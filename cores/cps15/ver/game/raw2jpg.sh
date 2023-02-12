#!/bin/bash
#dd if=video.raw of=video1.raw bs=$((384*224*4)) count=1000

RAW=video.raw
DELETE=

if [ $# = 1 ]; then
    RAW=video_skip.raw
    DELETE="rm $RAW"
    dd if=video.raw of=$RAW bs=$((384*224*4)) skip=$1
fi

rm -rf video
mkdir video
convert -size 384x224 -depth 8 RGBA:$RAW -resize 200% video/video.jpg
$DELETE
cd video
rmdup.sh