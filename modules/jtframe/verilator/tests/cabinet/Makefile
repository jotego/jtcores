CXX ?= c++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -pedantic

TEST = cabinet_test
PACKER = cabinet_pack
SRC = main.cpp ../../cabinet.cpp ../../cheats.cpp ../../sim_utils.cpp

all: $(TEST)

$(TEST): $(SRC) ../../cabinet.h ../../cheats.h ../../sim_utils.h
	$(CXX) $(CXXFLAGS) -I../.. -o $@ $(SRC)

$(PACKER): ../../cabinet_export.cpp ../../cabinet.cpp ../../cabinet.h ../../sim_utils.cpp ../../sim_utils.h
	$(CXX) $(CXXFLAGS) -I../.. -o $@ ../../cabinet_export.cpp ../../cabinet.cpp ../../sim_utils.cpp

test: $(TEST) $(PACKER)
	./$(TEST)
	python3 export_test.py ./$(PACKER)

clean:
	rm -f $(TEST) $(PACKER)

.PHONY: all test clean
