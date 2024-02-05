#!/bin/bash
#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2020, ROE (http://www.roe.ac.uk/)
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

# -----------------------------------------------------
# Settings ...

    set -eu
    set -o pipefail

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    srcpath="$(dirname ${binpath})"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"

    configyml=${1:-'/tmp/aglais-config.yml'}
    statusyml=${2:-'/tmp/aglais-status.yml'}

    buildname="aglais-$(date '+%Y%m%d')"
    builddate="$(date '+%Y%m%d:%H%M%S')"

    namespace=$(
        yq read '/tmp/aglais-status.yml' 'aglais.status.kubernetes.namespace'
        )

# -----------------------------------------------------
# Capture our Dashboard ingress IP address.
# ** This has to be done after a delay to allow Kubernetes time to allocate the IP address.

    dashipv4=$(
        kubectl \
            --namespace "${namespace:?}" \
            get Ingress \
                --output json \
        | jq -r '
            .items[]
          | select(.metadata.name == "aglais-dashboard-kubernetes-dashboard")
          | .status.loadBalancer.ingress[0].ip
          '
        )

    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.kubernetes.ingress.dashboard.ipv4' \
            "${dashipv4}"


# -----------------------------------------------------
# Capture our Zeppelin ingress IP address.
# ** This has to be done after a delay to allow Kubernetes time to allocate the IP address.

    zeppipv4=$(
        kubectl \
            --namespace "${namespace:?}" \
            get Ingress \
                --output json \
        | jq -r '
            .items[]
          | select(.metadata.name == "zeppelin-server-ingress")
          | .status.loadBalancer.ingress[0].ip
          '
        )

    yq write \
        --inplace \
        "${statusyml:?}" \
            'aglais.status.kubernetes.ingress.zeppelin.ipv4' \
            "${zeppipv4}"


