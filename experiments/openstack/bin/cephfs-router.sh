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

    cloudname=${1:?}
    matchname=${2:?}

    projectname="iris-${cloudname:?}"

# -----------------------------------------------------
# Locate the project source directory.

    binpath=$(dirname $(readlink -f ${0}))
    srcpath=$(dirname ${binpath})

# -----------------------------------------------------
# Get our project ID.

    projectid=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            project list \
                --format json \
        | jq -r '.[] | select(.Name == "'${projectname:?}'") | .ID'
        )

    echo ""
    echo "---- ----"
    echo "Project name [${projectname:?}]"
    echo "Project ID   [${projectid:?}]"


# -----------------------------------------------------
# Create a new router.

    openstack \
        --os-cloud "${cloudname:?}" \
        router create \
            --format json \
            --enable \
            --project "${projectid:?}" \
            "ceph-router" \
    > "ceph-router.json"

    cephroutername=$(
        jq -r '. | .name' "ceph-router.json"
        )

    cephrouterid=$(
        jq -r '. | .id' "ceph-router.json"
        )


# -----------------------------------------------------
# Set the router's external gateway.

    cumulusnetid=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            network list \
                --format json \
        | jq -r '.[] | select(.Name == "cumulus-internal") | .ID'
        )

    openstack \
        --os-cloud "${cloudname:?}" \
        router set \
            --external-gateway "${cumulusnetid:?}" \
            "${cephrouterid:?}"


# -----------------------------------------------------
# Create a network port for our cluster subnet.

    openstack \
        --os-cloud "${cloudname:?}" \
        subnet list \
            --format json \
    | jq '.[] | select(.Name | startswith("'${matchname:?}'"))' \
    > '/tmp/cluster-subnet.json'

    clustersubid=$(
        jq -r '.ID' '/tmp/cluster-subnet.json'
        )

    clustersubname=$(
        jq -r '.Name' '/tmp/cluster-subnet.json'
        )

    clusternetid=$(
        jq -r '.Network' '/tmp/cluster-subnet.json'
        )

    openstack \
        --os-cloud "${cloudname:?}" \
        port create \
            --format json \
            --network "${clusternetid:?}" \
            --fixed-ip "subnet=${clustersubid:?}" \
        "cluster-subnet-port" \
    > "/tmp/cluster-subnet-port.json"

    echo ""
    echo "---- ----"
    echo "Cluster subnet name [${clustersubname:?}]"
    echo "Cluster subnet ID   [${clustersubid:?}]"
    echo ""
    echo "Cluster subnet port"
    jq '{network_id, fixed_ips}'  "/tmp/cluster-subnet-port.json"


# -----------------------------------------------------
# Add the network port to our Ceph router.

    subnetportid=$(
        jq -r '.id' "/tmp/cluster-subnet-port.json"
        )

    openstack \
        --os-cloud "${cloudname:?}" \
        router add port \
            "${cephrouterid:?}" \
            "${subnetportid:?}"

# -----------------------------------------------------
# Get details of the Ceph router.

    echo ""
    echo "---- ----"
    echo "Ceph router name [${cephroutername:?}]"
    echo "Ceph router ID   [${cephrouterid:?}]"
    echo ""
    echo "Ceph router info"
    openstack \
        --os-cloud "${cloudname:?}" \
        router show \
            --format json \
            "${cephrouterid:?}" \
    | jq '{external_gateway_info, interfaces_info, routes}'


# -----------------------------------------------------
# Identify our cluster router.

    openstack \
        --os-cloud "${cloudname:?}" \
        router list \
            --format json \
    | jq '.[] | select(.Name | startswith("'${matchname}'"))' \
    > '/tmp/cluster-router.json'

    clusterrouterid=$(
        jq -r '.ID' '/tmp/cluster-router.json'
        )

    clusterroutername=$(
        jq -r '.Name' '/tmp/cluster-router.json'
        )

# -----------------------------------------------------
# Add a route for the Ceph network to our cluster router.

    subnetportip=$(
        jq -r '.fixed_ips[0].ip_address' '/tmp/cluster-subnet-port.json'
        )

    openstack \
        --os-cloud "${cloudname:?}" \
        router set \
            --route "destination=10.206.0.0/16,gateway=${subnetportip:?}" \
            "${clusterrouterid:?}"

# -----------------------------------------------------
# Get details of the cluster router.

    echo ""
    echo "---- ----"
    echo "Cluster router name [${clusterroutername:?}]"
    echo "Cluster router ID   [${clusterrouterid:?}]"
    echo ""
    echo "Cluster router info"
    openstack \
        --os-cloud "${cloudname:?}" \
        router show \
            --format json \
            "${clusterrouterid:?}" \
    | jq '{external_gateway_info, interfaces_info, routes}'


