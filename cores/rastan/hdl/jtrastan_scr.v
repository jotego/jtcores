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
    Date: 2-4-2022 */

// This module implements the pc080sn logic
// The original clock was 26.686MHz/2 = 13.343MHz
// Using 48MHz as basis, the ratio is 1073/3860
// Measurements on Operation Wolf reported in MAME
//    VSync - 60.0551Hz
//    HSync - 15.6742kHz

module jtrastan_scr(
    input           rst,
    input           clk,
    output          pxl_cen,
    output          pxl2_cen,

    output          HS,
    output          VS,
    output          LHBL,
    output          LVBL,
    output reg      flip,
    output   [ 8:0] hdump,
    output   [ 8:0] vrender,

    input    [18:1] main_addr,
    input    [15:0] main_dout,
    input    [ 1:0] main_dsn,
    input           main_rnw,
    input           scr_cs,        // selection from address decoder
    output          dtackn,

    output   [15:2] ram0_addr,
    input    [31:0] ram0_data,
    input           ram0_ok,
    output          ram0_cs,

    output   [19:2] rom0_addr,
    input    [31:0] rom0_data,
    input           rom0_ok,
    output          rom0_cs,

    output   [15:2] ram1_addr,
    input    [31:0] ram1_data,
    input           ram1_ok,
    output          ram1_cs,

    output   [19:2] rom1_addr,
    input    [31:0] rom1_data,
    input           rom1_ok,
    output          rom1_cs,

    output   [10:0] scr1_pxl,
    output   [10:0] scr0_pxl,
    input    [ 7:0] debug_bus,
    output   [ 7:0] debug_view
);

wire [ 8:0] vdump;
reg  [15:0] scr0_hpos, scr1_hpos, scr0_vpos, scr1_vpos;

assign dtackn = 0;
assign debug_view = scr1_hpos[8:1];
/*
reg LVBLl;

always @(posedge clk) begin
    LVBLl <= LVBL;
    if( ~LVBL && LVBLl ) scr0_hpos <= scr0_hpos + 1'd1;
end
*/
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr0_hpos <= 0;
        scr1_hpos <= 0;
        scr0_vpos <= 0;
        scr1_vpos <= 0;
    end else if(scr_cs && !main_rnw) begin
        case( {main_addr[18:16],main_addr[1]} )
            {3'd2,1'b0}: scr0_vpos <= main_dout;
            {3'd2,1'b1}: scr1_vpos <= main_dout;
            {3'd4,1'b0}: scr0_hpos <= main_dout;
            {3'd4,1'b1}: scr1_hpos <= main_dout;
            {3'd5,1'b0}: flip      <= main_dout[0];
            default:;
        endcase
    end
end

jtframe_frac_cen #(
    .W (  2 )
) u_cen (
    .clk    ( clk       ),
    .n      ( 10'd1     ),         // numerator
    .m      ( 10'd4     ),         // denominator
    .cen    ({pxl_cen,pxl2_cen}),
    .cenb   (           )
);

// According to accurate PCB measurements
jtframe_vtimer #(
    .VB_START   ( 9'd239          ),
    .VB_END     ( 9'd239+9'd23    ),
    .VS_START   ( 9'd239+9'd7     ),
    .HB_END     ( 9'hF            ),
    .HB_START   ( 9'h14F          ),
    .HCNT_END   ( 9'd319+9'd104   ),
    .HS_START   ( 9'd320+9'd44    )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

jtrastan_tilemap u_scr0( // background
    .rst        ( rst       ),
    .clk        ( clk       ),

    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),

    .hpos       ( scr0_hpos[8:0] ),
    .vpos       ( scr0_vpos[8:0] ),

    .ram_addr   ( ram0_addr ),
    .ram_data   ( ram0_data ),
    .ram_ok     ( ram0_ok   ),
    .ram_cs     ( ram0_cs   ),

    .rom_addr   ( rom0_addr ),
    .rom_data   ( rom0_data ),
    .rom_ok     ( rom0_ok   ),
    .rom_cs     ( rom0_cs   ),

    .pxl        ( scr0_pxl  ),
    .debug_bus  ( debug_bus )
);

jtrastan_tilemap #(1) u_scr1( // foreground
    .rst        ( rst       ),
    .clk        ( clk       ),

    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),

    .hpos       ( scr1_hpos[8:0] ),
    .vpos       ( scr1_vpos[8:0] ),

    .ram_addr   ( ram1_addr ),
    .ram_data   ( ram1_data ),
    .ram_ok     ( ram1_ok   ),
    .ram_cs     ( ram1_cs   ),

    .rom_addr   ( rom1_addr ),
    .rom_data   ( rom1_data ),
    .rom_ok     ( rom1_ok   ),
    .rom_cs     ( rom1_cs   ),

    .pxl        ( scr1_pxl  ),
    .debug_bus  ( debug_bus )
);

endmodule