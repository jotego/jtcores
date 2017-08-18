
ifndef LIBPNG_CONFIG
LIBPNG_CONFIG := libpng-config
endif

make_cflags := -Wall -I$(PNGPP) -I$(PREFIX)/include $(shell $(LIBPNG_CONFIG) --cflags) $(CFLAGS)
make_ldflags := -L$(PREFIX)/lib $(shell $(LIBPNG_CONFIG) --static --ldflags) $(LDFLAGS)

ifndef NDEBUG
make_cflags := $(make_cflags) -g
make_ldflags := $(make_ldflags) -g
endif

sources := bytemerge.cc \
	hex2bin.cc \
	frame2png.cc

deps := $(sources:.cc=.dep)
objects := $(sources:.cc=.o)
bins := $(sources:.cc=$(bin_suffix))

all: $(sources) $(bins)

frame2png: frame2png.cc
	g++ $(CPPFLAGS) $(make_cflags) $(make_ldflags) $< -o $@
