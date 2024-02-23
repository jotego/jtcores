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

module jtdd2_sound(
    input           clk,
    input           rst,
    input           H8,
    input           cen_snd,
    input           cen_fm,
    input           cen_fm2,
    input           cen_oki,
    // communication with main CPU
    input           snd_irq,
    input   [ 7:0]  snd_latch,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,

    output  [17:0]  adpcm_addr,
    output          adpcm_cs,
    input   [ 7:0]  adpcm_data,
    input           adpcm_ok,

    // Sound output
    output     signed [15:0] sound,
    output                   sample,
    output                   peak
);
`ifndef NOSOUND
wire [ 7:0] cpu_dout, ram_dout, fm_dout, oki_dout;
wire [15:0] A;
reg  [ 7:0] cpu_din;
wire        wr_n, int_n, nmi_n;
wire signed [13:0] adpcm_snd;
wire signed [15:0] fm_left, fm_right;
reg ram_cs, latch_cs, oki_cs, fm_cs;
wire oki_wrn = oki_cs & ~wr_n;
assign rom_addr = A[14:0];

wire mreq_n;

localparam [7:0] FMGAIN  = 8'h10,
                 PCMGAIN = 8'h10;

jtframe_mixer #(.W0(16),.W1(16),.W2(14),.W3(14), .WOUT(16)) u_mixer(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .cen    ( cen_fm2       ),
    // input signals
    .ch0    ( fm_left       ),
    .ch1    ( fm_right      ),
    .ch2    ( adpcm_snd     ),
    .ch3    ( adpcm_snd     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( FMGAIN        ),
    .gain1  ( FMGAIN        ),
    .gain2  ( PCMGAIN       ),
    .gain3  ( PCMGAIN       ),
    .mixed  ( sound         ),
    .peak   ( peak          )
);

always @(*) begin
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    fm_cs    = 1'b0;
    oki_cs   = 1'b0;
    rom_cs   = 1'b0;
    if(!mreq_n) begin
        if(A[15]) begin
            case(A[14:11])
                4'b0000: ram_cs   = 1'b1; // 8000-87ff
                4'b0001: fm_cs    = 1'b1; // 8800-8801
                4'b0011: oki_cs   = 1'b1; // 9800
                4'b0100: latch_cs = 1'b1; // a000
                default:;
            endcase
        end
        else rom_cs = 1'b1;
    end
end

always @(*) begin
    case(1'b1)
        rom_cs:   cpu_din = rom_data;
        ram_cs:   cpu_din = ram_dout;
        latch_cs: cpu_din = snd_latch;
        fm_cs:    cpu_din = fm_dout;
        oki_cs:   cpu_din = oki_dout;
        default:  cpu_din = 8'hff;
    endcase
end

jtframe_ff u_ff(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( nmi_n       ),
    .set      ( 1'b0        ),    // active high
    .clr      ( latch_cs    ),    // active high
    .sigedge  ( snd_irq     ) // signal whose edge will trigger the FF
);

jtframe_sysz80 #(.RAM_AW(11),.RECOVERY(0)) u_cpu(
    .rst_n      ( ~rst          ),
    .clk        ( clk           ),
    .cen        ( cen_snd       ),
    .cpu_cen    (               ),
    .int_n      ( int_n         ),
    .nmi_n      ( nmi_n         ),
    .busrq_n    ( 1'b1          ),
    .m1_n       (               ),
    .mreq_n     ( mreq_n        ),
    .iorq_n     (               ),
    .rd_n       (               ),
    .wr_n       ( wr_n          ),
    .rfsh_n     (               ),
    .halt_n     (               ),
    .busak_n    (               ),
    .A          ( A             ),
    .cpu_din    ( cpu_din       ),
    .cpu_dout   ( cpu_dout      ),
    .ram_dout   ( ram_dout      ),
    .ram_cs     ( ram_cs        ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        )
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
    .irq_n      ( int_n     ),
    // Low resolution output (same as real chip)
    .sample     ( sample    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_left   ),
    .xright     ( fm_right  )
);

assign adpcm_cs = 1'b1;

jt6295 #(.INTERPOL(2)) u_adpcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_oki   ),
    .ss         ( 1'b1      ),
    // CPU interface
    .wrn        ( oki_wrn   ),  // active low
    .din        ( cpu_dout  ),
    .dout       ( oki_dout  ),
    // ROM interface
    .rom_addr   ( adpcm_addr),
    .rom_data   ( adpcm_data),
    .rom_ok     ( adpcm_ok  ),
    // Sound output
    .sample     (           ),
    .sound      ( adpcm_snd )
);
`else // NOSOUND
assign sample     = 0;
assign sound      = 0;
assign peak       = 0;
initial rom_cs    = 0;
assign rom_addr   = 0;
assign adpcm_cs   = 0;
assign adpcm_addr = 0;
`endif
endmodule
