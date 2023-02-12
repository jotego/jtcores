#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#include <cstring>

using namespace std;

void cpsa( ofstream& fout );

int main( int argc, char *argv[] ) {
    char cfg[256];

    if( argc!=2 ) {
        printf("Error: expecting as argument the path to the CPSB config file\n");
        printf("       cfg2mame cfg/sf2_cfg.hex -> creates regs.mame to use in MAME\n");
        return 1;
    }
    ifstream fin(argv[1]);
    if( !fin ) {
        printf("Error: cannot open file %s\n", argv[1] );
        return 1;
    }

    fin.getline( cfg, 256 );
    char *aux=strtok(cfg,"h");
    aux = strtok(NULL, "h");
    int reg_addr[32];
    int cnt=23;
    const char *names[] = {
        "ADDR ID",
        "CPSB ID",
        "mult1",
        "mult2",
        "rslt0",
        "rslt1",
        "12-layer",
        "17-prio0",
        "18-prio1",
        "19-prio2",
        "20-prio3",
        "in2",
        "in3",
        "13-pal_page",
        "layer_mask0",
        "layer_mask1",
        "layer_mask2",
        "layer_mask3"
    };
    ofstream fout("regs.mame");
    if( !fout ) {
        printf("Cannot open regs.mame for writting\n");
        return 1;
    }
    while( aux && cnt>=0 ) {
        sscanf(aux, "%X,", &reg_addr[cnt]);
        // cout << dec << cnt << " --> " << hex << reg_addr[cnt] << '\n';
        cnt--;
        aux = strtok(NULL, "h");
    }
    cpsa(fout);
    for( int k=2; k<14; k++ ) {
        if( reg_addr[k] == 0xff ) continue;
        int addr = 0x800140+reg_addr[k];
        fout << "wp " << hex << addr << ",2,w,1,{printf \"" << names[k] << " = %X\",wpdata;g}\n";
    }
    return 0;
}

void cpsa( ofstream& fout ) {
    fout <<
"wp 800100,2,w,1,{printf \"1-OBJ     base = %X\",wpdata; g}\n"
"wp 800102,2,w,1,{printf \"2-SCROLL1 base = %X\",wpdata; g}\n"
"wp 800104,2,w,1,{printf \"3-SCROLL2 base = %X\",wpdata; g}\n"
"wp 800106,2,w,1,{printf \"4-SCROLL3 base = %X\",wpdata; g}\n"
"wp 800108,2,w,1,{printf \"14-Row     base = %X\",wpdata; g}\n"
"wp 80010A,2,w,1,{printf \"5-Palette base = %X\",wpdata; g}\n"
"wp 80010C,2,w,1,{printf \"6-Scroll1 X    = %X\",wpdata; g}\n"
"wp 80010E,2,w,1,{printf \"7-Scroll1 Y    = %X\",wpdata; g}\n"
"wp 800110,2,w,1,{printf \"8-Scroll2 X    = %X\",wpdata; g}\n"
"wp 800112,2,w,1,{printf \"9-Scroll2 Y    = %X\",wpdata; g}\n"
"wp 800114,2,w,1,{printf \"10-Scroll3 X    = %X\",wpdata; g}\n"
"wp 800116,2,w,1,{printf \"11-Scroll3 Y    = %X\",wpdata; g}\n"
/*"wp 800118,2,w,1,{printf \"Star 0  X    = %X\",wpdata; g}\n"*/
/*"wp 80011a,2,w,1,{printf \"Star 0  Y    = %X\",wpdata; g}\n"*/
/*"wp 80011c,2,w,1,{printf \"Star 1  X    = %X\",wpdata; g}\n"*/
/*"wp 80011e,2,w,1,{printf \"Star 1  Y    = %X\",wpdata; g}\n"*/
"wp 800120,2,w,1,{printf \"15-Row offset   = %X\",wpdata; g}\n"
"wp 800122,2,w,1,{printf \"16-Video control= %X\",wpdata; g}\n";
}