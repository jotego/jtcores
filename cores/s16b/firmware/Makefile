s16mcu_alt.zip: 317-0104.c2 317-0098.c2 README
	cpfiles

317-0104.c2: tturf.s
	echo "Tough Turf custom firmware"
	as31 -l -Fbin -O317-0104.c2 tturf.s

317-0098.c2: wb3.s
	echo "Wonder Boy III custom firmware"
	as31 -l -Fbin -O317-0098.c2 wb3.s

mcu.bin: s16atest.s
	echo "MCU test firmware for System 16A"
	as31 -l -Fbin -Omcu.bin s16atest.s

clean:
	rm -f s16mcu_alt 317-0104.c2 317-0098.c2
