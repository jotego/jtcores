#include <iostream>
#include <fstream>

using namespace std;

int main() {
    ofstream of_red("palr.hex");
    ofstream of_gb("palgb.hex");

    of_red << hex;
    of_gb  << hex;

    for( int k=0; k<1024; k+=16 ) {
        for( int j=0; j<16; j++ ) {
            of_red << j << '\n';
            of_gb << ( (j<<4)|j ) << '\n';
        }
    }
    return 0;
}