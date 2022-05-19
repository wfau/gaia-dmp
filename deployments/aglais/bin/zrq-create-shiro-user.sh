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

user=${1:?}
hash=${2}
pass=''

if [ -z "${hash}" ]
then
    pass=$(
        pwgen 30 1
        )
    hash=$(
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
    INSERT INTO users (username, password) VALUES (\"${user}\", \"${hash}\");
    INSERT INTO user_roles (username, role_name) VALUES (\"${user}\", \"user\");
    "

cat << EOF
{
"name": "${user}",
"pass": "${pass}",
"hash": "${hash}"
}
EOF

