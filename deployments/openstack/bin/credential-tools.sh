#!/bin/bash
#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2024, ROE (http://www.roe.ac.uk/)
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
# It is easy to get the application credentials mixed up in a clouds.yaml file.
# To have the credentials for 'red' in the configuration for 'blue'.
#
# These functions compare the clouds.yaml credentials with the actual project name.
#
# See:
# https://github.com/wfau/gaia-dmp/issues/1282
#

#
# Get the project name for a cloud.
getprojectname()
    {
    local cloudname=${1:-'cloudname required'}
    local projectid

    projectid=$(
        openstack \
            --os-cloud "${cloudname}" \
            token issue \
                --format json \
        | jq -r '.project_id'
        )

    openstack \
        --os-cloud "${cloudname}" \
        project show \
            --format json \
            "${projectid}" \
    | jq -r '.name'

    }

#
# Check the credentials for a cloud match.
checkcredentials()
    {
    local cloudname=${1:-'cloudname required'}
    local projectname

    echo ""
    echo "Checking credentials for [${cloudname}]"

    projectname=$(
        getprojectname "${cloudname}"
        )

    if [ "${cloudname}" == "${projectname}" ]
    then
        echo "PASS credentials match [${projectname}]"
        return 0
    else
        echo "FAIL credentials match do not match [${cloudname}][${projectname}]"
        return -1
    fi
    }

