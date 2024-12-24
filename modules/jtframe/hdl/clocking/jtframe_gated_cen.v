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
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-12-2019 */

///////////////////////////////////////////////////////////////////////////
// Fractional clock enable signal
// W refers to the number of divided down cen signals available
// each one is divided by 2
// generation is halted while busy input is high, and lost
// cycles are recovered once busy goes low

/* verilator tracing_on */

module jtframe_gated_cen #( parameter
    W     =  2,
    MFREQ = 48000,
    NUM   = 1,
    DEN   = 8,
    CW    = $clog2(DEN+NUM*2)+4
)(
    input              rst,
    input              clk,
    input              busy,
    output reg [W-1:0] cen,

    output     [ 15:0] fave, fworst // average cpu_cen frequency in kHz
);

localparam NUM2 = NUM<<1;

// reg  [ W-1:0] pre;
wire          over;
wire [  CW:0] cencnt_nx, sum;
reg  [CW-1:0] cencnt=0;
reg  [ W-1:0] toggle=0, toggle_l=0;
reg           blank=0;
wire          cnt_en = !busy || rst;
integer       i;

assign over      = !blank && cencnt > DEN[CW-1:0]-NUM2[CW-1:0];
assign cencnt_nx = {1'b0,cencnt}+NUM2[CW:0] - ((over && cnt_en) ? DEN[CW:0] : {CW+1{1'b0}});

always @(posedge clk) begin
    blank <= 0;
    cencnt  <= cencnt_nx[CW] ? {CW{1'b1}} : cencnt_nx[CW-1:0];
    if( over && cnt_en ) begin
        blank <= 1;
        toggle <= toggle + 1'd1;
        toggle_l <= toggle;
        cen <= ~toggle & toggle_l;
    end else begin
        cen <= 0;
    end
end

jtframe_freqinfo #(.MFREQ( MFREQ )) u_info(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pulse      ( cen[0]    ),
    .fave       ( fave      ), // average cpu_cen frequency in kHz
    .fworst     ( fworst    )
);

endmodule