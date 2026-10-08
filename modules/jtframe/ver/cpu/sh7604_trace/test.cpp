#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>

#include "Vtest.h"
#include "verilated.h"
#if VM_TRACE_FST
#include "verilated_fst_c.h"
#endif

namespace {

static constexpr uint64_t CLK_HZ = 80000000ULL;
static constexpr uint64_t PS_PER_HALF = 1000000000000ULL / (CLK_HZ * 2ULL);

static constexpr uint32_t STATUS_PASS = 0x55aa00ffU;
static constexpr uint32_t STATUS_CACHE = 0x55aa00c3U;
static constexpr uint32_t STATUS_FAIL = 0xdead0001U;
static constexpr uint32_t EXPECTED_SUM = 0x123456f4U;
static constexpr uint32_t EXPECTED_PR  = 0x00000434U;
static constexpr uint64_t ALL_MILESTONES = (1ULL << 28) - 1ULL;

static double g_sc_time_ps = 0.0;

enum Milestone : uint32_t {
    M_R13_LITERAL = 0,
    M_R14_LITERAL,
    M_JUMP_TARGET,
    M_MOV_IMM_R0,
    M_EXTU_R1,
    M_SHLL2_R1,
    M_ADD_IMM_R1,
    M_LITERAL_R2,
    M_MOV_R3,
    M_ADD_R3,
    M_LITERAL_R4,
    M_LOAD_R5,
    M_CMP_T,
    M_BSR_PR,
    M_DELAY_R8,
    M_SUB_R9,
    M_RTS_DELAY_R10,
    M_CACHE_LOW_FETCH,
    M_CACHE_STATUS_R0,
    M_CACHE_RETURN_R0,
    M_CACHE_STATUS,
    M_CHAIN_ADDR_R0,
    M_CHAIN_LOAD0_R0,
    M_CHAIN_LOAD1_R0,
    M_CHAIN_LOAD2_R0,
    M_STATUS_ADDR,
    M_STATUS_PASS_R0,
    M_PASS_STORE_PC
};

struct Args {
    uint64_t timeout_ms = 100;
    bool trace_commits = false;
};

struct TraceState {
    uint32_t seq = 0;
    uint32_t pc = 0;
    uint32_t sr = 0;
    uint32_t pr = 0;
    uint32_t r[16] = {};
};

static void usage(const char* argv0) {
    std::fprintf(stderr, "Usage: %s [--timeout milliseconds] [--trace-commits]\n", argv0);
}

static Args parse_args(int argc, char** argv) {
    Args args;
    for (int i = 1; i < argc; i++) {
        std::string a = argv[i];
        if (a == "--timeout" && i + 1 < argc) {
            args.timeout_ms = std::strtoull(argv[++i], nullptr, 0);
        } else if (a == "--trace-commits") {
            args.trace_commits = true;
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
    uint32_t last_trace_seq = 0;
    uint32_t last_status = 0;
    uint64_t seen = 0;
    bool cpu_reported_pass = false;
    bool saw_pass = false;
    bool trace_commits = false;
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

    TraceState trace_state() const {
        TraceState t;
        t.seq = top.trace_seq;
        t.pc  = top.trace_commit_pc;
        t.sr  = top.trace_sr;
        t.pr  = top.trace_pr;
        t.r[0]  = top.trace_r0;
        t.r[1]  = top.trace_r1;
        t.r[2]  = top.trace_r2;
        t.r[3]  = top.trace_r3;
        t.r[4]  = top.trace_r4;
        t.r[5]  = top.trace_r5;
        t.r[6]  = top.trace_r6;
        t.r[7]  = top.trace_r7;
        t.r[8]  = top.trace_r8;
        t.r[9]  = top.trace_r9;
        t.r[10] = top.trace_r10;
        t.r[11] = top.trace_r11;
        t.r[12] = top.trace_r12;
        t.r[13] = top.trace_r13;
        t.r[14] = top.trace_r14;
        t.r[15] = top.trace_r15;
        return t;
    }

    void mark(Milestone m) {
        seen |= 1ULL << static_cast<uint32_t>(m);
    }

    bool saw(Milestone m) const {
        return (seen & (1ULL << static_cast<uint32_t>(m))) != 0;
    }

    void expect_eq(const TraceState& t, const char* name, uint32_t got, uint32_t exp) {
        if (got != exp) {
            fatalf("TRACE mismatch at seq=%u pc=%08x %s expected=%08x got=%08x",
                t.seq, t.pc, name, exp, got);
        }
    }

    void check_trace_commit() {
        if (!top.trace_valid) return;

        TraceState t = trace_state();
        if (t.seq == last_trace_seq) return;
        last_trace_seq = t.seq;

        if (trace_commits &&
            ((t.pc >= 0x00000400U && t.pc < 0x00000480U) ||
             (t.pc >= 0x00000540U && t.pc < 0x00000560U))) {
            std::fprintf(stderr,
                "TRACE seq=%u pc=%08x sr=%08x pr=%08x r0=%08x r1=%08x r2=%08x r3=%08x r4=%08x r5=%08x r8=%08x r9=%08x r10=%08x r13=%08x r14=%08x\n",
                t.seq, t.pc, t.sr, t.pr, t.r[0], t.r[1], t.r[2], t.r[3],
                t.r[4], t.r[5], t.r[8], t.r[9], t.r[10], t.r[13], t.r[14]);
        }

        if (!saw(M_JUMP_TARGET) && t.pc >= 0x00000418U && t.pc < 0x00000460U) {
            expect_eq(t, "R13 after jump target reached", t.r[13], 0x00000410U);
            expect_eq(t, "R14 after jump target reached", t.r[14], 0x00000418U);
            mark(M_JUMP_TARGET);
        }
        if (!saw(M_BSR_PR) && t.pc >= 0x00000430U && t.pr == EXPECTED_PR) {
            mark(M_BSR_PR);
        }
        if (!saw(M_DELAY_R8) && t.r[8] == 0x00000055U && t.pr == EXPECTED_PR) {
            mark(M_DELAY_R8);
        }
        if (!saw(M_SUB_R9) && t.r[9] == 0x00000066U) {
            mark(M_SUB_R9);
        }
        if (!saw(M_RTS_DELAY_R10) && t.pc >= 0x00000434U && t.r[10] == 0x00000077U) {
            mark(M_RTS_DELAY_R10);
        }
        if (!saw(M_ADD_IMM_R1) && t.pc >= 0x00000420U && t.pc < 0x00000460U && t.r[1] == 0x0000007cU) {
            mark(M_ADD_IMM_R1);
        }
        if (!saw(M_ADD_R3) && t.pc >= 0x00000426U && t.pc < 0x00000460U && t.r[3] == EXPECTED_SUM) {
            mark(M_ADD_R3);
        }
        if (!saw(M_STATUS_ADDR) && t.r[14] == 0x06000000U) {
            mark(M_STATUS_ADDR);
        }
        if (!saw(M_STATUS_PASS_R0) && t.r[0] == STATUS_PASS) {
            mark(M_STATUS_PASS_R0);
        }
        if (cpu_reported_pass && seen == ALL_MILESTONES) {
            saw_pass = true;
        }

        switch (t.pc) {
        case 0x00000404U:
            expect_eq(t, "R13 after MOV.L literal", t.r[13], 0x00000410U);
            expect_eq(t, "R14 after MOV.L literal", t.r[14], 0x00000418U);
            mark(M_R13_LITERAL);
            mark(M_R14_LITERAL);
            break;
        case 0x0000041aU:
            expect_eq(t, "R0 after MOV immediate", t.r[0], 0x00000012U);
            mark(M_MOV_IMM_R0);
            break;
        case 0x0000041cU:
            expect_eq(t, "R1 after EXTU.B", t.r[1], 0x00000012U);
            mark(M_EXTU_R1);
            break;
        case 0x0000041eU:
            expect_eq(t, "R1 after SHLL2", t.r[1], 0x00000048U);
            mark(M_SHLL2_R1);
            break;
        case 0x00000420U:
            expect_eq(t, "R1 after ADD immediate", t.r[1], 0x0000007cU);
            mark(M_ADD_IMM_R1);
            break;
        case 0x00000422U:
            expect_eq(t, "R2 after MOV.L literal", t.r[2], 0x12345678U);
            mark(M_LITERAL_R2);
            break;
        case 0x00000424U:
            expect_eq(t, "R3 after MOV register", t.r[3], 0x12345678U);
            mark(M_MOV_R3);
            break;
        case 0x00000426U:
            expect_eq(t, "R3 after ADD register", t.r[3], EXPECTED_SUM);
            mark(M_ADD_R3);
            break;
        case 0x00000428U:
            expect_eq(t, "R4 after MOV.L data address", t.r[4], 0x00002000U);
            mark(M_LITERAL_R4);
            break;
        case 0x0000042cU:
            expect_eq(t, "R5 after MOV.L memory load", t.r[5], EXPECTED_SUM);
            mark(M_LOAD_R5);
            break;
        case 0x0000042eU:
            expect_eq(t, "SR.T after CMP/EQ", t.sr & 1U, 1U);
            mark(M_CMP_T);
            break;
        case 0x00000468U:
            expect_eq(t, "R14 after status literal", t.r[14], 0x06000000U);
            mark(M_STATUS_ADDR);
            break;
        case 0x0000046aU:
            expect_eq(t, "R0 after pass literal", t.r[0], STATUS_PASS);
            mark(M_STATUS_PASS_R0);
            break;
        case 0x0000046cU:
            expect_eq(t, "R0 at pass store", t.r[0], STATUS_PASS);
            expect_eq(t, "R14 at pass store", t.r[14], 0x06000000U);
            mark(M_PASS_STORE_PC);
            break;
        case 0x00000548U:
            expect_eq(t, "R0 after cache status literal", t.r[0], STATUS_CACHE);
            mark(M_CACHE_STATUS_R0);
            break;
        case 0x0000054cU:
            expect_eq(t, "R0 after cache return literal", t.r[0], 0x0000044cU);
            mark(M_CACHE_RETURN_R0);
            break;
        case 0x00000460U:
            expect_eq(t, "R0 before chained MOV.L @R0,R0", t.r[0], 0x00000010U);
            mark(M_CHAIN_ADDR_R0);
            break;
        case 0x00000462U:
            expect_eq(t, "R0 after first chained MOV.L @R0,R0", t.r[0], 0x00002034U);
            mark(M_CHAIN_LOAD0_R0);
            break;
        case 0x00000464U:
            expect_eq(t, "R0 after second chained MOV.L @R0,R0", t.r[0], 0x00002398U);
            mark(M_CHAIN_LOAD1_R0);
            break;
        case 0x00000466U:
            expect_eq(t, "R0 after third chained MOV.L @R0,R0", t.r[0], 0x00002394U);
            mark(M_CHAIN_LOAD2_R0);
            break;
        default:
            break;
        }
    }

    void check_cache_target_fetch() {
        const uint32_t byte_addr = static_cast<uint32_t>(top.cache_addr) << 1;
        if (top.cache_cs && top.cache_rd && byte_addr >= 0x00000540U && byte_addr < 0x00000580U) {
            if ((top.trace_pc >> 29) == 0x6U) {
                fatalf("TRACE_PC stale during low fetch: cache_addr=%08x trace_pc=%08x",
                    byte_addr, static_cast<uint32_t>(top.trace_pc));
            }
            mark(M_CACHE_LOW_FETCH);
        }
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
        if (code == STATUS_CACHE) {
            mark(M_CACHE_STATUS);
            return;
        }
        if (code != STATUS_PASS) {
            fatalf("unexpected status code %08x", code);
        }
        cpu_reported_pass = true;
        mark(M_PASS_STORE_PC);
        if (seen == ALL_MILESTONES) saw_pass = true;
    }

    void half_tick(uint8_t clk) {
        top.clk = clk;
        eval_dump();
        if (clk) {
            check_cache_target_fetch();
            check_trace_commit();
            check_status();
            if (top.ce_r && top.ce_f) {
                fatal("CE_R and CE_F overlapped");
            }
        }
        main_time_ps += PS_PER_HALF;
    }

public:
    explicit Sim(bool trace_commits_) : trace_commits(trace_commits_) {
        top.clk = 0;
        top.rst = 1;
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
                std::fprintf(stderr, "PASS cycles=%llu time_ms=%llu\n",
                    static_cast<unsigned long long>(cycles),
                    static_cast<unsigned long long>(main_time_ps / 1000000000ULL));
                return;
            }
        }
        fatalf("timed out waiting for CPU PASS status: seen=%05llx expected=%05llx missing=%05llx",
            static_cast<unsigned long long>(seen),
            static_cast<unsigned long long>(ALL_MILESTONES),
            static_cast<unsigned long long>(ALL_MILESTONES & ~seen));
    }
};

} // namespace

double sc_time_stamp() {
    return g_sc_time_ps;
}

int main(int argc, char** argv) {
    Args args = parse_args(argc, argv);
    Sim sim(args.trace_commits);
    sim.run(args.timeout_ms);
    return 0;
}
