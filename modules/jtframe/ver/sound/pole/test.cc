#include "Vtest.h"
#include <cstdio>
#include <cmath>
#include "verilated_vcd_c.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

using namespace std;

int t=0;
Vtest *dut;
VerilatedVcdC *tfp;
bool keep=false;
vluint64_t simtime=0;

int scale=0x7fff; // 16 bit maximum
float fs =192000;      // sampling frequency
int   WA =(1<<15)-1;
const vluint64_t half_period = 1.0/fs*1e12/4.0;

// 1st order low pass filter
// Omega C -> Oc=tan(pi*fc/fs)
// b0 = b1 = Oc/(1+Oc)
//      a1 = (1-Oc)/(1+Oc)
// This is equivalent to b0=b1=Oc, a1=(1-Oc)
int calc_a(float fc) {
    float pi = 3.14159265;
    float wc = tan(pi*fc/fs); // Omega C with prewarp
    return (int)(WA*(1.0-wc)/(wc+1.0)); // change sign
}

// time argument in microseconds
int clk(float freq, float time) {
    static unsigned ticks=0;
    const float pi2 = 6.283185307;
    float w = freq*pi2/fs;
    int max=0,min=0;
    bool first=true;
    float fperiod=1e12/freq;
    int kmax=time*1e6/(half_period*2.0);
    for( int k=0; k<(kmax<<1); k++ ) {
        dut->clk=k&1;
        if( k&1 ) {
            dut->sample = 1-dut->sample;
            if( dut->sample ) {
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
        if(keep) tfp->dump(simtime);
    }
    return (max-min)/2;
}

void reset() {
    dut->rst=1;
    dut->sample=0;
    dut->sin=0;
    dut->a=0;
    clk(10,1.0);
    dut->rst=0;
}

#define LEN(a) (sizeof(a)/sizeof(a[0]))

int main(int argc, char *argv[]) {
    for(int k=argc-1;k>0;k--) {
        if(strcmp(argv[k],"-w")==0) {
            printf("Keeping waveforms\n");
            keep=true;
            continue;
        }
        sscanf(argv[k],"%d",&WA);
        printf("WA=%d\n",WA);
    }

    VerilatedContext context;
    context.commandArgs(argc, argv);
    dut = new Vtest(&context);
    tfp = new VerilatedVcdC;

    if(keep) {
        dut->trace(tfp,99);
        Verilated::traceEverOn(true);
        tfp->open("test.vcd");
        reset();
    }
    reset();

    FILE *f=fopen("test.csv","w");

    float cutoffs[5]={100,1000,2000,5000,10000};
    float freqs[]={10,20,50,100,200,500,1000,2000,5000,10000,20000};
    int amplitudes[]={0x01f,0x1ff,0x7fff};
    // header
    fprintf(f,"input,cut-off");
    for( int cont=0;cont<11;cont++) fprintf(f,",%.1f",freqs[cont]);
    // body
    for( int ck=0; ck<LEN(cutoffs);ck++)
    for( int ak=0; ak<LEN(amplitudes); ak++ )  {
        scale=amplitudes[ak];
        dut->a = calc_a(cutoffs[ck]);
        fprintf(f,"\n%d,%.0f",scale,cutoffs[ck]);
        for( int cont=0;cont<11;cont++) {
            float freq=freqs[cont];
            // reference values for VCD file
            dut->cutoff=cutoffs[ck];
            dut->freq=freq;
            dut->amplitude=amplitudes[ak];
            // actual data
            clk(freq,10e3);
            int amp = clk(freq,1.0e6/freq*5*log10(freq));
            float gain=20.0*log10(float(amp)/float(scale));
            fprintf(f,",%.1f",gain);
        }
    }
    fprintf(f,"\n");
    if(keep) {
        tfp->close();
    }
    delete dut;
    delete tfp;
    fclose(f);
    return 0;
}