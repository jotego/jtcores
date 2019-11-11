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
    int snd, last_irq;
    char *rom2;
    Vtest* top;
    VerilatedVcdC* tfp;
    WaveWritter *ww;
    ofstream fdata;
    vluint64_t sim_time, sim_step, sample_time;

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
    int finish_time=1000;
    int code=1;
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
        if( strcmp(argv[k],"-t")==0 ) {
            k++; 
            if(k>=argc) {
                cerr << "ERROR: expecting filename after -t\n";
                return 1;
            }
            stringstream ss(argv[k]);
            ss >> finish_time;
            continue;
        }
        if( strcmp(argv[k],"-c")==0 ) {
            k++; 
            if(k>=argc) {
                cerr << "ERROR: expecting filename after -c\n";
                return 1;
            }
            stringstream ss(argv[k]);
            ss >> code;
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
        top->snd2_latch = code;
        wrap.sim(finish_time);
    } catch(int i ) { cerr << "ERROR #" << i << '\n'; }
    cout << '\n';
    delete tfp; tfp=0;
    delete top; top=0;
    return 0;
}

void Wrapper::eval() {
    top->eval();
    snd      = top->snd;
    int a = top->snd2_addr;
    top->snd2_data = rom2[a];
    sim_time += sim_step;
    #ifdef TRACE
    tfp->dump( sim_time );
    #endif
}

void Wrapper::advance() {
    top->clk = 0;
    eval();
    last_irq = top->adpcm_irq;
    top->clk = 1;
    eval();
    if( sim_time >= sample_time ) {
        int16_t lr[2];
        lr[0] = top->snd;
        lr[1] = lr[0];
        ww->write(lr);
        sample_time = sim_time + 1e9/8000;
    }
    int adpcm_irq = top->adpcm_irq;
    if( adpcm_irq && !last_irq ) {
        char data = (char)top->adpcm_din;
        fdata.write( &data, 1 );
    }
    last_irq = top->adpcm_irq;
}

void Wrapper::sim(int time) {
    vluint64_t final_time = time;
    final_time = sim_time + final_time*1000'000;
    while( sim_time < final_time ) advance();
}

void Wrapper::reset() {
    top->rst = 1;
    top->clk = 0;
    top->snd2_latch = 0;
    for( int i=0; i<10; i++ ) {
        advance();
    }
    top->rst=0;
}

Wrapper::Wrapper( Vtest* t, VerilatedVcdC* vcd ) : top(t), tfp(vcd) { 
    rom2 = new char[64*1024];
    ifstream fin("../../../rom/tora/toramich/tr_03.11j", ios_base::binary);
    fin.read(rom2,64*1024);
    // simulation time
    sim_time = 0;
    float step = 1e9/(2*48e6);
    sim_step = step;
    sample_time = 0;
    // Wave output
    ww = new WaveWritter("test.wav", 8000, false );
    // ADPCM data input
    fdata.open("adpcm_din.bin", ios_base::binary);    
}

Wrapper::~Wrapper() {
    delete []rom2; rom2=0;
    delete ww; ww=0;
}
