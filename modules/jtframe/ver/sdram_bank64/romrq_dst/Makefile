all: sdram_bank0.bin sdram_bank1.bin sdram_bank2.bin sdram_bank3.bin \
	sdram_bank0.hex sdram_bank1.hex sdram_bank2.hex sdram_bank3.hex

sdram_bank0.bin sdram_bank1.bin sdram_bank2.bin sdram_bank3.bin:
	dd if=/dev/urandom of=sdram_bank0.bin bs=1K count=128
	dd if=/dev/urandom of=sdram_bank1.bin bs=1K count=128
	dd if=/dev/urandom of=sdram_bank2.bin bs=1K count=128
	dd if=/dev/urandom of=sdram_bank3.bin bs=1K count=128

sdram_bank0.hex: sdram_bank0.bin
	cat sdram_bank0.bin | bin2hex > sdram_bank0.hex

sdram_bank1.hex: sdram_bank1.bin
	cat sdram_bank1.bin | bin2hex > sdram_bank1.hex

sdram_bank2.hex: sdram_bank2.bin
	cat sdram_bank2.bin | bin2hex > sdram_bank2.hex

sdram_bank3.hex: sdram_bank3.bin
	cat sdram_bank3.bin | bin2hex > sdram_bank3.hex