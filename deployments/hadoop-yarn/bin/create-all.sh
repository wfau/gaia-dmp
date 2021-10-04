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
    treetop="$(dirname $(dirname ${binpath}))"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"
    echo "Tree [${treetop}]"

    cloudname=${1:?}
    buildname="aglais-$(date '+%Y%m%d')"
    builddate="$(date '+%Y%m%d:%H%M%S')"

    deployconf="${2:-medium-04}"
    deployname="${cloudname:?}-$(date '+%Y%m%d')"
    deploydate=$(date '+%Y%m%dT%H%M%S')

    configyml='/tmp/aglais-config.yml'
    statusyml='/tmp/aglais-status.yml'
    touch "${statusyml:?}"

    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.deployment.type' \
            'hadoop-yarn'
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.deployment.conf' \
            "${deployconf}"
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
    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.spec.openstack.cloud' \
            "${cloudname}"

    echo "---- ---- ----"
    echo "Config yml [${configyml}]"
    echo "Cloud name [${cloudname}]"
    echo "Build name [${buildname}]"
    echo "---- ---- ----"
    echo "Deploy conf [${deployconf}]"
    echo "Deploy name [${deployname}]"
    echo "Deploy date [${deploydate}]"
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
# Delete any existing known hosts file..
# Temp fix until we get a better solution.
# https://github.com/wfau/aglais/issues/401

    rm -f "${HOME}/.ssh/known_hosts"

# -----------------------------------------------------
# Create the machines, deploy Hadoop and Spark.

    echo ""
    echo "---- ----"
    echo "Running Ansible deploy"

    inventory="config/${deployconf}.yml"

    pushd "${treetop:?}/hadoop-yarn/ansible"

        ansible-playbook \
            --verbose \
            --verbose \
            --inventory "${inventory:?}" \
            "create-all.yml"

    popd


# -----------------------------------------------------
# Start the HDFS services.

    "${treetop:?}/hadoop-yarn/bin/start-hdfs.sh"


# -----------------------------------------------------
# Start the Yarn services.

    "${treetop:?}/hadoop-yarn/bin/start-yarn.sh"


# -----------------------------------------------------
# Initialise the Spark services.

    "${treetop:?}/hadoop-yarn/bin/init-spark.sh"


# -----------------------------------------------------
# Initialise the Zeppelin service.

    "${treetop:?}/hadoop-yarn/bin/start-zeppelin.sh"


# -----------------------------------------------------
# Create our CephFS router.

    "${treetop:?}/hadoop-yarn/bin/cephfs-router.sh" \
        "${cloudname:?}" \
        "${deployname:?}"


# -----------------------------------------------------
# Mount the data shares.
# Using a hard coded cloud name to make it portable.

    sharelist="${treetop:?}/common/manila/datashares.yaml"
    mountmode='ro'
    mounthost='zeppelin:masters:workers'

    for shareid in $(
        yq read "${sharelist:?}" 'datashares.[*].id'
        )
    do
        echo ""
        echo "Share [${shareid:?}]"

        sharename=$(yq read "${sharelist:?}" "datashares.(id==${shareid:?}).sharename")
        mountpath=$(yq read "${sharelist:?}" "datashares.(id==${shareid:?}).mountpath")

        "${treetop:?}/hadoop-yarn/bin/cephfs-mount.sh" \
            'gaia-prod' \
            "${inventory:?}" \
            "${sharename:?}" \
            "${mountpath:?}" \
            "${mounthost:?}" \
            "${mountmode:?}"

    done

# -----------------------------------------------------
# Add the data symlinks.
# Needs to be done after the data shares have been mounted.

    pushd "/deployments/hadoop-yarn/ansible"

        ansible-playbook \
            --verbose \
            --verbose \
            --inventory "${inventory:?}" \
            "61-data-links.yml"

    popd


# -----------------------------------------------------
# Mount the user shares.
# Using a hard coded cloud name to make it portable.

    sharelist="${treetop:?}/common/manila/usershares.yaml"
    mountmode='rw'
    mounthost='zeppelin:masters:workers'

    for shareid in $(
        yq read "${sharelist:?}" 'usershares.[*].id'
        )
    do
        echo ""
        echo "Share [${shareid:?}]"

        sharename=$(yq read "${sharelist:?}" "usershares.(id==${shareid:?}).sharename")
        mountpath=$(yq read "${sharelist:?}" "usershares.(id==${shareid:?}).mountpath")

        "${treetop:?}/hadoop-yarn/bin/cephfs-mount.sh" \
            'gaia-prod' \
            "${inventory:?}" \
            "${sharename:?}" \
            "${mountpath:?}" \
            "${mounthost:?}" \
            "${mountmode:?}"

    done

# -----------------------------------------------------
# Run Benchmarks

    pushd "/deployments/hadoop-yarn/ansible"

        ansible-playbook \
            --verbose \
            --inventory "${inventory:?}" \
            "36-run-benchmark.yml"

    popd
