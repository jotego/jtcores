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
    Date: 29-3-2026 */

// Generic 32-bit dual port RAM with clock enable
// parameters:
//      AW      => Address bit width, 10 for 4kB
//      SIMFILE_* => binary files to load during simulation
//      SIMHEXFILE_* => hexadecimal files to load during simulation

module jtframe_dual_ram32 #(parameter AW=10,
    SIMFILE="",
    SIMHEXFILE_0="",
    SIMHEXFILE_1="",
    SIMHEXFILE_2="",
    SIMHEXFILE_3="",
    ENDIAN=0,
    VERBOSE=0,          // set to 1 to display memory writes
    VERBOSE_OFFSET=0    // value added to the address when displaying
)(
    // Port 0
    input          clk0,
    input   [31:0] data0,
    input   [AW-1:2] addr0,
    input   [ 3:0] we0,
    output  [31:0] q0,
    // Port 1
    input          clk1,
    input   [31:0] data1,
    input   [AW-1:2] addr1,
    input   [ 3:0] we1,
    output  [31:0] q1
);

localparam BYTE0_SEL = ENDIAN ? 3 : 0;
localparam BYTE1_SEL = ENDIAN ? 2 : 1;
localparam BYTE2_SEL = ENDIAN ? 1 : 2;
localparam BYTE3_SEL = ENDIAN ? 0 : 3;

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
        reg [AW-1:2] al;
        reg [31:0] dl;
        reg [ 3:0] wel;
        always @(posedge clk0) begin
            al  <= addr0;
            dl  <= data0;
            wel <= we0;
            if( al!=addr0 || dl!=data0 || wel!=we0 ) begin
                if(we0[0]) $display("%m %0X=%X", { {32-AW{1'b0}}, addr0,2'b00}+VERBOSE_OFFSET,data0[ 7: 0]);
                if(we0[1]) $display("%m %0X=%X", { {32-AW{1'b0}}, addr0,2'b01}+VERBOSE_OFFSET,data0[15: 8]);
                if(we0[2]) $display("%m %0X=%X", { {32-AW{1'b0}}, addr0,2'b10}+VERBOSE_OFFSET,data0[23:16]);
                if(we0[3]) $display("%m %0X=%X", { {32-AW{1'b0}}, addr0,2'b11}+VERBOSE_OFFSET,data0[31:24]);
            end
        end
    end
endgenerate
`endif

jtframe_dual_ram #(
    .DW        ( 8             ),
    .AW        ( AW-2          ),
    .SIMFILE   ( SIMFILE       ),
    .SIMHEXFILE( SIMHEXFILE_0  ),
    .SIMFILE_BYTE( BYTE0_SEL   ),
    .FULL_DW   ( 32            )  )
u_byte0(
    .clk0       ( clk0              ),
    .clk1       ( clk1              ),
    .data0      ( data0[ 7: 0]      ),
    .addr0      ( addr0             ),
    .we0        ( we0[0]            ),
    .q0         ( q0[ 7: 0]         ),
    .data1      ( data1[ 7: 0]      ),
    .addr1      ( addr1             ),
    .we1        ( we1[0]            ),
    .q1         ( q1[ 7: 0]         )
);

jtframe_dual_ram #(
    .DW        ( 8             ),
    .AW        ( AW-2          ),
    .SIMFILE   ( SIMFILE       ),
    .SIMHEXFILE( SIMHEXFILE_1  ),
    .SIMFILE_BYTE( BYTE1_SEL   ),
    .FULL_DW   ( 32            )  )
u_byte1(
    .clk0       ( clk0              ),
    .clk1       ( clk1              ),
    .data0      ( data0[15: 8]      ),
    .addr0      ( addr0             ),
    .we0        ( we0[1]            ),
    .q0         ( q0[15: 8]         ),
    .data1      ( data1[15: 8]      ),
    .addr1      ( addr1             ),
    .we1        ( we1[1]            ),
    .q1         ( q1[15: 8]         )
);

jtframe_dual_ram #(
    .DW        ( 8             ),
    .AW        ( AW-2          ),
    .SIMFILE   ( SIMFILE       ),
    .SIMHEXFILE( SIMHEXFILE_2  ),
    .SIMFILE_BYTE( BYTE2_SEL   ),
    .FULL_DW   ( 32            )  )
u_byte2(
    .clk0       ( clk0              ),
    .clk1       ( clk1              ),
    .data0      ( data0[23:16]      ),
    .addr0      ( addr0             ),
    .we0        ( we0[2]            ),
    .q0         ( q0[23:16]         ),
    .data1      ( data1[23:16]      ),
    .addr1      ( addr1             ),
    .we1        ( we1[2]            ),
    .q1         ( q1[23:16]         )
);

jtframe_dual_ram #(
    .DW        ( 8             ),
    .AW        ( AW-2          ),
    .SIMFILE   ( SIMFILE       ),
    .SIMHEXFILE( SIMHEXFILE_3  ),
    .SIMFILE_BYTE( BYTE3_SEL   ),
    .FULL_DW   ( 32            )  )
u_byte3(
    .clk0       ( clk0              ),
    .clk1       ( clk1              ),
    .data0      ( data0[31:24]      ),
    .addr0      ( addr0             ),
    .we0        ( we0[3]            ),
    .q0         ( q0[31:24]         ),
    .data1      ( data1[31:24]      ),
    .addr1      ( addr1             ),
    .we1        ( we1[3]            ),
    .q1         ( q1[31:24]         )
);

endmodule
