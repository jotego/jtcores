#include <array>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>

#include "Vtest.h"
#include "sdram.h"
#include "verilated.h"
#if VM_TRACE_FST
#include "verilated_fst_c.h"
#endif

namespace {

static constexpr uint64_t CLK_HZ = 100000000ULL;
static constexpr uint64_t PS_PER_HALF = 1000000000000ULL / (CLK_HZ * 2ULL);
static constexpr uint32_t TOTAL_BYTES = 64U * 1024U * 1024U;
static constexpr uint32_t BANK_BYTES = 16U * 1024U * 1024U;
static constexpr uint32_t HEADER_BYTES = 32U;
static constexpr uint32_t PAGE_WORDS = 512U;
static constexpr uint32_t WORD_BYTES = 2U;
static constexpr uint32_t CHUNK_BYTES = 64U * 1024U;

enum class HeaderMode {
    None,
    Forward,
    Reverse,
};

struct Args {
    uint32_t bytes = TOTAL_BYTES;
    uint64_t seed = 0x64b51d397ac4e812ULL;
    uint64_t timeout_cycles = 0;
    bool keep_data = false;
    bool progress = false;
    HeaderMode header_mode = HeaderMode::None;
    std::string data_file = "download.bin";
};

static void usage(const char* argv0) {
    std::fprintf(stderr,
        "Usage: %s [--bytes N] [--seed N] [--timeout-cycles N] [--header-mode none|forward|reverse] [--keep-data] [--progress]\n",
        argv0);
}

static uint64_t parse_u64(const char* s, const char* opt) {
    char* end = nullptr;
    errno = 0;
    uint64_t v = std::strtoull(s, &end, 0);
    if (errno || end == s || *end != '\0') {
        std::fprintf(stderr, "ERROR: invalid value for %s: %s\n", opt, s);
        std::exit(1);
    }
    return v;
}

static Args parse_args(int argc, char** argv) {
    Args args;
    for (int i = 1; i < argc; i++) {
        std::string a = argv[i];
        if (a == "--bytes" && i + 1 < argc) {
            uint64_t v = parse_u64(argv[++i], "--bytes");
            if (v == 0 || v > TOTAL_BYTES) {
                std::fprintf(stderr, "ERROR: --bytes must be in range 1..%u\n", TOTAL_BYTES);
                std::exit(1);
            }
            args.bytes = static_cast<uint32_t>(v);
        } else if (a == "--seed" && i + 1 < argc) {
            args.seed = parse_u64(argv[++i], "--seed");
        } else if (a == "--timeout-cycles" && i + 1 < argc) {
            args.timeout_cycles = parse_u64(argv[++i], "--timeout-cycles");
        } else if (a == "--file" && i + 1 < argc) {
            args.data_file = argv[++i];
        } else if (a == "--header-mode" && i + 1 < argc) {
            std::string mode = argv[++i];
            if (mode == "none") {
                args.header_mode = HeaderMode::None;
            } else if (mode == "forward") {
                args.header_mode = HeaderMode::Forward;
            } else if (mode == "reverse") {
                args.header_mode = HeaderMode::Reverse;
            } else {
                std::fprintf(stderr, "ERROR: invalid value for --header-mode: %s\n", mode.c_str());
                std::exit(1);
            }
        } else if (a == "--keep-data") {
            args.keep_data = true;
        } else if (a == "--progress") {
            args.progress = true;
        } else if (a == "-h" || a == "--help") {
            usage(argv[0]);
            std::exit(0);
        } else {
            usage(argv[0]);
            std::fprintf(stderr, "ERROR: unknown argument '%s'\n", a.c_str());
            std::exit(1);
        }
    }
    uint32_t max_bytes = args.header_mode == HeaderMode::None ? TOTAL_BYTES : TOTAL_BYTES - HEADER_BYTES;
    if (args.bytes > max_bytes) {
        std::fprintf(stderr, "ERROR: --bytes must be in range 1..%u with this header mode\n", max_bytes);
        std::exit(1);
    }
    if (args.bytes & 1U) {
        std::fprintf(stderr, "ERROR: --bytes must be even so readback CRC can use whole 16-bit words\n");
        std::exit(1);
    }
    return args;
}

class CRC32 {
    std::array<uint32_t, 256> table {};
    uint32_t crc = 0xffffffffU;

public:
    CRC32() {
        for (uint32_t i = 0; i < table.size(); i++) {
            uint32_t v = i;
            for (int bit = 0; bit < 8; bit++) {
                v = (v & 1U) ? ((v >> 1) ^ 0xedb88320U) : (v >> 1);
            }
            table[i] = v;
        }
    }

    void reset() {
        crc = 0xffffffffU;
    }

    void update(uint8_t v) {
        crc = (crc >> 8) ^ table[(crc ^ v) & 0xffU];
    }

    void update(const uint8_t* data, size_t len) {
        for (size_t i = 0; i < len; i++) update(data[i]);
    }

    uint32_t value() const {
        return ~crc;
    }
};


static uint32_t header_size(const Args& args) {
    return args.header_mode == HeaderMode::None ? 0U : HEADER_BYTES;
}

static std::array<uint8_t, HEADER_BYTES> make_balut_header(HeaderMode mode) {
    std::array<uint8_t, HEADER_BYTES> header {};
    const std::array<uint16_t, 5> words { 0x0000U, 0x0100U, 0x0200U, 0x0300U, 0xffffU };
    for (size_t i = 0; i < words.size(); i++) {
        uint16_t word = words[i];
        uint8_t hi = static_cast<uint8_t>(word >> 8);
        uint8_t lo = static_cast<uint8_t>(word & 0xffU);
        if (mode == HeaderMode::Reverse) {
            header[i * 2U] = lo;
            header[i * 2U + 1U] = hi;
        } else {
            header[i * 2U] = hi;
            header[i * 2U + 1U] = lo;
        }
    }
    return header;
}

static uint8_t next_random(uint64_t& state) {
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return static_cast<uint8_t>(state >> 24);
}

static std::array<uint32_t, 4> make_download_file(const Args& args) {
    std::array<CRC32, 4> crc;
    std::array<uint32_t, 4> out {};
    std::vector<uint8_t> buf(CHUNK_BYTES);
    uint64_t state = args.seed;
    uint32_t written = 0;

    FILE* f = std::fopen(args.data_file.c_str(), "wb");
    if (!f) {
        std::fprintf(stderr, "ERROR: creating %s: %s\n", args.data_file.c_str(), std::strerror(errno));
        std::exit(1);
    }

    if (args.header_mode != HeaderMode::None) {
        auto header = make_balut_header(args.header_mode);
        if (std::fwrite(header.data(), 1, header.size(), f) != header.size()) {
            std::fprintf(stderr, "ERROR: writing header to %s\n", args.data_file.c_str());
            std::exit(1);
        }
    }

    while (written < args.bytes) {
        uint32_t chunk = args.bytes - written;
        if (chunk > buf.size()) chunk = static_cast<uint32_t>(buf.size());
        for (uint32_t i = 0; i < chunk; i++) {
            buf[i] = next_random(state);
        }
        if (std::fwrite(buf.data(), 1, chunk, f) != chunk) {
            std::fprintf(stderr, "ERROR: writing %s\n", args.data_file.c_str());
            std::exit(1);
        }

        uint32_t pos = written;
        uint32_t remaining = chunk;
        const uint8_t* p = buf.data();
        while (remaining != 0) {
            uint32_t bank = pos / BANK_BYTES;
            uint32_t bank_left = BANK_BYTES - (pos % BANK_BYTES);
            uint32_t take = remaining < bank_left ? remaining : bank_left;
            crc[bank].update(p, take);
            pos += take;
            p += take;
            remaining -= take;
        }
        written += chunk;
    }

    if (std::fclose(f) != 0) {
        std::fprintf(stderr, "ERROR: closing %s\n", args.data_file.c_str());
        std::exit(1);
    }

    for (int bank = 0; bank < 4; bank++) out[bank] = crc[bank].value();
    return out;
}

class Sim {
    Vtest top;
    SDRAMModel sdram;
    uint64_t main_time_ps = 0;
    uint64_t cycles = 0;
    uint8_t last_clk = 0;
    bool progress = false;
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
        top.eval();
#if VM_TRACE_FST
        if (trace) trace->dump(main_time_ps);
#endif
    }

    void sdram_tick() {
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

        SDRAMOutputs out = sdram.tick(pins, main_time_ps);
        top.SDRAM_DQ = out.dq_drive ? out.dq : 0;
    }

    void half_tick(uint8_t clk) {
        top.clk = clk;
        eval_dump();
        if (last_clk && !clk) sdram_tick();
        last_clk = clk;
        main_time_ps += PS_PER_HALF;
    }

    void tick() {
        half_tick(1);
        half_tick(0);
        cycles++;
    }

    void check_timeout(uint64_t timeout_cycles) {
        if (timeout_cycles != 0 && cycles >= timeout_cycles) {
            fatal("simulation timeout reached");
        }
    }

    void wait_init(uint64_t timeout_cycles) {
        for (int i = 0; i < 20; i++) tick();
        top.rst = 0;
        for (uint32_t wait = 0; wait < 20000; wait++) {
            tick();
            check_timeout(timeout_cycles);
            if (!top.init) return;
        }
        fatal("timed out waiting for SDRAM init");
    }

    void wait_prog_ready(uint64_t timeout_cycles) {
        bool saw_low = false;
        for (uint32_t wait = 0; wait < 1000; wait++) {
            tick();
            check_timeout(timeout_cycles);
            if (!top.prog_rdy) {
                saw_low = true;
            } else if (saw_low) {
                return;
            }
        }
        fatal("timed out waiting for a fresh prog_rdy pulse");
    }

    void wait_ack(uint64_t timeout_cycles) {
        for (uint32_t wait = 0; wait < 1000; wait++) {
            tick();
            check_timeout(timeout_cycles);
            if (top.ack) return;
        }
        fatal("timed out waiting for read ack");
    }

    uint16_t read_word(uint32_t bank, uint32_t word_addr, uint64_t timeout_cycles) {
        top.addr = word_addr;
        top.ba = bank;
        top.rd = 1;
        wait_ack(timeout_cycles);
        for (uint32_t wait = 0; wait < 1000; wait++) {
            tick();
            check_timeout(timeout_cycles);
            if (top.dok) {
                uint16_t value = top.dout;
                top.rd = 0;
                for (uint32_t done_wait = 0; done_wait < 32; done_wait++) {
                    tick();
                    check_timeout(timeout_cycles);
                    if (top.rdy) return value;
                }
                fatal("timed out waiting for read completion");
            }
        }
        fatal("timed out waiting for read data");
    }

    void read_burst_crc(uint32_t bank, uint32_t word_addr, uint32_t words, CRC32& crc, uint64_t timeout_cycles) {
        top.addr = word_addr;
        top.ba = bank;
        top.rd = 1;
        wait_ack(timeout_cycles);

        uint32_t seen = 0;
        bool done = false;
        while (seen < words) {
            tick();
            check_timeout(timeout_cycles);
            if (top.dok) {
                uint16_t value = top.dout;
                crc.update(static_cast<uint8_t>(value & 0xff));
                crc.update(static_cast<uint8_t>(value >> 8));
                seen++;
                if (top.rdy) done = true;
                if (seen == words) top.rd = 0;
            }
        }

        if (!done) {
            for (uint32_t wait = 0; wait < 32; wait++) {
                tick();
                check_timeout(timeout_cycles);
                if (top.rdy) {
                    done = true;
                    break;
                }
            }
        }
        if (!done) fatal("timed out waiting for burst read completion");
        for (int i = 0; i < 4; i++) tick();
    }

public:
    explicit Sim(bool progress_) : sdram(10), progress(progress_) {
        top.clk = 0;
        top.rst = 1;
        top.ioctl_rom = 0;
        top.ioctl_addr = 0;
        top.ioctl_dout = 0;
        top.ioctl_wr = 0;
        top.addr = 0;
        top.ba = 0;
        top.rd = 0;
        top.SDRAM_DQ = 0;
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

    void run_download(const Args& args) {
        FILE* f = std::fopen(args.data_file.c_str(), "rb");
        if (!f) {
            fatalf("opening %s: %s", args.data_file.c_str(), std::strerror(errno));
        }

        wait_init(args.timeout_cycles);
        top.ioctl_rom = 1;

        std::vector<uint8_t> buf(CHUNK_BYTES);
        uint32_t transferred = 0;
        uint32_t transfer_bytes = args.bytes + header_size(args);
        while (transferred < transfer_bytes) {
            uint32_t chunk = transfer_bytes - transferred;
            if (chunk > buf.size()) chunk = static_cast<uint32_t>(buf.size());
            if (std::fread(buf.data(), 1, chunk, f) != chunk) {
                fatal("short read from generated download file");
            }
            for (uint32_t i = 0; i < chunk; i++) {
                uint32_t addr = transferred + i;
                top.ioctl_addr = addr;
                top.ioctl_dout = buf[i];
                top.ioctl_wr = 1;
                tick();
                check_timeout(args.timeout_cycles);
                top.ioctl_wr = 0;
                if (addr >= header_size(args)) {
                    wait_prog_ready(args.timeout_cycles);
                } else {
                    tick();
                    check_timeout(args.timeout_cycles);
                }
            }
            transferred += chunk;
            uint32_t payload_done = transferred > header_size(args) ? transferred - header_size(args) : 0U;
            if (progress && ((payload_done % BANK_BYTES) == 0 || payload_done == args.bytes)) {
                std::fprintf(stderr, "downloaded %u/%u bytes\n", payload_done, args.bytes);
            }
        }
        std::fclose(f);

        top.ioctl_wr = 0;
        top.ioctl_rom = 0;
        for (int i = 0; i < 256; i++) tick();
    }

    std::array<uint32_t, 4> readback_crc(uint32_t total_bytes, uint64_t timeout_cycles) {
        std::array<uint32_t, 4> out {};
        for (uint32_t bank = 0; bank < 4; bank++) {
            uint32_t bank_bytes = 0;
            if (total_bytes > bank * BANK_BYTES) {
                uint32_t remaining = total_bytes - bank * BANK_BYTES;
                bank_bytes = remaining < BANK_BYTES ? remaining : BANK_BYTES;
            }
            if (bank_bytes == 0) continue;

            CRC32 crc;
            uint32_t words = bank_bytes / WORD_BYTES;
            uint32_t word_addr = 0;
            while (word_addr < words) {
                uint32_t page_left = PAGE_WORDS - (word_addr % PAGE_WORDS);
                uint32_t remaining = words - word_addr;
                uint32_t count = remaining < page_left ? remaining : page_left;
                read_burst_crc(bank, word_addr, count, crc, timeout_cycles);
                word_addr += count;
            }
            out[bank] = crc.value();
            if (progress) {
                std::fprintf(stderr, "read bank %u crc=%08x\n", bank, out[bank]);
            }
        }
        return out;
    }

    uint64_t cycle_count() const {
        return cycles;
    }
};

} // namespace

int main(int argc, char** argv) {
    Args args = parse_args(argc, argv);

    try {
        std::array<uint32_t, 4> expected = make_download_file(args);
        Sim sim(args.progress);
        sim.run_download(args);
        std::array<uint32_t, 4> actual = sim.readback_crc(args.bytes, args.timeout_cycles);

        bool ok = true;
        for (int bank = 0; bank < 4; bank++) {
            uint32_t bank_bytes = 0;
            if (args.bytes > static_cast<uint32_t>(bank) * BANK_BYTES) {
                uint32_t remaining = args.bytes - static_cast<uint32_t>(bank) * BANK_BYTES;
                bank_bytes = remaining < BANK_BYTES ? remaining : BANK_BYTES;
            }
            if (bank_bytes == 0) continue;
            std::fprintf(stderr, "bank %d bytes=%u expected_crc=%08x actual_crc=%08x\n",
                bank, bank_bytes, expected[bank], actual[bank]);
            if (expected[bank] != actual[bank]) ok = false;
        }

        if (!args.keep_data) std::remove(args.data_file.c_str());
        if (!ok) {
            std::fprintf(stderr, "FAIL cycles=%llu\n", static_cast<unsigned long long>(sim.cycle_count()));
            return 1;
        }
        std::fprintf(stderr, "PASS cycles=%llu bytes=%u\n",
            static_cast<unsigned long long>(sim.cycle_count()), args.bytes);
        return 0;
    } catch (const char* msg) {
        std::fprintf(stderr, "ERROR: %s\n", msg);
    } catch (const std::exception& e) {
        std::fprintf(stderr, "ERROR: %s\n", e.what());
    }

    if (!args.keep_data) std::remove(args.data_file.c_str());
    return 1;
}
