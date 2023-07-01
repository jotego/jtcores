#include <stdio.h>
#include <stdlib.h>

int fill( char *fname, int*ram);

int main(int argc, char *argv[]) {
    int ram[512];
    char *fname_def = "filter";
    char *fname = argc>1 ? argv[1] : fname_def;
    if( fill( fname, ram ) ) return 1;
    for( int j=0; j<512; j++ )
        printf("%04X\n",ram[j]&0xffff);
    return 0;
}

int fill( char *fname, int*ram ) {
    FILE *fin;
    int j=0;
    char buf[256];
    for( int k=0; k<512; k++ ) ram[k]=0;
    fin = fopen( fname ,"r" );
    if( !fin ) {
        printf("Cannot open file %s\n", fname );
        return 1;
    }
    do {
        fgets( buf, 256, fin );
    }while( buf[0]=='#' );
    do{
        int n;
        n = strtol(buf, NULL, 0);
        ram[j++] = n;
        fgets( buf, 256, fin );
    }while(!feof(fin) && j<256);
    fclose(fin);
    return 0;
}