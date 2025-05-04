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
    Date: 15-3-2025 */

module jtthundr_cenloop(
    input             rst,
    input             clk,
    input      [ 1:0] busy,

    output reg        cen_main=0, cen_sub=0, cen_mcu=0, mcu_seln=0,

    output     [15:0] fave, fworst // average cpu_cen frequency in kHz
);

// 49.152 crystal on board
parameter FCLK = `JTFRAME_MCLK/1000,
          FCPU =  1536*4, // 49152/1536/4 = 8
          NUM  = 1,
          DEN  = FCLK/FCPU,
          CW   = $clog2(FCLK/FCPU)+4;

reg     [1:0] clk4=0;
reg     [6:0] mcu_sh=0;
wire          over;
wire [  CW:0] cencnt_nx;
reg  [CW-1:0] cencnt=0;
reg     [1:0] blank=0;
reg           blank_ok=0;
wire          bsyg = busy==0 || rst;

assign over      = blank_ok && !mcu_seln && cencnt > DEN[CW-1:0]-{NUM[CW-2:0],1'b0};
assign cencnt_nx = {1'b0,cencnt}+NUM[CW:0] -
                   (over && bsyg ? DEN[CW:0] : {CW+1{1'b0}});


always @(posedge clk) begin
    mcu_sh   <= {mcu_sh[5:0],cen_mcu};
    cen_main <= clk4==0 &&  mcu_sh[2];
    cen_sub  <= clk4==2 &&  mcu_sh[2];
    mcu_seln <= clk4==0 && |mcu_sh[3:1];
end

always @(posedge clk) begin
    if( !blank_ok ) begin
        blank <= blank + 1'd1 ;
        blank_ok <= blank==3;
    end
    cencnt  <= cencnt_nx[CW] ? {CW{1'b1}} : cencnt_nx[CW-1:0];
    if( over && bsyg ) begin
        blank_ok <= 0;
        clk4  <= clk4+2'd1;
        cen_mcu <= 1;
    end else begin
        cen_mcu    <= 0;
    end
end

jtframe_freqinfo #(.MFREQ( FCLK )) u_info(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pulse      ( cen_main  ),
    .fave       ( fave      ), // average CPU frequency in kHz
    .fworst     ( fworst    )
);

endmodule