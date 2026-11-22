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

// GHDL 4.1.0 datapath. Regeneration is documented in doc/cpus.md.
/* verilator coverage_off */
module t80_reg
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
  wire [7:0] n8697_o;
  wire [7:0] n8698_o;
  wire [7:0] n8699_o;
  wire [7:0] n8700_o;
  wire [7:0] n8701_o;
  wire [7:0] n8702_o;
  wire [7:0] n8703_o;
  wire [7:0] n8704_o;
  wire [7:0] n8705_o;
  wire [7:0] n8706_o;
  wire [7:0] n8707_o;
  wire [7:0] n8708_o;
  wire [7:0] n8709_o;
  wire [7:0] n8710_o;
  wire [7:0] n8711_o;
  wire [7:0] n8712_o;
  wire [2:0] n8715_o;
  wire [63:0] n8718_o;
  wire [2:0] n8721_o;
  wire [63:0] n8724_o;
  wire n8725_o;
  wire n8726_o;
  wire [63:0] n8727_o;
  wire [63:0] n8728_o;
  wire [63:0] n8729_o;
  wire [63:0] n8730_o;
  wire [2:0] n8736_o;
  wire [2:0] n8741_o;
  wire [2:0] n8746_o;
  wire [2:0] n8751_o;
  wire [2:0] n8756_o;
  wire [2:0] n8761_o;
  wire [7:0] n8764_o;
  wire [7:0] n8765_o;
  wire [15:0] n8766_o;
  wire [7:0] n8767_o;
  wire [23:0] n8768_o;
  wire [7:0] n8769_o;
  wire [31:0] n8770_o;
  wire [7:0] n8771_o;
  wire [39:0] n8772_o;
  wire [7:0] n8773_o;
  wire [47:0] n8774_o;
  wire [7:0] n8775_o;
  wire [55:0] n8776_o;
  wire [7:0] n8777_o;
  wire [63:0] n8778_o;
  wire [7:0] n8779_o;
  wire [71:0] n8780_o;
  wire [7:0] n8781_o;
  wire [79:0] n8782_o;
  wire [7:0] n8783_o;
  wire [87:0] n8784_o;
  wire [7:0] n8785_o;
  wire [95:0] n8786_o;
  wire [7:0] n8787_o;
  wire [103:0] n8788_o;
  wire [7:0] n8789_o;
  wire [111:0] n8790_o;
  wire [7:0] n8791_o;
  wire [119:0] n8792_o;
  wire [7:0] n8793_o;
  wire [127:0] n8794_o;
  reg [63:0] n8795_q;
  reg [63:0] n8796_q;
  wire n8797_o;
  wire n8798_o;
  wire n8799_o;
  wire n8800_o;
  wire n8801_o;
  wire n8802_o;
  wire n8803_o;
  wire n8804_o;
  wire n8805_o;
  wire n8806_o;
  wire n8807_o;
  wire n8808_o;
  wire n8809_o;
  wire n8810_o;
  wire n8811_o;
  wire n8812_o;
  wire n8813_o;
  wire n8814_o;
  wire [7:0] n8815_o;
  wire [7:0] n8816_o;
  wire [7:0] n8817_o;
  wire [7:0] n8818_o;
  wire [7:0] n8819_o;
  wire [7:0] n8820_o;
  wire [7:0] n8821_o;
  wire [7:0] n8822_o;
  wire [7:0] n8823_o;
  wire [7:0] n8824_o;
  wire [7:0] n8825_o;
  wire [7:0] n8826_o;
  wire [7:0] n8827_o;
  wire [7:0] n8828_o;
  wire [7:0] n8829_o;
  wire [7:0] n8830_o;
  wire [63:0] n8831_o;
  wire n8832_o;
  wire n8833_o;
  wire n8834_o;
  wire n8835_o;
  wire n8836_o;
  wire n8837_o;
  wire n8838_o;
  wire n8839_o;
  wire n8840_o;
  wire n8841_o;
  wire n8842_o;
  wire n8843_o;
  wire n8844_o;
  wire n8845_o;
  wire n8846_o;
  wire n8847_o;
  wire n8848_o;
  wire n8849_o;
  wire [7:0] n8850_o;
  wire [7:0] n8851_o;
  wire [7:0] n8852_o;
  wire [7:0] n8853_o;
  wire [7:0] n8854_o;
  wire [7:0] n8855_o;
  wire [7:0] n8856_o;
  wire [7:0] n8857_o;
  wire [7:0] n8858_o;
  wire [7:0] n8859_o;
  wire [7:0] n8860_o;
  wire [7:0] n8861_o;
  wire [7:0] n8862_o;
  wire [7:0] n8863_o;
  wire [7:0] n8864_o;
  wire [7:0] n8865_o;
  wire [63:0] n8866_o;
  wire [7:0] n8867_o;
  wire [7:0] n8868_o;
  wire [7:0] n8869_o;
  wire [7:0] n8870_o;
  wire [7:0] n8871_o;
  wire [7:0] n8872_o;
  wire [7:0] n8873_o;
  wire [7:0] n8874_o;
  wire [1:0] n8875_o;
  reg [7:0] n8876_o;
  wire [1:0] n8877_o;
  reg [7:0] n8878_o;
  wire n8879_o;
  wire [7:0] n8880_o;
  wire [7:0] n8881_o;
  wire [7:0] n8882_o;
  wire [7:0] n8883_o;
  wire [7:0] n8884_o;
  wire [7:0] n8885_o;
  wire [7:0] n8886_o;
  wire [7:0] n8887_o;
  wire [7:0] n8888_o;
  wire [1:0] n8889_o;
  reg [7:0] n8890_o;
  wire [1:0] n8891_o;
  reg [7:0] n8892_o;
  wire n8893_o;
  wire [7:0] n8894_o;
  wire [7:0] n8895_o;
  wire [7:0] n8896_o;
  wire [7:0] n8897_o;
  wire [7:0] n8898_o;
  wire [7:0] n8899_o;
  wire [7:0] n8900_o;
  wire [7:0] n8901_o;
  wire [7:0] n8902_o;
  wire [1:0] n8903_o;
  reg [7:0] n8904_o;
  wire [1:0] n8905_o;
  reg [7:0] n8906_o;
  wire n8907_o;
  wire [7:0] n8908_o;
  wire [7:0] n8909_o;
  wire [7:0] n8910_o;
  wire [7:0] n8911_o;
  wire [7:0] n8912_o;
  wire [7:0] n8913_o;
  wire [7:0] n8914_o;
  wire [7:0] n8915_o;
  wire [7:0] n8916_o;
  wire [1:0] n8917_o;
  reg [7:0] n8918_o;
  wire [1:0] n8919_o;
  reg [7:0] n8920_o;
  wire n8921_o;
  wire [7:0] n8922_o;
  wire [7:0] n8923_o;
  wire [7:0] n8924_o;
  wire [7:0] n8925_o;
  wire [7:0] n8926_o;
  wire [7:0] n8927_o;
  wire [7:0] n8928_o;
  wire [7:0] n8929_o;
  wire [7:0] n8930_o;
  wire [1:0] n8931_o;
  reg [7:0] n8932_o;
  wire [1:0] n8933_o;
  reg [7:0] n8934_o;
  wire n8935_o;
  wire [7:0] n8936_o;
  wire [7:0] n8937_o;
  wire [7:0] n8938_o;
  wire [7:0] n8939_o;
  wire [7:0] n8940_o;
  wire [7:0] n8941_o;
  wire [7:0] n8942_o;
  wire [7:0] n8943_o;
  wire [7:0] n8944_o;
  wire [1:0] n8945_o;
  reg [7:0] n8946_o;
  wire [1:0] n8947_o;
  reg [7:0] n8948_o;
  wire n8949_o;
  wire [7:0] n8950_o;
  assign doah = n8880_o;
  assign doal = n8894_o;
  assign dobh = n8908_o;
  assign dobl = n8922_o;
  assign doch = n8936_o;
  assign docl = n8950_o;
  assign dor = n8794_o;
  /* T80_Reg.vhd:101:16  */
  assign regsh = n8795_q; // (signal)
  /* T80_Reg.vhd:102:16  */
  assign regsl = n8796_q; // (signal)
  /* T80_Reg.vhd:110:48  */
  assign n8697_o = dir[7:0];
  /* T80_Reg.vhd:111:48  */
  assign n8698_o = dir[15:8];
  /* T80_Reg.vhd:113:48  */
  assign n8699_o = dir[23:16];
  /* T80_Reg.vhd:114:48  */
  assign n8700_o = dir[31:24];
  /* T80_Reg.vhd:116:48  */
  assign n8701_o = dir[39:32];
  /* T80_Reg.vhd:117:48  */
  assign n8702_o = dir[47:40];
  /* T80_Reg.vhd:119:48  */
  assign n8703_o = dir[55:48];
  /* T80_Reg.vhd:120:48  */
  assign n8704_o = dir[63:56];
  /* T80_Reg.vhd:122:48  */
  assign n8705_o = dir[71:64];
  /* T80_Reg.vhd:123:48  */
  assign n8706_o = dir[79:72];
  /* T80_Reg.vhd:125:48  */
  assign n8707_o = dir[87:80];
  /* T80_Reg.vhd:126:48  */
  assign n8708_o = dir[95:88];
  /* T80_Reg.vhd:128:48  */
  assign n8709_o = dir[103:96];
  /* T80_Reg.vhd:129:48  */
  assign n8710_o = dir[111:104];
  /* T80_Reg.vhd:131:48  */
  assign n8711_o = dir[119:112];
  /* T80_Reg.vhd:132:48  */
  assign n8712_o = dir[127:120];
  /* T80_Reg.vhd:135:47  */
  assign n8715_o = 3'b111 - addra;
  /* T80_Reg.vhd:133:25  */
  assign n8718_o = n8725_o ? n8831_o : regsh;
  /* T80_Reg.vhd:138:47  */
  assign n8721_o = 3'b111 - addra;
  /* T80_Reg.vhd:133:25  */
  assign n8724_o = n8726_o ? n8866_o : regsl;
  /* T80_Reg.vhd:133:25  */
  assign n8725_o = weh & cen;
  /* T80_Reg.vhd:133:25  */
  assign n8726_o = wel & cen;
  assign n8727_o = {n8698_o, n8700_o, n8702_o, n8704_o, n8706_o, n8708_o, n8710_o, n8712_o};
  /* T80_Reg.vhd:109:25  */
  assign n8728_o = dirset ? n8727_o : n8718_o;
  /* T80_ALU.vhd:113:26  */
  assign n8729_o = {n8697_o, n8699_o, n8701_o, n8703_o, n8705_o, n8707_o, n8709_o, n8711_o};
  /* T80_Reg.vhd:109:25  */
  assign n8730_o = dirset ? n8729_o : n8724_o;
  /* T80_Reg.vhd:144:23  */
  assign n8736_o = 3'b111 - addra;
  /* T80_Reg.vhd:145:23  */
  assign n8741_o = 3'b111 - addra;
  /* T80_Reg.vhd:146:23  */
  assign n8746_o = 3'b111 - addrb;
  /* T80_Reg.vhd:147:23  */
  assign n8751_o = 3'b111 - addrb;
  /* T80_Reg.vhd:148:23  */
  assign n8756_o = 3'b111 - addrc;
  /* T80_Reg.vhd:149:23  */
  assign n8761_o = 3'b111 - addrc;
  /* T80_Reg.vhd:150:22  */
  assign n8764_o = regsh[7:0];
  /* T80_Reg.vhd:150:33  */
  assign n8765_o = regsl[7:0];
  /* T80_Reg.vhd:150:26  */
  assign n8766_o = {n8764_o, n8765_o};
  /* T80_Reg.vhd:150:44  */
  assign n8767_o = regsh[15:8];
  /* T80_Reg.vhd:150:37  */
  assign n8768_o = {n8766_o, n8767_o};
  /* T80_Reg.vhd:150:55  */
  assign n8769_o = regsl[15:8];
  /* T80_Reg.vhd:150:48  */
  assign n8770_o = {n8768_o, n8769_o};
  /* T80_Reg.vhd:150:66  */
  assign n8771_o = regsh[23:16];
  /* T80_Reg.vhd:150:59  */
  assign n8772_o = {n8770_o, n8771_o};
  /* T80_Reg.vhd:150:77  */
  assign n8773_o = regsl[23:16];
  /* T80_Reg.vhd:150:70  */
  assign n8774_o = {n8772_o, n8773_o};
  /* T80_Reg.vhd:150:88  */
  assign n8775_o = regsh[31:24];
  /* T80_Reg.vhd:150:81  */
  assign n8776_o = {n8774_o, n8775_o};
  /* T80_Reg.vhd:150:99  */
  assign n8777_o = regsl[31:24];
  /* T80_Reg.vhd:150:92  */
  assign n8778_o = {n8776_o, n8777_o};
  /* T80_Reg.vhd:150:110  */
  assign n8779_o = regsh[39:32];
  /* T80_Reg.vhd:150:103  */
  assign n8780_o = {n8778_o, n8779_o};
  /* T80_Reg.vhd:150:121  */
  assign n8781_o = regsl[39:32];
  /* T80_Reg.vhd:150:114  */
  assign n8782_o = {n8780_o, n8781_o};
  /* T80_Reg.vhd:150:132  */
  assign n8783_o = regsh[47:40];
  /* T80_Reg.vhd:150:125  */
  assign n8784_o = {n8782_o, n8783_o};
  /* T80_Reg.vhd:150:143  */
  assign n8785_o = regsl[47:40];
  /* T80_Reg.vhd:150:136  */
  assign n8786_o = {n8784_o, n8785_o};
  /* T80_Reg.vhd:150:154  */
  assign n8787_o = regsh[55:48];
  /* T80_Reg.vhd:150:147  */
  assign n8788_o = {n8786_o, n8787_o};
  /* T80_Reg.vhd:150:165  */
  assign n8789_o = regsl[55:48];
  /* T80_Reg.vhd:150:158  */
  assign n8790_o = {n8788_o, n8789_o};
  /* T80_Reg.vhd:150:176  */
  assign n8791_o = regsh[63:56];
  /* T80_Reg.vhd:150:169  */
  assign n8792_o = {n8790_o, n8791_o};
  /* T80_Reg.vhd:150:187  */
  assign n8793_o = regsl[63:56];
  /* T80_Reg.vhd:150:180  */
  assign n8794_o = {n8792_o, n8793_o};
  /* T80_Reg.vhd:108:17  */
  always @(posedge clk)
    n8795_q <= n8728_o;
  /* T80_Reg.vhd:108:17  */
  always @(posedge clk)
    n8796_q <= n8730_o;
  /* T80_Reg.vhd:135:41  */
  assign n8797_o = n8715_o[2];
  /* T80_Reg.vhd:135:41  */
  assign n8798_o = ~n8797_o;
  /* T80_Reg.vhd:135:41  */
  assign n8799_o = n8715_o[1];
  /* T80_Reg.vhd:135:41  */
  assign n8800_o = ~n8799_o;
  /* T80_Reg.vhd:135:41  */
  assign n8801_o = n8798_o & n8800_o;
  /* T80_Reg.vhd:135:41  */
  assign n8802_o = n8798_o & n8799_o;
  /* T80_Reg.vhd:135:41  */
  assign n8803_o = n8797_o & n8800_o;
  /* T80_Reg.vhd:135:41  */
  assign n8804_o = n8797_o & n8799_o;
  /* T80_Reg.vhd:135:41  */
  assign n8805_o = n8715_o[0];
  /* T80_Reg.vhd:135:41  */
  assign n8806_o = ~n8805_o;
  /* T80_Reg.vhd:135:41  */
  assign n8807_o = n8801_o & n8806_o;
  /* T80_Reg.vhd:135:41  */
  assign n8808_o = n8801_o & n8805_o;
  /* T80_Reg.vhd:135:41  */
  assign n8809_o = n8802_o & n8806_o;
  /* T80_Reg.vhd:135:41  */
  assign n8810_o = n8802_o & n8805_o;
  /* T80_Reg.vhd:135:41  */
  assign n8811_o = n8803_o & n8806_o;
  /* T80_Reg.vhd:135:41  */
  assign n8812_o = n8803_o & n8805_o;
  /* T80_Reg.vhd:135:41  */
  assign n8813_o = n8804_o & n8806_o;
  /* T80_Reg.vhd:135:41  */
  assign n8814_o = n8804_o & n8805_o;
  assign n8815_o = regsh[7:0];
  /* T80_Reg.vhd:135:41  */
  assign n8816_o = n8807_o ? dih : n8815_o;
  assign n8817_o = regsh[15:8];
  /* T80_Reg.vhd:135:41  */
  assign n8818_o = n8808_o ? dih : n8817_o;
  assign n8819_o = regsh[23:16];
  /* T80_Reg.vhd:135:41  */
  assign n8820_o = n8809_o ? dih : n8819_o;
  assign n8821_o = regsh[31:24];
  /* T80_Reg.vhd:135:41  */
  assign n8822_o = n8810_o ? dih : n8821_o;
  assign n8823_o = regsh[39:32];
  /* T80_Reg.vhd:135:41  */
  assign n8824_o = n8811_o ? dih : n8823_o;
  assign n8825_o = regsh[47:40];
  /* T80_Reg.vhd:135:41  */
  assign n8826_o = n8812_o ? dih : n8825_o;
  assign n8827_o = regsh[55:48];
  /* T80_Reg.vhd:135:41  */
  assign n8828_o = n8813_o ? dih : n8827_o;
  assign n8829_o = regsh[63:56];
  /* T80_Reg.vhd:135:41  */
  assign n8830_o = n8814_o ? dih : n8829_o;
  assign n8831_o = {n8830_o, n8828_o, n8826_o, n8824_o, n8822_o, n8820_o, n8818_o, n8816_o};
  /* T80_Reg.vhd:138:41  */
  assign n8832_o = n8721_o[2];
  /* T80_Reg.vhd:138:41  */
  assign n8833_o = ~n8832_o;
  /* T80_Reg.vhd:138:41  */
  assign n8834_o = n8721_o[1];
  /* T80_Reg.vhd:138:41  */
  assign n8835_o = ~n8834_o;
  /* T80_Reg.vhd:138:41  */
  assign n8836_o = n8833_o & n8835_o;
  /* T80_Reg.vhd:138:41  */
  assign n8837_o = n8833_o & n8834_o;
  /* T80_Reg.vhd:138:41  */
  assign n8838_o = n8832_o & n8835_o;
  /* T80_Reg.vhd:138:41  */
  assign n8839_o = n8832_o & n8834_o;
  /* T80_Reg.vhd:138:41  */
  assign n8840_o = n8721_o[0];
  /* T80_Reg.vhd:138:41  */
  assign n8841_o = ~n8840_o;
  /* T80_Reg.vhd:138:41  */
  assign n8842_o = n8836_o & n8841_o;
  /* T80_Reg.vhd:138:41  */
  assign n8843_o = n8836_o & n8840_o;
  /* T80_Reg.vhd:138:41  */
  assign n8844_o = n8837_o & n8841_o;
  /* T80_Reg.vhd:138:41  */
  assign n8845_o = n8837_o & n8840_o;
  /* T80_Reg.vhd:138:41  */
  assign n8846_o = n8838_o & n8841_o;
  /* T80_Reg.vhd:138:41  */
  assign n8847_o = n8838_o & n8840_o;
  /* T80_Reg.vhd:138:41  */
  assign n8848_o = n8839_o & n8841_o;
  /* T80_Reg.vhd:138:41  */
  assign n8849_o = n8839_o & n8840_o;
  assign n8850_o = regsl[7:0];
  /* T80_Reg.vhd:138:41  */
  assign n8851_o = n8842_o ? dil : n8850_o;
  assign n8852_o = regsl[15:8];
  /* T80_Reg.vhd:138:41  */
  assign n8853_o = n8843_o ? dil : n8852_o;
  assign n8854_o = regsl[23:16];
  /* T80_Reg.vhd:138:41  */
  assign n8855_o = n8844_o ? dil : n8854_o;
  assign n8856_o = regsl[31:24];
  /* T80_Reg.vhd:138:41  */
  assign n8857_o = n8845_o ? dil : n8856_o;
  assign n8858_o = regsl[39:32];
  /* T80_Reg.vhd:138:41  */
  assign n8859_o = n8846_o ? dil : n8858_o;
  assign n8860_o = regsl[47:40];
  /* T80_Reg.vhd:138:41  */
  assign n8861_o = n8847_o ? dil : n8860_o;
  assign n8862_o = regsl[55:48];
  /* T80_Reg.vhd:138:41  */
  assign n8863_o = n8848_o ? dil : n8862_o;
  assign n8864_o = regsl[63:56];
  /* T80_Reg.vhd:138:41  */
  assign n8865_o = n8849_o ? dil : n8864_o;
  assign n8866_o = {n8865_o, n8863_o, n8861_o, n8859_o, n8857_o, n8855_o, n8853_o, n8851_o};
  /* T80_Reg.vhd:138:47  */
  assign n8867_o = regsh[7:0];
  /* T80_Reg.vhd:138:41  */
  assign n8868_o = regsh[15:8];
  assign n8869_o = regsh[23:16];
  assign n8870_o = regsh[31:24];
  assign n8871_o = regsh[39:32];
  assign n8872_o = regsh[47:40];
  assign n8873_o = regsh[55:48];
  assign n8874_o = regsh[63:56];
  /* T80_Reg.vhd:144:22  */
  assign n8875_o = n8736_o[1:0];
  /* T80_Reg.vhd:144:22  */
  always @*
    case (n8875_o)
      2'b00: n8876_o = n8867_o;
      2'b01: n8876_o = n8868_o;
      2'b10: n8876_o = n8869_o;
      2'b11: n8876_o = n8870_o;
    endcase
  /* T80_Reg.vhd:144:22  */
  assign n8877_o = n8736_o[1:0];
  /* T80_Reg.vhd:144:22  */
  always @*
    case (n8877_o)
      2'b00: n8878_o = n8871_o;
      2'b01: n8878_o = n8872_o;
      2'b10: n8878_o = n8873_o;
      2'b11: n8878_o = n8874_o;
    endcase
  /* T80_Reg.vhd:144:22  */
  assign n8879_o = n8736_o[2];
  /* T80_Reg.vhd:144:22  */
  assign n8880_o = n8879_o ? n8878_o : n8876_o;
  /* T80_Reg.vhd:144:22  */
  assign n8881_o = regsl[7:0];
  /* T80_Reg.vhd:144:23  */
  assign n8882_o = regsl[15:8];
  assign n8883_o = regsl[23:16];
  assign n8884_o = regsl[31:24];
  assign n8885_o = regsl[39:32];
  assign n8886_o = regsl[47:40];
  assign n8887_o = regsl[55:48];
  assign n8888_o = regsl[63:56];
  /* T80_Reg.vhd:145:22  */
  assign n8889_o = n8741_o[1:0];
  /* T80_Reg.vhd:145:22  */
  always @*
    case (n8889_o)
      2'b00: n8890_o = n8881_o;
      2'b01: n8890_o = n8882_o;
      2'b10: n8890_o = n8883_o;
      2'b11: n8890_o = n8884_o;
    endcase
  /* T80_Reg.vhd:145:22  */
  assign n8891_o = n8741_o[1:0];
  /* T80_Reg.vhd:145:22  */
  always @*
    case (n8891_o)
      2'b00: n8892_o = n8885_o;
      2'b01: n8892_o = n8886_o;
      2'b10: n8892_o = n8887_o;
      2'b11: n8892_o = n8888_o;
    endcase
  /* T80_Reg.vhd:145:22  */
  assign n8893_o = n8741_o[2];
  /* T80_Reg.vhd:145:22  */
  assign n8894_o = n8893_o ? n8892_o : n8890_o;
  /* T80_Reg.vhd:145:22  */
  assign n8895_o = regsh[7:0];
  /* T80_Reg.vhd:145:23  */
  assign n8896_o = regsh[15:8];
  assign n8897_o = regsh[23:16];
  assign n8898_o = regsh[31:24];
  assign n8899_o = regsh[39:32];
  assign n8900_o = regsh[47:40];
  assign n8901_o = regsh[55:48];
  assign n8902_o = regsh[63:56];
  /* T80_Reg.vhd:146:22  */
  assign n8903_o = n8746_o[1:0];
  /* T80_Reg.vhd:146:22  */
  always @*
    case (n8903_o)
      2'b00: n8904_o = n8895_o;
      2'b01: n8904_o = n8896_o;
      2'b10: n8904_o = n8897_o;
      2'b11: n8904_o = n8898_o;
    endcase
  /* T80_Reg.vhd:146:22  */
  assign n8905_o = n8746_o[1:0];
  /* T80_Reg.vhd:146:22  */
  always @*
    case (n8905_o)
      2'b00: n8906_o = n8899_o;
      2'b01: n8906_o = n8900_o;
      2'b10: n8906_o = n8901_o;
      2'b11: n8906_o = n8902_o;
    endcase
  /* T80_Reg.vhd:146:22  */
  assign n8907_o = n8746_o[2];
  /* T80_Reg.vhd:146:22  */
  assign n8908_o = n8907_o ? n8906_o : n8904_o;
  /* T80_Reg.vhd:146:22  */
  assign n8909_o = regsl[7:0];
  /* T80_Reg.vhd:146:23  */
  assign n8910_o = regsl[15:8];
  assign n8911_o = regsl[23:16];
  assign n8912_o = regsl[31:24];
  assign n8913_o = regsl[39:32];
  assign n8914_o = regsl[47:40];
  assign n8915_o = regsl[55:48];
  assign n8916_o = regsl[63:56];
  /* T80_Reg.vhd:147:22  */
  assign n8917_o = n8751_o[1:0];
  /* T80_Reg.vhd:147:22  */
  always @*
    case (n8917_o)
      2'b00: n8918_o = n8909_o;
      2'b01: n8918_o = n8910_o;
      2'b10: n8918_o = n8911_o;
      2'b11: n8918_o = n8912_o;
    endcase
  /* T80_Reg.vhd:147:22  */
  assign n8919_o = n8751_o[1:0];
  /* T80_Reg.vhd:147:22  */
  always @*
    case (n8919_o)
      2'b00: n8920_o = n8913_o;
      2'b01: n8920_o = n8914_o;
      2'b10: n8920_o = n8915_o;
      2'b11: n8920_o = n8916_o;
    endcase
  /* T80_Reg.vhd:147:22  */
  assign n8921_o = n8751_o[2];
  /* T80_Reg.vhd:147:22  */
  assign n8922_o = n8921_o ? n8920_o : n8918_o;
  /* T80_Reg.vhd:147:22  */
  assign n8923_o = regsh[7:0];
  /* T80_Reg.vhd:147:23  */
  assign n8924_o = regsh[15:8];
  assign n8925_o = regsh[23:16];
  assign n8926_o = regsh[31:24];
  assign n8927_o = regsh[39:32];
  assign n8928_o = regsh[47:40];
  assign n8929_o = regsh[55:48];
  assign n8930_o = regsh[63:56];
  /* T80_Reg.vhd:148:22  */
  assign n8931_o = n8756_o[1:0];
  /* T80_Reg.vhd:148:22  */
  always @*
    case (n8931_o)
      2'b00: n8932_o = n8923_o;
      2'b01: n8932_o = n8924_o;
      2'b10: n8932_o = n8925_o;
      2'b11: n8932_o = n8926_o;
    endcase
  /* T80_Reg.vhd:148:22  */
  assign n8933_o = n8756_o[1:0];
  /* T80_Reg.vhd:148:22  */
  always @*
    case (n8933_o)
      2'b00: n8934_o = n8927_o;
      2'b01: n8934_o = n8928_o;
      2'b10: n8934_o = n8929_o;
      2'b11: n8934_o = n8930_o;
    endcase
  /* T80_Reg.vhd:148:22  */
  assign n8935_o = n8756_o[2];
  /* T80_Reg.vhd:148:22  */
  assign n8936_o = n8935_o ? n8934_o : n8932_o;
  /* T80_Reg.vhd:148:22  */
  assign n8937_o = regsl[7:0];
  /* T80_Reg.vhd:148:23  */
  assign n8938_o = regsl[15:8];
  assign n8939_o = regsl[23:16];
  assign n8940_o = regsl[31:24];
  assign n8941_o = regsl[39:32];
  assign n8942_o = regsl[47:40];
  assign n8943_o = regsl[55:48];
  assign n8944_o = regsl[63:56];
  /* T80_Reg.vhd:149:22  */
  assign n8945_o = n8761_o[1:0];
  /* T80_Reg.vhd:149:22  */
  always @*
    case (n8945_o)
      2'b00: n8946_o = n8937_o;
      2'b01: n8946_o = n8938_o;
      2'b10: n8946_o = n8939_o;
      2'b11: n8946_o = n8940_o;
    endcase
  /* T80_Reg.vhd:149:22  */
  assign n8947_o = n8761_o[1:0];
  /* T80_Reg.vhd:149:22  */
  always @*
    case (n8947_o)
      2'b00: n8948_o = n8941_o;
      2'b01: n8948_o = n8942_o;
      2'b10: n8948_o = n8943_o;
      2'b11: n8948_o = n8944_o;
    endcase
  /* T80_Reg.vhd:149:22  */
  assign n8949_o = n8761_o[2];
  /* T80_Reg.vhd:149:22  */
  assign n8950_o = n8949_o ? n8948_o : n8946_o;
endmodule

module t80_alu_0_0_1_2_3_4_5_6_7
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
   input  [1:0] mode_sel,
   output [7:0] q,
   output [7:0] f_out);
  wire usecarry;
  wire carry7_v;
  wire overflow_v;
  wire halfcarry_v;
  wire carry_v;
  wire [7:0] q_v;
  wire [7:0] bitmask;
  wire [2:0] n8078_o;
  wire n8081_o;
  wire n8084_o;
  wire n8087_o;
  wire n8090_o;
  wire n8093_o;
  wire n8096_o;
  wire n8099_o;
  wire [6:0] n8101_o;
  reg [7:0] n8102_o;
  wire n8103_o;
  wire n8104_o;
  wire n8105_o;
  wire n8106_o;
  wire [3:0] n8108_o;
  wire [3:0] n8109_o;
  wire n8110_o;
  wire n8111_o;
  wire n8112_o;
  wire n8113_o;
  wire n8114_o;
  wire [3:0] n8119_o;
  wire [3:0] n8120_o;
  wire [4:0] n8123_o;
  wire [5:0] n8124_o;
  wire [4:0] n8126_o;
  wire [5:0] n8128_o;
  wire [5:0] n8129_o;
  wire n8131_o;
  wire [3:0] n8132_o;
  wire [2:0] n8134_o;
  wire [2:0] n8135_o;
  wire n8136_o;
  wire [2:0] n8141_o;
  wire [2:0] n8142_o;
  wire [3:0] n8145_o;
  wire [4:0] n8146_o;
  wire [3:0] n8148_o;
  wire [4:0] n8150_o;
  wire [4:0] n8151_o;
  wire n8153_o;
  wire [2:0] n8154_o;
  wire n8156_o;
  wire n8157_o;
  wire n8158_o;
  wire n8163_o;
  wire n8164_o;
  wire [1:0] n8167_o;
  wire [2:0] n8168_o;
  wire [1:0] n8170_o;
  wire [2:0] n8172_o;
  wire [2:0] n8173_o;
  wire n8175_o;
  wire n8176_o;
  wire [31:0] n8179_o;
  wire n8181_o;
  wire n8182_o;
  wire n8183_o;
  wire n8184_o;
  wire n8185_o;
  wire n8186_o;
  wire n8187_o;
  wire n8188_o;
  wire n8189_o;
  wire n8190_o;
  wire n8191_o;
  wire n8192_o;
  wire n8193_o;
  wire n8194_o;
  wire n8195_o;
  wire n8196_o;
  wire n8197_o;
  wire n8198_o;
  wire n8199_o;
  wire [2:0] n8207_o;
  wire n8209_o;
  wire n8211_o;
  wire n8212_o;
  wire n8214_o;
  wire n8215_o;
  wire n8217_o;
  wire n8219_o;
  wire n8220_o;
  wire n8222_o;
  wire n8223_o;
  wire [7:0] n8224_o;
  wire n8227_o;
  wire [7:0] n8228_o;
  wire n8231_o;
  wire [7:0] n8232_o;
  wire [3:0] n8234_o;
  reg n8235_o;
  reg n8236_o;
  wire n8237_o;
  reg n8238_o;
  reg n8239_o;
  reg [7:0] n8240_o;
  wire [2:0] n8241_o;
  wire n8243_o;
  wire n8244_o;
  wire n8245_o;
  wire n8246_o;
  wire n8247_o;
  wire n8248_o;
  wire n8249_o;
  wire n8251_o;
  wire n8253_o;
  wire n8254_o;
  wire n8256_o;
  wire n8257_o;
  wire [2:0] n8258_o;
  wire n8260_o;
  wire n8262_o;
  wire n8263_o;
  wire n8265_o;
  wire n8266_o;
  wire n8268_o;
  wire n8269_o;
  wire n8271_o;
  wire n8272_o;
  wire n8273_o;
  wire n8274_o;
  wire n8275_o;
  wire n8276_o;
  wire n8277_o;
  wire n8278_o;
  wire n8279_o;
  wire n8280_o;
  wire n8281_o;
  wire n8282_o;
  wire n8283_o;
  wire n8284_o;
  wire n8285_o;
  wire n8286_o;
  wire n8287_o;
  wire n8288_o;
  reg n8289_o;
  wire n8290_o;
  wire n8291_o;
  wire n8292_o;
  wire [1:0] n8293_o;
  wire n8294_o;
  wire [1:0] n8295_o;
  wire [1:0] n8296_o;
  wire n8298_o;
  wire n8300_o;
  wire n8301_o;
  wire n8303_o;
  wire n8304_o;
  wire n8306_o;
  wire n8307_o;
  wire n8309_o;
  wire n8310_o;
  wire n8312_o;
  wire n8313_o;
  wire n8315_o;
  wire n8316_o;
  wire n8318_o;
  wire n8319_o;
  wire n8320_o;
  wire n8323_o;
  wire n8324_o;
  wire [8:0] n8325_o;
  wire [3:0] n8326_o;
  wire n8328_o;
  wire n8329_o;
  wire n8330_o;
  wire [8:0] n8331_o;
  wire [3:0] n8332_o;
  wire n8334_o;
  wire n8337_o;
  wire [8:0] n8338_o;
  wire [8:0] n8340_o;
  wire n8341_o;
  wire [8:0] n8342_o;
  wire [8:0] n8343_o;
  wire [4:0] n8344_o;
  wire n8346_o;
  wire n8347_o;
  wire n8348_o;
  wire [8:0] n8350_o;
  wire [8:0] n8351_o;
  wire [8:0] n8352_o;
  wire [3:0] n8353_o;
  wire n8355_o;
  wire n8356_o;
  wire n8357_o;
  wire [8:0] n8358_o;
  wire [3:0] n8359_o;
  wire n8361_o;
  wire n8363_o;
  wire [8:0] n8364_o;
  wire [7:0] n8365_o;
  wire [7:0] n8367_o;
  wire n8368_o;
  wire [7:0] n8369_o;
  wire n8371_o;
  wire n8372_o;
  wire n8373_o;
  wire [8:0] n8374_o;
  wire [8:0] n8376_o;
  wire [8:0] n8377_o;
  wire [8:0] n8378_o;
  wire n8379_o;
  wire [8:0] n8380_o;
  wire n8381_o;
  wire n8382_o;
  wire n8383_o;
  wire n8384_o;
  wire n8385_o;
  wire [7:0] n8386_o;
  wire [7:0] n8387_o;
  wire n8389_o;
  wire n8392_o;
  wire n8393_o;
  wire n8394_o;
  wire n8395_o;
  wire n8396_o;
  wire n8397_o;
  wire n8398_o;
  wire n8399_o;
  wire n8400_o;
  wire n8401_o;
  wire n8402_o;
  wire n8403_o;
  wire n8404_o;
  wire n8405_o;
  wire n8406_o;
  wire n8407_o;
  wire n8408_o;
  wire n8409_o;
  wire n8411_o;
  wire [3:0] n8412_o;
  wire n8413_o;
  wire [3:0] n8414_o;
  wire [3:0] n8415_o;
  wire [3:0] n8416_o;
  wire [7:0] n8419_o;
  wire n8420_o;
  wire [7:0] n8421_o;
  wire n8422_o;
  wire [7:0] n8423_o;
  wire n8425_o;
  wire n8428_o;
  wire [7:0] n8429_o;
  wire n8430_o;
  wire [7:0] n8431_o;
  wire n8432_o;
  wire [7:0] n8433_o;
  wire n8434_o;
  wire n8435_o;
  wire [7:0] n8436_o;
  wire n8437_o;
  wire n8438_o;
  wire [7:0] n8439_o;
  wire n8440_o;
  wire n8441_o;
  wire [7:0] n8442_o;
  wire n8443_o;
  wire n8444_o;
  wire [7:0] n8445_o;
  wire n8446_o;
  wire n8447_o;
  wire [7:0] n8448_o;
  wire n8449_o;
  wire n8450_o;
  wire [7:0] n8451_o;
  wire n8452_o;
  wire n8453_o;
  wire n8454_o;
  wire n8456_o;
  wire n8458_o;
  wire n8459_o;
  wire [7:0] n8460_o;
  wire n8461_o;
  wire n8463_o;
  wire n8468_o;
  wire n8469_o;
  wire [2:0] n8472_o;
  wire n8474_o;
  wire n8476_o;
  wire n8477_o;
  wire n8478_o;
  wire n8479_o;
  wire n8480_o;
  wire n8481_o;
  wire n8482_o;
  wire n8483_o;
  wire n8485_o;
  wire [7:0] n8486_o;
  wire n8488_o;
  wire [7:0] n8489_o;
  wire [7:0] n8490_o;
  wire n8492_o;
  wire [2:0] n8493_o;
  wire [6:0] n8494_o;
  wire n8495_o;
  wire n8496_o;
  wire n8498_o;
  wire [6:0] n8499_o;
  wire n8500_o;
  wire n8501_o;
  wire n8503_o;
  wire [6:0] n8504_o;
  wire n8505_o;
  wire n8506_o;
  wire n8508_o;
  wire [6:0] n8509_o;
  wire n8510_o;
  wire n8511_o;
  wire n8513_o;
  wire [6:0] n8514_o;
  wire n8516_o;
  wire n8518_o;
  wire [31:0] n8519_o;
  wire n8521_o;
  wire [3:0] n8522_o;
  wire [3:0] n8523_o;
  wire [6:0] n8525_o;
  wire n8527_o;
  wire n8528_o;
  wire [7:0] n8529_o;
  wire [7:0] n8530_o;
  wire [7:0] n8531_o;
  wire n8533_o;
  wire [6:0] n8534_o;
  wire n8535_o;
  wire n8536_o;
  wire n8538_o;
  wire [6:0] n8539_o;
  wire n8541_o;
  wire [6:0] n8542_o;
  reg n8543_o;
  wire n8544_o;
  wire n8545_o;
  wire n8546_o;
  wire n8547_o;
  wire n8548_o;
  reg n8549_o;
  wire [5:0] n8550_o;
  wire [5:0] n8551_o;
  wire [5:0] n8552_o;
  wire [5:0] n8553_o;
  wire [5:0] n8554_o;
  wire [5:0] n8555_o;
  wire [5:0] n8556_o;
  wire [5:0] n8557_o;
  reg [5:0] n8558_o;
  wire n8559_o;
  wire n8560_o;
  wire n8561_o;
  wire n8562_o;
  reg n8563_o;
  wire [7:0] n8566_o;
  wire n8567_o;
  wire [7:0] n8568_o;
  wire n8569_o;
  wire [7:0] n8570_o;
  wire n8571_o;
  wire [7:0] n8572_o;
  wire n8574_o;
  wire n8577_o;
  wire [7:0] n8578_o;
  wire n8579_o;
  wire [7:0] n8580_o;
  wire n8581_o;
  wire n8582_o;
  wire [7:0] n8583_o;
  wire n8584_o;
  wire n8585_o;
  wire [7:0] n8586_o;
  wire n8587_o;
  wire n8588_o;
  wire [7:0] n8589_o;
  wire n8590_o;
  wire n8591_o;
  wire [7:0] n8592_o;
  wire n8593_o;
  wire n8594_o;
  wire [7:0] n8595_o;
  wire n8596_o;
  wire n8597_o;
  wire [7:0] n8598_o;
  wire n8599_o;
  wire n8600_o;
  wire n8601_o;
  wire n8603_o;
  wire n8604_o;
  wire n8605_o;
  wire n8606_o;
  wire [1:0] n8607_o;
  wire n8608_o;
  wire [1:0] n8609_o;
  wire [1:0] n8610_o;
  wire n8612_o;
  wire [6:0] n8613_o;
  wire n8614_o;
  reg n8615_o;
  wire n8616_o;
  reg n8617_o;
  wire n8618_o;
  reg n8619_o;
  wire n8620_o;
  reg n8621_o;
  wire n8622_o;
  reg n8623_o;
  wire n8624_o;
  reg n8625_o;
  wire n8626_o;
  wire n8627_o;
  wire n8628_o;
  reg n8629_o;
  wire n8630_o;
  wire n8631_o;
  wire n8632_o;
  reg n8633_o;
  wire n8641_o;
  wire n8642_o;
  wire n8643_o;
  wire n8644_o;
  wire n8645_o;
  wire n8646_o;
  reg n8648_o;
  wire [2:0] n8649_o;
  wire [2:0] n8650_o;
  wire [2:0] n8651_o;
  wire [2:0] n8652_o;
  wire [2:0] n8653_o;
  wire [2:0] n8654_o;
  wire [2:0] n8655_o;
  reg [2:0] n8657_o;
  wire [2:0] n8658_o;
  wire [2:0] n8659_o;
  wire [2:0] n8660_o;
  wire [2:0] n8661_o;
  wire [2:0] n8662_o;
  wire [2:0] n8663_o;
  wire [2:0] n8664_o;
  reg [2:0] n8666_o;
  wire n8667_o;
  wire n8668_o;
  wire n8669_o;
  wire n8670_o;
  wire n8671_o;
  wire n8672_o;
  reg n8674_o;
  wire [7:0] n8682_o;
  wire [7:0] n8685_o;
  wire [7:0] n8686_o;
  assign q = n8682_o;
  assign f_out = n8686_o;
  /* T80_ALU.vhd:127:16  */
  assign usecarry = n8106_o; // (signal)
  /* T80_ALU.vhd:128:16  */
  assign carry7_v = n8153_o; // (signal)
  /* T80_ALU.vhd:129:16  */
  assign overflow_v = n8199_o; // (signal)
  /* T80_ALU.vhd:130:16  */
  assign halfcarry_v = n8131_o; // (signal)
  /* T80_ALU.vhd:131:16  */
  assign carry_v = n8175_o; // (signal)
  /* T80_ALU.vhd:132:16  */
  assign q_v = n8685_o; // (signal)
  /* T80_ALU.vhd:134:16  */
  assign bitmask = n8102_o; // (signal)
  /* T80_ALU.vhd:138:16  */
  assign n8078_o = ir[5:3];
  /* T80_ALU.vhd:138:58  */
  assign n8081_o = n8078_o == 3'b000;
  /* T80_ALU.vhd:139:94  */
  assign n8084_o = n8078_o == 3'b001;
  /* T80_ALU.vhd:140:94  */
  assign n8087_o = n8078_o == 3'b010;
  /* T80_ALU.vhd:141:94  */
  assign n8090_o = n8078_o == 3'b011;
  /* T80_ALU.vhd:142:94  */
  assign n8093_o = n8078_o == 3'b100;
  /* T80_ALU.vhd:143:94  */
  assign n8096_o = n8078_o == 3'b101;
  /* T80_ALU.vhd:144:94  */
  assign n8099_o = n8078_o == 3'b110;
  /* T80_MCode.vhd:113:7  */
  assign n8101_o = {n8099_o, n8096_o, n8093_o, n8090_o, n8087_o, n8084_o, n8081_o};
  /* T80_ALU.vhd:138:9  */
  always @*
    case (n8101_o)
      7'b1000000: n8102_o = 8'b01000000;
      7'b0100000: n8102_o = 8'b00100000;
      7'b0010000: n8102_o = 8'b00010000;
      7'b0001000: n8102_o = 8'b00001000;
      7'b0000100: n8102_o = 8'b00000100;
      7'b0000010: n8102_o = 8'b00000010;
      7'b0000001: n8102_o = 8'b00000001;
      default: n8102_o = 8'b10000000;
    endcase
  /* T80_ALU.vhd:147:31  */
  assign n8103_o = alu_op[2];
  /* T80_ALU.vhd:147:21  */
  assign n8104_o = ~n8103_o;
  /* T80_ALU.vhd:147:45  */
  assign n8105_o = alu_op[0];
  /* T80_ALU.vhd:147:35  */
  assign n8106_o = n8104_o & n8105_o;
  /* T80_ALU.vhd:148:20  */
  assign n8108_o = busa[3:0];
  /* T80_ALU.vhd:148:38  */
  assign n8109_o = busb[3:0];
  /* T80_ALU.vhd:148:58  */
  assign n8110_o = alu_op[1];
  /* T80_ALU.vhd:148:69  */
  assign n8111_o = alu_op[1];
  /* T80_ALU.vhd:148:95  */
  assign n8112_o = f_in[0];
  /* T80_ALU.vhd:148:87  */
  assign n8113_o = usecarry & n8112_o;
  /* T80_ALU.vhd:148:73  */
  assign n8114_o = n8111_o ^ n8113_o;
  /* T80_ALU.vhd:116:32  */
  assign n8119_o = ~n8109_o;
  /* T80_ALU.vhd:115:17  */
  assign n8120_o = n8110_o ? n8119_o : n8109_o;
  /* T80_ALU.vhd:121:39  */
  assign n8123_o = {1'b0, n8108_o};
  /* T80_ALU.vhd:121:43  */
  assign n8124_o = {n8123_o, n8114_o};
  /* T80_ALU.vhd:121:70  */
  assign n8126_o = {1'b0, n8120_o};
  /* T80_ALU.vhd:121:76  */
  assign n8128_o = {n8126_o, 1'b1};
  /* T80_ALU.vhd:121:55  */
  assign n8129_o = n8124_o + n8128_o;
  /* T80_ALU.vhd:122:31  */
  assign n8131_o = n8129_o[5];
  /* T80_ALU.vhd:123:46  */
  assign n8132_o = n8129_o[4:1];
  /* T80_ALU.vhd:149:20  */
  assign n8134_o = busa[6:4];
  /* T80_ALU.vhd:149:38  */
  assign n8135_o = busb[6:4];
  /* T80_ALU.vhd:149:58  */
  assign n8136_o = alu_op[1];
  /* T80_ALU.vhd:116:32  */
  assign n8141_o = ~n8135_o;
  /* T80_ALU.vhd:115:17  */
  assign n8142_o = n8136_o ? n8141_o : n8135_o;
  /* T80_ALU.vhd:121:39  */
  assign n8145_o = {1'b0, n8134_o};
  /* T80_ALU.vhd:121:43  */
  assign n8146_o = {n8145_o, halfcarry_v};
  /* T80_ALU.vhd:121:70  */
  assign n8148_o = {1'b0, n8142_o};
  /* T80_ALU.vhd:121:76  */
  assign n8150_o = {n8148_o, 1'b1};
  /* T80_ALU.vhd:121:55  */
  assign n8151_o = n8146_o + n8150_o;
  /* T80_ALU.vhd:122:31  */
  assign n8153_o = n8151_o[4];
  /* T80_ALU.vhd:123:46  */
  assign n8154_o = n8151_o[3:1];
  /* T80_ALU.vhd:150:20  */
  assign n8156_o = busa[7];
  /* T80_ALU.vhd:150:38  */
  assign n8157_o = busb[7];
  /* T80_ALU.vhd:150:58  */
  assign n8158_o = alu_op[1];
  /* T80_ALU.vhd:116:32  */
  assign n8163_o = ~n8157_o;
  /* T80_ALU.vhd:115:17  */
  assign n8164_o = n8158_o ? n8163_o : n8157_o;
  /* T80_ALU.vhd:121:39  */
  assign n8167_o = {1'b0, n8156_o};
  /* T80_ALU.vhd:121:43  */
  assign n8168_o = {n8167_o, carry7_v};
  /* T80_ALU.vhd:121:70  */
  assign n8170_o = {1'b0, n8164_o};
  /* T80_ALU.vhd:121:76  */
  assign n8172_o = {n8170_o, 1'b1};
  /* T80_ALU.vhd:121:55  */
  assign n8173_o = n8168_o + n8172_o;
  /* T80_ALU.vhd:122:31  */
  assign n8175_o = n8173_o[2];
  /* T80_ALU.vhd:123:46  */
  assign n8176_o = n8173_o[1];
  /* T80_ALU.vhd:155:28  */
  assign n8179_o = {30'b0, mode_sel};  //  uext
  /* T80_ALU.vhd:155:28  */
  assign n8181_o = n8179_o == 32'b00000000000000000000000000000010;
  /* T80_ALU.vhd:156:47  */
  assign n8182_o = q_v[0];
  /* T80_ALU.vhd:156:58  */
  assign n8183_o = q_v[1];
  /* T80_ALU.vhd:156:51  */
  assign n8184_o = n8182_o ^ n8183_o;
  /* T80_ALU.vhd:156:69  */
  assign n8185_o = q_v[2];
  /* T80_ALU.vhd:156:62  */
  assign n8186_o = n8184_o ^ n8185_o;
  /* T80_ALU.vhd:156:80  */
  assign n8187_o = q_v[3];
  /* T80_ALU.vhd:156:73  */
  assign n8188_o = n8186_o ^ n8187_o;
  /* T80_ALU.vhd:157:47  */
  assign n8189_o = q_v[4];
  /* T80_ALU.vhd:156:84  */
  assign n8190_o = n8188_o ^ n8189_o;
  /* T80_ALU.vhd:157:58  */
  assign n8191_o = q_v[5];
  /* T80_ALU.vhd:157:51  */
  assign n8192_o = n8190_o ^ n8191_o;
  /* T80_ALU.vhd:157:69  */
  assign n8193_o = q_v[6];
  /* T80_ALU.vhd:157:62  */
  assign n8194_o = n8192_o ^ n8193_o;
  /* T80_ALU.vhd:157:80  */
  assign n8195_o = q_v[7];
  /* T80_ALU.vhd:157:73  */
  assign n8196_o = n8194_o ^ n8195_o;
  /* T80_ALU.vhd:156:39  */
  assign n8197_o = ~n8196_o;
  /* T80_ALU.vhd:158:47  */
  assign n8198_o = carry_v ^ carry7_v;
  /* T80_ALU.vhd:155:17  */
  assign n8199_o = n8181_o ? n8197_o : n8198_o;
  /* T80_ALU.vhd:173:36  */
  assign n8207_o = alu_op[2:0];
  /* T80_ALU.vhd:174:25  */
  assign n8209_o = n8207_o == 3'b000;
  /* T80_ALU.vhd:174:36  */
  assign n8211_o = n8207_o == 3'b001;
  /* T80_ALU.vhd:174:36  */
  assign n8212_o = n8209_o | n8211_o;
  /* T80_ALU.vhd:182:50  */
  assign n8214_o = ~carry_v;
  /* T80_ALU.vhd:183:50  */
  assign n8215_o = ~halfcarry_v;
  /* T80_ALU.vhd:179:25  */
  assign n8217_o = n8207_o == 3'b010;
  /* T80_ALU.vhd:179:36  */
  assign n8219_o = n8207_o == 3'b011;
  /* T80_ALU.vhd:179:36  */
  assign n8220_o = n8217_o | n8219_o;
  /* T80_ALU.vhd:179:44  */
  assign n8222_o = n8207_o == 3'b111;
  /* T80_ALU.vhd:179:44  */
  assign n8223_o = n8220_o | n8222_o;
  /* T80_ALU.vhd:186:57  */
  assign n8224_o = busa & busb;
  /* T80_ALU.vhd:185:25  */
  assign n8227_o = n8207_o == 3'b100;
  /* T80_ALU.vhd:189:57  */
  assign n8228_o = busa ^ busb;
  /* T80_ALU.vhd:188:25  */
  assign n8231_o = n8207_o == 3'b101;
  /* T80_ALU.vhd:192:57  */
  assign n8232_o = busa | busb;
  assign n8234_o = {n8231_o, n8227_o, n8223_o, n8212_o};
  /* T80_ALU.vhd:173:25  */
  always @*
    case (n8234_o)
      4'b1000: n8235_o = 1'b0;
      4'b0100: n8235_o = 1'b0;
      4'b0010: n8235_o = n8214_o;
      4'b0001: n8235_o = carry_v;
      default: n8235_o = 1'b0;
    endcase
  /* T80_ALU.vhd:173:25  */
  always @*
    case (n8234_o)
      4'b1000: n8236_o = 1'b0;
      4'b0100: n8236_o = 1'b0;
      4'b0010: n8236_o = 1'b1;
      4'b0001: n8236_o = 1'b0;
      default: n8236_o = 1'b0;
    endcase
  assign n8237_o = f_in[2];
  /* T80_ALU.vhd:173:25  */
  always @*
    case (n8234_o)
      4'b1000: n8238_o = n8237_o;
      4'b0100: n8238_o = n8237_o;
      4'b0010: n8238_o = overflow_v;
      4'b0001: n8238_o = overflow_v;
      default: n8238_o = n8237_o;
    endcase
  /* T80_ALU.vhd:173:25  */
  always @*
    case (n8234_o)
      4'b1000: n8239_o = 1'b0;
      4'b0100: n8239_o = 1'b1;
      4'b0010: n8239_o = n8215_o;
      4'b0001: n8239_o = halfcarry_v;
      default: n8239_o = 1'b0;
    endcase
  /* T80_ALU.vhd:173:25  */
  always @*
    case (n8234_o)
      4'b1000: n8240_o = n8228_o;
      4'b0100: n8240_o = n8224_o;
      4'b0010: n8240_o = q_v;
      4'b0001: n8240_o = q_v;
      default: n8240_o = n8232_o;
    endcase
  /* T80_ALU.vhd:195:34  */
  assign n8241_o = alu_op[2:0];
  /* T80_ALU.vhd:195:47  */
  assign n8243_o = n8241_o == 3'b111;
  /* T80_ALU.vhd:196:54  */
  assign n8244_o = busb[3];
  /* T80_ALU.vhd:197:54  */
  assign n8245_o = busb[5];
  /* T80_ALU.vhd:199:53  */
  assign n8246_o = n8240_o[3];
  /* T80_ALU.vhd:200:53  */
  assign n8247_o = n8240_o[5];
  /* T80_ALU.vhd:195:25  */
  assign n8248_o = n8243_o ? n8244_o : n8246_o;
  /* T80_ALU.vhd:195:25  */
  assign n8249_o = n8243_o ? n8245_o : n8247_o;
  /* T80_ALU.vhd:202:44  */
  assign n8251_o = n8240_o == 8'b00000000;
  /* T80_ALU.vhd:205:62  */
  assign n8253_o = f_in[6];
  /* T80_ALU.vhd:204:33  */
  assign n8254_o = z16 ? n8253_o : 1'b1;
  /* T80_ALU.vhd:202:25  */
  assign n8256_o = n8251_o ? n8254_o : 1'b0;
  /* T80_ALU.vhd:210:45  */
  assign n8257_o = n8240_o[7];
  /* T80_ALU.vhd:211:36  */
  assign n8258_o = alu_op[2:0];
  /* T80_ALU.vhd:212:25  */
  assign n8260_o = n8258_o == 3'b000;
  /* T80_ALU.vhd:212:36  */
  assign n8262_o = n8258_o == 3'b001;
  /* T80_ALU.vhd:212:36  */
  assign n8263_o = n8260_o | n8262_o;
  /* T80_ALU.vhd:212:44  */
  assign n8265_o = n8258_o == 3'b010;
  /* T80_ALU.vhd:212:44  */
  assign n8266_o = n8263_o | n8265_o;
  /* T80_ALU.vhd:212:52  */
  assign n8268_o = n8258_o == 3'b011;
  /* T80_ALU.vhd:212:52  */
  assign n8269_o = n8266_o | n8268_o;
  /* T80_ALU.vhd:212:60  */
  assign n8271_o = n8258_o == 3'b111;
  /* T80_ALU.vhd:212:60  */
  assign n8272_o = n8269_o | n8271_o;
  /* T80_ALU.vhd:214:58  */
  assign n8273_o = n8240_o[0];
  /* T80_ALU.vhd:214:69  */
  assign n8274_o = n8240_o[1];
  /* T80_ALU.vhd:214:62  */
  assign n8275_o = n8273_o ^ n8274_o;
  /* T80_ALU.vhd:214:80  */
  assign n8276_o = n8240_o[2];
  /* T80_ALU.vhd:214:73  */
  assign n8277_o = n8275_o ^ n8276_o;
  /* T80_ALU.vhd:214:91  */
  assign n8278_o = n8240_o[3];
  /* T80_ALU.vhd:214:84  */
  assign n8279_o = n8277_o ^ n8278_o;
  /* T80_ALU.vhd:215:44  */
  assign n8280_o = n8240_o[4];
  /* T80_ALU.vhd:214:95  */
  assign n8281_o = n8279_o ^ n8280_o;
  /* T80_ALU.vhd:215:55  */
  assign n8282_o = n8240_o[5];
  /* T80_ALU.vhd:215:48  */
  assign n8283_o = n8281_o ^ n8282_o;
  /* T80_ALU.vhd:215:66  */
  assign n8284_o = n8240_o[6];
  /* T80_ALU.vhd:215:59  */
  assign n8285_o = n8283_o ^ n8284_o;
  /* T80_ALU.vhd:215:77  */
  assign n8286_o = n8240_o[7];
  /* T80_ALU.vhd:215:70  */
  assign n8287_o = n8285_o ^ n8286_o;
  /* T80_ALU.vhd:214:50  */
  assign n8288_o = ~n8287_o;
  /* T80_ALU.vhd:211:25  */
  always @*
    case (n8272_o)
      1'b1: n8289_o = n8238_o;
      default: n8289_o = n8288_o;
    endcase
  /* T80_ALU.vhd:218:54  */
  assign n8290_o = f_in[7];
  /* T80_ALU.vhd:219:54  */
  assign n8291_o = f_in[6];
  /* T80_ALU.vhd:220:54  */
  assign n8292_o = f_in[2];
  assign n8293_o = {n8290_o, n8291_o};
  /* T80_ALU.vhd:217:25  */
  assign n8294_o = arith16 ? n8292_o : n8289_o;
  assign n8295_o = {n8257_o, n8256_o};
  /* T80_ALU.vhd:217:25  */
  assign n8296_o = arith16 ? n8293_o : n8295_o;
  /* T80_ALU.vhd:170:17  */
  assign n8298_o = alu_op == 4'b0000;
  /* T80_ALU.vhd:170:29  */
  assign n8300_o = alu_op == 4'b0001;
  /* T80_ALU.vhd:170:29  */
  assign n8301_o = n8298_o | n8300_o;
  /* T80_ALU.vhd:170:38  */
  assign n8303_o = alu_op == 4'b0010;
  /* T80_ALU.vhd:170:38  */
  assign n8304_o = n8301_o | n8303_o;
  /* T80_ALU.vhd:170:48  */
  assign n8306_o = alu_op == 4'b0011;
  /* T80_ALU.vhd:170:48  */
  assign n8307_o = n8304_o | n8306_o;
  /* T80_ALU.vhd:170:57  */
  assign n8309_o = alu_op == 4'b0100;
  /* T80_ALU.vhd:170:57  */
  assign n8310_o = n8307_o | n8309_o;
  /* T80_ALU.vhd:170:66  */
  assign n8312_o = alu_op == 4'b0101;
  /* T80_ALU.vhd:170:66  */
  assign n8313_o = n8310_o | n8312_o;
  /* T80_ALU.vhd:170:75  */
  assign n8315_o = alu_op == 4'b0110;
  /* T80_ALU.vhd:170:75  */
  assign n8316_o = n8313_o | n8315_o;
  /* T80_ALU.vhd:170:84  */
  assign n8318_o = alu_op == 4'b0111;
  /* T80_ALU.vhd:170:84  */
  assign n8319_o = n8316_o | n8318_o;
  /* T80_ALU.vhd:224:46  */
  assign n8320_o = f_in[4];
  /* T80_ALU.vhd:228:32  */
  assign n8323_o = f_in[1];
  /* T80_ALU.vhd:228:41  */
  assign n8324_o = ~n8323_o;
  assign n8325_o = {1'b0, busa};
  /* T80_ALU.vhd:231:41  */
  assign n8326_o = n8325_o[3:0];
  /* T80_ALU.vhd:231:54  */
  assign n8328_o = $unsigned(n8326_o) > $unsigned(4'b1001);
  /* T80_ALU.vhd:231:65  */
  assign n8329_o = f_in[4];
  /* T80_ALU.vhd:231:58  */
  assign n8330_o = n8328_o | n8329_o;
  assign n8331_o = {1'b0, busa};
  /* T80_ALU.vhd:232:50  */
  assign n8332_o = n8331_o[3:0];
  /* T80_ALU.vhd:232:63  */
  assign n8334_o = $unsigned(n8332_o) > $unsigned(4'b1001);
  /* T80_ALU.vhd:232:41  */
  assign n8337_o = n8334_o ? 1'b1 : 1'b0;
  assign n8338_o = {1'b0, busa};
  /* T80_ALU.vhd:237:56  */
  assign n8340_o = n8338_o + 9'b000000110;
  /* T80_ALU.vhd:231:33  */
  assign n8341_o = n8330_o ? n8337_o : n8320_o;
  assign n8342_o = {1'b0, busa};
  /* T80_ALU.vhd:231:33  */
  assign n8343_o = n8330_o ? n8340_o : n8342_o;
  /* T80_ALU.vhd:240:41  */
  assign n8344_o = n8343_o[8:4];
  /* T80_ALU.vhd:240:54  */
  assign n8346_o = $unsigned(n8344_o) > $unsigned(5'b01001);
  /* T80_ALU.vhd:240:65  */
  assign n8347_o = f_in[0];
  /* T80_ALU.vhd:240:58  */
  assign n8348_o = n8346_o | n8347_o;
  /* T80_ALU.vhd:241:56  */
  assign n8350_o = n8343_o + 9'b001100000;
  /* T80_ALU.vhd:240:33  */
  assign n8351_o = n8348_o ? n8350_o : n8343_o;
  assign n8352_o = {1'b0, busa};
  /* T80_ALU.vhd:245:41  */
  assign n8353_o = n8352_o[3:0];
  /* T80_ALU.vhd:245:54  */
  assign n8355_o = $unsigned(n8353_o) > $unsigned(4'b1001);
  /* T80_ALU.vhd:245:65  */
  assign n8356_o = f_in[4];
  /* T80_ALU.vhd:245:58  */
  assign n8357_o = n8355_o | n8356_o;
  assign n8358_o = {1'b0, busa};
  /* T80_ALU.vhd:246:49  */
  assign n8359_o = n8358_o[3:0];
  /* T80_ALU.vhd:246:62  */
  assign n8361_o = $unsigned(n8359_o) > $unsigned(4'b0101);
  /* T80_ALU.vhd:245:33  */
  assign n8363_o = n8368_o ? 1'b0 : n8320_o;
  assign n8364_o = {1'b0, busa};
  /* T80_ALU.vhd:249:67  */
  assign n8365_o = n8364_o[7:0];
  /* T80_ALU.vhd:249:80  */
  assign n8367_o = n8365_o - 8'b00000110;
  /* T80_ALU.vhd:245:33  */
  assign n8368_o = n8361_o & n8357_o;
  /* T80_ALU.vhd:245:33  */
  assign n8369_o = n8357_o ? n8367_o : busa;
  /* T80_ALU.vhd:251:51  */
  assign n8371_o = $unsigned(busa) > $unsigned(8'b10011001);
  /* T80_ALU.vhd:251:64  */
  assign n8372_o = f_in[0];
  /* T80_ALU.vhd:251:57  */
  assign n8373_o = n8371_o | n8372_o;
  assign n8374_o = {1'b0, n8369_o};
  /* T80_ALU.vhd:252:56  */
  assign n8376_o = n8374_o - 9'b101100000;
  assign n8377_o = {1'b0, n8369_o};
  /* T80_ALU.vhd:251:33  */
  assign n8378_o = n8373_o ? n8376_o : n8377_o;
  /* T80_ALU.vhd:228:25  */
  assign n8379_o = n8324_o ? n8341_o : n8363_o;
  /* T80_ALU.vhd:228:25  */
  assign n8380_o = n8324_o ? n8351_o : n8378_o;
  /* T80_ALU.vhd:255:47  */
  assign n8381_o = n8380_o[3];
  /* T80_ALU.vhd:256:47  */
  assign n8382_o = n8380_o[5];
  /* T80_ALU.vhd:257:46  */
  assign n8383_o = f_in[0];
  /* T80_ALU.vhd:257:63  */
  assign n8384_o = n8380_o[8];
  /* T80_ALU.vhd:257:55  */
  assign n8385_o = n8383_o | n8384_o;
  /* T80_ALU.vhd:258:54  */
  assign n8386_o = n8380_o[7:0];
  /* T80_ALU.vhd:259:33  */
  assign n8387_o = n8380_o[7:0];
  /* T80_ALU.vhd:259:46  */
  assign n8389_o = n8387_o == 8'b00000000;
  /* T80_ALU.vhd:259:25  */
  assign n8392_o = n8389_o ? 1'b1 : 1'b0;
  /* T80_ALU.vhd:264:47  */
  assign n8393_o = n8380_o[7];
  /* T80_ALU.vhd:265:52  */
  assign n8394_o = n8380_o[0];
  /* T80_ALU.vhd:265:65  */
  assign n8395_o = n8380_o[1];
  /* T80_ALU.vhd:265:56  */
  assign n8396_o = n8394_o ^ n8395_o;
  /* T80_ALU.vhd:265:78  */
  assign n8397_o = n8380_o[2];
  /* T80_ALU.vhd:265:69  */
  assign n8398_o = n8396_o ^ n8397_o;
  /* T80_ALU.vhd:265:91  */
  assign n8399_o = n8380_o[3];
  /* T80_ALU.vhd:265:82  */
  assign n8400_o = n8398_o ^ n8399_o;
  /* T80_ALU.vhd:266:38  */
  assign n8401_o = n8380_o[4];
  /* T80_ALU.vhd:265:95  */
  assign n8402_o = n8400_o ^ n8401_o;
  /* T80_ALU.vhd:266:51  */
  assign n8403_o = n8380_o[5];
  /* T80_ALU.vhd:266:42  */
  assign n8404_o = n8402_o ^ n8403_o;
  /* T80_ALU.vhd:266:64  */
  assign n8405_o = n8380_o[6];
  /* T80_ALU.vhd:266:55  */
  assign n8406_o = n8404_o ^ n8405_o;
  /* T80_ALU.vhd:266:77  */
  assign n8407_o = n8380_o[7];
  /* T80_ALU.vhd:266:68  */
  assign n8408_o = n8406_o ^ n8407_o;
  /* T80_ALU.vhd:265:42  */
  assign n8409_o = ~n8408_o;
  /* T80_ALU.vhd:222:17  */
  assign n8411_o = alu_op == 4'b1100;
  /* T80_ALU.vhd:269:48  */
  assign n8412_o = busa[7:4];
  /* T80_ALU.vhd:270:34  */
  assign n8413_o = alu_op[0];
  /* T80_ALU.vhd:271:56  */
  assign n8414_o = busb[7:4];
  /* T80_ALU.vhd:273:56  */
  assign n8415_o = busb[3:0];
  /* T80_ALU.vhd:270:25  */
  assign n8416_o = n8413_o ? n8414_o : n8415_o;
  assign n8419_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:277:45  */
  assign n8420_o = n8419_o[3];
  assign n8421_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:278:45  */
  assign n8422_o = n8421_o[5];
  assign n8423_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:279:44  */
  assign n8425_o = n8423_o == 8'b00000000;
  /* T80_ALU.vhd:279:25  */
  assign n8428_o = n8425_o ? 1'b1 : 1'b0;
  assign n8429_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:284:45  */
  assign n8430_o = n8429_o[7];
  assign n8431_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:285:50  */
  assign n8432_o = n8431_o[0];
  assign n8433_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:285:61  */
  assign n8434_o = n8433_o[1];
  /* T80_ALU.vhd:285:54  */
  assign n8435_o = n8432_o ^ n8434_o;
  assign n8436_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:285:72  */
  assign n8437_o = n8436_o[2];
  /* T80_ALU.vhd:285:65  */
  assign n8438_o = n8435_o ^ n8437_o;
  assign n8439_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:285:83  */
  assign n8440_o = n8439_o[3];
  /* T80_ALU.vhd:285:76  */
  assign n8441_o = n8438_o ^ n8440_o;
  assign n8442_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:286:36  */
  assign n8443_o = n8442_o[4];
  /* T80_ALU.vhd:285:87  */
  assign n8444_o = n8441_o ^ n8443_o;
  assign n8445_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:286:47  */
  assign n8446_o = n8445_o[5];
  /* T80_ALU.vhd:286:40  */
  assign n8447_o = n8444_o ^ n8446_o;
  assign n8448_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:286:58  */
  assign n8449_o = n8448_o[6];
  /* T80_ALU.vhd:286:51  */
  assign n8450_o = n8447_o ^ n8449_o;
  assign n8451_o = {n8412_o, n8416_o};
  /* T80_ALU.vhd:286:69  */
  assign n8452_o = n8451_o[7];
  /* T80_ALU.vhd:286:62  */
  assign n8453_o = n8450_o ^ n8452_o;
  /* T80_ALU.vhd:285:42  */
  assign n8454_o = ~n8453_o;
  /* T80_ALU.vhd:267:17  */
  assign n8456_o = alu_op == 4'b1101;
  /* T80_ALU.vhd:267:29  */
  assign n8458_o = alu_op == 4'b1110;
  /* T80_ALU.vhd:267:29  */
  assign n8459_o = n8456_o | n8458_o;
  /* T80_ALU.vhd:289:49  */
  assign n8460_o = busb & bitmask;
  /* T80_ALU.vhd:290:45  */
  assign n8461_o = n8460_o[7];
  /* T80_ALU.vhd:291:44  */
  assign n8463_o = n8460_o == 8'b00000000;
  /* T80_ALU.vhd:291:25  */
  assign n8468_o = n8463_o ? 1'b1 : 1'b0;
  /* T80_ALU.vhd:291:25  */
  assign n8469_o = n8463_o ? 1'b1 : 1'b0;
  /* T80_ALU.vhd:300:30  */
  assign n8472_o = ir[2:0];
  /* T80_ALU.vhd:300:43  */
  assign n8474_o = n8472_o == 3'b110;
  /* T80_ALU.vhd:300:63  */
  assign n8476_o = xy_state != 2'b00;
  /* T80_ALU.vhd:300:51  */
  assign n8477_o = n8474_o | n8476_o;
  /* T80_ALU.vhd:301:52  */
  assign n8478_o = wz[11];
  /* T80_ALU.vhd:302:52  */
  assign n8479_o = wz[13];
  /* T80_ALU.vhd:304:54  */
  assign n8480_o = busb[3];
  /* T80_ALU.vhd:305:54  */
  assign n8481_o = busb[5];
  /* T80_ALU.vhd:300:25  */
  assign n8482_o = n8477_o ? n8478_o : n8480_o;
  /* T80_ALU.vhd:300:25  */
  assign n8483_o = n8477_o ? n8479_o : n8481_o;
  /* T80_ALU.vhd:287:17  */
  assign n8485_o = alu_op == 4'b1001;
  /* T80_ALU.vhd:309:49  */
  assign n8486_o = busb | bitmask;
  /* T80_ALU.vhd:307:17  */
  assign n8488_o = alu_op == 4'b1010;
  /* T80_ALU.vhd:312:53  */
  assign n8489_o = ~bitmask;
  /* T80_ALU.vhd:312:49  */
  assign n8490_o = busb & n8489_o;
  /* T80_ALU.vhd:310:17  */
  assign n8492_o = alu_op == 4'b1011;
  /* T80_ALU.vhd:315:32  */
  assign n8493_o = ir[5:3];
  /* T80_ALU.vhd:317:56  */
  assign n8494_o = busa[6:0];
  /* T80_ALU.vhd:318:47  */
  assign n8495_o = busa[7];
  /* T80_ALU.vhd:319:54  */
  assign n8496_o = busa[7];
  /* T80_ALU.vhd:316:25  */
  assign n8498_o = n8493_o == 3'b000;
  /* T80_ALU.vhd:321:56  */
  assign n8499_o = busa[6:0];
  /* T80_ALU.vhd:322:47  */
  assign n8500_o = f_in[0];
  /* T80_ALU.vhd:323:54  */
  assign n8501_o = busa[7];
  /* T80_ALU.vhd:320:25  */
  assign n8503_o = n8493_o == 3'b010;
  /* T80_ALU.vhd:325:56  */
  assign n8504_o = busa[7:1];
  /* T80_ALU.vhd:326:47  */
  assign n8505_o = busa[0];
  /* T80_ALU.vhd:327:54  */
  assign n8506_o = busa[0];
  /* T80_ALU.vhd:324:25  */
  assign n8508_o = n8493_o == 3'b001;
  /* T80_ALU.vhd:329:56  */
  assign n8509_o = busa[7:1];
  /* T80_ALU.vhd:330:47  */
  assign n8510_o = f_in[0];
  /* T80_ALU.vhd:331:54  */
  assign n8511_o = busa[0];
  /* T80_ALU.vhd:328:25  */
  assign n8513_o = n8493_o == 3'b011;
  /* T80_ALU.vhd:333:56  */
  assign n8514_o = busa[6:0];
  /* T80_ALU.vhd:335:54  */
  assign n8516_o = busa[7];
  /* T80_ALU.vhd:332:25  */
  assign n8518_o = n8493_o == 3'b100;
  /* T80_ALU.vhd:337:45  */
  assign n8519_o = {30'b0, mode_sel};  //  uext
  /* T80_ALU.vhd:337:45  */
  assign n8521_o = n8519_o == 32'b00000000000000000000000000000011;
  /* T80_ALU.vhd:338:64  */
  assign n8522_o = busa[3:0];
  /* T80_ALU.vhd:339:64  */
  assign n8523_o = busa[7:4];
  /* T80_ALU.vhd:342:64  */
  assign n8525_o = busa[6:0];
  /* T80_ALU.vhd:344:62  */
  assign n8527_o = busa[7];
  /* T80_ALU.vhd:337:33  */
  assign n8528_o = n8521_o ? 1'b0 : n8527_o;
  assign n8529_o = {n8525_o, 1'b1};
  assign n8530_o = {n8522_o, n8523_o};
  /* T80_ALU.vhd:337:33  */
  assign n8531_o = n8521_o ? n8530_o : n8529_o;
  /* T80_ALU.vhd:336:25  */
  assign n8533_o = n8493_o == 3'b110;
  /* T80_ALU.vhd:347:56  */
  assign n8534_o = busa[7:1];
  /* T80_ALU.vhd:348:47  */
  assign n8535_o = busa[7];
  /* T80_ALU.vhd:349:54  */
  assign n8536_o = busa[0];
  /* T80_ALU.vhd:346:25  */
  assign n8538_o = n8493_o == 3'b101;
  /* T80_ALU.vhd:351:56  */
  assign n8539_o = busa[7:1];
  /* T80_ALU.vhd:353:54  */
  assign n8541_o = busa[0];
  assign n8542_o = {n8538_o, n8533_o, n8518_o, n8513_o, n8508_o, n8503_o, n8498_o};
  /* T80_ALU.vhd:315:25  */
  always @*
    case (n8542_o)
      7'b1000000: n8543_o = n8536_o;
      7'b0100000: n8543_o = n8528_o;
      7'b0010000: n8543_o = n8516_o;
      7'b0001000: n8543_o = n8511_o;
      7'b0000100: n8543_o = n8506_o;
      7'b0000010: n8543_o = n8501_o;
      7'b0000001: n8543_o = n8496_o;
      default: n8543_o = n8541_o;
    endcase
  assign n8544_o = n8504_o[0];
  assign n8545_o = n8509_o[0];
  assign n8546_o = n8531_o[0];
  assign n8547_o = n8534_o[0];
  assign n8548_o = n8539_o[0];
  /* T80_ALU.vhd:315:25  */
  always @*
    case (n8542_o)
      7'b1000000: n8549_o = n8547_o;
      7'b0100000: n8549_o = n8546_o;
      7'b0010000: n8549_o = 1'b0;
      7'b0001000: n8549_o = n8545_o;
      7'b0000100: n8549_o = n8544_o;
      7'b0000010: n8549_o = n8500_o;
      7'b0000001: n8549_o = n8495_o;
      default: n8549_o = n8548_o;
    endcase
  assign n8550_o = n8494_o[5:0];
  assign n8551_o = n8499_o[5:0];
  assign n8552_o = n8504_o[6:1];
  assign n8553_o = n8509_o[6:1];
  assign n8554_o = n8514_o[5:0];
  assign n8555_o = n8531_o[6:1];
  assign n8556_o = n8534_o[6:1];
  assign n8557_o = n8539_o[6:1];
  /* T80_ALU.vhd:315:25  */
  always @*
    case (n8542_o)
      7'b1000000: n8558_o = n8556_o;
      7'b0100000: n8558_o = n8555_o;
      7'b0010000: n8558_o = n8554_o;
      7'b0001000: n8558_o = n8553_o;
      7'b0000100: n8558_o = n8552_o;
      7'b0000010: n8558_o = n8551_o;
      7'b0000001: n8558_o = n8550_o;
      default: n8558_o = n8557_o;
    endcase
  assign n8559_o = n8494_o[6];
  assign n8560_o = n8499_o[6];
  assign n8561_o = n8514_o[6];
  assign n8562_o = n8531_o[7];
  /* T80_ALU.vhd:315:25  */
  always @*
    case (n8542_o)
      7'b1000000: n8563_o = n8535_o;
      7'b0100000: n8563_o = n8562_o;
      7'b0010000: n8563_o = n8561_o;
      7'b0001000: n8563_o = n8510_o;
      7'b0000100: n8563_o = n8505_o;
      7'b0000010: n8563_o = n8560_o;
      7'b0000001: n8563_o = n8559_o;
      default: n8563_o = 1'b0;
    endcase
  assign n8566_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:357:45  */
  assign n8567_o = n8566_o[3];
  assign n8568_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:358:45  */
  assign n8569_o = n8568_o[5];
  assign n8570_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:359:45  */
  assign n8571_o = n8570_o[7];
  assign n8572_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:360:44  */
  assign n8574_o = n8572_o == 8'b00000000;
  /* T80_ALU.vhd:360:25  */
  assign n8577_o = n8574_o ? 1'b1 : 1'b0;
  assign n8578_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:365:50  */
  assign n8579_o = n8578_o[0];
  assign n8580_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:365:61  */
  assign n8581_o = n8580_o[1];
  /* T80_ALU.vhd:365:54  */
  assign n8582_o = n8579_o ^ n8581_o;
  assign n8583_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:365:72  */
  assign n8584_o = n8583_o[2];
  /* T80_ALU.vhd:365:65  */
  assign n8585_o = n8582_o ^ n8584_o;
  assign n8586_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:365:83  */
  assign n8587_o = n8586_o[3];
  /* T80_ALU.vhd:365:76  */
  assign n8588_o = n8585_o ^ n8587_o;
  assign n8589_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:366:36  */
  assign n8590_o = n8589_o[4];
  /* T80_ALU.vhd:365:87  */
  assign n8591_o = n8588_o ^ n8590_o;
  assign n8592_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:366:47  */
  assign n8593_o = n8592_o[5];
  /* T80_ALU.vhd:366:40  */
  assign n8594_o = n8591_o ^ n8593_o;
  assign n8595_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:366:58  */
  assign n8596_o = n8595_o[6];
  /* T80_ALU.vhd:366:51  */
  assign n8597_o = n8594_o ^ n8596_o;
  assign n8598_o = {n8563_o, n8558_o, n8549_o};
  /* T80_ALU.vhd:366:69  */
  assign n8599_o = n8598_o[7];
  /* T80_ALU.vhd:366:62  */
  assign n8600_o = n8597_o ^ n8599_o;
  /* T80_ALU.vhd:365:42  */
  assign n8601_o = ~n8600_o;
  /* T80_ALU.vhd:367:33  */
  assign n8603_o = iset == 2'b00;
  /* T80_ALU.vhd:368:54  */
  assign n8604_o = f_in[2];
  /* T80_ALU.vhd:369:54  */
  assign n8605_o = f_in[7];
  /* T80_ALU.vhd:370:54  */
  assign n8606_o = f_in[6];
  assign n8607_o = {n8605_o, n8606_o};
  /* T80_ALU.vhd:367:25  */
  assign n8608_o = n8603_o ? n8604_o : n8601_o;
  assign n8609_o = {n8571_o, n8577_o};
  /* T80_ALU.vhd:367:25  */
  assign n8610_o = n8603_o ? n8607_o : n8609_o;
  /* T80_ALU.vhd:313:17  */
  assign n8612_o = alu_op == 4'b1000;
  assign n8613_o = {n8612_o, n8492_o, n8488_o, n8485_o, n8459_o, n8411_o, n8319_o};
  assign n8614_o = f_in[0];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8615_o = n8543_o;
      7'b0100000: n8615_o = n8614_o;
      7'b0010000: n8615_o = n8614_o;
      7'b0001000: n8615_o = n8614_o;
      7'b0000100: n8615_o = n8614_o;
      7'b0000010: n8615_o = n8385_o;
      7'b0000001: n8615_o = n8235_o;
      default: n8615_o = n8614_o;
    endcase
  assign n8616_o = f_in[1];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8617_o = 1'b0;
      7'b0100000: n8617_o = n8616_o;
      7'b0010000: n8617_o = n8616_o;
      7'b0001000: n8617_o = 1'b0;
      7'b0000100: n8617_o = 1'b0;
      7'b0000010: n8617_o = n8616_o;
      7'b0000001: n8617_o = n8236_o;
      default: n8617_o = n8616_o;
    endcase
  assign n8618_o = f_in[2];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8619_o = n8608_o;
      7'b0100000: n8619_o = n8618_o;
      7'b0010000: n8619_o = n8618_o;
      7'b0001000: n8619_o = n8468_o;
      7'b0000100: n8619_o = n8454_o;
      7'b0000010: n8619_o = n8409_o;
      7'b0000001: n8619_o = n8294_o;
      default: n8619_o = n8618_o;
    endcase
  assign n8620_o = f_in[3];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8621_o = n8567_o;
      7'b0100000: n8621_o = n8620_o;
      7'b0010000: n8621_o = n8620_o;
      7'b0001000: n8621_o = n8482_o;
      7'b0000100: n8621_o = n8420_o;
      7'b0000010: n8621_o = n8381_o;
      7'b0000001: n8621_o = n8248_o;
      default: n8621_o = n8620_o;
    endcase
  assign n8622_o = f_in[4];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8623_o = 1'b0;
      7'b0100000: n8623_o = n8622_o;
      7'b0010000: n8623_o = n8622_o;
      7'b0001000: n8623_o = 1'b1;
      7'b0000100: n8623_o = 1'b0;
      7'b0000010: n8623_o = n8379_o;
      7'b0000001: n8623_o = n8239_o;
      default: n8623_o = n8622_o;
    endcase
  assign n8624_o = f_in[5];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8625_o = n8569_o;
      7'b0100000: n8625_o = n8624_o;
      7'b0010000: n8625_o = n8624_o;
      7'b0001000: n8625_o = n8483_o;
      7'b0000100: n8625_o = n8422_o;
      7'b0000010: n8625_o = n8382_o;
      7'b0000001: n8625_o = n8249_o;
      default: n8625_o = n8624_o;
    endcase
  assign n8626_o = n8296_o[0];
  assign n8627_o = n8610_o[0];
  assign n8628_o = f_in[6];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8629_o = n8627_o;
      7'b0100000: n8629_o = n8628_o;
      7'b0010000: n8629_o = n8628_o;
      7'b0001000: n8629_o = n8469_o;
      7'b0000100: n8629_o = n8428_o;
      7'b0000010: n8629_o = n8392_o;
      7'b0000001: n8629_o = n8626_o;
      default: n8629_o = n8628_o;
    endcase
  assign n8630_o = n8296_o[1];
  assign n8631_o = n8610_o[1];
  assign n8632_o = f_in[7];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8633_o = n8631_o;
      7'b0100000: n8633_o = n8632_o;
      7'b0010000: n8633_o = n8632_o;
      7'b0001000: n8633_o = n8461_o;
      7'b0000100: n8633_o = n8430_o;
      7'b0000010: n8633_o = n8393_o;
      7'b0000001: n8633_o = n8630_o;
      default: n8633_o = n8632_o;
    endcase
  assign n8641_o = n8240_o[0];
  assign n8642_o = n8386_o[0];
  assign n8643_o = n8416_o[0];
  assign n8644_o = n8460_o[0];
  assign n8645_o = n8486_o[0];
  assign n8646_o = n8490_o[0];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8648_o = n8549_o;
      7'b0100000: n8648_o = n8646_o;
      7'b0010000: n8648_o = n8645_o;
      7'b0001000: n8648_o = n8644_o;
      7'b0000100: n8648_o = n8643_o;
      7'b0000010: n8648_o = n8642_o;
      7'b0000001: n8648_o = n8641_o;
      default: n8648_o = 1'bX;
    endcase
  assign n8649_o = n8240_o[3:1];
  assign n8650_o = n8386_o[3:1];
  assign n8651_o = n8416_o[3:1];
  assign n8652_o = n8460_o[3:1];
  assign n8653_o = n8486_o[3:1];
  assign n8654_o = n8490_o[3:1];
  assign n8655_o = n8558_o[2:0];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8657_o = n8655_o;
      7'b0100000: n8657_o = n8654_o;
      7'b0010000: n8657_o = n8653_o;
      7'b0001000: n8657_o = n8652_o;
      7'b0000100: n8657_o = n8651_o;
      7'b0000010: n8657_o = n8650_o;
      7'b0000001: n8657_o = n8649_o;
      default: n8657_o = 3'bX;
    endcase
  assign n8658_o = n8240_o[6:4];
  assign n8659_o = n8386_o[6:4];
  assign n8660_o = n8412_o[2:0];
  assign n8661_o = n8460_o[6:4];
  assign n8662_o = n8486_o[6:4];
  assign n8663_o = n8490_o[6:4];
  assign n8664_o = n8558_o[5:3];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8666_o = n8664_o;
      7'b0100000: n8666_o = n8663_o;
      7'b0010000: n8666_o = n8662_o;
      7'b0001000: n8666_o = n8661_o;
      7'b0000100: n8666_o = n8660_o;
      7'b0000010: n8666_o = n8659_o;
      7'b0000001: n8666_o = n8658_o;
      default: n8666_o = 3'bX;
    endcase
  assign n8667_o = n8240_o[7];
  assign n8668_o = n8386_o[7];
  assign n8669_o = n8412_o[3];
  assign n8670_o = n8460_o[7];
  assign n8671_o = n8486_o[7];
  assign n8672_o = n8490_o[7];
  /* T80_ALU.vhd:169:17  */
  always @*
    case (n8613_o)
      7'b1000000: n8674_o = n8563_o;
      7'b0100000: n8674_o = n8672_o;
      7'b0010000: n8674_o = n8671_o;
      7'b0001000: n8674_o = n8670_o;
      7'b0000100: n8674_o = n8669_o;
      7'b0000010: n8674_o = n8668_o;
      7'b0000001: n8674_o = n8667_o;
      default: n8674_o = 1'bX;
    endcase
  assign n8682_o = {n8674_o, n8666_o, n8657_o, n8648_o};
  assign n8685_o = {n8176_o, n8154_o, n8132_o};
  assign n8686_o = {n8633_o, n8629_o, n8625_o, n8623_o, n8621_o, n8619_o, n8617_o, n8615_o};
endmodule

module t80_mcode_0_0_1_2_3_4_5_6_7
  (input  [7:0] ir,
   input  [1:0] iset,
   input  [2:0] mcycle,
   input  [7:0] f,
   input  nmicycle,
   input  intcycle,
   input  [1:0] xy_state,
   input  [1:0] mode_sel,
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
  wire [2:0] n2115_o;
  wire [2:0] n2116_o;
  wire [1:0] n2117_o;
  wire n2119_o;
  wire [2:0] n2122_o;
  wire [2:0] n2123_o;
  wire [3:0] n2125_o;
  wire n2127_o;
  wire n2129_o;
  wire n2130_o;
  wire n2132_o;
  wire n2133_o;
  wire n2135_o;
  wire n2136_o;
  wire n2138_o;
  wire n2139_o;
  wire n2141_o;
  wire n2142_o;
  wire n2144_o;
  wire n2145_o;
  wire n2147_o;
  wire n2148_o;
  wire n2150_o;
  wire n2151_o;
  wire n2153_o;
  wire n2154_o;
  wire n2156_o;
  wire n2157_o;
  wire n2159_o;
  wire n2160_o;
  wire n2162_o;
  wire n2163_o;
  wire n2165_o;
  wire n2166_o;
  wire n2168_o;
  wire n2169_o;
  wire n2171_o;
  wire n2172_o;
  wire n2174_o;
  wire n2175_o;
  wire n2177_o;
  wire n2178_o;
  wire n2180_o;
  wire n2181_o;
  wire n2183_o;
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
  wire [30:0] n2272_o;
  wire n2274_o;
  reg n2277_o;
  reg n2280_o;
  reg [2:0] n2282_o;
  wire n2284_o;
  wire n2286_o;
  wire n2287_o;
  wire n2289_o;
  wire n2290_o;
  wire n2292_o;
  wire n2293_o;
  wire n2295_o;
  wire n2296_o;
  wire n2298_o;
  wire n2299_o;
  wire n2301_o;
  wire n2302_o;
  wire [30:0] n2303_o;
  wire n2305_o;
  wire n2307_o;
  wire [1:0] n2308_o;
  reg n2311_o;
  reg [2:0] n2313_o;
  reg [2:0] n2316_o;
  wire n2318_o;
  wire n2320_o;
  wire n2321_o;
  wire n2323_o;
  wire n2324_o;
  wire n2326_o;
  wire n2327_o;
  wire n2329_o;
  wire n2330_o;
  wire n2332_o;
  wire n2333_o;
  wire n2335_o;
  wire n2336_o;
  wire [30:0] n2337_o;
  wire n2340_o;
  wire n2342_o;
  wire [1:0] n2343_o;
  reg [2:0] n2345_o;
  reg n2347_o;
  reg [2:0] n2350_o;
  reg n2353_o;
  wire n2355_o;
  wire n2357_o;
  wire n2358_o;
  wire n2360_o;
  wire n2361_o;
  wire n2363_o;
  wire n2364_o;
  wire n2366_o;
  wire n2367_o;
  wire n2369_o;
  wire n2370_o;
  wire n2372_o;
  wire n2373_o;
  wire [30:0] n2374_o;
  wire n2377_o;
  wire n2379_o;
  wire [1:0] n2380_o;
  reg n2383_o;
  reg [2:0] n2385_o;
  reg n2387_o;
  reg [2:0] n2390_o;
  reg n2393_o;
  wire n2395_o;
  wire [30:0] n2396_o;
  wire n2398_o;
  wire n2400_o;
  wire [1:0] n2401_o;
  reg n2404_o;
  reg [2:0] n2407_o;
  wire n2409_o;
  wire [30:0] n2410_o;
  wire n2412_o;
  wire n2414_o;
  wire [1:0] n2415_o;
  reg n2418_o;
  reg [2:0] n2421_o;
  wire n2423_o;
  wire [31:0] n2424_o;
  wire n2426_o;
  wire [30:0] n2427_o;
  wire n2429_o;
  wire n2431_o;
  wire [1:0] n2432_o;
  reg [3:0] n2435_o;
  reg n2438_o;
  reg [2:0] n2441_o;
  wire [30:0] n2442_o;
  wire n2444_o;
  wire n2446_o;
  wire n2448_o;
  wire [2:0] n2449_o;
  reg n2453_o;
  reg n2456_o;
  reg [2:0] n2459_o;
  reg n2462_o;
  wire [2:0] n2465_o;
  wire n2467_o;
  wire [3:0] n2469_o;
  wire n2470_o;
  wire [2:0] n2471_o;
  wire n2473_o;
  wire n2475_o;
  wire [30:0] n2476_o;
  wire n2478_o;
  wire n2480_o;
  wire [1:0] n2481_o;
  reg [3:0] n2484_o;
  reg [2:0] n2487_o;
  reg [1:0] n2490_o;
  reg n2493_o;
  wire n2495_o;
  wire [30:0] n2496_o;
  wire n2498_o;
  wire n2500_o;
  wire [1:0] n2501_o;
  reg [3:0] n2504_o;
  reg [2:0] n2507_o;
  reg [1:0] n2510_o;
  reg n2513_o;
  wire n2515_o;
  wire [31:0] n2516_o;
  wire n2518_o;
  wire [30:0] n2519_o;
  wire n2521_o;
  wire n2523_o;
  wire [1:0] n2524_o;
  reg [3:0] n2527_o;
  reg [3:0] n2530_o;
  reg [2:0] n2533_o;
  reg n2536_o;
  wire [30:0] n2537_o;
  wire n2539_o;
  wire n2541_o;
  wire n2543_o;
  wire [2:0] n2544_o;
  reg n2548_o;
  reg [3:0] n2551_o;
  reg [2:0] n2554_o;
  reg n2557_o;
  reg [1:0] n2560_o;
  reg n2563_o;
  wire [2:0] n2566_o;
  wire n2568_o;
  wire [3:0] n2570_o;
  wire [3:0] n2571_o;
  wire [2:0] n2572_o;
  wire n2574_o;
  wire [1:0] n2576_o;
  wire n2577_o;
  wire n2579_o;
  wire [30:0] n2580_o;
  wire n2582_o;
  wire [2:0] n2584_o;
  wire [2:0] n2586_o;
  wire n2589_o;
  wire n2591_o;
  wire n2593_o;
  wire [2:0] n2595_o;
  wire [2:0] n2597_o;
  wire n2600_o;
  wire n2602_o;
  wire [1:0] n2603_o;
  reg n2607_o;
  reg n2611_o;
  reg [2:0] n2613_o;
  reg n2615_o;
  wire n2617_o;
  wire n2619_o;
  wire n2620_o;
  wire n2622_o;
  wire n2623_o;
  wire n2625_o;
  wire n2626_o;
  wire [31:0] n2627_o;
  wire n2629_o;
  wire [30:0] n2630_o;
  wire n2632_o;
  wire n2634_o;
  wire [1:0] n2635_o;
  reg [3:0] n2638_o;
  reg n2641_o;
  reg [2:0] n2644_o;
  wire [30:0] n2645_o;
  wire n2647_o;
  wire n2649_o;
  wire n2652_o;
  wire n2655_o;
  wire [3:0] n2656_o;
  reg n2660_o;
  reg n2663_o;
  reg n2667_o;
  reg [2:0] n2669_o;
  reg [2:0] n2673_o;
  reg n2676_o;
  reg n2679_o;
  wire [2:0] n2682_o;
  wire n2684_o;
  wire n2686_o;
  wire [3:0] n2688_o;
  wire n2690_o;
  wire n2692_o;
  wire [2:0] n2694_o;
  wire [2:0] n2695_o;
  wire n2697_o;
  wire n2699_o;
  wire n2701_o;
  wire [31:0] n2702_o;
  wire n2704_o;
  wire [30:0] n2705_o;
  wire n2707_o;
  wire n2709_o;
  wire [1:0] n2710_o;
  reg [3:0] n2713_o;
  reg [3:0] n2716_o;
  reg [2:0] n2719_o;
  reg n2722_o;
  wire [30:0] n2723_o;
  wire n2725_o;
  wire n2727_o;
  wire n2729_o;
  wire n2731_o;
  wire [3:0] n2732_o;
  reg n2736_o;
  reg n2739_o;
  reg [3:0] n2743_o;
  reg [2:0] n2747_o;
  reg n2750_o;
  reg n2753_o;
  reg n2757_o;
  wire [2:0] n2760_o;
  wire n2762_o;
  wire n2764_o;
  wire [3:0] n2766_o;
  wire [3:0] n2767_o;
  wire [2:0] n2768_o;
  wire n2770_o;
  wire n2772_o;
  wire n2773_o;
  wire n2775_o;
  wire n2777_o;
  wire [30:0] n2778_o;
  wire n2780_o;
  wire [3:0] n2783_o;
  wire [3:0] n2785_o;
  wire n2787_o;
  wire n2789_o;
  wire [3:0] n2792_o;
  wire [3:0] n2794_o;
  wire n2796_o;
  wire n2798_o;
  wire [2:0] n2799_o;
  reg [2:0] n2801_o;
  reg [3:0] n2805_o;
  reg [3:0] n2807_o;
  reg [2:0] n2811_o;
  reg n2815_o;
  wire n2817_o;
  wire n2819_o;
  wire n2820_o;
  wire n2822_o;
  wire n2823_o;
  wire n2825_o;
  wire n2826_o;
  wire [30:0] n2827_o;
  wire n2829_o;
  wire n2831_o;
  wire [2:0] n2833_o;
  wire [2:0] n2835_o;
  wire n2838_o;
  wire n2840_o;
  wire n2842_o;
  wire [2:0] n2844_o;
  wire [2:0] n2846_o;
  wire n2849_o;
  wire n2851_o;
  wire [2:0] n2852_o;
  reg [3:0] n2856_o;
  reg n2860_o;
  reg [2:0] n2862_o;
  reg n2864_o;
  reg [2:0] n2868_o;
  wire n2870_o;
  wire n2872_o;
  wire n2873_o;
  wire n2875_o;
  wire n2876_o;
  wire n2878_o;
  wire n2879_o;
  wire [31:0] n2880_o;
  wire n2882_o;
  wire n2885_o;
  wire n2887_o;
  wire [31:0] n2888_o;
  wire n2890_o;
  wire [30:0] n2891_o;
  wire n2893_o;
  wire n2895_o;
  wire n2897_o;
  wire n2899_o;
  wire [3:0] n2900_o;
  reg n2904_o;
  reg n2907_o;
  reg [3:0] n2911_o;
  reg [2:0] n2915_o;
  reg n2918_o;
  reg n2921_o;
  reg n2925_o;
  wire [31:0] n2926_o;
  wire n2928_o;
  wire n2931_o;
  wire [2:0] n2934_o;
  wire n2936_o;
  wire n2938_o;
  wire [3:0] n2940_o;
  wire [2:0] n2942_o;
  wire n2944_o;
  wire n2946_o;
  wire n2948_o;
  wire n2950_o;
  wire n2952_o;
  wire [31:0] n2953_o;
  wire n2955_o;
  wire [30:0] n2956_o;
  wire n2958_o;
  wire n2960_o;
  wire n2962_o;
  wire [2:0] n2963_o;
  reg [3:0] n2967_o;
  reg [2:0] n2971_o;
  reg n2974_o;
  reg n2977_o;
  reg n2980_o;
  reg n2983_o;
  wire [31:0] n2984_o;
  wire n2986_o;
  wire n2989_o;
  wire [2:0] n2992_o;
  wire [3:0] n2994_o;
  wire [2:0] n2996_o;
  wire n2998_o;
  wire n3000_o;
  wire n3002_o;
  wire n3004_o;
  wire n3006_o;
  wire n3008_o;
  wire [31:0] n3009_o;
  wire n3011_o;
  wire [30:0] n3012_o;
  wire n3014_o;
  wire n3016_o;
  wire n3018_o;
  wire n3020_o;
  wire n3022_o;
  wire [4:0] n3023_o;
  reg [2:0] n3026_o;
  reg [3:0] n3030_o;
  reg n3034_o;
  reg [3:0] n3038_o;
  reg [3:0] n3042_o;
  reg [2:0] n3048_o;
  reg n3051_o;
  reg n3054_o;
  reg n3058_o;
  wire [2:0] n3061_o;
  wire [2:0] n3062_o;
  wire [3:0] n3064_o;
  wire n3066_o;
  wire [3:0] n3068_o;
  wire [3:0] n3070_o;
  wire [2:0] n3072_o;
  wire n3074_o;
  wire n3076_o;
  wire n3078_o;
  wire n3080_o;
  wire n3083_o;
  wire n3085_o;
  wire n3086_o;
  wire n3088_o;
  wire n3089_o;
  wire n3091_o;
  wire n3092_o;
  wire n3094_o;
  wire n3095_o;
  wire n3097_o;
  wire n3098_o;
  wire n3100_o;
  wire n3101_o;
  wire n3103_o;
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
  wire n3124_o;
  wire n3125_o;
  wire n3127_o;
  wire n3128_o;
  wire n3130_o;
  wire n3131_o;
  wire n3133_o;
  wire n3134_o;
  wire n3136_o;
  wire n3137_o;
  wire n3139_o;
  wire n3140_o;
  wire n3142_o;
  wire n3143_o;
  wire n3145_o;
  wire n3146_o;
  wire n3148_o;
  wire n3149_o;
  wire n3151_o;
  wire n3152_o;
  wire n3154_o;
  wire n3155_o;
  wire n3157_o;
  wire n3158_o;
  wire n3160_o;
  wire n3161_o;
  wire n3163_o;
  wire n3164_o;
  wire n3166_o;
  wire n3167_o;
  wire n3169_o;
  wire n3170_o;
  wire n3172_o;
  wire n3173_o;
  wire n3175_o;
  wire n3176_o;
  wire n3178_o;
  wire n3179_o;
  wire n3181_o;
  wire n3182_o;
  wire n3184_o;
  wire n3185_o;
  wire n3187_o;
  wire n3188_o;
  wire n3190_o;
  wire n3191_o;
  wire n3193_o;
  wire n3194_o;
  wire n3196_o;
  wire n3197_o;
  wire n3199_o;
  wire n3200_o;
  wire n3202_o;
  wire n3203_o;
  wire n3205_o;
  wire n3206_o;
  wire n3208_o;
  wire n3209_o;
  wire n3211_o;
  wire n3212_o;
  wire n3214_o;
  wire n3215_o;
  wire n3217_o;
  wire n3218_o;
  wire n3220_o;
  wire n3221_o;
  wire n3223_o;
  wire n3224_o;
  wire n3226_o;
  wire n3227_o;
  wire n3229_o;
  wire n3230_o;
  wire n3232_o;
  wire n3233_o;
  wire n3235_o;
  wire n3236_o;
  wire n3238_o;
  wire n3239_o;
  wire n3241_o;
  wire n3242_o;
  wire n3244_o;
  wire n3245_o;
  wire n3247_o;
  wire n3248_o;
  wire [30:0] n3249_o;
  wire n3251_o;
  wire n3254_o;
  wire [1:0] n3255_o;
  reg n3258_o;
  reg [2:0] n3260_o;
  reg [2:0] n3262_o;
  reg n3265_o;
  reg [2:0] n3268_o;
  wire n3270_o;
  wire n3272_o;
  wire n3273_o;
  wire n3275_o;
  wire n3276_o;
  wire n3278_o;
  wire n3279_o;
  wire n3281_o;
  wire n3282_o;
  wire n3284_o;
  wire n3285_o;
  wire n3287_o;
  wire n3288_o;
  wire n3290_o;
  wire n3291_o;
  wire n3293_o;
  wire n3297_o;
  wire n3300_o;
  wire [2:0] n3302_o;
  wire [2:0] n3304_o;
  wire n3307_o;
  wire n3309_o;
  wire n3311_o;
  wire n3312_o;
  wire n3314_o;
  wire n3315_o;
  wire n3317_o;
  wire n3318_o;
  wire n3320_o;
  wire n3321_o;
  wire n3323_o;
  wire n3324_o;
  wire n3326_o;
  wire n3327_o;
  wire n3329_o;
  wire n3330_o;
  wire n3332_o;
  wire n3334_o;
  wire n3335_o;
  wire n3337_o;
  wire n3338_o;
  wire n3340_o;
  wire n3341_o;
  wire n3343_o;
  wire n3344_o;
  wire n3346_o;
  wire n3347_o;
  wire n3349_o;
  wire n3350_o;
  wire [30:0] n3351_o;
  wire n3353_o;
  wire n3355_o;
  wire n3357_o;
  wire [2:0] n3358_o;
  reg [2:0] n3360_o;
  reg n3363_o;
  reg [2:0] n3365_o;
  reg [3:0] n3368_o;
  reg [3:0] n3370_o;
  reg n3373_o;
  reg n3376_o;
  reg [2:0] n3380_o;
  reg n3383_o;
  wire n3385_o;
  wire n3387_o;
  wire n3389_o;
  wire n3390_o;
  wire n3392_o;
  wire n3393_o;
  wire n3395_o;
  wire n3396_o;
  wire n3398_o;
  wire n3399_o;
  wire n3401_o;
  wire n3402_o;
  wire n3404_o;
  wire n3405_o;
  wire [30:0] n3406_o;
  wire n3408_o;
  wire n3410_o;
  wire n3412_o;
  wire [2:0] n3413_o;
  reg [2:0] n3415_o;
  reg n3418_o;
  reg [2:0] n3420_o;
  reg [3:0] n3423_o;
  reg [3:0] n3425_o;
  reg n3428_o;
  reg n3431_o;
  reg [2:0] n3435_o;
  reg n3438_o;
  wire n3440_o;
  wire n3443_o;
  wire n3445_o;
  wire n3447_o;
  wire n3449_o;
  wire [30:0] n3450_o;
  wire n3452_o;
  wire n3454_o;
  wire n3456_o;
  wire [2:0] n3457_o;
  reg [2:0] n3459_o;
  reg [3:0] n3463_o;
  reg [3:0] n3467_o;
  reg [2:0] n3471_o;
  reg n3475_o;
  wire [30:0] n3476_o;
  wire n3478_o;
  wire n3480_o;
  wire n3482_o;
  wire n3484_o;
  wire n3486_o;
  wire [4:0] n3487_o;
  reg [2:0] n3489_o;
  reg n3492_o;
  reg [3:0] n3496_o;
  reg [3:0] n3500_o;
  reg [2:0] n3504_o;
  reg n3507_o;
  reg n3511_o;
  reg n3515_o;
  wire [2:0] n3518_o;
  wire [2:0] n3519_o;
  wire n3521_o;
  wire [3:0] n3523_o;
  wire [3:0] n3525_o;
  wire [2:0] n3527_o;
  wire n3529_o;
  wire n3531_o;
  wire n3533_o;
  wire [2:0] n3535_o;
  wire [2:0] n3536_o;
  wire n3538_o;
  wire [3:0] n3539_o;
  wire [3:0] n3540_o;
  wire [2:0] n3541_o;
  wire n3543_o;
  wire n3545_o;
  wire n3546_o;
  wire n3548_o;
  wire n3550_o;
  wire n3552_o;
  wire n3554_o;
  wire [30:0] n3555_o;
  wire [1:0] n3557_o;
  wire [30:0] n3558_o;
  wire [1:0] n3559_o;
  wire n3562_o;
  wire n3564_o;
  wire n3565_o;
  wire n3567_o;
  wire n3568_o;
  reg n3570_o;
  reg [1:0] n3572_o;
  reg n3575_o;
  wire n3577_o;
  wire [1:0] n3579_o;
  wire [30:0] n3580_o;
  wire [1:0] n3581_o;
  wire n3583_o;
  wire n3585_o;
  wire n3586_o;
  wire n3588_o;
  wire n3589_o;
  reg n3592_o;
  reg [1:0] n3594_o;
  reg n3597_o;
  wire n3599_o;
  wire [1:0] n3600_o;
  reg [2:0] n3602_o;
  reg n3606_o;
  reg [2:0] n3608_o;
  reg n3610_o;
  reg [1:0] n3612_o;
  reg n3614_o;
  reg [3:0] n3617_o;
  reg n3621_o;
  reg n3625_o;
  reg [1:0] n3628_o;
  reg n3632_o;
  wire n3634_o;
  wire n3636_o;
  wire n3637_o;
  wire n3639_o;
  wire n3640_o;
  wire n3642_o;
  wire n3643_o;
  wire n3646_o;
  wire n3648_o;
  wire n3649_o;
  wire n3651_o;
  wire n3652_o;
  wire n3654_o;
  wire n3655_o;
  wire n3658_o;
  wire n3660_o;
  wire n3661_o;
  wire n3663_o;
  wire n3664_o;
  wire n3666_o;
  wire n3667_o;
  wire n3670_o;
  wire n3672_o;
  wire n3673_o;
  wire n3675_o;
  wire n3676_o;
  wire n3678_o;
  wire n3679_o;
  wire [30:0] n3680_o;
  wire n3682_o;
  wire n3684_o;
  wire [1:0] n3685_o;
  reg n3689_o;
  reg n3692_o;
  reg n3695_o;
  reg n3698_o;
  wire n3700_o;
  wire n3701_o;
  wire [31:0] n3702_o;
  wire n3704_o;
  wire n3705_o;
  wire [1:0] n3706_o;
  wire [30:0] n3707_o;
  wire n3709_o;
  wire n3711_o;
  wire [1:0] n3712_o;
  reg [3:0] n3715_o;
  reg [2:0] n3718_o;
  reg n3721_o;
  reg n3724_o;
  wire n3726_o;
  wire [30:0] n3727_o;
  wire n3729_o;
  wire n3731_o;
  wire n3733_o;
  wire [2:0] n3734_o;
  reg n3738_o;
  reg [3:0] n3741_o;
  reg [2:0] n3744_o;
  reg n3747_o;
  reg n3750_o;
  wire n3752_o;
  wire [30:0] n3753_o;
  wire n3755_o;
  wire n3757_o;
  wire [1:0] n3758_o;
  reg n3761_o;
  reg [2:0] n3764_o;
  reg n3767_o;
  wire n3769_o;
  wire [30:0] n3770_o;
  wire n3772_o;
  wire n3774_o;
  wire n3776_o;
  wire [2:0] n3777_o;
  reg n3781_o;
  reg n3784_o;
  reg [2:0] n3787_o;
  reg n3790_o;
  wire n3792_o;
  wire [3:0] n3793_o;
  reg [2:0] n3799_o;
  reg n3802_o;
  reg n3805_o;
  reg [3:0] n3808_o;
  reg [2:0] n3810_o;
  reg n3813_o;
  reg n3816_o;
  reg n3819_o;
  wire [30:0] n3820_o;
  wire n3822_o;
  wire [2:0] n3824_o;
  wire [31:0] n3825_o;
  wire n3831_o;
  wire n3832_o;
  wire n3833_o;
  wire n3835_o;
  wire n3836_o;
  wire n3838_o;
  wire n3839_o;
  wire n3840_o;
  wire n3842_o;
  wire n3843_o;
  wire n3845_o;
  wire n3848_o;
  wire n3851_o;
  wire n3854_o;
  wire n3857_o;
  wire [7:0] n3858_o;
  reg n3860_o;
  wire n3861_o;
  wire n3862_o;
  wire n3864_o;
  wire n3865_o;
  wire n3867_o;
  wire n3868_o;
  wire n3869_o;
  wire n3871_o;
  wire n3872_o;
  wire n3874_o;
  wire n3875_o;
  wire n3876_o;
  wire n3878_o;
  wire n3879_o;
  wire n3881_o;
  wire n3882_o;
  wire n3883_o;
  wire n3885_o;
  wire n3886_o;
  wire n3888_o;
  wire [7:0] n3889_o;
  reg n3891_o;
  wire n3892_o;
  wire n3895_o;
  wire n3897_o;
  wire [1:0] n3898_o;
  reg n3902_o;
  reg n3904_o;
  reg n3907_o;
  reg n3910_o;
  wire [2:0] n3912_o;
  wire n3913_o;
  wire n3915_o;
  wire [3:0] n3917_o;
  wire [2:0] n3919_o;
  wire n3921_o;
  wire n3923_o;
  wire n3924_o;
  wire n3926_o;
  wire n3928_o;
  wire n3930_o;
  wire n3932_o;
  wire n3933_o;
  wire n3935_o;
  wire n3936_o;
  wire n3938_o;
  wire n3939_o;
  wire n3941_o;
  wire n3942_o;
  wire n3944_o;
  wire n3945_o;
  wire n3947_o;
  wire n3948_o;
  wire n3950_o;
  wire n3951_o;
  wire [31:0] n3952_o;
  wire n3954_o;
  wire [30:0] n3955_o;
  wire n3957_o;
  wire n3959_o;
  wire [1:0] n3960_o;
  reg [2:0] n3962_o;
  reg n3965_o;
  reg n3968_o;
  reg n3971_o;
  wire [2:0] n3974_o;
  wire [2:0] n3975_o;
  wire n3977_o;
  wire n3979_o;
  wire n3981_o;
  wire n3983_o;
  wire [31:0] n3984_o;
  wire n3986_o;
  wire [30:0] n3987_o;
  wire n3988_o;
  wire n3989_o;
  wire [2:0] n3992_o;
  wire n3994_o;
  wire n3996_o;
  wire [1:0] n3997_o;
  reg [2:0] n3999_o;
  reg [2:0] n4002_o;
  reg n4005_o;
  reg n4008_o;
  reg n4011_o;
  wire [2:0] n4013_o;
  wire [2:0] n4014_o;
  wire n4016_o;
  wire n4018_o;
  wire n4020_o;
  wire n4022_o;
  wire [31:0] n4023_o;
  wire n4025_o;
  wire [30:0] n4026_o;
  wire n4027_o;
  wire [2:0] n4030_o;
  wire n4032_o;
  wire n4034_o;
  wire [1:0] n4035_o;
  reg [2:0] n4037_o;
  reg [2:0] n4040_o;
  reg n4043_o;
  reg n4046_o;
  reg n4049_o;
  wire [2:0] n4051_o;
  wire [2:0] n4052_o;
  wire n4054_o;
  wire n4056_o;
  wire n4058_o;
  wire n4060_o;
  wire [31:0] n4061_o;
  wire n4063_o;
  wire [30:0] n4064_o;
  wire n4065_o;
  wire n4066_o;
  wire [2:0] n4069_o;
  wire n4071_o;
  wire n4073_o;
  wire [1:0] n4074_o;
  reg [2:0] n4076_o;
  reg [2:0] n4079_o;
  reg n4082_o;
  reg n4085_o;
  reg n4088_o;
  wire [2:0] n4090_o;
  wire [2:0] n4091_o;
  wire n4093_o;
  wire n4095_o;
  wire n4097_o;
  wire n4099_o;
  wire [31:0] n4100_o;
  wire n4102_o;
  wire [30:0] n4103_o;
  wire n4104_o;
  wire [2:0] n4107_o;
  wire n4109_o;
  wire n4111_o;
  wire [1:0] n4112_o;
  reg [2:0] n4114_o;
  reg [2:0] n4117_o;
  reg n4120_o;
  reg n4123_o;
  reg n4126_o;
  wire [2:0] n4128_o;
  wire [2:0] n4129_o;
  wire n4131_o;
  wire n4133_o;
  wire n4135_o;
  wire n4137_o;
  wire n4139_o;
  wire [31:0] n4140_o;
  wire n4142_o;
  wire [31:0] n4143_o;
  wire n4145_o;
  wire [30:0] n4146_o;
  wire n4149_o;
  wire n4151_o;
  wire n4153_o;
  wire [2:0] n4154_o;
  reg [2:0] n4157_o;
  reg n4160_o;
  reg n4163_o;
  reg [2:0] n4165_o;
  reg [3:0] n4168_o;
  reg [3:0] n4170_o;
  reg n4173_o;
  reg n4176_o;
  reg n4180_o;
  reg n4183_o;
  wire [2:0] n4186_o;
  wire [2:0] n4187_o;
  wire n4189_o;
  wire n4191_o;
  wire [2:0] n4193_o;
  wire [3:0] n4195_o;
  wire [3:0] n4196_o;
  wire n4198_o;
  wire n4200_o;
  wire n4202_o;
  wire n4204_o;
  wire [2:0] n4206_o;
  wire [2:0] n4207_o;
  wire n4209_o;
  wire n4211_o;
  wire [2:0] n4213_o;
  wire [3:0] n4215_o;
  wire [3:0] n4216_o;
  wire n4218_o;
  wire n4220_o;
  wire n4222_o;
  wire n4224_o;
  wire n4226_o;
  wire [30:0] n4227_o;
  wire n4229_o;
  wire n4231_o;
  wire n4233_o;
  wire n4235_o;
  wire [3:0] n4236_o;
  reg [2:0] n4238_o;
  reg n4242_o;
  reg [3:0] n4246_o;
  reg [3:0] n4250_o;
  reg [2:0] n4254_o;
  reg n4257_o;
  reg n4260_o;
  reg n4263_o;
  reg n4267_o;
  wire n4269_o;
  wire n4270_o;
  wire n4271_o;
  wire [31:0] n4272_o;
  wire n4274_o;
  wire n4275_o;
  wire [30:0] n4276_o;
  wire n4278_o;
  wire [2:0] n4280_o;
  wire [31:0] n4281_o;
  wire n4287_o;
  wire n4288_o;
  wire n4289_o;
  wire n4291_o;
  wire n4292_o;
  wire n4294_o;
  wire n4295_o;
  wire n4296_o;
  wire n4298_o;
  wire n4299_o;
  wire n4301_o;
  wire n4304_o;
  wire n4307_o;
  wire n4310_o;
  wire n4313_o;
  wire [7:0] n4314_o;
  reg n4316_o;
  wire n4317_o;
  wire n4318_o;
  wire n4320_o;
  wire n4321_o;
  wire n4323_o;
  wire n4324_o;
  wire n4325_o;
  wire n4327_o;
  wire n4328_o;
  wire n4330_o;
  wire n4331_o;
  wire n4332_o;
  wire n4334_o;
  wire n4335_o;
  wire n4337_o;
  wire n4338_o;
  wire n4339_o;
  wire n4341_o;
  wire n4342_o;
  wire n4344_o;
  wire [7:0] n4345_o;
  reg n4347_o;
  wire n4348_o;
  wire [2:0] n4351_o;
  wire [2:0] n4353_o;
  wire [3:0] n4356_o;
  wire [3:0] n4359_o;
  wire [2:0] n4362_o;
  wire n4364_o;
  wire n4366_o;
  wire n4368_o;
  wire [3:0] n4369_o;
  reg [2:0] n4371_o;
  reg [2:0] n4373_o;
  reg n4377_o;
  reg [3:0] n4380_o;
  reg [3:0] n4383_o;
  reg [2:0] n4386_o;
  reg n4389_o;
  reg n4392_o;
  reg n4395_o;
  reg n4399_o;
  wire [2:0] n4401_o;
  wire [2:0] n4402_o;
  wire n4404_o;
  wire [3:0] n4406_o;
  wire [3:0] n4408_o;
  wire [2:0] n4410_o;
  wire n4412_o;
  wire n4414_o;
  wire n4416_o;
  wire n4418_o;
  wire n4420_o;
  wire n4422_o;
  wire n4423_o;
  wire n4425_o;
  wire n4426_o;
  wire n4428_o;
  wire n4429_o;
  wire n4431_o;
  wire n4432_o;
  wire n4434_o;
  wire n4435_o;
  wire n4437_o;
  wire n4438_o;
  wire n4440_o;
  wire n4441_o;
  wire [30:0] n4442_o;
  wire n4444_o;
  wire n4446_o;
  wire n4448_o;
  wire [2:0] n4449_o;
  reg [3:0] n4453_o;
  reg [2:0] n4457_o;
  reg n4460_o;
  reg n4463_o;
  wire n4465_o;
  wire n4466_o;
  wire [31:0] n4467_o;
  wire n4469_o;
  wire n4470_o;
  wire [1:0] n4471_o;
  wire [30:0] n4472_o;
  wire n4474_o;
  wire n4476_o;
  wire [1:0] n4477_o;
  reg n4480_o;
  reg [3:0] n4483_o;
  reg [2:0] n4486_o;
  reg n4489_o;
  wire n4491_o;
  wire [30:0] n4492_o;
  wire n4494_o;
  wire n4496_o;
  wire [1:0] n4497_o;
  reg n4500_o;
  reg n4504_o;
  reg [3:0] n4508_o;
  reg [3:0] n4512_o;
  reg [3:0] n4515_o;
  reg n4519_o;
  reg n4522_o;
  wire n4524_o;
  wire [30:0] n4525_o;
  wire n4527_o;
  wire n4529_o;
  wire [1:0] n4530_o;
  reg n4533_o;
  reg n4536_o;
  reg [2:0] n4539_o;
  wire n4541_o;
  wire [30:0] n4542_o;
  wire n4544_o;
  wire n4546_o;
  wire n4549_o;
  wire n4552_o;
  wire [3:0] n4553_o;
  reg n4557_o;
  reg n4560_o;
  reg n4564_o;
  reg [2:0] n4566_o;
  reg [2:0] n4570_o;
  reg n4573_o;
  reg n4576_o;
  wire n4578_o;
  wire [3:0] n4579_o;
  reg [2:0] n4585_o;
  reg n4587_o;
  reg n4590_o;
  reg n4593_o;
  reg n4596_o;
  wire [2:0] n4597_o;
  reg [2:0] n4600_o;
  wire n4601_o;
  reg n4604_o;
  reg [3:0] n4607_o;
  reg [3:0] n4609_o;
  reg n4612_o;
  reg [2:0] n4615_o;
  reg n4618_o;
  reg n4621_o;
  reg n4624_o;
  reg n4627_o;
  wire [30:0] n4628_o;
  wire [2:0] n4630_o;
  wire [31:0] n4631_o;
  wire n4637_o;
  wire n4638_o;
  wire n4639_o;
  wire n4641_o;
  wire n4642_o;
  wire n4644_o;
  wire n4645_o;
  wire n4646_o;
  wire n4648_o;
  wire n4649_o;
  wire n4651_o;
  wire n4654_o;
  wire n4657_o;
  wire n4660_o;
  wire n4663_o;
  wire [7:0] n4664_o;
  reg n4666_o;
  wire n4667_o;
  wire n4668_o;
  wire n4670_o;
  wire n4671_o;
  wire n4673_o;
  wire n4674_o;
  wire n4675_o;
  wire n4677_o;
  wire n4678_o;
  wire n4680_o;
  wire n4681_o;
  wire n4682_o;
  wire n4684_o;
  wire n4685_o;
  wire n4687_o;
  wire n4688_o;
  wire n4689_o;
  wire n4691_o;
  wire n4692_o;
  wire n4694_o;
  wire [7:0] n4695_o;
  reg n4697_o;
  wire n4698_o;
  wire [2:0] n4701_o;
  wire [2:0] n4704_o;
  wire n4706_o;
  wire n4708_o;
  wire n4710_o;
  wire [2:0] n4711_o;
  reg [2:0] n4713_o;
  reg [2:0] n4716_o;
  reg [3:0] n4720_o;
  reg [2:0] n4723_o;
  reg n4726_o;
  reg n4729_o;
  wire [2:0] n4730_o;
  wire [2:0] n4731_o;
  wire n4733_o;
  wire n4735_o;
  wire [3:0] n4737_o;
  wire n4739_o;
  wire n4741_o;
  wire [3:0] n4742_o;
  wire [3:0] n4744_o;
  wire [3:0] n4746_o;
  wire [3:0] n4747_o;
  wire n4749_o;
  wire [2:0] n4750_o;
  wire n4752_o;
  wire n4753_o;
  wire n4755_o;
  wire n4757_o;
  wire n4759_o;
  wire n4761_o;
  wire n4763_o;
  wire n4764_o;
  wire n4766_o;
  wire n4767_o;
  wire n4769_o;
  wire n4770_o;
  wire n4772_o;
  wire n4773_o;
  wire n4775_o;
  wire n4776_o;
  wire n4778_o;
  wire n4779_o;
  wire n4781_o;
  wire n4782_o;
  wire [30:0] n4783_o;
  wire n4785_o;
  wire n4787_o;
  wire n4789_o;
  wire [2:0] n4790_o;
  reg [2:0] n4792_o;
  reg [3:0] n4796_o;
  reg [3:0] n4800_o;
  reg [2:0] n4804_o;
  reg n4807_o;
  reg n4811_o;
  wire n4813_o;
  wire n4815_o;
  wire n4816_o;
  wire n4818_o;
  wire n4819_o;
  wire n4821_o;
  wire n4822_o;
  wire n4824_o;
  wire n4825_o;
  wire n4827_o;
  wire n4828_o;
  wire n4830_o;
  wire n4831_o;
  wire n4833_o;
  wire n4834_o;
  wire [31:0] n4835_o;
  wire n4837_o;
  wire [30:0] n4838_o;
  wire n4840_o;
  wire n4842_o;
  wire [1:0] n4843_o;
  reg n4846_o;
  reg n4849_o;
  reg [2:0] n4852_o;
  reg n4855_o;
  wire [2:0] n4858_o;
  wire n4860_o;
  wire n4862_o;
  wire [2:0] n4864_o;
  wire n4866_o;
  wire n4868_o;
  wire [31:0] n4869_o;
  wire n4871_o;
  wire [30:0] n4872_o;
  wire n4874_o;
  wire n4876_o;
  wire [1:0] n4877_o;
  reg n4880_o;
  reg [3:0] n4883_o;
  reg [2:0] n4886_o;
  reg n4889_o;
  reg n4892_o;
  wire [2:0] n4895_o;
  wire n4897_o;
  wire [3:0] n4899_o;
  wire [2:0] n4901_o;
  wire n4903_o;
  wire n4905_o;
  wire n4907_o;
  wire [31:0] n4908_o;
  wire n4910_o;
  wire [1:0] n4913_o;
  wire n4915_o;
  wire [31:0] n4916_o;
  wire n4918_o;
  wire [1:0] n4921_o;
  wire n4923_o;
  wire [31:0] n4924_o;
  wire n4926_o;
  wire [1:0] n4929_o;
  wire n4931_o;
  wire n4933_o;
  wire n4934_o;
  wire [58:0] n4935_o;
  reg [2:0] n4958_o;
  reg [2:0] n4963_o;
  reg [1:0] n4966_o;
  reg n4969_o;
  reg n4972_o;
  wire [1:0] n4973_o;
  wire [1:0] n4974_o;
  wire [1:0] n4975_o;
  wire [1:0] n4976_o;
  wire [1:0] n4977_o;
  wire [1:0] n4978_o;
  wire [1:0] n4979_o;
  wire [1:0] n4980_o;
  wire [1:0] n4981_o;
  wire [1:0] n4982_o;
  wire [1:0] n4983_o;
  wire [1:0] n4984_o;
  wire [1:0] n4985_o;
  wire [1:0] n4986_o;
  reg [1:0] n4989_o;
  wire [1:0] n4990_o;
  wire [1:0] n4991_o;
  wire [1:0] n4992_o;
  wire [1:0] n4993_o;
  wire [1:0] n4994_o;
  wire [1:0] n4995_o;
  wire [1:0] n4996_o;
  wire [1:0] n4997_o;
  wire [1:0] n4998_o;
  wire [1:0] n4999_o;
  wire [1:0] n5000_o;
  wire [1:0] n5001_o;
  wire [1:0] n5002_o;
  wire [1:0] n5003_o;
  reg [1:0] n5006_o;
  reg n5015_o;
  reg n5018_o;
  wire [2:0] n5019_o;
  wire [2:0] n5020_o;
  reg [2:0] n5023_o;
  wire n5024_o;
  wire n5025_o;
  reg n5028_o;
  wire n5029_o;
  wire n5030_o;
  wire n5031_o;
  wire n5032_o;
  wire n5033_o;
  wire n5034_o;
  wire n5035_o;
  wire n5036_o;
  wire n5037_o;
  wire n5038_o;
  wire n5039_o;
  wire n5040_o;
  wire n5041_o;
  wire n5043_o;
  wire n5045_o;
  wire n5046_o;
  wire n5047_o;
  wire n5048_o;
  wire n5049_o;
  wire n5050_o;
  wire n5051_o;
  wire n5052_o;
  wire n5053_o;
  reg n5056_o;
  wire [1:0] n5057_o;
  wire [1:0] n5058_o;
  wire [1:0] n5059_o;
  wire [1:0] n5060_o;
  wire [1:0] n5061_o;
  wire [1:0] n5062_o;
  wire [1:0] n5063_o;
  wire [1:0] n5064_o;
  wire [1:0] n5065_o;
  wire [1:0] n5066_o;
  wire [1:0] n5067_o;
  wire [1:0] n5068_o;
  wire [1:0] n5069_o;
  wire [1:0] n5071_o;
  wire [1:0] n5073_o;
  wire [1:0] n5074_o;
  wire [1:0] n5075_o;
  wire [1:0] n5076_o;
  wire [1:0] n5077_o;
  wire [1:0] n5078_o;
  wire [1:0] n5079_o;
  wire [1:0] n5080_o;
  wire [1:0] n5081_o;
  reg [1:0] n5084_o;
  wire n5085_o;
  wire n5086_o;
  wire n5087_o;
  wire n5088_o;
  wire n5089_o;
  wire n5090_o;
  wire n5091_o;
  wire n5093_o;
  wire n5095_o;
  wire n5096_o;
  wire n5097_o;
  wire n5098_o;
  wire n5099_o;
  wire n5100_o;
  wire n5101_o;
  wire n5102_o;
  wire n5103_o;
  reg n5106_o;
  reg [3:0] n5112_o;
  reg n5120_o;
  reg n5125_o;
  reg n5128_o;
  reg [2:0] n5131_o;
  reg n5134_o;
  reg n5137_o;
  reg n5140_o;
  reg n5144_o;
  reg n5147_o;
  reg n5150_o;
  reg n5153_o;
  reg n5156_o;
  reg n5160_o;
  reg n5163_o;
  reg n5167_o;
  reg n5170_o;
  reg n5173_o;
  reg n5176_o;
  reg n5180_o;
  reg n5184_o;
  reg n5188_o;
  reg n5191_o;
  reg [1:0] n5194_o;
  reg n5198_o;
  reg n5202_o;
  reg n5206_o;
  reg n5209_o;
  reg n5212_o;
  wire n5214_o;
  wire [2:0] n5215_o;
  wire [2:0] n5216_o;
  wire n5218_o;
  wire n5220_o;
  wire n5223_o;
  wire [3:0] n5225_o;
  wire n5228_o;
  wire [30:0] n5229_o;
  wire n5231_o;
  wire n5233_o;
  wire n5234_o;
  wire n5236_o;
  wire n5238_o;
  wire [2:0] n5239_o;
  reg [2:0] n5241_o;
  reg n5244_o;
  reg [3:0] n5246_o;
  reg n5249_o;
  reg [2:0] n5253_o;
  reg n5256_o;
  wire [2:0] n5259_o;
  wire [2:0] n5260_o;
  wire n5261_o;
  wire [3:0] n5262_o;
  wire n5263_o;
  wire [2:0] n5265_o;
  wire n5267_o;
  wire n5270_o;
  wire n5272_o;
  wire n5274_o;
  wire n5275_o;
  wire n5277_o;
  wire n5278_o;
  wire n5280_o;
  wire n5281_o;
  wire n5283_o;
  wire n5284_o;
  wire n5286_o;
  wire n5287_o;
  wire n5289_o;
  wire n5290_o;
  wire n5292_o;
  wire n5293_o;
  wire n5295_o;
  wire n5296_o;
  wire n5298_o;
  wire n5299_o;
  wire n5301_o;
  wire n5302_o;
  wire n5304_o;
  wire n5305_o;
  wire n5307_o;
  wire n5308_o;
  wire n5310_o;
  wire n5311_o;
  wire n5313_o;
  wire n5314_o;
  wire n5316_o;
  wire n5317_o;
  wire n5319_o;
  wire n5320_o;
  wire n5322_o;
  wire n5323_o;
  wire n5325_o;
  wire n5326_o;
  wire n5328_o;
  wire n5329_o;
  wire n5331_o;
  wire n5332_o;
  wire n5334_o;
  wire n5335_o;
  wire n5337_o;
  wire n5338_o;
  wire n5340_o;
  wire n5341_o;
  wire n5343_o;
  wire n5344_o;
  wire n5346_o;
  wire n5347_o;
  wire n5349_o;
  wire n5350_o;
  wire n5352_o;
  wire n5353_o;
  wire n5355_o;
  wire n5356_o;
  wire n5358_o;
  wire n5359_o;
  wire n5361_o;
  wire n5362_o;
  wire n5364_o;
  wire n5365_o;
  wire n5367_o;
  wire n5368_o;
  wire n5370_o;
  wire n5371_o;
  wire n5373_o;
  wire n5374_o;
  wire n5376_o;
  wire n5377_o;
  wire n5379_o;
  wire n5380_o;
  wire n5382_o;
  wire n5383_o;
  wire n5385_o;
  wire n5386_o;
  wire n5388_o;
  wire n5389_o;
  wire n5391_o;
  wire n5392_o;
  wire n5394_o;
  wire n5395_o;
  wire n5397_o;
  wire n5398_o;
  wire n5400_o;
  wire n5401_o;
  wire n5403_o;
  wire n5404_o;
  wire n5406_o;
  wire n5407_o;
  wire n5409_o;
  wire n5410_o;
  wire n5412_o;
  wire n5413_o;
  wire n5415_o;
  wire n5416_o;
  wire n5418_o;
  wire n5419_o;
  wire n5421_o;
  wire n5422_o;
  wire n5424_o;
  wire n5425_o;
  wire n5427_o;
  wire n5428_o;
  wire n5430_o;
  wire n5431_o;
  wire n5433_o;
  wire n5434_o;
  wire n5436_o;
  wire n5437_o;
  wire [30:0] n5438_o;
  wire n5440_o;
  wire n5442_o;
  wire n5443_o;
  wire n5445_o;
  wire n5447_o;
  wire [2:0] n5448_o;
  reg [2:0] n5450_o;
  reg n5453_o;
  reg [3:0] n5455_o;
  reg n5458_o;
  reg [2:0] n5462_o;
  reg n5465_o;
  wire n5467_o;
  wire n5469_o;
  wire n5470_o;
  wire n5472_o;
  wire n5473_o;
  wire n5475_o;
  wire n5476_o;
  wire n5478_o;
  wire n5479_o;
  wire n5481_o;
  wire n5482_o;
  wire n5484_o;
  wire n5485_o;
  wire n5487_o;
  wire n5488_o;
  wire n5490_o;
  wire n5492_o;
  wire [2:0] n5493_o;
  wire [2:0] n5494_o;
  wire [3:0] n5496_o;
  wire [30:0] n5497_o;
  wire n5499_o;
  wire n5501_o;
  wire n5502_o;
  wire n5504_o;
  wire [1:0] n5505_o;
  reg [2:0] n5507_o;
  reg [3:0] n5509_o;
  reg [2:0] n5512_o;
  wire [2:0] n5515_o;
  wire [2:0] n5516_o;
  wire n5517_o;
  wire [3:0] n5518_o;
  wire [2:0] n5520_o;
  wire n5523_o;
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
  wire [30:0] n5691_o;
  wire n5693_o;
  wire n5695_o;
  wire n5696_o;
  wire n5698_o;
  wire [1:0] n5699_o;
  reg [2:0] n5701_o;
  reg [3:0] n5703_o;
  reg [2:0] n5706_o;
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
  wire n5733_o;
  wire n5736_o;
  wire [3:0] n5738_o;
  wire n5741_o;
  wire [30:0] n5742_o;
  wire n5744_o;
  wire n5746_o;
  wire n5747_o;
  wire n5749_o;
  wire n5751_o;
  wire [2:0] n5752_o;
  reg [2:0] n5754_o;
  reg n5757_o;
  reg [3:0] n5759_o;
  reg n5762_o;
  reg [2:0] n5766_o;
  reg n5769_o;
  wire [2:0] n5772_o;
  wire [2:0] n5773_o;
  wire n5774_o;
  wire [3:0] n5775_o;
  wire n5776_o;
  wire [2:0] n5778_o;
  wire n5780_o;
  wire n5783_o;
  wire n5785_o;
  wire n5787_o;
  wire n5788_o;
  wire n5790_o;
  wire n5791_o;
  wire n5793_o;
  wire n5794_o;
  wire n5796_o;
  wire n5797_o;
  wire n5799_o;
  wire n5800_o;
  wire n5802_o;
  wire n5803_o;
  wire n5805_o;
  wire n5806_o;
  wire n5808_o;
  wire n5809_o;
  wire n5811_o;
  wire n5812_o;
  wire n5814_o;
  wire n5815_o;
  wire n5817_o;
  wire n5818_o;
  wire n5820_o;
  wire n5821_o;
  wire n5823_o;
  wire n5824_o;
  wire n5826_o;
  wire n5827_o;
  wire n5829_o;
  wire n5830_o;
  wire n5832_o;
  wire n5833_o;
  wire n5835_o;
  wire n5836_o;
  wire n5838_o;
  wire n5839_o;
  wire n5841_o;
  wire n5842_o;
  wire n5844_o;
  wire n5845_o;
  wire n5847_o;
  wire n5848_o;
  wire n5850_o;
  wire n5851_o;
  wire n5853_o;
  wire n5854_o;
  wire n5856_o;
  wire n5857_o;
  wire n5859_o;
  wire n5860_o;
  wire n5862_o;
  wire n5863_o;
  wire n5865_o;
  wire n5866_o;
  wire n5868_o;
  wire n5869_o;
  wire n5871_o;
  wire n5872_o;
  wire n5874_o;
  wire n5875_o;
  wire n5877_o;
  wire n5878_o;
  wire n5880_o;
  wire n5881_o;
  wire n5883_o;
  wire n5884_o;
  wire n5886_o;
  wire n5887_o;
  wire n5889_o;
  wire n5890_o;
  wire n5892_o;
  wire n5893_o;
  wire n5895_o;
  wire n5896_o;
  wire n5898_o;
  wire n5899_o;
  wire n5901_o;
  wire n5902_o;
  wire n5904_o;
  wire n5905_o;
  wire n5907_o;
  wire n5908_o;
  wire n5910_o;
  wire n5911_o;
  wire n5913_o;
  wire n5914_o;
  wire n5916_o;
  wire n5917_o;
  wire n5919_o;
  wire n5920_o;
  wire n5922_o;
  wire n5923_o;
  wire n5925_o;
  wire n5926_o;
  wire n5928_o;
  wire n5929_o;
  wire n5931_o;
  wire n5932_o;
  wire n5934_o;
  wire n5935_o;
  wire n5937_o;
  wire n5938_o;
  wire n5940_o;
  wire n5941_o;
  wire n5943_o;
  wire n5944_o;
  wire n5946_o;
  wire n5947_o;
  wire n5949_o;
  wire n5950_o;
  wire [30:0] n5951_o;
  wire n5953_o;
  wire n5955_o;
  wire n5956_o;
  wire n5958_o;
  wire n5960_o;
  wire [2:0] n5961_o;
  reg [2:0] n5963_o;
  reg n5966_o;
  reg [3:0] n5968_o;
  reg n5971_o;
  reg [2:0] n5975_o;
  reg n5978_o;
  wire n5980_o;
  wire n5982_o;
  wire n5983_o;
  wire n5985_o;
  wire n5986_o;
  wire n5988_o;
  wire n5989_o;
  wire n5991_o;
  wire n5992_o;
  wire n5994_o;
  wire n5995_o;
  wire n5997_o;
  wire n5998_o;
  wire n6000_o;
  wire n6001_o;
  wire n6003_o;
  wire n6005_o;
  wire n6008_o;
  wire [3:0] n6010_o;
  wire n6013_o;
  wire [30:0] n6014_o;
  wire n6016_o;
  wire n6018_o;
  wire n6019_o;
  wire n6021_o;
  wire n6023_o;
  wire [2:0] n6024_o;
  reg [2:0] n6026_o;
  reg n6029_o;
  reg [3:0] n6031_o;
  reg n6034_o;
  reg [2:0] n6038_o;
  reg n6041_o;
  wire [2:0] n6044_o;
  wire [2:0] n6045_o;
  wire n6046_o;
  wire [3:0] n6047_o;
  wire n6048_o;
  wire [2:0] n6050_o;
  wire n6052_o;
  wire n6055_o;
  wire n6057_o;
  wire n6059_o;
  wire n6060_o;
  wire n6062_o;
  wire n6063_o;
  wire n6065_o;
  wire n6066_o;
  wire n6068_o;
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
  wire n6093_o;
  wire n6095_o;
  wire n6096_o;
  wire n6098_o;
  wire n6099_o;
  wire n6101_o;
  wire n6102_o;
  wire n6104_o;
  wire n6105_o;
  wire n6107_o;
  wire n6108_o;
  wire n6110_o;
  wire n6111_o;
  wire n6113_o;
  wire n6114_o;
  wire n6116_o;
  wire n6117_o;
  wire n6119_o;
  wire n6120_o;
  wire n6122_o;
  wire n6123_o;
  wire n6125_o;
  wire n6126_o;
  wire n6128_o;
  wire n6129_o;
  wire n6131_o;
  wire n6132_o;
  wire n6134_o;
  wire n6135_o;
  wire n6137_o;
  wire n6138_o;
  wire n6140_o;
  wire n6141_o;
  wire n6143_o;
  wire n6144_o;
  wire n6146_o;
  wire n6147_o;
  wire n6149_o;
  wire n6150_o;
  wire n6152_o;
  wire n6153_o;
  wire n6155_o;
  wire n6156_o;
  wire n6158_o;
  wire n6159_o;
  wire n6161_o;
  wire n6162_o;
  wire n6164_o;
  wire n6165_o;
  wire n6167_o;
  wire n6168_o;
  wire n6170_o;
  wire n6171_o;
  wire n6173_o;
  wire n6174_o;
  wire n6176_o;
  wire n6177_o;
  wire n6179_o;
  wire n6180_o;
  wire n6182_o;
  wire n6183_o;
  wire n6185_o;
  wire n6186_o;
  wire n6188_o;
  wire n6189_o;
  wire n6191_o;
  wire n6192_o;
  wire n6194_o;
  wire n6195_o;
  wire n6197_o;
  wire n6198_o;
  wire n6200_o;
  wire n6201_o;
  wire n6203_o;
  wire n6204_o;
  wire n6206_o;
  wire n6207_o;
  wire n6209_o;
  wire n6210_o;
  wire n6212_o;
  wire n6213_o;
  wire n6215_o;
  wire n6216_o;
  wire n6218_o;
  wire n6219_o;
  wire n6221_o;
  wire n6222_o;
  wire [30:0] n6223_o;
  wire n6225_o;
  wire n6227_o;
  wire n6228_o;
  wire n6230_o;
  wire n6232_o;
  wire [2:0] n6233_o;
  reg [2:0] n6235_o;
  reg n6238_o;
  reg [3:0] n6240_o;
  reg n6243_o;
  reg [2:0] n6247_o;
  reg n6250_o;
  wire n6252_o;
  wire n6254_o;
  wire n6255_o;
  wire n6257_o;
  wire n6258_o;
  wire n6260_o;
  wire n6261_o;
  wire n6263_o;
  wire n6264_o;
  wire n6266_o;
  wire n6267_o;
  wire n6269_o;
  wire n6270_o;
  wire n6272_o;
  wire n6273_o;
  wire [7:0] n6274_o;
  reg [2:0] n6280_o;
  reg [2:0] n6282_o;
  reg n6285_o;
  reg [2:0] n6287_o;
  reg [3:0] n6289_o;
  reg n6292_o;
  reg [2:0] n6294_o;
  reg n6297_o;
  reg n6300_o;
  wire n6302_o;
  wire n6304_o;
  wire n6306_o;
  wire n6307_o;
  wire n6309_o;
  wire n6310_o;
  wire n6312_o;
  wire n6313_o;
  wire n6315_o;
  wire n6316_o;
  wire n6318_o;
  wire n6319_o;
  wire n6321_o;
  wire n6322_o;
  wire n6324_o;
  wire n6325_o;
  wire n6327_o;
  wire n6328_o;
  wire n6330_o;
  wire n6331_o;
  wire n6333_o;
  wire n6334_o;
  wire n6336_o;
  wire n6337_o;
  wire n6339_o;
  wire n6340_o;
  wire n6342_o;
  wire n6343_o;
  wire n6345_o;
  wire n6346_o;
  wire n6348_o;
  wire n6349_o;
  wire n6351_o;
  wire n6352_o;
  wire n6354_o;
  wire n6355_o;
  wire n6357_o;
  wire n6358_o;
  wire n6360_o;
  wire n6361_o;
  wire n6363_o;
  wire n6364_o;
  wire n6366_o;
  wire n6367_o;
  wire n6369_o;
  wire n6370_o;
  wire n6372_o;
  wire n6373_o;
  wire n6375_o;
  wire n6376_o;
  wire n6378_o;
  wire n6379_o;
  wire n6381_o;
  wire n6382_o;
  wire n6384_o;
  wire n6385_o;
  wire n6387_o;
  wire n6388_o;
  wire n6390_o;
  wire n6391_o;
  wire n6393_o;
  wire n6394_o;
  wire n6396_o;
  wire n6397_o;
  wire n6399_o;
  wire n6400_o;
  wire n6402_o;
  wire n6403_o;
  wire n6405_o;
  wire n6406_o;
  wire n6408_o;
  wire n6409_o;
  wire n6411_o;
  wire n6412_o;
  wire n6414_o;
  wire n6415_o;
  wire n6417_o;
  wire n6418_o;
  wire n6420_o;
  wire n6421_o;
  wire n6423_o;
  wire n6424_o;
  wire n6426_o;
  wire n6427_o;
  wire n6429_o;
  wire n6430_o;
  wire n6432_o;
  wire n6433_o;
  wire n6435_o;
  wire n6436_o;
  wire n6438_o;
  wire n6439_o;
  wire n6441_o;
  wire n6442_o;
  wire n6444_o;
  wire n6445_o;
  wire n6447_o;
  wire n6448_o;
  wire n6450_o;
  wire n6451_o;
  wire n6453_o;
  wire n6454_o;
  wire n6456_o;
  wire n6457_o;
  wire n6459_o;
  wire n6460_o;
  wire n6462_o;
  wire n6463_o;
  wire n6465_o;
  wire n6466_o;
  wire n6468_o;
  wire n6469_o;
  wire n6471_o;
  wire n6472_o;
  wire n6474_o;
  wire n6475_o;
  wire n6477_o;
  wire n6478_o;
  wire n6480_o;
  wire n6481_o;
  wire n6483_o;
  wire n6484_o;
  wire n6486_o;
  wire n6487_o;
  wire n6489_o;
  wire n6490_o;
  wire n6492_o;
  wire n6493_o;
  wire n6495_o;
  wire n6496_o;
  wire n6498_o;
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
  wire n6522_o;
  wire n6523_o;
  wire n6525_o;
  wire n6526_o;
  wire n6528_o;
  wire n6529_o;
  wire n6531_o;
  wire n6532_o;
  wire n6534_o;
  wire n6535_o;
  wire n6537_o;
  wire n6538_o;
  wire n6540_o;
  wire n6541_o;
  wire n6543_o;
  wire n6544_o;
  wire n6546_o;
  wire n6547_o;
  wire n6549_o;
  wire n6550_o;
  wire n6552_o;
  wire n6553_o;
  wire n6555_o;
  wire n6556_o;
  wire n6558_o;
  wire n6559_o;
  wire n6561_o;
  wire n6562_o;
  wire n6564_o;
  wire n6565_o;
  wire n6567_o;
  wire n6568_o;
  wire n6570_o;
  wire n6571_o;
  wire n6573_o;
  wire n6574_o;
  wire n6576_o;
  wire n6577_o;
  wire n6579_o;
  wire n6580_o;
  wire n6582_o;
  wire n6583_o;
  wire n6585_o;
  wire n6586_o;
  wire n6588_o;
  wire n6589_o;
  wire n6591_o;
  wire n6592_o;
  wire n6594_o;
  wire n6595_o;
  wire n6597_o;
  wire n6598_o;
  wire n6600_o;
  wire n6601_o;
  wire n6603_o;
  wire n6604_o;
  wire n6606_o;
  wire n6607_o;
  wire n6609_o;
  wire n6610_o;
  wire n6612_o;
  wire n6613_o;
  wire n6615_o;
  wire n6616_o;
  wire n6618_o;
  wire n6619_o;
  wire n6621_o;
  wire n6622_o;
  wire n6624_o;
  wire n6625_o;
  wire n6627_o;
  wire n6628_o;
  wire n6630_o;
  wire n6631_o;
  wire n6633_o;
  wire n6634_o;
  wire n6636_o;
  wire n6637_o;
  wire n6639_o;
  wire n6640_o;
  wire n6642_o;
  wire n6643_o;
  wire n6645_o;
  wire n6646_o;
  wire n6648_o;
  wire n6649_o;
  wire n6651_o;
  wire n6652_o;
  wire n6654_o;
  wire n6655_o;
  wire n6657_o;
  wire n6658_o;
  wire n6660_o;
  wire n6661_o;
  wire n6663_o;
  wire n6664_o;
  wire n6666_o;
  wire n6667_o;
  wire n6669_o;
  wire n6670_o;
  wire n6672_o;
  wire n6673_o;
  wire n6675_o;
  wire n6676_o;
  wire n6678_o;
  wire n6679_o;
  wire n6681_o;
  wire n6682_o;
  wire n6684_o;
  wire n6685_o;
  wire n6687_o;
  wire n6688_o;
  wire n6690_o;
  wire n6691_o;
  wire n6693_o;
  wire n6694_o;
  wire n6696_o;
  wire n6697_o;
  wire n6699_o;
  wire n6700_o;
  wire n6702_o;
  wire n6703_o;
  wire n6705_o;
  wire n6706_o;
  wire n6708_o;
  wire n6709_o;
  wire n6711_o;
  wire n6712_o;
  wire n6714_o;
  wire n6715_o;
  wire n6717_o;
  wire n6718_o;
  wire n6720_o;
  wire n6721_o;
  wire n6723_o;
  wire n6724_o;
  wire n6726_o;
  wire n6727_o;
  wire n6729_o;
  wire n6730_o;
  wire n6732_o;
  wire n6733_o;
  wire n6735_o;
  wire n6736_o;
  wire n6738_o;
  wire n6739_o;
  wire n6741_o;
  wire n6742_o;
  wire n6744_o;
  wire n6745_o;
  wire n6747_o;
  wire n6748_o;
  wire n6750_o;
  wire n6751_o;
  wire n6753_o;
  wire n6754_o;
  wire n6756_o;
  wire n6757_o;
  wire n6759_o;
  wire n6760_o;
  wire n6762_o;
  wire n6763_o;
  wire n6765_o;
  wire n6766_o;
  wire n6768_o;
  wire n6769_o;
  wire n6771_o;
  wire n6772_o;
  wire n6774_o;
  wire n6775_o;
  wire n6777_o;
  wire n6778_o;
  wire n6780_o;
  wire n6781_o;
  wire n6783_o;
  wire n6784_o;
  wire n6786_o;
  wire n6787_o;
  wire n6789_o;
  wire n6790_o;
  wire n6792_o;
  wire n6793_o;
  wire n6795_o;
  wire n6796_o;
  wire n6798_o;
  wire n6799_o;
  wire n6801_o;
  wire n6802_o;
  wire n6804_o;
  wire n6805_o;
  wire n6807_o;
  wire n6808_o;
  wire n6810_o;
  wire n6811_o;
  wire n6813_o;
  wire n6814_o;
  wire n6816_o;
  wire n6817_o;
  wire n6819_o;
  wire n6820_o;
  wire n6822_o;
  wire n6823_o;
  wire n6825_o;
  wire n6826_o;
  wire n6828_o;
  wire n6829_o;
  wire n6831_o;
  wire n6833_o;
  wire n6834_o;
  wire n6836_o;
  wire n6838_o;
  wire n6840_o;
  wire n6842_o;
  wire [30:0] n6843_o;
  wire n6845_o;
  wire n6847_o;
  wire [1:0] n6848_o;
  wire n6850_o;
  wire [1:0] n6851_o;
  wire [2:0] n6853_o;
  wire [2:0] n6855_o;
  wire n6858_o;
  wire n6860_o;
  wire [1:0] n6861_o;
  wire n6863_o;
  wire [1:0] n6864_o;
  wire [2:0] n6866_o;
  wire [2:0] n6868_o;
  wire n6871_o;
  wire n6873_o;
  wire [3:0] n6874_o;
  reg n6878_o;
  reg n6881_o;
  reg n6885_o;
  reg [2:0] n6887_o;
  reg n6889_o;
  reg [2:0] n6893_o;
  reg n6896_o;
  reg n6899_o;
  wire n6901_o;
  wire n6903_o;
  wire n6904_o;
  wire n6906_o;
  wire n6907_o;
  wire n6909_o;
  wire n6910_o;
  wire [30:0] n6911_o;
  wire n6913_o;
  wire [1:0] n6914_o;
  wire n6916_o;
  wire [1:0] n6917_o;
  wire [3:0] n6920_o;
  wire [3:0] n6922_o;
  wire n6924_o;
  wire [1:0] n6925_o;
  wire n6927_o;
  wire [1:0] n6928_o;
  wire [3:0] n6931_o;
  wire [3:0] n6933_o;
  wire n6935_o;
  wire n6937_o;
  wire [3:0] n6938_o;
  reg n6942_o;
  reg n6945_o;
  reg [3:0] n6947_o;
  reg [2:0] n6951_o;
  reg n6954_o;
  reg n6957_o;
  reg n6961_o;
  wire n6963_o;
  wire n6965_o;
  wire n6966_o;
  wire n6968_o;
  wire n6969_o;
  wire n6971_o;
  wire n6972_o;
  wire [30:0] n6973_o;
  wire n6975_o;
  wire n6977_o;
  wire n6978_o;
  wire [3:0] n6981_o;
  wire n6983_o;
  wire n6984_o;
  wire n6985_o;
  wire [3:0] n6988_o;
  wire n6990_o;
  wire n6992_o;
  wire [3:0] n6993_o;
  reg [2:0] n6996_o;
  reg [3:0] n6999_o;
  reg [2:0] n7001_o;
  reg [3:0] n7004_o;
  reg [3:0] n7006_o;
  reg [2:0] n7010_o;
  reg n7013_o;
  reg n7016_o;
  reg n7019_o;
  wire n7021_o;
  wire n7023_o;
  wire n7024_o;
  wire n7026_o;
  wire n7027_o;
  wire n7029_o;
  wire n7030_o;
  wire [30:0] n7031_o;
  wire n7033_o;
  wire n7035_o;
  wire n7036_o;
  wire [3:0] n7039_o;
  wire n7041_o;
  wire n7043_o;
  wire n7045_o;
  wire [3:0] n7046_o;
  reg [2:0] n7049_o;
  reg [3:0] n7052_o;
  reg [2:0] n7054_o;
  reg [3:0] n7057_o;
  reg [3:0] n7059_o;
  reg n7062_o;
  reg n7065_o;
  reg [2:0] n7068_o;
  reg n7071_o;
  reg n7075_o;
  wire n7077_o;
  wire n7079_o;
  wire n7080_o;
  wire n7082_o;
  wire n7083_o;
  wire n7085_o;
  wire n7086_o;
  wire n7088_o;
  wire n7090_o;
  wire n7091_o;
  wire n7093_o;
  wire n7094_o;
  wire n7096_o;
  wire n7097_o;
  wire n7099_o;
  wire n7100_o;
  wire n7102_o;
  wire n7103_o;
  wire n7105_o;
  wire n7106_o;
  wire n7108_o;
  wire n7109_o;
  wire n7111_o;
  wire n7113_o;
  wire n7114_o;
  wire n7116_o;
  wire n7117_o;
  wire n7119_o;
  wire n7120_o;
  wire n7122_o;
  wire n7124_o;
  wire n7125_o;
  wire n7127_o;
  wire n7129_o;
  wire n7130_o;
  wire [30:0] n7131_o;
  wire [1:0] n7133_o;
  wire [30:0] n7134_o;
  wire [1:0] n7135_o;
  wire n7138_o;
  wire n7140_o;
  wire n7141_o;
  wire n7143_o;
  wire n7144_o;
  reg n7146_o;
  reg [1:0] n7148_o;
  reg n7151_o;
  wire n7153_o;
  wire [1:0] n7155_o;
  wire [30:0] n7156_o;
  wire [1:0] n7157_o;
  wire n7160_o;
  wire n7162_o;
  wire n7163_o;
  wire n7165_o;
  wire n7166_o;
  reg n7168_o;
  reg [1:0] n7170_o;
  reg n7173_o;
  wire n7175_o;
  wire [1:0] n7176_o;
  reg [2:0] n7178_o;
  reg n7182_o;
  reg [2:0] n7184_o;
  reg n7186_o;
  reg [1:0] n7188_o;
  reg n7190_o;
  reg [3:0] n7193_o;
  reg n7197_o;
  reg [1:0] n7200_o;
  reg n7204_o;
  wire n7206_o;
  wire n7208_o;
  wire n7209_o;
  wire n7211_o;
  wire n7212_o;
  wire n7214_o;
  wire n7215_o;
  wire [30:0] n7216_o;
  wire [1:0] n7218_o;
  wire [30:0] n7219_o;
  wire [1:0] n7220_o;
  wire n7223_o;
  wire n7225_o;
  wire n7226_o;
  wire n7228_o;
  wire n7229_o;
  reg n7231_o;
  reg [1:0] n7233_o;
  reg n7236_o;
  wire n7238_o;
  wire [1:0] n7240_o;
  wire [30:0] n7241_o;
  wire [1:0] n7242_o;
  wire n7244_o;
  wire n7246_o;
  wire n7247_o;
  wire n7249_o;
  wire n7250_o;
  reg n7253_o;
  reg [1:0] n7255_o;
  reg n7258_o;
  wire n7260_o;
  wire [1:0] n7261_o;
  reg [2:0] n7263_o;
  reg n7267_o;
  reg [2:0] n7269_o;
  reg n7271_o;
  reg [1:0] n7273_o;
  reg n7275_o;
  reg [3:0] n7278_o;
  reg n7282_o;
  reg [1:0] n7285_o;
  reg n7289_o;
  wire n7291_o;
  wire n7293_o;
  wire n7294_o;
  wire n7296_o;
  wire n7297_o;
  wire n7299_o;
  wire n7300_o;
  wire [30:0] n7301_o;
  wire n7303_o;
  wire n7307_o;
  wire n7309_o;
  wire n7311_o;
  wire [3:0] n7312_o;
  reg [2:0] n7314_o;
  reg n7317_o;
  reg [2:0] n7319_o;
  reg [2:0] n7321_o;
  reg [3:0] n7323_o;
  reg n7326_o;
  reg [2:0] n7330_o;
  reg n7333_o;
  reg n7336_o;
  reg n7339_o;
  wire n7341_o;
  wire [30:0] n7342_o;
  wire n7344_o;
  wire n7348_o;
  wire n7350_o;
  wire n7352_o;
  wire [3:0] n7353_o;
  reg [2:0] n7355_o;
  reg n7358_o;
  reg [2:0] n7360_o;
  reg [2:0] n7362_o;
  reg [3:0] n7364_o;
  reg n7367_o;
  reg [2:0] n7371_o;
  reg n7374_o;
  reg n7377_o;
  reg n7380_o;
  wire n7382_o;
  wire [30:0] n7383_o;
  wire n7385_o;
  wire n7387_o;
  wire n7389_o;
  wire [2:0] n7390_o;
  reg [3:0] n7394_o;
  reg [2:0] n7398_o;
  reg n7401_o;
  reg n7404_o;
  reg n7407_o;
  reg n7410_o;
  wire n7412_o;
  wire n7414_o;
  wire n7415_o;
  wire n7417_o;
  wire n7418_o;
  wire n7420_o;
  wire n7421_o;
  wire n7423_o;
  wire n7424_o;
  wire n7426_o;
  wire n7427_o;
  wire n7429_o;
  wire n7430_o;
  wire n7432_o;
  wire n7433_o;
  wire [30:0] n7434_o;
  wire n7436_o;
  wire [2:0] n7437_o;
  wire n7439_o;
  wire [2:0] n7440_o;
  wire n7443_o;
  wire [2:0] n7445_o;
  wire n7447_o;
  wire [1:0] n7448_o;
  reg n7450_o;
  reg [2:0] n7452_o;
  reg [2:0] n7455_o;
  reg n7458_o;
  reg n7461_o;
  reg [1:0] n7464_o;
  wire n7466_o;
  wire n7468_o;
  wire n7469_o;
  wire n7471_o;
  wire n7472_o;
  wire n7474_o;
  wire n7475_o;
  wire n7477_o;
  wire n7478_o;
  wire n7480_o;
  wire n7481_o;
  wire n7483_o;
  wire n7484_o;
  wire n7486_o;
  wire n7487_o;
  wire [30:0] n7488_o;
  wire [2:0] n7489_o;
  wire [2:0] n7490_o;
  wire n7492_o;
  wire n7495_o;
  wire n7497_o;
  wire n7499_o;
  wire [1:0] n7500_o;
  reg [2:0] n7502_o;
  reg n7504_o;
  reg [2:0] n7507_o;
  reg n7510_o;
  reg [1:0] n7513_o;
  reg n7516_o;
  wire n7518_o;
  wire n7520_o;
  wire n7521_o;
  wire n7523_o;
  wire n7524_o;
  wire n7526_o;
  wire n7527_o;
  wire n7529_o;
  wire n7530_o;
  wire n7532_o;
  wire n7533_o;
  wire n7535_o;
  wire n7536_o;
  wire n7538_o;
  wire n7539_o;
  wire [30:0] n7540_o;
  wire n7541_o;
  wire n7543_o;
  wire n7545_o;
  wire n7546_o;
  wire n7547_o;
  wire [3:0] n7550_o;
  wire n7552_o;
  wire n7554_o;
  wire [3:0] n7555_o;
  reg [2:0] n7558_o;
  wire [2:0] n7559_o;
  reg [2:0] n7561_o;
  wire n7562_o;
  reg n7564_o;
  reg n7567_o;
  reg [3:0] n7570_o;
  reg [3:0] n7574_o;
  reg [3:0] n7576_o;
  reg n7579_o;
  reg [2:0] n7583_o;
  reg n7586_o;
  reg n7589_o;
  reg [1:0] n7592_o;
  reg n7595_o;
  reg n7598_o;
  wire n7600_o;
  wire n7602_o;
  wire n7603_o;
  wire n7605_o;
  wire n7606_o;
  wire n7608_o;
  wire n7609_o;
  wire [30:0] n7610_o;
  wire n7612_o;
  wire n7613_o;
  wire n7615_o;
  wire n7616_o;
  wire n7617_o;
  wire [3:0] n7620_o;
  wire n7622_o;
  wire n7624_o;
  wire [3:0] n7625_o;
  reg [2:0] n7628_o;
  wire [2:0] n7629_o;
  reg [2:0] n7631_o;
  wire n7632_o;
  reg n7634_o;
  reg n7637_o;
  reg [3:0] n7640_o;
  reg [3:0] n7644_o;
  reg [3:0] n7646_o;
  reg n7649_o;
  reg [2:0] n7653_o;
  reg n7656_o;
  reg n7659_o;
  reg [1:0] n7662_o;
  reg n7665_o;
  reg n7668_o;
  wire n7670_o;
  wire n7672_o;
  wire n7673_o;
  wire n7675_o;
  wire n7676_o;
  wire n7678_o;
  wire n7679_o;
  wire [22:0] n7680_o;
  reg [2:0] n7696_o;
  reg [2:0] n7702_o;
  reg n7705_o;
  reg n7708_o;
  wire [2:0] n7709_o;
  wire [2:0] n7710_o;
  wire [2:0] n7711_o;
  reg [2:0] n7714_o;
  wire n7715_o;
  wire n7716_o;
  wire n7717_o;
  reg n7720_o;
  reg n7723_o;
  reg n7727_o;
  wire [2:0] n7729_o;
  wire [2:0] n7730_o;
  reg [2:0] n7733_o;
  wire n7735_o;
  wire n7736_o;
  reg n7739_o;
  wire n7740_o;
  wire n7741_o;
  wire n7742_o;
  wire n7744_o;
  wire n7745_o;
  wire n7746_o;
  wire n7747_o;
  wire n7748_o;
  reg n7751_o;
  wire [1:0] n7752_o;
  wire [1:0] n7753_o;
  wire [1:0] n7754_o;
  wire [1:0] n7756_o;
  wire [1:0] n7757_o;
  wire [1:0] n7758_o;
  wire [1:0] n7759_o;
  wire [1:0] n7760_o;
  reg [1:0] n7763_o;
  wire n7764_o;
  wire n7765_o;
  wire n7766_o;
  wire n7768_o;
  wire n7769_o;
  reg n7772_o;
  reg [3:0] n7775_o;
  reg n7779_o;
  reg n7782_o;
  reg [2:0] n7785_o;
  reg n7788_o;
  reg n7791_o;
  reg n7794_o;
  reg n7797_o;
  reg [2:0] n7804_o;
  reg n7807_o;
  reg n7810_o;
  reg n7813_o;
  reg n7816_o;
  reg n7819_o;
  reg n7822_o;
  reg n7825_o;
  reg [1:0] n7828_o;
  reg [1:0] n7834_o;
  reg n7837_o;
  reg n7840_o;
  wire [1:0] n7841_o;
  reg [2:0] n7842_o;
  reg [2:0] n7844_o;
  reg [1:0] n7846_o;
  reg n7849_o;
  reg n7852_o;
  wire [1:0] n7854_o;
  reg [1:0] n7856_o;
  wire n7857_o;
  wire n7858_o;
  reg n7860_o;
  wire n7861_o;
  reg n7863_o;
  reg n7867_o;
  reg n7870_o;
  reg [2:0] n7872_o;
  reg n7874_o;
  wire n7877_o;
  reg n7878_o;
  wire [1:0] n7879_o;
  reg [1:0] n7880_o;
  reg n7882_o;
  reg [3:0] n7886_o;
  reg n7887_o;
  reg n7890_o;
  reg n7893_o;
  reg [2:0] n7895_o;
  reg n7898_o;
  reg n7901_o;
  reg n7904_o;
  reg n7907_o;
  reg n7910_o;
  reg n7913_o;
  reg n7916_o;
  reg n7919_o;
  reg n7922_o;
  reg [2:0] n7925_o;
  reg n7928_o;
  reg n7931_o;
  reg n7934_o;
  reg n7937_o;
  reg n7940_o;
  reg n7943_o;
  reg n7946_o;
  reg n7949_o;
  reg n7952_o;
  reg n7955_o;
  reg n7958_o;
  reg n7961_o;
  reg n7964_o;
  reg n7967_o;
  reg n7970_o;
  reg [1:0] n7973_o;
  reg n7976_o;
  reg n7979_o;
  reg [1:0] n7982_o;
  reg n7985_o;
  reg n7988_o;
  reg n7990_o;
  reg n7993_o;
  wire [31:0] n7995_o;
  wire n7997_o;
  wire n7999_o;
  wire [2:0] n8001_o;
  wire [2:0] n8002_o;
  wire [31:0] n8003_o;
  wire n8005_o;
  wire n8007_o;
  wire [2:0] n8009_o;
  wire [2:0] n8010_o;
  wire [31:0] n8011_o;
  wire n8013_o;
  wire n8015_o;
  wire [31:0] n8016_o;
  wire n8018_o;
  wire [2:0] n8021_o;
  wire [3:0] n8022_o;
  wire [3:0] n8023_o;
  wire [3:0] n8024_o;
  wire [2:0] n8026_o;
  wire n8028_o;
  wire n8030_o;
  wire n8031_o;
  wire [2:0] n8033_o;
  wire n8034_o;
  wire n8036_o;
  wire [3:0] n8037_o;
  wire [3:0] n8038_o;
  wire [2:0] n8039_o;
  wire n8041_o;
  wire [31:0] n8042_o;
  wire n8044_o;
  wire [2:0] n8046_o;
  wire n8048_o;
  wire [2:0] n8050_o;
  wire n8053_o;
  wire n8055_o;
  wire n8056_o;
  wire n8058_o;
  wire n8060_o;
  wire n8061_o;
  wire n8062_o;
  wire [3:0] n8063_o;
  wire [3:0] n8064_o;
  wire n8065_o;
  wire n8066_o;
  wire [2:0] n8067_o;
  wire n8068_o;
  wire [3:0] n8069_o;
  wire [3:0] n8070_o;
  wire [2:0] n8071_o;
  wire n8072_o;
  wire [3:0] n8074_o;
  wire [3:0] n8075_o;
  assign mcycles = n7842_o;
  assign tstates = n8067_o;
  assign prefix = n7846_o;
  assign inc_pc = n8068_o;
  assign inc_wz = n7852_o;
  assign incdec_16 = n8074_o;
  assign read_to_reg = n7867_o;
  assign read_to_acc = n7870_o;
  assign set_busa_to = n8075_o;
  assign set_busb_to = n8070_o;
  assign alu_op = n7886_o;
  assign save_alu = n7887_o;
  assign preservec = n7890_o;
  assign arith16 = n7893_o;
  assign set_addr_to = n8071_o;
  assign iorq = n7898_o;
  assign jump = n7901_o;
  assign jumpe = n7904_o;
  assign jumpxy = n7907_o;
  assign call = n7910_o;
  assign rstp = n7913_o;
  assign ldz = n7916_o;
  assign ldw = n7919_o;
  assign ldsphl = n7922_o;
  assign special_ld = n7925_o;
  assign exchangedh = n7928_o;
  assign exchangerp = n7931_o;
  assign exchangeaf = n7934_o;
  assign exchangers = n7937_o;
  assign i_djnz = n7940_o;
  assign i_cpl = n7943_o;
  assign i_ccf = n7946_o;
  assign i_scf = n7949_o;
  assign i_retn = n7952_o;
  assign i_bt = n7955_o;
  assign i_bc = n7958_o;
  assign i_btr = n7961_o;
  assign i_rld = n7964_o;
  assign i_rrd = n7967_o;
  assign i_inrc = n7970_o;
  assign setwz = n7973_o;
  assign setdi = n7976_o;
  assign setei = n7979_o;
  assign imode = n7982_o;
  assign halt = n7985_o;
  assign noread = n8066_o;
  assign write = n7990_o;
  assign xybit_undoc = n7993_o;
  /* T80_MCode.vhd:200:26  */
  assign n2115_o = ir[5:3];
  /* T80_MCode.vhd:201:26  */
  assign n2116_o = ir[2:0];
  /* T80_MCode.vhd:202:28  */
  assign n2117_o = ir[5:4];
  /* T80_MCode.vhd:206:27  */
  assign n2119_o = mcycle == 3'b001;
  /* T80_MCode.vhd:206:17  */
  assign n2122_o = n2119_o ? 3'b100 : 3'b011;
  /* T80_MCode.vhd:219:35  */
  assign n2123_o = ir[5:3];
  /* T80_MCode.vhd:219:31  */
  assign n2125_o = {1'b0, n2123_o};
  /* T80_MCode.vhd:269:17  */
  assign n2127_o = ir == 8'b01000000;
  /* T80_MCode.vhd:269:32  */
  assign n2129_o = ir == 8'b01000001;
  /* T80_MCode.vhd:269:32  */
  assign n2130_o = n2127_o | n2129_o;
  /* T80_MCode.vhd:269:43  */
  assign n2132_o = ir == 8'b01000010;
  /* T80_MCode.vhd:269:43  */
  assign n2133_o = n2130_o | n2132_o;
  /* T80_MCode.vhd:269:54  */
  assign n2135_o = ir == 8'b01000011;
  /* T80_MCode.vhd:269:54  */
  assign n2136_o = n2133_o | n2135_o;
  /* T80_MCode.vhd:269:65  */
  assign n2138_o = ir == 8'b01000100;
  /* T80_MCode.vhd:269:65  */
  assign n2139_o = n2136_o | n2138_o;
  /* T80_MCode.vhd:269:76  */
  assign n2141_o = ir == 8'b01000101;
  /* T80_MCode.vhd:269:76  */
  assign n2142_o = n2139_o | n2141_o;
  /* T80_MCode.vhd:269:87  */
  assign n2144_o = ir == 8'b01000111;
  /* T80_MCode.vhd:269:87  */
  assign n2145_o = n2142_o | n2144_o;
  /* T80_MCode.vhd:270:25  */
  assign n2147_o = ir == 8'b01001000;
  /* T80_MCode.vhd:270:25  */
  assign n2148_o = n2145_o | n2147_o;
  /* T80_MCode.vhd:270:36  */
  assign n2150_o = ir == 8'b01001001;
  /* T80_MCode.vhd:270:36  */
  assign n2151_o = n2148_o | n2150_o;
  /* T80_MCode.vhd:270:47  */
  assign n2153_o = ir == 8'b01001010;
  /* T80_MCode.vhd:270:47  */
  assign n2154_o = n2151_o | n2153_o;
  /* T80_MCode.vhd:270:58  */
  assign n2156_o = ir == 8'b01001011;
  /* T80_MCode.vhd:270:58  */
  assign n2157_o = n2154_o | n2156_o;
  /* T80_MCode.vhd:270:69  */
  assign n2159_o = ir == 8'b01001100;
  /* T80_MCode.vhd:270:69  */
  assign n2160_o = n2157_o | n2159_o;
  /* T80_MCode.vhd:270:80  */
  assign n2162_o = ir == 8'b01001101;
  /* T80_MCode.vhd:270:80  */
  assign n2163_o = n2160_o | n2162_o;
  /* T80_MCode.vhd:270:91  */
  assign n2165_o = ir == 8'b01001111;
  /* T80_MCode.vhd:270:91  */
  assign n2166_o = n2163_o | n2165_o;
  /* T80_MCode.vhd:271:25  */
  assign n2168_o = ir == 8'b01010000;
  /* T80_MCode.vhd:271:25  */
  assign n2169_o = n2166_o | n2168_o;
  /* T80_MCode.vhd:271:36  */
  assign n2171_o = ir == 8'b01010001;
  /* T80_MCode.vhd:271:36  */
  assign n2172_o = n2169_o | n2171_o;
  /* T80_MCode.vhd:271:47  */
  assign n2174_o = ir == 8'b01010010;
  /* T80_MCode.vhd:271:47  */
  assign n2175_o = n2172_o | n2174_o;
  /* T80_MCode.vhd:271:58  */
  assign n2177_o = ir == 8'b01010011;
  /* T80_MCode.vhd:271:58  */
  assign n2178_o = n2175_o | n2177_o;
  /* T80_MCode.vhd:271:69  */
  assign n2180_o = ir == 8'b01010100;
  /* T80_MCode.vhd:271:69  */
  assign n2181_o = n2178_o | n2180_o;
  /* T80_MCode.vhd:271:80  */
  assign n2183_o = ir == 8'b01010101;
  /* T80_MCode.vhd:271:80  */
  assign n2184_o = n2181_o | n2183_o;
  /* T80_MCode.vhd:271:91  */
  assign n2186_o = ir == 8'b01010111;
  /* T80_MCode.vhd:271:91  */
  assign n2187_o = n2184_o | n2186_o;
  /* T80_MCode.vhd:272:25  */
  assign n2189_o = ir == 8'b01011000;
  /* T80_MCode.vhd:272:25  */
  assign n2190_o = n2187_o | n2189_o;
  /* T80_MCode.vhd:272:36  */
  assign n2192_o = ir == 8'b01011001;
  /* T80_MCode.vhd:272:36  */
  assign n2193_o = n2190_o | n2192_o;
  /* T80_MCode.vhd:272:47  */
  assign n2195_o = ir == 8'b01011010;
  /* T80_MCode.vhd:272:47  */
  assign n2196_o = n2193_o | n2195_o;
  /* T80_MCode.vhd:272:58  */
  assign n2198_o = ir == 8'b01011011;
  /* T80_MCode.vhd:272:58  */
  assign n2199_o = n2196_o | n2198_o;
  /* T80_MCode.vhd:272:69  */
  assign n2201_o = ir == 8'b01011100;
  /* T80_MCode.vhd:272:69  */
  assign n2202_o = n2199_o | n2201_o;
  /* T80_MCode.vhd:272:80  */
  assign n2204_o = ir == 8'b01011101;
  /* T80_MCode.vhd:272:80  */
  assign n2205_o = n2202_o | n2204_o;
  /* T80_MCode.vhd:272:91  */
  assign n2207_o = ir == 8'b01011111;
  /* T80_MCode.vhd:272:91  */
  assign n2208_o = n2205_o | n2207_o;
  /* T80_MCode.vhd:273:25  */
  assign n2210_o = ir == 8'b01100000;
  /* T80_MCode.vhd:273:25  */
  assign n2211_o = n2208_o | n2210_o;
  /* T80_MCode.vhd:273:36  */
  assign n2213_o = ir == 8'b01100001;
  /* T80_MCode.vhd:273:36  */
  assign n2214_o = n2211_o | n2213_o;
  /* T80_MCode.vhd:273:47  */
  assign n2216_o = ir == 8'b01100010;
  /* T80_MCode.vhd:273:47  */
  assign n2217_o = n2214_o | n2216_o;
  /* T80_MCode.vhd:273:58  */
  assign n2219_o = ir == 8'b01100011;
  /* T80_MCode.vhd:273:58  */
  assign n2220_o = n2217_o | n2219_o;
  /* T80_MCode.vhd:273:69  */
  assign n2222_o = ir == 8'b01100100;
  /* T80_MCode.vhd:273:69  */
  assign n2223_o = n2220_o | n2222_o;
  /* T80_MCode.vhd:273:80  */
  assign n2225_o = ir == 8'b01100101;
  /* T80_MCode.vhd:273:80  */
  assign n2226_o = n2223_o | n2225_o;
  /* T80_MCode.vhd:273:91  */
  assign n2228_o = ir == 8'b01100111;
  /* T80_MCode.vhd:273:91  */
  assign n2229_o = n2226_o | n2228_o;
  /* T80_MCode.vhd:274:25  */
  assign n2231_o = ir == 8'b01101000;
  /* T80_MCode.vhd:274:25  */
  assign n2232_o = n2229_o | n2231_o;
  /* T80_MCode.vhd:274:36  */
  assign n2234_o = ir == 8'b01101001;
  /* T80_MCode.vhd:274:36  */
  assign n2235_o = n2232_o | n2234_o;
  /* T80_MCode.vhd:274:47  */
  assign n2237_o = ir == 8'b01101010;
  /* T80_MCode.vhd:274:47  */
  assign n2238_o = n2235_o | n2237_o;
  /* T80_MCode.vhd:274:58  */
  assign n2240_o = ir == 8'b01101011;
  /* T80_MCode.vhd:274:58  */
  assign n2241_o = n2238_o | n2240_o;
  /* T80_MCode.vhd:274:69  */
  assign n2243_o = ir == 8'b01101100;
  /* T80_MCode.vhd:274:69  */
  assign n2244_o = n2241_o | n2243_o;
  /* T80_MCode.vhd:274:80  */
  assign n2246_o = ir == 8'b01101101;
  /* T80_MCode.vhd:274:80  */
  assign n2247_o = n2244_o | n2246_o;
  /* T80_MCode.vhd:274:91  */
  assign n2249_o = ir == 8'b01101111;
  /* T80_MCode.vhd:274:91  */
  assign n2250_o = n2247_o | n2249_o;
  /* T80_MCode.vhd:275:25  */
  assign n2252_o = ir == 8'b01111000;
  /* T80_MCode.vhd:275:25  */
  assign n2253_o = n2250_o | n2252_o;
  /* T80_MCode.vhd:275:36  */
  assign n2255_o = ir == 8'b01111001;
  /* T80_MCode.vhd:275:36  */
  assign n2256_o = n2253_o | n2255_o;
  /* T80_MCode.vhd:275:47  */
  assign n2258_o = ir == 8'b01111010;
  /* T80_MCode.vhd:275:47  */
  assign n2259_o = n2256_o | n2258_o;
  /* T80_MCode.vhd:275:58  */
  assign n2261_o = ir == 8'b01111011;
  /* T80_MCode.vhd:275:58  */
  assign n2262_o = n2259_o | n2261_o;
  /* T80_MCode.vhd:275:69  */
  assign n2264_o = ir == 8'b01111100;
  /* T80_MCode.vhd:275:69  */
  assign n2265_o = n2262_o | n2264_o;
  /* T80_MCode.vhd:275:80  */
  assign n2267_o = ir == 8'b01111101;
  /* T80_MCode.vhd:275:80  */
  assign n2268_o = n2265_o | n2267_o;
  /* T80_MCode.vhd:275:91  */
  assign n2270_o = ir == 8'b01111111;
  /* T80_MCode.vhd:275:91  */
  assign n2271_o = n2268_o | n2270_o;
  /* T80_MCode.vhd:284:30  */
  assign n2272_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:285:25  */
  assign n2274_o = n2272_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:284:25  */
  always @*
    case (n2274_o)
      1'b1: n2277_o = 1'b1;
      default: n2277_o = 1'b0;
    endcase
  /* T80_MCode.vhd:284:25  */
  always @*
    case (n2274_o)
      1'b1: n2280_o = 1'b1;
      default: n2280_o = 1'b0;
    endcase
  /* T80_MCode.vhd:284:25  */
  always @*
    case (n2274_o)
      1'b1: n2282_o = n2115_o;
      default: n2282_o = 3'b000;
    endcase
  /* T80_MCode.vhd:281:17  */
  assign n2284_o = ir == 8'b00000110;
  /* T80_MCode.vhd:281:32  */
  assign n2286_o = ir == 8'b00001110;
  /* T80_MCode.vhd:281:32  */
  assign n2287_o = n2284_o | n2286_o;
  /* T80_MCode.vhd:281:43  */
  assign n2289_o = ir == 8'b00010110;
  /* T80_MCode.vhd:281:43  */
  assign n2290_o = n2287_o | n2289_o;
  /* T80_MCode.vhd:281:54  */
  assign n2292_o = ir == 8'b00011110;
  /* T80_MCode.vhd:281:54  */
  assign n2293_o = n2290_o | n2292_o;
  /* T80_MCode.vhd:281:65  */
  assign n2295_o = ir == 8'b00100110;
  /* T80_MCode.vhd:281:65  */
  assign n2296_o = n2293_o | n2295_o;
  /* T80_MCode.vhd:281:76  */
  assign n2298_o = ir == 8'b00101110;
  /* T80_MCode.vhd:281:76  */
  assign n2299_o = n2296_o | n2298_o;
  /* T80_MCode.vhd:281:87  */
  assign n2301_o = ir == 8'b00111110;
  /* T80_MCode.vhd:281:87  */
  assign n2302_o = n2299_o | n2301_o;
  /* T80_MCode.vhd:294:30  */
  assign n2303_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:295:25  */
  assign n2305_o = n2303_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:297:25  */
  assign n2307_o = n2303_o == 31'b0000000000000000000000000000010;
  assign n2308_o = {n2307_o, n2305_o};
  /* T80_MCode.vhd:294:25  */
  always @*
    case (n2308_o)
      2'b10: n2311_o = 1'b1;
      2'b01: n2311_o = 1'b0;
      default: n2311_o = 1'b0;
    endcase
  /* T80_MCode.vhd:294:25  */
  always @*
    case (n2308_o)
      2'b10: n2313_o = n2115_o;
      2'b01: n2313_o = 3'b000;
      default: n2313_o = 3'b000;
    endcase
  /* T80_MCode.vhd:294:25  */
  always @*
    case (n2308_o)
      2'b10: n2316_o = 3'b111;
      2'b01: n2316_o = 3'b010;
      default: n2316_o = 3'b111;
    endcase
  /* T80_MCode.vhd:291:17  */
  assign n2318_o = ir == 8'b01000110;
  /* T80_MCode.vhd:291:32  */
  assign n2320_o = ir == 8'b01001110;
  /* T80_MCode.vhd:291:32  */
  assign n2321_o = n2318_o | n2320_o;
  /* T80_MCode.vhd:291:43  */
  assign n2323_o = ir == 8'b01010110;
  /* T80_MCode.vhd:291:43  */
  assign n2324_o = n2321_o | n2323_o;
  /* T80_MCode.vhd:291:54  */
  assign n2326_o = ir == 8'b01011110;
  /* T80_MCode.vhd:291:54  */
  assign n2327_o = n2324_o | n2326_o;
  /* T80_MCode.vhd:291:65  */
  assign n2329_o = ir == 8'b01100110;
  /* T80_MCode.vhd:291:65  */
  assign n2330_o = n2327_o | n2329_o;
  /* T80_MCode.vhd:291:76  */
  assign n2332_o = ir == 8'b01101110;
  /* T80_MCode.vhd:291:76  */
  assign n2333_o = n2330_o | n2332_o;
  /* T80_MCode.vhd:291:87  */
  assign n2335_o = ir == 8'b01111110;
  /* T80_MCode.vhd:291:87  */
  assign n2336_o = n2333_o | n2335_o;
  /* T80_MCode.vhd:305:30  */
  assign n2337_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:306:25  */
  assign n2340_o = n2337_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:310:25  */
  assign n2342_o = n2337_o == 31'b0000000000000000000000000000010;
  assign n2343_o = {n2342_o, n2340_o};
  /* T80_MCode.vhd:305:25  */
  always @*
    case (n2343_o)
      2'b10: n2345_o = 3'b000;
      2'b01: n2345_o = n2116_o;
      default: n2345_o = 3'b000;
    endcase
  /* T80_MCode.vhd:305:25  */
  always @*
    case (n2343_o)
      2'b10: n2347_o = 1'b0;
      2'b01: n2347_o = 1'b0;
      default: n2347_o = 1'b0;
    endcase
  /* T80_MCode.vhd:305:25  */
  always @*
    case (n2343_o)
      2'b10: n2350_o = 3'b111;
      2'b01: n2350_o = 3'b010;
      default: n2350_o = 3'b111;
    endcase
  /* T80_MCode.vhd:305:25  */
  always @*
    case (n2343_o)
      2'b10: n2353_o = 1'b1;
      2'b01: n2353_o = 1'b0;
      default: n2353_o = 1'b0;
    endcase
  /* T80_MCode.vhd:302:17  */
  assign n2355_o = ir == 8'b01110000;
  /* T80_MCode.vhd:302:32  */
  assign n2357_o = ir == 8'b01110001;
  /* T80_MCode.vhd:302:32  */
  assign n2358_o = n2355_o | n2357_o;
  /* T80_MCode.vhd:302:43  */
  assign n2360_o = ir == 8'b01110010;
  /* T80_MCode.vhd:302:43  */
  assign n2361_o = n2358_o | n2360_o;
  /* T80_MCode.vhd:302:54  */
  assign n2363_o = ir == 8'b01110011;
  /* T80_MCode.vhd:302:54  */
  assign n2364_o = n2361_o | n2363_o;
  /* T80_MCode.vhd:302:65  */
  assign n2366_o = ir == 8'b01110100;
  /* T80_MCode.vhd:302:65  */
  assign n2367_o = n2364_o | n2366_o;
  /* T80_MCode.vhd:302:76  */
  assign n2369_o = ir == 8'b01110101;
  /* T80_MCode.vhd:302:76  */
  assign n2370_o = n2367_o | n2369_o;
  /* T80_MCode.vhd:302:87  */
  assign n2372_o = ir == 8'b01110111;
  /* T80_MCode.vhd:302:87  */
  assign n2373_o = n2370_o | n2372_o;
  /* T80_MCode.vhd:317:30  */
  assign n2374_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:318:25  */
  assign n2377_o = n2374_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:323:25  */
  assign n2379_o = n2374_o == 31'b0000000000000000000000000000011;
  assign n2380_o = {n2379_o, n2377_o};
  /* T80_MCode.vhd:317:25  */
  always @*
    case (n2380_o)
      2'b10: n2383_o = 1'b0;
      2'b01: n2383_o = 1'b1;
      default: n2383_o = 1'b0;
    endcase
  /* T80_MCode.vhd:317:25  */
  always @*
    case (n2380_o)
      2'b10: n2385_o = 3'b000;
      2'b01: n2385_o = n2116_o;
      default: n2385_o = 3'b000;
    endcase
  /* T80_MCode.vhd:317:25  */
  always @*
    case (n2380_o)
      2'b10: n2387_o = 1'b0;
      2'b01: n2387_o = 1'b0;
      default: n2387_o = 1'b0;
    endcase
  /* T80_MCode.vhd:317:25  */
  always @*
    case (n2380_o)
      2'b10: n2390_o = 3'b111;
      2'b01: n2390_o = 3'b010;
      default: n2390_o = 3'b111;
    endcase
  /* T80_MCode.vhd:317:25  */
  always @*
    case (n2380_o)
      2'b10: n2393_o = 1'b1;
      2'b01: n2393_o = 1'b0;
      default: n2393_o = 1'b0;
    endcase
  /* T80_MCode.vhd:314:17  */
  assign n2395_o = ir == 8'b00110110;
  /* T80_MCode.vhd:330:30  */
  assign n2396_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:331:25  */
  assign n2398_o = n2396_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:333:25  */
  assign n2400_o = n2396_o == 31'b0000000000000000000000000000010;
  assign n2401_o = {n2400_o, n2398_o};
  /* T80_MCode.vhd:330:25  */
  always @*
    case (n2401_o)
      2'b10: n2404_o = 1'b1;
      2'b01: n2404_o = 1'b0;
      default: n2404_o = 1'b0;
    endcase
  /* T80_MCode.vhd:330:25  */
  always @*
    case (n2401_o)
      2'b10: n2407_o = 3'b111;
      2'b01: n2407_o = 3'b000;
      default: n2407_o = 3'b111;
    endcase
  /* T80_MCode.vhd:327:17  */
  assign n2409_o = ir == 8'b00001010;
  /* T80_MCode.vhd:340:30  */
  assign n2410_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:341:25  */
  assign n2412_o = n2410_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:343:25  */
  assign n2414_o = n2410_o == 31'b0000000000000000000000000000010;
  assign n2415_o = {n2414_o, n2412_o};
  /* T80_MCode.vhd:340:25  */
  always @*
    case (n2415_o)
      2'b10: n2418_o = 1'b1;
      2'b01: n2418_o = 1'b0;
      default: n2418_o = 1'b0;
    endcase
  /* T80_MCode.vhd:340:25  */
  always @*
    case (n2415_o)
      2'b10: n2421_o = 3'b111;
      2'b01: n2421_o = 3'b001;
      default: n2421_o = 3'b111;
    endcase
  /* T80_MCode.vhd:337:17  */
  assign n2423_o = ir == 8'b00011010;
  /* T80_MCode.vhd:348:37  */
  assign n2424_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:348:37  */
  assign n2426_o = n2424_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:351:38  */
  assign n2427_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:352:33  */
  assign n2429_o = n2427_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:354:33  */
  assign n2431_o = n2427_o == 31'b0000000000000000000000000000010;
  assign n2432_o = {n2431_o, n2429_o};
  /* T80_MCode.vhd:351:33  */
  always @*
    case (n2432_o)
      2'b10: n2435_o = 4'b1110;
      2'b01: n2435_o = 4'b0000;
      default: n2435_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:351:33  */
  always @*
    case (n2432_o)
      2'b10: n2438_o = 1'b1;
      2'b01: n2438_o = 1'b0;
      default: n2438_o = 1'b0;
    endcase
  /* T80_MCode.vhd:351:33  */
  always @*
    case (n2432_o)
      2'b10: n2441_o = 3'b111;
      2'b01: n2441_o = 3'b010;
      default: n2441_o = 3'b111;
    endcase
  /* T80_MCode.vhd:362:38  */
  assign n2442_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:363:33  */
  assign n2444_o = n2442_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:366:33  */
  assign n2446_o = n2442_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:369:33  */
  assign n2448_o = n2442_o == 31'b0000000000000000000000000000100;
  assign n2449_o = {n2448_o, n2446_o, n2444_o};
  /* T80_MCode.vhd:362:33  */
  always @*
    case (n2449_o)
      3'b100: n2453_o = 1'b0;
      3'b010: n2453_o = 1'b1;
      3'b001: n2453_o = 1'b1;
      default: n2453_o = 1'b0;
    endcase
  /* T80_MCode.vhd:362:33  */
  always @*
    case (n2449_o)
      3'b100: n2456_o = 1'b1;
      3'b010: n2456_o = 1'b0;
      3'b001: n2456_o = 1'b0;
      default: n2456_o = 1'b0;
    endcase
  /* T80_MCode.vhd:362:33  */
  always @*
    case (n2449_o)
      3'b100: n2459_o = 3'b111;
      3'b010: n2459_o = 3'b110;
      3'b001: n2459_o = 3'b111;
      default: n2459_o = 3'b111;
    endcase
  /* T80_MCode.vhd:362:33  */
  always @*
    case (n2449_o)
      3'b100: n2462_o = 1'b0;
      3'b010: n2462_o = 1'b0;
      3'b001: n2462_o = 1'b1;
      default: n2462_o = 1'b0;
    endcase
  /* T80_MCode.vhd:348:25  */
  assign n2465_o = n2426_o ? 3'b010 : 3'b100;
  /* T80_MCode.vhd:348:25  */
  assign n2467_o = n2426_o ? 1'b0 : n2453_o;
  /* T80_MCode.vhd:348:25  */
  assign n2469_o = n2426_o ? n2435_o : 4'b0000;
  /* T80_MCode.vhd:348:25  */
  assign n2470_o = n2426_o ? n2438_o : n2456_o;
  /* T80_MCode.vhd:348:25  */
  assign n2471_o = n2426_o ? n2441_o : n2459_o;
  /* T80_MCode.vhd:348:25  */
  assign n2473_o = n2426_o ? 1'b0 : n2462_o;
  /* T80_MCode.vhd:347:17  */
  assign n2475_o = ir == 8'b00111010;
  /* T80_MCode.vhd:377:30  */
  assign n2476_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:378:25  */
  assign n2478_o = n2476_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:382:25  */
  assign n2480_o = n2476_o == 31'b0000000000000000000000000000010;
  assign n2481_o = {n2480_o, n2478_o};
  /* T80_MCode.vhd:377:25  */
  always @*
    case (n2481_o)
      2'b10: n2484_o = 4'b0000;
      2'b01: n2484_o = 4'b0111;
      default: n2484_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:377:25  */
  always @*
    case (n2481_o)
      2'b10: n2487_o = 3'b111;
      2'b01: n2487_o = 3'b000;
      default: n2487_o = 3'b111;
    endcase
  /* T80_MCode.vhd:377:25  */
  always @*
    case (n2481_o)
      2'b10: n2490_o = 2'b00;
      2'b01: n2490_o = 2'b10;
      default: n2490_o = 2'b00;
    endcase
  /* T80_MCode.vhd:377:25  */
  always @*
    case (n2481_o)
      2'b10: n2493_o = 1'b1;
      2'b01: n2493_o = 1'b0;
      default: n2493_o = 1'b0;
    endcase
  /* T80_MCode.vhd:374:17  */
  assign n2495_o = ir == 8'b00000010;
  /* T80_MCode.vhd:389:30  */
  assign n2496_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:390:25  */
  assign n2498_o = n2496_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:394:25  */
  assign n2500_o = n2496_o == 31'b0000000000000000000000000000010;
  assign n2501_o = {n2500_o, n2498_o};
  /* T80_MCode.vhd:389:25  */
  always @*
    case (n2501_o)
      2'b10: n2504_o = 4'b0000;
      2'b01: n2504_o = 4'b0111;
      default: n2504_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:389:25  */
  always @*
    case (n2501_o)
      2'b10: n2507_o = 3'b111;
      2'b01: n2507_o = 3'b001;
      default: n2507_o = 3'b111;
    endcase
  /* T80_MCode.vhd:389:25  */
  always @*
    case (n2501_o)
      2'b10: n2510_o = 2'b00;
      2'b01: n2510_o = 2'b10;
      default: n2510_o = 2'b00;
    endcase
  /* T80_MCode.vhd:389:25  */
  always @*
    case (n2501_o)
      2'b10: n2513_o = 1'b1;
      2'b01: n2513_o = 1'b0;
      default: n2513_o = 1'b0;
    endcase
  /* T80_MCode.vhd:386:17  */
  assign n2515_o = ir == 8'b00010010;
  /* T80_MCode.vhd:399:37  */
  assign n2516_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:399:37  */
  assign n2518_o = n2516_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:402:38  */
  assign n2519_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:403:33  */
  assign n2521_o = n2519_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:406:33  */
  assign n2523_o = n2519_o == 31'b0000000000000000000000000000010;
  assign n2524_o = {n2523_o, n2521_o};
  /* T80_MCode.vhd:402:33  */
  always @*
    case (n2524_o)
      2'b10: n2527_o = 4'b1110;
      2'b01: n2527_o = 4'b0000;
      default: n2527_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:402:33  */
  always @*
    case (n2524_o)
      2'b10: n2530_o = 4'b0000;
      2'b01: n2530_o = 4'b0111;
      default: n2530_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:402:33  */
  always @*
    case (n2524_o)
      2'b10: n2533_o = 3'b111;
      2'b01: n2533_o = 3'b010;
      default: n2533_o = 3'b111;
    endcase
  /* T80_MCode.vhd:402:33  */
  always @*
    case (n2524_o)
      2'b10: n2536_o = 1'b1;
      2'b01: n2536_o = 1'b0;
      default: n2536_o = 1'b0;
    endcase
  /* T80_MCode.vhd:414:38  */
  assign n2537_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:415:33  */
  assign n2539_o = n2537_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:418:33  */
  assign n2541_o = n2537_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:423:33  */
  assign n2543_o = n2537_o == 31'b0000000000000000000000000000100;
  assign n2544_o = {n2543_o, n2541_o, n2539_o};
  /* T80_MCode.vhd:414:33  */
  always @*
    case (n2544_o)
      3'b100: n2548_o = 1'b0;
      3'b010: n2548_o = 1'b1;
      3'b001: n2548_o = 1'b1;
      default: n2548_o = 1'b0;
    endcase
  /* T80_MCode.vhd:414:33  */
  always @*
    case (n2544_o)
      3'b100: n2551_o = 4'b0000;
      3'b010: n2551_o = 4'b0111;
      3'b001: n2551_o = 4'b0000;
      default: n2551_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:414:33  */
  always @*
    case (n2544_o)
      3'b100: n2554_o = 3'b111;
      3'b010: n2554_o = 3'b110;
      3'b001: n2554_o = 3'b111;
      default: n2554_o = 3'b111;
    endcase
  /* T80_MCode.vhd:414:33  */
  always @*
    case (n2544_o)
      3'b100: n2557_o = 1'b0;
      3'b010: n2557_o = 1'b0;
      3'b001: n2557_o = 1'b1;
      default: n2557_o = 1'b0;
    endcase
  /* T80_MCode.vhd:414:33  */
  always @*
    case (n2544_o)
      3'b100: n2560_o = 2'b00;
      3'b010: n2560_o = 2'b10;
      3'b001: n2560_o = 2'b00;
      default: n2560_o = 2'b00;
    endcase
  /* T80_MCode.vhd:414:33  */
  always @*
    case (n2544_o)
      3'b100: n2563_o = 1'b1;
      3'b010: n2563_o = 1'b0;
      3'b001: n2563_o = 1'b0;
      default: n2563_o = 1'b0;
    endcase
  /* T80_MCode.vhd:399:25  */
  assign n2566_o = n2518_o ? 3'b010 : 3'b100;
  /* T80_MCode.vhd:399:25  */
  assign n2568_o = n2518_o ? 1'b0 : n2548_o;
  /* T80_MCode.vhd:399:25  */
  assign n2570_o = n2518_o ? n2527_o : 4'b0000;
  /* T80_MCode.vhd:399:25  */
  assign n2571_o = n2518_o ? n2530_o : n2551_o;
  /* T80_MCode.vhd:399:25  */
  assign n2572_o = n2518_o ? n2533_o : n2554_o;
  /* T80_MCode.vhd:399:25  */
  assign n2574_o = n2518_o ? 1'b0 : n2557_o;
  /* T80_MCode.vhd:399:25  */
  assign n2576_o = n2518_o ? 2'b00 : n2560_o;
  /* T80_MCode.vhd:399:25  */
  assign n2577_o = n2518_o ? n2536_o : n2563_o;
  /* T80_MCode.vhd:398:17  */
  assign n2579_o = ir == 8'b00110010;
  /* T80_MCode.vhd:433:30  */
  assign n2580_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:437:42  */
  assign n2582_o = n2117_o == 2'b11;
  assign n2584_o = {n2117_o, 1'b1};
  /* T80_MCode.vhd:437:33  */
  assign n2586_o = n2582_o ? 3'b000 : n2584_o;
  /* T80_MCode.vhd:437:33  */
  assign n2589_o = n2582_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:434:25  */
  assign n2591_o = n2580_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:446:42  */
  assign n2593_o = n2117_o == 2'b11;
  assign n2595_o = {n2117_o, 1'b0};
  /* T80_MCode.vhd:446:33  */
  assign n2597_o = n2593_o ? 3'b001 : n2595_o;
  /* T80_MCode.vhd:446:33  */
  assign n2600_o = n2593_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:443:25  */
  assign n2602_o = n2580_o == 31'b0000000000000000000000000000011;
  assign n2603_o = {n2602_o, n2591_o};
  /* T80_MCode.vhd:433:25  */
  always @*
    case (n2603_o)
      2'b10: n2607_o = 1'b1;
      2'b01: n2607_o = 1'b1;
      default: n2607_o = 1'b0;
    endcase
  /* T80_MCode.vhd:433:25  */
  always @*
    case (n2603_o)
      2'b10: n2611_o = 1'b1;
      2'b01: n2611_o = 1'b1;
      default: n2611_o = 1'b0;
    endcase
  /* T80_MCode.vhd:433:25  */
  always @*
    case (n2603_o)
      2'b10: n2613_o = n2597_o;
      2'b01: n2613_o = n2586_o;
      default: n2613_o = 3'b000;
    endcase
  /* T80_MCode.vhd:433:25  */
  always @*
    case (n2603_o)
      2'b10: n2615_o = n2600_o;
      2'b01: n2615_o = n2589_o;
      default: n2615_o = 1'b0;
    endcase
  /* T80_MCode.vhd:430:17  */
  assign n2617_o = ir == 8'b00000001;
  /* T80_MCode.vhd:430:32  */
  assign n2619_o = ir == 8'b00010001;
  /* T80_MCode.vhd:430:32  */
  assign n2620_o = n2617_o | n2619_o;
  /* T80_MCode.vhd:430:43  */
  assign n2622_o = ir == 8'b00100001;
  /* T80_MCode.vhd:430:43  */
  assign n2623_o = n2620_o | n2622_o;
  /* T80_MCode.vhd:430:54  */
  assign n2625_o = ir == 8'b00110001;
  /* T80_MCode.vhd:430:54  */
  assign n2626_o = n2623_o | n2625_o;
  /* T80_MCode.vhd:455:37  */
  assign n2627_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:455:37  */
  assign n2629_o = n2627_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:458:38  */
  assign n2630_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:459:33  */
  assign n2632_o = n2630_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:461:33  */
  assign n2634_o = n2630_o == 31'b0000000000000000000000000000010;
  assign n2635_o = {n2634_o, n2632_o};
  /* T80_MCode.vhd:458:33  */
  always @*
    case (n2635_o)
      2'b10: n2638_o = 4'b0110;
      2'b01: n2638_o = 4'b0000;
      default: n2638_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:458:33  */
  always @*
    case (n2635_o)
      2'b10: n2641_o = 1'b1;
      2'b01: n2641_o = 1'b0;
      default: n2641_o = 1'b0;
    endcase
  /* T80_MCode.vhd:458:33  */
  always @*
    case (n2635_o)
      2'b10: n2644_o = 3'b111;
      2'b01: n2644_o = 3'b010;
      default: n2644_o = 3'b111;
    endcase
  /* T80_MCode.vhd:469:38  */
  assign n2645_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:470:33  */
  assign n2647_o = n2645_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:473:33  */
  assign n2649_o = n2645_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:477:33  */
  assign n2652_o = n2645_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:482:33  */
  assign n2655_o = n2645_o == 31'b0000000000000000000000000000101;
  assign n2656_o = {n2655_o, n2652_o, n2649_o, n2647_o};
  /* T80_MCode.vhd:469:33  */
  always @*
    case (n2656_o)
      4'b1000: n2660_o = 1'b0;
      4'b0100: n2660_o = 1'b0;
      4'b0010: n2660_o = 1'b1;
      4'b0001: n2660_o = 1'b1;
      default: n2660_o = 1'b0;
    endcase
  /* T80_MCode.vhd:469:33  */
  always @*
    case (n2656_o)
      4'b1000: n2663_o = 1'b0;
      4'b0100: n2663_o = 1'b1;
      4'b0010: n2663_o = 1'b0;
      4'b0001: n2663_o = 1'b0;
      default: n2663_o = 1'b0;
    endcase
  /* T80_MCode.vhd:469:33  */
  always @*
    case (n2656_o)
      4'b1000: n2667_o = 1'b1;
      4'b0100: n2667_o = 1'b1;
      4'b0010: n2667_o = 1'b0;
      4'b0001: n2667_o = 1'b0;
      default: n2667_o = 1'b0;
    endcase
  /* T80_MCode.vhd:469:33  */
  always @*
    case (n2656_o)
      4'b1000: n2669_o = 3'b100;
      4'b0100: n2669_o = 3'b101;
      4'b0010: n2669_o = 3'b000;
      4'b0001: n2669_o = 3'b000;
      default: n2669_o = 3'b000;
    endcase
  /* T80_MCode.vhd:469:33  */
  always @*
    case (n2656_o)
      4'b1000: n2673_o = 3'b111;
      4'b0100: n2673_o = 3'b110;
      4'b0010: n2673_o = 3'b110;
      4'b0001: n2673_o = 3'b111;
      default: n2673_o = 3'b111;
    endcase
  /* T80_MCode.vhd:469:33  */
  always @*
    case (n2656_o)
      4'b1000: n2676_o = 1'b0;
      4'b0100: n2676_o = 1'b0;
      4'b0010: n2676_o = 1'b0;
      4'b0001: n2676_o = 1'b1;
      default: n2676_o = 1'b0;
    endcase
  /* T80_MCode.vhd:469:33  */
  always @*
    case (n2656_o)
      4'b1000: n2679_o = 1'b0;
      4'b0100: n2679_o = 1'b0;
      4'b0010: n2679_o = 1'b1;
      4'b0001: n2679_o = 1'b0;
      default: n2679_o = 1'b0;
    endcase
  /* T80_MCode.vhd:455:25  */
  assign n2682_o = n2629_o ? 3'b010 : 3'b101;
  /* T80_MCode.vhd:455:25  */
  assign n2684_o = n2629_o ? 1'b0 : n2660_o;
  /* T80_MCode.vhd:455:25  */
  assign n2686_o = n2629_o ? 1'b0 : n2663_o;
  /* T80_MCode.vhd:455:25  */
  assign n2688_o = n2629_o ? n2638_o : 4'b0000;
  /* T80_MCode.vhd:455:25  */
  assign n2690_o = n2629_o ? 1'b0 : n2667_o;
  /* T80_MCode.vhd:455:25  */
  assign n2692_o = n2629_o ? n2641_o : 1'b0;
  /* T80_MCode.vhd:455:25  */
  assign n2694_o = n2629_o ? 3'b000 : n2669_o;
  /* T80_MCode.vhd:455:25  */
  assign n2695_o = n2629_o ? n2644_o : n2673_o;
  /* T80_MCode.vhd:455:25  */
  assign n2697_o = n2629_o ? 1'b0 : n2676_o;
  /* T80_MCode.vhd:455:25  */
  assign n2699_o = n2629_o ? 1'b0 : n2679_o;
  /* T80_MCode.vhd:454:17  */
  assign n2701_o = ir == 8'b00101010;
  /* T80_MCode.vhd:489:37  */
  assign n2702_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:489:37  */
  assign n2704_o = n2702_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:492:38  */
  assign n2705_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:493:33  */
  assign n2707_o = n2705_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:496:33  */
  assign n2709_o = n2705_o == 31'b0000000000000000000000000000010;
  assign n2710_o = {n2709_o, n2707_o};
  /* T80_MCode.vhd:492:33  */
  always @*
    case (n2710_o)
      2'b10: n2713_o = 4'b0110;
      2'b01: n2713_o = 4'b0000;
      default: n2713_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:492:33  */
  always @*
    case (n2710_o)
      2'b10: n2716_o = 4'b0000;
      2'b01: n2716_o = 4'b0111;
      default: n2716_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:492:33  */
  always @*
    case (n2710_o)
      2'b10: n2719_o = 3'b111;
      2'b01: n2719_o = 3'b010;
      default: n2719_o = 3'b111;
    endcase
  /* T80_MCode.vhd:492:33  */
  always @*
    case (n2710_o)
      2'b10: n2722_o = 1'b1;
      2'b01: n2722_o = 1'b0;
      default: n2722_o = 1'b0;
    endcase
  /* T80_MCode.vhd:504:38  */
  assign n2723_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:505:33  */
  assign n2725_o = n2723_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:508:33  */
  assign n2727_o = n2723_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:513:33  */
  assign n2729_o = n2723_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:518:33  */
  assign n2731_o = n2723_o == 31'b0000000000000000000000000000101;
  assign n2732_o = {n2731_o, n2729_o, n2727_o, n2725_o};
  /* T80_MCode.vhd:504:33  */
  always @*
    case (n2732_o)
      4'b1000: n2736_o = 1'b0;
      4'b0100: n2736_o = 1'b0;
      4'b0010: n2736_o = 1'b1;
      4'b0001: n2736_o = 1'b1;
      default: n2736_o = 1'b0;
    endcase
  /* T80_MCode.vhd:504:33  */
  always @*
    case (n2732_o)
      4'b1000: n2739_o = 1'b0;
      4'b0100: n2739_o = 1'b1;
      4'b0010: n2739_o = 1'b0;
      4'b0001: n2739_o = 1'b0;
      default: n2739_o = 1'b0;
    endcase
  /* T80_MCode.vhd:504:33  */
  always @*
    case (n2732_o)
      4'b1000: n2743_o = 4'b0000;
      4'b0100: n2743_o = 4'b0100;
      4'b0010: n2743_o = 4'b0101;
      4'b0001: n2743_o = 4'b0000;
      default: n2743_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:504:33  */
  always @*
    case (n2732_o)
      4'b1000: n2747_o = 3'b111;
      4'b0100: n2747_o = 3'b110;
      4'b0010: n2747_o = 3'b110;
      4'b0001: n2747_o = 3'b111;
      default: n2747_o = 3'b111;
    endcase
  /* T80_MCode.vhd:504:33  */
  always @*
    case (n2732_o)
      4'b1000: n2750_o = 1'b0;
      4'b0100: n2750_o = 1'b0;
      4'b0010: n2750_o = 1'b0;
      4'b0001: n2750_o = 1'b1;
      default: n2750_o = 1'b0;
    endcase
  /* T80_MCode.vhd:504:33  */
  always @*
    case (n2732_o)
      4'b1000: n2753_o = 1'b0;
      4'b0100: n2753_o = 1'b0;
      4'b0010: n2753_o = 1'b1;
      4'b0001: n2753_o = 1'b0;
      default: n2753_o = 1'b0;
    endcase
  /* T80_MCode.vhd:504:33  */
  always @*
    case (n2732_o)
      4'b1000: n2757_o = 1'b1;
      4'b0100: n2757_o = 1'b1;
      4'b0010: n2757_o = 1'b0;
      4'b0001: n2757_o = 1'b0;
      default: n2757_o = 1'b0;
    endcase
  /* T80_MCode.vhd:489:25  */
  assign n2760_o = n2704_o ? 3'b010 : 3'b101;
  /* T80_MCode.vhd:489:25  */
  assign n2762_o = n2704_o ? 1'b0 : n2736_o;
  /* T80_MCode.vhd:489:25  */
  assign n2764_o = n2704_o ? 1'b0 : n2739_o;
  /* T80_MCode.vhd:489:25  */
  assign n2766_o = n2704_o ? n2713_o : 4'b0000;
  /* T80_MCode.vhd:489:25  */
  assign n2767_o = n2704_o ? n2716_o : n2743_o;
  /* T80_MCode.vhd:489:25  */
  assign n2768_o = n2704_o ? n2719_o : n2747_o;
  /* T80_MCode.vhd:489:25  */
  assign n2770_o = n2704_o ? 1'b0 : n2750_o;
  /* T80_MCode.vhd:489:25  */
  assign n2772_o = n2704_o ? 1'b0 : n2753_o;
  /* T80_MCode.vhd:489:25  */
  assign n2773_o = n2704_o ? n2722_o : n2757_o;
  /* T80_MCode.vhd:488:17  */
  assign n2775_o = ir == 8'b00100010;
  /* T80_MCode.vhd:523:17  */
  assign n2777_o = ir == 8'b11111001;
  /* T80_MCode.vhd:530:30  */
  assign n2778_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:535:42  */
  assign n2780_o = n2117_o == 2'b11;
  assign n2783_o = {1'b0, n2117_o, 1'b0};
  /* T80_MCode.vhd:535:33  */
  assign n2785_o = n2780_o ? 4'b0111 : n2783_o;
  /* T80_MCode.vhd:531:25  */
  assign n2787_o = n2778_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:545:42  */
  assign n2789_o = n2117_o == 2'b11;
  assign n2792_o = {1'b0, n2117_o, 1'b1};
  /* T80_MCode.vhd:545:33  */
  assign n2794_o = n2789_o ? 4'b1011 : n2792_o;
  /* T80_MCode.vhd:542:25  */
  assign n2796_o = n2778_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:553:25  */
  assign n2798_o = n2778_o == 31'b0000000000000000000000000000011;
  assign n2799_o = {n2798_o, n2796_o, n2787_o};
  /* T80_MCode.vhd:530:25  */
  always @*
    case (n2799_o)
      3'b100: n2801_o = n2122_o;
      3'b010: n2801_o = n2122_o;
      3'b001: n2801_o = 3'b101;
      default: n2801_o = n2122_o;
    endcase
  /* T80_MCode.vhd:530:25  */
  always @*
    case (n2799_o)
      3'b100: n2805_o = 4'b0000;
      3'b010: n2805_o = 4'b1111;
      3'b001: n2805_o = 4'b1111;
      default: n2805_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:530:25  */
  always @*
    case (n2799_o)
      3'b100: n2807_o = 4'b0000;
      3'b010: n2807_o = n2794_o;
      3'b001: n2807_o = n2785_o;
      default: n2807_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:530:25  */
  always @*
    case (n2799_o)
      3'b100: n2811_o = 3'b111;
      3'b010: n2811_o = 3'b101;
      3'b001: n2811_o = 3'b101;
      default: n2811_o = 3'b111;
    endcase
  /* T80_MCode.vhd:530:25  */
  always @*
    case (n2799_o)
      3'b100: n2815_o = 1'b1;
      3'b010: n2815_o = 1'b1;
      3'b001: n2815_o = 1'b0;
      default: n2815_o = 1'b0;
    endcase
  /* T80_MCode.vhd:527:17  */
  assign n2817_o = ir == 8'b11000101;
  /* T80_MCode.vhd:527:32  */
  assign n2819_o = ir == 8'b11010101;
  /* T80_MCode.vhd:527:32  */
  assign n2820_o = n2817_o | n2819_o;
  /* T80_MCode.vhd:527:43  */
  assign n2822_o = ir == 8'b11100101;
  /* T80_MCode.vhd:527:43  */
  assign n2823_o = n2820_o | n2822_o;
  /* T80_MCode.vhd:527:54  */
  assign n2825_o = ir == 8'b11110101;
  /* T80_MCode.vhd:527:54  */
  assign n2826_o = n2823_o | n2825_o;
  /* T80_MCode.vhd:560:30  */
  assign n2827_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:561:25  */
  assign n2829_o = n2827_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:567:42  */
  assign n2831_o = n2117_o == 2'b11;
  assign n2833_o = {n2117_o, 1'b1};
  /* T80_MCode.vhd:567:33  */
  assign n2835_o = n2831_o ? 3'b011 : n2833_o;
  /* T80_MCode.vhd:567:33  */
  assign n2838_o = n2831_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:563:25  */
  assign n2840_o = n2827_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:576:42  */
  assign n2842_o = n2117_o == 2'b11;
  assign n2844_o = {n2117_o, 1'b0};
  /* T80_MCode.vhd:576:33  */
  assign n2846_o = n2842_o ? 3'b111 : n2844_o;
  /* T80_MCode.vhd:576:33  */
  assign n2849_o = n2842_o ? 1'b0 : 1'b0;
  /* T80_MCode.vhd:573:25  */
  assign n2851_o = n2827_o == 31'b0000000000000000000000000000011;
  assign n2852_o = {n2851_o, n2840_o, n2829_o};
  /* T80_MCode.vhd:560:25  */
  always @*
    case (n2852_o)
      3'b100: n2856_o = 4'b0111;
      3'b010: n2856_o = 4'b0111;
      3'b001: n2856_o = 4'b0000;
      default: n2856_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:560:25  */
  always @*
    case (n2852_o)
      3'b100: n2860_o = 1'b1;
      3'b010: n2860_o = 1'b1;
      3'b001: n2860_o = 1'b0;
      default: n2860_o = 1'b0;
    endcase
  /* T80_MCode.vhd:560:25  */
  always @*
    case (n2852_o)
      3'b100: n2862_o = n2846_o;
      3'b010: n2862_o = n2835_o;
      3'b001: n2862_o = 3'b000;
      default: n2862_o = 3'b000;
    endcase
  /* T80_MCode.vhd:560:25  */
  always @*
    case (n2852_o)
      3'b100: n2864_o = n2849_o;
      3'b010: n2864_o = n2838_o;
      3'b001: n2864_o = 1'b0;
      default: n2864_o = 1'b0;
    endcase
  /* T80_MCode.vhd:560:25  */
  always @*
    case (n2852_o)
      3'b100: n2868_o = 3'b111;
      3'b010: n2868_o = 3'b101;
      3'b001: n2868_o = 3'b101;
      default: n2868_o = 3'b111;
    endcase
  /* T80_MCode.vhd:557:17  */
  assign n2870_o = ir == 8'b11000001;
  /* T80_MCode.vhd:557:32  */
  assign n2872_o = ir == 8'b11010001;
  /* T80_MCode.vhd:557:32  */
  assign n2873_o = n2870_o | n2872_o;
  /* T80_MCode.vhd:557:43  */
  assign n2875_o = ir == 8'b11100001;
  /* T80_MCode.vhd:557:43  */
  assign n2876_o = n2873_o | n2875_o;
  /* T80_MCode.vhd:557:54  */
  assign n2878_o = ir == 8'b11110001;
  /* T80_MCode.vhd:557:54  */
  assign n2879_o = n2876_o | n2878_o;
  /* T80_MCode.vhd:587:37  */
  assign n2880_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:587:37  */
  assign n2882_o = n2880_o != 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:587:25  */
  assign n2885_o = n2882_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:586:17  */
  assign n2887_o = ir == 8'b11101011;
  /* T80_MCode.vhd:592:37  */
  assign n2888_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:592:37  */
  assign n2890_o = n2888_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:595:38  */
  assign n2891_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:596:33  */
  assign n2893_o = n2891_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:599:33  */
  assign n2895_o = n2891_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:604:33  */
  assign n2897_o = n2891_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:609:33  */
  assign n2899_o = n2891_o == 31'b0000000000000000000000000000101;
  assign n2900_o = {n2899_o, n2897_o, n2895_o, n2893_o};
  /* T80_MCode.vhd:595:33  */
  always @*
    case (n2900_o)
      4'b1000: n2904_o = 1'b0;
      4'b0100: n2904_o = 1'b0;
      4'b0010: n2904_o = 1'b1;
      4'b0001: n2904_o = 1'b1;
      default: n2904_o = 1'b0;
    endcase
  /* T80_MCode.vhd:595:33  */
  always @*
    case (n2900_o)
      4'b1000: n2907_o = 1'b0;
      4'b0100: n2907_o = 1'b1;
      4'b0010: n2907_o = 1'b0;
      4'b0001: n2907_o = 1'b0;
      default: n2907_o = 1'b0;
    endcase
  /* T80_MCode.vhd:595:33  */
  always @*
    case (n2900_o)
      4'b1000: n2911_o = 4'b0000;
      4'b0100: n2911_o = 4'b1001;
      4'b0010: n2911_o = 4'b1000;
      4'b0001: n2911_o = 4'b0000;
      default: n2911_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:595:33  */
  always @*
    case (n2900_o)
      4'b1000: n2915_o = 3'b111;
      4'b0100: n2915_o = 3'b110;
      4'b0010: n2915_o = 3'b110;
      4'b0001: n2915_o = 3'b111;
      default: n2915_o = 3'b111;
    endcase
  /* T80_MCode.vhd:595:33  */
  always @*
    case (n2900_o)
      4'b1000: n2918_o = 1'b0;
      4'b0100: n2918_o = 1'b0;
      4'b0010: n2918_o = 1'b0;
      4'b0001: n2918_o = 1'b1;
      default: n2918_o = 1'b0;
    endcase
  /* T80_MCode.vhd:595:33  */
  always @*
    case (n2900_o)
      4'b1000: n2921_o = 1'b0;
      4'b0100: n2921_o = 1'b0;
      4'b0010: n2921_o = 1'b1;
      4'b0001: n2921_o = 1'b0;
      default: n2921_o = 1'b0;
    endcase
  /* T80_MCode.vhd:595:33  */
  always @*
    case (n2900_o)
      4'b1000: n2925_o = 1'b1;
      4'b0100: n2925_o = 1'b1;
      4'b0010: n2925_o = 1'b0;
      4'b0001: n2925_o = 1'b0;
      default: n2925_o = 1'b0;
    endcase
  /* T80_MCode.vhd:613:40  */
  assign n2926_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:613:40  */
  assign n2928_o = $signed(n2926_o) < $signed(32'b00000000000000000000000000000010);
  /* T80_MCode.vhd:613:25  */
  assign n2931_o = n2928_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:592:25  */
  assign n2934_o = n2890_o ? 3'b101 : 3'b001;
  /* T80_MCode.vhd:592:25  */
  assign n2936_o = n2890_o ? n2904_o : 1'b0;
  /* T80_MCode.vhd:592:25  */
  assign n2938_o = n2890_o ? n2907_o : 1'b0;
  /* T80_MCode.vhd:592:25  */
  assign n2940_o = n2890_o ? n2911_o : 4'b0000;
  /* T80_MCode.vhd:592:25  */
  assign n2942_o = n2890_o ? n2915_o : 3'b111;
  /* T80_MCode.vhd:592:25  */
  assign n2944_o = n2890_o ? n2918_o : 1'b0;
  /* T80_MCode.vhd:592:25  */
  assign n2946_o = n2890_o ? n2921_o : 1'b0;
  /* T80_MCode.vhd:592:25  */
  assign n2948_o = n2890_o ? 1'b0 : n2931_o;
  /* T80_MCode.vhd:592:25  */
  assign n2950_o = n2890_o ? n2925_o : 1'b0;
  /* T80_MCode.vhd:591:17  */
  assign n2952_o = ir == 8'b00001000;
  /* T80_MCode.vhd:618:37  */
  assign n2953_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:618:37  */
  assign n2955_o = n2953_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:621:38  */
  assign n2956_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:622:33  */
  assign n2958_o = n2956_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:624:33  */
  assign n2960_o = n2956_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:628:33  */
  assign n2962_o = n2956_o == 31'b0000000000000000000000000000011;
  assign n2963_o = {n2962_o, n2960_o, n2958_o};
  /* T80_MCode.vhd:621:33  */
  always @*
    case (n2963_o)
      3'b100: n2967_o = 4'b0111;
      3'b010: n2967_o = 4'b0111;
      3'b001: n2967_o = 4'b0000;
      default: n2967_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:621:33  */
  always @*
    case (n2963_o)
      3'b100: n2971_o = 3'b111;
      3'b010: n2971_o = 3'b101;
      3'b001: n2971_o = 3'b101;
      default: n2971_o = 3'b111;
    endcase
  /* T80_MCode.vhd:621:33  */
  always @*
    case (n2963_o)
      3'b100: n2974_o = 1'b1;
      3'b010: n2974_o = 1'b0;
      3'b001: n2974_o = 1'b0;
      default: n2974_o = 1'b0;
    endcase
  /* T80_MCode.vhd:621:33  */
  always @*
    case (n2963_o)
      3'b100: n2977_o = 1'b0;
      3'b010: n2977_o = 1'b1;
      3'b001: n2977_o = 1'b0;
      default: n2977_o = 1'b0;
    endcase
  /* T80_MCode.vhd:621:33  */
  always @*
    case (n2963_o)
      3'b100: n2980_o = 1'b1;
      3'b010: n2980_o = 1'b0;
      3'b001: n2980_o = 1'b0;
      default: n2980_o = 1'b0;
    endcase
  /* T80_MCode.vhd:621:33  */
  always @*
    case (n2963_o)
      3'b100: n2983_o = 1'b1;
      3'b010: n2983_o = 1'b0;
      3'b001: n2983_o = 1'b0;
      default: n2983_o = 1'b0;
    endcase
  /* T80_MCode.vhd:635:40  */
  assign n2984_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:635:40  */
  assign n2986_o = $signed(n2984_o) < $signed(32'b00000000000000000000000000000010);
  /* T80_MCode.vhd:635:25  */
  assign n2989_o = n2986_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:618:25  */
  assign n2992_o = n2955_o ? 3'b011 : 3'b001;
  /* T80_MCode.vhd:618:25  */
  assign n2994_o = n2955_o ? n2967_o : 4'b0000;
  /* T80_MCode.vhd:618:25  */
  assign n2996_o = n2955_o ? n2971_o : 3'b111;
  /* T80_MCode.vhd:618:25  */
  assign n2998_o = n2955_o ? n2974_o : 1'b0;
  /* T80_MCode.vhd:618:25  */
  assign n3000_o = n2955_o ? n2977_o : 1'b0;
  /* T80_MCode.vhd:618:25  */
  assign n3002_o = n2955_o ? 1'b0 : n2989_o;
  /* T80_MCode.vhd:618:25  */
  assign n3004_o = n2955_o ? n2980_o : 1'b0;
  /* T80_MCode.vhd:618:25  */
  assign n3006_o = n2955_o ? n2983_o : 1'b0;
  /* T80_MCode.vhd:617:17  */
  assign n3008_o = ir == 8'b11011001;
  /* T80_MCode.vhd:640:37  */
  assign n3009_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:640:37  */
  assign n3011_o = n3009_o != 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:643:38  */
  assign n3012_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:644:33  */
  assign n3014_o = n3012_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:646:33  */
  assign n3016_o = n3012_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:652:33  */
  assign n3018_o = n3012_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:657:33  */
  assign n3020_o = n3012_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:663:33  */
  assign n3022_o = n3012_o == 31'b0000000000000000000000000000101;
  assign n3023_o = {n3022_o, n3020_o, n3018_o, n3016_o, n3014_o};
  /* T80_MCode.vhd:643:33  */
  always @*
    case (n3023_o)
      5'b10000: n3026_o = 3'b101;
      5'b01000: n3026_o = n2122_o;
      5'b00100: n3026_o = 3'b100;
      5'b00010: n3026_o = n2122_o;
      5'b00001: n3026_o = n2122_o;
      default: n3026_o = n2122_o;
    endcase
  /* T80_MCode.vhd:643:33  */
  always @*
    case (n3023_o)
      5'b10000: n3030_o = 4'b1111;
      5'b01000: n3030_o = 4'b0000;
      5'b00100: n3030_o = 4'b0111;
      5'b00010: n3030_o = 4'b0000;
      5'b00001: n3030_o = 4'b0000;
      default: n3030_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:643:33  */
  always @*
    case (n3023_o)
      5'b10000: n3034_o = 1'b0;
      5'b01000: n3034_o = 1'b1;
      5'b00100: n3034_o = 1'b0;
      5'b00010: n3034_o = 1'b1;
      5'b00001: n3034_o = 1'b0;
      default: n3034_o = 1'b0;
    endcase
  /* T80_MCode.vhd:643:33  */
  always @*
    case (n3023_o)
      5'b10000: n3038_o = 4'b0000;
      5'b01000: n3038_o = 4'b0100;
      5'b00100: n3038_o = 4'b0000;
      5'b00010: n3038_o = 4'b0101;
      5'b00001: n3038_o = 4'b0000;
      default: n3038_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:643:33  */
  always @*
    case (n3023_o)
      5'b10000: n3042_o = 4'b0000;
      5'b01000: n3042_o = 4'b0100;
      5'b00100: n3042_o = 4'b0000;
      5'b00010: n3042_o = 4'b0101;
      5'b00001: n3042_o = 4'b0000;
      default: n3042_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:643:33  */
  always @*
    case (n3023_o)
      5'b10000: n3048_o = 3'b111;
      5'b01000: n3048_o = 3'b101;
      5'b00100: n3048_o = 3'b101;
      5'b00010: n3048_o = 3'b101;
      5'b00001: n3048_o = 3'b101;
      default: n3048_o = 3'b111;
    endcase
  /* T80_MCode.vhd:643:33  */
  always @*
    case (n3023_o)
      5'b10000: n3051_o = 1'b0;
      5'b01000: n3051_o = 1'b0;
      5'b00100: n3051_o = 1'b0;
      5'b00010: n3051_o = 1'b1;
      5'b00001: n3051_o = 1'b0;
      default: n3051_o = 1'b0;
    endcase
  /* T80_MCode.vhd:643:33  */
  always @*
    case (n3023_o)
      5'b10000: n3054_o = 1'b0;
      5'b01000: n3054_o = 1'b1;
      5'b00100: n3054_o = 1'b0;
      5'b00010: n3054_o = 1'b0;
      5'b00001: n3054_o = 1'b0;
      default: n3054_o = 1'b0;
    endcase
  /* T80_MCode.vhd:643:33  */
  always @*
    case (n3023_o)
      5'b10000: n3058_o = 1'b1;
      5'b01000: n3058_o = 1'b0;
      5'b00100: n3058_o = 1'b1;
      5'b00010: n3058_o = 1'b0;
      5'b00001: n3058_o = 1'b0;
      default: n3058_o = 1'b0;
    endcase
  /* T80_MCode.vhd:640:25  */
  assign n3061_o = n3011_o ? 3'b101 : 3'b001;
  /* T80_MCode.vhd:640:25  */
  assign n3062_o = n3011_o ? n3026_o : n2122_o;
  /* T80_MCode.vhd:640:25  */
  assign n3064_o = n3011_o ? n3030_o : 4'b0000;
  /* T80_MCode.vhd:640:25  */
  assign n3066_o = n3011_o ? n3034_o : 1'b0;
  /* T80_MCode.vhd:640:25  */
  assign n3068_o = n3011_o ? n3038_o : 4'b0000;
  /* T80_MCode.vhd:640:25  */
  assign n3070_o = n3011_o ? n3042_o : 4'b0000;
  /* T80_MCode.vhd:640:25  */
  assign n3072_o = n3011_o ? n3048_o : 3'b111;
  /* T80_MCode.vhd:640:25  */
  assign n3074_o = n3011_o ? n3051_o : 1'b0;
  /* T80_MCode.vhd:640:25  */
  assign n3076_o = n3011_o ? n3054_o : 1'b0;
  /* T80_MCode.vhd:640:25  */
  assign n3078_o = n3011_o ? n3058_o : 1'b0;
  /* T80_MCode.vhd:639:17  */
  assign n3080_o = ir == 8'b11100011;
  /* T80_MCode.vhd:672:17  */
  assign n3083_o = ir == 8'b10000000;
  /* T80_MCode.vhd:672:32  */
  assign n3085_o = ir == 8'b10000001;
  /* T80_MCode.vhd:672:32  */
  assign n3086_o = n3083_o | n3085_o;
  /* T80_MCode.vhd:672:43  */
  assign n3088_o = ir == 8'b10000010;
  /* T80_MCode.vhd:672:43  */
  assign n3089_o = n3086_o | n3088_o;
  /* T80_MCode.vhd:672:54  */
  assign n3091_o = ir == 8'b10000011;
  /* T80_MCode.vhd:672:54  */
  assign n3092_o = n3089_o | n3091_o;
  /* T80_MCode.vhd:672:65  */
  assign n3094_o = ir == 8'b10000100;
  /* T80_MCode.vhd:672:65  */
  assign n3095_o = n3092_o | n3094_o;
  /* T80_MCode.vhd:672:76  */
  assign n3097_o = ir == 8'b10000101;
  /* T80_MCode.vhd:672:76  */
  assign n3098_o = n3095_o | n3097_o;
  /* T80_MCode.vhd:672:87  */
  assign n3100_o = ir == 8'b10000111;
  /* T80_MCode.vhd:672:87  */
  assign n3101_o = n3098_o | n3100_o;
  /* T80_MCode.vhd:673:25  */
  assign n3103_o = ir == 8'b10001000;
  /* T80_MCode.vhd:673:25  */
  assign n3104_o = n3101_o | n3103_o;
  /* T80_MCode.vhd:673:36  */
  assign n3106_o = ir == 8'b10001001;
  /* T80_MCode.vhd:673:36  */
  assign n3107_o = n3104_o | n3106_o;
  /* T80_MCode.vhd:673:47  */
  assign n3109_o = ir == 8'b10001010;
  /* T80_MCode.vhd:673:47  */
  assign n3110_o = n3107_o | n3109_o;
  /* T80_MCode.vhd:673:58  */
  assign n3112_o = ir == 8'b10001011;
  /* T80_MCode.vhd:673:58  */
  assign n3113_o = n3110_o | n3112_o;
  /* T80_MCode.vhd:673:69  */
  assign n3115_o = ir == 8'b10001100;
  /* T80_MCode.vhd:673:69  */
  assign n3116_o = n3113_o | n3115_o;
  /* T80_MCode.vhd:673:80  */
  assign n3118_o = ir == 8'b10001101;
  /* T80_MCode.vhd:673:80  */
  assign n3119_o = n3116_o | n3118_o;
  /* T80_MCode.vhd:673:91  */
  assign n3121_o = ir == 8'b10001111;
  /* T80_MCode.vhd:673:91  */
  assign n3122_o = n3119_o | n3121_o;
  /* T80_MCode.vhd:674:25  */
  assign n3124_o = ir == 8'b10010000;
  /* T80_MCode.vhd:674:25  */
  assign n3125_o = n3122_o | n3124_o;
  /* T80_MCode.vhd:674:36  */
  assign n3127_o = ir == 8'b10010001;
  /* T80_MCode.vhd:674:36  */
  assign n3128_o = n3125_o | n3127_o;
  /* T80_MCode.vhd:674:47  */
  assign n3130_o = ir == 8'b10010010;
  /* T80_MCode.vhd:674:47  */
  assign n3131_o = n3128_o | n3130_o;
  /* T80_MCode.vhd:674:58  */
  assign n3133_o = ir == 8'b10010011;
  /* T80_MCode.vhd:674:58  */
  assign n3134_o = n3131_o | n3133_o;
  /* T80_MCode.vhd:674:69  */
  assign n3136_o = ir == 8'b10010100;
  /* T80_MCode.vhd:674:69  */
  assign n3137_o = n3134_o | n3136_o;
  /* T80_MCode.vhd:674:80  */
  assign n3139_o = ir == 8'b10010101;
  /* T80_MCode.vhd:674:80  */
  assign n3140_o = n3137_o | n3139_o;
  /* T80_MCode.vhd:674:91  */
  assign n3142_o = ir == 8'b10010111;
  /* T80_MCode.vhd:674:91  */
  assign n3143_o = n3140_o | n3142_o;
  /* T80_MCode.vhd:675:25  */
  assign n3145_o = ir == 8'b10011000;
  /* T80_MCode.vhd:675:25  */
  assign n3146_o = n3143_o | n3145_o;
  /* T80_MCode.vhd:675:36  */
  assign n3148_o = ir == 8'b10011001;
  /* T80_MCode.vhd:675:36  */
  assign n3149_o = n3146_o | n3148_o;
  /* T80_MCode.vhd:675:47  */
  assign n3151_o = ir == 8'b10011010;
  /* T80_MCode.vhd:675:47  */
  assign n3152_o = n3149_o | n3151_o;
  /* T80_MCode.vhd:675:58  */
  assign n3154_o = ir == 8'b10011011;
  /* T80_MCode.vhd:675:58  */
  assign n3155_o = n3152_o | n3154_o;
  /* T80_MCode.vhd:675:69  */
  assign n3157_o = ir == 8'b10011100;
  /* T80_MCode.vhd:675:69  */
  assign n3158_o = n3155_o | n3157_o;
  /* T80_MCode.vhd:675:80  */
  assign n3160_o = ir == 8'b10011101;
  /* T80_MCode.vhd:675:80  */
  assign n3161_o = n3158_o | n3160_o;
  /* T80_MCode.vhd:675:91  */
  assign n3163_o = ir == 8'b10011111;
  /* T80_MCode.vhd:675:91  */
  assign n3164_o = n3161_o | n3163_o;
  /* T80_MCode.vhd:676:25  */
  assign n3166_o = ir == 8'b10100000;
  /* T80_MCode.vhd:676:25  */
  assign n3167_o = n3164_o | n3166_o;
  /* T80_MCode.vhd:676:36  */
  assign n3169_o = ir == 8'b10100001;
  /* T80_MCode.vhd:676:36  */
  assign n3170_o = n3167_o | n3169_o;
  /* T80_MCode.vhd:676:47  */
  assign n3172_o = ir == 8'b10100010;
  /* T80_MCode.vhd:676:47  */
  assign n3173_o = n3170_o | n3172_o;
  /* T80_MCode.vhd:676:58  */
  assign n3175_o = ir == 8'b10100011;
  /* T80_MCode.vhd:676:58  */
  assign n3176_o = n3173_o | n3175_o;
  /* T80_MCode.vhd:676:69  */
  assign n3178_o = ir == 8'b10100100;
  /* T80_MCode.vhd:676:69  */
  assign n3179_o = n3176_o | n3178_o;
  /* T80_MCode.vhd:676:80  */
  assign n3181_o = ir == 8'b10100101;
  /* T80_MCode.vhd:676:80  */
  assign n3182_o = n3179_o | n3181_o;
  /* T80_MCode.vhd:676:91  */
  assign n3184_o = ir == 8'b10100111;
  /* T80_MCode.vhd:676:91  */
  assign n3185_o = n3182_o | n3184_o;
  /* T80_MCode.vhd:677:25  */
  assign n3187_o = ir == 8'b10101000;
  /* T80_MCode.vhd:677:25  */
  assign n3188_o = n3185_o | n3187_o;
  /* T80_MCode.vhd:677:36  */
  assign n3190_o = ir == 8'b10101001;
  /* T80_MCode.vhd:677:36  */
  assign n3191_o = n3188_o | n3190_o;
  /* T80_MCode.vhd:677:47  */
  assign n3193_o = ir == 8'b10101010;
  /* T80_MCode.vhd:677:47  */
  assign n3194_o = n3191_o | n3193_o;
  /* T80_MCode.vhd:677:58  */
  assign n3196_o = ir == 8'b10101011;
  /* T80_MCode.vhd:677:58  */
  assign n3197_o = n3194_o | n3196_o;
  /* T80_MCode.vhd:677:69  */
  assign n3199_o = ir == 8'b10101100;
  /* T80_MCode.vhd:677:69  */
  assign n3200_o = n3197_o | n3199_o;
  /* T80_MCode.vhd:677:80  */
  assign n3202_o = ir == 8'b10101101;
  /* T80_MCode.vhd:677:80  */
  assign n3203_o = n3200_o | n3202_o;
  /* T80_MCode.vhd:677:91  */
  assign n3205_o = ir == 8'b10101111;
  /* T80_MCode.vhd:677:91  */
  assign n3206_o = n3203_o | n3205_o;
  /* T80_MCode.vhd:678:25  */
  assign n3208_o = ir == 8'b10110000;
  /* T80_MCode.vhd:678:25  */
  assign n3209_o = n3206_o | n3208_o;
  /* T80_MCode.vhd:678:36  */
  assign n3211_o = ir == 8'b10110001;
  /* T80_MCode.vhd:678:36  */
  assign n3212_o = n3209_o | n3211_o;
  /* T80_MCode.vhd:678:47  */
  assign n3214_o = ir == 8'b10110010;
  /* T80_MCode.vhd:678:47  */
  assign n3215_o = n3212_o | n3214_o;
  /* T80_MCode.vhd:678:58  */
  assign n3217_o = ir == 8'b10110011;
  /* T80_MCode.vhd:678:58  */
  assign n3218_o = n3215_o | n3217_o;
  /* T80_MCode.vhd:678:69  */
  assign n3220_o = ir == 8'b10110100;
  /* T80_MCode.vhd:678:69  */
  assign n3221_o = n3218_o | n3220_o;
  /* T80_MCode.vhd:678:80  */
  assign n3223_o = ir == 8'b10110101;
  /* T80_MCode.vhd:678:80  */
  assign n3224_o = n3221_o | n3223_o;
  /* T80_MCode.vhd:678:91  */
  assign n3226_o = ir == 8'b10110111;
  /* T80_MCode.vhd:678:91  */
  assign n3227_o = n3224_o | n3226_o;
  /* T80_MCode.vhd:679:25  */
  assign n3229_o = ir == 8'b10111000;
  /* T80_MCode.vhd:679:25  */
  assign n3230_o = n3227_o | n3229_o;
  /* T80_MCode.vhd:679:36  */
  assign n3232_o = ir == 8'b10111001;
  /* T80_MCode.vhd:679:36  */
  assign n3233_o = n3230_o | n3232_o;
  /* T80_MCode.vhd:679:47  */
  assign n3235_o = ir == 8'b10111010;
  /* T80_MCode.vhd:679:47  */
  assign n3236_o = n3233_o | n3235_o;
  /* T80_MCode.vhd:679:58  */
  assign n3238_o = ir == 8'b10111011;
  /* T80_MCode.vhd:679:58  */
  assign n3239_o = n3236_o | n3238_o;
  /* T80_MCode.vhd:679:69  */
  assign n3241_o = ir == 8'b10111100;
  /* T80_MCode.vhd:679:69  */
  assign n3242_o = n3239_o | n3241_o;
  /* T80_MCode.vhd:679:80  */
  assign n3244_o = ir == 8'b10111101;
  /* T80_MCode.vhd:679:80  */
  assign n3245_o = n3242_o | n3244_o;
  /* T80_MCode.vhd:679:91  */
  assign n3247_o = ir == 8'b10111111;
  /* T80_MCode.vhd:679:91  */
  assign n3248_o = n3245_o | n3247_o;
  /* T80_MCode.vhd:702:30  */
  assign n3249_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:703:25  */
  assign n3251_o = n3249_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:705:25  */
  assign n3254_o = n3249_o == 31'b0000000000000000000000000000010;
  assign n3255_o = {n3254_o, n3251_o};
  /* T80_MCode.vhd:702:25  */
  always @*
    case (n3255_o)
      2'b10: n3258_o = 1'b1;
      2'b01: n3258_o = 1'b0;
      default: n3258_o = 1'b0;
    endcase
  /* T80_MCode.vhd:702:25  */
  always @*
    case (n3255_o)
      2'b10: n3260_o = 3'b111;
      2'b01: n3260_o = 3'b000;
      default: n3260_o = 3'b000;
    endcase
  /* T80_MCode.vhd:702:25  */
  always @*
    case (n3255_o)
      2'b10: n3262_o = n2116_o;
      2'b01: n3262_o = 3'b000;
      default: n3262_o = 3'b000;
    endcase
  /* T80_MCode.vhd:702:25  */
  always @*
    case (n3255_o)
      2'b10: n3265_o = 1'b1;
      2'b01: n3265_o = 1'b0;
      default: n3265_o = 1'b0;
    endcase
  /* T80_MCode.vhd:702:25  */
  always @*
    case (n3255_o)
      2'b10: n3268_o = 3'b111;
      2'b01: n3268_o = 3'b010;
      default: n3268_o = 3'b111;
    endcase
  /* T80_MCode.vhd:692:17  */
  assign n3270_o = ir == 8'b10000110;
  /* T80_MCode.vhd:692:32  */
  assign n3272_o = ir == 8'b10001110;
  /* T80_MCode.vhd:692:32  */
  assign n3273_o = n3270_o | n3272_o;
  /* T80_MCode.vhd:692:43  */
  assign n3275_o = ir == 8'b10010110;
  /* T80_MCode.vhd:692:43  */
  assign n3276_o = n3273_o | n3275_o;
  /* T80_MCode.vhd:692:54  */
  assign n3278_o = ir == 8'b10011110;
  /* T80_MCode.vhd:692:54  */
  assign n3279_o = n3276_o | n3278_o;
  /* T80_MCode.vhd:692:65  */
  assign n3281_o = ir == 8'b10100110;
  /* T80_MCode.vhd:692:65  */
  assign n3282_o = n3279_o | n3281_o;
  /* T80_MCode.vhd:692:76  */
  assign n3284_o = ir == 8'b10101110;
  /* T80_MCode.vhd:692:76  */
  assign n3285_o = n3282_o | n3284_o;
  /* T80_MCode.vhd:692:87  */
  assign n3287_o = ir == 8'b10110110;
  /* T80_MCode.vhd:692:87  */
  assign n3288_o = n3285_o | n3287_o;
  /* T80_MCode.vhd:692:98  */
  assign n3290_o = ir == 8'b10111110;
  /* T80_MCode.vhd:692:98  */
  assign n3291_o = n3288_o | n3290_o;
  /* T80_MCode.vhd:722:35  */
  assign n3293_o = mcycle == 3'b010;
  /* T80_MCode.vhd:722:25  */
  assign n3297_o = n3293_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:722:25  */
  assign n3300_o = n3293_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:722:25  */
  assign n3302_o = n3293_o ? 3'b111 : 3'b000;
  /* T80_MCode.vhd:722:25  */
  assign n3304_o = n3293_o ? n2116_o : 3'b000;
  /* T80_MCode.vhd:722:25  */
  assign n3307_o = n3293_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:712:17  */
  assign n3309_o = ir == 8'b11000110;
  /* T80_MCode.vhd:712:32  */
  assign n3311_o = ir == 8'b11001110;
  /* T80_MCode.vhd:712:32  */
  assign n3312_o = n3309_o | n3311_o;
  /* T80_MCode.vhd:712:43  */
  assign n3314_o = ir == 8'b11010110;
  /* T80_MCode.vhd:712:43  */
  assign n3315_o = n3312_o | n3314_o;
  /* T80_MCode.vhd:712:54  */
  assign n3317_o = ir == 8'b11011110;
  /* T80_MCode.vhd:712:54  */
  assign n3318_o = n3315_o | n3317_o;
  /* T80_MCode.vhd:712:65  */
  assign n3320_o = ir == 8'b11100110;
  /* T80_MCode.vhd:712:65  */
  assign n3321_o = n3318_o | n3320_o;
  /* T80_MCode.vhd:712:76  */
  assign n3323_o = ir == 8'b11101110;
  /* T80_MCode.vhd:712:76  */
  assign n3324_o = n3321_o | n3323_o;
  /* T80_MCode.vhd:712:87  */
  assign n3326_o = ir == 8'b11110110;
  /* T80_MCode.vhd:712:87  */
  assign n3327_o = n3324_o | n3326_o;
  /* T80_MCode.vhd:712:98  */
  assign n3329_o = ir == 8'b11111110;
  /* T80_MCode.vhd:712:98  */
  assign n3330_o = n3327_o | n3329_o;
  /* T80_MCode.vhd:729:17  */
  assign n3332_o = ir == 8'b00000100;
  /* T80_MCode.vhd:729:32  */
  assign n3334_o = ir == 8'b00001100;
  /* T80_MCode.vhd:729:32  */
  assign n3335_o = n3332_o | n3334_o;
  /* T80_MCode.vhd:729:43  */
  assign n3337_o = ir == 8'b00010100;
  /* T80_MCode.vhd:729:43  */
  assign n3338_o = n3335_o | n3337_o;
  /* T80_MCode.vhd:729:54  */
  assign n3340_o = ir == 8'b00011100;
  /* T80_MCode.vhd:729:54  */
  assign n3341_o = n3338_o | n3340_o;
  /* T80_MCode.vhd:729:65  */
  assign n3343_o = ir == 8'b00100100;
  /* T80_MCode.vhd:729:65  */
  assign n3344_o = n3341_o | n3343_o;
  /* T80_MCode.vhd:729:76  */
  assign n3346_o = ir == 8'b00101100;
  /* T80_MCode.vhd:729:76  */
  assign n3347_o = n3344_o | n3346_o;
  /* T80_MCode.vhd:729:87  */
  assign n3349_o = ir == 8'b00111100;
  /* T80_MCode.vhd:729:87  */
  assign n3350_o = n3347_o | n3349_o;
  /* T80_MCode.vhd:740:30  */
  assign n3351_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:741:25  */
  assign n3353_o = n3351_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:743:25  */
  assign n3355_o = n3351_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:752:25  */
  assign n3357_o = n3351_o == 31'b0000000000000000000000000000011;
  assign n3358_o = {n3357_o, n3355_o, n3353_o};
  /* T80_MCode.vhd:740:25  */
  always @*
    case (n3358_o)
      3'b100: n3360_o = n2122_o;
      3'b010: n3360_o = 3'b100;
      3'b001: n3360_o = n2122_o;
      default: n3360_o = n2122_o;
    endcase
  /* T80_MCode.vhd:740:25  */
  always @*
    case (n3358_o)
      3'b100: n3363_o = 1'b0;
      3'b010: n3363_o = 1'b1;
      3'b001: n3363_o = 1'b0;
      default: n3363_o = 1'b0;
    endcase
  /* T80_MCode.vhd:740:25  */
  always @*
    case (n3358_o)
      3'b100: n3365_o = 3'b000;
      3'b010: n3365_o = n2115_o;
      3'b001: n3365_o = 3'b000;
      default: n3365_o = 3'b000;
    endcase
  /* T80_MCode.vhd:740:25  */
  always @*
    case (n3358_o)
      3'b100: n3368_o = 4'b0000;
      3'b010: n3368_o = 4'b1010;
      3'b001: n3368_o = 4'b0000;
      default: n3368_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:740:25  */
  always @*
    case (n3358_o)
      3'b100: n3370_o = n2125_o;
      3'b010: n3370_o = 4'b0000;
      3'b001: n3370_o = n2125_o;
      default: n3370_o = n2125_o;
    endcase
  /* T80_MCode.vhd:740:25  */
  always @*
    case (n3358_o)
      3'b100: n3373_o = 1'b0;
      3'b010: n3373_o = 1'b1;
      3'b001: n3373_o = 1'b0;
      default: n3373_o = 1'b0;
    endcase
  /* T80_MCode.vhd:740:25  */
  always @*
    case (n3358_o)
      3'b100: n3376_o = 1'b0;
      3'b010: n3376_o = 1'b1;
      3'b001: n3376_o = 1'b0;
      default: n3376_o = 1'b0;
    endcase
  /* T80_MCode.vhd:740:25  */
  always @*
    case (n3358_o)
      3'b100: n3380_o = 3'b111;
      3'b010: n3380_o = 3'b010;
      3'b001: n3380_o = 3'b010;
      default: n3380_o = 3'b111;
    endcase
  /* T80_MCode.vhd:740:25  */
  always @*
    case (n3358_o)
      3'b100: n3383_o = 1'b1;
      3'b010: n3383_o = 1'b0;
      3'b001: n3383_o = 1'b0;
      default: n3383_o = 1'b0;
    endcase
  /* T80_MCode.vhd:737:17  */
  assign n3385_o = ir == 8'b00110100;
  /* T80_MCode.vhd:756:17  */
  assign n3387_o = ir == 8'b00000101;
  /* T80_MCode.vhd:756:32  */
  assign n3389_o = ir == 8'b00001101;
  /* T80_MCode.vhd:756:32  */
  assign n3390_o = n3387_o | n3389_o;
  /* T80_MCode.vhd:756:43  */
  assign n3392_o = ir == 8'b00010101;
  /* T80_MCode.vhd:756:43  */
  assign n3393_o = n3390_o | n3392_o;
  /* T80_MCode.vhd:756:54  */
  assign n3395_o = ir == 8'b00011101;
  /* T80_MCode.vhd:756:54  */
  assign n3396_o = n3393_o | n3395_o;
  /* T80_MCode.vhd:756:65  */
  assign n3398_o = ir == 8'b00100101;
  /* T80_MCode.vhd:756:65  */
  assign n3399_o = n3396_o | n3398_o;
  /* T80_MCode.vhd:756:76  */
  assign n3401_o = ir == 8'b00101101;
  /* T80_MCode.vhd:756:76  */
  assign n3402_o = n3399_o | n3401_o;
  /* T80_MCode.vhd:756:87  */
  assign n3404_o = ir == 8'b00111101;
  /* T80_MCode.vhd:756:87  */
  assign n3405_o = n3402_o | n3404_o;
  /* T80_MCode.vhd:767:30  */
  assign n3406_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:768:25  */
  assign n3408_o = n3406_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:770:25  */
  assign n3410_o = n3406_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:779:25  */
  assign n3412_o = n3406_o == 31'b0000000000000000000000000000011;
  assign n3413_o = {n3412_o, n3410_o, n3408_o};
  /* T80_MCode.vhd:767:25  */
  always @*
    case (n3413_o)
      3'b100: n3415_o = n2122_o;
      3'b010: n3415_o = 3'b100;
      3'b001: n3415_o = n2122_o;
      default: n3415_o = n2122_o;
    endcase
  /* T80_MCode.vhd:767:25  */
  always @*
    case (n3413_o)
      3'b100: n3418_o = 1'b0;
      3'b010: n3418_o = 1'b1;
      3'b001: n3418_o = 1'b0;
      default: n3418_o = 1'b0;
    endcase
  /* T80_MCode.vhd:767:25  */
  always @*
    case (n3413_o)
      3'b100: n3420_o = 3'b000;
      3'b010: n3420_o = n2115_o;
      3'b001: n3420_o = 3'b000;
      default: n3420_o = 3'b000;
    endcase
  /* T80_MCode.vhd:767:25  */
  always @*
    case (n3413_o)
      3'b100: n3423_o = 4'b0000;
      3'b010: n3423_o = 4'b1010;
      3'b001: n3423_o = 4'b0000;
      default: n3423_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:767:25  */
  always @*
    case (n3413_o)
      3'b100: n3425_o = n2125_o;
      3'b010: n3425_o = 4'b0010;
      3'b001: n3425_o = n2125_o;
      default: n3425_o = n2125_o;
    endcase
  /* T80_MCode.vhd:767:25  */
  always @*
    case (n3413_o)
      3'b100: n3428_o = 1'b0;
      3'b010: n3428_o = 1'b1;
      3'b001: n3428_o = 1'b0;
      default: n3428_o = 1'b0;
    endcase
  /* T80_MCode.vhd:767:25  */
  always @*
    case (n3413_o)
      3'b100: n3431_o = 1'b0;
      3'b010: n3431_o = 1'b1;
      3'b001: n3431_o = 1'b0;
      default: n3431_o = 1'b0;
    endcase
  /* T80_MCode.vhd:767:25  */
  always @*
    case (n3413_o)
      3'b100: n3435_o = 3'b111;
      3'b010: n3435_o = 3'b010;
      3'b001: n3435_o = 3'b010;
      default: n3435_o = 3'b111;
    endcase
  /* T80_MCode.vhd:767:25  */
  always @*
    case (n3413_o)
      3'b100: n3438_o = 1'b1;
      3'b010: n3438_o = 1'b0;
      3'b001: n3438_o = 1'b0;
      default: n3438_o = 1'b0;
    endcase
  /* T80_MCode.vhd:764:17  */
  assign n3440_o = ir == 8'b00110101;
  /* T80_MCode.vhd:785:17  */
  assign n3443_o = ir == 8'b00100111;
  /* T80_MCode.vhd:791:17  */
  assign n3445_o = ir == 8'b00101111;
  /* T80_MCode.vhd:794:17  */
  assign n3447_o = ir == 8'b00111111;
  /* T80_MCode.vhd:797:17  */
  assign n3449_o = ir == 8'b00110111;
  /* T80_MCode.vhd:804:38  */
  assign n3450_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:805:33  */
  assign n3452_o = n3450_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:810:33  */
  assign n3454_o = n3450_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:815:33  */
  assign n3456_o = n3450_o == 31'b0000000000000000000000000000011;
  assign n3457_o = {n3456_o, n3454_o, n3452_o};
  /* T80_MCode.vhd:804:33  */
  always @*
    case (n3457_o)
      3'b100: n3459_o = n2122_o;
      3'b010: n3459_o = n2122_o;
      3'b001: n3459_o = 3'b101;
      default: n3459_o = n2122_o;
    endcase
  /* T80_MCode.vhd:804:33  */
  always @*
    case (n3457_o)
      3'b100: n3463_o = 4'b0000;
      3'b010: n3463_o = 4'b1111;
      3'b001: n3463_o = 4'b1111;
      default: n3463_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:804:33  */
  always @*
    case (n3457_o)
      3'b100: n3467_o = 4'b0000;
      3'b010: n3467_o = 4'b1100;
      3'b001: n3467_o = 4'b1101;
      default: n3467_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:804:33  */
  always @*
    case (n3457_o)
      3'b100: n3471_o = 3'b111;
      3'b010: n3471_o = 3'b101;
      3'b001: n3471_o = 3'b101;
      default: n3471_o = 3'b111;
    endcase
  /* T80_MCode.vhd:804:33  */
  always @*
    case (n3457_o)
      3'b100: n3475_o = 1'b1;
      3'b010: n3475_o = 1'b1;
      3'b001: n3475_o = 1'b0;
      default: n3475_o = 1'b0;
    endcase
  /* T80_MCode.vhd:822:38  */
  assign n3476_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:823:33  */
  assign n3478_o = n3476_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:829:33  */
  assign n3480_o = n3476_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:835:33  */
  assign n3482_o = n3476_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:838:33  */
  assign n3484_o = n3476_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:841:33  */
  assign n3486_o = n3476_o == 31'b0000000000000000000000000000101;
  assign n3487_o = {n3486_o, n3484_o, n3482_o, n3480_o, n3478_o};
  /* T80_MCode.vhd:822:33  */
  always @*
    case (n3487_o)
      5'b10000: n3489_o = n2122_o;
      5'b01000: n3489_o = n2122_o;
      5'b00100: n3489_o = n2122_o;
      5'b00010: n3489_o = n2122_o;
      5'b00001: n3489_o = 3'b101;
      default: n3489_o = n2122_o;
    endcase
  /* T80_MCode.vhd:822:33  */
  always @*
    case (n3487_o)
      5'b10000: n3492_o = 1'b0;
      5'b01000: n3492_o = 1'b1;
      5'b00100: n3492_o = 1'b0;
      5'b00010: n3492_o = 1'b0;
      5'b00001: n3492_o = 1'b0;
      default: n3492_o = 1'b0;
    endcase
  /* T80_MCode.vhd:822:33  */
  always @*
    case (n3487_o)
      5'b10000: n3496_o = 4'b0000;
      5'b01000: n3496_o = 4'b0000;
      5'b00100: n3496_o = 4'b0000;
      5'b00010: n3496_o = 4'b1111;
      5'b00001: n3496_o = 4'b1111;
      default: n3496_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:822:33  */
  always @*
    case (n3487_o)
      5'b10000: n3500_o = 4'b0000;
      5'b01000: n3500_o = 4'b0000;
      5'b00100: n3500_o = 4'b0000;
      5'b00010: n3500_o = 4'b1100;
      5'b00001: n3500_o = 4'b1101;
      default: n3500_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:822:33  */
  always @*
    case (n3487_o)
      5'b10000: n3504_o = 3'b111;
      5'b01000: n3504_o = 3'b111;
      5'b00100: n3504_o = 3'b111;
      5'b00010: n3504_o = 3'b101;
      5'b00001: n3504_o = 3'b101;
      default: n3504_o = 3'b111;
    endcase
  /* T80_MCode.vhd:822:33  */
  always @*
    case (n3487_o)
      5'b10000: n3507_o = 1'b1;
      5'b01000: n3507_o = 1'b0;
      5'b00100: n3507_o = 1'b0;
      5'b00010: n3507_o = 1'b0;
      5'b00001: n3507_o = 1'b0;
      default: n3507_o = 1'b0;
    endcase
  /* T80_MCode.vhd:822:33  */
  always @*
    case (n3487_o)
      5'b10000: n3511_o = 1'b0;
      5'b01000: n3511_o = 1'b1;
      5'b00100: n3511_o = 1'b0;
      5'b00010: n3511_o = 1'b0;
      5'b00001: n3511_o = 1'b1;
      default: n3511_o = 1'b0;
    endcase
  /* T80_MCode.vhd:822:33  */
  always @*
    case (n3487_o)
      5'b10000: n3515_o = 1'b0;
      5'b01000: n3515_o = 1'b0;
      5'b00100: n3515_o = 1'b1;
      5'b00010: n3515_o = 1'b1;
      5'b00001: n3515_o = 1'b0;
      default: n3515_o = 1'b0;
    endcase
  /* T80_MCode.vhd:819:25  */
  assign n3518_o = intcycle ? 3'b101 : 3'b001;
  /* T80_MCode.vhd:819:25  */
  assign n3519_o = intcycle ? n3489_o : n2122_o;
  /* T80_MCode.vhd:819:25  */
  assign n3521_o = intcycle ? n3492_o : 1'b0;
  /* T80_MCode.vhd:819:25  */
  assign n3523_o = intcycle ? n3496_o : 4'b0000;
  /* T80_MCode.vhd:819:25  */
  assign n3525_o = intcycle ? n3500_o : 4'b0000;
  /* T80_MCode.vhd:819:25  */
  assign n3527_o = intcycle ? n3504_o : 3'b111;
  /* T80_MCode.vhd:819:25  */
  assign n3529_o = intcycle ? n3507_o : 1'b0;
  /* T80_MCode.vhd:819:25  */
  assign n3531_o = intcycle ? n3511_o : 1'b0;
  /* T80_MCode.vhd:819:25  */
  assign n3533_o = intcycle ? n3515_o : 1'b0;
  /* T80_MCode.vhd:801:25  */
  assign n3535_o = nmicycle ? 3'b011 : n3518_o;
  /* T80_MCode.vhd:801:25  */
  assign n3536_o = nmicycle ? n3459_o : n3519_o;
  /* T80_MCode.vhd:801:25  */
  assign n3538_o = nmicycle ? 1'b0 : n3521_o;
  /* T80_MCode.vhd:801:25  */
  assign n3539_o = nmicycle ? n3463_o : n3523_o;
  /* T80_MCode.vhd:801:25  */
  assign n3540_o = nmicycle ? n3467_o : n3525_o;
  /* T80_MCode.vhd:801:25  */
  assign n3541_o = nmicycle ? n3471_o : n3527_o;
  /* T80_MCode.vhd:801:25  */
  assign n3543_o = nmicycle ? 1'b0 : n3529_o;
  /* T80_MCode.vhd:801:25  */
  assign n3545_o = nmicycle ? 1'b0 : n3531_o;
  /* T80_MCode.vhd:801:25  */
  assign n3546_o = nmicycle ? n3475_o : n3533_o;
  /* T80_MCode.vhd:800:17  */
  assign n3548_o = ir == 8'b00000000;
  /* T80_MCode.vhd:848:17  */
  assign n3550_o = ir == 8'b01110110;
  /* T80_MCode.vhd:851:17  */
  assign n3552_o = ir == 8'b11110011;
  /* T80_MCode.vhd:854:17  */
  assign n3554_o = ir == 8'b11111011;
  /* T80_MCode.vhd:862:30  */
  assign n3555_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:869:60  */
  assign n3557_o = ir[5:4];
  /* T80_MCode.vhd:869:38  */
  assign n3558_o = {29'b0, n3557_o};  //  uext
  /* T80_MCode.vhd:871:70  */
  assign n3559_o = ir[5:4];
  /* T80_MCode.vhd:870:33  */
  assign n3562_o = n3558_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:870:39  */
  assign n3564_o = n3558_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:870:39  */
  assign n3565_o = n3562_o | n3564_o;
  /* T80_MCode.vhd:870:41  */
  assign n3567_o = n3558_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:870:41  */
  assign n3568_o = n3565_o | n3567_o;
  /* T80_MCode.vhd:869:33  */
  always @*
    case (n3568_o)
      1'b1: n3570_o = 1'b1;
      default: n3570_o = 1'b0;
    endcase
  /* T80_MCode.vhd:869:33  */
  always @*
    case (n3568_o)
      1'b1: n3572_o = n3559_o;
      default: n3572_o = 2'b00;
    endcase
  /* T80_MCode.vhd:869:33  */
  always @*
    case (n3568_o)
      1'b1: n3575_o = 1'b0;
      default: n3575_o = 1'b1;
    endcase
  /* T80_MCode.vhd:863:25  */
  assign n3577_o = n3555_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:885:60  */
  assign n3579_o = ir[5:4];
  /* T80_MCode.vhd:885:38  */
  assign n3580_o = {29'b0, n3579_o};  //  uext
  /* T80_MCode.vhd:887:70  */
  assign n3581_o = ir[5:4];
  /* T80_MCode.vhd:886:33  */
  assign n3583_o = n3580_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:886:39  */
  assign n3585_o = n3580_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:886:39  */
  assign n3586_o = n3583_o | n3585_o;
  /* T80_MCode.vhd:886:41  */
  assign n3588_o = n3580_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:886:41  */
  assign n3589_o = n3586_o | n3588_o;
  /* T80_MCode.vhd:885:33  */
  always @*
    case (n3589_o)
      1'b1: n3592_o = 1'b0;
      default: n3592_o = 1'b1;
    endcase
  /* T80_MCode.vhd:885:33  */
  always @*
    case (n3589_o)
      1'b1: n3594_o = n3581_o;
      default: n3594_o = 2'b00;
    endcase
  /* T80_MCode.vhd:885:33  */
  always @*
    case (n3589_o)
      1'b1: n3597_o = 1'b0;
      default: n3597_o = 1'b1;
    endcase
  /* T80_MCode.vhd:879:25  */
  assign n3599_o = n3555_o == 31'b0000000000000000000000000000011;
  assign n3600_o = {n3599_o, n3577_o};
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3602_o = n2122_o;
      2'b01: n3602_o = 3'b100;
      default: n3602_o = n2122_o;
    endcase
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3606_o = 1'b1;
      2'b01: n3606_o = 1'b1;
      default: n3606_o = 1'b0;
    endcase
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3608_o = 3'b100;
      2'b01: n3608_o = 3'b101;
      default: n3608_o = 3'b000;
    endcase
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3610_o = n3592_o;
      2'b01: n3610_o = n3570_o;
      default: n3610_o = 1'b0;
    endcase
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3612_o = n3594_o;
      2'b01: n3612_o = n3572_o;
      default: n3612_o = 2'b00;
    endcase
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3614_o = n3597_o;
      2'b01: n3614_o = n3575_o;
      default: n3614_o = 1'b0;
    endcase
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3617_o = 4'b0001;
      2'b01: n3617_o = 4'b0000;
      default: n3617_o = n2125_o;
    endcase
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3621_o = 1'b1;
      2'b01: n3621_o = 1'b1;
      default: n3621_o = 1'b0;
    endcase
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3625_o = 1'b1;
      2'b01: n3625_o = 1'b1;
      default: n3625_o = 1'b0;
    endcase
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3628_o = 2'b00;
      2'b01: n3628_o = 2'b11;
      default: n3628_o = 2'b00;
    endcase
  /* T80_MCode.vhd:862:25  */
  always @*
    case (n3600_o)
      2'b10: n3632_o = 1'b1;
      2'b01: n3632_o = 1'b1;
      default: n3632_o = 1'b0;
    endcase
  /* T80_MCode.vhd:859:17  */
  assign n3634_o = ir == 8'b00001001;
  /* T80_MCode.vhd:859:32  */
  assign n3636_o = ir == 8'b00011001;
  /* T80_MCode.vhd:859:32  */
  assign n3637_o = n3634_o | n3636_o;
  /* T80_MCode.vhd:859:43  */
  assign n3639_o = ir == 8'b00101001;
  /* T80_MCode.vhd:859:43  */
  assign n3640_o = n3637_o | n3639_o;
  /* T80_MCode.vhd:859:54  */
  assign n3642_o = ir == 8'b00111001;
  /* T80_MCode.vhd:859:54  */
  assign n3643_o = n3640_o | n3642_o;
  /* T80_MCode.vhd:894:17  */
  assign n3646_o = ir == 8'b00000011;
  /* T80_MCode.vhd:894:32  */
  assign n3648_o = ir == 8'b00010011;
  /* T80_MCode.vhd:894:32  */
  assign n3649_o = n3646_o | n3648_o;
  /* T80_MCode.vhd:894:43  */
  assign n3651_o = ir == 8'b00100011;
  /* T80_MCode.vhd:894:43  */
  assign n3652_o = n3649_o | n3651_o;
  /* T80_MCode.vhd:894:54  */
  assign n3654_o = ir == 8'b00110011;
  /* T80_MCode.vhd:894:54  */
  assign n3655_o = n3652_o | n3654_o;
  /* T80_MCode.vhd:899:17  */
  assign n3658_o = ir == 8'b00001011;
  /* T80_MCode.vhd:899:32  */
  assign n3660_o = ir == 8'b00011011;
  /* T80_MCode.vhd:899:32  */
  assign n3661_o = n3658_o | n3660_o;
  /* T80_MCode.vhd:899:43  */
  assign n3663_o = ir == 8'b00101011;
  /* T80_MCode.vhd:899:43  */
  assign n3664_o = n3661_o | n3663_o;
  /* T80_MCode.vhd:899:54  */
  assign n3666_o = ir == 8'b00111011;
  /* T80_MCode.vhd:899:54  */
  assign n3667_o = n3664_o | n3666_o;
  /* T80_MCode.vhd:906:17  */
  assign n3670_o = ir == 8'b00000111;
  /* T80_MCode.vhd:908:25  */
  assign n3672_o = ir == 8'b00010111;
  /* T80_MCode.vhd:908:25  */
  assign n3673_o = n3670_o | n3672_o;
  /* T80_MCode.vhd:910:25  */
  assign n3675_o = ir == 8'b00001111;
  /* T80_MCode.vhd:910:25  */
  assign n3676_o = n3673_o | n3675_o;
  /* T80_MCode.vhd:912:25  */
  assign n3678_o = ir == 8'b00011111;
  /* T80_MCode.vhd:912:25  */
  assign n3679_o = n3676_o | n3678_o;
  /* T80_MCode.vhd:923:30  */
  assign n3680_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:924:25  */
  assign n3682_o = n3680_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:927:25  */
  assign n3684_o = n3680_o == 31'b0000000000000000000000000000011;
  assign n3685_o = {n3684_o, n3682_o};
  /* T80_MCode.vhd:923:25  */
  always @*
    case (n3685_o)
      2'b10: n3689_o = 1'b1;
      2'b01: n3689_o = 1'b1;
      default: n3689_o = 1'b0;
    endcase
  /* T80_MCode.vhd:923:25  */
  always @*
    case (n3685_o)
      2'b10: n3692_o = 1'b1;
      2'b01: n3692_o = 1'b0;
      default: n3692_o = 1'b0;
    endcase
  /* T80_MCode.vhd:923:25  */
  always @*
    case (n3685_o)
      2'b10: n3695_o = 1'b0;
      2'b01: n3695_o = 1'b1;
      default: n3695_o = 1'b0;
    endcase
  /* T80_MCode.vhd:923:25  */
  always @*
    case (n3685_o)
      2'b10: n3698_o = 1'b1;
      2'b01: n3698_o = 1'b0;
      default: n3698_o = 1'b0;
    endcase
  /* T80_MCode.vhd:920:17  */
  assign n3700_o = ir == 8'b11000011;
  /* T80_MCode.vhd:934:30  */
  assign n3701_o = ir[5];
  /* T80_MCode.vhd:934:53  */
  assign n3702_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:934:53  */
  assign n3704_o = n3702_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:934:40  */
  assign n3705_o = n3704_o & n3701_o;
  /* T80_MCode.vhd:935:41  */
  assign n3706_o = ir[4:3];
  /* T80_MCode.vhd:939:46  */
  assign n3707_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:940:41  */
  assign n3709_o = n3707_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:943:41  */
  assign n3711_o = n3707_o == 31'b0000000000000000000000000000010;
  assign n3712_o = {n3711_o, n3709_o};
  /* T80_MCode.vhd:939:41  */
  always @*
    case (n3712_o)
      2'b10: n3715_o = 4'b0000;
      2'b01: n3715_o = 4'b0111;
      default: n3715_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:939:41  */
  always @*
    case (n3712_o)
      2'b10: n3718_o = 3'b111;
      2'b01: n3718_o = 3'b000;
      default: n3718_o = 3'b111;
    endcase
  /* T80_MCode.vhd:939:41  */
  always @*
    case (n3712_o)
      2'b10: n3721_o = 1'b1;
      2'b01: n3721_o = 1'b0;
      default: n3721_o = 1'b0;
    endcase
  /* T80_MCode.vhd:939:41  */
  always @*
    case (n3712_o)
      2'b10: n3724_o = 1'b1;
      2'b01: n3724_o = 1'b0;
      default: n3724_o = 1'b0;
    endcase
  /* T80_MCode.vhd:936:33  */
  assign n3726_o = n3706_o == 2'b00;
  /* T80_MCode.vhd:951:46  */
  assign n3727_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:952:41  */
  assign n3729_o = n3727_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:955:41  */
  assign n3731_o = n3727_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:959:41  */
  assign n3733_o = n3727_o == 31'b0000000000000000000000000000100;
  assign n3734_o = {n3733_o, n3731_o, n3729_o};
  /* T80_MCode.vhd:951:41  */
  always @*
    case (n3734_o)
      3'b100: n3738_o = 1'b0;
      3'b010: n3738_o = 1'b1;
      3'b001: n3738_o = 1'b1;
      default: n3738_o = 1'b0;
    endcase
  /* T80_MCode.vhd:951:41  */
  always @*
    case (n3734_o)
      3'b100: n3741_o = 4'b0000;
      3'b010: n3741_o = 4'b0111;
      3'b001: n3741_o = 4'b0000;
      default: n3741_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:951:41  */
  always @*
    case (n3734_o)
      3'b100: n3744_o = 3'b111;
      3'b010: n3744_o = 3'b110;
      3'b001: n3744_o = 3'b111;
      default: n3744_o = 3'b111;
    endcase
  /* T80_MCode.vhd:951:41  */
  always @*
    case (n3734_o)
      3'b100: n3747_o = 1'b0;
      3'b010: n3747_o = 1'b0;
      3'b001: n3747_o = 1'b1;
      default: n3747_o = 1'b0;
    endcase
  /* T80_MCode.vhd:951:41  */
  always @*
    case (n3734_o)
      3'b100: n3750_o = 1'b1;
      3'b010: n3750_o = 1'b0;
      3'b001: n3750_o = 1'b0;
      default: n3750_o = 1'b0;
    endcase
  /* T80_MCode.vhd:948:33  */
  assign n3752_o = n3706_o == 2'b01;
  /* T80_MCode.vhd:966:46  */
  assign n3753_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:967:41  */
  assign n3755_o = n3753_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:969:41  */
  assign n3757_o = n3753_o == 31'b0000000000000000000000000000010;
  assign n3758_o = {n3757_o, n3755_o};
  /* T80_MCode.vhd:966:41  */
  always @*
    case (n3758_o)
      2'b10: n3761_o = 1'b1;
      2'b01: n3761_o = 1'b0;
      default: n3761_o = 1'b0;
    endcase
  /* T80_MCode.vhd:966:41  */
  always @*
    case (n3758_o)
      2'b10: n3764_o = 3'b111;
      2'b01: n3764_o = 3'b000;
      default: n3764_o = 3'b111;
    endcase
  /* T80_MCode.vhd:966:41  */
  always @*
    case (n3758_o)
      2'b10: n3767_o = 1'b1;
      2'b01: n3767_o = 1'b0;
      default: n3767_o = 1'b0;
    endcase
  /* T80_MCode.vhd:963:33  */
  assign n3769_o = n3706_o == 2'b10;
  /* T80_MCode.vhd:977:46  */
  assign n3770_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:978:41  */
  assign n3772_o = n3770_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:981:41  */
  assign n3774_o = n3770_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:984:41  */
  assign n3776_o = n3770_o == 31'b0000000000000000000000000000100;
  assign n3777_o = {n3776_o, n3774_o, n3772_o};
  /* T80_MCode.vhd:977:41  */
  always @*
    case (n3777_o)
      3'b100: n3781_o = 1'b0;
      3'b010: n3781_o = 1'b1;
      3'b001: n3781_o = 1'b1;
      default: n3781_o = 1'b0;
    endcase
  /* T80_MCode.vhd:977:41  */
  always @*
    case (n3777_o)
      3'b100: n3784_o = 1'b1;
      3'b010: n3784_o = 1'b0;
      3'b001: n3784_o = 1'b0;
      default: n3784_o = 1'b0;
    endcase
  /* T80_MCode.vhd:977:41  */
  always @*
    case (n3777_o)
      3'b100: n3787_o = 3'b111;
      3'b010: n3787_o = 3'b110;
      3'b001: n3787_o = 3'b111;
      default: n3787_o = 3'b111;
    endcase
  /* T80_MCode.vhd:977:41  */
  always @*
    case (n3777_o)
      3'b100: n3790_o = 1'b0;
      3'b010: n3790_o = 1'b0;
      3'b001: n3790_o = 1'b1;
      default: n3790_o = 1'b0;
    endcase
  /* T80_MCode.vhd:974:33  */
  assign n3792_o = n3706_o == 2'b11;
  assign n3793_o = {n3792_o, n3769_o, n3752_o, n3726_o};
  /* T80_MCode.vhd:935:33  */
  always @*
    case (n3793_o)
      4'b1000: n3799_o = 3'b100;
      4'b0100: n3799_o = 3'b010;
      4'b0010: n3799_o = 3'b100;
      4'b0001: n3799_o = 3'b010;
      default: n3799_o = 3'bX;
    endcase
  /* T80_MCode.vhd:935:33  */
  always @*
    case (n3793_o)
      4'b1000: n3802_o = n3781_o;
      4'b0100: n3802_o = 1'b0;
      4'b0010: n3802_o = n3738_o;
      4'b0001: n3802_o = 1'b0;
      default: n3802_o = 1'bX;
    endcase
  /* T80_MCode.vhd:935:33  */
  always @*
    case (n3793_o)
      4'b1000: n3805_o = n3784_o;
      4'b0100: n3805_o = n3761_o;
      4'b0010: n3805_o = 1'b0;
      4'b0001: n3805_o = 1'b0;
      default: n3805_o = 1'bX;
    endcase
  /* T80_MCode.vhd:935:33  */
  always @*
    case (n3793_o)
      4'b1000: n3808_o = 4'b0000;
      4'b0100: n3808_o = 4'b0000;
      4'b0010: n3808_o = n3741_o;
      4'b0001: n3808_o = n3715_o;
      default: n3808_o = 4'bX;
    endcase
  /* T80_MCode.vhd:935:33  */
  always @*
    case (n3793_o)
      4'b1000: n3810_o = n3787_o;
      4'b0100: n3810_o = n3764_o;
      4'b0010: n3810_o = n3744_o;
      4'b0001: n3810_o = n3718_o;
      default: n3810_o = 3'bX;
    endcase
  /* T80_MCode.vhd:935:33  */
  always @*
    case (n3793_o)
      4'b1000: n3813_o = 1'b0;
      4'b0100: n3813_o = n3767_o;
      4'b0010: n3813_o = 1'b0;
      4'b0001: n3813_o = n3721_o;
      default: n3813_o = 1'bX;
    endcase
  /* T80_MCode.vhd:935:33  */
  always @*
    case (n3793_o)
      4'b1000: n3816_o = n3790_o;
      4'b0100: n3816_o = 1'b0;
      4'b0010: n3816_o = n3747_o;
      4'b0001: n3816_o = 1'b0;
      default: n3816_o = 1'bX;
    endcase
  /* T80_MCode.vhd:935:33  */
  always @*
    case (n3793_o)
      4'b1000: n3819_o = 1'b0;
      4'b0100: n3819_o = 1'b0;
      4'b0010: n3819_o = n3750_o;
      4'b0001: n3819_o = n3724_o;
      default: n3819_o = 1'bX;
    endcase
  /* T80_MCode.vhd:992:38  */
  assign n3820_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:993:33  */
  assign n3822_o = n3820_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:999:73  */
  assign n3824_o = ir[5:3];
  /* T80_MCode.vhd:999:88  */
  assign n3825_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:167:29  */
  assign n3831_o = n3825_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:169:47  */
  assign n3832_o = f[7];
  /* T80_MCode.vhd:169:56  */
  assign n3833_o = ~n3832_o;
  /* T80_MCode.vhd:169:25  */
  assign n3835_o = n3824_o == 3'b000;
  /* T80_MCode.vhd:170:47  */
  assign n3836_o = f[7];
  /* T80_MCode.vhd:170:25  */
  assign n3838_o = n3824_o == 3'b001;
  /* T80_MCode.vhd:171:47  */
  assign n3839_o = f[4];
  /* T80_MCode.vhd:171:56  */
  assign n3840_o = ~n3839_o;
  /* T80_MCode.vhd:171:25  */
  assign n3842_o = n3824_o == 3'b010;
  /* T80_MCode.vhd:172:47  */
  assign n3843_o = f[4];
  /* T80_MCode.vhd:172:25  */
  assign n3845_o = n3824_o == 3'b011;
  /* T80_MCode.vhd:173:25  */
  assign n3848_o = n3824_o == 3'b100;
  /* T80_MCode.vhd:174:25  */
  assign n3851_o = n3824_o == 3'b101;
  /* T80_MCode.vhd:175:25  */
  assign n3854_o = n3824_o == 3'b110;
  /* T80_MCode.vhd:176:25  */
  assign n3857_o = n3824_o == 3'b111;
  assign n3858_o = {n3857_o, n3854_o, n3851_o, n3848_o, n3845_o, n3842_o, n3838_o, n3835_o};
  /* T80_MCode.vhd:168:25  */
  always @*
    case (n3858_o)
      8'b10000000: n3860_o = 1'b0;
      8'b01000000: n3860_o = 1'b0;
      8'b00100000: n3860_o = 1'b0;
      8'b00010000: n3860_o = 1'b0;
      8'b00001000: n3860_o = n3843_o;
      8'b00000100: n3860_o = n3840_o;
      8'b00000010: n3860_o = n3836_o;
      8'b00000001: n3860_o = n3833_o;
      default: n3860_o = 1'bX;
    endcase
  /* T80_MCode.vhd:180:47  */
  assign n3861_o = f[6];
  /* T80_MCode.vhd:180:56  */
  assign n3862_o = ~n3861_o;
  /* T80_MCode.vhd:180:25  */
  assign n3864_o = n3824_o == 3'b000;
  /* T80_MCode.vhd:181:47  */
  assign n3865_o = f[6];
  /* T80_MCode.vhd:181:25  */
  assign n3867_o = n3824_o == 3'b001;
  /* T80_MCode.vhd:182:47  */
  assign n3868_o = f[0];
  /* T80_MCode.vhd:182:56  */
  assign n3869_o = ~n3868_o;
  /* T80_MCode.vhd:182:25  */
  assign n3871_o = n3824_o == 3'b010;
  /* T80_MCode.vhd:183:47  */
  assign n3872_o = f[0];
  /* T80_MCode.vhd:183:25  */
  assign n3874_o = n3824_o == 3'b011;
  /* T80_MCode.vhd:184:47  */
  assign n3875_o = f[2];
  /* T80_MCode.vhd:184:56  */
  assign n3876_o = ~n3875_o;
  /* T80_MCode.vhd:184:25  */
  assign n3878_o = n3824_o == 3'b100;
  /* T80_MCode.vhd:185:47  */
  assign n3879_o = f[2];
  /* T80_MCode.vhd:185:25  */
  assign n3881_o = n3824_o == 3'b101;
  /* T80_MCode.vhd:186:47  */
  assign n3882_o = f[7];
  /* T80_MCode.vhd:186:56  */
  assign n3883_o = ~n3882_o;
  /* T80_MCode.vhd:186:25  */
  assign n3885_o = n3824_o == 3'b110;
  /* T80_MCode.vhd:187:47  */
  assign n3886_o = f[7];
  /* T80_MCode.vhd:187:25  */
  assign n3888_o = n3824_o == 3'b111;
  assign n3889_o = {n3888_o, n3885_o, n3881_o, n3878_o, n3874_o, n3871_o, n3867_o, n3864_o};
  /* T80_MCode.vhd:179:25  */
  always @*
    case (n3889_o)
      8'b10000000: n3891_o = n3886_o;
      8'b01000000: n3891_o = n3883_o;
      8'b00100000: n3891_o = n3879_o;
      8'b00010000: n3891_o = n3876_o;
      8'b00001000: n3891_o = n3872_o;
      8'b00000100: n3891_o = n3869_o;
      8'b00000010: n3891_o = n3865_o;
      8'b00000001: n3891_o = n3862_o;
      default: n3891_o = 1'bX;
    endcase
  /* T80_MCode.vhd:167:17  */
  assign n3892_o = n3831_o ? n3860_o : n3891_o;
  /* T80_MCode.vhd:999:41  */
  assign n3895_o = n3892_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:996:33  */
  assign n3897_o = n3820_o == 31'b0000000000000000000000000000011;
  assign n3898_o = {n3897_o, n3822_o};
  /* T80_MCode.vhd:992:33  */
  always @*
    case (n3898_o)
      2'b10: n3902_o = 1'b1;
      2'b01: n3902_o = 1'b1;
      default: n3902_o = 1'b0;
    endcase
  /* T80_MCode.vhd:992:33  */
  always @*
    case (n3898_o)
      2'b10: n3904_o = n3895_o;
      2'b01: n3904_o = 1'b0;
      default: n3904_o = 1'b0;
    endcase
  /* T80_MCode.vhd:992:33  */
  always @*
    case (n3898_o)
      2'b10: n3907_o = 1'b0;
      2'b01: n3907_o = 1'b1;
      default: n3907_o = 1'b0;
    endcase
  /* T80_MCode.vhd:992:33  */
  always @*
    case (n3898_o)
      2'b10: n3910_o = 1'b1;
      2'b01: n3910_o = 1'b0;
      default: n3910_o = 1'b0;
    endcase
  /* T80_MCode.vhd:934:25  */
  assign n3912_o = n3705_o ? n3799_o : 3'b011;
  /* T80_MCode.vhd:934:25  */
  assign n3913_o = n3705_o ? n3802_o : n3902_o;
  /* T80_MCode.vhd:934:25  */
  assign n3915_o = n3705_o ? n3805_o : 1'b0;
  /* T80_MCode.vhd:934:25  */
  assign n3917_o = n3705_o ? n3808_o : 4'b0000;
  /* T80_MCode.vhd:934:25  */
  assign n3919_o = n3705_o ? n3810_o : 3'b111;
  /* T80_MCode.vhd:934:25  */
  assign n3921_o = n3705_o ? n3813_o : 1'b0;
  /* T80_MCode.vhd:934:25  */
  assign n3923_o = n3705_o ? 1'b0 : n3904_o;
  /* T80_MCode.vhd:934:25  */
  assign n3924_o = n3705_o ? n3816_o : n3907_o;
  /* T80_MCode.vhd:934:25  */
  assign n3926_o = n3705_o ? 1'b0 : n3910_o;
  /* T80_MCode.vhd:934:25  */
  assign n3928_o = n3705_o ? n3819_o : 1'b0;
  /* T80_MCode.vhd:933:17  */
  assign n3930_o = ir == 8'b11000010;
  /* T80_MCode.vhd:933:32  */
  assign n3932_o = ir == 8'b11001010;
  /* T80_MCode.vhd:933:32  */
  assign n3933_o = n3930_o | n3932_o;
  /* T80_MCode.vhd:933:43  */
  assign n3935_o = ir == 8'b11010010;
  /* T80_MCode.vhd:933:43  */
  assign n3936_o = n3933_o | n3935_o;
  /* T80_MCode.vhd:933:54  */
  assign n3938_o = ir == 8'b11011010;
  /* T80_MCode.vhd:933:54  */
  assign n3939_o = n3936_o | n3938_o;
  /* T80_MCode.vhd:933:65  */
  assign n3941_o = ir == 8'b11100010;
  /* T80_MCode.vhd:933:65  */
  assign n3942_o = n3939_o | n3941_o;
  /* T80_MCode.vhd:933:76  */
  assign n3944_o = ir == 8'b11101010;
  /* T80_MCode.vhd:933:76  */
  assign n3945_o = n3942_o | n3944_o;
  /* T80_MCode.vhd:933:87  */
  assign n3947_o = ir == 8'b11110010;
  /* T80_MCode.vhd:933:87  */
  assign n3948_o = n3945_o | n3947_o;
  /* T80_MCode.vhd:933:98  */
  assign n3950_o = ir == 8'b11111010;
  /* T80_MCode.vhd:933:98  */
  assign n3951_o = n3948_o | n3950_o;
  /* T80_MCode.vhd:1006:37  */
  assign n3952_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1006:37  */
  assign n3954_o = n3952_o != 32'b00000000000000000000000000000010;
  /* T80_MCode.vhd:1009:38  */
  assign n3955_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1010:33  */
  assign n3957_o = n3955_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1012:33  */
  assign n3959_o = n3955_o == 31'b0000000000000000000000000000011;
  assign n3960_o = {n3959_o, n3957_o};
  /* T80_MCode.vhd:1009:33  */
  always @*
    case (n3960_o)
      2'b10: n3962_o = 3'b101;
      2'b01: n3962_o = n2122_o;
      default: n3962_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1009:33  */
  always @*
    case (n3960_o)
      2'b10: n3965_o = 1'b0;
      2'b01: n3965_o = 1'b1;
      default: n3965_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1009:33  */
  always @*
    case (n3960_o)
      2'b10: n3968_o = 1'b1;
      2'b01: n3968_o = 1'b0;
      default: n3968_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1009:33  */
  always @*
    case (n3960_o)
      2'b10: n3971_o = 1'b1;
      2'b01: n3971_o = 1'b0;
      default: n3971_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1006:25  */
  assign n3974_o = n3954_o ? 3'b011 : 3'b001;
  /* T80_MCode.vhd:1006:25  */
  assign n3975_o = n3954_o ? n3962_o : n2122_o;
  /* T80_MCode.vhd:1006:25  */
  assign n3977_o = n3954_o ? n3965_o : 1'b0;
  /* T80_MCode.vhd:1006:25  */
  assign n3979_o = n3954_o ? n3968_o : 1'b0;
  /* T80_MCode.vhd:1006:25  */
  assign n3981_o = n3954_o ? n3971_o : 1'b0;
  /* T80_MCode.vhd:1005:17  */
  assign n3983_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1020:37  */
  assign n3984_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1020:37  */
  assign n3986_o = n3984_o != 32'b00000000000000000000000000000010;
  /* T80_MCode.vhd:1023:38  */
  assign n3987_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1026:45  */
  assign n3988_o = f[0];
  /* T80_MCode.vhd:1026:54  */
  assign n3989_o = ~n3988_o;
  /* T80_MCode.vhd:1026:41  */
  assign n3992_o = n3989_o ? 3'b010 : 3'b011;
  /* T80_MCode.vhd:1024:33  */
  assign n3994_o = n3987_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1029:33  */
  assign n3996_o = n3987_o == 31'b0000000000000000000000000000011;
  assign n3997_o = {n3996_o, n3994_o};
  /* T80_MCode.vhd:1023:33  */
  always @*
    case (n3997_o)
      2'b10: n3999_o = 3'b011;
      2'b01: n3999_o = n3992_o;
      default: n3999_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1023:33  */
  always @*
    case (n3997_o)
      2'b10: n4002_o = 3'b101;
      2'b01: n4002_o = n2122_o;
      default: n4002_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1023:33  */
  always @*
    case (n3997_o)
      2'b10: n4005_o = 1'b0;
      2'b01: n4005_o = 1'b1;
      default: n4005_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1023:33  */
  always @*
    case (n3997_o)
      2'b10: n4008_o = 1'b1;
      2'b01: n4008_o = 1'b0;
      default: n4008_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1023:33  */
  always @*
    case (n3997_o)
      2'b10: n4011_o = 1'b1;
      2'b01: n4011_o = 1'b0;
      default: n4011_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1020:25  */
  assign n4013_o = n3986_o ? n3999_o : 3'b001;
  /* T80_MCode.vhd:1020:25  */
  assign n4014_o = n3986_o ? n4002_o : n2122_o;
  /* T80_MCode.vhd:1020:25  */
  assign n4016_o = n3986_o ? n4005_o : 1'b0;
  /* T80_MCode.vhd:1020:25  */
  assign n4018_o = n3986_o ? n4008_o : 1'b0;
  /* T80_MCode.vhd:1020:25  */
  assign n4020_o = n3986_o ? n4011_o : 1'b0;
  /* T80_MCode.vhd:1019:17  */
  assign n4022_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1037:37  */
  assign n4023_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1037:37  */
  assign n4025_o = n4023_o != 32'b00000000000000000000000000000010;
  /* T80_MCode.vhd:1040:38  */
  assign n4026_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1043:45  */
  assign n4027_o = f[0];
  /* T80_MCode.vhd:1043:41  */
  assign n4030_o = n4027_o ? 3'b010 : 3'b011;
  /* T80_MCode.vhd:1041:33  */
  assign n4032_o = n4026_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1046:33  */
  assign n4034_o = n4026_o == 31'b0000000000000000000000000000011;
  assign n4035_o = {n4034_o, n4032_o};
  /* T80_MCode.vhd:1040:33  */
  always @*
    case (n4035_o)
      2'b10: n4037_o = 3'b011;
      2'b01: n4037_o = n4030_o;
      default: n4037_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1040:33  */
  always @*
    case (n4035_o)
      2'b10: n4040_o = 3'b101;
      2'b01: n4040_o = n2122_o;
      default: n4040_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1040:33  */
  always @*
    case (n4035_o)
      2'b10: n4043_o = 1'b0;
      2'b01: n4043_o = 1'b1;
      default: n4043_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1040:33  */
  always @*
    case (n4035_o)
      2'b10: n4046_o = 1'b1;
      2'b01: n4046_o = 1'b0;
      default: n4046_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1040:33  */
  always @*
    case (n4035_o)
      2'b10: n4049_o = 1'b1;
      2'b01: n4049_o = 1'b0;
      default: n4049_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1037:25  */
  assign n4051_o = n4025_o ? n4037_o : 3'b001;
  /* T80_MCode.vhd:1037:25  */
  assign n4052_o = n4025_o ? n4040_o : n2122_o;
  /* T80_MCode.vhd:1037:25  */
  assign n4054_o = n4025_o ? n4043_o : 1'b0;
  /* T80_MCode.vhd:1037:25  */
  assign n4056_o = n4025_o ? n4046_o : 1'b0;
  /* T80_MCode.vhd:1037:25  */
  assign n4058_o = n4025_o ? n4049_o : 1'b0;
  /* T80_MCode.vhd:1036:17  */
  assign n4060_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1054:37  */
  assign n4061_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1054:37  */
  assign n4063_o = n4061_o != 32'b00000000000000000000000000000010;
  /* T80_MCode.vhd:1057:38  */
  assign n4064_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1060:45  */
  assign n4065_o = f[6];
  /* T80_MCode.vhd:1060:54  */
  assign n4066_o = ~n4065_o;
  /* T80_MCode.vhd:1060:41  */
  assign n4069_o = n4066_o ? 3'b010 : 3'b011;
  /* T80_MCode.vhd:1058:33  */
  assign n4071_o = n4064_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1063:33  */
  assign n4073_o = n4064_o == 31'b0000000000000000000000000000011;
  assign n4074_o = {n4073_o, n4071_o};
  /* T80_MCode.vhd:1057:33  */
  always @*
    case (n4074_o)
      2'b10: n4076_o = 3'b011;
      2'b01: n4076_o = n4069_o;
      default: n4076_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1057:33  */
  always @*
    case (n4074_o)
      2'b10: n4079_o = 3'b101;
      2'b01: n4079_o = n2122_o;
      default: n4079_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1057:33  */
  always @*
    case (n4074_o)
      2'b10: n4082_o = 1'b0;
      2'b01: n4082_o = 1'b1;
      default: n4082_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1057:33  */
  always @*
    case (n4074_o)
      2'b10: n4085_o = 1'b1;
      2'b01: n4085_o = 1'b0;
      default: n4085_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1057:33  */
  always @*
    case (n4074_o)
      2'b10: n4088_o = 1'b1;
      2'b01: n4088_o = 1'b0;
      default: n4088_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1054:25  */
  assign n4090_o = n4063_o ? n4076_o : 3'b001;
  /* T80_MCode.vhd:1054:25  */
  assign n4091_o = n4063_o ? n4079_o : n2122_o;
  /* T80_MCode.vhd:1054:25  */
  assign n4093_o = n4063_o ? n4082_o : 1'b0;
  /* T80_MCode.vhd:1054:25  */
  assign n4095_o = n4063_o ? n4085_o : 1'b0;
  /* T80_MCode.vhd:1054:25  */
  assign n4097_o = n4063_o ? n4088_o : 1'b0;
  /* T80_MCode.vhd:1053:17  */
  assign n4099_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1071:37  */
  assign n4100_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1071:37  */
  assign n4102_o = n4100_o != 32'b00000000000000000000000000000010;
  /* T80_MCode.vhd:1074:38  */
  assign n4103_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1077:45  */
  assign n4104_o = f[6];
  /* T80_MCode.vhd:1077:41  */
  assign n4107_o = n4104_o ? 3'b010 : 3'b011;
  /* T80_MCode.vhd:1075:33  */
  assign n4109_o = n4103_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1080:33  */
  assign n4111_o = n4103_o == 31'b0000000000000000000000000000011;
  assign n4112_o = {n4111_o, n4109_o};
  /* T80_MCode.vhd:1074:33  */
  always @*
    case (n4112_o)
      2'b10: n4114_o = 3'b011;
      2'b01: n4114_o = n4107_o;
      default: n4114_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1074:33  */
  always @*
    case (n4112_o)
      2'b10: n4117_o = 3'b101;
      2'b01: n4117_o = n2122_o;
      default: n4117_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1074:33  */
  always @*
    case (n4112_o)
      2'b10: n4120_o = 1'b0;
      2'b01: n4120_o = 1'b1;
      default: n4120_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1074:33  */
  always @*
    case (n4112_o)
      2'b10: n4123_o = 1'b1;
      2'b01: n4123_o = 1'b0;
      default: n4123_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1074:33  */
  always @*
    case (n4112_o)
      2'b10: n4126_o = 1'b1;
      2'b01: n4126_o = 1'b0;
      default: n4126_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1071:25  */
  assign n4128_o = n4102_o ? n4114_o : 3'b001;
  /* T80_MCode.vhd:1071:25  */
  assign n4129_o = n4102_o ? n4117_o : n2122_o;
  /* T80_MCode.vhd:1071:25  */
  assign n4131_o = n4102_o ? n4120_o : 1'b0;
  /* T80_MCode.vhd:1071:25  */
  assign n4133_o = n4102_o ? n4123_o : 1'b0;
  /* T80_MCode.vhd:1071:25  */
  assign n4135_o = n4102_o ? n4126_o : 1'b0;
  /* T80_MCode.vhd:1070:17  */
  assign n4137_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1087:17  */
  assign n4139_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1091:37  */
  assign n4140_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1091:37  */
  assign n4142_o = n4140_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:1093:40  */
  assign n4143_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1093:40  */
  assign n4145_o = $signed(n4143_o) < $signed(32'b00000000000000000000000000000010);
  /* T80_MCode.vhd:1096:38  */
  assign n4146_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1097:33  */
  assign n4149_o = n4146_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1105:33  */
  assign n4151_o = n4146_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1108:33  */
  assign n4153_o = n4146_o == 31'b0000000000000000000000000000011;
  assign n4154_o = {n4153_o, n4151_o, n4149_o};
  /* T80_MCode.vhd:1096:33  */
  always @*
    case (n4154_o)
      3'b100: n4157_o = 3'b101;
      3'b010: n4157_o = n2122_o;
      3'b001: n4157_o = 3'b101;
      default: n4157_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1096:33  */
  always @*
    case (n4154_o)
      3'b100: n4160_o = 1'b0;
      3'b010: n4160_o = 1'b1;
      3'b001: n4160_o = 1'b0;
      default: n4160_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1096:33  */
  always @*
    case (n4154_o)
      3'b100: n4163_o = 1'b0;
      3'b010: n4163_o = 1'b0;
      3'b001: n4163_o = 1'b1;
      default: n4163_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1096:33  */
  always @*
    case (n4154_o)
      3'b100: n4165_o = 3'b000;
      3'b010: n4165_o = 3'b000;
      3'b001: n4165_o = 3'b000;
      default: n4165_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1096:33  */
  always @*
    case (n4154_o)
      3'b100: n4168_o = 4'b0000;
      3'b010: n4168_o = 4'b0000;
      3'b001: n4168_o = 4'b1010;
      default: n4168_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1096:33  */
  always @*
    case (n4154_o)
      3'b100: n4170_o = n2125_o;
      3'b010: n4170_o = n2125_o;
      3'b001: n4170_o = 4'b0010;
      default: n4170_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1096:33  */
  always @*
    case (n4154_o)
      3'b100: n4173_o = 1'b0;
      3'b010: n4173_o = 1'b0;
      3'b001: n4173_o = 1'b1;
      default: n4173_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1096:33  */
  always @*
    case (n4154_o)
      3'b100: n4176_o = 1'b1;
      3'b010: n4176_o = 1'b0;
      3'b001: n4176_o = 1'b0;
      default: n4176_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1096:33  */
  always @*
    case (n4154_o)
      3'b100: n4180_o = 1'b0;
      3'b010: n4180_o = 1'b1;
      3'b001: n4180_o = 1'b1;
      default: n4180_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1096:33  */
  always @*
    case (n4154_o)
      3'b100: n4183_o = 1'b1;
      3'b010: n4183_o = 1'b0;
      3'b001: n4183_o = 1'b0;
      default: n4183_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1093:25  */
  assign n4186_o = n4145_o ? 3'b011 : 3'b001;
  /* T80_MCode.vhd:1093:25  */
  assign n4187_o = n4145_o ? n4157_o : n2122_o;
  /* T80_MCode.vhd:1093:25  */
  assign n4189_o = n4145_o ? n4160_o : 1'b0;
  /* T80_MCode.vhd:1093:25  */
  assign n4191_o = n4145_o ? n4163_o : 1'b0;
  /* T80_MCode.vhd:1093:25  */
  assign n4193_o = n4145_o ? n4165_o : 3'b000;
  /* T80_MCode.vhd:1093:25  */
  assign n4195_o = n4145_o ? n4168_o : 4'b0000;
  /* T80_MCode.vhd:1093:25  */
  assign n4196_o = n4145_o ? n4170_o : n2125_o;
  /* T80_MCode.vhd:1093:25  */
  assign n4198_o = n4145_o ? n4173_o : 1'b0;
  /* T80_MCode.vhd:1093:25  */
  assign n4200_o = n4145_o ? n4176_o : 1'b0;
  /* T80_MCode.vhd:1093:25  */
  assign n4202_o = n4145_o ? n4180_o : 1'b0;
  /* T80_MCode.vhd:1093:25  */
  assign n4204_o = n4145_o ? n4183_o : 1'b0;
  /* T80_MCode.vhd:1091:25  */
  assign n4206_o = n4142_o ? 3'b001 : n4186_o;
  /* T80_MCode.vhd:1091:25  */
  assign n4207_o = n4142_o ? n2122_o : n4187_o;
  /* T80_MCode.vhd:1091:25  */
  assign n4209_o = n4142_o ? 1'b0 : n4189_o;
  /* T80_MCode.vhd:1091:25  */
  assign n4211_o = n4142_o ? 1'b0 : n4191_o;
  /* T80_MCode.vhd:1091:25  */
  assign n4213_o = n4142_o ? 3'b000 : n4193_o;
  /* T80_MCode.vhd:1091:25  */
  assign n4215_o = n4142_o ? 4'b0000 : n4195_o;
  /* T80_MCode.vhd:1091:25  */
  assign n4216_o = n4142_o ? n2125_o : n4196_o;
  /* T80_MCode.vhd:1091:25  */
  assign n4218_o = n4142_o ? 1'b0 : n4198_o;
  /* T80_MCode.vhd:1091:25  */
  assign n4220_o = n4142_o ? 1'b0 : n4200_o;
  /* T80_MCode.vhd:1091:25  */
  assign n4222_o = n4142_o ? 1'b1 : n4202_o;
  /* T80_MCode.vhd:1091:25  */
  assign n4224_o = n4142_o ? 1'b0 : n4204_o;
  /* T80_MCode.vhd:1090:17  */
  assign n4226_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1120:30  */
  assign n4227_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1121:25  */
  assign n4229_o = n4227_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1124:25  */
  assign n4231_o = n4227_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1131:25  */
  assign n4233_o = n4227_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1136:25  */
  assign n4235_o = n4227_o == 31'b0000000000000000000000000000101;
  assign n4236_o = {n4235_o, n4233_o, n4231_o, n4229_o};
  /* T80_MCode.vhd:1120:25  */
  always @*
    case (n4236_o)
      4'b1000: n4238_o = n2122_o;
      4'b0100: n4238_o = n2122_o;
      4'b0010: n4238_o = 3'b100;
      4'b0001: n4238_o = n2122_o;
      default: n4238_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1120:25  */
  always @*
    case (n4236_o)
      4'b1000: n4242_o = 1'b0;
      4'b0100: n4242_o = 1'b0;
      4'b0010: n4242_o = 1'b1;
      4'b0001: n4242_o = 1'b1;
      default: n4242_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1120:25  */
  always @*
    case (n4236_o)
      4'b1000: n4246_o = 4'b0000;
      4'b0100: n4246_o = 4'b1111;
      4'b0010: n4246_o = 4'b1111;
      4'b0001: n4246_o = 4'b0000;
      default: n4246_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1120:25  */
  always @*
    case (n4236_o)
      4'b1000: n4250_o = 4'b0000;
      4'b0100: n4250_o = 4'b1100;
      4'b0010: n4250_o = 4'b1101;
      4'b0001: n4250_o = 4'b0000;
      default: n4250_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1120:25  */
  always @*
    case (n4236_o)
      4'b1000: n4254_o = 3'b111;
      4'b0100: n4254_o = 3'b101;
      4'b0010: n4254_o = 3'b101;
      4'b0001: n4254_o = 3'b111;
      default: n4254_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1120:25  */
  always @*
    case (n4236_o)
      4'b1000: n4257_o = 1'b1;
      4'b0100: n4257_o = 1'b0;
      4'b0010: n4257_o = 1'b0;
      4'b0001: n4257_o = 1'b0;
      default: n4257_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1120:25  */
  always @*
    case (n4236_o)
      4'b1000: n4260_o = 1'b0;
      4'b0100: n4260_o = 1'b0;
      4'b0010: n4260_o = 1'b0;
      4'b0001: n4260_o = 1'b1;
      default: n4260_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1120:25  */
  always @*
    case (n4236_o)
      4'b1000: n4263_o = 1'b0;
      4'b0100: n4263_o = 1'b0;
      4'b0010: n4263_o = 1'b1;
      4'b0001: n4263_o = 1'b0;
      default: n4263_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1120:25  */
  always @*
    case (n4236_o)
      4'b1000: n4267_o = 1'b1;
      4'b0100: n4267_o = 1'b1;
      4'b0010: n4267_o = 1'b0;
      4'b0001: n4267_o = 1'b0;
      default: n4267_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1117:17  */
  assign n4269_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1142:30  */
  assign n4270_o = ir[5];
  /* T80_MCode.vhd:1142:34  */
  assign n4271_o = ~n4270_o;
  /* T80_MCode.vhd:1142:52  */
  assign n4272_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1142:52  */
  assign n4274_o = n4272_o != 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:1142:40  */
  assign n4275_o = n4271_o | n4274_o;
  /* T80_MCode.vhd:1145:38  */
  assign n4276_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1146:33  */
  assign n4278_o = n4276_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1152:73  */
  assign n4280_o = ir[5:3];
  /* T80_MCode.vhd:1152:88  */
  assign n4281_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:167:29  */
  assign n4287_o = n4281_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:169:47  */
  assign n4288_o = f[7];
  /* T80_MCode.vhd:169:56  */
  assign n4289_o = ~n4288_o;
  /* T80_MCode.vhd:169:25  */
  assign n4291_o = n4280_o == 3'b000;
  /* T80_MCode.vhd:170:47  */
  assign n4292_o = f[7];
  /* T80_MCode.vhd:170:25  */
  assign n4294_o = n4280_o == 3'b001;
  /* T80_MCode.vhd:171:47  */
  assign n4295_o = f[4];
  /* T80_MCode.vhd:171:56  */
  assign n4296_o = ~n4295_o;
  /* T80_MCode.vhd:171:25  */
  assign n4298_o = n4280_o == 3'b010;
  /* T80_MCode.vhd:172:47  */
  assign n4299_o = f[4];
  /* T80_MCode.vhd:172:25  */
  assign n4301_o = n4280_o == 3'b011;
  /* T80_MCode.vhd:173:25  */
  assign n4304_o = n4280_o == 3'b100;
  /* T80_MCode.vhd:174:25  */
  assign n4307_o = n4280_o == 3'b101;
  /* T80_MCode.vhd:175:25  */
  assign n4310_o = n4280_o == 3'b110;
  /* T80_MCode.vhd:176:25  */
  assign n4313_o = n4280_o == 3'b111;
  assign n4314_o = {n4313_o, n4310_o, n4307_o, n4304_o, n4301_o, n4298_o, n4294_o, n4291_o};
  /* T80_MCode.vhd:168:25  */
  always @*
    case (n4314_o)
      8'b10000000: n4316_o = 1'b0;
      8'b01000000: n4316_o = 1'b0;
      8'b00100000: n4316_o = 1'b0;
      8'b00010000: n4316_o = 1'b0;
      8'b00001000: n4316_o = n4299_o;
      8'b00000100: n4316_o = n4296_o;
      8'b00000010: n4316_o = n4292_o;
      8'b00000001: n4316_o = n4289_o;
      default: n4316_o = 1'bX;
    endcase
  /* T80_MCode.vhd:180:47  */
  assign n4317_o = f[6];
  /* T80_MCode.vhd:180:56  */
  assign n4318_o = ~n4317_o;
  /* T80_MCode.vhd:180:25  */
  assign n4320_o = n4280_o == 3'b000;
  /* T80_MCode.vhd:181:47  */
  assign n4321_o = f[6];
  /* T80_MCode.vhd:181:25  */
  assign n4323_o = n4280_o == 3'b001;
  /* T80_MCode.vhd:182:47  */
  assign n4324_o = f[0];
  /* T80_MCode.vhd:182:56  */
  assign n4325_o = ~n4324_o;
  /* T80_MCode.vhd:182:25  */
  assign n4327_o = n4280_o == 3'b010;
  /* T80_MCode.vhd:183:47  */
  assign n4328_o = f[0];
  /* T80_MCode.vhd:183:25  */
  assign n4330_o = n4280_o == 3'b011;
  /* T80_MCode.vhd:184:47  */
  assign n4331_o = f[2];
  /* T80_MCode.vhd:184:56  */
  assign n4332_o = ~n4331_o;
  /* T80_MCode.vhd:184:25  */
  assign n4334_o = n4280_o == 3'b100;
  /* T80_MCode.vhd:185:47  */
  assign n4335_o = f[2];
  /* T80_MCode.vhd:185:25  */
  assign n4337_o = n4280_o == 3'b101;
  /* T80_MCode.vhd:186:47  */
  assign n4338_o = f[7];
  /* T80_MCode.vhd:186:56  */
  assign n4339_o = ~n4338_o;
  /* T80_MCode.vhd:186:25  */
  assign n4341_o = n4280_o == 3'b110;
  /* T80_MCode.vhd:187:47  */
  assign n4342_o = f[7];
  /* T80_MCode.vhd:187:25  */
  assign n4344_o = n4280_o == 3'b111;
  assign n4345_o = {n4344_o, n4341_o, n4337_o, n4334_o, n4330_o, n4327_o, n4323_o, n4320_o};
  /* T80_MCode.vhd:179:25  */
  always @*
    case (n4345_o)
      8'b10000000: n4347_o = n4342_o;
      8'b01000000: n4347_o = n4339_o;
      8'b00100000: n4347_o = n4335_o;
      8'b00010000: n4347_o = n4332_o;
      8'b00001000: n4347_o = n4328_o;
      8'b00000100: n4347_o = n4325_o;
      8'b00000010: n4347_o = n4321_o;
      8'b00000001: n4347_o = n4318_o;
      default: n4347_o = 1'bX;
    endcase
  /* T80_MCode.vhd:167:17  */
  assign n4348_o = n4287_o ? n4316_o : n4347_o;
  /* T80_MCode.vhd:1152:41  */
  assign n4351_o = n4348_o ? 3'b101 : 3'b011;
  /* T80_MCode.vhd:1152:41  */
  assign n4353_o = n4348_o ? 3'b100 : n2122_o;
  /* T80_MCode.vhd:1152:41  */
  assign n4356_o = n4348_o ? 4'b1111 : 4'b0000;
  /* T80_MCode.vhd:1152:41  */
  assign n4359_o = n4348_o ? 4'b1101 : 4'b0000;
  /* T80_MCode.vhd:1152:41  */
  assign n4362_o = n4348_o ? 3'b101 : 3'b111;
  /* T80_MCode.vhd:1149:33  */
  assign n4364_o = n4276_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1160:33  */
  assign n4366_o = n4276_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1165:33  */
  assign n4368_o = n4276_o == 31'b0000000000000000000000000000101;
  assign n4369_o = {n4368_o, n4366_o, n4364_o, n4278_o};
  /* T80_MCode.vhd:1145:33  */
  always @*
    case (n4369_o)
      4'b1000: n4371_o = 3'b101;
      4'b0100: n4371_o = 3'b101;
      4'b0010: n4371_o = n4351_o;
      4'b0001: n4371_o = 3'b101;
      default: n4371_o = 3'b101;
    endcase
  /* T80_MCode.vhd:1145:33  */
  always @*
    case (n4369_o)
      4'b1000: n4373_o = n2122_o;
      4'b0100: n4373_o = n2122_o;
      4'b0010: n4373_o = n4353_o;
      4'b0001: n4373_o = n2122_o;
      default: n4373_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1145:33  */
  always @*
    case (n4369_o)
      4'b1000: n4377_o = 1'b0;
      4'b0100: n4377_o = 1'b0;
      4'b0010: n4377_o = 1'b1;
      4'b0001: n4377_o = 1'b1;
      default: n4377_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1145:33  */
  always @*
    case (n4369_o)
      4'b1000: n4380_o = 4'b0000;
      4'b0100: n4380_o = 4'b1111;
      4'b0010: n4380_o = n4356_o;
      4'b0001: n4380_o = 4'b0000;
      default: n4380_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1145:33  */
  always @*
    case (n4369_o)
      4'b1000: n4383_o = 4'b0000;
      4'b0100: n4383_o = 4'b1100;
      4'b0010: n4383_o = n4359_o;
      4'b0001: n4383_o = 4'b0000;
      default: n4383_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1145:33  */
  always @*
    case (n4369_o)
      4'b1000: n4386_o = 3'b111;
      4'b0100: n4386_o = 3'b101;
      4'b0010: n4386_o = n4362_o;
      4'b0001: n4386_o = 3'b111;
      default: n4386_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1145:33  */
  always @*
    case (n4369_o)
      4'b1000: n4389_o = 1'b1;
      4'b0100: n4389_o = 1'b0;
      4'b0010: n4389_o = 1'b0;
      4'b0001: n4389_o = 1'b0;
      default: n4389_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1145:33  */
  always @*
    case (n4369_o)
      4'b1000: n4392_o = 1'b0;
      4'b0100: n4392_o = 1'b0;
      4'b0010: n4392_o = 1'b0;
      4'b0001: n4392_o = 1'b1;
      default: n4392_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1145:33  */
  always @*
    case (n4369_o)
      4'b1000: n4395_o = 1'b0;
      4'b0100: n4395_o = 1'b0;
      4'b0010: n4395_o = 1'b1;
      4'b0001: n4395_o = 1'b0;
      default: n4395_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1145:33  */
  always @*
    case (n4369_o)
      4'b1000: n4399_o = 1'b1;
      4'b0100: n4399_o = 1'b1;
      4'b0010: n4399_o = 1'b0;
      4'b0001: n4399_o = 1'b0;
      default: n4399_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1142:25  */
  assign n4401_o = n4275_o ? n4371_o : 3'b001;
  /* T80_MCode.vhd:1142:25  */
  assign n4402_o = n4275_o ? n4373_o : n2122_o;
  /* T80_MCode.vhd:1142:25  */
  assign n4404_o = n4275_o ? n4377_o : 1'b0;
  /* T80_MCode.vhd:1142:25  */
  assign n4406_o = n4275_o ? n4380_o : 4'b0000;
  /* T80_MCode.vhd:1142:25  */
  assign n4408_o = n4275_o ? n4383_o : 4'b0000;
  /* T80_MCode.vhd:1142:25  */
  assign n4410_o = n4275_o ? n4386_o : 3'b111;
  /* T80_MCode.vhd:1142:25  */
  assign n4412_o = n4275_o ? n4389_o : 1'b0;
  /* T80_MCode.vhd:1142:25  */
  assign n4414_o = n4275_o ? n4392_o : 1'b0;
  /* T80_MCode.vhd:1142:25  */
  assign n4416_o = n4275_o ? n4395_o : 1'b0;
  /* T80_MCode.vhd:1142:25  */
  assign n4418_o = n4275_o ? n4399_o : 1'b0;
  /* T80_MCode.vhd:1141:17  */
  assign n4420_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1141:32  */
  assign n4422_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1141:32  */
  assign n4423_o = n4420_o | n4422_o;
  /* T80_MCode.vhd:1141:43  */
  assign n4425_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1141:43  */
  assign n4426_o = n4423_o | n4425_o;
  /* T80_MCode.vhd:1141:54  */
  assign n4428_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1141:54  */
  assign n4429_o = n4426_o | n4428_o;
  /* T80_MCode.vhd:1141:65  */
  assign n4431_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1141:65  */
  assign n4432_o = n4429_o | n4431_o;
  /* T80_MCode.vhd:1141:76  */
  assign n4434_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1141:76  */
  assign n4435_o = n4432_o | n4434_o;
  /* T80_MCode.vhd:1141:87  */
  assign n4437_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1141:87  */
  assign n4438_o = n4435_o | n4437_o;
  /* T80_MCode.vhd:1141:98  */
  assign n4440_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1141:98  */
  assign n4441_o = n4438_o | n4440_o;
  /* T80_MCode.vhd:1174:30  */
  assign n4442_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1175:25  */
  assign n4444_o = n4442_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1178:25  */
  assign n4446_o = n4442_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1182:25  */
  assign n4448_o = n4442_o == 31'b0000000000000000000000000000011;
  assign n4449_o = {n4448_o, n4446_o, n4444_o};
  /* T80_MCode.vhd:1174:25  */
  always @*
    case (n4449_o)
      3'b100: n4453_o = 4'b0111;
      3'b010: n4453_o = 4'b0111;
      3'b001: n4453_o = 4'b0000;
      default: n4453_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1174:25  */
  always @*
    case (n4449_o)
      3'b100: n4457_o = 3'b111;
      3'b010: n4457_o = 3'b101;
      3'b001: n4457_o = 3'b101;
      default: n4457_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1174:25  */
  always @*
    case (n4449_o)
      3'b100: n4460_o = 1'b1;
      3'b010: n4460_o = 1'b0;
      3'b001: n4460_o = 1'b0;
      default: n4460_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1174:25  */
  always @*
    case (n4449_o)
      3'b100: n4463_o = 1'b0;
      3'b010: n4463_o = 1'b1;
      3'b001: n4463_o = 1'b0;
      default: n4463_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1171:17  */
  assign n4465_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1188:30  */
  assign n4466_o = ir[5];
  /* T80_MCode.vhd:1188:53  */
  assign n4467_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1188:53  */
  assign n4469_o = n4467_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:1188:40  */
  assign n4470_o = n4469_o & n4466_o;
  /* T80_MCode.vhd:1189:41  */
  assign n4471_o = ir[4:3];
  /* T80_MCode.vhd:1193:46  */
  assign n4472_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1194:41  */
  assign n4474_o = n4472_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1198:41  */
  assign n4476_o = n4472_o == 31'b0000000000000000000000000000011;
  assign n4477_o = {n4476_o, n4474_o};
  /* T80_MCode.vhd:1193:41  */
  always @*
    case (n4477_o)
      2'b10: n4480_o = 1'b0;
      2'b01: n4480_o = 1'b1;
      default: n4480_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1193:41  */
  always @*
    case (n4477_o)
      2'b10: n4483_o = 4'b0000;
      2'b01: n4483_o = 4'b0111;
      default: n4483_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1193:41  */
  always @*
    case (n4477_o)
      2'b10: n4486_o = 3'b111;
      2'b01: n4486_o = 3'b100;
      default: n4486_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1193:41  */
  always @*
    case (n4477_o)
      2'b10: n4489_o = 1'b1;
      2'b01: n4489_o = 1'b0;
      default: n4489_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1190:33  */
  assign n4491_o = n4471_o == 2'b00;
  /* T80_MCode.vhd:1205:46  */
  assign n4492_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1206:41  */
  assign n4494_o = n4492_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1213:41  */
  assign n4496_o = n4492_o == 31'b0000000000000000000000000000011;
  assign n4497_o = {n4496_o, n4494_o};
  /* T80_MCode.vhd:1205:41  */
  always @*
    case (n4497_o)
      2'b10: n4500_o = 1'b0;
      2'b01: n4500_o = 1'b1;
      default: n4500_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1205:41  */
  always @*
    case (n4497_o)
      2'b10: n4504_o = 1'b1;
      2'b01: n4504_o = 1'b1;
      default: n4504_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1205:41  */
  always @*
    case (n4497_o)
      2'b10: n4508_o = 4'b1001;
      2'b01: n4508_o = 4'b1000;
      default: n4508_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1205:41  */
  always @*
    case (n4497_o)
      2'b10: n4512_o = 4'b1110;
      2'b01: n4512_o = 4'b0110;
      default: n4512_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1205:41  */
  always @*
    case (n4497_o)
      2'b10: n4515_o = 4'b0001;
      2'b01: n4515_o = 4'b0000;
      default: n4515_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1205:41  */
  always @*
    case (n4497_o)
      2'b10: n4519_o = 1'b1;
      2'b01: n4519_o = 1'b1;
      default: n4519_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1205:41  */
  always @*
    case (n4497_o)
      2'b10: n4522_o = 1'b1;
      2'b01: n4522_o = 1'b0;
      default: n4522_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1202:33  */
  assign n4524_o = n4471_o == 2'b01;
  /* T80_MCode.vhd:1225:46  */
  assign n4525_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1226:41  */
  assign n4527_o = n4525_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1229:41  */
  assign n4529_o = n4525_o == 31'b0000000000000000000000000000011;
  assign n4530_o = {n4529_o, n4527_o};
  /* T80_MCode.vhd:1225:41  */
  always @*
    case (n4530_o)
      2'b10: n4533_o = 1'b0;
      2'b01: n4533_o = 1'b1;
      default: n4533_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1225:41  */
  always @*
    case (n4530_o)
      2'b10: n4536_o = 1'b1;
      2'b01: n4536_o = 1'b0;
      default: n4536_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1225:41  */
  always @*
    case (n4530_o)
      2'b10: n4539_o = 3'b111;
      2'b01: n4539_o = 3'b100;
      default: n4539_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1222:33  */
  assign n4541_o = n4471_o == 2'b10;
  /* T80_MCode.vhd:1236:46  */
  assign n4542_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1237:41  */
  assign n4544_o = n4542_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1240:41  */
  assign n4546_o = n4542_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1244:41  */
  assign n4549_o = n4542_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1249:41  */
  assign n4552_o = n4542_o == 31'b0000000000000000000000000000101;
  assign n4553_o = {n4552_o, n4549_o, n4546_o, n4544_o};
  /* T80_MCode.vhd:1236:41  */
  always @*
    case (n4553_o)
      4'b1000: n4557_o = 1'b0;
      4'b0100: n4557_o = 1'b0;
      4'b0010: n4557_o = 1'b1;
      4'b0001: n4557_o = 1'b1;
      default: n4557_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1236:41  */
  always @*
    case (n4553_o)
      4'b1000: n4560_o = 1'b0;
      4'b0100: n4560_o = 1'b1;
      4'b0010: n4560_o = 1'b0;
      4'b0001: n4560_o = 1'b0;
      default: n4560_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1236:41  */
  always @*
    case (n4553_o)
      4'b1000: n4564_o = 1'b1;
      4'b0100: n4564_o = 1'b1;
      4'b0010: n4564_o = 1'b0;
      4'b0001: n4564_o = 1'b0;
      default: n4564_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1236:41  */
  always @*
    case (n4553_o)
      4'b1000: n4566_o = 3'b100;
      4'b0100: n4566_o = 3'b101;
      4'b0010: n4566_o = 3'b000;
      4'b0001: n4566_o = 3'b000;
      default: n4566_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1236:41  */
  always @*
    case (n4553_o)
      4'b1000: n4570_o = 3'b111;
      4'b0100: n4570_o = 3'b110;
      4'b0010: n4570_o = 3'b110;
      4'b0001: n4570_o = 3'b111;
      default: n4570_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1236:41  */
  always @*
    case (n4553_o)
      4'b1000: n4573_o = 1'b0;
      4'b0100: n4573_o = 1'b0;
      4'b0010: n4573_o = 1'b0;
      4'b0001: n4573_o = 1'b1;
      default: n4573_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1236:41  */
  always @*
    case (n4553_o)
      4'b1000: n4576_o = 1'b0;
      4'b0100: n4576_o = 1'b0;
      4'b0010: n4576_o = 1'b1;
      4'b0001: n4576_o = 1'b0;
      default: n4576_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1233:33  */
  assign n4578_o = n4471_o == 2'b11;
  assign n4579_o = {n4578_o, n4541_o, n4524_o, n4491_o};
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4585_o = 3'b101;
      4'b0100: n4585_o = 3'b011;
      4'b0010: n4585_o = 3'b011;
      4'b0001: n4585_o = 3'b011;
      default: n4585_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4587_o = n4557_o;
      4'b0100: n4587_o = n4533_o;
      4'b0010: n4587_o = n4500_o;
      4'b0001: n4587_o = n4480_o;
      default: n4587_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4590_o = n4560_o;
      4'b0100: n4590_o = 1'b0;
      4'b0010: n4590_o = 1'b0;
      4'b0001: n4590_o = 1'b0;
      default: n4590_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4593_o = n4564_o;
      4'b0100: n4593_o = 1'b0;
      4'b0010: n4593_o = n4504_o;
      4'b0001: n4593_o = 1'b0;
      default: n4593_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4596_o = 1'b0;
      4'b0100: n4596_o = n4536_o;
      4'b0010: n4596_o = 1'b0;
      4'b0001: n4596_o = 1'b0;
      default: n4596_o = 1'bX;
    endcase
  assign n4597_o = n4508_o[2:0];
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4600_o = n4566_o;
      4'b0100: n4600_o = 3'b000;
      4'b0010: n4600_o = n4597_o;
      4'b0001: n4600_o = 3'b000;
      default: n4600_o = 3'bX;
    endcase
  assign n4601_o = n4508_o[3];
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4604_o = 1'b0;
      4'b0100: n4604_o = 1'b0;
      4'b0010: n4604_o = n4601_o;
      4'b0001: n4604_o = 1'b0;
      default: n4604_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4607_o = 4'b0000;
      4'b0100: n4607_o = 4'b0000;
      4'b0010: n4607_o = n4512_o;
      4'b0001: n4607_o = n4483_o;
      default: n4607_o = 4'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4609_o = n2125_o;
      4'b0100: n4609_o = n2125_o;
      4'b0010: n4609_o = n4515_o;
      4'b0001: n4609_o = n2125_o;
      default: n4609_o = 4'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4612_o = 1'b0;
      4'b0100: n4612_o = 1'b0;
      4'b0010: n4612_o = n4519_o;
      4'b0001: n4612_o = 1'b0;
      default: n4612_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4615_o = n4570_o;
      4'b0100: n4615_o = n4539_o;
      4'b0010: n4615_o = 3'b111;
      4'b0001: n4615_o = n4486_o;
      default: n4615_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4618_o = n4573_o;
      4'b0100: n4618_o = 1'b0;
      4'b0010: n4618_o = 1'b0;
      4'b0001: n4618_o = 1'b0;
      default: n4618_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4621_o = n4576_o;
      4'b0100: n4621_o = 1'b0;
      4'b0010: n4621_o = 1'b0;
      4'b0001: n4621_o = 1'b0;
      default: n4621_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4624_o = 1'b0;
      4'b0100: n4624_o = 1'b0;
      4'b0010: n4624_o = n4522_o;
      4'b0001: n4624_o = 1'b0;
      default: n4624_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1189:33  */
  always @*
    case (n4579_o)
      4'b1000: n4627_o = 1'b0;
      4'b0100: n4627_o = 1'b0;
      4'b0010: n4627_o = 1'b0;
      4'b0001: n4627_o = n4489_o;
      default: n4627_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1258:38  */
  assign n4628_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1260:73  */
  assign n4630_o = ir[5:3];
  /* T80_MCode.vhd:1260:88  */
  assign n4631_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:167:29  */
  assign n4637_o = n4631_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:169:47  */
  assign n4638_o = f[7];
  /* T80_MCode.vhd:169:56  */
  assign n4639_o = ~n4638_o;
  /* T80_MCode.vhd:169:25  */
  assign n4641_o = n4630_o == 3'b000;
  /* T80_MCode.vhd:170:47  */
  assign n4642_o = f[7];
  /* T80_MCode.vhd:170:25  */
  assign n4644_o = n4630_o == 3'b001;
  /* T80_MCode.vhd:171:47  */
  assign n4645_o = f[4];
  /* T80_MCode.vhd:171:56  */
  assign n4646_o = ~n4645_o;
  /* T80_MCode.vhd:171:25  */
  assign n4648_o = n4630_o == 3'b010;
  /* T80_MCode.vhd:172:47  */
  assign n4649_o = f[4];
  /* T80_MCode.vhd:172:25  */
  assign n4651_o = n4630_o == 3'b011;
  /* T80_MCode.vhd:173:25  */
  assign n4654_o = n4630_o == 3'b100;
  /* T80_MCode.vhd:174:25  */
  assign n4657_o = n4630_o == 3'b101;
  /* T80_MCode.vhd:175:25  */
  assign n4660_o = n4630_o == 3'b110;
  /* T80_MCode.vhd:176:25  */
  assign n4663_o = n4630_o == 3'b111;
  assign n4664_o = {n4663_o, n4660_o, n4657_o, n4654_o, n4651_o, n4648_o, n4644_o, n4641_o};
  /* T80_MCode.vhd:168:25  */
  always @*
    case (n4664_o)
      8'b10000000: n4666_o = 1'b0;
      8'b01000000: n4666_o = 1'b0;
      8'b00100000: n4666_o = 1'b0;
      8'b00010000: n4666_o = 1'b0;
      8'b00001000: n4666_o = n4649_o;
      8'b00000100: n4666_o = n4646_o;
      8'b00000010: n4666_o = n4642_o;
      8'b00000001: n4666_o = n4639_o;
      default: n4666_o = 1'bX;
    endcase
  /* T80_MCode.vhd:180:47  */
  assign n4667_o = f[6];
  /* T80_MCode.vhd:180:56  */
  assign n4668_o = ~n4667_o;
  /* T80_MCode.vhd:180:25  */
  assign n4670_o = n4630_o == 3'b000;
  /* T80_MCode.vhd:181:47  */
  assign n4671_o = f[6];
  /* T80_MCode.vhd:181:25  */
  assign n4673_o = n4630_o == 3'b001;
  /* T80_MCode.vhd:182:47  */
  assign n4674_o = f[0];
  /* T80_MCode.vhd:182:56  */
  assign n4675_o = ~n4674_o;
  /* T80_MCode.vhd:182:25  */
  assign n4677_o = n4630_o == 3'b010;
  /* T80_MCode.vhd:183:47  */
  assign n4678_o = f[0];
  /* T80_MCode.vhd:183:25  */
  assign n4680_o = n4630_o == 3'b011;
  /* T80_MCode.vhd:184:47  */
  assign n4681_o = f[2];
  /* T80_MCode.vhd:184:56  */
  assign n4682_o = ~n4681_o;
  /* T80_MCode.vhd:184:25  */
  assign n4684_o = n4630_o == 3'b100;
  /* T80_MCode.vhd:185:47  */
  assign n4685_o = f[2];
  /* T80_MCode.vhd:185:25  */
  assign n4687_o = n4630_o == 3'b101;
  /* T80_MCode.vhd:186:47  */
  assign n4688_o = f[7];
  /* T80_MCode.vhd:186:56  */
  assign n4689_o = ~n4688_o;
  /* T80_MCode.vhd:186:25  */
  assign n4691_o = n4630_o == 3'b110;
  /* T80_MCode.vhd:187:47  */
  assign n4692_o = f[7];
  /* T80_MCode.vhd:187:25  */
  assign n4694_o = n4630_o == 3'b111;
  assign n4695_o = {n4694_o, n4691_o, n4687_o, n4684_o, n4680_o, n4677_o, n4673_o, n4670_o};
  /* T80_MCode.vhd:179:25  */
  always @*
    case (n4695_o)
      8'b10000000: n4697_o = n4692_o;
      8'b01000000: n4697_o = n4689_o;
      8'b00100000: n4697_o = n4685_o;
      8'b00010000: n4697_o = n4682_o;
      8'b00001000: n4697_o = n4678_o;
      8'b00000100: n4697_o = n4675_o;
      8'b00000010: n4697_o = n4671_o;
      8'b00000001: n4697_o = n4668_o;
      default: n4697_o = 1'bX;
    endcase
  /* T80_MCode.vhd:167:17  */
  assign n4698_o = n4637_o ? n4666_o : n4697_o;
  /* T80_MCode.vhd:1260:41  */
  assign n4701_o = n4698_o ? 3'b011 : 3'b001;
  /* T80_MCode.vhd:1260:41  */
  assign n4704_o = n4698_o ? 3'b101 : 3'b111;
  /* T80_MCode.vhd:1259:33  */
  assign n4706_o = n4628_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1266:33  */
  assign n4708_o = n4628_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1270:33  */
  assign n4710_o = n4628_o == 31'b0000000000000000000000000000011;
  assign n4711_o = {n4710_o, n4708_o, n4706_o};
  /* T80_MCode.vhd:1258:33  */
  always @*
    case (n4711_o)
      3'b100: n4713_o = 3'b011;
      3'b010: n4713_o = 3'b011;
      3'b001: n4713_o = n4701_o;
      default: n4713_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1258:33  */
  always @*
    case (n4711_o)
      3'b100: n4716_o = n2122_o;
      3'b010: n4716_o = n2122_o;
      3'b001: n4716_o = 3'b101;
      default: n4716_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1258:33  */
  always @*
    case (n4711_o)
      3'b100: n4720_o = 4'b0111;
      3'b010: n4720_o = 4'b0111;
      3'b001: n4720_o = 4'b0000;
      default: n4720_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1258:33  */
  always @*
    case (n4711_o)
      3'b100: n4723_o = 3'b111;
      3'b010: n4723_o = 3'b101;
      3'b001: n4723_o = n4704_o;
      default: n4723_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1258:33  */
  always @*
    case (n4711_o)
      3'b100: n4726_o = 1'b1;
      3'b010: n4726_o = 1'b0;
      3'b001: n4726_o = 1'b0;
      default: n4726_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1258:33  */
  always @*
    case (n4711_o)
      3'b100: n4729_o = 1'b0;
      3'b010: n4729_o = 1'b1;
      3'b001: n4729_o = 1'b0;
      default: n4729_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1188:25  */
  assign n4730_o = n4470_o ? n4585_o : n4713_o;
  /* T80_MCode.vhd:1188:25  */
  assign n4731_o = n4470_o ? n2122_o : n4716_o;
  /* T80_MCode.vhd:1188:25  */
  assign n4733_o = n4470_o ? n4587_o : 1'b0;
  /* T80_MCode.vhd:1188:25  */
  assign n4735_o = n4470_o ? n4590_o : 1'b0;
  /* T80_MCode.vhd:1188:25  */
  assign n4737_o = n4470_o ? 4'b0000 : n4720_o;
  /* T80_MCode.vhd:1188:25  */
  assign n4739_o = n4470_o ? n4593_o : 1'b0;
  /* T80_MCode.vhd:1188:25  */
  assign n4741_o = n4470_o ? n4596_o : 1'b0;
  assign n4742_o = {n4604_o, n4600_o};
  /* T80_MCode.vhd:1188:25  */
  assign n4744_o = n4470_o ? n4742_o : 4'b0000;
  /* T80_MCode.vhd:1188:25  */
  assign n4746_o = n4470_o ? n4607_o : 4'b0000;
  /* T80_MCode.vhd:1188:25  */
  assign n4747_o = n4470_o ? n4609_o : n2125_o;
  /* T80_MCode.vhd:1188:25  */
  assign n4749_o = n4470_o ? n4612_o : 1'b0;
  /* T80_MCode.vhd:1188:25  */
  assign n4750_o = n4470_o ? n4615_o : n4723_o;
  /* T80_MCode.vhd:1188:25  */
  assign n4752_o = n4470_o ? 1'b0 : n4726_o;
  /* T80_MCode.vhd:1188:25  */
  assign n4753_o = n4470_o ? n4618_o : n4729_o;
  /* T80_MCode.vhd:1188:25  */
  assign n4755_o = n4470_o ? n4621_o : 1'b0;
  /* T80_MCode.vhd:1188:25  */
  assign n4757_o = n4470_o ? n4624_o : 1'b0;
  /* T80_MCode.vhd:1188:25  */
  assign n4759_o = n4470_o ? n4627_o : 1'b0;
  /* T80_MCode.vhd:1187:17  */
  assign n4761_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1187:32  */
  assign n4763_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1187:32  */
  assign n4764_o = n4761_o | n4763_o;
  /* T80_MCode.vhd:1187:43  */
  assign n4766_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1187:43  */
  assign n4767_o = n4764_o | n4766_o;
  /* T80_MCode.vhd:1187:54  */
  assign n4769_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1187:54  */
  assign n4770_o = n4767_o | n4769_o;
  /* T80_MCode.vhd:1187:65  */
  assign n4772_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1187:65  */
  assign n4773_o = n4770_o | n4772_o;
  /* T80_MCode.vhd:1187:76  */
  assign n4775_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1187:76  */
  assign n4776_o = n4773_o | n4775_o;
  /* T80_MCode.vhd:1187:87  */
  assign n4778_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1187:87  */
  assign n4779_o = n4776_o | n4778_o;
  /* T80_MCode.vhd:1187:98  */
  assign n4781_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1187:98  */
  assign n4782_o = n4779_o | n4781_o;
  /* T80_MCode.vhd:1279:30  */
  assign n4783_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1280:25  */
  assign n4785_o = n4783_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1285:25  */
  assign n4787_o = n4783_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1290:25  */
  assign n4789_o = n4783_o == 31'b0000000000000000000000000000011;
  assign n4790_o = {n4789_o, n4787_o, n4785_o};
  /* T80_MCode.vhd:1279:25  */
  always @*
    case (n4790_o)
      3'b100: n4792_o = n2122_o;
      3'b010: n4792_o = n2122_o;
      3'b001: n4792_o = 3'b101;
      default: n4792_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1279:25  */
  always @*
    case (n4790_o)
      3'b100: n4796_o = 4'b0000;
      3'b010: n4796_o = 4'b1111;
      3'b001: n4796_o = 4'b1111;
      default: n4796_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1279:25  */
  always @*
    case (n4790_o)
      3'b100: n4800_o = 4'b0000;
      3'b010: n4800_o = 4'b1100;
      3'b001: n4800_o = 4'b1101;
      default: n4800_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1279:25  */
  always @*
    case (n4790_o)
      3'b100: n4804_o = 3'b111;
      3'b010: n4804_o = 3'b101;
      3'b001: n4804_o = 3'b101;
      default: n4804_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1279:25  */
  always @*
    case (n4790_o)
      3'b100: n4807_o = 1'b1;
      3'b010: n4807_o = 1'b0;
      3'b001: n4807_o = 1'b0;
      default: n4807_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1279:25  */
  always @*
    case (n4790_o)
      3'b100: n4811_o = 1'b1;
      3'b010: n4811_o = 1'b1;
      3'b001: n4811_o = 1'b0;
      default: n4811_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1276:17  */
  assign n4813_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1276:32  */
  assign n4815_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1276:32  */
  assign n4816_o = n4813_o | n4815_o;
  /* T80_MCode.vhd:1276:43  */
  assign n4818_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1276:43  */
  assign n4819_o = n4816_o | n4818_o;
  /* T80_MCode.vhd:1276:54  */
  assign n4821_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1276:54  */
  assign n4822_o = n4819_o | n4821_o;
  /* T80_MCode.vhd:1276:65  */
  assign n4824_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1276:65  */
  assign n4825_o = n4822_o | n4824_o;
  /* T80_MCode.vhd:1276:76  */
  assign n4827_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1276:76  */
  assign n4828_o = n4825_o | n4827_o;
  /* T80_MCode.vhd:1276:87  */
  assign n4830_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1276:87  */
  assign n4831_o = n4828_o | n4830_o;
  /* T80_MCode.vhd:1276:98  */
  assign n4833_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1276:98  */
  assign n4834_o = n4831_o | n4833_o;
  /* T80_MCode.vhd:1298:37  */
  assign n4835_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1298:37  */
  assign n4837_o = n4835_o != 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:1301:38  */
  assign n4838_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1302:33  */
  assign n4840_o = n4838_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1305:33  */
  assign n4842_o = n4838_o == 31'b0000000000000000000000000000011;
  assign n4843_o = {n4842_o, n4840_o};
  /* T80_MCode.vhd:1301:33  */
  always @*
    case (n4843_o)
      2'b10: n4846_o = 1'b0;
      2'b01: n4846_o = 1'b1;
      default: n4846_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1301:33  */
  always @*
    case (n4843_o)
      2'b10: n4849_o = 1'b1;
      2'b01: n4849_o = 1'b0;
      default: n4849_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1301:33  */
  always @*
    case (n4843_o)
      2'b10: n4852_o = 3'b111;
      2'b01: n4852_o = 3'b100;
      default: n4852_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1301:33  */
  always @*
    case (n4843_o)
      2'b10: n4855_o = 1'b1;
      2'b01: n4855_o = 1'b0;
      default: n4855_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1298:25  */
  assign n4858_o = n4837_o ? 3'b011 : 3'b001;
  /* T80_MCode.vhd:1298:25  */
  assign n4860_o = n4837_o ? n4846_o : 1'b0;
  /* T80_MCode.vhd:1298:25  */
  assign n4862_o = n4837_o ? n4849_o : 1'b0;
  /* T80_MCode.vhd:1298:25  */
  assign n4864_o = n4837_o ? n4852_o : 3'b111;
  /* T80_MCode.vhd:1298:25  */
  assign n4866_o = n4837_o ? n4855_o : 1'b0;
  /* T80_MCode.vhd:1297:17  */
  assign n4868_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1312:37  */
  assign n4869_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1312:37  */
  assign n4871_o = n4869_o != 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:1315:38  */
  assign n4872_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1316:33  */
  assign n4874_o = n4872_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1320:33  */
  assign n4876_o = n4872_o == 31'b0000000000000000000000000000011;
  assign n4877_o = {n4876_o, n4874_o};
  /* T80_MCode.vhd:1315:33  */
  always @*
    case (n4877_o)
      2'b10: n4880_o = 1'b0;
      2'b01: n4880_o = 1'b1;
      default: n4880_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1315:33  */
  always @*
    case (n4877_o)
      2'b10: n4883_o = 4'b0000;
      2'b01: n4883_o = 4'b0111;
      default: n4883_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1315:33  */
  always @*
    case (n4877_o)
      2'b10: n4886_o = 3'b111;
      2'b01: n4886_o = 3'b100;
      default: n4886_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1315:33  */
  always @*
    case (n4877_o)
      2'b10: n4889_o = 1'b1;
      2'b01: n4889_o = 1'b0;
      default: n4889_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1315:33  */
  always @*
    case (n4877_o)
      2'b10: n4892_o = 1'b1;
      2'b01: n4892_o = 1'b0;
      default: n4892_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1312:25  */
  assign n4895_o = n4871_o ? 3'b011 : 3'b001;
  /* T80_MCode.vhd:1312:25  */
  assign n4897_o = n4871_o ? n4880_o : 1'b0;
  /* T80_MCode.vhd:1312:25  */
  assign n4899_o = n4871_o ? n4883_o : 4'b0000;
  /* T80_MCode.vhd:1312:25  */
  assign n4901_o = n4871_o ? n4886_o : 3'b111;
  /* T80_MCode.vhd:1312:25  */
  assign n4903_o = n4871_o ? n4889_o : 1'b0;
  /* T80_MCode.vhd:1312:25  */
  assign n4905_o = n4871_o ? n4892_o : 1'b0;
  /* T80_MCode.vhd:1311:17  */
  assign n4907_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1334:37  */
  assign n4908_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1334:37  */
  assign n4910_o = n4908_o != 32'b00000000000000000000000000000010;
  /* T80_MCode.vhd:1334:25  */
  assign n4913_o = n4910_o ? 2'b01 : 2'b00;
  /* T80_MCode.vhd:1333:17  */
  assign n4915_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1339:37  */
  assign n4916_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1339:37  */
  assign n4918_o = $signed(n4916_o) < $signed(32'b00000000000000000000000000000010);
  /* T80_MCode.vhd:1339:25  */
  assign n4921_o = n4918_o ? 2'b10 : 2'b00;
  /* T80_MCode.vhd:1338:17  */
  assign n4923_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1344:37  */
  assign n4924_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1344:37  */
  assign n4926_o = $signed(n4924_o) < $signed(32'b00000000000000000000000000000010);
  /* T80_MCode.vhd:1344:25  */
  assign n4929_o = n4926_o ? 2'b11 : 2'b00;
  /* T80_MCode.vhd:1343:17  */
  assign n4931_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1343:32  */
  assign n4933_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1343:32  */
  assign n4934_o = n4931_o | n4933_o;
  assign n4935_o = {n4934_o, n4923_o, n4915_o, n4907_o, n4868_o, n4834_o, n4782_o, n4465_o, n4441_o, n4269_o, n4226_o, n4139_o, n4137_o, n4099_o, n4060_o, n4022_o, n3983_o, n3951_o, n3700_o, n3679_o, n3667_o, n3655_o, n3643_o, n3554_o, n3552_o, n3550_o, n3548_o, n3449_o, n3447_o, n3445_o, n3443_o, n3440_o, n3405_o, n3385_o, n3350_o, n3330_o, n3291_o, n3248_o, n3080_o, n3008_o, n2952_o, n2887_o, n2879_o, n2826_o, n2777_o, n2775_o, n2701_o, n2626_o, n2579_o, n2515_o, n2495_o, n2475_o, n2423_o, n2409_o, n2395_o, n2373_o, n2336_o, n2302_o, n2271_o};
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4958_o = 3'b001;
      59'b01000000000000000000000000000000000000000000000000000000000: n4958_o = 3'b001;
      59'b00100000000000000000000000000000000000000000000000000000000: n4958_o = 3'b001;
      59'b00010000000000000000000000000000000000000000000000000000000: n4958_o = n4895_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4958_o = n4858_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4958_o = 3'b011;
      59'b00000010000000000000000000000000000000000000000000000000000: n4958_o = n4730_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4958_o = 3'b011;
      59'b00000000100000000000000000000000000000000000000000000000000: n4958_o = n4401_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4958_o = 3'b101;
      59'b00000000001000000000000000000000000000000000000000000000000: n4958_o = n4206_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000010000000000000000000000000000000000000000000000: n4958_o = n4128_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4958_o = n4090_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4958_o = n4051_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4958_o = n4013_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4958_o = n3974_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n4958_o = n3912_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4958_o = 3'b011;
      59'b00000000000000000001000000000000000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000100000000000000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000010000000000000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000001000000000000000000000000000000000000: n4958_o = 3'b011;
      59'b00000000000000000000000100000000000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000010000000000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000001000000000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000000100000000000000000000000000000000: n4958_o = n3535_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000000001000000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000000000100000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000000000010000000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000000000001000000000000000000000000000: n4958_o = 3'b011;
      59'b00000000000000000000000000000000100000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000000000000010000000000000000000000000: n4958_o = 3'b011;
      59'b00000000000000000000000000000000001000000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000000000000000100000000000000000000000: n4958_o = 3'b010;
      59'b00000000000000000000000000000000000010000000000000000000000: n4958_o = 3'b010;
      59'b00000000000000000000000000000000000001000000000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000000000000000000100000000000000000000: n4958_o = n3061_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4958_o = n2992_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n4958_o = n2934_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000000000000000000000010000000000000000: n4958_o = 3'b011;
      59'b00000000000000000000000000000000000000000001000000000000000: n4958_o = 3'b011;
      59'b00000000000000000000000000000000000000000000100000000000000: n4958_o = 3'b001;
      59'b00000000000000000000000000000000000000000000010000000000000: n4958_o = n2760_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4958_o = n2682_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4958_o = 3'b011;
      59'b00000000000000000000000000000000000000000000000010000000000: n4958_o = n2566_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4958_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000100000000: n4958_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000010000000: n4958_o = n2465_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4958_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000100000: n4958_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000010000: n4958_o = 3'b011;
      59'b00000000000000000000000000000000000000000000000000000001000: n4958_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000100: n4958_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000010: n4958_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000001: n4958_o = 3'b001;
      default: n4958_o = 3'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4963_o = n2122_o;
      59'b01000000000000000000000000000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00100000000000000000000000000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00010000000000000000000000000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4963_o = n4792_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4963_o = n4731_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4963_o = n4402_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4963_o = n4238_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4963_o = n4207_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000010000000000000000000000000000000000000000000000: n4963_o = n4129_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4963_o = n4091_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4963_o = n4052_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4963_o = n4014_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4963_o = n3975_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000100000000000000000000000000000000000000: n4963_o = 3'b110;
      59'b00000000000000000000010000000000000000000000000000000000000: n4963_o = 3'b110;
      59'b00000000000000000000001000000000000000000000000000000000000: n4963_o = n3602_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000010000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000001000000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000100000000000000000000000000000000: n4963_o = n3536_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000001000000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000100000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000010000000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000001000000000000000000000000000: n4963_o = n3415_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000010000000000000000000000000: n4963_o = n3360_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000100000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4963_o = n3062_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000010000000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4963_o = n2801_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4963_o = 3'b110;
      59'b00000000000000000000000000000000000000000000010000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4963_o = n2122_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4963_o = n2122_o;
      default: n4963_o = 3'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4966_o = n4929_o;
      59'b01000000000000000000000000000000000000000000000000000000000: n4966_o = n4921_o;
      59'b00100000000000000000000000000000000000000000000000000000000: n4966_o = n4913_o;
      59'b00010000000000000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000010000000000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000001000000000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000100000000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000010000000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000001000000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000010000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000001000000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000100000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000010000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000010000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000001000000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000100000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000001000000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000100000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000010000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4966_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4966_o = 2'b00;
      default: n4966_o = 2'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4969_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4969_o = n4897_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4969_o = n4860_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4969_o = n4733_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4969_o = n4404_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4969_o = n4242_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4969_o = n4209_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4969_o = n4131_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4969_o = n4093_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4969_o = n4054_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4969_o = n4016_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4969_o = n3977_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n4969_o = n3913_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4969_o = n3689_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4969_o = n3538_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4969_o = n3297_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4969_o = n2936_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4969_o = n2762_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4969_o = n2684_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4969_o = n2607_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4969_o = n2568_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4969_o = n2467_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4969_o = n2383_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4969_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4969_o = n2277_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4969_o = 1'b0;
      default: n4969_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4972_o = n4735_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4972_o = n2938_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4972_o = n2764_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4972_o = n2686_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4972_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4972_o = 1'b0;
      default: n4972_o = 1'bX;
    endcase
  assign n4973_o = n2469_o[1:0];
  assign n4974_o = n2570_o[1:0];
  assign n4975_o = n2688_o[1:0];
  assign n4976_o = n2766_o[1:0];
  assign n4977_o = n2805_o[1:0];
  assign n4978_o = n2856_o[1:0];
  assign n4979_o = n2994_o[1:0];
  assign n4980_o = n3064_o[1:0];
  assign n4981_o = n3539_o[1:0];
  assign n4982_o = n4246_o[1:0];
  assign n4983_o = n4406_o[1:0];
  assign n4984_o = n4453_o[1:0];
  assign n4985_o = n4737_o[1:0];
  assign n4986_o = n4796_o[1:0];
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4989_o = n4986_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4989_o = n4985_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4989_o = n4984_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4989_o = n4983_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4989_o = n4982_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4989_o = n2117_o;
      59'b00000000000000000000010000000000000000000000000000000000000: n4989_o = n2117_o;
      59'b00000000000000000000001000000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000100000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4989_o = n4981_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4989_o = n4980_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4989_o = n4979_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4989_o = n4978_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4989_o = n4977_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4989_o = n4976_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4989_o = n4975_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4989_o = n4974_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000100000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000010000000: n4989_o = n4973_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4989_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4989_o = 2'b00;
      default: n4989_o = 2'bX;
    endcase
  assign n4990_o = n2469_o[3:2];
  assign n4991_o = n2570_o[3:2];
  assign n4992_o = n2688_o[3:2];
  assign n4993_o = n2766_o[3:2];
  assign n4994_o = n2805_o[3:2];
  assign n4995_o = n2856_o[3:2];
  assign n4996_o = n2994_o[3:2];
  assign n4997_o = n3064_o[3:2];
  assign n4998_o = n3539_o[3:2];
  assign n4999_o = n4246_o[3:2];
  assign n5000_o = n4406_o[3:2];
  assign n5001_o = n4453_o[3:2];
  assign n5002_o = n4737_o[3:2];
  assign n5003_o = n4796_o[3:2];
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n5006_o = n5003_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n5006_o = n5002_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5006_o = n5001_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n5006_o = n5000_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n5006_o = n4999_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n5006_o = 2'b11;
      59'b00000000000000000000010000000000000000000000000000000000000: n5006_o = 2'b01;
      59'b00000000000000000000001000000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000100000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n5006_o = n4998_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n5006_o = n4997_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5006_o = n4996_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n5006_o = n4995_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n5006_o = n4994_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n5006_o = n4993_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n5006_o = n4992_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n5006_o = n4991_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000100000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000010000000: n5006_o = n4990_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n5006_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n5006_o = 2'b00;
      default: n5006_o = 2'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5015_o = n4739_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5015_o = n4211_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5015_o = 1'b1;
      59'b00000000000000000000100000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5015_o = n3606_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5015_o = 1'b1;
      59'b00000000000000000000000000000001000000000000000000000000000: n5015_o = n3418_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n5015_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n5015_o = n3363_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n5015_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n5015_o = n3300_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n5015_o = n3258_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n5015_o = 1'b1;
      59'b00000000000000000000000000000000000000100000000000000000000: n5015_o = n3066_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5015_o = n2860_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5015_o = n2690_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n5015_o = n2611_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5015_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5015_o = n2311_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n5015_o = n2280_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n5015_o = 1'b1;
      default: n5015_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5018_o = n4862_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5018_o = n4741_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5018_o = n3915_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5018_o = n2692_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5018_o = n2470_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n5018_o = n2418_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n5018_o = n2404_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5018_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5018_o = 1'b0;
      default: n5018_o = 1'bX;
    endcase
  assign n5019_o = n3068_o[2:0];
  assign n5020_o = n4744_o[2:0];
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b01000000000000000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00100000000000000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00010000000000000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00001000000000000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000100000000000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000010000000000000000000000000000000000000000000000000000: n5023_o = n5020_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000100000000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000010000000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000001000000000000000000000000000000000000000000000000: n5023_o = n4213_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000010000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000001000000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000100000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000010000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000001000000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000100000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000010000000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000001000000000000000000000000000000000000000: n5023_o = 3'b111;
      59'b00000000000000000000100000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000010000000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000001000000000000000000000000000000000000: n5023_o = n3608_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000010000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000001000000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000100000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000010000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000001000000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000100000000000000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000010000000000000000000000000000: n5023_o = 3'b111;
      59'b00000000000000000000000000000001000000000000000000000000000: n5023_o = n3420_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n5023_o = n2115_o;
      59'b00000000000000000000000000000000010000000000000000000000000: n5023_o = n3365_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n5023_o = n2115_o;
      59'b00000000000000000000000000000000000100000000000000000000000: n5023_o = n3302_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n5023_o = n3260_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n5023_o = 3'b111;
      59'b00000000000000000000000000000000000000100000000000000000000: n5023_o = n5019_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000001000000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000100000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000010000000000000000: n5023_o = n2862_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000100000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000010000000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000001000000000000: n5023_o = n2694_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n5023_o = n2613_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000001000000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000100000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000010000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000001000000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000100000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000010000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000001000: n5023_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000000100: n5023_o = n2313_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n5023_o = n2282_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n5023_o = n2115_o;
      default: n5023_o = 3'bX;
    endcase
  assign n5024_o = n3068_o[3];
  assign n5025_o = n4744_o[3];
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5028_o = n5025_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5028_o = n5024_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5028_o = n2864_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5028_o = n2615_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5028_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5028_o = 1'b0;
      default: n5028_o = 1'bX;
    endcase
  assign n5029_o = n2116_o[0];
  assign n5030_o = n2345_o[0];
  assign n5031_o = n2385_o[0];
  assign n5032_o = n2484_o[0];
  assign n5033_o = n2504_o[0];
  assign n5034_o = n2571_o[0];
  assign n5035_o = n2767_o[0];
  assign n5036_o = n2807_o[0];
  assign n5037_o = n2940_o[0];
  assign n5038_o = n3070_o[0];
  assign n5039_o = n2116_o[0];
  assign n5040_o = n3262_o[0];
  assign n5041_o = n3304_o[0];
  assign n5043_o = n3368_o[0];
  assign n5045_o = n3423_o[0];
  assign n5046_o = n3540_o[0];
  assign n5047_o = n3917_o[0];
  assign n5048_o = n4215_o[0];
  assign n5049_o = n4250_o[0];
  assign n5050_o = n4408_o[0];
  assign n5051_o = n4746_o[0];
  assign n5052_o = n4800_o[0];
  assign n5053_o = n4899_o[0];
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5056_o = n5053_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5056_o = n5052_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n5056_o = n5051_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5056_o = n5050_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n5056_o = n5049_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n5056_o = n5048_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5056_o = n5047_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5056_o = n3610_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5056_o = n5046_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5056_o = n5045_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5056_o = n5043_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5056_o = n5041_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n5056_o = n5040_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n5056_o = n5039_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n5056_o = n5038_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5056_o = n5037_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5056_o = n5036_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5056_o = n5035_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5056_o = n5034_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n5056_o = n5033_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n5056_o = n5032_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5056_o = n5031_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n5056_o = n5030_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5056_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5056_o = n5029_o;
      default: n5056_o = 1'bX;
    endcase
  assign n5057_o = n2116_o[2:1];
  assign n5058_o = n2345_o[2:1];
  assign n5059_o = n2385_o[2:1];
  assign n5060_o = n2484_o[2:1];
  assign n5061_o = n2504_o[2:1];
  assign n5062_o = n2571_o[2:1];
  assign n5063_o = n2767_o[2:1];
  assign n5064_o = n2807_o[2:1];
  assign n5065_o = n2940_o[2:1];
  assign n5066_o = n3070_o[2:1];
  assign n5067_o = n2116_o[2:1];
  assign n5068_o = n3262_o[2:1];
  assign n5069_o = n3304_o[2:1];
  assign n5071_o = n3368_o[2:1];
  assign n5073_o = n3423_o[2:1];
  assign n5074_o = n3540_o[2:1];
  assign n5075_o = n3917_o[2:1];
  assign n5076_o = n4215_o[2:1];
  assign n5077_o = n4250_o[2:1];
  assign n5078_o = n4408_o[2:1];
  assign n5079_o = n4746_o[2:1];
  assign n5080_o = n4800_o[2:1];
  assign n5081_o = n4899_o[2:1];
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n5084_o = n5081_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n5084_o = n5080_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n5084_o = n5079_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000100000000000000000000000000000000000000000000000000: n5084_o = n5078_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n5084_o = n5077_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n5084_o = n5076_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n5084_o = n5075_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000010000000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000001000000000000000000000000000000000000: n5084_o = n3612_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n5084_o = n5074_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n5084_o = n5073_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n5084_o = 2'b01;
      59'b00000000000000000000000000000000010000000000000000000000000: n5084_o = n5071_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n5084_o = 2'b01;
      59'b00000000000000000000000000000000000100000000000000000000000: n5084_o = n5069_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n5084_o = n5068_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n5084_o = n5067_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n5084_o = n5066_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n5084_o = n5065_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000000001000000000000000: n5084_o = n5064_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n5084_o = n5063_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n5084_o = n5062_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n5084_o = n5061_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n5084_o = n5060_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n5084_o = n5059_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n5084_o = n5058_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n5084_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n5084_o = n5057_o;
      default: n5084_o = 2'bX;
    endcase
  assign n5085_o = n2484_o[3];
  assign n5086_o = n2504_o[3];
  assign n5087_o = n2571_o[3];
  assign n5088_o = n2767_o[3];
  assign n5089_o = n2807_o[3];
  assign n5090_o = n2940_o[3];
  assign n5091_o = n3070_o[3];
  assign n5093_o = n3368_o[3];
  assign n5095_o = n3423_o[3];
  assign n5096_o = n3540_o[3];
  assign n5097_o = n3917_o[3];
  assign n5098_o = n4215_o[3];
  assign n5099_o = n4250_o[3];
  assign n5100_o = n4408_o[3];
  assign n5101_o = n4746_o[3];
  assign n5102_o = n4800_o[3];
  assign n5103_o = n4899_o[3];
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5106_o = n5103_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5106_o = n5102_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n5106_o = n5101_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5106_o = n5100_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n5106_o = n5099_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n5106_o = n5098_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5106_o = n5097_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5106_o = n3614_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5106_o = n5096_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5106_o = n5095_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n5106_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n5106_o = n5093_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n5106_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5106_o = n5091_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5106_o = n5090_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5106_o = n5089_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5106_o = n5088_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5106_o = n5087_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n5106_o = n5086_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n5106_o = n5085_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5106_o = n2387_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n5106_o = n2347_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5106_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5106_o = 1'b0;
      default: n5106_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b01000000000000000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00100000000000000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00010000000000000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n5112_o = n4747_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n5112_o = n4216_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000010000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n5112_o = 4'b1000;
      59'b00000000000000000000100000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000010000000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000001000000000000000000000000000000000000: n5112_o = n3617_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000010000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000001000000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000100000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000001000000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000100000000000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000010000000000000000000000000000: n5112_o = 4'b1100;
      59'b00000000000000000000000000000001000000000000000000000000000: n5112_o = n3425_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n5112_o = 4'b0010;
      59'b00000000000000000000000000000000010000000000000000000000000: n5112_o = n3370_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n5112_o = 4'b0000;
      59'b00000000000000000000000000000000000100000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000010000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000010000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n5112_o = n2125_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n5112_o = n2125_o;
      default: n5112_o = 4'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5120_o = n4749_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5120_o = n4218_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5120_o = 1'b1;
      59'b00000000000000000000100000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5120_o = n3621_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5120_o = 1'b1;
      59'b00000000000000000000000000000001000000000000000000000000000: n5120_o = n3428_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n5120_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n5120_o = n3373_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n5120_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n5120_o = n3307_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n5120_o = n3265_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n5120_o = 1'b1;
      59'b00000000000000000000000000000000000000100000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5120_o = 1'b0;
      default: n5120_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5125_o = n3431_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n5125_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n5125_o = n3376_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n5125_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5125_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5125_o = 1'b0;
      default: n5125_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5128_o = n3625_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5128_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5128_o = 1'b0;
      default: n5128_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b01000000000000000000000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00100000000000000000000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00010000000000000000000000000000000000000000000000000000000: n5131_o = n4901_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n5131_o = n4864_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n5131_o = n4804_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n5131_o = n4750_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5131_o = n4457_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n5131_o = n4410_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n5131_o = n4254_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000100000000000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000010000000000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000001000000000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000100000000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000010000000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000001000000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000100000000000000000000000000000000000000000: n5131_o = n3919_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000001000000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000100000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000010000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000001000000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000100000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000010000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000001000000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000100000000000000000000000000000000: n5131_o = n3541_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000001000000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000000100000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000000010000000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000000001000000000000000000000000000: n5131_o = n3435_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000000000010000000000000000000000000: n5131_o = n3380_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000000000000100000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000000000000010000000000000000000000: n5131_o = n3268_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000000000000000100000000000000000000: n5131_o = n3072_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5131_o = n2996_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n5131_o = n2942_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000000000000000000010000000000000000: n5131_o = n2868_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n5131_o = n2811_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000000000000000000000010000000000000: n5131_o = n2768_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n5131_o = n2695_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n5131_o = 3'b111;
      59'b00000000000000000000000000000000000000000000000010000000000: n5131_o = n2572_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n5131_o = n2507_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n5131_o = n2487_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n5131_o = n2471_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n5131_o = n2421_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n5131_o = n2407_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n5131_o = n2390_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n5131_o = n2350_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n5131_o = n2316_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n5131_o = 3'b111;
      59'b00000000000000000000000000000000000000000000000000000000001: n5131_o = 3'b111;
      default: n5131_o = 3'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5134_o = n4903_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n5134_o = n4866_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5134_o = n3921_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5134_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5134_o = 1'b0;
      default: n5134_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5137_o = n4752_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5137_o = n4460_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5137_o = n3923_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5137_o = n3692_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5137_o = n3543_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5137_o = n2998_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5137_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5137_o = 1'b0;
      default: n5137_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5140_o = n4220_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5140_o = n4133_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n5140_o = n4095_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n5140_o = n4056_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n5140_o = n4018_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n5140_o = n3979_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5140_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5140_o = 1'b0;
      default: n5140_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5144_o = 1'b1;
      59'b00000000000010000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5144_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5144_o = 1'b0;
      default: n5144_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5147_o = n4412_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n5147_o = n4257_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5147_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5147_o = 1'b0;
      default: n5147_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5150_o = n4807_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5150_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5150_o = 1'b0;
      default: n5150_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5153_o = n4753_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5153_o = n4463_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n5153_o = n4414_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n5153_o = n4260_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5153_o = n3924_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5153_o = n3695_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5153_o = n3545_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5153_o = n3074_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5153_o = n3000_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n5153_o = n2944_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5153_o = n2770_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n5153_o = n2697_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5153_o = n2574_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5153_o = n2473_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5153_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5153_o = 1'b0;
      default: n5153_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5156_o = n4755_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5156_o = n4416_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n5156_o = n4263_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5156_o = n3926_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5156_o = n3698_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5156_o = n3076_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5156_o = n2946_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5156_o = n2772_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n5156_o = n2699_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5156_o = 1'b0;
      default: n5156_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5160_o = 1'b1;
      59'b00000000000000000000000000000000000000000000010000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5160_o = 1'b0;
      default: n5160_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5163_o = n2885_o;
      59'b00000000000000000000000000000000000000000010000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5163_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5163_o = 1'b0;
      default: n5163_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5167_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5167_o = 1'b1;
      default: n5167_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5170_o = n2948_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5170_o = 1'b0;
      default: n5170_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5173_o = n3002_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5173_o = 1'b0;
      default: n5173_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5176_o = n4222_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5176_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5176_o = 1'b0;
      default: n5176_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5180_o = 1'b1;
      59'b00000000000000000000000000000010000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5180_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5180_o = 1'b0;
      default: n5180_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5184_o = 1'b1;
      59'b00000000000000000000000000000100000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5184_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5184_o = 1'b0;
      default: n5184_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5188_o = 1'b1;
      59'b00000000000000000000000000001000000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5188_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5188_o = 1'b0;
      default: n5188_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5191_o = n3004_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5191_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5191_o = 1'b0;
      default: n5191_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000010000000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000001000000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000100000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000010000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000001000000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000010000000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000001000000000000000000000000000000000000: n5194_o = n3628_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000010000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000010000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000001000000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000100000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n5194_o = n2576_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n5194_o = n2510_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n5194_o = n2490_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n5194_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n5194_o = 2'b00;
      default: n5194_o = 2'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5198_o = 1'b1;
      59'b00000000000000000000000001000000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5198_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5198_o = 1'b0;
      default: n5198_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5202_o = 1'b1;
      59'b00000000000000000000000010000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5202_o = n3006_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5202_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5202_o = 1'b0;
      default: n5202_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5206_o = 1'b1;
      59'b00000000000000000000000000100000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5206_o = 1'b0;
      default: n5206_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n5209_o = n4757_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n5209_o = n4224_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5209_o = n4135_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n5209_o = n4097_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n5209_o = n4058_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n5209_o = n4020_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n5209_o = n3981_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5209_o = n3632_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5209_o = 1'b0;
      default: n5209_o = 1'bX;
    endcase
  /* T80_MCode.vhd:267:17  */
  always @*
    case (n4935_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n5212_o = n4905_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n5212_o = n4811_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n5212_o = n4759_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n5212_o = n4418_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n5212_o = n4267_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n5212_o = n3928_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n5212_o = n3546_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n5212_o = n3438_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n5212_o = n3383_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n5212_o = n3078_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n5212_o = n2950_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n5212_o = n2815_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n5212_o = n2773_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n5212_o = n2577_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n5212_o = n2513_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n5212_o = n2493_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n5212_o = n2393_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n5212_o = n2353_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n5212_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n5212_o = 1'b0;
      default: n5212_o = 1'bX;
    endcase
  /* T80_MCode.vhd:259:17  */
  assign n5214_o = iset == 2'b00;
  /* T80_MCode.vhd:1358:54  */
  assign n5215_o = ir[2:0];
  /* T80_MCode.vhd:1359:54  */
  assign n5216_o = ir[2:0];
  /* T80_MCode.vhd:1378:44  */
  assign n5218_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1379:51  */
  assign n5220_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1379:41  */
  assign n5223_o = n5220_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1379:41  */
  assign n5225_o = n5220_o ? 4'b1000 : n2125_o;
  /* T80_MCode.vhd:1379:41  */
  assign n5228_o = n5220_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1388:46  */
  assign n5229_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1389:41  */
  assign n5231_o = n5229_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1389:48  */
  assign n5233_o = n5229_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1389:48  */
  assign n5234_o = n5231_o | n5233_o;
  /* T80_MCode.vhd:1391:41  */
  assign n5236_o = n5229_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1397:41  */
  assign n5238_o = n5229_o == 31'b0000000000000000000000000000011;
  assign n5239_o = {n5238_o, n5236_o, n5234_o};
  /* T80_MCode.vhd:1388:41  */
  always @*
    case (n5239_o)
      3'b100: n5241_o = n2122_o;
      3'b010: n5241_o = 3'b100;
      3'b001: n5241_o = n2122_o;
      default: n5241_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1388:41  */
  always @*
    case (n5239_o)
      3'b100: n5244_o = 1'b0;
      3'b010: n5244_o = 1'b1;
      3'b001: n5244_o = 1'b0;
      default: n5244_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1388:41  */
  always @*
    case (n5239_o)
      3'b100: n5246_o = n2125_o;
      3'b010: n5246_o = 4'b1000;
      3'b001: n5246_o = n2125_o;
      default: n5246_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1388:41  */
  always @*
    case (n5239_o)
      3'b100: n5249_o = 1'b0;
      3'b010: n5249_o = 1'b1;
      3'b001: n5249_o = 1'b0;
      default: n5249_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1388:41  */
  always @*
    case (n5239_o)
      3'b100: n5253_o = 3'b111;
      3'b010: n5253_o = 3'b010;
      3'b001: n5253_o = 3'b010;
      default: n5253_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1388:41  */
  always @*
    case (n5239_o)
      3'b100: n5256_o = 1'b1;
      3'b010: n5256_o = 1'b0;
      3'b001: n5256_o = 1'b0;
      default: n5256_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1378:33  */
  assign n5259_o = n5218_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1378:33  */
  assign n5260_o = n5218_o ? n2122_o : n5241_o;
  /* T80_MCode.vhd:1378:33  */
  assign n5261_o = n5218_o ? n5223_o : n5244_o;
  /* T80_MCode.vhd:1378:33  */
  assign n5262_o = n5218_o ? n5225_o : n5246_o;
  /* T80_MCode.vhd:1378:33  */
  assign n5263_o = n5218_o ? n5228_o : n5249_o;
  /* T80_MCode.vhd:1378:33  */
  assign n5265_o = n5218_o ? 3'b111 : n5253_o;
  /* T80_MCode.vhd:1378:33  */
  assign n5267_o = n5218_o ? 1'b0 : n5256_o;
  /* T80_MCode.vhd:1378:33  */
  assign n5270_o = n5218_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1362:25  */
  assign n5272_o = ir == 8'b00000000;
  /* T80_MCode.vhd:1362:40  */
  assign n5274_o = ir == 8'b00000001;
  /* T80_MCode.vhd:1362:40  */
  assign n5275_o = n5272_o | n5274_o;
  /* T80_MCode.vhd:1362:51  */
  assign n5277_o = ir == 8'b00000010;
  /* T80_MCode.vhd:1362:51  */
  assign n5278_o = n5275_o | n5277_o;
  /* T80_MCode.vhd:1362:62  */
  assign n5280_o = ir == 8'b00000011;
  /* T80_MCode.vhd:1362:62  */
  assign n5281_o = n5278_o | n5280_o;
  /* T80_MCode.vhd:1362:73  */
  assign n5283_o = ir == 8'b00000100;
  /* T80_MCode.vhd:1362:73  */
  assign n5284_o = n5281_o | n5283_o;
  /* T80_MCode.vhd:1362:84  */
  assign n5286_o = ir == 8'b00000101;
  /* T80_MCode.vhd:1362:84  */
  assign n5287_o = n5284_o | n5286_o;
  /* T80_MCode.vhd:1362:95  */
  assign n5289_o = ir == 8'b00000111;
  /* T80_MCode.vhd:1362:95  */
  assign n5290_o = n5287_o | n5289_o;
  /* T80_MCode.vhd:1363:33  */
  assign n5292_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1363:33  */
  assign n5293_o = n5290_o | n5292_o;
  /* T80_MCode.vhd:1363:44  */
  assign n5295_o = ir == 8'b00010001;
  /* T80_MCode.vhd:1363:44  */
  assign n5296_o = n5293_o | n5295_o;
  /* T80_MCode.vhd:1363:55  */
  assign n5298_o = ir == 8'b00010010;
  /* T80_MCode.vhd:1363:55  */
  assign n5299_o = n5296_o | n5298_o;
  /* T80_MCode.vhd:1363:66  */
  assign n5301_o = ir == 8'b00010011;
  /* T80_MCode.vhd:1363:66  */
  assign n5302_o = n5299_o | n5301_o;
  /* T80_MCode.vhd:1363:77  */
  assign n5304_o = ir == 8'b00010100;
  /* T80_MCode.vhd:1363:77  */
  assign n5305_o = n5302_o | n5304_o;
  /* T80_MCode.vhd:1363:88  */
  assign n5307_o = ir == 8'b00010101;
  /* T80_MCode.vhd:1363:88  */
  assign n5308_o = n5305_o | n5307_o;
  /* T80_MCode.vhd:1363:99  */
  assign n5310_o = ir == 8'b00010111;
  /* T80_MCode.vhd:1363:99  */
  assign n5311_o = n5308_o | n5310_o;
  /* T80_MCode.vhd:1364:33  */
  assign n5313_o = ir == 8'b00001000;
  /* T80_MCode.vhd:1364:33  */
  assign n5314_o = n5311_o | n5313_o;
  /* T80_MCode.vhd:1364:44  */
  assign n5316_o = ir == 8'b00001001;
  /* T80_MCode.vhd:1364:44  */
  assign n5317_o = n5314_o | n5316_o;
  /* T80_MCode.vhd:1364:55  */
  assign n5319_o = ir == 8'b00001010;
  /* T80_MCode.vhd:1364:55  */
  assign n5320_o = n5317_o | n5319_o;
  /* T80_MCode.vhd:1364:66  */
  assign n5322_o = ir == 8'b00001011;
  /* T80_MCode.vhd:1364:66  */
  assign n5323_o = n5320_o | n5322_o;
  /* T80_MCode.vhd:1364:77  */
  assign n5325_o = ir == 8'b00001100;
  /* T80_MCode.vhd:1364:77  */
  assign n5326_o = n5323_o | n5325_o;
  /* T80_MCode.vhd:1364:88  */
  assign n5328_o = ir == 8'b00001101;
  /* T80_MCode.vhd:1364:88  */
  assign n5329_o = n5326_o | n5328_o;
  /* T80_MCode.vhd:1364:99  */
  assign n5331_o = ir == 8'b00001111;
  /* T80_MCode.vhd:1364:99  */
  assign n5332_o = n5329_o | n5331_o;
  /* T80_MCode.vhd:1365:33  */
  assign n5334_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1365:33  */
  assign n5335_o = n5332_o | n5334_o;
  /* T80_MCode.vhd:1365:44  */
  assign n5337_o = ir == 8'b00011001;
  /* T80_MCode.vhd:1365:44  */
  assign n5338_o = n5335_o | n5337_o;
  /* T80_MCode.vhd:1365:55  */
  assign n5340_o = ir == 8'b00011010;
  /* T80_MCode.vhd:1365:55  */
  assign n5341_o = n5338_o | n5340_o;
  /* T80_MCode.vhd:1365:66  */
  assign n5343_o = ir == 8'b00011011;
  /* T80_MCode.vhd:1365:66  */
  assign n5344_o = n5341_o | n5343_o;
  /* T80_MCode.vhd:1365:77  */
  assign n5346_o = ir == 8'b00011100;
  /* T80_MCode.vhd:1365:77  */
  assign n5347_o = n5344_o | n5346_o;
  /* T80_MCode.vhd:1365:88  */
  assign n5349_o = ir == 8'b00011101;
  /* T80_MCode.vhd:1365:88  */
  assign n5350_o = n5347_o | n5349_o;
  /* T80_MCode.vhd:1365:99  */
  assign n5352_o = ir == 8'b00011111;
  /* T80_MCode.vhd:1365:99  */
  assign n5353_o = n5350_o | n5352_o;
  /* T80_MCode.vhd:1366:33  */
  assign n5355_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1366:33  */
  assign n5356_o = n5353_o | n5355_o;
  /* T80_MCode.vhd:1366:44  */
  assign n5358_o = ir == 8'b00100001;
  /* T80_MCode.vhd:1366:44  */
  assign n5359_o = n5356_o | n5358_o;
  /* T80_MCode.vhd:1366:55  */
  assign n5361_o = ir == 8'b00100010;
  /* T80_MCode.vhd:1366:55  */
  assign n5362_o = n5359_o | n5361_o;
  /* T80_MCode.vhd:1366:66  */
  assign n5364_o = ir == 8'b00100011;
  /* T80_MCode.vhd:1366:66  */
  assign n5365_o = n5362_o | n5364_o;
  /* T80_MCode.vhd:1366:77  */
  assign n5367_o = ir == 8'b00100100;
  /* T80_MCode.vhd:1366:77  */
  assign n5368_o = n5365_o | n5367_o;
  /* T80_MCode.vhd:1366:88  */
  assign n5370_o = ir == 8'b00100101;
  /* T80_MCode.vhd:1366:88  */
  assign n5371_o = n5368_o | n5370_o;
  /* T80_MCode.vhd:1366:99  */
  assign n5373_o = ir == 8'b00100111;
  /* T80_MCode.vhd:1366:99  */
  assign n5374_o = n5371_o | n5373_o;
  /* T80_MCode.vhd:1367:33  */
  assign n5376_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1367:33  */
  assign n5377_o = n5374_o | n5376_o;
  /* T80_MCode.vhd:1367:44  */
  assign n5379_o = ir == 8'b00101001;
  /* T80_MCode.vhd:1367:44  */
  assign n5380_o = n5377_o | n5379_o;
  /* T80_MCode.vhd:1367:55  */
  assign n5382_o = ir == 8'b00101010;
  /* T80_MCode.vhd:1367:55  */
  assign n5383_o = n5380_o | n5382_o;
  /* T80_MCode.vhd:1367:66  */
  assign n5385_o = ir == 8'b00101011;
  /* T80_MCode.vhd:1367:66  */
  assign n5386_o = n5383_o | n5385_o;
  /* T80_MCode.vhd:1367:77  */
  assign n5388_o = ir == 8'b00101100;
  /* T80_MCode.vhd:1367:77  */
  assign n5389_o = n5386_o | n5388_o;
  /* T80_MCode.vhd:1367:88  */
  assign n5391_o = ir == 8'b00101101;
  /* T80_MCode.vhd:1367:88  */
  assign n5392_o = n5389_o | n5391_o;
  /* T80_MCode.vhd:1367:99  */
  assign n5394_o = ir == 8'b00101111;
  /* T80_MCode.vhd:1367:99  */
  assign n5395_o = n5392_o | n5394_o;
  /* T80_MCode.vhd:1368:33  */
  assign n5397_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1368:33  */
  assign n5398_o = n5395_o | n5397_o;
  /* T80_MCode.vhd:1368:44  */
  assign n5400_o = ir == 8'b00110001;
  /* T80_MCode.vhd:1368:44  */
  assign n5401_o = n5398_o | n5400_o;
  /* T80_MCode.vhd:1368:55  */
  assign n5403_o = ir == 8'b00110010;
  /* T80_MCode.vhd:1368:55  */
  assign n5404_o = n5401_o | n5403_o;
  /* T80_MCode.vhd:1368:66  */
  assign n5406_o = ir == 8'b00110011;
  /* T80_MCode.vhd:1368:66  */
  assign n5407_o = n5404_o | n5406_o;
  /* T80_MCode.vhd:1368:77  */
  assign n5409_o = ir == 8'b00110100;
  /* T80_MCode.vhd:1368:77  */
  assign n5410_o = n5407_o | n5409_o;
  /* T80_MCode.vhd:1368:88  */
  assign n5412_o = ir == 8'b00110101;
  /* T80_MCode.vhd:1368:88  */
  assign n5413_o = n5410_o | n5412_o;
  /* T80_MCode.vhd:1368:99  */
  assign n5415_o = ir == 8'b00110111;
  /* T80_MCode.vhd:1368:99  */
  assign n5416_o = n5413_o | n5415_o;
  /* T80_MCode.vhd:1369:33  */
  assign n5418_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1369:33  */
  assign n5419_o = n5416_o | n5418_o;
  /* T80_MCode.vhd:1369:44  */
  assign n5421_o = ir == 8'b00111001;
  /* T80_MCode.vhd:1369:44  */
  assign n5422_o = n5419_o | n5421_o;
  /* T80_MCode.vhd:1369:55  */
  assign n5424_o = ir == 8'b00111010;
  /* T80_MCode.vhd:1369:55  */
  assign n5425_o = n5422_o | n5424_o;
  /* T80_MCode.vhd:1369:66  */
  assign n5427_o = ir == 8'b00111011;
  /* T80_MCode.vhd:1369:66  */
  assign n5428_o = n5425_o | n5427_o;
  /* T80_MCode.vhd:1369:77  */
  assign n5430_o = ir == 8'b00111100;
  /* T80_MCode.vhd:1369:77  */
  assign n5431_o = n5428_o | n5430_o;
  /* T80_MCode.vhd:1369:88  */
  assign n5433_o = ir == 8'b00111101;
  /* T80_MCode.vhd:1369:88  */
  assign n5434_o = n5431_o | n5433_o;
  /* T80_MCode.vhd:1369:99  */
  assign n5436_o = ir == 8'b00111111;
  /* T80_MCode.vhd:1369:99  */
  assign n5437_o = n5434_o | n5436_o;
  /* T80_MCode.vhd:1413:38  */
  assign n5438_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1414:33  */
  assign n5440_o = n5438_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1414:40  */
  assign n5442_o = n5438_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1414:40  */
  assign n5443_o = n5440_o | n5442_o;
  /* T80_MCode.vhd:1416:33  */
  assign n5445_o = n5438_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1422:33  */
  assign n5447_o = n5438_o == 31'b0000000000000000000000000000011;
  assign n5448_o = {n5447_o, n5445_o, n5443_o};
  /* T80_MCode.vhd:1413:33  */
  always @*
    case (n5448_o)
      3'b100: n5450_o = n2122_o;
      3'b010: n5450_o = 3'b100;
      3'b001: n5450_o = n2122_o;
      default: n5450_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1413:33  */
  always @*
    case (n5448_o)
      3'b100: n5453_o = 1'b0;
      3'b010: n5453_o = 1'b1;
      3'b001: n5453_o = 1'b0;
      default: n5453_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1413:33  */
  always @*
    case (n5448_o)
      3'b100: n5455_o = n2125_o;
      3'b010: n5455_o = 4'b1000;
      3'b001: n5455_o = n2125_o;
      default: n5455_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1413:33  */
  always @*
    case (n5448_o)
      3'b100: n5458_o = 1'b0;
      3'b010: n5458_o = 1'b1;
      3'b001: n5458_o = 1'b0;
      default: n5458_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1413:33  */
  always @*
    case (n5448_o)
      3'b100: n5462_o = 3'b111;
      3'b010: n5462_o = 3'b010;
      3'b001: n5462_o = 3'b010;
      default: n5462_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1413:33  */
  always @*
    case (n5448_o)
      3'b100: n5465_o = 1'b1;
      3'b010: n5465_o = 1'b0;
      3'b001: n5465_o = 1'b0;
      default: n5465_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1403:25  */
  assign n5467_o = ir == 8'b00000110;
  /* T80_MCode.vhd:1403:40  */
  assign n5469_o = ir == 8'b00010110;
  /* T80_MCode.vhd:1403:40  */
  assign n5470_o = n5467_o | n5469_o;
  /* T80_MCode.vhd:1403:51  */
  assign n5472_o = ir == 8'b00001110;
  /* T80_MCode.vhd:1403:51  */
  assign n5473_o = n5470_o | n5472_o;
  /* T80_MCode.vhd:1403:62  */
  assign n5475_o = ir == 8'b00011110;
  /* T80_MCode.vhd:1403:62  */
  assign n5476_o = n5473_o | n5475_o;
  /* T80_MCode.vhd:1403:73  */
  assign n5478_o = ir == 8'b00101110;
  /* T80_MCode.vhd:1403:73  */
  assign n5479_o = n5476_o | n5478_o;
  /* T80_MCode.vhd:1403:84  */
  assign n5481_o = ir == 8'b00111110;
  /* T80_MCode.vhd:1403:84  */
  assign n5482_o = n5479_o | n5481_o;
  /* T80_MCode.vhd:1403:95  */
  assign n5484_o = ir == 8'b00100110;
  /* T80_MCode.vhd:1403:95  */
  assign n5485_o = n5482_o | n5484_o;
  /* T80_MCode.vhd:1403:106  */
  assign n5487_o = ir == 8'b00110110;
  /* T80_MCode.vhd:1403:106  */
  assign n5488_o = n5485_o | n5487_o;
  /* T80_MCode.vhd:1435:44  */
  assign n5490_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1436:51  */
  assign n5492_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1437:72  */
  assign n5493_o = ir[2:0];
  /* T80_MCode.vhd:1435:33  */
  assign n5494_o = n5517_o ? n5493_o : n5216_o;
  /* T80_MCode.vhd:1436:41  */
  assign n5496_o = n5492_o ? 4'b1001 : n2125_o;
  /* T80_MCode.vhd:1444:46  */
  assign n5497_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1445:41  */
  assign n5499_o = n5497_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1445:48  */
  assign n5501_o = n5497_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1445:48  */
  assign n5502_o = n5499_o | n5501_o;
  /* T80_MCode.vhd:1447:41  */
  assign n5504_o = n5497_o == 31'b0000000000000000000000000000010;
  assign n5505_o = {n5504_o, n5502_o};
  /* T80_MCode.vhd:1444:41  */
  always @*
    case (n5505_o)
      2'b10: n5507_o = 3'b100;
      2'b01: n5507_o = n2122_o;
      default: n5507_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1444:41  */
  always @*
    case (n5505_o)
      2'b10: n5509_o = 4'b1001;
      2'b01: n5509_o = n2125_o;
      default: n5509_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1444:41  */
  always @*
    case (n5505_o)
      2'b10: n5512_o = 3'b111;
      2'b01: n5512_o = 3'b010;
      default: n5512_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1435:33  */
  assign n5515_o = n5490_o ? 3'b001 : 3'b010;
  /* T80_MCode.vhd:1435:33  */
  assign n5516_o = n5490_o ? n2122_o : n5507_o;
  /* T80_MCode.vhd:1435:33  */
  assign n5517_o = n5492_o & n5490_o;
  /* T80_MCode.vhd:1435:33  */
  assign n5518_o = n5490_o ? n5496_o : n5509_o;
  /* T80_MCode.vhd:1435:33  */
  assign n5520_o = n5490_o ? 3'b111 : n5512_o;
  /* T80_MCode.vhd:1435:33  */
  assign n5523_o = n5490_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1426:25  */
  assign n5525_o = ir == 8'b01000000;
  /* T80_MCode.vhd:1426:40  */
  assign n5527_o = ir == 8'b01000001;
  /* T80_MCode.vhd:1426:40  */
  assign n5528_o = n5525_o | n5527_o;
  /* T80_MCode.vhd:1426:51  */
  assign n5530_o = ir == 8'b01000010;
  /* T80_MCode.vhd:1426:51  */
  assign n5531_o = n5528_o | n5530_o;
  /* T80_MCode.vhd:1426:62  */
  assign n5533_o = ir == 8'b01000011;
  /* T80_MCode.vhd:1426:62  */
  assign n5534_o = n5531_o | n5533_o;
  /* T80_MCode.vhd:1426:73  */
  assign n5536_o = ir == 8'b01000100;
  /* T80_MCode.vhd:1426:73  */
  assign n5537_o = n5534_o | n5536_o;
  /* T80_MCode.vhd:1426:84  */
  assign n5539_o = ir == 8'b01000101;
  /* T80_MCode.vhd:1426:84  */
  assign n5540_o = n5537_o | n5539_o;
  /* T80_MCode.vhd:1426:95  */
  assign n5542_o = ir == 8'b01000111;
  /* T80_MCode.vhd:1426:95  */
  assign n5543_o = n5540_o | n5542_o;
  /* T80_MCode.vhd:1427:33  */
  assign n5545_o = ir == 8'b01001000;
  /* T80_MCode.vhd:1427:33  */
  assign n5546_o = n5543_o | n5545_o;
  /* T80_MCode.vhd:1427:44  */
  assign n5548_o = ir == 8'b01001001;
  /* T80_MCode.vhd:1427:44  */
  assign n5549_o = n5546_o | n5548_o;
  /* T80_MCode.vhd:1427:55  */
  assign n5551_o = ir == 8'b01001010;
  /* T80_MCode.vhd:1427:55  */
  assign n5552_o = n5549_o | n5551_o;
  /* T80_MCode.vhd:1427:66  */
  assign n5554_o = ir == 8'b01001011;
  /* T80_MCode.vhd:1427:66  */
  assign n5555_o = n5552_o | n5554_o;
  /* T80_MCode.vhd:1427:77  */
  assign n5557_o = ir == 8'b01001100;
  /* T80_MCode.vhd:1427:77  */
  assign n5558_o = n5555_o | n5557_o;
  /* T80_MCode.vhd:1427:88  */
  assign n5560_o = ir == 8'b01001101;
  /* T80_MCode.vhd:1427:88  */
  assign n5561_o = n5558_o | n5560_o;
  /* T80_MCode.vhd:1427:99  */
  assign n5563_o = ir == 8'b01001111;
  /* T80_MCode.vhd:1427:99  */
  assign n5564_o = n5561_o | n5563_o;
  /* T80_MCode.vhd:1428:33  */
  assign n5566_o = ir == 8'b01010000;
  /* T80_MCode.vhd:1428:33  */
  assign n5567_o = n5564_o | n5566_o;
  /* T80_MCode.vhd:1428:44  */
  assign n5569_o = ir == 8'b01010001;
  /* T80_MCode.vhd:1428:44  */
  assign n5570_o = n5567_o | n5569_o;
  /* T80_MCode.vhd:1428:55  */
  assign n5572_o = ir == 8'b01010010;
  /* T80_MCode.vhd:1428:55  */
  assign n5573_o = n5570_o | n5572_o;
  /* T80_MCode.vhd:1428:66  */
  assign n5575_o = ir == 8'b01010011;
  /* T80_MCode.vhd:1428:66  */
  assign n5576_o = n5573_o | n5575_o;
  /* T80_MCode.vhd:1428:77  */
  assign n5578_o = ir == 8'b01010100;
  /* T80_MCode.vhd:1428:77  */
  assign n5579_o = n5576_o | n5578_o;
  /* T80_MCode.vhd:1428:88  */
  assign n5581_o = ir == 8'b01010101;
  /* T80_MCode.vhd:1428:88  */
  assign n5582_o = n5579_o | n5581_o;
  /* T80_MCode.vhd:1428:99  */
  assign n5584_o = ir == 8'b01010111;
  /* T80_MCode.vhd:1428:99  */
  assign n5585_o = n5582_o | n5584_o;
  /* T80_MCode.vhd:1429:33  */
  assign n5587_o = ir == 8'b01011000;
  /* T80_MCode.vhd:1429:33  */
  assign n5588_o = n5585_o | n5587_o;
  /* T80_MCode.vhd:1429:44  */
  assign n5590_o = ir == 8'b01011001;
  /* T80_MCode.vhd:1429:44  */
  assign n5591_o = n5588_o | n5590_o;
  /* T80_MCode.vhd:1429:55  */
  assign n5593_o = ir == 8'b01011010;
  /* T80_MCode.vhd:1429:55  */
  assign n5594_o = n5591_o | n5593_o;
  /* T80_MCode.vhd:1429:66  */
  assign n5596_o = ir == 8'b01011011;
  /* T80_MCode.vhd:1429:66  */
  assign n5597_o = n5594_o | n5596_o;
  /* T80_MCode.vhd:1429:77  */
  assign n5599_o = ir == 8'b01011100;
  /* T80_MCode.vhd:1429:77  */
  assign n5600_o = n5597_o | n5599_o;
  /* T80_MCode.vhd:1429:88  */
  assign n5602_o = ir == 8'b01011101;
  /* T80_MCode.vhd:1429:88  */
  assign n5603_o = n5600_o | n5602_o;
  /* T80_MCode.vhd:1429:99  */
  assign n5605_o = ir == 8'b01011111;
  /* T80_MCode.vhd:1429:99  */
  assign n5606_o = n5603_o | n5605_o;
  /* T80_MCode.vhd:1430:33  */
  assign n5608_o = ir == 8'b01100000;
  /* T80_MCode.vhd:1430:33  */
  assign n5609_o = n5606_o | n5608_o;
  /* T80_MCode.vhd:1430:44  */
  assign n5611_o = ir == 8'b01100001;
  /* T80_MCode.vhd:1430:44  */
  assign n5612_o = n5609_o | n5611_o;
  /* T80_MCode.vhd:1430:55  */
  assign n5614_o = ir == 8'b01100010;
  /* T80_MCode.vhd:1430:55  */
  assign n5615_o = n5612_o | n5614_o;
  /* T80_MCode.vhd:1430:66  */
  assign n5617_o = ir == 8'b01100011;
  /* T80_MCode.vhd:1430:66  */
  assign n5618_o = n5615_o | n5617_o;
  /* T80_MCode.vhd:1430:77  */
  assign n5620_o = ir == 8'b01100100;
  /* T80_MCode.vhd:1430:77  */
  assign n5621_o = n5618_o | n5620_o;
  /* T80_MCode.vhd:1430:88  */
  assign n5623_o = ir == 8'b01100101;
  /* T80_MCode.vhd:1430:88  */
  assign n5624_o = n5621_o | n5623_o;
  /* T80_MCode.vhd:1430:99  */
  assign n5626_o = ir == 8'b01100111;
  /* T80_MCode.vhd:1430:99  */
  assign n5627_o = n5624_o | n5626_o;
  /* T80_MCode.vhd:1431:33  */
  assign n5629_o = ir == 8'b01101000;
  /* T80_MCode.vhd:1431:33  */
  assign n5630_o = n5627_o | n5629_o;
  /* T80_MCode.vhd:1431:44  */
  assign n5632_o = ir == 8'b01101001;
  /* T80_MCode.vhd:1431:44  */
  assign n5633_o = n5630_o | n5632_o;
  /* T80_MCode.vhd:1431:55  */
  assign n5635_o = ir == 8'b01101010;
  /* T80_MCode.vhd:1431:55  */
  assign n5636_o = n5633_o | n5635_o;
  /* T80_MCode.vhd:1431:66  */
  assign n5638_o = ir == 8'b01101011;
  /* T80_MCode.vhd:1431:66  */
  assign n5639_o = n5636_o | n5638_o;
  /* T80_MCode.vhd:1431:77  */
  assign n5641_o = ir == 8'b01101100;
  /* T80_MCode.vhd:1431:77  */
  assign n5642_o = n5639_o | n5641_o;
  /* T80_MCode.vhd:1431:88  */
  assign n5644_o = ir == 8'b01101101;
  /* T80_MCode.vhd:1431:88  */
  assign n5645_o = n5642_o | n5644_o;
  /* T80_MCode.vhd:1431:99  */
  assign n5647_o = ir == 8'b01101111;
  /* T80_MCode.vhd:1431:99  */
  assign n5648_o = n5645_o | n5647_o;
  /* T80_MCode.vhd:1432:33  */
  assign n5650_o = ir == 8'b01110000;
  /* T80_MCode.vhd:1432:33  */
  assign n5651_o = n5648_o | n5650_o;
  /* T80_MCode.vhd:1432:44  */
  assign n5653_o = ir == 8'b01110001;
  /* T80_MCode.vhd:1432:44  */
  assign n5654_o = n5651_o | n5653_o;
  /* T80_MCode.vhd:1432:55  */
  assign n5656_o = ir == 8'b01110010;
  /* T80_MCode.vhd:1432:55  */
  assign n5657_o = n5654_o | n5656_o;
  /* T80_MCode.vhd:1432:66  */
  assign n5659_o = ir == 8'b01110011;
  /* T80_MCode.vhd:1432:66  */
  assign n5660_o = n5657_o | n5659_o;
  /* T80_MCode.vhd:1432:77  */
  assign n5662_o = ir == 8'b01110100;
  /* T80_MCode.vhd:1432:77  */
  assign n5663_o = n5660_o | n5662_o;
  /* T80_MCode.vhd:1432:88  */
  assign n5665_o = ir == 8'b01110101;
  /* T80_MCode.vhd:1432:88  */
  assign n5666_o = n5663_o | n5665_o;
  /* T80_MCode.vhd:1432:99  */
  assign n5668_o = ir == 8'b01110111;
  /* T80_MCode.vhd:1432:99  */
  assign n5669_o = n5666_o | n5668_o;
  /* T80_MCode.vhd:1433:33  */
  assign n5671_o = ir == 8'b01111000;
  /* T80_MCode.vhd:1433:33  */
  assign n5672_o = n5669_o | n5671_o;
  /* T80_MCode.vhd:1433:44  */
  assign n5674_o = ir == 8'b01111001;
  /* T80_MCode.vhd:1433:44  */
  assign n5675_o = n5672_o | n5674_o;
  /* T80_MCode.vhd:1433:55  */
  assign n5677_o = ir == 8'b01111010;
  /* T80_MCode.vhd:1433:55  */
  assign n5678_o = n5675_o | n5677_o;
  /* T80_MCode.vhd:1433:66  */
  assign n5680_o = ir == 8'b01111011;
  /* T80_MCode.vhd:1433:66  */
  assign n5681_o = n5678_o | n5680_o;
  /* T80_MCode.vhd:1433:77  */
  assign n5683_o = ir == 8'b01111100;
  /* T80_MCode.vhd:1433:77  */
  assign n5684_o = n5681_o | n5683_o;
  /* T80_MCode.vhd:1433:88  */
  assign n5686_o = ir == 8'b01111101;
  /* T80_MCode.vhd:1433:88  */
  assign n5687_o = n5684_o | n5686_o;
  /* T80_MCode.vhd:1433:99  */
  assign n5689_o = ir == 8'b01111111;
  /* T80_MCode.vhd:1433:99  */
  assign n5690_o = n5687_o | n5689_o;
  /* T80_MCode.vhd:1457:38  */
  assign n5691_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1458:33  */
  assign n5693_o = n5691_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1458:40  */
  assign n5695_o = n5691_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1458:40  */
  assign n5696_o = n5693_o | n5695_o;
  /* T80_MCode.vhd:1460:33  */
  assign n5698_o = n5691_o == 31'b0000000000000000000000000000010;
  assign n5699_o = {n5698_o, n5696_o};
  /* T80_MCode.vhd:1457:33  */
  always @*
    case (n5699_o)
      2'b10: n5701_o = 3'b100;
      2'b01: n5701_o = n2122_o;
      default: n5701_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1457:33  */
  always @*
    case (n5699_o)
      2'b10: n5703_o = 4'b1001;
      2'b01: n5703_o = n2125_o;
      default: n5703_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1457:33  */
  always @*
    case (n5699_o)
      2'b10: n5706_o = 3'b111;
      2'b01: n5706_o = 3'b010;
      default: n5706_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1454:25  */
  assign n5708_o = ir == 8'b01000110;
  /* T80_MCode.vhd:1454:40  */
  assign n5710_o = ir == 8'b01001110;
  /* T80_MCode.vhd:1454:40  */
  assign n5711_o = n5708_o | n5710_o;
  /* T80_MCode.vhd:1454:51  */
  assign n5713_o = ir == 8'b01010110;
  /* T80_MCode.vhd:1454:51  */
  assign n5714_o = n5711_o | n5713_o;
  /* T80_MCode.vhd:1454:62  */
  assign n5716_o = ir == 8'b01011110;
  /* T80_MCode.vhd:1454:62  */
  assign n5717_o = n5714_o | n5716_o;
  /* T80_MCode.vhd:1454:73  */
  assign n5719_o = ir == 8'b01100110;
  /* T80_MCode.vhd:1454:73  */
  assign n5720_o = n5717_o | n5719_o;
  /* T80_MCode.vhd:1454:84  */
  assign n5722_o = ir == 8'b01101110;
  /* T80_MCode.vhd:1454:84  */
  assign n5723_o = n5720_o | n5722_o;
  /* T80_MCode.vhd:1454:95  */
  assign n5725_o = ir == 8'b01110110;
  /* T80_MCode.vhd:1454:95  */
  assign n5726_o = n5723_o | n5725_o;
  /* T80_MCode.vhd:1454:106  */
  assign n5728_o = ir == 8'b01111110;
  /* T80_MCode.vhd:1454:106  */
  assign n5729_o = n5726_o | n5728_o;
  /* T80_MCode.vhd:1474:44  */
  assign n5731_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1475:51  */
  assign n5733_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1475:41  */
  assign n5736_o = n5733_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1475:41  */
  assign n5738_o = n5733_o ? 4'b1010 : n2125_o;
  /* T80_MCode.vhd:1475:41  */
  assign n5741_o = n5733_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1484:46  */
  assign n5742_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1485:41  */
  assign n5744_o = n5742_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1485:48  */
  assign n5746_o = n5742_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1485:48  */
  assign n5747_o = n5744_o | n5746_o;
  /* T80_MCode.vhd:1487:41  */
  assign n5749_o = n5742_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1493:41  */
  assign n5751_o = n5742_o == 31'b0000000000000000000000000000011;
  assign n5752_o = {n5751_o, n5749_o, n5747_o};
  /* T80_MCode.vhd:1484:41  */
  always @*
    case (n5752_o)
      3'b100: n5754_o = n2122_o;
      3'b010: n5754_o = 3'b100;
      3'b001: n5754_o = n2122_o;
      default: n5754_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1484:41  */
  always @*
    case (n5752_o)
      3'b100: n5757_o = 1'b0;
      3'b010: n5757_o = 1'b1;
      3'b001: n5757_o = 1'b0;
      default: n5757_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1484:41  */
  always @*
    case (n5752_o)
      3'b100: n5759_o = n2125_o;
      3'b010: n5759_o = 4'b1010;
      3'b001: n5759_o = n2125_o;
      default: n5759_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1484:41  */
  always @*
    case (n5752_o)
      3'b100: n5762_o = 1'b0;
      3'b010: n5762_o = 1'b1;
      3'b001: n5762_o = 1'b0;
      default: n5762_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1484:41  */
  always @*
    case (n5752_o)
      3'b100: n5766_o = 3'b111;
      3'b010: n5766_o = 3'b010;
      3'b001: n5766_o = 3'b010;
      default: n5766_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1484:41  */
  always @*
    case (n5752_o)
      3'b100: n5769_o = 1'b1;
      3'b010: n5769_o = 1'b0;
      3'b001: n5769_o = 1'b0;
      default: n5769_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1474:33  */
  assign n5772_o = n5731_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1474:33  */
  assign n5773_o = n5731_o ? n2122_o : n5754_o;
  /* T80_MCode.vhd:1474:33  */
  assign n5774_o = n5731_o ? n5736_o : n5757_o;
  /* T80_MCode.vhd:1474:33  */
  assign n5775_o = n5731_o ? n5738_o : n5759_o;
  /* T80_MCode.vhd:1474:33  */
  assign n5776_o = n5731_o ? n5741_o : n5762_o;
  /* T80_MCode.vhd:1474:33  */
  assign n5778_o = n5731_o ? 3'b111 : n5766_o;
  /* T80_MCode.vhd:1474:33  */
  assign n5780_o = n5731_o ? 1'b0 : n5769_o;
  /* T80_MCode.vhd:1474:33  */
  assign n5783_o = n5731_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1465:25  */
  assign n5785_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1465:40  */
  assign n5787_o = ir == 8'b11000001;
  /* T80_MCode.vhd:1465:40  */
  assign n5788_o = n5785_o | n5787_o;
  /* T80_MCode.vhd:1465:51  */
  assign n5790_o = ir == 8'b11000010;
  /* T80_MCode.vhd:1465:51  */
  assign n5791_o = n5788_o | n5790_o;
  /* T80_MCode.vhd:1465:62  */
  assign n5793_o = ir == 8'b11000011;
  /* T80_MCode.vhd:1465:62  */
  assign n5794_o = n5791_o | n5793_o;
  /* T80_MCode.vhd:1465:73  */
  assign n5796_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1465:73  */
  assign n5797_o = n5794_o | n5796_o;
  /* T80_MCode.vhd:1465:84  */
  assign n5799_o = ir == 8'b11000101;
  /* T80_MCode.vhd:1465:84  */
  assign n5800_o = n5797_o | n5799_o;
  /* T80_MCode.vhd:1465:95  */
  assign n5802_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1465:95  */
  assign n5803_o = n5800_o | n5802_o;
  /* T80_MCode.vhd:1466:33  */
  assign n5805_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1466:33  */
  assign n5806_o = n5803_o | n5805_o;
  /* T80_MCode.vhd:1466:44  */
  assign n5808_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1466:44  */
  assign n5809_o = n5806_o | n5808_o;
  /* T80_MCode.vhd:1466:55  */
  assign n5811_o = ir == 8'b11001010;
  /* T80_MCode.vhd:1466:55  */
  assign n5812_o = n5809_o | n5811_o;
  /* T80_MCode.vhd:1466:66  */
  assign n5814_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1466:66  */
  assign n5815_o = n5812_o | n5814_o;
  /* T80_MCode.vhd:1466:77  */
  assign n5817_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1466:77  */
  assign n5818_o = n5815_o | n5817_o;
  /* T80_MCode.vhd:1466:88  */
  assign n5820_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1466:88  */
  assign n5821_o = n5818_o | n5820_o;
  /* T80_MCode.vhd:1466:99  */
  assign n5823_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1466:99  */
  assign n5824_o = n5821_o | n5823_o;
  /* T80_MCode.vhd:1467:33  */
  assign n5826_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1467:33  */
  assign n5827_o = n5824_o | n5826_o;
  /* T80_MCode.vhd:1467:44  */
  assign n5829_o = ir == 8'b11010001;
  /* T80_MCode.vhd:1467:44  */
  assign n5830_o = n5827_o | n5829_o;
  /* T80_MCode.vhd:1467:55  */
  assign n5832_o = ir == 8'b11010010;
  /* T80_MCode.vhd:1467:55  */
  assign n5833_o = n5830_o | n5832_o;
  /* T80_MCode.vhd:1467:66  */
  assign n5835_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1467:66  */
  assign n5836_o = n5833_o | n5835_o;
  /* T80_MCode.vhd:1467:77  */
  assign n5838_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1467:77  */
  assign n5839_o = n5836_o | n5838_o;
  /* T80_MCode.vhd:1467:88  */
  assign n5841_o = ir == 8'b11010101;
  /* T80_MCode.vhd:1467:88  */
  assign n5842_o = n5839_o | n5841_o;
  /* T80_MCode.vhd:1467:99  */
  assign n5844_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1467:99  */
  assign n5845_o = n5842_o | n5844_o;
  /* T80_MCode.vhd:1468:33  */
  assign n5847_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1468:33  */
  assign n5848_o = n5845_o | n5847_o;
  /* T80_MCode.vhd:1468:44  */
  assign n5850_o = ir == 8'b11011001;
  /* T80_MCode.vhd:1468:44  */
  assign n5851_o = n5848_o | n5850_o;
  /* T80_MCode.vhd:1468:55  */
  assign n5853_o = ir == 8'b11011010;
  /* T80_MCode.vhd:1468:55  */
  assign n5854_o = n5851_o | n5853_o;
  /* T80_MCode.vhd:1468:66  */
  assign n5856_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1468:66  */
  assign n5857_o = n5854_o | n5856_o;
  /* T80_MCode.vhd:1468:77  */
  assign n5859_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1468:77  */
  assign n5860_o = n5857_o | n5859_o;
  /* T80_MCode.vhd:1468:88  */
  assign n5862_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1468:88  */
  assign n5863_o = n5860_o | n5862_o;
  /* T80_MCode.vhd:1468:99  */
  assign n5865_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1468:99  */
  assign n5866_o = n5863_o | n5865_o;
  /* T80_MCode.vhd:1469:33  */
  assign n5868_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1469:33  */
  assign n5869_o = n5866_o | n5868_o;
  /* T80_MCode.vhd:1469:44  */
  assign n5871_o = ir == 8'b11100001;
  /* T80_MCode.vhd:1469:44  */
  assign n5872_o = n5869_o | n5871_o;
  /* T80_MCode.vhd:1469:55  */
  assign n5874_o = ir == 8'b11100010;
  /* T80_MCode.vhd:1469:55  */
  assign n5875_o = n5872_o | n5874_o;
  /* T80_MCode.vhd:1469:66  */
  assign n5877_o = ir == 8'b11100011;
  /* T80_MCode.vhd:1469:66  */
  assign n5878_o = n5875_o | n5877_o;
  /* T80_MCode.vhd:1469:77  */
  assign n5880_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1469:77  */
  assign n5881_o = n5878_o | n5880_o;
  /* T80_MCode.vhd:1469:88  */
  assign n5883_o = ir == 8'b11100101;
  /* T80_MCode.vhd:1469:88  */
  assign n5884_o = n5881_o | n5883_o;
  /* T80_MCode.vhd:1469:99  */
  assign n5886_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1469:99  */
  assign n5887_o = n5884_o | n5886_o;
  /* T80_MCode.vhd:1470:33  */
  assign n5889_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1470:33  */
  assign n5890_o = n5887_o | n5889_o;
  /* T80_MCode.vhd:1470:44  */
  assign n5892_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1470:44  */
  assign n5893_o = n5890_o | n5892_o;
  /* T80_MCode.vhd:1470:55  */
  assign n5895_o = ir == 8'b11101010;
  /* T80_MCode.vhd:1470:55  */
  assign n5896_o = n5893_o | n5895_o;
  /* T80_MCode.vhd:1470:66  */
  assign n5898_o = ir == 8'b11101011;
  /* T80_MCode.vhd:1470:66  */
  assign n5899_o = n5896_o | n5898_o;
  /* T80_MCode.vhd:1470:77  */
  assign n5901_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1470:77  */
  assign n5902_o = n5899_o | n5901_o;
  /* T80_MCode.vhd:1470:88  */
  assign n5904_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1470:88  */
  assign n5905_o = n5902_o | n5904_o;
  /* T80_MCode.vhd:1470:99  */
  assign n5907_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1470:99  */
  assign n5908_o = n5905_o | n5907_o;
  /* T80_MCode.vhd:1471:33  */
  assign n5910_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1471:33  */
  assign n5911_o = n5908_o | n5910_o;
  /* T80_MCode.vhd:1471:44  */
  assign n5913_o = ir == 8'b11110001;
  /* T80_MCode.vhd:1471:44  */
  assign n5914_o = n5911_o | n5913_o;
  /* T80_MCode.vhd:1471:55  */
  assign n5916_o = ir == 8'b11110010;
  /* T80_MCode.vhd:1471:55  */
  assign n5917_o = n5914_o | n5916_o;
  /* T80_MCode.vhd:1471:66  */
  assign n5919_o = ir == 8'b11110011;
  /* T80_MCode.vhd:1471:66  */
  assign n5920_o = n5917_o | n5919_o;
  /* T80_MCode.vhd:1471:77  */
  assign n5922_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1471:77  */
  assign n5923_o = n5920_o | n5922_o;
  /* T80_MCode.vhd:1471:88  */
  assign n5925_o = ir == 8'b11110101;
  /* T80_MCode.vhd:1471:88  */
  assign n5926_o = n5923_o | n5925_o;
  /* T80_MCode.vhd:1471:99  */
  assign n5928_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1471:99  */
  assign n5929_o = n5926_o | n5928_o;
  /* T80_MCode.vhd:1472:33  */
  assign n5931_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1472:33  */
  assign n5932_o = n5929_o | n5931_o;
  /* T80_MCode.vhd:1472:44  */
  assign n5934_o = ir == 8'b11111001;
  /* T80_MCode.vhd:1472:44  */
  assign n5935_o = n5932_o | n5934_o;
  /* T80_MCode.vhd:1472:55  */
  assign n5937_o = ir == 8'b11111010;
  /* T80_MCode.vhd:1472:55  */
  assign n5938_o = n5935_o | n5937_o;
  /* T80_MCode.vhd:1472:66  */
  assign n5940_o = ir == 8'b11111011;
  /* T80_MCode.vhd:1472:66  */
  assign n5941_o = n5938_o | n5940_o;
  /* T80_MCode.vhd:1472:77  */
  assign n5943_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1472:77  */
  assign n5944_o = n5941_o | n5943_o;
  /* T80_MCode.vhd:1472:88  */
  assign n5946_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1472:88  */
  assign n5947_o = n5944_o | n5946_o;
  /* T80_MCode.vhd:1472:99  */
  assign n5949_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1472:99  */
  assign n5950_o = n5947_o | n5949_o;
  /* T80_MCode.vhd:1502:38  */
  assign n5951_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1503:33  */
  assign n5953_o = n5951_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1503:40  */
  assign n5955_o = n5951_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1503:40  */
  assign n5956_o = n5953_o | n5955_o;
  /* T80_MCode.vhd:1505:33  */
  assign n5958_o = n5951_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1511:33  */
  assign n5960_o = n5951_o == 31'b0000000000000000000000000000011;
  assign n5961_o = {n5960_o, n5958_o, n5956_o};
  /* T80_MCode.vhd:1502:33  */
  always @*
    case (n5961_o)
      3'b100: n5963_o = n2122_o;
      3'b010: n5963_o = 3'b100;
      3'b001: n5963_o = n2122_o;
      default: n5963_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1502:33  */
  always @*
    case (n5961_o)
      3'b100: n5966_o = 1'b0;
      3'b010: n5966_o = 1'b1;
      3'b001: n5966_o = 1'b0;
      default: n5966_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1502:33  */
  always @*
    case (n5961_o)
      3'b100: n5968_o = n2125_o;
      3'b010: n5968_o = 4'b1010;
      3'b001: n5968_o = n2125_o;
      default: n5968_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1502:33  */
  always @*
    case (n5961_o)
      3'b100: n5971_o = 1'b0;
      3'b010: n5971_o = 1'b1;
      3'b001: n5971_o = 1'b0;
      default: n5971_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1502:33  */
  always @*
    case (n5961_o)
      3'b100: n5975_o = 3'b111;
      3'b010: n5975_o = 3'b010;
      3'b001: n5975_o = 3'b010;
      default: n5975_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1502:33  */
  always @*
    case (n5961_o)
      3'b100: n5978_o = 1'b1;
      3'b010: n5978_o = 1'b0;
      3'b001: n5978_o = 1'b0;
      default: n5978_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1499:25  */
  assign n5980_o = ir == 8'b11000110;
  /* T80_MCode.vhd:1499:40  */
  assign n5982_o = ir == 8'b11001110;
  /* T80_MCode.vhd:1499:40  */
  assign n5983_o = n5980_o | n5982_o;
  /* T80_MCode.vhd:1499:51  */
  assign n5985_o = ir == 8'b11010110;
  /* T80_MCode.vhd:1499:51  */
  assign n5986_o = n5983_o | n5985_o;
  /* T80_MCode.vhd:1499:62  */
  assign n5988_o = ir == 8'b11011110;
  /* T80_MCode.vhd:1499:62  */
  assign n5989_o = n5986_o | n5988_o;
  /* T80_MCode.vhd:1499:73  */
  assign n5991_o = ir == 8'b11100110;
  /* T80_MCode.vhd:1499:73  */
  assign n5992_o = n5989_o | n5991_o;
  /* T80_MCode.vhd:1499:84  */
  assign n5994_o = ir == 8'b11101110;
  /* T80_MCode.vhd:1499:84  */
  assign n5995_o = n5992_o | n5994_o;
  /* T80_MCode.vhd:1499:95  */
  assign n5997_o = ir == 8'b11110110;
  /* T80_MCode.vhd:1499:95  */
  assign n5998_o = n5995_o | n5997_o;
  /* T80_MCode.vhd:1499:106  */
  assign n6000_o = ir == 8'b11111110;
  /* T80_MCode.vhd:1499:106  */
  assign n6001_o = n5998_o | n6000_o;
  /* T80_MCode.vhd:1524:44  */
  assign n6003_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1525:51  */
  assign n6005_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1525:41  */
  assign n6008_o = n6005_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1525:41  */
  assign n6010_o = n6005_o ? 4'b1011 : n2125_o;
  /* T80_MCode.vhd:1525:41  */
  assign n6013_o = n6005_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1534:46  */
  assign n6014_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1535:41  */
  assign n6016_o = n6014_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1535:48  */
  assign n6018_o = n6014_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1535:48  */
  assign n6019_o = n6016_o | n6018_o;
  /* T80_MCode.vhd:1537:41  */
  assign n6021_o = n6014_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1543:41  */
  assign n6023_o = n6014_o == 31'b0000000000000000000000000000011;
  assign n6024_o = {n6023_o, n6021_o, n6019_o};
  /* T80_MCode.vhd:1534:41  */
  always @*
    case (n6024_o)
      3'b100: n6026_o = n2122_o;
      3'b010: n6026_o = 3'b100;
      3'b001: n6026_o = n2122_o;
      default: n6026_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1534:41  */
  always @*
    case (n6024_o)
      3'b100: n6029_o = 1'b0;
      3'b010: n6029_o = 1'b1;
      3'b001: n6029_o = 1'b0;
      default: n6029_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1534:41  */
  always @*
    case (n6024_o)
      3'b100: n6031_o = n2125_o;
      3'b010: n6031_o = 4'b1011;
      3'b001: n6031_o = n2125_o;
      default: n6031_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1534:41  */
  always @*
    case (n6024_o)
      3'b100: n6034_o = 1'b0;
      3'b010: n6034_o = 1'b1;
      3'b001: n6034_o = 1'b0;
      default: n6034_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1534:41  */
  always @*
    case (n6024_o)
      3'b100: n6038_o = 3'b111;
      3'b010: n6038_o = 3'b010;
      3'b001: n6038_o = 3'b010;
      default: n6038_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1534:41  */
  always @*
    case (n6024_o)
      3'b100: n6041_o = 1'b1;
      3'b010: n6041_o = 1'b0;
      3'b001: n6041_o = 1'b0;
      default: n6041_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1524:33  */
  assign n6044_o = n6003_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1524:33  */
  assign n6045_o = n6003_o ? n2122_o : n6026_o;
  /* T80_MCode.vhd:1524:33  */
  assign n6046_o = n6003_o ? n6008_o : n6029_o;
  /* T80_MCode.vhd:1524:33  */
  assign n6047_o = n6003_o ? n6010_o : n6031_o;
  /* T80_MCode.vhd:1524:33  */
  assign n6048_o = n6003_o ? n6013_o : n6034_o;
  /* T80_MCode.vhd:1524:33  */
  assign n6050_o = n6003_o ? 3'b111 : n6038_o;
  /* T80_MCode.vhd:1524:33  */
  assign n6052_o = n6003_o ? 1'b0 : n6041_o;
  /* T80_MCode.vhd:1524:33  */
  assign n6055_o = n6003_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1515:25  */
  assign n6057_o = ir == 8'b10000000;
  /* T80_MCode.vhd:1515:40  */
  assign n6059_o = ir == 8'b10000001;
  /* T80_MCode.vhd:1515:40  */
  assign n6060_o = n6057_o | n6059_o;
  /* T80_MCode.vhd:1515:51  */
  assign n6062_o = ir == 8'b10000010;
  /* T80_MCode.vhd:1515:51  */
  assign n6063_o = n6060_o | n6062_o;
  /* T80_MCode.vhd:1515:62  */
  assign n6065_o = ir == 8'b10000011;
  /* T80_MCode.vhd:1515:62  */
  assign n6066_o = n6063_o | n6065_o;
  /* T80_MCode.vhd:1515:73  */
  assign n6068_o = ir == 8'b10000100;
  /* T80_MCode.vhd:1515:73  */
  assign n6069_o = n6066_o | n6068_o;
  /* T80_MCode.vhd:1515:84  */
  assign n6071_o = ir == 8'b10000101;
  /* T80_MCode.vhd:1515:84  */
  assign n6072_o = n6069_o | n6071_o;
  /* T80_MCode.vhd:1515:95  */
  assign n6074_o = ir == 8'b10000111;
  /* T80_MCode.vhd:1515:95  */
  assign n6075_o = n6072_o | n6074_o;
  /* T80_MCode.vhd:1516:33  */
  assign n6077_o = ir == 8'b10001000;
  /* T80_MCode.vhd:1516:33  */
  assign n6078_o = n6075_o | n6077_o;
  /* T80_MCode.vhd:1516:44  */
  assign n6080_o = ir == 8'b10001001;
  /* T80_MCode.vhd:1516:44  */
  assign n6081_o = n6078_o | n6080_o;
  /* T80_MCode.vhd:1516:55  */
  assign n6083_o = ir == 8'b10001010;
  /* T80_MCode.vhd:1516:55  */
  assign n6084_o = n6081_o | n6083_o;
  /* T80_MCode.vhd:1516:66  */
  assign n6086_o = ir == 8'b10001011;
  /* T80_MCode.vhd:1516:66  */
  assign n6087_o = n6084_o | n6086_o;
  /* T80_MCode.vhd:1516:77  */
  assign n6089_o = ir == 8'b10001100;
  /* T80_MCode.vhd:1516:77  */
  assign n6090_o = n6087_o | n6089_o;
  /* T80_MCode.vhd:1516:88  */
  assign n6092_o = ir == 8'b10001101;
  /* T80_MCode.vhd:1516:88  */
  assign n6093_o = n6090_o | n6092_o;
  /* T80_MCode.vhd:1516:99  */
  assign n6095_o = ir == 8'b10001111;
  /* T80_MCode.vhd:1516:99  */
  assign n6096_o = n6093_o | n6095_o;
  /* T80_MCode.vhd:1517:33  */
  assign n6098_o = ir == 8'b10010000;
  /* T80_MCode.vhd:1517:33  */
  assign n6099_o = n6096_o | n6098_o;
  /* T80_MCode.vhd:1517:44  */
  assign n6101_o = ir == 8'b10010001;
  /* T80_MCode.vhd:1517:44  */
  assign n6102_o = n6099_o | n6101_o;
  /* T80_MCode.vhd:1517:55  */
  assign n6104_o = ir == 8'b10010010;
  /* T80_MCode.vhd:1517:55  */
  assign n6105_o = n6102_o | n6104_o;
  /* T80_MCode.vhd:1517:66  */
  assign n6107_o = ir == 8'b10010011;
  /* T80_MCode.vhd:1517:66  */
  assign n6108_o = n6105_o | n6107_o;
  /* T80_MCode.vhd:1517:77  */
  assign n6110_o = ir == 8'b10010100;
  /* T80_MCode.vhd:1517:77  */
  assign n6111_o = n6108_o | n6110_o;
  /* T80_MCode.vhd:1517:88  */
  assign n6113_o = ir == 8'b10010101;
  /* T80_MCode.vhd:1517:88  */
  assign n6114_o = n6111_o | n6113_o;
  /* T80_MCode.vhd:1517:99  */
  assign n6116_o = ir == 8'b10010111;
  /* T80_MCode.vhd:1517:99  */
  assign n6117_o = n6114_o | n6116_o;
  /* T80_MCode.vhd:1518:33  */
  assign n6119_o = ir == 8'b10011000;
  /* T80_MCode.vhd:1518:33  */
  assign n6120_o = n6117_o | n6119_o;
  /* T80_MCode.vhd:1518:44  */
  assign n6122_o = ir == 8'b10011001;
  /* T80_MCode.vhd:1518:44  */
  assign n6123_o = n6120_o | n6122_o;
  /* T80_MCode.vhd:1518:55  */
  assign n6125_o = ir == 8'b10011010;
  /* T80_MCode.vhd:1518:55  */
  assign n6126_o = n6123_o | n6125_o;
  /* T80_MCode.vhd:1518:66  */
  assign n6128_o = ir == 8'b10011011;
  /* T80_MCode.vhd:1518:66  */
  assign n6129_o = n6126_o | n6128_o;
  /* T80_MCode.vhd:1518:77  */
  assign n6131_o = ir == 8'b10011100;
  /* T80_MCode.vhd:1518:77  */
  assign n6132_o = n6129_o | n6131_o;
  /* T80_MCode.vhd:1518:88  */
  assign n6134_o = ir == 8'b10011101;
  /* T80_MCode.vhd:1518:88  */
  assign n6135_o = n6132_o | n6134_o;
  /* T80_MCode.vhd:1518:99  */
  assign n6137_o = ir == 8'b10011111;
  /* T80_MCode.vhd:1518:99  */
  assign n6138_o = n6135_o | n6137_o;
  /* T80_MCode.vhd:1519:33  */
  assign n6140_o = ir == 8'b10100000;
  /* T80_MCode.vhd:1519:33  */
  assign n6141_o = n6138_o | n6140_o;
  /* T80_MCode.vhd:1519:44  */
  assign n6143_o = ir == 8'b10100001;
  /* T80_MCode.vhd:1519:44  */
  assign n6144_o = n6141_o | n6143_o;
  /* T80_MCode.vhd:1519:55  */
  assign n6146_o = ir == 8'b10100010;
  /* T80_MCode.vhd:1519:55  */
  assign n6147_o = n6144_o | n6146_o;
  /* T80_MCode.vhd:1519:66  */
  assign n6149_o = ir == 8'b10100011;
  /* T80_MCode.vhd:1519:66  */
  assign n6150_o = n6147_o | n6149_o;
  /* T80_MCode.vhd:1519:77  */
  assign n6152_o = ir == 8'b10100100;
  /* T80_MCode.vhd:1519:77  */
  assign n6153_o = n6150_o | n6152_o;
  /* T80_MCode.vhd:1519:88  */
  assign n6155_o = ir == 8'b10100101;
  /* T80_MCode.vhd:1519:88  */
  assign n6156_o = n6153_o | n6155_o;
  /* T80_MCode.vhd:1519:99  */
  assign n6158_o = ir == 8'b10100111;
  /* T80_MCode.vhd:1519:99  */
  assign n6159_o = n6156_o | n6158_o;
  /* T80_MCode.vhd:1520:33  */
  assign n6161_o = ir == 8'b10101000;
  /* T80_MCode.vhd:1520:33  */
  assign n6162_o = n6159_o | n6161_o;
  /* T80_MCode.vhd:1520:44  */
  assign n6164_o = ir == 8'b10101001;
  /* T80_MCode.vhd:1520:44  */
  assign n6165_o = n6162_o | n6164_o;
  /* T80_MCode.vhd:1520:55  */
  assign n6167_o = ir == 8'b10101010;
  /* T80_MCode.vhd:1520:55  */
  assign n6168_o = n6165_o | n6167_o;
  /* T80_MCode.vhd:1520:66  */
  assign n6170_o = ir == 8'b10101011;
  /* T80_MCode.vhd:1520:66  */
  assign n6171_o = n6168_o | n6170_o;
  /* T80_MCode.vhd:1520:77  */
  assign n6173_o = ir == 8'b10101100;
  /* T80_MCode.vhd:1520:77  */
  assign n6174_o = n6171_o | n6173_o;
  /* T80_MCode.vhd:1520:88  */
  assign n6176_o = ir == 8'b10101101;
  /* T80_MCode.vhd:1520:88  */
  assign n6177_o = n6174_o | n6176_o;
  /* T80_MCode.vhd:1520:99  */
  assign n6179_o = ir == 8'b10101111;
  /* T80_MCode.vhd:1520:99  */
  assign n6180_o = n6177_o | n6179_o;
  /* T80_MCode.vhd:1521:33  */
  assign n6182_o = ir == 8'b10110000;
  /* T80_MCode.vhd:1521:33  */
  assign n6183_o = n6180_o | n6182_o;
  /* T80_MCode.vhd:1521:44  */
  assign n6185_o = ir == 8'b10110001;
  /* T80_MCode.vhd:1521:44  */
  assign n6186_o = n6183_o | n6185_o;
  /* T80_MCode.vhd:1521:55  */
  assign n6188_o = ir == 8'b10110010;
  /* T80_MCode.vhd:1521:55  */
  assign n6189_o = n6186_o | n6188_o;
  /* T80_MCode.vhd:1521:66  */
  assign n6191_o = ir == 8'b10110011;
  /* T80_MCode.vhd:1521:66  */
  assign n6192_o = n6189_o | n6191_o;
  /* T80_MCode.vhd:1521:77  */
  assign n6194_o = ir == 8'b10110100;
  /* T80_MCode.vhd:1521:77  */
  assign n6195_o = n6192_o | n6194_o;
  /* T80_MCode.vhd:1521:88  */
  assign n6197_o = ir == 8'b10110101;
  /* T80_MCode.vhd:1521:88  */
  assign n6198_o = n6195_o | n6197_o;
  /* T80_MCode.vhd:1521:99  */
  assign n6200_o = ir == 8'b10110111;
  /* T80_MCode.vhd:1521:99  */
  assign n6201_o = n6198_o | n6200_o;
  /* T80_MCode.vhd:1522:33  */
  assign n6203_o = ir == 8'b10111000;
  /* T80_MCode.vhd:1522:33  */
  assign n6204_o = n6201_o | n6203_o;
  /* T80_MCode.vhd:1522:44  */
  assign n6206_o = ir == 8'b10111001;
  /* T80_MCode.vhd:1522:44  */
  assign n6207_o = n6204_o | n6206_o;
  /* T80_MCode.vhd:1522:55  */
  assign n6209_o = ir == 8'b10111010;
  /* T80_MCode.vhd:1522:55  */
  assign n6210_o = n6207_o | n6209_o;
  /* T80_MCode.vhd:1522:66  */
  assign n6212_o = ir == 8'b10111011;
  /* T80_MCode.vhd:1522:66  */
  assign n6213_o = n6210_o | n6212_o;
  /* T80_MCode.vhd:1522:77  */
  assign n6215_o = ir == 8'b10111100;
  /* T80_MCode.vhd:1522:77  */
  assign n6216_o = n6213_o | n6215_o;
  /* T80_MCode.vhd:1522:88  */
  assign n6218_o = ir == 8'b10111101;
  /* T80_MCode.vhd:1522:88  */
  assign n6219_o = n6216_o | n6218_o;
  /* T80_MCode.vhd:1522:99  */
  assign n6221_o = ir == 8'b10111111;
  /* T80_MCode.vhd:1522:99  */
  assign n6222_o = n6219_o | n6221_o;
  /* T80_MCode.vhd:1552:38  */
  assign n6223_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1553:33  */
  assign n6225_o = n6223_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1553:40  */
  assign n6227_o = n6223_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1553:40  */
  assign n6228_o = n6225_o | n6227_o;
  /* T80_MCode.vhd:1555:33  */
  assign n6230_o = n6223_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1561:33  */
  assign n6232_o = n6223_o == 31'b0000000000000000000000000000011;
  assign n6233_o = {n6232_o, n6230_o, n6228_o};
  /* T80_MCode.vhd:1552:33  */
  always @*
    case (n6233_o)
      3'b100: n6235_o = n2122_o;
      3'b010: n6235_o = 3'b100;
      3'b001: n6235_o = n2122_o;
      default: n6235_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1552:33  */
  always @*
    case (n6233_o)
      3'b100: n6238_o = 1'b0;
      3'b010: n6238_o = 1'b1;
      3'b001: n6238_o = 1'b0;
      default: n6238_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1552:33  */
  always @*
    case (n6233_o)
      3'b100: n6240_o = n2125_o;
      3'b010: n6240_o = 4'b1011;
      3'b001: n6240_o = n2125_o;
      default: n6240_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1552:33  */
  always @*
    case (n6233_o)
      3'b100: n6243_o = 1'b0;
      3'b010: n6243_o = 1'b1;
      3'b001: n6243_o = 1'b0;
      default: n6243_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1552:33  */
  always @*
    case (n6233_o)
      3'b100: n6247_o = 3'b111;
      3'b010: n6247_o = 3'b010;
      3'b001: n6247_o = 3'b010;
      default: n6247_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1552:33  */
  always @*
    case (n6233_o)
      3'b100: n6250_o = 1'b1;
      3'b010: n6250_o = 1'b0;
      3'b001: n6250_o = 1'b0;
      default: n6250_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1549:25  */
  assign n6252_o = ir == 8'b10000110;
  /* T80_MCode.vhd:1549:40  */
  assign n6254_o = ir == 8'b10001110;
  /* T80_MCode.vhd:1549:40  */
  assign n6255_o = n6252_o | n6254_o;
  /* T80_MCode.vhd:1549:51  */
  assign n6257_o = ir == 8'b10010110;
  /* T80_MCode.vhd:1549:51  */
  assign n6258_o = n6255_o | n6257_o;
  /* T80_MCode.vhd:1549:62  */
  assign n6260_o = ir == 8'b10011110;
  /* T80_MCode.vhd:1549:62  */
  assign n6261_o = n6258_o | n6260_o;
  /* T80_MCode.vhd:1549:73  */
  assign n6263_o = ir == 8'b10100110;
  /* T80_MCode.vhd:1549:73  */
  assign n6264_o = n6261_o | n6263_o;
  /* T80_MCode.vhd:1549:84  */
  assign n6266_o = ir == 8'b10101110;
  /* T80_MCode.vhd:1549:84  */
  assign n6267_o = n6264_o | n6266_o;
  /* T80_MCode.vhd:1549:95  */
  assign n6269_o = ir == 8'b10110110;
  /* T80_MCode.vhd:1549:95  */
  assign n6270_o = n6267_o | n6269_o;
  /* T80_MCode.vhd:1549:106  */
  assign n6272_o = ir == 8'b10111110;
  /* T80_MCode.vhd:1549:106  */
  assign n6273_o = n6270_o | n6272_o;
  assign n6274_o = {n6273_o, n6222_o, n6001_o, n5950_o, n5729_o, n5690_o, n5488_o, n5437_o};
  /* T80_MCode.vhd:1361:25  */
  always @*
    case (n6274_o)
      8'b10000000: n6280_o = 3'b011;
      8'b01000000: n6280_o = n6044_o;
      8'b00100000: n6280_o = 3'b011;
      8'b00010000: n6280_o = n5772_o;
      8'b00001000: n6280_o = 3'b010;
      8'b00000100: n6280_o = n5515_o;
      8'b00000010: n6280_o = 3'b011;
      8'b00000001: n6280_o = n5259_o;
      default: n6280_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1361:25  */
  always @*
    case (n6274_o)
      8'b10000000: n6282_o = n6235_o;
      8'b01000000: n6282_o = n6045_o;
      8'b00100000: n6282_o = n5963_o;
      8'b00010000: n6282_o = n5773_o;
      8'b00001000: n6282_o = n5701_o;
      8'b00000100: n6282_o = n5516_o;
      8'b00000010: n6282_o = n5450_o;
      8'b00000001: n6282_o = n5260_o;
      default: n6282_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1361:25  */
  always @*
    case (n6274_o)
      8'b10000000: n6285_o = n6238_o;
      8'b01000000: n6285_o = n6046_o;
      8'b00100000: n6285_o = n5966_o;
      8'b00010000: n6285_o = n5774_o;
      8'b00001000: n6285_o = 1'b0;
      8'b00000100: n6285_o = 1'b0;
      8'b00000010: n6285_o = n5453_o;
      8'b00000001: n6285_o = n5261_o;
      default: n6285_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1361:25  */
  always @*
    case (n6274_o)
      8'b10000000: n6287_o = n5216_o;
      8'b01000000: n6287_o = n5216_o;
      8'b00100000: n6287_o = n5216_o;
      8'b00010000: n6287_o = n5216_o;
      8'b00001000: n6287_o = n5216_o;
      8'b00000100: n6287_o = n5494_o;
      8'b00000010: n6287_o = n5216_o;
      8'b00000001: n6287_o = n5216_o;
      default: n6287_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1361:25  */
  always @*
    case (n6274_o)
      8'b10000000: n6289_o = n6240_o;
      8'b01000000: n6289_o = n6047_o;
      8'b00100000: n6289_o = n5968_o;
      8'b00010000: n6289_o = n5775_o;
      8'b00001000: n6289_o = n5703_o;
      8'b00000100: n6289_o = n5518_o;
      8'b00000010: n6289_o = n5455_o;
      8'b00000001: n6289_o = n5262_o;
      default: n6289_o = 4'bX;
    endcase
  /* T80_MCode.vhd:1361:25  */
  always @*
    case (n6274_o)
      8'b10000000: n6292_o = n6243_o;
      8'b01000000: n6292_o = n6048_o;
      8'b00100000: n6292_o = n5971_o;
      8'b00010000: n6292_o = n5776_o;
      8'b00001000: n6292_o = 1'b0;
      8'b00000100: n6292_o = 1'b0;
      8'b00000010: n6292_o = n5458_o;
      8'b00000001: n6292_o = n5263_o;
      default: n6292_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1361:25  */
  always @*
    case (n6274_o)
      8'b10000000: n6294_o = n6247_o;
      8'b01000000: n6294_o = n6050_o;
      8'b00100000: n6294_o = n5975_o;
      8'b00010000: n6294_o = n5778_o;
      8'b00001000: n6294_o = n5706_o;
      8'b00000100: n6294_o = n5520_o;
      8'b00000010: n6294_o = n5462_o;
      8'b00000001: n6294_o = n5265_o;
      default: n6294_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1361:25  */
  always @*
    case (n6274_o)
      8'b10000000: n6297_o = n6250_o;
      8'b01000000: n6297_o = n6052_o;
      8'b00100000: n6297_o = n5978_o;
      8'b00010000: n6297_o = n5780_o;
      8'b00001000: n6297_o = 1'b0;
      8'b00000100: n6297_o = 1'b0;
      8'b00000010: n6297_o = n5465_o;
      8'b00000001: n6297_o = n5267_o;
      default: n6297_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1361:25  */
  always @*
    case (n6274_o)
      8'b10000000: n6300_o = 1'b0;
      8'b01000000: n6300_o = n6055_o;
      8'b00100000: n6300_o = 1'b0;
      8'b00010000: n6300_o = n5783_o;
      8'b00001000: n6300_o = 1'b0;
      8'b00000100: n6300_o = n5523_o;
      8'b00000010: n6300_o = 1'b0;
      8'b00000001: n6300_o = n5270_o;
      default: n6300_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1350:17  */
  assign n6302_o = iset == 2'b01;
  /* T80_MCode.vhd:1576:25  */
  assign n6304_o = ir == 8'b00000000;
  /* T80_MCode.vhd:1576:40  */
  assign n6306_o = ir == 8'b00000001;
  /* T80_MCode.vhd:1576:40  */
  assign n6307_o = n6304_o | n6306_o;
  /* T80_MCode.vhd:1576:51  */
  assign n6309_o = ir == 8'b00000010;
  /* T80_MCode.vhd:1576:51  */
  assign n6310_o = n6307_o | n6309_o;
  /* T80_MCode.vhd:1576:62  */
  assign n6312_o = ir == 8'b00000011;
  /* T80_MCode.vhd:1576:62  */
  assign n6313_o = n6310_o | n6312_o;
  /* T80_MCode.vhd:1576:73  */
  assign n6315_o = ir == 8'b00000100;
  /* T80_MCode.vhd:1576:73  */
  assign n6316_o = n6313_o | n6315_o;
  /* T80_MCode.vhd:1576:84  */
  assign n6318_o = ir == 8'b00000101;
  /* T80_MCode.vhd:1576:84  */
  assign n6319_o = n6316_o | n6318_o;
  /* T80_MCode.vhd:1576:95  */
  assign n6321_o = ir == 8'b00000110;
  /* T80_MCode.vhd:1576:95  */
  assign n6322_o = n6319_o | n6321_o;
  /* T80_MCode.vhd:1576:106  */
  assign n6324_o = ir == 8'b00000111;
  /* T80_MCode.vhd:1576:106  */
  assign n6325_o = n6322_o | n6324_o;
  /* T80_MCode.vhd:1577:33  */
  assign n6327_o = ir == 8'b00001000;
  /* T80_MCode.vhd:1577:33  */
  assign n6328_o = n6325_o | n6327_o;
  /* T80_MCode.vhd:1577:44  */
  assign n6330_o = ir == 8'b00001001;
  /* T80_MCode.vhd:1577:44  */
  assign n6331_o = n6328_o | n6330_o;
  /* T80_MCode.vhd:1577:55  */
  assign n6333_o = ir == 8'b00001010;
  /* T80_MCode.vhd:1577:55  */
  assign n6334_o = n6331_o | n6333_o;
  /* T80_MCode.vhd:1577:66  */
  assign n6336_o = ir == 8'b00001011;
  /* T80_MCode.vhd:1577:66  */
  assign n6337_o = n6334_o | n6336_o;
  /* T80_MCode.vhd:1577:77  */
  assign n6339_o = ir == 8'b00001100;
  /* T80_MCode.vhd:1577:77  */
  assign n6340_o = n6337_o | n6339_o;
  /* T80_MCode.vhd:1577:88  */
  assign n6342_o = ir == 8'b00001101;
  /* T80_MCode.vhd:1577:88  */
  assign n6343_o = n6340_o | n6342_o;
  /* T80_MCode.vhd:1577:99  */
  assign n6345_o = ir == 8'b00001110;
  /* T80_MCode.vhd:1577:99  */
  assign n6346_o = n6343_o | n6345_o;
  /* T80_MCode.vhd:1577:110  */
  assign n6348_o = ir == 8'b00001111;
  /* T80_MCode.vhd:1577:110  */
  assign n6349_o = n6346_o | n6348_o;
  /* T80_MCode.vhd:1578:33  */
  assign n6351_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1578:33  */
  assign n6352_o = n6349_o | n6351_o;
  /* T80_MCode.vhd:1578:44  */
  assign n6354_o = ir == 8'b00010001;
  /* T80_MCode.vhd:1578:44  */
  assign n6355_o = n6352_o | n6354_o;
  /* T80_MCode.vhd:1578:55  */
  assign n6357_o = ir == 8'b00010010;
  /* T80_MCode.vhd:1578:55  */
  assign n6358_o = n6355_o | n6357_o;
  /* T80_MCode.vhd:1578:66  */
  assign n6360_o = ir == 8'b00010011;
  /* T80_MCode.vhd:1578:66  */
  assign n6361_o = n6358_o | n6360_o;
  /* T80_MCode.vhd:1578:77  */
  assign n6363_o = ir == 8'b00010100;
  /* T80_MCode.vhd:1578:77  */
  assign n6364_o = n6361_o | n6363_o;
  /* T80_MCode.vhd:1578:88  */
  assign n6366_o = ir == 8'b00010101;
  /* T80_MCode.vhd:1578:88  */
  assign n6367_o = n6364_o | n6366_o;
  /* T80_MCode.vhd:1578:99  */
  assign n6369_o = ir == 8'b00010110;
  /* T80_MCode.vhd:1578:99  */
  assign n6370_o = n6367_o | n6369_o;
  /* T80_MCode.vhd:1578:110  */
  assign n6372_o = ir == 8'b00010111;
  /* T80_MCode.vhd:1578:110  */
  assign n6373_o = n6370_o | n6372_o;
  /* T80_MCode.vhd:1579:33  */
  assign n6375_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1579:33  */
  assign n6376_o = n6373_o | n6375_o;
  /* T80_MCode.vhd:1579:44  */
  assign n6378_o = ir == 8'b00011001;
  /* T80_MCode.vhd:1579:44  */
  assign n6379_o = n6376_o | n6378_o;
  /* T80_MCode.vhd:1579:55  */
  assign n6381_o = ir == 8'b00011010;
  /* T80_MCode.vhd:1579:55  */
  assign n6382_o = n6379_o | n6381_o;
  /* T80_MCode.vhd:1579:66  */
  assign n6384_o = ir == 8'b00011011;
  /* T80_MCode.vhd:1579:66  */
  assign n6385_o = n6382_o | n6384_o;
  /* T80_MCode.vhd:1579:77  */
  assign n6387_o = ir == 8'b00011100;
  /* T80_MCode.vhd:1579:77  */
  assign n6388_o = n6385_o | n6387_o;
  /* T80_MCode.vhd:1579:88  */
  assign n6390_o = ir == 8'b00011101;
  /* T80_MCode.vhd:1579:88  */
  assign n6391_o = n6388_o | n6390_o;
  /* T80_MCode.vhd:1579:99  */
  assign n6393_o = ir == 8'b00011110;
  /* T80_MCode.vhd:1579:99  */
  assign n6394_o = n6391_o | n6393_o;
  /* T80_MCode.vhd:1579:110  */
  assign n6396_o = ir == 8'b00011111;
  /* T80_MCode.vhd:1579:110  */
  assign n6397_o = n6394_o | n6396_o;
  /* T80_MCode.vhd:1580:33  */
  assign n6399_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1580:33  */
  assign n6400_o = n6397_o | n6399_o;
  /* T80_MCode.vhd:1580:44  */
  assign n6402_o = ir == 8'b00100001;
  /* T80_MCode.vhd:1580:44  */
  assign n6403_o = n6400_o | n6402_o;
  /* T80_MCode.vhd:1580:55  */
  assign n6405_o = ir == 8'b00100010;
  /* T80_MCode.vhd:1580:55  */
  assign n6406_o = n6403_o | n6405_o;
  /* T80_MCode.vhd:1580:66  */
  assign n6408_o = ir == 8'b00100011;
  /* T80_MCode.vhd:1580:66  */
  assign n6409_o = n6406_o | n6408_o;
  /* T80_MCode.vhd:1580:77  */
  assign n6411_o = ir == 8'b00100100;
  /* T80_MCode.vhd:1580:77  */
  assign n6412_o = n6409_o | n6411_o;
  /* T80_MCode.vhd:1580:88  */
  assign n6414_o = ir == 8'b00100101;
  /* T80_MCode.vhd:1580:88  */
  assign n6415_o = n6412_o | n6414_o;
  /* T80_MCode.vhd:1580:99  */
  assign n6417_o = ir == 8'b00100110;
  /* T80_MCode.vhd:1580:99  */
  assign n6418_o = n6415_o | n6417_o;
  /* T80_MCode.vhd:1580:110  */
  assign n6420_o = ir == 8'b00100111;
  /* T80_MCode.vhd:1580:110  */
  assign n6421_o = n6418_o | n6420_o;
  /* T80_MCode.vhd:1581:33  */
  assign n6423_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1581:33  */
  assign n6424_o = n6421_o | n6423_o;
  /* T80_MCode.vhd:1581:44  */
  assign n6426_o = ir == 8'b00101001;
  /* T80_MCode.vhd:1581:44  */
  assign n6427_o = n6424_o | n6426_o;
  /* T80_MCode.vhd:1581:55  */
  assign n6429_o = ir == 8'b00101010;
  /* T80_MCode.vhd:1581:55  */
  assign n6430_o = n6427_o | n6429_o;
  /* T80_MCode.vhd:1581:66  */
  assign n6432_o = ir == 8'b00101011;
  /* T80_MCode.vhd:1581:66  */
  assign n6433_o = n6430_o | n6432_o;
  /* T80_MCode.vhd:1581:77  */
  assign n6435_o = ir == 8'b00101100;
  /* T80_MCode.vhd:1581:77  */
  assign n6436_o = n6433_o | n6435_o;
  /* T80_MCode.vhd:1581:88  */
  assign n6438_o = ir == 8'b00101101;
  /* T80_MCode.vhd:1581:88  */
  assign n6439_o = n6436_o | n6438_o;
  /* T80_MCode.vhd:1581:99  */
  assign n6441_o = ir == 8'b00101110;
  /* T80_MCode.vhd:1581:99  */
  assign n6442_o = n6439_o | n6441_o;
  /* T80_MCode.vhd:1581:110  */
  assign n6444_o = ir == 8'b00101111;
  /* T80_MCode.vhd:1581:110  */
  assign n6445_o = n6442_o | n6444_o;
  /* T80_MCode.vhd:1582:33  */
  assign n6447_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1582:33  */
  assign n6448_o = n6445_o | n6447_o;
  /* T80_MCode.vhd:1582:44  */
  assign n6450_o = ir == 8'b00110001;
  /* T80_MCode.vhd:1582:44  */
  assign n6451_o = n6448_o | n6450_o;
  /* T80_MCode.vhd:1582:55  */
  assign n6453_o = ir == 8'b00110010;
  /* T80_MCode.vhd:1582:55  */
  assign n6454_o = n6451_o | n6453_o;
  /* T80_MCode.vhd:1582:66  */
  assign n6456_o = ir == 8'b00110011;
  /* T80_MCode.vhd:1582:66  */
  assign n6457_o = n6454_o | n6456_o;
  /* T80_MCode.vhd:1582:77  */
  assign n6459_o = ir == 8'b00110100;
  /* T80_MCode.vhd:1582:77  */
  assign n6460_o = n6457_o | n6459_o;
  /* T80_MCode.vhd:1582:88  */
  assign n6462_o = ir == 8'b00110101;
  /* T80_MCode.vhd:1582:88  */
  assign n6463_o = n6460_o | n6462_o;
  /* T80_MCode.vhd:1582:99  */
  assign n6465_o = ir == 8'b00110110;
  /* T80_MCode.vhd:1582:99  */
  assign n6466_o = n6463_o | n6465_o;
  /* T80_MCode.vhd:1582:110  */
  assign n6468_o = ir == 8'b00110111;
  /* T80_MCode.vhd:1582:110  */
  assign n6469_o = n6466_o | n6468_o;
  /* T80_MCode.vhd:1583:33  */
  assign n6471_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1583:33  */
  assign n6472_o = n6469_o | n6471_o;
  /* T80_MCode.vhd:1583:44  */
  assign n6474_o = ir == 8'b00111001;
  /* T80_MCode.vhd:1583:44  */
  assign n6475_o = n6472_o | n6474_o;
  /* T80_MCode.vhd:1583:55  */
  assign n6477_o = ir == 8'b00111010;
  /* T80_MCode.vhd:1583:55  */
  assign n6478_o = n6475_o | n6477_o;
  /* T80_MCode.vhd:1583:66  */
  assign n6480_o = ir == 8'b00111011;
  /* T80_MCode.vhd:1583:66  */
  assign n6481_o = n6478_o | n6480_o;
  /* T80_MCode.vhd:1583:77  */
  assign n6483_o = ir == 8'b00111100;
  /* T80_MCode.vhd:1583:77  */
  assign n6484_o = n6481_o | n6483_o;
  /* T80_MCode.vhd:1583:88  */
  assign n6486_o = ir == 8'b00111101;
  /* T80_MCode.vhd:1583:88  */
  assign n6487_o = n6484_o | n6486_o;
  /* T80_MCode.vhd:1583:99  */
  assign n6489_o = ir == 8'b00111110;
  /* T80_MCode.vhd:1583:99  */
  assign n6490_o = n6487_o | n6489_o;
  /* T80_MCode.vhd:1583:110  */
  assign n6492_o = ir == 8'b00111111;
  /* T80_MCode.vhd:1583:110  */
  assign n6493_o = n6490_o | n6492_o;
  /* T80_MCode.vhd:1586:33  */
  assign n6495_o = ir == 8'b10000000;
  /* T80_MCode.vhd:1586:33  */
  assign n6496_o = n6493_o | n6495_o;
  /* T80_MCode.vhd:1586:44  */
  assign n6498_o = ir == 8'b10000001;
  /* T80_MCode.vhd:1586:44  */
  assign n6499_o = n6496_o | n6498_o;
  /* T80_MCode.vhd:1586:55  */
  assign n6501_o = ir == 8'b10000010;
  /* T80_MCode.vhd:1586:55  */
  assign n6502_o = n6499_o | n6501_o;
  /* T80_MCode.vhd:1586:66  */
  assign n6504_o = ir == 8'b10000011;
  /* T80_MCode.vhd:1586:66  */
  assign n6505_o = n6502_o | n6504_o;
  /* T80_MCode.vhd:1586:77  */
  assign n6507_o = ir == 8'b10000100;
  /* T80_MCode.vhd:1586:77  */
  assign n6508_o = n6505_o | n6507_o;
  /* T80_MCode.vhd:1586:88  */
  assign n6510_o = ir == 8'b10000101;
  /* T80_MCode.vhd:1586:88  */
  assign n6511_o = n6508_o | n6510_o;
  /* T80_MCode.vhd:1586:99  */
  assign n6513_o = ir == 8'b10000110;
  /* T80_MCode.vhd:1586:99  */
  assign n6514_o = n6511_o | n6513_o;
  /* T80_MCode.vhd:1586:110  */
  assign n6516_o = ir == 8'b10000111;
  /* T80_MCode.vhd:1586:110  */
  assign n6517_o = n6514_o | n6516_o;
  /* T80_MCode.vhd:1587:33  */
  assign n6519_o = ir == 8'b10001000;
  /* T80_MCode.vhd:1587:33  */
  assign n6520_o = n6517_o | n6519_o;
  /* T80_MCode.vhd:1587:44  */
  assign n6522_o = ir == 8'b10001001;
  /* T80_MCode.vhd:1587:44  */
  assign n6523_o = n6520_o | n6522_o;
  /* T80_MCode.vhd:1587:55  */
  assign n6525_o = ir == 8'b10001010;
  /* T80_MCode.vhd:1587:55  */
  assign n6526_o = n6523_o | n6525_o;
  /* T80_MCode.vhd:1587:66  */
  assign n6528_o = ir == 8'b10001011;
  /* T80_MCode.vhd:1587:66  */
  assign n6529_o = n6526_o | n6528_o;
  /* T80_MCode.vhd:1587:77  */
  assign n6531_o = ir == 8'b10001100;
  /* T80_MCode.vhd:1587:77  */
  assign n6532_o = n6529_o | n6531_o;
  /* T80_MCode.vhd:1587:88  */
  assign n6534_o = ir == 8'b10001101;
  /* T80_MCode.vhd:1587:88  */
  assign n6535_o = n6532_o | n6534_o;
  /* T80_MCode.vhd:1587:99  */
  assign n6537_o = ir == 8'b10001110;
  /* T80_MCode.vhd:1587:99  */
  assign n6538_o = n6535_o | n6537_o;
  /* T80_MCode.vhd:1587:110  */
  assign n6540_o = ir == 8'b10001111;
  /* T80_MCode.vhd:1587:110  */
  assign n6541_o = n6538_o | n6540_o;
  /* T80_MCode.vhd:1588:33  */
  assign n6543_o = ir == 8'b10010000;
  /* T80_MCode.vhd:1588:33  */
  assign n6544_o = n6541_o | n6543_o;
  /* T80_MCode.vhd:1588:44  */
  assign n6546_o = ir == 8'b10010001;
  /* T80_MCode.vhd:1588:44  */
  assign n6547_o = n6544_o | n6546_o;
  /* T80_MCode.vhd:1588:55  */
  assign n6549_o = ir == 8'b10010010;
  /* T80_MCode.vhd:1588:55  */
  assign n6550_o = n6547_o | n6549_o;
  /* T80_MCode.vhd:1588:66  */
  assign n6552_o = ir == 8'b10010011;
  /* T80_MCode.vhd:1588:66  */
  assign n6553_o = n6550_o | n6552_o;
  /* T80_MCode.vhd:1588:77  */
  assign n6555_o = ir == 8'b10010100;
  /* T80_MCode.vhd:1588:77  */
  assign n6556_o = n6553_o | n6555_o;
  /* T80_MCode.vhd:1588:88  */
  assign n6558_o = ir == 8'b10010101;
  /* T80_MCode.vhd:1588:88  */
  assign n6559_o = n6556_o | n6558_o;
  /* T80_MCode.vhd:1588:99  */
  assign n6561_o = ir == 8'b10010110;
  /* T80_MCode.vhd:1588:99  */
  assign n6562_o = n6559_o | n6561_o;
  /* T80_MCode.vhd:1588:110  */
  assign n6564_o = ir == 8'b10010111;
  /* T80_MCode.vhd:1588:110  */
  assign n6565_o = n6562_o | n6564_o;
  /* T80_MCode.vhd:1589:33  */
  assign n6567_o = ir == 8'b10011000;
  /* T80_MCode.vhd:1589:33  */
  assign n6568_o = n6565_o | n6567_o;
  /* T80_MCode.vhd:1589:44  */
  assign n6570_o = ir == 8'b10011001;
  /* T80_MCode.vhd:1589:44  */
  assign n6571_o = n6568_o | n6570_o;
  /* T80_MCode.vhd:1589:55  */
  assign n6573_o = ir == 8'b10011010;
  /* T80_MCode.vhd:1589:55  */
  assign n6574_o = n6571_o | n6573_o;
  /* T80_MCode.vhd:1589:66  */
  assign n6576_o = ir == 8'b10011011;
  /* T80_MCode.vhd:1589:66  */
  assign n6577_o = n6574_o | n6576_o;
  /* T80_MCode.vhd:1589:77  */
  assign n6579_o = ir == 8'b10011100;
  /* T80_MCode.vhd:1589:77  */
  assign n6580_o = n6577_o | n6579_o;
  /* T80_MCode.vhd:1589:88  */
  assign n6582_o = ir == 8'b10011101;
  /* T80_MCode.vhd:1589:88  */
  assign n6583_o = n6580_o | n6582_o;
  /* T80_MCode.vhd:1589:99  */
  assign n6585_o = ir == 8'b10011110;
  /* T80_MCode.vhd:1589:99  */
  assign n6586_o = n6583_o | n6585_o;
  /* T80_MCode.vhd:1589:110  */
  assign n6588_o = ir == 8'b10011111;
  /* T80_MCode.vhd:1589:110  */
  assign n6589_o = n6586_o | n6588_o;
  /* T80_MCode.vhd:1590:33  */
  assign n6591_o = ir == 8'b10100100;
  /* T80_MCode.vhd:1590:33  */
  assign n6592_o = n6589_o | n6591_o;
  /* T80_MCode.vhd:1590:88  */
  assign n6594_o = ir == 8'b10100101;
  /* T80_MCode.vhd:1590:88  */
  assign n6595_o = n6592_o | n6594_o;
  /* T80_MCode.vhd:1590:99  */
  assign n6597_o = ir == 8'b10100110;
  /* T80_MCode.vhd:1590:99  */
  assign n6598_o = n6595_o | n6597_o;
  /* T80_MCode.vhd:1590:110  */
  assign n6600_o = ir == 8'b10100111;
  /* T80_MCode.vhd:1590:110  */
  assign n6601_o = n6598_o | n6600_o;
  /* T80_MCode.vhd:1591:33  */
  assign n6603_o = ir == 8'b10101100;
  /* T80_MCode.vhd:1591:33  */
  assign n6604_o = n6601_o | n6603_o;
  /* T80_MCode.vhd:1591:88  */
  assign n6606_o = ir == 8'b10101101;
  /* T80_MCode.vhd:1591:88  */
  assign n6607_o = n6604_o | n6606_o;
  /* T80_MCode.vhd:1591:99  */
  assign n6609_o = ir == 8'b10101110;
  /* T80_MCode.vhd:1591:99  */
  assign n6610_o = n6607_o | n6609_o;
  /* T80_MCode.vhd:1591:110  */
  assign n6612_o = ir == 8'b10101111;
  /* T80_MCode.vhd:1591:110  */
  assign n6613_o = n6610_o | n6612_o;
  /* T80_MCode.vhd:1592:33  */
  assign n6615_o = ir == 8'b10110100;
  /* T80_MCode.vhd:1592:33  */
  assign n6616_o = n6613_o | n6615_o;
  /* T80_MCode.vhd:1592:88  */
  assign n6618_o = ir == 8'b10110101;
  /* T80_MCode.vhd:1592:88  */
  assign n6619_o = n6616_o | n6618_o;
  /* T80_MCode.vhd:1592:99  */
  assign n6621_o = ir == 8'b10110110;
  /* T80_MCode.vhd:1592:99  */
  assign n6622_o = n6619_o | n6621_o;
  /* T80_MCode.vhd:1592:110  */
  assign n6624_o = ir == 8'b10110111;
  /* T80_MCode.vhd:1592:110  */
  assign n6625_o = n6622_o | n6624_o;
  /* T80_MCode.vhd:1593:33  */
  assign n6627_o = ir == 8'b10111100;
  /* T80_MCode.vhd:1593:33  */
  assign n6628_o = n6625_o | n6627_o;
  /* T80_MCode.vhd:1593:88  */
  assign n6630_o = ir == 8'b10111101;
  /* T80_MCode.vhd:1593:88  */
  assign n6631_o = n6628_o | n6630_o;
  /* T80_MCode.vhd:1593:99  */
  assign n6633_o = ir == 8'b10111110;
  /* T80_MCode.vhd:1593:99  */
  assign n6634_o = n6631_o | n6633_o;
  /* T80_MCode.vhd:1593:110  */
  assign n6636_o = ir == 8'b10111111;
  /* T80_MCode.vhd:1593:110  */
  assign n6637_o = n6634_o | n6636_o;
  /* T80_MCode.vhd:1594:33  */
  assign n6639_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1594:33  */
  assign n6640_o = n6637_o | n6639_o;
  /* T80_MCode.vhd:1594:44  */
  assign n6642_o = ir == 8'b11000001;
  /* T80_MCode.vhd:1594:44  */
  assign n6643_o = n6640_o | n6642_o;
  /* T80_MCode.vhd:1594:55  */
  assign n6645_o = ir == 8'b11000010;
  /* T80_MCode.vhd:1594:55  */
  assign n6646_o = n6643_o | n6645_o;
  /* T80_MCode.vhd:1594:66  */
  assign n6648_o = ir == 8'b11000011;
  /* T80_MCode.vhd:1594:66  */
  assign n6649_o = n6646_o | n6648_o;
  /* T80_MCode.vhd:1594:77  */
  assign n6651_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1594:77  */
  assign n6652_o = n6649_o | n6651_o;
  /* T80_MCode.vhd:1594:88  */
  assign n6654_o = ir == 8'b11000101;
  /* T80_MCode.vhd:1594:88  */
  assign n6655_o = n6652_o | n6654_o;
  /* T80_MCode.vhd:1594:99  */
  assign n6657_o = ir == 8'b11000110;
  /* T80_MCode.vhd:1594:99  */
  assign n6658_o = n6655_o | n6657_o;
  /* T80_MCode.vhd:1594:110  */
  assign n6660_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1594:110  */
  assign n6661_o = n6658_o | n6660_o;
  /* T80_MCode.vhd:1595:33  */
  assign n6663_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1595:33  */
  assign n6664_o = n6661_o | n6663_o;
  /* T80_MCode.vhd:1595:44  */
  assign n6666_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1595:44  */
  assign n6667_o = n6664_o | n6666_o;
  /* T80_MCode.vhd:1595:55  */
  assign n6669_o = ir == 8'b11001010;
  /* T80_MCode.vhd:1595:55  */
  assign n6670_o = n6667_o | n6669_o;
  /* T80_MCode.vhd:1595:66  */
  assign n6672_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1595:66  */
  assign n6673_o = n6670_o | n6672_o;
  /* T80_MCode.vhd:1595:77  */
  assign n6675_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1595:77  */
  assign n6676_o = n6673_o | n6675_o;
  /* T80_MCode.vhd:1595:88  */
  assign n6678_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1595:88  */
  assign n6679_o = n6676_o | n6678_o;
  /* T80_MCode.vhd:1595:99  */
  assign n6681_o = ir == 8'b11001110;
  /* T80_MCode.vhd:1595:99  */
  assign n6682_o = n6679_o | n6681_o;
  /* T80_MCode.vhd:1595:110  */
  assign n6684_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1595:110  */
  assign n6685_o = n6682_o | n6684_o;
  /* T80_MCode.vhd:1596:33  */
  assign n6687_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1596:33  */
  assign n6688_o = n6685_o | n6687_o;
  /* T80_MCode.vhd:1596:44  */
  assign n6690_o = ir == 8'b11010001;
  /* T80_MCode.vhd:1596:44  */
  assign n6691_o = n6688_o | n6690_o;
  /* T80_MCode.vhd:1596:55  */
  assign n6693_o = ir == 8'b11010010;
  /* T80_MCode.vhd:1596:55  */
  assign n6694_o = n6691_o | n6693_o;
  /* T80_MCode.vhd:1596:66  */
  assign n6696_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1596:66  */
  assign n6697_o = n6694_o | n6696_o;
  /* T80_MCode.vhd:1596:77  */
  assign n6699_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1596:77  */
  assign n6700_o = n6697_o | n6699_o;
  /* T80_MCode.vhd:1596:88  */
  assign n6702_o = ir == 8'b11010101;
  /* T80_MCode.vhd:1596:88  */
  assign n6703_o = n6700_o | n6702_o;
  /* T80_MCode.vhd:1596:99  */
  assign n6705_o = ir == 8'b11010110;
  /* T80_MCode.vhd:1596:99  */
  assign n6706_o = n6703_o | n6705_o;
  /* T80_MCode.vhd:1596:110  */
  assign n6708_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1596:110  */
  assign n6709_o = n6706_o | n6708_o;
  /* T80_MCode.vhd:1597:33  */
  assign n6711_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1597:33  */
  assign n6712_o = n6709_o | n6711_o;
  /* T80_MCode.vhd:1597:44  */
  assign n6714_o = ir == 8'b11011001;
  /* T80_MCode.vhd:1597:44  */
  assign n6715_o = n6712_o | n6714_o;
  /* T80_MCode.vhd:1597:55  */
  assign n6717_o = ir == 8'b11011010;
  /* T80_MCode.vhd:1597:55  */
  assign n6718_o = n6715_o | n6717_o;
  /* T80_MCode.vhd:1597:66  */
  assign n6720_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1597:66  */
  assign n6721_o = n6718_o | n6720_o;
  /* T80_MCode.vhd:1597:77  */
  assign n6723_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1597:77  */
  assign n6724_o = n6721_o | n6723_o;
  /* T80_MCode.vhd:1597:88  */
  assign n6726_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1597:88  */
  assign n6727_o = n6724_o | n6726_o;
  /* T80_MCode.vhd:1597:99  */
  assign n6729_o = ir == 8'b11011110;
  /* T80_MCode.vhd:1597:99  */
  assign n6730_o = n6727_o | n6729_o;
  /* T80_MCode.vhd:1597:110  */
  assign n6732_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1597:110  */
  assign n6733_o = n6730_o | n6732_o;
  /* T80_MCode.vhd:1598:33  */
  assign n6735_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1598:33  */
  assign n6736_o = n6733_o | n6735_o;
  /* T80_MCode.vhd:1598:44  */
  assign n6738_o = ir == 8'b11100001;
  /* T80_MCode.vhd:1598:44  */
  assign n6739_o = n6736_o | n6738_o;
  /* T80_MCode.vhd:1598:55  */
  assign n6741_o = ir == 8'b11100010;
  /* T80_MCode.vhd:1598:55  */
  assign n6742_o = n6739_o | n6741_o;
  /* T80_MCode.vhd:1598:66  */
  assign n6744_o = ir == 8'b11100011;
  /* T80_MCode.vhd:1598:66  */
  assign n6745_o = n6742_o | n6744_o;
  /* T80_MCode.vhd:1598:77  */
  assign n6747_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1598:77  */
  assign n6748_o = n6745_o | n6747_o;
  /* T80_MCode.vhd:1598:88  */
  assign n6750_o = ir == 8'b11100101;
  /* T80_MCode.vhd:1598:88  */
  assign n6751_o = n6748_o | n6750_o;
  /* T80_MCode.vhd:1598:99  */
  assign n6753_o = ir == 8'b11100110;
  /* T80_MCode.vhd:1598:99  */
  assign n6754_o = n6751_o | n6753_o;
  /* T80_MCode.vhd:1598:110  */
  assign n6756_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1598:110  */
  assign n6757_o = n6754_o | n6756_o;
  /* T80_MCode.vhd:1599:33  */
  assign n6759_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1599:33  */
  assign n6760_o = n6757_o | n6759_o;
  /* T80_MCode.vhd:1599:44  */
  assign n6762_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1599:44  */
  assign n6763_o = n6760_o | n6762_o;
  /* T80_MCode.vhd:1599:55  */
  assign n6765_o = ir == 8'b11101010;
  /* T80_MCode.vhd:1599:55  */
  assign n6766_o = n6763_o | n6765_o;
  /* T80_MCode.vhd:1599:66  */
  assign n6768_o = ir == 8'b11101011;
  /* T80_MCode.vhd:1599:66  */
  assign n6769_o = n6766_o | n6768_o;
  /* T80_MCode.vhd:1599:77  */
  assign n6771_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1599:77  */
  assign n6772_o = n6769_o | n6771_o;
  /* T80_MCode.vhd:1599:88  */
  assign n6774_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1599:88  */
  assign n6775_o = n6772_o | n6774_o;
  /* T80_MCode.vhd:1599:99  */
  assign n6777_o = ir == 8'b11101110;
  /* T80_MCode.vhd:1599:99  */
  assign n6778_o = n6775_o | n6777_o;
  /* T80_MCode.vhd:1599:110  */
  assign n6780_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1599:110  */
  assign n6781_o = n6778_o | n6780_o;
  /* T80_MCode.vhd:1600:33  */
  assign n6783_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1600:33  */
  assign n6784_o = n6781_o | n6783_o;
  /* T80_MCode.vhd:1600:44  */
  assign n6786_o = ir == 8'b11110001;
  /* T80_MCode.vhd:1600:44  */
  assign n6787_o = n6784_o | n6786_o;
  /* T80_MCode.vhd:1600:55  */
  assign n6789_o = ir == 8'b11110010;
  /* T80_MCode.vhd:1600:55  */
  assign n6790_o = n6787_o | n6789_o;
  /* T80_MCode.vhd:1600:66  */
  assign n6792_o = ir == 8'b11110011;
  /* T80_MCode.vhd:1600:66  */
  assign n6793_o = n6790_o | n6792_o;
  /* T80_MCode.vhd:1600:77  */
  assign n6795_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1600:77  */
  assign n6796_o = n6793_o | n6795_o;
  /* T80_MCode.vhd:1600:88  */
  assign n6798_o = ir == 8'b11110101;
  /* T80_MCode.vhd:1600:88  */
  assign n6799_o = n6796_o | n6798_o;
  /* T80_MCode.vhd:1600:99  */
  assign n6801_o = ir == 8'b11110110;
  /* T80_MCode.vhd:1600:99  */
  assign n6802_o = n6799_o | n6801_o;
  /* T80_MCode.vhd:1600:110  */
  assign n6804_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1600:110  */
  assign n6805_o = n6802_o | n6804_o;
  /* T80_MCode.vhd:1601:33  */
  assign n6807_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1601:33  */
  assign n6808_o = n6805_o | n6807_o;
  /* T80_MCode.vhd:1601:44  */
  assign n6810_o = ir == 8'b11111001;
  /* T80_MCode.vhd:1601:44  */
  assign n6811_o = n6808_o | n6810_o;
  /* T80_MCode.vhd:1601:55  */
  assign n6813_o = ir == 8'b11111010;
  /* T80_MCode.vhd:1601:55  */
  assign n6814_o = n6811_o | n6813_o;
  /* T80_MCode.vhd:1601:66  */
  assign n6816_o = ir == 8'b11111011;
  /* T80_MCode.vhd:1601:66  */
  assign n6817_o = n6814_o | n6816_o;
  /* T80_MCode.vhd:1601:77  */
  assign n6819_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1601:77  */
  assign n6820_o = n6817_o | n6819_o;
  /* T80_MCode.vhd:1601:88  */
  assign n6822_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1601:88  */
  assign n6823_o = n6820_o | n6822_o;
  /* T80_MCode.vhd:1601:99  */
  assign n6825_o = ir == 8'b11111110;
  /* T80_MCode.vhd:1601:99  */
  assign n6826_o = n6823_o | n6825_o;
  /* T80_MCode.vhd:1601:110  */
  assign n6828_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1601:110  */
  assign n6829_o = n6826_o | n6828_o;
  /* T80_MCode.vhd:1603:25  */
  assign n6831_o = ir == 8'b01111110;
  /* T80_MCode.vhd:1603:40  */
  assign n6833_o = ir == 8'b01111111;
  /* T80_MCode.vhd:1603:40  */
  assign n6834_o = n6831_o | n6833_o;
  /* T80_MCode.vhd:1607:25  */
  assign n6836_o = ir == 8'b01010111;
  /* T80_MCode.vhd:1611:25  */
  assign n6838_o = ir == 8'b01011111;
  /* T80_MCode.vhd:1615:25  */
  assign n6840_o = ir == 8'b01000111;
  /* T80_MCode.vhd:1619:25  */
  assign n6842_o = ir == 8'b01001111;
  /* T80_MCode.vhd:1627:38  */
  assign n6843_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1628:33  */
  assign n6845_o = n6843_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1631:33  */
  assign n6847_o = n6843_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1637:46  */
  assign n6848_o = ir[5:4];
  /* T80_MCode.vhd:1637:59  */
  assign n6850_o = n6848_o == 2'b11;
  /* T80_MCode.vhd:1640:78  */
  assign n6851_o = ir[5:4];
  assign n6853_o = {n6851_o, 1'b1};
  /* T80_MCode.vhd:1637:41  */
  assign n6855_o = n6850_o ? 3'b000 : n6853_o;
  /* T80_MCode.vhd:1637:41  */
  assign n6858_o = n6850_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1635:33  */
  assign n6860_o = n6843_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1647:46  */
  assign n6861_o = ir[5:4];
  /* T80_MCode.vhd:1647:59  */
  assign n6863_o = n6861_o == 2'b11;
  /* T80_MCode.vhd:1650:78  */
  assign n6864_o = ir[5:4];
  assign n6866_o = {n6864_o, 1'b0};
  /* T80_MCode.vhd:1647:41  */
  assign n6868_o = n6863_o ? 3'b001 : n6866_o;
  /* T80_MCode.vhd:1647:41  */
  assign n6871_o = n6863_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1645:33  */
  assign n6873_o = n6843_o == 31'b0000000000000000000000000000101;
  assign n6874_o = {n6873_o, n6860_o, n6847_o, n6845_o};
  /* T80_MCode.vhd:1627:33  */
  always @*
    case (n6874_o)
      4'b1000: n6878_o = 1'b0;
      4'b0100: n6878_o = 1'b0;
      4'b0010: n6878_o = 1'b1;
      4'b0001: n6878_o = 1'b1;
      default: n6878_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1627:33  */
  always @*
    case (n6874_o)
      4'b1000: n6881_o = 1'b0;
      4'b0100: n6881_o = 1'b1;
      4'b0010: n6881_o = 1'b0;
      4'b0001: n6881_o = 1'b0;
      default: n6881_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1627:33  */
  always @*
    case (n6874_o)
      4'b1000: n6885_o = 1'b1;
      4'b0100: n6885_o = 1'b1;
      4'b0010: n6885_o = 1'b0;
      4'b0001: n6885_o = 1'b0;
      default: n6885_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1627:33  */
  always @*
    case (n6874_o)
      4'b1000: n6887_o = n6868_o;
      4'b0100: n6887_o = n6855_o;
      4'b0010: n6887_o = 3'b000;
      4'b0001: n6887_o = 3'b000;
      default: n6887_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1627:33  */
  always @*
    case (n6874_o)
      4'b1000: n6889_o = n6871_o;
      4'b0100: n6889_o = n6858_o;
      4'b0010: n6889_o = 1'b0;
      4'b0001: n6889_o = 1'b0;
      default: n6889_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1627:33  */
  always @*
    case (n6874_o)
      4'b1000: n6893_o = 3'b111;
      4'b0100: n6893_o = 3'b110;
      4'b0010: n6893_o = 3'b110;
      4'b0001: n6893_o = 3'b111;
      default: n6893_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1627:33  */
  always @*
    case (n6874_o)
      4'b1000: n6896_o = 1'b0;
      4'b0100: n6896_o = 1'b0;
      4'b0010: n6896_o = 1'b0;
      4'b0001: n6896_o = 1'b1;
      default: n6896_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1627:33  */
  always @*
    case (n6874_o)
      4'b1000: n6899_o = 1'b0;
      4'b0100: n6899_o = 1'b0;
      4'b0010: n6899_o = 1'b1;
      4'b0001: n6899_o = 1'b0;
      default: n6899_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1624:25  */
  assign n6901_o = ir == 8'b01001011;
  /* T80_MCode.vhd:1624:40  */
  assign n6903_o = ir == 8'b01011011;
  /* T80_MCode.vhd:1624:40  */
  assign n6904_o = n6901_o | n6903_o;
  /* T80_MCode.vhd:1624:51  */
  assign n6906_o = ir == 8'b01101011;
  /* T80_MCode.vhd:1624:51  */
  assign n6907_o = n6904_o | n6906_o;
  /* T80_MCode.vhd:1624:62  */
  assign n6909_o = ir == 8'b01111011;
  /* T80_MCode.vhd:1624:62  */
  assign n6910_o = n6907_o | n6909_o;
  /* T80_MCode.vhd:1658:38  */
  assign n6911_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1659:33  */
  assign n6913_o = n6911_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1666:46  */
  assign n6914_o = ir[5:4];
  /* T80_MCode.vhd:1666:59  */
  assign n6916_o = n6914_o == 2'b11;
  /* T80_MCode.vhd:1669:78  */
  assign n6917_o = ir[5:4];
  assign n6920_o = {1'b0, n6917_o, 1'b1};
  /* T80_MCode.vhd:1666:41  */
  assign n6922_o = n6916_o ? 4'b1000 : n6920_o;
  /* T80_MCode.vhd:1662:33  */
  assign n6924_o = n6911_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1677:46  */
  assign n6925_o = ir[5:4];
  /* T80_MCode.vhd:1677:59  */
  assign n6927_o = n6925_o == 2'b11;
  /* T80_MCode.vhd:1680:78  */
  assign n6928_o = ir[5:4];
  assign n6931_o = {1'b0, n6928_o, 1'b0};
  /* T80_MCode.vhd:1677:41  */
  assign n6933_o = n6927_o ? 4'b1001 : n6931_o;
  /* T80_MCode.vhd:1673:33  */
  assign n6935_o = n6911_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1684:33  */
  assign n6937_o = n6911_o == 31'b0000000000000000000000000000101;
  assign n6938_o = {n6937_o, n6935_o, n6924_o, n6913_o};
  /* T80_MCode.vhd:1658:33  */
  always @*
    case (n6938_o)
      4'b1000: n6942_o = 1'b0;
      4'b0100: n6942_o = 1'b0;
      4'b0010: n6942_o = 1'b1;
      4'b0001: n6942_o = 1'b1;
      default: n6942_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1658:33  */
  always @*
    case (n6938_o)
      4'b1000: n6945_o = 1'b0;
      4'b0100: n6945_o = 1'b1;
      4'b0010: n6945_o = 1'b0;
      4'b0001: n6945_o = 1'b0;
      default: n6945_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1658:33  */
  always @*
    case (n6938_o)
      4'b1000: n6947_o = 4'b0000;
      4'b0100: n6947_o = n6933_o;
      4'b0010: n6947_o = n6922_o;
      4'b0001: n6947_o = 4'b0000;
      default: n6947_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1658:33  */
  always @*
    case (n6938_o)
      4'b1000: n6951_o = 3'b111;
      4'b0100: n6951_o = 3'b110;
      4'b0010: n6951_o = 3'b110;
      4'b0001: n6951_o = 3'b111;
      default: n6951_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1658:33  */
  always @*
    case (n6938_o)
      4'b1000: n6954_o = 1'b0;
      4'b0100: n6954_o = 1'b0;
      4'b0010: n6954_o = 1'b0;
      4'b0001: n6954_o = 1'b1;
      default: n6954_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1658:33  */
  always @*
    case (n6938_o)
      4'b1000: n6957_o = 1'b0;
      4'b0100: n6957_o = 1'b0;
      4'b0010: n6957_o = 1'b1;
      4'b0001: n6957_o = 1'b0;
      default: n6957_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1658:33  */
  always @*
    case (n6938_o)
      4'b1000: n6961_o = 1'b1;
      4'b0100: n6961_o = 1'b1;
      4'b0010: n6961_o = 1'b0;
      4'b0001: n6961_o = 1'b0;
      default: n6961_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1655:25  */
  assign n6963_o = ir == 8'b01000011;
  /* T80_MCode.vhd:1655:40  */
  assign n6965_o = ir == 8'b01010011;
  /* T80_MCode.vhd:1655:40  */
  assign n6966_o = n6963_o | n6965_o;
  /* T80_MCode.vhd:1655:51  */
  assign n6968_o = ir == 8'b01100011;
  /* T80_MCode.vhd:1655:51  */
  assign n6969_o = n6966_o | n6968_o;
  /* T80_MCode.vhd:1655:62  */
  assign n6971_o = ir == 8'b01110011;
  /* T80_MCode.vhd:1655:62  */
  assign n6972_o = n6969_o | n6971_o;
  /* T80_MCode.vhd:1691:38  */
  assign n6973_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1692:33  */
  assign n6975_o = n6973_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1700:46  */
  assign n6977_o = ir[3];
  /* T80_MCode.vhd:1700:50  */
  assign n6978_o = ~n6977_o;
  /* T80_MCode.vhd:1700:41  */
  assign n6981_o = n6978_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1695:33  */
  assign n6983_o = n6973_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1709:46  */
  assign n6984_o = ir[3];
  /* T80_MCode.vhd:1709:50  */
  assign n6985_o = ~n6984_o;
  /* T80_MCode.vhd:1709:41  */
  assign n6988_o = n6985_o ? 4'b0101 : 4'b1101;
  /* T80_MCode.vhd:1705:33  */
  assign n6990_o = n6973_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1714:33  */
  assign n6992_o = n6973_o == 31'b0000000000000000000000000000100;
  assign n6993_o = {n6992_o, n6990_o, n6983_o, n6975_o};
  /* T80_MCode.vhd:1691:33  */
  always @*
    case (n6993_o)
      4'b1000: n6996_o = 3'b101;
      4'b0100: n6996_o = 3'b101;
      4'b0010: n6996_o = n2122_o;
      4'b0001: n6996_o = n2122_o;
      default: n6996_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1691:33  */
  always @*
    case (n6993_o)
      4'b1000: n6999_o = 4'b0000;
      4'b0100: n6999_o = n6988_o;
      4'b0010: n6999_o = n6981_o;
      4'b0001: n6999_o = 4'b1100;
      default: n6999_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1691:33  */
  always @*
    case (n6993_o)
      4'b1000: n7001_o = 3'b000;
      4'b0100: n7001_o = 3'b000;
      4'b0010: n7001_o = 3'b111;
      4'b0001: n7001_o = 3'b000;
      default: n7001_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1691:33  */
  always @*
    case (n6993_o)
      4'b1000: n7004_o = 4'b0000;
      4'b0100: n7004_o = 4'b0000;
      4'b0010: n7004_o = 4'b0110;
      4'b0001: n7004_o = 4'b0000;
      default: n7004_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1691:33  */
  always @*
    case (n6993_o)
      4'b1000: n7006_o = n2125_o;
      4'b0100: n7006_o = n2125_o;
      4'b0010: n7006_o = 4'b0000;
      4'b0001: n7006_o = n2125_o;
      default: n7006_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1691:33  */
  always @*
    case (n6993_o)
      4'b1000: n7010_o = 3'b111;
      4'b0100: n7010_o = 3'b111;
      4'b0010: n7010_o = 3'b001;
      4'b0001: n7010_o = 3'b010;
      default: n7010_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1691:33  */
  always @*
    case (n6993_o)
      4'b1000: n7013_o = 1'b0;
      4'b0100: n7013_o = 1'b1;
      4'b0010: n7013_o = 1'b0;
      4'b0001: n7013_o = 1'b0;
      default: n7013_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1691:33  */
  always @*
    case (n6993_o)
      4'b1000: n7016_o = 1'b1;
      4'b0100: n7016_o = 1'b0;
      4'b0010: n7016_o = 1'b0;
      4'b0001: n7016_o = 1'b0;
      default: n7016_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1691:33  */
  always @*
    case (n6993_o)
      4'b1000: n7019_o = 1'b0;
      4'b0100: n7019_o = 1'b1;
      4'b0010: n7019_o = 1'b0;
      4'b0001: n7019_o = 1'b0;
      default: n7019_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1688:25  */
  assign n7021_o = ir == 8'b10100000;
  /* T80_MCode.vhd:1688:41  */
  assign n7023_o = ir == 8'b10101000;
  /* T80_MCode.vhd:1688:41  */
  assign n7024_o = n7021_o | n7023_o;
  /* T80_MCode.vhd:1688:54  */
  assign n7026_o = ir == 8'b10110000;
  /* T80_MCode.vhd:1688:54  */
  assign n7027_o = n7024_o | n7026_o;
  /* T80_MCode.vhd:1688:67  */
  assign n7029_o = ir == 8'b10111000;
  /* T80_MCode.vhd:1688:67  */
  assign n7030_o = n7027_o | n7029_o;
  /* T80_MCode.vhd:1722:38  */
  assign n7031_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1723:33  */
  assign n7033_o = n7031_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1732:46  */
  assign n7035_o = ir[3];
  /* T80_MCode.vhd:1732:50  */
  assign n7036_o = ~n7035_o;
  /* T80_MCode.vhd:1732:41  */
  assign n7039_o = n7036_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1726:33  */
  assign n7041_o = n7031_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1737:33  */
  assign n7043_o = n7031_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1741:33  */
  assign n7045_o = n7031_o == 31'b0000000000000000000000000000100;
  assign n7046_o = {n7045_o, n7043_o, n7041_o, n7033_o};
  /* T80_MCode.vhd:1722:33  */
  always @*
    case (n7046_o)
      4'b1000: n7049_o = 3'b101;
      4'b0100: n7049_o = 3'b101;
      4'b0010: n7049_o = n2122_o;
      4'b0001: n7049_o = n2122_o;
      default: n7049_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1722:33  */
  always @*
    case (n7046_o)
      4'b1000: n7052_o = 4'b0000;
      4'b0100: n7052_o = 4'b0000;
      4'b0010: n7052_o = n7039_o;
      4'b0001: n7052_o = 4'b1100;
      default: n7052_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1722:33  */
  always @*
    case (n7046_o)
      4'b1000: n7054_o = 3'b000;
      4'b0100: n7054_o = 3'b000;
      4'b0010: n7054_o = 3'b111;
      4'b0001: n7054_o = 3'b000;
      default: n7054_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1722:33  */
  always @*
    case (n7046_o)
      4'b1000: n7057_o = 4'b0000;
      4'b0100: n7057_o = 4'b0000;
      4'b0010: n7057_o = 4'b0110;
      4'b0001: n7057_o = 4'b0000;
      default: n7057_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1722:33  */
  always @*
    case (n7046_o)
      4'b1000: n7059_o = n2125_o;
      4'b0100: n7059_o = n2125_o;
      4'b0010: n7059_o = 4'b0111;
      4'b0001: n7059_o = n2125_o;
      default: n7059_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1722:33  */
  always @*
    case (n7046_o)
      4'b1000: n7062_o = 1'b0;
      4'b0100: n7062_o = 1'b0;
      4'b0010: n7062_o = 1'b1;
      4'b0001: n7062_o = 1'b0;
      default: n7062_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1722:33  */
  always @*
    case (n7046_o)
      4'b1000: n7065_o = 1'b0;
      4'b0100: n7065_o = 1'b0;
      4'b0010: n7065_o = 1'b1;
      4'b0001: n7065_o = 1'b0;
      default: n7065_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1722:33  */
  always @*
    case (n7046_o)
      4'b1000: n7068_o = 3'b111;
      4'b0100: n7068_o = 3'b111;
      4'b0010: n7068_o = 3'b111;
      4'b0001: n7068_o = 3'b010;
      default: n7068_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1722:33  */
  always @*
    case (n7046_o)
      4'b1000: n7071_o = 1'b0;
      4'b0100: n7071_o = 1'b1;
      4'b0010: n7071_o = 1'b0;
      4'b0001: n7071_o = 1'b0;
      default: n7071_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1722:33  */
  always @*
    case (n7046_o)
      4'b1000: n7075_o = 1'b1;
      4'b0100: n7075_o = 1'b1;
      4'b0010: n7075_o = 1'b0;
      4'b0001: n7075_o = 1'b0;
      default: n7075_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1719:25  */
  assign n7077_o = ir == 8'b10100001;
  /* T80_MCode.vhd:1719:41  */
  assign n7079_o = ir == 8'b10101001;
  /* T80_MCode.vhd:1719:41  */
  assign n7080_o = n7077_o | n7079_o;
  /* T80_MCode.vhd:1719:54  */
  assign n7082_o = ir == 8'b10110001;
  /* T80_MCode.vhd:1719:54  */
  assign n7083_o = n7080_o | n7082_o;
  /* T80_MCode.vhd:1719:67  */
  assign n7085_o = ir == 8'b10111001;
  /* T80_MCode.vhd:1719:67  */
  assign n7086_o = n7083_o | n7085_o;
  /* T80_MCode.vhd:1746:25  */
  assign n7088_o = ir == 8'b01000100;
  /* T80_MCode.vhd:1746:40  */
  assign n7090_o = ir == 8'b01001100;
  /* T80_MCode.vhd:1746:40  */
  assign n7091_o = n7088_o | n7090_o;
  /* T80_MCode.vhd:1746:51  */
  assign n7093_o = ir == 8'b01010100;
  /* T80_MCode.vhd:1746:51  */
  assign n7094_o = n7091_o | n7093_o;
  /* T80_MCode.vhd:1746:62  */
  assign n7096_o = ir == 8'b01011100;
  /* T80_MCode.vhd:1746:62  */
  assign n7097_o = n7094_o | n7096_o;
  /* T80_MCode.vhd:1746:73  */
  assign n7099_o = ir == 8'b01100100;
  /* T80_MCode.vhd:1746:73  */
  assign n7100_o = n7097_o | n7099_o;
  /* T80_MCode.vhd:1746:84  */
  assign n7102_o = ir == 8'b01101100;
  /* T80_MCode.vhd:1746:84  */
  assign n7103_o = n7100_o | n7102_o;
  /* T80_MCode.vhd:1746:95  */
  assign n7105_o = ir == 8'b01110100;
  /* T80_MCode.vhd:1746:95  */
  assign n7106_o = n7103_o | n7105_o;
  /* T80_MCode.vhd:1746:106  */
  assign n7108_o = ir == 8'b01111100;
  /* T80_MCode.vhd:1746:106  */
  assign n7109_o = n7106_o | n7108_o;
  /* T80_MCode.vhd:1753:25  */
  assign n7111_o = ir == 8'b01000110;
  /* T80_MCode.vhd:1753:40  */
  assign n7113_o = ir == 8'b01001110;
  /* T80_MCode.vhd:1753:40  */
  assign n7114_o = n7111_o | n7113_o;
  /* T80_MCode.vhd:1753:51  */
  assign n7116_o = ir == 8'b01100110;
  /* T80_MCode.vhd:1753:51  */
  assign n7117_o = n7114_o | n7116_o;
  /* T80_MCode.vhd:1753:62  */
  assign n7119_o = ir == 8'b01101110;
  /* T80_MCode.vhd:1753:62  */
  assign n7120_o = n7117_o | n7119_o;
  /* T80_MCode.vhd:1756:25  */
  assign n7122_o = ir == 8'b01010110;
  /* T80_MCode.vhd:1756:40  */
  assign n7124_o = ir == 8'b01110110;
  /* T80_MCode.vhd:1756:40  */
  assign n7125_o = n7122_o | n7124_o;
  /* T80_MCode.vhd:1759:25  */
  assign n7127_o = ir == 8'b01011110;
  /* T80_MCode.vhd:1759:40  */
  assign n7129_o = ir == 8'b01110111;
  /* T80_MCode.vhd:1759:40  */
  assign n7130_o = n7127_o | n7129_o;
  /* T80_MCode.vhd:1766:38  */
  assign n7131_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1773:68  */
  assign n7133_o = ir[5:4];
  /* T80_MCode.vhd:1773:46  */
  assign n7134_o = {29'b0, n7133_o};  //  uext
  /* T80_MCode.vhd:1775:78  */
  assign n7135_o = ir[5:4];
  /* T80_MCode.vhd:1774:41  */
  assign n7138_o = n7134_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1774:47  */
  assign n7140_o = n7134_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1774:47  */
  assign n7141_o = n7138_o | n7140_o;
  /* T80_MCode.vhd:1774:49  */
  assign n7143_o = n7134_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1774:49  */
  assign n7144_o = n7141_o | n7143_o;
  /* T80_MCode.vhd:1773:41  */
  always @*
    case (n7144_o)
      1'b1: n7146_o = 1'b1;
      default: n7146_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1773:41  */
  always @*
    case (n7144_o)
      1'b1: n7148_o = n7135_o;
      default: n7148_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1773:41  */
  always @*
    case (n7144_o)
      1'b1: n7151_o = 1'b0;
      default: n7151_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1767:33  */
  assign n7153_o = n7131_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1788:68  */
  assign n7155_o = ir[5:4];
  /* T80_MCode.vhd:1788:46  */
  assign n7156_o = {29'b0, n7155_o};  //  uext
  /* T80_MCode.vhd:1790:78  */
  assign n7157_o = ir[5:4];
  /* T80_MCode.vhd:1789:41  */
  assign n7160_o = n7156_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1789:47  */
  assign n7162_o = n7156_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1789:47  */
  assign n7163_o = n7160_o | n7162_o;
  /* T80_MCode.vhd:1789:49  */
  assign n7165_o = n7156_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1789:49  */
  assign n7166_o = n7163_o | n7165_o;
  /* T80_MCode.vhd:1788:41  */
  always @*
    case (n7166_o)
      1'b1: n7168_o = 1'b0;
      default: n7168_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1788:41  */
  always @*
    case (n7166_o)
      1'b1: n7170_o = n7157_o;
      default: n7170_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1788:41  */
  always @*
    case (n7166_o)
      1'b1: n7173_o = 1'b0;
      default: n7173_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1782:33  */
  assign n7175_o = n7131_o == 31'b0000000000000000000000000000011;
  assign n7176_o = {n7175_o, n7153_o};
  /* T80_MCode.vhd:1766:33  */
  always @*
    case (n7176_o)
      2'b10: n7178_o = n2122_o;
      2'b01: n7178_o = 3'b100;
      default: n7178_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1766:33  */
  always @*
    case (n7176_o)
      2'b10: n7182_o = 1'b1;
      2'b01: n7182_o = 1'b1;
      default: n7182_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1766:33  */
  always @*
    case (n7176_o)
      2'b10: n7184_o = 3'b100;
      2'b01: n7184_o = 3'b101;
      default: n7184_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1766:33  */
  always @*
    case (n7176_o)
      2'b10: n7186_o = n7168_o;
      2'b01: n7186_o = n7146_o;
      default: n7186_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1766:33  */
  always @*
    case (n7176_o)
      2'b10: n7188_o = n7170_o;
      2'b01: n7188_o = n7148_o;
      default: n7188_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1766:33  */
  always @*
    case (n7176_o)
      2'b10: n7190_o = n7173_o;
      2'b01: n7190_o = n7151_o;
      default: n7190_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1766:33  */
  always @*
    case (n7176_o)
      2'b10: n7193_o = 4'b0001;
      2'b01: n7193_o = 4'b0001;
      default: n7193_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1766:33  */
  always @*
    case (n7176_o)
      2'b10: n7197_o = 1'b1;
      2'b01: n7197_o = 1'b1;
      default: n7197_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1766:33  */
  always @*
    case (n7176_o)
      2'b10: n7200_o = 2'b00;
      2'b01: n7200_o = 2'b11;
      default: n7200_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1766:33  */
  always @*
    case (n7176_o)
      2'b10: n7204_o = 1'b1;
      2'b01: n7204_o = 1'b1;
      default: n7204_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1763:25  */
  assign n7206_o = ir == 8'b01001010;
  /* T80_MCode.vhd:1763:40  */
  assign n7208_o = ir == 8'b01011010;
  /* T80_MCode.vhd:1763:40  */
  assign n7209_o = n7206_o | n7208_o;
  /* T80_MCode.vhd:1763:51  */
  assign n7211_o = ir == 8'b01101010;
  /* T80_MCode.vhd:1763:51  */
  assign n7212_o = n7209_o | n7211_o;
  /* T80_MCode.vhd:1763:62  */
  assign n7214_o = ir == 8'b01111010;
  /* T80_MCode.vhd:1763:62  */
  assign n7215_o = n7212_o | n7214_o;
  /* T80_MCode.vhd:1800:38  */
  assign n7216_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1807:68  */
  assign n7218_o = ir[5:4];
  /* T80_MCode.vhd:1807:46  */
  assign n7219_o = {29'b0, n7218_o};  //  uext
  /* T80_MCode.vhd:1809:78  */
  assign n7220_o = ir[5:4];
  /* T80_MCode.vhd:1808:41  */
  assign n7223_o = n7219_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1808:47  */
  assign n7225_o = n7219_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1808:47  */
  assign n7226_o = n7223_o | n7225_o;
  /* T80_MCode.vhd:1808:49  */
  assign n7228_o = n7219_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1808:49  */
  assign n7229_o = n7226_o | n7228_o;
  /* T80_MCode.vhd:1807:41  */
  always @*
    case (n7229_o)
      1'b1: n7231_o = 1'b1;
      default: n7231_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1807:41  */
  always @*
    case (n7229_o)
      1'b1: n7233_o = n7220_o;
      default: n7233_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1807:41  */
  always @*
    case (n7229_o)
      1'b1: n7236_o = 1'b0;
      default: n7236_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1801:33  */
  assign n7238_o = n7216_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1822:68  */
  assign n7240_o = ir[5:4];
  /* T80_MCode.vhd:1822:46  */
  assign n7241_o = {29'b0, n7240_o};  //  uext
  /* T80_MCode.vhd:1824:78  */
  assign n7242_o = ir[5:4];
  /* T80_MCode.vhd:1823:41  */
  assign n7244_o = n7241_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1823:47  */
  assign n7246_o = n7241_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1823:47  */
  assign n7247_o = n7244_o | n7246_o;
  /* T80_MCode.vhd:1823:49  */
  assign n7249_o = n7241_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1823:49  */
  assign n7250_o = n7247_o | n7249_o;
  /* T80_MCode.vhd:1822:41  */
  always @*
    case (n7250_o)
      1'b1: n7253_o = 1'b0;
      default: n7253_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1822:41  */
  always @*
    case (n7250_o)
      1'b1: n7255_o = n7242_o;
      default: n7255_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1822:41  */
  always @*
    case (n7250_o)
      1'b1: n7258_o = 1'b0;
      default: n7258_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1816:33  */
  assign n7260_o = n7216_o == 31'b0000000000000000000000000000011;
  assign n7261_o = {n7260_o, n7238_o};
  /* T80_MCode.vhd:1800:33  */
  always @*
    case (n7261_o)
      2'b10: n7263_o = n2122_o;
      2'b01: n7263_o = 3'b100;
      default: n7263_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1800:33  */
  always @*
    case (n7261_o)
      2'b10: n7267_o = 1'b1;
      2'b01: n7267_o = 1'b1;
      default: n7267_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1800:33  */
  always @*
    case (n7261_o)
      2'b10: n7269_o = 3'b100;
      2'b01: n7269_o = 3'b101;
      default: n7269_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1800:33  */
  always @*
    case (n7261_o)
      2'b10: n7271_o = n7253_o;
      2'b01: n7271_o = n7231_o;
      default: n7271_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1800:33  */
  always @*
    case (n7261_o)
      2'b10: n7273_o = n7255_o;
      2'b01: n7273_o = n7233_o;
      default: n7273_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1800:33  */
  always @*
    case (n7261_o)
      2'b10: n7275_o = n7258_o;
      2'b01: n7275_o = n7236_o;
      default: n7275_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1800:33  */
  always @*
    case (n7261_o)
      2'b10: n7278_o = 4'b0011;
      2'b01: n7278_o = 4'b0011;
      default: n7278_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1800:33  */
  always @*
    case (n7261_o)
      2'b10: n7282_o = 1'b1;
      2'b01: n7282_o = 1'b1;
      default: n7282_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1800:33  */
  always @*
    case (n7261_o)
      2'b10: n7285_o = 2'b00;
      2'b01: n7285_o = 2'b11;
      default: n7285_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1800:33  */
  always @*
    case (n7261_o)
      2'b10: n7289_o = 1'b1;
      2'b01: n7289_o = 1'b1;
      default: n7289_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1797:25  */
  assign n7291_o = ir == 8'b01000010;
  /* T80_MCode.vhd:1797:40  */
  assign n7293_o = ir == 8'b01010010;
  /* T80_MCode.vhd:1797:40  */
  assign n7294_o = n7291_o | n7293_o;
  /* T80_MCode.vhd:1797:51  */
  assign n7296_o = ir == 8'b01100010;
  /* T80_MCode.vhd:1797:51  */
  assign n7297_o = n7294_o | n7296_o;
  /* T80_MCode.vhd:1797:62  */
  assign n7299_o = ir == 8'b01110010;
  /* T80_MCode.vhd:1797:62  */
  assign n7300_o = n7297_o | n7299_o;
  /* T80_MCode.vhd:1833:38  */
  assign n7301_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1834:33  */
  assign n7303_o = n7301_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1836:33  */
  assign n7307_o = n7301_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1842:33  */
  assign n7309_o = n7301_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1847:33  */
  assign n7311_o = n7301_o == 31'b0000000000000000000000000000100;
  assign n7312_o = {n7311_o, n7309_o, n7307_o, n7303_o};
  /* T80_MCode.vhd:1833:33  */
  always @*
    case (n7312_o)
      4'b1000: n7314_o = n2122_o;
      4'b0100: n7314_o = 3'b100;
      4'b0010: n7314_o = n2122_o;
      4'b0001: n7314_o = n2122_o;
      default: n7314_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1833:33  */
  always @*
    case (n7312_o)
      4'b1000: n7317_o = 1'b0;
      4'b0100: n7317_o = 1'b0;
      4'b0010: n7317_o = 1'b1;
      4'b0001: n7317_o = 1'b0;
      default: n7317_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1833:33  */
  always @*
    case (n7312_o)
      4'b1000: n7319_o = 3'b000;
      4'b0100: n7319_o = 3'b000;
      4'b0010: n7319_o = 3'b111;
      4'b0001: n7319_o = 3'b000;
      default: n7319_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1833:33  */
  always @*
    case (n7312_o)
      4'b1000: n7321_o = 3'b000;
      4'b0100: n7321_o = 3'b000;
      4'b0010: n7321_o = 3'b110;
      4'b0001: n7321_o = 3'b000;
      default: n7321_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1833:33  */
  always @*
    case (n7312_o)
      4'b1000: n7323_o = n2125_o;
      4'b0100: n7323_o = n2125_o;
      4'b0010: n7323_o = 4'b1101;
      4'b0001: n7323_o = n2125_o;
      default: n7323_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1833:33  */
  always @*
    case (n7312_o)
      4'b1000: n7326_o = 1'b0;
      4'b0100: n7326_o = 1'b0;
      4'b0010: n7326_o = 1'b1;
      4'b0001: n7326_o = 1'b0;
      default: n7326_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1833:33  */
  always @*
    case (n7312_o)
      4'b1000: n7330_o = 3'b111;
      4'b0100: n7330_o = 3'b010;
      4'b0010: n7330_o = 3'b111;
      4'b0001: n7330_o = 3'b010;
      default: n7330_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1833:33  */
  always @*
    case (n7312_o)
      4'b1000: n7333_o = 1'b0;
      4'b0100: n7333_o = 1'b1;
      4'b0010: n7333_o = 1'b0;
      4'b0001: n7333_o = 1'b0;
      default: n7333_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1833:33  */
  always @*
    case (n7312_o)
      4'b1000: n7336_o = 1'b0;
      4'b0100: n7336_o = 1'b1;
      4'b0010: n7336_o = 1'b0;
      4'b0001: n7336_o = 1'b0;
      default: n7336_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1833:33  */
  always @*
    case (n7312_o)
      4'b1000: n7339_o = 1'b1;
      4'b0100: n7339_o = 1'b0;
      4'b0010: n7339_o = 1'b0;
      4'b0001: n7339_o = 1'b0;
      default: n7339_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1830:25  */
  assign n7341_o = ir == 8'b01101111;
  /* T80_MCode.vhd:1854:38  */
  assign n7342_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1855:33  */
  assign n7344_o = n7342_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1857:33  */
  assign n7348_o = n7342_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1863:33  */
  assign n7350_o = n7342_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1868:33  */
  assign n7352_o = n7342_o == 31'b0000000000000000000000000000100;
  assign n7353_o = {n7352_o, n7350_o, n7348_o, n7344_o};
  /* T80_MCode.vhd:1854:33  */
  always @*
    case (n7353_o)
      4'b1000: n7355_o = n2122_o;
      4'b0100: n7355_o = 3'b100;
      4'b0010: n7355_o = n2122_o;
      4'b0001: n7355_o = n2122_o;
      default: n7355_o = n2122_o;
    endcase
  /* T80_MCode.vhd:1854:33  */
  always @*
    case (n7353_o)
      4'b1000: n7358_o = 1'b0;
      4'b0100: n7358_o = 1'b0;
      4'b0010: n7358_o = 1'b1;
      4'b0001: n7358_o = 1'b0;
      default: n7358_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1854:33  */
  always @*
    case (n7353_o)
      4'b1000: n7360_o = 3'b000;
      4'b0100: n7360_o = 3'b000;
      4'b0010: n7360_o = 3'b111;
      4'b0001: n7360_o = 3'b000;
      default: n7360_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1854:33  */
  always @*
    case (n7353_o)
      4'b1000: n7362_o = 3'b000;
      4'b0100: n7362_o = 3'b000;
      4'b0010: n7362_o = 3'b110;
      4'b0001: n7362_o = 3'b000;
      default: n7362_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1854:33  */
  always @*
    case (n7353_o)
      4'b1000: n7364_o = n2125_o;
      4'b0100: n7364_o = n2125_o;
      4'b0010: n7364_o = 4'b1110;
      4'b0001: n7364_o = n2125_o;
      default: n7364_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1854:33  */
  always @*
    case (n7353_o)
      4'b1000: n7367_o = 1'b0;
      4'b0100: n7367_o = 1'b0;
      4'b0010: n7367_o = 1'b1;
      4'b0001: n7367_o = 1'b0;
      default: n7367_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1854:33  */
  always @*
    case (n7353_o)
      4'b1000: n7371_o = 3'b111;
      4'b0100: n7371_o = 3'b010;
      4'b0010: n7371_o = 3'b111;
      4'b0001: n7371_o = 3'b010;
      default: n7371_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1854:33  */
  always @*
    case (n7353_o)
      4'b1000: n7374_o = 1'b0;
      4'b0100: n7374_o = 1'b1;
      4'b0010: n7374_o = 1'b0;
      4'b0001: n7374_o = 1'b0;
      default: n7374_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1854:33  */
  always @*
    case (n7353_o)
      4'b1000: n7377_o = 1'b0;
      4'b0100: n7377_o = 1'b1;
      4'b0010: n7377_o = 1'b0;
      4'b0001: n7377_o = 1'b0;
      default: n7377_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1854:33  */
  always @*
    case (n7353_o)
      4'b1000: n7380_o = 1'b1;
      4'b0100: n7380_o = 1'b0;
      4'b0010: n7380_o = 1'b0;
      4'b0001: n7380_o = 1'b0;
      default: n7380_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1851:25  */
  assign n7382_o = ir == 8'b01100111;
  /* T80_MCode.vhd:1875:38  */
  assign n7383_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1876:33  */
  assign n7385_o = n7383_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1878:33  */
  assign n7387_o = n7383_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1882:33  */
  assign n7389_o = n7383_o == 31'b0000000000000000000000000000011;
  assign n7390_o = {n7389_o, n7387_o, n7385_o};
  /* T80_MCode.vhd:1875:33  */
  always @*
    case (n7390_o)
      3'b100: n7394_o = 4'b0111;
      3'b010: n7394_o = 4'b0111;
      3'b001: n7394_o = 4'b0000;
      default: n7394_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1875:33  */
  always @*
    case (n7390_o)
      3'b100: n7398_o = 3'b111;
      3'b010: n7398_o = 3'b101;
      3'b001: n7398_o = 3'b101;
      default: n7398_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1875:33  */
  always @*
    case (n7390_o)
      3'b100: n7401_o = 1'b1;
      3'b010: n7401_o = 1'b0;
      3'b001: n7401_o = 1'b0;
      default: n7401_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1875:33  */
  always @*
    case (n7390_o)
      3'b100: n7404_o = 1'b0;
      3'b010: n7404_o = 1'b1;
      3'b001: n7404_o = 1'b0;
      default: n7404_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1875:33  */
  always @*
    case (n7390_o)
      3'b100: n7407_o = 1'b1;
      3'b010: n7407_o = 1'b0;
      3'b001: n7407_o = 1'b0;
      default: n7407_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1875:33  */
  always @*
    case (n7390_o)
      3'b100: n7410_o = 1'b1;
      3'b010: n7410_o = 1'b0;
      3'b001: n7410_o = 1'b0;
      default: n7410_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1872:25  */
  assign n7412_o = ir == 8'b01000101;
  /* T80_MCode.vhd:1872:40  */
  assign n7414_o = ir == 8'b01001101;
  /* T80_MCode.vhd:1872:40  */
  assign n7415_o = n7412_o | n7414_o;
  /* T80_MCode.vhd:1872:51  */
  assign n7417_o = ir == 8'b01010101;
  /* T80_MCode.vhd:1872:51  */
  assign n7418_o = n7415_o | n7417_o;
  /* T80_MCode.vhd:1872:62  */
  assign n7420_o = ir == 8'b01011101;
  /* T80_MCode.vhd:1872:62  */
  assign n7421_o = n7418_o | n7420_o;
  /* T80_MCode.vhd:1872:73  */
  assign n7423_o = ir == 8'b01100101;
  /* T80_MCode.vhd:1872:73  */
  assign n7424_o = n7421_o | n7423_o;
  /* T80_MCode.vhd:1872:84  */
  assign n7426_o = ir == 8'b01101101;
  /* T80_MCode.vhd:1872:84  */
  assign n7427_o = n7424_o | n7426_o;
  /* T80_MCode.vhd:1872:95  */
  assign n7429_o = ir == 8'b01110101;
  /* T80_MCode.vhd:1872:95  */
  assign n7430_o = n7427_o | n7429_o;
  /* T80_MCode.vhd:1872:106  */
  assign n7432_o = ir == 8'b01111101;
  /* T80_MCode.vhd:1872:106  */
  assign n7433_o = n7430_o | n7432_o;
  /* T80_MCode.vhd:1892:38  */
  assign n7434_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1893:33  */
  assign n7436_o = n7434_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1898:46  */
  assign n7437_o = ir[5:3];
  /* T80_MCode.vhd:1898:59  */
  assign n7439_o = n7437_o != 3'b110;
  /* T80_MCode.vhd:1900:78  */
  assign n7440_o = ir[5:3];
  /* T80_MCode.vhd:1898:41  */
  assign n7443_o = n7439_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1898:41  */
  assign n7445_o = n7439_o ? n7440_o : 3'b000;
  /* T80_MCode.vhd:1896:33  */
  assign n7447_o = n7434_o == 31'b0000000000000000000000000000010;
  assign n7448_o = {n7447_o, n7436_o};
  /* T80_MCode.vhd:1892:33  */
  always @*
    case (n7448_o)
      2'b10: n7450_o = n7443_o;
      2'b01: n7450_o = 1'b0;
      default: n7450_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1892:33  */
  always @*
    case (n7448_o)
      2'b10: n7452_o = n7445_o;
      2'b01: n7452_o = 3'b000;
      default: n7452_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1892:33  */
  always @*
    case (n7448_o)
      2'b10: n7455_o = 3'b111;
      2'b01: n7455_o = 3'b000;
      default: n7455_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1892:33  */
  always @*
    case (n7448_o)
      2'b10: n7458_o = 1'b1;
      2'b01: n7458_o = 1'b0;
      default: n7458_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1892:33  */
  always @*
    case (n7448_o)
      2'b10: n7461_o = 1'b1;
      2'b01: n7461_o = 1'b0;
      default: n7461_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1892:33  */
  always @*
    case (n7448_o)
      2'b10: n7464_o = 2'b00;
      2'b01: n7464_o = 2'b01;
      default: n7464_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1889:25  */
  assign n7466_o = ir == 8'b01000000;
  /* T80_MCode.vhd:1889:40  */
  assign n7468_o = ir == 8'b01001000;
  /* T80_MCode.vhd:1889:40  */
  assign n7469_o = n7466_o | n7468_o;
  /* T80_MCode.vhd:1889:51  */
  assign n7471_o = ir == 8'b01010000;
  /* T80_MCode.vhd:1889:51  */
  assign n7472_o = n7469_o | n7471_o;
  /* T80_MCode.vhd:1889:62  */
  assign n7474_o = ir == 8'b01011000;
  /* T80_MCode.vhd:1889:62  */
  assign n7475_o = n7472_o | n7474_o;
  /* T80_MCode.vhd:1889:73  */
  assign n7477_o = ir == 8'b01100000;
  /* T80_MCode.vhd:1889:73  */
  assign n7478_o = n7475_o | n7477_o;
  /* T80_MCode.vhd:1889:84  */
  assign n7480_o = ir == 8'b01101000;
  /* T80_MCode.vhd:1889:84  */
  assign n7481_o = n7478_o | n7480_o;
  /* T80_MCode.vhd:1889:95  */
  assign n7483_o = ir == 8'b01110000;
  /* T80_MCode.vhd:1889:95  */
  assign n7484_o = n7481_o | n7483_o;
  /* T80_MCode.vhd:1889:106  */
  assign n7486_o = ir == 8'b01111000;
  /* T80_MCode.vhd:1889:106  */
  assign n7487_o = n7484_o | n7486_o;
  /* T80_MCode.vhd:1909:38  */
  assign n7488_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1913:78  */
  assign n7489_o = ir[5:3];
  /* T80_MCode.vhd:1914:46  */
  assign n7490_o = ir[5:3];
  /* T80_MCode.vhd:1914:59  */
  assign n7492_o = n7490_o == 3'b110;
  /* T80_MCode.vhd:1914:41  */
  assign n7495_o = n7492_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1910:33  */
  assign n7497_o = n7488_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1917:33  */
  assign n7499_o = n7488_o == 31'b0000000000000000000000000000010;
  assign n7500_o = {n7499_o, n7497_o};
  /* T80_MCode.vhd:1909:33  */
  always @*
    case (n7500_o)
      2'b10: n7502_o = 3'b000;
      2'b01: n7502_o = n7489_o;
      default: n7502_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1909:33  */
  always @*
    case (n7500_o)
      2'b10: n7504_o = 1'b0;
      2'b01: n7504_o = n7495_o;
      default: n7504_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1909:33  */
  always @*
    case (n7500_o)
      2'b10: n7507_o = 3'b111;
      2'b01: n7507_o = 3'b000;
      default: n7507_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1909:33  */
  always @*
    case (n7500_o)
      2'b10: n7510_o = 1'b1;
      2'b01: n7510_o = 1'b0;
      default: n7510_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1909:33  */
  always @*
    case (n7500_o)
      2'b10: n7513_o = 2'b00;
      2'b01: n7513_o = 2'b01;
      default: n7513_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1909:33  */
  always @*
    case (n7500_o)
      2'b10: n7516_o = 1'b1;
      2'b01: n7516_o = 1'b0;
      default: n7516_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1905:25  */
  assign n7518_o = ir == 8'b01000001;
  /* T80_MCode.vhd:1905:40  */
  assign n7520_o = ir == 8'b01001001;
  /* T80_MCode.vhd:1905:40  */
  assign n7521_o = n7518_o | n7520_o;
  /* T80_MCode.vhd:1905:51  */
  assign n7523_o = ir == 8'b01010001;
  /* T80_MCode.vhd:1905:51  */
  assign n7524_o = n7521_o | n7523_o;
  /* T80_MCode.vhd:1905:62  */
  assign n7526_o = ir == 8'b01011001;
  /* T80_MCode.vhd:1905:62  */
  assign n7527_o = n7524_o | n7526_o;
  /* T80_MCode.vhd:1905:73  */
  assign n7529_o = ir == 8'b01100001;
  /* T80_MCode.vhd:1905:73  */
  assign n7530_o = n7527_o | n7529_o;
  /* T80_MCode.vhd:1905:84  */
  assign n7532_o = ir == 8'b01101001;
  /* T80_MCode.vhd:1905:84  */
  assign n7533_o = n7530_o | n7532_o;
  /* T80_MCode.vhd:1905:95  */
  assign n7535_o = ir == 8'b01110001;
  /* T80_MCode.vhd:1905:95  */
  assign n7536_o = n7533_o | n7535_o;
  /* T80_MCode.vhd:1905:106  */
  assign n7538_o = ir == 8'b01111001;
  /* T80_MCode.vhd:1905:106  */
  assign n7539_o = n7536_o | n7538_o;
  /* T80_MCode.vhd:1925:38  */
  assign n7540_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1935:59  */
  assign n7541_o = ir[3];
  /* T80_MCode.vhd:1926:33  */
  assign n7543_o = n7540_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1936:33  */
  assign n7545_o = n7540_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1941:46  */
  assign n7546_o = ir[3];
  /* T80_MCode.vhd:1941:50  */
  assign n7547_o = ~n7546_o;
  /* T80_MCode.vhd:1941:41  */
  assign n7550_o = n7547_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1940:33  */
  assign n7552_o = n7540_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1948:33  */
  assign n7554_o = n7540_o == 31'b0000000000000000000000000000100;
  assign n7555_o = {n7554_o, n7552_o, n7545_o, n7543_o};
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7558_o = 3'b101;
      4'b0100: n7558_o = n2122_o;
      4'b0010: n7558_o = n2122_o;
      4'b0001: n7558_o = 3'b101;
      default: n7558_o = n2122_o;
    endcase
  assign n7559_o = n7550_o[2:0];
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7561_o = 3'b000;
      4'b0100: n7561_o = n7559_o;
      4'b0010: n7561_o = 3'b000;
      4'b0001: n7561_o = 3'b000;
      default: n7561_o = 3'b000;
    endcase
  assign n7562_o = n7550_o[3];
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7564_o = 1'b0;
      4'b0100: n7564_o = n7562_o;
      4'b0010: n7564_o = 1'b0;
      4'b0001: n7564_o = n7541_o;
      default: n7564_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7567_o = 1'b0;
      4'b0100: n7567_o = 1'b0;
      4'b0010: n7567_o = 1'b0;
      4'b0001: n7567_o = 1'b1;
      default: n7567_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7570_o = 4'b0000;
      4'b0100: n7570_o = 4'b0000;
      4'b0010: n7570_o = 4'b0000;
      4'b0001: n7570_o = 4'b0000;
      default: n7570_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7574_o = 4'b0000;
      4'b0100: n7574_o = 4'b0000;
      4'b0010: n7574_o = 4'b0110;
      4'b0001: n7574_o = 4'b1010;
      default: n7574_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7576_o = n2125_o;
      4'b0100: n7576_o = n2125_o;
      4'b0010: n7576_o = n2125_o;
      4'b0001: n7576_o = 4'b0010;
      default: n7576_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7579_o = 1'b0;
      4'b0100: n7579_o = 1'b0;
      4'b0010: n7579_o = 1'b0;
      4'b0001: n7579_o = 1'b1;
      default: n7579_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7583_o = 3'b111;
      4'b0100: n7583_o = 3'b111;
      4'b0010: n7583_o = 3'b010;
      4'b0001: n7583_o = 3'b000;
      default: n7583_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7586_o = 1'b0;
      4'b0100: n7586_o = 1'b0;
      4'b0010: n7586_o = 1'b1;
      4'b0001: n7586_o = 1'b0;
      default: n7586_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7589_o = 1'b0;
      4'b0100: n7589_o = 1'b1;
      4'b0010: n7589_o = 1'b0;
      4'b0001: n7589_o = 1'b0;
      default: n7589_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7592_o = 2'b00;
      4'b0100: n7592_o = 2'b00;
      4'b0010: n7592_o = 2'b00;
      4'b0001: n7592_o = 2'b11;
      default: n7592_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7595_o = 1'b1;
      4'b0100: n7595_o = 1'b0;
      4'b0010: n7595_o = 1'b0;
      4'b0001: n7595_o = 1'b0;
      default: n7595_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1925:33  */
  always @*
    case (n7555_o)
      4'b1000: n7598_o = 1'b0;
      4'b0100: n7598_o = 1'b1;
      4'b0010: n7598_o = 1'b0;
      4'b0001: n7598_o = 1'b0;
      default: n7598_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1922:25  */
  assign n7600_o = ir == 8'b10100010;
  /* T80_MCode.vhd:1922:41  */
  assign n7602_o = ir == 8'b10101010;
  /* T80_MCode.vhd:1922:41  */
  assign n7603_o = n7600_o | n7602_o;
  /* T80_MCode.vhd:1922:54  */
  assign n7605_o = ir == 8'b10110010;
  /* T80_MCode.vhd:1922:54  */
  assign n7606_o = n7603_o | n7605_o;
  /* T80_MCode.vhd:1922:67  */
  assign n7608_o = ir == 8'b10111010;
  /* T80_MCode.vhd:1922:67  */
  assign n7609_o = n7606_o | n7608_o;
  /* T80_MCode.vhd:1956:38  */
  assign n7610_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1957:33  */
  assign n7612_o = n7610_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1969:59  */
  assign n7613_o = ir[3];
  /* T80_MCode.vhd:1965:33  */
  assign n7615_o = n7610_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1971:46  */
  assign n7616_o = ir[3];
  /* T80_MCode.vhd:1971:50  */
  assign n7617_o = ~n7616_o;
  /* T80_MCode.vhd:1971:41  */
  assign n7620_o = n7617_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1970:33  */
  assign n7622_o = n7610_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1979:33  */
  assign n7624_o = n7610_o == 31'b0000000000000000000000000000100;
  assign n7625_o = {n7624_o, n7622_o, n7615_o, n7612_o};
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7628_o = 3'b101;
      4'b0100: n7628_o = n2122_o;
      4'b0010: n7628_o = n2122_o;
      4'b0001: n7628_o = 3'b101;
      default: n7628_o = n2122_o;
    endcase
  assign n7629_o = n7620_o[2:0];
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7631_o = 3'b000;
      4'b0100: n7631_o = n7629_o;
      4'b0010: n7631_o = 3'b000;
      4'b0001: n7631_o = 3'b000;
      default: n7631_o = 3'b000;
    endcase
  assign n7632_o = n7620_o[3];
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7634_o = 1'b0;
      4'b0100: n7634_o = n7632_o;
      4'b0010: n7634_o = n7613_o;
      4'b0001: n7634_o = 1'b0;
      default: n7634_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7637_o = 1'b0;
      4'b0100: n7637_o = 1'b0;
      4'b0010: n7637_o = 1'b0;
      4'b0001: n7637_o = 1'b1;
      default: n7637_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7640_o = 4'b0000;
      4'b0100: n7640_o = 4'b0000;
      4'b0010: n7640_o = 4'b0000;
      4'b0001: n7640_o = 4'b0000;
      default: n7640_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7644_o = 4'b0000;
      4'b0100: n7644_o = 4'b0000;
      4'b0010: n7644_o = 4'b0110;
      4'b0001: n7644_o = 4'b1010;
      default: n7644_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7646_o = n2125_o;
      4'b0100: n7646_o = n2125_o;
      4'b0010: n7646_o = n2125_o;
      4'b0001: n7646_o = 4'b0010;
      default: n7646_o = n2125_o;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7649_o = 1'b0;
      4'b0100: n7649_o = 1'b0;
      4'b0010: n7649_o = 1'b0;
      4'b0001: n7649_o = 1'b1;
      default: n7649_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7653_o = 3'b111;
      4'b0100: n7653_o = 3'b111;
      4'b0010: n7653_o = 3'b000;
      4'b0001: n7653_o = 3'b010;
      default: n7653_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7656_o = 1'b0;
      4'b0100: n7656_o = 1'b1;
      4'b0010: n7656_o = 1'b0;
      4'b0001: n7656_o = 1'b0;
      default: n7656_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7659_o = 1'b0;
      4'b0100: n7659_o = 1'b1;
      4'b0010: n7659_o = 1'b0;
      4'b0001: n7659_o = 1'b0;
      default: n7659_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7662_o = 2'b00;
      4'b0100: n7662_o = 2'b00;
      4'b0010: n7662_o = 2'b11;
      4'b0001: n7662_o = 2'b00;
      default: n7662_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7665_o = 1'b1;
      4'b0100: n7665_o = 1'b0;
      4'b0010: n7665_o = 1'b0;
      4'b0001: n7665_o = 1'b0;
      default: n7665_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1956:33  */
  always @*
    case (n7625_o)
      4'b1000: n7668_o = 1'b0;
      4'b0100: n7668_o = 1'b1;
      4'b0010: n7668_o = 1'b0;
      4'b0001: n7668_o = 1'b0;
      default: n7668_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1953:25  */
  assign n7670_o = ir == 8'b10100011;
  /* T80_MCode.vhd:1953:41  */
  assign n7672_o = ir == 8'b10101011;
  /* T80_MCode.vhd:1953:41  */
  assign n7673_o = n7670_o | n7672_o;
  /* T80_MCode.vhd:1953:54  */
  assign n7675_o = ir == 8'b10110011;
  /* T80_MCode.vhd:1953:54  */
  assign n7676_o = n7673_o | n7675_o;
  /* T80_MCode.vhd:1953:67  */
  assign n7678_o = ir == 8'b10111011;
  /* T80_MCode.vhd:1953:67  */
  assign n7679_o = n7676_o | n7678_o;
  assign n7680_o = {n7679_o, n7609_o, n7539_o, n7487_o, n7433_o, n7382_o, n7341_o, n7300_o, n7215_o, n7130_o, n7125_o, n7120_o, n7109_o, n7086_o, n7030_o, n6972_o, n6910_o, n6842_o, n6840_o, n6838_o, n6836_o, n6834_o, n6829_o};
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7696_o = 3'b100;
      23'b01000000000000000000000: n7696_o = 3'b100;
      23'b00100000000000000000000: n7696_o = 3'b010;
      23'b00010000000000000000000: n7696_o = 3'b010;
      23'b00001000000000000000000: n7696_o = 3'b011;
      23'b00000100000000000000000: n7696_o = 3'b100;
      23'b00000010000000000000000: n7696_o = 3'b100;
      23'b00000001000000000000000: n7696_o = 3'b011;
      23'b00000000100000000000000: n7696_o = 3'b011;
      23'b00000000010000000000000: n7696_o = 3'b001;
      23'b00000000001000000000000: n7696_o = 3'b001;
      23'b00000000000100000000000: n7696_o = 3'b001;
      23'b00000000000010000000000: n7696_o = 3'b001;
      23'b00000000000001000000000: n7696_o = 3'b100;
      23'b00000000000000100000000: n7696_o = 3'b100;
      23'b00000000000000010000000: n7696_o = 3'b101;
      23'b00000000000000001000000: n7696_o = 3'b101;
      23'b00000000000000000100000: n7696_o = 3'b001;
      23'b00000000000000000010000: n7696_o = 3'b001;
      23'b00000000000000000001000: n7696_o = 3'b001;
      23'b00000000000000000000100: n7696_o = 3'b001;
      23'b00000000000000000000010: n7696_o = 3'b001;
      23'b00000000000000000000001: n7696_o = 3'b001;
      default: n7696_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7702_o = n7628_o;
      23'b01000000000000000000000: n7702_o = n7558_o;
      23'b00100000000000000000000: n7702_o = n2122_o;
      23'b00010000000000000000000: n7702_o = n2122_o;
      23'b00001000000000000000000: n7702_o = n2122_o;
      23'b00000100000000000000000: n7702_o = n7355_o;
      23'b00000010000000000000000: n7702_o = n7314_o;
      23'b00000001000000000000000: n7702_o = n7263_o;
      23'b00000000100000000000000: n7702_o = n7178_o;
      23'b00000000010000000000000: n7702_o = n2122_o;
      23'b00000000001000000000000: n7702_o = n2122_o;
      23'b00000000000100000000000: n7702_o = n2122_o;
      23'b00000000000010000000000: n7702_o = n2122_o;
      23'b00000000000001000000000: n7702_o = n7049_o;
      23'b00000000000000100000000: n7702_o = n6996_o;
      23'b00000000000000010000000: n7702_o = n2122_o;
      23'b00000000000000001000000: n7702_o = n2122_o;
      23'b00000000000000000100000: n7702_o = 3'b101;
      23'b00000000000000000010000: n7702_o = 3'b101;
      23'b00000000000000000001000: n7702_o = 3'b101;
      23'b00000000000000000000100: n7702_o = 3'b101;
      23'b00000000000000000000010: n7702_o = n2122_o;
      23'b00000000000000000000001: n7702_o = n2122_o;
      default: n7702_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7705_o = 1'b0;
      23'b01000000000000000000000: n7705_o = 1'b0;
      23'b00100000000000000000000: n7705_o = 1'b0;
      23'b00010000000000000000000: n7705_o = 1'b0;
      23'b00001000000000000000000: n7705_o = 1'b0;
      23'b00000100000000000000000: n7705_o = 1'b0;
      23'b00000010000000000000000: n7705_o = 1'b0;
      23'b00000001000000000000000: n7705_o = 1'b0;
      23'b00000000100000000000000: n7705_o = 1'b0;
      23'b00000000010000000000000: n7705_o = 1'b0;
      23'b00000000001000000000000: n7705_o = 1'b0;
      23'b00000000000100000000000: n7705_o = 1'b0;
      23'b00000000000010000000000: n7705_o = 1'b0;
      23'b00000000000001000000000: n7705_o = 1'b0;
      23'b00000000000000100000000: n7705_o = 1'b0;
      23'b00000000000000010000000: n7705_o = n6942_o;
      23'b00000000000000001000000: n7705_o = n6878_o;
      23'b00000000000000000100000: n7705_o = 1'b0;
      23'b00000000000000000010000: n7705_o = 1'b0;
      23'b00000000000000000001000: n7705_o = 1'b0;
      23'b00000000000000000000100: n7705_o = 1'b0;
      23'b00000000000000000000010: n7705_o = 1'b0;
      23'b00000000000000000000001: n7705_o = 1'b0;
      default: n7705_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7708_o = 1'b0;
      23'b01000000000000000000000: n7708_o = 1'b0;
      23'b00100000000000000000000: n7708_o = 1'b0;
      23'b00010000000000000000000: n7708_o = 1'b0;
      23'b00001000000000000000000: n7708_o = 1'b0;
      23'b00000100000000000000000: n7708_o = 1'b0;
      23'b00000010000000000000000: n7708_o = 1'b0;
      23'b00000001000000000000000: n7708_o = 1'b0;
      23'b00000000100000000000000: n7708_o = 1'b0;
      23'b00000000010000000000000: n7708_o = 1'b0;
      23'b00000000001000000000000: n7708_o = 1'b0;
      23'b00000000000100000000000: n7708_o = 1'b0;
      23'b00000000000010000000000: n7708_o = 1'b0;
      23'b00000000000001000000000: n7708_o = 1'b0;
      23'b00000000000000100000000: n7708_o = 1'b0;
      23'b00000000000000010000000: n7708_o = n6945_o;
      23'b00000000000000001000000: n7708_o = n6881_o;
      23'b00000000000000000100000: n7708_o = 1'b0;
      23'b00000000000000000010000: n7708_o = 1'b0;
      23'b00000000000000000001000: n7708_o = 1'b0;
      23'b00000000000000000000100: n7708_o = 1'b0;
      23'b00000000000000000000010: n7708_o = 1'b0;
      23'b00000000000000000000001: n7708_o = 1'b0;
      default: n7708_o = 1'bX;
    endcase
  assign n7709_o = n6999_o[2:0];
  assign n7710_o = n7052_o[2:0];
  assign n7711_o = n7394_o[2:0];
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7714_o = n7631_o;
      23'b01000000000000000000000: n7714_o = n7561_o;
      23'b00100000000000000000000: n7714_o = 3'b000;
      23'b00010000000000000000000: n7714_o = 3'b000;
      23'b00001000000000000000000: n7714_o = n7711_o;
      23'b00000100000000000000000: n7714_o = 3'b000;
      23'b00000010000000000000000: n7714_o = 3'b000;
      23'b00000001000000000000000: n7714_o = 3'b000;
      23'b00000000100000000000000: n7714_o = 3'b000;
      23'b00000000010000000000000: n7714_o = 3'b000;
      23'b00000000001000000000000: n7714_o = 3'b000;
      23'b00000000000100000000000: n7714_o = 3'b000;
      23'b00000000000010000000000: n7714_o = 3'b000;
      23'b00000000000001000000000: n7714_o = n7710_o;
      23'b00000000000000100000000: n7714_o = n7709_o;
      23'b00000000000000010000000: n7714_o = 3'b000;
      23'b00000000000000001000000: n7714_o = 3'b000;
      23'b00000000000000000100000: n7714_o = 3'b000;
      23'b00000000000000000010000: n7714_o = 3'b000;
      23'b00000000000000000001000: n7714_o = 3'b000;
      23'b00000000000000000000100: n7714_o = 3'b000;
      23'b00000000000000000000010: n7714_o = 3'b000;
      23'b00000000000000000000001: n7714_o = 3'b000;
      default: n7714_o = 3'bX;
    endcase
  assign n7715_o = n6999_o[3];
  assign n7716_o = n7052_o[3];
  assign n7717_o = n7394_o[3];
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7720_o = n7634_o;
      23'b01000000000000000000000: n7720_o = n7564_o;
      23'b00100000000000000000000: n7720_o = 1'b0;
      23'b00010000000000000000000: n7720_o = 1'b0;
      23'b00001000000000000000000: n7720_o = n7717_o;
      23'b00000100000000000000000: n7720_o = 1'b0;
      23'b00000010000000000000000: n7720_o = 1'b0;
      23'b00000001000000000000000: n7720_o = 1'b0;
      23'b00000000100000000000000: n7720_o = 1'b0;
      23'b00000000010000000000000: n7720_o = 1'b0;
      23'b00000000001000000000000: n7720_o = 1'b0;
      23'b00000000000100000000000: n7720_o = 1'b0;
      23'b00000000000010000000000: n7720_o = 1'b0;
      23'b00000000000001000000000: n7720_o = n7716_o;
      23'b00000000000000100000000: n7720_o = n7715_o;
      23'b00000000000000010000000: n7720_o = 1'b0;
      23'b00000000000000001000000: n7720_o = 1'b0;
      23'b00000000000000000100000: n7720_o = 1'b0;
      23'b00000000000000000010000: n7720_o = 1'b0;
      23'b00000000000000000001000: n7720_o = 1'b0;
      23'b00000000000000000000100: n7720_o = 1'b0;
      23'b00000000000000000000010: n7720_o = 1'b0;
      23'b00000000000000000000001: n7720_o = 1'b0;
      default: n7720_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7723_o = n7637_o;
      23'b01000000000000000000000: n7723_o = n7567_o;
      23'b00100000000000000000000: n7723_o = 1'b0;
      23'b00010000000000000000000: n7723_o = n7450_o;
      23'b00001000000000000000000: n7723_o = 1'b0;
      23'b00000100000000000000000: n7723_o = n7358_o;
      23'b00000010000000000000000: n7723_o = n7317_o;
      23'b00000001000000000000000: n7723_o = n7267_o;
      23'b00000000100000000000000: n7723_o = n7182_o;
      23'b00000000010000000000000: n7723_o = 1'b0;
      23'b00000000001000000000000: n7723_o = 1'b0;
      23'b00000000000100000000000: n7723_o = 1'b0;
      23'b00000000000010000000000: n7723_o = 1'b0;
      23'b00000000000001000000000: n7723_o = 1'b0;
      23'b00000000000000100000000: n7723_o = 1'b0;
      23'b00000000000000010000000: n7723_o = 1'b0;
      23'b00000000000000001000000: n7723_o = n6885_o;
      23'b00000000000000000100000: n7723_o = 1'b0;
      23'b00000000000000000010000: n7723_o = 1'b0;
      23'b00000000000000000001000: n7723_o = 1'b0;
      23'b00000000000000000000100: n7723_o = 1'b0;
      23'b00000000000000000000010: n7723_o = 1'b0;
      23'b00000000000000000000001: n7723_o = 1'b0;
      default: n7723_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7727_o = 1'b0;
      23'b01000000000000000000000: n7727_o = 1'b0;
      23'b00100000000000000000000: n7727_o = 1'b0;
      23'b00010000000000000000000: n7727_o = 1'b0;
      23'b00001000000000000000000: n7727_o = 1'b0;
      23'b00000100000000000000000: n7727_o = 1'b0;
      23'b00000010000000000000000: n7727_o = 1'b0;
      23'b00000001000000000000000: n7727_o = 1'b0;
      23'b00000000100000000000000: n7727_o = 1'b0;
      23'b00000000010000000000000: n7727_o = 1'b0;
      23'b00000000001000000000000: n7727_o = 1'b0;
      23'b00000000000100000000000: n7727_o = 1'b0;
      23'b00000000000010000000000: n7727_o = 1'b1;
      23'b00000000000001000000000: n7727_o = 1'b0;
      23'b00000000000000100000000: n7727_o = 1'b0;
      23'b00000000000000010000000: n7727_o = 1'b0;
      23'b00000000000000001000000: n7727_o = 1'b0;
      23'b00000000000000000100000: n7727_o = 1'b0;
      23'b00000000000000000010000: n7727_o = 1'b0;
      23'b00000000000000000001000: n7727_o = 1'b0;
      23'b00000000000000000000100: n7727_o = 1'b0;
      23'b00000000000000000000010: n7727_o = 1'b0;
      23'b00000000000000000000001: n7727_o = 1'b0;
      default: n7727_o = 1'bX;
    endcase
  assign n7729_o = n7570_o[2:0];
  assign n7730_o = n7640_o[2:0];
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7733_o = n7730_o;
      23'b01000000000000000000000: n7733_o = n7729_o;
      23'b00100000000000000000000: n7733_o = 3'b000;
      23'b00010000000000000000000: n7733_o = n7452_o;
      23'b00001000000000000000000: n7733_o = 3'b000;
      23'b00000100000000000000000: n7733_o = n7360_o;
      23'b00000010000000000000000: n7733_o = n7319_o;
      23'b00000001000000000000000: n7733_o = n7269_o;
      23'b00000000100000000000000: n7733_o = n7184_o;
      23'b00000000010000000000000: n7733_o = 3'b000;
      23'b00000000001000000000000: n7733_o = 3'b000;
      23'b00000000000100000000000: n7733_o = 3'b000;
      23'b00000000000010000000000: n7733_o = 3'b010;
      23'b00000000000001000000000: n7733_o = n7054_o;
      23'b00000000000000100000000: n7733_o = n7001_o;
      23'b00000000000000010000000: n7733_o = 3'b000;
      23'b00000000000000001000000: n7733_o = n6887_o;
      23'b00000000000000000100000: n7733_o = 3'b000;
      23'b00000000000000000010000: n7733_o = 3'b000;
      23'b00000000000000000001000: n7733_o = 3'b000;
      23'b00000000000000000000100: n7733_o = 3'b000;
      23'b00000000000000000000010: n7733_o = 3'b000;
      23'b00000000000000000000001: n7733_o = 3'b000;
      default: n7733_o = 3'bX;
    endcase
  assign n7735_o = n7570_o[3];
  assign n7736_o = n7640_o[3];
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7739_o = n7736_o;
      23'b01000000000000000000000: n7739_o = n7735_o;
      23'b00100000000000000000000: n7739_o = 1'b0;
      23'b00010000000000000000000: n7739_o = 1'b0;
      23'b00001000000000000000000: n7739_o = 1'b0;
      23'b00000100000000000000000: n7739_o = 1'b0;
      23'b00000010000000000000000: n7739_o = 1'b0;
      23'b00000001000000000000000: n7739_o = 1'b0;
      23'b00000000100000000000000: n7739_o = 1'b0;
      23'b00000000010000000000000: n7739_o = 1'b0;
      23'b00000000001000000000000: n7739_o = 1'b0;
      23'b00000000000100000000000: n7739_o = 1'b0;
      23'b00000000000010000000000: n7739_o = 1'b1;
      23'b00000000000001000000000: n7739_o = 1'b0;
      23'b00000000000000100000000: n7739_o = 1'b0;
      23'b00000000000000010000000: n7739_o = 1'b0;
      23'b00000000000000001000000: n7739_o = n6889_o;
      23'b00000000000000000100000: n7739_o = 1'b0;
      23'b00000000000000000010000: n7739_o = 1'b0;
      23'b00000000000000000001000: n7739_o = 1'b0;
      23'b00000000000000000000100: n7739_o = 1'b0;
      23'b00000000000000000000010: n7739_o = 1'b0;
      23'b00000000000000000000001: n7739_o = 1'b0;
      default: n7739_o = 1'bX;
    endcase
  assign n7740_o = n6947_o[0];
  assign n7741_o = n7004_o[0];
  assign n7742_o = n7057_o[0];
  assign n7744_o = n7321_o[0];
  assign n7745_o = n7362_o[0];
  assign n7746_o = n7502_o[0];
  assign n7747_o = n7574_o[0];
  assign n7748_o = n7644_o[0];
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7751_o = n7748_o;
      23'b01000000000000000000000: n7751_o = n7747_o;
      23'b00100000000000000000000: n7751_o = n7746_o;
      23'b00010000000000000000000: n7751_o = 1'b0;
      23'b00001000000000000000000: n7751_o = 1'b0;
      23'b00000100000000000000000: n7751_o = n7745_o;
      23'b00000010000000000000000: n7751_o = n7744_o;
      23'b00000001000000000000000: n7751_o = n7271_o;
      23'b00000000100000000000000: n7751_o = n7186_o;
      23'b00000000010000000000000: n7751_o = 1'b0;
      23'b00000000001000000000000: n7751_o = 1'b0;
      23'b00000000000100000000000: n7751_o = 1'b0;
      23'b00000000000010000000000: n7751_o = 1'b1;
      23'b00000000000001000000000: n7751_o = n7742_o;
      23'b00000000000000100000000: n7751_o = n7741_o;
      23'b00000000000000010000000: n7751_o = n7740_o;
      23'b00000000000000001000000: n7751_o = 1'b0;
      23'b00000000000000000100000: n7751_o = 1'b0;
      23'b00000000000000000010000: n7751_o = 1'b0;
      23'b00000000000000000001000: n7751_o = 1'b0;
      23'b00000000000000000000100: n7751_o = 1'b0;
      23'b00000000000000000000010: n7751_o = 1'b0;
      23'b00000000000000000000001: n7751_o = 1'b0;
      default: n7751_o = 1'bX;
    endcase
  assign n7752_o = n6947_o[2:1];
  assign n7753_o = n7004_o[2:1];
  assign n7754_o = n7057_o[2:1];
  assign n7756_o = n7321_o[2:1];
  assign n7757_o = n7362_o[2:1];
  assign n7758_o = n7502_o[2:1];
  assign n7759_o = n7574_o[2:1];
  assign n7760_o = n7644_o[2:1];
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7763_o = n7760_o;
      23'b01000000000000000000000: n7763_o = n7759_o;
      23'b00100000000000000000000: n7763_o = n7758_o;
      23'b00010000000000000000000: n7763_o = 2'b00;
      23'b00001000000000000000000: n7763_o = 2'b00;
      23'b00000100000000000000000: n7763_o = n7757_o;
      23'b00000010000000000000000: n7763_o = n7756_o;
      23'b00000001000000000000000: n7763_o = n7273_o;
      23'b00000000100000000000000: n7763_o = n7188_o;
      23'b00000000010000000000000: n7763_o = 2'b00;
      23'b00000000001000000000000: n7763_o = 2'b00;
      23'b00000000000100000000000: n7763_o = 2'b00;
      23'b00000000000010000000000: n7763_o = 2'b11;
      23'b00000000000001000000000: n7763_o = n7754_o;
      23'b00000000000000100000000: n7763_o = n7753_o;
      23'b00000000000000010000000: n7763_o = n7752_o;
      23'b00000000000000001000000: n7763_o = 2'b00;
      23'b00000000000000000100000: n7763_o = 2'b00;
      23'b00000000000000000010000: n7763_o = 2'b00;
      23'b00000000000000000001000: n7763_o = 2'b00;
      23'b00000000000000000000100: n7763_o = 2'b00;
      23'b00000000000000000000010: n7763_o = 2'b00;
      23'b00000000000000000000001: n7763_o = 2'b00;
      default: n7763_o = 2'bX;
    endcase
  assign n7764_o = n6947_o[3];
  assign n7765_o = n7004_o[3];
  assign n7766_o = n7057_o[3];
  assign n7768_o = n7574_o[3];
  assign n7769_o = n7644_o[3];
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7772_o = n7769_o;
      23'b01000000000000000000000: n7772_o = n7768_o;
      23'b00100000000000000000000: n7772_o = n7504_o;
      23'b00010000000000000000000: n7772_o = 1'b0;
      23'b00001000000000000000000: n7772_o = 1'b0;
      23'b00000100000000000000000: n7772_o = 1'b0;
      23'b00000010000000000000000: n7772_o = 1'b0;
      23'b00000001000000000000000: n7772_o = n7275_o;
      23'b00000000100000000000000: n7772_o = n7190_o;
      23'b00000000010000000000000: n7772_o = 1'b0;
      23'b00000000001000000000000: n7772_o = 1'b0;
      23'b00000000000100000000000: n7772_o = 1'b0;
      23'b00000000000010000000000: n7772_o = 1'b0;
      23'b00000000000001000000000: n7772_o = n7766_o;
      23'b00000000000000100000000: n7772_o = n7765_o;
      23'b00000000000000010000000: n7772_o = n7764_o;
      23'b00000000000000001000000: n7772_o = 1'b0;
      23'b00000000000000000100000: n7772_o = 1'b0;
      23'b00000000000000000010000: n7772_o = 1'b0;
      23'b00000000000000000001000: n7772_o = 1'b0;
      23'b00000000000000000000100: n7772_o = 1'b0;
      23'b00000000000000000000010: n7772_o = 1'b0;
      23'b00000000000000000000001: n7772_o = 1'b0;
      default: n7772_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7775_o = n7646_o;
      23'b01000000000000000000000: n7775_o = n7576_o;
      23'b00100000000000000000000: n7775_o = n2125_o;
      23'b00010000000000000000000: n7775_o = n2125_o;
      23'b00001000000000000000000: n7775_o = n2125_o;
      23'b00000100000000000000000: n7775_o = n7364_o;
      23'b00000010000000000000000: n7775_o = n7323_o;
      23'b00000001000000000000000: n7775_o = n7278_o;
      23'b00000000100000000000000: n7775_o = n7193_o;
      23'b00000000010000000000000: n7775_o = n2125_o;
      23'b00000000001000000000000: n7775_o = n2125_o;
      23'b00000000000100000000000: n7775_o = n2125_o;
      23'b00000000000010000000000: n7775_o = 4'b0010;
      23'b00000000000001000000000: n7775_o = n7059_o;
      23'b00000000000000100000000: n7775_o = n7006_o;
      23'b00000000000000010000000: n7775_o = n2125_o;
      23'b00000000000000001000000: n7775_o = n2125_o;
      23'b00000000000000000100000: n7775_o = n2125_o;
      23'b00000000000000000010000: n7775_o = n2125_o;
      23'b00000000000000000001000: n7775_o = n2125_o;
      23'b00000000000000000000100: n7775_o = n2125_o;
      23'b00000000000000000000010: n7775_o = n2125_o;
      23'b00000000000000000000001: n7775_o = n2125_o;
      default: n7775_o = 4'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7779_o = n7649_o;
      23'b01000000000000000000000: n7779_o = n7579_o;
      23'b00100000000000000000000: n7779_o = 1'b0;
      23'b00010000000000000000000: n7779_o = 1'b0;
      23'b00001000000000000000000: n7779_o = 1'b0;
      23'b00000100000000000000000: n7779_o = n7367_o;
      23'b00000010000000000000000: n7779_o = n7326_o;
      23'b00000001000000000000000: n7779_o = n7282_o;
      23'b00000000100000000000000: n7779_o = n7197_o;
      23'b00000000010000000000000: n7779_o = 1'b0;
      23'b00000000001000000000000: n7779_o = 1'b0;
      23'b00000000000100000000000: n7779_o = 1'b0;
      23'b00000000000010000000000: n7779_o = 1'b1;
      23'b00000000000001000000000: n7779_o = n7062_o;
      23'b00000000000000100000000: n7779_o = 1'b0;
      23'b00000000000000010000000: n7779_o = 1'b0;
      23'b00000000000000001000000: n7779_o = 1'b0;
      23'b00000000000000000100000: n7779_o = 1'b0;
      23'b00000000000000000010000: n7779_o = 1'b0;
      23'b00000000000000000001000: n7779_o = 1'b0;
      23'b00000000000000000000100: n7779_o = 1'b0;
      23'b00000000000000000000010: n7779_o = 1'b0;
      23'b00000000000000000000001: n7779_o = 1'b0;
      default: n7779_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7782_o = 1'b0;
      23'b01000000000000000000000: n7782_o = 1'b0;
      23'b00100000000000000000000: n7782_o = 1'b0;
      23'b00010000000000000000000: n7782_o = 1'b0;
      23'b00001000000000000000000: n7782_o = 1'b0;
      23'b00000100000000000000000: n7782_o = 1'b0;
      23'b00000010000000000000000: n7782_o = 1'b0;
      23'b00000001000000000000000: n7782_o = 1'b0;
      23'b00000000100000000000000: n7782_o = 1'b0;
      23'b00000000010000000000000: n7782_o = 1'b0;
      23'b00000000001000000000000: n7782_o = 1'b0;
      23'b00000000000100000000000: n7782_o = 1'b0;
      23'b00000000000010000000000: n7782_o = 1'b0;
      23'b00000000000001000000000: n7782_o = n7065_o;
      23'b00000000000000100000000: n7782_o = 1'b0;
      23'b00000000000000010000000: n7782_o = 1'b0;
      23'b00000000000000001000000: n7782_o = 1'b0;
      23'b00000000000000000100000: n7782_o = 1'b0;
      23'b00000000000000000010000: n7782_o = 1'b0;
      23'b00000000000000000001000: n7782_o = 1'b0;
      23'b00000000000000000000100: n7782_o = 1'b0;
      23'b00000000000000000000010: n7782_o = 1'b0;
      23'b00000000000000000000001: n7782_o = 1'b0;
      default: n7782_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7785_o = n7653_o;
      23'b01000000000000000000000: n7785_o = n7583_o;
      23'b00100000000000000000000: n7785_o = n7507_o;
      23'b00010000000000000000000: n7785_o = n7455_o;
      23'b00001000000000000000000: n7785_o = n7398_o;
      23'b00000100000000000000000: n7785_o = n7371_o;
      23'b00000010000000000000000: n7785_o = n7330_o;
      23'b00000001000000000000000: n7785_o = 3'b111;
      23'b00000000100000000000000: n7785_o = 3'b111;
      23'b00000000010000000000000: n7785_o = 3'b111;
      23'b00000000001000000000000: n7785_o = 3'b111;
      23'b00000000000100000000000: n7785_o = 3'b111;
      23'b00000000000010000000000: n7785_o = 3'b111;
      23'b00000000000001000000000: n7785_o = n7068_o;
      23'b00000000000000100000000: n7785_o = n7010_o;
      23'b00000000000000010000000: n7785_o = n6951_o;
      23'b00000000000000001000000: n7785_o = n6893_o;
      23'b00000000000000000100000: n7785_o = 3'b111;
      23'b00000000000000000010000: n7785_o = 3'b111;
      23'b00000000000000000001000: n7785_o = 3'b111;
      23'b00000000000000000000100: n7785_o = 3'b111;
      23'b00000000000000000000010: n7785_o = 3'b111;
      23'b00000000000000000000001: n7785_o = 3'b111;
      default: n7785_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7788_o = n7656_o;
      23'b01000000000000000000000: n7788_o = n7586_o;
      23'b00100000000000000000000: n7788_o = n7510_o;
      23'b00010000000000000000000: n7788_o = n7458_o;
      23'b00001000000000000000000: n7788_o = 1'b0;
      23'b00000100000000000000000: n7788_o = 1'b0;
      23'b00000010000000000000000: n7788_o = 1'b0;
      23'b00000001000000000000000: n7788_o = 1'b0;
      23'b00000000100000000000000: n7788_o = 1'b0;
      23'b00000000010000000000000: n7788_o = 1'b0;
      23'b00000000001000000000000: n7788_o = 1'b0;
      23'b00000000000100000000000: n7788_o = 1'b0;
      23'b00000000000010000000000: n7788_o = 1'b0;
      23'b00000000000001000000000: n7788_o = 1'b0;
      23'b00000000000000100000000: n7788_o = 1'b0;
      23'b00000000000000010000000: n7788_o = 1'b0;
      23'b00000000000000001000000: n7788_o = 1'b0;
      23'b00000000000000000100000: n7788_o = 1'b0;
      23'b00000000000000000010000: n7788_o = 1'b0;
      23'b00000000000000000001000: n7788_o = 1'b0;
      23'b00000000000000000000100: n7788_o = 1'b0;
      23'b00000000000000000000010: n7788_o = 1'b0;
      23'b00000000000000000000001: n7788_o = 1'b0;
      default: n7788_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7791_o = 1'b0;
      23'b01000000000000000000000: n7791_o = 1'b0;
      23'b00100000000000000000000: n7791_o = 1'b0;
      23'b00010000000000000000000: n7791_o = 1'b0;
      23'b00001000000000000000000: n7791_o = n7401_o;
      23'b00000100000000000000000: n7791_o = 1'b0;
      23'b00000010000000000000000: n7791_o = 1'b0;
      23'b00000001000000000000000: n7791_o = 1'b0;
      23'b00000000100000000000000: n7791_o = 1'b0;
      23'b00000000010000000000000: n7791_o = 1'b0;
      23'b00000000001000000000000: n7791_o = 1'b0;
      23'b00000000000100000000000: n7791_o = 1'b0;
      23'b00000000000010000000000: n7791_o = 1'b0;
      23'b00000000000001000000000: n7791_o = 1'b0;
      23'b00000000000000100000000: n7791_o = 1'b0;
      23'b00000000000000010000000: n7791_o = 1'b0;
      23'b00000000000000001000000: n7791_o = 1'b0;
      23'b00000000000000000100000: n7791_o = 1'b0;
      23'b00000000000000000010000: n7791_o = 1'b0;
      23'b00000000000000000001000: n7791_o = 1'b0;
      23'b00000000000000000000100: n7791_o = 1'b0;
      23'b00000000000000000000010: n7791_o = 1'b0;
      23'b00000000000000000000001: n7791_o = 1'b0;
      default: n7791_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7794_o = 1'b0;
      23'b01000000000000000000000: n7794_o = 1'b0;
      23'b00100000000000000000000: n7794_o = 1'b0;
      23'b00010000000000000000000: n7794_o = 1'b0;
      23'b00001000000000000000000: n7794_o = n7404_o;
      23'b00000100000000000000000: n7794_o = 1'b0;
      23'b00000010000000000000000: n7794_o = 1'b0;
      23'b00000001000000000000000: n7794_o = 1'b0;
      23'b00000000100000000000000: n7794_o = 1'b0;
      23'b00000000010000000000000: n7794_o = 1'b0;
      23'b00000000001000000000000: n7794_o = 1'b0;
      23'b00000000000100000000000: n7794_o = 1'b0;
      23'b00000000000010000000000: n7794_o = 1'b0;
      23'b00000000000001000000000: n7794_o = 1'b0;
      23'b00000000000000100000000: n7794_o = 1'b0;
      23'b00000000000000010000000: n7794_o = n6954_o;
      23'b00000000000000001000000: n7794_o = n6896_o;
      23'b00000000000000000100000: n7794_o = 1'b0;
      23'b00000000000000000010000: n7794_o = 1'b0;
      23'b00000000000000000001000: n7794_o = 1'b0;
      23'b00000000000000000000100: n7794_o = 1'b0;
      23'b00000000000000000000010: n7794_o = 1'b0;
      23'b00000000000000000000001: n7794_o = 1'b0;
      default: n7794_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7797_o = 1'b0;
      23'b01000000000000000000000: n7797_o = 1'b0;
      23'b00100000000000000000000: n7797_o = 1'b0;
      23'b00010000000000000000000: n7797_o = 1'b0;
      23'b00001000000000000000000: n7797_o = n7407_o;
      23'b00000100000000000000000: n7797_o = 1'b0;
      23'b00000010000000000000000: n7797_o = 1'b0;
      23'b00000001000000000000000: n7797_o = 1'b0;
      23'b00000000100000000000000: n7797_o = 1'b0;
      23'b00000000010000000000000: n7797_o = 1'b0;
      23'b00000000001000000000000: n7797_o = 1'b0;
      23'b00000000000100000000000: n7797_o = 1'b0;
      23'b00000000000010000000000: n7797_o = 1'b0;
      23'b00000000000001000000000: n7797_o = 1'b0;
      23'b00000000000000100000000: n7797_o = 1'b0;
      23'b00000000000000010000000: n7797_o = n6957_o;
      23'b00000000000000001000000: n7797_o = n6899_o;
      23'b00000000000000000100000: n7797_o = 1'b0;
      23'b00000000000000000010000: n7797_o = 1'b0;
      23'b00000000000000000001000: n7797_o = 1'b0;
      23'b00000000000000000000100: n7797_o = 1'b0;
      23'b00000000000000000000010: n7797_o = 1'b0;
      23'b00000000000000000000001: n7797_o = 1'b0;
      default: n7797_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7804_o = 3'b000;
      23'b01000000000000000000000: n7804_o = 3'b000;
      23'b00100000000000000000000: n7804_o = 3'b000;
      23'b00010000000000000000000: n7804_o = 3'b000;
      23'b00001000000000000000000: n7804_o = 3'b000;
      23'b00000100000000000000000: n7804_o = 3'b000;
      23'b00000010000000000000000: n7804_o = 3'b000;
      23'b00000001000000000000000: n7804_o = 3'b000;
      23'b00000000100000000000000: n7804_o = 3'b000;
      23'b00000000010000000000000: n7804_o = 3'b000;
      23'b00000000001000000000000: n7804_o = 3'b000;
      23'b00000000000100000000000: n7804_o = 3'b000;
      23'b00000000000010000000000: n7804_o = 3'b000;
      23'b00000000000001000000000: n7804_o = 3'b000;
      23'b00000000000000100000000: n7804_o = 3'b000;
      23'b00000000000000010000000: n7804_o = 3'b000;
      23'b00000000000000001000000: n7804_o = 3'b000;
      23'b00000000000000000100000: n7804_o = 3'b111;
      23'b00000000000000000010000: n7804_o = 3'b110;
      23'b00000000000000000001000: n7804_o = 3'b101;
      23'b00000000000000000000100: n7804_o = 3'b100;
      23'b00000000000000000000010: n7804_o = 3'b000;
      23'b00000000000000000000001: n7804_o = 3'b000;
      default: n7804_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7807_o = 1'b0;
      23'b01000000000000000000000: n7807_o = 1'b0;
      23'b00100000000000000000000: n7807_o = 1'b0;
      23'b00010000000000000000000: n7807_o = 1'b0;
      23'b00001000000000000000000: n7807_o = n7410_o;
      23'b00000100000000000000000: n7807_o = 1'b0;
      23'b00000010000000000000000: n7807_o = 1'b0;
      23'b00000001000000000000000: n7807_o = 1'b0;
      23'b00000000100000000000000: n7807_o = 1'b0;
      23'b00000000010000000000000: n7807_o = 1'b0;
      23'b00000000001000000000000: n7807_o = 1'b0;
      23'b00000000000100000000000: n7807_o = 1'b0;
      23'b00000000000010000000000: n7807_o = 1'b0;
      23'b00000000000001000000000: n7807_o = 1'b0;
      23'b00000000000000100000000: n7807_o = 1'b0;
      23'b00000000000000010000000: n7807_o = 1'b0;
      23'b00000000000000001000000: n7807_o = 1'b0;
      23'b00000000000000000100000: n7807_o = 1'b0;
      23'b00000000000000000010000: n7807_o = 1'b0;
      23'b00000000000000000001000: n7807_o = 1'b0;
      23'b00000000000000000000100: n7807_o = 1'b0;
      23'b00000000000000000000010: n7807_o = 1'b0;
      23'b00000000000000000000001: n7807_o = 1'b0;
      default: n7807_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7810_o = 1'b0;
      23'b01000000000000000000000: n7810_o = 1'b0;
      23'b00100000000000000000000: n7810_o = 1'b0;
      23'b00010000000000000000000: n7810_o = 1'b0;
      23'b00001000000000000000000: n7810_o = 1'b0;
      23'b00000100000000000000000: n7810_o = 1'b0;
      23'b00000010000000000000000: n7810_o = 1'b0;
      23'b00000001000000000000000: n7810_o = 1'b0;
      23'b00000000100000000000000: n7810_o = 1'b0;
      23'b00000000010000000000000: n7810_o = 1'b0;
      23'b00000000001000000000000: n7810_o = 1'b0;
      23'b00000000000100000000000: n7810_o = 1'b0;
      23'b00000000000010000000000: n7810_o = 1'b0;
      23'b00000000000001000000000: n7810_o = 1'b0;
      23'b00000000000000100000000: n7810_o = n7013_o;
      23'b00000000000000010000000: n7810_o = 1'b0;
      23'b00000000000000001000000: n7810_o = 1'b0;
      23'b00000000000000000100000: n7810_o = 1'b0;
      23'b00000000000000000010000: n7810_o = 1'b0;
      23'b00000000000000000001000: n7810_o = 1'b0;
      23'b00000000000000000000100: n7810_o = 1'b0;
      23'b00000000000000000000010: n7810_o = 1'b0;
      23'b00000000000000000000001: n7810_o = 1'b0;
      default: n7810_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7813_o = 1'b0;
      23'b01000000000000000000000: n7813_o = 1'b0;
      23'b00100000000000000000000: n7813_o = 1'b0;
      23'b00010000000000000000000: n7813_o = 1'b0;
      23'b00001000000000000000000: n7813_o = 1'b0;
      23'b00000100000000000000000: n7813_o = 1'b0;
      23'b00000010000000000000000: n7813_o = 1'b0;
      23'b00000001000000000000000: n7813_o = 1'b0;
      23'b00000000100000000000000: n7813_o = 1'b0;
      23'b00000000010000000000000: n7813_o = 1'b0;
      23'b00000000001000000000000: n7813_o = 1'b0;
      23'b00000000000100000000000: n7813_o = 1'b0;
      23'b00000000000010000000000: n7813_o = 1'b0;
      23'b00000000000001000000000: n7813_o = n7071_o;
      23'b00000000000000100000000: n7813_o = 1'b0;
      23'b00000000000000010000000: n7813_o = 1'b0;
      23'b00000000000000001000000: n7813_o = 1'b0;
      23'b00000000000000000100000: n7813_o = 1'b0;
      23'b00000000000000000010000: n7813_o = 1'b0;
      23'b00000000000000000001000: n7813_o = 1'b0;
      23'b00000000000000000000100: n7813_o = 1'b0;
      23'b00000000000000000000010: n7813_o = 1'b0;
      23'b00000000000000000000001: n7813_o = 1'b0;
      default: n7813_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7816_o = n7659_o;
      23'b01000000000000000000000: n7816_o = n7589_o;
      23'b00100000000000000000000: n7816_o = 1'b0;
      23'b00010000000000000000000: n7816_o = 1'b0;
      23'b00001000000000000000000: n7816_o = 1'b0;
      23'b00000100000000000000000: n7816_o = 1'b0;
      23'b00000010000000000000000: n7816_o = 1'b0;
      23'b00000001000000000000000: n7816_o = 1'b0;
      23'b00000000100000000000000: n7816_o = 1'b0;
      23'b00000000010000000000000: n7816_o = 1'b0;
      23'b00000000001000000000000: n7816_o = 1'b0;
      23'b00000000000100000000000: n7816_o = 1'b0;
      23'b00000000000010000000000: n7816_o = 1'b0;
      23'b00000000000001000000000: n7816_o = 1'b0;
      23'b00000000000000100000000: n7816_o = 1'b0;
      23'b00000000000000010000000: n7816_o = 1'b0;
      23'b00000000000000001000000: n7816_o = 1'b0;
      23'b00000000000000000100000: n7816_o = 1'b0;
      23'b00000000000000000010000: n7816_o = 1'b0;
      23'b00000000000000000001000: n7816_o = 1'b0;
      23'b00000000000000000000100: n7816_o = 1'b0;
      23'b00000000000000000000010: n7816_o = 1'b0;
      23'b00000000000000000000001: n7816_o = 1'b0;
      default: n7816_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7819_o = 1'b0;
      23'b01000000000000000000000: n7819_o = 1'b0;
      23'b00100000000000000000000: n7819_o = 1'b0;
      23'b00010000000000000000000: n7819_o = 1'b0;
      23'b00001000000000000000000: n7819_o = 1'b0;
      23'b00000100000000000000000: n7819_o = 1'b0;
      23'b00000010000000000000000: n7819_o = n7333_o;
      23'b00000001000000000000000: n7819_o = 1'b0;
      23'b00000000100000000000000: n7819_o = 1'b0;
      23'b00000000010000000000000: n7819_o = 1'b0;
      23'b00000000001000000000000: n7819_o = 1'b0;
      23'b00000000000100000000000: n7819_o = 1'b0;
      23'b00000000000010000000000: n7819_o = 1'b0;
      23'b00000000000001000000000: n7819_o = 1'b0;
      23'b00000000000000100000000: n7819_o = 1'b0;
      23'b00000000000000010000000: n7819_o = 1'b0;
      23'b00000000000000001000000: n7819_o = 1'b0;
      23'b00000000000000000100000: n7819_o = 1'b0;
      23'b00000000000000000010000: n7819_o = 1'b0;
      23'b00000000000000000001000: n7819_o = 1'b0;
      23'b00000000000000000000100: n7819_o = 1'b0;
      23'b00000000000000000000010: n7819_o = 1'b0;
      23'b00000000000000000000001: n7819_o = 1'b0;
      default: n7819_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7822_o = 1'b0;
      23'b01000000000000000000000: n7822_o = 1'b0;
      23'b00100000000000000000000: n7822_o = 1'b0;
      23'b00010000000000000000000: n7822_o = 1'b0;
      23'b00001000000000000000000: n7822_o = 1'b0;
      23'b00000100000000000000000: n7822_o = n7374_o;
      23'b00000010000000000000000: n7822_o = 1'b0;
      23'b00000001000000000000000: n7822_o = 1'b0;
      23'b00000000100000000000000: n7822_o = 1'b0;
      23'b00000000010000000000000: n7822_o = 1'b0;
      23'b00000000001000000000000: n7822_o = 1'b0;
      23'b00000000000100000000000: n7822_o = 1'b0;
      23'b00000000000010000000000: n7822_o = 1'b0;
      23'b00000000000001000000000: n7822_o = 1'b0;
      23'b00000000000000100000000: n7822_o = 1'b0;
      23'b00000000000000010000000: n7822_o = 1'b0;
      23'b00000000000000001000000: n7822_o = 1'b0;
      23'b00000000000000000100000: n7822_o = 1'b0;
      23'b00000000000000000010000: n7822_o = 1'b0;
      23'b00000000000000000001000: n7822_o = 1'b0;
      23'b00000000000000000000100: n7822_o = 1'b0;
      23'b00000000000000000000010: n7822_o = 1'b0;
      23'b00000000000000000000001: n7822_o = 1'b0;
      default: n7822_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7825_o = 1'b0;
      23'b01000000000000000000000: n7825_o = 1'b0;
      23'b00100000000000000000000: n7825_o = 1'b0;
      23'b00010000000000000000000: n7825_o = n7461_o;
      23'b00001000000000000000000: n7825_o = 1'b0;
      23'b00000100000000000000000: n7825_o = 1'b0;
      23'b00000010000000000000000: n7825_o = 1'b0;
      23'b00000001000000000000000: n7825_o = 1'b0;
      23'b00000000100000000000000: n7825_o = 1'b0;
      23'b00000000010000000000000: n7825_o = 1'b0;
      23'b00000000001000000000000: n7825_o = 1'b0;
      23'b00000000000100000000000: n7825_o = 1'b0;
      23'b00000000000010000000000: n7825_o = 1'b0;
      23'b00000000000001000000000: n7825_o = 1'b0;
      23'b00000000000000100000000: n7825_o = 1'b0;
      23'b00000000000000010000000: n7825_o = 1'b0;
      23'b00000000000000001000000: n7825_o = 1'b0;
      23'b00000000000000000100000: n7825_o = 1'b0;
      23'b00000000000000000010000: n7825_o = 1'b0;
      23'b00000000000000000001000: n7825_o = 1'b0;
      23'b00000000000000000000100: n7825_o = 1'b0;
      23'b00000000000000000000010: n7825_o = 1'b0;
      23'b00000000000000000000001: n7825_o = 1'b0;
      default: n7825_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7828_o = n7662_o;
      23'b01000000000000000000000: n7828_o = n7592_o;
      23'b00100000000000000000000: n7828_o = n7513_o;
      23'b00010000000000000000000: n7828_o = n7464_o;
      23'b00001000000000000000000: n7828_o = 2'b00;
      23'b00000100000000000000000: n7828_o = 2'b00;
      23'b00000010000000000000000: n7828_o = 2'b00;
      23'b00000001000000000000000: n7828_o = n7285_o;
      23'b00000000100000000000000: n7828_o = n7200_o;
      23'b00000000010000000000000: n7828_o = 2'b00;
      23'b00000000001000000000000: n7828_o = 2'b00;
      23'b00000000000100000000000: n7828_o = 2'b00;
      23'b00000000000010000000000: n7828_o = 2'b00;
      23'b00000000000001000000000: n7828_o = 2'b00;
      23'b00000000000000100000000: n7828_o = 2'b00;
      23'b00000000000000010000000: n7828_o = 2'b00;
      23'b00000000000000001000000: n7828_o = 2'b00;
      23'b00000000000000000100000: n7828_o = 2'b00;
      23'b00000000000000000010000: n7828_o = 2'b00;
      23'b00000000000000000001000: n7828_o = 2'b00;
      23'b00000000000000000000100: n7828_o = 2'b00;
      23'b00000000000000000000010: n7828_o = 2'b00;
      23'b00000000000000000000001: n7828_o = 2'b00;
      default: n7828_o = 2'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7834_o = 2'b11;
      23'b01000000000000000000000: n7834_o = 2'b11;
      23'b00100000000000000000000: n7834_o = 2'b11;
      23'b00010000000000000000000: n7834_o = 2'b11;
      23'b00001000000000000000000: n7834_o = 2'b11;
      23'b00000100000000000000000: n7834_o = 2'b11;
      23'b00000010000000000000000: n7834_o = 2'b11;
      23'b00000001000000000000000: n7834_o = 2'b11;
      23'b00000000100000000000000: n7834_o = 2'b11;
      23'b00000000010000000000000: n7834_o = 2'b10;
      23'b00000000001000000000000: n7834_o = 2'b01;
      23'b00000000000100000000000: n7834_o = 2'b00;
      23'b00000000000010000000000: n7834_o = 2'b11;
      23'b00000000000001000000000: n7834_o = 2'b11;
      23'b00000000000000100000000: n7834_o = 2'b11;
      23'b00000000000000010000000: n7834_o = 2'b11;
      23'b00000000000000001000000: n7834_o = 2'b11;
      23'b00000000000000000100000: n7834_o = 2'b11;
      23'b00000000000000000010000: n7834_o = 2'b11;
      23'b00000000000000000001000: n7834_o = 2'b11;
      23'b00000000000000000000100: n7834_o = 2'b11;
      23'b00000000000000000000010: n7834_o = 2'b11;
      23'b00000000000000000000001: n7834_o = 2'b11;
      default: n7834_o = 2'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7837_o = n7665_o;
      23'b01000000000000000000000: n7837_o = n7595_o;
      23'b00100000000000000000000: n7837_o = 1'b0;
      23'b00010000000000000000000: n7837_o = 1'b0;
      23'b00001000000000000000000: n7837_o = 1'b0;
      23'b00000100000000000000000: n7837_o = n7377_o;
      23'b00000010000000000000000: n7837_o = n7336_o;
      23'b00000001000000000000000: n7837_o = n7289_o;
      23'b00000000100000000000000: n7837_o = n7204_o;
      23'b00000000010000000000000: n7837_o = 1'b0;
      23'b00000000001000000000000: n7837_o = 1'b0;
      23'b00000000000100000000000: n7837_o = 1'b0;
      23'b00000000000010000000000: n7837_o = 1'b0;
      23'b00000000000001000000000: n7837_o = n7075_o;
      23'b00000000000000100000000: n7837_o = n7016_o;
      23'b00000000000000010000000: n7837_o = 1'b0;
      23'b00000000000000001000000: n7837_o = 1'b0;
      23'b00000000000000000100000: n7837_o = 1'b0;
      23'b00000000000000000010000: n7837_o = 1'b0;
      23'b00000000000000000001000: n7837_o = 1'b0;
      23'b00000000000000000000100: n7837_o = 1'b0;
      23'b00000000000000000000010: n7837_o = 1'b0;
      23'b00000000000000000000001: n7837_o = 1'b0;
      default: n7837_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1575:25  */
  always @*
    case (n7680_o)
      23'b10000000000000000000000: n7840_o = n7668_o;
      23'b01000000000000000000000: n7840_o = n7598_o;
      23'b00100000000000000000000: n7840_o = n7516_o;
      23'b00010000000000000000000: n7840_o = 1'b0;
      23'b00001000000000000000000: n7840_o = 1'b0;
      23'b00000100000000000000000: n7840_o = n7380_o;
      23'b00000010000000000000000: n7840_o = n7339_o;
      23'b00000001000000000000000: n7840_o = 1'b0;
      23'b00000000100000000000000: n7840_o = 1'b0;
      23'b00000000010000000000000: n7840_o = 1'b0;
      23'b00000000001000000000000: n7840_o = 1'b0;
      23'b00000000000100000000000: n7840_o = 1'b0;
      23'b00000000000010000000000: n7840_o = 1'b0;
      23'b00000000000001000000000: n7840_o = 1'b0;
      23'b00000000000000100000000: n7840_o = n7019_o;
      23'b00000000000000010000000: n7840_o = n6961_o;
      23'b00000000000000001000000: n7840_o = 1'b0;
      23'b00000000000000000100000: n7840_o = 1'b0;
      23'b00000000000000000010000: n7840_o = 1'b0;
      23'b00000000000000000001000: n7840_o = 1'b0;
      23'b00000000000000000000100: n7840_o = 1'b0;
      23'b00000000000000000000010: n7840_o = 1'b0;
      23'b00000000000000000000001: n7840_o = 1'b0;
      default: n7840_o = 1'bX;
    endcase
  assign n7841_o = {n6302_o, n5214_o};
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7842_o = n6280_o;
      2'b01: n7842_o = n4958_o;
      default: n7842_o = n7696_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7844_o = n6282_o;
      2'b01: n7844_o = n4963_o;
      default: n7844_o = n7702_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7846_o = 2'b00;
      2'b01: n7846_o = n4966_o;
      default: n7846_o = 2'b00;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7849_o = 1'b0;
      2'b01: n7849_o = n4969_o;
      default: n7849_o = n7705_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7852_o = 1'b0;
      2'b01: n7852_o = n4972_o;
      default: n7852_o = n7708_o;
    endcase
  assign n7854_o = n7714_o[1:0];
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7856_o = 2'b00;
      2'b01: n7856_o = n4989_o;
      default: n7856_o = n7854_o;
    endcase
  assign n7857_o = n5006_o[0];
  assign n7858_o = n7714_o[2];
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7860_o = 1'b0;
      2'b01: n7860_o = n7857_o;
      default: n7860_o = n7858_o;
    endcase
  assign n7861_o = n5006_o[1];
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7863_o = 1'b0;
      2'b01: n7863_o = n7861_o;
      default: n7863_o = n7720_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7867_o = n6285_o;
      2'b01: n7867_o = n5015_o;
      default: n7867_o = n7723_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7870_o = 1'b0;
      2'b01: n7870_o = n5018_o;
      default: n7870_o = n7727_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7872_o = n5215_o;
      2'b01: n7872_o = n5023_o;
      default: n7872_o = n7733_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7874_o = 1'b0;
      2'b01: n7874_o = n5028_o;
      default: n7874_o = n7739_o;
    endcase
  assign n7877_o = n6287_o[0];
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7878_o = n7877_o;
      2'b01: n7878_o = n5056_o;
      default: n7878_o = n7751_o;
    endcase
  assign n7879_o = n6287_o[2:1];
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7880_o = n7879_o;
      2'b01: n7880_o = n5084_o;
      default: n7880_o = n7763_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7882_o = 1'b0;
      2'b01: n7882_o = n5106_o;
      default: n7882_o = n7772_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7886_o = n6289_o;
      2'b01: n7886_o = n5112_o;
      default: n7886_o = n7775_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7887_o = n6292_o;
      2'b01: n7887_o = n5120_o;
      default: n7887_o = n7779_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7890_o = 1'b0;
      2'b01: n7890_o = n5125_o;
      default: n7890_o = n7782_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7893_o = 1'b0;
      2'b01: n7893_o = n5128_o;
      default: n7893_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7895_o = n6294_o;
      2'b01: n7895_o = n5131_o;
      default: n7895_o = n7785_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7898_o = 1'b0;
      2'b01: n7898_o = n5134_o;
      default: n7898_o = n7788_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7901_o = 1'b0;
      2'b01: n7901_o = n5137_o;
      default: n7901_o = n7791_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7904_o = 1'b0;
      2'b01: n7904_o = n5140_o;
      default: n7904_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7907_o = 1'b0;
      2'b01: n7907_o = n5144_o;
      default: n7907_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7910_o = 1'b0;
      2'b01: n7910_o = n5147_o;
      default: n7910_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7913_o = 1'b0;
      2'b01: n7913_o = n5150_o;
      default: n7913_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7916_o = 1'b0;
      2'b01: n7916_o = n5153_o;
      default: n7916_o = n7794_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7919_o = 1'b0;
      2'b01: n7919_o = n5156_o;
      default: n7919_o = n7797_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7922_o = 1'b0;
      2'b01: n7922_o = n5160_o;
      default: n7922_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7925_o = 3'b000;
      2'b01: n7925_o = 3'b000;
      default: n7925_o = n7804_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7928_o = 1'b0;
      2'b01: n7928_o = n5163_o;
      default: n7928_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7931_o = 1'b0;
      2'b01: n7931_o = n5167_o;
      default: n7931_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7934_o = 1'b0;
      2'b01: n7934_o = n5170_o;
      default: n7934_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7937_o = 1'b0;
      2'b01: n7937_o = n5173_o;
      default: n7937_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7940_o = 1'b0;
      2'b01: n7940_o = n5176_o;
      default: n7940_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7943_o = 1'b0;
      2'b01: n7943_o = n5180_o;
      default: n7943_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7946_o = 1'b0;
      2'b01: n7946_o = n5184_o;
      default: n7946_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7949_o = 1'b0;
      2'b01: n7949_o = n5188_o;
      default: n7949_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7952_o = 1'b0;
      2'b01: n7952_o = n5191_o;
      default: n7952_o = n7807_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7955_o = 1'b0;
      2'b01: n7955_o = 1'b0;
      default: n7955_o = n7810_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7958_o = 1'b0;
      2'b01: n7958_o = 1'b0;
      default: n7958_o = n7813_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7961_o = 1'b0;
      2'b01: n7961_o = 1'b0;
      default: n7961_o = n7816_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7964_o = 1'b0;
      2'b01: n7964_o = 1'b0;
      default: n7964_o = n7819_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7967_o = 1'b0;
      2'b01: n7967_o = 1'b0;
      default: n7967_o = n7822_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7970_o = 1'b0;
      2'b01: n7970_o = 1'b0;
      default: n7970_o = n7825_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7973_o = 2'b00;
      2'b01: n7973_o = n5194_o;
      default: n7973_o = n7828_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7976_o = 1'b0;
      2'b01: n7976_o = n5198_o;
      default: n7976_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7979_o = 1'b0;
      2'b01: n7979_o = n5202_o;
      default: n7979_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7982_o = 2'b11;
      2'b01: n7982_o = 2'b11;
      default: n7982_o = n7834_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7985_o = 1'b0;
      2'b01: n7985_o = n5206_o;
      default: n7985_o = 1'b0;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7988_o = 1'b0;
      2'b01: n7988_o = n5209_o;
      default: n7988_o = n7837_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7990_o = n6297_o;
      2'b01: n7990_o = n5212_o;
      default: n7990_o = n7840_o;
    endcase
  /* T80_MCode.vhd:258:17  */
  always @*
    case (n7841_o)
      2'b10: n7993_o = n6300_o;
      2'b01: n7993_o = 1'b0;
      default: n7993_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1988:29  */
  assign n7995_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1988:29  */
  assign n7997_o = n7995_o == 32'b00000000000000000000000000000001;
  /* T80_MCode.vhd:1989:35  */
  assign n7999_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1989:25  */
  assign n8001_o = n7999_o ? n7844_o : 3'b011;
  /* T80_MCode.vhd:1988:17  */
  assign n8002_o = n7997_o ? n8001_o : n7844_o;
  /* T80_MCode.vhd:1996:29  */
  assign n8003_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:1996:29  */
  assign n8005_o = n8003_o == 32'b00000000000000000000000000000011;
  /* T80_MCode.vhd:1997:35  */
  assign n8007_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1997:25  */
  assign n8009_o = n8007_o ? n8002_o : 3'b100;
  /* T80_MCode.vhd:1996:17  */
  assign n8010_o = n8005_o ? n8009_o : n8002_o;
  /* T80_MCode.vhd:2004:29  */
  assign n8011_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:2004:29  */
  assign n8013_o = $signed(n8011_o) < $signed(32'b00000000000000000000000000000010);
  /* T80_MCode.vhd:2005:35  */
  assign n8015_o = mcycle == 3'b110;
  /* T80_MCode.vhd:2007:45  */
  assign n8016_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:2007:45  */
  assign n8018_o = n8016_o == 32'b00000000000000000000000000000001;
  /* T80_MCode.vhd:2005:25  */
  assign n8021_o = n8034_o ? 3'b100 : n8010_o;
  assign n8022_o = {1'b0, n2116_o};
  assign n8023_o = {n7882_o, n7880_o, n7878_o};
  /* T80_MCode.vhd:2007:33  */
  assign n8024_o = n8018_o ? n8022_o : n8023_o;
  /* T80_MCode.vhd:2007:33  */
  assign n8026_o = n8018_o ? 3'b010 : n7895_o;
  /* T80_MCode.vhd:2013:40  */
  assign n8028_o = ir == 8'b00110110;
  /* T80_MCode.vhd:2013:60  */
  assign n8030_o = ir == 8'b11001011;
  /* T80_MCode.vhd:2013:53  */
  assign n8031_o = n8028_o | n8030_o;
  /* T80_MCode.vhd:2013:33  */
  assign n8033_o = n8031_o ? 3'b111 : n8026_o;
  /* T80_MCode.vhd:2005:25  */
  assign n8034_o = n8018_o & n8015_o;
  /* T80_MCode.vhd:2005:25  */
  assign n8036_o = n8015_o ? 1'b1 : n7849_o;
  assign n8037_o = {n7882_o, n7880_o, n7878_o};
  /* T80_MCode.vhd:2005:25  */
  assign n8038_o = n8015_o ? n8024_o : n8037_o;
  /* T80_MCode.vhd:2005:25  */
  assign n8039_o = n8015_o ? n8033_o : n7895_o;
  /* T80_MCode.vhd:2017:35  */
  assign n8041_o = mcycle == 3'b111;
  /* T80_MCode.vhd:2018:45  */
  assign n8042_o = {30'b0, mode_sel};  //  uext
  /* T80_MCode.vhd:2018:45  */
  assign n8044_o = n8042_o == 32'b00000000000000000000000000000000;
  /* T80_MCode.vhd:2017:25  */
  assign n8046_o = n8061_o ? 3'b101 : n8021_o;
  /* T80_MCode.vhd:2021:41  */
  assign n8048_o = iset != 2'b01;
  /* T80_MCode.vhd:2017:25  */
  assign n8050_o = n8065_o ? 3'b010 : n8039_o;
  /* T80_MCode.vhd:2026:40  */
  assign n8053_o = ir == 8'b00110110;
  /* T80_MCode.vhd:2026:61  */
  assign n8055_o = iset == 2'b01;
  /* T80_MCode.vhd:2026:53  */
  assign n8056_o = n8053_o | n8055_o;
  /* T80_MCode.vhd:2017:25  */
  assign n8058_o = n8062_o ? 1'b1 : n8036_o;
  /* T80_MCode.vhd:2026:33  */
  assign n8060_o = n8056_o ? n7988_o : 1'b1;
  /* T80_MCode.vhd:2017:25  */
  assign n8061_o = n8044_o & n8041_o;
  /* T80_MCode.vhd:2017:25  */
  assign n8062_o = n8056_o & n8041_o;
  assign n8063_o = {1'b0, n2116_o};
  /* T80_MCode.vhd:2017:25  */
  assign n8064_o = n8041_o ? n8063_o : n8038_o;
  /* T80_MCode.vhd:2017:25  */
  assign n8065_o = n8048_o & n8041_o;
  /* T80_MCode.vhd:2004:17  */
  assign n8066_o = n8072_o ? n8060_o : n7988_o;
  /* T80_MCode.vhd:2004:17  */
  assign n8067_o = n8013_o ? n8046_o : n8010_o;
  /* T80_MCode.vhd:2004:17  */
  assign n8068_o = n8013_o ? n8058_o : n7849_o;
  assign n8069_o = {n7882_o, n7880_o, n7878_o};
  /* T80_MCode.vhd:2004:17  */
  assign n8070_o = n8013_o ? n8064_o : n8069_o;
  /* T80_MCode.vhd:2004:17  */
  assign n8071_o = n8013_o ? n8050_o : n7895_o;
  /* T80_MCode.vhd:2004:17  */
  assign n8072_o = n8041_o & n8013_o;
  assign n8074_o = {n7863_o, n7860_o, n7856_o};
  assign n8075_o = {n7874_o, n7872_o};
endmodule

module T80
  (input  RESET_n,
   input  CLK_n,
   input  CEN,
   input  WAIT_n,
   input  INT_n,
   input  NMI_n,
   input  BUSRQ_n,
   input  [7:0] DInst,
   input  [7:0] DI,
   input  out0,
   input  DIRSet,
   input  [211:0] DIR,
   input  [1:0] Mode_Sel,
   output M1_n,
   output IORQ,
   output NoRead,
   output Write,
   output RFSH_n,
   output HALT_n,
   output BUSAK_n,
   output [15:0] A,
   output [7:0] DOUT,
   output [2:0] MC,
   output [2:0] TS,
   output IntCycle_n,
   output IntE,
   output Stop,
   output [211:0] REGS);
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
  wire [1:0] n15_o;
  wire [3:0] n16_o;
  wire [131:0] n17_o;
  wire [147:0] n18_o;
  wire [163:0] n19_o;
  wire [171:0] n20_o;
  wire [179:0] n21_o;
  wire [187:0] n22_o;
  wire [195:0] n23_o;
  wire [203:0] n24_o;
  wire [211:0] n25_o;
  wire n26_o;
  wire [211:0] n27_o;
  wire [1:0] n28_o;
  wire [3:0] n29_o;
  wire [15:0] n30_o;
  wire [19:0] n31_o;
  wire [47:0] n32_o;
  wire [67:0] n33_o;
  wire [15:0] n34_o;
  wire [83:0] n35_o;
  wire [47:0] n36_o;
  wire [131:0] n37_o;
  wire [147:0] n38_o;
  wire [163:0] n39_o;
  wire [171:0] n40_o;
  wire [179:0] n41_o;
  wire [187:0] n42_o;
  wire [195:0] n43_o;
  wire [203:0] n44_o;
  wire [211:0] n45_o;
  wire [2:0] mcode_n46;
  wire [2:0] mcode_n47;
  wire [1:0] mcode_n48;
  wire mcode_n49;
  wire mcode_n50;
  wire [3:0] mcode_n51;
  wire mcode_n52;
  wire mcode_n53;
  wire [3:0] mcode_n54;
  wire [3:0] mcode_n55;
  wire [3:0] mcode_n56;
  wire mcode_n57;
  wire mcode_n58;
  wire mcode_n59;
  wire [2:0] mcode_n60;
  wire mcode_n61;
  wire mcode_n62;
  wire mcode_n63;
  wire mcode_n64;
  wire mcode_n65;
  wire mcode_n66;
  wire mcode_n67;
  wire mcode_n68;
  wire mcode_n69;
  wire [2:0] mcode_n70;
  wire mcode_n71;
  wire mcode_n72;
  wire mcode_n73;
  wire mcode_n74;
  wire mcode_n75;
  wire mcode_n76;
  wire mcode_n77;
  wire mcode_n78;
  wire mcode_n79;
  wire mcode_n80;
  wire mcode_n81;
  wire mcode_n82;
  wire mcode_n83;
  wire mcode_n84;
  wire mcode_n85;
  wire [1:0] mcode_n86;
  wire mcode_n87;
  wire mcode_n88;
  wire [1:0] mcode_n89;
  wire mcode_n90;
  wire mcode_n91;
  wire mcode_n92;
  wire mcode_n93;
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
  wire [5:0] n190_o;
  wire [7:0] u_alu_n191;
  wire [7:0] u_alu_n192;
  wire [7:0] u_alu_q;
  wire [7:0] u_alu_f_out;
  wire n197_o;
  wire n198_o;
  wire n200_o;
  wire n201_o;
  wire n205_o;
  wire n206_o;
  wire n207_o;
  wire n209_o;
  wire n211_o;
  wire n213_o;
  wire n214_o;
  wire n215_o;
  wire n217_o;
  wire n219_o;
  wire n220_o;
  wire n221_o;
  wire n222_o;
  wire n223_o;
  wire [7:0] n225_o;
  wire n226_o;
  wire [7:0] n227_o;
  wire n232_o;
  wire [7:0] n234_o;
  wire [7:0] n235_o;
  wire [7:0] n236_o;
  wire [7:0] n237_o;
  wire [7:0] n238_o;
  wire [7:0] n239_o;
  wire [15:0] n240_o;
  wire [15:0] n241_o;
  wire [15:0] n242_o;
  wire [1:0] n243_o;
  wire n245_o;
  wire [1:0] n246_o;
  wire n248_o;
  wire n249_o;
  wire n250_o;
  wire n251_o;
  wire n252_o;
  wire n253_o;
  wire n255_o;
  wire n256_o;
  wire n259_o;
  wire n261_o;
  wire n262_o;
  wire n263_o;
  wire n264_o;
  wire n266_o;
  wire n267_o;
  wire [31:0] n268_o;
  wire n270_o;
  wire [6:0] n271_o;
  wire [6:0] n273_o;
  wire [15:0] n274_o;
  wire [15:0] n275_o;
  wire [6:0] n276_o;
  wire [6:0] n277_o;
  wire n278_o;
  wire n279_o;
  wire n280_o;
  wire n281_o;
  wire n282_o;
  wire n283_o;
  wire n284_o;
  wire n285_o;
  wire n286_o;
  wire n287_o;
  wire [15:0] n289_o;
  wire [15:0] n290_o;
  wire n292_o;
  wire n293_o;
  wire n295_o;
  wire n296_o;
  wire n297_o;
  wire n298_o;
  wire [7:0] n300_o;
  wire [7:0] n302_o;
  wire n304_o;
  wire n306_o;
  wire n307_o;
  wire [1:0] n310_o;
  wire n312_o;
  wire [1:0] n314_o;
  wire n316_o;
  wire [1:0] n318_o;
  wire [1:0] n319_o;
  wire n320_o;
  wire [1:0] n322_o;
  wire [1:0] n325_o;
  wire n327_o;
  wire n328_o;
  wire n330_o;
  wire n331_o;
  wire [7:0] n332_o;
  wire [1:0] n333_o;
  wire [1:0] n334_o;
  wire n335_o;
  wire n337_o;
  wire n339_o;
  wire [1:0] n341_o;
  wire n342_o;
  wire n344_o;
  wire n345_o;
  wire n346_o;
  wire n347_o;
  wire n348_o;
  wire [7:0] n349_o;
  wire [7:0] n350_o;
  wire n351_o;
  wire n352_o;
  wire n353_o;
  wire n355_o;
  wire n356_o;
  wire n358_o;
  wire n359_o;
  wire [7:0] n360_o;
  wire [7:0] n361_o;
  wire n363_o;
  wire [15:0] n364_o;
  wire [15:0] n365_o;
  wire n367_o;
  wire [31:0] n368_o;
  wire n370_o;
  wire [31:0] n372_o;
  wire n374_o;
  wire [7:0] n375_o;
  wire [7:0] n376_o;
  wire [15:0] n377_o;
  wire [15:0] n380_o;
  wire n382_o;
  wire n384_o;
  wire [31:0] n385_o;
  wire n387_o;
  wire n388_o;
  wire [7:0] n390_o;
  wire n392_o;
  wire [15:0] n395_o;
  wire [15:0] n396_o;
  wire n398_o;
  wire [7:0] n399_o;
  wire [7:0] n402_o;
  wire [15:0] n403_o;
  wire [15:0] n404_o;
  wire [15:0] n405_o;
  wire [15:0] n406_o;
  wire [15:0] n407_o;
  wire n409_o;
  wire n411_o;
  wire [7:0] n412_o;
  wire [7:0] n415_o;
  wire [15:0] n416_o;
  wire [15:0] n417_o;
  wire n419_o;
  wire [15:0] n421_o;
  wire [7:0] n422_o;
  wire n424_o;
  wire [7:0] n425_o;
  wire [7:0] n428_o;
  wire [15:0] n429_o;
  wire [15:0] n430_o;
  wire [15:0] n431_o;
  wire [15:0] n432_o;
  wire [15:0] n433_o;
  wire n435_o;
  wire [5:0] n436_o;
  wire [7:0] n437_o;
  wire [7:0] n438_o;
  wire [7:0] n439_o;
  wire [7:0] n440_o;
  wire [7:0] n441_o;
  wire [7:0] n442_o;
  reg [7:0] n443_o;
  wire [7:0] n444_o;
  wire [7:0] n445_o;
  wire [7:0] n446_o;
  wire [7:0] n447_o;
  wire [7:0] n448_o;
  wire [7:0] n449_o;
  reg [7:0] n450_o;
  reg [15:0] n451_o;
  wire [15:0] n452_o;
  wire [15:0] n453_o;
  wire [15:0] n454_o;
  wire [15:0] n455_o;
  wire [15:0] n456_o;
  wire [15:0] n457_o;
  wire [15:0] n459_o;
  wire [15:0] n461_o;
  wire [15:0] n462_o;
  wire [15:0] n463_o;
  wire [15:0] n464_o;
  wire [15:0] n465_o;
  wire [15:0] n466_o;
  wire [15:0] n467_o;
  wire [15:0] n468_o;
  wire [15:0] n469_o;
  wire [15:0] n470_o;
  wire [15:0] n471_o;
  wire [15:0] n472_o;
  wire [15:0] n473_o;
  wire n475_o;
  wire [15:0] n476_o;
  wire [7:0] n477_o;
  wire n478_o;
  wire n479_o;
  wire n481_o;
  wire n482_o;
  wire [7:0] n484_o;
  wire [2:0] n485_o;
  wire n486_o;
  wire n487_o;
  wire n490_o;
  wire n491_o;
  wire n492_o;
  wire n493_o;
  wire n494_o;
  wire [1:0] n496_o;
  wire [2:0] n497_o;
  wire n498_o;
  wire [1:0] n499_o;
  wire [1:0] n500_o;
  wire n503_o;
  wire n505_o;
  wire [1:0] n507_o;
  wire [2:0] n508_o;
  wire [1:0] n509_o;
  wire [15:0] n511_o;
  wire n512_o;
  wire [1:0] n513_o;
  wire [1:0] n514_o;
  wire [15:0] n517_o;
  wire [15:0] n518_o;
  wire n519_o;
  wire [3:0] n521_o;
  wire n523_o;
  wire n525_o;
  wire n526_o;
  wire n527_o;
  wire n528_o;
  wire n530_o;
  wire n531_o;
  wire n532_o;
  wire n533_o;
  wire n534_o;
  wire n535_o;
  wire [8:0] n537_o;
  wire [7:0] n538_o;
  wire [8:0] n540_o;
  wire [8:0] n541_o;
  wire n542_o;
  wire n543_o;
  wire n544_o;
  wire [8:0] n546_o;
  wire [8:0] n548_o;
  wire [8:0] n549_o;
  wire n550_o;
  wire n551_o;
  wire n552_o;
  wire n553_o;
  wire n554_o;
  wire n555_o;
  wire n556_o;
  wire n557_o;
  wire n558_o;
  wire n559_o;
  wire n560_o;
  wire n561_o;
  wire n562_o;
  wire n563_o;
  wire n564_o;
  wire n565_o;
  wire [2:0] n566_o;
  wire n567_o;
  wire [2:0] n568_o;
  wire [2:0] n569_o;
  wire n570_o;
  wire n571_o;
  wire n572_o;
  wire n573_o;
  wire n574_o;
  wire n575_o;
  wire n576_o;
  wire n577_o;
  wire n578_o;
  wire n579_o;
  wire n580_o;
  wire n581_o;
  wire n582_o;
  wire n583_o;
  wire n584_o;
  wire n585_o;
  wire n586_o;
  wire n587_o;
  wire n588_o;
  wire n589_o;
  wire n590_o;
  wire n591_o;
  wire n592_o;
  wire n593_o;
  wire n594_o;
  wire n595_o;
  wire n596_o;
  wire n597_o;
  wire n600_o;
  wire n601_o;
  wire n603_o;
  wire n605_o;
  wire n606_o;
  wire [7:0] n607_o;
  wire [15:0] n608_o;
  wire [15:0] n609_o;
  wire [15:0] n610_o;
  wire [15:0] n611_o;
  wire [15:0] n613_o;
  wire [15:0] n614_o;
  wire [15:0] n615_o;
  wire [15:0] n616_o;
  wire [15:0] n618_o;
  wire [15:0] n619_o;
  wire [2:0] n620_o;
  localparam [15:0] n621_o = 16'b0000000000000000;
  wire [9:0] n622_o;
  wire [2:0] n623_o;
  wire [15:0] n624_o;
  wire [15:0] n625_o;
  wire [15:0] n626_o;
  wire [15:0] n627_o;
  wire n628_o;
  wire n630_o;
  wire n632_o;
  wire n633_o;
  wire [15:0] n634_o;
  wire [15:0] n635_o;
  wire [15:0] n636_o;
  wire n638_o;
  wire n640_o;
  wire n641_o;
  wire n642_o;
  wire n643_o;
  wire n644_o;
  wire [15:0] n647_o;
  wire [15:0] n648_o;
  wire n649_o;
  wire n651_o;
  wire n652_o;
  wire n654_o;
  wire n656_o;
  wire n657_o;
  wire n658_o;
  wire [2:0] n659_o;
  wire n661_o;
  wire n662_o;
  wire [15:0] n664_o;
  wire [15:0] n666_o;
  wire [15:0] n667_o;
  wire [15:0] n668_o;
  wire n669_o;
  wire [15:0] n670_o;
  wire [7:0] n671_o;
  wire [1:0] n672_o;
  wire [7:0] n673_o;
  wire [7:0] n675_o;
  wire [7:0] n676_o;
  wire n677_o;
  wire n678_o;
  wire [15:0] n679_o;
  wire [7:0] n680_o;
  wire [7:0] n682_o;
  wire [7:0] n683_o;
  wire n685_o;
  wire [15:0] n686_o;
  wire [15:0] n687_o;
  wire n688_o;
  wire [15:0] n689_o;
  wire [7:0] n690_o;
  wire [1:0] n691_o;
  wire n692_o;
  wire n693_o;
  wire n694_o;
  wire [3:0] n696_o;
  wire n699_o;
  wire n703_o;
  wire [7:0] n704_o;
  wire [7:0] n705_o;
  wire [7:0] n706_o;
  wire [7:0] n707_o;
  wire [7:0] n708_o;
  wire [7:0] n709_o;
  wire [7:0] n710_o;
  wire [7:0] n711_o;
  wire [7:0] n712_o;
  wire [7:0] n713_o;
  wire [7:0] n714_o;
  wire [7:0] n715_o;
  wire [7:0] n716_o;
  wire [7:0] n717_o;
  wire [7:0] n718_o;
  wire [7:0] n719_o;
  wire [7:0] n720_o;
  wire [7:0] n721_o;
  wire [7:0] n722_o;
  wire [7:0] n723_o;
  wire [7:0] n724_o;
  wire [7:0] n725_o;
  wire [7:0] n726_o;
  wire [7:0] n727_o;
  wire [7:0] n728_o;
  wire [7:0] n729_o;
  wire [7:0] n730_o;
  wire [7:0] n731_o;
  wire [7:0] n732_o;
  wire [7:0] n733_o;
  wire [7:0] n734_o;
  wire [7:0] n735_o;
  wire [7:0] n736_o;
  wire [7:0] n737_o;
  wire [7:0] n738_o;
  wire [7:0] n739_o;
  wire [7:0] n740_o;
  wire [7:0] n741_o;
  wire [7:0] n742_o;
  wire [7:0] n743_o;
  wire [7:0] n744_o;
  wire [7:0] n745_o;
  wire [7:0] n746_o;
  wire [7:0] n747_o;
  wire [7:0] n748_o;
  wire [7:0] n749_o;
  wire [7:0] n750_o;
  wire [7:0] n751_o;
  wire [7:0] n752_o;
  wire [7:0] n753_o;
  wire [7:0] n754_o;
  wire [7:0] n755_o;
  wire [7:0] n756_o;
  wire [7:0] n757_o;
  wire [7:0] n758_o;
  wire [7:0] n759_o;
  wire [7:0] n760_o;
  wire [7:0] n761_o;
  wire [7:0] n762_o;
  wire [7:0] n763_o;
  wire [7:0] n764_o;
  wire [7:0] n765_o;
  wire [7:0] n766_o;
  wire [7:0] n767_o;
  wire [7:0] n768_o;
  wire [7:0] n769_o;
  wire [7:0] n770_o;
  wire [7:0] n771_o;
  wire [7:0] n772_o;
  wire [7:0] n773_o;
  wire [7:0] n774_o;
  wire [7:0] n775_o;
  wire [7:0] n776_o;
  wire [7:0] n777_o;
  wire [7:0] n778_o;
  wire [7:0] n779_o;
  wire [7:0] n780_o;
  wire [7:0] n781_o;
  wire [7:0] n782_o;
  wire [7:0] n783_o;
  wire [7:0] n784_o;
  wire [7:0] n785_o;
  wire [7:0] n786_o;
  wire [7:0] n787_o;
  wire n788_o;
  wire [1:0] n789_o;
  wire n790_o;
  wire n792_o;
  wire n795_o;
  wire n796_o;
  wire n798_o;
  wire n801_o;
  wire n802_o;
  wire n804_o;
  wire n807_o;
  wire n808_o;
  wire n810_o;
  wire n813_o;
  wire n815_o;
  wire [2:0] n816_o;
  reg [7:0] n817_o;
  wire n818_o;
  wire n819_o;
  wire n820_o;
  wire n821_o;
  wire n822_o;
  reg n823_o;
  wire n824_o;
  wire n825_o;
  wire n826_o;
  wire n827_o;
  wire n828_o;
  reg n829_o;
  wire n830_o;
  wire n831_o;
  wire n832_o;
  wire n833_o;
  wire n834_o;
  reg n835_o;
  wire n836_o;
  wire n837_o;
  wire n838_o;
  wire n839_o;
  wire n840_o;
  reg n841_o;
  wire n842_o;
  wire n843_o;
  wire n844_o;
  wire n845_o;
  wire n846_o;
  reg n847_o;
  wire n848_o;
  wire n849_o;
  wire n850_o;
  wire n851_o;
  wire n852_o;
  reg n853_o;
  wire n854_o;
  wire n855_o;
  wire n856_o;
  wire n857_o;
  wire n858_o;
  reg n859_o;
  reg [7:0] n860_o;
  wire n861_o;
  wire [7:0] n862_o;
  reg [7:0] n863_o;
  wire [7:0] n864_o;
  wire [6:0] n865_o;
  wire [6:0] n866_o;
  wire [6:0] n867_o;
  wire [6:0] n868_o;
  wire [6:0] n869_o;
  wire [6:0] n870_o;
  wire [6:0] n871_o;
  wire [7:0] n872_o;
  wire n873_o;
  wire [7:0] n874_o;
  wire [7:0] n875_o;
  wire n876_o;
  wire [6:0] n877_o;
  wire [6:0] n878_o;
  wire [6:0] n879_o;
  wire [6:0] n880_o;
  wire [6:0] n881_o;
  wire [6:0] n882_o;
  wire n883_o;
  wire n884_o;
  wire n885_o;
  wire n886_o;
  wire n887_o;
  wire n888_o;
  wire n889_o;
  wire [7:0] n890_o;
  wire [7:0] n891_o;
  wire [15:0] n892_o;
  wire [15:0] n893_o;
  wire n894_o;
  wire n895_o;
  wire n897_o;
  wire n898_o;
  wire [31:0] n899_o;
  wire n901_o;
  wire n902_o;
  wire n903_o;
  wire n904_o;
  wire n905_o;
  wire n906_o;
  wire n907_o;
  wire n908_o;
  wire n909_o;
  wire n910_o;
  wire n911_o;
  wire n912_o;
  wire n913_o;
  wire n914_o;
  wire n915_o;
  wire n916_o;
  wire n917_o;
  wire n918_o;
  wire n919_o;
  wire n920_o;
  wire [6:0] n921_o;
  wire n922_o;
  wire n923_o;
  wire n924_o;
  wire [7:0] n925_o;
  wire [3:0] n926_o;
  wire [3:0] n927_o;
  wire [2:0] n928_o;
  wire [2:0] n929_o;
  wire [2:0] n930_o;
  wire [2:0] n931_o;
  wire [2:0] n932_o;
  wire [2:0] n933_o;
  wire [2:0] n934_o;
  wire [2:0] n935_o;
  wire [2:0] n936_o;
  wire [2:0] n937_o;
  wire [2:0] n938_o;
  wire [2:0] n939_o;
  wire [2:0] n940_o;
  wire [3:0] n941_o;
  wire [3:0] n942_o;
  wire [3:0] n943_o;
  wire [3:0] n944_o;
  wire [7:0] n945_o;
  wire [7:0] n946_o;
  wire n948_o;
  wire n951_o;
  wire n952_o;
  wire n954_o;
  wire n957_o;
  wire n958_o;
  wire n959_o;
  wire n960_o;
  wire n961_o;
  wire n962_o;
  wire n963_o;
  wire n964_o;
  wire n965_o;
  wire n966_o;
  wire n967_o;
  wire n968_o;
  wire n969_o;
  wire n970_o;
  wire n971_o;
  wire n972_o;
  wire n973_o;
  wire n974_o;
  wire [6:0] n975_o;
  wire n980_o;
  wire n981_o;
  wire n982_o;
  wire n984_o;
  wire n985_o;
  wire n986_o;
  wire n987_o;
  wire n988_o;
  wire [7:0] n989_o;
  wire [3:0] n990_o;
  wire [3:0] n991_o;
  wire [7:0] n992_o;
  wire [7:0] n993_o;
  wire [3:0] n994_o;
  wire [3:0] n995_o;
  wire [7:0] n996_o;
  wire [7:0] n997_o;
  wire [7:0] n998_o;
  wire n999_o;
  wire [4:0] n1002_o;
  wire [4:0] n1003_o;
  wire [4:0] n1004_o;
  wire [4:0] n1006_o;
  wire n1009_o;
  wire n1010_o;
  wire n1011_o;
  wire n1012_o;
  wire [2:0] n1015_o;
  wire n1016_o;
  wire n1017_o;
  wire n1018_o;
  wire n1019_o;
  wire n1020_o;
  wire n1021_o;
  wire [1:0] n1033_o;
  wire [1:0] n1034_o;
  wire [1:0] n1035_o;
  wire [1:0] n1036_o;
  wire [1:0] n1037_o;
  wire n1038_o;
  wire n1039_o;
  wire n1040_o;
  wire n1041_o;
  wire n1042_o;
  wire n1044_o;
  wire n1045_o;
  wire n1046_o;
  wire [7:0] n1048_o;
  wire [7:0] n1049_o;
  wire n1050_o;
  wire n1051_o;
  wire n1052_o;
  wire n1053_o;
  wire n1054_o;
  wire n1055_o;
  wire n1056_o;
  wire n1057_o;
  wire n1058_o;
  wire n1059_o;
  wire n1060_o;
  wire n1061_o;
  wire n1062_o;
  wire n1063_o;
  wire n1064_o;
  wire n1065_o;
  wire n1066_o;
  wire n1067_o;
  wire n1075_o;
  wire n1076_o;
  wire n1077_o;
  wire n1078_o;
  wire n1079_o;
  wire n1080_o;
  wire n1081_o;
  wire n1083_o;
  wire n1084_o;
  wire n1086_o;
  wire n1087_o;
  wire n1088_o;
  wire n1089_o;
  wire n1090_o;
  wire n1092_o;
  wire n1093_o;
  wire n1094_o;
  wire n1096_o;
  wire n1098_o;
  wire n1100_o;
  wire n1102_o;
  wire n1104_o;
  wire [4:0] n1105_o;
  reg [7:0] n1106_o;
  reg [7:0] n1107_o;
  wire [7:0] n1108_o;
  reg [7:0] n1109_o;
  wire [7:0] n1110_o;
  wire [7:0] n1111_o;
  wire [7:0] n1112_o;
  wire [7:0] n1113_o;
  wire [7:0] n1114_o;
  wire [7:0] n1115_o;
  wire [7:0] n1116_o;
  wire [7:0] n1117_o;
  wire [7:0] n1118_o;
  reg [7:0] n1119_o;
  wire [7:0] n1120_o;
  wire [7:0] n1121_o;
  wire [7:0] n1122_o;
  wire [7:0] n1123_o;
  wire [7:0] n1124_o;
  wire [7:0] n1125_o;
  wire [7:0] n1126_o;
  wire [7:0] n1127_o;
  wire [7:0] n1128_o;
  reg [7:0] n1129_o;
  wire [7:0] n1130_o;
  wire [7:0] n1131_o;
  wire [7:0] n1132_o;
  wire [7:0] n1133_o;
  wire [7:0] n1134_o;
  wire [15:0] n1135_o;
  wire [15:0] n1136_o;
  wire [15:0] n1137_o;
  wire [7:0] n1138_o;
  wire [7:0] n1139_o;
  wire [7:0] n1140_o;
  wire [7:0] n1141_o;
  wire [7:0] n1142_o;
  wire n1143_o;
  wire [7:0] n1144_o;
  wire [15:0] n1145_o;
  wire [15:0] n1146_o;
  wire n1147_o;
  wire [15:0] n1148_o;
  wire [7:0] n1149_o;
  wire [1:0] n1150_o;
  wire n1151_o;
  wire n1152_o;
  wire n1153_o;
  wire n1154_o;
  wire [4:0] n1155_o;
  wire n1156_o;
  wire n1157_o;
  wire [3:0] n1158_o;
  wire n1159_o;
  wire n1160_o;
  wire [2:0] n1161_o;
  wire n1162_o;
  wire [15:0] n1165_o;
  wire [7:0] n1166_o;
  wire [7:0] n1167_o;
  wire [7:0] n1168_o;
  wire [7:0] n1169_o;
  wire [7:0] n1170_o;
  wire [7:0] n1171_o;
  wire [7:0] n1172_o;
  wire [15:0] n1173_o;
  wire [15:0] n1174_o;
  wire n1175_o;
  wire [15:0] n1176_o;
  wire [7:0] n1177_o;
  wire [1:0] n1178_o;
  wire [1:0] n1179_o;
  wire [1:0] n1180_o;
  wire n1181_o;
  wire n1182_o;
  wire [4:0] n1183_o;
  wire n1184_o;
  wire n1185_o;
  wire [3:0] n1186_o;
  wire n1187_o;
  wire n1188_o;
  wire [2:0] n1189_o;
  wire n1190_o;
  wire [1:0] n1285_o;
  wire [2:0] n1286_o;
  wire n1287_o;
  wire n1289_o;
  wire n1290_o;
  wire [1:0] n1291_o;
  wire n1293_o;
  wire n1294_o;
  wire n1295_o;
  wire [2:0] n1297_o;
  wire [2:0] n1298_o;
  wire [1:0] n1299_o;
  wire [2:0] n1300_o;
  wire n1301_o;
  wire n1303_o;
  wire n1304_o;
  wire [1:0] n1305_o;
  wire n1307_o;
  wire n1308_o;
  wire n1309_o;
  wire [2:0] n1311_o;
  wire [2:0] n1312_o;
  wire [1:0] n1313_o;
  wire [2:0] n1314_o;
  wire n1315_o;
  wire [2:0] n1317_o;
  wire [2:0] n1318_o;
  wire n1319_o;
  wire n1321_o;
  wire n1322_o;
  wire n1324_o;
  wire n1325_o;
  wire n1326_o;
  wire [2:0] n1328_o;
  wire [2:0] n1329_o;
  wire n1330_o;
  wire [31:0] n1331_o;
  wire n1333_o;
  wire n1334_o;
  wire n1335_o;
  wire n1336_o;
  wire n1338_o;
  wire n1340_o;
  wire n1342_o;
  wire n1343_o;
  wire n1344_o;
  wire [2:0] n1345_o;
  wire n1347_o;
  wire n1348_o;
  wire n1350_o;
  wire n1353_o;
  wire n1354_o;
  wire [1:0] n1366_o;
  wire [2:0] n1367_o;
  wire n1369_o;
  wire n1371_o;
  wire n1373_o;
  wire n1374_o;
  wire n1375_o;
  wire n1376_o;
  wire n1377_o;
  wire n1379_o;
  wire n1380_o;
  wire [2:0] n1381_o;
  wire n1382_o;
  wire [2:0] n1384_o;
  wire n1386_o;
  wire n1388_o;
  wire n1390_o;
  wire n1391_o;
  wire n1392_o;
  wire n1393_o;
  wire n1394_o;
  wire [1:0] n1395_o;
  wire n1397_o;
  wire n1398_o;
  wire [2:0] n1399_o;
  wire [2:0] n1401_o;
  wire n1403_o;
  wire n1404_o;
  wire [2:0] n1405_o;
  wire [2:0] n1407_o;
  wire n1409_o;
  wire n1410_o;
  wire [2:0] n1411_o;
  wire [2:0] n1413_o;
  wire n1415_o;
  wire n1416_o;
  wire [2:0] n1417_o;
  wire [15:0] n1419_o;
  wire n1420_o;
  wire [15:0] n1421_o;
  wire [15:0] n1423_o;
  wire n1427_o;
  wire n1428_o;
  wire n1429_o;
  wire n1430_o;
  wire n1431_o;
  wire n1433_o;
  wire n1434_o;
  wire n1435_o;
  wire n1436_o;
  wire n1437_o;
  wire n1438_o;
  wire n1440_o;
  wire n1442_o;
  wire n1443_o;
  wire n1445_o;
  wire n1446_o;
  wire n1448_o;
  wire n1449_o;
  wire n1451_o;
  wire n1452_o;
  wire n1454_o;
  wire n1455_o;
  reg n1457_o;
  reg n1459_o;
  wire n1461_o;
  wire n1464_o;
  wire n1467_o;
  wire n1469_o;
  wire n1470_o;
  wire n1471_o;
  wire n1473_o;
  wire n1475_o;
  wire n1476_o;
  wire n1478_o;
  wire n1479_o;
  wire n1481_o;
  wire n1482_o;
  wire n1484_o;
  wire n1486_o;
  wire n1487_o;
  wire n1488_o;
  wire n1489_o;
  wire [1:0] n1490_o;
  wire n1492_o;
  wire n1494_o;
  wire n1495_o;
  wire n1497_o;
  wire n1498_o;
  reg n1500_o;
  reg n1502_o;
  wire n1503_o;
  wire n1504_o;
  wire n1509_o;
  wire n1510_o;
  wire [7:0] n1511_o;
  wire [7:0] n1512_o;
  wire [7:0] n1513_o;
  wire [7:0] n1514_o;
  wire n1516_o;
  wire n1517_o;
  wire [7:0] n1518_o;
  wire [7:0] n1519_o;
  wire [7:0] n1520_o;
  wire [7:0] n1521_o;
  wire n1522_o;
  wire n1524_o;
  wire n1526_o;
  wire n1527_o;
  wire n1529_o;
  wire n1531_o;
  wire n1532_o;
  wire n1533_o;
  wire n1534_o;
  wire [7:0] n1535_o;
  wire [7:0] n1536_o;
  wire [7:0] n1537_o;
  wire [7:0] n1538_o;
  wire [7:0] u_regs_n1540;
  wire [7:0] u_regs_n1541;
  wire [7:0] u_regs_n1542;
  wire [7:0] u_regs_n1543;
  wire [7:0] u_regs_n1544;
  wire [7:0] u_regs_n1545;
  wire [127:0] u_regs_n1546;
  wire [127:0] n1547_o;
  wire [7:0] u_regs_doah;
  wire [7:0] u_regs_doal;
  wire [7:0] u_regs_dobh;
  wire [7:0] u_regs_dobl;
  wire [7:0] u_regs_doch;
  wire [7:0] u_regs_docl;
  wire [127:0] u_regs_dor;
  wire n1566_o;
  wire n1567_o;
  wire [7:0] n1568_o;
  wire [7:0] n1569_o;
  wire [7:0] n1570_o;
  wire n1572_o;
  wire n1574_o;
  wire n1575_o;
  wire n1577_o;
  wire n1578_o;
  wire n1580_o;
  wire n1581_o;
  wire n1583_o;
  wire n1584_o;
  wire n1586_o;
  wire n1587_o;
  wire n1589_o;
  wire [7:0] n1590_o;
  wire n1592_o;
  wire [7:0] n1593_o;
  wire n1595_o;
  wire n1597_o;
  wire n1599_o;
  wire [7:0] n1600_o;
  wire n1602_o;
  wire [7:0] n1603_o;
  wire n1605_o;
  wire n1607_o;
  wire n1608_o;
  wire [7:0] n1611_o;
  wire n1613_o;
  wire [9:0] n1614_o;
  reg [7:0] n1617_o;
  wire n1619_o;
  wire n1620_o;
  wire [7:0] n1621_o;
  wire [7:0] n1622_o;
  wire [7:0] n1623_o;
  wire n1625_o;
  wire n1627_o;
  wire n1628_o;
  wire n1630_o;
  wire n1631_o;
  wire n1633_o;
  wire n1634_o;
  wire n1636_o;
  wire n1637_o;
  wire n1639_o;
  wire n1640_o;
  wire n1642_o;
  wire [7:0] n1643_o;
  wire n1645_o;
  wire [7:0] n1646_o;
  wire n1648_o;
  wire n1650_o;
  wire [5:0] n1651_o;
  reg [7:0] n1654_o;
  wire [7:0] n1655_o;
  wire [7:0] n1656_o;
  wire n1664_o;
  wire n1666_o;
  wire n1667_o;
  wire n1669_o;
  wire n1671_o;
  wire n1672_o;
  wire n1674_o;
  wire n1675_o;
  wire n1676_o;
  wire n1679_o;
  wire n1685_o;
  wire n1686_o;
  wire n1687_o;
  reg n1688_oldnmi_n;
  wire n1691_o;
  wire n1693_o;
  wire n1694_o;
  wire n1695_o;
  wire n1696_o;
  wire n1698_o;
  wire n1699_o;
  wire n1700_o;
  wire n1702_o;
  wire n1704_o;
  wire n1705_o;
  wire n1706_o;
  wire n1707_o;
  wire n1708_o;
  wire n1709_o;
  wire n1710_o;
  wire n1711_o;
  wire n1712_o;
  wire n1713_o;
  wire n1714_o;
  wire n1715_o;
  wire n1716_o;
  wire n1717_o;
  wire n1718_o;
  wire n1719_o;
  wire n1720_o;
  wire n1721_o;
  wire n1722_o;
  wire n1723_o;
  wire n1724_o;
  wire n1725_o;
  wire n1727_o;
  wire n1728_o;
  wire n1730_o;
  wire n1731_o;
  wire n1733_o;
  wire n1734_o;
  wire n1735_o;
  wire n1736_o;
  wire n1738_o;
  wire n1740_o;
  wire n1742_o;
  wire n1743_o;
  wire n1744_o;
  wire n1745_o;
  wire n1747_o;
  wire n1749_o;
  wire n1751_o;
  wire n1752_o;
  wire n1753_o;
  wire n1755_o;
  wire n1756_o;
  wire n1757_o;
  wire n1759_o;
  wire n1760_o;
  wire n1761_o;
  wire n1763_o;
  wire n1765_o;
  wire [31:0] n1766_o;
  wire n1768_o;
  wire n1769_o;
  wire [2:0] n1771_o;
  wire n1773_o;
  wire n1775_o;
  wire [31:0] n1776_o;
  wire n1778_o;
  wire n1779_o;
  wire n1781_o;
  wire n1782_o;
  wire n1783_o;
  wire [2:0] n1785_o;
  wire n1786_o;
  wire n1787_o;
  wire n1789_o;
  wire n1790_o;
  wire n1791_o;
  wire n1792_o;
  wire n1794_o;
  wire n1795_o;
  wire n1796_o;
  wire n1797_o;
  wire n1799_o;
  wire n1800_o;
  wire n1801_o;
  wire n1802_o;
  wire n1804_o;
  wire n1806_o;
  wire n1809_o;
  wire n1811_o;
  wire n1812_o;
  wire n1814_o;
  wire n1816_o;
  wire n1820_o;
  wire [2:0] n1823_o;
  wire n1825_o;
  wire [2:0] n1827_o;
  wire n1828_o;
  wire n1829_o;
  wire n1830_o;
  wire n1831_o;
  wire n1832_o;
  wire n1833_o;
  wire [2:0] n1834_o;
  wire n1835_o;
  wire n1836_o;
  wire n1837_o;
  wire n1838_o;
  wire n1839_o;
  wire n1840_o;
  wire [2:0] n1842_o;
  wire n1843_o;
  wire n1844_o;
  wire n1845_o;
  wire [2:0] n1846_o;
  wire n1847_o;
  wire n1848_o;
  wire n1849_o;
  wire [2:0] n1851_o;
  wire [2:0] n1852_o;
  wire n1853_o;
  wire n1854_o;
  wire n1857_o;
  wire n1858_o;
  wire [2:0] n1859_o;
  wire n1860_o;
  wire n1861_o;
  wire n1862_o;
  wire n1863_o;
  wire n1865_o;
  wire n1866_o;
  wire n1867_o;
  wire n1868_o;
  wire n1869_o;
  wire [2:0] n1871_o;
  wire [2:0] n1872_o;
  wire n1873_o;
  wire [2:0] n1874_o;
  wire [2:0] n1875_o;
  wire n1876_o;
  wire n1877_o;
  wire n1878_o;
  wire n1880_o;
  wire n1881_o;
  wire [2:0] n1882_o;
  wire n1883_o;
  wire n1884_o;
  wire n1885_o;
  wire [2:0] n1886_o;
  wire [2:0] n1887_o;
  wire n1888_o;
  wire n1889_o;
  wire n1890_o;
  wire n1892_o;
  wire n1894_o;
  wire [2:0] n1895_o;
  wire n1896_o;
  wire n1897_o;
  wire n1898_o;
  wire [2:0] n1899_o;
  wire [2:0] n1900_o;
  wire n1901_o;
  wire n1902_o;
  wire n1903_o;
  wire n1904_o;
  wire n1905_o;
  wire [2:0] n1906_o;
  wire n1907_o;
  wire n1908_o;
  wire n1910_o;
  wire n1912_o;
  wire n1913_o;
  wire n1914_o;
  wire n1915_o;
  wire n1916_o;
  wire n1917_o;
  wire n1918_o;
  wire n1919_o;
  wire n1920_o;
  wire n1921_o;
  wire n1922_o;
  wire n1923_o;
  wire n1924_o;
  wire n1925_o;
  wire n1926_o;
  wire n1927_o;
  wire n1928_o;
  wire [2:0] n1929_o;
  wire [2:0] n1930_o;
  wire n1931_o;
  wire n1932_o;
  wire n1933_o;
  wire n1934_o;
  wire n1935_o;
  wire n1936_o;
  wire [2:0] n1937_o;
  wire n1938_o;
  wire n1939_o;
  wire n1940_o;
  wire n1941_o;
  wire n1942_o;
  wire n1943_o;
  wire n1992_o;
  wire n1993_o;
  reg n1994_q;
  wire n1997_o;
  wire n1998_o;
  wire n1999_o;
  reg [7:0] n2001_q;
  reg [7:0] n2002_q;
  reg [7:0] n2003_q;
  reg [7:0] n2004_q;
  reg [7:0] n2005_q;
  reg [7:0] n2006_q;
  reg [15:0] n2007_q;
  reg [15:0] n2008_q;
  wire [15:0] n2009_o;
  wire [15:0] n2010_o;
  wire [15:0] n2011_o;
  wire [2:0] n2012_o;
  reg [2:0] n2013_q;
  wire [2:0] n2014_o;
  reg [2:0] n2015_q;
  wire [2:0] n2016_o;
  reg [2:0] n2017_q;
  reg n2018_q;
  reg [15:0] n2019_q;
  reg [7:0] n2020_q;
  reg [1:0] n2021_q;
  wire [15:0] n2022_o;
  reg [15:0] n2023_q;
  reg [2:0] n2024_q;
  reg [2:0] n2025_q;
  reg n2026_q;
  reg n2027_q;
  reg n2028_q;
  reg n2029_q;
  reg n2030_q;
  reg n2031_q;
  reg [1:0] n2032_q;
  reg [1:0] n2033_q;
  reg [2:0] n2034_q;
  reg n2035_q;
  reg n2036_q;
  reg n2037_q;
  reg n2038_q;
  reg n2039_q;
  wire n2040_o;
  reg n2041_q;
  wire [7:0] n2042_o;
  reg [7:0] n2043_q;
  wire [7:0] n2044_o;
  reg [7:0] n2045_q;
  reg [4:0] n2046_q;
  reg n2047_q;
  reg n2048_q;
  reg [3:0] n2049_q;
  reg n2050_q;
  reg n2051_q;
  reg [2:0] n2052_q;
  reg n2053_q;
  reg n2054_q;
  reg n2055_q;
  reg n2056_q;
  wire n2057_o;
  reg n2058_q;
  reg [15:0] n2059_q;
  reg [7:0] n2060_q;
  assign M1_n = n2056_q;
  assign IORQ = iorq_i;
  assign NoRead = mcode_n91;
  assign Write = mcode_n92;
  assign RFSH_n = n2058_q;
  assign HALT_n = n1685_o;
  assign BUSAK_n = n1686_o;
  assign A = n2059_q;
  assign DOUT = n2060_q;
  assign MC = mcycle;
  assign TS = tstate;
  assign IntCycle_n = n1687_o;
  assign IntE = inte_ff1;
  assign Stop = i_djnz;
  assign REGS = n27_o;
  /* T80.vhd:266:16  */
  assign acc = n2001_q; // (signal)
  /* T80.vhd:266:21  */
  assign f = n2002_q; // (signal)
  /* T80.vhd:267:16  */
  assign ap = n2003_q; // (signal)
  /* T80.vhd:267:20  */
  assign fp = n2004_q; // (signal)
  /* T80.vhd:268:16  */
  assign i = n2005_q; // (signal)
  /* T80.vhd:269:16  */
  assign r = n2006_q; // (signal)
  /* T80.vhd:270:16  */
  assign sp = n2007_q; // (signal)
  /* T80.vhd:270:20  */
  assign pc = n2008_q; // (signal)
  /* T80.vhd:272:16  */
  assign regdih = n1537_o; // (signal)
  /* T80.vhd:273:16  */
  assign regdil = n1538_o; // (signal)
  /* T80.vhd:274:16  */
  assign regbusa = n2009_o; // (signal)
  /* T80.vhd:275:16  */
  assign regbusb = n2010_o; // (signal)
  /* T80.vhd:276:16  */
  assign regbusc = n2011_o; // (signal)
  /* T80.vhd:277:16  */
  assign regaddra_r = n2013_q; // (signal)
  /* T80.vhd:278:16  */
  assign regaddra = n1381_o; // (signal)
  /* T80.vhd:279:16  */
  assign regaddrb_r = n2015_q; // (signal)
  /* T80.vhd:280:16  */
  assign regaddrb = n1417_o; // (signal)
  /* T80.vhd:281:16  */
  assign regaddrc = n2017_q; // (signal)
  /* T80.vhd:282:16  */
  assign regweh = n1503_o; // (signal)
  /* T80.vhd:283:16  */
  assign regwel = n1504_o; // (signal)
  /* T80.vhd:284:16  */
  assign alternate = n2018_q; // (signal)
  /* T80.vhd:287:16  */
  assign wz = n2019_q; // (signal)
  /* T80.vhd:288:16  */
  assign ir = n2020_q; // (signal)
  /* T80.vhd:289:16  */
  assign iset = n2021_q; // (signal)
  /* T80.vhd:290:16  */
  assign regbusa_r = n2023_q; // (signal)
  /* T80.vhd:292:16  */
  assign id16 = n1421_o; // (signal)
  /* T80.vhd:293:16  */
  assign save_mux = n225_o; // (signal)
  /* T80.vhd:295:16  */
  assign tstate = n2024_q; // (signal)
  /* T80.vhd:296:16  */
  assign mcycle = n2025_q; // (signal)
  /* T80.vhd:297:16  */
  assign inte_ff1 = n2026_q; // (signal)
  /* T80.vhd:298:16  */
  assign inte_ff2 = n2027_q; // (signal)
  /* T80.vhd:299:16  */
  assign halt_ff = n2028_q; // (signal)
  /* T80.vhd:300:16  */
  assign busreq_s = n2029_q; // (signal)
  /* T80.vhd:301:16  */
  assign busack = n2030_q; // (signal)
  /* T80.vhd:302:16  */
  assign clken = n198_o; // (signal)
  /* T80.vhd:303:16  */
  assign nmi_s = n2031_q; // (signal)
  /* T80.vhd:304:16  */
  assign istatus = n2032_q; // (signal)
  /* T80.vhd:306:16  */
  assign di_reg = DI; // (signal)
  /* T80.vhd:307:16  */
  assign t_res = n201_o; // (signal)
  /* T80.vhd:308:16  */
  assign xy_state = n2033_q; // (signal)
  /* T80.vhd:309:16  */
  assign pre_xy_f_m = n2034_q; // (signal)
  /* T80.vhd:310:16  */
  assign nextis_xy_fetch = n223_o; // (signal)
  /* T80.vhd:311:16  */
  assign xy_ind = n2035_q; // (signal)
  /* T80.vhd:312:16  */
  assign no_btr = n2036_q; // (signal)
  /* T80.vhd:313:16  */
  assign btr_r = n2037_q; // (signal)
  /* T80.vhd:314:16  */
  assign auto_wait = n1999_o; // (signal)
  /* T80.vhd:315:16  */
  assign auto_wait_t1 = n2038_q; // (signal)
  /* T80.vhd:316:16  */
  assign auto_wait_t2 = n2039_q; // (signal)
  /* T80.vhd:317:16  */
  assign incdecz = n2041_q; // (signal)
  /* T80.vhd:320:16  */
  assign busb = n2043_q; // (signal)
  /* T80.vhd:321:16  */
  assign busa = n2045_q; // (signal)
  /* T80.vhd:322:16  */
  assign alu_q = u_alu_n191; // (signal)
  /* T80.vhd:323:16  */
  assign f_out = u_alu_n192; // (signal)
  /* T80.vhd:326:16  */
  assign read_to_reg_r = n2046_q; // (signal)
  /* T80.vhd:327:16  */
  assign arith16_r = n2047_q; // (signal)
  /* T80.vhd:328:16  */
  assign z16_r = n2048_q; // (signal)
  /* T80.vhd:329:16  */
  assign alu_op_r = n2049_q; // (signal)
  /* T80.vhd:330:16  */
  assign save_alu_r = n2050_q; // (signal)
  /* T80.vhd:331:16  */
  assign preservec_r = n2051_q; // (signal)
  /* T80.vhd:332:16  */
  assign mcycles = n2052_q; // (signal)
  /* T80.vhd:335:16  */
  assign mcycles_d = mcode_n46; // (signal)
  /* T80.vhd:336:16  */
  assign tstates = mcode_n47; // (signal)
  /* T80.vhd:337:16  */
  assign intcycle = n2053_q; // (signal)
  /* T80.vhd:338:16  */
  assign nmicycle = n2054_q; // (signal)
  /* T80.vhd:339:16  */
  assign inc_pc = mcode_n49; // (signal)
  /* T80.vhd:340:16  */
  assign inc_wz = mcode_n50; // (signal)
  /* T80.vhd:341:16  */
  assign incdec_16 = mcode_n51; // (signal)
  /* T80.vhd:342:16  */
  assign prefix = mcode_n48; // (signal)
  /* T80.vhd:343:16  */
  assign read_to_acc = mcode_n53; // (signal)
  /* T80.vhd:344:16  */
  assign read_to_reg = mcode_n52; // (signal)
  /* T80.vhd:345:16  */
  assign set_busb_to = mcode_n55; // (signal)
  /* T80.vhd:346:16  */
  assign set_busa_to = mcode_n54; // (signal)
  /* T80.vhd:347:16  */
  assign alu_op = mcode_n56; // (signal)
  /* T80.vhd:348:16  */
  assign save_alu = mcode_n57; // (signal)
  /* T80.vhd:349:16  */
  assign preservec = mcode_n58; // (signal)
  /* T80.vhd:350:16  */
  assign arith16 = mcode_n59; // (signal)
  /* T80.vhd:351:16  */
  assign set_addr_to = mcode_n60; // (signal)
  /* T80.vhd:352:16  */
  assign jump = mcode_n62; // (signal)
  /* T80.vhd:353:16  */
  assign jumpe = mcode_n63; // (signal)
  /* T80.vhd:354:16  */
  assign jumpxy = mcode_n64; // (signal)
  /* T80.vhd:355:16  */
  assign call = mcode_n65; // (signal)
  /* T80.vhd:356:16  */
  assign rstp = mcode_n66; // (signal)
  /* T80.vhd:357:16  */
  assign ldz = mcode_n67; // (signal)
  /* T80.vhd:358:16  */
  assign ldw = mcode_n68; // (signal)
  /* T80.vhd:359:16  */
  assign ldsphl = mcode_n69; // (signal)
  /* T80.vhd:360:16  */
  assign iorq_i = mcode_n61; // (signal)
  /* T80.vhd:361:16  */
  assign special_ld = mcode_n70; // (signal)
  /* T80.vhd:362:16  */
  assign exchangedh = mcode_n71; // (signal)
  /* T80.vhd:363:16  */
  assign exchangerp = mcode_n72; // (signal)
  /* T80.vhd:364:16  */
  assign exchangeaf = mcode_n73; // (signal)
  /* T80.vhd:365:16  */
  assign exchangers = mcode_n74; // (signal)
  /* T80.vhd:366:16  */
  assign i_djnz = mcode_n75; // (signal)
  /* T80.vhd:367:16  */
  assign i_cpl = mcode_n76; // (signal)
  /* T80.vhd:368:16  */
  assign i_ccf = mcode_n77; // (signal)
  /* T80.vhd:369:16  */
  assign i_scf = mcode_n78; // (signal)
  /* T80.vhd:370:16  */
  assign i_retn = mcode_n79; // (signal)
  /* T80.vhd:371:16  */
  assign i_bt = mcode_n80; // (signal)
  /* T80.vhd:372:16  */
  assign i_bc = mcode_n81; // (signal)
  /* T80.vhd:373:16  */
  assign i_btr = mcode_n82; // (signal)
  /* T80.vhd:374:16  */
  assign i_rld = mcode_n83; // (signal)
  /* T80.vhd:375:16  */
  assign i_rrd = mcode_n84; // (signal)
  /* T80.vhd:376:16  */
  assign i_rxdd = n2055_q; // (signal)
  /* T80.vhd:377:16  */
  assign i_inrc = mcode_n85; // (signal)
  /* T80.vhd:378:16  */
  assign setwz = mcode_n86; // (signal)
  /* T80.vhd:379:16  */
  assign setdi = mcode_n87; // (signal)
  /* T80.vhd:380:16  */
  assign setei = mcode_n88; // (signal)
  /* T80.vhd:381:16  */
  assign imode = mcode_n89; // (signal)
  /* T80.vhd:382:16  */
  assign halt = mcode_n90; // (signal)
  /* T80.vhd:383:16  */
  assign xybit_undoc = mcode_n93; // (signal)
  /* T80.vhd:384:16  */
  assign dor = u_regs_n1546; // (signal)
  /* T80.vhd:388:26  */
  assign n15_o = {inte_ff2, inte_ff1};
  /* T80.vhd:388:37  */
  assign n16_o = {n15_o, istatus};
  /* T80.vhd:388:47  */
  assign n17_o = {n16_o, dor};
  /* T80.vhd:388:53  */
  assign n18_o = {n17_o, pc};
  /* T80.vhd:388:76  */
  assign n19_o = {n18_o, sp};
  /* T80.vhd:388:99  */
  assign n20_o = {n19_o, r};
  /* T80.vhd:388:121  */
  assign n21_o = {n20_o, i};
  /* T80.vhd:388:125  */
  assign n22_o = {n21_o, fp};
  /* T80.vhd:388:130  */
  assign n23_o = {n22_o, ap};
  /* T80.vhd:388:135  */
  assign n24_o = {n23_o, f};
  /* T80.vhd:388:139  */
  assign n25_o = {n24_o, acc};
  /* T80.vhd:388:160  */
  assign n26_o = ~alternate;
  /* T80.vhd:388:145  */
  assign n27_o = n26_o ? n25_o : n45_o;
  /* T80.vhd:389:40  */
  assign n28_o = {inte_ff2, inte_ff1};
  /* T80.vhd:389:51  */
  assign n29_o = {n28_o, istatus};
  /* T80.vhd:389:66  */
  assign n30_o = dor[127:112];
  /* T80.vhd:389:61  */
  assign n31_o = {n29_o, n30_o};
  /* T80.vhd:389:88  */
  assign n32_o = dor[47:0];
  /* T80.vhd:389:83  */
  assign n33_o = {n31_o, n32_o};
  /* T80.vhd:389:107  */
  assign n34_o = dor[63:48];
  /* T80.vhd:389:102  */
  assign n35_o = {n33_o, n34_o};
  /* T80.vhd:389:127  */
  assign n36_o = dor[111:64];
  /* T80.vhd:389:122  */
  assign n37_o = {n35_o, n36_o};
  /* T80.vhd:389:143  */
  assign n38_o = {n37_o, pc};
  /* T80.vhd:390:70  */
  assign n39_o = {n38_o, sp};
  /* T80.vhd:390:93  */
  assign n40_o = {n39_o, r};
  /* T80.vhd:390:115  */
  assign n41_o = {n40_o, i};
  /* T80.vhd:390:119  */
  assign n42_o = {n41_o, fp};
  /* T80.vhd:390:124  */
  assign n43_o = {n42_o, ap};
  /* T80.vhd:390:129  */
  assign n44_o = {n43_o, f};
  /* T80.vhd:390:133  */
  assign n45_o = {n44_o, acc};
  /* T80.vhd:411:40  */
  assign mcode_n46 = mcode_mcycles; // (signal)
  /* T80.vhd:412:40  */
  assign mcode_n47 = mcode_tstates; // (signal)
  /* T80.vhd:413:40  */
  assign mcode_n48 = mcode_prefix; // (signal)
  /* T80.vhd:414:40  */
  assign mcode_n49 = mcode_inc_pc; // (signal)
  /* T80.vhd:415:40  */
  assign mcode_n50 = mcode_inc_wz; // (signal)
  /* T80.vhd:416:40  */
  assign mcode_n51 = mcode_incdec_16; // (signal)
  /* T80.vhd:418:40  */
  assign mcode_n52 = mcode_read_to_reg; // (signal)
  /* T80.vhd:417:40  */
  assign mcode_n53 = mcode_read_to_acc; // (signal)
  /* T80.vhd:420:40  */
  assign mcode_n54 = mcode_set_busa_to; // (signal)
  /* T80.vhd:419:40  */
  assign mcode_n55 = mcode_set_busb_to; // (signal)
  /* T80.vhd:421:40  */
  assign mcode_n56 = mcode_alu_op; // (signal)
  /* T80.vhd:422:40  */
  assign mcode_n57 = mcode_save_alu; // (signal)
  /* T80.vhd:423:40  */
  assign mcode_n58 = mcode_preservec; // (signal)
  /* T80.vhd:424:40  */
  assign mcode_n59 = mcode_arith16; // (signal)
  /* T80.vhd:425:40  */
  assign mcode_n60 = mcode_set_addr_to; // (signal)
  /* T80.vhd:426:40  */
  assign mcode_n61 = mcode_iorq; // (signal)
  /* T80.vhd:427:40  */
  assign mcode_n62 = mcode_jump; // (signal)
  /* T80.vhd:428:40  */
  assign mcode_n63 = mcode_jumpe; // (signal)
  /* T80.vhd:429:40  */
  assign mcode_n64 = mcode_jumpxy; // (signal)
  /* T80.vhd:430:40  */
  assign mcode_n65 = mcode_call; // (signal)
  /* T80.vhd:431:40  */
  assign mcode_n66 = mcode_rstp; // (signal)
  /* T80.vhd:432:40  */
  assign mcode_n67 = mcode_ldz; // (signal)
  /* T80.vhd:433:40  */
  assign mcode_n68 = mcode_ldw; // (signal)
  /* T80.vhd:434:40  */
  assign mcode_n69 = mcode_ldsphl; // (signal)
  /* T80.vhd:435:40  */
  assign mcode_n70 = mcode_special_ld; // (signal)
  /* T80.vhd:436:40  */
  assign mcode_n71 = mcode_exchangedh; // (signal)
  /* T80.vhd:437:40  */
  assign mcode_n72 = mcode_exchangerp; // (signal)
  /* T80.vhd:438:40  */
  assign mcode_n73 = mcode_exchangeaf; // (signal)
  /* T80.vhd:439:40  */
  assign mcode_n74 = mcode_exchangers; // (signal)
  /* T80.vhd:440:40  */
  assign mcode_n75 = mcode_i_djnz; // (signal)
  /* T80.vhd:441:40  */
  assign mcode_n76 = mcode_i_cpl; // (signal)
  /* T80.vhd:442:40  */
  assign mcode_n77 = mcode_i_ccf; // (signal)
  /* T80.vhd:443:40  */
  assign mcode_n78 = mcode_i_scf; // (signal)
  /* T80.vhd:444:40  */
  assign mcode_n79 = mcode_i_retn; // (signal)
  /* T80.vhd:445:40  */
  assign mcode_n80 = mcode_i_bt; // (signal)
  /* T80.vhd:446:40  */
  assign mcode_n81 = mcode_i_bc; // (signal)
  /* T80.vhd:447:40  */
  assign mcode_n82 = mcode_i_btr; // (signal)
  /* T80.vhd:448:40  */
  assign mcode_n83 = mcode_i_rld; // (signal)
  /* T80.vhd:449:40  */
  assign mcode_n84 = mcode_i_rrd; // (signal)
  /* T80.vhd:450:40  */
  assign mcode_n85 = mcode_i_inrc; // (signal)
  /* T80.vhd:451:40  */
  assign mcode_n86 = mcode_setwz; // (signal)
  /* T80.vhd:452:40  */
  assign mcode_n87 = mcode_setdi; // (signal)
  /* T80.vhd:453:40  */
  assign mcode_n88 = mcode_setei; // (signal)
  /* T80.vhd:454:40  */
  assign mcode_n89 = mcode_imode; // (signal)
  /* T80.vhd:455:40  */
  assign mcode_n90 = mcode_halt; // (signal)
  /* T80.vhd:456:40  */
  assign mcode_n91 = mcode_noread; // (signal)
  /* T80.vhd:457:40  */
  assign mcode_n92 = mcode_write; // (signal)
  /* T80.vhd:458:40  */
  assign mcode_n93 = mcode_xybit_undoc; // (signal)
  /* T80.vhd:392:9  */
  t80_mcode_0_0_1_2_3_4_5_6_7 mcode (
    .ir(ir),
    .iset(iset),
    .mcycle(mcycle),
    .f(f),
    .nmicycle(nmicycle),
    .intcycle(intcycle),
    .xy_state(xy_state),
    .mode_sel(Mode_Sel),
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
  /* T80.vhd:478:38  */
  assign n190_o = ir[5:0];
  /* T80.vhd:483:36  */
  assign u_alu_n191 = u_alu_q; // (signal)
  /* T80.vhd:484:36  */
  assign u_alu_n192 = u_alu_f_out; // (signal)
  /* T80.vhd:461:9  */
  t80_alu_0_0_1_2_3_4_5_6_7 u_alu (
    .arith16(arith16_r),
    .z16(z16_r),
    .wz(wz),
    .xy_state(xy_state),
    .alu_op(alu_op_r),
    .ir(n190_o),
    .iset(iset),
    .busa(busa),
    .busb(busb),
    .f_in(f),
    .mode_sel(Mode_Sel),
    .q(u_alu_q),
    .f_out(u_alu_f_out));
  /* T80.vhd:487:26  */
  assign n197_o = ~busack;
  /* T80.vhd:487:22  */
  assign n198_o = CEN & n197_o;
  /* T80.vhd:489:34  */
  assign n200_o = tstate == tstates;
  /* T80.vhd:489:22  */
  assign n201_o = n200_o ? 1'b1 : 1'b0;
  /* T80.vhd:491:46  */
  assign n205_o = xy_state != 2'b00;
  /* T80.vhd:491:65  */
  assign n206_o = ~xy_ind;
  /* T80.vhd:491:54  */
  assign n207_o = n206_o & n205_o;
  /* T80.vhd:492:71  */
  assign n209_o = set_addr_to == 3'b010;
  /* T80.vhd:493:65  */
  assign n211_o = mcycle == 3'b001;
  /* T80.vhd:493:80  */
  assign n213_o = ir == 8'b11001011;
  /* T80.vhd:493:73  */
  assign n214_o = n213_o & n211_o;
  /* T80.vhd:492:78  */
  assign n215_o = n209_o | n214_o;
  /* T80.vhd:494:65  */
  assign n217_o = mcycle == 3'b001;
  /* T80.vhd:494:80  */
  assign n219_o = ir == 8'b00110110;
  /* T80.vhd:494:73  */
  assign n220_o = n219_o & n217_o;
  /* T80.vhd:493:94  */
  assign n221_o = n215_o | n220_o;
  /* T80.vhd:491:71  */
  assign n222_o = n221_o & n207_o;
  /* T80.vhd:491:32  */
  assign n223_o = n222_o ? 1'b1 : 1'b0;
  /* T80.vhd:496:26  */
  assign n225_o = exchangerp ? busb : n227_o;
  /* T80.vhd:497:40  */
  assign n226_o = ~save_alu_r;
  /* T80.vhd:496:48  */
  assign n227_o = n226_o ? di_reg : alu_q;
  /* T80.vhd:504:28  */
  assign n232_o = ~RESET_n;
  /* T80.vhd:537:43  */
  assign n234_o = DIR[7:0];
  /* T80.vhd:538:43  */
  assign n235_o = DIR[15:8];
  /* T80.vhd:539:43  */
  assign n236_o = DIR[23:16];
  /* T80.vhd:540:43  */
  assign n237_o = DIR[31:24];
  /* T80.vhd:541:43  */
  assign n238_o = DIR[39:32];
  /* T80.vhd:542:52  */
  assign n239_o = DIR[47:40];
  /* T80.vhd:543:52  */
  assign n240_o = DIR[63:48];
  /* T80.vhd:544:52  */
  assign n241_o = DIR[79:64];
  /* T80.vhd:545:43  */
  assign n242_o = DIR[79:64];
  /* T80.vhd:546:47  */
  assign n243_o = DIR[209:208];
  /* T80.vhd:555:42  */
  assign n245_o = imode != 2'b11;
  /* T80.vhd:548:25  */
  assign n246_o = n1151_o ? imode : istatus;
  /* T80.vhd:561:41  */
  assign n248_o = iset == 2'b10;
  /* T80.vhd:561:58  */
  assign n249_o = alu_op[2];
  /* T80.vhd:561:62  */
  assign n250_o = ~n249_o;
  /* T80.vhd:561:48  */
  assign n251_o = n250_o & n248_o;
  /* T80.vhd:561:78  */
  assign n252_o = alu_op[0];
  /* T80.vhd:561:68  */
  assign n253_o = n252_o & n251_o;
  /* T80.vhd:561:99  */
  assign n255_o = mcycle == 3'b011;
  /* T80.vhd:561:88  */
  assign n256_o = n255_o & n253_o;
  /* T80.vhd:561:33  */
  assign n259_o = n256_o ? 1'b1 : 1'b0;
  /* T80.vhd:567:44  */
  assign n261_o = mcycle == 3'b001;
  /* T80.vhd:567:62  */
  assign n262_o = tstate[2];
  /* T80.vhd:567:66  */
  assign n263_o = ~n262_o;
  /* T80.vhd:567:52  */
  assign n264_o = n263_o & n261_o;
  /* T80.vhd:570:51  */
  assign n266_o = tstate == 3'b010;
  /* T80.vhd:570:55  */
  assign n267_o = WAIT_n & n266_o;
  /* T80.vhd:571:61  */
  assign n268_o = {30'b0, Mode_Sel};  //  uext
  /* T80.vhd:571:61  */
  assign n270_o = $signed(n268_o) < $signed(32'b00000000000000000000000000000010);
  /* T80.vhd:574:75  */
  assign n271_o = r[6:0];
  /* T80.vhd:574:88  */
  assign n273_o = n271_o + 7'b0000001;
  assign n274_o = {i, r};
  /* T80.vhd:570:41  */
  assign n275_o = n328_o ? n274_o : n2059_q;
  assign n276_o = r[6:0];
  /* T80.vhd:567:33  */
  assign n277_o = n685_o ? n273_o : n276_o;
  /* T80.vhd:577:57  */
  assign n278_o = ~jump;
  /* T80.vhd:577:72  */
  assign n279_o = ~call;
  /* T80.vhd:577:63  */
  assign n280_o = n279_o & n278_o;
  /* T80.vhd:577:91  */
  assign n281_o = ~nmicycle;
  /* T80.vhd:577:78  */
  assign n282_o = n281_o & n280_o;
  /* T80.vhd:577:110  */
  assign n283_o = ~intcycle;
  /* T80.vhd:577:97  */
  assign n284_o = n283_o & n282_o;
  /* T80.vhd:577:139  */
  assign n285_o = halt_ff | halt;
  /* T80.vhd:577:120  */
  assign n286_o = ~n285_o;
  /* T80.vhd:577:116  */
  assign n287_o = n286_o & n284_o;
  /* T80.vhd:578:66  */
  assign n289_o = pc + 16'b0000000000000001;
  /* T80.vhd:570:41  */
  assign n290_o = n331_o ? n289_o : pc;
  /* T80.vhd:581:79  */
  assign n292_o = istatus == 2'b01;
  /* T80.vhd:581:67  */
  assign n293_o = n292_o & intcycle;
  /* T80.vhd:583:100  */
  assign n295_o = istatus == 2'b10;
  /* T80.vhd:583:88  */
  assign n296_o = n295_o & intcycle;
  /* T80.vhd:583:69  */
  assign n297_o = halt_ff | n296_o;
  /* T80.vhd:583:108  */
  assign n298_o = n297_o | nmicycle;
  /* T80.vhd:583:49  */
  assign n300_o = n298_o ? 8'b00000000 : DInst;
  /* T80.vhd:581:49  */
  assign n302_o = n293_o ? 8'b11111111 : n300_o;
  /* T80.vhd:590:59  */
  assign n304_o = prefix != 2'b00;
  /* T80.vhd:591:67  */
  assign n306_o = prefix == 2'b11;
  /* T80.vhd:592:70  */
  assign n307_o = ir[5];
  /* T80.vhd:592:65  */
  assign n310_o = n307_o ? 2'b10 : 2'b01;
  /* T80.vhd:598:75  */
  assign n312_o = prefix == 2'b10;
  /* T80.vhd:598:65  */
  assign n314_o = n312_o ? 2'b00 : xy_state;
  /* T80.vhd:598:65  */
  assign n316_o = n312_o ? 1'b0 : xy_ind;
  /* T80.vhd:591:57  */
  assign n318_o = n306_o ? 2'b00 : prefix;
  /* T80.vhd:591:57  */
  assign n319_o = n306_o ? n310_o : n314_o;
  /* T80.vhd:591:57  */
  assign n320_o = n306_o ? xy_ind : n316_o;
  /* T80.vhd:590:49  */
  assign n322_o = n304_o ? n318_o : 2'b00;
  /* T80.vhd:590:49  */
  assign n325_o = n304_o ? n319_o : 2'b00;
  /* T80.vhd:590:49  */
  assign n327_o = n304_o ? n320_o : 1'b0;
  /* T80.vhd:570:41  */
  assign n328_o = n270_o & n267_o;
  /* T80.vhd:570:41  */
  assign n330_o = n270_o & n267_o;
  /* T80.vhd:570:41  */
  assign n331_o = n287_o & n267_o;
  /* T80.vhd:570:41  */
  assign n332_o = n267_o ? n302_o : ir;
  /* T80.vhd:570:41  */
  assign n333_o = n267_o ? n322_o : iset;
  /* T80.vhd:548:25  */
  assign n334_o = n1152_o ? n325_o : xy_state;
  /* T80.vhd:570:41  */
  assign n335_o = n267_o ? n327_o : xy_ind;
  /* T80.vhd:613:51  */
  assign n337_o = mcycle == 3'b110;
  /* T80.vhd:615:59  */
  assign n339_o = prefix == 2'b01;
  /* T80.vhd:613:41  */
  assign n341_o = n342_o ? 2'b01 : iset;
  /* T80.vhd:613:41  */
  assign n342_o = n339_o & n337_o;
  /* T80.vhd:613:41  */
  assign n344_o = n337_o ? 1'b1 : xy_ind;
  /* T80.vhd:621:64  */
  assign n345_o = i_bt | i_bc;
  /* T80.vhd:621:72  */
  assign n346_o = n345_o | i_btr;
  /* T80.vhd:621:86  */
  assign n347_o = ~no_btr;
  /* T80.vhd:621:82  */
  assign n348_o = n346_o & n347_o;
  /* T80.vhd:624:76  */
  assign n349_o = wz[7:0];
  /* T80.vhd:626:86  */
  assign n350_o = wz[7:0];
  /* T80.vhd:630:66  */
  assign n351_o = call | rstp;
  /* T80.vhd:633:62  */
  assign n352_o = mcycle == mcycles;
  /* T80.vhd:633:72  */
  assign n353_o = nmicycle & n352_o;
  /* T80.vhd:636:62  */
  assign n355_o = mcycle == 3'b011;
  /* T80.vhd:636:70  */
  assign n356_o = intcycle & n355_o;
  /* T80.vhd:636:101  */
  assign n358_o = istatus == 2'b10;
  /* T80.vhd:636:89  */
  assign n359_o = n358_o & n356_o;
  /* T80.vhd:638:76  */
  assign n360_o = wz[7:0];
  /* T80.vhd:640:86  */
  assign n361_o = wz[7:0];
  /* T80.vhd:644:77  */
  assign n363_o = xy_state == 2'b00;
  /* T80.vhd:647:73  */
  assign n364_o = nextis_xy_fetch ? pc : wz;
  /* T80.vhd:644:65  */
  assign n365_o = n363_o ? regbusc : n364_o;
  /* T80.vhd:643:57  */
  assign n367_o = set_addr_to == 3'b010;
  /* T80.vhd:654:77  */
  assign n368_o = {30'b0, Mode_Sel};  //  uext
  /* T80.vhd:654:77  */
  assign n370_o = n368_o == 32'b00000000000000000000000000000011;
  /* T80.vhd:657:80  */
  assign n372_o = {30'b0, Mode_Sel};  //  uext
  /* T80.vhd:657:80  */
  assign n374_o = n372_o == 32'b00000000000000000000000000000010;
  /* T80.vhd:657:65  */
  assign n375_o = n374_o ? di_reg : acc;
  /* T80.vhd:654:65  */
  assign n376_o = n370_o ? 8'b11111111 : n375_o;
  /* T80.vhd:664:76  */
  assign n377_o = {acc, di_reg};
  /* T80.vhd:664:86  */
  assign n380_o = n377_o + 16'b0000000000000001;
  /* T80.vhd:653:57  */
  assign n382_o = set_addr_to == 3'b100;
  /* T80.vhd:665:57  */
  assign n384_o = set_addr_to == 3'b101;
  /* T80.vhd:668:77  */
  assign n385_o = {30'b0, Mode_Sel};  //  uext
  /* T80.vhd:668:77  */
  assign n387_o = n385_o == 32'b00000000000000000000000000000011;
  /* T80.vhd:668:81  */
  assign n388_o = iorq_i & n387_o;
  /* T80.vhd:671:97  */
  assign n390_o = regbusc[7:0];
  /* T80.vhd:674:82  */
  assign n392_o = setwz == 2'b01;
  /* T80.vhd:675:95  */
  assign n395_o = regbusc + 16'b0000000000000001;
  /* T80.vhd:674:73  */
  assign n396_o = n392_o ? n395_o : wz;
  /* T80.vhd:677:82  */
  assign n398_o = setwz == 2'b10;
  /* T80.vhd:678:106  */
  assign n399_o = regbusc[7:0];
  /* T80.vhd:678:119  */
  assign n402_o = n399_o + 8'b00000001;
  assign n403_o = {acc, n402_o};
  /* T80.vhd:677:73  */
  assign n404_o = n398_o ? n403_o : n396_o;
  assign n405_o = {8'b11111111, n390_o};
  /* T80.vhd:668:65  */
  assign n406_o = n388_o ? n405_o : regbusc;
  /* T80.vhd:668:65  */
  assign n407_o = n388_o ? wz : n404_o;
  /* T80.vhd:667:57  */
  assign n409_o = set_addr_to == 3'b000;
  /* T80.vhd:684:74  */
  assign n411_o = setwz == 2'b10;
  /* T80.vhd:685:98  */
  assign n412_o = regbusc[7:0];
  /* T80.vhd:685:111  */
  assign n415_o = n412_o + 8'b00000001;
  assign n416_o = {acc, n415_o};
  /* T80.vhd:684:65  */
  assign n417_o = n411_o ? n416_o : wz;
  /* T80.vhd:682:57  */
  assign n419_o = set_addr_to == 3'b001;
  /* T80.vhd:690:108  */
  assign n421_o = wz + 16'b0000000000000001;
  /* T80.vhd:693:92  */
  assign n422_o = wz[7:0];
  /* T80.vhd:694:82  */
  assign n424_o = setwz == 2'b10;
  /* T80.vhd:695:101  */
  assign n425_o = wz[7:0];
  /* T80.vhd:695:114  */
  assign n428_o = n425_o + 8'b00000001;
  assign n429_o = {acc, n428_o};
  /* T80.vhd:694:73  */
  assign n430_o = n424_o ? n429_o : wz;
  assign n431_o = {di_reg, n422_o};
  /* T80.vhd:689:65  */
  assign n432_o = inc_wz ? n421_o : n431_o;
  /* T80.vhd:689:65  */
  assign n433_o = inc_wz ? wz : n430_o;
  /* T80.vhd:688:57  */
  assign n435_o = set_addr_to == 3'b110;
  assign n436_o = {n435_o, n419_o, n409_o, n384_o, n382_o, n367_o};
  assign n437_o = n365_o[7:0];
  assign n438_o = sp[7:0];
  assign n439_o = n406_o[7:0];
  assign n440_o = regbusc[7:0];
  assign n441_o = n432_o[7:0];
  assign n442_o = pc[7:0];
  /* T80.vhd:642:57  */
  always @*
    case (n436_o)
      6'b100000: n443_o = n441_o;
      6'b010000: n443_o = n440_o;
      6'b001000: n443_o = n439_o;
      6'b000100: n443_o = n438_o;
      6'b000010: n443_o = di_reg;
      6'b000001: n443_o = n437_o;
      default: n443_o = n442_o;
    endcase
  assign n444_o = n365_o[15:8];
  assign n445_o = sp[15:8];
  assign n446_o = n406_o[15:8];
  assign n447_o = regbusc[15:8];
  assign n448_o = n432_o[15:8];
  assign n449_o = pc[15:8];
  /* T80.vhd:642:57  */
  always @*
    case (n436_o)
      6'b100000: n450_o = n448_o;
      6'b010000: n450_o = n447_o;
      6'b001000: n450_o = n446_o;
      6'b000100: n450_o = n445_o;
      6'b000010: n450_o = n376_o;
      6'b000001: n450_o = n444_o;
      default: n450_o = n449_o;
    endcase
  /* T80.vhd:642:57  */
  always @*
    case (n436_o)
      6'b100000: n451_o = n433_o;
      6'b010000: n451_o = n417_o;
      6'b001000: n451_o = n407_o;
      6'b000100: n451_o = wz;
      6'b000010: n451_o = n380_o;
      6'b000001: n451_o = wz;
      default: n451_o = wz;
    endcase
  assign n452_o = {n450_o, n443_o};
  assign n453_o = {i, n360_o};
  /* T80.vhd:636:49  */
  assign n454_o = n359_o ? n453_o : n452_o;
  assign n455_o = {i, n361_o};
  /* T80.vhd:636:49  */
  assign n456_o = n359_o ? n455_o : pc;
  /* T80.vhd:636:49  */
  assign n457_o = n359_o ? wz : n451_o;
  /* T80.vhd:633:49  */
  assign n459_o = n353_o ? 16'b0000000001100110 : n454_o;
  /* T80.vhd:633:49  */
  assign n461_o = n353_o ? 16'b0000000001100110 : n456_o;
  /* T80.vhd:633:49  */
  assign n462_o = n353_o ? wz : n457_o;
  /* T80.vhd:630:49  */
  assign n463_o = n351_o ? wz : n459_o;
  /* T80.vhd:630:49  */
  assign n464_o = n351_o ? wz : n461_o;
  /* T80.vhd:630:49  */
  assign n465_o = n351_o ? wz : n462_o;
  /* T80.vhd:627:49  */
  assign n466_o = jumpxy ? regbusc : n463_o;
  /* T80.vhd:627:49  */
  assign n467_o = jumpxy ? regbusc : n464_o;
  /* T80.vhd:627:49  */
  assign n468_o = jumpxy ? wz : n465_o;
  assign n469_o = {di_reg, n349_o};
  /* T80.vhd:622:49  */
  assign n470_o = jump ? n469_o : n466_o;
  assign n471_o = {di_reg, n350_o};
  /* T80.vhd:622:49  */
  assign n472_o = jump ? n471_o : n467_o;
  /* T80.vhd:622:49  */
  assign n473_o = jump ? wz : n468_o;
  /* T80.vhd:704:58  */
  assign n475_o = setwz == 2'b11;
  /* T80.vhd:704:49  */
  assign n476_o = n475_o ? id16 : n473_o;
  /* T80.vhd:713:64  */
  assign n477_o = ~acc;
  /* T80.vhd:714:77  */
  assign n478_o = acc[5];
  /* T80.vhd:714:70  */
  assign n479_o = ~n478_o;
  /* T80.vhd:716:77  */
  assign n481_o = acc[3];
  /* T80.vhd:716:70  */
  assign n482_o = ~n481_o;
  /* T80.vhd:620:41  */
  assign n484_o = n512_o ? n477_o : acc;
  assign n485_o = {n479_o, 1'b1, n482_o};
  assign n486_o = f[1];
  /* T80.vhd:711:49  */
  assign n487_o = i_cpl ? 1'b1 : n486_o;
  /* T80.vhd:721:75  */
  assign n490_o = f[0];
  /* T80.vhd:721:70  */
  assign n491_o = ~n490_o;
  /* T80.vhd:722:73  */
  assign n492_o = acc[5];
  /* T80.vhd:723:71  */
  assign n493_o = f[0];
  /* T80.vhd:724:73  */
  assign n494_o = acc[3];
  assign n496_o = {1'b0, n491_o};
  assign n497_o = {n492_o, n493_o, n494_o};
  assign n498_o = f[0];
  assign n499_o = {n487_o, n498_o};
  /* T80.vhd:719:49  */
  assign n500_o = i_ccf ? n496_o : n499_o;
  /* T80.vhd:730:73  */
  assign n503_o = acc[5];
  /* T80.vhd:732:73  */
  assign n505_o = acc[3];
  assign n507_o = {1'b0, 1'b1};
  assign n508_o = {n503_o, 1'b0, n505_o};
  /* T80.vhd:727:49  */
  assign n509_o = i_scf ? n507_o : n500_o;
  /* T80.vhd:620:41  */
  assign n511_o = t_res ? n470_o : n2059_q;
  /* T80.vhd:620:41  */
  assign n512_o = i_cpl & t_res;
  assign n513_o = f[1:0];
  /* T80.vhd:620:41  */
  assign n514_o = t_res ? n509_o : n513_o;
  /* T80.vhd:620:41  */
  assign n517_o = t_res ? n472_o : pc;
  /* T80.vhd:620:41  */
  assign n518_o = t_res ? n476_o : wz;
  /* T80.vhd:620:41  */
  assign n519_o = t_res ? n348_o : btr_r;
  /* T80.vhd:620:41  */
  assign n521_o = t_res ? alu_op : 4'b0000;
  /* T80.vhd:620:41  */
  assign n523_o = t_res ? save_alu : 1'b0;
  /* T80.vhd:737:52  */
  assign n525_o = tstate == 3'b010;
  /* T80.vhd:737:56  */
  assign n526_o = i_btr & n525_o;
  /* T80.vhd:737:78  */
  assign n527_o = ir[0];
  /* T80.vhd:737:72  */
  assign n528_o = n527_o & n526_o;
  /* T80.vhd:737:100  */
  assign n530_o = tstate == 3'b001;
  /* T80.vhd:737:104  */
  assign n531_o = i_btr & n530_o;
  /* T80.vhd:737:126  */
  assign n532_o = ir[0];
  /* T80.vhd:737:130  */
  assign n533_o = ~n532_o;
  /* T80.vhd:737:120  */
  assign n534_o = n533_o & n531_o;
  /* T80.vhd:737:89  */
  assign n535_o = n528_o | n534_o;
  /* T80.vhd:738:61  */
  assign n537_o = {1'b0, di_reg};
  /* T80.vhd:738:101  */
  assign n538_o = id16[7:0];
  /* T80.vhd:738:78  */
  assign n540_o = {1'b0, n538_o};
  /* T80.vhd:738:71  */
  assign n541_o = n537_o + n540_o;
  /* T80.vhd:739:68  */
  assign n542_o = di_reg[7];
  /* T80.vhd:740:65  */
  assign n543_o = n541_o[8];
  /* T80.vhd:741:65  */
  assign n544_o = n541_o[8];
  /* T80.vhd:742:61  */
  assign n546_o = n541_o & 9'b000000111;
  /* T80.vhd:742:88  */
  assign n548_o = {1'b0, busa};
  /* T80.vhd:742:80  */
  assign n549_o = n546_o ^ n548_o;
  /* T80.vhd:743:70  */
  assign n550_o = n549_o[0];
  /* T80.vhd:743:81  */
  assign n551_o = n549_o[1];
  /* T80.vhd:743:74  */
  assign n552_o = n550_o ^ n551_o;
  /* T80.vhd:743:92  */
  assign n553_o = n549_o[2];
  /* T80.vhd:743:85  */
  assign n554_o = n552_o ^ n553_o;
  /* T80.vhd:743:103  */
  assign n555_o = n549_o[3];
  /* T80.vhd:743:96  */
  assign n556_o = n554_o ^ n555_o;
  /* T80.vhd:743:114  */
  assign n557_o = n549_o[4];
  /* T80.vhd:743:107  */
  assign n558_o = n556_o ^ n557_o;
  /* T80.vhd:743:125  */
  assign n559_o = n549_o[5];
  /* T80.vhd:743:118  */
  assign n560_o = n558_o ^ n559_o;
  /* T80.vhd:743:136  */
  assign n561_o = n549_o[6];
  /* T80.vhd:743:129  */
  assign n562_o = n560_o ^ n561_o;
  /* T80.vhd:743:147  */
  assign n563_o = n549_o[7];
  /* T80.vhd:743:140  */
  assign n564_o = n562_o ^ n563_o;
  /* T80.vhd:743:62  */
  assign n565_o = ~n564_o;
  assign n566_o = {n565_o, n542_o, n543_o};
  assign n567_o = f[2];
  assign n568_o = {n567_o, n514_o};
  /* T80.vhd:737:41  */
  assign n569_o = n535_o ? n566_o : n568_o;
  assign n570_o = f[4];
  assign n571_o = f[4];
  assign n572_o = n485_o[1];
  /* T80.vhd:711:49  */
  assign n573_o = i_cpl ? n572_o : n571_o;
  assign n574_o = n497_o[1];
  /* T80.vhd:719:49  */
  assign n575_o = i_ccf ? n574_o : n573_o;
  assign n576_o = n508_o[1];
  /* T80.vhd:727:49  */
  assign n577_o = i_scf ? n576_o : n575_o;
  /* T80.vhd:620:41  */
  assign n578_o = t_res ? n577_o : n570_o;
  /* T80.vhd:737:41  */
  assign n579_o = n535_o ? n544_o : n578_o;
  assign n580_o = f[5];
  assign n581_o = f[5];
  assign n582_o = n485_o[2];
  /* T80.vhd:711:49  */
  assign n583_o = i_cpl ? n582_o : n581_o;
  assign n584_o = n497_o[2];
  /* T80.vhd:719:49  */
  assign n585_o = i_ccf ? n584_o : n583_o;
  assign n586_o = n508_o[2];
  /* T80.vhd:727:49  */
  assign n587_o = i_scf ? n586_o : n585_o;
  /* T80.vhd:620:41  */
  assign n588_o = t_res ? n587_o : n580_o;
  assign n589_o = f[3];
  assign n590_o = f[3];
  assign n591_o = n485_o[0];
  /* T80.vhd:711:49  */
  assign n592_o = i_cpl ? n591_o : n590_o;
  assign n593_o = n497_o[0];
  /* T80.vhd:719:49  */
  assign n594_o = i_ccf ? n593_o : n592_o;
  assign n595_o = n508_o[0];
  /* T80.vhd:727:49  */
  assign n596_o = i_scf ? n595_o : n594_o;
  /* T80.vhd:620:41  */
  assign n597_o = t_res ? n596_o : n589_o;
  /* T80.vhd:746:51  */
  assign n600_o = tstate == 3'b010;
  /* T80.vhd:746:55  */
  assign n601_o = WAIT_n & n600_o;
  /* T80.vhd:747:57  */
  assign n603_o = iset == 2'b01;
  /* T80.vhd:747:75  */
  assign n605_o = mcycle == 3'b111;
  /* T80.vhd:747:64  */
  assign n606_o = n605_o & n603_o;
  /* T80.vhd:746:41  */
  assign n607_o = n628_o ? DInst : ir;
  /* T80.vhd:751:83  */
  assign n608_o = {{8{di_reg[7]}}, di_reg}; // sext
  /* T80.vhd:751:83  */
  assign n609_o = pc + n608_o;
  /* T80.vhd:752:91  */
  assign n610_o = {{8{di_reg[7]}}, di_reg}; // sext
  /* T80.vhd:752:91  */
  assign n611_o = pc + n610_o;
  /* T80.vhd:754:66  */
  assign n613_o = pc + 16'b0000000000000001;
  /* T80.vhd:753:49  */
  assign n614_o = inc_pc ? n613_o : n517_o;
  /* T80.vhd:750:49  */
  assign n615_o = jumpe ? n609_o : n614_o;
  /* T80.vhd:750:49  */
  assign n616_o = jumpe ? n611_o : n518_o;
  /* T80.vhd:757:66  */
  assign n618_o = pc - 16'b0000000000000010;
  /* T80.vhd:756:49  */
  assign n619_o = btr_r ? n618_o : n615_o;
  /* T80.vhd:761:77  */
  assign n620_o = ir[5:3];
  assign n622_o = n621_o[15:6];
  assign n623_o = n621_o[2:0];
  assign n624_o = {n622_o, n620_o, n623_o};
  /* T80.vhd:759:49  */
  assign n625_o = rstp ? n624_o : n616_o;
  /* T80.vhd:746:41  */
  assign n626_o = n601_o ? n619_o : n517_o;
  /* T80.vhd:746:41  */
  assign n627_o = n601_o ? n625_o : n518_o;
  /* T80.vhd:746:41  */
  assign n628_o = n606_o & n601_o;
  /* T80.vhd:764:51  */
  assign n630_o = tstate == 3'b011;
  /* T80.vhd:764:66  */
  assign n632_o = mcycle == 3'b110;
  /* T80.vhd:764:55  */
  assign n633_o = n632_o & n630_o;
  /* T80.vhd:765:88  */
  assign n634_o = {{8{di_reg[7]}}, di_reg}; // sext
  /* T80.vhd:765:88  */
  assign n635_o = regbusc + n634_o;
  /* T80.vhd:764:41  */
  assign n636_o = n633_o ? n635_o : n627_o;
  /* T80.vhd:768:51  */
  assign n638_o = mcycle == 3'b011;
  /* T80.vhd:768:70  */
  assign n640_o = tstate == 3'b100;
  /* T80.vhd:768:59  */
  assign n641_o = n640_o & n638_o;
  /* T80.vhd:768:85  */
  assign n642_o = ~no_btr;
  /* T80.vhd:768:74  */
  assign n643_o = n642_o & n641_o;
  /* T80.vhd:769:63  */
  assign n644_o = i_bt | i_bc;
  /* T80.vhd:770:83  */
  assign n647_o = pc - 16'b0000000000000001;
  /* T80.vhd:768:41  */
  assign n648_o = n649_o ? n647_o : n636_o;
  /* T80.vhd:768:41  */
  assign n649_o = n644_o & n643_o;
  /* T80.vhd:774:52  */
  assign n651_o = tstate == 3'b010;
  /* T80.vhd:774:56  */
  assign n652_o = WAIT_n & n651_o;
  /* T80.vhd:774:85  */
  assign n654_o = tstate == 3'b100;
  /* T80.vhd:774:100  */
  assign n656_o = mcycle == 3'b001;
  /* T80.vhd:774:89  */
  assign n657_o = n656_o & n654_o;
  /* T80.vhd:774:74  */
  assign n658_o = n652_o | n657_o;
  /* T80.vhd:775:61  */
  assign n659_o = incdec_16[2:0];
  /* T80.vhd:775:74  */
  assign n661_o = n659_o == 3'b111;
  /* T80.vhd:776:69  */
  assign n662_o = incdec_16[3];
  /* T80.vhd:777:74  */
  assign n664_o = sp - 16'b0000000000000001;
  /* T80.vhd:779:74  */
  assign n666_o = sp + 16'b0000000000000001;
  /* T80.vhd:776:57  */
  assign n667_o = n662_o ? n664_o : n666_o;
  /* T80.vhd:774:41  */
  assign n668_o = n669_o ? n667_o : sp;
  /* T80.vhd:774:41  */
  assign n669_o = n661_o & n658_o;
  /* T80.vhd:784:41  */
  assign n670_o = ldsphl ? regbusc : n668_o;
  /* T80.vhd:787:41  */
  assign n671_o = exchangeaf ? ap : n484_o;
  assign n672_o = f[7:6];
  assign n673_o = {n672_o, n588_o, n579_o, n597_o, n569_o};
  /* T80.vhd:787:41  */
  assign n675_o = exchangeaf ? acc : ap;
  /* T80.vhd:787:41  */
  assign n676_o = exchangeaf ? f : fp;
  /* T80.vhd:794:62  */
  assign n677_o = ~alternate;
  /* T80.vhd:793:41  */
  assign n678_o = exchangers ? n677_o : alternate;
  /* T80.vhd:567:33  */
  assign n679_o = n264_o ? n275_o : n511_o;
  /* T80.vhd:567:33  */
  assign n680_o = n264_o ? acc : n671_o;
  /* T80.vhd:567:33  */
  assign n682_o = n264_o ? ap : n675_o;
  /* T80.vhd:567:33  */
  assign n683_o = n264_o ? fp : n676_o;
  /* T80.vhd:567:33  */
  assign n685_o = n330_o & n264_o;
  /* T80.vhd:567:33  */
  assign n686_o = n264_o ? sp : n670_o;
  /* T80.vhd:567:33  */
  assign n687_o = n264_o ? n290_o : n626_o;
  /* T80.vhd:567:33  */
  assign n688_o = n264_o ? alternate : n678_o;
  /* T80.vhd:567:33  */
  assign n689_o = n264_o ? wz : n648_o;
  /* T80.vhd:567:33  */
  assign n690_o = n264_o ? n332_o : n607_o;
  /* T80.vhd:567:33  */
  assign n691_o = n264_o ? n333_o : n341_o;
  /* T80.vhd:567:33  */
  assign n692_o = n267_o & n264_o;
  /* T80.vhd:567:33  */
  assign n693_o = n264_o ? n335_o : n344_o;
  /* T80.vhd:567:33  */
  assign n694_o = n264_o ? btr_r : n519_o;
  /* T80.vhd:567:33  */
  assign n696_o = n264_o ? 4'b0000 : n521_o;
  /* T80.vhd:567:33  */
  assign n699_o = n264_o ? 1'b0 : n523_o;
  /* T80.vhd:798:43  */
  assign n703_o = tstate == 3'b011;
  assign n704_o = wz[7:0];
  assign n705_o = n451_o[7:0];
  assign n706_o = wz[7:0];
  /* T80.vhd:636:49  */
  assign n707_o = n359_o ? n706_o : n705_o;
  assign n708_o = wz[7:0];
  /* T80.vhd:633:49  */
  assign n709_o = n353_o ? n708_o : n707_o;
  assign n710_o = wz[7:0];
  /* T80.vhd:630:49  */
  assign n711_o = n351_o ? n710_o : n709_o;
  assign n712_o = wz[7:0];
  /* T80.vhd:627:49  */
  assign n713_o = jumpxy ? n712_o : n711_o;
  assign n714_o = wz[7:0];
  /* T80.vhd:622:49  */
  assign n715_o = jump ? n714_o : n713_o;
  assign n716_o = id16[7:0];
  /* T80.vhd:704:49  */
  assign n717_o = n475_o ? n716_o : n715_o;
  /* T80.vhd:620:41  */
  assign n718_o = t_res ? n717_o : n704_o;
  assign n719_o = wz[7:0];
  assign n720_o = n451_o[7:0];
  assign n721_o = wz[7:0];
  /* T80.vhd:636:49  */
  assign n722_o = n359_o ? n721_o : n720_o;
  assign n723_o = wz[7:0];
  /* T80.vhd:633:49  */
  assign n724_o = n353_o ? n723_o : n722_o;
  assign n725_o = wz[7:0];
  /* T80.vhd:630:49  */
  assign n726_o = n351_o ? n725_o : n724_o;
  assign n727_o = wz[7:0];
  /* T80.vhd:627:49  */
  assign n728_o = jumpxy ? n727_o : n726_o;
  assign n729_o = wz[7:0];
  /* T80.vhd:622:49  */
  assign n730_o = jump ? n729_o : n728_o;
  assign n731_o = id16[7:0];
  /* T80.vhd:704:49  */
  assign n732_o = n475_o ? n731_o : n730_o;
  /* T80.vhd:620:41  */
  assign n733_o = t_res ? n732_o : n719_o;
  assign n734_o = n611_o[7:0];
  /* T80.vhd:750:49  */
  assign n735_o = jumpe ? n734_o : n733_o;
  assign n736_o = n624_o[7:0];
  /* T80.vhd:759:49  */
  assign n737_o = rstp ? n736_o : n735_o;
  /* T80.vhd:746:41  */
  assign n738_o = n601_o ? n737_o : n718_o;
  assign n739_o = n635_o[7:0];
  /* T80.vhd:764:41  */
  assign n740_o = n633_o ? n739_o : n738_o;
  assign n741_o = n647_o[7:0];
  /* T80.vhd:768:41  */
  assign n742_o = n649_o ? n741_o : n740_o;
  assign n743_o = wz[7:0];
  /* T80.vhd:567:33  */
  assign n744_o = n264_o ? n743_o : n742_o;
  /* T80.vhd:799:41  */
  assign n745_o = ldz ? di_reg : n744_o;
  assign n746_o = wz[15:8];
  assign n747_o = n451_o[15:8];
  assign n748_o = wz[15:8];
  /* T80.vhd:636:49  */
  assign n749_o = n359_o ? n748_o : n747_o;
  assign n750_o = wz[15:8];
  /* T80.vhd:633:49  */
  assign n751_o = n353_o ? n750_o : n749_o;
  assign n752_o = wz[15:8];
  /* T80.vhd:630:49  */
  assign n753_o = n351_o ? n752_o : n751_o;
  assign n754_o = wz[15:8];
  /* T80.vhd:627:49  */
  assign n755_o = jumpxy ? n754_o : n753_o;
  assign n756_o = wz[15:8];
  /* T80.vhd:622:49  */
  assign n757_o = jump ? n756_o : n755_o;
  assign n758_o = id16[15:8];
  /* T80.vhd:704:49  */
  assign n759_o = n475_o ? n758_o : n757_o;
  /* T80.vhd:620:41  */
  assign n760_o = t_res ? n759_o : n746_o;
  assign n761_o = wz[15:8];
  assign n762_o = n451_o[15:8];
  assign n763_o = wz[15:8];
  /* T80.vhd:636:49  */
  assign n764_o = n359_o ? n763_o : n762_o;
  assign n765_o = wz[15:8];
  /* T80.vhd:633:49  */
  assign n766_o = n353_o ? n765_o : n764_o;
  assign n767_o = wz[15:8];
  /* T80.vhd:630:49  */
  assign n768_o = n351_o ? n767_o : n766_o;
  assign n769_o = wz[15:8];
  /* T80.vhd:627:49  */
  assign n770_o = jumpxy ? n769_o : n768_o;
  assign n771_o = wz[15:8];
  /* T80.vhd:622:49  */
  assign n772_o = jump ? n771_o : n770_o;
  assign n773_o = id16[15:8];
  /* T80.vhd:704:49  */
  assign n774_o = n475_o ? n773_o : n772_o;
  /* T80.vhd:620:41  */
  assign n775_o = t_res ? n774_o : n761_o;
  assign n776_o = n611_o[15:8];
  /* T80.vhd:750:49  */
  assign n777_o = jumpe ? n776_o : n775_o;
  assign n778_o = n624_o[15:8];
  /* T80.vhd:759:49  */
  assign n779_o = rstp ? n778_o : n777_o;
  /* T80.vhd:746:41  */
  assign n780_o = n601_o ? n779_o : n760_o;
  assign n781_o = n635_o[15:8];
  /* T80.vhd:764:41  */
  assign n782_o = n633_o ? n781_o : n780_o;
  assign n783_o = n647_o[15:8];
  /* T80.vhd:768:41  */
  assign n784_o = n649_o ? n783_o : n782_o;
  assign n785_o = wz[15:8];
  /* T80.vhd:567:33  */
  assign n786_o = n264_o ? n785_o : n784_o;
  /* T80.vhd:802:41  */
  assign n787_o = ldw ? di_reg : n786_o;
  /* T80.vhd:806:54  */
  assign n788_o = special_ld[2];
  /* T80.vhd:807:64  */
  assign n789_o = special_ld[1:0];
  /* T80.vhd:811:71  */
  assign n790_o = i[7];
  /* T80.vhd:813:62  */
  assign n792_o = i == 8'b00000000;
  /* T80.vhd:813:57  */
  assign n795_o = n792_o ? 1'b1 : 1'b0;
  /* T80.vhd:819:71  */
  assign n796_o = i[5];
  /* T80.vhd:821:71  */
  assign n798_o = i[3];
  /* T80.vhd:808:49  */
  assign n801_o = n789_o == 2'b00;
  /* T80.vhd:828:71  */
  assign n802_o = r[7];
  /* T80.vhd:830:62  */
  assign n804_o = r == 8'b00000000;
  /* T80.vhd:830:57  */
  assign n807_o = n804_o ? 1'b1 : 1'b0;
  /* T80.vhd:836:71  */
  assign n808_o = r[5];
  /* T80.vhd:838:71  */
  assign n810_o = r[3];
  /* T80.vhd:825:49  */
  assign n813_o = n789_o == 2'b01;
  /* T80.vhd:841:49  */
  assign n815_o = n789_o == 2'b10;
  assign n816_o = {n815_o, n813_o, n801_o};
  /* T80.vhd:807:49  */
  always @*
    case (n816_o)
      3'b100: n817_o = n680_o;
      3'b010: n817_o = r;
      3'b001: n817_o = i;
      default: n817_o = n680_o;
    endcase
  assign n818_o = n673_o[1];
  assign n819_o = fp[1];
  /* T80.vhd:787:41  */
  assign n820_o = exchangeaf ? n819_o : n818_o;
  assign n821_o = f[1];
  /* T80.vhd:567:33  */
  assign n822_o = n264_o ? n821_o : n820_o;
  /* T80.vhd:807:49  */
  always @*
    case (n816_o)
      3'b100: n823_o = n822_o;
      3'b010: n823_o = 1'b0;
      3'b001: n823_o = 1'b0;
      default: n823_o = n822_o;
    endcase
  assign n824_o = n673_o[2];
  assign n825_o = fp[2];
  /* T80.vhd:787:41  */
  assign n826_o = exchangeaf ? n825_o : n824_o;
  assign n827_o = f[2];
  /* T80.vhd:567:33  */
  assign n828_o = n264_o ? n827_o : n826_o;
  /* T80.vhd:807:49  */
  always @*
    case (n816_o)
      3'b100: n829_o = n828_o;
      3'b010: n829_o = inte_ff2;
      3'b001: n829_o = inte_ff2;
      default: n829_o = n828_o;
    endcase
  assign n830_o = n673_o[3];
  assign n831_o = fp[3];
  /* T80.vhd:787:41  */
  assign n832_o = exchangeaf ? n831_o : n830_o;
  assign n833_o = f[3];
  /* T80.vhd:567:33  */
  assign n834_o = n264_o ? n833_o : n832_o;
  /* T80.vhd:807:49  */
  always @*
    case (n816_o)
      3'b100: n835_o = n834_o;
      3'b010: n835_o = n810_o;
      3'b001: n835_o = n798_o;
      default: n835_o = n834_o;
    endcase
  assign n836_o = n673_o[4];
  assign n837_o = fp[4];
  /* T80.vhd:787:41  */
  assign n838_o = exchangeaf ? n837_o : n836_o;
  assign n839_o = f[4];
  /* T80.vhd:567:33  */
  assign n840_o = n264_o ? n839_o : n838_o;
  /* T80.vhd:807:49  */
  always @*
    case (n816_o)
      3'b100: n841_o = n840_o;
      3'b010: n841_o = 1'b0;
      3'b001: n841_o = 1'b0;
      default: n841_o = n840_o;
    endcase
  assign n842_o = n673_o[5];
  assign n843_o = fp[5];
  /* T80.vhd:787:41  */
  assign n844_o = exchangeaf ? n843_o : n842_o;
  assign n845_o = f[5];
  /* T80.vhd:567:33  */
  assign n846_o = n264_o ? n845_o : n844_o;
  /* T80.vhd:807:49  */
  always @*
    case (n816_o)
      3'b100: n847_o = n846_o;
      3'b010: n847_o = n808_o;
      3'b001: n847_o = n796_o;
      default: n847_o = n846_o;
    endcase
  assign n848_o = n673_o[6];
  assign n849_o = fp[6];
  /* T80.vhd:787:41  */
  assign n850_o = exchangeaf ? n849_o : n848_o;
  assign n851_o = f[6];
  /* T80.vhd:567:33  */
  assign n852_o = n264_o ? n851_o : n850_o;
  /* T80.vhd:807:49  */
  always @*
    case (n816_o)
      3'b100: n853_o = n852_o;
      3'b010: n853_o = n807_o;
      3'b001: n853_o = n795_o;
      default: n853_o = n852_o;
    endcase
  assign n854_o = n673_o[7];
  assign n855_o = fp[7];
  /* T80.vhd:787:41  */
  assign n856_o = exchangeaf ? n855_o : n854_o;
  assign n857_o = f[7];
  /* T80.vhd:567:33  */
  assign n858_o = n264_o ? n857_o : n856_o;
  /* T80.vhd:807:49  */
  always @*
    case (n816_o)
      3'b100: n859_o = n858_o;
      3'b010: n859_o = n802_o;
      3'b001: n859_o = n790_o;
      default: n859_o = n858_o;
    endcase
  /* T80.vhd:807:49  */
  always @*
    case (n816_o)
      3'b100: n860_o = acc;
      3'b010: n860_o = i;
      3'b001: n860_o = i;
      default: n860_o = i;
    endcase
  assign n861_o = r[7];
  assign n862_o = {n861_o, n277_o};
  /* T80.vhd:807:49  */
  always @*
    case (n816_o)
      3'b100: n863_o = n862_o;
      3'b010: n863_o = n862_o;
      3'b001: n863_o = n862_o;
      default: n863_o = acc;
    endcase
  /* T80.vhd:798:33  */
  assign n864_o = n876_o ? n817_o : n680_o;
  assign n865_o = {n859_o, n853_o, n847_o, n841_o, n835_o, n829_o, n823_o};
  assign n866_o = n673_o[7:1];
  assign n867_o = fp[7:1];
  /* T80.vhd:787:41  */
  assign n868_o = exchangeaf ? n867_o : n866_o;
  assign n869_o = f[7:1];
  /* T80.vhd:567:33  */
  assign n870_o = n264_o ? n869_o : n868_o;
  /* T80.vhd:806:41  */
  assign n871_o = n788_o ? n865_o : n870_o;
  /* T80.vhd:548:25  */
  assign n872_o = n1143_o ? n860_o : i;
  assign n873_o = r[7];
  assign n874_o = {n873_o, n277_o};
  /* T80.vhd:806:41  */
  assign n875_o = n788_o ? n863_o : n874_o;
  /* T80.vhd:798:33  */
  assign n876_o = n788_o & n703_o;
  assign n877_o = n673_o[7:1];
  assign n878_o = fp[7:1];
  /* T80.vhd:787:41  */
  assign n879_o = exchangeaf ? n878_o : n877_o;
  assign n880_o = f[7:1];
  /* T80.vhd:567:33  */
  assign n881_o = n264_o ? n880_o : n879_o;
  /* T80.vhd:798:33  */
  assign n882_o = n703_o ? n871_o : n881_o;
  assign n883_o = n673_o[0];
  assign n884_o = fp[0];
  /* T80.vhd:787:41  */
  assign n885_o = exchangeaf ? n884_o : n883_o;
  assign n886_o = f[0];
  /* T80.vhd:567:33  */
  assign n887_o = n264_o ? n886_o : n885_o;
  /* T80.vhd:798:33  */
  assign n888_o = n788_o & n703_o;
  assign n889_o = r[7];
  assign n890_o = {n889_o, n277_o};
  /* T80.vhd:798:33  */
  assign n891_o = n703_o ? n875_o : n890_o;
  assign n892_o = {n787_o, n745_o};
  /* T80.vhd:798:33  */
  assign n893_o = n703_o ? n892_o : n689_o;
  /* T80.vhd:849:44  */
  assign n894_o = ~i_djnz;
  /* T80.vhd:849:50  */
  assign n895_o = save_alu_r & n894_o;
  /* T80.vhd:849:84  */
  assign n897_o = alu_op_r == 4'b1001;
  /* T80.vhd:849:72  */
  assign n898_o = n895_o | n897_o;
  /* T80.vhd:850:53  */
  assign n899_o = {30'b0, Mode_Sel};  //  uext
  /* T80.vhd:850:53  */
  assign n901_o = n899_o == 32'b00000000000000000000000000000011;
  /* T80.vhd:851:62  */
  assign n902_o = f_out[6];
  /* T80.vhd:852:62  */
  assign n903_o = f_out[5];
  /* T80.vhd:853:62  */
  assign n904_o = f_out[7];
  /* T80.vhd:854:64  */
  assign n905_o = ~preservec_r;
  /* T80.vhd:855:70  */
  assign n906_o = f_out[4];
  assign n907_o = n673_o[4];
  assign n908_o = fp[4];
  /* T80.vhd:787:41  */
  assign n909_o = exchangeaf ? n908_o : n907_o;
  assign n910_o = f[4];
  /* T80.vhd:567:33  */
  assign n911_o = n264_o ? n910_o : n909_o;
  assign n912_o = n673_o[4];
  assign n913_o = fp[4];
  /* T80.vhd:787:41  */
  assign n914_o = exchangeaf ? n913_o : n912_o;
  assign n915_o = f[4];
  /* T80.vhd:567:33  */
  assign n916_o = n264_o ? n915_o : n914_o;
  assign n917_o = n865_o[3];
  /* T80.vhd:806:41  */
  assign n918_o = n788_o ? n917_o : n916_o;
  /* T80.vhd:798:33  */
  assign n919_o = n703_o ? n918_o : n911_o;
  /* T80.vhd:854:49  */
  assign n920_o = n905_o ? n906_o : n919_o;
  /* T80.vhd:858:71  */
  assign n921_o = f_out[7:1];
  /* T80.vhd:859:64  */
  assign n922_o = ~preservec_r;
  /* T80.vhd:860:75  */
  assign n923_o = f_out[0];
  /* T80.vhd:859:49  */
  assign n924_o = n922_o ? n923_o : n887_o;
  assign n925_o = {n921_o, n924_o};
  assign n926_o = {n904_o, n902_o, n903_o, n920_o};
  assign n927_o = n925_o[3:0];
  assign n928_o = n673_o[3:1];
  assign n929_o = fp[3:1];
  /* T80.vhd:787:41  */
  assign n930_o = exchangeaf ? n929_o : n928_o;
  assign n931_o = f[3:1];
  /* T80.vhd:567:33  */
  assign n932_o = n264_o ? n931_o : n930_o;
  assign n933_o = n673_o[3:1];
  assign n934_o = fp[3:1];
  /* T80.vhd:787:41  */
  assign n935_o = exchangeaf ? n934_o : n933_o;
  assign n936_o = f[3:1];
  /* T80.vhd:567:33  */
  assign n937_o = n264_o ? n936_o : n935_o;
  assign n938_o = n865_o[2:0];
  /* T80.vhd:806:41  */
  assign n939_o = n788_o ? n938_o : n937_o;
  /* T80.vhd:798:33  */
  assign n940_o = n703_o ? n939_o : n932_o;
  assign n941_o = {n940_o, n887_o};
  /* T80.vhd:850:41  */
  assign n942_o = n901_o ? n941_o : n927_o;
  assign n943_o = n925_o[7:4];
  /* T80.vhd:850:41  */
  assign n944_o = n901_o ? n926_o : n943_o;
  assign n945_o = {n944_o, n942_o};
  assign n946_o = {n882_o, n887_o};
  /* T80.vhd:864:48  */
  assign n948_o = i_inrc & t_res;
  /* T80.vhd:867:60  */
  assign n951_o = di_reg[3];
  /* T80.vhd:868:60  */
  assign n952_o = di_reg[5];
  /* T80.vhd:869:63  */
  assign n954_o = di_reg == 8'b00000000;
  /* T80.vhd:869:41  */
  assign n957_o = n954_o ? 1'b1 : 1'b0;
  /* T80.vhd:874:60  */
  assign n958_o = di_reg[7];
  /* T80.vhd:875:65  */
  assign n959_o = di_reg[0];
  /* T80.vhd:875:79  */
  assign n960_o = di_reg[1];
  /* T80.vhd:875:69  */
  assign n961_o = n959_o ^ n960_o;
  /* T80.vhd:875:93  */
  assign n962_o = di_reg[2];
  /* T80.vhd:875:83  */
  assign n963_o = n961_o ^ n962_o;
  /* T80.vhd:875:107  */
  assign n964_o = di_reg[3];
  /* T80.vhd:875:97  */
  assign n965_o = n963_o ^ n964_o;
  /* T80.vhd:876:55  */
  assign n966_o = di_reg[4];
  /* T80.vhd:875:111  */
  assign n967_o = n965_o ^ n966_o;
  /* T80.vhd:876:69  */
  assign n968_o = di_reg[5];
  /* T80.vhd:876:59  */
  assign n969_o = n967_o ^ n968_o;
  /* T80.vhd:876:83  */
  assign n970_o = di_reg[6];
  /* T80.vhd:876:73  */
  assign n971_o = n969_o ^ n970_o;
  /* T80.vhd:876:97  */
  assign n972_o = di_reg[7];
  /* T80.vhd:876:87  */
  assign n973_o = n971_o ^ n972_o;
  /* T80.vhd:875:54  */
  assign n974_o = ~n973_o;
  assign n975_o = {n958_o, n957_o, n952_o, 1'b0, n951_o, n974_o, 1'b0};
  assign n980_o = n946_o[0];
  assign n981_o = n945_o[0];
  /* T80.vhd:849:33  */
  assign n982_o = n898_o ? n981_o : n980_o;
  /* T80.vhd:879:43  */
  assign n984_o = tstate == 3'b001;
  /* T80.vhd:879:64  */
  assign n985_o = ~auto_wait_t1;
  /* T80.vhd:879:47  */
  assign n986_o = n985_o & n984_o;
  /* T80.vhd:881:57  */
  assign n987_o = i_rld | i_rrd;
  /* T80.vhd:882:50  */
  assign n988_o = ~i_rxdd;
  /* T80.vhd:882:41  */
  assign n989_o = n988_o ? busb : n2060_q;
  /* T80.vhd:886:73  */
  assign n990_o = busa[3:0];
  /* T80.vhd:887:73  */
  assign n991_o = busb[3:0];
  assign n992_o = {n991_o, n990_o};
  /* T80.vhd:885:41  */
  assign n993_o = i_rld ? n992_o : n989_o;
  /* T80.vhd:890:73  */
  assign n994_o = busb[7:4];
  /* T80.vhd:891:73  */
  assign n995_o = busa[3:0];
  assign n996_o = {n995_o, n994_o};
  /* T80.vhd:889:41  */
  assign n997_o = i_rrd ? n996_o : n993_o;
  /* T80.vhd:879:33  */
  assign n998_o = n986_o ? n997_o : n2060_q;
  /* T80.vhd:548:25  */
  assign n999_o = n1162_o ? n987_o : i_rxdd;
  assign n1002_o = {1'b1, 4'b0111};
  assign n1003_o = {read_to_reg, set_busa_to};
  /* T80.vhd:898:41  */
  assign n1004_o = read_to_acc ? n1002_o : n1003_o;
  /* T80.vhd:895:33  */
  assign n1006_o = t_res ? n1004_o : 5'b00000;
  /* T80.vhd:904:43  */
  assign n1009_o = tstate == 3'b001;
  /* T80.vhd:904:47  */
  assign n1010_o = i_bt & n1009_o;
  /* T80.vhd:905:59  */
  assign n1011_o = alu_q[3];
  /* T80.vhd:906:59  */
  assign n1012_o = alu_q[1];
  assign n1015_o = {n1012_o, 1'b0, n1011_o};
  assign n1016_o = n946_o[1];
  assign n1017_o = n945_o[1];
  /* T80.vhd:849:33  */
  assign n1018_o = n898_o ? n1017_o : n1016_o;
  assign n1019_o = n975_o[0];
  /* T80.vhd:864:33  */
  assign n1020_o = n948_o ? n1019_o : n1018_o;
  /* T80.vhd:904:33  */
  assign n1021_o = n1010_o ? 1'b0 : n1020_o;
  assign n1033_o = n946_o[7:6];
  assign n1034_o = n945_o[7:6];
  /* T80.vhd:849:33  */
  assign n1035_o = n898_o ? n1034_o : n1033_o;
  assign n1036_o = n975_o[6:5];
  /* T80.vhd:864:33  */
  assign n1037_o = n948_o ? n1036_o : n1035_o;
  assign n1038_o = n946_o[2];
  assign n1039_o = n945_o[2];
  /* T80.vhd:849:33  */
  assign n1040_o = n898_o ? n1039_o : n1038_o;
  assign n1041_o = n975_o[1];
  /* T80.vhd:864:33  */
  assign n1042_o = n948_o ? n1041_o : n1040_o;
  /* T80.vhd:910:43  */
  assign n1044_o = tstate == 3'b001;
  /* T80.vhd:910:47  */
  assign n1045_o = i_bc & n1044_o;
  /* T80.vhd:911:72  */
  assign n1046_o = f_out[4];
  /* T80.vhd:911:65  */
  assign n1048_o = {7'b0000000, n1046_o};
  /* T80.vhd:911:52  */
  assign n1049_o = alu_q - n1048_o;
  /* T80.vhd:912:55  */
  assign n1050_o = n1049_o[3];
  /* T80.vhd:913:55  */
  assign n1051_o = n1049_o[1];
  assign n1052_o = n946_o[3];
  assign n1053_o = n945_o[3];
  /* T80.vhd:849:33  */
  assign n1054_o = n898_o ? n1053_o : n1052_o;
  assign n1055_o = n975_o[2];
  /* T80.vhd:864:33  */
  assign n1056_o = n948_o ? n1055_o : n1054_o;
  assign n1057_o = n1015_o[0];
  /* T80.vhd:904:33  */
  assign n1058_o = n1010_o ? n1057_o : n1056_o;
  /* T80.vhd:910:33  */
  assign n1059_o = n1045_o ? n1050_o : n1058_o;
  assign n1060_o = n946_o[5];
  assign n1061_o = n945_o[5];
  /* T80.vhd:849:33  */
  assign n1062_o = n898_o ? n1061_o : n1060_o;
  assign n1063_o = n975_o[4];
  /* T80.vhd:864:33  */
  assign n1064_o = n948_o ? n1063_o : n1062_o;
  assign n1065_o = n1015_o[2];
  /* T80.vhd:904:33  */
  assign n1066_o = n1010_o ? n1065_o : n1064_o;
  /* T80.vhd:910:33  */
  assign n1067_o = n1045_o ? n1051_o : n1066_o;
  assign n1075_o = n946_o[4];
  assign n1076_o = n945_o[4];
  /* T80.vhd:849:33  */
  assign n1077_o = n898_o ? n1076_o : n1075_o;
  assign n1078_o = n975_o[3];
  /* T80.vhd:864:33  */
  assign n1079_o = n948_o ? n1078_o : n1077_o;
  assign n1080_o = n1015_o[1];
  /* T80.vhd:904:33  */
  assign n1081_o = n1010_o ? n1080_o : n1079_o;
  /* T80.vhd:915:47  */
  assign n1083_o = i_bc | i_bt;
  /* T80.vhd:915:33  */
  assign n1084_o = n1083_o ? incdecz : n1042_o;
  /* T80.vhd:919:44  */
  assign n1086_o = tstate == 3'b001;
  /* T80.vhd:919:63  */
  assign n1087_o = ~save_alu_r;
  /* T80.vhd:919:48  */
  assign n1088_o = n1087_o & n1086_o;
  /* T80.vhd:919:86  */
  assign n1089_o = ~auto_wait_t1;
  /* T80.vhd:919:69  */
  assign n1090_o = n1089_o & n1088_o;
  /* T80.vhd:920:72  */
  assign n1092_o = alu_op_r != 4'b0111;
  /* T80.vhd:920:59  */
  assign n1093_o = n1092_o & save_alu_r;
  /* T80.vhd:919:93  */
  assign n1094_o = n1090_o | n1093_o;
  /* T80.vhd:922:41  */
  assign n1096_o = read_to_reg_r == 5'b10111;
  /* T80.vhd:924:41  */
  assign n1098_o = read_to_reg_r == 5'b10110;
  /* T80.vhd:926:41  */
  assign n1100_o = read_to_reg_r == 5'b11000;
  /* T80.vhd:928:41  */
  assign n1102_o = read_to_reg_r == 5'b11001;
  /* T80.vhd:930:41  */
  assign n1104_o = read_to_reg_r == 5'b11011;
  assign n1105_o = {n1104_o, n1102_o, n1100_o, n1098_o, n1096_o};
  /* T80.vhd:921:41  */
  always @*
    case (n1105_o)
      5'b10000: n1106_o = n998_o;
      5'b01000: n1106_o = n998_o;
      5'b00100: n1106_o = n998_o;
      5'b00010: n1106_o = save_mux;
      5'b00001: n1106_o = n998_o;
      default: n1106_o = n998_o;
    endcase
  /* T80.vhd:921:41  */
  always @*
    case (n1105_o)
      5'b10000: n1107_o = n864_o;
      5'b01000: n1107_o = n864_o;
      5'b00100: n1107_o = n864_o;
      5'b00010: n1107_o = n864_o;
      5'b00001: n1107_o = save_mux;
      default: n1107_o = n864_o;
    endcase
  assign n1108_o = {n1037_o, n1067_o, n1081_o, n1059_o, n1084_o, n1021_o, n982_o};
  /* T80.vhd:921:41  */
  always @*
    case (n1105_o)
      5'b10000: n1109_o = save_mux;
      5'b01000: n1109_o = n1108_o;
      5'b00100: n1109_o = n1108_o;
      5'b00010: n1109_o = n1108_o;
      5'b00001: n1109_o = n1108_o;
      default: n1109_o = n1108_o;
    endcase
  assign n1110_o = sp[7:0];
  assign n1111_o = n666_o[7:0];
  assign n1112_o = n664_o[7:0];
  /* T80.vhd:776:57  */
  assign n1113_o = n662_o ? n1112_o : n1111_o;
  /* T80.vhd:774:41  */
  assign n1114_o = n669_o ? n1113_o : n1110_o;
  assign n1115_o = regbusc[7:0];
  /* T80.vhd:784:41  */
  assign n1116_o = ldsphl ? n1115_o : n1114_o;
  assign n1117_o = sp[7:0];
  /* T80.vhd:567:33  */
  assign n1118_o = n264_o ? n1117_o : n1116_o;
  /* T80.vhd:921:41  */
  always @*
    case (n1105_o)
      5'b10000: n1119_o = n1118_o;
      5'b01000: n1119_o = n1118_o;
      5'b00100: n1119_o = save_mux;
      5'b00010: n1119_o = n1118_o;
      5'b00001: n1119_o = n1118_o;
      default: n1119_o = n1118_o;
    endcase
  assign n1120_o = sp[15:8];
  assign n1121_o = n666_o[15:8];
  assign n1122_o = n664_o[15:8];
  /* T80.vhd:776:57  */
  assign n1123_o = n662_o ? n1122_o : n1121_o;
  /* T80.vhd:774:41  */
  assign n1124_o = n669_o ? n1123_o : n1120_o;
  assign n1125_o = regbusc[15:8];
  /* T80.vhd:784:41  */
  assign n1126_o = ldsphl ? n1125_o : n1124_o;
  assign n1127_o = sp[15:8];
  /* T80.vhd:567:33  */
  assign n1128_o = n264_o ? n1127_o : n1126_o;
  /* T80.vhd:921:41  */
  always @*
    case (n1105_o)
      5'b10000: n1129_o = n1128_o;
      5'b01000: n1129_o = save_mux;
      5'b00100: n1129_o = n1128_o;
      5'b00010: n1129_o = n1128_o;
      5'b00001: n1129_o = n1128_o;
      default: n1129_o = n1128_o;
    endcase
  /* T80.vhd:934:41  */
  assign n1130_o = xybit_undoc ? alu_q : n1106_o;
  /* T80.vhd:919:33  */
  assign n1131_o = n1094_o ? n1130_o : n998_o;
  /* T80.vhd:919:33  */
  assign n1132_o = n1094_o ? n1107_o : n864_o;
  assign n1133_o = {n1037_o, n1067_o, n1081_o, n1059_o, n1084_o, n1021_o, n982_o};
  /* T80.vhd:919:33  */
  assign n1134_o = n1094_o ? n1109_o : n1133_o;
  assign n1135_o = {n1129_o, n1119_o};
  /* T80.vhd:919:33  */
  assign n1136_o = n1094_o ? n1135_o : n686_o;
  /* T80.vhd:548:25  */
  assign n1137_o = clken ? n679_o : n2059_q;
  /* T80.vhd:548:25  */
  assign n1138_o = clken ? n1131_o : n2060_q;
  /* T80.vhd:548:25  */
  assign n1139_o = clken ? n1132_o : acc;
  /* T80.vhd:548:25  */
  assign n1140_o = clken ? n1134_o : f;
  /* T80.vhd:548:25  */
  assign n1141_o = clken ? n682_o : ap;
  /* T80.vhd:548:25  */
  assign n1142_o = clken ? n683_o : fp;
  /* T80.vhd:548:25  */
  assign n1143_o = n888_o & clken;
  /* T80.vhd:548:25  */
  assign n1144_o = clken ? n891_o : r;
  /* T80.vhd:548:25  */
  assign n1145_o = clken ? n1136_o : sp;
  /* T80.vhd:548:25  */
  assign n1146_o = clken ? n687_o : pc;
  /* T80.vhd:548:25  */
  assign n1147_o = clken ? n688_o : alternate;
  /* T80.vhd:548:25  */
  assign n1148_o = clken ? n893_o : wz;
  /* T80.vhd:548:25  */
  assign n1149_o = clken ? n690_o : ir;
  /* T80.vhd:548:25  */
  assign n1150_o = clken ? n691_o : iset;
  /* T80.vhd:548:25  */
  assign n1151_o = n245_o & clken;
  /* T80.vhd:548:25  */
  assign n1152_o = n692_o & clken;
  /* T80.vhd:548:25  */
  assign n1153_o = clken ? n693_o : xy_ind;
  /* T80.vhd:548:25  */
  assign n1154_o = clken ? n694_o : btr_r;
  /* T80.vhd:548:25  */
  assign n1155_o = clken ? n1006_o : read_to_reg_r;
  /* T80.vhd:548:25  */
  assign n1156_o = clken ? arith16 : arith16_r;
  /* T80.vhd:548:25  */
  assign n1157_o = clken ? n259_o : z16_r;
  /* T80.vhd:548:25  */
  assign n1158_o = clken ? n696_o : alu_op_r;
  /* T80.vhd:548:25  */
  assign n1159_o = clken ? n699_o : save_alu_r;
  /* T80.vhd:548:25  */
  assign n1160_o = clken ? preservec : preservec_r;
  /* T80.vhd:548:25  */
  assign n1161_o = clken ? mcycles_d : mcycles;
  /* T80.vhd:548:25  */
  assign n1162_o = n986_o & clken;
  /* T80.vhd:536:25  */
  assign n1165_o = DIRSet ? n242_o : n1137_o;
  /* T80.vhd:536:25  */
  assign n1166_o = DIRSet ? n2060_q : n1138_o;
  /* T80.vhd:536:25  */
  assign n1167_o = DIRSet ? n234_o : n1139_o;
  /* T80.vhd:536:25  */
  assign n1168_o = DIRSet ? n235_o : n1140_o;
  /* T80.vhd:536:25  */
  assign n1169_o = DIRSet ? n236_o : n1141_o;
  /* T80.vhd:536:25  */
  assign n1170_o = DIRSet ? n237_o : n1142_o;
  /* T80.vhd:536:25  */
  assign n1171_o = DIRSet ? n238_o : n872_o;
  /* T80.vhd:536:25  */
  assign n1172_o = DIRSet ? n239_o : n1144_o;
  /* T80.vhd:536:25  */
  assign n1173_o = DIRSet ? n240_o : n1145_o;
  /* T80.vhd:536:25  */
  assign n1174_o = DIRSet ? n241_o : n1146_o;
  /* T80.vhd:536:25  */
  assign n1175_o = DIRSet ? alternate : n1147_o;
  /* T80.vhd:536:25  */
  assign n1176_o = DIRSet ? wz : n1148_o;
  /* T80.vhd:536:25  */
  assign n1177_o = DIRSet ? ir : n1149_o;
  /* T80.vhd:536:25  */
  assign n1178_o = DIRSet ? iset : n1150_o;
  /* T80.vhd:536:25  */
  assign n1179_o = DIRSet ? n243_o : n246_o;
  /* T80.vhd:536:25  */
  assign n1180_o = DIRSet ? xy_state : n334_o;
  /* T80.vhd:536:25  */
  assign n1181_o = DIRSet ? xy_ind : n1153_o;
  /* T80.vhd:536:25  */
  assign n1182_o = DIRSet ? btr_r : n1154_o;
  /* T80.vhd:536:25  */
  assign n1183_o = DIRSet ? read_to_reg_r : n1155_o;
  /* T80.vhd:536:25  */
  assign n1184_o = DIRSet ? arith16_r : n1156_o;
  /* T80.vhd:536:25  */
  assign n1185_o = DIRSet ? z16_r : n1157_o;
  /* T80.vhd:536:25  */
  assign n1186_o = DIRSet ? alu_op_r : n1158_o;
  /* T80.vhd:536:25  */
  assign n1187_o = DIRSet ? save_alu_r : n1159_o;
  /* T80.vhd:536:25  */
  assign n1188_o = DIRSet ? preservec_r : n1160_o;
  /* T80.vhd:536:25  */
  assign n1189_o = DIRSet ? mcycles : n1161_o;
  /* T80.vhd:536:25  */
  assign n1190_o = DIRSet ? i_rxdd : n999_o;
  /* T80.vhd:952:70  */
  assign n1285_o = set_busa_to[2:1];
  /* T80.vhd:952:57  */
  assign n1286_o = {alternate, n1285_o};
  /* T80.vhd:953:43  */
  assign n1287_o = ~xy_ind;
  /* T80.vhd:953:62  */
  assign n1289_o = xy_state != 2'b00;
  /* T80.vhd:953:49  */
  assign n1290_o = n1289_o & n1287_o;
  /* T80.vhd:953:85  */
  assign n1291_o = set_busa_to[2:1];
  /* T80.vhd:953:98  */
  assign n1293_o = n1291_o == 2'b10;
  /* T80.vhd:953:70  */
  assign n1294_o = n1293_o & n1290_o;
  /* T80.vhd:954:63  */
  assign n1295_o = xy_state[1];
  /* T80.vhd:954:67  */
  assign n1297_o = {n1295_o, 2'b11};
  /* T80.vhd:953:33  */
  assign n1298_o = n1294_o ? n1297_o : n1286_o;
  /* T80.vhd:958:70  */
  assign n1299_o = set_busb_to[2:1];
  /* T80.vhd:958:57  */
  assign n1300_o = {alternate, n1299_o};
  /* T80.vhd:959:43  */
  assign n1301_o = ~xy_ind;
  /* T80.vhd:959:62  */
  assign n1303_o = xy_state != 2'b00;
  /* T80.vhd:959:49  */
  assign n1304_o = n1303_o & n1301_o;
  /* T80.vhd:959:85  */
  assign n1305_o = set_busb_to[2:1];
  /* T80.vhd:959:98  */
  assign n1307_o = n1305_o == 2'b10;
  /* T80.vhd:959:70  */
  assign n1308_o = n1307_o & n1304_o;
  /* T80.vhd:960:63  */
  assign n1309_o = xy_state[1];
  /* T80.vhd:960:67  */
  assign n1311_o = {n1309_o, 2'b11};
  /* T80.vhd:959:33  */
  assign n1312_o = n1308_o ? n1311_o : n1300_o;
  /* T80.vhd:964:68  */
  assign n1313_o = set_addr_to[1:0];
  /* T80.vhd:964:55  */
  assign n1314_o = {alternate, n1313_o};
  /* T80.vhd:966:50  */
  assign n1315_o = jumpxy | ldsphl;
  /* T80.vhd:967:63  */
  assign n1317_o = {alternate, 2'b10};
  /* T80.vhd:966:33  */
  assign n1318_o = n1315_o ? n1317_o : n1314_o;
  /* T80.vhd:969:51  */
  assign n1319_o = jumpxy | ldsphl;
  /* T80.vhd:969:81  */
  assign n1321_o = xy_state != 2'b00;
  /* T80.vhd:969:68  */
  assign n1322_o = n1321_o & n1319_o;
  /* T80.vhd:969:101  */
  assign n1324_o = mcycle == 3'b110;
  /* T80.vhd:969:90  */
  assign n1325_o = n1322_o | n1324_o;
  /* T80.vhd:970:61  */
  assign n1326_o = xy_state[1];
  /* T80.vhd:970:65  */
  assign n1328_o = {n1326_o, 2'b11};
  /* T80.vhd:969:33  */
  assign n1329_o = n1325_o ? n1328_o : n1318_o;
  /* T80.vhd:973:49  */
  assign n1330_o = save_alu_r & i_djnz;
  /* T80.vhd:973:83  */
  assign n1331_o = {30'b0, Mode_Sel};  //  uext
  /* T80.vhd:973:83  */
  assign n1333_o = $signed(n1331_o) < $signed(32'b00000000000000000000000000000010);
  /* T80.vhd:973:70  */
  assign n1334_o = n1333_o & n1330_o;
  /* T80.vhd:974:57  */
  assign n1335_o = f_out[6];
  /* T80.vhd:973:33  */
  assign n1336_o = n1334_o ? n1335_o : incdecz;
  /* T80.vhd:976:44  */
  assign n1338_o = tstate == 3'b010;
  /* T80.vhd:976:59  */
  assign n1340_o = tstate == 3'b011;
  /* T80.vhd:976:74  */
  assign n1342_o = mcycle == 3'b001;
  /* T80.vhd:976:63  */
  assign n1343_o = n1342_o & n1340_o;
  /* T80.vhd:976:48  */
  assign n1344_o = n1338_o | n1343_o;
  /* T80.vhd:976:97  */
  assign n1345_o = incdec_16[2:0];
  /* T80.vhd:976:110  */
  assign n1347_o = n1345_o == 3'b100;
  /* T80.vhd:976:84  */
  assign n1348_o = n1347_o & n1344_o;
  /* T80.vhd:977:49  */
  assign n1350_o = id16 == 16'b0000000000000000;
  /* T80.vhd:977:41  */
  assign n1353_o = n1350_o ? 1'b0 : 1'b1;
  /* T80.vhd:976:33  */
  assign n1354_o = n1348_o ? n1353_o : n1336_o;
  /* T80.vhd:991:46  */
  assign n1366_o = incdec_16[1:0];
  /* T80.vhd:991:35  */
  assign n1367_o = {alternate, n1366_o};
  /* T80.vhd:991:72  */
  assign n1369_o = tstate == 3'b010;
  /* T80.vhd:992:41  */
  assign n1371_o = tstate == 3'b011;
  /* T80.vhd:992:56  */
  assign n1373_o = mcycle == 3'b001;
  /* T80.vhd:992:45  */
  assign n1374_o = n1373_o & n1371_o;
  /* T80.vhd:992:77  */
  assign n1375_o = incdec_16[2];
  /* T80.vhd:992:64  */
  assign n1376_o = n1375_o & n1374_o;
  /* T80.vhd:991:76  */
  assign n1377_o = n1369_o | n1376_o;
  /* T80.vhd:992:102  */
  assign n1379_o = xy_state == 2'b00;
  /* T80.vhd:992:89  */
  assign n1380_o = n1379_o & n1377_o;
  /* T80.vhd:991:59  */
  assign n1381_o = n1380_o ? n1367_o : n1399_o;
  /* T80.vhd:993:33  */
  assign n1382_o = xy_state[1];
  /* T80.vhd:993:37  */
  assign n1384_o = {n1382_o, 2'b11};
  /* T80.vhd:993:57  */
  assign n1386_o = tstate == 3'b010;
  /* T80.vhd:994:41  */
  assign n1388_o = tstate == 3'b011;
  /* T80.vhd:994:56  */
  assign n1390_o = mcycle == 3'b001;
  /* T80.vhd:994:45  */
  assign n1391_o = n1390_o & n1388_o;
  /* T80.vhd:994:77  */
  assign n1392_o = incdec_16[2];
  /* T80.vhd:994:64  */
  assign n1393_o = n1392_o & n1391_o;
  /* T80.vhd:993:61  */
  assign n1394_o = n1386_o | n1393_o;
  /* T80.vhd:994:102  */
  assign n1395_o = incdec_16[1:0];
  /* T80.vhd:994:115  */
  assign n1397_o = n1395_o == 2'b10;
  /* T80.vhd:994:89  */
  assign n1398_o = n1397_o & n1394_o;
  /* T80.vhd:992:109  */
  assign n1399_o = n1398_o ? n1384_o : n1405_o;
  /* T80.vhd:996:35  */
  assign n1401_o = {alternate, 2'b10};
  /* T80.vhd:996:75  */
  assign n1403_o = tstate == 3'b011;
  /* T80.vhd:996:64  */
  assign n1404_o = n1403_o & exchangedh;
  /* T80.vhd:994:122  */
  assign n1405_o = n1404_o ? n1401_o : n1411_o;
  /* T80.vhd:997:35  */
  assign n1407_o = {alternate, 2'b01};
  /* T80.vhd:997:75  */
  assign n1409_o = tstate == 3'b100;
  /* T80.vhd:997:64  */
  assign n1410_o = n1409_o & exchangedh;
  /* T80.vhd:996:79  */
  assign n1411_o = n1410_o ? n1407_o : regaddra_r;
  /* T80.vhd:1003:35  */
  assign n1413_o = {alternate, 2'b01};
  /* T80.vhd:1003:75  */
  assign n1415_o = tstate == 3'b011;
  /* T80.vhd:1003:64  */
  assign n1416_o = n1415_o & exchangedh;
  /* T80.vhd:1003:42  */
  assign n1417_o = n1416_o ? n1413_o : regaddrb_r;
  /* T80.vhd:1007:33  */
  assign n1419_o = regbusa - 16'b0000000000000001;
  /* T80.vhd:1007:51  */
  assign n1420_o = incdec_16[3];
  /* T80.vhd:1007:37  */
  assign n1421_o = n1420_o ? n1419_o : n1423_o;
  /* T80.vhd:1008:41  */
  assign n1423_o = regbusa + 16'b0000000000000001;
  /* T80.vhd:1015:28  */
  assign n1427_o = tstate == 3'b001;
  /* T80.vhd:1015:47  */
  assign n1428_o = ~save_alu_r;
  /* T80.vhd:1015:32  */
  assign n1429_o = n1428_o & n1427_o;
  /* T80.vhd:1015:70  */
  assign n1430_o = ~auto_wait_t1;
  /* T80.vhd:1015:53  */
  assign n1431_o = n1430_o & n1429_o;
  /* T80.vhd:1016:56  */
  assign n1433_o = alu_op_r != 4'b0111;
  /* T80.vhd:1016:43  */
  assign n1434_o = n1433_o & save_alu_r;
  /* T80.vhd:1015:77  */
  assign n1435_o = n1431_o | n1434_o;
  /* T80.vhd:1019:60  */
  assign n1436_o = read_to_reg_r[0];
  /* T80.vhd:1019:43  */
  assign n1437_o = ~n1436_o;
  /* T80.vhd:1020:56  */
  assign n1438_o = read_to_reg_r[0];
  /* T80.vhd:1018:25  */
  assign n1440_o = read_to_reg_r == 5'b10000;
  /* T80.vhd:1018:38  */
  assign n1442_o = read_to_reg_r == 5'b10001;
  /* T80.vhd:1018:38  */
  assign n1443_o = n1440_o | n1442_o;
  /* T80.vhd:1018:48  */
  assign n1445_o = read_to_reg_r == 5'b10010;
  /* T80.vhd:1018:48  */
  assign n1446_o = n1443_o | n1445_o;
  /* T80.vhd:1018:58  */
  assign n1448_o = read_to_reg_r == 5'b10011;
  /* T80.vhd:1018:58  */
  assign n1449_o = n1446_o | n1448_o;
  /* T80.vhd:1018:68  */
  assign n1451_o = read_to_reg_r == 5'b10100;
  /* T80.vhd:1018:68  */
  assign n1452_o = n1449_o | n1451_o;
  /* T80.vhd:1018:78  */
  assign n1454_o = read_to_reg_r == 5'b10101;
  /* T80.vhd:1018:78  */
  assign n1455_o = n1452_o | n1454_o;
  /* T80.vhd:1017:25  */
  always @*
    case (n1455_o)
      1'b1: n1457_o = n1437_o;
      default: n1457_o = 1'b0;
    endcase
  /* T80.vhd:1017:25  */
  always @*
    case (n1455_o)
      1'b1: n1459_o = n1438_o;
      default: n1459_o = 1'b0;
    endcase
  /* T80.vhd:1015:17  */
  assign n1461_o = n1435_o ? n1457_o : 1'b0;
  /* T80.vhd:1015:17  */
  assign n1464_o = n1435_o ? n1459_o : 1'b0;
  /* T80.vhd:1025:49  */
  assign n1467_o = tstate == 3'b011;
  /* T80.vhd:1025:63  */
  assign n1469_o = tstate == 3'b100;
  /* T80.vhd:1025:53  */
  assign n1470_o = n1467_o | n1469_o;
  /* T80.vhd:1025:37  */
  assign n1471_o = n1470_o & exchangedh;
  /* T80.vhd:1025:17  */
  assign n1473_o = n1471_o ? 1'b1 : n1461_o;
  /* T80.vhd:1025:17  */
  assign n1475_o = n1471_o ? 1'b1 : n1464_o;
  /* T80.vhd:1030:29  */
  assign n1476_o = incdec_16[2];
  /* T80.vhd:1030:52  */
  assign n1478_o = tstate == 3'b010;
  /* T80.vhd:1030:56  */
  assign n1479_o = WAIT_n & n1478_o;
  /* T80.vhd:1030:84  */
  assign n1481_o = mcycle != 3'b001;
  /* T80.vhd:1030:73  */
  assign n1482_o = n1481_o & n1479_o;
  /* T80.vhd:1030:105  */
  assign n1484_o = tstate == 3'b011;
  /* T80.vhd:1030:120  */
  assign n1486_o = mcycle == 3'b001;
  /* T80.vhd:1030:109  */
  assign n1487_o = n1486_o & n1484_o;
  /* T80.vhd:1030:94  */
  assign n1488_o = n1482_o | n1487_o;
  /* T80.vhd:1030:39  */
  assign n1489_o = n1488_o & n1476_o;
  /* T80.vhd:1031:39  */
  assign n1490_o = incdec_16[1:0];
  /* T80.vhd:1032:25  */
  assign n1492_o = n1490_o == 2'b00;
  /* T80.vhd:1032:35  */
  assign n1494_o = n1490_o == 2'b01;
  /* T80.vhd:1032:35  */
  assign n1495_o = n1492_o | n1494_o;
  /* T80.vhd:1032:42  */
  assign n1497_o = n1490_o == 2'b10;
  /* T80.vhd:1032:42  */
  assign n1498_o = n1495_o | n1497_o;
  /* T80.vhd:1031:25  */
  always @*
    case (n1498_o)
      1'b1: n1500_o = 1'b1;
      default: n1500_o = n1473_o;
    endcase
  /* T80.vhd:1031:25  */
  always @*
    case (n1498_o)
      1'b1: n1502_o = 1'b1;
      default: n1502_o = n1475_o;
    endcase
  /* T80.vhd:1030:17  */
  assign n1503_o = n1489_o ? n1500_o : n1473_o;
  /* T80.vhd:1030:17  */
  assign n1504_o = n1489_o ? n1502_o : n1475_o;
  /* T80.vhd:1046:48  */
  assign n1509_o = tstate == 3'b011;
  /* T80.vhd:1046:37  */
  assign n1510_o = n1509_o & exchangedh;
  /* T80.vhd:1047:42  */
  assign n1511_o = regbusb[15:8];
  /* T80.vhd:1048:42  */
  assign n1512_o = regbusb[7:0];
  /* T80.vhd:1046:17  */
  assign n1513_o = n1510_o ? n1511_o : save_mux;
  /* T80.vhd:1046:17  */
  assign n1514_o = n1510_o ? n1512_o : save_mux;
  /* T80.vhd:1050:48  */
  assign n1516_o = tstate == 3'b100;
  /* T80.vhd:1050:37  */
  assign n1517_o = n1516_o & exchangedh;
  /* T80.vhd:1051:44  */
  assign n1518_o = regbusa_r[15:8];
  /* T80.vhd:1052:44  */
  assign n1519_o = regbusa_r[7:0];
  /* T80.vhd:1050:17  */
  assign n1520_o = n1517_o ? n1518_o : n1513_o;
  /* T80.vhd:1050:17  */
  assign n1521_o = n1517_o ? n1519_o : n1514_o;
  /* T80.vhd:1055:29  */
  assign n1522_o = incdec_16[2];
  /* T80.vhd:1055:52  */
  assign n1524_o = tstate == 3'b010;
  /* T80.vhd:1055:67  */
  assign n1526_o = mcycle != 3'b001;
  /* T80.vhd:1055:56  */
  assign n1527_o = n1526_o & n1524_o;
  /* T80.vhd:1055:88  */
  assign n1529_o = tstate == 3'b011;
  /* T80.vhd:1055:103  */
  assign n1531_o = mcycle == 3'b001;
  /* T80.vhd:1055:92  */
  assign n1532_o = n1531_o & n1529_o;
  /* T80.vhd:1055:77  */
  assign n1533_o = n1527_o | n1532_o;
  /* T80.vhd:1055:39  */
  assign n1534_o = n1533_o & n1522_o;
  /* T80.vhd:1056:56  */
  assign n1535_o = id16[15:8];
  /* T80.vhd:1057:56  */
  assign n1536_o = id16[7:0];
  /* T80.vhd:1055:17  */
  assign n1537_o = n1534_o ? n1535_o : n1520_o;
  /* T80.vhd:1055:17  */
  assign n1538_o = n1534_o ? n1536_o : n1521_o;
  /* T80.vhd:1072:33  */
  assign u_regs_n1540 = u_regs_doah; // (signal)
  /* T80.vhd:1073:33  */
  assign u_regs_n1541 = u_regs_doal; // (signal)
  /* T80.vhd:1074:33  */
  assign u_regs_n1542 = u_regs_dobh; // (signal)
  /* T80.vhd:1075:33  */
  assign u_regs_n1543 = u_regs_dobl; // (signal)
  /* T80.vhd:1076:33  */
  assign u_regs_n1544 = u_regs_doch; // (signal)
  /* T80.vhd:1077:33  */
  assign u_regs_n1545 = u_regs_docl; // (signal)
  /* T80.vhd:1078:33  */
  assign u_regs_n1546 = u_regs_dor; // (signal)
  /* T80.vhd:1080:36  */
  assign n1547_o = DIR[207:80];
  /* T80.vhd:1061:9  */
  t80_reg u_regs (
    .clk(CLK_n),
    .cen(clken),
    .weh(regweh),
    .wel(regwel),
    .addra(regaddra),
    .addrb(regaddrb),
    .addrc(regaddrc),
    .dih(regdih),
    .dil(regdil),
    .dirset(DIRSet),
    .dir(n1547_o),
    .doah(u_regs_doah),
    .doal(u_regs_doal),
    .dobh(u_regs_dobh),
    .dobl(u_regs_dobl),
    .doch(u_regs_doch),
    .docl(u_regs_docl),
    .dor(u_regs_dor));
  /* T80.vhd:1092:33  */
  assign n1566_o = set_busb_to == 4'b0111;
  /* T80.vhd:1095:55  */
  assign n1567_o = set_busb_to[0];
  /* T80.vhd:1096:64  */
  assign n1568_o = regbusb[7:0];
  /* T80.vhd:1098:64  */
  assign n1569_o = regbusb[15:8];
  /* T80.vhd:1095:41  */
  assign n1570_o = n1567_o ? n1568_o : n1569_o;
  /* T80.vhd:1094:33  */
  assign n1572_o = set_busb_to == 4'b0000;
  /* T80.vhd:1094:45  */
  assign n1574_o = set_busb_to == 4'b0001;
  /* T80.vhd:1094:45  */
  assign n1575_o = n1572_o | n1574_o;
  /* T80.vhd:1094:54  */
  assign n1577_o = set_busb_to == 4'b0010;
  /* T80.vhd:1094:54  */
  assign n1578_o = n1575_o | n1577_o;
  /* T80.vhd:1094:63  */
  assign n1580_o = set_busb_to == 4'b0011;
  /* T80.vhd:1094:63  */
  assign n1581_o = n1578_o | n1580_o;
  /* T80.vhd:1094:72  */
  assign n1583_o = set_busb_to == 4'b0100;
  /* T80.vhd:1094:72  */
  assign n1584_o = n1581_o | n1583_o;
  /* T80.vhd:1094:81  */
  assign n1586_o = set_busb_to == 4'b0101;
  /* T80.vhd:1094:81  */
  assign n1587_o = n1584_o | n1586_o;
  /* T80.vhd:1100:33  */
  assign n1589_o = set_busb_to == 4'b0110;
  /* T80.vhd:1103:68  */
  assign n1590_o = sp[7:0];
  /* T80.vhd:1102:33  */
  assign n1592_o = set_busb_to == 4'b1000;
  /* T80.vhd:1105:68  */
  assign n1593_o = sp[15:8];
  /* T80.vhd:1104:33  */
  assign n1595_o = set_busb_to == 4'b1001;
  /* T80.vhd:1106:33  */
  assign n1597_o = set_busb_to == 4'b1010;
  /* T80.vhd:1108:33  */
  assign n1599_o = set_busb_to == 4'b1011;
  /* T80.vhd:1111:68  */
  assign n1600_o = pc[7:0];
  /* T80.vhd:1110:33  */
  assign n1602_o = set_busb_to == 4'b1100;
  /* T80.vhd:1113:68  */
  assign n1603_o = pc[15:8];
  /* T80.vhd:1112:33  */
  assign n1605_o = set_busb_to == 4'b1101;
  /* T80.vhd:1115:47  */
  assign n1607_o = ir == 8'b01110001;
  /* T80.vhd:1115:55  */
  assign n1608_o = out0 & n1607_o;
  /* T80.vhd:1115:41  */
  assign n1611_o = n1608_o ? 8'b11111111 : 8'b00000000;
  /* T80.vhd:1114:33  */
  assign n1613_o = set_busb_to == 4'b1110;
  assign n1614_o = {n1613_o, n1605_o, n1602_o, n1599_o, n1597_o, n1595_o, n1592_o, n1589_o, n1587_o, n1566_o};
  /* T80.vhd:1091:33  */
  always @*
    case (n1614_o)
      10'b1000000000: n1617_o = n1611_o;
      10'b0100000000: n1617_o = n1603_o;
      10'b0010000000: n1617_o = n1600_o;
      10'b0001000000: n1617_o = f;
      10'b0000100000: n1617_o = 8'b00000001;
      10'b0000010000: n1617_o = n1593_o;
      10'b0000001000: n1617_o = n1590_o;
      10'b0000000100: n1617_o = di_reg;
      10'b0000000010: n1617_o = n1570_o;
      10'b0000000001: n1617_o = acc;
      default: n1617_o = 8'bX;
    endcase
  /* T80.vhd:1125:33  */
  assign n1619_o = set_busa_to == 4'b0111;
  /* T80.vhd:1128:55  */
  assign n1620_o = set_busa_to[0];
  /* T80.vhd:1129:64  */
  assign n1621_o = regbusa[7:0];
  /* T80.vhd:1131:64  */
  assign n1622_o = regbusa[15:8];
  /* T80.vhd:1128:41  */
  assign n1623_o = n1620_o ? n1621_o : n1622_o;
  /* T80.vhd:1127:33  */
  assign n1625_o = set_busa_to == 4'b0000;
  /* T80.vhd:1127:45  */
  assign n1627_o = set_busa_to == 4'b0001;
  /* T80.vhd:1127:45  */
  assign n1628_o = n1625_o | n1627_o;
  /* T80.vhd:1127:54  */
  assign n1630_o = set_busa_to == 4'b0010;
  /* T80.vhd:1127:54  */
  assign n1631_o = n1628_o | n1630_o;
  /* T80.vhd:1127:63  */
  assign n1633_o = set_busa_to == 4'b0011;
  /* T80.vhd:1127:63  */
  assign n1634_o = n1631_o | n1633_o;
  /* T80.vhd:1127:72  */
  assign n1636_o = set_busa_to == 4'b0100;
  /* T80.vhd:1127:72  */
  assign n1637_o = n1634_o | n1636_o;
  /* T80.vhd:1127:81  */
  assign n1639_o = set_busa_to == 4'b0101;
  /* T80.vhd:1127:81  */
  assign n1640_o = n1637_o | n1639_o;
  /* T80.vhd:1133:33  */
  assign n1642_o = set_busa_to == 4'b0110;
  /* T80.vhd:1136:68  */
  assign n1643_o = sp[7:0];
  /* T80.vhd:1135:33  */
  assign n1645_o = set_busa_to == 4'b1000;
  /* T80.vhd:1138:68  */
  assign n1646_o = sp[15:8];
  /* T80.vhd:1137:33  */
  assign n1648_o = set_busa_to == 4'b1001;
  /* T80.vhd:1139:33  */
  assign n1650_o = set_busa_to == 4'b1010;
  assign n1651_o = {n1650_o, n1648_o, n1645_o, n1642_o, n1640_o, n1619_o};
  /* T80.vhd:1124:33  */
  always @*
    case (n1651_o)
      6'b100000: n1654_o = 8'b00000000;
      6'b010000: n1654_o = n1646_o;
      6'b001000: n1654_o = n1643_o;
      6'b000100: n1654_o = di_reg;
      6'b000010: n1654_o = n1623_o;
      6'b000001: n1654_o = acc;
      default: n1654_o = 8'bX;
    endcase
  /* T80.vhd:1144:33  */
  assign n1655_o = xybit_undoc ? di_reg : n1617_o;
  /* T80.vhd:1144:33  */
  assign n1656_o = xybit_undoc ? di_reg : n1654_o;
  /* T80.vhd:1159:28  */
  assign n1664_o = ~RESET_n;
  /* T80.vhd:1162:35  */
  assign n1666_o = ~DIRSet;
  /* T80.vhd:1162:41  */
  assign n1667_o = CEN & n1666_o;
  /* T80.vhd:1163:43  */
  assign n1669_o = mcycle == 3'b001;
  /* T80.vhd:1163:64  */
  assign n1671_o = tstate == 3'b010;
  /* T80.vhd:1163:69  */
  assign n1672_o = WAIT_n & n1671_o;
  /* T80.vhd:1163:97  */
  assign n1674_o = tstate == 3'b011;
  /* T80.vhd:1163:87  */
  assign n1675_o = n1672_o | n1674_o;
  /* T80.vhd:1163:51  */
  assign n1676_o = n1675_o & n1669_o;
  /* T80.vhd:1163:33  */
  assign n1679_o = n1676_o ? 1'b0 : 1'b1;
  /* T80.vhd:1175:19  */
  assign n1685_o = ~halt_ff;
  /* T80.vhd:1176:20  */
  assign n1686_o = ~busack;
  /* T80.vhd:1177:23  */
  assign n1687_o = ~intcycle;
  /* T80.vhd:1188:26  */
  always @*
    n1688_oldnmi_n = n1994_q; // (isignal)
  initial
    n1688_oldnmi_n = 1'bX;
  /* T80.vhd:1190:28  */
  assign n1691_o = ~RESET_n;
  /* T80.vhd:1209:48  */
  assign n1693_o = DIR[211];
  /* T80.vhd:1210:48  */
  assign n1694_o = DIR[210];
  /* T80.vhd:1212:42  */
  assign n1695_o = ~NMI_n;
  /* T80.vhd:1212:48  */
  assign n1696_o = n1688_oldnmi_n & n1695_o;
  /* T80.vhd:1212:33  */
  assign n1698_o = n1696_o ? 1'b1 : nmi_s;
  /* T80.vhd:1218:53  */
  assign n1699_o = ~BUSRQ_n;
  /* T80.vhd:1224:75  */
  assign n1700_o = auto_wait | iorq_i;
  /* T80.vhd:1220:41  */
  assign n1702_o = t_res ? 1'b0 : n1700_o;
  /* T80.vhd:1220:41  */
  assign n1704_o = t_res ? 1'b0 : auto_wait_t1;
  /* T80.vhd:1226:68  */
  assign n1705_o = ir[4];
  /* T80.vhd:1226:62  */
  assign n1706_o = ~n1705_o;
  /* T80.vhd:1226:80  */
  assign n1707_o = f[2];
  /* T80.vhd:1226:75  */
  assign n1708_o = ~n1707_o;
  /* T80.vhd:1226:72  */
  assign n1709_o = n1706_o | n1708_o;
  /* T80.vhd:1226:57  */
  assign n1710_o = i_bt & n1709_o;
  /* T80.vhd:1227:74  */
  assign n1711_o = ir[4];
  /* T80.vhd:1227:68  */
  assign n1712_o = ~n1711_o;
  /* T80.vhd:1227:82  */
  assign n1713_o = f[6];
  /* T80.vhd:1227:78  */
  assign n1714_o = n1712_o | n1713_o;
  /* T80.vhd:1227:99  */
  assign n1715_o = f[2];
  /* T80.vhd:1227:94  */
  assign n1716_o = ~n1715_o;
  /* T80.vhd:1227:91  */
  assign n1717_o = n1714_o | n1716_o;
  /* T80.vhd:1227:63  */
  assign n1718_o = i_bc & n1717_o;
  /* T80.vhd:1226:91  */
  assign n1719_o = n1710_o | n1718_o;
  /* T80.vhd:1228:75  */
  assign n1720_o = ir[4];
  /* T80.vhd:1228:69  */
  assign n1721_o = ~n1720_o;
  /* T80.vhd:1228:83  */
  assign n1722_o = f[6];
  /* T80.vhd:1228:79  */
  assign n1723_o = n1721_o | n1722_o;
  /* T80.vhd:1228:64  */
  assign n1724_o = i_btr & n1723_o;
  /* T80.vhd:1227:110  */
  assign n1725_o = n1719_o | n1724_o;
  /* T80.vhd:1229:51  */
  assign n1727_o = tstate == 3'b010;
  /* T80.vhd:1233:69  */
  assign n1728_o = ~nmicycle;
  /* T80.vhd:1230:49  */
  assign n1730_o = n1731_o ? 1'b1 : inte_ff1;
  /* T80.vhd:1230:49  */
  assign n1731_o = n1728_o & setei;
  /* T80.vhd:1229:41  */
  assign n1733_o = n1736_o ? 1'b1 : inte_ff2;
  /* T80.vhd:1238:49  */
  assign n1734_o = i_retn ? inte_ff2 : n1730_o;
  /* T80.vhd:1229:41  */
  assign n1735_o = n1727_o ? n1734_o : inte_ff1;
  /* T80.vhd:1229:41  */
  assign n1736_o = setei & n1727_o;
  /* T80.vhd:1242:51  */
  assign n1738_o = tstate == 3'b011;
  /* T80.vhd:1242:41  */
  assign n1740_o = n1743_o ? 1'b0 : n1735_o;
  /* T80.vhd:1242:41  */
  assign n1742_o = n1744_o ? 1'b0 : n1733_o;
  /* T80.vhd:1242:41  */
  assign n1743_o = setdi & n1738_o;
  /* T80.vhd:1242:41  */
  assign n1744_o = setdi & n1738_o;
  /* T80.vhd:1248:59  */
  assign n1745_o = intcycle | nmicycle;
  /* T80.vhd:1248:41  */
  assign n1747_o = n1745_o ? 1'b0 : halt_ff;
  /* T80.vhd:1251:51  */
  assign n1749_o = mcycle == 3'b001;
  /* T80.vhd:1251:70  */
  assign n1751_o = tstate == 3'b010;
  /* T80.vhd:1251:59  */
  assign n1752_o = n1751_o & n1749_o;
  /* T80.vhd:1251:74  */
  assign n1753_o = WAIT_n & n1752_o;
  /* T80.vhd:1251:41  */
  assign n1755_o = n1753_o ? 1'b1 : n2056_q;
  /* T80.vhd:1254:65  */
  assign n1756_o = busack & busreq_s;
  /* T80.vhd:1254:44  */
  assign n1757_o = ~n1756_o;
  /* T80.vhd:1256:59  */
  assign n1759_o = tstate == 3'b010;
  /* T80.vhd:1256:74  */
  assign n1760_o = ~WAIT_n;
  /* T80.vhd:1256:63  */
  assign n1761_o = n1760_o & n1759_o;
  /* T80.vhd:1257:49  */
  assign n1763_o = n1878_o ? 1'b1 : n1747_o;
  /* T80.vhd:1268:79  */
  assign n1765_o = ir == 8'b00110110;
  /* T80.vhd:1268:105  */
  assign n1766_o = {30'b0, Mode_Sel};  //  uext
  /* T80.vhd:1268:105  */
  assign n1768_o = n1766_o == 32'b00000000000000000000000000000000;
  /* T80.vhd:1268:92  */
  assign n1769_o = n1768_o & n1765_o;
  /* T80.vhd:1268:73  */
  assign n1771_o = n1769_o ? 3'b010 : mcycle;
  /* T80.vhd:1271:79  */
  assign n1773_o = mcycle == 3'b111;
  /* T80.vhd:1271:99  */
  assign n1775_o = mcycle == 3'b110;
  /* T80.vhd:1271:120  */
  assign n1776_o = {30'b0, Mode_Sel};  //  uext
  /* T80.vhd:1271:120  */
  assign n1778_o = n1776_o == 32'b00000000000000000000000000000001;
  /* T80.vhd:1271:107  */
  assign n1779_o = n1778_o & n1775_o;
  /* T80.vhd:1271:133  */
  assign n1781_o = iset != 2'b01;
  /* T80.vhd:1271:124  */
  assign n1782_o = n1781_o & n1779_o;
  /* T80.vhd:1271:88  */
  assign n1783_o = n1773_o | n1782_o;
  /* T80.vhd:1272:121  */
  assign n1785_o = pre_xy_f_m + 3'b001;
  /* T80.vhd:1273:79  */
  assign n1786_o = mcycle == mcycles;
  /* T80.vhd:1273:90  */
  assign n1787_o = n1786_o | no_btr;
  /* T80.vhd:1273:117  */
  assign n1789_o = mcycle == 3'b010;
  /* T80.vhd:1273:125  */
  assign n1790_o = i_djnz & n1789_o;
  /* T80.vhd:1273:142  */
  assign n1791_o = incdecz & n1790_o;
  /* T80.vhd:1273:106  */
  assign n1792_o = n1787_o | n1791_o;
  /* T80.vhd:1278:99  */
  assign n1794_o = prefix == 2'b00;
  /* T80.vhd:1278:88  */
  assign n1795_o = n1794_o & nmi_s;
  /* T80.vhd:1282:103  */
  assign n1796_o = ~INT_n;
  /* T80.vhd:1282:94  */
  assign n1797_o = n1796_o & inte_ff1;
  /* T80.vhd:1282:119  */
  assign n1799_o = prefix == 2'b00;
  /* T80.vhd:1282:108  */
  assign n1800_o = n1799_o & n1797_o;
  /* T80.vhd:1282:136  */
  assign n1801_o = ~setei;
  /* T80.vhd:1282:126  */
  assign n1802_o = n1801_o & n1800_o;
  /* T80.vhd:1282:73  */
  assign n1804_o = n1802_o ? 1'b0 : n1740_o;
  /* T80.vhd:1282:73  */
  assign n1806_o = n1802_o ? 1'b0 : n1742_o;
  /* T80.vhd:1282:73  */
  assign n1809_o = n1802_o ? 1'b1 : 1'b0;
  /* T80.vhd:1278:73  */
  assign n1811_o = n1795_o ? 1'b0 : n1804_o;
  /* T80.vhd:1278:73  */
  assign n1812_o = n1795_o ? n1742_o : n1806_o;
  /* T80.vhd:1273:65  */
  assign n1814_o = n1830_o ? 1'b0 : n1698_o;
  /* T80.vhd:1278:73  */
  assign n1816_o = n1795_o ? 1'b0 : n1809_o;
  /* T80.vhd:1278:73  */
  assign n1820_o = n1795_o ? 1'b1 : 1'b0;
  /* T80.vhd:1288:117  */
  assign n1823_o = mcycle + 3'b001;
  /* T80.vhd:1273:65  */
  assign n1825_o = n1792_o ? 1'b0 : n1755_o;
  /* T80.vhd:1273:65  */
  assign n1827_o = n1792_o ? 3'b001 : n1823_o;
  /* T80.vhd:1273:65  */
  assign n1828_o = n1792_o ? n1811_o : n1740_o;
  /* T80.vhd:1273:65  */
  assign n1829_o = n1792_o ? n1812_o : n1742_o;
  /* T80.vhd:1273:65  */
  assign n1830_o = n1795_o & n1792_o;
  /* T80.vhd:1273:65  */
  assign n1831_o = n1792_o ? n1816_o : intcycle;
  /* T80.vhd:1273:65  */
  assign n1832_o = n1792_o ? n1820_o : nmicycle;
  /* T80.vhd:1271:65  */
  assign n1833_o = n1783_o ? n1755_o : n1825_o;
  /* T80.vhd:1271:65  */
  assign n1834_o = n1783_o ? n1785_o : n1827_o;
  /* T80.vhd:1271:65  */
  assign n1835_o = n1783_o ? n1740_o : n1828_o;
  /* T80.vhd:1271:65  */
  assign n1836_o = n1783_o ? n1742_o : n1829_o;
  /* T80.vhd:1271:65  */
  assign n1837_o = n1783_o ? n1698_o : n1814_o;
  /* T80.vhd:1271:65  */
  assign n1838_o = n1783_o ? intcycle : n1831_o;
  /* T80.vhd:1271:65  */
  assign n1839_o = n1783_o ? nmicycle : n1832_o;
  /* T80.vhd:1265:65  */
  assign n1840_o = nextis_xy_fetch ? n1755_o : n1833_o;
  /* T80.vhd:1265:65  */
  assign n1842_o = nextis_xy_fetch ? 3'b110 : n1834_o;
  /* T80.vhd:1265:65  */
  assign n1843_o = nextis_xy_fetch ? n1740_o : n1835_o;
  /* T80.vhd:1265:65  */
  assign n1844_o = nextis_xy_fetch ? n1742_o : n1836_o;
  /* T80.vhd:1265:65  */
  assign n1845_o = nextis_xy_fetch ? n1698_o : n1837_o;
  /* T80.vhd:1265:65  */
  assign n1846_o = nextis_xy_fetch ? n1771_o : pre_xy_f_m;
  /* T80.vhd:1265:65  */
  assign n1847_o = nextis_xy_fetch ? intcycle : n1838_o;
  /* T80.vhd:1265:65  */
  assign n1848_o = nextis_xy_fetch ? nmicycle : n1839_o;
  /* T80.vhd:1261:57  */
  assign n1849_o = busreq_s ? n1755_o : n1840_o;
  /* T80.vhd:1261:57  */
  assign n1851_o = busreq_s ? tstate : 3'b001;
  /* T80.vhd:1261:57  */
  assign n1852_o = busreq_s ? mcycle : n1842_o;
  /* T80.vhd:1261:57  */
  assign n1853_o = busreq_s ? n1740_o : n1843_o;
  /* T80.vhd:1261:57  */
  assign n1854_o = busreq_s ? n1742_o : n1844_o;
  /* T80.vhd:1261:57  */
  assign n1857_o = busreq_s ? 1'b1 : 1'b0;
  /* T80.vhd:1261:57  */
  assign n1858_o = busreq_s ? n1698_o : n1845_o;
  /* T80.vhd:1261:57  */
  assign n1859_o = busreq_s ? pre_xy_f_m : n1846_o;
  /* T80.vhd:1261:57  */
  assign n1860_o = busreq_s ? intcycle : n1847_o;
  /* T80.vhd:1261:57  */
  assign n1861_o = busreq_s ? nmicycle : n1848_o;
  /* T80.vhd:1292:94  */
  assign n1862_o = ~auto_wait_t2;
  /* T80.vhd:1292:77  */
  assign n1863_o = n1862_o & auto_wait;
  /* T80.vhd:1293:77  */
  assign n1865_o = iorq_i & 1'b1;
  /* T80.vhd:1293:111  */
  assign n1866_o = ~auto_wait_t1;
  /* T80.vhd:1293:94  */
  assign n1867_o = n1866_o & n1865_o;
  /* T80.vhd:1292:101  */
  assign n1868_o = n1863_o | n1867_o;
  /* T80.vhd:1292:101  */
  assign n1869_o = ~n1868_o;
  /* T80.vhd:1294:82  */
  assign n1871_o = tstate + 3'b001;
  /* T80.vhd:1292:57  */
  assign n1872_o = n1869_o ? n1871_o : tstate;
  /* T80.vhd:1257:49  */
  assign n1873_o = t_res ? n1849_o : n1755_o;
  /* T80.vhd:1257:49  */
  assign n1874_o = t_res ? n1851_o : n1872_o;
  /* T80.vhd:1257:49  */
  assign n1875_o = t_res ? n1852_o : mcycle;
  /* T80.vhd:1257:49  */
  assign n1876_o = t_res ? n1853_o : n1740_o;
  /* T80.vhd:1257:49  */
  assign n1877_o = t_res ? n1854_o : n1742_o;
  /* T80.vhd:1257:49  */
  assign n1878_o = halt & t_res;
  /* T80.vhd:1257:49  */
  assign n1880_o = t_res ? n1857_o : 1'b0;
  /* T80.vhd:1257:49  */
  assign n1881_o = t_res ? n1858_o : n1698_o;
  /* T80.vhd:1257:49  */
  assign n1882_o = t_res ? n1859_o : pre_xy_f_m;
  /* T80.vhd:1257:49  */
  assign n1883_o = t_res ? n1860_o : intcycle;
  /* T80.vhd:1257:49  */
  assign n1884_o = t_res ? n1861_o : nmicycle;
  /* T80.vhd:1256:49  */
  assign n1885_o = n1761_o ? n1755_o : n1873_o;
  /* T80.vhd:1256:49  */
  assign n1886_o = n1761_o ? tstate : n1874_o;
  /* T80.vhd:1256:49  */
  assign n1887_o = n1761_o ? mcycle : n1875_o;
  /* T80.vhd:1256:49  */
  assign n1888_o = n1761_o ? n1740_o : n1876_o;
  /* T80.vhd:1256:49  */
  assign n1889_o = n1761_o ? n1742_o : n1877_o;
  /* T80.vhd:1256:49  */
  assign n1890_o = n1761_o ? n1747_o : n1763_o;
  /* T80.vhd:1256:49  */
  assign n1892_o = n1761_o ? 1'b0 : n1880_o;
  /* T80.vhd:1256:49  */
  assign n1894_o = n1761_o ? n1698_o : n1881_o;
  /* T80.vhd:1256:49  */
  assign n1895_o = n1761_o ? pre_xy_f_m : n1882_o;
  /* T80.vhd:1256:49  */
  assign n1896_o = n1761_o ? intcycle : n1883_o;
  /* T80.vhd:1256:49  */
  assign n1897_o = n1761_o ? nmicycle : n1884_o;
  /* T80.vhd:1254:41  */
  assign n1898_o = n1757_o ? n1885_o : n1755_o;
  /* T80.vhd:1217:33  */
  assign n1899_o = n1914_o ? n1886_o : tstate;
  /* T80.vhd:1217:33  */
  assign n1900_o = n1915_o ? n1887_o : mcycle;
  /* T80.vhd:1254:41  */
  assign n1901_o = n1757_o ? n1888_o : n1740_o;
  /* T80.vhd:1254:41  */
  assign n1902_o = n1757_o ? n1889_o : n1742_o;
  /* T80.vhd:1254:41  */
  assign n1903_o = n1757_o ? n1890_o : n1747_o;
  /* T80.vhd:1217:33  */
  assign n1904_o = n1920_o ? n1892_o : busack;
  /* T80.vhd:1217:33  */
  assign n1905_o = n1921_o ? n1894_o : n1698_o;
  /* T80.vhd:1217:33  */
  assign n1906_o = n1922_o ? n1895_o : pre_xy_f_m;
  /* T80.vhd:1217:33  */
  assign n1907_o = n1926_o ? n1896_o : intcycle;
  /* T80.vhd:1217:33  */
  assign n1908_o = n1927_o ? n1897_o : nmicycle;
  /* T80.vhd:1298:51  */
  assign n1910_o = tstate == 3'b000;
  /* T80.vhd:1298:41  */
  assign n1912_o = n1910_o ? 1'b0 : n1898_o;
  /* T80.vhd:1217:33  */
  assign n1913_o = CEN ? n1912_o : n2056_q;
  /* T80.vhd:1217:33  */
  assign n1914_o = n1757_o & CEN;
  /* T80.vhd:1217:33  */
  assign n1915_o = n1757_o & CEN;
  /* T80.vhd:1217:33  */
  assign n1916_o = CEN ? n1901_o : inte_ff1;
  /* T80.vhd:1217:33  */
  assign n1917_o = CEN ? n1902_o : inte_ff2;
  /* T80.vhd:1217:33  */
  assign n1918_o = CEN ? n1903_o : halt_ff;
  /* T80.vhd:1217:33  */
  assign n1919_o = CEN ? n1699_o : busreq_s;
  /* T80.vhd:1217:33  */
  assign n1920_o = n1757_o & CEN;
  /* T80.vhd:1217:33  */
  assign n1921_o = n1757_o & CEN;
  /* T80.vhd:1217:33  */
  assign n1922_o = n1757_o & CEN;
  /* T80.vhd:1217:33  */
  assign n1923_o = CEN ? n1725_o : no_btr;
  /* T80.vhd:1217:33  */
  assign n1924_o = CEN ? n1702_o : auto_wait_t1;
  /* T80.vhd:1217:33  */
  assign n1925_o = CEN ? n1704_o : auto_wait_t2;
  /* T80.vhd:1217:33  */
  assign n1926_o = n1757_o & CEN;
  /* T80.vhd:1217:33  */
  assign n1927_o = n1757_o & CEN;
  /* T80.vhd:1208:25  */
  assign n1928_o = DIRSet ? n2056_q : n1913_o;
  /* T80.vhd:1208:25  */
  assign n1929_o = DIRSet ? tstate : n1899_o;
  /* T80.vhd:1208:25  */
  assign n1930_o = DIRSet ? mcycle : n1900_o;
  /* T80.vhd:1208:25  */
  assign n1931_o = DIRSet ? n1694_o : n1916_o;
  /* T80.vhd:1208:25  */
  assign n1932_o = DIRSet ? n1693_o : n1917_o;
  /* T80.vhd:1208:25  */
  assign n1933_o = DIRSet ? halt_ff : n1918_o;
  /* T80.vhd:1208:25  */
  assign n1934_o = DIRSet ? busreq_s : n1919_o;
  /* T80.vhd:1208:25  */
  assign n1935_o = DIRSet ? busack : n1904_o;
  /* T80.vhd:1208:25  */
  assign n1936_o = DIRSet ? nmi_s : n1905_o;
  /* T80.vhd:1208:25  */
  assign n1937_o = DIRSet ? pre_xy_f_m : n1906_o;
  /* T80.vhd:1208:25  */
  assign n1938_o = DIRSet ? no_btr : n1923_o;
  /* T80.vhd:1208:25  */
  assign n1939_o = DIRSet ? auto_wait_t1 : n1924_o;
  /* T80.vhd:1208:25  */
  assign n1940_o = DIRSet ? auto_wait_t2 : n1925_o;
  /* T80.vhd:1208:25  */
  assign n1941_o = DIRSet ? intcycle : n1907_o;
  /* T80.vhd:1208:25  */
  assign n1942_o = DIRSet ? nmicycle : n1908_o;
  /* T80.vhd:1208:25  */
  assign n1943_o = DIRSet ? n1688_oldnmi_n : NMI_n;
  /* T80.vhd:1187:9  */
  assign n1992_o = ~n1691_o;
  /* T80.vhd:1206:17  */
  assign n1993_o = n1992_o ? n1943_o : n1688_oldnmi_n;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n)
    n1994_q <= n1993_o;
  /* T80.vhd:1306:57  */
  assign n1997_o = mcycle == 3'b001;
  /* T80.vhd:1306:46  */
  assign n1998_o = n1997_o & intcycle;
  /* T80.vhd:1306:26  */
  assign n1999_o = n1998_o ? 1'b1 : 1'b0;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2001_q <= 8'b11111111;
    else
      n2001_q <= n1167_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2002_q <= 8'b11111111;
    else
      n2002_q <= n1168_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2003_q <= 8'b11111111;
    else
      n2003_q <= n1169_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2004_q <= 8'b11111111;
    else
      n2004_q <= n1170_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2005_q <= 8'b00000000;
    else
      n2005_q <= n1171_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2006_q <= 8'b00000000;
    else
      n2006_q <= n1172_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2007_q <= 16'b1111111111111111;
    else
      n2007_q <= n1173_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2008_q <= 16'b0000000000000000;
    else
      n2008_q <= n1174_o;
  /* T80.vhd:504:17  */
  assign n2009_o = {u_regs_n1540, u_regs_n1541};
  /* T80.vhd:504:17  */
  assign n2010_o = {u_regs_n1542, u_regs_n1543};
  /* T80.vhd:504:17  */
  assign n2011_o = {u_regs_n1544, u_regs_n1545};
  /* T80.vhd:949:17  */
  assign n2012_o = clken ? n1298_o : regaddra_r;
  /* T80.vhd:949:17  */
  always @(posedge CLK_n)
    n2013_q <= n2012_o;
  /* T80.vhd:949:17  */
  assign n2014_o = clken ? n1312_o : regaddrb_r;
  /* T80.vhd:949:17  */
  always @(posedge CLK_n)
    n2015_q <= n2014_o;
  /* T80.vhd:949:17  */
  assign n2016_o = clken ? n1329_o : regaddrc;
  /* T80.vhd:949:17  */
  always @(posedge CLK_n)
    n2017_q <= n2016_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2018_q <= 1'b0;
    else
      n2018_q <= n1175_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2019_q <= 16'b0000000000000000;
    else
      n2019_q <= n1176_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2020_q <= 8'b00000000;
    else
      n2020_q <= n1177_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2021_q <= 2'b00;
    else
      n2021_q <= n1178_o;
  /* T80.vhd:949:17  */
  assign n2022_o = clken ? regbusa : regbusa_r;
  /* T80.vhd:949:17  */
  always @(posedge CLK_n)
    n2023_q <= n2022_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2024_q <= 3'b000;
    else
      n2024_q <= n1929_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2025_q <= 3'b001;
    else
      n2025_q <= n1930_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2026_q <= 1'b0;
    else
      n2026_q <= n1931_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2027_q <= 1'b0;
    else
      n2027_q <= n1932_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2028_q <= 1'b0;
    else
      n2028_q <= n1933_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2029_q <= 1'b0;
    else
      n2029_q <= n1934_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2030_q <= 1'b0;
    else
      n2030_q <= n1935_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2031_q <= 1'b0;
    else
      n2031_q <= n1936_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2032_q <= 2'b00;
    else
      n2032_q <= n1179_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2033_q <= 2'b00;
    else
      n2033_q <= n1180_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2034_q <= 3'b000;
    else
      n2034_q <= n1937_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2035_q <= 1'b0;
    else
      n2035_q <= n1181_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2036_q <= 1'b0;
    else
      n2036_q <= n1938_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2037_q <= 1'b0;
    else
      n2037_q <= n1182_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2038_q <= 1'b0;
    else
      n2038_q <= n1939_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2039_q <= 1'b0;
    else
      n2039_q <= n1940_o;
  /* T80.vhd:949:17  */
  assign n2040_o = clken ? n1354_o : incdecz;
  /* T80.vhd:949:17  */
  always @(posedge CLK_n)
    n2041_q <= n2040_o;
  /* T80.vhd:1089:17  */
  assign n2042_o = clken ? n1655_o : busb;
  /* T80.vhd:1089:17  */
  always @(posedge CLK_n)
    n2043_q <= n2042_o;
  /* T80.vhd:1089:17  */
  assign n2044_o = clken ? n1656_o : busa;
  /* T80.vhd:1089:17  */
  always @(posedge CLK_n)
    n2045_q <= n2044_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2046_q <= 5'b00000;
    else
      n2046_q <= n1183_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2047_q <= 1'b0;
    else
      n2047_q <= n1184_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2048_q <= 1'b0;
    else
      n2048_q <= n1185_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2049_q <= 4'b0000;
    else
      n2049_q <= n1186_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2050_q <= 1'b0;
    else
      n2050_q <= n1187_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2051_q <= 1'b0;
    else
      n2051_q <= n1188_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2052_q <= 3'b000;
    else
      n2052_q <= n1189_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2053_q <= 1'b0;
    else
      n2053_q <= n1941_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2054_q <= 1'b0;
    else
      n2054_q <= n1942_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2055_q <= 1'b0;
    else
      n2055_q <= n1190_o;
  /* T80.vhd:1206:17  */
  always @(posedge CLK_n or posedge n1691_o)
    if (n1691_o)
      n2056_q <= 1'b1;
    else
      n2056_q <= n1928_o;
  /* T80.vhd:1161:17  */
  assign n2057_o = n1667_o ? n1679_o : n2058_q;
  /* T80.vhd:1161:17  */
  always @(posedge CLK_n or posedge n1664_o)
    if (n1664_o)
      n2058_q <= 1'b1;
    else
      n2058_q <= n2057_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2059_q <= 16'b0000000000000000;
    else
      n2059_q <= n1165_o;
  /* T80.vhd:534:17  */
  always @(posedge CLK_n or posedge n232_o)
    if (n232_o)
      n2060_q <= 8'b00000000;
    else
      n2060_q <= n1166_o;
endmodule

module T80s #(parameter Mode = 0)
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
  wire [211:0] regs;
  // Register assignments for debugging. Names
  // match MAME's debugger names
// IFF2, IFF1, IM, IY, HL', DE', BC', IX, HL, DE, BC, PC, SP, R, I, F', A', F, A
wire [15:0] AF, BC, DE, HL, AF2, BC2, DE2, HL2,IX,IY,PC,SP;
wire [ 7:0] I,R;
assign {IY,HL2,DE2,BC2,IX,HL,DE,BC,PC,SP,R,I,AF2[7:0],AF2[15:8],AF[7:0],AF[15:8]} = regs[0+:208];
  T80 u0 (
    .RESET_n    ( RESET_n       ),
    .CLK_n      ( CLK           ),
    .CEN        ( CEN           ),
    .WAIT_n     ( WAIT_n        ),
    .INT_n      ( INT_n         ),
    .NMI_n      ( NMI_n         ),
    .BUSRQ_n    ( BUSRQ_n       ),
    .DInst      ( DI            ),
    .DI         ( di_reg        ),
    .out0       ( OUT0          ),
    .DIRSet     ( n25_o         ),
    .DIR        ( n26_o         ),
    .Mode_Sel   ( Mode[1:0]     ),
    .M1_n       ( u0_m1_n       ),
    .IORQ       ( u0_iorq       ),
    .NoRead     ( u0_noread     ),
    .Write      ( u0_write      ),
    .RFSH_n     ( u0_rfsh_n     ),
    .HALT_n     ( u0_halt_n     ),
    .BUSAK_n    ( u0_busak_n    ),
    .A          ( u0_a          ),
    .DOUT       ( u0_dout       ),
    .MC         ( u0_mc         ),
    .TS         ( u0_ts         ),
    .IntCycle_n ( u0_intcycle_n ),
    .IntE       (               ),
    .Stop       (               ),
    .REGS       ( regs          )
  );
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
  assign n129_o = CEN & n123_o;
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
