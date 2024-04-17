#!/bin/bash

DUMP=dump.bin

if [ ! -z "$1"    ]; then DUMP="$1"; fi
if [ ! -e "$DUMP" ]; then "Cannot find $DUMP"; exit 1; fi

{{ range .Ioctl.Buses }}{{ if .Name -}}
# {{ .Name }} {{ .Size }} bytes ({{.SizekB}} kB)
dd if="$DUMP" of={{.Name}}.bin bs=256 count={{.Blocks}} skip={{.SkipBlocks}}
{{ if eq .DW 16 -}}
jtutil drop1    < {{.Name}}.bin > {{.Name}}_hi.bin
jtutil drop1 -l < {{.Name}}.bin > {{.Name}}_lo.bin
{{end }}
{{ end }}{{ end  }}
dd if="$DUMP" of=rest.bin bs=256 skip={{.Ioctl.SkipAll}}
