#include <cstdint>
#include <functional>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

#include "../../sdram.h"

using namespace std;

static void fail(const string& msg) {
    throw runtime_error(msg);
}

static void check(bool cond, const string& msg) {
    if( !cond ) fail(msg);
}

static string hex16(uint16_t v) {
    ostringstream ss;
    ss << "0x" << hex << uppercase << v;
    return ss.str();
}

static SDRAMPins nop(uint8_t dqm = 0, uint16_t din = 0) {
    SDRAMPins pins;
    pins.cke = true;
    pins.ncs = false;
    pins.nras = true;
    pins.ncas = true;
    pins.nwe = true;
    pins.dqm = dqm;
    pins.din = din;
    return pins;
}

static SDRAMPins mrs(int mode) {
    SDRAMPins pins = nop();
    pins.nras = false;
    pins.ncas = false;
    pins.nwe = false;
    pins.a = mode;
    return pins;
}

static SDRAMPins activate(int bank, int row) {
    SDRAMPins pins = nop();
    pins.ba = bank;
    pins.nras = false;
    pins.a = row;
    return pins;
}

static SDRAMPins precharge(int bank, bool all = false) {
    SDRAMPins pins = nop();
    pins.ba = bank;
    pins.nras = false;
    pins.nwe = false;
    if( all ) pins.a = 0x400;
    return pins;
}

static SDRAMPins read_cmd(int bank, int col, bool auto_precharge = false, uint8_t dqm = 0) {
    SDRAMPins pins = nop(dqm);
    pins.ba = bank;
    pins.ncas = false;
    if( auto_precharge ) pins.a = col | 0x400;
    else pins.a = col;
    return pins;
}

static SDRAMPins write_cmd(int bank, int col, uint16_t din, bool auto_precharge = false, uint8_t dqm = 0) {
    SDRAMPins pins = nop(dqm, din);
    pins.ba = bank;
    pins.ncas = false;
    pins.nwe = false;
    if( auto_precharge ) pins.a = col | 0x400;
    else pins.a = col;
    return pins;
}

static SDRAMPins burst_stop() {
    SDRAMPins pins = nop();
    pins.nwe = false;
    return pins;
}

static int row_base(int colw, int row) {
    return row << colw;
}

static uint16_t pattern(int bank, int row, int col) {
    return static_cast<uint16_t>(((bank & 3) << 12) | ((row & 0xf) << 8) | (col & 0xff));
}

static void fill_row(SDRAMModel& model, int colw, int bank, int row) {
    int base = row_base(colw, row);
    for( int col = 0; col < (1 << colw); col++ ) {
        model.write_word(bank, base | col, pattern(bank, row, col));
    }
}

static void expect_no_output(const SDRAMOutputs& out, const string& ctx) {
    check(!out.dq_drive, ctx + ": unexpected DQ drive");
}

static void expect_output(const SDRAMOutputs& out, uint16_t expected, const string& ctx) {
    check(out.dq_drive, ctx + ": expected DQ drive");
    check(out.dq == expected, ctx + ": expected " + hex16(expected) + " got " + hex16(out.dq));
}

static void set_mode(SDRAMModel& model, int mode) {
    expect_no_output(model.tick(mrs(mode)), "mode set");
}

static void open_row(SDRAMModel& model, int bank, int row) {
    expect_no_output(model.tick(activate(bank, row)), "activate");
}

static void test_sequential_read(int colw) {
    SDRAMModel model(colw);
    fill_row(model, colw, 0, 3);
    set_mode(model, 0x20 | 0x2);
    open_row(model, 0, 3);

    expect_no_output(model.tick(read_cmd(0, 5)), "read command");
    expect_no_output(model.tick(nop()), "read latency 1");
    expect_output(model.tick(nop()), pattern(0, 3, 5), "read beat 0");
    expect_output(model.tick(nop()), pattern(0, 3, 6), "read beat 1");
    expect_output(model.tick(nop()), pattern(0, 3, 7), "read beat 2");
    expect_output(model.tick(nop()), pattern(0, 3, 4), "read beat 3");
    expect_no_output(model.tick(nop()), "read done");
}

static void test_interleaved_read(int colw) {
    SDRAMModel model(colw);
    fill_row(model, colw, 0, 1);
    set_mode(model, 0x20 | 0x8 | 0x2);
    open_row(model, 0, 1);

    expect_no_output(model.tick(read_cmd(0, 5)), "interleaved read command");
    expect_no_output(model.tick(nop()), "interleaved latency 1");
    expect_output(model.tick(nop()), pattern(0, 1, 5), "interleaved beat 0");
    expect_output(model.tick(nop()), pattern(0, 1, 4), "interleaved beat 1");
    expect_output(model.tick(nop()), pattern(0, 1, 7), "interleaved beat 2");
    expect_output(model.tick(nop()), pattern(0, 1, 6), "interleaved beat 3");
}

static void test_full_page_read_wrap(int colw) {
    SDRAMModel model(colw);
    int last = (1 << colw) - 1;
    fill_row(model, colw, 0, 2);
    set_mode(model, 0x20 | 0x7);
    open_row(model, 0, 2);

    expect_no_output(model.tick(read_cmd(0, last)), "full-page read command");
    expect_no_output(model.tick(nop()), "full-page latency 1");
    expect_output(model.tick(nop()), pattern(0, 2, last), "full-page beat 0");
    expect_output(model.tick(nop()), pattern(0, 2, 0), "full-page beat 1");
    expect_output(model.tick(nop()), pattern(0, 2, 1), "full-page beat 2");
}

static void test_burst_stop_read(int colw) {
    SDRAMModel model(colw);
    fill_row(model, colw, 0, 4);
    set_mode(model, 0x20 | 0x7);
    open_row(model, 0, 4);

    expect_no_output(model.tick(read_cmd(0, 2)), "stop read command");
    expect_no_output(model.tick(nop()), "stop read latency 1");
    expect_output(model.tick(nop()), pattern(0, 4, 2), "stop read beat 0");
    expect_output(model.tick(burst_stop()), pattern(0, 4, 3), "stop read beat 1");
    expect_output(model.tick(nop()), pattern(0, 4, 4), "stop read beat 2");
    expect_no_output(model.tick(nop()), "stop read done");
}

static void test_read_interrupt(int colw) {
    SDRAMModel model(colw);
    fill_row(model, colw, 0, 5);
    set_mode(model, 0x20 | 0x2);
    open_row(model, 0, 5);

    expect_no_output(model.tick(read_cmd(0, 1)), "read A");
    expect_no_output(model.tick(nop()), "read A latency 1");
    expect_output(model.tick(nop()), pattern(0, 5, 1), "read A beat 0");
    expect_no_output(model.tick(read_cmd(0, 8)), "read B command");
    expect_no_output(model.tick(nop()), "read B latency 1");
    expect_output(model.tick(nop()), pattern(0, 5, 8), "read B beat 0");
    expect_output(model.tick(nop()), pattern(0, 5, 9), "read B beat 1");
}

static void test_read_dqm_latency(int colw) {
    SDRAMModel model(colw);
    int base = row_base(colw, 1);
    model.write_word(0, base | 0, 0xA1B2);
    model.write_word(0, base | 1, 0xC3D4);
    set_mode(model, 0x20 | 0x2);
    open_row(model, 0, 1);

    expect_no_output(model.tick(read_cmd(0, 0, false, 1)), "dqm read command");
    expect_no_output(model.tick(nop(2)), "dqm latency 1");
    expect_output(model.tick(nop()), 0xA100, "dqm beat 0");
    expect_output(model.tick(nop()), 0x00D4, "dqm beat 1");
}

static void test_write_burst(int colw) {
    SDRAMModel model(colw);
    int base = row_base(colw, 2);
    set_mode(model, 0x20 | 0x2);
    open_row(model, 0, 2);

    expect_no_output(model.tick(write_cmd(0, 5, 0x1001)), "write burst command");
    expect_no_output(model.tick(nop(0, 0x1002)), "write beat 1");
    expect_no_output(model.tick(nop(0, 0x1003)), "write beat 2");
    expect_no_output(model.tick(nop(0, 0x1004)), "write beat 3");
    check(model.read_word(0, base | 5) == 0x1001, "write col 5");
    check(model.read_word(0, base | 6) == 0x1002, "write col 6");
    check(model.read_word(0, base | 7) == 0x1003, "write col 7");
    check(model.read_word(0, base | 4) == 0x1004, "write col 4");
}

static void test_full_page_write_wrap(int colw) {
    SDRAMModel model(colw);
    int base = row_base(colw, 1);
    int last = (1 << colw) - 1;
    set_mode(model, 0x20 | 0x7);
    open_row(model, 0, 1);

    expect_no_output(model.tick(write_cmd(0, last, 0x2201)), "full-page write command");
    expect_no_output(model.tick(nop(0, 0x2202)), "full-page write beat 1");
    expect_no_output(model.tick(nop(0, 0x2203)), "full-page write beat 2");
    expect_no_output(model.tick(burst_stop()), "full-page burst stop");
    expect_no_output(model.tick(nop(0, 0x2204)), "full-page post-stop");
    check(model.read_word(0, base | last) == 0x2201, "full-page last col");
    check(model.read_word(0, base | 0) == 0x2202, "full-page wrap col 0");
    check(model.read_word(0, base | 1) == 0x2203, "full-page wrap col 1");
    check(model.read_word(0, base | 2) == 0x0000, "full-page stop prevented extra beat");
}

static void test_write_single(int colw) {
    SDRAMModel model(colw);
    int base = row_base(colw, 3);
    set_mode(model, 0x20 | 0x2 | 0x200);
    open_row(model, 0, 3);

    expect_no_output(model.tick(write_cmd(0, 2, 0x1234)), "write single command");
    expect_no_output(model.tick(nop(0, 0x5678)), "write single next beat");
    check(model.read_word(0, base | 2) == 0x1234, "write single stored first beat");
    check(model.read_word(0, base | 3) == 0x0000, "write single suppressed second beat");
}

static void test_write_dqm(int colw) {
    SDRAMModel model(colw);
    int base = row_base(colw, 0);
    model.write_word(0, base | 0, 0xffff);
    model.write_word(0, base | 1, 0xffff);
    set_mode(model, 0x20 | 0x1);
    open_row(model, 0, 0);

    expect_no_output(model.tick(write_cmd(0, 0, 0x1234, false, 1)), "write dqm command");
    expect_no_output(model.tick(nop(2, 0x5678)), "write dqm beat 1");
    check(model.read_word(0, base | 0) == 0x12ff, "write dqm masked low byte");
    check(model.read_word(0, base | 1) == 0xff78, "write dqm masked high byte");
}

static void test_read_interrupts_write(int colw) {
    SDRAMModel model(colw);
    int base = row_base(colw, 6);
    set_mode(model, 0x20 | 0x2);
    open_row(model, 0, 6);

    expect_no_output(model.tick(write_cmd(0, 0, 0x1111)), "write A");
    expect_no_output(model.tick(nop(0, 0x2222)), "write B");
    expect_no_output(model.tick(read_cmd(0, 0)), "read interrupt command");
    expect_no_output(model.tick(nop()), "read interrupt latency 1");
    expect_output(model.tick(nop()), 0x1111, "read interrupt beat 0");
    expect_output(model.tick(nop()), 0x2222, "read interrupt beat 1");
    check(model.read_word(0, base | 0) == 0x1111, "interrupt write col 0");
    check(model.read_word(0, base | 1) == 0x2222, "interrupt write col 1");
    check(model.read_word(0, base | 2) == 0x0000, "interrupt suppressed later write beat");
}

static void test_precharge_and_auto_precharge(int colw) {
    SDRAMModel model(colw);
    fill_row(model, colw, 0, 1);
    set_mode(model, 0x20 | 0x1);
    open_row(model, 0, 1);
    check(model.bank_active(0), "bank active after activate");
    check(model.bank_row_base(0) == row_base(colw, 1), "row base after activate");

    expect_no_output(model.tick(read_cmd(0, 0, true)), "auto-precharge read");
    expect_no_output(model.tick(nop()), "auto-precharge latency 1");
    expect_output(model.tick(nop()), pattern(0, 1, 0), "auto-precharge beat 0");
    expect_output(model.tick(nop()), pattern(0, 1, 1), "auto-precharge beat 1");
    check(!model.bank_active(0), "bank inactive after auto-precharge");

    open_row(model, 0, 2);
    check(model.bank_active(0), "bank reactivated");
    check(model.bank_row_base(0) == row_base(colw, 2), "row base updated");
    expect_no_output(model.tick(precharge(0)), "precharge bank");
    check(!model.bank_active(0), "bank inactive after precharge");

    open_row(model, 0, 3);
    open_row(model, 1, 4);
    expect_no_output(model.tick(precharge(0, true)), "precharge all");
    check(!model.bank_active(0), "bank 0 inactive after precharge all");
    check(!model.bank_active(1), "bank 1 inactive after precharge all");
}

static void test_full_page_auto_precharge_ignored(int colw) {
    SDRAMModel model(colw);
    fill_row(model, colw, 0, 7);
    set_mode(model, 0x20 | 0x7);
    open_row(model, 0, 7);

    expect_no_output(model.tick(read_cmd(0, 0, true)), "full-page auto-precharge read");
    expect_no_output(model.tick(nop()), "full-page auto-precharge latency 1");
    expect_output(model.tick(nop()), pattern(0, 7, 0), "full-page auto-precharge beat 0");
    check(model.bank_active(0), "full-page auto-precharge ignored bank active");
    check(model.active_burst_kind() == 1, "full-page burst still active");
}

static void run_geometry_suite(int colw) {
    test_sequential_read(colw);
    test_interleaved_read(colw);
    test_full_page_read_wrap(colw);
    test_burst_stop_read(colw);
    test_read_interrupt(colw);
    test_read_dqm_latency(colw);
    test_write_burst(colw);
    test_full_page_write_wrap(colw);
    test_write_single(colw);
    test_write_dqm(colw);
    test_read_interrupts_write(colw);
    test_precharge_and_auto_precharge(colw);
    test_full_page_auto_precharge_ignored(colw);
}

int main() {
    try {
        run_geometry_suite(9);
        run_geometry_suite(10);
        cout << "PASS\n";
        return 0;
    } catch( const exception& e ) {
        cerr << "FAIL: " << e.what() << '\n';
        return 1;
    }
}
