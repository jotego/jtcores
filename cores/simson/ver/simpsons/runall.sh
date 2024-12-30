#!/bin/bash

BAD=

for i in scenes/*; do
    if ! sim.sh -s $(basename $i) --batch $*; then
        BAD="$(basename $i) $BAD"
    fi
done
if [ -d all ]; then
    rm -rf all.old
    mv all all.old
fi
mkdir all
find scenes -name "*jpg" | xargs -I_ mv _ all
(find scenes -name "*crc" | xargs cat)>all/crc
if [ ! -z "$BAD" ]; then
    echo "Bad scenes: $BAD"
fi