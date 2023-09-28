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
    Date: 22-9-2023 */

module jtshouse_cenloop(
    input             rst,
    input             clk,
    input      [ 2:0] busy,

    output reg        prc_main, prc_sub, prc_snd, prc_mcu,
    output            cen_main, cen_sub, cen_snd, cen_mcu,

    output     [15:0] fave, fworst // average cpu_cen frequency in kHz
);

parameter FCLK = 49152,
          FCPU =  1536*4,
          NUM  = 1,
          DEN  = FCLK/FCPU,
          CW   = $clog2(FCLK/FCPU)+4;

reg     [3:0] cpu_cen;
reg     [1:0] clk4;
wire          over;
wire [  CW:0] cencnt_nx;
reg  [CW-1:0] cencnt=0;
reg           blank=0;
wire          bsyg = busy==0 || rst;

assign over      = !blank && cencnt > DEN[CW-1:0]-{NUM[CW-2:0],1'b0};
assign cencnt_nx = {1'b0,cencnt}+NUM[CW:0] -
                   (over && bsyg ? DEN[CW:0] : {CW+1{1'b0}});

assign cen_main = cpu_cen[0];
assign cen_sub  = cpu_cen[1];
assign cen_mcu  = cpu_cen[2];
assign cen_snd  = cpu_cen[3];

always @(posedge clk) begin
    blank <= 0;
    cencnt  <= cencnt_nx[CW] ? {CW{1'b1}} : cencnt_nx[CW-1:0];
    if( over && bsyg ) begin
        blank <= 1;
        clk4 <= clk4+2'd1;
        cpu_cen[0] <= clk4==0;
        cpu_cen[1] <= clk4==2;
        cpu_cen[2] <= clk4==1;
        cpu_cen[3] <= clk4==3;
    end else begin
        cpu_cen <= 0;
    end
    if( cen_sub ) { prc_snd, prc_mcu, prc_sub, prc_main } <= 4'b1000;
    if( cen_main) { prc_snd, prc_mcu, prc_sub, prc_main } <= 4'b0100;
    if( cen_mcu ) { prc_snd, prc_mcu, prc_sub, prc_main } <= 4'b0010;
    if( cen_snd ) { prc_snd, prc_mcu, prc_sub, prc_main } <= 4'b0001;
end

jtframe_freqinfo #(.MFREQ( FCLK )) u_info(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pulse      ( cpu_cen[0]),
    .fave       ( fave      ), // average cpu_cen frequency in kHz
    .fworst     ( fworst    )
);

endmodule