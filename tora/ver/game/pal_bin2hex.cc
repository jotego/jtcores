#include <iostream>
#include <fstream>

using namespace std;

// convert palette from MAME save command in debugger
// input binary palette file as stdin

int main() {
    ofstream fr("palr.hex");
    ofstream fgb("palgb.hex");
    char buf[2];
    cin.read(buf,2);
    do {
        int v = 0xff&(int)buf[0];
        fr << hex << v << '\n';
        v = 0xff&(int)buf[1];
        fgb << hex << v << '\n';
        cin.read(buf,2);
    }while( !cin.eof() );
}