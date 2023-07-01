#!/bin/bash

if [ $# != 1 ]; then
    cat << EOF
Use jtfriday.sh CORENAME
EOF
exit 1
fi

CORE=${1,,}
DATESTAMP=$(date --date=friday +"%Y%m%d")
RLS=$JTROOT/release

TEMP=`mktemp --directory`

cd $TEMP
mkdir -p $TEMP/_Arcade/cores

function zipme {
    zip -r jtfriday_$1_${DATESTAMP}.zip *
    mv jtfriday_$1_${DATESTAMP}.zip $JTFRIDAY
    rm -rf $TEMP/*
}

# MiSTer files
cp $RLS/mister/$CORE/releases/*rbf $TEMP/_Arcade/cores
cp $RLS/mister/$CORE/releases/*mra $TEMP/_Arcade
cp -r $RLS/mra/_alternatives $TEMP/_Arcade
mkdir -p $TEMP/games/mame
cp $JTUTIL/jtbeta.zip $TEMP/games/mame
cp $RLS/mister/$CORE/*.md $TEMP
zipme mister

# Pocket files
mkdir $TEMP/pocket
cp -r $RLS/mra $TEMP
cp -r $RLS/pocket/raw/* $TEMP/pocket
cp $RLS/mister/$CORE/*.md $TEMP
zipme pocket

# MiST/SiDi
cp -r $RLS/{mra,mist,sidi} $TEMP
cp $RLS/mister/$CORE/*.md $TEMP
zipme other