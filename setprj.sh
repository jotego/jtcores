#!/bin/bash

if (echo $PATH | grep modules/jtframe/bin -q); then
    echo ERROR: path variable already points to a modules/jtframe/bin folder
    echo source setprj.sh with a clean PATH
else
    export JTROOT=$(pwd)
    export JTFRAME=$JTROOT/modules/jtframe

    PATH=$PATH:$JTFRAME/bin:.
    #unalias jtcore
    alias jtcore="$JTFRAME/bin/jtcore"

    # derived variables
    CORES=$JTROOT/cores
    ROM=$JTROOT/rom
    MRA=$ROM/mra
    MODULES=$JTROOT/modules
    JT12=$MODULES/jt12
    JT51=$MODULES/jt51
fi

function swcore {
    IFS=/ read -ra string <<< $(pwd)
    j="/"
    next=0
    good=
    for i in ${string[@]};do
        if [ $next = 0 ]; then
            j=${j}${i}/            
        else
            next=0
            j=${j}$1/
        fi
        if [ "$i" = cores ]; then
            next=1
            good=1
        fi
    done
    if [[ $good && -d $j ]]; then
        cd $j
    else       
        cd $JTROOT/cores/$1
    fi
    pwd
}

echo "Use swcore <corename> to switch to a different core once you are"
echo "inside the cores folder"