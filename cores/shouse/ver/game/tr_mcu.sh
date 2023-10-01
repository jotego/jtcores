#!/bin/bash
rm ~/.mame/nvram/splatter/nvram
mame splatter -debug -debugscript tr_mcu.mame -sound none
