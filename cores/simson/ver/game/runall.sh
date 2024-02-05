#!/bin/bash

for i in scenes/*; do
    sim.sh -s $(basename $i) --batch
done
if [ -d all ]; then
    rm -rf all.old
    mv all all.old
fi
mkdir all
find scenes -name "*jpg" | xargs -I_ mv _ all