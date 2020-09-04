#!/bin/bash

for i in objram/*bin; do
    ln -sf $i sf-obj.bin
    goobj.sh
    mv video-0.jpg $(basename $i .bin).jpg
done