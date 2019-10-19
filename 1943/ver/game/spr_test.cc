#include <iostream>

using namespace std;

int main() {
    for(char k=0; k<32;k++) {
        char obj[4] = { (char)0x50, (char)0xea, (char)(48+(k%1)*4), (char)(k<<3) };
        cout.write( obj, 4 );
    }
    for( int row=0; row<8; row++ )
    //for(char k=0; k<32;k++) {
    //    char obj[4] = { (char)0x50, (char)0xea, (char)(48+(k%1)*4), (char)(k<<3) };
    //    cout.write( obj, 4 );
    //}
    //for(int k=32*4; k<128*4; k++) {
    //    char obj=0xf8;
    //    cout.write(&obj,1);
    //}
    return 0;
}