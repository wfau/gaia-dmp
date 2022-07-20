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


    datahostname='data.aglais.uk'
    datahostuser='fedora'

    datacloud=iris-gaia-data

    homesize=1
    usersize=10

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
        local userhome=${3:?'userhome required'}
        local publickey=${4}
        local linuxuid=${5}
        #
        # Call Zeppelin to create the Linux user account.
        # Returns JSON.
        ssh zeppelin \
            "
            sudo /opt/aglais/bin/create-linux-user.sh '${username}' '${usertype}' '${userhome}' '${publickey}' '${linuxuid}'
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
        local sharecloud=${1:?'sharecloud required'}
        local sharename=${2:?'sharename required'}
        local mountpath=${3:?'mountpath required'}
        local mounthosts=${4:-'zeppelin'}
        local sharesize=${5:-10}
        local mountmode=${6:-'rw'}
        local publicshare=${7:-'True'}
        #
        # Call our Openstack script to create the share.
        # Returns JSON.
        /deployments/zeppelin/bin/create-ceph-share.sh \
            "${sharecloud}"  \
            "${sharename}"  \
            "${mountpath}"  \
            "${mounthosts}" \
            "${sharesize}"  \
            "${mountmode}"  \
            "${publicshare}"
        }

    cloneusernotebooks()
        {
        local username=${1:?'username required'}
        local usertype=${2:?'usertype required'}
        local password=${3}
        #
        # Call Zeppelin to clone the user's notebooks.
        # Returns JSON.
        ssh zeppelin \
            "
            clone-notebooks.sh '${username}' '${usertype}' '${password}'
            "
        }

    createusermain()
        {
        local username=${1:?'username required'}
        local usertype=${2:-'test'}
        local userrole=${3:-'user'}
        local publickey=${4}
        local linuxuid=${5}
        local password=${6}
        local passhash=${7}

        if [ "${usertype}" == 'live' ]
        then
            sharecloud=${datacloud}
        else
            sharecloud=${cloudname}
        fi

echo "{"
echo "\"homeshare\": "
        createcephshare \
            "${sharecloud}" \
            "${sharecloud}-home-${username}"  \
            "/home/${username}" \
            "zeppelin" \
            "${homesize}" \
            "rw"

echo ","
echo "\"usershare\": "
        createcephshare \
            "${sharecloud}" \
            "${sharecloud}-user-${username}"  \
            "/user/${username}" \
            "zeppelin:workers" \
            "${usersize}" \
            "rw"

echo ","
echo "\"linuxuser\": "
        local linuxuserjson=$(mktemp)
        createlinuxuser \
            "${username}" \
            "${usertype}" \
            "/home/${username}" \
            "${publickey}" \
            "${linuxuid}" \
        | tee "${linuxuserjson}"

echo ","
echo "\"hdfsspace\": "
        createhdfsspace \
            "${username}" \
            "${usertype}"

echo ","
echo "\"shirouser\": "
        local shirouserjson=$(mktemp)
        createshirouser \
            "${username}" \
            "${usertype}" \
            "${userrole}" \
            "${password}" \
            "${passhash}" \
        | tee "${shirouserjson}"

        local password=$(
            jq -r '.password' "${shirouserjson}"
            )

echo ","
echo "\"notebooks\": "
        cloneusernotebooks \
            "${username}" \
            "${usertype}" \
            "${password}"

echo "}"
        }

    #
    # Create users from a bash array.
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

    #
    # Create users from a YAML input file.
    createyamlusers()
        {
        local yamlfile=${1:?'yamlfile required'}
        local yamlpath=${2:-'users'}

        local userlist=$(
            yq -I 0 -o json ".${yamlpath}" "${yamlfile}"
            )

        local comma
        local username

        echo '{"users":['
        for username in $(
            jq --raw-output '.[].name' <<< ${userlist}
            )
        do
            echo "${comma}" ; comma=','
            local userinfo=$(
                jq --raw-output --null-input --argjson itemlist "${userlist}" "\$itemlist[] | select(.name == \"${username}\")"
                )
            createusermain \
                "${username}" \
                "$(jq --raw-output --null-input --argjson itemx "${userinfo}" '$itemx.type  // empty')"     \
                "$(jq --raw-output --null-input --argjson itemx "${userinfo}" '$itemx.role  // empty')"     \
                "$(jq --raw-output --null-input --argjson itemx "${userinfo}" '$itemx.publickey // empty')" \
                "$(jq --raw-output --null-input --argjson itemx "${userinfo}" '$itemx.linuxuid  // empty')" \
                "$(jq --raw-output --null-input --argjson itemx "${userinfo}" '$itemx.password  // empty')" \
                "$(jq --raw-output --null-input --argjson itemx "${userinfo}" '$itemx.passhash  // empty')"
        done
        echo ']}'
        }

    #
    # Convert JSON format array into YAML format array.
    json-yaml-users()
        {
        local jsonfile=${1:-'input JSON filename required'}
        local yamlfile=${2:-'output YAML filename required'}
        jq '
            {
            users: [
                .users[] |
                    {
                    name:      .linuxuser.name,
                    type:      (.linuxuser.type // ""),
                    role:      (.shirouser.role // ""),
                    linuxuid:  (.linuxuser.linuxuid // ""),
                    publickey: (.linuxuser.publickey // ""),
                    password:  (.shirouser.pasword // ""),
                    passhash:  (.shirouser.passhash // ""),
                    }
                ]
            }
            ' "${jsonfile}" \
        | yq -P \
        | tee "${yamlfile}"
        }

    #
    # Convert JSON format entry into YAML format entry.
    json-yaml-user()
        {
        local jsonfile=${1:-'input JSON filename required'}
        local yamlfile=${2:-'output YAML filename required'}
        jq '
            {
            name:      .linuxuser.name,
            type:      (.linuxuser.type // ""),
            role:      (.shirouser.role // ""),
            linuxuid:  (.linuxuser.linuxuid // ""),
            publickey: (.linuxuser.publickey // ""),
            password:  (.shirouser.pasword // ""),
            passhash:  (.shirouser.passhash // ""),
            }
            ' "${jsonfile}" \
        | yq -P \
        | tee "${yamlfile}"
        }

