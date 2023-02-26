#include <iostream>
#include <iomanip>

using namespace std;

int bg8x4_scan(int col, int row ) {
    return (col & 0x0f) + ((row & 0x0f) << 4) + ((col & 0x70) << 4) + ((row & 0x30) << 7);
}

int bg4x8_scan(int col, int row ) {
    return (col & 0x0f) + ((row & 0x0f) << 4) + ((col & 0x30) << 4) + ((row & 0x70) << 6);
}

void all_8x4() {    
    for( int row=0; row<64; row++ ) {
        for( int col=0; col<128; col++ ) {
            cout << hex << row << '\t' << hex << col << '\t' 
                << hex << bg8x4_scan(row,col) << '\n';
        }
    }
}

void all_4x8() {    
    for( int row=0; row<128; row++ ) {
        for( int col=0; col<64; col++ ) {
            cout << hex << row << '\t' << hex << col << '\t' 
                << hex << bg4x8_scan(row,col) << '\n';
        }
    }
}

int main() {
    //all_4x8();
    all_8x4();
}