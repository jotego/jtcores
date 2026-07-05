#!/bin/bash -e

DUMP=dump.bin
DELETE=

main() {
	parse_args "$@"
	if [ -n "$DELETE" ]; then
		delete_parts
		return
	fi
	require_input_file
	split_into_parts
	run_core_specific_script
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--delete) DELETE=1;;
			*) DUMP="$1";;
		esac
		shift
	done
}

require_input_file() {
	if [ ! -e "$DUMP" ]; then
		echo "Cannot find $DUMP"
		return 1
	fi
}

split_into_parts() {
	{{ range .Ioctl.Buses }}{{ if .Name -}}
	# {{ .Name }} {{ .Size }} bytes ({{.SizekB}} kB)
	dd if="$DUMP" of={{.Name}}.bin bs=64 count={{.Blocks}} skip={{.SkipBlocks}}
	{{ if eq .DW 16 -}}
	jtutil drop1    < {{.Name}}.bin > {{.Name}}_hi.bin
	jtutil drop1 -l < {{.Name}}.bin > {{.Name}}_lo.bin
	{{end }}
	{{ end }}{{ end  }}
	make_rest
}

delete_parts() {
	{{ range .Ioctl.Buses }}{{ if .Name -}}
	rm -f {{.Name}}.bin
	{{ if eq .DW 16 -}}
	rm -f {{.Name}}_hi.bin {{.Name}}_lo.bin
	{{end }}
	{{ end }}{{ end  }}
	rm -f rest.bin
}

make_rest() {
	dd if="$DUMP" of=rest.bin bs=64 skip={{.Ioctl.SkipAll}}
}

run_core_specific_script() {
	local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	for path in $script_path/. $script_path/..; do
		if [ -x $path/rest2bin.sh ]; then
			echo $path/rest2bin.sh
			$path/rest2bin.sh
			return
		fi
	done
}

main "$@"
