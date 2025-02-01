#!/bin/bash -e

main() {
	parse_args $*
	compile
	if [ ! -z $MAME ]; then
		run_on_mame
	fi
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-m|--mame)  MAME=1;;
			-d|--debug) MAME=1; DEBUG="-debug -debugscript debug.mame";;
			-s|--sim) SIM=1;;
			-h|--help)
				show_help
				exit 0;;
			*) echo "Unsupported argument $1"
				exit 1;;
		esac
		shift
	done
}

function show_help {
	cat <<EOF
Generation of FLSTORY compatible Z80 code from C sources.

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

Test it on mame
	mame flstory -rompath . -debug
Test it on jtsim
	jtutil sdram
	jtsim
EOF
}

compile() {
	sdcc -mz80 --code-loc 0x0000 --data-loc 0xC000 --xram-size 0x800 -c custom.c
	sdasz80 -o crt0.rel crt0.s
	sdld -i custom.ihx custom.rel crt0.rel -k custom.lk
	makebin -s 0x2000 custom.ihx snd.22
	echo "Binary file for ROM snd.22 produced"
	clean_up_compile
}

clean_up_compile() {
	rm -f *.bi4 *.rel *.ihx *.map *.sym
}

run_on_mame() {
	unzip_rom
	cp snd.22 flstory
	mame flstory -rompath . -window -skip_gameinfo $DEBUG
}

unzip_rom() {
	if [ -d flstory ]; then	return; fi
	unzip ~/.mame/roms/flstory.zip  -d flstory
	unzip ~/.mame/roms/m68705p5.zip -d flstory/
}

main $*
