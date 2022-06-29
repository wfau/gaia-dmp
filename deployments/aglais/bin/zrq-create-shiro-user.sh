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

srcfile="$(basename ${0})"
srcpath="$(dirname $(readlink -f ${0}))"

# Include our JSON formatting tools.
source "${srcpath}/json-tools.sh"

username="${1}"
usertype="${2}"
passhash="${3:-''}"
password="${4:-''}"
userrole="${5:-'user'}"




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






            #!/bin/bash
            # Create MySQL user
            NEW_USERNAME=${1:?}
            NEW_USERTYPE=${2:?}
            NEW_PASSWORD_ENCRYPTED=${3:-''}
            NEW_PASSWORD=''

            USER_TABLE='users';
            USER_ROLES_TABLE='user_roles'

            if [ -z "${NEW_PASSWORD_ENCRYPTED}" ]
            then
                NEW_PASSWORD=$(
                    pwgen 30 1
                    )
                NEW_PASSWORD_ENCRYPTED="$(java -jar {{aghome}}/lib/shiro-tools-hasher-cli.jar -i 500000 -f shiro1 -a SHA-256 -gss 128 $NEW_PASSWORD)"
            fi

            mysql {{shirodbname}} << EOF
            INSERT INTO $USER_TABLE (username, password) VALUES ("$NEW_USERNAME", "$NEW_PASSWORD_ENCRYPTED");
            INSERT INTO $USER_ROLES_TABLE (username, role_name) VALUES ("$NEW_USERNAME", "$NEW_USERTYPE");
            EOF

            cat << EOF
            {
            "name": "${NEW_USERNAME}",
            "type": "${NEW_USERTYPE}",
            "pass": "${NEW_PASSWORD}",
            "hash": "${NEW_PASSWORD_ENCRYPTED}"
            }
            EOF

