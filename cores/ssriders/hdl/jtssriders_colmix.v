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

module jtssriders_colmix(
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
    input             lyrf_blnk_n,
    input             lyra_blnk_n,
    input             lyrb_blnk_n,
    input             lyro_blnk_n,
    input      [ 7:0] lyrf_pxl,
    input      [11:0] lyra_pxl,
    input      [11:0] lyrb_pxl,
    input      [11:0] lyro_pxl,

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

wire [ 1:0] cpu_palwe;
wire [15:0] pal_dout;
reg  [15:0] pxl_aux;
reg  [ 1:0] dim_cmn, dim_l;
reg  [23:0] bgr;
wire [10:0] pal_addr;
wire        brit, shad, pcu_we;

// 8/16 bit interface
assign cpu_palwe = {2{cpu_we&pal_cs}} & ~cpu_dsn;
assign pcu_we    = pcu_cs & ~cpu_dsn[0] & cpu_we;
assign ioctl_din = ioctl_addr[0] ? pal_dout[7:0] : pal_dout[15:8];
assign {blue,green,red} = (lvbl & lhbl ) ? bgr : 24'd0;

// function [7:0] dim75( input [7:0] d );
//     dim75 = d - (d>>2);
// endfunction

// function [23:0] dim_rgb( input [14:0] cin, input [1:0] shade );
//     reg [3:0] effsh;
//     effsh = { ~({3{shade[0]}}&dim), shade[1] }
//     dim = !shade? { dim75( {cin[14:10], cin[14:12]} ),
//                     dim75( {cin[ 9: 5], cin[ 9: 7]} ),
//                     dim75( {cin[ 4: 0], cin[ 4: 2]} ) } :
//                  { cin[14:10], cin[14:12],
//                    cin[ 9: 5], cin[ 9: 7],
//                    cin[ 4: 0], cin[ 4: 2] };
// endfunction

function [7:0] ext8( input [4:0] cin );
begin
    ext8 = {cin,cin[4:2]};
end
endfunction

// 052535 output impedance 685 Ohm measured with floating inputs
//        input pins impedance 460 Ohm
always @* begin
    case( {dimmod, dimpol} )
        0: dim_cmn = {  shad, brit        };
        1: dim_cmn = {  shad, brit | shad };
        2: dim_cmn = { ~shad, brit        };
        2: dim_cmn = { ~shad, brit |~shad };
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        bgr   <= 0;
        dim_l <= 0;
    end else begin
        if( pxl_cen ) begin
            dim_l <= dim_cmn;
            //dim_rgb( pal_dout[14:0], dim_l);
            bgr <= { ext8(pal_dout[14:10]),
                     ext8(pal_dout[ 9: 5]),
                     ext8(pal_dout[ 4: 0]) };
        end
    end
end

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
    .ci1        ( { 2'd0, lyro_pxl[6:0] } ),
    .ci2        ( { 2'd0, lyrf_pxl[7:5], lyrf_pxl[3:0] } ),
    .ci4        ( { 1'b0, lyra_pxl[7:5], lyra_pxl[3:0] } ),
    .ci3        ( { 1'b0, lyrb_pxl[7:5], lyrb_pxl[3:0] } ),
    // shadow
    .shd_in     ({1'b0,~shadow}), // why do we need the inversion?
    .shd_out    ( shad      ),
    // dump to SD card
    .ioctl_addr ( ioctl_ram ? ioctl_addr[3:0] : debug_bus[3:0] ),
    .ioctl_din  ( dump_mmr  ),

    .cout       ( pal_addr  ),
    .brit       ( brit      ),
    .col_n      (           )
);

// this does not follow the same arrangement of the original
// it's only important if you try to load a dump from MAME
jtframe_dual_nvram #(.AW(11),.SIMFILE("pal_lo.bin")) u_ramlo(
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

jtframe_dual_nvram #(.AW(11),.SIMFILE("pal_hi.bin")) u_ramhi(
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

endmodule