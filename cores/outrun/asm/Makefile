jtoutrun.rom: test.mra test-rom.zip
	mra test.mra -z .
	cp -v jtoutrun.rom $(ROM)
	if [ -d /m/MIST ] ; then cp -v jtoutrun.rom /m/MIST; fi

test-rom.zip: main.bin sub.bin
	zip test-rom.zip main.bin sub.bin

sub.bin: sub.asm
	vasmm68k_mot -Fbin -L sub.lst -o sub.bin sub.asm
	dd if=/dev/urandom of=sub.bin conv=notrunc oflag=append count=768
	truncate --size=384K sub.bin

main.bin: main.asm
	vasmm68k_mot -Fbin -L main.lst -o main.bin main.asm
	dd if=/dev/urandom of=main.bin conv=notrunc oflag=append count=768
	truncate --size=384K main.bin

clear:
	rm -f main.bin sub.bin test-rom.zip jtoutrun.rom