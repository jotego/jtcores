#!/bin/bash

dd if=rom.bin of=audio_lo.bin skip=320 count=32
dd if=rom.bin of=audio_hi.bin skip=352 count=32

jtsim $*
