#!/bin/bash

# This file is part of JT_FRAME.
# JTFRAME program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# JTFRAME program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: Jose Tejada Gomez. Twitter: @topapate
# Date: 3-1-2023

# Finds the right MRA file and extracts the rom file for it

if [ $# -lt 2 ]; then
    cat <<EOF
get.sh <core name> <MAME setname> [options to jtframe mra]

Extracts the .rom file and places it in the $ROM folder.

1. Regenerates the MRA files by running jtframe mra
2. Searches through them looking for the right one to parse
3. Runs the mra or orca tool to get the .rom file
4. Creates a file in rom/setname.dip with the default DIP
   switches, from MSB to LSB
EOF
    exit 1
fi

if [ -z "$JTROOT" ]; then
    echo "JTROOT is not defined. Call setprj.sh before getset.sh"
    exit 1
fi

CORENAME=$1
SETNAME=$2
shift
shift
# The rest of the arguments are passed to jtframe

function require {
    if [ ! -e "$1" ]; then
        echo "getset.sh: cannot find $1"
        exit 1
    fi

}

require "$CORES/$CORENAME/cfg/mame2mra.toml"
require "$JTROOT/doc/mame.xml"

if [ ! -d ~/.mame/roms ]; then
    echo "Cannot find folder ~/.mame/roms"
    exit 1
fi

AUX=`mktemp`
if ! jtframe mra $CORENAME $* > $AUX; then
    cat $AUX
    rm $AUX
    exit 1
fi
rm $AUX

MATCHES=`mktemp`

find $JTROOT/release/mra -name "*.mra" -print0 | xargs -0 grep --files-with-matches ">$SETNAME<" > $MATCHES
case `wc -l $MATCHES | cut -f 1 -d ' '` in
    0)
        echo "Cannot find the required ROM set: $SETNAME in $MRA."
        echo "Check the set name spelling."
        exit 1;;
    1) basename "$(cat $MATCHES)";;
    *)
        echo "getset.sh: More than one MRA file contained $SETNAME"
        cat $MATCHES
        rm $MATCHES
        exit 1;;
esac

# Get the DIP switch configuration
cd $ROM
DIPSW=$(xmlstarlet sel -t -m misterromdescription -m switches -v @default "$(cat $MATCHES)")
DIPSW=$(echo $DIPSW | tr , '\n' | tac | tr -t '\n' ' ')
printf "%s%s%s%s" $DIPSW > $SETNAME.dip

rm -f $MATCHES

