	#!/bin/sh
#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2021, ROE (http://www.roe.ac.uk/)
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

    echo "---- ---- ----"
    echo "Cloud base [${cloudbase}]"
    echo "Cloud name [${cloudname}]"
    echo "---- ---- ----"
    echo "Deploy conf [${deployconf}]"
    echo "---- ---- ----"


# -----------------------------------------------------
# Mount the data shares.

    sharelist="${treetop:?}/common/manila/datashares.yaml"
    mountmode='ro'

    for shareid in $(
        yq eval '.datashares.[].id' "${sharelist:?}"
        )
    do
        echo ""
        echo "Share [${shareid:?}]"

        sharecloud=$(
            yq eval ".datashares.[] | select(.id == \"${shareid:?}\").cloudname"  "${sharelist:?}"
            )
        sharename=$(
            yq eval ".datashares.[] | select(.id == \"${shareid:?}\").sharename"  "${sharelist:?}"
            )
        mountpath=$(
            yq eval ".datashares.[] | select(.id == \"${shareid:?}\").mountpath"  "${sharelist:?}"
            )

        "${treetop:?}/hadoop-yarn/bin/cephfs-mount.sh" \
            "${inventory:?}" \
            "${sharecloud:?}" \
            "${sharename:?}" \
            "${mountpath:?}" \
            "${mountmode:?}"

    done

# -----------------------------------------------------
# Add the data symlinks.
# Needs to be done after the data shares have been mounted.

    pushd "/deployments/hadoop-yarn/ansible"

        ansible-playbook \
            --inventory "${inventory:?}" \
            "61-data-links.yml"

    popd


# -----------------------------------------------------
# Check the data shares.
# Using a hard coded cloud name to make it portable.

    sharelist="${treetop:?}/common/manila/datashares.yaml"
    testhost=zeppelin

    for shareid in $(
        yq eval '.datashares.[].id' "${sharelist}"
        )
    do

        checkbase=$(
            yq eval ".datashares.[] | select(.id == \"${shareid}\").mountpath" "${sharelist}"
            )
        checknum=$(
            yq eval ".datashares.[] | select(.id == \"${shareid}\").checksums | length" "${sharelist}"
            )

        for (( i=0; i<checknum; i++ ))
        do
            checkpath=$(
                yq eval ".datashares.[] | select(.id == \"${shareid}\").checksums[${i}].path" "${sharelist}"
                )
            checkcount=$(
                yq eval ".datashares.[] | select(.id == \"${shareid}\").checksums[${i}].count" "${sharelist}"
                )
            checkhash=$(
                yq eval ".datashares.[] | select(.id == \"${shareid}\").checksums[${i}].md5sum" "${sharelist}"
                )

            echo ""
            echo "Share [${checkbase}/${checkpath}]"

            testcount=$(
                ssh "${testhost:?}" \
                    "
                    ls -1 ${checkbase}/${checkpath} | wc -l
                    "
                )

            if [ "${testcount}" == "${checkcount}" ]
            then
                echo "Count [PASS]"
            else
                echo "Count [FAIL][${checkcount}][${testcount}]"
            fi

            testhash=$(
                ssh "${testhost:?}" \
                    "
                    ls -1 -v ${checkbase}/${checkpath} | md5sum | cut -d ' ' -f 1
                    "
                )

            if [ "${testhash}" == "${checkhash}" ]
            then
                echo "Hash  [PASS]"
            else
                echo "Hash  [FAIL][${checkhash}][${testhash}]"
            fi
        done
    done


