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
# This script isn't used at the moment, the equivalent script is created by the creat-user-scripts Ansible playbook.
# We will probably move most of the code out of the Ansible playbook into small scripts like this in a future PR.
# Which will hopefully make them easier to maintain.
#

username="${1:?}"
usertype="${2:?}"
passhash="${3:?}"
userrole=${4:-'user'}
password=''

if [ -z "${passhash}" ]
then
    pass=$(
        pwgen 30 1
        )
    passhash=$(
        java \
            -jar '/opt/aglais/lib/shiro-tools-hasher-cli.jar' \
            -i 500000 \
            -f shiro1 \
            -a SHA-256 \
            -gss 128 \
            "${pass}"
        )
fi

mysql --execute \
    "
    INSERT INTO users (username, password) VALUES (\"${username}\", \"${passhash}\");
    INSERT INTO user_roles (username, role_name) VALUES (\"${username}\", \"${userrole}\");
    "

cat << EOF
{
"name": "${user}",
"pass": "${pass}",
"hash": "${hash}"
}
EOF

