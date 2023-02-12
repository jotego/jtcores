#include "Vjtcps2_sbox_fn1_r1.h"
#include "cps2crypt.h"

#include <cstdio>
#include <cstring>

using namespace std;

class DUT {
    Vjtcps2_sbox_fn1_r1 sbox;
public:
    int eval( int din, int key );
};

int main( int argc, char *argv[] ) {
    DUT dut;
    optimised_sbox ref[4];
    optimise_sboxes( ref, fn1_r1_boxes );
    int good=0;

    for( int k=0; k<(1<<24); k++ )
    for( int v=0; v<256; v++ ) {
        int dut_val = dut.eval( v, k);
        int ref_out=0;
        for( int j=0; j<4; j++ ) {
            int this_key = (k>>(6*j))&0x3f;
            int addr = ref[j].input_lookup[v] ^ this_key;
            ref_out |= ref[j].output[addr];
        }
        if( dut_val != ref_out ) {
            printf("%06X %2X -> %X <>", k, v, dut_val );
            printf(" %X", ref_out);
            printf("*\n");
            printf("%d correct\n", good);
            goto finish;
        }
        good++;
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