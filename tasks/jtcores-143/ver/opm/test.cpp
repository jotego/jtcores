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
                advance(delay * 16);
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
        advance(512);
        while (chip.cycles != 0) advance(1);
        recording = true;
        finish_capture();
    }

    void capture_event(const char* path, const std::vector<uint8_t>& event, unsigned samples) {
        advance(2048); // 4096 input master clocks
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

static std::vector<uint8_t> read_program(const char* path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) throw std::runtime_error("cannot open program");
    std::vector<uint8_t> program{std::istreambuf_iterator<char>(file), {}};
    if (program.empty() || program.size() > 8192)
        throw std::runtime_error("invalid program length");
    return program;
}

int main(int argc, char** argv) {
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
        const auto init = read_program(argv[first + (event_mode ? 1 : 0)]);
        const auto event = event_mode ? read_program(argv[first + 2]) : std::vector<uint8_t>{};
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
        oracle.program(init);
        if (event_mode) oracle.capture_event(argv[first + 3], event, samples);
        else oracle.capture(argv[first + 1], samples);
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
