#include "Vjtcps2_keyload.h"
#include "cps2crypt.h"

#include <cstdio>
#include <cstring>

using namespace std;

class DUT {
    Vjtcps2_keyload load;
public:
    void load_keys(char *buf);
    int64_t keys() {
        return load.key;
    }
    int upper_range() {
        return (((~load.addr_rng & 0x3ff)<<14) | 0x3fff) + 1;
    }
    int raw() {
        return load.addr_rng;
    }
};

void buffer_load( const char*, char *);
void rom_load( const char*, char *);

void shift( char *b) {
    int c=0;
    for( int j=0; j<20; j++ ) {
        int nc = (b[j]>>7)&1;
        b[j] = (b[j]<<1) | c;
        c = nc;
    }
}

int main( int argc, char *argv[] ) {
    char buf_keys[20];
    uint16_t *rom, *dec;
    DUT dut;
    MAME_keys mame_keys;
    int exit_code=0;

    rom = new uint16_t[0x20'0000];
    dec = new uint16_t[0x20'0000];
    memset( buf_keys, 0, 20 );
    buf_keys[0]=1;
    try {
        buffer_load( "spf2t/spf2t.key", buf_keys );
        rom_load("spf2t/pzf.04", (char*)rom );
        //buffer_load( "t.key", buf_keys );
        dut.load_keys( buf_keys );
        init_cps2crypt( buf_keys, mame_keys );

        printf("Upper range: %X <> %X\n", mame_keys.upper, dut.upper_range() );
        printf("range raw = %X\n", dut.raw());
        printf("%08X-%08X", mame_keys.key[1], mame_keys.key[0]);
        //for( int i=0; i<2; i++ )
        //for( int k=3; k>=0; k-- )
        //    printf("%02X", (mame_keys.key[i]>>(k<<3))&0xff );
        putchar('\n');
        printf("%016lX\n", dut.keys() );
        if( mame_keys.upper != dut.upper_range() ) {
            printf("Error: upper ranges don't match\n");
            throw 3;
        }
        // Decode some of the file
        cps2_decrypt( rom, dec,
            0x8'0000, mame_keys.key, 0, mame_keys.upper );
        for( int k=0; k<16; k++) {
            printf("%04X -> %04X\n", rom[k], dec[k]);
        }
    } catch( int e ) {
        exit_code = e;
    }

    delete []rom;
    delete []dec;
    return exit_code;
}

void rom_load( const char*fname, char *buf) {
    FILE *f = fopen(fname,"rb");
    if( f == NULL ) {
        printf("ERROR: cannot open key file %s\n", fname );
        throw 1;
    }
    int cnt = fread( buf, 1, 0x8'0000, f );
    fclose(f);
    if( cnt != 0x8'0000 ) {
        printf("ERROR: the key file %s is too short\n", fname );
        throw 2;
    }
}

void buffer_load( const char*fname, char *buf) {
    FILE *f = fopen(fname,"rb");
    if( f == NULL ) {
        printf("ERROR: cannot open key file %s\n", fname );
        throw 1;
    }
    int cnt = fread( buf, 1, 20, f );
    fclose(f);
    if( cnt != 20 ) {
        printf("ERROR: the key file %s is too short\n", fname );
        throw 2;
    }
}

void DUT::load_keys(char *buf) {
    load.clk=0;
    load.rst=1;
    load.din=0;
    load.din_we=0;
    load.eval();
    load.rst=0;
    load.eval();
    for( int k=0; k<20; k++ ) {
        load.din = buf[k];
        for( int j=0; j<4; j++ ) {
            load.din_we = (j&2) != 0;
            load.clk = j&1;
            load.eval();
        }
    }
    load.din_we=0;
    for( int j=0; j<4; j++ ) {
        load.clk=j&1;
        load.eval();
    }
}