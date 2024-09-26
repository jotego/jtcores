#!/bin/bash -e

if [ $# -ne 0 ]; then
	cat <<EOF
Generation of S18 compatible M68000 code from C sources.

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
	unidasm custom.bin -arch m68000
Test it on mame
	mame shdancer -rompath . -debug
Test it on jtsim
	jtutil sdram
	jtsim
EOF
	exit 0
fi

m68k-linux-gnu-gcc -m68000 -static -MMD -MP -O1 -c custom.c
m68k-linux-gnu-ld -o custom custom.o  --script=custom.ld --oformat=binary

if [ ! -d shdancer ]; then
	echo "shdancer folder not found."
	echo "unzip MAME's shdancer in it and try again"
	exit 1
fi

jtutil drop1 -l --pad $((256*1024)) < custom > shdancer/epr-12774b.a6
jtutil drop1    --pad $((256*1024)) < custom > shdancer/epr-12773b.a5
zip -qr shdancer.zip shdancer
jtframe mra s18 --path .
