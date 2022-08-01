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
#[root@ansibler]

    /deployments/hadoop-yarn/bin/create-all.sh \
        "${cloudname:?}" \
        "${configname:?}" \
    | tee /tmp/create-all.log


# -----------------------------------------------------
# Copy notebooks from our backup store.
#[root@ansibler]

    ssh zeppelin \
        '
        sshuser=fedora
        sshhost=data.aglais.uk

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
            --human-readable \
            --checksum \
            --recursive \
            --exclude "~Trash" \
            "${sshuser:?}@${sshhost:?}:/var/local/backups/notebooks/latest/notebook/" \
            "/home/fedora/zeppelin/notebook"

        rsync \
            --perms \
            --times \
            --group \
            --owner \
            --stats \
            --human-readable \
            --checksum \
            --recursive \
            "${sshuser:?}@${sshhost:?}:/var/local/backups/notebooks/latest/notebook-authorization.json" \
            "/home/fedora/zeppelin/conf/notebook-authorization.json"

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
# https://github.com/wfau/aglais/issues/893
#[root@ansibler]

    ssh-keyscan 'data.aglais.uk' 2>/dev/null >> "${HOME}/.ssh/known_hosts"


# -----------------------------------------------------
# Get the IP address from the ssh config file.
# TODO Save the IP address during the deployment process.
# https://github.com/wfau/aglais/issues/860
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
# https://github.com/wfau/aglais/issues/862
# WARNING this is not idempotent.
# Deploying more than once adds multiple rows
#[root@ansibler]

cat >> /etc/hosts << EOF
# Zeppelin
${ipaddress}    zeppelin
EOF


# -----------------------------------------------------
# Update our DuckDNS record.
# TODO Add this to the Ansible deployment.
#[root@ansibler]

    # This should be done automatically.
    # https://github.com/wfau/aglais/issues/893
    source /deployments/zeppelin/bin/create-user-tools.sh

    ducktoken=$(getsecret 'devops.duckdns.token')

    echo "----"
    echo "Updating DuckDNS record"
    curl "https://www.duckdns.org/update/${cloudname:?}/${ducktoken:?}/${ipaddress:?}"
    echo
    echo "----"


# -----------------------------------------------------
# Install our integration tests.
#[root@ansibler]

    pip install git+https://github.com/wfau/aglais-testing@v0.2.3


# -----------------------------------------------------
# Display our deployment status.
#[root@ansibler]

    cat '/opt/aglais/aglais-status.yml'




