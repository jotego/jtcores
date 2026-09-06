/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-4-2022 */

module jtrastan_cchip(
    input         rst,
    input         clk,
    input         cen,
    input         cs,
    input  [10:0] addr,
    input  [ 7:0] din,
    output [ 7:0] dout,
    input         rnw,
    input         LVBL,
    input         rbisland,
    input         service,
    input  [ 1:0] cab_1p,
    input  [ 1:0] coin,
    input         tilt,
    input  [ 5:0] joystick1,
    output [11:0] cchip_mask_addr,
    input  [ 7:0] cchip_mask_data,
    output [12:0] cchip_eprom_addr,
    input  [ 7:0] cchip_eprom_data
);

wire int1;
reg  [7:0] cc_pa, cc_pb, cc_pc, cc_an;

assign int1 = ~LVBL;

always @(posedge clk) begin
    cc_pa <= rbisland ? { service, cab_1p[0], cab_1p[1], 5'h1f } : 8'h00;
    cc_pb <= { 6'h3f, ~coin[1:0] };
    cc_pc <= rbisland ? { joystick1[5], joystick1[4], joystick1[0],
                          joystick1[1], 3'b111, tilt } :
                        { 3'b111, cab_1p[0], tilt, service,
                          joystick1[5], joystick1[4] };
    // Needs extra investigation to see if we can live without this.
    cc_an <= rbisland ? 8'hff : 8'h00;
end

jttc0030cmd u_cchip(
    .rst        ( rst              ),
    .clk        ( clk              ),
    .cen        ( cen              ),
    .cs         ( cs               ),
    .addr       ( addr             ),
    .din        ( din              ),
    .dout       ( dout             ),
    .rnw        ( rnw              ),
    .dtack_n    (                  ),
    .int1       ( int1             ),
    .nmi_n      ( 1'b1             ),
    .pa_in      ( cc_pa            ),
    .pb_in      ( cc_pb            ),
    .pc_in      ( cc_pc            ),
    .pa_out     (                  ),
    .pb_out     (                  ),
    .pc_out     (                  ),
    .an         ( cc_an            ),
    .mrom_addr  ( cchip_mask_addr  ),
    .mrom_data  ( cchip_mask_data  ),
    .eprom_addr ( cchip_eprom_addr ),
    .eprom_data ( cchip_eprom_data ),
    .rom_addr   (                  ),
    .rom_cs     (                  ),
    // debug (unused)
    .dbg_pc     (                  ),
    .dbg_fetch  (                  )
);

endmodule
