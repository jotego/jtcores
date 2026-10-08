/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-12-2019 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtcontra_sound(
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
    input           rom_ok,
    // ADPCM ROM - not used
    output  [16:0]  pcm_addr,
    output          pcm_cs,
    input   [ 7:0]  pcm_data,
    input           pcm_ok,
    // Sound output
    output signed [15:0] fm_l,
    output signed [15:0] fm_r,
    output        [ 7:0] st_dout
);

assign pcm_addr = 0;
assign pcm_cs   = 0;
assign st_dout  = 0;

`ifndef NOSOUND
wire [ 7:0] cpu_dout, ram_dout, fm_dout;
wire [15:0] A;
reg  [ 7:0] cpu_din;
wire        RnW, irq_n;
reg         ram_cs, latch_cs, fm_cs, irq_cs;

wire signed [15:0] xleft, xright;

assign rom_addr  = A[14:0];

wire cpu_cen;

always @(*) begin
    rom_cs   = A[15];
    latch_cs = !A[15] && A[14:13]==2'b00 && RnW;
    fm_cs    = !A[15] && A[14:13]==2'b01;
    irq_cs   = !A[15] && A[14:13]==2'b10 && !RnW;
    ram_cs   = !A[15] && A[14:13]==2'b11;
end

always @(posedge clk) begin
    case(1'b1)
        rom_cs:   cpu_din <= rom_data;
        ram_cs:   cpu_din <= ram_dout;
        latch_cs: cpu_din <= snd_latch;
        fm_cs:    cpu_din <= fm_dout;
        default:  cpu_din <= 8'hff;
    endcase
end


jtframe_ff u_ff(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      ( 1'b0        ),    // active high
    .clr      ( irq_cs      ),    // active high
    .sigedge  ( snd_irq     ) // signal whose edge will trigger the FF
);

jtframe_sys6809 #(.RAM_AW(11),.CENDIV(0)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm2   ),   // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 3MHz

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    .irq_ack    (           ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    // memory interface
    .A          ( A         ),
    .RnW        ( RnW       ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // Bus multiplexer is external
    .ram_dout   ( ram_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   ),
    .VMA        (           )
);

jt51 u_jt51(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( RnW | ~cpu_cen ), // write
    .a0         ( A[0]      ),
    .din        ( cpu_dout  ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      (           ),
    // Low resolution output (same as real chip)
    .sample     (           ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

`ifdef SIMULATION
always @(negedge snd_irq) $display("INFO: sound latch %X", snd_latch );
`endif
`else // NOSOUND
    initial rom_cs   = 0;
    assign  rom_addr = 0;
`endif
endmodule
