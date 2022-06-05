#!/bin/bash


# -----------------------------------------------------
# Delete everything.
#[root@ansibler]

    time \
        /deployments/openstack/bin/delete-all.sh \
            "${cloudname:?}"


# -----------------------------------------------------
# Create everything.
# (*) apart from the user database.
#[root@ansibler]

    time \
        /deployments/hadoop-yarn/bin/create-all.sh \
            "${cloudname:?}" \
            "${configname:?}" \
        | tee /tmp/create-all.log


# -----------------------------------------------------
# Create our shiro-auth database.
#[root@ansibler]

    time \
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




