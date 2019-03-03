#!/bin/bash

# Is the root folder environment variable set

if [ "$JTGNG_ROOT" = "" ]; then
    echo "ERROR: Missing JTGNG_ROOT environment variable. Define it to"
    echo "point to the github jt_gng folder path."
    exit 1
fi

# Is the project defined?
PRJ=$1
shift

if [ "$PRJ" = "" ]; then
    echo "ERROR: Missing project name."
    echo "Usage: compile.sh project_name "
    exit 1
fi

ZIP=TRUE
GIT=FALSE
PROG=FALSE
SKIP_COMPILE=FALSE

while [ $# -gt 0 ]; do
    case "$1" in
        "-skip") SKIP_COMPILE=TRUE;;
        "-git") GIT=TRUE;;
        "-prog") PROG=TRUE;;
        "-prog-only") 
            PROG=TRUE
            ZIP=FALSE
            SKIP_COMPILE=TRUE;;
        "-zip") shift; break;;
        "-help")
        cat << EOF
JT_GNG compilation tool. (c) Jose Tejada 2019, @topapate
    First argument is the project name, like jtgng, or jt1943

    -skip   skips compilation and goes directly to prepare the release file
            using the RBF file available.
    -git    adds the release file to git
    -prog   programs the FPGA
    -zip    all arguments from that point on will be used as inputs to the
            zip file. All files must be referred to $JTGNG_ROOT path
    -help   displays this message
EOF
            exit 0;;
        *)  echo "ERROR: Unknown option $1";
            exit 1;;
    esac
    shift
done

echo =======================================
echo $PRJ compilation starts at $(date +%T)

if [ $SKIP_COMPILE = FALSE ]; then
    # Update message file
    ${PRJ}_msg.py
    # Recompile
    cd $JTGNG_ROOT/${PRJ:2}/mist
    mkdir -p $JTGNG_ROOT/log
    quartus_sh --flow compile $PRJ > $JTGNG_ROOT/log/$PRJ.log
    if ! grep "Full Compilation was successful" $JTGNG_ROOT/log/$PRJ.log; then
        grep -i error $JTGNG_ROOT/log/$PRJ.log -A 2
        echo "ERROR while compiling the project. Aborting"
        exit 1
    fi
fi

if [ $ZIP = TRUE ]; then
    # Rename output file
    cd $JTGNG_ROOT
    RELEASE=${PRJ}_mist_$(date +"%Y%m%d")
    RBF=${PRJ:2}/mist/$PRJ.rbf
    if [ ! -e $RBF ]; then
        echo "ERROR: file $RBF does not exist. You need to recompile."
        exit 1
    fi
    cp $RBF $RELEASE.rbf
    zip --update --junk-paths releases/${RELEASE}.zip ${RELEASE}.rbf README.txt $*
    rm $RELEASE.rbf

    if [ -e rom/${PRJ:2}/build_rom.ini ]; then
        zip --junk-paths releases/$RELEASE.zip rom/build_rom.sh rom/${PRJ:2}/build_rom.ini
    fi

    function add_ifexists {
        if [ -e $1 ]; then
            zip --junk-paths releases/$RELEASE.zip $1
        fi   
    }

    add_ifexists doc/$PRJ.txt
    add_ifexists rom/${PRJ:2}/build_rom.bat
fi

# Add to git
if [ $GIT = TRUE ]; then
    git add -f ${PRJ:2}/mist/msg.hex
    git add releases/$RELEASE.zip
fi

if [ $PROG = TRUE ]; then
    quartus_pgm -c "USB-Blaster(Altera) [1-1.2]" ${PRJ:2}/mist/$PRJ.cdf
fi

echo completed at $(date)