#!/bin/bash

OD="od -t x1 -A none -v -w1"

$OD mm07.3b > 3b.hex
$OD mm09.3c > 3c.hex
$OD mm11.3e > 3e.hex

$OD mm06.1b > 1b.hex
$OD mm08.1c > 1c.hex
$OD mm10.1e > 1e.hex
$OD mm12.1l > 1l.hex
$OD mm14.4l > 4l.hex

$OD mmt03d.8n  > 8n.hex
$OD mmt04d.10n > 10n.hex
$OD mmt05d.13n > 13n.hex

$OD tbp24s10.14k > 14k.hex