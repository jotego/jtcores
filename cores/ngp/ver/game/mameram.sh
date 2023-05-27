#!/bin/bash
rm -rf ~/.mame/nvram/ngp*
mame ngp -debug -debugscript <(echo 'wp 4000,3000,w,1,{printf " %x=%02x", wpaddr, wpdata;go};go') -debuglog
cat debug.log | tr [:upper:] [:lower:] > writes.emu
#delete lines starting with a character or with >
sed -i '/^[a-z>]/d' writes.emu
rm -f debug.log