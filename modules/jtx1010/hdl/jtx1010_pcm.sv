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
    Date: 14-2-2026 */

module jtx1010_pcm(
    input              clk,
    input              cen,
    output reg  [ 3:0] ch,
    output reg  [ 4:0] st,
    output reg  [ 7:0] cfg,
    output reg         up,

    output reg  [15:0] keyon,
    input       [ 7:0] cfg_data,
    // ROM interface
    output reg  [19:0] rom_addr,
    input       [ 7:0] rom_data,
    output reg         rom_cs,      // rom_ok not needed

    output reg signed [15:0] pcm_l, pcm_r
);

localparam KEYON=0, WAV=1, DIV=7;

reg  [ 3:0] vol_l, vol_r;
reg  [ 7:0] delta, start, finish;
reg  [15:0] buf_l;
wire [19:0] cur;
reg  [19:0] nx_cur;

reg signed [15:0] mul;
reg signed [ 7:0] mul_in1, mul_in2;
reg        [ 3:0] mul_in;

always_comb begin
    mul_in1 = {4'd0,mul_in};
    mul_in2 = cfg[KEYON] ? rom_data : 8'd0;
    mul = mul_in1 * mul_in2;
end

wire we = st==31;

jtframe_ram #(.DW(20), .AW(4))u_ram(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( nx_cur        ),
    .addr   ( ch            ),
    .we     ( we            ),
    .q      ( cur           )
);

// 16 MHz/16 ch => 1MHz per channel
// 32 steps per channel => 31,250 Hz sampling rate
always_ff @(posedge clk) if(cen) begin
    {ch,st} <= {ch,st}+9'd1;
    case(st)
        0:  cfg          <= cfg_data;
        1: {vol_l,vol_r} <= cfg_data;
        2:  delta        <= cfg_data >> cfg[DIV];
        4:  start        <= cfg_data;
        5:  finish       <=-cfg_data;
        7:  up <= cfg[KEYON];
       11: rom_addr <= {start,12'd0}+{4'd0,cur[19:4]};
       12: if(rom_addr[19:12]>=finish) cfg[KEYON] <= 0;
       13: rom_cs <= cfg[KEYON] && !cfg[WAV];
       14: nx_cur <= cfg[KEYON] ? cur+{12'd0,delta} : 20'd0;
       // 14 -> 21 waiting for rom data for 7us
       // MAME driver questions vol_l bits
       21: begin mul_in <= vol_l;               end
       22: begin mul_in <= vol_r; buf_l <= mul; end
       24: keyon[ch] <= cfg[KEYON];
       25: begin
            rom_cs <= 0;
            pcm_l  <= buf_l;
            pcm_r  <= mul;
        end
        default: ;
    endcase
end

endmodule