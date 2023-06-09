#!/bin/bash
#mame scontra -debug -debugscript trace.mame -playback ./scontra
TRACE=`pwd`/trace.mame
rm -rf ~/.mame/snap/scontra
cd $MAMESRC
./mamearcade scontra -debug -debugscript $TRACE -sound none -rompath roms