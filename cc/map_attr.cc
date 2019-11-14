#include <iostream>
#include <fstream>

// Extract every second byte of a file and dump it to stdout
// This usually corresponds to the attribute byte of a map file

using namespace std;

int main(/*int argc, char *argv[]*/) {
    ifstream fin("tr_13.7l", ifstream::binary );
    if( fin.good() ) {
        while(!fin.eof() ) {
            char buf[2];
            fin.read( buf, 2 );
            cout.write( &buf[1], 1 );
        }
        return 0;
    }
    else {
        cout << "ERROR: problem reading map file.";
        return 1;
    }
}