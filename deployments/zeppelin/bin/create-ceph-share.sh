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
source "/deployments/aglais/bin/json-tools.sh"

sharecloud=${1}
sharename=${2}
sharesize=${3}
mountpath=${4}
mountowner=${5}
mountgroup=${6}
mountmode=${7:-'rw'}
public=${8:-'True'}

# Set the Manila API version.
# https://stackoverflow.com/a/58806536
export OS_SHARE_API_VERSION=2.51

sharetype=ceph01_cephfs
sharezone=nova
shareprotocol=CEPHFS
shareaccesstype=cephx

# Check required params
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

if [ -z "${sharesize}" ]
then
    jsonerror "[share size] required"
    exit 1
fi

if [ -z "${mountpath}" ]
then
    jsonerror "[mount path] required"
    exit 1
fi

if [ -z "${mountowner}" ]
then
    jsonerror "[mount owner] required"
    exit 1
fi

if [ -z "${mountgroup}" ]
then
    jsonerror "[mount group] required"
    exit 1
fi

# Temp files to save JSON outputs.
sharejson=$(mktemp --suffix '.json')
accessjson=$(mktemp --suffix '.json')
ansiblejson=$(mktemp --suffix '.json')

openstack \
    --os-cloud "${sharecloud}" \
    share show \
        --format json \
        "${sharename}" \
    1> "${sharejson}" \
    2> "${debugerrorfile}"
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
        --os-cloud "${sharecloud}" \
        share create \
            --format json \
            --name "${sharename}" \
            --public "${public}" \
            --share-type "${sharetype}" \
            --availability-zone "${sharezone}" \
            "${shareprotocol}" \
            "${sharesize}" \
        1> "${sharejson}" \
        2> "${debugerrorfile}"
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
                --os-cloud "${sharecloud}" \
                share show \
                    --format json \
                    "${shareuuid}" \
                1> "${sharejson}" \
                2> "${debugerrorfile}"
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
                --os-cloud "${sharecloud}" \
                share access create \
                    --format json \
                    --access-level 'ro' \
                    "${shareuuid}" \
                    "${shareaccesstype}" \
                    "${sharename}-ro" \
                1> "${accessjson}" \
                2> "${debugerrorfile}"
                retcode=$?

            if [ ${retcode} -eq 0 ]
            then
                passmessage "Share [${sharename}][${shareuuid}] [ro] access created"
            else
                failmessage "Failed to create [ro] access for [${sharename}][${shareuuid}]"
            fi

            openstack \
                --os-cloud "${sharecloud}" \
                share access create \
                    --format json \
                    --access-level 'rw' \
                    "${shareuuid}" \
                    "${shareaccesstype}" \
                    "${sharename}-rw" \
                1> "${accessjson}" \
                2> "${debugerrorfile}"
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

if [ "${sharestatus}" != "available" ]
then
    skipmessage "Mounting share [${sharename}][${shareuuid}] skipped, status [${sharestatus}]"
else

    locations=$(
        jq '.export_locations' "${sharejson}"
        )

    cephpath=$(
        sed '
            s/^.*path = \([^\\]*\).*$/\1/
            s/^\(.*\):\(\/.*\)$/\2/
            ' <<< ${locations}
            )

    cephnodes=$(
        sed '
            s/^.*path = \([^\\]*\).*$/\1/
            s/^\(.*\):\(\/.*\)$/\1/
            ' <<< ${locations}
            )

    accesslist=$(mktemp --suffix '.json')
    openstack \
        --os-cloud "${sharecloud}" \
        share access list \
            --format json \
            "${shareuuid}" \
        1> "${accesslist}" \
        2> "${debugerrorfile}"
        retcode=$?

    if [ ${retcode} -ne 0 ]
    then
        failmessage "Failed to select access rules for [${sharename}][${shareuuid}]"
    else

        # Yes, some numpty thought it was a good idea to change the JSON field names.
        # Changing 'id' to 'ID', and 'access_level' to 'Access Level'.
        # Possibly because they thought it would be pretty ?
        # Waste of an afternoon chasing that down.
        accessrule=$(
            jq -r '.[] | select(.access_level == "'${mountmode}'") | .id' "${accesslist}"
            )
        if [ -z "${accessrule}" ]
        then
            accessrule=$(
                jq -r '.[] | select(."Access Level" == "'${mountmode}'") | .ID' "${accesslist}"
                )
        fi
        if [ -z "${accessrule}" ]
        then
            failmessage "Failed to find [${mountmode}] access rule for [${sharename}][${shareuuid}]"
        else
            openstack \
                --os-cloud "${sharecloud}" \
                share access show \
                    --format json \
                    "${accessrule}" \
                1> "${accessjson}" \
                2> "${debugerrorfile}"
                retcode=$?

            if [ ${retcode} -ne 0 ]
            then
                failmessage "Failed to select access rule [${accessrule}] for [${sharename}][${shareuuid}]"
            else
                cephname=$(
                    jq -r '.access_to' "${accessjson}"
                    )
                cephkey=$(
                    jq -r '.access_key' "${accessjson}"
                    )

                pushd "/deployments/hadoop-yarn/ansible" &> /dev/null

                    mountyaml=$(mktemp --suffix '.yaml')
                    cat > "${mountyaml}" << EOF
mountpath:  '${mountpath}'
mountmode:  '${mountmode}'
mountowner: '${mountowner}'
mountgroup: '${mountgroup}'

cephname:   '${cephname}'
cephnodes:  '${cephnodes}'
cephpath:   '${cephpath}'
cephkey:    '${cephkey}'
EOF

                    statusyml="/tmp/aglais-status.yml"
                    deployconf=$(
                        yq '.aglais.status.deployment.conf' "${statusyml}" \
                        2> "${debugerrorfile}"
                        )
                    retcode=$?
                    if [ ${retcode} -ne 0 ]
                    then
                        failmessage "Failed to read Ansible config [${statusyml}]"
                    else
                        export ANSIBLE_STDOUT_CALLBACK=ansible.posix.json
                        ansible-playbook \
                            --inventory  "config/${deployconf}.yml" \
                            --extra-vars "@${mountyaml}" \
                            '51-cephfs-mount.yml' \
                        1> "${ansiblejson}" \
                        2> "${debugerrorfile}"
                        retcode=$?

                        if [ ${retcode} -eq 0 ]
                        then
                            passmessage "Ansible mount playbook succeded"
                        else
                            failmessage "Ansible mount playbook failed"
                        fi
                    fi

                popd &> /dev/null
            fi
        fi
    fi
fi

cat << EOF
{
"name":   "${sharename}",
"uuid":   "${shareuuid}",
"status": "${sharestatus}",
"ceph": {
    "nodes": "${cephnodes}",
    "path":  "${cephpath}",
    "name":  "${cephname}",
    "key":   "${cephkey}"
    },
"mount": {
    "path":  "${mountpath}",
    "mode":  "${mountmode}",
    "owner": "${mountowner}",
    "group": "${mountgroup}"
    },
"openstack": $([ -s "${sharejson}"   ] && cat "${sharejson}"   || echo "{}"),
"ansible":   $([ -s "${ansiblejson}" ] && cat "${ansiblejson}" || echo "{}"),
$(jsondebug)
}
EOF


