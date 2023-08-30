#!/bin/bash

{{ range .Ioctl.Buses }}{{ if .Name -}}
# {{ .Name }} {{ .Size }} bytes ({{.SizekB}} kB)
dd if=$1 of={{.Name}}.bin bs=256 count={{.Blocks}} skip={{.SkipBlocks}}
{{ if eq .DW 16 -}}
drop1    < {{.Name}}.bin > {{.Name}}_hi.bin
drop1 -l < {{.Name}}.bin > {{.Name}}_lo.bin
{{end }}
{{ end }}{{ end  }}
dd if=$1 of=rest.bin bs=256 skip={{.Ioctl.SkipAll}}
