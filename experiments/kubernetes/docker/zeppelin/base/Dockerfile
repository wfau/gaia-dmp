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

FROM debian:10.7-slim
MAINTAINER Apache Software Foundation <dev@zeppelin.apache.org>

ARG buildtag
ARG buildtime

LABEL maintainer="Dave Morris <docker-admin@metagrid.co.uk>"
LABEL buildtag="${buildtag}"
LABEL buildtime="${buildtime}"
LABEL gitrepo="https://github.com/wfau/aglais"

ENV LOG_TAG="[ZEPPELIN]:"
ENV LANG=en_GB.UTF-8
#ENV LC_ALL=en_GB.UTF-8

# Set the locale
# https://serverfault.com/questions/362903/how-do-you-set-a-locale-non-interactively-on-debian-ubuntu
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "$LOG_TAG configure locale" && \
    apt-get -y update && \
    apt-get install -y locales && \
    echo "$LANG UTF-8" > /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=$LANG

RUN echo "$LOG_TAG update and install basic packages" && \
    apt-get -y update && \
    apt-get install -y software-properties-common && \
    apt -y autoclean && \
    apt -y dist-upgrade && \
    apt-get install -y build-essential

RUN echo "$LOG_TAG install tini related packages" && \
    apt-get install -y wget curl grep sed dpkg && \
    TINI_VERSION=`curl https://github.com/krallin/tini/releases/latest | grep -o "/v.*\"" | sed 's:^..\(.*\).$:\1:'` && \
    curl -L "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}.deb" > tini.deb && \
    dpkg -i tini.deb && \
    rm tini.deb

# Create missing man directories.
# https://github.com/debuerreotype/debuerreotype/issues/10
# https://github.com/libvirt/libvirt-ci/commit/9cd2f73597e1599330e9657d51200eb0d2052bb2
RUN mkdir -p /usr/share/man/man1

# Update from openjdk-8-jdk to openjdk-11-jdk
# https://stackoverflow.com/questions/57031649/how-to-install-openjdk-8-jdk-on-debian-10-buster
# https://serverfault.com/questions/974992/why-isnt-there-a-openjdk-8-jdk-package-on-debian-anymore
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
RUN echo "$LOG_TAG Install java11" && \
    apt-get -y update && \
    apt-get install -y openjdk-11-jdk && \
    rm -rf /var/lib/apt/lists/*

# should install conda first before numpy, matploylib since pip and python will be installed by conda
RUN echo "$LOG_TAG Install miniconda3 related packages" && \
    apt-get -y update && \
    apt-get install -y bzip2 ca-certificates \
    libglib2.0-0 libxext6 libsm6 libxrender1 \
    git mercurial subversion && \
    echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-4.6.14-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh

ENV PATH /opt/conda/bin:$PATH
RUN echo "$LOG_TAG Install python related packages" && \
    apt-get -y update && \
    apt-get install -y python-dev python-pip && \
    apt-get install -y gfortran && \
    # numerical/algebra packages
    apt-get install -y libblas-dev libatlas-base-dev liblapack-dev && \
    # font, image
    apt-get install -y libpng-dev libfreetype6-dev libxft-dev && \
    # for tkinter
    apt-get install -y python-tk libxml2-dev libxslt-dev zlib1g-dev && \
    hash -r && \
    conda config --set always_yes yes --set changeps1 no && \
    conda update -q conda && \
    conda info -a && \
    conda config --add channels conda-forge && \
    pip install -q pycodestyle==2.5.0 && \
    pip install -q numpy==1.17.3 pandas==0.25.0 scipy==1.3.1 grpcio==1.19.0 bkzep==0.6.1 hvplot==0.5.2 protobuf==3.10.0 pandasql==0.7.3 ipython==7.8.0 matplotlib==3.0.3 ipykernel==5.1.2 jupyter_client==5.3.4 bokeh==1.3.4 panel==0.6.0 holoviews==1.12.3 seaborn==0.9.0 plotnine==0.5.1 intake==0.5.3 intake-parquet==0.2.2 altair==3.2.0 pycodestyle==2.5.0 apache_beam==2.15.0

RUN echo "$LOG_TAG Install R related packages" && \
    echo "PATH: $PATH" && \
    echo "deb http://cran.rstudio.com/bin/linux/debian buster-cran40/" | tee -a /etc/apt/sources.list && \
    apt-key adv --keyserver keys.gnupg.net --recv-key FCAE2A0E115C3D8A && \
    apt-get -y update && \
    apt-get -y --allow-unauthenticated install r-base r-base-dev && \
    R -e "install.packages('evaluate', repos = 'https://cloud.r-project.org')" && \
    R -e "install.packages('knitr', repos='http://cran.us.r-project.org')" && \
    R -e "install.packages('ggplot2', repos='http://cran.us.r-project.org')" && \
    R -e "install.packages('googleVis', repos='http://cran.us.r-project.org')" && \
    R -e "install.packages('data.table', repos='http://cran.us.r-project.org')" && \
    R -e "install.packages('IRkernel', repos = 'https://cloud.r-project.org');IRkernel::installspec()" && \
    R -e "install.packages('shiny', repos = 'https://cloud.r-project.org')" && \
    # for devtools, Rcpp
    apt-get -y install libcurl4-gnutls-dev libssl-dev libgit2-dev && \
    R -e "install.packages('devtools', repos='http://cran.us.r-project.org')" && \
    R -e "install.packages('Rcpp', repos='http://cran.us.r-project.org')" && \
    Rscript -e "library('devtools'); library('Rcpp'); install_github('ramnathv/rCharts')"

RUN echo "$LOG_TAG Cleanup" && \
    apt-get autoclean && \
    apt-get clean



