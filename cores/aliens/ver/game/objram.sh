#!/bin/bash
mame aliens -debug -debuglog -debugscript objram.mame
jtutil log2bin -a 0x7c00 -s 0x400 -o obj.bin
jtutil log2bin -a 0x0000 -s 0x400 -o pal.bin
