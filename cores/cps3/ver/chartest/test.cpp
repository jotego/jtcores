#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <stdexcept>
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

static constexpr uint32_t TILES_BYTES = 0x400000;
static const bool kChardmaDebug = std::getenv("CHARDMA_DEBUG") != nullptr;

class FatalError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

struct Range {
    uint32_t dst = 0;
    uint32_t length = 0;
    uint32_t dump_offset = 0;
};

struct Command {
    int index = -1;
    int type = -1;
    uint32_t raw[3] = {0, 0, 0};
    uint32_t source = 0;
    uint32_t destination = 0;
    uint32_t requested_length = 0;
    uint32_t actual_length = 0;
    uint32_t table_address = 0;
    std::vector<Range> ranges;
};

struct DumpInfo {
    int id = 0;
    uint32_t list_address = 0;
    uint32_t list_bytes = 0;
    uint32_t source_reg = 0;
    uint32_t other_reg = 0;
    uint32_t commands = 0;
    uint32_t transfers = 0;
    std::string data_file;
    fs::path yaml_path;
    fs::path bin_path;
    std::vector<Command> cmd;
};

struct Args {
    fs::path dumps_dir = "dumps";
    int only_dump = -1;
    int first_dump = -1;
    int last_dump = -1;
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
        "Usage: %s [--dumps path] [--dump id] [--first id] [--last id] [--limit count]\n",
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
        } else if( a == "--first" && i + 1 < argc ) {
            args.first_dump = std::atoi(argv[++i]);
        } else if( a == "--last" && i + 1 < argc ) {
            args.last_dump = std::atoi(argv[++i]);
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

static int line_indent(const std::string& s) {
    int n = 0;
    while( n < static_cast<int>(s.size()) && s[n] == ' ' ) n++;
    return n;
}

static DumpInfo load_dump_yaml(const fs::path& yaml_path) {
    DumpInfo info;
    info.yaml_path = yaml_path;
    info.id = std::atoi(yaml_path.stem().string().c_str());

    std::ifstream fin(yaml_path);
    if( !fin ) {
        std::fprintf(stderr, "ERROR: could not open '%s'\n", yaml_path.c_str());
        std::exit(1);
    }

    Command* cur_cmd = nullptr;
    Range* cur_range = nullptr;
    bool in_ranges = false;
    std::string line;
    while( std::getline(fin, line) ) {
        int indent = line_indent(line);
        std::string t = trim(line);
        if( t.empty() ) continue;

        if( indent == 0 && t.rfind("cmd_", 0) == 0 && t.back() == ':' ) {
            info.cmd.push_back(Command());
            cur_cmd = &info.cmd.back();
            cur_cmd->index = std::atoi(t.substr(4).c_str());
            cur_range = nullptr;
            in_ranges = false;
            continue;
        }

        if( indent == 0 ) {
            std::size_t colon = t.find(':');
            if( colon == std::string::npos ) continue;
            std::string key = trim(t.substr(0, colon));
            std::string val = trim(t.substr(colon + 1));
            if( key == "list_address" ) info.list_address = parse_u32(val);
            else if( key == "list_bytes" ) info.list_bytes = parse_u32(val);
            else if( key == "source_reg" ) info.source_reg = parse_u32(val);
            else if( key == "other_reg" ) info.other_reg = parse_u32(val);
            else if( key == "commands" ) info.commands = parse_u32(val);
            else if( key == "transfers" ) info.transfers = parse_u32(val);
            else if( key == "data_file" ) info.data_file = val;
            continue;
        }

        if( !cur_cmd ) continue;

        if( indent == 2 && t == "ranges:" ) {
            in_ranges = true;
            cur_range = nullptr;
            continue;
        }

        if( indent == 2 ) {
            in_ranges = false;
            cur_range = nullptr;
            std::size_t colon = t.find(':');
            if( colon == std::string::npos ) continue;
            std::string key = trim(t.substr(0, colon));
            std::string val = trim(t.substr(colon + 1));
            if( key == "raw" ) {
                std::size_t lb = val.find('[');
                std::size_t rb = val.find(']');
                if( lb != std::string::npos && rb != std::string::npos && rb > lb ) {
                    std::string body = val.substr(lb + 1, rb - lb - 1);
                    std::stringstream ss(body);
                    std::string tok;
                    int idx = 0;
                    while( std::getline(ss, tok, ',') && idx < 3 ) {
                        cur_cmd->raw[idx++] = parse_u32(tok);
                    }
                }
            } else if( key == "type" ) cur_cmd->type = static_cast<int>(parse_u32(val));
            else if( key == "source" ) cur_cmd->source = parse_u32(val);
            else if( key == "destination" ) cur_cmd->destination = parse_u32(val);
            else if( key == "requested_length" ) cur_cmd->requested_length = parse_u32(val);
            else if( key == "actual_length" ) cur_cmd->actual_length = parse_u32(val);
            else if( key == "table_address" ) cur_cmd->table_address = parse_u32(val);
            continue;
        }

        if( in_ranges && indent == 4 && t == "[]" ) {
            continue;
        }

        if( in_ranges && indent == 4 && t.rfind("- ", 0) == 0 ) {
            cur_cmd->ranges.push_back(Range());
            cur_range = &cur_cmd->ranges.back();
            std::string rest = trim(t.substr(2));
            if( !rest.empty() ) {
                std::size_t colon = rest.find(':');
                if( colon != std::string::npos ) {
                    std::string key = trim(rest.substr(0, colon));
                    std::string val = trim(rest.substr(colon + 1));
                    if( key == "dst" ) cur_range->dst = parse_u32(val);
                    else if( key == "length" ) cur_range->length = parse_u32(val);
                    else if( key == "dump_offset" ) cur_range->dump_offset = parse_u32(val);
                }
            }
            continue;
        }

        if( in_ranges && cur_range && indent >= 6 ) {
            std::size_t colon = t.find(':');
            if( colon == std::string::npos ) continue;
            std::string key = trim(t.substr(0, colon));
            std::string val = trim(t.substr(colon + 1));
            if( key == "dst" ) cur_range->dst = parse_u32(val);
            else if( key == "length" ) cur_range->length = parse_u32(val);
            else if( key == "dump_offset" ) cur_range->dump_offset = parse_u32(val);
        }
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
        if( args.first_dump >= 0 && info.id < args.first_dump ) continue;
        if( args.last_dump >= 0 && info.id > args.last_dump ) continue;
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
        top.core_rst = 1;
        for( int i = 0; i < 8; i++ ) tick();
        top.rst = 0;
        top.core_rst = 0;
        for( int i = 0; i < 8; i++ ) tick();
    }

    void core_reset() {
        top.core_rst = 1;
        for( int i = 0; i < 8; i++ ) tick();
        top.core_rst = 0;
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
        uint64_t total_expected = 0;
        for( const auto& cmd : info.cmd ) {
            for( const auto& range : cmd.ranges ) {
                total_expected += range.length;
            }
        }
        if( total_expected != ref.size() ) {
            fatalf("Dump %d size mismatch: bin=%zu ranges=%llu",
                info.id, ref.size(), static_cast<unsigned long long>(total_expected));
        }

        load_command_list(info);
        verify_command_list(info);

        top.chardma_src_lo = static_cast<uint16_t>(info.source_reg & 0xffffU);
        top.chardma_src_hi = static_cast<uint8_t>((info.other_reg >> 16) & 0x3fU);
        if( ((info.other_reg >> 22) & 1U) == 0 ) {
            fatalf("Dump %d has no character DMA trigger bit set", info.id);
        }
        top.chardma_go = 1;
        tick();
        tick();
        top.chardma_go = 0;

        bool saw_busy = false;
        const int timeout_limit = 5000000 +
            static_cast<int>(std::min<uint64_t>(total_expected * 128ULL, 200000000ULL));
        for( int timeout = 0; timeout < timeout_limit; timeout++ ) {
            tick();
            if( top.dma_busy ) saw_busy = true;
            if( top.dma_done ) break;
            if( timeout == timeout_limit - 1 ) {
                fatalf("Timed out waiting for char DMA completion on dump %d", info.id);
            }
        }
        tick();
        wait_for_idle_bus();

        if( total_expected != 0 && !saw_busy ) {
            fatalf("Char DMA %d completed without ever asserting busy", info.id);
        }

        verify_ranges(info, ref);
        std::printf("PASS dump=%d list=0x%06x src=0x%08x other=0x%08x transfers=%u commands=%u\n",
            info.id, info.list_address, info.source_reg, info.other_reg,
            info.transfers, info.commands);
        std::fflush(stdout);
    }

private:
    UUT top;
    SDRAM sdram;
    uint64_t main_time_ps = 0;
#if VM_TRACE_FST
    VerilatedFstC* trace = nullptr;
#endif

    void fatal(const char* msg) {
        throw FatalError(msg);
    }

    template <typename... ArgsT>
    void fatalf(const char* fmt, ArgsT... args) {
        int len = std::snprintf(nullptr, 0, fmt, args...);
        if( len < 0 ) {
            throw FatalError("formatting fatal error failed");
        }
        std::vector<char> msg(static_cast<std::size_t>(len) + 1U);
        std::snprintf(msg.data(), msg.size(), fmt, args...);
        throw FatalError(std::string(msg.data()));
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

    void wait_for_idle_bus() {
        for( int timeout = 0; timeout < 256; timeout++ ) {
            if( !top.dma_busy && !top.dma_done ) {
                return;
            }
            tick();
        }
        fatal("Timed out waiting for DMA/cache bus to go idle");
    }

    uint32_t read_tiles_wr_word(uint32_t word_addr) {
        top.verify_addr = word_addr;
        top.verify_rd = 1;
        for( int timeout = 0; timeout < 2000; timeout++ ) {
            tick();
            if( top.verify_ok ) {
                uint32_t data = static_cast<uint32_t>(top.verify_data);
                top.verify_rd = 0;
                tick();
                return data;
            }
        }
        top.verify_rd = 0;
        fatalf("Timed out reading tiles_wr cache word 0x%x", word_addr);
        return 0;
    }

    uint32_t read_tiles_word(uint32_t word_addr) {
        top.verify_addr = word_addr;
        top.verify_gfx_rd = 1;
        for( int timeout = 0; timeout < 2000; timeout++ ) {
            tick();
            if( top.verify_ok ) {
                uint32_t data = static_cast<uint32_t>(top.verify_data);
                top.verify_gfx_rd = 0;
                tick();
                return data;
            }
        }
        top.verify_gfx_rd = 0;
        fatalf("Timed out reading tiles graphics cache word 0x%x", word_addr);
        return 0;
    }

    void write_tiles_word(uint32_t word_addr, uint32_t data) {
        top.verify_addr = word_addr;
        top.verify_din = data;
        top.verify_dsn = 0x0;
        top.verify_wr = 1;
        for( int timeout = 0; timeout < 2000; timeout++ ) {
            tick();
            if( top.verify_ok ) {
                top.verify_wr = 0;
                tick();
                return;
            }
        }
        top.verify_wr = 0;
        fatalf("Timed out writing tiles cache word 0x%x", word_addr);
    }

    uint8_t read_tiles_byte(uint32_t byte_addr) {
        uint32_t word = read_tiles_word(byte_addr >> 2);
        switch( byte_addr & 3U ) {
            case 0: return static_cast<uint8_t>(word >> 8);
            case 1: return static_cast<uint8_t>(word);
            case 2: return static_cast<uint8_t>(word >> 24);
            default: return static_cast<uint8_t>(word >> 16);
        }
    }

    static uint32_t pixel_order32(uint32_t v) {
        // Inverse of the test.v tiles_data halfword reorder.
        return ((v & 0x0000ff00U) << 16) |
               ((v & 0x000000ffU) << 16) |
               ((v & 0xff000000U) >> 16) |
               ((v & 0x00ff0000U) >> 16);
    }

    void load_command_list(const DumpInfo& info) {
        uint32_t word_addr = info.list_address;
        for( const auto& cmd : info.cmd ) {
            write_tiles_word(word_addr + 0, pixel_order32(cmd.raw[0]));
            write_tiles_word(word_addr + 1, pixel_order32(cmd.raw[1]));
            write_tiles_word(word_addr + 2, pixel_order32(cmd.raw[2]));
            word_addr += 3;
        }
        // Stop entry: the DMA exits when w0[24] is set.
        write_tiles_word(word_addr + 0, pixel_order32(0x01000000U));
        write_tiles_word(word_addr + 1, 0);
        write_tiles_word(word_addr + 2, 0);
    }

    void verify_command_list(const DumpInfo& info) {
        uint32_t word_addr = info.list_address;
        for( const auto& cmd : info.cmd ) {
            uint32_t expect0 = pixel_order32(cmd.raw[0]);
            uint32_t expect1 = pixel_order32(cmd.raw[1]);
            uint32_t expect2 = pixel_order32(cmd.raw[2]);
            uint32_t got0 = read_tiles_wr_word(word_addr + 0);
            uint32_t got1 = read_tiles_wr_word(word_addr + 1);
            uint32_t got2 = read_tiles_wr_word(word_addr + 2);
            if( got0 != expect0 || got1 != expect1 || got2 != expect2 ) {
                fatalf(
                    "Command list mismatch dump=%d word=0x%x expect=[0x%08x 0x%08x 0x%08x] got=[0x%08x 0x%08x 0x%08x]",
                    info.id, word_addr, expect0, expect1, expect2, got0, got1, got2);
            }
            word_addr += 3;
        }
    }

    void verify_ranges(const DumpInfo& info, const std::vector<uint8_t>& ref) {
        for( const auto& cmd : info.cmd ) {
            for( const auto& range : cmd.ranges ) {
                if( static_cast<uint64_t>(range.dump_offset) + range.length > ref.size() ) {
                    fatalf("Dump %d range overruns BIN: cmd=%d dump_offset=0x%x length=0x%x size=%zu",
                        info.id, cmd.index, range.dump_offset, range.length, ref.size());
                }
                for( uint32_t i = 0; i < range.length; i++ ) {
                    uint8_t expect = ref[range.dump_offset + i];
                    uint32_t phys_off = TILES_BYTES + range.dst + i;
                    uint8_t got = read_tiles_byte(range.dst + i);
                    if( got != expect ) {
                        bool swap_match = false;
                        if( (i ^ 1U) < range.length ) {
                            swap_match = ref[range.dump_offset + (i ^ 1U)] == got;
                        }
                        fatalf(
                            "Dump %d mismatch cmd=%d dst=0x%06x dump_off=0x%06x expect=0x%02x got=0x%02x bank3_off=0x%06x swap16_match=%s src=0x%08x table=0x%08x",
                            info.id, cmd.index, range.dst + i, range.dump_offset + i,
                            expect, got, phys_off, swap_match ? "yes" : "no",
                            cmd.source, cmd.table_address);
                    }
                }
            }
        }
    }
};

} // namespace

int main(int argc, char** argv) {
    try {
        Verilated::commandArgs(argc, argv);
        Args args = parse_args(argc, argv);
        std::vector<DumpInfo> dumps = load_dump_list(args);

        Sim sim;
        sim.reset();
        sim.wait_init_done();

        for( const auto& dump : dumps ) {
            sim.core_reset();
            sim.run_dump(dump);
        }

        std::printf("Verified %zu character DMA dumps\n", dumps.size());
        return 0;
    } catch( const FatalError& e ) {
        std::fprintf(stderr, "ERROR: %s\n", e.what());
        return 1;
    }
}
