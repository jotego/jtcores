#!/bin/bash
export JTROOT=$(pwd)
export JTFRAME=$JTROOT/modules/jtframe
export PATH=$PATH:.
#unalias jtcore
alias jtcore="$JTFRAME/bin/jtcore"