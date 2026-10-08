#!/bin/bash
# creates the MCU dump
dd if=rom.bin of=mcu.bin ibs=256 obs=256 iseek=$((0xc80)) count=8
jtsim "$@"
