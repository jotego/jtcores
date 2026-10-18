/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-10-2026 */

module jtseicro_decode(
    input      [15:0] addr,
    input             mreq_n, iorq_n, m1_n, rfsh_n, rd_n, wr_n,
    output            rom_cs, shared_cs, vram_cs, color_cs,
    output            obj0_cs, obj1_cs, scroll_cs,
    output            in0_cs, in1_cs, test_cs, watchdog_clr,
    output            ay_bdir, ay_bc1
);

wire mem = !mreq_n && rfsh_n;
wire io = !iorq_n && m1_n;
wire ay_write = io && !wr_n && (addr[7:0] & 8'hf6)==0;
wire ay_read = io && !rd_n && (addr[7:0] & 8'hf7)==8'h04;

assign rom_cs = mem && !rd_n && addr < 16'h7800;
assign shared_cs = mem && addr[15:11]==5'b01111;
assign vram_cs = mem && addr[15:10]==6'b100100;
assign color_cs = mem && addr[15:10]==6'b100111;
assign obj0_cs = mem && addr>=16'h8820 && addr<=16'h887f;
assign obj1_cs = mem && !wr_n && addr[15:5]==11'h4c4;
assign scroll_cs = mem && addr[15:5]==11'h4c0;
assign in0_cs = mem && !rd_n && addr==16'ha000;
assign in1_cs = mem && !rd_n && addr==16'ha800;
assign test_cs = mem && !rd_n && addr==16'hb000;
assign watchdog_clr = mem && !rd_n && addr==16'hb800;
assign ay_bdir = ay_write;
assign ay_bc1 = (ay_write && !addr[0]) || ay_read;

endmodule
