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
    echo "Cloud name   [${cloudname}]"
    echo "Build name   [${buildname}]"
    echo "---- ---- ----"


# -----------------------------------------------------
# Check for existing keypair.

    echo "Checking for key [${buildname}]"
    keyname=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            keypair list \
                --format json \
        | jq -r '.[] | select(.Name | startswith("'${buildname:?}'")) | .Name'
        )

# -----------------------------------------------------
# Create a new keypair if needed.

    if [ -n "${keyname}" ]
    then
        echo "Found [${keyname}]"
    else
        newname=${buildname:?}-keypair
        echo "Creating keypair [${newname}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            keypair create \
                --public-key "${treetop:?}/common/ssh/aglais-team-keys" \
                "${newname:?}"
    fi

