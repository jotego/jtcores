/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-3-2026 */

// Generic 32-bit RAM with clock enable
// parameters:
//      AW      => Address bit width, 10 for 1kB
//      SIMFILE_* => binary files to load during simulation
//      SIMHEXFILE_* => hexadecimal files to load during simulation
//      ENDIAN  => 0 (default) for little-endian hosts (x86). Use ENDIAN=0
//                 when loading binary files written by C fwrite on x86.
//      LATCH_IN  => Register address, data and we before the RAM. Adds one
//                   clock cycle of latency.
//      LATCH_OUT => Register output data after the RAM. Adds one clock cycle
//                   of latency.

module jtframe_ram32 #(parameter AW=10,
    SIMFILE="",
    SIMHEXFILE_0="",
    SIMHEXFILE_1="",
    SIMHEXFILE_2="",
    SIMHEXFILE_3="",
    ENDIAN=0,
    VERBOSE=0,          // set to 1 to display memory writes
    VERBOSE_OFFSET=0,   // value added to the address when displaying
    LATCH_IN=0,         // latch: inputs; adds one clock cycle
    LATCH_OUT=0         // latch: outputs; adds one clock cycle
)(
    input          clk,
    input   [31:0] data,
    input   [AW-1:2] addr,
    input   [ 3:0] we,
    output  [31:0] q
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
        always @(posedge clk) begin
            al  <= addr;
            dl  <= data;
            wel <= we;
            if( al!=addr || dl!=data || wel!=we ) begin
                if(we[0]) $display("%m %0X=%X", { {32-AW{1'b0}}, addr,2'b00}+VERBOSE_OFFSET,data[ 7: 0]);
                if(we[1]) $display("%m %0X=%X", { {32-AW{1'b0}}, addr,2'b01}+VERBOSE_OFFSET,data[15: 8]);
                if(we[2]) $display("%m %0X=%X", { {32-AW{1'b0}}, addr,2'b10}+VERBOSE_OFFSET,data[23:16]);
                if(we[3]) $display("%m %0X=%X", { {32-AW{1'b0}}, addr,2'b11}+VERBOSE_OFFSET,data[31:24]);
            end
        end
    end
endgenerate
`endif

jtframe_ram #(
    .DW        ( 8             ),
    .AW        ( AW-2          ),
    .SIMFILE   ( SIMFILE       ),
    .SIMHEXFILE( SIMHEXFILE_0  ),
    .SIMFILE_BYTE( BYTE0_SEL   ),
    .SIMFILE_DW( 32            ),
    .LATCH_IN  ( LATCH_IN      ),
    .LATCH_OUT ( LATCH_OUT     )  )
u_byte0(
    .clk        ( clk               ),
    .cen        ( 1'b1              ),
    .data       ( data[ 7: 0]       ),
    .addr       ( addr              ),
    .we         ( we[0]             ),
    .q          ( q[ 7: 0]          )
);

jtframe_ram #(
    .DW        ( 8             ),
    .AW        ( AW-2          ),
    .SIMFILE   ( SIMFILE       ),
    .SIMHEXFILE( SIMHEXFILE_1  ),
    .SIMFILE_BYTE( BYTE1_SEL   ),
    .SIMFILE_DW( 32            ),
    .LATCH_IN  ( LATCH_IN      ),
    .LATCH_OUT ( LATCH_OUT     )  )
u_byte1(
    .clk        ( clk               ),
    .cen        ( 1'b1              ),
    .data       ( data[15: 8]       ),
    .addr       ( addr              ),
    .we         ( we[1]             ),
    .q          ( q[15: 8]          )
);

jtframe_ram #(
    .DW        ( 8             ),
    .AW        ( AW-2          ),
    .SIMFILE   ( SIMFILE       ),
    .SIMHEXFILE( SIMHEXFILE_2  ),
    .SIMFILE_BYTE( BYTE2_SEL   ),
    .SIMFILE_DW( 32            ),
    .LATCH_IN  ( LATCH_IN      ),
    .LATCH_OUT ( LATCH_OUT     )  )
u_byte2(
    .clk        ( clk               ),
    .cen        ( 1'b1              ),
    .data       ( data[23:16]       ),
    .addr       ( addr              ),
    .we         ( we[2]             ),
    .q          ( q[23:16]          )
);

jtframe_ram #(
    .DW        ( 8             ),
    .AW        ( AW-2          ),
    .SIMFILE   ( SIMFILE       ),
    .SIMHEXFILE( SIMHEXFILE_3  ),
    .SIMFILE_BYTE( BYTE3_SEL   ),
    .SIMFILE_DW( 32            ),
    .LATCH_IN  ( LATCH_IN      ),
    .LATCH_OUT ( LATCH_OUT     )  )
u_byte3(
    .clk        ( clk               ),
    .cen        ( 1'b1              ),
    .data       ( data[31:24]       ),
    .addr       ( addr              ),
    .we         ( we[3]             ),
    .q          ( q[31:24]          )
);

endmodule
