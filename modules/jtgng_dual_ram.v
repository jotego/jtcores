/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 23-12-2018 */

module jtgng_dual_ram #(parameter dw=8, aw=10, simfile="")(
    input   clk,
    input   clk_en /* synthesis direct_enable = 1 */,
    input   [dw-1:0] data,
    input   [aw-1:0] rd_addr,
    input   [aw-1:0] wr_addr,
    input   we,
    output reg [dw-1:0] q
);

reg [dw-1:0] mem[0:(2**aw)-1];

`ifdef SIMULATION
integer f, readcnt;
initial
if( simfile != "" ) begin
    f=$fopen(simfile,"rb");
    readcnt=$fread( mem, f );
    $fclose(f);
    end
else begin
    for( readcnt=0; readcnt<(2**aw)-1; readcnt=readcnt+1 )
        mem[readcnt] = {dw{1'b0}};
    end
`endif

always @(posedge clk) begin
    q <= mem[rd_addr];
end

always @(posedge clk) if( clk_en ) begin
    if( we) mem[wr_addr] <= data;
end

endmodule // jtgng_ram