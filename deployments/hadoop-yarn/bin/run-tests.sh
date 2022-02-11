#!/bin/sh
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
    cloudname=${1:?}
    deployconf="${2:?}"

    inventory="${treetop:?}/hadoop-yarn/ansible/config/${deployconf:?}.yml"
    testlevel="${3:-quick}"
    concurrent="${4:-False}"
    num_users="${5:-1}"
    # Available test levels: [quick, basic, full, multiuser]

    echo "---- ---- ----"
    echo "Deploy conf [${deployconf}]"
    echo "Test Level [${testlevel}]"
    echo "Concurrent [${concurrent}]"
    echo "Number of users [${num_users}]"
    echo "---- ---- ----"

# -----------------------------------------------------
# Run Benchmarks

echo "Running multi user test"

if [[ "$testlevel" == "multiuser" ]]
then

echo "Running multi user test"

    pushd "/deployments/hadoop-yarn/ansible"

        ansible-playbook \
            --verbose \
            --inventory "${inventory:?}" \
            --extra-vars "testlevel=$testlevel concurrent=$concurrent num_users=$num_users" \
            "36-run-benchmark.yml" \

    popd

else

    echo "Running single user test"

    pushd "/deployments/hadoop-yarn/ansible"

        ansible-playbook \
            --verbose \
            --inventory "${inventory:?}" \
	    --extra-vars "testlevel=$testlevel concurrent=$concurrent num_users=$num_users"  \
            "36-run-benchmark.yml"

    popd

fi

