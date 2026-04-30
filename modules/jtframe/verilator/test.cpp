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
#include <iostream>
#include <fstream>
#include <string>
#include <sys/stat.h>
#include "UUT.h"
#include "defmacros.h"
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

#ifndef _JTFRAME_GAMEPLL
    #define _JTFRAME_GAMEPLL "jtframe_pll6000"
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
#ifdef _JTFRAME_PLL
        semi = (vluint64_t)(1e12/(16.0*_JTFRAME_PLL*1000.0));
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

class MultiClockSim96 : MultiClock {
public:
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
    ifstream fin;
    UUT& dut;
    int line;
    bool done, rst_assigned;
public:
    SimInputs( UUT& _dut) : dut(_dut) {
        dut.dip_pause = 1;
        rst_assigned  = 0;
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
#ifdef _SIM_INPUTS
        line = 0;
        done = false;
        fin.open("sim_inputs.hex");
        if( fin.bad() ) {
            fputs("ERROR: (test.cpp)  could not open sim_inputs.hex\n", stderr );
        } else {
            fputs("reading sim_inputs.hex\n", stderr );
        }
        next();
#else
        done = true;
#endif
    }
    bool is_controlling_reset() { return rst_assigned; }
    void next() {
        if( !done && fin.good() ) {
            string s;
            unsigned v;
            ++line;
            getline( fin, s );
            if( sscanf( s.c_str(),"%x", &v )==1 ) parse_inputs(v);
            if( fin.eof() ) {
                done = true;
                fprintf(stderr,"\nsim_inputs.hex finished at line %d\n", line);
                fin.close();
            }

        } else {
            dut.cab_1p = 0xf;
            dut.coin   = 0xf;
            dut.joystick1    = 0x3ff;
        }
    }
    void parse_inputs( unsigned v ) {
        v = ~v;
        apply_reset(v);
        apply_joystick(v);
        auto coin_l   = dut.coin&3;
        dut.dip_test  = (v & 0x800) ? 1 : 0;
        dut.service   = (v & 0x002) ? 1 : 0;
        dut.cab_1p    = 0xc | ((v>>2)&3);
        dut.coin      = 0xe | (v&1);
        if( coin_l != (dut.coin&3) && coin_l!=3 ) {
            cout << "\ncoin inserted (sim_inputs.hex line " << line << ")\n";
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
            if(!rst_assigned) cout << "\nReset forced through cabinet input file";
            rst_assigned = true;
            dut.rst  =1;
            dut.rst24=1;
            dut.rst96=1;
        }
    }
    void apply_joystick(unsigned v) {
        dut.joystick1 = 0x30f | ((v>>4)&0xf0);
        v >>= 4;
        dut.joystick1    = (dut.joystick1&0xf0) | (v&0xf);
#ifdef _JTFRAME_JOY_LRUD
        dut.joystick1    = (dut.joystick1&0xf0) | ((v&3)<<2) | ((v>>2)&3);
#endif
#ifdef _JTFRAME_JOY_LRDU
        dut.joystick1    = (dut.joystick1&0xf0) | ((v&3)<<2) | ((v>>3)&1) | ((v>>1)&2);
#endif
#ifdef _JTFRAME_JOY_RLDU
        dut.joystick1    = (dut.joystick1&0xf0) | ((v&1)<<3) | ((v&2)<<1) | ((v&4)>>1) | ((v&8)>>3);
#endif
#ifdef _JTFRAME_JOY_RLUD
        dut.joystick1    = (dut.joystick1&0xf0) | ((v&1)<<3) | ((v&2)<<1) | ((v&4)>>2) | ((v&8)>>2);
#endif
#ifdef _JTFRAME_JOY_DURL
        dut.joystick1    = (dut.joystick1&0xf0) | ((v&8)>>1) | ((v&4)<<1) | ((v&2)>>1) | ((v&1)<<1);
#endif
#ifdef _JTFRAME_JOY_DULR
        dut.joystick1    = (dut.joystick1&0xf0) | ((v&8)>>1) | ((v&4)<<1) | (v&3);
#endif
#ifdef _JTFRAME_JOY_UDRL
        dut.joystick1    = (dut.joystick1&0xf0) | (v&0xc) | ((v&2)>>1) | ((v&1)<<1);
#endif
    }
};

int fileLength( const char *name ) {
    ifstream fin( name, ios_base::binary );
    fin.seekg( 0, ios_base::end );
    return (int)fin.tellg();
}

class Download {
    UUT& dut;
    int addr, din, ticks, zeroat, len, cart_start, nvram_start;
    char *buf, *iodin;
    bool done, cart, nvram, full_download, iodump_busy;
    int read_buf() {
        return (buf!=nullptr && addr<len) ? buf[addr] : 0;
    }
public:
    Download(UUT& _dut) : dut(_dut) {
        done = false;
        buf = nullptr;
        iodin = nullptr;
        ifstream fin( "rom.bin", ios_base::binary );
        fin.seekg( 0, ios_base::end );
        len = (int)fin.tellg();
        int rom_len = len;
        if( len == 0 || fin.bad() ) {
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
            fin.read(buf,len);
            if( fin.bad() ) {
                fputs("Verilator test.cpp: problem while reading rom.bin\n",stderr);
            } else {
                fprintf(stderr,"Read %d bytes from rom.bin\n",rom_len);
            }
            if( cart ) {
                ifstream fcart( "cart.bin", ios_base::binary );
                fcart.read( buf+cart_start, cart_len );
                if( fin.bad() ) {
                    fputs("Verilator test.cpp: problem while reading cart.bin\n",stderr);
                } else {
                    fprintf(stderr,"Read %d bytes from cart.bin (starts at %x)\n",cart_len,cart_start);
                }
            }
            if( nvram ) {
                ifstream fcart( "nvram.bin", ios_base::binary );
                fcart.read( buf+nvram_start, nvram_len );
                if( fin.bad() ) {
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
        if( (ticks&STEP)==STEP) {
            iodin[dut.ioctl_addr] = dut.ioctl_din;
            if( ++dut.ioctl_addr == _JTFRAME_IOCTL_RD ) {
                fprintf(stderr,"\nIOCTL read finished\n");
                dut.ioctl_addr=0;
                dut.ioctl_ram=0;
                iodump_busy=false;
                auto of = ofstream("dump.bin",ios_base::binary);
                of.write(iodin,_JTFRAME_IOCTL_RD);
                if( of.bad() ) {
                    fprintf(stderr,"ERROR: (test.cpp) creating dump.bin\n" );
                }
            }
        }
        ticks++;
#endif
    }
    void iodump_start() {
#ifdef _JTFRAME_IOCTL_RD
        if( iodump_busy ) return;
        fprintf(stderr,"\nIOCTL read started\n");
        iodump_busy = true;
        dut.ioctl_addr=0;
        dut.ioctl_ram=1;
        ticks=0;
        if(iodin==nullptr) {
            iodin=new char[_JTFRAME_IOCTL_RD];
        }
#endif
    }
};

const int VIDEO_BUFLEN = _JTFRAME_WIDTH*_JTFRAME_HEIGHT;

class JTSim {
    vluint64_t simtime;
    WaveWritter wav;
    string convert_options;
    int coremod;
    MultiClock *multi_clock;

    void parse_args( int argc, char *argv[] );
    void measure_screen_rate();
    void video_dump();
    void get_coremod();
    bool trace;
    bool dump_ok;
    bool download;
    VerilatedVcdC* tracer;
    SDRAM sdram;
    SimInputs sim_inputs;
    Download dwn;
    int frame_cnt, last_LVBL, last_VS, last_flip;
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
    wav("test.wav",48000,false), sdram(g), sim_inputs(g), dwn(g), game(g),vrate(0)
{
    simtime   = 0;
    frame_cnt = 0;
    last_LVBL = 0;
    last_VS   = 0;
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
    parse_args( argc, argv );
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

JTSim::~JTSim() {
#ifdef _DUMP
    delete tracer;
#endif
    delete multi_clock;
    multi_clock = NULL;
}

void JTSim::clock(int n) {
    static int ticks=0;
    static int last_dwnd=0;
    while( n-- > 0 ) {
        int cur_dwn = game.ioctl_rom | game.ioctl_ram | game.dwnld_busy;
        multi_clock->advance_half_period();
        game.eval();
        if( game.contextp()->gotFinish() ) return;
        sdram.update();
        dwn.update();
        if( !cur_dwn && last_dwnd ) {
            fprintf(stderr,"\nROM file transfered (frame %d)\n",frame_cnt);
            if( finish_time>0 ) finish_time += simtime/1000'000'000;
            if( finish_frame>0 && _DUMP_START==0 ) {
                finish_frame += frame_cnt;
            }
            if ( dwn.FullDownload() ) sdram.dump();
            reset(0);
        }
#ifdef _RST_DLY
        reset( simtime < RST_DLY*1000'000L ? 1 : 0);
#endif
        last_dwnd = cur_dwn;
        simtime += multi_clock->get_semi_period();
#ifdef _DUMP
        if( tracer && dump_ok ) tracer->dump(simtime);
#endif
        multi_clock->advance_half_period();
        game.eval();
        if( game.contextp()->gotFinish() ) return;
        sdram.update();
        simtime += multi_clock->get_semi_period();
        ticks++;

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
        if( game.VS && !last_VS && (sim_inputs.is_controlling_reset() || !game.rst) ) sim_inputs.next();
        last_LVBL = game.LVBL;
        last_VS   = game.VS;

        video_dump();
    }
}

void JTSim::measure_screen_rate() {
    static vluint64_t last=0;
    auto vperiod=simtime-last;
    last=simtime;
    vrate = 1e12/float(vperiod);
}

void JTSim::video_dump() {
#ifdef _JTFRAME_SIM_SKIP_FRAME_DUMP
    return;
#endif
    static int LHBLl, LVBLl;
    static int cntw[2], cnth[2];
    static int last_pxlcen=0;
    if( game.pxl_cen && !last_pxlcen ) {
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
                                "-size %dx%d %s -depth 8 RGBA:frame.raw %s frames/frame_%05d.jpg",
                                activew, activeh,
                                (coremod&1) ? (CCW ? "-rotate -90" : "-rotate 90") : "",
                                convert_options.c_str(), frame_cnt);
                            if( system(exes) ) {
                                printf("WARNING: (test.cpp) convert tool did not succeed\n");
                            }
                        }
                        exit(0);
                    }
                }
            } else {
                cnth[0]++;
                if( game.LVBL!=0 ) cnth[1]++;
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

void JTSim::parse_args( int argc, char *argv[] ) {
    trace = false;
    finish_frame = -1;
    finish_time  = 10;
    for( int k=1; k<argc; k++ ) {
        if( strcmp( argv[k], "--trace")==0 ) {
            trace=true;
            dump_ok = _DUMP_START==0;
            continue;
        }
        if( strcmp( argv[k], "-time")==0 ) {
            if( ++k >= argc ) {
                fputs("ERROR: (test.cpp)  expecting time after -time argument\n", stderr);
            } else {
                finish_time = atol(argv[k]);
            }
            continue;
        }
        if( strcmp( argv[k], "-frame")==0 ) {
            if( ++k >= argc ) {
                fputs("ERROR: (test.cpp)  expecting frame count after -frame argument\n", stderr);
            } else {
                finish_frame = atol(argv[k]);
            }
            continue;
        }
    }
    #ifdef _MAXFRAME
    finish_frame = _MAXFRAME;
    #endif
}

void report_vrate( float vrate ) {
    printf("\nFrame rate: %.2f Hz\n",vrate);
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
        if( sim.get_frame()>1 ) fputc('\n',stderr);
    } catch( const char *error ) {
        fputs(error,stderr);
        fputc('\n',stderr);
        return 1;
    }
    return 0;
}
