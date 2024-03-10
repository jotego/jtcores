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
    Date: 6-5-2023 */

module jtsimson_sound(
    input           rst,
    input           clk,
    input           cen_fm,
    input           cen_fm2,
    input           simson,

    // communication with main CPU
    input           snd_irq,
    input   [ 7:0]  main_dout,
    output  [ 7:0]  main_din,
    input           main_addr,
    input           main_rnw,
    input           mono,
    // ROM
    output   [16:0] rom_addr,
    output reg      rom_cs,
    input    [ 7:0] rom_data,
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
    // Sound output
    output signed [15:0] fm_l,  fm_r,
    output signed [13:0] pcm_l, pcm_r,
    // Debug
    input    [ 7:0] debug_bus,
    output   [ 7:0] st_dout
);
`ifndef NOSOUND
localparam  [ 7:0]  FMGAIN=8'h08;

wire        [ 7:0]  cpu_dout, ram_dout, fm_dout, st_pcm, pcm_dout;
wire        [15:0]  A;
reg         [ 7:0]  cpu_din;
wire                m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n,
                    peak_l, peak_r, nmi_n;
reg                 ram_cs, latch_cs, fm_cs, pcm_cs, bank_cs;
wire                cpu_cen, sample;
reg                 mem_acc, af, nmi_clr;
reg         [ 2:0]  bank;
reg         [ 3:0]  pcm_msb;

assign rom_addr = simson ? { A[15] ? bank : { 2'd0, A[14] }, A[13:0] } : {1'd0,A[15:0]};
assign st_dout  = fm_dout;

always @(*) begin
    mem_acc  = !mreq_n && rfsh_n;
    af       = A[15:12]==4'hf;
    rom_cs   = mem_acc && !af;
    ram_cs   = mem_acc &&  af && !A[11];
    bank_cs  = 0;
    nmi_clr  = 0;
    fm_cs    = 0;
    pcm_cs   = 0;
    if( mem_acc && af ) case(A[11:9])
        4: fm_cs   = 1;
        5: nmi_clr = 1;
        6: pcm_cs  = 1;
        7: bank_cs = simson;     // unused in Parodius
        default:;
    endcase
end

always @(*) begin
    case(1'b1)
        rom_cs:  cpu_din = rom_data;
        ram_cs:  cpu_din = ram_dout;
        pcm_cs:  cpu_din = pcm_dout;
        fm_cs:   cpu_din = fm_dout;
        default: cpu_din = 8'hff;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank   <= 0;
    end else begin
        if( bank_cs ) bank <= cpu_dout[2:0];
    end
end
/* verilator tracing_off */
jtframe_edge #(.QSET(0)) u_edge (
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( sample    ),
    .clr    ( nmi_clr   ),
    .q      ( nmi_n     )
);

/* verilator tracing_on */
jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( ~snd_irq  ),
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
    .sample     ( sample    ),
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);
/* verilator tracing_off */
jt053260 u_pcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    // Main CPU interface
    .ma0        ( main_addr ),
    .mrdnw      ( main_rnw  ),
    .mcs        ( 1'b1      ),
    .mdin       ( main_din  ),
    .mdout      ( main_dout ),
    // Sub CPU control
    .addr       ( A[5:0]    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .cs         ( pcm_cs    ),
    .dout       ( pcm_dout  ),
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
    .snd_l      ( pcm_l     ),
    .snd_r      ( pcm_r     ),
    .sample     (           )
);
`else
initial rom_cs   = 0;
assign  pcma_cs  = 0, pcmb_cs=0, pcmc_cs=0, pcmd_cs=0;
assign  pcma_addr= 0, pcmb_addr=0, pcmc_addr=0, pcmd_addr=0;
assign  rom_addr = 0;
assign  snd_l    = 0;
assign  snd_r    = 0;
initial peak     = 0;
assign  sample   = 0;
assign  st_dout  = 0;
assign  main_din = 0;
`endif
endmodule
