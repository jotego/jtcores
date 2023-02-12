#include "Vjtcps2_decrypt.h"
#include "cps2crypt.h"

#include <cstdio>
#include <cstring>

using namespace std;

class DUT {
    Vjtcps2_decrypt dut;
public:
    void load_keys(char *buf);
    int dec( int addr, int din );
    // int64_t keys() {
    //     return dut.key;
    // }
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
    bool bad=false;

    rom = new uint16_t[0x20'0000];
    dec = new uint16_t[0x20'0000];
    memset( buf_keys, 0, 20 );
    buf_keys[0]=1;
    try {
        buffer_load( "spf2t/spf2t.key", buf_keys );
        rom_load("spf2t/pzfe.03", (char*)rom );
        //buffer_load( "t.key", buf_keys );
        dut.load_keys( buf_keys );
        init_cps2crypt( buf_keys, mame_keys );
        printf("%08X-%08X", mame_keys.key[1], mame_keys.key[0]);
        //for( int i=0; i<2; i++ )
        //for( int k=3; k>=0; k-- )
        //    printf("%02X", (mame_keys.key[i]>>(k<<3))&0xff );
        putchar('\n');
        //printf("%016lX\n", dut.keys() );
        //if( mame_keys.upper != dut.upper_range() ) {
        //    printf("Error: upper ranges don't match\n");
        //    printf("Upper range: %X <> %X\n", mame_keys.upper, dut.upper_range() );
        //    throw 3;
        //}
        // Decode some of the file
        cps2_decrypt( rom, dec,
            0x8'0000, mame_keys.key, 0, mame_keys.upper );
        for( int k=0; k<16; k++) {
            int dut_dec = dut.dec( k, rom[k] );
            printf("%04X -> %04X -> %04X", rom[k], dec[k], dut_dec );
            if( dut_dec != dec[k] ) {
                putchar('*');
                bad=true;
            }
            puts("");
        }
    } catch( int e ) {
        exit_code = e;
    }
    if( !bad ) puts("PASS");
    delete []rom;
    delete []dec;
    return exit_code;
}

int DUT::dec( int addr, int din ) {
    dut.clk=0;
    dut.addr = addr;
    dut.din = din;
    dut.fc=6;
    dut.dec_en=1;
    dut.eval();
    dut.clk=1;
    dut.eval();
    return dut.dout;
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
    dut.clk=0;
    dut.rst=1;
    dut.prog_din=0;
    dut.prog_we=0;
    dut.eval();
    dut.rst=0;
    dut.eval();
    for( int k=0; k<20; k++ ) {
        dut.prog_din = buf[k];
        for( int j=0; j<4; j++ ) {
            dut.prog_we = (j&2) != 0;
            dut.clk = j&1;
            dut.eval();
        }
    }
    dut.prog_we=0;
    for( int j=0; j<4; j++ ) {
        dut.clk=j&1;
        dut.eval();
    }
}