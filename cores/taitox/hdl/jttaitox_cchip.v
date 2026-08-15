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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Date: 8-2026 */

/*  TC0030CMD C-chip, Superman only. 68k window 900000-900fff, lower byte:
      $000-$7FF  shared SRAM  (900000-9007ff, mem68)
      $800-$FFF  ASIC regs    (900800-900fff, asic)
    Host address is A[11:1] -> the module's 11-bit addr.

    MCU port assignment (taito_x.cpp superman machine_config):
      pa <- IN0   P1 joystick + buttons + START1
      pb <- IN1   P2 joystick + buttons + START2
      an <- IN2   coins, service, tilt
      pc -> counters_w   coin counters and lockouts

    IN0/IN1 are TAITO_JOY_UDLR_2_BUTTONS_START:
      0-3 U/D/L/R, 4 B1, 5 B2, 6 B3 (kyustrkr only), 7 STARTn
    IN2 on Superman is NOT the taito_x generic layout - bit 3 is unused
    and TILT sits on bit 7:
      0 COIN1, 1 COIN2, 2 SERVICE1, 3-6 unused, 7 TILT

    Everything is active low on both sides, so the cabinet inputs go
    straight in.  The joystick arrives already reordered to UDLR by
    JTFRAME_JOY_RLDU.    */

module jttaitox_cchip(
    input             rst,
    input             clk,
    input             cen,

    // 68k side, lower byte only
    input             cs,
    input      [10:0] addr,
    input      [ 7:0] din,
    output     [ 7:0] dout,
    input             rnw,
    input             LVBL,

    // cabinet inputs, active low
    input      [ 6:0] joystick1,
    input      [ 6:0] joystick2,
    input      [ 1:0] start_button,
    input      [ 1:0] coin,
    input             service,
    input             tilt,

    // coin counters / lockouts (pc_out), for the coin door
    output     [ 7:0] counters,

    output     [11:0] cchip_mask_addr,
    input      [ 7:0] cchip_mask_data,
    output     [12:0] cchip_eprom_addr,
    input      [ 7:0] cchip_eprom_data
);

reg [7:0] cc_pa, cc_pb, cc_an;

always @(posedge clk) begin
    cc_pa <= { start_button[0], joystick1[6:4], joystick1[3:0] };
    cc_pb <= { start_button[1], joystick2[6:4], joystick2[3:0] };
    cc_an <= { tilt, 4'hf, service, coin[1], coin[0] };
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
    .dtack_n    (                  ),   // main paces via jtframe_68kdtack_cen
    // taito_x.cpp asserts ext_interrupt on the vblank interrupt and clears it
    // on the next timer slice. The module conditions the edge internally, so
    // the raw blanking level goes straight in.
    .int1       ( ~LVBL            ),
    .nmi_n      ( 1'b1             ),
    .pa_in      ( cc_pa            ),
    .pb_in      ( cc_pb            ),
    .pc_in      ( 8'hff            ),
    .pa_out     (                  ),
    .pb_out     (                  ),
    .pc_out     ( counters         ),
    .an         ( cc_an            ),
    .mrom_addr  ( cchip_mask_addr  ),
    .mrom_data  ( cchip_mask_data  ),
    .eprom_addr ( cchip_eprom_addr ),
    .eprom_data ( cchip_eprom_data ),
    // debug (unused)
    .dbg_pc     (                  ),
    .dbg_fetch  (                  )
);

endmodule
