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
    treetop="$(dirname $(dirname ${binpath}))"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"
    echo "Tree [${treetop}]"

    cloudname=${1:?}
    buildname="aglais-$(date '+%Y%m%d')"
    builddate="$(date '+%Y%m%d:%H%M%S')"

    deployname="${cloudname:?}-$(date '+%Y%m%d')"
    deploydate=$(date '+%Y%m%dT%H%M%S')

    configyml='/tmp/aglais-config.yml'
    statusyml='/tmp/aglais-status.yml'
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
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.openstack.cloud' \
            "${cloudname}"

    echo "---- ---- ----"
    echo "Config yml [${configyml}]"
    echo "Cloud name [${cloudname}]"
    echo "Build name [${buildname}]"
    echo "Deployment [${deployname}]"
    echo "---- ---- ----"

    hemlpath='/tmp/helm'
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.kubernetes.helm.path' \
            "${hemlpath}"

    namespace=${buildname,,}
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.kubernetes.namespace' \
            "${namespace}"


# -----------------------------------------------------
# Create our SSH keypair.
# Do we need this here, or does it go inside magnum-create ?

    "${treetop:?}/openstack/bin/create-keypair.sh" \
        "${cloudname:?}" \
        "${buildname:?}"


# -----------------------------------------------------
# Create our Magnum cluster.

    "${treetop:?}/kubernetes/bin/magnum-create.sh" \
        "${cloudname:?}" \
        "${buildname:?}"


# -----------------------------------------------------
# Get the cluster details.

    clusterid=$(
        jq -r '.uuid' '/tmp/cluster-status.json'
        )
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.openstack.magnum.cluster.uuid' \
            "${clusterid}"


# -----------------------------------------------------
# Get the temnplate details.

    templateuuid=$(
        jq -r '.cluster_template_id' '/tmp/cluster-status.json'
        )

    openstack\
        --os-cloud "${cloudname:?}" \
        coe cluster template show \
            --format json \
            "${templateuuid:?}" \
        > '/tmp/cluster-template.json'

    templatename=$(
        jq -r '.name' '/tmp/cluster-template.json'
        )

    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.openstack.magnum.template.uuid' \
            "${templateuuid}"
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.openstack.magnum.template.name' \
            "${templatename}"


# -----------------------------------------------------
# Create our CephFS router.

    "${treetop:?}/kubernetes/bin/cephfs-router.sh" \
        "${cloudname:?}" \
        "${buildname:?}"


# -----------------------------------------------------
# Get the connection details for our cluster.

    "${treetop:?}/kubernetes/bin/cluster-config.sh" \
        "${cloudname:?}" \
        "${clusterid:?}"

    echo "----"
    echo "Cluster info"

    kubectl \
        cluster-info


# -----------------------------------------------------
# Create a local copy of our Helm charts.

    echo ""
    echo "----"
    echo "Copying Aglais Helm charts"
    echo "  [${treetop:?}/kubernetes/helm] -> [${hemlpath:?}]"

    cp -a "${treetop:?}/kubernetes/helm" \
          "${hemlpath:?}"


# -----------------------------------------------------
# Install our main Helm chart.
# Using 'upgrade --install' to make the command idempotent
# https://github.com/helm/helm/issues/3134

    echo ""
    echo "----"
    echo "Installing Aglais Helm chart"
    echo "Namespace [${namespace}]"

    helm dependency update \
        "${hemlpath:?}"

    helm upgrade \
        --install \
        --create-namespace \
        --namespace "${namespace:?}" \
        'aglais' \
        "${hemlpath:?}"


# -----------------------------------------------------
# Install our dashboard chart.
# Using 'upgrade --install' to make the command idempotent
# https://github.com/helm/helm/issues/3134

#   dashhost=$(
#       yq read \
#           "${configyml:?}" \
#               'aglais.spec.dashboard.hostname'
#       )
    dashhost="dashboard.${cloudname:?}.aglais.uk"

    echo ""
    echo "----"
    echo "Installing dashboard Helm chart"
    echo "Namespace [${namespace}]"
    echo "Hostname  [${dashhost}]"

    helm dependency update \
        "${hemlpath:?}/tools/dashboard"

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
        "${hemlpath:?}/tools/dashboard" \
        --values "/tmp/dashboard-values.yaml"

#TODO Patch the k8s metrics

    # We can't capture the external IP address here because it won't be ready yet.

    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.dashboard.hostname' \
            "${dashhost}"


# -----------------------------------------------------
# Mount the data shares.
# Using a hard coded cloud name to make it portable.
# Hard coded mode to 'rw' due to problems with ReadOnlyMany

    sharelist="${treetop:?}/common/manila/datashares.yaml"
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

        "${treetop:?}/kubernetes/bin/cephfs-mount.sh" \
            'gaia-prod' \
            "${namespace:?}" \
            "${sharename:?}" \
            "${mountpath:?}" \
            "${sharemode:?}"

    done


# -----------------------------------------------------
# Mount the user shares.
# Using a hard coded cloud name to make it portable.

    sharelist="${treetop:?}/common/manila/usershares.yaml"
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

        "${treetop:?}/kubernetes/bin/cephfs-mount.sh" \
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

#   zepphost=$(
#       yq read \
#           "${configyml:?}" \
#               'aglais.spec.zeppelin.hostname'
#       )
    zepphost="zeppelin.${cloudname:?}.aglais.uk"

    echo ""
    echo "----"
    echo "Installing Zeppelin Helm chart"
    echo "Namespace [${namespace}]"
    echo "Hostname  [${zepphost}]"

    helm dependency update \
        "${hemlpath:?}/tools/zeppelin"

    cat > "/tmp/zeppelin-values.yaml" << EOF
zeppelin_server_hostname: "${zepphost:?}"
EOF

    helm upgrade \
        --install \
        --create-namespace \
        --namespace "${namespace:?}" \
        'aglais-zeppelin' \
        "${hemlpath:?}/tools/zeppelin" \
        --values "/tmp/zeppelin-values.yaml"

    # We can't capture the IP address here because it won't be ready yet.

    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.zeppelin.hostname' \
            "${zepphost}"


# -----------------------------------------------------
# Install our Drupal chart.
# Using 'upgrade --install' to make the command idempotent
# https://github.com/helm/helm/issues/3134

#   drupalhost=$(
#       yq read \
#           "${configyml:?}" \
#               'aglais.spec.drupal.hostname'
#       )
    drupalhost="drupal.${cloudname:?}.aglais.uk"

    echo ""
    echo "----"
    echo "Installing Drupal Helm chart"
    echo "Namespace [${namespace}]"
    echo "Hostname  [${drupalhost}]"

    helm dependency update \
        "${hemlpath:?}/tools/drupal"

    cat > "/tmp/drupal-values.yaml" << EOF
drupal_server_hostname: "${drupalhost:?}"
EOF




# -----------------------------------------------------
# Capture our Dashboard ingress IP address.
# ** This has to be done after a delay to allow Kubernetes time to allocate the IP address.

#   sleep 30

    daship=$(
        kubectl \
            --namespace "${namespace:?}" \
            get Ingress \
                --output json \
        | jq -r '
            .items[]
          | select(.metadata.name == "aglais-dashboard-kubernetes-dashboard")
          | .status.loadBalancer.ingress[0].ip
          '
        )

    yq write \
        --inplace \
        '/tmp/aglais-status.yml' \
            'aglais.status.dashboard.publicipv4' \
            "${daship}"


# -----------------------------------------------------
# Capture our Zeppelin ingress IP address.
# ** This has to be done after a delay to allow Kubernetes time to allocate the IP address.

#   sleep 30

    zeppip=$(
        kubectl \
            --namespace "${namespace:?}" \
            get Ingress \
                --output json \
        | jq -r '
            .items[]
          | select(.metadata.name == "zeppelin-server-ingress")
          | .status.loadBalancer.ingress[0].ip
          '
        )

    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.zeppelin.publicipv4' \
            "${zeppip}"


