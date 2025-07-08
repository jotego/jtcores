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
    Date: 8-7-2025 */

module jtrungun_sound(
    input           rst,
    input           clk,
    input           cen_8,
    input           cen_pcm,

    input           pair_we,
    // communication with main CPU
    input   [ 7:0]  main_dout,  // bus access for Punk Shot
    output  [ 7:0]  main_din,
    output  [ 7:0]  pair_dout,
    input   [ 4:1]  main_addr,
    input           main_rnw,

    input           snd_irq,
    // ROM
    output  [16:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output   [21:0] pcma_addr, pcmb_addr,
    input    [ 7:0] pcma_dout, pcmb_dout,
    output          pcma_cs,   pcmb_cs,
    // Sound output
    output     signed [15:0] k539a_l, k539a_r, k539b_l, k539b_r,
    // Debug
    input    [ 7:0] debug_bus,
    output   [ 7:0] st_dout
);

assign main_din = 0;

`ifndef NOSOUND
wire        [ 7:0]  cpu_dout, cpu_din,  ram_dout, ctl,
                    k39a_dout, k39b_dout, latch_dout;
wire        [ 3:0]  rom_hi;
wire        [ 3:0]  bank;
wire        [15:0]  A;
wire                m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n, nmi_n,
                    cpu_cen, latch_we,
                    latch_intn, int_n, nmi_trig, nmi_clr;
reg                 ram_cs, fm_cs,  k39a_cs, k39b_cs, mem_acc,
                    nmi_clrr, bank_cs, wreq;

assign rom_hi   = A[15] ? bank : {3'd0, A[14]};
assign rom_addr = {rom_hi[2:0], A[13:0]};
assign nmi_clr  =~ctl[5];
assign bank     = ctl[3:0];
assign st_dout  = sta_dout;

always @(*) begin
    mem_acc = !mreq_n && rfsh_n;
    rom_cs  = mem_acc && (!A[15] || !A[14]);
    ram_cs  = mem_acc && A[15:13]==3'b110;     // Cxxx
    k39a_cs = mem_acc && A[15:10]==6'b1110_00; // E0xx
    k39b_cs = mem_acc && A[15:10]==6'b1110_01; // E4xx
    pair_cs = mem_acc && A[15:10]==6'b1111_00; // F0xx
    bank_cs = mem_acc && A[15:10]==6'b1111_10; // F8xx
    wreq    = !m1_n && (!A[15] || !A[14]);
end

jtframe_8bit_reg u_reg(rst,clk,wr_n,cpu_dout,bank_cs,ctl);

jtframe_edge #(.QSET(0)) u_edge (
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( nmi_trig  ),
    .clr    ( nmi_clr   ),
    .q      ( nmi_n     )
);

jtframe_sysz80 #(.RAM_AW(13), .CLR_INT(1)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_8     ),  // wait states ignored
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

jt539 u_k54539a(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_pcm   ),
    // CPU interface
    .addr       ({A[9],A[7:0]}),
    .we         ( ~wr_n     ),
    .rd         ( ~rd_n     ),
    .cs         ( k39a_cs   ),
    .din        ( cpu_dout  ),
    .dout       ( k39a_dout ),
    // ROM
    .rom_cs     ( pcma_cs   ),
    .rom_addr   ( pcma_addr ),
    .rom_data   ( pcma_dout ),
    // Sound output
    .left       ( k539a_l   ),
    .right      ( k539a_r   ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( sta_dout  )
);

jt539 u_k54539b(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_pcm   ),
    // CPU interface
    .addr       ({A[9],A[7:0]}),
    .we         ( ~wr_n     ),
    .rd         ( ~rd_n     ),
    .cs         ( k39b_cs   ),
    .din        ( cpu_dout  ),
    .dout       ( k39b_dout ),
    // ROM
    .rom_cs     ( pcmb_cs   ),
    .rom_addr   ( pcmb_addr ),
    .rom_data   ( pcmb_dout ),
    // Sound output
    .left       ( k539b_l   ),
    .right      ( k539b_r   ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( stb_dout  )
);
`endif
endmodule 
