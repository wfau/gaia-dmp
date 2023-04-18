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
    treetop="$(dirname $(dirname ${binpath}))"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"
    echo "Tree [${treetop}]"

    cloudname=${1:?}

    echo "---- ---- ----"
    echo "Cloud name [${cloudname}]"
    echo "---- ---- ----"


# -----------------------------------------------------
# List the currenbt resources.

    echo ""
    echo "---- ----"
    echo "Clusters"

    openstack \
        --os-cloud "${cloudname:?}" \
        coe cluster list


    echo ""
    echo "---- ----"
    echo "Servers"
    openstack \
        --os-cloud "${cloudname:?}" \
        server list


    echo ""
    echo "---- ----"
    echo "Volumes"
    openstack \
        --os-cloud "${cloudname:?}" \
        volume list


    echo ""
    echo "---- ----"
    echo "Floating addresses"
    openstack \
        --os-cloud "${cloudname:?}" \
        floating ip list

    echo ""
    echo "---- ----"
    echo "Load balancers"
    openstack \
        --os-cloud "${cloudname:?}" \
        loadbalancer  list


    echo ""
    echo "---- ----"
    echo "Routers"
    openstack \
        --os-cloud "${cloudname:?}" \
        router list


    echo ""
    echo "---- ----"
    echo "Networks"
    openstack \
        --os-cloud "${cloudname:?}" \
        network list


    echo ""
    echo "---- ----"
    echo "Subnets"
    openstack \
        --os-cloud "${cloudname:?}" \
        subnet list


    echo ""
    echo "---- ----"
    echo "Security groups"
    openstack \
        --os-cloud "${cloudname:?}" \
        security group list





