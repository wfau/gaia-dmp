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
# Functions to parse Eleanor OpenStack address information.

    eleanorinternalmatch()
        {
        local haystack=${1:?}
        ipaddressmatch \
            'vm-network-UoE-internal' \
            "${haystack}"
        }

    eleanorexternalmatch()
        {
        local haystack=${1:?}
        ipaddressmatch \
            'vm-network-UoE-external' \
            "${haystack}"
        }

    eleanorexternal()
        {
        local jsonfile=${1:-$(vmjsonpath)}
        eleanorexternalmatch \
            "$(getvmaddresses ${jsonfile})"
        }

    eleanorinternal()
        {
        local jsonfile=${1:-$(vmjsonpath)}
        eleanorinternalmatch \
            "$(getvmaddresses ${jsonfile})"
        }

# -----------------------------------------------------
# Functions to create Eleanor floating IP addresses.

    makeinternalfloat()
        {
        makefloat ${privatenet:?}
        }

    makeexternalfloat()
        {
        makefloat ${publicnet:?}
        }

# -----------------------------------------------------
# Functions to add Eleanor floating IP addresses.

    addinternalfloat()
        {
        local vmident=${1:?}

        getvminfo "${vmident}"

        local vmaddresses=(
            $(eleanorinternal)
            )
        local vmaddress=${vmaddresses[0]}

        local floating=$(makeinternalfloat)

        linkvmfloat \
            "${vmident:?}" \
            "${vmaddress:?}" \
            "${floating:?}"

        echo "${floating:?}"    
        }

    addexternalfloat()
        {
        local vmident=${1:?}

        getvminfo "${vmident}"

        local vmaddresses=(
            $(eleanorexternal)
            )
        local vmaddress=${vmaddresses[0]}

        local floating=$(makeexternalfloat)

        linkvmfloat \
            "${vmident:?}" \
            "${vmaddress:?}" \
            "${floating:?}"
        
        echo "${floating:?}"    
        }

# -----------------------------------------------------
# Functions to get Eleanor addresses.
# This assumes one 192 address followed by one 172 address.

        geteleanor192()
            {
            local internals=(
                $(eleanorinternal)
                )
            echo "${internals[0]}"
            }

        geteleanor172()
            {
            local internals=(
                $(eleanorinternal)
                )
            echo "${internals[1]}"
            }

