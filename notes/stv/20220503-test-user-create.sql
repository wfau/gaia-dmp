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


    Target:

        Test creating and importing users scripts

    Result:
  
        PASS (SLOW)


# -----------------------------------------------------
# Fetch target branch
#[user@desktop]

    source "${HOME:?}/aglais.env"
    pushd "${AGLAIS_CODE}"
      	git checkout 'feature/user-creation'

    popd


# -----------------------------------------------------
# Create a container to work with.
#[user@desktop]

    source "${HOME:?}/aglais.env"

    podman run \
        --rm \
        --tty \
        --interactive \
        --name ansibler \
        --hostname ansibler \
        --publish 3000:3000 \
        --publish 8088:8088 \
        --env "SSH_AUTH_SOCK=/mnt/ssh_auth_sock" \
        --volume "${SSH_AUTH_SOCK}:/mnt/ssh_auth_sock:rw,z" \
        --volume "${HOME:?}/clouds.yaml:/etc/openstack/clouds.yaml:ro,z" \
        --volume "${AGLAIS_CODE:?}/deployments:/deployments:ro,z" \
        --volume "${AGLAIS_SECRETS:?}/sql/:/deployments/common/zeppelin/sql/:ro,z" \
        atolmis/ansible-client:2021.08.25 \
        bash




# Deploy "prod"

# -----------------------------------------------------
# Set the cloud and configuration.
#[root@ansibler]

    cloudname=iris-gaia-red

    configname=zeppelin-26.43-spark-6.26.43


# -----------------------------------------------------
# Delete everything.
#[root@ansibler]

    time \
        /deployments/openstack/bin/delete-all.sh \
            "${cloudname:?}"

        > Done



# -----------------------------------------------------
# Create everything, using the new config.
#[root@ansibler]

    time \
        /deployments/hadoop-yarn/bin/create-all.sh \
            "${cloudname:?}" \
            "${configname:?}"   \
        | tee /tmp/create-all.log


        > Done


# -----------------------------------------------------
# Create (jdbc) users.
#[root@ansibler]

    time \
        /deployments/hadoop-yarn/bin/create-users.sh \
            "${cloudname:?}" \
            "${configname:?}"   \
            "jdbc"   \
        | tee /tmp/create-users.log

x
# -----------------------------------------------------
# Replace notebook with version in github.
#[root@ansibler]

  mv /home/fedora/zeppelin-0.10.0-bin-all/notebook/ /home/fedora/zeppelin-0.10.0-bin-all/notebook-backup
  git clone https://github.com/wfau/aglais-notebooks notebook


# -----------------------------------------------------
# Validate Zeppelin as 'gaiauser'
#[gaiauser@firefox]

# Login Successful
# Notebook create & run successful
# Logout


# -----------------------------------------------------
# Add a user
#[fedora@zeppelin]

sudo /home/fedora/zeppelin-0.10.0-bin-all/scripts/add_user.sh
Create a new Zeppelin user
Username: john  
Password: ****
User role: user
mysql: [Warning] Using a password on the command line interface can be insecure.
{"status":"OK","message":"","body":{"principal":"john","ticket":"306a46bd-fc5c-4e79-8401-784154323a6b","roles":"[\"user\"]"}}
{"status":"OK","message":"","body":"2H2UDJPNZ"}
{"status":"OK","message":"","body":"2H373CSAT"}
{"status":"OK","message":"","body":"2H1R1EWTX"}
{"status":"OK","message":"","body":"2H3SB5YCH"}
{"status":"OK","message":"","body":"2H1TZECKU"}
{"status":"OK","message":"","body":"2H2USGUAG"}
{"status":"OK","message":"","body":"2H47HMDRP"}



# -----------------------------------------------------
# Validate Zeppelin as 'john'
#[john@firefox]

# Login [SUCCESS]
# Run notebooks created under /Users/john/examples [SUCCESS]
# Test that other users cannot see new users examples folder [Success]
# Logout



# -----------------------------------------------------
# Validate zeppelin directories were created
#[fedora@zeppelin]

ls -l /home/fedora/zeppelin-0.10.0-bin-all/notebook/Users/john/examples/

total 2948
-rw-rw-r--. 1 fedora fedora  78779 May  3 11:50 Data_Holdings_2H373CSAT.zpln
-rw-rw-r--. 1 fedora fedora 816455 May  3 11:50 Good_astrometric_solutions_via_ML_Random_Forrest_classifier_2H2USGUAG.zpln
-rw-rw-r--. 1 fedora fedora 986851 May  3 11:50 Mean_proper_motions_over_the_sky_2H3SB5YCH.zpln
-rw-rw-r--. 1 fedora fedora 616764 May  3 11:54 Source_counts_over_the_sky_2H1R1EWTX.zpln
-rw-rw-r--. 1 fedora fedora  33824 May  3 11:53 Start_Here_2H2UDJPNZ.zpln
-rw-rw-r--. 1 fedora fedora 102573 May  3 11:50 Tips_and_tricks_2H47HMDRP.zpln
-rw-rw-r--. 1 fedora fedora 367923 May  3 11:50 Working_with_cross-matched_surveys_2H1TZECKU.zpln


ls -l

total 4
drwxrwxrwx. 7 root root    5 Jan  4 11:49 dcr
drwxrwxrwx. 2 root root 4096 May  3 11:50 john
drwxrwxrwx. 4 root root    6 Feb 15 13:47 nch
drwxrwxrwx. 2 root root    0 Apr 29 14:40 stv
drwxrwxrwx. 7 root root    9 Jan  5 13:30 zrq



# -----------------------------------------------------
# Export users to file
#[fedora@zeppelin]

sudo ./export-users.sh

# File auth.sql created


# -----------------------------------------------------
# Copy users file locally, to our secrets directory
#[fedora@zeppelin]

scp fedora@128.232.222.207:/home/fedora/zeppelin-0.10.0-bin-all/auth.sql ${AGLAIS_SECRETS}/sql/auth.sql


# Recreate deploy, validate that the new user persists across deploys


# Deploy "jdbc"

# -----------------------------------------------------
# Set the cloud and configuration.
#[root@ansibler]

    cloudname=iris-gaia-red

    configname=zeppelin-26.43-spark-6.26.43


# -----------------------------------------------------
# Delete everything.
#[root@ansibler]

    time \
        /deployments/openstack/bin/delete-all.sh \
            "${cloudname:?}"

        > Done



# -----------------------------------------------------
# Create everything, using the new config.
#[root@ansibler]

    time \
        /deployments/hadoop-yarn/bin/create-all.sh \
            "${cloudname:?}" \
            "${configname:?}"   \
        | tee /tmp/create-all.log


        > Done

# -----------------------------------------------------
# Create (test) users.
#[root@ansibler]

    time \
        /deployments/hadoop-yarn/bin/create-users.sh \
            "${cloudname:?}" \
            "${configname:?}"   \
            "jdbc"   \
        | tee /tmp/create-users.log


# -----------------------------------------------------
# Validate Zeppelin as 'john'
#[john@firefox]

# Login [SUCCESS]

# The directory created under /user has not been persisted
# The directory & notebooks created under Examples have not been saved anywhere, so they do not appear
# Logout


# Create another user
# [SUCCESS]




