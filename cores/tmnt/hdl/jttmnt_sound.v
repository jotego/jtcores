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
    input   [ 2:0]  game_id,
    // communication with main CPU
    input   [ 7:0]  main_dout,  // bus access for Punk Shot
    output  [ 7:0]  main_din,
    input           main_addr,
    input           main_rnw,

    input           snd_irq,
    input   [ 7:0]  snd_latch,  // latch for other games
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output   [20:0] pcma_addr,
    input    [ 7:0] pcma_dout,
    output          pcma_cs,
    input           pcma_ok,

    output   [20:0] pcmb_addr,
    input    [ 7:0] pcmb_dout,
    output          pcmb_cs,
    input           pcmb_ok,

    output   [20:0] pcmc_addr,
    input    [ 7:0] pcmc_dout,
    output          pcmc_cs,
    input           pcmc_ok,

    output   [20:0] pcmd_addr,
    input    [ 7:0] pcmd_dout,
    output          pcmd_cs,
    input           pcmd_ok,
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
    output reg signed [15:0] title,
    output     signed [15:0] fm_l,  fm_r,
    output     signed [13:0] k60_l, k60_r,
    output     signed [11:0] pcm,
    output     signed [ 8:0] upd,
    // Debug
    input         [ 7:0] debug_bus,
    output        [ 7:0] st_dout
);
`ifndef NOSOUND
`include "game_id.inc"

wire        [ 7:0]  cpu_dout, ram_dout, fm_dout, st_pcm, k60_dout;
wire        [15:0]  A;
wire        [16:0]  k32a_addr, k32b_addr;
wire        [20:0]  k60a_addr, k60b_addr;
reg         [ 7:0]  cpu_din;
wire                m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n, nmi_n,
                    k60a_cs, k60b_cs, k32a_cs, k32b_cs, cpu_cen, sample;
reg                 ram_cs, latch_cs, fm_cs, dac_cs, bsy_cs, k60_cs;
reg                 mem_acc, mem_upper;
reg         [ 3:0]  pcm_bank;
wire        [ 1:0]  ct;
reg                 upd_rstn, upd_play, upd_sres, upd_vdin, upd_vst, title_rstn;
reg         [ 7:0]  upd_latch;
wire                upd_bsyn;
wire                upper4k;
reg                 upd_rst, k7232_rst, k53260_rst, k60, nmi_clr;

assign rom_addr = A[14:0];
assign title_cs = 1;
assign st_dout  = snd_latch;
assign upper4k  = &A[15:12];
assign pcma_addr = k60 ? k60a_addr : { 4'd0, k32a_addr };
assign pcmb_addr = k60 ? k60b_addr : { 4'd0, k32b_addr };
assign pcma_cs   = k60 ? k60a_cs : k32a_cs;
assign pcmb_cs   = k60 ? k60b_cs : k32b_cs;

always @(posedge clk) begin
    // keep unused chips in reset state
    if( game_id==PUNKSHOT ) begin
       k60        <= 1;
       upd_rst    <= 1;
       k7232_rst  <= 1;
       k53260_rst <= rst;
    end else begin  // 007232, Title, ADPCM
       k60        <= 0;
       upd_rst    <= ~upd_rstn | rst;
       k7232_rst  <= rst;
       k53260_rst <= 1;
    end
end

always @(*) begin
    mem_acc  = !mreq_n && rfsh_n;
    rom_cs   = mem_acc && !A[15] && !rd_n;
    // Devices
    mem_upper= mem_acc &&  A[15];
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
    k60_cs   = 0;
    nmi_clr  = 1;

    if( game_id==PUNKSHOT ) begin
        mem_upper = mem_acc &  upper4k;
        rom_cs    = mem_acc & ~upper4k;
        ram_cs    = mem_upper && A[11]==0;
        fm_cs     = mem_upper && A[11:9]==4;
        nmi_clr   = mem_upper && A[11:9]==5;
        k60_cs    = mem_upper && A[11:9]==6; // 53260
        dac_cs    = 0;
        latch_cs  = 0;
        upd_sres  = 0;
        upd_vdin  = 0;
        upd_vst   = 0;
        bsy_cs    = 0;
    end
end

jtframe_edge #(.QSET(0)) u_edge (
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( sample    ),
    .clr    ( nmi_clr   ),
    .q      ( nmi_n     )
);

always @(*) begin
    case(1'b1)
        rom_cs:      cpu_din = rom_data;
        ram_cs:      cpu_din = ram_dout;
        latch_cs:    cpu_din = snd_latch;
        k60_cs:      cpu_din = k60_dout;
        fm_cs:       cpu_din = fm_dout;
        bsy_cs:      cpu_din = { 7'h0, upd_bsyn };
        default:     cpu_din = 8'hff;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        upd_rstn   <= 0;
        upd_latch  <= 0;
        upd_play   <= 1;
        title_rstn <= 0;
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
        title      <= 0;
    end else if( cen_20 ) begin
        if( !title_rstn ) begin
            title_addr <= 0;
            title      <= 0;
        end else begin
            title_addr <= title_addr + 1'd1;
            title      <= title_raw >>> ~title_data[15:13];
        end
    end
end

/* verilator tracing_off */
jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( ~snd_irq  ),
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
    .ct1        ( ct[0]     ),
    .ct2        ( ct[1]     ),
    .irq_n      (           ),
    // Low resolution output (same as real chip)
    .sample     ( sample    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

/* verilator tracing_on */
jt053260 u_k53260(
    .rst        ( k53260_rst),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    // Main CPU interface
    .ma0        ( main_addr ),
    .mrdnw      ( main_rnw  ),
    .mcs        ( 1'b1      ),
    .mdin       ( main_din  ),
    .mdout      ( main_dout ),
    // Sub CPU control
    .addr       ( A[5:0]    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .cs         ( k60_cs    ),
    .dout       ( k60_dout  ),
    .din        ( cpu_dout  ),

    // External memory - the original chip
    // only had one bus
    .roma_addr  ( k60a_addr ),
    .roma_data  ( pcma_dout ),
    .roma_cs    ( k60a_cs   ),
    // .roma_ok    ( pcma_ok   ),

    .romb_addr  ( k60b_addr ),
    .romb_data  ( pcmb_dout ),
    .romb_cs    ( k60b_cs   ),
    // .romb_ok    ( pcmb_ok   ),

    .romc_addr  ( pcmc_addr ),
    .romc_data  ( pcmc_dout ),
    .romc_cs    ( pcmc_cs   ),
    // .romc_ok    ( pcmc_ok   ),

    .romd_addr  ( pcmd_addr ),
    .romd_data  ( pcmd_dout ),
    .romd_cs    ( pcmd_cs   ),
    // .romd_ok    ( pcmd_ok   ),
    // sound output - raw
    .snd_l      ( k60_l     ),
    .snd_r      ( k60_r     ),
    .sample     (           )
);

jt007232 u_k7232(
    .rst        ( k7232_rst ),
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
    .roma_addr  ( k32a_addr ),
    .roma_dout  ( pcma_dout ),
    .roma_cs    ( k32a_cs   ),
    .roma_ok    ( pcma_ok   ),

    .romb_addr  ( k32b_addr ),
    .romb_dout  ( pcmb_dout ),
    .romb_cs    ( k32b_cs   ),
    .romb_ok    ( pcmb_ok   ),
    // sound output - raw
    .snda       (           ),
    .sndb       (           ),
    .snd        ( pcm       ),
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
    .sound      ( upd       ),
    // unused
    .drqn       (           )
);
`else
assign  main_din   = 0;
assign  pcma_addr  = 0;
assign  pcma_cs    = 0;
assign  pcmb_addr  = 0;
assign  pcmb_cs    = 0;
assign  pcmc_addr  = 0;
assign  pcmc_cs    = 0;
assign  pcmd_addr  = 0;
assign  pcmd_cs    = 0;
assign  rom_addr   = 0;
assign  sample     = 0;
assign  st_dout    = 0;
assign  title_cs   = 0;
assign  upd_addr   = 0;
assign  upd_cs     = 0;
initial peak       = 0;
initial rom_cs     = 0;
initial snd_left   = 0;
initial snd_right  = 0;
initial title_addr = 0;
`endif
endmodule
