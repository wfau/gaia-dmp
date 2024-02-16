#!/bin/bash
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
# Test script for the live host warning.
# Means we can test the checks without deleting anything by accident.
# When all is stable we can delete this.
#

# ----------------------------------------------------------------
# Add the live system fingerprint to known_hosts.
# https://github.com/wfau/gaia-dmp/issues/1286

    if [ ! -e "${HOME}/.ssh" ]
    then
        mkdir "${HOME}/.ssh"
    fi
    if [ ! -e "${HOME}/.ssh/known_hosts" ]
    then
        touch "${HOME}/.ssh/known_hosts"
    fi
    if [[ $(grep --count 'live.gaia-dmp.uk' "${HOME}/.ssh/known_hosts") == 0 ]]
    then
        ssh-keyscan 'live.gaia-dmp.uk' 2>/dev/null >> "${HOME}/.ssh/known_hosts"
    fi

# ----------------------------------------------------------------
# Check if we are deleting live, confirm before continuing if yes

    live_hostname=$(ssh fedora@live.gaia-dmp.uk 'hostname')

    if [ $? -ne 0 ]; then
        echo "Failed to check the live system hostname"
        kill -INT $$
    fi

    if [[ "$live_hostname" == *"$cloudname"* ]]; then
        read -p "You are replacing the current live system!! Do you want to proceed? (y/N) " -n 1 -r
        echo
        if [[ $REPLY != "y" ]];
        then
            kill -INT $$
        fi
    fi


# ----------------------------------------------------------------
# Check we stop if we can't check the live hostname.

    live_hostname=$(ssh fedora@live.gaia-dmp.uk 'hostname')
# Wrong username
#   live_hostname=$(ssh frog@live.gaia-dmp.uk 'hostname')
# Wrong hostname
#   live_hostname=$(ssh fedora@toad.gaia-dmp.uk 'hostname')

    if [ $? -ne 0 ]; then
        echo "Failed to check the live system hostname"
        kill -INT $$
    fi


