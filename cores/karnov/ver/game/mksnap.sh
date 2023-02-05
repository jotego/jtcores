#!/bin/bash
cat<<EOF
Call mksnap.mame on the scene you want to save.
Then quit MAME and run cpsnap.sh <scene>
EOF

GAME=$1

if [ -z "$GAME" ]; then GAME=karnov; fi

$MAMESRC/mame64 $GAME -debug -debugscript wp.mame
