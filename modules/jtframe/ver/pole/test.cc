#include "Vjtframe_pole.h"
#include <cstdio>
#include <cmath>
#include "verilated_vcd_c.h"

using namespace std;

Vjtframe_pole dut;
VerilatedVcdC tfp;
int t=0;

const int scale=8191;
const float fs= 6000*4;//*1.23;
const float pi2=6.28318507;
const float w = pi2*7700/fs;
const int a = 104;

// a =114 for 6000*4
// a

void clk(int kmax) {
    static unsigned ticks=0;
    for( int k=0; k<(kmax<<1); k++ ) {
        dut.clk=k&1;
        if( k&1 ) {
            dut.sample = 1-dut.sample;
            if( dut.sample ) {
                dut.sin=scale*sin( w * t );
                ++t;
            }
        }
        dut.eval();
        tfp.dump(ticks++);
    }
}

void reset() {
    dut.rst=1;
    dut.sample=0;
    dut.sin=0;
    dut.a=a;
    clk(4);
    dut.rst=0;
}

int main() {
    dut.trace(&tfp,99);
    Verilated::traceEverOn(true);
    tfp.open("test.vcd");
    reset();
    int16_t ideal=0;

    int16_t max_y=0, max_x=0;

    printf("a=%d\n",a);
    for( int k=0; k<fs; k++ ) {
        clk(2);
        int16_t x = dut.sin;
        int16_t y = dut.sout;
        ideal = a*ideal+(127-a)*x;
        if( ideal>max_y ) max_y=ideal;
        if( x>max_x ) max_x=x;
       // printf("%4d ||| %6d - %6d  <> %6d\n",t,x,y,ideal);
    }
    float gain=max_y;
    gain/=max_x;
    printf("Gain = %f\n",gain);

    return 0;
}