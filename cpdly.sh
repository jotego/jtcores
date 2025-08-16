#!/bin/bash -e

seed=$1
dst=/nobackup/outrun
cp -r $dst/${seed}/* release/pocket/raw/Cores
jtbin2sd
