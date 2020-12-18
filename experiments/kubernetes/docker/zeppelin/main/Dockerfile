# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARG buildsrc

FROM aglais/zeppelin-base:${buildsrc}
MAINTAINER Dave Morris <docker-admin@metagrid.co.uk>

ARG buildsrc
ARG buildtag
ARG buildtime

LABEL maintainer="Dave Morris <docker-admin@metagrid.co.uk>"
LABEL buildsrc="${buildsrc}"
LABEL buildtag="${buildtag}"
LABEL buildtime="${buildtime}"
LABEL gitrepo="https://github.com/wfau/aglais"

ENV Z_HOME="/zeppelin"
ENV ZEPPELIN_ADDR="0.0.0.0"

COPY . ${Z_HOME}/
RUN chown -R root:root ${Z_HOME} && \
    mkdir -p ${Z_HOME}/logs ${Z_HOME}/run ${Z_HOME}/webapps && \
    # Allow process to edit /etc/passwd, to create a user entry for zeppelin
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
    # Give access to some specific folders
    chmod -R 775 "${Z_HOME}/logs" "${Z_HOME}/run" "${Z_HOME}/notebook" "${Z_HOME}/conf" && \
    # Allow process to create new folders (e.g. webapps)
    chmod 775 ${Z_HOME}

COPY log4j.properties ${Z_HOME}/conf/

USER 1000

EXPOSE 8080

ENTRYPOINT [ "/usr/bin/tini", "--" ]
WORKDIR ${Z_HOME}
CMD ["bin/zeppelin.sh"]
