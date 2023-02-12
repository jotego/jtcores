#include <iostream>
#include <fstream>
#include <iomanip>

using namespace std;

int dump64_word( ofstream& of, const char *s0, const char *s1, const char *s2, const char *s3 ) {
    int n=0;
    ifstream f0(s0,ios_base::binary);
    ifstream f1(s1,ios_base::binary);
    ifstream f2(s2,ios_base::binary);
    ifstream f3(s3,ios_base::binary);
    while( !f0.eof() ) {
        char a[4][2];
        f0.read( a[0], 2 );
        f1.read( a[1], 2 );
        f2.read( a[2], 2 );
        f3.read( a[3], 2 );
        int64_t t[4];
        for( int k=0; k<4; k++) {
            int64_t x;
            t[k] = a[k][0];
            t[k] &= 0xff;
            t[k] <<= 8;
            x    = a[k][1];
            x    &= 0xff;
            t[k] |= x;
            t[k] &= 0xffff; // redundant
        }
        int64_t all = (((((t[3] << 16)|t[2])<<16)|t[1])<<16)|t[0];
        of << hex << all << '\n';
        n++;
    }
    return n-1;
}

int dump64_byte( ofstream& of, 
    const char *s0, const char *s1, const char *s2, const char *s3,
    const char *s4, const char *s5, const char *s6, const char *s7 ) {
    int n=0;
    ifstream f0(s0,ios_base::binary);
    ifstream f1(s1,ios_base::binary);
    ifstream f2(s2,ios_base::binary);
    ifstream f3(s3,ios_base::binary);
    ifstream f4(s4,ios_base::binary);
    ifstream f5(s5,ios_base::binary);
    ifstream f6(s6,ios_base::binary);
    ifstream f7(s7,ios_base::binary);

    while( !f0.eof() ) {
        char c[8];
        f0.read( &c[0], 1 );
        f1.read( &c[1], 1 );
        f2.read( &c[2], 1 );
        f3.read( &c[3], 1 );
        f4.read( &c[4], 1 );
        f5.read( &c[5], 1 );
        f6.read( &c[6], 1 );
        f7.read( &c[7], 1 );
        int64_t t=0;
        for( int k=0; k<8; k++) { 
            int64_t a = c[k];
            a &= 0xff;
            t <<= 8;
            t |= a;
        }
        of << hex << t << '\n';
        n++;
    }
    return n-1;
}

int main() {
    ofstream of("gfx.hex");
    int os;
    os = dump64_word( of, "dm-05.3a", "dm-07.3f", "dm-06.3c", "dm-08.3g" );
    cout << "Bank 1 starts at " << hex << os << '\n';
    os += dump64_byte( of, "11.4c", "20.7c", "15.4g", "24.7g", "09.4a", "18.7a", "13.4e", "22.7e" );
    cout << "Bank 2 starts at " << hex << os << '\n';
    os += dump64_byte( of, "12.4d", "21.7d", "16.4h", "25.7h", "10.4b", "19.7b", "14.4f", "23.7f" );
    return 0;
}