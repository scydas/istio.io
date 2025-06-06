---
title: DNS 代理
description: 如何配置 DNS 代理。
weight: 60
keywords: [traffic-management,dns,virtual-machine]
owner: istio/wg-networking-maintainers
test: yes
---

除了捕获应用流量，Istio 还可以捕获 DNS 请求，
以提高网格的性能和可用性。当 Istio 代理 DNS 时，
所有来自应用程序的 DNS 请求将会被重定向到 Sidecar 或 ztunnel 代理，
因为 Sidecar 存储了域名到 IP 地址的映射。如果请求被代理处理，
它将直接给应用返回响应，避免了对上游 DNS 服务器的往返。
反之，请求将按照标准的 `/etc/resolv.conf` DNS 配置向上游转发。

虽然 Kubernetes 为 Kubernetes `Service`
提供了一个开箱即用的 DNS 解析，但任何自定义的 `ServiceEntry`
都不会被识别。有了这个功能，`ServiceEntry` 地址可以被解析，
而不需要自定义 DNS 服务配置。对于 Kubernetes `Service` 来说，
一样的 DNS 响应，但减少了 `kube-dns` 的负载，并且提高了性能。

该功能也适用于在 Kubernetes 外部运行的服务。
这意味着所有的内部服务都可以被解析，而不需要再使用笨重的运行方法来暴露集群外的 Kubernetes DNS 条目。

## 开始 {#getting-started}

Istio 通常会基于 HTTP 头来路由流量。如果无法基于 HTTP 头进行路由
（例如在 Ambient 模式下，或在 Sidecar 模式下使用 TCP 流量时），则可以启用 DNS 代理。

在 Ambient 模式下，ztunnel 仅能看到第 4 层流量，无法访问 HTTP 头。
因此，DNS 代理机制对于解析 `ServiceEntry` 地址是必需的，
特别是在[将出口流量发送到 waypoint](https://github.com/istio/istio/wiki/Troubleshooting-Istio-Ambient#scenario-ztunnel-is-not-sending-egress-traffic-to-waypoints)的情况下更是如此。

### Ambient 模式 {#ambient-mode}

从 Istio 1.25 开始，Ambient 模式默认启用了 DNS 代理机制。

对于 1.25 之前的版本，您可以在安装时通过设置 `values.cni.ambient.dnsCapture=true`
和 `values.pilot.env.PILOT_ENABLE_IP_AUTOALLOCATE=true` 来启用 DNS 捕获。

### Sidecar 模式 {#sidecar-mode}

此功能默认情况下未启用。要启用该功能，请在安装 Istio 时使用以下设置：

{{< text bash >}}
$ cat <<EOF | istioctl install -y -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      proxyMetadata:
        # 启用基本 DNS 代理
        ISTIO_META_DNS_CAPTURE: "true"
EOF
{{< /text >}}

您也可以在每个 Pod 上启用该功能，通过 [`proxy.istio.io/config` 注解](/zh/docs/reference/config/annotations/)：

{{< text syntax=yaml snip_id=none >}}
kind: Deployment
metadata:
  name: curl
spec:
...
  template:
    metadata:
      annotations:
        proxy.istio.io/config: |
          proxyMetadata:
            ISTIO_META_DNS_CAPTURE: "true"
...
{{< /text >}}

{{< tip >}}
当时使用 [`istioctl 工作负载配置`](/zh/docs/setup/install/virtual-machine/)部署虚拟机时，
默认启用基础 DNS 代理。
{{< /tip >}}

## DNS 捕获 {#DNS-capture-in-action}

为了尝试 DNS 捕获，首先为某些外部服务启动一个 `ServiceEntry`：

{{< text bash >}}
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-address
spec:
  addresses:
  - 198.51.100.1
  hosts:
  - address.internal
  ports:
  - name: http
    number: 80
    protocol: HTTP
EOF
{{< /text >}}

调用客户端应用以发起 DNS 请求：

{{< text bash >}}
$ kubectl label namespace default istio-injection=enabled --overwrite
$ kubectl apply -f @samples/curl/curl.yaml@
{{< /text >}}

如果不开启 DNS 捕获，请求 `address.internal`
时可能解析失败。一旦启用 DNS 捕获，您将收到一个基于 `address` 配置的响应：

{{< text bash >}}
$ kubectl exec deploy/curl -- curl -sS -v address.internal
*   Trying 198.51.100.1:80...
{{< /text >}}

## 自动分配地址 {#address-auto-allocation}

在上面的示例中，对于发送请求的服务，您有一个预定义的 IP 地址。
但是常规情况下，服务访问外部服务时一般没有一个相对固定的地址，
因此需要通过 DNS 代理去访问外部服务。如果 DNS 代理没有足够的信息去返回一个响应的情况下，
将需要向上游转发 DNS 请求。

这在 TCP 通讯中是一个很严重的问题。它不像 HTTP 请求，基于 `Host` 头部去路由。
TCP 携带的信息更少，只能在目标 IP 和端口号上路由。
由于后端没有稳定的 IP，所以也不能基于其他信息进行路由，
只剩下端口号，但是这会导致多个 `ServiceEntry` 使用 TCP
服务会共享同一端口而产生冲突。更多细节参阅[以下章节](#external-tcp-services-without-vips)。

为了解决这些问题，DNS 代理还支持自动为未明确指定地址的 `ServiceEntry` 分配地址。
DNS 响应将为每个 `ServiceEntry` 包含一个独特且自动分配的地址。然后，
代理被配置为将请求匹配到该 IP 地址，并将请求转发到相应的 `ServiceEntry`。
只要这些服务不使用通配符主机，Istio 将自动为这些服务分配不可路由的虚拟 IP
（来自 Class E 子网）。侧车上的 Istio 代理将使用这些虚拟 IP 作为应用程序
DNS 查找查询的响应。Envoy 现在可以清晰地区分每个外部 TCP 服务的流量，并将其转发到正确的目标。

{{< warning >}}
由于该特性修改了 DNS 响应，因此可能无法兼容所有应用程序。
{{< /warning >}}

尝试配置另外一个 `ServiceEntry`：

{{< text bash >}}
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-auto
spec:
  hosts:
  - auto.internal
  ports:
  - name: http
    number: 80
    protocol: HTTP
  resolution: DNS
EOF
{{< /text >}}

现在，发送一个请求：

{{< text bash >}}
$ kubectl exec deploy/curl -- curl -sS -v auto.internal
*   Trying 240.240.0.1:80...
{{< /text >}}

您可以看到，请求被发送到一个自动分配的地址 `240.240.0.1` 上。
这些地址将从 `240.240.0.0/16` 预留的 IP 地址池中挑选出来，
以避免与真实的服务发生冲突。

用户还可以通过向其 `ServiceEntry` 添加标签
`networking.istio.io/enable-autoallocate-ip="true/false"`
来灵活地进行更细粒度的配置。此标签配置未设置任何 `spec.addresses`
的 `ServiceEntry` 是否应自动为其分配 IP 地址。

要尝试此功能，请使用退出标签更新现有的 `ServiceEntry`：

{{< text bash >}}
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-auto
  labels:
    networking.istio.io/enable-autoallocate-ip: "false"
spec:
  hosts:
  - auto.internal
  ports:
  - name: http
    number: 80
    protocol: HTTP
  resolution: DNS
EOF
{{< /text >}}

现在，发送请求并验证自动分配不再发生：

{{< text bash >}}
$ kubectl exec deploy/curl -- curl -sS -v auto.internal
* Could not resolve host: auto.internal
* shutting down connection #0
{{< /text >}}

## 不带 VIP 的外部 TCP 服务 {#external-tcp-services-without-vips}

默认情况下，Istio 在路由外部 TCP 流量时存在限制，因为它无法区分相同端口上的多个 TCP 服务。
当使用第三方数据库（如 AWS 关系型数据库服务）或任何具有地理冗余设置的数据库时，这种限制尤为明显。
默认情况下，类似但不同的外部 TCP 服务不能被分别处理。
为了让 Sidecar 区分网格之外的两个不同的 TCP 服务的流量，
这些服务必须位于不同的端口上，或者它们需要具有全局唯一的 VIP 地址。

例如，如果您有两个外部数据库服务（`mysql-instance1` 和 `mysql-instance2`），
并为这两个服务创建了服务条目，则客户端 Sidecar 仍将在 `0.0.0.0:{port}`
上有一个单独的侦听器，从公共 DNS 服务器查找只 `mysql-instance1` 的 IP 地址，
并将流量转发到它。它无法将流量路由到 `mysql-instance2`，因为它无法区分抵达
`0.0.0.0:{port}` 的流量是针对 `mysql-instance1` 还是 `mysql-instance2` 的。

以下示例显示了如何使用 DNS 代理解决此问题。
虚拟 IP 地址将被分配到每个服务条目，以便客户端 Sidecar 可以清楚地区分每个外部 TCP 服务的流量。

1.  更新[开始](#getting-started)一节中指定的 Istio 配置，
    以配置 `discoverySelectors`，从而限制网格仅对启用了
    `istio-injection` 的命名空间进行筛选。
    这将使我们可以在集群中使用任何其他命名空间来运行网格之外的 TCP 服务。

    {{< text bash >}}
    $ cat <<EOF | istioctl install -y -f -
    apiVersion: install.istio.io/v1alpha1
    kind: IstioOperator
    spec:
      meshConfig:
        defaultConfig:
          proxyMetadata:
            # 启用基本 DNS 代理
            ISTIO_META_DNS_CAPTURE: "true"
        # 下面的 discoverySelectors 配置只是用于模拟外部服务 TCP 场景，
        # 这样我们就不必使用外部站点进行测试。
        discoverySelectors:
        - matchLabels:
            istio-injection: enabled
    EOF
    {{< /text >}}

1.  部署第一个外部样例 TCP 应用：

    {{< text bash >}}
    $ kubectl create ns external-1
    $ kubectl -n external-1 apply -f samples/tcp-echo/tcp-echo.yaml
    {{< /text >}}

1.  部署第二个外部样例 TCP 应用：

    {{< text bash >}}
    $ kubectl create ns external-2
    $ kubectl -n external-2 apply -f samples/tcp-echo/tcp-echo.yaml
    {{< /text >}}

1.  配置 `ServiceEntry` 以到达外部服务：

    {{< text bash >}}
    $ kubectl apply -f - <<EOF
    apiVersion: networking.istio.io/v1
    kind: ServiceEntry
    metadata:
      name: external-svc-1
    spec:
      hosts:
      - tcp-echo.external-1.svc.cluster.local
      ports:
      - name: external-svc-1
        number: 9000
        protocol: TCP
      resolution: DNS
    ---
    apiVersion: networking.istio.io/v1
    kind: ServiceEntry
    metadata:
      name: external-svc-2
    spec:
      hosts:
      - tcp-echo.external-2.svc.cluster.local
      ports:
      - name: external-svc-2
        number: 9000
        protocol: TCP
      resolution: DNS
    EOF
    {{< /text >}}

1.  确认在客户端侧为每个服务分别配置了侦听器：

    {{< text bash >}}
    $ istioctl pc listener deploy/curl | grep tcp-echo | awk '{printf "ADDRESS=%s, DESTINATION=%s %s\n", $1, $4, $5}'
    ADDRESS=240.240.105.94, DESTINATION=Cluster: outbound|9000||tcp-echo.external-2.svc.cluster.local
    ADDRESS=240.240.69.138, DESTINATION=Cluster: outbound|9000||tcp-echo.external-1.svc.cluster.local
    {{< /text >}}

## 清理 {#cleanup}

{{< text bash >}}
$ kubectl -n external-1 delete -f @samples/tcp-echo/tcp-echo.yaml@
$ kubectl -n external-2 delete -f @samples/tcp-echo/tcp-echo.yaml@
$ kubectl delete -f @samples/curl/curl.yaml@
$ istioctl uninstall --purge -y
$ kubectl delete ns istio-system external-1 external-2
$ kubectl label namespace default istio-injection-
{{< /text >}}
