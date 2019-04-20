#!/bin/bash
# Show the pause screen

function check_hex_file {
    if [ ! -e $1 ]; then
        if [ ! -e ../../mist/$1 ]; then
            echo Missing HEX files for PAUSE screen. Attempting to generate them:
            pushd
            cd ../../../bin
            python avatar.py
            popd
        fi
        echo INFO: Created symbolic link to $1
        ln -s ../../mist/$1
    fi
}

check_hex_file avatar.hex
check_hex_file avatar_xy.hex

go.sh $* -frame 2 -video -deep -mist -d DIP_TEST -nosnd -d NOMAIN -d ALWAYS_PAUSE
