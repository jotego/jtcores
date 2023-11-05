#!/bin/bash
set -e

git clone --depth 1 --shallow-submodules  --recurse-submodules git@github.com:jotego/jtcores.git
cd jtcores
COMMIT=$1
git checkout $COMMIT
shift

. setprj.sh
jtframe
cd $JTROOT

jtcore $*
mkdir -p /release/$COMMIT
rsync release /release/$COMMIT
