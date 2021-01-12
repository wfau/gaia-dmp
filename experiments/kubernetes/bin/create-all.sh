#!/bin/bash
#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2020, ROE (http://www.roe.ac.uk/)
#
#     This information is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This information is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.
#   </meta:licence>
# </meta:header>
#
#

# -----------------------------------------------------
# Settings ...

#   set -eu
#   set -o pipefail

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    srcpath="$(dirname ${binpath})"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"

    cloudname=${1:?}
    buildname=${2:?}
    namespace=${3:?}

    echo "---- ---- ----"
    echo "Cloud name [${cloudname:?}]"
    echo "Build name [${buildname:?}]"
    echo "Namespace  [${namespace:?}]"
    echo "---- ---- ----"


# -----------------------------------------------------
# Create our Magnum cluster.

    '/kubernetes/bin/magnum-create.sh' \
        "${cloudname:?}" \
        "${buildname:?}"


# -----------------------------------------------------
# Create our CephFS router.

    '/kubernetes/bin/cephfs-router.sh' \
        "${cloudname:?}" \
        "${buildname:?}"


# -----------------------------------------------------
# Get the connection details for our cluster.

    clusterid=$(
        jq -r '.uuid' '/tmp/cluster-status.json'
        )

    '/kubernetes/bin/cluster-config.sh' \
        "${cloudname:?}" \
        "${clusterid:?}"

    echo "----"
    echo "Cluster info"

    kubectl \
        cluster-info


# -----------------------------------------------------
# Install our main Helm chart.
# Using 'upgrade --install' to make the command idempotent
# https://github.com/helm/helm/issues/3134

    echo ""
    echo "----"
    echo "Installing Aglais Helm chart"
    echo "Namespace [${namespace}]"

    helm dependency update \
        "/kubernetes/helm"

    helm upgrade \
        --install \
        --create-namespace \
        --namespace "${namespace:?}" \
        'aglais' \
        "/kubernetes/helm"


# -----------------------------------------------------
# Install our dashboard chart.
# Using 'upgrade --install' to make the command idempotent
# https://github.com/helm/helm/issues/3134

    dashhost=valeria.metagrid.xyz

    echo ""
    echo "----"
    echo "Installing dashboard Helm chart"
    echo "Namespace [${namespace}]"
    echo "Dash host [${dashhost}]"

    helm dependency update \
        "/kubernetes/helm/tools/dashboard"

    cat > "/tmp/dashboard-values.yaml" << EOF
kubernetes-dashboard:
  ingress:
    enabled: true
    paths:
      - /
    hosts:
      - ${dashhost:?}
EOF

    helm upgrade \
        --install \
        --create-namespace \
        --namespace "${namespace:?}" \
        'aglais-dashboard' \
        "/kubernetes/helm/tools/dashboard" \
        --values "/tmp/dashboard-values.yaml"

#TODO Patch the k8s metrics


# -----------------------------------------------------
# Mount the Gaia DR2 and eDR3 data.
# Note the hard coded cloud name to get details of the static share.

    '/kubernetes/bin/cephfs-mount.sh' \
        'gaia-prod' \
        "${namespace:?}" \
        'aglais-gaia-dr2' \
        '/data/gaia/dr2' \
        'rw'

    '/kubernetes/bin/cephfs-mount.sh' \
        'gaia-prod' \
        "${namespace:?}" \
        'aglais-gaia-edr3' \
        '/data/gaia/edr3' \
        'rw'

# -----------------------------------------------------
# Mount the additional catalogs.
# Note the hard coded cloud name to get details of the static share.

    '/kubernetes/bin/cephfs-mount.sh' \
        'gaia-prod' \
        "${namespace:?}" \
        'aglais-wise-allwise' \
        '/data/wise/allwise' \
        'rw'

    '/kubernetes/bin/cephfs-mount.sh' \
        'gaia-prod' \
        "${namespace:?}" \
        'aglais-panstarrs-dr1' \
        '/data/panstarrs/dr1' \
        'rw'

    '/kubernetes/bin/cephfs-mount.sh' \
        'gaia-prod' \
        "${namespace:?}" \
        'aglais-twomass-allsky' \
        '/data/twomass/allsky' \
        'rw'

# -----------------------------------------------------
# Mount the user data volumes.
# Note the hard coded cloud name to get details of the static share.

    '/kubernetes/bin/cephfs-mount.sh' \
        'gaia-prod' \
        "${namespace:?}" \
        'aglais-user-nch' \
        '/user/nch' \
        'rw'


    '/kubernetes/bin/cephfs-mount.sh' \
        'gaia-prod' \
        "${namespace:?}" \
        'aglais-user-stv' \
        '/user/stv' \
        'rw'

    '/kubernetes/bin/cephfs-mount.sh' \
        'gaia-prod' \
        "${namespace:?}" \
        'aglais-user-zrq' \
        '/user/zrq' \
        'rw'


# -----------------------------------------------------
# Install our Zeppelin chart.
# Using 'upgrade --install' to make the command idempotent
# https://github.com/helm/helm/issues/3134

    zepphost=zeppelin.metagrid.xyz

    echo ""
    echo "----"
    echo "Installing Zeppelin Helm chart"
    echo "Namespace [${namespace}]"
    echo "Zepp host [${zepphost}]"


    helm dependency update \
        "/kubernetes/helm/tools/zeppelin"

    cat > "/tmp/zeppelin-values.yaml" << EOF
zeppelin_server_hostname: "${zepphost:?}"
EOF

    helm upgrade \
        --install \
        --create-namespace \
        --namespace "${namespace:?}" \
        'aglais-zeppelin' \
        "/kubernetes/helm/tools/zeppelin" \
        --values "/tmp/zeppelin-values.yaml"


# -----------------------------------------------------
# Install our Drupal chart.
# Using 'upgrade --install' to make the command idempotent
# https://github.com/helm/helm/issues/3134

    drupalhost=drupal.metagrid.xyz

    echo ""
    echo "----"
    echo "Installing Zeppelin Helm chart"
    echo "Namespace [${namespace}]"
    echo "Zepp host [${zepphost}]"


    helm dependency update \
        "/kubernetes/helm/tools/zeppelin"



