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
    deploytype="${3:-prod}"



    echo "---- ---- ----"
    echo "Deploy conf [${deployconf}]"
    echo "Deploy Type [${deploytype}]"
    echo "---- ---- ----"


    # Create the Zeppelin Shiro Database.

    echo ""
    echo "---- ----"
    echo "Creating Zeppelin Shiro database"

    pushd "${treetop:?}/hadoop-yarn/ansible"

            ansible-playbook \
                --inventory "${inventory:?}" \
                "38-install-user-db.yml"
    popd



    # Import users

    pushd "${treetop:?}/hadoop-yarn/ansible"


        if [ "${deploytype}" == "test" ]
        then
            ansible-playbook \
                --inventory "${inventory:?}" \
                --extra-vars "users_import_file=auth-test.sql" \
                "39-import-users.yml"
        else
            ansible-playbook \
                --inventory "${inventory:?}" \
                --extra-vars "users_import_file=auth.sql" \
                "39-import-users.yml"
        fi

    popd


# -----------------------------------------------------
# Restart the Zeppelin service.

    "${treetop:?}/hadoop-yarn/bin/restart-zeppelin.sh"


