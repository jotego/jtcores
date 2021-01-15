#!/bin/bash

NETWORK_MIST=
NETWORK_MISTER=

while [ $# -gt 0 ]; do
    case "$1" in
        -network)
            NETWORK_MIST="-network hosts.mist"
            NETWORK_MISTER="-network hosts.mister";;
        *)
            OTHER="$OTHER $1";
    esac
    shift
done

jtupdate -target "mist sidi" $NETWORK_MIST $OTHER -jobs 5
cp $JTROOT/log/update.log /tmp/update_mist.log
jtupdate -mister $NETWORK_MISTER -jobs 2 $OTHER
cat /tmp/update_mist.log >> $JTROOT/log/update.log
