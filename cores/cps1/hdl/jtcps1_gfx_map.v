/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR a PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2020 */
    

// A[22:20]   Usage
// 000        OBJ
// 001        SCROLL 1
// 010        SCROLL 2
// 011        SCROLL 3
// 100        Star field
/*
function match;
    input [8:0] code_start;
    input [8:0] code_end;
    input [5:0] gfx_type;
    input [5:0] bank_type;

    match = code_in[8:0] >= code_start && 
            code_in[8:0] <= code_end &&
            (gfx_type & bank_type)!=6'd0;
endfunction

wire [5:0] 
*/
module jtcps1_gfx_map#(
    localparam CFG_LEN=9+9+6+4
)(
    input      [ 2: 0] gfx_type,
    input      [19:10] code_in,    
    output reg [19:10] code_out,
    // Configuration
    input      [ 7:0]  bank0_start,
    input      [ 7:0]  bank1_start,
    input      [ 7:0]  bank2_start,
    input      [ 7:0]  bank3_start,

    input  [CFG_LEN*8-1:0]  config // 3x8=24 bytes
);

wire [ 7:0] match;
wire [79:0] masked;

generate
    genvar m, n0;
    for( m=0; m<8; m=m+1 ) begin : match_array
        n0 = CFG_LEN*m;
        match u_match(
            .code0   ( config[8+n0:n0]     ),
            .code1   ( config[17+n0:8+n0]  ),
            .gfx_type( config[22+n0:18+n0] ),
            .code_in ( code_in             ),
            .code_out( masked[32+n0:23+n0] ),
            .match   ( match[k]            )
        );
    end
endgenerate

reg [7:0]

endmodule