/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-3-2025 */

module jtrthunder_main(
    input               rst,
    input               clk,

    output              mrom_cs,   srom_cs,   ram_cs,
    input               mrom_ok,   srom_ok,   ram_ok,
    input        [ 7:0] mrom_data, srom_data, ram_dout,

    input        [ 7:0] debug_bus,
    output       [ 7:0] st_dout
);
`ifndef NOMAIN

wire [15:0] maddr;

jtrthunder_cus47 u_cus47(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .addr       ( maddr     ),
);

mc6809i u_mcpu(
    .nRESET     ( rst_n     ),
    .clk        ( clk       ),
    .cen_E      ( main_E    ),
    .cen_Q      ( main_Q    ),
    .D          ( mdin      ),
    .DOut       ( mdout     ),
    .ADDR       ( maddr     ),
    .RnW        ( mrnw      ),
    // Interrupts
    .nIRQ       ( mirq_n    ),
    .nFIRQ      ( mfirq_n   ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .AVMA       ( mavma     ),
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);

mc6809i u_scpu(
    .nRESET     ( rst_n     ),
    .clk        ( clk       ),
    .cen_E      ( sub_E     ),
    .cen_Q      ( sub_Q     ),
    .D          ( sdin      ),
    .DOut       ( sdout     ),
    .ADDR       ( saddr     ),
    .RnW        ( srnw      ),
    // Interrupts
    .nIRQ       ( sirq_n    ),
    .nFIRQ      ( sfirq_n   ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .AVMA       ( savma     ),
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);
`else
`endif
endmodule