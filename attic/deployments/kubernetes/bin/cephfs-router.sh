# -----------------------------------------------------
# Settings ...

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    treetop="$(dirname $(dirname ${binpath}))"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"
    echo "Tree [${treetop}]"

    cloudname=${1:?}
    buildname=${2:?}

    echo "---- ---- ----"
    echo "Cloud name [${cloudname}]"
    echo "Build name [${buildname}]"


# -----------------------------------------------------
# Identify our stack name.
# TODO check /tmp/cluster-stack.json

    stackname=$(
        jq -r '.stack_name' '/tmp/cluster-stack.json'
        )

    echo "---- ---- ----"
    echo "Stack name [${stackname}]"

# -----------------------------------------------------
# Identify our cluster router.

    openstack\
        --os-cloud "${cloudname:?}" \
        router list \
            --format json \
    | jq '.[] | select(.Name | startswith("'${stackname:?}'")) | select(.Name | test("extrouter"))' \
    > '/tmp/cluster-router.json'


# -----------------------------------------------------
# Identify our cluster subnet.

    openstack\
        --os-cloud "${cloudname:?}" \
        subnet list \
            --format json \
    | jq '.[] | select(.Name | startswith("'${stackname:?}'")) | select(.Name | test("private_subnet"))' \
    > '/tmp/cluster-subnet.json'


# -----------------------------------------------------
# Create the CephFS router.

    "${treetop:?}/openstack/bin/cephfs-router.sh" \
        "${cloudname:?}" \
        "${buildname:?}"



