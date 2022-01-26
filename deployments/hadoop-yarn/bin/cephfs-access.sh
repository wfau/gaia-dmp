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
    treetop="$(dirname $(dirname ${binpath}))"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"
    echo "Tree [${treetop}]"

    cloudname=${1:?}
    sharename=${2:?}
    mountpath=${3:?}
    mountmode=${4:-'ro'}

    echo "---- ---- ----"
    echo "Cloud name [${cloudname}]"
    echo "Share name [${sharename}]"
    echo "Mount path [${mountpath}]"
    echo "Mount mode [${mountmode}]"
    echo "---- ---- ----"
    echo ""

    manilainfo="/tmp/${sharename:?}-manila.json"
    accessjson="/tmp/${sharename:?}-access.json"
    accessyaml="/tmp/${sharename:?}-access.yml"
    globalyaml="/tmp/aglais-ceph-access.yml"


# -----------------------------------------------------
# Set the Manila API version.
# https://stackoverflow.com/a/58806536
# TODO Move this to an openstack script.

   #export OS_SHARE_API_VERSION=2.51
    export OS_SHARE_API_VERSION=2.46

# -----------------------------------------------------
# Identify the Manila share.
# TODO Move this to an openstack script.

    echo "Target [${cloudname}][${sharename}]"

    shareid=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            share list \
                --format json \
        | jq -r '.[] | select( .Name == "'${sharename:?}'") | .ID'
        )

    echo "Found  [${shareid}]"

# -----------------------------------------------------
# Get details of the Ceph export location.
# TODO Move this to an openstack script.

    openstack \
        --os-cloud "${cloudname:?}" \
        share show \
            --format json \
            "${shareid:?}" \
    | jq '.' \
    > "${manilainfo:?}"

    locations=$(
        jq '.export_locations' "${manilainfo:?}"
        )

    cephnodes=$(
        echo "${locations:?}" |
        sed '
            s/^.*path = \([^\\]*\).*$/\1/
            s/^\(.*\):\(\/.*\)$/\1/
            s/,/ /g
            '
            )

    cephpath=$(
        echo "${locations:?}" |
        sed '
            s/^.*path = \([^\\]*\).*$/\1/
            s/^\(.*\):\(\/.*\)$/\2/
            '
            )

    cephsize=$(
        jq '.size' "${manilainfo:?}"
        )

    echo "----"
    echo "Ceph path [${cephpath}]"
    echo "Ceph size [${cephsize}]"

    echo "----"
    for cephnode in ${cephnodes}
    do
        echo "Ceph node [${cephnode}]"
    done


# -----------------------------------------------------
# Get details of the access rule.
# TODO Move this to an openstack script.

    accessrule=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            share access list \
                --format json \
                "${shareid:?}" \
        | jq -r '.[] | select(.access_level == "'${mountmode:?}'") | .id'
        )

    openstack \
        --os-cloud "${cloudname:?}" \
        share access show \
            --format json \
            "${accessrule:?}" \
    | jq '.' \
    > "${accessjson:?}"

    cephuser=$(
        jq -r '.access_to' "${accessjson:?}"
        )

    cephkey=$(
        jq -r '.access_key' "${accessjson:?}"
        )

    echo "----"
    echo "Ceph user [${cephuser}]"
    echo "Ceph key  [${cephkey}]"
    echo ""


# -----------------------------------------------------
# Create an Ansible vars file for this share.

    cat > "${accessyaml:?}" << EOF
cephuser:  '${cephuser:?}'
cephkey:   '${cephkey:?}'
cephpath:  '${cephpath:?}'
cephnodes: '${cephnodes// /,}'
mountpath: '${mountpath}'
mountmode: '${mountmode}'
EOF


# -----------------------------------------------------
# Update the global Ansible vars file.

    touch "${globalyaml:?}"

    yq write \
        --inplace \
        "${globalyaml:?}" \
            "aglais.ceph.${sharename:?}.cephuser" \
            "${cephuser:?}"

    yq write \
        --inplace \
        "${globalyaml:?}" \
            "aglais.ceph.${sharename:?}.cephkey" \
            "${cephkey:?}"

    yq write \
        --inplace \
        "${globalyaml:?}" \
            "aglais.ceph.${sharename:?}.cephpath" \
            "${cephpath:?}"

    yq write \
        --inplace \
        "${globalyaml:?}" \
            "aglais.ceph.${sharename:?}.cephnodes" \
            "${cephnodes:?}"

    yq write \
        --inplace \
        "${globalyaml:?}" \
            "aglais.ceph.${sharename:?}.mountpath" \
            "${mountpath:?}"

    yq write \
        --inplace \
        "${globalyaml:?}" \
            "aglais.ceph.${sharename:?}.mountmode" \
            "${mountmode:?}"

