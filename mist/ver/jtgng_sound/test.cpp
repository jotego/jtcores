#include "Vjtgng_sound.h"
#include "verilated_vcd_c.h"
#include <fstream>
#include <iostream>

using namespace std;

const int PERIOD = 1e9/6e6; // 6MHz in ns
const int SEMIPERIOD = PERIOD/2; // 6MHz in ns
const int CLKSTEP = PERIOD/4; // 6MHz in ns

vluint64_t main_time = 0;

double sc_time_stamp () {      // Called by $time in Verilog
   return main_time;
}

class Sim {
    Vjtgng_sound *top;
    VerilatedVcdC* vcd;
    int rom_addr, rom_cs, rom_dout;
    void apply();
    void get();
    char *rom;
    bool trace, toggle;
    vluint64_t main_next;
    int frame_vh; // 0xffff0000 -> frame count
                  // 0x0000ff00 -> Vertical count
                  // 0x000000ff -> Horizontal count
public:
    int clk, rst, soft_rst, sres_b, snd_latch, V32;
    int cen3, cen1p5, ym_snd;

    Sim(bool _trace);
    ~Sim();
    Vjtgng_sound* Top() { return top; }
    bool next();
    void reset(int cnt);
    vluint64_t get_time() { return main_time; }
    bool next_quarter();
};

vluint64_t ms2ns(vluint64_t val) { val*=1000'000; return val; }

/////////////////////////////////////////////
int main(int argc, char *argv[]) {try{
    vluint64_t sim_time = ms2ns(2500);
    bool trace=false;
    for( int k=1; k<argc; k++) {
        if( strcmp(argv[k], "-trace")==0 ) { trace=true; continue; }
        if( strcmp(argv[k], "-time")==0 ) {
            int ms;
            sscanf( argv[++k], "%d", &ms );
            sim_time = ms2ns(ms);
            continue; 
        }
        cout << "Unknown argument: " << argv[k] << '\n';
        return 1;
    }
    Sim sim(trace);
    sim.reset(512);
    bool zeros=true;
    vluint64_t aux_time;

    aux_time = main_time + ms2ns(1);
    cout << "Start up after reset (" << aux_time << ")\n";
    while( main_time < aux_time ) sim.next();
    cout << "Send latch info\n";
    sim.snd_latch = 0x30; // Map music
    sim.V32 = 0;
    sim_time += main_time;

    Vjtgng_sound* top = sim.Top();
    while( main_time < sim_time ) {
        sim.next();
    }

    return 0;

} catch(int i) { return i;}}

//////////////////////////////////////////////

Sim::Sim(bool _trace=false) : trace(_trace) {
    ifstream f("../../../rom/mm02.14h", ios_base::binary);
    if( !f.good() ) {
        cerr << "Cannot find file mm02.14h\n";
        throw 1;
    }
    top = new Vjtgng_sound;
    rom = new char[32*1024];
    f.read(rom, 32*1024 );
    if( f.gcount()!=32*1024 ) {
        cerr << "File mm02.14h does not have the expected size.\n";
        throw 1;
    }
    vcd = new VerilatedVcdC;
    if( trace ) {
        Verilated::traceEverOn(true);
        top->trace(vcd,99);
        vcd->open("test.vcd"); 
    }  
    toggle = false; main_next=0;
    cen1p5 = 1;
    cen3   = 1;
    frame_vh = 0;
}

Sim::~Sim() {
    delete top; top=NULL;
    delete vcd; vcd=NULL;
    delete rom; rom=NULL;
}

void Sim::apply() {
    top->snd_latch  = snd_latch;
    top->V32        = V32;
    top->rom_dout   = rom_cs ? rom[rom_addr&0x7fff] : 0;
    top->clk        = clk;
    top->cen3       = cen3;
    top->cen1p5     = cen1p5;
    // reset signals
    top->sres_b     = sres_b;
    top->rst        = rst;
    top->soft_rst   = soft_rst;
}

void Sim::get() {
    ym_snd    = top->ym_snd;
    rom_cs    = top->rom_cs;
    rom_addr  = top->rom_addr;
}

bool Sim::next() {
    apply();
    top->eval();
    get();
    if(trace) vcd->dump( get_time() );
    bool toggle = next_quarter();
    if( toggle ) {
        clk = 1-clk;
        if( !clk ) {
            cen1p5 = 1-cen1p5;
        }
        frame_vh++;
    }
    V32 = (frame_vh&0xff00)==0x2000;
    return toggle;
}

void Sim::reset(int cnt) {
    sres_b      = 1;
    soft_rst    = 0;
    rst         = 1;
    clk         = 0;
    V32         = 1;
    while( cnt-- ) next();
    rst = 0;
    next();
}

bool Sim::next_quarter() {
    if( !toggle ) {
        main_next = main_time + SEMIPERIOD;
        main_time += CLKSTEP;
        toggle = true;
        return false; // toggle clock
    }
    else {
        main_time = main_next;
        if( (frame_vh & 0x3ffff) == 0 ) { // A dot per every 4 frames
            cerr << '.';
        }
        toggle=false;
        return true; // do not toggle clock
    }
}