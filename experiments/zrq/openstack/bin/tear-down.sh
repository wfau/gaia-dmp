#!/bin/sh
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
# Link our clouds.cfg file.
# https://docs.ansible.com/ansible/latest/reference_appendices/config.html#the-configuration-file

    mkdir /etc/openstack
    pushd /etc/openstack
        ln -sf /tmp/clouds.yaml
    popd

# -----------------------------------------------------
# Set the name prefix to look for.

    regex='^aglais'

# -----------------------------------------------------
# List our servers.

    echo ""
    echo "---- ---- ---- ----"
    echo "List servers"
    echo ""
    
    openstack \
        --os-cloud "${cloudname:?}" \
        server list


# -----------------------------------------------------
# Delete our servers (using JQ foo).

    echo ""
    echo "---- ---- ---- ----"
    echo "Delete servers"
    echo ""

    for serverid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            server list \
                --format json \
        | jq -r '.[] | select(.Name | test("'${regex:?}'")) | .ID'
        )
    do
        echo "Server [${serverid:?}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            server delete \
                "${serverid:?}"
    done


# -----------------------------------------------------
# Release our router ports (using JQ foo).

    echo ""
    echo "---- ---- ---- ----"
    echo "Release router ports"
    echo ""

    for routerid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            router list \
                --format json \
        | jq -r '.[] | select(.Name | test("'${regex:?}'")) | .ID'
        )
    do
        echo "Router [${routerid:?}]"

        for portid in $(
            openstack \
                --os-cloud "${cloudname:?}" \
                port list \
                    --router "${routerid:?}" \
                    --format json \
            | jq -r '.[] | .ID'
            )
        do
            echo "Port   [${portid:?}]"
            openstack \
                --os-cloud "${cloudname:?}" \
                router remove port \
                    "${routerid:?}" \
                    "${portid:?}"            
        done
    done


# -----------------------------------------------------
# Delete our routers (using JQ foo).

    echo ""
    echo "---- ---- ---- ----"
    echo "Delete routers"
    echo ""

    for routerid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            router list \
                --format json \
        | jq -r '.[] | select(.Name | test("'${regex:?}'")) | .ID'
        )
    do
        echo "Router [${routerid:?}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            router delete \
                "${routerid:?}"
    done

# -----------------------------------------------------
# Delete our networks.

    echo ""
    echo "---- ---- ---- ----"
    echo "Delete networks"
    echo ""

    for networkid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            network list \
                --format json \
        | jq -r '.[] | select(.Name | test("'${regex:?}'")) | .ID'
        )
    do
        echo "Network [${networkid:?}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            network delete \
                "${networkid:?}"
    done

# -----------------------------------------------------
# Delete our security groups.

    echo ""
    echo "---- ---- ---- ----"
    echo "Delete security groups"
    echo ""

    for groupid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            security group list \
                --format json \
        | jq -r '.[] | select(.Name | test("'${regex:?}'")) | .ID'
        )
    do
        echo "Group [${groupid:?}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            security group delete \
                "${groupid:?}"
    done


# -----------------------------------------------------
# Release all the floating IP addresses.

    echo ""
    echo "---- ---- ---- ----"
    echo "Release floating addresses"
    echo ""

    for addressid in $(
        openstack \
            --os-cloud "${cloudname:?}" \
            floating ip list \
                --format json \
        | jq -r '.[] | .ID'
        )
    do
        echo "Address [${addressid:?}]"
        openstack \
            --os-cloud "${cloudname:?}" \
            floating ip delete \
                "${addressid:?}"
    done


