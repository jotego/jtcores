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
    Date: 18-8-2026 */

/*  P0-051A sound: PC060HA + YM2151, for Daisenpu and Twin Hawk.

    The Z80 map is the same as the other two boards, so the decode and the
    bank latch are shared and come from the caller. Only the mailbox chip
    and the FM chip differ:

      P0-039A / P0-057A   TC0140SYT + YM2610 @ 8 MHz
      P0-051A             PC060HA   + YM2151 @ 4 MHz

    Both chips are the same silicon for the mailbox - MAME's pc060ha_device
    derives from tc0140syt_device - so this uses jtrastan_pc060 too. What
    it does not do is emit the Z80 chip selects: that is TC0140SYT-only, and
    on this board the decode is discrete logic we have no schematic for.

    The YM2151 register window is e000-e001 against the YM2610's e000-e003,
    but the caller decodes A[15:8]==8'hE0, which covers both.             */

module jttaitox_hawk_snd(
    input             rst,
    input             clk,
    input             fm_cen,      // 16/4 = 4 MHz
    input             fm_cenp1,    // half of fm_cen
    input             main_cen,
    input             snd_cen,

    // 68000 side of the mailbox
    input             main_cs,
    input             main_addr,   // A1
    input      [ 3:0] main_dout,
    output     [ 3:0] main_din,
    input             main_rnw,

    // Z80 side
    input      [15:0] a,
    input      [ 7:0] din,
    output     [ 3:0] dout,
    input             wr_n,
    input             syt_cs,      // mailbox select, decoded by the caller
    input             ym_cs,
    output            nmi_n,
    output            z80_rst,
    output     [ 7:0] ym_dout,
    output            int_n,

    output signed [15:0] snd_left, snd_right
);

`ifndef NOSOUND
jtrastan_pc060 u_mailbox(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .main_cen   ( main_cen      ),
    .snd_cen    ( snd_cen       ),

    .main_dout  ( main_dout     ),
    .main_din   ( main_din      ),
    .main_addr  ( main_addr     ),
    .main_rnw   ( main_rnw      ),
    .main_cs    ( main_cs       ),

    .snd_dout   ( din[3:0]      ),
    .snd_din    ( dout          ),
    .snd_addr   ( a[0]          ),
    .snd_rnw    ( wr_n          ),
    .snd_cs     ( syt_cs        ),
    .snd_nmin   ( nmi_n         ),
    .snd_rst    ( z80_rst       )
);

jt51 u_jt51(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( fm_cen        ),
    .cen_p1     ( fm_cenp1      ),
    .cs_n       ( ~ym_cs        ),
    .wr_n       ( wr_n          ),
    .a0         ( a[0]          ),
    .din        ( din           ),
    .dout       ( ym_dout       ),
    .ct1        (               ),
    .ct2        (               ),
    .irq_n      ( int_n         ),
    .sample     (               ),
    .left       (               ),
    .right      (               ),
    .xleft      ( snd_left      ),
    .xright     ( snd_right     )
);
`else
assign main_din=0, dout=0, nmi_n=1, z80_rst=0, ym_dout=0, int_n=1,
       snd_left=0, snd_right=0;
`endif

endmodule
