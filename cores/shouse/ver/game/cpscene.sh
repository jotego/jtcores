#!/bin/bash
# Copies a save file from MiSTer to a scene folder

DST=scenes/$1
if [ -d $DST ]; then
	mv $DST/dump.bin $DST/old
else
	mkdir $DST
fi

scp mister.home:/media/fat/config/nvram/Splatter*.nvm $DST/dump.bin
