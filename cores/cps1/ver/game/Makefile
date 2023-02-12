all: sdram_bank1.hex sdram_bank2.hex sdram_bank3.hex cps_cfg.hex

sdram_bank1.hex sdram_bank2.hex sdram_bank3.hex cps_cfg.hex: rom.bin rom2hex
	rom2hex rom.bin $(SCENE)

rom2hex: rom2hex.cc

