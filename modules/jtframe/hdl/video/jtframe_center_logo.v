/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 11-8-2022 */

// shows the JT logo at the screen centre
module jtframe_center_logo #(parameter
    COLORW  = 4,
    SHOWHEX = 1
) (
    input        rst,
    input        clk,
    input        pxl_cen,
    input        show_en,
    // input  [1:0] rotate, //[0] - rotate [1] - left or right

    // VGA signals coming from core
    input  [3*COLORW-1:0] rgb_in,
    input        hs,
    input        vs,
    input        lhbl,
    input        lvbl,

    // VGA signals going to video connector
    output reg [3*COLORW-1:0] rgb_out,

    input [63:0] chipid,

    output reg   hs_out,
    output reg   vs_out,
    output reg   lhbl_out,
    output reg   lvbl_out
);

reg  [ 8:0] hcnt=0,vcnt=0,
            htot=9'd256, vtot=9'd256,
            hover=0, vover=9'd100;
reg  [ 9:0] hdiff, vdiff;
reg         lhbl_l, lvbl_l;
wire        idpxl;
reg         inzone;
wire [COLORW*3-1:0] logorgb;

always @(posedge clk) if( pxl_cen ) begin
    { hs_out, vs_out     } <= { hs, vs };
    { lhbl_out, lvbl_out } <= { lhbl, lvbl };
    rgb_out <= !show_en ? rgb_in :                                    // regular video
              inzone ? logorgb : {3*COLORW{idpxl & SHOWHEX[0] }};     // logo or chip ID
end

always @* begin
    hdiff = {1'b0,hcnt} - {1'b0,hover};
    vdiff = {1'b0,vcnt} - {1'b0,vover};
    inzone = hdiff < 256 && !hdiff[9] && hdiff>8 &&
             vdiff < 128 && !vdiff[9];
end

// screen counter
always @(posedge clk) if( pxl_cen ) begin
    lhbl_l <= lhbl;
    lvbl_l <= lvbl;
    hcnt <= lhbl ? hcnt + 9'd1 : 9'd0;
    if( !lhbl && lhbl_l ) begin
        htot <= hcnt;
        vcnt <= lvbl ? vcnt+9'd1 : 9'd0;
    end
    if( !lvbl && lvbl_l ) begin
        vtot  <= vcnt;
        hover <= htot<9'd256 ? 9'd0 : (htot-9'd256)>>1;
        vover <= vtot<9'd128 ? 9'd0 : (vtot-9'd128)>>1;
    end
end

jtframe_logo #(.COLORW(COLORW)) u_logo(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdiff     ),
    .hdump      ( hdiff     ),
    .rgb        ( logorgb   )
);

jtframe_hexdisplay #(.H0(64),.V0(192)) u_hexdisplay(
    .clk     ( clk       ),
    .pxl_cen ( pxl_cen   ),
    .hcnt    ( hcnt      ),
    .vcnt    ( vcnt      ),
    .data    ( chipid    ),
    .pxl     ( idpxl     )
);

endmodule
