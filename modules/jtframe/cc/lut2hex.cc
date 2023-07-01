#include <iostream>
#include <iomanip>
#include <fstream>
#include <string>
#include <ctype.h>

using namespace std;

int parse_line( int *buf, ifstream& fin );

const int max_mem = 4*1024;

int main( int argc, char *argv[] ) {
    if( argc != 2 ) {
        cout << "ERROR: expecting lut filename\n";
        return 1;
    }
    string fname( argv[1] );
    ifstream fin( fname );
    if( !fin.good() ) {
        cout << "ERROR: cannot open file " << fname << '\n';
        return 2;
    }
    // Parse file
    int *buf = new int[max_mem]; // Max 16 kB
    for(int k=0; k<max_mem; k++ ) buf[k]=0;
    int *pline = buf;
    int line=0;

    try {
        while( !fin.eof() ) {
            pline += parse_line( pline, fin );
            if( pline-buf >= max_mem-4 ) {
                throw "ERROR: file is too long for 4kB ";
            }
            line++;
        }
        // Dump the contents
        ofstream fout( "lut.hex" );
        for( int k=0; k<max_mem; k++ ) {
            fout << hex << buf[k] << '\n';
        }
    } catch( const char* error ) {
        cout << "ERROR: " << error << "at line " << dec << (line+1) << '\n';
        delete []buf;
        return 3;
    }

    delete []buf;
    return 0;
}

int parse_line( int *buf, ifstream& fin ) {
    string line;
    getline( fin, line );
    if( line.length()==0 ) return 0;
    int f = line.find_first_not_of(" \t");
    if( line[f] == '#' ) return 0;
    if( line[f] == '\\') {
        int row_max=3;
        int col_max=0;
        if( line[f+1]=='9') { // parse 3x3 object
            col_max=3;
        }
        if( line[f+1]=='6') { // parse 3x2 object
            col_max=2;
        }
        if( col_max>0 ) {
            line=line.substr(3);
            int id, x, y, pal;
            int n = sscanf( line.c_str(), "%d, %d, %d, %d\n", &id, &x, &y, &pal );
            if( n!=4 ) throw "ERROR: not enough arguments ";
            for( int row=0; row<row_max; row++ )
                for( int col=0; col<col_max; col++ )
                {
                    buf[0] = id++;
                    buf[1] = x + col*2;
                    buf[2] = y + row*2;
                    buf[3] = pal;
                    buf+=4;
                }
            return 4*9;
        }
        throw "ERROR: cannot parse line "+line;
    }
    else { // single object
        int id, x, y, pal;
        int n = sscanf( line.c_str(), "%d, %d, %d, %d\n", &id, &x, &y, &pal );
        if( n!=4 ) throw "ERROR: not enough arguments ";
        buf[0] = id;
        buf[1] = x;
        buf[2] = --y; // deleted one so when writting LUT on a text editor
            // the line numbers used in the msg file can be entered directly
        buf[3] = pal;
        return 4;
    }
}