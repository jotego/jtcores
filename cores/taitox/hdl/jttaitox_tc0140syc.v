/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR addr PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received addr copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
            Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 17-8-2026 */

/*  Taito TC0140SYT.

    The 68000<->Z80 nibble mailbox is very similar to PC060HA

    On top of that the TC0140SYT owns the Z80 memory decode, which the
    PC060HA does not: it emits the ROM and RAM chip selects and holds the
    16 kB bank latch. That is what this module adds around the mailbox.
*/

module jttaitox_tc0140syc(
    input             rst,
    input             clk,
    input             main_cen,
    input             snd_cen,

    // 68000 side: 800001 port, 800003 comm
    input             main_cs,
    input             main_addr,   // A1
    input      [ 3:0] main_dout,
    output     [ 3:0] main_din,
    input             main_rnw,

    // Z80 side
    input      [15:0] addr,
    input      [ 7:0] din,
    output     [ 3:0] dout,
    input             mreq_n,
    input             rfsh_n,
    input             wr_n,
    output            nmi_n,
    output            z80_rst,     // slave reset requested by the 68000

    // Z80 memory decode
    output            rom_cs,
    output     [15:0] rom_addr,    // 16 kB pages, low 64 kB of the sound ROM
    output            ram_cs,
    output            opx_n,       // YM select, active low
    output            syt_cs       // this chip's own select
);

wire       mem_acc, bank_cs;
wire [1:0] bank;
wire [7:2] nc;

assign mem_acc  = ~mreq_n & rfsh_n;
assign rom_cs   = mem_acc & ~addr[15];
assign ram_cs   = mem_acc && addr[15:13]==3'b110;
assign opx_n    = ~(mem_acc && addr[15:8]==8'hE0);
assign syt_cs   = mem_acc && addr[15:8]==8'hE2;
assign rom_addr = { addr[14] ? bank : 2'd0, addr[13:0] };
assign bank_cs  = mem_acc && addr[15:8]==8'hf2;

jtframe_8bit_reg u_bank(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .din        ( din           ),
    .dout       ( {nc,bank}     ),
    .wr_n       ( wr_n          ),
    .cs         ( bank_cs       )
);

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
    .snd_addr   ( addr[0]       ),
    .snd_rnw    ( wr_n          ),
    .snd_cs     ( syt_cs        ),
    .snd_nmin   ( nmi_n         ),
    .snd_rst    ( z80_rst       )
);

endmodule
