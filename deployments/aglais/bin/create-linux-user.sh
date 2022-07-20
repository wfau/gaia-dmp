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
userhome=${3}
publickey=${4}
linuxuid=${5}

minuid=20000
maxuid=60000

# TODO Move these to an Ansible managed config file.
sshkeyname=id_rsa
sshkeytype=rsa
zepkeypath=/opt/aglais/ssh/fedora-rsa.pub
zepusergroup=zeppelinusers

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
if [ -z "${linuxuid}" ]
then
    linuxuid=$(
        getent passwd | awk -F: 'BEGIN {linuxuid = '${minuid}'} ($3 < '${maxuid}') && ($3 > linuxuid) { linuxuid = $3 } END { print linuxuid + 1 }'
        )
fi

# Check the user's home directory exists.


# Create the Linux user account.
id "${username}" &> /dev/null
if [ $? -eq 0 ]
then
    skipmessage "adduser [${username}] skipped (done)"
else
    adduser \
        --uid "${linuxuid}" \
        --home "${userhome}" \
        --no-create-home \
        --user-group \
        --groups "users,${zepusergroup}" \
        "${username}" \
    2> "${debugerrorfile}"

    if [ $? -eq 0 ]
    then
        passmessage "adduser [${username}] done"
    else
        failmessage "adduser [${username}] failed"
    fi
fi

# Create the user's .ssh directory.
if [ -e "${userhome}/.ssh" ]
then
    skipmessage "mkdir [${userhome}/.ssh] skipped (done)"
else
    mkdir "${userhome}/.ssh" 2> "${debugerrorfile}"
    if [ $? -eq 0 ]
    then
        passmessage "mkdir [${userhome}/.ssh] done"
    else
        failmessage "mkdir [${userhome}/.ssh] failed"
    fi
fi

#   # Generate our local ssh key pair.
#   # Not sure what this is used for ....
#   ssh-keygen \
#       -t "${sshkeytype}" \
#       -N '' \
#       -f "${userhome}/.ssh/${sshkeyname}" \
#   > /dev/null 2>&1

# Create the user's authorized_keys file.
if [ ! -e "${userhome}/.ssh/authorized_keys" ]
then
    touch "${userhome}/.ssh/authorized_keys"
fi

# Add the Zeppelin user's public key.
zepkey=$(cat "${zepkeypath}")
if [ $(grep -c "${zepkey}" "${userhome}/.ssh/authorized_keys" ) -ne 0 ]
then
    skipmessage "adding public key for [zeppelin] skipped (done)"
else
    cat >> "${userhome}/.ssh/authorized_keys" 2> "${debugerrorfile}" << EOF
# zeppelin's public key"
${zepkey}
EOF
    if [ $? -eq 0 ]
    then
        passmessage "adding public key for [zepelin] done"
    else
        failmessage "adding public key for [zepelin] failed"
    fi
fi

# Add the user's own public key.
if [ -z "${publickey}" ]
then
    skipmessage "adding public key for [${username}] skipped (no key)"
else
    if [ $(grep -c "${publickey}" "${userhome}/.ssh/authorized_keys" ) -ne 0 ]
    then
        skipmessage "adding public key for [${username}] skipped (done)"
    else
        cat >> "${userhome}/.ssh/authorized_keys" 2> "${debugerrorfile}" << EOF
# ${username}'s public key"
${publickey}
EOF
        if [ $? -eq 0 ]
        then
            passmessage "adding public key for [${username}] done"
        else
            failmessage "adding public key for [${username}] failed"
        fi
    fi
fi

# Fix ownership of the user's home directory.
chown -R "${username}:${username}" "${userhome}" 2> "${debugerrorfile}"
if [ $? -ne 0 ]
then
    failmessage "chown [${userhome}] failed"
fi
# Fix permissions on the user's home directory.
chmod -R "u=rwx,g=rx,o=" "${userhome}" 2> "${debugerrorfile}"
if [ $? -ne 0 ]
then
    failmessage "chmod [${userhome}] failed"
fi

# Fix ownership of the user's .ssh directory.
chown -R "${username}:${username}" "${userhome}/.ssh" 2> "${debugerrorfile}"
if [ $? -ne 0 ]
then
    failmessage "chown [${userhome}/.ssh] failed"
fi
# Fix permissions on the user's .ssh directory.
chmod -R "u=rwX,g=,o=" "${userhome}/.ssh" 2> "${debugerrorfile}"
if [ $? -ne 0 ]
then
    failmessage "chmod [${userhome}/.ssh] failed"
fi

# Generate our JSON response.
cat << JSON
{
"name": "${username}",
"type": "${usertype}",
"linuxuid":  "${linuxuid}",
$(jsondebug)
}
JSON

