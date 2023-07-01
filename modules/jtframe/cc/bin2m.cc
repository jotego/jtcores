#include <iostream>
#include <fstream>
#include <sstream>
#include <iomanip>

using namespace std;

int main() {
    ifstream fin("video.bin",ios_base::binary);
    if( !fin.good() ) {
        cout << "ERROR: cannot open video.bin\n";
        return 1;
    }
    int srgb;
    bool hsync = false;
    bool vsync = false;
    bool init  = true;

    int rows=0, cols=0;
    int frame=0;
    ofstream fout;

    while( !fin.eof() ) {
        fin.read( (char*) &srgb, 4 );
        if( init ) {
            if( !(srgb&0x2000) ) continue; // wait for first V blank
            init = false;
        }
        if( srgb & 0x2000 ) { // check for VS
            if( !vsync ) {
                // cout << "\nRows = " <<  rows << " rows\n";
                fout.close();
                stringstream name;
                name << "video_" << setfill('0') << setw(3) << frame << ".m";
                fout.open( name.str() );
                frame++;
            }
            vsync = true;
            rows=0;
            continue;
        }
        if( srgb & 0x1000 ) { // check for HS
            if( !hsync ) {
                fout << '\n';
                // cout << cols << ", ";
                rows++;
                cols=0;
            }
            hsync = true;
            continue;
        }        
        hsync = false;
        vsync=false;
        int r = srgb&0xf00;
        int g = srgb&0x0f0;
        int b = srgb&0x00f;
        int rgb32 = (((r<<8) | g)<<8) | b;
        fout << rgb32 << ' ';
        cols++;
    }
    return 0;
}