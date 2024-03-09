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
    Date: 2-7-2019 */

// Note that I have kept jtcontra instead of jtcomsc
// so the module is selected in the qip but the jtcontra_game.v
// makes the same instantiation
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
    // ADPCM ROM
    output  [16:0]  pcm_addr,
    output          pcm_cs,
    input   [ 7:0]  pcm_data,
    input           pcm_ok,

    // Sound output
    output signed [15:0] fm,
    output signed [ 8:0] pcm,
    output        [ 9:0] psg,
    output        [ 7:0] st_dout
);
`ifndef NOSOUND
wire        [ 7:0]  cpu_dout, ram_dout, fm_dout, porta, pre_a, pre_b, pre_c;
wire        [15:0]  A;
reg         [ 7:0]  cpu_din, pcm_latch;
wire                m1_n, mreq_n, rd_n, wr_n, int_n, iorq_n, rfsh_n;
wire                comb_rst, busyn;
reg                 ram_cs, latch_cs, fm_cs, irq_cs, pcm_busy_cs;
reg                 pcm_rst_cs, pcm_latch_cs;
reg                 pcm_rstn, pcm_play;
wire signed [15:0]  fm_snd;
wire                cen_640, cen_320;
wire                cpu_cen, irq_ack;
reg                 pcm_play_cs;
reg                 mem_acc, mem_upper;
wire signed [ 9:0]  psg2x; // DC-removed version of psg01
wire signed [ 8:0]  pcm_snd;

assign rom_addr  = A[14:0];
assign irq_ack   = !m1_n && !iorq_n;
assign comb_rst  = ~pcm_rstn | rst;
assign st_dout   = porta;

always @(*) begin
    mem_acc  = !mreq_n && rfsh_n;
    rom_cs   = mem_acc && !A[15] && !rd_n;
    // Devices
    mem_upper   = mem_acc &&  A[15];
    ram_cs      = mem_upper && A[14:12]==3'd0; // 8xxx
    pcm_play_cs = mem_upper && A[14:12]==3'd1; // 9xxx
    pcm_latch_cs= mem_upper && A[14:12]==3'd2; // Axxx
    pcm_busy_cs = mem_upper && A[14:12]==3'd3; // Bxxx
    pcm_rst_cs  = mem_upper && A[14:12]==3'd4; // Cxxx
    latch_cs    = mem_upper && A[14:12]==3'd5; // Dxxx
    fm_cs       = mem_upper && A[14:12]==3'd6; // Exxx
end

always @(*) begin
    case(1'b1)
        rom_cs:      cpu_din = rom_data;
        ram_cs:      cpu_din = ram_dout;
        latch_cs:    cpu_din = snd_latch;
        fm_cs:       cpu_din = fm_dout;
        pcm_busy_cs: cpu_din = {7'd0, busyn };
        default:     cpu_din = 8'hff;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pcm_rstn  <= 0;
        pcm_latch <= 8'd0;
        pcm_play  <= 1;
    end else begin
        if( pcm_rst_cs && !wr_n   ) pcm_rstn  <= cpu_dout[0];
        if( pcm_latch_cs && !wr_n ) pcm_latch <= cpu_dout;
        if( pcm_play_cs && !wr_n  ) pcm_play  <= ~cpu_dout[1];
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

jtframe_sysz80 #(.RAM_AW(11),.RECOVERY(0)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm2   ), // 1.5MHz, there is a clock divider in schematics
//    .cen        ( cen_fm    ), // 3MHz, see if melody pace gets faster
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
    .rom_ok     ( rom_ok    )
);

jtframe_frac_cen u_adpcm_cen( // 640Hz
    .clk        (  clk                ), // 24 MHz
    .n          ( 10'd2               ),
    .m          ( 10'd75              ),
    .cen        ( { cen_320, cen_640 }),
    .cenb       (                     )
);

jt03 u_fm(
    .rst        ( rst        ),
    // CPU interface
    .clk        ( clk        ),
    .cen        ( cen_fm     ),
    .din        ( cpu_dout   ),
    .addr       ( A[0]       ),
    .cs_n       ( ~fm_cs     ),
    .wr_n       ( wr_n       ),
    .psg_snd    ( psg        ),
    .fm_snd     ( fm         ),
    .snd_sample (            ),
    .dout       ( fm_dout    ),
    // unused outputs
    .irq_n      (            ),
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .IOA_in     ( 8'd0       ),
    .IOB_in     ( 8'd0       ),
    .IOA_out    ( porta      ),
    .IOB_out    (            ),
    .IOA_oe     (            ),
    .IOB_oe     (            ),
    .debug_view (            ),
    .snd        (            )
);

jt7759 u_pcm(
    .rst        ( comb_rst  ),
    .clk        ( clk       ),
    .cen        ( cen_640   ),  // 640kHz
    .stn        ( pcm_play  ),  // STart (active low)
    .cs         ( 1'b1      ),
    .mdn        ( 1'b1      ),  // MODE: 1 for stand alone mode, 0 for slave mode
    .busyn      ( busyn     ),
    .wrn        ( 1'b1      ),  // for slave mode only
    .din        ( pcm_latch ),
    .rom_cs     ( pcm_cs    ),      // equivalent to DRQn in original chip
    .rom_addr   ( pcm_addr  ),
    .rom_data   ( pcm_data  ),
    .rom_ok     ( pcm_ok    ),
    .sound      ( pcm       ),
    // unused
    .drqn       (           )
);

`ifdef SIMULATION
always @(negedge snd_irq) $display("INFO: sound latch %X", snd_latch );
`endif
`else // NOSOUND
    initial rom_cs  = 0;
    assign pcm_cs   = 0;
    assign rom_addr = 0;
    assign pcm_addr = 0;
`endif
endmodule
