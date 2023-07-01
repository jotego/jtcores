module ps2_intf_v
  (input  CLK,
   input  nRESET,
   input  PS2_CLK,
   input  PS2_DATA,
   output [7:0] DATA,
   output VALID,
   output ERROR);
  wire [7:0] clk_filter;
  wire ps2_clk_in;
  wire ps2_dat_in;
  wire clk_edge;
  wire [3:0] bit_count;
  wire [8:0] shiftreg;
  wire parity;
  wire n5_o;
  wire [6:0] n7_o;
  wire [7:0] n8_o;
  wire n10_o;
  wire n12_o;
  wire n15_o;
  wire n17_o;
  wire n19_o;
  wire n21_o;
  wire n23_o;
  wire n40_o;
  wire [4:0] n42_o;
  wire n44_o;
  wire n45_o;
  wire [3:0] n47_o;
  wire [3:0] n48_o;
  wire [4:0] n49_o;
  wire n51_o;
  wire [3:0] n53_o;
  wire [7:0] n54_o;
  wire [8:0] n55_o;
  wire n56_o;
  wire [7:0] n57_o;
  wire [7:0] n58_o;
  wire n61_o;
  wire n64_o;
  wire n65_o;
  wire n67_o;
  wire n69_o;
  wire [7:0] n70_o;
  wire n72_o;
  wire n74_o;
  wire [3:0] n76_o;
  wire [8:0] n77_o;
  wire n78_o;
  wire [7:0] n79_o;
  wire n81_o;
  wire n83_o;
  wire [3:0] n84_o;
  wire [8:0] n85_o;
  wire n87_o;
  wire n90_o;
  wire n93_o;
  reg [7:0] n117_q;
  reg n118_q;
  reg n119_q;
  reg n120_q;
  wire [3:0] n121_o;
  reg [3:0] n122_q;
  wire [8:0] n123_o;
  reg [8:0] n124_q;
  wire n125_o;
  reg n126_q;
  wire [7:0] n127_o;
  reg [7:0] n128_q;
  reg n129_q;
  reg n130_q;
  assign DATA = n128_q;
  assign VALID = n129_q;
  assign ERROR = n130_q;
  /* ps2_intf.vhd:66:9  */
  assign clk_filter = n117_q; // (signal)
  /* ps2_intf.vhd:68:9  */
  assign ps2_clk_in = n118_q; // (signal)
  /* ps2_intf.vhd:69:9  */
  assign ps2_dat_in = n119_q; // (signal)
  /* ps2_intf.vhd:71:9  */
  assign clk_edge = n120_q; // (signal)
  /* ps2_intf.vhd:72:9  */
  assign bit_count = n122_q; // (signal)
  /* ps2_intf.vhd:73:9  */
  assign shiftreg = n124_q; // (signal)
  /* ps2_intf.vhd:74:9  */
  assign parity = n126_q; // (signal)
  /* ps2_intf.vhd:79:27  */
  assign n5_o = ~nRESET;
  /* ps2_intf.vhd:87:59  */
  assign n7_o = clk_filter[7:1];
  /* ps2_intf.vhd:87:47  */
  assign n8_o = {PS2_CLK, n7_o};
  /* ps2_intf.vhd:90:39  */
  assign n10_o = clk_filter == 8'b11111111;
  /* ps2_intf.vhd:93:42  */
  assign n12_o = clk_filter == 8'b00000000;
  /* ps2_intf.vhd:95:33  */
  assign n15_o = ps2_clk_in ? 1'b1 : 1'b0;
  /* ps2_intf.vhd:93:25  */
  assign n17_o = n12_o ? 1'b0 : ps2_clk_in;
  /* ps2_intf.vhd:93:25  */
  assign n19_o = n12_o ? n15_o : 1'b0;
  /* ps2_intf.vhd:90:25  */
  assign n21_o = n10_o ? 1'b1 : n17_o;
  /* ps2_intf.vhd:90:25  */
  assign n23_o = n10_o ? 1'b0 : n19_o;
  /* ps2_intf.vhd:106:27  */
  assign n40_o = ~nRESET;
  /* ps2_intf.vhd:120:46  */
  assign n42_o = {1'b0, bit_count};  //  uext
  /* ps2_intf.vhd:120:46  */
  assign n44_o = n42_o == 5'b00000;
  /* ps2_intf.vhd:126:55  */
  assign n45_o = ~ps2_dat_in;
  /* ps2_intf.vhd:128:72  */
  assign n47_o = bit_count + 4'b0001;
  /* ps2_intf.vhd:126:41  */
  assign n48_o = n45_o ? n47_o : bit_count;
  /* ps2_intf.vhd:133:54  */
  assign n49_o = {1'b0, bit_count};  //  uext
  /* ps2_intf.vhd:133:54  */
  assign n51_o = $signed(n49_o) < $signed(5'b01010);
  /* ps2_intf.vhd:135:72  */
  assign n53_o = bit_count + 4'b0001;
  /* ps2_intf.vhd:136:82  */
  assign n54_o = shiftreg[8:1];
  /* ps2_intf.vhd:136:72  */
  assign n55_o = {ps2_dat_in, n54_o};
  /* ps2_intf.vhd:137:66  */
  assign n56_o = parity ^ ps2_dat_in;
  /* ps2_intf.vhd:143:73  */
  assign n57_o = shiftreg[7:0];
  /* ps2_intf.vhd:138:41  */
  assign n58_o = n65_o ? n57_o : n128_q;
  /* ps2_intf.vhd:141:49  */
  assign n61_o = parity ? 1'b1 : 1'b0;
  /* ps2_intf.vhd:141:49  */
  assign n64_o = parity ? 1'b0 : 1'b1;
  /* ps2_intf.vhd:138:41  */
  assign n65_o = ps2_dat_in & parity;
  /* ps2_intf.vhd:138:41  */
  assign n67_o = ps2_dat_in ? n61_o : 1'b0;
  /* ps2_intf.vhd:138:41  */
  assign n69_o = ps2_dat_in ? n64_o : 1'b1;
  /* ps2_intf.vhd:133:41  */
  assign n70_o = n51_o ? n128_q : n58_o;
  /* ps2_intf.vhd:133:41  */
  assign n72_o = n51_o ? 1'b0 : n67_o;
  /* ps2_intf.vhd:133:41  */
  assign n74_o = n51_o ? 1'b0 : n69_o;
  /* ps2_intf.vhd:133:41  */
  assign n76_o = n51_o ? n53_o : 4'b0000;
  /* ps2_intf.vhd:133:41  */
  assign n77_o = n51_o ? n55_o : shiftreg;
  /* ps2_intf.vhd:133:41  */
  assign n78_o = n51_o ? n56_o : parity;
  /* ps2_intf.vhd:120:33  */
  assign n79_o = n44_o ? n128_q : n70_o;
  /* ps2_intf.vhd:120:33  */
  assign n81_o = n44_o ? 1'b0 : n72_o;
  /* ps2_intf.vhd:120:33  */
  assign n83_o = n44_o ? 1'b0 : n74_o;
  /* ps2_intf.vhd:120:33  */
  assign n84_o = n44_o ? n48_o : n76_o;
  /* ps2_intf.vhd:120:33  */
  assign n85_o = n44_o ? shiftreg : n77_o;
  /* ps2_intf.vhd:120:33  */
  assign n87_o = n44_o ? 1'b0 : n78_o;
  /* ps2_intf.vhd:118:25  */
  assign n90_o = clk_edge ? n81_o : 1'b0;
  /* ps2_intf.vhd:118:25  */
  assign n93_o = clk_edge ? n83_o : 1'b0;
  /* ps2_intf.vhd:84:17  */
  always @(posedge CLK or posedge n5_o)
    if (n5_o)
      n117_q <= 8'b11111111;
    else
      n117_q <= n8_o;
  /* ps2_intf.vhd:84:17  */
  always @(posedge CLK or posedge n5_o)
    if (n5_o)
      n118_q <= 1'b1;
    else
      n118_q <= n21_o;
  /* ps2_intf.vhd:84:17  */
  always @(posedge CLK or posedge n5_o)
    if (n5_o)
      n119_q <= 1'b1;
    else
      n119_q <= PS2_DATA;
  /* ps2_intf.vhd:84:17  */
  always @(posedge CLK or posedge n5_o)
    if (n5_o)
      n120_q <= 1'b0;
    else
      n120_q <= n23_o;
  /* ps2_intf.vhd:113:17  */
  assign n121_o = clk_edge ? n84_o : bit_count;
  /* ps2_intf.vhd:113:17  */
  always @(posedge CLK or posedge n40_o)
    if (n40_o)
      n122_q <= 4'b0000;
    else
      n122_q <= n121_o;
  /* ps2_intf.vhd:113:17  */
  assign n123_o = clk_edge ? n85_o : shiftreg;
  /* ps2_intf.vhd:113:17  */
  always @(posedge CLK or posedge n40_o)
    if (n40_o)
      n124_q <= 9'b000000000;
    else
      n124_q <= n123_o;
  /* ps2_intf.vhd:113:17  */
  assign n125_o = clk_edge ? n87_o : parity;
  /* ps2_intf.vhd:113:17  */
  always @(posedge CLK or posedge n40_o)
    if (n40_o)
      n126_q <= 1'b0;
    else
      n126_q <= n125_o;
  /* ps2_intf.vhd:113:17  */
  assign n127_o = clk_edge ? n79_o : n128_q;
  /* ps2_intf.vhd:113:17  */
  always @(posedge CLK or posedge n40_o)
    if (n40_o)
      n128_q <= 8'b00000000;
    else
      n128_q <= n127_o;
  /* ps2_intf.vhd:113:17  */
  always @(posedge CLK or posedge n40_o)
    if (n40_o)
      n129_q <= 1'b0;
    else
      n129_q <= n90_o;
  /* ps2_intf.vhd:113:17  */
  always @(posedge CLK or posedge n40_o)
    if (n40_o)
      n130_q <= 1'b0;
    else
      n130_q <= n93_o;
endmodule

