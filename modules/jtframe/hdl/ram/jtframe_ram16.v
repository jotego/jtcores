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
    Date: 25-1-2021 */

// Generic 16-bit dual port RAM with clock enable
// parameters:
//      AW      => Address bit width, 10 for 1kB
//      SIMFILE => binary file to load during simulation
//      SIMHEXFILE => hexadecimal file to load during simulation

module jtframe_ram16 #(parameter AW=10,
    SIMFILE_LO="", SIMHEXFILE_LO="",
    SIMFILE_HI="", SIMHEXFILE_HI="",
    VERBOSE=0,          // set to 1 to display memory writes
    VERBOSE_OFFSET=0    // value added to the address when displaying
)(
    input          clk,
    input   [15:0] data,
    input   [AW:1] addr,
    input   [ 1:0] we,
    output  [15:0] q
);

`ifdef SIMULATION
generate
    if( VERBOSE==1 ) begin
        `ifdef VERILATOR
            initial begin
                $display("WARNING: Producing large outputs with the $display task in verilator");
                $display("is known to produce corrupted text at least up to verilator version 5.006");
                $display("https://github.com/verilator/verilator/issues/3799");
            end
        `endif
        reg [AW:1] al;
        reg [15:0] dl;
        reg [ 1:0] wel;
        always @(posedge clk) begin
            al  <= addr;
            dl  <= data;
            wel <= we;
            if( al!=addr || dl!=data || wel!=we ) begin
                if(we[0]) $display("%m %0X=%X", { {32-AW{1'b0}}, addr,1'b0}+VERBOSE_OFFSET,data[7:0]);
                if(we[1]) $display("%m %0X=%X", { {32-AW{1'b0}}, addr,1'b1}+VERBOSE_OFFSET,data[15:8]);
            end
        end
    end
endgenerate
`endif

jtframe_ram #(
    .DW        ( 8             ),
    .AW        ( AW            ),
    .SIMFILE   ( SIMFILE_LO    ),
    .SIMHEXFILE( SIMHEXFILE_LO )  )
u_lo(
    .clk        ( clk               ),
    .cen        ( 1'b1              ),
    // Port 0
    .data       ( data [7:0]        ),
    .addr       ( addr              ),
    .we         ( we [0]            ),
    .q          ( q [7:0]           )
);

jtframe_ram #(
    .DW        ( 8             ),
    .AW        ( AW            ),
    .SIMFILE   ( SIMFILE_HI    ),
    .SIMHEXFILE( SIMHEXFILE_HI )  )
u_hi(
    .clk        ( clk               ),
    .cen        ( 1'b1              ),
    // Port 0
    .data       ( data [15:8]       ),
    .addr       ( addr              ),
    .we         ( we [1]            ),
    .q          ( q [15:8]          )
);

endmodule