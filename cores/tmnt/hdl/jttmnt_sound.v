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
    Date: 6-5-2023 */

module jttmnt_sound(
    input           rst,
    input           clk,
    input           cen_fm,
    input           cen_fm2,
    input           cen_640,
    input           cen_20,
    // communication with main CPU
    input           snd_irq,
    input   [ 7:0]  snd_latch,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output   [16:0] pcma_addr,
    input    [ 7:0] pcma_dout,
    output          pcma_cs,
    input           pcma_ok,

    output   [16:0] pcmb_addr,
    input    [ 7:0] pcmb_dout,
    output          pcmb_cs,
    input           pcmb_ok,
    // UPD ADPCM ROM
    output  [16:0]  upd_addr,
    output          upd_cs,
    input   [ 7:0]  upd_data,
    input           upd_ok,
    // Title theme
    input    [15:0] title_data,
    output          title_cs,
    output reg [18:1] title_addr,
    input           title_ok,

    // Sound output
    output signed [15:0] snd,
    output               sample,
    output               peak,
    // Debug
    input      [7:0] debug_bus,
    output reg [7:0] st_dout
);
`ifndef NOSOUND

reg         [ 7:0]  fmgain, pcmgain, updgain, title_gain;
wire        [ 7:0]  cpu_dout, ram_dout, fm_dout, st_pcm;
wire        [15:0]  A;
reg         [ 7:0]  cpu_din;
wire                m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n;
reg                 ram_cs, latch_cs, fm_cs, dac_cs, bsy_cs;
wire signed [15:0]  fm_left, fm_right;
wire signed [16:0]  fm_mono;
wire signed [ 8:0]  upd_snd;
wire                cpu_cen;
reg                 mem_acc, mem_upper;
reg         [ 3:0]  pcm_bank;
wire signed [11:0]  pcm_snd;
wire        [ 1:0]  ct;
reg                 upd_rstn, upd_play, upd_sres, upd_vdin, upd_vst, title_rstn;
reg         [ 7:0]  upd_latch;
wire                upd_rst, upd_bsyn;
reg signed  [15:0]  title_snd; // bit 0 is always discarded
wire signed [15:0]  snd_mix;

assign upd_rst  = ~upd_rstn | rst;

assign rom_addr = A[14:0];
assign title_cs = 1;
assign fm_mono  = fm_left+fm_right;

always @(*) begin
    case( debug_bus[5:4])
        2: st_dout = snd[7:0];
        3: st_dout = snd[15:8];
        default: st_dout = snd_latch;
    endcase
end

always @(*) begin
    mem_acc  = !mreq_n && rfsh_n;
    rom_cs   = mem_acc && !A[15] && !rd_n;
    // Devices
    mem_upper = mem_acc && A[15];
    // the schematics show an IOCK output which
    // isn't connected on the real PCB
    ram_cs   = mem_upper && A[14:12]==0; // 8xxx
    upd_sres = mem_upper && A[14:12]==1; // 9xxx
    latch_cs = mem_upper && A[14:12]==2; // Axxx
    dac_cs   = mem_upper && A[14:12]==3; // Bxxx
    fm_cs    = mem_upper && A[14:12]==4; // Cxxx
    upd_vdin = mem_upper && A[14:12]==5; // Dxxx
    upd_vst  = mem_upper && A[14:12]==6; // Exxx
    bsy_cs   = mem_upper && A[14:12]==7; // Fxxx
end

always @(*) begin
    case(1'b1)
        rom_cs:      cpu_din = rom_data;
        ram_cs:      cpu_din = ram_dout;
        latch_cs:    cpu_din = snd_latch;
        fm_cs:       cpu_din = fm_dout;
        bsy_cs:      cpu_din = { 7'h0, upd_bsyn };
        default:     cpu_din = 8'hff;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        upd_rstn  <= 0;
        upd_latch <= 0;
        upd_play  <= 1;
    end else begin
        if( upd_sres && !wr_n ) { title_rstn, upd_rstn } <= cpu_dout[2:1];
        if( upd_vdin && !wr_n ) upd_latch <= cpu_dout;
        if( upd_vst  && !wr_n ) upd_play  <= ~cpu_dout[0];
    end
end

wire signed [15:0] title_raw = { ~title_data[12], title_data[11:3], 6'd0 };

// Title screen music
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        title_addr <= 0;
        title_snd  <= 0;
    end else if( cen_20 ) begin
        if( !title_rstn ) begin
            title_addr <= 0;
            title_snd  <= 0;
        end else begin
            title_addr <= title_addr + 1'd1;
            title_snd  <= title_raw >>> ~title_data[15:13];
        end
    end
end

// `ifdef JTFRAME_RELEASE
initial begin
    fmgain     = 8'h0c; // music
    pcmgain    = 8'h04; // percussion
    updgain    = 8'h02; // voices (fire! hang on April)
    title_gain = 8'h02; // theme song
end
// `else
// always @(posedge clk, posedge rst) begin
//     fmgain     <= 8'h01 << debug_bus[7:6];
//     updgain    <= 8'h01 << debug_bus[5:4];
//     pcmgain    <= 8'h01 << debug_bus[3:2];
//     title_gain <= 8'h01 << debug_bus[1:0];
// end
// `endif

assign snd = debug_bus[2:0] == 0 ? snd_mix :
             debug_bus[2:0] == 1 ? fm_mono[16:1] :
             debug_bus[2:0] == 2 ? {pcm_snd,4'd0} :
             debug_bus[2:0] == 3 ? {upd_snd,7'd0} : title_snd;

/* verilator tracing_on */
jtframe_mixer #(.W0(16),.W1(12),.W2(9),.W3(16)) u_mixer(
    .rst    ( rst        ),
    .clk    ( clk        ),
    .cen    ( cen_fm     ),
    .ch0    (fm_mono[16:1]),
    .ch1    ( pcm_snd    ),
    .ch2    ( upd_snd    ),
    .ch3    ( title_snd  ),
    .gain0  ( 8'h0A ), //fmgain     ),
    .gain1  ( 8'h02 ), //pcmgain    ),
    .gain2  ( 8'h02 ), //updgain    ),
    .gain3  ( 8'h02 ), //title_gain ),
    .mixed  ( snd_mix    ),
    .peak   ( peak       )
);

/* verilator tracing_off */
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
    .sample     ( sample    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_left   ),
    .xright     ( fm_right  )
);

/* verilator tracing_on */
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
    .roma_addr  ( pcma_addr ),
    .roma_dout  ( pcma_dout ),
    .roma_cs    ( pcma_cs   ),
    .roma_ok    ( pcma_ok   ),

    .romb_addr  ( pcmb_addr ),
    .romb_dout  ( pcmb_dout ),
    .romb_cs    ( pcmb_cs   ),
    .romb_ok    ( pcmb_ok   ),
    // sound output - raw
    .snda       (           ),
    .sndb       (           ),
    .snd        ( pcm_snd   ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_pcm    )
);
/* verilator tracing_off */
jt7759 u_upd(
    .rst        ( upd_rst   ),
    .clk        ( clk       ),
    .cen        ( cen_640   ),  // 640kHz
    .stn        ( upd_play  ),  // STart (active low)
    .cs         ( 1'b1      ),
    .mdn        ( 1'b1      ),  // MODE: 1 for stand alone mode, 0 for slave mode
    .busyn      ( upd_bsyn  ),
    .wrn        ( 1'b1      ),  // for slave mode only
    .din        ( upd_latch ),
    .rom_cs     ( upd_cs    ),  // equivalent to DRQn in original chip
    .rom_addr   ( upd_addr  ),
    .rom_data   ( upd_data  ),
    .rom_ok     ( upd_ok    ),
    .sound      ( upd_snd   ),
    // unused
    .drqn       (           )
);

`else
initial rom_cs     = 0;
initial title_addr = 0;
assign  title_cs   = 0;
assign  pcma_cs    = 0;
assign  pcmb_cs    = 0;
assign  upd_cs     = 0;
assign  pcma_addr  = 0;
assign  pcmb_addr  = 0;
assign  upd_addr   = 0;
assign  rom_addr   = 0;
assign  snd        = 0;
assign  peak       = 0;
assign  sample     = 0;
initial st_dout    = 0;
`endif
endmodule
