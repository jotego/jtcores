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
    Date: 1-2-2023 */

module jtcastle_sound(
    input           clk,        // 24 MHz
    input           rst,
    // communication with main CPU
    input           snd_irq,
    input   [ 7:0]  snd_latch,
    input   [ 7:0]  debug_bus,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output   [18:0] pcma_addr,
    input    [ 7:0] pcma_data,
    output          pcma_cs,
    input           pcma_ok,

    output   [18:0] pcmb_addr,
    input    [ 7:0] pcmb_data,
    output          pcmb_cs,
    input           pcmb_ok,

    // Sound output
    output signed [15:0] fm,
    output signed [11:0] pcm_a, pcm_b, scc
);
`ifndef NOSOUND
wire        [ 7:0]  cpu_dout, ram_dout, fm_dout, scc_dout;
wire        [15:0]  A;
reg         [ 7:0]  cpu_din;
reg         [ 3:0]  banks;
wire                m1_n, mreq_n, rd_n, wr_n, int_n, nmi_n, iorq_n, rfsh_n;
reg                 ram_cs, latch_cs, fm_cs, scc_cs, dac_cs, bank_cs;
wire                cen_fm2,     // 1.8 MHz
                    cen_fm,     //  3.6 MHz
                    cen2_fm,    //  7.2 MHz
                    cen4_fm;    // 14.3 MHz
wire                cpu_cen, irq_ack;
reg                 mem_acc, mem_upper;
wire        [ 7:0]  div_dout;

assign rom_addr  = A[14:0];
assign irq_ack   = !m1_n && !iorq_n;
// assign fm_gain  = 8'h08;
// assign scc_gain = 8'h06;
// assign pcm_gain = fxgain;

// This connection is done through the NE output
// of the 007232 on the board by using a latch
// and a mux. I can simplify it here:
assign pcma_addr[18:17] = banks[1:0];
assign pcmb_addr[18:17] = banks[3:2];

jtframe_frac_cen #(.W(4),.WC(12)) u_cen(
    .clk        ( clk       ),  // 24 MHz
    .n          ( 12'd0735  ),  // 0.01% error
    .m          ( 12'd2464  ),
    .cen        ( {cen_fm2, cen_fm, cen2_fm, cen4_fm } ),
    .cenb       (           )
);

always @(*) begin
    mem_acc  = !mreq_n && rfsh_n;
    rom_cs   = mem_acc && !A[15] && !rd_n;
    // Devices
    mem_upper = mem_acc && A[15];
    ram_cs    = mem_upper && A[14:12]==0; // 8xxx
    scc_cs    = mem_upper && A[14:12]==1; // 9xxx - 051649
    fm_cs     = mem_upper && A[14:12]==2; // Axxx
    dac_cs    = mem_upper && A[14:12]==3; // Bxxx
    bank_cs   = mem_upper && A[14:12]==4; // Cxxx
    latch_cs  = mem_upper && A[14:12]==5; // Dxxx

end

always @(*) begin
    case(1'b1)
        rom_cs:      cpu_din = rom_data;
        ram_cs:      cpu_din = ram_dout;
        scc_cs:      cpu_din = scc_dout;
        latch_cs:    cpu_din = snd_latch;
        fm_cs:       cpu_din = fm_dout;
        default:     cpu_din = 8'hff;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        banks <= 0;
    end else begin
        if( bank_cs ) banks <= cpu_dout[3:0];
    end
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

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
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
jtopl2 u_opl(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .addr       ( A[0]      ),
    .din        ( cpu_dout  ), // data in
    .dout       ( fm_dout   ), // data out
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( wr_n      ), // write
    .irq_n      ( nmi_n     ),
    // combined output
    .snd        ( fm        ),
    .sample     (           )  // marks new output sample
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

    // External memory - the original chip
    // only had one bus
    .roma_addr  ( pcma_addr[16:0] ),
    .roma_dout  ( pcma_data ),
    .roma_cs    ( pcma_cs   ),
    .roma_ok    ( pcma_ok   ),

    .romb_addr  ( pcmb_addr[16:0] ),
    .romb_dout  ( pcmb_data ),
    .romb_cs    ( pcmb_cs   ),
    .romb_ok    ( pcmb_ok   ),
    // sound output
    .snda       ( pcm_a     ),
    .sndb       ( pcm_b     ),
    .snd        (           ),
    .swap_gains ( 1'b0      ),
    // debug
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);
/* verilator tracing_on */
jt051649 u_scc(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen4       ( cen4_fm   ),
    .cs         ( scc_cs    ),
    .wrn        ( wr_n      ),
    .addr       ( {4'b1001, A[11:0] }), // bits 10-8 ignored
    .din        ( cpu_dout  ),
    .dout       ( scc_dout  ),
    .snd        ( scc   )
);

`else
initial rom_cs    = 0;
assign  pcma_cs   = 0;
assign  pcma_addr = 0;
assign  pcmb_cs   = 0;
assign  pcmb_addr = 0;
assign  rom_addr  = 0;
assign  snd       = 0;
assign  peak      = 0;
assign  sample    = 0;
`endif
endmodule
