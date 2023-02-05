#!/bin/bash

for i in scene*; do
    s=${i#scene}
    govideo.sh -s $s
    mv video-0.jpg $s.jpg
done