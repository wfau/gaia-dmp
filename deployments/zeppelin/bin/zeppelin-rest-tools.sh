#!/bin/sh
#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2021, ROE (http://www.roe.ac.uk/)
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
#

# -----------------------------------------------------
# Basic REST API functions.

    zeplogin()
        {
        local username=${1:?}
        local password=${2:?}
        zepcookies=/tmp/${username:?}.cookies
        curl \
            --silent \
            --request 'POST' \
            --cookie-jar "${zepcookies:?}" \
            --data "userName=${username:?}" \
            --data "password=${password:?}" \
            "${zeppelinurl:?}/api/login" \
        | jq '.'
        }

    zepnbjsonfile()
        {
        local nbident=${1:?}
        echo "/tmp/${nbident:?}.json"
        }

    zepnbjsonclr()
        {
        local nbident=${1:?}
        local jsonfile=$(zepnbjsonfile ${nbident})
        if [ -f "${jsonfile}" ]
        then
            rm -f "${jsonfile}"
        fi
        }

    zepnbclear()
        {
        local nbident=${1:?}
        zepnbjsonclr ${nbident}
        curl \
            --silent \
            --request PUT \
            --cookie "${zepcookies:?}" \
            "${zeppelinurl:?}/api/notebook/${nbident:?}/clear" \
        | jq '.'
        }

    zepnbstatus()
        {
        local nbident=${1:?}
        zepnbjsonclr ${nbident}
        curl \
            --silent \
            --request GET \
            --cookie "${zepcookies:?}" \
            "${zeppelinurl:?}/api/notebook/${nbident:?}" \
        | jq '.' | tee $(zepnbjsonfile ${nbident}) | jq 'del(.body.paragraphs[])'
        }

    zepnbexecute()
        {
        local nbident=${1:?}
        zepnbjsonclr ${nbident}
        curl \
            --silent \
            --request POST \
            --cookie "${zepcookies:?}" \
            "${zeppelinurl:?}/api/notebook/job/${nbident:?}" \
        | jq '.'
        }


# -----------------------------------------------------
# Execute a notebook paragraph at a time.

    zepnbexecstep()
        {
        local nbident=${1:?}
        zepnbjsonclr ${nbident}

        # Fetch the notbook details.
        curl \
            --silent \
            --request GET \
            --cookie "${zepcookies:?}" \
            "${zeppelinurl:?}/api/notebook/${nbident:?}" \
            > $(zepnbjsonfile ${nbident})


        # List the title, status and ident.
        paralist=$(mktemp --suffix '.json')
        jq '
            [.body.paragraphs[]? | {id, status, title}]
            ' "$(zepnbjsonfile ${nbident})" \
            > "${paralist}"


        # Execute each paragraph
        jq -r '.[] | @text' "${paralist}" \
        | while read line
            do
                title=$(jq -r '.title' <<< "${line}")
                paraid=$(jq -r '.id'   <<< "${line}")
                status=$(jq -r '.status' <<< "${line}")
                echo ""
                echo "Para [${paraid}][${title}]"

                curl \
                    --silent \
                    --request POST \
                    --cookie "${zepcookies:?}" \
                    "${zeppelinurl:?}/api/notebook/run/${nbident:?}/${paraid:?}" \
                | jq 'del(.body.msg)' \
                | tee "/tmp/para-${paraid}.json"


                result=$(
                    jq -r '.body.code' "/tmp/para-${paraid}.json"
                    )
                echo "Result [${result}]"

                if [ "${result}" != 'SUCCESS' ]
                then
                    break
                fi

            done
        }

# -----------------------------------------------------
# Calculate the elapsed time for each paragraph.

    zepnbparatime()
        {
        local nbident=${1:?}

        cat $(zepnbjsonfile ${nbident}) \
        | sed '
            /"dateStarted": null,/d
            /"dateStarted":/ {
                h
                s/\([[:space:]]*\)"dateStarted":[[:space:]]*\("[^"]*"\).*$/\1\2/
                x
                }
            /"dateFinished": null,/ d
            /"dateFinished":/ {
                H
                x
                s/[[:space:]]*"dateFinished":[[:space:]]*\("[^"]*"\).*$/ \1/
                s/\([[:space:]]*\)\(.*\)/\1echo "\1\\"elapsedTime\\": \\"$(datediff --format "%H:%M:%S" --input-format "%b %d, %Y %H:%M:%S %p" \2)\\","/e
                x
                G
                }
            ' \
        | jq '
            .body.paragraphs[] | select(.results.code != null) | {
                title,
                result: .results.code,
                time:   .elapsedTime,
                }
            '
        }


# -----------------------------------------------------
# Calculate the elapsed time for the whole notebook.
#[root@ansibler]

    zepnbtotaltime()
        {
        local nbident=${1:?}
        local jsonfile=$(zepnbjsonfile ${nbident})

        local first=$(
            jq -r '
                [.body.paragraphs[] | select(.dateStarted != null) | .dateStarted] | first
                ' \
                "${jsonfile}"
            )

        local last=$(
            jq -r '
                [.body.paragraphs[] | select(.dateFinished != null) | .dateFinished] | last
                ' \
                "${jsonfile}"
            )

        datediff --format "%H:%M:%S" --input-format "%b %d, %Y %H:%M:%S %p" "${first}" "${last}"
        }



