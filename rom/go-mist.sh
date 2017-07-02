#!/bin/bash

OD="od -t x1 -A none -v -w1"
ODx2="od -t x2 -A none -v -w2"

## Game ROM
# 8N, 9N, 32kBx2
$OD mmt03d.8n > gng.hex 
$OD mmt03d.8n >> gng.hex 
# 10N, 11N, 16kBx2
$OD mmt04d.10n >> gng.hex 
$OD mmt04d.10n >> gng.hex 
# 12N, 13N, 32kBx2
$OD mmt05d.13n >> gng.hex 
$OD mmt05d.13n >> gng.hex 

## Sound ROM, 32kB
echo "// Sound ROM " >> gng.hex
echo "@30000" >> gng.hex
$OD mm02.14h >> gng.hex 

## Character ROM, 16kB
echo "// Character ROM " >> gng.hex
echo "@40000" >> gng.hex
$OD mm01.11e >> gng.hex 

## Object ROM, 32kBx2x2
../cc/bytemerge mm{16.3n,13.3l} 3nl
../cc/bytemerge mm{15.1n,12.1l} 1nl
echo "// Object ROM " >> gng.hex
echo "@68000" >> gng.hex
$ODx2 3nl >> gng.hex 
$ODx2 1nl >> gng.hex 

## Scroll ROM, 16kBx2x2
../cc/bytemerge mm*3{b,c} 3bc
../cc/bytemerge mm*1{b,c} 1bc
echo "// Scroll ROM " >> gng.hex
echo "@e0000" >> gng.hex
$ODx2 3bc >> gng.hex 
$ODx2 1bc >> gng.hex 

## Scroll ROM, 16kBx2
echo "// Scroll ROM " >> gng.hex
echo "@f0000" >> gng.hex
$OD *3e >> gng.hex 
$OD *.1e >> gng.hex 