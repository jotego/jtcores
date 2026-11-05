#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "UUT.h"
#include "verilated.h"
#if VM_TRACE_FST
#include "verilated_fst_c.h"
#endif
#include "sdram.h"

namespace fs = std::filesystem;

namespace {

struct DumpInfo {
    int id = 0;
    uint32_t source_reg = 0;
    uint32_t real_source = 0;
    uint32_t dest = 0;
    uint32_t fade = 0;
    uint32_t other2 = 0;
    uint32_t length_reg = 0;
    uint32_t trigger_data = 0;
    uint32_t dma_length = 0;
    std::string data_file;
    fs::path yaml_path;
    fs::path bin_path;
};

struct Args {
    fs::path dumps_dir = "dumps";
    int only_dump = -1;
    int limit = -1;
};

static std::string trim(const std::string& s) {
    std::size_t a = 0;
    std::size_t b = s.size();
    while( a < b && std::isspace(static_cast<unsigned char>(s[a])) ) a++;
    while( b > a && std::isspace(static_cast<unsigned char>(s[b - 1])) ) b--;
    return s.substr(a, b - a);
}

static uint32_t parse_u32(const std::string& s) {
    return static_cast<uint32_t>(std::strtoul(trim(s).c_str(), nullptr, 0));
}

static void usage(const char* argv0) {
    std::fprintf(stderr,
        "Usage: %s [--dumps path] [--dump id] [--limit count]\n",
        argv0);
}

static Args parse_args(int argc, char** argv) {
    Args args;
    for( int i = 1; i < argc; i++ ) {
        std::string a = argv[i];
        if( a == "--dumps" && i + 1 < argc ) {
            args.dumps_dir = argv[++i];
        } else if( a == "--dump" && i + 1 < argc ) {
            args.only_dump = std::atoi(argv[++i]);
        } else if( a == "--limit" && i + 1 < argc ) {
            args.limit = std::atoi(argv[++i]);
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

static DumpInfo load_dump_yaml(const fs::path& yaml_path) {
    DumpInfo info;
    info.yaml_path = yaml_path;

    std::ifstream fin(yaml_path);
    if( !fin ) {
        std::fprintf(stderr, "ERROR: could not open '%s'\n", yaml_path.c_str());
        std::exit(1);
    }

    std::string stem = yaml_path.stem().string();
    info.id = std::atoi(stem.c_str());

    std::string line;
    while( std::getline(fin, line) ) {
        std::size_t colon = line.find(':');
        if( colon == std::string::npos ) continue;
        std::string key = trim(line.substr(0, colon));
        std::string val = trim(line.substr(colon + 1));
        if( key == "source_reg" ) info.source_reg = parse_u32(val);
        else if( key == "real_source" ) info.real_source = parse_u32(val);
        else if( key == "dest" ) info.dest = parse_u32(val);
        else if( key == "fade" ) info.fade = parse_u32(val);
        else if( key == "other2" ) info.other2 = parse_u32(val);
        else if( key == "length_reg" ) info.length_reg = parse_u32(val);
        else if( key == "trigger_data" ) info.trigger_data = parse_u32(val);
        else if( key == "dma_length" ) info.dma_length = parse_u32(val);
        else if( key == "data_file" ) info.data_file = val;
    }

    info.bin_path = yaml_path.parent_path() / info.data_file;
    return info;
}

static std::vector<DumpInfo> load_dump_list(const Args& args) {
    if( !fs::is_directory(args.dumps_dir) ) {
        std::fprintf(stderr, "ERROR: dumps directory not found: %s\n",
            args.dumps_dir.c_str());
        std::exit(1);
    }

    std::vector<DumpInfo> dumps;
    for( const auto& ent : fs::directory_iterator(args.dumps_dir) ) {
        if( !ent.is_regular_file() ) continue;
        if( ent.path().extension() != ".yaml" ) continue;
        DumpInfo info = load_dump_yaml(ent.path());
        if( args.only_dump >= 0 && info.id != args.only_dump ) continue;
        dumps.push_back(info);
    }

    std::sort(dumps.begin(), dumps.end(),
        [](const DumpInfo& a, const DumpInfo& b) { return a.id < b.id; });

    if( args.limit >= 0 && static_cast<int>(dumps.size()) > args.limit ) {
        dumps.resize(args.limit);
    }

    if( dumps.empty() ) {
        std::fprintf(stderr, "ERROR: no dump files selected in %s\n",
            args.dumps_dir.c_str());
        std::exit(1);
    }
    return dumps;
}

static std::vector<uint8_t> load_file_bytes(const fs::path& path) {
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

static uint16_t read_be16(const std::vector<uint8_t>& buf, std::size_t word_idx) {
    std::size_t off = word_idx << 1;
    return (static_cast<uint16_t>(buf[off]) << 8) |
           static_cast<uint16_t>(buf[off + 1]);
}

static uint16_t bswap16(uint16_t v) {
    return static_cast<uint16_t>((v << 8) | (v >> 8));
}

static uint8_t fade_chan(uint8_t c, uint8_t f) {
    if( (f & 0x40) == 0 ) return c;
    if( f & 0x20 ) {
        uint16_t mul = static_cast<uint16_t>(31 - c) * static_cast<uint16_t>(31 - (f & 0x1f));
        return static_cast<uint8_t>(31 - ((mul >> 5) & 0x1f));
    }
    uint16_t mul = static_cast<uint16_t>(c) * static_cast<uint16_t>(f & 0x1f);
    return static_cast<uint8_t>((mul >> 5) & 0x1f);
}

static uint16_t apply_fade(uint16_t colour, uint32_t fade) {
    uint8_t r = fade_chan(colour & 0x1f, (fade >> 24) & 0x7f);
    uint8_t g = fade_chan((colour >> 5) & 0x1f, (fade >> 16) & 0x7f);
    uint8_t b = fade_chan((colour >> 10) & 0x1f, fade & 0x7f);
    return static_cast<uint16_t>((colour & 0x8000) | (b << 10) | (g << 5) | r);
}

class Sim {
public:
    Sim() : sdram(top) {
        eval();
#if VM_TRACE_FST
        Verilated::traceEverOn(true);
        trace = new VerilatedFstC;
        top.trace(trace, 99);
        trace->open("test.fst");
#endif
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

    void reset() {
        top.rst = 1;
        for( int i = 0; i < 8; i++ ) tick();
        top.rst = 0;
        for( int i = 0; i < 8; i++ ) tick();
    }

    void wait_init_done() {
        for( int timeout = 0; timeout < 200000; timeout++ ) {
            tick();
            if( top.init == 0 ) return;
        }
        fatal("Timed out waiting for SDRAM init");
    }

    void run_dump(const DumpInfo& info) {
        std::vector<uint8_t> ref = load_file_bytes(info.bin_path);
        if( (ref.size() & 1U) != 0 ) {
            fatalf("Dump %d has odd-sized BIN file %s", info.id, info.bin_path.c_str());
        }
        if( ref.size() != static_cast<std::size_t>(info.dma_length) * 2U ) {
            fatalf("Dump %d size mismatch: bin=%zu dma_length=%u",
                info.id, ref.size(), info.dma_length);
        }

        uint32_t derived_real = (info.source_reg << 1) - 0x400000U;
        if( derived_real != info.real_source ) {
            fatalf("Dump %d source decode mismatch: derived=0x%08x yaml=0x%08x",
                info.id, derived_real, info.real_source);
        }

        top.paldma_src = info.source_reg;
        top.paldma_dst = info.dest;
        top.paldma_fade = info.fade;
        top.paldma_len = static_cast<uint16_t>(info.dma_length & 0xffffU);
        top.paldma_len_hi = (info.dma_length >> 16) & 1U;
        if( (info.trigger_data & 2U) == 0 ) {
            fatalf("Dump %d has no palette DMA trigger bit set", info.id);
        }
        top.paldma_go = 1;
        bool last_src_ok = top.dbg_src_ok != 0;
        uint32_t dbg_addr[4] = {0, 0, 0, 0};
        uint16_t dbg_data[4] = {0, 0, 0, 0};
        int dbg_count = 0;
        tick();
        tick();
        top.paldma_go = 0;

        bool saw_busy = false;
        for( int timeout = 0; timeout < 2000000; timeout++ ) {
            tick();
            if( top.paldma_busy ) saw_busy = true;
            bool src_ok = top.dbg_src_ok != 0;
            if( src_ok && !last_src_ok && dbg_count < 4 ) {
                dbg_addr[dbg_count] = static_cast<uint32_t>(top.dbg_src_addr);
                dbg_data[dbg_count] = static_cast<uint16_t>(top.dbg_src_dout);
                dbg_count++;
            }
            last_src_ok = src_ok;
            if( top.paldma_done ) break;
            if( timeout == 1999999 ) {
                fatalf("Timed out waiting for DMA completion on dump %d", info.id);
            }
        }
        tick();

        if( info.dma_length != 0 && !saw_busy ) {
            fatalf("DMA %d completed without ever asserting busy", info.id);
        }

        verify_palette(info, ref, dbg_addr, dbg_data, dbg_count);
        std::printf("PASS dump=%d src=0x%08x real=0x%08x dst=0x%08x len=0x%x fade=0x%08x\n",
            info.id, info.source_reg, info.real_source, info.dest,
            info.dma_length, info.fade);
    }

private:
    UUT top;
    SDRAM sdram;
    uint64_t main_time_ps = 0;
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

    void eval() {
        top.eval();
        sdram.update();
#if VM_TRACE_FST
        if( trace ) trace->dump(main_time_ps);
#endif
    }

    void advance_time(uint64_t delta_ps) {
        main_time_ps += delta_ps;
        eval();
    }

    void tick() {
        top.clk_sdram = 1;
        advance_time(2500);

        top.clk = 1;
        advance_time(2500);

        top.clk_sdram = 0;
        advance_time(2500);

        top.clk = 0;
        advance_time(2500);
    }

    uint16_t read_palette_word(uint32_t word_addr) {
        top.pal_rd_addr = word_addr;
        tick();
        tick();
        return static_cast<uint16_t>(top.pal_rd_data);
    }

    void verify_palette(
        const DumpInfo& info,
        const std::vector<uint8_t>& ref,
        const uint32_t dbg_addr[4],
        const uint16_t dbg_data[4],
        int dbg_count
    ) {
        uint32_t dst_base = info.dest;
        for( uint32_t i = 0; i < info.dma_length; i++ ) {
            uint32_t dst_addr = (dst_base + i) ^ 1U;
            uint16_t raw = read_be16(ref, i);
            uint16_t expect = apply_fade(raw, info.fade);
            uint16_t got = read_palette_word(dst_addr);
            if( got != expect ) {
                for( int k = 0; k < dbg_count; k++ ) {
                    std::fprintf(stderr,
                        "DBG dump=%d src[%d] addr=0x%08x data=0x%04x\n",
                        info.id, k, dbg_addr[k], dbg_data[k]);
                }
                fatalf(
                    "Dump %d mismatch at word %u dst=0x%05x raw=0x%04x expect=0x%04x got=0x%04x swapped_expect=0x%04x real_src=0x%08x",
                    info.id, i, dst_addr, raw, expect, got, bswap16(expect),
                    info.real_source + (i << 1));
            }
        }
    }
};

} // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Args args = parse_args(argc, argv);
    std::vector<DumpInfo> dumps = load_dump_list(args);

    Sim sim;
    sim.reset();
    sim.wait_init_done();

    for( const auto& dump : dumps ) {
        sim.run_dump(dump);
    }

    std::printf("Verified %zu palette DMA dumps\n", dumps.size());
    return 0;
}
