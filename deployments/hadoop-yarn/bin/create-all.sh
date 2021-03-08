#!/bin/sh
#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2020, ROE (http://www.roe.ac.uk/)
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

# -----------------------------------------------------
# Settings ...

    set -eu
    set -o pipefail

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    srcpath="$(dirname ${binpath})"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"

    configyml=${1:-'/tmp/aglais-config.yml'}
    statusyml=${2:-'/tmp/aglais-status.yml'}
    touch "${statusyml:?}"

    cloudname=$(
        yq read \
            "${configyml:?}" \
                'aglais.spec.openstack.cloud'
        )
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.spec.openstack.cloud' \
            "${cloudname}"

    deployname="${cloudname:?}-$(date '+%Y%m%d')"
    deploydate=$(date '+%Y%m%dT%H%M%S')

    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.deployment.type' \
            'hadoop-yarn'
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.deployment.name' \
            "${deployname}"
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.deployment.date' \
            "${deploydate}"


    echo "---- ---- ----"
    echo "Cloud name [${cloudname}]"
    echo "Deployment [${deployname}]"
    echo "---- ---- ----"


# -----------------------------------------------------
# Create our Ansible include vars file.

    ln -sf "${statusyml}" '/tmp/ansible-vars.yml'

#
#    cat > /tmp/ansible-vars.yml << EOF
#aglais:
#  version: 1.0
#  spec:
#    deployment:
#        name: '${deployname:?}'
#    openstack:
#        cloud: '${cloudname:?}'
#
#
#EOF

# -----------------------------------------------------
# Create the machines, deploy Hadoop and Spark.

    echo ""
    echo "---- ----"
    echo "Running Ansible deploy"

    pushd "/hadoop-yarn/ansible"

        ansible-playbook \
            --inventory "hosts.yml" \
            "create-all.yml"

    popd


# -----------------------------------------------------
# Start the HDFS services.

    '/hadoop-yarn/bin/start-hdfs.sh'


# -----------------------------------------------------
# Start the Yarn services.

    '/hadoop-yarn/bin/start-yarn.sh'


# -----------------------------------------------------
# Initialise the Spark services.

    '/hadoop-yarn/bin/init-spark.sh'


# -----------------------------------------------------
# Initialise the Zeppelin service.

    '/hadoop-yarn/bin/start-zeppelin.sh'


# -----------------------------------------------------
# Create our CephFS router.

    '/hadoop-yarn/bin/cephfs-router.sh' \
        "${cloudname:?}" \
        "${deployname:?}"


# -----------------------------------------------------
# Mount the data shares.
# Using a hard coded cloud name to make it portable.

    sharelist='/common/manila/datashares.yaml'
    sharemode='ro'

    for shareid in $(
        yq read "${sharelist:?}" 'shares.[*].id'
        )
    do
        echo ""
        echo "Share [${shareid:?}]"

        sharename=$(yq read "${sharelist:?}" "shares.(id==${shareid:?}).sharename")
        mountpath=$(yq read "${sharelist:?}" "shares.(id==${shareid:?}).mountpath")

        '/hadoop-yarn/bin/cephfs-mount.sh' \
            'gaia-prod' \
            "${sharename:?}" \
            "${mountpath:?}" \
            "${sharemode:?}"

    done


# -----------------------------------------------------
# Mount the user shares.
# Using a hard coded cloud name to make it portable.

    sharelist='/common/manila/usershares.yaml'
    sharemode='rw'

    for shareid in $(
        yq read "${sharelist:?}" 'shares.[*].id'
        )
    do
        echo ""
        echo "Share [${shareid:?}]"

        sharename=$(yq read "${sharelist:?}" "shares.(id==${shareid:?}).sharename")
        mountpath=$(yq read "${sharelist:?}" "shares.(id==${shareid:?}).mountpath")

        '/hadoop-yarn/bin/cephfs-mount.sh' \
            'gaia-prod' \
            "${sharename:?}" \
            "${mountpath:?}" \
            "${sharemode:?}"

    done

