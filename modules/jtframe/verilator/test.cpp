/*  This file is part of JT_FRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 9-5-2022 */

// All screen output should go through stderr using C functions
// Do not use C++ IO functions like cout or cerr because it
// can mess up with verilog $display and $fdisplay calls
// see https://github.com/verilator/verilator/issues/3799

#include <cstring>
#include <cstdlib>
#include <cerrno>
#include <fstream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>
#include <sys/stat.h>
#include "UUT.h"
#include "cabinet.h"
#include "cheats.h"
#include "defmacros.h"
#include "sim_utils.h"
#include "sdram.h"
#include "wavewritter.h"

#include <sys/types.h>
#include <unistd.h>
#include <sys/wait.h>

#ifdef _DUMP
    #include "verilated_vcd_c.h"
#endif

#ifndef _DUMP_START
    const int _DUMP_START=0;
#endif

#ifndef _JTFRAME_COLORW
    #define _JTFRAME_COLORW 4
#endif

using namespace std;

#ifndef _JTFRAME_SIM_DIPS
    #define _JTFRAME_SIM_DIPS 0xffffffff
#endif

#if _JTFRAME_SIM96 || _JTFRAME_SDRAM96
const bool use96 = true;
#else
const bool use96 = false;
#endif

#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_MAGENTA "\x1b[35m"
#define ANSI_COLOR_CYAN    "\x1b[36m"
#define ANSI_COLOR_RESET   "\x1b[0m"

uint32_t crcTable[256];

void makeCRCTable() {
    uint32_t crc;
    for (uint32_t i = 0; i < 256; i++) {
        crc = i;
        for (uint32_t j = 0; j < 8; j++) {
            crc = (crc & 1) ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
        }
        crcTable[i] = crc;
    }
}

uint32_t calcCRC32( char *data, int len) {
    uint32_t crc = 0xFFFFFFFF;
    for (size_t i = 0; i < len; i++) {
        uint8_t byte = (uint8_t)data[i];
        crc = (crc >> 8) ^ crcTable[(crc ^ byte) & 0xFF];
    }
    return ~crc;
}

void storeCRC( char *data, int len ) {
    uint32_t crc32 = calcCRC32(data,len);
    ofstream of("frames/frames.crc",std::ios::app);
    if( of.is_open() ) {
        of << hex << crc32 << endl;
    }
}

class MultiClock {
protected:
    int cnt;
    UUT& game;
    vluint64_t semi;
public:
    MultiClock(UUT& g) : game(g) {
        cnt=0;
#ifdef _JTFRAME_MCLK
        semi = (vluint64_t)(1e12/(_JTFRAME_MCLK));
    #if !(_JTFRAME_SIM96 || _JTFRAME_SDRAM96)
        semi >>= 1;
    #endif
#else
        semi = (vluint64_t)10416;
#endif
    }
    virtual void advance_half_period()=0;
    virtual vluint64_t get_semi_period() { return semi; }
};

class MultiClock48 : MultiClock {
public:
    MultiClock48(UUT& g) : MultiClock(g) { }
    virtual void advance_half_period();
};

class MultiClock96 : MultiClock {
public:
    MultiClock96(UUT& g) : MultiClock(g) { semi/=2; }
    virtual void advance_half_period();
};

MultiClock* MakeMultiClock(UUT& game) {
    return use96 ? (MultiClock*)new MultiClock96(game):
                   (MultiClock*)new MultiClock48(game);
}

void MultiClock48::advance_half_period() {
    game.clk24 = (cnt>>1)&1;
    cnt++;
    game.clk   =  cnt    &1;
#ifdef _JTFRAME_CLK48
    game.clk48 =  game.clk;
#endif
}

void MultiClock96::advance_half_period() {
    game.clk48 = (cnt>>1)&1;
    cnt++;
    cnt&=7;
    game.clk24 = (cnt>6 || cnt<=2) ? 1 : 0;
    game.clk96 =  cnt    &1;
#ifdef _JTFRAME_SDRAM96
    game.clk   =  game.clk96;
#else
    game.clk   =  game.clk48;
#endif
}

class SimInputs {
    UUT& dut;
    SDRAM& sdram;
    unique_ptr<CabinetScript> cab;
    unique_ptr<CheatDatabase> cheat_db;
    vector<string> pending_cheats;
    int line = 0;
    bool done = true;
    bool has_dipsw = false;
    bool has_pending = false;
    bool rst_assigned = false;
    bool trace_requested = false;
    bool dump_requested = false;
    unsigned dipsw = 0;
    string cheat_target;

    void apply_pending_cheats() {
        if( !has_pending ) return;
        if( !cheat_db ) {
            throw runtime_error("cabinet script requests a cheat but JTFRAME_SIM_CHEATS is not set");
        }
        if( !cheat_db->has_target(cheat_target) ) {
            throw runtime_error("cabinet script requests a cheat but no cheats target set '" + cheat_target + "'");
        }
        for( const auto& name : pending_cheats ) {
            const vector<CheatWrite>* writes = cheat_db->find(cheat_target, name);
            if( writes == nullptr ) {
                throw runtime_error("cabinet script requests unknown cheat '" + name + "' for target '" + cheat_target + "'");
            }
            for( const auto& write : *writes ) sdram.write_bytes(write.bank, write.offset, write.byte_mask, write.data);
            fprintf(stderr, "Applied cheat %s for %s (%zu SDRAM write%s)\n", name.c_str(), cheat_target.c_str(), writes->size(),
                writes->size() == 1 ? "" : "s");
        }
        pending_cheats.clear();
        has_pending = false;
    }
public:
    SimInputs( UUT& _dut, SDRAM& _sdram, const char *filename) : dut(_dut), sdram(_sdram) {
        dut.dip_pause = 1;
        dut.joystick1 = 0xff;
        dut.joystick2 = 0xff;
        dut.joystick3 = 0xff;
        dut.joystick4 = 0xff;
        dut.cab_1p    = 0xf;
        dut.coin      = 0xf;
        dut.service   = 1;
        dut.tilt      = 1;
        dut.dip_test  = 1;
#ifdef _JTFRAME_OSD_FLIP
        dut.dip_flip  = 1;
#endif
        if( filename != nullptr && *filename != 0 ) {
            done = false;
            cab.reset(new CabinetScript(filename));
            fprintf(stderr, "Validated %llu frames from %s\n", static_cast<unsigned long long>(cab->frame_count()), filename);
            const char *cheat_file = getenv("JTFRAME_SIM_CHEATS");
            if( cheat_file != nullptr && *cheat_file != 0 ) {
                cheat_db.reset(new CheatDatabase(cheat_file));
                fprintf(stderr, "Loaded %zu cheat definitions for %zu target%s from %s\n", cheat_db->definition_count(),
                    cheat_db->target_count(), cheat_db->target_count() == 1 ? "" : "s", cheat_file);
            }
            const char *active_set = getenv("JTFRAME_SIM_SETNAME");
            cheat_target = active_set == nullptr ? "" : active_set;
            next();
        }
    }
    bool is_controlling_reset() { return rst_assigned; }
    bool has_cabinet_script() const { return cab != nullptr; }
    bool cabinet_done() const { return cab != nullptr && done; }
    bool take_tracing_on() {
        const bool requested = trace_requested;
        trace_requested = false;
        return requested;
    }
    bool take_dump() {
        const bool requested = dump_requested;
        dump_requested = false;
        return requested;
    }
    void restore_dipsw() {
        if( has_dipsw ) {
            dut.dipsw = dipsw;
            fprintf(stderr, "DIP sw overridden to %X (cabinet input frame %d)\n", dut.dipsw, line);
        }
    }
    void next() {
        apply_pending_cheats();
        if( !done && !cab->done() ) {
            ++line;
            const CabinetFrame& frame = cab->next();
            parse_inputs(frame.inputs);
            if( frame.has_dipsw ) {
                dipsw = frame.dipsw;
                has_dipsw = true;
                restore_dipsw();
            }
            pending_cheats = frame.cheats;
            has_pending = !pending_cheats.empty();
            if( frame.tracing_on ) trace_requested = true;
            if( frame.dump ) dump_requested = true;
        } else {
            if( !done && cab != nullptr && cab->done() ) {
                done = true;
                fprintf(stderr,"\ncabinet input file loaded through frame %d\n", line);
            }
            dut.cab_1p = 0xf;
            dut.coin   = 0xf;
            dut.joystick1    = 0x3ff;
            dut.joystick2    = 0x3ff;
        }
    }
    void parse_inputs( unsigned v ) {
        v = ~v;
        apply_reset(v);
        apply_joystick(v, 4,  dut.joystick1);
        apply_joystick(v, 14, dut.joystick2);
        auto coin_l   = dut.coin&3;
        dut.dip_test  = (v & 0x800) ? 1 : 0;
        dut.service   = (v & 0x002) ? 1 : 0;
        dut.cab_1p    = 0xc | ((v>>2)&3);
        dut.coin      = 0xc | (v&1) | ((v>>12)&2);
        if( coin_l != (dut.coin&3) && coin_l!=3 ) {
            fprintf(stderr, "\ncoin inserted (cabinet input frame %d)\n", line);
        }
    }
    void apply_reset(unsigned v) {
        const int RESET_BIT=0x1000;
        if( (v&RESET_BIT)!=0 && rst_assigned ) {
            rst_assigned = false;
            dut.rst  =0;
            dut.rst24=0;
            dut.rst96=0;
        }
        if( (v&RESET_BIT)==0 ) {
            if(!rst_assigned) fputs("\nReset forced through cabinet input file", stderr);
            rst_assigned = true;
            dut.rst  =1;
            dut.rst24=1;
            dut.rst96=1;
        }
    }
    void apply_joystick(unsigned v, int shift, decltype(dut.joystick1)& joystick) {
        joystick = 0x30f | ((v>>shift)&0xf0);
        v >>= shift;
        joystick = (joystick&0xf0) | (v&0xf);
#ifdef _JTFRAME_JOY_LRUD
        joystick = (joystick&0xf0) | ((v&3)<<2) | ((v>>2)&3);
#endif
#ifdef _JTFRAME_JOY_LRDU
        joystick = (joystick&0xf0) | ((v&3)<<2) | ((v>>3)&1) | ((v>>1)&2);
#endif
#ifdef _JTFRAME_JOY_RLDU
        joystick = (joystick&0xf0) | ((v&1)<<3) | ((v&2)<<1) | ((v&4)>>1) | ((v&8)>>3);
#endif
#ifdef _JTFRAME_JOY_RLUD
        joystick = (joystick&0xf0) | ((v&1)<<3) | ((v&2)<<1) | ((v&4)>>2) | ((v&8)>>2);
#endif
#ifdef _JTFRAME_JOY_DURL
        joystick = (joystick&0xf0) | ((v&8)>>1) | ((v&4)<<1) | ((v&2)>>1) | ((v&1)<<1);
#endif
#ifdef _JTFRAME_JOY_DULR
        joystick = (joystick&0xf0) | ((v&8)>>1) | ((v&4)<<1) | (v&3);
#endif
#ifdef _JTFRAME_JOY_UDRL
        joystick = (joystick&0xf0) | (v&0xc) | ((v&2)>>1) | ((v&1)<<1);
#endif
    }
};

int fileLength( const char *name ) {
    ifstream fin( name, ios_base::binary );
    if( !fin ) return 0;
    fin.seekg( 0, ios_base::end );
    const streamoff length = fin.tellg();
    return length > 0 ? static_cast<int>(length) : 0;
}

class Download {
    UUT& dut;
    int addr = 0;
    int ticks = 0;
    int iodump_ticks = 0;
    int zeroat = 0;
    int len = 0;
    int cart_start = 0;
    int nvram_start = 0;
    char *buf = nullptr;
    char *iodin = nullptr;
    bool done = false;
    bool cart = false;
    bool nvram = false;
    bool full_download = false;
    bool iodump_busy = false;
    bool iodump_pause = true;
    bool download_finished = false;
    string iodump_filename;
    int read_buf() {
        return (buf!=nullptr && addr<len) ? buf[addr] : 0;
    }
public:
    Download(UUT& _dut) : dut(_dut) {
        ifstream fin( "rom.bin", ios_base::binary );
        if( !fin ) {
            fputs("Verilator test.cpp: cannot open file rom.bin\n",stderr);
            return;
        }
        fin.seekg( 0, ios_base::end );
        len = (int)fin.tellg();
        int rom_len = len;
        if( len <= 0 || !fin ) {
            fputs("Verilator test.cpp: cannot open file rom.bin\n",stderr);
        } else {
            int cart_len = fileLength("cart.bin");
            if( cart_len > 0 ) {
                cart = true;
                cart_start = len;
                len += cart_len;
            }
            int nvram_len = fileLength("nvram.bin");
            if( nvram_len > 0 ) {
                nvram = true;
                nvram_start = len;
                len += nvram_len;
            }

            buf = new char[len];
            fin.seekg(0, ios_base::beg);
            fin.read(buf,rom_len);
            if( !fin ) {
                fputs("Verilator test.cpp: problem while reading rom.bin\n",stderr);
            } else {
                fprintf(stderr,"Read %d bytes from rom.bin\n",rom_len);
            }
            if( cart ) {
                ifstream fcart( "cart.bin", ios_base::binary );
                if( !fcart || !fcart.read( buf+cart_start, cart_len ) ) {
                    fputs("Verilator test.cpp: problem while reading cart.bin\n",stderr);
                } else {
                    fprintf(stderr,"Read %d bytes from cart.bin (starts at %x)\n",cart_len,cart_start);
                }
            }
            if( nvram ) {
                ifstream fcart( "nvram.bin", ios_base::binary );
                if( !fcart || !fcart.read( buf+nvram_start, nvram_len ) ) {
                    fputs("Verilator test.cpp: problem while reading nvram.bin\n",stderr);
                } else {
                    fprintf(stderr,"Read %d bytes from nvram.bin (starts at %x)\n",nvram_len,nvram_start);
                }
            }
        }
    };
    ~Download() {
        delete []buf;
        buf=nullptr;
        delete []iodin;
        iodin=nullptr;
    };
    bool FullDownload() { return full_download; }
    bool take_download_finished() {
        const bool finished = download_finished;
        download_finished = false;
        return finished;
    }
    void start( bool download ) {
        full_download = download;
        if( !full_download ) {
            if ( len > 32 ) {
                fputs("ROM download shortened to 32 bytes.\n",stderr);
                if( nvram ) fputs("Warning: skipping transfer of nvram.bin.\n",stderr);
                len=32;
            } else {
                fputs("Short ROM download\n",stderr);
            }
        }
        ticks = 0; zeroat = 0;
        done = false;
        download_finished = false;
        dut.ioctl_rom = 1;
        dut.ioctl_addr = 0;
        dut.ioctl_dout = read_buf();
        dut.ioctl_wr   = 0;
        addr = -1;
    }
    void update() {
#ifdef _JTFRAME_SIM96
        if(ticks==zeroat) dut.ioctl_wr = 0;
#else
        dut.ioctl_wr = 0;
#endif
        if( dut.ioctl_rom || dut.ioctl_ram ) step_download();
        if( iodump_busy ) iodump_step();
    }
    void step_download() {
        if( !done ) {
#ifdef _JTFRAME_SIM_SLOWLOAD
            const int STEP=31;
#else
            const int STEP=15;
#endif
            switch( ticks & STEP ) {
                case 0:
                    addr++;
                    dut.ioctl_addr = addr;
#ifdef _JTFRAME_CART_OFFSET
                    if( cart && addr>=cart_start ) {
                        dut.ioctl_addr += _JTFRAME_CART_OFFSET-cart_start;
                    }
#endif
#ifdef _JTFRAME_IOCTL_RD
                    if( nvram && addr>=nvram_start) {
                        dut.ioctl_addr -= nvram_start;
                        dut.ioctl_ram = 1;
                        dut.ioctl_rom = 0;
                    }
#endif
                    dut.ioctl_dout = read_buf();
                    break;
                case 1:
                    if( addr < len ) {
                        dut.ioctl_wr = 1;
                        zeroat = ticks+2;
                    } else {
#ifdef _JTFRAME_IOCTL_RD
                        dut.ioctl_ram   = 0;
#endif
                        dut.ioctl_rom = 0;
                        done = true;
                        download_finished = true;
                    }
                    break;
            }
            ticks++;
        } else {
            ticks=0;
        }
    }
    void iodump_step() {
#ifdef _JTFRAME_IOCTL_RD
        const int STEP=3;
        if( (iodump_ticks&STEP)==STEP) {
            iodin[dut.ioctl_addr] = dut.ioctl_din;
            if( ++dut.ioctl_addr == _JTFRAME_IOCTL_RD ) {
                fprintf(stderr,"\nIOCTL read finished\n");
                dut.ioctl_addr=0;
                dut.ioctl_ram=0;
                dut.dip_pause = iodump_pause;
                iodump_busy=false;
                ofstream of(iodump_filename,ios_base::binary);
                if( !of || !of.write(iodin,_JTFRAME_IOCTL_RD) ) {
                    fprintf(stderr,"ERROR: (test.cpp) creating %s\n", iodump_filename.c_str() );
                }
            }
        }
        iodump_ticks++;
#endif
    }
    bool iodump_start(const string& filename = "dump.bin") {
#ifdef _JTFRAME_IOCTL_RD
        if( iodump_busy ) return false;
        fprintf(stderr,"\nIOCTL read started\n");
        iodump_busy = true;
        iodump_filename = filename;
        iodump_pause = dut.dip_pause;
        dut.dip_pause = 0;
        dut.ioctl_addr=0;
        dut.ioctl_ram=1;
        iodump_ticks=0;
        if(iodin==nullptr) {
            iodin=new char[_JTFRAME_IOCTL_RD];
        }
        return true;
#else
        fprintf(stderr, "ERROR: (test.cpp) IOCTL dump requested but JTFRAME_IOCTL_RD is not defined\n");
        return false;
#endif
    }
};

const int VIDEO_BUFLEN = _JTFRAME_WIDTH*_JTFRAME_HEIGHT;

struct HarnessOptions {
    const char *cabinet_input = nullptr;
    bool explicit_video_limit = false;
    bool trace = false;
    int finish_time = 10;
    int finish_frame = -1;
};

static HarnessOptions parse_harness_options(int argc, char *argv[]) {
    HarnessOptions options;
    for( int k = 1; k < argc; k++ ) {
        if( strcmp(argv[k], "--inputs") == 0 ) {
            if( ++k >= argc || argv[k][0] == 0 ) throw runtime_error("--inputs requires a cabinet input file");
            if( options.cabinet_input != nullptr ) throw runtime_error("--inputs may only be specified once");
            options.cabinet_input = argv[k];
        } else if( strcmp(argv[k], "--video-limit") == 0 ) {
            options.explicit_video_limit = true;
        } else if( strcmp(argv[k], "--trace") == 0 ) {
            options.trace = true;
        } else if( strcmp(argv[k], "-time") == 0 ) {
            if( ++k >= argc ) throw runtime_error("expecting time after -time argument");
            options.finish_time = static_cast<int>(parse_number(argv[k], "simulation time"));
        }
    }
#ifdef _MAXFRAME
    options.finish_frame = _MAXFRAME;
#endif
    return options;
}

class JTSim {
    vluint64_t simtime = 0;
    WaveWritter wav;
    string convert_options;
    int coremod = 0;
    MultiClock *multi_clock = nullptr;

    void measure_screen_rate();
    void video_dump();
    void get_coremod();
    void cabinet_dump();
    void process_sim_inputs();
    bool trace = false;
    bool dump_ok = false;
    bool download = false;
    bool explicit_video_limit = false;
    vluint64_t last_frame_time = 0;
    HarnessOptions options;
    VerilatedVcdC* tracer = nullptr;
    SDRAM sdram;
#ifdef _JTFRAME_SDRAM_XL
    SDRAM sdram2;
#endif
    SimInputs sim_inputs;
    Download dwn;
    int frame_cnt = 0;
    int last_VS = 0;
    int last_LVBL = 0;
    int last_flip = 0;
    struct t_dump{
        ofstream fout;
        int k, half;
        int32_t buffer0[VIDEO_BUFLEN];
        int32_t buffer1[VIDEO_BUFLEN];
        int32_t *buffer;
        void reset() {
            buffer = !half ? buffer0 : buffer1;
            half = 1-half;
            k = 0;
        }
        bool diff() {
#ifdef _JTFRAME_SIM_VIDEO
            return true;
#endif
            for(int j=0;j<VIDEO_BUFLEN;j++) {
                if(buffer0[j]!=buffer1[j]) return true;
            }
            return false;
        }
        char *prev_buffer() {
            return (char*)(half ? buffer1 : buffer0 );
        }
        t_dump() {
            half=0;
            reset();
        }
        void push(int32_t val) {
            if( k<VIDEO_BUFLEN ) {
                *buffer++ = val;
                k++;
            }
        }
    } dump;
    int color8(int c) {
        switch(_JTFRAME_COLORW) {
            case 8: return c;
            case 6: return (c<<2) | ((c>>3)&3);
            case 5: return (c<<3) | ((c>>2)&7);
            case 4: return (c<<4) | c;
            default: return c;
        }
    }
    void reset(int r);
    void report_flip_changes() {
        if( !game.rst ) {
            if( last_flip != game.dip_flip ) fputs("\ndip_flip toggled\n", stderr);
        }
        last_flip = game.dip_flip;
    }
public:
    int finish_time, finish_frame, totalh, totalw, activeh, activew;
    float vrate;
    bool done() {
        if( game.contextp()->gotFinish() ) return true;
        if( sim_inputs.has_cabinet_script() && !explicit_video_limit && !sim_inputs.cabinet_done() ) return false;
        return (finish_frame>0 ? frame_cnt > finish_frame :
                simtime/1000'000'000 >= finish_time ) &&
               (!game.ioctl_rom && !game.ioctl_ram && !game.dwnld_busy);
    };
    UUT& game;
    int get_frame() { return frame_cnt; }
    void update_wav();
    JTSim( UUT& g, int argc, char *argv[] );
    ~JTSim();
    void clock(int n);
    int time2ticks(vluint64_t time_in_ps) { return int(time_in_ps/(2L*multi_clock->get_semi_period())); }
};

void JTSim::reset( int v ) {
    game.rst = v;
#ifdef _JTFRAME_SIM96
    game.rst96 = v;
#endif
    game.rst24 = v;
}

JTSim::JTSim( UUT& g, int argc, char *argv[]) :
    wav("test.wav",48000,false), options(parse_harness_options(argc, argv)), sdram(g)
#ifdef _JTFRAME_SDRAM_XL
    , sdram2(g, "sdram2", true)
#endif
    , sim_inputs(g, sdram, options.cabinet_input), dwn(g), game(g),vrate(0)
{
    char *opt = getenv("CONVERT_OPTIONS");
    if ( opt!=NULL ) convert_options = opt;
    multi_clock = MakeMultiClock(g);
    get_coremod();
    fprintf(stderr,"Simulation clock period set to %d ps (%.3f MHz)\n",
        ((int)multi_clock->get_semi_period()<<1), 1e6/(multi_clock->get_semi_period()<<1));
#ifdef _LOADROM
    download = true;
#else
    download = false;
#endif
#ifdef _JTFRAME_SIM_DEBUG
    game.debug_bus = _JTFRAME_SIM_DEBUG;
#endif
    trace = options.trace;
    explicit_video_limit = options.explicit_video_limit;
    finish_time = options.finish_time;
    finish_frame = options.finish_frame;
    dump_ok = trace && !sim_inputs.has_cabinet_script() && _DUMP_START==0;
#ifdef _DUMP
    if( trace ) {
        Verilated::traceEverOn(true);
        tracer = new VerilatedVcdC;
        game.trace( tracer, 99 );
        tracer->open("test.vcd");
        fputs("Verilator will dump to test.vcd\n",stderr);
    } else {
        tracer = nullptr;
    }
#endif
#ifdef _JTFRAME_SIM_GFXEN
    game.gfx_en=_JTFRAME_SIM_GFXEN;
#else
    game.gfx_en=0xf;
#endif
    game.dipsw=_JTFRAME_SIM_DIPS;
    fprintf(stderr,"DIP sw set to %X\n",game.dipsw);
    sim_inputs.restore_dipsw();
    reset(0);
    game.sdram_rst = 0;
    clock(24);
    game.sdram_rst = 1;
    reset(1);
    clock(48);
    game.sdram_rst = 0;
#ifdef _JTFRAME_SIM96
    game.rst96 = 0;
#endif
    clock(10);
    for( int k=0; k<1000 && game.sdram_init==1; k++ ) clock(1000);
    dwn.start(download);
}

void JTSim::get_coremod() {
#ifdef _JTFRAME_VERTICAL
    coremod=1;
#else
    coremod=0;
#endif
    ifstream fin("core.mod",ios_base::binary);
    char c[2];
    if(fin.good()) {
        fin.read(c,2);
        coremod = ((int)c[0])&0xff;
    }
}

void JTSim::cabinet_dump() {
#ifndef _JTFRAME_IOCTL_RD
    fprintf(stderr, "ERROR: (test.cpp) cabinet dump requested but JTFRAME_IOCTL_RD is not defined\n");
    return;
#else
    const string scene_root = "scenes";
    const string scene_dir = scene_root + "/" + to_string(frame_cnt);
    auto make_directory = [](const string& path) {
        if( mkdir(path.c_str(), 0775) == 0 ) return true;
        if( errno != EEXIST ) return false;
        struct stat status;
        return stat(path.c_str(), &status) == 0 && S_ISDIR(status.st_mode);
    };
    if( !make_directory(scene_root) || !make_directory(scene_dir) ) {
        fprintf(stderr, "ERROR: (test.cpp) cannot create scene directory %s: %s\n", scene_dir.c_str(), strerror(errno));
        return;
    }
    if( !dwn.iodump_start(scene_dir + "/dump.bin") ) {
        fprintf(stderr, "ERROR: (test.cpp) cabinet dump ignored at frame %d\n", frame_cnt);
    }
#endif
}

void JTSim::process_sim_inputs() {
    if( !game.LVBL || last_LVBL ) return;

    if( sim_inputs.is_controlling_reset() || !game.rst ) sim_inputs.next();
    if( sim_inputs.take_dump() ) cabinet_dump();
#ifdef _DUMP
    if( !dump_ok && sim_inputs.take_tracing_on() ) {
        dump_ok = true;
        fprintf(stderr, "\nTracing starts (cabinet input frame %d)\n", frame_cnt);
    }
#endif
}

JTSim::~JTSim() {
#ifdef _DUMP
    delete tracer;
#endif
    delete multi_clock;
    multi_clock = NULL;
}

void JTSim::clock(int n) {
    while( n-- > 0 ) {
        multi_clock->advance_half_period();
        game.eval();
        if( game.contextp()->gotFinish() ) return;
        sdram.update(simtime + multi_clock->get_semi_period());
#ifdef _JTFRAME_SDRAM_XL
        sdram2.update(simtime + multi_clock->get_semi_period());
#endif
        dwn.update();
        if( dwn.take_download_finished() ) {
            fprintf(stderr,"\nROM file transfered (frame %d)\n",frame_cnt);
            if( finish_time>0 ) finish_time += simtime/1000'000'000;
            if( finish_frame>0 && _DUMP_START==0 ) {
                finish_frame += frame_cnt;
            }
            if ( dwn.FullDownload() ) {
                sdram.dump();
#ifdef _JTFRAME_SDRAM_XL
                sdram2.dump();
#endif
            }
            reset(0);
        }
#ifdef _RST_DLY
        reset( simtime < RST_DLY*1000'000L ? 1 : 0);
#endif
        simtime += multi_clock->get_semi_period();
#ifdef _DUMP
        if( tracer && dump_ok ) tracer->dump(simtime);
#endif
        multi_clock->advance_half_period();
        game.eval();
        if( game.contextp()->gotFinish() ) return;
        sdram.update(simtime + multi_clock->get_semi_period());
#ifdef _JTFRAME_SDRAM_XL
        sdram2.update(simtime + multi_clock->get_semi_period());
#endif
        simtime += multi_clock->get_semi_period();
#ifdef _DUMP
        if( tracer && dump_ok ) tracer->dump(simtime);
#endif
        if( game.VS && !last_VS ) {
            measure_screen_rate();
            fprintf(stderr,ANSI_COLOR_RED "%X" ANSI_COLOR_RESET, frame_cnt&0xf);
            frame_cnt++;
#ifdef _JTFRAME_SIM_IODUMP
            if( frame_cnt==_JTFRAME_SIM_IODUMP ) dwn.iodump_start();
#endif
            if( frame_cnt == _DUMP_START && !dump_ok ) {
                dump_ok = 1;
                fprintf(stderr,"\nDump starts (frame %d)\n", frame_cnt);
            }
            if( (frame_cnt & 0x3f)==0 ) fprintf(stderr," - " ANSI_COLOR_YELLOW "%4d\n", frame_cnt);
#ifdef _JTFRAME_SIM_DEBUG
            game.debug_bus++;
#endif
        }
        process_sim_inputs();
        last_VS   = game.VS;
        last_LVBL = game.LVBL;

        video_dump();
    }
}

void JTSim::measure_screen_rate() {
    auto vperiod=simtime-last_frame_time;
    last_frame_time=simtime;
    vrate = 1e12/float(vperiod);
}

void JTSim::video_dump() {
#ifdef _JTFRAME_SIM_SKIP_FRAME_DUMP
    return;
#endif
    static int LHBLl, LVBLl;
    static int cntw[2], cnth[2];
    static bool active_video;
    static int last_pxlcen=0;
    if( game.pxl_cen && !last_pxlcen ) {
        if( game.LHBL && game.LVBL ) active_video = true;
        if( game.LHBL && game.LVBL && frame_cnt>0 ) {
            const int MASK = (1<<_JTFRAME_COLORW)-1;
            int red   = game.red   & MASK;
            int green = game.green & MASK;
            int blue  = game.blue  & MASK;
            int mix = 0xFF000000 |
                ( color8(blue ) << 16 ) |
                ( color8(green) <<  8 ) |
                ( color8(red  )       );
            dump.push( mix );
        }
        if( !game.LHBL && LHBLl!=0 ) {
            totalw = cntw[0];
            activew= cntw[1];
            cntw[0]=0; cntw[1]=0;
            cnth[0]++;
            if( active_video ) cnth[1]++;
            active_video = false;
            if( !game.LVBL && LVBLl!=0 ) {
                report_flip_changes();
                totalh = cnth[0];
                activeh= cnth[1];
                cnth[0]=0; cnth[1]=0;
                dump.reset();
                int CCW = (coremod&4)>>2;
                CCW ^= game.dip_flip&1;
                if( dump.diff() ) {
                    if( fork()==0 ) {
                        int len = (activew*activeh)<<2;
                        storeCRC(dump.prev_buffer(),len);
                        dump.fout.open("frame.raw",ios_base::binary);
                        if( dump.fout.good() ) {
                            dump.fout.write( dump.prev_buffer(), len );
                            dump.fout.close();
                            char exes[512];
                            snprintf(exes,512,"convert -filter Point "
                                "-size %dx%d %s -depth 8 RGBA:frame.raw %s frames/frame_%05d.png",
                                activew, activeh,
                                (coremod&1) ? (CCW ? "-rotate -90" : "-rotate 90") : "",
                                convert_options.c_str(), frame_cnt);
                            if( system(exes) ) {
                                fputs("WARNING: (test.cpp) convert tool did not succeed\n", stderr);
                            }
                        }
                        exit(0);
                    }
                }
            }
            LVBLl = game.LVBL;
        } else {
            cntw[0]++;
            if( game.LHBL!=0 ) cntw[1]++;
        }
        LHBLl = game.LHBL;
    }
    last_pxlcen = game.pxl_cen;
}

void JTSim::update_wav() {
    int16_t snd[2];
    snd[0] = game.snd_left;
    snd[1] = game.snd_right;
    wav.write(snd);
}

void report_vrate( float vrate ) {
    fprintf(stderr, "\nFrame rate: %.2f Hz\n",vrate);
    ofstream framerate("framerate");
    framerate << vrate;
    framerate.close();
}

int main(int argc, char *argv[]) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    makeCRCTable();

    fputs("Verilator sim starts\n", stderr);
    try {
        UUT game{&context};
        JTSim sim(game, argc, argv);
        int ticks_48kHz = sim.time2ticks(20'833'333);
        while( !sim.done() ) {
            sim.clock(ticks_48kHz);
            sim.update_wav();
            if( sim.get_frame()==3 ) {
#ifndef _JTFRAME_SIM_SKIP_VSIZE
                if( sim.activeh != _JTFRAME_HEIGHT || sim.activew != _JTFRAME_WIDTH ) {
                    fprintf(stderr, "\nERROR: (test.cpp)  video size mismatch. Macros define it as %dx%d but the core outputs %dx%d\n",
                        _JTFRAME_WIDTH, _JTFRAME_HEIGHT, sim.activew, sim.activeh );
                    break;
                }
#endif
            }
        }
        while(wait(NULL) != -1);
#ifdef _COVERAGE
        mkdir("logs",0755)==0;
        Verilated::threadContextp()->coveragep()->write("logs/coverage.dat");
#endif
        report_vrate( sim.vrate );
#if defined(_JTFRAME_RATE) && !defined(_JTFRAME_SKIP_RATE_TEST)
        float rate_delta = sim.vrate - _JTFRAME_RATE;
        if( rate_delta < 0 ) rate_delta = -rate_delta;
        if( rate_delta > 0.1f ) {
            fprintf(stderr,
                "\nERROR: (test.cpp) frame rate mismatch. Expected %.2f Hz but got %.2f Hz\n",
                float(_JTFRAME_RATE), sim.vrate );
            return 64;
        }
#endif
        if( sim.get_frame()>1 ) fputc('\n',stderr);
    } catch( const char *error ) {
        fputs(error,stderr);
        fputc('\n',stderr);
        return 1;
    } catch( const exception& error ) {
        fprintf(stderr, "ERROR: (test.cpp)  %s\n", error.what());
        return 1;
    }
    return 0;
}
