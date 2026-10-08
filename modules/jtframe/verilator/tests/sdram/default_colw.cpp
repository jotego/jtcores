#include "../../sdram.cpp"

#ifndef EXPECTED_DEFAULT_COLW
#error EXPECTED_DEFAULT_COLW must be defined by the test build
#endif

int main() {
    return DEFAULT_COLW == EXPECTED_DEFAULT_COLW ? 0 : 1;
}
