#include <iostream>
#include <fstream>

using namespace std;

int main() {
    ofstream ob("b_ram.bin", ios_base::binary);
    ofstream org("rg_ram.bin", ios_base::binary);
    for( int k=0; k<256; k++ ) {
        char buf[4] = { 0xff, 0x88, 0x44, 0 };
        ob.write(buf, 4 );
        org.write(buf, 4 );
    }
    return 0;
}