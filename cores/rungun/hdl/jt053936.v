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
    Date: 12-7-2025 */

// Based on Furrtek's module (see the original in the doc folder)

module jt053936(
    input           rst, clk, cen,

    input    [15:0] din,
    input    [ 4:1] addr,
    input           N16_8,

    input           hs, vs,
    input           cs, dtackn,
    input    [ 1:0] dsn,
    output          dma_n,

    input           nloe,
    output    [2:0] lh,
    output    [8:0] la,

    input           noe,
    output   [12:0] x,
    output          xh,
    output   [12:0] y,
    output          yh,
    output      reg nob,
    // IOCTL dump
    input      [4:0] ioctl_addr,
    output reg [7:0] ioctl_din,
);

reg  [15:0] mmr[0:15]; // used (real) registers are aliased as wires
wire [15:0] io_mux, xhstep, xvstep, yhstep, yvstep, xcnt0, ycnt0;
wire [ 9:0] xmin,  xmax, hcnt0;
wire [ 8:0] ymin,  ymax, vcnt0, ln0;
wire [ 1:0] xmul,  ymul;
wire [ 5:0] xclip, yclip;
wire        ln_en, ob_n;
wire [ 1:0] ob_cfg, ob_dly;
wire        aux;
integer k;

assign io_mux = mmr[ioctl_addr[4:1]];
assign xcnt0  = mmr[ 0];
assign ycnt0  = mmr[ 1];
assign xvstep = mmr[ 2];
assign yvstep = mmr[ 3];
assign xhstep = mmr[ 4];
assign yhstep = mmr[ 5];
assign xmul   = mmr[ 6][ 7: 6];
assign ymul   = mmr[ 6][15:14];
assign xclip  = mmr[ 6][ 5: 0];
assign yclip  = mmr[ 6][13: 8];
assign ln_en  = mmr[ 7][6];
assign ob_n   = mmr[ 7][5];
assign ob_cfg = mmr[ 7][4:3];
assign aux    = mmr[ 7][2];
assign ob_dly = mmr[ 7][1:0];
assign xmin   = mmr[ 8][9:0];
assign xmax   = mmr[ 9][9:0];
assign ymax   = mmr[10][8:0];
assign ymin   = mmr[11][8:0];
assign hcnt0  = mmr[12][9:0];
assign vcnt0  = mmr[13][8:0];
assign ln0    = mmr[14][8:0];

always @(posedge clk) begin
    if( rst ) begin
        for(k=0;k<16;k=k+1) mmr[k] <= 0;
    end else begin
        k = 0; // for Quartus linter
    end
end

always @(posedge clk) begin
    ioctl_din <= ioctl_addr[0] ? io_mux[15:8] : io_mux[7:0];
end

endmodule 