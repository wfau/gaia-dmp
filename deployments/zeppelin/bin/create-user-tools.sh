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

    defaultsharesize=10

    datahostname='data.aglais.uk'
    datahostuser='fedora'

    # Get the password hash for a user name.
    # Calls 'getpasshash' on data project VM.
    getpasshash()
        {
        local username="${1:?'username required'}"
        ssh -n "${datahostuser:?}@${datahostname:?}" \
            "
            getpasshash '${username:?}'
            "
        }

    createshirouser()
        {
        local username="${1:?'username required'}"
        local usertype="${2:?'usertype required'}"
        local passhash="$(getpasshash \"${username}\")"
        #
        # Call Zeppelin to create a user account in the Shiro database.
        # Returns JSON.
        ssh zeppelin \
            "
            create_mysql_user.sh '${username}' '${usertype}' '${passhash}'
            "
        }

    createlinuxuser()
        {
        local username="${1:?'username required'}"
        local usertype="${2:?'usertype required'}"
        local uid="${3}"
        local home="${4}"
        #
        # Call Zeppelin to create the Linux user account.
        # Returns JSON.
        ssh zeppelin \
            "
            create_unix_user.sh '${username}' '${usertype}' '${uid}' '${home}'
            "
        }

    createhdfsspace()
        {
        local username="${1:?'username required'}"
        local usertype="${2:?'usertype required'}"
        #
        # Call Zeppelin to create the user's HDFS space.
        # Returns JSON.
        ssh zeppelin \
            "
            create_hdfs_home.sh '${username}' '${usertype}'
            "
        }

    createcephshare()
        {
        local cloudname="${1:?'cloudname required'}"
        local username="${2:?'username required'}"
        local usertype="${3:?'usertype required'}"
        local uid="${4:?'user id required'}"

        local cephroot="/ceph-${usertype}"
        local sharepath="${5:-${cephroot}/${username}}"
        local sharesize="${6:-${defaultsharesize}}"
        local sharename="${usertype}-${username}"
        local shareuuid=$(uuidgen)

        #
        # Call to Openstack to create the share.
        #
        create-ceph-share.sh \
            "${cloudname}" \
            "${sharename}" \
            "${sharesize}"


        #
        # Call to Zeppelin to mount the share.
        #

cat << EOF
{
"name": "${sharename}",
"uuid": "${shareuuid}",
"path": "${sharepath}",
"size":  ${sharesize}
}
EOF
        }

    cloneusernotebooks()
        {
        local username="${1:?'username required'}"
        local usertype="${2:?'usertype required'}"
        local userpass="${3}"
        #
        # Call Zeppelin to clone the user's notebooks.
        # Returns null (could return JSON list).
        if [ -n "${userpass}" ]
        then
            ssh zeppelin \
                "
                create_notebook_clone.sh '${username}' '${usertype}' '${userpass}'
                "
        else
            echo "{}"
        fi
        }

    createusermain()
        {
        local username="${1:?'username required'}"
        local usertype="${2:-'test'}"
        local uid="${3}"
        local home="${4}"
        local data="${5}"
        local size="${6}"

        linuxuserjson=$(
            createlinuxuser \
                "${username}" \
                "${usertype}" \
                "${uid}"  \
                "${home}"
            )

        uid=$(
            jq -r '.uid' <<< ${linuxuserjson}
            )

#        cephsharejson=$(
#            createcephshare \
#                "${username}" \
#                "${usertype}" \
#                "${uid}"  \
#                "${data}" \
#                "${size}"
#            )

        hdfsspacejson=$(
            createhdfsspace \
                "${username}" \
                "${usertype}"
            )

        shirouserjson=$(
            createshirouser \
                "${username}" \
                "${usertype}"
            )

        local pass=$(
            jq -r '.pass' <<< ${shirouserjson}
            )

        notebooksjson=$(
            cloneusernotebooks \
                "${username}" \
                "${usertype}" \
                "${pass}"
            )

cat << EOF
{
"linuxuser": ${linuxuserjson},
"shirouser": ${shirouserjson},
"hdfsspace": ${hdfsspacejson},
"notebooks": ${notebooksjson}
}
EOF
        }

    createarrayusers()
        {
        local usernames=("$@")
        local username
        local comma=''
        echo '{ "users": ['
        for username in "${usernames[@]}"
        do
            echo "${comma}" ; comma=','
            createusermain "${username}"
        done
        echo ']}'
        }

    createyamlusers()
        {
        local yamlfile=${1:?'yamlfile required'}
        local yamlpath=${2:-'users'}
        local comma=''

        echo '{ "users": ['
        while read -r userinfo
        do
            echo "${comma}" ; comma=','
            createusermain \
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.name // empty')" \
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.type // empty')" \
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.uid  // empty')" \
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.home // empty')" \
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.data.path // empty')" \
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.data.size // empty')"
        done <<< $(
            yq -I 0 -o json '.'${yamlpath}'[]' \
                "${yamlfile}"
            )
        echo ']}'
        }

