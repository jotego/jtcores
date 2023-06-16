#!/bin/bash
rm -rf ~/.mame/nvram/ngp*
mame ngp -debug -debugscript debug.mame -rompath roms

