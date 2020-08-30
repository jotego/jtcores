#!/bin/bash
mkdir -p video2
convert -size 384x224 -depth 8 RGBA:video.raw video2/video.jpg
rm -rf video
mv video2 video
