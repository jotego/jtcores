#!/bin/bash

OTHER=
SCENE=1

while [ $# -gt 0 ]; do
    case $1 in
        -s)
            shift
            if [ ! -d scene${1} ]; then
                echo "Cannot find scene #" $1
                exit 1
            fi
            SCENE=$1
            ;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

rm -f scene
ln -s scene${SCENE} scene
go.sh -d GFX_ONLY -d NOSOUND -video 2 -deep $OTHER || exit $?
mv video-0.jpg $SCENE.jpg
rm video-1.jpg
