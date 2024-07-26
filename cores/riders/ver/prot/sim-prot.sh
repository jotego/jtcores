#!/bin/bash -e

verilator prot.v --cc prot.cpp --exe
make -C obj_dir -f Vprot.mk > /dev/null || echo "make error"
obj_dir/Vprot