#!/bin/bash

for i in objram/*bin; do
    fn=$(basename $i .bin)
    fn=${fn:6}
    goobj.sh $fn -verilator
    mv frame_1.jpg $(basename $i .bin).jpg
done