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
    Date: 21-9-2023 */

// The implementation of the KEY chips follows MAME's namcos1_m.cpp
// These chips won't impact any timing accuracy
/* verilator tracing_on */
module jtshouse_key(
    input               rst,
    input               clk,

    input               cs,
    input               rnw,
    input         [7:0] addr,
    input         [7:0] din,
    output reg    [7:0] dout,

    input               prog_en,
    input               prog_wr,
    input         [2:0] prog_addr,
    input         [7:0] prog_data

);

// The random number generator follows MAME's implementation
// for the sake of comparing debug traces

reg  [7:0] cfg[0:7];
reg  [7:0] mmr[0:7];
reg  [5:0] sel;
wire [7:0] mmr_mux;
reg        up_rng, cs_l;

integer i, rng, nx_rng;

assign mmr_mux = mmr[cfg[4][2:0]];

always @(posedge clk) begin
    if( prog_en & prog_wr ) cfg[prog_addr] <= prog_data;
end

// Random number generator. Should research the real one: https://github.com/jotego/jtcores/issues/363
// For now, I use JT51's LFSR
// reg [16:0] bb;
// assign rng = bb[16-:8];

// always @(posedge clk, posedge rst) begin : base_counter
//     if( rst ) begin
//         bb <= 14220;
//     end else if(up_rng) begin
//         bb[16:1] <= bb[15:0];
//         bb[0]    <= ~(bb[16]^bb[13]);
//     end
// end

always @* begin
    for(i=0;i<6;i=i+1) sel[i]=addr[6:4]==cfg[i+2][2:0] && cs;
    up_rng = sel[1] && !cs_l;
    nx_rng = 1664525 * rng + 1013904223;
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        dout    <= 0;
        cs_l    <= 0;
        rng     <= 'h9d14abd7;
    end else begin
        cs_l    <= cs;
        if( cs && ~rnw ) begin
            if(!cs_l) $display("KEY: %X <- %X",addr[6:4], din);
            mmr[addr[6:4]] <= din;
        end
        if( up_rng ) rng <= nx_rng;
        // do not use "case" to avoid Quartus warning
             if( sel[0] ) dout <= cfg[1];     // key ID
        else if( sel[1] ) dout <= rng[16+:8]; // Random Number Generator
        else if( sel[3] ) dout <= { mmr_mux[3:0], mmr_mux[7:4] }; // swap nibbles
        else if( sel[4] ) dout <= { mmr_mux[3:0], addr[7:4] };    // lower nibble
        else if( sel[5] ) dout <= { mmr_mux[7:4], addr[7:4] };    // upper nibble
    end
end

`ifdef SIMULATION
reg [2:0] addrl;
reg       rnwl;

always @(posedge clk) begin
    addrl <= addr[6:4];
    rnwl  <= rnw;
    if( !cs && cs_l && rnwl ) begin
        $display("KEY: %X => %X",addrl, dout);
    end
end
`endif

endmodule