#!/bin/bash
rm ~/.mame/nvram/blastoff/nvram
~/mame/mame blastoff -debug -debugscript tr_mcu.mame -sound none
