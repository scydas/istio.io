#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2154

# Copyright Istio Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# @setup multicluster

set -e
set -u
set -o pipefail

source content/en/docs/setup/install/multicluster/common.sh
set_multi_network_vars

function install_istio_on_cluster1_istioctl {
    echo "Installing Istio on Primary cluster: ${CTX_CLUSTER1}"

    snip_set_the_default_network_for_cluster1_1

    snip_configure_cluster1_as_a_primary_1
    echo y | snip_configure_cluster1_as_a_primary_2

    echo "Creating the east-west gateway"
    snip_install_the_eastwest_gateway_in_cluster1_1

    echo "Waiting for the east-west gateway to have an external IP"
    _verify_like snip_install_the_eastwest_gateway_in_cluster1_3 "$snip_install_the_eastwest_gateway_in_cluster1_3_out"

    echo "Exposing services via the east-west gateway"
    snip_expose_services_in_cluster1_1
}

function install_istio_on_cluster2_istioctl {
    echo "Installing Istio on Primary cluster: ${CTX_CLUSTER2}"

    snip_set_the_default_network_for_cluster2_1

    snip_configure_cluster2_as_a_primary_1
    echo y | snip_configure_cluster2_as_a_primary_2

    echo "Creating the east-west gateway"
    snip_install_the_eastwest_gateway_in_cluster2_1

    echo "Waiting for the east-west gateway to have an external IP"
    _verify_like snip_install_the_eastwest_gateway_in_cluster2_3 "$snip_install_the_eastwest_gateway_in_cluster2_3_out"

    echo "Exposing services via the east-west gateway"
    snip_expose_services_in_cluster2_1
}

function install_istio_istioctl {
  # Install Istio on the 2 clusters. Executing in
  # parallel to reduce test time.
  install_istio_on_cluster1_istioctl &
  install_istio_on_cluster2_istioctl &
  wait
}

function enable_endpoint_discovery {
  snip_enable_endpoint_discovery_1
  snip_enable_endpoint_discovery_2
}

time configure_trust
time install_istio_istioctl
time enable_endpoint_discovery
time verify_load_balancing

# @cleanup
source content/en/docs/setup/install/multicluster/common.sh
set_multi_network_vars
time cleanup_istioctl

# Everything should be removed once cleanup completes. Use a small
# timeout for comparing cluster snapshots before/after the test.
export VERIFY_TIMEOUT=20
