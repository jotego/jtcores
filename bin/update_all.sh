#!/bin/bash
jtupdate -target "mist sidi" -network hosts.mist
cp $JTROOT/log/update.log /tmp/update_mist.log
jtupdate -mister -network hosts.mister
cat /tmp/update_mist.log >> $JTROOT/log/update.log