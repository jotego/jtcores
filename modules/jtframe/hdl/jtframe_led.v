/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-3-2019 */

module jtframe_led(
    input        rst,
    input        clk,
    input        LVBL,
    input        ioctl_rom,
    input        osd_shown,
    input [3:0]  gfx_en,
    input [1:0]  game_led,
    input        cheat_led,
    output reg   led
);

wire  sys_led, enlarged;
reg   last_LVBL, cen_VB;

`ifdef MISTER
localparam POL = 1;
`else
localparam POL = 0;
`endif

assign sys_led = ~( ioctl_rom | cheat_led /*| osd_shown*/);

always @(posedge clk) begin
    last_LVBL <= LVBL;
    cen_VB    <= !LVBL && last_LVBL;
end

// Make the minimum pulse length equal to 16 frames = 0.26s
jtframe_enlarger #(.W(4)) u_enlarger(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .cen        ( cen_VB            ),
    .pulse_in   ( game_led[0]       ),
    .pulse_out  ( enlarged          )
);

///////////////// LED is on while
// ioctl_rom, PLL lock lost, OSD is shown or in reset state
always @(posedge clk) begin
    if( rst ) begin
        led <= POL[0];
    end else begin
        led <= (~enlarged & sys_led ) ^ POL[0];
    end
end

endmodule