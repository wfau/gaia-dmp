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
#

srcfile="$(basename ${0})"
srcpath="$(dirname $(readlink -f ${0}))"

# Include our JSON formatting tools.
source "${srcpath}/json-tools.sh"

# Include our Shiro password tools.
source "${srcpath}/shiro-tools.sh"

username=${1}
usertype=${2}
userrole=${3:-'user'}
password=${4:-''}
passhash=${5:-''}

passlength=20
passcount=1

# TODO Move these to an Ansible managed config file.
databasename='shirodata'
databaseuser='shirouser'

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

# Check for empty hash.
if [ -n "${passhash}" ]
then
    skipmessage "hashpass skipped (done)"
else
    if [ -n "${password}" ]
    then
        skipmessage "passgen skipped (done)"
    else
        password=$(
            pwgen ${passlength} ${passcount} 2> "${debugerrorfile}"
            )
        if [ $? -eq 0 ]
        then
            passmessage "passgen done"
        else
            failmessage "passgen failed"
        fi
    fi

    passhash=$(
        hashpass "${password}" 2> "${debugerrorfile}"
        )
    if [ $? -eq 0 ]
    then
        passmessage "hashpass done"
    else
        failmessage "hashpass failed"
    fi
fi

# Check for empty values.
if [ -z "${username}" ]
then
    failmessage "null username"
elif [ -z "${passhash}" ]
then
    failmessage "null passhash"
elif [ -z "${userrole}" ]
then
    failmessage "null userrole"
else
    # Insert or update the database.
    mysql --database "${databasename}" --execute \
        "
        INSERT INTO users (
            username,
            password
            )
        VALUES (
            \"${username}\",
            \"${passhash}\"
            )
        ON DUPLICATE KEY UPDATE
            password = \"${passhash}\"
            ;
        INSERT INTO user_roles (
            username,
            role_name
            )
        VALUES (
            \"${username}\",
            \"${userrole}\"
            )
        ON DUPLICATE KEY UPDATE
            role_name = \"${userrole}\"
            ;
        " \
    2> "${debugerrorfile}"

    if [ $? -eq 0 ]
    then
        passmessage "database INSERT done"
    else
        failmessage "database INSERT failed"
    fi
fi

cat << EOF
{
"name": "${username}",
"type": "${usertype}",
"role": "${userrole}",
"pass": "${password}",
"hash": "${passhash}",
$(jsondebug)
}
EOF

