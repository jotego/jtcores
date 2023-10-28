#!/bin/bash
rm ~/.mame/nvram/splatter/nvram
~/mame/mame splatter -debug -debugscript tr_mcu.mame -sound none
