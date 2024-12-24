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
    Date: 2-12-2019 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtdd_sound(
    input           clk,        // 24 MHz
    input           rst,
    input           cen6,
    input           cen_fm,
    input           cen_fm2,
    input           H8,
    // communication with main CPU
    input           snd_irq,
    input   [ 7:0]  snd_latch,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,

    output  [15:0]  adpcm0_addr,
    output          adpcm0_cs,
    input   [ 7:0]  adpcm0_data,
    input           adpcm0_ok,

    output  [15:0]  adpcm1_addr,
    output          adpcm1_cs,
    input   [ 7:0]  adpcm1_data,
    input           adpcm1_ok,
    // Sound output
    output signed [15:0] fm_l, fm_r,
    output signed [11:0] pcm_a, pcm_b
);
`ifndef NOSOUND
wire        [ 7:0] cpu_dout, ram_dout, fm_dout;
wire        [15:0] A;
reg         [ 7:0] cpu_din;
wire               RnW, firq_n, irq_n;
reg                ram_cs, latch_cs, ad_cs, fm_cs, ad0_cs, ad1_cs;

assign rom_addr = A[14:0];

always @(*) begin
    rom_cs   = A[15];
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    ad_cs    = 1'b0;
    fm_cs    = 1'b0;
    ad0_cs   = 1'b0;
    ad1_cs   = 1'b0;
    if(!A[15]) case(A[14:11])
        4'd0: ram_cs   = 1'b1;
        4'd2: latch_cs = 1'b1;
        4'd3: ad_cs    = 1'b1;
        4'd5: fm_cs    = 1'b1;
        4'd7: if(!RnW) begin
            ad0_cs = ~A[0];
            ad1_cs =  A[0];
        end
        default:;
    endcase
end

always @(posedge clk) begin
    case(1'b1)
        rom_cs:   cpu_din <= rom_data;
        ram_cs:   cpu_din <= ram_dout;
        latch_cs: cpu_din <= snd_latch;
        fm_cs:    cpu_din <= fm_dout;
        ad_cs:    cpu_din <= {~6'h0, adpcm1_cs, adpcm0_cs};
        default:  cpu_din <= 8'hff;
    endcase
end

reg  cen_oki, last_H8, H8_edge;
wire cpu_cen;

always @(posedge clk) begin
    last_H8 <= H8;
    H8_edge <= H8 && !last_H8;
end

always @(posedge clk) begin
    cen_oki <= H8_edge;
end

jtframe_ff u_ff(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      ( 1'b0        ),    // active high
    .clr      ( latch_cs    ),    // active high
    .sigedge  ( snd_irq     ) // signal whose edge will trigger the FF
);

jtframe_sys6809 #(.RAM_AW(11),.CENDIV(0)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen6      ),    // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 1.5MHz
    .VMA        (           ),
    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( firq_n    ),
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
    .cpu_din    ( cpu_din   )
);

jt51 u_jt51(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( ~fm_cs    ), // chip select
    .wr_n       ( RnW | ~cpu_cen ), // write
    .a0         ( A[0]      ),
    .din        ( cpu_dout  ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( firq_n    ),
    // Low resolution output (same as real chip)
    .sample     (           ),
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

jtdd_adpcm u_adpcm0(
    .clk        ( clk           ),
    .rst        ( rst           ),
    .cpu_cen    ( cpu_cen       ),
    .cen_oki    ( cen_oki       ),        // 375 kHz
    // communication with main CPU
    .cpu_dout   ( cpu_dout      ),
    .cpu_AB     ( A[2:1]        ),
    .cs         ( ad0_cs        ),
    // ROM
    .rom_addr   ( adpcm0_addr   ),
    .rom_cs     ( adpcm0_cs     ),
    .rom_data   ( adpcm0_data   ),
    .rom_ok     ( adpcm0_ok     ),

    // Sound output
    .snd        ( pcm_a         ),
    .sample     (               )
);

jtdd_adpcm u_adpcm1(
    .clk        ( clk           ),
    .rst        ( rst           ),
    .cpu_cen    ( cpu_cen       ),
    .cen_oki    ( cen_oki       ),        // 375 kHz
    // communication with main CPU
    .cpu_dout   ( cpu_dout      ),
    .cpu_AB     ( A[2:1]        ),
    .cs         ( ad1_cs        ),
    // ROM
    .rom_addr   ( adpcm1_addr   ),
    .rom_cs     ( adpcm1_cs     ),
    .rom_data   ( adpcm1_data   ),
    .rom_ok     ( adpcm1_ok     ),

    // Sound output
    .snd        ( pcm_b         ),
    .sample     (               )
);

`ifdef SIMULATION
always @(negedge snd_irq) $display("INFO: sound latch %X", snd_latch );
`endif

`else // NOSOUND
assign sample      = 0;
assign sound       = 0;
assign peak        = 0;
initial rom_cs     = 0;
assign rom_addr    = 0;
assign adpcm0_cs   = 0;
assign adpcm0_addr = 0;
assign adpcm1_cs   = 0;
assign adpcm1_addr = 0;
`endif
endmodule
