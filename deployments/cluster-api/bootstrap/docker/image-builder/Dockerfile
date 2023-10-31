#
# Copyright (c) 2023, ROE (http://www.roe.ac.uk/)
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

ARG buildtag

FROM registry.k8s.io/scl-image-builder/cluster-node-image-builder-amd64:v0.1.19

ARG buildtag
ARG buildtime

LABEL maintainer "Dave Morris <docker-admin@metagrid.co.uk>"
LABEL buildtag   "${buildtag}"
LABEL buildtime  "${buildtime}"
LABEL vendor     "Wide Field Astronomy Unit (WFAU)"
LABEL version    "${buildtag}"
LABEL license    "GPL-3.0-or-later"
LABEL org.opencontainers.image.created  "${buildtime}"
LABEL org.opencontainers.image.vendor   "Wide Field Astronomy Unit (WFAU)"
LABEL org.opencontainers.image.version  "${buildtag}"
LABEL org.opencontainers.image.licenses "GPL-3.0-or-later"
LABEL org.opencontainers.image.source   "https://github.com/wfau/gaia-dmp"
LABEL org.opencontainers.image.authors  "https://github.com/Zarquan"

#
# Swap to the root account to install things.
USER root

#
# Because Debian.
ENV DEBIAN_FRONTEND=noninteractive

#
# Update apt .. because it can't do it itself.
RUN apt-get update

#
# Install pip.
RUN apt-get install \
      --yes \
      python3-pip

#
# Install Python wheel.
# https://github.com/pypa/pip/issues/8559
RUN apt-get install \
      --yes \
      python3-wheel

#
# Install Jq.
RUN apt-get install \
      --yes \
      jq

#
# Install Yq.
# https://mikefarah.gitbook.io/yq/v/v3.x/#on-ubuntu-16.04-or-higher-from-debian-package
RUN apt-get install \
      --yes \
      software-properties-common
RUN add-apt-repository \
      --yes \
      ppa:rmescandon/yq
RUN apt-get update
RUN apt-get install \
      --yes \
      yq

#
# Install the Openstack client.
RUN apt-get install \
      --yes \
      --quiet \
      python3-openstacksdk \
      python3-openstackclient \
      python3-octaviaclient \
      python3-manilaclient \
      python3-magnumclient

#
# Swap back to the xx account.
USER imagebuilder

