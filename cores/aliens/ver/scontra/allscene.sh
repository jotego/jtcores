#!/bin/bash

for i in *.RAM; do
    scene.sh -s $i
    mv frame_0001.jpg $(basename $i .RAM).jpg
done
