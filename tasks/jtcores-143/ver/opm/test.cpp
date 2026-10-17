// Standalone API driver; no third-party emulator implementation is copied here.
#include "opm.h"
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

class Oracle {
    opm_t chip{};
    int32_t dac[2]{};
    uint64_t ticks = 0;
    FILE* csv = nullptr;
    FILE* events = nullptr;
    unsigned captured = 0;
    unsigned capture_limit = 0;
    bool recording = false;

    void advance(unsigned count) {
        for (unsigned n = 0; n < count; ++n) {
            OPM_Clock(&chip, dac, nullptr, nullptr, nullptr);
            ++ticks;
            if (recording && captured < capture_limit && chip.cycles == 0) {
                std::fprintf(csv, "%u,%d,%d,%llu,%u,%u,%u,%u,%u\n", captured++,
                    dac[0], dac[1], static_cast<unsigned long long>(ticks * 2),
                    chip.pg_inc[0], chip.pg_inc[8], chip.pg_inc[16], chip.pg_inc[24],
                    chip.pg_phase[24]);
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
        OPM_Write(&chip, 0, address);
        advance(8);
        if (events && recording)
            std::fprintf(events, "write,%llu,%u,%u\n",
                static_cast<unsigned long long>(ticks * 2), address, value);
        OPM_Write(&chip, 1, value);
        advance(8);
        idle();
    }

public:
    Oracle() {
        OPM_Reset(&chip);
        advance(256);
    }

    ~Oracle() {
        if (csv) std::fclose(csv);
        if (events) std::fclose(events);
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
        program(event);
        finish_capture();
    }

    void finish_capture() {
        while (captured < capture_limit) advance(1);
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
        const bool event_mode = argc > 1 && std::string(argv[1]) == "--event";
        const int count_index = event_mode ? 5 : 3;
        if (argc != count_index && argc != count_index + 1)
            throw std::runtime_error("Usage: opm-oracle PROGRAM CSV [SAMPLES]\n"
                "       opm-oracle --event INIT EVENT CSV [SAMPLES]");
        const auto init = read_program(argv[event_mode ? 2 : 1]);
        const auto event = event_mode ? read_program(argv[3]) : std::vector<uint8_t>{};
        size_t parsed = 0;
        const std::string count = argc == count_index + 1 ? argv[count_index] : "16384";
        if (count.empty() || count.find_first_not_of("0123456789") != std::string::npos)
            throw std::runtime_error("invalid sample count");
        const auto samples = std::stoull(count, &parsed);
        if (parsed != count.size() || samples == 0 || samples > 10000000)
            throw std::runtime_error("invalid sample count");
        Oracle oracle;
        oracle.program(init);
        if (event_mode) oracle.capture_event(argv[4], event, samples);
        else oracle.capture(argv[2], samples);
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
