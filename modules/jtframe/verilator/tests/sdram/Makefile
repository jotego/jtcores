CXX ?= c++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -pedantic

TEST = sdram_test
SRC = main.cpp ../../sdram.cpp

all: $(TEST)

$(TEST): $(SRC) ../../sdram.h
	$(CXX) $(CXXFLAGS) -I../.. -o $@ $(SRC)

test: $(TEST)
	./$(TEST)

clean:
	rm -f $(TEST)

.PHONY: all test clean
