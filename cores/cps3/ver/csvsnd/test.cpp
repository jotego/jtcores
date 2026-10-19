#include <cctype>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "Vtest.h"
#include "verilated.h"
#if VM_TRACE_FST
#include "verilated_fst_c.h"
#endif
#include "sdram.h"
#include "wavewritter.h"

namespace {

constexpr uint64_t SIM_HZ = 50000000ULL;
constexpr uint64_t CPU_HZ = 25000000ULL;
constexpr uint32_t WAV_HZ = 48000U;
constexpr uint64_t STARTUP_US = 300ULL;
constexpr uint64_t PS_PER_SEC = 1000000000000ULL;
constexpr uint64_t HALF_DEN = 2ULL * SIM_HZ;
constexpr uint64_t HALF_PS = PS_PER_SEC / HALF_DEN;
constexpr uint64_t HALF_PS_REM = PS_PER_SEC % HALF_DEN;

static double g_sc_time_ps = 0.0;

struct CsvCmd {
    uint64_t cpu_ticks = 0;
    uint64_t sim_cycle = 0;
    bool is_read = false;
    uint8_t addr = 0;
    uint32_t data = 0;
    uint32_t mask = 0;
    uint8_t byte_mask = 0;
    int line = 0;
};

static std::string trim(const std::string& s) {
    size_t a = 0;
    size_t b = s.size();
    while( a < b && std::isspace(static_cast<unsigned char>(s[a])) ) a++;
    while( b > a && std::isspace(static_cast<unsigned char>(s[b - 1])) ) b--;
    return s.substr(a, b - a);
}

static uint64_t parse_u64(const std::string& s) {
    return std::strtoull(trim(s).c_str(), nullptr, 0);
}

static bool parse_rw(const std::string& s) {
    std::string t = trim(s);
    if( t == "1" || t == "r" || t == "R" || t == "read" || t == "READ" ) return true;
    if( t == "0" || t == "w" || t == "W" || t == "write" || t == "WRITE" ) return false;
    std::fprintf(stderr, "ERROR: unsupported r/w token '%s'\n", t.c_str());
    std::exit(1);
}

static uint8_t mask_to_bytes(uint32_t mask) {
    uint8_t byte_mask = 0;
    for( int k = 0; k < 4; k++ ) {
        if( ((mask >> (k * 8)) & 0xffU) != 0 ) byte_mask |= (1U << k);
    }
    return byte_mask;
}

static uint64_t cpu_to_sim(uint64_t cpu_ticks) {
    return (cpu_ticks * SIM_HZ + CPU_HZ - 1) / CPU_HZ;
}

static bool is_general_keyoff(const CsvCmd& cmd) {
    return !cmd.is_read &&
           cmd.addr == 0x80 &&
           (cmd.mask & 0xffff0000U) != 0 &&
           (cmd.data & cmd.mask & 0xffff0000U) == 0;
}

static bool is_keyon(const CsvCmd& cmd) {
    return !cmd.is_read &&
           cmd.addr == 0x80 &&
           (cmd.mask & 0xffff0000U) != 0 &&
           (cmd.data & cmd.mask & 0xffff0000U) != 0;
}

static void shorten_preamble(std::vector<CsvCmd>& cmds) {
    const uint64_t target_cycle = (STARTUP_US * SIM_HZ + 999999ULL) / 1000000ULL;

    if( !cmds.empty() && is_general_keyoff(cmds.front()) ) {
        cmds.erase(cmds.begin());
    }
    if( cmds.empty() ) return;

    size_t first_keyon = cmds.size();
    for( size_t i = 0; i < cmds.size(); i++ ) {
        if( is_keyon(cmds[i]) ) {
            first_keyon = i;
            break;
        }
    }

    if( first_keyon == cmds.size() ) {
        if( cmds.front().sim_cycle <= target_cycle ) return;
        const uint64_t shift = cmds.front().sim_cycle - target_cycle;
        for( auto& cmd : cmds ) {
            cmd.sim_cycle -= shift;
        }
        return;
    }

    const uint64_t orig_keyon_cycle = cmds[first_keyon].sim_cycle;
    if( orig_keyon_cycle > target_cycle ) {
        const uint64_t shift = orig_keyon_cycle - target_cycle;
        for( size_t i = first_keyon; i < cmds.size(); i++ ) {
            cmds[i].sim_cycle -= shift;
        }
    }

    uint64_t pre_start = target_cycle > first_keyon ? target_cycle - first_keyon : 0;
    for( size_t i = 0; i < first_keyon; i++ ) {
        cmds[i].sim_cycle = pre_start + i;
    }
}

static std::vector<CsvCmd> load_csv(const std::string& path) {
    std::ifstream fin(path);
    if( !fin ) {
        std::fprintf(stderr, "ERROR: could not open CSV '%s'\n", path.c_str());
        std::exit(1);
    }

    std::vector<CsvCmd> out;
    std::string line;
    int line_no = 0;
    while( std::getline(fin, line) ) {
        line_no++;
        if( line_no == 1 && line.size() >= 3 &&
            static_cast<unsigned char>(line[0]) == 0xef &&
            static_cast<unsigned char>(line[1]) == 0xbb &&
            static_cast<unsigned char>(line[2]) == 0xbf ) {
            line.erase(0, 3);
        }
        if( line.empty() ) continue;
        if( line_no == 1 ) continue;

        std::stringstream ss(line);
        std::string f0, f1, f2, f3, f4;
        if( !std::getline(ss, f0, ',') || !std::getline(ss, f1, ',') ||
            !std::getline(ss, f2, ',') || !std::getline(ss, f3, ',') ||
            !std::getline(ss, f4, ',') ) {
            std::fprintf(stderr, "ERROR: malformed CSV line %d\n", line_no);
            std::exit(1);
        }

        CsvCmd cmd;
        cmd.line = line_no;
        cmd.cpu_ticks = parse_u64(f0);
        cmd.sim_cycle = cpu_to_sim(cmd.cpu_ticks);
        cmd.is_read = parse_rw(f1);
        cmd.addr = static_cast<uint8_t>(parse_u64(f2) & 0xffU);
        cmd.data = static_cast<uint32_t>(parse_u64(f3));
        cmd.mask = static_cast<uint32_t>(parse_u64(f4));
        cmd.byte_mask = mask_to_bytes(cmd.mask);
        out.push_back(cmd);
    }
    shorten_preamble(out);
    return out;
}

struct Args {
    std::string csv_path = "snd.csv";
    std::string wav_path = "test.wav";
    uint64_t timeout_ms = 0;
    bool strict_reads = false;
};

static void usage(const char* argv0) {
    std::fprintf(stderr,
        "Usage: %s [--csv path] [--wav path] [--timeout milliseconds] [--strict-reads]\n",
        argv0);
}

static Args parse_args(int argc, char** argv) {
    Args args;
    for( int i = 1; i < argc; i++ ) {
        std::string a = argv[i];
        if( a == "--csv" && i + 1 < argc ) {
            args.csv_path = argv[++i];
        } else if( a == "--wav" && i + 1 < argc ) {
            args.wav_path = argv[++i];
        } else if( a == "--timeout" && i + 1 < argc ) {
            args.timeout_ms = std::strtoull(argv[++i], nullptr, 0);
        } else if( a == "--strict-reads" ) {
            args.strict_reads = true;
        } else if( a == "--help" || a == "-h" ) {
            usage(argv[0]);
            std::exit(0);
        } else {
            usage(argv[0]);
            std::fprintf(stderr, "ERROR: unknown argument '%s'\n", a.c_str());
            std::exit(1);
        }
    }
    return args;
}

class Sim {
    Vtest top;
    SDRAMModel sdram;
    bool last_sdram_clk = false;
    WaveWritter wav;
    bool strict_reads = false;
    uint64_t main_time_ps = 0;
    uint64_t half_ps_err = 0;
    uint64_t cycle = 0;
    uint64_t wav_acc = 0;
    uint64_t dbg_rom_cs_cycles = 0;
    uint64_t dbg_rom_ok_cycles = 0;
    uint32_t dbg_last_rom_addr = 0;
    uint64_t read_mismatch_count = 0;
    uint64_t dbg_first_rom_cs_cycle = 0;
    uint64_t dbg_first_audio_cycle = 0;
#if VM_TRACE_FST
    VerilatedFstC* trace = nullptr;
#endif

    void load_sdram_bank1() {
        std::ifstream fin("sdram_bank1.bin", std::ios::binary);
        if( !fin ) {
            std::fprintf(stderr, "ERROR: could not open sdram_bank1.bin\n");
            std::exit(1);
        }
        fin.seekg(0, fin.end);
        size_t len = static_cast<size_t>(fin.tellg());
        fin.seekg(0, fin.beg);
        len = std::min(len, static_cast<size_t>(sdram.bank_byte_len()));
        std::vector<uint8_t> aux(len);
        fin.read(reinterpret_cast<char*>(aux.data()), static_cast<std::streamsize>(len));
        size_t got = static_cast<size_t>(fin.gcount());
        sdram.load_bank_bytes(1, aux.data(), got, true);
        std::fprintf(stderr, "Read %zX from sdram_bank1.bin\n", got);
    }

    void update_sdram() {
        bool neg_edge = !top.SDRAM_CLK && last_sdram_clk;
        if( neg_edge ) {
            SDRAMPins pins;
            pins.cke = top.SDRAM_CKE != 0;
            pins.ncs = top.SDRAM_nCS != 0;
            pins.nras = top.SDRAM_nRAS != 0;
            pins.ncas = top.SDRAM_nCAS != 0;
            pins.nwe = top.SDRAM_nWE != 0;
            pins.ba = top.SDRAM_BA & 3;
            pins.dqm = top.SDRAM_DQM & 3;
            pins.a = top.SDRAM_A;
            pins.din = top.SDRAM_DIN;
            SDRAMOutputs out = sdram.tick(pins);
            top.SDRAM_DQ = out.dq_drive ? out.dq : 0;
        }
        last_sdram_clk = top.SDRAM_CLK != 0;
    }

public:
    explicit Sim(const std::string& wav_path, bool strict_reads_)
        : top(),
          sdram(10, true),
          wav(wav_path, static_cast<int>(WAV_HZ), false),
          strict_reads(strict_reads_) {
        sdram.reset();
        load_sdram_bank1();
        top.rst = 1;
        top.clk = 0;
        top.snd_cs = 0;
        top.cpu_addr = 0;
        top.cpu_dout = 0;
        top.cpu_rnw = 1;
        top.cpu_wr_mask = 0;
        top.SDRAM_DQ = 0;
#if VM_TRACE_FST
        Verilated::traceEverOn(true);
        trace = new VerilatedFstC;
        top.trace(trace, 99);
        trace->open("test.fst");
#endif
        top.eval();
    }

    ~Sim() {
#if VM_TRACE_FST
        if( trace != nullptr ) {
            trace->close();
            delete trace;
            trace = nullptr;
        }
#endif
    }

    void half_cycle(int clk_val) {
        top.clk = clk_val;
        g_sc_time_ps = static_cast<double>(main_time_ps);
        top.eval();
        update_sdram();
        top.eval();
#if VM_TRACE_FST
        if( trace != nullptr ) trace->dump(main_time_ps);
#endif
        main_time_ps += HALF_PS;
        half_ps_err += HALF_PS_REM;
        if( half_ps_err >= HALF_DEN ) {
            main_time_ps++;
            half_ps_err -= HALF_DEN;
        }
    }

    void step_cycle() {
        half_cycle(0);
        half_cycle(1);
        cycle++;
        bool rom_was_cs = top.dbg_rom_cs != 0;
        if( rom_was_cs ) dbg_rom_cs_cycles++;
        if( top.dbg_rom_ok ) dbg_rom_ok_cycles++;
        dbg_last_rom_addr = static_cast<uint32_t>(top.dbg_rom_addr);
        wav_acc += WAV_HZ;
        while( wav_acc >= SIM_HZ ) {
            wav_acc -= SIM_HZ;
            int16_t lr[2];
            lr[0] = static_cast<int16_t>(top.snd_right);
            lr[1] = static_cast<int16_t>(top.snd_left);
            wav.write(lr);
        }
    }

    void release_bus() {
        top.snd_cs = 0;
        top.cpu_rnw = 1;
        top.cpu_wr_mask = 0;
        top.cpu_addr = 0;
        top.cpu_dout = 0;
    }

    void reset(unsigned cycles_rst = 32) {
        for( unsigned k = 0; k < cycles_rst; k++ ) step_cycle();
        top.rst = 0;
        release_bus();
    }

    void execute(const CsvCmd& cmd) {
        // jtcps3_sound expects 16-bit data ALWAYS on cpu_dout[15:0]
        // and byte enables on cpu_we_n[1:0], with cpu_addr[1]
        // routing them to the correct internal halfword.
        // MAME trace places them on the actual halfword; remap here.
        bool is_upper = (cmd.mask & 0xFFFF0000U) != 0;
        uint32_t bus_data   = cmd.data;
        uint8_t  bus_wr_mask = cmd.byte_mask;
        uint32_t bus_addr   = static_cast<uint32_t>(cmd.addr << 1);
        if( is_upper ) {
            bus_data   = (bus_data >> 16) & 0xFFFFU;   // upper→lower
            bus_wr_mask = bus_wr_mask >> 2;             // bytes[3:2]→[1:0]
            if( cmd.addr != 0x80 ) bus_addr |= 1;       // KEY reg needs bit1=0
        } else {
            bus_data &= 0xFFFFU;
        }
        top.snd_cs = 1;
        top.cpu_addr = bus_addr;
        top.cpu_dout = bus_data;
        top.cpu_rnw = cmd.is_read ? 1 : 0;
        top.cpu_wr_mask = cmd.is_read ? 0 : bus_wr_mask;
        step_cycle();
        if( cmd.is_read ) {
            // Readback: sound module returns data in cpu_din[15:0];
            // shift to match MAME trace's expected halfword position
            uint32_t raw = static_cast<uint32_t>(top.cpu_din);
            uint32_t got = (is_upper ? (raw << 16) : raw) & cmd.mask;
            uint32_t exp = cmd.data & cmd.mask;
            if( got != exp ) {
                read_mismatch_count++;
                const char* level = strict_reads ? "ERROR" : "WARN";
                std::fprintf(stderr,
                    "%s: CSV line %d read mismatch at cycle %llu addr=0x%02X got=0x%08X exp=0x%08X mask=0x%08X\n",
                    level,
                    cmd.line,
                    static_cast<unsigned long long>(cycle),
                    cmd.addr,
                    got,
                    exp,
                    cmd.mask);
                if( strict_reads ) {
                    std::exit(1);
                }
            }
        }
        release_bus();
    }

    uint64_t get_cycle() const { return cycle; }
    uint64_t get_rom_cs_cycles() const { return dbg_rom_cs_cycles; }
    uint64_t get_rom_ok_cycles() const { return dbg_rom_ok_cycles; }
    uint32_t get_last_rom_addr() const { return dbg_last_rom_addr; }
    uint64_t get_read_mismatch_count() const { return read_mismatch_count; }
};

} // namespace

double sc_time_stamp() {
    return g_sc_time_ps;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    const Args args = parse_args(argc, argv);
    const std::vector<CsvCmd> cmds = load_csv(args.csv_path);
    const uint64_t timeout_cycles = args.timeout_ms == 0 ? 0 : (args.timeout_ms * SIM_HZ + 999ULL) / 1000ULL;

    Sim sim(args.wav_path, args.strict_reads);
    sim.reset();

    size_t next = 0;
    while( next < cmds.size() ) {
        if( timeout_cycles != 0 && sim.get_cycle() > timeout_cycles ) {
            std::fprintf(stderr, "timeout after %llu cycles, rom_cs=%llu rom_ok=%llu last_rom_addr=0x%06X\n",
                static_cast<unsigned long long>(sim.get_cycle()),
                static_cast<unsigned long long>(sim.get_rom_cs_cycles()),
                static_cast<unsigned long long>(sim.get_rom_ok_cycles()),
                sim.get_last_rom_addr());
            if( sim.get_read_mismatch_count() != 0 ) {
                std::fprintf(stderr, "read mismatches: %llu\n",
                    static_cast<unsigned long long>(sim.get_read_mismatch_count()));
            }
            return 0;
        }
        if( sim.get_cycle() < cmds[next].sim_cycle ) {
            sim.step_cycle();
            continue;
        }
        sim.execute(cmds[next]);
        next++;
    }

    if( sim.get_read_mismatch_count() != 0 ) {
        std::fprintf(stderr, "read mismatches: %llu\n",
            static_cast<unsigned long long>(sim.get_read_mismatch_count()));
    }
    return 0;
}
