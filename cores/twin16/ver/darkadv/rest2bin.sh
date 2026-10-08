#!/bin/bash

main() {
	extract_sprite_tiles
	inject_into_sdram
}

extract_sprite_tiles() {
	dd if=rest.bin of=obj_tiles.bin bs=16 skip=1
}

inject_into_sdram() {
	local sdram=sdram_bank1.bin
	local aux=`mktemp`
	dd if=$sdram of=$aux bs=16k count=1
	append obj_tiles $aux bs=128k count=1
	append $sdram    $aux bs=16k skip=9
	mv $aux $sdram
}

append() {
	local input="$1"; shift
	local output="$1"; shift
	dd if=$input of=$output oflag=append conv=notrunc $*
}

main $*
