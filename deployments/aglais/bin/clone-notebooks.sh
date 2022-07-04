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
source "${srcpath}/json-tools.sh"

username=${1}
usertype=${2}
userpass=${3}

zeppelinurl='http://localhost:8080'
zeppbasedir="/home/fedora/zeppelin"
usernotebookdir="${zeppbasedir}/notebook/Users/${username}"
userexamplesdir="${usernotebookdir}/examples"

cookiefile=$(mktemp)

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

if [ -z "${userpass}" ]
then
    jsonerror "[userpass] required"
    exit 1
fi

agmkdir "${usernotebookdir}" "${username}:${username}" "u=rwx,g=rx,o=rx"

agmkdir "${userexamplesdir}" "${username}:${username}" "u=rwx,g=rx,o=rx"

# Login

# Check for user examples
userexamplespath=



            echo '['

            curl \
            --silent \
            --request 'POST' \
            --cookie-jar "${zepcookies:?}" \
            --data "userName=${NEW_USERNAME:?}" \
            --data "password=${NEW_PASSWORD:?}" \
            ${ZEPPELIN_URL:?}/api/login

            curl --silent --cookie "${zepcookies:?}" "${ZEPPELIN_URL:?}/api/notebook"| jq -r '.body[] | select(.path | startswith("/Public")) | [.id, .path] | @tsv' |
            while IFS=$'\t' read -r id path; do
              echo ','
              curl --silent -L -H 'Content-Type: application/json' -d "{'name': '${path/Public Examples/Users/$NEW_USERNAME}' }" --request POST --cookie "${zepcookies:?}" $ZEPPELIN_URL/api/notebook/$id
            done
            echo ']'



cat << EOF
{
"path":  "${hdfspath}",
"owner": "${username}",
"group": "${hdfsgroup}",
$(jsondebug)
}
EOF

