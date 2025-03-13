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
    Date: 22-6-2022 */

module jtframe_mouse(
    input              rst,
    input              clk,
    input              lock,

    // real mouse inputs
    input signed [8:0] mouse_dx,
    input signed [8:0] mouse_dy,
    input        [7:0] mouse_f,     // flags (2:0 = buttons)
    input              mouse_st,    // strobe
    input              mouse_idx,   // up to two mouse devices
    // Mouse emulation
    input       [ 3:0] joyn1,       // active low
    input       [ 3:0] joyn2,

    // { 8-bit dx, 8-bit dy } encoded for the core
    // in 2's complement unless JTFRAME_MOUSE_NO2COMPL is defined
    output reg  [15:0] mouse_1p,
    output reg  [15:0] mouse_2p,
    output reg   [1:0] mouse_strobe,

    output reg  [ 2:0] but_1p,
    output reg  [ 2:0] but_2p
);

reg  [3:0] joy1_l, joy2_l;
wire [3:0] joy1,   joy2,
           joy1_on, joy1_off, joy2_on, joy2_off;

`ifndef JTFRAME_MOUSE_NOEMU
    `ifndef JTFRAME_LIGHTGUN
        localparam MOUSE_EMU=1;
    `else
        localparam MOUSE_EMU=0;
    `endif
`else
    localparam MOUSE_EMU=0;
`endif

`ifndef JTFRAME_MOUSE_EMUSENS
    localparam [8:0] MOUSE_EMU_SENS=9'h10;
`else
    localparam [8:0] MOUSE_EMU_SENS=`JTFRAME_MOUSE_EMUSENS;
`endif

function [7:0] cv( input [8:0] min ); // convert to the right format
    `ifdef JTFRAME_MOUSE_NO2COMPL
        // some games cannot handle 2's complement, so
        // a conversion to sign plus magnitude is provided here
        cv = { min[8], min[8] ? -min[7:1] : min[7:1] };
    `else
        cv = min[8:1];
    `endif
endfunction

assign joy1     = ~joyn1,
       joy2     = ~joyn2;
assign joy1_on  =  joy1 & ~joy1_l;
assign joy1_off = ~joy1 &  joy1_l;
assign joy2_on  =  joy2 & ~joy2_l;
assign joy2_off = ~joy2 &  joy2_l;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mouse_1p <= 0;
        mouse_2p <= 0;
        but_1p   <= 0;
        but_2p   <= 0;
        joy1_l   <= 0;
        joy2_l   <= 0;
        mouse_strobe <= 0;
    end else if(!lock) begin
        joy1_l <= joy1;
        joy2_l <= joy2;
        mouse_strobe <= 0;
        if( mouse_st ) begin
            if( !mouse_idx ) begin
                mouse_1p <= { cv(mouse_dy), cv(mouse_dx) };
                but_1p   <= mouse_f[2:0];
                mouse_strobe[0] <= 1;
            end else begin
                mouse_2p <= { cv(mouse_dy), cv(mouse_dx) };
                but_2p   <= mouse_f[2:0];
                mouse_strobe[1] <= 1;
            end
        end
        if( MOUSE_EMU ) begin
            if( joy1_on[0] ) mouse_1p[ 7:0] <= MOUSE_EMU_SENS[7:0];
            if( joy1_on[1] ) mouse_1p[ 7:0] <= cv(-MOUSE_EMU_SENS<<1);
            if( joy1_on[2] ) mouse_1p[15:8] <= MOUSE_EMU_SENS[7:0];
            if( joy1_on[3] ) mouse_1p[15:8] <= cv(-MOUSE_EMU_SENS);
            if( |joy1_on ) mouse_strobe[0] <= 1;

            if( joy2_on[0] ) mouse_2p[ 7:0] <= MOUSE_EMU_SENS[7:0];
            if( joy2_on[1] ) mouse_2p[ 7:0] <= cv(-MOUSE_EMU_SENS<<1);
            if( joy2_on[2] ) mouse_2p[15:8] <= MOUSE_EMU_SENS[7:0];
            if( joy2_on[3] ) mouse_2p[15:8] <= cv(-MOUSE_EMU_SENS);
            if( |joy2_on ) mouse_strobe[1] <= 1;

            // Stop the mouse when releasing the joystick
            if( joy1_off[1:0]!=0 ) mouse_1p[ 7:0] <= 0;
            if( joy1_off[3:2]!=0 ) mouse_1p[15:8] <= 0;
            if( joy2_off[1:0]!=0 ) mouse_2p[ 7:0] <= 0;
            if( joy2_off[3:2]!=0 ) mouse_2p[15:8] <= 0;
        end
    end
end

endmodule
