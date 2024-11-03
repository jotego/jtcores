#!/bin/bash -e
# Create the binary files with MAME'script dump.mame
# then run mame2dump.sh to generate a dump.bin file
SCENE=1
if [ ! -z "$1" ]; then
	SCENE="$1"
fi
jtutil fold fix-raw.bin fix.bin  --bit 10
# jtutil fold scr-raw.bin vram.bin --bit 7
mkdir -p scenes/$SCENE
cat pal.bin fix.bin vram.bin objram.bin > scenes/$SCENE/dump.bin
echo "Created scene $SCENE"
# copy most recent snap shot
setname=$(basename $(pwd))
SNAPS=~/.mame/snap/$setname
cp $SNAPS/"$(ls -t $SNAPS | head -n 1)" scenes/$SCENE/ref.png

