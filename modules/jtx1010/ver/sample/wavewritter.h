#include <string>
#include <fstream>
#include <iomanip>
#include <iostream>

using namespace std;

class WaveWritter {
    std::ofstream fsnd, fhex;
    std::string name;
    bool dump_hex;
    void Constructor(const char *filename, int sample_rate, bool hex );
public:
    WaveWritter(const char *filename, int sample_rate, bool hex ) {
        Constructor( filename, sample_rate, hex );
    }
    WaveWritter(const std::string &filename, int sample_rate, bool hex ) {
        Constructor( filename.c_str(), sample_rate, hex );
    }
    void write( int16_t *lr );
    ~WaveWritter();
};


void WaveWritter::write( int16_t* lr ) {
    fsnd.write( (char*)lr, sizeof(int16_t)*2 );
    if( dump_hex ) {
        fhex << hex << lr[0] << '\n';
        fhex << hex << lr[1] << '\n';
    }
}

void WaveWritter::Constructor( const char *filename, int sample_rate, bool hex ) {
    name = filename;
    fsnd.open(filename, ios_base::binary);
    dump_hex = hex;
    if( dump_hex ) {
        char *hexname;
        hexname = new char[strlen(filename)+1];
        strcpy(hexname,filename);
        strcpy( hexname+strlen(filename)-4, ".hex" );
        cerr << "Hex file " << hexname << '\n';
        fhex.open(hexname);
        delete[] hexname;
    }
    // write header
    char zero=0;
    for( int k=0; k<45; k++ ) fsnd.write( &zero, 1 );
    fsnd.seekp(0);
    fsnd.write( "RIFF", 4 ); // @ 0
    fsnd.seekp(8);
    fsnd.write( "WAVEfmt ", 8 );  // @ 8
    int32_t number32 = 16;
    fsnd.write( (char*)&number32, 4 ); // @ 16
    int16_t number16 = 1;
    fsnd.write( (char*) &number16, 2); // @ 20
    number16=2;
    fsnd.write( (char*) &number16, 2); // @ 22
    number32 = sample_rate;
    fsnd.write( (char*)&number32, 4 ); // @ 26
    number32 = sample_rate*2*2;
    fsnd.write( (char*)&number32, 4 ); // @ 30
    number16=2*2;   // Block align
    fsnd.write( (char*) &number16, 2); // @ 32
    number16=16;
    fsnd.write( (char*) &number16, 2); // @ 34
    fsnd.write( "data", 4 ); // @ 36
    fsnd.seekp(44);
}

WaveWritter::~WaveWritter() {
    int32_t number32;
    streampos file_length = fsnd.tellp();
    number32 = (int32_t)file_length-8;
    fsnd.seekp(4);
    fsnd.write( (char*)&number32, 4);
    fsnd.seekp(40);
    number32 = (int32_t)file_length-44;
    fsnd.write( (char*)&number32, 4);
}