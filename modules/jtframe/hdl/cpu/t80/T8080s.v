// Generated from the T80 VHDL sources with GHDL 4.1.0.
// ghdl -a -fsynopsys -fexplicit T80_ALU.vhd T80_Reg.vhd T80_MCode.vhd T80.vhd T80s.vhd
// ghdl --synth --out=verilog -fsynopsys -fexplicit -gMode=2 T80s
// The modules use 8080-specific names so this file can be loaded with T80s.v.

// Copyright (c) 2018 Sorgelig
//  Test passed: ZEXDOC, ZEXALL, Z80Full(*), Z80memptr
//  (*) Currently only SCF and CCF instructions aren't passed X/Y flags check as
//      correct implementation is still unclear.
//
// ****
// T80(b) core. In an effort to merge and maintain bug fixes ....
//
// Ver 303 add undocumented DDCB and FDCB opcodes by TobiFlex 20.04.2010
// Ver 301 parity flag is just parity for 8080, also overflow for Z80, by Sean Riddle
// Ver 300 started tidyup.
//
// MikeJ March 2005
// Latest version from www.fpgaarcade.com (original www.opencores.org)
//
// ****
// Z80 compatible microprocessor core
//
// Version : 0247
// Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
// All rights reserved
//
// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in synthesized form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// Neither the name of the author nor the names of other contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

/* verilator coverage_off */
module t8080_reg
  (input  clk,
   input  cen,
   input  weh,
   input  wel,
   input  [2:0] addra,
   input  [2:0] addrb,
   input  [2:0] addrc,
   input  [7:0] dih,
   input  [7:0] dil,
   input  dirset,
   input  [127:0] dir,
   output [7:0] doah,
   output [7:0] doal,
   output [7:0] dobh,
   output [7:0] dobl,
   output [7:0] doch,
   output [7:0] docl,
   output [127:0] dor);
  wire [63:0] regsh;
  wire [63:0] regsl;
  wire [7:0] n7575_o;
  wire [7:0] n7576_o;
  wire [7:0] n7577_o;
  wire [7:0] n7578_o;
  wire [7:0] n7579_o;
  wire [7:0] n7580_o;
  wire [7:0] n7581_o;
  wire [7:0] n7582_o;
  wire [7:0] n7583_o;
  wire [7:0] n7584_o;
  wire [7:0] n7585_o;
  wire [7:0] n7586_o;
  wire [7:0] n7587_o;
  wire [7:0] n7588_o;
  wire [7:0] n7589_o;
  wire [7:0] n7590_o;
  wire [2:0] n7593_o;
  wire [63:0] n7596_o;
  wire [2:0] n7599_o;
  wire [63:0] n7602_o;
  wire n7603_o;
  wire n7604_o;
  wire [63:0] n7605_o;
  wire [63:0] n7606_o;
  wire [63:0] n7607_o;
  wire [63:0] n7608_o;
  wire [2:0] n7614_o;
  wire [2:0] n7619_o;
  wire [2:0] n7624_o;
  wire [2:0] n7629_o;
  wire [2:0] n7634_o;
  wire [2:0] n7639_o;
  wire [7:0] n7642_o;
  wire [7:0] n7643_o;
  wire [15:0] n7644_o;
  wire [7:0] n7645_o;
  wire [23:0] n7646_o;
  wire [7:0] n7647_o;
  wire [31:0] n7648_o;
  wire [7:0] n7649_o;
  wire [39:0] n7650_o;
  wire [7:0] n7651_o;
  wire [47:0] n7652_o;
  wire [7:0] n7653_o;
  wire [55:0] n7654_o;
  wire [7:0] n7655_o;
  wire [63:0] n7656_o;
  wire [7:0] n7657_o;
  wire [71:0] n7658_o;
  wire [7:0] n7659_o;
  wire [79:0] n7660_o;
  wire [7:0] n7661_o;
  wire [87:0] n7662_o;
  wire [7:0] n7663_o;
  wire [95:0] n7664_o;
  wire [7:0] n7665_o;
  wire [103:0] n7666_o;
  wire [7:0] n7667_o;
  wire [111:0] n7668_o;
  wire [7:0] n7669_o;
  wire [119:0] n7670_o;
  wire [7:0] n7671_o;
  wire [127:0] n7672_o;
  reg [63:0] n7673_q;
  reg [63:0] n7674_q;
  wire n7675_o;
  wire n7676_o;
  wire n7677_o;
  wire n7678_o;
  wire n7679_o;
  wire n7680_o;
  wire n7681_o;
  wire n7682_o;
  wire n7683_o;
  wire n7684_o;
  wire n7685_o;
  wire n7686_o;
  wire n7687_o;
  wire n7688_o;
  wire n7689_o;
  wire n7690_o;
  wire n7691_o;
  wire n7692_o;
  wire [7:0] n7693_o;
  wire [7:0] n7694_o;
  wire [7:0] n7695_o;
  wire [7:0] n7696_o;
  wire [7:0] n7697_o;
  wire [7:0] n7698_o;
  wire [7:0] n7699_o;
  wire [7:0] n7700_o;
  wire [7:0] n7701_o;
  wire [7:0] n7702_o;
  wire [7:0] n7703_o;
  wire [7:0] n7704_o;
  wire [7:0] n7705_o;
  wire [7:0] n7706_o;
  wire [7:0] n7707_o;
  wire [7:0] n7708_o;
  wire [63:0] n7709_o;
  wire n7710_o;
  wire n7711_o;
  wire n7712_o;
  wire n7713_o;
  wire n7714_o;
  wire n7715_o;
  wire n7716_o;
  wire n7717_o;
  wire n7718_o;
  wire n7719_o;
  wire n7720_o;
  wire n7721_o;
  wire n7722_o;
  wire n7723_o;
  wire n7724_o;
  wire n7725_o;
  wire n7726_o;
  wire n7727_o;
  wire [7:0] n7728_o;
  wire [7:0] n7729_o;
  wire [7:0] n7730_o;
  wire [7:0] n7731_o;
  wire [7:0] n7732_o;
  wire [7:0] n7733_o;
  wire [7:0] n7734_o;
  wire [7:0] n7735_o;
  wire [7:0] n7736_o;
  wire [7:0] n7737_o;
  wire [7:0] n7738_o;
  wire [7:0] n7739_o;
  wire [7:0] n7740_o;
  wire [7:0] n7741_o;
  wire [7:0] n7742_o;
  wire [7:0] n7743_o;
  wire [63:0] n7744_o;
  wire [7:0] n7745_o;
  wire [7:0] n7746_o;
  wire [7:0] n7747_o;
  wire [7:0] n7748_o;
  wire [7:0] n7749_o;
  wire [7:0] n7750_o;
  wire [7:0] n7751_o;
  wire [7:0] n7752_o;
  wire [1:0] n7753_o;
  reg [7:0] n7754_o;
  wire [1:0] n7755_o;
  reg [7:0] n7756_o;
  wire n7757_o;
  wire [7:0] n7758_o;
  wire [7:0] n7759_o;
  wire [7:0] n7760_o;
  wire [7:0] n7761_o;
  wire [7:0] n7762_o;
  wire [7:0] n7763_o;
  wire [7:0] n7764_o;
  wire [7:0] n7765_o;
  wire [7:0] n7766_o;
  wire [1:0] n7767_o;
  reg [7:0] n7768_o;
  wire [1:0] n7769_o;
  reg [7:0] n7770_o;
  wire n7771_o;
  wire [7:0] n7772_o;
  wire [7:0] n7773_o;
  wire [7:0] n7774_o;
  wire [7:0] n7775_o;
  wire [7:0] n7776_o;
  wire [7:0] n7777_o;
  wire [7:0] n7778_o;
  wire [7:0] n7779_o;
  wire [7:0] n7780_o;
  wire [1:0] n7781_o;
  reg [7:0] n7782_o;
  wire [1:0] n7783_o;
  reg [7:0] n7784_o;
  wire n7785_o;
  wire [7:0] n7786_o;
  wire [7:0] n7787_o;
  wire [7:0] n7788_o;
  wire [7:0] n7789_o;
  wire [7:0] n7790_o;
  wire [7:0] n7791_o;
  wire [7:0] n7792_o;
  wire [7:0] n7793_o;
  wire [7:0] n7794_o;
  wire [1:0] n7795_o;
  reg [7:0] n7796_o;
  wire [1:0] n7797_o;
  reg [7:0] n7798_o;
  wire n7799_o;
  wire [7:0] n7800_o;
  wire [7:0] n7801_o;
  wire [7:0] n7802_o;
  wire [7:0] n7803_o;
  wire [7:0] n7804_o;
  wire [7:0] n7805_o;
  wire [7:0] n7806_o;
  wire [7:0] n7807_o;
  wire [7:0] n7808_o;
  wire [1:0] n7809_o;
  reg [7:0] n7810_o;
  wire [1:0] n7811_o;
  reg [7:0] n7812_o;
  wire n7813_o;
  wire [7:0] n7814_o;
  wire [7:0] n7815_o;
  wire [7:0] n7816_o;
  wire [7:0] n7817_o;
  wire [7:0] n7818_o;
  wire [7:0] n7819_o;
  wire [7:0] n7820_o;
  wire [7:0] n7821_o;
  wire [7:0] n7822_o;
  wire [1:0] n7823_o;
  reg [7:0] n7824_o;
  wire [1:0] n7825_o;
  reg [7:0] n7826_o;
  wire n7827_o;
  wire [7:0] n7828_o;
  assign doah = n7758_o;
  assign doal = n7772_o;
  assign dobh = n7786_o;
  assign dobl = n7800_o;
  assign doch = n7814_o;
  assign docl = n7828_o;
  assign dor = n7672_o;
  /* T80_Reg.vhd:101:16  */
  assign regsh = n7673_q; // (signal)
  /* T80_Reg.vhd:102:16  */
  assign regsl = n7674_q; // (signal)
  /* T80_Reg.vhd:110:48  */
  assign n7575_o = dir[7:0];
  /* T80_Reg.vhd:111:48  */
  assign n7576_o = dir[15:8];
  /* T80_Reg.vhd:113:48  */
  assign n7577_o = dir[23:16];
  /* T80_Reg.vhd:114:48  */
  assign n7578_o = dir[31:24];
  /* T80_Reg.vhd:116:48  */
  assign n7579_o = dir[39:32];
  /* T80_Reg.vhd:117:48  */
  assign n7580_o = dir[47:40];
  /* T80_Reg.vhd:119:48  */
  assign n7581_o = dir[55:48];
  /* T80_Reg.vhd:120:48  */
  assign n7582_o = dir[63:56];
  /* T80_Reg.vhd:122:48  */
  assign n7583_o = dir[71:64];
  /* T80_Reg.vhd:123:48  */
  assign n7584_o = dir[79:72];
  /* T80_Reg.vhd:125:48  */
  assign n7585_o = dir[87:80];
  /* T80_Reg.vhd:126:48  */
  assign n7586_o = dir[95:88];
  /* T80_Reg.vhd:128:48  */
  assign n7587_o = dir[103:96];
  /* T80_Reg.vhd:129:48  */
  assign n7588_o = dir[111:104];
  /* T80_Reg.vhd:131:48  */
  assign n7589_o = dir[119:112];
  /* T80_Reg.vhd:132:48  */
  assign n7590_o = dir[127:120];
  /* T80_Reg.vhd:135:47  */
  assign n7593_o = 3'b111 - addra;
  /* T80_Reg.vhd:133:25  */
  assign n7596_o = n7603_o ? n7709_o : regsh;
  /* T80_Reg.vhd:138:47  */
  assign n7599_o = 3'b111 - addra;
  /* T80_Reg.vhd:133:25  */
  assign n7602_o = n7604_o ? n7744_o : regsl;
  /* T80_Reg.vhd:133:25  */
  assign n7603_o = weh & cen;
  /* T80_Reg.vhd:133:25  */
  assign n7604_o = wel & cen;
  assign n7605_o = {n7576_o, n7578_o, n7580_o, n7582_o, n7584_o, n7586_o, n7588_o, n7590_o};
  /* T80_Reg.vhd:109:25  */
  assign n7606_o = dirset ? n7605_o : n7596_o;
  /* T80_ALU.vhd:112:26  */
  assign n7607_o = {n7575_o, n7577_o, n7579_o, n7581_o, n7583_o, n7585_o, n7587_o, n7589_o};
  /* T80_Reg.vhd:109:25  */
  assign n7608_o = dirset ? n7607_o : n7602_o;
  /* T80_Reg.vhd:144:23  */
  assign n7614_o = 3'b111 - addra;
  /* T80_Reg.vhd:145:23  */
  assign n7619_o = 3'b111 - addra;
  /* T80_Reg.vhd:146:23  */
  assign n7624_o = 3'b111 - addrb;
  /* T80_Reg.vhd:147:23  */
  assign n7629_o = 3'b111 - addrb;
  /* T80_Reg.vhd:148:23  */
  assign n7634_o = 3'b111 - addrc;
  /* T80_Reg.vhd:149:23  */
  assign n7639_o = 3'b111 - addrc;
  /* T80_Reg.vhd:150:22  */
  assign n7642_o = regsh[7:0];
  /* T80_Reg.vhd:150:33  */
  assign n7643_o = regsl[7:0];
  /* T80_Reg.vhd:150:26  */
  assign n7644_o = {n7642_o, n7643_o};
  /* T80_Reg.vhd:150:44  */
  assign n7645_o = regsh[15:8];
  /* T80_Reg.vhd:150:37  */
  assign n7646_o = {n7644_o, n7645_o};
  /* T80_Reg.vhd:150:55  */
  assign n7647_o = regsl[15:8];
  /* T80_Reg.vhd:150:48  */
  assign n7648_o = {n7646_o, n7647_o};
  /* T80_Reg.vhd:150:66  */
  assign n7649_o = regsh[23:16];
  /* T80_Reg.vhd:150:59  */
  assign n7650_o = {n7648_o, n7649_o};
  /* T80_Reg.vhd:150:77  */
  assign n7651_o = regsl[23:16];
  /* T80_Reg.vhd:150:70  */
  assign n7652_o = {n7650_o, n7651_o};
  /* T80_Reg.vhd:150:88  */
  assign n7653_o = regsh[31:24];
  /* T80_Reg.vhd:150:81  */
  assign n7654_o = {n7652_o, n7653_o};
  /* T80_Reg.vhd:150:99  */
  assign n7655_o = regsl[31:24];
  /* T80_Reg.vhd:150:92  */
  assign n7656_o = {n7654_o, n7655_o};
  /* T80_Reg.vhd:150:110  */
  assign n7657_o = regsh[39:32];
  /* T80_Reg.vhd:150:103  */
  assign n7658_o = {n7656_o, n7657_o};
  /* T80_Reg.vhd:150:121  */
  assign n7659_o = regsl[39:32];
  /* T80_Reg.vhd:150:114  */
  assign n7660_o = {n7658_o, n7659_o};
  /* T80_Reg.vhd:150:132  */
  assign n7661_o = regsh[47:40];
  /* T80_Reg.vhd:150:125  */
  assign n7662_o = {n7660_o, n7661_o};
  /* T80_Reg.vhd:150:143  */
  assign n7663_o = regsl[47:40];
  /* T80_Reg.vhd:150:136  */
  assign n7664_o = {n7662_o, n7663_o};
  /* T80_Reg.vhd:150:154  */
  assign n7665_o = regsh[55:48];
  /* T80_Reg.vhd:150:147  */
  assign n7666_o = {n7664_o, n7665_o};
  /* T80_Reg.vhd:150:165  */
  assign n7667_o = regsl[55:48];
  /* T80_Reg.vhd:150:158  */
  assign n7668_o = {n7666_o, n7667_o};
  /* T80_Reg.vhd:150:176  */
  assign n7669_o = regsh[63:56];
  /* T80_Reg.vhd:150:169  */
  assign n7670_o = {n7668_o, n7669_o};
  /* T80_Reg.vhd:150:187  */
  assign n7671_o = regsl[63:56];
  /* T80_Reg.vhd:150:180  */
  assign n7672_o = {n7670_o, n7671_o};
  /* T80_Reg.vhd:108:17  */
  always @(posedge clk)
    n7673_q <= n7606_o;
  /* T80_Reg.vhd:108:17  */
  always @(posedge clk)
    n7674_q <= n7608_o;
  /* T80_Reg.vhd:135:41  */
  assign n7675_o = n7593_o[2];
  /* T80_Reg.vhd:135:41  */
  assign n7676_o = ~n7675_o;
  /* T80_Reg.vhd:135:41  */
  assign n7677_o = n7593_o[1];
  /* T80_Reg.vhd:135:41  */
  assign n7678_o = ~n7677_o;
  /* T80_Reg.vhd:135:41  */
  assign n7679_o = n7676_o & n7678_o;
  /* T80_Reg.vhd:135:41  */
  assign n7680_o = n7676_o & n7677_o;
  /* T80_Reg.vhd:135:41  */
  assign n7681_o = n7675_o & n7678_o;
  /* T80_Reg.vhd:135:41  */
  assign n7682_o = n7675_o & n7677_o;
  /* T80_Reg.vhd:135:41  */
  assign n7683_o = n7593_o[0];
  /* T80_Reg.vhd:135:41  */
  assign n7684_o = ~n7683_o;
  /* T80_Reg.vhd:135:41  */
  assign n7685_o = n7679_o & n7684_o;
  /* T80_Reg.vhd:135:41  */
  assign n7686_o = n7679_o & n7683_o;
  /* T80_Reg.vhd:135:41  */
  assign n7687_o = n7680_o & n7684_o;
  /* T80_Reg.vhd:135:41  */
  assign n7688_o = n7680_o & n7683_o;
  /* T80_Reg.vhd:135:41  */
  assign n7689_o = n7681_o & n7684_o;
  /* T80_Reg.vhd:135:41  */
  assign n7690_o = n7681_o & n7683_o;
  /* T80_Reg.vhd:135:41  */
  assign n7691_o = n7682_o & n7684_o;
  /* T80_Reg.vhd:135:41  */
  assign n7692_o = n7682_o & n7683_o;
  assign n7693_o = regsh[7:0];
  /* T80_Reg.vhd:135:41  */
  assign n7694_o = n7685_o ? dih : n7693_o;
  assign n7695_o = regsh[15:8];
  /* T80_Reg.vhd:135:41  */
  assign n7696_o = n7686_o ? dih : n7695_o;
  assign n7697_o = regsh[23:16];
  /* T80_Reg.vhd:135:41  */
  assign n7698_o = n7687_o ? dih : n7697_o;
  assign n7699_o = regsh[31:24];
  /* T80_Reg.vhd:135:41  */
  assign n7700_o = n7688_o ? dih : n7699_o;
  assign n7701_o = regsh[39:32];
  /* T80_Reg.vhd:135:41  */
  assign n7702_o = n7689_o ? dih : n7701_o;
  assign n7703_o = regsh[47:40];
  /* T80_Reg.vhd:135:41  */
  assign n7704_o = n7690_o ? dih : n7703_o;
  assign n7705_o = regsh[55:48];
  /* T80_Reg.vhd:135:41  */
  assign n7706_o = n7691_o ? dih : n7705_o;
  assign n7707_o = regsh[63:56];
  /* T80_Reg.vhd:135:41  */
  assign n7708_o = n7692_o ? dih : n7707_o;
  assign n7709_o = {n7708_o, n7706_o, n7704_o, n7702_o, n7700_o, n7698_o, n7696_o, n7694_o};
  /* T80_Reg.vhd:138:41  */
  assign n7710_o = n7599_o[2];
  /* T80_Reg.vhd:138:41  */
  assign n7711_o = ~n7710_o;
  /* T80_Reg.vhd:138:41  */
  assign n7712_o = n7599_o[1];
  /* T80_Reg.vhd:138:41  */
  assign n7713_o = ~n7712_o;
  /* T80_Reg.vhd:138:41  */
  assign n7714_o = n7711_o & n7713_o;
  /* T80_Reg.vhd:138:41  */
  assign n7715_o = n7711_o & n7712_o;
  /* T80_Reg.vhd:138:41  */
  assign n7716_o = n7710_o & n7713_o;
  /* T80_Reg.vhd:138:41  */
  assign n7717_o = n7710_o & n7712_o;
  /* T80_Reg.vhd:138:41  */
  assign n7718_o = n7599_o[0];
  /* T80_Reg.vhd:138:41  */
  assign n7719_o = ~n7718_o;
  /* T80_Reg.vhd:138:41  */
  assign n7720_o = n7714_o & n7719_o;
  /* T80_Reg.vhd:138:41  */
  assign n7721_o = n7714_o & n7718_o;
  /* T80_Reg.vhd:138:41  */
  assign n7722_o = n7715_o & n7719_o;
  /* T80_Reg.vhd:138:41  */
  assign n7723_o = n7715_o & n7718_o;
  /* T80_Reg.vhd:138:41  */
  assign n7724_o = n7716_o & n7719_o;
  /* T80_Reg.vhd:138:41  */
  assign n7725_o = n7716_o & n7718_o;
  /* T80_Reg.vhd:138:41  */
  assign n7726_o = n7717_o & n7719_o;
  /* T80_Reg.vhd:138:41  */
  assign n7727_o = n7717_o & n7718_o;
  assign n7728_o = regsl[7:0];
  /* T80_Reg.vhd:138:41  */
  assign n7729_o = n7720_o ? dil : n7728_o;
  assign n7730_o = regsl[15:8];
  /* T80_Reg.vhd:138:41  */
  assign n7731_o = n7721_o ? dil : n7730_o;
  assign n7732_o = regsl[23:16];
  /* T80_Reg.vhd:138:41  */
  assign n7733_o = n7722_o ? dil : n7732_o;
  assign n7734_o = regsl[31:24];
  /* T80_Reg.vhd:138:41  */
  assign n7735_o = n7723_o ? dil : n7734_o;
  assign n7736_o = regsl[39:32];
  /* T80_Reg.vhd:138:41  */
  assign n7737_o = n7724_o ? dil : n7736_o;
  assign n7738_o = regsl[47:40];
  /* T80_Reg.vhd:138:41  */
  assign n7739_o = n7725_o ? dil : n7738_o;
  assign n7740_o = regsl[55:48];
  /* T80_Reg.vhd:138:41  */
  assign n7741_o = n7726_o ? dil : n7740_o;
  assign n7742_o = regsl[63:56];
  /* T80_Reg.vhd:138:41  */
  assign n7743_o = n7727_o ? dil : n7742_o;
  assign n7744_o = {n7743_o, n7741_o, n7739_o, n7737_o, n7735_o, n7733_o, n7731_o, n7729_o};
  /* T80_Reg.vhd:138:47  */
  assign n7745_o = regsh[7:0];
  /* T80_Reg.vhd:138:41  */
  assign n7746_o = regsh[15:8];
  assign n7747_o = regsh[23:16];
  assign n7748_o = regsh[31:24];
  assign n7749_o = regsh[39:32];
  assign n7750_o = regsh[47:40];
  assign n7751_o = regsh[55:48];
  assign n7752_o = regsh[63:56];
  /* T80_Reg.vhd:144:22  */
  assign n7753_o = n7614_o[1:0];
  /* T80_Reg.vhd:144:22  */
  always @*
    case (n7753_o)
      2'b00: n7754_o = n7745_o;
      2'b01: n7754_o = n7746_o;
      2'b10: n7754_o = n7747_o;
      2'b11: n7754_o = n7748_o;
    endcase
  /* T80_Reg.vhd:144:22  */
  assign n7755_o = n7614_o[1:0];
  /* T80_Reg.vhd:144:22  */
  always @*
    case (n7755_o)
      2'b00: n7756_o = n7749_o;
      2'b01: n7756_o = n7750_o;
      2'b10: n7756_o = n7751_o;
      2'b11: n7756_o = n7752_o;
    endcase
  /* T80_Reg.vhd:144:22  */
  assign n7757_o = n7614_o[2];
  /* T80_Reg.vhd:144:22  */
  assign n7758_o = n7757_o ? n7756_o : n7754_o;
  /* T80_Reg.vhd:144:22  */
  assign n7759_o = regsl[7:0];
  /* T80_Reg.vhd:144:23  */
  assign n7760_o = regsl[15:8];
  assign n7761_o = regsl[23:16];
  assign n7762_o = regsl[31:24];
  assign n7763_o = regsl[39:32];
  assign n7764_o = regsl[47:40];
  assign n7765_o = regsl[55:48];
  assign n7766_o = regsl[63:56];
  /* T80_Reg.vhd:145:22  */
  assign n7767_o = n7619_o[1:0];
  /* T80_Reg.vhd:145:22  */
  always @*
    case (n7767_o)
      2'b00: n7768_o = n7759_o;
      2'b01: n7768_o = n7760_o;
      2'b10: n7768_o = n7761_o;
      2'b11: n7768_o = n7762_o;
    endcase
  /* T80_Reg.vhd:145:22  */
  assign n7769_o = n7619_o[1:0];
  /* T80_Reg.vhd:145:22  */
  always @*
    case (n7769_o)
      2'b00: n7770_o = n7763_o;
      2'b01: n7770_o = n7764_o;
      2'b10: n7770_o = n7765_o;
      2'b11: n7770_o = n7766_o;
    endcase
  /* T80_Reg.vhd:145:22  */
  assign n7771_o = n7619_o[2];
  /* T80_Reg.vhd:145:22  */
  assign n7772_o = n7771_o ? n7770_o : n7768_o;
  /* T80_Reg.vhd:145:22  */
  assign n7773_o = regsh[7:0];
  /* T80_Reg.vhd:145:23  */
  assign n7774_o = regsh[15:8];
  assign n7775_o = regsh[23:16];
  assign n7776_o = regsh[31:24];
  assign n7777_o = regsh[39:32];
  assign n7778_o = regsh[47:40];
  assign n7779_o = regsh[55:48];
  assign n7780_o = regsh[63:56];
  /* T80_Reg.vhd:146:22  */
  assign n7781_o = n7624_o[1:0];
  /* T80_Reg.vhd:146:22  */
  always @*
    case (n7781_o)
      2'b00: n7782_o = n7773_o;
      2'b01: n7782_o = n7774_o;
      2'b10: n7782_o = n7775_o;
      2'b11: n7782_o = n7776_o;
    endcase
  /* T80_Reg.vhd:146:22  */
  assign n7783_o = n7624_o[1:0];
  /* T80_Reg.vhd:146:22  */
  always @*
    case (n7783_o)
      2'b00: n7784_o = n7777_o;
      2'b01: n7784_o = n7778_o;
      2'b10: n7784_o = n7779_o;
      2'b11: n7784_o = n7780_o;
    endcase
  /* T80_Reg.vhd:146:22  */
  assign n7785_o = n7624_o[2];
  /* T80_Reg.vhd:146:22  */
  assign n7786_o = n7785_o ? n7784_o : n7782_o;
  /* T80_Reg.vhd:146:22  */
  assign n7787_o = regsl[7:0];
  /* T80_Reg.vhd:146:23  */
  assign n7788_o = regsl[15:8];
  assign n7789_o = regsl[23:16];
  assign n7790_o = regsl[31:24];
  assign n7791_o = regsl[39:32];
  assign n7792_o = regsl[47:40];
  assign n7793_o = regsl[55:48];
  assign n7794_o = regsl[63:56];
  /* T80_Reg.vhd:147:22  */
  assign n7795_o = n7629_o[1:0];
  /* T80_Reg.vhd:147:22  */
  always @*
    case (n7795_o)
      2'b00: n7796_o = n7787_o;
      2'b01: n7796_o = n7788_o;
      2'b10: n7796_o = n7789_o;
      2'b11: n7796_o = n7790_o;
    endcase
  /* T80_Reg.vhd:147:22  */
  assign n7797_o = n7629_o[1:0];
  /* T80_Reg.vhd:147:22  */
  always @*
    case (n7797_o)
      2'b00: n7798_o = n7791_o;
      2'b01: n7798_o = n7792_o;
      2'b10: n7798_o = n7793_o;
      2'b11: n7798_o = n7794_o;
    endcase
  /* T80_Reg.vhd:147:22  */
  assign n7799_o = n7629_o[2];
  /* T80_Reg.vhd:147:22  */
  assign n7800_o = n7799_o ? n7798_o : n7796_o;
  /* T80_Reg.vhd:147:22  */
  assign n7801_o = regsh[7:0];
  /* T80_Reg.vhd:147:23  */
  assign n7802_o = regsh[15:8];
  assign n7803_o = regsh[23:16];
  assign n7804_o = regsh[31:24];
  assign n7805_o = regsh[39:32];
  assign n7806_o = regsh[47:40];
  assign n7807_o = regsh[55:48];
  assign n7808_o = regsh[63:56];
  /* T80_Reg.vhd:148:22  */
  assign n7809_o = n7634_o[1:0];
  /* T80_Reg.vhd:148:22  */
  always @*
    case (n7809_o)
      2'b00: n7810_o = n7801_o;
      2'b01: n7810_o = n7802_o;
      2'b10: n7810_o = n7803_o;
      2'b11: n7810_o = n7804_o;
    endcase
  /* T80_Reg.vhd:148:22  */
  assign n7811_o = n7634_o[1:0];
  /* T80_Reg.vhd:148:22  */
  always @*
    case (n7811_o)
      2'b00: n7812_o = n7805_o;
      2'b01: n7812_o = n7806_o;
      2'b10: n7812_o = n7807_o;
      2'b11: n7812_o = n7808_o;
    endcase
  /* T80_Reg.vhd:148:22  */
  assign n7813_o = n7634_o[2];
  /* T80_Reg.vhd:148:22  */
  assign n7814_o = n7813_o ? n7812_o : n7810_o;
  /* T80_Reg.vhd:148:22  */
  assign n7815_o = regsl[7:0];
  /* T80_Reg.vhd:148:23  */
  assign n7816_o = regsl[15:8];
  assign n7817_o = regsl[23:16];
  assign n7818_o = regsl[31:24];
  assign n7819_o = regsl[39:32];
  assign n7820_o = regsl[47:40];
  assign n7821_o = regsl[55:48];
  assign n7822_o = regsl[63:56];
  /* T80_Reg.vhd:149:22  */
  assign n7823_o = n7639_o[1:0];
  /* T80_Reg.vhd:149:22  */
  always @*
    case (n7823_o)
      2'b00: n7824_o = n7815_o;
      2'b01: n7824_o = n7816_o;
      2'b10: n7824_o = n7817_o;
      2'b11: n7824_o = n7818_o;
    endcase
  /* T80_Reg.vhd:149:22  */
  assign n7825_o = n7639_o[1:0];
  /* T80_Reg.vhd:149:22  */
  always @*
    case (n7825_o)
      2'b00: n7826_o = n7819_o;
      2'b01: n7826_o = n7820_o;
      2'b10: n7826_o = n7821_o;
      2'b11: n7826_o = n7822_o;
    endcase
  /* T80_Reg.vhd:149:22  */
  assign n7827_o = n7639_o[2];
  /* T80_Reg.vhd:149:22  */
  assign n7828_o = n7827_o ? n7826_o : n7824_o;
endmodule

module t8080_alu
  (input  arith16,
   input  z16,
   input  [15:0] wz,
   input  [1:0] xy_state,
   input  [3:0] alu_op,
   input  [5:0] ir,
   input  [1:0] iset,
   input  [7:0] busa,
   input  [7:0] busb,
   input  [7:0] f_in,
   output [7:0] q,
   output [7:0] f_out);
  wire usecarry;
  wire carry7_v;
  wire overflow_v;
  wire halfcarry_v;
  wire carry_v;
  wire [7:0] q_v;
  wire [7:0] bitmask;
  wire [2:0] n6972_o;
  wire n6975_o;
  wire n6978_o;
  wire n6981_o;
  wire n6984_o;
  wire n6987_o;
  wire n6990_o;
  wire n6993_o;
  wire [6:0] n6995_o;
  reg [7:0] n6996_o;
  wire n6997_o;
  wire n6998_o;
  wire n6999_o;
  wire n7000_o;
  wire [3:0] n7002_o;
  wire [3:0] n7003_o;
  wire n7004_o;
  wire n7005_o;
  wire n7006_o;
  wire n7007_o;
  wire n7008_o;
  wire [3:0] n7013_o;
  wire [3:0] n7014_o;
  wire [4:0] n7017_o;
  wire [5:0] n7018_o;
  wire [4:0] n7020_o;
  wire [5:0] n7022_o;
  wire [5:0] n7023_o;
  wire n7025_o;
  wire [3:0] n7026_o;
  wire [2:0] n7028_o;
  wire [2:0] n7029_o;
  wire n7030_o;
  wire [2:0] n7035_o;
  wire [2:0] n7036_o;
  wire [3:0] n7039_o;
  wire [4:0] n7040_o;
  wire [3:0] n7042_o;
  wire [4:0] n7044_o;
  wire [4:0] n7045_o;
  wire n7047_o;
  wire [2:0] n7048_o;
  wire n7050_o;
  wire n7051_o;
  wire n7052_o;
  wire n7057_o;
  wire n7058_o;
  wire [1:0] n7061_o;
  wire [2:0] n7062_o;
  wire [1:0] n7064_o;
  wire [2:0] n7066_o;
  wire [2:0] n7067_o;
  wire n7069_o;
  wire n7070_o;
  wire n7073_o;
  wire n7074_o;
  wire n7075_o;
  wire n7076_o;
  wire n7077_o;
  wire n7078_o;
  wire n7079_o;
  wire n7080_o;
  wire n7081_o;
  wire n7082_o;
  wire n7083_o;
  wire n7084_o;
  wire n7085_o;
  wire n7086_o;
  wire n7087_o;
  wire n7088_o;
  wire [2:0] n7096_o;
  wire n7098_o;
  wire n7100_o;
  wire n7101_o;
  wire n7103_o;
  wire n7104_o;
  wire n7106_o;
  wire n7108_o;
  wire n7109_o;
  wire n7111_o;
  wire n7112_o;
  wire [7:0] n7113_o;
  wire n7116_o;
  wire [7:0] n7117_o;
  wire n7120_o;
  wire [7:0] n7121_o;
  wire [3:0] n7123_o;
  reg n7124_o;
  reg n7125_o;
  wire n7126_o;
  reg n7127_o;
  reg n7128_o;
  reg [7:0] n7129_o;
  wire [2:0] n7130_o;
  wire n7132_o;
  wire n7133_o;
  wire n7134_o;
  wire n7135_o;
  wire n7136_o;
  wire n7137_o;
  wire n7138_o;
  wire n7140_o;
  wire n7142_o;
  wire n7143_o;
  wire n7145_o;
  wire n7146_o;
  wire [2:0] n7147_o;
  wire n7149_o;
  wire n7151_o;
  wire n7152_o;
  wire n7154_o;
  wire n7155_o;
  wire n7157_o;
  wire n7158_o;
  wire n7160_o;
  wire n7161_o;
  wire n7162_o;
  wire n7163_o;
  wire n7164_o;
  wire n7165_o;
  wire n7166_o;
  wire n7167_o;
  wire n7168_o;
  wire n7169_o;
  wire n7170_o;
  wire n7171_o;
  wire n7172_o;
  wire n7173_o;
  wire n7174_o;
  wire n7175_o;
  wire n7176_o;
  wire n7177_o;
  reg n7178_o;
  wire n7179_o;
  wire n7180_o;
  wire n7181_o;
  wire [1:0] n7182_o;
  wire n7183_o;
  wire [1:0] n7184_o;
  wire [1:0] n7185_o;
  wire n7187_o;
  wire n7189_o;
  wire n7190_o;
  wire n7192_o;
  wire n7193_o;
  wire n7195_o;
  wire n7196_o;
  wire n7198_o;
  wire n7199_o;
  wire n7201_o;
  wire n7202_o;
  wire n7204_o;
  wire n7205_o;
  wire n7207_o;
  wire n7208_o;
  wire n7209_o;
  wire n7212_o;
  wire n7213_o;
  wire [8:0] n7214_o;
  wire [3:0] n7215_o;
  wire n7217_o;
  wire n7218_o;
  wire n7219_o;
  wire [8:0] n7220_o;
  wire [3:0] n7221_o;
  wire n7223_o;
  wire n7226_o;
  wire [8:0] n7227_o;
  wire [8:0] n7229_o;
  wire n7230_o;
  wire [8:0] n7231_o;
  wire [8:0] n7232_o;
  wire [4:0] n7233_o;
  wire n7235_o;
  wire n7236_o;
  wire n7237_o;
  wire [8:0] n7239_o;
  wire [8:0] n7240_o;
  wire [8:0] n7241_o;
  wire [3:0] n7242_o;
  wire n7244_o;
  wire n7245_o;
  wire n7246_o;
  wire [8:0] n7247_o;
  wire [3:0] n7248_o;
  wire n7250_o;
  wire n7252_o;
  wire [8:0] n7253_o;
  wire [7:0] n7254_o;
  wire [7:0] n7256_o;
  wire n7257_o;
  wire [7:0] n7258_o;
  wire n7260_o;
  wire n7261_o;
  wire n7262_o;
  wire [8:0] n7263_o;
  wire [8:0] n7265_o;
  wire [8:0] n7266_o;
  wire [8:0] n7267_o;
  wire n7268_o;
  wire [8:0] n7269_o;
  wire n7270_o;
  wire n7271_o;
  wire n7272_o;
  wire n7273_o;
  wire n7274_o;
  wire [7:0] n7275_o;
  wire [7:0] n7276_o;
  wire n7278_o;
  wire n7281_o;
  wire n7282_o;
  wire n7283_o;
  wire n7284_o;
  wire n7285_o;
  wire n7286_o;
  wire n7287_o;
  wire n7288_o;
  wire n7289_o;
  wire n7290_o;
  wire n7291_o;
  wire n7292_o;
  wire n7293_o;
  wire n7294_o;
  wire n7295_o;
  wire n7296_o;
  wire n7297_o;
  wire n7298_o;
  wire n7300_o;
  wire [3:0] n7301_o;
  wire n7302_o;
  wire [3:0] n7303_o;
  wire [3:0] n7304_o;
  wire [3:0] n7305_o;
  wire [7:0] n7308_o;
  wire n7309_o;
  wire [7:0] n7310_o;
  wire n7311_o;
  wire [7:0] n7312_o;
  wire n7314_o;
  wire n7317_o;
  wire [7:0] n7318_o;
  wire n7319_o;
  wire [7:0] n7320_o;
  wire n7321_o;
  wire [7:0] n7322_o;
  wire n7323_o;
  wire n7324_o;
  wire [7:0] n7325_o;
  wire n7326_o;
  wire n7327_o;
  wire [7:0] n7328_o;
  wire n7329_o;
  wire n7330_o;
  wire [7:0] n7331_o;
  wire n7332_o;
  wire n7333_o;
  wire [7:0] n7334_o;
  wire n7335_o;
  wire n7336_o;
  wire [7:0] n7337_o;
  wire n7338_o;
  wire n7339_o;
  wire [7:0] n7340_o;
  wire n7341_o;
  wire n7342_o;
  wire n7343_o;
  wire n7345_o;
  wire n7347_o;
  wire n7348_o;
  wire [7:0] n7349_o;
  wire n7350_o;
  wire n7352_o;
  wire n7357_o;
  wire n7358_o;
  wire [2:0] n7361_o;
  wire n7363_o;
  wire n7365_o;
  wire n7366_o;
  wire n7367_o;
  wire n7368_o;
  wire n7369_o;
  wire n7370_o;
  wire n7371_o;
  wire n7372_o;
  wire n7374_o;
  wire [7:0] n7375_o;
  wire n7377_o;
  wire [7:0] n7378_o;
  wire [7:0] n7379_o;
  wire n7381_o;
  wire [2:0] n7382_o;
  wire [6:0] n7383_o;
  wire n7384_o;
  wire n7385_o;
  wire n7387_o;
  wire [6:0] n7388_o;
  wire n7389_o;
  wire n7390_o;
  wire n7392_o;
  wire [6:0] n7393_o;
  wire n7394_o;
  wire n7395_o;
  wire n7397_o;
  wire [6:0] n7398_o;
  wire n7399_o;
  wire n7400_o;
  wire n7402_o;
  wire [6:0] n7403_o;
  wire n7405_o;
  wire n7407_o;
  wire [6:0] n7408_o;
  wire n7410_o;
  wire n7412_o;
  wire [6:0] n7413_o;
  wire n7414_o;
  wire n7415_o;
  wire n7417_o;
  wire [6:0] n7418_o;
  wire n7420_o;
  wire [6:0] n7421_o;
  reg n7422_o;
  wire n7423_o;
  wire n7424_o;
  wire n7425_o;
  wire n7426_o;
  reg n7427_o;
  wire [5:0] n7428_o;
  wire [5:0] n7429_o;
  wire [5:0] n7430_o;
  wire [5:0] n7431_o;
  wire [5:0] n7432_o;
  wire [5:0] n7433_o;
  wire [5:0] n7434_o;
  wire [5:0] n7435_o;
  reg [5:0] n7436_o;
  wire n7437_o;
  wire n7438_o;
  wire n7439_o;
  wire n7440_o;
  reg n7441_o;
  wire [7:0] n7444_o;
  wire n7445_o;
  wire [7:0] n7446_o;
  wire n7447_o;
  wire [7:0] n7448_o;
  wire n7449_o;
  wire [7:0] n7450_o;
  wire n7452_o;
  wire n7455_o;
  wire [7:0] n7456_o;
  wire n7457_o;
  wire [7:0] n7458_o;
  wire n7459_o;
  wire n7460_o;
  wire [7:0] n7461_o;
  wire n7462_o;
  wire n7463_o;
  wire [7:0] n7464_o;
  wire n7465_o;
  wire n7466_o;
  wire [7:0] n7467_o;
  wire n7468_o;
  wire n7469_o;
  wire [7:0] n7470_o;
  wire n7471_o;
  wire n7472_o;
  wire [7:0] n7473_o;
  wire n7474_o;
  wire n7475_o;
  wire [7:0] n7476_o;
  wire n7477_o;
  wire n7478_o;
  wire n7479_o;
  wire n7481_o;
  wire n7482_o;
  wire n7483_o;
  wire n7484_o;
  wire [1:0] n7485_o;
  wire n7486_o;
  wire [1:0] n7487_o;
  wire [1:0] n7488_o;
  wire n7490_o;
  wire [6:0] n7491_o;
  wire n7492_o;
  reg n7493_o;
  wire n7494_o;
  reg n7495_o;
  wire n7496_o;
  reg n7497_o;
  wire n7498_o;
  reg n7499_o;
  wire n7500_o;
  reg n7501_o;
  wire n7502_o;
  reg n7503_o;
  wire n7504_o;
  wire n7505_o;
  wire n7506_o;
  reg n7507_o;
  wire n7508_o;
  wire n7509_o;
  wire n7510_o;
  reg n7511_o;
  wire n7519_o;
  wire n7520_o;
  wire n7521_o;
  wire n7522_o;
  wire n7523_o;
  wire n7524_o;
  reg n7526_o;
  wire [2:0] n7527_o;
  wire [2:0] n7528_o;
  wire [2:0] n7529_o;
  wire [2:0] n7530_o;
  wire [2:0] n7531_o;
  wire [2:0] n7532_o;
  wire [2:0] n7533_o;
  reg [2:0] n7535_o;
  wire [2:0] n7536_o;
  wire [2:0] n7537_o;
  wire [2:0] n7538_o;
  wire [2:0] n7539_o;
  wire [2:0] n7540_o;
  wire [2:0] n7541_o;
  wire [2:0] n7542_o;
  reg [2:0] n7544_o;
  wire n7545_o;
  wire n7546_o;
  wire n7547_o;
  wire n7548_o;
  wire n7549_o;
  wire n7550_o;
  reg n7552_o;
  wire [7:0] n7560_o;
  wire [7:0] n7563_o;
  wire [7:0] n7564_o;
  assign q = n7560_o;
  assign f_out = n7564_o;
  /* T80_ALU.vhd:126:16  */
  assign usecarry = n7000_o; // (signal)
  /* T80_ALU.vhd:127:16  */
  assign carry7_v = n7047_o; // (signal)
  /* T80_ALU.vhd:128:16  */
  assign overflow_v = n7088_o; // (signal)
  /* T80_ALU.vhd:129:16  */
  assign halfcarry_v = n7025_o; // (signal)
  /* T80_ALU.vhd:130:16  */
  assign carry_v = n7069_o; // (signal)
  /* T80_ALU.vhd:131:16  */
  assign q_v = n7563_o; // (signal)
  /* T80_ALU.vhd:133:16  */
  assign bitmask = n6996_o; // (signal)
  /* T80_ALU.vhd:137:16  */
  assign n6972_o = ir[5:3];
  /* T80_ALU.vhd:137:58  */
  assign n6975_o = n6972_o == 3'b000;
  /* T80_ALU.vhd:138:94  */
  assign n6978_o = n6972_o == 3'b001;
  /* T80_ALU.vhd:139:94  */
  assign n6981_o = n6972_o == 3'b010;
  /* T80_ALU.vhd:140:94  */
  assign n6984_o = n6972_o == 3'b011;
  /* T80_ALU.vhd:141:94  */
  assign n6987_o = n6972_o == 3'b100;
  /* T80_ALU.vhd:142:94  */
  assign n6990_o = n6972_o == 3'b101;
  /* T80_ALU.vhd:143:94  */
  assign n6993_o = n6972_o == 3'b110;
  /* T80_MCode.vhd:113:7  */
  assign n6995_o = {n6993_o, n6990_o, n6987_o, n6984_o, n6981_o, n6978_o, n6975_o};
  /* T80_ALU.vhd:137:9  */
  always @*
    case (n6995_o)
      7'b1000000: n6996_o = 8'b01000000;
      7'b0100000: n6996_o = 8'b00100000;
      7'b0010000: n6996_o = 8'b00010000;
      7'b0001000: n6996_o = 8'b00001000;
      7'b0000100: n6996_o = 8'b00000100;
      7'b0000010: n6996_o = 8'b00000010;
      7'b0000001: n6996_o = 8'b00000001;
      default: n6996_o = 8'b10000000;
    endcase
  /* T80_ALU.vhd:146:31  */
  assign n6997_o = alu_op[2];
  /* T80_ALU.vhd:146:21  */
  assign n6998_o = ~n6997_o;
  /* T80_ALU.vhd:146:45  */
  assign n6999_o = alu_op[0];
  /* T80_ALU.vhd:146:35  */
  assign n7000_o = n6998_o & n6999_o;
  /* T80_ALU.vhd:147:20  */
  assign n7002_o = busa[3:0];
  /* T80_ALU.vhd:147:38  */
  assign n7003_o = busb[3:0];
  /* T80_ALU.vhd:147:58  */
  assign n7004_o = alu_op[1];
  /* T80_ALU.vhd:147:69  */
  assign n7005_o = alu_op[1];
  /* T80_ALU.vhd:147:95  */
  assign n7006_o = f_in[0];
  /* T80_ALU.vhd:147:87  */
  assign n7007_o = usecarry & n7006_o;
  /* T80_ALU.vhd:147:73  */
  assign n7008_o = n7005_o ^ n7007_o;
  /* T80_ALU.vhd:115:32  */
  assign n7013_o = ~n7003_o;
  /* T80_ALU.vhd:114:17  */
  assign n7014_o = n7004_o ? n7013_o : n7003_o;
  /* T80_ALU.vhd:120:39  */
  assign n7017_o = {1'b0, n7002_o};
  /* T80_ALU.vhd:120:43  */
  assign n7018_o = {n7017_o, n7008_o};
  /* T80_ALU.vhd:120:70  */
  assign n7020_o = {1'b0, n7014_o};
  /* T80_ALU.vhd:120:76  */
  assign n7022_o = {n7020_o, 1'b1};
  /* T80_ALU.vhd:120:55  */
  assign n7023_o = n7018_o + n7022_o;
  /* T80_ALU.vhd:121:31  */
  assign n7025_o = n7023_o[5];
  /* T80_ALU.vhd:122:46  */
  assign n7026_o = n7023_o[4:1];
  /* T80_ALU.vhd:148:20  */
  assign n7028_o = busa[6:4];
  /* T80_ALU.vhd:148:38  */
  assign n7029_o = busb[6:4];
  /* T80_ALU.vhd:148:58  */
  assign n7030_o = alu_op[1];
  /* T80_ALU.vhd:115:32  */
  assign n7035_o = ~n7029_o;
  /* T80_ALU.vhd:114:17  */
  assign n7036_o = n7030_o ? n7035_o : n7029_o;
  /* T80_ALU.vhd:120:39  */
  assign n7039_o = {1'b0, n7028_o};
  /* T80_ALU.vhd:120:43  */
  assign n7040_o = {n7039_o, halfcarry_v};
  /* T80_ALU.vhd:120:70  */
  assign n7042_o = {1'b0, n7036_o};
  /* T80_ALU.vhd:120:76  */
  assign n7044_o = {n7042_o, 1'b1};
  /* T80_ALU.vhd:120:55  */
  assign n7045_o = n7040_o + n7044_o;
  /* T80_ALU.vhd:121:31  */
  assign n7047_o = n7045_o[4];
  /* T80_ALU.vhd:122:46  */
  assign n7048_o = n7045_o[3:1];
  /* T80_ALU.vhd:149:20  */
  assign n7050_o = busa[7];
  /* T80_ALU.vhd:149:38  */
  assign n7051_o = busb[7];
  /* T80_ALU.vhd:149:58  */
  assign n7052_o = alu_op[1];
  /* T80_ALU.vhd:115:32  */
  assign n7057_o = ~n7051_o;
  /* T80_ALU.vhd:114:17  */
  assign n7058_o = n7052_o ? n7057_o : n7051_o;
  /* T80_ALU.vhd:120:39  */
  assign n7061_o = {1'b0, n7050_o};
  /* T80_ALU.vhd:120:43  */
  assign n7062_o = {n7061_o, carry7_v};
  /* T80_ALU.vhd:120:70  */
  assign n7064_o = {1'b0, n7058_o};
  /* T80_ALU.vhd:120:76  */
  assign n7066_o = {n7064_o, 1'b1};
  /* T80_ALU.vhd:120:55  */
  assign n7067_o = n7062_o + n7066_o;
  /* T80_ALU.vhd:121:31  */
  assign n7069_o = n7067_o[2];
  /* T80_ALU.vhd:122:46  */
  assign n7070_o = n7067_o[1];
  /* T80_ALU.vhd:155:47  */
  assign n7073_o = q_v[0];
  /* T80_ALU.vhd:155:58  */
  assign n7074_o = q_v[1];
  /* T80_ALU.vhd:155:51  */
  assign n7075_o = n7073_o ^ n7074_o;
  /* T80_ALU.vhd:155:69  */
  assign n7076_o = q_v[2];
  /* T80_ALU.vhd:155:62  */
  assign n7077_o = n7075_o ^ n7076_o;
  /* T80_ALU.vhd:155:80  */
  assign n7078_o = q_v[3];
  /* T80_ALU.vhd:155:73  */
  assign n7079_o = n7077_o ^ n7078_o;
  /* T80_ALU.vhd:156:47  */
  assign n7080_o = q_v[4];
  /* T80_ALU.vhd:155:84  */
  assign n7081_o = n7079_o ^ n7080_o;
  /* T80_ALU.vhd:156:58  */
  assign n7082_o = q_v[5];
  /* T80_ALU.vhd:156:51  */
  assign n7083_o = n7081_o ^ n7082_o;
  /* T80_ALU.vhd:156:69  */
  assign n7084_o = q_v[6];
  /* T80_ALU.vhd:156:62  */
  assign n7085_o = n7083_o ^ n7084_o;
  /* T80_ALU.vhd:156:80  */
  assign n7086_o = q_v[7];
  /* T80_ALU.vhd:156:73  */
  assign n7087_o = n7085_o ^ n7086_o;
  /* T80_ALU.vhd:155:39  */
  assign n7088_o = ~n7087_o;
  /* T80_ALU.vhd:172:36  */
  assign n7096_o = alu_op[2:0];
  /* T80_ALU.vhd:173:25  */
  assign n7098_o = n7096_o == 3'b000;
  /* T80_ALU.vhd:173:36  */
  assign n7100_o = n7096_o == 3'b001;
  /* T80_ALU.vhd:173:36  */
  assign n7101_o = n7098_o | n7100_o;
  /* T80_ALU.vhd:181:50  */
  assign n7103_o = ~carry_v;
  /* T80_ALU.vhd:182:50  */
  assign n7104_o = ~halfcarry_v;
  /* T80_ALU.vhd:178:25  */
  assign n7106_o = n7096_o == 3'b010;
  /* T80_ALU.vhd:178:36  */
  assign n7108_o = n7096_o == 3'b011;
  /* T80_ALU.vhd:178:36  */
  assign n7109_o = n7106_o | n7108_o;
  /* T80_ALU.vhd:178:44  */
  assign n7111_o = n7096_o == 3'b111;
  /* T80_ALU.vhd:178:44  */
  assign n7112_o = n7109_o | n7111_o;
  /* T80_ALU.vhd:185:57  */
  assign n7113_o = busa & busb;
  /* T80_ALU.vhd:184:25  */
  assign n7116_o = n7096_o == 3'b100;
  /* T80_ALU.vhd:188:57  */
  assign n7117_o = busa ^ busb;
  /* T80_ALU.vhd:187:25  */
  assign n7120_o = n7096_o == 3'b101;
  /* T80_ALU.vhd:191:57  */
  assign n7121_o = busa | busb;
  assign n7123_o = {n7120_o, n7116_o, n7112_o, n7101_o};
  /* T80_ALU.vhd:172:25  */
  always @*
    case (n7123_o)
      4'b1000: n7124_o = 1'b0;
      4'b0100: n7124_o = 1'b0;
      4'b0010: n7124_o = n7103_o;
      4'b0001: n7124_o = carry_v;
      default: n7124_o = 1'b0;
    endcase
  /* T80_ALU.vhd:172:25  */
  always @*
    case (n7123_o)
      4'b1000: n7125_o = 1'b0;
      4'b0100: n7125_o = 1'b0;
      4'b0010: n7125_o = 1'b1;
      4'b0001: n7125_o = 1'b0;
      default: n7125_o = 1'b0;
    endcase
  assign n7126_o = f_in[2];
  /* T80_ALU.vhd:172:25  */
  always @*
    case (n7123_o)
      4'b1000: n7127_o = n7126_o;
      4'b0100: n7127_o = n7126_o;
      4'b0010: n7127_o = overflow_v;
      4'b0001: n7127_o = overflow_v;
      default: n7127_o = n7126_o;
    endcase
  /* T80_ALU.vhd:172:25  */
  always @*
    case (n7123_o)
      4'b1000: n7128_o = 1'b0;
      4'b0100: n7128_o = 1'b1;
      4'b0010: n7128_o = n7104_o;
      4'b0001: n7128_o = halfcarry_v;
      default: n7128_o = 1'b0;
    endcase
  /* T80_ALU.vhd:172:25  */
  always @*
    case (n7123_o)
      4'b1000: n7129_o = n7117_o;
      4'b0100: n7129_o = n7113_o;
      4'b0010: n7129_o = q_v;
      4'b0001: n7129_o = q_v;
      default: n7129_o = n7121_o;
    endcase
  /* T80_ALU.vhd:194:34  */
  assign n7130_o = alu_op[2:0];
  /* T80_ALU.vhd:194:47  */
  assign n7132_o = n7130_o == 3'b111;
  /* T80_ALU.vhd:195:54  */
  assign n7133_o = busb[3];
  /* T80_ALU.vhd:196:54  */
  assign n7134_o = busb[5];
  /* T80_ALU.vhd:198:53  */
  assign n7135_o = n7129_o[3];
  /* T80_ALU.vhd:199:53  */
  assign n7136_o = n7129_o[5];
  /* T80_ALU.vhd:194:25  */
  assign n7137_o = n7132_o ? n7133_o : n7135_o;
  /* T80_ALU.vhd:194:25  */
  assign n7138_o = n7132_o ? n7134_o : n7136_o;
  /* T80_ALU.vhd:201:44  */
  assign n7140_o = n7129_o == 8'b00000000;
  /* T80_ALU.vhd:204:62  */
  assign n7142_o = f_in[6];
  /* T80_ALU.vhd:203:33  */
  assign n7143_o = z16 ? n7142_o : 1'b1;
  /* T80_ALU.vhd:201:25  */
  assign n7145_o = n7140_o ? n7143_o : 1'b0;
  /* T80_ALU.vhd:209:45  */
  assign n7146_o = n7129_o[7];
  /* T80_ALU.vhd:210:36  */
  assign n7147_o = alu_op[2:0];
  /* T80_ALU.vhd:211:25  */
  assign n7149_o = n7147_o == 3'b000;
  /* T80_ALU.vhd:211:36  */
  assign n7151_o = n7147_o == 3'b001;
  /* T80_ALU.vhd:211:36  */
  assign n7152_o = n7149_o | n7151_o;
  /* T80_ALU.vhd:211:44  */
  assign n7154_o = n7147_o == 3'b010;
  /* T80_ALU.vhd:211:44  */
  assign n7155_o = n7152_o | n7154_o;
  /* T80_ALU.vhd:211:52  */
  assign n7157_o = n7147_o == 3'b011;
  /* T80_ALU.vhd:211:52  */
  assign n7158_o = n7155_o | n7157_o;
  /* T80_ALU.vhd:211:60  */
  assign n7160_o = n7147_o == 3'b111;
  /* T80_ALU.vhd:211:60  */
  assign n7161_o = n7158_o | n7160_o;
  /* T80_ALU.vhd:213:58  */
  assign n7162_o = n7129_o[0];
  /* T80_ALU.vhd:213:69  */
  assign n7163_o = n7129_o[1];
  /* T80_ALU.vhd:213:62  */
  assign n7164_o = n7162_o ^ n7163_o;
  /* T80_ALU.vhd:213:80  */
  assign n7165_o = n7129_o[2];
  /* T80_ALU.vhd:213:73  */
  assign n7166_o = n7164_o ^ n7165_o;
  /* T80_ALU.vhd:213:91  */
  assign n7167_o = n7129_o[3];
  /* T80_ALU.vhd:213:84  */
  assign n7168_o = n7166_o ^ n7167_o;
  /* T80_ALU.vhd:214:44  */
  assign n7169_o = n7129_o[4];
  /* T80_ALU.vhd:213:95  */
  assign n7170_o = n7168_o ^ n7169_o;
  /* T80_ALU.vhd:214:55  */
  assign n7171_o = n7129_o[5];
  /* T80_ALU.vhd:214:48  */
  assign n7172_o = n7170_o ^ n7171_o;
  /* T80_ALU.vhd:214:66  */
  assign n7173_o = n7129_o[6];
  /* T80_ALU.vhd:214:59  */
  assign n7174_o = n7172_o ^ n7173_o;
  /* T80_ALU.vhd:214:77  */
  assign n7175_o = n7129_o[7];
  /* T80_ALU.vhd:214:70  */
  assign n7176_o = n7174_o ^ n7175_o;
  /* T80_ALU.vhd:213:50  */
  assign n7177_o = ~n7176_o;
  /* T80_ALU.vhd:210:25  */
  always @*
    case (n7161_o)
      1'b1: n7178_o = n7127_o;
      default: n7178_o = n7177_o;
    endcase
  /* T80_ALU.vhd:217:54  */
  assign n7179_o = f_in[7];
  /* T80_ALU.vhd:218:54  */
  assign n7180_o = f_in[6];
  /* T80_ALU.vhd:219:54  */
  assign n7181_o = f_in[2];
  assign n7182_o = {n7179_o, n7180_o};
  /* T80_ALU.vhd:216:25  */
  assign n7183_o = arith16 ? n7181_o : n7178_o;
  assign n7184_o = {n7146_o, n7145_o};
  /* T80_ALU.vhd:216:25  */
  assign n7185_o = arith16 ? n7182_o : n7184_o;
  /* T80_ALU.vhd:169:17  */
  assign n7187_o = alu_op == 4'b0000;
  /* T80_ALU.vhd:169:29  */
  assign n7189_o = alu_op == 4'b0001;
  /* T80_ALU.vhd:169:29  */
  assign n7190_o = n7187_o | n7189_o;
  /* T80_ALU.vhd:169:38  */
  assign n7192_o = alu_op == 4'b0010;
  /* T80_ALU.vhd:169:38  */
  assign n7193_o = n7190_o | n7192_o;
  /* T80_ALU.vhd:169:48  */
  assign n7195_o = alu_op == 4'b0011;
  /* T80_ALU.vhd:169:48  */
  assign n7196_o = n7193_o | n7195_o;
  /* T80_ALU.vhd:169:57  */
  assign n7198_o = alu_op == 4'b0100;
  /* T80_ALU.vhd:169:57  */
  assign n7199_o = n7196_o | n7198_o;
  /* T80_ALU.vhd:169:66  */
  assign n7201_o = alu_op == 4'b0101;
  /* T80_ALU.vhd:169:66  */
  assign n7202_o = n7199_o | n7201_o;
  /* T80_ALU.vhd:169:75  */
  assign n7204_o = alu_op == 4'b0110;
  /* T80_ALU.vhd:169:75  */
  assign n7205_o = n7202_o | n7204_o;
  /* T80_ALU.vhd:169:84  */
  assign n7207_o = alu_op == 4'b0111;
  /* T80_ALU.vhd:169:84  */
  assign n7208_o = n7205_o | n7207_o;
  /* T80_ALU.vhd:223:46  */
  assign n7209_o = f_in[4];
  /* T80_ALU.vhd:227:32  */
  assign n7212_o = f_in[1];
  /* T80_ALU.vhd:227:41  */
  assign n7213_o = ~n7212_o;
  assign n7214_o = {1'b0, busa};
  /* T80_ALU.vhd:230:41  */
  assign n7215_o = n7214_o[3:0];
  /* T80_ALU.vhd:230:54  */
  assign n7217_o = $unsigned(n7215_o) > $unsigned(4'b1001);
  /* T80_ALU.vhd:230:65  */
  assign n7218_o = f_in[4];
  /* T80_ALU.vhd:230:58  */
  assign n7219_o = n7217_o | n7218_o;
  assign n7220_o = {1'b0, busa};
  /* T80_ALU.vhd:231:50  */
  assign n7221_o = n7220_o[3:0];
  /* T80_ALU.vhd:231:63  */
  assign n7223_o = $unsigned(n7221_o) > $unsigned(4'b1001);
  /* T80_ALU.vhd:231:41  */
  assign n7226_o = n7223_o ? 1'b1 : 1'b0;
  assign n7227_o = {1'b0, busa};
  /* T80_ALU.vhd:236:56  */
  assign n7229_o = n7227_o + 9'b000000110;
  /* T80_ALU.vhd:230:33  */
  assign n7230_o = n7219_o ? n7226_o : n7209_o;
  assign n7231_o = {1'b0, busa};
  /* T80_ALU.vhd:230:33  */
  assign n7232_o = n7219_o ? n7229_o : n7231_o;
  /* T80_ALU.vhd:239:41  */
  assign n7233_o = n7232_o[8:4];
  /* T80_ALU.vhd:239:54  */
  assign n7235_o = $unsigned(n7233_o) > $unsigned(5'b01001);
  /* T80_ALU.vhd:239:65  */
  assign n7236_o = f_in[0];
  /* T80_ALU.vhd:239:58  */
  assign n7237_o = n7235_o | n7236_o;
  /* T80_ALU.vhd:240:56  */
  assign n7239_o = n7232_o + 9'b001100000;
  /* T80_ALU.vhd:239:33  */
  assign n7240_o = n7237_o ? n7239_o : n7232_o;
  assign n7241_o = {1'b0, busa};
  /* T80_ALU.vhd:244:41  */
  assign n7242_o = n7241_o[3:0];
  /* T80_ALU.vhd:244:54  */
  assign n7244_o = $unsigned(n7242_o) > $unsigned(4'b1001);
  /* T80_ALU.vhd:244:65  */
  assign n7245_o = f_in[4];
  /* T80_ALU.vhd:244:58  */
  assign n7246_o = n7244_o | n7245_o;
  assign n7247_o = {1'b0, busa};
  /* T80_ALU.vhd:245:49  */
  assign n7248_o = n7247_o[3:0];
  /* T80_ALU.vhd:245:62  */
  assign n7250_o = $unsigned(n7248_o) > $unsigned(4'b0101);
  /* T80_ALU.vhd:244:33  */
  assign n7252_o = n7257_o ? 1'b0 : n7209_o;
  assign n7253_o = {1'b0, busa};
  /* T80_ALU.vhd:248:67  */
  assign n7254_o = n7253_o[7:0];
  /* T80_ALU.vhd:248:80  */
  assign n7256_o = n7254_o - 8'b00000110;
  /* T80_ALU.vhd:244:33  */
  assign n7257_o = n7250_o & n7246_o;
  /* T80_ALU.vhd:244:33  */
  assign n7258_o = n7246_o ? n7256_o : busa;
  /* T80_ALU.vhd:250:51  */
  assign n7260_o = $unsigned(busa) > $unsigned(8'b10011001);
  /* T80_ALU.vhd:250:64  */
  assign n7261_o = f_in[0];
  /* T80_ALU.vhd:250:57  */
  assign n7262_o = n7260_o | n7261_o;
  assign n7263_o = {1'b0, n7258_o};
  /* T80_ALU.vhd:251:56  */
  assign n7265_o = n7263_o - 9'b101100000;
  assign n7266_o = {1'b0, n7258_o};
  /* T80_ALU.vhd:250:33  */
  assign n7267_o = n7262_o ? n7265_o : n7266_o;
  /* T80_ALU.vhd:227:25  */
  assign n7268_o = n7213_o ? n7230_o : n7252_o;
  /* T80_ALU.vhd:227:25  */
  assign n7269_o = n7213_o ? n7240_o : n7267_o;
  /* T80_ALU.vhd:254:47  */
  assign n7270_o = n7269_o[3];
  /* T80_ALU.vhd:255:47  */
  assign n7271_o = n7269_o[5];
  /* T80_ALU.vhd:256:46  */
  assign n7272_o = f_in[0];
  /* T80_ALU.vhd:256:63  */
  assign n7273_o = n7269_o[8];
  /* T80_ALU.vhd:256:55  */
  assign n7274_o = n7272_o | n7273_o;
  /* T80_ALU.vhd:257:54  */
  assign n7275_o = n7269_o[7:0];
  /* T80_ALU.vhd:258:33  */
  assign n7276_o = n7269_o[7:0];
  /* T80_ALU.vhd:258:46  */
  assign n7278_o = n7276_o == 8'b00000000;
  /* T80_ALU.vhd:258:25  */
  assign n7281_o = n7278_o ? 1'b1 : 1'b0;
  /* T80_ALU.vhd:263:47  */
  assign n7282_o = n7269_o[7];
  /* T80_ALU.vhd:264:52  */
  assign n7283_o = n7269_o[0];
  /* T80_ALU.vhd:264:65  */
  assign n7284_o = n7269_o[1];
  /* T80_ALU.vhd:264:56  */
  assign n7285_o = n7283_o ^ n7284_o;
  /* T80_ALU.vhd:264:78  */
  assign n7286_o = n7269_o[2];
  /* T80_ALU.vhd:264:69  */
  assign n7287_o = n7285_o ^ n7286_o;
  /* T80_ALU.vhd:264:91  */
  assign n7288_o = n7269_o[3];
  /* T80_ALU.vhd:264:82  */
  assign n7289_o = n7287_o ^ n7288_o;
  /* T80_ALU.vhd:265:38  */
  assign n7290_o = n7269_o[4];
  /* T80_ALU.vhd:264:95  */
  assign n7291_o = n7289_o ^ n7290_o;
  /* T80_ALU.vhd:265:51  */
  assign n7292_o = n7269_o[5];
  /* T80_ALU.vhd:265:42  */
  assign n7293_o = n7291_o ^ n7292_o;
  /* T80_ALU.vhd:265:64  */
  assign n7294_o = n7269_o[6];
  /* T80_ALU.vhd:265:55  */
  assign n7295_o = n7293_o ^ n7294_o;
  /* T80_ALU.vhd:265:77  */
  assign n7296_o = n7269_o[7];
  /* T80_ALU.vhd:265:68  */
  assign n7297_o = n7295_o ^ n7296_o;
  /* T80_ALU.vhd:264:42  */
  assign n7298_o = ~n7297_o;
  /* T80_ALU.vhd:221:17  */
  assign n7300_o = alu_op == 4'b1100;
  /* T80_ALU.vhd:268:48  */
  assign n7301_o = busa[7:4];
  /* T80_ALU.vhd:269:34  */
  assign n7302_o = alu_op[0];
  /* T80_ALU.vhd:270:56  */
  assign n7303_o = busb[7:4];
  /* T80_ALU.vhd:272:56  */
  assign n7304_o = busb[3:0];
  /* T80_ALU.vhd:269:25  */
  assign n7305_o = n7302_o ? n7303_o : n7304_o;
  assign n7308_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:276:45  */
  assign n7309_o = n7308_o[3];
  assign n7310_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:277:45  */
  assign n7311_o = n7310_o[5];
  assign n7312_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:278:44  */
  assign n7314_o = n7312_o == 8'b00000000;
  /* T80_ALU.vhd:278:25  */
  assign n7317_o = n7314_o ? 1'b1 : 1'b0;
  assign n7318_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:283:45  */
  assign n7319_o = n7318_o[7];
  assign n7320_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:284:50  */
  assign n7321_o = n7320_o[0];
  assign n7322_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:284:61  */
  assign n7323_o = n7322_o[1];
  /* T80_ALU.vhd:284:54  */
  assign n7324_o = n7321_o ^ n7323_o;
  assign n7325_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:284:72  */
  assign n7326_o = n7325_o[2];
  /* T80_ALU.vhd:284:65  */
  assign n7327_o = n7324_o ^ n7326_o;
  assign n7328_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:284:83  */
  assign n7329_o = n7328_o[3];
  /* T80_ALU.vhd:284:76  */
  assign n7330_o = n7327_o ^ n7329_o;
  assign n7331_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:285:36  */
  assign n7332_o = n7331_o[4];
  /* T80_ALU.vhd:284:87  */
  assign n7333_o = n7330_o ^ n7332_o;
  assign n7334_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:285:47  */
  assign n7335_o = n7334_o[5];
  /* T80_ALU.vhd:285:40  */
  assign n7336_o = n7333_o ^ n7335_o;
  assign n7337_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:285:58  */
  assign n7338_o = n7337_o[6];
  /* T80_ALU.vhd:285:51  */
  assign n7339_o = n7336_o ^ n7338_o;
  assign n7340_o = {n7301_o, n7305_o};
  /* T80_ALU.vhd:285:69  */
  assign n7341_o = n7340_o[7];
  /* T80_ALU.vhd:285:62  */
  assign n7342_o = n7339_o ^ n7341_o;
  /* T80_ALU.vhd:284:42  */
  assign n7343_o = ~n7342_o;
  /* T80_ALU.vhd:266:17  */
  assign n7345_o = alu_op == 4'b1101;
  /* T80_ALU.vhd:266:29  */
  assign n7347_o = alu_op == 4'b1110;
  /* T80_ALU.vhd:266:29  */
  assign n7348_o = n7345_o | n7347_o;
  /* T80_ALU.vhd:288:49  */
  assign n7349_o = busb & bitmask;
  /* T80_ALU.vhd:289:45  */
  assign n7350_o = n7349_o[7];
  /* T80_ALU.vhd:290:44  */
  assign n7352_o = n7349_o == 8'b00000000;
  /* T80_ALU.vhd:290:25  */
  assign n7357_o = n7352_o ? 1'b1 : 1'b0;
  /* T80_ALU.vhd:290:25  */
  assign n7358_o = n7352_o ? 1'b1 : 1'b0;
  /* T80_ALU.vhd:299:30  */
  assign n7361_o = ir[2:0];
  /* T80_ALU.vhd:299:43  */
  assign n7363_o = n7361_o == 3'b110;
  /* T80_ALU.vhd:299:63  */
  assign n7365_o = xy_state != 2'b00;
  /* T80_ALU.vhd:299:51  */
  assign n7366_o = n7363_o | n7365_o;
  /* T80_ALU.vhd:300:52  */
  assign n7367_o = wz[11];
  /* T80_ALU.vhd:301:52  */
  assign n7368_o = wz[13];
  /* T80_ALU.vhd:303:54  */
  assign n7369_o = busb[3];
  /* T80_ALU.vhd:304:54  */
  assign n7370_o = busb[5];
  /* T80_ALU.vhd:299:25  */
  assign n7371_o = n7366_o ? n7367_o : n7369_o;
  /* T80_ALU.vhd:299:25  */
  assign n7372_o = n7366_o ? n7368_o : n7370_o;
  /* T80_ALU.vhd:286:17  */
  assign n7374_o = alu_op == 4'b1001;
  /* T80_ALU.vhd:308:49  */
  assign n7375_o = busb | bitmask;
  /* T80_ALU.vhd:306:17  */
  assign n7377_o = alu_op == 4'b1010;
  /* T80_ALU.vhd:311:53  */
  assign n7378_o = ~bitmask;
  /* T80_ALU.vhd:311:49  */
  assign n7379_o = busb & n7378_o;
  /* T80_ALU.vhd:309:17  */
  assign n7381_o = alu_op == 4'b1011;
  /* T80_ALU.vhd:314:32  */
  assign n7382_o = ir[5:3];
  /* T80_ALU.vhd:316:56  */
  assign n7383_o = busa[6:0];
  /* T80_ALU.vhd:317:47  */
  assign n7384_o = busa[7];
  /* T80_ALU.vhd:318:54  */
  assign n7385_o = busa[7];
  /* T80_ALU.vhd:315:25  */
  assign n7387_o = n7382_o == 3'b000;
  /* T80_ALU.vhd:320:56  */
  assign n7388_o = busa[6:0];
  /* T80_ALU.vhd:321:47  */
  assign n7389_o = f_in[0];
  /* T80_ALU.vhd:322:54  */
  assign n7390_o = busa[7];
  /* T80_ALU.vhd:319:25  */
  assign n7392_o = n7382_o == 3'b010;
  /* T80_ALU.vhd:324:56  */
  assign n7393_o = busa[7:1];
  /* T80_ALU.vhd:325:47  */
  assign n7394_o = busa[0];
  /* T80_ALU.vhd:326:54  */
  assign n7395_o = busa[0];
  /* T80_ALU.vhd:323:25  */
  assign n7397_o = n7382_o == 3'b001;
  /* T80_ALU.vhd:328:56  */
  assign n7398_o = busa[7:1];
  /* T80_ALU.vhd:329:47  */
  assign n7399_o = f_in[0];
  /* T80_ALU.vhd:330:54  */
  assign n7400_o = busa[0];
  /* T80_ALU.vhd:327:25  */
  assign n7402_o = n7382_o == 3'b011;
  /* T80_ALU.vhd:332:56  */
  assign n7403_o = busa[6:0];
  /* T80_ALU.vhd:334:54  */
  assign n7405_o = busa[7];
  /* T80_ALU.vhd:331:25  */
  assign n7407_o = n7382_o == 3'b100;
  /* T80_ALU.vhd:341:64  */
  assign n7408_o = busa[6:0];
  /* T80_ALU.vhd:343:62  */
  assign n7410_o = busa[7];
  /* T80_ALU.vhd:335:25  */
  assign n7412_o = n7382_o == 3'b110;
  /* T80_ALU.vhd:346:56  */
  assign n7413_o = busa[7:1];
  /* T80_ALU.vhd:347:47  */
  assign n7414_o = busa[7];
  /* T80_ALU.vhd:348:54  */
  assign n7415_o = busa[0];
  /* T80_ALU.vhd:345:25  */
  assign n7417_o = n7382_o == 3'b101;
  /* T80_ALU.vhd:350:56  */
  assign n7418_o = busa[7:1];
  /* T80_ALU.vhd:352:54  */
  assign n7420_o = busa[0];
  assign n7421_o = {n7417_o, n7412_o, n7407_o, n7402_o, n7397_o, n7392_o, n7387_o};
  /* T80_ALU.vhd:314:25  */
  always @*
    case (n7421_o)
      7'b1000000: n7422_o = n7415_o;
      7'b0100000: n7422_o = n7410_o;
      7'b0010000: n7422_o = n7405_o;
      7'b0001000: n7422_o = n7400_o;
      7'b0000100: n7422_o = n7395_o;
      7'b0000010: n7422_o = n7390_o;
      7'b0000001: n7422_o = n7385_o;
      default: n7422_o = n7420_o;
    endcase
  assign n7423_o = n7393_o[0];
  assign n7424_o = n7398_o[0];
  assign n7425_o = n7413_o[0];
  assign n7426_o = n7418_o[0];
  /* T80_ALU.vhd:314:25  */
  always @*
    case (n7421_o)
      7'b1000000: n7427_o = n7425_o;
      7'b0100000: n7427_o = 1'b1;
      7'b0010000: n7427_o = 1'b0;
      7'b0001000: n7427_o = n7424_o;
      7'b0000100: n7427_o = n7423_o;
      7'b0000010: n7427_o = n7389_o;
      7'b0000001: n7427_o = n7384_o;
      default: n7427_o = n7426_o;
    endcase
  assign n7428_o = n7383_o[5:0];
  assign n7429_o = n7388_o[5:0];
  assign n7430_o = n7393_o[6:1];
  assign n7431_o = n7398_o[6:1];
  assign n7432_o = n7403_o[5:0];
  assign n7433_o = n7408_o[5:0];
  assign n7434_o = n7413_o[6:1];
  assign n7435_o = n7418_o[6:1];
  /* T80_ALU.vhd:314:25  */
  always @*
    case (n7421_o)
      7'b1000000: n7436_o = n7434_o;
      7'b0100000: n7436_o = n7433_o;
      7'b0010000: n7436_o = n7432_o;
      7'b0001000: n7436_o = n7431_o;
      7'b0000100: n7436_o = n7430_o;
      7'b0000010: n7436_o = n7429_o;
      7'b0000001: n7436_o = n7428_o;
      default: n7436_o = n7435_o;
    endcase
  assign n7437_o = n7383_o[6];
  assign n7438_o = n7388_o[6];
  assign n7439_o = n7403_o[6];
  assign n7440_o = n7408_o[6];
  /* T80_ALU.vhd:314:25  */
  always @*
    case (n7421_o)
      7'b1000000: n7441_o = n7414_o;
      7'b0100000: n7441_o = n7440_o;
      7'b0010000: n7441_o = n7439_o;
      7'b0001000: n7441_o = n7399_o;
      7'b0000100: n7441_o = n7394_o;
      7'b0000010: n7441_o = n7438_o;
      7'b0000001: n7441_o = n7437_o;
      default: n7441_o = 1'b0;
    endcase
  assign n7444_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:356:45  */
  assign n7445_o = n7444_o[3];
  assign n7446_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:357:45  */
  assign n7447_o = n7446_o[5];
  assign n7448_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:358:45  */
  assign n7449_o = n7448_o[7];
  assign n7450_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:359:44  */
  assign n7452_o = n7450_o == 8'b00000000;
  /* T80_ALU.vhd:359:25  */
  assign n7455_o = n7452_o ? 1'b1 : 1'b0;
  assign n7456_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:364:50  */
  assign n7457_o = n7456_o[0];
  assign n7458_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:364:61  */
  assign n7459_o = n7458_o[1];
  /* T80_ALU.vhd:364:54  */
  assign n7460_o = n7457_o ^ n7459_o;
  assign n7461_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:364:72  */
  assign n7462_o = n7461_o[2];
  /* T80_ALU.vhd:364:65  */
  assign n7463_o = n7460_o ^ n7462_o;
  assign n7464_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:364:83  */
  assign n7465_o = n7464_o[3];
  /* T80_ALU.vhd:364:76  */
  assign n7466_o = n7463_o ^ n7465_o;
  assign n7467_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:365:36  */
  assign n7468_o = n7467_o[4];
  /* T80_ALU.vhd:364:87  */
  assign n7469_o = n7466_o ^ n7468_o;
  assign n7470_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:365:47  */
  assign n7471_o = n7470_o[5];
  /* T80_ALU.vhd:365:40  */
  assign n7472_o = n7469_o ^ n7471_o;
  assign n7473_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:365:58  */
  assign n7474_o = n7473_o[6];
  /* T80_ALU.vhd:365:51  */
  assign n7475_o = n7472_o ^ n7474_o;
  assign n7476_o = {n7441_o, n7436_o, n7427_o};
  /* T80_ALU.vhd:365:69  */
  assign n7477_o = n7476_o[7];
  /* T80_ALU.vhd:365:62  */
  assign n7478_o = n7475_o ^ n7477_o;
  /* T80_ALU.vhd:364:42  */
  assign n7479_o = ~n7478_o;
  /* T80_ALU.vhd:366:33  */
  assign n7481_o = iset == 2'b00;
  /* T80_ALU.vhd:367:54  */
  assign n7482_o = f_in[2];
  /* T80_ALU.vhd:368:54  */
  assign n7483_o = f_in[7];
  /* T80_ALU.vhd:369:54  */
  assign n7484_o = f_in[6];
  assign n7485_o = {n7483_o, n7484_o};
  /* T80_ALU.vhd:366:25  */
  assign n7486_o = n7481_o ? n7482_o : n7479_o;
  assign n7487_o = {n7449_o, n7455_o};
  /* T80_ALU.vhd:366:25  */
  assign n7488_o = n7481_o ? n7485_o : n7487_o;
  /* T80_ALU.vhd:312:17  */
  assign n7490_o = alu_op == 4'b1000;
  assign n7491_o = {n7490_o, n7381_o, n7377_o, n7374_o, n7348_o, n7300_o, n7208_o};
  assign n7492_o = f_in[0];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7493_o = n7422_o;
      7'b0100000: n7493_o = n7492_o;
      7'b0010000: n7493_o = n7492_o;
      7'b0001000: n7493_o = n7492_o;
      7'b0000100: n7493_o = n7492_o;
      7'b0000010: n7493_o = n7274_o;
      7'b0000001: n7493_o = n7124_o;
      default: n7493_o = n7492_o;
    endcase
  assign n7494_o = f_in[1];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7495_o = 1'b0;
      7'b0100000: n7495_o = n7494_o;
      7'b0010000: n7495_o = n7494_o;
      7'b0001000: n7495_o = 1'b0;
      7'b0000100: n7495_o = 1'b0;
      7'b0000010: n7495_o = n7494_o;
      7'b0000001: n7495_o = n7125_o;
      default: n7495_o = n7494_o;
    endcase
  assign n7496_o = f_in[2];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7497_o = n7486_o;
      7'b0100000: n7497_o = n7496_o;
      7'b0010000: n7497_o = n7496_o;
      7'b0001000: n7497_o = n7357_o;
      7'b0000100: n7497_o = n7343_o;
      7'b0000010: n7497_o = n7298_o;
      7'b0000001: n7497_o = n7183_o;
      default: n7497_o = n7496_o;
    endcase
  assign n7498_o = f_in[3];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7499_o = n7445_o;
      7'b0100000: n7499_o = n7498_o;
      7'b0010000: n7499_o = n7498_o;
      7'b0001000: n7499_o = n7371_o;
      7'b0000100: n7499_o = n7309_o;
      7'b0000010: n7499_o = n7270_o;
      7'b0000001: n7499_o = n7137_o;
      default: n7499_o = n7498_o;
    endcase
  assign n7500_o = f_in[4];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7501_o = 1'b0;
      7'b0100000: n7501_o = n7500_o;
      7'b0010000: n7501_o = n7500_o;
      7'b0001000: n7501_o = 1'b1;
      7'b0000100: n7501_o = 1'b0;
      7'b0000010: n7501_o = n7268_o;
      7'b0000001: n7501_o = n7128_o;
      default: n7501_o = n7500_o;
    endcase
  assign n7502_o = f_in[5];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7503_o = n7447_o;
      7'b0100000: n7503_o = n7502_o;
      7'b0010000: n7503_o = n7502_o;
      7'b0001000: n7503_o = n7372_o;
      7'b0000100: n7503_o = n7311_o;
      7'b0000010: n7503_o = n7271_o;
      7'b0000001: n7503_o = n7138_o;
      default: n7503_o = n7502_o;
    endcase
  assign n7504_o = n7185_o[0];
  assign n7505_o = n7488_o[0];
  assign n7506_o = f_in[6];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7507_o = n7505_o;
      7'b0100000: n7507_o = n7506_o;
      7'b0010000: n7507_o = n7506_o;
      7'b0001000: n7507_o = n7358_o;
      7'b0000100: n7507_o = n7317_o;
      7'b0000010: n7507_o = n7281_o;
      7'b0000001: n7507_o = n7504_o;
      default: n7507_o = n7506_o;
    endcase
  assign n7508_o = n7185_o[1];
  assign n7509_o = n7488_o[1];
  assign n7510_o = f_in[7];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7511_o = n7509_o;
      7'b0100000: n7511_o = n7510_o;
      7'b0010000: n7511_o = n7510_o;
      7'b0001000: n7511_o = n7350_o;
      7'b0000100: n7511_o = n7319_o;
      7'b0000010: n7511_o = n7282_o;
      7'b0000001: n7511_o = n7508_o;
      default: n7511_o = n7510_o;
    endcase
  assign n7519_o = n7129_o[0];
  assign n7520_o = n7275_o[0];
  assign n7521_o = n7305_o[0];
  assign n7522_o = n7349_o[0];
  assign n7523_o = n7375_o[0];
  assign n7524_o = n7379_o[0];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7526_o = n7427_o;
      7'b0100000: n7526_o = n7524_o;
      7'b0010000: n7526_o = n7523_o;
      7'b0001000: n7526_o = n7522_o;
      7'b0000100: n7526_o = n7521_o;
      7'b0000010: n7526_o = n7520_o;
      7'b0000001: n7526_o = n7519_o;
      default: n7526_o = 1'bX;
    endcase
  assign n7527_o = n7129_o[3:1];
  assign n7528_o = n7275_o[3:1];
  assign n7529_o = n7305_o[3:1];
  assign n7530_o = n7349_o[3:1];
  assign n7531_o = n7375_o[3:1];
  assign n7532_o = n7379_o[3:1];
  assign n7533_o = n7436_o[2:0];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7535_o = n7533_o;
      7'b0100000: n7535_o = n7532_o;
      7'b0010000: n7535_o = n7531_o;
      7'b0001000: n7535_o = n7530_o;
      7'b0000100: n7535_o = n7529_o;
      7'b0000010: n7535_o = n7528_o;
      7'b0000001: n7535_o = n7527_o;
      default: n7535_o = 3'bX;
    endcase
  assign n7536_o = n7129_o[6:4];
  assign n7537_o = n7275_o[6:4];
  assign n7538_o = n7301_o[2:0];
  assign n7539_o = n7349_o[6:4];
  assign n7540_o = n7375_o[6:4];
  assign n7541_o = n7379_o[6:4];
  assign n7542_o = n7436_o[5:3];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7544_o = n7542_o;
      7'b0100000: n7544_o = n7541_o;
      7'b0010000: n7544_o = n7540_o;
      7'b0001000: n7544_o = n7539_o;
      7'b0000100: n7544_o = n7538_o;
      7'b0000010: n7544_o = n7537_o;
      7'b0000001: n7544_o = n7536_o;
      default: n7544_o = 3'bX;
    endcase
  assign n7545_o = n7129_o[7];
  assign n7546_o = n7275_o[7];
  assign n7547_o = n7301_o[3];
  assign n7548_o = n7349_o[7];
  assign n7549_o = n7375_o[7];
  assign n7550_o = n7379_o[7];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7491_o)
      7'b1000000: n7552_o = n7441_o;
      7'b0100000: n7552_o = n7550_o;
      7'b0010000: n7552_o = n7549_o;
      7'b0001000: n7552_o = n7548_o;
      7'b0000100: n7552_o = n7547_o;
      7'b0000010: n7552_o = n7546_o;
      7'b0000001: n7552_o = n7545_o;
      default: n7552_o = 1'bX;
    endcase
  assign n7560_o = {n7552_o, n7544_o, n7535_o, n7526_o};
  assign n7563_o = {n7070_o, n7048_o, n7026_o};
  assign n7564_o = {n7511_o, n7507_o, n7503_o, n7501_o, n7499_o, n7497_o, n7495_o, n7493_o};
endmodule

module t8080_mcode
  (input  [7:0] ir,
   input  [1:0] iset,
   input  [2:0] mcycle,
   input  [7:0] f,
   input  nmicycle,
   input  intcycle,
   input  [1:0] xy_state,
   output [2:0] mcycles,
   output [2:0] tstates,
   output [1:0] prefix,
   output inc_pc,
   output inc_wz,
   output [3:0] incdec_16,
   output read_to_reg,
   output read_to_acc,
   output [3:0] set_busa_to,
   output [3:0] set_busb_to,
   output [3:0] alu_op,
   output save_alu,
   output preservec,
   output arith16,
   output [2:0] set_addr_to,
   output iorq,
   output jump,
   output jumpe,
   output jumpxy,
   output call,
   output rstp,
   output ldz,
   output ldw,
   output ldsphl,
   output [2:0] special_ld,
   output exchangedh,
   output exchangerp,
   output exchangeaf,
   output exchangers,
   output i_djnz,
   output i_cpl,
   output i_ccf,
   output i_scf,
   output i_retn,
   output i_bt,
   output i_bc,
   output i_btr,
   output i_rld,
   output i_rrd,
   output i_inrc,
   output [1:0] setwz,
   output setdi,
   output setei,
   output [1:0] imode,
   output halt,
   output noread,
   output write,
   output xybit_undoc);
  wire [2:0] n2172_o;
  wire [2:0] n2173_o;
  wire [1:0] n2174_o;
  wire n2176_o;
  wire [2:0] n2179_o;
  wire [2:0] n2180_o;
  wire [3:0] n2182_o;
  wire n2184_o;
  wire n2186_o;
  wire n2187_o;
  wire n2189_o;
  wire n2190_o;
  wire n2192_o;
  wire n2193_o;
  wire n2195_o;
  wire n2196_o;
  wire n2198_o;
  wire n2199_o;
  wire n2201_o;
  wire n2202_o;
  wire n2204_o;
  wire n2205_o;
  wire n2207_o;
  wire n2208_o;
  wire n2210_o;
  wire n2211_o;
  wire n2213_o;
  wire n2214_o;
  wire n2216_o;
  wire n2217_o;
  wire n2219_o;
  wire n2220_o;
  wire n2222_o;
  wire n2223_o;
  wire n2225_o;
  wire n2226_o;
  wire n2228_o;
  wire n2229_o;
  wire n2231_o;
  wire n2232_o;
  wire n2234_o;
  wire n2235_o;
  wire n2237_o;
  wire n2238_o;
  wire n2240_o;
  wire n2241_o;
  wire n2243_o;
  wire n2244_o;
  wire n2246_o;
  wire n2247_o;
  wire n2249_o;
  wire n2250_o;
  wire n2252_o;
  wire n2253_o;
  wire n2255_o;
  wire n2256_o;
  wire n2258_o;
  wire n2259_o;
  wire n2261_o;
  wire n2262_o;
  wire n2264_o;
  wire n2265_o;
  wire n2267_o;
  wire n2268_o;
  wire n2270_o;
  wire n2271_o;
  wire n2273_o;
  wire n2274_o;
  wire n2276_o;
  wire n2277_o;
  wire n2279_o;
  wire n2280_o;
  wire n2282_o;
  wire n2283_o;
  wire n2285_o;
  wire n2286_o;
  wire n2288_o;
  wire n2289_o;
  wire n2291_o;
  wire n2292_o;
  wire n2294_o;
  wire n2295_o;
  wire n2297_o;
  wire n2298_o;
  wire n2300_o;
  wire n2301_o;
  wire n2303_o;
  wire n2304_o;
  wire n2306_o;
  wire n2307_o;
  wire n2309_o;
  wire n2310_o;
  wire n2312_o;
  wire n2313_o;
  wire n2315_o;
  wire n2316_o;
  wire n2318_o;
  wire n2319_o;
  wire n2321_o;
  wire n2322_o;
  wire n2324_o;
  wire n2325_o;
  wire n2327_o;
  wire n2328_o;
  wire [30:0] n2329_o;
  wire n2331_o;
  reg n2334_o;
  reg n2337_o;
  reg [2:0] n2339_o;
  wire n2341_o;
  wire n2343_o;
  wire n2344_o;
  wire n2346_o;
  wire n2347_o;
  wire n2349_o;
  wire n2350_o;
  wire n2352_o;
  wire n2353_o;
  wire n2355_o;
  wire n2356_o;
  wire n2358_o;
  wire n2359_o;
  wire [30:0] n2360_o;
  wire n2362_o;
  wire n2364_o;
  wire [1:0] n2365_o;
  reg n2368_o;
  reg [2:0] n2370_o;
  reg [2:0] n2373_o;
  wire n2375_o;
  wire n2377_o;
  wire n2378_o;
  wire n2380_o;
  wire n2381_o;
  wire n2383_o;
  wire n2384_o;
  wire n2386_o;
  wire n2387_o;
  wire n2389_o;
  wire n2390_o;
  wire n2392_o;
  wire n2393_o;
  wire [30:0] n2394_o;
  wire n2397_o;
  wire n2399_o;
  wire [1:0] n2400_o;
  reg [2:0] n2402_o;
  reg n2404_o;
  reg [2:0] n2407_o;
  reg n2410_o;
  wire n2412_o;
  wire n2414_o;
  wire n2415_o;
  wire n2417_o;
  wire n2418_o;
  wire n2420_o;
  wire n2421_o;
  wire n2423_o;
  wire n2424_o;
  wire n2426_o;
  wire n2427_o;
  wire n2429_o;
  wire n2430_o;
  wire [30:0] n2431_o;
  wire n2434_o;
  wire n2436_o;
  wire [1:0] n2437_o;
  reg n2440_o;
  reg [2:0] n2442_o;
  reg n2444_o;
  reg [2:0] n2447_o;
  reg n2450_o;
  wire n2452_o;
  wire [30:0] n2453_o;
  wire n2455_o;
  wire n2457_o;
  wire [1:0] n2458_o;
  reg n2461_o;
  reg [2:0] n2464_o;
  wire n2466_o;
  wire [30:0] n2467_o;
  wire n2469_o;
  wire n2471_o;
  wire [1:0] n2472_o;
  reg n2475_o;
  reg [2:0] n2478_o;
  wire n2480_o;
  wire [30:0] n2481_o;
  wire n2483_o;
  wire n2485_o;
  wire n2487_o;
  wire [2:0] n2488_o;
  reg n2492_o;
  reg n2495_o;
  reg [2:0] n2498_o;
  reg n2501_o;
  wire n2503_o;
  wire [30:0] n2504_o;
  wire n2506_o;
  wire n2508_o;
  wire [1:0] n2509_o;
  reg [3:0] n2512_o;
  reg [2:0] n2515_o;
  reg [1:0] n2518_o;
  reg n2521_o;
  wire n2523_o;
  wire [30:0] n2524_o;
  wire n2526_o;
  wire n2528_o;
  wire [1:0] n2529_o;
  reg [3:0] n2532_o;
  reg [2:0] n2535_o;
  reg [1:0] n2538_o;
  reg n2541_o;
  wire n2543_o;
  wire [30:0] n2544_o;
  wire n2546_o;
  wire n2548_o;
  wire n2550_o;
  wire [2:0] n2551_o;
  reg n2555_o;
  reg [3:0] n2558_o;
  reg [2:0] n2561_o;
  reg n2564_o;
  reg [1:0] n2567_o;
  reg n2570_o;
  wire n2572_o;
  wire [30:0] n2573_o;
  wire n2575_o;
  wire [2:0] n2577_o;
  wire [2:0] n2579_o;
  wire n2582_o;
  wire n2584_o;
  wire n2586_o;
  wire [2:0] n2588_o;
  wire [2:0] n2590_o;
  wire n2593_o;
  wire n2595_o;
  wire [1:0] n2596_o;
  reg n2600_o;
  reg n2604_o;
  reg [2:0] n2606_o;
  reg n2608_o;
  wire n2610_o;
  wire n2612_o;
  wire n2613_o;
  wire n2615_o;
  wire n2616_o;
  wire n2618_o;
  wire n2619_o;
  wire [30:0] n2620_o;
  wire n2622_o;
  wire n2624_o;
  wire n2627_o;
  wire n2630_o;
  wire [3:0] n2631_o;
  reg n2635_o;
  reg n2638_o;
  reg n2642_o;
  reg [2:0] n2644_o;
  reg [2:0] n2648_o;
  reg n2651_o;
  reg n2654_o;
  wire n2656_o;
  wire [30:0] n2657_o;
  wire n2659_o;
  wire n2661_o;
  wire n2663_o;
  wire n2665_o;
  wire [3:0] n2666_o;
  reg n2670_o;
  reg n2673_o;
  reg [3:0] n2677_o;
  reg [2:0] n2681_o;
  reg n2684_o;
  reg n2687_o;
  reg n2691_o;
  wire n2693_o;
  wire n2695_o;
  wire [30:0] n2696_o;
  wire n2698_o;
  wire [3:0] n2701_o;
  wire [3:0] n2703_o;
  wire n2705_o;
  wire n2707_o;
  wire [3:0] n2710_o;
  wire [3:0] n2712_o;
  wire n2714_o;
  wire n2716_o;
  wire [2:0] n2717_o;
  reg [2:0] n2719_o;
  reg [3:0] n2723_o;
  reg [3:0] n2725_o;
  reg [2:0] n2729_o;
  reg n2733_o;
  wire n2735_o;
  wire n2737_o;
  wire n2738_o;
  wire n2740_o;
  wire n2741_o;
  wire n2743_o;
  wire n2744_o;
  wire [30:0] n2745_o;
  wire n2747_o;
  wire n2749_o;
  wire [2:0] n2751_o;
  wire [2:0] n2753_o;
  wire n2756_o;
  wire n2758_o;
  wire n2760_o;
  wire [2:0] n2762_o;
  wire [2:0] n2764_o;
  wire n2767_o;
  wire n2769_o;
  wire [2:0] n2770_o;
  reg [3:0] n2774_o;
  reg n2778_o;
  reg [2:0] n2780_o;
  reg n2782_o;
  reg [2:0] n2786_o;
  wire n2788_o;
  wire n2790_o;
  wire n2791_o;
  wire n2793_o;
  wire n2794_o;
  wire n2796_o;
  wire n2797_o;
  wire n2799_o;
  wire n2801_o;
  wire n2803_o;
  wire [30:0] n2804_o;
  wire n2806_o;
  wire n2808_o;
  wire n2810_o;
  wire n2812_o;
  wire n2814_o;
  wire [4:0] n2815_o;
  reg [2:0] n2818_o;
  reg [3:0] n2822_o;
  reg n2826_o;
  reg [3:0] n2830_o;
  reg [3:0] n2834_o;
  reg [2:0] n2840_o;
  reg n2843_o;
  reg n2846_o;
  reg n2850_o;
  wire n2852_o;
  wire n2855_o;
  wire n2857_o;
  wire n2858_o;
  wire n2860_o;
  wire n2861_o;
  wire n2863_o;
  wire n2864_o;
  wire n2866_o;
  wire n2867_o;
  wire n2869_o;
  wire n2870_o;
  wire n2872_o;
  wire n2873_o;
  wire n2875_o;
  wire n2876_o;
  wire n2878_o;
  wire n2879_o;
  wire n2881_o;
  wire n2882_o;
  wire n2884_o;
  wire n2885_o;
  wire n2887_o;
  wire n2888_o;
  wire n2890_o;
  wire n2891_o;
  wire n2893_o;
  wire n2894_o;
  wire n2896_o;
  wire n2897_o;
  wire n2899_o;
  wire n2900_o;
  wire n2902_o;
  wire n2903_o;
  wire n2905_o;
  wire n2906_o;
  wire n2908_o;
  wire n2909_o;
  wire n2911_o;
  wire n2912_o;
  wire n2914_o;
  wire n2915_o;
  wire n2917_o;
  wire n2918_o;
  wire n2920_o;
  wire n2921_o;
  wire n2923_o;
  wire n2924_o;
  wire n2926_o;
  wire n2927_o;
  wire n2929_o;
  wire n2930_o;
  wire n2932_o;
  wire n2933_o;
  wire n2935_o;
  wire n2936_o;
  wire n2938_o;
  wire n2939_o;
  wire n2941_o;
  wire n2942_o;
  wire n2944_o;
  wire n2945_o;
  wire n2947_o;
  wire n2948_o;
  wire n2950_o;
  wire n2951_o;
  wire n2953_o;
  wire n2954_o;
  wire n2956_o;
  wire n2957_o;
  wire n2959_o;
  wire n2960_o;
  wire n2962_o;
  wire n2963_o;
  wire n2965_o;
  wire n2966_o;
  wire n2968_o;
  wire n2969_o;
  wire n2971_o;
  wire n2972_o;
  wire n2974_o;
  wire n2975_o;
  wire n2977_o;
  wire n2978_o;
  wire n2980_o;
  wire n2981_o;
  wire n2983_o;
  wire n2984_o;
  wire n2986_o;
  wire n2987_o;
  wire n2989_o;
  wire n2990_o;
  wire n2992_o;
  wire n2993_o;
  wire n2995_o;
  wire n2996_o;
  wire n2998_o;
  wire n2999_o;
  wire n3001_o;
  wire n3002_o;
  wire n3004_o;
  wire n3005_o;
  wire n3007_o;
  wire n3008_o;
  wire n3010_o;
  wire n3011_o;
  wire n3013_o;
  wire n3014_o;
  wire n3016_o;
  wire n3017_o;
  wire n3019_o;
  wire n3020_o;
  wire [30:0] n3021_o;
  wire n3023_o;
  wire n3026_o;
  wire [1:0] n3027_o;
  reg n3030_o;
  reg [2:0] n3032_o;
  reg [2:0] n3034_o;
  reg n3037_o;
  reg [2:0] n3040_o;
  wire n3042_o;
  wire n3044_o;
  wire n3045_o;
  wire n3047_o;
  wire n3048_o;
  wire n3050_o;
  wire n3051_o;
  wire n3053_o;
  wire n3054_o;
  wire n3056_o;
  wire n3057_o;
  wire n3059_o;
  wire n3060_o;
  wire n3062_o;
  wire n3063_o;
  wire n3065_o;
  wire n3069_o;
  wire n3072_o;
  wire [2:0] n3074_o;
  wire [2:0] n3076_o;
  wire n3079_o;
  wire n3081_o;
  wire n3083_o;
  wire n3084_o;
  wire n3086_o;
  wire n3087_o;
  wire n3089_o;
  wire n3090_o;
  wire n3092_o;
  wire n3093_o;
  wire n3095_o;
  wire n3096_o;
  wire n3098_o;
  wire n3099_o;
  wire n3101_o;
  wire n3102_o;
  wire n3104_o;
  wire n3106_o;
  wire n3107_o;
  wire n3109_o;
  wire n3110_o;
  wire n3112_o;
  wire n3113_o;
  wire n3115_o;
  wire n3116_o;
  wire n3118_o;
  wire n3119_o;
  wire n3121_o;
  wire n3122_o;
  wire [30:0] n3123_o;
  wire n3125_o;
  wire n3127_o;
  wire n3129_o;
  wire [2:0] n3130_o;
  reg [2:0] n3132_o;
  reg n3135_o;
  reg [2:0] n3137_o;
  reg [3:0] n3140_o;
  reg [3:0] n3142_o;
  reg n3145_o;
  reg n3148_o;
  reg [2:0] n3152_o;
  reg n3155_o;
  wire n3157_o;
  wire n3159_o;
  wire n3161_o;
  wire n3162_o;
  wire n3164_o;
  wire n3165_o;
  wire n3167_o;
  wire n3168_o;
  wire n3170_o;
  wire n3171_o;
  wire n3173_o;
  wire n3174_o;
  wire n3176_o;
  wire n3177_o;
  wire [30:0] n3178_o;
  wire n3180_o;
  wire n3182_o;
  wire n3184_o;
  wire [2:0] n3185_o;
  reg [2:0] n3187_o;
  reg n3190_o;
  reg [2:0] n3192_o;
  reg [3:0] n3195_o;
  reg [3:0] n3197_o;
  reg n3200_o;
  reg n3203_o;
  reg [2:0] n3207_o;
  reg n3210_o;
  wire n3212_o;
  wire n3215_o;
  wire n3217_o;
  wire n3219_o;
  wire n3221_o;
  wire [30:0] n3222_o;
  wire n3224_o;
  wire n3226_o;
  wire n3228_o;
  wire [2:0] n3229_o;
  reg [2:0] n3231_o;
  reg [3:0] n3235_o;
  reg [3:0] n3239_o;
  reg [2:0] n3243_o;
  reg n3247_o;
  wire [30:0] n3248_o;
  wire n3250_o;
  wire n3252_o;
  wire n3254_o;
  wire n3256_o;
  wire n3258_o;
  wire [4:0] n3259_o;
  reg [2:0] n3261_o;
  reg n3264_o;
  reg [3:0] n3268_o;
  reg [3:0] n3272_o;
  reg [2:0] n3276_o;
  reg n3279_o;
  reg n3283_o;
  reg n3287_o;
  wire [2:0] n3290_o;
  wire [2:0] n3291_o;
  wire n3293_o;
  wire [3:0] n3295_o;
  wire [3:0] n3297_o;
  wire [2:0] n3299_o;
  wire n3301_o;
  wire n3303_o;
  wire n3305_o;
  wire [2:0] n3307_o;
  wire [2:0] n3308_o;
  wire n3310_o;
  wire [3:0] n3311_o;
  wire [3:0] n3312_o;
  wire [2:0] n3313_o;
  wire n3315_o;
  wire n3317_o;
  wire n3318_o;
  wire n3320_o;
  wire n3322_o;
  wire n3324_o;
  wire n3326_o;
  wire [30:0] n3327_o;
  wire [1:0] n3329_o;
  wire [30:0] n3330_o;
  wire [1:0] n3331_o;
  wire n3334_o;
  wire n3336_o;
  wire n3337_o;
  wire n3339_o;
  wire n3340_o;
  reg n3342_o;
  reg [1:0] n3344_o;
  reg n3347_o;
  wire n3349_o;
  wire [1:0] n3351_o;
  wire [30:0] n3352_o;
  wire [1:0] n3353_o;
  wire n3355_o;
  wire n3357_o;
  wire n3358_o;
  wire n3360_o;
  wire n3361_o;
  reg n3364_o;
  reg [1:0] n3366_o;
  reg n3369_o;
  wire n3371_o;
  wire [1:0] n3372_o;
  reg [2:0] n3374_o;
  reg n3378_o;
  reg [2:0] n3380_o;
  reg n3382_o;
  reg [1:0] n3384_o;
  reg n3386_o;
  reg [3:0] n3389_o;
  reg n3393_o;
  reg n3397_o;
  reg [1:0] n3400_o;
  reg n3404_o;
  wire n3406_o;
  wire n3408_o;
  wire n3409_o;
  wire n3411_o;
  wire n3412_o;
  wire n3414_o;
  wire n3415_o;
  wire n3418_o;
  wire n3420_o;
  wire n3421_o;
  wire n3423_o;
  wire n3424_o;
  wire n3426_o;
  wire n3427_o;
  wire n3430_o;
  wire n3432_o;
  wire n3433_o;
  wire n3435_o;
  wire n3436_o;
  wire n3438_o;
  wire n3439_o;
  wire n3442_o;
  wire n3444_o;
  wire n3445_o;
  wire n3447_o;
  wire n3448_o;
  wire n3450_o;
  wire n3451_o;
  wire [30:0] n3452_o;
  wire n3454_o;
  wire n3456_o;
  wire [1:0] n3457_o;
  reg n3461_o;
  reg n3464_o;
  reg n3467_o;
  reg n3470_o;
  wire n3472_o;
  wire [30:0] n3474_o;
  wire n3476_o;
  wire [2:0] n3478_o;
  wire n3483_o;
  wire n3484_o;
  wire n3486_o;
  wire n3487_o;
  wire n3489_o;
  wire n3490_o;
  wire n3491_o;
  wire n3493_o;
  wire n3494_o;
  wire n3496_o;
  wire n3497_o;
  wire n3498_o;
  wire n3500_o;
  wire n3501_o;
  wire n3503_o;
  wire n3504_o;
  wire n3505_o;
  wire n3507_o;
  wire n3508_o;
  wire n3510_o;
  wire [7:0] n3511_o;
  reg n3513_o;
  wire n3516_o;
  wire n3518_o;
  wire [1:0] n3519_o;
  reg n3523_o;
  reg n3525_o;
  reg n3528_o;
  reg n3531_o;
  wire n3533_o;
  wire n3535_o;
  wire n3536_o;
  wire n3538_o;
  wire n3539_o;
  wire n3541_o;
  wire n3542_o;
  wire n3544_o;
  wire n3545_o;
  wire n3547_o;
  wire n3548_o;
  wire n3550_o;
  wire n3551_o;
  wire n3553_o;
  wire n3554_o;
  wire n3556_o;
  wire n3558_o;
  wire n3560_o;
  wire n3562_o;
  wire n3564_o;
  wire n3566_o;
  wire n3568_o;
  wire [30:0] n3569_o;
  wire n3571_o;
  wire n3573_o;
  wire n3575_o;
  wire n3577_o;
  wire [3:0] n3578_o;
  reg [2:0] n3580_o;
  reg n3584_o;
  reg [3:0] n3588_o;
  reg [3:0] n3592_o;
  reg [2:0] n3596_o;
  reg n3599_o;
  reg n3602_o;
  reg n3605_o;
  reg n3609_o;
  wire n3611_o;
  wire [30:0] n3614_o;
  wire n3616_o;
  wire [2:0] n3618_o;
  wire n3623_o;
  wire n3624_o;
  wire n3626_o;
  wire n3627_o;
  wire n3629_o;
  wire n3630_o;
  wire n3631_o;
  wire n3633_o;
  wire n3634_o;
  wire n3636_o;
  wire n3637_o;
  wire n3638_o;
  wire n3640_o;
  wire n3641_o;
  wire n3643_o;
  wire n3644_o;
  wire n3645_o;
  wire n3647_o;
  wire n3648_o;
  wire n3650_o;
  wire [7:0] n3651_o;
  reg n3653_o;
  wire [2:0] n3656_o;
  wire [2:0] n3658_o;
  wire [3:0] n3661_o;
  wire [3:0] n3664_o;
  wire [2:0] n3667_o;
  wire n3669_o;
  wire n3671_o;
  wire n3673_o;
  wire [3:0] n3674_o;
  reg [2:0] n3676_o;
  reg [2:0] n3678_o;
  reg n3682_o;
  reg [3:0] n3685_o;
  reg [3:0] n3688_o;
  reg [2:0] n3691_o;
  reg n3694_o;
  reg n3697_o;
  reg n3700_o;
  reg n3704_o;
  wire n3706_o;
  wire n3708_o;
  wire n3709_o;
  wire n3711_o;
  wire n3712_o;
  wire n3714_o;
  wire n3715_o;
  wire n3717_o;
  wire n3718_o;
  wire n3720_o;
  wire n3721_o;
  wire n3723_o;
  wire n3724_o;
  wire n3726_o;
  wire n3727_o;
  wire [30:0] n3728_o;
  wire n3730_o;
  wire n3732_o;
  wire n3734_o;
  wire [2:0] n3735_o;
  reg [3:0] n3739_o;
  reg [2:0] n3743_o;
  reg n3746_o;
  reg n3749_o;
  wire n3751_o;
  wire [30:0] n3753_o;
  wire [2:0] n3755_o;
  wire n3760_o;
  wire n3761_o;
  wire n3763_o;
  wire n3764_o;
  wire n3766_o;
  wire n3767_o;
  wire n3768_o;
  wire n3770_o;
  wire n3771_o;
  wire n3773_o;
  wire n3774_o;
  wire n3775_o;
  wire n3777_o;
  wire n3778_o;
  wire n3780_o;
  wire n3781_o;
  wire n3782_o;
  wire n3784_o;
  wire n3785_o;
  wire n3787_o;
  wire [7:0] n3788_o;
  reg n3790_o;
  wire [2:0] n3793_o;
  wire [2:0] n3796_o;
  wire n3798_o;
  wire n3800_o;
  wire n3802_o;
  wire [2:0] n3803_o;
  reg [2:0] n3805_o;
  reg [2:0] n3808_o;
  reg [3:0] n3812_o;
  reg [2:0] n3815_o;
  reg n3818_o;
  reg n3821_o;
  wire n3823_o;
  wire n3825_o;
  wire n3826_o;
  wire n3828_o;
  wire n3829_o;
  wire n3831_o;
  wire n3832_o;
  wire n3834_o;
  wire n3835_o;
  wire n3837_o;
  wire n3838_o;
  wire n3840_o;
  wire n3841_o;
  wire n3843_o;
  wire n3844_o;
  wire [30:0] n3845_o;
  wire n3847_o;
  wire n3849_o;
  wire n3851_o;
  wire [2:0] n3852_o;
  reg [2:0] n3854_o;
  reg [3:0] n3858_o;
  reg [3:0] n3862_o;
  reg [2:0] n3866_o;
  reg n3869_o;
  reg n3873_o;
  wire n3875_o;
  wire n3877_o;
  wire n3878_o;
  wire n3880_o;
  wire n3881_o;
  wire n3883_o;
  wire n3884_o;
  wire n3886_o;
  wire n3887_o;
  wire n3889_o;
  wire n3890_o;
  wire n3892_o;
  wire n3893_o;
  wire n3895_o;
  wire n3896_o;
  wire [30:0] n3897_o;
  wire n3899_o;
  wire n3901_o;
  wire [1:0] n3902_o;
  reg n3905_o;
  reg n3908_o;
  reg [2:0] n3911_o;
  reg n3914_o;
  wire n3916_o;
  wire [30:0] n3917_o;
  wire n3919_o;
  wire n3921_o;
  wire [1:0] n3922_o;
  reg n3925_o;
  reg [3:0] n3928_o;
  reg [2:0] n3931_o;
  reg n3934_o;
  reg n3937_o;
  wire n3939_o;
  wire n3941_o;
  wire n3943_o;
  wire n3945_o;
  wire n3947_o;
  wire n3948_o;
  wire [58:0] n3949_o;
  reg [2:0] n3980_o;
  reg [2:0] n3985_o;
  reg n3988_o;
  reg n3991_o;
  wire [1:0] n3992_o;
  wire [1:0] n3993_o;
  wire [1:0] n3994_o;
  wire [1:0] n3995_o;
  wire [1:0] n3996_o;
  wire [1:0] n3997_o;
  wire [1:0] n3998_o;
  wire [1:0] n3999_o;
  wire [1:0] n4000_o;
  reg [1:0] n4003_o;
  wire [1:0] n4004_o;
  wire [1:0] n4005_o;
  wire [1:0] n4006_o;
  wire [1:0] n4007_o;
  wire [1:0] n4008_o;
  wire [1:0] n4009_o;
  wire [1:0] n4010_o;
  wire [1:0] n4011_o;
  wire [1:0] n4012_o;
  reg [1:0] n4015_o;
  reg n4024_o;
  reg n4027_o;
  wire [2:0] n4028_o;
  reg [2:0] n4031_o;
  wire n4032_o;
  reg n4035_o;
  wire n4036_o;
  wire n4037_o;
  wire n4038_o;
  wire n4039_o;
  wire n4040_o;
  wire n4041_o;
  wire n4042_o;
  wire n4043_o;
  wire n4044_o;
  wire n4045_o;
  wire n4046_o;
  wire n4047_o;
  wire n4049_o;
  wire n4051_o;
  wire n4052_o;
  wire n4053_o;
  wire n4054_o;
  wire n4055_o;
  wire n4056_o;
  reg n4059_o;
  wire [1:0] n4060_o;
  wire [1:0] n4061_o;
  wire [1:0] n4062_o;
  wire [1:0] n4063_o;
  wire [1:0] n4064_o;
  wire [1:0] n4065_o;
  wire [1:0] n4066_o;
  wire [1:0] n4067_o;
  wire [1:0] n4068_o;
  wire [1:0] n4069_o;
  wire [1:0] n4070_o;
  wire [1:0] n4071_o;
  wire [1:0] n4073_o;
  wire [1:0] n4075_o;
  wire [1:0] n4076_o;
  wire [1:0] n4077_o;
  wire [1:0] n4078_o;
  wire [1:0] n4079_o;
  wire [1:0] n4080_o;
  reg [1:0] n4083_o;
  wire n4084_o;
  wire n4085_o;
  wire n4086_o;
  wire n4087_o;
  wire n4088_o;
  wire n4089_o;
  wire n4091_o;
  wire n4093_o;
  wire n4094_o;
  wire n4095_o;
  wire n4096_o;
  wire n4097_o;
  wire n4098_o;
  reg n4101_o;
  reg [3:0] n4107_o;
  reg n4115_o;
  reg n4120_o;
  reg n4123_o;
  reg [2:0] n4126_o;
  reg n4129_o;
  reg n4132_o;
  reg n4136_o;
  reg n4139_o;
  reg n4142_o;
  reg n4145_o;
  reg n4148_o;
  reg n4152_o;
  reg n4156_o;
  reg n4160_o;
  reg n4164_o;
  reg n4168_o;
  reg n4172_o;
  reg [1:0] n4175_o;
  reg n4179_o;
  reg n4183_o;
  reg n4187_o;
  reg n4190_o;
  reg n4193_o;
  wire n4195_o;
  wire [2:0] n4196_o;
  wire [2:0] n4197_o;
  wire n4199_o;
  wire n4201_o;
  wire n4204_o;
  wire [3:0] n4206_o;
  wire n4209_o;
  wire [30:0] n4210_o;
  wire n4212_o;
  wire n4214_o;
  wire n4215_o;
  wire n4217_o;
  wire n4219_o;
  wire [2:0] n4220_o;
  reg [2:0] n4222_o;
  reg n4225_o;
  reg [3:0] n4227_o;
  reg n4230_o;
  reg [2:0] n4234_o;
  reg n4237_o;
  wire [2:0] n4240_o;
  wire [2:0] n4241_o;
  wire n4242_o;
  wire [3:0] n4243_o;
  wire n4244_o;
  wire [2:0] n4246_o;
  wire n4248_o;
  wire n4251_o;
  wire n4253_o;
  wire n4255_o;
  wire n4256_o;
  wire n4258_o;
  wire n4259_o;
  wire n4261_o;
  wire n4262_o;
  wire n4264_o;
  wire n4265_o;
  wire n4267_o;
  wire n4268_o;
  wire n4270_o;
  wire n4271_o;
  wire n4273_o;
  wire n4274_o;
  wire n4276_o;
  wire n4277_o;
  wire n4279_o;
  wire n4280_o;
  wire n4282_o;
  wire n4283_o;
  wire n4285_o;
  wire n4286_o;
  wire n4288_o;
  wire n4289_o;
  wire n4291_o;
  wire n4292_o;
  wire n4294_o;
  wire n4295_o;
  wire n4297_o;
  wire n4298_o;
  wire n4300_o;
  wire n4301_o;
  wire n4303_o;
  wire n4304_o;
  wire n4306_o;
  wire n4307_o;
  wire n4309_o;
  wire n4310_o;
  wire n4312_o;
  wire n4313_o;
  wire n4315_o;
  wire n4316_o;
  wire n4318_o;
  wire n4319_o;
  wire n4321_o;
  wire n4322_o;
  wire n4324_o;
  wire n4325_o;
  wire n4327_o;
  wire n4328_o;
  wire n4330_o;
  wire n4331_o;
  wire n4333_o;
  wire n4334_o;
  wire n4336_o;
  wire n4337_o;
  wire n4339_o;
  wire n4340_o;
  wire n4342_o;
  wire n4343_o;
  wire n4345_o;
  wire n4346_o;
  wire n4348_o;
  wire n4349_o;
  wire n4351_o;
  wire n4352_o;
  wire n4354_o;
  wire n4355_o;
  wire n4357_o;
  wire n4358_o;
  wire n4360_o;
  wire n4361_o;
  wire n4363_o;
  wire n4364_o;
  wire n4366_o;
  wire n4367_o;
  wire n4369_o;
  wire n4370_o;
  wire n4372_o;
  wire n4373_o;
  wire n4375_o;
  wire n4376_o;
  wire n4378_o;
  wire n4379_o;
  wire n4381_o;
  wire n4382_o;
  wire n4384_o;
  wire n4385_o;
  wire n4387_o;
  wire n4388_o;
  wire n4390_o;
  wire n4391_o;
  wire n4393_o;
  wire n4394_o;
  wire n4396_o;
  wire n4397_o;
  wire n4399_o;
  wire n4400_o;
  wire n4402_o;
  wire n4403_o;
  wire n4405_o;
  wire n4406_o;
  wire n4408_o;
  wire n4409_o;
  wire n4411_o;
  wire n4412_o;
  wire n4414_o;
  wire n4415_o;
  wire n4417_o;
  wire n4418_o;
  wire [30:0] n4419_o;
  wire n4421_o;
  wire n4423_o;
  wire n4424_o;
  wire n4426_o;
  wire n4428_o;
  wire [2:0] n4429_o;
  reg [2:0] n4431_o;
  reg n4434_o;
  reg [3:0] n4436_o;
  reg n4439_o;
  reg [2:0] n4443_o;
  reg n4446_o;
  wire n4448_o;
  wire n4450_o;
  wire n4451_o;
  wire n4453_o;
  wire n4454_o;
  wire n4456_o;
  wire n4457_o;
  wire n4459_o;
  wire n4460_o;
  wire n4462_o;
  wire n4463_o;
  wire n4465_o;
  wire n4466_o;
  wire n4468_o;
  wire n4469_o;
  wire n4471_o;
  wire n4473_o;
  wire [2:0] n4474_o;
  wire [2:0] n4475_o;
  wire [3:0] n4477_o;
  wire [30:0] n4478_o;
  wire n4480_o;
  wire n4482_o;
  wire n4483_o;
  wire n4485_o;
  wire [1:0] n4486_o;
  reg [2:0] n4488_o;
  reg [3:0] n4490_o;
  reg [2:0] n4493_o;
  wire [2:0] n4496_o;
  wire [2:0] n4497_o;
  wire n4498_o;
  wire [3:0] n4499_o;
  wire [2:0] n4501_o;
  wire n4504_o;
  wire n4506_o;
  wire n4508_o;
  wire n4509_o;
  wire n4511_o;
  wire n4512_o;
  wire n4514_o;
  wire n4515_o;
  wire n4517_o;
  wire n4518_o;
  wire n4520_o;
  wire n4521_o;
  wire n4523_o;
  wire n4524_o;
  wire n4526_o;
  wire n4527_o;
  wire n4529_o;
  wire n4530_o;
  wire n4532_o;
  wire n4533_o;
  wire n4535_o;
  wire n4536_o;
  wire n4538_o;
  wire n4539_o;
  wire n4541_o;
  wire n4542_o;
  wire n4544_o;
  wire n4545_o;
  wire n4547_o;
  wire n4548_o;
  wire n4550_o;
  wire n4551_o;
  wire n4553_o;
  wire n4554_o;
  wire n4556_o;
  wire n4557_o;
  wire n4559_o;
  wire n4560_o;
  wire n4562_o;
  wire n4563_o;
  wire n4565_o;
  wire n4566_o;
  wire n4568_o;
  wire n4569_o;
  wire n4571_o;
  wire n4572_o;
  wire n4574_o;
  wire n4575_o;
  wire n4577_o;
  wire n4578_o;
  wire n4580_o;
  wire n4581_o;
  wire n4583_o;
  wire n4584_o;
  wire n4586_o;
  wire n4587_o;
  wire n4589_o;
  wire n4590_o;
  wire n4592_o;
  wire n4593_o;
  wire n4595_o;
  wire n4596_o;
  wire n4598_o;
  wire n4599_o;
  wire n4601_o;
  wire n4602_o;
  wire n4604_o;
  wire n4605_o;
  wire n4607_o;
  wire n4608_o;
  wire n4610_o;
  wire n4611_o;
  wire n4613_o;
  wire n4614_o;
  wire n4616_o;
  wire n4617_o;
  wire n4619_o;
  wire n4620_o;
  wire n4622_o;
  wire n4623_o;
  wire n4625_o;
  wire n4626_o;
  wire n4628_o;
  wire n4629_o;
  wire n4631_o;
  wire n4632_o;
  wire n4634_o;
  wire n4635_o;
  wire n4637_o;
  wire n4638_o;
  wire n4640_o;
  wire n4641_o;
  wire n4643_o;
  wire n4644_o;
  wire n4646_o;
  wire n4647_o;
  wire n4649_o;
  wire n4650_o;
  wire n4652_o;
  wire n4653_o;
  wire n4655_o;
  wire n4656_o;
  wire n4658_o;
  wire n4659_o;
  wire n4661_o;
  wire n4662_o;
  wire n4664_o;
  wire n4665_o;
  wire n4667_o;
  wire n4668_o;
  wire n4670_o;
  wire n4671_o;
  wire [30:0] n4672_o;
  wire n4674_o;
  wire n4676_o;
  wire n4677_o;
  wire n4679_o;
  wire [1:0] n4680_o;
  reg [2:0] n4682_o;
  reg [3:0] n4684_o;
  reg [2:0] n4687_o;
  wire n4689_o;
  wire n4691_o;
  wire n4692_o;
  wire n4694_o;
  wire n4695_o;
  wire n4697_o;
  wire n4698_o;
  wire n4700_o;
  wire n4701_o;
  wire n4703_o;
  wire n4704_o;
  wire n4706_o;
  wire n4707_o;
  wire n4709_o;
  wire n4710_o;
  wire n4712_o;
  wire n4714_o;
  wire n4717_o;
  wire [3:0] n4719_o;
  wire n4722_o;
  wire [30:0] n4723_o;
  wire n4725_o;
  wire n4727_o;
  wire n4728_o;
  wire n4730_o;
  wire n4732_o;
  wire [2:0] n4733_o;
  reg [2:0] n4735_o;
  reg n4738_o;
  reg [3:0] n4740_o;
  reg n4743_o;
  reg [2:0] n4747_o;
  reg n4750_o;
  wire [2:0] n4753_o;
  wire [2:0] n4754_o;
  wire n4755_o;
  wire [3:0] n4756_o;
  wire n4757_o;
  wire [2:0] n4759_o;
  wire n4761_o;
  wire n4764_o;
  wire n4766_o;
  wire n4768_o;
  wire n4769_o;
  wire n4771_o;
  wire n4772_o;
  wire n4774_o;
  wire n4775_o;
  wire n4777_o;
  wire n4778_o;
  wire n4780_o;
  wire n4781_o;
  wire n4783_o;
  wire n4784_o;
  wire n4786_o;
  wire n4787_o;
  wire n4789_o;
  wire n4790_o;
  wire n4792_o;
  wire n4793_o;
  wire n4795_o;
  wire n4796_o;
  wire n4798_o;
  wire n4799_o;
  wire n4801_o;
  wire n4802_o;
  wire n4804_o;
  wire n4805_o;
  wire n4807_o;
  wire n4808_o;
  wire n4810_o;
  wire n4811_o;
  wire n4813_o;
  wire n4814_o;
  wire n4816_o;
  wire n4817_o;
  wire n4819_o;
  wire n4820_o;
  wire n4822_o;
  wire n4823_o;
  wire n4825_o;
  wire n4826_o;
  wire n4828_o;
  wire n4829_o;
  wire n4831_o;
  wire n4832_o;
  wire n4834_o;
  wire n4835_o;
  wire n4837_o;
  wire n4838_o;
  wire n4840_o;
  wire n4841_o;
  wire n4843_o;
  wire n4844_o;
  wire n4846_o;
  wire n4847_o;
  wire n4849_o;
  wire n4850_o;
  wire n4852_o;
  wire n4853_o;
  wire n4855_o;
  wire n4856_o;
  wire n4858_o;
  wire n4859_o;
  wire n4861_o;
  wire n4862_o;
  wire n4864_o;
  wire n4865_o;
  wire n4867_o;
  wire n4868_o;
  wire n4870_o;
  wire n4871_o;
  wire n4873_o;
  wire n4874_o;
  wire n4876_o;
  wire n4877_o;
  wire n4879_o;
  wire n4880_o;
  wire n4882_o;
  wire n4883_o;
  wire n4885_o;
  wire n4886_o;
  wire n4888_o;
  wire n4889_o;
  wire n4891_o;
  wire n4892_o;
  wire n4894_o;
  wire n4895_o;
  wire n4897_o;
  wire n4898_o;
  wire n4900_o;
  wire n4901_o;
  wire n4903_o;
  wire n4904_o;
  wire n4906_o;
  wire n4907_o;
  wire n4909_o;
  wire n4910_o;
  wire n4912_o;
  wire n4913_o;
  wire n4915_o;
  wire n4916_o;
  wire n4918_o;
  wire n4919_o;
  wire n4921_o;
  wire n4922_o;
  wire n4924_o;
  wire n4925_o;
  wire n4927_o;
  wire n4928_o;
  wire n4930_o;
  wire n4931_o;
  wire [30:0] n4932_o;
  wire n4934_o;
  wire n4936_o;
  wire n4937_o;
  wire n4939_o;
  wire n4941_o;
  wire [2:0] n4942_o;
  reg [2:0] n4944_o;
  reg n4947_o;
  reg [3:0] n4949_o;
  reg n4952_o;
  reg [2:0] n4956_o;
  reg n4959_o;
  wire n4961_o;
  wire n4963_o;
  wire n4964_o;
  wire n4966_o;
  wire n4967_o;
  wire n4969_o;
  wire n4970_o;
  wire n4972_o;
  wire n4973_o;
  wire n4975_o;
  wire n4976_o;
  wire n4978_o;
  wire n4979_o;
  wire n4981_o;
  wire n4982_o;
  wire n4984_o;
  wire n4986_o;
  wire n4989_o;
  wire [3:0] n4991_o;
  wire n4994_o;
  wire [30:0] n4995_o;
  wire n4997_o;
  wire n4999_o;
  wire n5000_o;
  wire n5002_o;
  wire n5004_o;
  wire [2:0] n5005_o;
  reg [2:0] n5007_o;
  reg n5010_o;
  reg [3:0] n5012_o;
  reg n5015_o;
  reg [2:0] n5019_o;
  reg n5022_o;
  wire [2:0] n5025_o;
  wire [2:0] n5026_o;
  wire n5027_o;
  wire [3:0] n5028_o;
  wire n5029_o;
  wire [2:0] n5031_o;
  wire n5033_o;
  wire n5036_o;
  wire n5038_o;
  wire n5040_o;
  wire n5041_o;
  wire n5043_o;
  wire n5044_o;
  wire n5046_o;
  wire n5047_o;
  wire n5049_o;
  wire n5050_o;
  wire n5052_o;
  wire n5053_o;
  wire n5055_o;
  wire n5056_o;
  wire n5058_o;
  wire n5059_o;
  wire n5061_o;
  wire n5062_o;
  wire n5064_o;
  wire n5065_o;
  wire n5067_o;
  wire n5068_o;
  wire n5070_o;
  wire n5071_o;
  wire n5073_o;
  wire n5074_o;
  wire n5076_o;
  wire n5077_o;
  wire n5079_o;
  wire n5080_o;
  wire n5082_o;
  wire n5083_o;
  wire n5085_o;
  wire n5086_o;
  wire n5088_o;
  wire n5089_o;
  wire n5091_o;
  wire n5092_o;
  wire n5094_o;
  wire n5095_o;
  wire n5097_o;
  wire n5098_o;
  wire n5100_o;
  wire n5101_o;
  wire n5103_o;
  wire n5104_o;
  wire n5106_o;
  wire n5107_o;
  wire n5109_o;
  wire n5110_o;
  wire n5112_o;
  wire n5113_o;
  wire n5115_o;
  wire n5116_o;
  wire n5118_o;
  wire n5119_o;
  wire n5121_o;
  wire n5122_o;
  wire n5124_o;
  wire n5125_o;
  wire n5127_o;
  wire n5128_o;
  wire n5130_o;
  wire n5131_o;
  wire n5133_o;
  wire n5134_o;
  wire n5136_o;
  wire n5137_o;
  wire n5139_o;
  wire n5140_o;
  wire n5142_o;
  wire n5143_o;
  wire n5145_o;
  wire n5146_o;
  wire n5148_o;
  wire n5149_o;
  wire n5151_o;
  wire n5152_o;
  wire n5154_o;
  wire n5155_o;
  wire n5157_o;
  wire n5158_o;
  wire n5160_o;
  wire n5161_o;
  wire n5163_o;
  wire n5164_o;
  wire n5166_o;
  wire n5167_o;
  wire n5169_o;
  wire n5170_o;
  wire n5172_o;
  wire n5173_o;
  wire n5175_o;
  wire n5176_o;
  wire n5178_o;
  wire n5179_o;
  wire n5181_o;
  wire n5182_o;
  wire n5184_o;
  wire n5185_o;
  wire n5187_o;
  wire n5188_o;
  wire n5190_o;
  wire n5191_o;
  wire n5193_o;
  wire n5194_o;
  wire n5196_o;
  wire n5197_o;
  wire n5199_o;
  wire n5200_o;
  wire n5202_o;
  wire n5203_o;
  wire [30:0] n5204_o;
  wire n5206_o;
  wire n5208_o;
  wire n5209_o;
  wire n5211_o;
  wire n5213_o;
  wire [2:0] n5214_o;
  reg [2:0] n5216_o;
  reg n5219_o;
  reg [3:0] n5221_o;
  reg n5224_o;
  reg [2:0] n5228_o;
  reg n5231_o;
  wire n5233_o;
  wire n5235_o;
  wire n5236_o;
  wire n5238_o;
  wire n5239_o;
  wire n5241_o;
  wire n5242_o;
  wire n5244_o;
  wire n5245_o;
  wire n5247_o;
  wire n5248_o;
  wire n5250_o;
  wire n5251_o;
  wire n5253_o;
  wire n5254_o;
  wire [7:0] n5255_o;
  reg [2:0] n5261_o;
  reg [2:0] n5263_o;
  reg n5266_o;
  reg [2:0] n5268_o;
  reg [3:0] n5270_o;
  reg n5273_o;
  reg [2:0] n5275_o;
  reg n5278_o;
  reg n5281_o;
  wire n5283_o;
  wire n5285_o;
  wire n5287_o;
  wire n5288_o;
  wire n5290_o;
  wire n5291_o;
  wire n5293_o;
  wire n5294_o;
  wire n5296_o;
  wire n5297_o;
  wire n5299_o;
  wire n5300_o;
  wire n5302_o;
  wire n5303_o;
  wire n5305_o;
  wire n5306_o;
  wire n5308_o;
  wire n5309_o;
  wire n5311_o;
  wire n5312_o;
  wire n5314_o;
  wire n5315_o;
  wire n5317_o;
  wire n5318_o;
  wire n5320_o;
  wire n5321_o;
  wire n5323_o;
  wire n5324_o;
  wire n5326_o;
  wire n5327_o;
  wire n5329_o;
  wire n5330_o;
  wire n5332_o;
  wire n5333_o;
  wire n5335_o;
  wire n5336_o;
  wire n5338_o;
  wire n5339_o;
  wire n5341_o;
  wire n5342_o;
  wire n5344_o;
  wire n5345_o;
  wire n5347_o;
  wire n5348_o;
  wire n5350_o;
  wire n5351_o;
  wire n5353_o;
  wire n5354_o;
  wire n5356_o;
  wire n5357_o;
  wire n5359_o;
  wire n5360_o;
  wire n5362_o;
  wire n5363_o;
  wire n5365_o;
  wire n5366_o;
  wire n5368_o;
  wire n5369_o;
  wire n5371_o;
  wire n5372_o;
  wire n5374_o;
  wire n5375_o;
  wire n5377_o;
  wire n5378_o;
  wire n5380_o;
  wire n5381_o;
  wire n5383_o;
  wire n5384_o;
  wire n5386_o;
  wire n5387_o;
  wire n5389_o;
  wire n5390_o;
  wire n5392_o;
  wire n5393_o;
  wire n5395_o;
  wire n5396_o;
  wire n5398_o;
  wire n5399_o;
  wire n5401_o;
  wire n5402_o;
  wire n5404_o;
  wire n5405_o;
  wire n5407_o;
  wire n5408_o;
  wire n5410_o;
  wire n5411_o;
  wire n5413_o;
  wire n5414_o;
  wire n5416_o;
  wire n5417_o;
  wire n5419_o;
  wire n5420_o;
  wire n5422_o;
  wire n5423_o;
  wire n5425_o;
  wire n5426_o;
  wire n5428_o;
  wire n5429_o;
  wire n5431_o;
  wire n5432_o;
  wire n5434_o;
  wire n5435_o;
  wire n5437_o;
  wire n5438_o;
  wire n5440_o;
  wire n5441_o;
  wire n5443_o;
  wire n5444_o;
  wire n5446_o;
  wire n5447_o;
  wire n5449_o;
  wire n5450_o;
  wire n5452_o;
  wire n5453_o;
  wire n5455_o;
  wire n5456_o;
  wire n5458_o;
  wire n5459_o;
  wire n5461_o;
  wire n5462_o;
  wire n5464_o;
  wire n5465_o;
  wire n5467_o;
  wire n5468_o;
  wire n5470_o;
  wire n5471_o;
  wire n5473_o;
  wire n5474_o;
  wire n5476_o;
  wire n5477_o;
  wire n5479_o;
  wire n5480_o;
  wire n5482_o;
  wire n5483_o;
  wire n5485_o;
  wire n5486_o;
  wire n5488_o;
  wire n5489_o;
  wire n5491_o;
  wire n5492_o;
  wire n5494_o;
  wire n5495_o;
  wire n5497_o;
  wire n5498_o;
  wire n5500_o;
  wire n5501_o;
  wire n5503_o;
  wire n5504_o;
  wire n5506_o;
  wire n5507_o;
  wire n5509_o;
  wire n5510_o;
  wire n5512_o;
  wire n5513_o;
  wire n5515_o;
  wire n5516_o;
  wire n5518_o;
  wire n5519_o;
  wire n5521_o;
  wire n5522_o;
  wire n5524_o;
  wire n5525_o;
  wire n5527_o;
  wire n5528_o;
  wire n5530_o;
  wire n5531_o;
  wire n5533_o;
  wire n5534_o;
  wire n5536_o;
  wire n5537_o;
  wire n5539_o;
  wire n5540_o;
  wire n5542_o;
  wire n5543_o;
  wire n5545_o;
  wire n5546_o;
  wire n5548_o;
  wire n5549_o;
  wire n5551_o;
  wire n5552_o;
  wire n5554_o;
  wire n5555_o;
  wire n5557_o;
  wire n5558_o;
  wire n5560_o;
  wire n5561_o;
  wire n5563_o;
  wire n5564_o;
  wire n5566_o;
  wire n5567_o;
  wire n5569_o;
  wire n5570_o;
  wire n5572_o;
  wire n5573_o;
  wire n5575_o;
  wire n5576_o;
  wire n5578_o;
  wire n5579_o;
  wire n5581_o;
  wire n5582_o;
  wire n5584_o;
  wire n5585_o;
  wire n5587_o;
  wire n5588_o;
  wire n5590_o;
  wire n5591_o;
  wire n5593_o;
  wire n5594_o;
  wire n5596_o;
  wire n5597_o;
  wire n5599_o;
  wire n5600_o;
  wire n5602_o;
  wire n5603_o;
  wire n5605_o;
  wire n5606_o;
  wire n5608_o;
  wire n5609_o;
  wire n5611_o;
  wire n5612_o;
  wire n5614_o;
  wire n5615_o;
  wire n5617_o;
  wire n5618_o;
  wire n5620_o;
  wire n5621_o;
  wire n5623_o;
  wire n5624_o;
  wire n5626_o;
  wire n5627_o;
  wire n5629_o;
  wire n5630_o;
  wire n5632_o;
  wire n5633_o;
  wire n5635_o;
  wire n5636_o;
  wire n5638_o;
  wire n5639_o;
  wire n5641_o;
  wire n5642_o;
  wire n5644_o;
  wire n5645_o;
  wire n5647_o;
  wire n5648_o;
  wire n5650_o;
  wire n5651_o;
  wire n5653_o;
  wire n5654_o;
  wire n5656_o;
  wire n5657_o;
  wire n5659_o;
  wire n5660_o;
  wire n5662_o;
  wire n5663_o;
  wire n5665_o;
  wire n5666_o;
  wire n5668_o;
  wire n5669_o;
  wire n5671_o;
  wire n5672_o;
  wire n5674_o;
  wire n5675_o;
  wire n5677_o;
  wire n5678_o;
  wire n5680_o;
  wire n5681_o;
  wire n5683_o;
  wire n5684_o;
  wire n5686_o;
  wire n5687_o;
  wire n5689_o;
  wire n5690_o;
  wire n5692_o;
  wire n5693_o;
  wire n5695_o;
  wire n5696_o;
  wire n5698_o;
  wire n5699_o;
  wire n5701_o;
  wire n5702_o;
  wire n5704_o;
  wire n5705_o;
  wire n5707_o;
  wire n5708_o;
  wire n5710_o;
  wire n5711_o;
  wire n5713_o;
  wire n5714_o;
  wire n5716_o;
  wire n5717_o;
  wire n5719_o;
  wire n5720_o;
  wire n5722_o;
  wire n5723_o;
  wire n5725_o;
  wire n5726_o;
  wire n5728_o;
  wire n5729_o;
  wire n5731_o;
  wire n5732_o;
  wire n5734_o;
  wire n5735_o;
  wire n5737_o;
  wire n5738_o;
  wire n5740_o;
  wire n5741_o;
  wire n5743_o;
  wire n5744_o;
  wire n5746_o;
  wire n5747_o;
  wire n5749_o;
  wire n5750_o;
  wire n5752_o;
  wire n5753_o;
  wire n5755_o;
  wire n5756_o;
  wire n5758_o;
  wire n5759_o;
  wire n5761_o;
  wire n5762_o;
  wire n5764_o;
  wire n5765_o;
  wire n5767_o;
  wire n5768_o;
  wire n5770_o;
  wire n5771_o;
  wire n5773_o;
  wire n5774_o;
  wire n5776_o;
  wire n5777_o;
  wire n5779_o;
  wire n5780_o;
  wire n5782_o;
  wire n5783_o;
  wire n5785_o;
  wire n5786_o;
  wire n5788_o;
  wire n5789_o;
  wire n5791_o;
  wire n5792_o;
  wire n5794_o;
  wire n5795_o;
  wire n5797_o;
  wire n5798_o;
  wire n5800_o;
  wire n5801_o;
  wire n5803_o;
  wire n5804_o;
  wire n5806_o;
  wire n5807_o;
  wire n5809_o;
  wire n5810_o;
  wire n5812_o;
  wire n5814_o;
  wire n5815_o;
  wire n5817_o;
  wire n5819_o;
  wire n5821_o;
  wire n5823_o;
  wire [30:0] n5824_o;
  wire n5826_o;
  wire n5828_o;
  wire [1:0] n5829_o;
  wire n5831_o;
  wire [1:0] n5832_o;
  wire [2:0] n5834_o;
  wire [2:0] n5836_o;
  wire n5839_o;
  wire n5841_o;
  wire [1:0] n5842_o;
  wire n5844_o;
  wire [1:0] n5845_o;
  wire [2:0] n5847_o;
  wire [2:0] n5849_o;
  wire n5852_o;
  wire n5854_o;
  wire [3:0] n5855_o;
  reg n5859_o;
  reg n5862_o;
  reg n5866_o;
  reg [2:0] n5868_o;
  reg n5870_o;
  reg [2:0] n5874_o;
  reg n5877_o;
  reg n5880_o;
  wire n5882_o;
  wire n5884_o;
  wire n5885_o;
  wire n5887_o;
  wire n5888_o;
  wire n5890_o;
  wire n5891_o;
  wire [30:0] n5892_o;
  wire n5894_o;
  wire [1:0] n5895_o;
  wire n5897_o;
  wire [1:0] n5898_o;
  wire [3:0] n5901_o;
  wire [3:0] n5903_o;
  wire n5905_o;
  wire [1:0] n5906_o;
  wire n5908_o;
  wire [1:0] n5909_o;
  wire [3:0] n5912_o;
  wire [3:0] n5914_o;
  wire n5916_o;
  wire n5918_o;
  wire [3:0] n5919_o;
  reg n5923_o;
  reg n5926_o;
  reg [3:0] n5928_o;
  reg [2:0] n5932_o;
  reg n5935_o;
  reg n5938_o;
  reg n5942_o;
  wire n5944_o;
  wire n5946_o;
  wire n5947_o;
  wire n5949_o;
  wire n5950_o;
  wire n5952_o;
  wire n5953_o;
  wire [30:0] n5954_o;
  wire n5956_o;
  wire n5958_o;
  wire n5959_o;
  wire [3:0] n5962_o;
  wire n5964_o;
  wire n5965_o;
  wire n5966_o;
  wire [3:0] n5969_o;
  wire n5971_o;
  wire n5973_o;
  wire [3:0] n5974_o;
  reg [2:0] n5977_o;
  reg [3:0] n5980_o;
  reg [2:0] n5982_o;
  reg [3:0] n5985_o;
  reg [3:0] n5987_o;
  reg [2:0] n5991_o;
  reg n5994_o;
  reg n5997_o;
  reg n6000_o;
  wire n6002_o;
  wire n6004_o;
  wire n6005_o;
  wire n6007_o;
  wire n6008_o;
  wire n6010_o;
  wire n6011_o;
  wire [30:0] n6012_o;
  wire n6014_o;
  wire n6016_o;
  wire n6017_o;
  wire [3:0] n6020_o;
  wire n6022_o;
  wire n6024_o;
  wire n6026_o;
  wire [3:0] n6027_o;
  reg [2:0] n6030_o;
  reg [3:0] n6033_o;
  reg [2:0] n6035_o;
  reg [3:0] n6038_o;
  reg [3:0] n6040_o;
  reg n6043_o;
  reg n6046_o;
  reg [2:0] n6049_o;
  reg n6052_o;
  reg n6056_o;
  wire n6058_o;
  wire n6060_o;
  wire n6061_o;
  wire n6063_o;
  wire n6064_o;
  wire n6066_o;
  wire n6067_o;
  wire n6069_o;
  wire n6071_o;
  wire n6072_o;
  wire n6074_o;
  wire n6075_o;
  wire n6077_o;
  wire n6078_o;
  wire n6080_o;
  wire n6081_o;
  wire n6083_o;
  wire n6084_o;
  wire n6086_o;
  wire n6087_o;
  wire n6089_o;
  wire n6090_o;
  wire n6092_o;
  wire n6094_o;
  wire n6095_o;
  wire n6097_o;
  wire n6098_o;
  wire n6100_o;
  wire n6101_o;
  wire n6103_o;
  wire n6105_o;
  wire n6106_o;
  wire n6108_o;
  wire n6110_o;
  wire n6111_o;
  wire [30:0] n6112_o;
  wire [1:0] n6114_o;
  wire [30:0] n6115_o;
  wire [1:0] n6116_o;
  wire n6119_o;
  wire n6121_o;
  wire n6122_o;
  wire n6124_o;
  wire n6125_o;
  reg n6127_o;
  reg [1:0] n6129_o;
  reg n6132_o;
  wire n6134_o;
  wire [1:0] n6136_o;
  wire [30:0] n6137_o;
  wire [1:0] n6138_o;
  wire n6141_o;
  wire n6143_o;
  wire n6144_o;
  wire n6146_o;
  wire n6147_o;
  reg n6149_o;
  reg [1:0] n6151_o;
  reg n6154_o;
  wire n6156_o;
  wire [1:0] n6157_o;
  reg [2:0] n6159_o;
  reg n6163_o;
  reg [2:0] n6165_o;
  reg n6167_o;
  reg [1:0] n6169_o;
  reg n6171_o;
  reg [3:0] n6174_o;
  reg n6178_o;
  reg [1:0] n6181_o;
  reg n6185_o;
  wire n6187_o;
  wire n6189_o;
  wire n6190_o;
  wire n6192_o;
  wire n6193_o;
  wire n6195_o;
  wire n6196_o;
  wire [30:0] n6197_o;
  wire [1:0] n6199_o;
  wire [30:0] n6200_o;
  wire [1:0] n6201_o;
  wire n6204_o;
  wire n6206_o;
  wire n6207_o;
  wire n6209_o;
  wire n6210_o;
  reg n6212_o;
  reg [1:0] n6214_o;
  reg n6217_o;
  wire n6219_o;
  wire [1:0] n6221_o;
  wire [30:0] n6222_o;
  wire [1:0] n6223_o;
  wire n6225_o;
  wire n6227_o;
  wire n6228_o;
  wire n6230_o;
  wire n6231_o;
  reg n6234_o;
  reg [1:0] n6236_o;
  reg n6239_o;
  wire n6241_o;
  wire [1:0] n6242_o;
  reg [2:0] n6244_o;
  reg n6248_o;
  reg [2:0] n6250_o;
  reg n6252_o;
  reg [1:0] n6254_o;
  reg n6256_o;
  reg [3:0] n6259_o;
  reg n6263_o;
  reg [1:0] n6266_o;
  reg n6270_o;
  wire n6272_o;
  wire n6274_o;
  wire n6275_o;
  wire n6277_o;
  wire n6278_o;
  wire n6280_o;
  wire n6281_o;
  wire [30:0] n6282_o;
  wire n6284_o;
  wire n6288_o;
  wire n6290_o;
  wire n6292_o;
  wire [3:0] n6293_o;
  reg [2:0] n6295_o;
  reg n6298_o;
  reg [2:0] n6300_o;
  reg [2:0] n6302_o;
  reg [3:0] n6304_o;
  reg n6307_o;
  reg [2:0] n6311_o;
  reg n6314_o;
  reg n6317_o;
  reg n6320_o;
  wire n6322_o;
  wire [30:0] n6323_o;
  wire n6325_o;
  wire n6329_o;
  wire n6331_o;
  wire n6333_o;
  wire [3:0] n6334_o;
  reg [2:0] n6336_o;
  reg n6339_o;
  reg [2:0] n6341_o;
  reg [2:0] n6343_o;
  reg [3:0] n6345_o;
  reg n6348_o;
  reg [2:0] n6352_o;
  reg n6355_o;
  reg n6358_o;
  reg n6361_o;
  wire n6363_o;
  wire [30:0] n6364_o;
  wire n6366_o;
  wire n6368_o;
  wire n6370_o;
  wire [2:0] n6371_o;
  reg [3:0] n6375_o;
  reg [2:0] n6379_o;
  reg n6382_o;
  reg n6385_o;
  reg n6388_o;
  reg n6391_o;
  wire n6393_o;
  wire n6395_o;
  wire n6396_o;
  wire n6398_o;
  wire n6399_o;
  wire n6401_o;
  wire n6402_o;
  wire n6404_o;
  wire n6405_o;
  wire n6407_o;
  wire n6408_o;
  wire n6410_o;
  wire n6411_o;
  wire n6413_o;
  wire n6414_o;
  wire [30:0] n6415_o;
  wire n6417_o;
  wire [2:0] n6418_o;
  wire n6420_o;
  wire [2:0] n6421_o;
  wire n6424_o;
  wire [2:0] n6426_o;
  wire n6428_o;
  wire [1:0] n6429_o;
  reg n6431_o;
  reg [2:0] n6433_o;
  reg [2:0] n6436_o;
  reg n6439_o;
  reg n6442_o;
  reg [1:0] n6445_o;
  wire n6447_o;
  wire n6449_o;
  wire n6450_o;
  wire n6452_o;
  wire n6453_o;
  wire n6455_o;
  wire n6456_o;
  wire n6458_o;
  wire n6459_o;
  wire n6461_o;
  wire n6462_o;
  wire n6464_o;
  wire n6465_o;
  wire n6467_o;
  wire n6468_o;
  wire [30:0] n6469_o;
  wire [2:0] n6470_o;
  wire [2:0] n6471_o;
  wire n6473_o;
  wire n6476_o;
  wire n6478_o;
  wire n6480_o;
  wire [1:0] n6481_o;
  reg [2:0] n6483_o;
  reg n6485_o;
  reg [2:0] n6488_o;
  reg n6491_o;
  reg [1:0] n6494_o;
  reg n6497_o;
  wire n6499_o;
  wire n6501_o;
  wire n6502_o;
  wire n6504_o;
  wire n6505_o;
  wire n6507_o;
  wire n6508_o;
  wire n6510_o;
  wire n6511_o;
  wire n6513_o;
  wire n6514_o;
  wire n6516_o;
  wire n6517_o;
  wire n6519_o;
  wire n6520_o;
  wire [30:0] n6521_o;
  wire n6522_o;
  wire n6524_o;
  wire n6526_o;
  wire n6527_o;
  wire n6528_o;
  wire [3:0] n6531_o;
  wire n6533_o;
  wire n6535_o;
  wire [3:0] n6536_o;
  reg [2:0] n6539_o;
  wire [2:0] n6540_o;
  reg [2:0] n6542_o;
  wire n6543_o;
  reg n6545_o;
  reg n6548_o;
  reg [3:0] n6551_o;
  reg [3:0] n6555_o;
  reg [3:0] n6557_o;
  reg n6560_o;
  reg [2:0] n6564_o;
  reg n6567_o;
  reg n6570_o;
  reg [1:0] n6573_o;
  reg n6576_o;
  reg n6579_o;
  wire n6581_o;
  wire n6583_o;
  wire n6584_o;
  wire n6586_o;
  wire n6587_o;
  wire n6589_o;
  wire n6590_o;
  wire [30:0] n6591_o;
  wire n6593_o;
  wire n6594_o;
  wire n6596_o;
  wire n6597_o;
  wire n6598_o;
  wire [3:0] n6601_o;
  wire n6603_o;
  wire n6605_o;
  wire [3:0] n6606_o;
  reg [2:0] n6609_o;
  wire [2:0] n6610_o;
  reg [2:0] n6612_o;
  wire n6613_o;
  reg n6615_o;
  reg n6618_o;
  reg [3:0] n6621_o;
  reg [3:0] n6625_o;
  reg [3:0] n6627_o;
  reg n6630_o;
  reg [2:0] n6634_o;
  reg n6637_o;
  reg n6640_o;
  reg [1:0] n6643_o;
  reg n6646_o;
  reg n6649_o;
  wire n6651_o;
  wire n6653_o;
  wire n6654_o;
  wire n6656_o;
  wire n6657_o;
  wire n6659_o;
  wire n6660_o;
  wire [22:0] n6661_o;
  reg [2:0] n6677_o;
  reg [2:0] n6683_o;
  reg n6686_o;
  reg n6689_o;
  wire [2:0] n6690_o;
  wire [2:0] n6691_o;
  wire [2:0] n6692_o;
  reg [2:0] n6695_o;
  wire n6696_o;
  wire n6697_o;
  wire n6698_o;
  reg n6701_o;
  reg n6704_o;
  reg n6708_o;
  wire [2:0] n6710_o;
  wire [2:0] n6711_o;
  reg [2:0] n6714_o;
  wire n6716_o;
  wire n6717_o;
  reg n6720_o;
  wire n6721_o;
  wire n6722_o;
  wire n6723_o;
  wire n6725_o;
  wire n6726_o;
  wire n6727_o;
  wire n6728_o;
  wire n6729_o;
  reg n6732_o;
  wire [1:0] n6733_o;
  wire [1:0] n6734_o;
  wire [1:0] n6735_o;
  wire [1:0] n6737_o;
  wire [1:0] n6738_o;
  wire [1:0] n6739_o;
  wire [1:0] n6740_o;
  wire [1:0] n6741_o;
  reg [1:0] n6744_o;
  wire n6745_o;
  wire n6746_o;
  wire n6747_o;
  wire n6749_o;
  wire n6750_o;
  reg n6753_o;
  reg [3:0] n6756_o;
  reg n6760_o;
  reg n6763_o;
  reg [2:0] n6766_o;
  reg n6769_o;
  reg n6772_o;
  reg n6775_o;
  reg n6778_o;
  reg [2:0] n6785_o;
  reg n6788_o;
  reg n6791_o;
  reg n6794_o;
  reg n6797_o;
  reg n6800_o;
  reg n6803_o;
  reg n6806_o;
  reg [1:0] n6809_o;
  reg [1:0] n6815_o;
  reg n6818_o;
  reg n6821_o;
  wire [1:0] n6822_o;
  reg [2:0] n6823_o;
  reg [2:0] n6825_o;
  reg n6827_o;
  reg n6830_o;
  wire [1:0] n6832_o;
  reg [1:0] n6834_o;
  wire n6835_o;
  wire n6836_o;
  reg n6838_o;
  wire n6839_o;
  reg n6841_o;
  reg n6845_o;
  reg n6848_o;
  reg [2:0] n6850_o;
  reg n6852_o;
  wire n6855_o;
  reg n6856_o;
  wire [1:0] n6857_o;
  reg [1:0] n6858_o;
  reg n6860_o;
  reg [3:0] n6864_o;
  reg n6865_o;
  reg n6868_o;
  reg n6871_o;
  reg [2:0] n6873_o;
  reg n6876_o;
  reg n6879_o;
  reg n6882_o;
  reg n6885_o;
  reg n6888_o;
  reg n6891_o;
  reg n6894_o;
  reg n6897_o;
  reg [2:0] n6900_o;
  reg n6903_o;
  reg n6906_o;
  reg n6909_o;
  reg n6912_o;
  reg n6915_o;
  reg n6918_o;
  reg n6921_o;
  reg n6924_o;
  reg n6927_o;
  reg n6930_o;
  reg n6933_o;
  reg n6936_o;
  reg [1:0] n6939_o;
  reg n6942_o;
  reg n6945_o;
  reg [1:0] n6948_o;
  reg n6951_o;
  reg n6954_o;
  reg n6956_o;
  reg n6959_o;
  localparam [1:0] n6962_o = 2'b00;
  localparam n6963_o = 1'b0;
  localparam n6964_o = 1'b0;
  localparam n6965_o = 1'b0;
  localparam n6966_o = 1'b0;
  wire [3:0] n6967_o;
  wire [3:0] n6968_o;
  wire [3:0] n6969_o;
  assign mcycles = n6823_o;
  assign tstates = n6825_o;
  assign prefix = n6962_o;
  assign inc_pc = n6827_o;
  assign inc_wz = n6830_o;
  assign incdec_16 = n6967_o;
  assign read_to_reg = n6845_o;
  assign read_to_acc = n6848_o;
  assign set_busa_to = n6968_o;
  assign set_busb_to = n6969_o;
  assign alu_op = n6864_o;
  assign save_alu = n6865_o;
  assign preservec = n6868_o;
  assign arith16 = n6871_o;
  assign set_addr_to = n6873_o;
  assign iorq = n6876_o;
  assign jump = n6879_o;
  assign jumpe = n6963_o;
  assign jumpxy = n6882_o;
  assign call = n6885_o;
  assign rstp = n6888_o;
  assign ldz = n6891_o;
  assign ldw = n6894_o;
  assign ldsphl = n6897_o;
  assign special_ld = n6900_o;
  assign exchangedh = n6903_o;
  assign exchangerp = n6906_o;
  assign exchangeaf = n6964_o;
  assign exchangers = n6965_o;
  assign i_djnz = n6966_o;
  assign i_cpl = n6909_o;
  assign i_ccf = n6912_o;
  assign i_scf = n6915_o;
  assign i_retn = n6918_o;
  assign i_bt = n6921_o;
  assign i_bc = n6924_o;
  assign i_btr = n6927_o;
  assign i_rld = n6930_o;
  assign i_rrd = n6933_o;
  assign i_inrc = n6936_o;
  assign setwz = n6939_o;
  assign setdi = n6942_o;
  assign setei = n6945_o;
  assign imode = n6948_o;
  assign halt = n6951_o;
  assign noread = n6954_o;
  assign write = n6956_o;
  assign xybit_undoc = n6959_o;
  /* T80_MCode.vhd:198:26  */
  assign n2172_o = ir[5:3];
  /* T80_MCode.vhd:199:26  */
  assign n2173_o = ir[2:0];
  /* T80_MCode.vhd:200:28  */
  assign n2174_o = ir[5:4];
  /* T80_MCode.vhd:204:27  */
  assign n2176_o = mcycle == 3'b001;
  /* T80_MCode.vhd:204:17  */
  assign n2179_o = n2176_o ? 3'b100 : 3'b011;
  /* T80_MCode.vhd:217:35  */
  assign n2180_o = ir[5:3];
  /* T80_MCode.vhd:217:31  */
  assign n2182_o = {1'b0, n2180_o};
  /* T80_MCode.vhd:267:17  */
  assign n2184_o = ir == 8'b01000000;
  /* T80_MCode.vhd:267:32  */
  assign n2186_o = ir == 8'b01000001;
  /* T80_MCode.vhd:267:32  */
  assign n2187_o = n2184_o | n2186_o;
  /* T80_MCode.vhd:267:43  */
  assign n2189_o = ir == 8'b01000010;
  /* T80_MCode.vhd:267:43  */
  assign n2190_o = n2187_o | n2189_o;
  /* T80_MCode.vhd:267:54  */
  assign n2192_o = ir == 8'b01000011;
  /* T80_MCode.vhd:267:54  */
  assign n2193_o = n2190_o | n2192_o;
  /* T80_MCode.vhd:267:65  */
  assign n2195_o = ir == 8'b01000100;
  /* T80_MCode.vhd:267:65  */
  assign n2196_o = n2193_o | n2195_o;
  /* T80_MCode.vhd:267:76  */
  assign n2198_o = ir == 8'b01000101;
  /* T80_MCode.vhd:267:76  */
  assign n2199_o = n2196_o | n2198_o;
  /* T80_MCode.vhd:267:87  */
  assign n2201_o = ir == 8'b01000111;
  /* T80_MCode.vhd:267:87  */
  assign n2202_o = n2199_o | n2201_o;
  /* T80_MCode.vhd:268:25  */
  assign n2204_o = ir == 8'b01001000;
  /* T80_MCode.vhd:268:25  */
  assign n2205_o = n2202_o | n2204_o;
  /* T80_MCode.vhd:268:36  */
  assign n2207_o = ir == 8'b01001001;
  /* T80_MCode.vhd:268:36  */
  assign n2208_o = n2205_o | n2207_o;
  /* T80_MCode.vhd:268:47  */
  assign n2210_o = ir == 8'b01001010;
  /* T80_MCode.vhd:268:47  */
  assign n2211_o = n2208_o | n2210_o;
  /* T80_MCode.vhd:268:58  */
  assign n2213_o = ir == 8'b01001011;
  /* T80_MCode.vhd:268:58  */
  assign n2214_o = n2211_o | n2213_o;
  /* T80_MCode.vhd:268:69  */
  assign n2216_o = ir == 8'b01001100;
  /* T80_MCode.vhd:268:69  */
  assign n2217_o = n2214_o | n2216_o;
  /* T80_MCode.vhd:268:80  */
  assign n2219_o = ir == 8'b01001101;
  /* T80_MCode.vhd:268:80  */
  assign n2220_o = n2217_o | n2219_o;
  /* T80_MCode.vhd:268:91  */
  assign n2222_o = ir == 8'b01001111;
  /* T80_MCode.vhd:268:91  */
  assign n2223_o = n2220_o | n2222_o;
  /* T80_MCode.vhd:269:25  */
  assign n2225_o = ir == 8'b01010000;
  /* T80_MCode.vhd:269:25  */
  assign n2226_o = n2223_o | n2225_o;
  /* T80_MCode.vhd:269:36  */
  assign n2228_o = ir == 8'b01010001;
  /* T80_MCode.vhd:269:36  */
  assign n2229_o = n2226_o | n2228_o;
  /* T80_MCode.vhd:269:47  */
  assign n2231_o = ir == 8'b01010010;
  /* T80_MCode.vhd:269:47  */
  assign n2232_o = n2229_o | n2231_o;
  /* T80_MCode.vhd:269:58  */
  assign n2234_o = ir == 8'b01010011;
  /* T80_MCode.vhd:269:58  */
  assign n2235_o = n2232_o | n2234_o;
  /* T80_MCode.vhd:269:69  */
  assign n2237_o = ir == 8'b01010100;
  /* T80_MCode.vhd:269:69  */
  assign n2238_o = n2235_o | n2237_o;
  /* T80_MCode.vhd:269:80  */
  assign n2240_o = ir == 8'b01010101;
  /* T80_MCode.vhd:269:80  */
  assign n2241_o = n2238_o | n2240_o;
  /* T80_MCode.vhd:269:91  */
  assign n2243_o = ir == 8'b01010111;
  /* T80_MCode.vhd:269:91  */
  assign n2244_o = n2241_o | n2243_o;
  /* T80_MCode.vhd:270:25  */
  assign n2246_o = ir == 8'b01011000;
  /* T80_MCode.vhd:270:25  */
  assign n2247_o = n2244_o | n2246_o;
  /* T80_MCode.vhd:270:36  */
  assign n2249_o = ir == 8'b01011001;
  /* T80_MCode.vhd:270:36  */
  assign n2250_o = n2247_o | n2249_o;
  /* T80_MCode.vhd:270:47  */
  assign n2252_o = ir == 8'b01011010;
  /* T80_MCode.vhd:270:47  */
  assign n2253_o = n2250_o | n2252_o;
  /* T80_MCode.vhd:270:58  */
  assign n2255_o = ir == 8'b01011011;
  /* T80_MCode.vhd:270:58  */
  assign n2256_o = n2253_o | n2255_o;
  /* T80_MCode.vhd:270:69  */
  assign n2258_o = ir == 8'b01011100;
  /* T80_MCode.vhd:270:69  */
  assign n2259_o = n2256_o | n2258_o;
  /* T80_MCode.vhd:270:80  */
  assign n2261_o = ir == 8'b01011101;
  /* T80_MCode.vhd:270:80  */
  assign n2262_o = n2259_o | n2261_o;
  /* T80_MCode.vhd:270:91  */
  assign n2264_o = ir == 8'b01011111;
  /* T80_MCode.vhd:270:91  */
  assign n2265_o = n2262_o | n2264_o;
  /* T80_MCode.vhd:271:25  */
  assign n2267_o = ir == 8'b01100000;
  /* T80_MCode.vhd:271:25  */
  assign n2268_o = n2265_o | n2267_o;
  /* T80_MCode.vhd:271:36  */
  assign n2270_o = ir == 8'b01100001;
  /* T80_MCode.vhd:271:36  */
  assign n2271_o = n2268_o | n2270_o;
  /* T80_MCode.vhd:271:47  */
  assign n2273_o = ir == 8'b01100010;
  /* T80_MCode.vhd:271:47  */
  assign n2274_o = n2271_o | n2273_o;
  /* T80_MCode.vhd:271:58  */
  assign n2276_o = ir == 8'b01100011;
  /* T80_MCode.vhd:271:58  */
  assign n2277_o = n2274_o | n2276_o;
  /* T80_MCode.vhd:271:69  */
  assign n2279_o = ir == 8'b01100100;
  /* T80_MCode.vhd:271:69  */
  assign n2280_o = n2277_o | n2279_o;
  /* T80_MCode.vhd:271:80  */
  assign n2282_o = ir == 8'b01100101;
  /* T80_MCode.vhd:271:80  */
  assign n2283_o = n2280_o | n2282_o;
  /* T80_MCode.vhd:271:91  */
  assign n2285_o = ir == 8'b01100111;
  /* T80_MCode.vhd:271:91  */
  assign n2286_o = n2283_o | n2285_o;
  /* T80_MCode.vhd:272:25  */
  assign n2288_o = ir == 8'b01101000;
  /* T80_MCode.vhd:272:25  */
  assign n2289_o = n2286_o | n2288_o;
  /* T80_MCode.vhd:272:36  */
  assign n2291_o = ir == 8'b01101001;
  /* T80_MCode.vhd:272:36  */
  assign n2292_o = n2289_o | n2291_o;
  /* T80_MCode.vhd:272:47  */
  assign n2294_o = ir == 8'b01101010;
  /* T80_MCode.vhd:272:47  */
  assign n2295_o = n2292_o | n2294_o;
  /* T80_MCode.vhd:272:58  */
  assign n2297_o = ir == 8'b01101011;
  /* T80_MCode.vhd:272:58  */
  assign n2298_o = n2295_o | n2297_o;
  /* T80_MCode.vhd:272:69  */
  assign n2300_o = ir == 8'b01101100;
  /* T80_MCode.vhd:272:69  */
  assign n2301_o = n2298_o | n2300_o;
  /* T80_MCode.vhd:272:80  */
  assign n2303_o = ir == 8'b01101101;
  /* T80_MCode.vhd:272:80  */
  assign n2304_o = n2301_o | n2303_o;
  /* T80_MCode.vhd:272:91  */
  assign n2306_o = ir == 8'b01101111;
  /* T80_MCode.vhd:272:91  */
  assign n2307_o = n2304_o | n2306_o;
  /* T80_MCode.vhd:273:25  */
  assign n2309_o = ir == 8'b01111000;
  /* T80_MCode.vhd:273:25  */
  assign n2310_o = n2307_o | n2309_o;
  /* T80_MCode.vhd:273:36  */
  assign n2312_o = ir == 8'b01111001;
  /* T80_MCode.vhd:273:36  */
  assign n2313_o = n2310_o | n2312_o;
  /* T80_MCode.vhd:273:47  */
  assign n2315_o = ir == 8'b01111010;
  /* T80_MCode.vhd:273:47  */
  assign n2316_o = n2313_o | n2315_o;
  /* T80_MCode.vhd:273:58  */
  assign n2318_o = ir == 8'b01111011;
  /* T80_MCode.vhd:273:58  */
  assign n2319_o = n2316_o | n2318_o;
  /* T80_MCode.vhd:273:69  */
  assign n2321_o = ir == 8'b01111100;
  /* T80_MCode.vhd:273:69  */
  assign n2322_o = n2319_o | n2321_o;
  /* T80_MCode.vhd:273:80  */
  assign n2324_o = ir == 8'b01111101;
  /* T80_MCode.vhd:273:80  */
  assign n2325_o = n2322_o | n2324_o;
  /* T80_MCode.vhd:273:91  */
  assign n2327_o = ir == 8'b01111111;
  /* T80_MCode.vhd:273:91  */
  assign n2328_o = n2325_o | n2327_o;
  /* T80_MCode.vhd:282:30  */
  assign n2329_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:283:25  */
  assign n2331_o = n2329_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:282:25  */
  always @*
    case (n2331_o)
      1'b1: n2334_o = 1'b1;
      default: n2334_o = 1'b0;
    endcase
  /* T80_MCode.vhd:282:25  */
  always @*
    case (n2331_o)
      1'b1: n2337_o = 1'b1;
      default: n2337_o = 1'b0;
    endcase
  /* T80_MCode.vhd:282:25  */
  always @*
    case (n2331_o)
      1'b1: n2339_o = n2172_o;
      default: n2339_o = 3'b000;
    endcase
  /* T80_MCode.vhd:279:17  */
  assign n2341_o = ir == 8'b00000110;
  /* T80_MCode.vhd:279:32  */
  assign n2343_o = ir == 8'b00001110;
  /* T80_MCode.vhd:279:32  */
  assign n2344_o = n2341_o | n2343_o;
  /* T80_MCode.vhd:279:43  */
  assign n2346_o = ir == 8'b00010110;
  /* T80_MCode.vhd:279:43  */
  assign n2347_o = n2344_o | n2346_o;
  /* T80_MCode.vhd:279:54  */
  assign n2349_o = ir == 8'b00011110;
  /* T80_MCode.vhd:279:54  */
  assign n2350_o = n2347_o | n2349_o;
  /* T80_MCode.vhd:279:65  */
  assign n2352_o = ir == 8'b00100110;
  /* T80_MCode.vhd:279:65  */
  assign n2353_o = n2350_o | n2352_o;
  /* T80_MCode.vhd:279:76  */
  assign n2355_o = ir == 8'b00101110;
  /* T80_MCode.vhd:279:76  */
  assign n2356_o = n2353_o | n2355_o;
  /* T80_MCode.vhd:279:87  */
  assign n2358_o = ir == 8'b00111110;
  /* T80_MCode.vhd:279:87  */
  assign n2359_o = n2356_o | n2358_o;
  /* T80_MCode.vhd:292:30  */
  assign n2360_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:293:25  */
  assign n2362_o = n2360_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:295:25  */
  assign n2364_o = n2360_o == 31'b0000000000000000000000000000010;
  assign n2365_o = {n2364_o, n2362_o};
  /* T80_MCode.vhd:292:25  */
  always @*
    case (n2365_o)
      2'b10: n2368_o = 1'b1;
      2'b01: n2368_o = 1'b0;
      default: n2368_o = 1'b0;
    endcase
  /* T80_MCode.vhd:292:25  */
  always @*
    case (n2365_o)
      2'b10: n2370_o = n2172_o;
      2'b01: n2370_o = 3'b000;
      default: n2370_o = 3'b000;
    endcase
  /* T80_MCode.vhd:292:25  */
  always @*
    case (n2365_o)
      2'b10: n2373_o = 3'b111;
      2'b01: n2373_o = 3'b010;
      default: n2373_o = 3'b111;
    endcase
  /* T80_MCode.vhd:289:17  */
  assign n2375_o = ir == 8'b01000110;
  /* T80_MCode.vhd:289:32  */
  assign n2377_o = ir == 8'b01001110;
  /* T80_MCode.vhd:289:32  */
  assign n2378_o = n2375_o | n2377_o;
  /* T80_MCode.vhd:289:43  */
  assign n2380_o = ir == 8'b01010110;
  /* T80_MCode.vhd:289:43  */
  assign n2381_o = n2378_o | n2380_o;
  /* T80_MCode.vhd:289:54  */
  assign n2383_o = ir == 8'b01011110;
  /* T80_MCode.vhd:289:54  */
  assign n2384_o = n2381_o | n2383_o;
  /* T80_MCode.vhd:289:65  */
  assign n2386_o = ir == 8'b01100110;
  /* T80_MCode.vhd:289:65  */
  assign n2387_o = n2384_o | n2386_o;
  /* T80_MCode.vhd:289:76  */
  assign n2389_o = ir == 8'b01101110;
  /* T80_MCode.vhd:289:76  */
  assign n2390_o = n2387_o | n2389_o;
  /* T80_MCode.vhd:289:87  */
  assign n2392_o = ir == 8'b01111110;
  /* T80_MCode.vhd:289:87  */
  assign n2393_o = n2390_o | n2392_o;
  /* T80_MCode.vhd:303:30  */
  assign n2394_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:304:25  */
  assign n2397_o = n2394_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:308:25  */
  assign n2399_o = n2394_o == 31'b0000000000000000000000000000010;
  assign n2400_o = {n2399_o, n2397_o};
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2400_o)
      2'b10: n2402_o = 3'b000;
      2'b01: n2402_o = n2173_o;
      default: n2402_o = 3'b000;
    endcase
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2400_o)
      2'b10: n2404_o = 1'b0;
      2'b01: n2404_o = 1'b0;
      default: n2404_o = 1'b0;
    endcase
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2400_o)
      2'b10: n2407_o = 3'b111;
      2'b01: n2407_o = 3'b010;
      default: n2407_o = 3'b111;
    endcase
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2400_o)
      2'b10: n2410_o = 1'b1;
      2'b01: n2410_o = 1'b0;
      default: n2410_o = 1'b0;
    endcase
  /* T80_MCode.vhd:300:17  */
  assign n2412_o = ir == 8'b01110000;
  /* T80_MCode.vhd:300:32  */
  assign n2414_o = ir == 8'b01110001;
  /* T80_MCode.vhd:300:32  */
  assign n2415_o = n2412_o | n2414_o;
  /* T80_MCode.vhd:300:43  */
  assign n2417_o = ir == 8'b01110010;
  /* T80_MCode.vhd:300:43  */
  assign n2418_o = n2415_o | n2417_o;
  /* T80_MCode.vhd:300:54  */
  assign n2420_o = ir == 8'b01110011;
  /* T80_MCode.vhd:300:54  */
  assign n2421_o = n2418_o | n2420_o;
  /* T80_MCode.vhd:300:65  */
  assign n2423_o = ir == 8'b01110100;
  /* T80_MCode.vhd:300:65  */
  assign n2424_o = n2421_o | n2423_o;
  /* T80_MCode.vhd:300:76  */
  assign n2426_o = ir == 8'b01110101;
  /* T80_MCode.vhd:300:76  */
  assign n2427_o = n2424_o | n2426_o;
  /* T80_MCode.vhd:300:87  */
  assign n2429_o = ir == 8'b01110111;
  /* T80_MCode.vhd:300:87  */
  assign n2430_o = n2427_o | n2429_o;
  /* T80_MCode.vhd:315:30  */
  assign n2431_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:316:25  */
  assign n2434_o = n2431_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:321:25  */
  assign n2436_o = n2431_o == 31'b0000000000000000000000000000011;
  assign n2437_o = {n2436_o, n2434_o};
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2437_o)
      2'b10: n2440_o = 1'b0;
      2'b01: n2440_o = 1'b1;
      default: n2440_o = 1'b0;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2437_o)
      2'b10: n2442_o = 3'b000;
      2'b01: n2442_o = n2173_o;
      default: n2442_o = 3'b000;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2437_o)
      2'b10: n2444_o = 1'b0;
      2'b01: n2444_o = 1'b0;
      default: n2444_o = 1'b0;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2437_o)
      2'b10: n2447_o = 3'b111;
      2'b01: n2447_o = 3'b010;
      default: n2447_o = 3'b111;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2437_o)
      2'b10: n2450_o = 1'b1;
      2'b01: n2450_o = 1'b0;
      default: n2450_o = 1'b0;
    endcase
  /* T80_MCode.vhd:312:17  */
  assign n2452_o = ir == 8'b00110110;
  /* T80_MCode.vhd:328:30  */
  assign n2453_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:329:25  */
  assign n2455_o = n2453_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:331:25  */
  assign n2457_o = n2453_o == 31'b0000000000000000000000000000010;
  assign n2458_o = {n2457_o, n2455_o};
  /* T80_MCode.vhd:328:25  */
  always @*
    case (n2458_o)
      2'b10: n2461_o = 1'b1;
      2'b01: n2461_o = 1'b0;
      default: n2461_o = 1'b0;
    endcase
  /* T80_MCode.vhd:328:25  */
  always @*
    case (n2458_o)
      2'b10: n2464_o = 3'b111;
      2'b01: n2464_o = 3'b000;
      default: n2464_o = 3'b111;
    endcase
  /* T80_MCode.vhd:325:17  */
  assign n2466_o = ir == 8'b00001010;
  /* T80_MCode.vhd:338:30  */
  assign n2467_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:339:25  */
  assign n2469_o = n2467_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:341:25  */
  assign n2471_o = n2467_o == 31'b0000000000000000000000000000010;
  assign n2472_o = {n2471_o, n2469_o};
  /* T80_MCode.vhd:338:25  */
  always @*
    case (n2472_o)
      2'b10: n2475_o = 1'b1;
      2'b01: n2475_o = 1'b0;
      default: n2475_o = 1'b0;
    endcase
  /* T80_MCode.vhd:338:25  */
  always @*
    case (n2472_o)
      2'b10: n2478_o = 3'b111;
      2'b01: n2478_o = 3'b001;
      default: n2478_o = 3'b111;
    endcase
  /* T80_MCode.vhd:335:17  */
  assign n2480_o = ir == 8'b00011010;
  /* T80_MCode.vhd:360:38  */
  assign n2481_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:361:33  */
  assign n2483_o = n2481_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:364:33  */
  assign n2485_o = n2481_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:367:33  */
  assign n2487_o = n2481_o == 31'b0000000000000000000000000000100;
  assign n2488_o = {n2487_o, n2485_o, n2483_o};
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2488_o)
      3'b100: n2492_o = 1'b0;
      3'b010: n2492_o = 1'b1;
      3'b001: n2492_o = 1'b1;
      default: n2492_o = 1'b0;
    endcase
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2488_o)
      3'b100: n2495_o = 1'b1;
      3'b010: n2495_o = 1'b0;
      3'b001: n2495_o = 1'b0;
      default: n2495_o = 1'b0;
    endcase
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2488_o)
      3'b100: n2498_o = 3'b111;
      3'b010: n2498_o = 3'b110;
      3'b001: n2498_o = 3'b111;
      default: n2498_o = 3'b111;
    endcase
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2488_o)
      3'b100: n2501_o = 1'b0;
      3'b010: n2501_o = 1'b0;
      3'b001: n2501_o = 1'b1;
      default: n2501_o = 1'b0;
    endcase
  /* T80_MCode.vhd:345:17  */
  assign n2503_o = ir == 8'b00111010;
  /* T80_MCode.vhd:375:30  */
  assign n2504_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:376:25  */
  assign n2506_o = n2504_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:380:25  */
  assign n2508_o = n2504_o == 31'b0000000000000000000000000000010;
  assign n2509_o = {n2508_o, n2506_o};
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2509_o)
      2'b10: n2512_o = 4'b0000;
      2'b01: n2512_o = 4'b0111;
      default: n2512_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2509_o)
      2'b10: n2515_o = 3'b111;
      2'b01: n2515_o = 3'b000;
      default: n2515_o = 3'b111;
    endcase
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2509_o)
      2'b10: n2518_o = 2'b00;
      2'b01: n2518_o = 2'b10;
      default: n2518_o = 2'b00;
    endcase
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2509_o)
      2'b10: n2521_o = 1'b1;
      2'b01: n2521_o = 1'b0;
      default: n2521_o = 1'b0;
    endcase
  /* T80_MCode.vhd:372:17  */
  assign n2523_o = ir == 8'b00000010;
  /* T80_MCode.vhd:387:30  */
  assign n2524_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:388:25  */
  assign n2526_o = n2524_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:392:25  */
  assign n2528_o = n2524_o == 31'b0000000000000000000000000000010;
  assign n2529_o = {n2528_o, n2526_o};
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2529_o)
      2'b10: n2532_o = 4'b0000;
      2'b01: n2532_o = 4'b0111;
      default: n2532_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2529_o)
      2'b10: n2535_o = 3'b111;
      2'b01: n2535_o = 3'b001;
      default: n2535_o = 3'b111;
    endcase
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2529_o)
      2'b10: n2538_o = 2'b00;
      2'b01: n2538_o = 2'b10;
      default: n2538_o = 2'b00;
    endcase
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2529_o)
      2'b10: n2541_o = 1'b1;
      2'b01: n2541_o = 1'b0;
      default: n2541_o = 1'b0;
    endcase
  /* T80_MCode.vhd:384:17  */
  assign n2543_o = ir == 8'b00010010;
  /* T80_MCode.vhd:412:38  */
  assign n2544_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:413:33  */
  assign n2546_o = n2544_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:416:33  */
  assign n2548_o = n2544_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:421:33  */
  assign n2550_o = n2544_o == 31'b0000000000000000000000000000100;
  assign n2551_o = {n2550_o, n2548_o, n2546_o};
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2555_o = 1'b0;
      3'b010: n2555_o = 1'b1;
      3'b001: n2555_o = 1'b1;
      default: n2555_o = 1'b0;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2558_o = 4'b0000;
      3'b010: n2558_o = 4'b0111;
      3'b001: n2558_o = 4'b0000;
      default: n2558_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2561_o = 3'b111;
      3'b010: n2561_o = 3'b110;
      3'b001: n2561_o = 3'b111;
      default: n2561_o = 3'b111;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2564_o = 1'b0;
      3'b010: n2564_o = 1'b0;
      3'b001: n2564_o = 1'b1;
      default: n2564_o = 1'b0;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2567_o = 2'b00;
      3'b010: n2567_o = 2'b10;
      3'b001: n2567_o = 2'b00;
      default: n2567_o = 2'b00;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2570_o = 1'b1;
      3'b010: n2570_o = 1'b0;
      3'b001: n2570_o = 1'b0;
      default: n2570_o = 1'b0;
    endcase
  /* T80_MCode.vhd:396:17  */
  assign n2572_o = ir == 8'b00110010;
  /* T80_MCode.vhd:431:30  */
  assign n2573_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:435:42  */
  assign n2575_o = n2174_o == 2'b11;
  assign n2577_o = {n2174_o, 1'b1};
  /* T80_MCode.vhd:435:33  */
  assign n2579_o = n2575_o ? 3'b000 : n2577_o;
  /* T80_MCode.vhd:435:33  */
  assign n2582_o = n2575_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:432:25  */
  assign n2584_o = n2573_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:444:42  */
  assign n2586_o = n2174_o == 2'b11;
  assign n2588_o = {n2174_o, 1'b0};
  /* T80_MCode.vhd:444:33  */
  assign n2590_o = n2586_o ? 3'b001 : n2588_o;
  /* T80_MCode.vhd:444:33  */
  assign n2593_o = n2586_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:441:25  */
  assign n2595_o = n2573_o == 31'b0000000000000000000000000000011;
  assign n2596_o = {n2595_o, n2584_o};
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2596_o)
      2'b10: n2600_o = 1'b1;
      2'b01: n2600_o = 1'b1;
      default: n2600_o = 1'b0;
    endcase
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2596_o)
      2'b10: n2604_o = 1'b1;
      2'b01: n2604_o = 1'b1;
      default: n2604_o = 1'b0;
    endcase
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2596_o)
      2'b10: n2606_o = n2590_o;
      2'b01: n2606_o = n2579_o;
      default: n2606_o = 3'b000;
    endcase
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2596_o)
      2'b10: n2608_o = n2593_o;
      2'b01: n2608_o = n2582_o;
      default: n2608_o = 1'b0;
    endcase
  /* T80_MCode.vhd:428:17  */
  assign n2610_o = ir == 8'b00000001;
  /* T80_MCode.vhd:428:32  */
  assign n2612_o = ir == 8'b00010001;
  /* T80_MCode.vhd:428:32  */
  assign n2613_o = n2610_o | n2612_o;
  /* T80_MCode.vhd:428:43  */
  assign n2615_o = ir == 8'b00100001;
  /* T80_MCode.vhd:428:43  */
  assign n2616_o = n2613_o | n2615_o;
  /* T80_MCode.vhd:428:54  */
  assign n2618_o = ir == 8'b00110001;
  /* T80_MCode.vhd:428:54  */
  assign n2619_o = n2616_o | n2618_o;
  /* T80_MCode.vhd:467:38  */
  assign n2620_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:468:33  */
  assign n2622_o = n2620_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:471:33  */
  assign n2624_o = n2620_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:475:33  */
  assign n2627_o = n2620_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:480:33  */
  assign n2630_o = n2620_o == 31'b0000000000000000000000000000101;
  assign n2631_o = {n2630_o, n2627_o, n2624_o, n2622_o};
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2635_o = 1'b0;
      4'b0100: n2635_o = 1'b0;
      4'b0010: n2635_o = 1'b1;
      4'b0001: n2635_o = 1'b1;
      default: n2635_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2638_o = 1'b0;
      4'b0100: n2638_o = 1'b1;
      4'b0010: n2638_o = 1'b0;
      4'b0001: n2638_o = 1'b0;
      default: n2638_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2642_o = 1'b1;
      4'b0100: n2642_o = 1'b1;
      4'b0010: n2642_o = 1'b0;
      4'b0001: n2642_o = 1'b0;
      default: n2642_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2644_o = 3'b100;
      4'b0100: n2644_o = 3'b101;
      4'b0010: n2644_o = 3'b000;
      4'b0001: n2644_o = 3'b000;
      default: n2644_o = 3'b000;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2648_o = 3'b111;
      4'b0100: n2648_o = 3'b110;
      4'b0010: n2648_o = 3'b110;
      4'b0001: n2648_o = 3'b111;
      default: n2648_o = 3'b111;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2651_o = 1'b0;
      4'b0100: n2651_o = 1'b0;
      4'b0010: n2651_o = 1'b0;
      4'b0001: n2651_o = 1'b1;
      default: n2651_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2654_o = 1'b0;
      4'b0100: n2654_o = 1'b0;
      4'b0010: n2654_o = 1'b1;
      4'b0001: n2654_o = 1'b0;
      default: n2654_o = 1'b0;
    endcase
  /* T80_MCode.vhd:452:17  */
  assign n2656_o = ir == 8'b00101010;
  /* T80_MCode.vhd:502:38  */
  assign n2657_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:503:33  */
  assign n2659_o = n2657_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:506:33  */
  assign n2661_o = n2657_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:511:33  */
  assign n2663_o = n2657_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:516:33  */
  assign n2665_o = n2657_o == 31'b0000000000000000000000000000101;
  assign n2666_o = {n2665_o, n2663_o, n2661_o, n2659_o};
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2670_o = 1'b0;
      4'b0100: n2670_o = 1'b0;
      4'b0010: n2670_o = 1'b1;
      4'b0001: n2670_o = 1'b1;
      default: n2670_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2673_o = 1'b0;
      4'b0100: n2673_o = 1'b1;
      4'b0010: n2673_o = 1'b0;
      4'b0001: n2673_o = 1'b0;
      default: n2673_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2677_o = 4'b0000;
      4'b0100: n2677_o = 4'b0100;
      4'b0010: n2677_o = 4'b0101;
      4'b0001: n2677_o = 4'b0000;
      default: n2677_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2681_o = 3'b111;
      4'b0100: n2681_o = 3'b110;
      4'b0010: n2681_o = 3'b110;
      4'b0001: n2681_o = 3'b111;
      default: n2681_o = 3'b111;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2684_o = 1'b0;
      4'b0100: n2684_o = 1'b0;
      4'b0010: n2684_o = 1'b0;
      4'b0001: n2684_o = 1'b1;
      default: n2684_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2687_o = 1'b0;
      4'b0100: n2687_o = 1'b0;
      4'b0010: n2687_o = 1'b1;
      4'b0001: n2687_o = 1'b0;
      default: n2687_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2691_o = 1'b1;
      4'b0100: n2691_o = 1'b1;
      4'b0010: n2691_o = 1'b0;
      4'b0001: n2691_o = 1'b0;
      default: n2691_o = 1'b0;
    endcase
  /* T80_MCode.vhd:486:17  */
  assign n2693_o = ir == 8'b00100010;
  /* T80_MCode.vhd:521:17  */
  assign n2695_o = ir == 8'b11111001;
  /* T80_MCode.vhd:528:30  */
  assign n2696_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:533:42  */
  assign n2698_o = n2174_o == 2'b11;
  assign n2701_o = {1'b0, n2174_o, 1'b0};
  /* T80_MCode.vhd:533:33  */
  assign n2703_o = n2698_o ? 4'b0111 : n2701_o;
  /* T80_MCode.vhd:529:25  */
  assign n2705_o = n2696_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:543:42  */
  assign n2707_o = n2174_o == 2'b11;
  assign n2710_o = {1'b0, n2174_o, 1'b1};
  /* T80_MCode.vhd:543:33  */
  assign n2712_o = n2707_o ? 4'b1011 : n2710_o;
  /* T80_MCode.vhd:540:25  */
  assign n2714_o = n2696_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:551:25  */
  assign n2716_o = n2696_o == 31'b0000000000000000000000000000011;
  assign n2717_o = {n2716_o, n2714_o, n2705_o};
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2717_o)
      3'b100: n2719_o = n2179_o;
      3'b010: n2719_o = n2179_o;
      3'b001: n2719_o = 3'b101;
      default: n2719_o = n2179_o;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2717_o)
      3'b100: n2723_o = 4'b0000;
      3'b010: n2723_o = 4'b1111;
      3'b001: n2723_o = 4'b1111;
      default: n2723_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2717_o)
      3'b100: n2725_o = 4'b0000;
      3'b010: n2725_o = n2712_o;
      3'b001: n2725_o = n2703_o;
      default: n2725_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2717_o)
      3'b100: n2729_o = 3'b111;
      3'b010: n2729_o = 3'b101;
      3'b001: n2729_o = 3'b101;
      default: n2729_o = 3'b111;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2717_o)
      3'b100: n2733_o = 1'b1;
      3'b010: n2733_o = 1'b1;
      3'b001: n2733_o = 1'b0;
      default: n2733_o = 1'b0;
    endcase
  /* T80_MCode.vhd:525:17  */
  assign n2735_o = ir == 8'b11000101;
  /* T80_MCode.vhd:525:32  */
  assign n2737_o = ir == 8'b11010101;
  /* T80_MCode.vhd:525:32  */
  assign n2738_o = n2735_o | n2737_o;
  /* T80_MCode.vhd:525:43  */
  assign n2740_o = ir == 8'b11100101;
  /* T80_MCode.vhd:525:43  */
  assign n2741_o = n2738_o | n2740_o;
  /* T80_MCode.vhd:525:54  */
  assign n2743_o = ir == 8'b11110101;
  /* T80_MCode.vhd:525:54  */
  assign n2744_o = n2741_o | n2743_o;
  /* T80_MCode.vhd:558:30  */
  assign n2745_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:559:25  */
  assign n2747_o = n2745_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:565:42  */
  assign n2749_o = n2174_o == 2'b11;
  assign n2751_o = {n2174_o, 1'b1};
  /* T80_MCode.vhd:565:33  */
  assign n2753_o = n2749_o ? 3'b011 : n2751_o;
  /* T80_MCode.vhd:565:33  */
  assign n2756_o = n2749_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:561:25  */
  assign n2758_o = n2745_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:574:42  */
  assign n2760_o = n2174_o == 2'b11;
  assign n2762_o = {n2174_o, 1'b0};
  /* T80_MCode.vhd:574:33  */
  assign n2764_o = n2760_o ? 3'b111 : n2762_o;
  /* T80_MCode.vhd:574:33  */
  assign n2767_o = n2760_o ? 1'b0 : 1'b0;
  /* T80_MCode.vhd:571:25  */
  assign n2769_o = n2745_o == 31'b0000000000000000000000000000011;
  assign n2770_o = {n2769_o, n2758_o, n2747_o};
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2770_o)
      3'b100: n2774_o = 4'b0111;
      3'b010: n2774_o = 4'b0111;
      3'b001: n2774_o = 4'b0000;
      default: n2774_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2770_o)
      3'b100: n2778_o = 1'b1;
      3'b010: n2778_o = 1'b1;
      3'b001: n2778_o = 1'b0;
      default: n2778_o = 1'b0;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2770_o)
      3'b100: n2780_o = n2764_o;
      3'b010: n2780_o = n2753_o;
      3'b001: n2780_o = 3'b000;
      default: n2780_o = 3'b000;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2770_o)
      3'b100: n2782_o = n2767_o;
      3'b010: n2782_o = n2756_o;
      3'b001: n2782_o = 1'b0;
      default: n2782_o = 1'b0;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2770_o)
      3'b100: n2786_o = 3'b111;
      3'b010: n2786_o = 3'b101;
      3'b001: n2786_o = 3'b101;
      default: n2786_o = 3'b111;
    endcase
  /* T80_MCode.vhd:555:17  */
  assign n2788_o = ir == 8'b11000001;
  /* T80_MCode.vhd:555:32  */
  assign n2790_o = ir == 8'b11010001;
  /* T80_MCode.vhd:555:32  */
  assign n2791_o = n2788_o | n2790_o;
  /* T80_MCode.vhd:555:43  */
  assign n2793_o = ir == 8'b11100001;
  /* T80_MCode.vhd:555:43  */
  assign n2794_o = n2791_o | n2793_o;
  /* T80_MCode.vhd:555:54  */
  assign n2796_o = ir == 8'b11110001;
  /* T80_MCode.vhd:555:54  */
  assign n2797_o = n2794_o | n2796_o;
  /* T80_MCode.vhd:584:17  */
  assign n2799_o = ir == 8'b11101011;
  /* T80_MCode.vhd:589:17  */
  assign n2801_o = ir == 8'b00001000;
  /* T80_MCode.vhd:615:17  */
  assign n2803_o = ir == 8'b11011001;
  /* T80_MCode.vhd:641:38  */
  assign n2804_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:642:33  */
  assign n2806_o = n2804_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:644:33  */
  assign n2808_o = n2804_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:650:33  */
  assign n2810_o = n2804_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:655:33  */
  assign n2812_o = n2804_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:661:33  */
  assign n2814_o = n2804_o == 31'b0000000000000000000000000000101;
  assign n2815_o = {n2814_o, n2812_o, n2810_o, n2808_o, n2806_o};
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2818_o = 3'b101;
      5'b01000: n2818_o = n2179_o;
      5'b00100: n2818_o = 3'b100;
      5'b00010: n2818_o = n2179_o;
      5'b00001: n2818_o = n2179_o;
      default: n2818_o = n2179_o;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2822_o = 4'b1111;
      5'b01000: n2822_o = 4'b0000;
      5'b00100: n2822_o = 4'b0111;
      5'b00010: n2822_o = 4'b0000;
      5'b00001: n2822_o = 4'b0000;
      default: n2822_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2826_o = 1'b0;
      5'b01000: n2826_o = 1'b1;
      5'b00100: n2826_o = 1'b0;
      5'b00010: n2826_o = 1'b1;
      5'b00001: n2826_o = 1'b0;
      default: n2826_o = 1'b0;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2830_o = 4'b0000;
      5'b01000: n2830_o = 4'b0100;
      5'b00100: n2830_o = 4'b0000;
      5'b00010: n2830_o = 4'b0101;
      5'b00001: n2830_o = 4'b0000;
      default: n2830_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2834_o = 4'b0000;
      5'b01000: n2834_o = 4'b0100;
      5'b00100: n2834_o = 4'b0000;
      5'b00010: n2834_o = 4'b0101;
      5'b00001: n2834_o = 4'b0000;
      default: n2834_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2840_o = 3'b111;
      5'b01000: n2840_o = 3'b101;
      5'b00100: n2840_o = 3'b101;
      5'b00010: n2840_o = 3'b101;
      5'b00001: n2840_o = 3'b101;
      default: n2840_o = 3'b111;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2843_o = 1'b0;
      5'b01000: n2843_o = 1'b0;
      5'b00100: n2843_o = 1'b0;
      5'b00010: n2843_o = 1'b1;
      5'b00001: n2843_o = 1'b0;
      default: n2843_o = 1'b0;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2846_o = 1'b0;
      5'b01000: n2846_o = 1'b1;
      5'b00100: n2846_o = 1'b0;
      5'b00010: n2846_o = 1'b0;
      5'b00001: n2846_o = 1'b0;
      default: n2846_o = 1'b0;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2850_o = 1'b1;
      5'b01000: n2850_o = 1'b0;
      5'b00100: n2850_o = 1'b1;
      5'b00010: n2850_o = 1'b0;
      5'b00001: n2850_o = 1'b0;
      default: n2850_o = 1'b0;
    endcase
  /* T80_MCode.vhd:637:17  */
  assign n2852_o = ir == 8'b11100011;
  /* T80_MCode.vhd:670:17  */
  assign n2855_o = ir == 8'b10000000;
  /* T80_MCode.vhd:670:32  */
  assign n2857_o = ir == 8'b10000001;
  /* T80_MCode.vhd:670:32  */
  assign n2858_o = n2855_o | n2857_o;
  /* T80_MCode.vhd:670:43  */
  assign n2860_o = ir == 8'b10000010;
  /* T80_MCode.vhd:670:43  */
  assign n2861_o = n2858_o | n2860_o;
  /* T80_MCode.vhd:670:54  */
  assign n2863_o = ir == 8'b10000011;
  /* T80_MCode.vhd:670:54  */
  assign n2864_o = n2861_o | n2863_o;
  /* T80_MCode.vhd:670:65  */
  assign n2866_o = ir == 8'b10000100;
  /* T80_MCode.vhd:670:65  */
  assign n2867_o = n2864_o | n2866_o;
  /* T80_MCode.vhd:670:76  */
  assign n2869_o = ir == 8'b10000101;
  /* T80_MCode.vhd:670:76  */
  assign n2870_o = n2867_o | n2869_o;
  /* T80_MCode.vhd:670:87  */
  assign n2872_o = ir == 8'b10000111;
  /* T80_MCode.vhd:670:87  */
  assign n2873_o = n2870_o | n2872_o;
  /* T80_MCode.vhd:671:25  */
  assign n2875_o = ir == 8'b10001000;
  /* T80_MCode.vhd:671:25  */
  assign n2876_o = n2873_o | n2875_o;
  /* T80_MCode.vhd:671:36  */
  assign n2878_o = ir == 8'b10001001;
  /* T80_MCode.vhd:671:36  */
  assign n2879_o = n2876_o | n2878_o;
  /* T80_MCode.vhd:671:47  */
  assign n2881_o = ir == 8'b10001010;
  /* T80_MCode.vhd:671:47  */
  assign n2882_o = n2879_o | n2881_o;
  /* T80_MCode.vhd:671:58  */
  assign n2884_o = ir == 8'b10001011;
  /* T80_MCode.vhd:671:58  */
  assign n2885_o = n2882_o | n2884_o;
  /* T80_MCode.vhd:671:69  */
  assign n2887_o = ir == 8'b10001100;
  /* T80_MCode.vhd:671:69  */
  assign n2888_o = n2885_o | n2887_o;
  /* T80_MCode.vhd:671:80  */
  assign n2890_o = ir == 8'b10001101;
  /* T80_MCode.vhd:671:80  */
  assign n2891_o = n2888_o | n2890_o;
  /* T80_MCode.vhd:671:91  */
  assign n2893_o = ir == 8'b10001111;
  /* T80_MCode.vhd:671:91  */
  assign n2894_o = n2891_o | n2893_o;
  /* T80_MCode.vhd:672:25  */
  assign n2896_o = ir == 8'b10010000;
  /* T80_MCode.vhd:672:25  */
  assign n2897_o = n2894_o | n2896_o;
  /* T80_MCode.vhd:672:36  */
  assign n2899_o = ir == 8'b10010001;
  /* T80_MCode.vhd:672:36  */
  assign n2900_o = n2897_o | n2899_o;
  /* T80_MCode.vhd:672:47  */
  assign n2902_o = ir == 8'b10010010;
  /* T80_MCode.vhd:672:47  */
  assign n2903_o = n2900_o | n2902_o;
  /* T80_MCode.vhd:672:58  */
  assign n2905_o = ir == 8'b10010011;
  /* T80_MCode.vhd:672:58  */
  assign n2906_o = n2903_o | n2905_o;
  /* T80_MCode.vhd:672:69  */
  assign n2908_o = ir == 8'b10010100;
  /* T80_MCode.vhd:672:69  */
  assign n2909_o = n2906_o | n2908_o;
  /* T80_MCode.vhd:672:80  */
  assign n2911_o = ir == 8'b10010101;
  /* T80_MCode.vhd:672:80  */
  assign n2912_o = n2909_o | n2911_o;
  /* T80_MCode.vhd:672:91  */
  assign n2914_o = ir == 8'b10010111;
  /* T80_MCode.vhd:672:91  */
  assign n2915_o = n2912_o | n2914_o;
  /* T80_MCode.vhd:673:25  */
  assign n2917_o = ir == 8'b10011000;
  /* T80_MCode.vhd:673:25  */
  assign n2918_o = n2915_o | n2917_o;
  /* T80_MCode.vhd:673:36  */
  assign n2920_o = ir == 8'b10011001;
  /* T80_MCode.vhd:673:36  */
  assign n2921_o = n2918_o | n2920_o;
  /* T80_MCode.vhd:673:47  */
  assign n2923_o = ir == 8'b10011010;
  /* T80_MCode.vhd:673:47  */
  assign n2924_o = n2921_o | n2923_o;
  /* T80_MCode.vhd:673:58  */
  assign n2926_o = ir == 8'b10011011;
  /* T80_MCode.vhd:673:58  */
  assign n2927_o = n2924_o | n2926_o;
  /* T80_MCode.vhd:673:69  */
  assign n2929_o = ir == 8'b10011100;
  /* T80_MCode.vhd:673:69  */
  assign n2930_o = n2927_o | n2929_o;
  /* T80_MCode.vhd:673:80  */
  assign n2932_o = ir == 8'b10011101;
  /* T80_MCode.vhd:673:80  */
  assign n2933_o = n2930_o | n2932_o;
  /* T80_MCode.vhd:673:91  */
  assign n2935_o = ir == 8'b10011111;
  /* T80_MCode.vhd:673:91  */
  assign n2936_o = n2933_o | n2935_o;
  /* T80_MCode.vhd:674:25  */
  assign n2938_o = ir == 8'b10100000;
  /* T80_MCode.vhd:674:25  */
  assign n2939_o = n2936_o | n2938_o;
  /* T80_MCode.vhd:674:36  */
  assign n2941_o = ir == 8'b10100001;
  /* T80_MCode.vhd:674:36  */
  assign n2942_o = n2939_o | n2941_o;
  /* T80_MCode.vhd:674:47  */
  assign n2944_o = ir == 8'b10100010;
  /* T80_MCode.vhd:674:47  */
  assign n2945_o = n2942_o | n2944_o;
  /* T80_MCode.vhd:674:58  */
  assign n2947_o = ir == 8'b10100011;
  /* T80_MCode.vhd:674:58  */
  assign n2948_o = n2945_o | n2947_o;
  /* T80_MCode.vhd:674:69  */
  assign n2950_o = ir == 8'b10100100;
  /* T80_MCode.vhd:674:69  */
  assign n2951_o = n2948_o | n2950_o;
  /* T80_MCode.vhd:674:80  */
  assign n2953_o = ir == 8'b10100101;
  /* T80_MCode.vhd:674:80  */
  assign n2954_o = n2951_o | n2953_o;
  /* T80_MCode.vhd:674:91  */
  assign n2956_o = ir == 8'b10100111;
  /* T80_MCode.vhd:674:91  */
  assign n2957_o = n2954_o | n2956_o;
  /* T80_MCode.vhd:675:25  */
  assign n2959_o = ir == 8'b10101000;
  /* T80_MCode.vhd:675:25  */
  assign n2960_o = n2957_o | n2959_o;
  /* T80_MCode.vhd:675:36  */
  assign n2962_o = ir == 8'b10101001;
  /* T80_MCode.vhd:675:36  */
  assign n2963_o = n2960_o | n2962_o;
  /* T80_MCode.vhd:675:47  */
  assign n2965_o = ir == 8'b10101010;
  /* T80_MCode.vhd:675:47  */
  assign n2966_o = n2963_o | n2965_o;
  /* T80_MCode.vhd:675:58  */
  assign n2968_o = ir == 8'b10101011;
  /* T80_MCode.vhd:675:58  */
  assign n2969_o = n2966_o | n2968_o;
  /* T80_MCode.vhd:675:69  */
  assign n2971_o = ir == 8'b10101100;
  /* T80_MCode.vhd:675:69  */
  assign n2972_o = n2969_o | n2971_o;
  /* T80_MCode.vhd:675:80  */
  assign n2974_o = ir == 8'b10101101;
  /* T80_MCode.vhd:675:80  */
  assign n2975_o = n2972_o | n2974_o;
  /* T80_MCode.vhd:675:91  */
  assign n2977_o = ir == 8'b10101111;
  /* T80_MCode.vhd:675:91  */
  assign n2978_o = n2975_o | n2977_o;
  /* T80_MCode.vhd:676:25  */
  assign n2980_o = ir == 8'b10110000;
  /* T80_MCode.vhd:676:25  */
  assign n2981_o = n2978_o | n2980_o;
  /* T80_MCode.vhd:676:36  */
  assign n2983_o = ir == 8'b10110001;
  /* T80_MCode.vhd:676:36  */
  assign n2984_o = n2981_o | n2983_o;
  /* T80_MCode.vhd:676:47  */
  assign n2986_o = ir == 8'b10110010;
  /* T80_MCode.vhd:676:47  */
  assign n2987_o = n2984_o | n2986_o;
  /* T80_MCode.vhd:676:58  */
  assign n2989_o = ir == 8'b10110011;
  /* T80_MCode.vhd:676:58  */
  assign n2990_o = n2987_o | n2989_o;
  /* T80_MCode.vhd:676:69  */
  assign n2992_o = ir == 8'b10110100;
  /* T80_MCode.vhd:676:69  */
  assign n2993_o = n2990_o | n2992_o;
  /* T80_MCode.vhd:676:80  */
  assign n2995_o = ir == 8'b10110101;
  /* T80_MCode.vhd:676:80  */
  assign n2996_o = n2993_o | n2995_o;
  /* T80_MCode.vhd:676:91  */
  assign n2998_o = ir == 8'b10110111;
  /* T80_MCode.vhd:676:91  */
  assign n2999_o = n2996_o | n2998_o;
  /* T80_MCode.vhd:677:25  */
  assign n3001_o = ir == 8'b10111000;
  /* T80_MCode.vhd:677:25  */
  assign n3002_o = n2999_o | n3001_o;
  /* T80_MCode.vhd:677:36  */
  assign n3004_o = ir == 8'b10111001;
  /* T80_MCode.vhd:677:36  */
  assign n3005_o = n3002_o | n3004_o;
  /* T80_MCode.vhd:677:47  */
  assign n3007_o = ir == 8'b10111010;
  /* T80_MCode.vhd:677:47  */
  assign n3008_o = n3005_o | n3007_o;
  /* T80_MCode.vhd:677:58  */
  assign n3010_o = ir == 8'b10111011;
  /* T80_MCode.vhd:677:58  */
  assign n3011_o = n3008_o | n3010_o;
  /* T80_MCode.vhd:677:69  */
  assign n3013_o = ir == 8'b10111100;
  /* T80_MCode.vhd:677:69  */
  assign n3014_o = n3011_o | n3013_o;
  /* T80_MCode.vhd:677:80  */
  assign n3016_o = ir == 8'b10111101;
  /* T80_MCode.vhd:677:80  */
  assign n3017_o = n3014_o | n3016_o;
  /* T80_MCode.vhd:677:91  */
  assign n3019_o = ir == 8'b10111111;
  /* T80_MCode.vhd:677:91  */
  assign n3020_o = n3017_o | n3019_o;
  /* T80_MCode.vhd:700:30  */
  assign n3021_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:701:25  */
  assign n3023_o = n3021_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:703:25  */
  assign n3026_o = n3021_o == 31'b0000000000000000000000000000010;
  assign n3027_o = {n3026_o, n3023_o};
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3027_o)
      2'b10: n3030_o = 1'b1;
      2'b01: n3030_o = 1'b0;
      default: n3030_o = 1'b0;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3027_o)
      2'b10: n3032_o = 3'b111;
      2'b01: n3032_o = 3'b000;
      default: n3032_o = 3'b000;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3027_o)
      2'b10: n3034_o = n2173_o;
      2'b01: n3034_o = 3'b000;
      default: n3034_o = 3'b000;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3027_o)
      2'b10: n3037_o = 1'b1;
      2'b01: n3037_o = 1'b0;
      default: n3037_o = 1'b0;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3027_o)
      2'b10: n3040_o = 3'b111;
      2'b01: n3040_o = 3'b010;
      default: n3040_o = 3'b111;
    endcase
  /* T80_MCode.vhd:690:17  */
  assign n3042_o = ir == 8'b10000110;
  /* T80_MCode.vhd:690:32  */
  assign n3044_o = ir == 8'b10001110;
  /* T80_MCode.vhd:690:32  */
  assign n3045_o = n3042_o | n3044_o;
  /* T80_MCode.vhd:690:43  */
  assign n3047_o = ir == 8'b10010110;
  /* T80_MCode.vhd:690:43  */
  assign n3048_o = n3045_o | n3047_o;
  /* T80_MCode.vhd:690:54  */
  assign n3050_o = ir == 8'b10011110;
  /* T80_MCode.vhd:690:54  */
  assign n3051_o = n3048_o | n3050_o;
  /* T80_MCode.vhd:690:65  */
  assign n3053_o = ir == 8'b10100110;
  /* T80_MCode.vhd:690:65  */
  assign n3054_o = n3051_o | n3053_o;
  /* T80_MCode.vhd:690:76  */
  assign n3056_o = ir == 8'b10101110;
  /* T80_MCode.vhd:690:76  */
  assign n3057_o = n3054_o | n3056_o;
  /* T80_MCode.vhd:690:87  */
  assign n3059_o = ir == 8'b10110110;
  /* T80_MCode.vhd:690:87  */
  assign n3060_o = n3057_o | n3059_o;
  /* T80_MCode.vhd:690:98  */
  assign n3062_o = ir == 8'b10111110;
  /* T80_MCode.vhd:690:98  */
  assign n3063_o = n3060_o | n3062_o;
  /* T80_MCode.vhd:720:35  */
  assign n3065_o = mcycle == 3'b010;
  /* T80_MCode.vhd:720:25  */
  assign n3069_o = n3065_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:720:25  */
  assign n3072_o = n3065_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:720:25  */
  assign n3074_o = n3065_o ? 3'b111 : 3'b000;
  /* T80_MCode.vhd:720:25  */
  assign n3076_o = n3065_o ? n2173_o : 3'b000;
  /* T80_MCode.vhd:720:25  */
  assign n3079_o = n3065_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:710:17  */
  assign n3081_o = ir == 8'b11000110;
  /* T80_MCode.vhd:710:32  */
  assign n3083_o = ir == 8'b11001110;
  /* T80_MCode.vhd:710:32  */
  assign n3084_o = n3081_o | n3083_o;
  /* T80_MCode.vhd:710:43  */
  assign n3086_o = ir == 8'b11010110;
  /* T80_MCode.vhd:710:43  */
  assign n3087_o = n3084_o | n3086_o;
  /* T80_MCode.vhd:710:54  */
  assign n3089_o = ir == 8'b11011110;
  /* T80_MCode.vhd:710:54  */
  assign n3090_o = n3087_o | n3089_o;
  /* T80_MCode.vhd:710:65  */
  assign n3092_o = ir == 8'b11100110;
  /* T80_MCode.vhd:710:65  */
  assign n3093_o = n3090_o | n3092_o;
  /* T80_MCode.vhd:710:76  */
  assign n3095_o = ir == 8'b11101110;
  /* T80_MCode.vhd:710:76  */
  assign n3096_o = n3093_o | n3095_o;
  /* T80_MCode.vhd:710:87  */
  assign n3098_o = ir == 8'b11110110;
  /* T80_MCode.vhd:710:87  */
  assign n3099_o = n3096_o | n3098_o;
  /* T80_MCode.vhd:710:98  */
  assign n3101_o = ir == 8'b11111110;
  /* T80_MCode.vhd:710:98  */
  assign n3102_o = n3099_o | n3101_o;
  /* T80_MCode.vhd:727:17  */
  assign n3104_o = ir == 8'b00000100;
  /* T80_MCode.vhd:727:32  */
  assign n3106_o = ir == 8'b00001100;
  /* T80_MCode.vhd:727:32  */
  assign n3107_o = n3104_o | n3106_o;
  /* T80_MCode.vhd:727:43  */
  assign n3109_o = ir == 8'b00010100;
  /* T80_MCode.vhd:727:43  */
  assign n3110_o = n3107_o | n3109_o;
  /* T80_MCode.vhd:727:54  */
  assign n3112_o = ir == 8'b00011100;
  /* T80_MCode.vhd:727:54  */
  assign n3113_o = n3110_o | n3112_o;
  /* T80_MCode.vhd:727:65  */
  assign n3115_o = ir == 8'b00100100;
  /* T80_MCode.vhd:727:65  */
  assign n3116_o = n3113_o | n3115_o;
  /* T80_MCode.vhd:727:76  */
  assign n3118_o = ir == 8'b00101100;
  /* T80_MCode.vhd:727:76  */
  assign n3119_o = n3116_o | n3118_o;
  /* T80_MCode.vhd:727:87  */
  assign n3121_o = ir == 8'b00111100;
  /* T80_MCode.vhd:727:87  */
  assign n3122_o = n3119_o | n3121_o;
  /* T80_MCode.vhd:738:30  */
  assign n3123_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:739:25  */
  assign n3125_o = n3123_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:741:25  */
  assign n3127_o = n3123_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:750:25  */
  assign n3129_o = n3123_o == 31'b0000000000000000000000000000011;
  assign n3130_o = {n3129_o, n3127_o, n3125_o};
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3132_o = n2179_o;
      3'b010: n3132_o = 3'b100;
      3'b001: n3132_o = n2179_o;
      default: n3132_o = n2179_o;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3135_o = 1'b0;
      3'b010: n3135_o = 1'b1;
      3'b001: n3135_o = 1'b0;
      default: n3135_o = 1'b0;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3137_o = 3'b000;
      3'b010: n3137_o = n2172_o;
      3'b001: n3137_o = 3'b000;
      default: n3137_o = 3'b000;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3140_o = 4'b0000;
      3'b010: n3140_o = 4'b1010;
      3'b001: n3140_o = 4'b0000;
      default: n3140_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3142_o = n2182_o;
      3'b010: n3142_o = 4'b0000;
      3'b001: n3142_o = n2182_o;
      default: n3142_o = n2182_o;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3145_o = 1'b0;
      3'b010: n3145_o = 1'b1;
      3'b001: n3145_o = 1'b0;
      default: n3145_o = 1'b0;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3148_o = 1'b0;
      3'b010: n3148_o = 1'b1;
      3'b001: n3148_o = 1'b0;
      default: n3148_o = 1'b0;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3152_o = 3'b111;
      3'b010: n3152_o = 3'b010;
      3'b001: n3152_o = 3'b010;
      default: n3152_o = 3'b111;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3155_o = 1'b1;
      3'b010: n3155_o = 1'b0;
      3'b001: n3155_o = 1'b0;
      default: n3155_o = 1'b0;
    endcase
  /* T80_MCode.vhd:735:17  */
  assign n3157_o = ir == 8'b00110100;
  /* T80_MCode.vhd:754:17  */
  assign n3159_o = ir == 8'b00000101;
  /* T80_MCode.vhd:754:32  */
  assign n3161_o = ir == 8'b00001101;
  /* T80_MCode.vhd:754:32  */
  assign n3162_o = n3159_o | n3161_o;
  /* T80_MCode.vhd:754:43  */
  assign n3164_o = ir == 8'b00010101;
  /* T80_MCode.vhd:754:43  */
  assign n3165_o = n3162_o | n3164_o;
  /* T80_MCode.vhd:754:54  */
  assign n3167_o = ir == 8'b00011101;
  /* T80_MCode.vhd:754:54  */
  assign n3168_o = n3165_o | n3167_o;
  /* T80_MCode.vhd:754:65  */
  assign n3170_o = ir == 8'b00100101;
  /* T80_MCode.vhd:754:65  */
  assign n3171_o = n3168_o | n3170_o;
  /* T80_MCode.vhd:754:76  */
  assign n3173_o = ir == 8'b00101101;
  /* T80_MCode.vhd:754:76  */
  assign n3174_o = n3171_o | n3173_o;
  /* T80_MCode.vhd:754:87  */
  assign n3176_o = ir == 8'b00111101;
  /* T80_MCode.vhd:754:87  */
  assign n3177_o = n3174_o | n3176_o;
  /* T80_MCode.vhd:765:30  */
  assign n3178_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:766:25  */
  assign n3180_o = n3178_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:768:25  */
  assign n3182_o = n3178_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:777:25  */
  assign n3184_o = n3178_o == 31'b0000000000000000000000000000011;
  assign n3185_o = {n3184_o, n3182_o, n3180_o};
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3187_o = n2179_o;
      3'b010: n3187_o = 3'b100;
      3'b001: n3187_o = n2179_o;
      default: n3187_o = n2179_o;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3190_o = 1'b0;
      3'b010: n3190_o = 1'b1;
      3'b001: n3190_o = 1'b0;
      default: n3190_o = 1'b0;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3192_o = 3'b000;
      3'b010: n3192_o = n2172_o;
      3'b001: n3192_o = 3'b000;
      default: n3192_o = 3'b000;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3195_o = 4'b0000;
      3'b010: n3195_o = 4'b1010;
      3'b001: n3195_o = 4'b0000;
      default: n3195_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3197_o = n2182_o;
      3'b010: n3197_o = 4'b0010;
      3'b001: n3197_o = n2182_o;
      default: n3197_o = n2182_o;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3200_o = 1'b0;
      3'b010: n3200_o = 1'b1;
      3'b001: n3200_o = 1'b0;
      default: n3200_o = 1'b0;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3203_o = 1'b0;
      3'b010: n3203_o = 1'b1;
      3'b001: n3203_o = 1'b0;
      default: n3203_o = 1'b0;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3207_o = 3'b111;
      3'b010: n3207_o = 3'b010;
      3'b001: n3207_o = 3'b010;
      default: n3207_o = 3'b111;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3210_o = 1'b1;
      3'b010: n3210_o = 1'b0;
      3'b001: n3210_o = 1'b0;
      default: n3210_o = 1'b0;
    endcase
  /* T80_MCode.vhd:762:17  */
  assign n3212_o = ir == 8'b00110101;
  /* T80_MCode.vhd:783:17  */
  assign n3215_o = ir == 8'b00100111;
  /* T80_MCode.vhd:789:17  */
  assign n3217_o = ir == 8'b00101111;
  /* T80_MCode.vhd:792:17  */
  assign n3219_o = ir == 8'b00111111;
  /* T80_MCode.vhd:795:17  */
  assign n3221_o = ir == 8'b00110111;
  /* T80_MCode.vhd:802:38  */
  assign n3222_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:803:33  */
  assign n3224_o = n3222_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:808:33  */
  assign n3226_o = n3222_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:813:33  */
  assign n3228_o = n3222_o == 31'b0000000000000000000000000000011;
  assign n3229_o = {n3228_o, n3226_o, n3224_o};
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3229_o)
      3'b100: n3231_o = n2179_o;
      3'b010: n3231_o = n2179_o;
      3'b001: n3231_o = 3'b101;
      default: n3231_o = n2179_o;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3229_o)
      3'b100: n3235_o = 4'b0000;
      3'b010: n3235_o = 4'b1111;
      3'b001: n3235_o = 4'b1111;
      default: n3235_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3229_o)
      3'b100: n3239_o = 4'b0000;
      3'b010: n3239_o = 4'b1100;
      3'b001: n3239_o = 4'b1101;
      default: n3239_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3229_o)
      3'b100: n3243_o = 3'b111;
      3'b010: n3243_o = 3'b101;
      3'b001: n3243_o = 3'b101;
      default: n3243_o = 3'b111;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3229_o)
      3'b100: n3247_o = 1'b1;
      3'b010: n3247_o = 1'b1;
      3'b001: n3247_o = 1'b0;
      default: n3247_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:38  */
  assign n3248_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:821:33  */
  assign n3250_o = n3248_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:827:33  */
  assign n3252_o = n3248_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:833:33  */
  assign n3254_o = n3248_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:836:33  */
  assign n3256_o = n3248_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:839:33  */
  assign n3258_o = n3248_o == 31'b0000000000000000000000000000101;
  assign n3259_o = {n3258_o, n3256_o, n3254_o, n3252_o, n3250_o};
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3261_o = n2179_o;
      5'b01000: n3261_o = n2179_o;
      5'b00100: n3261_o = n2179_o;
      5'b00010: n3261_o = n2179_o;
      5'b00001: n3261_o = 3'b101;
      default: n3261_o = n2179_o;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3264_o = 1'b0;
      5'b01000: n3264_o = 1'b1;
      5'b00100: n3264_o = 1'b0;
      5'b00010: n3264_o = 1'b0;
      5'b00001: n3264_o = 1'b0;
      default: n3264_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3268_o = 4'b0000;
      5'b01000: n3268_o = 4'b0000;
      5'b00100: n3268_o = 4'b0000;
      5'b00010: n3268_o = 4'b1111;
      5'b00001: n3268_o = 4'b1111;
      default: n3268_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3272_o = 4'b0000;
      5'b01000: n3272_o = 4'b0000;
      5'b00100: n3272_o = 4'b0000;
      5'b00010: n3272_o = 4'b1100;
      5'b00001: n3272_o = 4'b1101;
      default: n3272_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3276_o = 3'b111;
      5'b01000: n3276_o = 3'b111;
      5'b00100: n3276_o = 3'b111;
      5'b00010: n3276_o = 3'b101;
      5'b00001: n3276_o = 3'b101;
      default: n3276_o = 3'b111;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3279_o = 1'b1;
      5'b01000: n3279_o = 1'b0;
      5'b00100: n3279_o = 1'b0;
      5'b00010: n3279_o = 1'b0;
      5'b00001: n3279_o = 1'b0;
      default: n3279_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3283_o = 1'b0;
      5'b01000: n3283_o = 1'b1;
      5'b00100: n3283_o = 1'b0;
      5'b00010: n3283_o = 1'b0;
      5'b00001: n3283_o = 1'b1;
      default: n3283_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3287_o = 1'b0;
      5'b01000: n3287_o = 1'b0;
      5'b00100: n3287_o = 1'b1;
      5'b00010: n3287_o = 1'b1;
      5'b00001: n3287_o = 1'b0;
      default: n3287_o = 1'b0;
    endcase
  /* T80_MCode.vhd:817:25  */
  assign n3290_o = intcycle ? 3'b101 : 3'b001;
  /* T80_MCode.vhd:817:25  */
  assign n3291_o = intcycle ? n3261_o : n2179_o;
  /* T80_MCode.vhd:817:25  */
  assign n3293_o = intcycle ? n3264_o : 1'b0;
  /* T80_MCode.vhd:817:25  */
  assign n3295_o = intcycle ? n3268_o : 4'b0000;
  /* T80_MCode.vhd:817:25  */
  assign n3297_o = intcycle ? n3272_o : 4'b0000;
  /* T80_MCode.vhd:817:25  */
  assign n3299_o = intcycle ? n3276_o : 3'b111;
  /* T80_MCode.vhd:817:25  */
  assign n3301_o = intcycle ? n3279_o : 1'b0;
  /* T80_MCode.vhd:817:25  */
  assign n3303_o = intcycle ? n3283_o : 1'b0;
  /* T80_MCode.vhd:817:25  */
  assign n3305_o = intcycle ? n3287_o : 1'b0;
  /* T80_MCode.vhd:799:25  */
  assign n3307_o = nmicycle ? 3'b011 : n3290_o;
  /* T80_MCode.vhd:799:25  */
  assign n3308_o = nmicycle ? n3231_o : n3291_o;
  /* T80_MCode.vhd:799:25  */
  assign n3310_o = nmicycle ? 1'b0 : n3293_o;
  /* T80_MCode.vhd:799:25  */
  assign n3311_o = nmicycle ? n3235_o : n3295_o;
  /* T80_MCode.vhd:799:25  */
  assign n3312_o = nmicycle ? n3239_o : n3297_o;
  /* T80_MCode.vhd:799:25  */
  assign n3313_o = nmicycle ? n3243_o : n3299_o;
  /* T80_MCode.vhd:799:25  */
  assign n3315_o = nmicycle ? 1'b0 : n3301_o;
  /* T80_MCode.vhd:799:25  */
  assign n3317_o = nmicycle ? 1'b0 : n3303_o;
  /* T80_MCode.vhd:799:25  */
  assign n3318_o = nmicycle ? n3247_o : n3305_o;
  /* T80_MCode.vhd:798:17  */
  assign n3320_o = ir == 8'b00000000;
  /* T80_MCode.vhd:846:17  */
  assign n3322_o = ir == 8'b01110110;
  /* T80_MCode.vhd:849:17  */
  assign n3324_o = ir == 8'b11110011;
  /* T80_MCode.vhd:852:17  */
  assign n3326_o = ir == 8'b11111011;
  /* T80_MCode.vhd:860:30  */
  assign n3327_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:867:60  */
  assign n3329_o = ir[5:4];
  /* T80_MCode.vhd:867:38  */
  assign n3330_o = {29'b0, n3329_o};  //  uext
  /* T80_MCode.vhd:869:70  */
  assign n3331_o = ir[5:4];
  /* T80_MCode.vhd:868:33  */
  assign n3334_o = n3330_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:868:39  */
  assign n3336_o = n3330_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:868:39  */
  assign n3337_o = n3334_o | n3336_o;
  /* T80_MCode.vhd:868:41  */
  assign n3339_o = n3330_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:868:41  */
  assign n3340_o = n3337_o | n3339_o;
  /* T80_MCode.vhd:867:33  */
  always @*
    case (n3340_o)
      1'b1: n3342_o = 1'b1;
      default: n3342_o = 1'b0;
    endcase
  /* T80_MCode.vhd:867:33  */
  always @*
    case (n3340_o)
      1'b1: n3344_o = n3331_o;
      default: n3344_o = 2'b00;
    endcase
  /* T80_MCode.vhd:867:33  */
  always @*
    case (n3340_o)
      1'b1: n3347_o = 1'b0;
      default: n3347_o = 1'b1;
    endcase
  /* T80_MCode.vhd:861:25  */
  assign n3349_o = n3327_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:883:60  */
  assign n3351_o = ir[5:4];
  /* T80_MCode.vhd:883:38  */
  assign n3352_o = {29'b0, n3351_o};  //  uext
  /* T80_MCode.vhd:885:70  */
  assign n3353_o = ir[5:4];
  /* T80_MCode.vhd:884:33  */
  assign n3355_o = n3352_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:884:39  */
  assign n3357_o = n3352_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:884:39  */
  assign n3358_o = n3355_o | n3357_o;
  /* T80_MCode.vhd:884:41  */
  assign n3360_o = n3352_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:884:41  */
  assign n3361_o = n3358_o | n3360_o;
  /* T80_MCode.vhd:883:33  */
  always @*
    case (n3361_o)
      1'b1: n3364_o = 1'b0;
      default: n3364_o = 1'b1;
    endcase
  /* T80_MCode.vhd:883:33  */
  always @*
    case (n3361_o)
      1'b1: n3366_o = n3353_o;
      default: n3366_o = 2'b00;
    endcase
  /* T80_MCode.vhd:883:33  */
  always @*
    case (n3361_o)
      1'b1: n3369_o = 1'b0;
      default: n3369_o = 1'b1;
    endcase
  /* T80_MCode.vhd:877:25  */
  assign n3371_o = n3327_o == 31'b0000000000000000000000000000011;
  assign n3372_o = {n3371_o, n3349_o};
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3374_o = n2179_o;
      2'b01: n3374_o = 3'b100;
      default: n3374_o = n2179_o;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3378_o = 1'b1;
      2'b01: n3378_o = 1'b1;
      default: n3378_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3380_o = 3'b100;
      2'b01: n3380_o = 3'b101;
      default: n3380_o = 3'b000;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3382_o = n3364_o;
      2'b01: n3382_o = n3342_o;
      default: n3382_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3384_o = n3366_o;
      2'b01: n3384_o = n3344_o;
      default: n3384_o = 2'b00;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3386_o = n3369_o;
      2'b01: n3386_o = n3347_o;
      default: n3386_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3389_o = 4'b0001;
      2'b01: n3389_o = 4'b0000;
      default: n3389_o = n2182_o;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3393_o = 1'b1;
      2'b01: n3393_o = 1'b1;
      default: n3393_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3397_o = 1'b1;
      2'b01: n3397_o = 1'b1;
      default: n3397_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3400_o = 2'b00;
      2'b01: n3400_o = 2'b11;
      default: n3400_o = 2'b00;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3404_o = 1'b1;
      2'b01: n3404_o = 1'b1;
      default: n3404_o = 1'b0;
    endcase
  /* T80_MCode.vhd:857:17  */
  assign n3406_o = ir == 8'b00001001;
  /* T80_MCode.vhd:857:32  */
  assign n3408_o = ir == 8'b00011001;
  /* T80_MCode.vhd:857:32  */
  assign n3409_o = n3406_o | n3408_o;
  /* T80_MCode.vhd:857:43  */
  assign n3411_o = ir == 8'b00101001;
  /* T80_MCode.vhd:857:43  */
  assign n3412_o = n3409_o | n3411_o;
  /* T80_MCode.vhd:857:54  */
  assign n3414_o = ir == 8'b00111001;
  /* T80_MCode.vhd:857:54  */
  assign n3415_o = n3412_o | n3414_o;
  /* T80_MCode.vhd:892:17  */
  assign n3418_o = ir == 8'b00000011;
  /* T80_MCode.vhd:892:32  */
  assign n3420_o = ir == 8'b00010011;
  /* T80_MCode.vhd:892:32  */
  assign n3421_o = n3418_o | n3420_o;
  /* T80_MCode.vhd:892:43  */
  assign n3423_o = ir == 8'b00100011;
  /* T80_MCode.vhd:892:43  */
  assign n3424_o = n3421_o | n3423_o;
  /* T80_MCode.vhd:892:54  */
  assign n3426_o = ir == 8'b00110011;
  /* T80_MCode.vhd:892:54  */
  assign n3427_o = n3424_o | n3426_o;
  /* T80_MCode.vhd:897:17  */
  assign n3430_o = ir == 8'b00001011;
  /* T80_MCode.vhd:897:32  */
  assign n3432_o = ir == 8'b00011011;
  /* T80_MCode.vhd:897:32  */
  assign n3433_o = n3430_o | n3432_o;
  /* T80_MCode.vhd:897:43  */
  assign n3435_o = ir == 8'b00101011;
  /* T80_MCode.vhd:897:43  */
  assign n3436_o = n3433_o | n3435_o;
  /* T80_MCode.vhd:897:54  */
  assign n3438_o = ir == 8'b00111011;
  /* T80_MCode.vhd:897:54  */
  assign n3439_o = n3436_o | n3438_o;
  /* T80_MCode.vhd:904:17  */
  assign n3442_o = ir == 8'b00000111;
  /* T80_MCode.vhd:906:25  */
  assign n3444_o = ir == 8'b00010111;
  /* T80_MCode.vhd:906:25  */
  assign n3445_o = n3442_o | n3444_o;
  /* T80_MCode.vhd:908:25  */
  assign n3447_o = ir == 8'b00001111;
  /* T80_MCode.vhd:908:25  */
  assign n3448_o = n3445_o | n3447_o;
  /* T80_MCode.vhd:910:25  */
  assign n3450_o = ir == 8'b00011111;
  /* T80_MCode.vhd:910:25  */
  assign n3451_o = n3448_o | n3450_o;
  /* T80_MCode.vhd:921:30  */
  assign n3452_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:922:25  */
  assign n3454_o = n3452_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:925:25  */
  assign n3456_o = n3452_o == 31'b0000000000000000000000000000011;
  assign n3457_o = {n3456_o, n3454_o};
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3457_o)
      2'b10: n3461_o = 1'b1;
      2'b01: n3461_o = 1'b1;
      default: n3461_o = 1'b0;
    endcase
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3457_o)
      2'b10: n3464_o = 1'b1;
      2'b01: n3464_o = 1'b0;
      default: n3464_o = 1'b0;
    endcase
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3457_o)
      2'b10: n3467_o = 1'b0;
      2'b01: n3467_o = 1'b1;
      default: n3467_o = 1'b0;
    endcase
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3457_o)
      2'b10: n3470_o = 1'b1;
      2'b01: n3470_o = 1'b0;
      default: n3470_o = 1'b0;
    endcase
  /* T80_MCode.vhd:918:17  */
  assign n3472_o = ir == 8'b11000011;
  /* T80_MCode.vhd:990:38  */
  assign n3474_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:991:33  */
  assign n3476_o = n3474_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:997:73  */
  assign n3478_o = ir[5:3];
  /* T80_MCode.vhd:178:47  */
  assign n3483_o = f[6];
  /* T80_MCode.vhd:178:56  */
  assign n3484_o = ~n3483_o;
  /* T80_MCode.vhd:178:25  */
  assign n3486_o = n3478_o == 3'b000;
  /* T80_MCode.vhd:179:47  */
  assign n3487_o = f[6];
  /* T80_MCode.vhd:179:25  */
  assign n3489_o = n3478_o == 3'b001;
  /* T80_MCode.vhd:180:47  */
  assign n3490_o = f[0];
  /* T80_MCode.vhd:180:56  */
  assign n3491_o = ~n3490_o;
  /* T80_MCode.vhd:180:25  */
  assign n3493_o = n3478_o == 3'b010;
  /* T80_MCode.vhd:181:47  */
  assign n3494_o = f[0];
  /* T80_MCode.vhd:181:25  */
  assign n3496_o = n3478_o == 3'b011;
  /* T80_MCode.vhd:182:47  */
  assign n3497_o = f[2];
  /* T80_MCode.vhd:182:56  */
  assign n3498_o = ~n3497_o;
  /* T80_MCode.vhd:182:25  */
  assign n3500_o = n3478_o == 3'b100;
  /* T80_MCode.vhd:183:47  */
  assign n3501_o = f[2];
  /* T80_MCode.vhd:183:25  */
  assign n3503_o = n3478_o == 3'b101;
  /* T80_MCode.vhd:184:47  */
  assign n3504_o = f[7];
  /* T80_MCode.vhd:184:56  */
  assign n3505_o = ~n3504_o;
  /* T80_MCode.vhd:184:25  */
  assign n3507_o = n3478_o == 3'b110;
  /* T80_MCode.vhd:185:47  */
  assign n3508_o = f[7];
  /* T80_MCode.vhd:185:25  */
  assign n3510_o = n3478_o == 3'b111;
  assign n3511_o = {n3510_o, n3507_o, n3503_o, n3500_o, n3496_o, n3493_o, n3489_o, n3486_o};
  /* T80_MCode.vhd:177:25  */
  always @*
    case (n3511_o)
      8'b10000000: n3513_o = n3508_o;
      8'b01000000: n3513_o = n3505_o;
      8'b00100000: n3513_o = n3501_o;
      8'b00010000: n3513_o = n3498_o;
      8'b00001000: n3513_o = n3494_o;
      8'b00000100: n3513_o = n3491_o;
      8'b00000010: n3513_o = n3487_o;
      8'b00000001: n3513_o = n3484_o;
      default: n3513_o = 1'bX;
    endcase
  /* T80_MCode.vhd:997:41  */
  assign n3516_o = n3513_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:994:33  */
  assign n3518_o = n3474_o == 31'b0000000000000000000000000000011;
  assign n3519_o = {n3518_o, n3476_o};
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3519_o)
      2'b10: n3523_o = 1'b1;
      2'b01: n3523_o = 1'b1;
      default: n3523_o = 1'b0;
    endcase
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3519_o)
      2'b10: n3525_o = n3516_o;
      2'b01: n3525_o = 1'b0;
      default: n3525_o = 1'b0;
    endcase
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3519_o)
      2'b10: n3528_o = 1'b0;
      2'b01: n3528_o = 1'b1;
      default: n3528_o = 1'b0;
    endcase
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3519_o)
      2'b10: n3531_o = 1'b1;
      2'b01: n3531_o = 1'b0;
      default: n3531_o = 1'b0;
    endcase
  /* T80_MCode.vhd:931:17  */
  assign n3533_o = ir == 8'b11000010;
  /* T80_MCode.vhd:931:32  */
  assign n3535_o = ir == 8'b11001010;
  /* T80_MCode.vhd:931:32  */
  assign n3536_o = n3533_o | n3535_o;
  /* T80_MCode.vhd:931:43  */
  assign n3538_o = ir == 8'b11010010;
  /* T80_MCode.vhd:931:43  */
  assign n3539_o = n3536_o | n3538_o;
  /* T80_MCode.vhd:931:54  */
  assign n3541_o = ir == 8'b11011010;
  /* T80_MCode.vhd:931:54  */
  assign n3542_o = n3539_o | n3541_o;
  /* T80_MCode.vhd:931:65  */
  assign n3544_o = ir == 8'b11100010;
  /* T80_MCode.vhd:931:65  */
  assign n3545_o = n3542_o | n3544_o;
  /* T80_MCode.vhd:931:76  */
  assign n3547_o = ir == 8'b11101010;
  /* T80_MCode.vhd:931:76  */
  assign n3548_o = n3545_o | n3547_o;
  /* T80_MCode.vhd:931:87  */
  assign n3550_o = ir == 8'b11110010;
  /* T80_MCode.vhd:931:87  */
  assign n3551_o = n3548_o | n3550_o;
  /* T80_MCode.vhd:931:98  */
  assign n3553_o = ir == 8'b11111010;
  /* T80_MCode.vhd:931:98  */
  assign n3554_o = n3551_o | n3553_o;
  /* T80_MCode.vhd:1003:17  */
  assign n3556_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1017:17  */
  assign n3558_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1034:17  */
  assign n3560_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1051:17  */
  assign n3562_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1068:17  */
  assign n3564_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1085:17  */
  assign n3566_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1088:17  */
  assign n3568_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1118:30  */
  assign n3569_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1119:25  */
  assign n3571_o = n3569_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1122:25  */
  assign n3573_o = n3569_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1129:25  */
  assign n3575_o = n3569_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1134:25  */
  assign n3577_o = n3569_o == 31'b0000000000000000000000000000101;
  assign n3578_o = {n3577_o, n3575_o, n3573_o, n3571_o};
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3580_o = n2179_o;
      4'b0100: n3580_o = n2179_o;
      4'b0010: n3580_o = 3'b100;
      4'b0001: n3580_o = n2179_o;
      default: n3580_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3584_o = 1'b0;
      4'b0100: n3584_o = 1'b0;
      4'b0010: n3584_o = 1'b1;
      4'b0001: n3584_o = 1'b1;
      default: n3584_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3588_o = 4'b0000;
      4'b0100: n3588_o = 4'b1111;
      4'b0010: n3588_o = 4'b1111;
      4'b0001: n3588_o = 4'b0000;
      default: n3588_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3592_o = 4'b0000;
      4'b0100: n3592_o = 4'b1100;
      4'b0010: n3592_o = 4'b1101;
      4'b0001: n3592_o = 4'b0000;
      default: n3592_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3596_o = 3'b111;
      4'b0100: n3596_o = 3'b101;
      4'b0010: n3596_o = 3'b101;
      4'b0001: n3596_o = 3'b111;
      default: n3596_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3599_o = 1'b1;
      4'b0100: n3599_o = 1'b0;
      4'b0010: n3599_o = 1'b0;
      4'b0001: n3599_o = 1'b0;
      default: n3599_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3602_o = 1'b0;
      4'b0100: n3602_o = 1'b0;
      4'b0010: n3602_o = 1'b0;
      4'b0001: n3602_o = 1'b1;
      default: n3602_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3605_o = 1'b0;
      4'b0100: n3605_o = 1'b0;
      4'b0010: n3605_o = 1'b1;
      4'b0001: n3605_o = 1'b0;
      default: n3605_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3609_o = 1'b1;
      4'b0100: n3609_o = 1'b1;
      4'b0010: n3609_o = 1'b0;
      4'b0001: n3609_o = 1'b0;
      default: n3609_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1115:17  */
  assign n3611_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1143:38  */
  assign n3614_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1144:33  */
  assign n3616_o = n3614_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1150:73  */
  assign n3618_o = ir[5:3];
  /* T80_MCode.vhd:178:47  */
  assign n3623_o = f[6];
  /* T80_MCode.vhd:178:56  */
  assign n3624_o = ~n3623_o;
  /* T80_MCode.vhd:178:25  */
  assign n3626_o = n3618_o == 3'b000;
  /* T80_MCode.vhd:179:47  */
  assign n3627_o = f[6];
  /* T80_MCode.vhd:179:25  */
  assign n3629_o = n3618_o == 3'b001;
  /* T80_MCode.vhd:180:47  */
  assign n3630_o = f[0];
  /* T80_MCode.vhd:180:56  */
  assign n3631_o = ~n3630_o;
  /* T80_MCode.vhd:180:25  */
  assign n3633_o = n3618_o == 3'b010;
  /* T80_MCode.vhd:181:47  */
  assign n3634_o = f[0];
  /* T80_MCode.vhd:181:25  */
  assign n3636_o = n3618_o == 3'b011;
  /* T80_MCode.vhd:182:47  */
  assign n3637_o = f[2];
  /* T80_MCode.vhd:182:56  */
  assign n3638_o = ~n3637_o;
  /* T80_MCode.vhd:182:25  */
  assign n3640_o = n3618_o == 3'b100;
  /* T80_MCode.vhd:183:47  */
  assign n3641_o = f[2];
  /* T80_MCode.vhd:183:25  */
  assign n3643_o = n3618_o == 3'b101;
  /* T80_MCode.vhd:184:47  */
  assign n3644_o = f[7];
  /* T80_MCode.vhd:184:56  */
  assign n3645_o = ~n3644_o;
  /* T80_MCode.vhd:184:25  */
  assign n3647_o = n3618_o == 3'b110;
  /* T80_MCode.vhd:185:47  */
  assign n3648_o = f[7];
  /* T80_MCode.vhd:185:25  */
  assign n3650_o = n3618_o == 3'b111;
  assign n3651_o = {n3650_o, n3647_o, n3643_o, n3640_o, n3636_o, n3633_o, n3629_o, n3626_o};
  /* T80_MCode.vhd:177:25  */
  always @*
    case (n3651_o)
      8'b10000000: n3653_o = n3648_o;
      8'b01000000: n3653_o = n3645_o;
      8'b00100000: n3653_o = n3641_o;
      8'b00010000: n3653_o = n3638_o;
      8'b00001000: n3653_o = n3634_o;
      8'b00000100: n3653_o = n3631_o;
      8'b00000010: n3653_o = n3627_o;
      8'b00000001: n3653_o = n3624_o;
      default: n3653_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1150:41  */
  assign n3656_o = n3653_o ? 3'b101 : 3'b011;
  /* T80_MCode.vhd:1150:41  */
  assign n3658_o = n3653_o ? 3'b100 : n2179_o;
  /* T80_MCode.vhd:1150:41  */
  assign n3661_o = n3653_o ? 4'b1111 : 4'b0000;
  /* T80_MCode.vhd:1150:41  */
  assign n3664_o = n3653_o ? 4'b1101 : 4'b0000;
  /* T80_MCode.vhd:1150:41  */
  assign n3667_o = n3653_o ? 3'b101 : 3'b111;
  /* T80_MCode.vhd:1147:33  */
  assign n3669_o = n3614_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1158:33  */
  assign n3671_o = n3614_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1163:33  */
  assign n3673_o = n3614_o == 31'b0000000000000000000000000000101;
  assign n3674_o = {n3673_o, n3671_o, n3669_o, n3616_o};
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3676_o = 3'b101;
      4'b0100: n3676_o = 3'b101;
      4'b0010: n3676_o = n3656_o;
      4'b0001: n3676_o = 3'b101;
      default: n3676_o = 3'b101;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3678_o = n2179_o;
      4'b0100: n3678_o = n2179_o;
      4'b0010: n3678_o = n3658_o;
      4'b0001: n3678_o = n2179_o;
      default: n3678_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3682_o = 1'b0;
      4'b0100: n3682_o = 1'b0;
      4'b0010: n3682_o = 1'b1;
      4'b0001: n3682_o = 1'b1;
      default: n3682_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3685_o = 4'b0000;
      4'b0100: n3685_o = 4'b1111;
      4'b0010: n3685_o = n3661_o;
      4'b0001: n3685_o = 4'b0000;
      default: n3685_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3688_o = 4'b0000;
      4'b0100: n3688_o = 4'b1100;
      4'b0010: n3688_o = n3664_o;
      4'b0001: n3688_o = 4'b0000;
      default: n3688_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3691_o = 3'b111;
      4'b0100: n3691_o = 3'b101;
      4'b0010: n3691_o = n3667_o;
      4'b0001: n3691_o = 3'b111;
      default: n3691_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3694_o = 1'b1;
      4'b0100: n3694_o = 1'b0;
      4'b0010: n3694_o = 1'b0;
      4'b0001: n3694_o = 1'b0;
      default: n3694_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3697_o = 1'b0;
      4'b0100: n3697_o = 1'b0;
      4'b0010: n3697_o = 1'b0;
      4'b0001: n3697_o = 1'b1;
      default: n3697_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3700_o = 1'b0;
      4'b0100: n3700_o = 1'b0;
      4'b0010: n3700_o = 1'b1;
      4'b0001: n3700_o = 1'b0;
      default: n3700_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3704_o = 1'b1;
      4'b0100: n3704_o = 1'b1;
      4'b0010: n3704_o = 1'b0;
      4'b0001: n3704_o = 1'b0;
      default: n3704_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1139:17  */
  assign n3706_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1139:32  */
  assign n3708_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1139:32  */
  assign n3709_o = n3706_o | n3708_o;
  /* T80_MCode.vhd:1139:43  */
  assign n3711_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1139:43  */
  assign n3712_o = n3709_o | n3711_o;
  /* T80_MCode.vhd:1139:54  */
  assign n3714_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1139:54  */
  assign n3715_o = n3712_o | n3714_o;
  /* T80_MCode.vhd:1139:65  */
  assign n3717_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1139:65  */
  assign n3718_o = n3715_o | n3717_o;
  /* T80_MCode.vhd:1139:76  */
  assign n3720_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1139:76  */
  assign n3721_o = n3718_o | n3720_o;
  /* T80_MCode.vhd:1139:87  */
  assign n3723_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1139:87  */
  assign n3724_o = n3721_o | n3723_o;
  /* T80_MCode.vhd:1139:98  */
  assign n3726_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1139:98  */
  assign n3727_o = n3724_o | n3726_o;
  /* T80_MCode.vhd:1172:30  */
  assign n3728_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1173:25  */
  assign n3730_o = n3728_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1176:25  */
  assign n3732_o = n3728_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1180:25  */
  assign n3734_o = n3728_o == 31'b0000000000000000000000000000011;
  assign n3735_o = {n3734_o, n3732_o, n3730_o};
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3735_o)
      3'b100: n3739_o = 4'b0111;
      3'b010: n3739_o = 4'b0111;
      3'b001: n3739_o = 4'b0000;
      default: n3739_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3735_o)
      3'b100: n3743_o = 3'b111;
      3'b010: n3743_o = 3'b101;
      3'b001: n3743_o = 3'b101;
      default: n3743_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3735_o)
      3'b100: n3746_o = 1'b1;
      3'b010: n3746_o = 1'b0;
      3'b001: n3746_o = 1'b0;
      default: n3746_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3735_o)
      3'b100: n3749_o = 1'b0;
      3'b010: n3749_o = 1'b1;
      3'b001: n3749_o = 1'b0;
      default: n3749_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1169:17  */
  assign n3751_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1256:38  */
  assign n3753_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1258:73  */
  assign n3755_o = ir[5:3];
  /* T80_MCode.vhd:178:47  */
  assign n3760_o = f[6];
  /* T80_MCode.vhd:178:56  */
  assign n3761_o = ~n3760_o;
  /* T80_MCode.vhd:178:25  */
  assign n3763_o = n3755_o == 3'b000;
  /* T80_MCode.vhd:179:47  */
  assign n3764_o = f[6];
  /* T80_MCode.vhd:179:25  */
  assign n3766_o = n3755_o == 3'b001;
  /* T80_MCode.vhd:180:47  */
  assign n3767_o = f[0];
  /* T80_MCode.vhd:180:56  */
  assign n3768_o = ~n3767_o;
  /* T80_MCode.vhd:180:25  */
  assign n3770_o = n3755_o == 3'b010;
  /* T80_MCode.vhd:181:47  */
  assign n3771_o = f[0];
  /* T80_MCode.vhd:181:25  */
  assign n3773_o = n3755_o == 3'b011;
  /* T80_MCode.vhd:182:47  */
  assign n3774_o = f[2];
  /* T80_MCode.vhd:182:56  */
  assign n3775_o = ~n3774_o;
  /* T80_MCode.vhd:182:25  */
  assign n3777_o = n3755_o == 3'b100;
  /* T80_MCode.vhd:183:47  */
  assign n3778_o = f[2];
  /* T80_MCode.vhd:183:25  */
  assign n3780_o = n3755_o == 3'b101;
  /* T80_MCode.vhd:184:47  */
  assign n3781_o = f[7];
  /* T80_MCode.vhd:184:56  */
  assign n3782_o = ~n3781_o;
  /* T80_MCode.vhd:184:25  */
  assign n3784_o = n3755_o == 3'b110;
  /* T80_MCode.vhd:185:47  */
  assign n3785_o = f[7];
  /* T80_MCode.vhd:185:25  */
  assign n3787_o = n3755_o == 3'b111;
  assign n3788_o = {n3787_o, n3784_o, n3780_o, n3777_o, n3773_o, n3770_o, n3766_o, n3763_o};
  /* T80_MCode.vhd:177:25  */
  always @*
    case (n3788_o)
      8'b10000000: n3790_o = n3785_o;
      8'b01000000: n3790_o = n3782_o;
      8'b00100000: n3790_o = n3778_o;
      8'b00010000: n3790_o = n3775_o;
      8'b00001000: n3790_o = n3771_o;
      8'b00000100: n3790_o = n3768_o;
      8'b00000010: n3790_o = n3764_o;
      8'b00000001: n3790_o = n3761_o;
      default: n3790_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1258:41  */
  assign n3793_o = n3790_o ? 3'b011 : 3'b001;
  /* T80_MCode.vhd:1258:41  */
  assign n3796_o = n3790_o ? 3'b101 : 3'b111;
  /* T80_MCode.vhd:1257:33  */
  assign n3798_o = n3753_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1264:33  */
  assign n3800_o = n3753_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1268:33  */
  assign n3802_o = n3753_o == 31'b0000000000000000000000000000011;
  assign n3803_o = {n3802_o, n3800_o, n3798_o};
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3805_o = 3'b011;
      3'b010: n3805_o = 3'b011;
      3'b001: n3805_o = n3793_o;
      default: n3805_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3808_o = n2179_o;
      3'b010: n3808_o = n2179_o;
      3'b001: n3808_o = 3'b101;
      default: n3808_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3812_o = 4'b0111;
      3'b010: n3812_o = 4'b0111;
      3'b001: n3812_o = 4'b0000;
      default: n3812_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3815_o = 3'b111;
      3'b010: n3815_o = 3'b101;
      3'b001: n3815_o = n3796_o;
      default: n3815_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3818_o = 1'b1;
      3'b010: n3818_o = 1'b0;
      3'b001: n3818_o = 1'b0;
      default: n3818_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3821_o = 1'b0;
      3'b010: n3821_o = 1'b1;
      3'b001: n3821_o = 1'b0;
      default: n3821_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1185:17  */
  assign n3823_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1185:32  */
  assign n3825_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1185:32  */
  assign n3826_o = n3823_o | n3825_o;
  /* T80_MCode.vhd:1185:43  */
  assign n3828_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1185:43  */
  assign n3829_o = n3826_o | n3828_o;
  /* T80_MCode.vhd:1185:54  */
  assign n3831_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1185:54  */
  assign n3832_o = n3829_o | n3831_o;
  /* T80_MCode.vhd:1185:65  */
  assign n3834_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1185:65  */
  assign n3835_o = n3832_o | n3834_o;
  /* T80_MCode.vhd:1185:76  */
  assign n3837_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1185:76  */
  assign n3838_o = n3835_o | n3837_o;
  /* T80_MCode.vhd:1185:87  */
  assign n3840_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1185:87  */
  assign n3841_o = n3838_o | n3840_o;
  /* T80_MCode.vhd:1185:98  */
  assign n3843_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1185:98  */
  assign n3844_o = n3841_o | n3843_o;
  /* T80_MCode.vhd:1277:30  */
  assign n3845_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1278:25  */
  assign n3847_o = n3845_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1283:25  */
  assign n3849_o = n3845_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1288:25  */
  assign n3851_o = n3845_o == 31'b0000000000000000000000000000011;
  assign n3852_o = {n3851_o, n3849_o, n3847_o};
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3854_o = n2179_o;
      3'b010: n3854_o = n2179_o;
      3'b001: n3854_o = 3'b101;
      default: n3854_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3858_o = 4'b0000;
      3'b010: n3858_o = 4'b1111;
      3'b001: n3858_o = 4'b1111;
      default: n3858_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3862_o = 4'b0000;
      3'b010: n3862_o = 4'b1100;
      3'b001: n3862_o = 4'b1101;
      default: n3862_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3866_o = 3'b111;
      3'b010: n3866_o = 3'b101;
      3'b001: n3866_o = 3'b101;
      default: n3866_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3869_o = 1'b1;
      3'b010: n3869_o = 1'b0;
      3'b001: n3869_o = 1'b0;
      default: n3869_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3873_o = 1'b1;
      3'b010: n3873_o = 1'b1;
      3'b001: n3873_o = 1'b0;
      default: n3873_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1274:17  */
  assign n3875_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1274:32  */
  assign n3877_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1274:32  */
  assign n3878_o = n3875_o | n3877_o;
  /* T80_MCode.vhd:1274:43  */
  assign n3880_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1274:43  */
  assign n3881_o = n3878_o | n3880_o;
  /* T80_MCode.vhd:1274:54  */
  assign n3883_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1274:54  */
  assign n3884_o = n3881_o | n3883_o;
  /* T80_MCode.vhd:1274:65  */
  assign n3886_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1274:65  */
  assign n3887_o = n3884_o | n3886_o;
  /* T80_MCode.vhd:1274:76  */
  assign n3889_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1274:76  */
  assign n3890_o = n3887_o | n3889_o;
  /* T80_MCode.vhd:1274:87  */
  assign n3892_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1274:87  */
  assign n3893_o = n3890_o | n3892_o;
  /* T80_MCode.vhd:1274:98  */
  assign n3895_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1274:98  */
  assign n3896_o = n3893_o | n3895_o;
  /* T80_MCode.vhd:1299:38  */
  assign n3897_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1300:33  */
  assign n3899_o = n3897_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1303:33  */
  assign n3901_o = n3897_o == 31'b0000000000000000000000000000011;
  assign n3902_o = {n3901_o, n3899_o};
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n3902_o)
      2'b10: n3905_o = 1'b0;
      2'b01: n3905_o = 1'b1;
      default: n3905_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n3902_o)
      2'b10: n3908_o = 1'b1;
      2'b01: n3908_o = 1'b0;
      default: n3908_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n3902_o)
      2'b10: n3911_o = 3'b111;
      2'b01: n3911_o = 3'b100;
      default: n3911_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n3902_o)
      2'b10: n3914_o = 1'b1;
      2'b01: n3914_o = 1'b0;
      default: n3914_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1295:17  */
  assign n3916_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1313:38  */
  assign n3917_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1314:33  */
  assign n3919_o = n3917_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1318:33  */
  assign n3921_o = n3917_o == 31'b0000000000000000000000000000011;
  assign n3922_o = {n3921_o, n3919_o};
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n3922_o)
      2'b10: n3925_o = 1'b0;
      2'b01: n3925_o = 1'b1;
      default: n3925_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n3922_o)
      2'b10: n3928_o = 4'b0000;
      2'b01: n3928_o = 4'b0111;
      default: n3928_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n3922_o)
      2'b10: n3931_o = 3'b111;
      2'b01: n3931_o = 3'b100;
      default: n3931_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n3922_o)
      2'b10: n3934_o = 1'b1;
      2'b01: n3934_o = 1'b0;
      default: n3934_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n3922_o)
      2'b10: n3937_o = 1'b1;
      2'b01: n3937_o = 1'b0;
      default: n3937_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1309:17  */
  assign n3939_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1331:17  */
  assign n3941_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1336:17  */
  assign n3943_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1341:17  */
  assign n3945_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1341:32  */
  assign n3947_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1341:32  */
  assign n3948_o = n3945_o | n3947_o;
  assign n3949_o = {n3948_o, n3943_o, n3941_o, n3939_o, n3916_o, n3896_o, n3844_o, n3751_o, n3727_o, n3611_o, n3568_o, n3566_o, n3564_o, n3562_o, n3560_o, n3558_o, n3556_o, n3554_o, n3472_o, n3451_o, n3439_o, n3427_o, n3415_o, n3326_o, n3324_o, n3322_o, n3320_o, n3221_o, n3219_o, n3217_o, n3215_o, n3212_o, n3177_o, n3157_o, n3122_o, n3102_o, n3063_o, n3020_o, n2852_o, n2803_o, n2801_o, n2799_o, n2797_o, n2744_o, n2695_o, n2693_o, n2656_o, n2619_o, n2572_o, n2543_o, n2523_o, n2503_o, n2480_o, n2466_o, n2452_o, n2430_o, n2393_o, n2359_o, n2328_o};
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b01000000000000000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00100000000000000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00010000000000000000000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00001000000000000000000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000100000000000000000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000010000000000000000000000000000000000000000000000000000: n3980_o = n3805_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000000100000000000000000000000000000000000000000000000000: n3980_o = n3676_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n3980_o = 3'b101;
      59'b00000000001000000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000100000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000010000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000001000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000100000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000010000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000001000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000100000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000000000000000010000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000000000000000001000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000100000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000010000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000001000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000000000000000000000100000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000010000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000001000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000100000000000000000000000000000000: n3980_o = n3307_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000001000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000100000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000010000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000001000000000000000000000000000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000100000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000010000000000000000000000000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000001000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000100000000000000000000000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000010000000000000000000000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000001000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000000100000000000000000000: n3980_o = 3'b101;
      59'b00000000000000000000000000000000000000010000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000000001000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000000000100000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000000000010000000000000000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000000000000001000000000000000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000000000000000100000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000000000000010000000000000: n3980_o = 3'b101;
      59'b00000000000000000000000000000000000000000000001000000000000: n3980_o = 3'b101;
      59'b00000000000000000000000000000000000000000000000100000000000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000000000000000000010000000000: n3980_o = 3'b100;
      59'b00000000000000000000000000000000000000000000000001000000000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000100000000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000010000000: n3980_o = 3'b100;
      59'b00000000000000000000000000000000000000000000000000001000000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000100000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000010000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000000000000000000000000001000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000100: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000010: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000001: n3980_o = 3'b001;
      default: n3980_o = 3'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b01000000000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00100000000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00010000000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n3985_o = n3854_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n3985_o = n3808_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n3985_o = n3678_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n3985_o = n3580_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000010000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000100000000000000000000000000000000000000: n3985_o = 3'b110;
      59'b00000000000000000000010000000000000000000000000000000000000: n3985_o = 3'b110;
      59'b00000000000000000000001000000000000000000000000000000000000: n3985_o = n3374_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000010000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000001000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000100000000000000000000000000000000: n3985_o = n3308_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000001000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000100000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000010000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000001000000000000000000000000000: n3985_o = n3187_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000010000000000000000000000000: n3985_o = n3132_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000100000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n3985_o = n2818_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000010000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n3985_o = n2719_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n3985_o = 3'b110;
      59'b00000000000000000000000000000000000000000000010000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n3985_o = n2179_o;
      default: n3985_o = 3'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n3988_o = n3925_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n3988_o = n3905_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n3988_o = n3682_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n3988_o = n3584_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n3988_o = n3523_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n3988_o = n3461_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n3988_o = n3310_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n3988_o = n3069_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n3988_o = n2670_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n3988_o = n2635_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n3988_o = n2600_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n3988_o = n2555_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n3988_o = n2492_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n3988_o = n2440_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n3988_o = n2334_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n3988_o = 1'b0;
      default: n3988_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n3991_o = n2673_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n3991_o = n2638_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n3991_o = 1'b0;
      default: n3991_o = 1'bX;
    endcase
  assign n3992_o = n2723_o[1:0];
  assign n3993_o = n2774_o[1:0];
  assign n3994_o = n2822_o[1:0];
  assign n3995_o = n3311_o[1:0];
  assign n3996_o = n3588_o[1:0];
  assign n3997_o = n3685_o[1:0];
  assign n3998_o = n3739_o[1:0];
  assign n3999_o = n3812_o[1:0];
  assign n4000_o = n3858_o[1:0];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4003_o = n4000_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4003_o = n3999_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4003_o = n3998_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4003_o = n3997_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4003_o = n3996_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4003_o = n2174_o;
      59'b00000000000000000000010000000000000000000000000000000000000: n4003_o = n2174_o;
      59'b00000000000000000000001000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000100000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4003_o = n3995_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4003_o = n3994_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4003_o = n3993_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4003_o = n3992_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000001000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000100000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000010000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4003_o = 2'b00;
      default: n4003_o = 2'bX;
    endcase
  assign n4004_o = n2723_o[3:2];
  assign n4005_o = n2774_o[3:2];
  assign n4006_o = n2822_o[3:2];
  assign n4007_o = n3311_o[3:2];
  assign n4008_o = n3588_o[3:2];
  assign n4009_o = n3685_o[3:2];
  assign n4010_o = n3739_o[3:2];
  assign n4011_o = n3812_o[3:2];
  assign n4012_o = n3858_o[3:2];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4015_o = n4012_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4015_o = n4011_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4015_o = n4010_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4015_o = n4009_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4015_o = n4008_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4015_o = 2'b11;
      59'b00000000000000000000010000000000000000000000000000000000000: n4015_o = 2'b01;
      59'b00000000000000000000001000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000100000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4015_o = n4007_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4015_o = n4006_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4015_o = n4005_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4015_o = n4004_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000001000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000100000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000010000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4015_o = 2'b00;
      default: n4015_o = 2'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4024_o = 1'b1;
      59'b00000000000000000000100000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4024_o = n3378_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4024_o = 1'b1;
      59'b00000000000000000000000000000001000000000000000000000000000: n4024_o = n3190_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4024_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4024_o = n3135_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4024_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4024_o = n3072_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4024_o = n3030_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4024_o = 1'b1;
      59'b00000000000000000000000000000000000000100000000000000000000: n4024_o = n2826_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4024_o = n2778_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4024_o = n2642_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4024_o = n2604_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4024_o = n2368_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4024_o = n2337_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4024_o = 1'b1;
      default: n4024_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4027_o = n3908_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4027_o = n2495_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4027_o = n2475_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4027_o = n2461_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4027_o = 1'b0;
      default: n4027_o = 1'bX;
    endcase
  assign n4028_o = n2830_o[2:0];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b01000000000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00100000000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00010000000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00001000000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000100000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000010000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000001000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000100000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000010000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000001000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000100000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000010000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000001000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000100000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000010000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000001000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000100000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000010000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000001000000000000000000000000000000000000000: n4031_o = 3'b111;
      59'b00000000000000000000100000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000010000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000001000000000000000000000000000000000000: n4031_o = n3380_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000010000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000001000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000100000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000010000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000001000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000100000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000010000000000000000000000000000: n4031_o = 3'b111;
      59'b00000000000000000000000000000001000000000000000000000000000: n4031_o = n3192_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4031_o = n2172_o;
      59'b00000000000000000000000000000000010000000000000000000000000: n4031_o = n3137_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4031_o = n2172_o;
      59'b00000000000000000000000000000000000100000000000000000000000: n4031_o = n3074_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4031_o = n3032_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4031_o = 3'b111;
      59'b00000000000000000000000000000000000000100000000000000000000: n4031_o = n4028_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000001000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000100000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000010000000000000000: n4031_o = n2780_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000100000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000010000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000001000000000000: n4031_o = n2644_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4031_o = n2606_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000001000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000100000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000010000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000001000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000100000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000010000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000001000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000000100: n4031_o = n2370_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4031_o = n2339_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4031_o = n2172_o;
      default: n4031_o = 3'bX;
    endcase
  assign n4032_o = n2830_o[3];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4035_o = n4032_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4035_o = n2782_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4035_o = n2608_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4035_o = 1'b0;
      default: n4035_o = 1'bX;
    endcase
  assign n4036_o = n2173_o[0];
  assign n4037_o = n2402_o[0];
  assign n4038_o = n2442_o[0];
  assign n4039_o = n2512_o[0];
  assign n4040_o = n2532_o[0];
  assign n4041_o = n2558_o[0];
  assign n4042_o = n2677_o[0];
  assign n4043_o = n2725_o[0];
  assign n4044_o = n2834_o[0];
  assign n4045_o = n2173_o[0];
  assign n4046_o = n3034_o[0];
  assign n4047_o = n3076_o[0];
  assign n4049_o = n3140_o[0];
  assign n4051_o = n3195_o[0];
  assign n4052_o = n3312_o[0];
  assign n4053_o = n3592_o[0];
  assign n4054_o = n3688_o[0];
  assign n4055_o = n3862_o[0];
  assign n4056_o = n3928_o[0];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4059_o = n4056_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4059_o = n4055_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4059_o = n4054_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4059_o = n4053_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4059_o = n3382_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4059_o = n4052_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4059_o = n4051_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4059_o = n4049_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4059_o = n4047_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4059_o = n4046_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4059_o = n4045_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4059_o = n4044_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4059_o = n4043_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4059_o = n4042_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4059_o = n4041_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4059_o = n4040_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4059_o = n4039_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4059_o = n4038_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4059_o = n4037_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4059_o = n4036_o;
      default: n4059_o = 1'bX;
    endcase
  assign n4060_o = n2173_o[2:1];
  assign n4061_o = n2402_o[2:1];
  assign n4062_o = n2442_o[2:1];
  assign n4063_o = n2512_o[2:1];
  assign n4064_o = n2532_o[2:1];
  assign n4065_o = n2558_o[2:1];
  assign n4066_o = n2677_o[2:1];
  assign n4067_o = n2725_o[2:1];
  assign n4068_o = n2834_o[2:1];
  assign n4069_o = n2173_o[2:1];
  assign n4070_o = n3034_o[2:1];
  assign n4071_o = n3076_o[2:1];
  assign n4073_o = n3140_o[2:1];
  assign n4075_o = n3195_o[2:1];
  assign n4076_o = n3312_o[2:1];
  assign n4077_o = n3592_o[2:1];
  assign n4078_o = n3688_o[2:1];
  assign n4079_o = n3862_o[2:1];
  assign n4080_o = n3928_o[2:1];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4083_o = n4080_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4083_o = n4079_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000001000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000100000000000000000000000000000000000000000000000000: n4083_o = n4078_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4083_o = n4077_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000010000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000001000000000000000000000000000000000000: n4083_o = n3384_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4083_o = n4076_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4083_o = n4075_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4083_o = 2'b01;
      59'b00000000000000000000000000000000010000000000000000000000000: n4083_o = n4073_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4083_o = 2'b01;
      59'b00000000000000000000000000000000000100000000000000000000000: n4083_o = n4071_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4083_o = n4070_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4083_o = n4069_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4083_o = n4068_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000001000000000000000: n4083_o = n4067_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4083_o = n4066_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4083_o = n4065_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4083_o = n4064_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4083_o = n4063_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4083_o = n4062_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4083_o = n4061_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4083_o = n4060_o;
      default: n4083_o = 2'bX;
    endcase
  assign n4084_o = n2512_o[3];
  assign n4085_o = n2532_o[3];
  assign n4086_o = n2558_o[3];
  assign n4087_o = n2677_o[3];
  assign n4088_o = n2725_o[3];
  assign n4089_o = n2834_o[3];
  assign n4091_o = n3140_o[3];
  assign n4093_o = n3195_o[3];
  assign n4094_o = n3312_o[3];
  assign n4095_o = n3592_o[3];
  assign n4096_o = n3688_o[3];
  assign n4097_o = n3862_o[3];
  assign n4098_o = n3928_o[3];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4101_o = n4098_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4101_o = n4097_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4101_o = n4096_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4101_o = n4095_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4101_o = n3386_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4101_o = n4094_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4101_o = n4093_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4101_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4101_o = n4091_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4101_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4101_o = n4089_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4101_o = n4088_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4101_o = n4087_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4101_o = n4086_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4101_o = n4085_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4101_o = n4084_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4101_o = n2444_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4101_o = n2404_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4101_o = 1'b0;
      default: n4101_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b01000000000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00100000000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00010000000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000010000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4107_o = 4'b1000;
      59'b00000000000000000000100000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000010000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000001000000000000000000000000000000000000: n4107_o = n3389_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000010000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000001000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000100000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000001000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000100000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000010000000000000000000000000000: n4107_o = 4'b1100;
      59'b00000000000000000000000000000001000000000000000000000000000: n4107_o = n3197_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4107_o = 4'b0010;
      59'b00000000000000000000000000000000010000000000000000000000000: n4107_o = n3142_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4107_o = 4'b0000;
      59'b00000000000000000000000000000000000100000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000010000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000010000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4107_o = n2182_o;
      default: n4107_o = 4'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4115_o = 1'b1;
      59'b00000000000000000000100000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4115_o = n3393_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4115_o = 1'b1;
      59'b00000000000000000000000000000001000000000000000000000000000: n4115_o = n3200_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4115_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4115_o = n3145_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4115_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4115_o = n3079_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4115_o = n3037_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4115_o = 1'b1;
      59'b00000000000000000000000000000000000000100000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4115_o = 1'b0;
      default: n4115_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4120_o = n3203_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4120_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4120_o = n3148_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4120_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4120_o = 1'b0;
      default: n4120_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4123_o = n3397_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4123_o = 1'b0;
      default: n4123_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b01000000000000000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00100000000000000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00010000000000000000000000000000000000000000000000000000000: n4126_o = n3931_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4126_o = n3911_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4126_o = n3866_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4126_o = n3815_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4126_o = n3743_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4126_o = n3691_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4126_o = n3596_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000100000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000010000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000001000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000100000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000010000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000001000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000100000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000010000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000001000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000100000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000010000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000001000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000100000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000010000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000001000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000100000000000000000000000000000000: n4126_o = n3313_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000001000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000100000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000010000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000001000000000000000000000000000: n4126_o = n3207_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000010000000000000000000000000: n4126_o = n3152_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000100000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000010000000000000000000000: n4126_o = n3040_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000100000000000000000000: n4126_o = n2840_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000001000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000000100000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000000010000000000000000: n4126_o = n2786_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4126_o = n2729_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000000000010000000000000: n4126_o = n2681_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4126_o = n2648_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000000000000010000000000: n4126_o = n2561_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4126_o = n2535_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4126_o = n2515_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4126_o = n2498_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4126_o = n2478_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4126_o = n2464_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4126_o = n2447_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4126_o = n2407_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4126_o = n2373_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000000000000000000000001: n4126_o = 3'b111;
      default: n4126_o = 3'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4129_o = n3934_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4129_o = n3914_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4129_o = 1'b0;
      default: n4129_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4132_o = n3818_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4132_o = n3746_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4132_o = n3525_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4132_o = n3464_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4132_o = n3315_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4132_o = 1'b0;
      default: n4132_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4136_o = 1'b1;
      59'b00000000000010000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4136_o = 1'b0;
      default: n4136_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4139_o = n3694_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4139_o = n3599_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4139_o = 1'b0;
      default: n4139_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4142_o = n3869_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4142_o = 1'b0;
      default: n4142_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4145_o = n3821_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4145_o = n3749_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4145_o = n3697_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4145_o = n3602_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4145_o = n3528_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4145_o = n3467_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4145_o = n3317_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4145_o = n2843_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4145_o = n2684_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4145_o = n2651_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4145_o = n2564_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4145_o = n2501_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4145_o = 1'b0;
      default: n4145_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4148_o = n3700_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4148_o = n3605_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4148_o = n3531_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4148_o = n3470_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4148_o = n2846_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4148_o = n2687_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4148_o = n2654_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4148_o = 1'b0;
      default: n4148_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4152_o = 1'b1;
      59'b00000000000000000000000000000000000000000000010000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4152_o = 1'b0;
      default: n4152_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4156_o = 1'b1;
      59'b00000000000000000000000000000000000000000010000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4156_o = 1'b0;
      default: n4156_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4160_o = 1'b1;
      default: n4160_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4164_o = 1'b1;
      59'b00000000000000000000000000000010000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4164_o = 1'b0;
      default: n4164_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4168_o = 1'b1;
      59'b00000000000000000000000000000100000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4168_o = 1'b0;
      default: n4168_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4172_o = 1'b1;
      59'b00000000000000000000000000001000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4172_o = 1'b0;
      default: n4172_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000010000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000001000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000100000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000010000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000001000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000010000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000001000000000000000000000000000000000000: n4175_o = n3400_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000010000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000010000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000001000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000100000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4175_o = n2567_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4175_o = n2538_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4175_o = n2518_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4175_o = 2'b00;
      default: n4175_o = 2'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4179_o = 1'b1;
      59'b00000000000000000000000001000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4179_o = 1'b0;
      default: n4179_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4183_o = 1'b1;
      59'b00000000000000000000000010000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4183_o = 1'b0;
      default: n4183_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4187_o = 1'b1;
      59'b00000000000000000000000000100000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4187_o = 1'b0;
      default: n4187_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4190_o = n3404_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4190_o = 1'b0;
      default: n4190_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4193_o = n3937_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4193_o = n3873_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4193_o = n3704_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4193_o = n3609_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4193_o = n3318_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4193_o = n3210_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4193_o = n3155_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4193_o = n2850_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4193_o = n2733_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4193_o = n2691_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4193_o = n2570_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4193_o = n2541_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4193_o = n2521_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4193_o = n2450_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4193_o = n2410_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4193_o = 1'b0;
      default: n4193_o = 1'bX;
    endcase
  /* T80_MCode.vhd:257:17  */
  assign n4195_o = iset == 2'b00;
  /* T80_MCode.vhd:1356:54  */
  assign n4196_o = ir[2:0];
  /* T80_MCode.vhd:1357:54  */
  assign n4197_o = ir[2:0];
  /* T80_MCode.vhd:1376:44  */
  assign n4199_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1377:51  */
  assign n4201_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1377:41  */
  assign n4204_o = n4201_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1377:41  */
  assign n4206_o = n4201_o ? 4'b1000 : n2182_o;
  /* T80_MCode.vhd:1377:41  */
  assign n4209_o = n4201_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1386:46  */
  assign n4210_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1387:41  */
  assign n4212_o = n4210_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1387:48  */
  assign n4214_o = n4210_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1387:48  */
  assign n4215_o = n4212_o | n4214_o;
  /* T80_MCode.vhd:1389:41  */
  assign n4217_o = n4210_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1395:41  */
  assign n4219_o = n4210_o == 31'b0000000000000000000000000000011;
  assign n4220_o = {n4219_o, n4217_o, n4215_o};
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4222_o = n2179_o;
      3'b010: n4222_o = 3'b100;
      3'b001: n4222_o = n2179_o;
      default: n4222_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4225_o = 1'b0;
      3'b010: n4225_o = 1'b1;
      3'b001: n4225_o = 1'b0;
      default: n4225_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4227_o = n2182_o;
      3'b010: n4227_o = 4'b1000;
      3'b001: n4227_o = n2182_o;
      default: n4227_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4230_o = 1'b0;
      3'b010: n4230_o = 1'b1;
      3'b001: n4230_o = 1'b0;
      default: n4230_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4234_o = 3'b111;
      3'b010: n4234_o = 3'b010;
      3'b001: n4234_o = 3'b010;
      default: n4234_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4237_o = 1'b1;
      3'b010: n4237_o = 1'b0;
      3'b001: n4237_o = 1'b0;
      default: n4237_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1376:33  */
  assign n4240_o = n4199_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1376:33  */
  assign n4241_o = n4199_o ? n2179_o : n4222_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4242_o = n4199_o ? n4204_o : n4225_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4243_o = n4199_o ? n4206_o : n4227_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4244_o = n4199_o ? n4209_o : n4230_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4246_o = n4199_o ? 3'b111 : n4234_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4248_o = n4199_o ? 1'b0 : n4237_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4251_o = n4199_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1360:25  */
  assign n4253_o = ir == 8'b00000000;
  /* T80_MCode.vhd:1360:40  */
  assign n4255_o = ir == 8'b00000001;
  /* T80_MCode.vhd:1360:40  */
  assign n4256_o = n4253_o | n4255_o;
  /* T80_MCode.vhd:1360:51  */
  assign n4258_o = ir == 8'b00000010;
  /* T80_MCode.vhd:1360:51  */
  assign n4259_o = n4256_o | n4258_o;
  /* T80_MCode.vhd:1360:62  */
  assign n4261_o = ir == 8'b00000011;
  /* T80_MCode.vhd:1360:62  */
  assign n4262_o = n4259_o | n4261_o;
  /* T80_MCode.vhd:1360:73  */
  assign n4264_o = ir == 8'b00000100;
  /* T80_MCode.vhd:1360:73  */
  assign n4265_o = n4262_o | n4264_o;
  /* T80_MCode.vhd:1360:84  */
  assign n4267_o = ir == 8'b00000101;
  /* T80_MCode.vhd:1360:84  */
  assign n4268_o = n4265_o | n4267_o;
  /* T80_MCode.vhd:1360:95  */
  assign n4270_o = ir == 8'b00000111;
  /* T80_MCode.vhd:1360:95  */
  assign n4271_o = n4268_o | n4270_o;
  /* T80_MCode.vhd:1361:33  */
  assign n4273_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1361:33  */
  assign n4274_o = n4271_o | n4273_o;
  /* T80_MCode.vhd:1361:44  */
  assign n4276_o = ir == 8'b00010001;
  /* T80_MCode.vhd:1361:44  */
  assign n4277_o = n4274_o | n4276_o;
  /* T80_MCode.vhd:1361:55  */
  assign n4279_o = ir == 8'b00010010;
  /* T80_MCode.vhd:1361:55  */
  assign n4280_o = n4277_o | n4279_o;
  /* T80_MCode.vhd:1361:66  */
  assign n4282_o = ir == 8'b00010011;
  /* T80_MCode.vhd:1361:66  */
  assign n4283_o = n4280_o | n4282_o;
  /* T80_MCode.vhd:1361:77  */
  assign n4285_o = ir == 8'b00010100;
  /* T80_MCode.vhd:1361:77  */
  assign n4286_o = n4283_o | n4285_o;
  /* T80_MCode.vhd:1361:88  */
  assign n4288_o = ir == 8'b00010101;
  /* T80_MCode.vhd:1361:88  */
  assign n4289_o = n4286_o | n4288_o;
  /* T80_MCode.vhd:1361:99  */
  assign n4291_o = ir == 8'b00010111;
  /* T80_MCode.vhd:1361:99  */
  assign n4292_o = n4289_o | n4291_o;
  /* T80_MCode.vhd:1362:33  */
  assign n4294_o = ir == 8'b00001000;
  /* T80_MCode.vhd:1362:33  */
  assign n4295_o = n4292_o | n4294_o;
  /* T80_MCode.vhd:1362:44  */
  assign n4297_o = ir == 8'b00001001;
  /* T80_MCode.vhd:1362:44  */
  assign n4298_o = n4295_o | n4297_o;
  /* T80_MCode.vhd:1362:55  */
  assign n4300_o = ir == 8'b00001010;
  /* T80_MCode.vhd:1362:55  */
  assign n4301_o = n4298_o | n4300_o;
  /* T80_MCode.vhd:1362:66  */
  assign n4303_o = ir == 8'b00001011;
  /* T80_MCode.vhd:1362:66  */
  assign n4304_o = n4301_o | n4303_o;
  /* T80_MCode.vhd:1362:77  */
  assign n4306_o = ir == 8'b00001100;
  /* T80_MCode.vhd:1362:77  */
  assign n4307_o = n4304_o | n4306_o;
  /* T80_MCode.vhd:1362:88  */
  assign n4309_o = ir == 8'b00001101;
  /* T80_MCode.vhd:1362:88  */
  assign n4310_o = n4307_o | n4309_o;
  /* T80_MCode.vhd:1362:99  */
  assign n4312_o = ir == 8'b00001111;
  /* T80_MCode.vhd:1362:99  */
  assign n4313_o = n4310_o | n4312_o;
  /* T80_MCode.vhd:1363:33  */
  assign n4315_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1363:33  */
  assign n4316_o = n4313_o | n4315_o;
  /* T80_MCode.vhd:1363:44  */
  assign n4318_o = ir == 8'b00011001;
  /* T80_MCode.vhd:1363:44  */
  assign n4319_o = n4316_o | n4318_o;
  /* T80_MCode.vhd:1363:55  */
  assign n4321_o = ir == 8'b00011010;
  /* T80_MCode.vhd:1363:55  */
  assign n4322_o = n4319_o | n4321_o;
  /* T80_MCode.vhd:1363:66  */
  assign n4324_o = ir == 8'b00011011;
  /* T80_MCode.vhd:1363:66  */
  assign n4325_o = n4322_o | n4324_o;
  /* T80_MCode.vhd:1363:77  */
  assign n4327_o = ir == 8'b00011100;
  /* T80_MCode.vhd:1363:77  */
  assign n4328_o = n4325_o | n4327_o;
  /* T80_MCode.vhd:1363:88  */
  assign n4330_o = ir == 8'b00011101;
  /* T80_MCode.vhd:1363:88  */
  assign n4331_o = n4328_o | n4330_o;
  /* T80_MCode.vhd:1363:99  */
  assign n4333_o = ir == 8'b00011111;
  /* T80_MCode.vhd:1363:99  */
  assign n4334_o = n4331_o | n4333_o;
  /* T80_MCode.vhd:1364:33  */
  assign n4336_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1364:33  */
  assign n4337_o = n4334_o | n4336_o;
  /* T80_MCode.vhd:1364:44  */
  assign n4339_o = ir == 8'b00100001;
  /* T80_MCode.vhd:1364:44  */
  assign n4340_o = n4337_o | n4339_o;
  /* T80_MCode.vhd:1364:55  */
  assign n4342_o = ir == 8'b00100010;
  /* T80_MCode.vhd:1364:55  */
  assign n4343_o = n4340_o | n4342_o;
  /* T80_MCode.vhd:1364:66  */
  assign n4345_o = ir == 8'b00100011;
  /* T80_MCode.vhd:1364:66  */
  assign n4346_o = n4343_o | n4345_o;
  /* T80_MCode.vhd:1364:77  */
  assign n4348_o = ir == 8'b00100100;
  /* T80_MCode.vhd:1364:77  */
  assign n4349_o = n4346_o | n4348_o;
  /* T80_MCode.vhd:1364:88  */
  assign n4351_o = ir == 8'b00100101;
  /* T80_MCode.vhd:1364:88  */
  assign n4352_o = n4349_o | n4351_o;
  /* T80_MCode.vhd:1364:99  */
  assign n4354_o = ir == 8'b00100111;
  /* T80_MCode.vhd:1364:99  */
  assign n4355_o = n4352_o | n4354_o;
  /* T80_MCode.vhd:1365:33  */
  assign n4357_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1365:33  */
  assign n4358_o = n4355_o | n4357_o;
  /* T80_MCode.vhd:1365:44  */
  assign n4360_o = ir == 8'b00101001;
  /* T80_MCode.vhd:1365:44  */
  assign n4361_o = n4358_o | n4360_o;
  /* T80_MCode.vhd:1365:55  */
  assign n4363_o = ir == 8'b00101010;
  /* T80_MCode.vhd:1365:55  */
  assign n4364_o = n4361_o | n4363_o;
  /* T80_MCode.vhd:1365:66  */
  assign n4366_o = ir == 8'b00101011;
  /* T80_MCode.vhd:1365:66  */
  assign n4367_o = n4364_o | n4366_o;
  /* T80_MCode.vhd:1365:77  */
  assign n4369_o = ir == 8'b00101100;
  /* T80_MCode.vhd:1365:77  */
  assign n4370_o = n4367_o | n4369_o;
  /* T80_MCode.vhd:1365:88  */
  assign n4372_o = ir == 8'b00101101;
  /* T80_MCode.vhd:1365:88  */
  assign n4373_o = n4370_o | n4372_o;
  /* T80_MCode.vhd:1365:99  */
  assign n4375_o = ir == 8'b00101111;
  /* T80_MCode.vhd:1365:99  */
  assign n4376_o = n4373_o | n4375_o;
  /* T80_MCode.vhd:1366:33  */
  assign n4378_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1366:33  */
  assign n4379_o = n4376_o | n4378_o;
  /* T80_MCode.vhd:1366:44  */
  assign n4381_o = ir == 8'b00110001;
  /* T80_MCode.vhd:1366:44  */
  assign n4382_o = n4379_o | n4381_o;
  /* T80_MCode.vhd:1366:55  */
  assign n4384_o = ir == 8'b00110010;
  /* T80_MCode.vhd:1366:55  */
  assign n4385_o = n4382_o | n4384_o;
  /* T80_MCode.vhd:1366:66  */
  assign n4387_o = ir == 8'b00110011;
  /* T80_MCode.vhd:1366:66  */
  assign n4388_o = n4385_o | n4387_o;
  /* T80_MCode.vhd:1366:77  */
  assign n4390_o = ir == 8'b00110100;
  /* T80_MCode.vhd:1366:77  */
  assign n4391_o = n4388_o | n4390_o;
  /* T80_MCode.vhd:1366:88  */
  assign n4393_o = ir == 8'b00110101;
  /* T80_MCode.vhd:1366:88  */
  assign n4394_o = n4391_o | n4393_o;
  /* T80_MCode.vhd:1366:99  */
  assign n4396_o = ir == 8'b00110111;
  /* T80_MCode.vhd:1366:99  */
  assign n4397_o = n4394_o | n4396_o;
  /* T80_MCode.vhd:1367:33  */
  assign n4399_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1367:33  */
  assign n4400_o = n4397_o | n4399_o;
  /* T80_MCode.vhd:1367:44  */
  assign n4402_o = ir == 8'b00111001;
  /* T80_MCode.vhd:1367:44  */
  assign n4403_o = n4400_o | n4402_o;
  /* T80_MCode.vhd:1367:55  */
  assign n4405_o = ir == 8'b00111010;
  /* T80_MCode.vhd:1367:55  */
  assign n4406_o = n4403_o | n4405_o;
  /* T80_MCode.vhd:1367:66  */
  assign n4408_o = ir == 8'b00111011;
  /* T80_MCode.vhd:1367:66  */
  assign n4409_o = n4406_o | n4408_o;
  /* T80_MCode.vhd:1367:77  */
  assign n4411_o = ir == 8'b00111100;
  /* T80_MCode.vhd:1367:77  */
  assign n4412_o = n4409_o | n4411_o;
  /* T80_MCode.vhd:1367:88  */
  assign n4414_o = ir == 8'b00111101;
  /* T80_MCode.vhd:1367:88  */
  assign n4415_o = n4412_o | n4414_o;
  /* T80_MCode.vhd:1367:99  */
  assign n4417_o = ir == 8'b00111111;
  /* T80_MCode.vhd:1367:99  */
  assign n4418_o = n4415_o | n4417_o;
  /* T80_MCode.vhd:1411:38  */
  assign n4419_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1412:33  */
  assign n4421_o = n4419_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1412:40  */
  assign n4423_o = n4419_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1412:40  */
  assign n4424_o = n4421_o | n4423_o;
  /* T80_MCode.vhd:1414:33  */
  assign n4426_o = n4419_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1420:33  */
  assign n4428_o = n4419_o == 31'b0000000000000000000000000000011;
  assign n4429_o = {n4428_o, n4426_o, n4424_o};
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4431_o = n2179_o;
      3'b010: n4431_o = 3'b100;
      3'b001: n4431_o = n2179_o;
      default: n4431_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4434_o = 1'b0;
      3'b010: n4434_o = 1'b1;
      3'b001: n4434_o = 1'b0;
      default: n4434_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4436_o = n2182_o;
      3'b010: n4436_o = 4'b1000;
      3'b001: n4436_o = n2182_o;
      default: n4436_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4439_o = 1'b0;
      3'b010: n4439_o = 1'b1;
      3'b001: n4439_o = 1'b0;
      default: n4439_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4443_o = 3'b111;
      3'b010: n4443_o = 3'b010;
      3'b001: n4443_o = 3'b010;
      default: n4443_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4446_o = 1'b1;
      3'b010: n4446_o = 1'b0;
      3'b001: n4446_o = 1'b0;
      default: n4446_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1401:25  */
  assign n4448_o = ir == 8'b00000110;
  /* T80_MCode.vhd:1401:40  */
  assign n4450_o = ir == 8'b00010110;
  /* T80_MCode.vhd:1401:40  */
  assign n4451_o = n4448_o | n4450_o;
  /* T80_MCode.vhd:1401:51  */
  assign n4453_o = ir == 8'b00001110;
  /* T80_MCode.vhd:1401:51  */
  assign n4454_o = n4451_o | n4453_o;
  /* T80_MCode.vhd:1401:62  */
  assign n4456_o = ir == 8'b00011110;
  /* T80_MCode.vhd:1401:62  */
  assign n4457_o = n4454_o | n4456_o;
  /* T80_MCode.vhd:1401:73  */
  assign n4459_o = ir == 8'b00101110;
  /* T80_MCode.vhd:1401:73  */
  assign n4460_o = n4457_o | n4459_o;
  /* T80_MCode.vhd:1401:84  */
  assign n4462_o = ir == 8'b00111110;
  /* T80_MCode.vhd:1401:84  */
  assign n4463_o = n4460_o | n4462_o;
  /* T80_MCode.vhd:1401:95  */
  assign n4465_o = ir == 8'b00100110;
  /* T80_MCode.vhd:1401:95  */
  assign n4466_o = n4463_o | n4465_o;
  /* T80_MCode.vhd:1401:106  */
  assign n4468_o = ir == 8'b00110110;
  /* T80_MCode.vhd:1401:106  */
  assign n4469_o = n4466_o | n4468_o;
  /* T80_MCode.vhd:1433:44  */
  assign n4471_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1434:51  */
  assign n4473_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1435:72  */
  assign n4474_o = ir[2:0];
  /* T80_MCode.vhd:1433:33  */
  assign n4475_o = n4498_o ? n4474_o : n4197_o;
  /* T80_MCode.vhd:1434:41  */
  assign n4477_o = n4473_o ? 4'b1001 : n2182_o;
  /* T80_MCode.vhd:1442:46  */
  assign n4478_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1443:41  */
  assign n4480_o = n4478_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1443:48  */
  assign n4482_o = n4478_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1443:48  */
  assign n4483_o = n4480_o | n4482_o;
  /* T80_MCode.vhd:1445:41  */
  assign n4485_o = n4478_o == 31'b0000000000000000000000000000010;
  assign n4486_o = {n4485_o, n4483_o};
  /* T80_MCode.vhd:1442:41  */
  always @*
    case (n4486_o)
      2'b10: n4488_o = 3'b100;
      2'b01: n4488_o = n2179_o;
      default: n4488_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1442:41  */
  always @*
    case (n4486_o)
      2'b10: n4490_o = 4'b1001;
      2'b01: n4490_o = n2182_o;
      default: n4490_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1442:41  */
  always @*
    case (n4486_o)
      2'b10: n4493_o = 3'b111;
      2'b01: n4493_o = 3'b010;
      default: n4493_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1433:33  */
  assign n4496_o = n4471_o ? 3'b001 : 3'b010;
  /* T80_MCode.vhd:1433:33  */
  assign n4497_o = n4471_o ? n2179_o : n4488_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4498_o = n4473_o & n4471_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4499_o = n4471_o ? n4477_o : n4490_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4501_o = n4471_o ? 3'b111 : n4493_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4504_o = n4471_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1424:25  */
  assign n4506_o = ir == 8'b01000000;
  /* T80_MCode.vhd:1424:40  */
  assign n4508_o = ir == 8'b01000001;
  /* T80_MCode.vhd:1424:40  */
  assign n4509_o = n4506_o | n4508_o;
  /* T80_MCode.vhd:1424:51  */
  assign n4511_o = ir == 8'b01000010;
  /* T80_MCode.vhd:1424:51  */
  assign n4512_o = n4509_o | n4511_o;
  /* T80_MCode.vhd:1424:62  */
  assign n4514_o = ir == 8'b01000011;
  /* T80_MCode.vhd:1424:62  */
  assign n4515_o = n4512_o | n4514_o;
  /* T80_MCode.vhd:1424:73  */
  assign n4517_o = ir == 8'b01000100;
  /* T80_MCode.vhd:1424:73  */
  assign n4518_o = n4515_o | n4517_o;
  /* T80_MCode.vhd:1424:84  */
  assign n4520_o = ir == 8'b01000101;
  /* T80_MCode.vhd:1424:84  */
  assign n4521_o = n4518_o | n4520_o;
  /* T80_MCode.vhd:1424:95  */
  assign n4523_o = ir == 8'b01000111;
  /* T80_MCode.vhd:1424:95  */
  assign n4524_o = n4521_o | n4523_o;
  /* T80_MCode.vhd:1425:33  */
  assign n4526_o = ir == 8'b01001000;
  /* T80_MCode.vhd:1425:33  */
  assign n4527_o = n4524_o | n4526_o;
  /* T80_MCode.vhd:1425:44  */
  assign n4529_o = ir == 8'b01001001;
  /* T80_MCode.vhd:1425:44  */
  assign n4530_o = n4527_o | n4529_o;
  /* T80_MCode.vhd:1425:55  */
  assign n4532_o = ir == 8'b01001010;
  /* T80_MCode.vhd:1425:55  */
  assign n4533_o = n4530_o | n4532_o;
  /* T80_MCode.vhd:1425:66  */
  assign n4535_o = ir == 8'b01001011;
  /* T80_MCode.vhd:1425:66  */
  assign n4536_o = n4533_o | n4535_o;
  /* T80_MCode.vhd:1425:77  */
  assign n4538_o = ir == 8'b01001100;
  /* T80_MCode.vhd:1425:77  */
  assign n4539_o = n4536_o | n4538_o;
  /* T80_MCode.vhd:1425:88  */
  assign n4541_o = ir == 8'b01001101;
  /* T80_MCode.vhd:1425:88  */
  assign n4542_o = n4539_o | n4541_o;
  /* T80_MCode.vhd:1425:99  */
  assign n4544_o = ir == 8'b01001111;
  /* T80_MCode.vhd:1425:99  */
  assign n4545_o = n4542_o | n4544_o;
  /* T80_MCode.vhd:1426:33  */
  assign n4547_o = ir == 8'b01010000;
  /* T80_MCode.vhd:1426:33  */
  assign n4548_o = n4545_o | n4547_o;
  /* T80_MCode.vhd:1426:44  */
  assign n4550_o = ir == 8'b01010001;
  /* T80_MCode.vhd:1426:44  */
  assign n4551_o = n4548_o | n4550_o;
  /* T80_MCode.vhd:1426:55  */
  assign n4553_o = ir == 8'b01010010;
  /* T80_MCode.vhd:1426:55  */
  assign n4554_o = n4551_o | n4553_o;
  /* T80_MCode.vhd:1426:66  */
  assign n4556_o = ir == 8'b01010011;
  /* T80_MCode.vhd:1426:66  */
  assign n4557_o = n4554_o | n4556_o;
  /* T80_MCode.vhd:1426:77  */
  assign n4559_o = ir == 8'b01010100;
  /* T80_MCode.vhd:1426:77  */
  assign n4560_o = n4557_o | n4559_o;
  /* T80_MCode.vhd:1426:88  */
  assign n4562_o = ir == 8'b01010101;
  /* T80_MCode.vhd:1426:88  */
  assign n4563_o = n4560_o | n4562_o;
  /* T80_MCode.vhd:1426:99  */
  assign n4565_o = ir == 8'b01010111;
  /* T80_MCode.vhd:1426:99  */
  assign n4566_o = n4563_o | n4565_o;
  /* T80_MCode.vhd:1427:33  */
  assign n4568_o = ir == 8'b01011000;
  /* T80_MCode.vhd:1427:33  */
  assign n4569_o = n4566_o | n4568_o;
  /* T80_MCode.vhd:1427:44  */
  assign n4571_o = ir == 8'b01011001;
  /* T80_MCode.vhd:1427:44  */
  assign n4572_o = n4569_o | n4571_o;
  /* T80_MCode.vhd:1427:55  */
  assign n4574_o = ir == 8'b01011010;
  /* T80_MCode.vhd:1427:55  */
  assign n4575_o = n4572_o | n4574_o;
  /* T80_MCode.vhd:1427:66  */
  assign n4577_o = ir == 8'b01011011;
  /* T80_MCode.vhd:1427:66  */
  assign n4578_o = n4575_o | n4577_o;
  /* T80_MCode.vhd:1427:77  */
  assign n4580_o = ir == 8'b01011100;
  /* T80_MCode.vhd:1427:77  */
  assign n4581_o = n4578_o | n4580_o;
  /* T80_MCode.vhd:1427:88  */
  assign n4583_o = ir == 8'b01011101;
  /* T80_MCode.vhd:1427:88  */
  assign n4584_o = n4581_o | n4583_o;
  /* T80_MCode.vhd:1427:99  */
  assign n4586_o = ir == 8'b01011111;
  /* T80_MCode.vhd:1427:99  */
  assign n4587_o = n4584_o | n4586_o;
  /* T80_MCode.vhd:1428:33  */
  assign n4589_o = ir == 8'b01100000;
  /* T80_MCode.vhd:1428:33  */
  assign n4590_o = n4587_o | n4589_o;
  /* T80_MCode.vhd:1428:44  */
  assign n4592_o = ir == 8'b01100001;
  /* T80_MCode.vhd:1428:44  */
  assign n4593_o = n4590_o | n4592_o;
  /* T80_MCode.vhd:1428:55  */
  assign n4595_o = ir == 8'b01100010;
  /* T80_MCode.vhd:1428:55  */
  assign n4596_o = n4593_o | n4595_o;
  /* T80_MCode.vhd:1428:66  */
  assign n4598_o = ir == 8'b01100011;
  /* T80_MCode.vhd:1428:66  */
  assign n4599_o = n4596_o | n4598_o;
  /* T80_MCode.vhd:1428:77  */
  assign n4601_o = ir == 8'b01100100;
  /* T80_MCode.vhd:1428:77  */
  assign n4602_o = n4599_o | n4601_o;
  /* T80_MCode.vhd:1428:88  */
  assign n4604_o = ir == 8'b01100101;
  /* T80_MCode.vhd:1428:88  */
  assign n4605_o = n4602_o | n4604_o;
  /* T80_MCode.vhd:1428:99  */
  assign n4607_o = ir == 8'b01100111;
  /* T80_MCode.vhd:1428:99  */
  assign n4608_o = n4605_o | n4607_o;
  /* T80_MCode.vhd:1429:33  */
  assign n4610_o = ir == 8'b01101000;
  /* T80_MCode.vhd:1429:33  */
  assign n4611_o = n4608_o | n4610_o;
  /* T80_MCode.vhd:1429:44  */
  assign n4613_o = ir == 8'b01101001;
  /* T80_MCode.vhd:1429:44  */
  assign n4614_o = n4611_o | n4613_o;
  /* T80_MCode.vhd:1429:55  */
  assign n4616_o = ir == 8'b01101010;
  /* T80_MCode.vhd:1429:55  */
  assign n4617_o = n4614_o | n4616_o;
  /* T80_MCode.vhd:1429:66  */
  assign n4619_o = ir == 8'b01101011;
  /* T80_MCode.vhd:1429:66  */
  assign n4620_o = n4617_o | n4619_o;
  /* T80_MCode.vhd:1429:77  */
  assign n4622_o = ir == 8'b01101100;
  /* T80_MCode.vhd:1429:77  */
  assign n4623_o = n4620_o | n4622_o;
  /* T80_MCode.vhd:1429:88  */
  assign n4625_o = ir == 8'b01101101;
  /* T80_MCode.vhd:1429:88  */
  assign n4626_o = n4623_o | n4625_o;
  /* T80_MCode.vhd:1429:99  */
  assign n4628_o = ir == 8'b01101111;
  /* T80_MCode.vhd:1429:99  */
  assign n4629_o = n4626_o | n4628_o;
  /* T80_MCode.vhd:1430:33  */
  assign n4631_o = ir == 8'b01110000;
  /* T80_MCode.vhd:1430:33  */
  assign n4632_o = n4629_o | n4631_o;
  /* T80_MCode.vhd:1430:44  */
  assign n4634_o = ir == 8'b01110001;
  /* T80_MCode.vhd:1430:44  */
  assign n4635_o = n4632_o | n4634_o;
  /* T80_MCode.vhd:1430:55  */
  assign n4637_o = ir == 8'b01110010;
  /* T80_MCode.vhd:1430:55  */
  assign n4638_o = n4635_o | n4637_o;
  /* T80_MCode.vhd:1430:66  */
  assign n4640_o = ir == 8'b01110011;
  /* T80_MCode.vhd:1430:66  */
  assign n4641_o = n4638_o | n4640_o;
  /* T80_MCode.vhd:1430:77  */
  assign n4643_o = ir == 8'b01110100;
  /* T80_MCode.vhd:1430:77  */
  assign n4644_o = n4641_o | n4643_o;
  /* T80_MCode.vhd:1430:88  */
  assign n4646_o = ir == 8'b01110101;
  /* T80_MCode.vhd:1430:88  */
  assign n4647_o = n4644_o | n4646_o;
  /* T80_MCode.vhd:1430:99  */
  assign n4649_o = ir == 8'b01110111;
  /* T80_MCode.vhd:1430:99  */
  assign n4650_o = n4647_o | n4649_o;
  /* T80_MCode.vhd:1431:33  */
  assign n4652_o = ir == 8'b01111000;
  /* T80_MCode.vhd:1431:33  */
  assign n4653_o = n4650_o | n4652_o;
  /* T80_MCode.vhd:1431:44  */
  assign n4655_o = ir == 8'b01111001;
  /* T80_MCode.vhd:1431:44  */
  assign n4656_o = n4653_o | n4655_o;
  /* T80_MCode.vhd:1431:55  */
  assign n4658_o = ir == 8'b01111010;
  /* T80_MCode.vhd:1431:55  */
  assign n4659_o = n4656_o | n4658_o;
  /* T80_MCode.vhd:1431:66  */
  assign n4661_o = ir == 8'b01111011;
  /* T80_MCode.vhd:1431:66  */
  assign n4662_o = n4659_o | n4661_o;
  /* T80_MCode.vhd:1431:77  */
  assign n4664_o = ir == 8'b01111100;
  /* T80_MCode.vhd:1431:77  */
  assign n4665_o = n4662_o | n4664_o;
  /* T80_MCode.vhd:1431:88  */
  assign n4667_o = ir == 8'b01111101;
  /* T80_MCode.vhd:1431:88  */
  assign n4668_o = n4665_o | n4667_o;
  /* T80_MCode.vhd:1431:99  */
  assign n4670_o = ir == 8'b01111111;
  /* T80_MCode.vhd:1431:99  */
  assign n4671_o = n4668_o | n4670_o;
  /* T80_MCode.vhd:1455:38  */
  assign n4672_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1456:33  */
  assign n4674_o = n4672_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1456:40  */
  assign n4676_o = n4672_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1456:40  */
  assign n4677_o = n4674_o | n4676_o;
  /* T80_MCode.vhd:1458:33  */
  assign n4679_o = n4672_o == 31'b0000000000000000000000000000010;
  assign n4680_o = {n4679_o, n4677_o};
  /* T80_MCode.vhd:1455:33  */
  always @*
    case (n4680_o)
      2'b10: n4682_o = 3'b100;
      2'b01: n4682_o = n2179_o;
      default: n4682_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1455:33  */
  always @*
    case (n4680_o)
      2'b10: n4684_o = 4'b1001;
      2'b01: n4684_o = n2182_o;
      default: n4684_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1455:33  */
  always @*
    case (n4680_o)
      2'b10: n4687_o = 3'b111;
      2'b01: n4687_o = 3'b010;
      default: n4687_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1452:25  */
  assign n4689_o = ir == 8'b01000110;
  /* T80_MCode.vhd:1452:40  */
  assign n4691_o = ir == 8'b01001110;
  /* T80_MCode.vhd:1452:40  */
  assign n4692_o = n4689_o | n4691_o;
  /* T80_MCode.vhd:1452:51  */
  assign n4694_o = ir == 8'b01010110;
  /* T80_MCode.vhd:1452:51  */
  assign n4695_o = n4692_o | n4694_o;
  /* T80_MCode.vhd:1452:62  */
  assign n4697_o = ir == 8'b01011110;
  /* T80_MCode.vhd:1452:62  */
  assign n4698_o = n4695_o | n4697_o;
  /* T80_MCode.vhd:1452:73  */
  assign n4700_o = ir == 8'b01100110;
  /* T80_MCode.vhd:1452:73  */
  assign n4701_o = n4698_o | n4700_o;
  /* T80_MCode.vhd:1452:84  */
  assign n4703_o = ir == 8'b01101110;
  /* T80_MCode.vhd:1452:84  */
  assign n4704_o = n4701_o | n4703_o;
  /* T80_MCode.vhd:1452:95  */
  assign n4706_o = ir == 8'b01110110;
  /* T80_MCode.vhd:1452:95  */
  assign n4707_o = n4704_o | n4706_o;
  /* T80_MCode.vhd:1452:106  */
  assign n4709_o = ir == 8'b01111110;
  /* T80_MCode.vhd:1452:106  */
  assign n4710_o = n4707_o | n4709_o;
  /* T80_MCode.vhd:1472:44  */
  assign n4712_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1473:51  */
  assign n4714_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1473:41  */
  assign n4717_o = n4714_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1473:41  */
  assign n4719_o = n4714_o ? 4'b1010 : n2182_o;
  /* T80_MCode.vhd:1473:41  */
  assign n4722_o = n4714_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1482:46  */
  assign n4723_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1483:41  */
  assign n4725_o = n4723_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1483:48  */
  assign n4727_o = n4723_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1483:48  */
  assign n4728_o = n4725_o | n4727_o;
  /* T80_MCode.vhd:1485:41  */
  assign n4730_o = n4723_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1491:41  */
  assign n4732_o = n4723_o == 31'b0000000000000000000000000000011;
  assign n4733_o = {n4732_o, n4730_o, n4728_o};
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4735_o = n2179_o;
      3'b010: n4735_o = 3'b100;
      3'b001: n4735_o = n2179_o;
      default: n4735_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4738_o = 1'b0;
      3'b010: n4738_o = 1'b1;
      3'b001: n4738_o = 1'b0;
      default: n4738_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4740_o = n2182_o;
      3'b010: n4740_o = 4'b1010;
      3'b001: n4740_o = n2182_o;
      default: n4740_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4743_o = 1'b0;
      3'b010: n4743_o = 1'b1;
      3'b001: n4743_o = 1'b0;
      default: n4743_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4747_o = 3'b111;
      3'b010: n4747_o = 3'b010;
      3'b001: n4747_o = 3'b010;
      default: n4747_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4750_o = 1'b1;
      3'b010: n4750_o = 1'b0;
      3'b001: n4750_o = 1'b0;
      default: n4750_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1472:33  */
  assign n4753_o = n4712_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1472:33  */
  assign n4754_o = n4712_o ? n2179_o : n4735_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4755_o = n4712_o ? n4717_o : n4738_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4756_o = n4712_o ? n4719_o : n4740_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4757_o = n4712_o ? n4722_o : n4743_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4759_o = n4712_o ? 3'b111 : n4747_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4761_o = n4712_o ? 1'b0 : n4750_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4764_o = n4712_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1463:25  */
  assign n4766_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1463:40  */
  assign n4768_o = ir == 8'b11000001;
  /* T80_MCode.vhd:1463:40  */
  assign n4769_o = n4766_o | n4768_o;
  /* T80_MCode.vhd:1463:51  */
  assign n4771_o = ir == 8'b11000010;
  /* T80_MCode.vhd:1463:51  */
  assign n4772_o = n4769_o | n4771_o;
  /* T80_MCode.vhd:1463:62  */
  assign n4774_o = ir == 8'b11000011;
  /* T80_MCode.vhd:1463:62  */
  assign n4775_o = n4772_o | n4774_o;
  /* T80_MCode.vhd:1463:73  */
  assign n4777_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1463:73  */
  assign n4778_o = n4775_o | n4777_o;
  /* T80_MCode.vhd:1463:84  */
  assign n4780_o = ir == 8'b11000101;
  /* T80_MCode.vhd:1463:84  */
  assign n4781_o = n4778_o | n4780_o;
  /* T80_MCode.vhd:1463:95  */
  assign n4783_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1463:95  */
  assign n4784_o = n4781_o | n4783_o;
  /* T80_MCode.vhd:1464:33  */
  assign n4786_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1464:33  */
  assign n4787_o = n4784_o | n4786_o;
  /* T80_MCode.vhd:1464:44  */
  assign n4789_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1464:44  */
  assign n4790_o = n4787_o | n4789_o;
  /* T80_MCode.vhd:1464:55  */
  assign n4792_o = ir == 8'b11001010;
  /* T80_MCode.vhd:1464:55  */
  assign n4793_o = n4790_o | n4792_o;
  /* T80_MCode.vhd:1464:66  */
  assign n4795_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1464:66  */
  assign n4796_o = n4793_o | n4795_o;
  /* T80_MCode.vhd:1464:77  */
  assign n4798_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1464:77  */
  assign n4799_o = n4796_o | n4798_o;
  /* T80_MCode.vhd:1464:88  */
  assign n4801_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1464:88  */
  assign n4802_o = n4799_o | n4801_o;
  /* T80_MCode.vhd:1464:99  */
  assign n4804_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1464:99  */
  assign n4805_o = n4802_o | n4804_o;
  /* T80_MCode.vhd:1465:33  */
  assign n4807_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1465:33  */
  assign n4808_o = n4805_o | n4807_o;
  /* T80_MCode.vhd:1465:44  */
  assign n4810_o = ir == 8'b11010001;
  /* T80_MCode.vhd:1465:44  */
  assign n4811_o = n4808_o | n4810_o;
  /* T80_MCode.vhd:1465:55  */
  assign n4813_o = ir == 8'b11010010;
  /* T80_MCode.vhd:1465:55  */
  assign n4814_o = n4811_o | n4813_o;
  /* T80_MCode.vhd:1465:66  */
  assign n4816_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1465:66  */
  assign n4817_o = n4814_o | n4816_o;
  /* T80_MCode.vhd:1465:77  */
  assign n4819_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1465:77  */
  assign n4820_o = n4817_o | n4819_o;
  /* T80_MCode.vhd:1465:88  */
  assign n4822_o = ir == 8'b11010101;
  /* T80_MCode.vhd:1465:88  */
  assign n4823_o = n4820_o | n4822_o;
  /* T80_MCode.vhd:1465:99  */
  assign n4825_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1465:99  */
  assign n4826_o = n4823_o | n4825_o;
  /* T80_MCode.vhd:1466:33  */
  assign n4828_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1466:33  */
  assign n4829_o = n4826_o | n4828_o;
  /* T80_MCode.vhd:1466:44  */
  assign n4831_o = ir == 8'b11011001;
  /* T80_MCode.vhd:1466:44  */
  assign n4832_o = n4829_o | n4831_o;
  /* T80_MCode.vhd:1466:55  */
  assign n4834_o = ir == 8'b11011010;
  /* T80_MCode.vhd:1466:55  */
  assign n4835_o = n4832_o | n4834_o;
  /* T80_MCode.vhd:1466:66  */
  assign n4837_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1466:66  */
  assign n4838_o = n4835_o | n4837_o;
  /* T80_MCode.vhd:1466:77  */
  assign n4840_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1466:77  */
  assign n4841_o = n4838_o | n4840_o;
  /* T80_MCode.vhd:1466:88  */
  assign n4843_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1466:88  */
  assign n4844_o = n4841_o | n4843_o;
  /* T80_MCode.vhd:1466:99  */
  assign n4846_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1466:99  */
  assign n4847_o = n4844_o | n4846_o;
  /* T80_MCode.vhd:1467:33  */
  assign n4849_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1467:33  */
  assign n4850_o = n4847_o | n4849_o;
  /* T80_MCode.vhd:1467:44  */
  assign n4852_o = ir == 8'b11100001;
  /* T80_MCode.vhd:1467:44  */
  assign n4853_o = n4850_o | n4852_o;
  /* T80_MCode.vhd:1467:55  */
  assign n4855_o = ir == 8'b11100010;
  /* T80_MCode.vhd:1467:55  */
  assign n4856_o = n4853_o | n4855_o;
  /* T80_MCode.vhd:1467:66  */
  assign n4858_o = ir == 8'b11100011;
  /* T80_MCode.vhd:1467:66  */
  assign n4859_o = n4856_o | n4858_o;
  /* T80_MCode.vhd:1467:77  */
  assign n4861_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1467:77  */
  assign n4862_o = n4859_o | n4861_o;
  /* T80_MCode.vhd:1467:88  */
  assign n4864_o = ir == 8'b11100101;
  /* T80_MCode.vhd:1467:88  */
  assign n4865_o = n4862_o | n4864_o;
  /* T80_MCode.vhd:1467:99  */
  assign n4867_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1467:99  */
  assign n4868_o = n4865_o | n4867_o;
  /* T80_MCode.vhd:1468:33  */
  assign n4870_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1468:33  */
  assign n4871_o = n4868_o | n4870_o;
  /* T80_MCode.vhd:1468:44  */
  assign n4873_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1468:44  */
  assign n4874_o = n4871_o | n4873_o;
  /* T80_MCode.vhd:1468:55  */
  assign n4876_o = ir == 8'b11101010;
  /* T80_MCode.vhd:1468:55  */
  assign n4877_o = n4874_o | n4876_o;
  /* T80_MCode.vhd:1468:66  */
  assign n4879_o = ir == 8'b11101011;
  /* T80_MCode.vhd:1468:66  */
  assign n4880_o = n4877_o | n4879_o;
  /* T80_MCode.vhd:1468:77  */
  assign n4882_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1468:77  */
  assign n4883_o = n4880_o | n4882_o;
  /* T80_MCode.vhd:1468:88  */
  assign n4885_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1468:88  */
  assign n4886_o = n4883_o | n4885_o;
  /* T80_MCode.vhd:1468:99  */
  assign n4888_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1468:99  */
  assign n4889_o = n4886_o | n4888_o;
  /* T80_MCode.vhd:1469:33  */
  assign n4891_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1469:33  */
  assign n4892_o = n4889_o | n4891_o;
  /* T80_MCode.vhd:1469:44  */
  assign n4894_o = ir == 8'b11110001;
  /* T80_MCode.vhd:1469:44  */
  assign n4895_o = n4892_o | n4894_o;
  /* T80_MCode.vhd:1469:55  */
  assign n4897_o = ir == 8'b11110010;
  /* T80_MCode.vhd:1469:55  */
  assign n4898_o = n4895_o | n4897_o;
  /* T80_MCode.vhd:1469:66  */
  assign n4900_o = ir == 8'b11110011;
  /* T80_MCode.vhd:1469:66  */
  assign n4901_o = n4898_o | n4900_o;
  /* T80_MCode.vhd:1469:77  */
  assign n4903_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1469:77  */
  assign n4904_o = n4901_o | n4903_o;
  /* T80_MCode.vhd:1469:88  */
  assign n4906_o = ir == 8'b11110101;
  /* T80_MCode.vhd:1469:88  */
  assign n4907_o = n4904_o | n4906_o;
  /* T80_MCode.vhd:1469:99  */
  assign n4909_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1469:99  */
  assign n4910_o = n4907_o | n4909_o;
  /* T80_MCode.vhd:1470:33  */
  assign n4912_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1470:33  */
  assign n4913_o = n4910_o | n4912_o;
  /* T80_MCode.vhd:1470:44  */
  assign n4915_o = ir == 8'b11111001;
  /* T80_MCode.vhd:1470:44  */
  assign n4916_o = n4913_o | n4915_o;
  /* T80_MCode.vhd:1470:55  */
  assign n4918_o = ir == 8'b11111010;
  /* T80_MCode.vhd:1470:55  */
  assign n4919_o = n4916_o | n4918_o;
  /* T80_MCode.vhd:1470:66  */
  assign n4921_o = ir == 8'b11111011;
  /* T80_MCode.vhd:1470:66  */
  assign n4922_o = n4919_o | n4921_o;
  /* T80_MCode.vhd:1470:77  */
  assign n4924_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1470:77  */
  assign n4925_o = n4922_o | n4924_o;
  /* T80_MCode.vhd:1470:88  */
  assign n4927_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1470:88  */
  assign n4928_o = n4925_o | n4927_o;
  /* T80_MCode.vhd:1470:99  */
  assign n4930_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1470:99  */
  assign n4931_o = n4928_o | n4930_o;
  /* T80_MCode.vhd:1500:38  */
  assign n4932_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1501:33  */
  assign n4934_o = n4932_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1501:40  */
  assign n4936_o = n4932_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1501:40  */
  assign n4937_o = n4934_o | n4936_o;
  /* T80_MCode.vhd:1503:33  */
  assign n4939_o = n4932_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1509:33  */
  assign n4941_o = n4932_o == 31'b0000000000000000000000000000011;
  assign n4942_o = {n4941_o, n4939_o, n4937_o};
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4944_o = n2179_o;
      3'b010: n4944_o = 3'b100;
      3'b001: n4944_o = n2179_o;
      default: n4944_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4947_o = 1'b0;
      3'b010: n4947_o = 1'b1;
      3'b001: n4947_o = 1'b0;
      default: n4947_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4949_o = n2182_o;
      3'b010: n4949_o = 4'b1010;
      3'b001: n4949_o = n2182_o;
      default: n4949_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4952_o = 1'b0;
      3'b010: n4952_o = 1'b1;
      3'b001: n4952_o = 1'b0;
      default: n4952_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4956_o = 3'b111;
      3'b010: n4956_o = 3'b010;
      3'b001: n4956_o = 3'b010;
      default: n4956_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4959_o = 1'b1;
      3'b010: n4959_o = 1'b0;
      3'b001: n4959_o = 1'b0;
      default: n4959_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1497:25  */
  assign n4961_o = ir == 8'b11000110;
  /* T80_MCode.vhd:1497:40  */
  assign n4963_o = ir == 8'b11001110;
  /* T80_MCode.vhd:1497:40  */
  assign n4964_o = n4961_o | n4963_o;
  /* T80_MCode.vhd:1497:51  */
  assign n4966_o = ir == 8'b11010110;
  /* T80_MCode.vhd:1497:51  */
  assign n4967_o = n4964_o | n4966_o;
  /* T80_MCode.vhd:1497:62  */
  assign n4969_o = ir == 8'b11011110;
  /* T80_MCode.vhd:1497:62  */
  assign n4970_o = n4967_o | n4969_o;
  /* T80_MCode.vhd:1497:73  */
  assign n4972_o = ir == 8'b11100110;
  /* T80_MCode.vhd:1497:73  */
  assign n4973_o = n4970_o | n4972_o;
  /* T80_MCode.vhd:1497:84  */
  assign n4975_o = ir == 8'b11101110;
  /* T80_MCode.vhd:1497:84  */
  assign n4976_o = n4973_o | n4975_o;
  /* T80_MCode.vhd:1497:95  */
  assign n4978_o = ir == 8'b11110110;
  /* T80_MCode.vhd:1497:95  */
  assign n4979_o = n4976_o | n4978_o;
  /* T80_MCode.vhd:1497:106  */
  assign n4981_o = ir == 8'b11111110;
  /* T80_MCode.vhd:1497:106  */
  assign n4982_o = n4979_o | n4981_o;
  /* T80_MCode.vhd:1522:44  */
  assign n4984_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1523:51  */
  assign n4986_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1523:41  */
  assign n4989_o = n4986_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1523:41  */
  assign n4991_o = n4986_o ? 4'b1011 : n2182_o;
  /* T80_MCode.vhd:1523:41  */
  assign n4994_o = n4986_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1532:46  */
  assign n4995_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1533:41  */
  assign n4997_o = n4995_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1533:48  */
  assign n4999_o = n4995_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1533:48  */
  assign n5000_o = n4997_o | n4999_o;
  /* T80_MCode.vhd:1535:41  */
  assign n5002_o = n4995_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1541:41  */
  assign n5004_o = n4995_o == 31'b0000000000000000000000000000011;
  assign n5005_o = {n5004_o, n5002_o, n5000_o};
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5007_o = n2179_o;
      3'b010: n5007_o = 3'b100;
      3'b001: n5007_o = n2179_o;
      default: n5007_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5010_o = 1'b0;
      3'b010: n5010_o = 1'b1;
      3'b001: n5010_o = 1'b0;
      default: n5010_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5012_o = n2182_o;
      3'b010: n5012_o = 4'b1011;
      3'b001: n5012_o = n2182_o;
      default: n5012_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5015_o = 1'b0;
      3'b010: n5015_o = 1'b1;
      3'b001: n5015_o = 1'b0;
      default: n5015_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5019_o = 3'b111;
      3'b010: n5019_o = 3'b010;
      3'b001: n5019_o = 3'b010;
      default: n5019_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5022_o = 1'b1;
      3'b010: n5022_o = 1'b0;
      3'b001: n5022_o = 1'b0;
      default: n5022_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1522:33  */
  assign n5025_o = n4984_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1522:33  */
  assign n5026_o = n4984_o ? n2179_o : n5007_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5027_o = n4984_o ? n4989_o : n5010_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5028_o = n4984_o ? n4991_o : n5012_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5029_o = n4984_o ? n4994_o : n5015_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5031_o = n4984_o ? 3'b111 : n5019_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5033_o = n4984_o ? 1'b0 : n5022_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5036_o = n4984_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1513:25  */
  assign n5038_o = ir == 8'b10000000;
  /* T80_MCode.vhd:1513:40  */
  assign n5040_o = ir == 8'b10000001;
  /* T80_MCode.vhd:1513:40  */
  assign n5041_o = n5038_o | n5040_o;
  /* T80_MCode.vhd:1513:51  */
  assign n5043_o = ir == 8'b10000010;
  /* T80_MCode.vhd:1513:51  */
  assign n5044_o = n5041_o | n5043_o;
  /* T80_MCode.vhd:1513:62  */
  assign n5046_o = ir == 8'b10000011;
  /* T80_MCode.vhd:1513:62  */
  assign n5047_o = n5044_o | n5046_o;
  /* T80_MCode.vhd:1513:73  */
  assign n5049_o = ir == 8'b10000100;
  /* T80_MCode.vhd:1513:73  */
  assign n5050_o = n5047_o | n5049_o;
  /* T80_MCode.vhd:1513:84  */
  assign n5052_o = ir == 8'b10000101;
  /* T80_MCode.vhd:1513:84  */
  assign n5053_o = n5050_o | n5052_o;
  /* T80_MCode.vhd:1513:95  */
  assign n5055_o = ir == 8'b10000111;
  /* T80_MCode.vhd:1513:95  */
  assign n5056_o = n5053_o | n5055_o;
  /* T80_MCode.vhd:1514:33  */
  assign n5058_o = ir == 8'b10001000;
  /* T80_MCode.vhd:1514:33  */
  assign n5059_o = n5056_o | n5058_o;
  /* T80_MCode.vhd:1514:44  */
  assign n5061_o = ir == 8'b10001001;
  /* T80_MCode.vhd:1514:44  */
  assign n5062_o = n5059_o | n5061_o;
  /* T80_MCode.vhd:1514:55  */
  assign n5064_o = ir == 8'b10001010;
  /* T80_MCode.vhd:1514:55  */
  assign n5065_o = n5062_o | n5064_o;
  /* T80_MCode.vhd:1514:66  */
  assign n5067_o = ir == 8'b10001011;
  /* T80_MCode.vhd:1514:66  */
  assign n5068_o = n5065_o | n5067_o;
  /* T80_MCode.vhd:1514:77  */
  assign n5070_o = ir == 8'b10001100;
  /* T80_MCode.vhd:1514:77  */
  assign n5071_o = n5068_o | n5070_o;
  /* T80_MCode.vhd:1514:88  */
  assign n5073_o = ir == 8'b10001101;
  /* T80_MCode.vhd:1514:88  */
  assign n5074_o = n5071_o | n5073_o;
  /* T80_MCode.vhd:1514:99  */
  assign n5076_o = ir == 8'b10001111;
  /* T80_MCode.vhd:1514:99  */
  assign n5077_o = n5074_o | n5076_o;
  /* T80_MCode.vhd:1515:33  */
  assign n5079_o = ir == 8'b10010000;
  /* T80_MCode.vhd:1515:33  */
  assign n5080_o = n5077_o | n5079_o;
  /* T80_MCode.vhd:1515:44  */
  assign n5082_o = ir == 8'b10010001;
  /* T80_MCode.vhd:1515:44  */
  assign n5083_o = n5080_o | n5082_o;
  /* T80_MCode.vhd:1515:55  */
  assign n5085_o = ir == 8'b10010010;
  /* T80_MCode.vhd:1515:55  */
  assign n5086_o = n5083_o | n5085_o;
  /* T80_MCode.vhd:1515:66  */
  assign n5088_o = ir == 8'b10010011;
  /* T80_MCode.vhd:1515:66  */
  assign n5089_o = n5086_o | n5088_o;
  /* T80_MCode.vhd:1515:77  */
  assign n5091_o = ir == 8'b10010100;
  /* T80_MCode.vhd:1515:77  */
  assign n5092_o = n5089_o | n5091_o;
  /* T80_MCode.vhd:1515:88  */
  assign n5094_o = ir == 8'b10010101;
  /* T80_MCode.vhd:1515:88  */
  assign n5095_o = n5092_o | n5094_o;
  /* T80_MCode.vhd:1515:99  */
  assign n5097_o = ir == 8'b10010111;
  /* T80_MCode.vhd:1515:99  */
  assign n5098_o = n5095_o | n5097_o;
  /* T80_MCode.vhd:1516:33  */
  assign n5100_o = ir == 8'b10011000;
  /* T80_MCode.vhd:1516:33  */
  assign n5101_o = n5098_o | n5100_o;
  /* T80_MCode.vhd:1516:44  */
  assign n5103_o = ir == 8'b10011001;
  /* T80_MCode.vhd:1516:44  */
  assign n5104_o = n5101_o | n5103_o;
  /* T80_MCode.vhd:1516:55  */
  assign n5106_o = ir == 8'b10011010;
  /* T80_MCode.vhd:1516:55  */
  assign n5107_o = n5104_o | n5106_o;
  /* T80_MCode.vhd:1516:66  */
  assign n5109_o = ir == 8'b10011011;
  /* T80_MCode.vhd:1516:66  */
  assign n5110_o = n5107_o | n5109_o;
  /* T80_MCode.vhd:1516:77  */
  assign n5112_o = ir == 8'b10011100;
  /* T80_MCode.vhd:1516:77  */
  assign n5113_o = n5110_o | n5112_o;
  /* T80_MCode.vhd:1516:88  */
  assign n5115_o = ir == 8'b10011101;
  /* T80_MCode.vhd:1516:88  */
  assign n5116_o = n5113_o | n5115_o;
  /* T80_MCode.vhd:1516:99  */
  assign n5118_o = ir == 8'b10011111;
  /* T80_MCode.vhd:1516:99  */
  assign n5119_o = n5116_o | n5118_o;
  /* T80_MCode.vhd:1517:33  */
  assign n5121_o = ir == 8'b10100000;
  /* T80_MCode.vhd:1517:33  */
  assign n5122_o = n5119_o | n5121_o;
  /* T80_MCode.vhd:1517:44  */
  assign n5124_o = ir == 8'b10100001;
  /* T80_MCode.vhd:1517:44  */
  assign n5125_o = n5122_o | n5124_o;
  /* T80_MCode.vhd:1517:55  */
  assign n5127_o = ir == 8'b10100010;
  /* T80_MCode.vhd:1517:55  */
  assign n5128_o = n5125_o | n5127_o;
  /* T80_MCode.vhd:1517:66  */
  assign n5130_o = ir == 8'b10100011;
  /* T80_MCode.vhd:1517:66  */
  assign n5131_o = n5128_o | n5130_o;
  /* T80_MCode.vhd:1517:77  */
  assign n5133_o = ir == 8'b10100100;
  /* T80_MCode.vhd:1517:77  */
  assign n5134_o = n5131_o | n5133_o;
  /* T80_MCode.vhd:1517:88  */
  assign n5136_o = ir == 8'b10100101;
  /* T80_MCode.vhd:1517:88  */
  assign n5137_o = n5134_o | n5136_o;
  /* T80_MCode.vhd:1517:99  */
  assign n5139_o = ir == 8'b10100111;
  /* T80_MCode.vhd:1517:99  */
  assign n5140_o = n5137_o | n5139_o;
  /* T80_MCode.vhd:1518:33  */
  assign n5142_o = ir == 8'b10101000;
  /* T80_MCode.vhd:1518:33  */
  assign n5143_o = n5140_o | n5142_o;
  /* T80_MCode.vhd:1518:44  */
  assign n5145_o = ir == 8'b10101001;
  /* T80_MCode.vhd:1518:44  */
  assign n5146_o = n5143_o | n5145_o;
  /* T80_MCode.vhd:1518:55  */
  assign n5148_o = ir == 8'b10101010;
  /* T80_MCode.vhd:1518:55  */
  assign n5149_o = n5146_o | n5148_o;
  /* T80_MCode.vhd:1518:66  */
  assign n5151_o = ir == 8'b10101011;
  /* T80_MCode.vhd:1518:66  */
  assign n5152_o = n5149_o | n5151_o;
  /* T80_MCode.vhd:1518:77  */
  assign n5154_o = ir == 8'b10101100;
  /* T80_MCode.vhd:1518:77  */
  assign n5155_o = n5152_o | n5154_o;
  /* T80_MCode.vhd:1518:88  */
  assign n5157_o = ir == 8'b10101101;
  /* T80_MCode.vhd:1518:88  */
  assign n5158_o = n5155_o | n5157_o;
  /* T80_MCode.vhd:1518:99  */
  assign n5160_o = ir == 8'b10101111;
  /* T80_MCode.vhd:1518:99  */
  assign n5161_o = n5158_o | n5160_o;
  /* T80_MCode.vhd:1519:33  */
  assign n5163_o = ir == 8'b10110000;
  /* T80_MCode.vhd:1519:33  */
  assign n5164_o = n5161_o | n5163_o;
  /* T80_MCode.vhd:1519:44  */
  assign n5166_o = ir == 8'b10110001;
  /* T80_MCode.vhd:1519:44  */
  assign n5167_o = n5164_o | n5166_o;
  /* T80_MCode.vhd:1519:55  */
  assign n5169_o = ir == 8'b10110010;
  /* T80_MCode.vhd:1519:55  */
  assign n5170_o = n5167_o | n5169_o;
  /* T80_MCode.vhd:1519:66  */
  assign n5172_o = ir == 8'b10110011;
  /* T80_MCode.vhd:1519:66  */
  assign n5173_o = n5170_o | n5172_o;
  /* T80_MCode.vhd:1519:77  */
  assign n5175_o = ir == 8'b10110100;
  /* T80_MCode.vhd:1519:77  */
  assign n5176_o = n5173_o | n5175_o;
  /* T80_MCode.vhd:1519:88  */
  assign n5178_o = ir == 8'b10110101;
  /* T80_MCode.vhd:1519:88  */
  assign n5179_o = n5176_o | n5178_o;
  /* T80_MCode.vhd:1519:99  */
  assign n5181_o = ir == 8'b10110111;
  /* T80_MCode.vhd:1519:99  */
  assign n5182_o = n5179_o | n5181_o;
  /* T80_MCode.vhd:1520:33  */
  assign n5184_o = ir == 8'b10111000;
  /* T80_MCode.vhd:1520:33  */
  assign n5185_o = n5182_o | n5184_o;
  /* T80_MCode.vhd:1520:44  */
  assign n5187_o = ir == 8'b10111001;
  /* T80_MCode.vhd:1520:44  */
  assign n5188_o = n5185_o | n5187_o;
  /* T80_MCode.vhd:1520:55  */
  assign n5190_o = ir == 8'b10111010;
  /* T80_MCode.vhd:1520:55  */
  assign n5191_o = n5188_o | n5190_o;
  /* T80_MCode.vhd:1520:66  */
  assign n5193_o = ir == 8'b10111011;
  /* T80_MCode.vhd:1520:66  */
  assign n5194_o = n5191_o | n5193_o;
  /* T80_MCode.vhd:1520:77  */
  assign n5196_o = ir == 8'b10111100;
  /* T80_MCode.vhd:1520:77  */
  assign n5197_o = n5194_o | n5196_o;
  /* T80_MCode.vhd:1520:88  */
  assign n5199_o = ir == 8'b10111101;
  /* T80_MCode.vhd:1520:88  */
  assign n5200_o = n5197_o | n5199_o;
  /* T80_MCode.vhd:1520:99  */
  assign n5202_o = ir == 8'b10111111;
  /* T80_MCode.vhd:1520:99  */
  assign n5203_o = n5200_o | n5202_o;
  /* T80_MCode.vhd:1550:38  */
  assign n5204_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1551:33  */
  assign n5206_o = n5204_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1551:40  */
  assign n5208_o = n5204_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1551:40  */
  assign n5209_o = n5206_o | n5208_o;
  /* T80_MCode.vhd:1553:33  */
  assign n5211_o = n5204_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1559:33  */
  assign n5213_o = n5204_o == 31'b0000000000000000000000000000011;
  assign n5214_o = {n5213_o, n5211_o, n5209_o};
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5216_o = n2179_o;
      3'b010: n5216_o = 3'b100;
      3'b001: n5216_o = n2179_o;
      default: n5216_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5219_o = 1'b0;
      3'b010: n5219_o = 1'b1;
      3'b001: n5219_o = 1'b0;
      default: n5219_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5221_o = n2182_o;
      3'b010: n5221_o = 4'b1011;
      3'b001: n5221_o = n2182_o;
      default: n5221_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5224_o = 1'b0;
      3'b010: n5224_o = 1'b1;
      3'b001: n5224_o = 1'b0;
      default: n5224_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5228_o = 3'b111;
      3'b010: n5228_o = 3'b010;
      3'b001: n5228_o = 3'b010;
      default: n5228_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5231_o = 1'b1;
      3'b010: n5231_o = 1'b0;
      3'b001: n5231_o = 1'b0;
      default: n5231_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1547:25  */
  assign n5233_o = ir == 8'b10000110;
  /* T80_MCode.vhd:1547:40  */
  assign n5235_o = ir == 8'b10001110;
  /* T80_MCode.vhd:1547:40  */
  assign n5236_o = n5233_o | n5235_o;
  /* T80_MCode.vhd:1547:51  */
  assign n5238_o = ir == 8'b10010110;
  /* T80_MCode.vhd:1547:51  */
  assign n5239_o = n5236_o | n5238_o;
  /* T80_MCode.vhd:1547:62  */
  assign n5241_o = ir == 8'b10011110;
  /* T80_MCode.vhd:1547:62  */
  assign n5242_o = n5239_o | n5241_o;
  /* T80_MCode.vhd:1547:73  */
  assign n5244_o = ir == 8'b10100110;
  /* T80_MCode.vhd:1547:73  */
  assign n5245_o = n5242_o | n5244_o;
  /* T80_MCode.vhd:1547:84  */
  assign n5247_o = ir == 8'b10101110;
  /* T80_MCode.vhd:1547:84  */
  assign n5248_o = n5245_o | n5247_o;
  /* T80_MCode.vhd:1547:95  */
  assign n5250_o = ir == 8'b10110110;
  /* T80_MCode.vhd:1547:95  */
  assign n5251_o = n5248_o | n5250_o;
  /* T80_MCode.vhd:1547:106  */
  assign n5253_o = ir == 8'b10111110;
  /* T80_MCode.vhd:1547:106  */
  assign n5254_o = n5251_o | n5253_o;
  assign n5255_o = {n5254_o, n5203_o, n4982_o, n4931_o, n4710_o, n4671_o, n4469_o, n4418_o};
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5261_o = 3'b011;
      8'b01000000: n5261_o = n5025_o;
      8'b00100000: n5261_o = 3'b011;
      8'b00010000: n5261_o = n4753_o;
      8'b00001000: n5261_o = 3'b010;
      8'b00000100: n5261_o = n4496_o;
      8'b00000010: n5261_o = 3'b011;
      8'b00000001: n5261_o = n4240_o;
      default: n5261_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5263_o = n5216_o;
      8'b01000000: n5263_o = n5026_o;
      8'b00100000: n5263_o = n4944_o;
      8'b00010000: n5263_o = n4754_o;
      8'b00001000: n5263_o = n4682_o;
      8'b00000100: n5263_o = n4497_o;
      8'b00000010: n5263_o = n4431_o;
      8'b00000001: n5263_o = n4241_o;
      default: n5263_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5266_o = n5219_o;
      8'b01000000: n5266_o = n5027_o;
      8'b00100000: n5266_o = n4947_o;
      8'b00010000: n5266_o = n4755_o;
      8'b00001000: n5266_o = 1'b0;
      8'b00000100: n5266_o = 1'b0;
      8'b00000010: n5266_o = n4434_o;
      8'b00000001: n5266_o = n4242_o;
      default: n5266_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5268_o = n4197_o;
      8'b01000000: n5268_o = n4197_o;
      8'b00100000: n5268_o = n4197_o;
      8'b00010000: n5268_o = n4197_o;
      8'b00001000: n5268_o = n4197_o;
      8'b00000100: n5268_o = n4475_o;
      8'b00000010: n5268_o = n4197_o;
      8'b00000001: n5268_o = n4197_o;
      default: n5268_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5270_o = n5221_o;
      8'b01000000: n5270_o = n5028_o;
      8'b00100000: n5270_o = n4949_o;
      8'b00010000: n5270_o = n4756_o;
      8'b00001000: n5270_o = n4684_o;
      8'b00000100: n5270_o = n4499_o;
      8'b00000010: n5270_o = n4436_o;
      8'b00000001: n5270_o = n4243_o;
      default: n5270_o = 4'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5273_o = n5224_o;
      8'b01000000: n5273_o = n5029_o;
      8'b00100000: n5273_o = n4952_o;
      8'b00010000: n5273_o = n4757_o;
      8'b00001000: n5273_o = 1'b0;
      8'b00000100: n5273_o = 1'b0;
      8'b00000010: n5273_o = n4439_o;
      8'b00000001: n5273_o = n4244_o;
      default: n5273_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5275_o = n5228_o;
      8'b01000000: n5275_o = n5031_o;
      8'b00100000: n5275_o = n4956_o;
      8'b00010000: n5275_o = n4759_o;
      8'b00001000: n5275_o = n4687_o;
      8'b00000100: n5275_o = n4501_o;
      8'b00000010: n5275_o = n4443_o;
      8'b00000001: n5275_o = n4246_o;
      default: n5275_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5278_o = n5231_o;
      8'b01000000: n5278_o = n5033_o;
      8'b00100000: n5278_o = n4959_o;
      8'b00010000: n5278_o = n4761_o;
      8'b00001000: n5278_o = 1'b0;
      8'b00000100: n5278_o = 1'b0;
      8'b00000010: n5278_o = n4446_o;
      8'b00000001: n5278_o = n4248_o;
      default: n5278_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5281_o = 1'b0;
      8'b01000000: n5281_o = n5036_o;
      8'b00100000: n5281_o = 1'b0;
      8'b00010000: n5281_o = n4764_o;
      8'b00001000: n5281_o = 1'b0;
      8'b00000100: n5281_o = n4504_o;
      8'b00000010: n5281_o = 1'b0;
      8'b00000001: n5281_o = n4251_o;
      default: n5281_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1348:17  */
  assign n5283_o = iset == 2'b01;
  /* T80_MCode.vhd:1574:25  */
  assign n5285_o = ir == 8'b00000000;
  /* T80_MCode.vhd:1574:40  */
  assign n5287_o = ir == 8'b00000001;
  /* T80_MCode.vhd:1574:40  */
  assign n5288_o = n5285_o | n5287_o;
  /* T80_MCode.vhd:1574:51  */
  assign n5290_o = ir == 8'b00000010;
  /* T80_MCode.vhd:1574:51  */
  assign n5291_o = n5288_o | n5290_o;
  /* T80_MCode.vhd:1574:62  */
  assign n5293_o = ir == 8'b00000011;
  /* T80_MCode.vhd:1574:62  */
  assign n5294_o = n5291_o | n5293_o;
  /* T80_MCode.vhd:1574:73  */
  assign n5296_o = ir == 8'b00000100;
  /* T80_MCode.vhd:1574:73  */
  assign n5297_o = n5294_o | n5296_o;
  /* T80_MCode.vhd:1574:84  */
  assign n5299_o = ir == 8'b00000101;
  /* T80_MCode.vhd:1574:84  */
  assign n5300_o = n5297_o | n5299_o;
  /* T80_MCode.vhd:1574:95  */
  assign n5302_o = ir == 8'b00000110;
  /* T80_MCode.vhd:1574:95  */
  assign n5303_o = n5300_o | n5302_o;
  /* T80_MCode.vhd:1574:106  */
  assign n5305_o = ir == 8'b00000111;
  /* T80_MCode.vhd:1574:106  */
  assign n5306_o = n5303_o | n5305_o;
  /* T80_MCode.vhd:1575:33  */
  assign n5308_o = ir == 8'b00001000;
  /* T80_MCode.vhd:1575:33  */
  assign n5309_o = n5306_o | n5308_o;
  /* T80_MCode.vhd:1575:44  */
  assign n5311_o = ir == 8'b00001001;
  /* T80_MCode.vhd:1575:44  */
  assign n5312_o = n5309_o | n5311_o;
  /* T80_MCode.vhd:1575:55  */
  assign n5314_o = ir == 8'b00001010;
  /* T80_MCode.vhd:1575:55  */
  assign n5315_o = n5312_o | n5314_o;
  /* T80_MCode.vhd:1575:66  */
  assign n5317_o = ir == 8'b00001011;
  /* T80_MCode.vhd:1575:66  */
  assign n5318_o = n5315_o | n5317_o;
  /* T80_MCode.vhd:1575:77  */
  assign n5320_o = ir == 8'b00001100;
  /* T80_MCode.vhd:1575:77  */
  assign n5321_o = n5318_o | n5320_o;
  /* T80_MCode.vhd:1575:88  */
  assign n5323_o = ir == 8'b00001101;
  /* T80_MCode.vhd:1575:88  */
  assign n5324_o = n5321_o | n5323_o;
  /* T80_MCode.vhd:1575:99  */
  assign n5326_o = ir == 8'b00001110;
  /* T80_MCode.vhd:1575:99  */
  assign n5327_o = n5324_o | n5326_o;
  /* T80_MCode.vhd:1575:110  */
  assign n5329_o = ir == 8'b00001111;
  /* T80_MCode.vhd:1575:110  */
  assign n5330_o = n5327_o | n5329_o;
  /* T80_MCode.vhd:1576:33  */
  assign n5332_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1576:33  */
  assign n5333_o = n5330_o | n5332_o;
  /* T80_MCode.vhd:1576:44  */
  assign n5335_o = ir == 8'b00010001;
  /* T80_MCode.vhd:1576:44  */
  assign n5336_o = n5333_o | n5335_o;
  /* T80_MCode.vhd:1576:55  */
  assign n5338_o = ir == 8'b00010010;
  /* T80_MCode.vhd:1576:55  */
  assign n5339_o = n5336_o | n5338_o;
  /* T80_MCode.vhd:1576:66  */
  assign n5341_o = ir == 8'b00010011;
  /* T80_MCode.vhd:1576:66  */
  assign n5342_o = n5339_o | n5341_o;
  /* T80_MCode.vhd:1576:77  */
  assign n5344_o = ir == 8'b00010100;
  /* T80_MCode.vhd:1576:77  */
  assign n5345_o = n5342_o | n5344_o;
  /* T80_MCode.vhd:1576:88  */
  assign n5347_o = ir == 8'b00010101;
  /* T80_MCode.vhd:1576:88  */
  assign n5348_o = n5345_o | n5347_o;
  /* T80_MCode.vhd:1576:99  */
  assign n5350_o = ir == 8'b00010110;
  /* T80_MCode.vhd:1576:99  */
  assign n5351_o = n5348_o | n5350_o;
  /* T80_MCode.vhd:1576:110  */
  assign n5353_o = ir == 8'b00010111;
  /* T80_MCode.vhd:1576:110  */
  assign n5354_o = n5351_o | n5353_o;
  /* T80_MCode.vhd:1577:33  */
  assign n5356_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1577:33  */
  assign n5357_o = n5354_o | n5356_o;
  /* T80_MCode.vhd:1577:44  */
  assign n5359_o = ir == 8'b00011001;
  /* T80_MCode.vhd:1577:44  */
  assign n5360_o = n5357_o | n5359_o;
  /* T80_MCode.vhd:1577:55  */
  assign n5362_o = ir == 8'b00011010;
  /* T80_MCode.vhd:1577:55  */
  assign n5363_o = n5360_o | n5362_o;
  /* T80_MCode.vhd:1577:66  */
  assign n5365_o = ir == 8'b00011011;
  /* T80_MCode.vhd:1577:66  */
  assign n5366_o = n5363_o | n5365_o;
  /* T80_MCode.vhd:1577:77  */
  assign n5368_o = ir == 8'b00011100;
  /* T80_MCode.vhd:1577:77  */
  assign n5369_o = n5366_o | n5368_o;
  /* T80_MCode.vhd:1577:88  */
  assign n5371_o = ir == 8'b00011101;
  /* T80_MCode.vhd:1577:88  */
  assign n5372_o = n5369_o | n5371_o;
  /* T80_MCode.vhd:1577:99  */
  assign n5374_o = ir == 8'b00011110;
  /* T80_MCode.vhd:1577:99  */
  assign n5375_o = n5372_o | n5374_o;
  /* T80_MCode.vhd:1577:110  */
  assign n5377_o = ir == 8'b00011111;
  /* T80_MCode.vhd:1577:110  */
  assign n5378_o = n5375_o | n5377_o;
  /* T80_MCode.vhd:1578:33  */
  assign n5380_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1578:33  */
  assign n5381_o = n5378_o | n5380_o;
  /* T80_MCode.vhd:1578:44  */
  assign n5383_o = ir == 8'b00100001;
  /* T80_MCode.vhd:1578:44  */
  assign n5384_o = n5381_o | n5383_o;
  /* T80_MCode.vhd:1578:55  */
  assign n5386_o = ir == 8'b00100010;
  /* T80_MCode.vhd:1578:55  */
  assign n5387_o = n5384_o | n5386_o;
  /* T80_MCode.vhd:1578:66  */
  assign n5389_o = ir == 8'b00100011;
  /* T80_MCode.vhd:1578:66  */
  assign n5390_o = n5387_o | n5389_o;
  /* T80_MCode.vhd:1578:77  */
  assign n5392_o = ir == 8'b00100100;
  /* T80_MCode.vhd:1578:77  */
  assign n5393_o = n5390_o | n5392_o;
  /* T80_MCode.vhd:1578:88  */
  assign n5395_o = ir == 8'b00100101;
  /* T80_MCode.vhd:1578:88  */
  assign n5396_o = n5393_o | n5395_o;
  /* T80_MCode.vhd:1578:99  */
  assign n5398_o = ir == 8'b00100110;
  /* T80_MCode.vhd:1578:99  */
  assign n5399_o = n5396_o | n5398_o;
  /* T80_MCode.vhd:1578:110  */
  assign n5401_o = ir == 8'b00100111;
  /* T80_MCode.vhd:1578:110  */
  assign n5402_o = n5399_o | n5401_o;
  /* T80_MCode.vhd:1579:33  */
  assign n5404_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1579:33  */
  assign n5405_o = n5402_o | n5404_o;
  /* T80_MCode.vhd:1579:44  */
  assign n5407_o = ir == 8'b00101001;
  /* T80_MCode.vhd:1579:44  */
  assign n5408_o = n5405_o | n5407_o;
  /* T80_MCode.vhd:1579:55  */
  assign n5410_o = ir == 8'b00101010;
  /* T80_MCode.vhd:1579:55  */
  assign n5411_o = n5408_o | n5410_o;
  /* T80_MCode.vhd:1579:66  */
  assign n5413_o = ir == 8'b00101011;
  /* T80_MCode.vhd:1579:66  */
  assign n5414_o = n5411_o | n5413_o;
  /* T80_MCode.vhd:1579:77  */
  assign n5416_o = ir == 8'b00101100;
  /* T80_MCode.vhd:1579:77  */
  assign n5417_o = n5414_o | n5416_o;
  /* T80_MCode.vhd:1579:88  */
  assign n5419_o = ir == 8'b00101101;
  /* T80_MCode.vhd:1579:88  */
  assign n5420_o = n5417_o | n5419_o;
  /* T80_MCode.vhd:1579:99  */
  assign n5422_o = ir == 8'b00101110;
  /* T80_MCode.vhd:1579:99  */
  assign n5423_o = n5420_o | n5422_o;
  /* T80_MCode.vhd:1579:110  */
  assign n5425_o = ir == 8'b00101111;
  /* T80_MCode.vhd:1579:110  */
  assign n5426_o = n5423_o | n5425_o;
  /* T80_MCode.vhd:1580:33  */
  assign n5428_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1580:33  */
  assign n5429_o = n5426_o | n5428_o;
  /* T80_MCode.vhd:1580:44  */
  assign n5431_o = ir == 8'b00110001;
  /* T80_MCode.vhd:1580:44  */
  assign n5432_o = n5429_o | n5431_o;
  /* T80_MCode.vhd:1580:55  */
  assign n5434_o = ir == 8'b00110010;
  /* T80_MCode.vhd:1580:55  */
  assign n5435_o = n5432_o | n5434_o;
  /* T80_MCode.vhd:1580:66  */
  assign n5437_o = ir == 8'b00110011;
  /* T80_MCode.vhd:1580:66  */
  assign n5438_o = n5435_o | n5437_o;
  /* T80_MCode.vhd:1580:77  */
  assign n5440_o = ir == 8'b00110100;
  /* T80_MCode.vhd:1580:77  */
  assign n5441_o = n5438_o | n5440_o;
  /* T80_MCode.vhd:1580:88  */
  assign n5443_o = ir == 8'b00110101;
  /* T80_MCode.vhd:1580:88  */
  assign n5444_o = n5441_o | n5443_o;
  /* T80_MCode.vhd:1580:99  */
  assign n5446_o = ir == 8'b00110110;
  /* T80_MCode.vhd:1580:99  */
  assign n5447_o = n5444_o | n5446_o;
  /* T80_MCode.vhd:1580:110  */
  assign n5449_o = ir == 8'b00110111;
  /* T80_MCode.vhd:1580:110  */
  assign n5450_o = n5447_o | n5449_o;
  /* T80_MCode.vhd:1581:33  */
  assign n5452_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1581:33  */
  assign n5453_o = n5450_o | n5452_o;
  /* T80_MCode.vhd:1581:44  */
  assign n5455_o = ir == 8'b00111001;
  /* T80_MCode.vhd:1581:44  */
  assign n5456_o = n5453_o | n5455_o;
  /* T80_MCode.vhd:1581:55  */
  assign n5458_o = ir == 8'b00111010;
  /* T80_MCode.vhd:1581:55  */
  assign n5459_o = n5456_o | n5458_o;
  /* T80_MCode.vhd:1581:66  */
  assign n5461_o = ir == 8'b00111011;
  /* T80_MCode.vhd:1581:66  */
  assign n5462_o = n5459_o | n5461_o;
  /* T80_MCode.vhd:1581:77  */
  assign n5464_o = ir == 8'b00111100;
  /* T80_MCode.vhd:1581:77  */
  assign n5465_o = n5462_o | n5464_o;
  /* T80_MCode.vhd:1581:88  */
  assign n5467_o = ir == 8'b00111101;
  /* T80_MCode.vhd:1581:88  */
  assign n5468_o = n5465_o | n5467_o;
  /* T80_MCode.vhd:1581:99  */
  assign n5470_o = ir == 8'b00111110;
  /* T80_MCode.vhd:1581:99  */
  assign n5471_o = n5468_o | n5470_o;
  /* T80_MCode.vhd:1581:110  */
  assign n5473_o = ir == 8'b00111111;
  /* T80_MCode.vhd:1581:110  */
  assign n5474_o = n5471_o | n5473_o;
  /* T80_MCode.vhd:1584:33  */
  assign n5476_o = ir == 8'b10000000;
  /* T80_MCode.vhd:1584:33  */
  assign n5477_o = n5474_o | n5476_o;
  /* T80_MCode.vhd:1584:44  */
  assign n5479_o = ir == 8'b10000001;
  /* T80_MCode.vhd:1584:44  */
  assign n5480_o = n5477_o | n5479_o;
  /* T80_MCode.vhd:1584:55  */
  assign n5482_o = ir == 8'b10000010;
  /* T80_MCode.vhd:1584:55  */
  assign n5483_o = n5480_o | n5482_o;
  /* T80_MCode.vhd:1584:66  */
  assign n5485_o = ir == 8'b10000011;
  /* T80_MCode.vhd:1584:66  */
  assign n5486_o = n5483_o | n5485_o;
  /* T80_MCode.vhd:1584:77  */
  assign n5488_o = ir == 8'b10000100;
  /* T80_MCode.vhd:1584:77  */
  assign n5489_o = n5486_o | n5488_o;
  /* T80_MCode.vhd:1584:88  */
  assign n5491_o = ir == 8'b10000101;
  /* T80_MCode.vhd:1584:88  */
  assign n5492_o = n5489_o | n5491_o;
  /* T80_MCode.vhd:1584:99  */
  assign n5494_o = ir == 8'b10000110;
  /* T80_MCode.vhd:1584:99  */
  assign n5495_o = n5492_o | n5494_o;
  /* T80_MCode.vhd:1584:110  */
  assign n5497_o = ir == 8'b10000111;
  /* T80_MCode.vhd:1584:110  */
  assign n5498_o = n5495_o | n5497_o;
  /* T80_MCode.vhd:1585:33  */
  assign n5500_o = ir == 8'b10001000;
  /* T80_MCode.vhd:1585:33  */
  assign n5501_o = n5498_o | n5500_o;
  /* T80_MCode.vhd:1585:44  */
  assign n5503_o = ir == 8'b10001001;
  /* T80_MCode.vhd:1585:44  */
  assign n5504_o = n5501_o | n5503_o;
  /* T80_MCode.vhd:1585:55  */
  assign n5506_o = ir == 8'b10001010;
  /* T80_MCode.vhd:1585:55  */
  assign n5507_o = n5504_o | n5506_o;
  /* T80_MCode.vhd:1585:66  */
  assign n5509_o = ir == 8'b10001011;
  /* T80_MCode.vhd:1585:66  */
  assign n5510_o = n5507_o | n5509_o;
  /* T80_MCode.vhd:1585:77  */
  assign n5512_o = ir == 8'b10001100;
  /* T80_MCode.vhd:1585:77  */
  assign n5513_o = n5510_o | n5512_o;
  /* T80_MCode.vhd:1585:88  */
  assign n5515_o = ir == 8'b10001101;
  /* T80_MCode.vhd:1585:88  */
  assign n5516_o = n5513_o | n5515_o;
  /* T80_MCode.vhd:1585:99  */
  assign n5518_o = ir == 8'b10001110;
  /* T80_MCode.vhd:1585:99  */
  assign n5519_o = n5516_o | n5518_o;
  /* T80_MCode.vhd:1585:110  */
  assign n5521_o = ir == 8'b10001111;
  /* T80_MCode.vhd:1585:110  */
  assign n5522_o = n5519_o | n5521_o;
  /* T80_MCode.vhd:1586:33  */
  assign n5524_o = ir == 8'b10010000;
  /* T80_MCode.vhd:1586:33  */
  assign n5525_o = n5522_o | n5524_o;
  /* T80_MCode.vhd:1586:44  */
  assign n5527_o = ir == 8'b10010001;
  /* T80_MCode.vhd:1586:44  */
  assign n5528_o = n5525_o | n5527_o;
  /* T80_MCode.vhd:1586:55  */
  assign n5530_o = ir == 8'b10010010;
  /* T80_MCode.vhd:1586:55  */
  assign n5531_o = n5528_o | n5530_o;
  /* T80_MCode.vhd:1586:66  */
  assign n5533_o = ir == 8'b10010011;
  /* T80_MCode.vhd:1586:66  */
  assign n5534_o = n5531_o | n5533_o;
  /* T80_MCode.vhd:1586:77  */
  assign n5536_o = ir == 8'b10010100;
  /* T80_MCode.vhd:1586:77  */
  assign n5537_o = n5534_o | n5536_o;
  /* T80_MCode.vhd:1586:88  */
  assign n5539_o = ir == 8'b10010101;
  /* T80_MCode.vhd:1586:88  */
  assign n5540_o = n5537_o | n5539_o;
  /* T80_MCode.vhd:1586:99  */
  assign n5542_o = ir == 8'b10010110;
  /* T80_MCode.vhd:1586:99  */
  assign n5543_o = n5540_o | n5542_o;
  /* T80_MCode.vhd:1586:110  */
  assign n5545_o = ir == 8'b10010111;
  /* T80_MCode.vhd:1586:110  */
  assign n5546_o = n5543_o | n5545_o;
  /* T80_MCode.vhd:1587:33  */
  assign n5548_o = ir == 8'b10011000;
  /* T80_MCode.vhd:1587:33  */
  assign n5549_o = n5546_o | n5548_o;
  /* T80_MCode.vhd:1587:44  */
  assign n5551_o = ir == 8'b10011001;
  /* T80_MCode.vhd:1587:44  */
  assign n5552_o = n5549_o | n5551_o;
  /* T80_MCode.vhd:1587:55  */
  assign n5554_o = ir == 8'b10011010;
  /* T80_MCode.vhd:1587:55  */
  assign n5555_o = n5552_o | n5554_o;
  /* T80_MCode.vhd:1587:66  */
  assign n5557_o = ir == 8'b10011011;
  /* T80_MCode.vhd:1587:66  */
  assign n5558_o = n5555_o | n5557_o;
  /* T80_MCode.vhd:1587:77  */
  assign n5560_o = ir == 8'b10011100;
  /* T80_MCode.vhd:1587:77  */
  assign n5561_o = n5558_o | n5560_o;
  /* T80_MCode.vhd:1587:88  */
  assign n5563_o = ir == 8'b10011101;
  /* T80_MCode.vhd:1587:88  */
  assign n5564_o = n5561_o | n5563_o;
  /* T80_MCode.vhd:1587:99  */
  assign n5566_o = ir == 8'b10011110;
  /* T80_MCode.vhd:1587:99  */
  assign n5567_o = n5564_o | n5566_o;
  /* T80_MCode.vhd:1587:110  */
  assign n5569_o = ir == 8'b10011111;
  /* T80_MCode.vhd:1587:110  */
  assign n5570_o = n5567_o | n5569_o;
  /* T80_MCode.vhd:1588:33  */
  assign n5572_o = ir == 8'b10100100;
  /* T80_MCode.vhd:1588:33  */
  assign n5573_o = n5570_o | n5572_o;
  /* T80_MCode.vhd:1588:88  */
  assign n5575_o = ir == 8'b10100101;
  /* T80_MCode.vhd:1588:88  */
  assign n5576_o = n5573_o | n5575_o;
  /* T80_MCode.vhd:1588:99  */
  assign n5578_o = ir == 8'b10100110;
  /* T80_MCode.vhd:1588:99  */
  assign n5579_o = n5576_o | n5578_o;
  /* T80_MCode.vhd:1588:110  */
  assign n5581_o = ir == 8'b10100111;
  /* T80_MCode.vhd:1588:110  */
  assign n5582_o = n5579_o | n5581_o;
  /* T80_MCode.vhd:1589:33  */
  assign n5584_o = ir == 8'b10101100;
  /* T80_MCode.vhd:1589:33  */
  assign n5585_o = n5582_o | n5584_o;
  /* T80_MCode.vhd:1589:88  */
  assign n5587_o = ir == 8'b10101101;
  /* T80_MCode.vhd:1589:88  */
  assign n5588_o = n5585_o | n5587_o;
  /* T80_MCode.vhd:1589:99  */
  assign n5590_o = ir == 8'b10101110;
  /* T80_MCode.vhd:1589:99  */
  assign n5591_o = n5588_o | n5590_o;
  /* T80_MCode.vhd:1589:110  */
  assign n5593_o = ir == 8'b10101111;
  /* T80_MCode.vhd:1589:110  */
  assign n5594_o = n5591_o | n5593_o;
  /* T80_MCode.vhd:1590:33  */
  assign n5596_o = ir == 8'b10110100;
  /* T80_MCode.vhd:1590:33  */
  assign n5597_o = n5594_o | n5596_o;
  /* T80_MCode.vhd:1590:88  */
  assign n5599_o = ir == 8'b10110101;
  /* T80_MCode.vhd:1590:88  */
  assign n5600_o = n5597_o | n5599_o;
  /* T80_MCode.vhd:1590:99  */
  assign n5602_o = ir == 8'b10110110;
  /* T80_MCode.vhd:1590:99  */
  assign n5603_o = n5600_o | n5602_o;
  /* T80_MCode.vhd:1590:110  */
  assign n5605_o = ir == 8'b10110111;
  /* T80_MCode.vhd:1590:110  */
  assign n5606_o = n5603_o | n5605_o;
  /* T80_MCode.vhd:1591:33  */
  assign n5608_o = ir == 8'b10111100;
  /* T80_MCode.vhd:1591:33  */
  assign n5609_o = n5606_o | n5608_o;
  /* T80_MCode.vhd:1591:88  */
  assign n5611_o = ir == 8'b10111101;
  /* T80_MCode.vhd:1591:88  */
  assign n5612_o = n5609_o | n5611_o;
  /* T80_MCode.vhd:1591:99  */
  assign n5614_o = ir == 8'b10111110;
  /* T80_MCode.vhd:1591:99  */
  assign n5615_o = n5612_o | n5614_o;
  /* T80_MCode.vhd:1591:110  */
  assign n5617_o = ir == 8'b10111111;
  /* T80_MCode.vhd:1591:110  */
  assign n5618_o = n5615_o | n5617_o;
  /* T80_MCode.vhd:1592:33  */
  assign n5620_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1592:33  */
  assign n5621_o = n5618_o | n5620_o;
  /* T80_MCode.vhd:1592:44  */
  assign n5623_o = ir == 8'b11000001;
  /* T80_MCode.vhd:1592:44  */
  assign n5624_o = n5621_o | n5623_o;
  /* T80_MCode.vhd:1592:55  */
  assign n5626_o = ir == 8'b11000010;
  /* T80_MCode.vhd:1592:55  */
  assign n5627_o = n5624_o | n5626_o;
  /* T80_MCode.vhd:1592:66  */
  assign n5629_o = ir == 8'b11000011;
  /* T80_MCode.vhd:1592:66  */
  assign n5630_o = n5627_o | n5629_o;
  /* T80_MCode.vhd:1592:77  */
  assign n5632_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1592:77  */
  assign n5633_o = n5630_o | n5632_o;
  /* T80_MCode.vhd:1592:88  */
  assign n5635_o = ir == 8'b11000101;
  /* T80_MCode.vhd:1592:88  */
  assign n5636_o = n5633_o | n5635_o;
  /* T80_MCode.vhd:1592:99  */
  assign n5638_o = ir == 8'b11000110;
  /* T80_MCode.vhd:1592:99  */
  assign n5639_o = n5636_o | n5638_o;
  /* T80_MCode.vhd:1592:110  */
  assign n5641_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1592:110  */
  assign n5642_o = n5639_o | n5641_o;
  /* T80_MCode.vhd:1593:33  */
  assign n5644_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1593:33  */
  assign n5645_o = n5642_o | n5644_o;
  /* T80_MCode.vhd:1593:44  */
  assign n5647_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1593:44  */
  assign n5648_o = n5645_o | n5647_o;
  /* T80_MCode.vhd:1593:55  */
  assign n5650_o = ir == 8'b11001010;
  /* T80_MCode.vhd:1593:55  */
  assign n5651_o = n5648_o | n5650_o;
  /* T80_MCode.vhd:1593:66  */
  assign n5653_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1593:66  */
  assign n5654_o = n5651_o | n5653_o;
  /* T80_MCode.vhd:1593:77  */
  assign n5656_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1593:77  */
  assign n5657_o = n5654_o | n5656_o;
  /* T80_MCode.vhd:1593:88  */
  assign n5659_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1593:88  */
  assign n5660_o = n5657_o | n5659_o;
  /* T80_MCode.vhd:1593:99  */
  assign n5662_o = ir == 8'b11001110;
  /* T80_MCode.vhd:1593:99  */
  assign n5663_o = n5660_o | n5662_o;
  /* T80_MCode.vhd:1593:110  */
  assign n5665_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1593:110  */
  assign n5666_o = n5663_o | n5665_o;
  /* T80_MCode.vhd:1594:33  */
  assign n5668_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1594:33  */
  assign n5669_o = n5666_o | n5668_o;
  /* T80_MCode.vhd:1594:44  */
  assign n5671_o = ir == 8'b11010001;
  /* T80_MCode.vhd:1594:44  */
  assign n5672_o = n5669_o | n5671_o;
  /* T80_MCode.vhd:1594:55  */
  assign n5674_o = ir == 8'b11010010;
  /* T80_MCode.vhd:1594:55  */
  assign n5675_o = n5672_o | n5674_o;
  /* T80_MCode.vhd:1594:66  */
  assign n5677_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1594:66  */
  assign n5678_o = n5675_o | n5677_o;
  /* T80_MCode.vhd:1594:77  */
  assign n5680_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1594:77  */
  assign n5681_o = n5678_o | n5680_o;
  /* T80_MCode.vhd:1594:88  */
  assign n5683_o = ir == 8'b11010101;
  /* T80_MCode.vhd:1594:88  */
  assign n5684_o = n5681_o | n5683_o;
  /* T80_MCode.vhd:1594:99  */
  assign n5686_o = ir == 8'b11010110;
  /* T80_MCode.vhd:1594:99  */
  assign n5687_o = n5684_o | n5686_o;
  /* T80_MCode.vhd:1594:110  */
  assign n5689_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1594:110  */
  assign n5690_o = n5687_o | n5689_o;
  /* T80_MCode.vhd:1595:33  */
  assign n5692_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1595:33  */
  assign n5693_o = n5690_o | n5692_o;
  /* T80_MCode.vhd:1595:44  */
  assign n5695_o = ir == 8'b11011001;
  /* T80_MCode.vhd:1595:44  */
  assign n5696_o = n5693_o | n5695_o;
  /* T80_MCode.vhd:1595:55  */
  assign n5698_o = ir == 8'b11011010;
  /* T80_MCode.vhd:1595:55  */
  assign n5699_o = n5696_o | n5698_o;
  /* T80_MCode.vhd:1595:66  */
  assign n5701_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1595:66  */
  assign n5702_o = n5699_o | n5701_o;
  /* T80_MCode.vhd:1595:77  */
  assign n5704_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1595:77  */
  assign n5705_o = n5702_o | n5704_o;
  /* T80_MCode.vhd:1595:88  */
  assign n5707_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1595:88  */
  assign n5708_o = n5705_o | n5707_o;
  /* T80_MCode.vhd:1595:99  */
  assign n5710_o = ir == 8'b11011110;
  /* T80_MCode.vhd:1595:99  */
  assign n5711_o = n5708_o | n5710_o;
  /* T80_MCode.vhd:1595:110  */
  assign n5713_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1595:110  */
  assign n5714_o = n5711_o | n5713_o;
  /* T80_MCode.vhd:1596:33  */
  assign n5716_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1596:33  */
  assign n5717_o = n5714_o | n5716_o;
  /* T80_MCode.vhd:1596:44  */
  assign n5719_o = ir == 8'b11100001;
  /* T80_MCode.vhd:1596:44  */
  assign n5720_o = n5717_o | n5719_o;
  /* T80_MCode.vhd:1596:55  */
  assign n5722_o = ir == 8'b11100010;
  /* T80_MCode.vhd:1596:55  */
  assign n5723_o = n5720_o | n5722_o;
  /* T80_MCode.vhd:1596:66  */
  assign n5725_o = ir == 8'b11100011;
  /* T80_MCode.vhd:1596:66  */
  assign n5726_o = n5723_o | n5725_o;
  /* T80_MCode.vhd:1596:77  */
  assign n5728_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1596:77  */
  assign n5729_o = n5726_o | n5728_o;
  /* T80_MCode.vhd:1596:88  */
  assign n5731_o = ir == 8'b11100101;
  /* T80_MCode.vhd:1596:88  */
  assign n5732_o = n5729_o | n5731_o;
  /* T80_MCode.vhd:1596:99  */
  assign n5734_o = ir == 8'b11100110;
  /* T80_MCode.vhd:1596:99  */
  assign n5735_o = n5732_o | n5734_o;
  /* T80_MCode.vhd:1596:110  */
  assign n5737_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1596:110  */
  assign n5738_o = n5735_o | n5737_o;
  /* T80_MCode.vhd:1597:33  */
  assign n5740_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1597:33  */
  assign n5741_o = n5738_o | n5740_o;
  /* T80_MCode.vhd:1597:44  */
  assign n5743_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1597:44  */
  assign n5744_o = n5741_o | n5743_o;
  /* T80_MCode.vhd:1597:55  */
  assign n5746_o = ir == 8'b11101010;
  /* T80_MCode.vhd:1597:55  */
  assign n5747_o = n5744_o | n5746_o;
  /* T80_MCode.vhd:1597:66  */
  assign n5749_o = ir == 8'b11101011;
  /* T80_MCode.vhd:1597:66  */
  assign n5750_o = n5747_o | n5749_o;
  /* T80_MCode.vhd:1597:77  */
  assign n5752_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1597:77  */
  assign n5753_o = n5750_o | n5752_o;
  /* T80_MCode.vhd:1597:88  */
  assign n5755_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1597:88  */
  assign n5756_o = n5753_o | n5755_o;
  /* T80_MCode.vhd:1597:99  */
  assign n5758_o = ir == 8'b11101110;
  /* T80_MCode.vhd:1597:99  */
  assign n5759_o = n5756_o | n5758_o;
  /* T80_MCode.vhd:1597:110  */
  assign n5761_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1597:110  */
  assign n5762_o = n5759_o | n5761_o;
  /* T80_MCode.vhd:1598:33  */
  assign n5764_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1598:33  */
  assign n5765_o = n5762_o | n5764_o;
  /* T80_MCode.vhd:1598:44  */
  assign n5767_o = ir == 8'b11110001;
  /* T80_MCode.vhd:1598:44  */
  assign n5768_o = n5765_o | n5767_o;
  /* T80_MCode.vhd:1598:55  */
  assign n5770_o = ir == 8'b11110010;
  /* T80_MCode.vhd:1598:55  */
  assign n5771_o = n5768_o | n5770_o;
  /* T80_MCode.vhd:1598:66  */
  assign n5773_o = ir == 8'b11110011;
  /* T80_MCode.vhd:1598:66  */
  assign n5774_o = n5771_o | n5773_o;
  /* T80_MCode.vhd:1598:77  */
  assign n5776_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1598:77  */
  assign n5777_o = n5774_o | n5776_o;
  /* T80_MCode.vhd:1598:88  */
  assign n5779_o = ir == 8'b11110101;
  /* T80_MCode.vhd:1598:88  */
  assign n5780_o = n5777_o | n5779_o;
  /* T80_MCode.vhd:1598:99  */
  assign n5782_o = ir == 8'b11110110;
  /* T80_MCode.vhd:1598:99  */
  assign n5783_o = n5780_o | n5782_o;
  /* T80_MCode.vhd:1598:110  */
  assign n5785_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1598:110  */
  assign n5786_o = n5783_o | n5785_o;
  /* T80_MCode.vhd:1599:33  */
  assign n5788_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1599:33  */
  assign n5789_o = n5786_o | n5788_o;
  /* T80_MCode.vhd:1599:44  */
  assign n5791_o = ir == 8'b11111001;
  /* T80_MCode.vhd:1599:44  */
  assign n5792_o = n5789_o | n5791_o;
  /* T80_MCode.vhd:1599:55  */
  assign n5794_o = ir == 8'b11111010;
  /* T80_MCode.vhd:1599:55  */
  assign n5795_o = n5792_o | n5794_o;
  /* T80_MCode.vhd:1599:66  */
  assign n5797_o = ir == 8'b11111011;
  /* T80_MCode.vhd:1599:66  */
  assign n5798_o = n5795_o | n5797_o;
  /* T80_MCode.vhd:1599:77  */
  assign n5800_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1599:77  */
  assign n5801_o = n5798_o | n5800_o;
  /* T80_MCode.vhd:1599:88  */
  assign n5803_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1599:88  */
  assign n5804_o = n5801_o | n5803_o;
  /* T80_MCode.vhd:1599:99  */
  assign n5806_o = ir == 8'b11111110;
  /* T80_MCode.vhd:1599:99  */
  assign n5807_o = n5804_o | n5806_o;
  /* T80_MCode.vhd:1599:110  */
  assign n5809_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1599:110  */
  assign n5810_o = n5807_o | n5809_o;
  /* T80_MCode.vhd:1601:25  */
  assign n5812_o = ir == 8'b01111110;
  /* T80_MCode.vhd:1601:40  */
  assign n5814_o = ir == 8'b01111111;
  /* T80_MCode.vhd:1601:40  */
  assign n5815_o = n5812_o | n5814_o;
  /* T80_MCode.vhd:1605:25  */
  assign n5817_o = ir == 8'b01010111;
  /* T80_MCode.vhd:1609:25  */
  assign n5819_o = ir == 8'b01011111;
  /* T80_MCode.vhd:1613:25  */
  assign n5821_o = ir == 8'b01000111;
  /* T80_MCode.vhd:1617:25  */
  assign n5823_o = ir == 8'b01001111;
  /* T80_MCode.vhd:1625:38  */
  assign n5824_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1626:33  */
  assign n5826_o = n5824_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1629:33  */
  assign n5828_o = n5824_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1635:46  */
  assign n5829_o = ir[5:4];
  /* T80_MCode.vhd:1635:59  */
  assign n5831_o = n5829_o == 2'b11;
  /* T80_MCode.vhd:1638:78  */
  assign n5832_o = ir[5:4];
  assign n5834_o = {n5832_o, 1'b1};
  /* T80_MCode.vhd:1635:41  */
  assign n5836_o = n5831_o ? 3'b000 : n5834_o;
  /* T80_MCode.vhd:1635:41  */
  assign n5839_o = n5831_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1633:33  */
  assign n5841_o = n5824_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1645:46  */
  assign n5842_o = ir[5:4];
  /* T80_MCode.vhd:1645:59  */
  assign n5844_o = n5842_o == 2'b11;
  /* T80_MCode.vhd:1648:78  */
  assign n5845_o = ir[5:4];
  assign n5847_o = {n5845_o, 1'b0};
  /* T80_MCode.vhd:1645:41  */
  assign n5849_o = n5844_o ? 3'b001 : n5847_o;
  /* T80_MCode.vhd:1645:41  */
  assign n5852_o = n5844_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1643:33  */
  assign n5854_o = n5824_o == 31'b0000000000000000000000000000101;
  assign n5855_o = {n5854_o, n5841_o, n5828_o, n5826_o};
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5859_o = 1'b0;
      4'b0100: n5859_o = 1'b0;
      4'b0010: n5859_o = 1'b1;
      4'b0001: n5859_o = 1'b1;
      default: n5859_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5862_o = 1'b0;
      4'b0100: n5862_o = 1'b1;
      4'b0010: n5862_o = 1'b0;
      4'b0001: n5862_o = 1'b0;
      default: n5862_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5866_o = 1'b1;
      4'b0100: n5866_o = 1'b1;
      4'b0010: n5866_o = 1'b0;
      4'b0001: n5866_o = 1'b0;
      default: n5866_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5868_o = n5849_o;
      4'b0100: n5868_o = n5836_o;
      4'b0010: n5868_o = 3'b000;
      4'b0001: n5868_o = 3'b000;
      default: n5868_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5870_o = n5852_o;
      4'b0100: n5870_o = n5839_o;
      4'b0010: n5870_o = 1'b0;
      4'b0001: n5870_o = 1'b0;
      default: n5870_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5874_o = 3'b111;
      4'b0100: n5874_o = 3'b110;
      4'b0010: n5874_o = 3'b110;
      4'b0001: n5874_o = 3'b111;
      default: n5874_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5877_o = 1'b0;
      4'b0100: n5877_o = 1'b0;
      4'b0010: n5877_o = 1'b0;
      4'b0001: n5877_o = 1'b1;
      default: n5877_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5880_o = 1'b0;
      4'b0100: n5880_o = 1'b0;
      4'b0010: n5880_o = 1'b1;
      4'b0001: n5880_o = 1'b0;
      default: n5880_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1622:25  */
  assign n5882_o = ir == 8'b01001011;
  /* T80_MCode.vhd:1622:40  */
  assign n5884_o = ir == 8'b01011011;
  /* T80_MCode.vhd:1622:40  */
  assign n5885_o = n5882_o | n5884_o;
  /* T80_MCode.vhd:1622:51  */
  assign n5887_o = ir == 8'b01101011;
  /* T80_MCode.vhd:1622:51  */
  assign n5888_o = n5885_o | n5887_o;
  /* T80_MCode.vhd:1622:62  */
  assign n5890_o = ir == 8'b01111011;
  /* T80_MCode.vhd:1622:62  */
  assign n5891_o = n5888_o | n5890_o;
  /* T80_MCode.vhd:1656:38  */
  assign n5892_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1657:33  */
  assign n5894_o = n5892_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1664:46  */
  assign n5895_o = ir[5:4];
  /* T80_MCode.vhd:1664:59  */
  assign n5897_o = n5895_o == 2'b11;
  /* T80_MCode.vhd:1667:78  */
  assign n5898_o = ir[5:4];
  assign n5901_o = {1'b0, n5898_o, 1'b1};
  /* T80_MCode.vhd:1664:41  */
  assign n5903_o = n5897_o ? 4'b1000 : n5901_o;
  /* T80_MCode.vhd:1660:33  */
  assign n5905_o = n5892_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1675:46  */
  assign n5906_o = ir[5:4];
  /* T80_MCode.vhd:1675:59  */
  assign n5908_o = n5906_o == 2'b11;
  /* T80_MCode.vhd:1678:78  */
  assign n5909_o = ir[5:4];
  assign n5912_o = {1'b0, n5909_o, 1'b0};
  /* T80_MCode.vhd:1675:41  */
  assign n5914_o = n5908_o ? 4'b1001 : n5912_o;
  /* T80_MCode.vhd:1671:33  */
  assign n5916_o = n5892_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1682:33  */
  assign n5918_o = n5892_o == 31'b0000000000000000000000000000101;
  assign n5919_o = {n5918_o, n5916_o, n5905_o, n5894_o};
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5923_o = 1'b0;
      4'b0100: n5923_o = 1'b0;
      4'b0010: n5923_o = 1'b1;
      4'b0001: n5923_o = 1'b1;
      default: n5923_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5926_o = 1'b0;
      4'b0100: n5926_o = 1'b1;
      4'b0010: n5926_o = 1'b0;
      4'b0001: n5926_o = 1'b0;
      default: n5926_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5928_o = 4'b0000;
      4'b0100: n5928_o = n5914_o;
      4'b0010: n5928_o = n5903_o;
      4'b0001: n5928_o = 4'b0000;
      default: n5928_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5932_o = 3'b111;
      4'b0100: n5932_o = 3'b110;
      4'b0010: n5932_o = 3'b110;
      4'b0001: n5932_o = 3'b111;
      default: n5932_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5935_o = 1'b0;
      4'b0100: n5935_o = 1'b0;
      4'b0010: n5935_o = 1'b0;
      4'b0001: n5935_o = 1'b1;
      default: n5935_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5938_o = 1'b0;
      4'b0100: n5938_o = 1'b0;
      4'b0010: n5938_o = 1'b1;
      4'b0001: n5938_o = 1'b0;
      default: n5938_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5942_o = 1'b1;
      4'b0100: n5942_o = 1'b1;
      4'b0010: n5942_o = 1'b0;
      4'b0001: n5942_o = 1'b0;
      default: n5942_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1653:25  */
  assign n5944_o = ir == 8'b01000011;
  /* T80_MCode.vhd:1653:40  */
  assign n5946_o = ir == 8'b01010011;
  /* T80_MCode.vhd:1653:40  */
  assign n5947_o = n5944_o | n5946_o;
  /* T80_MCode.vhd:1653:51  */
  assign n5949_o = ir == 8'b01100011;
  /* T80_MCode.vhd:1653:51  */
  assign n5950_o = n5947_o | n5949_o;
  /* T80_MCode.vhd:1653:62  */
  assign n5952_o = ir == 8'b01110011;
  /* T80_MCode.vhd:1653:62  */
  assign n5953_o = n5950_o | n5952_o;
  /* T80_MCode.vhd:1689:38  */
  assign n5954_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1690:33  */
  assign n5956_o = n5954_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1698:46  */
  assign n5958_o = ir[3];
  /* T80_MCode.vhd:1698:50  */
  assign n5959_o = ~n5958_o;
  /* T80_MCode.vhd:1698:41  */
  assign n5962_o = n5959_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1693:33  */
  assign n5964_o = n5954_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1707:46  */
  assign n5965_o = ir[3];
  /* T80_MCode.vhd:1707:50  */
  assign n5966_o = ~n5965_o;
  /* T80_MCode.vhd:1707:41  */
  assign n5969_o = n5966_o ? 4'b0101 : 4'b1101;
  /* T80_MCode.vhd:1703:33  */
  assign n5971_o = n5954_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1712:33  */
  assign n5973_o = n5954_o == 31'b0000000000000000000000000000100;
  assign n5974_o = {n5973_o, n5971_o, n5964_o, n5956_o};
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5977_o = 3'b101;
      4'b0100: n5977_o = 3'b101;
      4'b0010: n5977_o = n2179_o;
      4'b0001: n5977_o = n2179_o;
      default: n5977_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5980_o = 4'b0000;
      4'b0100: n5980_o = n5969_o;
      4'b0010: n5980_o = n5962_o;
      4'b0001: n5980_o = 4'b1100;
      default: n5980_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5982_o = 3'b000;
      4'b0100: n5982_o = 3'b000;
      4'b0010: n5982_o = 3'b111;
      4'b0001: n5982_o = 3'b000;
      default: n5982_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5985_o = 4'b0000;
      4'b0100: n5985_o = 4'b0000;
      4'b0010: n5985_o = 4'b0110;
      4'b0001: n5985_o = 4'b0000;
      default: n5985_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5987_o = n2182_o;
      4'b0100: n5987_o = n2182_o;
      4'b0010: n5987_o = 4'b0000;
      4'b0001: n5987_o = n2182_o;
      default: n5987_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5991_o = 3'b111;
      4'b0100: n5991_o = 3'b111;
      4'b0010: n5991_o = 3'b001;
      4'b0001: n5991_o = 3'b010;
      default: n5991_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5994_o = 1'b0;
      4'b0100: n5994_o = 1'b1;
      4'b0010: n5994_o = 1'b0;
      4'b0001: n5994_o = 1'b0;
      default: n5994_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5997_o = 1'b1;
      4'b0100: n5997_o = 1'b0;
      4'b0010: n5997_o = 1'b0;
      4'b0001: n5997_o = 1'b0;
      default: n5997_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n6000_o = 1'b0;
      4'b0100: n6000_o = 1'b1;
      4'b0010: n6000_o = 1'b0;
      4'b0001: n6000_o = 1'b0;
      default: n6000_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1686:25  */
  assign n6002_o = ir == 8'b10100000;
  /* T80_MCode.vhd:1686:41  */
  assign n6004_o = ir == 8'b10101000;
  /* T80_MCode.vhd:1686:41  */
  assign n6005_o = n6002_o | n6004_o;
  /* T80_MCode.vhd:1686:54  */
  assign n6007_o = ir == 8'b10110000;
  /* T80_MCode.vhd:1686:54  */
  assign n6008_o = n6005_o | n6007_o;
  /* T80_MCode.vhd:1686:67  */
  assign n6010_o = ir == 8'b10111000;
  /* T80_MCode.vhd:1686:67  */
  assign n6011_o = n6008_o | n6010_o;
  /* T80_MCode.vhd:1720:38  */
  assign n6012_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1721:33  */
  assign n6014_o = n6012_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1730:46  */
  assign n6016_o = ir[3];
  /* T80_MCode.vhd:1730:50  */
  assign n6017_o = ~n6016_o;
  /* T80_MCode.vhd:1730:41  */
  assign n6020_o = n6017_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1724:33  */
  assign n6022_o = n6012_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1735:33  */
  assign n6024_o = n6012_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1739:33  */
  assign n6026_o = n6012_o == 31'b0000000000000000000000000000100;
  assign n6027_o = {n6026_o, n6024_o, n6022_o, n6014_o};
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6030_o = 3'b101;
      4'b0100: n6030_o = 3'b101;
      4'b0010: n6030_o = n2179_o;
      4'b0001: n6030_o = n2179_o;
      default: n6030_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6033_o = 4'b0000;
      4'b0100: n6033_o = 4'b0000;
      4'b0010: n6033_o = n6020_o;
      4'b0001: n6033_o = 4'b1100;
      default: n6033_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6035_o = 3'b000;
      4'b0100: n6035_o = 3'b000;
      4'b0010: n6035_o = 3'b111;
      4'b0001: n6035_o = 3'b000;
      default: n6035_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6038_o = 4'b0000;
      4'b0100: n6038_o = 4'b0000;
      4'b0010: n6038_o = 4'b0110;
      4'b0001: n6038_o = 4'b0000;
      default: n6038_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6040_o = n2182_o;
      4'b0100: n6040_o = n2182_o;
      4'b0010: n6040_o = 4'b0111;
      4'b0001: n6040_o = n2182_o;
      default: n6040_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6043_o = 1'b0;
      4'b0100: n6043_o = 1'b0;
      4'b0010: n6043_o = 1'b1;
      4'b0001: n6043_o = 1'b0;
      default: n6043_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6046_o = 1'b0;
      4'b0100: n6046_o = 1'b0;
      4'b0010: n6046_o = 1'b1;
      4'b0001: n6046_o = 1'b0;
      default: n6046_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6049_o = 3'b111;
      4'b0100: n6049_o = 3'b111;
      4'b0010: n6049_o = 3'b111;
      4'b0001: n6049_o = 3'b010;
      default: n6049_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6052_o = 1'b0;
      4'b0100: n6052_o = 1'b1;
      4'b0010: n6052_o = 1'b0;
      4'b0001: n6052_o = 1'b0;
      default: n6052_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6056_o = 1'b1;
      4'b0100: n6056_o = 1'b1;
      4'b0010: n6056_o = 1'b0;
      4'b0001: n6056_o = 1'b0;
      default: n6056_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1717:25  */
  assign n6058_o = ir == 8'b10100001;
  /* T80_MCode.vhd:1717:41  */
  assign n6060_o = ir == 8'b10101001;
  /* T80_MCode.vhd:1717:41  */
  assign n6061_o = n6058_o | n6060_o;
  /* T80_MCode.vhd:1717:54  */
  assign n6063_o = ir == 8'b10110001;
  /* T80_MCode.vhd:1717:54  */
  assign n6064_o = n6061_o | n6063_o;
  /* T80_MCode.vhd:1717:67  */
  assign n6066_o = ir == 8'b10111001;
  /* T80_MCode.vhd:1717:67  */
  assign n6067_o = n6064_o | n6066_o;
  /* T80_MCode.vhd:1744:25  */
  assign n6069_o = ir == 8'b01000100;
  /* T80_MCode.vhd:1744:40  */
  assign n6071_o = ir == 8'b01001100;
  /* T80_MCode.vhd:1744:40  */
  assign n6072_o = n6069_o | n6071_o;
  /* T80_MCode.vhd:1744:51  */
  assign n6074_o = ir == 8'b01010100;
  /* T80_MCode.vhd:1744:51  */
  assign n6075_o = n6072_o | n6074_o;
  /* T80_MCode.vhd:1744:62  */
  assign n6077_o = ir == 8'b01011100;
  /* T80_MCode.vhd:1744:62  */
  assign n6078_o = n6075_o | n6077_o;
  /* T80_MCode.vhd:1744:73  */
  assign n6080_o = ir == 8'b01100100;
  /* T80_MCode.vhd:1744:73  */
  assign n6081_o = n6078_o | n6080_o;
  /* T80_MCode.vhd:1744:84  */
  assign n6083_o = ir == 8'b01101100;
  /* T80_MCode.vhd:1744:84  */
  assign n6084_o = n6081_o | n6083_o;
  /* T80_MCode.vhd:1744:95  */
  assign n6086_o = ir == 8'b01110100;
  /* T80_MCode.vhd:1744:95  */
  assign n6087_o = n6084_o | n6086_o;
  /* T80_MCode.vhd:1744:106  */
  assign n6089_o = ir == 8'b01111100;
  /* T80_MCode.vhd:1744:106  */
  assign n6090_o = n6087_o | n6089_o;
  /* T80_MCode.vhd:1751:25  */
  assign n6092_o = ir == 8'b01000110;
  /* T80_MCode.vhd:1751:40  */
  assign n6094_o = ir == 8'b01001110;
  /* T80_MCode.vhd:1751:40  */
  assign n6095_o = n6092_o | n6094_o;
  /* T80_MCode.vhd:1751:51  */
  assign n6097_o = ir == 8'b01100110;
  /* T80_MCode.vhd:1751:51  */
  assign n6098_o = n6095_o | n6097_o;
  /* T80_MCode.vhd:1751:62  */
  assign n6100_o = ir == 8'b01101110;
  /* T80_MCode.vhd:1751:62  */
  assign n6101_o = n6098_o | n6100_o;
  /* T80_MCode.vhd:1754:25  */
  assign n6103_o = ir == 8'b01010110;
  /* T80_MCode.vhd:1754:40  */
  assign n6105_o = ir == 8'b01110110;
  /* T80_MCode.vhd:1754:40  */
  assign n6106_o = n6103_o | n6105_o;
  /* T80_MCode.vhd:1757:25  */
  assign n6108_o = ir == 8'b01011110;
  /* T80_MCode.vhd:1757:40  */
  assign n6110_o = ir == 8'b01110111;
  /* T80_MCode.vhd:1757:40  */
  assign n6111_o = n6108_o | n6110_o;
  /* T80_MCode.vhd:1764:38  */
  assign n6112_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1771:68  */
  assign n6114_o = ir[5:4];
  /* T80_MCode.vhd:1771:46  */
  assign n6115_o = {29'b0, n6114_o};  //  uext
  /* T80_MCode.vhd:1773:78  */
  assign n6116_o = ir[5:4];
  /* T80_MCode.vhd:1772:41  */
  assign n6119_o = n6115_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1772:47  */
  assign n6121_o = n6115_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1772:47  */
  assign n6122_o = n6119_o | n6121_o;
  /* T80_MCode.vhd:1772:49  */
  assign n6124_o = n6115_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1772:49  */
  assign n6125_o = n6122_o | n6124_o;
  /* T80_MCode.vhd:1771:41  */
  always @*
    case (n6125_o)
      1'b1: n6127_o = 1'b1;
      default: n6127_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1771:41  */
  always @*
    case (n6125_o)
      1'b1: n6129_o = n6116_o;
      default: n6129_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1771:41  */
  always @*
    case (n6125_o)
      1'b1: n6132_o = 1'b0;
      default: n6132_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1765:33  */
  assign n6134_o = n6112_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1786:68  */
  assign n6136_o = ir[5:4];
  /* T80_MCode.vhd:1786:46  */
  assign n6137_o = {29'b0, n6136_o};  //  uext
  /* T80_MCode.vhd:1788:78  */
  assign n6138_o = ir[5:4];
  /* T80_MCode.vhd:1787:41  */
  assign n6141_o = n6137_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1787:47  */
  assign n6143_o = n6137_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1787:47  */
  assign n6144_o = n6141_o | n6143_o;
  /* T80_MCode.vhd:1787:49  */
  assign n6146_o = n6137_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1787:49  */
  assign n6147_o = n6144_o | n6146_o;
  /* T80_MCode.vhd:1786:41  */
  always @*
    case (n6147_o)
      1'b1: n6149_o = 1'b0;
      default: n6149_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1786:41  */
  always @*
    case (n6147_o)
      1'b1: n6151_o = n6138_o;
      default: n6151_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1786:41  */
  always @*
    case (n6147_o)
      1'b1: n6154_o = 1'b0;
      default: n6154_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1780:33  */
  assign n6156_o = n6112_o == 31'b0000000000000000000000000000011;
  assign n6157_o = {n6156_o, n6134_o};
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6159_o = n2179_o;
      2'b01: n6159_o = 3'b100;
      default: n6159_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6163_o = 1'b1;
      2'b01: n6163_o = 1'b1;
      default: n6163_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6165_o = 3'b100;
      2'b01: n6165_o = 3'b101;
      default: n6165_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6167_o = n6149_o;
      2'b01: n6167_o = n6127_o;
      default: n6167_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6169_o = n6151_o;
      2'b01: n6169_o = n6129_o;
      default: n6169_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6171_o = n6154_o;
      2'b01: n6171_o = n6132_o;
      default: n6171_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6174_o = 4'b0001;
      2'b01: n6174_o = 4'b0001;
      default: n6174_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6178_o = 1'b1;
      2'b01: n6178_o = 1'b1;
      default: n6178_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6181_o = 2'b00;
      2'b01: n6181_o = 2'b11;
      default: n6181_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6185_o = 1'b1;
      2'b01: n6185_o = 1'b1;
      default: n6185_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1761:25  */
  assign n6187_o = ir == 8'b01001010;
  /* T80_MCode.vhd:1761:40  */
  assign n6189_o = ir == 8'b01011010;
  /* T80_MCode.vhd:1761:40  */
  assign n6190_o = n6187_o | n6189_o;
  /* T80_MCode.vhd:1761:51  */
  assign n6192_o = ir == 8'b01101010;
  /* T80_MCode.vhd:1761:51  */
  assign n6193_o = n6190_o | n6192_o;
  /* T80_MCode.vhd:1761:62  */
  assign n6195_o = ir == 8'b01111010;
  /* T80_MCode.vhd:1761:62  */
  assign n6196_o = n6193_o | n6195_o;
  /* T80_MCode.vhd:1798:38  */
  assign n6197_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1805:68  */
  assign n6199_o = ir[5:4];
  /* T80_MCode.vhd:1805:46  */
  assign n6200_o = {29'b0, n6199_o};  //  uext
  /* T80_MCode.vhd:1807:78  */
  assign n6201_o = ir[5:4];
  /* T80_MCode.vhd:1806:41  */
  assign n6204_o = n6200_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1806:47  */
  assign n6206_o = n6200_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1806:47  */
  assign n6207_o = n6204_o | n6206_o;
  /* T80_MCode.vhd:1806:49  */
  assign n6209_o = n6200_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1806:49  */
  assign n6210_o = n6207_o | n6209_o;
  /* T80_MCode.vhd:1805:41  */
  always @*
    case (n6210_o)
      1'b1: n6212_o = 1'b1;
      default: n6212_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1805:41  */
  always @*
    case (n6210_o)
      1'b1: n6214_o = n6201_o;
      default: n6214_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1805:41  */
  always @*
    case (n6210_o)
      1'b1: n6217_o = 1'b0;
      default: n6217_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1799:33  */
  assign n6219_o = n6197_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1820:68  */
  assign n6221_o = ir[5:4];
  /* T80_MCode.vhd:1820:46  */
  assign n6222_o = {29'b0, n6221_o};  //  uext
  /* T80_MCode.vhd:1822:78  */
  assign n6223_o = ir[5:4];
  /* T80_MCode.vhd:1821:41  */
  assign n6225_o = n6222_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1821:47  */
  assign n6227_o = n6222_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1821:47  */
  assign n6228_o = n6225_o | n6227_o;
  /* T80_MCode.vhd:1821:49  */
  assign n6230_o = n6222_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1821:49  */
  assign n6231_o = n6228_o | n6230_o;
  /* T80_MCode.vhd:1820:41  */
  always @*
    case (n6231_o)
      1'b1: n6234_o = 1'b0;
      default: n6234_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1820:41  */
  always @*
    case (n6231_o)
      1'b1: n6236_o = n6223_o;
      default: n6236_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1820:41  */
  always @*
    case (n6231_o)
      1'b1: n6239_o = 1'b0;
      default: n6239_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1814:33  */
  assign n6241_o = n6197_o == 31'b0000000000000000000000000000011;
  assign n6242_o = {n6241_o, n6219_o};
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6244_o = n2179_o;
      2'b01: n6244_o = 3'b100;
      default: n6244_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6248_o = 1'b1;
      2'b01: n6248_o = 1'b1;
      default: n6248_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6250_o = 3'b100;
      2'b01: n6250_o = 3'b101;
      default: n6250_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6252_o = n6234_o;
      2'b01: n6252_o = n6212_o;
      default: n6252_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6254_o = n6236_o;
      2'b01: n6254_o = n6214_o;
      default: n6254_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6256_o = n6239_o;
      2'b01: n6256_o = n6217_o;
      default: n6256_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6259_o = 4'b0011;
      2'b01: n6259_o = 4'b0011;
      default: n6259_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6263_o = 1'b1;
      2'b01: n6263_o = 1'b1;
      default: n6263_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6266_o = 2'b00;
      2'b01: n6266_o = 2'b11;
      default: n6266_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6270_o = 1'b1;
      2'b01: n6270_o = 1'b1;
      default: n6270_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1795:25  */
  assign n6272_o = ir == 8'b01000010;
  /* T80_MCode.vhd:1795:40  */
  assign n6274_o = ir == 8'b01010010;
  /* T80_MCode.vhd:1795:40  */
  assign n6275_o = n6272_o | n6274_o;
  /* T80_MCode.vhd:1795:51  */
  assign n6277_o = ir == 8'b01100010;
  /* T80_MCode.vhd:1795:51  */
  assign n6278_o = n6275_o | n6277_o;
  /* T80_MCode.vhd:1795:62  */
  assign n6280_o = ir == 8'b01110010;
  /* T80_MCode.vhd:1795:62  */
  assign n6281_o = n6278_o | n6280_o;
  /* T80_MCode.vhd:1831:38  */
  assign n6282_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1832:33  */
  assign n6284_o = n6282_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1834:33  */
  assign n6288_o = n6282_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1840:33  */
  assign n6290_o = n6282_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1845:33  */
  assign n6292_o = n6282_o == 31'b0000000000000000000000000000100;
  assign n6293_o = {n6292_o, n6290_o, n6288_o, n6284_o};
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6295_o = n2179_o;
      4'b0100: n6295_o = 3'b100;
      4'b0010: n6295_o = n2179_o;
      4'b0001: n6295_o = n2179_o;
      default: n6295_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6298_o = 1'b0;
      4'b0100: n6298_o = 1'b0;
      4'b0010: n6298_o = 1'b1;
      4'b0001: n6298_o = 1'b0;
      default: n6298_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6300_o = 3'b000;
      4'b0100: n6300_o = 3'b000;
      4'b0010: n6300_o = 3'b111;
      4'b0001: n6300_o = 3'b000;
      default: n6300_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6302_o = 3'b000;
      4'b0100: n6302_o = 3'b000;
      4'b0010: n6302_o = 3'b110;
      4'b0001: n6302_o = 3'b000;
      default: n6302_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6304_o = n2182_o;
      4'b0100: n6304_o = n2182_o;
      4'b0010: n6304_o = 4'b1101;
      4'b0001: n6304_o = n2182_o;
      default: n6304_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6307_o = 1'b0;
      4'b0100: n6307_o = 1'b0;
      4'b0010: n6307_o = 1'b1;
      4'b0001: n6307_o = 1'b0;
      default: n6307_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6311_o = 3'b111;
      4'b0100: n6311_o = 3'b010;
      4'b0010: n6311_o = 3'b111;
      4'b0001: n6311_o = 3'b010;
      default: n6311_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6314_o = 1'b0;
      4'b0100: n6314_o = 1'b1;
      4'b0010: n6314_o = 1'b0;
      4'b0001: n6314_o = 1'b0;
      default: n6314_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6317_o = 1'b0;
      4'b0100: n6317_o = 1'b1;
      4'b0010: n6317_o = 1'b0;
      4'b0001: n6317_o = 1'b0;
      default: n6317_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6320_o = 1'b1;
      4'b0100: n6320_o = 1'b0;
      4'b0010: n6320_o = 1'b0;
      4'b0001: n6320_o = 1'b0;
      default: n6320_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1828:25  */
  assign n6322_o = ir == 8'b01101111;
  /* T80_MCode.vhd:1852:38  */
  assign n6323_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1853:33  */
  assign n6325_o = n6323_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1855:33  */
  assign n6329_o = n6323_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1861:33  */
  assign n6331_o = n6323_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1866:33  */
  assign n6333_o = n6323_o == 31'b0000000000000000000000000000100;
  assign n6334_o = {n6333_o, n6331_o, n6329_o, n6325_o};
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6336_o = n2179_o;
      4'b0100: n6336_o = 3'b100;
      4'b0010: n6336_o = n2179_o;
      4'b0001: n6336_o = n2179_o;
      default: n6336_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6339_o = 1'b0;
      4'b0100: n6339_o = 1'b0;
      4'b0010: n6339_o = 1'b1;
      4'b0001: n6339_o = 1'b0;
      default: n6339_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6341_o = 3'b000;
      4'b0100: n6341_o = 3'b000;
      4'b0010: n6341_o = 3'b111;
      4'b0001: n6341_o = 3'b000;
      default: n6341_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6343_o = 3'b000;
      4'b0100: n6343_o = 3'b000;
      4'b0010: n6343_o = 3'b110;
      4'b0001: n6343_o = 3'b000;
      default: n6343_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6345_o = n2182_o;
      4'b0100: n6345_o = n2182_o;
      4'b0010: n6345_o = 4'b1110;
      4'b0001: n6345_o = n2182_o;
      default: n6345_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6348_o = 1'b0;
      4'b0100: n6348_o = 1'b0;
      4'b0010: n6348_o = 1'b1;
      4'b0001: n6348_o = 1'b0;
      default: n6348_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6352_o = 3'b111;
      4'b0100: n6352_o = 3'b010;
      4'b0010: n6352_o = 3'b111;
      4'b0001: n6352_o = 3'b010;
      default: n6352_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6355_o = 1'b0;
      4'b0100: n6355_o = 1'b1;
      4'b0010: n6355_o = 1'b0;
      4'b0001: n6355_o = 1'b0;
      default: n6355_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6358_o = 1'b0;
      4'b0100: n6358_o = 1'b1;
      4'b0010: n6358_o = 1'b0;
      4'b0001: n6358_o = 1'b0;
      default: n6358_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6361_o = 1'b1;
      4'b0100: n6361_o = 1'b0;
      4'b0010: n6361_o = 1'b0;
      4'b0001: n6361_o = 1'b0;
      default: n6361_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1849:25  */
  assign n6363_o = ir == 8'b01100111;
  /* T80_MCode.vhd:1873:38  */
  assign n6364_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1874:33  */
  assign n6366_o = n6364_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1876:33  */
  assign n6368_o = n6364_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1880:33  */
  assign n6370_o = n6364_o == 31'b0000000000000000000000000000011;
  assign n6371_o = {n6370_o, n6368_o, n6366_o};
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6375_o = 4'b0111;
      3'b010: n6375_o = 4'b0111;
      3'b001: n6375_o = 4'b0000;
      default: n6375_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6379_o = 3'b111;
      3'b010: n6379_o = 3'b101;
      3'b001: n6379_o = 3'b101;
      default: n6379_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6382_o = 1'b1;
      3'b010: n6382_o = 1'b0;
      3'b001: n6382_o = 1'b0;
      default: n6382_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6385_o = 1'b0;
      3'b010: n6385_o = 1'b1;
      3'b001: n6385_o = 1'b0;
      default: n6385_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6388_o = 1'b1;
      3'b010: n6388_o = 1'b0;
      3'b001: n6388_o = 1'b0;
      default: n6388_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6391_o = 1'b1;
      3'b010: n6391_o = 1'b0;
      3'b001: n6391_o = 1'b0;
      default: n6391_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1870:25  */
  assign n6393_o = ir == 8'b01000101;
  /* T80_MCode.vhd:1870:40  */
  assign n6395_o = ir == 8'b01001101;
  /* T80_MCode.vhd:1870:40  */
  assign n6396_o = n6393_o | n6395_o;
  /* T80_MCode.vhd:1870:51  */
  assign n6398_o = ir == 8'b01010101;
  /* T80_MCode.vhd:1870:51  */
  assign n6399_o = n6396_o | n6398_o;
  /* T80_MCode.vhd:1870:62  */
  assign n6401_o = ir == 8'b01011101;
  /* T80_MCode.vhd:1870:62  */
  assign n6402_o = n6399_o | n6401_o;
  /* T80_MCode.vhd:1870:73  */
  assign n6404_o = ir == 8'b01100101;
  /* T80_MCode.vhd:1870:73  */
  assign n6405_o = n6402_o | n6404_o;
  /* T80_MCode.vhd:1870:84  */
  assign n6407_o = ir == 8'b01101101;
  /* T80_MCode.vhd:1870:84  */
  assign n6408_o = n6405_o | n6407_o;
  /* T80_MCode.vhd:1870:95  */
  assign n6410_o = ir == 8'b01110101;
  /* T80_MCode.vhd:1870:95  */
  assign n6411_o = n6408_o | n6410_o;
  /* T80_MCode.vhd:1870:106  */
  assign n6413_o = ir == 8'b01111101;
  /* T80_MCode.vhd:1870:106  */
  assign n6414_o = n6411_o | n6413_o;
  /* T80_MCode.vhd:1890:38  */
  assign n6415_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1891:33  */
  assign n6417_o = n6415_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1896:46  */
  assign n6418_o = ir[5:3];
  /* T80_MCode.vhd:1896:59  */
  assign n6420_o = n6418_o != 3'b110;
  /* T80_MCode.vhd:1898:78  */
  assign n6421_o = ir[5:3];
  /* T80_MCode.vhd:1896:41  */
  assign n6424_o = n6420_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1896:41  */
  assign n6426_o = n6420_o ? n6421_o : 3'b000;
  /* T80_MCode.vhd:1894:33  */
  assign n6428_o = n6415_o == 31'b0000000000000000000000000000010;
  assign n6429_o = {n6428_o, n6417_o};
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6431_o = n6424_o;
      2'b01: n6431_o = 1'b0;
      default: n6431_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6433_o = n6426_o;
      2'b01: n6433_o = 3'b000;
      default: n6433_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6436_o = 3'b111;
      2'b01: n6436_o = 3'b000;
      default: n6436_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6439_o = 1'b1;
      2'b01: n6439_o = 1'b0;
      default: n6439_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6442_o = 1'b1;
      2'b01: n6442_o = 1'b0;
      default: n6442_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6445_o = 2'b00;
      2'b01: n6445_o = 2'b01;
      default: n6445_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1887:25  */
  assign n6447_o = ir == 8'b01000000;
  /* T80_MCode.vhd:1887:40  */
  assign n6449_o = ir == 8'b01001000;
  /* T80_MCode.vhd:1887:40  */
  assign n6450_o = n6447_o | n6449_o;
  /* T80_MCode.vhd:1887:51  */
  assign n6452_o = ir == 8'b01010000;
  /* T80_MCode.vhd:1887:51  */
  assign n6453_o = n6450_o | n6452_o;
  /* T80_MCode.vhd:1887:62  */
  assign n6455_o = ir == 8'b01011000;
  /* T80_MCode.vhd:1887:62  */
  assign n6456_o = n6453_o | n6455_o;
  /* T80_MCode.vhd:1887:73  */
  assign n6458_o = ir == 8'b01100000;
  /* T80_MCode.vhd:1887:73  */
  assign n6459_o = n6456_o | n6458_o;
  /* T80_MCode.vhd:1887:84  */
  assign n6461_o = ir == 8'b01101000;
  /* T80_MCode.vhd:1887:84  */
  assign n6462_o = n6459_o | n6461_o;
  /* T80_MCode.vhd:1887:95  */
  assign n6464_o = ir == 8'b01110000;
  /* T80_MCode.vhd:1887:95  */
  assign n6465_o = n6462_o | n6464_o;
  /* T80_MCode.vhd:1887:106  */
  assign n6467_o = ir == 8'b01111000;
  /* T80_MCode.vhd:1887:106  */
  assign n6468_o = n6465_o | n6467_o;
  /* T80_MCode.vhd:1907:38  */
  assign n6469_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1911:78  */
  assign n6470_o = ir[5:3];
  /* T80_MCode.vhd:1912:46  */
  assign n6471_o = ir[5:3];
  /* T80_MCode.vhd:1912:59  */
  assign n6473_o = n6471_o == 3'b110;
  /* T80_MCode.vhd:1912:41  */
  assign n6476_o = n6473_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1908:33  */
  assign n6478_o = n6469_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1915:33  */
  assign n6480_o = n6469_o == 31'b0000000000000000000000000000010;
  assign n6481_o = {n6480_o, n6478_o};
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6483_o = 3'b000;
      2'b01: n6483_o = n6470_o;
      default: n6483_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6485_o = 1'b0;
      2'b01: n6485_o = n6476_o;
      default: n6485_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6488_o = 3'b111;
      2'b01: n6488_o = 3'b000;
      default: n6488_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6491_o = 1'b1;
      2'b01: n6491_o = 1'b0;
      default: n6491_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6494_o = 2'b00;
      2'b01: n6494_o = 2'b01;
      default: n6494_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6497_o = 1'b1;
      2'b01: n6497_o = 1'b0;
      default: n6497_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1903:25  */
  assign n6499_o = ir == 8'b01000001;
  /* T80_MCode.vhd:1903:40  */
  assign n6501_o = ir == 8'b01001001;
  /* T80_MCode.vhd:1903:40  */
  assign n6502_o = n6499_o | n6501_o;
  /* T80_MCode.vhd:1903:51  */
  assign n6504_o = ir == 8'b01010001;
  /* T80_MCode.vhd:1903:51  */
  assign n6505_o = n6502_o | n6504_o;
  /* T80_MCode.vhd:1903:62  */
  assign n6507_o = ir == 8'b01011001;
  /* T80_MCode.vhd:1903:62  */
  assign n6508_o = n6505_o | n6507_o;
  /* T80_MCode.vhd:1903:73  */
  assign n6510_o = ir == 8'b01100001;
  /* T80_MCode.vhd:1903:73  */
  assign n6511_o = n6508_o | n6510_o;
  /* T80_MCode.vhd:1903:84  */
  assign n6513_o = ir == 8'b01101001;
  /* T80_MCode.vhd:1903:84  */
  assign n6514_o = n6511_o | n6513_o;
  /* T80_MCode.vhd:1903:95  */
  assign n6516_o = ir == 8'b01110001;
  /* T80_MCode.vhd:1903:95  */
  assign n6517_o = n6514_o | n6516_o;
  /* T80_MCode.vhd:1903:106  */
  assign n6519_o = ir == 8'b01111001;
  /* T80_MCode.vhd:1903:106  */
  assign n6520_o = n6517_o | n6519_o;
  /* T80_MCode.vhd:1923:38  */
  assign n6521_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1933:59  */
  assign n6522_o = ir[3];
  /* T80_MCode.vhd:1924:33  */
  assign n6524_o = n6521_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1934:33  */
  assign n6526_o = n6521_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1939:46  */
  assign n6527_o = ir[3];
  /* T80_MCode.vhd:1939:50  */
  assign n6528_o = ~n6527_o;
  /* T80_MCode.vhd:1939:41  */
  assign n6531_o = n6528_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1938:33  */
  assign n6533_o = n6521_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1946:33  */
  assign n6535_o = n6521_o == 31'b0000000000000000000000000000100;
  assign n6536_o = {n6535_o, n6533_o, n6526_o, n6524_o};
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6539_o = 3'b101;
      4'b0100: n6539_o = n2179_o;
      4'b0010: n6539_o = n2179_o;
      4'b0001: n6539_o = 3'b101;
      default: n6539_o = n2179_o;
    endcase
  assign n6540_o = n6531_o[2:0];
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6542_o = 3'b000;
      4'b0100: n6542_o = n6540_o;
      4'b0010: n6542_o = 3'b000;
      4'b0001: n6542_o = 3'b000;
      default: n6542_o = 3'b000;
    endcase
  assign n6543_o = n6531_o[3];
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6545_o = 1'b0;
      4'b0100: n6545_o = n6543_o;
      4'b0010: n6545_o = 1'b0;
      4'b0001: n6545_o = n6522_o;
      default: n6545_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6548_o = 1'b0;
      4'b0100: n6548_o = 1'b0;
      4'b0010: n6548_o = 1'b0;
      4'b0001: n6548_o = 1'b1;
      default: n6548_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6551_o = 4'b0000;
      4'b0100: n6551_o = 4'b0000;
      4'b0010: n6551_o = 4'b0000;
      4'b0001: n6551_o = 4'b0000;
      default: n6551_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6555_o = 4'b0000;
      4'b0100: n6555_o = 4'b0000;
      4'b0010: n6555_o = 4'b0110;
      4'b0001: n6555_o = 4'b1010;
      default: n6555_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6557_o = n2182_o;
      4'b0100: n6557_o = n2182_o;
      4'b0010: n6557_o = n2182_o;
      4'b0001: n6557_o = 4'b0010;
      default: n6557_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6560_o = 1'b0;
      4'b0100: n6560_o = 1'b0;
      4'b0010: n6560_o = 1'b0;
      4'b0001: n6560_o = 1'b1;
      default: n6560_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6564_o = 3'b111;
      4'b0100: n6564_o = 3'b111;
      4'b0010: n6564_o = 3'b010;
      4'b0001: n6564_o = 3'b000;
      default: n6564_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6567_o = 1'b0;
      4'b0100: n6567_o = 1'b0;
      4'b0010: n6567_o = 1'b1;
      4'b0001: n6567_o = 1'b0;
      default: n6567_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6570_o = 1'b0;
      4'b0100: n6570_o = 1'b1;
      4'b0010: n6570_o = 1'b0;
      4'b0001: n6570_o = 1'b0;
      default: n6570_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6573_o = 2'b00;
      4'b0100: n6573_o = 2'b00;
      4'b0010: n6573_o = 2'b00;
      4'b0001: n6573_o = 2'b11;
      default: n6573_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6576_o = 1'b1;
      4'b0100: n6576_o = 1'b0;
      4'b0010: n6576_o = 1'b0;
      4'b0001: n6576_o = 1'b0;
      default: n6576_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6579_o = 1'b0;
      4'b0100: n6579_o = 1'b1;
      4'b0010: n6579_o = 1'b0;
      4'b0001: n6579_o = 1'b0;
      default: n6579_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1920:25  */
  assign n6581_o = ir == 8'b10100010;
  /* T80_MCode.vhd:1920:41  */
  assign n6583_o = ir == 8'b10101010;
  /* T80_MCode.vhd:1920:41  */
  assign n6584_o = n6581_o | n6583_o;
  /* T80_MCode.vhd:1920:54  */
  assign n6586_o = ir == 8'b10110010;
  /* T80_MCode.vhd:1920:54  */
  assign n6587_o = n6584_o | n6586_o;
  /* T80_MCode.vhd:1920:67  */
  assign n6589_o = ir == 8'b10111010;
  /* T80_MCode.vhd:1920:67  */
  assign n6590_o = n6587_o | n6589_o;
  /* T80_MCode.vhd:1954:38  */
  assign n6591_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1955:33  */
  assign n6593_o = n6591_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1967:59  */
  assign n6594_o = ir[3];
  /* T80_MCode.vhd:1963:33  */
  assign n6596_o = n6591_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1969:46  */
  assign n6597_o = ir[3];
  /* T80_MCode.vhd:1969:50  */
  assign n6598_o = ~n6597_o;
  /* T80_MCode.vhd:1969:41  */
  assign n6601_o = n6598_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1968:33  */
  assign n6603_o = n6591_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1977:33  */
  assign n6605_o = n6591_o == 31'b0000000000000000000000000000100;
  assign n6606_o = {n6605_o, n6603_o, n6596_o, n6593_o};
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6609_o = 3'b101;
      4'b0100: n6609_o = n2179_o;
      4'b0010: n6609_o = n2179_o;
      4'b0001: n6609_o = 3'b101;
      default: n6609_o = n2179_o;
    endcase
  assign n6610_o = n6601_o[2:0];
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6612_o = 3'b000;
      4'b0100: n6612_o = n6610_o;
      4'b0010: n6612_o = 3'b000;
      4'b0001: n6612_o = 3'b000;
      default: n6612_o = 3'b000;
    endcase
  assign n6613_o = n6601_o[3];
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6615_o = 1'b0;
      4'b0100: n6615_o = n6613_o;
      4'b0010: n6615_o = n6594_o;
      4'b0001: n6615_o = 1'b0;
      default: n6615_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6618_o = 1'b0;
      4'b0100: n6618_o = 1'b0;
      4'b0010: n6618_o = 1'b0;
      4'b0001: n6618_o = 1'b1;
      default: n6618_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6621_o = 4'b0000;
      4'b0100: n6621_o = 4'b0000;
      4'b0010: n6621_o = 4'b0000;
      4'b0001: n6621_o = 4'b0000;
      default: n6621_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6625_o = 4'b0000;
      4'b0100: n6625_o = 4'b0000;
      4'b0010: n6625_o = 4'b0110;
      4'b0001: n6625_o = 4'b1010;
      default: n6625_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6627_o = n2182_o;
      4'b0100: n6627_o = n2182_o;
      4'b0010: n6627_o = n2182_o;
      4'b0001: n6627_o = 4'b0010;
      default: n6627_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6630_o = 1'b0;
      4'b0100: n6630_o = 1'b0;
      4'b0010: n6630_o = 1'b0;
      4'b0001: n6630_o = 1'b1;
      default: n6630_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6634_o = 3'b111;
      4'b0100: n6634_o = 3'b111;
      4'b0010: n6634_o = 3'b000;
      4'b0001: n6634_o = 3'b010;
      default: n6634_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6637_o = 1'b0;
      4'b0100: n6637_o = 1'b1;
      4'b0010: n6637_o = 1'b0;
      4'b0001: n6637_o = 1'b0;
      default: n6637_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6640_o = 1'b0;
      4'b0100: n6640_o = 1'b1;
      4'b0010: n6640_o = 1'b0;
      4'b0001: n6640_o = 1'b0;
      default: n6640_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6643_o = 2'b00;
      4'b0100: n6643_o = 2'b00;
      4'b0010: n6643_o = 2'b11;
      4'b0001: n6643_o = 2'b00;
      default: n6643_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6646_o = 1'b1;
      4'b0100: n6646_o = 1'b0;
      4'b0010: n6646_o = 1'b0;
      4'b0001: n6646_o = 1'b0;
      default: n6646_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6649_o = 1'b0;
      4'b0100: n6649_o = 1'b1;
      4'b0010: n6649_o = 1'b0;
      4'b0001: n6649_o = 1'b0;
      default: n6649_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1951:25  */
  assign n6651_o = ir == 8'b10100011;
  /* T80_MCode.vhd:1951:41  */
  assign n6653_o = ir == 8'b10101011;
  /* T80_MCode.vhd:1951:41  */
  assign n6654_o = n6651_o | n6653_o;
  /* T80_MCode.vhd:1951:54  */
  assign n6656_o = ir == 8'b10110011;
  /* T80_MCode.vhd:1951:54  */
  assign n6657_o = n6654_o | n6656_o;
  /* T80_MCode.vhd:1951:67  */
  assign n6659_o = ir == 8'b10111011;
  /* T80_MCode.vhd:1951:67  */
  assign n6660_o = n6657_o | n6659_o;
  assign n6661_o = {n6660_o, n6590_o, n6520_o, n6468_o, n6414_o, n6363_o, n6322_o, n6281_o, n6196_o, n6111_o, n6106_o, n6101_o, n6090_o, n6067_o, n6011_o, n5953_o, n5891_o, n5823_o, n5821_o, n5819_o, n5817_o, n5815_o, n5810_o};
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6677_o = 3'b100;
      23'b01000000000000000000000: n6677_o = 3'b100;
      23'b00100000000000000000000: n6677_o = 3'b010;
      23'b00010000000000000000000: n6677_o = 3'b010;
      23'b00001000000000000000000: n6677_o = 3'b011;
      23'b00000100000000000000000: n6677_o = 3'b100;
      23'b00000010000000000000000: n6677_o = 3'b100;
      23'b00000001000000000000000: n6677_o = 3'b011;
      23'b00000000100000000000000: n6677_o = 3'b011;
      23'b00000000010000000000000: n6677_o = 3'b001;
      23'b00000000001000000000000: n6677_o = 3'b001;
      23'b00000000000100000000000: n6677_o = 3'b001;
      23'b00000000000010000000000: n6677_o = 3'b001;
      23'b00000000000001000000000: n6677_o = 3'b100;
      23'b00000000000000100000000: n6677_o = 3'b100;
      23'b00000000000000010000000: n6677_o = 3'b101;
      23'b00000000000000001000000: n6677_o = 3'b101;
      23'b00000000000000000100000: n6677_o = 3'b001;
      23'b00000000000000000010000: n6677_o = 3'b001;
      23'b00000000000000000001000: n6677_o = 3'b001;
      23'b00000000000000000000100: n6677_o = 3'b001;
      23'b00000000000000000000010: n6677_o = 3'b001;
      23'b00000000000000000000001: n6677_o = 3'b001;
      default: n6677_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6683_o = n6609_o;
      23'b01000000000000000000000: n6683_o = n6539_o;
      23'b00100000000000000000000: n6683_o = n2179_o;
      23'b00010000000000000000000: n6683_o = n2179_o;
      23'b00001000000000000000000: n6683_o = n2179_o;
      23'b00000100000000000000000: n6683_o = n6336_o;
      23'b00000010000000000000000: n6683_o = n6295_o;
      23'b00000001000000000000000: n6683_o = n6244_o;
      23'b00000000100000000000000: n6683_o = n6159_o;
      23'b00000000010000000000000: n6683_o = n2179_o;
      23'b00000000001000000000000: n6683_o = n2179_o;
      23'b00000000000100000000000: n6683_o = n2179_o;
      23'b00000000000010000000000: n6683_o = n2179_o;
      23'b00000000000001000000000: n6683_o = n6030_o;
      23'b00000000000000100000000: n6683_o = n5977_o;
      23'b00000000000000010000000: n6683_o = n2179_o;
      23'b00000000000000001000000: n6683_o = n2179_o;
      23'b00000000000000000100000: n6683_o = 3'b101;
      23'b00000000000000000010000: n6683_o = 3'b101;
      23'b00000000000000000001000: n6683_o = 3'b101;
      23'b00000000000000000000100: n6683_o = 3'b101;
      23'b00000000000000000000010: n6683_o = n2179_o;
      23'b00000000000000000000001: n6683_o = n2179_o;
      default: n6683_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6686_o = 1'b0;
      23'b01000000000000000000000: n6686_o = 1'b0;
      23'b00100000000000000000000: n6686_o = 1'b0;
      23'b00010000000000000000000: n6686_o = 1'b0;
      23'b00001000000000000000000: n6686_o = 1'b0;
      23'b00000100000000000000000: n6686_o = 1'b0;
      23'b00000010000000000000000: n6686_o = 1'b0;
      23'b00000001000000000000000: n6686_o = 1'b0;
      23'b00000000100000000000000: n6686_o = 1'b0;
      23'b00000000010000000000000: n6686_o = 1'b0;
      23'b00000000001000000000000: n6686_o = 1'b0;
      23'b00000000000100000000000: n6686_o = 1'b0;
      23'b00000000000010000000000: n6686_o = 1'b0;
      23'b00000000000001000000000: n6686_o = 1'b0;
      23'b00000000000000100000000: n6686_o = 1'b0;
      23'b00000000000000010000000: n6686_o = n5923_o;
      23'b00000000000000001000000: n6686_o = n5859_o;
      23'b00000000000000000100000: n6686_o = 1'b0;
      23'b00000000000000000010000: n6686_o = 1'b0;
      23'b00000000000000000001000: n6686_o = 1'b0;
      23'b00000000000000000000100: n6686_o = 1'b0;
      23'b00000000000000000000010: n6686_o = 1'b0;
      23'b00000000000000000000001: n6686_o = 1'b0;
      default: n6686_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6689_o = 1'b0;
      23'b01000000000000000000000: n6689_o = 1'b0;
      23'b00100000000000000000000: n6689_o = 1'b0;
      23'b00010000000000000000000: n6689_o = 1'b0;
      23'b00001000000000000000000: n6689_o = 1'b0;
      23'b00000100000000000000000: n6689_o = 1'b0;
      23'b00000010000000000000000: n6689_o = 1'b0;
      23'b00000001000000000000000: n6689_o = 1'b0;
      23'b00000000100000000000000: n6689_o = 1'b0;
      23'b00000000010000000000000: n6689_o = 1'b0;
      23'b00000000001000000000000: n6689_o = 1'b0;
      23'b00000000000100000000000: n6689_o = 1'b0;
      23'b00000000000010000000000: n6689_o = 1'b0;
      23'b00000000000001000000000: n6689_o = 1'b0;
      23'b00000000000000100000000: n6689_o = 1'b0;
      23'b00000000000000010000000: n6689_o = n5926_o;
      23'b00000000000000001000000: n6689_o = n5862_o;
      23'b00000000000000000100000: n6689_o = 1'b0;
      23'b00000000000000000010000: n6689_o = 1'b0;
      23'b00000000000000000001000: n6689_o = 1'b0;
      23'b00000000000000000000100: n6689_o = 1'b0;
      23'b00000000000000000000010: n6689_o = 1'b0;
      23'b00000000000000000000001: n6689_o = 1'b0;
      default: n6689_o = 1'bX;
    endcase
  assign n6690_o = n5980_o[2:0];
  assign n6691_o = n6033_o[2:0];
  assign n6692_o = n6375_o[2:0];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6695_o = n6612_o;
      23'b01000000000000000000000: n6695_o = n6542_o;
      23'b00100000000000000000000: n6695_o = 3'b000;
      23'b00010000000000000000000: n6695_o = 3'b000;
      23'b00001000000000000000000: n6695_o = n6692_o;
      23'b00000100000000000000000: n6695_o = 3'b000;
      23'b00000010000000000000000: n6695_o = 3'b000;
      23'b00000001000000000000000: n6695_o = 3'b000;
      23'b00000000100000000000000: n6695_o = 3'b000;
      23'b00000000010000000000000: n6695_o = 3'b000;
      23'b00000000001000000000000: n6695_o = 3'b000;
      23'b00000000000100000000000: n6695_o = 3'b000;
      23'b00000000000010000000000: n6695_o = 3'b000;
      23'b00000000000001000000000: n6695_o = n6691_o;
      23'b00000000000000100000000: n6695_o = n6690_o;
      23'b00000000000000010000000: n6695_o = 3'b000;
      23'b00000000000000001000000: n6695_o = 3'b000;
      23'b00000000000000000100000: n6695_o = 3'b000;
      23'b00000000000000000010000: n6695_o = 3'b000;
      23'b00000000000000000001000: n6695_o = 3'b000;
      23'b00000000000000000000100: n6695_o = 3'b000;
      23'b00000000000000000000010: n6695_o = 3'b000;
      23'b00000000000000000000001: n6695_o = 3'b000;
      default: n6695_o = 3'bX;
    endcase
  assign n6696_o = n5980_o[3];
  assign n6697_o = n6033_o[3];
  assign n6698_o = n6375_o[3];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6701_o = n6615_o;
      23'b01000000000000000000000: n6701_o = n6545_o;
      23'b00100000000000000000000: n6701_o = 1'b0;
      23'b00010000000000000000000: n6701_o = 1'b0;
      23'b00001000000000000000000: n6701_o = n6698_o;
      23'b00000100000000000000000: n6701_o = 1'b0;
      23'b00000010000000000000000: n6701_o = 1'b0;
      23'b00000001000000000000000: n6701_o = 1'b0;
      23'b00000000100000000000000: n6701_o = 1'b0;
      23'b00000000010000000000000: n6701_o = 1'b0;
      23'b00000000001000000000000: n6701_o = 1'b0;
      23'b00000000000100000000000: n6701_o = 1'b0;
      23'b00000000000010000000000: n6701_o = 1'b0;
      23'b00000000000001000000000: n6701_o = n6697_o;
      23'b00000000000000100000000: n6701_o = n6696_o;
      23'b00000000000000010000000: n6701_o = 1'b0;
      23'b00000000000000001000000: n6701_o = 1'b0;
      23'b00000000000000000100000: n6701_o = 1'b0;
      23'b00000000000000000010000: n6701_o = 1'b0;
      23'b00000000000000000001000: n6701_o = 1'b0;
      23'b00000000000000000000100: n6701_o = 1'b0;
      23'b00000000000000000000010: n6701_o = 1'b0;
      23'b00000000000000000000001: n6701_o = 1'b0;
      default: n6701_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6704_o = n6618_o;
      23'b01000000000000000000000: n6704_o = n6548_o;
      23'b00100000000000000000000: n6704_o = 1'b0;
      23'b00010000000000000000000: n6704_o = n6431_o;
      23'b00001000000000000000000: n6704_o = 1'b0;
      23'b00000100000000000000000: n6704_o = n6339_o;
      23'b00000010000000000000000: n6704_o = n6298_o;
      23'b00000001000000000000000: n6704_o = n6248_o;
      23'b00000000100000000000000: n6704_o = n6163_o;
      23'b00000000010000000000000: n6704_o = 1'b0;
      23'b00000000001000000000000: n6704_o = 1'b0;
      23'b00000000000100000000000: n6704_o = 1'b0;
      23'b00000000000010000000000: n6704_o = 1'b0;
      23'b00000000000001000000000: n6704_o = 1'b0;
      23'b00000000000000100000000: n6704_o = 1'b0;
      23'b00000000000000010000000: n6704_o = 1'b0;
      23'b00000000000000001000000: n6704_o = n5866_o;
      23'b00000000000000000100000: n6704_o = 1'b0;
      23'b00000000000000000010000: n6704_o = 1'b0;
      23'b00000000000000000001000: n6704_o = 1'b0;
      23'b00000000000000000000100: n6704_o = 1'b0;
      23'b00000000000000000000010: n6704_o = 1'b0;
      23'b00000000000000000000001: n6704_o = 1'b0;
      default: n6704_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6708_o = 1'b0;
      23'b01000000000000000000000: n6708_o = 1'b0;
      23'b00100000000000000000000: n6708_o = 1'b0;
      23'b00010000000000000000000: n6708_o = 1'b0;
      23'b00001000000000000000000: n6708_o = 1'b0;
      23'b00000100000000000000000: n6708_o = 1'b0;
      23'b00000010000000000000000: n6708_o = 1'b0;
      23'b00000001000000000000000: n6708_o = 1'b0;
      23'b00000000100000000000000: n6708_o = 1'b0;
      23'b00000000010000000000000: n6708_o = 1'b0;
      23'b00000000001000000000000: n6708_o = 1'b0;
      23'b00000000000100000000000: n6708_o = 1'b0;
      23'b00000000000010000000000: n6708_o = 1'b1;
      23'b00000000000001000000000: n6708_o = 1'b0;
      23'b00000000000000100000000: n6708_o = 1'b0;
      23'b00000000000000010000000: n6708_o = 1'b0;
      23'b00000000000000001000000: n6708_o = 1'b0;
      23'b00000000000000000100000: n6708_o = 1'b0;
      23'b00000000000000000010000: n6708_o = 1'b0;
      23'b00000000000000000001000: n6708_o = 1'b0;
      23'b00000000000000000000100: n6708_o = 1'b0;
      23'b00000000000000000000010: n6708_o = 1'b0;
      23'b00000000000000000000001: n6708_o = 1'b0;
      default: n6708_o = 1'bX;
    endcase
  assign n6710_o = n6551_o[2:0];
  assign n6711_o = n6621_o[2:0];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6714_o = n6711_o;
      23'b01000000000000000000000: n6714_o = n6710_o;
      23'b00100000000000000000000: n6714_o = 3'b000;
      23'b00010000000000000000000: n6714_o = n6433_o;
      23'b00001000000000000000000: n6714_o = 3'b000;
      23'b00000100000000000000000: n6714_o = n6341_o;
      23'b00000010000000000000000: n6714_o = n6300_o;
      23'b00000001000000000000000: n6714_o = n6250_o;
      23'b00000000100000000000000: n6714_o = n6165_o;
      23'b00000000010000000000000: n6714_o = 3'b000;
      23'b00000000001000000000000: n6714_o = 3'b000;
      23'b00000000000100000000000: n6714_o = 3'b000;
      23'b00000000000010000000000: n6714_o = 3'b010;
      23'b00000000000001000000000: n6714_o = n6035_o;
      23'b00000000000000100000000: n6714_o = n5982_o;
      23'b00000000000000010000000: n6714_o = 3'b000;
      23'b00000000000000001000000: n6714_o = n5868_o;
      23'b00000000000000000100000: n6714_o = 3'b000;
      23'b00000000000000000010000: n6714_o = 3'b000;
      23'b00000000000000000001000: n6714_o = 3'b000;
      23'b00000000000000000000100: n6714_o = 3'b000;
      23'b00000000000000000000010: n6714_o = 3'b000;
      23'b00000000000000000000001: n6714_o = 3'b000;
      default: n6714_o = 3'bX;
    endcase
  assign n6716_o = n6551_o[3];
  assign n6717_o = n6621_o[3];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6720_o = n6717_o;
      23'b01000000000000000000000: n6720_o = n6716_o;
      23'b00100000000000000000000: n6720_o = 1'b0;
      23'b00010000000000000000000: n6720_o = 1'b0;
      23'b00001000000000000000000: n6720_o = 1'b0;
      23'b00000100000000000000000: n6720_o = 1'b0;
      23'b00000010000000000000000: n6720_o = 1'b0;
      23'b00000001000000000000000: n6720_o = 1'b0;
      23'b00000000100000000000000: n6720_o = 1'b0;
      23'b00000000010000000000000: n6720_o = 1'b0;
      23'b00000000001000000000000: n6720_o = 1'b0;
      23'b00000000000100000000000: n6720_o = 1'b0;
      23'b00000000000010000000000: n6720_o = 1'b1;
      23'b00000000000001000000000: n6720_o = 1'b0;
      23'b00000000000000100000000: n6720_o = 1'b0;
      23'b00000000000000010000000: n6720_o = 1'b0;
      23'b00000000000000001000000: n6720_o = n5870_o;
      23'b00000000000000000100000: n6720_o = 1'b0;
      23'b00000000000000000010000: n6720_o = 1'b0;
      23'b00000000000000000001000: n6720_o = 1'b0;
      23'b00000000000000000000100: n6720_o = 1'b0;
      23'b00000000000000000000010: n6720_o = 1'b0;
      23'b00000000000000000000001: n6720_o = 1'b0;
      default: n6720_o = 1'bX;
    endcase
  assign n6721_o = n5928_o[0];
  assign n6722_o = n5985_o[0];
  assign n6723_o = n6038_o[0];
  assign n6725_o = n6302_o[0];
  assign n6726_o = n6343_o[0];
  assign n6727_o = n6483_o[0];
  assign n6728_o = n6555_o[0];
  assign n6729_o = n6625_o[0];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6732_o = n6729_o;
      23'b01000000000000000000000: n6732_o = n6728_o;
      23'b00100000000000000000000: n6732_o = n6727_o;
      23'b00010000000000000000000: n6732_o = 1'b0;
      23'b00001000000000000000000: n6732_o = 1'b0;
      23'b00000100000000000000000: n6732_o = n6726_o;
      23'b00000010000000000000000: n6732_o = n6725_o;
      23'b00000001000000000000000: n6732_o = n6252_o;
      23'b00000000100000000000000: n6732_o = n6167_o;
      23'b00000000010000000000000: n6732_o = 1'b0;
      23'b00000000001000000000000: n6732_o = 1'b0;
      23'b00000000000100000000000: n6732_o = 1'b0;
      23'b00000000000010000000000: n6732_o = 1'b1;
      23'b00000000000001000000000: n6732_o = n6723_o;
      23'b00000000000000100000000: n6732_o = n6722_o;
      23'b00000000000000010000000: n6732_o = n6721_o;
      23'b00000000000000001000000: n6732_o = 1'b0;
      23'b00000000000000000100000: n6732_o = 1'b0;
      23'b00000000000000000010000: n6732_o = 1'b0;
      23'b00000000000000000001000: n6732_o = 1'b0;
      23'b00000000000000000000100: n6732_o = 1'b0;
      23'b00000000000000000000010: n6732_o = 1'b0;
      23'b00000000000000000000001: n6732_o = 1'b0;
      default: n6732_o = 1'bX;
    endcase
  assign n6733_o = n5928_o[2:1];
  assign n6734_o = n5985_o[2:1];
  assign n6735_o = n6038_o[2:1];
  assign n6737_o = n6302_o[2:1];
  assign n6738_o = n6343_o[2:1];
  assign n6739_o = n6483_o[2:1];
  assign n6740_o = n6555_o[2:1];
  assign n6741_o = n6625_o[2:1];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6744_o = n6741_o;
      23'b01000000000000000000000: n6744_o = n6740_o;
      23'b00100000000000000000000: n6744_o = n6739_o;
      23'b00010000000000000000000: n6744_o = 2'b00;
      23'b00001000000000000000000: n6744_o = 2'b00;
      23'b00000100000000000000000: n6744_o = n6738_o;
      23'b00000010000000000000000: n6744_o = n6737_o;
      23'b00000001000000000000000: n6744_o = n6254_o;
      23'b00000000100000000000000: n6744_o = n6169_o;
      23'b00000000010000000000000: n6744_o = 2'b00;
      23'b00000000001000000000000: n6744_o = 2'b00;
      23'b00000000000100000000000: n6744_o = 2'b00;
      23'b00000000000010000000000: n6744_o = 2'b11;
      23'b00000000000001000000000: n6744_o = n6735_o;
      23'b00000000000000100000000: n6744_o = n6734_o;
      23'b00000000000000010000000: n6744_o = n6733_o;
      23'b00000000000000001000000: n6744_o = 2'b00;
      23'b00000000000000000100000: n6744_o = 2'b00;
      23'b00000000000000000010000: n6744_o = 2'b00;
      23'b00000000000000000001000: n6744_o = 2'b00;
      23'b00000000000000000000100: n6744_o = 2'b00;
      23'b00000000000000000000010: n6744_o = 2'b00;
      23'b00000000000000000000001: n6744_o = 2'b00;
      default: n6744_o = 2'bX;
    endcase
  assign n6745_o = n5928_o[3];
  assign n6746_o = n5985_o[3];
  assign n6747_o = n6038_o[3];
  assign n6749_o = n6555_o[3];
  assign n6750_o = n6625_o[3];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6753_o = n6750_o;
      23'b01000000000000000000000: n6753_o = n6749_o;
      23'b00100000000000000000000: n6753_o = n6485_o;
      23'b00010000000000000000000: n6753_o = 1'b0;
      23'b00001000000000000000000: n6753_o = 1'b0;
      23'b00000100000000000000000: n6753_o = 1'b0;
      23'b00000010000000000000000: n6753_o = 1'b0;
      23'b00000001000000000000000: n6753_o = n6256_o;
      23'b00000000100000000000000: n6753_o = n6171_o;
      23'b00000000010000000000000: n6753_o = 1'b0;
      23'b00000000001000000000000: n6753_o = 1'b0;
      23'b00000000000100000000000: n6753_o = 1'b0;
      23'b00000000000010000000000: n6753_o = 1'b0;
      23'b00000000000001000000000: n6753_o = n6747_o;
      23'b00000000000000100000000: n6753_o = n6746_o;
      23'b00000000000000010000000: n6753_o = n6745_o;
      23'b00000000000000001000000: n6753_o = 1'b0;
      23'b00000000000000000100000: n6753_o = 1'b0;
      23'b00000000000000000010000: n6753_o = 1'b0;
      23'b00000000000000000001000: n6753_o = 1'b0;
      23'b00000000000000000000100: n6753_o = 1'b0;
      23'b00000000000000000000010: n6753_o = 1'b0;
      23'b00000000000000000000001: n6753_o = 1'b0;
      default: n6753_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6756_o = n6627_o;
      23'b01000000000000000000000: n6756_o = n6557_o;
      23'b00100000000000000000000: n6756_o = n2182_o;
      23'b00010000000000000000000: n6756_o = n2182_o;
      23'b00001000000000000000000: n6756_o = n2182_o;
      23'b00000100000000000000000: n6756_o = n6345_o;
      23'b00000010000000000000000: n6756_o = n6304_o;
      23'b00000001000000000000000: n6756_o = n6259_o;
      23'b00000000100000000000000: n6756_o = n6174_o;
      23'b00000000010000000000000: n6756_o = n2182_o;
      23'b00000000001000000000000: n6756_o = n2182_o;
      23'b00000000000100000000000: n6756_o = n2182_o;
      23'b00000000000010000000000: n6756_o = 4'b0010;
      23'b00000000000001000000000: n6756_o = n6040_o;
      23'b00000000000000100000000: n6756_o = n5987_o;
      23'b00000000000000010000000: n6756_o = n2182_o;
      23'b00000000000000001000000: n6756_o = n2182_o;
      23'b00000000000000000100000: n6756_o = n2182_o;
      23'b00000000000000000010000: n6756_o = n2182_o;
      23'b00000000000000000001000: n6756_o = n2182_o;
      23'b00000000000000000000100: n6756_o = n2182_o;
      23'b00000000000000000000010: n6756_o = n2182_o;
      23'b00000000000000000000001: n6756_o = n2182_o;
      default: n6756_o = 4'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6760_o = n6630_o;
      23'b01000000000000000000000: n6760_o = n6560_o;
      23'b00100000000000000000000: n6760_o = 1'b0;
      23'b00010000000000000000000: n6760_o = 1'b0;
      23'b00001000000000000000000: n6760_o = 1'b0;
      23'b00000100000000000000000: n6760_o = n6348_o;
      23'b00000010000000000000000: n6760_o = n6307_o;
      23'b00000001000000000000000: n6760_o = n6263_o;
      23'b00000000100000000000000: n6760_o = n6178_o;
      23'b00000000010000000000000: n6760_o = 1'b0;
      23'b00000000001000000000000: n6760_o = 1'b0;
      23'b00000000000100000000000: n6760_o = 1'b0;
      23'b00000000000010000000000: n6760_o = 1'b1;
      23'b00000000000001000000000: n6760_o = n6043_o;
      23'b00000000000000100000000: n6760_o = 1'b0;
      23'b00000000000000010000000: n6760_o = 1'b0;
      23'b00000000000000001000000: n6760_o = 1'b0;
      23'b00000000000000000100000: n6760_o = 1'b0;
      23'b00000000000000000010000: n6760_o = 1'b0;
      23'b00000000000000000001000: n6760_o = 1'b0;
      23'b00000000000000000000100: n6760_o = 1'b0;
      23'b00000000000000000000010: n6760_o = 1'b0;
      23'b00000000000000000000001: n6760_o = 1'b0;
      default: n6760_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6763_o = 1'b0;
      23'b01000000000000000000000: n6763_o = 1'b0;
      23'b00100000000000000000000: n6763_o = 1'b0;
      23'b00010000000000000000000: n6763_o = 1'b0;
      23'b00001000000000000000000: n6763_o = 1'b0;
      23'b00000100000000000000000: n6763_o = 1'b0;
      23'b00000010000000000000000: n6763_o = 1'b0;
      23'b00000001000000000000000: n6763_o = 1'b0;
      23'b00000000100000000000000: n6763_o = 1'b0;
      23'b00000000010000000000000: n6763_o = 1'b0;
      23'b00000000001000000000000: n6763_o = 1'b0;
      23'b00000000000100000000000: n6763_o = 1'b0;
      23'b00000000000010000000000: n6763_o = 1'b0;
      23'b00000000000001000000000: n6763_o = n6046_o;
      23'b00000000000000100000000: n6763_o = 1'b0;
      23'b00000000000000010000000: n6763_o = 1'b0;
      23'b00000000000000001000000: n6763_o = 1'b0;
      23'b00000000000000000100000: n6763_o = 1'b0;
      23'b00000000000000000010000: n6763_o = 1'b0;
      23'b00000000000000000001000: n6763_o = 1'b0;
      23'b00000000000000000000100: n6763_o = 1'b0;
      23'b00000000000000000000010: n6763_o = 1'b0;
      23'b00000000000000000000001: n6763_o = 1'b0;
      default: n6763_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6766_o = n6634_o;
      23'b01000000000000000000000: n6766_o = n6564_o;
      23'b00100000000000000000000: n6766_o = n6488_o;
      23'b00010000000000000000000: n6766_o = n6436_o;
      23'b00001000000000000000000: n6766_o = n6379_o;
      23'b00000100000000000000000: n6766_o = n6352_o;
      23'b00000010000000000000000: n6766_o = n6311_o;
      23'b00000001000000000000000: n6766_o = 3'b111;
      23'b00000000100000000000000: n6766_o = 3'b111;
      23'b00000000010000000000000: n6766_o = 3'b111;
      23'b00000000001000000000000: n6766_o = 3'b111;
      23'b00000000000100000000000: n6766_o = 3'b111;
      23'b00000000000010000000000: n6766_o = 3'b111;
      23'b00000000000001000000000: n6766_o = n6049_o;
      23'b00000000000000100000000: n6766_o = n5991_o;
      23'b00000000000000010000000: n6766_o = n5932_o;
      23'b00000000000000001000000: n6766_o = n5874_o;
      23'b00000000000000000100000: n6766_o = 3'b111;
      23'b00000000000000000010000: n6766_o = 3'b111;
      23'b00000000000000000001000: n6766_o = 3'b111;
      23'b00000000000000000000100: n6766_o = 3'b111;
      23'b00000000000000000000010: n6766_o = 3'b111;
      23'b00000000000000000000001: n6766_o = 3'b111;
      default: n6766_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6769_o = n6637_o;
      23'b01000000000000000000000: n6769_o = n6567_o;
      23'b00100000000000000000000: n6769_o = n6491_o;
      23'b00010000000000000000000: n6769_o = n6439_o;
      23'b00001000000000000000000: n6769_o = 1'b0;
      23'b00000100000000000000000: n6769_o = 1'b0;
      23'b00000010000000000000000: n6769_o = 1'b0;
      23'b00000001000000000000000: n6769_o = 1'b0;
      23'b00000000100000000000000: n6769_o = 1'b0;
      23'b00000000010000000000000: n6769_o = 1'b0;
      23'b00000000001000000000000: n6769_o = 1'b0;
      23'b00000000000100000000000: n6769_o = 1'b0;
      23'b00000000000010000000000: n6769_o = 1'b0;
      23'b00000000000001000000000: n6769_o = 1'b0;
      23'b00000000000000100000000: n6769_o = 1'b0;
      23'b00000000000000010000000: n6769_o = 1'b0;
      23'b00000000000000001000000: n6769_o = 1'b0;
      23'b00000000000000000100000: n6769_o = 1'b0;
      23'b00000000000000000010000: n6769_o = 1'b0;
      23'b00000000000000000001000: n6769_o = 1'b0;
      23'b00000000000000000000100: n6769_o = 1'b0;
      23'b00000000000000000000010: n6769_o = 1'b0;
      23'b00000000000000000000001: n6769_o = 1'b0;
      default: n6769_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6772_o = 1'b0;
      23'b01000000000000000000000: n6772_o = 1'b0;
      23'b00100000000000000000000: n6772_o = 1'b0;
      23'b00010000000000000000000: n6772_o = 1'b0;
      23'b00001000000000000000000: n6772_o = n6382_o;
      23'b00000100000000000000000: n6772_o = 1'b0;
      23'b00000010000000000000000: n6772_o = 1'b0;
      23'b00000001000000000000000: n6772_o = 1'b0;
      23'b00000000100000000000000: n6772_o = 1'b0;
      23'b00000000010000000000000: n6772_o = 1'b0;
      23'b00000000001000000000000: n6772_o = 1'b0;
      23'b00000000000100000000000: n6772_o = 1'b0;
      23'b00000000000010000000000: n6772_o = 1'b0;
      23'b00000000000001000000000: n6772_o = 1'b0;
      23'b00000000000000100000000: n6772_o = 1'b0;
      23'b00000000000000010000000: n6772_o = 1'b0;
      23'b00000000000000001000000: n6772_o = 1'b0;
      23'b00000000000000000100000: n6772_o = 1'b0;
      23'b00000000000000000010000: n6772_o = 1'b0;
      23'b00000000000000000001000: n6772_o = 1'b0;
      23'b00000000000000000000100: n6772_o = 1'b0;
      23'b00000000000000000000010: n6772_o = 1'b0;
      23'b00000000000000000000001: n6772_o = 1'b0;
      default: n6772_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6775_o = 1'b0;
      23'b01000000000000000000000: n6775_o = 1'b0;
      23'b00100000000000000000000: n6775_o = 1'b0;
      23'b00010000000000000000000: n6775_o = 1'b0;
      23'b00001000000000000000000: n6775_o = n6385_o;
      23'b00000100000000000000000: n6775_o = 1'b0;
      23'b00000010000000000000000: n6775_o = 1'b0;
      23'b00000001000000000000000: n6775_o = 1'b0;
      23'b00000000100000000000000: n6775_o = 1'b0;
      23'b00000000010000000000000: n6775_o = 1'b0;
      23'b00000000001000000000000: n6775_o = 1'b0;
      23'b00000000000100000000000: n6775_o = 1'b0;
      23'b00000000000010000000000: n6775_o = 1'b0;
      23'b00000000000001000000000: n6775_o = 1'b0;
      23'b00000000000000100000000: n6775_o = 1'b0;
      23'b00000000000000010000000: n6775_o = n5935_o;
      23'b00000000000000001000000: n6775_o = n5877_o;
      23'b00000000000000000100000: n6775_o = 1'b0;
      23'b00000000000000000010000: n6775_o = 1'b0;
      23'b00000000000000000001000: n6775_o = 1'b0;
      23'b00000000000000000000100: n6775_o = 1'b0;
      23'b00000000000000000000010: n6775_o = 1'b0;
      23'b00000000000000000000001: n6775_o = 1'b0;
      default: n6775_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6778_o = 1'b0;
      23'b01000000000000000000000: n6778_o = 1'b0;
      23'b00100000000000000000000: n6778_o = 1'b0;
      23'b00010000000000000000000: n6778_o = 1'b0;
      23'b00001000000000000000000: n6778_o = n6388_o;
      23'b00000100000000000000000: n6778_o = 1'b0;
      23'b00000010000000000000000: n6778_o = 1'b0;
      23'b00000001000000000000000: n6778_o = 1'b0;
      23'b00000000100000000000000: n6778_o = 1'b0;
      23'b00000000010000000000000: n6778_o = 1'b0;
      23'b00000000001000000000000: n6778_o = 1'b0;
      23'b00000000000100000000000: n6778_o = 1'b0;
      23'b00000000000010000000000: n6778_o = 1'b0;
      23'b00000000000001000000000: n6778_o = 1'b0;
      23'b00000000000000100000000: n6778_o = 1'b0;
      23'b00000000000000010000000: n6778_o = n5938_o;
      23'b00000000000000001000000: n6778_o = n5880_o;
      23'b00000000000000000100000: n6778_o = 1'b0;
      23'b00000000000000000010000: n6778_o = 1'b0;
      23'b00000000000000000001000: n6778_o = 1'b0;
      23'b00000000000000000000100: n6778_o = 1'b0;
      23'b00000000000000000000010: n6778_o = 1'b0;
      23'b00000000000000000000001: n6778_o = 1'b0;
      default: n6778_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6785_o = 3'b000;
      23'b01000000000000000000000: n6785_o = 3'b000;
      23'b00100000000000000000000: n6785_o = 3'b000;
      23'b00010000000000000000000: n6785_o = 3'b000;
      23'b00001000000000000000000: n6785_o = 3'b000;
      23'b00000100000000000000000: n6785_o = 3'b000;
      23'b00000010000000000000000: n6785_o = 3'b000;
      23'b00000001000000000000000: n6785_o = 3'b000;
      23'b00000000100000000000000: n6785_o = 3'b000;
      23'b00000000010000000000000: n6785_o = 3'b000;
      23'b00000000001000000000000: n6785_o = 3'b000;
      23'b00000000000100000000000: n6785_o = 3'b000;
      23'b00000000000010000000000: n6785_o = 3'b000;
      23'b00000000000001000000000: n6785_o = 3'b000;
      23'b00000000000000100000000: n6785_o = 3'b000;
      23'b00000000000000010000000: n6785_o = 3'b000;
      23'b00000000000000001000000: n6785_o = 3'b000;
      23'b00000000000000000100000: n6785_o = 3'b111;
      23'b00000000000000000010000: n6785_o = 3'b110;
      23'b00000000000000000001000: n6785_o = 3'b101;
      23'b00000000000000000000100: n6785_o = 3'b100;
      23'b00000000000000000000010: n6785_o = 3'b000;
      23'b00000000000000000000001: n6785_o = 3'b000;
      default: n6785_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6788_o = 1'b0;
      23'b01000000000000000000000: n6788_o = 1'b0;
      23'b00100000000000000000000: n6788_o = 1'b0;
      23'b00010000000000000000000: n6788_o = 1'b0;
      23'b00001000000000000000000: n6788_o = n6391_o;
      23'b00000100000000000000000: n6788_o = 1'b0;
      23'b00000010000000000000000: n6788_o = 1'b0;
      23'b00000001000000000000000: n6788_o = 1'b0;
      23'b00000000100000000000000: n6788_o = 1'b0;
      23'b00000000010000000000000: n6788_o = 1'b0;
      23'b00000000001000000000000: n6788_o = 1'b0;
      23'b00000000000100000000000: n6788_o = 1'b0;
      23'b00000000000010000000000: n6788_o = 1'b0;
      23'b00000000000001000000000: n6788_o = 1'b0;
      23'b00000000000000100000000: n6788_o = 1'b0;
      23'b00000000000000010000000: n6788_o = 1'b0;
      23'b00000000000000001000000: n6788_o = 1'b0;
      23'b00000000000000000100000: n6788_o = 1'b0;
      23'b00000000000000000010000: n6788_o = 1'b0;
      23'b00000000000000000001000: n6788_o = 1'b0;
      23'b00000000000000000000100: n6788_o = 1'b0;
      23'b00000000000000000000010: n6788_o = 1'b0;
      23'b00000000000000000000001: n6788_o = 1'b0;
      default: n6788_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6791_o = 1'b0;
      23'b01000000000000000000000: n6791_o = 1'b0;
      23'b00100000000000000000000: n6791_o = 1'b0;
      23'b00010000000000000000000: n6791_o = 1'b0;
      23'b00001000000000000000000: n6791_o = 1'b0;
      23'b00000100000000000000000: n6791_o = 1'b0;
      23'b00000010000000000000000: n6791_o = 1'b0;
      23'b00000001000000000000000: n6791_o = 1'b0;
      23'b00000000100000000000000: n6791_o = 1'b0;
      23'b00000000010000000000000: n6791_o = 1'b0;
      23'b00000000001000000000000: n6791_o = 1'b0;
      23'b00000000000100000000000: n6791_o = 1'b0;
      23'b00000000000010000000000: n6791_o = 1'b0;
      23'b00000000000001000000000: n6791_o = 1'b0;
      23'b00000000000000100000000: n6791_o = n5994_o;
      23'b00000000000000010000000: n6791_o = 1'b0;
      23'b00000000000000001000000: n6791_o = 1'b0;
      23'b00000000000000000100000: n6791_o = 1'b0;
      23'b00000000000000000010000: n6791_o = 1'b0;
      23'b00000000000000000001000: n6791_o = 1'b0;
      23'b00000000000000000000100: n6791_o = 1'b0;
      23'b00000000000000000000010: n6791_o = 1'b0;
      23'b00000000000000000000001: n6791_o = 1'b0;
      default: n6791_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6794_o = 1'b0;
      23'b01000000000000000000000: n6794_o = 1'b0;
      23'b00100000000000000000000: n6794_o = 1'b0;
      23'b00010000000000000000000: n6794_o = 1'b0;
      23'b00001000000000000000000: n6794_o = 1'b0;
      23'b00000100000000000000000: n6794_o = 1'b0;
      23'b00000010000000000000000: n6794_o = 1'b0;
      23'b00000001000000000000000: n6794_o = 1'b0;
      23'b00000000100000000000000: n6794_o = 1'b0;
      23'b00000000010000000000000: n6794_o = 1'b0;
      23'b00000000001000000000000: n6794_o = 1'b0;
      23'b00000000000100000000000: n6794_o = 1'b0;
      23'b00000000000010000000000: n6794_o = 1'b0;
      23'b00000000000001000000000: n6794_o = n6052_o;
      23'b00000000000000100000000: n6794_o = 1'b0;
      23'b00000000000000010000000: n6794_o = 1'b0;
      23'b00000000000000001000000: n6794_o = 1'b0;
      23'b00000000000000000100000: n6794_o = 1'b0;
      23'b00000000000000000010000: n6794_o = 1'b0;
      23'b00000000000000000001000: n6794_o = 1'b0;
      23'b00000000000000000000100: n6794_o = 1'b0;
      23'b00000000000000000000010: n6794_o = 1'b0;
      23'b00000000000000000000001: n6794_o = 1'b0;
      default: n6794_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6797_o = n6640_o;
      23'b01000000000000000000000: n6797_o = n6570_o;
      23'b00100000000000000000000: n6797_o = 1'b0;
      23'b00010000000000000000000: n6797_o = 1'b0;
      23'b00001000000000000000000: n6797_o = 1'b0;
      23'b00000100000000000000000: n6797_o = 1'b0;
      23'b00000010000000000000000: n6797_o = 1'b0;
      23'b00000001000000000000000: n6797_o = 1'b0;
      23'b00000000100000000000000: n6797_o = 1'b0;
      23'b00000000010000000000000: n6797_o = 1'b0;
      23'b00000000001000000000000: n6797_o = 1'b0;
      23'b00000000000100000000000: n6797_o = 1'b0;
      23'b00000000000010000000000: n6797_o = 1'b0;
      23'b00000000000001000000000: n6797_o = 1'b0;
      23'b00000000000000100000000: n6797_o = 1'b0;
      23'b00000000000000010000000: n6797_o = 1'b0;
      23'b00000000000000001000000: n6797_o = 1'b0;
      23'b00000000000000000100000: n6797_o = 1'b0;
      23'b00000000000000000010000: n6797_o = 1'b0;
      23'b00000000000000000001000: n6797_o = 1'b0;
      23'b00000000000000000000100: n6797_o = 1'b0;
      23'b00000000000000000000010: n6797_o = 1'b0;
      23'b00000000000000000000001: n6797_o = 1'b0;
      default: n6797_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6800_o = 1'b0;
      23'b01000000000000000000000: n6800_o = 1'b0;
      23'b00100000000000000000000: n6800_o = 1'b0;
      23'b00010000000000000000000: n6800_o = 1'b0;
      23'b00001000000000000000000: n6800_o = 1'b0;
      23'b00000100000000000000000: n6800_o = 1'b0;
      23'b00000010000000000000000: n6800_o = n6314_o;
      23'b00000001000000000000000: n6800_o = 1'b0;
      23'b00000000100000000000000: n6800_o = 1'b0;
      23'b00000000010000000000000: n6800_o = 1'b0;
      23'b00000000001000000000000: n6800_o = 1'b0;
      23'b00000000000100000000000: n6800_o = 1'b0;
      23'b00000000000010000000000: n6800_o = 1'b0;
      23'b00000000000001000000000: n6800_o = 1'b0;
      23'b00000000000000100000000: n6800_o = 1'b0;
      23'b00000000000000010000000: n6800_o = 1'b0;
      23'b00000000000000001000000: n6800_o = 1'b0;
      23'b00000000000000000100000: n6800_o = 1'b0;
      23'b00000000000000000010000: n6800_o = 1'b0;
      23'b00000000000000000001000: n6800_o = 1'b0;
      23'b00000000000000000000100: n6800_o = 1'b0;
      23'b00000000000000000000010: n6800_o = 1'b0;
      23'b00000000000000000000001: n6800_o = 1'b0;
      default: n6800_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6803_o = 1'b0;
      23'b01000000000000000000000: n6803_o = 1'b0;
      23'b00100000000000000000000: n6803_o = 1'b0;
      23'b00010000000000000000000: n6803_o = 1'b0;
      23'b00001000000000000000000: n6803_o = 1'b0;
      23'b00000100000000000000000: n6803_o = n6355_o;
      23'b00000010000000000000000: n6803_o = 1'b0;
      23'b00000001000000000000000: n6803_o = 1'b0;
      23'b00000000100000000000000: n6803_o = 1'b0;
      23'b00000000010000000000000: n6803_o = 1'b0;
      23'b00000000001000000000000: n6803_o = 1'b0;
      23'b00000000000100000000000: n6803_o = 1'b0;
      23'b00000000000010000000000: n6803_o = 1'b0;
      23'b00000000000001000000000: n6803_o = 1'b0;
      23'b00000000000000100000000: n6803_o = 1'b0;
      23'b00000000000000010000000: n6803_o = 1'b0;
      23'b00000000000000001000000: n6803_o = 1'b0;
      23'b00000000000000000100000: n6803_o = 1'b0;
      23'b00000000000000000010000: n6803_o = 1'b0;
      23'b00000000000000000001000: n6803_o = 1'b0;
      23'b00000000000000000000100: n6803_o = 1'b0;
      23'b00000000000000000000010: n6803_o = 1'b0;
      23'b00000000000000000000001: n6803_o = 1'b0;
      default: n6803_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6806_o = 1'b0;
      23'b01000000000000000000000: n6806_o = 1'b0;
      23'b00100000000000000000000: n6806_o = 1'b0;
      23'b00010000000000000000000: n6806_o = n6442_o;
      23'b00001000000000000000000: n6806_o = 1'b0;
      23'b00000100000000000000000: n6806_o = 1'b0;
      23'b00000010000000000000000: n6806_o = 1'b0;
      23'b00000001000000000000000: n6806_o = 1'b0;
      23'b00000000100000000000000: n6806_o = 1'b0;
      23'b00000000010000000000000: n6806_o = 1'b0;
      23'b00000000001000000000000: n6806_o = 1'b0;
      23'b00000000000100000000000: n6806_o = 1'b0;
      23'b00000000000010000000000: n6806_o = 1'b0;
      23'b00000000000001000000000: n6806_o = 1'b0;
      23'b00000000000000100000000: n6806_o = 1'b0;
      23'b00000000000000010000000: n6806_o = 1'b0;
      23'b00000000000000001000000: n6806_o = 1'b0;
      23'b00000000000000000100000: n6806_o = 1'b0;
      23'b00000000000000000010000: n6806_o = 1'b0;
      23'b00000000000000000001000: n6806_o = 1'b0;
      23'b00000000000000000000100: n6806_o = 1'b0;
      23'b00000000000000000000010: n6806_o = 1'b0;
      23'b00000000000000000000001: n6806_o = 1'b0;
      default: n6806_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6809_o = n6643_o;
      23'b01000000000000000000000: n6809_o = n6573_o;
      23'b00100000000000000000000: n6809_o = n6494_o;
      23'b00010000000000000000000: n6809_o = n6445_o;
      23'b00001000000000000000000: n6809_o = 2'b00;
      23'b00000100000000000000000: n6809_o = 2'b00;
      23'b00000010000000000000000: n6809_o = 2'b00;
      23'b00000001000000000000000: n6809_o = n6266_o;
      23'b00000000100000000000000: n6809_o = n6181_o;
      23'b00000000010000000000000: n6809_o = 2'b00;
      23'b00000000001000000000000: n6809_o = 2'b00;
      23'b00000000000100000000000: n6809_o = 2'b00;
      23'b00000000000010000000000: n6809_o = 2'b00;
      23'b00000000000001000000000: n6809_o = 2'b00;
      23'b00000000000000100000000: n6809_o = 2'b00;
      23'b00000000000000010000000: n6809_o = 2'b00;
      23'b00000000000000001000000: n6809_o = 2'b00;
      23'b00000000000000000100000: n6809_o = 2'b00;
      23'b00000000000000000010000: n6809_o = 2'b00;
      23'b00000000000000000001000: n6809_o = 2'b00;
      23'b00000000000000000000100: n6809_o = 2'b00;
      23'b00000000000000000000010: n6809_o = 2'b00;
      23'b00000000000000000000001: n6809_o = 2'b00;
      default: n6809_o = 2'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6815_o = 2'b11;
      23'b01000000000000000000000: n6815_o = 2'b11;
      23'b00100000000000000000000: n6815_o = 2'b11;
      23'b00010000000000000000000: n6815_o = 2'b11;
      23'b00001000000000000000000: n6815_o = 2'b11;
      23'b00000100000000000000000: n6815_o = 2'b11;
      23'b00000010000000000000000: n6815_o = 2'b11;
      23'b00000001000000000000000: n6815_o = 2'b11;
      23'b00000000100000000000000: n6815_o = 2'b11;
      23'b00000000010000000000000: n6815_o = 2'b10;
      23'b00000000001000000000000: n6815_o = 2'b01;
      23'b00000000000100000000000: n6815_o = 2'b00;
      23'b00000000000010000000000: n6815_o = 2'b11;
      23'b00000000000001000000000: n6815_o = 2'b11;
      23'b00000000000000100000000: n6815_o = 2'b11;
      23'b00000000000000010000000: n6815_o = 2'b11;
      23'b00000000000000001000000: n6815_o = 2'b11;
      23'b00000000000000000100000: n6815_o = 2'b11;
      23'b00000000000000000010000: n6815_o = 2'b11;
      23'b00000000000000000001000: n6815_o = 2'b11;
      23'b00000000000000000000100: n6815_o = 2'b11;
      23'b00000000000000000000010: n6815_o = 2'b11;
      23'b00000000000000000000001: n6815_o = 2'b11;
      default: n6815_o = 2'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6818_o = n6646_o;
      23'b01000000000000000000000: n6818_o = n6576_o;
      23'b00100000000000000000000: n6818_o = 1'b0;
      23'b00010000000000000000000: n6818_o = 1'b0;
      23'b00001000000000000000000: n6818_o = 1'b0;
      23'b00000100000000000000000: n6818_o = n6358_o;
      23'b00000010000000000000000: n6818_o = n6317_o;
      23'b00000001000000000000000: n6818_o = n6270_o;
      23'b00000000100000000000000: n6818_o = n6185_o;
      23'b00000000010000000000000: n6818_o = 1'b0;
      23'b00000000001000000000000: n6818_o = 1'b0;
      23'b00000000000100000000000: n6818_o = 1'b0;
      23'b00000000000010000000000: n6818_o = 1'b0;
      23'b00000000000001000000000: n6818_o = n6056_o;
      23'b00000000000000100000000: n6818_o = n5997_o;
      23'b00000000000000010000000: n6818_o = 1'b0;
      23'b00000000000000001000000: n6818_o = 1'b0;
      23'b00000000000000000100000: n6818_o = 1'b0;
      23'b00000000000000000010000: n6818_o = 1'b0;
      23'b00000000000000000001000: n6818_o = 1'b0;
      23'b00000000000000000000100: n6818_o = 1'b0;
      23'b00000000000000000000010: n6818_o = 1'b0;
      23'b00000000000000000000001: n6818_o = 1'b0;
      default: n6818_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6821_o = n6649_o;
      23'b01000000000000000000000: n6821_o = n6579_o;
      23'b00100000000000000000000: n6821_o = n6497_o;
      23'b00010000000000000000000: n6821_o = 1'b0;
      23'b00001000000000000000000: n6821_o = 1'b0;
      23'b00000100000000000000000: n6821_o = n6361_o;
      23'b00000010000000000000000: n6821_o = n6320_o;
      23'b00000001000000000000000: n6821_o = 1'b0;
      23'b00000000100000000000000: n6821_o = 1'b0;
      23'b00000000010000000000000: n6821_o = 1'b0;
      23'b00000000001000000000000: n6821_o = 1'b0;
      23'b00000000000100000000000: n6821_o = 1'b0;
      23'b00000000000010000000000: n6821_o = 1'b0;
      23'b00000000000001000000000: n6821_o = 1'b0;
      23'b00000000000000100000000: n6821_o = n6000_o;
      23'b00000000000000010000000: n6821_o = n5942_o;
      23'b00000000000000001000000: n6821_o = 1'b0;
      23'b00000000000000000100000: n6821_o = 1'b0;
      23'b00000000000000000010000: n6821_o = 1'b0;
      23'b00000000000000000001000: n6821_o = 1'b0;
      23'b00000000000000000000100: n6821_o = 1'b0;
      23'b00000000000000000000010: n6821_o = 1'b0;
      23'b00000000000000000000001: n6821_o = 1'b0;
      default: n6821_o = 1'bX;
    endcase
  assign n6822_o = {n5283_o, n4195_o};
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6823_o = n5261_o;
      2'b01: n6823_o = n3980_o;
      default: n6823_o = n6677_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6825_o = n5263_o;
      2'b01: n6825_o = n3985_o;
      default: n6825_o = n6683_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6827_o = 1'b0;
      2'b01: n6827_o = n3988_o;
      default: n6827_o = n6686_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6830_o = 1'b0;
      2'b01: n6830_o = n3991_o;
      default: n6830_o = n6689_o;
    endcase
  assign n6832_o = n6695_o[1:0];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6834_o = 2'b00;
      2'b01: n6834_o = n4003_o;
      default: n6834_o = n6832_o;
    endcase
  assign n6835_o = n4015_o[0];
  assign n6836_o = n6695_o[2];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6838_o = 1'b0;
      2'b01: n6838_o = n6835_o;
      default: n6838_o = n6836_o;
    endcase
  assign n6839_o = n4015_o[1];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6841_o = 1'b0;
      2'b01: n6841_o = n6839_o;
      default: n6841_o = n6701_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6845_o = n5266_o;
      2'b01: n6845_o = n4024_o;
      default: n6845_o = n6704_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6848_o = 1'b0;
      2'b01: n6848_o = n4027_o;
      default: n6848_o = n6708_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6850_o = n4196_o;
      2'b01: n6850_o = n4031_o;
      default: n6850_o = n6714_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6852_o = 1'b0;
      2'b01: n6852_o = n4035_o;
      default: n6852_o = n6720_o;
    endcase
  assign n6855_o = n5268_o[0];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6856_o = n6855_o;
      2'b01: n6856_o = n4059_o;
      default: n6856_o = n6732_o;
    endcase
  assign n6857_o = n5268_o[2:1];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6858_o = n6857_o;
      2'b01: n6858_o = n4083_o;
      default: n6858_o = n6744_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6860_o = 1'b0;
      2'b01: n6860_o = n4101_o;
      default: n6860_o = n6753_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6864_o = n5270_o;
      2'b01: n6864_o = n4107_o;
      default: n6864_o = n6756_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6865_o = n5273_o;
      2'b01: n6865_o = n4115_o;
      default: n6865_o = n6760_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6868_o = 1'b0;
      2'b01: n6868_o = n4120_o;
      default: n6868_o = n6763_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6871_o = 1'b0;
      2'b01: n6871_o = n4123_o;
      default: n6871_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6873_o = n5275_o;
      2'b01: n6873_o = n4126_o;
      default: n6873_o = n6766_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6876_o = 1'b0;
      2'b01: n6876_o = n4129_o;
      default: n6876_o = n6769_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6879_o = 1'b0;
      2'b01: n6879_o = n4132_o;
      default: n6879_o = n6772_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6882_o = 1'b0;
      2'b01: n6882_o = n4136_o;
      default: n6882_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6885_o = 1'b0;
      2'b01: n6885_o = n4139_o;
      default: n6885_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6888_o = 1'b0;
      2'b01: n6888_o = n4142_o;
      default: n6888_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6891_o = 1'b0;
      2'b01: n6891_o = n4145_o;
      default: n6891_o = n6775_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6894_o = 1'b0;
      2'b01: n6894_o = n4148_o;
      default: n6894_o = n6778_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6897_o = 1'b0;
      2'b01: n6897_o = n4152_o;
      default: n6897_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6900_o = 3'b000;
      2'b01: n6900_o = 3'b000;
      default: n6900_o = n6785_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6903_o = 1'b0;
      2'b01: n6903_o = n4156_o;
      default: n6903_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6906_o = 1'b0;
      2'b01: n6906_o = n4160_o;
      default: n6906_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6909_o = 1'b0;
      2'b01: n6909_o = n4164_o;
      default: n6909_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6912_o = 1'b0;
      2'b01: n6912_o = n4168_o;
      default: n6912_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6915_o = 1'b0;
      2'b01: n6915_o = n4172_o;
      default: n6915_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6918_o = 1'b0;
      2'b01: n6918_o = 1'b0;
      default: n6918_o = n6788_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6921_o = 1'b0;
      2'b01: n6921_o = 1'b0;
      default: n6921_o = n6791_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6924_o = 1'b0;
      2'b01: n6924_o = 1'b0;
      default: n6924_o = n6794_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6927_o = 1'b0;
      2'b01: n6927_o = 1'b0;
      default: n6927_o = n6797_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6930_o = 1'b0;
      2'b01: n6930_o = 1'b0;
      default: n6930_o = n6800_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6933_o = 1'b0;
      2'b01: n6933_o = 1'b0;
      default: n6933_o = n6803_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6936_o = 1'b0;
      2'b01: n6936_o = 1'b0;
      default: n6936_o = n6806_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6939_o = 2'b00;
      2'b01: n6939_o = n4175_o;
      default: n6939_o = n6809_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6942_o = 1'b0;
      2'b01: n6942_o = n4179_o;
      default: n6942_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6945_o = 1'b0;
      2'b01: n6945_o = n4183_o;
      default: n6945_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6948_o = 2'b11;
      2'b01: n6948_o = 2'b11;
      default: n6948_o = n6815_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6951_o = 1'b0;
      2'b01: n6951_o = n4187_o;
      default: n6951_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6954_o = 1'b0;
      2'b01: n6954_o = n4190_o;
      default: n6954_o = n6818_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6956_o = n5278_o;
      2'b01: n6956_o = n4193_o;
      default: n6956_o = n6821_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6959_o = n5281_o;
      2'b01: n6959_o = 1'b0;
      default: n6959_o = 1'b0;
    endcase
  assign n6967_o = {n6841_o, n6838_o, n6834_o};
  assign n6968_o = {n6852_o, n6850_o};
  assign n6969_o = {n6860_o, n6858_o, n6856_o};
endmodule

module t8080_cpu
  (input  reset_n,
   input  clk_n,
   input  cen,
   input  wait_n,
   input  int_n,
   input  nmi_n,
   input  busrq_n,
   input  [7:0] dinst,
   input  [7:0] di,
   input  out0,
   input  dirset,
   input  [211:0] dir,
   output m1_n,
   output iorq,
   output noread,
   output write,
   output rfsh_n,
   output halt_n,
   output busak_n,
   output [15:0] a,
   output [7:0] dout,
   output [2:0] mc,
   output [2:0] ts,
   output intcycle_n,
   output inte,
   output stop,
   output [211:0] regs);
  wire [7:0] acc;
  wire [7:0] f;
  wire [7:0] ap;
  wire [7:0] fp;
  wire [7:0] i;
  wire [7:0] r;
  wire [15:0] sp;
  wire [15:0] pc;
  wire [7:0] regdih;
  wire [7:0] regdil;
  wire [15:0] regbusa;
  wire [15:0] regbusb;
  wire [15:0] regbusc;
  wire [2:0] regaddra_r;
  wire [2:0] regaddra;
  wire [2:0] regaddrb_r;
  wire [2:0] regaddrb;
  wire [2:0] regaddrc;
  wire regweh;
  wire regwel;
  wire alternate;
  wire [15:0] wz;
  wire [7:0] ir;
  wire [1:0] iset;
  wire [15:0] regbusa_r;
  wire [15:0] id16;
  wire [7:0] save_mux;
  wire [2:0] tstate;
  wire [2:0] mcycle;
  wire inte_ff1;
  wire inte_ff2;
  wire halt_ff;
  wire busreq_s;
  wire busack;
  wire clken;
  wire nmi_s;
  wire [1:0] istatus;
  wire [7:0] di_reg;
  wire t_res;
  wire [1:0] xy_state;
  wire [2:0] pre_xy_f_m;
  wire nextis_xy_fetch;
  wire xy_ind;
  wire no_btr;
  wire btr_r;
  wire auto_wait;
  wire auto_wait_t1;
  wire auto_wait_t2;
  wire incdecz;
  wire [7:0] busb;
  wire [7:0] busa;
  wire [7:0] alu_q;
  wire [7:0] f_out;
  wire [4:0] read_to_reg_r;
  wire arith16_r;
  wire z16_r;
  wire [3:0] alu_op_r;
  wire save_alu_r;
  wire preservec_r;
  wire [2:0] mcycles;
  wire [2:0] mcycles_d;
  wire [2:0] tstates;
  wire intcycle;
  wire nmicycle;
  wire inc_pc;
  wire inc_wz;
  wire [3:0] incdec_16;
  wire [1:0] prefix;
  wire read_to_acc;
  wire read_to_reg;
  wire [3:0] set_busb_to;
  wire [3:0] set_busa_to;
  wire [3:0] alu_op;
  wire save_alu;
  wire preservec;
  wire arith16;
  wire [2:0] set_addr_to;
  wire jump;
  wire jumpe;
  wire jumpxy;
  wire call;
  wire rstp;
  wire ldz;
  wire ldw;
  wire ldsphl;
  wire iorq_i;
  wire [2:0] special_ld;
  wire exchangedh;
  wire exchangerp;
  wire exchangeaf;
  wire exchangers;
  wire i_djnz;
  wire i_cpl;
  wire i_ccf;
  wire i_scf;
  wire i_retn;
  wire i_bt;
  wire i_bc;
  wire i_btr;
  wire i_rld;
  wire i_rrd;
  wire i_rxdd;
  wire i_inrc;
  wire [1:0] setwz;
  wire setdi;
  wire setei;
  wire [1:0] imode;
  wire halt;
  wire xybit_undoc;
  wire [127:0] dor;
  wire [1:0] n171_o;
  wire [3:0] n172_o;
  wire [131:0] n173_o;
  wire [147:0] n174_o;
  wire [163:0] n175_o;
  wire [171:0] n176_o;
  wire [179:0] n177_o;
  wire [187:0] n178_o;
  wire [195:0] n179_o;
  wire [203:0] n180_o;
  wire [211:0] n181_o;
  wire n182_o;
  wire [211:0] n183_o;
  wire [1:0] n184_o;
  wire [3:0] n185_o;
  wire [15:0] n186_o;
  wire [19:0] n187_o;
  wire [47:0] n188_o;
  wire [67:0] n189_o;
  wire [15:0] n190_o;
  wire [83:0] n191_o;
  wire [47:0] n192_o;
  wire [131:0] n193_o;
  wire [147:0] n194_o;
  wire [163:0] n195_o;
  wire [171:0] n196_o;
  wire [179:0] n197_o;
  wire [187:0] n198_o;
  wire [195:0] n199_o;
  wire [203:0] n200_o;
  wire [211:0] n201_o;
  wire [2:0] mcode_n202;
  wire [2:0] mcode_n203;
  wire [1:0] mcode_n204;
  wire mcode_n205;
  wire mcode_n206;
  wire [3:0] mcode_n207;
  wire mcode_n208;
  wire mcode_n209;
  wire [3:0] mcode_n210;
  wire [3:0] mcode_n211;
  wire [3:0] mcode_n212;
  wire mcode_n213;
  wire mcode_n214;
  wire mcode_n215;
  wire [2:0] mcode_n216;
  wire mcode_n217;
  wire mcode_n218;
  wire mcode_n219;
  wire mcode_n220;
  wire mcode_n221;
  wire mcode_n222;
  wire mcode_n223;
  wire mcode_n224;
  wire mcode_n225;
  wire [2:0] mcode_n226;
  wire mcode_n227;
  wire mcode_n228;
  wire mcode_n229;
  wire mcode_n230;
  wire mcode_n231;
  wire mcode_n232;
  wire mcode_n233;
  wire mcode_n234;
  wire mcode_n235;
  wire mcode_n236;
  wire mcode_n237;
  wire mcode_n238;
  wire mcode_n239;
  wire mcode_n240;
  wire mcode_n241;
  wire [1:0] mcode_n242;
  wire mcode_n243;
  wire mcode_n244;
  wire [1:0] mcode_n245;
  wire mcode_n246;
  wire mcode_n247;
  wire mcode_n248;
  wire mcode_n249;
  wire [2:0] mcode_mcycles;
  wire [2:0] mcode_tstates;
  wire [1:0] mcode_prefix;
  wire mcode_inc_pc;
  wire mcode_inc_wz;
  wire [3:0] mcode_incdec_16;
  wire mcode_read_to_reg;
  wire mcode_read_to_acc;
  wire [3:0] mcode_set_busa_to;
  wire [3:0] mcode_set_busb_to;
  wire [3:0] mcode_alu_op;
  wire mcode_save_alu;
  wire mcode_preservec;
  wire mcode_arith16;
  wire [2:0] mcode_set_addr_to;
  wire mcode_iorq;
  wire mcode_jump;
  wire mcode_jumpe;
  wire mcode_jumpxy;
  wire mcode_call;
  wire mcode_rstp;
  wire mcode_ldz;
  wire mcode_ldw;
  wire mcode_ldsphl;
  wire [2:0] mcode_special_ld;
  wire mcode_exchangedh;
  wire mcode_exchangerp;
  wire mcode_exchangeaf;
  wire mcode_exchangers;
  wire mcode_i_djnz;
  wire mcode_i_cpl;
  wire mcode_i_ccf;
  wire mcode_i_scf;
  wire mcode_i_retn;
  wire mcode_i_bt;
  wire mcode_i_bc;
  wire mcode_i_btr;
  wire mcode_i_rld;
  wire mcode_i_rrd;
  wire mcode_i_inrc;
  wire [1:0] mcode_setwz;
  wire mcode_setdi;
  wire mcode_setei;
  wire [1:0] mcode_imode;
  wire mcode_halt;
  wire mcode_noread;
  wire mcode_write;
  wire mcode_xybit_undoc;
  wire [5:0] n346_o;
  wire [7:0] u_alu_n347;
  wire [7:0] u_alu_n348;
  wire [7:0] u_alu_q;
  wire [7:0] u_alu_f_out;
  wire n353_o;
  wire n354_o;
  wire n356_o;
  wire n357_o;
  wire n361_o;
  wire n362_o;
  wire n363_o;
  wire n365_o;
  wire n367_o;
  wire n369_o;
  wire n370_o;
  wire n371_o;
  wire n373_o;
  wire n375_o;
  wire n376_o;
  wire n377_o;
  wire n378_o;
  wire n379_o;
  wire [7:0] n381_o;
  wire n382_o;
  wire [7:0] n383_o;
  wire n388_o;
  wire [7:0] n390_o;
  wire [7:0] n391_o;
  wire [7:0] n392_o;
  wire [7:0] n393_o;
  wire [7:0] n394_o;
  wire [7:0] n395_o;
  wire [15:0] n396_o;
  wire [15:0] n397_o;
  wire [15:0] n398_o;
  wire [1:0] n399_o;
  wire n401_o;
  wire [1:0] n402_o;
  wire n404_o;
  wire n405_o;
  wire n406_o;
  wire n407_o;
  wire n408_o;
  wire n409_o;
  wire n411_o;
  wire n412_o;
  wire n415_o;
  wire n417_o;
  wire n418_o;
  wire n419_o;
  wire n420_o;
  wire n422_o;
  wire n423_o;
  wire n424_o;
  wire n425_o;
  wire n426_o;
  wire n427_o;
  wire n428_o;
  wire n429_o;
  wire n430_o;
  wire n431_o;
  wire n432_o;
  wire n433_o;
  wire [15:0] n435_o;
  wire [15:0] n436_o;
  wire n438_o;
  wire n439_o;
  wire n441_o;
  wire n442_o;
  wire n443_o;
  wire n444_o;
  wire [7:0] n446_o;
  wire [7:0] n448_o;
  wire n450_o;
  wire n452_o;
  wire n453_o;
  wire [1:0] n456_o;
  wire n458_o;
  wire [1:0] n460_o;
  wire n462_o;
  wire [1:0] n464_o;
  wire [1:0] n465_o;
  wire n466_o;
  wire [1:0] n468_o;
  wire [1:0] n471_o;
  wire n473_o;
  wire n474_o;
  wire [7:0] n475_o;
  wire [1:0] n476_o;
  wire [1:0] n477_o;
  wire n478_o;
  wire n480_o;
  wire n482_o;
  wire [1:0] n484_o;
  wire n485_o;
  wire n487_o;
  wire n488_o;
  wire n489_o;
  wire n490_o;
  wire n491_o;
  wire [7:0] n492_o;
  wire [7:0] n493_o;
  wire n494_o;
  wire n495_o;
  wire n496_o;
  wire n498_o;
  wire n499_o;
  wire n501_o;
  wire n502_o;
  wire [7:0] n503_o;
  wire [7:0] n504_o;
  wire n506_o;
  wire [15:0] n507_o;
  wire [15:0] n508_o;
  wire n510_o;
  wire [15:0] n511_o;
  wire [15:0] n514_o;
  wire n516_o;
  wire n518_o;
  wire n520_o;
  wire [15:0] n523_o;
  wire [15:0] n524_o;
  wire n526_o;
  wire [7:0] n527_o;
  wire [7:0] n530_o;
  wire [15:0] n531_o;
  wire [15:0] n532_o;
  wire n534_o;
  wire n536_o;
  wire [7:0] n537_o;
  wire [7:0] n540_o;
  wire [15:0] n541_o;
  wire [15:0] n542_o;
  wire n544_o;
  wire [15:0] n546_o;
  wire [7:0] n547_o;
  wire n549_o;
  wire [7:0] n550_o;
  wire [7:0] n553_o;
  wire [15:0] n554_o;
  wire [15:0] n555_o;
  wire [15:0] n556_o;
  wire [15:0] n557_o;
  wire [15:0] n558_o;
  wire n560_o;
  wire [5:0] n561_o;
  wire [7:0] n562_o;
  wire [7:0] n563_o;
  wire [7:0] n564_o;
  wire [7:0] n565_o;
  wire [7:0] n566_o;
  wire [7:0] n567_o;
  reg [7:0] n568_o;
  wire [7:0] n569_o;
  wire [7:0] n570_o;
  wire [7:0] n571_o;
  wire [7:0] n572_o;
  wire [7:0] n573_o;
  wire [7:0] n574_o;
  reg [7:0] n575_o;
  reg [15:0] n576_o;
  wire [15:0] n577_o;
  wire [15:0] n578_o;
  wire [15:0] n579_o;
  wire [15:0] n580_o;
  wire [15:0] n581_o;
  wire [15:0] n582_o;
  wire [15:0] n584_o;
  wire [15:0] n586_o;
  wire [15:0] n587_o;
  wire [15:0] n588_o;
  wire [15:0] n589_o;
  wire [15:0] n590_o;
  wire [15:0] n591_o;
  wire [15:0] n592_o;
  wire [15:0] n593_o;
  wire [15:0] n594_o;
  wire [15:0] n595_o;
  wire [15:0] n596_o;
  wire [15:0] n597_o;
  wire [15:0] n598_o;
  wire n600_o;
  wire [15:0] n601_o;
  wire [7:0] n602_o;
  wire n603_o;
  wire n604_o;
  wire n606_o;
  wire n607_o;
  wire [7:0] n609_o;
  wire [2:0] n610_o;
  wire n611_o;
  wire n612_o;
  wire n615_o;
  wire n616_o;
  wire n617_o;
  wire n618_o;
  wire n619_o;
  wire [1:0] n621_o;
  wire [2:0] n622_o;
  wire n623_o;
  wire [1:0] n624_o;
  wire [1:0] n625_o;
  wire n628_o;
  wire n630_o;
  wire [1:0] n632_o;
  wire [2:0] n633_o;
  wire [1:0] n634_o;
  wire [15:0] n636_o;
  wire n637_o;
  wire [1:0] n638_o;
  wire [1:0] n639_o;
  wire [15:0] n642_o;
  wire [15:0] n643_o;
  wire n644_o;
  wire [3:0] n646_o;
  wire n648_o;
  wire n650_o;
  wire n651_o;
  wire n652_o;
  wire n653_o;
  wire n655_o;
  wire n656_o;
  wire n657_o;
  wire n658_o;
  wire n659_o;
  wire n660_o;
  wire [8:0] n662_o;
  wire [7:0] n663_o;
  wire [8:0] n665_o;
  wire [8:0] n666_o;
  wire n667_o;
  wire n668_o;
  wire n669_o;
  wire [8:0] n671_o;
  wire [8:0] n673_o;
  wire [8:0] n674_o;
  wire n675_o;
  wire n676_o;
  wire n677_o;
  wire n678_o;
  wire n679_o;
  wire n680_o;
  wire n681_o;
  wire n682_o;
  wire n683_o;
  wire n684_o;
  wire n685_o;
  wire n686_o;
  wire n687_o;
  wire n688_o;
  wire n689_o;
  wire n690_o;
  wire [2:0] n691_o;
  wire n692_o;
  wire [2:0] n693_o;
  wire [2:0] n694_o;
  wire n695_o;
  wire n696_o;
  wire n697_o;
  wire n698_o;
  wire n699_o;
  wire n700_o;
  wire n701_o;
  wire n702_o;
  wire n703_o;
  wire n704_o;
  wire n705_o;
  wire n706_o;
  wire n707_o;
  wire n708_o;
  wire n709_o;
  wire n710_o;
  wire n711_o;
  wire n712_o;
  wire n713_o;
  wire n714_o;
  wire n715_o;
  wire n716_o;
  wire n717_o;
  wire n718_o;
  wire n719_o;
  wire n720_o;
  wire n721_o;
  wire n722_o;
  wire n725_o;
  wire n726_o;
  wire n728_o;
  wire n730_o;
  wire n731_o;
  wire [7:0] n732_o;
  wire [15:0] n733_o;
  wire [15:0] n734_o;
  wire [15:0] n735_o;
  wire [15:0] n736_o;
  wire [15:0] n738_o;
  wire [15:0] n739_o;
  wire [15:0] n740_o;
  wire [15:0] n741_o;
  wire [15:0] n743_o;
  wire [15:0] n744_o;
  wire [2:0] n745_o;
  localparam [15:0] n746_o = 16'b0000000000000000;
  wire [9:0] n747_o;
  wire [2:0] n748_o;
  wire [15:0] n749_o;
  wire [15:0] n750_o;
  wire [15:0] n751_o;
  wire [15:0] n752_o;
  wire n753_o;
  wire n755_o;
  wire n757_o;
  wire n758_o;
  wire [15:0] n759_o;
  wire [15:0] n760_o;
  wire [15:0] n761_o;
  wire n763_o;
  wire n765_o;
  wire n766_o;
  wire n767_o;
  wire n768_o;
  wire n769_o;
  wire [15:0] n772_o;
  wire [15:0] n773_o;
  wire n774_o;
  wire n776_o;
  wire n777_o;
  wire n779_o;
  wire n781_o;
  wire n782_o;
  wire n783_o;
  wire [2:0] n784_o;
  wire n786_o;
  wire n787_o;
  wire [15:0] n789_o;
  wire [15:0] n791_o;
  wire [15:0] n792_o;
  wire [15:0] n793_o;
  wire n794_o;
  wire [15:0] n795_o;
  wire [7:0] n796_o;
  wire [1:0] n797_o;
  wire [7:0] n798_o;
  wire [7:0] n800_o;
  wire [7:0] n801_o;
  wire n802_o;
  wire n803_o;
  wire [15:0] n804_o;
  wire [7:0] n805_o;
  wire [7:0] n807_o;
  wire [7:0] n808_o;
  wire [15:0] n809_o;
  wire [15:0] n810_o;
  wire n811_o;
  wire [15:0] n812_o;
  wire [7:0] n813_o;
  wire [1:0] n814_o;
  wire n815_o;
  wire n816_o;
  wire n817_o;
  wire [3:0] n819_o;
  wire n822_o;
  wire n826_o;
  wire [7:0] n827_o;
  wire [7:0] n828_o;
  wire [7:0] n829_o;
  wire [7:0] n830_o;
  wire [7:0] n831_o;
  wire [7:0] n832_o;
  wire [7:0] n833_o;
  wire [7:0] n834_o;
  wire [7:0] n835_o;
  wire [7:0] n836_o;
  wire [7:0] n837_o;
  wire [7:0] n838_o;
  wire [7:0] n839_o;
  wire [7:0] n840_o;
  wire [7:0] n841_o;
  wire [7:0] n842_o;
  wire [7:0] n843_o;
  wire [7:0] n844_o;
  wire [7:0] n845_o;
  wire [7:0] n846_o;
  wire [7:0] n847_o;
  wire [7:0] n848_o;
  wire [7:0] n849_o;
  wire [7:0] n850_o;
  wire [7:0] n851_o;
  wire [7:0] n852_o;
  wire [7:0] n853_o;
  wire [7:0] n854_o;
  wire [7:0] n855_o;
  wire [7:0] n856_o;
  wire [7:0] n857_o;
  wire [7:0] n858_o;
  wire [7:0] n859_o;
  wire [7:0] n860_o;
  wire [7:0] n861_o;
  wire [7:0] n862_o;
  wire [7:0] n863_o;
  wire [7:0] n864_o;
  wire [7:0] n865_o;
  wire [7:0] n866_o;
  wire [7:0] n867_o;
  wire [7:0] n868_o;
  wire [7:0] n869_o;
  wire [7:0] n870_o;
  wire [7:0] n871_o;
  wire [7:0] n872_o;
  wire [7:0] n873_o;
  wire [7:0] n874_o;
  wire [7:0] n875_o;
  wire [7:0] n876_o;
  wire [7:0] n877_o;
  wire [7:0] n878_o;
  wire [7:0] n879_o;
  wire [7:0] n880_o;
  wire [7:0] n881_o;
  wire [7:0] n882_o;
  wire [7:0] n883_o;
  wire [7:0] n884_o;
  wire [7:0] n885_o;
  wire [7:0] n886_o;
  wire [7:0] n887_o;
  wire [7:0] n888_o;
  wire [7:0] n889_o;
  wire [7:0] n890_o;
  wire [7:0] n891_o;
  wire [7:0] n892_o;
  wire [7:0] n893_o;
  wire [7:0] n894_o;
  wire [7:0] n895_o;
  wire [7:0] n896_o;
  wire [7:0] n897_o;
  wire [7:0] n898_o;
  wire [7:0] n899_o;
  wire [7:0] n900_o;
  wire [7:0] n901_o;
  wire [7:0] n902_o;
  wire [7:0] n903_o;
  wire [7:0] n904_o;
  wire [7:0] n905_o;
  wire [7:0] n906_o;
  wire [7:0] n907_o;
  wire [7:0] n908_o;
  wire [7:0] n909_o;
  wire [7:0] n910_o;
  wire n911_o;
  wire [1:0] n912_o;
  wire n913_o;
  wire n915_o;
  wire n918_o;
  wire n919_o;
  wire n921_o;
  wire n924_o;
  wire n925_o;
  wire n927_o;
  wire n930_o;
  wire n931_o;
  wire n933_o;
  wire n936_o;
  wire n938_o;
  wire [2:0] n939_o;
  reg [7:0] n940_o;
  wire n941_o;
  wire n942_o;
  wire n943_o;
  wire n944_o;
  wire n945_o;
  reg n946_o;
  wire n947_o;
  wire n948_o;
  wire n949_o;
  wire n950_o;
  wire n951_o;
  reg n952_o;
  wire n953_o;
  wire n954_o;
  wire n955_o;
  wire n956_o;
  wire n957_o;
  reg n958_o;
  wire n959_o;
  wire n960_o;
  wire n961_o;
  wire n962_o;
  wire n963_o;
  reg n964_o;
  wire n965_o;
  wire n966_o;
  wire n967_o;
  wire n968_o;
  wire n969_o;
  reg n970_o;
  wire n971_o;
  wire n972_o;
  wire n973_o;
  wire n974_o;
  wire n975_o;
  reg n976_o;
  wire n977_o;
  wire n978_o;
  wire n979_o;
  wire n980_o;
  wire n981_o;
  reg n982_o;
  reg [7:0] n983_o;
  reg [7:0] n984_o;
  wire [7:0] n985_o;
  wire [6:0] n986_o;
  wire [6:0] n987_o;
  wire [6:0] n988_o;
  wire [6:0] n989_o;
  wire [6:0] n990_o;
  wire [6:0] n991_o;
  wire [6:0] n992_o;
  wire [7:0] n993_o;
  wire [7:0] n994_o;
  wire n995_o;
  wire [6:0] n996_o;
  wire [6:0] n997_o;
  wire [6:0] n998_o;
  wire [6:0] n999_o;
  wire [6:0] n1000_o;
  wire [6:0] n1001_o;
  wire n1002_o;
  wire n1003_o;
  wire n1004_o;
  wire n1005_o;
  wire n1006_o;
  wire n1007_o;
  wire n1008_o;
  wire [15:0] n1009_o;
  wire [15:0] n1010_o;
  wire n1011_o;
  wire n1012_o;
  wire n1014_o;
  wire n1015_o;
  wire [6:0] n1016_o;
  wire n1017_o;
  wire n1018_o;
  wire n1019_o;
  wire [7:0] n1020_o;
  wire [7:0] n1021_o;
  wire n1023_o;
  wire n1026_o;
  wire n1027_o;
  wire n1029_o;
  wire n1032_o;
  wire n1033_o;
  wire n1034_o;
  wire n1035_o;
  wire n1036_o;
  wire n1037_o;
  wire n1038_o;
  wire n1039_o;
  wire n1040_o;
  wire n1041_o;
  wire n1042_o;
  wire n1043_o;
  wire n1044_o;
  wire n1045_o;
  wire n1046_o;
  wire n1047_o;
  wire n1048_o;
  wire n1049_o;
  wire [6:0] n1050_o;
  wire n1055_o;
  wire n1056_o;
  wire n1057_o;
  wire n1059_o;
  wire n1060_o;
  wire n1061_o;
  wire n1062_o;
  wire n1063_o;
  wire [7:0] n1064_o;
  wire [3:0] n1065_o;
  wire [3:0] n1066_o;
  wire [7:0] n1067_o;
  wire [7:0] n1068_o;
  wire [3:0] n1069_o;
  wire [3:0] n1070_o;
  wire [7:0] n1071_o;
  wire [7:0] n1072_o;
  wire [7:0] n1073_o;
  wire n1074_o;
  wire [4:0] n1077_o;
  wire [4:0] n1078_o;
  wire [4:0] n1079_o;
  wire [4:0] n1081_o;
  wire n1084_o;
  wire n1085_o;
  wire n1086_o;
  wire n1087_o;
  wire [2:0] n1090_o;
  wire n1091_o;
  wire n1092_o;
  wire n1093_o;
  wire n1094_o;
  wire n1095_o;
  wire n1096_o;
  wire [1:0] n1108_o;
  wire [1:0] n1109_o;
  wire [1:0] n1110_o;
  wire [1:0] n1111_o;
  wire [1:0] n1112_o;
  wire n1113_o;
  wire n1114_o;
  wire n1115_o;
  wire n1116_o;
  wire n1117_o;
  wire n1119_o;
  wire n1120_o;
  wire n1121_o;
  wire [7:0] n1123_o;
  wire [7:0] n1124_o;
  wire n1125_o;
  wire n1126_o;
  wire n1127_o;
  wire n1128_o;
  wire n1129_o;
  wire n1130_o;
  wire n1131_o;
  wire n1132_o;
  wire n1133_o;
  wire n1134_o;
  wire n1135_o;
  wire n1136_o;
  wire n1137_o;
  wire n1138_o;
  wire n1139_o;
  wire n1140_o;
  wire n1141_o;
  wire n1142_o;
  wire n1150_o;
  wire n1151_o;
  wire n1152_o;
  wire n1153_o;
  wire n1154_o;
  wire n1155_o;
  wire n1156_o;
  wire n1158_o;
  wire n1159_o;
  wire n1161_o;
  wire n1162_o;
  wire n1163_o;
  wire n1164_o;
  wire n1165_o;
  wire n1167_o;
  wire n1168_o;
  wire n1169_o;
  wire n1171_o;
  wire n1173_o;
  wire n1175_o;
  wire n1177_o;
  wire n1179_o;
  wire [4:0] n1180_o;
  reg [7:0] n1181_o;
  reg [7:0] n1182_o;
  wire [7:0] n1183_o;
  reg [7:0] n1184_o;
  wire [7:0] n1185_o;
  wire [7:0] n1186_o;
  wire [7:0] n1187_o;
  wire [7:0] n1188_o;
  wire [7:0] n1189_o;
  wire [7:0] n1190_o;
  wire [7:0] n1191_o;
  wire [7:0] n1192_o;
  wire [7:0] n1193_o;
  reg [7:0] n1194_o;
  wire [7:0] n1195_o;
  wire [7:0] n1196_o;
  wire [7:0] n1197_o;
  wire [7:0] n1198_o;
  wire [7:0] n1199_o;
  wire [7:0] n1200_o;
  wire [7:0] n1201_o;
  wire [7:0] n1202_o;
  wire [7:0] n1203_o;
  reg [7:0] n1204_o;
  wire [7:0] n1205_o;
  wire [7:0] n1206_o;
  wire [7:0] n1207_o;
  wire [7:0] n1208_o;
  wire [7:0] n1209_o;
  wire [15:0] n1210_o;
  wire [15:0] n1211_o;
  wire [15:0] n1212_o;
  wire [7:0] n1213_o;
  wire [7:0] n1214_o;
  wire [7:0] n1215_o;
  wire [7:0] n1216_o;
  wire [7:0] n1217_o;
  wire n1218_o;
  wire n1219_o;
  wire [15:0] n1220_o;
  wire [15:0] n1221_o;
  wire n1222_o;
  wire [15:0] n1223_o;
  wire [7:0] n1224_o;
  wire [1:0] n1225_o;
  wire n1226_o;
  wire n1227_o;
  wire n1228_o;
  wire n1229_o;
  wire [4:0] n1230_o;
  wire n1231_o;
  wire n1232_o;
  wire [3:0] n1233_o;
  wire n1234_o;
  wire n1235_o;
  wire [2:0] n1236_o;
  wire n1237_o;
  wire [15:0] n1240_o;
  wire [7:0] n1241_o;
  wire [7:0] n1242_o;
  wire [7:0] n1243_o;
  wire [7:0] n1244_o;
  wire [7:0] n1245_o;
  wire [7:0] n1246_o;
  wire [7:0] n1247_o;
  wire [15:0] n1248_o;
  wire [15:0] n1249_o;
  wire n1250_o;
  wire [15:0] n1251_o;
  wire [7:0] n1252_o;
  wire [1:0] n1253_o;
  wire [1:0] n1254_o;
  wire [1:0] n1255_o;
  wire n1256_o;
  wire n1257_o;
  wire [4:0] n1258_o;
  wire n1259_o;
  wire n1260_o;
  wire [3:0] n1261_o;
  wire n1262_o;
  wire n1263_o;
  wire [2:0] n1264_o;
  wire n1265_o;
  wire [1:0] n1360_o;
  wire [2:0] n1361_o;
  wire n1362_o;
  wire n1364_o;
  wire n1365_o;
  wire [1:0] n1366_o;
  wire n1368_o;
  wire n1369_o;
  wire n1370_o;
  wire [2:0] n1372_o;
  wire [2:0] n1373_o;
  wire [1:0] n1374_o;
  wire [2:0] n1375_o;
  wire n1376_o;
  wire n1378_o;
  wire n1379_o;
  wire [1:0] n1380_o;
  wire n1382_o;
  wire n1383_o;
  wire n1384_o;
  wire [2:0] n1386_o;
  wire [2:0] n1387_o;
  wire [1:0] n1388_o;
  wire [2:0] n1389_o;
  wire n1390_o;
  wire [2:0] n1392_o;
  wire [2:0] n1393_o;
  wire n1394_o;
  wire n1396_o;
  wire n1397_o;
  wire n1399_o;
  wire n1400_o;
  wire n1401_o;
  wire [2:0] n1403_o;
  wire [2:0] n1404_o;
  wire n1407_o;
  wire n1409_o;
  wire n1411_o;
  wire n1412_o;
  wire n1413_o;
  wire [2:0] n1414_o;
  wire n1416_o;
  wire n1417_o;
  wire n1419_o;
  wire n1422_o;
  wire n1428_o;
  wire [1:0] n1435_o;
  wire [2:0] n1436_o;
  wire n1438_o;
  wire n1440_o;
  wire n1442_o;
  wire n1443_o;
  wire n1444_o;
  wire n1445_o;
  wire n1446_o;
  wire n1448_o;
  wire n1449_o;
  wire [2:0] n1450_o;
  wire n1451_o;
  wire [2:0] n1453_o;
  wire n1455_o;
  wire n1457_o;
  wire n1459_o;
  wire n1460_o;
  wire n1461_o;
  wire n1462_o;
  wire n1463_o;
  wire [1:0] n1464_o;
  wire n1466_o;
  wire n1467_o;
  wire [2:0] n1468_o;
  wire [2:0] n1470_o;
  wire n1472_o;
  wire n1473_o;
  wire [2:0] n1474_o;
  wire [2:0] n1476_o;
  wire n1478_o;
  wire n1479_o;
  wire [2:0] n1480_o;
  wire [2:0] n1482_o;
  wire n1484_o;
  wire n1485_o;
  wire [2:0] n1486_o;
  wire [15:0] n1488_o;
  wire n1489_o;
  wire [15:0] n1490_o;
  wire [15:0] n1492_o;
  wire n1496_o;
  wire n1497_o;
  wire n1498_o;
  wire n1499_o;
  wire n1500_o;
  wire n1502_o;
  wire n1503_o;
  wire n1504_o;
  wire n1505_o;
  wire n1506_o;
  wire n1507_o;
  wire n1509_o;
  wire n1511_o;
  wire n1512_o;
  wire n1514_o;
  wire n1515_o;
  wire n1517_o;
  wire n1518_o;
  wire n1520_o;
  wire n1521_o;
  wire n1523_o;
  wire n1524_o;
  reg n1526_o;
  reg n1528_o;
  wire n1530_o;
  wire n1533_o;
  wire n1536_o;
  wire n1538_o;
  wire n1539_o;
  wire n1540_o;
  wire n1542_o;
  wire n1544_o;
  wire n1545_o;
  wire n1547_o;
  wire n1548_o;
  wire n1550_o;
  wire n1551_o;
  wire n1553_o;
  wire n1555_o;
  wire n1556_o;
  wire n1557_o;
  wire n1558_o;
  wire [1:0] n1559_o;
  wire n1561_o;
  wire n1563_o;
  wire n1564_o;
  wire n1566_o;
  wire n1567_o;
  reg n1569_o;
  reg n1571_o;
  wire n1572_o;
  wire n1573_o;
  wire n1578_o;
  wire n1579_o;
  wire [7:0] n1580_o;
  wire [7:0] n1581_o;
  wire [7:0] n1582_o;
  wire [7:0] n1583_o;
  wire n1585_o;
  wire n1586_o;
  wire [7:0] n1587_o;
  wire [7:0] n1588_o;
  wire [7:0] n1589_o;
  wire [7:0] n1590_o;
  wire n1591_o;
  wire n1593_o;
  wire n1595_o;
  wire n1596_o;
  wire n1598_o;
  wire n1600_o;
  wire n1601_o;
  wire n1602_o;
  wire n1603_o;
  wire [7:0] n1604_o;
  wire [7:0] n1605_o;
  wire [7:0] n1606_o;
  wire [7:0] n1607_o;
  wire [7:0] u_regs_n1609;
  wire [7:0] u_regs_n1610;
  wire [7:0] u_regs_n1611;
  wire [7:0] u_regs_n1612;
  wire [7:0] u_regs_n1613;
  wire [7:0] u_regs_n1614;
  wire [127:0] u_regs_n1615;
  wire [127:0] n1616_o;
  wire [7:0] u_regs_doah;
  wire [7:0] u_regs_doal;
  wire [7:0] u_regs_dobh;
  wire [7:0] u_regs_dobl;
  wire [7:0] u_regs_doch;
  wire [7:0] u_regs_docl;
  wire [127:0] u_regs_dor;
  wire n1635_o;
  wire n1636_o;
  wire [7:0] n1637_o;
  wire [7:0] n1638_o;
  wire [7:0] n1639_o;
  wire n1641_o;
  wire n1643_o;
  wire n1644_o;
  wire n1646_o;
  wire n1647_o;
  wire n1649_o;
  wire n1650_o;
  wire n1652_o;
  wire n1653_o;
  wire n1655_o;
  wire n1656_o;
  wire n1658_o;
  wire [7:0] n1659_o;
  wire n1661_o;
  wire [7:0] n1662_o;
  wire n1664_o;
  wire n1666_o;
  wire n1668_o;
  wire [7:0] n1669_o;
  wire n1671_o;
  wire [7:0] n1672_o;
  wire n1674_o;
  wire n1676_o;
  wire n1677_o;
  wire [7:0] n1680_o;
  wire n1682_o;
  wire [9:0] n1683_o;
  reg [7:0] n1686_o;
  wire n1688_o;
  wire n1689_o;
  wire [7:0] n1690_o;
  wire [7:0] n1691_o;
  wire [7:0] n1692_o;
  wire n1694_o;
  wire n1696_o;
  wire n1697_o;
  wire n1699_o;
  wire n1700_o;
  wire n1702_o;
  wire n1703_o;
  wire n1705_o;
  wire n1706_o;
  wire n1708_o;
  wire n1709_o;
  wire n1711_o;
  wire [7:0] n1712_o;
  wire n1714_o;
  wire [7:0] n1715_o;
  wire n1717_o;
  wire n1719_o;
  wire [5:0] n1720_o;
  reg [7:0] n1723_o;
  wire [7:0] n1724_o;
  wire [7:0] n1725_o;
  wire n1733_o;
  wire n1735_o;
  wire n1736_o;
  wire n1738_o;
  wire n1740_o;
  wire n1741_o;
  wire n1743_o;
  wire n1744_o;
  wire n1745_o;
  wire n1748_o;
  wire n1754_o;
  wire n1755_o;
  wire n1756_o;
  reg n1757_oldnmi_n;
  wire n1760_o;
  wire n1762_o;
  wire n1763_o;
  wire n1764_o;
  wire n1765_o;
  wire n1767_o;
  wire n1768_o;
  wire n1769_o;
  wire n1771_o;
  wire n1773_o;
  wire n1774_o;
  wire n1775_o;
  wire n1776_o;
  wire n1777_o;
  wire n1778_o;
  wire n1779_o;
  wire n1780_o;
  wire n1781_o;
  wire n1782_o;
  wire n1783_o;
  wire n1784_o;
  wire n1785_o;
  wire n1786_o;
  wire n1787_o;
  wire n1788_o;
  wire n1789_o;
  wire n1790_o;
  wire n1791_o;
  wire n1792_o;
  wire n1793_o;
  wire n1794_o;
  wire n1796_o;
  wire n1797_o;
  wire n1799_o;
  wire n1800_o;
  wire n1802_o;
  wire n1803_o;
  wire n1804_o;
  wire n1805_o;
  wire n1807_o;
  wire n1809_o;
  wire n1811_o;
  wire n1812_o;
  wire n1813_o;
  wire n1814_o;
  wire n1816_o;
  wire n1818_o;
  wire n1820_o;
  wire n1821_o;
  wire n1822_o;
  wire n1824_o;
  wire n1825_o;
  wire n1826_o;
  wire n1828_o;
  wire n1829_o;
  wire n1830_o;
  wire n1832_o;
  wire n1836_o;
  wire n1840_o;
  wire [2:0] n1842_o;
  wire n1843_o;
  wire n1844_o;
  wire n1846_o;
  wire n1847_o;
  wire n1848_o;
  wire n1849_o;
  wire n1851_o;
  wire n1852_o;
  wire n1853_o;
  wire n1854_o;
  wire n1856_o;
  wire n1857_o;
  wire n1858_o;
  wire n1859_o;
  wire n1861_o;
  wire n1863_o;
  wire n1866_o;
  wire n1868_o;
  wire n1869_o;
  wire n1871_o;
  wire n1873_o;
  wire n1877_o;
  wire [2:0] n1880_o;
  wire n1882_o;
  wire [2:0] n1884_o;
  wire n1885_o;
  wire n1886_o;
  wire n1887_o;
  wire n1888_o;
  wire n1889_o;
  wire n1890_o;
  wire [2:0] n1891_o;
  wire n1892_o;
  wire n1893_o;
  wire n1894_o;
  wire n1895_o;
  wire n1896_o;
  wire n1897_o;
  wire [2:0] n1899_o;
  wire n1900_o;
  wire n1901_o;
  wire n1902_o;
  wire [2:0] n1903_o;
  wire n1904_o;
  wire n1905_o;
  wire n1906_o;
  wire [2:0] n1908_o;
  wire [2:0] n1909_o;
  wire n1910_o;
  wire n1911_o;
  wire n1914_o;
  wire n1915_o;
  wire [2:0] n1916_o;
  wire n1917_o;
  wire n1918_o;
  wire n1919_o;
  wire n1920_o;
  wire n1922_o;
  wire n1923_o;
  wire n1924_o;
  wire n1925_o;
  wire n1926_o;
  wire [2:0] n1928_o;
  wire [2:0] n1929_o;
  wire n1930_o;
  wire [2:0] n1931_o;
  wire [2:0] n1932_o;
  wire n1933_o;
  wire n1934_o;
  wire n1935_o;
  wire n1937_o;
  wire n1938_o;
  wire [2:0] n1939_o;
  wire n1940_o;
  wire n1941_o;
  wire n1942_o;
  wire [2:0] n1943_o;
  wire [2:0] n1944_o;
  wire n1945_o;
  wire n1946_o;
  wire n1947_o;
  wire n1949_o;
  wire n1951_o;
  wire [2:0] n1952_o;
  wire n1953_o;
  wire n1954_o;
  wire n1955_o;
  wire [2:0] n1956_o;
  wire [2:0] n1957_o;
  wire n1958_o;
  wire n1959_o;
  wire n1960_o;
  wire n1961_o;
  wire n1962_o;
  wire [2:0] n1963_o;
  wire n1964_o;
  wire n1965_o;
  wire n1967_o;
  wire n1969_o;
  wire n1970_o;
  wire n1971_o;
  wire n1972_o;
  wire n1973_o;
  wire n1974_o;
  wire n1975_o;
  wire n1976_o;
  wire n1977_o;
  wire n1978_o;
  wire n1979_o;
  wire n1980_o;
  wire n1981_o;
  wire n1982_o;
  wire n1983_o;
  wire n1984_o;
  wire n1985_o;
  wire [2:0] n1986_o;
  wire [2:0] n1987_o;
  wire n1988_o;
  wire n1989_o;
  wire n1990_o;
  wire n1991_o;
  wire n1992_o;
  wire n1993_o;
  wire [2:0] n1994_o;
  wire n1995_o;
  wire n1996_o;
  wire n1997_o;
  wire n1998_o;
  wire n1999_o;
  wire n2000_o;
  wire n2049_o;
  wire n2050_o;
  reg n2051_q;
  wire n2054_o;
  wire n2055_o;
  wire n2056_o;
  reg [7:0] n2058_q;
  reg [7:0] n2059_q;
  reg [7:0] n2060_q;
  reg [7:0] n2061_q;
  reg [7:0] n2062_q;
  reg [7:0] n2063_q;
  reg [15:0] n2064_q;
  reg [15:0] n2065_q;
  wire [15:0] n2066_o;
  wire [15:0] n2067_o;
  wire [15:0] n2068_o;
  wire [2:0] n2069_o;
  reg [2:0] n2070_q;
  wire [2:0] n2071_o;
  reg [2:0] n2072_q;
  wire [2:0] n2073_o;
  reg [2:0] n2074_q;
  reg n2075_q;
  reg [15:0] n2076_q;
  reg [7:0] n2077_q;
  reg [1:0] n2078_q;
  wire [15:0] n2079_o;
  reg [15:0] n2080_q;
  reg [2:0] n2081_q;
  reg [2:0] n2082_q;
  reg n2083_q;
  reg n2084_q;
  reg n2085_q;
  reg n2086_q;
  reg n2087_q;
  reg n2088_q;
  reg [1:0] n2089_q;
  reg [1:0] n2090_q;
  reg [2:0] n2091_q;
  reg n2092_q;
  reg n2093_q;
  reg n2094_q;
  reg n2095_q;
  reg n2096_q;
  wire n2097_o;
  reg n2098_q;
  wire [7:0] n2099_o;
  reg [7:0] n2100_q;
  wire [7:0] n2101_o;
  reg [7:0] n2102_q;
  reg [4:0] n2103_q;
  reg n2104_q;
  reg n2105_q;
  reg [3:0] n2106_q;
  reg n2107_q;
  reg n2108_q;
  reg [2:0] n2109_q;
  reg n2110_q;
  reg n2111_q;
  reg n2112_q;
  reg n2113_q;
  wire n2114_o;
  reg n2115_q;
  reg [15:0] n2116_q;
  reg [7:0] n2117_q;
  assign m1_n = n2113_q;
  assign iorq = iorq_i;
  assign noread = mcode_n247;
  assign write = mcode_n248;
  assign rfsh_n = n2115_q;
  assign halt_n = n1754_o;
  assign busak_n = n1755_o;
  assign a = n2116_q;
  assign dout = n2117_q;
  assign mc = mcycle;
  assign ts = tstate;
  assign intcycle_n = n1756_o;
  assign inte = inte_ff1;
  assign stop = i_djnz;
  assign regs = n183_o;
  /* T80.vhd:263:16  */
  assign acc = n2058_q; // (signal)
  /* T80.vhd:263:21  */
  assign f = n2059_q; // (signal)
  /* T80.vhd:264:16  */
  assign ap = n2060_q; // (signal)
  /* T80.vhd:264:20  */
  assign fp = n2061_q; // (signal)
  /* T80.vhd:265:16  */
  assign i = n2062_q; // (signal)
  /* T80.vhd:266:16  */
  assign r = n2063_q; // (signal)
  /* T80.vhd:267:16  */
  assign sp = n2064_q; // (signal)
  /* T80.vhd:267:20  */
  assign pc = n2065_q; // (signal)
  /* T80.vhd:269:16  */
  assign regdih = n1606_o; // (signal)
  /* T80.vhd:270:16  */
  assign regdil = n1607_o; // (signal)
  /* T80.vhd:271:16  */
  assign regbusa = n2066_o; // (signal)
  /* T80.vhd:272:16  */
  assign regbusb = n2067_o; // (signal)
  /* T80.vhd:273:16  */
  assign regbusc = n2068_o; // (signal)
  /* T80.vhd:274:16  */
  assign regaddra_r = n2070_q; // (signal)
  /* T80.vhd:275:16  */
  assign regaddra = n1450_o; // (signal)
  /* T80.vhd:276:16  */
  assign regaddrb_r = n2072_q; // (signal)
  /* T80.vhd:277:16  */
  assign regaddrb = n1486_o; // (signal)
  /* T80.vhd:278:16  */
  assign regaddrc = n2074_q; // (signal)
  /* T80.vhd:279:16  */
  assign regweh = n1572_o; // (signal)
  /* T80.vhd:280:16  */
  assign regwel = n1573_o; // (signal)
  /* T80.vhd:281:16  */
  assign alternate = n2075_q; // (signal)
  /* T80.vhd:284:16  */
  assign wz = n2076_q; // (signal)
  /* T80.vhd:285:16  */
  assign ir = n2077_q; // (signal)
  /* T80.vhd:286:16  */
  assign iset = n2078_q; // (signal)
  /* T80.vhd:287:16  */
  assign regbusa_r = n2080_q; // (signal)
  /* T80.vhd:289:16  */
  assign id16 = n1490_o; // (signal)
  /* T80.vhd:290:16  */
  assign save_mux = n381_o; // (signal)
  /* T80.vhd:292:16  */
  assign tstate = n2081_q; // (signal)
  /* T80.vhd:293:16  */
  assign mcycle = n2082_q; // (signal)
  /* T80.vhd:294:16  */
  assign inte_ff1 = n2083_q; // (signal)
  /* T80.vhd:295:16  */
  assign inte_ff2 = n2084_q; // (signal)
  /* T80.vhd:296:16  */
  assign halt_ff = n2085_q; // (signal)
  /* T80.vhd:297:16  */
  assign busreq_s = n2086_q; // (signal)
  /* T80.vhd:298:16  */
  assign busack = n2087_q; // (signal)
  /* T80.vhd:299:16  */
  assign clken = n354_o; // (signal)
  /* T80.vhd:300:16  */
  assign nmi_s = n2088_q; // (signal)
  /* T80.vhd:301:16  */
  assign istatus = n2089_q; // (signal)
  /* T80.vhd:303:16  */
  assign di_reg = di; // (signal)
  /* T80.vhd:304:16  */
  assign t_res = n357_o; // (signal)
  /* T80.vhd:305:16  */
  assign xy_state = n2090_q; // (signal)
  /* T80.vhd:306:16  */
  assign pre_xy_f_m = n2091_q; // (signal)
  /* T80.vhd:307:16  */
  assign nextis_xy_fetch = n379_o; // (signal)
  /* T80.vhd:308:16  */
  assign xy_ind = n2092_q; // (signal)
  /* T80.vhd:309:16  */
  assign no_btr = n2093_q; // (signal)
  /* T80.vhd:310:16  */
  assign btr_r = n2094_q; // (signal)
  /* T80.vhd:311:16  */
  assign auto_wait = n2056_o; // (signal)
  /* T80.vhd:312:16  */
  assign auto_wait_t1 = n2095_q; // (signal)
  /* T80.vhd:313:16  */
  assign auto_wait_t2 = n2096_q; // (signal)
  /* T80.vhd:314:16  */
  assign incdecz = n2098_q; // (signal)
  /* T80.vhd:317:16  */
  assign busb = n2100_q; // (signal)
  /* T80.vhd:318:16  */
  assign busa = n2102_q; // (signal)
  /* T80.vhd:319:16  */
  assign alu_q = u_alu_n347; // (signal)
  /* T80.vhd:320:16  */
  assign f_out = u_alu_n348; // (signal)
  /* T80.vhd:323:16  */
  assign read_to_reg_r = n2103_q; // (signal)
  /* T80.vhd:324:16  */
  assign arith16_r = n2104_q; // (signal)
  /* T80.vhd:325:16  */
  assign z16_r = n2105_q; // (signal)
  /* T80.vhd:326:16  */
  assign alu_op_r = n2106_q; // (signal)
  /* T80.vhd:327:16  */
  assign save_alu_r = n2107_q; // (signal)
  /* T80.vhd:328:16  */
  assign preservec_r = n2108_q; // (signal)
  /* T80.vhd:329:16  */
  assign mcycles = n2109_q; // (signal)
  /* T80.vhd:332:16  */
  assign mcycles_d = mcode_n202; // (signal)
  /* T80.vhd:333:16  */
  assign tstates = mcode_n203; // (signal)
  /* T80.vhd:334:16  */
  assign intcycle = n2110_q; // (signal)
  /* T80.vhd:335:16  */
  assign nmicycle = n2111_q; // (signal)
  /* T80.vhd:336:16  */
  assign inc_pc = mcode_n205; // (signal)
  /* T80.vhd:337:16  */
  assign inc_wz = mcode_n206; // (signal)
  /* T80.vhd:338:16  */
  assign incdec_16 = mcode_n207; // (signal)
  /* T80.vhd:339:16  */
  assign prefix = mcode_n204; // (signal)
  /* T80.vhd:340:16  */
  assign read_to_acc = mcode_n209; // (signal)
  /* T80.vhd:341:16  */
  assign read_to_reg = mcode_n208; // (signal)
  /* T80.vhd:342:16  */
  assign set_busb_to = mcode_n211; // (signal)
  /* T80.vhd:343:16  */
  assign set_busa_to = mcode_n210; // (signal)
  /* T80.vhd:344:16  */
  assign alu_op = mcode_n212; // (signal)
  /* T80.vhd:345:16  */
  assign save_alu = mcode_n213; // (signal)
  /* T80.vhd:346:16  */
  assign preservec = mcode_n214; // (signal)
  /* T80.vhd:347:16  */
  assign arith16 = mcode_n215; // (signal)
  /* T80.vhd:348:16  */
  assign set_addr_to = mcode_n216; // (signal)
  /* T80.vhd:349:16  */
  assign jump = mcode_n218; // (signal)
  /* T80.vhd:350:16  */
  assign jumpe = mcode_n219; // (signal)
  /* T80.vhd:351:16  */
  assign jumpxy = mcode_n220; // (signal)
  /* T80.vhd:352:16  */
  assign call = mcode_n221; // (signal)
  /* T80.vhd:353:16  */
  assign rstp = mcode_n222; // (signal)
  /* T80.vhd:354:16  */
  assign ldz = mcode_n223; // (signal)
  /* T80.vhd:355:16  */
  assign ldw = mcode_n224; // (signal)
  /* T80.vhd:356:16  */
  assign ldsphl = mcode_n225; // (signal)
  /* T80.vhd:357:16  */
  assign iorq_i = mcode_n217; // (signal)
  /* T80.vhd:358:16  */
  assign special_ld = mcode_n226; // (signal)
  /* T80.vhd:359:16  */
  assign exchangedh = mcode_n227; // (signal)
  /* T80.vhd:360:16  */
  assign exchangerp = mcode_n228; // (signal)
  /* T80.vhd:361:16  */
  assign exchangeaf = mcode_n229; // (signal)
  /* T80.vhd:362:16  */
  assign exchangers = mcode_n230; // (signal)
  /* T80.vhd:363:16  */
  assign i_djnz = mcode_n231; // (signal)
  /* T80.vhd:364:16  */
  assign i_cpl = mcode_n232; // (signal)
  /* T80.vhd:365:16  */
  assign i_ccf = mcode_n233; // (signal)
  /* T80.vhd:366:16  */
  assign i_scf = mcode_n234; // (signal)
  /* T80.vhd:367:16  */
  assign i_retn = mcode_n235; // (signal)
  /* T80.vhd:368:16  */
  assign i_bt = mcode_n236; // (signal)
  /* T80.vhd:369:16  */
  assign i_bc = mcode_n237; // (signal)
  /* T80.vhd:370:16  */
  assign i_btr = mcode_n238; // (signal)
  /* T80.vhd:371:16  */
  assign i_rld = mcode_n239; // (signal)
  /* T80.vhd:372:16  */
  assign i_rrd = mcode_n240; // (signal)
  /* T80.vhd:373:16  */
  assign i_rxdd = n2112_q; // (signal)
  /* T80.vhd:374:16  */
  assign i_inrc = mcode_n241; // (signal)
  /* T80.vhd:375:16  */
  assign setwz = mcode_n242; // (signal)
  /* T80.vhd:376:16  */
  assign setdi = mcode_n243; // (signal)
  /* T80.vhd:377:16  */
  assign setei = mcode_n244; // (signal)
  /* T80.vhd:378:16  */
  assign imode = mcode_n245; // (signal)
  /* T80.vhd:379:16  */
  assign halt = mcode_n246; // (signal)
  /* T80.vhd:380:16  */
  assign xybit_undoc = mcode_n249; // (signal)
  /* T80.vhd:381:16  */
  assign dor = u_regs_n1615; // (signal)
  /* T80.vhd:385:26  */
  assign n171_o = {inte_ff2, inte_ff1};
  /* T80.vhd:385:37  */
  assign n172_o = {n171_o, istatus};
  /* T80.vhd:385:47  */
  assign n173_o = {n172_o, dor};
  /* T80.vhd:385:53  */
  assign n174_o = {n173_o, pc};
  /* T80.vhd:385:76  */
  assign n175_o = {n174_o, sp};
  /* T80.vhd:385:99  */
  assign n176_o = {n175_o, r};
  /* T80.vhd:385:121  */
  assign n177_o = {n176_o, i};
  /* T80.vhd:385:125  */
  assign n178_o = {n177_o, fp};
  /* T80.vhd:385:130  */
  assign n179_o = {n178_o, ap};
  /* T80.vhd:385:135  */
  assign n180_o = {n179_o, f};
  /* T80.vhd:385:139  */
  assign n181_o = {n180_o, acc};
  /* T80.vhd:385:160  */
  assign n182_o = ~alternate;
  /* T80.vhd:385:145  */
  assign n183_o = n182_o ? n181_o : n201_o;
  /* T80.vhd:386:40  */
  assign n184_o = {inte_ff2, inte_ff1};
  /* T80.vhd:386:51  */
  assign n185_o = {n184_o, istatus};
  /* T80.vhd:386:66  */
  assign n186_o = dor[127:112];
  /* T80.vhd:386:61  */
  assign n187_o = {n185_o, n186_o};
  /* T80.vhd:386:88  */
  assign n188_o = dor[47:0];
  /* T80.vhd:386:83  */
  assign n189_o = {n187_o, n188_o};
  /* T80.vhd:386:107  */
  assign n190_o = dor[63:48];
  /* T80.vhd:386:102  */
  assign n191_o = {n189_o, n190_o};
  /* T80.vhd:386:127  */
  assign n192_o = dor[111:64];
  /* T80.vhd:386:122  */
  assign n193_o = {n191_o, n192_o};
  /* T80.vhd:386:143  */
  assign n194_o = {n193_o, pc};
  /* T80.vhd:387:70  */
  assign n195_o = {n194_o, sp};
  /* T80.vhd:387:93  */
  assign n196_o = {n195_o, r};
  /* T80.vhd:387:115  */
  assign n197_o = {n196_o, i};
  /* T80.vhd:387:119  */
  assign n198_o = {n197_o, fp};
  /* T80.vhd:387:124  */
  assign n199_o = {n198_o, ap};
  /* T80.vhd:387:129  */
  assign n200_o = {n199_o, f};
  /* T80.vhd:387:133  */
  assign n201_o = {n200_o, acc};
  /* T80.vhd:408:40  */
  assign mcode_n202 = mcode_mcycles; // (signal)
  /* T80.vhd:409:40  */
  assign mcode_n203 = mcode_tstates; // (signal)
  /* T80.vhd:410:40  */
  assign mcode_n204 = mcode_prefix; // (signal)
  /* T80.vhd:411:40  */
  assign mcode_n205 = mcode_inc_pc; // (signal)
  /* T80.vhd:412:40  */
  assign mcode_n206 = mcode_inc_wz; // (signal)
  /* T80.vhd:413:40  */
  assign mcode_n207 = mcode_incdec_16; // (signal)
  /* T80.vhd:415:40  */
  assign mcode_n208 = mcode_read_to_reg; // (signal)
  /* T80.vhd:414:40  */
  assign mcode_n209 = mcode_read_to_acc; // (signal)
  /* T80.vhd:417:40  */
  assign mcode_n210 = mcode_set_busa_to; // (signal)
  /* T80.vhd:416:40  */
  assign mcode_n211 = mcode_set_busb_to; // (signal)
  /* T80.vhd:418:40  */
  assign mcode_n212 = mcode_alu_op; // (signal)
  /* T80.vhd:419:40  */
  assign mcode_n213 = mcode_save_alu; // (signal)
  /* T80.vhd:420:40  */
  assign mcode_n214 = mcode_preservec; // (signal)
  /* T80.vhd:421:40  */
  assign mcode_n215 = mcode_arith16; // (signal)
  /* T80.vhd:422:40  */
  assign mcode_n216 = mcode_set_addr_to; // (signal)
  /* T80.vhd:423:40  */
  assign mcode_n217 = mcode_iorq; // (signal)
  /* T80.vhd:424:40  */
  assign mcode_n218 = mcode_jump; // (signal)
  /* T80.vhd:425:40  */
  assign mcode_n219 = mcode_jumpe; // (signal)
  /* T80.vhd:426:40  */
  assign mcode_n220 = mcode_jumpxy; // (signal)
  /* T80.vhd:427:40  */
  assign mcode_n221 = mcode_call; // (signal)
  /* T80.vhd:428:40  */
  assign mcode_n222 = mcode_rstp; // (signal)
  /* T80.vhd:429:40  */
  assign mcode_n223 = mcode_ldz; // (signal)
  /* T80.vhd:430:40  */
  assign mcode_n224 = mcode_ldw; // (signal)
  /* T80.vhd:431:40  */
  assign mcode_n225 = mcode_ldsphl; // (signal)
  /* T80.vhd:432:40  */
  assign mcode_n226 = mcode_special_ld; // (signal)
  /* T80.vhd:433:40  */
  assign mcode_n227 = mcode_exchangedh; // (signal)
  /* T80.vhd:434:40  */
  assign mcode_n228 = mcode_exchangerp; // (signal)
  /* T80.vhd:435:40  */
  assign mcode_n229 = mcode_exchangeaf; // (signal)
  /* T80.vhd:436:40  */
  assign mcode_n230 = mcode_exchangers; // (signal)
  /* T80.vhd:437:40  */
  assign mcode_n231 = mcode_i_djnz; // (signal)
  /* T80.vhd:438:40  */
  assign mcode_n232 = mcode_i_cpl; // (signal)
  /* T80.vhd:439:40  */
  assign mcode_n233 = mcode_i_ccf; // (signal)
  /* T80.vhd:440:40  */
  assign mcode_n234 = mcode_i_scf; // (signal)
  /* T80.vhd:441:40  */
  assign mcode_n235 = mcode_i_retn; // (signal)
  /* T80.vhd:442:40  */
  assign mcode_n236 = mcode_i_bt; // (signal)
  /* T80.vhd:443:40  */
  assign mcode_n237 = mcode_i_bc; // (signal)
  /* T80.vhd:444:40  */
  assign mcode_n238 = mcode_i_btr; // (signal)
  /* T80.vhd:445:40  */
  assign mcode_n239 = mcode_i_rld; // (signal)
  /* T80.vhd:446:40  */
  assign mcode_n240 = mcode_i_rrd; // (signal)
  /* T80.vhd:447:40  */
  assign mcode_n241 = mcode_i_inrc; // (signal)
  /* T80.vhd:448:40  */
  assign mcode_n242 = mcode_setwz; // (signal)
  /* T80.vhd:449:40  */
  assign mcode_n243 = mcode_setdi; // (signal)
  /* T80.vhd:450:40  */
  assign mcode_n244 = mcode_setei; // (signal)
  /* T80.vhd:451:40  */
  assign mcode_n245 = mcode_imode; // (signal)
  /* T80.vhd:452:40  */
  assign mcode_n246 = mcode_halt; // (signal)
  /* T80.vhd:453:40  */
  assign mcode_n247 = mcode_noread; // (signal)
  /* T80.vhd:454:40  */
  assign mcode_n248 = mcode_write; // (signal)
  /* T80.vhd:455:40  */
  assign mcode_n249 = mcode_xybit_undoc; // (signal)
  /* T80.vhd:389:9  */
  t8080_mcode mcode (
    .ir(ir),
    .iset(iset),
    .mcycle(mcycle),
    .f(f),
    .nmicycle(nmicycle),
    .intcycle(intcycle),
    .xy_state(xy_state),
    .mcycles(mcode_mcycles),
    .tstates(mcode_tstates),
    .prefix(mcode_prefix),
    .inc_pc(mcode_inc_pc),
    .inc_wz(mcode_inc_wz),
    .incdec_16(mcode_incdec_16),
    .read_to_reg(mcode_read_to_reg),
    .read_to_acc(mcode_read_to_acc),
    .set_busa_to(mcode_set_busa_to),
    .set_busb_to(mcode_set_busb_to),
    .alu_op(mcode_alu_op),
    .save_alu(mcode_save_alu),
    .preservec(mcode_preservec),
    .arith16(mcode_arith16),
    .set_addr_to(mcode_set_addr_to),
    .iorq(mcode_iorq),
    .jump(mcode_jump),
    .jumpe(mcode_jumpe),
    .jumpxy(mcode_jumpxy),
    .call(mcode_call),
    .rstp(mcode_rstp),
    .ldz(mcode_ldz),
    .ldw(mcode_ldw),
    .ldsphl(mcode_ldsphl),
    .special_ld(mcode_special_ld),
    .exchangedh(mcode_exchangedh),
    .exchangerp(mcode_exchangerp),
    .exchangeaf(mcode_exchangeaf),
    .exchangers(mcode_exchangers),
    .i_djnz(mcode_i_djnz),
    .i_cpl(mcode_i_cpl),
    .i_ccf(mcode_i_ccf),
    .i_scf(mcode_i_scf),
    .i_retn(mcode_i_retn),
    .i_bt(mcode_i_bt),
    .i_bc(mcode_i_bc),
    .i_btr(mcode_i_btr),
    .i_rld(mcode_i_rld),
    .i_rrd(mcode_i_rrd),
    .i_inrc(mcode_i_inrc),
    .setwz(mcode_setwz),
    .setdi(mcode_setdi),
    .setei(mcode_setei),
    .imode(mcode_imode),
    .halt(mcode_halt),
    .noread(mcode_noread),
    .write(mcode_write),
    .xybit_undoc(mcode_xybit_undoc));
  /* T80.vhd:474:38  */
  assign n346_o = ir[5:0];
  /* T80.vhd:479:36  */
  assign u_alu_n347 = u_alu_q; // (signal)
  /* T80.vhd:480:36  */
  assign u_alu_n348 = u_alu_f_out; // (signal)
  /* T80.vhd:457:9  */
  t8080_alu u_alu (
    .arith16(arith16_r),
    .z16(z16_r),
    .wz(wz),
    .xy_state(xy_state),
    .alu_op(alu_op_r),
    .ir(n346_o),
    .iset(iset),
    .busa(busa),
    .busb(busb),
    .f_in(f),
    .q(u_alu_q),
    .f_out(u_alu_f_out));
  /* T80.vhd:482:26  */
  assign n353_o = ~busack;
  /* T80.vhd:482:22  */
  assign n354_o = cen & n353_o;
  /* T80.vhd:484:34  */
  assign n356_o = tstate == tstates;
  /* T80.vhd:484:22  */
  assign n357_o = n356_o ? 1'b1 : 1'b0;
  /* T80.vhd:486:46  */
  assign n361_o = xy_state != 2'b00;
  /* T80.vhd:486:65  */
  assign n362_o = ~xy_ind;
  /* T80.vhd:486:54  */
  assign n363_o = n362_o & n361_o;
  /* T80.vhd:487:71  */
  assign n365_o = set_addr_to == 3'b010;
  /* T80.vhd:488:65  */
  assign n367_o = mcycle == 3'b001;
  /* T80.vhd:488:80  */
  assign n369_o = ir == 8'b11001011;
  /* T80.vhd:488:73  */
  assign n370_o = n369_o & n367_o;
  /* T80.vhd:487:78  */
  assign n371_o = n365_o | n370_o;
  /* T80.vhd:489:65  */
  assign n373_o = mcycle == 3'b001;
  /* T80.vhd:489:80  */
  assign n375_o = ir == 8'b00110110;
  /* T80.vhd:489:73  */
  assign n376_o = n375_o & n373_o;
  /* T80.vhd:488:94  */
  assign n377_o = n371_o | n376_o;
  /* T80.vhd:486:71  */
  assign n378_o = n377_o & n363_o;
  /* T80.vhd:486:32  */
  assign n379_o = n378_o ? 1'b1 : 1'b0;
  /* T80.vhd:491:26  */
  assign n381_o = exchangerp ? busb : n383_o;
  /* T80.vhd:492:40  */
  assign n382_o = ~save_alu_r;
  /* T80.vhd:491:48  */
  assign n383_o = n382_o ? di_reg : alu_q;
  /* T80.vhd:499:28  */
  assign n388_o = ~reset_n;
  /* T80.vhd:532:43  */
  assign n390_o = dir[7:0];
  /* T80.vhd:533:43  */
  assign n391_o = dir[15:8];
  /* T80.vhd:534:43  */
  assign n392_o = dir[23:16];
  /* T80.vhd:535:43  */
  assign n393_o = dir[31:24];
  /* T80.vhd:536:43  */
  assign n394_o = dir[39:32];
  /* T80.vhd:537:52  */
  assign n395_o = dir[47:40];
  /* T80.vhd:538:52  */
  assign n396_o = dir[63:48];
  /* T80.vhd:539:52  */
  assign n397_o = dir[79:64];
  /* T80.vhd:540:43  */
  assign n398_o = dir[79:64];
  /* T80.vhd:541:47  */
  assign n399_o = dir[209:208];
  /* T80.vhd:550:42  */
  assign n401_o = imode != 2'b11;
  /* T80.vhd:543:25  */
  assign n402_o = n1226_o ? imode : istatus;
  /* T80.vhd:556:41  */
  assign n404_o = iset == 2'b10;
  /* T80.vhd:556:58  */
  assign n405_o = alu_op[2];
  /* T80.vhd:556:62  */
  assign n406_o = ~n405_o;
  /* T80.vhd:556:48  */
  assign n407_o = n406_o & n404_o;
  /* T80.vhd:556:78  */
  assign n408_o = alu_op[0];
  /* T80.vhd:556:68  */
  assign n409_o = n408_o & n407_o;
  /* T80.vhd:556:99  */
  assign n411_o = mcycle == 3'b011;
  /* T80.vhd:556:88  */
  assign n412_o = n411_o & n409_o;
  /* T80.vhd:556:33  */
  assign n415_o = n412_o ? 1'b1 : 1'b0;
  /* T80.vhd:562:44  */
  assign n417_o = mcycle == 3'b001;
  /* T80.vhd:562:62  */
  assign n418_o = tstate[2];
  /* T80.vhd:562:66  */
  assign n419_o = ~n418_o;
  /* T80.vhd:562:52  */
  assign n420_o = n419_o & n417_o;
  /* T80.vhd:565:51  */
  assign n422_o = tstate == 3'b010;
  /* T80.vhd:565:55  */
  assign n423_o = wait_n & n422_o;
  /* T80.vhd:572:57  */
  assign n424_o = ~jump;
  /* T80.vhd:572:72  */
  assign n425_o = ~call;
  /* T80.vhd:572:63  */
  assign n426_o = n425_o & n424_o;
  /* T80.vhd:572:91  */
  assign n427_o = ~nmicycle;
  /* T80.vhd:572:78  */
  assign n428_o = n427_o & n426_o;
  /* T80.vhd:572:110  */
  assign n429_o = ~intcycle;
  /* T80.vhd:572:97  */
  assign n430_o = n429_o & n428_o;
  /* T80.vhd:572:139  */
  assign n431_o = halt_ff | halt;
  /* T80.vhd:572:120  */
  assign n432_o = ~n431_o;
  /* T80.vhd:572:116  */
  assign n433_o = n432_o & n430_o;
  /* T80.vhd:573:66  */
  assign n435_o = pc + 16'b0000000000000001;
  /* T80.vhd:565:41  */
  assign n436_o = n474_o ? n435_o : pc;
  /* T80.vhd:576:79  */
  assign n438_o = istatus == 2'b01;
  /* T80.vhd:576:67  */
  assign n439_o = n438_o & intcycle;
  /* T80.vhd:578:100  */
  assign n441_o = istatus == 2'b10;
  /* T80.vhd:578:88  */
  assign n442_o = n441_o & intcycle;
  /* T80.vhd:578:69  */
  assign n443_o = halt_ff | n442_o;
  /* T80.vhd:578:108  */
  assign n444_o = n443_o | nmicycle;
  /* T80.vhd:578:49  */
  assign n446_o = n444_o ? 8'b00000000 : dinst;
  /* T80.vhd:576:49  */
  assign n448_o = n439_o ? 8'b11111111 : n446_o;
  /* T80.vhd:585:59  */
  assign n450_o = prefix != 2'b00;
  /* T80.vhd:586:67  */
  assign n452_o = prefix == 2'b11;
  /* T80.vhd:587:70  */
  assign n453_o = ir[5];
  /* T80.vhd:587:65  */
  assign n456_o = n453_o ? 2'b10 : 2'b01;
  /* T80.vhd:593:75  */
  assign n458_o = prefix == 2'b10;
  /* T80.vhd:593:65  */
  assign n460_o = n458_o ? 2'b00 : xy_state;
  /* T80.vhd:593:65  */
  assign n462_o = n458_o ? 1'b0 : xy_ind;
  /* T80.vhd:586:57  */
  assign n464_o = n452_o ? 2'b00 : prefix;
  /* T80.vhd:586:57  */
  assign n465_o = n452_o ? n456_o : n460_o;
  /* T80.vhd:586:57  */
  assign n466_o = n452_o ? xy_ind : n462_o;
  /* T80.vhd:585:49  */
  assign n468_o = n450_o ? n464_o : 2'b00;
  /* T80.vhd:585:49  */
  assign n471_o = n450_o ? n465_o : 2'b00;
  /* T80.vhd:585:49  */
  assign n473_o = n450_o ? n466_o : 1'b0;
  /* T80.vhd:565:41  */
  assign n474_o = n433_o & n423_o;
  /* T80.vhd:565:41  */
  assign n475_o = n423_o ? n448_o : ir;
  /* T80.vhd:565:41  */
  assign n476_o = n423_o ? n468_o : iset;
  /* T80.vhd:543:25  */
  assign n477_o = n1227_o ? n471_o : xy_state;
  /* T80.vhd:565:41  */
  assign n478_o = n423_o ? n473_o : xy_ind;
  /* T80.vhd:608:51  */
  assign n480_o = mcycle == 3'b110;
  /* T80.vhd:610:59  */
  assign n482_o = prefix == 2'b01;
  /* T80.vhd:608:41  */
  assign n484_o = n485_o ? 2'b01 : iset;
  /* T80.vhd:608:41  */
  assign n485_o = n482_o & n480_o;
  /* T80.vhd:608:41  */
  assign n487_o = n480_o ? 1'b1 : xy_ind;
  /* T80.vhd:616:64  */
  assign n488_o = i_bt | i_bc;
  /* T80.vhd:616:72  */
  assign n489_o = n488_o | i_btr;
  /* T80.vhd:616:86  */
  assign n490_o = ~no_btr;
  /* T80.vhd:616:82  */
  assign n491_o = n489_o & n490_o;
  /* T80.vhd:619:76  */
  assign n492_o = wz[7:0];
  /* T80.vhd:621:86  */
  assign n493_o = wz[7:0];
  /* T80.vhd:625:66  */
  assign n494_o = call | rstp;
  /* T80.vhd:628:62  */
  assign n495_o = mcycle == mcycles;
  /* T80.vhd:628:72  */
  assign n496_o = nmicycle & n495_o;
  /* T80.vhd:631:62  */
  assign n498_o = mcycle == 3'b011;
  /* T80.vhd:631:70  */
  assign n499_o = intcycle & n498_o;
  /* T80.vhd:631:101  */
  assign n501_o = istatus == 2'b10;
  /* T80.vhd:631:89  */
  assign n502_o = n501_o & n499_o;
  /* T80.vhd:633:76  */
  assign n503_o = wz[7:0];
  /* T80.vhd:635:86  */
  assign n504_o = wz[7:0];
  /* T80.vhd:639:77  */
  assign n506_o = xy_state == 2'b00;
  /* T80.vhd:642:73  */
  assign n507_o = nextis_xy_fetch ? pc : wz;
  /* T80.vhd:639:65  */
  assign n508_o = n506_o ? regbusc : n507_o;
  /* T80.vhd:638:57  */
  assign n510_o = set_addr_to == 3'b010;
  /* T80.vhd:659:76  */
  assign n511_o = {acc, di_reg};
  /* T80.vhd:659:86  */
  assign n514_o = n511_o + 16'b0000000000000001;
  /* T80.vhd:648:57  */
  assign n516_o = set_addr_to == 3'b100;
  /* T80.vhd:660:57  */
  assign n518_o = set_addr_to == 3'b101;
  /* T80.vhd:669:82  */
  assign n520_o = setwz == 2'b01;
  /* T80.vhd:670:95  */
  assign n523_o = regbusc + 16'b0000000000000001;
  /* T80.vhd:669:73  */
  assign n524_o = n520_o ? n523_o : wz;
  /* T80.vhd:672:82  */
  assign n526_o = setwz == 2'b10;
  /* T80.vhd:673:106  */
  assign n527_o = regbusc[7:0];
  /* T80.vhd:673:119  */
  assign n530_o = n527_o + 8'b00000001;
  assign n531_o = {acc, n530_o};
  /* T80.vhd:672:73  */
  assign n532_o = n526_o ? n531_o : n524_o;
  /* T80.vhd:662:57  */
  assign n534_o = set_addr_to == 3'b000;
  /* T80.vhd:679:74  */
  assign n536_o = setwz == 2'b10;
  /* T80.vhd:680:98  */
  assign n537_o = regbusc[7:0];
  /* T80.vhd:680:111  */
  assign n540_o = n537_o + 8'b00000001;
  assign n541_o = {acc, n540_o};
  /* T80.vhd:679:65  */
  assign n542_o = n536_o ? n541_o : wz;
  /* T80.vhd:677:57  */
  assign n544_o = set_addr_to == 3'b001;
  /* T80.vhd:685:108  */
  assign n546_o = wz + 16'b0000000000000001;
  /* T80.vhd:688:92  */
  assign n547_o = wz[7:0];
  /* T80.vhd:689:82  */
  assign n549_o = setwz == 2'b10;
  /* T80.vhd:690:101  */
  assign n550_o = wz[7:0];
  /* T80.vhd:690:114  */
  assign n553_o = n550_o + 8'b00000001;
  assign n554_o = {acc, n553_o};
  /* T80.vhd:689:73  */
  assign n555_o = n549_o ? n554_o : wz;
  assign n556_o = {di_reg, n547_o};
  /* T80.vhd:684:65  */
  assign n557_o = inc_wz ? n546_o : n556_o;
  /* T80.vhd:684:65  */
  assign n558_o = inc_wz ? wz : n555_o;
  /* T80.vhd:683:57  */
  assign n560_o = set_addr_to == 3'b110;
  assign n561_o = {n560_o, n544_o, n534_o, n518_o, n516_o, n510_o};
  assign n562_o = n508_o[7:0];
  assign n563_o = sp[7:0];
  assign n564_o = regbusc[7:0];
  assign n565_o = regbusc[7:0];
  assign n566_o = n557_o[7:0];
  assign n567_o = pc[7:0];
  /* T80.vhd:637:57  */
  always @*
    case (n561_o)
      6'b100000: n568_o = n566_o;
      6'b010000: n568_o = n565_o;
      6'b001000: n568_o = n564_o;
      6'b000100: n568_o = n563_o;
      6'b000010: n568_o = di_reg;
      6'b000001: n568_o = n562_o;
      default: n568_o = n567_o;
    endcase
  assign n569_o = n508_o[15:8];
  assign n570_o = sp[15:8];
  assign n571_o = regbusc[15:8];
  assign n572_o = regbusc[15:8];
  assign n573_o = n557_o[15:8];
  assign n574_o = pc[15:8];
  /* T80.vhd:637:57  */
  always @*
    case (n561_o)
      6'b100000: n575_o = n573_o;
      6'b010000: n575_o = n572_o;
      6'b001000: n575_o = n571_o;
      6'b000100: n575_o = n570_o;
      6'b000010: n575_o = di_reg;
      6'b000001: n575_o = n569_o;
      default: n575_o = n574_o;
    endcase
  /* T80.vhd:637:57  */
  always @*
    case (n561_o)
      6'b100000: n576_o = n558_o;
      6'b010000: n576_o = n542_o;
      6'b001000: n576_o = n532_o;
      6'b000100: n576_o = wz;
      6'b000010: n576_o = n514_o;
      6'b000001: n576_o = wz;
      default: n576_o = wz;
    endcase
  assign n577_o = {n575_o, n568_o};
  assign n578_o = {i, n503_o};
  /* T80.vhd:631:49  */
  assign n579_o = n502_o ? n578_o : n577_o;
  assign n580_o = {i, n504_o};
  /* T80.vhd:631:49  */
  assign n581_o = n502_o ? n580_o : pc;
  /* T80.vhd:631:49  */
  assign n582_o = n502_o ? wz : n576_o;
  /* T80.vhd:628:49  */
  assign n584_o = n496_o ? 16'b0000000001100110 : n579_o;
  /* T80.vhd:628:49  */
  assign n586_o = n496_o ? 16'b0000000001100110 : n581_o;
  /* T80.vhd:628:49  */
  assign n587_o = n496_o ? wz : n582_o;
  /* T80.vhd:625:49  */
  assign n588_o = n494_o ? wz : n584_o;
  /* T80.vhd:625:49  */
  assign n589_o = n494_o ? wz : n586_o;
  /* T80.vhd:625:49  */
  assign n590_o = n494_o ? wz : n587_o;
  /* T80.vhd:622:49  */
  assign n591_o = jumpxy ? regbusc : n588_o;
  /* T80.vhd:622:49  */
  assign n592_o = jumpxy ? regbusc : n589_o;
  /* T80.vhd:622:49  */
  assign n593_o = jumpxy ? wz : n590_o;
  assign n594_o = {di_reg, n492_o};
  /* T80.vhd:617:49  */
  assign n595_o = jump ? n594_o : n591_o;
  assign n596_o = {di_reg, n493_o};
  /* T80.vhd:617:49  */
  assign n597_o = jump ? n596_o : n592_o;
  /* T80.vhd:617:49  */
  assign n598_o = jump ? wz : n593_o;
  /* T80.vhd:699:58  */
  assign n600_o = setwz == 2'b11;
  /* T80.vhd:699:49  */
  assign n601_o = n600_o ? id16 : n598_o;
  /* T80.vhd:708:64  */
  assign n602_o = ~acc;
  /* T80.vhd:709:77  */
  assign n603_o = acc[5];
  /* T80.vhd:709:70  */
  assign n604_o = ~n603_o;
  /* T80.vhd:711:77  */
  assign n606_o = acc[3];
  /* T80.vhd:711:70  */
  assign n607_o = ~n606_o;
  /* T80.vhd:615:41  */
  assign n609_o = n637_o ? n602_o : acc;
  assign n610_o = {n604_o, 1'b1, n607_o};
  assign n611_o = f[1];
  /* T80.vhd:706:49  */
  assign n612_o = i_cpl ? 1'b1 : n611_o;
  /* T80.vhd:716:75  */
  assign n615_o = f[0];
  /* T80.vhd:716:70  */
  assign n616_o = ~n615_o;
  /* T80.vhd:717:73  */
  assign n617_o = acc[5];
  /* T80.vhd:718:71  */
  assign n618_o = f[0];
  /* T80.vhd:719:73  */
  assign n619_o = acc[3];
  assign n621_o = {1'b0, n616_o};
  assign n622_o = {n617_o, n618_o, n619_o};
  assign n623_o = f[0];
  assign n624_o = {n612_o, n623_o};
  /* T80.vhd:714:49  */
  assign n625_o = i_ccf ? n621_o : n624_o;
  /* T80.vhd:725:73  */
  assign n628_o = acc[5];
  /* T80.vhd:727:73  */
  assign n630_o = acc[3];
  assign n632_o = {1'b0, 1'b1};
  assign n633_o = {n628_o, 1'b0, n630_o};
  /* T80.vhd:722:49  */
  assign n634_o = i_scf ? n632_o : n625_o;
  /* T80.vhd:615:41  */
  assign n636_o = t_res ? n595_o : n2116_q;
  /* T80.vhd:615:41  */
  assign n637_o = i_cpl & t_res;
  assign n638_o = f[1:0];
  /* T80.vhd:615:41  */
  assign n639_o = t_res ? n634_o : n638_o;
  /* T80.vhd:615:41  */
  assign n642_o = t_res ? n597_o : pc;
  /* T80.vhd:615:41  */
  assign n643_o = t_res ? n601_o : wz;
  /* T80.vhd:615:41  */
  assign n644_o = t_res ? n491_o : btr_r;
  /* T80.vhd:615:41  */
  assign n646_o = t_res ? alu_op : 4'b0000;
  /* T80.vhd:615:41  */
  assign n648_o = t_res ? save_alu : 1'b0;
  /* T80.vhd:732:52  */
  assign n650_o = tstate == 3'b010;
  /* T80.vhd:732:56  */
  assign n651_o = i_btr & n650_o;
  /* T80.vhd:732:78  */
  assign n652_o = ir[0];
  /* T80.vhd:732:72  */
  assign n653_o = n652_o & n651_o;
  /* T80.vhd:732:100  */
  assign n655_o = tstate == 3'b001;
  /* T80.vhd:732:104  */
  assign n656_o = i_btr & n655_o;
  /* T80.vhd:732:126  */
  assign n657_o = ir[0];
  /* T80.vhd:732:130  */
  assign n658_o = ~n657_o;
  /* T80.vhd:732:120  */
  assign n659_o = n658_o & n656_o;
  /* T80.vhd:732:89  */
  assign n660_o = n653_o | n659_o;
  /* T80.vhd:733:61  */
  assign n662_o = {1'b0, di_reg};
  /* T80.vhd:733:101  */
  assign n663_o = id16[7:0];
  /* T80.vhd:733:78  */
  assign n665_o = {1'b0, n663_o};
  /* T80.vhd:733:71  */
  assign n666_o = n662_o + n665_o;
  /* T80.vhd:734:68  */
  assign n667_o = di_reg[7];
  /* T80.vhd:735:65  */
  assign n668_o = n666_o[8];
  /* T80.vhd:736:65  */
  assign n669_o = n666_o[8];
  /* T80.vhd:737:61  */
  assign n671_o = n666_o & 9'b000000111;
  /* T80.vhd:737:88  */
  assign n673_o = {1'b0, busa};
  /* T80.vhd:737:80  */
  assign n674_o = n671_o ^ n673_o;
  /* T80.vhd:738:70  */
  assign n675_o = n674_o[0];
  /* T80.vhd:738:81  */
  assign n676_o = n674_o[1];
  /* T80.vhd:738:74  */
  assign n677_o = n675_o ^ n676_o;
  /* T80.vhd:738:92  */
  assign n678_o = n674_o[2];
  /* T80.vhd:738:85  */
  assign n679_o = n677_o ^ n678_o;
  /* T80.vhd:738:103  */
  assign n680_o = n674_o[3];
  /* T80.vhd:738:96  */
  assign n681_o = n679_o ^ n680_o;
  /* T80.vhd:738:114  */
  assign n682_o = n674_o[4];
  /* T80.vhd:738:107  */
  assign n683_o = n681_o ^ n682_o;
  /* T80.vhd:738:125  */
  assign n684_o = n674_o[5];
  /* T80.vhd:738:118  */
  assign n685_o = n683_o ^ n684_o;
  /* T80.vhd:738:136  */
  assign n686_o = n674_o[6];
  /* T80.vhd:738:129  */
  assign n687_o = n685_o ^ n686_o;
  /* T80.vhd:738:147  */
  assign n688_o = n674_o[7];
  /* T80.vhd:738:140  */
  assign n689_o = n687_o ^ n688_o;
  /* T80.vhd:738:62  */
  assign n690_o = ~n689_o;
  assign n691_o = {n690_o, n667_o, n668_o};
  assign n692_o = f[2];
  assign n693_o = {n692_o, n639_o};
  /* T80.vhd:732:41  */
  assign n694_o = n660_o ? n691_o : n693_o;
  assign n695_o = f[4];
  assign n696_o = f[4];
  assign n697_o = n610_o[1];
  /* T80.vhd:706:49  */
  assign n698_o = i_cpl ? n697_o : n696_o;
  assign n699_o = n622_o[1];
  /* T80.vhd:714:49  */
  assign n700_o = i_ccf ? n699_o : n698_o;
  assign n701_o = n633_o[1];
  /* T80.vhd:722:49  */
  assign n702_o = i_scf ? n701_o : n700_o;
  /* T80.vhd:615:41  */
  assign n703_o = t_res ? n702_o : n695_o;
  /* T80.vhd:732:41  */
  assign n704_o = n660_o ? n669_o : n703_o;
  assign n705_o = f[5];
  assign n706_o = f[5];
  assign n707_o = n610_o[2];
  /* T80.vhd:706:49  */
  assign n708_o = i_cpl ? n707_o : n706_o;
  assign n709_o = n622_o[2];
  /* T80.vhd:714:49  */
  assign n710_o = i_ccf ? n709_o : n708_o;
  assign n711_o = n633_o[2];
  /* T80.vhd:722:49  */
  assign n712_o = i_scf ? n711_o : n710_o;
  /* T80.vhd:615:41  */
  assign n713_o = t_res ? n712_o : n705_o;
  assign n714_o = f[3];
  assign n715_o = f[3];
  assign n716_o = n610_o[0];
  /* T80.vhd:706:49  */
  assign n717_o = i_cpl ? n716_o : n715_o;
  assign n718_o = n622_o[0];
  /* T80.vhd:714:49  */
  assign n719_o = i_ccf ? n718_o : n717_o;
  assign n720_o = n633_o[0];
  /* T80.vhd:722:49  */
  assign n721_o = i_scf ? n720_o : n719_o;
  /* T80.vhd:615:41  */
  assign n722_o = t_res ? n721_o : n714_o;
  /* T80.vhd:741:51  */
  assign n725_o = tstate == 3'b010;
  /* T80.vhd:741:55  */
  assign n726_o = wait_n & n725_o;
  /* T80.vhd:742:57  */
  assign n728_o = iset == 2'b01;
  /* T80.vhd:742:75  */
  assign n730_o = mcycle == 3'b111;
  /* T80.vhd:742:64  */
  assign n731_o = n730_o & n728_o;
  /* T80.vhd:741:41  */
  assign n732_o = n753_o ? dinst : ir;
  /* T80.vhd:746:83  */
  assign n733_o = {{8{di_reg[7]}}, di_reg}; // sext
  /* T80.vhd:746:83  */
  assign n734_o = pc + n733_o;
  /* T80.vhd:747:91  */
  assign n735_o = {{8{di_reg[7]}}, di_reg}; // sext
  /* T80.vhd:747:91  */
  assign n736_o = pc + n735_o;
  /* T80.vhd:749:66  */
  assign n738_o = pc + 16'b0000000000000001;
  /* T80.vhd:748:49  */
  assign n739_o = inc_pc ? n738_o : n642_o;
  /* T80.vhd:745:49  */
  assign n740_o = jumpe ? n734_o : n739_o;
  /* T80.vhd:745:49  */
  assign n741_o = jumpe ? n736_o : n643_o;
  /* T80.vhd:752:66  */
  assign n743_o = pc - 16'b0000000000000010;
  /* T80.vhd:751:49  */
  assign n744_o = btr_r ? n743_o : n740_o;
  /* T80.vhd:756:77  */
  assign n745_o = ir[5:3];
  assign n747_o = n746_o[15:6];
  assign n748_o = n746_o[2:0];
  assign n749_o = {n747_o, n745_o, n748_o};
  /* T80.vhd:754:49  */
  assign n750_o = rstp ? n749_o : n741_o;
  /* T80.vhd:741:41  */
  assign n751_o = n726_o ? n744_o : n642_o;
  /* T80.vhd:741:41  */
  assign n752_o = n726_o ? n750_o : n643_o;
  /* T80.vhd:741:41  */
  assign n753_o = n731_o & n726_o;
  /* T80.vhd:759:51  */
  assign n755_o = tstate == 3'b011;
  /* T80.vhd:759:66  */
  assign n757_o = mcycle == 3'b110;
  /* T80.vhd:759:55  */
  assign n758_o = n757_o & n755_o;
  /* T80.vhd:760:88  */
  assign n759_o = {{8{di_reg[7]}}, di_reg}; // sext
  /* T80.vhd:760:88  */
  assign n760_o = regbusc + n759_o;
  /* T80.vhd:759:41  */
  assign n761_o = n758_o ? n760_o : n752_o;
  /* T80.vhd:763:51  */
  assign n763_o = mcycle == 3'b011;
  /* T80.vhd:763:70  */
  assign n765_o = tstate == 3'b100;
  /* T80.vhd:763:59  */
  assign n766_o = n765_o & n763_o;
  /* T80.vhd:763:85  */
  assign n767_o = ~no_btr;
  /* T80.vhd:763:74  */
  assign n768_o = n767_o & n766_o;
  /* T80.vhd:764:63  */
  assign n769_o = i_bt | i_bc;
  /* T80.vhd:765:83  */
  assign n772_o = pc - 16'b0000000000000001;
  /* T80.vhd:763:41  */
  assign n773_o = n774_o ? n772_o : n761_o;
  /* T80.vhd:763:41  */
  assign n774_o = n769_o & n768_o;
  /* T80.vhd:769:52  */
  assign n776_o = tstate == 3'b010;
  /* T80.vhd:769:56  */
  assign n777_o = wait_n & n776_o;
  /* T80.vhd:769:85  */
  assign n779_o = tstate == 3'b100;
  /* T80.vhd:769:100  */
  assign n781_o = mcycle == 3'b001;
  /* T80.vhd:769:89  */
  assign n782_o = n781_o & n779_o;
  /* T80.vhd:769:74  */
  assign n783_o = n777_o | n782_o;
  /* T80.vhd:770:61  */
  assign n784_o = incdec_16[2:0];
  /* T80.vhd:770:74  */
  assign n786_o = n784_o == 3'b111;
  /* T80.vhd:771:69  */
  assign n787_o = incdec_16[3];
  /* T80.vhd:772:74  */
  assign n789_o = sp - 16'b0000000000000001;
  /* T80.vhd:774:74  */
  assign n791_o = sp + 16'b0000000000000001;
  /* T80.vhd:771:57  */
  assign n792_o = n787_o ? n789_o : n791_o;
  /* T80.vhd:769:41  */
  assign n793_o = n794_o ? n792_o : sp;
  /* T80.vhd:769:41  */
  assign n794_o = n786_o & n783_o;
  /* T80.vhd:779:41  */
  assign n795_o = ldsphl ? regbusc : n793_o;
  /* T80.vhd:782:41  */
  assign n796_o = exchangeaf ? ap : n609_o;
  assign n797_o = f[7:6];
  assign n798_o = {n797_o, n713_o, n704_o, n722_o, n694_o};
  /* T80.vhd:782:41  */
  assign n800_o = exchangeaf ? acc : ap;
  /* T80.vhd:782:41  */
  assign n801_o = exchangeaf ? f : fp;
  /* T80.vhd:789:62  */
  assign n802_o = ~alternate;
  /* T80.vhd:788:41  */
  assign n803_o = exchangers ? n802_o : alternate;
  /* T80.vhd:562:33  */
  assign n804_o = n420_o ? n2116_q : n636_o;
  /* T80.vhd:562:33  */
  assign n805_o = n420_o ? acc : n796_o;
  /* T80.vhd:562:33  */
  assign n807_o = n420_o ? ap : n800_o;
  /* T80.vhd:562:33  */
  assign n808_o = n420_o ? fp : n801_o;
  /* T80.vhd:562:33  */
  assign n809_o = n420_o ? sp : n795_o;
  /* T80.vhd:562:33  */
  assign n810_o = n420_o ? n436_o : n751_o;
  /* T80.vhd:562:33  */
  assign n811_o = n420_o ? alternate : n803_o;
  /* T80.vhd:562:33  */
  assign n812_o = n420_o ? wz : n773_o;
  /* T80.vhd:562:33  */
  assign n813_o = n420_o ? n475_o : n732_o;
  /* T80.vhd:562:33  */
  assign n814_o = n420_o ? n476_o : n484_o;
  /* T80.vhd:562:33  */
  assign n815_o = n423_o & n420_o;
  /* T80.vhd:562:33  */
  assign n816_o = n420_o ? n478_o : n487_o;
  /* T80.vhd:562:33  */
  assign n817_o = n420_o ? btr_r : n644_o;
  /* T80.vhd:562:33  */
  assign n819_o = n420_o ? 4'b0000 : n646_o;
  /* T80.vhd:562:33  */
  assign n822_o = n420_o ? 1'b0 : n648_o;
  /* T80.vhd:793:43  */
  assign n826_o = tstate == 3'b011;
  assign n827_o = wz[7:0];
  assign n828_o = n576_o[7:0];
  assign n829_o = wz[7:0];
  /* T80.vhd:631:49  */
  assign n830_o = n502_o ? n829_o : n828_o;
  assign n831_o = wz[7:0];
  /* T80.vhd:628:49  */
  assign n832_o = n496_o ? n831_o : n830_o;
  assign n833_o = wz[7:0];
  /* T80.vhd:625:49  */
  assign n834_o = n494_o ? n833_o : n832_o;
  assign n835_o = wz[7:0];
  /* T80.vhd:622:49  */
  assign n836_o = jumpxy ? n835_o : n834_o;
  assign n837_o = wz[7:0];
  /* T80.vhd:617:49  */
  assign n838_o = jump ? n837_o : n836_o;
  assign n839_o = id16[7:0];
  /* T80.vhd:699:49  */
  assign n840_o = n600_o ? n839_o : n838_o;
  /* T80.vhd:615:41  */
  assign n841_o = t_res ? n840_o : n827_o;
  assign n842_o = wz[7:0];
  assign n843_o = n576_o[7:0];
  assign n844_o = wz[7:0];
  /* T80.vhd:631:49  */
  assign n845_o = n502_o ? n844_o : n843_o;
  assign n846_o = wz[7:0];
  /* T80.vhd:628:49  */
  assign n847_o = n496_o ? n846_o : n845_o;
  assign n848_o = wz[7:0];
  /* T80.vhd:625:49  */
  assign n849_o = n494_o ? n848_o : n847_o;
  assign n850_o = wz[7:0];
  /* T80.vhd:622:49  */
  assign n851_o = jumpxy ? n850_o : n849_o;
  assign n852_o = wz[7:0];
  /* T80.vhd:617:49  */
  assign n853_o = jump ? n852_o : n851_o;
  assign n854_o = id16[7:0];
  /* T80.vhd:699:49  */
  assign n855_o = n600_o ? n854_o : n853_o;
  /* T80.vhd:615:41  */
  assign n856_o = t_res ? n855_o : n842_o;
  assign n857_o = n736_o[7:0];
  /* T80.vhd:745:49  */
  assign n858_o = jumpe ? n857_o : n856_o;
  assign n859_o = n749_o[7:0];
  /* T80.vhd:754:49  */
  assign n860_o = rstp ? n859_o : n858_o;
  /* T80.vhd:741:41  */
  assign n861_o = n726_o ? n860_o : n841_o;
  assign n862_o = n760_o[7:0];
  /* T80.vhd:759:41  */
  assign n863_o = n758_o ? n862_o : n861_o;
  assign n864_o = n772_o[7:0];
  /* T80.vhd:763:41  */
  assign n865_o = n774_o ? n864_o : n863_o;
  assign n866_o = wz[7:0];
  /* T80.vhd:562:33  */
  assign n867_o = n420_o ? n866_o : n865_o;
  /* T80.vhd:794:41  */
  assign n868_o = ldz ? di_reg : n867_o;
  assign n869_o = wz[15:8];
  assign n870_o = n576_o[15:8];
  assign n871_o = wz[15:8];
  /* T80.vhd:631:49  */
  assign n872_o = n502_o ? n871_o : n870_o;
  assign n873_o = wz[15:8];
  /* T80.vhd:628:49  */
  assign n874_o = n496_o ? n873_o : n872_o;
  assign n875_o = wz[15:8];
  /* T80.vhd:625:49  */
  assign n876_o = n494_o ? n875_o : n874_o;
  assign n877_o = wz[15:8];
  /* T80.vhd:622:49  */
  assign n878_o = jumpxy ? n877_o : n876_o;
  assign n879_o = wz[15:8];
  /* T80.vhd:617:49  */
  assign n880_o = jump ? n879_o : n878_o;
  assign n881_o = id16[15:8];
  /* T80.vhd:699:49  */
  assign n882_o = n600_o ? n881_o : n880_o;
  /* T80.vhd:615:41  */
  assign n883_o = t_res ? n882_o : n869_o;
  assign n884_o = wz[15:8];
  assign n885_o = n576_o[15:8];
  assign n886_o = wz[15:8];
  /* T80.vhd:631:49  */
  assign n887_o = n502_o ? n886_o : n885_o;
  assign n888_o = wz[15:8];
  /* T80.vhd:628:49  */
  assign n889_o = n496_o ? n888_o : n887_o;
  assign n890_o = wz[15:8];
  /* T80.vhd:625:49  */
  assign n891_o = n494_o ? n890_o : n889_o;
  assign n892_o = wz[15:8];
  /* T80.vhd:622:49  */
  assign n893_o = jumpxy ? n892_o : n891_o;
  assign n894_o = wz[15:8];
  /* T80.vhd:617:49  */
  assign n895_o = jump ? n894_o : n893_o;
  assign n896_o = id16[15:8];
  /* T80.vhd:699:49  */
  assign n897_o = n600_o ? n896_o : n895_o;
  /* T80.vhd:615:41  */
  assign n898_o = t_res ? n897_o : n884_o;
  assign n899_o = n736_o[15:8];
  /* T80.vhd:745:49  */
  assign n900_o = jumpe ? n899_o : n898_o;
  assign n901_o = n749_o[15:8];
  /* T80.vhd:754:49  */
  assign n902_o = rstp ? n901_o : n900_o;
  /* T80.vhd:741:41  */
  assign n903_o = n726_o ? n902_o : n883_o;
  assign n904_o = n760_o[15:8];
  /* T80.vhd:759:41  */
  assign n905_o = n758_o ? n904_o : n903_o;
  assign n906_o = n772_o[15:8];
  /* T80.vhd:763:41  */
  assign n907_o = n774_o ? n906_o : n905_o;
  assign n908_o = wz[15:8];
  /* T80.vhd:562:33  */
  assign n909_o = n420_o ? n908_o : n907_o;
  /* T80.vhd:797:41  */
  assign n910_o = ldw ? di_reg : n909_o;
  /* T80.vhd:801:54  */
  assign n911_o = special_ld[2];
  /* T80.vhd:802:64  */
  assign n912_o = special_ld[1:0];
  /* T80.vhd:806:71  */
  assign n913_o = i[7];
  /* T80.vhd:808:62  */
  assign n915_o = i == 8'b00000000;
  /* T80.vhd:808:57  */
  assign n918_o = n915_o ? 1'b1 : 1'b0;
  /* T80.vhd:814:71  */
  assign n919_o = i[5];
  /* T80.vhd:816:71  */
  assign n921_o = i[3];
  /* T80.vhd:803:49  */
  assign n924_o = n912_o == 2'b00;
  /* T80.vhd:823:71  */
  assign n925_o = r[7];
  /* T80.vhd:825:62  */
  assign n927_o = r == 8'b00000000;
  /* T80.vhd:825:57  */
  assign n930_o = n927_o ? 1'b1 : 1'b0;
  /* T80.vhd:831:71  */
  assign n931_o = r[5];
  /* T80.vhd:833:71  */
  assign n933_o = r[3];
  /* T80.vhd:820:49  */
  assign n936_o = n912_o == 2'b01;
  /* T80.vhd:836:49  */
  assign n938_o = n912_o == 2'b10;
  assign n939_o = {n938_o, n936_o, n924_o};
  /* T80.vhd:802:49  */
  always @*
    case (n939_o)
      3'b100: n940_o = n805_o;
      3'b010: n940_o = r;
      3'b001: n940_o = i;
      default: n940_o = n805_o;
    endcase
  assign n941_o = n798_o[1];
  assign n942_o = fp[1];
  /* T80.vhd:782:41  */
  assign n943_o = exchangeaf ? n942_o : n941_o;
  assign n944_o = f[1];
  /* T80.vhd:562:33  */
  assign n945_o = n420_o ? n944_o : n943_o;
  /* T80.vhd:802:49  */
  always @*
    case (n939_o)
      3'b100: n946_o = n945_o;
      3'b010: n946_o = 1'b0;
      3'b001: n946_o = 1'b0;
      default: n946_o = n945_o;
    endcase
  assign n947_o = n798_o[2];
  assign n948_o = fp[2];
  /* T80.vhd:782:41  */
  assign n949_o = exchangeaf ? n948_o : n947_o;
  assign n950_o = f[2];
  /* T80.vhd:562:33  */
  assign n951_o = n420_o ? n950_o : n949_o;
  /* T80.vhd:802:49  */
  always @*
    case (n939_o)
      3'b100: n952_o = n951_o;
      3'b010: n952_o = inte_ff2;
      3'b001: n952_o = inte_ff2;
      default: n952_o = n951_o;
    endcase
  assign n953_o = n798_o[3];
  assign n954_o = fp[3];
  /* T80.vhd:782:41  */
  assign n955_o = exchangeaf ? n954_o : n953_o;
  assign n956_o = f[3];
  /* T80.vhd:562:33  */
  assign n957_o = n420_o ? n956_o : n955_o;
  /* T80.vhd:802:49  */
  always @*
    case (n939_o)
      3'b100: n958_o = n957_o;
      3'b010: n958_o = n933_o;
      3'b001: n958_o = n921_o;
      default: n958_o = n957_o;
    endcase
  assign n959_o = n798_o[4];
  assign n960_o = fp[4];
  /* T80.vhd:782:41  */
  assign n961_o = exchangeaf ? n960_o : n959_o;
  assign n962_o = f[4];
  /* T80.vhd:562:33  */
  assign n963_o = n420_o ? n962_o : n961_o;
  /* T80.vhd:802:49  */
  always @*
    case (n939_o)
      3'b100: n964_o = n963_o;
      3'b010: n964_o = 1'b0;
      3'b001: n964_o = 1'b0;
      default: n964_o = n963_o;
    endcase
  assign n965_o = n798_o[5];
  assign n966_o = fp[5];
  /* T80.vhd:782:41  */
  assign n967_o = exchangeaf ? n966_o : n965_o;
  assign n968_o = f[5];
  /* T80.vhd:562:33  */
  assign n969_o = n420_o ? n968_o : n967_o;
  /* T80.vhd:802:49  */
  always @*
    case (n939_o)
      3'b100: n970_o = n969_o;
      3'b010: n970_o = n931_o;
      3'b001: n970_o = n919_o;
      default: n970_o = n969_o;
    endcase
  assign n971_o = n798_o[6];
  assign n972_o = fp[6];
  /* T80.vhd:782:41  */
  assign n973_o = exchangeaf ? n972_o : n971_o;
  assign n974_o = f[6];
  /* T80.vhd:562:33  */
  assign n975_o = n420_o ? n974_o : n973_o;
  /* T80.vhd:802:49  */
  always @*
    case (n939_o)
      3'b100: n976_o = n975_o;
      3'b010: n976_o = n930_o;
      3'b001: n976_o = n918_o;
      default: n976_o = n975_o;
    endcase
  assign n977_o = n798_o[7];
  assign n978_o = fp[7];
  /* T80.vhd:782:41  */
  assign n979_o = exchangeaf ? n978_o : n977_o;
  assign n980_o = f[7];
  /* T80.vhd:562:33  */
  assign n981_o = n420_o ? n980_o : n979_o;
  /* T80.vhd:802:49  */
  always @*
    case (n939_o)
      3'b100: n982_o = n981_o;
      3'b010: n982_o = n925_o;
      3'b001: n982_o = n913_o;
      default: n982_o = n981_o;
    endcase
  /* T80.vhd:802:49  */
  always @*
    case (n939_o)
      3'b100: n983_o = acc;
      3'b010: n983_o = i;
      3'b001: n983_o = i;
      default: n983_o = i;
    endcase
  /* T80.vhd:802:49  */
  always @*
    case (n939_o)
      3'b100: n984_o = r;
      3'b010: n984_o = r;
      3'b001: n984_o = r;
      default: n984_o = acc;
    endcase
  /* T80.vhd:793:33  */
  assign n985_o = n995_o ? n940_o : n805_o;
  assign n986_o = {n982_o, n976_o, n970_o, n964_o, n958_o, n952_o, n946_o};
  assign n987_o = n798_o[7:1];
  assign n988_o = fp[7:1];
  /* T80.vhd:782:41  */
  assign n989_o = exchangeaf ? n988_o : n987_o;
  assign n990_o = f[7:1];
  /* T80.vhd:562:33  */
  assign n991_o = n420_o ? n990_o : n989_o;
  /* T80.vhd:801:41  */
  assign n992_o = n911_o ? n986_o : n991_o;
  /* T80.vhd:543:25  */
  assign n993_o = n1218_o ? n983_o : i;
  /* T80.vhd:543:25  */
  assign n994_o = n1219_o ? n984_o : r;
  /* T80.vhd:793:33  */
  assign n995_o = n911_o & n826_o;
  assign n996_o = n798_o[7:1];
  assign n997_o = fp[7:1];
  /* T80.vhd:782:41  */
  assign n998_o = exchangeaf ? n997_o : n996_o;
  assign n999_o = f[7:1];
  /* T80.vhd:562:33  */
  assign n1000_o = n420_o ? n999_o : n998_o;
  /* T80.vhd:793:33  */
  assign n1001_o = n826_o ? n992_o : n1000_o;
  assign n1002_o = n798_o[0];
  assign n1003_o = fp[0];
  /* T80.vhd:782:41  */
  assign n1004_o = exchangeaf ? n1003_o : n1002_o;
  assign n1005_o = f[0];
  /* T80.vhd:562:33  */
  assign n1006_o = n420_o ? n1005_o : n1004_o;
  /* T80.vhd:793:33  */
  assign n1007_o = n911_o & n826_o;
  /* T80.vhd:793:33  */
  assign n1008_o = n911_o & n826_o;
  assign n1009_o = {n910_o, n868_o};
  /* T80.vhd:793:33  */
  assign n1010_o = n826_o ? n1009_o : n812_o;
  /* T80.vhd:844:44  */
  assign n1011_o = ~i_djnz;
  /* T80.vhd:844:50  */
  assign n1012_o = save_alu_r & n1011_o;
  /* T80.vhd:844:84  */
  assign n1014_o = alu_op_r == 4'b1001;
  /* T80.vhd:844:72  */
  assign n1015_o = n1012_o | n1014_o;
  /* T80.vhd:853:71  */
  assign n1016_o = f_out[7:1];
  /* T80.vhd:854:64  */
  assign n1017_o = ~preservec_r;
  /* T80.vhd:855:75  */
  assign n1018_o = f_out[0];
  /* T80.vhd:854:49  */
  assign n1019_o = n1017_o ? n1018_o : n1006_o;
  assign n1020_o = {n1016_o, n1019_o};
  assign n1021_o = {n1001_o, n1006_o};
  /* T80.vhd:859:48  */
  assign n1023_o = i_inrc & t_res;
  /* T80.vhd:862:60  */
  assign n1026_o = di_reg[3];
  /* T80.vhd:863:60  */
  assign n1027_o = di_reg[5];
  /* T80.vhd:864:63  */
  assign n1029_o = di_reg == 8'b00000000;
  /* T80.vhd:864:41  */
  assign n1032_o = n1029_o ? 1'b1 : 1'b0;
  /* T80.vhd:869:60  */
  assign n1033_o = di_reg[7];
  /* T80.vhd:870:65  */
  assign n1034_o = di_reg[0];
  /* T80.vhd:870:79  */
  assign n1035_o = di_reg[1];
  /* T80.vhd:870:69  */
  assign n1036_o = n1034_o ^ n1035_o;
  /* T80.vhd:870:93  */
  assign n1037_o = di_reg[2];
  /* T80.vhd:870:83  */
  assign n1038_o = n1036_o ^ n1037_o;
  /* T80.vhd:870:107  */
  assign n1039_o = di_reg[3];
  /* T80.vhd:870:97  */
  assign n1040_o = n1038_o ^ n1039_o;
  /* T80.vhd:871:55  */
  assign n1041_o = di_reg[4];
  /* T80.vhd:870:111  */
  assign n1042_o = n1040_o ^ n1041_o;
  /* T80.vhd:871:69  */
  assign n1043_o = di_reg[5];
  /* T80.vhd:871:59  */
  assign n1044_o = n1042_o ^ n1043_o;
  /* T80.vhd:871:83  */
  assign n1045_o = di_reg[6];
  /* T80.vhd:871:73  */
  assign n1046_o = n1044_o ^ n1045_o;
  /* T80.vhd:871:97  */
  assign n1047_o = di_reg[7];
  /* T80.vhd:871:87  */
  assign n1048_o = n1046_o ^ n1047_o;
  /* T80.vhd:870:54  */
  assign n1049_o = ~n1048_o;
  assign n1050_o = {n1033_o, n1032_o, n1027_o, 1'b0, n1026_o, n1049_o, 1'b0};
  assign n1055_o = n1021_o[0];
  assign n1056_o = n1020_o[0];
  /* T80.vhd:844:33  */
  assign n1057_o = n1015_o ? n1056_o : n1055_o;
  /* T80.vhd:874:43  */
  assign n1059_o = tstate == 3'b001;
  /* T80.vhd:874:64  */
  assign n1060_o = ~auto_wait_t1;
  /* T80.vhd:874:47  */
  assign n1061_o = n1060_o & n1059_o;
  /* T80.vhd:876:57  */
  assign n1062_o = i_rld | i_rrd;
  /* T80.vhd:877:50  */
  assign n1063_o = ~i_rxdd;
  /* T80.vhd:877:41  */
  assign n1064_o = n1063_o ? busb : n2117_q;
  /* T80.vhd:881:73  */
  assign n1065_o = busa[3:0];
  /* T80.vhd:882:73  */
  assign n1066_o = busb[3:0];
  assign n1067_o = {n1066_o, n1065_o};
  /* T80.vhd:880:41  */
  assign n1068_o = i_rld ? n1067_o : n1064_o;
  /* T80.vhd:885:73  */
  assign n1069_o = busb[7:4];
  /* T80.vhd:886:73  */
  assign n1070_o = busa[3:0];
  assign n1071_o = {n1070_o, n1069_o};
  /* T80.vhd:884:41  */
  assign n1072_o = i_rrd ? n1071_o : n1068_o;
  /* T80.vhd:874:33  */
  assign n1073_o = n1061_o ? n1072_o : n2117_q;
  /* T80.vhd:543:25  */
  assign n1074_o = n1237_o ? n1062_o : i_rxdd;
  assign n1077_o = {1'b1, 4'b0111};
  assign n1078_o = {read_to_reg, set_busa_to};
  /* T80.vhd:893:41  */
  assign n1079_o = read_to_acc ? n1077_o : n1078_o;
  /* T80.vhd:890:33  */
  assign n1081_o = t_res ? n1079_o : 5'b00000;
  /* T80.vhd:899:43  */
  assign n1084_o = tstate == 3'b001;
  /* T80.vhd:899:47  */
  assign n1085_o = i_bt & n1084_o;
  /* T80.vhd:900:59  */
  assign n1086_o = alu_q[3];
  /* T80.vhd:901:59  */
  assign n1087_o = alu_q[1];
  assign n1090_o = {n1087_o, 1'b0, n1086_o};
  assign n1091_o = n1021_o[1];
  assign n1092_o = n1020_o[1];
  /* T80.vhd:844:33  */
  assign n1093_o = n1015_o ? n1092_o : n1091_o;
  assign n1094_o = n1050_o[0];
  /* T80.vhd:859:33  */
  assign n1095_o = n1023_o ? n1094_o : n1093_o;
  /* T80.vhd:899:33  */
  assign n1096_o = n1085_o ? 1'b0 : n1095_o;
  assign n1108_o = n1021_o[7:6];
  assign n1109_o = n1020_o[7:6];
  /* T80.vhd:844:33  */
  assign n1110_o = n1015_o ? n1109_o : n1108_o;
  assign n1111_o = n1050_o[6:5];
  /* T80.vhd:859:33  */
  assign n1112_o = n1023_o ? n1111_o : n1110_o;
  assign n1113_o = n1021_o[2];
  assign n1114_o = n1020_o[2];
  /* T80.vhd:844:33  */
  assign n1115_o = n1015_o ? n1114_o : n1113_o;
  assign n1116_o = n1050_o[1];
  /* T80.vhd:859:33  */
  assign n1117_o = n1023_o ? n1116_o : n1115_o;
  /* T80.vhd:905:43  */
  assign n1119_o = tstate == 3'b001;
  /* T80.vhd:905:47  */
  assign n1120_o = i_bc & n1119_o;
  /* T80.vhd:906:72  */
  assign n1121_o = f_out[4];
  /* T80.vhd:906:65  */
  assign n1123_o = {7'b0000000, n1121_o};
  /* T80.vhd:906:52  */
  assign n1124_o = alu_q - n1123_o;
  /* T80.vhd:907:55  */
  assign n1125_o = n1124_o[3];
  /* T80.vhd:908:55  */
  assign n1126_o = n1124_o[1];
  assign n1127_o = n1021_o[3];
  assign n1128_o = n1020_o[3];
  /* T80.vhd:844:33  */
  assign n1129_o = n1015_o ? n1128_o : n1127_o;
  assign n1130_o = n1050_o[2];
  /* T80.vhd:859:33  */
  assign n1131_o = n1023_o ? n1130_o : n1129_o;
  assign n1132_o = n1090_o[0];
  /* T80.vhd:899:33  */
  assign n1133_o = n1085_o ? n1132_o : n1131_o;
  /* T80.vhd:905:33  */
  assign n1134_o = n1120_o ? n1125_o : n1133_o;
  assign n1135_o = n1021_o[5];
  assign n1136_o = n1020_o[5];
  /* T80.vhd:844:33  */
  assign n1137_o = n1015_o ? n1136_o : n1135_o;
  assign n1138_o = n1050_o[4];
  /* T80.vhd:859:33  */
  assign n1139_o = n1023_o ? n1138_o : n1137_o;
  assign n1140_o = n1090_o[2];
  /* T80.vhd:899:33  */
  assign n1141_o = n1085_o ? n1140_o : n1139_o;
  /* T80.vhd:905:33  */
  assign n1142_o = n1120_o ? n1126_o : n1141_o;
  assign n1150_o = n1021_o[4];
  assign n1151_o = n1020_o[4];
  /* T80.vhd:844:33  */
  assign n1152_o = n1015_o ? n1151_o : n1150_o;
  assign n1153_o = n1050_o[3];
  /* T80.vhd:859:33  */
  assign n1154_o = n1023_o ? n1153_o : n1152_o;
  assign n1155_o = n1090_o[1];
  /* T80.vhd:899:33  */
  assign n1156_o = n1085_o ? n1155_o : n1154_o;
  /* T80.vhd:910:47  */
  assign n1158_o = i_bc | i_bt;
  /* T80.vhd:910:33  */
  assign n1159_o = n1158_o ? incdecz : n1117_o;
  /* T80.vhd:914:44  */
  assign n1161_o = tstate == 3'b001;
  /* T80.vhd:914:63  */
  assign n1162_o = ~save_alu_r;
  /* T80.vhd:914:48  */
  assign n1163_o = n1162_o & n1161_o;
  /* T80.vhd:914:86  */
  assign n1164_o = ~auto_wait_t1;
  /* T80.vhd:914:69  */
  assign n1165_o = n1164_o & n1163_o;
  /* T80.vhd:915:72  */
  assign n1167_o = alu_op_r != 4'b0111;
  /* T80.vhd:915:59  */
  assign n1168_o = n1167_o & save_alu_r;
  /* T80.vhd:914:93  */
  assign n1169_o = n1165_o | n1168_o;
  /* T80.vhd:917:41  */
  assign n1171_o = read_to_reg_r == 5'b10111;
  /* T80.vhd:919:41  */
  assign n1173_o = read_to_reg_r == 5'b10110;
  /* T80.vhd:921:41  */
  assign n1175_o = read_to_reg_r == 5'b11000;
  /* T80.vhd:923:41  */
  assign n1177_o = read_to_reg_r == 5'b11001;
  /* T80.vhd:925:41  */
  assign n1179_o = read_to_reg_r == 5'b11011;
  assign n1180_o = {n1179_o, n1177_o, n1175_o, n1173_o, n1171_o};
  /* T80.vhd:916:41  */
  always @*
    case (n1180_o)
      5'b10000: n1181_o = n1073_o;
      5'b01000: n1181_o = n1073_o;
      5'b00100: n1181_o = n1073_o;
      5'b00010: n1181_o = save_mux;
      5'b00001: n1181_o = n1073_o;
      default: n1181_o = n1073_o;
    endcase
  /* T80.vhd:916:41  */
  always @*
    case (n1180_o)
      5'b10000: n1182_o = n985_o;
      5'b01000: n1182_o = n985_o;
      5'b00100: n1182_o = n985_o;
      5'b00010: n1182_o = n985_o;
      5'b00001: n1182_o = save_mux;
      default: n1182_o = n985_o;
    endcase
  assign n1183_o = {n1112_o, n1142_o, n1156_o, n1134_o, n1159_o, n1096_o, n1057_o};
  /* T80.vhd:916:41  */
  always @*
    case (n1180_o)
      5'b10000: n1184_o = save_mux;
      5'b01000: n1184_o = n1183_o;
      5'b00100: n1184_o = n1183_o;
      5'b00010: n1184_o = n1183_o;
      5'b00001: n1184_o = n1183_o;
      default: n1184_o = n1183_o;
    endcase
  assign n1185_o = sp[7:0];
  assign n1186_o = n791_o[7:0];
  assign n1187_o = n789_o[7:0];
  /* T80.vhd:771:57  */
  assign n1188_o = n787_o ? n1187_o : n1186_o;
  /* T80.vhd:769:41  */
  assign n1189_o = n794_o ? n1188_o : n1185_o;
  assign n1190_o = regbusc[7:0];
  /* T80.vhd:779:41  */
  assign n1191_o = ldsphl ? n1190_o : n1189_o;
  assign n1192_o = sp[7:0];
  /* T80.vhd:562:33  */
  assign n1193_o = n420_o ? n1192_o : n1191_o;
  /* T80.vhd:916:41  */
  always @*
    case (n1180_o)
      5'b10000: n1194_o = n1193_o;
      5'b01000: n1194_o = n1193_o;
      5'b00100: n1194_o = save_mux;
      5'b00010: n1194_o = n1193_o;
      5'b00001: n1194_o = n1193_o;
      default: n1194_o = n1193_o;
    endcase
  assign n1195_o = sp[15:8];
  assign n1196_o = n791_o[15:8];
  assign n1197_o = n789_o[15:8];
  /* T80.vhd:771:57  */
  assign n1198_o = n787_o ? n1197_o : n1196_o;
  /* T80.vhd:769:41  */
  assign n1199_o = n794_o ? n1198_o : n1195_o;
  assign n1200_o = regbusc[15:8];
  /* T80.vhd:779:41  */
  assign n1201_o = ldsphl ? n1200_o : n1199_o;
  assign n1202_o = sp[15:8];
  /* T80.vhd:562:33  */
  assign n1203_o = n420_o ? n1202_o : n1201_o;
  /* T80.vhd:916:41  */
  always @*
    case (n1180_o)
      5'b10000: n1204_o = n1203_o;
      5'b01000: n1204_o = save_mux;
      5'b00100: n1204_o = n1203_o;
      5'b00010: n1204_o = n1203_o;
      5'b00001: n1204_o = n1203_o;
      default: n1204_o = n1203_o;
    endcase
  /* T80.vhd:929:41  */
  assign n1205_o = xybit_undoc ? alu_q : n1181_o;
  /* T80.vhd:914:33  */
  assign n1206_o = n1169_o ? n1205_o : n1073_o;
  /* T80.vhd:914:33  */
  assign n1207_o = n1169_o ? n1182_o : n985_o;
  assign n1208_o = {n1112_o, n1142_o, n1156_o, n1134_o, n1159_o, n1096_o, n1057_o};
  /* T80.vhd:914:33  */
  assign n1209_o = n1169_o ? n1184_o : n1208_o;
  assign n1210_o = {n1204_o, n1194_o};
  /* T80.vhd:914:33  */
  assign n1211_o = n1169_o ? n1210_o : n809_o;
  /* T80.vhd:543:25  */
  assign n1212_o = clken ? n804_o : n2116_q;
  /* T80.vhd:543:25  */
  assign n1213_o = clken ? n1206_o : n2117_q;
  /* T80.vhd:543:25  */
  assign n1214_o = clken ? n1207_o : acc;
  /* T80.vhd:543:25  */
  assign n1215_o = clken ? n1209_o : f;
  /* T80.vhd:543:25  */
  assign n1216_o = clken ? n807_o : ap;
  /* T80.vhd:543:25  */
  assign n1217_o = clken ? n808_o : fp;
  /* T80.vhd:543:25  */
  assign n1218_o = n1007_o & clken;
  /* T80.vhd:543:25  */
  assign n1219_o = n1008_o & clken;
  /* T80.vhd:543:25  */
  assign n1220_o = clken ? n1211_o : sp;
  /* T80.vhd:543:25  */
  assign n1221_o = clken ? n810_o : pc;
  /* T80.vhd:543:25  */
  assign n1222_o = clken ? n811_o : alternate;
  /* T80.vhd:543:25  */
  assign n1223_o = clken ? n1010_o : wz;
  /* T80.vhd:543:25  */
  assign n1224_o = clken ? n813_o : ir;
  /* T80.vhd:543:25  */
  assign n1225_o = clken ? n814_o : iset;
  /* T80.vhd:543:25  */
  assign n1226_o = n401_o & clken;
  /* T80.vhd:543:25  */
  assign n1227_o = n815_o & clken;
  /* T80.vhd:543:25  */
  assign n1228_o = clken ? n816_o : xy_ind;
  /* T80.vhd:543:25  */
  assign n1229_o = clken ? n817_o : btr_r;
  /* T80.vhd:543:25  */
  assign n1230_o = clken ? n1081_o : read_to_reg_r;
  /* T80.vhd:543:25  */
  assign n1231_o = clken ? arith16 : arith16_r;
  /* T80.vhd:543:25  */
  assign n1232_o = clken ? n415_o : z16_r;
  /* T80.vhd:543:25  */
  assign n1233_o = clken ? n819_o : alu_op_r;
  /* T80.vhd:543:25  */
  assign n1234_o = clken ? n822_o : save_alu_r;
  /* T80.vhd:543:25  */
  assign n1235_o = clken ? preservec : preservec_r;
  /* T80.vhd:543:25  */
  assign n1236_o = clken ? mcycles_d : mcycles;
  /* T80.vhd:543:25  */
  assign n1237_o = n1061_o & clken;
  /* T80.vhd:531:25  */
  assign n1240_o = dirset ? n398_o : n1212_o;
  /* T80.vhd:531:25  */
  assign n1241_o = dirset ? n2117_q : n1213_o;
  /* T80.vhd:531:25  */
  assign n1242_o = dirset ? n390_o : n1214_o;
  /* T80.vhd:531:25  */
  assign n1243_o = dirset ? n391_o : n1215_o;
  /* T80.vhd:531:25  */
  assign n1244_o = dirset ? n392_o : n1216_o;
  /* T80.vhd:531:25  */
  assign n1245_o = dirset ? n393_o : n1217_o;
  /* T80.vhd:531:25  */
  assign n1246_o = dirset ? n394_o : n993_o;
  /* T80.vhd:531:25  */
  assign n1247_o = dirset ? n395_o : n994_o;
  /* T80.vhd:531:25  */
  assign n1248_o = dirset ? n396_o : n1220_o;
  /* T80.vhd:531:25  */
  assign n1249_o = dirset ? n397_o : n1221_o;
  /* T80.vhd:531:25  */
  assign n1250_o = dirset ? alternate : n1222_o;
  /* T80.vhd:531:25  */
  assign n1251_o = dirset ? wz : n1223_o;
  /* T80.vhd:531:25  */
  assign n1252_o = dirset ? ir : n1224_o;
  /* T80.vhd:531:25  */
  assign n1253_o = dirset ? iset : n1225_o;
  /* T80.vhd:531:25  */
  assign n1254_o = dirset ? n399_o : n402_o;
  /* T80.vhd:531:25  */
  assign n1255_o = dirset ? xy_state : n477_o;
  /* T80.vhd:531:25  */
  assign n1256_o = dirset ? xy_ind : n1228_o;
  /* T80.vhd:531:25  */
  assign n1257_o = dirset ? btr_r : n1229_o;
  /* T80.vhd:531:25  */
  assign n1258_o = dirset ? read_to_reg_r : n1230_o;
  /* T80.vhd:531:25  */
  assign n1259_o = dirset ? arith16_r : n1231_o;
  /* T80.vhd:531:25  */
  assign n1260_o = dirset ? z16_r : n1232_o;
  /* T80.vhd:531:25  */
  assign n1261_o = dirset ? alu_op_r : n1233_o;
  /* T80.vhd:531:25  */
  assign n1262_o = dirset ? save_alu_r : n1234_o;
  /* T80.vhd:531:25  */
  assign n1263_o = dirset ? preservec_r : n1235_o;
  /* T80.vhd:531:25  */
  assign n1264_o = dirset ? mcycles : n1236_o;
  /* T80.vhd:531:25  */
  assign n1265_o = dirset ? i_rxdd : n1074_o;
  /* T80.vhd:947:70  */
  assign n1360_o = set_busa_to[2:1];
  /* T80.vhd:947:57  */
  assign n1361_o = {alternate, n1360_o};
  /* T80.vhd:948:43  */
  assign n1362_o = ~xy_ind;
  /* T80.vhd:948:62  */
  assign n1364_o = xy_state != 2'b00;
  /* T80.vhd:948:49  */
  assign n1365_o = n1364_o & n1362_o;
  /* T80.vhd:948:85  */
  assign n1366_o = set_busa_to[2:1];
  /* T80.vhd:948:98  */
  assign n1368_o = n1366_o == 2'b10;
  /* T80.vhd:948:70  */
  assign n1369_o = n1368_o & n1365_o;
  /* T80.vhd:949:63  */
  assign n1370_o = xy_state[1];
  /* T80.vhd:949:67  */
  assign n1372_o = {n1370_o, 2'b11};
  /* T80.vhd:948:33  */
  assign n1373_o = n1369_o ? n1372_o : n1361_o;
  /* T80.vhd:953:70  */
  assign n1374_o = set_busb_to[2:1];
  /* T80.vhd:953:57  */
  assign n1375_o = {alternate, n1374_o};
  /* T80.vhd:954:43  */
  assign n1376_o = ~xy_ind;
  /* T80.vhd:954:62  */
  assign n1378_o = xy_state != 2'b00;
  /* T80.vhd:954:49  */
  assign n1379_o = n1378_o & n1376_o;
  /* T80.vhd:954:85  */
  assign n1380_o = set_busb_to[2:1];
  /* T80.vhd:954:98  */
  assign n1382_o = n1380_o == 2'b10;
  /* T80.vhd:954:70  */
  assign n1383_o = n1382_o & n1379_o;
  /* T80.vhd:955:63  */
  assign n1384_o = xy_state[1];
  /* T80.vhd:955:67  */
  assign n1386_o = {n1384_o, 2'b11};
  /* T80.vhd:954:33  */
  assign n1387_o = n1383_o ? n1386_o : n1375_o;
  /* T80.vhd:959:68  */
  assign n1388_o = set_addr_to[1:0];
  /* T80.vhd:959:55  */
  assign n1389_o = {alternate, n1388_o};
  /* T80.vhd:961:50  */
  assign n1390_o = jumpxy | ldsphl;
  /* T80.vhd:962:63  */
  assign n1392_o = {alternate, 2'b10};
  /* T80.vhd:961:33  */
  assign n1393_o = n1390_o ? n1392_o : n1389_o;
  /* T80.vhd:964:51  */
  assign n1394_o = jumpxy | ldsphl;
  /* T80.vhd:964:81  */
  assign n1396_o = xy_state != 2'b00;
  /* T80.vhd:964:68  */
  assign n1397_o = n1396_o & n1394_o;
  /* T80.vhd:964:101  */
  assign n1399_o = mcycle == 3'b110;
  /* T80.vhd:964:90  */
  assign n1400_o = n1397_o | n1399_o;
  /* T80.vhd:965:61  */
  assign n1401_o = xy_state[1];
  /* T80.vhd:965:65  */
  assign n1403_o = {n1401_o, 2'b11};
  /* T80.vhd:964:33  */
  assign n1404_o = n1400_o ? n1403_o : n1393_o;
  /* T80.vhd:971:44  */
  assign n1407_o = tstate == 3'b010;
  /* T80.vhd:971:59  */
  assign n1409_o = tstate == 3'b011;
  /* T80.vhd:971:74  */
  assign n1411_o = mcycle == 3'b001;
  /* T80.vhd:971:63  */
  assign n1412_o = n1411_o & n1409_o;
  /* T80.vhd:971:48  */
  assign n1413_o = n1407_o | n1412_o;
  /* T80.vhd:971:97  */
  assign n1414_o = incdec_16[2:0];
  /* T80.vhd:971:110  */
  assign n1416_o = n1414_o == 3'b100;
  /* T80.vhd:971:84  */
  assign n1417_o = n1416_o & n1413_o;
  /* T80.vhd:972:49  */
  assign n1419_o = id16 == 16'b0000000000000000;
  /* T80.vhd:972:41  */
  assign n1422_o = n1419_o ? 1'b0 : 1'b1;
  /* T80.vhd:945:25  */
  assign n1428_o = n1417_o & clken;
  /* T80.vhd:986:46  */
  assign n1435_o = incdec_16[1:0];
  /* T80.vhd:986:35  */
  assign n1436_o = {alternate, n1435_o};
  /* T80.vhd:986:72  */
  assign n1438_o = tstate == 3'b010;
  /* T80.vhd:987:41  */
  assign n1440_o = tstate == 3'b011;
  /* T80.vhd:987:56  */
  assign n1442_o = mcycle == 3'b001;
  /* T80.vhd:987:45  */
  assign n1443_o = n1442_o & n1440_o;
  /* T80.vhd:987:77  */
  assign n1444_o = incdec_16[2];
  /* T80.vhd:987:64  */
  assign n1445_o = n1444_o & n1443_o;
  /* T80.vhd:986:76  */
  assign n1446_o = n1438_o | n1445_o;
  /* T80.vhd:987:102  */
  assign n1448_o = xy_state == 2'b00;
  /* T80.vhd:987:89  */
  assign n1449_o = n1448_o & n1446_o;
  /* T80.vhd:986:59  */
  assign n1450_o = n1449_o ? n1436_o : n1468_o;
  /* T80.vhd:988:33  */
  assign n1451_o = xy_state[1];
  /* T80.vhd:988:37  */
  assign n1453_o = {n1451_o, 2'b11};
  /* T80.vhd:988:57  */
  assign n1455_o = tstate == 3'b010;
  /* T80.vhd:989:41  */
  assign n1457_o = tstate == 3'b011;
  /* T80.vhd:989:56  */
  assign n1459_o = mcycle == 3'b001;
  /* T80.vhd:989:45  */
  assign n1460_o = n1459_o & n1457_o;
  /* T80.vhd:989:77  */
  assign n1461_o = incdec_16[2];
  /* T80.vhd:989:64  */
  assign n1462_o = n1461_o & n1460_o;
  /* T80.vhd:988:61  */
  assign n1463_o = n1455_o | n1462_o;
  /* T80.vhd:989:102  */
  assign n1464_o = incdec_16[1:0];
  /* T80.vhd:989:115  */
  assign n1466_o = n1464_o == 2'b10;
  /* T80.vhd:989:89  */
  assign n1467_o = n1466_o & n1463_o;
  /* T80.vhd:987:109  */
  assign n1468_o = n1467_o ? n1453_o : n1474_o;
  /* T80.vhd:991:35  */
  assign n1470_o = {alternate, 2'b10};
  /* T80.vhd:991:75  */
  assign n1472_o = tstate == 3'b011;
  /* T80.vhd:991:64  */
  assign n1473_o = n1472_o & exchangedh;
  /* T80.vhd:989:122  */
  assign n1474_o = n1473_o ? n1470_o : n1480_o;
  /* T80.vhd:992:35  */
  assign n1476_o = {alternate, 2'b01};
  /* T80.vhd:992:75  */
  assign n1478_o = tstate == 3'b100;
  /* T80.vhd:992:64  */
  assign n1479_o = n1478_o & exchangedh;
  /* T80.vhd:991:79  */
  assign n1480_o = n1479_o ? n1476_o : regaddra_r;
  /* T80.vhd:998:35  */
  assign n1482_o = {alternate, 2'b01};
  /* T80.vhd:998:75  */
  assign n1484_o = tstate == 3'b011;
  /* T80.vhd:998:64  */
  assign n1485_o = n1484_o & exchangedh;
  /* T80.vhd:998:42  */
  assign n1486_o = n1485_o ? n1482_o : regaddrb_r;
  /* T80.vhd:1002:33  */
  assign n1488_o = regbusa - 16'b0000000000000001;
  /* T80.vhd:1002:51  */
  assign n1489_o = incdec_16[3];
  /* T80.vhd:1002:37  */
  assign n1490_o = n1489_o ? n1488_o : n1492_o;
  /* T80.vhd:1003:41  */
  assign n1492_o = regbusa + 16'b0000000000000001;
  /* T80.vhd:1010:28  */
  assign n1496_o = tstate == 3'b001;
  /* T80.vhd:1010:47  */
  assign n1497_o = ~save_alu_r;
  /* T80.vhd:1010:32  */
  assign n1498_o = n1497_o & n1496_o;
  /* T80.vhd:1010:70  */
  assign n1499_o = ~auto_wait_t1;
  /* T80.vhd:1010:53  */
  assign n1500_o = n1499_o & n1498_o;
  /* T80.vhd:1011:56  */
  assign n1502_o = alu_op_r != 4'b0111;
  /* T80.vhd:1011:43  */
  assign n1503_o = n1502_o & save_alu_r;
  /* T80.vhd:1010:77  */
  assign n1504_o = n1500_o | n1503_o;
  /* T80.vhd:1014:60  */
  assign n1505_o = read_to_reg_r[0];
  /* T80.vhd:1014:43  */
  assign n1506_o = ~n1505_o;
  /* T80.vhd:1015:56  */
  assign n1507_o = read_to_reg_r[0];
  /* T80.vhd:1013:25  */
  assign n1509_o = read_to_reg_r == 5'b10000;
  /* T80.vhd:1013:38  */
  assign n1511_o = read_to_reg_r == 5'b10001;
  /* T80.vhd:1013:38  */
  assign n1512_o = n1509_o | n1511_o;
  /* T80.vhd:1013:48  */
  assign n1514_o = read_to_reg_r == 5'b10010;
  /* T80.vhd:1013:48  */
  assign n1515_o = n1512_o | n1514_o;
  /* T80.vhd:1013:58  */
  assign n1517_o = read_to_reg_r == 5'b10011;
  /* T80.vhd:1013:58  */
  assign n1518_o = n1515_o | n1517_o;
  /* T80.vhd:1013:68  */
  assign n1520_o = read_to_reg_r == 5'b10100;
  /* T80.vhd:1013:68  */
  assign n1521_o = n1518_o | n1520_o;
  /* T80.vhd:1013:78  */
  assign n1523_o = read_to_reg_r == 5'b10101;
  /* T80.vhd:1013:78  */
  assign n1524_o = n1521_o | n1523_o;
  /* T80.vhd:1012:25  */
  always @*
    case (n1524_o)
      1'b1: n1526_o = n1506_o;
      default: n1526_o = 1'b0;
    endcase
  /* T80.vhd:1012:25  */
  always @*
    case (n1524_o)
      1'b1: n1528_o = n1507_o;
      default: n1528_o = 1'b0;
    endcase
  /* T80.vhd:1010:17  */
  assign n1530_o = n1504_o ? n1526_o : 1'b0;
  /* T80.vhd:1010:17  */
  assign n1533_o = n1504_o ? n1528_o : 1'b0;
  /* T80.vhd:1020:49  */
  assign n1536_o = tstate == 3'b011;
  /* T80.vhd:1020:63  */
  assign n1538_o = tstate == 3'b100;
  /* T80.vhd:1020:53  */
  assign n1539_o = n1536_o | n1538_o;
  /* T80.vhd:1020:37  */
  assign n1540_o = n1539_o & exchangedh;
  /* T80.vhd:1020:17  */
  assign n1542_o = n1540_o ? 1'b1 : n1530_o;
  /* T80.vhd:1020:17  */
  assign n1544_o = n1540_o ? 1'b1 : n1533_o;
  /* T80.vhd:1025:29  */
  assign n1545_o = incdec_16[2];
  /* T80.vhd:1025:52  */
  assign n1547_o = tstate == 3'b010;
  /* T80.vhd:1025:56  */
  assign n1548_o = wait_n & n1547_o;
  /* T80.vhd:1025:84  */
  assign n1550_o = mcycle != 3'b001;
  /* T80.vhd:1025:73  */
  assign n1551_o = n1550_o & n1548_o;
  /* T80.vhd:1025:105  */
  assign n1553_o = tstate == 3'b011;
  /* T80.vhd:1025:120  */
  assign n1555_o = mcycle == 3'b001;
  /* T80.vhd:1025:109  */
  assign n1556_o = n1555_o & n1553_o;
  /* T80.vhd:1025:94  */
  assign n1557_o = n1551_o | n1556_o;
  /* T80.vhd:1025:39  */
  assign n1558_o = n1557_o & n1545_o;
  /* T80.vhd:1026:39  */
  assign n1559_o = incdec_16[1:0];
  /* T80.vhd:1027:25  */
  assign n1561_o = n1559_o == 2'b00;
  /* T80.vhd:1027:35  */
  assign n1563_o = n1559_o == 2'b01;
  /* T80.vhd:1027:35  */
  assign n1564_o = n1561_o | n1563_o;
  /* T80.vhd:1027:42  */
  assign n1566_o = n1559_o == 2'b10;
  /* T80.vhd:1027:42  */
  assign n1567_o = n1564_o | n1566_o;
  /* T80.vhd:1026:25  */
  always @*
    case (n1567_o)
      1'b1: n1569_o = 1'b1;
      default: n1569_o = n1542_o;
    endcase
  /* T80.vhd:1026:25  */
  always @*
    case (n1567_o)
      1'b1: n1571_o = 1'b1;
      default: n1571_o = n1544_o;
    endcase
  /* T80.vhd:1025:17  */
  assign n1572_o = n1558_o ? n1569_o : n1542_o;
  /* T80.vhd:1025:17  */
  assign n1573_o = n1558_o ? n1571_o : n1544_o;
  /* T80.vhd:1041:48  */
  assign n1578_o = tstate == 3'b011;
  /* T80.vhd:1041:37  */
  assign n1579_o = n1578_o & exchangedh;
  /* T80.vhd:1042:42  */
  assign n1580_o = regbusb[15:8];
  /* T80.vhd:1043:42  */
  assign n1581_o = regbusb[7:0];
  /* T80.vhd:1041:17  */
  assign n1582_o = n1579_o ? n1580_o : save_mux;
  /* T80.vhd:1041:17  */
  assign n1583_o = n1579_o ? n1581_o : save_mux;
  /* T80.vhd:1045:48  */
  assign n1585_o = tstate == 3'b100;
  /* T80.vhd:1045:37  */
  assign n1586_o = n1585_o & exchangedh;
  /* T80.vhd:1046:44  */
  assign n1587_o = regbusa_r[15:8];
  /* T80.vhd:1047:44  */
  assign n1588_o = regbusa_r[7:0];
  /* T80.vhd:1045:17  */
  assign n1589_o = n1586_o ? n1587_o : n1582_o;
  /* T80.vhd:1045:17  */
  assign n1590_o = n1586_o ? n1588_o : n1583_o;
  /* T80.vhd:1050:29  */
  assign n1591_o = incdec_16[2];
  /* T80.vhd:1050:52  */
  assign n1593_o = tstate == 3'b010;
  /* T80.vhd:1050:67  */
  assign n1595_o = mcycle != 3'b001;
  /* T80.vhd:1050:56  */
  assign n1596_o = n1595_o & n1593_o;
  /* T80.vhd:1050:88  */
  assign n1598_o = tstate == 3'b011;
  /* T80.vhd:1050:103  */
  assign n1600_o = mcycle == 3'b001;
  /* T80.vhd:1050:92  */
  assign n1601_o = n1600_o & n1598_o;
  /* T80.vhd:1050:77  */
  assign n1602_o = n1596_o | n1601_o;
  /* T80.vhd:1050:39  */
  assign n1603_o = n1602_o & n1591_o;
  /* T80.vhd:1051:56  */
  assign n1604_o = id16[15:8];
  /* T80.vhd:1052:56  */
  assign n1605_o = id16[7:0];
  /* T80.vhd:1050:17  */
  assign n1606_o = n1603_o ? n1604_o : n1589_o;
  /* T80.vhd:1050:17  */
  assign n1607_o = n1603_o ? n1605_o : n1590_o;
  /* T80.vhd:1067:33  */
  assign u_regs_n1609 = u_regs_doah; // (signal)
  /* T80.vhd:1068:33  */
  assign u_regs_n1610 = u_regs_doal; // (signal)
  /* T80.vhd:1069:33  */
  assign u_regs_n1611 = u_regs_dobh; // (signal)
  /* T80.vhd:1070:33  */
  assign u_regs_n1612 = u_regs_dobl; // (signal)
  /* T80.vhd:1071:33  */
  assign u_regs_n1613 = u_regs_doch; // (signal)
  /* T80.vhd:1072:33  */
  assign u_regs_n1614 = u_regs_docl; // (signal)
  /* T80.vhd:1073:33  */
  assign u_regs_n1615 = u_regs_dor; // (signal)
  /* T80.vhd:1075:36  */
  assign n1616_o = dir[207:80];
  /* T80.vhd:1056:9  */
  t8080_reg u_regs (
    .clk(clk_n),
    .cen(clken),
    .weh(regweh),
    .wel(regwel),
    .addra(regaddra),
    .addrb(regaddrb),
    .addrc(regaddrc),
    .dih(regdih),
    .dil(regdil),
    .dirset(dirset),
    .dir(n1616_o),
    .doah(u_regs_doah),
    .doal(u_regs_doal),
    .dobh(u_regs_dobh),
    .dobl(u_regs_dobl),
    .doch(u_regs_doch),
    .docl(u_regs_docl),
    .dor(u_regs_dor));
  /* T80.vhd:1087:33  */
  assign n1635_o = set_busb_to == 4'b0111;
  /* T80.vhd:1090:55  */
  assign n1636_o = set_busb_to[0];
  /* T80.vhd:1091:64  */
  assign n1637_o = regbusb[7:0];
  /* T80.vhd:1093:64  */
  assign n1638_o = regbusb[15:8];
  /* T80.vhd:1090:41  */
  assign n1639_o = n1636_o ? n1637_o : n1638_o;
  /* T80.vhd:1089:33  */
  assign n1641_o = set_busb_to == 4'b0000;
  /* T80.vhd:1089:45  */
  assign n1643_o = set_busb_to == 4'b0001;
  /* T80.vhd:1089:45  */
  assign n1644_o = n1641_o | n1643_o;
  /* T80.vhd:1089:54  */
  assign n1646_o = set_busb_to == 4'b0010;
  /* T80.vhd:1089:54  */
  assign n1647_o = n1644_o | n1646_o;
  /* T80.vhd:1089:63  */
  assign n1649_o = set_busb_to == 4'b0011;
  /* T80.vhd:1089:63  */
  assign n1650_o = n1647_o | n1649_o;
  /* T80.vhd:1089:72  */
  assign n1652_o = set_busb_to == 4'b0100;
  /* T80.vhd:1089:72  */
  assign n1653_o = n1650_o | n1652_o;
  /* T80.vhd:1089:81  */
  assign n1655_o = set_busb_to == 4'b0101;
  /* T80.vhd:1089:81  */
  assign n1656_o = n1653_o | n1655_o;
  /* T80.vhd:1095:33  */
  assign n1658_o = set_busb_to == 4'b0110;
  /* T80.vhd:1098:68  */
  assign n1659_o = sp[7:0];
  /* T80.vhd:1097:33  */
  assign n1661_o = set_busb_to == 4'b1000;
  /* T80.vhd:1100:68  */
  assign n1662_o = sp[15:8];
  /* T80.vhd:1099:33  */
  assign n1664_o = set_busb_to == 4'b1001;
  /* T80.vhd:1101:33  */
  assign n1666_o = set_busb_to == 4'b1010;
  /* T80.vhd:1103:33  */
  assign n1668_o = set_busb_to == 4'b1011;
  /* T80.vhd:1106:68  */
  assign n1669_o = pc[7:0];
  /* T80.vhd:1105:33  */
  assign n1671_o = set_busb_to == 4'b1100;
  /* T80.vhd:1108:68  */
  assign n1672_o = pc[15:8];
  /* T80.vhd:1107:33  */
  assign n1674_o = set_busb_to == 4'b1101;
  /* T80.vhd:1110:47  */
  assign n1676_o = ir == 8'b01110001;
  /* T80.vhd:1110:55  */
  assign n1677_o = out0 & n1676_o;
  /* T80.vhd:1110:41  */
  assign n1680_o = n1677_o ? 8'b11111111 : 8'b00000000;
  /* T80.vhd:1109:33  */
  assign n1682_o = set_busb_to == 4'b1110;
  assign n1683_o = {n1682_o, n1674_o, n1671_o, n1668_o, n1666_o, n1664_o, n1661_o, n1658_o, n1656_o, n1635_o};
  /* T80.vhd:1086:33  */
  always @*
    case (n1683_o)
      10'b1000000000: n1686_o = n1680_o;
      10'b0100000000: n1686_o = n1672_o;
      10'b0010000000: n1686_o = n1669_o;
      10'b0001000000: n1686_o = f;
      10'b0000100000: n1686_o = 8'b00000001;
      10'b0000010000: n1686_o = n1662_o;
      10'b0000001000: n1686_o = n1659_o;
      10'b0000000100: n1686_o = di_reg;
      10'b0000000010: n1686_o = n1639_o;
      10'b0000000001: n1686_o = acc;
      default: n1686_o = 8'bX;
    endcase
  /* T80.vhd:1120:33  */
  assign n1688_o = set_busa_to == 4'b0111;
  /* T80.vhd:1123:55  */
  assign n1689_o = set_busa_to[0];
  /* T80.vhd:1124:64  */
  assign n1690_o = regbusa[7:0];
  /* T80.vhd:1126:64  */
  assign n1691_o = regbusa[15:8];
  /* T80.vhd:1123:41  */
  assign n1692_o = n1689_o ? n1690_o : n1691_o;
  /* T80.vhd:1122:33  */
  assign n1694_o = set_busa_to == 4'b0000;
  /* T80.vhd:1122:45  */
  assign n1696_o = set_busa_to == 4'b0001;
  /* T80.vhd:1122:45  */
  assign n1697_o = n1694_o | n1696_o;
  /* T80.vhd:1122:54  */
  assign n1699_o = set_busa_to == 4'b0010;
  /* T80.vhd:1122:54  */
  assign n1700_o = n1697_o | n1699_o;
  /* T80.vhd:1122:63  */
  assign n1702_o = set_busa_to == 4'b0011;
  /* T80.vhd:1122:63  */
  assign n1703_o = n1700_o | n1702_o;
  /* T80.vhd:1122:72  */
  assign n1705_o = set_busa_to == 4'b0100;
  /* T80.vhd:1122:72  */
  assign n1706_o = n1703_o | n1705_o;
  /* T80.vhd:1122:81  */
  assign n1708_o = set_busa_to == 4'b0101;
  /* T80.vhd:1122:81  */
  assign n1709_o = n1706_o | n1708_o;
  /* T80.vhd:1128:33  */
  assign n1711_o = set_busa_to == 4'b0110;
  /* T80.vhd:1131:68  */
  assign n1712_o = sp[7:0];
  /* T80.vhd:1130:33  */
  assign n1714_o = set_busa_to == 4'b1000;
  /* T80.vhd:1133:68  */
  assign n1715_o = sp[15:8];
  /* T80.vhd:1132:33  */
  assign n1717_o = set_busa_to == 4'b1001;
  /* T80.vhd:1134:33  */
  assign n1719_o = set_busa_to == 4'b1010;
  assign n1720_o = {n1719_o, n1717_o, n1714_o, n1711_o, n1709_o, n1688_o};
  /* T80.vhd:1119:33  */
  always @*
    case (n1720_o)
      6'b100000: n1723_o = 8'b00000000;
      6'b010000: n1723_o = n1715_o;
      6'b001000: n1723_o = n1712_o;
      6'b000100: n1723_o = di_reg;
      6'b000010: n1723_o = n1692_o;
      6'b000001: n1723_o = acc;
      default: n1723_o = 8'bX;
    endcase
  /* T80.vhd:1139:33  */
  assign n1724_o = xybit_undoc ? di_reg : n1686_o;
  /* T80.vhd:1139:33  */
  assign n1725_o = xybit_undoc ? di_reg : n1723_o;
  /* T80.vhd:1154:28  */
  assign n1733_o = ~reset_n;
  /* T80.vhd:1157:35  */
  assign n1735_o = ~dirset;
  /* T80.vhd:1157:41  */
  assign n1736_o = cen & n1735_o;
  /* T80.vhd:1158:43  */
  assign n1738_o = mcycle == 3'b001;
  /* T80.vhd:1158:64  */
  assign n1740_o = tstate == 3'b010;
  /* T80.vhd:1158:69  */
  assign n1741_o = wait_n & n1740_o;
  /* T80.vhd:1158:97  */
  assign n1743_o = tstate == 3'b011;
  /* T80.vhd:1158:87  */
  assign n1744_o = n1741_o | n1743_o;
  /* T80.vhd:1158:51  */
  assign n1745_o = n1744_o & n1738_o;
  /* T80.vhd:1158:33  */
  assign n1748_o = n1745_o ? 1'b0 : 1'b1;
  /* T80.vhd:1170:19  */
  assign n1754_o = ~halt_ff;
  /* T80.vhd:1171:20  */
  assign n1755_o = ~busack;
  /* T80.vhd:1172:23  */
  assign n1756_o = ~intcycle;
  /* T80.vhd:1183:26  */
  always @*
    n1757_oldnmi_n = n2051_q; // (isignal)
  initial
    n1757_oldnmi_n = 1'bX;
  /* T80.vhd:1185:28  */
  assign n1760_o = ~reset_n;
  /* T80.vhd:1204:48  */
  assign n1762_o = dir[211];
  /* T80.vhd:1205:48  */
  assign n1763_o = dir[210];
  /* T80.vhd:1207:42  */
  assign n1764_o = ~nmi_n;
  /* T80.vhd:1207:48  */
  assign n1765_o = n1757_oldnmi_n & n1764_o;
  /* T80.vhd:1207:33  */
  assign n1767_o = n1765_o ? 1'b1 : nmi_s;
  /* T80.vhd:1213:53  */
  assign n1768_o = ~busrq_n;
  /* T80.vhd:1219:75  */
  assign n1769_o = auto_wait | iorq_i;
  /* T80.vhd:1215:41  */
  assign n1771_o = t_res ? 1'b0 : n1769_o;
  /* T80.vhd:1215:41  */
  assign n1773_o = t_res ? 1'b0 : auto_wait_t1;
  /* T80.vhd:1221:68  */
  assign n1774_o = ir[4];
  /* T80.vhd:1221:62  */
  assign n1775_o = ~n1774_o;
  /* T80.vhd:1221:80  */
  assign n1776_o = f[2];
  /* T80.vhd:1221:75  */
  assign n1777_o = ~n1776_o;
  /* T80.vhd:1221:72  */
  assign n1778_o = n1775_o | n1777_o;
  /* T80.vhd:1221:57  */
  assign n1779_o = i_bt & n1778_o;
  /* T80.vhd:1222:74  */
  assign n1780_o = ir[4];
  /* T80.vhd:1222:68  */
  assign n1781_o = ~n1780_o;
  /* T80.vhd:1222:82  */
  assign n1782_o = f[6];
  /* T80.vhd:1222:78  */
  assign n1783_o = n1781_o | n1782_o;
  /* T80.vhd:1222:99  */
  assign n1784_o = f[2];
  /* T80.vhd:1222:94  */
  assign n1785_o = ~n1784_o;
  /* T80.vhd:1222:91  */
  assign n1786_o = n1783_o | n1785_o;
  /* T80.vhd:1222:63  */
  assign n1787_o = i_bc & n1786_o;
  /* T80.vhd:1221:91  */
  assign n1788_o = n1779_o | n1787_o;
  /* T80.vhd:1223:75  */
  assign n1789_o = ir[4];
  /* T80.vhd:1223:69  */
  assign n1790_o = ~n1789_o;
  /* T80.vhd:1223:83  */
  assign n1791_o = f[6];
  /* T80.vhd:1223:79  */
  assign n1792_o = n1790_o | n1791_o;
  /* T80.vhd:1223:64  */
  assign n1793_o = i_btr & n1792_o;
  /* T80.vhd:1222:110  */
  assign n1794_o = n1788_o | n1793_o;
  /* T80.vhd:1224:51  */
  assign n1796_o = tstate == 3'b010;
  /* T80.vhd:1228:69  */
  assign n1797_o = ~nmicycle;
  /* T80.vhd:1225:49  */
  assign n1799_o = n1800_o ? 1'b1 : inte_ff1;
  /* T80.vhd:1225:49  */
  assign n1800_o = n1797_o & setei;
  /* T80.vhd:1224:41  */
  assign n1802_o = n1805_o ? 1'b1 : inte_ff2;
  /* T80.vhd:1233:49  */
  assign n1803_o = i_retn ? inte_ff2 : n1799_o;
  /* T80.vhd:1224:41  */
  assign n1804_o = n1796_o ? n1803_o : inte_ff1;
  /* T80.vhd:1224:41  */
  assign n1805_o = setei & n1796_o;
  /* T80.vhd:1237:51  */
  assign n1807_o = tstate == 3'b011;
  /* T80.vhd:1237:41  */
  assign n1809_o = n1812_o ? 1'b0 : n1804_o;
  /* T80.vhd:1237:41  */
  assign n1811_o = n1813_o ? 1'b0 : n1802_o;
  /* T80.vhd:1237:41  */
  assign n1812_o = setdi & n1807_o;
  /* T80.vhd:1237:41  */
  assign n1813_o = setdi & n1807_o;
  /* T80.vhd:1243:59  */
  assign n1814_o = intcycle | nmicycle;
  /* T80.vhd:1243:41  */
  assign n1816_o = n1814_o ? 1'b0 : halt_ff;
  /* T80.vhd:1246:51  */
  assign n1818_o = mcycle == 3'b001;
  /* T80.vhd:1246:70  */
  assign n1820_o = tstate == 3'b010;
  /* T80.vhd:1246:59  */
  assign n1821_o = n1820_o & n1818_o;
  /* T80.vhd:1246:74  */
  assign n1822_o = wait_n & n1821_o;
  /* T80.vhd:1246:41  */
  assign n1824_o = n1822_o ? 1'b1 : n2113_q;
  /* T80.vhd:1249:65  */
  assign n1825_o = busack & busreq_s;
  /* T80.vhd:1249:44  */
  assign n1826_o = ~n1825_o;
  /* T80.vhd:1251:59  */
  assign n1828_o = tstate == 3'b010;
  /* T80.vhd:1251:74  */
  assign n1829_o = ~wait_n;
  /* T80.vhd:1251:63  */
  assign n1830_o = n1829_o & n1828_o;
  /* T80.vhd:1252:49  */
  assign n1832_o = n1935_o ? 1'b1 : n1816_o;
  /* T80.vhd:1266:79  */
  assign n1836_o = mcycle == 3'b111;
  /* T80.vhd:1266:88  */
  assign n1840_o = n1836_o | 1'b0;
  /* T80.vhd:1267:121  */
  assign n1842_o = pre_xy_f_m + 3'b001;
  /* T80.vhd:1268:79  */
  assign n1843_o = mcycle == mcycles;
  /* T80.vhd:1268:90  */
  assign n1844_o = n1843_o | no_btr;
  /* T80.vhd:1268:117  */
  assign n1846_o = mcycle == 3'b010;
  /* T80.vhd:1268:125  */
  assign n1847_o = i_djnz & n1846_o;
  /* T80.vhd:1268:142  */
  assign n1848_o = incdecz & n1847_o;
  /* T80.vhd:1268:106  */
  assign n1849_o = n1844_o | n1848_o;
  /* T80.vhd:1273:99  */
  assign n1851_o = prefix == 2'b00;
  /* T80.vhd:1273:88  */
  assign n1852_o = n1851_o & nmi_s;
  /* T80.vhd:1277:103  */
  assign n1853_o = ~int_n;
  /* T80.vhd:1277:94  */
  assign n1854_o = n1853_o & inte_ff1;
  /* T80.vhd:1277:119  */
  assign n1856_o = prefix == 2'b00;
  /* T80.vhd:1277:108  */
  assign n1857_o = n1856_o & n1854_o;
  /* T80.vhd:1277:136  */
  assign n1858_o = ~setei;
  /* T80.vhd:1277:126  */
  assign n1859_o = n1858_o & n1857_o;
  /* T80.vhd:1277:73  */
  assign n1861_o = n1859_o ? 1'b0 : n1809_o;
  /* T80.vhd:1277:73  */
  assign n1863_o = n1859_o ? 1'b0 : n1811_o;
  /* T80.vhd:1277:73  */
  assign n1866_o = n1859_o ? 1'b1 : 1'b0;
  /* T80.vhd:1273:73  */
  assign n1868_o = n1852_o ? 1'b0 : n1861_o;
  /* T80.vhd:1273:73  */
  assign n1869_o = n1852_o ? n1811_o : n1863_o;
  /* T80.vhd:1268:65  */
  assign n1871_o = n1887_o ? 1'b0 : n1767_o;
  /* T80.vhd:1273:73  */
  assign n1873_o = n1852_o ? 1'b0 : n1866_o;
  /* T80.vhd:1273:73  */
  assign n1877_o = n1852_o ? 1'b1 : 1'b0;
  /* T80.vhd:1283:117  */
  assign n1880_o = mcycle + 3'b001;
  /* T80.vhd:1268:65  */
  assign n1882_o = n1849_o ? 1'b0 : n1824_o;
  /* T80.vhd:1268:65  */
  assign n1884_o = n1849_o ? 3'b001 : n1880_o;
  /* T80.vhd:1268:65  */
  assign n1885_o = n1849_o ? n1868_o : n1809_o;
  /* T80.vhd:1268:65  */
  assign n1886_o = n1849_o ? n1869_o : n1811_o;
  /* T80.vhd:1268:65  */
  assign n1887_o = n1852_o & n1849_o;
  /* T80.vhd:1268:65  */
  assign n1888_o = n1849_o ? n1873_o : intcycle;
  /* T80.vhd:1268:65  */
  assign n1889_o = n1849_o ? n1877_o : nmicycle;
  /* T80.vhd:1266:65  */
  assign n1890_o = n1840_o ? n1824_o : n1882_o;
  /* T80.vhd:1266:65  */
  assign n1891_o = n1840_o ? n1842_o : n1884_o;
  /* T80.vhd:1266:65  */
  assign n1892_o = n1840_o ? n1809_o : n1885_o;
  /* T80.vhd:1266:65  */
  assign n1893_o = n1840_o ? n1811_o : n1886_o;
  /* T80.vhd:1266:65  */
  assign n1894_o = n1840_o ? n1767_o : n1871_o;
  /* T80.vhd:1266:65  */
  assign n1895_o = n1840_o ? intcycle : n1888_o;
  /* T80.vhd:1266:65  */
  assign n1896_o = n1840_o ? nmicycle : n1889_o;
  /* T80.vhd:1260:65  */
  assign n1897_o = nextis_xy_fetch ? n1824_o : n1890_o;
  /* T80.vhd:1260:65  */
  assign n1899_o = nextis_xy_fetch ? 3'b110 : n1891_o;
  /* T80.vhd:1260:65  */
  assign n1900_o = nextis_xy_fetch ? n1809_o : n1892_o;
  /* T80.vhd:1260:65  */
  assign n1901_o = nextis_xy_fetch ? n1811_o : n1893_o;
  /* T80.vhd:1260:65  */
  assign n1902_o = nextis_xy_fetch ? n1767_o : n1894_o;
  /* T80.vhd:1260:65  */
  assign n1903_o = nextis_xy_fetch ? mcycle : pre_xy_f_m;
  /* T80.vhd:1260:65  */
  assign n1904_o = nextis_xy_fetch ? intcycle : n1895_o;
  /* T80.vhd:1260:65  */
  assign n1905_o = nextis_xy_fetch ? nmicycle : n1896_o;
  /* T80.vhd:1256:57  */
  assign n1906_o = busreq_s ? n1824_o : n1897_o;
  /* T80.vhd:1256:57  */
  assign n1908_o = busreq_s ? tstate : 3'b001;
  /* T80.vhd:1256:57  */
  assign n1909_o = busreq_s ? mcycle : n1899_o;
  /* T80.vhd:1256:57  */
  assign n1910_o = busreq_s ? n1809_o : n1900_o;
  /* T80.vhd:1256:57  */
  assign n1911_o = busreq_s ? n1811_o : n1901_o;
  /* T80.vhd:1256:57  */
  assign n1914_o = busreq_s ? 1'b1 : 1'b0;
  /* T80.vhd:1256:57  */
  assign n1915_o = busreq_s ? n1767_o : n1902_o;
  /* T80.vhd:1256:57  */
  assign n1916_o = busreq_s ? pre_xy_f_m : n1903_o;
  /* T80.vhd:1256:57  */
  assign n1917_o = busreq_s ? intcycle : n1904_o;
  /* T80.vhd:1256:57  */
  assign n1918_o = busreq_s ? nmicycle : n1905_o;
  /* T80.vhd:1287:94  */
  assign n1919_o = ~auto_wait_t2;
  /* T80.vhd:1287:77  */
  assign n1920_o = n1919_o & auto_wait;
  /* T80.vhd:1288:77  */
  assign n1922_o = iorq_i & 1'b1;
  /* T80.vhd:1288:111  */
  assign n1923_o = ~auto_wait_t1;
  /* T80.vhd:1288:94  */
  assign n1924_o = n1923_o & n1922_o;
  /* T80.vhd:1287:101  */
  assign n1925_o = n1920_o | n1924_o;
  /* T80.vhd:1287:101  */
  assign n1926_o = ~n1925_o;
  /* T80.vhd:1289:82  */
  assign n1928_o = tstate + 3'b001;
  /* T80.vhd:1287:57  */
  assign n1929_o = n1926_o ? n1928_o : tstate;
  /* T80.vhd:1252:49  */
  assign n1930_o = t_res ? n1906_o : n1824_o;
  /* T80.vhd:1252:49  */
  assign n1931_o = t_res ? n1908_o : n1929_o;
  /* T80.vhd:1252:49  */
  assign n1932_o = t_res ? n1909_o : mcycle;
  /* T80.vhd:1252:49  */
  assign n1933_o = t_res ? n1910_o : n1809_o;
  /* T80.vhd:1252:49  */
  assign n1934_o = t_res ? n1911_o : n1811_o;
  /* T80.vhd:1252:49  */
  assign n1935_o = halt & t_res;
  /* T80.vhd:1252:49  */
  assign n1937_o = t_res ? n1914_o : 1'b0;
  /* T80.vhd:1252:49  */
  assign n1938_o = t_res ? n1915_o : n1767_o;
  /* T80.vhd:1252:49  */
  assign n1939_o = t_res ? n1916_o : pre_xy_f_m;
  /* T80.vhd:1252:49  */
  assign n1940_o = t_res ? n1917_o : intcycle;
  /* T80.vhd:1252:49  */
  assign n1941_o = t_res ? n1918_o : nmicycle;
  /* T80.vhd:1251:49  */
  assign n1942_o = n1830_o ? n1824_o : n1930_o;
  /* T80.vhd:1251:49  */
  assign n1943_o = n1830_o ? tstate : n1931_o;
  /* T80.vhd:1251:49  */
  assign n1944_o = n1830_o ? mcycle : n1932_o;
  /* T80.vhd:1251:49  */
  assign n1945_o = n1830_o ? n1809_o : n1933_o;
  /* T80.vhd:1251:49  */
  assign n1946_o = n1830_o ? n1811_o : n1934_o;
  /* T80.vhd:1251:49  */
  assign n1947_o = n1830_o ? n1816_o : n1832_o;
  /* T80.vhd:1251:49  */
  assign n1949_o = n1830_o ? 1'b0 : n1937_o;
  /* T80.vhd:1251:49  */
  assign n1951_o = n1830_o ? n1767_o : n1938_o;
  /* T80.vhd:1251:49  */
  assign n1952_o = n1830_o ? pre_xy_f_m : n1939_o;
  /* T80.vhd:1251:49  */
  assign n1953_o = n1830_o ? intcycle : n1940_o;
  /* T80.vhd:1251:49  */
  assign n1954_o = n1830_o ? nmicycle : n1941_o;
  /* T80.vhd:1249:41  */
  assign n1955_o = n1826_o ? n1942_o : n1824_o;
  /* T80.vhd:1212:33  */
  assign n1956_o = n1971_o ? n1943_o : tstate;
  /* T80.vhd:1212:33  */
  assign n1957_o = n1972_o ? n1944_o : mcycle;
  /* T80.vhd:1249:41  */
  assign n1958_o = n1826_o ? n1945_o : n1809_o;
  /* T80.vhd:1249:41  */
  assign n1959_o = n1826_o ? n1946_o : n1811_o;
  /* T80.vhd:1249:41  */
  assign n1960_o = n1826_o ? n1947_o : n1816_o;
  /* T80.vhd:1212:33  */
  assign n1961_o = n1977_o ? n1949_o : busack;
  /* T80.vhd:1212:33  */
  assign n1962_o = n1978_o ? n1951_o : n1767_o;
  /* T80.vhd:1212:33  */
  assign n1963_o = n1979_o ? n1952_o : pre_xy_f_m;
  /* T80.vhd:1212:33  */
  assign n1964_o = n1983_o ? n1953_o : intcycle;
  /* T80.vhd:1212:33  */
  assign n1965_o = n1984_o ? n1954_o : nmicycle;
  /* T80.vhd:1293:51  */
  assign n1967_o = tstate == 3'b000;
  /* T80.vhd:1293:41  */
  assign n1969_o = n1967_o ? 1'b0 : n1955_o;
  /* T80.vhd:1212:33  */
  assign n1970_o = cen ? n1969_o : n2113_q;
  /* T80.vhd:1212:33  */
  assign n1971_o = n1826_o & cen;
  /* T80.vhd:1212:33  */
  assign n1972_o = n1826_o & cen;
  /* T80.vhd:1212:33  */
  assign n1973_o = cen ? n1958_o : inte_ff1;
  /* T80.vhd:1212:33  */
  assign n1974_o = cen ? n1959_o : inte_ff2;
  /* T80.vhd:1212:33  */
  assign n1975_o = cen ? n1960_o : halt_ff;
  /* T80.vhd:1212:33  */
  assign n1976_o = cen ? n1768_o : busreq_s;
  /* T80.vhd:1212:33  */
  assign n1977_o = n1826_o & cen;
  /* T80.vhd:1212:33  */
  assign n1978_o = n1826_o & cen;
  /* T80.vhd:1212:33  */
  assign n1979_o = n1826_o & cen;
  /* T80.vhd:1212:33  */
  assign n1980_o = cen ? n1794_o : no_btr;
  /* T80.vhd:1212:33  */
  assign n1981_o = cen ? n1771_o : auto_wait_t1;
  /* T80.vhd:1212:33  */
  assign n1982_o = cen ? n1773_o : auto_wait_t2;
  /* T80.vhd:1212:33  */
  assign n1983_o = n1826_o & cen;
  /* T80.vhd:1212:33  */
  assign n1984_o = n1826_o & cen;
  /* T80.vhd:1203:25  */
  assign n1985_o = dirset ? n2113_q : n1970_o;
  /* T80.vhd:1203:25  */
  assign n1986_o = dirset ? tstate : n1956_o;
  /* T80.vhd:1203:25  */
  assign n1987_o = dirset ? mcycle : n1957_o;
  /* T80.vhd:1203:25  */
  assign n1988_o = dirset ? n1763_o : n1973_o;
  /* T80.vhd:1203:25  */
  assign n1989_o = dirset ? n1762_o : n1974_o;
  /* T80.vhd:1203:25  */
  assign n1990_o = dirset ? halt_ff : n1975_o;
  /* T80.vhd:1203:25  */
  assign n1991_o = dirset ? busreq_s : n1976_o;
  /* T80.vhd:1203:25  */
  assign n1992_o = dirset ? busack : n1961_o;
  /* T80.vhd:1203:25  */
  assign n1993_o = dirset ? nmi_s : n1962_o;
  /* T80.vhd:1203:25  */
  assign n1994_o = dirset ? pre_xy_f_m : n1963_o;
  /* T80.vhd:1203:25  */
  assign n1995_o = dirset ? no_btr : n1980_o;
  /* T80.vhd:1203:25  */
  assign n1996_o = dirset ? auto_wait_t1 : n1981_o;
  /* T80.vhd:1203:25  */
  assign n1997_o = dirset ? auto_wait_t2 : n1982_o;
  /* T80.vhd:1203:25  */
  assign n1998_o = dirset ? intcycle : n1964_o;
  /* T80.vhd:1203:25  */
  assign n1999_o = dirset ? nmicycle : n1965_o;
  /* T80.vhd:1203:25  */
  assign n2000_o = dirset ? n1757_oldnmi_n : nmi_n;
  /* T80.vhd:1182:9  */
  assign n2049_o = ~n1760_o;
  /* T80.vhd:1201:17  */
  assign n2050_o = n2049_o ? n2000_o : n1757_oldnmi_n;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n)
    n2051_q <= n2050_o;
  /* T80.vhd:1301:57  */
  assign n2054_o = mcycle == 3'b001;
  /* T80.vhd:1301:46  */
  assign n2055_o = n2054_o & intcycle;
  /* T80.vhd:1301:26  */
  assign n2056_o = n2055_o ? 1'b1 : 1'b0;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2058_q <= 8'b11111111;
    else
      n2058_q <= n1242_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2059_q <= 8'b11111111;
    else
      n2059_q <= n1243_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2060_q <= 8'b11111111;
    else
      n2060_q <= n1244_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2061_q <= 8'b11111111;
    else
      n2061_q <= n1245_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2062_q <= 8'b00000000;
    else
      n2062_q <= n1246_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2063_q <= 8'b00000000;
    else
      n2063_q <= n1247_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2064_q <= 16'b1111111111111111;
    else
      n2064_q <= n1248_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2065_q <= 16'b0000000000000000;
    else
      n2065_q <= n1249_o;
  /* T80.vhd:499:17  */
  assign n2066_o = {u_regs_n1609, u_regs_n1610};
  /* T80.vhd:499:17  */
  assign n2067_o = {u_regs_n1611, u_regs_n1612};
  /* T80.vhd:499:17  */
  assign n2068_o = {u_regs_n1613, u_regs_n1614};
  /* T80.vhd:944:17  */
  assign n2069_o = clken ? n1373_o : regaddra_r;
  /* T80.vhd:944:17  */
  always @(posedge clk_n)
    n2070_q <= n2069_o;
  /* T80.vhd:944:17  */
  assign n2071_o = clken ? n1387_o : regaddrb_r;
  /* T80.vhd:944:17  */
  always @(posedge clk_n)
    n2072_q <= n2071_o;
  /* T80.vhd:944:17  */
  assign n2073_o = clken ? n1404_o : regaddrc;
  /* T80.vhd:944:17  */
  always @(posedge clk_n)
    n2074_q <= n2073_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2075_q <= 1'b0;
    else
      n2075_q <= n1250_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2076_q <= 16'b0000000000000000;
    else
      n2076_q <= n1251_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2077_q <= 8'b00000000;
    else
      n2077_q <= n1252_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2078_q <= 2'b00;
    else
      n2078_q <= n1253_o;
  /* T80.vhd:944:17  */
  assign n2079_o = clken ? regbusa : regbusa_r;
  /* T80.vhd:944:17  */
  always @(posedge clk_n)
    n2080_q <= n2079_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2081_q <= 3'b000;
    else
      n2081_q <= n1986_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2082_q <= 3'b001;
    else
      n2082_q <= n1987_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2083_q <= 1'b0;
    else
      n2083_q <= n1988_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2084_q <= 1'b0;
    else
      n2084_q <= n1989_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2085_q <= 1'b0;
    else
      n2085_q <= n1990_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2086_q <= 1'b0;
    else
      n2086_q <= n1991_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2087_q <= 1'b0;
    else
      n2087_q <= n1992_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2088_q <= 1'b0;
    else
      n2088_q <= n1993_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2089_q <= 2'b00;
    else
      n2089_q <= n1254_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2090_q <= 2'b00;
    else
      n2090_q <= n1255_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2091_q <= 3'b000;
    else
      n2091_q <= n1994_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2092_q <= 1'b0;
    else
      n2092_q <= n1256_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2093_q <= 1'b0;
    else
      n2093_q <= n1995_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2094_q <= 1'b0;
    else
      n2094_q <= n1257_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2095_q <= 1'b0;
    else
      n2095_q <= n1996_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2096_q <= 1'b0;
    else
      n2096_q <= n1997_o;
  /* T80.vhd:944:17  */
  assign n2097_o = n1428_o ? n1422_o : incdecz;
  /* T80.vhd:944:17  */
  always @(posedge clk_n)
    n2098_q <= n2097_o;
  /* T80.vhd:1084:17  */
  assign n2099_o = clken ? n1724_o : busb;
  /* T80.vhd:1084:17  */
  always @(posedge clk_n)
    n2100_q <= n2099_o;
  /* T80.vhd:1084:17  */
  assign n2101_o = clken ? n1725_o : busa;
  /* T80.vhd:1084:17  */
  always @(posedge clk_n)
    n2102_q <= n2101_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2103_q <= 5'b00000;
    else
      n2103_q <= n1258_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2104_q <= 1'b0;
    else
      n2104_q <= n1259_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2105_q <= 1'b0;
    else
      n2105_q <= n1260_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2106_q <= 4'b0000;
    else
      n2106_q <= n1261_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2107_q <= 1'b0;
    else
      n2107_q <= n1262_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2108_q <= 1'b0;
    else
      n2108_q <= n1263_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2109_q <= 3'b000;
    else
      n2109_q <= n1264_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2110_q <= 1'b0;
    else
      n2110_q <= n1998_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2111_q <= 1'b0;
    else
      n2111_q <= n1999_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2112_q <= 1'b0;
    else
      n2112_q <= n1265_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1760_o)
    if (n1760_o)
      n2113_q <= 1'b1;
    else
      n2113_q <= n1985_o;
  /* T80.vhd:1156:17  */
  assign n2114_o = n1736_o ? n1748_o : n2115_q;
  /* T80.vhd:1156:17  */
  always @(posedge clk_n or posedge n1733_o)
    if (n1733_o)
      n2115_q <= 1'b1;
    else
      n2115_q <= n2114_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2116_q <= 16'b0000000000000000;
    else
      n2116_q <= n1240_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2117_q <= 8'b00000000;
    else
      n2117_q <= n1241_o;
endmodule

module T8080s
  (input  RESET_n,
   input  CLK,
   input  CEN,
   input  WAIT_n,
   input  INT_n,
   input  NMI_n,
   input  BUSRQ_n,
   input  OUT0,
   input  [7:0] DI,
   output M1_n,
   output MREQ_n,
   output IORQ_n,
   output RD_n,
   output WR_n,
   output RFSH_n,
   output HALT_n,
   output BUSAK_n,
   output [15:0] A,
   output [7:0] DOUT);
  wire intcycle_n;
  wire noread;
  wire write;
  wire iorq;
  wire [7:0] di_reg;
  wire [2:0] mcycle;
  wire [2:0] tstate;
  wire u0_n10;
  wire u0_n11;
  wire u0_n12;
  wire u0_n13;
  wire u0_n14;
  wire u0_n15;
  wire u0_n16;
  wire [15:0] u0_n17;
  wire [7:0] u0_n18;
  wire [2:0] u0_n19;
  wire [2:0] u0_n20;
  wire u0_n21;
  localparam n25_o = 1'b0;
  localparam [211:0] n26_o = 212'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  wire u0_m1_n;
  wire u0_iorq;
  wire u0_noread;
  wire u0_write;
  wire u0_rfsh_n;
  wire u0_halt_n;
  wire u0_busak_n;
  wire [15:0] u0_a;
  wire [7:0] u0_dout;
  wire [2:0] u0_mc;
  wire [2:0] u0_ts;
  wire u0_intcycle_n;
  wire u0_inte;
  wire u0_stop;
  wire [211:0] u0_regs;
  wire n56_o;
  wire n59_o;
  wire n61_o;
  wire n63_o;
  wire n64_o;
  wire n65_o;
  wire n66_o;
  wire n67_o;
  wire n68_o;
  wire n70_o;
  wire n72_o;
  wire n74_o;
  wire n76_o;
  wire n78_o;
  wire n80_o;
  wire n82_o;
  wire n83_o;
  wire n84_o;
  wire n85_o;
  wire n86_o;
  wire n87_o;
  wire n88_o;
  wire n89_o;
  wire n90_o;
  wire n92_o;
  wire n94_o;
  wire n97_o;
  wire n99_o;
  wire n101_o;
  wire n102_o;
  wire n103_o;
  wire n104_o;
  wire n105_o;
  wire n106_o;
  wire n107_o;
  wire n108_o;
  wire n111_o;
  wire n112_o;
  wire n114_o;
  wire n116_o;
  wire n119_o;
  wire n122_o;
  wire n123_o;
  wire n129_o;
  wire [7:0] n146_o;
  reg [7:0] n147_q;
  wire n148_o;
  reg n149_q;
  wire n150_o;
  reg n151_q;
  wire n152_o;
  reg n153_q;
  wire n154_o;
  reg n155_q;
  assign M1_n = u0_n10;
  assign MREQ_n = n149_q;
  assign IORQ_n = n151_q;
  assign RD_n = n153_q;
  assign WR_n = n155_q;
  assign RFSH_n = u0_n14;
  assign HALT_n = u0_n15;
  assign BUSAK_n = u0_n16;
  assign A = u0_n17;
  assign DOUT = u0_n18;
  /* T80s.vhd:148:16  */
  assign intcycle_n = u0_n21; // (signal)
  /* T80s.vhd:149:16  */
  assign noread = u0_n12; // (signal)
  /* T80s.vhd:150:16  */
  assign write = u0_n13; // (signal)
  /* T80s.vhd:151:16  */
  assign iorq = u0_n11; // (signal)
  /* T80s.vhd:152:16  */
  assign di_reg = n147_q; // (signal)
  /* T80s.vhd:153:16  */
  assign mcycle = u0_n19; // (signal)
  /* T80s.vhd:154:16  */
  assign tstate = u0_n20; // (signal)
  /* T80s.vhd:164:25  */
  assign u0_n10 = u0_m1_n; // (signal)
  /* T80s.vhd:165:25  */
  assign u0_n11 = u0_iorq; // (signal)
  /* T80s.vhd:166:27  */
  assign u0_n12 = u0_noread; // (signal)
  /* T80s.vhd:167:26  */
  assign u0_n13 = u0_write; // (signal)
  /* T80s.vhd:168:27  */
  assign u0_n14 = u0_rfsh_n; // (signal)
  /* T80s.vhd:169:27  */
  assign u0_n15 = u0_halt_n; // (signal)
  /* T80s.vhd:175:28  */
  assign u0_n16 = u0_busak_n; // (signal)
  /* T80s.vhd:177:22  */
  assign u0_n17 = u0_a; // (signal)
  /* T80s.vhd:180:25  */
  assign u0_n18 = u0_dout; // (signal)
  /* T80s.vhd:181:23  */
  assign u0_n19 = u0_mc; // (signal)
  /* T80s.vhd:182:23  */
  assign u0_n20 = u0_ts; // (signal)
  /* T80s.vhd:184:31  */
  assign u0_n21 = u0_intcycle_n; // (signal)
  /* T80s.vhd:158:9  */
  t8080_cpu u0 (
    .reset_n(RESET_n),
    .clk_n(CLK),
    .cen(CEN),
    .wait_n(WAIT_n),
    .int_n(INT_n),
    .nmi_n(NMI_n),
    .busrq_n(BUSRQ_n),
    .dinst(DI),
    .di(di_reg),
    .out0(OUT0),
    .dirset(n25_o),
    .dir(n26_o),
    .m1_n(u0_m1_n),
    .iorq(u0_iorq),
    .noread(u0_noread),
    .write(u0_write),
    .rfsh_n(u0_rfsh_n),
    .halt_n(u0_halt_n),
    .busak_n(u0_busak_n),
    .a(u0_a),
    .dout(u0_dout),
    .mc(u0_mc),
    .ts(u0_ts),
    .intcycle_n(u0_intcycle_n),
    .inte(),
    .stop(),
    .regs());
  /* T80s.vhd:189:28  */
  assign n56_o = ~RESET_n;
  /* T80s.vhd:201:43  */
  assign n59_o = mcycle == 3'b001;
  /* T80s.vhd:202:51  */
  assign n61_o = tstate == 3'b001;
  /* T80s.vhd:202:66  */
  assign n63_o = tstate == 3'b010;
  /* T80s.vhd:202:81  */
  assign n64_o = ~WAIT_n;
  /* T80s.vhd:202:70  */
  assign n65_o = n64_o & n63_o;
  /* T80s.vhd:202:55  */
  assign n66_o = n61_o | n65_o;
  /* T80s.vhd:203:57  */
  assign n67_o = ~intcycle_n;
  /* T80s.vhd:204:59  */
  assign n68_o = ~intcycle_n;
  /* T80s.vhd:202:41  */
  assign n70_o = n66_o ? n68_o : 1'b1;
  /* T80s.vhd:202:41  */
  assign n72_o = n66_o ? intcycle_n : 1'b1;
  /* T80s.vhd:202:41  */
  assign n74_o = n66_o ? n67_o : 1'b1;
  /* T80s.vhd:207:51  */
  assign n76_o = tstate == 3'b011;
  /* T80s.vhd:207:41  */
  assign n78_o = n76_o ? 1'b0 : n70_o;
  /* T80s.vhd:211:52  */
  assign n80_o = tstate == 3'b001;
  /* T80s.vhd:211:67  */
  assign n82_o = tstate == 3'b010;
  /* T80s.vhd:211:82  */
  assign n83_o = ~WAIT_n;
  /* T80s.vhd:211:71  */
  assign n84_o = n83_o & n82_o;
  /* T80s.vhd:211:56  */
  assign n85_o = n80_o | n84_o;
  /* T80s.vhd:211:101  */
  assign n86_o = ~noread;
  /* T80s.vhd:211:90  */
  assign n87_o = n86_o & n85_o;
  /* T80s.vhd:211:117  */
  assign n88_o = ~write;
  /* T80s.vhd:211:107  */
  assign n89_o = n88_o & n87_o;
  /* T80s.vhd:213:59  */
  assign n90_o = ~iorq;
  /* T80s.vhd:211:41  */
  assign n92_o = n89_o ? iorq : 1'b1;
  /* T80s.vhd:211:41  */
  assign n94_o = n89_o ? n90_o : 1'b1;
  /* T80s.vhd:211:41  */
  assign n97_o = n89_o ? 1'b0 : 1'b1;
  /* T80s.vhd:223:60  */
  assign n99_o = tstate == 3'b001;
  /* T80s.vhd:223:75  */
  assign n101_o = tstate == 3'b010;
  /* T80s.vhd:223:90  */
  assign n102_o = ~WAIT_n;
  /* T80s.vhd:223:79  */
  assign n103_o = n102_o & n101_o;
  /* T80s.vhd:223:64  */
  assign n104_o = n99_o | n103_o;
  /* T80s.vhd:223:98  */
  assign n105_o = write & n104_o;
  /* T80s.vhd:225:67  */
  assign n106_o = ~iorq;
  /* T80s.vhd:223:49  */
  assign n107_o = n105_o ? iorq : n92_o;
  /* T80s.vhd:223:49  */
  assign n108_o = n105_o ? n106_o : n94_o;
  /* T80s.vhd:223:49  */
  assign n111_o = n105_o ? 1'b0 : 1'b1;
  /* T80s.vhd:201:33  */
  assign n112_o = n59_o ? n78_o : n107_o;
  /* T80s.vhd:201:33  */
  assign n114_o = n59_o ? n72_o : n108_o;
  /* T80s.vhd:201:33  */
  assign n116_o = n59_o ? n74_o : n97_o;
  /* T80s.vhd:201:33  */
  assign n119_o = n59_o ? 1'b1 : n111_o;
  /* T80s.vhd:230:43  */
  assign n122_o = tstate == 3'b010;
  /* T80s.vhd:230:47  */
  assign n123_o = WAIT_n & n122_o;
  /* T80s.vhd:196:25  */
  assign n129_o = n123_o & CEN;
  /* T80s.vhd:195:17  */
  assign n146_o = n129_o ? DI : di_reg;
  /* T80s.vhd:195:17  */
  always @(posedge CLK or posedge n56_o)
    if (n56_o)
      n147_q <= 8'b00000000;
    else
      n147_q <= n146_o;
  /* T80s.vhd:195:17  */
  assign n148_o = CEN ? n112_o : n149_q;
  /* T80s.vhd:195:17  */
  always @(posedge CLK or posedge n56_o)
    if (n56_o)
      n149_q <= 1'b1;
    else
      n149_q <= n148_o;
  /* T80s.vhd:195:17  */
  assign n150_o = CEN ? n114_o : n151_q;
  /* T80s.vhd:195:17  */
  always @(posedge CLK or posedge n56_o)
    if (n56_o)
      n151_q <= 1'b1;
    else
      n151_q <= n150_o;
  /* T80s.vhd:195:17  */
  assign n152_o = CEN ? n116_o : n153_q;
  /* T80s.vhd:195:17  */
  always @(posedge CLK or posedge n56_o)
    if (n56_o)
      n153_q <= 1'b1;
    else
      n153_q <= n152_o;
  /* T80s.vhd:195:17  */
  assign n154_o = CEN ? n119_o : n155_q;
  /* T80s.vhd:195:17  */
  always @(posedge CLK or posedge n56_o)
    if (n56_o)
      n155_q <= 1'b1;
    else
      n155_q <= n154_o;
endmodule
