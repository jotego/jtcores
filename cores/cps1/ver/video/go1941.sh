#!/bin/bash

cd 1941
make || exit $?
anim
cd ..

for i in $(seq 2 133); do
    if [ -e $i.png ]; then
        continue
    fi
    if [ ! -e 1941/vram$i.bin ]; then
        cd 1941
        ln -s vram2.bin vram$i.bin
        cd ..
    fi
    go.sh -g 1941 -s $i
    mv video.png $i.png
done
