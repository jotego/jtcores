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
    Date: 27-10-2017 */

// Generic dual port RAM with clock enable
// parameters:
// DW      => Data bit width, 8 for byte-based memories
// AW      => Address bit width, 10 for 1kB
//
// Transparency when writting
// ALPHAW  => The bits ALPHAW-1:0 will be used for comparison
// ALPHA   => If the input data matches ALPHA it will not be written
//
// Old data deletion
// After rd input goes low, the data at rd_addr will be overwritten
// with the BLANK value. The data is deleted BLANK_DLY clock cycles
// after rd went low

module jtframe_obj_buffer #(parameter
    DW          = 8,
    AW          = 9,
    ALPHAW      = 4,
    ALPHA       = 32'HF,
    BLANK       = ALPHA,
    BLANK_DLY   = 2,
    FLIP_OFFSET = 0,
    KEEP_OLD    = 0   // Do not overwrite old non-ALPHA data
                      // requires address, data and we signals to be held
                      // for at least two clock cycles
)(
    input   clk,
    input   LHBL,
    input   flip,
    // New data writes
    input   [DW-1:0] wr_data,
    input   [AW-1:0] wr_addr,
    input   we,
    // Old data reads (and erases)
    input   [AW-1:0] rd_addr,
    input   rd,                 // data will be erased after the rd event
    output reg [DW-1:0] rd_data
);

reg     line, last_LHBL;
wire    new_we;

reg [BLANK_DLY-1:0] dly;
wire                delete_we = dly[0];
wire [DW-1:0]       blank_data = BLANK[DW-1:0];
wire [DW-1:0]       dump_data, old;

assign new_we = wr_data[ALPHAW-1:0] != ALPHA[ALPHAW-1:0] && we
    && (old[ALPHAW-1:0]==ALPHA[ALPHAW-1:0] || KEEP_OLD==0);

`ifdef SIMULATION
initial begin
    line = 0;
end
`endif

always @(posedge clk) begin
    last_LHBL <= LHBL;
    if( !LHBL && last_LHBL )
        line <= ~line;
end

always @(posedge clk) begin
    if( rd ) begin
        dly       <= { 1'b1, {BLANK_DLY-1{1'b0}}  };
    end else begin
        dly       <= dly>>1;
    end
    if( delete_we ) rd_data <= dump_data;
end

wire [AW-1:0] wr_af = flip ? ~wr_addr + FLIP_OFFSET[AW-1:0] : wr_addr;

jtframe_dual_ram #(.AW(AW+1),.DW(DW)) u_line(
    .clk0   ( clk           ),
    .clk1   ( clk           ),
    // Port 0
    .data0  ( wr_data       ),
    .addr0  ( {line,wr_af}  ),
    .we0    ( new_we        ),
    .q0     ( old           ),
    // Port 1
    .data1  ( blank_data    ),
    .addr1  ({~line,rd_addr}),
    .we1    ( delete_we     ),
    .q1     ( dump_data     )
);

endmodule