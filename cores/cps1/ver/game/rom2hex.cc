// Creates hex files to be load in simulation in order to
// skip the ROM loading process
// The input ROM file must be created from an MRA file with the mra tool

// The output files are:
// sdram bank hex files
// CPS config data
// Q-Sound firmware

#include <iostream>
#include <fstream>
#include <iomanip>
#include <cstdlib>
#include <cstring>
#include <cassert>
#include <string>

using namespace std;

int get_offset( char *b, int s ) {
    int a0 = b[s];
    int a1 = b[s+1];
    a0 &= 0xff;
    a1 &= 0xff;
    int a2 = (a1<<8) | a0;
    a2 <<= 10; // convert kB to bytes
    return a2;
}

int BANK_LEN = 0x80'0000;

void clear_bank( char *data );
void dump_bank( char *data, const char *fname );
void read_bank( char *data, ifstream& fin, int start, int end, int offset=0 );
void read_vram( char *data, const string& game, const string& scene, const char *fn, int offset, int len );
void dump_cfg( char header[64]);
void dump_kabuki( char header[64]);
void dump_qsnd( char *data );
void rewrite( uint64_t* io );
void cps2split( char *buf, const string name, int start );
void dump_cps2obj( const string& game, const string& scene );

int main(int argc, char *argv[]) {
    bool cps2=false;
    string game, scene;

    for( int k=2; k<argc; k++ ) {
        if( strcmp(argv[k], "-cps2")==0 ) {
            // printf("rom2hex: CPS2 mode enabled\n");
            cps2=true;
            BANK_LEN = 0x100'0000;
            continue;
        }
        if( strcmp(argv[k], "-game")==0 ) {
            assert( k+1 < argc );
            game=argv[++k];
            continue;
        }
        if( strcmp(argv[k], "-scene")==0 ) {
            assert( k+1 < argc );
            scene=argv[++k];
            continue;
        }
        printf("rom2hex: unsupported argument '%s'\n", argv[k] );
        return 1;
    }

    ifstream fin( argv[1], ios_base::binary );
    if( !fin.good() ) {
        cout << "ERROR: cannot open file " << argv[1] << '\n';
        return 1;
    }
    char header[64];
    bool qnsd_game=false;
    fin.read( header, 64 );

    int snd_start  = get_offset( header, 0 );
    int pcm_start  = get_offset( header, 2 );
    int gfx_start  = get_offset( header, 4 );
    int qsnd_start = get_offset( header, 6 );
    qnsd_game = qsnd_start != 0xffff*0x400;

    cout << "Sound start " << hex << snd_start << '\n';
    cout << "PCM   start " << hex << pcm_start << '\n';
    cout << "GFX   start " << hex << gfx_start << '\n';
    if( qnsd_game ) {
        cout << "Qsnd  start " << hex << qsnd_start << '\n';
    }

    dump_cfg( header );
    dump_kabuki( header );

    char *data = new char[BANK_LEN];
    try{
        // VRAM
        const int VRAM_OFFSET=0x20'0000;
        const int ORAM_OFFSET=0x28'0000;
        const int SND_OFFSET =0x38'0000;
        if( game.size() && scene.size() ) {
            clear_bank(data);
            read_vram( data, game, scene, "vram", VRAM_OFFSET, 192 );
            if( cps2 ) {
                read_vram( data, game, scene, "obj", ORAM_OFFSET, 8 );
                dump_cps2obj( game, scene );
            }
        }
        read_bank( data, fin, 0, snd_start );   // Main CPU
        read_bank( data, fin, snd_start, pcm_start, SND_OFFSET<<1 );
        dump_bank( data, "sdram_bank0" );
        // GFX
        int rd_ptr = gfx_start;
        for( int bank=cps2?2:3; bank<4 && rd_ptr < qsnd_start; bank++, rd_ptr+=0x80'0000 ) {
            clear_bank( data );
            read_bank( data, fin, rd_ptr, rd_ptr+BANK_LEN );
            if( cps2 ) {
                const int banksize=0x20'0000;
                for (int i = 0; i < BANK_LEN; i += banksize)
                    rewrite( (uint64_t *)(data+i) ); // address wires are shuffled
            }
            char szaux[32];
            sprintf(szaux,"sdram_bank%d",bank);
            dump_bank( data, szaux );
        }
        // Sound
        clear_bank( data );
        read_bank( data, fin, pcm_start, gfx_start, 0x10'0000<<1 );
        dump_bank( data, "sdram_bank1" );
        // QSound firmware
        if( qnsd_game ) {
            read_bank( data, fin, qsnd_start, qsnd_start+0x2000 );
            dump_qsnd( data );
        }
    } catch( const char *s) {
        cout << "ERROR: " << s << '\n';
    }

    delete []data;
    return 0;
}

void rewrite( uint64_t* io ) {
    uint64_t *copy = new uint64_t[0x20'0000/8];
    memcpy( copy, io, 0x20'0000 );
    for( int k=0; k<0x20'0000/8; k++ ) {
        // gfx_addr = { gfx_addr[24:21], gfx_addr[3], gfx_addr[20:4], gfx_addr[2:0] };
        int kx = (k>>1)  | ((k&1)<<17);
        io[kx]=copy[k];
    }
    delete[] copy;
}

void clear_bank( char *data ) {
    const int v = ~0;
    int *b = (int*)data;
    for( int k=0; k<BANK_LEN; k+=sizeof(int) ) *b++=v;
}

void dump_bank( char *data, const char *fname ) {
    string fullname(fname);
    ofstream fout(fullname+".hex");
    if( !fout.good() ) throw "Cannot open output hex file\n";
    for( int k=0; k<BANK_LEN; k+=2 ) {
        int a = data[k+1];
        int b = data[k];
        a&=0xff;
        b&=0xff;
        a = (a<<8) | b;
        //fout << hex << setw(4) << setfill('0') << a << '\n';
        fout << hex << setw(4) << setfill('0') << a;
        if( (k&0xe) == 0xe )
            fout << '\n';
        else
            fout << ' ';
    }
    fout.close();
    // Binary file
    fout.open(fullname+".bin");
    fout.write(data,BANK_LEN );
}

void read_bank(char *data, ifstream& fin, int start, int end, int offset ) {
    const int header_size = 64;
    start += header_size;
    if( end )
        end += header_size;
    else {
        fin.seekg(0,ios_base::end);
        end = (int) fin.tellg();
    }
    fin.seekg( start, ios_base::beg );
    if( fin.eof() ) throw "input file reached EOF";
    if( !fin.good() ) throw "Cannot seek inside input file";
    const int len=end-start;
    if( len <=0 ) throw "Wrong offsets";
    data += offset;
    fin.read(data,len);
    fin.clear();
}

void dump_cfg( char header[64]) {
    ofstream fout("cps_cfg.hex");
    for( int k=0x27; k>=0x10; k-- ) {
        int j = header[k];
        j&=0xff;
        fout << "8'h" << hex << j;
        if( k!=0x10 ) fout << ',';
    }
}

void dump_kabuki( char header[64]) {
    ofstream fout("kabuki.hex");
    for( int k=0x30; k<=0x3a; k++ ) {
        int j = header[k];
        j&=0xff;
        fout << hex << setw(2) << setfill('0') << j;
    }
    fout << '\n';
}

void dump_qsnd( char *data ) {
    ofstream flsb("qsnd_lsb.hex");
    ofstream fmsb("qsnd_msb.hex");
    for( int k=0; k<0x2000; ) {
        int d;
        d = data[k++];
        flsb << hex << (d&0xff) << '\n';
        d = data[k++];
        fmsb << hex << (d&0xff) << '\n';
    }
}

void read_vram( char *data, const string& game, const string& scene,
                const char *fn, int offset, int len ) {
    string vram_name = (game +"/")+(fn+scene)+".bin";
    ifstream fin( vram_name, ios_base::binary );
    if( fin ) {
        offset <<=1;
        fin.read( data+offset, len*1024 );
        char *b = data+offset;
        for( int k=0; k<len*1024; k+=2 ) {
            char a = b[k+0];
            b[k+0] = b[k+1];
            b[k+1] = a;
        }
    } else {
        printf("Error: cannot open file %s", vram_name.c_str());
    }
}

void cps2split( char *buf, const string name, int start ) {
    string fname = name + ".bin";
    ofstream fout( fname, ios_base::binary );
    char *aux = new char[2*1024];
    char *p=aux;
    for( int k=start; k<8*1024; k+=8 )
        *p++ = buf[k];
    fout.write( aux, 2*1024 );
    delete []aux;
}

void dump_cps2obj( const string& game, const string& scene ) {
    char *buf = new char[4096*2];
    string fname = game + "/obj" + scene + ".bin";
    ifstream fin( fname, ios_base::binary );
    if( fin ) {
        fin.read( buf, 8*1024 );
        // reverse order
        for( int k=0; k<8*1024; k+=2 ) {
            char x   = buf[k];
            buf[k]   = buf[k+1];
            buf[k+1] = x;
        }
        // split data in 4 files
        cps2split( buf, "objx_lo",    0 );
        cps2split( buf, "objx_hi",    1 );
        cps2split( buf, "objy_lo",    2 );
        cps2split( buf, "objy_hi",    3 );
        cps2split( buf, "objcode_lo", 4 );
        cps2split( buf, "objcode_hi", 5 );
        cps2split( buf, "objattr_lo", 6 );
        cps2split( buf, "objattr_hi", 7 );
    } else {
        printf("Error: cannot open file %s", fname.c_str());
    }
    delete []buf;
}