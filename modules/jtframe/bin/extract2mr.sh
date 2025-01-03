#!/bin/bash -e
ZIPFOLDER=/gdrive/jotego/core-builds/
COMMIT=`find $ZIPFOLDER -name ${1}"*" | head -n 1`
if [[ -z "$COMMIT" || ! -e $COMMIT ]]; then
	echo "Cannot find $1 in $ZIPFOLDER"
	exit 1
fi

if [ -z "$MISTERPASSWD" ]; then
    echo "Define the MiSTer password in the environment variable MISTERPASSWD"
    exit 1
fi

unzip -j $COMMIT release/mister/neogeopocket.rbf -d /tmp
sshpass -p $MISTERPASSWD scp /tmp/neogeopocket.rbf root@mister.home:/media/fat/_Console
rm /tmp/neogeopocket.rbf
