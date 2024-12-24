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
    Date: 22-8-2021 */

module jtmx5k_sound(
    input           clk,        // 24 MHz
    input           rst,
    input           cen_fm,
    input           cen_fm2,
    // communication with main CPU
    input           snd_irq,
    input   [ 7:0]  snd_latch,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    // ADPCM ROM
    output   [17:0] pcma_addr,
    input    [ 7:0] pcma_dout,
    output          pcma_cs,
    input           pcma_ok,

    output   [17:0] pcmb_addr,
    input    [ 7:0] pcmb_dout,
    output          pcmb_cs,
    input           pcmb_ok,

    // Sound output
    output signed [15:0] fm_l, fm_r,
    output signed [11:0] pcm
);
`ifndef NOSOUND
wire        [ 7:0]  cpu_dout, ram_dout, fm_dout;
wire        [15:0]  A;
reg         [ 7:0]  cpu_din;
wire                m1_n, mreq_n, rd_n, wr_n, int_n, iorq_n, rfsh_n;
reg                 ram_cs, latch_cs, fm_cs, div_cs, dac_cs, iock;
wire                cpu_cen, irq_ack;
reg                 mem_acc, mem_upper;
wire        [ 7:0]  div_dout;

assign rom_addr  = A[14:0];
assign irq_ack   = !m1_n && !iorq_n;

// This connection is done through the NE output
// of the 007232 on the board by using a latch
// I can simplify it here:
assign pcma_addr[17] = 0;
assign pcmb_addr[17] = 1;

always @(*) begin
    mem_acc  = !mreq_n && rfsh_n;
    rom_cs   = mem_acc && !A[15] && !rd_n;
    // Devices
    mem_upper = mem_acc && A[15];
    // the schematics show an IOCK output which
    // isn't connected on the real PCB
    ram_cs    = mem_upper && A[14:12]==0; // 8xxx
    div_cs    = mem_upper && A[14:12]==1; // 9xxx
    latch_cs  = mem_upper && A[14:12]==2; // Axxx
    dac_cs    = mem_upper && A[14:12]==3; // Bxxx
    fm_cs     = mem_upper && A[14:12]==4; // Cxxx
end

always @(*) begin
    case(1'b1)
        rom_cs:      cpu_din = rom_data;
        ram_cs:      cpu_din = ram_dout;
        div_cs:      cpu_din = div_dout;
        latch_cs:    cpu_din = snd_latch;
        fm_cs:       cpu_din = fm_dout;
        default:     cpu_din = 8'hff;
    endcase
end

jtframe_ff u_ff(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( int_n       ),
    .set      ( 1'b0        ),    // active high
    .clr      ( irq_ack     ),    // active high
    .sigedge  ( snd_irq     ) // signal whose edge will trigger the FF
);

jtcontra_007452 u_div(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cs     ( div_cs & cpu_cen ),
    .wrn    ( wr_n      ),
    .addr   ( A[2:0]    ),
    .din    ( cpu_dout  ),
    .dout   ( div_dout  )
);

jtframe_sysz80 #(.RAM_AW(11),.RECOVERY(0)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( int_n     ),
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
    .rom_ok     ( 1'b1      )
);

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
    .sample     (           ),
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

jt007232 u_pcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .addr       ( A[3:0]    ),
    .dacs       ( dac_cs    ), // active high
    .cen_q      (           ),
    .cen_e      (           ),
    .wr_n       ( wr_n      ),
    .din        ( cpu_dout  ),
    .swap_gains ( 1'b0      ),

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
    .snd        ( pcm       ),
    // debug
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);
`else
initial rom_cs   = 0;
assign  pcma_cs  = 0;
assign  pcmb_cs  = 0;
assign  rom_addr = 15'd0;
assign  pcm      = 0;
assign  fm_l     = 0;
assign  fm_r     = 0;
`endif
endmodule
