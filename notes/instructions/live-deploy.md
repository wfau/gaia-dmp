# Instructions for deploying a live GDMP Service

### Setup aglais.env (if it doesn't exist)

edit "${HOME:?}/aglais.env"
	
	AGLAIS_REPO='git@github.com:wfau/aglais.git'
	AGLAIS_HOME="/home/user/gdmp_repo_location"
	AGLAIS_CODE="${AGLAIS_HOME:?}/"


### Check current live deploy 

    [user@desktop]

    ssh fedora@live.gaia-dmp.uk \
        '
        date
        hostname
        '
        
	> iris-gaia-green-20230308-zeppelin



### Create a container to work with.

    [user@desktop]

    source "${HOME:?}/aglais.env"
    agcolour=red
    configname=zeppelin-54.86-spark-6.26.43
    agproxymap=3000:3000
    clientname=ansibler-${agcolour}
    cloudname=iris-gaia-${agcolour}

    podman run \
        --rm \
        --tty \
        --interactive \
        --name     "${clientname:?}" \
        --hostname "${clientname:?}" \
        --publish  "${agproxymap:?}" \
        --env "cloudname=${cloudname:?}" \
        --env "configname=${configname:?}" \
        --env "SSH_AUTH_SOCK=/mnt/ssh_auth_sock" \
        --volume "${SSH_AUTH_SOCK:?}:/mnt/ssh_auth_sock:rw,z" \
        --volume "${HOME:?}/clouds.yaml:/etc/openstack/clouds.yaml:ro,z" \
        --volume "${AGLAIS_CODE:?}/deployments:/deployments:ro,z" \
        ghcr.io/wfau/atolmis/ansible-client:2022.07.25 \
        bash


### Backup the notebooks onto data node.

    [root@ansibler]

    ssh fedora@data.gaia-dmp.uk

        sshuser=fedora
        sshhost=live.gaia-dmp.uk

        ssh-keyscan "${sshhost:?}" 2>/dev/null >> "${HOME}/.ssh/known_hosts"

        pushd /var/local/backups
            pushd notebooks

                datetime=$(date '+%Y%m%d-%H%M%S')
                backname="${datetime:?}-${sshhost:?}-notebooks"

                mkdir "${backname}"

                rsync \
                    --perms \
                    --times \
                    --group \
                    --owner \
                    --stats \
                    --progress \
                    --exclude '~Trash' \
                    --human-readable \
                    --checksum \
                    --recursive \
                    --rsync-path 'sudo rsync' \
                    "${sshuser:?}@${sshhost:?}:/home/fedora/zeppelin/notebook" \
                    "${backname:?}"

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
                    --rsync-path 'sudo rsync' \
                    "${sshuser:?}@${sshhost:?}:/home/fedora/zeppelin/conf/notebook-authorization.json" \
                    "${backname:?}"

                if [ -L latest ]
                then
                    rm latest
                fi
                ln -s "${backname:?}" latest

            popd
        popd

Verify the results
        
        ls -al /var/local/backups/notebooks/
        du -h -d 3 /var/local/backups/notebooks/latest/



### Deploy everything.

    [root@ansibler]

    time \
        source /deployments/hadoop-yarn/bin/deploy.sh


### Import our live users.
    
    [root@ansibler]

    source /deployments/zeppelin/bin/create-user-tools.sh

    import-live-users   
    
    
### Manually validate our service

    [user@dekstop]
    
    firefox \
        --new-window \
        'https://iris-gaia-red.gaia-dmp.uk/'


### Get the public IP address of our Zeppelin node.

    [root@ansibler]

    deployname=$(
        yq eval \
            '.aglais.status.deployment.name' \
            '/opt/aglais/aglais-status.yml'
        )

    zeppelinid=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            server list \
                --format json \
        | jq -r '.[] | select(.Name == "'${deployname:?}'-zeppelin") | .ID'
        )

    zeppelinip=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            server show \
                --format json \
                "${zeppelinid:?}" \
        | jq -r ".addresses | .\"${deployname}-internal-network\" | .[1]"
        )
        
    cat << EOF
    Zeppelin ID [${zeppelinid:?}]
    Zeppelin IP [${zeppelinip:?}]
    EOF
    
        > Zeppelin ID  ..
        > Zeppelin IP ..
            
    

### Update the dns entry with new IP

dmp.gaia.ac.uk -> Zeppelin IP

    source /deployments/zeppelin/bin/create-user-tools.sh
    ducktoken=$(getsecret 'devops.duckdns.token')
    duckname=aglais-live

    curl "https://www.duckdns.org/update/${duckname:?}/${ducktoken:?}/${zeppelinip:?}"    

    > OK


### Manually validate live URL

    [user@dekstop]
    
    firefox \
        --new-window \
        'https://dmp.gaia.ac.uk/'

        
