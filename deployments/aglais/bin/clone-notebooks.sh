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

#zeppbasedir="/home/fedora/zeppelin"
#usernotebookdir="${zeppbasedir}/notebook/Users/${username}"
#userexamplesdir="${usernotebookdir}/examples"

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

cookiefile=$(mktemp)
resultfile=$(mktemp)

# Login to Zeppelin
curl \
    --request 'POST' \
    --no-progress-meter \
    --cookie-jar "${cookiefile}" \
    --data "userName=${username}" \
    --data "password=${userpass}" \
    "${zeppelinurl}/api/login" \
    1> "${resultfile}" \
    2> "${debugerrorfile}"
    retcode=$?

if [ ${retcode} -ne 0 ]
then
    failmessage "Login [${username}] failed - retcode [${retcode}]"
else
    loginstatus=$(
        jq -r '.status' "${resultfile}"
        )
    if [ "${loginstatus}" != "OK" ]
    then
        failmessage "Login [${username}] failed - status [${status}]"
    else
        passmessage "Login [${username}] done"
    fi
fi

# If login worked.
if [ ${loginstatus} == "PASS" ]
then

public_examples="/Public Examples"
private_examples="/Users/${username}/examples"

# List the (visible) notebooks
curl \
    --no-progress-meter \
    --cookie "${cookiefile}" \
    "${zeppelinurl:?}/api/notebook" \
    1> "${resultfile}" \
    2> "${errorfile}"
    retcode=$?

# Count the user's examples
if [ ${retcode} -ne 0 ]
then
    echo "Count failed - error code [${retcode}]"
    cat "${errorfile}"
else
    if [ -s "${resultfile}" ]
    then
        count=$(
            jq "
                [
                .body[] | select(.path | startswith(\"${private_examples}\")) | {id, path}
                ] | length
                " "${resultfile}"
            )
    else
        count=0
    fi
    if [ ${count} -ne 0 ]
    then
        echo "Examples found [${count}]"
    else
        echo "Examples needed [${count}]"

        # Clone the public examples
        for noteid in $(
            jq -r "
                .body[] | select(.path | startswith(\"${public_examples}\")) | .id
                " "${resultfile}"
            )
        do
            notepath=$(
                jq -r '
                    .body[] | select(.id == "'${noteid}'") | .path
                    ' "${resultfile}"
                )
            clonepath=${notepath/${public_examples}/${private_examples}}
            echo
            echo "ident [${noteid}]"
            echo "path  [${notepath}]"
            echo "path  [${clonepath}]"

            curl \
                --location \
                --request POST \
                --no-progress-meter \
                --cookie "${cookiefile}" \
                --header 'Content-Type: application/json' \
                --data "{
                    \"name\": \"${clonepath}\"
                    }" \
                "${zeppelinurl}/api/notebook/${noteid}" \
                1> "${resultfile}" \
                2> "${errorfile}"
                retcode=$?

            if [ ${retcode} -ne 0 ]
            then
                echo "Clone failed - error code [${retcode}]"
                cat "${errorfile}"
            else
                status=$(
                    jq -r '.status' "${resultfile}"
                    )
                exception=$(
                    jq -r '.exception' "${resultfile}"
                    )
                if [ -n "${exception}" ]
                then
                    echo "Clone failed - exception [${exception}] "
                else
                    echo "Clone done - [${clonepath}]"
                fi
            fi
        done
    fi
fi



cat << EOF
{
"user": "${username}",
$(jsondebug)
}
EOF

