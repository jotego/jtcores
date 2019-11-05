#include <iostream>
#include <cstdlib>
#include <sstream>
#include <fstream>
#include <iomanip>
#include <string>
#include "Vtest.h"

using namespace std;

class Wrapper {
    int    screen[256][224];
    int*   rom;
    int    hcnt,vcnt, LHBL, LVBL, last_LHBL, last_LVBL;
    int    pxl_cen, bus_req, blen, obj_AB;
    int    frame_cnt;
    Vtest* top;

    void advance();
    void dma_cycle();
    void eval();
    void load_palette( const char *name, int pos );
public:
    int8_t cpu_mem[512];
    Wrapper( Vtest* t );
    ~Wrapper();
    void frame();
    void reset();
    void random();
    void save_raw();
};

int main(int argc, char *argv[]) {
    Vtest *top = new Vtest();
    try {
        Wrapper wrap(top);
        wrap.reset();
        wrap.cpu_mem[0]=4;
        wrap.cpu_mem[2]=0x80;
        wrap.cpu_mem[3]=0x80;

        wrap.random();
        for(int i=0; i<5; i++ ) {
            for( int j=0; j<512; j+=4 ) {
                wrap.cpu_mem[j+3]++;
            }
            wrap.frame();
            wrap.save_raw();
            cout << '.';
        }
    } catch(int i ) { }
    cout << '\n';
    delete top; top=0;
    return 0;
}

void Wrapper::save_raw() {
    stringstream s;
    s << "obj_" << frame_cnt << ".raw";
    ofstream of(s.str(),ios_base::binary);
    for( int c=0; c<224; c++ )
        for(int r=0; r<256; r++ ) {
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
    int     obj_data;
    int     obj_addr = top->obj_addr;
    obj_addr += 0x4'C000;
    obj_data = rom[obj_addr];
    top->obj_data = obj_data;
    top->obj_ok   = 1;
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
        if( LHBL && LVBL && vcnt<224 ) {
            int pxl = top->obj_pxl;
            screen[hcnt][vcnt]= (pxl<<4) | pxl;
        }
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

void Wrapper::frame() {
    while( !LVBL ) advance();
    while( LVBL ) advance();
}

void Wrapper::random() {
    for( int k=0; k<512; k++ ) {
        cpu_mem[k] = rand()%256;
    }
    dma_cycle();
    frame();
}

void Wrapper::reset() {
    top->rst = 1;
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
    top->flip       = 0;
    for( int i=0; i<10; i++ ) {
        advance();
    }
    top->rst=0;
    LHBL = top->LHBL;
    LVBL = top->LVBL;
    // Load the palettes
    load_palette( "../../../rom/1943/bm7.7c",1 );
    load_palette( "../../../rom/1943/bm8.8c",2 );
}

void Wrapper::load_palette( const char *name, int pos ) {
    ifstream pal(name);
    top->prom_hi_we = (pos&2)>>1;
    top->prom_lo_we = pos&1;
    if( pal.bad() || pal.eof() ) {
        cerr << "ERROR: cannot read palette file\n";
        throw 1;
    }
    char *buf = new char[256];
    pal.read( buf, 256 );
    for( int k=0; k<256; k++ ) {
        top->prog_addr  = k;
        top->prog_din   = buf[k]&0xf;
        advance();
        advance();
    }
    top->prom_hi_we = 0;
    top->prom_lo_we = 0;
}

Wrapper::Wrapper( Vtest* t ) : top(t) { 
    LVBL=1; 
    LHBL=1; 
    frame_cnt=0; 
    rom = new int[20971520];
    ifstream fin("../game/sdram.hex");
    if( fin.bad() || fin.eof() ) {
        cerr << "ERROR: cannot load ../game/sdram.hex";
        throw 1;
    }
    int k;
    for( k=0; k<20'971'520 && !fin.eof(); k++ ) {
        string s;
        fin >> s;
        if( s =="xxxx" ) {
            rom[k] = 0xffff;
        }
        else {
            stringstream ss(s);
            ss >> hex >> rom[k];
        }
    }
    cout << "Read " << k << " words of ROM\n";
    for( int k=0; k<512; k++ ) cpu_mem[k]=0xf8;
}

Wrapper::~Wrapper() {
    delete []rom;
    rom=0;
}
