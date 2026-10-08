/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps

module test;

reg         rst = 1'b1;
reg         clk = 1'b0;
reg         cen = 1'b0;
reg         int0n = 1'b1, int1n = 1'b1;
reg  [ 7:0] p0_i = 8'hff, p1_i = 8'h00, p2_i = 8'hff, p3_i = 8'hff;
wire [ 7:0] p0_o, p1_o, p2_o, p3_o;
reg  [ 7:0] x_din = 8'd0;
wire [ 7:0] x_dout;
wire [15:0] x_addr;
wire        x_wr, x_acc;
reg  [11:0] prog_addr = 12'd0;
reg  [ 7:0] prom_din = 8'd0;
reg         prom_we = 1'b0;
reg  [ 7:0] xmem [0:65535];
reg  [15:0] xread_addr = 16'd0;
reg         xread_pending = 1'b0;
reg  [ 3:0] gap = 4'd0;
reg  [ 7:0] lfsr = 8'h1;
reg         cen_l = 1'b0, state_valid = 1'b0;
reg         movx_acc_l = 1'b0;
reg [255:0] held_state;
integer i;

always #5 clk = ~clk;

// cen is deliberately irregular, but high pulses always have an idle cycle
// between them. This exercises the controller's clock-enable contract.
always @(posedge clk) begin
    if (rst) begin
        cen  <= 1'b0;
        gap  <= 4'd0;
        lfsr <= 8'h1;
    end else if (cen) begin
        cen  <= 1'b0;
        lfsr <= {lfsr[6:0],lfsr[7]^lfsr[5]^lfsr[4]^lfsr[3]};
        gap  <= {2'd0,lfsr[1:0]};
    end else if (gap == 0) begin
        cen <= 1'b1;
    end else begin
        gap <= gap - 1'd1;
    end
end

// Sample immediately after every enabled edge.  During each following idle
// edge, no architectural CPU state may advance even though the wrapper clock
// itself keeps running.
always @(posedge clk) cen_l <= cen;
always @(negedge clk) begin
    if (rst) begin
        state_valid = 1'b0;
    end else if (cen_l) begin
        // A synchronous XDATA wrapper needs wait microsteps after the
        // request, but the mapper must see precisely one access strobe.
        // Consecutive asserted control-store slots would turn one MOVX into
        // several mapper cycles.
        if (uut.u_mcu.x_acc_i && movx_acc_l)
            $fatal(1, "MOVX x_acc asserted for consecutive MCU microsteps");
        movx_acc_l = uut.u_mcu.x_acc_i;
        held_state = {uut.u_mcu.pc, uut.u_mcu.ir, uut.u_mcu.a, uut.u_mcu.b,
                      uut.u_mcu.psw, uut.u_mcu.sp, uut.u_mcu.dptr,
                      uut.u_mcu.u_ctrl.uaddr, uut.u_mcu.rom_addr,
                      uut.u_mcu.ram_addr, uut.u_mcu.ram_we, uut.u_mcu.ram_dout,
                      uut.u_mcu.x_addr, uut.u_mcu.x_wr, uut.u_mcu.x_acc,
                      uut.u_mcu.x_dout};
        state_valid = 1'b1;
    end else if (state_valid && {uut.u_mcu.pc, uut.u_mcu.ir, uut.u_mcu.a, uut.u_mcu.b,
                                 uut.u_mcu.psw, uut.u_mcu.sp, uut.u_mcu.dptr,
                                 uut.u_mcu.u_ctrl.uaddr, uut.u_mcu.rom_addr,
                                 uut.u_mcu.ram_addr, uut.u_mcu.ram_we, uut.u_mcu.ram_dout,
                                 uut.u_mcu.x_addr, uut.u_mcu.x_wr, uut.u_mcu.x_acc,
                                 uut.u_mcu.x_dout} !== held_state) begin
        $fatal(1, "JT8051 state or core bus advanced while cen was low");
    end
end

always @(posedge clk) begin
    if (rst) begin
        x_din          <= 8'hff;
        xread_pending  <= 1'b0;
    end else if (cen) begin
        // S16 returns a byte on the enabled edge after the request, then
        // changes it on the following enabled edge.  This is the transient
        // XDATA response seen in the Body Slam waveform.
        // Address 1236 models a fast target whose response is already
        // present on the request phase.  Other reads model the shared-ROM
        // response one enabled edge later.  Both retain the returned byte
        // until a later transaction, as the MCU bus latch does.
        if (xread_pending) begin
            x_din <= xmem[xread_addr];
            xread_pending <= 1'b0;
        end else if (x_acc && !x_wr) begin
            if (x_addr == 16'h1236) begin
                x_din <= xmem[x_addr];
            end else begin
                xread_addr <= x_addr;
                xread_pending <= 1'b1;
            end
        end
        if (x_acc && x_wr) xmem[x_addr] <= x_dout;
    end
end

task put;
    input [11:0] addr;
    input [ 7:0] data;
begin
    @(negedge clk);
    prog_addr = addr;
    prom_din  = data;
    prom_we   = 1'b1;
    @(negedge clk);
    prom_we   = 1'b0;
end
endtask

`include "test_tasks.vh"

jtframe_8751mcu #(.SYNC_XDATA(1)) uut(
    .rst, .clk, .cen, .int0n, .int1n, .p0_i, .p1_i, .p2_i, .p3_i,
    .p0_o, .p1_o, .p2_o, .p3_o,
    .x_din, .x_dout, .x_addr, .x_wr, .x_acc,
    .clk_rom(clk), .prog_addr, .prom_din, .prom_we
);

initial begin
    for (i=0; i<65536; i=i+1) xmem[i] = 8'd0;
    xmem[16'h1235] = 8'ha5;
    xmem[16'h1236] = 8'h3c;
    // Register, indirect, direct, stack, call/return, MOVC and MOVX.
    put(12'h000,8'h78); put(12'h001,8'h20); // MOV R0,#20
    put(12'h002,8'h76); put(12'h003,8'haa); // MOV @R0,#aa
    put(12'h004,8'he6);                      // MOV A,@R0
    put(12'h005,8'h24); put(12'h006,8'h01); // ADD A,#1
    put(12'h007,8'hf5); put(12'h008,8'h30); // MOV 30,A
    put(12'h009,8'he5); put(12'h00a,8'h30); // MOV A,30
    put(12'h00b,8'hf5); put(12'h00c,8'h90); // MOV P1,A
    put(12'h00d,8'h74); put(12'h00e,8'h12); // MOV A,#12
    put(12'h00f,8'hc0); put(12'h010,8'he0); // PUSH ACC
    put(12'h011,8'h74); put(12'h012,8'h00); // MOV A,#00
    put(12'h013,8'hd0); put(12'h014,8'he0); // POP ACC
    put(12'h015,8'hf5); put(12'h016,8'ha0); // MOV P2,A
    put(12'h017,8'h12); put(12'h018,8'h00); put(12'h019,8'h80); // LCALL
    put(12'h01a,8'hf5); put(12'h01b,8'h35); // Save LCALL result
    put(12'h01c,8'h90); put(12'h01d,8'h01); put(12'h01e,8'h00); // DPTR
    put(12'h01f,8'h74); put(12'h020,8'h02); // A=2
    put(12'h021,8'h93);                      // MOVC A,@A+DPTR
    put(12'h022,8'hf5); put(12'h023,8'h36); // save MOVC result
    put(12'h024,8'h90); put(12'h025,8'h12); put(12'h026,8'h34); // DPTR
    put(12'h027,8'h74); put(12'h028,8'h66); // A=66
    put(12'h029,8'hf0);                      // MOVX @DPTR,A
    put(12'h02a,8'h74); put(12'h02b,8'h00); // A=0
    put(12'h02c,8'he0);                      // MOVX A,@DPTR
    put(12'h02d,8'hf5); put(12'h02e,8'hb0); // MOV P3,A
    put(12'h02f,8'h78); put(12'h030,8'h55); // MOV R0,#55
    put(12'h031,8'h74); put(12'h032,8'h3c); // MOV A,#3c
    put(12'h033,8'hf8);                      // MOV R0,A
    put(12'h034,8'h74); put(12'h035,8'h00); // MOV A,#0
    put(12'h036,8'he8);                      // MOV A,R0
    put(12'h037,8'hf5); put(12'h038,8'h31); // MOV 31,A
    put(12'h039,8'h74); put(12'h03a,8'h09); // MOV A,#09
    put(12'h03b,8'h24); put(12'h03c,8'h01); // ADD A,#1
    put(12'h03d,8'hd4);                      // DA A
    put(12'h03e,8'hf5); put(12'h03f,8'h32); // MOV 32,A
    put(12'h040,8'h74); put(12'h041,8'h17); // MOV A,#17
    put(12'h042,8'h75); put(12'h043,8'hf0); put(12'h044,8'h05); // MOV B,#5
    put(12'h045,8'h84);                      // DIV AB
    put(12'h046,8'hf5); put(12'h047,8'h33); // MOV 33,A
    put(12'h048,8'he5); put(12'h049,8'hf0); // MOV A,B
    put(12'h04a,8'hf5); put(12'h04b,8'h34); // MOV 34,A
    // JBC is a read-modify-write operation, so it reads a port latch even
    // when the physical input pin differs.  The first branch must not take
    // (latch 0/pin 0); the second must take and clear latch bit 0 (latch 1/pin 0).
    put(12'h04c,8'h75); put(12'h04d,8'h90); put(12'h04e,8'h00); // P1 latch=0
    put(12'h04f,8'h10); put(12'h050,8'h90); put(12'h051,8'h03); // JBC P1.0,55
    put(12'h052,8'h75); put(12'h053,8'h80); put(12'h054,8'ha5); // must execute
    put(12'h055,8'h75); put(12'h056,8'h90); put(12'h057,8'h01); // P1 latch=1
    put(12'h058,8'h10); put(12'h059,8'h90); put(12'h05a,8'h03); // JBC P1.0,5e
    put(12'h05b,8'h75); put(12'h05c,8'h80); put(12'h05d,8'hee); // must skip
    // A MOVX read must receive the byte for its current address, not the
    // previous transaction's synchronous-XDATA value.
    put(12'h05e,8'h90); put(12'h05f,8'h12); put(12'h060,8'h35); // DPTR=1235
    put(12'h061,8'he0);                      // MOVX A,@DPTR
    put(12'h062,8'hf5); put(12'h063,8'h37); // save distinct read value
    put(12'h064,8'h90); put(12'h065,8'h12); put(12'h066,8'h36); // DPTR=1236
    put(12'h067,8'he0);                      // MOVX A,@DPTR (fast response)
    put(12'h068,8'hf5); put(12'h069,8'h38); // save fast read value
    put(12'h06a,8'h80); put(12'h06b,8'hfe); // loop
    put(12'h080,8'h24); put(12'h081,8'h34); put(12'h082,8'h22); // ADD; RET
    put(12'h100,8'h00); put(12'h101,8'h00); put(12'h102,8'h5a); // code table

    repeat (16) @(posedge clk);
    rst = 1'b0;
    repeat (12000) @(posedge clk);
    assert_msg(uut.u_ramu.u_ramu.mem[7'h36] == 8'h5a, "MOVC through synchronous program memory");
    assert_msg(uut.u_ramu.u_ramu.mem[7'h30] == 8'hab, "direct and indirect internal RAM path");
    assert_msg(p2_o == 8'h12, "PUSH/POP through synchronous internal RAM");
    assert_msg(p3_o == 8'h66, "MOVX external-memory read/write path");
    assert_msg(uut.u_ramu.u_ramu.mem[7'h35] == 8'h46, "LCALL/RET stack return path");
    assert_msg(uut.u_ramu.u_ramu.mem[7'h31] == 8'h3c, "MOV Rn,A and MOV A,Rn");
    assert_msg(uut.u_ramu.u_ramu.mem[7'h32] == 8'h10, "DA A BCD adjustment");
    assert_msg(uut.u_ramu.u_ramu.mem[7'h33] == 8'h04, "DIV AB quotient");
    assert_msg(uut.u_ramu.u_ramu.mem[7'h34] == 8'h03, "DIV AB remainder");
    assert_msg(uut.u_ramu.u_ramu.mem[7'h37] == 8'ha5, "MOVX reads the current synchronous-XDATA address");
    assert_msg(uut.u_ramu.u_ramu.mem[7'h38] == 8'h3c, "MOVX retains a fast synchronous-XDATA response");
    assert_msg(p0_o == 8'ha5, "JBC does not branch from a clear P1 latch");
    assert_msg(p1_o == 8'h00, "JBC branches and clears a set P1 latch");
    pass();
end

endmodule
