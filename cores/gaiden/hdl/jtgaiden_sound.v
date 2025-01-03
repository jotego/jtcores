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
    Date: 1-1-2025 */

module jtgaiden_sound(
    input                rst,
    input                clk,
    input                cen4,
    input                cen1,

    input       [ 7:0]   cmd,
    input                nmirq,
    // ROM
    output      [15:0]   rom_addr,
    output  reg          rom_cs,
    input       [ 7:0]   rom_data,
    input                rom_ok,
    // ADPCM ROM
    output        [16:0] pcm_addr,
    output               pcm_cs,
    input         [ 7:0] pcm_data,
    input                pcm_ok,
    // Sound
    output signed [15:0] fm0,  fm1,
    output        [ 9:0] psg0, psg1,
    output signed [13:0] pcm
);
`ifndef NOSOUND
wire [15:0] A;
wire [ 7:0] dout, fm0_dout, fm1_dout, oki_dout, ram_dout;
reg  [ 7:0] din;
wire        nc, rd_n, wr_n, nmi_n, mreq_n, rfsh_n, oki_wrn, m1_n, iorq_n, int_n;
reg         ram_cs, fm0_cs, fm1_cs, oki_cs, cmd_cs, rstn;

assign pcm_cs   = 1;
assign oki_wrn  = ~oki_cs | wr_n;
assign rom_addr = A;

always @(posedge clk) rstn <= ~rst;

always @* begin
    rom_cs = 0;
    ram_cs = 0;
    oki_cs = 0;
    fm0_cs = 0;
    fm1_cs = 0;
    cmd_cs = 0;
    if( !mreq_n && rfsh_n ) begin
        rom_cs = A[15:12]!=4'hf;
        ram_cs = A[15:12]==4'hf && !A[11];
        oki_cs = A[15:12]==4'hf &&  A[11:10]==2 && A[5:4]==0;
        fm0_cs = A[15:12]==4'hf &&  A[11:10]==2 && A[5:4]==1;
        fm1_cs = A[15:12]==4'hf &&  A[11:10]==2 && A[5:4]==2;
        cmd_cs = A[15:12]==4'hf &&  A[11:10]==3;
    end
end

always @(posedge clk) begin
    din <= rom_cs ? rom_data :
           ram_cs ? ram_dout :
           oki_cs ? oki_dout :
           fm0_cs ? fm0_dout :
           fm1_cs ? fm1_dout :
           cmd_cs ? cmd      : 8'h0;
end

jtframe_edge #(.QSET(0)) u_edge(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( nmirq     ),
    .clr    ( cmd_cs    ),
    .q      ( nmi_n     )
);

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( rstn        ),
    .clk        ( clk         ),
    .cen        ( cen4        ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   ( ram_dout    ),
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

jt03 u_fm0(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen        ( cen4       ),
    .din        ( dout       ),
    .dout       ( fm0_dout   ),
    .addr       ( A[0]       ),
    .cs_n       ( ~fm0_cs    ),
    .wr_n       ( wr_n       ),
    .psg_snd    ( psg0       ),
    .fm_snd     ( fm0        ),
    .snd_sample (            ),
    .irq_n      ( int_n      ),
    // unused outputs
    .IOA_oe     (            ),
    .IOB_oe     (            ),
    .IOA_in     ( 8'd0       ),
    .IOB_in     ( 8'd0       ),
    .IOA_out    (            ),
    .IOB_out    (            ),
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .snd        (            ),
    .debug_view (            )
);

jt03 u_fm1(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen        ( cen4       ),
    .din        ( dout       ),
    .dout       ( fm1_dout   ),
    .addr       ( A[0]       ),
    .cs_n       ( ~fm1_cs    ),
    .wr_n       ( wr_n       ),
    .psg_snd    ( psg1       ),
    .fm_snd     ( fm1        ),
    .snd_sample (            ),
    .irq_n      (            ),
    // unused outputs
    .IOA_oe     (            ),
    .IOB_oe     (            ),
    .IOA_in     ( 8'd0       ),
    .IOB_in     ( 8'd0       ),
    .IOA_out    (            ),
    .IOB_out    (            ),
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .snd        (            ),
    .debug_view (            )
);

jt6295 #(.INTERPOL(0)) u_adpcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen1      ),
    .ss         ( 1'b1      ),
    // CPU interface
    .wrn        ( oki_wrn   ),  // active low
    .din        ( dout      ),
    .dout       ( oki_dout  ),
    // ROM interface
    .rom_addr   ({nc,pcm_addr}),
    .rom_data   ( pcm_data  ),
    .rom_ok     ( pcm_ok    ),
    // Sound output
    .sound      ( pcm       ),
    .sample     (           )
);
`else
initial rom_cs=0;
assign  rom_addr=0, pcm_addr=0, pcm_cs=0,
        fm0=0,  fm1=0, psg0=0, psg1=0, pcm=0;
`endif
endmodule