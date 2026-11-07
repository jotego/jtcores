/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-6-2021 */

module jts16_fd1094(
    input             rst,
    input             clk,

    // Key access
    output     [12:0] key_addr,
    input      [ 7:0] key_data,

    // Configuration
    input      [12:0] prog_addr,
    input             fd1094_we,
    input      [ 7:0] prog_data,

    // Operation
    input             dec_en,
    input      [ 2:0] FC,
    input             ASn,

    input      [23:1] addr,
    input      [15:0] enc,
    output     [15:0] dec,

    input             rom_ok,
    input             dtackn,
    output            ok_dly
);

parameter SIMFILE="maincpu:key";

wire [7:0] st,       // state
           gkey0;

wire inta_n = ~&{ FC[2], FC[1], FC[0], ~ASn }; // interrupt ack
wire vrq    = ~&FC;
wire op_n   = FC[1:0]!=2'b10;
wire sup_prog = FC == 3'd6;

jts16_fd1094_ctrl u_ctrl(
    .rst        ( rst       ),
    .clk        ( clk       ),

    // Operation
    .inta_n     ( inta_n    ),      // interrupt acknowledgement
    .op_n       ( op_n      ),

    .addr       ( addr      ),
    .dec        ( dec       ),
    .gkey0      ( gkey0     ),

    .sup_prog   ( sup_prog  ),
    .dtackn     ( dtackn    ),
    .st         ( st        )
);

jts16_fd1094_dec #(.SIMFILE(SIMFILE)) u_dec(
    .rst        ( rst       ),
    .clk        ( clk       ),

    // Key access
    .key_addr   ( key_addr  ),
    .key_data   ( key_data  ),

    // Configuration
    .prog_addr  ( prog_addr ),
    .fd1094_we  ( fd1094_we ),
    .prog_data  ( prog_data ),

    // Operation
    .dec_en     ( dec_en    ),
    .vrq        ( vrq       ),      // vector request
    .st         ( st        ),       // state
    .gkey0      ( gkey0     ),

    .op_n       ( op_n      ),     // OP (0) or data (1)
    .addr       ( addr      ),
    .enc        ( enc       ),
    .dec        ( dec       ),

    .rom_ok     ( rom_ok    ),
    .ok_dly     ( ok_dly    )
);

endmodule