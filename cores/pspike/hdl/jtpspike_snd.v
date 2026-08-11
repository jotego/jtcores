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
    Date: 11-8-2026 */

// Z80 at 5MHz plus a YM2610 at 8MHz.
//
//   0000-77ff  ROM, the bottom of the 128kB sound ROM
//   7800-7fff  RAM
//   8000-ffff  one of four 32kB banks of the same ROM
//
// Two different port maps:
//   spinlbrk_sound_portmap (pspikes, turbofrc)
//     00     w  bank select    14  r latch / w acknowledge    18-1b rw YM2610
//   pspikes_sound_portmap (aerofgtb) - despite the name, pspikes does NOT use it
//     00-03 rw  YM2610         04  w bank    08 w acknowledge  0c r latch
//
// Getting this wrong stalls the 68000: it polls the pending flag, and if the
// Z80 never hits the acknowledge port the flag never clears.
//
// The latch is two way: a write from the 68000 raises the Z80 NMI and sets a
// pending flag the 68000 can poll; the Z80 clears both by writing to port 14.

module jtpspike_snd(
    input                rst,
    input                clk,
    input                snd_cen,        // 5 MHz
    input                fm_cen,         // 8 MHz

    input      [ 7:0]    snd_latch,
    input                snd_wr,
    output reg           snd_pending,

    output     [16:0]    rom_addr,
    output               rom_cs,
    input      [ 7:0]    rom_data,
    input                rom_ok,

    output     [19:0]    pcma_addr,
    output               pcma_cs,
    input      [ 7:0]    pcma_data,
    input                pcma_ok,

    output     [18:0]    pcmb_addr,
    output               pcmb_cs,
    input      [ 7:0]    pcmb_data,
    input                pcmb_ok,

    input                aerofgt,
    input      [ 7:0]    debug_bus,

    output signed [15:0] fm_l, fm_r
);

wire [15:0] A;
wire [ 7:0] cpu_dout, fm_dout;
reg  [ 7:0] cpu_din;
reg  [ 1:0] bank;
wire        mreq_n, iorq_n, rd_n, wr_n, m1_n, rfsh_n, int_n;
wire        mem_acc, io_acc;
wire        ram_cs, bank_cs, latch_rd, latch_ack, fm_cs;
wire [ 7:0] ram_dout;
wire [19:0] adpcma_addr;
wire [23:0] adpcmb_addr;
// jt10.v declares adpcma_bank as 4 bits but its own jt12_top drives 5, so
// one width warning inside the submodule is unavoidable. Match the port and
// leave it unused: the 1MB region is covered by adpcma_addr alone
wire [ 3:0] adpcma_bank;
wire        adpcma_roe_n, adpcmb_roe_n;
reg  [ 7:0] pcma_l, pcmb_l;

assign mem_acc  = ~mreq_n & rfsh_n;
assign io_acc   = ~iorq_n & m1_n;
// 7800-7fff is the only RAM, everything else in memory space is ROM
assign ram_cs   = mem_acc & A[15:11]==5'b01111;
assign rom_cs   = mem_acc & ~ram_cs;
assign bank_cs  = io_acc & (aerofgt ? A[7:0]==8'h04 : A[7:0]==8'h00);
assign latch_rd = io_acc & (aerofgt ? A[7:0]==8'h0c : A[7:0]==8'h14);
assign latch_ack= io_acc & (aerofgt ? A[7:0]==8'h08 : A[7:0]==8'h14);
assign fm_cs    = io_acc & (aerofgt ? A[7:2]==6'b0000_00     // 00-03
                                    : A[7:2]==6'b0001_10);   // 18-1b
assign rom_addr = { A[15] ? bank : 2'd0, A[14:0] };

always @* begin
    cpu_din = 8'hff;
    case( 1'b1 )
        ram_cs:   cpu_din = ram_dout;
        rom_cs:   cpu_din = rom_data;
        latch_rd: cpu_din = snd_latch;
        fm_cs:    cpu_din = fm_dout;
        default:;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        bank        <= 0;
        snd_pending <= 0;
    end else begin
        if( bank_cs && !wr_n ) bank <= cpu_dout[1:0];
        // the 68000 write wins over a simultaneous acknowledge
        if( latch_ack && !wr_n ) snd_pending <= 0;
        if( snd_wr            ) snd_pending <= 1;
    end
end

jtframe_z80_devwait u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( snd_cen   ),
    .cpu_cen    (           ),
    .int_n      ( int_n     ),
    .nmi_n      ( ~snd_pending ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .din        ( cpu_din   ),
    .dout       ( cpu_dout  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .dev_busy   ( 1'b0      )
);

jtframe_ram #(.AW(11)) u_ram(
    .clk        ( clk       ),
    .cen        ( 1'b1      ),
    .addr       ( A[10:0]   ),
    .data       ( cpu_dout  ),
    .we         ( ram_cs & ~wr_n ),
    .q          ( ram_dout  )
);

// ADPCM ROMs. The chip has no wait handshake, so the byte is latched when
// SDRAM answers and held until the next request
assign pcma_cs   = ~adpcma_roe_n;
assign pcmb_cs   = ~adpcmb_roe_n;
assign pcma_addr = adpcma_addr;         // 1 MB region, adpcma_bank stays 0
assign pcmb_addr = adpcmb_addr[18:0];   // 256 kB region

always @(posedge clk) begin
    if( pcma_cs && pcma_ok ) pcma_l <= pcma_data;
    if( pcmb_cs && pcmb_ok ) pcmb_l <= pcmb_data;
end

jt10 u_jt10(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( fm_cen    ),
    .din        ( cpu_dout  ),
    .addr       ( A[1:0]    ),
    .cs_n       ( ~fm_cs    ),
    .wr_n       ( wr_n      ),
    .dout       ( fm_dout   ),
    .irq_n      ( int_n     ),

    .adpcma_addr( adpcma_addr  ),
    .adpcma_bank( adpcma_bank  ),
    .adpcma_roe_n(adpcma_roe_n ),
    .adpcma_data( pcma_l       ),
    .adpcmb_addr( adpcmb_addr  ),
    .adpcmb_roe_n(adpcmb_roe_n ),
    .adpcmb_data( pcmb_l       ),

    // separated outputs unused, the mixed ones carry everything
    .psg_A      (           ),
    .psg_B      (           ),
    .psg_C      (           ),
    .fm_snd     (           ),
    .psg_snd    (           ),
    .snd_right  ( fm_r      ),
    .snd_left   ( fm_l      ),
    .snd_sample (           ),
    // debug_bus[5:0] mutes individual ADPCM-A channels, 0 = all playing
    .ch_enable  ( ~debug_bus[5:0] )
);

endmodule
