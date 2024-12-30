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
    Date: 7-7-2024 */

module jtriders_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

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

    // Final pixels
    input      [ 7:0] lyrf_pxl,
    input      [11:0] lyra_pxl,
    input      [11:0] lyrb_pxl,
    input      [11:0] lyro_pxl,
    input      [ 1:0] lyro_pri,

    input             shadow,
    input      [ 2:0] dim,
    input             dimmod,
    input             dimpol,

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

wire [15:0] pal_dout;
wire [ 1:0] cpu_palwe;
reg  [ 1:0] dim_cmn;
reg  [ 4:0] pal_dmux;
reg  [ 3:0] bsel; // bright selection
reg  [23:0] bgr;
reg         st;
wire [ 7:0] r8, bg8;
reg  [ 7:0] b8, g8;
wire [10:0] pal_addr;
wire        brit, shad, pcu_we, nc;
// 053251 inputs
wire [ 5:0] pri1;
wire [ 8:0] ci0, ci1, ci2;
wire [ 7:0] ci3, ci4;
wire [ 1:0] shd_out, shd_in;

// 8/16 bit interface
assign cpu_palwe = {2{cpu_we&pal_cs}} & ~cpu_dsn;
assign pcu_we    = pcu_cs & ~cpu_dsn[0] & cpu_we;
assign ioctl_din = ioctl_addr[0] ? pal_dout[7:0] : pal_dout[15:8];
assign {blue,green,red} = (lvbl & lhbl ) ? bgr : 24'd0;

// 053251 wiring
assign pri1      = {1'b1, lyro_pxl[10:9], 3'd0};
assign ci0       =  9'd0;
assign ci1       =  lyro_pxl[8:0];
assign ci2       = {2'd0, lyrf_pxl[7:5], lyrf_pxl[3:0] };
assign ci3       = {1'b0, lyrb_pxl[7:5], lyrb_pxl[3:0] };
assign ci4       = {1'b0, lyra_pxl[7:5], lyra_pxl[3:0] };
assign shad      =  shd_out[0];
assign shd_in    = {1'b0,shadow};

always @* begin
    // LUT generated with
    // jtutil bright --dark --brw 4 --rout 50 --bpp 5
    case( {dimpol, dimmod} )
        3,2: dim_cmn[1] = ~shad;
        1,0: dim_cmn[1] =  shad;
    endcase
    case( {dimpol, dimmod} )
        3,1: dim_cmn[0] = brit | dim_cmn[1];
        2,0: dim_cmn[0] = brit;
    endcase
end

function [7:0] conv58(input [4:0] cin );
begin
    conv58 = {cin, cin[4-:3]};
end
endfunction

`ifdef NODIMMING
wire nodimming = 1;
`else
wire nodimming = 0;
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bgr   <= 0;
        bsel  <= 0;
        st    <= 0;
    end else begin
        st        <= ~st;
        bsel[3]   <= dim_cmn[1];
        bsel[2:0] <= ~({3{dim_cmn[0]}}&dim);
        pal_dmux  <= st ? pal_dout[14:10] : pal_dout[9:5]; // blue (msb), green (middle)
        if( st ) b8 <= bg8; else g8 <= bg8;
        if( pxl_cen ) begin
            bgr <= nodimming ?
                {conv58(pal_dout[10+:5]),conv58(pal_dout[5+:5]),conv58(pal_dout[0+:5])} :
                { b8, g8, r8 };
        end
        // if( debug_bus[7] ) bsel <= debug_bus[3:0];
    end
end

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
    .pri1       ( pri1      ),
    .pri2       ( 6'h3f     ),
    // color inputs
    .ci0        ( ci0       ),
    .ci1        ( ci1       ),
    .ci2        ( ci2       ),
    .ci3        ( ci3       ),
    .ci4        ( ci4       ),
    // shadow
    .shd_in     ( shd_in    ),
    .shd_out    ( shd_out   ),
    // dump to SD card
    .ioctl_addr ( ioctl_ram ? ioctl_addr[3:0] : debug_bus[3:0] ),
    .ioctl_din  ( dump_mmr  ),

    .cout       ( pal_addr  ),
    .brit       ( brit      ),
    .col_n      (           )
);

// this does not follow the same arrangement of the original
// it's only important if you try to load a dump from MAME
jtframe_dual_nvram #(.AW(11),.SIMFILE("pal_hi.bin")) u_ramlo(
    // Port 0: CPU
    .clk0   ( clk           ),
    .data0  ( cpu_dout[7:0] ),
    .addr0  ( cpu_addr[11:1]),
    .we0    ( cpu_palwe[0]  ),
    .q0     ( cpu_din[7:0]),
    // Port 1
    .clk1   ( clk           ),
    .data1  ( 8'd0          ),
    .addr1a ( pal_addr      ),
    .addr1b (ioctl_addr[11:1]),
    .sel_b  ( ioctl_ram     ),
    .we_b   ( 1'b0          ),
    .q1     ( pal_dout[ 7:0])
);

jtframe_dual_nvram #(.AW(11),.SIMFILE("pal_lo.bin")) u_ramhi(
    // Port 0: CPU
    .clk0   ( clk           ),
    .data0  ( cpu_dout[15:8]),
    .addr0  ( cpu_addr[11:1]),
    .we0    ( cpu_palwe[1]  ),
    .q0     ( cpu_din[15:8] ),
    // Port 1
    .clk1   ( clk           ),
    .data1  ( 8'd0          ),
    .addr1a ( pal_addr      ),
    .addr1b (ioctl_addr[11:1]),
    .sel_b  ( ioctl_ram     ),
    .we_b   ( 1'b0          ),
    .q1     ( pal_dout[15:8] )
);

jtframe_dual_ram #(.AW(9),.SYNFILE("collut.hex")) u_lut(
    // Port 0
    .clk0   ( clk           ),
    .data0  ( 8'd0          ),
    .addr0  ( {bsel,pal_dout[4:0]} ),
    .we0    ( 1'b0          ),
    .q0     ( r8            ),
    // Port 1
    .clk1   ( clk           ),
    .data1  ( 8'd0          ),
    .addr1  ( {bsel,pal_dmux} ),
    .we1    ( 1'b0          ),
    .q1     ( bg8           )
);

endmodule