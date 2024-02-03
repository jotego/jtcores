#!/bin/bash
# This file is part of JTFRAME.
# JTFRAME program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# JTFRAME program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

# Author: Jose Tejada Gomez. Twitter: @topapate
# Version: 1.0
# Date: 12-1-2023

# Creates the beta zip files from the contents of $JTROOT/release
# Places a copy of the files in $JTROOT and another one, for
# archiving purposes in $JTFRIDAY

set -e

CORESTAMP=$(date --date=friday +"%Y%m%d")
SHORTSTAMP=$(date --date=friday +"%y%m%d")
DEST=`mktemp --directory`
UPMR=

if [ ! -d "$JTFRIDAY" ]; then
    cat >/dev/stderr <<EOF
Missing JTFRIDAY variable pointing to the destination folder
Define it if you want to archive a copy of the zip files there
EOF
    exit 1
fi

# MiSTer
mkdir -p "$DEST"/_Arcade/cores "$DEST/mra"
mkdir -p $DEST/games/mame
cp $JTUTIL/jtbeta.zip $DEST/games/mame
cp $JTBIN/mister/*rbf "$DEST"/_Arcade/cores

# MiST, SiDi
cp -r $JTBIN/mra/* "$DEST"/_Arcade
cp -r $JTBIN/{mist,sidi,mra} "$DEST"

# Pocket
mkdir -p $DEST/pocket/Assets/jtpatreon/common
cp -r $JTBIN/pocket/raw/* $DEST/pocket
unzip -q $JTUTIL/jtbeta.zip -d $DEST/pocket/Assets/jtpatreon/common
mkdir $DEST/pocket/readme
mv $DEST/pocket/*.txt $DEST/pocket/readme

# Make zip files
cd $DEST
cat >zip_comment <<EOF
      -- JOTEGO --

Beta files for Patreon supporters.
  https://www.patreon.com/jotego

EOF
function betazip {
    cat $DEST/zip_comment | zip -qr --test --archive-comment -9 $*
}

betazip jtfriday_${SHORTSTAMP}_mister.zip _Arcade games &
betazip jtfriday_${SHORTSTAMP}_pocket.zip mra pocket &
betazip jtfriday_${SHORTSTAMP}_other.zip  mra mist sidi &

wait
cp *.zip $JTROOT
if [ -d "$JTFRIDAY" ]; then
    mkdir -p "$JTFRIDAY"/$SHORTSTAMP
    cp *.zip "$JTFRIDAY"/$SHORTSTAMP
fi

cd $JTROOT
rm -rf $DEST
