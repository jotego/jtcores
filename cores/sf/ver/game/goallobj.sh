#!/bin/bash

for i in objram/*bin; do
    ln -sf $i sf-obj.bin
    goobj.sh
    mv frame_1.jpg $(basename $i .bin).jpg
done