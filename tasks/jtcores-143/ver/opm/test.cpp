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

    void advance(unsigned count) {
        for (unsigned n = 0; n < count; ++n) {
            OPM_Clock(&chip, dac, nullptr, nullptr, nullptr);
            ++ticks;
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
        OPM_Write(&chip, 1, value);
        advance(8);
        idle();
    }

public:
    Oracle() {
        OPM_Reset(&chip);
        advance(256);
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

    void capture(const char* path, unsigned samples) {
        FILE* csv = std::fopen(path, "wx");
        if (!csv) throw std::runtime_error("cannot exclusively create CSV");
        std::fprintf(csv, "sample,left,right,clock,inc0,inc8,inc16,inc24,phase24\n");
        // This driver compares steady tones. Remove register/key-on pipeline
        // startup, then align snapshots to the same operator cycle each frame.
        advance(512);
        while (chip.cycles != 0) advance(1);
        for (unsigned n = 0; n < samples; ++n) {
            advance(32);
            std::fprintf(csv, "%u,%d,%d,%llu,%u,%u,%u,%u,%u\n", n,
                dac[0], dac[1], static_cast<unsigned long long>(ticks * 2),
                chip.pg_inc[0], chip.pg_inc[8], chip.pg_inc[16], chip.pg_inc[24],
                chip.pg_phase[24]);
        }
        const bool failed = std::ferror(csv);
        const int closed = std::fclose(csv);
        if (failed || closed) throw std::runtime_error("CSV write failed");
        std::cout << "Captured " << samples << " OPM samples; carrier increment="
            << chip.pg_inc[24] << '\n';
    }
};

int main(int argc, char** argv) {
    try {
        if (argc < 3 || argc > 4)
            throw std::runtime_error("Usage: opm-oracle PROGRAM CSV [SAMPLES]");
        std::ifstream file(argv[1], std::ios::binary);
        if (!file) throw std::runtime_error("cannot open program");
        std::vector<uint8_t> program{std::istreambuf_iterator<char>(file), {}};
        if (program.empty() || program.size() > 8192)
            throw std::runtime_error("invalid program length");
        size_t parsed = 0;
        const std::string count = argc == 4 ? argv[3] : "16384";
        const auto samples = std::stoull(count, &parsed);
        if (parsed != count.size() || samples == 0 || samples > 10000000)
            throw std::runtime_error("invalid sample count");
        Oracle oracle;
        oracle.program(program);
        oracle.capture(argv[2], samples);
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
