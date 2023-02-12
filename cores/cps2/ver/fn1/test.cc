#include "Vjtcps2_fn1.h"
#include "cps2crypt.h"

#include <cstdio>
#include <cstring>

using namespace std;

class DUT {
public:
    Vjtcps2_fn1 sbox;
    int eval( int din, uint64_t key );
};

int main( int argc, char *argv[] ) {
    DUT dut;
    struct optimised_sbox sboxes1[4*4];
    int good=0;

    optimise_sboxes(&sboxes1[0*4], fn1_r1_boxes);
    optimise_sboxes(&sboxes1[1*4], fn1_r2_boxes);
    optimise_sboxes(&sboxes1[2*4], fn1_r3_boxes);
    optimise_sboxes(&sboxes1[3*4], fn1_r4_boxes);

    for( int cnt=0; cnt<1'000'000; cnt++ ) {
        uint64_t k=0;
        for( int j=0; j<4; j++ ) {
            k |= rand();
            k <<= 16;
        }

        dut.eval( 0, k );

        uint32_t key1[4];
        uint32_t master_key[2];
        master_key[1] = (k>>32)&0xffff'ffff;
        master_key[0] = k&0xffff'ffff;
        // expand master key to 1st FN 96-bit key
        expand_1st_key(key1, master_key);

        // add extra bits for s-boxes with less than 6 inputs
        key1[0] ^= BIT(key1[0], 1) <<  4;
        key1[0] ^= BIT(key1[0], 2) <<  5;
        key1[0] ^= BIT(key1[0], 8) << 11;
        key1[1] ^= BIT(key1[1], 0) <<  5;
        key1[1] ^= BIT(key1[1], 8) << 11;
        key1[2] ^= BIT(key1[2], 1) <<  5;
        key1[2] ^= BIT(key1[2], 8) << 11;

        if( key1[0] != dut.sbox.jtcps2_fn1__DOT__key1 ||
            key1[1] != dut.sbox.jtcps2_fn1__DOT__key2 ||
            key1[2] != dut.sbox.jtcps2_fn1__DOT__key3 ||
            key1[3] != dut.sbox.jtcps2_fn1__DOT__key4
            ) {
            printf("Key1 %05X <> %05X\n", key1[0], dut.sbox.jtcps2_fn1__DOT__key1 );
            printf("Key2 %05X <> %05X\n", key1[1], dut.sbox.jtcps2_fn1__DOT__key2 );
            printf("Key3 %05X <> %05X\n", key1[2], dut.sbox.jtcps2_fn1__DOT__key3 );
            printf("Key4 %05X <> %05X\n", key1[3], dut.sbox.jtcps2_fn1__DOT__key4 );
            goto finish;
        }
        for( int a=0; a<0x1'0000; a++ ) {
            int ref_out = feistel(a, fn1_groupA, fn1_groupB,
                    &sboxes1[0*4], &sboxes1[1*4], &sboxes1[2*4], &sboxes1[3*4],
                    key1[0], key1[1], key1[2], key1[3]);
            int dut_out = dut.eval( a, k );
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


int DUT::eval( int din, uint64_t key ) {
    sbox.din = din;
    sbox.key = key;
    sbox.clk=0;
    sbox.eval();
    sbox.clk=1;
    sbox.eval();
    return sbox.dout;
}