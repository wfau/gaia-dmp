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
    buildname=${2:?}

    echo "---- ---- ----"
    echo "Cloud name  [${cloudname}]"
    echo "Build name  [${buildname}]"
    echo "---- ---- ----"


# -----------------------------------------------------
# Get our SSH keypair.

    keyname=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            keypair list \
                --format json \
        | jq -r '.[0] | .Name'
        )

    echo ""
    echo "---- ----"
    echo "SSH key name  [${keyname}]"

# -----------------------------------------------------
# Get the virtual machine flavors.

    mastercount=1
    workercount=4

    masterflavorname='general.v1.tiny'
    workerflavorname='general.v1.medium'

    masterflavorid=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            flavor list \
                --format json \
        | jq -r '.[] | select(.Name == "'${masterflavorname:?}'") | .ID'
        )

    workerflavorid=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            flavor list \
                --format json \
        | jq -r '.[] | select(.Name == "'${workerflavorname:?}'") | .ID'
        )

    echo ""
    echo "---- ----"
    echo "Master count  [${mastercount}]"
    echo "Master flavor [${masterflavorname}][${masterflavorid}]"
    echo "Worker count  [${workercount}]"
    echo "Worker flavor [${workerflavorname}][${workerflavorid}]"

# -----------------------------------------------------
# Get the uuid for the '1.17' template.

    templatename='kubernetes-1.17.2-20200205'
    templateuuid=$(
        openstack \
            --os-cloud "${cloudname:?}" \
            coe cluster template list \
                --format json \
        | jq -r '.[] | select(.name == "'${templatename:?}'") | .uuid'
        )

    echo ""
    echo "---- ----"
    echo "Template name [${templatename}]"
    echo "Template uuid [${templateuuid}]"


# -----------------------------------------------------
# Create a new cluster.

    clustername="${buildname:?}-cluster"

    echo ""
    echo "---- ----"
    echo "Creating cluster"

    openstack \
        --os-cloud "${cloudname:?}"-super \
        coe cluster create \
            --keypair          "${keyname:?}" \
            --master-count     "${mastercount:?}" \
            --master-flavor    "${masterflavorid:?}" \
            --node-count       "${workercount:?}" \
            --flavor           "${workerflavorid:?}" \
            --cluster-template "${templateuuid:?}" \
            --merge-labels \
            --label "foo=bar" \
            --label "foo.aglais.uk=bar" \
            --label "http://labels.aglais.uk/foo=bar" \
            "${clustername:?}" \
    > /tmp/cluster-create.txt

    clusteruuid=$(
        sed -n '
            s/Request to create cluster \([-0-9a-f]*\) accepted/\1/p
            ' '/tmp/cluster-create.txt'
        )

    echo "Cluster ID [${clusteruuid}]"


    echo ""
    echo "---- ----"
    echo "Polling status"

    # TODO Move to common tools
    pullstatus()
        {
        local clid=${1:?}
        openstack \
            --os-cloud "${cloudname:?}"-super \
            coe cluster show \
                --format json \
                "${clid:?}" \
        > '/tmp/cluster-status.json'
        # TODO Catch HTTP 404 error
        }

    jsonstatus()
        {
        jq -r '.status' '/tmp/cluster-status.json'
        # TODO Catch blank file
        }

    bothstatus()
        {
        local clid=${1:?}
        pullstatus "${clid:?}"
        jsonstatus
        }

     while [ $(bothstatus ${clusteruuid:?}) == 'CREATE_IN_PROGRESS' ]
        do
            echo "IN PROGRESS"
            sleep 10
        done

    if [ $(jsonstatus) == 'CREATE_COMPLETE' ]
    then
        echo "COMPLETE"
    else
        echo "CREATE FAILED"
        cat '/tmp/cluster-status.json'
    fi


# -----------------------------------------------------
# Get the stack details.

    stackuuid=$(
        openstack\
            --os-cloud "${cloudname:?}" \
            coe cluster show \
                --format json \
                "${clusteruuid:?}" \
        | jq -r '.stack_id'
        )

    openstack\
        --os-cloud "${cloudname:?}" \
        stack show \
            --format json \
            "${stackuuid:?}" \
        > '/tmp/cluster-stack.json'


    stackname=$(
        openstack\
            --os-cloud "${cloudname:?}" \
            stack show \
                --format json \
                "${stackuuid:?}" \
            | jq -r '.stack_name'
        )

    echo ""
    echo "---- ----"
    echo "Stack uuid [${stackuuid}]"
    echo "Stack name [${stackname}]"

