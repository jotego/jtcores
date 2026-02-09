#!/bin/bash -e

verilator prot.v --cc prot.cpp --exe
make --quiet -C obj_dir -f Vprot.mk || echo "make error"
obj_dir/Vprot
