#!/bin/bash
# bonus stage with people holding wooden items
# it is good to check the obj-scr alignment

ln -sf objram/sf-obj17.bin sf-obj.bin

go.sh -d NOMAIN -d NOCHAR -d NOSOUND -d GRAY -d OBJLOAD \
    -d SIM_SCR1POS=\'h1800 \
    -d SIM_SCR2POS=\'h1380 \
    -d NOMCU -video 2 -w $*