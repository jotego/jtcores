/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 31-7-2026
*/

module jtblkout_main(
    input                rst,
    input                clk,        // 24 MHz logic domain (clk24); SDRAM is 48 MHz
    input                LVBL,

    output        [17:1] main_addr,
    output        [ 1:0] main_dsn,
    output        [15:0] main_dout,
    output               main_rnw,
    output reg           rom_cs,
    output        [ 1:0] work_we,
    output        [ 1:0] work2_we,
    output               work3_sel,
    output        [16:1] work3_addr,
    output        [ 1:0] work3_dsn,
    output               work3_we,
    output        [ 1:0] fvram_we,
    output        [ 1:0] pal_we,
    output               fbram_sel,
    output        [17:1] fbram_addr,
    output        [ 1:0] fbram_dsn,
    output               fbram_we,
    output reg           frontcol_cs, // 280000-280003, pen-512 colour register

    input         [15:0] work_dout,
    input         [15:0] work2_dout,
    input         [15:0] work3_dout,
    input         [15:0] fvram_dout,
    input         [15:0] pal_dout,
    input         [15:0] fb_dout,
    input                fb_ok,
    input                work3_ok,   // work3 lives in SDRAM (bank 3)
    input         [15:0] rom_data,
    input                rom_ok,

    input                blockoutj,
    // sound latch (0x100015)
    output reg           snd_irq,
    output reg    [ 7:0] snd_latch,

    // cabinet (active-low, idle=1; no inversion)
    input         [ 7:0] joystick1,
    input         [ 7:0] joystick2,
    input         [ 3:0] cab_1p,
    input         [ 3:0] coin,
    input                service,
    input                tilt,
    input                dip_pause,
    input         [ 7:0] dipsw_a,
    input         [ 7:0] dipsw_b
);
`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg         io_cs, io_rd;
reg  [ 7:0] cab_dout;
reg  [15:0] cpu_din;
wire [15:0] cpu_dout;
wire        irq6n, irq5n;
wire        ok_dly;
wire        irq6ack, irq5ack;
wire        bus_cs, bus_busy, bus_legit;
wire        fb_wr, work3_wr;
wire [2:0]  ok_cs, ok_in;
reg         work_cs, work2_cs, work3_cs, fvram_cs, pal_cs, fb_cs;

assign main_addr = A[17:1];
assign main_dsn  = {UDSn, LDSn};
assign main_rnw  = RnW;
assign main_dout = cpu_dout;
assign allFC     = ~&FC;                 // high unless the CPU is in CPU space
assign IPLn      = !irq6n ? 3'b001 :     // level 6
                   !irq5n ? 3'b010 :     // level 5
                            3'b111;      // none
assign VPAn      = !(!ASn && FC==7);     // autovector all IRQs
assign irq6ack   = io_cs && !RnW && A[4:1]==4'h8; // 100010
assign irq5ack   = io_cs && !RnW && A[4:1]==4'h9; // 100012
// SDRAM regions pace DTACK;
assign bus_cs    = rom_cs | fb_cs | work3_cs;
assign ok_cs     = { rom_cs, fb_cs, work3_cs };
assign ok_in     = { rom_ok, fb_ok, work3_ok };
assign bus_busy  = (rom_cs | fb_cs | work3_cs) & ~ok_dly;
assign bus_legit = 0;
assign work_we   = {2{work_cs  & ~RnW}} & ~{UDSn, LDSn};
assign work2_we  = {2{work2_cs & ~RnW}} & ~{UDSn, LDSn};
assign fvram_we  = {2{fvram_cs & ~RnW}} & ~{UDSn, LDSn};
assign pal_we    = {2{pal_cs   & ~RnW}} & ~{UDSn, LDSn};

assign fb_wr       = fb_cs & ~RnW;
assign fbram_sel   = RnW ? fb_cs : (fb_wr & {UDSn, LDSn}!=2'b11);
assign fbram_addr  = A[17:1];
assign fbram_dsn   = {UDSn, LDSn};
assign fbram_we    = fb_wr & {UDSn, LDSn}!=2'b11;
assign work3_wr    = work3_cs & ~RnW;
assign work3_sel   = RnW ? work3_cs : (work3_wr & {UDSn, LDSn}!=2'b11);
assign work3_addr  = A[16:1];
assign work3_dsn   = {UDSn, LDSn};
assign work3_we    = work3_wr & {UDSn, LDSn}!=2'b11;

always @* begin
    rom_cs      = allFC && A[23:18]==6'h0  && !ASn && {UDSn,LDSn} != 2'b11;        // 000000-03ffff
    io_cs       = allFC && A[23:5]==19'h8000 && !ASn && {UDSn,LDSn} != 2'b11;      // 100000-100012
    fb_cs       = allFC && A[23:18]==6'h6  && !ASn;                                // 180000-1bffff
    work_cs     = allFC && A[23:16]==8'h1d && (A[15]|A[14]) && !ASn;               // 1d4000-1dffff
    work2_cs    = allFC && A[23:16]==8'h1f && (A[15]|A[14]) && !ASn;               // 1f4000-1fffff
    fvram_cs    = allFC && A[23:15]==9'h40 && !ASn;                                // 200000-207fff
    work3_cs    = allFC && A[23:17]==7'h10 && (A[16]|A[15]) && !ASn && {UDSn,LDSn} != 2'b11; // 208000-21ffff
    pal_cs      = allFC && A[23:12]==12'h280 && A[11]==0 && (A[10]^A[9]) && !ASn; // 280200-2805ff
    frontcol_cs = allFC && A[23:4]==20'h28000 && A[3:2]==0 && !ASn;                // 280000-280003
    io_rd       = io_cs && RnW;
end

always @* begin
    case( A[3:1] )
        3'd0:    cab_dout = { cab_1p[0], joystick1[6], joystick1[5], blockoutj ? joystick1[4] : joystick1[7], joystick1[3:0] }; // P1
        3'd1:    cab_dout = { cab_1p[1], joystick2[6], joystick2[5], blockoutj ? joystick2[4] : joystick2[7], joystick2[3:0] }; // P2
        3'd2:    cab_dout = { 4'hf, coin[2:0], 1'b1 };                    // SYSTEM: coin3/2/1 @ b3/2/1
        3'd3:    cab_dout = dipsw_a;                                      // DSW1
        3'd4:    cab_dout = blockoutj ? dipsw_b[7:0] : { joystick2[4], joystick1[4], dipsw_b[5:0] }; // DSW2: b7=P2 A, b6=P1 A
        default: cab_dout = 8'hff;
    endcase
end

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_data   :
               work_cs  ? work_dout  :
               work2_cs ? work2_dout :
               work3_cs ? work3_dout :
               fvram_cs ? fvram_dout :
               pal_cs   ? pal_dout   :
               fb_cs    ? fb_dout    :
               io_rd    ? {cab_dout, cab_dout} :
               16'hffff;
end

jtframe_okdly #(.W(3)) u_okdly(
    .rst    ( rst    ),
    .clk    ( clk    ),
    .cs     ( ok_cs  ),
    .ok     ( ok_in  ),
    .ok_dly ( ok_dly )
);

// sound latch @ 0x100015 (odd byte -> LDS)
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_irq   <= 0;
        snd_latch <= 0;
    end else begin
        snd_irq   <= io_cs && !RnW && A[4:1]==4'hA && !LDSn;
        if( io_cs && !RnW && A[4:1]==4'hA && !LDSn ) snd_latch <= cpu_dout[7:0];
    end
end

jtframe_edge #(.QSET(0), .ATRST(1)) u_irq5 (
    .rst    ( rst              ),
    .clk    ( clk              ),
    .edgeof ( LVBL & dip_pause ),
    .clr    ( irq5ack          ),
    .q      ( irq5n            )
);

jtframe_edge #(.QSET(0), .ATRST(1)) u_irq6 (
    .rst    ( rst               ),
    .clk    ( clk               ),
    .edgeof ( ~LVBL & dip_pause ),
    .clr    ( irq6ack           ),
    .q      ( irq6n             )
);

// TODO: experiment with cache size to save on WD.
jtframe_68kdtack_cen #(.W(8),.WD(12)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( bus_legit ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 7'd5      ),  // 24 MHz * 5/12 = 10 MHz
    .den        ( 8'd12     ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),

    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);
// this is a claude 'make lint pass' artifact. and i need time to understand what to do.
wire _unused = &{1'b0, service, tilt, cab_1p[3:2], coin[3]};
`else
assign main_addr=0, main_dsn=0, main_dout=0, main_rnw=1;
assign work_we=0, work2_we=0, work3_sel=0, work3_addr=0, work3_dsn=0, work3_we=0;
assign fvram_we=0, pal_we=0, fbram_sel=0, fbram_addr=0, fbram_dsn=0, fbram_we=0;
initial begin
    rom_cs=0; frontcol_cs=0;
    snd_irq=0; snd_latch=0;
end
`endif
endmodule
