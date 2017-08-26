#!/bin/bash

OD="od -t x1 -A none -v -w1"
ODx2="od -t x2 -A none -v -w2"

## Game ROM
# 8N, 9N, 32kBx2
$ODx2 mmt03d.8n > gng.hex 
echo "@04000" >> gng.hex
$ODx2 mmt03d.8n >> gng.hex 
# 10N, 11N, 16kBx2
echo "@8000" >> gng.hex
$ODx2 mmt04d.10n >> gng.hex 
echo "@C000" >> gng.hex
$ODx2 mmt04d.10n >> gng.hex 
# 12N, 13N, 32kBx2
echo "@10000" >> gng.hex
$ODx2 mmt05d.13n >> gng.hex 
echo "@14000" >> gng.hex
$ODx2 mmt05d.13n >> gng.hex 

## Sound ROM, 32kB
echo "// Sound ROM " >> gng.hex
echo "@30000" >> gng.hex
$ODx2 mm02.14h >> gng.hex 

## Character ROM, 16kB
echo "// Character ROM " >> gng.hex
echo "@40000" >> gng.hex
$ODx2 mm01.11e >> gng.hex 

## Object ROM, 16kBx4 = 64kB
../cc/bytemerge mm{16.3n,13.3l} 3nl
../cc/bytemerge mm{15.1n,12.1l} 1nl
echo "// Object ROM " >> gng.hex
echo "@50000" >> gng.hex
$ODx2 3nl >> gng.hex 
$ODx2 1nl >> gng.hex 

## Scroll ROM, 16kBx4 = 64kB
#../cc/bytemerge mm*3{b,c} 3bc
#../cc/bytemerge mm*1{b,c} 1bc
echo "// Scroll ROM " >> gng.hex
echo "@60000" >> gng.hex
$OD mm09.3c > 3c.hex
$OD mm07.3b > 3b.hex
paste 3c.hex 3b.hex -d "" | tr -d ' ' > 3bc.hex
$OD mm11.3e > 3e.hex
paste 3bc.hex 3e.hex -d "\n" >> gng.hex
#$ODx2 3bc >> gng.hex 
#$ODx2 1bc >> gng.hex 
$OD mm08.1c > 1c.hex
$OD mm06.1b > 1b.hex
paste 1c.hex 1b.hex -d "" | tr -d ' ' > 1bc.hex
$OD mm10.1e > 1e.hex
paste 1bc.hex 1e.hex -d "\n" >> gng.hex


## Scroll ROM, 16kBx2 = 32kB
#echo "// Scroll ROM " >> gng.hex
#echo "@70000" >> gng.hex
#$OD *3e >> gng.hex 
#$OD *.1e >> gng.hex 

../cc/hex2bin