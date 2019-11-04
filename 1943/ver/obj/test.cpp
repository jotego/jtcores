#include <iostream>
#include <cstdlib>
#include <sstream>
#include <fstream>
#include "Vtest.h"

using namespace std;

class Wrapper {
    int8_t cpu_mem[512];
    int    screen[256][224];
    char * rom;
    int    hcnt,vcnt, LHBL, LVBL, last_LHBL, last_LVBL;
    int    pxl_cen, bus_req, blen, obj_AB;
    int    frame_cnt;
    Vtest* top;

    void advance();
    void dma_cycle();
    void eval();
    void load_palette( const char *name );
public:
    Wrapper( Vtest* t );
    ~Wrapper();
    void reset();
    void random();
    void save_raw();
};

int main(int argc, char *argv[]) {
    Vtest *top = new Vtest();
    try {
        Wrapper wrap(top);
        wrap.reset();
        wrap.random();
        wrap.save_raw();
    } catch(int i ) { }
    delete top; top=0;
    return 0;
}

void Wrapper::save_raw() {
    stringstream s;
    s << "obj_" << frame_cnt << ".raw";
    ofstream of(s.str(),ios_base::binary);
    for(int r=0; r<256; r++ )
        for( int c=0; c<224; c++ ) {
            char rgba[4];
            rgba[0] = screen[r][c];
            rgba[1] = rgba[2] = rgba[0];
            rgba[3] = (char)0xff;
            of.write( rgba, 4 );
        }
}

void Wrapper::eval() {
    top->eval();
    LHBL    = top->LHBL;
    LVBL    = top->LVBL;
    pxl_cen = top->pxl_cen;
    bus_req = top->bus_req;
    blen    = top->blen;
    obj_AB  = top->obj_AB;
    int16_t obj_data;
    int     obj_addr;
}

void Wrapper::advance() {
    top->clk = 0;
    eval();
    last_LHBL = LHBL;
    last_LVBL = LVBL;
    top->clk = 1;
    eval();
    if( pxl_cen ) {
        if( !LHBL ) hcnt=0;
        else hcnt++;
        hcnt&=0xff;
        if( LHBL && !last_LHBL ) vcnt++;
        if( !LVBL ) vcnt=0;
        if( LHBL && LVBL && vcnt<224 ) screen[hcnt][vcnt]=top->obj_pxl;
        if( LVBL && !last_LVBL ) frame_cnt++;
        // cout << LVBL << LHBL << " - " << vcnt << " " << hcnt << '\n';
    }
}

void Wrapper::dma_cycle() {
    while( LVBL ) advance();
    top->OKOUT = 1;
    cout << "Wait for high bus_req\n";
    while( !bus_req ) advance();
    top->bus_ack=1;
    cout << "Wait for low bus_req\n";
    while( bus_req ) {
        top->obj_DB = cpu_mem[obj_AB];
        advance();
    }
    top->bus_ack=0;
}

void Wrapper::random() {
    for( int k=0; k<512; k++ ) {
        cpu_mem[k] = rand()%256;
    }
    dma_cycle();
    while( !LVBL ) advance();
    while( LVBL ) advance();
}

void Wrapper::reset() {
    top->rst = 0;
    top->clk = 0;
    top->prog_addr  = 0;
    top->prog_din   = 0;
    top->prom_hi_we = 0;
    top->prom_lo_we = 0;
    top->obj_DB     = 0;
    top->OKOUT      = 0;
    top->bus_ack    = 0;
    top->obj_data   = 0;
    top->obj_ok     = 0;
    for( int i=0; i<100; i++ ) {
        eval();
        top->clk = i%2;
    }
    LHBL = top->LHBL;
    LVBL = top->LVBL;
    // Load the palettes
    load_palette( "../../../rom/1943/bm7.7c" );
    load_palette( "../../../rom/1943/bm8.8c" );
}

void Wrapper::load_palette( const char *name ) {
    ifstream pal(name);
    if( pal.bad() || pal.eof() ) {
        cerr << "ERROR: cannot read palette file\n";
        throw 1;
    }
    for( int k=0; k<256; k++ ) {
        char c;
        pal.read( &c, 1 );
        top->prog_addr  = k;
        top->prom_hi_we = 1;
        top->prog_din   = c&0xf;
        advance();
        advance();
    }
}

Wrapper::Wrapper( Vtest* t ) : top(t) { 
    LVBL=1; 
    LHBL=1; 
    frame_cnt=0; 
    rom = new char[887808];
    ifstream fin("../../../rom/JT1943.rom");
    if( fin.bad() || fin.eof() ) {
        cerr << "ERROR: cannot load JT1943.rom";
        throw 1;
    }
    fin.read( rom, 887808 );
}

Wrapper::~Wrapper() {
    delete []rom;
    rom=0;
}
