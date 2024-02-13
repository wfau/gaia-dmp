#!/bin/bash
#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2023, ROE (http://www.roe.ac.uk/)
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

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    treetop="$(dirname $(dirname ${binpath}))"
    cloudname="${1:?}"
    deployconf="${2:?}"
    inventory="${treetop:?}/hadoop-yarn/ansible/config/${deployconf:?}.yml"


# -----------------------------------------------------
# Run tests (Ports, Redirects etc..)

    echo ""
    echo "---- ----"
    echo "Run some system status tests"

    pushd "/deployments/hadoop-yarn/ansible"

        ansible-playbook \
            --inventory "${inventory:?}" \
            "45-system-tests.yml"
    popd

