#!/bin/bash

OD="od -t x1 -A none -v -w1"
ODx2="od -t x2 -A none -v -w2"

function curpos() {
	printf "%X" $(cat gng.hex | wc -l)
}

GAME=makaimurg

case $GAME in
	makaimur)
		rom8n=gngroms/8n.rom
		rom10n=gngroms/10n.rom
		rom12n=gngroms/12n.rom
		rom_char=gngroms/gg1.bin
		audio=gngroms/gg2.bin
		romx9=gngroms/gg9.bin
		romx7=gngroms/gg7.bin
		romx11=gngroms/gg11.bin
		romx8=gngroms/gg8.bin
		romx6=gngroms/gg6.bin
		romx10=gngroms/gg10.bin

		romx17=gngroms/gng13.n4
		romx16=gngroms/gg16.bin
		romx15=gngroms/gg15.bin

		romx14=gngroms/gng16.l4
		romx13=gngroms/gg13.bin
		romx12=gngroms/gg12.bin
		;;
	makaimurg)
		rom10n=gngroms/mj04g.bin
		rom8n=gngroms/mj03g.bin
		rom12n=gngroms/mj05g.bin
		rom_char=gngroms/gg1.bin
		audio=gngroms/gg2.bin
		romx9=gngroms/gg9.bin
		romx7=gngroms/gg7.bin
		romx11=gngroms/gg11.bin
		romx8=gngroms/gg8.bin
		romx6=gngroms/gg6.bin
		romx10=gngroms/gg10.bin

		romx17=gngroms/gng13.n4
		romx16=gngroms/gg16.bin
		romx15=gngroms/gg15.bin

		romx14=gngroms/gng16.l4
		romx13=gngroms/gg13.bin
		romx12=gngroms/gg12.bin
		;;		
	gngc)
		rom10n=gngroms/mm_c_04
		rom8n=gngroms/mm_c_03
		rom12n=gngroms/mm_c_05
		rom_char=gngroms/gg1.bin
		audio=gngroms/gg2.bin
		romx9=gngroms/gg9.bin
		romx7=gngroms/gg7.bin
		romx11=gngroms/gg11.bin
		romx8=gngroms/gg8.bin
		romx6=gngroms/gg6.bin
		romx10=gngroms/gg10.bin

		romx17=gngroms/gng13.n4
		romx16=gngroms/gg16.bin
		romx15=gngroms/gg15.bin

		romx14=gngroms/gng16.l4
		romx13=gngroms/gg13.bin
		romx12=gngroms/gg12.bin
		;;		
	gngt)
		rom8n=mmt03d.8n
		rom10n=mmt04d.10n
		rom12n=mmt05d.13n
		rom_char=mm01.11e
		audio=mm02.14h
		romx9=mm09.3c
		romx7=mm07.3b
		romx11=mm11.3e
		romx8=mm08.1c
		romx6=mm06.1b
		romx10=mm10.1e

		romx17=mm17.4n
		romx16=mm16.3n
		romx15=mm15.1n

		romx14=mm14.4l
		romx13=mm13.3l
		romx12=mm12.1l
		;;
esac
echo "ROMs for $GAME"
## Game ROM
$ODx2 $rom8n --endian little > gng.hex 
echo "10N starts at " $(curpos)
$ODx2 $rom10n --endian little >> gng.hex 
echo "13N starts at " $( curpos )
$ODx2 $rom12n --endian little >> gng.hex 
echo "Characters start at " $(curpos)
$ODx2 $rom_char >> gng.hex 
echo "Scroll tiles start at " $(curpos)
$OD $romx9 > 3c.hex
$OD $romx7 > 3b.hex
paste 3c.hex 3b.hex -d "" | tr -d ' ' > 3bc.hex
$OD $romx11 > 3e.hex
paste 3bc.hex 3e.hex -d "\n" >> gng.hex

$OD $romx8 > 1c.hex
$OD $romx6 > 1b.hex
paste 1c.hex 1b.hex -d "" | tr -d ' ' > 1bc.hex
$OD $romx10 > 1e.hex
paste 1bc.hex 1e.hex -d "\n" >> gng.hex

echo "Object starts at " $(curpos)

## Object ROM, 16kBx4 = 64kB
$OD $romx17 $romx16 $romx15 > n31.hex
$OD $romx14 $romx13 $romx12 > l31.hex
paste n31.hex l31.hex -d "" | tr -d ' ' > obj.hex
cat obj.hex >> gng.hex

## Sound ROM, 32kB
echo "Sound starts at " $(curpos)
$ODx2 $audio >> gng.hex 
echo "Sound ends at " $(curpos)

../cc/hex2bin
cp JTGNG.rom $GAME.rom