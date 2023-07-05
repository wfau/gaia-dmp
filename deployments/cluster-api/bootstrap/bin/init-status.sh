#!/bin/sh
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2023, ROE (http://www.roe.ac.uk/)
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
# AIMetrics: [{"name": "ChatGPT","contribution": {"value": 0,"units": "%"}}]

#
# TODO Remove the debug logging when we are happy with this.
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
    statusyml=${2:-'/opt/aglais/aglais-status.yml'}

    echo "---- ---- ----"
    echo "Cloud name  [${cloudname:?}]"
    echo "Status file [${statusyml:?}]"
    echo "---- ---- ----"

# -----------------------------------------------------
# Create the target directory.

    #
    if [ ! -e "$(dirname ${statusyml})" ]
    then
        mkdir -p "$(dirname ${statusyml})"
    fi

# -----------------------------------------------------
# Backup any existing status file.

    if [ -e "${statusyml}" ]
    then
        mv --backup=numbered \
           "${statusyml}" \
           "${statusyml%%.*}-$(date '+%Y%m%dT%H%M%S').bak"
    fi

# -----------------------------------------------------
# Start clean.

    rm -f "${statusyml}"
    touch "${statusyml}"

# -----------------------------------------------------
# Create an Openstack token to get the project and user details.

    openstack \
        --os-cloud "${cloudname:?}" \
        token issue \
            --format json \
    | tee '/tmp/ostoken.json'   \
    | jq '.'

    export osuserid=$(
        jq -r '.user_id' '/tmp/ostoken.json'
        )

    openstack \
        --os-cloud "${cloudname:?}" \
        user show \
            --format json \
            "${osuserid}" \
    | tee '/tmp/osuser.json' \
    | jq '.'

    export osusername=$(
        jq -r '.name' '/tmp/osuser.json'
        )

    export osprojectid=$(
        jq -r '.project_id' '/tmp/ostoken.json'
        )

    openstack \
        --os-cloud "${cloudname:?}" \
        project show \
            --format json \
            "${osprojectid}" \
    | tee '/tmp/osproject.json' \
    | jq '.'

    export osprojectname=$(
        jq -r '.name' '/tmp/osproject.json'
        )

    export deployname=${cloudname:?}-$(date '+%Y%m%d')
    export deploydate=$(date '+%Y%m%dT%H%M%S')

# -----------------------------------------------------
# Create a new YAML status file.

    yq --null-input '{
        "aglais": {
            "deployment": {
                "type": "cluster-api",
                "name": strenv(deployname),
                "date": strenv(deploydate)
                },
            "openstack": {
                "cloud": {
                    "name": strenv(cloudname)
                    },
                "user": {
                    "id": strenv(osuserid),
                    "name": strenv(osusername)
                    },
                "project": {
                    "id": strenv(osprojectid),
                    "name": strenv(osprojectname)
                    }
                }
            }
        }' \
    | tee "${statusyml}" \
    | yq '.'


