#!/bin/bash
# generate data with writes to the OBJ RAM
rm -rf ~/.mame/nvram/ngp*
mame ngp -debug -debugscript <(cat <<EOF
    wp 8800,0100,w,1,{printf " %x=%02x", wpaddr, wpdata;go};
    wp 4000,3000,w,1,{printf " %x=%02x", wpaddr, wpdata;go};
    go
EOF
) -debuglog
cat debug.log | tr [:upper:] [:lower:] > writes.emu
#delete lines starting with a character or with >
sed -i '/^[a-z>]/d' writes.emu
rm -f debug.log

echo "Generate the simulation file with simram.sh. Then, run this command:"
echo "sdiff -d writes.emu writes.sim > d"