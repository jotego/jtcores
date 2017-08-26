#!/bin/bash

OD="od -t x1 -A none -v -w16 --read-bytes=16"

function cmp() {
	A=$($OD --skip-bytes=$(($2*1024)) $1)
	B=$($OD --skip-bytes=$(($3*1024)) JTGNG.rom)
	echo "$A"
	if [ "$A" != "$B" ]; then
		echo "$B"
		echo "ERROR: Mismatch"
	fi
}

echo "\$8000 (8N)"
cmp mmt03d.8n 0 0
echo "\$C000 (8N)"
cmp mmt03d.8n 16 16
echo "\$6000 (10N high)"
cmp mmt04d.10n 8 40

echo "\$4000 Bank 0 (13N low)"
cmp mmt05d.13n 0 48
echo "\$4000 Bank 1 (13N low)"
cmp mmt05d.13n 8 56
echo "\$4000 Bank 2 (13N low)"
cmp mmt05d.13n 16 64
echo "\$4000 Bank 3 (13N low)"
cmp mmt05d.13n 24 72
echo "\$4000 Bank 4 (10N low)"
cmp mmt04d.10n 0 32