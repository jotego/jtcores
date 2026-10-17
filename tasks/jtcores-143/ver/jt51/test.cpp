#include "Vjt51.h"
#include "verilated.h"
#ifdef TRACE
#include "verilated_fst_c.h"
#endif
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

class simulation {
    VerilatedContext context;
    Vjt51 top{&context};
#ifdef TRACE
    VerilatedFstC trace;
#endif
    uint64_t clocks=0;
    FILE *output=nullptr;
    unsigned captured=0;
public:
    simulation(const std::string &csv) {
        output=std::fopen(csv.c_str(),"wx");
        if(!output) throw std::runtime_error("cannot exclusively create output CSV");
        std::fprintf(output,"sample,left,right,xleft,xright,clock,status\n");
        top.clk=0; top.rst=1; top.cen=1; top.cen_p1=0;
        top.cs_n=0; top.wr_n=1; top.a0=0; top.din=0;
#ifdef TRACE
        context.traceEverOn(true);
        top.trace(&trace,99);
        trace.open("test.fst");
#endif
        step(256);
        top.rst=0;
        step(256);
    }
    ~simulation() {
        top.final();
#ifdef TRACE
        trace.close();
#endif
        if(output) std::fclose(output);
    }
    void step(unsigned count, bool record=false) {
        for(unsigned i=0;i<count;i++) {
            top.clk=0; top.cen_p1=(clocks&1); top.eval();
            bool sample=top.sample;
            context.timeInc(139665); // ps; nominal 3.58 MHz master clock
#ifdef TRACE
            trace.dump(context.time());
#endif
            top.clk=1; top.eval();
            context.timeInc(139665);
#ifdef TRACE
            trace.dump(context.time());
#endif
            clocks++;
            if(sample && record) {
                std::fprintf(output,"%u,%d,%d,%d,%d,%llu,%u\n",captured++,
                    int16_t(top.left),int16_t(top.right),int16_t(top.xleft),int16_t(top.xright),
                    static_cast<unsigned long long>(clocks),top.dout);
            }
        }
    }
    void write(uint8_t reg,uint8_t value) {
        wait_busy();
        top.a0=0; top.din=reg; top.wr_n=0; step(2);
        top.wr_n=1; step(10);
        top.a0=1; top.din=value; top.wr_n=0; step(2);
        top.wr_n=1; step(2);
        wait_busy();
    }
    void wait_busy() {
        unsigned count=0;
        while(top.dout&0x80) {
            if(++count>4096) throw std::runtime_error("jt51 busy did not clear");
            step(1);
        }
    }
    void program(const std::vector<uint8_t> &bytes) {
        size_t pos=0;
        while(pos<bytes.size()) {
            uint8_t op=bytes.at(pos++);
            if(op==0) return;
            if(op==1) {
                uint8_t reg=bytes.at(pos++),value=bytes.at(pos++);
                write(reg,value);
            } else if(op==2) {
                unsigned count=bytes.at(pos++);
                count|=unsigned(bytes.at(pos++))<<8;
                // A conservative settling interval, not calibrated CPU timing.
                step(count*32);
            } else if(op==3) {
                std::cout<<"jt51 status="<<unsigned(top.dout)<<"\n";
            } else throw std::runtime_error("invalid monitor opcode");
        }
        throw std::runtime_error("monitor program has no completion opcode");
    }
    void capture(unsigned samples) {
        while(captured<samples) step(1,true);
        if(std::fflush(output)) throw std::runtime_error("CSV write failed");
        std::cout<<"Captured "<<captured<<" jt51 samples\n";
    }
};

int main(int argc,char **argv) {
    try {
        if(argc<3 || argc>4) throw std::runtime_error("Usage: simulation PROGRAM CSV [SAMPLES]");
        std::ifstream input(argv[1],std::ios::binary);
        if(!input) throw std::runtime_error("cannot read monitor program");
        std::vector<uint8_t> bytes{std::istreambuf_iterator<char>(input),{}};
        if(bytes.empty() || bytes.size()>8192) throw std::runtime_error("invalid program length");
        unsigned samples=argc==4 ? std::stoul(argv[3]) : 16384;
        if(samples==0 || samples>10000000) throw std::runtime_error("invalid sample count");
        simulation sim(argv[2]);
        sim.program(bytes);
        sim.capture(samples);
    } catch(const std::exception &e) {
        std::cerr<<e.what()<<"\n";
        return 1;
    }
}
