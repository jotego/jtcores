#!/bin/bash
VIDEOWIDTH=384
VIDEOHEIGHT=240

mkdir -p video

# convert -size 384x240 -depth 8 RGBA:video.raw -resize 200% video.png
    convert $CONVERT_OPTIONS -size ${VIDEOWIDTH}x${VIDEOHEIGHT} \
        -depth 8 RGBA:video.raw video/video.jpg