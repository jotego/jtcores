# Generate the lookup table for the resistor network at the output of
# the palette RAM, using the code from resnet.cpp in MAME.
# 
# We patch resnet.cpp to add a main function and some definitions so
# that it works standalone, and print a .hex file that we use in
# u_colour_lut in nemesis_game.v.
# 
# Source files from MAME (commit 12864014 from Jun 19, 2020):
# - src/lib/util/palette.h
# - src/emu/video/resnet.h
# - src/emu/video/resnet.cpp

RESNET_BIN = ./resnet_colmix
RESNET_CPP = resnet_colmix.cpp
COLMIX = nemesis_colmix.hex

default: $(COLMIX)

$(RESNET_CPP): mame/resnet.cpp resnet.patch
	cp mame/resnet.cpp $@
	patch -p0 -i resnet.patch

$(COLMIX): $(RESNET_BIN)
	$(RESNET_BIN) > $@

$(RESNET_BIN): $(RESNET_CPP) mame/resnet.h mame/palette.h
	g++ -o $@ -std=c++17 $(RESNET_CPP)

clean:
	rm -f $(RESNET_CPP) $(RESNET_BIN)
