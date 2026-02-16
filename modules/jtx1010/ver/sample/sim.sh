#!/bin/bash -e

SAMPLE_FILE=scale.csv.gz
ROMPATH=~/.mame/roms
OTHER=

main() {
	parse_args "$@"
	if [[ "$SAMPLE_FILE" = *gz ]]; then unzip_file; fi
	clean_up_on_exit
	prepare_rom
	compile_verilator
	run_sim $channel
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help) show_help; exit 0;;
			-t|--time) OTHER="$1 $2 $OTHER"; shift;;
			-w|--keep)
				if [[ $2 =~ ^[0-9]+$ ]]; then
					OTHER="$1 $2 $OTHER"
					shift
				else
					OTHER="$1 $OTHER"
				fi
				;;
			-*) echo "Unknown argument $1"; exit 1;;
			*) SAMPLE_FILE=$1;;
		esac
		shift
	done
	fix_file_name
}

show_help() {
	cat<<EOF
$0 simulates .csv files consisting of tuples of data representing write
events to the chip:

clock ticks,address,data

Use $0 [filename.csv[.gz]] [other arguments]

-t, --time	simulate up to this time in ms
-w, --keep	creates a .fst file
-h, --help  this screen
EOF
}

fix_file_name() {
	local alt=$SAMPLE_FILE
	if [ ! -e $alt ]; then
		if [ -e ${alt}.csv ]; then
			SAMPLE_FILE=${alt}.csv
			return
		elif [ -e ${alt}.csv.gz ]; then
			SAMPLE_FILE=${alt}.csv.gz
			return
		fi
		echo "Cannot find file $SAMPLE_FILE"
		exit 1
	fi
}

unzip_file() {
	local name=${SAMPLE_FILE%.gz}
	gunzip -c $SAMPLE_FILE > $name
	SAMPLE_FILE=$name
}

clean_up_on_exit() {
	trap "rm -f test.vcd" EXIT INT KILL
}

prepare_rom() {
	local info=`head -n 1 $SAMPLE_FILE`
	local hash zipname filenames
	read hash zipname filenames <<< $info
	if [[ -z "$zipname" || -z "$filenames" ]]; then
		echo "The first line of the CSV file must contain"
		echo "the setname followed by the PCM ROM names"
		exit 1
	fi
	unzip -qo $ROMPATH/${zipname}.zip $filenames
	cat $filenames > rom.bin
	rm -f $filenames
}

run_sim() {
	local channel="$1"
	rm -f test.vcd
	mkfifo test.vcd
	vcd2fst -p test.vcd test.fst &
	echo obj_dir/UUT $SAMPLE_FILE $OTHER
	time obj_dir/UUT $SAMPLE_FILE $OTHER
	rm test.vcd
}

compile_verilator() {
	rm -rf obj_dir
	verilator --quiet-stats ../../hdl/*v \
		$JTFRAME/hdl/ram/jtframe_*.v -DSIMULATION \
		--prefix UUT --top-module jtx1010 --trace \
		--timescale 1ps/1ps --cc test.cpp --exe
	export CPPFLAGS="-O1"
	make -j -C obj_dir -f UUT.mk > make.log || (cat make.log; exit 1)
}

main "$@"