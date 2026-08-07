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

    Volfied sound: Z80 @ 4 MHz + YM2203 @ 4 MHz + PC060HA, from volfied.cpp:
      0000-7fff  ROM
      8000-87ff  RAM
      8800       PC060HA slave_port_w
      8801       PC060HA slave_comm_r/w
      9000-9001  YM2203
      9800       NOP (write)
    DIP switches A/B are read through the YM2203 port A/B inputs.
*/

module jtvlfied_snd(
    input                rst,
    input                clk,            // 48 MHz

    // From main CPU (PC060HA master side)
    input                main_cen,       // 68k cen, 8 MHz
    input                main_addr,      // = A[1]
    input         [ 3:0] main_dout,
    output        [ 3:0] main_din,
    input                main_rnw,
    input                sn_rd,
    input                sn_we,

    output        [14:0] rom_addr,
    output reg           rom_cs,
    input                rom_ok,
    input         [ 7:0] rom_data,

    input         [ 7:0] dipsw_a,
    input         [ 7:0] dipsw_b,

    output signed [15:0] fm,           // YM2203 FM  -> mem.yaml channel 'fm'
    output        [ 9:0] psg           // YM2203 PSG -> mem.yaml channel 'psg'
);
// Z80 and the PC060HA sound side share one cen, half of the 68k's: the
// handshake edge detection inside the PC060HA samples on it.
reg  snd_cen_tog;
wire snd_cen = main_cen & snd_cen_tog;
always @(posedge clk, posedge rst) begin
    if( rst )
        snd_cen_tog <= 0;
    else if( main_cen )
        snd_cen_tog <= ~snd_cen_tog;
end
`ifndef NOSOUND
wire        [ 1:0] cen_pair;
wire               cen4 = cen_pair[0];
wire        [15:0] A;
wire        [ 7:0] dout, ym_dout, ram_dout;
wire        [ 3:0] pc6_dout;
reg                ym_cs, ram_cs, pc6_cs;
wire               m1_n, iorq_n, rd_n, wr_n, mreq_n, rfsh_n, nmi_n;
wire               int_n, pc6_rst, main_cs;
reg                snd_rstn;
reg         [ 7:0] din;
wire signed [15:0] fm_snd;

assign main_cs  = sn_rd | sn_we;
assign rom_addr = A[14:0];

always @(posedge clk) snd_rstn <= ~(rst | pc6_rst);

always @* begin
    rom_cs = !A[15] && !rd_n;            // 0000-7fff
    ram_cs = 0;
    pc6_cs = 0;
    ym_cs  = 0;
    if( !mreq_n && rfsh_n && A[15] ) begin
        case( A[14:11] )
            4'h0: ram_cs = 1;            // 8000-87ff (decoded coarse)
            4'h1: pc6_cs = 1;            // 8800-8801
            4'h2: ym_cs  = 1;            // 9000-9001
            default:;
        endcase
    end
end

always @(posedge clk) begin
    din <= rom_cs ? rom_data :
           ram_cs ? ram_dout :
           ym_cs  ? ym_dout  :
           pc6_cs ? { 4'hf, pc6_dout } :
           8'hff;
end

jtframe_frac_cen #(.W(2),.WC(11)) u_cpucen(  // 48 MHz -> 4 MHz YM2203
    .clk  ( clk          ),
    .n    ( 11'd1        ),
    .m    ( 11'd12       ),
    .cen  ( cen_pair     ),
    .cenb (              )
);

jtrastan_pc060 u_pc060(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .main_cen   ( main_cen  ),
    .snd_cen    ( snd_cen   ),
    .main_dout  ( main_dout ),
    .main_din   ( main_din  ),
    .main_addr  ( main_addr ),
    .main_rnw   ( main_rnw  ),
    .main_cs    ( main_cs   ),

    .snd_dout   ( dout[3:0] ),
    .snd_din    ( pc6_dout  ),
    .snd_addr   ( A[0]      ),
    .snd_rnw    ( wr_n      ),
    .snd_cs     ( pc6_cs    ),
    .snd_nmin   ( nmi_n     ),
    .snd_rst    ( pc6_rst   )
);

// RECOVERY cannot be set because snd_cen comes from fx68k and it
// may not have enough idle clock cycles for RECOVERY to work.
// See https://github.com/jotego/jtcores/issues/1502
jtframe_sysz80 #(.RECOVERY(0)) u_cpu(
    .rst_n      ( snd_rstn  ),
    .clk        ( clk       ),
    .cen        ( snd_cen   ),
    .cpu_cen    (           ),
    .int_n      ( int_n     ),
    .nmi_n      ( nmi_n     ),
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
    .cpu_din    ( din       ),
    .cpu_dout   ( dout      ),
    .ram_dout   ( ram_dout  ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);

jt03 u_ym2203(
    .rst        ( ~snd_rstn ),
    .clk        ( clk       ),
    .cen        ( cen4      ),
    .din        ( dout      ),
    .addr       ( A[0]      ),
    .cs_n       ( ~ym_cs    ),
    .wr_n       ( wr_n      ),
    .dout       ( ym_dout   ),
    .irq_n      ( int_n     ),
    .IOA_in     ( dipsw_a   ),
    .IOB_in     ( dipsw_b   ),
    .IOA_out    (           ),
    .IOB_out    (           ),
    .IOA_oe     (           ),
    .IOB_oe     (           ),
    .psg_A      (           ),
    .psg_B      (           ),
    .psg_C      (           ),
    .fm_snd     ( fm_snd    ),
    .psg_snd    ( psg       ),
    .snd        (           ),
    .snd_sample (           ),
    .debug_view (           )
);

assign fm = fm_snd;
`else
assign main_din=0, rom_addr=0, fm=0, psg=0;
initial rom_cs=0;
`endif
endmodule
