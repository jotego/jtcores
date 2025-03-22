#!/bin/bash -e

main() {
	parse_args $*
	create_folder
	concat_files
}

parse_args() {
	folder_name="$1"
	if [ -z "$folder_name" ]; then
		echo "Missing scene name"
		exit 1
	fi
	rest="$2"
}

create_folder() {
	mkdir -p scenes/$folder_name
}

concat_files() {
	cat vram0.bin vram1.bin > scenes/$folder_name/dump.bin
	if [ -z "$rest" ]; then
		rest="00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
	fi
	echo $rest | tr -d ' \n' | xxd -r -p >> scenes/$folder_name/dump.bin
}

main $*
