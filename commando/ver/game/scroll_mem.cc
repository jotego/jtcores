#include <fstream>

using namespace std;

int main() {
    ofstream of("scrlow.bin", ios_base::binary);
    for( int k=0;k<1024;k++) {
        const char tile[2] = {0x55, 0x4d};
        of << tile[ k&1 ];
    }
    return 0;
}