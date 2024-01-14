#!/bin/bash
set -e
asl -L -cpu 6809 triram.s
p2bin triram.p triram.bin

asl -L -cpu 6801 triram-mcu.s
p2bin triram-mcu.p triram-mcu.bin