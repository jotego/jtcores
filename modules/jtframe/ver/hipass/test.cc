#include "Vjtframe_hipass.h"
#include <cstdio>
#include <cmath>
#include "verilated_vcd_c.h"

using namespace std;

int t=0;
Vjtframe_hipass *dut;
VerilatedVcdC *tfp;

vluint64_t simtime=0;

const int scale=0x7fff; // 16 bit maximum
const float fs =192000;      // sampling frequency
const float fc = 100;
const float pi2=6.28318507;
const int    W = 14;
// 100Hz
// const int    b = 0.998366*(1<<W);
// const int    a = 0.996732*(1<<W);
// 1kHz
const int    b = 0.98390*(1<<W);
const int    a = 0.96780*(1<<W);

const vluint64_t half_period = 1.0/fs*1e12/4.0;

int clk(float freq, int kmax) {
    static unsigned ticks=0;
    float w = freq*pi2/fs;
    int max=0,min=0;
    bool first=true;
    for( int k=0; k<(kmax<<1); k++ ) {
        dut->clk=k&1;
        if( (k&1)==0 ) {
            dut->sample = 1-dut->sample;
            if( dut->sample==0 ) {
                dut->sin=scale*sin( w * t );
                // convert to 16 bit signed integer
                int16_t sout = dut->sout;
                if(sout>max||first) max=sout;
                if(sout<min||first) min=sout;
                first=false;
                ++t;
            }
        }
        simtime += half_period;
        dut->eval();
        tfp->dump(simtime);
    }
    return (max-min)/2;
}

void reset() {
    dut->rst=1;
    dut->sample=0;
    dut->sin=0;
    dut->a=a;
    dut->b=b;
    clk(10,4);
    dut->rst=0;
}

int main(int argc, char *argv[]) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    dut = new Vjtframe_hipass(&context);
    tfp = new VerilatedVcdC;

    dut->trace(tfp,99);
    Verilated::traceEverOn(true);
    tfp->open("test.vcd");
    reset();

    printf("a=%d\tb=%d\n",a,b);
    float freqs[]={10,20,50,100,200,500,1000,2000,5000,10000,20000};
    for( int cont=0;cont<11;cont++) {
        float freq=freqs[cont];
        clk(freq,19200);
        int max = clk(freq,19200*3);
        float gain=20.0*log10(float(max)/float(scale));
        printf("%5.0f Hz\t%.1f dB\t(%4d)\n",freq,gain,max);
    }
    tfp->close();
    delete dut;
    delete tfp;
    return 0;
}