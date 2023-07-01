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
      Date: 19-9-2020

*/
/* verilator tracing_off */
module jtframe_kabuki(
    input             clk,  // This clock must match the SDRAM's
    input             m1_n,
    input             rd_n,
    input             mreq_n,
    input      [15:0] addr,
    input      [ 7:0] din,
    input             en,
    // Decode keys
    input      [ 7:0] prog_data,
    input             prog_we,
    output reg [ 7:0] dout
);

reg  [15:0] addr_hit;
reg  [87:0] kabuki_keys;
reg         en_cpy, last_we;

wire [31:0] swap_key1, swap_key2;
wire [15:0] addr_key;
wire [ 7:0] xor_key;

assign { swap_key1, swap_key2, addr_key, xor_key } = kabuki_keys;

always @(posedge clk) begin
    last_we <= prog_we;
    if( !prog_we && last_we ) begin
        kabuki_keys <= { kabuki_keys[79:0], prog_data };
    end
    en_cpy <= en;
end

function [7:0] bitswap1(
        input [ 7:0] din,
        input [15:0] key,
        input [ 7:0] hit );
    bitswap1 = {
        hit[ key[14:12] ] ? { din[6], din[7] } : din[7:6],
        hit[ key[10: 8] ] ? { din[4], din[5] } : din[5:4],
        hit[ key[ 6: 4] ] ? { din[2], din[3] } : din[3:2],
        hit[ key[ 2: 0] ] ? { din[0], din[1] } : din[1:0]
    };
endfunction

function [7:0] bitswap2(
        input [ 7:0] din,
        input [15:0] key,
        input [ 7:0] hit );
    bitswap2 = {
        hit[ key[ 2: 0] ] ? { din[6], din[7] } : din[7:6],
        hit[ key[ 6: 4] ] ? { din[4], din[5] } : din[5:4],
        hit[ key[10: 8] ] ? { din[2], din[3] } : din[3:2],
        hit[ key[14:12] ] ? { din[0], din[1] } : din[1:0]
    };
endfunction

always @(posedge clk) begin
    addr_hit <= m1_n ?
        ( (addr ^ 16'h1fc0) + addr_key + 16'd1 ) : // data
        (addr + addr_key); // OP
end

always @(*) begin
    dout = din;
    if( !mreq_n && !rd_n && en_cpy ) begin
        dout  = bitswap1( dout, swap_key1[15:0], addr_hit[7:0] );
        dout  = { dout[6:0], dout[7] };

        dout  = bitswap2( dout, swap_key1[31:16], addr_hit[7:0] );
        dout  = dout ^ xor_key;
        dout  = { dout[6:0], dout[7] };

        dout  = bitswap2( dout, swap_key2[15:0], addr_hit[15:8] );
        dout  = { dout[6:0], dout[7] };

        dout  = bitswap1( dout, swap_key2[31:16], addr_hit[15:8] );
    end
end

// Load the kabuki keys only if it is a simulation with no rom loading
// of CPS 1.5
`ifdef CPS15
`ifdef SIMULATION
`ifndef LOADROM
reg [87:0] kabuki_aux[0:0];
initial begin
    $readmemh("kabuki.hex", kabuki_aux);
    kabuki_keys = kabuki_aux[0];
end
`endif
`endif
`endif

endmodule
/* verilator tracing_on */
