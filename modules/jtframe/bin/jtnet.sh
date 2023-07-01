#!/bin/bash
source setprj.sh > /dev/null
export JTBIN=$1
shift
$*
