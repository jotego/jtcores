#include <cstdio>
#include <cstring>
#include <fstream>

using namespace std;

void dump(const char *filename, char *buf, int len) {
    ofstream of(filename);
    for( int k=0; k<len; k++ ) {
        int c = buf[k];
        c&=0xff;
        of << hex << c << '\n';
    }    
}

void write_char( char *mem, const char *msg, int row, int col ) {
    row &= 0x1f;
    col &= 0x1f;
    row <<= 5;
    row |= col;
    while( *msg ) mem[row++] = *msg++;
}

int main(int argc, char *argv[]) {
    char *mem = new char[0x800];
    memset( mem, 0, 0x800 );
    dump( "scr_ram.hex",mem, 0x800 );
    dump( "obj_buf.hex",mem, 0x080 );
    // Write a message
    memset( mem, 0x20, 0x800 );
    write_char(mem, "HOLA MUNDO", 0x10,0x10 );
    dump("char_ram.hex",mem, 0x800 );
    return 0;
}