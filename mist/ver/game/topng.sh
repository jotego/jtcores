#!/bin/bash

for i in frame_*; do
	name=$(basename "$i")
	extension="${name##*.}"
	if [ "$extension" == png ]; then continue; fi
	../../../cc/frame2png "$i"
	mv output.png "$i.png"
	mv "$i" old/"$i"
done