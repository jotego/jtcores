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
FIRMONLY=NOFIRMONLY
NOFIRM=NOFIRM
MAXFRAME=
OBJTEST=
SIM_MS=1
SIMULATOR=iverilog
#FASTSIM="-DNOCHAR -DNOCOLMIX -DNOSCR -DNOSOUND"
#FASTSIM="-DNOSOUND"
FASTSIM=

while [ $# -gt 0 ]; do
	if [ "$1" = "-w" ]; then
		DUMP=DUMP
		echo Signal dump enabled
		shift
		continue
	fi
	if [ "$1" = "-obj" ]; then
		shift
		echo "Object test: will used special firmware on ROM space"
		OBJTEST="-DOBJTEST"	
		FIRMWARE="obj_test.s"	
		continue
	fi
	if [ "$1" = "-frames" ]; then
		shift
		if [ "$1" = "" ]; then
			echo "Must specify number of frames to simulate"
			exit 1
		fi
		MAXFRAME="-DMAXFRAME=$1"
		echo Simulate up to $1 frames
		shift
		continue
	fi
	if [ "$1" = "-time" ]; then
		shift
		if [ "$1" = "" ]; then
			echo "Must specify number of milliseconds to simulate"
			exit 1
		fi
		SIM_MS="$1"
		echo Simulate $1 ms
		shift
		continue
	fi	
	if [ "$1" = "-firmonly" ]; then
		FIRMONLY=FIRMONLY
		NOFIRM=FIRM
		echo Firmware dump only
		shift
		continue
	fi
	if [ "$1" = "-firm" ]; then
		NOFIRM=FIRM
		echo Will copy firmware to Quartus folder
		shift
		continue
	fi	
	if [ "$1" = "-g" ]; then
		FIRMWARE=rungame.s
		if [ ! -e ../../../rom/gng.hex ]; then
			echo "Cannot find ROM file: ../../../rom/gng.hex"
			exit 1
		fi
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
			echo "Missing file JTGNG.rom, looking into rom folder"
			if ! cp ../../../rom/JTGNG.rom . -v; then
				echo "Cannot find file JTGNG.rom in . or in ../../../rom"
				echo "Run go-mist.sh in rom folder to generate it."
				exit 1
			fi
		fi
		shift
		continue
	fi
	if [ $1 = "-lint" ]; then
		SIMULATOR=verilator
		shift
		continue
	fi
	echo "Unknown option $1"
	exit 1
done

#Prepare firmware
if [[ "$OBJTEST" = "-DOBJTEST" && "$NOFIRM" != "NOFIRM" ]]; then
	echo "Cannot specify -obj and -firm together"
	exit 1
fi

if ! lwasm $FIRMWARE --output=gng_test.bin --list=gng_test.lst --format=raw; then
	exit 1
fi

if [ "$OBJTEST" = "-DOBJTEST" ]; then
	ODx2="od -t x2 -A none -v -w2"
	$ODx2 --endian little gng_test.bin > ram.hex	
	echo "@1C000" >> ram.hex
	if [ ! -e ../../../rom/obj.hex ]; then
		echo "Missing the object hex dump"
		echo "use go-mist.sh to generate it at the ROM folder"
		exit 1
	fi
	cat ../../../rom/obj.hex >> ram.hex
else
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

fi

if [ $NOFIRM != NOFIRM ]; then
	echo Quartus firmware file overwritten
	cp jtgng_firmware.mif ../../quartus 
fi

if [ $FIRMONLY = FIRMONLY ]; then exit 0; fi



zero_file 10n.hex 16384
zero_file 13n.hex $((2*16384))

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
	iverilog game_test.v \
		$(add_dir ../../../modules/jt12/hdl jt03.f) \
		../../hdl/*.v \
		../common/{mt48lc16m16a2,altera_mf,quick_sdram}.v \
		../../../modules/mc6809/mc6809{_cen,i}.v \
		../../../modules/tv80/*.v \
		-s game_test -o sim -DSIM_MS=$SIM_MS -DSIMULATION \
		-D$DUMP -D$CHR_DUMP -D$RAM_INFO -D$VGACONV -D$LOADROM $FASTSIM \
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
		-D$DUMP -D$CHR_DUMP -D$RAM_INFO -D$VGACONV -D$LOADROM -DFASTSDRAM \
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