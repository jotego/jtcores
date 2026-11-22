// GHDL 4.1.0 output for T80.vhd from T80s synthesis with -gMode=2.
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
module t80_8080
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
  t80_8080_mcode mcode (
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
  t80_8080_alu u_alu (
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
  t80_8080_reg u_regs (
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
