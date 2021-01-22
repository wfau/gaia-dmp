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

    configyml=${1:-'/tmp/aglais-config.yml'}
    statusyml=${2:-'/tmp/aglais-status.yml'}

    buildname="aglais-$(date '+%Y%m%d')"
    builddate="$(date '+%Y%m%d:%H%M%S')"

    touch "${statusyml:?}"
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.deployment.type' \
            'kubernetes'
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.deployment.name' \
            "${buildname}"
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.deployment.date' \
            "${builddate}"

    cloudname=$(
        yq read \
            "${configyml:?}" \
                'aglais.spec.openstack.cloudname'
        )
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.spec.openstack.cloudname' \
            "${cloudname}"

    echo "---- ---- ----"
    echo "Config yml [${configyml}]"
    echo "Build name [${buildname}]"
    echo "Cloud name [${cloudname}]"
    echo "---- ---- ----"


# -----------------------------------------------------
# Create our SSH keypair.
# Do we need this here, or does it go inside magnum-create ?

    '/openstack/bin/create-keypair.sh' \
        "${cloudname:?}" \
        "${buildname:?}"


# -----------------------------------------------------
# Create our Magnum cluster.

    '/kubernetes/bin/magnum-create.sh' \
        "${cloudname:?}" \
        "${buildname:?}"

    clusterid=$(
        jq -r '.uuid' '/tmp/cluster-status.json'
        )
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.openstack.cluster.id' \
            "${clusterid}"

# -----------------------------------------------------
# Create our CephFS router.

    '/kubernetes/bin/cephfs-router.sh' \
        "${cloudname:?}" \
        "${buildname:?}"


# -----------------------------------------------------
# Get the connection details for our cluster.

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

    namespace=${buildname,,}
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.kubernetes.namespace' \
            "${namespace}"

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

    dashhost=$(
        yq read \
            "${configyml:?}" \
                'aglais.spec.dashboard.hostname'
        )

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
# Mount the data shares.
# Using a hard coded cloud name to make it portable.

    sharelist='/common/manila/datashares.yaml'
    sharemode='ro'

    for shareid in $(
        yq read \
            "${sharelist:?}" \
                'shares.[*].id'
        )
    do
        echo ""
        echo "Share [${shareid:?}]"

        sharename=$(yq read "${sharelist:?}" "shares.(id==${shareid:?}).sharename")
        mountpath=$(yq read "${sharelist:?}" "shares.(id==${shareid:?}).mountpath")

        '/kubernetes/bin/cephfs-mount.sh' \
            'gaia-prod' \
            "${namespace:?}" \
            "${sharename:?}" \
            "${mountpath:?}" \
            "${sharemode:?}"

    done


# -----------------------------------------------------
# Mount the user shares.
# Using a hard coded cloud name to make it portable.

    sharelist='/common/manila/usershares.yaml'
    sharemode='rw'

    for shareid in $(
        yq read \
            "${sharelist:?}" \
                'shares.[*].id'
        )
    do
        echo ""
        echo "Share [${shareid:?}]"

        sharename=$(yq read "${sharelist:?}" "shares.(id==${shareid:?}).sharename")
        mountpath=$(yq read "${sharelist:?}" "shares.(id==${shareid:?}).mountpath")

        '/kubernetes/bin/cephfs-mount.sh' \
            'gaia-prod' \
            "${namespace:?}" \
            "${sharename:?}" \
            "${mountpath:?}" \
            "${sharemode:?}"

    done


# -----------------------------------------------------
# Install our Zeppelin chart.
# Using 'upgrade --install' to make the command idempotent
# https://github.com/helm/helm/issues/3134

    zepphost=$(
        yq read \
            "${configyml:?}" \
                'aglais.spec.zeppelin.hostname'
        )

    echo ""
    echo "----"
    echo "Installing Zeppelin Helm chart"
    echo "Namespace [${namespace}]"
    echo "Hostname  [${zepphost}]"


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

    drupalhost=$(
        yq read \
            "${configyml:?}" \
                'aglais.spec.drupal.hostname'
        )

    echo ""
    echo "----"
    echo "Installing Drupal Helm chart"
    echo "Namespace [${namespace}]"
    echo "Hostname  [${drupalhost}]"

    helm dependency update \
        "/kubernetes/helm/tools/drupal"

    cat > "/tmp/zeppelin-values.yaml" << EOF
drupal_server_hostname: "${drupalhost:?}"
EOF





