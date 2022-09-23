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

infomessage()
    {
    local message=${1}
    if [ -n "${message}" ]
    then
        debugmessages+=("INFO: ${message}")
    fi
    }

failmessage()
    {
    debugresult="FAIL"
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

# Augmented mkdir, chown and chmod with debug messages.
agmkdir()
    {
    local dirpath=${1:?'dirpath required'}
    local dirmode=${2:-'u=rwxs,g=wrxs,o=rx'}
    local diruser=${3:-$(id -un)}

    if [ -e "${dirpath}" ]
    then
        skipmessage "mkdir [${dirpath}] skipped (done)"
    else
        sudo mkdir -p "${dirpath}" 1> "${debugerrorfile}" 2>&1
        if [ $? -eq 0 ]
        then
            passmessage "mkdir [${dirpath}] done"
        else
            failmessage "mkdir [${dirpath}] failed"
        fi
        sudo chown "${diruser}" "${dirpath}" 1> "${debugerrorfile}" 2>&1
        if [ $? -eq 0 ]
        then
            passmessage "chown [${dirpath}] done"
        else
            failmessage "chown [${dirpath}] failed"
        fi
        sudo chmod "${dirmode}" "${dirpath}" 1> "${debugerrorfile}" 2>&1
        if [ $? -eq 0 ]
        then
            passmessage "chmod [${dirpath}] done"
        else
            failmessage "chmod [${dirpath}] failed"
        fi
    fi
    }

# Quiet version of pushd, with debug messages.
qpushd()
    {
    local path=${1:?'dirpath required'}
    pushd "${path}" 1> "${debugerrorfile}" 2>&1
    if [ $? -ne 0 ]
    then
        failmessage "pushd [${path}] failed"
    fi
    }

# Quiet version of popd, with debug messages.
qpopd()
    {
    popd 1> "${debugerrorfile}" 2>&1
    if [ $? -ne 0 ]
    then
        failmessage "pushd [${dirpath}] failed"
    fi
    }


