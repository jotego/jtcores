#include <cstdio>
#include <fstream>

using namespace std;

int main(int argc, char *argv[]) {
    char *mem = new char[0x800];
    for( int k=0; k<0x800; k++ ) mem[k]=0;
    ofstream of("char_ram.hex");
    for( int k=0; k<0x800; k++ ) {
        int c = mem[k];
        c&=0xff;
        of << hex << c << '\n';
    }
    return 0;
}