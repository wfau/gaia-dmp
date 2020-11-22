#!/bin/sh
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

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    srcpath="$(dirname ${binpath})"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"

    echo "---- ---- ----"
    echo "Cloud name [${cloudname}]"
    echo "Cloud user [${clouduser}]"

    buildname="aglais-k8s-$(date '+%Y%m%d')"

    echo "Build name [${buildname}]"
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

    clusteruuid=$(
        jq -r '.uuid' '/tmp/cluster-status.json'
        )

    echo "----"
    echo "Cluster uuid [${clusteruuid}]"

    mkdir -p "${HOME}/.kube"
    openstack \
        --os-cloud "${cloudname:?}" \
        coe cluster config \
            "${clusteruuid:?}" \
                --force \
                --dir "${HOME}/.kube" \
    > '/dev/null' 2>&1

    kubectl \
        cluster-info


# -----------------------------------------------------
# Install our main Helm chart.


# -----------------------------------------------------
# Mount the Gaia DR2 data.
# Note the hard coded cloud name to get details of the static share.

#   '/kubernetes/bin/cephfs-mount.sh' \
#       'gaia-prod' \
#       'aglais-gaia-dr2' \
#       '/data/gaia/dr2'


# -----------------------------------------------------
# Mount the user data volume.
# Note the hard coded cloud name to get details of the static share.

#   '/kubernetes/bin/cephfs-mount.sh' \
#       'gaia-prod' \
#       'aglais-user-nch' \
#       '/user/nch' \
#       'rw'


