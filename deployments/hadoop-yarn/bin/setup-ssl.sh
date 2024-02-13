#!/bin/bash
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
    cloudname="${1:?}"
    deployconf="${2:?}"

    inventory="${treetop:?}/hadoop-yarn/ansible/config/${deployconf:?}.yml"

    echo "---- ---- ----"
    echo "Deploy conf [${deployconf}]"
    echo "---- ---- ----"

    # Copy latest SSL certificates
    scp -o "StrictHostKeyChecking=no"  -r fedora@data.gaia-dmp.uk:/home/fedora/certs/latest/ /root/certs/

    # Setup SSL for nginx

    pushd "/deployments/hadoop-yarn/ansible"

        ansible-playbook \
            --verbose \
            --inventory "${inventory:?}" \
            "43-setup-ssl.yml"

    popd



# -----------------------------------------------------
# Restart NGINX proxy

    "${treetop:?}/hadoop-yarn/bin/start-nginx.sh"
