
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
    echo "Restarting Zeppelin"

    ssh zeppelin \
        '
        /home/fedora/zeppelin-0.10.0-bin-all/bin/zeppelin-daemon.sh restart
        '

