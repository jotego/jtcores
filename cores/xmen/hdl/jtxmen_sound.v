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

module jtxmen_sound(
    input           rst,
    input           clk,
    input           cen_8,
    input           cen_4,
    input           cen_2,
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
    output   [20:0] pcm_addr,
    input    [ 7:0] pcm_dout,
    output          pcm_cs,
    // Sound output
    output     signed [15:0] fm_l, fm_r, k539_l, k539_r,
    // Debug
    input    [ 7:0] debug_bus,
    output   [ 7:0] st_dout
);

assign main_din = 0;

`ifndef NOSOUND
wire        [ 7:0]  cpu_dout, cpu_din,  ram_dout, fm_dout,
                    k39_dout, latch_dout;
wire        [ 3:0]  rom_hi;
reg         [ 3:0]  bank;
wire        [15:0]  A;
wire                m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n, nmi_n,
                    cpu_cen, cen_g, fm_intn, latch_we, cen_fm, cen_fm2,
                    latch_intn, int_n, nmi_trig, nmi_clr, k39_we;
reg                 ram_cs, fm_cs,  k39_cs, mem_acc,
                    nmi_clrr, bank_we, k21_cs;

assign int_n    = latch_intn;
assign nmi_trig = fm_intn;
assign nmi_clr  = nmi_clrr;
assign latch_we = k21_cs && !wr_n;
assign rom_hi   = A[15]? bank : {3'd0, A[14]};
assign rom_addr = {rom_hi[2:0], A[13:0]};
assign cpu_din  = rom_cs ? rom_data   :
                  ram_cs ? ram_dout   :
                  k39_cs ? k39_dout   :
                  k21_cs ? latch_dout :
                  fm_cs  ? fm_dout    : 8'hff;
assign cen_fm   = cen_4;
assign cen_fm2  = cen_2;
assign cen_g    = (ram_cs | rom_cs) ? cen_4 : cen_8; // wait state for RAM/ROM access
// this is not 100% accurate, but quite close. It does not seem to have much of
// an effect anyway.

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank <= 0;
    end else begin
        if( bank_we ) { nmi_clrr, bank } <= cpu_dout[4:0];
    end
end

always @(*) begin
    mem_acc = !mreq_n && rfsh_n;
    rom_cs  = mem_acc && ((!A[15] && A[14]) || !A[14]) && !rd_n;
    ram_cs  = mem_acc && A[15:13]==3'b110;
    fm_cs   = mem_acc && A[15:12]==4'he &&  A[11];
    k39_cs  = mem_acc && A[15:12]==4'he && !A[11];
    k21_cs  = mem_acc && A[15:12]==4'hf && !A[11];
    bank_we = mem_acc && A[15:12]==4'hf &&  A[11] && !A[10];
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
    .irq_n      ( fm_intn   ),
    // Low resolution output (same as real chip)
    .sample     (           ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);
/* verilator tracing_on */
jt539 u_k54539(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_pcm   ),
    // CPU interface
    .addr       ({A[9],A[7:0]}),
    .we         ( ~wr_n     ),
    .rd         ( ~rd_n     ),
    .cs         ( k39_cs    ),
    .din        ( cpu_dout  ),
    .dout       ( k39_dout  ),
    // ROM
    .rom_cs     ( pcm_cs    ),
    .rom_addr   ( pcm_addr  ),
    .rom_data   ( pcm_dout  ),
    // Sound output
    .left       ( k539_l    ),
    .right      ( k539_r    ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
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
    .int_n      ( latch_intn)
);
`else
assign  main_din = 0;
assign  pcm_addr = 0;
assign  pcm_cs   = 0;
assign  rom_addr = 0;
assign  st_dout  = 0;
initial rom_cs   = 0;
assign  { pair_dout, fm_l, fm_r, k539_l, k539_r } = 0;
`endif
endmodule
