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
sharename=${3}
sharecloud=${4}

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

sharecloud=${cloudname:?}
sharename=test-$(pwgen 8 1)
sharesize=5

sharejson=$(mktemp)
errorfile=$(mktemp)
accessjson=$(mktemp)

openstack \
    --os-cloud "${sharecloud:?}" \
    share show \
        --format json \
        "${sharename:?}" \
    1> "${sharejson:?}" \
    2> "${errorfile:?}"
    retcode=$?

if [ ${retcode} -gt 1 ]
then
    echo "FAIL : failed to select share [${sharename}], code [${retcode}]"
    echo "---- ----"
    cat "${errorfile}"
    echo "---- ----"

elif [ ${retcode} -eq 0 ]
then
    shareuuid=$(
        jq -r '.id' "${sharejson}"
        )
    echo "PASS : Share [${sharename}] selected [${shareuuid}]"

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
            --share-type "${sharetype:?}" \
            --availability-zone "${sharezone:?}" \
            "${shareprotocol:?}" \
            "${sharesize:?}" \
        1> "${sharejson:?}" \
        2> "${errorfile:?}"
        retcode=$?

    if [ ${retcode} -ne 0 ]
    then
        echo "FAIL : failed to create share [${sharename}], return code [${retcode}]"
        echo "---- ----"
        cat "${errorfile}"
        echo "---- ----"
    else
        shareuuid=$(
            jq -r '.id' "${sharejson}"
            )
        sharestatus=$(
            jq -r '.status' "${sharejson}"
            )
        echo "PASS : Share [${sharename}] created [${shareuuid}][${sharestatus}]"

        while [ "${sharestatus}" == 'creating' ]
        do
            openstack \
                --os-cloud "${sharecloud:?}" \
                share show \
                    --format json \
                    "${shareuuid:?}" \
                1> "${sharejson:?}" \
                2> "${errorfile:?}"
                retcode=$?

            if [ ${retcode} -eq 0 ]
            then
                sharestatus=$(
                    jq -r '.status' "${sharejson}"
                    )
                echo "PASS : Share [${sharename}] status [${shareuuid}][${sharestatus}]"
            else
                sharestatus="error"
                echo "FAIL : Failed to check share [${sharename}] status, return code [${retcode}]"
                echo "---- ----"
                cat "${errorfile}"
                echo "---- ----"
            fi
        done

        if [ "${sharestatus}" != "good" ]
        then
            echo "FAIL : Failed to create share [${sharename}], share status [${sharestatus}]"
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
                2> "${errorfile:?}"
                retcode=$?

            if [ ${retcode} -eq 0 ]
            then
                echo "PASS : [ro] access created"
            else
                echo "FAIL : Failed to create [ro] access to [${sharename}]"
                echo "---- ----"
                cat "${errorfile}"
                echo "---- ----"
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
                2> "${errorfile:?}"
                retcode=$?

            if [ ${retcode} -eq 0 ]
            then
                echo "PASS : [rw] access created"
            else
                echo "FAIL : Failed to create [rw] access to [${sharename}]"
                echo "---- ----"
                cat "${errorfile}"
                echo "---- ----"
            fi
        fi
    fi
fi











cat << EOF
{
"uuid":  "${cephuuid}",
"name":  "${cephname}"
"path":  "${mountpath}",
"owner": "${fileowner}",
"group": "${filegroup}",
$(jsondebug)
}
EOF

