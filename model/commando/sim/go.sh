#!/bin/bash

SIMTIME=
EXTRA2=-lxt

if [[ -z "$JTUTIL" || -z "$JTFRAME" ]]; then
    echo "JTUTIL and JTFRAME environment variables must be defined"
    exit 1
fi

if [ ! -e $JTUTIL/src/pcb2ver ]; then
    x=$(pwd)
    cd $JTUTIL/src
    if ! make; then
        exit 1
    fi
    cd "$x"
fi

echo "Importing netlist"
if ! $JTUTIL/src/pcb2ver ../commando.net \
    --lib $JTFRAME/hdl/jt74.v \
    --ports pcb.v --wires \
    > pcb_model.v; then
    cat pcb_model.v
    exit 1
fi

# create blank rom files if they don't exist
# for i in 0 1; do
#     for j in 0 1 2 3; do
#         if [ ! -e dma${j}${i}.bin ]; then
#             dd if=/dev/zero of=dma${j}${i}.bin bs=256 count=1
#         fi
#     done
# done

while [ $# -gt 0 ]; do
    case $1 in
        -time) 
            shift
            if [ "$1" = "" ]; then
                echo "Missing time argument afte -time"
                exit 1
            fi
            SIMTIME="-DSIMTIME=$1"
            ;;
        -deep)
            EXTRA="$EXTRA -DDUMPALL";;
        -vcd)
            EXTRA="$EXTRA -DVCD"
            EXTRA2=;;
        *)  echo Unknown argument $1
            exit 1;;
    esac
    shift
done

iverilog test.v pcb.v \
    $JTUTIL/hdl/jt74.v \
    $SIMTIME $EXTRA\
    -o sim -stest -DSIMULATION -DMEM_CHECK_TIME=1000_000 && sim $EXTRA2
