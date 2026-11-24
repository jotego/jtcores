# Generate the measured GX400 lookup tables used by the video and sound HDL.
# These are calculated constants, not arcade firmware.

HDL_DIR = ../hdl
COLMIX = $(HDL_DIR)/colmix.hex
PROM_VOL = $(HDL_DIR)/prom_vol.hex

default: $(COLMIX) $(PROM_VOL)

RESNET_BIN = ./resnet_colmix
RESNET_CPP = resnet_colmix.cpp

$(RESNET_CPP): mame/resnet.cpp resnet.patch
	patch -p0 -i resnet.patch -o $(RESNET_CPP)

$(COLMIX): $(RESNET_BIN)
	$(RESNET_BIN) > $@

$(RESNET_BIN): $(RESNET_CPP) mame/resnet.h mame/palette.h
	g++ -o $@ -std=c++17 $(RESNET_CPP)

$(PROM_VOL): prom_volumes.py
	python3 prom_volumes.py > $@

clean:
	rm -f $(RESNET_CPP) $(RESNET_BIN) $(COLMIX) $(PROM_VOL)
