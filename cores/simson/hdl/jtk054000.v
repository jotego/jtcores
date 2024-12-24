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
    Date: 20-10-2023 */

module jtk054000(
    input             rst,
    input             clk,

    input             cs,
    input       [4:0] addr,
    input             we,
    input       [7:0] din, 
    output      [7:0] dout

    // Debug
    // input      [ 7:0] debug_bus,
    // output reg [ 7:0] st_dout    
);

reg         hit, hitx, hity;

wire [23:0] o0x, o0y, o1x, o1y;
wire [ 7:0] o0h, o0w, o1h, o1w, dx, dy;

// adjusted
reg        [23:0] a0x, a0y;
reg        [ 8:0] addx, addy;
reg signed [23:0] subx, suby;

function [8:0] abs( input [8:0] a );
    abs = a[8] ? -a : a;
endfunction

assign dout = {7'd0, hit};

always @(posedge clk) begin
    a0x  <= o0x+{{16{dx[7]}},dx};
    a0y  <= o0y+{{16{dy[7]}},dy};
    subx <= a0x - o1x;
    addx <= o0w + o1w;
    suby <= a0y - o1y;
    addy <= o0h + o1h;
    hitx <= subx>511 || subx<-1024 || abs(subx[8:0])>addx[8:0];
    hity <= suby>511 || suby<-1024 || abs(suby[8:0])>addy[8:0];
    hit  <= hitx | hity;
end

jtk054000_mmr u_mmr(
    .rst    ( rst       ),
    .clk    ( clk       ),

    .cs     ( cs        ),
    .addr   ( addr      ),
    .rnw    ( ~we       ),
    .din    ( din       ), 
    .dout   (           ),
    
    .dx     ( dx        ),
    .dy     ( dy        ),
    .o0x    ( o0x       ),
    .o0w    ( o0w       ),
    .o0h    ( o0h       ),
    .o0y    ( o0y       ),
    .o1x    ( o1x       ),
    .o1w    ( o1w       ),
    .o1h    ( o1h       ),
    .o1y    ( o1y       ),

    // IOCTL dump
    .ioctl_addr ( 5'd0  ),
    .ioctl_din  (       ),
    // Debug
    .debug_bus  ( 8'd0  ),
    .st_dout    (       )
);

endmodule