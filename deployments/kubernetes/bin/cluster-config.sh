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
    echo "File  [${binfile}]"
    echo "Path  [${binpath}]"

    cloudname=${1:?}
    clusterid=${2:?}

    echo "---- ---- ----"
    echo "Cloud name  [${cloudname}]"
    echo "Cluster ID  [${clusterid}]"
    echo "---- ---- ----"


# -----------------------------------------------------
# Get the connection details for our cluster.

    configdir=${HOME}/.kube

    mkdir -p "${configdir:?}"
    chmod 'u=rwx,g=,o=' "${configdir:?}"

    openstack \
        --os-cloud "${cloudname:?}" \
        coe cluster config \
            "${clusterid:?}" \
                --force \
                --dir "${configdir:?}" \
    > '/dev/null' 2>&1

    chmod 'u=rw,g=,o=' "${configdir:?}/config"


