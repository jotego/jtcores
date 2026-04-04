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

/*
    SDRAM model overview

    This file implements the SDRAM behavior used by JTFRAME's Verilator-based
    simulations. It emulates the command/data semantics that the cores rely on:

    - mode register programming for burst length, burst type, CAS latency, and
      write-burst-single mode
    - bank activation and row tracking
    - fixed-length and full-page read/write bursts
    - sequential and interleaved column addressing
    - burst interruption through READ/WRITE/BURST STOP/PRECHARGE commands
    - functional auto-precharge handling
    - DQM byte masking, including the read-side two-cycle masking delay
    - JTFRAME's 32 MB and 64 MB SDRAM geometries

    The model is intentionally functional rather than fully timing-accurate.
    It does not try to enforce the complete SDRAM datasheet timing rules such
    as tRCD, tRP, tWR, refresh windows, or power-down/self-refresh behavior.
    The goal is to reproduce the memory transactions that JTFRAME issues during
    simulation closely enough for end-to-end video/audio validation.
*/

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <fstream>

#if __has_include("UUT.h")
    #include "UUT.h"
    #define JTFRAME_VERILATOR_HAS_UUT 1
#else
    #define JTFRAME_VERILATOR_HAS_UUT 0
#endif

#if __has_include("defmacros.h")
    #include "defmacros.h"
#endif

#include "sdram.h"

using namespace std;

#ifdef _JTFRAME_SDRAM_LARGE
const int DEFAULT_COLW = 10;
#else
const int DEFAULT_COLW = 9;
#endif

static bool masked(uint8_t dqm, int bit) {
    return (dqm & bit) != 0;
}

SDRAMModel::SDRAMModel(int colw, bool verbose)
    : colw_(colw),
      bank_word_len_(0x2000 << colw),
      bank_byte_len_(0x4000 << colw),
      word_mask_(bank_word_len_ - 1),
      colmask_((1 << colw) - 1),
      verbose_(verbose),
      burst_len_(1),
      cas_latency_(2),
      burst_full_page_(false),
      burst_interleaved_(false),
      write_burst_single_(false),
      read_dqm_({0, 0}) {
    for( auto& bank : banks_ ) bank.assign(bank_word_len_, 0);
    reset();
}

void SDRAMModel::reset() {
    read_dqm_[0] = 0;
    read_dqm_[1] = 0;
    burst_ = BurstState();
    for( auto& bank : banks_state_ ) {
        bank.active = false;
        bank.row_base = 0;
    }
}

void SDRAMModel::set_verbose(bool enable) {
    verbose_ = enable;
}

int SDRAMModel::colw() const {
    return colw_;
}

int SDRAMModel::bank_word_len() const {
    return bank_word_len_;
}

int SDRAMModel::bank_byte_len() const {
    return bank_byte_len_;
}

int SDRAMModel::word_mask() const {
    return word_mask_;
}

bool SDRAMModel::bank_active(int bank) const {
    return banks_state_[bank & 3].active;
}

int SDRAMModel::bank_row_base(int bank) const {
    return banks_state_[bank & 3].row_base;
}

int SDRAMModel::active_burst_kind() const {
    return burst_.kind;
}

int SDRAMModel::active_burst_bank() const {
    return burst_.bank;
}

uint16_t SDRAMModel::read_word(int bank, int addr) const {
    bank &= 3;
    addr &= word_mask_;
    return banks_[bank][addr];
}

void SDRAMModel::write_word(int bank, int addr, uint16_t val, uint8_t dqm) {
    bank &= 3;
    addr &= word_mask_;
    uint16_t cur = banks_[bank][addr];
    if( !masked(dqm, 1) ) {
        cur &= 0xff00;
        cur |= val & 0x00ff;
    }
    if( !masked(dqm, 2) ) {
        cur &= 0x00ff;
        cur |= val & 0xff00;
    }
    banks_[bank][addr] = cur;
}

void SDRAMModel::clear_bank(int bank) {
    bank &= 3;
    fill(banks_[bank].begin(), banks_[bank].end(), 0);
}

void SDRAMModel::load_bank_bytes(int bank, const uint8_t* data, size_t len, bool swap_bytes) {
    bank &= 3;
    clear_bank(bank);
    size_t words = min(len >> 1, static_cast<size_t>(bank_word_len_));
    for( size_t k = 0; k < words; k++ ) {
        uint16_t word;
        if( swap_bytes ) {
            word = (static_cast<uint16_t>(data[(k << 1)]) << 8) | data[(k << 1) + 1];
        } else {
            word = data[(k << 1)] | (static_cast<uint16_t>(data[(k << 1) + 1]) << 8);
        }
        banks_[bank][k] = word;
    }
}

void SDRAMModel::dump_bank_bytes(int bank, uint8_t* data, size_t len, bool swap_bytes) const {
    bank &= 3;
    size_t words = min(len >> 1, static_cast<size_t>(bank_word_len_));
    for( size_t k = 0; k < words; k++ ) {
        uint16_t word = banks_[bank][k];
        if( swap_bytes ) {
            data[(k << 1)] = (word >> 8) & 0xff;
            data[(k << 1) + 1] = word & 0xff;
        } else {
            data[(k << 1)] = word & 0xff;
            data[(k << 1) + 1] = (word >> 8) & 0xff;
        }
    }
}

int SDRAMModel::decode_burst_length(int mode) const {
    switch( mode & 7 ) {
        case 0: return 1;
        case 1: return 2;
        case 2: return 4;
        case 3: return 8;
        case 7: return 1 << colw_;
        default:
            throw "\nERROR: (sdram.cpp) unsupported SDRAM burst length encoding in mode register\n";
    }
}

int SDRAMModel::effective_write_length() const {
    return write_burst_single_ ? 1 : burst_len_;
}

int SDRAMModel::burst_limit(const BurstState& burst) const {
    return burst.full_page ? (1 << colw_) : burst.burst_len;
}

int SDRAMModel::column_for_beat(const BurstState& burst, int beat) const {
    if( burst.full_page ) {
        return (burst.start_col + beat) & colmask_;
    }
    int limit = burst_limit(burst);
    int lowmask = limit - 1;
    int base = burst.start_col & ~lowmask;
    int low = burst.start_col & lowmask;
    if( burst.interleaved ) {
        return base | ((low ^ beat) & lowmask);
    }
    return base | ((low + beat) & lowmask);
}

uint16_t SDRAMModel::apply_read_dqm(uint16_t value, uint8_t dqm) const {
    if( masked(dqm, 1) ) value &= 0xff00;
    if( masked(dqm, 2) ) value &= 0x00ff;
    return value;
}

void SDRAMModel::change_mode(int mode) {
    burst_len_ = decode_burst_length(mode);
    burst_full_page_ = (mode & 7) == 7;
    burst_interleaved_ = (mode & 8) != 0;
    cas_latency_ = (mode >> 4) & 7;
    if( cas_latency_ == 0 ) cas_latency_ = 2;
    write_burst_single_ = (mode & 0x200) != 0;

    if( verbose_ ) {
        if( burst_full_page_ ) {
            fprintf(stderr,
                "SDRAM burst mode changed to full-page (%d words) CAS=%d type=%s write=%s\n",
                burst_len_,
                cas_latency_,
                burst_interleaved_ ? "interleaved" : "sequential",
                write_burst_single_ ? "single" : "burst");
        } else {
            fprintf(stderr,
                "SDRAM burst mode changed to %d CAS=%d type=%s write=%s\n",
                burst_len_,
                cas_latency_,
                burst_interleaved_ ? "interleaved" : "sequential",
                write_burst_single_ ? "single" : "burst");
        }
    }
}

void SDRAMModel::terminate_burst(bool close_bank) {
    if( close_bank && burst_.kind != BURST_NONE ) {
        banks_state_[burst_.bank].active = false;
    }
    burst_ = BurstState();
}

void SDRAMModel::precharge_bank(int bank) {
    bank &= 3;
    if( burst_.kind != BURST_NONE && burst_.bank == bank ) terminate_burst(false);
    banks_state_[bank].active = false;
}

void SDRAMModel::precharge_all() {
    terminate_burst(false);
    for( auto& bank : banks_state_ ) bank.active = false;
}

void SDRAMModel::start_read(int bank, int column, bool auto_precharge) {
    bank &= 3;
    BurstState next;
    next.kind = BURST_READ;
    next.bank = bank;
    next.row_base = banks_state_[bank].row_base;
    next.start_col = column & colmask_;
    next.burst_len = burst_len_;
    next.read_wait = cas_latency_;
    next.read_stop = 0;
    next.full_page = burst_full_page_;
    next.interleaved = burst_interleaved_ && !burst_full_page_;
    next.auto_precharge = auto_precharge && !burst_full_page_;
    burst_ = next;
}

void SDRAMModel::start_write(int bank, int column, bool auto_precharge) {
    bank &= 3;
    BurstState next;
    next.kind = BURST_WRITE;
    next.bank = bank;
    next.row_base = banks_state_[bank].row_base;
    next.start_col = column & colmask_;
    next.burst_len = effective_write_length();
    next.read_wait = 0;
    next.read_stop = 0;
    next.full_page = burst_full_page_ && !write_burst_single_;
    next.interleaved = burst_interleaved_ && !next.full_page && next.burst_len > 1;
    next.auto_precharge = auto_precharge && !next.full_page;
    next.write_single = write_burst_single_;
    burst_ = next;
}

void SDRAMModel::accept_write_beat(uint16_t value, uint8_t dqm) {
    if( burst_.kind != BURST_WRITE ) return;
    int addr = (burst_.row_base | column_for_beat(burst_, burst_.beat)) & word_mask_;
    write_word(burst_.bank, addr, value, dqm);
    burst_.beat++;
    if( !burst_.full_page && burst_.beat >= burst_.burst_len ) {
        terminate_burst(burst_.auto_precharge);
    }
}

SDRAMOutputs SDRAMModel::advance_read(uint8_t read_dqm) {
    SDRAMOutputs out;
    if( burst_.kind != BURST_READ ) return out;
    if( burst_.read_wait > 0 ) {
        burst_.read_wait--;
        return out;
    }

    int addr = (burst_.row_base | column_for_beat(burst_, burst_.beat)) & word_mask_;
    uint16_t data = apply_read_dqm(read_word(burst_.bank, addr), read_dqm);
    out.dq_drive = read_dqm != 3;
    out.dq = data;

    burst_.beat++;

    if( !burst_.full_page && burst_.beat >= burst_.burst_len ) {
        terminate_burst(burst_.auto_precharge);
        return out;
    }

    if( burst_.read_stop > 0 ) {
        burst_.read_stop--;
        if( burst_.read_stop == 0 ) terminate_burst(false);
    }

    return out;
}

SDRAMOutputs SDRAMModel::tick(const SDRAMPins& pins) {
    SDRAMOutputs out;
    uint8_t read_dqm = read_dqm_[0];
    bool command_consumed_write = false;

    if( pins.cke && !pins.ncs ) {
        int bank = pins.ba & 3;
        if( !pins.nras && !pins.ncas && !pins.nwe ) {
            change_mode(pins.a);
        } else if( !pins.nras && pins.ncas && pins.nwe ) {
            if( burst_.kind != BURST_NONE && burst_.bank == bank ) terminate_burst(false);
            banks_state_[bank].active = true;
            banks_state_[bank].row_base = (pins.a << colw_) & word_mask_;
        } else if( !pins.nras && pins.ncas && !pins.nwe ) {
            if( pins.a & 0x400 ) {
                precharge_all();
            } else {
                precharge_bank(bank);
            }
        } else if( pins.nras && !pins.ncas && pins.nwe ) {
            if( burst_.kind != BURST_NONE ) terminate_burst(false);
            start_read(bank, pins.a & colmask_, (pins.a & 0x400) != 0);
        } else if( pins.nras && !pins.ncas && !pins.nwe ) {
            if( burst_.kind != BURST_NONE ) terminate_burst(false);
            start_write(bank, pins.a & colmask_, (pins.a & 0x400) != 0);
            accept_write_beat(pins.din, pins.dqm);
            command_consumed_write = true;
        } else if( pins.nras && pins.ncas && !pins.nwe ) {
            if( burst_.kind == BURST_READ && !burst_.auto_precharge ) {
                burst_.read_stop = cas_latency_;
            } else if( burst_.kind == BURST_WRITE && !burst_.auto_precharge ) {
                terminate_burst(false);
            }
        }
    }

    if( pins.cke && !command_consumed_write && burst_.kind == BURST_WRITE ) {
        accept_write_beat(pins.din, pins.dqm);
    }

    if( pins.cke ) out = advance_read(read_dqm);

    read_dqm_[0] = read_dqm_[1];
    read_dqm_[1] = pins.dqm;
    return out;
}

#if JTFRAME_VERILATOR_HAS_UUT

SDRAM::SDRAM(UUT& _dut) : dut(_dut), model(DEFAULT_COLW, true), last_clk(dut.SDRAM_CLK) {
    for( int k = 0; k < 4; k++ ) {
        char fname[32];
        snprintf(fname, sizeof(fname), "sdram_bank%d.bin", k);
        ifstream fin(fname, ios_base::binary);
        if( !fin ) {
#ifndef _LOADROM
            fprintf(stderr, "WARNING: (sdram.cpp) %s not found\n", fname);
#endif
            continue;
        }
        fin.seekg(0, fin.end);
        size_t len = static_cast<size_t>(fin.tellg());
        fin.seekg(0, fin.beg);
        len = min(len, static_cast<size_t>(model.bank_byte_len()));
        vector<uint8_t> aux(len);
        fin.read(reinterpret_cast<char*>(aux.data()), static_cast<streamsize>(len));
        auto pos = static_cast<size_t>(fin.gcount());
        fprintf(stderr, "Read %X from %s\n", static_cast<unsigned>(pos), fname);
        model.load_bank_bytes(k, aux.data(), pos, true);
    }
}

SDRAM::~SDRAM() {}

void SDRAM::update() {
    bool neg_edge = !dut.SDRAM_CLK && last_clk;
    if( neg_edge ) {
        SDRAMPins pins;
        pins.cke = dut.SDRAM_CKE != 0;
        pins.ncs = dut.SDRAM_nCS != 0;
        pins.nras = dut.SDRAM_nRAS != 0;
        pins.ncas = dut.SDRAM_nCAS != 0;
        pins.nwe = dut.SDRAM_nWE != 0;
        pins.ba = dut.SDRAM_BA & 3;
        pins.dqm = dut.SDRAM_DQM & 3;
        pins.a = dut.SDRAM_A;
        pins.din = dut.SDRAM_DIN;
        auto out = model.tick(pins);
        dut.SDRAM_DQ = out.dq_drive ? out.dq : 0;
    }
    last_clk = dut.SDRAM_CLK;
}

void SDRAM::dump() {
    vector<uint8_t> aux(model.bank_byte_len());
    for( int k = 0; k < 4; k++ ) {
        char fname[32];
        snprintf(fname, sizeof(fname), "sdram_bank%d.bin", k);
        ofstream fout(fname, ios_base::binary);
        if( !fout.good() ) {
            fprintf(stderr, "ERROR: (sdram.cpp) creating %s\n", fname);
            continue;
        }
        model.dump_bank_bytes(k, aux.data(), aux.size(), true);
        fout.write(reinterpret_cast<const char*>(aux.data()), static_cast<streamsize>(aux.size()));
        if( !fout.good() ) {
            fprintf(stderr, "ERROR: (sdram.cpp) saving to %s\n", fname);
        } else {
            fprintf(stderr, "\t%s dumped\n", fname);
        }
    }
}

#endif
