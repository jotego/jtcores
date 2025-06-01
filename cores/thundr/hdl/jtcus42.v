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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-3-2025 */

// dual tilemap with independent scroll
module jtcus42(
    input               rst,
    input               clk, pxl_cen, dec_en,
    input               flip, scrhflip, hs,
    input        [ 8:0] hdump, vdump,
    input        [ 3:0] scrhos,         // per game adjustment

    input               cs, cpu_rnw,
    input        [ 2:0] cpu_addr,
    input        [ 7:0] cpu_dout,

    output       [12:1] vram_addr,
    input        [15:0] vram_dout,
    output       [ 4:0] dec_addr,
    input        [ 7:0] dec_data,

    output              roma_cs, romb_cs,
    output       [15:2] roma_addr, romb_addr,
    input        [31:0] roma_data, romb_data,   // upper byte not used
    input               roma_ok, romb_ok,

    input         [2:0] ioctl_addr,
    output        [7:0] ioctl_din,

    output       [10:0] pxl,
    output       [ 2:0] prio,
    // debug
    input        [ 7:0] debug_bus,
    output       [ 7:0] st_dout
);

parameter ID=0,HBASE=9'd0;

localparam [2:0] ALPHA=7;

wire [10:0] scra_pxl, scrb_pxl;
wire [11:1] a_addr, b_addr;
wire [15:0] a_dout, b_dout;
wire [ 8:0] scrxa, scrxb;
reg  [ 8:0] effxa, effxb;
wire [ 2:0] prioa, priob;
wire [ 7:0] scrya, scryb, adec_data, bdec_data;
wire [ 4:0] adec_addr, bdec_addr;
wire        scra_op, scrb_op, selb;

assign scra_op = scra_pxl[2:0]!=ALPHA;
assign scrb_op = scrb_pxl[2:0]!=ALPHA;
assign selb    = scrb_op && (!scra_op || priob > prioa);
assign pxl     = selb ? scrb_pxl  : scra_pxl;
assign prio    = selb ? priob : prioa;

always @(posedge clk) begin
    effxa <= scrxa + { {5{scrhos[3]}}, scrhos };
    effxb <= scrxb + { {5{scrhos[3]}}, scrhos };
end

jtframe_ram_rdmux #(.AW(12),.DW(16)) u_vram_mux(
    .clk        ( clk           ),
    .addr       ( vram_addr     ),
    .data       ( vram_dout     ),
    .addr_a     ( {1'b0,a_addr} ),
    .addr_b     ( {1'b1,b_addr} ),
    .douta      ( a_dout        ),
    .doutb      ( b_dout        )
);

jtframe_ram_rdmux #(.AW(5),.DW(8)) u_dec_mux(
    .clk        ( clk           ),
    .addr       ( dec_addr      ),
    .data       ( dec_data      ),
    .addr_a     ( adec_addr     ),
    .addr_b     ( bdec_addr     ),
    .douta      ( adec_data     ),
    .doutb      ( bdec_data     )
);

jtcus42_mmr #(.SIMFILE(ID==0?"mmr0.bin":"mmr1.bin")) u_mmr(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .cs         ( cs            ),
    .addr       ( cpu_addr      ),
    .rnw        ( cpu_rnw       ),
    .din        ( cpu_dout      ),
    .dout       (               ),

    .scrxa      ( scrxa         ),
    .scrya      ( scrya         ),
    .scrxb      ( scrxb         ),
    .scryb      ( scryb         ),

    .prioa      ( prioa         ),
    .priob      ( priob         ),

    // IOCTL dump
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_dout       )
);

jtthundr_scroll #(.LYR(0),.HBASE(HBASE)) u_scra(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .dec_en     ( dec_en        ),
    .hs         ( hs            ),
    .flip       ( flip          ),
    .scrhflip   ( scrhflip      ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .scrx       ( effxa         ),
    .scry       ( scrya         ),

    .vram_addr  ( a_addr        ),
    .vram_dout  ( a_dout        ),
    .dec_addr   ( adec_addr     ),
    .dec_data   ( adec_data     ),

    .rom_cs     ( roma_cs       ),
    .rom_addr   ( roma_addr     ),
    .rom_data   ( roma_data     ),
    .rom_ok     ( roma_ok       ),
    .debug_bus  ( debug_bus     ),

    .pxl        ( scra_pxl      )
);

jtthundr_scroll #(.LYR(1),.HBASE(HBASE)) u_scrb(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .dec_en     ( dec_en        ),
    .hs         ( hs            ),
    .flip       ( flip          ),
    .scrhflip   ( scrhflip      ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .scrx       ( effxb         ),
    .scry       ( scryb         ),

    .vram_addr  ( b_addr        ),
    .vram_dout  ( b_dout        ),
    .dec_addr   ( bdec_addr     ),
    .dec_data   ( bdec_data     ),

    .rom_cs     ( romb_cs       ),
    .rom_addr   ( romb_addr     ),
    .rom_data   ( romb_data     ),
    .rom_ok     ( romb_ok       ),
    .debug_bus  ( debug_bus     ),

    .pxl        ( scrb_pxl      )
);

endmodule