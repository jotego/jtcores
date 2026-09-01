/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

// Moo object producer.  The board's 053246/053247 pair is represented by the
// established JTCORE scan, DMA and draw blocks; board glue remains here.
module jtmoomsa_obj(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,
    input      [8:0]  hdump,
    input      [8:0]  vdump,
    input      [9:0]  voffset,
    input             hs,
    input             lvbl,
    input      [7:0]  cfg,
    input      [9:0]  xoffset,
    input      [9:0]  yoffset,
    input      [22:1] rmrd_addr,
    input      [15:0] dma_data,
    output     [13:1] dma_addr,
    output            dma_bsy,
    output     [22:2] rom_addr,
    output            rom_cs,
    input      [31:0] rom_data,
    input             rom_ok,
    input             objcha_n,
    input             objsys_cs,
    output     [15:0] objsys_dout,
    output     [4:0]  prio,
    output     [1:0]  shd,
    output     [8:0]  pxl,
    input      [3:0]  gfx_en
);

wire [15:0] scan_even, scan_odd, dma_din;
/* The PCB has no named sink for the donor scan-complete status. */
/* verilator lint_off UNUSEDSIGNAL */
wire        scan_done;
wire        dma_flicker;
wire [15:0] dma_even_q0;
wire [15:0] dma_odd_q0;
wire [3:0]  cfg_unused_diag = {cfg[7:5],cfg[3]};
wire [2:0]  gfx_en_unused_diag = gfx_en[2:0];
wire        dma_addr_lane_diag = dma_wr_addr[1];
/* verilator lint_on UNUSEDSIGNAL */
wire [11:2] scan_addr;
wire [11:1] dma_wr_addr;
wire [9:0]  scan_xoffset, scan_yoffset;
wire [1:0]  scan_shd;
wire [3:0]  ysub;
wire [15:0] code;
wire [9:0]  attr;
wire        hflip, vflip, hz_keep, dr_start, dr_busy;
wire [9:0]  hpos;
wire [11:0] hzoom;
wire        dma_weh, dma_wel;
wire [31:0] sorted;
wire [22:2] pre_addr;
wire [15:0] pre_pxl;
wire [3:0]  pen_eff;
wire        pre_cs;

assign scan_xoffset = xoffset;
assign scan_yoffset = yoffset;
// Shadow is carried by pen 15 only: a shadowed sprite emits its shadow code
// with a transparent pen, every other pen passes through unaltered.
assign pen_eff = (pre_pxl[15:14] == 2'b00 || !(&pre_pxl[3:0])) ?
                 pre_pxl[3:0] : 4'd0;
assign prio = pre_pxl[13:9];
assign shd  = pre_pxl[15:14];
assign pxl = gfx_en[3] ? {pre_pxl[8:4],pen_eff} : 9'd0;

wire objsys_rom_cs = objsys_cs && !objcha_n;

assign rom_cs = objsys_rom_cs || pre_cs;
assign rom_addr = objsys_rom_cs ? rmrd_addr[22:2] :
    {pre_addr[22:7],pre_addr[5:2],pre_addr[6]};
assign objsys_dout = objsys_rom_cs ?
    (rmrd_addr[1] ? rom_data[31:16] : rom_data[15:0]) : 16'hffff;

jt053246_scan #(.HOFFSET(10'h3d1)) u_scan(
    .rst       (rst),
    .clk       (clk),
    .voffset   (voffset),
    .done      (scan_done),
    .code      (code),
    .attr      (attr),
    .hflip     (hflip),
    .vflip     (vflip),
    .hpos      (hpos),
    .ysub      (ysub),
    .hzoom     (hzoom),
    .hz_keep   (hz_keep),
    .hdump     (hdump),
    .vdump     (vdump),
    .hs        (hs),
    .scan_even (scan_even),
    .scan_odd  (scan_odd),
    .xoffset   (scan_xoffset),
    .yoffset   (scan_yoffset),
    .ghf       (cfg[0]),
    .gvf       (cfg[1]),
    .scan_addr (scan_addr),
    .shd       (scan_shd),
    .dr_start  (dr_start),
    .dr_busy   (dr_busy),
    .debug_bus (8'd0)
);

jt053246_dma #(.EDGE_TRIGGER(1)) u_dma(
    .rst        (rst),
    .clk        (clk),
    .pxl2_cen   (pxl2_cen),
    .mode8      (cfg[2]),
    .dma_en     (cfg[4]),
    .dma_trig   (1'b0),
    .k44_en     (1'b0),
    .simson     (1'b0),
    .hs         (hs),
    .lvbl       (lvbl),
    .dma_addr   (dma_addr),
    .dma_data   (dma_data),
    .dma_bsy    (dma_bsy),
    .dma_weh    (dma_weh),
    .dma_wel    (dma_wel),
    .dma_wr_addr(dma_wr_addr),
    .dma_din    (dma_din),
    .flicker    (dma_flicker)
);

jtframe_dual_ram16 #(.AW(10)) u_even(
    .clk0  (clk), .data0(dma_din), .addr0(dma_wr_addr[11:2]),
    .we0   ({2{dma_wel}}), .q0(dma_even_q0),
    .clk1  (clk), .data1(16'd0), .addr1(scan_addr),
    .we1   (2'b00), .q1(scan_even)
);

jtframe_dual_ram16 #(.AW(10)) u_odd(
    .clk0  (clk), .data0(dma_din), .addr0(dma_wr_addr[11:2]),
    .we0   ({2{dma_weh}}), .q0(dma_odd_q0),
    .clk1  (clk), .data1(16'd0), .addr1(scan_addr),
    .we1   (2'b00), .q1(scan_odd)
);

jtframe_8x8x4_packed_msb u_packed(.raw(rom_data),.sorted(sorted));

jtframe_objdraw #(
    .SHADOW(0), .AW(10), .CW(16), .PW(16), .LATCH(1), .SWAPH(1),
    .ZW(12), .ZI(6), .ZENLARGE(1), .SW(2), .FLIP_OFFSET(9'h12)
) u_draw(
    .rst      (rst),
    .clk      (clk),
    .pxl_cen  (pxl_cen),
    .hs       (hs),
    .flip     (1'b0),
    .hdump    ({1'b0,hdump}),
    .draw     (dr_start),
    .busy     (dr_busy),
    .code     (code),
    .xpos     (hpos),
    .ysub     (ysub),
    .hzoom    (hzoom),
    .hz_keep  (hz_keep),
    .hflip    (~hflip),
    .vflip    (vflip),
    .pal      ({scan_shd,attr}),
    .rom_addr (pre_addr),
    .rom_cs   (pre_cs),
    .rom_ok   (rom_ok),
    .rom_data (sorted),
    .pxl      (pre_pxl)
);

endmodule
