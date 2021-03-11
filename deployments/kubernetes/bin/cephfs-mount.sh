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

#TODO Make the read/write status configurable.

# -----------------------------------------------------
# Settings ...

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    treetop="$(dirname $(dirname ${binpath}))"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"
    echo "Tree [${treetop}]"

    cloudname=${1:?}
    namespace=${2:?}
    sharename=${3:?}
    mountpath=${4:?}
    sharemode=${5:-'ro'}

    echo "---- ---- ----"
    echo "Cloud name [${cloudname}]"
    echo "Namespace  [${namespace}]"
    echo "Share name [${sharename}]"
    echo "Mount path [${mountpath}]"
    echo "Share mode [${sharemode}]"
    echo "---- ---- ----"
    echo ""

# -----------------------------------------------------
# Set the Manila API version.
# https://stackoverflow.com/a/58806536

    export OS_SHARE_API_VERSION=2.51

# -----------------------------------------------------
# Identify the Manila share.

    shareid=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            share list \
                --format json \
        | jq -r '.[] | select( .Name == "'${sharename:?}'") | .ID'
        )

    openstack \
        --os-cloud "${cloudname:?}" \
        share show \
            --format json \
            "${shareid:?}" \
    > "/tmp/${sharename:?}-share.json"

    echo "----"
    echo "Share uuid [${shareid}]"


# -----------------------------------------------------
# Get size of the share (in Gbytes).

    sharesize=$(
        jq -r '.size' "/tmp/${sharename:?}-share.json"
        )

    echo "----"
    echo "Share size [${sharesize}]"


# -----------------------------------------------------
# Get the access rule.

    accessid=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            share access list \
                --format json \
                "${shareid:?}" \
        | jq -r '.[] | select(.access_level == "'${sharemode:?}'") | .id'
        )

    echo "----"
    echo "Access rule [${accessid}]"


# -----------------------------------------------------
# Create the values file for our Helm chart.

cat > "/tmp/${sharename:?}-values.yaml" << EOF

aglais:
  dataset: "${sharename:?}"

mount:
  path: "${mountpath:?}"
  readonly: true

csi:
  size:    ${sharesize:?}
  access: "ReadWriteMany"

openstack:
  shareid:  ${shareid:?}
  accessid: ${accessid:?}

EOF


# -----------------------------------------------------
# Install our Manila share.
# Using 'upgrade --install' to make the command idempotent
# https://github.com/helm/helm/issues/3134

    helm upgrade \
        --install \
        --create-namespace \
        --namespace "${namespace:?}" \
        "${sharename,,}" \
        "${treetop:?}/kubernetes/helm/tools/manila-share" \
        --values "/tmp/${sharename:?}-values.yaml"



