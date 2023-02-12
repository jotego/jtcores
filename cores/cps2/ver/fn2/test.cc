#include "Vjtcps2_fn2.h"
#include "cps2crypt.h"

#include <cstdio>
#include <cstring>

using namespace std;

class DUT {
public:
    Vjtcps2_fn2 sbox;
    int eval( int din, int key, uint64_t master_key );
};

int main( int argc, char *argv[] ) {
    DUT dut;
    struct optimised_sbox sboxes2[4*4];
    int good=0;

    optimise_sboxes(&sboxes2[0*4], fn2_r1_boxes);
    optimise_sboxes(&sboxes2[1*4], fn2_r2_boxes);
    optimise_sboxes(&sboxes2[2*4], fn2_r3_boxes);
    optimise_sboxes(&sboxes2[3*4], fn2_r4_boxes);

    for( int cnt=0; cnt<1'000'000; cnt++ ) {
        uint64_t master_key64=0;
        for( int j=0; j<4; j++ ) {
            master_key64 |= rand()&0xffff;
            master_key64 <<= 16;
        }
        int key = rand()&0xffff;

        dut.eval( 0, key, master_key64 );

        uint32_t ref_key2[4];
        uint32_t master_key[2];
        master_key[1] = (master_key64>>32)&0xffff'ffff;
        master_key[0] = master_key64&0xffff'ffff;

        // expand master key to 1st FN 96-bit key
        uint32_t ref_subkey[2];
        expand_subkey( ref_subkey, key );
        //printf("Ref subkey = %04X%04X\n", ref_subkey[1], ref_subkey[0] );
        ref_subkey[0] ^= master_key[0];
        ref_subkey[1] ^= master_key[1];
        //printf("Ref subkey ^ master key = %04X%04X\n", ref_subkey[1], ref_subkey[0] );
        expand_2nd_key( ref_key2, ref_subkey);

        // add extra bits for s-boxes with less than 6 inputs
        ref_key2[0] ^= BIT(ref_key2[0], 0) <<  5;
        ref_key2[0] ^= BIT(ref_key2[0], 6) << 11;
        ref_key2[1] ^= BIT(ref_key2[1], 0) <<  5;
        ref_key2[1] ^= BIT(ref_key2[1], 1) <<  4;
        ref_key2[2] ^= BIT(ref_key2[2], 2) <<  5;
        ref_key2[2] ^= BIT(ref_key2[2], 3) <<  4;
        ref_key2[2] ^= BIT(ref_key2[2], 7) << 11;
        ref_key2[3] ^= BIT(ref_key2[3], 1) <<  5;


        if( ref_key2[0] != (int)dut.sbox.jtcps2_fn2__DOT__key1 ||
            ref_key2[1] != (int)dut.sbox.jtcps2_fn2__DOT__key2 ||
            ref_key2[2] != (int)dut.sbox.jtcps2_fn2__DOT__key3 ||
            ref_key2[3] != (int)dut.sbox.jtcps2_fn2__DOT__key4
            ) {
            printf("Key1 %05X <> %05X\n", dut.sbox.jtcps2_fn2__DOT__key1, ref_key2[0] );
            printf("Key2 %05X <> %05X\n", dut.sbox.jtcps2_fn2__DOT__key2, ref_key2[1] );
            printf("Key3 %05X <> %05X\n", dut.sbox.jtcps2_fn2__DOT__key3, ref_key2[2] );
            printf("Key4 %05X <> %05X\n", dut.sbox.jtcps2_fn2__DOT__key4, ref_key2[3] );
            goto finish;
        }
        for( int a=0; a<0x1'0000; a++ ) {
            int ref_out = feistel(a, fn2_groupA, fn2_groupB,
                    &sboxes2[0*4], &sboxes2[1*4], &sboxes2[2*4], &sboxes2[3*4],
                    ref_key2[0], ref_key2[1], ref_key2[2], ref_key2[3]);
            int dut_out = dut.eval( a, key, master_key64 );
            if( dut_out != ref_out ) {
                printf("a=%04X -> %04X != %04X (ref)\n", a, dut_out, ref_out );
                goto finish;
            }
            good++;
        }
    }
    puts("PASS");
    finish:
    printf("%d good\n", good);
    return 0;
}


int DUT::eval( int din, int key, uint64_t master_key ) {
    sbox.din = din;
    sbox.key = key;
    sbox.master_key = master_key;
    sbox.eval();
    return sbox.dout;
}