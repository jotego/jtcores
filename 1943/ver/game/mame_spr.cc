#include <iostream>

using namespace std;

int main() {
    char mem[4*1024];
    char dma[512];
    cin.read(mem,4*1024);
    for( int k=0; k<512; k++ ) {
        int p = (k&3)+( (k&~3)<<3);        
        dma[k] = mem[p];
        //cout << k << ' ' << p << '\n';
    }
    cout.write(dma,512);
    return 0;
}