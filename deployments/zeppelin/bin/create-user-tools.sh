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
        local key="${1:?}"
        ssh -n "${datahostuser:?}@${datahostname:?}" \
            "
            getpasshash '${key:?}'
            "
        }

    createshirouser()
        {
        local user="${1:?}"
        local hash="$(getpasshash \"${user}\")"
        #
        # Call Zeppelin to create a user account in the Shiro database.
        # Returns JSON.
        ssh zeppelin \
            "
            create_mysql_user.sh '${user}' '${hash}'
            "
        }

    createlinuxuser()
        {
        local user="${1:?}"
        local uid="${2}"
        local home="${3}"
        #
        # Call Zeppelin to create the Linux user account.
        # Returns JSON.
        ssh zeppelin \
            "
            create_unix_user.sh '${user}' '${uid}' '${home}'
            "
        }

    createhdfsspace()
        {
        local user="${1:?}"
        #
        # Call Zeppelin to create the user's HDFS space.
        # Returns null.
        ssh zeppelin \
            "
            create_hdfs_user.sh '${user}'
            "
        }

    createusershare()
        {
        local username="${1:?}"
        local uid="${2:?}"
        local sharepath="${3:-/user/${user}}"
        local sharesize="${4:-${defaultsharesize}}"
        local sharename="user-data-${username}"
        local shareuuid=$(uuidgen)

        #
        # Call to Openstack to create the share.
        #

        #
        # Call to Zeppelin to mount the share.
        #

cat << EOF
{
"name": "${sharename}",
"uuid": "${shareuuid}",
"path": "${sharepath}",
"size": ${sharesize}
}
EOF
        }

    cloneusernotebooks()
        {
        local user="${1:?}"
        local pass="${2:?}"
        #
        # Call Zeppelin to clone the user's notebooks.
        # Returns null (could return JSON list).
        if [ -n "${pass}" ]
        then
            ssh zeppelin \
                "
                create_notebook_clone.sh '${user}' '${pass}'
                "
        fi
        }

    createusermain()
        {
        local user="${1:?}"
        local uid="${2}"
        local home="${3}"
        local data="${4}"
        local size="${5}"

        shirouserjson=$(
            createshirouser \
                "${user}"
            )

        pass=$(jq -r '.pass' <<< ${shirouserjson})

        linuxuserjson=$(
            createlinuxuser \
                "${user}" \
                "${uid}"  \
                "${home}"
            )

        uid=$(jq -r '.uid' <<< ${linuxuserjson})

        cephsharejson=$(
            createusershare \
                "${user}" \
                "${uid}"  \
                "${data}" \
                "${size}"
            )

        hdfsspacejson=$(
            createhdfsspace \
                "${user}"
            )

        notebooksjson=$(
            cloneusernotebooks \
                "${user}" \
                "${pass}"
            )

cat << EOF
{
"linuxuser": ${linuxuserjson},
"shirouser": ${shirouserjson},
"cephshare": ${cephsharejson},
"notebooks:" ${notebooksjson}
}
EOF
        }

    createarrayusers()
        {
        local names=("$@")
        local name
        local comma=''
        echo '{ "users": ['
        for name in "${names[@]}"
        do
            echo "${comma}" ; comma=','
            createusermain "${name}"
        done
        echo ']}'
        }

    createyamlusers()
        {
        local yamlfile=${1:?}
        local yamlpath=${2:-'users'}
        local comma=''

        echo '{ "users": ['
        while read -r userinfo
        do
            echo "${comma}" ; comma=','
            createusermain \
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.name // empty')" \
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

