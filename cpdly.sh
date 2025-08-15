#!/bin/bash -e

seed=$1
dly=$2
cp -r /nobackup/outrun/phase48-${seed}/${dly}/* release/pocket/raw/Cores
jtbin2sd
