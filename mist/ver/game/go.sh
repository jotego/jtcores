#!/bin/bash

function zero_file {
	rm -f $1
	cnt=$2
	while [ $cnt != 0 ]; do
		echo -e "0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0" >> $1
		cnt=$((cnt-16))
	done;
}

DUMP=NODUMP
CHR_DUMP=NOCHR_DUMP
RAM_INFO=NORAM_INFO
FIRMWARE=gng_test.s
VGACONV=NOVGACONV
LOADROM=NOLOADROM

while [ $# -gt 0 ]; do
	if [ "$1" = "-w" ]; then
		DUMP=DUMP
		echo Signal dump enabled
		shift
		continue
	fi
	if [ "$1" = "-g" ]; then
		FIRMWARE=rungame.s
		echo Running game directly
		shift
		continue
	fi
	if [ "$1" = "-ch" ]; then
		CHR_DUMP=CHR_DUMP
		echo Character dump enabled
		shift
		continue
	fi
	if [ "$1" = "-info" ]; then
		RAM_INFO=RAM_INFO
		echo RAM information enabled
		shift
		continue
	fi
	if [ "$1" = "-vga" ]; then
		VGACONV=VGACONV
		echo VGA conversion enabled
		shift
		continue
	fi
	if [ "$1" = "-load" ]; then
		LOADROM=LOADROM
		echo ROM load through SPI enabled
		if [ ! -e JTGNG.rom ]; then
			echo Missing file JTGNG.rom
			exit 1
		fi
		shift
		continue
	fi
	echo "Unknown option $1"
	exit 1
done

#Prepare firmware

if ! lwasm $FIRMWARE --output=gng_test.bin --list=gng_test.lst --format=raw; then
	exit 1
fi

echo -e "DEPTH = 8192;\nWIDTH = 8;\nADDRESS_RADIX = HEX;DATA_RADIX = HEX;" > jtgng_firmware.mif
echo -e "CONTENT\nBEGIN" >> jtgng_firmware.mif


OD="od -t x1 -A none -v -w1"

$OD gng_test.bin > ram.hex

python <<XXX
import string

infile=open("ram.hex","r")
file=open("jtgng_firmware.mif","a")
#file.write("[0000..1FFF]:")
addr=0;
for line in infile:
	line=string.replace(line,'\n','')
	file.write( '{0:X} : {1};\n'.format(addr,line) )
	addr=addr+1
file.write("END;")
XXX
cp jtgng_firmware.mif ../../quartus 

#exit 0

zero_file 10n.hex 16384
zero_file 13n.hex $((2*16384))

iverilog game_test.v \
	../../hdl/*.v \
	../common/{mt48lc16m16a2.v,altera_mf.v} \
	../../../modules/mc6809/{mc6809.v,mc6809i.v} \
	-s game_test -o sim \
	-D$DUMP -D$CHR_DUMP -D$RAM_INFO -DSIMULATION -D$VGACONV -D$LOADROM \
&& sim -lxt