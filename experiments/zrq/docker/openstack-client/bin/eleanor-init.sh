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
# Extract the network identifiers.

    openstack \
        network \
        list \
        --format json \
        | jq '.' \
        > /tmp/network-list.json

    match='^vm-network-UoE-external'
    externalnet=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/network-list.json
            )

    match='^vm-network-UoE-internal'
    internalnet=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/network-list.json
            )

    match='^Floating Network Public'
    publicnet=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/network-list.json
            )

    match='^Floating Network Private'
    privatenet=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/network-list.json
            )

# -----------------------------------------------------
# Extract the m1 flavor identifiers.

    openstack \
        flavor \
        list \
        --format json \
        | jq '.' \
        > /tmp/flavor-list.json

    match='^m1.small'
    m1small=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/flavor-list.json
            )

    match='^m1.medium'
    m1medium=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/flavor-list.json
            )

    match='^m1.large'
    m1large=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/flavor-list.json
            )

    match='^m1.xlarge'
    m1xlarge=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/flavor-list.json
            )

    match='^m1.xxlarge'
    m1xxlarge=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/flavor-list.json
            )

# -----------------------------------------------------
# Extract our target image identifiers.

    openstack \
        image \
        list \
        --format json \
        | jq '.' \
        > /tmp/image-list.json

    match='^fedora-27-docker'
    fedora27=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/image-list.json
            )

    match='^fedora-28-docker'
    fedora28=$(
        jq -r "
            .[] | select(.Name | test(\"${match:?}\")) | .ID
            " /tmp/image-list.json
            )


