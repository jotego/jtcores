#!/bin/bash -e

DUMP=dump.bin

main() {
	set_input_file $1
	split_into_parts
	run_core_specific_script
}

set_input_file() {
	local scene_file="$1"
	if [ ! -z "scene_file" ]; then DUMP="$scene_file"; fi
	if [ ! -e "$DUMP" ]; then
		echo "Cannot find $DUMP"
		return 1
	fi
}

split_into_parts() {
	{{ range .Ioctl.Buses }}{{ if .Name -}}
	# {{ .Name }} {{ .Size }} bytes ({{.SizekB}} kB)
	dd if="$DUMP" of={{.Name}}.bin bs=256 count={{.Blocks}} skip={{.SkipBlocks}}
	{{ if eq .DW 16 -}}
	jtutil drop1    < {{.Name}}.bin > {{.Name}}_hi.bin
	jtutil drop1 -l < {{.Name}}.bin > {{.Name}}_lo.bin
	{{end }}
	{{ end }}{{ end  }}
	make_rest
}

make_rest() {
	dd if="$DUMP" of=rest.bin bs=256 skip={{.Ioctl.SkipAll}}
}

run_core_specific_script() {
	if [ -x rest2bin.sh ]; then
		rest2bin.sh
	fi
}

main $*