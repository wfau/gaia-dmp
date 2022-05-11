	#!/bin/sh
#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2021, ROE (http://www.roe.ac.uk/)
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

    cloudbase='arcus'
    cloudname=${1:?}
    buildname="aglais-$(date '+%Y%m%d')"
    builddate="$(date '+%Y%m%d:%H%M%S')"

    deployconf="${2:-medium-04}"
    deployname="${cloudname:?}-$(date '+%Y%m%d')"
    deploydate=$(date '+%Y%m%dT%H%M%S')

    configyml='/tmp/aglais-config.yml'
    statusyml='/tmp/aglais-status.yml'
    touch "${statusyml:?}"

    yq eval \
        --inplace \
        ".aglais.status.deployment.type = \"hadoop-yarn\"" \
        "${statusyml:?}"

    yq eval \
        --inplace \
        ".aglais.status.deployment.conf = \"${deployconf}\"" \
        "${statusyml:?}"

    yq eval \
        --inplace \
        ".aglais.status.deployment.name = \"${deployname}\"" \
        "${statusyml:?}"

    yq eval \
        --inplace \
        ".aglais.status.deployment.date = \"${deploydate}\"" \
        "${statusyml:?}"

    yq eval \
        --inplace \
        ".aglais.spec.openstack.cloud.base = \"${cloudbase}\"" \
        "${statusyml:?}"

    yq eval \
        --inplace \
        ".aglais.spec.openstack.cloud.name = \"${cloudname}\"" \
        "${statusyml:?}"

#rm '/usr/bin/yq'
#wget -O '/usr/bin/yq' 'https://github.com/mikefarah/yq/releases/download/v4.16.2/yq_linux_amd64'
#chmod a+x '/usr/bin/yq'
#
#    cloudconfig="${treetop:?}/common/openstack/config/${cloudbase:?}.yml"  yq eval \
#        ".aglais.spec.openstack.cloud.config |= load(strenv(cloudconfig))" \
#        "${statusyml:?}"
#
#    yq eval-all \
#        "" \
#        "${statusyml:?}" \
#        "${treetop:?}/common/openstack/config/${cloudbase:?}.yml"

    echo "---- ---- ----"
#   echo "Config yml [${configyml}]"
    echo "Cloud base [${cloudbase}]"
    echo "Cloud name [${cloudname}]"
    echo "Build name [${buildname}]"
    echo "---- ---- ----"
    echo "Deploy conf [${deployconf}]"
    echo "Deploy name [${deployname}]"
    echo "Deploy date [${deploydate}]"
    echo "---- ---- ----"

# -----------------------------------------------------
# Link our Ansible vars filea.

    ln -sf "${statusyml}" '/tmp/ansible-vars.yml'

#   ln -sf "${treetop:?}/common/openstack/config/${cloudbase:?}.yml" '/tmp/openstack-vars.yml'

# -----------------------------------------------------
# Delete any existing known hosts file..
# Temp fix until we get a better solution.
# https://github.com/wfau/aglais/issues/401

    rm -f "${HOME}/.ssh/known_hosts"

# -----------------------------------------------------
# Select the Ansible inventory.

    inventory="${treetop:?}/hadoop-yarn/ansible/config/${deployconf:?}.yml"

# -----------------------------------------------------
# Create the machines, deploy Hadoop and Spark.

    echo ""
    echo "---- ----"
    echo "Running Ansible deploy"

    pushd "${treetop:?}/hadoop-yarn/ansible"

        ansible-playbook \
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
        yq eval '.datashares.[].id' "${sharelist:?}"
        )
    do
        echo ""
        echo "Share [${shareid:?}]"

        sharecloud=$(
            yq eval ".datashares.[] | select(.id == \"${shareid:?}\").cloudname"  "${sharelist:?}"
            )
        sharename=$(
            yq eval ".datashares.[] | select(.id == \"${shareid:?}\").sharename"  "${sharelist:?}"
            )
        mountpath=$(
            yq eval ".datashares.[] | select(.id == \"${shareid:?}\").mountpath"  "${sharelist:?}"
            )

        "${treetop:?}/hadoop-yarn/bin/cephfs-mount.sh" \
            "${inventory:?}" \
            "${sharecloud:?}" \
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
            --inventory "${inventory:?}" \
            "61-data-links.yml"

    popd


# -----------------------------------------------------
# Check the data shares.
# Using a hard coded cloud name to make it portable.

    sharelist="${treetop:?}/common/manila/datashares.yaml"
    testhost=zeppelin

    for shareid in $(
        yq eval '.datashares.[].id' "${sharelist}"
        )
    do

        checkbase=$(
            yq eval ".datashares.[] | select(.id == \"${shareid}\").mountpath" "${sharelist}"
            )
        checknum=$(
            yq eval ".datashares.[] | select(.id == \"${shareid}\").checksums | length" "${sharelist}"
            )

        for (( i=0; i<checknum; i++ ))
        do
            checkpath=$(
                yq eval ".datashares.[] | select(.id == \"${shareid}\").checksums[${i}].path" "${sharelist}"
                )
            checkcount=$(
                yq eval ".datashares.[] | select(.id == \"${shareid}\").checksums[${i}].count" "${sharelist}"
                )
            checkhash=$(
                yq eval ".datashares.[] | select(.id == \"${shareid}\").checksums[${i}].md5sum" "${sharelist}"
                )

            echo ""
            echo "Share [${checkbase}/${checkpath}]"

            testcount=$(
                ssh "${testhost:?}" \
                    "
                    ls -1 ${checkbase}/${checkpath} | wc -l
                    "
                )

            if [ "${testcount}" == "${checkcount}" ]
            then
                echo "Count [PASS]"
            else
                echo "Count [FAIL][${checkcount}][${testcount}]"
            fi

            testhash=$(
                ssh "${testhost:?}" \
                    "
                    ls -1 -v ${checkbase}/${checkpath} | md5sum | cut -d ' ' -f 1
                    "
                )

            if [ "${testhash}" == "${checkhash}" ]
            then
                echo "Hash  [PASS]"
            else
                echo "Hash  [FAIL][${checkhash}][${testhash}]"
            fi
        done
    done


# -----------------------------------------------------
# Mount the user shares.
# Using a hard coded cloud name to make it portable.

    sharelist="${treetop:?}/common/manila/usershares.yaml"
    mountmode='rw'
    mounthost='zeppelin:masters:workers'

    for shareid in $(
        yq eval ".usershares.[].id" "${sharelist:?}"
        )
    do
        echo ""
        echo "Share [${shareid:?}]"

        sharecloud=$(
            yq eval ".usershares.[] | select(.id == \"${shareid:?}\").cloudname"  "${sharelist:?}"
            )
        sharename=$(
            yq eval ".usershares.[] | select(.id == \"${shareid:?}\").sharename" "${sharelist:?}"
            )
        mountpath=$(
            yq eval ".usershares.[] | select(.id == \"${shareid:?}\").mountpath" "${sharelist:?}"
            )

        "${treetop:?}/hadoop-yarn/bin/cephfs-mount.sh" \
            "${inventory:?}" \
            "${sharecloud:?}" \
            "${sharename:?}" \
            "${mountpath:?}" \
            "${mounthost:?}" \
            "${mountmode:?}"

    done


# -----------------------------------------------------
# Restart the Zeppelin service.

    "${treetop:?}/hadoop-yarn/bin/restart-zeppelin.sh"

# -----------------------------------------------------
# Install GaiaXpy

    pushd "/deployments/hadoop-yarn/ansible"

        ansible-playbook \
            --inventory "${inventory:?}" \
            "37-install-gaiaxpy.yml"

    popd

