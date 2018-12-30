#!/bin/bash

EXTRA=
GATHER=gather_dummy.f
DEPTH="--trace-depth 1"
EXTRA_VERI=
VCD2FST=FALSE
SKIPMAKE=FALSE
QUIET=FALSE

function quiet_echo() {
    if [ $QUIET = FALSE ]; then
        echo "$*"
    fi
}

while [ $# -gt 0 ]; do
    if [ "$1" = "-w" ]; then
        EXTRA="$EXTRA -trace"
        VCD2FST=TRUE
        quiet_echo Signal dump enabled
        shift
        continue
    fi
    if [ "$1" = "-q" ]; then
        EXTRA="$EXTRA -quiet"
        QUIET=TRUE
        shift
        continue
    fi    
    if [ "$1" = "-time" ]; then
        shift
        if [ "$1" = "" ]; then
            echo "Must specify number of milliseconds to simulate"
            exit 1
        fi
        EXTRA="$EXTRA -time $1"
        quiet_echo Simulate $1 ms
        shift
        continue
    fi  
    if [ "$1" = "-runonly" ]; then
        quiet_echo Skipping Verilator and make steps
        SKIPMAKE=TRUE
        shift
        continue
    fi    
    if [ "$1" = "-snd" ]; then
        quiet_echo Simulate with full jt03
        GATHER=gather.f
        shift
        continue
    fi
    if [ "$1" = "-code" ]; then
        EXTRA="$EXTRA $1 $2"
        shift
        shift
        continue
    fi    
    if [ "$1" = "-cen" ]; then
        EXTRA="$EXTRA $1 $2"
        shift
        shift
        continue
    fi      
    if [ "$1" = "-psg_mmr" ]; then
        quiet_echo PSG Register Dump Enabled
        EXTRA_VERI="$EXTRA_VERI -DDUMMY_PRINTALL"
        shift
        continue
    fi  
    if [ "$1" = "-deep" ]; then
        quiet_echo Deep trace.
        DEPTH=
        EXTRA="$EXTRA -trace"       
        VCD2FST=TRUE
        shift
        continue
    fi
    if [ "$1" = "-threads" ]; then
        DEPTH=
        EXTRA_VERI="$EXTRA_VERI --threads 1"
        shift
        continue
    fi  
    if [ "$1" = -lint ]; then
        verilator -f gather.f --lint-only --top-module jtgng_sound --error-limit 500
        exit $?
    fi  
    echo "go.sh: Unknown option $1"
    exit 1
done

if [ $SKIPMAKE = FALSE ]; then
    if ! verilator --cc -f $GATHER --top-module jtgng_sound --trace --exe test.cpp \
        -DNOLFO -DNOTIMER $DEPTH $EXTRA_VERI; then
        exit $?
    fi

    if ! make -j -C obj_dir -f Vjtgng_sound.mk Vjtgng_sound; then
        exit $?
    fi
fi

if [ $VCD2FST = TRUE ]; then
    obj_dir/Vjtgng_sound $EXTRA | vcd2fst -v - -f test.fst
else
    obj_dir/Vjtgng_sound $EXTRA
fi