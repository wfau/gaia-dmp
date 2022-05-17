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

# -----------------------------------------------------
# Settings ...

#    set -eu
#    set -o pipefail
#
#    binfile="$(basename ${0})"
#    binpath="$(dirname $(readlink -f ${0}))"
#    treetop="$(dirname $(dirname ${binpath}))"
#
#    echo ""
#    echo "---- ---- ----"
#    echo "File [${binfile}]"
#    echo "Path [${binpath}]"
#    echo "Tree [${treetop}]"
#    echo "---- ---- ----"
#

    hadoopuid=5000
    hadoopgid=5000

    defaultsharesize=10

    datahostname='data.aglais.uk'
    datahostuser='fedora'

    # Get the next available uid
    # https://www.commandlinefu.com/commands/view/5684/determine-next-available-uid
    # TODO Move this to the Zeppelin node.
    getnextuid()
        {
        getent passwd | awk -F: '($3>600) && ($3<60000) && ($3>maxuid) { maxuid=$3; } END { print maxuid+1; }'
        }

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

    # Generate a new password hash.
    newpasshash()
        {
        local password="${1:?}"
        java \
            -jar "${HOME}/lib/shiro-tools-hasher.jar" \
            -i 500000 \
            -f shiro1 \
            -a SHA-256 \
            -gss 128 \
            '${password:?}'
        }

    createshirouser()
        {
        local user="${1:?}"
        local hash="$(getpasshash \"${user}\")";
        local pass=''

        if [ -z "${hash}" ]
        then
            pass=$(
                pwgen 30 1
                )
            hash=$(
                newpasshash "${pass}"
                )
        fi

        #
        # Call to Zeppelin node to create the user account in the Shiro database.
        #

cat << EOF
{
"pass": "${pass}",
"hash": "${hash}"
}
EOF
        }

    createlinuxuser()
        {
        local user="${1:?}"
        local uid="${2}"
        local gid="${3}"
        local home="${4:-/home/${user}}"

        #
        # Call to Zeppelin node to create the Linux user account.
        # The test for zero and the call to 'getnextuid' would be done on the Zeppelin node.
        #

        if [ -z ${uid} ]
        then
            uid=$(getnextuid)
        fi
        if [ -z ${gid} ]
        then
            gid=${uid}
        fi


cat << EOF
{
"name": "${user}",
"uid":  ${uid},
"gid":  ${gid},
"home": "${home}"
}
EOF
        }

    createusershare()
        {
        local username="${1:?}"
        local uid="${2:?}"
        local gid="${3:?}"
        local sharepath="${4:-/user/${user}}"
        local sharesize="${5:-${defaultsharesize}}"
        local sharename="user-data-${username}"
        local shareuuid=$(uuidgen)

        #
        # Call to Openstack to create the share.
        #

        #
        # Call to Zeppelin node to mount the share.
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


    createusermain()
        {
        local user="${1:?}"
        local uid="${2}"
        local gid="${3}"
        local home="${4}"
        local data="${5}"
        local size="${6}"

        shirouserjson=$(
            createshirouser \
                "${user}"
            )

        linuxuserjson=$(
            createlinuxuser \
                "${user}" \
                "${uid}"  \
                "${gid}"  \
                "${home}"
            )

        uid=$(jq -r '.uid' <<< ${linuxuserjson})
        gid=$(jq -r '.gid' <<< ${linuxuserjson})

        shareinfojson=$(
            createusershare \
                "${user}" \
                "${uid}"  \
                "${hadoopgid}" \
                "${data}" \
                "${size}"
            )

cat << EOF
{
"linux": ${linuxuserjson},
"shiro": ${shirouserjson},
"share": ${shareinfojson}
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
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.gid  // empty')" \
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.home // empty')" \
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.data.path // empty')" \
                "$(jq --raw-output --null-input --argjson user "${userinfo}" '$user.data.size // empty')"
        done <<< $(
            yq -I 0 -o json '.'${yamlpath}'[]' \
                "${yamlfile}"
            )
        echo ']}'
        }

