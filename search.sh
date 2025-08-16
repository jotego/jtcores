#!/bin/bash

seed=$RANDOM
dst=/nobackup/outrun
cd $JTROOT

compile() {
	find $RLS -name "*rbf_r" -delete
	jtcore outrun -pocket -u JTFRAME_SKIP --seed $seed || return 1
	mkdir -p $dst
	cp -r $RLS/pocket/raw/Cores $dst/"$seed"
	echo -e "\n\n"
}

dly=0
for i in $(seq 1 10); do
	seed=$RANDOM
	compile
done
