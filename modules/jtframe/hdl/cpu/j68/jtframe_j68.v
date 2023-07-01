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
    Date: 30-5-2021 */

module jtframe_j68(
    input   clk,
    input   rst,

    input   HALTn,

    output  [23:1] eab,
    output     reg ASn,
    output         LDSn,
    output         UDSn,
    output         eRWn,
    input          DTACKn,

    // Data bus
    input   [15:0] iEdb,
    output  [15:0] oEdb,

    // Bus sharing
    input      BRn,
    input      BGACKn,
    output reg BGn=1,

    // interrupts
    input   IPL0n,
    input   IPL1n,
    input   IPL2n,

    // state
    output  FC0,
    output  FC1,
    output  FC2
);

reg cen=0;

wire [1:0]  byte_ena;     // Byte enable
wire [31:0] address;      // Address bus
wire [2:0]  fc,           // Function code
            ipl_n;        // Interrupt level
wire        data_ack, rd_ena, wr_ena;

assign {FC2,FC1,FC0} = fc;
assign ipl_n         =  { IPL2n, IPL1n, IPL0n };
assign {UDSn,LDSn}   = ~byte_ena;
assign data_ack      = ~DTACKn;
assign eRWn          = ~wr_ena;
assign eab           = address[23:1];

always @(posedge clk) begin
    // During memory access (ASn low), we need to introduce some
    // idle cycles (cen at 50%) for J68 to work well with the external glue logic
    cen <= rst | ((~cen | ASn) & HALTn & BGn);
    if( ASn && !BRn ) BGn <= 0;
    if( BRn ) BGn <= 1;
end

always @(posedge clk) begin
    if( rst )
        ASn <= 1;
    else begin
        if( rd_ena | wr_ena )
            ASn <= 0;
        else if( data_ack )
            ASn <= 1;
    end
end


cpu_j68 #(.USE_CLK_ENA(1)) u_j68
(
    // Clock and reset
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_ena    ( cen       ), // CPU clock enable
    // Bus interface
    .rd_ena     ( rd_ena    ), // Read strobe
    .wr_ena     ( wr_ena    ), // Write strobe
    .data_ack   ( data_ack  ), // Data acknowledge
    .byte_ena   ( byte_ena  ), // Byte enable
    .address    ( address   ), // Address bus
    .rd_data    ( iEdb      ), // Data bus in
    .wr_data    ( oEdb      ), // Data bus out
    // 68000 control
    .fc         ( fc        ),           // Function code
    .ipl_n      ( ipl_n     ),           // Interrupt level

    // 68000 debug - unused
    .dbg_reg_addr   (), // Register address
    .dbg_reg_wren   (), // Register write enable
    .dbg_reg_data   (), // Register write data
    .dbg_sr_reg     (), // Status register
    .dbg_pc_reg     (), // Program counter
    .dbg_usp_reg    (), // User stack pointer
    .dbg_ssp_reg    (), // Supervisor stack pointer
    .dbg_vbr_reg    (), // Vector base register
    .dbg_cycles     (), // Cycles counter
    .dbg_ifetch     (), // Instruction fetch
    .dbg_irq_lvl    ()  // Interrupt level
);

endmodule