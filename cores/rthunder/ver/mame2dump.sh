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
}

create_folder() {
	mkdir -p scenes/$folder_name
}

concat_files() {
	cat vram0.bin vram1.bin > scenes/$folder_name/dump.bin
}

main $*
