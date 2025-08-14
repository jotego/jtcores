#!/bin/bash -e

dly=$1
cp -r /nobackup/outrun/phase48/${dly}/Cores release/pocket/raw/
jtbin2sd
