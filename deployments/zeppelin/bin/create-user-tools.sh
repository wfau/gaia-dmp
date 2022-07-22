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

    # TODO Move this to a separate script, client-tools or client-setup.
    # https://github.com/wfau/aglais/issues/893
    datahostname='data.aglais.uk'
    datahostuser='fedora'
    datacloud='iris-gaia-data'

    homesize=1
    usersize=10

    # Get a secret.
    # Calls 'getsecret' on the data VM.
    # TODO Move this to a separate script, client-tools or client-setup.
    # https://github.com/wfau/aglais/issues/893
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
        local password=${1:?'password required'}
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
        local linuxuid=${4}
        local publickey=${5}
        #
        # Call Zeppelin to create the Linux user account.
        # Returns JSON.
        ssh zeppelin \
            "
            sudo /opt/aglais/bin/create-linux-user.sh '${username}' '${usertype}' '${userhome}' '${linuxuid}' '${publickey}'
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
        local linuxuid=${4}
        local password=${5}
        local passhash=${6}
        local publickey=${7}
        local homesharename=${8}
        local homesharecloud=${9}
        local usersharename=${10}
        local usersharecloud=${11}

        local typesharecloud
        if [ "${usertype}" == 'live' ]
        then
            typesharecloud=${datacloud}
        else
            typesharecloud=${cloudname}
        fi

        local homesharepath="/home/${username}"

        if [ -z "${homesharecloud}" ]
        then
            homesharecloud="${typesharecloud}"
        fi
        if [ -z "${homesharename}" ]
        then
            homesharename="${homesharecloud}-home-${username}"
        fi

        local usersharepath="/user/${username}"
        if [ -z "${usersharecloud}" ]
        then
            usersharecloud="${typesharecloud}"
        fi
        if [ -z "${usersharename}" ]
        then
            usersharename="${usersharecloud}-user-${username}"
        fi

echo "{"
echo "\"username\": \"${username}\","
echo "\"usertype\": \"${usertype}\","
echo "\"homeshare\": "
        createcephshare \
            "${homesharecloud}" \
            "${homesharename}"  \
            "${homesharepath}"  \
            "zeppelin" \
            "${homesize}" \
            "rw"

echo ","
echo "\"usershare\": "
        createcephshare \
            "${usersharecloud}" \
            "${usersharename}"  \
            "${usersharepath}"  \
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
            "${linuxuid}" \
            "${publickey}" \
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

    # TODO
    # Create a single user from a YAML input file.
    # createyamluser()

    #
    # Create users from a YAML input file.
    # If we have more than one entry with the same name it will only read the first and skip the rest.
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
            local userjson=$(
                jq --raw-output --null-input --argjson itemlist "${userlist}" "[\$itemlist[] | select(.name == \"${username}\")]"
                )
            createusermain \
                "${username}" \
                "$(jq --raw-output --null-input --argjson itemx "${userjson}" '$itemx[0].type  // empty')"     \
                "$(jq --raw-output --null-input --argjson itemx "${userjson}" '$itemx[0].role  // empty')"     \
                "$(jq --raw-output --null-input --argjson itemx "${userjson}" '$itemx[0].linuxuid  // empty')" \
                "$(jq --raw-output --null-input --argjson itemx "${userjson}" '$itemx[0].password  // empty')" \
                "$(jq --raw-output --null-input --argjson itemx "${userjson}" '$itemx[0].passhash  // empty')" \
                "$(jq --raw-output --null-input --argjson itemx "${userjson}" '$itemx[0].publickey // empty')" \
                "$(jq --raw-output --null-input --argjson itemx "${userjson}" '$itemx[0].homeshare.name  // empty')" \
                "$(jq --raw-output --null-input --argjson itemx "${userjson}" '$itemx[0].homeshare.cloud // empty')" \
                "$(jq --raw-output --null-input --argjson itemx "${userjson}" '$itemx[0].usershare.name  // empty')" \
                "$(jq --raw-output --null-input --argjson itemx "${userjson}" '$itemx[0].usershare.cloud // empty')"
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
                    password:  (.shirouser.password // ""),
                    passhash:  (.shirouser.passhash // ""),
                    publickey: (.linuxuser.publickey // ""),
                    homeshare: {
                        name:  (.homeshare.name // ""),
                        cloud: (.homeshare.cloud // "")
                        },
                    usershare: {
                        name:  (.usershare.name // ""),
                        cloud: (.usershare.cloud // "")
                        }
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
            password:  (.shirouser.password // ""),
            passhash:  (.shirouser.passhash // ""),
            publickey: (.linuxuser.publickey // ""),
            homeshare: {
                name:  (.homeshare.name // ""),
                cloud: (.homeshare.cloud // "")
                },
            usershare: {
                name:  (.usershare.name // ""),
                cloud: (.usershare.cloud // "")
                }
            }
            ' "${jsonfile}" \
        | yq -P \
        | tee "${yamlfile}"
        }


    #
    # List the shiro account information (safe).
    list-shiro-info()
        {
        local jsonfile=${1:-'input JSON filename required'}
        jq '[
            .users[] | {
                username: .username,
                password: .shirouser.password,
                hashhash: .shirouser.hashhash
                }
            ]' "${jsonfile}"
        }

    #
    # List the shiro account information (full).
    list-shiro-full()
        {
        local jsonfile=${1:-'input JSON filename required'}
        jq '[
            .users[] | {
                username: .username,
                password: .shirouser.password,
                passhash: .shirouser.passhash,
                hashhash: .shirouser.hashhash
                }
            ]' "${jsonfile}"
        }

    #
    # List the CephFS share information.
    list-ceph-info()
        {
        local jsonfile=${1:-'input JSON filename required'}
        jq '[
            .users[] | {
                username: .username,
                usershare: {
                    name:   .usershare.name,
                    cloud:  .usershare.cloud,
                    status: .usershare.status
                    },
                homeshare: {
                    name:   .usershare.name,
                    cloud:  .usershare.cloud,
                    status: .usershare.status
                    }
                }
            ]' "${jsonfile}"
        }

    #
    # Import our live users
    import-live-users()
        {
        createyamlusers \
            /deployments/common/users/live-users.yml \
        | tee /tmp/live-users.json
        }

    #
    # Import some simple test users
    import-test-users()
        {
        createyamlusers \
            /deployments/common/users/test-users.yml \
        | tee /tmp/test-users.json
        }


