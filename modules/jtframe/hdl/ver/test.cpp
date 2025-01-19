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

// fork
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

#ifdef _JTFRAME_SDRAM_LARGE
    const int BANK_LEN = 0x100'0000;
#else
    const int BANK_LEN = 0x080'0000;
#endif

#ifndef _JTFRAME_SIM_DIPS
    #define _JTFRAME_SIM_DIPS 0xffffffff
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

class WaveWritter {
    std::ofstream fsnd, fhex;
    std::string name;
    bool dump_hex;
    void Constructor(const char *filename, int sample_rate, bool hex );
public:
    WaveWritter(const char *filename, int sample_rate, bool hex ) {
        Constructor( filename, sample_rate, hex );
    }
    WaveWritter(const std::string &filename, int sample_rate, bool hex ) {
        Constructor( filename.c_str(), sample_rate, hex );
    }
    void write( int16_t *lr );
    ~WaveWritter();
};

class SDRAM {
    UUT& dut;
    char *banks[4];
    int rd_st[4], ba_blen[4], ba_addr[4];
    //int last_rd[5];
    char header[32];
    int burst_len, burst_mask;
    int read_offset( int region );
    int read_bank( char *bank, int addr );
    void write_bank16( char *bank,  int addr, int val, int dm /* act. low */ );
    void change_burst();
public:
    SDRAM(UUT& _dut);
    ~SDRAM();
    void update();
    void dump();
};

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
        dut.dip_flip  = 1; // Disable OSD-based flip
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
        dut.joystick1 = 0x30f | ((v>>4)&0xf0); // buttons 1~4
        v >>= 4;    // directions:
        dut.joystick1    = (dut.joystick1&0xf0) | (v&0xf); // _JTFRAME_JOY_UDLR
#ifdef _JTFRAME_JOY_LRUD
        dut.joystick1    = (dut.joystick1&0xf0) | ((v&3)<<2) | ((v>>2)&3);
#endif
#ifdef _JTFRAME_JOY_RLDU
        dut.joystick1    = (dut.joystick1&0xf0) | ((v&1)<<3) | ((v&2)<<1) | ((v&4)>>1) | ((v&8)>>3);
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
    int addr, din, ticks,len, cart_start, nvram_start;
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
                cart_start = len; // starts after rom.bin
                len += cart_len;
            }
            int nvram_len = fileLength("nvram.bin");
            if( nvram_len > 0 ) {
                nvram = true;
                nvram_start = len; // starts after cart.bin
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
        full_download = download; // At least the first 32 bytes will always be downloaded
        if( !full_download ) {
            if ( len > 32 ) {
                fputs("ROM download shortened to 32 bytes.\n",stderr);
                if( nvram ) fputs("Warning: skipping transfer of nvram.bin.\n",stderr);
                len=32;
            } else {
                fputs("Short ROM download\n",stderr);
            }
        }
        ticks = 0;
        done = false;
        dut.ioctl_rom = 1;
        dut.ioctl_addr = 0;
        dut.ioctl_dout = read_buf();
        dut.ioctl_wr   = 0;
        addr = -1;
    }
    void update() {
        dut.ioctl_wr = 0;
        if( dut.ioctl_rom ) step_download();
        if( iodump_busy ) iodump_step();
    }
    void step_download() {
        if( !done ) {
#ifdef _JTFRAME_SIM_SLOWLOAD
            const int STEP=31;
#else
            const int STEP=15;
#endif
            switch( ticks & STEP ) { // ~ 12 MBytes/s - at 6MHz jtframe_sdram64 misses writes
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
                    }
#endif
                    dut.ioctl_dout = read_buf();
                    break;
                case 1:
                    if( addr < len ) {
                        dut.ioctl_wr = 1;
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
    vluint64_t semi_period;
    WaveWritter wav;
    string convert_options;
    int coremod;

    void parse_args( int argc, char *argv[] );
    void measure_screen_rate();
    void video_dump();
    void get_coremod();
    bool trace;   // trace enable or not
    bool dump_ok; // can we dump? (provided trace is enabled)
    bool download;
    VerilatedVcdC* tracer;
    SDRAM sdram;
    SimInputs sim_inputs;
    Download dwn;
    int frame_cnt, last_LVBL, last_VS;
    // Video dump
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
public:
    int finish_time, finish_frame, totalh, totalw, activeh, activew;
    float vrate;
    bool done() {
        if( game.contextp()->gotFinish() ) return true;
        return (finish_frame>0 ? frame_cnt > finish_frame :
                simtime/1000'000'000 >= finish_time ) && (!game.ioctl_rom && !game.dwnld_busy);
    };
    UUT& game;
    int get_frame() { return frame_cnt; }
    void update_wav();
    JTSim( UUT& g, int argc, char *argv[] );
    ~JTSim();
    void clock(int n);
};

////////////////////////////////////////////////////////////////////////
//////////////////////// SDRAM /////////////////////////////////////////


int SDRAM::read_bank( char *bank, int addr ) {
    const int mask = (BANK_LEN>>1)-1; // 8/16MB in 16-bit words
    addr &= mask;
    int16_t *b16 =(int16_t*)bank;
    int v = b16[addr]&0xffff;
    return v;
}

void SDRAM::write_bank16( char *bank, int addr, int val, int dm /* act. low */ ) {
    const int mask = (BANK_LEN>>1)-1; // 8/16MB in 16-bit words
    addr &= mask;
    int16_t *b16 =(int16_t*)bank;

    int v = (int)b16[addr];
    if( (dm&1) == 0 ) {
        v &= 0xff00;
        v |= val&0xff;
    }
    if( (dm&2) == 0 ) {
        v &= 0xff;
        v |= val&0xff00;
    }
    v &= 0xffff;
    b16[addr] = (int16_t)v;
}

void SDRAM::dump() {
    char *aux=new char[BANK_LEN];
    for( int k=0; k<4; k++ ) {
        char fname[32];
        snprintf(fname,32,"sdram_bank%d.bin",k);
        ofstream fout(fname,ios_base::binary);
        if( !fout.good() ) {
            fprintf(stderr,"ERROR: (test.cpp) creating %s\n", fname );
        }
        // reverse bytes because 16-bit access operation
        // use the wrong endianness in intel machines
        // this makes the dump compatible with other verilog simulators
        for( int j=0;j<BANK_LEN;j++) {
            aux[j^1] = banks[k][j];
        }
        fout.write(aux,BANK_LEN);
        if( !fout.good() ) {
            fprintf(stderr, "ERROR: (test.cpp) saving to %s\n", fname );
        }
        fprintf(stderr,"\t%s dumped\n", fname );
    }
    delete[] aux;
}

void SDRAM::change_burst() {
    int mode = dut.SDRAM_A;
    burst_len = 1 << (mode&3);
    // for(int k=0; k<4; k++ ) ba_blen[k]=burst_len+1;
    burst_mask = ~(burst_len-1);
    fprintf(stderr, "SDRAM burst mode changed to %d mask 0x%X -> ",  burst_len, burst_mask );
    if( burst_len>4 ) {
        throw "\nERROR: (test.cpp)  support for bursts larger than 4 is not implemented in test.cpp\n";
    }
    // Update bank burst lengths
#ifdef _JTFRAME_BA0_LEN
    ba_blen[0] = (_JTFRAME_BA0_LEN>>4)+1;
#else
    ba_blen[0] = 3; // default burst is 2, then +1 for read logic
#endif
#ifdef _JTFRAME_BA1_LEN
    ba_blen[1] = (_JTFRAME_BA1_LEN>>4)+1;
#else
    ba_blen[1] = 3; // default burst is 2, then +1 for read logic
#endif
#ifdef _JTFRAME_BA2_LEN
    ba_blen[2] = (_JTFRAME_BA2_LEN>>4)+1;
#else
    ba_blen[2] = 3; // default burst is 2, then +1 for read logic
#endif
#ifdef _JTFRAME_BA3_LEN
    ba_blen[3] = (_JTFRAME_BA3_LEN>>4)+1;
#else
    ba_blen[3] = 3; // default burst is 2, then +1 for read logic
#endif
    fprintf(stderr,"burst per bank = {");
    for(int k=0, first=1; k<4; k++, first=0 ) fprintf(stderr,"%s %d", first ? "" : ",", ba_blen[k]-1);
    fprintf(stderr," }\n");
}

void SDRAM::update() {
    static auto last_clk = dut.SDRAM_CLK;
    static int maxwarn=25;
    bool neg_edge = !dut.SDRAM_CLK && last_clk;
    int cur_ba = dut.SDRAM_BA;
    cur_ba &= 3;
    if( !dut.SDRAM_nCS && neg_edge ) {
        if( !dut.SDRAM_nRAS && !dut.SDRAM_nCAS && !dut.SDRAM_nWE ) { // Mode register
            change_burst();
        }
        if( !dut.SDRAM_nRAS && dut.SDRAM_nCAS && dut.SDRAM_nWE ) { // Row address - Activate command
            ba_addr[ cur_ba ] = dut.SDRAM_A << 9; // 32MB module
            ba_addr[ cur_ba ] &= 0x3fffff;
        }
        if( dut.SDRAM_nRAS && !dut.SDRAM_nCAS ) {
            ba_addr[ cur_ba ] &= ~0x1ff;
            ba_addr[ cur_ba ] |= (dut.SDRAM_A & 0x1ff);
            if( dut.SDRAM_nWE ) { // enque read
                rd_st[ cur_ba ] = burst_len+2;
            } else {
                int dqm = dut.SDRAM_DQM;
                // cout << "Write bank " << cur_ba <<
                //         " ADDR = " << std::hex << ba_addr[cur_ba] <<
                //         " DATA = " << dut.SDRAM_DIN << " Mask = " << dqm << std::dec<< '\n';
                write_bank16( banks[cur_ba], ba_addr[cur_ba], dut.SDRAM_DIN, dqm );
            }
        }
        int ba_busy=-1;
        for( int k=0; k<4; k++ ) {
            // switch( k ) {
            //  case 0: dut.SDRAM_BA_ADDR0 = ba_addr[0]; break;
            //  case 1: dut.SDRAM_BA_ADDR1 = ba_addr[1]; break;
            //  case 2: dut.SDRAM_BA_ADDR2 = ba_addr[2]; break;
            //  case 3: dut.SDRAM_BA_ADDR3 = ba_addr[3]; break;
            // }
            if( rd_st[k]>0 && rd_st[k]<=burst_len ) { // Tested with 32 and 64-bit reads (JTFRAME_BAx_LEN=64)
                // May fail when using 96MHz for SDRAM. Needs investigation
                if( ba_busy>=0 && maxwarn>0 ) {
                    maxwarn--;
                    fputs("WARNING: (test.cpp) SDRAM reads clashed. This may happen if only some banks are used for longer bursts.\n",stderr);
                    // fprintf(stderr,"\tba_blen[%d]=%d\n\tba_blen[%d]=%d\n", ba_busy, ba_blen[ba_busy], k, ba_blen[k]);
                }
                // if( rd_st[k]==burst_len ) printf("Read start\n");
                auto data_read = read_bank( banks[k], ba_addr[k] );
                //cout << "Read " << std::hex << data_read << " from bank " << k << '\n';
                dut.SDRAM_DQ = data_read;
                if( burst_len>1 ) {
                    // Increase the column within the burst
                    auto col = ba_addr[k]&0x1ff;
                    auto col_inc = (col+1) & ~burst_mask;
                    col &= burst_mask;
                    col |= col_inc;
                    ba_addr[k] &= ~0x1ff;
                    ba_addr[k] |= col;
                }
                ba_busy = k;
            }
            if(rd_st[k]>0) rd_st[k]--;
            if(rd_st[k]==(burst_len+1-ba_blen[k])) rd_st[k]=0;
        }
    }
    last_clk = dut.SDRAM_CLK;
}


int SDRAM::read_offset( int region ) {
    if( region>=32 ) {
        region = 0;
        printf("ERROR: (test.cpp)  tried to read past the header\n");
        return 0;
    }
    int offset = (((int)header[region]<<8) | ((int)header[region+1]&0xff)) & 0xffff;
    return offset<<8;
}

SDRAM::SDRAM(UUT& _dut) : dut(_dut) {
    const int MAXBANK=3;
    banks[0] = nullptr;
    burst_len= 1;
    for( int k=0; k<4; k++ ) {
        banks[k] = new char[BANK_LEN];
        rd_st[k]=0;
        ba_addr[k]=0;
        // delete the content
        memset( banks[k], 0, BANK_LEN );
        // Try to load a file for it
        char fname[32];
        snprintf(fname,32,"sdram_bank%d.bin",k);
        ifstream fin( fname, ios_base::binary );
        if( fin ) {
            fin.seekg( 0, fin.end );
            auto len = fin.tellg();
            fin.seekg( 0, fin.beg );
            if( len>BANK_LEN ) len=BANK_LEN;
            char *aux=new char[BANK_LEN];
            fin.read( aux, len );
            auto pos = fin.tellg();
            fprintf(stderr, "Read %X from %s\n", (int)pos, fname );
            // reverse the byte order
            for( int j=0;j<pos;j++) {
                banks[k][j] = aux[j^1];
            }
            delete []aux;
            // Reset the rest of the SDRAM bank
            if( pos<BANK_LEN )
                memset( (void*)&banks[k][pos], 0, BANK_LEN-pos);
        }
#ifndef _LOADROM
        else {
            if( k<=MAXBANK ) fprintf( stderr, "WARNING: (test.cpp) %s not found\n", fname);
        }
#endif
    }
}

SDRAM::~SDRAM() {
    for( int k=0; k<4; k++ ) {
        delete [] banks[k];
        banks[k] = nullptr;
    }
}

////////////////////////////////////////////////////////////////////////
//////////////////////// JTSIM /////////////////////////////////////////

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
    get_coremod();
    // Derive the clock speed from _JTFRAME_PLL
#ifdef _JTFRAME_PLL
    semi_period = (vluint64_t)(1e12/(16.0*_JTFRAME_PLL*1000.0));
#elif _JTFRAME_SIM96 || _JTFRAME_SDRAM96
    semi_period = (vluint64_t)(10416/2); // 96MHz
#else
    semi_period = (vluint64_t)10416; // 48MHz
#endif
    fprintf(stderr,"Simulation clock period set to %d ps (%.3f MHz)\n", ((int)semi_period<<1), 1e6/(semi_period<<1));
#ifdef _LOADROM
    download = true;
#else
    download = false;
#endif
    game.enable_fm  = 1;
    game.enable_psg = 1;
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
    game.gfx_en=_JTFRAME_SIM_GFXEN;    // enable selected layers
#else
    game.gfx_en=0xf;    // enable all layers
#endif
    game.dipsw=_JTFRAME_SIM_DIPS;
    fprintf(stderr,"DIP sw set to %X\n",game.dipsw);
    reset(0);
    game.sdram_rst = 0; // the initial non-reset time should be short or JTKCPU
    clock(24);          // will signal a bus error
    game.sdram_rst = 1;
    reset(1);
    clock(48);
    game.sdram_rst = 0;
#ifdef _JTFRAME_SIM96
    game.rst96 = 0;
#endif
    clock(10);
    // Wait for the SDRAM initialization
    for( int k=0; k<1000 && game.sdram_init==1; k++ ) clock(1000);
    // Download the game ROM
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
}

void JTSim::clock(int n) {
    static int ticks=0;
    static int last_dwnd=0;
#ifdef _JTFRAME_SIM96
    n <<= 2;
#endif
    while( n-- > 0 ) {
        int cur_dwn = game.ioctl_rom | game.dwnld_busy;
        game.clk24 = (ticks & ((JTFRAME_CLK96||JTFRAME_SDRAM96) ? 2 : 1)) == 0 ? 0 : 1;
#ifdef _JTFRAME_CLK48
    game.clk48 = 1-game.clk48;
#endif
#ifdef _JTFRAME_SIM96
        game.clk96 = 1;
        game.clk   = 1-game.clk;
#else
        game.clk = 1;
#endif
        game.eval();
        if( game.contextp()->gotFinish() ) return;
        sdram.update();
        dwn.update();
        if( !cur_dwn && last_dwnd ) {
            // Download finished
            fprintf(stderr,"\nROM file transfered (frame %d)\n",frame_cnt);
            if( finish_time>0 ) finish_time += simtime/1000'000'000;
            if( finish_frame>0 && _DUMP_START==0 ) {
                finish_frame += frame_cnt; // the finish frame value is
                // counted from the time the download finishes, unless
                // _DUMP_START was set by calling jtsim -w frame#
                // in that case the total frame count will include the download
                // frames to avoid situations where the finish_frame could
                // be lower than the -w frame#, which would be confusing
            }
            if ( dwn.FullDownload() ) sdram.dump();
            reset(0);
        }
#ifdef _RST_DLY // reset delay in us
        reset( simtime < RST_DLY*1000'000L ? 1 : 0);
#endif
        last_dwnd = cur_dwn;
        simtime += semi_period;
#ifdef _DUMP
        if( tracer && dump_ok ) tracer->dump(simtime);
#endif
#ifdef _JTFRAME_SIM96
        game.clk96 = 0;
#else
        game.clk = 0;
#endif
        game.eval();
        if( game.contextp()->gotFinish() ) return;
        sdram.update();
        simtime += semi_period;
        ticks++;

#ifdef _DUMP
        if( tracer && dump_ok ) tracer->dump(simtime);
#endif
        // frame counter & inputs
        if( game.VS && !last_VS ) {
            measure_screen_rate();
            fprintf(stderr,ANSI_COLOR_RED "%X" ANSI_COLOR_RESET, frame_cnt&0xf); // do not flush the streams. It can mess up
            frame_cnt++;
#ifdef _JTFRAME_SIM_IODUMP
            if( frame_cnt==_JTFRAME_SIM_IODUMP ) dwn.iodump_start();
#endif
            if( frame_cnt == _DUMP_START && !dump_ok ) {
                dump_ok = 1;
                fprintf(stderr,"\nDump starts (frame %d)\n", frame_cnt);
            }
            // the display and fdisplay output of the verilog files
            if( (frame_cnt & 0x3f)==0 ) fprintf(stderr," - " ANSI_COLOR_YELLOW "%4d\n", frame_cnt);
#ifdef _JTFRAME_SIM_DEBUG
            game.debug_bus++;
#endif
        }
        if( game.VS && !last_VS && (sim_inputs.is_controlling_reset() || !game.rst) ) sim_inputs.next();    // sim inputs are applied when entering sync
        last_LVBL = game.LVBL;
        last_VS   = game.VS;

        // Video dump
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
    static int LHBLl, LVBLl;
    static int cntw[2], cnth[2];
    static int last_pxlcen=0;
    if( game.pxl_cen && !last_pxlcen ) {
        // Dump the video
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
        // Count the video size
        if( !game.LHBL && LHBLl!=0 ) {
            totalw = cntw[0];
            activew= cntw[1];
            cntw[0]=0; cntw[1]=0;
            if( !game.LVBL && LVBLl!=0 ) {
                totalh = cnth[0];
                activeh= cnth[1];
                cnth[0]=0; cnth[1]=0;
                dump.reset();
                int CCW = (coremod&4)>>2;
#ifndef _JTFRAME_OSD_FLIP
                CCW ^= game.dip_flip&1;
#endif
                if( dump.diff() ) {
                    // converts image to jpg in a different fork
                    // I suppose a thread would be faster...
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
                                (coremod&1) ? (CCW ? "-rotate -90" : "-rotate 90") : "", // rotate vertical games
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

void WaveWritter::write( int16_t* lr ) {
    fsnd.write( (char*)lr, sizeof(int16_t)*2 );
    if( dump_hex ) {
        fhex << hex << lr[0] << '\n';
        fhex << hex << lr[1] << '\n';
    }
}

void WaveWritter::Constructor( const char *filename, int sample_rate, bool hex ) {
    name = filename;
    fsnd.open(filename, ios_base::binary);
    dump_hex = hex;
    if( dump_hex ) {
        char *hexname;
        hexname = new char[strlen(filename)+1];
        strcpy(hexname,filename);
        strcpy( hexname+strlen(filename)-4, ".hex" );
        cerr << "Hex file " << hexname << '\n';
        fhex.open(hexname);
        delete[] hexname;
    }
    // write header
    char zero=0;
    for( int k=0; k<45; k++ ) fsnd.write( &zero, 1 );
    fsnd.seekp(0);
    fsnd.write( "RIFF", 4 );
    fsnd.seekp(8);
    fsnd.write( "WAVEfmt ", 8 );
    int32_t number32 = 16;
    fsnd.write( (char*)&number32, 4 );
    int16_t number16 = 1;
    fsnd.write( (char*) &number16, 2);
    number16=2;
    fsnd.write( (char*) &number16, 2);
    number32 = sample_rate;
    fsnd.write( (char*)&number32, 4 );
    number32 = sample_rate*2*2;
    fsnd.write( (char*)&number32, 4 );
    number16=2*2;   // Block align
    fsnd.write( (char*) &number16, 2);
    number16=16;
    fsnd.write( (char*) &number16, 2);
    fsnd.write( "data", 4 );
    fsnd.seekp(44);
}

WaveWritter::~WaveWritter() {
    int32_t number32;
    streampos file_length = fsnd.tellp();
    number32 = (int32_t)file_length-8;
    fsnd.seekp(4);
    fsnd.write( (char*)&number32, 4);
    fsnd.seekp(40);
    number32 = (int32_t)file_length-44;
    fsnd.write( (char*)&number32, 4);
}

void report_vrate( float vrate ) {
    printf("\nFrame rate: %.2f Hz\n",vrate);
}

////////////////////////////////////////////////////
// Main

int main(int argc, char *argv[]) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    makeCRCTable();

    fputs("Verilator sim starts\n", stderr);
    try {
        UUT game{&context};
        JTSim sim(game, argc, argv);
        while( !sim.done() ) {
            sim.clock(1'000); // this will dump at 48kHz sampling rate
            sim.update_wav(); // Other clock rates will not have exact wav dumps
            if( sim.get_frame()==2 ) {
                if( sim.activeh != _JTFRAME_HEIGHT || sim.activew != _JTFRAME_WIDTH ) {
                    fprintf(stderr, "\nERROR: (test.cpp)  video size mismatch. Macros define it as %dx%d but the core outputs %dx%d\n",
                        _JTFRAME_WIDTH, _JTFRAME_HEIGHT, sim.activew, sim.activeh );
                    break;
                }
            }
        }
        // wait until all child processes created with fork() are completed
        // before exiting.
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
