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

      P0-039A / P0-057A   TC0140SYT + YM2610 @ 8 MHz
      P0-051A             PC060HA   + YM2151 @ 4 MHz

    The mailbox is the same silicon on both - MAME's pc060ha_device derives
    from tc0140syt_device - so this uses jtrastan_pc060 too. The PC060HA
    does NOT emit the Z80 chip selects the way the TC0140SYT does: here the
    decode is board logic, so it lives in this file. The map matches the
    other boards; the YM2151 answers e000-e001 where the YM2610 takes
    e000-e003, and A[15:8]==8'hE0 covers both.                            */

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

    // Z80 bus
    input      [15:0] a,
    input      [ 7:0] din,
    input             mreq_n,
    input             rfsh_n,
    input             wr_n,
    input      [ 7:0] ram_dout,
    output reg [ 7:0] cpu_din,
    output            nmi_n,
    output            int_n,
    output            z80_rst,

    output            rom_cs,
    output     [15:0] rom_addr,
    output            ram_cs,
    input      [ 7:0] rom_data,

    output signed [15:0] snd_left, snd_right
);

`ifndef NOSOUND
wire [ 7:0] ym_dout;
wire [ 3:0] mbox_dout;
wire        mem, ym_cs, syt_cs;
reg  [ 1:0] bank;

assign mem      = ~mreq_n & rfsh_n;
assign rom_cs   = mem & ~a[15];
assign ram_cs   = mem & a[15:13]==3'b110;
assign ym_cs    = mem & a[15:8]==8'hE0;
assign syt_cs   = mem & a[15:8]==8'hE2;
assign rom_addr = { a[14] ? bank : 2'd0, a[13:0] };

always @(posedge clk) begin
    if( rst )
        bank <= 0;
    else if( mem && a[15:8]==8'hF2 && !wr_n )
        bank <= din[1:0];
end

always @(posedge clk) begin
    cpu_din <= rom_cs ? rom_data :
               ram_cs ? ram_dout :
               ym_cs  ? ym_dout  :
               syt_cs ? { 4'd0, mbox_dout } : 8'hff;
end

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
    .snd_din    ( mbox_dout     ),
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
assign main_din=0, nmi_n=1, z80_rst=0, int_n=1, rom_cs=0, rom_addr=0,
       ram_cs=0, snd_left=0, snd_right=0;
initial cpu_din=0;
`endif

endmodule
