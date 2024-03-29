#!/bin/bash
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
    treetop="$(dirname $(dirname ${binpath}))"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"
    echo "Tree [${treetop}]"

# -----------------------------------------------------
# Format the HDFS NameNode on master01.

    echo ""
    echo "---- ----"
    echo "Formatting HDFS"

    ssh master01 \
        '
        hdfs namenode -format
        '


# -----------------------------------------------------
# Start the HDFS services on master01.

    echo ""
    echo "---- ----"
    echo "Starting HDFS"

    ssh master01 \
        '
        start-dfs.sh
        '


# -----------------------------------------------------
# Check the HDFS status.

    echo ""
    echo "---- ----"
    echo "HDFS status"

    ssh master01 \
        '
        hdfs dfsadmin -report
        '


