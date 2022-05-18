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

# -----------------------------------------------------
# Settings ...

#    set -eu
#    set -o pipefail
#
#    binfile="$(basename ${0})"
#    binpath="$(dirname $(readlink -f ${0}))"
#    treetop="$(dirname $(dirname ${binpath}))"
#
#    echo ""
#    echo "---- ---- ----"
#    echo "File [${binfile}]"
#    echo "Path [${binpath}]"
#    echo "Tree [${treetop}]"
#    echo "---- ---- ----"
#


    # get the next available uid
    # https://www.commandlinefu.com/commands/view/5684/determine-next-available-uid
    getnextuid()
        {
        getent passwd | awk -F: '($3>600) && ($3<60000) && ($3>maxuid) { maxuid=$3; } END { print maxuid+1; }'
        }


    # Generate a new password hash.
    newpasshash()
        {
        local password="${1:?}"
        java \
            -jar "${HOME}/lib/shiro-tools-hasher.jar" \
            -i 500000 \
            -f shiro1 \
            -a SHA-256 \
            -gss 128 \
            '${password:?}'
        }

