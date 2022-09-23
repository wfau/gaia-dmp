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
# The error trapping and pass/fail messages are too complicated.
# A nice idea to solve a small problem, but there must be a simpler way.
# Designed to produce nice JSON output with easily readable error messages captured as an array of strings.
# Gardening task to replace a lot of the extra code with a simpler wrapper
# that runs the whole script as one function, captures any outout
# and formats it as a JSON friendly result.
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
    importjson=$(mktemp)

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

        #public_examples="/Public Examples"
        #private_examples="/Users/${username}/examples"

        userexamples="/Users/${username}/examples"

        # List the (visible) notebooks
        curl \
            --silent \
            --show-error \
            --cookie "${cookiefile}" \
            "${zeppelinurl}/api/notebook" \
            1> "${notebooklist}" \
            2> "${debugerrorfile}"
            retcode=$?

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
                        .body[] | select(.path | startswith(\"${userexamples}\")) | {id, path}
                        ] | length
                        " "${notebooklist}"
                    )

                # Check if the user already has some examples.
                if [ ${count} -ne 0 ]
                then
                    skipmessage "Examples found [${count}]"
                else

                    gitbase='/opt/aglais/notebooks'
                    gitname='aglais-notebooks'
                    gitpath="${gitbase}/${gitname}"
                    gitrepo="https://github.com/wfau/${gitname}"

                    version='v1.0.1'

                    if [ ! -e "${gitpath}" ]
                    then
                        if [ ! -e "$(dirname ${gitpath})" ]
                        then
                            agmkdir "$(dirname ${gitpath})"
                        fi
                        qpushd "$(dirname ${gitpath})"
                            git clone "${gitrepo}" "$(basename ${gitpath})" 1> "${debugerrorfile}" 2>&1
                            if [ $? -ne 0 ]
                            then
                                failmessage "git clone [${gitrepo}] failed"
                            fi
                        qpopd
                    else
                        qpushd "${gitpath}"
                            git checkout 'main' 1> "${debugerrorfile}" 2>&1
                            if [ $? -ne 0 ]
                            then
                                failmessage "git checkout [main] failed"
                            fi
                            git pull 1> "${debugerrorfile}" 2>&1
                            if [ $? -ne 0 ]
                            then
                                failmessage "git pull [${gitrepo}] failed"
                            fi
                        qpopd
                    fi

                    qpushd "${gitpath}"

                        git checkout "${version}" 1> "${debugerrorfile}" 2>&1
                        if [ $? -ne 0 ]
                        then
                            failmessage "git checkout [${version}] failed"
                        fi

                        # This is horribly fragile
                        for notefile in "Public Examples"/*.zpln
                        do
                            notename=$(
                                 jq -r '.name' "${notefile}"
                                )
                            notepath="${userexamples}/${notename}"
                            tempfile="$(mktemp --suffix '.zpln')"

                            infomessage "jq filter [${notefile}] to [${tempfile}]"
                            jq \
                                --arg 'fullname' "${notepath}" \
                                '
                                .name=$fullname |
                                .path="" |
                                .id=""
                                ' \
                                "${notefile}" 1> "${tempfile}" \
                                2> "${debugerrorfile}"
                            if [ $? -ne 0 ]
                            then
                                failmessage "jq filter [${notefile}] to [${tempfile}] failed"
                            fi

                            infomessage "Importing [${tempfile}] as [${notepath}]"
                            # Import the notebook.
                            curl \
                                --silent \
                                --show-error \
                                --location \
                                --request POST \
                                --cookie "${cookiefile}" \
                                --header 'Content-Type: application/json' \
                                --data "@${tempfile}" \
                                "${zeppelinurl}/api/notebook/import" \
                                1> "${importjson}" \
                                2> "${debugerrorfile}"
                                retcode=$?

                            if [ ${retcode} -ne 0 ]
                            then
                                failmessage "Import failed - error code [${retcode}]"
                            else
                                status=$(
                                    jq -r '.status' "${importjson}"
                                    )
                                if [ "${status}" == "OK" ]
                                then
                                    passmessage "Imported [${notefile}] as [${notepath}]"
                                else
                                    exception=$(
                                        jq -r '.exception' "${importjson}"
                                        )
                                    failmessage "Import failed - exception [${exception}] "
                                fi
                            fi
                        done
                    qpopd
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

