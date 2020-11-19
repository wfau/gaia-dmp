# -----------------------------------------------------
# Settings ...

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    srcpath="$(dirname ${binpath})"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"

    cloudname=${1:?}
    buildname=${2:?}

    echo "---- ---- ----"
    echo "Cloud name [${cloudname}]"
    echo "Build name [${buildname}]"
    echo "---- ---- ----"

# -----------------------------------------------------
# Identify our cluster router.

    openstack \
        --os-cloud "${cloudname:?}" \
        router list \
            --format json \
    | jq '.[] | select(.Name == "'${buildname}'-internal-network-router")' \
    > '/tmp/cluster-router.json'


# -----------------------------------------------------
# Identify our cluster subnet.

    openstack \
        --os-cloud "${cloudname:?}" \
        subnet list \
            --format json \
    | jq '.[] | select(.Name == "'${buildname}'-internal-network-subnet")' \
    > '/tmp/cluster-subnet.json'


# -----------------------------------------------------
# Create the CephFS router.

    '/openstack/bin/cephfs-router.sh' \
        "${cloudname:?}" \
        "${buildname:?}"



