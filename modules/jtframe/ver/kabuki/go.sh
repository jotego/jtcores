#!/bin/bash

if [ ! -e tk2_qa.5k ]; then
    echo "Missing file tk2_qa.5k from wof MAME rom set"
    exit 1
fi

cp tk2_qa.5k coded.bin
cat >keys.hex << EOF
01234567
54163072
5151
51
EOF

iverilog test.v ../../hdl/cpu/jtframe_kabuki.v -o sim && sim -lxt