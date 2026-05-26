#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include "Vtest.h"
#include "Vtest___024root.h"
#include "verilated.h"
#if VM_TRACE_FST
#include "verilated_fst_c.h"
#endif
#include "sdram.h"

namespace fs = std::filesystem;

namespace {

static constexpr uint64_t SIM_HZ = 85909090ULL;
static constexpr uint64_t CPU_HZ = 25000000ULL;
static constexpr uint64_t PS_PER_SEC = 1000000000000ULL;
static constexpr uint64_t SUB_DEN = 4ULL * SIM_HZ;
static constexpr uint64_t SUB_PS = PS_PER_SEC / SUB_DEN;
static constexpr uint64_t SUB_PS_REM = PS_PER_SEC % SUB_DEN;
static constexpr uint64_t TRACE_BOOT_WINDOW_CYCLES = 512ULL;

static constexpr uint32_t STATUS_ADDR   = 0x06000000U;
static constexpr uint32_t STATUS_COPY   = 0x00000011U;
static constexpr uint32_t STATUS_VERIFY = 0x00000022U;
static constexpr uint32_t STATUS_RMW    = 0x00000033U;
static constexpr uint32_t STATUS_PART   = 0x00000044U;
static constexpr uint32_t STATUS_SCAN   = 0x00000055U;
static constexpr uint32_t STATUS_PASS   = 0x00000066U;
static constexpr uint32_t STATUS_FAIL   = 0xdead0001U;

static constexpr uint32_t SRC_ADDR   = 0x00002000U;
static constexpr uint32_t DST_ADDR   = 0x00004000U;
static constexpr uint32_t RMW_ADDR   = 0x00004004U;
static constexpr uint32_t PART_ADDR  = 0x00004008U;
static constexpr uint32_t SCAN_ADDR  = 0x00006000U;
static constexpr uint32_t COPY_WORDS = 1U;
static constexpr uint32_t SCAN_WORDS = 1024U;

static double g_sc_time_ps = 0.0;

struct Args {
    uint64_t timeout_ms = 2000;
    uint64_t boot_timeout_ms = 200;
    bool boot_only = false;
    bool trace_bus = false;
    bool keep = false;
};

static void usage(const char* argv0) {
    std::fprintf(stderr,
        "Usage: %s [--timeout milliseconds] [--boot-timeout milliseconds] [--boot-only] [--trace-bus]\n",
        argv0);
}

static Args parse_args(int argc, char** argv) {
    Args args;
    for( int i = 1; i < argc; i++ ) {
        std::string a = argv[i];
        if( a == "--timeout" && i + 1 < argc ) {
            args.timeout_ms = std::strtoull(argv[++i], nullptr, 0);
        } else if( a == "--boot-timeout" && i + 1 < argc ) {
            args.boot_timeout_ms = std::strtoull(argv[++i], nullptr, 0);
        } else if( a == "--boot-only" ) {
            args.boot_only = true;
        } else if( a == "--trace-bus" ) {
            args.trace_bus = true;
        } else if( a == "-h" || a == "--help" ) {
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

static std::vector<uint8_t> load_file(const fs::path& path) {
    std::ifstream fin(path, std::ios::binary);
    if( !fin ) {
        std::fprintf(stderr, "ERROR: could not open '%s'\n", path.c_str());
        std::exit(1);
    }
    fin.seekg(0, std::ios::end);
    std::size_t len = static_cast<std::size_t>(fin.tellg());
    fin.seekg(0, std::ios::beg);
    std::vector<uint8_t> buf(len);
    fin.read(reinterpret_cast<char*>(buf.data()), static_cast<std::streamsize>(len));
    if( static_cast<std::size_t>(fin.gcount()) != len ) {
        std::fprintf(stderr, "ERROR: short read on '%s'\n", path.c_str());
        std::exit(1);
    }
    return buf;
}

class Sim {
    Vtest top;
    SDRAMModel sdram;
    bool last_clk_sdram = false;
    uint64_t main_time_ps = 0;
    uint64_t sub_ps_err = 0;
    uint64_t cycles = 0;
    uint32_t seen_phase = 0;
    bool boot_seen = false;
    uint64_t trace_bus_count = 0;
    bool saw_pass = false;
    bool saw_fail = false;
    bool last_status_write = false;
    uint32_t last_status_code = 0;
    uint64_t cache_req_count = 0;
    uint64_t cache_ok_count = 0;
    uint32_t last_cache_addr = 0;
    bool last_cache_active = false;
    bool last_cache_ok = false;
    bool last_cpu_req = false;
    uint32_t last_A = 0xffffffff;
    bool last_req_busy = false;
    bool last_req_seen = false;
    bool last_req_launch = false;
    bool last_req_ready = true;
    bool last_wait_n = true;
    bool trace_bus = false;
    uint64_t trace_boot_window = TRACE_BOOT_WINDOW_CYCLES;
    uint64_t debug_events = 0;
#if VM_TRACE_FST
    VerilatedFstC* trace = nullptr;
#endif

    void fatal(const char* msg) {
        std::fprintf(stderr, "ERROR: %s\n", msg);
        std::exit(1);
    }

    template <typename... ArgsT>
    void fatalf(const char* fmt, ArgsT... args) {
        std::fprintf(stderr, "ERROR: ");
        std::fprintf(stderr, fmt, args...);
        std::fprintf(stderr, "\n");
        std::exit(1);
    }

    void load_sdram_bank0() {
        auto data = load_file("sdram_bank0.bin");
        sdram.load_bank_bytes(0, data.data(), data.size(), true);
        std::fprintf(stderr, "Loaded %zu bytes into SDRAM bank 0\n", data.size());
    }

    void update_sdram() {
        bool neg_edge = !top.clk_sdram && last_clk_sdram;
        if( neg_edge ) {
            SDRAMPins pins;
            pins.cke = top.sdram_cke != 0;
            pins.ncs = top.sdram_ncs != 0;
            pins.nras = top.sdram_nras != 0;
            pins.ncas = top.sdram_ncas != 0;
            pins.nwe = top.sdram_nwe != 0;
            pins.ba = top.sdram_ba & 3;
            pins.dqm = top.sdram_dqm & 3;
            pins.a = top.sdram_a;
            pins.din = top.sdram_din;
            SDRAMOutputs out = sdram.tick(pins);
            top.sdram_dq = out.dq_drive ? out.dq : 0;
        }
        last_clk_sdram = top.clk_sdram != 0;
    }

    void check_cache_protocol() {
        if( top.cache_cs && !last_cache_active ) {
            cache_req_count++;
            last_cache_addr = static_cast<uint32_t>(top.cache_addr);
            bool interesting = last_cache_addr == (SRC_ADDR >> 2) ||
                               last_cache_addr == (DST_ADDR >> 2) ||
                               last_cache_addr == (RMW_ADDR >> 2) ||
                               last_cache_addr == (PART_ADDR >> 2) ||
                               last_cache_addr == (SCAN_ADDR >> 2) ||
                               last_cache_addr == (STATUS_ADDR >> 2);
            if( cache_req_count <= 64 || interesting ) {
                std::fprintf(stderr,
                    "CACHE_REQ #%llu A=%08x addr=%08x rd=%d wr=%d area0=%d ok=%d\n",
                    static_cast<unsigned long long>(cache_req_count),
                    static_cast<unsigned>(top.A),
                    static_cast<unsigned>(top.cache_addr),
                    top.cache_rd ? 1 : 0,
                    top.cache_wr ? 1 : 0,
                    ((top.A >> 25) & 3U) == 0 ? 1 : 0,
                    top.cache_ok ? 1 : 0);
            }
        }
        if( top.cache_cs && top.cache_ok && !last_cache_ok ) {
            cache_ok_count++;
            if( !boot_seen ) {
                boot_seen = true;
                std::fprintf(stderr,
                    "BOOT_SEEN A=%08x addr=%08x at cycle=%llu\n",
                    static_cast<unsigned>(top.A),
                    static_cast<unsigned>(top.cache_addr),
                    static_cast<unsigned long long>(cycles));
            }
            bool interesting = last_cache_addr == (SRC_ADDR >> 2) ||
                               last_cache_addr == (DST_ADDR >> 2) ||
                               last_cache_addr == (RMW_ADDR >> 2) ||
                               last_cache_addr == (PART_ADDR >> 2) ||
                               last_cache_addr == (SCAN_ADDR >> 2) ||
                               last_cache_addr == (STATUS_ADDR >> 2);
            if( cache_ok_count <= 64 || interesting ) {
                std::fprintf(stderr,
                    "CACHE_OK  #%llu A=%08x addr=%08x data=%08x\n",
                    static_cast<unsigned long long>(cache_ok_count),
                    static_cast<unsigned>(top.A),
                    static_cast<unsigned>(top.cache_addr),
                    static_cast<unsigned>(top.cache_dout));
            }
        }

        bool cache_is_active = top.cache_cs != 0;
        bool cache_waited = top.WAIT_N == 0;
        bool cache_wait_changed = last_wait_n != (top.WAIT_N != 0);
        bool cache_sig_changed = last_cache_addr != top.cache_addr ||
                                last_cache_active != cache_is_active ||
                                last_cache_ok != top.cache_ok;
        bool cache_just_started = !last_cache_active && cache_is_active;
        bool cache_just_finished = last_cache_active && !cache_is_active;
        bool cpu_req = top.BS_N == 0 && (top.RD_N == 0 || top.RD_WR_N == 0);
        bool req_busy = cache_is_active;
        bool req_seen = top.WAIT_N != 0 && !cache_is_active;
        bool req_launch = cache_just_started;
        bool req_ready = !cache_is_active || top.cache_ok;
        bool bus_state_changed = last_cpu_req != cpu_req ||
                                last_A != top.A ||
                                last_req_busy != req_busy ||
                                last_req_seen != req_seen ||
                                last_req_launch != req_launch ||
                                last_req_ready != req_ready ||
                                last_wait_n != (top.WAIT_N != 0);
        bool should_trace_bus = (!boot_seen && trace_boot_window > 0) ||
                               (boot_seen && (cache_sig_changed || cache_wait_changed ||
                                             cache_just_started || cache_just_finished ||
                                             cache_waited && cache_wait_changed ||
                                             bus_state_changed || debug_events < 32));
        if( !boot_seen && trace_bus && trace_boot_window > 0 ) {
            trace_boot_window--;
        }
        if( trace_bus && should_trace_bus ) {
            std::fprintf(stderr,
                "BUS_DBG=%llu cycle=%llu A=%08x dout=%08x c0_dout=%08x req=%d cache_busy=%d cache_seen=%d launch=%d ready=%d c_ok=%d cs=%d wr=%d wait_n=%d c_addr=%08x c_dsn=%x c_data=%08x\n",
                static_cast<unsigned long long>(trace_bus_count),
                static_cast<unsigned long long>(cycles),
                static_cast<unsigned>(top.A),
                static_cast<unsigned>(top.cpu_dout),
                static_cast<unsigned>(top.cache_dout),
                cpu_req ? 1 : 0,
                req_busy ? 1 : 0,
                req_seen ? 1 : 0,
                req_launch ? 1 : 0,
                req_ready ? 1 : 0,
                top.cache_ok ? 1 : 0,
                top.cache_cs ? 1 : 0,
                top.cache_wr ? 1 : 0,
                top.WAIT_N ? 1 : 0,
                static_cast<unsigned>(top.cache_addr),
                static_cast<unsigned>(top.cache_dsn),
                static_cast<unsigned>(top.cache_din));
            debug_events++;
        }
        trace_bus_count++;
        last_cache_addr = top.cache_addr;
        last_cache_active = cache_is_active;
        last_cache_ok = top.cache_ok;
        last_cpu_req = cpu_req;
        last_A = top.A;
        last_req_busy = req_busy;
        last_req_seen = req_seen;
        last_req_launch = req_launch;
        last_req_ready = req_ready;
        last_wait_n = top.WAIT_N != 0;

        if( top.cache_rd && top.cache_wr ) {
            fatal("cache read and write strobes overlapped");
        }
        if( top.ce_r && top.ce_f ) {
            fatal("CE_R and CE_F overlapped");
        }
        last_cache_active = top.cache_cs != 0;
        last_cache_ok = top.cache_ok != 0;
    }

    void check_status_writes() {
        bool status_write = top.cache_wr && static_cast<uint32_t>(top.cache_addr) == (STATUS_ADDR >> 1);
        if( !status_write ) {
            last_status_write = false;
            return;
        }
        if( last_status_write ) return;
        last_status_write = true;

        uint32_t code = top.cache_din;
        if( code == last_status_code ) return;
        last_status_code = code;
        std::fprintf(stderr, "STATUS_WRITE code=%08x at cycle=%llu\n",
            code, static_cast<unsigned long long>(cycles));
        if( code == STATUS_FAIL ) {
            saw_fail = true;
            fatal("CPU reported failure");
        }

        if( code == STATUS_COPY ) {
            if( seen_phase != 0 ) fatal("copy phase out of order");
            seen_phase = 1;
            return;
        }
        if( code == STATUS_VERIFY ) {
            if( seen_phase != 1 ) fatal("verify phase out of order");
            seen_phase = 2;
            return;
        }
        if( code == STATUS_RMW ) {
            if( seen_phase != 2 ) fatal("rmw phase out of order");
            seen_phase = 3;
            return;
        }
        if( code == STATUS_PART ) {
            if( seen_phase != 3 ) fatal("partial-write phase out of order");
            seen_phase = 4;
            return;
        }
        if( code == STATUS_SCAN ) {
            if( seen_phase != 4 ) fatal("scan phase out of order");
            seen_phase = 5;
            return;
        }
        if( code == STATUS_PASS ) {
            if( seen_phase != 5 ) fatal("pass reported before all phases completed");
            saw_pass = true;
            return;
        }

        fatalf("unexpected status code 0x%08x", code);
    }

    void verify_memory() {
        const uint32_t dst_word = DST_ADDR >> 1;
        for( uint32_t i = 0; i < COPY_WORDS * 2; i++ ) {
            uint16_t dst = sdram.read_word(0, dst_word + i);
            uint16_t expected = (i == 0) ? 0x0000 : 0x005a;
            if( dst != expected ) {
                fatalf("copy mismatch at halfword %u: expected=%04x dst=%04x", i, expected, dst);
            }
        }

        uint16_t rmw_hi = sdram.read_word(0, RMW_ADDR >> 1);
        uint16_t rmw_lo = sdram.read_word(0, (RMW_ADDR >> 1) + 1);
        if( rmw_hi != 0x0000 || rmw_lo != 0x007f ) {
            fatalf("rmw word mismatch: %04x %04x", rmw_hi, rmw_lo);
        }
    }

    void eval_and_update() {
        top.eval();
        update_sdram();
        top.eval();
#if VM_TRACE_FST
        if( trace ) trace->dump(main_time_ps);
#endif
    }

    void advance_subcycle(bool clk_sdram_val, bool clk_val) {
        top.clk_sdram = clk_sdram_val;
        top.clk = clk_val;
        top.cpu_din_ext = 0;
        g_sc_time_ps = static_cast<double>(main_time_ps);
        eval_and_update();
        check_cache_protocol();
        check_status_writes();
        if( (cycles & 0x3fffff) == 0 && clk_sdram_val && clk_val ) {
            std::fprintf(stderr,
                "PROGRESS cycle=%llu A=%08x CS3_N=%d RD_WR_N=%d cache_cs=%d cache_ok=%d\n",
                static_cast<unsigned long long>(cycles),
                static_cast<unsigned>(top.A),
                top.CS3_N ? 1 : 0,
                top.RD_WR_N ? 1 : 0,
                top.cache_cs ? 1 : 0,
                top.cache_ok ? 1 : 0);
        }

        main_time_ps += SUB_PS;
        sub_ps_err += SUB_PS_REM;
        if( sub_ps_err >= SUB_DEN ) {
            main_time_ps++;
            sub_ps_err -= SUB_DEN;
        }
    }

public:
    explicit Sim(bool trace_bus_) : sdram(10), trace_bus(trace_bus_) {
        top.clk = 0;
        top.clk_sdram = 0;
        top.rst = 1;
        top.cpu_din_ext = 0;
        top.sdram_dq = 0;
        sdram.reset();
        load_sdram_bank0();
#if VM_TRACE_FST
        Verilated::traceEverOn(true);
        trace = new VerilatedFstC;
        top.trace(trace, 99);
        trace->open("test.fst");
#endif
        eval_and_update();
    }

    ~Sim() {
#if VM_TRACE_FST
        if( trace ) {
            trace->close();
            delete trace;
            trace = nullptr;
        }
#endif
    }

    void tick() {
        advance_subcycle(1, 0);
        advance_subcycle(1, 1);
        advance_subcycle(0, 1);
        advance_subcycle(0, 0);
        cycles++;
    }

    void run(uint64_t timeout_ms, bool boot_only, uint64_t boot_timeout_ms) {
        top.rst = 1;
        for( int i = 0; i < 8; i++ ) tick();
        top.rst = 0;
        for( int timeout = 0; timeout < 200000; timeout++ ) {
            tick();
            if( top.init == 0 ) {
                break;
            }
            if( timeout == 199999 ) {
                fatal("timed out waiting for SDRAM init");
            }
        }
        for( int i = 0; i < 8; i++ ) tick();

        const uint64_t boot_deadline_ps = main_time_ps + boot_timeout_ms * 1000000ULL;
        while( !boot_seen && main_time_ps < boot_deadline_ps ) {
            tick();
            if( boot_seen ) {
                std::fprintf(stderr,
                    "BOOT_OK at cycle=%llu cache_reqs=%llu cache_oks=%llu\n",
                    static_cast<unsigned long long>(cycles),
                    static_cast<unsigned long long>(cache_req_count),
                    static_cast<unsigned long long>(cache_ok_count));
                if( boot_only ) {
                    return;
                }
                break;
            }
        }
        if( !boot_seen ) {
            fatal("timed out waiting for first cache completion (boot startup)");
        }

        const uint64_t timeout_ps = timeout_ms * 1000000000ULL;
        while( main_time_ps < timeout_ps ) {
            if( saw_pass ) {
                verify_memory();
                std::fprintf(stderr,
                    "PASS cycles=%llu cache_reqs=%llu cache_oks=%llu\n",
                    static_cast<unsigned long long>(cycles),
                    static_cast<unsigned long long>(cache_req_count),
                    static_cast<unsigned long long>(cache_ok_count));
                return;
            }
            tick();
        }

        fatal("timed out waiting for CPU PASS status");
    }
};

} // namespace

int main(int argc, char** argv) {
    Args args = parse_args(argc, argv);
    Sim sim(args.trace_bus);
    sim.run(args.timeout_ms, args.boot_only, args.boot_timeout_ms);
    return 0;
}
