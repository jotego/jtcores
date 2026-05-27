CXX ?= c++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -pedantic

TEST = sdram_test
SRC = main.cpp ../../sdram.cpp
DEFAULT_COLW_TESTS = default_colw_32 default_colw_large

all: $(TEST)

$(TEST): $(SRC) ../../sdram.h
	$(CXX) $(CXXFLAGS) -I../.. -o $@ $(SRC)

default_colw_32: default_colw.cpp ../../sdram.cpp ../../sdram.h
	$(CXX) $(CXXFLAGS) -I../.. -DEXPECTED_DEFAULT_COLW=9 -o $@ default_colw.cpp

default_colw_large: default_colw.cpp ../../sdram.cpp ../../sdram.h
	$(CXX) $(CXXFLAGS) -I../.. -D_JTFRAME_SDRAM_LARGE -DEXPECTED_DEFAULT_COLW=10 -o $@ default_colw.cpp

test: $(TEST) $(DEFAULT_COLW_TESTS)
	./$(TEST)
	./default_colw_32
	./default_colw_large

clean:
	rm -f $(TEST) $(DEFAULT_COLW_TESTS)

.PHONY: all test clean
