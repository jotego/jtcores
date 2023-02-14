#!/bin/bash
mkdir -p video
convert -size 256x224 -depth 8 RGBA:video.raw video/video.jpg
