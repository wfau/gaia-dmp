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

username="${1}"
usertype="${2}"
userkey="${3}"
userid="${4}"

minuid=20000
maxuid=60000

sshkeyname=id_rsa
sshkeytype=rsa
zepkeypath=/opt/aglais/ssh/ssh-fedora.pub
zepusergroup=zeppelinusers

result="PASS"
messages=()
errorfile=$(mktemp)

# Check we are root
if [ $(id -u) -ne 0 ]
then
    jsonerror "[${srcfile}] should be run as root"
    exit 1
fi

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


# Get the next available uid
# https://www.commandlinefu.com/commands/view/5684/determine-next-available-uid
if [ -z "${userid}" ]
then
    userid=$(
        getent passwd | awk -F: 'BEGIN {userid = '${minuid}'} ($3 < '${maxuid}') && ($3 > userid) { userid = $3 } END { print userid + 1 }'
        )
fi

# Create the Linux user's account.
id "${username}" 2>1 > /dev/null
if [ $? -eq 0 ]
then
    messages+=("SKIP: adduser [${username}] skipped")
else
    adduser \
        --uid "${userid}" \
        --create-home \
        --home-dir "${userhome}" \
        --user-group \
        --groups "users,${zepusergroup}" \
        "${username}" \
    2> "${errorfile}"

    if [ $? -eq 0 ]
    then
        messages+=("PASS: adduser [${username}] done")
    else
        result="FAIL"
        messages+=("FAIL: adduser [${username}] failed")
        messages+=$(cat "${errorfile}")
    fi
fi

# Create the Linux user's ssh directory.
if [ -e "${userhome}/.ssh" ]
then
    messages+=("SKIP: mkdir [${userhome}/.ssh] skipped")
else
    mkdir "${userhome}/.ssh" 2> "${errorfile}"
    if [ $? -eq 0 ]
    then
        messages+=("PASS: mkdir [${userhome}/.ssh] done")
    else
        result="FAIL"
        messages+=("FAIL: mkdir [${userhome}/.ssh] failed")
        messages+=$(cat "${errorfile}")
    fi
fi

#   # Generate our local ssh key pair.
#   # Not sure what this is used for ....
#   ssh-keygen \
#       -t "${sshkeytype}" \
#       -N '' \
#       -f "${userhome}/.ssh/${sshkeyname}" \
#   > /dev/null 2>&1

# Add the Zeppelin user's public key.
zepkey=$(cat "${zepkeypath}")
if [ $(grep -c "${zepkey}" "${userhome}/.ssh/authorized_keys" ) -ne 0 ]
then
    messages+=("SKIP: adding public key for [zepelin] skipped (done)")
else
    cat >> "${userhome}/.ssh/authorized_keys" 2> "${errorfile}" << EOF
# zeppelin's public key"
${zepkey}
EOF
    if [ $? -eq 0 ]
    then
        messages+=("PASS: adding public key for [zepelin] done")
    else
        result="FAIL"
        messages+=("FAIL: adding public key for [zepelin] failed")
        messages+=$(cat "${errorfile}")
    fi
fi

# Add the Linux user's public key.
if [ -z "${userkey}" ]
then
    messages+=("SKIP: adding public key for ${username} skipped (no key)")
else
    if [ $(grep -c "${userkey}" "${userhome}/.ssh/authorized_keys" ) -ne 0 ]
    then
        messages+=("SKIP: adding public key for ${username} dkipped (done)")
    else
        cat >> "${userhome}/.ssh/authorized_keys" 2> "${errorfile}" << EOF
# ${username}'s public key"
${userkey}
EOF
        if [ $? -eq 0 ]
        then
            messages+=("PASS: adding public key for ${username} done")
        else
            result="FAIL"
            messages+=("FAIL: adding public key for ${username} failed")
            messages+=$(cat "${errorfile}")
        fi
    fi
fi

# Fix permissions on the Linux user's ssh directory.
chown -R "${username}:${username}" "${userhome}/.ssh" 2> "${errorfile}"
if [ $? -ne 0 ]
then
    result="FAIL"
    messages+=$(cat "${errorfile}")
fi

chmod -R "u=rwX,g=,o=" "${userhome}/.ssh" 2> "${errorfile}"
if [ $? -ne 0 ]
then
    result="FAIL"
    messages+=$(cat "${errorfile}")
fi

# Generate our JSON response.
cat << JSON
{
"name":   "${username}",
"type":   "${usertype}",
"home":   "${userhome}",
"uid":    ${userid},
"debug": {
    "script": "${srcfile}",
    "result": "${result}",
    "messages:" $(jsonarray messages)
    }
}
JSON

