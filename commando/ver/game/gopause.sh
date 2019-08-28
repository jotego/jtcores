#!/bin/bash
# Show the pause screen

../../../bin/jtcommando_msg.py

function check_hex_file {
    if [ ! -e $1 ]; then
        if [ ! -e ../../mist/$1 ]; then
            echo Missing HEX files for PAUSE screen. Attempting to generate them:
            olddir=$(pwd)
            cd ../../../bin
            python avatar.py
            cd $olddir
        fi
        echo INFO: Created symbolic link to $1
        ln -s ../../mist/$1
    fi
}

# check_hex_file avatar.hex
# check_hex_file avatar_xy.hex
# check_hex_file avatar_pal.hex
# check_hex_file avatar_obj.hex

# use -d AVATARS to add AVATAS to simulation:
if ! go.sh -frame 1 $*  -video -d DIP_TEST -nosnd \
    -d NOMAIN -d NOSOUND -d ALWAYS_PAUSE -d SCANDOUBLER_DISABLE; then
    exit 1
fi