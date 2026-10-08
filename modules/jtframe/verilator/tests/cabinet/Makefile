CXX ?= c++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -pedantic

TEST = cabinet_test
SRC = main.cpp ../../cabinet.cpp ../../cheats.cpp ../../sim_utils.cpp

all: $(TEST)

$(TEST): $(SRC) ../../cabinet.h ../../cheats.h ../../sim_utils.h
	$(CXX) $(CXXFLAGS) -I../.. -o $@ $(SRC)

test: $(TEST)
	./$(TEST)

clean:
	rm -f $(TEST)

.PHONY: all test clean
