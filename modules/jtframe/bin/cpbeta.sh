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

CORE=$1
CORESTAMP=$(date --date=friday +"%Y%m%d")
SHORTSTAMP=$(date --date=friday +"%y%m%d")
DEST=`mktemp --directory`
UPMR=

if [ -z "$CORE" ]; then
    echo "Missing core name"
    exit 1
fi

if [ ! -d "$JTFRIDAY" ]; then
    cat >/dev/stderr <<EOF
Missing JTFRIDAY variable pointing to the destination folder
Define it if you want to archive a copy of the zip files there
EOF
    exit 1
fi

mkdir -p "$DEST"/_Arcade/cores "$DEST/mra"

# MiSTer
if [ -e $JTROOT/release/mister/$CORE/releases/*.rbf ]; then
    cp $JTROOT/release/mister/$CORE/releases/*.rbf "$DEST"/_Arcade/cores
    cp -r $JTROOT/release/mra/* "$DEST"/_Arcade
    UPMR=1
fi
cp -r $JTROOT/release/mra "$DEST"

# MiST, SiDi

function cp_file {
    if [ -d $JTROOT/release/$1 ]; then
        cp -r $JTROOT/release/$1 $DEST
    else
        echo "Skipping $1"
    fi
}

# cp_file mcp
# cp_file mc2
# cp_file neptuno
# cp_file sockit
# cp_file de1soc
# cp_file de10standard
cp $JTROOT/README.md $DEST
if [ -s $JTROOT/cores/$CORE/README.md ]; then
    cp $JTROOT/cores/$CORE/README.md $DEST/$CORE.md
fi

mkdir -p $DEST/games/mame
cp $JTUTIL/jtbeta.zip $DEST/games/mame
cp_file mist
cp_file sidi

# Pocket
mkdir -p $DEST/pocket
cp -r $JTROOT/release/pocket/raw/* $DEST/pocket

# Make zip files
cd $DEST
cat >zip_comment <<EOF
      -- JOTEGO --

Beta files for Patreon supporters.
  https://www.patreon.com/jotego

EOF
function betazip {
    cat zip_comment | zip -qr --test --archive-comment -9 $*
}
if [ -z "$UPMR" ]; then
    echo "Skipping MiSTer"
else
    betazip jtfriday_${SHORTSTAMP}_mister.zip _Arcade games *.md
fi
if [[ -d mist || -d sidi ]]; then
    betazip jtfriday_${SHORTSTAMP}_other.zip  mra *.md mist sidi
fi
betazip jtfriday_${SHORTSTAMP}_pocket.zip mra *.md pocket

cp *.zip $JTROOT
if [ -d "$JTFRIDAY" ]; then
    mkdir -p "$JTFRIDAY"/$SHORTSTAMP
    cp *.zip "$JTFRIDAY"/$SHORTSTAMP
fi

cd $JTROOT
rm -rf $DEST

# Copies to SD and MiSTer
cd $JTROOT
jtbin2sd &
jtbin2mr
wait
