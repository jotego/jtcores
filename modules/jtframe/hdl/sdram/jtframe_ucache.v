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
    Date: 9-10-2023 */

module jtframe_ucache #(parameter
    AW   = 10,
    DW   =  8,
    SIZE =  4
)(
    input               rst,
    input               clk,

    input      [AW-1:0] addr,

    // From client
    input               clr,
    input               cs,
    output reg          ok,

    // From SDRAM
    output              sdram_cs,
    input               sdram_ok,

    input      [DW-1:0] din,
    output reg [DW-1:0] dout
);

localparam SW=$clog2(SIZE);
localparam SMAX=SIZE-1;

reg [  AW-1:0] amem[0:SIZE-1];
reg [  DW-1:0] dmem[0:SIZE-1];
reg [SIZE-1:0] valid;
reg [SIZE-1:0] match;
reg [  DW-1:0] dread;
reg            hit;
reg [SW-1:0]   wr_indx;

integer i;

assign sdram_cs = cs & ~hit & ~sdram_ok;

always @* begin
    dread = dmem[0];
    for(i=0; i<SIZE; i=i+1) begin
        if( addr == amem[i] && valid[i] ) begin
            match[i] = 1;
            dread = dmem[i];
        end else begin
            match[i] = 0;
        end
    end
    hit = |match;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        valid   <= 0;
        wr_indx <= 0;
    end else begin
        if( clr ) valid <= 0;
        if( cs ) begin
            if( hit )
                dout <= dread;
            else if(sdram_ok)
                dout <= din;
        end
        ok <= (hit | sdram_ok) & cs;
        if( cs & sdram_ok & ~hit) begin
            wr_indx <= wr_indx==SMAX[SW-1:0] ? {SW{1'b0}} : wr_indx+1'd1;
            amem[wr_indx] <= addr;
            dmem[wr_indx] <= din;
            valid[wr_indx]<= 1;
        end
    end
end

endmodule