#!/bin/bash
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

# -----------------------------------------------------
# Delete everything.
#[root@ansibler]

    /deployments/openstack/bin/delete-all.sh \
        "${cloudname:?}"


# -----------------------------------------------------
# Create everything.
# (*) apart from the user database.
#[root@ansibler]

    /deployments/hadoop-yarn/bin/create-all.sh \
        "${cloudname:?}" \
        "${configname:?}" \
    | tee /tmp/create-all.log


# -----------------------------------------------------
# Create our shiro-auth database.
#[root@ansibler]

    /deployments/hadoop-yarn/bin/create-auth-database.sh \
        "${cloudname:?}" \
        "${configname:?}" \
    | tee /tmp/create-auth-database.log


# -----------------------------------------------------
# Copy notebooks from the live server.
#[root@ansibler]

    ssh zeppelin \
        '
        sshuser=fedora
        sshhost=zeppelin.aglais.uk

        sudo mkdir -p '/var/local/backups'
        sudo mv "/home/fedora/zeppelin/notebook" \
           "/var/local/backups/notebook-$(date '+%Y%m%d%H%M%S')"

        ssh-keyscan "${sshhost:?}" >> "${HOME}/.ssh/known_hosts"

        rsync \
            --perms \
            --times \
            --group \
            --owner \
            --stats \
            --progress \
            --human-readable \
            --checksum \
            --recursive \
            "${sshuser:?}@${sshhost:?}:zeppelin/notebook/" \
            "/home/fedora/zeppelin/notebook"
        '



# -----------------------------------------------------
# re-start Zeppelin.
#[root@ansibler]

    ssh zeppelin \
        '
        zeppelin-daemon.sh restart
        '


# -----------------------------------------------------
# Add the ssh key for our data node.
# This is used by the getpasshash function in the client container.
# TODO Add this to a client-setup.sh in ansible/client/bin.
#[root@ansibler]

    ssh-keyscan 'data.aglais.uk' 2>/dev/null >> "${HOME}/.ssh/known_hosts"


# -----------------------------------------------------
# Get the IP address from the ssh config file.
# TODO Save the IP address during the deployment process.
#[root@ansibler]

    ipaddress=$(

        sed -n '
            /^Host zeppelin/,/^Host/ {
                /HostName/ {
                    s/^[[:space:]]*HostName[[:space:]]\(.*\)/\1/ p
                    }
                }
            ' ~/.ssh/config

        )


# -----------------------------------------------------
# Add the Zeppelin IP address to our hosts file.
# TODO Add this to the Ansible deployment.
#[root@ansibler]

cat >> /etc/hosts << EOF
# Zeppelin
${ipaddress}    zeppelin
EOF

# -----------------------------------------------------
# Configure out client container.
#[root@ansibler]

    dnf install -y git

    pip install git+https://github.com/wfau/aglais-testing@v0.2.2




