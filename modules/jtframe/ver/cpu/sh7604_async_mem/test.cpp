#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>

#include "Vtest.h"
#include "Vtest___024root.h"
#include "verilated.h"
#if VM_TRACE_FST
#include "verilated_fst_c.h"
#endif

namespace {

static constexpr uint64_t CLK_HZ = 80000000ULL;
static constexpr uint64_t PS_PER_HALF = 1000000000000ULL / (CLK_HZ * 2ULL);

static constexpr uint32_t STATUS_COPY   = 0x00000011U;
static constexpr uint32_t STATUS_VERIFY = 0x00000022U;
static constexpr uint32_t STATUS_RMW    = 0x00000033U;
static constexpr uint32_t STATUS_PART   = 0x00000044U;
static constexpr uint32_t STATUS_SCAN   = 0x00000055U;
static constexpr uint32_t STATUS_PASS   = 0x00000066U;
static constexpr uint32_t STATUS_FAIL   = 0xdead0001U;

static constexpr uint32_t SRC_ADDR   = 0x00002000U;
static constexpr uint32_t DST_ADDR   = 0x00004000U;
static constexpr uint32_t RMW_ADDR   = 0x00005000U;
static constexpr uint32_t PART_ADDR  = 0x00005010U;
static constexpr uint32_t SCAN_ADDR  = 0x00008000U;
static constexpr uint32_t COPY_WORDS = 64U;
static constexpr uint32_t SCAN_WORDS = 2048U;

static double g_sc_time_ps = 0.0;

struct Args {
    uint64_t timeout_ms = 200;
    bool trace_bus = false;
};

static void usage(const char* argv0) {
    std::fprintf(stderr, "Usage: %s [--timeout milliseconds] [--trace-bus]\n", argv0);
}

static Args parse_args(int argc, char** argv) {
    Args args;
    for (int i = 1; i < argc; i++) {
        std::string a = argv[i];
        if (a == "--timeout" && i + 1 < argc) {
            args.timeout_ms = std::strtoull(argv[++i], nullptr, 0);
        } else if (a == "--trace-bus") {
            args.trace_bus = true;
        } else if (a == "-h" || a == "--help") {
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
    uint64_t main_time_ps = 0;
    uint64_t cycles = 0;
    uint32_t seen_phase = 0;
    uint32_t last_status = 0;
    bool saw_pass = false;
    bool trace_bus = false;
#if VM_TRACE_FST
    VerilatedFstC* trace = nullptr;
#endif

    [[noreturn]] void fatal(const char* msg) {
        std::fprintf(stderr, "ERROR: %s\n", msg);
        std::exit(1);
    }

    template <typename... ArgsT>
    [[noreturn]] void fatalf(const char* fmt, ArgsT... args) {
        std::fprintf(stderr, "ERROR: ");
        std::fprintf(stderr, fmt, args...);
        std::fprintf(stderr, "\n");
        std::exit(1);
    }

    void eval_dump() {
        g_sc_time_ps = static_cast<double>(main_time_ps);
        top.eval();
#if VM_TRACE_FST
        if (trace) trace->dump(main_time_ps);
#endif
    }

    void check_status() {
        if (!top.status_valid) return;

        const uint32_t code = top.status_code;
        if (code == last_status) return;
        last_status = code;

        std::fprintf(stderr, "STATUS code=%08x cycle=%llu A=%08x dout=%08x WE_N=%x\n",
            code,
            static_cast<unsigned long long>(cycles),
            static_cast<unsigned>(top.A),
            static_cast<unsigned>(top.cpu_dout),
            static_cast<unsigned>(top.WE_N));

        if (code == STATUS_FAIL) {
            fatal("CPU reported failure");
        }
        if (code == STATUS_COPY) {
            if (seen_phase != 0) fatal("copy status out of order");
            seen_phase = 1;
            return;
        }
        if (code == STATUS_VERIFY) {
            if (seen_phase != 1) fatal("verify status out of order");
            seen_phase = 2;
            return;
        }
        if (code == STATUS_RMW) {
            if (seen_phase != 2) fatal("rmw status out of order");
            seen_phase = 3;
            return;
        }
        if (code == STATUS_PART) {
            if (seen_phase != 3) fatal("partial-write status out of order");
            seen_phase = 4;
            return;
        }
        if (code == STATUS_SCAN) {
            if (seen_phase != 4) fatal("scan status out of order");
            seen_phase = 5;
            return;
        }
        if (code == STATUS_PASS) {
            if (seen_phase != 5) fatal("pass reported before all phases completed");
            saw_pass = true;
            return;
        }
        fatalf("unexpected status code %08x", code);
    }

    uint32_t read_mem32(uint32_t addr) {
        top.dbg_addr = addr & 0x00fffffcU;
        eval_dump();
        return top.dbg_data;
    }

    static uint32_t source_word(uint32_t i) {
        return 0x13570000U + (i * 0x1021U) + ((i & 15U) << 8) + (i ^ 0x5aU);
    }

    static uint32_t scan_word(uint32_t i) {
        return 0x24680000U + (i * 0x0101U) + ((i & 255U) << 4) + (i ^ 0xa5U);
    }

    void verify_memory() {
        for (uint32_t i = 0; i < COPY_WORDS; i++) {
            uint32_t src = read_mem32(SRC_ADDR + (i << 2));
            uint32_t dst = read_mem32(DST_ADDR + (i << 2));
            uint32_t exp = source_word(i);
            if (src != exp) {
                fatalf("source mismatch word %u: expected=%08x got=%08x", i, exp, src);
            }
            if (dst != exp) {
                fatalf("copy mismatch word %u: expected=%08x got=%08x", i, exp, dst);
            }
        }

        uint32_t rmw = read_mem32(RMW_ADDR);
        if (rmw != 0x135724a5U) {
            fatalf("read-modify-write mismatch: expected=135724a5 got=%08x", rmw);
        }

        uint32_t part = read_mem32(PART_ADDR);
        if (part != 0xaa771122U) {
            fatalf("partial-write mismatch: expected=aa771122 got=%08x", part);
        }

        uint32_t scan_xor = 0;
        for (uint32_t i = 0; i < SCAN_WORDS; i++) {
            uint32_t got = read_mem32(SCAN_ADDR + (i << 2));
            uint32_t exp = scan_word(i);
            if (got != exp) {
                fatalf("scan data mismatch word %u: expected=%08x got=%08x", i, exp, got);
            }
            scan_xor ^= got;
        }
        if (scan_xor != 0x001a0000U) {
            fatalf("scan xor mismatch: expected=001a0000 got=%08x", scan_xor);
        }
    }

    void half_tick(uint8_t clk) {
        top.clk = clk;
        eval_dump();
        if (clk) {
            check_status();
            if (top.ce_r && top.ce_f) {
                fatal("CE_R and CE_F overlapped");
            }
            if (trace_bus && (top.cache_cs || !top.BS_N || (cycles & 0xffffU) == 0)) {
                uint32_t pc = top.rootp->test__DOT__u_cpu__DOT__u_cpu__DOT__core__DOT__NPC;
                uint16_t ir = top.rootp->test__DOT__u_cpu__DOT__u_cpu__DOT__core__DOT__PIPE.__PVT__ID.__PVT__IR;
                uint32_t ibus_di = top.rootp->test__DOT__u_cpu__DOT__u_cpu__DOT__IBUS_DI;
                std::fprintf(stderr,
                    "BUS cycle=%llu pc=%08x ir=%04x ibus_di=%08x A=%08x din=%08x dout=%08x bs=%d cs0=%d cs3=%d rdwr=%d rd=%d we=%x wait=%d cache_cs=%d rd=%d wr=%d caddr=%08x cdin=%08x dsn=%x ok=%d ce_r=%d ce_f=%d\n",
                    static_cast<unsigned long long>(cycles),
                    static_cast<unsigned>(pc),
                    static_cast<unsigned>(ir),
                    static_cast<unsigned>(ibus_di),
                    static_cast<unsigned>(top.A),
                    static_cast<unsigned>(top.cpu_din_mon),
                    static_cast<unsigned>(top.cpu_dout),
                    top.BS_N ? 1 : 0,
                    top.CS0_N ? 1 : 0,
                    top.CS3_N ? 1 : 0,
                    top.RD_WR_N ? 1 : 0,
                    top.RD_N ? 1 : 0,
                    static_cast<unsigned>(top.WE_N),
                    top.WAIT_N ? 1 : 0,
                    top.cache_cs ? 1 : 0,
                    top.cache_rd ? 1 : 0,
                    top.cache_wr ? 1 : 0,
                    static_cast<unsigned>(top.cache_addr),
                    static_cast<unsigned>(top.cache_din),
                    static_cast<unsigned>(top.cache_dsn),
                    top.cache_ok ? 1 : 0,
                    top.ce_r ? 1 : 0,
                    top.ce_f ? 1 : 0);
            }
        }
        main_time_ps += PS_PER_HALF;
    }

public:
    explicit Sim(bool trace_bus_) : trace_bus(trace_bus_) {
        top.clk = 0;
        top.rst = 1;
        top.dbg_addr = 0;
#if VM_TRACE_FST
        Verilated::traceEverOn(true);
        trace = new VerilatedFstC;
        top.trace(trace, 99);
        trace->open("test.fst");
#endif
        eval_dump();
    }

    ~Sim() {
#if VM_TRACE_FST
        if (trace) {
            trace->close();
            delete trace;
            trace = nullptr;
        }
#endif
    }

    void tick() {
        half_tick(0);
        half_tick(1);
        cycles++;
    }

    void run(uint64_t timeout_ms) {
        for (int i = 0; i < 16; i++) tick();
        top.rst = 0;

        const uint64_t timeout_cycles = (CLK_HZ / 1000ULL) * timeout_ms;
        while (cycles < timeout_cycles) {
            tick();
            if (saw_pass) {
                verify_memory();
                std::fprintf(stderr, "PASS cycles=%llu time_ms=%llu\n",
                    static_cast<unsigned long long>(cycles),
                    static_cast<unsigned long long>(main_time_ps / 1000000000ULL));
                return;
            }
        }
        fatal("timed out waiting for CPU PASS status");
    }
};

} // namespace

int main(int argc, char** argv) {
    Args args = parse_args(argc, argv);
    Sim sim(args.trace_bus);
    sim.run(args.timeout_ms);
    return 0;
}
