#!/bin/bash

j=1

for i in $(seq 2 2000); do
    if [ ! -e video-$i.jpg ]; then
        break
    fi
    if diff video-$j.jpg video-$i.jpg > /dev/null; then
        # these two are equal
        rm video-$i.jpg
    else
        j=$i
    fi
done