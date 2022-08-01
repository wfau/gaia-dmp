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
linuxuid=${4}
publickey=${5}

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

# TODO Check the user's home directory exists.
# If not, then create and add the skeleton contents.
# https://github.com/wfau/aglais/issues/903

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

# Add public keys for zeppelin and the user.
headmark="# BEGIN GaiaDMp managed keys"
tailmark="# END GaiaDMp managed keys"

authorized=${userhome:?}/.ssh/authorized_keys

tempfile=$(mktemp)

cat > "${tempfile}" << EOF
# Do not edit this section

# Public key for Zeppelin
$(cat "${zepkeypath}")

# Public key for ${username}
${publickey}

EOF

if [ $(grep -c "${headmark}" "${authorized}") -eq 0 ]
then
    echo "${headmark}" >> "${authorized}"
    cat  "${tempfile}" >> "${authorized}"
    echo "${tailmark}" >> "${authorized}"
    passmessage "added public keys for [zepelin] and [${username}] (new)"
else
    sed -i "
        /${headmark}/,/${tailmark}/ {
            /${headmark}/ n
            /${tailmark}/ ! d
            }
        " ${authorized}
    sed -i "
        /${headmark}/ {
            r ${tempfile}
            }
        " ${authorized}
    passmessage "updates public keys for [zepelin] and [${username}] (sed)"
fi

# If the user's home directory is empty.
if [ $(ls -a -1 "${userhome}" | wc -l) -eq 2 ]
then
    # Install the skeleton files.
    cp \
       --recursive   \
       --no-clobber  \
       --preserve    \
         /etc/skel/. \
         "${userhome}"
    if [ $? -eq 0 ]
    then
        passmessage "Copying [/etc/skel] done"
    else
        failmessage "Copying [/etc/skel] failed"
    fi
    # Fix ownership of the copied files.
    chown -R "${username}:${username}" "${userhome}" 2> "${debugerrorfile}"
    if [ $? -ne 0 ]
    then
        failmessage "chown [${userhome}] failed"
    fi
fi

# Fix ownership of the user's home directory.
chown "${username}:${username}" "${userhome}" 2> "${debugerrorfile}"
if [ $? -ne 0 ]
then
    failmessage "chown [${userhome}] failed"
fi
# Fix permissions on the user's home directory.
chmod "u=rwx,g=rx,o=" "${userhome}" 2> "${debugerrorfile}"
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
"homedir":   "${userhome}",
"linuxuid":  "${linuxuid}",
"publickey":  $(jq --null-input --arg publickey "${publickey}" '$publickey'),
"pkeyhash":  "$(md5sum - <<< ${publickey} | sed 's/^\([^ ]*\).*/\1/')",
$(jsondebug)
}
JSON

