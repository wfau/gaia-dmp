#!/bin/bash
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

srcfile="$(basename ${0})"
srcpath="$(dirname $(readlink -f ${0}))"

# Include our JSON formatting tools.
source "${srcpath}/json-tools.sh"

username=${1}
usertype=${2}

# TODO Move these to an Ansible managed config file.
hdfsbase='/albert'
hdfsgroup='supergroup'

hdfspath="${hdfsbase}/${username}"

# Check required params
if [ -z "${username}" ]
then
    jsonerror "[username] required"
    exit 1
fi

if [ -z "${usertype}" ]
then
    jsonerror "[usertype] required"
    exit 1
fi

# Create the HDFS directory.
hdfs dfs -mkdir -p "${hdfspath}"
if [ $? -eq 0 ]
then
    passmessage "hdfs mkdir [${hdfspath}] done"
else
    failmessage "hdfs mkdir [${hdfspath}] failed"
fi

# Set the HDFS directory owner.
hdfs dfs -chown "${username}:${hdfsgroup}" "${hdfspath}"
if [ $? -eq 0 ]
then
    passmessage "hdfs chown [${hdfspath}] done"
else
    failmessage "hdfs chown [${hdfspath}] failed"
fi

cat << EOF
{
"path":  "${hdfspath}",
"owner": "${username}",
"group": "${hdfsgroup}",
$(jsondebug)
}
EOF

