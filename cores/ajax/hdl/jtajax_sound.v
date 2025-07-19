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
    Date: 29-6-2025 */

module jtajax_sound(
    input           rst,
    input           clk,
    input           cen_fm,
    input           cen_fm2,
    // communication with main CPU
    input           snd_irq,
    input   [ 7:0]  snd_latch,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM - 1
    output   [17:0] pcma_addr,
    input    [ 7:0] pcma_dout,
    output          pcma_cs,
    input           pcma_ok,

    output   [17:0] pcmb_addr,
    input    [ 7:0] pcmb_dout,
    output          pcmb_cs,
    input           pcmb_ok,
    // ADPCM ROM - 2
    output   [18:0] pcm2a_addr,
    input    [ 7:0] pcm2a_dout,
    output          pcm2a_cs,
    input           pcm2a_ok,

    output   [18:0] pcm2b_addr,
    input    [ 7:0] pcm2b_dout,
    output          pcm2b_cs,
    input           pcm2b_ok,

    // Sound output
    output signed [15:0] fm_l, fm_r,
    output signed [10:0] pcm1, pcm2_l, pcm2_r,
    // Debug
    input    [ 7:0] debug_bus,
    output   [ 7:0] st_dout
);
`ifndef NOSOUND

wire        [ 7:0] cpu_dout, ram_dout, fm_dout, st_pcm1, st2_pcm;
wire        [15:0] A;
reg         [ 7:0] cpu_din;
wire               m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n;
reg                ram_cs, latch_cs, fm_cs, dac1_cs, dac2_cs, bank_cs;
wire               cpu_cen;
reg                mem_acc, mem_upper;
reg         [ 5:0] pcm_bank;
wire        [ 1:0] ct;
wire signed [10:0] pcm2_a, pcm2_b;

assign rom_addr = A[14:0];
assign st_dout  = { 2'd0, pcm_bank };

// This connection is done through the NE output
// of the 007232 on the board by using a latch
// I can simplify it here:
assign pcma_addr [   17] = pcm_bank[1];
assign pcmb_addr [   17] = pcm_bank[0];
assign pcm2a_addr[18:17] = pcm_bank[5:4];
assign pcm2b_addr[18:17] = pcm_bank[3:2];

always @(*) begin
    mem_acc  = !mreq_n && rfsh_n;
    rom_cs   = mem_acc && !A[15];
    // Devices
    mem_upper = mem_acc   && A[15];
    ram_cs    = mem_upper && A[14:12]==0;
    bank_cs   = mem_upper && A[14:12]==1;
    dac1_cs   = mem_upper && A[14:12]==2;
    dac2_cs   = mem_upper && A[14:12]==3;
    fm_cs     = mem_upper && A[14:12]==4;
    latch_cs  = mem_upper && A[14:12]==6;
end

always @(*) begin
    case(1'b1)
        rom_cs:      cpu_din = rom_data;
        ram_cs:      cpu_din = ram_dout;
        latch_cs:    cpu_din = snd_latch;
        fm_cs:       cpu_din = fm_dout;
        default:     cpu_din = 8'h0;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        pcm_bank <= 0;
    end else if( bank_cs ) begin
        pcm_bank <= cpu_dout[5:0];
    end
end

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( ~snd_irq  ),
    .nmi_n      ( 1'b1      ),
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
    .ct1        ( ct[0]     ),
    .ct2        ( ct[1]     ),
    .irq_n      (           ),
    // Low resolution output (same as real chip)
    .sample     (           ),
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);
/* verilator tracing_on */
jtajax_pcmvol u_pcm2vol(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( dac2_cs   ),
    .wr_n       ( wr_n      ),
    .addr       ( A[3:0]    ),
    .haddr      ( A[11]     ),
    .din        ( cpu_dout  ),
    .pcm_a      (pcm2_a[6:0]),
    .pcm_b      (pcm2_b[6:0]),
    .l          (pcm2_l     ),
    .r          (pcm2_r     )
);

jt007232 #(.REG12A(0)) u_pcm1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .addr       ( A[3:0]    ),
    .dacs       ( dac1_cs    ), // active high
    .cen_q      (           ),
    .cen_e      (           ),
    .wr_n       ( wr_n      ),
    .din        ( cpu_dout  ),
    .swap_gains ( 1'b1      ),

    // External memory - the original chip
    // only had one bus
    .roma_addr  ( pcma_addr[16:0] ),
    .roma_dout  ( pcma_dout ),
    .roma_cs    ( pcma_cs   ),
    .roma_ok    ( pcma_ok   ),

    .romb_addr  ( pcmb_addr[16:0] ),
    .romb_dout  ( pcmb_dout ),
    .romb_cs    ( pcmb_cs   ),
    .romb_ok    ( pcmb_ok   ),
    // sound output - raw
    .snda       (           ),
    .sndb       (           ),
    .snd        ( pcm1      ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_pcm1   )
);

jt007232 #(.REG12A(0),.NOGAIN(1)) u_pcm2(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .addr       ( A[3:0]    ),
    .dacs       ( dac2_cs    ), // active high
    .cen_q      (           ),
    .cen_e      (           ),
    .wr_n       ( wr_n      ),
    .din        ( cpu_dout  ),
    .swap_gains ( 1'b1      ),  // no effect as NOGAIN=1

    // External memory - the original chip
    // only had one bus
    .roma_addr  ( pcm2a_addr[16:0] ),
    .roma_dout  ( pcm2a_dout ),
    .roma_cs    ( pcm2a_cs   ),
    .roma_ok    ( pcm2a_ok   ),

    .romb_addr  ( pcm2b_addr[16:0] ),
    .romb_dout  ( pcm2b_dout ),
    .romb_cs    ( pcm2b_cs   ),
    .romb_ok    ( pcm2b_ok   ),
    // sound output - raw
    .snda       ( pcm2_a    ),
    .sndb       ( pcm2_b    ),
    .snd        (           ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st2_pcm   )
);
`else
initial rom_cs   = 0;
assign  pcma_cs  = 0, pcm2a_cs  = 0;
assign  pcmb_cs  = 0, pcm2b_cs  = 0;
assign  pcma_addr= 0, pcm2a_addr= 0;
assign  pcmb_addr= 0, pcm2b_addr= 0;
assign  rom_addr = 0;
assign  fm_l     = 0;
assign  fm_r     = 0;
assign  pcm1     = 0, pcm2 = 0;
assign  st_dout  = 0;
`endif
endmodule
