/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 11-1-2021 */

// 1 slots for SDRAM read-only access
// Each slot can be used for 8, 16 or 32 bit access
// Small 4 byte cache used for each slot
/* verilator coverage_off */
module jtframe_rom_1slot #(parameter
    SDRAMW       = 22,
    SLOT0_DW     = 8,
    SLOT0_AW     = 8,
    SLOT0_LATCH  = 0,
    SLOT0_DOUBLE = 0,
    CACHE0_SIZE  = 0,
    CACHE0_LARGE = 0,
    SLOT0_BURSTLEN = 32,
/* verilator lint_off WIDTH */
    parameter [SDRAMW-1:0] SLOT0_OFFSET = {SDRAMW{1'b0}},
/* verilator lint_on WIDTH */
    SLOT0_OKLATCH= 1
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr,

    //  output data
    output [SLOT0_DW-1:0] slot0_dout,

    input               slot0_cs,
    output              slot0_ok,
    // SDRAM controller interface
    input               sdram_ack,
    output              sdram_rd,
    output [SDRAMW-1:0] sdram_addr,
    input               data_dst,
    input               data_rdy,
    input       [15:0]  data_read
);

jtframe_rom_2slots #(
    .SDRAMW       ( SDRAMW        ),
    .SLOT0_AW     ( SLOT0_AW      ),
    .SLOT0_DW     ( SLOT0_DW      ),
    .SLOT0_LATCH  ( SLOT0_LATCH   ),
    .SLOT0_OFFSET ( SLOT0_OFFSET  ),
    .SLOT0_DOUBLE ( SLOT0_DOUBLE  ),
    .SLOT0_OKLATCH( SLOT0_OKLATCH ),
    .CACHE0_SIZE  ( CACHE0_SIZE   ),
    .CACHE0_LARGE ( CACHE0_LARGE  ),
    .SLOT0_BURSTLEN( SLOT0_BURSTLEN )
) u_2slots(
    .rst    ( rst       ),
    .clk    ( clk       ),

    .slot0_addr( slot0_addr ),
    .slot1_addr(            ),

    //  output data
    .slot0_dout( slot0_dout ),
    .slot1_dout(            ),

    .slot0_cs  ( slot0_cs   ),
    .slot1_cs  ( 1'b0       ),

    .slot0_ok  ( slot0_ok   ),
    .slot1_ok  (            ),
    // SDRAM controller interface
    .sdram_ack ( sdram_ack  ),
    .sdram_rd ( sdram_rd  ),
    .sdram_addr( sdram_addr ),
    .data_dst  ( data_dst   ),
    .data_rdy  ( data_rdy   ),
    .data_read ( data_read  )
);

endmodule
