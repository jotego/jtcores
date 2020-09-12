#!/bin/bash
VIDEOWIDTH=256
VIDEOHEIGHT=224

mv video video2
rm -rf video2&
mkdir -p video

convert $CONVERT_OPTIONS -size ${VIDEOWIDTH}x${VIDEOHEIGHT} \
    -depth 8 RGBA:video.raw video/video.jpg
cd video
rmdup.sh