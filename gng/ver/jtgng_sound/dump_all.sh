#!/bin/bash

if [ "$1" = -start ]; then
    code=$2
else
    code=1
fi

(while [ $code -lt 64 ];do
    printf "%x\n" $code
    code=$((code+1))
done) | parallel --eta go.sh -q -runonly -snd -time 30000 -slow -code
