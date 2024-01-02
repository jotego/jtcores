`timescale 1ns / 1ps
//`default_nettype none

// A35T

//    This file is part of the ZXUNO Spectrum core.
//    Creation date is 21:14:58 2023-05-01 by Miguel Angel Rodriguez Jodar
//    (c)2014-2020 ZXUNO association.
//    ZXUNO official repository: http://svn.zxuno.com/svn/zxuno
//    Username: guest   Password: zxuno
//    Github repository for this core: https://github.com/mcleod-ideafix/zxuno_spectrum_core
//
//    ZXUNO Spectrum core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    ZXUNO Spectrum core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with the ZXUNO Spectrum core.  If not, see <https://www.gnu.org/licenses/>.
//
//    Any distributed copy of this file must keep this notice intact.
//
// ORIGINAL COPYRIGHT FOLLOWS:
// Author: Mike Field <hamster@snap.net.nz>
//
// Part of the DisplayPort_Verlog project - an open implementation of the 
// DisplayPort protocol for FPGA boards. 
//
// See https://github.com/hamsternz/DisplayPort_Verilog for latest versions.
//
///////////////////////////////////////////////////////////////////////////////
// Version |  Notes
// ----------------------------------------------------------------------------
//   1.0   | Initial Release
//
///////////////////////////////////////////////////////////////////////////////
//
// MIT License
// 
// Copyright (c) 2019 Mike Field
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
///////////////////////////////////////////////////////////////////////////////
//
// Want to say thanks?
//
// This design has taken many hours - 3 months of work for the initial VHDL
// design, and another month or so to convert it to Verilog for this release.
//
// I'm more than happy to share it if you can make use of it. It is released
// under the MIT license, so you are not under any onus to say thanks, but....
//
// If you what to say thanks for this design either drop me an email, or how about
// trying PayPal to my email (hamster@snap.net.nz)?
//
//  Educational use - Enough for a beer
//  Hobbyist use    - Enough for a pizza
//  Research use    - Enough to take the family out to dinner
//  Commercial use  - A weeks pay for an engineer (I wish!)
//
///////////////////////////////////////////////////////////////////////////////

module zxtres_wrapper (
  input  wire        clkvideo,
  input  wire        enclkvideo,
  input  wire        clkpalntsc,
  input  wire        reset_n,
  input  wire        reboot_fpga,
  //////////////////////////////////////////
  input  wire [20:0] sram_addr_in,
  input  wire        sram_we_n_in,
  input  wire        sram_oe_n_in,
  input  wire [7:0]  sram_data_to_chip,
  output wire [7:0]  sram_data_from_chip,
  //----------------------------------------
  output wire [19:0] sram_addr_out,
  output wire        sram_we_n_out,
  output wire        sram_oe_n_out,
  output wire        sram_ub_n_out,
  output wire        sram_lb_n_out,
  inout  wire [15:0] sram_data,
  output wire        poweron_reset,
  output wire        config_vga_on,
  output wire        config_scanlines_off,
  //////////////////////////////////////////
  input  wire        video_output_sel,
  input  wire        disable_scanlines,
  input  wire [1:0]  monochrome_sel,
  input  wire        interlaced_image,
  input  wire        ad724_modo,
  input  wire        ad724_clken,
  //////////////////////////////////////////
  input  wire [7:0]  ri,
  input  wire [7:0]  gi,
  input  wire [7:0]  bi,
  input  wire        hsync_ext_n,
  input  wire        vsync_ext_n,
  input  wire        csync_ext_n,
  //////////////////////////////////////////
  input  wire [15:0] audio_l,
  input  wire [15:0] audio_r,
  //////////////////////////////////////////
  output reg [7:0]   ro,
  output reg [7:0]   go,
  output reg [7:0]   bo,
  output reg         hsync,
  output reg         vsync,
  //////////////////////////////////////////
  output wire        sd_audio_l,
  output wire        sd_audio_r,
  output wire        i2s_bclk,
  output wire        i2s_lrclk,
  output wire        i2s_dout,
  //////////////////////////////////////////
  input  wire        joy_data,
  input  wire        joy_latch_megadrive,
  output wire        joy_clk,
  output wire        joy_load_n,
  output wire        joy1up,
  output wire        joy1down,
  output wire        joy1left,
  output wire        joy1right,
  output wire        joy1fire1,
  output wire        joy1fire2,
  output wire        joy1fire3,
  output wire        joy1start,
  output wire        joy2up,
  output wire        joy2down,
  output wire        joy2left,
  output wire        joy2right,
  output wire        joy2fire1,
  output wire        joy2fire2,
  output wire        joy2fire3,
  output wire        joy2start,
  //////////////////////////////////////////
  output wire        dp_tx_lane_p,
  output wire        dp_tx_lane_n,
  input  wire        dp_refclk_p,
  input  wire        dp_refclk_n,
  input  wire        dp_tx_hp_detect,
  inout  wire        dp_tx_auxch_tx_p,
  inout  wire        dp_tx_auxch_tx_n,
  inout  wire        dp_tx_auxch_rx_p,
  inout  wire        dp_tx_auxch_rx_n,
  ///////////////////////////////////////////
  output wire        dp_ready,
  output wire        dp_heartbeat
  );

  parameter [10:0] HSTART = 0;
  parameter [10:0] VSTART = 0;
  parameter [26:0] CLKVIDEO = 25;
  parameter INITIAL_FIELD = 0;   // no usado en realidad

  wire [18:0] ar, aw;
  wire we;
  wire [7:0] ro_vga, go_vga, bo_vga;
  wire [7:0] rpal, gpal, bpal;
  wire [7:0] rfb, gfb, bfb;
  wire [7:0] rdim, gdim, bdim;
  wire [7:0] riproc, giproc, biproc;
  wire [7:0] rvgaproc, gvgaproc, bvgaproc;
  wire [7:0] rfinal, gfinal, bfinal;
  wire hsync_vga, vsync_vga;
  wire [10:0] hcont, vcont, hcont_vga, vcont_vga;
  wire aplicar_scanline, campoparimpar_pal;
  wire clkcolor4x;

  wire      refclk0, odiv2_0;

  wire       tx_powerup_channel;

  wire       preemp_0p0;
  wire       preemp_3p5;
  wire       preemp_6p0;

  wire       swing_0p4;
  wire       swing_0p6;
  wire       swing_0p8;

  wire       tx_running;

  wire        tx_symbol_clk;
  wire [79:0] tx_symbols;
  wire clkr = tx_symbol_clk;

  wire        tx_align_train;
  wire        tx_clock_train;
  wire        tx_link_established;

  assign dp_ready = tx_link_established;

  wire  [2:0] stream_channel_count;
  wire [72:0] msa_merged_data;
  wire        test_signal_ready;
  wire        present;

  wire auxch_in;
  wire auxch_out;
  wire auxch_tri;

  reg [25:0] rheartb = 26'b0;
  always @(posedge tx_symbol_clk)
    rheartb <= rheartb + 26'd1;
  assign dp_heartbeat = rheartb[25];

  return_to_core1 reset_total (
    .clk(tx_symbol_clk),
    .boot_core(reboot_fpga)
  );

  config_retriever modo_video_inicial (
    .clk(clkvideo),
    .sram_addr_in(sram_addr_in),
    .sram_we_n_in(sram_we_n_in),
    .sram_oe_n_in(sram_oe_n_in),
    .sram_data_from_chip(sram_data_from_chip),
    .sram_data_to_chip(sram_data_to_chip),
    .sram_addr_out(sram_addr_out),
    .sram_we_n_out(sram_we_n_out),
    .sram_oe_n_out(sram_oe_n_out),
    .sram_ub_n_out(sram_ub_n_out),
    .sram_lb_n_out(sram_lb_n_out),
    .sram_data(sram_data),
    .pwon_reset(poweron_reset),
    .vga_on(config_vga_on),
    .scanlines_off(config_scanlines_off)
  );

  gencolorclk reloj_color (
    .clk(clkpalntsc),
    .en(ad724_clken),
    .mode(ad724_modo),
    .clkcolor4x(clkcolor4x) // (17.734475 MHz PAL ? 14.31818 MHz NTSC)
  );

  gen_hvconts contadores (
    .clk(clkvideo),
    .clken(enclkvideo),
    .reset_n(reset_n),
    .hs_n(hsync_ext_n),
    .vs_n(vsync_ext_n),
    .hcont(hcont),
    .vcont(vcont)
  );

  video_producer #(.HSTART(HSTART), .VSTART(VSTART), .INITIAL_FIELD(INITIAL_FIELD)) genframes (
    .clk(clkvideo),
    .clken(enclkvideo),
    .interlaced_image(interlaced_image),
    .hc(hcont),
    .vc(vcont),
    .field(campoparimpar_pal),
    .aw(aw),
    .we(we)
  );

  wire [7:0] dp0, dp1, dp2, dp3, dp4, dp5, dp6,
           dp7, dp8, dp9, dpA, dpB, dpC;
  wire [7:0] ri_d, gi_d, bi_d;

`ifdef DEBUG_DISPLAYPORT_AUX_CHANNEL
////////////////////////////////////////////////////////////////////////////
  debug visor_digitos (
    .clk(clkvideo),
    .clken(enclkvideo),
    .rst_n(reset_n),
    .visible(1'b1),
    .hc(hcont),
    .vc(vcont),
    .ri(ri),
    .gi(gi),
    .bi(bi),
    .ro(ri_d),
    .go(gi_d),
    .bo(bi_d),
    //////////////////////////
    .v8_0(dp0),
    .v8_1(dp1),
    .v8_2(dp2),
    .v8_3(dp3),
    .v8_4(dp4),
    .v8_5(dp5),
    .v8_6(dp6),
    .v8_7(dp7),
    .v8_8(dp8),
    .v8_9(dp9),
    .v8_a(dpA),
    .v8_b(dpB),
    .v8_c(dpC),
    .v8_d(0),
    .v8_e(0),
    .v8_f(0)
    );
`else
////////////////////////////////////////////////////////////////////////////
  assign ri_d = ri;
  assign gi_d = gi;
  assign bi_d = bi;
`endif
////////////////////////////////////////////////////////////////////////////

  monochrome efecto_mono_pal (monochrome_sel, ri_d, gi_d, bi_d, riproc, giproc, biproc);

  dp_memory fbuffer (
    .campoparimpar_pal(campoparimpar_pal),
    .lineaparimpar_vga(vcont_vga[0]),
    .interlaced_image(interlaced_image),
    .clkw(clkvideo),
    .aw(aw),
    .rin(ri_d),
    .gin(gi_d),
    .bin(bi_d),
    .we(we),
    .clkr(clkr),
    .ar(ar),
    .rout(rfb),
    .gout(gfb),
    .bout(bfb)
  );

  monochrome efecto_mono_vga (monochrome_sel, rfb, gfb, bfb, rvgaproc, gvgaproc, bvgaproc);

  color_dimmed rdimmer (rvgaproc, rdim);
  color_dimmed gdimmer (gvgaproc, gdim);
  color_dimmed bdimmer (bvgaproc, bdim);

  assign rfinal = (aplicar_scanline == 1 && disable_scanlines == 0)? rdim : rvgaproc;
  assign gfinal = (aplicar_scanline == 1 && disable_scanlines == 0)? gdim : gvgaproc;
  assign bfinal = (aplicar_scanline == 1 && disable_scanlines == 0)? bdim : bvgaproc;

  reg [1:0] divvga = 0;
  always @(posedge tx_symbol_clk) begin
    if (divvga == 2)
      divvga <= 0;
    else
      divvga <= divvga + 1;
  end

  vga_consumer genvideo (
    .clk(tx_symbol_clk),
    .clken(divvga == 2),
    .hcont(hcont_vga),
    .vcont(vcont_vga),
    .ri(rfinal),
    .gi(gfinal),
    .bi(bfinal),
    .ro(ro_vga),
    .go(go_vga),
    .bo(bo_vga),
    .hs(hsync_vga),
    .vs(vsync_vga)
  );

  always @* begin
    if (video_output_sel == 1'b0) begin // 15kHz + DP output
      ro = riproc;   // esta salida depende exclusivamente de
      go = giproc;   // como est\E9 codificado el color en el
      bo = biproc;   // video original
      hsync = csync_ext_n;
      vsync = clkcolor4x;
    end
    else begin  // VGA output + DP output
      ro = ro_vga;
      go = go_vga;
      bo = bo_vga;
      hsync = hsync_vga;
      vsync = vsync_vga;
    end
  end

//////////////////////////////////////////////////////

  sigma_delta_codec sdcodec (
    .clk(tx_symbol_clk),
    .audio_l(audio_l),
    .audio_r(audio_r),
    .sd_audio_l(sd_audio_l),
    .sd_audio_r(sd_audio_r)
  );

  i2s_sound #(.CLKMHZ(81)) i2scodec (
    .clk(tx_symbol_clk),
    .audio_l(audio_l),
    .audio_r(audio_r),
    .i2s_bclk(i2s_bclk),
    .i2s_lrclk(i2s_lrclk),
    .i2s_dout(i2s_dout)
  );

//////////////////////////////////////////////////////

  joydecoder decodificador_joysticks (
    .clk(clkvideo),
    .joy_data(joy_data),
    .joy_latch_megadrive(1'b1),
    .joy_clk(joy_clk),
    .joy_load_n(joy_load_n),
    .joy1up(joy1up),
    .joy1down(joy1down),
    .joy1left(joy1left),
    .joy1right(joy1right),
    .joy1fire1(joy1fire1),
    .joy1fire2(joy1fire2),
    .joy1fire3(joy1fire3),
    .joy1start(),
    .joy2up(joy2up),
    .joy2down(joy2down),
    .joy2left(joy2left),
    .joy2right(joy2right),
    .joy2fire1(joy2fire1),
    .joy2fire2(joy2fire2),
    .joy2fire3(),
    .joy2start()
  );

///////////////////////////////////////////////////
// Refclock buffers
///////////////////////////////////////////////////
IBUFDS_GTE2  ibufds_gte2_0 ( 
        .O               (refclk0),
        .ODIV2           (odiv2_0),      
        .CEB             (1'b0),
        .I               (dp_refclk_p),
        .IB              (dp_refclk_n)
    );

//IBUFDS_GTE2  ibufds_gte2_1 (
//        .O               (refclk1),
//        .ODIV2           (odiv2_1),
//        .CEB             (1'b0),
//        .I               (mgtrefclk1_p),
//        .IB              (mgtrefclk1_n)
//    );
///////////////////////////////////////////////////
// Aux channel interface 
///////////////////////////////////////////////////
wire auxch_in_ignore = 1'b0;
IOBUFDS #(
          .DIFF_TERM("FALSE"),     // Differential Termination ("TRUE"/"FALSE")
          .IBUF_LOW_PWR("TRUE"),   // Low Power - "TRUE", High Performance = "FALSE" 
          .IOSTANDARD("DEFAULT"), // Specify the I/O standard
          .SLEW("SLOW")            // Specify the output slew rate
       ) i_IOBUFDS_1 (
          .O   (auxch_in),         // Buffer output
          .IO  (dp_tx_auxch_rx_p),   // Diff_p inout (connect directly to top-level port)
          .IOB (dp_tx_auxch_rx_n),  // Diff_n inout (connect directly to top-level port)
          .I   (auxch_in_ignore),    // Buffer input
          .T   (1'b1)        // 3-state enableie input, high=input, low=output
      );

wire auxch_out_ignore;
IOBUFDS #(
          .DIFF_TERM("FALSE"),     // Differential Termination ("TRUE"/"FALSE")
          .IBUF_LOW_PWR("TRUE"),   // Low Power - "TRUE", High Performance = "FALSE" 
          .IOSTANDARD("DEFAULT"), // Specify the I/O standard
          .SLEW("SLOW")            // Specify the output slew rate
       ) i_IOBUFDS_2 (
          .O   (auxch_out_ignore),         // Buffer output
          .IO  (dp_tx_auxch_tx_p),  // Diff_p inout (connect directly to top-level port)
          .IOB (dp_tx_auxch_tx_n),  // Diff_n inout (connect directly to top-level port)
          .I   (auxch_out),              // Buffer input
          .T   (auxch_tri)               // 3-state enable input, high=input, low=output
      );
///////////////////////////////////////////////////
// Video pipeline
///////////////////////////////////////////////////
dp_consumer gendp (
        .clk                  (tx_symbol_clk),
        .stream_channel_count (stream_channel_count),
        .ready                (test_signal_ready),
        .fbaddr               (ar),
        .divvga               (divvga),
        .hcont                (hcont_vga),
        .vcont                (vcont_vga),
        .aplicar_scanline     (aplicar_scanline),
        .interlaced_image     (interlaced_image),
        .red                  (rfinal),
        .green                (gfinal),
        .blue                 (bfinal),
        .data                 (msa_merged_data)
    );
main_stream_processing i_main_stream_processing(
        .symbol_clk          (tx_symbol_clk),
        .tx_link_established (tx_link_established),
        .source_ready        (test_signal_ready),
        .tx_clock_train      (tx_clock_train),
        .tx_align_train      (tx_align_train),
        .audio_l             (audio_l),
        .audio_r             (audio_r),
        .in_data             (msa_merged_data),
        .tx_symbols          (tx_symbols)
    );

////////////////////////////////////////////////
// Transceivers 
///////////////////////////////////////////////
transceiver_bank  #(.CLKPERMICROSECOND(CLKVIDEO))i_transciever_bank(
    .mgmt_clk        (clkvideo),

    ///////////////////////////////
    // Master control
    ///////////////////////////////
    .powerup_channel (1'b1/*tx_powerup_channel*/),
 
    ///////////////////////////////
    // Output signal control
    ///////////////////////////////
    .preemp_0p0      (preemp_0p0),
    .preemp_3p5      (preemp_3p5),
    .preemp_6p0      (preemp_6p0),

    .swing_0p4       (swing_0p4),
    .swing_0p6       (swing_0p6),
    .swing_0p8       (swing_0p8),

    ///////////////////////////////
    // Status feedback
    ///////////////////////////////
    .tx_running      (tx_running),

    ///////////////////////////////
    // Reference clocks
    ///////////////////////////////
    .refclk0       (refclk0),
    .refclk1       (1'b0),

    ///////////////////////////////
    // Symbols to transmit
    ///////////////////////////////
    .tx_symbol_clk   (tx_symbol_clk),
    .tx_symbols      (tx_symbols),

    .gtptx_p         (dp_tx_lane_p),
    .gtptx_n         (dp_tx_lane_n)
);

reg reset_dp_training_n = 1'b0;
reg [19:0] contwait = 0;
always @(posedge clkvideo) begin  
  if (contwait == 20'hFFFFF)
    reset_dp_training_n <= 1'b1;
  else if (reset_n == 1'b0)
    contwait <= 0;
  else
    contwait <= contwait + 1;
end

channel_management #(.CLKPERMICROSECOND(CLKVIDEO)) i_channel_management(
        .sysclk               (clkvideo),
        .reset_n              (reset_dp_training_n),
        .hpd                  (dp_tx_hp_detect),
        .present              (present),
        .auxch_in             (auxch_in),
        .auxch_out            (auxch_out),
        .auxch_tri            (auxch_tri),
        .stream_channel_count (stream_channel_count),
        .source_channel_count (3'b001),
        .tx_clock_train       (tx_clock_train),
        .tx_align_train       (tx_align_train),
        .tx_powerup_channel   (tx_powerup_channel),
        .tx_preemp_0p0        (preemp_0p0),
        .tx_preemp_3p5        (preemp_3p5),
        .tx_preemp_6p0        (preemp_6p0),
        .tx_swing_0p4         (swing_0p4),
        .tx_swing_0p6         (swing_0p6),
        .tx_swing_0p8         (swing_0p8),
        .tx_running           (tx_running),
        .tx_link_established  (tx_link_established),

        .debug_dp_addr0       (dp0),
        .debug_dp_addr1       (dp1),
        .debug_dp_addr2       (dp2),
        .debug_dp_addr3       (dp3),
        .debug_dp_addr4       (dp4),
        .debug_dp_addr5       (dp5),
        .debug_dp_addr6       (dp6),
        .debug_dp_addr7       (dp7),
        .debug_dp_addr8       (dp8),
        .debug_dp_addr9       (dp9),
        .debug_dp_addrA       (dpA),
        .debug_dp_addrB       (dpB),
        .debug_dp_addrC       (dpC)
    );

endmodule

module vga_consumer (
  input wire clk,
  input wire clken,
  input wire [10:0] hcont,
  input wire [10:0] vcont,
  input wire [7:0] ri,
  input wire [7:0] gi,
  input wire [7:0] bi,
  output reg [7:0] ro,
  output reg [7:0] go,
  output reg [7:0] bo,
  output reg hs,
  output reg vs
  );

   // 800x600@50Hz,28MHz
//   localparam htotal = 896;
//   localparam vtotal = 625;
//   localparam hactive = 800;
//   localparam vactive = 600;
//   localparam hfrontporch = 24;
//   localparam hsyncpulse = 40;
//   localparam vfrontporch = 4;
//   localparam vsyncpulse = 3;
//   localparam hsyncpolarity = 0;
//   localparam vsyncpolarity = 0;

   // 704x576@50Hz,28MHz
//	  localparam htotal = 896;
//   localparam vtotal = 625;
//   localparam hactive = 704;
//   localparam vactive = 576;
//   localparam hfrontporch = 56;
//   localparam hsyncpulse = 80;
//   localparam vfrontporch = 23;
//   localparam vsyncpulse = 3;
//   localparam hsyncpolarity = 0;
//   localparam vsyncpolarity = 0;

   // VGA 640x480@60Hz,25MHz
 localparam htotal = 800;
 localparam vtotal = 525;
 localparam hactive = 640;
 localparam vactive = 480;
 localparam hfrontporch = 16;
 localparam hsyncpulse = 96;
 localparam vfrontporch = 11;
 localparam vsyncpulse = 2;
 localparam hsyncpolarity = 0;
 localparam vsyncpolarity = 0;

 reg active_area;

 always @* begin
   if (hcont>=0 && hcont<hactive && vcont>=0 && vcont<vactive)
     active_area = 1'b1;
   else
     active_area = 1'b0;
   if (hcont>=(hactive+hfrontporch) && hcont<(hactive+hfrontporch+hsyncpulse))
     hs = hsyncpolarity;
   else
     hs = ~hsyncpolarity;
   if (vcont>=(vactive+vfrontporch) && vcont<(vactive+vfrontporch+vsyncpulse))
     vs = vsyncpolarity;
   else
     vs = ~vsyncpolarity;
	end

  always @* begin
    if (active_area) begin
			ro = ri;
      go = gi;
      bo = bi;
    end
    else begin
      ro = 8'h00;
      go = 8'h00;
      bo = 8'h00;
    end
  end
endmodule

module dp_memory (
  input  wire campoparimpar_pal,
  input  wire lineaparimpar_vga,
  input  wire interlaced_image,
  input  wire clkw,
  input  wire [18:0] aw,
  input  wire [7:0] rin,
  input  wire [7:0] gin,
  input  wire [7:0] bin,
  input  wire we,
  input  wire clkr,
  input  wire [18:0] ar,
  output wire [7:0] rout,
  output wire [7:0] gout,
  output wire [7:0] bout
  );

  reg [8:0] fb [0:640*240-1];  // 640*240 pixeles
  reg [8:0] dout;

  assign rout = {dout[8:6], dout[8:6], dout[8:7]};
  assign gout = {dout[5:3], dout[5:3], dout[5:4]};
  assign bout = {dout[2:0], dout[2:0], dout[2:1]};

  always @(posedge clkw) begin
    if (we == 1'b1) begin
      fb[aw] <= {rin[7:5],gin[7:5],bin[7:5]};
    end
  end

  always @(posedge clkr) begin
    dout <= fb[ar];
  end

endmodule

module video_producer (
  input wire clk,
  input wire clken,
  input wire interlaced_image,
  input wire [10:0] hc,
  input wire [10:0] vc,
  output reg [18:0] aw,
  output reg field,
  output reg we
  );

  parameter [10:0] HSTART = 0;
  parameter [10:0] VSTART = 0;
  parameter INITIAL_FIELD = 0;

  initial aw = 'h00000;

  initial field = INITIAL_FIELD;
  wire in_framebuffer_area = (hc>=HSTART && hc<(HSTART+640) && vc>=VSTART && vc<(VSTART+240) );

  always @* begin
    if (in_framebuffer_area)
      we = 1'b1;
    else
      we = 1'b0;
  end

  always @(posedge clk) begin
    if (clken) begin
      if (in_framebuffer_area) begin
          aw <= aw + 1;
      end
      else if (vc==VSTART && hc == HSTART-1) begin
        aw <= 19'd0;
        field <= ~field;
      end
    end
  end

endmodule

module color_dimmed (
  input wire [7:0] in,
  output reg [7:0] out // out is scaled to 75% of in
  );

  always @* begin
    out = {1'b0,in[7:1]} + {2'b00,in[7:2]};  // out = 0.75*in
  end
endmodule

//`default_nettype wire
