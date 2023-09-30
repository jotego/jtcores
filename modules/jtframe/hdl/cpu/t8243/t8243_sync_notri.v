module t8243_core_1
  (input  clk_i,
   input  clk_rise_en_i,
   input  clk_fall_en_i,
   input  reset_n_i,
   input  cs_n_i,
   input  prog_n_i,
   input  [3:0] p2_i,
   input  [3:0] p4_i,
   input  [3:0] p5_i,
   input  [3:0] p6_i,
   input  [3:0] p7_i,
   output [3:0] p2_o,
   output p2_en_o,
   output [3:0] p4_o,
   output p4_en_o,
   output [3:0] p5_o,
   output p5_en_o,
   output [3:0] p6_o,
   output p6_en_o,
   output [3:0] p7_o,
   output p7_en_o);
  wire [1:0] instr_q;
  wire [3:0] px_sel_q;
  wire [3:0] px_en_q;
  wire p2_en_q;
  wire [15:0] px_latch_q;
  wire [3:0] data_s;
  wire [3:0] p2_s;
  wire [3:0] p4_s;
  wire [3:0] p5_s;
  wire [3:0] p6_s;
  wire [3:0] p7_s;
  wire n68_o;
  wire n69_o;
  wire [1:0] n70_o;
  wire [30:0] n71_o;
  wire [31:0] n72_o;
  wire [31:0] n74_o;
  wire [1:0] n75_o;
  wire [1:0] n77_o;
  localparam [3:0] n79_o = 4'b0000;
  wire [1:0] n83_o;
  wire n85_o;
  wire n87_o;
  wire n89_o;
  wire n91_o;
  wire [3:0] n92_o;
  reg [1:0] n97_o;
  reg n100_o;
  wire n116_o;
  wire n118_o;
  wire n119_o;
  wire n120_o;
  wire n122_o;
  wire n125_o;
  wire [3:0] n126_o;
  wire [3:0] n127_o;
  wire n128_o;
  wire n129_o;
  wire [3:0] n130_o;
  wire [3:0] n131_o;
  wire n132_o;
  wire n134_o;
  wire n137_o;
  wire [3:0] n138_o;
  wire [3:0] n139_o;
  wire n140_o;
  wire n141_o;
  wire [3:0] n142_o;
  wire [3:0] n143_o;
  wire n144_o;
  wire n146_o;
  wire n149_o;
  wire [3:0] n150_o;
  wire [3:0] n151_o;
  wire n152_o;
  wire n153_o;
  wire [3:0] n154_o;
  wire [3:0] n155_o;
  wire n156_o;
  wire n158_o;
  wire n161_o;
  wire [3:0] n162_o;
  wire [3:0] n163_o;
  wire n164_o;
  wire n165_o;
  wire [3:0] n166_o;
  wire [3:0] n167_o;
  wire [3:0] n168_o;
  wire [15:0] n170_o;
  wire [3:0] n181_o;
  wire n183_o;
  wire [3:0] n184_o;
  wire n186_o;
  wire [3:0] n187_o;
  wire n189_o;
  wire [3:0] n190_o;
  wire n192_o;
  wire [3:0] n193_o;
  reg [3:0] n195_o;
  reg [3:0] n197_o;
  wire n199_o;
  wire [3:0] n200_o;
  wire n202_o;
  wire [3:0] n203_o;
  wire n205_o;
  wire [2:0] n206_o;
  reg [3:0] n208_o;
  wire n211_o;
  wire n212_o;
  wire n213_o;
  wire n214_o;
  wire n215_o;
  wire [3:0] n217_o;
  wire n218_o;
  wire [3:0] n219_o;
  wire n220_o;
  wire [3:0] n221_o;
  wire n222_o;
  wire [3:0] n223_o;
  wire n224_o;
  wire [1:0] n225_o;
  reg [1:0] n226_q;
  wire [3:0] n227_o;
  reg [3:0] n228_q;
  wire [3:0] n229_o;
  reg [3:0] n230_q;
  wire n231_o;
  reg n232_q;
  wire [15:0] n233_o;
  reg [15:0] n234_q;
  wire n235_o;
  wire n236_o;
  wire n237_o;
  wire n238_o;
  wire n239_o;
  wire n240_o;
  wire n241_o;
  wire n242_o;
  wire n243_o;
  wire n244_o;
  wire n245_o;
  wire n246_o;
  wire n247_o;
  wire n248_o;
  wire n249_o;
  wire n250_o;
  wire [3:0] n251_o;
  assign p2_o = n195_o;
  assign p2_en_o = n215_o;
  assign p4_o = n217_o;
  assign p4_en_o = n218_o;
  assign p5_o = n219_o;
  assign p5_en_o = n220_o;
  assign p6_o = n221_o;
  assign p6_en_o = n222_o;
  assign p7_o = n223_o;
  assign p7_en_o = n224_o;
  /* t8243_core.vhd:107:12  */
  assign instr_q = n226_q; // (signal)
  /* t8243_core.vhd:115:11  */
  assign px_sel_q = n228_q; // (signal)
  /* t8243_core.vhd:117:11  */
  assign px_en_q = n230_q; // (signal)
  /* t8243_core.vhd:118:11  */
  assign p2_en_q = n232_q; // (signal)
  /* t8243_core.vhd:122:11  */
  assign px_latch_q = n234_q; // (signal)
  /* t8243_core.vhd:124:11  */
  assign data_s = n208_o; // (signal)
  /* t8243_core.vhd:126:11  */
  assign p2_s = p2_i; // (signal)
  /* t8243_core.vhd:127:11  */
  assign p4_s = p4_i; // (signal)
  /* t8243_core.vhd:128:11  */
  assign p5_s = p5_i; // (signal)
  /* t8243_core.vhd:129:11  */
  assign p6_s = p6_i; // (signal)
  /* t8243_core.vhd:130:11  */
  assign p7_s = p7_i; // (signal)
  /* t8243_core.vhd:157:17  */
  assign n68_o = ~cs_n_i;
  /* t8243_core.vhd:157:23  */
  assign n69_o = clk_fall_en_i & n68_o;
  /* t8243_core.vhd:160:42  */
  assign n70_o = p2_s[1:0];
  /* t8243_core.vhd:160:18  */
  assign n71_o = {29'b0, n70_o};  //  uext
  /* t8243_core.vhd:160:57  */
  assign n72_o = {1'b0, n71_o};  //  uext
  /* t8243_core.vhd:160:57  */
  assign n74_o = n72_o + 32'b00000000000000000000000000000100;
  /* t8243_core.vhd:160:57  */
  assign n75_o = n74_o[1:0];  // trunc
  /* t8243_core.vhd:160:57  */
  assign n77_o = n75_o - 2'b00;
  /* t8243_core.vhd:166:18  */
  assign n83_o = p2_s[3:2];
  /* t8243_core.vhd:167:11  */
  assign n85_o = n83_o == 2'b00;
  /* t8243_core.vhd:170:11  */
  assign n87_o = n83_o == 2'b01;
  /* t8243_core.vhd:172:11  */
  assign n89_o = n83_o == 2'b10;
  /* t8243_core.vhd:174:11  */
  assign n91_o = n83_o == 2'b11;
  assign n92_o = {n91_o, n89_o, n87_o, n85_o};
  /* t8243_core.vhd:166:9  */
  always @*
    case (n92_o)
      4'b1000: n97_o = 2'b11;
      4'b0100: n97_o = 2'b10;
      4'b0010: n97_o = 2'b01;
      4'b0001: n97_o = 2'b00;
      default: n97_o = instr_q;
    endcase
  /* t8243_core.vhd:166:9  */
  always @*
    case (n92_o)
      4'b1000: n100_o = 1'b0;
      4'b0100: n100_o = 1'b0;
      4'b0010: n100_o = 1'b0;
      4'b0001: n100_o = 1'b1;
      default: n100_o = 1'b0;
    endcase
  /* t8243_core.vhd:196:18  */
  assign n116_o = ~reset_n_i;
  /* t8243_core.vhd:201:17  */
  assign n118_o = ~cs_n_i;
  /* t8243_core.vhd:201:23  */
  assign n119_o = clk_rise_en_i & n118_o;
  /* t8243_core.vhd:203:22  */
  assign n120_o = px_sel_q[3];
  /* t8243_core.vhd:204:24  */
  assign n122_o = instr_q == 2'b00;
  /* t8243_core.vhd:204:13  */
  assign n125_o = n122_o ? 1'b0 : 1'b1;
  assign n126_o = px_latch_q[15:12];
  /* t8243_core.vhd:204:13  */
  assign n127_o = n122_o ? n126_o : data_s;
  assign n128_o = px_en_q[3];
  /* t8243_core.vhd:203:11  */
  assign n129_o = n120_o ? n125_o : n128_o;
  assign n130_o = px_latch_q[15:12];
  /* t8243_core.vhd:203:11  */
  assign n131_o = n120_o ? n127_o : n130_o;
  /* t8243_core.vhd:203:22  */
  assign n132_o = px_sel_q[2];
  /* t8243_core.vhd:204:24  */
  assign n134_o = instr_q == 2'b00;
  /* t8243_core.vhd:204:13  */
  assign n137_o = n134_o ? 1'b0 : 1'b1;
  assign n138_o = px_latch_q[11:8];
  /* t8243_core.vhd:204:13  */
  assign n139_o = n134_o ? n138_o : data_s;
  assign n140_o = px_en_q[2];
  /* t8243_core.vhd:203:11  */
  assign n141_o = n132_o ? n137_o : n140_o;
  assign n142_o = px_latch_q[11:8];
  /* t8243_core.vhd:203:11  */
  assign n143_o = n132_o ? n139_o : n142_o;
  /* t8243_core.vhd:203:22  */
  assign n144_o = px_sel_q[1];
  /* t8243_core.vhd:204:24  */
  assign n146_o = instr_q == 2'b00;
  /* t8243_core.vhd:204:13  */
  assign n149_o = n146_o ? 1'b0 : 1'b1;
  assign n150_o = px_latch_q[7:4];
  /* t8243_core.vhd:204:13  */
  assign n151_o = n146_o ? n150_o : data_s;
  assign n152_o = px_en_q[1];
  /* t8243_core.vhd:203:11  */
  assign n153_o = n144_o ? n149_o : n152_o;
  assign n154_o = px_latch_q[7:4];
  /* t8243_core.vhd:203:11  */
  assign n155_o = n144_o ? n151_o : n154_o;
  /* t8243_core.vhd:203:22  */
  assign n156_o = px_sel_q[0];
  /* t8243_core.vhd:204:24  */
  assign n158_o = instr_q == 2'b00;
  /* t8243_core.vhd:204:13  */
  assign n161_o = n158_o ? 1'b0 : 1'b1;
  assign n162_o = px_latch_q[3:0];
  /* t8243_core.vhd:204:13  */
  assign n163_o = n158_o ? n162_o : data_s;
  assign n164_o = px_en_q[0];
  /* t8243_core.vhd:203:11  */
  assign n165_o = n156_o ? n161_o : n164_o;
  assign n166_o = px_latch_q[3:0];
  /* t8243_core.vhd:203:11  */
  assign n167_o = n156_o ? n163_o : n166_o;
  assign n168_o = {n129_o, n141_o, n153_o, n165_o};
  assign n170_o = {n131_o, n143_o, n155_o, n167_o};
  /* t8243_core.vhd:244:29  */
  assign n181_o = px_latch_q[3:0];
  /* t8243_core.vhd:243:7  */
  assign n183_o = px_sel_q == 4'b0001;
  /* t8243_core.vhd:247:29  */
  assign n184_o = px_latch_q[7:4];
  /* t8243_core.vhd:246:7  */
  assign n186_o = px_sel_q == 4'b0010;
  /* t8243_core.vhd:250:29  */
  assign n187_o = px_latch_q[11:8];
  /* t8243_core.vhd:249:7  */
  assign n189_o = px_sel_q == 4'b0100;
  /* t8243_core.vhd:253:29  */
  assign n190_o = px_latch_q[15:12];
  /* t8243_core.vhd:252:7  */
  assign n192_o = px_sel_q == 4'b1000;
  assign n193_o = {n192_o, n189_o, n186_o, n183_o};
  /* t8243_core.vhd:242:5  */
  always @*
    case (n193_o)
      4'b1000: n195_o = p7_s;
      4'b0100: n195_o = p6_s;
      4'b0010: n195_o = p5_s;
      4'b0001: n195_o = p4_s;
      default: n195_o = 4'bX;
    endcase
  /* t8243_core.vhd:242:5  */
  always @*
    case (n193_o)
      4'b1000: n197_o = n190_o;
      4'b0100: n197_o = n187_o;
      4'b0010: n197_o = n184_o;
      4'b0001: n197_o = n181_o;
      default: n197_o = 4'bX;
    endcase
  /* t8243_core.vhd:261:7  */
  assign n199_o = instr_q == 2'b01;
  /* t8243_core.vhd:264:24  */
  assign n200_o = p2_s | n197_o;
  /* t8243_core.vhd:263:7  */
  assign n202_o = instr_q == 2'b10;
  /* t8243_core.vhd:266:24  */
  assign n203_o = p2_s & n197_o;
  /* t8243_core.vhd:265:7  */
  assign n205_o = instr_q == 2'b11;
  assign n206_o = {n205_o, n202_o, n199_o};
  /* t8243_core.vhd:260:5  */
  always @*
    case (n206_o)
      3'b100: n208_o = n203_o;
      3'b010: n208_o = n200_o;
      3'b001: n208_o = p2_s;
      default: n208_o = 4'bX;
    endcase
  /* t8243_core.vhd:280:26  */
  assign n211_o = ~cs_n_i;
  /* t8243_core.vhd:280:45  */
  assign n212_o = ~prog_n_i;
  /* t8243_core.vhd:280:32  */
  assign n213_o = n212_o & n211_o;
  /* t8243_core.vhd:280:51  */
  assign n214_o = p2_en_q & n213_o;
  /* t8243_core.vhd:280:14  */
  assign n215_o = n214_o ? 1'b1 : 1'b0;
  /* t8243_core.vhd:282:24  */
  assign n217_o = px_latch_q[3:0];
  /* t8243_core.vhd:283:21  */
  assign n218_o = px_en_q[0];
  /* t8243_core.vhd:284:24  */
  assign n219_o = px_latch_q[7:4];
  /* t8243_core.vhd:285:21  */
  assign n220_o = px_en_q[1];
  /* t8243_core.vhd:286:24  */
  assign n221_o = px_latch_q[11:8];
  /* t8243_core.vhd:287:21  */
  assign n222_o = px_en_q[2];
  /* t8243_core.vhd:288:24  */
  assign n223_o = px_latch_q[15:12];
  /* t8243_core.vhd:289:21  */
  assign n224_o = px_en_q[3];
  /* t8243_core.vhd:156:5  */
  assign n225_o = n69_o ? n97_o : instr_q;
  /* t8243_core.vhd:156:5  */
  always @(negedge clk_i or posedge cs_n_i)
    if (cs_n_i)
      n226_q <= 2'b01;
    else
      n226_q <= n225_o;
  /* t8243_core.vhd:156:5  */
  assign n227_o = n69_o ? n251_o : px_sel_q;
  /* t8243_core.vhd:156:5  */
  always @(negedge clk_i or posedge cs_n_i)
    if (cs_n_i)
      n228_q <= 4'b0000;
    else
      n228_q <= n227_o;
  /* t8243_core.vhd:200:5  */
  assign n229_o = n119_o ? n168_o : px_en_q;
  /* t8243_core.vhd:200:5  */
  always @(posedge clk_i or posedge n116_o)
    if (n116_o)
      n230_q <= 4'b0000;
    else
      n230_q <= n229_o;
  /* t8243_core.vhd:156:5  */
  assign n231_o = n69_o ? n100_o : p2_en_q;
  /* t8243_core.vhd:156:5  */
  always @(negedge clk_i or posedge cs_n_i)
    if (cs_n_i)
      n232_q <= 1'b0;
    else
      n232_q <= n231_o;
  /* t8243_core.vhd:200:5  */
  assign n233_o = n119_o ? n170_o : px_latch_q;
  /* t8243_core.vhd:200:5  */
  always @(posedge clk_i or posedge n116_o)
    if (n116_o)
      n234_q <= 16'b0000000000000000;
    else
      n234_q <= n233_o;
  /* t8243_core.vhd:160:9  */
  assign n235_o = n77_o[1];
  /* t8243_core.vhd:160:9  */
  assign n236_o = ~n235_o;
  /* t8243_core.vhd:160:9  */
  assign n237_o = n77_o[0];
  /* t8243_core.vhd:160:9  */
  assign n238_o = ~n237_o;
  /* t8243_core.vhd:160:9  */
  assign n239_o = n236_o & n238_o;
  /* t8243_core.vhd:160:9  */
  assign n240_o = n236_o & n237_o;
  /* t8243_core.vhd:160:9  */
  assign n241_o = n235_o & n238_o;
  /* t8243_core.vhd:160:9  */
  assign n242_o = n235_o & n237_o;
  /* t8243_core.vhd:68:5  */
  assign n243_o = n79_o[0];
  /* t8243_core.vhd:160:9  */
  assign n244_o = n239_o ? 1'b1 : n243_o;
  assign n245_o = n79_o[1];
  /* t8243_core.vhd:160:9  */
  assign n246_o = n240_o ? 1'b1 : n245_o;
  /* t8243_core.vhd:239:14  */
  assign n247_o = n79_o[2];
  /* t8243_core.vhd:160:9  */
  assign n248_o = n241_o ? 1'b1 : n247_o;
  assign n249_o = n79_o[3];
  /* t8243_core.vhd:160:9  */
  assign n250_o = n242_o ? 1'b1 : n249_o;
  /* t8243_core.vhd:200:5  */
  assign n251_o = {n250_o, n248_o, n246_o, n244_o};
endmodule

module t8243_sync_notri
  (input  clk_i,
   input  clk_en_i,
   input  reset_n_i,
   input  cs_n_i,
   input  prog_n_i,
   input  [3:0] p2_i,
   input  [3:0] p4_i,
   input  [3:0] p5_i,
   input  [3:0] p6_i,
   input  [3:0] p7_i,
   output [3:0] p2_o,
   output p2_en_o,
   output [3:0] p4_o,
   output p4_en_o,
   output [3:0] p5_o,
   output p5_en_o,
   output [3:0] p6_o,
   output p6_en_o,
   output [3:0] p7_o,
   output p7_en_o);
  wire prog_n_q;
  wire clk_rise_en_s;
  wire clk_fall_en_s;
  wire n11_o;
  wire n18_o;
  wire n19_o;
  wire n20_o;
  wire n21_o;
  wire n22_o;
  wire n23_o;
  wire [3:0] t8243_core_b_n24;
  wire t8243_core_b_n25;
  wire [3:0] t8243_core_b_n26;
  wire t8243_core_b_n27;
  wire [3:0] t8243_core_b_n28;
  wire t8243_core_b_n29;
  wire [3:0] t8243_core_b_n30;
  wire t8243_core_b_n31;
  wire [3:0] t8243_core_b_n32;
  wire t8243_core_b_n33;
  wire [3:0] t8243_core_b_p2_o;
  wire t8243_core_b_p2_en_o;
  wire [3:0] t8243_core_b_p4_o;
  wire t8243_core_b_p4_en_o;
  wire [3:0] t8243_core_b_p5_o;
  wire t8243_core_b_p5_en_o;
  wire [3:0] t8243_core_b_p6_o;
  wire t8243_core_b_p6_en_o;
  wire [3:0] t8243_core_b_p7_o;
  wire t8243_core_b_p7_en_o;
  wire n54_o;
  reg n55_q;
  assign p2_o = t8243_core_b_n24;
  assign p2_en_o = t8243_core_b_n25;
  assign p4_o = t8243_core_b_n26;
  assign p4_en_o = t8243_core_b_n27;
  assign p5_o = t8243_core_b_n28;
  assign p5_en_o = t8243_core_b_n29;
  assign p6_o = t8243_core_b_n30;
  assign p6_en_o = t8243_core_b_n31;
  assign p7_o = t8243_core_b_n32;
  assign p7_en_o = t8243_core_b_n33;
  /* t8243_sync_notri.vhd:88:10  */
  assign prog_n_q = n55_q; // (signal)
  /* t8243_sync_notri.vhd:89:10  */
  assign clk_rise_en_s = n20_o; // (signal)
  /* t8243_sync_notri.vhd:90:10  */
  assign clk_fall_en_s = n23_o; // (signal)
  /* t8243_sync_notri.vhd:103:18  */
  assign n11_o = ~reset_n_i;
  /* t8243_sync_notri.vhd:117:20  */
  assign n18_o = ~prog_n_q;
  /* t8243_sync_notri.vhd:116:29  */
  assign n19_o = clk_en_i & n18_o;
  /* t8243_sync_notri.vhd:117:33  */
  assign n20_o = n19_o & prog_n_i;
  /* t8243_sync_notri.vhd:118:29  */
  assign n21_o = clk_en_i & prog_n_q;
  /* t8243_sync_notri.vhd:119:33  */
  assign n22_o = ~prog_n_i;
  /* t8243_sync_notri.vhd:119:29  */
  assign n23_o = n21_o & n22_o;
  /* t8243_sync_notri.vhd:137:24  */
  assign t8243_core_b_n24 = t8243_core_b_p2_o; // (signal)
  /* t8243_sync_notri.vhd:138:24  */
  assign t8243_core_b_n25 = t8243_core_b_p2_en_o; // (signal)
  /* t8243_sync_notri.vhd:140:24  */
  assign t8243_core_b_n26 = t8243_core_b_p4_o; // (signal)
  /* t8243_sync_notri.vhd:141:24  */
  assign t8243_core_b_n27 = t8243_core_b_p4_en_o; // (signal)
  /* t8243_sync_notri.vhd:143:24  */
  assign t8243_core_b_n28 = t8243_core_b_p5_o; // (signal)
  /* t8243_sync_notri.vhd:144:24  */
  assign t8243_core_b_n29 = t8243_core_b_p5_en_o; // (signal)
  /* t8243_sync_notri.vhd:146:24  */
  assign t8243_core_b_n30 = t8243_core_b_p6_o; // (signal)
  /* t8243_sync_notri.vhd:147:24  */
  assign t8243_core_b_n31 = t8243_core_b_p6_en_o; // (signal)
  /* t8243_sync_notri.vhd:149:24  */
  assign t8243_core_b_n32 = t8243_core_b_p7_o; // (signal)
  /* t8243_sync_notri.vhd:150:24  */
  assign t8243_core_b_n33 = t8243_core_b_p7_en_o; // (signal)
  /* t8243_sync_notri.vhd:125:3  */
  t8243_core_1 t8243_core_b (
    .clk_i(clk_i),
    .clk_rise_en_i(clk_rise_en_s),
    .clk_fall_en_i(clk_fall_en_s),
    .reset_n_i(reset_n_i),
    .cs_n_i(cs_n_i),
    .prog_n_i(prog_n_i),
    .p2_i(p2_i),
    .p4_i(p4_i),
    .p5_i(p5_i),
    .p6_i(p6_i),
    .p7_i(p7_i),
    .p2_o(t8243_core_b_p2_o),
    .p2_en_o(t8243_core_b_p2_en_o),
    .p4_o(t8243_core_b_p4_o),
    .p4_en_o(t8243_core_b_p4_en_o),
    .p5_o(t8243_core_b_p5_o),
    .p5_en_o(t8243_core_b_p5_en_o),
    .p6_o(t8243_core_b_p6_o),
    .p6_en_o(t8243_core_b_p6_en_o),
    .p7_o(t8243_core_b_p7_o),
    .p7_en_o(t8243_core_b_p7_en_o));
  /* t8243_sync_notri.vhd:105:5  */
  assign n54_o = clk_en_i ? prog_n_i : prog_n_q;
  /* t8243_sync_notri.vhd:105:5  */
  always @(posedge clk_i or posedge n11_o)
    if (n11_o)
      n55_q <= 1'b1;
    else
      n55_q <= n54_o;
endmodule

