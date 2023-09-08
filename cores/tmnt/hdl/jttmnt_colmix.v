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
    Date: 15-4-2023 */

module jttmnt_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input      [ 2:0] game_id,
    input      [ 1:0] cpu_prio,

    // Base Video
    input             lhbl,
    input             lvbl,

    // CPU interface
    input             pcu_cs,
    input             pal_cs,
    input             cpu_we,
    input      [15:0] cpu_dout,
    input      [ 7:0] cpu_d8,
    input      [ 1:0] cpu_dsn,
    input      [12:1] cpu_addr,
    output     [15:0] cpu_din,

    // PROMs
    input      [ 7:0] prog_addr,
    input      [ 2:0] prog_data,
    input             prom_we,

    // Final pixels
    input             lyrf_blnk_n,
    input             lyra_blnk_n,
    input             lyrb_blnk_n,
    input             lyro_blnk_n,
    input      [ 7:0] lyrf_pxl,
    input      [11:0] lyra_pxl,
    input      [11:0] lyrb_pxl,
    input      [11:0] lyro_pxl,
    input             shadow,
    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    // Debug
    input      [11:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,
    output     [ 7:0] dump_mmr,

    input      [ 7:0] debug_bus
);

parameter IOCTL_A0=0;

`include "game_id.inc"

wire [ 1:0] prio_sel, cpu_palwe, k251_shd;
wire [ 7:0] prio_addr;
wire [15:0] cpu_paldo, cpu_paldi, pal_dout;
reg  [ 9:0] pxl;
reg  [15:0] pxl_aux;
reg  [23:0] bgr;
wire [10:0] pal_addr;
wire [10:0] k251_pxl, cpu_pala;
wire        shad, pcu_we;
reg         shl, k251_en;

assign prio_addr = { cpu_prio,  lyrb_pxl[7], shadow,
    lyrf_blnk_n, lyro_blnk_n, lyrb_blnk_n, lyra_blnk_n };
// 8/16 bit interface
assign cpu_pala  = k251_en ? cpu_addr[11:1] : cpu_addr[12:2];
assign cpu_palwe = {2{cpu_we&pal_cs}} & ( k251_en ? ~cpu_dsn : {~cpu_addr[1], cpu_addr[1]} );
assign cpu_paldi = k251_en ? cpu_dout : {2{cpu_d8}};
assign cpu_din   = k251_en ? cpu_paldo : { cpu_paldo[15:8], cpu_addr[1] ? cpu_paldo[7:0] : cpu_paldo[15:8] };
assign pal_addr  = k251_en ? k251_pxl : { 1'b0, pxl };
assign pcu_we    = pcu_cs & ~cpu_dsn[0] & cpu_we;

// fround needs the reverse order
assign ioctl_din = ioctl_addr[0]^IOCTL_A0[0] ? pal_dout[7:0] : pal_dout[15:8];
assign {blue,green,red} = (lvbl & lhbl ) ? bgr : 24'd0;

always @(posedge clk) begin
    k251_en <= game_id==PUNKSHOT;
end

always @* begin
    case( game_id )
        MIA:
        case( prio_sel )
            0: pxl[7:0] = { 1'b0, lyra_pxl[7:5], lyra_pxl[3:0] };
            1: pxl[7:0] = { 1'b1, lyrb_pxl[7:5], lyrb_pxl[3:0] };
            2: pxl[7:0] = lyro_pxl[7:0];
            3: pxl[7:0] = { lyrf_pxl[4], lyrf_pxl[7], 2'd0, lyrf_pxl[3:0] };
        endcase
        // TMNT
        default:
        case( prio_sel )
            0: pxl[7:0] = { 1'b0, lyra_pxl[7:5], lyra_pxl[3:0] };
            1: pxl[7:0] = { 1'b1, lyrb_pxl[7:5], lyrb_pxl[3:0] };
            2: pxl[7:0] = lyro_pxl[7:0];
            3: pxl[7:0] = { 1'b0, lyrf_pxl[7:5], lyrf_pxl[3:0] };
        endcase
    endcase
    pxl[9:8] = { ~prio_sel[1], ~|{prio_sel[0], ~prio_sel[1]} };
end

function [7:0] dim75( input [7:0] d );
    dim75 = d - (d>>2);
endfunction

function [23:0] dim( input [14:0] cin, input shade );
    dim = !shade? { dim75( {cin[14:10], cin[14:12]} ),
                    dim75( {cin[ 9: 5], cin[ 9: 7]} ),
                    dim75( {cin[ 4: 0], cin[ 4: 2]} ) } :
                 { cin[14:10], cin[14:12],
                   cin[ 9: 5], cin[ 9: 7],
                   cin[ 4: 0], cin[ 4: 2] };
endfunction

always @(posedge clk) begin
    if( rst ) begin
        bgr      <= 0;
        shl      <= 0;
    end else begin
        if( pxl_cen ) begin
            shl <= k251_en ? k251_shd[0] : shad;
            bgr <= dim( pal_dout[14:0], shl);
        end
    end
end

jtframe_prom #(.DW(3), .AW(8)) u_prio (
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prog_data     ),
    .rd_addr( prio_addr     ),
    .wr_addr( prog_addr     ),
    .we     ( prom_we       ),
    .q      ({shad,prio_sel})
);

// used in Punk Shot
jtcolmix_053251 u_k251(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    // CPU interface
    .cs         ( pcu_we    ),
    .addr       (cpu_addr[4:1]),
    .din        (cpu_dout[5:0]),
    // explicit priorities
    .sel        ( 1'b0      ),
    .pri0       ( 6'h3f     ),
    .pri1       ({1'b1, lyro_pxl[10:9], 3'd0 }),
    .pri2       ( 6'h3f     ),
    // color inputs
    .ci0        ( 9'd0      ),
    .ci1        ( { 1'd0, lyro_pxl[7:0] } ),
    .ci2        ( { 2'd0, lyrf_pxl[7:5], lyrf_pxl[3:0] } ),
    .ci4        ( { 1'b0, lyra_pxl[7:5], lyra_pxl[3:0] } ),
    .ci3        ( { 1'b0, lyrb_pxl[7:5], lyrb_pxl[3:0] } ),
    // shadow
    .shd_in     ({1'b0,~shadow}), // why do we need the inversion?
    .shd_out    ( k251_shd  ),
    // dump to SD card
    .ioctl_addr ( ioctl_ram ? ioctl_addr[3:0] : debug_bus[3:0] ),
    .ioctl_din  ( dump_mmr  ),

    .cout       ( k251_pxl  ),
    .brit       (           ),
    .col_n      (           )
);

// this does not follow the same arrangement of the original
// it's only important if you try to load a dump from MAME
jtframe_dual_nvram #(.AW(11),.SIMFILE("pal_lo.bin")) u_ramlo(
    // Port 0: CPU
    .clk0   ( clk           ),
    .data0  ( cpu_paldi[7:0]),
    .addr0  ( cpu_pala      ),
    .we0    ( cpu_palwe[0]  ),
    .q0     ( cpu_paldo[7:0]),
    // Port 1
    .clk1   ( clk           ),
    .data1  ( 8'd0          ),
    .addr1a ( pal_addr      ),
    .addr1b (ioctl_addr[11:1]),
    .sel_b  ( ioctl_ram     ),
    .we_b   ( 1'b0          ),
    .q1     ( pal_dout[ 7:0])
);

jtframe_dual_nvram #(.AW(11),.SIMFILE("pal_hi.bin")) u_ramhi(
    // Port 0: CPU
    .clk0   ( clk           ),
    .data0  (cpu_paldi[15:8]),
    .addr0  ( cpu_pala      ),
    .we0    ( cpu_palwe[1]  ),
    .q0     (cpu_paldo[15:8]),
    // Port 1
    .clk1   ( clk           ),
    .data1  ( 8'd0          ),
    .addr1a ( pal_addr      ),
    .addr1b (ioctl_addr[11:1]),
    .sel_b  ( ioctl_ram     ),
    .we_b   ( 1'b0          ),
    .q1     ( pal_dout[15:8] )
);

endmodule