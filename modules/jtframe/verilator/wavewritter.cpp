/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 9-5-2022 */

#include <cstring>
#include <iostream>

#include "wavewritter.h"

using namespace std;

WaveWritter::WaveWritter(const char *filename, int sample_rate, bool hex ) {
    Constructor( filename, sample_rate, hex );
}

WaveWritter::WaveWritter(const std::string &filename, int sample_rate, bool hex ) {
    Constructor( filename.c_str(), sample_rate, hex );
}

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
    char zero=0;
    for( int k=0; k<45; k++ ) fsnd.write( &zero, 1 );
    fsnd.seekp(0);
    fsnd.write( "RIFF", 4 );
    fsnd.seekp(8);
    fsnd.write( "WAVEfmt ", 8 );
    int32_t number32 = 16;
    fsnd.write( (char*)&number32, 4 );
    int16_t number16 = 1;
    fsnd.write( (char*) &number16, 2);
    number16=2;
    fsnd.write( (char*) &number16, 2);
    number32 = sample_rate;
    fsnd.write( (char*)&number32, 4 );
    number32 = sample_rate*2*2;
    fsnd.write( (char*)&number32, 4 );
    number16=2*2;
    fsnd.write( (char*) &number16, 2);
    number16=16;
    fsnd.write( (char*) &number16, 2);
    fsnd.write( "data", 4 );
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
