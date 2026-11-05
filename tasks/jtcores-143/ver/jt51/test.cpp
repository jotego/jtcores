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
    FILE *events=nullptr;
    FILE *bus=nullptr;
    int keyon_phase=-1;
    const char *program_kind="init";
    unsigned captured=0;
    unsigned capture_limit=0;
    unsigned sample_stride=1;
    unsigned native_phase=0;
    bool recording=false;
public:
    simulation(const std::string &csv, bool event_mode=false, unsigned stride=1, int phase=-1, bool public_bus=false)
        : keyon_phase(phase), sample_stride(stride) {
        output=std::fopen(csv.c_str(),"wx");
        if(!output) throw std::runtime_error("cannot exclusively create output CSV");
        if(event_mode) {
            events=std::fopen((csv+".events.csv").c_str(),"wx");
            if(!events) {
                std::fclose(output);
                output=nullptr;
                throw std::runtime_error("cannot exclusively create events CSV");
            }
            std::fprintf(events,"kind,clock,reg,value\n");
        }
        std::fprintf(output,"sample,left,right,xleft,xright,clock,status\n");
        if(public_bus) {
            bus=std::fopen((csv+".bus.csv").c_str(),"wx");
            if(!bus) throw std::runtime_error("cannot create public bus log");
            std::fprintf(bus,"program,kind,clock,residue,reg,value,cs_n,wr_n,a0,din,cen,cen_p1_scheduled,status\n");
        }
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
        if(events) std::fclose(events);
        if(bus) std::fclose(bus);
    }
    void step(unsigned count) {
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
            if(sample && recording && captured<capture_limit) {
                if(native_phase==0)
                    std::fprintf(output,"%u,%d,%d,%d,%d,%llu,%u\n",captured++,
                        int16_t(top.left),int16_t(top.right),int16_t(top.xleft),int16_t(top.xright),
                        static_cast<unsigned long long>(clocks),top.dout);
                native_phase=native_phase+1==sample_stride ? 0 : native_phase+1;
            }
        }
    }
    void write(uint8_t reg,uint8_t value) {
        wait_busy();
        top.a0=0; top.din=reg; top.wr_n=0; step(2);
        top.wr_n=1; step(10);
        if(keyon_phase>=0 && reg==8 && (value&0x78))
            step((unsigned(keyon_phase)+64-unsigned(clocks&63))&63);
        if(events && recording)
            std::fprintf(events,"write,%llu,%u,%u\n",
                static_cast<unsigned long long>(clocks),reg,value);
        top.a0=1; top.din=value; top.wr_n=0;
        log_bus("data_assert",reg,value); step(2);
        top.wr_n=1; log_bus("data_release",reg,value); step(2);
        wait_busy();
    }
    void log_bus(const char *kind,uint8_t reg,uint8_t value) {
        if(!bus) return;
        // This parity is scheduled for the upcoming evaluation in step().
        std::fprintf(bus,"%s,%s,%llu,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\n",program_kind,kind,
            static_cast<unsigned long long>(clocks),unsigned(clocks&63),reg,value,
            top.cs_n,top.wr_n,top.a0,top.din,top.cen,unsigned(clocks&1),top.dout);
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
            if(op==0) {
                if(pos!=bytes.size()) throw std::runtime_error("trailing program bytes");
                return;
            }
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
        capture_limit=samples;
        recording=true;
        finish_capture();
    }
    void capture_event(const std::vector<uint8_t> &event, unsigned samples) {
        step(4096);
        capture_limit=samples;
        recording=true;
        std::fprintf(events,"capture_start,%llu,,\n",
            static_cast<unsigned long long>(clocks));
        program_kind="event";
        program(event);
        finish_capture();
    }
    void finish_capture() {
        while(captured<capture_limit) step(1);
        if(bus && std::fflush(bus)) throw std::runtime_error("public bus log write failed");
        if(std::fflush(output)) throw std::runtime_error("CSV write failed");
        if(events && std::fflush(events)) throw std::runtime_error("events CSV write failed");
        std::cout<<"Captured "<<captured<<" jt51 samples\n";
    }
};

static std::vector<uint8_t> read_program(const char *path) {
    std::ifstream input(path,std::ios::binary);
    if(!input) throw std::runtime_error("cannot read monitor program");
    std::vector<uint8_t> bytes{std::istreambuf_iterator<char>(input),{}};
    if(bytes.empty() || bytes.size()>8192) throw std::runtime_error("invalid program length");
    return bytes;
}

int main(int argc,char **argv) {
    try {
        int key_phase=-1;
        bool public_bus=false;
        while(argc>1) {
            if(std::string(argv[1])=="--public-bus") {
                public_bus=true; --argc; ++argv; continue;
            }
            if(std::string(argv[1])!="--keyon-phase") break;
            if(key_phase>=0) throw std::runtime_error("duplicate key-on phase");
            if(argc<3) throw std::runtime_error("missing key-on phase");
            const std::string v=argv[2];
            if(v.empty() || v.find_first_not_of("0123456789")!=std::string::npos || std::stoull(v)>63)
                throw std::runtime_error("invalid key-on phase");
            key_phase=int(std::stoul(v)); public_bus=true; argc-=2; argv+=2;
        }
        int first=1;
        unsigned stride=1;
        if(argc>1 && std::string(argv[1])=="--stride") {
            if(argc<3) throw std::runtime_error("missing sample stride");
            const std::string value=argv[2];
            if(value.empty() || value.find_first_not_of("0123456789")!=std::string::npos)
                throw std::runtime_error("invalid sample stride");
            const auto parsed_stride=std::stoull(value);
            if(parsed_stride==0 || parsed_stride>1024)
                throw std::runtime_error("invalid sample stride");
            stride=parsed_stride;
            first=3;
        }
        const bool event_mode=argc>first && std::string(argv[first])=="--event";
        const int count_index=first+(event_mode ? 4 : 2);
        if(argc!=count_index && argc!=count_index+1)
            throw std::runtime_error("Usage: simulation [--stride N] PROGRAM CSV [SAMPLES]\n"
                "       simulation [--stride N] --event INIT EVENT CSV [SAMPLES]");
        const auto init=read_program(argv[first+(event_mode ? 1 : 0)]);
        const auto event=event_mode ? read_program(argv[first+2]) : std::vector<uint8_t>{};
        size_t parsed=0;
        const std::string count=argc==count_index+1 ? argv[count_index] : "16384";
        if(count.empty() || count.find_first_not_of("0123456789")!=std::string::npos)
            throw std::runtime_error("invalid sample count");
        const auto samples=std::stoull(count,&parsed);
        if(parsed!=count.size() || samples==0 || samples>10000000)
            throw std::runtime_error("invalid sample count");
        if(samples*stride>16777216)
            throw std::runtime_error("capture exceeds 16777216 native frames");
        simulation sim(argv[first+(event_mode ? 3 : 1)],event_mode,stride,key_phase,public_bus);
        sim.program(init);
        if(event_mode) sim.capture_event(event,samples);
        else sim.capture(samples);
    } catch(const std::exception &e) {
        std::cerr<<e.what()<<"\n";
        return 1;
    }
}
