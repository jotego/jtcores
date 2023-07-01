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
    Date: 6-12-2019 */

///////////////////////////////////////////////////////////////////////////
// Fractional clock enable signal
// W refers to the number of divided down cen signals available
// each one is divided by 2

/* verilator tracing_off */

module jtframe_frac_cen #(parameter W=2,WC=10)(
    input         clk,
    input   [WC-1:0] n,         // numerator
    input   [WC-1:0] m,         // denominator
    output reg [W-1:0] cen,
    output reg [W-1:0] cenb // 180 shifted
);

wire [WC:0] step={1'b0,n},
            lim ={1'b0,m},
            absmax = lim+step;

reg  [WC:0] cencnt=0,
            next, next2;

always @(*) begin
    next  = cencnt+step;
    next2 = next-lim;
end

reg  half    = 0;
wire over    = next>=lim;
wire halfway = next >= (lim>>1)  && !half;

reg  [W-1:0] edgecnt = 0;
wire [W-1:0] next_edgecnt = edgecnt + 1'd1;
wire [W-1:0] toggle = next_edgecnt & ~edgecnt;

reg  [W-1:0] edgecnt_b = 0;
wire [W-1:0] next_edgecnt_b = edgecnt_b + 1'd1;
wire [W-1:0] toggle_b = next_edgecnt_b & ~edgecnt_b;

`ifdef SIMULATION
initial begin
    if( n>(m>>1) ) $display("WARNING: %m will generate cen signals high for 2 cycles in a row");
end
`endif

always @(posedge clk) begin
    cen  <= 0;
    cenb <= 0;

    if( cencnt >= absmax ) begin
        // something went wrong: restart
        cencnt <= 0;
    end else
    if( halfway ) begin
        half <= 1'b1;
        edgecnt_b <= next_edgecnt_b;
        cenb <= { toggle_b[W-2:0], 1'b1 };
    end
    if( over ) begin
        cencnt <= next2;
        half <= 1'b0;
        edgecnt <= next_edgecnt;
        cen <= { toggle[W-2:0], 1'b1 };
    end else begin
        cencnt <= next;
    end
end


endmodule