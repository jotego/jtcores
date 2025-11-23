#!/bin/bash

# you may need to run this as sudo depending on the docker configuration

main() {
	make_gather_file
	convert_to_verilog
	remove_temp_files
	echo "t65-new.v created"
}

make_gather_file() {
	cat > gather.f <<EOF
T65_Pack.vhd
T65_ALU.vhd
T65_MCode.vhd
T65.vhd
EOF
}


convert_to_verilog() {
	ghdl -a -fsynopsys @gather.f
	ghdl synth --out=verilog T65 > t65-new.v
	rename_verilog_keywords_used_as_variables
}

rename_verilog_keywords_used_as_variables() {
	sed -i "s/break/brk/g" t65-new.v
}

ghdl() {
    docker run -ti -w/mnt -v `pwd`:/mnt ghdl/ghdl:ubuntu22-llvm-11 ghdl $*
}

remove_temp_files() {
	rm -f gather.f
}

main "$@"