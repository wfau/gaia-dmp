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
# JSON tools that will be used in several scripts.
#

# Format a message as JSON.
# https://stackoverflow.com/a/50380697
# https://stackoverflow.com/questions/10053678/escaping-characters-in-bash-for-json
jsonerror()
    {
    local message=${1}
    echo "{"
    echo "\"error\": {"
        echo "\"source\": \"$(basename ${0})\","
        echo "\"message\": $(jsonescape '${message}')"
        echo "}"
    echo "}"
    }

jsonescape()
    {
    local message=${1}
    echo -n "${message}" | jq --raw-input --slurp '.'
    }

jsonarray()
    {
    local -n array=$1
    jq --compact-output --null-input '$ARGS.positional' --args -- "${array[@]}"
    }

#
# Functions for collecting debug messages.
# These functions rely on this file being included in the target script using 'source'.
#
debugresult="PASS"
debugmessages=()
debugerrorfile=$(mktemp)

skipmessage()
    {
    local message=${1}
    if [ -n "${message}" ]
    then
        debugmessages+=("SKIP: ${message}")
    fi
    }

passmessage()
    {
    local message=${1}
    if [ -n "${message}" ]
    then
        debugmessages+=("PASS: ${message}")
    fi
    }

failmessage()
    {
    jsonresult="FAIL"
    local message=${1}
    if [ -n "${message}" ]
    then
        debugmessages+=("FAIL: ${message}")
    fi
    local errors
    readarray -t errors < "${debugerrorfile}"
    debugmessages+=("${errors[@]}")
    }

jsondebug()
    {
cat << JSON
"debug": {
    "script": "$(basename ${0})",
    "result": "${debugresult}",
    "messages": $(jsonarray debugmessages)
    }
JSON
    }


