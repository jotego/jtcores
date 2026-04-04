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

#include <cstdio>
#include <cstring>
#include <fstream>

#include "UUT.h"
#include "defmacros.h"
#include "sdram.h"

using namespace std;

#ifdef _JTFRAME_SDRAM_LARGE
const int COLW     = 10;
#else
const int COLW     = 9;
#endif
const int BANK_LEN = 0x4000 << COLW;
const int AMASK    = (BANK_LEN>>1)-1;
const int COLMASK  = (1<<COLW)-1;

int SDRAM::read_bank( char *bank, int addr ) {
    const int mask = (BANK_LEN>>1)-1;
    addr &= mask;
    int16_t *b16 =(int16_t*)bank;
    int v = b16[addr]&0xffff;
    return v;
}

void SDRAM::write_bank16( char *bank, int addr, int val, int dm ) {
    const int mask = (BANK_LEN>>1)-1;
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

int SDRAM::decode_burst_length(int mode) {
    switch( mode & 7 ) {
        case 0: return 1;
        case 1: return 2;
        case 2: return 4;
        case 3: return 8;
        case 7: return 1 << COLW;
        default:
            throw "\nERROR: (test.cpp) unsupported SDRAM burst length encoding in mode register\n";
    }
}

void SDRAM::change_burst() {
    int mode = dut.SDRAM_A;
    burst_len = decode_burst_length(mode);
    burst_full_page = (mode & 7) == 7;
    cas_latency = (mode >> 4) & 7;
    burst_mask = ~(burst_len-1);
    if( burst_full_page ) {
        fprintf(stderr, "SDRAM burst mode changed to full-page (%d words) CAS=%d mask 0x%X -> ",
            burst_len, cas_latency, burst_mask );
    } else {
        fprintf(stderr, "SDRAM burst mode changed to %d CAS=%d mask 0x%X -> ",
            burst_len, cas_latency, burst_mask );
    }
#ifdef _JTFRAME_BA0_LEN
    ba_blen[0] = (_JTFRAME_BA0_LEN>>4)+1;
#else
    ba_blen[0] = 3;
#endif
#ifdef _JTFRAME_BA1_LEN
    ba_blen[1] = (_JTFRAME_BA1_LEN>>4)+1;
#else
    ba_blen[1] = 3;
#endif
#ifdef _JTFRAME_BA2_LEN
    ba_blen[2] = (_JTFRAME_BA2_LEN>>4)+1;
#else
    ba_blen[2] = 3;
#endif
#ifdef _JTFRAME_BA3_LEN
    ba_blen[3] = (_JTFRAME_BA3_LEN>>4)+1;
#else
    ba_blen[3] = 3;
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
    if( neg_edge ) {
        if( !dut.SDRAM_nCS ) {
            if( !dut.SDRAM_nRAS && !dut.SDRAM_nCAS && !dut.SDRAM_nWE ) {
                change_burst();
            }
            if( !dut.SDRAM_nRAS && dut.SDRAM_nCAS && dut.SDRAM_nWE ) {
                ba_addr[ cur_ba ] = dut.SDRAM_A << COLW;
                ba_addr[ cur_ba ] &= AMASK;
            }
            if( !dut.SDRAM_nRAS && dut.SDRAM_nCAS && !dut.SDRAM_nWE ) {
                if( dut.SDRAM_A & 0x400 ) {
                    for( int k=0; k<4; k++ ) {
                        rd_st[k] = 0;
                        rd_left[k] = 0;
                    }
                } else {
                    rd_st[cur_ba] = 0;
                    rd_left[cur_ba] = 0;
                }
            }
            if( dut.SDRAM_nRAS && !dut.SDRAM_nCAS ) {
                ba_addr[ cur_ba ] &= ~COLMASK;
                ba_addr[ cur_ba ] |= (dut.SDRAM_A & COLMASK);
                if( dut.SDRAM_nWE ) {
                    rd_st[ cur_ba ] = cas_latency;
                    rd_left[ cur_ba ] = burst_full_page ? -1 : burst_len;
                } else {
                    int dqm = dut.SDRAM_DQM;
                    write_bank16( banks[cur_ba], ba_addr[cur_ba], dut.SDRAM_DIN, dqm );
                }
            }
            if( dut.SDRAM_nRAS && dut.SDRAM_nCAS && !dut.SDRAM_nWE ) {
                for( int k=0; k<4; k++ ) {
                    if( rd_left[k] != 0 ) {
                        if( rd_left[k] < 0 || rd_left[k] > cas_latency ) rd_left[k] = cas_latency;
                    }
                }
            }
        }
        int ba_busy=-1;
        for( int k=0; k<4; k++ ) {
            if( rd_st[k] > 0 ) {
                rd_st[k]--;
            } else if( rd_left[k] != 0 ) {
                if( ba_busy>=0 && maxwarn>0 ) {
                    maxwarn--;
                    fputs("WARNING: (test.cpp) SDRAM reads clashed. This may happen if only some banks are used for longer bursts.\n",stderr);
                }
                auto data_read = read_bank( banks[k], ba_addr[k] );
                dut.SDRAM_DQ = data_read;
                auto col = ba_addr[k]&COLMASK;
                auto col_inc = (col+1) & ~burst_mask;
                col &= burst_mask;
                col |= col_inc;
                ba_addr[k] &= ~COLMASK;
                ba_addr[k] |= col;
                if( rd_left[k] > 0 ) rd_left[k]--;
                ba_busy = k;
            }
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
    cas_latency = 2;
    burst_full_page = false;
    for( int k=0; k<4; k++ ) {
        banks[k] = new char[BANK_LEN];
        rd_st[k]=0;
        rd_left[k]=0;
        ba_addr[k]=0;
        memset( banks[k], 0, BANK_LEN );
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
            for( int j=0;j<pos;j++) {
                banks[k][j] = aux[j^1];
            }
            delete []aux;
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
