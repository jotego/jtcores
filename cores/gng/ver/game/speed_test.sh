#!/bin/bash
FIRMWARE=speed_test.s

if ! lwasm $FIRMWARE --output=speed_test.bin --list=speed_test.lst --format=raw; then
	exit 1
fi

cp -f speed_test.bin gng/gg3.bin
mame gng -rompath . -window