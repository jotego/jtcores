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

    Author: Andrea Bogazzi. andreabogazzi79@gmail.com
    Version: 1.0
    Date: 17-06-2026 */

// Seta downtown.cpp (metafox-class) main 68000.
// Unlike calibr50 (cal50): the X1-010 lives on THIS bus (0x100000) and the
// 65C02 is an I/O / protection coprocessor reached through shared RAM (0xb00000).
//
// downtown_map nibble decode (A[23:20]):
//   0 ROM   1 X1-010 sound   2 protection   3 ipl1-ack   4 (unused: twineagl-only)
//   5 ctrl/coin   6 DSW   7 palette   8 X1-012 ctrl   9 X1-012 VRAM
//   A sub-ctrl   B shared RAM   C X1-001 bg-flag   D X1-001 spr-ctrl
//   E X1-001 spr-code   F work RAM
module jtarbalest_main(
    input                rst, clk, cen8,
    input                lvbl,

    output        [19:1] rom_addr,
    output        [15:1] ram_addr,
    output        [12:0] cpu_addr,
    output        [ 1:0] cpu_dsn,
    output        [ 1:0] ram_we,
    output        [15:0] cpu_dout,
    output               cpu_rnw,

    output reg           rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,
    input         [15:0] ram_dout,

    // X1-010 sound (on the main bus)
    output reg           x1_cs,
    input         [ 7:0] x1_dout,

    // I/O / protection sub-CPU (65C02). sub_ctrl_w (0xa00000) is decoded here:
    output reg    [ 7:0] slatch0, slatch1, // soundlatches, read by the sub @0x0800/1
    output               sub_rst,          // 0xa00000 bit0 rising -> stretched sub reset
    output reg           shram_cs,     // 0xb00000 shared RAM
    output               shram_we,
    input         [ 7:0] shram_dout,

    // X1-012 tilemap + palette
    output        [ 1:0] pal_we,
    input         [15:0] pal_dout,
    output reg           tctrl_cs,     // X1-012 control
    output        [ 1:0] tlv_we,
    input         [15:0] tlv_dout,

    // X1-001 sprites (same regions as cal50)
    output reg           vram_cs, vflag_cs, vctrl_cs,
    input         [15:0] vram_dout,

    // Game select (0=metafox, 1=arbalest)
    input         [ 3:0] game_id,
    // Cabinet (DSW read by main; joysticks/coins are read by the sub)
    input         [15:0] dipsw,
    input                dip_pause,
    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN
wire [23:1] A;
reg  [15:0] cpu_din;
reg  [ 2:0] IPLn;
reg         ram_cs, prot_cs, ipl1_cs, dips_cs, tlv_cs, pal_cs, subctrl_cs;
wire        int16ms,
            cpu_cen, cpu_cenb, dtackn, VPAn, vgfx_cs,
            UDSn, LDSn, RnW, ASn, BUSn, bus_busy, bus_cs;
reg         HALTn;

assign cpu_addr = A[13:1];
assign rom_addr = A[19:1];
assign ram_addr = A[15:1];
// VPAn (6800-style sync) asserted on the upper half so the level-3 vblank IRQ
// autovectors: the IACK address is all 1s -> A[23]=1. Same idiom as cal50.
// MAME: screen_vblank -> set_inputline(maincpu,3) with no vector cb = autovector.
assign VPAn     = ~&{A[23],~ASn};
assign cpu_dsn  = {UDSn, LDSn};
assign bus_cs   = rom_cs | vgfx_cs;
// X1-001/X1-012 RAM is dual-port BRAM (CPU + engine on separate ports), so the
// CPU needs NO access-arbitration stall. cal50's hdump-gated vgfx_bsy wait, when
// imported here, desynced the fx68k dtack on the POST's back-to-back sprite-RAM
// writes and corrupted an ALU result (e1c7+0f0f -> 1289 instead of f0d6),
// failing the sprite-RAM self-test. Dropping the stall fixes it.
assign bus_busy = rom_cs & ~rom_ok;
assign BUSn     = ASn | (LDSn & UDSn);
assign cpu_rnw  = RnW;
assign ram_we   = ~cpu_dsn & {2{ram_cs   & ~RnW}};
assign pal_we   = ~cpu_dsn & {2{pal_cs   & ~RnW}};
assign tlv_we   = ~cpu_dsn & {2{tlv_cs   & ~RnW}};
assign shram_we = shram_cs & ~RnW & ~LDSn;   // 8-bit shared RAM, low byte
assign st_dout  = 0;
assign vgfx_cs  = vram_cs | vflag_cs | vctrl_cs;

always @* begin
    rom_cs     = !BUSn &&  A[23:20]==0;
    x1_cs      = !ASn  &&  A[23:20]==1;   // X1-010
    prot_cs    = !ASn  &&  A[23:20]==2;   // protection / debug stub
    ipl1_cs    = !ASn  &&  A[23:20]==3;
//  ctrl/coin  = !ASn  &&  A[23:20]==5;
    dips_cs    = !ASn  &&  A[23:20]==6;
    pal_cs     = !ASn  &&  A[23:20]==7;
    tctrl_cs   = !ASn  &&  A[23:20]==8 && !RnW;
    tlv_cs     = !ASn  &&  A[23:20]==9 && !A[14];
    subctrl_cs = !ASn  &&  A[23:20]==4'hA;
    shram_cs   = !BUSn &&  A[23:20]==4'hB;
    // SETA X1-001 chip
    vflag_cs   = !ASn  &&  A[23:20]==4'hC;
    vctrl_cs   = !ASn  &&  A[23:20]==4'hD && (A[9:8]!=3 || !LDSn);
    vram_cs    = !ASn  &&  A[23:20]==4'hE;
    ram_cs     = !BUSn &&  A[23:20]==4'hF;
end

reg [7:0] dipsw_mx;
always @* dipsw_mx = A[1] ? dipsw[7:0] : dipsw[15:8];

// metafox X1-017 protection (game_id==0). MAME metafox_protection_r returns
// offset*0x1f (word offset within 0x21c000-0x21ffff) with three special words.
// The boot self-tests this readback sequence; arbalest has no 0x21c000 protection.
wire        prot_meta = prot_cs && game_id==4'd0 && A[19:14]==6'd7;
wire [12:0] prot_off  = A[13:1];
reg  [15:0] prot_dout;
always @* begin
    case( prot_off )
        13'h000:  prot_dout = 16'h003d;
        13'h800:  prot_dout = 16'h0076;
        13'h1000: prot_dout = 16'h0010;
        default:  prot_dout = prot_off * 16'd31;   // offset*0x1f
    endcase
end

// metafox main = a single level-3 IRQ on vblank (downtown.cpp:
// screen_vblank().set_inputline(maincpu, 3)). Acked by the 0x300000 write
// (ipl1_ack_w). NO timer/scanline IRQ on the main (that is calibr50-only).
always @* begin
    IPLn = 3'b111;               // level 0 (idle)
    if( int16ms ) IPLn = 3'b100; // level 3 vblank IRQ
end

always @(posedge clk) begin
    HALTn   <= dip_pause & ~rst;
    cpu_din <= rom_cs   ? rom_data          :
               ram_cs   ? ram_dout          :
   (vram_cs | vctrl_cs) ? vram_dout         :
               pal_cs   ? pal_dout          :
               tlv_cs   ? tlv_dout          :
               x1_cs    ? {8'd0, x1_dout}   :
               shram_cs ? {8'd0, shram_dout}:
               dips_cs  ? {8'hff, dipsw_mx} :
               prot_meta? prot_dout         :
               prot_cs  ? 16'hffff          : 16'h0;
end

// sub_ctrl_w (0xa00000-7, umask 0x00ff): off0 bit0 rising -> stretched sub reset;
// off4/off6 -> soundlatch0/1 (read by the sub at 0x0800/1). A[2:1] = sub_ctrl offset.
reg         subctrl0_b0;
reg  [ 4:0] subrst_cnt;        // stretch the reset pulse over a few cen8 ticks
wire        subctrl_we = subctrl_cs & ~RnW & ~LDSn;
assign      sub_rst    = rst | (subrst_cnt!=0);
always @(posedge clk) begin
    if( rst ) begin
        slatch0 <= 0; slatch1 <= 0; subctrl0_b0 <= 0; subrst_cnt <= 0;
    end else begin
        if( subctrl_we ) case( A[2:1] )
            2'd0: begin
                subctrl0_b0 <= cpu_dout[0];
                if( cpu_dout[0] & ~subctrl0_b0 ) subrst_cnt <= 5'h1f; // bit0 rising
            end
            2'd2: slatch0 <= cpu_dout[7:0];
            2'd3: slatch1 <= cpu_dout[7:0];
            default:;
        endcase
        if( subrst_cnt!=0 && cen8 ) subrst_cnt <= subrst_cnt - 5'd1;
    end
end

jtframe_edge u_16ms(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof (~lvbl      ),     // vblank (LVBL falling) -> level-3 IRQ
    .clr    ( ipl1_cs   ),     // acked by the 0x300000 write
    .q      ( int16ms   )
);

jtframe_68kdtack_cen #(.W(6),.RECOVERY(1)) u_bus_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 5'd1      ),
    .den        ( 6'd6      ),
    .DTACKn     ( dtackn    ),
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
    .FC         (             ),

    .BERRn      ( 1'b1        ),
    .HALTn      ( HALTn       ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( dtackn      ),
    .IPLn       ( IPLn        )
);
`else
    initial rom_cs = 0;
    assign rom_addr  = 0, ram_addr = 0, cpu_addr = 0, cpu_dsn = 3,
           ram_we    = 0, cpu_dout = 0, cpu_rnw = 1,
           pal_we    = 0, tlv_we = 0, shram_we = 0, sub_rst = rst,
           st_dout   = 0;
    initial begin
        x1_cs=0; subctrl_cs=0; shram_cs=0; tctrl_cs=0;
        vram_cs=0; vflag_cs=0; vctrl_cs=0; slatch0=0; slatch1=0;
    end
`endif
endmodule
