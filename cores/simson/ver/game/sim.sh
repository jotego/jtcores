#!/bin/bash

if [ ! -e nvram.bin ]; then
    cat <<EOF
This system requires a valid nvram.bin file to boot up properly
Use MAME's simpsons.12c.nv file for the "simpsons" set
EOF
    exit 0
fi

jtsim $*
