#include "Vjtgng_sound.h"
#include "verilated_vcd_c.h"
#include <fstream>

const int PERIOD = 1e9/6e6; // 6MHz in ns
const int SEMI_PERIOD = PERIOD/2; // 6MHz in ns
const int QUARTER_PERIOD = PERIOD/4; // 6MHz in ns

vluint64_t main_time = 0;

double sc_time_stamp () {      // Called by $time in Verilog
   return main_time;
}

/*
    input   clk,    // 6   MHz
    input   rst,
    input   soft_rst,
    // Interface with main CPU
    input           sres_b, // Z80 reset
    input   [7:0]   snd_latch,
    input           V32,    
    // ROM access
    output  [14:0]  rom_addr,
    output          rom_cs,
    input   [ 7:0]  rom_dout,
    input           snd_wait,
    // Sound output
    output  signed [8:0] ym_mux_right,
    output  signed [8:0] ym_mux_left,
    output  signed [11:0] fm_right,
    output  signed [11:0] fm_left,
    output  ym_mux_sample
    */

class Sim {
    Vjtgng_sound *top;
    VerilatedVcdC* vcd;
    int clk, rst, soft_rst, sres_b, snd_latch, V32;
    int fm_right, fm_left;
    int rom_addr, rom_cs, rom_dout, snd_wait;
    void apply();
    void get();
    char *rom;
    bool trace;
public:
    Sim(bool _trace);
    ~Sim();
    void reset(int cnt);
};

int main(int argc, char *argv[]) {try{
    Sim sim(true);
    sim.reset(1024);
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
        tfp->open("test.vcd"); 
    }    
}

Sim::~Sim() {
    delete top; top=NULL;
    delete vcd; vcd=NULL;
    delete rom; rom=NULL;
}

void Sim::apply() {
    top->sres_b     = sres_b;
    top->snd_latch  = snd_latch;
    top->V32        = V32;
    top->rom_dout   = rom_cs ? rom[rom_addr] : 0;
    top->snd_wait   = 0;
    top->clk        = clk;
}

void Sim::get() {
    fm_left     = top->fm_left;
    fm_right    = top->fm_right;
    rom_cs      = top->rom_cs;
    rom_addr    = top->rom_addr;
}

void reset(int cnt) {
    sres_b      = 1;
    soft_rst    = 0;
    rst         = 1;
    clk         = 0;
    V32         = 1;
    while( cnt-- ) {
        apply();
        clk = 1-clk;
    }

}