/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-1-2021 */

// Generic 16-bit dual port RAM with clock enable
// parameters:
//      AW      => Address bit width, 10 for 1kB
//      SIMFILE => binary file to load during simulation
//      SIMHEXFILE => hexadecimal file to load during simulation
//      ENDIAN  => 0 (default) for little-endian hosts (x86). Use ENDIAN=0
//                 when loading binary files written by C fwrite on x86.
//      LATCH_IN  => Register address, data and we before the RAM. Adds one
//                   clock cycle of latency.
//      LATCH_OUT => Register output data after the RAM. Adds one clock cycle
//                   of latency.

module jtframe_ram16 #(parameter AW=10,
    SIMFILE="",
    SIMHEXFILE_LO="", SIMHEXFILE_HI="",
    ENDIAN=0,
    VERBOSE=0,          // set to 1 to display memory writes
    VERBOSE_OFFSET=0,   // value added to the address when displaying
    LATCH_IN=0,         // latch: inputs; adds one clock cycle
    LATCH_OUT=0         // latch: outputs; adds one clock cycle
)(
    input          clk,
    input   [15:0] data,
    input   [AW:1] addr,
    input   [ 1:0] we,
    output  [15:0] q
);

localparam LO_BYTE = ENDIAN ? 1 : 0;
localparam HI_BYTE = ENDIAN ? 0 : 1;

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
    .SIMFILE   ( SIMFILE       ),
    .SIMHEXFILE( SIMHEXFILE_LO ),
    .SIMFILE_BYTE( LO_BYTE     ),
    .SIMFILE_DW( 16            ),
    .LATCH_IN  ( LATCH_IN      ),
    .LATCH_OUT ( LATCH_OUT     )  )
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
    .SIMFILE   ( SIMFILE       ),
    .SIMHEXFILE( SIMHEXFILE_HI ),
    .SIMFILE_BYTE( HI_BYTE     ),
    .SIMFILE_DW( 16            ),
    .LATCH_IN  ( LATCH_IN      ),
    .LATCH_OUT ( LATCH_OUT     )  )
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
