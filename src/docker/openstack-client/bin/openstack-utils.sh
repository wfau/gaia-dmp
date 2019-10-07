#!/bin/sh
#
# Copyright (c) 2018, ROE (http://www.roe.ac.uk/)
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# -----------------------------------------------------
# Function to return the default JSON file.

    vmjsonpath()
        {
        echo "${1:-/tmp/vm-info.json}"
        }

# -----------------------------------------------------
# Function to create a virtual machine.

    # OpenStack fails if create calls are too rapid.
    makevmdelay=30

    makevm()
        {
        local vmname=${1:?}
        local vmflavor=${2:-${phym_flavor:?}}
        local vmimage=${3:-${phym_image:?}}
        local projid=${4:-${phym_project:?}}
        local keyid=${5:-${phym_userkey:?}}
        local netid=${6:-${internalnet:?}}
        local jsonfile=${7:-$(vmjsonpath)}

        # TODO - connect to both internal and external networks ..

        openstack \
            server \
            create \
            --format json \
            --image "${vmimage:?}" \
            --flavor "${vmflavor:?}" \
            --nic "net-id=${netid:?}" \
            --key-name "${keyid:?}" \
            "${projid:?}-${vmname:?}" \
            | jq '.' \
            > "${jsonfile:?}"

        if [[ -v makevmdelay ]]
        then
            sleep "${makevmdelay}"
        fi
        
        jq -r "
            .id
            " "${jsonfile:?}"
        }

# -----------------------------------------------------
# Function to fetch our instance JSON.

    getvminfo()
        {
        local vmident=${1:?}
        local jsonfile=${2:-$(vmjsonpath)}
        openstack \
            server \
            show \
            --format json \
            "${vmident:?}" \
            | jq '.' \
            > "${jsonfile}"
        }

# -----------------------------------------------------
# Functions to read properties from our instance JSON.

    getvmname()
        {
        local jsonfile=${1:-$(vmjsonpath)}
        jq -r "
            .name
            " "$(vmjsonpath)"
        }

    getvmimage()
        {
        local jsonfile=${1:-$(vmjsonpath)}
        jq -r "
           .image
            " "${jsonfile:?}"
        }

    getvmflavor()
        {
        local jsonfile=${1:-$(vmjsonpath)}
        jq -r "
           .flavor
            " "${jsonfile:?}"
        }

    getvmaddresses()
        {
        local jsonfile=${1:-$(vmjsonpath)}
        jq -r "
            .addresses
            " "${jsonfile}"
        }

# -----------------------------------------------------
# Function to parse OpenStack IP address information.

    ipaddressmatch()
        {
        local network=${1:?}
        local haystack=${2:?}
        echo "${haystack}" | sed -n '
            s/,//g
            s/.*'${network}'=\([0-9. ]*\).*/\1/p
            '
        }

# -----------------------------------------------------
# Function to create a floating IP address.

    makefloat()
        {
        local network=${1:?}
        openstack \
            floating ip \
            create \
            --format json \
            "${network:?}" \
            | jq '.' \
            > /tmp/floating-info.json

        jq -r "
            .floating_ip_address
            " /tmp/floating-info.json
        }

# -----------------------------------------------------
# Function to connect a floating address to a virtual machine.

    linkvmfloat()
        {
        local vmident=${1:?}
        local vmaddress=${2:?}
        local floatip=${3:?}
        openstack \
            server \
            add \
            floating ip \
            --fixed-ip-address "${vmaddress:?}" \
            "${vmident:?}" \
            "${floatip:?}"
        }

# -----------------------------------------------------
# Function to create a new volume.

    makevolume()
        {
        local volname=${1:?}
        local volsize=${2:?}

        openstack \
            volume create \
             --size "${volsize:?}"  \
             --format json  \
            "${volname:?}"  \
            | jq '.' \
            > /tmp/volume-info.json

        jq -r "
            .id
            " /tmp/volume-info.json
        }

