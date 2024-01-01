#!/bin/bash
rm -rf ~/.mame/nvram/ngp*
# expects modified version of the bios in ./roms folder. See README.md
mame ngp -debug -debugscript trace.mame -rompath roms -sound none

sed s/XWA1=0,XBC1=0,XDE1=0,XHL1=0,XWA2=0,XBC2=0,XDE2=0,XHL2=0,// debug.trace > view.trace