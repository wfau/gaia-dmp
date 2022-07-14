#!/bin/sh
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

srcfile="$(basename ${0})"
srcpath="$(dirname $(readlink -f ${0}))"

# Include our JSON formatting tools.
source "${srcpath}/../../aglais/bin/json-tools.sh"

username=${1}
usertype=${2}
sharecloud=${3}
sharename=${4}
sharesize=${5}

sharepublic=True

# Check required params
if [ -z "${username}" ]
then
    jsonerror "[username] required"
    exit 1
fi

if [ -z "${usertype}" ]
then
    jsonerror "[usertype] required"
    exit 1
fi

if [ -z "${sharename}" ]
then
    jsonerror "[share name] required"
    exit 1
fi

if [ -z "${sharecloud}" ]
then
    jsonerror "[share cloud] required"
    exit 1
fi

# Set the Manila API version.
# https://stackoverflow.com/a/58806536
export OS_SHARE_API_VERSION=2.51

sharetype=ceph01_cephfs
sharezone=nova
shareprotocol=CEPHFS
shareaccesstype=cephx

sharejson=$(mktemp)
accessjson=$(mktemp)

openstack \
    --os-cloud "${sharecloud:?}" \
    share show \
        --format json \
        "${sharename:?}" \
    1> "${sharejson:?}" \
    2> "${debugerrorfile:?}"
    retcode=$?

if [ ${retcode} -gt 1 ]
then
    failmessage "Failed to select share [${sharename}], code [${retcode}]"
elif [ ${retcode} -eq 0 ]
then
    shareuuid=$(
        jq -r '.id' "${sharejson}"
        )
    sharestatus=$(
        jq -r '.status' "${sharejson}"
        )
    if [ "${sharestatus}" == "available" ]
    then
        passmessage "Share [${sharename}][${shareuuid}] status [${sharestatus}]"
    else
        failmessage "Share [${sharename}][${shareuuid}] status [${sharestatus}]"
    fi

    # TODO
    # Check and add access rules ...
    #

elif [ ${retcode} -eq 1 ]
then

    openstack \
        --os-cloud "${sharecloud:?}" \
        share create \
            --format json \
            --name "${sharename:?}" \
            --public "${sharepublic}" \
            --share-type "${sharetype:?}" \
            --availability-zone "${sharezone:?}" \
            "${shareprotocol:?}" \
            "${sharesize:?}" \
        1> "${sharejson:?}" \
        2> "${debugerrorfile:?}"
        retcode=$?

    if [ ${retcode} -ne 0 ]
    then
        failmessage "Failed to create share [${sharename}], return code [${retcode}]"
    else
        shareuuid=$(
            jq -r '.id' "${sharejson}"
            )
        sharestatus=$(
            jq -r '.status' "${sharejson}"
            )
        passmessage "Share [${sharename}] created [${shareuuid}][${sharestatus}]"

        while [ "${sharestatus}" == 'creating' ]
        do
            openstack \
                --os-cloud "${sharecloud:?}" \
                share show \
                    --format json \
                    "${shareuuid:?}" \
                1> "${sharejson:?}" \
                2> "${debugerrorfile:?}"
                retcode=$?

            if [ ${retcode} -eq 0 ]
            then
                sharestatus=$(
                    jq -r '.status' "${sharejson}"
                    )
                passmessage "Share [${sharename}][${shareuuid}] status [${sharestatus}]"
            else
                sharestatus="error"
                failmessage "Failed to get status for [${sharename}][${shareuuid}], return code [${retcode}]"
            fi
        done

        if [ "${sharestatus}" != "available" ]
        then
            failmessage "Failed to create share [${sharename}][${shareuuid}], status [${sharestatus}]"
        else
            openstack \
                --os-cloud "${sharecloud:?}" \
                share access create \
                    --format json \
                    --access-level 'ro' \
                    "${shareuuid:?}" \
                    "${shareaccesstype:?}" \
                    "${sharename:?}-ro" \
                1> "${accessjson:?}" \
                2> "${debugerrorfile:?}"
                retcode=$?

            if [ ${retcode} -eq 0 ]
            then
                passmessage "Share [${sharename}][${shareuuid}] [ro] access created"
            else
                failmessage "Failed to create [ro] access for [${sharename}][${shareuuid}]"
            fi

            openstack \
                --os-cloud "${sharecloud:?}" \
                share access create \
                    --format json \
                    --access-level 'rw' \
                    "${shareuuid:?}" \
                    "${shareaccesstype:?}" \
                    "${sharename:?}-rw" \
                1> "${accessjson:?}" \
                2> "${debugerrorfile:?}"
                retcode=$?

            if [ ${retcode} -eq 0 ]
            then
                passmessage "Share [${sharename}][${shareuuid}] [rw] access created"
            else
                failmessage "Failed to create [rw] access for [${sharename}][${shareuuid}]"
            fi
        fi
    fi
fi

cat << EOF
{
"name":   "${sharename}",
"uuid":   "${shareuuid}",
"status": "${sharestatus}",
"path":   "${mountpath}",
"owner":  "${fileowner}",
"group":  "${filegroup}",
$(jsondebug)
}
EOF

