/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2017 */

// ROM implemented in BRAM
// DW can only be 8 or 16 bits
// The programming interface is always 8 bits
// This module is similar to jtframe_dual_nvram16
// but it limits writting to a single port

module jtframe_bram_rom #(parameter
            DW=8,
            AW=10,
`ifdef JTFRAME_SDRAM_LARGE
            PW=25,
`else       PW=24, `endif
            OFFSET=0,
            // for DW=8:
            SIMFILE="",
            // for DW=16:
            SIMFILE_LO="",
            SIMFILE_HI=""
)(
    input               clk,

    // Read Port
    input      [AW-1:0] addr,
    output     [DW-1:0] data,

    // Write Port - connect to the output of jtframe_dwnld
    // same signals that go to the SDRAM programming input
    input    [PW-1:0] prog_addr, // max 32MB
    input       [1:0] prog_mask,
    input       [7:0] prog_data,
    input             prog_we
);
/* verilator lint_off WIDTH */
localparam ONE=1;
// NB: The range comparison will fail if trying to use the last byte in the 64MB space
localparam [PW-1:0] ADDR1=OFFSET[PW-1:0] + (ONE[PW-1:0]<<( AW-(DW==8?1:0) )); /* verilator lint_on WIDTH */ /* verilator lint_off UNSIGNED */
wire in_range = prog_addr>=OFFSET[PW-1:0] && prog_addr<ADDR1; /* verilator lint_on UNSIGNED */
wire [PW-1:0] prog_aeff = prog_addr-OFFSET[PW-1:0];

generate
    if( DW==8 ) begin
        wire we = prog_we && in_range;
        jtframe_rpwp_ram #(.DW(DW),.AW(AW),.SIMFILE(SIMFILE)) u_ram(
            .clk    ( clk                ),
            .rd_addr( addr               ),
            .dout   ( data               ),

            .wr_addr({prog_aeff[AW-2:0],prog_mask[0]}),
            .din    ( prog_data          ),
            .we     ( we                 )
        );
    end else if( DW==16 ) begin
        wire we_upper = !prog_mask[1] && prog_we && in_range;
        wire we_lower = !prog_mask[0] && prog_we && in_range;

        jtframe_rpwp_ram #(.DW(8),.AW(AW),.SIMFILE(SIMFILE_HI)) u_upper(
            .clk    ( clk          ),
            .rd_addr( addr         ),
            .dout   ( data[DW-1-:8]),

            .wr_addr(prog_aeff[AW-1:0]),
            .din    ( prog_data   ),
            .we     ( we_upper     )
        );

        jtframe_rpwp_ram #(.DW(8),.AW(AW),.SIMFILE(SIMFILE_LO)) u_lower(
            .clk    ( clk          ),
            .rd_addr( addr         ),
            .dout   ( data[0+:8]   ),

            .wr_addr(prog_aeff[AW-1:0]),
            .din    ( prog_data   ),
            .we     ( we_lower     )
        );
    end
endgenerate

endmodule
