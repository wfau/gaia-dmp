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

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    treetop="$(dirname $(dirname ${binpath}))"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"
    echo "Tree [${treetop}]"

    cloudname=${1:?}
    buildname=${2:?}

    echo "---- ---- ----"
    echo "Cloud name [${cloudname}]"
    echo "Build name [${buildname}]"
    echo "---- ---- ----"

# -----------------------------------------------------
# Identify our cluster router.

    openstack \
        --os-cloud "${cloudname:?}" \
        router list \
            --format json \
    | jq '.[] | select(.Name == "'${buildname}'-internal-router")' \
    > '/tmp/cluster-router.json'


# -----------------------------------------------------
# Identify our cluster subnet.

    openstack \
        --os-cloud "${cloudname:?}" \
        subnet list \
            --format json \
    | jq '.[] | select(.Name == "'${buildname}'-internal-subnet")' \
    > '/tmp/cluster-subnet.json'


# -----------------------------------------------------
# Create the CephFS router.

    "${treetop:?}/openstack/bin/cephfs-router.sh" \
        "${cloudname:?}" \
        "${buildname:?}"





