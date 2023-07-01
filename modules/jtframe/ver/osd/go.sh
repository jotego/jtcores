#!/bin/bash

EXTRA=""

while [ $# -gt 0 ]; do
case "$1" in
	-w) EXTRA="$EXTRA -DDUMP";;
	-r) EXTRA="$EXTRA -DROTATE"
		echo "OSD rotation enabled";;
	-f) EXTRA="$EXTRA -DFLIP"
		echo "OSD rotation with flip enabled";;
	-h) 
		echo -e "\t-w to dump signals"
		echo -e "\t-r to rotate the OSD"
		echo -e "\t-f to rotate the OSD (flipped)"
		exit 0;;
esac
shift
done

iverilog -DSIMULATION $EXTRA test.v ../../hdl/mister/sys/osd.sv -g2005-sv -o sim && sim -lxt

echo "Converting the video output to video.png"
octave << 'EOF'
load video_dump.m
imwrite(video_dump,"video.png")
exit
EOF

