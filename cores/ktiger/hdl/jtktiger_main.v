/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Twin Cobra / Flying Shark main CPU: 68000 at 7 MHz (10 MHz on export
 * Twin Cobra boards).
 *
 *   000000-02FFFF  ROM
 *   030000-03FFFF  work RAM, shared with the DSP
 *   040000-04FFFF  sprite RAM, shared with the DSP
 *   050000-05FFFF  palette RAM, shared with the DSP
 *   060000-06FFFF  CRTC, 6800 bus cycle
 *   070000-076005  scroll and tile map pointer registers
 *   078000-079FFF  inputs, coin latch 07800B, main latch 07800D
 *   07A000-07BFFF  sound CPU RAM, low byte, through the Z80 bus request
 *   07E000-07FFFF  tile map data at the pointers
 */
module jtktiger_main(
    input             rst,
    input             clk,
    input             LVBL,
    input             VS,
    input             tcobr,
    input             fast,

    output     [17:1] rom_addr,
    input      [15:0] rom_data,
    output reg        rom_cs,
    input             rom_ok,

    output            dsp_on,
    output            dsp_rstn,
    output            snd_rstn,
    input             dsp_br,
    output            dsp_ack,
    input      [13:1] dsp_addr,
    input      [ 1:0] dsp_sel,
    input      [15:0] dsp_dout,
    output     [15:0] dsp_din,
    input             dsp_we,

    output     [13:1] sh_addr,
    output     [15:0] sh_din,
    output     [ 1:0] work_bwe,
    output     [ 1:0] obj_bwe,
    output     [ 1:0] pal_bwe,
    input      [15:0] work_dout,
    input      [15:0] objram_dout,
    input      [15:0] palram_dout,

    output     [10:0] mshr_addr,
    output     [ 7:0] mshr_din,
    output            mshr_we,
    input      [ 7:0] shared_dout,
    output            snd_busrq_n,
    input             snd_busak_n,

    output reg [ 2:0] scr_cs,
    output reg [ 2:0] scr_addr,
    output reg [ 7:0] scr_din,
    input      [15:0] txoffs,
    input      [15:0] bgoffs,
    input      [15:0] fgoffs,
    output            flip,
    output            bg_bank,
    output            fg_bank,
    output            video_on,

    output     [10:0] tx_a,
    output     [12:0] bg_a,
    output     [11:0] fg_a,
    output     [ 1:0] tx_bwe,
    output     [ 1:0] bg_bwe,
    output     [ 1:0] fg_bwe,
    input      [15:0] txram_dout,
    input      [15:0] bgram_dout,
    input      [15:0] fgram_dout,

    output     [15:0] cpu_dout,
    output     [ 7:0] sys,

    input      [15:0] dipsw,
    input      [ 5:0] joystick1,
    input      [ 5:0] joystick2,
    input      [ 1:0] cab_1p,
    input      [ 1:0] coin,
    input             service,
    input             tilt,
    input             dip_test,
    input             dip_pause
);

localparam integer MHZ = `JTFRAME_MCLK/1000000;

wire [23:1] A;
wire [ 2:0] FC;
wire        cpu_cen, cpu_cenb, UDSn, LDSn, RnW, ASn, VPAn, DTACKn, BUSn, irq_n,
            BRn, BGn, BGACKn;
wire        rom_ok_dly, bus_busy, cab_we, scr_wr;
wire [ 1:0] dsn, cpu_bwe, lyr;
wire [ 6:0] cab_sys;
reg  [15:0] cpu_din, cab_dout;
reg  [ 7:0] coin_ctl, mlatch;
reg         work_cs, obj_cs, pal_cs, shr_cs, cab_cs, vram_cs, scr_l, hi_pend;

assign rom_addr  = A[17:1];
assign dsn       = {UDSn, LDSn};
assign BUSn      = ASn | (&dsn);
assign VPAn      = ~(~ASn & ((&FC) | A[18:16]==3'd6));
assign bus_busy  = (rom_cs & ~rom_ok_dly) | (shr_cs & snd_busak_n);
assign snd_busrq_n = ~shr_cs;
assign cpu_bwe   = {2{~RnW}} & ~dsn;
assign cab_we    = cab_cs & ~RnW & ~LDSn;
assign scr_wr    = ~BUSn & ~RnW & A[18:15]==4'b1110 & A[12:3]==0 & A[2:1]!=2'd3 & A[14:13]!=2'd3;
assign lyr       = A[14:13];
assign cab_sys   = ~{ cab_1p[1], cab_1p[0], coin[1], coin[0], dip_test, tilt, service };
assign sys       = tcobr ? {1'b0, cab_sys} : 8'd0;

assign dsp_on    = tcobr ? mlatch[6] : coin_ctl[0];
assign dsp_rstn  = mlatch[0];
assign snd_rstn  = mlatch[1];
assign dsp_ack   = ~BGACKn;
assign flip      = mlatch[3];
assign bg_bank   = mlatch[4];
assign fg_bank   = mlatch[5] & tcobr;
assign video_on  = mlatch[7];

assign sh_addr   = dsp_ack ? dsp_addr : A[13:1];
assign sh_din    = dsp_ack ? dsp_dout : cpu_dout;
assign work_bwe  = dsp_ack ? {2{dsp_we && dsp_sel==2'd0}} : {2{work_cs}} & cpu_bwe;
assign obj_bwe   = dsp_ack ? {2{dsp_we && dsp_sel==2'd1}} : {2{obj_cs }} & cpu_bwe;
assign pal_bwe   = dsp_ack ? {2{dsp_we && dsp_sel==2'd2}} : {2{pal_cs }} & cpu_bwe;
assign dsp_din   = dsp_sel==2'd0 ? work_dout   :
                   dsp_sel==2'd1 ? objram_dout :
                   dsp_sel==2'd2 ? palram_dout : 16'd0;

assign mshr_addr = A[11:1];
assign mshr_din  = cpu_dout[7:0];
assign mshr_we   = shr_cs & ~RnW & ~LDSn & ~snd_busak_n;

assign tx_a      = txoffs[10:0];
assign bg_a      = {bg_bank, bgoffs[11:0]};
assign fg_a      = fgoffs[11:0];
assign tx_bwe    = {2{vram_cs && A[2:1]==2'd0}} & cpu_bwe;
assign bg_bwe    = {2{vram_cs && A[2:1]==2'd1}} & cpu_bwe;
assign fg_bwe    = {2{vram_cs && A[2:1]==2'd2}} & cpu_bwe;

always @* begin
    rom_cs  = !ASn  && A[18:16] < 3'd3;
    work_cs = !BUSn && A[18:16] == 3'd3;
    obj_cs  = !BUSn && A[18:16] == 3'd4;
    pal_cs  = !BUSn && A[18:16] == 3'd5;
    cab_cs  = !BUSn && A[18:13] == 6'h3c;
    shr_cs  = !BUSn && A[18:13] == 6'h3d;
    vram_cs = !BUSn && A[18:13] == 6'h3f;
end

always @(posedge clk) begin
    case( A[3:1] )
        3'd0:    cab_dout <= {8'd0, dipsw[ 7:0]};
        3'd1:    cab_dout <= {8'd0, dipsw[15:8]};
        3'd2:    cab_dout <= {8'd0, ~{2'b11, joystick1}};
        3'd3:    cab_dout <= {8'd0, ~{2'b11, joystick2}};
        3'd4:    cab_dout <= {8'd0, ~LVBL, cab_sys};
        default: cab_dout <= 16'd0;
    endcase
    cpu_din <= rom_cs  ? rom_data    :
               work_cs ? work_dout   :
               obj_cs  ? objram_dout :
               pal_cs  ? palram_dout :
               shr_cs  ? {8'd0, shared_dout} :
               vram_cs ? (A[2:1]==2'd0 ? txram_dout :
                          A[2:1]==2'd1 ? bgram_dout : fgram_dout) :
               cab_cs  ? cab_dout    : 16'd0;
end

// LS259 latches at 07800B and 07800D
always @(posedge clk) begin
    if( rst ) begin
        coin_ctl <= 0;
        mlatch   <= 0;
    end else if( cab_we ) begin
        if( A[3:1]==3'd5 ) coin_ctl[cpu_dout[3:1]] <= cpu_dout[0];
        if( A[3:1]==3'd6 ) mlatch[cpu_dout[3:1]]   <= cpu_dout[0];
    end
end

// scroll registers, low byte first
always @(posedge clk) begin
    if( rst ) begin
        scr_l   <= 0;
        hi_pend <= 0;
        scr_cs  <= 0;
    end else begin
        scr_l  <= scr_wr;
        scr_cs <= 0;
        if( scr_wr && !scr_l ) begin
            scr_cs[lyr] <= ~LDSn;
            scr_addr    <= {A[2:1], 1'b0};
            scr_din     <= cpu_dout[7:0];
            hi_pend     <= ~UDSn;
        end else if( hi_pend ) begin
            scr_cs[lyr] <= 1;
            scr_addr    <= {A[2:1], 1'b1};
            scr_din     <= cpu_dout[15:8];
            hi_pend     <= 0;
        end
    end
end

jtframe_edge #(.QSET(0)) u_irq(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( VS        ),
    .clr        ( ~mlatch[2]),
    .q          ( irq_n     )
);

jtframe_okdly u_okdly(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( rom_cs    ),
    .ok         ( rom_ok    ),
    .ok_dly     ( rom_ok_dly)
);

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( rom_cs | shr_cs ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( shr_cs    ),
    .bus_ack    ( dsp_ack   ),
    .ASn        ( ASn       ),
    .DSn        ( dsn       ),
    .num        ( fast ? 7'd10 : 7'd7 ),
    .den        ( MHZ[7:0]  ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .DTACKn     ( DTACKn    ),
    .fave       (           ),
    .fworst     (           )
);

jtframe_68kdma u_dma(
    .clk        ( clk       ),
    .rst        ( rst       ),
    .cen        ( cpu_cen   ),
    .cpu_BRn    ( BRn       ),
    .cpu_BGACKn ( BGACKn    ),
    .cpu_BGn    ( BGn       ),
    .cpu_ASn    ( ASn       ),
    .cpu_DTACKn ( DTACKn    ),
    .dev_br     ( dsp_br    )
);

jtframe_m68k u_cpu(
    .clk        ( clk       ),
    .rst        ( rst       ),
    .RESETn     (           ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .eab        ( A         ),
    .iEdb       ( cpu_din   ),
    .oEdb       ( cpu_dout  ),
    .eRWn       ( RnW       ),
    .LDSn       ( LDSn      ),
    .UDSn       ( UDSn      ),
    .ASn        ( ASn       ),
    .VPAn       ( VPAn      ),
    .FC         ( FC        ),
    .BERRn      ( 1'b1      ),
    .HALTn      ( dip_pause ),
    .BRn        ( BRn       ),
    .BGACKn     ( BGACKn    ),
    .BGn        ( BGn       ),
    .DTACKn     ( DTACKn    ),
    .IPLn       ( {irq_n, 2'b11} )
);

endmodule
