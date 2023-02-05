#include <iostream>
#include <fstream>
#include <cassert>
#include <iomanip>

using namespace std;

void parse( const unsigned char* buf, const char *name );

int main( int argc, char* argv[] ) {
    unsigned char gfx1[8192];
    unsigned char gfx2[8192];

    ifstream fin("gfx1.bin",ios_base::binary);
    fin.read( (char*)gfx1, 8192 );
    fin.close();
    fin.open("gfx2.bin", ios_base::binary);
    fin.read( (char*)gfx2, 8192 );

    parse( gfx1, "GFX1" );
    parse( gfx2, "GFX2" );

    return 0;
}

void parse( const unsigned char* buf, const char *name ) {
    cout << "\n\n======================================\n";
    cout << name << '\n';
    bool lastout=false, lastzero=false;
    for( int page=0; page<2; page++) {
        cout << "\n*************  PAGE " << page << " ************\n";
        for( int i=0x1000+0x800*page; i<0x113F+0x800*page; i+=5 ) {
            unsigned code = buf[i];
            unsigned code_lsb = (buf[i+1]>>2)&3;
            unsigned bank = ((buf[i+4]&0xc0)>>4) | (buf[i+1]&3);
            unsigned full_code = (((bank<<8) | code)<<2) | code_lsb;
            unsigned y = buf[i+2];
            unsigned x = buf[i+3] | ( (buf[i+4]&1)<<8 );
            unsigned flipy = (buf[i+4]&0x20) != 0;
            unsigned flipx = (buf[i+4]&0x10) != 0;
            unsigned sprsize= (buf[i+4]>>1)&7;
            unsigned pal = buf[i+1]>>4;
            if( y== 240 && ( (i&0x3ff)/5)>16 ) {
                if( !lastout ) {
                    cout << "---------------- " << hex << (i&0x3FF);
                    cout << "* Out of screen\n";
                }
                lastout = true;
                continue;
            }
            lastout = false;
            if( buf[i]==0 && buf[i+1]==0 && buf[i+2]==0
                && buf[i+3]==0 && buf[i+4]==0 ) {
                if( !lastzero) {
                    cout << "---------------- " << hex << (i&0x3FF);
                    cout << " (" << dec << ((i&0x3ff)/5) << ") ";
                    cout << "* all zeroes *\n";
                }
                lastzero = true;
                continue;
            }
            else {
                cout << "---------------- " << hex << (i&0x3FF);
                cout << " (" << dec << ((i&0x3ff)/5) << ") ";
                cout << "-----------------------\n";
            }
            lastzero = false;
            cout << "Code\t" << hex << bank << "-" << code << "-" << code_lsb;
            cout << " -- full " << hex << full_code;
            cout << " -- RAW " << setfill('0') << hex
                           << setw(2) << (unsigned)buf[i+0] << ' '
                           << setw(2) << (unsigned)buf[i+1] << ' '
                           << setw(2) << (unsigned)buf[i+2] << ' '
                           << setw(2) << (unsigned)buf[i+3] << ' '
                           << setw(2) << (unsigned)buf[i+4] << ' ' << '\n';
            cout << "Pos " << dec << x << " / " << y << "    ";
            cout << "Flip " << flipx << " / " << flipy << "    ";
            cout << "Pal " << pal << " size ";
            switch( sprsize ) {
                case 0: cout << "16x16"; break;
                case 1: cout << "16x8";  break;
                case 2: cout << "8x16";  break;
                case 3: cout << "8x8";   break;
                case 4: cout << "32x32"; break;
                default: cout << "UNKNOWN"; break;
            }
            cout << '\n';
        }
    }
}
