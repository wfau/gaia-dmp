#!/bin/bash
#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2022, ROE (http://www.roe.ac.uk/)
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

#
# Create a CephFS share using the Manila API.
# https://docs.openstack.org/python-openstackclient/latest/cli/plugin-commands/manila.html
#

cloudname="${1:?'cloud name required'}"
sharename="${2:?'share name required'}"
sharesize="${3:?'share size required'}"

sharetemp="/tmp/${sharename}"
sharetype='ceph01_cephfs'
sharezone='nova'
shareprotocol='CEPHFS'

accesstype='cephx'

# Set the Manila API version.
# https://stackoverflow.com/a/58806536
source /deployments/openstack/bin/settings.sh


cat << EOF
{
"params": {
    "cloudname": "${cloudname:?}",
    "sharename": "${sharename:?}",
    "sharesize": "${sharesize:?}"
    },
EOF

        openstack \
            --os-cloud "${cloudname}" \
            share create \
                --format json \
                --name "${sharename}" \
                --share-type "${sharetype}" \
                --availability-zone "${sharezone}" \
                "${shareprotocol}" \
                "${sharesize:?}" \
        > "${sharetemp}-share.json"

cat << EOF
"created": $(jq '{name, id, status, size}' "${sharetemp}-share.json"),
EOF

        shareid=$(
            jq -r '.id' "${sharetemp}-share.json"
            )

        openstack \
            --os-cloud "${cloudname}" \
            share access create \
                --format json \
                --access-level 'ro' \
                "${shareid}" \
                "${accesstype}" \
                "${sharename}-ro" \
        > "${sharetemp}-ro-access.json"

        openstack \
            --os-cloud "${cloudname}" \
            share access create \
                --format json \
                --access-level 'rw' \
                "${shareid}" \
                "${accesstype}" \
                "${sharename}-rw" \
        > "${sharetemp}-rw-access.json"

#cat << EOF
#"access": {
#   "read":  $(jq '{id, state, access_to, access_level, access_type}' "${sharetemp}-ro-access.json"),
#   "write": $(jq '{id, state, access_to, access_level, access_type}' "${sharetemp}-rw-access.json")
#    }
#}
#EOF

cat << EOF
"access": {
    }
}
EOF

