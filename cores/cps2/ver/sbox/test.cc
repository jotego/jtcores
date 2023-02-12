#include "Vtest.h"
#include "cps2crypt.h"

#include <cstdio>
#include <cstring>

using namespace std;

class DUT {
    Vtest sbox;
public:
    int eval( int din, int key );
};

int main( int argc, char *argv[] ) {
    DUT dut;
    optimised_sbox ref[4];
    optimise_sboxes( ref, fn1_r1_boxes );

    for( int k=0; k<64; k++ )
    for( int v=0; v<256; v++ ) {
        int dut_val = dut.eval( v, k);
        int addr = ref[2].input_lookup[v] ^ k;
        int out  = ref[2].output[addr];
        //out = ((out>>3)&1) | ((out>>5)&2);
        if( dut_val != out ) {
            printf("%2X %2X -> %X <>", k, v, dut_val );
            printf(" %X", out);
            printf("*\n");
            goto finish;
        }
    }
    puts("PASS");
    finish:
    return 0;
}


int DUT::eval( int din, int key ) {
    sbox.din = din;
    sbox.key = key;
    sbox.eval();
    return sbox.dout;
}