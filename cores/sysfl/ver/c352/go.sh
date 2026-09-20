#!/bin/bash
# jt352 verification: golden model generation + iverilog compare in docker
set -e
cd "$(dirname "$0")"
python3 golden.py
docker run --rm -v /Users/andreabogazzi/develop/jtpublicfork:/jt \
    -w /jt/cores/sysfl/ver/c352 --entrypoint bash jotego/simulator:arm64 -c '
set -e
iverilog -g2012 -o test.out test_jt352.v ../../hdl/c352/jt352.v
for c in linear muloop reverse pingpong noise; do
    n=$(cat cases/$c/n.txt)
    echo "=== case $c ==="
    ( cd cases/$c && vvp ../../test.out +n=$n )
done'
