#!/bin/bash -e

function show_help {
	cat <<EOF
Generation of S18 compatible M68000 code from C sources.

-m, --mame		test the code on MAME
-d, --debug		test on MAME debugger
-s, --sim		test the code on jtsim
-h, --help		this help message

Steps:

- Compile and link correctly custom.c so it will operate on S18 hardware
  Note the -O1 flag, see custom.c for details
- Split the binary code in two files with the right size for their use
  as ROM data on S18 hardware
- Create a new zip file compatible with mame and jtframe
- Run "jtframe mra s18 --path ." to prepare the jtsim compatible rom file.
  You can ignore the warnings about not finding zip files other than the
  target one.

View the output contents with
	unidasm custom -arch m68000
Test it on mame
	mame shdancer -rompath . -debug
Test it on jtsim
	jtutil sdram
	jtsim
EOF
}

SIM=
MAME=
DEBUG=-window

while [ $# -gt 0 ]; do
	case "$1" in
		-m|--mame) MAME=1;;
		-d|--debug) MAME=1; DEBUG="-debug";;
		-s|--sim) SIM=1;;
		-h|--help)
			show_help
			exit 0;;
	esac
	shift
done


m68k-linux-gnu-gcc -m68000 -static -MMD -MP -O1 -nostdlib -ffreestanding -S -c custom.c
m68k-linux-gnu-ld -o custom custom.o  --script=custom.ld --oformat=binary

if [ ! -d shdancer ]; then
	echo "shdancer folder not found."
	echo "unzip MAME's shdancer in it and try again"
	exit 1
fi

jtutil drop1 -l --pad $((256*1024)) < custom > shdancer/epr-12774b.a6
jtutil drop1    --pad $((256*1024)) < custom > shdancer/epr-12773b.a5
zip -qr shdancer.zip shdancer

if [ ! -z "$SIM" ]; then
	jtframe mra s18 --path .
	cd $CORES/s18/ver/shdancer
	jtutil sdram
	jtsim -video 80 -w -q -d NOMCU -d NOVDP
fi

if [ ! -z "$MAME" ]; then
	mame shdancer -rompath . $DEBUG -skip_gameinfo
fi
