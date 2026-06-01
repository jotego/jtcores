all: ../hdl/boot.hex

../hdl/boot.hex: boot.s Makefile
	asl -cpu 65c02 boot.s -l
	p2hex boot.p boot.ihex -r '$$c000-$$ffff' -l 16 -F Intel
	objcopy -I ihex -O binary --gap-fill 0 --pad-to 0x10000 boot.ihex boot.bin
	xxd -p -c 1 boot.bin > $@
	rm -f boot.bin boot.full.bin boot.ihex boot.lst boot.p

clean:
	rm -f boot.bin boot.full.bin boot.ihex boot.lst boot.p cps3crc.bin cps3crc.lst cps3crc.p
