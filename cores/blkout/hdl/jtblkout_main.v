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

    Block Out main CPU (68000 @ 10 MHz). Address map (technos/blockout.cpp):
      000000-03ffff  program ROM              (SDRAM bank 0)
      100000-100009  P1/P2/SYSTEM/DSW1/DSW2   (read, A[3:1] selects)
      100010         IRQ6 ack (w)
      100012         IRQ5 ack (w)
      100015         sound latch (w, low byte)
      180000-1bffff  back framebuffer         (SDRAM bank 2, videoram_r/w)
      1d4000-1dffff  work RAM                 (BRAM)
      1f4000-1fffff  work RAM                 (BRAM)
      200000-207fff  front 1bpp overlay VRAM  (BRAM)
      208000-21ffff  work RAM                 (BRAM)
      280002         front colour reg (w)     -> pen 512
      280200-2805ff  palette RAM              (BRAM)
    IRQ6 @ scanline 250 (vblank-out), IRQ5 @ scanline 0 (vblank-in); acked by w.
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
    output reg           work_cs,
    output reg           work2_cs,
    output reg           work3_cs,
    output reg           fvram_cs,
    output reg           pal_cs,
    output reg           fb_cs,
    output reg           frontcol_cs, // 280002 pen-512 colour write
    output reg    [11:0] frontcol,    // pen-512 xBGR-444 colour

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
reg         irq6n, irq5n, LVBLl;
wire        irq6ack, irq5ack;
wire        bus_cs, bus_busy, bus_legit;

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
// SDRAM regions pace DTACK; BRAM/regs auto-ack (single-cycle, ok held high).
assign bus_cs    = rom_cs | fb_cs | work3_cs;
assign bus_busy  = (rom_cs & ~rom_ok) | (fb_cs & ~fb_ok) | (work3_cs & ~work3_ok);
assign bus_legit = 0;

always @* begin
    rom_cs      = allFC && A[23:18]==6'h0  && !ASn;                 // 000000-03ffff
    io_cs       = allFC && A[23:16]==8'h10 && !ASn;                 // 100000-10ffff
    fb_cs       = allFC && A[23:18]==6'h6  && !ASn;                 // 180000-1bffff
    work_cs     = allFC && A[23:16]==8'h1d && !ASn;                 // 1d0000-1dffff
    work2_cs    = allFC && A[23:16]==8'h1f && !ASn;                 // 1f0000-1fffff
    fvram_cs    = allFC && A[23:15]==9'h40 && !ASn;                 // 200000-207fff
    // 208000-21ffff: same 0x200000 page, above the overlay (A[16] or A[15] set)
    work3_cs    = allFC && A[23:17]==7'h10 && (A[16]|A[15]) && !ASn;
    // 280000 page: pen-512 colour reg @280002 (A[10:9]==0) vs palette @280200-2805ff
    pal_cs      = allFC && A[23:16]==8'h28 && A[15:11]==0 && (A[10]|A[9]) && !ASn;
    frontcol_cs = allFC && A[23:16]==8'h28 && A[15:9]==0 && !ASn && !RnW; // 280002 (w)
    io_rd       = io_cs && RnW;
end

always @* begin
    case( A[3:1] )
        3'd0:    cab_dout = { cab_1p[0], joystick1[6], joystick1[5], joystick1[7], joystick1[3:0] }; // P1
        3'd1:    cab_dout = { cab_1p[1], joystick2[6], joystick2[5], joystick2[7], joystick2[3:0] }; // P2
        3'd2:    cab_dout = { 4'hf, coin[2:0], 1'b1 };                    // SYSTEM: coin3/2/1 @ b3/2/1
        3'd3:    cab_dout = dipsw_a;                                      // DSW1
        3'd4:    cab_dout = { joystick2[4], joystick1[4], dipsw_b[5:0] }; // DSW2: b7=P2 A, b6=P1 A
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

// pen-512 colour register (0x280002, xBGR-444 in the low 12 bits)
always @(posedge clk, posedge rst) begin
    if( rst ) frontcol <= 0;
    else if( frontcol_cs ) frontcol <= cpu_dout[11:0];
end

// Dual vblank IRQ on LVBL edges; software acks via 100010 / 100012.
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq6n <= 1; irq5n <= 1; LVBLl <= 0;
    end else begin
        LVBLl <= LVBL;
        if(  LVBLl && !LVBL ) irq6n <= 0;   // entering vblank
        if( !LVBLl &&  LVBL ) irq5n <= 0;   // leaving vblank
        if( irq6ack ) irq6n <= 1;
        if( irq5ack ) irq5n <= 1;
    end
end

jtframe_68kdtack_cen #(.W(8)) u_dtack(
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
wire _unused = &{1'b0, service, tilt, cab_1p[3:2], coin[3]};
`else
assign main_addr=0, main_dsn=0, main_dout=0, main_rnw=1;
initial begin
    rom_cs=0; work_cs=0; work2_cs=0; work3_cs=0; fvram_cs=0; pal_cs=0; fb_cs=0; frontcol_cs=0;
    frontcol=0; snd_irq=0; snd_latch=0;
end
`endif
endmodule
