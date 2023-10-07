#!/bin/bash
rm ~/.mame/nvram/splatter/nvram
mame splatter -debug -debugscript trace.mame -sound none
