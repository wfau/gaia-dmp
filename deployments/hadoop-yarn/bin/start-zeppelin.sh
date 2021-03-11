
# -----------------------------------------------------
# Settings ...

    binfile="$(basename ${0})"
    binpath="$(dirname $(readlink -f ${0}))"
    srcpath="$(dirname ${binpath})"

    echo ""
    echo "---- ---- ----"
    echo "File [${binfile}]"
    echo "Path [${binpath}]"

# -----------------------------------------------------
# Start the Zeppelin service.

    echo ""
    echo "---- ----"
    echo "Starting Zeppelin"

    ssh zeppelin \
        '
        /home/fedora/zeppelin-0.8.2-bin-all/bin/zeppelin-daemon.sh start
        '

