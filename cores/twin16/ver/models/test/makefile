TOP = twin16_main_tb
TOPSRC = twin16_main_tb.v
SRC_FILES = ../*.v
BIN = $(TOP).vvp

# Directories with Verilog modules
VERILOG_DIRS = ../lib/av/ \
               ../lib/70v000/ \
               ../lib/7400/ \
               ../lib/misc/

# Add `-y` for Verilog source directories
VFLAGS = -Wall -Wtimescale -s $(TOP) \
         $(addprefix -y ,$(VERILOG_DIRS))

all: $(BIN)

$(BIN): $(TOPSRC) $(SRC_FILES)
	iverilog -o $(BIN) $(VFLAGS) $(TOPSRC) $(SRC_FILES)

test: $(BIN)
	vvp $(BIN) -fst

.PHONY: clean

clean:
	rm -f *.vvp *.vcd *.fst
