#!/bin/bash

for i in $ROM/*.rom; do
    BN=$(basename $i)
    if [ -e $BN ]; then
        diff $i $BN
    fi
done
