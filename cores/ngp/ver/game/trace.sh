#!/bin/bash
rm -rf ~/.mame/nvram/ngp*
mame ngp -debug -debugscript trace.mame

