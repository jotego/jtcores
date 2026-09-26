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
            Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-8-2026 */

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

`ifdef RAM_IN_SDRAM
    // Mask ROM + game EPROM as one 12 kB SDRAM region: mask at 0x0000,
    // EPROM at 0x1000. Saves 12 BRAM blocks on the small devices.
    output     [13:0] ccrom_addr,
    output            ccrom_cs,
    input      [ 7:0] ccrom_data,
    input             ccrom_ok
`else
    output     [11:0] cchip_mask_addr,
    input      [ 7:0] cchip_mask_data,
    output     [12:0] cchip_eprom_addr,
    input      [ 7:0] cchip_eprom_data
`endif
);

reg [7:0] cc_pa, cc_pb, cc_an;

always @(posedge clk) begin
    cc_pa <= { start_button[0], joystick1[6:4], joystick1[3:0] };
    cc_pb <= { start_button[1], joystick2[6:4], joystick2[3:0] };
    cc_an <= { tilt, 4'hf, service, coin[1], coin[0] };
end

`ifdef RAM_IN_SDRAM
// Stall the MCU while a fetch is in flight. The address is combinational on
// the MCU state, so it stays put while cen is held low.
wire mcu_cen = cen & ~(ccrom_cs & ~ccrom_ok);
`else
wire mcu_cen = cen;
`endif

jttc0030cmd u_cchip(
    .rst        ( rst              ),
    .clk        ( clk              ),
    .cen        ( mcu_cen          ),
    .cs         ( cs               ),
    .addr       ( addr             ),
    .din        ( din              ),
    .dout       ( dout             ),
    .rnw        ( rnw              ),
    .dtack_n    (                  ),
    .int1       ( ~LVBL            ),
    .nmi_n      ( 1'b1             ),
    .pa_in      ( cc_pa            ),
    .pb_in      ( cc_pb            ),
    .pc_in      ( 8'hff            ),
    .pa_out     (                  ),
    .pb_out     (                  ),
    .pc_out     ( counters         ),
    .an         ( cc_an            ),
`ifdef RAM_IN_SDRAM
    .mrom_addr  (                  ),
    .mrom_data  ( ccrom_data       ),
    .eprom_addr (                  ),
    .eprom_data ( ccrom_data       ),
    .rom_addr   ( ccrom_addr       ),
    .rom_cs     ( ccrom_cs         ),
`else
    .mrom_addr  ( cchip_mask_addr  ),
    .mrom_data  ( cchip_mask_data  ),
    .eprom_addr ( cchip_eprom_addr ),
    .eprom_data ( cchip_eprom_data ),
    .rom_addr   (                  ),
    .rom_cs     (                  ),
`endif
    // debug (unused)
    .dbg_pc     (                  ),
    .dbg_fetch  (                  )
);

endmodule
