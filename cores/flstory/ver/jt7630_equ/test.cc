#include "Vjt7630_equ.h"
#include <cstdio>
#include <cmath>
#include "verilated_vcd_c.h"

using namespace std;

int t=0;
Vjt7630_equ *dut;
VerilatedVcdC *tfp;

vluint64_t simtime=0;

const int scale=0xfff;
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
const float freqs[]={10,20,50,100,200,500,1000,2000,5000,10000,20000};

const vluint64_t half_period = 1.0/fs*1e12/4.0;

struct Outputs {
    float gain[5];
    int16_t max[5],min[5];
    void CalcGain() {
        for(int k=0;k<5;k++) {
            gain[k]=20.0*log10(float(max[k]-min[k])/2.0/float(scale));
        }
    }
    void UpdateMaxMin( int k, int16_t val, bool init ) {
        if(k>3 || k<0) return;
        if(val>max[k]||init) max[k]=val;
        if(val<min[k]||init) min[k]=val;
    }
};


void clk(float freq, int kmax, Outputs *data ) {
    static unsigned ticks=0;
    float w = freq*pi2/fs;
    bool first=true;
    for( int k=0; k<(kmax<<1); k++ ) {
        dut->clk=k&1;
        if( (k&1)==0 ) {
            dut->cen48k = 1-dut->cen48k;
            if( dut->cen48k==0 ) {
                dut->sin=scale*sin( w * t );
                ++t;
                if(data==NULL) continue;
                // convert to 16 bit signed integer
                data->UpdateMaxMin(0,dut->lopass0,first);
                data->UpdateMaxMin(1,dut->lopass1,first);
                data->UpdateMaxMin(2,dut->hipass0,first);
                data->UpdateMaxMin(3,dut->hipass1,first);
                data->UpdateMaxMin(4,dut->sout,   first);
                first=false;
            }
        }
        simtime += half_period;
        dut->eval();
        tfp->dump(simtime);
    }
}

void reset() {
    dut->rst=1;
    dut->cen48k=0;
    dut->sin=0;
    clk(10,4,NULL);
    dut->rst=0;
}

typedef float t_sweep[12];

void sweep(Outputs *data) {
    for( int cont=0;cont<11;cont++) {
        float freq=freqs[cont];
        clk(freq,19200,NULL);
        clk(freq,19200*3,data);
        if(data!=NULL) {
            data->CalcGain();
            data++;
        }
    }
}

void save_csv(FILE *f) {
    const int steps=sizeof(freqs)/sizeof(float);
    const char *names[5]={"lo0","lo1","hi0","hi1","all"};
    Outputs *data=new Outputs[steps];
    sweep(data);
    for(int output=0;output<5;output++) {
        fprintf(f,"%s %d%d,",names[output],dut->lo_setting,dut->hi_setting);
        for(int freq=0;freq<steps;freq++) {
            if(freq!=0) fprintf(f,",");
            fprintf(f,"%.1f",data[freq].gain[output]);
        }
        fprintf(f,"\n");
    }
    delete data;
}

int main(int argc, char *argv[]) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    dut = new Vjt7630_equ(&context);
    dut->lo_setting=8;
    dut->hi_setting=8;
    tfp = new VerilatedVcdC;

    bool lo=false, hi=false, keep=false;
    for(;argc>1;) {
        argc--;
        if( strcmp(argv[argc],"-w")==0 ) { keep=true; continue; }
        if(!hi) { dut->hi_setting = atoi(argv[argc]); hi=true; continue; }
        if(!lo) { dut->lo_setting = atoi(argv[argc]); lo=true; continue; }
        printf("Too many arguments\n");
        return 1;
    }
    dut->trace(tfp,99);
    if(keep) {
        Verilated::traceEverOn(true);
        tfp->open("test.vcd");
    }
    reset();

    if (lo || hi ) {
        // printf("lo=%d\thi=%d\n",dut->lo_setting, dut->hi_setting);
        // sweep(NULL,0);
        printf("Unsupported\n");
    } else {
        FILE *f=fopen("equ.csv","w");
        fprintf(f,"name,10,20,50,100,200,500,1000,2000,5000,10000,20000\n");

        save_csv(f);

        // dut->hi_setting=0;
        // for( dut->lo_setting=0; dut->lo_setting<16;dut->lo_setting++ ) save_csv(f);
        // dut->lo_setting=0;
        // for( dut->hi_setting=0; dut->hi_setting<16;dut->hi_setting++ ) save_csv(f);
        // dut->lo_setting=8; dut->hi_setting=8; save_csv(f);
        fclose(f);
    }
    if(keep) tfp->close();
    delete dut;
    delete tfp;
    return 0;
}