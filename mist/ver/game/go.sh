#!/bin/bash

function zero_file {
	rm -f $1
	cnt=$2
	while [ $cnt != 0 ]; do
		echo -e "0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0" >> $1
		cnt=$((cnt-16))
	done;
}

DUMP=
CHR_DUMP=NOCHR_DUMP
RAM_INFO=NORAM_INFO
FIRMWARE=gng_test.s
VGACONV=NOVGACONV
LOADROM=
FIRMONLY=NOFIRMONLY
MAXFRAME=
SIM_MS=1
SIMULATOR=iverilog
FASTSIM=
TOP=game_test
MIST=

if ! g++ init_ram.cc -o init_ram; then
	exit 1;
fi
init_ram

while [ $# -gt 0 ]; do
case "$1" in
	"-w" | "-deep")
		DUMP=-DDUMP
		echo Signal dump enabled
		if [ $1 = "-deep" ]; then DUMP="$DUMP -DDEEPDUMP"; fi
		;;
	"-frames")
		shift
		if [ "$1" = "" ]; then
			echo "Must specify number of frames to simulate"
			exit 1
		fi
		MAXFRAME="-DMAXFRAME=$1"
		echo Simulate up to $1 frames
		;;
	"-mist")
		TOP=mist_test
		MIST=../../../modules/jt12/hdl/dac/jt12_dac2.v
		;;
	"-nosnd")
		FASTSIM="$FASTSIM -DNOSUND";;
	"-nocolmix")
		FASTSIM="$FASTSIM -DNOCOLMIX";;
	"-noscr")
		FASTSIM="$FASTSIM -DNOSCR";;
	"-nochar")
		FASTSIM="$FASTSIM -DNOCHAR";;
	"-time")
		shift
		if [ "$1" = "" ]; then
			echo "Must specify number of milliseconds to simulate"
			exit 1
		fi
		SIM_MS="$1"
		echo Simulate $1 ms
		;;
	"-firmonly")
		FIRMONLY=FIRMONLY
		echo Firmware dump only
		;;
	"-t")
		FIRMWARE=gng_test.s
		LOADROM=-DGNGTEST
		echo Running game directly
		;;
	"-ch")
		CHR_DUMP=CHR_DUMP
		echo Character dump enabled
		;;
	"-info")
		RAM_INFO=RAM_INFO
		echo RAM information enabled
		;;
	"-vga")
		VGACONV=VGACONV
		echo VGA conversion enabled
		;;
	"-load")
		LOADROM=-DLOADROM
		echo ROM load through SPI enabled
		if [ ! -e ../../../rom/JTGNG.rom ]; then
			echo "Missing file JTGNG.rom in rom folder"
			echo "Run go-mist.sh in rom folder to generate it."
			exit 1
		fi
		;;
	"-lint")
		SIMULATOR=verilator
		;;
	*) echo "Unknown option $1"; exit 1;;
esac
	shift
done


if ! lwasm $FIRMWARE --output=gng_test.bin --list=gng_test.lst --format=raw; then
	exit 1
fi

if [ $FIRMONLY = FIRMONLY ]; then exit 0; fi

function add_dir {
	for i in $(cat $1/$2); do
		echo $1/$i
	done
}

# HEX files with initial contents for some of the RAMs
function clear_hex_file {
	cnt=0
	rm -f $1.hex
	while [ $cnt -lt $2 ]; do 
		echo 0 >> $1.hex
		cnt=$((cnt+1))
	done	
}

clear_hex_file char_ram 2048
clear_hex_file scr_ram  2048
clear_hex_file obj_buf  128

if [ $SIMULATOR = iverilog ]; then
	iverilog ${TOP}.v \
		$(add_dir ../../../modules/jt12/hdl jt03.f) \
		../../hdl/*.v \
		../common/{mt48lc16m16a2,altera_mf,quick_sdram}.v \
		../../../modules/mc6809/mc6809{,i}.v \
		../../../modules/tv80/*.v $MIST \
		-s $TOP -o sim -DSIM_MS=$SIM_MS -DSIMULATION \
		$DUMP -D$CHR_DUMP -D$RAM_INFO -D$VGACONV $LOADROM $FASTSIM \
		$MAXFRAME $OBJTEST \
	&& sim -lxt
else
	verilator -I../../hdl \
		../../hdl/jtgng_game.v \
		../../../modules/mc6809/mc6809{_cen,i}.v \
		../../../modules/tv80/*.v \
		../common/quick_sdram.v \
		-F ../../../modules/jt12/hdl/jt03.f \
		--top-module jtgng_game -o sim \
		$DUMP -D$CHR_DUMP -D$RAM_INFO -D$VGACONV $LOADROM -DFASTSDRAM \
		-DVERILATOR_LINT \
		$MAXFRAME $OBJTEST -DSIM_MS=$SIM_MS --lint-only
fi

if [ $CHR_DUMP = CHR_DUMP ]; then
	rm frame*png
	for i in frame_*; do
		name=$(basename "$i")
		extension="${name##*.}"
		if [ "$extension" == png ]; then continue; fi
		../../../cc/frame2png "$i"
		mv output.png "$i.png"
		mv "$i" old/"$i"
	done
fi