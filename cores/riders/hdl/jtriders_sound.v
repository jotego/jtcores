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
    Date: 7-7-2024 */

module jtriders_sound(
    input           rst,
    input           clk,
    input           cen_8,
    input           cen_4,
    input           cen_fm,
    input           cen_fm2,
    input           cen_pcm,

    // communication with main CPU
    input   [ 7:0]  main_dout,  // bus access for Punk Shot
    output  [ 7:0]  main_din,
    input   [ 4:1]  main_addr,
    input           main_rnw,

    input           snd_irq,
    // ROM
    output  [16:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output   [20:0] pcma_addr,
    input    [ 7:0] pcma_dout,
    output          pcma_cs,
    input           pcma_ok,

    output   [20:0] pcmb_addr,
    input    [ 7:0] pcmb_dout,
    output          pcmb_cs,
    input           pcmb_ok,

    output   [20:0] pcmc_addr,
    input    [ 7:0] pcmc_dout,
    output          pcmc_cs,
    input           pcmc_ok,

    output   [20:0] pcmd_addr,
    input    [ 7:0] pcmd_dout,
    output          pcmd_cs,
    input           pcmd_ok,
    input    [ 5:0] snd_en,
    // Sound output
    output     signed [15:0] k60_l, k60_r
);
`ifndef NOSOUND
wire        [ 7:0]  cpu_dout, cpu_din,  ram_dout, fm_dout,
                    k60_dout /*, k39_dout,*/ /*latch_dout*/;
wire        [15:0]  A;
wire signed [15:0]  fm_l,  fm_r;
wire                m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n, nmi_n,
                    cpu_cen, sample, upper4k, cen_g, int_n, nmi_trig, nmi_clr;
reg                 ram_cs, fm_cs,  k60_cs, mem_acc,
                    mem_upper, nmi_cs;

assign int_n    = ~snd_irq;
assign nmi_trig =  sample;
assign nmi_clr  =  nmi_cs;
assign rom_addr = {1'b0,A[15:0]};
assign upper4k  = &A[15:12];
assign cpu_din  = rom_cs ? rom_data   :
                  ram_cs ? ram_dout   :
                  k60_cs ? k60_dout   :
                  fm_cs  ? fm_dout    : 8'hff;
assign cen_g    = (ram_cs | rom_cs) ? cen_4 : cen_8; // wait state for RAM/ROM access

always @(*) begin
    k60_cs    = 0;
    nmi_cs    = 0;
    mem_acc   = !mreq_n && rfsh_n;
    mem_upper = mem_acc && upper4k;
        rom_cs   = mem_acc   && !upper4k && !rd_n;
        ram_cs   = mem_upper && !A[11];      // F0xx~F7FF
        fm_cs    = mem_upper &&  A[11:9]==4; // F8xx
        k60_cs   = mem_upper &&  A[11:9]==5; // FAxx
        nmi_cs   = mem_upper &&  A[11:9]==6; // FCxx
end

jtframe_edge #(.QSET(0)) u_edge (
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( nmi_trig  ),
    .clr    ( nmi_clr   ),
    .q      ( nmi_n     )
);

/* verilator tracing_off */
jtframe_sysz80 #(`ifdef SND_RAMW .RAM_AW(`SND_RAMW), `endif .CLR_INT(1)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_g     ),
    .cpu_cen    ( cpu_cen   ),
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
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    // ROM access
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
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
    .din        ( cpu_dout  ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      (           ),
    // Low resolution output (same as real chip)
    .sample     ( sample    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

/* verilator tracing_off */
jt053260 u_k53260(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    // Main CPU interface
    .ma0        ( main_addr[1] ),
    .mrdnw      ( main_rnw  ),
    .mcs        ( 1'b1      ),
    .mdin       ( main_din  ),
    .mdout      ( main_dout ),
    // Sub CPU control
    .addr       ( A[5:0]    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .cs         ( k60_cs    ),
    .dout       ( k60_dout  ),
    .din        ( cpu_dout  ),

    // External memory - the original chip
    // only had one bus
    .roma_addr  ( pcma_addr ),
    .roma_data  ( pcma_dout ),
    .roma_cs    ( pcma_cs   ),
    // .roma_ok    ( pcma_ok   ),

    .romb_addr  ( pcmb_addr ),
    .romb_data  ( pcmb_dout ),
    .romb_cs    ( pcmb_cs   ),
    // .romb_ok    ( pcmb_ok   ),

    .romc_addr  ( pcmc_addr ),
    .romc_data  ( pcmc_dout ),
    .romc_cs    ( pcmc_cs   ),
    // .romc_ok    ( pcmc_ok   ),

    .romd_addr  ( pcmd_addr ),
    .romd_data  ( pcmd_dout ),
    .romd_cs    ( pcmd_cs   ),
    // .romd_ok    ( pcmd_ok   ),
    // sound output - raw
    .aux_l      ( fm_l      ),
    .aux_r      ( fm_r      ),
    .snd_l      ( k60_l     ),
    .snd_r      ( k60_r     ),
    .sample     (           ),
    .ch_en      (snd_en[5:1])
);
`else
assign  main_din   = 0;
assign  pcma_addr  = 0;
assign  pcma_cs    = 0;
assign  pcmb_addr  = 0;
assign  pcmb_cs    = 0;
assign  pcmc_addr  = 0;
assign  pcmc_cs    = 0;
assign  pcmd_addr  = 0;
assign  pcmd_cs    = 0;
assign  rom_addr   = 0;
initial rom_cs     = 0;
assign  { fm_l, fm_r, k60_l, k60_r } = 0;
`endif
endmodule
