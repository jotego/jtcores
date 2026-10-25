/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
`ifdef SPLIT_INTERLACED
`define JTFRAME_SPLIT_VIDEO
`define JTFRAME_INTERLACED
`endif
module test;
reg clk=0;always #5 clk=~clk;
reg [15:0] cfg=0;
reg vga_force_scaler=0;
`include "cfg_route.vh"
wire [7:0] VGA_R,VGA_G,VGA_B,SCALER_R,SCALER_G,SCALER_B;
wire VGA_HS,VGA_VS,VGA_DE,VGA_F1,CE_PIXEL,CLK_VIDEO;
wire SCALER_CE,SCALER_HS,SCALER_VS,SCALER_DE,SCALER_F1;
wire [1:0] VGA_SL;
`include "emu_route.vh"
// Progressive scan2x source has deliberately different tags from the analog bus.
source u_scan(
`include "scan_ports.vh"
 .unused(1'b0));
wire clk_vid=clk;
wire [23:0] vga_data_sl={VGA_R,VGA_G,VGA_B};
wire vga_ce_sl=CE_PIXEL,vga_hs_sl=VGA_HS,vga_vs_sl=VGA_VS,vga_de_sl=VGA_DE,f1=VGA_F1;
wire ce_hpix,hhs_fix,hvs_fix,hde_emu;
wire [7:0] hr_out,hg_out,hb_out;
`include "sys_route.vh"
`ifdef JTFRAME_SPLIT_VIDEO
assign sc_r=SCALER_R;assign sc_g=SCALER_G;assign sc_b=SCALER_B;
assign sc_ce=SCALER_CE;assign sc_hs=SCALER_HS;assign sc_vs=SCALER_VS;
assign sc_de=SCALER_DE;assign sc_f1=SCALER_F1;
`ifdef JTFRAME_INTERLACED
assign field=1;
`endif
assign split_r=8'hc1;assign split_g=8'h72;assign split_b=8'h23;
assign split_hs=1;assign split_vs=0;assign split_de=1;assign split_ce=0;assign split_field=1;
`endif
reg component=0;
wire [23:0] analog_out;
wire ah,av,ac,ad;
vga_out u_format(.clk(clk),.ypbpr_en(component),.hsync(VGA_HS),.vsync(VGA_VS),.csync(1'b0),.de(VGA_DE),.din(vga_data_sl),.dout(analog_out),.hsync_o(ah),.vsync_o(av),.csync_o(ac),.de_o(ad));
integer n;
initial begin
 repeat(8)@(negedge clk);
 for(n=0;n<16;n=n+1)begin
  cfg[12]=n[0];cfg[2]=n[1];cfg[10]=n[2];vga_force_scaler=n[3];#1;
`ifdef JTFRAME_SPLIT_VIDEO
  if(vga_fb!==0||vga_scaler!==0)$fatal(1,"split analog scaler override");
  if({VGA_R,VGA_G,VGA_B,VGA_HS,VGA_VS,VGA_DE,CE_PIXEL,VGA_F1}!=={24'hc17223,5'b10101})$fatal(1,"analog bundle");
`ifdef JTFRAME_INTERLACED
  if(SCALER_F1!==1||VGA_SL!==0)$fatal(1,"interlaced scaler field/analog scanlines");
`else
  if(SCALER_F1!==0||VGA_SL!==0)$fatal(1,"progressive field/analog scanlines");
`endif
  if(cfg[10])begin
   if({hr_out,hg_out,hb_out,hhs_fix,hvs_fix,ce_hpix,hde_emu,hf1}!=={24'hc17223,5'b10011})$fatal(1,"direct video analog select");
  end else begin
`ifdef JTFRAME_INTERLACED
   if({hr_out,hg_out,hb_out,hhs_fix,hvs_fix,ce_hpix,hde_emu,hf1}!=={24'h123456,5'b01111})$fatal(1,"HDMI interlaced select");
`else
   if({hr_out,hg_out,hb_out,hhs_fix,hvs_fix,ce_hpix,hde_emu,hf1}!=={24'h123456,5'b01110})$fatal(1,"HDMI progressive select");
`endif
  end
`else
  if(vga_fb!==(cfg[12]|vga_force_scaler)||vga_scaler!==(cfg[2]|vga_force_scaler))$fatal(1,"legacy config");
  if({hr_out,hg_out,hb_out,hhs_fix,hvs_fix,ce_hpix,hde_emu}!=={24'h123456,4'b0111})$fatal(1,"legacy video");
`endif
 end
 cfg=0;repeat(5)@(negedge clk);
 if(analog_out!==vga_data_sl)$fatal(1,"RGB analog format");
 component=1;#1;
 if(analog_out===vga_data_sl||(^analog_out)===1'bx)$fatal(1,"component conversion");
 if({ah,av,ad}!=={VGA_HS,VGA_VS,VGA_DE})$fatal(1,"component sync/de latency");
 $display("PASS");$finish;
end
initial begin #10000;$fatal(1,"routing timeout");end
endmodule
module source(output [7:0] scan2x_r,scan2x_g,scan2x_b,output scan2x_hs,scan2x_vs,scan2x_clk,scan2x_cen,scan2x_de,output [1:0] scan2x_sl,input unused);
assign {scan2x_r,scan2x_g,scan2x_b}=24'h123456;
assign {scan2x_hs,scan2x_vs,scan2x_clk,scan2x_cen,scan2x_de,scan2x_sl}=7'b0101110;
endmodule
