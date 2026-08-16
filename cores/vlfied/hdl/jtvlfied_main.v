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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 7-8-2026 */

module jtvlfied_main(
    input                rst,
    input                clk,            // 48 MHz
    input                LVBL,

    output        [19:1] main_addr,
    output        [ 1:0] main_dsn,
    output        [15:0] main_dout,
    output               main_rnw,
    output reg           rom_cs,
    output reg           ram_cs,
    output reg           obj_cs,
    output reg           fb_cs,
    output reg           pal_cs,
    output reg           vmask_cs,       // 600000 video mask write
    output reg           sprctrl_cs,     // 700000 sprite control write
    output reg           vctrl_cs,       // d00000 video control r/w
    output        [ 3:0] obj_pal,        // sprite palette bank = sprite_ctrl[5:2]

    input         [15:0] oram_dout,
    input         [15:0] pal_dout,
    input         [15:0] fb_dout,
    input         [15:0] vctrl_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                rom_ok,

    // C-chip (TC0030CMD) interface, 8-bit on lower byte
    output reg           cchip_cs,
    output        [11:1] cchip_addr,
    input         [ 7:0] cchip_dout,

    // bitmap framebuffer in SDRAM (jtvlfied_fb) — fb_ok paces the 68k
    input                fb_ok,

    output               cpu_cen,
    input         [ 7:0] sn_dout,
    output reg           sn_we,
    output reg           sn_rd,

    input                dip_pause
);
`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cenb;
wire        UDSn, LDSn, allFC, ASn, VPAn, DTACKn, busn;
wire [ 2:0] FC, IPLn;
reg  [15:0] cpu_din;
wire [ 7:0] obj_ctrl;
wire        intn;
wire        bus_cs, bus_busy, bus_legit;

assign main_addr = A[19:1];
assign main_dsn  = {UDSn, LDSn};
assign cchip_addr= A[11:1];
assign obj_pal   = obj_ctrl[5:2];
assign allFC     = ~&FC;
assign busn      = ASn | (UDSn & LDSn);
// VBL is a level-4 autovector interrupt
assign IPLn      = { intn, 2'b11 };
assign VPAn      = !(!ASn && FC==7);
assign bus_cs    = rom_cs | ram_cs | fb_cs;
assign bus_busy  = (rom_cs & ~rom_ok) | (fb_cs & ~fb_ok);
assign bus_legit = 0;

always @* begin
    rom_cs     = allFC && A[23:20]==4'h0 && !busn;            // 000000-0fffff
    ram_cs     = allFC && A[23:18]==6'h4 && !busn;            // 100000-103fff
    obj_cs     = allFC && A[23:18]==6'h8 && !busn;            // 200000-203fff
    fb_cs      = allFC && A[23:19]==5'h8 && !busn;            // 400000-47ffff
    pal_cs     = allFC && A[23:18]==6'h14&& !busn;            // 500000-503fff
    vmask_cs   = allFC && A[23:20]==4'h6 && !busn && !main_rnw;    // 600000
    sprctrl_cs = allFC && A[23:20]==4'h7 && !busn && !main_rnw;    // 700000
    vctrl_cs   = allFC && A[23:20]==4'hd && !busn;            // d00000
    cchip_cs   = allFC && A[23:20]==4'hf && !busn;            // f00000-f00fff

    // PC060HA is on the odd byte only; A[1] selects port (0) from comm (1)
    sn_we = allFC && A[23:20]==4'he && !ASn && !LDSn && !main_rnw;
    sn_rd = allFC && A[23:20]==4'he && !ASn && !LDSn &&  main_rnw;
end

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_data :
               ram_cs   ? ram_dout :
               obj_cs   ? oram_dout :
               pal_cs   ? pal_dout  :
               fb_cs    ? fb_dout   :
               vctrl_cs ? vctrl_dout :
               cchip_cs ? { 8'hff, cchip_dout } :
               sn_rd    ? { 8'hff, sn_dout }    :
               16'hffff;
end

jtframe_edge #(.QSET(0)) u_irq(
    .rst    ( rst               ),
    .clk    ( clk               ),
    .edgeof ( ~LVBL & dip_pause ),
    .clr    ( ~VPAn             ),
    .q      ( intn              )
);

jtframe_68kdtack_cen #(.W(12)) u_dtack(
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
    .num        ( 11'd231   ),
    .den        ( 12'd1541  ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

// PC090OJ colbank = 0x100 | ((sprite_ctrl & 0x3c)<<2), and its pen is
// (colbank+color)*16+pixel, so the palette index is {1, sprite_ctrl[5:2], pixel}
jtframe_8bit_reg u_obj_ctrl(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .wr_n       ( main_rnw | LDSn ),
    .din        ( main_dout[7:0]   ),
    .cs         ( sprctrl_cs      ),
    .dout       ( obj_ctrl        )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( main_dout   ),

    .eRWn       ( main_rnw    ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    .HALTn      ( 1'b1        ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    // Non-SDRAM regions are auto-acked by u_dtack when bus_cs=0
    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);
`else
assign main_addr=0, main_dsn=0, main_dout=0, main_rnw=1, cchip_addr=0, cpu_cen=0, obj_pal=0;
initial begin
    rom_cs=0; ram_cs=0; obj_cs=0; fb_cs=0; pal_cs=0;
    vmask_cs=0; sprctrl_cs=0; vctrl_cs=0; cchip_cs=0; sn_we=0; sn_rd=0;
end
`endif
endmodule
