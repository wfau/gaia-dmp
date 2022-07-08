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
# Script to invoke the Shiro hash function.
#

srcfile="$(basename ${0})"
srcpath="$(dirname $(readlink -f ${0}))"

# Include our JSON formatting tools.
source "${srcpath}/json-tools.sh"

# Include our Shiro password tools.
source "${srcpath}/shiro-tools.sh"

password=${1:-''}

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

cat << EOF
{
"pass": "${password}",
"hash": "${passhash}",
$(jsondebug)
}
EOF

