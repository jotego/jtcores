#include <stdio.h>

void dump( int k, int *val ) {
    FILE *f;
    char sz[128];
    int j;
    sprintf(sz,"regs%d.hex",k+2);
    f=fopen(sz,"w");
    for( j=0; j<20; j++ ) {
        fprintf(f,"%X\n",val[j]);
    }
}


int main() {
    int val[] = {
        0x9000, 0x9080, 0x90c0, 0x9100, 0x9140, 0xffd0, 0x92, 0xffc0,
        0x0, 0xff70, 0xff56, 0x13aa, 0x3f, 0x0, 0x0, 0x800e, 0x0, 0x7c01, 0x7fff, 0x34e };
    int k;
    for( k=0; k<132; k++ ) {
        dump(k,val);
        val[10]++;
    }
    return 0;
}