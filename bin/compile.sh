#!/bin/bash

# Is the root folder environment variable set

if [ "$JTGNG_ROOT" = "" ]; then
    echo "ERROR: Missing JTGNG_ROOT environment variable. Define it to"
    echo "point to the github jt_gng folder path."
    exit 1
fi

# Is the project defined?
PRJ=$1
ZIP=
shift

if [ "$PRJ" = "" ]; then
    echo "ERROR: Missing project name."
    echo "Usage: compile.sh project_name "
    exit 1
fi

GIT=FALSE
SKIP_COMPILE=FALSE

while [ $# -gt 0 ]; do
    case "$1" in
        "-skip") SKIP_COMPILE=TRUE;;
        "-git") GIT=TRUE;;
        "-zip") shift; break;;
        "-help")
        cat << EOF
JT_GNG compilation tool. (c) Jose Tejada 2019, @topapate
    First argument is the project name, like jtgng, or jt1943

    -skip   skips compilation and goes directly to prepare the release file
            using the RBF file available.
    -git    adds the release file to git
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

if [ $SKIP_COMPILE = FALSE ]; then
    # Update message file
    ${PRJ}_msg.py
    # Recompile
    cd $JTGNG_ROOT/${PRJ:2}/mist
    quartus_sh --flow compile $PRJ
    if $?; then
        echo "ERROR while compiling the project. Aborting"
        exit 1
    fi
else
    echo "INFO: Skipping compilation"
fi

# Rename output file
cd $JTGNG_ROOT
RELEASE=${PRJ}_mist_$(date +"%Y%m%d")
RBF=${PRJ:2}/mist/$PRJ.rbf
if [ ! -e $RBF ]; then
    echo "ERROR: file $RBF does not exist. You need to recompile."
    exit 1
fi
cp $RBF $RELEASE.rbf
zip --update releases/${RELEASE}.zip ${RELEASE}.rbf README.txt $*

if [ -e rom/${PRJ:2}/build_rom.ini ]; then
    zip releases/$RELEASE.zip rom/build_rom.sh rom/${PRJ:2}/build_rom.ini
fi

# Add to git
if [ $GIT = TRUE ]; then
    git add -f ${PRJ:2}/mist/msg.hex
    git add releases/$RELEASE.zip
fi