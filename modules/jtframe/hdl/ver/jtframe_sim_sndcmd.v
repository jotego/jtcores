/*  This file is part of JT_FRAME.
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
    Date: 28-6-2023 */

// Simulator helper to bypass the main CPU
// it will produce an irq pulse (for 64 clock cycles) and an 8-bit value
// to drive the sound CPU.
// A list of frame/command pairs is provided, where frames are 16-bit values
// and commands are 8 bits. The list is parsed from MSB to LSB, so it
// is written from left to right in the module instantiation.
// Example
// .frame_list( { 16'd4, 16'd67, 16'd73,16'd76,16'd79, }  ),
// .cmd_list  ( {  8'h1,  8'h5e,  8'h01, 8'h3a, 8'h5e, }  )
// The parameter CMDCNT must match the number of commands in the list

module jtframe_sim_sndcmd #(parameter CMDCNT=4)(
    input             rst,
    input             clk,
    input             lvbl,
    input [CMDCNT*8-1 :0] cmd_list,   // 8-bit cmd
    input [CMDCNT*16-1:0] frame_list, // 16-bit frame count for each cmd
    output reg        irq,
    output reg  [7:0] cmd
);

reg lvbl_l;
integer cmdcnt=0, framecnt, irqcnt,ptr;
reg  [15:0] cur_frame;
reg  [ 7:0] cur_cmd;

// data is played from MSB to LSB
always @(cmdcnt) begin
    ptr = CMDCNT-cmdcnt-1;
    cur_frame = frame_list[ (ptr<<4)-1 -:16];
    cur_cmd   = cmd_list  [ (ptr<<3)-1 -: 8];
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cmdcnt <= 0;
        framecnt <= 1;
        lvbl_l <= 0;
        irq <= 1;
        cmd <= 0;
        irqcnt <= 0;
    end else begin
        lvbl_l <= lvbl;
        if( irqcnt>0  ) irqcnt <= irqcnt-1;
        if( irqcnt==0 ) irq <= 0;
        if( lvbl_l && !lvbl ) begin
            framecnt <= framecnt+1;
            if( framecnt[15:0]==cur_frame ) begin
                cmdcnt <= cmdcnt+1;
                irq    <= 1;
                irqcnt <= 64;
                cmd    <= cur_cmd;
            end
        end
    end
end

endmodule