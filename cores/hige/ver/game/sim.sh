#!/bin/bash

# if [ -e char.bin ]; then
#     dd if=char.bin of=char_lo.bin count=2
#     dd if=char.bin of=char_hi.bin count=2 skip=2
# fi

# Generic simulation script from JTFRAME
jtsim $*
