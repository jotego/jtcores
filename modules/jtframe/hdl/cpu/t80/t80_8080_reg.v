// GHDL 4.1.0 output for T80_Reg.vhd from T80s synthesis with -gMode=2.
// Copyright (c) 2018 Sorgelig
//  Test passed: ZEXDOC, ZEXALL, Z80Full(*), Z80memptr
//  (*) Currently only SCF and CCF instructions aren't passed X/Y flags check as
//      correct implementation is still unclear.
//
// ****
// T80(b) core. In an effort to merge and maintain bug fixes ....
//
//
// Ver 300 started tidyup
// MikeJ March 2005
// Latest version from www.fpgaarcade.com (original www.opencores.org)
//
// ****
//
// T80 Registers, technology independent
//
// Version : 0244
//
// Copyright (c) 2002 Daniel Wallner (jesus@opencores.org)
//
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
module t80_8080_reg
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
