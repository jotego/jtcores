#include "Vjtgng_sound.h"
#include "verilated_vcd_c.h"
#include <fstream>
#include <iostream>

using namespace std;

const int PERIOD = 1e9/6e6; // cen3 set to 1
const int SEMIPERIOD = PERIOD/2;
const int CLKSTEP = PERIOD/4;

vluint64_t main_time = 0;

double sc_time_stamp () {      // Called by $time in Verilog
   return main_time;
}

class Sim {
    Vjtgng_sound *top;
    VerilatedVcdC* vcd;
    int rom_addr, rom_cs, rom_dout, sample;
    void apply();
    void get();
    char *rom;
    bool trace, toggle;
    vluint64_t main_next;
    int cen_cnt, cen_ym;
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
    void set_cen_ym(int _cen_ym ) { cen_ym = _cen_ym; }
    int get_sample() { return sample; }
    int get_frame() { return frame_vh>>16; };
    void reset(int cnt);
    vluint64_t get_time() { return main_time; }
    bool next_quarter();
};

vluint64_t ms2ns(vluint64_t val) { val*=1000'000; return val; }

class WaveWritter {
    ofstream fsnd, fhex;
    bool dump_hex;
    int skip, cnt;
public:
    WaveWritter(const char *filename, int sample_rate, bool hex );
    void set_skip( int _skip ) { skip=_skip; }
    void write( int16_t snd );
    ~WaveWritter();
};


/////////////////////////////////////////////
int main(int argc, char *argv[]) {try{
    vluint64_t sim_time = ms2ns(2500);
    bool trace=false;
    int sample_skip=0, cen_ym=1, code=0x30;
    for( int k=1; k<argc; k++) {
        if( strcmp(argv[k], "-trace")==0 ) { trace=true; continue; }
        if( strcmp(argv[k], "-time")==0 ) {
            int ms;
            sscanf( argv[++k], "%d", &ms );
            sim_time = ms2ns(ms);
            continue; 
        }
        if( strcmp(argv[k], "-skip")==0 ) {
            if( sscanf( argv[++k], "%d", &sample_skip ) != 1 ) {
                cerr << "ERROR: use -skip n, to skip n samples and write the n+1.\n";
                return 1;
            }
            continue; 
        }
        if( strcmp(argv[k], "-code")==0 ) {
            if( sscanf( argv[++k], "%d", &code ) != 1 ) {
                cerr << "ERROR: use -code n, to play sound code n.\n";
                return 1;
            }
            continue; 
        }        
        if( strcmp(argv[k], "-cen")==0 ) {
            if( sscanf( argv[++k], "%d", &cen_ym ) != 1 ) {
                cerr << "ERROR: use -cen n, to skip n clock cycles and let pass the n+1 for the YM2203.\n";
                return 1;
            }
            continue; 
        }        
        cerr << "Unknown argument: " << argv[k] << '\n';
        return 1;
    }
    Sim sim(trace);
    sim.reset(512);
    sim.set_cen_ym( cen_ym );
    bool zeros=true;
    vluint64_t aux_time;
    WaveWritter wav("test.wav",41834*2,false);
    wav.set_skip(sample_skip);

    aux_time = main_time + ms2ns(1);
    cerr << "Start up after reset (" << aux_time << ")\n";
    while( main_time < aux_time ) sim.next();
    sim.V32 = 0;
    sim_time += main_time;

    Vjtgng_sound* top = sim.Top();
    bool skip_zeros=true;
    int last_sample;
    vluint64_t sample_t0=0, sample_t1=0;
    while( main_time < sim_time ) {
        sim.next();
        if( !last_sample && sim.get_sample() && !(sim.ym_snd==0 && skip_zeros)) {
            skip_zeros = false;
            wav.write( sim.ym_snd );
            sample_t0 = sample_t1;
            sample_t1 = main_time;
        }
        last_sample = sim.get_sample();
        if( sim.get_frame()==60 && sim.snd_latch==0 ) {
            sim.snd_latch=code;
            cerr << "\nSnd latch set to " << hex << sim.snd_latch << '\n';
        }
    }
    cerr <<'\n';
    if( skip_zeros )
        cerr << "WARNING: Output wave file is empty. No sound output was produced.\n";
    else {
        int sample_period = sample_t1 - sample_t0;
        if( sample_period != 0 ) {
            double sample_period_ns = sample_period * 1e-9;
            double sample_freq = 1.0/sample_period_ns;
            cerr << "Sample frequency = " << sample_freq << "Hz";
        }
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
        vcd->open("/dev/stdout"); 
    }  
    toggle = false; main_next=0;
    cen1p5 = 1;
    cen3   = 1;
    snd_latch = 0;
    V32    = 0;
    sres_b = 1;
    soft_rst = 0;
    frame_vh = 0;
    cen_cnt  = 0;
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
    sample    = top->sample;
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
            cen_cnt++;
            if(cen_cnt>=cen_ym) {
                cen1p5 = 1-cen1p5;
                cen_cnt = 0;
            }
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


void WaveWritter::write( int16_t snd ) {
    if(cnt>=skip) {
        int16_t g[2];
        g[0] = snd;
        g[1] = snd;
        fsnd.write( (char*)&g, sizeof(int16_t)*2 );
        if( dump_hex ) {
            fhex << hex << g[0] << '\n';
            fhex << hex << g[1] << '\n';
        }
        cnt=0;
    }
    else cnt++;
}

WaveWritter::WaveWritter( const char *filename, int sample_rate, bool hex ) {
    cnt = 0;
    skip = 0;
    fsnd.open(filename, ios_base::binary);
    dump_hex = hex;
    if( dump_hex ) {
        char *hexname;
        hexname = new char[strlen(filename)+1];
        strcpy(hexname,filename);
        strcpy( hexname+strlen(filename)-4, ".hex" );
        cerr << "Hex file " << hexname << '\n';
        fhex.open(hexname);
        delete[] hexname;
    }
    // write header
    char zero=0;
    for( int k=0; k<45; k++ ) fsnd.write( &zero, 1 );
    fsnd.seekp(0);
    fsnd.write( "RIFF", 4 );
    fsnd.seekp(8);
    fsnd.write( "WAVEfmt ", 8 );
    int32_t number32 = 16;
    fsnd.write( (char*)&number32, 4 );
    int16_t number16 = 1;
    fsnd.write( (char*) &number16, 2);
    number16=2;
    fsnd.write( (char*) &number16, 2);
    number32 = sample_rate; 
    fsnd.write( (char*)&number32, 4 );
    number32 = sample_rate*2*2; 
    fsnd.write( (char*)&number32, 4 );
    number16=2*2;   // Block align
    fsnd.write( (char*) &number16, 2);
    number16=16;
    fsnd.write( (char*) &number16, 2);
    fsnd.write( "data", 4 );
    fsnd.seekp(44); 
}

WaveWritter::~WaveWritter() {
    int32_t number32;
    streampos file_length = fsnd.tellp();
    number32 = (int32_t)file_length-8;
    fsnd.seekp(4);
    fsnd.write( (char*)&number32, 4);
    fsnd.seekp(40);
    number32 = (int32_t)file_length-44;
    fsnd.write( (char*)&number32, 4);   
}
