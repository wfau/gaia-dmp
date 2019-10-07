#
# Copyright (c) 2018, ROE (http://www.roe.ac.uk/)
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

# FROM fedora:30
# https://github.com/docker-library/repo-info/blob/master/repos/fedora/tag-details.md#fedora30
FROM fedora@sha256:d39a02a0f13c1df3bbcb0ccea4021c53b8e0bfd87f701a5115e18ec089814e70

MAINTAINER [Dave Morris <docker-admin@metagrid.co.uk>]

#
# Mount the DNF cache as a volume.
VOLUME /var/cache/dnf

#
# Update the repo data.
RUN dnf -y makecache

#
# Install common admin tools.
RUN dnf install -y \
    sed \
    tar \
    zip \
    less \
    wget \
    nano \
    gzip \
    pwgen \
    gnupg \
    which

#
# Set the terminal type for exec.
# https://github.com/docker/docker/issues/9299
ENV TERM xterm

#
# Add our install scripts.
COPY bin /usr/local/bin/
RUN chmod a+x /usr/local/bin/*.sh

#
# Run our install scripts.
RUN /usr/local/bin/install-locale.sh

