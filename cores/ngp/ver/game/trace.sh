#!/bin/bash
rm -rf ~/.mame/nvram/ngp*
# uses modified version of the bios. See hack.md
mame ngp -debug -debugscript trace.mame -rompath roms -sound none

