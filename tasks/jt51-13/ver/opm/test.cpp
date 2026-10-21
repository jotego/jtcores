// Standalone API driver; no third-party emulator implementation is copied here.
#include "opm.h"
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#include <sstream>


// Driver-only input validation and timing journal; no synthesis/model arithmetic.
#include <openssl/sha.h>
#include <limits>
#include <sstream>
#include <iomanip>
#include <algorithm>
struct LoadedProgram {
    std::string path, sha256;
    std::vector<uint8_t> bytes;
    uint64_t writes=0;
};
static uint64_t natural(const std::string& text) {
    if(text.empty() || text.find_first_not_of("0123456789")!=std::string::npos)
        throw std::runtime_error("expected nonnegative integer");
    return std::stoull(text);
}
static LoadedProgram load_program(const std::string& path) {
    LoadedProgram p; p.path=path;
    std::ifstream in(path,std::ios::binary);
    if(!in) throw std::runtime_error("cannot read monitor program: "+path);
    // Bound reads as well as accepted payloads.
    char c;
    while(in.get(c)) {
        p.bytes.push_back(static_cast<uint8_t>(c));
        if(p.bytes.size()>8192) throw std::runtime_error("invalid program length");
    }
    if(!in.eof() || p.bytes.empty()) throw std::runtime_error("invalid program read/length");
    bool ended=false;
    for(size_t n=0;n<p.bytes.size();) {
        unsigned op=p.bytes[n++];
        if(op==0) { if(n!=p.bytes.size()) throw std::runtime_error("trailing program bytes"); ended=true; break; }
        if(op==1 || op==2) {
            if(p.bytes.size()-n<2) throw std::runtime_error("truncated monitor instruction");
            n+=2; if(op==1) ++p.writes;
        } else if(op!=3) throw std::runtime_error("invalid monitor opcode");
    }
    if(!ended) throw std::runtime_error("missing completion opcode");
    unsigned char digest[SHA256_DIGEST_LENGTH];
    SHA256(p.bytes.data(),p.bytes.size(),digest);
    std::ostringstream hex;
    for(auto x:digest) hex<<std::hex<<std::setw(2)<<std::setfill('0')<<unsigned(x);
    p.sha256=hex.str(); return p;
}
struct HistoryRow { LoadedProgram program; uint64_t gap; };
static std::vector<HistoryRow> read_history(const std::string& path) {
    std::ifstream in(path);
    std::string line;
    if(!in || !std::getline(in,line) || line!="program\tgap_before_master_clocks")
        throw std::runtime_error("invalid history TSV header");
    std::vector<HistoryRow> rows;
    uint64_t writes=0;
    while(std::getline(in,line)) {
        const auto tab=line.find('\t');
        if(tab==std::string::npos || tab==0 || line[0]!='/' || line.find('\t',tab+1)!=std::string::npos)
            throw std::runtime_error("history requires absolute program path and one gap column");
        const auto gap=natural(line.substr(tab+1));
        if(gap>std::numeric_limits<uint64_t>::max()/2) throw std::runtime_error("history gap overflow");
        auto p=load_program(line.substr(0,tab));
        writes+=p.writes;
        if(writes>2000000) throw std::runtime_error("whole input exceeds 2000000 writes");
        rows.push_back({std::move(p),gap});
    }
    if(!in.eof()) throw std::runtime_error("history TSV read failed");
    return rows;
}
static std::string csv_quote(const std::string& s) {
    std::string q="\"";
    for(char c:s) { q+=c; if(c=='\"') q+='\"'; }
    return q+'\"';
}

class Oracle {
    opm_t chip{};
    int32_t dac[2]{};
    uint64_t ticks = 0;
    FILE* csv = nullptr;
    FILE* events = nullptr;
    FILE* bus = nullptr;
    int keyon_phase = -1;
    const char* program_kind = "init";
    unsigned captured = 0;
    unsigned capture_limit = 0;
    unsigned sample_stride = 1;
    unsigned native_phase = 0;
    bool recording = false;

    bool log_public_bus=false;
    std::ostringstream public_bus;
    void advance(unsigned count) {
        for (unsigned n = 0; n < count; ++n) {
            OPM_Clock(&chip, dac, nullptr, nullptr, nullptr);
            ++ticks;
            if (recording && captured < capture_limit && chip.cycles == 0) {
                if (native_phase == 0)
                    std::fprintf(csv, "%u,%d,%d,%llu,%u,%u,%u,%u,%u\n", captured++,
                        dac[0], dac[1], static_cast<unsigned long long>(ticks * 2),
                        chip.pg_inc[0], chip.pg_inc[8], chip.pg_inc[16], chip.pg_inc[24],
                        chip.pg_phase[24]);
                native_phase = native_phase + 1 == sample_stride ? 0 : native_phase + 1;
            }
        }
    }

    void idle() {
        for (unsigned n = 0; OPM_Read(&chip, 1) & 0x80; ++n) {
            if (n == 4096) throw std::runtime_error("OPM busy timeout");
            advance(1);
        }
    }

    void write(uint8_t address, uint8_t value) {
        idle();
        log_bus("api_address",address,address,0);
        OPM_Write(&chip, 0, address);
        advance(8);
        if(keyon_phase>=0 && address==8 && (value&0x78))
            advance(((unsigned(keyon_phase)+64-unsigned((ticks*2)&63))&63)/2);
        if (events && recording)
            std::fprintf(events, "write,%llu,%u,%u\n",
                static_cast<unsigned long long>(ticks * 2), address, value);
        log_bus("api_data",address,value,1);
        OPM_Write(&chip, 1, value);
        advance(8);
        idle();
    }

    void log_bus(const char* kind,uint8_t address,uint8_t value,unsigned port) {
        if(!log_public_bus) return;
        public_bus << program_kind << ',' << kind << ',' << ticks*2 << ',' << ((ticks*2)&63)
            << ',' << unsigned(address) << ',' << unsigned(value) << ',' << port << ','
            << unsigned(OPM_Read(&chip,1)) << '\n';
    }

    bool history_mode=false;
    unsigned delay_half_per_count=64;
    uint64_t half_carry=0, requested_delay_half=0, executed_delay_master=0;
    FILE* history_log=nullptr;
    void wait_half(uint64_t requested) {
        if(requested>std::numeric_limits<uint64_t>::max()-half_carry)
            throw std::runtime_error("delay accumulator overflow");
        const auto total=requested+half_carry;
        uint64_t steps=total/4;
        half_carry=total%4;
        while(steps) {
            auto part=static_cast<unsigned>(std::min<uint64_t>(steps,std::numeric_limits<unsigned>::max()));
            advance(part); steps-=part;
        }
    }
    void monitor_delay(unsigned count) {
        const uint64_t half=uint64_t(count)*delay_half_per_count;
        if(half>std::numeric_limits<uint64_t>::max()-requested_delay_half)
            throw std::runtime_error("delay accounting overflow");
        requested_delay_half+=half;
        auto before=master_clock(); wait_half(half);
        executed_delay_master+=master_clock()-before;
    }
public:
    uint64_t master_clock() const { return ticks*2; }
    void configure_history(const std::string& csv_path,bool enabled,unsigned delay_half) {
        history_mode=enabled; delay_half_per_count=delay_half;
        if(!enabled) return;
        history_log=std::fopen((csv_path+".history.csv").c_str(),"wx");
        if(!history_log) throw std::runtime_error("cannot exclusively create history CSV");
        std::fprintf(history_log,"kind,index,path,sha256,write_count,clock_before,gap_requested_master_clocks,gap_executed_master_clocks,carry_before_half_master_clocks,carry_after_gap_half_master_clocks,clock_program_start,clock_after,carry_after_program_half_master_clocks,program_delay_requested_half_master_clocks,program_delay_executed_master_clocks,step_quantum_master_clocks,implicit_settle_master_clocks\n");
    }
    void history_program(const LoadedProgram& p,const char* kind,size_t index,uint64_t gap) {
        auto before=master_clock(),carry_before=half_carry;
        wait_half(gap*2);
        auto start=master_clock(),carry_gap=half_carry;
        auto delay_before=requested_delay_half,executed_before=executed_delay_master;
        program_kind=kind; program(p.bytes);
        std::fprintf(history_log,"%s,%zu,%s,%s,%llu,%llu,%llu,%llu,%llu,%llu,%llu,%llu,%llu,%llu,%llu,%u,0\n",
            kind,index,csv_quote(p.path).c_str(),p.sha256.c_str(),
            (unsigned long long)p.writes,(unsigned long long)before,(unsigned long long)gap,
            (unsigned long long)(start-before),(unsigned long long)carry_before,(unsigned long long)carry_gap,
            (unsigned long long)start,(unsigned long long)master_clock(),(unsigned long long)half_carry,
            (unsigned long long)(requested_delay_half-delay_before),(unsigned long long)(executed_delay_master-executed_before),4/2);
        if(std::fflush(history_log)) throw std::runtime_error("history CSV write failed");
    }
    void history_capture_marker() {
        if(!history_log) return;
        const auto now=(unsigned long long)master_clock(),carry=(unsigned long long)half_carry;
        std::fprintf(history_log,"capture_start,0,,,0,%llu,0,0,%llu,%llu,%llu,%llu,%llu,0,0,%u,0\n",now,carry,carry,now,now,carry,4/2);
        if(std::fflush(history_log)) throw std::runtime_error("history CSV write failed");
    }
public:
    explicit Oracle(unsigned stride = 1,int phase=-1,bool public_log=false)
        : keyon_phase(phase),sample_stride(stride),log_public_bus(public_log) {
        OPM_Reset(&chip);
        advance(256);
    }

    ~Oracle() {
        if (csv) std::fclose(csv);
        if (events) std::fclose(events);
        if (bus) std::fclose(bus);
        if(history_log) std::fclose(history_log);
    }

    void program(const std::vector<uint8_t>& data) {
        size_t cursor = 0;
        while (cursor < data.size()) {
            auto opcode = data.at(cursor++);
            switch (opcode) {
            case 0:
                if (cursor != data.size())
                    throw std::runtime_error("trailing program bytes");
                return;
            case 1: {
                auto address = data.at(cursor++);
                auto value = data.at(cursor++);
                write(address, value);
                break;
            }
            case 2: {
                unsigned delay = data.at(cursor++);
                delay |= unsigned(data.at(cursor++)) << 8;
                // Match jt51 harness settling delay: 32 master clocks/count.
                monitor_delay(delay);
                break;
            }
            case 3:
                std::cout << "OPM status=" << unsigned(OPM_Read(&chip, 1)) << '\n';
                break;
            default:
                throw std::runtime_error("invalid monitor opcode");
            }
        }
        throw std::runtime_error("missing completion opcode");
    }

    void open_capture(const char* path, unsigned samples, bool event_mode) {
        csv = std::fopen(path, "wx");
        if (!csv) throw std::runtime_error("cannot exclusively create CSV");
        if (event_mode) {
            events = std::fopen((std::string(path) + ".events.csv").c_str(), "wx");
            if (!events) throw std::runtime_error("cannot exclusively create events CSV");
            std::fprintf(events, "kind,clock,reg,value\n");
        }
        std::fprintf(csv, "sample,left,right,clock,inc0,inc8,inc16,inc24,phase24\n");
        if(log_public_bus) {
            bus=std::fopen((std::string(path)+".bus.csv").c_str(),"wx");
            if(!bus) throw std::runtime_error("cannot create public API log");
            std::fprintf(bus,"program,kind,clock,residue,reg,value,port,status\n");
        }
        capture_limit = samples;
    }

    void capture(const char* path, unsigned samples) {
        open_capture(path, samples, false);
        // This driver compares steady tones. Remove register/key-on pipeline
        // startup, then align snapshots to the same operator cycle each frame.
        if(!history_mode) {
            advance(512);
            while (chip.cycles != 0) advance(1);
        }
        history_capture_marker();
        recording = true;
        finish_capture();
    }

    void capture_event(const char* path, const std::vector<uint8_t>& event, unsigned samples) {
        if(!history_mode) advance(2048); // Legacy 4096 input master clocks
        history_capture_marker();
        open_capture(path, samples, true);
        recording = true;
        std::fprintf(events, "capture_start,%llu,,\n",
            static_cast<unsigned long long>(ticks * 2));
        program_kind="event";
        program(event);
        finish_capture();
    }

    void finish_capture() {
        while (captured < capture_limit) advance(1);
        if(bus) {
            std::fputs(public_bus.str().c_str(),bus);
            if(std::fflush(bus)) throw std::runtime_error("public log write failed");
        }
        if (std::fflush(csv)) throw std::runtime_error("CSV write failed");
        if (events && std::fflush(events)) throw std::runtime_error("events CSV write failed");
        std::cout << "Captured " << captured << " OPM samples; carrier increment="
            << chip.pg_inc[24] << '\n';
    }
};

int main(int argc, char** argv) {
    try {
        int key_phase=-1;
        bool public_bus=false;
        std::string history_path;
        bool history_enabled=false,delay_seen=false;
        unsigned delay_half=64;
        while(argc>1) {
            const std::string option=argv[1];
            if(option=="--history" || option=="--delay-clocks") {
                if(argc<3) throw std::runtime_error("missing history/delay option value");
                if(option=="--history") {
                    if(history_enabled) throw std::runtime_error("duplicate history option");
                    history_enabled=true; history_path=argv[2];
                } else {
                    if(delay_seen) throw std::runtime_error("duplicate delay-clocks option");
                    delay_seen=true;
                    if(std::string(argv[2])=="32") delay_half=64;
                    else if(std::string(argv[2])=="37.5") delay_half=75;
                    else throw std::runtime_error("delay-clocks must be 32 or 37.5");
                }
                argc-=2; argv+=2; continue;
            }
            if(std::string(argv[1])=="--public-bus") {
                public_bus=true; --argc; ++argv; continue;
            }
            if(std::string(argv[1])!="--keyon-phase") break;
            if(key_phase>=0) throw std::runtime_error("duplicate key-on phase");
            if(argc<3) throw std::runtime_error("missing key-on phase");
            const std::string v=argv[2];
            if(v.empty() || v.find_first_not_of("0123456789")!=std::string::npos || std::stoull(v)>63 || std::stoull(v)%2)
                throw std::runtime_error("invalid even key-on phase");
            key_phase=int(std::stoul(v)); public_bus=true; argc-=2; argv+=2;
        }
        int first = 1;
        unsigned stride = 1;
        if (argc > 1 && std::string(argv[1]) == "--stride") {
            if (argc < 3) throw std::runtime_error("missing sample stride");
            const std::string value = argv[2];
            if (value.empty() || value.find_first_not_of("0123456789") != std::string::npos)
                throw std::runtime_error("invalid sample stride");
            const auto parsed_stride = std::stoull(value);
            if (parsed_stride == 0 || parsed_stride > 1024)
                throw std::runtime_error("invalid sample stride");
            stride = parsed_stride;
            first = 3;
        }
        const bool event_mode = argc > first && std::string(argv[first]) == "--event";
        const int count_index = first + (event_mode ? 4 : 2);
        if (argc != count_index && argc != count_index + 1)
            throw std::runtime_error("Usage: opm-oracle [--stride N] PROGRAM CSV [SAMPLES]\n"
                "       opm-oracle [--stride N] --event INIT EVENT CSV [SAMPLES]");
        const auto init_loaded=load_program(argv[first+(event_mode ? 1 : 0)]);
        const auto event_loaded=event_mode ? load_program(argv[first+2]) : LoadedProgram{};
        const auto& init=init_loaded.bytes;
        const auto& event=event_loaded.bytes;
        const auto history=history_enabled ? read_history(history_path) : std::vector<HistoryRow>{};
        uint64_t whole_writes=init_loaded.writes+event_loaded.writes;
        for(const auto& row:history) whole_writes+=row.program.writes;
        if(whole_writes>2000000) throw std::runtime_error("whole input exceeds 2000000 writes");
        size_t parsed = 0;
        const std::string count = argc == count_index + 1 ? argv[count_index] : "16384";
        if (count.empty() || count.find_first_not_of("0123456789") != std::string::npos)
            throw std::runtime_error("invalid sample count");
        const auto samples = std::stoull(count, &parsed);
        if (parsed != count.size() || samples == 0 || samples > 10000000)
            throw std::runtime_error("invalid sample count");
        if (samples * stride > 16777216)
            throw std::runtime_error("capture exceeds 16777216 native frames");
        Oracle oracle(stride,key_phase,public_bus);
        oracle.configure_history(argv[first+(event_mode ? 3 : 1)],history_enabled,delay_half);
        if(history_enabled) {
            for(size_t n=0;n<history.size();++n)
                oracle.history_program(history[n].program,"history",n,history[n].gap);
            oracle.history_program(init_loaded,"init",history.size(),0);
        } else oracle.program(init);
        if (event_mode) oracle.capture_event(argv[first + 3], event, samples);
        else oracle.capture(argv[first + 1], samples);
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
