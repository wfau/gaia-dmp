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
# This script isn't used at the moment, the equivalent script is created by the creat-user-scripts Ansible playbook.
# We will probably move most of the code out of the Ansible playbook into small scripts like this in a future PR.
# Which will hopefully make them easier to maintain.
#

username="${1:?}"
usertype="${2:?}"
userid="${3}"
userhome="${4:-/home/${username}}"

minuid=20000
maxuid=60000

sshkeyname=id_rsa
sshkeytype=rsa
zeppubkeypath=/opt/aglais/ssh/ssh-fedora.pub
zepusergroup=zeppelinusers

# Get the next available uid
# https://www.commandlinefu.com/commands/view/5684/determine-next-available-uid
if [ -z ${userid} ]
then
    userid=$(
        getent passwd | awk -F: 'BEGIN {userid = '${minuid}'} ($3 < '${maxuid}') && ($3 > userid) { userid = $3 } END { print userid + 1 }'
        )
fi

# Do the whole block as root rather than one line at a time.
# https://stackoverflow.com/a/14497422
sudo -s -- <<  SUDO

    # Create the Unix user account.
    adduser \
        --uid "${userid}" \
        --create-home \
        --home-dir "${userhome}" \
        --user-group \
        --groups "users,${zepusergroup}" \
        "${username}"

    # Generate our local ssh key pair.
    mkdir "${userhome}/.ssh"
    ssh-keygen \
        -t "${sshkeytype}" \
        -N '' \
        -f "${userhome}/.ssh/${sshkeyname}" \
    > /dev/null 2>&1

    # Add the Zeppelin user's public key.
    cat "${zeppubkeypath}" >> "${userhome}/.ssh/authorized_keys"

    # Fix permissions on our ssh directory.
    chown -R "${username}:${username}" "${userhome}/.ssh"
    chmod -R "u=rwX,g=,o="     "${userhome}/.ssh"

SUDO

# Generate our JSON response.
cat << JSON
{
"name": "${username}",
"type": "${usertype}",
"home": "${userhome}",
"uid":   ${userid}
}
JSON

