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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-8-2024 */

module jtwwfss_sound(
    input                rst,
    input                clk,

    input                cen_fm,
    input                cen_fm2,
    input                cen_oki,

    // Interface with main CPU
    input                snd_on,
    input         [ 7:0] snd_latch,

    // ROM
    output        [14:0] rom_addr,
    input         [ 7:0] rom_data,
    output    reg        rom_cs,
    input                rom_ok,

    // ADPCM ROM
    output        [17:0] pcm_addr,
    output               pcm_cs,
    input         [ 7:0] pcm_data,
    input                pcm_ok,

    // Sound output
    output signed [15:0] fm_l, fm_r,
    output signed [13:0] pcm
);
`ifndef NOSOUND
reg         [ 7:0] din;
wire        [ 7:0] ram_dout, dout, oki_dout, fm_dout;
wire        [15:0] A;
reg                fm_cs, ram_cs, oki_cs, latch_cs;
wire               iorq_n, m1_n, mreq_n, int_n, oki_wrn, rd_n, wr_n, nmi_n;

assign pcm_cs   = 1;
assign oki_wrn  = ~(oki_cs & ~wr_n);
assign rom_addr = A[14:0];

always @* begin
    rom_cs   = !A[15];
    ram_cs   = 0;
    fm_cs    = 0;
    oki_cs   = 0;
    latch_cs = 0;

    if( A[15:14]==2'b10 && !mreq_n ) case(A[13:11])
        0: ram_cs   = 1;
        1: fm_cs    = 1;
        3: oki_cs   = 1;
        4: latch_cs = 1;
        default:;
    endcase
end

always @(posedge clk) begin
    din <= rom_cs   ? rom_data  :
           ram_cs   ? ram_dout  :
           oki_cs   ? oki_dout  :
           fm_cs    ? fm_dout   :
           latch_cs ? snd_latch : 8'h0;
end

jtframe_edge #(.QSET(0)) u_edge(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( snd_on    ),
    .clr    ( latch_cs  ),
    .q      ( nmi_n     )
);

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   ( ram_dout    ),
    // manage access to ROM data from SDRAM
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);
/* verilator tracing_off */
jt51 u_jt51(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( wr_n      ), // write
    .a0         ( A[0]      ),
    .din        ( dout      ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( int_n     ),
    // Low resolution output (same as real chip)
    .sample     (           ),
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

jt6295 #(.INTERPOL(0)) u_adpcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_oki   ),
    .ss         ( 1'b1      ),
    // CPU interface
    .wrn        ( oki_wrn   ),  // active low
    .din        ( dout      ),
    .dout       ( oki_dout  ),
    // ROM interface
    .rom_addr   ( pcm_addr  ),
    .rom_data   ( pcm_data  ),
    .rom_ok     ( pcm_ok    ),
    // Sound output
    .sound      ( pcm       ),
    .sample     (           )
);
`else
    initial rom_cs   = 0;
    assign  rom_addr = 0;
    assign  pcm_addr = 0;
    assign  pcm_cs   = 0;
    assign  fm_l     = 0, fm_r = 0;
    assign  pcm      = 0;
`endif
endmodule
