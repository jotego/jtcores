#include <iostream>
#include <cstdlib>
#include <sstream>
#include <fstream>
#include <iomanip>
#include <string>
#include "Vtest.h"
#include "trace.h"

#ifdef TRACE
#include "verilated_vcd_c.h"
#else
class VerilatedVcdC {

};
#endif


using namespace std;

class Wrapper {
    int    screen[256][224];
    int*   rom;
    int    hcnt,vcnt, LHBL, LVBL, last_LHBL, last_LVBL;
    int    pxl_cen, bus_req, blen, obj_AB;
    int    frame_cnt, last_obj_addr, ok_cnt;
    Vtest* top;
    VerilatedVcdC* tfp;
    vluint64_t sim_time, sim_step;

    void advance();
    void dma_cycle();
    void eval();
    void load_palette( const char *name, int pos );
public:
    int    fail_trip;
    int    cpu_mem[512];
    Wrapper( Vtest* t, VerilatedVcdC* vcd );
    ~Wrapper();
    void frame();
    void reset();
    void random(int cnt);
    void save_raw();
    void set_obj( int k, int id, int attr, int x, int y ) {
        k <<= 2;
        cpu_mem[k]   = id;
        cpu_mem[k+1] = attr;
        cpu_mem[k+2] = y;
        cpu_mem[k+3] = x;
    }
};

int main(int argc, char *argv[]) {
    Vtest *top = new Vtest();
    VerilatedVcdC* tfp = new VerilatedVcdC;
    string vcdname("test.vcd");
    for( int k=1; k<argc; k++ ) {
        if( strcmp(argv[k],"-w")==0 ) {
            k++; 
            if(k>=argc) {
                cerr << "ERROR: expecting filename after -w\n";
                return 1;
            }
            vcdname=argv[k];
            continue;
        }
        cerr << "ERROR: unexpected argument " << argv[k] << '\n';
        return 1;
    }
#ifdef TRACE
    bool trace=true;
    if( trace ) {
        Verilated::traceEverOn(true);
        top->trace(tfp,99);
        tfp->open(vcdname.c_str());
    }
#endif
    try {
        Wrapper wrap(top, tfp);
        wrap.reset();
        //for( int k=0; k<128; k++ ) {
        //    wrap.set_obj(k, 0x88, 0x2<<5, rand()%256, rand()%240 );
        //}
        int attr = (0x2<<5) | 2;
        //wrap.set_obj(1, 0x88, attr, 0x4A, 0x80 );

        //wrap.random(40);
        wrap.fail_trip = 0;
        for(int k=0; k<32; k++ ) {
            wrap.set_obj(k, 0x88, attr, k*5, 100+(k&0x3) );
            //for( int j=0; j<512; j+=4 ) {
            //    wrap.cpu_mem[j+3]++;
            //}
            wrap.frame();
            wrap.save_raw();
            cout << '.';
            cout.flush();
        }
    } catch(int i ) { cerr << "ERROR #" << i << '\n'; }
    cout << '\n';
    delete tfp; tfp=0;
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
    if( obj_addr != last_obj_addr ) {
        if( (rand()%100) < fail_trip ) {
            top->obj_ok = 0;
            ok_cnt = rand()%32;
        }
    }
    if( obj_addr == last_obj_addr && --ok_cnt<0 ) {
        top->obj_ok = 1;
    }
    last_obj_addr = obj_addr;
    obj_addr += 0x4'C000;
    obj_data = rom[obj_addr];
    top->obj_data = obj_data;
    sim_time += sim_step;
    #ifdef TRACE
    tfp->dump( sim_time );
    #endif
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
            //if( (pxl&0xf)==0xf  ) pxl=0xff;
            screen[hcnt][vcnt]= (pxl<<4)&0xff;
        }
        if( LVBL && !last_LVBL ) frame_cnt++;
        // cout << LVBL << LHBL << " - " << vcnt << " " << hcnt << '\n';
    }
}

void Wrapper::dma_cycle() {
    while( LVBL ) advance();
    top->OKOUT = 1;
    //cout << "DMA: Wait for high bus_req\n";
    while( !bus_req ) advance();
    top->bus_ack=1;
    //cout << "DMA: Wait for low bus_req\n";
    while( bus_req ) {
        top->obj_DB = cpu_mem[obj_AB]&0xff;
        advance();
    }
    top->OKOUT=0;
    top->bus_ack=0;
}

void Wrapper::frame() {
    dma_cycle();
    while( !LVBL ) advance();
    while( LVBL ) advance();
}

void Wrapper::random(int cnt=128) {
    for( int k=0; k<512/4; k++ ) {
        for( int j=0; j<4; j++ )
            cpu_mem[k+j] = k < cnt ? rand()%256 : 0xf8;
    }
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
    load_palette( "../../../rom/1943/bm7.7c",2 );
    load_palette( "../../../rom/1943/bm8.8c",1 );
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

Wrapper::Wrapper( Vtest* t, VerilatedVcdC* vcd ) : top(t), tfp(vcd) { 
    LVBL=1; 
    LHBL=1; 
    fail_trip = 0;
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
    // simulation time
    sim_time = 0;
    float step = 1/48e6/2*1e9;
    sim_step = step;
}

Wrapper::~Wrapper() {
    delete []rom;
    rom=0;
}
