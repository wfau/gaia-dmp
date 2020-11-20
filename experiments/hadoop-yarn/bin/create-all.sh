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

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    srcpath="$(dirname ${binpath})"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"

    echo "---- ---- ----"
    echo "Cloud name [${cloudname}]"
    echo "Cloud user [${clouduser}]"

    buildname="aglais-$(date '+%Y%m%d')"

    echo "Build name [${buildname}]"
    echo "---- ---- ----"

# -----------------------------------------------------
# Create our Ansible include vars file.

    cat > /tmp/ansible-vars.yml << EOF
buildtag:  '${buildname:?}'
cloudname: '${cloudname:?}'
clouduser: '${clouduser:?}'
EOF

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
# Create our CephFS router.

    '/hadoop-yarn/bin/cephfs-router.sh' \
        "${cloudname:?}" \
        "${buildname:?}"


# -----------------------------------------------------
# Mount the Gaia DR2 data.
# Note the hard coded cloud name to get details of the static share.

    '/hadoop-yarn/bin/cephfs-mount.sh' \
        'gaia-prod' \
        'aglais-gaia-dr2' \
        '/data/gaia/dr2'


# -----------------------------------------------------
# Mount the user data volume.
# Note the hard coded cloud name to get details of the static share.

    '/hadoop-yarn/bin/cephfs-mount.sh' \
        'gaia-prod' \
        'aglais-user-nch' \
        '/user/nch' \
        'rw'


