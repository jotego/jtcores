/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-9-2026 */

module jtharier_dtack_cen(
    input         rst,
    input         clk,
    output        cpu_cen,
    output        cpu_cenb,
    input         UDSn, LDSn,
    input         bus_cs,
    input         bus_busy,
    input         bus_legit,
    input         bus_ack, // do not recover cycles if another CPU has the bus
    input         ASn,  // DTACKn set low at the next cpu_cen after ASn goes low
    input [1:0]   DSn,  // If DSn goes high, DTACKn is reset high

    output        DTACKn,
    output  [15:0] fave, // average cpu_cen frequency in kHz
    output  [15:0] fworst  // average cpu_cen frequency in kHz
);

jtframe_68kdtack_cen #(.W(10)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( bus_legit ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        (  9'd173   ),
    .den        ( 10'd871   ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .DTACKn     ( DTACKn    ),
    .fave       ( fave      ),
    .fworst     ( fworst    )
);

endmodule