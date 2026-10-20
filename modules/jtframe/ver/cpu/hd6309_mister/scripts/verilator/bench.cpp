#include "Vhd6309_cycle_test.h"
#include "verilated.h"

#include <array>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {
constexpr uint64_t kDefaultInstructions = 99'999'975;
constexpr unsigned kResultWords = 96;

uint64_t parse_count(int argc, char **argv) {
    if (argc == 1) return kDefaultInstructions;
    if (argc < 2) throw std::runtime_error("usage: bench [completed-instructions]");
    char *end = nullptr;
    const auto count = std::strtoull(argv[1], &end, 10);
    if (!end || *end || count == 0 || count % 25 != 0 || count > 99'999'975)
        throw std::runtime_error("instruction count must be a positive multiple of 25 at most 99999975");
    return count;
}

unsigned parse_mode(int argc, char **argv) {
    if (argc < 3) return 1;
    char *end = nullptr;
    const auto mode = std::strtoul(argv[2], &end, 10);
    if (!end || *end || mode > 1) throw std::runtime_error("mode must be 0 (emulation) or 1 (native)");
    return static_cast<unsigned>(mode);
}

std::string parse_result_path(int argc, char **argv) {
    if (argc < 4) return {};
    if (argc != 5 || std::string(argv[3]) != "--result-bin")
        throw std::runtime_error("usage: bench [completed-instructions] [mode] [--result-bin PATH]");
    return argv[4];
}

void tick(Vhd6309_cycle_test &dut) {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
}

uint32_t read_word(Vhd6309_cycle_test &dut, unsigned address) {
    dut.result_word_addr = address;
    dut.eval();
    return dut.result_word_data;
}
} // namespace

int main(int argc, char **argv) {
    try {
        const uint64_t target = parse_count(argc, argv);
        const unsigned mode = parse_mode(argc, argv);
        const std::string result_path = parse_result_path(argc, argv);
        Vhd6309_cycle_test dut;
        dut.clk = 0;
        dut.reset_n = 0;
        dut.result_word_addr = 0;
        dut.eval();
        for (unsigned i = 0; i < 12; ++i) tick(dut);
        dut.reset_n = 1;
        dut.eval();

        const auto start = std::chrono::steady_clock::now();
        uint64_t clocks = 0;
        while (!dut.test_done) {
            tick(dut);
            ++clocks;
        }
        const auto stop = std::chrono::steady_clock::now();
        std::array<uint32_t, kResultWords> words{};
        for (unsigned i = 0; i < kResultWords; ++i)
            words[i] = read_word(dut, i);

        if (words[0] != 0x544d544a || words[1] != 1 ||
            (words[2] & 2u) == 0 || words[3] != kResultWords ||
            words[4] != mode || words[5] != target || words[6] != target)
            throw std::runtime_error("result window did not report a completed run of the requested length");

        if (!result_path.empty()) {
            std::ofstream result_file(result_path, std::ios::binary);
            if (!result_file) throw std::runtime_error("cannot open result binary: " + result_path);
            for (uint32_t word : words) {
                for (unsigned byte = 0; byte < 4; ++byte)
                    result_file.put(static_cast<char>((word >> (8 * byte)) & 0xff));
            }
            if (!result_file) throw std::runtime_error("failed writing result binary: " + result_path);
        }

        uint64_t hash = 14695981039346656037ull;
        for (uint32_t word : words) {
            for (unsigned byte = 0; byte < 4; ++byte) {
                hash ^= (word >> (8 * byte)) & 0xff;
                hash *= 1099511628211ull;
            }
        }

        const double elapsed = std::chrono::duration<double>(stop - start).count();
        std::cout << "mode=" << (mode ? "native" : "emulation")
                  << " target_instructions=" << target
                  << " host_clocks=" << clocks
                  << " result_e_cycles=" << words[7]
                  << " simulation_seconds=" << std::fixed << std::setprecision(3) << elapsed
                  << " instructions_per_second=" << std::setprecision(0)
                  << double(target) / elapsed
                  << " result_hash=0x" << std::hex << std::setw(16) << std::setfill('0')
                  << hash << std::dec << '\n';
        std::cout << "word,value\n";
        for (unsigned i = 0; i < words.size(); ++i)
            std::cout << i << ",0x" << std::hex << std::setw(8) << std::setfill('0')
                      << words[i] << std::dec << '\n';
        return 0;
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 2;
    }
}
