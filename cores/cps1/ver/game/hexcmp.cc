#include <iostream>
#include <iomanip>
#include <fstream>

/* Compares two files whose content is a hexadecimal number per line
    This is useful because text comparison failes if padding zeros
    are present only in one file or if case differences occur */

using namespace std;

int main(int argc, char *argv[]) {
    ifstream f1( argv[1] );
    ifstream f2( argv[2] );

    if( f1.bad() ) {
        cerr << "ERROR: cannot open " << argv[1] << '\n';
        return 1;
    }

    if( f2.bad() ) {
        cerr << "ERROR: cannot open " << argv[2] << '\n';
        return 1;
    }

    unsigned int n1, n2;
    int line=1;
    f1 >> hex >> n1;
    f2 >> hex >> n2;
    while( !f1.eof() && !f2.eof() ) {
        if( n1 != n2 ) {
            cout << "Files different at line " << line;
            cout << " ( 0x" << hex << line << ")";
            cout << '\n';
            return 1;
        }
        f1 >> hex >> n1;
        f2 >> hex >> n2;
        line++;
    }
    cout << "Files are equal\n";
    return 0;
}