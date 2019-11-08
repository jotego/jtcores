#include <iostream>
#include <cstdlib>
#include <sstream>
#include <fstream>
#include <iomanip>
#include <string>
#include "Vtest.h"
#include "trace.h"
#include "../../../modules/jtframe/cc/WaveWritter.hpp"

#ifdef TRACE
#include "verilated_vcd_c.h"
#else
class VerilatedVcdC {

};
#endif


using namespace std;

class Wrapper {
    int snd_addr, sample, last_sample, snd;
    char*   rom;
    Vtest* top;
    VerilatedVcdC* tfp;
    WaveWritter *ww;
    vluint64_t sim_time, sim_step;

    void advance();
    void eval();
public:
    void sim( int time );
    Wrapper( Vtest* t, VerilatedVcdC* vcd );
    ~Wrapper();
    void reset();
};

int main(int argc, char *argv[]) {
    Vtest *top = new Vtest();
    VerilatedVcdC* tfp = new VerilatedVcdC;
    string vcdname("test.vcd");
    int code=0x33;
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
        wrap.sim(1);
        top->snd_latch = code;
        wrap.sim(1000);
    } catch(int i ) { cerr << "ERROR #" << i << '\n'; }
    cout << '\n';
    delete tfp; tfp=0;
    delete top; top=0;
    return 0;
}

void Wrapper::eval() {
    top->eval();
    snd_addr = top->snd_addr;
    sample   = top->sample;
    snd      = top->snd;
    top->snd_data = rom[snd_addr];
    sim_time += sim_step;
    #ifdef TRACE
    tfp->dump( sim_time );
    #endif
}

void Wrapper::advance() {
    top->clk = 0;
    eval();
    last_sample = sample;
    top->clk = 1;
    eval();
    if( sample && !last_sample ) {
        int16_t lr[2];
        lr[0] = top->snd;
        lr[1] = lr[0];
        ww->write(lr);
    }
}

void Wrapper::sim(int time) {
    vluint64_t final_time = sim_time + time*1000'000;
    while( sim_time < final_time ) advance();
}

void Wrapper::reset() {
    top->rst = 1;
    top->clk = 0;
    top->snd_latch = 0;
    top->snd_data  = rom[0];
    for( int i=0; i<10; i++ ) {
        advance();
    }
    top->rst=0;
}

Wrapper::Wrapper( Vtest* t, VerilatedVcdC* vcd ) : top(t), tfp(vcd) { 
    rom = new char[32*1024];
    ifstream fin("../../../rom/tora/tru_05.12k",ios_base::binary);
    if( fin.bad() || fin.eof() ) {
        cerr << "ERROR: cannot load .../../../rom/tora/tru_05.12k";
        throw 1;
    }
    fin.read(rom,32*1024);
    // simulation time
    sim_time = 0;
    float step = 1/3.57e6*1e9;
    sim_step = step;
    // Wave output
    ww = new WaveWritter("test.wav", 3.57e6/6/12, false );
}

Wrapper::~Wrapper() {
    delete []rom; rom=0;
    delete ww; ww=0;
}
