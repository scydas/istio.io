---
title: Панель даних
test: n/a
---

Панель даних — це частина mesh, яка безпосередньо обробляє та маршрутизує трафік між екземплярами навантаження.

У режимі {{< gloss >}}sidecar{{< /gloss >}} панель даних Istio використовує проксі [Envoy](/docs/reference/glossary/#envoy), розгорнуті як sidecar, для медіації та контролю всього трафіку, який надсилають і отримують ваші сервіси mesh.

У режимі {{< gloss >}}ambient{{< /gloss >}} панель даних Istio використовує проксі {{< gloss >}}ztunnel{{< /gloss >}} на рівні вузла, розгорнуті як DaemonSet, для медіації та контролю всього трафіку, який надсилають і отримують ваші сервіси mesh.
