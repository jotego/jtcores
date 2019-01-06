#!/bin/bash

sound_type=normal

function show_usage {
	echo Usage: go-mist.sh "[rom-set] [-snd test|normal|fast]"
	echo -e "\trom-set is one of: makaimur makaimurg gngc speed_test gngt"
	exit 1
}

function valid_string {
	str=$1
	shift
	for i in $*; do
		if [ "$str" = "$i" ]; then
			return
		fi
	done
	echo "ERROR: \"$str\" must be one of" $*
	show_usage
}

while [ $# -gt 0 ]; do
	if [ "$GAME" = "" ]; then
		GAME=$1
		valid_string $GAME makaimur makaimurg gngc speed_test gngt
		shift
		continue
	fi
	# unknown parameter
	if [ "$GAME" != "" ]; then
		echo Unexpected argument $1. Game set was already specified to be $GAME
		show_usage
	fi
	echo Unknown argument $1
	show_usage
done

if [ "$GAME" = "" ]; then
	GAME=gngt
fi

function curpos() {
	cnt=$(cat JTGNG.rom | wc -c)
	# each ROM location has two bytes:
	cnt=$((cnt/2))
	printf "0x%05X = %d" $cnt $cnt 
}

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
	speed_test)
		rom10n=gngroms/mm_c_04
		rom8n=../mist/ver/game/speed_test.bin
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
if ! g++ ../cc/bytemerge.cc -o bytemerge; then
	echo ERROR: Cannot compile bytemerge utility.
	exit 1
fi
echo "ROMs for $GAME"
## Game ROM
cat $rom8n $rom10n $rom12n > JTGNG.rom

echo "Sound  starts at " $(curpos)
# Sound ROM
cat $audio >> JTGNG.rom

echo "Char   starts at " $(curpos)
cat $rom_char >> JTGNG.rom

echo "Scroll starts at " $(curpos)
# Scroll tiles, merge one byte from each ROM
# roms 9-7-11 belong to the same tile
# roms 8-6-10 belong to the same tile
bytemerge $romx9    $romx7  JTGNG.rom
bytemerge $romx8    $romx6  JTGNG.rom

# Scroll tiles, rest of bytes:
echo "Scroll upper 8 bits at " $(curpos)
bytemerge /dev/zero $romx11 JTGNG.rom
bytemerge /dev/zero $romx10 JTGNG.rom

echo "Object starts at " $(curpos)
#Objects
cat $romx17 $romx16 $romx15 > n31.bin
cat $romx14 $romx13 $romx12 > l31.bin
bytemerge n31.bin l31.bin JTGNG.rom
echo "File length " $(curpos) " 16-bit words"
