#!/bin/bash
# Show the pause screen

../../../bin/jtgng_msg.py

function check_hex_file {
    if [ ! -e $1 ]; then
        if [ ! -e ../../mist/$1 ]; then
            echo Missing HEX files for PAUSE screen. Attempting to generate them:
        fi
        echo INFO: Created symbolic link to $1
        ln -s ../../mist/$1
    fi
}

go.sh -frame 1 $*  -video -mister -d DIP_TEST -nosnd -d NOMAIN -d ALWAYS_PAUSE\
     -d NOSCR -d BYPASS_OSD -d SCANDOUBLER_DISABLE=1 -deep
