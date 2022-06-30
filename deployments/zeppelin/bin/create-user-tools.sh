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

    # Get a secret.
    # Calls 'getsecret' on the data VM.
    getsecret()
        {
        local key=${1:?'key required'}
        ssh -n "${datahostuser:?}@${datahostname:?}" \
            "
            getsecret '${key:?}'
            "
        }


    # Get the password hash for a user name.
    # Calls 'getpasshash' on the data VM.
    getpasshash()
        {
        local username=${1:?'username required'}
        ssh -n "${datahostuser:?}@${datahostname:?}" \
            "
            getpasshash '${username:?}'
            "
        }

    createshirohash()
        {
        local password=${1:-''}
        #
        # Call Zeppelin to hash the password.
        # Returns JSON.
        ssh zeppelin \
            "
            /opt/aglais/bin/create-shiro-hash.sh '${password}'
            "
        }

    createshirouser()
        {
        local username=${1:?'username required'}
        local usertype=${2:?'usertype required'}
        local userrole=${3:-'user'}
        local password=${4:-''}
        local passhash=${5:-$(getpasshash \"${username}\")}
        #
        # Call Zeppelin to create a user account in the Shiro database.
        # Returns JSON.
        ssh zeppelin \
            "
            /opt/aglais/bin/create-shiro-user.sh '${username}' '${usertype}' '${userrole}' '${password}' '${passhash}'
            "
        }

    createlinuxuser()
        {
        local username=${1:?'username required'}
        local usertype=${2:?'usertype required'}
        local userpkey=${3}
        local useruid=${4}
        #
        # Call Zeppelin to create the Linux user account.
        # Returns JSON.
        ssh zeppelin \
            "
            sudo /opt/aglais/bin/create-linux-user.sh '${username}' '${usertype}' '${userpkey}' '${useruid}'
            "
        }

    createhdfsspace()
        {
        local username=${1:?'username required'}
        local usertype=${2:?'usertype required'}
        #
        # Call Zeppelin to create the user's HDFS space.
        # Returns JSON.
        ssh zeppelin \
            "
            create-hdfs-space.sh '${username}' '${usertype}'
            "
        }

    createcephshare()
        {
        local cloudname=${1:?'cloudname required'}
        local username=${2:?'username required'}
        local usertype=${3:?'usertype required'}
        local uid=${4:?'user id required'}

        local cephroot="/ceph-${usertype}"
        local sharepath=${5:-${cephroot}/${username}}
        local sharesize=${6:-${defaultsharesize}}
        local sharename=${usertype}-${username}
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
        local username=${1:?'username required'}
        local usertype=${2:?'usertype required'}
        local userpass=${3}
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
        local username=${1:?'username required'}
        local usertype=${2:-'test'}
        local userpkey=${3}
        local useruid=${4}
        local datapath=${5}
        local datasize=${6}

        linuxuserjson=$(
            createlinuxuser \
                "${username}" \
                "${usertype}" \
                "${userpkey}" \
                "${useruid}"
            )

        useruid=$(
            jq -r '.uid' <<< ${linuxuserjson}
            )

# TODO Create user shares ..
#        cephsharejson=$(
#            createcephshare \
#                "${username}" \
#                "${usertype}" \
#                "${useruid}"  \
#                "${datapath}" \
#                "${datasize}"
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

        local userpass=$(
            jq -r '.pass' <<< ${shirouserjson}
            )

        notebooksjson=$(
            cloneusernotebooks \
                "${username}" \
                "${usertype}" \
                "${userpass}"
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

