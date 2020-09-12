#!/bin/bash
VIDEOWIDTH=256
VIDEOHEIGHT=240

mv video video2
rm -rf video2&
mkdir -p video

# convert -size 384x240 -depth 8 RGBA:video.raw -resize 200% video.png
    convert $CONVERT_OPTIONS -size ${VIDEOWIDTH}x${VIDEOHEIGHT} \
        -depth 8 RGBA:video.raw video/video.jpg