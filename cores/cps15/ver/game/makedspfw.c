#include <stdio.h>

int main() {
    FILE* fin=fopen("dl-1425.bin","rb");
    FILE* fmsb=fopen("dsp16fw_msb.hex","w");
    FILE* flsb=fopen("dsp16fw_lsb.hex","w");
    for( int k=0; k<4*1024; k++ ) {
        char data[2];
        fread( data, 2, 1, fin );
        fprintf(fmsb,"%02X\n",data[1]&0xff);
        fprintf(flsb,"%02X\n",data[0]&0xff);
    }
}