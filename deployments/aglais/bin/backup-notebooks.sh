#!/bin/sh
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

timestamp=$(date +"%Y%m%d")

directory_name="/var/local/backups/notebooks/${timestamp}-live.gaia-dmp.uk-notebooks/"

if [ -d "$directory_name" ]; then
  # If the directory already exists, synchronize with the remote directory
  rsync -avz --delete fedora@dmp.gaia.ac.uk:/home/fedora/zeppelin/notebook/ "$directory_name/notebook"
else
  # If the directory doesn't exist, create it and copy the remote directory
  mkdir "$directory_name"
  scp -r fedora@dmp.gaia.ac.uk:/home/fedora/zeppelin/notebook "$directory_name"
fi

scp -r fedora@dmp.gaia.ac.uk:/home/fedora/zeppelin/conf/notebook-authorization.json "$directory_name"

alias_path="/tmp/latest"
ln -sf "$directory_name" "$alias_path"

echo "Script executed successfully."
