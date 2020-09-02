#!/bin/bash

for i in objram/*bin; do
    goobj.sh $i
    mv video-0.jpg $(basename $i .bin).jpg
done