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
    skipmessage "Notebooks skipped - null password"
else

    cookiefile=$(mktemp)
    loginresult=$(mktemp)
    notebooklist=$(mktemp)
    cloneresult=$(mktemp)

    # Login to Zeppelin
    curl \
        --silent \
        --show-error \
        --request 'POST' \
        --cookie-jar "${cookiefile}" \
        --data "userName=${username}" \
        --data "password=${userpass}" \
        "${zeppelinurl}/api/login" \
        1> "${loginresult}" \
        2> "${debugerrorfile}"
        retcode=$?

    if [ ${retcode} -ne 0 ]
    then
        failmessage "Login [${username}] failed - retcode [${retcode}]"
    else
        loginstatus=$(
            jq -r '.status' "${loginresult}"
            )
        if [ "${loginstatus}" != "OK" ]
        then
            failmessage "Login [${username}] failed - status [${loginstatus}]"
        else
            passmessage "Login [${username}] done"
        fi
    fi

    # If login worked.
    if [ "${loginstatus}" == "OK" ]
    then

        public_examples="/Public Examples"
        private_examples="/Users/${username}/examples"

        # List the (visible) notebooks
        curl \
            --silent \
            --show-error \
            --cookie "${cookiefile}" \
            "${zeppelinurl}/api/notebook" \
            1> "${notebooklist}" \
            2> "${debugerrorfile}"
            retcode=$?

        # Count the user's examples
        if [ ${retcode} -ne 0 ]
        then
            failmessage "Count failed - error code [${retcode}]"
        else
            # If the list isn't empty.
            if [ -s "${notebooklist}" ]
            then
                # Count the user's examples.
                count=$(
                    jq "
                        [
                        .body[] | select(.path | startswith(\"${private_examples}\")) | {id, path}
                        ] | length
                        " "${notebooklist}"
                    )

                # Check if the user already has some examples.
                if [ ${count} -ne 0 ]
                then
                    skipmessage "Examples found [${count}]"
                else
                    # Clone the public examples
                    for noteid in $(
                        jq -r "
                            .body[] | select(.path | startswith(\"${public_examples}\")) | .id
                            " "${notebooklist}"
                        )
                    do
                        notepath=$(
                            jq -r '
                                .body[] | select(.id == "'${noteid}'") | .path
                                ' "${notebooklist}"
                            )
                        clonepath=${notepath/${public_examples}/${private_examples}}

                        # Clone a notebook.
                        curl \
                            --silent \
                            --show-error \
                            --location \
                            --request POST \
                            --cookie "${cookiefile}" \
                            --header 'Content-Type: application/json' \
                            --data "{
                                \"name\": \"${clonepath}\"
                                }" \
                            "${zeppelinurl}/api/notebook/${noteid}" \
                            1> "${cloneresult}" \
                            2> "${debugerrorfile}"
                            retcode=$?

                        if [ ${retcode} -ne 0 ]
                        then
                            failmessage "Clone failed - error code [${retcode}]"
                        else
                            status=$(
                                jq -r '.status' "${cloneresult}"
                                )
                            if [ "${status}" == "OK" ]
                            then
                                passmessage "Clone done [${noteid}][${clonepath}]"
                            else
                                exception=$(
                                    jq -r '.exception' "${cloneresult}"
                                    )
                                failmessage "Clone failed - exception [${exception}] "
                            fi
                        fi
                    done
                fi
            fi
        fi
    fi
fi

cat << EOF
{
"user": "${username}",
$(jsondebug)
}
EOF

