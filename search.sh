#!/bin/bash -e

pllfiles=$MODULES/jtframe/target/sidi128/hdl/pllgame
cd $JTROOT

# Fvco = m/n*fin = 48 -> 1/8/48 = 2.604ns
# 260 520 780 970 1300 1510 1730 1950 2270 2600 2820 3030 3250 3470 3680 3900 4230 4550 4770 4990 5200

for dly in 1300 1510 1730 1950 \
		2270 2600 2820 3030 3250 3470 3680 3900 \
		4230 4550 4770 4990 5200; do
	echo "=== Delay ${dly} ps ==="
	git restore -- $pllfiles/*
	sed -i s/2600/${dly}/g $pllfiles/*
	jtcore outrun -pocket --nosta -u JTFRAME_SKIP || continue
	dst=$JTROOT/phase/${dly}
	mkdir -p $dst
	cp -r $RLS/pocket/raw/Cores $dst
	echo -e "\n\n"
done
