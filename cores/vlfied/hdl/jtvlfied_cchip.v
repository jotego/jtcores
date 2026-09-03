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
    Version: 1.0
    Date: 7-8-2026 */

/*  TC0030CMD C-chip. 68k window f00000-f00fff, lower byte only:
      $000-$7FF  shared SRAM
      $800-$FFF  ASIC registers

    MCU port assignment (volfied.cpp machine_config):
      PA: bit5=START2 bit6=START1 bit7=SERVICE1
      PB: bit0=COIN1  bit1=COIN2
      PC: bit0=TILT   bit2..5=U/D/L/R  bit6=BUTTON1
      AD: bit1=UP bit2=DOWN bit4=RIGHT bit5=BUTTON1 bit7=LEFT, all cocktail P2
    Idle port bytes measured on MAME: PA=FF PB=FC PC=FF AD=FF.
    P2 LEFT sits on bit 7 rather than bit 3: the AD pins are ADC channels, and
    only the upper four can be read as digital inputs.    */

module jtvlfied_cchip(
    input             rst,
    input             clk,
    input             cen,

    // 68k side (lower byte only, umask 0x00ff)
    input             cs,
    input      [11:1] addr,
    input      [ 7:0] din,
    output     [ 7:0] dout,
    input             rnw,
    input             LVBL,

    // cabinet inputs. Active LOW (idle = 1), matching JTFRAME/MAME convention.
    input      [ 4:0] joystick1,       // [3:0]=U/D/L/R, [4]=button1
    input      [ 4:0] joystick2,
    input      [ 1:0] start_button,    // [0]=1P, [1]=2P
    input      [ 1:0] coin,
    input             service,
    input             tilt,

    output     [11:0] cchip_mask_addr,
    input      [ 7:0] cchip_mask_data,
    output     [12:0] cchip_eprom_addr,
    input      [ 7:0] cchip_eprom_data
);

reg [7:0] cc_pa, cc_pb, cc_pc, cc_an;

always @(posedge clk) begin
    cc_pa <= { service, start_button[0], start_button[1], 5'h1f };
    // Coin bits are active HIGH at the port (idle=0), opposite JTFRAME's
    // active-low coin — without the inversion the C-chip sees two coins stuck
    // inserted and shows COIN ERROR.
    cc_pb <= { 6'h3f, ~coin[1], ~coin[0] };
    // The four direction bits go in REVERSED into pc[5:2]; feeding them
    // straight swaps Up<->Right and Down<->Left.
    cc_pc <= { 1'b1, joystick1[4],
               joystick1[0], joystick1[1], joystick1[2], joystick1[3],
               1'b1, tilt };
    cc_an <= { joystick2[1], 1'b1, joystick2[4], joystick2[0],
               1'b1, joystick2[2], joystick2[3], 1'b1 };
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
    .int1       ( ~LVBL            ),   // volfied.cpp: ext_interrupt on VBL
    .nmi_n      ( 1'b1             ),
    .pa_in      ( cc_pa            ),
    .pb_in      ( cc_pb            ),
    .pc_in      ( cc_pc            ),
    .pa_out     (                  ),
    .pb_out     (                  ),   // coin lockout/counters (unused)
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
