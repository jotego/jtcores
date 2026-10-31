/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps

module test;

reg         clk = 1'b0, clk24 = 1'b0, rst = 1'b1, rst24 = 1'b1;
reg         mcu_cen = 1'b0, mcu_en = 1'b1;
reg         rom_ok = 1'b0, ram_ok = 1'b0;
reg  [15:0] rom_data = 16'h6000;
wire        rom_cs;
wire [18:1] rom_addr;
wire        cpu_cen, cpu_cenb;
wire [15:0] cpu_dout;
wire        UDSWn, LDSWn, RnW;
wire [12:1] cpu_addr;
wire        char_cs, pal_cs, objram_cs, flip, video_en, colscr_en, rowscr_en;
wire        ram_cs, vram_cs;
wire [ 7:0] snd_latch, st_dout;
wire        snd_irqn, sound_en;

always #10 clk = ~clk;
always #20 clk24 = ~clk24;

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

`include "test_tasks.vh"

jts16_main uut(
    .rst            ( rst          ),
    .clk            ( clk          ),
    .clk_rom        ( clk          ),
    .cpu_cen        ( cpu_cen      ),
    .cpu_cenb        ( cpu_cenb     ),
    .rst24          ( rst24        ),
    .clk24          ( clk24        ),
    .mcu_cen        ( mcu_cen      ),
    .game_id        ( 8'd0         ),
    .vint           ( 1'b0         ),
    .LHBL           ( 1'b1         ),
    .char_cs        ( char_cs      ),
    .pal_cs         ( pal_cs       ),
    .objram_cs      ( objram_cs    ),
    .char_dout      ( 16'hffff     ),
    .pal_dout       ( 16'hffff     ),
    .obj_dout       ( 16'hffff     ),
    .flip           ( flip         ),
    .video_en       ( video_en     ),
    .colscr_en      ( colscr_en    ),
    .rowscr_en      ( rowscr_en    ),
    .ram_cs         ( ram_cs       ),
    .vram_cs        ( vram_cs      ),
    .ram_data       ( 16'hffff     ),
    .ram_ok         ( ram_ok       ),
    .cpu_dout       ( cpu_dout     ),
    .UDSWn          ( UDSWn        ),
    .LDSWn          ( LDSWn        ),
    .RnW            ( RnW          ),
    .cpu_addr       ( cpu_addr     ),
    .snd_latch      ( snd_latch    ),
    .snd_irqn       ( snd_irqn     ),
    .sound_en       ( sound_en     ),
    .snd_ack        ( 1'b0         ),
    .joystick1      ( 9'd0         ),
    .joystick2      ( 9'd0         ),
    .joystick3      ( 9'd0         ),
    .joystick4      ( 9'd0         ),
    .joyana1        ( 16'hffff     ),
    .joyana1b       ( 16'hffff     ),
    .joyana2        ( 16'hffff     ),
    .joyana2b       ( 16'hffff     ),
    .joyana3        ( 16'hffff     ),
    .joyana4        ( 16'hffff     ),
    .cab_1p         ( 4'd0         ),
    .coin           ( 4'd0         ),
    .service        ( 1'b0         ),
    .rom_cs         ( rom_cs       ),
    .rom_addr       ( rom_addr     ),
    .rom_data       ( rom_data     ),
    .rom_ok          ( rom_ok       ),
    .dec_en         ( 1'b0         ),
    .fd1089_en      ( 1'b0         ),
    .fd1094_en      ( 1'b0         ),
    .dec_type       ( 1'b0         ),
    .prog_addr      ( 13'd0        ),
    .key_we         ( 1'b0         ),
    .fd1089_we      ( 1'b0         ),
    .prog_data      ( 8'd0         ),
    .key_addr       (             ),
    .key_data       ( 8'd0         ),
    .dip_test       ( 1'b0         ),
    .dipsw_a        ( 8'hff        ),
    .dipsw_b        ( 8'hff        ),
    .dipsw_c        ( 8'hff        ),
    .mcu_en         ( mcu_en       ),
    .mcu_prog_we    ( 1'b0         ),
    .debug_bus      ( 8'd0         ),
    .st_addr        ( 8'd0         ),
    .st_dout        ( st_dout      )
);

task pulse_mcu_cen;
begin
    @(negedge clk24);
    mcu_cen = 1'b1;
    @(posedge clk24);
    #1;
    if (uut.mcu_gated !== 1'b0)
        $display("gate opened early: mcu_ok=%b rom_cs=%b rom_ok=%b ram_cs=%b ram_ok=%b mcu_acc=%b mcu_ctrl=%02x addr=%04x",
            uut.mcu_ok, rom_cs, rom_ok, ram_cs, ram_ok, uut.mcu_acc, uut.mcu_ctrl, uut.mcu_addr);
    assert_msg(uut.mcu_gated == 1'b0,
        "MCU clock enable stays blocked until its selected target is ready");
    @(negedge clk24);
    mcu_cen = 1'b0;
end
endtask

task clock_gate_once;
begin
    @(negedge clk24);
    mcu_cen = 1'b1;
    #1;
    assert_msg(uut.mcu_gated == 1'b1,
        "MCU receives exactly a ready-qualified clock enable");
    @(posedge clk24);
    #1;
    @(negedge clk24);
    mcu_cen = 1'b0;
end
endtask

task pulse_expect_open;
begin
    @(negedge clk24);
    mcu_cen = 1'b1;
    #1;
    assert_msg(uut.mcu_gated == 1'b1,
        "ready or nonblocking access is allowed to advance the MCU");
    @(posedge clk24);
    #1;
    @(negedge clk24);
    mcu_cen = 1'b0;
end
endtask

task check_reset_held_ram;
    input wr;
begin
    force uut.mcu_acc = 1'b0;
    force uut.mcu_wr = wr;
    ram_ok = 1'b0;
    @(posedge clk);
    #1;
    force uut.mcu_ctrl = 8'hc0; // mode 0, P1.6 holds CPU in reset
    force uut.mcu_addr = 16'h4000;
    force uut.mcu_acc = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    assert_msg(uut.cpu_rst == 1'b1 && uut.BGACKn == 1'b1 &&
               uut.mcu_bus == 1'b1 && uut.BUSn == 1'b1,
        "reset-held MCU owns bus with inactive 68k strobes and BGACKn");
    assert_msg(ram_cs == 1'b1,
        "reset-held mode 0 address 4000 decodes to work RAM");
    assert_msg(uut.mcu_ok == 1'b0,
        "reset-held work-RAM access waits for ram_ok");
    repeat (4) pulse_mcu_cen();
    @(negedge clk);
    ram_ok = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    assert_msg(uut.mcu_ok == 1'b1,
        "reset-held work-RAM access becomes ready after ram_ok");
    pulse_expect_open();
end
endtask

task check_granted_access;
    input [7:0] ctrl;
    input [15:0] addr;
    input wr;
    input [2:0] target;
begin
    // No grant, CPU running: every active transaction must remain stalled,
    // including peripheral and unmapped requests with no memory wait signal.
    force uut.BRn = 1'b1;
    force uut.BGACKn = 1'b1;
    force uut.mcu_acc = 1'b0;
    force uut.mcu_wr = 1'b0;
    repeat (2) @(posedge clk);
    #1;
    force uut.mcu_ctrl = ctrl;
    force uut.mcu_addr = addr;
    force uut.mcu_wr = wr;
    force uut.mcu_acc = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    assert_msg(uut.cpu_rst == 1'b0 && uut.mcu_bus == 1'b0,
        "CPU is running and has not granted the bus");
    assert_msg(uut.mcu_ok == 1'b0,
        "active MCU access waits for the delayed bus grant");
    pulse_mcu_cen();

    // Grant follows the delayed BGACKn path. Check production decode and
    // verify that the transaction then advances without a ROM response.
    force uut.BRn = 1'b0;
    force uut.BGACKn = 1'b0;
    repeat (2) @(posedge clk);
    #1;
    assert_msg(uut.mcu_bus == 1'b1 && uut.mcu_ok == 1'b1,
        "active non-RAM access advances after bus grant");
    case (target)
        1: assert_msg(uut.io_cs, "granted MCU request selects IO");
        2: assert_msg(char_cs, "granted MCU request selects text RAM");
        3: assert_msg(pal_cs, "granted MCU request selects palette RAM");
        4: assert_msg(rom_cs, "granted ROM write selects ROM");
        default: assert_msg(!rom_cs && !ram_cs && !vram_cs &&
                            !char_cs && !pal_cs && !objram_cs && !uut.io_cs,
                            "granted unmapped access selects no target");
    endcase
    pulse_expect_open();
end
endtask

initial begin
    repeat (4) @(posedge clk24);
    rst = 1'b0;
    rst24 = 1'b0;
    repeat (3) @(posedge clk24);
    #1;
    assert_msg(uut.cpu_rst == 1'b1,
        "P1=EF holds the 68000 reset during the MCU checksum");
    assert_msg(uut.mcu_bus == 1'b1,
        "the MCU owns the bus while the main CPU is held reset");

    // Model the MCU's held MOVX request at the observed failing even address.
    // The real decode, registered chip select, response latch, and grant gate
    // remain live in jts16_main.
    force uut.mcu_ctrl = 8'hef;
    force uut.mcu_addr = 16'h0408;
    force uut.mcu_wr   = 1'b0;
    force uut.mcu_acc  = 1'b1;

    @(posedge clk);
    #1;
    assert_msg(rom_cs == 1'b1, "mode 5 request decodes to main ROM");
    assert_msg(rom_addr == 18'h00204,
        "MCU byte address 0408 maps to ROM word address 00204");
    assert_msg(uut.mcu_top == 8'h00, "mode 5 selects ROM bank zero");
    if (uut.mcu_ok !== 1'b0)
        $display("first decode edge was not stalled: mcu_ok=%b rom_cs=%b rom_ok=%b",
            uut.mcu_ok, rom_cs, rom_ok);
    assert_msg(uut.mcu_ok == 1'b0,
        "ROM request decode edge stays unready before rom_ok");

    // Exceed the observed 14 clk24-edge minimum ROM latency. Repeated enable
    // pulses must remain blocked while rom_ok is low, despite cpu_rst=1.
    repeat (18) pulse_mcu_cen();

    @(negedge clk24);
    rom_ok = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    assert_msg(uut.mcu_rom_din == 8'h00,
        "ready response for 0408 captures the expected lower byte");
    clock_gate_once();

    // Release that transaction and issue the odd byte of the same ROM word.
    @(negedge clk24);
    force uut.mcu_acc = 1'b0;
    rom_ok = 1'b0;
    @(posedge clk);
    #1;
    force uut.mcu_addr = 16'h0409;
    force uut.mcu_acc  = 1'b1;
    @(posedge clk);
    #1;
    assert_msg(rom_cs == 1'b1, "odd-byte request remains a ROM access");
    assert_msg(rom_addr == 18'h00204,
        "odd and even MCU byte addresses share one ROM word");
    assert_msg(uut.LDSn == 1'b1, "odd MCU byte selects upper ROM lane");

    @(negedge clk24);
    rom_ok = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    assert_msg(uut.mcu_rom_din == 8'h60,
        "ready response for 0409 captures the expected upper byte");
    clock_gate_once();

    // In checksum mode, CPU reset itself owns the MCU bus. Work RAM must
    // still decode even though BGACKn and the stopped 68000's ASn are high.
    check_reset_held_ram(1'b0);
    check_reset_held_ram(1'b1);

    // Release the reset-only synthetic grant, then model the live DMA grant
    // path with the CPU running. A pending ROM read must still wait for ROM
    // ready even though the main CPU is no longer held in reset.
    @(negedge clk24);
    force uut.mcu_acc = 1'b0;
    rom_ok = 1'b0;
    @(posedge clk);
    #1;
    force uut.mcu_ctrl = 8'haf; // mode 5, CPU reset released
    force uut.mcu_wr = 1'b0;
    force uut.BRn = 1'b0;
    force uut.BGACKn = 1'b0;
    @(posedge clk);
    #1;
    assert_msg(uut.cpu_rst == 1'b0 && uut.mcu_bus == 1'b1,
        "running 68000 grants the bus to the MCU");
    force uut.mcu_addr = 16'h0408;
    force uut.mcu_acc = 1'b1;
    @(posedge clk);
    #1;
    repeat (18) pulse_mcu_cen();
    @(negedge clk);
    rom_ok = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    assert_msg(uut.mcu_rom_din == 8'h00,
        "running-CPU grant returns the expected even ROM byte");
    clock_gate_once();

    // Work-RAM accesses use ram_ok. Hold one pending then acknowledge it.
    @(negedge clk24);
    force uut.mcu_acc = 1'b0;
    rom_ok = 1'b0;
    @(posedge clk);
    #1;
    force uut.mcu_ctrl = 8'h80; // mode 0, CPU reset released
    force uut.mcu_addr = 16'h4000; // work RAM
    force uut.mcu_acc = 1'b1;
    ram_ok = 1'b0;
    repeat (2) @(posedge clk);
    #1;
    assert_msg(ram_cs == 1'b1,
        "mode 0 address 4000 decodes to work RAM");
    repeat (4) pulse_mcu_cen();
    @(negedge clk);
    ram_ok = 1'b1;
    @(posedge clk);
    #1;
    pulse_expect_open();

    // RAM writes also wait for the selected RAM acknowledgement.
    @(negedge clk24);
    force uut.mcu_acc = 1'b0;
    force uut.mcu_wr = 1'b1;
    ram_ok = 1'b0;
    @(posedge clk);
    #1;
    force uut.mcu_ctrl = 8'h80;
    force uut.mcu_addr = 16'h4000;
    force uut.mcu_acc = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    assert_msg(ram_cs == 1'b1,
        "mode 0 work-RAM write selects the RAM target");
    assert_msg(uut.mcu_ok == 1'b0,
        "work-RAM write waits for ram_ok");
    repeat (4) pulse_mcu_cen();
    @(negedge clk);
    ram_ok = 1'b1;
    repeat (2) @(posedge clk);
    pulse_expect_open();

    // With the CPU running and no DMA grant, even active peripheral, ROM
    // write, and unmapped cycles must wait for grant. They then advance
    // without waiting for a ROM read response.
    rom_ok = 1'b0;
    check_granted_access(8'h80, 16'h8000, 1'b0, 3'd1); // IO
    check_granted_access(8'h88, 16'h8000, 1'b0, 3'd2); // text RAM
    check_granted_access(8'h98, 16'h0000, 1'b0, 3'd3); // palette RAM
    check_granted_access(8'ha0, 16'h0000, 1'b0, 3'd0); // unmapped
    check_granted_access(8'haf, 16'h0408, 1'b1, 3'd4); // ROM write

    // Idle MCU clock enables do not need a bus grant.
    force uut.BRn = 1'b1;
    force uut.BGACKn = 1'b1;
    force uut.mcu_acc = 1'b0;
    repeat (2) @(posedge clk);
    #1;
    assert_msg(uut.cpu_rst == 1'b0 && uut.mcu_bus == 1'b0,
        "idle case has no bus grant while CPU runs");
    assert_msg(uut.mcu_ok == 1'b1, "idle MCU access is nonblocking");
    pulse_expect_open();

    release uut.BRn;
    release uut.BGACKn;
    release uut.mcu_ctrl;
    release uut.mcu_addr;
    release uut.mcu_wr;
    release uut.mcu_acc;
    pass();
end

initial begin
    #100000;
    fail("timeout waiting for S16 MCU bus regression");
end

endmodule
