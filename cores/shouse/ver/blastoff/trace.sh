#!/bin/bash
rm ~/.mame/nvram/blastoff/nvram
mame blastoff -debug -debugscript trace.mame -sound none
