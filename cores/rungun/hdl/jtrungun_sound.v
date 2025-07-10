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
    input   [ 7:0]  main_dout,
    output  [ 7:0]  pair_dout,
    input   [ 4:1]  main_addr,

    input           snd_irq,
    // ROM
    output  [16:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output   [21:0] pcma_addr, pcmb_addr,
    input    [ 7:0] pcma_data, pcmb_data,
    output          pcma_cs,   pcmb_cs,
    // Sound output
    output     signed [15:0] k539a_l, k539a_r, k539b_l, k539b_r,
    // Debug
    input    [ 7:0] debug_bus,
    output   [ 7:0] st_dout
);
wire        [ 7:0]  cpu_dout, cpu_din,  ram_dout, ctl,
                    k39a_dout, k39b_dout, latch_dout, sta_dout, stb_dout;
wire        [ 3:0]  rom_hi;
wire        [ 3:0]  bank;
wire        [15:0]  A;
wire                m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n, nmi_n,
                    cpu_cen, latch_we, tima, timb,
                    latch_intn, int_n, nmi_clr;
reg                 ram_cs, k21_cs, k39a_cs, k39b_cs, mem_acc,
                    bank_cs, wreq;

assign rom_hi   = A[15] ? bank : {3'd0, A[14]};
assign rom_addr = {rom_hi[2:0], A[13:0]};
assign nmi_clr  =~ctl[4];
assign bank     = ctl[3:0];
assign st_dout  = sta_dout;
assign latch_we = k21_cs & ~wr_n;
assign cpu_din  = rom_cs  ? rom_data   :
                  ram_cs  ? ram_dout   :
                  k39a_cs ? k39a_dout  :
                  k39b_cs ? k39b_dout  :
                  k21_cs  ? latch_dout : 8'h0;

always @(*) begin
    mem_acc = !mreq_n && rfsh_n;
    rom_cs  = mem_acc && (!A[15] || !A[14]);
    ram_cs  = mem_acc && A[15:13]==3'b110;     // Cxxx
    k39a_cs = mem_acc && A[15:10]==6'b1110_00; // E0xx
    k39b_cs = mem_acc && A[15:10]==6'b1110_01; // E4xx
    k21_cs  = mem_acc && A[15:10]==6'b1111_00; // F0xx (pair_cs on sch)
    bank_cs = mem_acc && A[15:10]==6'b1111_10; // F8xx
    wreq    = !m1_n && (!A[15] || !A[14]);
end

jtframe_8bit_reg u_reg(rst,clk,wr_n,cpu_dout,bank_cs,ctl);

jtframe_edge #(.QSET(0)) u_edge (
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( tima      ),
    .clr    ( nmi_clr   ),
    .q      ( nmi_n     )
);

jt054321 u_54321(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .maddr      ( main_addr ),
    .mdout      ( main_dout ),
    .mdin       ( pair_dout ),
    .mwe        ( pair_we   ),

    .saddr      ( A[1:0]    ),
    .sdout      ( cpu_dout  ),
    .sdin       ( latch_dout),
    .swe        ( latch_we  ),

    // Z80 bus control
    .snd_on     ( snd_irq   ),
    .siorq_n    ( iorq_n    ),
    .int_n      ( int_n     )
);
`ifndef NOSOUND
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
    .timeout    ( tima      ),
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
    .rom_data   ( pcma_data ),
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
    .timeout    ( timb      ),
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
    .rom_data   ( pcmb_data ),
    // Sound output
    .left       ( k539b_l   ),
    .right      ( k539b_r   ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( stb_dout  )
);
`else
assign k539a_l=0, k539a_r=0, k539b_l=0, k539b_r=0,
       m1_n=1, mreq_n=1, rfsh_n=1, rd_n=1, wr_n=1,A=0,
       pcma_cs=0, pcmb_cs=0;
`endif
endmodule 
