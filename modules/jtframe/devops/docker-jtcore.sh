#!/bin/bash
set -e

git clone --shallow-submodules  --recurse-submodules git/jtcores.git
cd jtcores
COMMIT=$1
git checkout $COMMIT
shift

. modules/jtframe/bin/setprj.sh
jtframe
cd $JTROOT

jtcore $*
mkdir -p /release/$COMMIT
rsync release /release/$COMMIT
