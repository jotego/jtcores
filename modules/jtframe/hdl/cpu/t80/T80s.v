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
  wire [7:0] n7804_o;
  wire [7:0] n7805_o;
  wire [7:0] n7806_o;
  wire [7:0] n7807_o;
  wire [7:0] n7808_o;
  wire [7:0] n7809_o;
  wire [7:0] n7810_o;
  wire [7:0] n7811_o;
  wire [7:0] n7812_o;
  wire [7:0] n7813_o;
  wire [7:0] n7814_o;
  wire [7:0] n7815_o;
  wire [7:0] n7816_o;
  wire [7:0] n7817_o;
  wire [7:0] n7818_o;
  wire [7:0] n7819_o;
  wire [2:0] n7822_o;
  wire [63:0] n7825_o;
  wire [2:0] n7828_o;
  wire [63:0] n7831_o;
  wire n7832_o;
  wire n7833_o;
  wire [63:0] n7834_o;
  wire [63:0] n7835_o;
  wire [63:0] n7836_o;
  wire [63:0] n7837_o;
  wire [2:0] n7843_o;
  wire [2:0] n7848_o;
  wire [2:0] n7853_o;
  wire [2:0] n7858_o;
  wire [2:0] n7863_o;
  wire [2:0] n7868_o;
  wire [7:0] n7871_o;
  wire [7:0] n7872_o;
  wire [15:0] n7873_o;
  wire [7:0] n7874_o;
  wire [23:0] n7875_o;
  wire [7:0] n7876_o;
  wire [31:0] n7877_o;
  wire [7:0] n7878_o;
  wire [39:0] n7879_o;
  wire [7:0] n7880_o;
  wire [47:0] n7881_o;
  wire [7:0] n7882_o;
  wire [55:0] n7883_o;
  wire [7:0] n7884_o;
  wire [63:0] n7885_o;
  wire [7:0] n7886_o;
  wire [71:0] n7887_o;
  wire [7:0] n7888_o;
  wire [79:0] n7889_o;
  wire [7:0] n7890_o;
  wire [87:0] n7891_o;
  wire [7:0] n7892_o;
  wire [95:0] n7893_o;
  wire [7:0] n7894_o;
  wire [103:0] n7895_o;
  wire [7:0] n7896_o;
  wire [111:0] n7897_o;
  wire [7:0] n7898_o;
  wire [119:0] n7899_o;
  wire [7:0] n7900_o;
  wire [127:0] n7901_o;
  reg [63:0] n7902_q;
  reg [63:0] n7903_q;
  wire n7904_o;
  wire n7905_o;
  wire n7906_o;
  wire n7907_o;
  wire n7908_o;
  wire n7909_o;
  wire n7910_o;
  wire n7911_o;
  wire n7912_o;
  wire n7913_o;
  wire n7914_o;
  wire n7915_o;
  wire n7916_o;
  wire n7917_o;
  wire n7918_o;
  wire n7919_o;
  wire n7920_o;
  wire n7921_o;
  wire [7:0] n7922_o;
  wire [7:0] n7923_o;
  wire [7:0] n7924_o;
  wire [7:0] n7925_o;
  wire [7:0] n7926_o;
  wire [7:0] n7927_o;
  wire [7:0] n7928_o;
  wire [7:0] n7929_o;
  wire [7:0] n7930_o;
  wire [7:0] n7931_o;
  wire [7:0] n7932_o;
  wire [7:0] n7933_o;
  wire [7:0] n7934_o;
  wire [7:0] n7935_o;
  wire [7:0] n7936_o;
  wire [7:0] n7937_o;
  wire [63:0] n7938_o;
  wire n7939_o;
  wire n7940_o;
  wire n7941_o;
  wire n7942_o;
  wire n7943_o;
  wire n7944_o;
  wire n7945_o;
  wire n7946_o;
  wire n7947_o;
  wire n7948_o;
  wire n7949_o;
  wire n7950_o;
  wire n7951_o;
  wire n7952_o;
  wire n7953_o;
  wire n7954_o;
  wire n7955_o;
  wire n7956_o;
  wire [7:0] n7957_o;
  wire [7:0] n7958_o;
  wire [7:0] n7959_o;
  wire [7:0] n7960_o;
  wire [7:0] n7961_o;
  wire [7:0] n7962_o;
  wire [7:0] n7963_o;
  wire [7:0] n7964_o;
  wire [7:0] n7965_o;
  wire [7:0] n7966_o;
  wire [7:0] n7967_o;
  wire [7:0] n7968_o;
  wire [7:0] n7969_o;
  wire [7:0] n7970_o;
  wire [7:0] n7971_o;
  wire [7:0] n7972_o;
  wire [63:0] n7973_o;
  wire [7:0] n7974_o;
  wire [7:0] n7975_o;
  wire [7:0] n7976_o;
  wire [7:0] n7977_o;
  wire [7:0] n7978_o;
  wire [7:0] n7979_o;
  wire [7:0] n7980_o;
  wire [7:0] n7981_o;
  wire [1:0] n7982_o;
  reg [7:0] n7983_o;
  wire [1:0] n7984_o;
  reg [7:0] n7985_o;
  wire n7986_o;
  wire [7:0] n7987_o;
  wire [7:0] n7988_o;
  wire [7:0] n7989_o;
  wire [7:0] n7990_o;
  wire [7:0] n7991_o;
  wire [7:0] n7992_o;
  wire [7:0] n7993_o;
  wire [7:0] n7994_o;
  wire [7:0] n7995_o;
  wire [1:0] n7996_o;
  reg [7:0] n7997_o;
  wire [1:0] n7998_o;
  reg [7:0] n7999_o;
  wire n8000_o;
  wire [7:0] n8001_o;
  wire [7:0] n8002_o;
  wire [7:0] n8003_o;
  wire [7:0] n8004_o;
  wire [7:0] n8005_o;
  wire [7:0] n8006_o;
  wire [7:0] n8007_o;
  wire [7:0] n8008_o;
  wire [7:0] n8009_o;
  wire [1:0] n8010_o;
  reg [7:0] n8011_o;
  wire [1:0] n8012_o;
  reg [7:0] n8013_o;
  wire n8014_o;
  wire [7:0] n8015_o;
  wire [7:0] n8016_o;
  wire [7:0] n8017_o;
  wire [7:0] n8018_o;
  wire [7:0] n8019_o;
  wire [7:0] n8020_o;
  wire [7:0] n8021_o;
  wire [7:0] n8022_o;
  wire [7:0] n8023_o;
  wire [1:0] n8024_o;
  reg [7:0] n8025_o;
  wire [1:0] n8026_o;
  reg [7:0] n8027_o;
  wire n8028_o;
  wire [7:0] n8029_o;
  wire [7:0] n8030_o;
  wire [7:0] n8031_o;
  wire [7:0] n8032_o;
  wire [7:0] n8033_o;
  wire [7:0] n8034_o;
  wire [7:0] n8035_o;
  wire [7:0] n8036_o;
  wire [7:0] n8037_o;
  wire [1:0] n8038_o;
  reg [7:0] n8039_o;
  wire [1:0] n8040_o;
  reg [7:0] n8041_o;
  wire n8042_o;
  wire [7:0] n8043_o;
  wire [7:0] n8044_o;
  wire [7:0] n8045_o;
  wire [7:0] n8046_o;
  wire [7:0] n8047_o;
  wire [7:0] n8048_o;
  wire [7:0] n8049_o;
  wire [7:0] n8050_o;
  wire [7:0] n8051_o;
  wire [1:0] n8052_o;
  reg [7:0] n8053_o;
  wire [1:0] n8054_o;
  reg [7:0] n8055_o;
  wire n8056_o;
  wire [7:0] n8057_o;
  assign doah = n7987_o;
  assign doal = n8001_o;
  assign dobh = n8015_o;
  assign dobl = n8029_o;
  assign doch = n8043_o;
  assign docl = n8057_o;
  assign dor = n7901_o;
  /* T80_Reg.vhd:101:16  */
  assign regsh = n7902_q; // (signal)
  /* T80_Reg.vhd:102:16  */
  assign regsl = n7903_q; // (signal)
  /* T80_Reg.vhd:110:48  */
  assign n7804_o = dir[7:0];
  /* T80_Reg.vhd:111:48  */
  assign n7805_o = dir[15:8];
  /* T80_Reg.vhd:113:48  */
  assign n7806_o = dir[23:16];
  /* T80_Reg.vhd:114:48  */
  assign n7807_o = dir[31:24];
  /* T80_Reg.vhd:116:48  */
  assign n7808_o = dir[39:32];
  /* T80_Reg.vhd:117:48  */
  assign n7809_o = dir[47:40];
  /* T80_Reg.vhd:119:48  */
  assign n7810_o = dir[55:48];
  /* T80_Reg.vhd:120:48  */
  assign n7811_o = dir[63:56];
  /* T80_Reg.vhd:122:48  */
  assign n7812_o = dir[71:64];
  /* T80_Reg.vhd:123:48  */
  assign n7813_o = dir[79:72];
  /* T80_Reg.vhd:125:48  */
  assign n7814_o = dir[87:80];
  /* T80_Reg.vhd:126:48  */
  assign n7815_o = dir[95:88];
  /* T80_Reg.vhd:128:48  */
  assign n7816_o = dir[103:96];
  /* T80_Reg.vhd:129:48  */
  assign n7817_o = dir[111:104];
  /* T80_Reg.vhd:131:48  */
  assign n7818_o = dir[119:112];
  /* T80_Reg.vhd:132:48  */
  assign n7819_o = dir[127:120];
  /* T80_Reg.vhd:135:47  */
  assign n7822_o = 3'b111 - addra;
  /* T80_Reg.vhd:133:25  */
  assign n7825_o = n7832_o ? n7938_o : regsh;
  /* T80_Reg.vhd:138:47  */
  assign n7828_o = 3'b111 - addra;
  /* T80_Reg.vhd:133:25  */
  assign n7831_o = n7833_o ? n7973_o : regsl;
  /* T80_Reg.vhd:133:25  */
  assign n7832_o = cen & weh;
  /* T80_Reg.vhd:133:25  */
  assign n7833_o = cen & wel;
  assign n7834_o = {n7805_o, n7807_o, n7809_o, n7811_o, n7813_o, n7815_o, n7817_o, n7819_o};
  /* T80_Reg.vhd:109:25  */
  assign n7835_o = dirset ? n7834_o : n7825_o;
  /* T80_ALU.vhd:112:26  */
  assign n7836_o = {n7804_o, n7806_o, n7808_o, n7810_o, n7812_o, n7814_o, n7816_o, n7818_o};
  /* T80_Reg.vhd:109:25  */
  assign n7837_o = dirset ? n7836_o : n7831_o;
  /* T80_Reg.vhd:144:23  */
  assign n7843_o = 3'b111 - addra;
  /* T80_Reg.vhd:145:23  */
  assign n7848_o = 3'b111 - addra;
  /* T80_Reg.vhd:146:23  */
  assign n7853_o = 3'b111 - addrb;
  /* T80_Reg.vhd:147:23  */
  assign n7858_o = 3'b111 - addrb;
  /* T80_Reg.vhd:148:23  */
  assign n7863_o = 3'b111 - addrc;
  /* T80_Reg.vhd:149:23  */
  assign n7868_o = 3'b111 - addrc;
  /* T80_Reg.vhd:150:22  */
  assign n7871_o = regsh[7:0];
  /* T80_Reg.vhd:150:33  */
  assign n7872_o = regsl[7:0];
  /* T80_Reg.vhd:150:26  */
  assign n7873_o = {n7871_o, n7872_o};
  /* T80_Reg.vhd:150:44  */
  assign n7874_o = regsh[15:8];
  /* T80_Reg.vhd:150:37  */
  assign n7875_o = {n7873_o, n7874_o};
  /* T80_Reg.vhd:150:55  */
  assign n7876_o = regsl[15:8];
  /* T80_Reg.vhd:150:48  */
  assign n7877_o = {n7875_o, n7876_o};
  /* T80_Reg.vhd:150:66  */
  assign n7878_o = regsh[23:16];
  /* T80_Reg.vhd:150:59  */
  assign n7879_o = {n7877_o, n7878_o};
  /* T80_Reg.vhd:150:77  */
  assign n7880_o = regsl[23:16];
  /* T80_Reg.vhd:150:70  */
  assign n7881_o = {n7879_o, n7880_o};
  /* T80_Reg.vhd:150:88  */
  assign n7882_o = regsh[31:24];
  /* T80_Reg.vhd:150:81  */
  assign n7883_o = {n7881_o, n7882_o};
  /* T80_Reg.vhd:150:99  */
  assign n7884_o = regsl[31:24];
  /* T80_Reg.vhd:150:92  */
  assign n7885_o = {n7883_o, n7884_o};
  /* T80_Reg.vhd:150:110  */
  assign n7886_o = regsh[39:32];
  /* T80_Reg.vhd:150:103  */
  assign n7887_o = {n7885_o, n7886_o};
  /* T80_Reg.vhd:150:121  */
  assign n7888_o = regsl[39:32];
  /* T80_Reg.vhd:150:114  */
  assign n7889_o = {n7887_o, n7888_o};
  /* T80_Reg.vhd:150:132  */
  assign n7890_o = regsh[47:40];
  /* T80_Reg.vhd:150:125  */
  assign n7891_o = {n7889_o, n7890_o};
  /* T80_Reg.vhd:150:143  */
  assign n7892_o = regsl[47:40];
  /* T80_Reg.vhd:150:136  */
  assign n7893_o = {n7891_o, n7892_o};
  /* T80_Reg.vhd:150:154  */
  assign n7894_o = regsh[55:48];
  /* T80_Reg.vhd:150:147  */
  assign n7895_o = {n7893_o, n7894_o};
  /* T80_Reg.vhd:150:165  */
  assign n7896_o = regsl[55:48];
  /* T80_Reg.vhd:150:158  */
  assign n7897_o = {n7895_o, n7896_o};
  /* T80_Reg.vhd:150:176  */
  assign n7898_o = regsh[63:56];
  /* T80_Reg.vhd:150:169  */
  assign n7899_o = {n7897_o, n7898_o};
  /* T80_Reg.vhd:150:187  */
  assign n7900_o = regsl[63:56];
  /* T80_Reg.vhd:150:180  */
  assign n7901_o = {n7899_o, n7900_o};
  /* T80_Reg.vhd:108:17  */
  always @(posedge clk)
    n7902_q <= n7835_o;
  /* T80_Reg.vhd:108:17  */
  always @(posedge clk)
    n7903_q <= n7837_o;
  /* T80_Reg.vhd:135:41  */
  assign n7904_o = n7822_o[2];
  /* T80_Reg.vhd:135:41  */
  assign n7905_o = ~n7904_o;
  /* T80_Reg.vhd:135:41  */
  assign n7906_o = n7822_o[1];
  /* T80_Reg.vhd:135:41  */
  assign n7907_o = ~n7906_o;
  /* T80_Reg.vhd:135:41  */
  assign n7908_o = n7905_o & n7907_o;
  /* T80_Reg.vhd:135:41  */
  assign n7909_o = n7905_o & n7906_o;
  /* T80_Reg.vhd:135:41  */
  assign n7910_o = n7904_o & n7907_o;
  /* T80_Reg.vhd:135:41  */
  assign n7911_o = n7904_o & n7906_o;
  /* T80_Reg.vhd:135:41  */
  assign n7912_o = n7822_o[0];
  /* T80_Reg.vhd:135:41  */
  assign n7913_o = ~n7912_o;
  /* T80_Reg.vhd:135:41  */
  assign n7914_o = n7908_o & n7913_o;
  /* T80_Reg.vhd:135:41  */
  assign n7915_o = n7908_o & n7912_o;
  /* T80_Reg.vhd:135:41  */
  assign n7916_o = n7909_o & n7913_o;
  /* T80_Reg.vhd:135:41  */
  assign n7917_o = n7909_o & n7912_o;
  /* T80_Reg.vhd:135:41  */
  assign n7918_o = n7910_o & n7913_o;
  /* T80_Reg.vhd:135:41  */
  assign n7919_o = n7910_o & n7912_o;
  /* T80_Reg.vhd:135:41  */
  assign n7920_o = n7911_o & n7913_o;
  /* T80_Reg.vhd:135:41  */
  assign n7921_o = n7911_o & n7912_o;
  assign n7922_o = regsh[7:0];
  /* T80_Reg.vhd:135:41  */
  assign n7923_o = n7914_o ? dih : n7922_o;
  assign n7924_o = regsh[15:8];
  /* T80_Reg.vhd:135:41  */
  assign n7925_o = n7915_o ? dih : n7924_o;
  assign n7926_o = regsh[23:16];
  /* T80_Reg.vhd:135:41  */
  assign n7927_o = n7916_o ? dih : n7926_o;
  assign n7928_o = regsh[31:24];
  /* T80_Reg.vhd:135:41  */
  assign n7929_o = n7917_o ? dih : n7928_o;
  assign n7930_o = regsh[39:32];
  /* T80_Reg.vhd:135:41  */
  assign n7931_o = n7918_o ? dih : n7930_o;
  assign n7932_o = regsh[47:40];
  /* T80_Reg.vhd:135:41  */
  assign n7933_o = n7919_o ? dih : n7932_o;
  assign n7934_o = regsh[55:48];
  /* T80_Reg.vhd:135:41  */
  assign n7935_o = n7920_o ? dih : n7934_o;
  assign n7936_o = regsh[63:56];
  /* T80_Reg.vhd:135:41  */
  assign n7937_o = n7921_o ? dih : n7936_o;
  assign n7938_o = {n7937_o, n7935_o, n7933_o, n7931_o, n7929_o, n7927_o, n7925_o, n7923_o};
  /* T80_Reg.vhd:138:41  */
  assign n7939_o = n7828_o[2];
  /* T80_Reg.vhd:138:41  */
  assign n7940_o = ~n7939_o;
  /* T80_Reg.vhd:138:41  */
  assign n7941_o = n7828_o[1];
  /* T80_Reg.vhd:138:41  */
  assign n7942_o = ~n7941_o;
  /* T80_Reg.vhd:138:41  */
  assign n7943_o = n7940_o & n7942_o;
  /* T80_Reg.vhd:138:41  */
  assign n7944_o = n7940_o & n7941_o;
  /* T80_Reg.vhd:138:41  */
  assign n7945_o = n7939_o & n7942_o;
  /* T80_Reg.vhd:138:41  */
  assign n7946_o = n7939_o & n7941_o;
  /* T80_Reg.vhd:138:41  */
  assign n7947_o = n7828_o[0];
  /* T80_Reg.vhd:138:41  */
  assign n7948_o = ~n7947_o;
  /* T80_Reg.vhd:138:41  */
  assign n7949_o = n7943_o & n7948_o;
  /* T80_Reg.vhd:138:41  */
  assign n7950_o = n7943_o & n7947_o;
  /* T80_Reg.vhd:138:41  */
  assign n7951_o = n7944_o & n7948_o;
  /* T80_Reg.vhd:138:41  */
  assign n7952_o = n7944_o & n7947_o;
  /* T80_Reg.vhd:138:41  */
  assign n7953_o = n7945_o & n7948_o;
  /* T80_Reg.vhd:138:41  */
  assign n7954_o = n7945_o & n7947_o;
  /* T80_Reg.vhd:138:41  */
  assign n7955_o = n7946_o & n7948_o;
  /* T80_Reg.vhd:138:41  */
  assign n7956_o = n7946_o & n7947_o;
  assign n7957_o = regsl[7:0];
  /* T80_Reg.vhd:138:41  */
  assign n7958_o = n7949_o ? dil : n7957_o;
  assign n7959_o = regsl[15:8];
  /* T80_Reg.vhd:138:41  */
  assign n7960_o = n7950_o ? dil : n7959_o;
  assign n7961_o = regsl[23:16];
  /* T80_Reg.vhd:138:41  */
  assign n7962_o = n7951_o ? dil : n7961_o;
  assign n7963_o = regsl[31:24];
  /* T80_Reg.vhd:138:41  */
  assign n7964_o = n7952_o ? dil : n7963_o;
  assign n7965_o = regsl[39:32];
  /* T80_Reg.vhd:138:41  */
  assign n7966_o = n7953_o ? dil : n7965_o;
  assign n7967_o = regsl[47:40];
  /* T80_Reg.vhd:138:41  */
  assign n7968_o = n7954_o ? dil : n7967_o;
  assign n7969_o = regsl[55:48];
  /* T80_Reg.vhd:138:41  */
  assign n7970_o = n7955_o ? dil : n7969_o;
  assign n7971_o = regsl[63:56];
  /* T80_Reg.vhd:138:41  */
  assign n7972_o = n7956_o ? dil : n7971_o;
  assign n7973_o = {n7972_o, n7970_o, n7968_o, n7966_o, n7964_o, n7962_o, n7960_o, n7958_o};
  /* T80_Reg.vhd:138:47  */
  assign n7974_o = regsh[7:0];
  /* T80_Reg.vhd:138:41  */
  assign n7975_o = regsh[15:8];
  assign n7976_o = regsh[23:16];
  assign n7977_o = regsh[31:24];
  assign n7978_o = regsh[39:32];
  assign n7979_o = regsh[47:40];
  assign n7980_o = regsh[55:48];
  assign n7981_o = regsh[63:56];
  /* T80_Reg.vhd:144:22  */
  assign n7982_o = n7843_o[1:0];
  /* T80_Reg.vhd:144:22  */
  always @*
    case (n7982_o)
      2'b00: n7983_o = n7974_o;
      2'b01: n7983_o = n7975_o;
      2'b10: n7983_o = n7976_o;
      2'b11: n7983_o = n7977_o;
    endcase
  /* T80_Reg.vhd:144:22  */
  assign n7984_o = n7843_o[1:0];
  /* T80_Reg.vhd:144:22  */
  always @*
    case (n7984_o)
      2'b00: n7985_o = n7978_o;
      2'b01: n7985_o = n7979_o;
      2'b10: n7985_o = n7980_o;
      2'b11: n7985_o = n7981_o;
    endcase
  /* T80_Reg.vhd:144:22  */
  assign n7986_o = n7843_o[2];
  /* T80_Reg.vhd:144:22  */
  assign n7987_o = n7986_o ? n7985_o : n7983_o;
  /* T80_Reg.vhd:144:22  */
  assign n7988_o = regsl[7:0];
  /* T80_Reg.vhd:144:23  */
  assign n7989_o = regsl[15:8];
  assign n7990_o = regsl[23:16];
  assign n7991_o = regsl[31:24];
  assign n7992_o = regsl[39:32];
  assign n7993_o = regsl[47:40];
  assign n7994_o = regsl[55:48];
  assign n7995_o = regsl[63:56];
  /* T80_Reg.vhd:145:22  */
  assign n7996_o = n7848_o[1:0];
  /* T80_Reg.vhd:145:22  */
  always @*
    case (n7996_o)
      2'b00: n7997_o = n7988_o;
      2'b01: n7997_o = n7989_o;
      2'b10: n7997_o = n7990_o;
      2'b11: n7997_o = n7991_o;
    endcase
  /* T80_Reg.vhd:145:22  */
  assign n7998_o = n7848_o[1:0];
  /* T80_Reg.vhd:145:22  */
  always @*
    case (n7998_o)
      2'b00: n7999_o = n7992_o;
      2'b01: n7999_o = n7993_o;
      2'b10: n7999_o = n7994_o;
      2'b11: n7999_o = n7995_o;
    endcase
  /* T80_Reg.vhd:145:22  */
  assign n8000_o = n7848_o[2];
  /* T80_Reg.vhd:145:22  */
  assign n8001_o = n8000_o ? n7999_o : n7997_o;
  /* T80_Reg.vhd:145:22  */
  assign n8002_o = regsh[7:0];
  /* T80_Reg.vhd:145:23  */
  assign n8003_o = regsh[15:8];
  assign n8004_o = regsh[23:16];
  assign n8005_o = regsh[31:24];
  assign n8006_o = regsh[39:32];
  assign n8007_o = regsh[47:40];
  assign n8008_o = regsh[55:48];
  assign n8009_o = regsh[63:56];
  /* T80_Reg.vhd:146:22  */
  assign n8010_o = n7853_o[1:0];
  /* T80_Reg.vhd:146:22  */
  always @*
    case (n8010_o)
      2'b00: n8011_o = n8002_o;
      2'b01: n8011_o = n8003_o;
      2'b10: n8011_o = n8004_o;
      2'b11: n8011_o = n8005_o;
    endcase
  /* T80_Reg.vhd:146:22  */
  assign n8012_o = n7853_o[1:0];
  /* T80_Reg.vhd:146:22  */
  always @*
    case (n8012_o)
      2'b00: n8013_o = n8006_o;
      2'b01: n8013_o = n8007_o;
      2'b10: n8013_o = n8008_o;
      2'b11: n8013_o = n8009_o;
    endcase
  /* T80_Reg.vhd:146:22  */
  assign n8014_o = n7853_o[2];
  /* T80_Reg.vhd:146:22  */
  assign n8015_o = n8014_o ? n8013_o : n8011_o;
  /* T80_Reg.vhd:146:22  */
  assign n8016_o = regsl[7:0];
  /* T80_Reg.vhd:146:23  */
  assign n8017_o = regsl[15:8];
  assign n8018_o = regsl[23:16];
  assign n8019_o = regsl[31:24];
  assign n8020_o = regsl[39:32];
  assign n8021_o = regsl[47:40];
  assign n8022_o = regsl[55:48];
  assign n8023_o = regsl[63:56];
  /* T80_Reg.vhd:147:22  */
  assign n8024_o = n7858_o[1:0];
  /* T80_Reg.vhd:147:22  */
  always @*
    case (n8024_o)
      2'b00: n8025_o = n8016_o;
      2'b01: n8025_o = n8017_o;
      2'b10: n8025_o = n8018_o;
      2'b11: n8025_o = n8019_o;
    endcase
  /* T80_Reg.vhd:147:22  */
  assign n8026_o = n7858_o[1:0];
  /* T80_Reg.vhd:147:22  */
  always @*
    case (n8026_o)
      2'b00: n8027_o = n8020_o;
      2'b01: n8027_o = n8021_o;
      2'b10: n8027_o = n8022_o;
      2'b11: n8027_o = n8023_o;
    endcase
  /* T80_Reg.vhd:147:22  */
  assign n8028_o = n7858_o[2];
  /* T80_Reg.vhd:147:22  */
  assign n8029_o = n8028_o ? n8027_o : n8025_o;
  /* T80_Reg.vhd:147:22  */
  assign n8030_o = regsh[7:0];
  /* T80_Reg.vhd:147:23  */
  assign n8031_o = regsh[15:8];
  assign n8032_o = regsh[23:16];
  assign n8033_o = regsh[31:24];
  assign n8034_o = regsh[39:32];
  assign n8035_o = regsh[47:40];
  assign n8036_o = regsh[55:48];
  assign n8037_o = regsh[63:56];
  /* T80_Reg.vhd:148:22  */
  assign n8038_o = n7863_o[1:0];
  /* T80_Reg.vhd:148:22  */
  always @*
    case (n8038_o)
      2'b00: n8039_o = n8030_o;
      2'b01: n8039_o = n8031_o;
      2'b10: n8039_o = n8032_o;
      2'b11: n8039_o = n8033_o;
    endcase
  /* T80_Reg.vhd:148:22  */
  assign n8040_o = n7863_o[1:0];
  /* T80_Reg.vhd:148:22  */
  always @*
    case (n8040_o)
      2'b00: n8041_o = n8034_o;
      2'b01: n8041_o = n8035_o;
      2'b10: n8041_o = n8036_o;
      2'b11: n8041_o = n8037_o;
    endcase
  /* T80_Reg.vhd:148:22  */
  assign n8042_o = n7863_o[2];
  /* T80_Reg.vhd:148:22  */
  assign n8043_o = n8042_o ? n8041_o : n8039_o;
  /* T80_Reg.vhd:148:22  */
  assign n8044_o = regsl[7:0];
  /* T80_Reg.vhd:148:23  */
  assign n8045_o = regsl[15:8];
  assign n8046_o = regsl[23:16];
  assign n8047_o = regsl[31:24];
  assign n8048_o = regsl[39:32];
  assign n8049_o = regsl[47:40];
  assign n8050_o = regsl[55:48];
  assign n8051_o = regsl[63:56];
  /* T80_Reg.vhd:149:22  */
  assign n8052_o = n7868_o[1:0];
  /* T80_Reg.vhd:149:22  */
  always @*
    case (n8052_o)
      2'b00: n8053_o = n8044_o;
      2'b01: n8053_o = n8045_o;
      2'b10: n8053_o = n8046_o;
      2'b11: n8053_o = n8047_o;
    endcase
  /* T80_Reg.vhd:149:22  */
  assign n8054_o = n7868_o[1:0];
  /* T80_Reg.vhd:149:22  */
  always @*
    case (n8054_o)
      2'b00: n8055_o = n8048_o;
      2'b01: n8055_o = n8049_o;
      2'b10: n8055_o = n8050_o;
      2'b11: n8055_o = n8051_o;
    endcase
  /* T80_Reg.vhd:149:22  */
  assign n8056_o = n7868_o[2];
  /* T80_Reg.vhd:149:22  */
  assign n8057_o = n8056_o ? n8055_o : n8053_o;
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
   output [7:0] q,
   output [7:0] f_out);
  wire usecarry;
  wire carry7_v;
  wire overflow_v;
  wire halfcarry_v;
  wire carry_v;
  wire [7:0] q_v;
  wire [7:0] bitmask;
  wire [2:0] n7216_o;
  wire n7219_o;
  wire n7222_o;
  wire n7225_o;
  wire n7228_o;
  wire n7231_o;
  wire n7234_o;
  wire n7237_o;
  wire [6:0] n7239_o;
  reg [7:0] n7240_o;
  wire n7241_o;
  wire n7242_o;
  wire n7243_o;
  wire n7244_o;
  wire [3:0] n7246_o;
  wire [3:0] n7247_o;
  wire n7248_o;
  wire n7249_o;
  wire n7250_o;
  wire n7251_o;
  wire n7252_o;
  wire [3:0] n7257_o;
  wire [3:0] n7258_o;
  wire [4:0] n7261_o;
  wire [5:0] n7262_o;
  wire [4:0] n7264_o;
  wire [5:0] n7266_o;
  wire [5:0] n7267_o;
  wire n7269_o;
  wire [3:0] n7270_o;
  wire [2:0] n7272_o;
  wire [2:0] n7273_o;
  wire n7274_o;
  wire [2:0] n7279_o;
  wire [2:0] n7280_o;
  wire [3:0] n7283_o;
  wire [4:0] n7284_o;
  wire [3:0] n7286_o;
  wire [4:0] n7288_o;
  wire [4:0] n7289_o;
  wire n7291_o;
  wire [2:0] n7292_o;
  wire n7294_o;
  wire n7295_o;
  wire n7296_o;
  wire n7301_o;
  wire n7302_o;
  wire [1:0] n7305_o;
  wire [2:0] n7306_o;
  wire [1:0] n7308_o;
  wire [2:0] n7310_o;
  wire [2:0] n7311_o;
  wire n7313_o;
  wire n7314_o;
  wire n7317_o;
  wire [2:0] n7325_o;
  wire n7327_o;
  wire n7329_o;
  wire n7330_o;
  wire n7332_o;
  wire n7333_o;
  wire n7335_o;
  wire n7337_o;
  wire n7338_o;
  wire n7340_o;
  wire n7341_o;
  wire [7:0] n7342_o;
  wire n7345_o;
  wire [7:0] n7346_o;
  wire n7349_o;
  wire [7:0] n7350_o;
  wire [3:0] n7352_o;
  reg n7353_o;
  reg n7354_o;
  wire n7355_o;
  reg n7356_o;
  reg n7357_o;
  reg [7:0] n7358_o;
  wire [2:0] n7359_o;
  wire n7361_o;
  wire n7362_o;
  wire n7363_o;
  wire n7364_o;
  wire n7365_o;
  wire n7366_o;
  wire n7367_o;
  wire n7369_o;
  wire n7371_o;
  wire n7372_o;
  wire n7374_o;
  wire n7375_o;
  wire [2:0] n7376_o;
  wire n7378_o;
  wire n7380_o;
  wire n7381_o;
  wire n7383_o;
  wire n7384_o;
  wire n7386_o;
  wire n7387_o;
  wire n7389_o;
  wire n7390_o;
  wire n7391_o;
  wire n7392_o;
  wire n7393_o;
  wire n7394_o;
  wire n7395_o;
  wire n7396_o;
  wire n7397_o;
  wire n7398_o;
  wire n7399_o;
  wire n7400_o;
  wire n7401_o;
  wire n7402_o;
  wire n7403_o;
  wire n7404_o;
  wire n7405_o;
  wire n7406_o;
  reg n7407_o;
  wire n7408_o;
  wire n7409_o;
  wire n7410_o;
  wire [1:0] n7411_o;
  wire n7412_o;
  wire [1:0] n7413_o;
  wire [1:0] n7414_o;
  wire n7416_o;
  wire n7418_o;
  wire n7419_o;
  wire n7421_o;
  wire n7422_o;
  wire n7424_o;
  wire n7425_o;
  wire n7427_o;
  wire n7428_o;
  wire n7430_o;
  wire n7431_o;
  wire n7433_o;
  wire n7434_o;
  wire n7436_o;
  wire n7437_o;
  wire n7438_o;
  wire n7441_o;
  wire n7442_o;
  wire [8:0] n7443_o;
  wire [3:0] n7444_o;
  wire n7446_o;
  wire n7447_o;
  wire n7448_o;
  wire [8:0] n7449_o;
  wire [3:0] n7450_o;
  wire n7452_o;
  wire n7455_o;
  wire [8:0] n7456_o;
  wire [8:0] n7458_o;
  wire n7459_o;
  wire [8:0] n7460_o;
  wire [8:0] n7461_o;
  wire [4:0] n7462_o;
  wire n7464_o;
  wire n7465_o;
  wire n7466_o;
  wire [8:0] n7468_o;
  wire [8:0] n7469_o;
  wire [8:0] n7470_o;
  wire [3:0] n7471_o;
  wire n7473_o;
  wire n7474_o;
  wire n7475_o;
  wire [8:0] n7476_o;
  wire [3:0] n7477_o;
  wire n7479_o;
  wire n7481_o;
  wire [8:0] n7482_o;
  wire [7:0] n7483_o;
  wire [7:0] n7485_o;
  wire n7486_o;
  wire [7:0] n7487_o;
  wire n7489_o;
  wire n7490_o;
  wire n7491_o;
  wire [8:0] n7492_o;
  wire [8:0] n7494_o;
  wire [8:0] n7495_o;
  wire [8:0] n7496_o;
  wire n7497_o;
  wire [8:0] n7498_o;
  wire n7499_o;
  wire n7500_o;
  wire n7501_o;
  wire n7502_o;
  wire n7503_o;
  wire [7:0] n7504_o;
  wire [7:0] n7505_o;
  wire n7507_o;
  wire n7510_o;
  wire n7511_o;
  wire n7512_o;
  wire n7513_o;
  wire n7514_o;
  wire n7515_o;
  wire n7516_o;
  wire n7517_o;
  wire n7518_o;
  wire n7519_o;
  wire n7520_o;
  wire n7521_o;
  wire n7522_o;
  wire n7523_o;
  wire n7524_o;
  wire n7525_o;
  wire n7526_o;
  wire n7527_o;
  wire n7529_o;
  wire [3:0] n7530_o;
  wire n7531_o;
  wire [3:0] n7532_o;
  wire [3:0] n7533_o;
  wire [3:0] n7534_o;
  wire [7:0] n7537_o;
  wire n7538_o;
  wire [7:0] n7539_o;
  wire n7540_o;
  wire [7:0] n7541_o;
  wire n7543_o;
  wire n7546_o;
  wire [7:0] n7547_o;
  wire n7548_o;
  wire [7:0] n7549_o;
  wire n7550_o;
  wire [7:0] n7551_o;
  wire n7552_o;
  wire n7553_o;
  wire [7:0] n7554_o;
  wire n7555_o;
  wire n7556_o;
  wire [7:0] n7557_o;
  wire n7558_o;
  wire n7559_o;
  wire [7:0] n7560_o;
  wire n7561_o;
  wire n7562_o;
  wire [7:0] n7563_o;
  wire n7564_o;
  wire n7565_o;
  wire [7:0] n7566_o;
  wire n7567_o;
  wire n7568_o;
  wire [7:0] n7569_o;
  wire n7570_o;
  wire n7571_o;
  wire n7572_o;
  wire n7574_o;
  wire n7576_o;
  wire n7577_o;
  wire [7:0] n7578_o;
  wire n7579_o;
  wire n7581_o;
  wire n7586_o;
  wire n7587_o;
  wire [2:0] n7590_o;
  wire n7592_o;
  wire n7594_o;
  wire n7595_o;
  wire n7596_o;
  wire n7597_o;
  wire n7598_o;
  wire n7599_o;
  wire n7600_o;
  wire n7601_o;
  wire n7603_o;
  wire [7:0] n7604_o;
  wire n7606_o;
  wire [7:0] n7607_o;
  wire [7:0] n7608_o;
  wire n7610_o;
  wire [2:0] n7611_o;
  wire [6:0] n7612_o;
  wire n7613_o;
  wire n7614_o;
  wire n7616_o;
  wire [6:0] n7617_o;
  wire n7618_o;
  wire n7619_o;
  wire n7621_o;
  wire [6:0] n7622_o;
  wire n7623_o;
  wire n7624_o;
  wire n7626_o;
  wire [6:0] n7627_o;
  wire n7628_o;
  wire n7629_o;
  wire n7631_o;
  wire [6:0] n7632_o;
  wire n7634_o;
  wire n7636_o;
  wire [6:0] n7637_o;
  wire n7639_o;
  wire n7641_o;
  wire [6:0] n7642_o;
  wire n7643_o;
  wire n7644_o;
  wire n7646_o;
  wire [6:0] n7647_o;
  wire n7649_o;
  wire [6:0] n7650_o;
  reg n7651_o;
  wire n7652_o;
  wire n7653_o;
  wire n7654_o;
  wire n7655_o;
  reg n7656_o;
  wire [5:0] n7657_o;
  wire [5:0] n7658_o;
  wire [5:0] n7659_o;
  wire [5:0] n7660_o;
  wire [5:0] n7661_o;
  wire [5:0] n7662_o;
  wire [5:0] n7663_o;
  wire [5:0] n7664_o;
  reg [5:0] n7665_o;
  wire n7666_o;
  wire n7667_o;
  wire n7668_o;
  wire n7669_o;
  reg n7670_o;
  wire [7:0] n7673_o;
  wire n7674_o;
  wire [7:0] n7675_o;
  wire n7676_o;
  wire [7:0] n7677_o;
  wire n7678_o;
  wire [7:0] n7679_o;
  wire n7681_o;
  wire n7684_o;
  wire [7:0] n7685_o;
  wire n7686_o;
  wire [7:0] n7687_o;
  wire n7688_o;
  wire n7689_o;
  wire [7:0] n7690_o;
  wire n7691_o;
  wire n7692_o;
  wire [7:0] n7693_o;
  wire n7694_o;
  wire n7695_o;
  wire [7:0] n7696_o;
  wire n7697_o;
  wire n7698_o;
  wire [7:0] n7699_o;
  wire n7700_o;
  wire n7701_o;
  wire [7:0] n7702_o;
  wire n7703_o;
  wire n7704_o;
  wire [7:0] n7705_o;
  wire n7706_o;
  wire n7707_o;
  wire n7708_o;
  wire n7710_o;
  wire n7711_o;
  wire n7712_o;
  wire n7713_o;
  wire [1:0] n7714_o;
  wire n7715_o;
  wire [1:0] n7716_o;
  wire [1:0] n7717_o;
  wire n7719_o;
  wire [6:0] n7720_o;
  wire n7721_o;
  reg n7722_o;
  wire n7723_o;
  reg n7724_o;
  wire n7725_o;
  reg n7726_o;
  wire n7727_o;
  reg n7728_o;
  wire n7729_o;
  reg n7730_o;
  wire n7731_o;
  reg n7732_o;
  wire n7733_o;
  wire n7734_o;
  wire n7735_o;
  reg n7736_o;
  wire n7737_o;
  wire n7738_o;
  wire n7739_o;
  reg n7740_o;
  wire n7748_o;
  wire n7749_o;
  wire n7750_o;
  wire n7751_o;
  wire n7752_o;
  wire n7753_o;
  reg n7755_o;
  wire [2:0] n7756_o;
  wire [2:0] n7757_o;
  wire [2:0] n7758_o;
  wire [2:0] n7759_o;
  wire [2:0] n7760_o;
  wire [2:0] n7761_o;
  wire [2:0] n7762_o;
  reg [2:0] n7764_o;
  wire [2:0] n7765_o;
  wire [2:0] n7766_o;
  wire [2:0] n7767_o;
  wire [2:0] n7768_o;
  wire [2:0] n7769_o;
  wire [2:0] n7770_o;
  wire [2:0] n7771_o;
  reg [2:0] n7773_o;
  wire n7774_o;
  wire n7775_o;
  wire n7776_o;
  wire n7777_o;
  wire n7778_o;
  wire n7779_o;
  reg n7781_o;
  wire [7:0] n7789_o;
  wire [7:0] n7792_o;
  wire [7:0] n7793_o;
  assign q = n7789_o;
  assign f_out = n7793_o;
  /* T80_ALU.vhd:126:16  */
  assign usecarry = n7244_o; // (signal)
  /* T80_ALU.vhd:127:16  */
  assign carry7_v = n7291_o; // (signal)
  /* T80_ALU.vhd:128:16  */
  assign overflow_v = n7317_o; // (signal)
  /* T80_ALU.vhd:129:16  */
  assign halfcarry_v = n7269_o; // (signal)
  /* T80_ALU.vhd:130:16  */
  assign carry_v = n7313_o; // (signal)
  /* T80_ALU.vhd:131:16  */
  assign q_v = n7792_o; // (signal)
  /* T80_ALU.vhd:133:16  */
  assign bitmask = n7240_o; // (signal)
  /* T80_ALU.vhd:137:16  */
  assign n7216_o = ir[5:3];
  /* T80_ALU.vhd:137:58  */
  assign n7219_o = n7216_o == 3'b000;
  /* T80_ALU.vhd:138:94  */
  assign n7222_o = n7216_o == 3'b001;
  /* T80_ALU.vhd:139:94  */
  assign n7225_o = n7216_o == 3'b010;
  /* T80_ALU.vhd:140:94  */
  assign n7228_o = n7216_o == 3'b011;
  /* T80_ALU.vhd:141:94  */
  assign n7231_o = n7216_o == 3'b100;
  /* T80_ALU.vhd:142:94  */
  assign n7234_o = n7216_o == 3'b101;
  /* T80_ALU.vhd:143:94  */
  assign n7237_o = n7216_o == 3'b110;
  /* T80_MCode.vhd:113:7  */
  assign n7239_o = {n7237_o, n7234_o, n7231_o, n7228_o, n7225_o, n7222_o, n7219_o};
  /* T80_ALU.vhd:137:9  */
  always @*
    case (n7239_o)
      7'b1000000: n7240_o = 8'b01000000;
      7'b0100000: n7240_o = 8'b00100000;
      7'b0010000: n7240_o = 8'b00010000;
      7'b0001000: n7240_o = 8'b00001000;
      7'b0000100: n7240_o = 8'b00000100;
      7'b0000010: n7240_o = 8'b00000010;
      7'b0000001: n7240_o = 8'b00000001;
      default: n7240_o = 8'b10000000;
    endcase
  /* T80_ALU.vhd:146:31  */
  assign n7241_o = alu_op[2];
  /* T80_ALU.vhd:146:21  */
  assign n7242_o = ~n7241_o;
  /* T80_ALU.vhd:146:45  */
  assign n7243_o = alu_op[0];
  /* T80_ALU.vhd:146:35  */
  assign n7244_o = n7242_o & n7243_o;
  /* T80_ALU.vhd:147:20  */
  assign n7246_o = busa[3:0];
  /* T80_ALU.vhd:147:38  */
  assign n7247_o = busb[3:0];
  /* T80_ALU.vhd:147:58  */
  assign n7248_o = alu_op[1];
  /* T80_ALU.vhd:147:69  */
  assign n7249_o = alu_op[1];
  /* T80_ALU.vhd:147:95  */
  assign n7250_o = f_in[0];
  /* T80_ALU.vhd:147:87  */
  assign n7251_o = usecarry & n7250_o;
  /* T80_ALU.vhd:147:73  */
  assign n7252_o = n7249_o ^ n7251_o;
  /* T80_ALU.vhd:115:32  */
  assign n7257_o = ~n7247_o;
  /* T80_ALU.vhd:114:17  */
  assign n7258_o = n7248_o ? n7257_o : n7247_o;
  /* T80_ALU.vhd:120:39  */
  assign n7261_o = {1'b0, n7246_o};
  /* T80_ALU.vhd:120:43  */
  assign n7262_o = {n7261_o, n7252_o};
  /* T80_ALU.vhd:120:70  */
  assign n7264_o = {1'b0, n7258_o};
  /* T80_ALU.vhd:120:76  */
  assign n7266_o = {n7264_o, 1'b1};
  /* T80_ALU.vhd:120:55  */
  assign n7267_o = n7262_o + n7266_o;
  /* T80_ALU.vhd:121:31  */
  assign n7269_o = n7267_o[5];
  /* T80_ALU.vhd:122:46  */
  assign n7270_o = n7267_o[4:1];
  /* T80_ALU.vhd:148:20  */
  assign n7272_o = busa[6:4];
  /* T80_ALU.vhd:148:38  */
  assign n7273_o = busb[6:4];
  /* T80_ALU.vhd:148:58  */
  assign n7274_o = alu_op[1];
  /* T80_ALU.vhd:115:32  */
  assign n7279_o = ~n7273_o;
  /* T80_ALU.vhd:114:17  */
  assign n7280_o = n7274_o ? n7279_o : n7273_o;
  /* T80_ALU.vhd:120:39  */
  assign n7283_o = {1'b0, n7272_o};
  /* T80_ALU.vhd:120:43  */
  assign n7284_o = {n7283_o, halfcarry_v};
  /* T80_ALU.vhd:120:70  */
  assign n7286_o = {1'b0, n7280_o};
  /* T80_ALU.vhd:120:76  */
  assign n7288_o = {n7286_o, 1'b1};
  /* T80_ALU.vhd:120:55  */
  assign n7289_o = n7284_o + n7288_o;
  /* T80_ALU.vhd:121:31  */
  assign n7291_o = n7289_o[4];
  /* T80_ALU.vhd:122:46  */
  assign n7292_o = n7289_o[3:1];
  /* T80_ALU.vhd:149:20  */
  assign n7294_o = busa[7];
  /* T80_ALU.vhd:149:38  */
  assign n7295_o = busb[7];
  /* T80_ALU.vhd:149:58  */
  assign n7296_o = alu_op[1];
  /* T80_ALU.vhd:115:32  */
  assign n7301_o = ~n7295_o;
  /* T80_ALU.vhd:114:17  */
  assign n7302_o = n7296_o ? n7301_o : n7295_o;
  /* T80_ALU.vhd:120:39  */
  assign n7305_o = {1'b0, n7294_o};
  /* T80_ALU.vhd:120:43  */
  assign n7306_o = {n7305_o, carry7_v};
  /* T80_ALU.vhd:120:70  */
  assign n7308_o = {1'b0, n7302_o};
  /* T80_ALU.vhd:120:76  */
  assign n7310_o = {n7308_o, 1'b1};
  /* T80_ALU.vhd:120:55  */
  assign n7311_o = n7306_o + n7310_o;
  /* T80_ALU.vhd:121:31  */
  assign n7313_o = n7311_o[2];
  /* T80_ALU.vhd:122:46  */
  assign n7314_o = n7311_o[1];
  /* T80_ALU.vhd:157:47  */
  assign n7317_o = carry_v ^ carry7_v;
  /* T80_ALU.vhd:172:36  */
  assign n7325_o = alu_op[2:0];
  /* T80_ALU.vhd:173:25  */
  assign n7327_o = n7325_o == 3'b000;
  /* T80_ALU.vhd:173:36  */
  assign n7329_o = n7325_o == 3'b001;
  /* T80_ALU.vhd:173:36  */
  assign n7330_o = n7327_o | n7329_o;
  /* T80_ALU.vhd:181:50  */
  assign n7332_o = ~carry_v;
  /* T80_ALU.vhd:182:50  */
  assign n7333_o = ~halfcarry_v;
  /* T80_ALU.vhd:178:25  */
  assign n7335_o = n7325_o == 3'b010;
  /* T80_ALU.vhd:178:36  */
  assign n7337_o = n7325_o == 3'b011;
  /* T80_ALU.vhd:178:36  */
  assign n7338_o = n7335_o | n7337_o;
  /* T80_ALU.vhd:178:44  */
  assign n7340_o = n7325_o == 3'b111;
  /* T80_ALU.vhd:178:44  */
  assign n7341_o = n7338_o | n7340_o;
  /* T80_ALU.vhd:185:57  */
  assign n7342_o = busa & busb;
  /* T80_ALU.vhd:184:25  */
  assign n7345_o = n7325_o == 3'b100;
  /* T80_ALU.vhd:188:57  */
  assign n7346_o = busa ^ busb;
  /* T80_ALU.vhd:187:25  */
  assign n7349_o = n7325_o == 3'b101;
  /* T80_ALU.vhd:191:57  */
  assign n7350_o = busa | busb;
  assign n7352_o = {n7349_o, n7345_o, n7341_o, n7330_o};
  /* T80_ALU.vhd:172:25  */
  always @*
    case (n7352_o)
      4'b1000: n7353_o = 1'b0;
      4'b0100: n7353_o = 1'b0;
      4'b0010: n7353_o = n7332_o;
      4'b0001: n7353_o = carry_v;
      default: n7353_o = 1'b0;
    endcase
  /* T80_ALU.vhd:172:25  */
  always @*
    case (n7352_o)
      4'b1000: n7354_o = 1'b0;
      4'b0100: n7354_o = 1'b0;
      4'b0010: n7354_o = 1'b1;
      4'b0001: n7354_o = 1'b0;
      default: n7354_o = 1'b0;
    endcase
  assign n7355_o = f_in[2];
  /* T80_ALU.vhd:172:25  */
  always @*
    case (n7352_o)
      4'b1000: n7356_o = n7355_o;
      4'b0100: n7356_o = n7355_o;
      4'b0010: n7356_o = overflow_v;
      4'b0001: n7356_o = overflow_v;
      default: n7356_o = n7355_o;
    endcase
  /* T80_ALU.vhd:172:25  */
  always @*
    case (n7352_o)
      4'b1000: n7357_o = 1'b0;
      4'b0100: n7357_o = 1'b1;
      4'b0010: n7357_o = n7333_o;
      4'b0001: n7357_o = halfcarry_v;
      default: n7357_o = 1'b0;
    endcase
  /* T80_ALU.vhd:201:31  */
  always @*
    case (n7352_o)
      4'b1000: n7358_o = n7346_o;
      4'b0100: n7358_o = n7342_o;
      4'b0010: n7358_o = q_v;
      4'b0001: n7358_o = q_v;
      default: n7358_o = n7350_o;
    endcase
  /* T80_ALU.vhd:194:34  */
  assign n7359_o = alu_op[2:0];
  /* T80_ALU.vhd:194:47  */
  assign n7361_o = n7359_o == 3'b111;
  /* T80_ALU.vhd:195:54  */
  assign n7362_o = busb[3];
  /* T80_ALU.vhd:196:54  */
  assign n7363_o = busb[5];
  /* T80_ALU.vhd:198:53  */
  assign n7364_o = n7358_o[3];
  /* T80_ALU.vhd:199:53  */
  assign n7365_o = n7358_o[5];
  /* T80_ALU.vhd:194:25  */
  assign n7366_o = n7361_o ? n7362_o : n7364_o;
  /* T80_ALU.vhd:194:25  */
  assign n7367_o = n7361_o ? n7363_o : n7365_o;
  /* T80_ALU.vhd:201:44  */
  assign n7369_o = n7358_o == 8'b00000000;
  /* T80_ALU.vhd:204:62  */
  assign n7371_o = f_in[6];
  /* T80_ALU.vhd:203:33  */
  assign n7372_o = z16 ? n7371_o : 1'b1;
  /* T80_ALU.vhd:201:25  */
  assign n7374_o = n7369_o ? n7372_o : 1'b0;
  /* T80_ALU.vhd:209:45  */
  assign n7375_o = n7358_o[7];
  /* T80_ALU.vhd:210:36  */
  assign n7376_o = alu_op[2:0];
  /* T80_ALU.vhd:211:25  */
  assign n7378_o = n7376_o == 3'b000;
  /* T80_ALU.vhd:211:36  */
  assign n7380_o = n7376_o == 3'b001;
  /* T80_ALU.vhd:211:36  */
  assign n7381_o = n7378_o | n7380_o;
  /* T80_ALU.vhd:211:44  */
  assign n7383_o = n7376_o == 3'b010;
  /* T80_ALU.vhd:211:44  */
  assign n7384_o = n7381_o | n7383_o;
  /* T80_ALU.vhd:211:52  */
  assign n7386_o = n7376_o == 3'b011;
  /* T80_ALU.vhd:211:52  */
  assign n7387_o = n7384_o | n7386_o;
  /* T80_ALU.vhd:211:60  */
  assign n7389_o = n7376_o == 3'b111;
  /* T80_ALU.vhd:211:60  */
  assign n7390_o = n7387_o | n7389_o;
  /* T80_ALU.vhd:213:58  */
  assign n7391_o = n7358_o[0];
  /* T80_ALU.vhd:213:69  */
  assign n7392_o = n7358_o[1];
  /* T80_ALU.vhd:213:62  */
  assign n7393_o = n7391_o ^ n7392_o;
  /* T80_ALU.vhd:213:80  */
  assign n7394_o = n7358_o[2];
  /* T80_ALU.vhd:213:73  */
  assign n7395_o = n7393_o ^ n7394_o;
  /* T80_ALU.vhd:213:91  */
  assign n7396_o = n7358_o[3];
  /* T80_ALU.vhd:213:84  */
  assign n7397_o = n7395_o ^ n7396_o;
  /* T80_ALU.vhd:214:44  */
  assign n7398_o = n7358_o[4];
  /* T80_ALU.vhd:213:95  */
  assign n7399_o = n7397_o ^ n7398_o;
  /* T80_ALU.vhd:214:55  */
  assign n7400_o = n7358_o[5];
  /* T80_ALU.vhd:214:48  */
  assign n7401_o = n7399_o ^ n7400_o;
  /* T80_ALU.vhd:214:66  */
  assign n7402_o = n7358_o[6];
  /* T80_ALU.vhd:214:59  */
  assign n7403_o = n7401_o ^ n7402_o;
  /* T80_ALU.vhd:214:77  */
  assign n7404_o = n7358_o[7];
  /* T80_ALU.vhd:214:70  */
  assign n7405_o = n7403_o ^ n7404_o;
  /* T80_ALU.vhd:213:50  */
  assign n7406_o = ~n7405_o;
  /* T80_ALU.vhd:210:25  */
  always @*
    case (n7390_o)
      1'b1: n7407_o = n7356_o;
      default: n7407_o = n7406_o;
    endcase
  /* T80_ALU.vhd:217:54  */
  assign n7408_o = f_in[7];
  /* T80_ALU.vhd:218:54  */
  assign n7409_o = f_in[6];
  /* T80_ALU.vhd:219:54  */
  assign n7410_o = f_in[2];
  assign n7411_o = {n7408_o, n7409_o};
  /* T80_ALU.vhd:216:25  */
  assign n7412_o = arith16 ? n7410_o : n7407_o;
  assign n7413_o = {n7375_o, n7374_o};
  /* T80_ALU.vhd:216:25  */
  assign n7414_o = arith16 ? n7411_o : n7413_o;
  /* T80_ALU.vhd:169:17  */
  assign n7416_o = alu_op == 4'b0000;
  /* T80_ALU.vhd:169:29  */
  assign n7418_o = alu_op == 4'b0001;
  /* T80_ALU.vhd:169:29  */
  assign n7419_o = n7416_o | n7418_o;
  /* T80_ALU.vhd:169:38  */
  assign n7421_o = alu_op == 4'b0010;
  /* T80_ALU.vhd:169:38  */
  assign n7422_o = n7419_o | n7421_o;
  /* T80_ALU.vhd:169:48  */
  assign n7424_o = alu_op == 4'b0011;
  /* T80_ALU.vhd:169:48  */
  assign n7425_o = n7422_o | n7424_o;
  /* T80_ALU.vhd:169:57  */
  assign n7427_o = alu_op == 4'b0100;
  /* T80_ALU.vhd:169:57  */
  assign n7428_o = n7425_o | n7427_o;
  /* T80_ALU.vhd:169:66  */
  assign n7430_o = alu_op == 4'b0101;
  /* T80_ALU.vhd:169:66  */
  assign n7431_o = n7428_o | n7430_o;
  /* T80_ALU.vhd:169:75  */
  assign n7433_o = alu_op == 4'b0110;
  /* T80_ALU.vhd:169:75  */
  assign n7434_o = n7431_o | n7433_o;
  /* T80_ALU.vhd:169:84  */
  assign n7436_o = alu_op == 4'b0111;
  /* T80_ALU.vhd:169:84  */
  assign n7437_o = n7434_o | n7436_o;
  /* T80_ALU.vhd:223:46  */
  assign n7438_o = f_in[4];
  /* T80_ALU.vhd:227:32  */
  assign n7441_o = f_in[1];
  /* T80_ALU.vhd:227:41  */
  assign n7442_o = ~n7441_o;
  assign n7443_o = {1'b0, busa};
  /* T80_ALU.vhd:230:41  */
  assign n7444_o = n7443_o[3:0];
  /* T80_ALU.vhd:230:54  */
  assign n7446_o = $unsigned(n7444_o) > $unsigned(4'b1001);
  /* T80_ALU.vhd:230:65  */
  assign n7447_o = f_in[4];
  /* T80_ALU.vhd:230:58  */
  assign n7448_o = n7446_o | n7447_o;
  assign n7449_o = {1'b0, busa};
  /* T80_ALU.vhd:231:50  */
  assign n7450_o = n7449_o[3:0];
  /* T80_ALU.vhd:231:63  */
  assign n7452_o = $unsigned(n7450_o) > $unsigned(4'b1001);
  /* T80_ALU.vhd:231:41  */
  assign n7455_o = n7452_o ? 1'b1 : 1'b0;
  assign n7456_o = {1'b0, busa};
  /* T80_ALU.vhd:236:56  */
  assign n7458_o = n7456_o + 9'b000000110;
  /* T80_ALU.vhd:230:33  */
  assign n7459_o = n7448_o ? n7455_o : n7438_o;
  assign n7460_o = {1'b0, busa};
  /* T80_ALU.vhd:230:33  */
  assign n7461_o = n7448_o ? n7458_o : n7460_o;
  /* T80_ALU.vhd:239:41  */
  assign n7462_o = n7461_o[8:4];
  /* T80_ALU.vhd:239:54  */
  assign n7464_o = $unsigned(n7462_o) > $unsigned(5'b01001);
  /* T80_ALU.vhd:239:65  */
  assign n7465_o = f_in[0];
  /* T80_ALU.vhd:239:58  */
  assign n7466_o = n7464_o | n7465_o;
  /* T80_ALU.vhd:240:56  */
  assign n7468_o = n7461_o + 9'b001100000;
  /* T80_ALU.vhd:239:33  */
  assign n7469_o = n7466_o ? n7468_o : n7461_o;
  assign n7470_o = {1'b0, busa};
  /* T80_ALU.vhd:244:41  */
  assign n7471_o = n7470_o[3:0];
  /* T80_ALU.vhd:244:54  */
  assign n7473_o = $unsigned(n7471_o) > $unsigned(4'b1001);
  /* T80_ALU.vhd:244:65  */
  assign n7474_o = f_in[4];
  /* T80_ALU.vhd:244:58  */
  assign n7475_o = n7473_o | n7474_o;
  assign n7476_o = {1'b0, busa};
  /* T80_ALU.vhd:245:49  */
  assign n7477_o = n7476_o[3:0];
  /* T80_ALU.vhd:245:62  */
  assign n7479_o = $unsigned(n7477_o) > $unsigned(4'b0101);
  /* T80_ALU.vhd:244:33  */
  assign n7481_o = n7486_o ? 1'b0 : n7438_o;
  assign n7482_o = {1'b0, busa};
  /* T80_ALU.vhd:248:67  */
  assign n7483_o = n7482_o[7:0];
  /* T80_ALU.vhd:248:80  */
  assign n7485_o = n7483_o - 8'b00000110;
  /* T80_ALU.vhd:244:33  */
  assign n7486_o = n7475_o & n7479_o;
  /* T80_ALU.vhd:244:33  */
  assign n7487_o = n7475_o ? n7485_o : busa;
  /* T80_ALU.vhd:250:51  */
  assign n7489_o = $unsigned(busa) > $unsigned(8'b10011001);
  /* T80_ALU.vhd:250:64  */
  assign n7490_o = f_in[0];
  /* T80_ALU.vhd:250:57  */
  assign n7491_o = n7489_o | n7490_o;
  assign n7492_o = {1'b0, n7487_o};
  /* T80_ALU.vhd:251:56  */
  assign n7494_o = n7492_o - 9'b101100000;
  assign n7495_o = {1'b0, n7487_o};
  /* T80_ALU.vhd:250:33  */
  assign n7496_o = n7491_o ? n7494_o : n7495_o;
  /* T80_ALU.vhd:227:25  */
  assign n7497_o = n7442_o ? n7459_o : n7481_o;
  /* T80_ALU.vhd:227:25  */
  assign n7498_o = n7442_o ? n7469_o : n7496_o;
  /* T80_ALU.vhd:254:47  */
  assign n7499_o = n7498_o[3];
  /* T80_ALU.vhd:255:47  */
  assign n7500_o = n7498_o[5];
  /* T80_ALU.vhd:256:46  */
  assign n7501_o = f_in[0];
  /* T80_ALU.vhd:256:63  */
  assign n7502_o = n7498_o[8];
  /* T80_ALU.vhd:256:55  */
  assign n7503_o = n7501_o | n7502_o;
  /* T80_ALU.vhd:257:54  */
  assign n7504_o = n7498_o[7:0];
  /* T80_ALU.vhd:258:33  */
  assign n7505_o = n7498_o[7:0];
  /* T80_ALU.vhd:258:46  */
  assign n7507_o = n7505_o == 8'b00000000;
  /* T80_ALU.vhd:258:25  */
  assign n7510_o = n7507_o ? 1'b1 : 1'b0;
  /* T80_ALU.vhd:263:47  */
  assign n7511_o = n7498_o[7];
  /* T80_ALU.vhd:264:52  */
  assign n7512_o = n7498_o[0];
  /* T80_ALU.vhd:264:65  */
  assign n7513_o = n7498_o[1];
  /* T80_ALU.vhd:264:56  */
  assign n7514_o = n7512_o ^ n7513_o;
  /* T80_ALU.vhd:264:78  */
  assign n7515_o = n7498_o[2];
  /* T80_ALU.vhd:264:69  */
  assign n7516_o = n7514_o ^ n7515_o;
  /* T80_ALU.vhd:264:91  */
  assign n7517_o = n7498_o[3];
  /* T80_ALU.vhd:264:82  */
  assign n7518_o = n7516_o ^ n7517_o;
  /* T80_ALU.vhd:265:38  */
  assign n7519_o = n7498_o[4];
  /* T80_ALU.vhd:264:95  */
  assign n7520_o = n7518_o ^ n7519_o;
  /* T80_ALU.vhd:265:51  */
  assign n7521_o = n7498_o[5];
  /* T80_ALU.vhd:265:42  */
  assign n7522_o = n7520_o ^ n7521_o;
  /* T80_ALU.vhd:265:64  */
  assign n7523_o = n7498_o[6];
  /* T80_ALU.vhd:265:55  */
  assign n7524_o = n7522_o ^ n7523_o;
  /* T80_ALU.vhd:265:77  */
  assign n7525_o = n7498_o[7];
  /* T80_ALU.vhd:265:68  */
  assign n7526_o = n7524_o ^ n7525_o;
  /* T80_ALU.vhd:264:42  */
  assign n7527_o = ~n7526_o;
  /* T80_ALU.vhd:221:17  */
  assign n7529_o = alu_op == 4'b1100;
  /* T80_ALU.vhd:268:48  */
  assign n7530_o = busa[7:4];
  /* T80_ALU.vhd:269:34  */
  assign n7531_o = alu_op[0];
  /* T80_ALU.vhd:270:56  */
  assign n7532_o = busb[7:4];
  /* T80_ALU.vhd:272:56  */
  assign n7533_o = busb[3:0];
  /* T80_ALU.vhd:269:25  */
  assign n7534_o = n7531_o ? n7532_o : n7533_o;
  assign n7537_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:276:45  */
  assign n7538_o = n7537_o[3];
  assign n7539_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:277:45  */
  assign n7540_o = n7539_o[5];
  /* T80_ALU.vhd:278:31  */
  assign n7541_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:278:44  */
  assign n7543_o = n7541_o == 8'b00000000;
  /* T80_ALU.vhd:278:25  */
  assign n7546_o = n7543_o ? 1'b1 : 1'b0;
  assign n7547_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:283:45  */
  assign n7548_o = n7547_o[7];
  assign n7549_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:284:50  */
  assign n7550_o = n7549_o[0];
  assign n7551_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:284:61  */
  assign n7552_o = n7551_o[1];
  /* T80_ALU.vhd:284:54  */
  assign n7553_o = n7550_o ^ n7552_o;
  assign n7554_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:284:72  */
  assign n7555_o = n7554_o[2];
  /* T80_ALU.vhd:284:65  */
  assign n7556_o = n7553_o ^ n7555_o;
  assign n7557_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:284:83  */
  assign n7558_o = n7557_o[3];
  /* T80_ALU.vhd:284:76  */
  assign n7559_o = n7556_o ^ n7558_o;
  assign n7560_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:285:36  */
  assign n7561_o = n7560_o[4];
  /* T80_ALU.vhd:284:87  */
  assign n7562_o = n7559_o ^ n7561_o;
  assign n7563_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:285:47  */
  assign n7564_o = n7563_o[5];
  /* T80_ALU.vhd:285:40  */
  assign n7565_o = n7562_o ^ n7564_o;
  assign n7566_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:285:58  */
  assign n7567_o = n7566_o[6];
  /* T80_ALU.vhd:285:51  */
  assign n7568_o = n7565_o ^ n7567_o;
  assign n7569_o = {n7530_o, n7534_o};
  /* T80_ALU.vhd:285:69  */
  assign n7570_o = n7569_o[7];
  /* T80_ALU.vhd:285:62  */
  assign n7571_o = n7568_o ^ n7570_o;
  /* T80_ALU.vhd:284:42  */
  assign n7572_o = ~n7571_o;
  /* T80_ALU.vhd:266:17  */
  assign n7574_o = alu_op == 4'b1101;
  /* T80_ALU.vhd:266:29  */
  assign n7576_o = alu_op == 4'b1110;
  /* T80_ALU.vhd:266:29  */
  assign n7577_o = n7574_o | n7576_o;
  /* T80_ALU.vhd:290:31  */
  assign n7578_o = busb & bitmask;
  /* T80_ALU.vhd:289:45  */
  assign n7579_o = n7578_o[7];
  /* T80_ALU.vhd:290:44  */
  assign n7581_o = n7578_o == 8'b00000000;
  /* T80_ALU.vhd:290:25  */
  assign n7586_o = n7581_o ? 1'b1 : 1'b0;
  /* T80_ALU.vhd:290:25  */
  assign n7587_o = n7581_o ? 1'b1 : 1'b0;
  /* T80_ALU.vhd:299:30  */
  assign n7590_o = ir[2:0];
  /* T80_ALU.vhd:299:43  */
  assign n7592_o = n7590_o == 3'b110;
  /* T80_ALU.vhd:299:63  */
  assign n7594_o = xy_state != 2'b00;
  /* T80_ALU.vhd:299:51  */
  assign n7595_o = n7592_o | n7594_o;
  /* T80_ALU.vhd:300:52  */
  assign n7596_o = wz[11];
  /* T80_ALU.vhd:301:52  */
  assign n7597_o = wz[13];
  /* T80_ALU.vhd:303:54  */
  assign n7598_o = busb[3];
  /* T80_ALU.vhd:304:54  */
  assign n7599_o = busb[5];
  /* T80_ALU.vhd:299:25  */
  assign n7600_o = n7595_o ? n7596_o : n7598_o;
  /* T80_ALU.vhd:299:25  */
  assign n7601_o = n7595_o ? n7597_o : n7599_o;
  /* T80_ALU.vhd:286:17  */
  assign n7603_o = alu_op == 4'b1001;
  /* T80_ALU.vhd:308:49  */
  assign n7604_o = busb | bitmask;
  /* T80_ALU.vhd:306:17  */
  assign n7606_o = alu_op == 4'b1010;
  /* T80_ALU.vhd:311:53  */
  assign n7607_o = ~bitmask;
  /* T80_ALU.vhd:311:49  */
  assign n7608_o = busb & n7607_o;
  /* T80_ALU.vhd:309:17  */
  assign n7610_o = alu_op == 4'b1011;
  /* T80_ALU.vhd:314:32  */
  assign n7611_o = ir[5:3];
  /* T80_ALU.vhd:316:56  */
  assign n7612_o = busa[6:0];
  /* T80_ALU.vhd:317:47  */
  assign n7613_o = busa[7];
  /* T80_ALU.vhd:318:54  */
  assign n7614_o = busa[7];
  /* T80_ALU.vhd:315:25  */
  assign n7616_o = n7611_o == 3'b000;
  /* T80_ALU.vhd:320:56  */
  assign n7617_o = busa[6:0];
  /* T80_ALU.vhd:321:47  */
  assign n7618_o = f_in[0];
  /* T80_ALU.vhd:322:54  */
  assign n7619_o = busa[7];
  /* T80_ALU.vhd:319:25  */
  assign n7621_o = n7611_o == 3'b010;
  /* T80_ALU.vhd:324:56  */
  assign n7622_o = busa[7:1];
  /* T80_ALU.vhd:325:47  */
  assign n7623_o = busa[0];
  /* T80_ALU.vhd:326:54  */
  assign n7624_o = busa[0];
  /* T80_ALU.vhd:323:25  */
  assign n7626_o = n7611_o == 3'b001;
  /* T80_ALU.vhd:328:56  */
  assign n7627_o = busa[7:1];
  /* T80_ALU.vhd:329:47  */
  assign n7628_o = f_in[0];
  /* T80_ALU.vhd:330:54  */
  assign n7629_o = busa[0];
  /* T80_ALU.vhd:327:25  */
  assign n7631_o = n7611_o == 3'b011;
  /* T80_ALU.vhd:332:56  */
  assign n7632_o = busa[6:0];
  /* T80_ALU.vhd:334:54  */
  assign n7634_o = busa[7];
  /* T80_ALU.vhd:331:25  */
  assign n7636_o = n7611_o == 3'b100;
  /* T80_ALU.vhd:341:64  */
  assign n7637_o = busa[6:0];
  /* T80_ALU.vhd:343:62  */
  assign n7639_o = busa[7];
  /* T80_ALU.vhd:335:25  */
  assign n7641_o = n7611_o == 3'b110;
  /* T80_ALU.vhd:346:56  */
  assign n7642_o = busa[7:1];
  /* T80_ALU.vhd:347:47  */
  assign n7643_o = busa[7];
  /* T80_ALU.vhd:348:54  */
  assign n7644_o = busa[0];
  /* T80_ALU.vhd:345:25  */
  assign n7646_o = n7611_o == 3'b101;
  /* T80_ALU.vhd:350:56  */
  assign n7647_o = busa[7:1];
  /* T80_ALU.vhd:352:54  */
  assign n7649_o = busa[0];
  assign n7650_o = {n7646_o, n7641_o, n7636_o, n7631_o, n7626_o, n7621_o, n7616_o};
  /* T80_ALU.vhd:314:25  */
  always @*
    case (n7650_o)
      7'b1000000: n7651_o = n7644_o;
      7'b0100000: n7651_o = n7639_o;
      7'b0010000: n7651_o = n7634_o;
      7'b0001000: n7651_o = n7629_o;
      7'b0000100: n7651_o = n7624_o;
      7'b0000010: n7651_o = n7619_o;
      7'b0000001: n7651_o = n7614_o;
      default: n7651_o = n7649_o;
    endcase
  assign n7652_o = n7622_o[0];
  assign n7653_o = n7627_o[0];
  assign n7654_o = n7642_o[0];
  assign n7655_o = n7647_o[0];
  /* T80_ALU.vhd:314:25  */
  always @*
    case (n7650_o)
      7'b1000000: n7656_o = n7654_o;
      7'b0100000: n7656_o = 1'b1;
      7'b0010000: n7656_o = 1'b0;
      7'b0001000: n7656_o = n7653_o;
      7'b0000100: n7656_o = n7652_o;
      7'b0000010: n7656_o = n7618_o;
      7'b0000001: n7656_o = n7613_o;
      default: n7656_o = n7655_o;
    endcase
  assign n7657_o = n7612_o[5:0];
  assign n7658_o = n7617_o[5:0];
  assign n7659_o = n7622_o[6:1];
  assign n7660_o = n7627_o[6:1];
  assign n7661_o = n7632_o[5:0];
  assign n7662_o = n7637_o[5:0];
  assign n7663_o = n7642_o[6:1];
  assign n7664_o = n7647_o[6:1];
  /* T80_ALU.vhd:314:25  */
  always @*
    case (n7650_o)
      7'b1000000: n7665_o = n7663_o;
      7'b0100000: n7665_o = n7662_o;
      7'b0010000: n7665_o = n7661_o;
      7'b0001000: n7665_o = n7660_o;
      7'b0000100: n7665_o = n7659_o;
      7'b0000010: n7665_o = n7658_o;
      7'b0000001: n7665_o = n7657_o;
      default: n7665_o = n7664_o;
    endcase
  assign n7666_o = n7612_o[6];
  assign n7667_o = n7617_o[6];
  assign n7668_o = n7632_o[6];
  assign n7669_o = n7637_o[6];
  /* T80_ALU.vhd:314:25  */
  always @*
    case (n7650_o)
      7'b1000000: n7670_o = n7643_o;
      7'b0100000: n7670_o = n7669_o;
      7'b0010000: n7670_o = n7668_o;
      7'b0001000: n7670_o = n7628_o;
      7'b0000100: n7670_o = n7623_o;
      7'b0000010: n7670_o = n7667_o;
      7'b0000001: n7670_o = n7666_o;
      default: n7670_o = 1'b0;
    endcase
  assign n7673_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:356:45  */
  assign n7674_o = n7673_o[3];
  assign n7675_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:357:45  */
  assign n7676_o = n7675_o[5];
  assign n7677_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:358:45  */
  assign n7678_o = n7677_o[7];
  /* T80_ALU.vhd:359:31  */
  assign n7679_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:359:44  */
  assign n7681_o = n7679_o == 8'b00000000;
  /* T80_ALU.vhd:359:25  */
  assign n7684_o = n7681_o ? 1'b1 : 1'b0;
  assign n7685_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:364:50  */
  assign n7686_o = n7685_o[0];
  assign n7687_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:364:61  */
  assign n7688_o = n7687_o[1];
  /* T80_ALU.vhd:364:54  */
  assign n7689_o = n7686_o ^ n7688_o;
  assign n7690_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:364:72  */
  assign n7691_o = n7690_o[2];
  /* T80_ALU.vhd:364:65  */
  assign n7692_o = n7689_o ^ n7691_o;
  assign n7693_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:364:83  */
  assign n7694_o = n7693_o[3];
  /* T80_ALU.vhd:364:76  */
  assign n7695_o = n7692_o ^ n7694_o;
  assign n7696_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:365:36  */
  assign n7697_o = n7696_o[4];
  /* T80_ALU.vhd:364:87  */
  assign n7698_o = n7695_o ^ n7697_o;
  assign n7699_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:365:47  */
  assign n7700_o = n7699_o[5];
  /* T80_ALU.vhd:365:40  */
  assign n7701_o = n7698_o ^ n7700_o;
  assign n7702_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:365:58  */
  assign n7703_o = n7702_o[6];
  /* T80_ALU.vhd:365:51  */
  assign n7704_o = n7701_o ^ n7703_o;
  assign n7705_o = {n7670_o, n7665_o, n7656_o};
  /* T80_ALU.vhd:365:69  */
  assign n7706_o = n7705_o[7];
  /* T80_ALU.vhd:365:62  */
  assign n7707_o = n7704_o ^ n7706_o;
  /* T80_ALU.vhd:364:42  */
  assign n7708_o = ~n7707_o;
  /* T80_ALU.vhd:366:33  */
  assign n7710_o = iset == 2'b00;
  /* T80_ALU.vhd:367:54  */
  assign n7711_o = f_in[2];
  /* T80_ALU.vhd:368:54  */
  assign n7712_o = f_in[7];
  /* T80_ALU.vhd:369:54  */
  assign n7713_o = f_in[6];
  assign n7714_o = {n7712_o, n7713_o};
  /* T80_ALU.vhd:366:25  */
  assign n7715_o = n7710_o ? n7711_o : n7708_o;
  assign n7716_o = {n7678_o, n7684_o};
  /* T80_ALU.vhd:366:25  */
  assign n7717_o = n7710_o ? n7714_o : n7716_o;
  /* T80_ALU.vhd:312:17  */
  assign n7719_o = alu_op == 4'b1000;
  assign n7720_o = {n7719_o, n7610_o, n7606_o, n7603_o, n7577_o, n7529_o, n7437_o};
  assign n7721_o = f_in[0];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7722_o = n7651_o;
      7'b0100000: n7722_o = n7721_o;
      7'b0010000: n7722_o = n7721_o;
      7'b0001000: n7722_o = n7721_o;
      7'b0000100: n7722_o = n7721_o;
      7'b0000010: n7722_o = n7503_o;
      7'b0000001: n7722_o = n7353_o;
      default: n7722_o = n7721_o;
    endcase
  assign n7723_o = f_in[1];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7724_o = 1'b0;
      7'b0100000: n7724_o = n7723_o;
      7'b0010000: n7724_o = n7723_o;
      7'b0001000: n7724_o = 1'b0;
      7'b0000100: n7724_o = 1'b0;
      7'b0000010: n7724_o = n7723_o;
      7'b0000001: n7724_o = n7354_o;
      default: n7724_o = n7723_o;
    endcase
  assign n7725_o = f_in[2];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7726_o = n7715_o;
      7'b0100000: n7726_o = n7725_o;
      7'b0010000: n7726_o = n7725_o;
      7'b0001000: n7726_o = n7586_o;
      7'b0000100: n7726_o = n7572_o;
      7'b0000010: n7726_o = n7527_o;
      7'b0000001: n7726_o = n7412_o;
      default: n7726_o = n7725_o;
    endcase
  assign n7727_o = f_in[3];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7728_o = n7674_o;
      7'b0100000: n7728_o = n7727_o;
      7'b0010000: n7728_o = n7727_o;
      7'b0001000: n7728_o = n7600_o;
      7'b0000100: n7728_o = n7538_o;
      7'b0000010: n7728_o = n7499_o;
      7'b0000001: n7728_o = n7366_o;
      default: n7728_o = n7727_o;
    endcase
  assign n7729_o = f_in[4];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7730_o = 1'b0;
      7'b0100000: n7730_o = n7729_o;
      7'b0010000: n7730_o = n7729_o;
      7'b0001000: n7730_o = 1'b1;
      7'b0000100: n7730_o = 1'b0;
      7'b0000010: n7730_o = n7497_o;
      7'b0000001: n7730_o = n7357_o;
      default: n7730_o = n7729_o;
    endcase
  assign n7731_o = f_in[5];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7732_o = n7676_o;
      7'b0100000: n7732_o = n7731_o;
      7'b0010000: n7732_o = n7731_o;
      7'b0001000: n7732_o = n7601_o;
      7'b0000100: n7732_o = n7540_o;
      7'b0000010: n7732_o = n7500_o;
      7'b0000001: n7732_o = n7367_o;
      default: n7732_o = n7731_o;
    endcase
  assign n7733_o = n7414_o[0];
  assign n7734_o = n7717_o[0];
  assign n7735_o = f_in[6];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7736_o = n7734_o;
      7'b0100000: n7736_o = n7735_o;
      7'b0010000: n7736_o = n7735_o;
      7'b0001000: n7736_o = n7587_o;
      7'b0000100: n7736_o = n7546_o;
      7'b0000010: n7736_o = n7510_o;
      7'b0000001: n7736_o = n7733_o;
      default: n7736_o = n7735_o;
    endcase
  assign n7737_o = n7414_o[1];
  assign n7738_o = n7717_o[1];
  assign n7739_o = f_in[7];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7740_o = n7738_o;
      7'b0100000: n7740_o = n7739_o;
      7'b0010000: n7740_o = n7739_o;
      7'b0001000: n7740_o = n7579_o;
      7'b0000100: n7740_o = n7548_o;
      7'b0000010: n7740_o = n7511_o;
      7'b0000001: n7740_o = n7737_o;
      default: n7740_o = n7739_o;
    endcase
  assign n7748_o = n7358_o[0];
  assign n7749_o = n7504_o[0];
  assign n7750_o = n7534_o[0];
  assign n7751_o = n7578_o[0];
  assign n7752_o = n7604_o[0];
  assign n7753_o = n7608_o[0];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7755_o = n7656_o;
      7'b0100000: n7755_o = n7753_o;
      7'b0010000: n7755_o = n7752_o;
      7'b0001000: n7755_o = n7751_o;
      7'b0000100: n7755_o = n7750_o;
      7'b0000010: n7755_o = n7749_o;
      7'b0000001: n7755_o = n7748_o;
      default: n7755_o = 1'bX;
    endcase
  assign n7756_o = n7358_o[3:1];
  assign n7757_o = n7504_o[3:1];
  assign n7758_o = n7534_o[3:1];
  assign n7759_o = n7578_o[3:1];
  assign n7760_o = n7604_o[3:1];
  assign n7761_o = n7608_o[3:1];
  assign n7762_o = n7665_o[2:0];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7764_o = n7762_o;
      7'b0100000: n7764_o = n7761_o;
      7'b0010000: n7764_o = n7760_o;
      7'b0001000: n7764_o = n7759_o;
      7'b0000100: n7764_o = n7758_o;
      7'b0000010: n7764_o = n7757_o;
      7'b0000001: n7764_o = n7756_o;
      default: n7764_o = 3'bX;
    endcase
  assign n7765_o = n7358_o[6:4];
  assign n7766_o = n7504_o[6:4];
  assign n7767_o = n7530_o[2:0];
  assign n7768_o = n7578_o[6:4];
  assign n7769_o = n7604_o[6:4];
  assign n7770_o = n7608_o[6:4];
  assign n7771_o = n7665_o[5:3];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7773_o = n7771_o;
      7'b0100000: n7773_o = n7770_o;
      7'b0010000: n7773_o = n7769_o;
      7'b0001000: n7773_o = n7768_o;
      7'b0000100: n7773_o = n7767_o;
      7'b0000010: n7773_o = n7766_o;
      7'b0000001: n7773_o = n7765_o;
      default: n7773_o = 3'bX;
    endcase
  assign n7774_o = n7358_o[7];
  assign n7775_o = n7504_o[7];
  assign n7776_o = n7530_o[3];
  assign n7777_o = n7578_o[7];
  assign n7778_o = n7604_o[7];
  assign n7779_o = n7608_o[7];
  /* T80_ALU.vhd:168:17  */
  always @*
    case (n7720_o)
      7'b1000000: n7781_o = n7670_o;
      7'b0100000: n7781_o = n7779_o;
      7'b0010000: n7781_o = n7778_o;
      7'b0001000: n7781_o = n7777_o;
      7'b0000100: n7781_o = n7776_o;
      7'b0000010: n7781_o = n7775_o;
      7'b0000001: n7781_o = n7774_o;
      default: n7781_o = 1'bX;
    endcase
  assign n7789_o = {n7781_o, n7773_o, n7764_o, n7755_o};
  assign n7792_o = {n7314_o, n7292_o, n7270_o};
  assign n7793_o = {n7740_o, n7736_o, n7732_o, n7730_o, n7728_o, n7726_o, n7724_o, n7722_o};
endmodule

module t80_mcode_0_0_1_2_3_4_5_6_7
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
  wire [2:0] n2193_o;
  wire [2:0] n2194_o;
  wire [1:0] n2195_o;
  wire n2197_o;
  wire [2:0] n2200_o;
  wire [2:0] n2201_o;
  wire [3:0] n2203_o;
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
  wire n2330_o;
  wire n2331_o;
  wire n2333_o;
  wire n2334_o;
  wire n2336_o;
  wire n2337_o;
  wire n2339_o;
  wire n2340_o;
  wire n2342_o;
  wire n2343_o;
  wire n2345_o;
  wire n2346_o;
  wire n2348_o;
  wire n2349_o;
  wire [30:0] n2350_o;
  wire n2352_o;
  reg n2355_o;
  reg n2358_o;
  reg [2:0] n2360_o;
  wire n2362_o;
  wire n2364_o;
  wire n2365_o;
  wire n2367_o;
  wire n2368_o;
  wire n2370_o;
  wire n2371_o;
  wire n2373_o;
  wire n2374_o;
  wire n2376_o;
  wire n2377_o;
  wire n2379_o;
  wire n2380_o;
  wire [30:0] n2381_o;
  wire n2383_o;
  wire n2385_o;
  wire [1:0] n2386_o;
  reg n2389_o;
  reg [2:0] n2391_o;
  reg [2:0] n2394_o;
  wire n2396_o;
  wire n2398_o;
  wire n2399_o;
  wire n2401_o;
  wire n2402_o;
  wire n2404_o;
  wire n2405_o;
  wire n2407_o;
  wire n2408_o;
  wire n2410_o;
  wire n2411_o;
  wire n2413_o;
  wire n2414_o;
  wire [30:0] n2415_o;
  wire n2418_o;
  wire n2420_o;
  wire [1:0] n2421_o;
  reg [2:0] n2423_o;
  reg n2425_o;
  reg [2:0] n2428_o;
  reg n2431_o;
  wire n2433_o;
  wire n2435_o;
  wire n2436_o;
  wire n2438_o;
  wire n2439_o;
  wire n2441_o;
  wire n2442_o;
  wire n2444_o;
  wire n2445_o;
  wire n2447_o;
  wire n2448_o;
  wire n2450_o;
  wire n2451_o;
  wire [30:0] n2452_o;
  wire n2455_o;
  wire n2457_o;
  wire [1:0] n2458_o;
  reg n2461_o;
  reg [2:0] n2463_o;
  reg n2465_o;
  reg [2:0] n2468_o;
  reg n2471_o;
  wire n2473_o;
  wire [30:0] n2474_o;
  wire n2476_o;
  wire n2478_o;
  wire [1:0] n2479_o;
  reg n2482_o;
  reg [2:0] n2485_o;
  wire n2487_o;
  wire [30:0] n2488_o;
  wire n2490_o;
  wire n2492_o;
  wire [1:0] n2493_o;
  reg n2496_o;
  reg [2:0] n2499_o;
  wire n2501_o;
  wire [30:0] n2502_o;
  wire n2504_o;
  wire n2506_o;
  wire n2508_o;
  wire [2:0] n2509_o;
  reg n2513_o;
  reg n2516_o;
  reg [2:0] n2519_o;
  reg n2522_o;
  wire n2524_o;
  wire [30:0] n2525_o;
  wire n2527_o;
  wire n2529_o;
  wire [1:0] n2530_o;
  reg [3:0] n2533_o;
  reg [2:0] n2536_o;
  reg [1:0] n2539_o;
  reg n2542_o;
  wire n2544_o;
  wire [30:0] n2545_o;
  wire n2547_o;
  wire n2549_o;
  wire [1:0] n2550_o;
  reg [3:0] n2553_o;
  reg [2:0] n2556_o;
  reg [1:0] n2559_o;
  reg n2562_o;
  wire n2564_o;
  wire [30:0] n2565_o;
  wire n2567_o;
  wire n2569_o;
  wire n2571_o;
  wire [2:0] n2572_o;
  reg n2576_o;
  reg [3:0] n2579_o;
  reg [2:0] n2582_o;
  reg n2585_o;
  reg [1:0] n2588_o;
  reg n2591_o;
  wire n2593_o;
  wire [30:0] n2594_o;
  wire n2596_o;
  wire [2:0] n2598_o;
  wire [2:0] n2600_o;
  wire n2603_o;
  wire n2605_o;
  wire n2607_o;
  wire [2:0] n2609_o;
  wire [2:0] n2611_o;
  wire n2614_o;
  wire n2616_o;
  wire [1:0] n2617_o;
  reg n2621_o;
  reg n2625_o;
  reg [2:0] n2627_o;
  reg n2629_o;
  wire n2631_o;
  wire n2633_o;
  wire n2634_o;
  wire n2636_o;
  wire n2637_o;
  wire n2639_o;
  wire n2640_o;
  wire [30:0] n2641_o;
  wire n2643_o;
  wire n2645_o;
  wire n2648_o;
  wire n2651_o;
  wire [3:0] n2652_o;
  reg n2656_o;
  reg n2659_o;
  reg n2663_o;
  reg [2:0] n2665_o;
  reg [2:0] n2669_o;
  reg n2672_o;
  reg n2675_o;
  wire n2677_o;
  wire [30:0] n2678_o;
  wire n2680_o;
  wire n2682_o;
  wire n2684_o;
  wire n2686_o;
  wire [3:0] n2687_o;
  reg n2691_o;
  reg n2694_o;
  reg [3:0] n2698_o;
  reg [2:0] n2702_o;
  reg n2705_o;
  reg n2708_o;
  reg n2712_o;
  wire n2714_o;
  wire n2716_o;
  wire [30:0] n2717_o;
  wire n2719_o;
  wire [3:0] n2722_o;
  wire [3:0] n2724_o;
  wire n2726_o;
  wire n2728_o;
  wire [3:0] n2731_o;
  wire [3:0] n2733_o;
  wire n2735_o;
  wire n2737_o;
  wire [2:0] n2738_o;
  reg [2:0] n2740_o;
  reg [3:0] n2744_o;
  reg [3:0] n2746_o;
  reg [2:0] n2750_o;
  reg n2754_o;
  wire n2756_o;
  wire n2758_o;
  wire n2759_o;
  wire n2761_o;
  wire n2762_o;
  wire n2764_o;
  wire n2765_o;
  wire [30:0] n2766_o;
  wire n2768_o;
  wire n2770_o;
  wire [2:0] n2772_o;
  wire [2:0] n2774_o;
  wire n2777_o;
  wire n2779_o;
  wire n2781_o;
  wire [2:0] n2783_o;
  wire [2:0] n2785_o;
  wire n2788_o;
  wire n2790_o;
  wire [2:0] n2791_o;
  reg [3:0] n2795_o;
  reg n2799_o;
  reg [2:0] n2801_o;
  reg n2803_o;
  reg [2:0] n2807_o;
  wire n2809_o;
  wire n2811_o;
  wire n2812_o;
  wire n2814_o;
  wire n2815_o;
  wire n2817_o;
  wire n2818_o;
  wire n2820_o;
  wire n2822_o;
  wire n2824_o;
  wire [30:0] n2825_o;
  wire n2827_o;
  wire n2829_o;
  wire n2831_o;
  wire n2833_o;
  wire n2835_o;
  wire [4:0] n2836_o;
  reg [2:0] n2839_o;
  reg [3:0] n2843_o;
  reg n2847_o;
  reg [3:0] n2851_o;
  reg [3:0] n2855_o;
  reg [2:0] n2861_o;
  reg n2864_o;
  reg n2867_o;
  reg n2871_o;
  wire n2873_o;
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
  wire n3022_o;
  wire n3023_o;
  wire n3025_o;
  wire n3026_o;
  wire n3028_o;
  wire n3029_o;
  wire n3031_o;
  wire n3032_o;
  wire n3034_o;
  wire n3035_o;
  wire n3037_o;
  wire n3038_o;
  wire n3040_o;
  wire n3041_o;
  wire [30:0] n3042_o;
  wire n3044_o;
  wire n3047_o;
  wire [1:0] n3048_o;
  reg n3051_o;
  reg [2:0] n3053_o;
  reg [2:0] n3055_o;
  reg n3058_o;
  reg [2:0] n3061_o;
  wire n3063_o;
  wire n3065_o;
  wire n3066_o;
  wire n3068_o;
  wire n3069_o;
  wire n3071_o;
  wire n3072_o;
  wire n3074_o;
  wire n3075_o;
  wire n3077_o;
  wire n3078_o;
  wire n3080_o;
  wire n3081_o;
  wire n3083_o;
  wire n3084_o;
  wire n3086_o;
  wire n3090_o;
  wire n3093_o;
  wire [2:0] n3095_o;
  wire [2:0] n3097_o;
  wire n3100_o;
  wire n3102_o;
  wire n3104_o;
  wire n3105_o;
  wire n3107_o;
  wire n3108_o;
  wire n3110_o;
  wire n3111_o;
  wire n3113_o;
  wire n3114_o;
  wire n3116_o;
  wire n3117_o;
  wire n3119_o;
  wire n3120_o;
  wire n3122_o;
  wire n3123_o;
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
  wire [30:0] n3144_o;
  wire n3146_o;
  wire n3148_o;
  wire n3150_o;
  wire [2:0] n3151_o;
  reg [2:0] n3153_o;
  reg n3156_o;
  reg [2:0] n3158_o;
  reg [3:0] n3161_o;
  reg [3:0] n3163_o;
  reg n3166_o;
  reg n3169_o;
  reg [2:0] n3173_o;
  reg n3176_o;
  wire n3178_o;
  wire n3180_o;
  wire n3182_o;
  wire n3183_o;
  wire n3185_o;
  wire n3186_o;
  wire n3188_o;
  wire n3189_o;
  wire n3191_o;
  wire n3192_o;
  wire n3194_o;
  wire n3195_o;
  wire n3197_o;
  wire n3198_o;
  wire [30:0] n3199_o;
  wire n3201_o;
  wire n3203_o;
  wire n3205_o;
  wire [2:0] n3206_o;
  reg [2:0] n3208_o;
  reg n3211_o;
  reg [2:0] n3213_o;
  reg [3:0] n3216_o;
  reg [3:0] n3218_o;
  reg n3221_o;
  reg n3224_o;
  reg [2:0] n3228_o;
  reg n3231_o;
  wire n3233_o;
  wire n3236_o;
  wire n3238_o;
  wire n3240_o;
  wire n3242_o;
  wire [30:0] n3243_o;
  wire n3245_o;
  wire n3247_o;
  wire n3249_o;
  wire [2:0] n3250_o;
  reg [2:0] n3252_o;
  reg [3:0] n3256_o;
  reg [3:0] n3260_o;
  reg [2:0] n3264_o;
  reg n3268_o;
  wire [30:0] n3269_o;
  wire n3271_o;
  wire n3273_o;
  wire n3275_o;
  wire n3277_o;
  wire n3279_o;
  wire [4:0] n3280_o;
  reg [2:0] n3282_o;
  reg n3285_o;
  reg [3:0] n3289_o;
  reg [3:0] n3293_o;
  reg [2:0] n3297_o;
  reg n3300_o;
  reg n3304_o;
  reg n3308_o;
  wire [2:0] n3311_o;
  wire [2:0] n3312_o;
  wire n3314_o;
  wire [3:0] n3316_o;
  wire [3:0] n3318_o;
  wire [2:0] n3320_o;
  wire n3322_o;
  wire n3324_o;
  wire n3326_o;
  wire [2:0] n3328_o;
  wire [2:0] n3329_o;
  wire n3331_o;
  wire [3:0] n3332_o;
  wire [3:0] n3333_o;
  wire [2:0] n3334_o;
  wire n3336_o;
  wire n3338_o;
  wire n3339_o;
  wire n3341_o;
  wire n3343_o;
  wire n3345_o;
  wire n3347_o;
  wire [30:0] n3348_o;
  wire [1:0] n3350_o;
  wire [30:0] n3351_o;
  wire [1:0] n3352_o;
  wire n3355_o;
  wire n3357_o;
  wire n3358_o;
  wire n3360_o;
  wire n3361_o;
  reg n3363_o;
  reg [1:0] n3365_o;
  reg n3368_o;
  wire n3370_o;
  wire [1:0] n3372_o;
  wire [30:0] n3373_o;
  wire [1:0] n3374_o;
  wire n3376_o;
  wire n3378_o;
  wire n3379_o;
  wire n3381_o;
  wire n3382_o;
  reg n3385_o;
  reg [1:0] n3387_o;
  reg n3390_o;
  wire n3392_o;
  wire [1:0] n3393_o;
  reg [2:0] n3395_o;
  reg n3399_o;
  reg [2:0] n3401_o;
  reg n3403_o;
  reg [1:0] n3405_o;
  reg n3407_o;
  reg [3:0] n3410_o;
  reg n3414_o;
  reg n3418_o;
  reg [1:0] n3421_o;
  reg n3425_o;
  wire n3427_o;
  wire n3429_o;
  wire n3430_o;
  wire n3432_o;
  wire n3433_o;
  wire n3435_o;
  wire n3436_o;
  wire n3439_o;
  wire n3441_o;
  wire n3442_o;
  wire n3444_o;
  wire n3445_o;
  wire n3447_o;
  wire n3448_o;
  wire n3451_o;
  wire n3453_o;
  wire n3454_o;
  wire n3456_o;
  wire n3457_o;
  wire n3459_o;
  wire n3460_o;
  wire n3463_o;
  wire n3465_o;
  wire n3466_o;
  wire n3468_o;
  wire n3469_o;
  wire n3471_o;
  wire n3472_o;
  wire [30:0] n3473_o;
  wire n3475_o;
  wire n3477_o;
  wire [1:0] n3478_o;
  reg n3482_o;
  reg n3485_o;
  reg n3488_o;
  reg n3491_o;
  wire n3493_o;
  wire [30:0] n3495_o;
  wire n3497_o;
  wire [2:0] n3499_o;
  wire n3504_o;
  wire n3505_o;
  wire n3507_o;
  wire n3508_o;
  wire n3510_o;
  wire n3511_o;
  wire n3512_o;
  wire n3514_o;
  wire n3515_o;
  wire n3517_o;
  wire n3518_o;
  wire n3519_o;
  wire n3521_o;
  wire n3522_o;
  wire n3524_o;
  wire n3525_o;
  wire n3526_o;
  wire n3528_o;
  wire n3529_o;
  wire n3531_o;
  wire [7:0] n3532_o;
  reg n3534_o;
  wire n3537_o;
  wire n3539_o;
  wire [1:0] n3540_o;
  reg n3544_o;
  reg n3546_o;
  reg n3549_o;
  reg n3552_o;
  wire n3554_o;
  wire n3556_o;
  wire n3557_o;
  wire n3559_o;
  wire n3560_o;
  wire n3562_o;
  wire n3563_o;
  wire n3565_o;
  wire n3566_o;
  wire n3568_o;
  wire n3569_o;
  wire n3571_o;
  wire n3572_o;
  wire n3574_o;
  wire n3575_o;
  wire [30:0] n3576_o;
  wire n3578_o;
  wire n3580_o;
  wire [1:0] n3581_o;
  reg [2:0] n3583_o;
  reg n3586_o;
  reg n3589_o;
  reg n3592_o;
  wire n3594_o;
  wire [30:0] n3595_o;
  wire n3596_o;
  wire n3597_o;
  wire [2:0] n3600_o;
  wire n3602_o;
  wire n3604_o;
  wire [1:0] n3605_o;
  reg [2:0] n3607_o;
  reg [2:0] n3610_o;
  reg n3613_o;
  reg n3616_o;
  reg n3619_o;
  wire n3621_o;
  wire [30:0] n3622_o;
  wire n3623_o;
  wire [2:0] n3626_o;
  wire n3628_o;
  wire n3630_o;
  wire [1:0] n3631_o;
  reg [2:0] n3633_o;
  reg [2:0] n3636_o;
  reg n3639_o;
  reg n3642_o;
  reg n3645_o;
  wire n3647_o;
  wire [30:0] n3648_o;
  wire n3649_o;
  wire n3650_o;
  wire [2:0] n3653_o;
  wire n3655_o;
  wire n3657_o;
  wire [1:0] n3658_o;
  reg [2:0] n3660_o;
  reg [2:0] n3663_o;
  reg n3666_o;
  reg n3669_o;
  reg n3672_o;
  wire n3674_o;
  wire [30:0] n3675_o;
  wire n3676_o;
  wire [2:0] n3679_o;
  wire n3681_o;
  wire n3683_o;
  wire [1:0] n3684_o;
  reg [2:0] n3686_o;
  reg [2:0] n3689_o;
  reg n3692_o;
  reg n3695_o;
  reg n3698_o;
  wire n3700_o;
  wire n3702_o;
  wire [30:0] n3703_o;
  wire n3706_o;
  wire n3708_o;
  wire n3710_o;
  wire [2:0] n3711_o;
  reg [2:0] n3714_o;
  reg n3717_o;
  reg n3720_o;
  reg [2:0] n3722_o;
  reg [3:0] n3725_o;
  reg [3:0] n3727_o;
  reg n3730_o;
  reg n3733_o;
  reg n3737_o;
  reg n3740_o;
  wire n3742_o;
  wire [30:0] n3743_o;
  wire n3745_o;
  wire n3747_o;
  wire n3749_o;
  wire n3751_o;
  wire [3:0] n3752_o;
  reg [2:0] n3754_o;
  reg n3758_o;
  reg [3:0] n3762_o;
  reg [3:0] n3766_o;
  reg [2:0] n3770_o;
  reg n3773_o;
  reg n3776_o;
  reg n3779_o;
  reg n3783_o;
  wire n3785_o;
  wire [30:0] n3788_o;
  wire n3790_o;
  wire [2:0] n3792_o;
  wire n3797_o;
  wire n3798_o;
  wire n3800_o;
  wire n3801_o;
  wire n3803_o;
  wire n3804_o;
  wire n3805_o;
  wire n3807_o;
  wire n3808_o;
  wire n3810_o;
  wire n3811_o;
  wire n3812_o;
  wire n3814_o;
  wire n3815_o;
  wire n3817_o;
  wire n3818_o;
  wire n3819_o;
  wire n3821_o;
  wire n3822_o;
  wire n3824_o;
  wire [7:0] n3825_o;
  reg n3827_o;
  wire [2:0] n3830_o;
  wire [2:0] n3832_o;
  wire [3:0] n3835_o;
  wire [3:0] n3838_o;
  wire [2:0] n3841_o;
  wire n3843_o;
  wire n3845_o;
  wire n3847_o;
  wire [3:0] n3848_o;
  reg [2:0] n3850_o;
  reg [2:0] n3852_o;
  reg n3856_o;
  reg [3:0] n3859_o;
  reg [3:0] n3862_o;
  reg [2:0] n3865_o;
  reg n3868_o;
  reg n3871_o;
  reg n3874_o;
  reg n3878_o;
  wire n3880_o;
  wire n3882_o;
  wire n3883_o;
  wire n3885_o;
  wire n3886_o;
  wire n3888_o;
  wire n3889_o;
  wire n3891_o;
  wire n3892_o;
  wire n3894_o;
  wire n3895_o;
  wire n3897_o;
  wire n3898_o;
  wire n3900_o;
  wire n3901_o;
  wire [30:0] n3902_o;
  wire n3904_o;
  wire n3906_o;
  wire n3908_o;
  wire [2:0] n3909_o;
  reg [3:0] n3913_o;
  reg [2:0] n3917_o;
  reg n3920_o;
  reg n3923_o;
  wire n3925_o;
  wire [30:0] n3927_o;
  wire [2:0] n3929_o;
  wire n3934_o;
  wire n3935_o;
  wire n3937_o;
  wire n3938_o;
  wire n3940_o;
  wire n3941_o;
  wire n3942_o;
  wire n3944_o;
  wire n3945_o;
  wire n3947_o;
  wire n3948_o;
  wire n3949_o;
  wire n3951_o;
  wire n3952_o;
  wire n3954_o;
  wire n3955_o;
  wire n3956_o;
  wire n3958_o;
  wire n3959_o;
  wire n3961_o;
  wire [7:0] n3962_o;
  reg n3964_o;
  wire [2:0] n3967_o;
  wire [2:0] n3970_o;
  wire n3972_o;
  wire n3974_o;
  wire n3976_o;
  wire [2:0] n3977_o;
  reg [2:0] n3979_o;
  reg [2:0] n3982_o;
  reg [3:0] n3986_o;
  reg [2:0] n3989_o;
  reg n3992_o;
  reg n3995_o;
  wire n3997_o;
  wire n3999_o;
  wire n4000_o;
  wire n4002_o;
  wire n4003_o;
  wire n4005_o;
  wire n4006_o;
  wire n4008_o;
  wire n4009_o;
  wire n4011_o;
  wire n4012_o;
  wire n4014_o;
  wire n4015_o;
  wire n4017_o;
  wire n4018_o;
  wire [30:0] n4019_o;
  wire n4021_o;
  wire n4023_o;
  wire n4025_o;
  wire [2:0] n4026_o;
  reg [2:0] n4028_o;
  reg [3:0] n4032_o;
  reg [3:0] n4036_o;
  reg [2:0] n4040_o;
  reg n4043_o;
  reg n4047_o;
  wire n4049_o;
  wire n4051_o;
  wire n4052_o;
  wire n4054_o;
  wire n4055_o;
  wire n4057_o;
  wire n4058_o;
  wire n4060_o;
  wire n4061_o;
  wire n4063_o;
  wire n4064_o;
  wire n4066_o;
  wire n4067_o;
  wire n4069_o;
  wire n4070_o;
  wire [30:0] n4071_o;
  wire n4073_o;
  wire n4075_o;
  wire [1:0] n4076_o;
  reg n4079_o;
  reg n4082_o;
  reg [2:0] n4085_o;
  reg n4088_o;
  wire n4090_o;
  wire [30:0] n4091_o;
  wire n4093_o;
  wire n4095_o;
  wire [1:0] n4096_o;
  reg n4099_o;
  reg [3:0] n4102_o;
  reg [2:0] n4105_o;
  reg n4108_o;
  reg n4111_o;
  wire n4113_o;
  wire n4115_o;
  wire n4117_o;
  wire n4119_o;
  wire n4121_o;
  wire n4122_o;
  wire [58:0] n4123_o;
  reg [2:0] n4156_o;
  reg [2:0] n4161_o;
  reg [1:0] n4167_o;
  reg n4170_o;
  reg n4173_o;
  wire [1:0] n4174_o;
  wire [1:0] n4175_o;
  wire [1:0] n4176_o;
  wire [1:0] n4177_o;
  wire [1:0] n4178_o;
  wire [1:0] n4179_o;
  wire [1:0] n4180_o;
  wire [1:0] n4181_o;
  wire [1:0] n4182_o;
  reg [1:0] n4185_o;
  wire [1:0] n4186_o;
  wire [1:0] n4187_o;
  wire [1:0] n4188_o;
  wire [1:0] n4189_o;
  wire [1:0] n4190_o;
  wire [1:0] n4191_o;
  wire [1:0] n4192_o;
  wire [1:0] n4193_o;
  wire [1:0] n4194_o;
  reg [1:0] n4197_o;
  reg n4206_o;
  reg n4209_o;
  wire [2:0] n4210_o;
  reg [2:0] n4213_o;
  wire n4214_o;
  reg n4217_o;
  wire n4218_o;
  wire n4219_o;
  wire n4220_o;
  wire n4221_o;
  wire n4222_o;
  wire n4223_o;
  wire n4224_o;
  wire n4225_o;
  wire n4226_o;
  wire n4227_o;
  wire n4228_o;
  wire n4229_o;
  wire n4231_o;
  wire n4233_o;
  wire n4234_o;
  wire n4235_o;
  wire n4236_o;
  wire n4237_o;
  wire n4238_o;
  wire n4239_o;
  reg n4242_o;
  wire [1:0] n4243_o;
  wire [1:0] n4244_o;
  wire [1:0] n4245_o;
  wire [1:0] n4246_o;
  wire [1:0] n4247_o;
  wire [1:0] n4248_o;
  wire [1:0] n4249_o;
  wire [1:0] n4250_o;
  wire [1:0] n4251_o;
  wire [1:0] n4252_o;
  wire [1:0] n4253_o;
  wire [1:0] n4254_o;
  wire [1:0] n4256_o;
  wire [1:0] n4258_o;
  wire [1:0] n4259_o;
  wire [1:0] n4260_o;
  wire [1:0] n4261_o;
  wire [1:0] n4262_o;
  wire [1:0] n4263_o;
  wire [1:0] n4264_o;
  reg [1:0] n4267_o;
  wire n4268_o;
  wire n4269_o;
  wire n4270_o;
  wire n4271_o;
  wire n4272_o;
  wire n4273_o;
  wire n4275_o;
  wire n4277_o;
  wire n4278_o;
  wire n4279_o;
  wire n4280_o;
  wire n4281_o;
  wire n4282_o;
  wire n4283_o;
  reg n4286_o;
  reg [3:0] n4292_o;
  reg n4300_o;
  reg n4305_o;
  reg n4308_o;
  reg [2:0] n4311_o;
  reg n4314_o;
  reg n4317_o;
  reg n4320_o;
  reg n4324_o;
  reg n4327_o;
  reg n4330_o;
  reg n4333_o;
  reg n4336_o;
  reg n4340_o;
  reg n4344_o;
  reg n4348_o;
  reg n4352_o;
  reg n4356_o;
  reg n4359_o;
  reg n4363_o;
  reg n4367_o;
  reg n4371_o;
  reg [1:0] n4374_o;
  reg n4378_o;
  reg n4382_o;
  reg n4386_o;
  reg n4389_o;
  reg n4392_o;
  wire n4394_o;
  wire [2:0] n4395_o;
  wire [2:0] n4396_o;
  wire n4398_o;
  wire n4400_o;
  wire n4403_o;
  wire [3:0] n4405_o;
  wire n4408_o;
  wire [30:0] n4409_o;
  wire n4411_o;
  wire n4413_o;
  wire n4414_o;
  wire n4416_o;
  wire n4418_o;
  wire [2:0] n4419_o;
  reg [2:0] n4421_o;
  reg n4424_o;
  reg [3:0] n4426_o;
  reg n4429_o;
  reg [2:0] n4433_o;
  reg n4436_o;
  wire [2:0] n4439_o;
  wire [2:0] n4440_o;
  wire n4441_o;
  wire [3:0] n4442_o;
  wire n4443_o;
  wire [2:0] n4445_o;
  wire n4447_o;
  wire n4450_o;
  wire n4452_o;
  wire n4454_o;
  wire n4455_o;
  wire n4457_o;
  wire n4458_o;
  wire n4460_o;
  wire n4461_o;
  wire n4463_o;
  wire n4464_o;
  wire n4466_o;
  wire n4467_o;
  wire n4469_o;
  wire n4470_o;
  wire n4472_o;
  wire n4473_o;
  wire n4475_o;
  wire n4476_o;
  wire n4478_o;
  wire n4479_o;
  wire n4481_o;
  wire n4482_o;
  wire n4484_o;
  wire n4485_o;
  wire n4487_o;
  wire n4488_o;
  wire n4490_o;
  wire n4491_o;
  wire n4493_o;
  wire n4494_o;
  wire n4496_o;
  wire n4497_o;
  wire n4499_o;
  wire n4500_o;
  wire n4502_o;
  wire n4503_o;
  wire n4505_o;
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
  wire [30:0] n4618_o;
  wire n4620_o;
  wire n4622_o;
  wire n4623_o;
  wire n4625_o;
  wire n4627_o;
  wire [2:0] n4628_o;
  reg [2:0] n4630_o;
  reg n4633_o;
  reg [3:0] n4635_o;
  reg n4638_o;
  reg [2:0] n4642_o;
  reg n4645_o;
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
  wire n4672_o;
  wire [2:0] n4673_o;
  wire [2:0] n4674_o;
  wire [3:0] n4676_o;
  wire [30:0] n4677_o;
  wire n4679_o;
  wire n4681_o;
  wire n4682_o;
  wire n4684_o;
  wire [1:0] n4685_o;
  reg [2:0] n4687_o;
  reg [3:0] n4689_o;
  reg [2:0] n4692_o;
  wire [2:0] n4695_o;
  wire [2:0] n4696_o;
  wire n4697_o;
  wire [3:0] n4698_o;
  wire [2:0] n4700_o;
  wire n4703_o;
  wire n4705_o;
  wire n4707_o;
  wire n4708_o;
  wire n4710_o;
  wire n4711_o;
  wire n4713_o;
  wire n4714_o;
  wire n4716_o;
  wire n4717_o;
  wire n4719_o;
  wire n4720_o;
  wire n4722_o;
  wire n4723_o;
  wire n4725_o;
  wire n4726_o;
  wire n4728_o;
  wire n4729_o;
  wire n4731_o;
  wire n4732_o;
  wire n4734_o;
  wire n4735_o;
  wire n4737_o;
  wire n4738_o;
  wire n4740_o;
  wire n4741_o;
  wire n4743_o;
  wire n4744_o;
  wire n4746_o;
  wire n4747_o;
  wire n4749_o;
  wire n4750_o;
  wire n4752_o;
  wire n4753_o;
  wire n4755_o;
  wire n4756_o;
  wire n4758_o;
  wire n4759_o;
  wire n4761_o;
  wire n4762_o;
  wire n4764_o;
  wire n4765_o;
  wire n4767_o;
  wire n4768_o;
  wire n4770_o;
  wire n4771_o;
  wire n4773_o;
  wire n4774_o;
  wire n4776_o;
  wire n4777_o;
  wire n4779_o;
  wire n4780_o;
  wire n4782_o;
  wire n4783_o;
  wire n4785_o;
  wire n4786_o;
  wire n4788_o;
  wire n4789_o;
  wire n4791_o;
  wire n4792_o;
  wire n4794_o;
  wire n4795_o;
  wire n4797_o;
  wire n4798_o;
  wire n4800_o;
  wire n4801_o;
  wire n4803_o;
  wire n4804_o;
  wire n4806_o;
  wire n4807_o;
  wire n4809_o;
  wire n4810_o;
  wire n4812_o;
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
  wire n4836_o;
  wire n4837_o;
  wire n4839_o;
  wire n4840_o;
  wire n4842_o;
  wire n4843_o;
  wire n4845_o;
  wire n4846_o;
  wire n4848_o;
  wire n4849_o;
  wire n4851_o;
  wire n4852_o;
  wire n4854_o;
  wire n4855_o;
  wire n4857_o;
  wire n4858_o;
  wire n4860_o;
  wire n4861_o;
  wire n4863_o;
  wire n4864_o;
  wire n4866_o;
  wire n4867_o;
  wire n4869_o;
  wire n4870_o;
  wire [30:0] n4871_o;
  wire n4873_o;
  wire n4875_o;
  wire n4876_o;
  wire n4878_o;
  wire [1:0] n4879_o;
  reg [2:0] n4881_o;
  reg [3:0] n4883_o;
  reg [2:0] n4886_o;
  wire n4888_o;
  wire n4890_o;
  wire n4891_o;
  wire n4893_o;
  wire n4894_o;
  wire n4896_o;
  wire n4897_o;
  wire n4899_o;
  wire n4900_o;
  wire n4902_o;
  wire n4903_o;
  wire n4905_o;
  wire n4906_o;
  wire n4908_o;
  wire n4909_o;
  wire n4911_o;
  wire n4913_o;
  wire n4916_o;
  wire [3:0] n4918_o;
  wire n4921_o;
  wire [30:0] n4922_o;
  wire n4924_o;
  wire n4926_o;
  wire n4927_o;
  wire n4929_o;
  wire n4931_o;
  wire [2:0] n4932_o;
  reg [2:0] n4934_o;
  reg n4937_o;
  reg [3:0] n4939_o;
  reg n4942_o;
  reg [2:0] n4946_o;
  reg n4949_o;
  wire [2:0] n4952_o;
  wire [2:0] n4953_o;
  wire n4954_o;
  wire [3:0] n4955_o;
  wire n4956_o;
  wire [2:0] n4958_o;
  wire n4960_o;
  wire n4963_o;
  wire n4965_o;
  wire n4967_o;
  wire n4968_o;
  wire n4970_o;
  wire n4971_o;
  wire n4973_o;
  wire n4974_o;
  wire n4976_o;
  wire n4977_o;
  wire n4979_o;
  wire n4980_o;
  wire n4982_o;
  wire n4983_o;
  wire n4985_o;
  wire n4986_o;
  wire n4988_o;
  wire n4989_o;
  wire n4991_o;
  wire n4992_o;
  wire n4994_o;
  wire n4995_o;
  wire n4997_o;
  wire n4998_o;
  wire n5000_o;
  wire n5001_o;
  wire n5003_o;
  wire n5004_o;
  wire n5006_o;
  wire n5007_o;
  wire n5009_o;
  wire n5010_o;
  wire n5012_o;
  wire n5013_o;
  wire n5015_o;
  wire n5016_o;
  wire n5018_o;
  wire n5019_o;
  wire n5021_o;
  wire n5022_o;
  wire n5024_o;
  wire n5025_o;
  wire n5027_o;
  wire n5028_o;
  wire n5030_o;
  wire n5031_o;
  wire n5033_o;
  wire n5034_o;
  wire n5036_o;
  wire n5037_o;
  wire n5039_o;
  wire n5040_o;
  wire n5042_o;
  wire n5043_o;
  wire n5045_o;
  wire n5046_o;
  wire n5048_o;
  wire n5049_o;
  wire n5051_o;
  wire n5052_o;
  wire n5054_o;
  wire n5055_o;
  wire n5057_o;
  wire n5058_o;
  wire n5060_o;
  wire n5061_o;
  wire n5063_o;
  wire n5064_o;
  wire n5066_o;
  wire n5067_o;
  wire n5069_o;
  wire n5070_o;
  wire n5072_o;
  wire n5073_o;
  wire n5075_o;
  wire n5076_o;
  wire n5078_o;
  wire n5079_o;
  wire n5081_o;
  wire n5082_o;
  wire n5084_o;
  wire n5085_o;
  wire n5087_o;
  wire n5088_o;
  wire n5090_o;
  wire n5091_o;
  wire n5093_o;
  wire n5094_o;
  wire n5096_o;
  wire n5097_o;
  wire n5099_o;
  wire n5100_o;
  wire n5102_o;
  wire n5103_o;
  wire n5105_o;
  wire n5106_o;
  wire n5108_o;
  wire n5109_o;
  wire n5111_o;
  wire n5112_o;
  wire n5114_o;
  wire n5115_o;
  wire n5117_o;
  wire n5118_o;
  wire n5120_o;
  wire n5121_o;
  wire n5123_o;
  wire n5124_o;
  wire n5126_o;
  wire n5127_o;
  wire n5129_o;
  wire n5130_o;
  wire [30:0] n5131_o;
  wire n5133_o;
  wire n5135_o;
  wire n5136_o;
  wire n5138_o;
  wire n5140_o;
  wire [2:0] n5141_o;
  reg [2:0] n5143_o;
  reg n5146_o;
  reg [3:0] n5148_o;
  reg n5151_o;
  reg [2:0] n5155_o;
  reg n5158_o;
  wire n5160_o;
  wire n5162_o;
  wire n5163_o;
  wire n5165_o;
  wire n5166_o;
  wire n5168_o;
  wire n5169_o;
  wire n5171_o;
  wire n5172_o;
  wire n5174_o;
  wire n5175_o;
  wire n5177_o;
  wire n5178_o;
  wire n5180_o;
  wire n5181_o;
  wire n5183_o;
  wire n5185_o;
  wire n5188_o;
  wire [3:0] n5190_o;
  wire n5193_o;
  wire [30:0] n5194_o;
  wire n5196_o;
  wire n5198_o;
  wire n5199_o;
  wire n5201_o;
  wire n5203_o;
  wire [2:0] n5204_o;
  reg [2:0] n5206_o;
  reg n5209_o;
  reg [3:0] n5211_o;
  reg n5214_o;
  reg [2:0] n5218_o;
  reg n5221_o;
  wire [2:0] n5224_o;
  wire [2:0] n5225_o;
  wire n5226_o;
  wire [3:0] n5227_o;
  wire n5228_o;
  wire [2:0] n5230_o;
  wire n5232_o;
  wire n5235_o;
  wire n5237_o;
  wire n5239_o;
  wire n5240_o;
  wire n5242_o;
  wire n5243_o;
  wire n5245_o;
  wire n5246_o;
  wire n5248_o;
  wire n5249_o;
  wire n5251_o;
  wire n5252_o;
  wire n5254_o;
  wire n5255_o;
  wire n5257_o;
  wire n5258_o;
  wire n5260_o;
  wire n5261_o;
  wire n5263_o;
  wire n5264_o;
  wire n5266_o;
  wire n5267_o;
  wire n5269_o;
  wire n5270_o;
  wire n5272_o;
  wire n5273_o;
  wire n5275_o;
  wire n5276_o;
  wire n5278_o;
  wire n5279_o;
  wire n5281_o;
  wire n5282_o;
  wire n5284_o;
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
  wire [30:0] n5403_o;
  wire n5405_o;
  wire n5407_o;
  wire n5408_o;
  wire n5410_o;
  wire n5412_o;
  wire [2:0] n5413_o;
  reg [2:0] n5415_o;
  reg n5418_o;
  reg [3:0] n5420_o;
  reg n5423_o;
  reg [2:0] n5427_o;
  reg n5430_o;
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
  wire [7:0] n5454_o;
  reg [2:0] n5460_o;
  reg [2:0] n5462_o;
  reg n5465_o;
  reg [2:0] n5467_o;
  reg [3:0] n5469_o;
  reg n5472_o;
  reg [2:0] n5474_o;
  reg n5477_o;
  reg n5480_o;
  wire n5482_o;
  wire n5484_o;
  wire n5486_o;
  wire n5487_o;
  wire n5489_o;
  wire n5490_o;
  wire n5492_o;
  wire n5493_o;
  wire n5495_o;
  wire n5496_o;
  wire n5498_o;
  wire n5499_o;
  wire n5501_o;
  wire n5502_o;
  wire n5504_o;
  wire n5505_o;
  wire n5507_o;
  wire n5508_o;
  wire n5510_o;
  wire n5511_o;
  wire n5513_o;
  wire n5514_o;
  wire n5516_o;
  wire n5517_o;
  wire n5519_o;
  wire n5520_o;
  wire n5522_o;
  wire n5523_o;
  wire n5525_o;
  wire n5526_o;
  wire n5528_o;
  wire n5529_o;
  wire n5531_o;
  wire n5532_o;
  wire n5534_o;
  wire n5535_o;
  wire n5537_o;
  wire n5538_o;
  wire n5540_o;
  wire n5541_o;
  wire n5543_o;
  wire n5544_o;
  wire n5546_o;
  wire n5547_o;
  wire n5549_o;
  wire n5550_o;
  wire n5552_o;
  wire n5553_o;
  wire n5555_o;
  wire n5556_o;
  wire n5558_o;
  wire n5559_o;
  wire n5561_o;
  wire n5562_o;
  wire n5564_o;
  wire n5565_o;
  wire n5567_o;
  wire n5568_o;
  wire n5570_o;
  wire n5571_o;
  wire n5573_o;
  wire n5574_o;
  wire n5576_o;
  wire n5577_o;
  wire n5579_o;
  wire n5580_o;
  wire n5582_o;
  wire n5583_o;
  wire n5585_o;
  wire n5586_o;
  wire n5588_o;
  wire n5589_o;
  wire n5591_o;
  wire n5592_o;
  wire n5594_o;
  wire n5595_o;
  wire n5597_o;
  wire n5598_o;
  wire n5600_o;
  wire n5601_o;
  wire n5603_o;
  wire n5604_o;
  wire n5606_o;
  wire n5607_o;
  wire n5609_o;
  wire n5610_o;
  wire n5612_o;
  wire n5613_o;
  wire n5615_o;
  wire n5616_o;
  wire n5618_o;
  wire n5619_o;
  wire n5621_o;
  wire n5622_o;
  wire n5624_o;
  wire n5625_o;
  wire n5627_o;
  wire n5628_o;
  wire n5630_o;
  wire n5631_o;
  wire n5633_o;
  wire n5634_o;
  wire n5636_o;
  wire n5637_o;
  wire n5639_o;
  wire n5640_o;
  wire n5642_o;
  wire n5643_o;
  wire n5645_o;
  wire n5646_o;
  wire n5648_o;
  wire n5649_o;
  wire n5651_o;
  wire n5652_o;
  wire n5654_o;
  wire n5655_o;
  wire n5657_o;
  wire n5658_o;
  wire n5660_o;
  wire n5661_o;
  wire n5663_o;
  wire n5664_o;
  wire n5666_o;
  wire n5667_o;
  wire n5669_o;
  wire n5670_o;
  wire n5672_o;
  wire n5673_o;
  wire n5675_o;
  wire n5676_o;
  wire n5678_o;
  wire n5679_o;
  wire n5681_o;
  wire n5682_o;
  wire n5684_o;
  wire n5685_o;
  wire n5687_o;
  wire n5688_o;
  wire n5690_o;
  wire n5691_o;
  wire n5693_o;
  wire n5694_o;
  wire n5696_o;
  wire n5697_o;
  wire n5699_o;
  wire n5700_o;
  wire n5702_o;
  wire n5703_o;
  wire n5705_o;
  wire n5706_o;
  wire n5708_o;
  wire n5709_o;
  wire n5711_o;
  wire n5712_o;
  wire n5714_o;
  wire n5715_o;
  wire n5717_o;
  wire n5718_o;
  wire n5720_o;
  wire n5721_o;
  wire n5723_o;
  wire n5724_o;
  wire n5726_o;
  wire n5727_o;
  wire n5729_o;
  wire n5730_o;
  wire n5732_o;
  wire n5733_o;
  wire n5735_o;
  wire n5736_o;
  wire n5738_o;
  wire n5739_o;
  wire n5741_o;
  wire n5742_o;
  wire n5744_o;
  wire n5745_o;
  wire n5747_o;
  wire n5748_o;
  wire n5750_o;
  wire n5751_o;
  wire n5753_o;
  wire n5754_o;
  wire n5756_o;
  wire n5757_o;
  wire n5759_o;
  wire n5760_o;
  wire n5762_o;
  wire n5763_o;
  wire n5765_o;
  wire n5766_o;
  wire n5768_o;
  wire n5769_o;
  wire n5771_o;
  wire n5772_o;
  wire n5774_o;
  wire n5775_o;
  wire n5777_o;
  wire n5778_o;
  wire n5780_o;
  wire n5781_o;
  wire n5783_o;
  wire n5784_o;
  wire n5786_o;
  wire n5787_o;
  wire n5789_o;
  wire n5790_o;
  wire n5792_o;
  wire n5793_o;
  wire n5795_o;
  wire n5796_o;
  wire n5798_o;
  wire n5799_o;
  wire n5801_o;
  wire n5802_o;
  wire n5804_o;
  wire n5805_o;
  wire n5807_o;
  wire n5808_o;
  wire n5810_o;
  wire n5811_o;
  wire n5813_o;
  wire n5814_o;
  wire n5816_o;
  wire n5817_o;
  wire n5819_o;
  wire n5820_o;
  wire n5822_o;
  wire n5823_o;
  wire n5825_o;
  wire n5826_o;
  wire n5828_o;
  wire n5829_o;
  wire n5831_o;
  wire n5832_o;
  wire n5834_o;
  wire n5835_o;
  wire n5837_o;
  wire n5838_o;
  wire n5840_o;
  wire n5841_o;
  wire n5843_o;
  wire n5844_o;
  wire n5846_o;
  wire n5847_o;
  wire n5849_o;
  wire n5850_o;
  wire n5852_o;
  wire n5853_o;
  wire n5855_o;
  wire n5856_o;
  wire n5858_o;
  wire n5859_o;
  wire n5861_o;
  wire n5862_o;
  wire n5864_o;
  wire n5865_o;
  wire n5867_o;
  wire n5868_o;
  wire n5870_o;
  wire n5871_o;
  wire n5873_o;
  wire n5874_o;
  wire n5876_o;
  wire n5877_o;
  wire n5879_o;
  wire n5880_o;
  wire n5882_o;
  wire n5883_o;
  wire n5885_o;
  wire n5886_o;
  wire n5888_o;
  wire n5889_o;
  wire n5891_o;
  wire n5892_o;
  wire n5894_o;
  wire n5895_o;
  wire n5897_o;
  wire n5898_o;
  wire n5900_o;
  wire n5901_o;
  wire n5903_o;
  wire n5904_o;
  wire n5906_o;
  wire n5907_o;
  wire n5909_o;
  wire n5910_o;
  wire n5912_o;
  wire n5913_o;
  wire n5915_o;
  wire n5916_o;
  wire n5918_o;
  wire n5919_o;
  wire n5921_o;
  wire n5922_o;
  wire n5924_o;
  wire n5925_o;
  wire n5927_o;
  wire n5928_o;
  wire n5930_o;
  wire n5931_o;
  wire n5933_o;
  wire n5934_o;
  wire n5936_o;
  wire n5937_o;
  wire n5939_o;
  wire n5940_o;
  wire n5942_o;
  wire n5943_o;
  wire n5945_o;
  wire n5946_o;
  wire n5948_o;
  wire n5949_o;
  wire n5951_o;
  wire n5952_o;
  wire n5954_o;
  wire n5955_o;
  wire n5957_o;
  wire n5958_o;
  wire n5960_o;
  wire n5961_o;
  wire n5963_o;
  wire n5964_o;
  wire n5966_o;
  wire n5967_o;
  wire n5969_o;
  wire n5970_o;
  wire n5972_o;
  wire n5973_o;
  wire n5975_o;
  wire n5976_o;
  wire n5978_o;
  wire n5979_o;
  wire n5981_o;
  wire n5982_o;
  wire n5984_o;
  wire n5985_o;
  wire n5987_o;
  wire n5988_o;
  wire n5990_o;
  wire n5991_o;
  wire n5993_o;
  wire n5994_o;
  wire n5996_o;
  wire n5997_o;
  wire n5999_o;
  wire n6000_o;
  wire n6002_o;
  wire n6003_o;
  wire n6005_o;
  wire n6006_o;
  wire n6008_o;
  wire n6009_o;
  wire n6011_o;
  wire n6013_o;
  wire n6014_o;
  wire n6016_o;
  wire n6018_o;
  wire n6020_o;
  wire n6022_o;
  wire [30:0] n6023_o;
  wire n6025_o;
  wire n6027_o;
  wire [1:0] n6028_o;
  wire n6030_o;
  wire [1:0] n6031_o;
  wire [2:0] n6033_o;
  wire [2:0] n6035_o;
  wire n6038_o;
  wire n6040_o;
  wire [1:0] n6041_o;
  wire n6043_o;
  wire [1:0] n6044_o;
  wire [2:0] n6046_o;
  wire [2:0] n6048_o;
  wire n6051_o;
  wire n6053_o;
  wire [3:0] n6054_o;
  reg n6058_o;
  reg n6061_o;
  reg n6065_o;
  reg [2:0] n6067_o;
  reg n6069_o;
  reg [2:0] n6073_o;
  reg n6076_o;
  reg n6079_o;
  wire n6081_o;
  wire n6083_o;
  wire n6084_o;
  wire n6086_o;
  wire n6087_o;
  wire n6089_o;
  wire n6090_o;
  wire [30:0] n6091_o;
  wire n6093_o;
  wire [1:0] n6094_o;
  wire n6096_o;
  wire [1:0] n6097_o;
  wire [3:0] n6100_o;
  wire [3:0] n6102_o;
  wire n6104_o;
  wire [1:0] n6105_o;
  wire n6107_o;
  wire [1:0] n6108_o;
  wire [3:0] n6111_o;
  wire [3:0] n6113_o;
  wire n6115_o;
  wire n6117_o;
  wire [3:0] n6118_o;
  reg n6122_o;
  reg n6125_o;
  reg [3:0] n6127_o;
  reg [2:0] n6131_o;
  reg n6134_o;
  reg n6137_o;
  reg n6141_o;
  wire n6143_o;
  wire n6145_o;
  wire n6146_o;
  wire n6148_o;
  wire n6149_o;
  wire n6151_o;
  wire n6152_o;
  wire [30:0] n6153_o;
  wire n6155_o;
  wire n6157_o;
  wire n6158_o;
  wire [3:0] n6161_o;
  wire n6163_o;
  wire n6164_o;
  wire n6165_o;
  wire [3:0] n6168_o;
  wire n6170_o;
  wire n6172_o;
  wire [3:0] n6173_o;
  reg [2:0] n6176_o;
  reg [3:0] n6179_o;
  reg [2:0] n6181_o;
  reg [3:0] n6184_o;
  reg [3:0] n6186_o;
  reg [2:0] n6190_o;
  reg n6193_o;
  reg n6196_o;
  reg n6199_o;
  wire n6201_o;
  wire n6203_o;
  wire n6204_o;
  wire n6206_o;
  wire n6207_o;
  wire n6209_o;
  wire n6210_o;
  wire [30:0] n6211_o;
  wire n6213_o;
  wire n6215_o;
  wire n6216_o;
  wire [3:0] n6219_o;
  wire n6221_o;
  wire n6223_o;
  wire n6225_o;
  wire [3:0] n6226_o;
  reg [2:0] n6229_o;
  reg [3:0] n6232_o;
  reg [2:0] n6234_o;
  reg [3:0] n6237_o;
  reg [3:0] n6239_o;
  reg n6242_o;
  reg n6245_o;
  reg [2:0] n6248_o;
  reg n6251_o;
  reg n6255_o;
  wire n6257_o;
  wire n6259_o;
  wire n6260_o;
  wire n6262_o;
  wire n6263_o;
  wire n6265_o;
  wire n6266_o;
  wire n6268_o;
  wire n6270_o;
  wire n6271_o;
  wire n6273_o;
  wire n6274_o;
  wire n6276_o;
  wire n6277_o;
  wire n6279_o;
  wire n6280_o;
  wire n6282_o;
  wire n6283_o;
  wire n6285_o;
  wire n6286_o;
  wire n6288_o;
  wire n6289_o;
  wire n6291_o;
  wire n6293_o;
  wire n6294_o;
  wire n6296_o;
  wire n6297_o;
  wire n6299_o;
  wire n6300_o;
  wire n6302_o;
  wire n6304_o;
  wire n6305_o;
  wire n6307_o;
  wire n6309_o;
  wire n6310_o;
  wire [30:0] n6311_o;
  wire [1:0] n6313_o;
  wire [30:0] n6314_o;
  wire [1:0] n6315_o;
  wire n6318_o;
  wire n6320_o;
  wire n6321_o;
  wire n6323_o;
  wire n6324_o;
  reg n6326_o;
  reg [1:0] n6328_o;
  reg n6331_o;
  wire n6333_o;
  wire [1:0] n6335_o;
  wire [30:0] n6336_o;
  wire [1:0] n6337_o;
  wire n6340_o;
  wire n6342_o;
  wire n6343_o;
  wire n6345_o;
  wire n6346_o;
  reg n6348_o;
  reg [1:0] n6350_o;
  reg n6353_o;
  wire n6355_o;
  wire [1:0] n6356_o;
  reg [2:0] n6358_o;
  reg n6362_o;
  reg [2:0] n6364_o;
  reg n6366_o;
  reg [1:0] n6368_o;
  reg n6370_o;
  reg [3:0] n6373_o;
  reg n6377_o;
  reg [1:0] n6380_o;
  reg n6384_o;
  wire n6386_o;
  wire n6388_o;
  wire n6389_o;
  wire n6391_o;
  wire n6392_o;
  wire n6394_o;
  wire n6395_o;
  wire [30:0] n6396_o;
  wire [1:0] n6398_o;
  wire [30:0] n6399_o;
  wire [1:0] n6400_o;
  wire n6403_o;
  wire n6405_o;
  wire n6406_o;
  wire n6408_o;
  wire n6409_o;
  reg n6411_o;
  reg [1:0] n6413_o;
  reg n6416_o;
  wire n6418_o;
  wire [1:0] n6420_o;
  wire [30:0] n6421_o;
  wire [1:0] n6422_o;
  wire n6424_o;
  wire n6426_o;
  wire n6427_o;
  wire n6429_o;
  wire n6430_o;
  reg n6433_o;
  reg [1:0] n6435_o;
  reg n6438_o;
  wire n6440_o;
  wire [1:0] n6441_o;
  reg [2:0] n6443_o;
  reg n6447_o;
  reg [2:0] n6449_o;
  reg n6451_o;
  reg [1:0] n6453_o;
  reg n6455_o;
  reg [3:0] n6458_o;
  reg n6462_o;
  reg [1:0] n6465_o;
  reg n6469_o;
  wire n6471_o;
  wire n6473_o;
  wire n6474_o;
  wire n6476_o;
  wire n6477_o;
  wire n6479_o;
  wire n6480_o;
  wire [30:0] n6481_o;
  wire n6483_o;
  wire n6487_o;
  wire n6489_o;
  wire n6491_o;
  wire [3:0] n6492_o;
  reg [2:0] n6494_o;
  reg n6497_o;
  reg [2:0] n6499_o;
  reg [2:0] n6501_o;
  reg [3:0] n6503_o;
  reg n6506_o;
  reg [2:0] n6510_o;
  reg n6513_o;
  reg n6516_o;
  reg n6519_o;
  wire n6521_o;
  wire [30:0] n6522_o;
  wire n6524_o;
  wire n6528_o;
  wire n6530_o;
  wire n6532_o;
  wire [3:0] n6533_o;
  reg [2:0] n6535_o;
  reg n6538_o;
  reg [2:0] n6540_o;
  reg [2:0] n6542_o;
  reg [3:0] n6544_o;
  reg n6547_o;
  reg [2:0] n6551_o;
  reg n6554_o;
  reg n6557_o;
  reg n6560_o;
  wire n6562_o;
  wire [30:0] n6563_o;
  wire n6565_o;
  wire n6567_o;
  wire n6569_o;
  wire [2:0] n6570_o;
  reg [3:0] n6574_o;
  reg [2:0] n6578_o;
  reg n6581_o;
  reg n6584_o;
  reg n6587_o;
  reg n6590_o;
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
  wire [30:0] n6614_o;
  wire n6616_o;
  wire [2:0] n6617_o;
  wire n6619_o;
  wire [2:0] n6620_o;
  wire n6623_o;
  wire [2:0] n6625_o;
  wire n6627_o;
  wire [1:0] n6628_o;
  reg n6630_o;
  reg [2:0] n6632_o;
  reg [2:0] n6635_o;
  reg n6638_o;
  reg n6641_o;
  reg [1:0] n6644_o;
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
  wire [30:0] n6668_o;
  wire [2:0] n6669_o;
  wire [2:0] n6670_o;
  wire n6672_o;
  wire n6675_o;
  wire n6677_o;
  wire n6679_o;
  wire [1:0] n6680_o;
  reg [2:0] n6682_o;
  reg n6684_o;
  reg [2:0] n6687_o;
  reg n6690_o;
  reg [1:0] n6693_o;
  reg n6696_o;
  wire n6698_o;
  wire n6700_o;
  wire n6701_o;
  wire n6703_o;
  wire n6704_o;
  wire n6706_o;
  wire n6707_o;
  wire n6709_o;
  wire n6710_o;
  wire n6712_o;
  wire n6713_o;
  wire n6715_o;
  wire n6716_o;
  wire n6718_o;
  wire n6719_o;
  wire [30:0] n6720_o;
  wire n6721_o;
  wire n6723_o;
  wire n6725_o;
  wire n6726_o;
  wire n6727_o;
  wire [3:0] n6730_o;
  wire n6732_o;
  wire n6734_o;
  wire [3:0] n6735_o;
  reg [2:0] n6738_o;
  wire [2:0] n6739_o;
  reg [2:0] n6741_o;
  wire n6742_o;
  reg n6744_o;
  reg n6747_o;
  reg [3:0] n6750_o;
  reg [3:0] n6754_o;
  reg [3:0] n6756_o;
  reg n6759_o;
  reg [2:0] n6763_o;
  reg n6766_o;
  reg n6769_o;
  reg [1:0] n6772_o;
  reg n6775_o;
  reg n6778_o;
  wire n6780_o;
  wire n6782_o;
  wire n6783_o;
  wire n6785_o;
  wire n6786_o;
  wire n6788_o;
  wire n6789_o;
  wire [30:0] n6790_o;
  wire n6792_o;
  wire n6793_o;
  wire n6795_o;
  wire n6796_o;
  wire n6797_o;
  wire [3:0] n6800_o;
  wire n6802_o;
  wire n6804_o;
  wire [3:0] n6805_o;
  reg [2:0] n6808_o;
  wire [2:0] n6809_o;
  reg [2:0] n6811_o;
  wire n6812_o;
  reg n6814_o;
  reg n6817_o;
  reg [3:0] n6820_o;
  reg [3:0] n6824_o;
  reg [3:0] n6826_o;
  reg n6829_o;
  reg [2:0] n6833_o;
  reg n6836_o;
  reg n6839_o;
  reg [1:0] n6842_o;
  reg n6845_o;
  reg n6848_o;
  wire n6850_o;
  wire n6852_o;
  wire n6853_o;
  wire n6855_o;
  wire n6856_o;
  wire n6858_o;
  wire n6859_o;
  wire [22:0] n6860_o;
  reg [2:0] n6876_o;
  reg [2:0] n6882_o;
  reg n6885_o;
  reg n6888_o;
  wire [2:0] n6889_o;
  wire [2:0] n6890_o;
  wire [2:0] n6891_o;
  reg [2:0] n6894_o;
  wire n6895_o;
  wire n6896_o;
  wire n6897_o;
  reg n6900_o;
  reg n6903_o;
  reg n6907_o;
  wire [2:0] n6909_o;
  wire [2:0] n6910_o;
  reg [2:0] n6913_o;
  wire n6915_o;
  wire n6916_o;
  reg n6919_o;
  wire n6920_o;
  wire n6921_o;
  wire n6922_o;
  wire n6924_o;
  wire n6925_o;
  wire n6926_o;
  wire n6927_o;
  wire n6928_o;
  reg n6931_o;
  wire [1:0] n6932_o;
  wire [1:0] n6933_o;
  wire [1:0] n6934_o;
  wire [1:0] n6936_o;
  wire [1:0] n6937_o;
  wire [1:0] n6938_o;
  wire [1:0] n6939_o;
  wire [1:0] n6940_o;
  reg [1:0] n6943_o;
  wire n6944_o;
  wire n6945_o;
  wire n6946_o;
  wire n6948_o;
  wire n6949_o;
  reg n6952_o;
  reg [3:0] n6955_o;
  reg n6959_o;
  reg n6962_o;
  reg [2:0] n6965_o;
  reg n6968_o;
  reg n6971_o;
  reg n6974_o;
  reg n6977_o;
  reg [2:0] n6984_o;
  reg n6987_o;
  reg n6990_o;
  reg n6993_o;
  reg n6996_o;
  reg n6999_o;
  reg n7002_o;
  reg n7005_o;
  reg [1:0] n7008_o;
  reg [1:0] n7014_o;
  reg n7017_o;
  reg n7020_o;
  wire [1:0] n7021_o;
  reg [2:0] n7022_o;
  reg [2:0] n7024_o;
  reg [1:0] n7026_o;
  reg n7029_o;
  reg n7032_o;
  wire [1:0] n7034_o;
  reg [1:0] n7036_o;
  wire n7037_o;
  wire n7038_o;
  reg n7040_o;
  wire n7041_o;
  reg n7043_o;
  reg n7047_o;
  reg n7050_o;
  reg [2:0] n7052_o;
  reg n7054_o;
  wire n7057_o;
  reg n7058_o;
  wire [1:0] n7059_o;
  reg [1:0] n7060_o;
  reg n7062_o;
  reg [3:0] n7066_o;
  reg n7067_o;
  reg n7070_o;
  reg n7073_o;
  reg [2:0] n7075_o;
  reg n7078_o;
  reg n7081_o;
  reg n7084_o;
  reg n7087_o;
  reg n7090_o;
  reg n7093_o;
  reg n7096_o;
  reg n7099_o;
  reg n7102_o;
  reg [2:0] n7105_o;
  reg n7108_o;
  reg n7111_o;
  reg n7114_o;
  reg n7117_o;
  reg n7120_o;
  reg n7123_o;
  reg n7126_o;
  reg n7129_o;
  reg n7132_o;
  reg n7135_o;
  reg n7138_o;
  reg n7141_o;
  reg n7144_o;
  reg n7147_o;
  reg n7150_o;
  reg [1:0] n7153_o;
  reg n7156_o;
  reg n7159_o;
  reg [1:0] n7162_o;
  reg n7165_o;
  reg n7168_o;
  reg n7170_o;
  reg n7173_o;
  wire n7176_o;
  wire n7178_o;
  wire n7180_o;
  wire n7181_o;
  wire [2:0] n7183_o;
  wire n7185_o;
  wire n7186_o;
  wire n7188_o;
  wire n7190_o;
  wire [2:0] n7192_o;
  wire n7195_o;
  wire n7197_o;
  wire n7198_o;
  wire n7200_o;
  wire n7202_o;
  wire [2:0] n7204_o;
  wire n7205_o;
  wire [3:0] n7206_o;
  wire [3:0] n7207_o;
  wire [3:0] n7208_o;
  wire n7209_o;
  wire n7210_o;
  wire [3:0] n7212_o;
  wire [3:0] n7213_o;
  assign mcycles = n7022_o;
  assign tstates = n7204_o;
  assign prefix = n7026_o;
  assign inc_pc = n7200_o;
  assign inc_wz = n7032_o;
  assign incdec_16 = n7212_o;
  assign read_to_reg = n7047_o;
  assign read_to_acc = n7050_o;
  assign set_busa_to = n7213_o;
  assign set_busb_to = n7208_o;
  assign alu_op = n7066_o;
  assign save_alu = n7067_o;
  assign preservec = n7070_o;
  assign arith16 = n7073_o;
  assign set_addr_to = n7192_o;
  assign iorq = n7078_o;
  assign jump = n7081_o;
  assign jumpe = n7084_o;
  assign jumpxy = n7087_o;
  assign call = n7090_o;
  assign rstp = n7093_o;
  assign ldz = n7096_o;
  assign ldw = n7099_o;
  assign ldsphl = n7102_o;
  assign special_ld = n7105_o;
  assign exchangedh = n7108_o;
  assign exchangerp = n7111_o;
  assign exchangeaf = n7114_o;
  assign exchangers = n7117_o;
  assign i_djnz = n7120_o;
  assign i_cpl = n7123_o;
  assign i_ccf = n7126_o;
  assign i_scf = n7129_o;
  assign i_retn = n7132_o;
  assign i_bt = n7135_o;
  assign i_bc = n7138_o;
  assign i_btr = n7141_o;
  assign i_rld = n7144_o;
  assign i_rrd = n7147_o;
  assign i_inrc = n7150_o;
  assign setwz = n7153_o;
  assign setdi = n7156_o;
  assign setei = n7159_o;
  assign imode = n7162_o;
  assign halt = n7165_o;
  assign noread = n7210_o;
  assign write = n7170_o;
  assign xybit_undoc = n7173_o;
  /* T80_MCode.vhd:198:26  */
  assign n2193_o = ir[5:3];
  /* T80_MCode.vhd:199:26  */
  assign n2194_o = ir[2:0];
  /* T80_MCode.vhd:200:28  */
  assign n2195_o = ir[5:4];
  /* T80_MCode.vhd:204:27  */
  assign n2197_o = mcycle == 3'b001;
  /* T80_MCode.vhd:204:17  */
  assign n2200_o = n2197_o ? 3'b100 : 3'b011;
  /* T80_MCode.vhd:217:35  */
  assign n2201_o = ir[5:3];
  /* T80_MCode.vhd:217:31  */
  assign n2203_o = {1'b0, n2201_o};
  /* T80_MCode.vhd:267:17  */
  assign n2205_o = ir == 8'b01000000;
  /* T80_MCode.vhd:267:32  */
  assign n2207_o = ir == 8'b01000001;
  /* T80_MCode.vhd:267:32  */
  assign n2208_o = n2205_o | n2207_o;
  /* T80_MCode.vhd:267:43  */
  assign n2210_o = ir == 8'b01000010;
  /* T80_MCode.vhd:267:43  */
  assign n2211_o = n2208_o | n2210_o;
  /* T80_MCode.vhd:267:54  */
  assign n2213_o = ir == 8'b01000011;
  /* T80_MCode.vhd:267:54  */
  assign n2214_o = n2211_o | n2213_o;
  /* T80_MCode.vhd:267:65  */
  assign n2216_o = ir == 8'b01000100;
  /* T80_MCode.vhd:267:65  */
  assign n2217_o = n2214_o | n2216_o;
  /* T80_MCode.vhd:267:76  */
  assign n2219_o = ir == 8'b01000101;
  /* T80_MCode.vhd:267:76  */
  assign n2220_o = n2217_o | n2219_o;
  /* T80_MCode.vhd:267:87  */
  assign n2222_o = ir == 8'b01000111;
  /* T80_MCode.vhd:267:87  */
  assign n2223_o = n2220_o | n2222_o;
  /* T80_MCode.vhd:268:25  */
  assign n2225_o = ir == 8'b01001000;
  /* T80_MCode.vhd:268:25  */
  assign n2226_o = n2223_o | n2225_o;
  /* T80_MCode.vhd:268:36  */
  assign n2228_o = ir == 8'b01001001;
  /* T80_MCode.vhd:268:36  */
  assign n2229_o = n2226_o | n2228_o;
  /* T80_MCode.vhd:268:47  */
  assign n2231_o = ir == 8'b01001010;
  /* T80_MCode.vhd:268:47  */
  assign n2232_o = n2229_o | n2231_o;
  /* T80_MCode.vhd:268:58  */
  assign n2234_o = ir == 8'b01001011;
  /* T80_MCode.vhd:268:58  */
  assign n2235_o = n2232_o | n2234_o;
  /* T80_MCode.vhd:268:69  */
  assign n2237_o = ir == 8'b01001100;
  /* T80_MCode.vhd:268:69  */
  assign n2238_o = n2235_o | n2237_o;
  /* T80_MCode.vhd:268:80  */
  assign n2240_o = ir == 8'b01001101;
  /* T80_MCode.vhd:268:80  */
  assign n2241_o = n2238_o | n2240_o;
  /* T80_MCode.vhd:268:91  */
  assign n2243_o = ir == 8'b01001111;
  /* T80_MCode.vhd:268:91  */
  assign n2244_o = n2241_o | n2243_o;
  /* T80_MCode.vhd:269:25  */
  assign n2246_o = ir == 8'b01010000;
  /* T80_MCode.vhd:269:25  */
  assign n2247_o = n2244_o | n2246_o;
  /* T80_MCode.vhd:269:36  */
  assign n2249_o = ir == 8'b01010001;
  /* T80_MCode.vhd:269:36  */
  assign n2250_o = n2247_o | n2249_o;
  /* T80_MCode.vhd:269:47  */
  assign n2252_o = ir == 8'b01010010;
  /* T80_MCode.vhd:269:47  */
  assign n2253_o = n2250_o | n2252_o;
  /* T80_MCode.vhd:269:58  */
  assign n2255_o = ir == 8'b01010011;
  /* T80_MCode.vhd:269:58  */
  assign n2256_o = n2253_o | n2255_o;
  /* T80_MCode.vhd:269:69  */
  assign n2258_o = ir == 8'b01010100;
  /* T80_MCode.vhd:269:69  */
  assign n2259_o = n2256_o | n2258_o;
  /* T80_MCode.vhd:269:80  */
  assign n2261_o = ir == 8'b01010101;
  /* T80_MCode.vhd:269:80  */
  assign n2262_o = n2259_o | n2261_o;
  /* T80_MCode.vhd:269:91  */
  assign n2264_o = ir == 8'b01010111;
  /* T80_MCode.vhd:269:91  */
  assign n2265_o = n2262_o | n2264_o;
  /* T80_MCode.vhd:270:25  */
  assign n2267_o = ir == 8'b01011000;
  /* T80_MCode.vhd:270:25  */
  assign n2268_o = n2265_o | n2267_o;
  /* T80_MCode.vhd:270:36  */
  assign n2270_o = ir == 8'b01011001;
  /* T80_MCode.vhd:270:36  */
  assign n2271_o = n2268_o | n2270_o;
  /* T80_MCode.vhd:270:47  */
  assign n2273_o = ir == 8'b01011010;
  /* T80_MCode.vhd:270:47  */
  assign n2274_o = n2271_o | n2273_o;
  /* T80_MCode.vhd:270:58  */
  assign n2276_o = ir == 8'b01011011;
  /* T80_MCode.vhd:270:58  */
  assign n2277_o = n2274_o | n2276_o;
  /* T80_MCode.vhd:270:69  */
  assign n2279_o = ir == 8'b01011100;
  /* T80_MCode.vhd:270:69  */
  assign n2280_o = n2277_o | n2279_o;
  /* T80_MCode.vhd:270:80  */
  assign n2282_o = ir == 8'b01011101;
  /* T80_MCode.vhd:270:80  */
  assign n2283_o = n2280_o | n2282_o;
  /* T80_MCode.vhd:270:91  */
  assign n2285_o = ir == 8'b01011111;
  /* T80_MCode.vhd:270:91  */
  assign n2286_o = n2283_o | n2285_o;
  /* T80_MCode.vhd:271:25  */
  assign n2288_o = ir == 8'b01100000;
  /* T80_MCode.vhd:271:25  */
  assign n2289_o = n2286_o | n2288_o;
  /* T80_MCode.vhd:271:36  */
  assign n2291_o = ir == 8'b01100001;
  /* T80_MCode.vhd:271:36  */
  assign n2292_o = n2289_o | n2291_o;
  /* T80_MCode.vhd:271:47  */
  assign n2294_o = ir == 8'b01100010;
  /* T80_MCode.vhd:271:47  */
  assign n2295_o = n2292_o | n2294_o;
  /* T80_MCode.vhd:271:58  */
  assign n2297_o = ir == 8'b01100011;
  /* T80_MCode.vhd:271:58  */
  assign n2298_o = n2295_o | n2297_o;
  /* T80_MCode.vhd:271:69  */
  assign n2300_o = ir == 8'b01100100;
  /* T80_MCode.vhd:271:69  */
  assign n2301_o = n2298_o | n2300_o;
  /* T80_MCode.vhd:271:80  */
  assign n2303_o = ir == 8'b01100101;
  /* T80_MCode.vhd:271:80  */
  assign n2304_o = n2301_o | n2303_o;
  /* T80_MCode.vhd:271:91  */
  assign n2306_o = ir == 8'b01100111;
  /* T80_MCode.vhd:271:91  */
  assign n2307_o = n2304_o | n2306_o;
  /* T80_MCode.vhd:272:25  */
  assign n2309_o = ir == 8'b01101000;
  /* T80_MCode.vhd:272:25  */
  assign n2310_o = n2307_o | n2309_o;
  /* T80_MCode.vhd:272:36  */
  assign n2312_o = ir == 8'b01101001;
  /* T80_MCode.vhd:272:36  */
  assign n2313_o = n2310_o | n2312_o;
  /* T80_MCode.vhd:272:47  */
  assign n2315_o = ir == 8'b01101010;
  /* T80_MCode.vhd:272:47  */
  assign n2316_o = n2313_o | n2315_o;
  /* T80_MCode.vhd:272:58  */
  assign n2318_o = ir == 8'b01101011;
  /* T80_MCode.vhd:272:58  */
  assign n2319_o = n2316_o | n2318_o;
  /* T80_MCode.vhd:272:69  */
  assign n2321_o = ir == 8'b01101100;
  /* T80_MCode.vhd:272:69  */
  assign n2322_o = n2319_o | n2321_o;
  /* T80_MCode.vhd:272:80  */
  assign n2324_o = ir == 8'b01101101;
  /* T80_MCode.vhd:272:80  */
  assign n2325_o = n2322_o | n2324_o;
  /* T80_MCode.vhd:272:91  */
  assign n2327_o = ir == 8'b01101111;
  /* T80_MCode.vhd:272:91  */
  assign n2328_o = n2325_o | n2327_o;
  /* T80_MCode.vhd:273:25  */
  assign n2330_o = ir == 8'b01111000;
  /* T80_MCode.vhd:273:25  */
  assign n2331_o = n2328_o | n2330_o;
  /* T80_MCode.vhd:273:36  */
  assign n2333_o = ir == 8'b01111001;
  /* T80_MCode.vhd:273:36  */
  assign n2334_o = n2331_o | n2333_o;
  /* T80_MCode.vhd:273:47  */
  assign n2336_o = ir == 8'b01111010;
  /* T80_MCode.vhd:273:47  */
  assign n2337_o = n2334_o | n2336_o;
  /* T80_MCode.vhd:273:58  */
  assign n2339_o = ir == 8'b01111011;
  /* T80_MCode.vhd:273:58  */
  assign n2340_o = n2337_o | n2339_o;
  /* T80_MCode.vhd:273:69  */
  assign n2342_o = ir == 8'b01111100;
  /* T80_MCode.vhd:273:69  */
  assign n2343_o = n2340_o | n2342_o;
  /* T80_MCode.vhd:273:80  */
  assign n2345_o = ir == 8'b01111101;
  /* T80_MCode.vhd:273:80  */
  assign n2346_o = n2343_o | n2345_o;
  /* T80_MCode.vhd:273:91  */
  assign n2348_o = ir == 8'b01111111;
  /* T80_MCode.vhd:273:91  */
  assign n2349_o = n2346_o | n2348_o;
  /* T80_MCode.vhd:282:30  */
  assign n2350_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:283:25  */
  assign n2352_o = n2350_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:282:25  */
  always @*
    case (n2352_o)
      1'b1: n2355_o = 1'b1;
      default: n2355_o = 1'b0;
    endcase
  /* T80_MCode.vhd:282:25  */
  always @*
    case (n2352_o)
      1'b1: n2358_o = 1'b1;
      default: n2358_o = 1'b0;
    endcase
  /* T80_MCode.vhd:282:25  */
  always @*
    case (n2352_o)
      1'b1: n2360_o = n2193_o;
      default: n2360_o = 3'b000;
    endcase
  /* T80_MCode.vhd:279:17  */
  assign n2362_o = ir == 8'b00000110;
  /* T80_MCode.vhd:279:32  */
  assign n2364_o = ir == 8'b00001110;
  /* T80_MCode.vhd:279:32  */
  assign n2365_o = n2362_o | n2364_o;
  /* T80_MCode.vhd:279:43  */
  assign n2367_o = ir == 8'b00010110;
  /* T80_MCode.vhd:279:43  */
  assign n2368_o = n2365_o | n2367_o;
  /* T80_MCode.vhd:279:54  */
  assign n2370_o = ir == 8'b00011110;
  /* T80_MCode.vhd:279:54  */
  assign n2371_o = n2368_o | n2370_o;
  /* T80_MCode.vhd:279:65  */
  assign n2373_o = ir == 8'b00100110;
  /* T80_MCode.vhd:279:65  */
  assign n2374_o = n2371_o | n2373_o;
  /* T80_MCode.vhd:279:76  */
  assign n2376_o = ir == 8'b00101110;
  /* T80_MCode.vhd:279:76  */
  assign n2377_o = n2374_o | n2376_o;
  /* T80_MCode.vhd:279:87  */
  assign n2379_o = ir == 8'b00111110;
  /* T80_MCode.vhd:279:87  */
  assign n2380_o = n2377_o | n2379_o;
  /* T80_MCode.vhd:292:30  */
  assign n2381_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:293:25  */
  assign n2383_o = n2381_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:295:25  */
  assign n2385_o = n2381_o == 31'b0000000000000000000000000000010;
  assign n2386_o = {n2385_o, n2383_o};
  /* T80_MCode.vhd:292:25  */
  always @*
    case (n2386_o)
      2'b10: n2389_o = 1'b1;
      2'b01: n2389_o = 1'b0;
      default: n2389_o = 1'b0;
    endcase
  /* T80_MCode.vhd:292:25  */
  always @*
    case (n2386_o)
      2'b10: n2391_o = n2193_o;
      2'b01: n2391_o = 3'b000;
      default: n2391_o = 3'b000;
    endcase
  /* T80_MCode.vhd:292:25  */
  always @*
    case (n2386_o)
      2'b10: n2394_o = 3'b111;
      2'b01: n2394_o = 3'b010;
      default: n2394_o = 3'b111;
    endcase
  /* T80_MCode.vhd:289:17  */
  assign n2396_o = ir == 8'b01000110;
  /* T80_MCode.vhd:289:32  */
  assign n2398_o = ir == 8'b01001110;
  /* T80_MCode.vhd:289:32  */
  assign n2399_o = n2396_o | n2398_o;
  /* T80_MCode.vhd:289:43  */
  assign n2401_o = ir == 8'b01010110;
  /* T80_MCode.vhd:289:43  */
  assign n2402_o = n2399_o | n2401_o;
  /* T80_MCode.vhd:289:54  */
  assign n2404_o = ir == 8'b01011110;
  /* T80_MCode.vhd:289:54  */
  assign n2405_o = n2402_o | n2404_o;
  /* T80_MCode.vhd:289:65  */
  assign n2407_o = ir == 8'b01100110;
  /* T80_MCode.vhd:289:65  */
  assign n2408_o = n2405_o | n2407_o;
  /* T80_MCode.vhd:289:76  */
  assign n2410_o = ir == 8'b01101110;
  /* T80_MCode.vhd:289:76  */
  assign n2411_o = n2408_o | n2410_o;
  /* T80_MCode.vhd:289:87  */
  assign n2413_o = ir == 8'b01111110;
  /* T80_MCode.vhd:289:87  */
  assign n2414_o = n2411_o | n2413_o;
  /* T80_MCode.vhd:303:30  */
  assign n2415_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:304:25  */
  assign n2418_o = n2415_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:308:25  */
  assign n2420_o = n2415_o == 31'b0000000000000000000000000000010;
  assign n2421_o = {n2420_o, n2418_o};
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2421_o)
      2'b10: n2423_o = 3'b000;
      2'b01: n2423_o = n2194_o;
      default: n2423_o = 3'b000;
    endcase
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2421_o)
      2'b10: n2425_o = 1'b0;
      2'b01: n2425_o = 1'b0;
      default: n2425_o = 1'b0;
    endcase
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2421_o)
      2'b10: n2428_o = 3'b111;
      2'b01: n2428_o = 3'b010;
      default: n2428_o = 3'b111;
    endcase
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2421_o)
      2'b10: n2431_o = 1'b1;
      2'b01: n2431_o = 1'b0;
      default: n2431_o = 1'b0;
    endcase
  /* T80_MCode.vhd:300:17  */
  assign n2433_o = ir == 8'b01110000;
  /* T80_MCode.vhd:300:32  */
  assign n2435_o = ir == 8'b01110001;
  /* T80_MCode.vhd:300:32  */
  assign n2436_o = n2433_o | n2435_o;
  /* T80_MCode.vhd:300:43  */
  assign n2438_o = ir == 8'b01110010;
  /* T80_MCode.vhd:300:43  */
  assign n2439_o = n2436_o | n2438_o;
  /* T80_MCode.vhd:300:54  */
  assign n2441_o = ir == 8'b01110011;
  /* T80_MCode.vhd:300:54  */
  assign n2442_o = n2439_o | n2441_o;
  /* T80_MCode.vhd:300:65  */
  assign n2444_o = ir == 8'b01110100;
  /* T80_MCode.vhd:300:65  */
  assign n2445_o = n2442_o | n2444_o;
  /* T80_MCode.vhd:300:76  */
  assign n2447_o = ir == 8'b01110101;
  /* T80_MCode.vhd:300:76  */
  assign n2448_o = n2445_o | n2447_o;
  /* T80_MCode.vhd:300:87  */
  assign n2450_o = ir == 8'b01110111;
  /* T80_MCode.vhd:300:87  */
  assign n2451_o = n2448_o | n2450_o;
  /* T80_MCode.vhd:315:30  */
  assign n2452_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:316:25  */
  assign n2455_o = n2452_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:321:25  */
  assign n2457_o = n2452_o == 31'b0000000000000000000000000000011;
  assign n2458_o = {n2457_o, n2455_o};
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2458_o)
      2'b10: n2461_o = 1'b0;
      2'b01: n2461_o = 1'b1;
      default: n2461_o = 1'b0;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2458_o)
      2'b10: n2463_o = 3'b000;
      2'b01: n2463_o = n2194_o;
      default: n2463_o = 3'b000;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2458_o)
      2'b10: n2465_o = 1'b0;
      2'b01: n2465_o = 1'b0;
      default: n2465_o = 1'b0;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2458_o)
      2'b10: n2468_o = 3'b111;
      2'b01: n2468_o = 3'b010;
      default: n2468_o = 3'b111;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2458_o)
      2'b10: n2471_o = 1'b1;
      2'b01: n2471_o = 1'b0;
      default: n2471_o = 1'b0;
    endcase
  /* T80_MCode.vhd:312:17  */
  assign n2473_o = ir == 8'b00110110;
  /* T80_MCode.vhd:328:30  */
  assign n2474_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:329:25  */
  assign n2476_o = n2474_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:331:25  */
  assign n2478_o = n2474_o == 31'b0000000000000000000000000000010;
  assign n2479_o = {n2478_o, n2476_o};
  /* T80_MCode.vhd:328:25  */
  always @*
    case (n2479_o)
      2'b10: n2482_o = 1'b1;
      2'b01: n2482_o = 1'b0;
      default: n2482_o = 1'b0;
    endcase
  /* T80_MCode.vhd:328:25  */
  always @*
    case (n2479_o)
      2'b10: n2485_o = 3'b111;
      2'b01: n2485_o = 3'b000;
      default: n2485_o = 3'b111;
    endcase
  /* T80_MCode.vhd:325:17  */
  assign n2487_o = ir == 8'b00001010;
  /* T80_MCode.vhd:338:30  */
  assign n2488_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:339:25  */
  assign n2490_o = n2488_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:341:25  */
  assign n2492_o = n2488_o == 31'b0000000000000000000000000000010;
  assign n2493_o = {n2492_o, n2490_o};
  /* T80_MCode.vhd:338:25  */
  always @*
    case (n2493_o)
      2'b10: n2496_o = 1'b1;
      2'b01: n2496_o = 1'b0;
      default: n2496_o = 1'b0;
    endcase
  /* T80_MCode.vhd:338:25  */
  always @*
    case (n2493_o)
      2'b10: n2499_o = 3'b111;
      2'b01: n2499_o = 3'b001;
      default: n2499_o = 3'b111;
    endcase
  /* T80_MCode.vhd:335:17  */
  assign n2501_o = ir == 8'b00011010;
  /* T80_MCode.vhd:360:38  */
  assign n2502_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:361:33  */
  assign n2504_o = n2502_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:364:33  */
  assign n2506_o = n2502_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:367:33  */
  assign n2508_o = n2502_o == 31'b0000000000000000000000000000100;
  assign n2509_o = {n2508_o, n2506_o, n2504_o};
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2509_o)
      3'b100: n2513_o = 1'b0;
      3'b010: n2513_o = 1'b1;
      3'b001: n2513_o = 1'b1;
      default: n2513_o = 1'b0;
    endcase
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2509_o)
      3'b100: n2516_o = 1'b1;
      3'b010: n2516_o = 1'b0;
      3'b001: n2516_o = 1'b0;
      default: n2516_o = 1'b0;
    endcase
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2509_o)
      3'b100: n2519_o = 3'b111;
      3'b010: n2519_o = 3'b110;
      3'b001: n2519_o = 3'b111;
      default: n2519_o = 3'b111;
    endcase
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2509_o)
      3'b100: n2522_o = 1'b0;
      3'b010: n2522_o = 1'b0;
      3'b001: n2522_o = 1'b1;
      default: n2522_o = 1'b0;
    endcase
  /* T80_MCode.vhd:345:17  */
  assign n2524_o = ir == 8'b00111010;
  /* T80_MCode.vhd:375:30  */
  assign n2525_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:376:25  */
  assign n2527_o = n2525_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:380:25  */
  assign n2529_o = n2525_o == 31'b0000000000000000000000000000010;
  assign n2530_o = {n2529_o, n2527_o};
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2530_o)
      2'b10: n2533_o = 4'b0000;
      2'b01: n2533_o = 4'b0111;
      default: n2533_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2530_o)
      2'b10: n2536_o = 3'b111;
      2'b01: n2536_o = 3'b000;
      default: n2536_o = 3'b111;
    endcase
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2530_o)
      2'b10: n2539_o = 2'b00;
      2'b01: n2539_o = 2'b10;
      default: n2539_o = 2'b00;
    endcase
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2530_o)
      2'b10: n2542_o = 1'b1;
      2'b01: n2542_o = 1'b0;
      default: n2542_o = 1'b0;
    endcase
  /* T80_MCode.vhd:372:17  */
  assign n2544_o = ir == 8'b00000010;
  /* T80_MCode.vhd:387:30  */
  assign n2545_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:388:25  */
  assign n2547_o = n2545_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:392:25  */
  assign n2549_o = n2545_o == 31'b0000000000000000000000000000010;
  assign n2550_o = {n2549_o, n2547_o};
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2550_o)
      2'b10: n2553_o = 4'b0000;
      2'b01: n2553_o = 4'b0111;
      default: n2553_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2550_o)
      2'b10: n2556_o = 3'b111;
      2'b01: n2556_o = 3'b001;
      default: n2556_o = 3'b111;
    endcase
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2550_o)
      2'b10: n2559_o = 2'b00;
      2'b01: n2559_o = 2'b10;
      default: n2559_o = 2'b00;
    endcase
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2550_o)
      2'b10: n2562_o = 1'b1;
      2'b01: n2562_o = 1'b0;
      default: n2562_o = 1'b0;
    endcase
  /* T80_MCode.vhd:384:17  */
  assign n2564_o = ir == 8'b00010010;
  /* T80_MCode.vhd:412:38  */
  assign n2565_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:413:33  */
  assign n2567_o = n2565_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:416:33  */
  assign n2569_o = n2565_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:421:33  */
  assign n2571_o = n2565_o == 31'b0000000000000000000000000000100;
  assign n2572_o = {n2571_o, n2569_o, n2567_o};
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2572_o)
      3'b100: n2576_o = 1'b0;
      3'b010: n2576_o = 1'b1;
      3'b001: n2576_o = 1'b1;
      default: n2576_o = 1'b0;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2572_o)
      3'b100: n2579_o = 4'b0000;
      3'b010: n2579_o = 4'b0111;
      3'b001: n2579_o = 4'b0000;
      default: n2579_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2572_o)
      3'b100: n2582_o = 3'b111;
      3'b010: n2582_o = 3'b110;
      3'b001: n2582_o = 3'b111;
      default: n2582_o = 3'b111;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2572_o)
      3'b100: n2585_o = 1'b0;
      3'b010: n2585_o = 1'b0;
      3'b001: n2585_o = 1'b1;
      default: n2585_o = 1'b0;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2572_o)
      3'b100: n2588_o = 2'b00;
      3'b010: n2588_o = 2'b10;
      3'b001: n2588_o = 2'b00;
      default: n2588_o = 2'b00;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2572_o)
      3'b100: n2591_o = 1'b1;
      3'b010: n2591_o = 1'b0;
      3'b001: n2591_o = 1'b0;
      default: n2591_o = 1'b0;
    endcase
  /* T80_MCode.vhd:396:17  */
  assign n2593_o = ir == 8'b00110010;
  /* T80_MCode.vhd:431:30  */
  assign n2594_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:435:42  */
  assign n2596_o = n2195_o == 2'b11;
  assign n2598_o = {n2195_o, 1'b1};
  /* T80_MCode.vhd:435:33  */
  assign n2600_o = n2596_o ? 3'b000 : n2598_o;
  /* T80_MCode.vhd:435:33  */
  assign n2603_o = n2596_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:432:25  */
  assign n2605_o = n2594_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:444:42  */
  assign n2607_o = n2195_o == 2'b11;
  assign n2609_o = {n2195_o, 1'b0};
  /* T80_MCode.vhd:444:33  */
  assign n2611_o = n2607_o ? 3'b001 : n2609_o;
  /* T80_MCode.vhd:444:33  */
  assign n2614_o = n2607_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:441:25  */
  assign n2616_o = n2594_o == 31'b0000000000000000000000000000011;
  assign n2617_o = {n2616_o, n2605_o};
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2617_o)
      2'b10: n2621_o = 1'b1;
      2'b01: n2621_o = 1'b1;
      default: n2621_o = 1'b0;
    endcase
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2617_o)
      2'b10: n2625_o = 1'b1;
      2'b01: n2625_o = 1'b1;
      default: n2625_o = 1'b0;
    endcase
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2617_o)
      2'b10: n2627_o = n2611_o;
      2'b01: n2627_o = n2600_o;
      default: n2627_o = 3'b000;
    endcase
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2617_o)
      2'b10: n2629_o = n2614_o;
      2'b01: n2629_o = n2603_o;
      default: n2629_o = 1'b0;
    endcase
  /* T80_MCode.vhd:428:17  */
  assign n2631_o = ir == 8'b00000001;
  /* T80_MCode.vhd:428:32  */
  assign n2633_o = ir == 8'b00010001;
  /* T80_MCode.vhd:428:32  */
  assign n2634_o = n2631_o | n2633_o;
  /* T80_MCode.vhd:428:43  */
  assign n2636_o = ir == 8'b00100001;
  /* T80_MCode.vhd:428:43  */
  assign n2637_o = n2634_o | n2636_o;
  /* T80_MCode.vhd:428:54  */
  assign n2639_o = ir == 8'b00110001;
  /* T80_MCode.vhd:428:54  */
  assign n2640_o = n2637_o | n2639_o;
  /* T80_MCode.vhd:467:38  */
  assign n2641_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:468:33  */
  assign n2643_o = n2641_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:471:33  */
  assign n2645_o = n2641_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:475:33  */
  assign n2648_o = n2641_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:480:33  */
  assign n2651_o = n2641_o == 31'b0000000000000000000000000000101;
  assign n2652_o = {n2651_o, n2648_o, n2645_o, n2643_o};
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2652_o)
      4'b1000: n2656_o = 1'b0;
      4'b0100: n2656_o = 1'b0;
      4'b0010: n2656_o = 1'b1;
      4'b0001: n2656_o = 1'b1;
      default: n2656_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2652_o)
      4'b1000: n2659_o = 1'b0;
      4'b0100: n2659_o = 1'b1;
      4'b0010: n2659_o = 1'b0;
      4'b0001: n2659_o = 1'b0;
      default: n2659_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2652_o)
      4'b1000: n2663_o = 1'b1;
      4'b0100: n2663_o = 1'b1;
      4'b0010: n2663_o = 1'b0;
      4'b0001: n2663_o = 1'b0;
      default: n2663_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2652_o)
      4'b1000: n2665_o = 3'b100;
      4'b0100: n2665_o = 3'b101;
      4'b0010: n2665_o = 3'b000;
      4'b0001: n2665_o = 3'b000;
      default: n2665_o = 3'b000;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2652_o)
      4'b1000: n2669_o = 3'b111;
      4'b0100: n2669_o = 3'b110;
      4'b0010: n2669_o = 3'b110;
      4'b0001: n2669_o = 3'b111;
      default: n2669_o = 3'b111;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2652_o)
      4'b1000: n2672_o = 1'b0;
      4'b0100: n2672_o = 1'b0;
      4'b0010: n2672_o = 1'b0;
      4'b0001: n2672_o = 1'b1;
      default: n2672_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2652_o)
      4'b1000: n2675_o = 1'b0;
      4'b0100: n2675_o = 1'b0;
      4'b0010: n2675_o = 1'b1;
      4'b0001: n2675_o = 1'b0;
      default: n2675_o = 1'b0;
    endcase
  /* T80_MCode.vhd:452:17  */
  assign n2677_o = ir == 8'b00101010;
  /* T80_MCode.vhd:502:38  */
  assign n2678_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:503:33  */
  assign n2680_o = n2678_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:506:33  */
  assign n2682_o = n2678_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:511:33  */
  assign n2684_o = n2678_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:516:33  */
  assign n2686_o = n2678_o == 31'b0000000000000000000000000000101;
  assign n2687_o = {n2686_o, n2684_o, n2682_o, n2680_o};
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2687_o)
      4'b1000: n2691_o = 1'b0;
      4'b0100: n2691_o = 1'b0;
      4'b0010: n2691_o = 1'b1;
      4'b0001: n2691_o = 1'b1;
      default: n2691_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2687_o)
      4'b1000: n2694_o = 1'b0;
      4'b0100: n2694_o = 1'b1;
      4'b0010: n2694_o = 1'b0;
      4'b0001: n2694_o = 1'b0;
      default: n2694_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2687_o)
      4'b1000: n2698_o = 4'b0000;
      4'b0100: n2698_o = 4'b0100;
      4'b0010: n2698_o = 4'b0101;
      4'b0001: n2698_o = 4'b0000;
      default: n2698_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2687_o)
      4'b1000: n2702_o = 3'b111;
      4'b0100: n2702_o = 3'b110;
      4'b0010: n2702_o = 3'b110;
      4'b0001: n2702_o = 3'b111;
      default: n2702_o = 3'b111;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2687_o)
      4'b1000: n2705_o = 1'b0;
      4'b0100: n2705_o = 1'b0;
      4'b0010: n2705_o = 1'b0;
      4'b0001: n2705_o = 1'b1;
      default: n2705_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2687_o)
      4'b1000: n2708_o = 1'b0;
      4'b0100: n2708_o = 1'b0;
      4'b0010: n2708_o = 1'b1;
      4'b0001: n2708_o = 1'b0;
      default: n2708_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2687_o)
      4'b1000: n2712_o = 1'b1;
      4'b0100: n2712_o = 1'b1;
      4'b0010: n2712_o = 1'b0;
      4'b0001: n2712_o = 1'b0;
      default: n2712_o = 1'b0;
    endcase
  /* T80_MCode.vhd:486:17  */
  assign n2714_o = ir == 8'b00100010;
  /* T80_MCode.vhd:521:17  */
  assign n2716_o = ir == 8'b11111001;
  /* T80_MCode.vhd:528:30  */
  assign n2717_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:533:42  */
  assign n2719_o = n2195_o == 2'b11;
  assign n2722_o = {1'b0, n2195_o, 1'b0};
  /* T80_MCode.vhd:533:33  */
  assign n2724_o = n2719_o ? 4'b0111 : n2722_o;
  /* T80_MCode.vhd:529:25  */
  assign n2726_o = n2717_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:543:42  */
  assign n2728_o = n2195_o == 2'b11;
  assign n2731_o = {1'b0, n2195_o, 1'b1};
  /* T80_MCode.vhd:543:33  */
  assign n2733_o = n2728_o ? 4'b1011 : n2731_o;
  /* T80_MCode.vhd:540:25  */
  assign n2735_o = n2717_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:551:25  */
  assign n2737_o = n2717_o == 31'b0000000000000000000000000000011;
  assign n2738_o = {n2737_o, n2735_o, n2726_o};
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2738_o)
      3'b100: n2740_o = n2200_o;
      3'b010: n2740_o = n2200_o;
      3'b001: n2740_o = 3'b101;
      default: n2740_o = n2200_o;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2738_o)
      3'b100: n2744_o = 4'b0000;
      3'b010: n2744_o = 4'b1111;
      3'b001: n2744_o = 4'b1111;
      default: n2744_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2738_o)
      3'b100: n2746_o = 4'b0000;
      3'b010: n2746_o = n2733_o;
      3'b001: n2746_o = n2724_o;
      default: n2746_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2738_o)
      3'b100: n2750_o = 3'b111;
      3'b010: n2750_o = 3'b101;
      3'b001: n2750_o = 3'b101;
      default: n2750_o = 3'b111;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2738_o)
      3'b100: n2754_o = 1'b1;
      3'b010: n2754_o = 1'b1;
      3'b001: n2754_o = 1'b0;
      default: n2754_o = 1'b0;
    endcase
  /* T80_MCode.vhd:525:17  */
  assign n2756_o = ir == 8'b11000101;
  /* T80_MCode.vhd:525:32  */
  assign n2758_o = ir == 8'b11010101;
  /* T80_MCode.vhd:525:32  */
  assign n2759_o = n2756_o | n2758_o;
  /* T80_MCode.vhd:525:43  */
  assign n2761_o = ir == 8'b11100101;
  /* T80_MCode.vhd:525:43  */
  assign n2762_o = n2759_o | n2761_o;
  /* T80_MCode.vhd:525:54  */
  assign n2764_o = ir == 8'b11110101;
  /* T80_MCode.vhd:525:54  */
  assign n2765_o = n2762_o | n2764_o;
  /* T80_MCode.vhd:558:30  */
  assign n2766_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:559:25  */
  assign n2768_o = n2766_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:565:42  */
  assign n2770_o = n2195_o == 2'b11;
  assign n2772_o = {n2195_o, 1'b1};
  /* T80_MCode.vhd:565:33  */
  assign n2774_o = n2770_o ? 3'b011 : n2772_o;
  /* T80_MCode.vhd:565:33  */
  assign n2777_o = n2770_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:561:25  */
  assign n2779_o = n2766_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:574:42  */
  assign n2781_o = n2195_o == 2'b11;
  assign n2783_o = {n2195_o, 1'b0};
  /* T80_MCode.vhd:574:33  */
  assign n2785_o = n2781_o ? 3'b111 : n2783_o;
  /* T80_MCode.vhd:574:33  */
  assign n2788_o = n2781_o ? 1'b0 : 1'b0;
  /* T80_MCode.vhd:571:25  */
  assign n2790_o = n2766_o == 31'b0000000000000000000000000000011;
  assign n2791_o = {n2790_o, n2779_o, n2768_o};
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2791_o)
      3'b100: n2795_o = 4'b0111;
      3'b010: n2795_o = 4'b0111;
      3'b001: n2795_o = 4'b0000;
      default: n2795_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2791_o)
      3'b100: n2799_o = 1'b1;
      3'b010: n2799_o = 1'b1;
      3'b001: n2799_o = 1'b0;
      default: n2799_o = 1'b0;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2791_o)
      3'b100: n2801_o = n2785_o;
      3'b010: n2801_o = n2774_o;
      3'b001: n2801_o = 3'b000;
      default: n2801_o = 3'b000;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2791_o)
      3'b100: n2803_o = n2788_o;
      3'b010: n2803_o = n2777_o;
      3'b001: n2803_o = 1'b0;
      default: n2803_o = 1'b0;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2791_o)
      3'b100: n2807_o = 3'b111;
      3'b010: n2807_o = 3'b101;
      3'b001: n2807_o = 3'b101;
      default: n2807_o = 3'b111;
    endcase
  /* T80_MCode.vhd:555:17  */
  assign n2809_o = ir == 8'b11000001;
  /* T80_MCode.vhd:555:32  */
  assign n2811_o = ir == 8'b11010001;
  /* T80_MCode.vhd:555:32  */
  assign n2812_o = n2809_o | n2811_o;
  /* T80_MCode.vhd:555:43  */
  assign n2814_o = ir == 8'b11100001;
  /* T80_MCode.vhd:555:43  */
  assign n2815_o = n2812_o | n2814_o;
  /* T80_MCode.vhd:555:54  */
  assign n2817_o = ir == 8'b11110001;
  /* T80_MCode.vhd:555:54  */
  assign n2818_o = n2815_o | n2817_o;
  /* T80_MCode.vhd:584:17  */
  assign n2820_o = ir == 8'b11101011;
  /* T80_MCode.vhd:589:17  */
  assign n2822_o = ir == 8'b00001000;
  /* T80_MCode.vhd:615:17  */
  assign n2824_o = ir == 8'b11011001;
  /* T80_MCode.vhd:641:38  */
  assign n2825_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:642:33  */
  assign n2827_o = n2825_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:644:33  */
  assign n2829_o = n2825_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:650:33  */
  assign n2831_o = n2825_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:655:33  */
  assign n2833_o = n2825_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:661:33  */
  assign n2835_o = n2825_o == 31'b0000000000000000000000000000101;
  assign n2836_o = {n2835_o, n2833_o, n2831_o, n2829_o, n2827_o};
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2836_o)
      5'b10000: n2839_o = 3'b101;
      5'b01000: n2839_o = n2200_o;
      5'b00100: n2839_o = 3'b100;
      5'b00010: n2839_o = n2200_o;
      5'b00001: n2839_o = n2200_o;
      default: n2839_o = n2200_o;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2836_o)
      5'b10000: n2843_o = 4'b1111;
      5'b01000: n2843_o = 4'b0000;
      5'b00100: n2843_o = 4'b0111;
      5'b00010: n2843_o = 4'b0000;
      5'b00001: n2843_o = 4'b0000;
      default: n2843_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2836_o)
      5'b10000: n2847_o = 1'b0;
      5'b01000: n2847_o = 1'b1;
      5'b00100: n2847_o = 1'b0;
      5'b00010: n2847_o = 1'b1;
      5'b00001: n2847_o = 1'b0;
      default: n2847_o = 1'b0;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2836_o)
      5'b10000: n2851_o = 4'b0000;
      5'b01000: n2851_o = 4'b0100;
      5'b00100: n2851_o = 4'b0000;
      5'b00010: n2851_o = 4'b0101;
      5'b00001: n2851_o = 4'b0000;
      default: n2851_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2836_o)
      5'b10000: n2855_o = 4'b0000;
      5'b01000: n2855_o = 4'b0100;
      5'b00100: n2855_o = 4'b0000;
      5'b00010: n2855_o = 4'b0101;
      5'b00001: n2855_o = 4'b0000;
      default: n2855_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2836_o)
      5'b10000: n2861_o = 3'b111;
      5'b01000: n2861_o = 3'b101;
      5'b00100: n2861_o = 3'b101;
      5'b00010: n2861_o = 3'b101;
      5'b00001: n2861_o = 3'b101;
      default: n2861_o = 3'b111;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2836_o)
      5'b10000: n2864_o = 1'b0;
      5'b01000: n2864_o = 1'b0;
      5'b00100: n2864_o = 1'b0;
      5'b00010: n2864_o = 1'b1;
      5'b00001: n2864_o = 1'b0;
      default: n2864_o = 1'b0;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2836_o)
      5'b10000: n2867_o = 1'b0;
      5'b01000: n2867_o = 1'b1;
      5'b00100: n2867_o = 1'b0;
      5'b00010: n2867_o = 1'b0;
      5'b00001: n2867_o = 1'b0;
      default: n2867_o = 1'b0;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2836_o)
      5'b10000: n2871_o = 1'b1;
      5'b01000: n2871_o = 1'b0;
      5'b00100: n2871_o = 1'b1;
      5'b00010: n2871_o = 1'b0;
      5'b00001: n2871_o = 1'b0;
      default: n2871_o = 1'b0;
    endcase
  /* T80_MCode.vhd:637:17  */
  assign n2873_o = ir == 8'b11100011;
  /* T80_MCode.vhd:670:17  */
  assign n2876_o = ir == 8'b10000000;
  /* T80_MCode.vhd:670:32  */
  assign n2878_o = ir == 8'b10000001;
  /* T80_MCode.vhd:670:32  */
  assign n2879_o = n2876_o | n2878_o;
  /* T80_MCode.vhd:670:43  */
  assign n2881_o = ir == 8'b10000010;
  /* T80_MCode.vhd:670:43  */
  assign n2882_o = n2879_o | n2881_o;
  /* T80_MCode.vhd:670:54  */
  assign n2884_o = ir == 8'b10000011;
  /* T80_MCode.vhd:670:54  */
  assign n2885_o = n2882_o | n2884_o;
  /* T80_MCode.vhd:670:65  */
  assign n2887_o = ir == 8'b10000100;
  /* T80_MCode.vhd:670:65  */
  assign n2888_o = n2885_o | n2887_o;
  /* T80_MCode.vhd:670:76  */
  assign n2890_o = ir == 8'b10000101;
  /* T80_MCode.vhd:670:76  */
  assign n2891_o = n2888_o | n2890_o;
  /* T80_MCode.vhd:670:87  */
  assign n2893_o = ir == 8'b10000111;
  /* T80_MCode.vhd:670:87  */
  assign n2894_o = n2891_o | n2893_o;
  /* T80_MCode.vhd:671:25  */
  assign n2896_o = ir == 8'b10001000;
  /* T80_MCode.vhd:671:25  */
  assign n2897_o = n2894_o | n2896_o;
  /* T80_MCode.vhd:671:36  */
  assign n2899_o = ir == 8'b10001001;
  /* T80_MCode.vhd:671:36  */
  assign n2900_o = n2897_o | n2899_o;
  /* T80_MCode.vhd:671:47  */
  assign n2902_o = ir == 8'b10001010;
  /* T80_MCode.vhd:671:47  */
  assign n2903_o = n2900_o | n2902_o;
  /* T80_MCode.vhd:671:58  */
  assign n2905_o = ir == 8'b10001011;
  /* T80_MCode.vhd:671:58  */
  assign n2906_o = n2903_o | n2905_o;
  /* T80_MCode.vhd:671:69  */
  assign n2908_o = ir == 8'b10001100;
  /* T80_MCode.vhd:671:69  */
  assign n2909_o = n2906_o | n2908_o;
  /* T80_MCode.vhd:671:80  */
  assign n2911_o = ir == 8'b10001101;
  /* T80_MCode.vhd:671:80  */
  assign n2912_o = n2909_o | n2911_o;
  /* T80_MCode.vhd:671:91  */
  assign n2914_o = ir == 8'b10001111;
  /* T80_MCode.vhd:671:91  */
  assign n2915_o = n2912_o | n2914_o;
  /* T80_MCode.vhd:672:25  */
  assign n2917_o = ir == 8'b10010000;
  /* T80_MCode.vhd:672:25  */
  assign n2918_o = n2915_o | n2917_o;
  /* T80_MCode.vhd:672:36  */
  assign n2920_o = ir == 8'b10010001;
  /* T80_MCode.vhd:672:36  */
  assign n2921_o = n2918_o | n2920_o;
  /* T80_MCode.vhd:672:47  */
  assign n2923_o = ir == 8'b10010010;
  /* T80_MCode.vhd:672:47  */
  assign n2924_o = n2921_o | n2923_o;
  /* T80_MCode.vhd:672:58  */
  assign n2926_o = ir == 8'b10010011;
  /* T80_MCode.vhd:672:58  */
  assign n2927_o = n2924_o | n2926_o;
  /* T80_MCode.vhd:672:69  */
  assign n2929_o = ir == 8'b10010100;
  /* T80_MCode.vhd:672:69  */
  assign n2930_o = n2927_o | n2929_o;
  /* T80_MCode.vhd:672:80  */
  assign n2932_o = ir == 8'b10010101;
  /* T80_MCode.vhd:672:80  */
  assign n2933_o = n2930_o | n2932_o;
  /* T80_MCode.vhd:672:91  */
  assign n2935_o = ir == 8'b10010111;
  /* T80_MCode.vhd:672:91  */
  assign n2936_o = n2933_o | n2935_o;
  /* T80_MCode.vhd:673:25  */
  assign n2938_o = ir == 8'b10011000;
  /* T80_MCode.vhd:673:25  */
  assign n2939_o = n2936_o | n2938_o;
  /* T80_MCode.vhd:673:36  */
  assign n2941_o = ir == 8'b10011001;
  /* T80_MCode.vhd:673:36  */
  assign n2942_o = n2939_o | n2941_o;
  /* T80_MCode.vhd:673:47  */
  assign n2944_o = ir == 8'b10011010;
  /* T80_MCode.vhd:673:47  */
  assign n2945_o = n2942_o | n2944_o;
  /* T80_MCode.vhd:673:58  */
  assign n2947_o = ir == 8'b10011011;
  /* T80_MCode.vhd:673:58  */
  assign n2948_o = n2945_o | n2947_o;
  /* T80_MCode.vhd:673:69  */
  assign n2950_o = ir == 8'b10011100;
  /* T80_MCode.vhd:673:69  */
  assign n2951_o = n2948_o | n2950_o;
  /* T80_MCode.vhd:673:80  */
  assign n2953_o = ir == 8'b10011101;
  /* T80_MCode.vhd:673:80  */
  assign n2954_o = n2951_o | n2953_o;
  /* T80_MCode.vhd:673:91  */
  assign n2956_o = ir == 8'b10011111;
  /* T80_MCode.vhd:673:91  */
  assign n2957_o = n2954_o | n2956_o;
  /* T80_MCode.vhd:674:25  */
  assign n2959_o = ir == 8'b10100000;
  /* T80_MCode.vhd:674:25  */
  assign n2960_o = n2957_o | n2959_o;
  /* T80_MCode.vhd:674:36  */
  assign n2962_o = ir == 8'b10100001;
  /* T80_MCode.vhd:674:36  */
  assign n2963_o = n2960_o | n2962_o;
  /* T80_MCode.vhd:674:47  */
  assign n2965_o = ir == 8'b10100010;
  /* T80_MCode.vhd:674:47  */
  assign n2966_o = n2963_o | n2965_o;
  /* T80_MCode.vhd:674:58  */
  assign n2968_o = ir == 8'b10100011;
  /* T80_MCode.vhd:674:58  */
  assign n2969_o = n2966_o | n2968_o;
  /* T80_MCode.vhd:674:69  */
  assign n2971_o = ir == 8'b10100100;
  /* T80_MCode.vhd:674:69  */
  assign n2972_o = n2969_o | n2971_o;
  /* T80_MCode.vhd:674:80  */
  assign n2974_o = ir == 8'b10100101;
  /* T80_MCode.vhd:674:80  */
  assign n2975_o = n2972_o | n2974_o;
  /* T80_MCode.vhd:674:91  */
  assign n2977_o = ir == 8'b10100111;
  /* T80_MCode.vhd:674:91  */
  assign n2978_o = n2975_o | n2977_o;
  /* T80_MCode.vhd:675:25  */
  assign n2980_o = ir == 8'b10101000;
  /* T80_MCode.vhd:675:25  */
  assign n2981_o = n2978_o | n2980_o;
  /* T80_MCode.vhd:675:36  */
  assign n2983_o = ir == 8'b10101001;
  /* T80_MCode.vhd:675:36  */
  assign n2984_o = n2981_o | n2983_o;
  /* T80_MCode.vhd:675:47  */
  assign n2986_o = ir == 8'b10101010;
  /* T80_MCode.vhd:675:47  */
  assign n2987_o = n2984_o | n2986_o;
  /* T80_MCode.vhd:675:58  */
  assign n2989_o = ir == 8'b10101011;
  /* T80_MCode.vhd:675:58  */
  assign n2990_o = n2987_o | n2989_o;
  /* T80_MCode.vhd:675:69  */
  assign n2992_o = ir == 8'b10101100;
  /* T80_MCode.vhd:675:69  */
  assign n2993_o = n2990_o | n2992_o;
  /* T80_MCode.vhd:675:80  */
  assign n2995_o = ir == 8'b10101101;
  /* T80_MCode.vhd:675:80  */
  assign n2996_o = n2993_o | n2995_o;
  /* T80_MCode.vhd:675:91  */
  assign n2998_o = ir == 8'b10101111;
  /* T80_MCode.vhd:675:91  */
  assign n2999_o = n2996_o | n2998_o;
  /* T80_MCode.vhd:676:25  */
  assign n3001_o = ir == 8'b10110000;
  /* T80_MCode.vhd:676:25  */
  assign n3002_o = n2999_o | n3001_o;
  /* T80_MCode.vhd:676:36  */
  assign n3004_o = ir == 8'b10110001;
  /* T80_MCode.vhd:676:36  */
  assign n3005_o = n3002_o | n3004_o;
  /* T80_MCode.vhd:676:47  */
  assign n3007_o = ir == 8'b10110010;
  /* T80_MCode.vhd:676:47  */
  assign n3008_o = n3005_o | n3007_o;
  /* T80_MCode.vhd:676:58  */
  assign n3010_o = ir == 8'b10110011;
  /* T80_MCode.vhd:676:58  */
  assign n3011_o = n3008_o | n3010_o;
  /* T80_MCode.vhd:676:69  */
  assign n3013_o = ir == 8'b10110100;
  /* T80_MCode.vhd:676:69  */
  assign n3014_o = n3011_o | n3013_o;
  /* T80_MCode.vhd:676:80  */
  assign n3016_o = ir == 8'b10110101;
  /* T80_MCode.vhd:676:80  */
  assign n3017_o = n3014_o | n3016_o;
  /* T80_MCode.vhd:676:91  */
  assign n3019_o = ir == 8'b10110111;
  /* T80_MCode.vhd:676:91  */
  assign n3020_o = n3017_o | n3019_o;
  /* T80_MCode.vhd:677:25  */
  assign n3022_o = ir == 8'b10111000;
  /* T80_MCode.vhd:677:25  */
  assign n3023_o = n3020_o | n3022_o;
  /* T80_MCode.vhd:677:36  */
  assign n3025_o = ir == 8'b10111001;
  /* T80_MCode.vhd:677:36  */
  assign n3026_o = n3023_o | n3025_o;
  /* T80_MCode.vhd:677:47  */
  assign n3028_o = ir == 8'b10111010;
  /* T80_MCode.vhd:677:47  */
  assign n3029_o = n3026_o | n3028_o;
  /* T80_MCode.vhd:677:58  */
  assign n3031_o = ir == 8'b10111011;
  /* T80_MCode.vhd:677:58  */
  assign n3032_o = n3029_o | n3031_o;
  /* T80_MCode.vhd:677:69  */
  assign n3034_o = ir == 8'b10111100;
  /* T80_MCode.vhd:677:69  */
  assign n3035_o = n3032_o | n3034_o;
  /* T80_MCode.vhd:677:80  */
  assign n3037_o = ir == 8'b10111101;
  /* T80_MCode.vhd:677:80  */
  assign n3038_o = n3035_o | n3037_o;
  /* T80_MCode.vhd:677:91  */
  assign n3040_o = ir == 8'b10111111;
  /* T80_MCode.vhd:677:91  */
  assign n3041_o = n3038_o | n3040_o;
  /* T80_MCode.vhd:700:30  */
  assign n3042_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:701:25  */
  assign n3044_o = n3042_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:703:25  */
  assign n3047_o = n3042_o == 31'b0000000000000000000000000000010;
  assign n3048_o = {n3047_o, n3044_o};
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3048_o)
      2'b10: n3051_o = 1'b1;
      2'b01: n3051_o = 1'b0;
      default: n3051_o = 1'b0;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3048_o)
      2'b10: n3053_o = 3'b111;
      2'b01: n3053_o = 3'b000;
      default: n3053_o = 3'b000;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3048_o)
      2'b10: n3055_o = n2194_o;
      2'b01: n3055_o = 3'b000;
      default: n3055_o = 3'b000;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3048_o)
      2'b10: n3058_o = 1'b1;
      2'b01: n3058_o = 1'b0;
      default: n3058_o = 1'b0;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3048_o)
      2'b10: n3061_o = 3'b111;
      2'b01: n3061_o = 3'b010;
      default: n3061_o = 3'b111;
    endcase
  /* T80_MCode.vhd:690:17  */
  assign n3063_o = ir == 8'b10000110;
  /* T80_MCode.vhd:690:32  */
  assign n3065_o = ir == 8'b10001110;
  /* T80_MCode.vhd:690:32  */
  assign n3066_o = n3063_o | n3065_o;
  /* T80_MCode.vhd:690:43  */
  assign n3068_o = ir == 8'b10010110;
  /* T80_MCode.vhd:690:43  */
  assign n3069_o = n3066_o | n3068_o;
  /* T80_MCode.vhd:690:54  */
  assign n3071_o = ir == 8'b10011110;
  /* T80_MCode.vhd:690:54  */
  assign n3072_o = n3069_o | n3071_o;
  /* T80_MCode.vhd:690:65  */
  assign n3074_o = ir == 8'b10100110;
  /* T80_MCode.vhd:690:65  */
  assign n3075_o = n3072_o | n3074_o;
  /* T80_MCode.vhd:690:76  */
  assign n3077_o = ir == 8'b10101110;
  /* T80_MCode.vhd:690:76  */
  assign n3078_o = n3075_o | n3077_o;
  /* T80_MCode.vhd:690:87  */
  assign n3080_o = ir == 8'b10110110;
  /* T80_MCode.vhd:690:87  */
  assign n3081_o = n3078_o | n3080_o;
  /* T80_MCode.vhd:690:98  */
  assign n3083_o = ir == 8'b10111110;
  /* T80_MCode.vhd:690:98  */
  assign n3084_o = n3081_o | n3083_o;
  /* T80_MCode.vhd:720:35  */
  assign n3086_o = mcycle == 3'b010;
  /* T80_MCode.vhd:720:25  */
  assign n3090_o = n3086_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:720:25  */
  assign n3093_o = n3086_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:720:25  */
  assign n3095_o = n3086_o ? 3'b111 : 3'b000;
  /* T80_MCode.vhd:720:25  */
  assign n3097_o = n3086_o ? n2194_o : 3'b000;
  /* T80_MCode.vhd:720:25  */
  assign n3100_o = n3086_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:710:17  */
  assign n3102_o = ir == 8'b11000110;
  /* T80_MCode.vhd:710:32  */
  assign n3104_o = ir == 8'b11001110;
  /* T80_MCode.vhd:710:32  */
  assign n3105_o = n3102_o | n3104_o;
  /* T80_MCode.vhd:710:43  */
  assign n3107_o = ir == 8'b11010110;
  /* T80_MCode.vhd:710:43  */
  assign n3108_o = n3105_o | n3107_o;
  /* T80_MCode.vhd:710:54  */
  assign n3110_o = ir == 8'b11011110;
  /* T80_MCode.vhd:710:54  */
  assign n3111_o = n3108_o | n3110_o;
  /* T80_MCode.vhd:710:65  */
  assign n3113_o = ir == 8'b11100110;
  /* T80_MCode.vhd:710:65  */
  assign n3114_o = n3111_o | n3113_o;
  /* T80_MCode.vhd:710:76  */
  assign n3116_o = ir == 8'b11101110;
  /* T80_MCode.vhd:710:76  */
  assign n3117_o = n3114_o | n3116_o;
  /* T80_MCode.vhd:710:87  */
  assign n3119_o = ir == 8'b11110110;
  /* T80_MCode.vhd:710:87  */
  assign n3120_o = n3117_o | n3119_o;
  /* T80_MCode.vhd:710:98  */
  assign n3122_o = ir == 8'b11111110;
  /* T80_MCode.vhd:710:98  */
  assign n3123_o = n3120_o | n3122_o;
  /* T80_MCode.vhd:727:17  */
  assign n3125_o = ir == 8'b00000100;
  /* T80_MCode.vhd:727:32  */
  assign n3127_o = ir == 8'b00001100;
  /* T80_MCode.vhd:727:32  */
  assign n3128_o = n3125_o | n3127_o;
  /* T80_MCode.vhd:727:43  */
  assign n3130_o = ir == 8'b00010100;
  /* T80_MCode.vhd:727:43  */
  assign n3131_o = n3128_o | n3130_o;
  /* T80_MCode.vhd:727:54  */
  assign n3133_o = ir == 8'b00011100;
  /* T80_MCode.vhd:727:54  */
  assign n3134_o = n3131_o | n3133_o;
  /* T80_MCode.vhd:727:65  */
  assign n3136_o = ir == 8'b00100100;
  /* T80_MCode.vhd:727:65  */
  assign n3137_o = n3134_o | n3136_o;
  /* T80_MCode.vhd:727:76  */
  assign n3139_o = ir == 8'b00101100;
  /* T80_MCode.vhd:727:76  */
  assign n3140_o = n3137_o | n3139_o;
  /* T80_MCode.vhd:727:87  */
  assign n3142_o = ir == 8'b00111100;
  /* T80_MCode.vhd:727:87  */
  assign n3143_o = n3140_o | n3142_o;
  /* T80_MCode.vhd:738:30  */
  assign n3144_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:739:25  */
  assign n3146_o = n3144_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:741:25  */
  assign n3148_o = n3144_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:750:25  */
  assign n3150_o = n3144_o == 31'b0000000000000000000000000000011;
  assign n3151_o = {n3150_o, n3148_o, n3146_o};
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3151_o)
      3'b100: n3153_o = n2200_o;
      3'b010: n3153_o = 3'b100;
      3'b001: n3153_o = n2200_o;
      default: n3153_o = n2200_o;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3151_o)
      3'b100: n3156_o = 1'b0;
      3'b010: n3156_o = 1'b1;
      3'b001: n3156_o = 1'b0;
      default: n3156_o = 1'b0;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3151_o)
      3'b100: n3158_o = 3'b000;
      3'b010: n3158_o = n2193_o;
      3'b001: n3158_o = 3'b000;
      default: n3158_o = 3'b000;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3151_o)
      3'b100: n3161_o = 4'b0000;
      3'b010: n3161_o = 4'b1010;
      3'b001: n3161_o = 4'b0000;
      default: n3161_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3151_o)
      3'b100: n3163_o = n2203_o;
      3'b010: n3163_o = 4'b0000;
      3'b001: n3163_o = n2203_o;
      default: n3163_o = n2203_o;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3151_o)
      3'b100: n3166_o = 1'b0;
      3'b010: n3166_o = 1'b1;
      3'b001: n3166_o = 1'b0;
      default: n3166_o = 1'b0;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3151_o)
      3'b100: n3169_o = 1'b0;
      3'b010: n3169_o = 1'b1;
      3'b001: n3169_o = 1'b0;
      default: n3169_o = 1'b0;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3151_o)
      3'b100: n3173_o = 3'b111;
      3'b010: n3173_o = 3'b010;
      3'b001: n3173_o = 3'b010;
      default: n3173_o = 3'b111;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3151_o)
      3'b100: n3176_o = 1'b1;
      3'b010: n3176_o = 1'b0;
      3'b001: n3176_o = 1'b0;
      default: n3176_o = 1'b0;
    endcase
  /* T80_MCode.vhd:735:17  */
  assign n3178_o = ir == 8'b00110100;
  /* T80_MCode.vhd:754:17  */
  assign n3180_o = ir == 8'b00000101;
  /* T80_MCode.vhd:754:32  */
  assign n3182_o = ir == 8'b00001101;
  /* T80_MCode.vhd:754:32  */
  assign n3183_o = n3180_o | n3182_o;
  /* T80_MCode.vhd:754:43  */
  assign n3185_o = ir == 8'b00010101;
  /* T80_MCode.vhd:754:43  */
  assign n3186_o = n3183_o | n3185_o;
  /* T80_MCode.vhd:754:54  */
  assign n3188_o = ir == 8'b00011101;
  /* T80_MCode.vhd:754:54  */
  assign n3189_o = n3186_o | n3188_o;
  /* T80_MCode.vhd:754:65  */
  assign n3191_o = ir == 8'b00100101;
  /* T80_MCode.vhd:754:65  */
  assign n3192_o = n3189_o | n3191_o;
  /* T80_MCode.vhd:754:76  */
  assign n3194_o = ir == 8'b00101101;
  /* T80_MCode.vhd:754:76  */
  assign n3195_o = n3192_o | n3194_o;
  /* T80_MCode.vhd:754:87  */
  assign n3197_o = ir == 8'b00111101;
  /* T80_MCode.vhd:754:87  */
  assign n3198_o = n3195_o | n3197_o;
  /* T80_MCode.vhd:765:30  */
  assign n3199_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:766:25  */
  assign n3201_o = n3199_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:768:25  */
  assign n3203_o = n3199_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:777:25  */
  assign n3205_o = n3199_o == 31'b0000000000000000000000000000011;
  assign n3206_o = {n3205_o, n3203_o, n3201_o};
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3206_o)
      3'b100: n3208_o = n2200_o;
      3'b010: n3208_o = 3'b100;
      3'b001: n3208_o = n2200_o;
      default: n3208_o = n2200_o;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3206_o)
      3'b100: n3211_o = 1'b0;
      3'b010: n3211_o = 1'b1;
      3'b001: n3211_o = 1'b0;
      default: n3211_o = 1'b0;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3206_o)
      3'b100: n3213_o = 3'b000;
      3'b010: n3213_o = n2193_o;
      3'b001: n3213_o = 3'b000;
      default: n3213_o = 3'b000;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3206_o)
      3'b100: n3216_o = 4'b0000;
      3'b010: n3216_o = 4'b1010;
      3'b001: n3216_o = 4'b0000;
      default: n3216_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3206_o)
      3'b100: n3218_o = n2203_o;
      3'b010: n3218_o = 4'b0010;
      3'b001: n3218_o = n2203_o;
      default: n3218_o = n2203_o;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3206_o)
      3'b100: n3221_o = 1'b0;
      3'b010: n3221_o = 1'b1;
      3'b001: n3221_o = 1'b0;
      default: n3221_o = 1'b0;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3206_o)
      3'b100: n3224_o = 1'b0;
      3'b010: n3224_o = 1'b1;
      3'b001: n3224_o = 1'b0;
      default: n3224_o = 1'b0;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3206_o)
      3'b100: n3228_o = 3'b111;
      3'b010: n3228_o = 3'b010;
      3'b001: n3228_o = 3'b010;
      default: n3228_o = 3'b111;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3206_o)
      3'b100: n3231_o = 1'b1;
      3'b010: n3231_o = 1'b0;
      3'b001: n3231_o = 1'b0;
      default: n3231_o = 1'b0;
    endcase
  /* T80_MCode.vhd:762:17  */
  assign n3233_o = ir == 8'b00110101;
  /* T80_MCode.vhd:783:17  */
  assign n3236_o = ir == 8'b00100111;
  /* T80_MCode.vhd:789:17  */
  assign n3238_o = ir == 8'b00101111;
  /* T80_MCode.vhd:792:17  */
  assign n3240_o = ir == 8'b00111111;
  /* T80_MCode.vhd:795:17  */
  assign n3242_o = ir == 8'b00110111;
  /* T80_MCode.vhd:802:38  */
  assign n3243_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:803:33  */
  assign n3245_o = n3243_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:808:33  */
  assign n3247_o = n3243_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:813:33  */
  assign n3249_o = n3243_o == 31'b0000000000000000000000000000011;
  assign n3250_o = {n3249_o, n3247_o, n3245_o};
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3250_o)
      3'b100: n3252_o = n2200_o;
      3'b010: n3252_o = n2200_o;
      3'b001: n3252_o = 3'b101;
      default: n3252_o = n2200_o;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3250_o)
      3'b100: n3256_o = 4'b0000;
      3'b010: n3256_o = 4'b1111;
      3'b001: n3256_o = 4'b1111;
      default: n3256_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3250_o)
      3'b100: n3260_o = 4'b0000;
      3'b010: n3260_o = 4'b1100;
      3'b001: n3260_o = 4'b1101;
      default: n3260_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3250_o)
      3'b100: n3264_o = 3'b111;
      3'b010: n3264_o = 3'b101;
      3'b001: n3264_o = 3'b101;
      default: n3264_o = 3'b111;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3250_o)
      3'b100: n3268_o = 1'b1;
      3'b010: n3268_o = 1'b1;
      3'b001: n3268_o = 1'b0;
      default: n3268_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:38  */
  assign n3269_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:821:33  */
  assign n3271_o = n3269_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:827:33  */
  assign n3273_o = n3269_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:833:33  */
  assign n3275_o = n3269_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:836:33  */
  assign n3277_o = n3269_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:839:33  */
  assign n3279_o = n3269_o == 31'b0000000000000000000000000000101;
  assign n3280_o = {n3279_o, n3277_o, n3275_o, n3273_o, n3271_o};
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3280_o)
      5'b10000: n3282_o = n2200_o;
      5'b01000: n3282_o = n2200_o;
      5'b00100: n3282_o = n2200_o;
      5'b00010: n3282_o = n2200_o;
      5'b00001: n3282_o = 3'b101;
      default: n3282_o = n2200_o;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3280_o)
      5'b10000: n3285_o = 1'b0;
      5'b01000: n3285_o = 1'b1;
      5'b00100: n3285_o = 1'b0;
      5'b00010: n3285_o = 1'b0;
      5'b00001: n3285_o = 1'b0;
      default: n3285_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3280_o)
      5'b10000: n3289_o = 4'b0000;
      5'b01000: n3289_o = 4'b0000;
      5'b00100: n3289_o = 4'b0000;
      5'b00010: n3289_o = 4'b1111;
      5'b00001: n3289_o = 4'b1111;
      default: n3289_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3280_o)
      5'b10000: n3293_o = 4'b0000;
      5'b01000: n3293_o = 4'b0000;
      5'b00100: n3293_o = 4'b0000;
      5'b00010: n3293_o = 4'b1100;
      5'b00001: n3293_o = 4'b1101;
      default: n3293_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3280_o)
      5'b10000: n3297_o = 3'b111;
      5'b01000: n3297_o = 3'b111;
      5'b00100: n3297_o = 3'b111;
      5'b00010: n3297_o = 3'b101;
      5'b00001: n3297_o = 3'b101;
      default: n3297_o = 3'b111;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3280_o)
      5'b10000: n3300_o = 1'b1;
      5'b01000: n3300_o = 1'b0;
      5'b00100: n3300_o = 1'b0;
      5'b00010: n3300_o = 1'b0;
      5'b00001: n3300_o = 1'b0;
      default: n3300_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3280_o)
      5'b10000: n3304_o = 1'b0;
      5'b01000: n3304_o = 1'b1;
      5'b00100: n3304_o = 1'b0;
      5'b00010: n3304_o = 1'b0;
      5'b00001: n3304_o = 1'b1;
      default: n3304_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3280_o)
      5'b10000: n3308_o = 1'b0;
      5'b01000: n3308_o = 1'b0;
      5'b00100: n3308_o = 1'b1;
      5'b00010: n3308_o = 1'b1;
      5'b00001: n3308_o = 1'b0;
      default: n3308_o = 1'b0;
    endcase
  /* T80_MCode.vhd:817:25  */
  assign n3311_o = intcycle ? 3'b101 : 3'b001;
  /* T80_MCode.vhd:817:25  */
  assign n3312_o = intcycle ? n3282_o : n2200_o;
  /* T80_MCode.vhd:817:25  */
  assign n3314_o = intcycle ? n3285_o : 1'b0;
  /* T80_MCode.vhd:817:25  */
  assign n3316_o = intcycle ? n3289_o : 4'b0000;
  /* T80_MCode.vhd:817:25  */
  assign n3318_o = intcycle ? n3293_o : 4'b0000;
  /* T80_MCode.vhd:817:25  */
  assign n3320_o = intcycle ? n3297_o : 3'b111;
  /* T80_MCode.vhd:817:25  */
  assign n3322_o = intcycle ? n3300_o : 1'b0;
  /* T80_MCode.vhd:817:25  */
  assign n3324_o = intcycle ? n3304_o : 1'b0;
  /* T80_MCode.vhd:817:25  */
  assign n3326_o = intcycle ? n3308_o : 1'b0;
  /* T80_MCode.vhd:799:25  */
  assign n3328_o = nmicycle ? 3'b011 : n3311_o;
  /* T80_MCode.vhd:799:25  */
  assign n3329_o = nmicycle ? n3252_o : n3312_o;
  /* T80_MCode.vhd:799:25  */
  assign n3331_o = nmicycle ? 1'b0 : n3314_o;
  /* T80_MCode.vhd:799:25  */
  assign n3332_o = nmicycle ? n3256_o : n3316_o;
  /* T80_MCode.vhd:799:25  */
  assign n3333_o = nmicycle ? n3260_o : n3318_o;
  /* T80_MCode.vhd:799:25  */
  assign n3334_o = nmicycle ? n3264_o : n3320_o;
  /* T80_MCode.vhd:799:25  */
  assign n3336_o = nmicycle ? 1'b0 : n3322_o;
  /* T80_MCode.vhd:799:25  */
  assign n3338_o = nmicycle ? 1'b0 : n3324_o;
  /* T80_MCode.vhd:799:25  */
  assign n3339_o = nmicycle ? n3268_o : n3326_o;
  /* T80_MCode.vhd:798:17  */
  assign n3341_o = ir == 8'b00000000;
  /* T80_MCode.vhd:846:17  */
  assign n3343_o = ir == 8'b01110110;
  /* T80_MCode.vhd:849:17  */
  assign n3345_o = ir == 8'b11110011;
  /* T80_MCode.vhd:852:17  */
  assign n3347_o = ir == 8'b11111011;
  /* T80_MCode.vhd:860:30  */
  assign n3348_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:867:60  */
  assign n3350_o = ir[5:4];
  /* T80_MCode.vhd:867:38  */
  assign n3351_o = {29'b0, n3350_o};  //  uext
  /* T80_MCode.vhd:869:70  */
  assign n3352_o = ir[5:4];
  /* T80_MCode.vhd:868:33  */
  assign n3355_o = n3351_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:868:39  */
  assign n3357_o = n3351_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:868:39  */
  assign n3358_o = n3355_o | n3357_o;
  /* T80_MCode.vhd:868:41  */
  assign n3360_o = n3351_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:868:41  */
  assign n3361_o = n3358_o | n3360_o;
  /* T80_MCode.vhd:867:33  */
  always @*
    case (n3361_o)
      1'b1: n3363_o = 1'b1;
      default: n3363_o = 1'b0;
    endcase
  /* T80_MCode.vhd:867:33  */
  always @*
    case (n3361_o)
      1'b1: n3365_o = n3352_o;
      default: n3365_o = 2'b00;
    endcase
  /* T80_MCode.vhd:867:33  */
  always @*
    case (n3361_o)
      1'b1: n3368_o = 1'b0;
      default: n3368_o = 1'b1;
    endcase
  /* T80_MCode.vhd:861:25  */
  assign n3370_o = n3348_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:883:60  */
  assign n3372_o = ir[5:4];
  /* T80_MCode.vhd:883:38  */
  assign n3373_o = {29'b0, n3372_o};  //  uext
  /* T80_MCode.vhd:885:70  */
  assign n3374_o = ir[5:4];
  /* T80_MCode.vhd:884:33  */
  assign n3376_o = n3373_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:884:39  */
  assign n3378_o = n3373_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:884:39  */
  assign n3379_o = n3376_o | n3378_o;
  /* T80_MCode.vhd:884:41  */
  assign n3381_o = n3373_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:884:41  */
  assign n3382_o = n3379_o | n3381_o;
  /* T80_MCode.vhd:883:33  */
  always @*
    case (n3382_o)
      1'b1: n3385_o = 1'b0;
      default: n3385_o = 1'b1;
    endcase
  /* T80_MCode.vhd:883:33  */
  always @*
    case (n3382_o)
      1'b1: n3387_o = n3374_o;
      default: n3387_o = 2'b00;
    endcase
  /* T80_MCode.vhd:883:33  */
  always @*
    case (n3382_o)
      1'b1: n3390_o = 1'b0;
      default: n3390_o = 1'b1;
    endcase
  /* T80_MCode.vhd:877:25  */
  assign n3392_o = n3348_o == 31'b0000000000000000000000000000011;
  assign n3393_o = {n3392_o, n3370_o};
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3395_o = n2200_o;
      2'b01: n3395_o = 3'b100;
      default: n3395_o = n2200_o;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3399_o = 1'b1;
      2'b01: n3399_o = 1'b1;
      default: n3399_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3401_o = 3'b100;
      2'b01: n3401_o = 3'b101;
      default: n3401_o = 3'b000;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3403_o = n3385_o;
      2'b01: n3403_o = n3363_o;
      default: n3403_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3405_o = n3387_o;
      2'b01: n3405_o = n3365_o;
      default: n3405_o = 2'b00;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3407_o = n3390_o;
      2'b01: n3407_o = n3368_o;
      default: n3407_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3410_o = 4'b0001;
      2'b01: n3410_o = 4'b0000;
      default: n3410_o = n2203_o;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3414_o = 1'b1;
      2'b01: n3414_o = 1'b1;
      default: n3414_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3418_o = 1'b1;
      2'b01: n3418_o = 1'b1;
      default: n3418_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3421_o = 2'b00;
      2'b01: n3421_o = 2'b11;
      default: n3421_o = 2'b00;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3393_o)
      2'b10: n3425_o = 1'b1;
      2'b01: n3425_o = 1'b1;
      default: n3425_o = 1'b0;
    endcase
  /* T80_MCode.vhd:857:17  */
  assign n3427_o = ir == 8'b00001001;
  /* T80_MCode.vhd:857:32  */
  assign n3429_o = ir == 8'b00011001;
  /* T80_MCode.vhd:857:32  */
  assign n3430_o = n3427_o | n3429_o;
  /* T80_MCode.vhd:857:43  */
  assign n3432_o = ir == 8'b00101001;
  /* T80_MCode.vhd:857:43  */
  assign n3433_o = n3430_o | n3432_o;
  /* T80_MCode.vhd:857:54  */
  assign n3435_o = ir == 8'b00111001;
  /* T80_MCode.vhd:857:54  */
  assign n3436_o = n3433_o | n3435_o;
  /* T80_MCode.vhd:892:17  */
  assign n3439_o = ir == 8'b00000011;
  /* T80_MCode.vhd:892:32  */
  assign n3441_o = ir == 8'b00010011;
  /* T80_MCode.vhd:892:32  */
  assign n3442_o = n3439_o | n3441_o;
  /* T80_MCode.vhd:892:43  */
  assign n3444_o = ir == 8'b00100011;
  /* T80_MCode.vhd:892:43  */
  assign n3445_o = n3442_o | n3444_o;
  /* T80_MCode.vhd:892:54  */
  assign n3447_o = ir == 8'b00110011;
  /* T80_MCode.vhd:892:54  */
  assign n3448_o = n3445_o | n3447_o;
  /* T80_MCode.vhd:897:17  */
  assign n3451_o = ir == 8'b00001011;
  /* T80_MCode.vhd:897:32  */
  assign n3453_o = ir == 8'b00011011;
  /* T80_MCode.vhd:897:32  */
  assign n3454_o = n3451_o | n3453_o;
  /* T80_MCode.vhd:897:43  */
  assign n3456_o = ir == 8'b00101011;
  /* T80_MCode.vhd:897:43  */
  assign n3457_o = n3454_o | n3456_o;
  /* T80_MCode.vhd:897:54  */
  assign n3459_o = ir == 8'b00111011;
  /* T80_MCode.vhd:897:54  */
  assign n3460_o = n3457_o | n3459_o;
  /* T80_MCode.vhd:904:17  */
  assign n3463_o = ir == 8'b00000111;
  /* T80_MCode.vhd:906:25  */
  assign n3465_o = ir == 8'b00010111;
  /* T80_MCode.vhd:906:25  */
  assign n3466_o = n3463_o | n3465_o;
  /* T80_MCode.vhd:908:25  */
  assign n3468_o = ir == 8'b00001111;
  /* T80_MCode.vhd:908:25  */
  assign n3469_o = n3466_o | n3468_o;
  /* T80_MCode.vhd:910:25  */
  assign n3471_o = ir == 8'b00011111;
  /* T80_MCode.vhd:910:25  */
  assign n3472_o = n3469_o | n3471_o;
  /* T80_MCode.vhd:921:30  */
  assign n3473_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:922:25  */
  assign n3475_o = n3473_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:925:25  */
  assign n3477_o = n3473_o == 31'b0000000000000000000000000000011;
  assign n3478_o = {n3477_o, n3475_o};
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3478_o)
      2'b10: n3482_o = 1'b1;
      2'b01: n3482_o = 1'b1;
      default: n3482_o = 1'b0;
    endcase
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3478_o)
      2'b10: n3485_o = 1'b1;
      2'b01: n3485_o = 1'b0;
      default: n3485_o = 1'b0;
    endcase
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3478_o)
      2'b10: n3488_o = 1'b0;
      2'b01: n3488_o = 1'b1;
      default: n3488_o = 1'b0;
    endcase
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3478_o)
      2'b10: n3491_o = 1'b1;
      2'b01: n3491_o = 1'b0;
      default: n3491_o = 1'b0;
    endcase
  /* T80_MCode.vhd:918:17  */
  assign n3493_o = ir == 8'b11000011;
  /* T80_MCode.vhd:990:38  */
  assign n3495_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:991:33  */
  assign n3497_o = n3495_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:997:73  */
  assign n3499_o = ir[5:3];
  /* T80_MCode.vhd:178:47  */
  assign n3504_o = f[6];
  /* T80_MCode.vhd:178:56  */
  assign n3505_o = ~n3504_o;
  /* T80_MCode.vhd:178:25  */
  assign n3507_o = n3499_o == 3'b000;
  /* T80_MCode.vhd:179:47  */
  assign n3508_o = f[6];
  /* T80_MCode.vhd:179:25  */
  assign n3510_o = n3499_o == 3'b001;
  /* T80_MCode.vhd:180:47  */
  assign n3511_o = f[0];
  /* T80_MCode.vhd:180:56  */
  assign n3512_o = ~n3511_o;
  /* T80_MCode.vhd:180:25  */
  assign n3514_o = n3499_o == 3'b010;
  /* T80_MCode.vhd:181:47  */
  assign n3515_o = f[0];
  /* T80_MCode.vhd:181:25  */
  assign n3517_o = n3499_o == 3'b011;
  /* T80_MCode.vhd:182:47  */
  assign n3518_o = f[2];
  /* T80_MCode.vhd:182:56  */
  assign n3519_o = ~n3518_o;
  /* T80_MCode.vhd:182:25  */
  assign n3521_o = n3499_o == 3'b100;
  /* T80_MCode.vhd:183:47  */
  assign n3522_o = f[2];
  /* T80_MCode.vhd:183:25  */
  assign n3524_o = n3499_o == 3'b101;
  /* T80_MCode.vhd:184:47  */
  assign n3525_o = f[7];
  /* T80_MCode.vhd:184:56  */
  assign n3526_o = ~n3525_o;
  /* T80_MCode.vhd:184:25  */
  assign n3528_o = n3499_o == 3'b110;
  /* T80_MCode.vhd:185:47  */
  assign n3529_o = f[7];
  /* T80_MCode.vhd:185:25  */
  assign n3531_o = n3499_o == 3'b111;
  assign n3532_o = {n3531_o, n3528_o, n3524_o, n3521_o, n3517_o, n3514_o, n3510_o, n3507_o};
  /* T80_MCode.vhd:177:25  */
  always @*
    case (n3532_o)
      8'b10000000: n3534_o = n3529_o;
      8'b01000000: n3534_o = n3526_o;
      8'b00100000: n3534_o = n3522_o;
      8'b00010000: n3534_o = n3519_o;
      8'b00001000: n3534_o = n3515_o;
      8'b00000100: n3534_o = n3512_o;
      8'b00000010: n3534_o = n3508_o;
      8'b00000001: n3534_o = n3505_o;
      default: n3534_o = 1'bX;
    endcase
  /* T80_MCode.vhd:997:41  */
  assign n3537_o = n3534_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:994:33  */
  assign n3539_o = n3495_o == 31'b0000000000000000000000000000011;
  assign n3540_o = {n3539_o, n3497_o};
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3540_o)
      2'b10: n3544_o = 1'b1;
      2'b01: n3544_o = 1'b1;
      default: n3544_o = 1'b0;
    endcase
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3540_o)
      2'b10: n3546_o = n3537_o;
      2'b01: n3546_o = 1'b0;
      default: n3546_o = 1'b0;
    endcase
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3540_o)
      2'b10: n3549_o = 1'b0;
      2'b01: n3549_o = 1'b1;
      default: n3549_o = 1'b0;
    endcase
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3540_o)
      2'b10: n3552_o = 1'b1;
      2'b01: n3552_o = 1'b0;
      default: n3552_o = 1'b0;
    endcase
  /* T80_MCode.vhd:931:17  */
  assign n3554_o = ir == 8'b11000010;
  /* T80_MCode.vhd:931:32  */
  assign n3556_o = ir == 8'b11001010;
  /* T80_MCode.vhd:931:32  */
  assign n3557_o = n3554_o | n3556_o;
  /* T80_MCode.vhd:931:43  */
  assign n3559_o = ir == 8'b11010010;
  /* T80_MCode.vhd:931:43  */
  assign n3560_o = n3557_o | n3559_o;
  /* T80_MCode.vhd:931:54  */
  assign n3562_o = ir == 8'b11011010;
  /* T80_MCode.vhd:931:54  */
  assign n3563_o = n3560_o | n3562_o;
  /* T80_MCode.vhd:931:65  */
  assign n3565_o = ir == 8'b11100010;
  /* T80_MCode.vhd:931:65  */
  assign n3566_o = n3563_o | n3565_o;
  /* T80_MCode.vhd:931:76  */
  assign n3568_o = ir == 8'b11101010;
  /* T80_MCode.vhd:931:76  */
  assign n3569_o = n3566_o | n3568_o;
  /* T80_MCode.vhd:931:87  */
  assign n3571_o = ir == 8'b11110010;
  /* T80_MCode.vhd:931:87  */
  assign n3572_o = n3569_o | n3571_o;
  /* T80_MCode.vhd:931:98  */
  assign n3574_o = ir == 8'b11111010;
  /* T80_MCode.vhd:931:98  */
  assign n3575_o = n3572_o | n3574_o;
  /* T80_MCode.vhd:1007:38  */
  assign n3576_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1008:33  */
  assign n3578_o = n3576_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1010:33  */
  assign n3580_o = n3576_o == 31'b0000000000000000000000000000011;
  assign n3581_o = {n3580_o, n3578_o};
  /* T80_MCode.vhd:1007:33  */
  always @*
    case (n3581_o)
      2'b10: n3583_o = 3'b101;
      2'b01: n3583_o = n2200_o;
      default: n3583_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1007:33  */
  always @*
    case (n3581_o)
      2'b10: n3586_o = 1'b0;
      2'b01: n3586_o = 1'b1;
      default: n3586_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1007:33  */
  always @*
    case (n3581_o)
      2'b10: n3589_o = 1'b1;
      2'b01: n3589_o = 1'b0;
      default: n3589_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1007:33  */
  always @*
    case (n3581_o)
      2'b10: n3592_o = 1'b1;
      2'b01: n3592_o = 1'b0;
      default: n3592_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1003:17  */
  assign n3594_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1021:38  */
  assign n3595_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1024:45  */
  assign n3596_o = f[0];
  /* T80_MCode.vhd:1024:54  */
  assign n3597_o = ~n3596_o;
  /* T80_MCode.vhd:1024:41  */
  assign n3600_o = n3597_o ? 3'b010 : 3'b011;
  /* T80_MCode.vhd:1022:33  */
  assign n3602_o = n3595_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1027:33  */
  assign n3604_o = n3595_o == 31'b0000000000000000000000000000011;
  assign n3605_o = {n3604_o, n3602_o};
  /* T80_MCode.vhd:1021:33  */
  always @*
    case (n3605_o)
      2'b10: n3607_o = 3'b011;
      2'b01: n3607_o = n3600_o;
      default: n3607_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1021:33  */
  always @*
    case (n3605_o)
      2'b10: n3610_o = 3'b101;
      2'b01: n3610_o = n2200_o;
      default: n3610_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1021:33  */
  always @*
    case (n3605_o)
      2'b10: n3613_o = 1'b0;
      2'b01: n3613_o = 1'b1;
      default: n3613_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1021:33  */
  always @*
    case (n3605_o)
      2'b10: n3616_o = 1'b1;
      2'b01: n3616_o = 1'b0;
      default: n3616_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1021:33  */
  always @*
    case (n3605_o)
      2'b10: n3619_o = 1'b1;
      2'b01: n3619_o = 1'b0;
      default: n3619_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1017:17  */
  assign n3621_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1038:38  */
  assign n3622_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1041:45  */
  assign n3623_o = f[0];
  /* T80_MCode.vhd:1041:41  */
  assign n3626_o = n3623_o ? 3'b010 : 3'b011;
  /* T80_MCode.vhd:1039:33  */
  assign n3628_o = n3622_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1044:33  */
  assign n3630_o = n3622_o == 31'b0000000000000000000000000000011;
  assign n3631_o = {n3630_o, n3628_o};
  /* T80_MCode.vhd:1038:33  */
  always @*
    case (n3631_o)
      2'b10: n3633_o = 3'b011;
      2'b01: n3633_o = n3626_o;
      default: n3633_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1038:33  */
  always @*
    case (n3631_o)
      2'b10: n3636_o = 3'b101;
      2'b01: n3636_o = n2200_o;
      default: n3636_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1038:33  */
  always @*
    case (n3631_o)
      2'b10: n3639_o = 1'b0;
      2'b01: n3639_o = 1'b1;
      default: n3639_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1038:33  */
  always @*
    case (n3631_o)
      2'b10: n3642_o = 1'b1;
      2'b01: n3642_o = 1'b0;
      default: n3642_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1038:33  */
  always @*
    case (n3631_o)
      2'b10: n3645_o = 1'b1;
      2'b01: n3645_o = 1'b0;
      default: n3645_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1034:17  */
  assign n3647_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1055:38  */
  assign n3648_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1058:45  */
  assign n3649_o = f[6];
  /* T80_MCode.vhd:1058:54  */
  assign n3650_o = ~n3649_o;
  /* T80_MCode.vhd:1058:41  */
  assign n3653_o = n3650_o ? 3'b010 : 3'b011;
  /* T80_MCode.vhd:1056:33  */
  assign n3655_o = n3648_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1061:33  */
  assign n3657_o = n3648_o == 31'b0000000000000000000000000000011;
  assign n3658_o = {n3657_o, n3655_o};
  /* T80_MCode.vhd:1055:33  */
  always @*
    case (n3658_o)
      2'b10: n3660_o = 3'b011;
      2'b01: n3660_o = n3653_o;
      default: n3660_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1055:33  */
  always @*
    case (n3658_o)
      2'b10: n3663_o = 3'b101;
      2'b01: n3663_o = n2200_o;
      default: n3663_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1055:33  */
  always @*
    case (n3658_o)
      2'b10: n3666_o = 1'b0;
      2'b01: n3666_o = 1'b1;
      default: n3666_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1055:33  */
  always @*
    case (n3658_o)
      2'b10: n3669_o = 1'b1;
      2'b01: n3669_o = 1'b0;
      default: n3669_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1055:33  */
  always @*
    case (n3658_o)
      2'b10: n3672_o = 1'b1;
      2'b01: n3672_o = 1'b0;
      default: n3672_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1051:17  */
  assign n3674_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1072:38  */
  assign n3675_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1075:45  */
  assign n3676_o = f[6];
  /* T80_MCode.vhd:1075:41  */
  assign n3679_o = n3676_o ? 3'b010 : 3'b011;
  /* T80_MCode.vhd:1073:33  */
  assign n3681_o = n3675_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1078:33  */
  assign n3683_o = n3675_o == 31'b0000000000000000000000000000011;
  assign n3684_o = {n3683_o, n3681_o};
  /* T80_MCode.vhd:1072:33  */
  always @*
    case (n3684_o)
      2'b10: n3686_o = 3'b011;
      2'b01: n3686_o = n3679_o;
      default: n3686_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1072:33  */
  always @*
    case (n3684_o)
      2'b10: n3689_o = 3'b101;
      2'b01: n3689_o = n2200_o;
      default: n3689_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1072:33  */
  always @*
    case (n3684_o)
      2'b10: n3692_o = 1'b0;
      2'b01: n3692_o = 1'b1;
      default: n3692_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1072:33  */
  always @*
    case (n3684_o)
      2'b10: n3695_o = 1'b1;
      2'b01: n3695_o = 1'b0;
      default: n3695_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1072:33  */
  always @*
    case (n3684_o)
      2'b10: n3698_o = 1'b1;
      2'b01: n3698_o = 1'b0;
      default: n3698_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1068:17  */
  assign n3700_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1085:17  */
  assign n3702_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1094:38  */
  assign n3703_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1095:33  */
  assign n3706_o = n3703_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1103:33  */
  assign n3708_o = n3703_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1106:33  */
  assign n3710_o = n3703_o == 31'b0000000000000000000000000000011;
  assign n3711_o = {n3710_o, n3708_o, n3706_o};
  /* T80_MCode.vhd:1094:33  */
  always @*
    case (n3711_o)
      3'b100: n3714_o = 3'b101;
      3'b010: n3714_o = n2200_o;
      3'b001: n3714_o = 3'b101;
      default: n3714_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1094:33  */
  always @*
    case (n3711_o)
      3'b100: n3717_o = 1'b0;
      3'b010: n3717_o = 1'b1;
      3'b001: n3717_o = 1'b0;
      default: n3717_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1094:33  */
  always @*
    case (n3711_o)
      3'b100: n3720_o = 1'b0;
      3'b010: n3720_o = 1'b0;
      3'b001: n3720_o = 1'b1;
      default: n3720_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1094:33  */
  always @*
    case (n3711_o)
      3'b100: n3722_o = 3'b000;
      3'b010: n3722_o = 3'b000;
      3'b001: n3722_o = 3'b000;
      default: n3722_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1094:33  */
  always @*
    case (n3711_o)
      3'b100: n3725_o = 4'b0000;
      3'b010: n3725_o = 4'b0000;
      3'b001: n3725_o = 4'b1010;
      default: n3725_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1094:33  */
  always @*
    case (n3711_o)
      3'b100: n3727_o = n2203_o;
      3'b010: n3727_o = n2203_o;
      3'b001: n3727_o = 4'b0010;
      default: n3727_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1094:33  */
  always @*
    case (n3711_o)
      3'b100: n3730_o = 1'b0;
      3'b010: n3730_o = 1'b0;
      3'b001: n3730_o = 1'b1;
      default: n3730_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1094:33  */
  always @*
    case (n3711_o)
      3'b100: n3733_o = 1'b1;
      3'b010: n3733_o = 1'b0;
      3'b001: n3733_o = 1'b0;
      default: n3733_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1094:33  */
  always @*
    case (n3711_o)
      3'b100: n3737_o = 1'b0;
      3'b010: n3737_o = 1'b1;
      3'b001: n3737_o = 1'b1;
      default: n3737_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1094:33  */
  always @*
    case (n3711_o)
      3'b100: n3740_o = 1'b1;
      3'b010: n3740_o = 1'b0;
      3'b001: n3740_o = 1'b0;
      default: n3740_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1088:17  */
  assign n3742_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1118:30  */
  assign n3743_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1119:25  */
  assign n3745_o = n3743_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1122:25  */
  assign n3747_o = n3743_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1129:25  */
  assign n3749_o = n3743_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1134:25  */
  assign n3751_o = n3743_o == 31'b0000000000000000000000000000101;
  assign n3752_o = {n3751_o, n3749_o, n3747_o, n3745_o};
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3752_o)
      4'b1000: n3754_o = n2200_o;
      4'b0100: n3754_o = n2200_o;
      4'b0010: n3754_o = 3'b100;
      4'b0001: n3754_o = n2200_o;
      default: n3754_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3752_o)
      4'b1000: n3758_o = 1'b0;
      4'b0100: n3758_o = 1'b0;
      4'b0010: n3758_o = 1'b1;
      4'b0001: n3758_o = 1'b1;
      default: n3758_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3752_o)
      4'b1000: n3762_o = 4'b0000;
      4'b0100: n3762_o = 4'b1111;
      4'b0010: n3762_o = 4'b1111;
      4'b0001: n3762_o = 4'b0000;
      default: n3762_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3752_o)
      4'b1000: n3766_o = 4'b0000;
      4'b0100: n3766_o = 4'b1100;
      4'b0010: n3766_o = 4'b1101;
      4'b0001: n3766_o = 4'b0000;
      default: n3766_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3752_o)
      4'b1000: n3770_o = 3'b111;
      4'b0100: n3770_o = 3'b101;
      4'b0010: n3770_o = 3'b101;
      4'b0001: n3770_o = 3'b111;
      default: n3770_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3752_o)
      4'b1000: n3773_o = 1'b1;
      4'b0100: n3773_o = 1'b0;
      4'b0010: n3773_o = 1'b0;
      4'b0001: n3773_o = 1'b0;
      default: n3773_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3752_o)
      4'b1000: n3776_o = 1'b0;
      4'b0100: n3776_o = 1'b0;
      4'b0010: n3776_o = 1'b0;
      4'b0001: n3776_o = 1'b1;
      default: n3776_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3752_o)
      4'b1000: n3779_o = 1'b0;
      4'b0100: n3779_o = 1'b0;
      4'b0010: n3779_o = 1'b1;
      4'b0001: n3779_o = 1'b0;
      default: n3779_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3752_o)
      4'b1000: n3783_o = 1'b1;
      4'b0100: n3783_o = 1'b1;
      4'b0010: n3783_o = 1'b0;
      4'b0001: n3783_o = 1'b0;
      default: n3783_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1115:17  */
  assign n3785_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1143:38  */
  assign n3788_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1144:33  */
  assign n3790_o = n3788_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1150:73  */
  assign n3792_o = ir[5:3];
  /* T80_MCode.vhd:178:47  */
  assign n3797_o = f[6];
  /* T80_MCode.vhd:178:56  */
  assign n3798_o = ~n3797_o;
  /* T80_MCode.vhd:178:25  */
  assign n3800_o = n3792_o == 3'b000;
  /* T80_MCode.vhd:179:47  */
  assign n3801_o = f[6];
  /* T80_MCode.vhd:179:25  */
  assign n3803_o = n3792_o == 3'b001;
  /* T80_MCode.vhd:180:47  */
  assign n3804_o = f[0];
  /* T80_MCode.vhd:180:56  */
  assign n3805_o = ~n3804_o;
  /* T80_MCode.vhd:180:25  */
  assign n3807_o = n3792_o == 3'b010;
  /* T80_MCode.vhd:181:47  */
  assign n3808_o = f[0];
  /* T80_MCode.vhd:181:25  */
  assign n3810_o = n3792_o == 3'b011;
  /* T80_MCode.vhd:182:47  */
  assign n3811_o = f[2];
  /* T80_MCode.vhd:182:56  */
  assign n3812_o = ~n3811_o;
  /* T80_MCode.vhd:182:25  */
  assign n3814_o = n3792_o == 3'b100;
  /* T80_MCode.vhd:183:47  */
  assign n3815_o = f[2];
  /* T80_MCode.vhd:183:25  */
  assign n3817_o = n3792_o == 3'b101;
  /* T80_MCode.vhd:184:47  */
  assign n3818_o = f[7];
  /* T80_MCode.vhd:184:56  */
  assign n3819_o = ~n3818_o;
  /* T80_MCode.vhd:184:25  */
  assign n3821_o = n3792_o == 3'b110;
  /* T80_MCode.vhd:185:47  */
  assign n3822_o = f[7];
  /* T80_MCode.vhd:185:25  */
  assign n3824_o = n3792_o == 3'b111;
  assign n3825_o = {n3824_o, n3821_o, n3817_o, n3814_o, n3810_o, n3807_o, n3803_o, n3800_o};
  /* T80_MCode.vhd:177:25  */
  always @*
    case (n3825_o)
      8'b10000000: n3827_o = n3822_o;
      8'b01000000: n3827_o = n3819_o;
      8'b00100000: n3827_o = n3815_o;
      8'b00010000: n3827_o = n3812_o;
      8'b00001000: n3827_o = n3808_o;
      8'b00000100: n3827_o = n3805_o;
      8'b00000010: n3827_o = n3801_o;
      8'b00000001: n3827_o = n3798_o;
      default: n3827_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1150:41  */
  assign n3830_o = n3827_o ? 3'b101 : 3'b011;
  /* T80_MCode.vhd:1150:41  */
  assign n3832_o = n3827_o ? 3'b100 : n2200_o;
  /* T80_MCode.vhd:1150:41  */
  assign n3835_o = n3827_o ? 4'b1111 : 4'b0000;
  /* T80_MCode.vhd:1150:41  */
  assign n3838_o = n3827_o ? 4'b1101 : 4'b0000;
  /* T80_MCode.vhd:1150:41  */
  assign n3841_o = n3827_o ? 3'b101 : 3'b111;
  /* T80_MCode.vhd:1147:33  */
  assign n3843_o = n3788_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1158:33  */
  assign n3845_o = n3788_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1163:33  */
  assign n3847_o = n3788_o == 31'b0000000000000000000000000000101;
  assign n3848_o = {n3847_o, n3845_o, n3843_o, n3790_o};
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3848_o)
      4'b1000: n3850_o = 3'b101;
      4'b0100: n3850_o = 3'b101;
      4'b0010: n3850_o = n3830_o;
      4'b0001: n3850_o = 3'b101;
      default: n3850_o = 3'b101;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3848_o)
      4'b1000: n3852_o = n2200_o;
      4'b0100: n3852_o = n2200_o;
      4'b0010: n3852_o = n3832_o;
      4'b0001: n3852_o = n2200_o;
      default: n3852_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3848_o)
      4'b1000: n3856_o = 1'b0;
      4'b0100: n3856_o = 1'b0;
      4'b0010: n3856_o = 1'b1;
      4'b0001: n3856_o = 1'b1;
      default: n3856_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3848_o)
      4'b1000: n3859_o = 4'b0000;
      4'b0100: n3859_o = 4'b1111;
      4'b0010: n3859_o = n3835_o;
      4'b0001: n3859_o = 4'b0000;
      default: n3859_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3848_o)
      4'b1000: n3862_o = 4'b0000;
      4'b0100: n3862_o = 4'b1100;
      4'b0010: n3862_o = n3838_o;
      4'b0001: n3862_o = 4'b0000;
      default: n3862_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3848_o)
      4'b1000: n3865_o = 3'b111;
      4'b0100: n3865_o = 3'b101;
      4'b0010: n3865_o = n3841_o;
      4'b0001: n3865_o = 3'b111;
      default: n3865_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3848_o)
      4'b1000: n3868_o = 1'b1;
      4'b0100: n3868_o = 1'b0;
      4'b0010: n3868_o = 1'b0;
      4'b0001: n3868_o = 1'b0;
      default: n3868_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3848_o)
      4'b1000: n3871_o = 1'b0;
      4'b0100: n3871_o = 1'b0;
      4'b0010: n3871_o = 1'b0;
      4'b0001: n3871_o = 1'b1;
      default: n3871_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3848_o)
      4'b1000: n3874_o = 1'b0;
      4'b0100: n3874_o = 1'b0;
      4'b0010: n3874_o = 1'b1;
      4'b0001: n3874_o = 1'b0;
      default: n3874_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3848_o)
      4'b1000: n3878_o = 1'b1;
      4'b0100: n3878_o = 1'b1;
      4'b0010: n3878_o = 1'b0;
      4'b0001: n3878_o = 1'b0;
      default: n3878_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1139:17  */
  assign n3880_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1139:32  */
  assign n3882_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1139:32  */
  assign n3883_o = n3880_o | n3882_o;
  /* T80_MCode.vhd:1139:43  */
  assign n3885_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1139:43  */
  assign n3886_o = n3883_o | n3885_o;
  /* T80_MCode.vhd:1139:54  */
  assign n3888_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1139:54  */
  assign n3889_o = n3886_o | n3888_o;
  /* T80_MCode.vhd:1139:65  */
  assign n3891_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1139:65  */
  assign n3892_o = n3889_o | n3891_o;
  /* T80_MCode.vhd:1139:76  */
  assign n3894_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1139:76  */
  assign n3895_o = n3892_o | n3894_o;
  /* T80_MCode.vhd:1139:87  */
  assign n3897_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1139:87  */
  assign n3898_o = n3895_o | n3897_o;
  /* T80_MCode.vhd:1139:98  */
  assign n3900_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1139:98  */
  assign n3901_o = n3898_o | n3900_o;
  /* T80_MCode.vhd:1172:30  */
  assign n3902_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1173:25  */
  assign n3904_o = n3902_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1176:25  */
  assign n3906_o = n3902_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1180:25  */
  assign n3908_o = n3902_o == 31'b0000000000000000000000000000011;
  assign n3909_o = {n3908_o, n3906_o, n3904_o};
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3909_o)
      3'b100: n3913_o = 4'b0111;
      3'b010: n3913_o = 4'b0111;
      3'b001: n3913_o = 4'b0000;
      default: n3913_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3909_o)
      3'b100: n3917_o = 3'b111;
      3'b010: n3917_o = 3'b101;
      3'b001: n3917_o = 3'b101;
      default: n3917_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3909_o)
      3'b100: n3920_o = 1'b1;
      3'b010: n3920_o = 1'b0;
      3'b001: n3920_o = 1'b0;
      default: n3920_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3909_o)
      3'b100: n3923_o = 1'b0;
      3'b010: n3923_o = 1'b1;
      3'b001: n3923_o = 1'b0;
      default: n3923_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1169:17  */
  assign n3925_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1256:38  */
  assign n3927_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1258:73  */
  assign n3929_o = ir[5:3];
  /* T80_MCode.vhd:178:47  */
  assign n3934_o = f[6];
  /* T80_MCode.vhd:178:56  */
  assign n3935_o = ~n3934_o;
  /* T80_MCode.vhd:178:25  */
  assign n3937_o = n3929_o == 3'b000;
  /* T80_MCode.vhd:179:47  */
  assign n3938_o = f[6];
  /* T80_MCode.vhd:179:25  */
  assign n3940_o = n3929_o == 3'b001;
  /* T80_MCode.vhd:180:47  */
  assign n3941_o = f[0];
  /* T80_MCode.vhd:180:56  */
  assign n3942_o = ~n3941_o;
  /* T80_MCode.vhd:180:25  */
  assign n3944_o = n3929_o == 3'b010;
  /* T80_MCode.vhd:181:47  */
  assign n3945_o = f[0];
  /* T80_MCode.vhd:181:25  */
  assign n3947_o = n3929_o == 3'b011;
  /* T80_MCode.vhd:182:47  */
  assign n3948_o = f[2];
  /* T80_MCode.vhd:182:56  */
  assign n3949_o = ~n3948_o;
  /* T80_MCode.vhd:182:25  */
  assign n3951_o = n3929_o == 3'b100;
  /* T80_MCode.vhd:183:47  */
  assign n3952_o = f[2];
  /* T80_MCode.vhd:183:25  */
  assign n3954_o = n3929_o == 3'b101;
  /* T80_MCode.vhd:184:47  */
  assign n3955_o = f[7];
  /* T80_MCode.vhd:184:56  */
  assign n3956_o = ~n3955_o;
  /* T80_MCode.vhd:184:25  */
  assign n3958_o = n3929_o == 3'b110;
  /* T80_MCode.vhd:185:47  */
  assign n3959_o = f[7];
  /* T80_MCode.vhd:185:25  */
  assign n3961_o = n3929_o == 3'b111;
  assign n3962_o = {n3961_o, n3958_o, n3954_o, n3951_o, n3947_o, n3944_o, n3940_o, n3937_o};
  /* T80_MCode.vhd:177:25  */
  always @*
    case (n3962_o)
      8'b10000000: n3964_o = n3959_o;
      8'b01000000: n3964_o = n3956_o;
      8'b00100000: n3964_o = n3952_o;
      8'b00010000: n3964_o = n3949_o;
      8'b00001000: n3964_o = n3945_o;
      8'b00000100: n3964_o = n3942_o;
      8'b00000010: n3964_o = n3938_o;
      8'b00000001: n3964_o = n3935_o;
      default: n3964_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1258:41  */
  assign n3967_o = n3964_o ? 3'b011 : 3'b001;
  /* T80_MCode.vhd:1258:41  */
  assign n3970_o = n3964_o ? 3'b101 : 3'b111;
  /* T80_MCode.vhd:1257:33  */
  assign n3972_o = n3927_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1264:33  */
  assign n3974_o = n3927_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1268:33  */
  assign n3976_o = n3927_o == 31'b0000000000000000000000000000011;
  assign n3977_o = {n3976_o, n3974_o, n3972_o};
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3977_o)
      3'b100: n3979_o = 3'b011;
      3'b010: n3979_o = 3'b011;
      3'b001: n3979_o = n3967_o;
      default: n3979_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3977_o)
      3'b100: n3982_o = n2200_o;
      3'b010: n3982_o = n2200_o;
      3'b001: n3982_o = 3'b101;
      default: n3982_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3977_o)
      3'b100: n3986_o = 4'b0111;
      3'b010: n3986_o = 4'b0111;
      3'b001: n3986_o = 4'b0000;
      default: n3986_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3977_o)
      3'b100: n3989_o = 3'b111;
      3'b010: n3989_o = 3'b101;
      3'b001: n3989_o = n3970_o;
      default: n3989_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3977_o)
      3'b100: n3992_o = 1'b1;
      3'b010: n3992_o = 1'b0;
      3'b001: n3992_o = 1'b0;
      default: n3992_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3977_o)
      3'b100: n3995_o = 1'b0;
      3'b010: n3995_o = 1'b1;
      3'b001: n3995_o = 1'b0;
      default: n3995_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1185:17  */
  assign n3997_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1185:32  */
  assign n3999_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1185:32  */
  assign n4000_o = n3997_o | n3999_o;
  /* T80_MCode.vhd:1185:43  */
  assign n4002_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1185:43  */
  assign n4003_o = n4000_o | n4002_o;
  /* T80_MCode.vhd:1185:54  */
  assign n4005_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1185:54  */
  assign n4006_o = n4003_o | n4005_o;
  /* T80_MCode.vhd:1185:65  */
  assign n4008_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1185:65  */
  assign n4009_o = n4006_o | n4008_o;
  /* T80_MCode.vhd:1185:76  */
  assign n4011_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1185:76  */
  assign n4012_o = n4009_o | n4011_o;
  /* T80_MCode.vhd:1185:87  */
  assign n4014_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1185:87  */
  assign n4015_o = n4012_o | n4014_o;
  /* T80_MCode.vhd:1185:98  */
  assign n4017_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1185:98  */
  assign n4018_o = n4015_o | n4017_o;
  /* T80_MCode.vhd:1277:30  */
  assign n4019_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1278:25  */
  assign n4021_o = n4019_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1283:25  */
  assign n4023_o = n4019_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1288:25  */
  assign n4025_o = n4019_o == 31'b0000000000000000000000000000011;
  assign n4026_o = {n4025_o, n4023_o, n4021_o};
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n4026_o)
      3'b100: n4028_o = n2200_o;
      3'b010: n4028_o = n2200_o;
      3'b001: n4028_o = 3'b101;
      default: n4028_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n4026_o)
      3'b100: n4032_o = 4'b0000;
      3'b010: n4032_o = 4'b1111;
      3'b001: n4032_o = 4'b1111;
      default: n4032_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n4026_o)
      3'b100: n4036_o = 4'b0000;
      3'b010: n4036_o = 4'b1100;
      3'b001: n4036_o = 4'b1101;
      default: n4036_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n4026_o)
      3'b100: n4040_o = 3'b111;
      3'b010: n4040_o = 3'b101;
      3'b001: n4040_o = 3'b101;
      default: n4040_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n4026_o)
      3'b100: n4043_o = 1'b1;
      3'b010: n4043_o = 1'b0;
      3'b001: n4043_o = 1'b0;
      default: n4043_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n4026_o)
      3'b100: n4047_o = 1'b1;
      3'b010: n4047_o = 1'b1;
      3'b001: n4047_o = 1'b0;
      default: n4047_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1274:17  */
  assign n4049_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1274:32  */
  assign n4051_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1274:32  */
  assign n4052_o = n4049_o | n4051_o;
  /* T80_MCode.vhd:1274:43  */
  assign n4054_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1274:43  */
  assign n4055_o = n4052_o | n4054_o;
  /* T80_MCode.vhd:1274:54  */
  assign n4057_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1274:54  */
  assign n4058_o = n4055_o | n4057_o;
  /* T80_MCode.vhd:1274:65  */
  assign n4060_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1274:65  */
  assign n4061_o = n4058_o | n4060_o;
  /* T80_MCode.vhd:1274:76  */
  assign n4063_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1274:76  */
  assign n4064_o = n4061_o | n4063_o;
  /* T80_MCode.vhd:1274:87  */
  assign n4066_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1274:87  */
  assign n4067_o = n4064_o | n4066_o;
  /* T80_MCode.vhd:1274:98  */
  assign n4069_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1274:98  */
  assign n4070_o = n4067_o | n4069_o;
  /* T80_MCode.vhd:1299:38  */
  assign n4071_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1300:33  */
  assign n4073_o = n4071_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1303:33  */
  assign n4075_o = n4071_o == 31'b0000000000000000000000000000011;
  assign n4076_o = {n4075_o, n4073_o};
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n4076_o)
      2'b10: n4079_o = 1'b0;
      2'b01: n4079_o = 1'b1;
      default: n4079_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n4076_o)
      2'b10: n4082_o = 1'b1;
      2'b01: n4082_o = 1'b0;
      default: n4082_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n4076_o)
      2'b10: n4085_o = 3'b111;
      2'b01: n4085_o = 3'b100;
      default: n4085_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n4076_o)
      2'b10: n4088_o = 1'b1;
      2'b01: n4088_o = 1'b0;
      default: n4088_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1295:17  */
  assign n4090_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1313:38  */
  assign n4091_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1314:33  */
  assign n4093_o = n4091_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1318:33  */
  assign n4095_o = n4091_o == 31'b0000000000000000000000000000011;
  assign n4096_o = {n4095_o, n4093_o};
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n4096_o)
      2'b10: n4099_o = 1'b0;
      2'b01: n4099_o = 1'b1;
      default: n4099_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n4096_o)
      2'b10: n4102_o = 4'b0000;
      2'b01: n4102_o = 4'b0111;
      default: n4102_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n4096_o)
      2'b10: n4105_o = 3'b111;
      2'b01: n4105_o = 3'b100;
      default: n4105_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n4096_o)
      2'b10: n4108_o = 1'b1;
      2'b01: n4108_o = 1'b0;
      default: n4108_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n4096_o)
      2'b10: n4111_o = 1'b1;
      2'b01: n4111_o = 1'b0;
      default: n4111_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1309:17  */
  assign n4113_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1331:17  */
  assign n4115_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1336:17  */
  assign n4117_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1341:17  */
  assign n4119_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1341:32  */
  assign n4121_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1341:32  */
  assign n4122_o = n4119_o | n4121_o;
  assign n4123_o = {n4122_o, n4117_o, n4115_o, n4113_o, n4090_o, n4070_o, n4018_o, n3925_o, n3901_o, n3785_o, n3742_o, n3702_o, n3700_o, n3674_o, n3647_o, n3621_o, n3594_o, n3575_o, n3493_o, n3472_o, n3460_o, n3448_o, n3436_o, n3347_o, n3345_o, n3343_o, n3341_o, n3242_o, n3240_o, n3238_o, n3236_o, n3233_o, n3198_o, n3178_o, n3143_o, n3123_o, n3084_o, n3041_o, n2873_o, n2824_o, n2822_o, n2820_o, n2818_o, n2765_o, n2716_o, n2714_o, n2677_o, n2640_o, n2593_o, n2564_o, n2544_o, n2524_o, n2501_o, n2487_o, n2473_o, n2451_o, n2414_o, n2380_o, n2349_o};
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4156_o = 3'b001;
      59'b01000000000000000000000000000000000000000000000000000000000: n4156_o = 3'b001;
      59'b00100000000000000000000000000000000000000000000000000000000: n4156_o = 3'b001;
      59'b00010000000000000000000000000000000000000000000000000000000: n4156_o = 3'b011;
      59'b00001000000000000000000000000000000000000000000000000000000: n4156_o = 3'b011;
      59'b00000100000000000000000000000000000000000000000000000000000: n4156_o = 3'b011;
      59'b00000010000000000000000000000000000000000000000000000000000: n4156_o = n3979_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4156_o = 3'b011;
      59'b00000000100000000000000000000000000000000000000000000000000: n4156_o = n3850_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4156_o = 3'b101;
      59'b00000000001000000000000000000000000000000000000000000000000: n4156_o = 3'b011;
      59'b00000000000100000000000000000000000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000010000000000000000000000000000000000000000000000: n4156_o = n3686_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4156_o = n3660_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4156_o = n3633_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4156_o = n3607_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4156_o = 3'b011;
      59'b00000000000000000100000000000000000000000000000000000000000: n4156_o = 3'b011;
      59'b00000000000000000010000000000000000000000000000000000000000: n4156_o = 3'b011;
      59'b00000000000000000001000000000000000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000100000000000000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000010000000000000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000001000000000000000000000000000000000000: n4156_o = 3'b011;
      59'b00000000000000000000000100000000000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000010000000000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000001000000000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000100000000000000000000000000000000: n4156_o = n3328_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000001000000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000000100000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000000010000000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000000001000000000000000000000000000: n4156_o = 3'b011;
      59'b00000000000000000000000000000000100000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000000000010000000000000000000000000: n4156_o = 3'b011;
      59'b00000000000000000000000000000000001000000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000000000000100000000000000000000000: n4156_o = 3'b010;
      59'b00000000000000000000000000000000000010000000000000000000000: n4156_o = 3'b010;
      59'b00000000000000000000000000000000000001000000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000000000000000100000000000000000000: n4156_o = 3'b101;
      59'b00000000000000000000000000000000000000010000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000000000000000001000000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000000000000000000100000000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000000000000000000010000000000000000: n4156_o = 3'b011;
      59'b00000000000000000000000000000000000000000001000000000000000: n4156_o = 3'b011;
      59'b00000000000000000000000000000000000000000000100000000000000: n4156_o = 3'b001;
      59'b00000000000000000000000000000000000000000000010000000000000: n4156_o = 3'b101;
      59'b00000000000000000000000000000000000000000000001000000000000: n4156_o = 3'b101;
      59'b00000000000000000000000000000000000000000000000100000000000: n4156_o = 3'b011;
      59'b00000000000000000000000000000000000000000000000010000000000: n4156_o = 3'b100;
      59'b00000000000000000000000000000000000000000000000001000000000: n4156_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000100000000: n4156_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000010000000: n4156_o = 3'b100;
      59'b00000000000000000000000000000000000000000000000000001000000: n4156_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000100000: n4156_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000010000: n4156_o = 3'b011;
      59'b00000000000000000000000000000000000000000000000000000001000: n4156_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000100: n4156_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000010: n4156_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000001: n4156_o = 3'b001;
      default: n4156_o = 3'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4161_o = n2200_o;
      59'b01000000000000000000000000000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00100000000000000000000000000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00010000000000000000000000000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4161_o = n4028_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4161_o = n3982_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4161_o = n3852_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4161_o = n3754_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4161_o = n3714_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000010000000000000000000000000000000000000000000000: n4161_o = n3689_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4161_o = n3663_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4161_o = n3636_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4161_o = n3610_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4161_o = n3583_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000100000000000000000000000000000000000000: n4161_o = 3'b110;
      59'b00000000000000000000010000000000000000000000000000000000000: n4161_o = 3'b110;
      59'b00000000000000000000001000000000000000000000000000000000000: n4161_o = n3395_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000010000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000001000000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000100000000000000000000000000000000: n4161_o = n3329_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000001000000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000100000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000010000000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000001000000000000000000000000000: n4161_o = n3208_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000010000000000000000000000000: n4161_o = n3153_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000100000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4161_o = n2839_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000010000000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4161_o = n2740_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4161_o = 3'b110;
      59'b00000000000000000000000000000000000000000000010000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4161_o = n2200_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4161_o = n2200_o;
      default: n4161_o = 3'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4167_o = 2'b11;
      59'b01000000000000000000000000000000000000000000000000000000000: n4167_o = 2'b10;
      59'b00100000000000000000000000000000000000000000000000000000000: n4167_o = 2'b01;
      59'b00010000000000000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000010000000000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000001000000000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000100000000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000010000000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000001000000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000010000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000001000000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000100000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000010000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000010000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000001000000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000100000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000001000000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000100000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000010000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4167_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4167_o = 2'b00;
      default: n4167_o = 2'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4170_o = n4099_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4170_o = n4079_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4170_o = n3856_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4170_o = n3758_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4170_o = n3717_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4170_o = n3692_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4170_o = n3666_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4170_o = n3639_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4170_o = n3613_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4170_o = n3586_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n4170_o = n3544_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4170_o = n3482_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4170_o = n3331_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4170_o = n3090_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4170_o = n2691_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4170_o = n2656_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4170_o = n2621_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4170_o = n2576_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4170_o = n2513_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4170_o = n2461_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4170_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4170_o = n2355_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4170_o = 1'b0;
      default: n4170_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4173_o = n2694_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4173_o = n2659_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4173_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4173_o = 1'b0;
      default: n4173_o = 1'bX;
    endcase
  assign n4174_o = n2744_o[1:0];
  assign n4175_o = n2795_o[1:0];
  assign n4176_o = n2843_o[1:0];
  assign n4177_o = n3332_o[1:0];
  assign n4178_o = n3762_o[1:0];
  assign n4179_o = n3859_o[1:0];
  assign n4180_o = n3913_o[1:0];
  assign n4181_o = n3986_o[1:0];
  assign n4182_o = n4032_o[1:0];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4185_o = n4182_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4185_o = n4181_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4185_o = n4180_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4185_o = n4179_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4185_o = n4178_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4185_o = n2195_o;
      59'b00000000000000000000010000000000000000000000000000000000000: n4185_o = n2195_o;
      59'b00000000000000000000001000000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000100000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4185_o = n4177_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4185_o = n4176_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4185_o = n4175_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4185_o = n4174_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000001000000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000100000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000010000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4185_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4185_o = 2'b00;
      default: n4185_o = 2'bX;
    endcase
  assign n4186_o = n2744_o[3:2];
  assign n4187_o = n2795_o[3:2];
  assign n4188_o = n2843_o[3:2];
  assign n4189_o = n3332_o[3:2];
  assign n4190_o = n3762_o[3:2];
  assign n4191_o = n3859_o[3:2];
  assign n4192_o = n3913_o[3:2];
  assign n4193_o = n3986_o[3:2];
  assign n4194_o = n4032_o[3:2];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4197_o = n4194_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4197_o = n4193_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4197_o = n4192_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4197_o = n4191_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4197_o = n4190_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4197_o = 2'b11;
      59'b00000000000000000000010000000000000000000000000000000000000: n4197_o = 2'b01;
      59'b00000000000000000000001000000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000100000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4197_o = n4189_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4197_o = n4188_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4197_o = n4187_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4197_o = n4186_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000001000000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000100000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000010000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4197_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4197_o = 2'b00;
      default: n4197_o = 2'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4206_o = n3720_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4206_o = 1'b1;
      59'b00000000000000000000100000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4206_o = n3399_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4206_o = 1'b1;
      59'b00000000000000000000000000000001000000000000000000000000000: n4206_o = n3211_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4206_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4206_o = n3156_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4206_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4206_o = n3093_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4206_o = n3051_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4206_o = 1'b1;
      59'b00000000000000000000000000000000000000100000000000000000000: n4206_o = n2847_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4206_o = n2799_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4206_o = n2663_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4206_o = n2625_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4206_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4206_o = n2389_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4206_o = n2358_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4206_o = 1'b1;
      default: n4206_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4209_o = n4082_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4209_o = n2516_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4209_o = n2496_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4209_o = n2482_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4209_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4209_o = 1'b0;
      default: n4209_o = 1'bX;
    endcase
  assign n4210_o = n2851_o[2:0];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b01000000000000000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00100000000000000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00010000000000000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00001000000000000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000100000000000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000010000000000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000001000000000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000100000000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000010000000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000001000000000000000000000000000000000000000000000000: n4213_o = n3722_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000010000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000001000000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000100000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000010000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000001000000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000100000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000010000000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000001000000000000000000000000000000000000000: n4213_o = 3'b111;
      59'b00000000000000000000100000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000010000000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000001000000000000000000000000000000000000: n4213_o = n3401_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000010000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000001000000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000100000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000010000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000001000000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000100000000000000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000010000000000000000000000000000: n4213_o = 3'b111;
      59'b00000000000000000000000000000001000000000000000000000000000: n4213_o = n3213_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4213_o = n2193_o;
      59'b00000000000000000000000000000000010000000000000000000000000: n4213_o = n3158_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4213_o = n2193_o;
      59'b00000000000000000000000000000000000100000000000000000000000: n4213_o = n3095_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4213_o = n3053_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4213_o = 3'b111;
      59'b00000000000000000000000000000000000000100000000000000000000: n4213_o = n4210_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000001000000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000100000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000010000000000000000: n4213_o = n2801_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000100000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000010000000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000001000000000000: n4213_o = n2665_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4213_o = n2627_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000001000000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000100000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000010000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000001000000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000100000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000010000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000001000: n4213_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000000100: n4213_o = n2391_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4213_o = n2360_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4213_o = n2193_o;
      default: n4213_o = 3'bX;
    endcase
  assign n4214_o = n2851_o[3];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4217_o = n4214_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4217_o = n2803_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4217_o = n2629_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4217_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4217_o = 1'b0;
      default: n4217_o = 1'bX;
    endcase
  assign n4218_o = n2194_o[0];
  assign n4219_o = n2423_o[0];
  assign n4220_o = n2463_o[0];
  assign n4221_o = n2533_o[0];
  assign n4222_o = n2553_o[0];
  assign n4223_o = n2579_o[0];
  assign n4224_o = n2698_o[0];
  assign n4225_o = n2746_o[0];
  assign n4226_o = n2855_o[0];
  assign n4227_o = n2194_o[0];
  assign n4228_o = n3055_o[0];
  assign n4229_o = n3097_o[0];
  assign n4231_o = n3161_o[0];
  assign n4233_o = n3216_o[0];
  assign n4234_o = n3333_o[0];
  assign n4235_o = n3725_o[0];
  assign n4236_o = n3766_o[0];
  assign n4237_o = n3862_o[0];
  assign n4238_o = n4036_o[0];
  assign n4239_o = n4102_o[0];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4242_o = n4239_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4242_o = n4238_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4242_o = n4237_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4242_o = n4236_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4242_o = n4235_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4242_o = n3403_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4242_o = n4234_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4242_o = n4233_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4242_o = n4231_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4242_o = n4229_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4242_o = n4228_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4242_o = n4227_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4242_o = n4226_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4242_o = n4225_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4242_o = n4224_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4242_o = n4223_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4242_o = n4222_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4242_o = n4221_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4242_o = n4220_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4242_o = n4219_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4242_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4242_o = n4218_o;
      default: n4242_o = 1'bX;
    endcase
  assign n4243_o = n2194_o[2:1];
  assign n4244_o = n2423_o[2:1];
  assign n4245_o = n2463_o[2:1];
  assign n4246_o = n2533_o[2:1];
  assign n4247_o = n2553_o[2:1];
  assign n4248_o = n2579_o[2:1];
  assign n4249_o = n2698_o[2:1];
  assign n4250_o = n2746_o[2:1];
  assign n4251_o = n2855_o[2:1];
  assign n4252_o = n2194_o[2:1];
  assign n4253_o = n3055_o[2:1];
  assign n4254_o = n3097_o[2:1];
  assign n4256_o = n3161_o[2:1];
  assign n4258_o = n3216_o[2:1];
  assign n4259_o = n3333_o[2:1];
  assign n4260_o = n3725_o[2:1];
  assign n4261_o = n3766_o[2:1];
  assign n4262_o = n3862_o[2:1];
  assign n4263_o = n4036_o[2:1];
  assign n4264_o = n4102_o[2:1];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4267_o = n4264_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4267_o = n4263_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000001000000000000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000100000000000000000000000000000000000000000000000000: n4267_o = n4262_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4267_o = n4261_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4267_o = n4260_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000010000000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000001000000000000000000000000000000000000: n4267_o = n3405_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4267_o = n4259_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4267_o = n4258_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4267_o = 2'b01;
      59'b00000000000000000000000000000000010000000000000000000000000: n4267_o = n4256_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4267_o = 2'b01;
      59'b00000000000000000000000000000000000100000000000000000000000: n4267_o = n4254_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4267_o = n4253_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4267_o = n4252_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4267_o = n4251_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000001000000000000000: n4267_o = n4250_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4267_o = n4249_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4267_o = n4248_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4267_o = n4247_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4267_o = n4246_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4267_o = n4245_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4267_o = n4244_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4267_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4267_o = n4243_o;
      default: n4267_o = 2'bX;
    endcase
  assign n4268_o = n2533_o[3];
  assign n4269_o = n2553_o[3];
  assign n4270_o = n2579_o[3];
  assign n4271_o = n2698_o[3];
  assign n4272_o = n2746_o[3];
  assign n4273_o = n2855_o[3];
  assign n4275_o = n3161_o[3];
  assign n4277_o = n3216_o[3];
  assign n4278_o = n3333_o[3];
  assign n4279_o = n3725_o[3];
  assign n4280_o = n3766_o[3];
  assign n4281_o = n3862_o[3];
  assign n4282_o = n4036_o[3];
  assign n4283_o = n4102_o[3];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4286_o = n4283_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4286_o = n4282_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4286_o = n4281_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4286_o = n4280_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4286_o = n4279_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4286_o = n3407_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4286_o = n4278_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4286_o = n4277_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4286_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4286_o = n4275_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4286_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4286_o = n4273_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4286_o = n4272_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4286_o = n4271_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4286_o = n4270_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4286_o = n4269_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4286_o = n4268_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4286_o = n2465_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4286_o = n2425_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4286_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4286_o = 1'b0;
      default: n4286_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b01000000000000000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00100000000000000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00010000000000000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4292_o = n3727_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000010000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4292_o = 4'b1000;
      59'b00000000000000000000100000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000010000000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000001000000000000000000000000000000000000: n4292_o = n3410_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000010000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000001000000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000100000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000001000000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000100000000000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000010000000000000000000000000000: n4292_o = 4'b1100;
      59'b00000000000000000000000000000001000000000000000000000000000: n4292_o = n3218_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4292_o = 4'b0010;
      59'b00000000000000000000000000000000010000000000000000000000000: n4292_o = n3163_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4292_o = 4'b0000;
      59'b00000000000000000000000000000000000100000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000010000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000010000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4292_o = n2203_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4292_o = n2203_o;
      default: n4292_o = 4'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4300_o = n3730_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4300_o = 1'b1;
      59'b00000000000000000000100000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4300_o = n3414_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4300_o = 1'b1;
      59'b00000000000000000000000000000001000000000000000000000000000: n4300_o = n3221_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4300_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4300_o = n3166_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4300_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4300_o = n3100_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4300_o = n3058_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4300_o = 1'b1;
      59'b00000000000000000000000000000000000000100000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4300_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4300_o = 1'b0;
      default: n4300_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4305_o = n3224_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4305_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4305_o = n3169_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4305_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4305_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4305_o = 1'b0;
      default: n4305_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4308_o = n3418_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4308_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4308_o = 1'b0;
      default: n4308_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b01000000000000000000000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00100000000000000000000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00010000000000000000000000000000000000000000000000000000000: n4311_o = n4105_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4311_o = n4085_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4311_o = n4040_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4311_o = n3989_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4311_o = n3917_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4311_o = n3865_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4311_o = n3770_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000100000000000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000010000000000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000001000000000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000100000000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000010000000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000001000000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000100000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000010000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000001000000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000100000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000010000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000001000000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000100000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000010000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000001000000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000100000000000000000000000000000000: n4311_o = n3334_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000001000000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000100000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000010000000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000001000000000000000000000000000: n4311_o = n3228_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000000010000000000000000000000000: n4311_o = n3173_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000000000100000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000000000010000000000000000000000: n4311_o = n3061_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000000000000100000000000000000000: n4311_o = n2861_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000000000000001000000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000000000000000100000000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000000000000000010000000000000000: n4311_o = n2807_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4311_o = n2750_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000000000000000000010000000000000: n4311_o = n2702_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4311_o = n2669_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4311_o = 3'b111;
      59'b00000000000000000000000000000000000000000000000010000000000: n4311_o = n2582_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4311_o = n2556_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4311_o = n2536_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4311_o = n2519_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4311_o = n2499_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4311_o = n2485_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4311_o = n2468_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4311_o = n2428_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4311_o = n2394_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4311_o = 3'b111;
      59'b00000000000000000000000000000000000000000000000000000000001: n4311_o = 3'b111;
      default: n4311_o = 3'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4314_o = n4108_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4314_o = n4088_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4314_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4314_o = 1'b0;
      default: n4314_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4317_o = n3992_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4317_o = n3920_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4317_o = n3546_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4317_o = n3485_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4317_o = n3336_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4317_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4317_o = 1'b0;
      default: n4317_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4320_o = n3733_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4320_o = n3695_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4320_o = n3669_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4320_o = n3642_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4320_o = n3616_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4320_o = n3589_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4320_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4320_o = 1'b0;
      default: n4320_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4324_o = 1'b1;
      59'b00000000000010000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4324_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4324_o = 1'b0;
      default: n4324_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4327_o = n3868_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4327_o = n3773_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4327_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4327_o = 1'b0;
      default: n4327_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4330_o = n4043_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4330_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4330_o = 1'b0;
      default: n4330_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4333_o = n3995_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4333_o = n3923_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4333_o = n3871_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4333_o = n3776_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4333_o = n3549_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4333_o = n3488_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4333_o = n3338_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4333_o = n2864_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4333_o = n2705_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4333_o = n2672_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4333_o = n2585_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4333_o = n2522_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4333_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4333_o = 1'b0;
      default: n4333_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4336_o = n3874_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4336_o = n3779_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4336_o = n3552_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4336_o = n3491_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4336_o = n2867_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4336_o = n2708_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4336_o = n2675_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4336_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4336_o = 1'b0;
      default: n4336_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4340_o = 1'b1;
      59'b00000000000000000000000000000000000000000000010000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4340_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4340_o = 1'b0;
      default: n4340_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4344_o = 1'b1;
      59'b00000000000000000000000000000000000000000010000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4344_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4344_o = 1'b0;
      default: n4344_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4348_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4348_o = 1'b1;
      default: n4348_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4352_o = 1'b1;
      59'b00000000000000000000000000000000000000000100000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4352_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4352_o = 1'b0;
      default: n4352_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4356_o = 1'b1;
      59'b00000000000000000000000000000000000000001000000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4356_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4356_o = 1'b0;
      default: n4356_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4359_o = n3737_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4359_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4359_o = 1'b0;
      default: n4359_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4363_o = 1'b1;
      59'b00000000000000000000000000000010000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4363_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4363_o = 1'b0;
      default: n4363_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4367_o = 1'b1;
      59'b00000000000000000000000000000100000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4367_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4367_o = 1'b0;
      default: n4367_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4371_o = 1'b1;
      59'b00000000000000000000000000001000000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4371_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4371_o = 1'b0;
      default: n4371_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000010000000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000001000000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000100000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000010000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000001000000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000010000000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000001000000000000000000000000000000000000: n4374_o = n3421_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000010000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000010000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000001000000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000100000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4374_o = n2588_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4374_o = n2559_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4374_o = n2539_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4374_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4374_o = 2'b00;
      default: n4374_o = 2'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4378_o = 1'b1;
      59'b00000000000000000000000001000000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4378_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4378_o = 1'b0;
      default: n4378_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4382_o = 1'b1;
      59'b00000000000000000000000010000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4382_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4382_o = 1'b0;
      default: n4382_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4386_o = 1'b1;
      59'b00000000000000000000000000100000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4386_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4386_o = 1'b0;
      default: n4386_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4389_o = n3740_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4389_o = n3698_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4389_o = n3672_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4389_o = n3645_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4389_o = n3619_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4389_o = n3592_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4389_o = n3425_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4389_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4389_o = 1'b0;
      default: n4389_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n4123_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4392_o = n4111_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4392_o = n4047_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4392_o = n3878_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4392_o = n3783_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4392_o = n3339_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4392_o = n3231_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4392_o = n3176_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4392_o = n2871_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4392_o = n2754_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4392_o = n2712_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4392_o = n2591_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4392_o = n2562_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4392_o = n2542_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4392_o = n2471_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4392_o = n2431_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4392_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4392_o = 1'b0;
      default: n4392_o = 1'bX;
    endcase
  /* T80_MCode.vhd:257:17  */
  assign n4394_o = iset == 2'b00;
  /* T80_MCode.vhd:1356:54  */
  assign n4395_o = ir[2:0];
  /* T80_MCode.vhd:1357:54  */
  assign n4396_o = ir[2:0];
  /* T80_MCode.vhd:1376:44  */
  assign n4398_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1377:51  */
  assign n4400_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1377:41  */
  assign n4403_o = n4400_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1377:41  */
  assign n4405_o = n4400_o ? 4'b1000 : n2203_o;
  /* T80_MCode.vhd:1377:41  */
  assign n4408_o = n4400_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1386:46  */
  assign n4409_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1387:41  */
  assign n4411_o = n4409_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1387:48  */
  assign n4413_o = n4409_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1387:48  */
  assign n4414_o = n4411_o | n4413_o;
  /* T80_MCode.vhd:1389:41  */
  assign n4416_o = n4409_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1395:41  */
  assign n4418_o = n4409_o == 31'b0000000000000000000000000000011;
  assign n4419_o = {n4418_o, n4416_o, n4414_o};
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4419_o)
      3'b100: n4421_o = n2200_o;
      3'b010: n4421_o = 3'b100;
      3'b001: n4421_o = n2200_o;
      default: n4421_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4419_o)
      3'b100: n4424_o = 1'b0;
      3'b010: n4424_o = 1'b1;
      3'b001: n4424_o = 1'b0;
      default: n4424_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4419_o)
      3'b100: n4426_o = n2203_o;
      3'b010: n4426_o = 4'b1000;
      3'b001: n4426_o = n2203_o;
      default: n4426_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4419_o)
      3'b100: n4429_o = 1'b0;
      3'b010: n4429_o = 1'b1;
      3'b001: n4429_o = 1'b0;
      default: n4429_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4419_o)
      3'b100: n4433_o = 3'b111;
      3'b010: n4433_o = 3'b010;
      3'b001: n4433_o = 3'b010;
      default: n4433_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4419_o)
      3'b100: n4436_o = 1'b1;
      3'b010: n4436_o = 1'b0;
      3'b001: n4436_o = 1'b0;
      default: n4436_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1376:33  */
  assign n4439_o = n4398_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1376:33  */
  assign n4440_o = n4398_o ? n2200_o : n4421_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4441_o = n4398_o ? n4403_o : n4424_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4442_o = n4398_o ? n4405_o : n4426_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4443_o = n4398_o ? n4408_o : n4429_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4445_o = n4398_o ? 3'b111 : n4433_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4447_o = n4398_o ? 1'b0 : n4436_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4450_o = n4398_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1360:25  */
  assign n4452_o = ir == 8'b00000000;
  /* T80_MCode.vhd:1360:40  */
  assign n4454_o = ir == 8'b00000001;
  /* T80_MCode.vhd:1360:40  */
  assign n4455_o = n4452_o | n4454_o;
  /* T80_MCode.vhd:1360:51  */
  assign n4457_o = ir == 8'b00000010;
  /* T80_MCode.vhd:1360:51  */
  assign n4458_o = n4455_o | n4457_o;
  /* T80_MCode.vhd:1360:62  */
  assign n4460_o = ir == 8'b00000011;
  /* T80_MCode.vhd:1360:62  */
  assign n4461_o = n4458_o | n4460_o;
  /* T80_MCode.vhd:1360:73  */
  assign n4463_o = ir == 8'b00000100;
  /* T80_MCode.vhd:1360:73  */
  assign n4464_o = n4461_o | n4463_o;
  /* T80_MCode.vhd:1360:84  */
  assign n4466_o = ir == 8'b00000101;
  /* T80_MCode.vhd:1360:84  */
  assign n4467_o = n4464_o | n4466_o;
  /* T80_MCode.vhd:1360:95  */
  assign n4469_o = ir == 8'b00000111;
  /* T80_MCode.vhd:1360:95  */
  assign n4470_o = n4467_o | n4469_o;
  /* T80_MCode.vhd:1361:33  */
  assign n4472_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1361:33  */
  assign n4473_o = n4470_o | n4472_o;
  /* T80_MCode.vhd:1361:44  */
  assign n4475_o = ir == 8'b00010001;
  /* T80_MCode.vhd:1361:44  */
  assign n4476_o = n4473_o | n4475_o;
  /* T80_MCode.vhd:1361:55  */
  assign n4478_o = ir == 8'b00010010;
  /* T80_MCode.vhd:1361:55  */
  assign n4479_o = n4476_o | n4478_o;
  /* T80_MCode.vhd:1361:66  */
  assign n4481_o = ir == 8'b00010011;
  /* T80_MCode.vhd:1361:66  */
  assign n4482_o = n4479_o | n4481_o;
  /* T80_MCode.vhd:1361:77  */
  assign n4484_o = ir == 8'b00010100;
  /* T80_MCode.vhd:1361:77  */
  assign n4485_o = n4482_o | n4484_o;
  /* T80_MCode.vhd:1361:88  */
  assign n4487_o = ir == 8'b00010101;
  /* T80_MCode.vhd:1361:88  */
  assign n4488_o = n4485_o | n4487_o;
  /* T80_MCode.vhd:1361:99  */
  assign n4490_o = ir == 8'b00010111;
  /* T80_MCode.vhd:1361:99  */
  assign n4491_o = n4488_o | n4490_o;
  /* T80_MCode.vhd:1362:33  */
  assign n4493_o = ir == 8'b00001000;
  /* T80_MCode.vhd:1362:33  */
  assign n4494_o = n4491_o | n4493_o;
  /* T80_MCode.vhd:1362:44  */
  assign n4496_o = ir == 8'b00001001;
  /* T80_MCode.vhd:1362:44  */
  assign n4497_o = n4494_o | n4496_o;
  /* T80_MCode.vhd:1362:55  */
  assign n4499_o = ir == 8'b00001010;
  /* T80_MCode.vhd:1362:55  */
  assign n4500_o = n4497_o | n4499_o;
  /* T80_MCode.vhd:1362:66  */
  assign n4502_o = ir == 8'b00001011;
  /* T80_MCode.vhd:1362:66  */
  assign n4503_o = n4500_o | n4502_o;
  /* T80_MCode.vhd:1362:77  */
  assign n4505_o = ir == 8'b00001100;
  /* T80_MCode.vhd:1362:77  */
  assign n4506_o = n4503_o | n4505_o;
  /* T80_MCode.vhd:1362:88  */
  assign n4508_o = ir == 8'b00001101;
  /* T80_MCode.vhd:1362:88  */
  assign n4509_o = n4506_o | n4508_o;
  /* T80_MCode.vhd:1362:99  */
  assign n4511_o = ir == 8'b00001111;
  /* T80_MCode.vhd:1362:99  */
  assign n4512_o = n4509_o | n4511_o;
  /* T80_MCode.vhd:1363:33  */
  assign n4514_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1363:33  */
  assign n4515_o = n4512_o | n4514_o;
  /* T80_MCode.vhd:1363:44  */
  assign n4517_o = ir == 8'b00011001;
  /* T80_MCode.vhd:1363:44  */
  assign n4518_o = n4515_o | n4517_o;
  /* T80_MCode.vhd:1363:55  */
  assign n4520_o = ir == 8'b00011010;
  /* T80_MCode.vhd:1363:55  */
  assign n4521_o = n4518_o | n4520_o;
  /* T80_MCode.vhd:1363:66  */
  assign n4523_o = ir == 8'b00011011;
  /* T80_MCode.vhd:1363:66  */
  assign n4524_o = n4521_o | n4523_o;
  /* T80_MCode.vhd:1363:77  */
  assign n4526_o = ir == 8'b00011100;
  /* T80_MCode.vhd:1363:77  */
  assign n4527_o = n4524_o | n4526_o;
  /* T80_MCode.vhd:1363:88  */
  assign n4529_o = ir == 8'b00011101;
  /* T80_MCode.vhd:1363:88  */
  assign n4530_o = n4527_o | n4529_o;
  /* T80_MCode.vhd:1363:99  */
  assign n4532_o = ir == 8'b00011111;
  /* T80_MCode.vhd:1363:99  */
  assign n4533_o = n4530_o | n4532_o;
  /* T80_MCode.vhd:1364:33  */
  assign n4535_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1364:33  */
  assign n4536_o = n4533_o | n4535_o;
  /* T80_MCode.vhd:1364:44  */
  assign n4538_o = ir == 8'b00100001;
  /* T80_MCode.vhd:1364:44  */
  assign n4539_o = n4536_o | n4538_o;
  /* T80_MCode.vhd:1364:55  */
  assign n4541_o = ir == 8'b00100010;
  /* T80_MCode.vhd:1364:55  */
  assign n4542_o = n4539_o | n4541_o;
  /* T80_MCode.vhd:1364:66  */
  assign n4544_o = ir == 8'b00100011;
  /* T80_MCode.vhd:1364:66  */
  assign n4545_o = n4542_o | n4544_o;
  /* T80_MCode.vhd:1364:77  */
  assign n4547_o = ir == 8'b00100100;
  /* T80_MCode.vhd:1364:77  */
  assign n4548_o = n4545_o | n4547_o;
  /* T80_MCode.vhd:1364:88  */
  assign n4550_o = ir == 8'b00100101;
  /* T80_MCode.vhd:1364:88  */
  assign n4551_o = n4548_o | n4550_o;
  /* T80_MCode.vhd:1364:99  */
  assign n4553_o = ir == 8'b00100111;
  /* T80_MCode.vhd:1364:99  */
  assign n4554_o = n4551_o | n4553_o;
  /* T80_MCode.vhd:1365:33  */
  assign n4556_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1365:33  */
  assign n4557_o = n4554_o | n4556_o;
  /* T80_MCode.vhd:1365:44  */
  assign n4559_o = ir == 8'b00101001;
  /* T80_MCode.vhd:1365:44  */
  assign n4560_o = n4557_o | n4559_o;
  /* T80_MCode.vhd:1365:55  */
  assign n4562_o = ir == 8'b00101010;
  /* T80_MCode.vhd:1365:55  */
  assign n4563_o = n4560_o | n4562_o;
  /* T80_MCode.vhd:1365:66  */
  assign n4565_o = ir == 8'b00101011;
  /* T80_MCode.vhd:1365:66  */
  assign n4566_o = n4563_o | n4565_o;
  /* T80_MCode.vhd:1365:77  */
  assign n4568_o = ir == 8'b00101100;
  /* T80_MCode.vhd:1365:77  */
  assign n4569_o = n4566_o | n4568_o;
  /* T80_MCode.vhd:1365:88  */
  assign n4571_o = ir == 8'b00101101;
  /* T80_MCode.vhd:1365:88  */
  assign n4572_o = n4569_o | n4571_o;
  /* T80_MCode.vhd:1365:99  */
  assign n4574_o = ir == 8'b00101111;
  /* T80_MCode.vhd:1365:99  */
  assign n4575_o = n4572_o | n4574_o;
  /* T80_MCode.vhd:1366:33  */
  assign n4577_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1366:33  */
  assign n4578_o = n4575_o | n4577_o;
  /* T80_MCode.vhd:1366:44  */
  assign n4580_o = ir == 8'b00110001;
  /* T80_MCode.vhd:1366:44  */
  assign n4581_o = n4578_o | n4580_o;
  /* T80_MCode.vhd:1366:55  */
  assign n4583_o = ir == 8'b00110010;
  /* T80_MCode.vhd:1366:55  */
  assign n4584_o = n4581_o | n4583_o;
  /* T80_MCode.vhd:1366:66  */
  assign n4586_o = ir == 8'b00110011;
  /* T80_MCode.vhd:1366:66  */
  assign n4587_o = n4584_o | n4586_o;
  /* T80_MCode.vhd:1366:77  */
  assign n4589_o = ir == 8'b00110100;
  /* T80_MCode.vhd:1366:77  */
  assign n4590_o = n4587_o | n4589_o;
  /* T80_MCode.vhd:1366:88  */
  assign n4592_o = ir == 8'b00110101;
  /* T80_MCode.vhd:1366:88  */
  assign n4593_o = n4590_o | n4592_o;
  /* T80_MCode.vhd:1366:99  */
  assign n4595_o = ir == 8'b00110111;
  /* T80_MCode.vhd:1366:99  */
  assign n4596_o = n4593_o | n4595_o;
  /* T80_MCode.vhd:1367:33  */
  assign n4598_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1367:33  */
  assign n4599_o = n4596_o | n4598_o;
  /* T80_MCode.vhd:1367:44  */
  assign n4601_o = ir == 8'b00111001;
  /* T80_MCode.vhd:1367:44  */
  assign n4602_o = n4599_o | n4601_o;
  /* T80_MCode.vhd:1367:55  */
  assign n4604_o = ir == 8'b00111010;
  /* T80_MCode.vhd:1367:55  */
  assign n4605_o = n4602_o | n4604_o;
  /* T80_MCode.vhd:1367:66  */
  assign n4607_o = ir == 8'b00111011;
  /* T80_MCode.vhd:1367:66  */
  assign n4608_o = n4605_o | n4607_o;
  /* T80_MCode.vhd:1367:77  */
  assign n4610_o = ir == 8'b00111100;
  /* T80_MCode.vhd:1367:77  */
  assign n4611_o = n4608_o | n4610_o;
  /* T80_MCode.vhd:1367:88  */
  assign n4613_o = ir == 8'b00111101;
  /* T80_MCode.vhd:1367:88  */
  assign n4614_o = n4611_o | n4613_o;
  /* T80_MCode.vhd:1367:99  */
  assign n4616_o = ir == 8'b00111111;
  /* T80_MCode.vhd:1367:99  */
  assign n4617_o = n4614_o | n4616_o;
  /* T80_MCode.vhd:1411:38  */
  assign n4618_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1412:33  */
  assign n4620_o = n4618_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1412:40  */
  assign n4622_o = n4618_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1412:40  */
  assign n4623_o = n4620_o | n4622_o;
  /* T80_MCode.vhd:1414:33  */
  assign n4625_o = n4618_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1420:33  */
  assign n4627_o = n4618_o == 31'b0000000000000000000000000000011;
  assign n4628_o = {n4627_o, n4625_o, n4623_o};
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4628_o)
      3'b100: n4630_o = n2200_o;
      3'b010: n4630_o = 3'b100;
      3'b001: n4630_o = n2200_o;
      default: n4630_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4628_o)
      3'b100: n4633_o = 1'b0;
      3'b010: n4633_o = 1'b1;
      3'b001: n4633_o = 1'b0;
      default: n4633_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4628_o)
      3'b100: n4635_o = n2203_o;
      3'b010: n4635_o = 4'b1000;
      3'b001: n4635_o = n2203_o;
      default: n4635_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4628_o)
      3'b100: n4638_o = 1'b0;
      3'b010: n4638_o = 1'b1;
      3'b001: n4638_o = 1'b0;
      default: n4638_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4628_o)
      3'b100: n4642_o = 3'b111;
      3'b010: n4642_o = 3'b010;
      3'b001: n4642_o = 3'b010;
      default: n4642_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4628_o)
      3'b100: n4645_o = 1'b1;
      3'b010: n4645_o = 1'b0;
      3'b001: n4645_o = 1'b0;
      default: n4645_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1401:25  */
  assign n4647_o = ir == 8'b00000110;
  /* T80_MCode.vhd:1401:40  */
  assign n4649_o = ir == 8'b00010110;
  /* T80_MCode.vhd:1401:40  */
  assign n4650_o = n4647_o | n4649_o;
  /* T80_MCode.vhd:1401:51  */
  assign n4652_o = ir == 8'b00001110;
  /* T80_MCode.vhd:1401:51  */
  assign n4653_o = n4650_o | n4652_o;
  /* T80_MCode.vhd:1401:62  */
  assign n4655_o = ir == 8'b00011110;
  /* T80_MCode.vhd:1401:62  */
  assign n4656_o = n4653_o | n4655_o;
  /* T80_MCode.vhd:1401:73  */
  assign n4658_o = ir == 8'b00101110;
  /* T80_MCode.vhd:1401:73  */
  assign n4659_o = n4656_o | n4658_o;
  /* T80_MCode.vhd:1401:84  */
  assign n4661_o = ir == 8'b00111110;
  /* T80_MCode.vhd:1401:84  */
  assign n4662_o = n4659_o | n4661_o;
  /* T80_MCode.vhd:1401:95  */
  assign n4664_o = ir == 8'b00100110;
  /* T80_MCode.vhd:1401:95  */
  assign n4665_o = n4662_o | n4664_o;
  /* T80_MCode.vhd:1401:106  */
  assign n4667_o = ir == 8'b00110110;
  /* T80_MCode.vhd:1401:106  */
  assign n4668_o = n4665_o | n4667_o;
  /* T80_MCode.vhd:1433:44  */
  assign n4670_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1434:51  */
  assign n4672_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1435:72  */
  assign n4673_o = ir[2:0];
  /* T80_MCode.vhd:1433:33  */
  assign n4674_o = n4697_o ? n4673_o : n4396_o;
  /* T80_MCode.vhd:1434:41  */
  assign n4676_o = n4672_o ? 4'b1001 : n2203_o;
  /* T80_MCode.vhd:1442:46  */
  assign n4677_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1443:41  */
  assign n4679_o = n4677_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1443:48  */
  assign n4681_o = n4677_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1443:48  */
  assign n4682_o = n4679_o | n4681_o;
  /* T80_MCode.vhd:1445:41  */
  assign n4684_o = n4677_o == 31'b0000000000000000000000000000010;
  assign n4685_o = {n4684_o, n4682_o};
  /* T80_MCode.vhd:1442:41  */
  always @*
    case (n4685_o)
      2'b10: n4687_o = 3'b100;
      2'b01: n4687_o = n2200_o;
      default: n4687_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1442:41  */
  always @*
    case (n4685_o)
      2'b10: n4689_o = 4'b1001;
      2'b01: n4689_o = n2203_o;
      default: n4689_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1442:41  */
  always @*
    case (n4685_o)
      2'b10: n4692_o = 3'b111;
      2'b01: n4692_o = 3'b010;
      default: n4692_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1433:33  */
  assign n4695_o = n4670_o ? 3'b001 : 3'b010;
  /* T80_MCode.vhd:1433:33  */
  assign n4696_o = n4670_o ? n2200_o : n4687_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4697_o = n4670_o & n4672_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4698_o = n4670_o ? n4676_o : n4689_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4700_o = n4670_o ? 3'b111 : n4692_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4703_o = n4670_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1424:25  */
  assign n4705_o = ir == 8'b01000000;
  /* T80_MCode.vhd:1424:40  */
  assign n4707_o = ir == 8'b01000001;
  /* T80_MCode.vhd:1424:40  */
  assign n4708_o = n4705_o | n4707_o;
  /* T80_MCode.vhd:1424:51  */
  assign n4710_o = ir == 8'b01000010;
  /* T80_MCode.vhd:1424:51  */
  assign n4711_o = n4708_o | n4710_o;
  /* T80_MCode.vhd:1424:62  */
  assign n4713_o = ir == 8'b01000011;
  /* T80_MCode.vhd:1424:62  */
  assign n4714_o = n4711_o | n4713_o;
  /* T80_MCode.vhd:1424:73  */
  assign n4716_o = ir == 8'b01000100;
  /* T80_MCode.vhd:1424:73  */
  assign n4717_o = n4714_o | n4716_o;
  /* T80_MCode.vhd:1424:84  */
  assign n4719_o = ir == 8'b01000101;
  /* T80_MCode.vhd:1424:84  */
  assign n4720_o = n4717_o | n4719_o;
  /* T80_MCode.vhd:1424:95  */
  assign n4722_o = ir == 8'b01000111;
  /* T80_MCode.vhd:1424:95  */
  assign n4723_o = n4720_o | n4722_o;
  /* T80_MCode.vhd:1425:33  */
  assign n4725_o = ir == 8'b01001000;
  /* T80_MCode.vhd:1425:33  */
  assign n4726_o = n4723_o | n4725_o;
  /* T80_MCode.vhd:1425:44  */
  assign n4728_o = ir == 8'b01001001;
  /* T80_MCode.vhd:1425:44  */
  assign n4729_o = n4726_o | n4728_o;
  /* T80_MCode.vhd:1425:55  */
  assign n4731_o = ir == 8'b01001010;
  /* T80_MCode.vhd:1425:55  */
  assign n4732_o = n4729_o | n4731_o;
  /* T80_MCode.vhd:1425:66  */
  assign n4734_o = ir == 8'b01001011;
  /* T80_MCode.vhd:1425:66  */
  assign n4735_o = n4732_o | n4734_o;
  /* T80_MCode.vhd:1425:77  */
  assign n4737_o = ir == 8'b01001100;
  /* T80_MCode.vhd:1425:77  */
  assign n4738_o = n4735_o | n4737_o;
  /* T80_MCode.vhd:1425:88  */
  assign n4740_o = ir == 8'b01001101;
  /* T80_MCode.vhd:1425:88  */
  assign n4741_o = n4738_o | n4740_o;
  /* T80_MCode.vhd:1425:99  */
  assign n4743_o = ir == 8'b01001111;
  /* T80_MCode.vhd:1425:99  */
  assign n4744_o = n4741_o | n4743_o;
  /* T80_MCode.vhd:1426:33  */
  assign n4746_o = ir == 8'b01010000;
  /* T80_MCode.vhd:1426:33  */
  assign n4747_o = n4744_o | n4746_o;
  /* T80_MCode.vhd:1426:44  */
  assign n4749_o = ir == 8'b01010001;
  /* T80_MCode.vhd:1426:44  */
  assign n4750_o = n4747_o | n4749_o;
  /* T80_MCode.vhd:1426:55  */
  assign n4752_o = ir == 8'b01010010;
  /* T80_MCode.vhd:1426:55  */
  assign n4753_o = n4750_o | n4752_o;
  /* T80_MCode.vhd:1426:66  */
  assign n4755_o = ir == 8'b01010011;
  /* T80_MCode.vhd:1426:66  */
  assign n4756_o = n4753_o | n4755_o;
  /* T80_MCode.vhd:1426:77  */
  assign n4758_o = ir == 8'b01010100;
  /* T80_MCode.vhd:1426:77  */
  assign n4759_o = n4756_o | n4758_o;
  /* T80_MCode.vhd:1426:88  */
  assign n4761_o = ir == 8'b01010101;
  /* T80_MCode.vhd:1426:88  */
  assign n4762_o = n4759_o | n4761_o;
  /* T80_MCode.vhd:1426:99  */
  assign n4764_o = ir == 8'b01010111;
  /* T80_MCode.vhd:1426:99  */
  assign n4765_o = n4762_o | n4764_o;
  /* T80_MCode.vhd:1427:33  */
  assign n4767_o = ir == 8'b01011000;
  /* T80_MCode.vhd:1427:33  */
  assign n4768_o = n4765_o | n4767_o;
  /* T80_MCode.vhd:1427:44  */
  assign n4770_o = ir == 8'b01011001;
  /* T80_MCode.vhd:1427:44  */
  assign n4771_o = n4768_o | n4770_o;
  /* T80_MCode.vhd:1427:55  */
  assign n4773_o = ir == 8'b01011010;
  /* T80_MCode.vhd:1427:55  */
  assign n4774_o = n4771_o | n4773_o;
  /* T80_MCode.vhd:1427:66  */
  assign n4776_o = ir == 8'b01011011;
  /* T80_MCode.vhd:1427:66  */
  assign n4777_o = n4774_o | n4776_o;
  /* T80_MCode.vhd:1427:77  */
  assign n4779_o = ir == 8'b01011100;
  /* T80_MCode.vhd:1427:77  */
  assign n4780_o = n4777_o | n4779_o;
  /* T80_MCode.vhd:1427:88  */
  assign n4782_o = ir == 8'b01011101;
  /* T80_MCode.vhd:1427:88  */
  assign n4783_o = n4780_o | n4782_o;
  /* T80_MCode.vhd:1427:99  */
  assign n4785_o = ir == 8'b01011111;
  /* T80_MCode.vhd:1427:99  */
  assign n4786_o = n4783_o | n4785_o;
  /* T80_MCode.vhd:1428:33  */
  assign n4788_o = ir == 8'b01100000;
  /* T80_MCode.vhd:1428:33  */
  assign n4789_o = n4786_o | n4788_o;
  /* T80_MCode.vhd:1428:44  */
  assign n4791_o = ir == 8'b01100001;
  /* T80_MCode.vhd:1428:44  */
  assign n4792_o = n4789_o | n4791_o;
  /* T80_MCode.vhd:1428:55  */
  assign n4794_o = ir == 8'b01100010;
  /* T80_MCode.vhd:1428:55  */
  assign n4795_o = n4792_o | n4794_o;
  /* T80_MCode.vhd:1428:66  */
  assign n4797_o = ir == 8'b01100011;
  /* T80_MCode.vhd:1428:66  */
  assign n4798_o = n4795_o | n4797_o;
  /* T80_MCode.vhd:1428:77  */
  assign n4800_o = ir == 8'b01100100;
  /* T80_MCode.vhd:1428:77  */
  assign n4801_o = n4798_o | n4800_o;
  /* T80_MCode.vhd:1428:88  */
  assign n4803_o = ir == 8'b01100101;
  /* T80_MCode.vhd:1428:88  */
  assign n4804_o = n4801_o | n4803_o;
  /* T80_MCode.vhd:1428:99  */
  assign n4806_o = ir == 8'b01100111;
  /* T80_MCode.vhd:1428:99  */
  assign n4807_o = n4804_o | n4806_o;
  /* T80_MCode.vhd:1429:33  */
  assign n4809_o = ir == 8'b01101000;
  /* T80_MCode.vhd:1429:33  */
  assign n4810_o = n4807_o | n4809_o;
  /* T80_MCode.vhd:1429:44  */
  assign n4812_o = ir == 8'b01101001;
  /* T80_MCode.vhd:1429:44  */
  assign n4813_o = n4810_o | n4812_o;
  /* T80_MCode.vhd:1429:55  */
  assign n4815_o = ir == 8'b01101010;
  /* T80_MCode.vhd:1429:55  */
  assign n4816_o = n4813_o | n4815_o;
  /* T80_MCode.vhd:1429:66  */
  assign n4818_o = ir == 8'b01101011;
  /* T80_MCode.vhd:1429:66  */
  assign n4819_o = n4816_o | n4818_o;
  /* T80_MCode.vhd:1429:77  */
  assign n4821_o = ir == 8'b01101100;
  /* T80_MCode.vhd:1429:77  */
  assign n4822_o = n4819_o | n4821_o;
  /* T80_MCode.vhd:1429:88  */
  assign n4824_o = ir == 8'b01101101;
  /* T80_MCode.vhd:1429:88  */
  assign n4825_o = n4822_o | n4824_o;
  /* T80_MCode.vhd:1429:99  */
  assign n4827_o = ir == 8'b01101111;
  /* T80_MCode.vhd:1429:99  */
  assign n4828_o = n4825_o | n4827_o;
  /* T80_MCode.vhd:1430:33  */
  assign n4830_o = ir == 8'b01110000;
  /* T80_MCode.vhd:1430:33  */
  assign n4831_o = n4828_o | n4830_o;
  /* T80_MCode.vhd:1430:44  */
  assign n4833_o = ir == 8'b01110001;
  /* T80_MCode.vhd:1430:44  */
  assign n4834_o = n4831_o | n4833_o;
  /* T80_MCode.vhd:1430:55  */
  assign n4836_o = ir == 8'b01110010;
  /* T80_MCode.vhd:1430:55  */
  assign n4837_o = n4834_o | n4836_o;
  /* T80_MCode.vhd:1430:66  */
  assign n4839_o = ir == 8'b01110011;
  /* T80_MCode.vhd:1430:66  */
  assign n4840_o = n4837_o | n4839_o;
  /* T80_MCode.vhd:1430:77  */
  assign n4842_o = ir == 8'b01110100;
  /* T80_MCode.vhd:1430:77  */
  assign n4843_o = n4840_o | n4842_o;
  /* T80_MCode.vhd:1430:88  */
  assign n4845_o = ir == 8'b01110101;
  /* T80_MCode.vhd:1430:88  */
  assign n4846_o = n4843_o | n4845_o;
  /* T80_MCode.vhd:1430:99  */
  assign n4848_o = ir == 8'b01110111;
  /* T80_MCode.vhd:1430:99  */
  assign n4849_o = n4846_o | n4848_o;
  /* T80_MCode.vhd:1431:33  */
  assign n4851_o = ir == 8'b01111000;
  /* T80_MCode.vhd:1431:33  */
  assign n4852_o = n4849_o | n4851_o;
  /* T80_MCode.vhd:1431:44  */
  assign n4854_o = ir == 8'b01111001;
  /* T80_MCode.vhd:1431:44  */
  assign n4855_o = n4852_o | n4854_o;
  /* T80_MCode.vhd:1431:55  */
  assign n4857_o = ir == 8'b01111010;
  /* T80_MCode.vhd:1431:55  */
  assign n4858_o = n4855_o | n4857_o;
  /* T80_MCode.vhd:1431:66  */
  assign n4860_o = ir == 8'b01111011;
  /* T80_MCode.vhd:1431:66  */
  assign n4861_o = n4858_o | n4860_o;
  /* T80_MCode.vhd:1431:77  */
  assign n4863_o = ir == 8'b01111100;
  /* T80_MCode.vhd:1431:77  */
  assign n4864_o = n4861_o | n4863_o;
  /* T80_MCode.vhd:1431:88  */
  assign n4866_o = ir == 8'b01111101;
  /* T80_MCode.vhd:1431:88  */
  assign n4867_o = n4864_o | n4866_o;
  /* T80_MCode.vhd:1431:99  */
  assign n4869_o = ir == 8'b01111111;
  /* T80_MCode.vhd:1431:99  */
  assign n4870_o = n4867_o | n4869_o;
  /* T80_MCode.vhd:1455:38  */
  assign n4871_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1456:33  */
  assign n4873_o = n4871_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1456:40  */
  assign n4875_o = n4871_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1456:40  */
  assign n4876_o = n4873_o | n4875_o;
  /* T80_MCode.vhd:1458:33  */
  assign n4878_o = n4871_o == 31'b0000000000000000000000000000010;
  assign n4879_o = {n4878_o, n4876_o};
  /* T80_MCode.vhd:1455:33  */
  always @*
    case (n4879_o)
      2'b10: n4881_o = 3'b100;
      2'b01: n4881_o = n2200_o;
      default: n4881_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1455:33  */
  always @*
    case (n4879_o)
      2'b10: n4883_o = 4'b1001;
      2'b01: n4883_o = n2203_o;
      default: n4883_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1455:33  */
  always @*
    case (n4879_o)
      2'b10: n4886_o = 3'b111;
      2'b01: n4886_o = 3'b010;
      default: n4886_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1452:25  */
  assign n4888_o = ir == 8'b01000110;
  /* T80_MCode.vhd:1452:40  */
  assign n4890_o = ir == 8'b01001110;
  /* T80_MCode.vhd:1452:40  */
  assign n4891_o = n4888_o | n4890_o;
  /* T80_MCode.vhd:1452:51  */
  assign n4893_o = ir == 8'b01010110;
  /* T80_MCode.vhd:1452:51  */
  assign n4894_o = n4891_o | n4893_o;
  /* T80_MCode.vhd:1452:62  */
  assign n4896_o = ir == 8'b01011110;
  /* T80_MCode.vhd:1452:62  */
  assign n4897_o = n4894_o | n4896_o;
  /* T80_MCode.vhd:1452:73  */
  assign n4899_o = ir == 8'b01100110;
  /* T80_MCode.vhd:1452:73  */
  assign n4900_o = n4897_o | n4899_o;
  /* T80_MCode.vhd:1452:84  */
  assign n4902_o = ir == 8'b01101110;
  /* T80_MCode.vhd:1452:84  */
  assign n4903_o = n4900_o | n4902_o;
  /* T80_MCode.vhd:1452:95  */
  assign n4905_o = ir == 8'b01110110;
  /* T80_MCode.vhd:1452:95  */
  assign n4906_o = n4903_o | n4905_o;
  /* T80_MCode.vhd:1452:106  */
  assign n4908_o = ir == 8'b01111110;
  /* T80_MCode.vhd:1452:106  */
  assign n4909_o = n4906_o | n4908_o;
  /* T80_MCode.vhd:1472:44  */
  assign n4911_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1473:51  */
  assign n4913_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1473:41  */
  assign n4916_o = n4913_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1473:41  */
  assign n4918_o = n4913_o ? 4'b1010 : n2203_o;
  /* T80_MCode.vhd:1473:41  */
  assign n4921_o = n4913_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1482:46  */
  assign n4922_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1483:41  */
  assign n4924_o = n4922_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1483:48  */
  assign n4926_o = n4922_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1483:48  */
  assign n4927_o = n4924_o | n4926_o;
  /* T80_MCode.vhd:1485:41  */
  assign n4929_o = n4922_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1491:41  */
  assign n4931_o = n4922_o == 31'b0000000000000000000000000000011;
  assign n4932_o = {n4931_o, n4929_o, n4927_o};
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4932_o)
      3'b100: n4934_o = n2200_o;
      3'b010: n4934_o = 3'b100;
      3'b001: n4934_o = n2200_o;
      default: n4934_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4932_o)
      3'b100: n4937_o = 1'b0;
      3'b010: n4937_o = 1'b1;
      3'b001: n4937_o = 1'b0;
      default: n4937_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4932_o)
      3'b100: n4939_o = n2203_o;
      3'b010: n4939_o = 4'b1010;
      3'b001: n4939_o = n2203_o;
      default: n4939_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4932_o)
      3'b100: n4942_o = 1'b0;
      3'b010: n4942_o = 1'b1;
      3'b001: n4942_o = 1'b0;
      default: n4942_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4932_o)
      3'b100: n4946_o = 3'b111;
      3'b010: n4946_o = 3'b010;
      3'b001: n4946_o = 3'b010;
      default: n4946_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4932_o)
      3'b100: n4949_o = 1'b1;
      3'b010: n4949_o = 1'b0;
      3'b001: n4949_o = 1'b0;
      default: n4949_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1472:33  */
  assign n4952_o = n4911_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1472:33  */
  assign n4953_o = n4911_o ? n2200_o : n4934_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4954_o = n4911_o ? n4916_o : n4937_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4955_o = n4911_o ? n4918_o : n4939_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4956_o = n4911_o ? n4921_o : n4942_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4958_o = n4911_o ? 3'b111 : n4946_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4960_o = n4911_o ? 1'b0 : n4949_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4963_o = n4911_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1463:25  */
  assign n4965_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1463:40  */
  assign n4967_o = ir == 8'b11000001;
  /* T80_MCode.vhd:1463:40  */
  assign n4968_o = n4965_o | n4967_o;
  /* T80_MCode.vhd:1463:51  */
  assign n4970_o = ir == 8'b11000010;
  /* T80_MCode.vhd:1463:51  */
  assign n4971_o = n4968_o | n4970_o;
  /* T80_MCode.vhd:1463:62  */
  assign n4973_o = ir == 8'b11000011;
  /* T80_MCode.vhd:1463:62  */
  assign n4974_o = n4971_o | n4973_o;
  /* T80_MCode.vhd:1463:73  */
  assign n4976_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1463:73  */
  assign n4977_o = n4974_o | n4976_o;
  /* T80_MCode.vhd:1463:84  */
  assign n4979_o = ir == 8'b11000101;
  /* T80_MCode.vhd:1463:84  */
  assign n4980_o = n4977_o | n4979_o;
  /* T80_MCode.vhd:1463:95  */
  assign n4982_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1463:95  */
  assign n4983_o = n4980_o | n4982_o;
  /* T80_MCode.vhd:1464:33  */
  assign n4985_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1464:33  */
  assign n4986_o = n4983_o | n4985_o;
  /* T80_MCode.vhd:1464:44  */
  assign n4988_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1464:44  */
  assign n4989_o = n4986_o | n4988_o;
  /* T80_MCode.vhd:1464:55  */
  assign n4991_o = ir == 8'b11001010;
  /* T80_MCode.vhd:1464:55  */
  assign n4992_o = n4989_o | n4991_o;
  /* T80_MCode.vhd:1464:66  */
  assign n4994_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1464:66  */
  assign n4995_o = n4992_o | n4994_o;
  /* T80_MCode.vhd:1464:77  */
  assign n4997_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1464:77  */
  assign n4998_o = n4995_o | n4997_o;
  /* T80_MCode.vhd:1464:88  */
  assign n5000_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1464:88  */
  assign n5001_o = n4998_o | n5000_o;
  /* T80_MCode.vhd:1464:99  */
  assign n5003_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1464:99  */
  assign n5004_o = n5001_o | n5003_o;
  /* T80_MCode.vhd:1465:33  */
  assign n5006_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1465:33  */
  assign n5007_o = n5004_o | n5006_o;
  /* T80_MCode.vhd:1465:44  */
  assign n5009_o = ir == 8'b11010001;
  /* T80_MCode.vhd:1465:44  */
  assign n5010_o = n5007_o | n5009_o;
  /* T80_MCode.vhd:1465:55  */
  assign n5012_o = ir == 8'b11010010;
  /* T80_MCode.vhd:1465:55  */
  assign n5013_o = n5010_o | n5012_o;
  /* T80_MCode.vhd:1465:66  */
  assign n5015_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1465:66  */
  assign n5016_o = n5013_o | n5015_o;
  /* T80_MCode.vhd:1465:77  */
  assign n5018_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1465:77  */
  assign n5019_o = n5016_o | n5018_o;
  /* T80_MCode.vhd:1465:88  */
  assign n5021_o = ir == 8'b11010101;
  /* T80_MCode.vhd:1465:88  */
  assign n5022_o = n5019_o | n5021_o;
  /* T80_MCode.vhd:1465:99  */
  assign n5024_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1465:99  */
  assign n5025_o = n5022_o | n5024_o;
  /* T80_MCode.vhd:1466:33  */
  assign n5027_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1466:33  */
  assign n5028_o = n5025_o | n5027_o;
  /* T80_MCode.vhd:1466:44  */
  assign n5030_o = ir == 8'b11011001;
  /* T80_MCode.vhd:1466:44  */
  assign n5031_o = n5028_o | n5030_o;
  /* T80_MCode.vhd:1466:55  */
  assign n5033_o = ir == 8'b11011010;
  /* T80_MCode.vhd:1466:55  */
  assign n5034_o = n5031_o | n5033_o;
  /* T80_MCode.vhd:1466:66  */
  assign n5036_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1466:66  */
  assign n5037_o = n5034_o | n5036_o;
  /* T80_MCode.vhd:1466:77  */
  assign n5039_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1466:77  */
  assign n5040_o = n5037_o | n5039_o;
  /* T80_MCode.vhd:1466:88  */
  assign n5042_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1466:88  */
  assign n5043_o = n5040_o | n5042_o;
  /* T80_MCode.vhd:1466:99  */
  assign n5045_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1466:99  */
  assign n5046_o = n5043_o | n5045_o;
  /* T80_MCode.vhd:1467:33  */
  assign n5048_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1467:33  */
  assign n5049_o = n5046_o | n5048_o;
  /* T80_MCode.vhd:1467:44  */
  assign n5051_o = ir == 8'b11100001;
  /* T80_MCode.vhd:1467:44  */
  assign n5052_o = n5049_o | n5051_o;
  /* T80_MCode.vhd:1467:55  */
  assign n5054_o = ir == 8'b11100010;
  /* T80_MCode.vhd:1467:55  */
  assign n5055_o = n5052_o | n5054_o;
  /* T80_MCode.vhd:1467:66  */
  assign n5057_o = ir == 8'b11100011;
  /* T80_MCode.vhd:1467:66  */
  assign n5058_o = n5055_o | n5057_o;
  /* T80_MCode.vhd:1467:77  */
  assign n5060_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1467:77  */
  assign n5061_o = n5058_o | n5060_o;
  /* T80_MCode.vhd:1467:88  */
  assign n5063_o = ir == 8'b11100101;
  /* T80_MCode.vhd:1467:88  */
  assign n5064_o = n5061_o | n5063_o;
  /* T80_MCode.vhd:1467:99  */
  assign n5066_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1467:99  */
  assign n5067_o = n5064_o | n5066_o;
  /* T80_MCode.vhd:1468:33  */
  assign n5069_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1468:33  */
  assign n5070_o = n5067_o | n5069_o;
  /* T80_MCode.vhd:1468:44  */
  assign n5072_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1468:44  */
  assign n5073_o = n5070_o | n5072_o;
  /* T80_MCode.vhd:1468:55  */
  assign n5075_o = ir == 8'b11101010;
  /* T80_MCode.vhd:1468:55  */
  assign n5076_o = n5073_o | n5075_o;
  /* T80_MCode.vhd:1468:66  */
  assign n5078_o = ir == 8'b11101011;
  /* T80_MCode.vhd:1468:66  */
  assign n5079_o = n5076_o | n5078_o;
  /* T80_MCode.vhd:1468:77  */
  assign n5081_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1468:77  */
  assign n5082_o = n5079_o | n5081_o;
  /* T80_MCode.vhd:1468:88  */
  assign n5084_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1468:88  */
  assign n5085_o = n5082_o | n5084_o;
  /* T80_MCode.vhd:1468:99  */
  assign n5087_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1468:99  */
  assign n5088_o = n5085_o | n5087_o;
  /* T80_MCode.vhd:1469:33  */
  assign n5090_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1469:33  */
  assign n5091_o = n5088_o | n5090_o;
  /* T80_MCode.vhd:1469:44  */
  assign n5093_o = ir == 8'b11110001;
  /* T80_MCode.vhd:1469:44  */
  assign n5094_o = n5091_o | n5093_o;
  /* T80_MCode.vhd:1469:55  */
  assign n5096_o = ir == 8'b11110010;
  /* T80_MCode.vhd:1469:55  */
  assign n5097_o = n5094_o | n5096_o;
  /* T80_MCode.vhd:1469:66  */
  assign n5099_o = ir == 8'b11110011;
  /* T80_MCode.vhd:1469:66  */
  assign n5100_o = n5097_o | n5099_o;
  /* T80_MCode.vhd:1469:77  */
  assign n5102_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1469:77  */
  assign n5103_o = n5100_o | n5102_o;
  /* T80_MCode.vhd:1469:88  */
  assign n5105_o = ir == 8'b11110101;
  /* T80_MCode.vhd:1469:88  */
  assign n5106_o = n5103_o | n5105_o;
  /* T80_MCode.vhd:1469:99  */
  assign n5108_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1469:99  */
  assign n5109_o = n5106_o | n5108_o;
  /* T80_MCode.vhd:1470:33  */
  assign n5111_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1470:33  */
  assign n5112_o = n5109_o | n5111_o;
  /* T80_MCode.vhd:1470:44  */
  assign n5114_o = ir == 8'b11111001;
  /* T80_MCode.vhd:1470:44  */
  assign n5115_o = n5112_o | n5114_o;
  /* T80_MCode.vhd:1470:55  */
  assign n5117_o = ir == 8'b11111010;
  /* T80_MCode.vhd:1470:55  */
  assign n5118_o = n5115_o | n5117_o;
  /* T80_MCode.vhd:1470:66  */
  assign n5120_o = ir == 8'b11111011;
  /* T80_MCode.vhd:1470:66  */
  assign n5121_o = n5118_o | n5120_o;
  /* T80_MCode.vhd:1470:77  */
  assign n5123_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1470:77  */
  assign n5124_o = n5121_o | n5123_o;
  /* T80_MCode.vhd:1470:88  */
  assign n5126_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1470:88  */
  assign n5127_o = n5124_o | n5126_o;
  /* T80_MCode.vhd:1470:99  */
  assign n5129_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1470:99  */
  assign n5130_o = n5127_o | n5129_o;
  /* T80_MCode.vhd:1500:38  */
  assign n5131_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1501:33  */
  assign n5133_o = n5131_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1501:40  */
  assign n5135_o = n5131_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1501:40  */
  assign n5136_o = n5133_o | n5135_o;
  /* T80_MCode.vhd:1503:33  */
  assign n5138_o = n5131_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1509:33  */
  assign n5140_o = n5131_o == 31'b0000000000000000000000000000011;
  assign n5141_o = {n5140_o, n5138_o, n5136_o};
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n5141_o)
      3'b100: n5143_o = n2200_o;
      3'b010: n5143_o = 3'b100;
      3'b001: n5143_o = n2200_o;
      default: n5143_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n5141_o)
      3'b100: n5146_o = 1'b0;
      3'b010: n5146_o = 1'b1;
      3'b001: n5146_o = 1'b0;
      default: n5146_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n5141_o)
      3'b100: n5148_o = n2203_o;
      3'b010: n5148_o = 4'b1010;
      3'b001: n5148_o = n2203_o;
      default: n5148_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n5141_o)
      3'b100: n5151_o = 1'b0;
      3'b010: n5151_o = 1'b1;
      3'b001: n5151_o = 1'b0;
      default: n5151_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n5141_o)
      3'b100: n5155_o = 3'b111;
      3'b010: n5155_o = 3'b010;
      3'b001: n5155_o = 3'b010;
      default: n5155_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n5141_o)
      3'b100: n5158_o = 1'b1;
      3'b010: n5158_o = 1'b0;
      3'b001: n5158_o = 1'b0;
      default: n5158_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1497:25  */
  assign n5160_o = ir == 8'b11000110;
  /* T80_MCode.vhd:1497:40  */
  assign n5162_o = ir == 8'b11001110;
  /* T80_MCode.vhd:1497:40  */
  assign n5163_o = n5160_o | n5162_o;
  /* T80_MCode.vhd:1497:51  */
  assign n5165_o = ir == 8'b11010110;
  /* T80_MCode.vhd:1497:51  */
  assign n5166_o = n5163_o | n5165_o;
  /* T80_MCode.vhd:1497:62  */
  assign n5168_o = ir == 8'b11011110;
  /* T80_MCode.vhd:1497:62  */
  assign n5169_o = n5166_o | n5168_o;
  /* T80_MCode.vhd:1497:73  */
  assign n5171_o = ir == 8'b11100110;
  /* T80_MCode.vhd:1497:73  */
  assign n5172_o = n5169_o | n5171_o;
  /* T80_MCode.vhd:1497:84  */
  assign n5174_o = ir == 8'b11101110;
  /* T80_MCode.vhd:1497:84  */
  assign n5175_o = n5172_o | n5174_o;
  /* T80_MCode.vhd:1497:95  */
  assign n5177_o = ir == 8'b11110110;
  /* T80_MCode.vhd:1497:95  */
  assign n5178_o = n5175_o | n5177_o;
  /* T80_MCode.vhd:1497:106  */
  assign n5180_o = ir == 8'b11111110;
  /* T80_MCode.vhd:1497:106  */
  assign n5181_o = n5178_o | n5180_o;
  /* T80_MCode.vhd:1522:44  */
  assign n5183_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1523:51  */
  assign n5185_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1523:41  */
  assign n5188_o = n5185_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1523:41  */
  assign n5190_o = n5185_o ? 4'b1011 : n2203_o;
  /* T80_MCode.vhd:1523:41  */
  assign n5193_o = n5185_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1532:46  */
  assign n5194_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1533:41  */
  assign n5196_o = n5194_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1533:48  */
  assign n5198_o = n5194_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1533:48  */
  assign n5199_o = n5196_o | n5198_o;
  /* T80_MCode.vhd:1535:41  */
  assign n5201_o = n5194_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1541:41  */
  assign n5203_o = n5194_o == 31'b0000000000000000000000000000011;
  assign n5204_o = {n5203_o, n5201_o, n5199_o};
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5204_o)
      3'b100: n5206_o = n2200_o;
      3'b010: n5206_o = 3'b100;
      3'b001: n5206_o = n2200_o;
      default: n5206_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5204_o)
      3'b100: n5209_o = 1'b0;
      3'b010: n5209_o = 1'b1;
      3'b001: n5209_o = 1'b0;
      default: n5209_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5204_o)
      3'b100: n5211_o = n2203_o;
      3'b010: n5211_o = 4'b1011;
      3'b001: n5211_o = n2203_o;
      default: n5211_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5204_o)
      3'b100: n5214_o = 1'b0;
      3'b010: n5214_o = 1'b1;
      3'b001: n5214_o = 1'b0;
      default: n5214_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5204_o)
      3'b100: n5218_o = 3'b111;
      3'b010: n5218_o = 3'b010;
      3'b001: n5218_o = 3'b010;
      default: n5218_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5204_o)
      3'b100: n5221_o = 1'b1;
      3'b010: n5221_o = 1'b0;
      3'b001: n5221_o = 1'b0;
      default: n5221_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1522:33  */
  assign n5224_o = n5183_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1522:33  */
  assign n5225_o = n5183_o ? n2200_o : n5206_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5226_o = n5183_o ? n5188_o : n5209_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5227_o = n5183_o ? n5190_o : n5211_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5228_o = n5183_o ? n5193_o : n5214_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5230_o = n5183_o ? 3'b111 : n5218_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5232_o = n5183_o ? 1'b0 : n5221_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5235_o = n5183_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1513:25  */
  assign n5237_o = ir == 8'b10000000;
  /* T80_MCode.vhd:1513:40  */
  assign n5239_o = ir == 8'b10000001;
  /* T80_MCode.vhd:1513:40  */
  assign n5240_o = n5237_o | n5239_o;
  /* T80_MCode.vhd:1513:51  */
  assign n5242_o = ir == 8'b10000010;
  /* T80_MCode.vhd:1513:51  */
  assign n5243_o = n5240_o | n5242_o;
  /* T80_MCode.vhd:1513:62  */
  assign n5245_o = ir == 8'b10000011;
  /* T80_MCode.vhd:1513:62  */
  assign n5246_o = n5243_o | n5245_o;
  /* T80_MCode.vhd:1513:73  */
  assign n5248_o = ir == 8'b10000100;
  /* T80_MCode.vhd:1513:73  */
  assign n5249_o = n5246_o | n5248_o;
  /* T80_MCode.vhd:1513:84  */
  assign n5251_o = ir == 8'b10000101;
  /* T80_MCode.vhd:1513:84  */
  assign n5252_o = n5249_o | n5251_o;
  /* T80_MCode.vhd:1513:95  */
  assign n5254_o = ir == 8'b10000111;
  /* T80_MCode.vhd:1513:95  */
  assign n5255_o = n5252_o | n5254_o;
  /* T80_MCode.vhd:1514:33  */
  assign n5257_o = ir == 8'b10001000;
  /* T80_MCode.vhd:1514:33  */
  assign n5258_o = n5255_o | n5257_o;
  /* T80_MCode.vhd:1514:44  */
  assign n5260_o = ir == 8'b10001001;
  /* T80_MCode.vhd:1514:44  */
  assign n5261_o = n5258_o | n5260_o;
  /* T80_MCode.vhd:1514:55  */
  assign n5263_o = ir == 8'b10001010;
  /* T80_MCode.vhd:1514:55  */
  assign n5264_o = n5261_o | n5263_o;
  /* T80_MCode.vhd:1514:66  */
  assign n5266_o = ir == 8'b10001011;
  /* T80_MCode.vhd:1514:66  */
  assign n5267_o = n5264_o | n5266_o;
  /* T80_MCode.vhd:1514:77  */
  assign n5269_o = ir == 8'b10001100;
  /* T80_MCode.vhd:1514:77  */
  assign n5270_o = n5267_o | n5269_o;
  /* T80_MCode.vhd:1514:88  */
  assign n5272_o = ir == 8'b10001101;
  /* T80_MCode.vhd:1514:88  */
  assign n5273_o = n5270_o | n5272_o;
  /* T80_MCode.vhd:1514:99  */
  assign n5275_o = ir == 8'b10001111;
  /* T80_MCode.vhd:1514:99  */
  assign n5276_o = n5273_o | n5275_o;
  /* T80_MCode.vhd:1515:33  */
  assign n5278_o = ir == 8'b10010000;
  /* T80_MCode.vhd:1515:33  */
  assign n5279_o = n5276_o | n5278_o;
  /* T80_MCode.vhd:1515:44  */
  assign n5281_o = ir == 8'b10010001;
  /* T80_MCode.vhd:1515:44  */
  assign n5282_o = n5279_o | n5281_o;
  /* T80_MCode.vhd:1515:55  */
  assign n5284_o = ir == 8'b10010010;
  /* T80_MCode.vhd:1515:55  */
  assign n5285_o = n5282_o | n5284_o;
  /* T80_MCode.vhd:1515:66  */
  assign n5287_o = ir == 8'b10010011;
  /* T80_MCode.vhd:1515:66  */
  assign n5288_o = n5285_o | n5287_o;
  /* T80_MCode.vhd:1515:77  */
  assign n5290_o = ir == 8'b10010100;
  /* T80_MCode.vhd:1515:77  */
  assign n5291_o = n5288_o | n5290_o;
  /* T80_MCode.vhd:1515:88  */
  assign n5293_o = ir == 8'b10010101;
  /* T80_MCode.vhd:1515:88  */
  assign n5294_o = n5291_o | n5293_o;
  /* T80_MCode.vhd:1515:99  */
  assign n5296_o = ir == 8'b10010111;
  /* T80_MCode.vhd:1515:99  */
  assign n5297_o = n5294_o | n5296_o;
  /* T80_MCode.vhd:1516:33  */
  assign n5299_o = ir == 8'b10011000;
  /* T80_MCode.vhd:1516:33  */
  assign n5300_o = n5297_o | n5299_o;
  /* T80_MCode.vhd:1516:44  */
  assign n5302_o = ir == 8'b10011001;
  /* T80_MCode.vhd:1516:44  */
  assign n5303_o = n5300_o | n5302_o;
  /* T80_MCode.vhd:1516:55  */
  assign n5305_o = ir == 8'b10011010;
  /* T80_MCode.vhd:1516:55  */
  assign n5306_o = n5303_o | n5305_o;
  /* T80_MCode.vhd:1516:66  */
  assign n5308_o = ir == 8'b10011011;
  /* T80_MCode.vhd:1516:66  */
  assign n5309_o = n5306_o | n5308_o;
  /* T80_MCode.vhd:1516:77  */
  assign n5311_o = ir == 8'b10011100;
  /* T80_MCode.vhd:1516:77  */
  assign n5312_o = n5309_o | n5311_o;
  /* T80_MCode.vhd:1516:88  */
  assign n5314_o = ir == 8'b10011101;
  /* T80_MCode.vhd:1516:88  */
  assign n5315_o = n5312_o | n5314_o;
  /* T80_MCode.vhd:1516:99  */
  assign n5317_o = ir == 8'b10011111;
  /* T80_MCode.vhd:1516:99  */
  assign n5318_o = n5315_o | n5317_o;
  /* T80_MCode.vhd:1517:33  */
  assign n5320_o = ir == 8'b10100000;
  /* T80_MCode.vhd:1517:33  */
  assign n5321_o = n5318_o | n5320_o;
  /* T80_MCode.vhd:1517:44  */
  assign n5323_o = ir == 8'b10100001;
  /* T80_MCode.vhd:1517:44  */
  assign n5324_o = n5321_o | n5323_o;
  /* T80_MCode.vhd:1517:55  */
  assign n5326_o = ir == 8'b10100010;
  /* T80_MCode.vhd:1517:55  */
  assign n5327_o = n5324_o | n5326_o;
  /* T80_MCode.vhd:1517:66  */
  assign n5329_o = ir == 8'b10100011;
  /* T80_MCode.vhd:1517:66  */
  assign n5330_o = n5327_o | n5329_o;
  /* T80_MCode.vhd:1517:77  */
  assign n5332_o = ir == 8'b10100100;
  /* T80_MCode.vhd:1517:77  */
  assign n5333_o = n5330_o | n5332_o;
  /* T80_MCode.vhd:1517:88  */
  assign n5335_o = ir == 8'b10100101;
  /* T80_MCode.vhd:1517:88  */
  assign n5336_o = n5333_o | n5335_o;
  /* T80_MCode.vhd:1517:99  */
  assign n5338_o = ir == 8'b10100111;
  /* T80_MCode.vhd:1517:99  */
  assign n5339_o = n5336_o | n5338_o;
  /* T80_MCode.vhd:1518:33  */
  assign n5341_o = ir == 8'b10101000;
  /* T80_MCode.vhd:1518:33  */
  assign n5342_o = n5339_o | n5341_o;
  /* T80_MCode.vhd:1518:44  */
  assign n5344_o = ir == 8'b10101001;
  /* T80_MCode.vhd:1518:44  */
  assign n5345_o = n5342_o | n5344_o;
  /* T80_MCode.vhd:1518:55  */
  assign n5347_o = ir == 8'b10101010;
  /* T80_MCode.vhd:1518:55  */
  assign n5348_o = n5345_o | n5347_o;
  /* T80_MCode.vhd:1518:66  */
  assign n5350_o = ir == 8'b10101011;
  /* T80_MCode.vhd:1518:66  */
  assign n5351_o = n5348_o | n5350_o;
  /* T80_MCode.vhd:1518:77  */
  assign n5353_o = ir == 8'b10101100;
  /* T80_MCode.vhd:1518:77  */
  assign n5354_o = n5351_o | n5353_o;
  /* T80_MCode.vhd:1518:88  */
  assign n5356_o = ir == 8'b10101101;
  /* T80_MCode.vhd:1518:88  */
  assign n5357_o = n5354_o | n5356_o;
  /* T80_MCode.vhd:1518:99  */
  assign n5359_o = ir == 8'b10101111;
  /* T80_MCode.vhd:1518:99  */
  assign n5360_o = n5357_o | n5359_o;
  /* T80_MCode.vhd:1519:33  */
  assign n5362_o = ir == 8'b10110000;
  /* T80_MCode.vhd:1519:33  */
  assign n5363_o = n5360_o | n5362_o;
  /* T80_MCode.vhd:1519:44  */
  assign n5365_o = ir == 8'b10110001;
  /* T80_MCode.vhd:1519:44  */
  assign n5366_o = n5363_o | n5365_o;
  /* T80_MCode.vhd:1519:55  */
  assign n5368_o = ir == 8'b10110010;
  /* T80_MCode.vhd:1519:55  */
  assign n5369_o = n5366_o | n5368_o;
  /* T80_MCode.vhd:1519:66  */
  assign n5371_o = ir == 8'b10110011;
  /* T80_MCode.vhd:1519:66  */
  assign n5372_o = n5369_o | n5371_o;
  /* T80_MCode.vhd:1519:77  */
  assign n5374_o = ir == 8'b10110100;
  /* T80_MCode.vhd:1519:77  */
  assign n5375_o = n5372_o | n5374_o;
  /* T80_MCode.vhd:1519:88  */
  assign n5377_o = ir == 8'b10110101;
  /* T80_MCode.vhd:1519:88  */
  assign n5378_o = n5375_o | n5377_o;
  /* T80_MCode.vhd:1519:99  */
  assign n5380_o = ir == 8'b10110111;
  /* T80_MCode.vhd:1519:99  */
  assign n5381_o = n5378_o | n5380_o;
  /* T80_MCode.vhd:1520:33  */
  assign n5383_o = ir == 8'b10111000;
  /* T80_MCode.vhd:1520:33  */
  assign n5384_o = n5381_o | n5383_o;
  /* T80_MCode.vhd:1520:44  */
  assign n5386_o = ir == 8'b10111001;
  /* T80_MCode.vhd:1520:44  */
  assign n5387_o = n5384_o | n5386_o;
  /* T80_MCode.vhd:1520:55  */
  assign n5389_o = ir == 8'b10111010;
  /* T80_MCode.vhd:1520:55  */
  assign n5390_o = n5387_o | n5389_o;
  /* T80_MCode.vhd:1520:66  */
  assign n5392_o = ir == 8'b10111011;
  /* T80_MCode.vhd:1520:66  */
  assign n5393_o = n5390_o | n5392_o;
  /* T80_MCode.vhd:1520:77  */
  assign n5395_o = ir == 8'b10111100;
  /* T80_MCode.vhd:1520:77  */
  assign n5396_o = n5393_o | n5395_o;
  /* T80_MCode.vhd:1520:88  */
  assign n5398_o = ir == 8'b10111101;
  /* T80_MCode.vhd:1520:88  */
  assign n5399_o = n5396_o | n5398_o;
  /* T80_MCode.vhd:1520:99  */
  assign n5401_o = ir == 8'b10111111;
  /* T80_MCode.vhd:1520:99  */
  assign n5402_o = n5399_o | n5401_o;
  /* T80_MCode.vhd:1550:38  */
  assign n5403_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1551:33  */
  assign n5405_o = n5403_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1551:40  */
  assign n5407_o = n5403_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1551:40  */
  assign n5408_o = n5405_o | n5407_o;
  /* T80_MCode.vhd:1553:33  */
  assign n5410_o = n5403_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1559:33  */
  assign n5412_o = n5403_o == 31'b0000000000000000000000000000011;
  assign n5413_o = {n5412_o, n5410_o, n5408_o};
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5413_o)
      3'b100: n5415_o = n2200_o;
      3'b010: n5415_o = 3'b100;
      3'b001: n5415_o = n2200_o;
      default: n5415_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5413_o)
      3'b100: n5418_o = 1'b0;
      3'b010: n5418_o = 1'b1;
      3'b001: n5418_o = 1'b0;
      default: n5418_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5413_o)
      3'b100: n5420_o = n2203_o;
      3'b010: n5420_o = 4'b1011;
      3'b001: n5420_o = n2203_o;
      default: n5420_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5413_o)
      3'b100: n5423_o = 1'b0;
      3'b010: n5423_o = 1'b1;
      3'b001: n5423_o = 1'b0;
      default: n5423_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5413_o)
      3'b100: n5427_o = 3'b111;
      3'b010: n5427_o = 3'b010;
      3'b001: n5427_o = 3'b010;
      default: n5427_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5413_o)
      3'b100: n5430_o = 1'b1;
      3'b010: n5430_o = 1'b0;
      3'b001: n5430_o = 1'b0;
      default: n5430_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1547:25  */
  assign n5432_o = ir == 8'b10000110;
  /* T80_MCode.vhd:1547:40  */
  assign n5434_o = ir == 8'b10001110;
  /* T80_MCode.vhd:1547:40  */
  assign n5435_o = n5432_o | n5434_o;
  /* T80_MCode.vhd:1547:51  */
  assign n5437_o = ir == 8'b10010110;
  /* T80_MCode.vhd:1547:51  */
  assign n5438_o = n5435_o | n5437_o;
  /* T80_MCode.vhd:1547:62  */
  assign n5440_o = ir == 8'b10011110;
  /* T80_MCode.vhd:1547:62  */
  assign n5441_o = n5438_o | n5440_o;
  /* T80_MCode.vhd:1547:73  */
  assign n5443_o = ir == 8'b10100110;
  /* T80_MCode.vhd:1547:73  */
  assign n5444_o = n5441_o | n5443_o;
  /* T80_MCode.vhd:1547:84  */
  assign n5446_o = ir == 8'b10101110;
  /* T80_MCode.vhd:1547:84  */
  assign n5447_o = n5444_o | n5446_o;
  /* T80_MCode.vhd:1547:95  */
  assign n5449_o = ir == 8'b10110110;
  /* T80_MCode.vhd:1547:95  */
  assign n5450_o = n5447_o | n5449_o;
  /* T80_MCode.vhd:1547:106  */
  assign n5452_o = ir == 8'b10111110;
  /* T80_MCode.vhd:1547:106  */
  assign n5453_o = n5450_o | n5452_o;
  assign n5454_o = {n5453_o, n5402_o, n5181_o, n5130_o, n4909_o, n4870_o, n4668_o, n4617_o};
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5454_o)
      8'b10000000: n5460_o = 3'b011;
      8'b01000000: n5460_o = n5224_o;
      8'b00100000: n5460_o = 3'b011;
      8'b00010000: n5460_o = n4952_o;
      8'b00001000: n5460_o = 3'b010;
      8'b00000100: n5460_o = n4695_o;
      8'b00000010: n5460_o = 3'b011;
      8'b00000001: n5460_o = n4439_o;
      default: n5460_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5454_o)
      8'b10000000: n5462_o = n5415_o;
      8'b01000000: n5462_o = n5225_o;
      8'b00100000: n5462_o = n5143_o;
      8'b00010000: n5462_o = n4953_o;
      8'b00001000: n5462_o = n4881_o;
      8'b00000100: n5462_o = n4696_o;
      8'b00000010: n5462_o = n4630_o;
      8'b00000001: n5462_o = n4440_o;
      default: n5462_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5454_o)
      8'b10000000: n5465_o = n5418_o;
      8'b01000000: n5465_o = n5226_o;
      8'b00100000: n5465_o = n5146_o;
      8'b00010000: n5465_o = n4954_o;
      8'b00001000: n5465_o = 1'b0;
      8'b00000100: n5465_o = 1'b0;
      8'b00000010: n5465_o = n4633_o;
      8'b00000001: n5465_o = n4441_o;
      default: n5465_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5454_o)
      8'b10000000: n5467_o = n4396_o;
      8'b01000000: n5467_o = n4396_o;
      8'b00100000: n5467_o = n4396_o;
      8'b00010000: n5467_o = n4396_o;
      8'b00001000: n5467_o = n4396_o;
      8'b00000100: n5467_o = n4674_o;
      8'b00000010: n5467_o = n4396_o;
      8'b00000001: n5467_o = n4396_o;
      default: n5467_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5454_o)
      8'b10000000: n5469_o = n5420_o;
      8'b01000000: n5469_o = n5227_o;
      8'b00100000: n5469_o = n5148_o;
      8'b00010000: n5469_o = n4955_o;
      8'b00001000: n5469_o = n4883_o;
      8'b00000100: n5469_o = n4698_o;
      8'b00000010: n5469_o = n4635_o;
      8'b00000001: n5469_o = n4442_o;
      default: n5469_o = 4'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5454_o)
      8'b10000000: n5472_o = n5423_o;
      8'b01000000: n5472_o = n5228_o;
      8'b00100000: n5472_o = n5151_o;
      8'b00010000: n5472_o = n4956_o;
      8'b00001000: n5472_o = 1'b0;
      8'b00000100: n5472_o = 1'b0;
      8'b00000010: n5472_o = n4638_o;
      8'b00000001: n5472_o = n4443_o;
      default: n5472_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5454_o)
      8'b10000000: n5474_o = n5427_o;
      8'b01000000: n5474_o = n5230_o;
      8'b00100000: n5474_o = n5155_o;
      8'b00010000: n5474_o = n4958_o;
      8'b00001000: n5474_o = n4886_o;
      8'b00000100: n5474_o = n4700_o;
      8'b00000010: n5474_o = n4642_o;
      8'b00000001: n5474_o = n4445_o;
      default: n5474_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5454_o)
      8'b10000000: n5477_o = n5430_o;
      8'b01000000: n5477_o = n5232_o;
      8'b00100000: n5477_o = n5158_o;
      8'b00010000: n5477_o = n4960_o;
      8'b00001000: n5477_o = 1'b0;
      8'b00000100: n5477_o = 1'b0;
      8'b00000010: n5477_o = n4645_o;
      8'b00000001: n5477_o = n4447_o;
      default: n5477_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5454_o)
      8'b10000000: n5480_o = 1'b0;
      8'b01000000: n5480_o = n5235_o;
      8'b00100000: n5480_o = 1'b0;
      8'b00010000: n5480_o = n4963_o;
      8'b00001000: n5480_o = 1'b0;
      8'b00000100: n5480_o = n4703_o;
      8'b00000010: n5480_o = 1'b0;
      8'b00000001: n5480_o = n4450_o;
      default: n5480_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1348:17  */
  assign n5482_o = iset == 2'b01;
  /* T80_MCode.vhd:1574:25  */
  assign n5484_o = ir == 8'b00000000;
  /* T80_MCode.vhd:1574:40  */
  assign n5486_o = ir == 8'b00000001;
  /* T80_MCode.vhd:1574:40  */
  assign n5487_o = n5484_o | n5486_o;
  /* T80_MCode.vhd:1574:51  */
  assign n5489_o = ir == 8'b00000010;
  /* T80_MCode.vhd:1574:51  */
  assign n5490_o = n5487_o | n5489_o;
  /* T80_MCode.vhd:1574:62  */
  assign n5492_o = ir == 8'b00000011;
  /* T80_MCode.vhd:1574:62  */
  assign n5493_o = n5490_o | n5492_o;
  /* T80_MCode.vhd:1574:73  */
  assign n5495_o = ir == 8'b00000100;
  /* T80_MCode.vhd:1574:73  */
  assign n5496_o = n5493_o | n5495_o;
  /* T80_MCode.vhd:1574:84  */
  assign n5498_o = ir == 8'b00000101;
  /* T80_MCode.vhd:1574:84  */
  assign n5499_o = n5496_o | n5498_o;
  /* T80_MCode.vhd:1574:95  */
  assign n5501_o = ir == 8'b00000110;
  /* T80_MCode.vhd:1574:95  */
  assign n5502_o = n5499_o | n5501_o;
  /* T80_MCode.vhd:1574:106  */
  assign n5504_o = ir == 8'b00000111;
  /* T80_MCode.vhd:1574:106  */
  assign n5505_o = n5502_o | n5504_o;
  /* T80_MCode.vhd:1575:33  */
  assign n5507_o = ir == 8'b00001000;
  /* T80_MCode.vhd:1575:33  */
  assign n5508_o = n5505_o | n5507_o;
  /* T80_MCode.vhd:1575:44  */
  assign n5510_o = ir == 8'b00001001;
  /* T80_MCode.vhd:1575:44  */
  assign n5511_o = n5508_o | n5510_o;
  /* T80_MCode.vhd:1575:55  */
  assign n5513_o = ir == 8'b00001010;
  /* T80_MCode.vhd:1575:55  */
  assign n5514_o = n5511_o | n5513_o;
  /* T80_MCode.vhd:1575:66  */
  assign n5516_o = ir == 8'b00001011;
  /* T80_MCode.vhd:1575:66  */
  assign n5517_o = n5514_o | n5516_o;
  /* T80_MCode.vhd:1575:77  */
  assign n5519_o = ir == 8'b00001100;
  /* T80_MCode.vhd:1575:77  */
  assign n5520_o = n5517_o | n5519_o;
  /* T80_MCode.vhd:1575:88  */
  assign n5522_o = ir == 8'b00001101;
  /* T80_MCode.vhd:1575:88  */
  assign n5523_o = n5520_o | n5522_o;
  /* T80_MCode.vhd:1575:99  */
  assign n5525_o = ir == 8'b00001110;
  /* T80_MCode.vhd:1575:99  */
  assign n5526_o = n5523_o | n5525_o;
  /* T80_MCode.vhd:1575:110  */
  assign n5528_o = ir == 8'b00001111;
  /* T80_MCode.vhd:1575:110  */
  assign n5529_o = n5526_o | n5528_o;
  /* T80_MCode.vhd:1576:33  */
  assign n5531_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1576:33  */
  assign n5532_o = n5529_o | n5531_o;
  /* T80_MCode.vhd:1576:44  */
  assign n5534_o = ir == 8'b00010001;
  /* T80_MCode.vhd:1576:44  */
  assign n5535_o = n5532_o | n5534_o;
  /* T80_MCode.vhd:1576:55  */
  assign n5537_o = ir == 8'b00010010;
  /* T80_MCode.vhd:1576:55  */
  assign n5538_o = n5535_o | n5537_o;
  /* T80_MCode.vhd:1576:66  */
  assign n5540_o = ir == 8'b00010011;
  /* T80_MCode.vhd:1576:66  */
  assign n5541_o = n5538_o | n5540_o;
  /* T80_MCode.vhd:1576:77  */
  assign n5543_o = ir == 8'b00010100;
  /* T80_MCode.vhd:1576:77  */
  assign n5544_o = n5541_o | n5543_o;
  /* T80_MCode.vhd:1576:88  */
  assign n5546_o = ir == 8'b00010101;
  /* T80_MCode.vhd:1576:88  */
  assign n5547_o = n5544_o | n5546_o;
  /* T80_MCode.vhd:1576:99  */
  assign n5549_o = ir == 8'b00010110;
  /* T80_MCode.vhd:1576:99  */
  assign n5550_o = n5547_o | n5549_o;
  /* T80_MCode.vhd:1576:110  */
  assign n5552_o = ir == 8'b00010111;
  /* T80_MCode.vhd:1576:110  */
  assign n5553_o = n5550_o | n5552_o;
  /* T80_MCode.vhd:1577:33  */
  assign n5555_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1577:33  */
  assign n5556_o = n5553_o | n5555_o;
  /* T80_MCode.vhd:1577:44  */
  assign n5558_o = ir == 8'b00011001;
  /* T80_MCode.vhd:1577:44  */
  assign n5559_o = n5556_o | n5558_o;
  /* T80_MCode.vhd:1577:55  */
  assign n5561_o = ir == 8'b00011010;
  /* T80_MCode.vhd:1577:55  */
  assign n5562_o = n5559_o | n5561_o;
  /* T80_MCode.vhd:1577:66  */
  assign n5564_o = ir == 8'b00011011;
  /* T80_MCode.vhd:1577:66  */
  assign n5565_o = n5562_o | n5564_o;
  /* T80_MCode.vhd:1577:77  */
  assign n5567_o = ir == 8'b00011100;
  /* T80_MCode.vhd:1577:77  */
  assign n5568_o = n5565_o | n5567_o;
  /* T80_MCode.vhd:1577:88  */
  assign n5570_o = ir == 8'b00011101;
  /* T80_MCode.vhd:1577:88  */
  assign n5571_o = n5568_o | n5570_o;
  /* T80_MCode.vhd:1577:99  */
  assign n5573_o = ir == 8'b00011110;
  /* T80_MCode.vhd:1577:99  */
  assign n5574_o = n5571_o | n5573_o;
  /* T80_MCode.vhd:1577:110  */
  assign n5576_o = ir == 8'b00011111;
  /* T80_MCode.vhd:1577:110  */
  assign n5577_o = n5574_o | n5576_o;
  /* T80_MCode.vhd:1578:33  */
  assign n5579_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1578:33  */
  assign n5580_o = n5577_o | n5579_o;
  /* T80_MCode.vhd:1578:44  */
  assign n5582_o = ir == 8'b00100001;
  /* T80_MCode.vhd:1578:44  */
  assign n5583_o = n5580_o | n5582_o;
  /* T80_MCode.vhd:1578:55  */
  assign n5585_o = ir == 8'b00100010;
  /* T80_MCode.vhd:1578:55  */
  assign n5586_o = n5583_o | n5585_o;
  /* T80_MCode.vhd:1578:66  */
  assign n5588_o = ir == 8'b00100011;
  /* T80_MCode.vhd:1578:66  */
  assign n5589_o = n5586_o | n5588_o;
  /* T80_MCode.vhd:1578:77  */
  assign n5591_o = ir == 8'b00100100;
  /* T80_MCode.vhd:1578:77  */
  assign n5592_o = n5589_o | n5591_o;
  /* T80_MCode.vhd:1578:88  */
  assign n5594_o = ir == 8'b00100101;
  /* T80_MCode.vhd:1578:88  */
  assign n5595_o = n5592_o | n5594_o;
  /* T80_MCode.vhd:1578:99  */
  assign n5597_o = ir == 8'b00100110;
  /* T80_MCode.vhd:1578:99  */
  assign n5598_o = n5595_o | n5597_o;
  /* T80_MCode.vhd:1578:110  */
  assign n5600_o = ir == 8'b00100111;
  /* T80_MCode.vhd:1578:110  */
  assign n5601_o = n5598_o | n5600_o;
  /* T80_MCode.vhd:1579:33  */
  assign n5603_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1579:33  */
  assign n5604_o = n5601_o | n5603_o;
  /* T80_MCode.vhd:1579:44  */
  assign n5606_o = ir == 8'b00101001;
  /* T80_MCode.vhd:1579:44  */
  assign n5607_o = n5604_o | n5606_o;
  /* T80_MCode.vhd:1579:55  */
  assign n5609_o = ir == 8'b00101010;
  /* T80_MCode.vhd:1579:55  */
  assign n5610_o = n5607_o | n5609_o;
  /* T80_MCode.vhd:1579:66  */
  assign n5612_o = ir == 8'b00101011;
  /* T80_MCode.vhd:1579:66  */
  assign n5613_o = n5610_o | n5612_o;
  /* T80_MCode.vhd:1579:77  */
  assign n5615_o = ir == 8'b00101100;
  /* T80_MCode.vhd:1579:77  */
  assign n5616_o = n5613_o | n5615_o;
  /* T80_MCode.vhd:1579:88  */
  assign n5618_o = ir == 8'b00101101;
  /* T80_MCode.vhd:1579:88  */
  assign n5619_o = n5616_o | n5618_o;
  /* T80_MCode.vhd:1579:99  */
  assign n5621_o = ir == 8'b00101110;
  /* T80_MCode.vhd:1579:99  */
  assign n5622_o = n5619_o | n5621_o;
  /* T80_MCode.vhd:1579:110  */
  assign n5624_o = ir == 8'b00101111;
  /* T80_MCode.vhd:1579:110  */
  assign n5625_o = n5622_o | n5624_o;
  /* T80_MCode.vhd:1580:33  */
  assign n5627_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1580:33  */
  assign n5628_o = n5625_o | n5627_o;
  /* T80_MCode.vhd:1580:44  */
  assign n5630_o = ir == 8'b00110001;
  /* T80_MCode.vhd:1580:44  */
  assign n5631_o = n5628_o | n5630_o;
  /* T80_MCode.vhd:1580:55  */
  assign n5633_o = ir == 8'b00110010;
  /* T80_MCode.vhd:1580:55  */
  assign n5634_o = n5631_o | n5633_o;
  /* T80_MCode.vhd:1580:66  */
  assign n5636_o = ir == 8'b00110011;
  /* T80_MCode.vhd:1580:66  */
  assign n5637_o = n5634_o | n5636_o;
  /* T80_MCode.vhd:1580:77  */
  assign n5639_o = ir == 8'b00110100;
  /* T80_MCode.vhd:1580:77  */
  assign n5640_o = n5637_o | n5639_o;
  /* T80_MCode.vhd:1580:88  */
  assign n5642_o = ir == 8'b00110101;
  /* T80_MCode.vhd:1580:88  */
  assign n5643_o = n5640_o | n5642_o;
  /* T80_MCode.vhd:1580:99  */
  assign n5645_o = ir == 8'b00110110;
  /* T80_MCode.vhd:1580:99  */
  assign n5646_o = n5643_o | n5645_o;
  /* T80_MCode.vhd:1580:110  */
  assign n5648_o = ir == 8'b00110111;
  /* T80_MCode.vhd:1580:110  */
  assign n5649_o = n5646_o | n5648_o;
  /* T80_MCode.vhd:1581:33  */
  assign n5651_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1581:33  */
  assign n5652_o = n5649_o | n5651_o;
  /* T80_MCode.vhd:1581:44  */
  assign n5654_o = ir == 8'b00111001;
  /* T80_MCode.vhd:1581:44  */
  assign n5655_o = n5652_o | n5654_o;
  /* T80_MCode.vhd:1581:55  */
  assign n5657_o = ir == 8'b00111010;
  /* T80_MCode.vhd:1581:55  */
  assign n5658_o = n5655_o | n5657_o;
  /* T80_MCode.vhd:1581:66  */
  assign n5660_o = ir == 8'b00111011;
  /* T80_MCode.vhd:1581:66  */
  assign n5661_o = n5658_o | n5660_o;
  /* T80_MCode.vhd:1581:77  */
  assign n5663_o = ir == 8'b00111100;
  /* T80_MCode.vhd:1581:77  */
  assign n5664_o = n5661_o | n5663_o;
  /* T80_MCode.vhd:1581:88  */
  assign n5666_o = ir == 8'b00111101;
  /* T80_MCode.vhd:1581:88  */
  assign n5667_o = n5664_o | n5666_o;
  /* T80_MCode.vhd:1581:99  */
  assign n5669_o = ir == 8'b00111110;
  /* T80_MCode.vhd:1581:99  */
  assign n5670_o = n5667_o | n5669_o;
  /* T80_MCode.vhd:1581:110  */
  assign n5672_o = ir == 8'b00111111;
  /* T80_MCode.vhd:1581:110  */
  assign n5673_o = n5670_o | n5672_o;
  /* T80_MCode.vhd:1584:33  */
  assign n5675_o = ir == 8'b10000000;
  /* T80_MCode.vhd:1584:33  */
  assign n5676_o = n5673_o | n5675_o;
  /* T80_MCode.vhd:1584:44  */
  assign n5678_o = ir == 8'b10000001;
  /* T80_MCode.vhd:1584:44  */
  assign n5679_o = n5676_o | n5678_o;
  /* T80_MCode.vhd:1584:55  */
  assign n5681_o = ir == 8'b10000010;
  /* T80_MCode.vhd:1584:55  */
  assign n5682_o = n5679_o | n5681_o;
  /* T80_MCode.vhd:1584:66  */
  assign n5684_o = ir == 8'b10000011;
  /* T80_MCode.vhd:1584:66  */
  assign n5685_o = n5682_o | n5684_o;
  /* T80_MCode.vhd:1584:77  */
  assign n5687_o = ir == 8'b10000100;
  /* T80_MCode.vhd:1584:77  */
  assign n5688_o = n5685_o | n5687_o;
  /* T80_MCode.vhd:1584:88  */
  assign n5690_o = ir == 8'b10000101;
  /* T80_MCode.vhd:1584:88  */
  assign n5691_o = n5688_o | n5690_o;
  /* T80_MCode.vhd:1584:99  */
  assign n5693_o = ir == 8'b10000110;
  /* T80_MCode.vhd:1584:99  */
  assign n5694_o = n5691_o | n5693_o;
  /* T80_MCode.vhd:1584:110  */
  assign n5696_o = ir == 8'b10000111;
  /* T80_MCode.vhd:1584:110  */
  assign n5697_o = n5694_o | n5696_o;
  /* T80_MCode.vhd:1585:33  */
  assign n5699_o = ir == 8'b10001000;
  /* T80_MCode.vhd:1585:33  */
  assign n5700_o = n5697_o | n5699_o;
  /* T80_MCode.vhd:1585:44  */
  assign n5702_o = ir == 8'b10001001;
  /* T80_MCode.vhd:1585:44  */
  assign n5703_o = n5700_o | n5702_o;
  /* T80_MCode.vhd:1585:55  */
  assign n5705_o = ir == 8'b10001010;
  /* T80_MCode.vhd:1585:55  */
  assign n5706_o = n5703_o | n5705_o;
  /* T80_MCode.vhd:1585:66  */
  assign n5708_o = ir == 8'b10001011;
  /* T80_MCode.vhd:1585:66  */
  assign n5709_o = n5706_o | n5708_o;
  /* T80_MCode.vhd:1585:77  */
  assign n5711_o = ir == 8'b10001100;
  /* T80_MCode.vhd:1585:77  */
  assign n5712_o = n5709_o | n5711_o;
  /* T80_MCode.vhd:1585:88  */
  assign n5714_o = ir == 8'b10001101;
  /* T80_MCode.vhd:1585:88  */
  assign n5715_o = n5712_o | n5714_o;
  /* T80_MCode.vhd:1585:99  */
  assign n5717_o = ir == 8'b10001110;
  /* T80_MCode.vhd:1585:99  */
  assign n5718_o = n5715_o | n5717_o;
  /* T80_MCode.vhd:1585:110  */
  assign n5720_o = ir == 8'b10001111;
  /* T80_MCode.vhd:1585:110  */
  assign n5721_o = n5718_o | n5720_o;
  /* T80_MCode.vhd:1586:33  */
  assign n5723_o = ir == 8'b10010000;
  /* T80_MCode.vhd:1586:33  */
  assign n5724_o = n5721_o | n5723_o;
  /* T80_MCode.vhd:1586:44  */
  assign n5726_o = ir == 8'b10010001;
  /* T80_MCode.vhd:1586:44  */
  assign n5727_o = n5724_o | n5726_o;
  /* T80_MCode.vhd:1586:55  */
  assign n5729_o = ir == 8'b10010010;
  /* T80_MCode.vhd:1586:55  */
  assign n5730_o = n5727_o | n5729_o;
  /* T80_MCode.vhd:1586:66  */
  assign n5732_o = ir == 8'b10010011;
  /* T80_MCode.vhd:1586:66  */
  assign n5733_o = n5730_o | n5732_o;
  /* T80_MCode.vhd:1586:77  */
  assign n5735_o = ir == 8'b10010100;
  /* T80_MCode.vhd:1586:77  */
  assign n5736_o = n5733_o | n5735_o;
  /* T80_MCode.vhd:1586:88  */
  assign n5738_o = ir == 8'b10010101;
  /* T80_MCode.vhd:1586:88  */
  assign n5739_o = n5736_o | n5738_o;
  /* T80_MCode.vhd:1586:99  */
  assign n5741_o = ir == 8'b10010110;
  /* T80_MCode.vhd:1586:99  */
  assign n5742_o = n5739_o | n5741_o;
  /* T80_MCode.vhd:1586:110  */
  assign n5744_o = ir == 8'b10010111;
  /* T80_MCode.vhd:1586:110  */
  assign n5745_o = n5742_o | n5744_o;
  /* T80_MCode.vhd:1587:33  */
  assign n5747_o = ir == 8'b10011000;
  /* T80_MCode.vhd:1587:33  */
  assign n5748_o = n5745_o | n5747_o;
  /* T80_MCode.vhd:1587:44  */
  assign n5750_o = ir == 8'b10011001;
  /* T80_MCode.vhd:1587:44  */
  assign n5751_o = n5748_o | n5750_o;
  /* T80_MCode.vhd:1587:55  */
  assign n5753_o = ir == 8'b10011010;
  /* T80_MCode.vhd:1587:55  */
  assign n5754_o = n5751_o | n5753_o;
  /* T80_MCode.vhd:1587:66  */
  assign n5756_o = ir == 8'b10011011;
  /* T80_MCode.vhd:1587:66  */
  assign n5757_o = n5754_o | n5756_o;
  /* T80_MCode.vhd:1587:77  */
  assign n5759_o = ir == 8'b10011100;
  /* T80_MCode.vhd:1587:77  */
  assign n5760_o = n5757_o | n5759_o;
  /* T80_MCode.vhd:1587:88  */
  assign n5762_o = ir == 8'b10011101;
  /* T80_MCode.vhd:1587:88  */
  assign n5763_o = n5760_o | n5762_o;
  /* T80_MCode.vhd:1587:99  */
  assign n5765_o = ir == 8'b10011110;
  /* T80_MCode.vhd:1587:99  */
  assign n5766_o = n5763_o | n5765_o;
  /* T80_MCode.vhd:1587:110  */
  assign n5768_o = ir == 8'b10011111;
  /* T80_MCode.vhd:1587:110  */
  assign n5769_o = n5766_o | n5768_o;
  /* T80_MCode.vhd:1588:33  */
  assign n5771_o = ir == 8'b10100100;
  /* T80_MCode.vhd:1588:33  */
  assign n5772_o = n5769_o | n5771_o;
  /* T80_MCode.vhd:1588:88  */
  assign n5774_o = ir == 8'b10100101;
  /* T80_MCode.vhd:1588:88  */
  assign n5775_o = n5772_o | n5774_o;
  /* T80_MCode.vhd:1588:99  */
  assign n5777_o = ir == 8'b10100110;
  /* T80_MCode.vhd:1588:99  */
  assign n5778_o = n5775_o | n5777_o;
  /* T80_MCode.vhd:1588:110  */
  assign n5780_o = ir == 8'b10100111;
  /* T80_MCode.vhd:1588:110  */
  assign n5781_o = n5778_o | n5780_o;
  /* T80_MCode.vhd:1589:33  */
  assign n5783_o = ir == 8'b10101100;
  /* T80_MCode.vhd:1589:33  */
  assign n5784_o = n5781_o | n5783_o;
  /* T80_MCode.vhd:1589:88  */
  assign n5786_o = ir == 8'b10101101;
  /* T80_MCode.vhd:1589:88  */
  assign n5787_o = n5784_o | n5786_o;
  /* T80_MCode.vhd:1589:99  */
  assign n5789_o = ir == 8'b10101110;
  /* T80_MCode.vhd:1589:99  */
  assign n5790_o = n5787_o | n5789_o;
  /* T80_MCode.vhd:1589:110  */
  assign n5792_o = ir == 8'b10101111;
  /* T80_MCode.vhd:1589:110  */
  assign n5793_o = n5790_o | n5792_o;
  /* T80_MCode.vhd:1590:33  */
  assign n5795_o = ir == 8'b10110100;
  /* T80_MCode.vhd:1590:33  */
  assign n5796_o = n5793_o | n5795_o;
  /* T80_MCode.vhd:1590:88  */
  assign n5798_o = ir == 8'b10110101;
  /* T80_MCode.vhd:1590:88  */
  assign n5799_o = n5796_o | n5798_o;
  /* T80_MCode.vhd:1590:99  */
  assign n5801_o = ir == 8'b10110110;
  /* T80_MCode.vhd:1590:99  */
  assign n5802_o = n5799_o | n5801_o;
  /* T80_MCode.vhd:1590:110  */
  assign n5804_o = ir == 8'b10110111;
  /* T80_MCode.vhd:1590:110  */
  assign n5805_o = n5802_o | n5804_o;
  /* T80_MCode.vhd:1591:33  */
  assign n5807_o = ir == 8'b10111100;
  /* T80_MCode.vhd:1591:33  */
  assign n5808_o = n5805_o | n5807_o;
  /* T80_MCode.vhd:1591:88  */
  assign n5810_o = ir == 8'b10111101;
  /* T80_MCode.vhd:1591:88  */
  assign n5811_o = n5808_o | n5810_o;
  /* T80_MCode.vhd:1591:99  */
  assign n5813_o = ir == 8'b10111110;
  /* T80_MCode.vhd:1591:99  */
  assign n5814_o = n5811_o | n5813_o;
  /* T80_MCode.vhd:1591:110  */
  assign n5816_o = ir == 8'b10111111;
  /* T80_MCode.vhd:1591:110  */
  assign n5817_o = n5814_o | n5816_o;
  /* T80_MCode.vhd:1592:33  */
  assign n5819_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1592:33  */
  assign n5820_o = n5817_o | n5819_o;
  /* T80_MCode.vhd:1592:44  */
  assign n5822_o = ir == 8'b11000001;
  /* T80_MCode.vhd:1592:44  */
  assign n5823_o = n5820_o | n5822_o;
  /* T80_MCode.vhd:1592:55  */
  assign n5825_o = ir == 8'b11000010;
  /* T80_MCode.vhd:1592:55  */
  assign n5826_o = n5823_o | n5825_o;
  /* T80_MCode.vhd:1592:66  */
  assign n5828_o = ir == 8'b11000011;
  /* T80_MCode.vhd:1592:66  */
  assign n5829_o = n5826_o | n5828_o;
  /* T80_MCode.vhd:1592:77  */
  assign n5831_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1592:77  */
  assign n5832_o = n5829_o | n5831_o;
  /* T80_MCode.vhd:1592:88  */
  assign n5834_o = ir == 8'b11000101;
  /* T80_MCode.vhd:1592:88  */
  assign n5835_o = n5832_o | n5834_o;
  /* T80_MCode.vhd:1592:99  */
  assign n5837_o = ir == 8'b11000110;
  /* T80_MCode.vhd:1592:99  */
  assign n5838_o = n5835_o | n5837_o;
  /* T80_MCode.vhd:1592:110  */
  assign n5840_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1592:110  */
  assign n5841_o = n5838_o | n5840_o;
  /* T80_MCode.vhd:1593:33  */
  assign n5843_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1593:33  */
  assign n5844_o = n5841_o | n5843_o;
  /* T80_MCode.vhd:1593:44  */
  assign n5846_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1593:44  */
  assign n5847_o = n5844_o | n5846_o;
  /* T80_MCode.vhd:1593:55  */
  assign n5849_o = ir == 8'b11001010;
  /* T80_MCode.vhd:1593:55  */
  assign n5850_o = n5847_o | n5849_o;
  /* T80_MCode.vhd:1593:66  */
  assign n5852_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1593:66  */
  assign n5853_o = n5850_o | n5852_o;
  /* T80_MCode.vhd:1593:77  */
  assign n5855_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1593:77  */
  assign n5856_o = n5853_o | n5855_o;
  /* T80_MCode.vhd:1593:88  */
  assign n5858_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1593:88  */
  assign n5859_o = n5856_o | n5858_o;
  /* T80_MCode.vhd:1593:99  */
  assign n5861_o = ir == 8'b11001110;
  /* T80_MCode.vhd:1593:99  */
  assign n5862_o = n5859_o | n5861_o;
  /* T80_MCode.vhd:1593:110  */
  assign n5864_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1593:110  */
  assign n5865_o = n5862_o | n5864_o;
  /* T80_MCode.vhd:1594:33  */
  assign n5867_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1594:33  */
  assign n5868_o = n5865_o | n5867_o;
  /* T80_MCode.vhd:1594:44  */
  assign n5870_o = ir == 8'b11010001;
  /* T80_MCode.vhd:1594:44  */
  assign n5871_o = n5868_o | n5870_o;
  /* T80_MCode.vhd:1594:55  */
  assign n5873_o = ir == 8'b11010010;
  /* T80_MCode.vhd:1594:55  */
  assign n5874_o = n5871_o | n5873_o;
  /* T80_MCode.vhd:1594:66  */
  assign n5876_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1594:66  */
  assign n5877_o = n5874_o | n5876_o;
  /* T80_MCode.vhd:1594:77  */
  assign n5879_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1594:77  */
  assign n5880_o = n5877_o | n5879_o;
  /* T80_MCode.vhd:1594:88  */
  assign n5882_o = ir == 8'b11010101;
  /* T80_MCode.vhd:1594:88  */
  assign n5883_o = n5880_o | n5882_o;
  /* T80_MCode.vhd:1594:99  */
  assign n5885_o = ir == 8'b11010110;
  /* T80_MCode.vhd:1594:99  */
  assign n5886_o = n5883_o | n5885_o;
  /* T80_MCode.vhd:1594:110  */
  assign n5888_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1594:110  */
  assign n5889_o = n5886_o | n5888_o;
  /* T80_MCode.vhd:1595:33  */
  assign n5891_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1595:33  */
  assign n5892_o = n5889_o | n5891_o;
  /* T80_MCode.vhd:1595:44  */
  assign n5894_o = ir == 8'b11011001;
  /* T80_MCode.vhd:1595:44  */
  assign n5895_o = n5892_o | n5894_o;
  /* T80_MCode.vhd:1595:55  */
  assign n5897_o = ir == 8'b11011010;
  /* T80_MCode.vhd:1595:55  */
  assign n5898_o = n5895_o | n5897_o;
  /* T80_MCode.vhd:1595:66  */
  assign n5900_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1595:66  */
  assign n5901_o = n5898_o | n5900_o;
  /* T80_MCode.vhd:1595:77  */
  assign n5903_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1595:77  */
  assign n5904_o = n5901_o | n5903_o;
  /* T80_MCode.vhd:1595:88  */
  assign n5906_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1595:88  */
  assign n5907_o = n5904_o | n5906_o;
  /* T80_MCode.vhd:1595:99  */
  assign n5909_o = ir == 8'b11011110;
  /* T80_MCode.vhd:1595:99  */
  assign n5910_o = n5907_o | n5909_o;
  /* T80_MCode.vhd:1595:110  */
  assign n5912_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1595:110  */
  assign n5913_o = n5910_o | n5912_o;
  /* T80_MCode.vhd:1596:33  */
  assign n5915_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1596:33  */
  assign n5916_o = n5913_o | n5915_o;
  /* T80_MCode.vhd:1596:44  */
  assign n5918_o = ir == 8'b11100001;
  /* T80_MCode.vhd:1596:44  */
  assign n5919_o = n5916_o | n5918_o;
  /* T80_MCode.vhd:1596:55  */
  assign n5921_o = ir == 8'b11100010;
  /* T80_MCode.vhd:1596:55  */
  assign n5922_o = n5919_o | n5921_o;
  /* T80_MCode.vhd:1596:66  */
  assign n5924_o = ir == 8'b11100011;
  /* T80_MCode.vhd:1596:66  */
  assign n5925_o = n5922_o | n5924_o;
  /* T80_MCode.vhd:1596:77  */
  assign n5927_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1596:77  */
  assign n5928_o = n5925_o | n5927_o;
  /* T80_MCode.vhd:1596:88  */
  assign n5930_o = ir == 8'b11100101;
  /* T80_MCode.vhd:1596:88  */
  assign n5931_o = n5928_o | n5930_o;
  /* T80_MCode.vhd:1596:99  */
  assign n5933_o = ir == 8'b11100110;
  /* T80_MCode.vhd:1596:99  */
  assign n5934_o = n5931_o | n5933_o;
  /* T80_MCode.vhd:1596:110  */
  assign n5936_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1596:110  */
  assign n5937_o = n5934_o | n5936_o;
  /* T80_MCode.vhd:1597:33  */
  assign n5939_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1597:33  */
  assign n5940_o = n5937_o | n5939_o;
  /* T80_MCode.vhd:1597:44  */
  assign n5942_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1597:44  */
  assign n5943_o = n5940_o | n5942_o;
  /* T80_MCode.vhd:1597:55  */
  assign n5945_o = ir == 8'b11101010;
  /* T80_MCode.vhd:1597:55  */
  assign n5946_o = n5943_o | n5945_o;
  /* T80_MCode.vhd:1597:66  */
  assign n5948_o = ir == 8'b11101011;
  /* T80_MCode.vhd:1597:66  */
  assign n5949_o = n5946_o | n5948_o;
  /* T80_MCode.vhd:1597:77  */
  assign n5951_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1597:77  */
  assign n5952_o = n5949_o | n5951_o;
  /* T80_MCode.vhd:1597:88  */
  assign n5954_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1597:88  */
  assign n5955_o = n5952_o | n5954_o;
  /* T80_MCode.vhd:1597:99  */
  assign n5957_o = ir == 8'b11101110;
  /* T80_MCode.vhd:1597:99  */
  assign n5958_o = n5955_o | n5957_o;
  /* T80_MCode.vhd:1597:110  */
  assign n5960_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1597:110  */
  assign n5961_o = n5958_o | n5960_o;
  /* T80_MCode.vhd:1598:33  */
  assign n5963_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1598:33  */
  assign n5964_o = n5961_o | n5963_o;
  /* T80_MCode.vhd:1598:44  */
  assign n5966_o = ir == 8'b11110001;
  /* T80_MCode.vhd:1598:44  */
  assign n5967_o = n5964_o | n5966_o;
  /* T80_MCode.vhd:1598:55  */
  assign n5969_o = ir == 8'b11110010;
  /* T80_MCode.vhd:1598:55  */
  assign n5970_o = n5967_o | n5969_o;
  /* T80_MCode.vhd:1598:66  */
  assign n5972_o = ir == 8'b11110011;
  /* T80_MCode.vhd:1598:66  */
  assign n5973_o = n5970_o | n5972_o;
  /* T80_MCode.vhd:1598:77  */
  assign n5975_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1598:77  */
  assign n5976_o = n5973_o | n5975_o;
  /* T80_MCode.vhd:1598:88  */
  assign n5978_o = ir == 8'b11110101;
  /* T80_MCode.vhd:1598:88  */
  assign n5979_o = n5976_o | n5978_o;
  /* T80_MCode.vhd:1598:99  */
  assign n5981_o = ir == 8'b11110110;
  /* T80_MCode.vhd:1598:99  */
  assign n5982_o = n5979_o | n5981_o;
  /* T80_MCode.vhd:1598:110  */
  assign n5984_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1598:110  */
  assign n5985_o = n5982_o | n5984_o;
  /* T80_MCode.vhd:1599:33  */
  assign n5987_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1599:33  */
  assign n5988_o = n5985_o | n5987_o;
  /* T80_MCode.vhd:1599:44  */
  assign n5990_o = ir == 8'b11111001;
  /* T80_MCode.vhd:1599:44  */
  assign n5991_o = n5988_o | n5990_o;
  /* T80_MCode.vhd:1599:55  */
  assign n5993_o = ir == 8'b11111010;
  /* T80_MCode.vhd:1599:55  */
  assign n5994_o = n5991_o | n5993_o;
  /* T80_MCode.vhd:1599:66  */
  assign n5996_o = ir == 8'b11111011;
  /* T80_MCode.vhd:1599:66  */
  assign n5997_o = n5994_o | n5996_o;
  /* T80_MCode.vhd:1599:77  */
  assign n5999_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1599:77  */
  assign n6000_o = n5997_o | n5999_o;
  /* T80_MCode.vhd:1599:88  */
  assign n6002_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1599:88  */
  assign n6003_o = n6000_o | n6002_o;
  /* T80_MCode.vhd:1599:99  */
  assign n6005_o = ir == 8'b11111110;
  /* T80_MCode.vhd:1599:99  */
  assign n6006_o = n6003_o | n6005_o;
  /* T80_MCode.vhd:1599:110  */
  assign n6008_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1599:110  */
  assign n6009_o = n6006_o | n6008_o;
  /* T80_MCode.vhd:1601:25  */
  assign n6011_o = ir == 8'b01111110;
  /* T80_MCode.vhd:1601:40  */
  assign n6013_o = ir == 8'b01111111;
  /* T80_MCode.vhd:1601:40  */
  assign n6014_o = n6011_o | n6013_o;
  /* T80_MCode.vhd:1605:25  */
  assign n6016_o = ir == 8'b01010111;
  /* T80_MCode.vhd:1609:25  */
  assign n6018_o = ir == 8'b01011111;
  /* T80_MCode.vhd:1613:25  */
  assign n6020_o = ir == 8'b01000111;
  /* T80_MCode.vhd:1617:25  */
  assign n6022_o = ir == 8'b01001111;
  /* T80_MCode.vhd:1625:38  */
  assign n6023_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1626:33  */
  assign n6025_o = n6023_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1629:33  */
  assign n6027_o = n6023_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1635:46  */
  assign n6028_o = ir[5:4];
  /* T80_MCode.vhd:1635:59  */
  assign n6030_o = n6028_o == 2'b11;
  /* T80_MCode.vhd:1638:78  */
  assign n6031_o = ir[5:4];
  assign n6033_o = {n6031_o, 1'b1};
  /* T80_MCode.vhd:1635:41  */
  assign n6035_o = n6030_o ? 3'b000 : n6033_o;
  /* T80_MCode.vhd:1635:41  */
  assign n6038_o = n6030_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1633:33  */
  assign n6040_o = n6023_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1645:46  */
  assign n6041_o = ir[5:4];
  /* T80_MCode.vhd:1645:59  */
  assign n6043_o = n6041_o == 2'b11;
  /* T80_MCode.vhd:1648:78  */
  assign n6044_o = ir[5:4];
  assign n6046_o = {n6044_o, 1'b0};
  /* T80_MCode.vhd:1645:41  */
  assign n6048_o = n6043_o ? 3'b001 : n6046_o;
  /* T80_MCode.vhd:1645:41  */
  assign n6051_o = n6043_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1643:33  */
  assign n6053_o = n6023_o == 31'b0000000000000000000000000000101;
  assign n6054_o = {n6053_o, n6040_o, n6027_o, n6025_o};
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n6054_o)
      4'b1000: n6058_o = 1'b0;
      4'b0100: n6058_o = 1'b0;
      4'b0010: n6058_o = 1'b1;
      4'b0001: n6058_o = 1'b1;
      default: n6058_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n6054_o)
      4'b1000: n6061_o = 1'b0;
      4'b0100: n6061_o = 1'b1;
      4'b0010: n6061_o = 1'b0;
      4'b0001: n6061_o = 1'b0;
      default: n6061_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n6054_o)
      4'b1000: n6065_o = 1'b1;
      4'b0100: n6065_o = 1'b1;
      4'b0010: n6065_o = 1'b0;
      4'b0001: n6065_o = 1'b0;
      default: n6065_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n6054_o)
      4'b1000: n6067_o = n6048_o;
      4'b0100: n6067_o = n6035_o;
      4'b0010: n6067_o = 3'b000;
      4'b0001: n6067_o = 3'b000;
      default: n6067_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n6054_o)
      4'b1000: n6069_o = n6051_o;
      4'b0100: n6069_o = n6038_o;
      4'b0010: n6069_o = 1'b0;
      4'b0001: n6069_o = 1'b0;
      default: n6069_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n6054_o)
      4'b1000: n6073_o = 3'b111;
      4'b0100: n6073_o = 3'b110;
      4'b0010: n6073_o = 3'b110;
      4'b0001: n6073_o = 3'b111;
      default: n6073_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n6054_o)
      4'b1000: n6076_o = 1'b0;
      4'b0100: n6076_o = 1'b0;
      4'b0010: n6076_o = 1'b0;
      4'b0001: n6076_o = 1'b1;
      default: n6076_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n6054_o)
      4'b1000: n6079_o = 1'b0;
      4'b0100: n6079_o = 1'b0;
      4'b0010: n6079_o = 1'b1;
      4'b0001: n6079_o = 1'b0;
      default: n6079_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1622:25  */
  assign n6081_o = ir == 8'b01001011;
  /* T80_MCode.vhd:1622:40  */
  assign n6083_o = ir == 8'b01011011;
  /* T80_MCode.vhd:1622:40  */
  assign n6084_o = n6081_o | n6083_o;
  /* T80_MCode.vhd:1622:51  */
  assign n6086_o = ir == 8'b01101011;
  /* T80_MCode.vhd:1622:51  */
  assign n6087_o = n6084_o | n6086_o;
  /* T80_MCode.vhd:1622:62  */
  assign n6089_o = ir == 8'b01111011;
  /* T80_MCode.vhd:1622:62  */
  assign n6090_o = n6087_o | n6089_o;
  /* T80_MCode.vhd:1656:38  */
  assign n6091_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1657:33  */
  assign n6093_o = n6091_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1664:46  */
  assign n6094_o = ir[5:4];
  /* T80_MCode.vhd:1664:59  */
  assign n6096_o = n6094_o == 2'b11;
  /* T80_MCode.vhd:1667:78  */
  assign n6097_o = ir[5:4];
  assign n6100_o = {1'b0, n6097_o, 1'b1};
  /* T80_MCode.vhd:1664:41  */
  assign n6102_o = n6096_o ? 4'b1000 : n6100_o;
  /* T80_MCode.vhd:1660:33  */
  assign n6104_o = n6091_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1675:46  */
  assign n6105_o = ir[5:4];
  /* T80_MCode.vhd:1675:59  */
  assign n6107_o = n6105_o == 2'b11;
  /* T80_MCode.vhd:1678:78  */
  assign n6108_o = ir[5:4];
  assign n6111_o = {1'b0, n6108_o, 1'b0};
  /* T80_MCode.vhd:1675:41  */
  assign n6113_o = n6107_o ? 4'b1001 : n6111_o;
  /* T80_MCode.vhd:1671:33  */
  assign n6115_o = n6091_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1682:33  */
  assign n6117_o = n6091_o == 31'b0000000000000000000000000000101;
  assign n6118_o = {n6117_o, n6115_o, n6104_o, n6093_o};
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n6118_o)
      4'b1000: n6122_o = 1'b0;
      4'b0100: n6122_o = 1'b0;
      4'b0010: n6122_o = 1'b1;
      4'b0001: n6122_o = 1'b1;
      default: n6122_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n6118_o)
      4'b1000: n6125_o = 1'b0;
      4'b0100: n6125_o = 1'b1;
      4'b0010: n6125_o = 1'b0;
      4'b0001: n6125_o = 1'b0;
      default: n6125_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n6118_o)
      4'b1000: n6127_o = 4'b0000;
      4'b0100: n6127_o = n6113_o;
      4'b0010: n6127_o = n6102_o;
      4'b0001: n6127_o = 4'b0000;
      default: n6127_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n6118_o)
      4'b1000: n6131_o = 3'b111;
      4'b0100: n6131_o = 3'b110;
      4'b0010: n6131_o = 3'b110;
      4'b0001: n6131_o = 3'b111;
      default: n6131_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n6118_o)
      4'b1000: n6134_o = 1'b0;
      4'b0100: n6134_o = 1'b0;
      4'b0010: n6134_o = 1'b0;
      4'b0001: n6134_o = 1'b1;
      default: n6134_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n6118_o)
      4'b1000: n6137_o = 1'b0;
      4'b0100: n6137_o = 1'b0;
      4'b0010: n6137_o = 1'b1;
      4'b0001: n6137_o = 1'b0;
      default: n6137_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n6118_o)
      4'b1000: n6141_o = 1'b1;
      4'b0100: n6141_o = 1'b1;
      4'b0010: n6141_o = 1'b0;
      4'b0001: n6141_o = 1'b0;
      default: n6141_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1653:25  */
  assign n6143_o = ir == 8'b01000011;
  /* T80_MCode.vhd:1653:40  */
  assign n6145_o = ir == 8'b01010011;
  /* T80_MCode.vhd:1653:40  */
  assign n6146_o = n6143_o | n6145_o;
  /* T80_MCode.vhd:1653:51  */
  assign n6148_o = ir == 8'b01100011;
  /* T80_MCode.vhd:1653:51  */
  assign n6149_o = n6146_o | n6148_o;
  /* T80_MCode.vhd:1653:62  */
  assign n6151_o = ir == 8'b01110011;
  /* T80_MCode.vhd:1653:62  */
  assign n6152_o = n6149_o | n6151_o;
  /* T80_MCode.vhd:1689:38  */
  assign n6153_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1690:33  */
  assign n6155_o = n6153_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1698:46  */
  assign n6157_o = ir[3];
  /* T80_MCode.vhd:1698:50  */
  assign n6158_o = ~n6157_o;
  /* T80_MCode.vhd:1698:41  */
  assign n6161_o = n6158_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1693:33  */
  assign n6163_o = n6153_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1707:46  */
  assign n6164_o = ir[3];
  /* T80_MCode.vhd:1707:50  */
  assign n6165_o = ~n6164_o;
  /* T80_MCode.vhd:1707:41  */
  assign n6168_o = n6165_o ? 4'b0101 : 4'b1101;
  /* T80_MCode.vhd:1703:33  */
  assign n6170_o = n6153_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1712:33  */
  assign n6172_o = n6153_o == 31'b0000000000000000000000000000100;
  assign n6173_o = {n6172_o, n6170_o, n6163_o, n6155_o};
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n6173_o)
      4'b1000: n6176_o = 3'b101;
      4'b0100: n6176_o = 3'b101;
      4'b0010: n6176_o = n2200_o;
      4'b0001: n6176_o = n2200_o;
      default: n6176_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n6173_o)
      4'b1000: n6179_o = 4'b0000;
      4'b0100: n6179_o = n6168_o;
      4'b0010: n6179_o = n6161_o;
      4'b0001: n6179_o = 4'b1100;
      default: n6179_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n6173_o)
      4'b1000: n6181_o = 3'b000;
      4'b0100: n6181_o = 3'b000;
      4'b0010: n6181_o = 3'b111;
      4'b0001: n6181_o = 3'b000;
      default: n6181_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n6173_o)
      4'b1000: n6184_o = 4'b0000;
      4'b0100: n6184_o = 4'b0000;
      4'b0010: n6184_o = 4'b0110;
      4'b0001: n6184_o = 4'b0000;
      default: n6184_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n6173_o)
      4'b1000: n6186_o = n2203_o;
      4'b0100: n6186_o = n2203_o;
      4'b0010: n6186_o = 4'b0000;
      4'b0001: n6186_o = n2203_o;
      default: n6186_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n6173_o)
      4'b1000: n6190_o = 3'b111;
      4'b0100: n6190_o = 3'b111;
      4'b0010: n6190_o = 3'b001;
      4'b0001: n6190_o = 3'b010;
      default: n6190_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n6173_o)
      4'b1000: n6193_o = 1'b0;
      4'b0100: n6193_o = 1'b1;
      4'b0010: n6193_o = 1'b0;
      4'b0001: n6193_o = 1'b0;
      default: n6193_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n6173_o)
      4'b1000: n6196_o = 1'b1;
      4'b0100: n6196_o = 1'b0;
      4'b0010: n6196_o = 1'b0;
      4'b0001: n6196_o = 1'b0;
      default: n6196_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n6173_o)
      4'b1000: n6199_o = 1'b0;
      4'b0100: n6199_o = 1'b1;
      4'b0010: n6199_o = 1'b0;
      4'b0001: n6199_o = 1'b0;
      default: n6199_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1686:25  */
  assign n6201_o = ir == 8'b10100000;
  /* T80_MCode.vhd:1686:41  */
  assign n6203_o = ir == 8'b10101000;
  /* T80_MCode.vhd:1686:41  */
  assign n6204_o = n6201_o | n6203_o;
  /* T80_MCode.vhd:1686:54  */
  assign n6206_o = ir == 8'b10110000;
  /* T80_MCode.vhd:1686:54  */
  assign n6207_o = n6204_o | n6206_o;
  /* T80_MCode.vhd:1686:67  */
  assign n6209_o = ir == 8'b10111000;
  /* T80_MCode.vhd:1686:67  */
  assign n6210_o = n6207_o | n6209_o;
  /* T80_MCode.vhd:1720:38  */
  assign n6211_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1721:33  */
  assign n6213_o = n6211_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1730:46  */
  assign n6215_o = ir[3];
  /* T80_MCode.vhd:1730:50  */
  assign n6216_o = ~n6215_o;
  /* T80_MCode.vhd:1730:41  */
  assign n6219_o = n6216_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1724:33  */
  assign n6221_o = n6211_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1735:33  */
  assign n6223_o = n6211_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1739:33  */
  assign n6225_o = n6211_o == 31'b0000000000000000000000000000100;
  assign n6226_o = {n6225_o, n6223_o, n6221_o, n6213_o};
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6226_o)
      4'b1000: n6229_o = 3'b101;
      4'b0100: n6229_o = 3'b101;
      4'b0010: n6229_o = n2200_o;
      4'b0001: n6229_o = n2200_o;
      default: n6229_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6226_o)
      4'b1000: n6232_o = 4'b0000;
      4'b0100: n6232_o = 4'b0000;
      4'b0010: n6232_o = n6219_o;
      4'b0001: n6232_o = 4'b1100;
      default: n6232_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6226_o)
      4'b1000: n6234_o = 3'b000;
      4'b0100: n6234_o = 3'b000;
      4'b0010: n6234_o = 3'b111;
      4'b0001: n6234_o = 3'b000;
      default: n6234_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6226_o)
      4'b1000: n6237_o = 4'b0000;
      4'b0100: n6237_o = 4'b0000;
      4'b0010: n6237_o = 4'b0110;
      4'b0001: n6237_o = 4'b0000;
      default: n6237_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6226_o)
      4'b1000: n6239_o = n2203_o;
      4'b0100: n6239_o = n2203_o;
      4'b0010: n6239_o = 4'b0111;
      4'b0001: n6239_o = n2203_o;
      default: n6239_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6226_o)
      4'b1000: n6242_o = 1'b0;
      4'b0100: n6242_o = 1'b0;
      4'b0010: n6242_o = 1'b1;
      4'b0001: n6242_o = 1'b0;
      default: n6242_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6226_o)
      4'b1000: n6245_o = 1'b0;
      4'b0100: n6245_o = 1'b0;
      4'b0010: n6245_o = 1'b1;
      4'b0001: n6245_o = 1'b0;
      default: n6245_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6226_o)
      4'b1000: n6248_o = 3'b111;
      4'b0100: n6248_o = 3'b111;
      4'b0010: n6248_o = 3'b111;
      4'b0001: n6248_o = 3'b010;
      default: n6248_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6226_o)
      4'b1000: n6251_o = 1'b0;
      4'b0100: n6251_o = 1'b1;
      4'b0010: n6251_o = 1'b0;
      4'b0001: n6251_o = 1'b0;
      default: n6251_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6226_o)
      4'b1000: n6255_o = 1'b1;
      4'b0100: n6255_o = 1'b1;
      4'b0010: n6255_o = 1'b0;
      4'b0001: n6255_o = 1'b0;
      default: n6255_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1717:25  */
  assign n6257_o = ir == 8'b10100001;
  /* T80_MCode.vhd:1717:41  */
  assign n6259_o = ir == 8'b10101001;
  /* T80_MCode.vhd:1717:41  */
  assign n6260_o = n6257_o | n6259_o;
  /* T80_MCode.vhd:1717:54  */
  assign n6262_o = ir == 8'b10110001;
  /* T80_MCode.vhd:1717:54  */
  assign n6263_o = n6260_o | n6262_o;
  /* T80_MCode.vhd:1717:67  */
  assign n6265_o = ir == 8'b10111001;
  /* T80_MCode.vhd:1717:67  */
  assign n6266_o = n6263_o | n6265_o;
  /* T80_MCode.vhd:1744:25  */
  assign n6268_o = ir == 8'b01000100;
  /* T80_MCode.vhd:1744:40  */
  assign n6270_o = ir == 8'b01001100;
  /* T80_MCode.vhd:1744:40  */
  assign n6271_o = n6268_o | n6270_o;
  /* T80_MCode.vhd:1744:51  */
  assign n6273_o = ir == 8'b01010100;
  /* T80_MCode.vhd:1744:51  */
  assign n6274_o = n6271_o | n6273_o;
  /* T80_MCode.vhd:1744:62  */
  assign n6276_o = ir == 8'b01011100;
  /* T80_MCode.vhd:1744:62  */
  assign n6277_o = n6274_o | n6276_o;
  /* T80_MCode.vhd:1744:73  */
  assign n6279_o = ir == 8'b01100100;
  /* T80_MCode.vhd:1744:73  */
  assign n6280_o = n6277_o | n6279_o;
  /* T80_MCode.vhd:1744:84  */
  assign n6282_o = ir == 8'b01101100;
  /* T80_MCode.vhd:1744:84  */
  assign n6283_o = n6280_o | n6282_o;
  /* T80_MCode.vhd:1744:95  */
  assign n6285_o = ir == 8'b01110100;
  /* T80_MCode.vhd:1744:95  */
  assign n6286_o = n6283_o | n6285_o;
  /* T80_MCode.vhd:1744:106  */
  assign n6288_o = ir == 8'b01111100;
  /* T80_MCode.vhd:1744:106  */
  assign n6289_o = n6286_o | n6288_o;
  /* T80_MCode.vhd:1751:25  */
  assign n6291_o = ir == 8'b01000110;
  /* T80_MCode.vhd:1751:40  */
  assign n6293_o = ir == 8'b01001110;
  /* T80_MCode.vhd:1751:40  */
  assign n6294_o = n6291_o | n6293_o;
  /* T80_MCode.vhd:1751:51  */
  assign n6296_o = ir == 8'b01100110;
  /* T80_MCode.vhd:1751:51  */
  assign n6297_o = n6294_o | n6296_o;
  /* T80_MCode.vhd:1751:62  */
  assign n6299_o = ir == 8'b01101110;
  /* T80_MCode.vhd:1751:62  */
  assign n6300_o = n6297_o | n6299_o;
  /* T80_MCode.vhd:1754:25  */
  assign n6302_o = ir == 8'b01010110;
  /* T80_MCode.vhd:1754:40  */
  assign n6304_o = ir == 8'b01110110;
  /* T80_MCode.vhd:1754:40  */
  assign n6305_o = n6302_o | n6304_o;
  /* T80_MCode.vhd:1757:25  */
  assign n6307_o = ir == 8'b01011110;
  /* T80_MCode.vhd:1757:40  */
  assign n6309_o = ir == 8'b01110111;
  /* T80_MCode.vhd:1757:40  */
  assign n6310_o = n6307_o | n6309_o;
  /* T80_MCode.vhd:1764:38  */
  assign n6311_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1771:68  */
  assign n6313_o = ir[5:4];
  /* T80_MCode.vhd:1771:46  */
  assign n6314_o = {29'b0, n6313_o};  //  uext
  /* T80_MCode.vhd:1773:78  */
  assign n6315_o = ir[5:4];
  /* T80_MCode.vhd:1772:41  */
  assign n6318_o = n6314_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1772:47  */
  assign n6320_o = n6314_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1772:47  */
  assign n6321_o = n6318_o | n6320_o;
  /* T80_MCode.vhd:1772:49  */
  assign n6323_o = n6314_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1772:49  */
  assign n6324_o = n6321_o | n6323_o;
  /* T80_MCode.vhd:1771:41  */
  always @*
    case (n6324_o)
      1'b1: n6326_o = 1'b1;
      default: n6326_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1771:41  */
  always @*
    case (n6324_o)
      1'b1: n6328_o = n6315_o;
      default: n6328_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1771:41  */
  always @*
    case (n6324_o)
      1'b1: n6331_o = 1'b0;
      default: n6331_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1765:33  */
  assign n6333_o = n6311_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1786:68  */
  assign n6335_o = ir[5:4];
  /* T80_MCode.vhd:1786:46  */
  assign n6336_o = {29'b0, n6335_o};  //  uext
  /* T80_MCode.vhd:1788:78  */
  assign n6337_o = ir[5:4];
  /* T80_MCode.vhd:1787:41  */
  assign n6340_o = n6336_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1787:47  */
  assign n6342_o = n6336_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1787:47  */
  assign n6343_o = n6340_o | n6342_o;
  /* T80_MCode.vhd:1787:49  */
  assign n6345_o = n6336_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1787:49  */
  assign n6346_o = n6343_o | n6345_o;
  /* T80_MCode.vhd:1786:41  */
  always @*
    case (n6346_o)
      1'b1: n6348_o = 1'b0;
      default: n6348_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1786:41  */
  always @*
    case (n6346_o)
      1'b1: n6350_o = n6337_o;
      default: n6350_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1786:41  */
  always @*
    case (n6346_o)
      1'b1: n6353_o = 1'b0;
      default: n6353_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1780:33  */
  assign n6355_o = n6311_o == 31'b0000000000000000000000000000011;
  assign n6356_o = {n6355_o, n6333_o};
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6356_o)
      2'b10: n6358_o = n2200_o;
      2'b01: n6358_o = 3'b100;
      default: n6358_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6356_o)
      2'b10: n6362_o = 1'b1;
      2'b01: n6362_o = 1'b1;
      default: n6362_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6356_o)
      2'b10: n6364_o = 3'b100;
      2'b01: n6364_o = 3'b101;
      default: n6364_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6356_o)
      2'b10: n6366_o = n6348_o;
      2'b01: n6366_o = n6326_o;
      default: n6366_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6356_o)
      2'b10: n6368_o = n6350_o;
      2'b01: n6368_o = n6328_o;
      default: n6368_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6356_o)
      2'b10: n6370_o = n6353_o;
      2'b01: n6370_o = n6331_o;
      default: n6370_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6356_o)
      2'b10: n6373_o = 4'b0001;
      2'b01: n6373_o = 4'b0001;
      default: n6373_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6356_o)
      2'b10: n6377_o = 1'b1;
      2'b01: n6377_o = 1'b1;
      default: n6377_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6356_o)
      2'b10: n6380_o = 2'b00;
      2'b01: n6380_o = 2'b11;
      default: n6380_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6356_o)
      2'b10: n6384_o = 1'b1;
      2'b01: n6384_o = 1'b1;
      default: n6384_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1761:25  */
  assign n6386_o = ir == 8'b01001010;
  /* T80_MCode.vhd:1761:40  */
  assign n6388_o = ir == 8'b01011010;
  /* T80_MCode.vhd:1761:40  */
  assign n6389_o = n6386_o | n6388_o;
  /* T80_MCode.vhd:1761:51  */
  assign n6391_o = ir == 8'b01101010;
  /* T80_MCode.vhd:1761:51  */
  assign n6392_o = n6389_o | n6391_o;
  /* T80_MCode.vhd:1761:62  */
  assign n6394_o = ir == 8'b01111010;
  /* T80_MCode.vhd:1761:62  */
  assign n6395_o = n6392_o | n6394_o;
  /* T80_MCode.vhd:1798:38  */
  assign n6396_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1805:68  */
  assign n6398_o = ir[5:4];
  /* T80_MCode.vhd:1805:46  */
  assign n6399_o = {29'b0, n6398_o};  //  uext
  /* T80_MCode.vhd:1807:78  */
  assign n6400_o = ir[5:4];
  /* T80_MCode.vhd:1806:41  */
  assign n6403_o = n6399_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1806:47  */
  assign n6405_o = n6399_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1806:47  */
  assign n6406_o = n6403_o | n6405_o;
  /* T80_MCode.vhd:1806:49  */
  assign n6408_o = n6399_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1806:49  */
  assign n6409_o = n6406_o | n6408_o;
  /* T80_MCode.vhd:1805:41  */
  always @*
    case (n6409_o)
      1'b1: n6411_o = 1'b1;
      default: n6411_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1805:41  */
  always @*
    case (n6409_o)
      1'b1: n6413_o = n6400_o;
      default: n6413_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1805:41  */
  always @*
    case (n6409_o)
      1'b1: n6416_o = 1'b0;
      default: n6416_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1799:33  */
  assign n6418_o = n6396_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1820:68  */
  assign n6420_o = ir[5:4];
  /* T80_MCode.vhd:1820:46  */
  assign n6421_o = {29'b0, n6420_o};  //  uext
  /* T80_MCode.vhd:1822:78  */
  assign n6422_o = ir[5:4];
  /* T80_MCode.vhd:1821:41  */
  assign n6424_o = n6421_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1821:47  */
  assign n6426_o = n6421_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1821:47  */
  assign n6427_o = n6424_o | n6426_o;
  /* T80_MCode.vhd:1821:49  */
  assign n6429_o = n6421_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1821:49  */
  assign n6430_o = n6427_o | n6429_o;
  /* T80_MCode.vhd:1820:41  */
  always @*
    case (n6430_o)
      1'b1: n6433_o = 1'b0;
      default: n6433_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1820:41  */
  always @*
    case (n6430_o)
      1'b1: n6435_o = n6422_o;
      default: n6435_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1820:41  */
  always @*
    case (n6430_o)
      1'b1: n6438_o = 1'b0;
      default: n6438_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1814:33  */
  assign n6440_o = n6396_o == 31'b0000000000000000000000000000011;
  assign n6441_o = {n6440_o, n6418_o};
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6441_o)
      2'b10: n6443_o = n2200_o;
      2'b01: n6443_o = 3'b100;
      default: n6443_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6441_o)
      2'b10: n6447_o = 1'b1;
      2'b01: n6447_o = 1'b1;
      default: n6447_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6441_o)
      2'b10: n6449_o = 3'b100;
      2'b01: n6449_o = 3'b101;
      default: n6449_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6441_o)
      2'b10: n6451_o = n6433_o;
      2'b01: n6451_o = n6411_o;
      default: n6451_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6441_o)
      2'b10: n6453_o = n6435_o;
      2'b01: n6453_o = n6413_o;
      default: n6453_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6441_o)
      2'b10: n6455_o = n6438_o;
      2'b01: n6455_o = n6416_o;
      default: n6455_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6441_o)
      2'b10: n6458_o = 4'b0011;
      2'b01: n6458_o = 4'b0011;
      default: n6458_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6441_o)
      2'b10: n6462_o = 1'b1;
      2'b01: n6462_o = 1'b1;
      default: n6462_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6441_o)
      2'b10: n6465_o = 2'b00;
      2'b01: n6465_o = 2'b11;
      default: n6465_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6441_o)
      2'b10: n6469_o = 1'b1;
      2'b01: n6469_o = 1'b1;
      default: n6469_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1795:25  */
  assign n6471_o = ir == 8'b01000010;
  /* T80_MCode.vhd:1795:40  */
  assign n6473_o = ir == 8'b01010010;
  /* T80_MCode.vhd:1795:40  */
  assign n6474_o = n6471_o | n6473_o;
  /* T80_MCode.vhd:1795:51  */
  assign n6476_o = ir == 8'b01100010;
  /* T80_MCode.vhd:1795:51  */
  assign n6477_o = n6474_o | n6476_o;
  /* T80_MCode.vhd:1795:62  */
  assign n6479_o = ir == 8'b01110010;
  /* T80_MCode.vhd:1795:62  */
  assign n6480_o = n6477_o | n6479_o;
  /* T80_MCode.vhd:1831:38  */
  assign n6481_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1832:33  */
  assign n6483_o = n6481_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1834:33  */
  assign n6487_o = n6481_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1840:33  */
  assign n6489_o = n6481_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1845:33  */
  assign n6491_o = n6481_o == 31'b0000000000000000000000000000100;
  assign n6492_o = {n6491_o, n6489_o, n6487_o, n6483_o};
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6492_o)
      4'b1000: n6494_o = n2200_o;
      4'b0100: n6494_o = 3'b100;
      4'b0010: n6494_o = n2200_o;
      4'b0001: n6494_o = n2200_o;
      default: n6494_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6492_o)
      4'b1000: n6497_o = 1'b0;
      4'b0100: n6497_o = 1'b0;
      4'b0010: n6497_o = 1'b1;
      4'b0001: n6497_o = 1'b0;
      default: n6497_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6492_o)
      4'b1000: n6499_o = 3'b000;
      4'b0100: n6499_o = 3'b000;
      4'b0010: n6499_o = 3'b111;
      4'b0001: n6499_o = 3'b000;
      default: n6499_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6492_o)
      4'b1000: n6501_o = 3'b000;
      4'b0100: n6501_o = 3'b000;
      4'b0010: n6501_o = 3'b110;
      4'b0001: n6501_o = 3'b000;
      default: n6501_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6492_o)
      4'b1000: n6503_o = n2203_o;
      4'b0100: n6503_o = n2203_o;
      4'b0010: n6503_o = 4'b1101;
      4'b0001: n6503_o = n2203_o;
      default: n6503_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6492_o)
      4'b1000: n6506_o = 1'b0;
      4'b0100: n6506_o = 1'b0;
      4'b0010: n6506_o = 1'b1;
      4'b0001: n6506_o = 1'b0;
      default: n6506_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6492_o)
      4'b1000: n6510_o = 3'b111;
      4'b0100: n6510_o = 3'b010;
      4'b0010: n6510_o = 3'b111;
      4'b0001: n6510_o = 3'b010;
      default: n6510_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6492_o)
      4'b1000: n6513_o = 1'b0;
      4'b0100: n6513_o = 1'b1;
      4'b0010: n6513_o = 1'b0;
      4'b0001: n6513_o = 1'b0;
      default: n6513_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6492_o)
      4'b1000: n6516_o = 1'b0;
      4'b0100: n6516_o = 1'b1;
      4'b0010: n6516_o = 1'b0;
      4'b0001: n6516_o = 1'b0;
      default: n6516_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6492_o)
      4'b1000: n6519_o = 1'b1;
      4'b0100: n6519_o = 1'b0;
      4'b0010: n6519_o = 1'b0;
      4'b0001: n6519_o = 1'b0;
      default: n6519_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1828:25  */
  assign n6521_o = ir == 8'b01101111;
  /* T80_MCode.vhd:1852:38  */
  assign n6522_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1853:33  */
  assign n6524_o = n6522_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1855:33  */
  assign n6528_o = n6522_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1861:33  */
  assign n6530_o = n6522_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1866:33  */
  assign n6532_o = n6522_o == 31'b0000000000000000000000000000100;
  assign n6533_o = {n6532_o, n6530_o, n6528_o, n6524_o};
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6533_o)
      4'b1000: n6535_o = n2200_o;
      4'b0100: n6535_o = 3'b100;
      4'b0010: n6535_o = n2200_o;
      4'b0001: n6535_o = n2200_o;
      default: n6535_o = n2200_o;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6533_o)
      4'b1000: n6538_o = 1'b0;
      4'b0100: n6538_o = 1'b0;
      4'b0010: n6538_o = 1'b1;
      4'b0001: n6538_o = 1'b0;
      default: n6538_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6533_o)
      4'b1000: n6540_o = 3'b000;
      4'b0100: n6540_o = 3'b000;
      4'b0010: n6540_o = 3'b111;
      4'b0001: n6540_o = 3'b000;
      default: n6540_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6533_o)
      4'b1000: n6542_o = 3'b000;
      4'b0100: n6542_o = 3'b000;
      4'b0010: n6542_o = 3'b110;
      4'b0001: n6542_o = 3'b000;
      default: n6542_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6533_o)
      4'b1000: n6544_o = n2203_o;
      4'b0100: n6544_o = n2203_o;
      4'b0010: n6544_o = 4'b1110;
      4'b0001: n6544_o = n2203_o;
      default: n6544_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6533_o)
      4'b1000: n6547_o = 1'b0;
      4'b0100: n6547_o = 1'b0;
      4'b0010: n6547_o = 1'b1;
      4'b0001: n6547_o = 1'b0;
      default: n6547_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6533_o)
      4'b1000: n6551_o = 3'b111;
      4'b0100: n6551_o = 3'b010;
      4'b0010: n6551_o = 3'b111;
      4'b0001: n6551_o = 3'b010;
      default: n6551_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6533_o)
      4'b1000: n6554_o = 1'b0;
      4'b0100: n6554_o = 1'b1;
      4'b0010: n6554_o = 1'b0;
      4'b0001: n6554_o = 1'b0;
      default: n6554_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6533_o)
      4'b1000: n6557_o = 1'b0;
      4'b0100: n6557_o = 1'b1;
      4'b0010: n6557_o = 1'b0;
      4'b0001: n6557_o = 1'b0;
      default: n6557_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6533_o)
      4'b1000: n6560_o = 1'b1;
      4'b0100: n6560_o = 1'b0;
      4'b0010: n6560_o = 1'b0;
      4'b0001: n6560_o = 1'b0;
      default: n6560_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1849:25  */
  assign n6562_o = ir == 8'b01100111;
  /* T80_MCode.vhd:1873:38  */
  assign n6563_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1874:33  */
  assign n6565_o = n6563_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1876:33  */
  assign n6567_o = n6563_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1880:33  */
  assign n6569_o = n6563_o == 31'b0000000000000000000000000000011;
  assign n6570_o = {n6569_o, n6567_o, n6565_o};
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6570_o)
      3'b100: n6574_o = 4'b0111;
      3'b010: n6574_o = 4'b0111;
      3'b001: n6574_o = 4'b0000;
      default: n6574_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6570_o)
      3'b100: n6578_o = 3'b111;
      3'b010: n6578_o = 3'b101;
      3'b001: n6578_o = 3'b101;
      default: n6578_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6570_o)
      3'b100: n6581_o = 1'b1;
      3'b010: n6581_o = 1'b0;
      3'b001: n6581_o = 1'b0;
      default: n6581_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6570_o)
      3'b100: n6584_o = 1'b0;
      3'b010: n6584_o = 1'b1;
      3'b001: n6584_o = 1'b0;
      default: n6584_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6570_o)
      3'b100: n6587_o = 1'b1;
      3'b010: n6587_o = 1'b0;
      3'b001: n6587_o = 1'b0;
      default: n6587_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6570_o)
      3'b100: n6590_o = 1'b1;
      3'b010: n6590_o = 1'b0;
      3'b001: n6590_o = 1'b0;
      default: n6590_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1870:25  */
  assign n6592_o = ir == 8'b01000101;
  /* T80_MCode.vhd:1870:40  */
  assign n6594_o = ir == 8'b01001101;
  /* T80_MCode.vhd:1870:40  */
  assign n6595_o = n6592_o | n6594_o;
  /* T80_MCode.vhd:1870:51  */
  assign n6597_o = ir == 8'b01010101;
  /* T80_MCode.vhd:1870:51  */
  assign n6598_o = n6595_o | n6597_o;
  /* T80_MCode.vhd:1870:62  */
  assign n6600_o = ir == 8'b01011101;
  /* T80_MCode.vhd:1870:62  */
  assign n6601_o = n6598_o | n6600_o;
  /* T80_MCode.vhd:1870:73  */
  assign n6603_o = ir == 8'b01100101;
  /* T80_MCode.vhd:1870:73  */
  assign n6604_o = n6601_o | n6603_o;
  /* T80_MCode.vhd:1870:84  */
  assign n6606_o = ir == 8'b01101101;
  /* T80_MCode.vhd:1870:84  */
  assign n6607_o = n6604_o | n6606_o;
  /* T80_MCode.vhd:1870:95  */
  assign n6609_o = ir == 8'b01110101;
  /* T80_MCode.vhd:1870:95  */
  assign n6610_o = n6607_o | n6609_o;
  /* T80_MCode.vhd:1870:106  */
  assign n6612_o = ir == 8'b01111101;
  /* T80_MCode.vhd:1870:106  */
  assign n6613_o = n6610_o | n6612_o;
  /* T80_MCode.vhd:1890:38  */
  assign n6614_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1891:33  */
  assign n6616_o = n6614_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1896:46  */
  assign n6617_o = ir[5:3];
  /* T80_MCode.vhd:1896:59  */
  assign n6619_o = n6617_o != 3'b110;
  /* T80_MCode.vhd:1898:78  */
  assign n6620_o = ir[5:3];
  /* T80_MCode.vhd:1896:41  */
  assign n6623_o = n6619_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1896:41  */
  assign n6625_o = n6619_o ? n6620_o : 3'b000;
  /* T80_MCode.vhd:1894:33  */
  assign n6627_o = n6614_o == 31'b0000000000000000000000000000010;
  assign n6628_o = {n6627_o, n6616_o};
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6628_o)
      2'b10: n6630_o = n6623_o;
      2'b01: n6630_o = 1'b0;
      default: n6630_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6628_o)
      2'b10: n6632_o = n6625_o;
      2'b01: n6632_o = 3'b000;
      default: n6632_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6628_o)
      2'b10: n6635_o = 3'b111;
      2'b01: n6635_o = 3'b000;
      default: n6635_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6628_o)
      2'b10: n6638_o = 1'b1;
      2'b01: n6638_o = 1'b0;
      default: n6638_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6628_o)
      2'b10: n6641_o = 1'b1;
      2'b01: n6641_o = 1'b0;
      default: n6641_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6628_o)
      2'b10: n6644_o = 2'b00;
      2'b01: n6644_o = 2'b01;
      default: n6644_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1887:25  */
  assign n6646_o = ir == 8'b01000000;
  /* T80_MCode.vhd:1887:40  */
  assign n6648_o = ir == 8'b01001000;
  /* T80_MCode.vhd:1887:40  */
  assign n6649_o = n6646_o | n6648_o;
  /* T80_MCode.vhd:1887:51  */
  assign n6651_o = ir == 8'b01010000;
  /* T80_MCode.vhd:1887:51  */
  assign n6652_o = n6649_o | n6651_o;
  /* T80_MCode.vhd:1887:62  */
  assign n6654_o = ir == 8'b01011000;
  /* T80_MCode.vhd:1887:62  */
  assign n6655_o = n6652_o | n6654_o;
  /* T80_MCode.vhd:1887:73  */
  assign n6657_o = ir == 8'b01100000;
  /* T80_MCode.vhd:1887:73  */
  assign n6658_o = n6655_o | n6657_o;
  /* T80_MCode.vhd:1887:84  */
  assign n6660_o = ir == 8'b01101000;
  /* T80_MCode.vhd:1887:84  */
  assign n6661_o = n6658_o | n6660_o;
  /* T80_MCode.vhd:1887:95  */
  assign n6663_o = ir == 8'b01110000;
  /* T80_MCode.vhd:1887:95  */
  assign n6664_o = n6661_o | n6663_o;
  /* T80_MCode.vhd:1887:106  */
  assign n6666_o = ir == 8'b01111000;
  /* T80_MCode.vhd:1887:106  */
  assign n6667_o = n6664_o | n6666_o;
  /* T80_MCode.vhd:1907:38  */
  assign n6668_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1911:78  */
  assign n6669_o = ir[5:3];
  /* T80_MCode.vhd:1912:46  */
  assign n6670_o = ir[5:3];
  /* T80_MCode.vhd:1912:59  */
  assign n6672_o = n6670_o == 3'b110;
  /* T80_MCode.vhd:1912:41  */
  assign n6675_o = n6672_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1908:33  */
  assign n6677_o = n6668_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1915:33  */
  assign n6679_o = n6668_o == 31'b0000000000000000000000000000010;
  assign n6680_o = {n6679_o, n6677_o};
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6680_o)
      2'b10: n6682_o = 3'b000;
      2'b01: n6682_o = n6669_o;
      default: n6682_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6680_o)
      2'b10: n6684_o = 1'b0;
      2'b01: n6684_o = n6675_o;
      default: n6684_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6680_o)
      2'b10: n6687_o = 3'b111;
      2'b01: n6687_o = 3'b000;
      default: n6687_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6680_o)
      2'b10: n6690_o = 1'b1;
      2'b01: n6690_o = 1'b0;
      default: n6690_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6680_o)
      2'b10: n6693_o = 2'b00;
      2'b01: n6693_o = 2'b01;
      default: n6693_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6680_o)
      2'b10: n6696_o = 1'b1;
      2'b01: n6696_o = 1'b0;
      default: n6696_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1903:25  */
  assign n6698_o = ir == 8'b01000001;
  /* T80_MCode.vhd:1903:40  */
  assign n6700_o = ir == 8'b01001001;
  /* T80_MCode.vhd:1903:40  */
  assign n6701_o = n6698_o | n6700_o;
  /* T80_MCode.vhd:1903:51  */
  assign n6703_o = ir == 8'b01010001;
  /* T80_MCode.vhd:1903:51  */
  assign n6704_o = n6701_o | n6703_o;
  /* T80_MCode.vhd:1903:62  */
  assign n6706_o = ir == 8'b01011001;
  /* T80_MCode.vhd:1903:62  */
  assign n6707_o = n6704_o | n6706_o;
  /* T80_MCode.vhd:1903:73  */
  assign n6709_o = ir == 8'b01100001;
  /* T80_MCode.vhd:1903:73  */
  assign n6710_o = n6707_o | n6709_o;
  /* T80_MCode.vhd:1903:84  */
  assign n6712_o = ir == 8'b01101001;
  /* T80_MCode.vhd:1903:84  */
  assign n6713_o = n6710_o | n6712_o;
  /* T80_MCode.vhd:1903:95  */
  assign n6715_o = ir == 8'b01110001;
  /* T80_MCode.vhd:1903:95  */
  assign n6716_o = n6713_o | n6715_o;
  /* T80_MCode.vhd:1903:106  */
  assign n6718_o = ir == 8'b01111001;
  /* T80_MCode.vhd:1903:106  */
  assign n6719_o = n6716_o | n6718_o;
  /* T80_MCode.vhd:1923:38  */
  assign n6720_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1933:59  */
  assign n6721_o = ir[3];
  /* T80_MCode.vhd:1924:33  */
  assign n6723_o = n6720_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1934:33  */
  assign n6725_o = n6720_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1939:46  */
  assign n6726_o = ir[3];
  /* T80_MCode.vhd:1939:50  */
  assign n6727_o = ~n6726_o;
  /* T80_MCode.vhd:1939:41  */
  assign n6730_o = n6727_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1938:33  */
  assign n6732_o = n6720_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1946:33  */
  assign n6734_o = n6720_o == 31'b0000000000000000000000000000100;
  assign n6735_o = {n6734_o, n6732_o, n6725_o, n6723_o};
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6738_o = 3'b101;
      4'b0100: n6738_o = n2200_o;
      4'b0010: n6738_o = n2200_o;
      4'b0001: n6738_o = 3'b101;
      default: n6738_o = n2200_o;
    endcase
  assign n6739_o = n6730_o[2:0];
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6741_o = 3'b000;
      4'b0100: n6741_o = n6739_o;
      4'b0010: n6741_o = 3'b000;
      4'b0001: n6741_o = 3'b000;
      default: n6741_o = 3'b000;
    endcase
  assign n6742_o = n6730_o[3];
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6744_o = 1'b0;
      4'b0100: n6744_o = n6742_o;
      4'b0010: n6744_o = 1'b0;
      4'b0001: n6744_o = n6721_o;
      default: n6744_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6747_o = 1'b0;
      4'b0100: n6747_o = 1'b0;
      4'b0010: n6747_o = 1'b0;
      4'b0001: n6747_o = 1'b1;
      default: n6747_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6750_o = 4'b0000;
      4'b0100: n6750_o = 4'b0000;
      4'b0010: n6750_o = 4'b0000;
      4'b0001: n6750_o = 4'b0000;
      default: n6750_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6754_o = 4'b0000;
      4'b0100: n6754_o = 4'b0000;
      4'b0010: n6754_o = 4'b0110;
      4'b0001: n6754_o = 4'b1010;
      default: n6754_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6756_o = n2203_o;
      4'b0100: n6756_o = n2203_o;
      4'b0010: n6756_o = n2203_o;
      4'b0001: n6756_o = 4'b0010;
      default: n6756_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6759_o = 1'b0;
      4'b0100: n6759_o = 1'b0;
      4'b0010: n6759_o = 1'b0;
      4'b0001: n6759_o = 1'b1;
      default: n6759_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6763_o = 3'b111;
      4'b0100: n6763_o = 3'b111;
      4'b0010: n6763_o = 3'b010;
      4'b0001: n6763_o = 3'b000;
      default: n6763_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6766_o = 1'b0;
      4'b0100: n6766_o = 1'b0;
      4'b0010: n6766_o = 1'b1;
      4'b0001: n6766_o = 1'b0;
      default: n6766_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6769_o = 1'b0;
      4'b0100: n6769_o = 1'b1;
      4'b0010: n6769_o = 1'b0;
      4'b0001: n6769_o = 1'b0;
      default: n6769_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6772_o = 2'b00;
      4'b0100: n6772_o = 2'b00;
      4'b0010: n6772_o = 2'b00;
      4'b0001: n6772_o = 2'b11;
      default: n6772_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6775_o = 1'b1;
      4'b0100: n6775_o = 1'b0;
      4'b0010: n6775_o = 1'b0;
      4'b0001: n6775_o = 1'b0;
      default: n6775_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6735_o)
      4'b1000: n6778_o = 1'b0;
      4'b0100: n6778_o = 1'b1;
      4'b0010: n6778_o = 1'b0;
      4'b0001: n6778_o = 1'b0;
      default: n6778_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1920:25  */
  assign n6780_o = ir == 8'b10100010;
  /* T80_MCode.vhd:1920:41  */
  assign n6782_o = ir == 8'b10101010;
  /* T80_MCode.vhd:1920:41  */
  assign n6783_o = n6780_o | n6782_o;
  /* T80_MCode.vhd:1920:54  */
  assign n6785_o = ir == 8'b10110010;
  /* T80_MCode.vhd:1920:54  */
  assign n6786_o = n6783_o | n6785_o;
  /* T80_MCode.vhd:1920:67  */
  assign n6788_o = ir == 8'b10111010;
  /* T80_MCode.vhd:1920:67  */
  assign n6789_o = n6786_o | n6788_o;
  /* T80_MCode.vhd:1954:38  */
  assign n6790_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1955:33  */
  assign n6792_o = n6790_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1967:59  */
  assign n6793_o = ir[3];
  /* T80_MCode.vhd:1963:33  */
  assign n6795_o = n6790_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1969:46  */
  assign n6796_o = ir[3];
  /* T80_MCode.vhd:1969:50  */
  assign n6797_o = ~n6796_o;
  /* T80_MCode.vhd:1969:41  */
  assign n6800_o = n6797_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1968:33  */
  assign n6802_o = n6790_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1977:33  */
  assign n6804_o = n6790_o == 31'b0000000000000000000000000000100;
  assign n6805_o = {n6804_o, n6802_o, n6795_o, n6792_o};
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6808_o = 3'b101;
      4'b0100: n6808_o = n2200_o;
      4'b0010: n6808_o = n2200_o;
      4'b0001: n6808_o = 3'b101;
      default: n6808_o = n2200_o;
    endcase
  assign n6809_o = n6800_o[2:0];
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6811_o = 3'b000;
      4'b0100: n6811_o = n6809_o;
      4'b0010: n6811_o = 3'b000;
      4'b0001: n6811_o = 3'b000;
      default: n6811_o = 3'b000;
    endcase
  assign n6812_o = n6800_o[3];
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6814_o = 1'b0;
      4'b0100: n6814_o = n6812_o;
      4'b0010: n6814_o = n6793_o;
      4'b0001: n6814_o = 1'b0;
      default: n6814_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6817_o = 1'b0;
      4'b0100: n6817_o = 1'b0;
      4'b0010: n6817_o = 1'b0;
      4'b0001: n6817_o = 1'b1;
      default: n6817_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6820_o = 4'b0000;
      4'b0100: n6820_o = 4'b0000;
      4'b0010: n6820_o = 4'b0000;
      4'b0001: n6820_o = 4'b0000;
      default: n6820_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6824_o = 4'b0000;
      4'b0100: n6824_o = 4'b0000;
      4'b0010: n6824_o = 4'b0110;
      4'b0001: n6824_o = 4'b1010;
      default: n6824_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6826_o = n2203_o;
      4'b0100: n6826_o = n2203_o;
      4'b0010: n6826_o = n2203_o;
      4'b0001: n6826_o = 4'b0010;
      default: n6826_o = n2203_o;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6829_o = 1'b0;
      4'b0100: n6829_o = 1'b0;
      4'b0010: n6829_o = 1'b0;
      4'b0001: n6829_o = 1'b1;
      default: n6829_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6833_o = 3'b111;
      4'b0100: n6833_o = 3'b111;
      4'b0010: n6833_o = 3'b000;
      4'b0001: n6833_o = 3'b010;
      default: n6833_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6836_o = 1'b0;
      4'b0100: n6836_o = 1'b1;
      4'b0010: n6836_o = 1'b0;
      4'b0001: n6836_o = 1'b0;
      default: n6836_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6839_o = 1'b0;
      4'b0100: n6839_o = 1'b1;
      4'b0010: n6839_o = 1'b0;
      4'b0001: n6839_o = 1'b0;
      default: n6839_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6842_o = 2'b00;
      4'b0100: n6842_o = 2'b00;
      4'b0010: n6842_o = 2'b11;
      4'b0001: n6842_o = 2'b00;
      default: n6842_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6845_o = 1'b1;
      4'b0100: n6845_o = 1'b0;
      4'b0010: n6845_o = 1'b0;
      4'b0001: n6845_o = 1'b0;
      default: n6845_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6805_o)
      4'b1000: n6848_o = 1'b0;
      4'b0100: n6848_o = 1'b1;
      4'b0010: n6848_o = 1'b0;
      4'b0001: n6848_o = 1'b0;
      default: n6848_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1951:25  */
  assign n6850_o = ir == 8'b10100011;
  /* T80_MCode.vhd:1951:41  */
  assign n6852_o = ir == 8'b10101011;
  /* T80_MCode.vhd:1951:41  */
  assign n6853_o = n6850_o | n6852_o;
  /* T80_MCode.vhd:1951:54  */
  assign n6855_o = ir == 8'b10110011;
  /* T80_MCode.vhd:1951:54  */
  assign n6856_o = n6853_o | n6855_o;
  /* T80_MCode.vhd:1951:67  */
  assign n6858_o = ir == 8'b10111011;
  /* T80_MCode.vhd:1951:67  */
  assign n6859_o = n6856_o | n6858_o;
  assign n6860_o = {n6859_o, n6789_o, n6719_o, n6667_o, n6613_o, n6562_o, n6521_o, n6480_o, n6395_o, n6310_o, n6305_o, n6300_o, n6289_o, n6266_o, n6210_o, n6152_o, n6090_o, n6022_o, n6020_o, n6018_o, n6016_o, n6014_o, n6009_o};
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6876_o = 3'b100;
      23'b01000000000000000000000: n6876_o = 3'b100;
      23'b00100000000000000000000: n6876_o = 3'b010;
      23'b00010000000000000000000: n6876_o = 3'b010;
      23'b00001000000000000000000: n6876_o = 3'b011;
      23'b00000100000000000000000: n6876_o = 3'b100;
      23'b00000010000000000000000: n6876_o = 3'b100;
      23'b00000001000000000000000: n6876_o = 3'b011;
      23'b00000000100000000000000: n6876_o = 3'b011;
      23'b00000000010000000000000: n6876_o = 3'b001;
      23'b00000000001000000000000: n6876_o = 3'b001;
      23'b00000000000100000000000: n6876_o = 3'b001;
      23'b00000000000010000000000: n6876_o = 3'b001;
      23'b00000000000001000000000: n6876_o = 3'b100;
      23'b00000000000000100000000: n6876_o = 3'b100;
      23'b00000000000000010000000: n6876_o = 3'b101;
      23'b00000000000000001000000: n6876_o = 3'b101;
      23'b00000000000000000100000: n6876_o = 3'b001;
      23'b00000000000000000010000: n6876_o = 3'b001;
      23'b00000000000000000001000: n6876_o = 3'b001;
      23'b00000000000000000000100: n6876_o = 3'b001;
      23'b00000000000000000000010: n6876_o = 3'b001;
      23'b00000000000000000000001: n6876_o = 3'b001;
      default: n6876_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6882_o = n6808_o;
      23'b01000000000000000000000: n6882_o = n6738_o;
      23'b00100000000000000000000: n6882_o = n2200_o;
      23'b00010000000000000000000: n6882_o = n2200_o;
      23'b00001000000000000000000: n6882_o = n2200_o;
      23'b00000100000000000000000: n6882_o = n6535_o;
      23'b00000010000000000000000: n6882_o = n6494_o;
      23'b00000001000000000000000: n6882_o = n6443_o;
      23'b00000000100000000000000: n6882_o = n6358_o;
      23'b00000000010000000000000: n6882_o = n2200_o;
      23'b00000000001000000000000: n6882_o = n2200_o;
      23'b00000000000100000000000: n6882_o = n2200_o;
      23'b00000000000010000000000: n6882_o = n2200_o;
      23'b00000000000001000000000: n6882_o = n6229_o;
      23'b00000000000000100000000: n6882_o = n6176_o;
      23'b00000000000000010000000: n6882_o = n2200_o;
      23'b00000000000000001000000: n6882_o = n2200_o;
      23'b00000000000000000100000: n6882_o = 3'b101;
      23'b00000000000000000010000: n6882_o = 3'b101;
      23'b00000000000000000001000: n6882_o = 3'b101;
      23'b00000000000000000000100: n6882_o = 3'b101;
      23'b00000000000000000000010: n6882_o = n2200_o;
      23'b00000000000000000000001: n6882_o = n2200_o;
      default: n6882_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6885_o = 1'b0;
      23'b01000000000000000000000: n6885_o = 1'b0;
      23'b00100000000000000000000: n6885_o = 1'b0;
      23'b00010000000000000000000: n6885_o = 1'b0;
      23'b00001000000000000000000: n6885_o = 1'b0;
      23'b00000100000000000000000: n6885_o = 1'b0;
      23'b00000010000000000000000: n6885_o = 1'b0;
      23'b00000001000000000000000: n6885_o = 1'b0;
      23'b00000000100000000000000: n6885_o = 1'b0;
      23'b00000000010000000000000: n6885_o = 1'b0;
      23'b00000000001000000000000: n6885_o = 1'b0;
      23'b00000000000100000000000: n6885_o = 1'b0;
      23'b00000000000010000000000: n6885_o = 1'b0;
      23'b00000000000001000000000: n6885_o = 1'b0;
      23'b00000000000000100000000: n6885_o = 1'b0;
      23'b00000000000000010000000: n6885_o = n6122_o;
      23'b00000000000000001000000: n6885_o = n6058_o;
      23'b00000000000000000100000: n6885_o = 1'b0;
      23'b00000000000000000010000: n6885_o = 1'b0;
      23'b00000000000000000001000: n6885_o = 1'b0;
      23'b00000000000000000000100: n6885_o = 1'b0;
      23'b00000000000000000000010: n6885_o = 1'b0;
      23'b00000000000000000000001: n6885_o = 1'b0;
      default: n6885_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6888_o = 1'b0;
      23'b01000000000000000000000: n6888_o = 1'b0;
      23'b00100000000000000000000: n6888_o = 1'b0;
      23'b00010000000000000000000: n6888_o = 1'b0;
      23'b00001000000000000000000: n6888_o = 1'b0;
      23'b00000100000000000000000: n6888_o = 1'b0;
      23'b00000010000000000000000: n6888_o = 1'b0;
      23'b00000001000000000000000: n6888_o = 1'b0;
      23'b00000000100000000000000: n6888_o = 1'b0;
      23'b00000000010000000000000: n6888_o = 1'b0;
      23'b00000000001000000000000: n6888_o = 1'b0;
      23'b00000000000100000000000: n6888_o = 1'b0;
      23'b00000000000010000000000: n6888_o = 1'b0;
      23'b00000000000001000000000: n6888_o = 1'b0;
      23'b00000000000000100000000: n6888_o = 1'b0;
      23'b00000000000000010000000: n6888_o = n6125_o;
      23'b00000000000000001000000: n6888_o = n6061_o;
      23'b00000000000000000100000: n6888_o = 1'b0;
      23'b00000000000000000010000: n6888_o = 1'b0;
      23'b00000000000000000001000: n6888_o = 1'b0;
      23'b00000000000000000000100: n6888_o = 1'b0;
      23'b00000000000000000000010: n6888_o = 1'b0;
      23'b00000000000000000000001: n6888_o = 1'b0;
      default: n6888_o = 1'bX;
    endcase
  assign n6889_o = n6179_o[2:0];
  assign n6890_o = n6232_o[2:0];
  assign n6891_o = n6574_o[2:0];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6894_o = n6811_o;
      23'b01000000000000000000000: n6894_o = n6741_o;
      23'b00100000000000000000000: n6894_o = 3'b000;
      23'b00010000000000000000000: n6894_o = 3'b000;
      23'b00001000000000000000000: n6894_o = n6891_o;
      23'b00000100000000000000000: n6894_o = 3'b000;
      23'b00000010000000000000000: n6894_o = 3'b000;
      23'b00000001000000000000000: n6894_o = 3'b000;
      23'b00000000100000000000000: n6894_o = 3'b000;
      23'b00000000010000000000000: n6894_o = 3'b000;
      23'b00000000001000000000000: n6894_o = 3'b000;
      23'b00000000000100000000000: n6894_o = 3'b000;
      23'b00000000000010000000000: n6894_o = 3'b000;
      23'b00000000000001000000000: n6894_o = n6890_o;
      23'b00000000000000100000000: n6894_o = n6889_o;
      23'b00000000000000010000000: n6894_o = 3'b000;
      23'b00000000000000001000000: n6894_o = 3'b000;
      23'b00000000000000000100000: n6894_o = 3'b000;
      23'b00000000000000000010000: n6894_o = 3'b000;
      23'b00000000000000000001000: n6894_o = 3'b000;
      23'b00000000000000000000100: n6894_o = 3'b000;
      23'b00000000000000000000010: n6894_o = 3'b000;
      23'b00000000000000000000001: n6894_o = 3'b000;
      default: n6894_o = 3'bX;
    endcase
  assign n6895_o = n6179_o[3];
  assign n6896_o = n6232_o[3];
  assign n6897_o = n6574_o[3];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6900_o = n6814_o;
      23'b01000000000000000000000: n6900_o = n6744_o;
      23'b00100000000000000000000: n6900_o = 1'b0;
      23'b00010000000000000000000: n6900_o = 1'b0;
      23'b00001000000000000000000: n6900_o = n6897_o;
      23'b00000100000000000000000: n6900_o = 1'b0;
      23'b00000010000000000000000: n6900_o = 1'b0;
      23'b00000001000000000000000: n6900_o = 1'b0;
      23'b00000000100000000000000: n6900_o = 1'b0;
      23'b00000000010000000000000: n6900_o = 1'b0;
      23'b00000000001000000000000: n6900_o = 1'b0;
      23'b00000000000100000000000: n6900_o = 1'b0;
      23'b00000000000010000000000: n6900_o = 1'b0;
      23'b00000000000001000000000: n6900_o = n6896_o;
      23'b00000000000000100000000: n6900_o = n6895_o;
      23'b00000000000000010000000: n6900_o = 1'b0;
      23'b00000000000000001000000: n6900_o = 1'b0;
      23'b00000000000000000100000: n6900_o = 1'b0;
      23'b00000000000000000010000: n6900_o = 1'b0;
      23'b00000000000000000001000: n6900_o = 1'b0;
      23'b00000000000000000000100: n6900_o = 1'b0;
      23'b00000000000000000000010: n6900_o = 1'b0;
      23'b00000000000000000000001: n6900_o = 1'b0;
      default: n6900_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6903_o = n6817_o;
      23'b01000000000000000000000: n6903_o = n6747_o;
      23'b00100000000000000000000: n6903_o = 1'b0;
      23'b00010000000000000000000: n6903_o = n6630_o;
      23'b00001000000000000000000: n6903_o = 1'b0;
      23'b00000100000000000000000: n6903_o = n6538_o;
      23'b00000010000000000000000: n6903_o = n6497_o;
      23'b00000001000000000000000: n6903_o = n6447_o;
      23'b00000000100000000000000: n6903_o = n6362_o;
      23'b00000000010000000000000: n6903_o = 1'b0;
      23'b00000000001000000000000: n6903_o = 1'b0;
      23'b00000000000100000000000: n6903_o = 1'b0;
      23'b00000000000010000000000: n6903_o = 1'b0;
      23'b00000000000001000000000: n6903_o = 1'b0;
      23'b00000000000000100000000: n6903_o = 1'b0;
      23'b00000000000000010000000: n6903_o = 1'b0;
      23'b00000000000000001000000: n6903_o = n6065_o;
      23'b00000000000000000100000: n6903_o = 1'b0;
      23'b00000000000000000010000: n6903_o = 1'b0;
      23'b00000000000000000001000: n6903_o = 1'b0;
      23'b00000000000000000000100: n6903_o = 1'b0;
      23'b00000000000000000000010: n6903_o = 1'b0;
      23'b00000000000000000000001: n6903_o = 1'b0;
      default: n6903_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6907_o = 1'b0;
      23'b01000000000000000000000: n6907_o = 1'b0;
      23'b00100000000000000000000: n6907_o = 1'b0;
      23'b00010000000000000000000: n6907_o = 1'b0;
      23'b00001000000000000000000: n6907_o = 1'b0;
      23'b00000100000000000000000: n6907_o = 1'b0;
      23'b00000010000000000000000: n6907_o = 1'b0;
      23'b00000001000000000000000: n6907_o = 1'b0;
      23'b00000000100000000000000: n6907_o = 1'b0;
      23'b00000000010000000000000: n6907_o = 1'b0;
      23'b00000000001000000000000: n6907_o = 1'b0;
      23'b00000000000100000000000: n6907_o = 1'b0;
      23'b00000000000010000000000: n6907_o = 1'b1;
      23'b00000000000001000000000: n6907_o = 1'b0;
      23'b00000000000000100000000: n6907_o = 1'b0;
      23'b00000000000000010000000: n6907_o = 1'b0;
      23'b00000000000000001000000: n6907_o = 1'b0;
      23'b00000000000000000100000: n6907_o = 1'b0;
      23'b00000000000000000010000: n6907_o = 1'b0;
      23'b00000000000000000001000: n6907_o = 1'b0;
      23'b00000000000000000000100: n6907_o = 1'b0;
      23'b00000000000000000000010: n6907_o = 1'b0;
      23'b00000000000000000000001: n6907_o = 1'b0;
      default: n6907_o = 1'bX;
    endcase
  assign n6909_o = n6750_o[2:0];
  assign n6910_o = n6820_o[2:0];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6913_o = n6910_o;
      23'b01000000000000000000000: n6913_o = n6909_o;
      23'b00100000000000000000000: n6913_o = 3'b000;
      23'b00010000000000000000000: n6913_o = n6632_o;
      23'b00001000000000000000000: n6913_o = 3'b000;
      23'b00000100000000000000000: n6913_o = n6540_o;
      23'b00000010000000000000000: n6913_o = n6499_o;
      23'b00000001000000000000000: n6913_o = n6449_o;
      23'b00000000100000000000000: n6913_o = n6364_o;
      23'b00000000010000000000000: n6913_o = 3'b000;
      23'b00000000001000000000000: n6913_o = 3'b000;
      23'b00000000000100000000000: n6913_o = 3'b000;
      23'b00000000000010000000000: n6913_o = 3'b010;
      23'b00000000000001000000000: n6913_o = n6234_o;
      23'b00000000000000100000000: n6913_o = n6181_o;
      23'b00000000000000010000000: n6913_o = 3'b000;
      23'b00000000000000001000000: n6913_o = n6067_o;
      23'b00000000000000000100000: n6913_o = 3'b000;
      23'b00000000000000000010000: n6913_o = 3'b000;
      23'b00000000000000000001000: n6913_o = 3'b000;
      23'b00000000000000000000100: n6913_o = 3'b000;
      23'b00000000000000000000010: n6913_o = 3'b000;
      23'b00000000000000000000001: n6913_o = 3'b000;
      default: n6913_o = 3'bX;
    endcase
  assign n6915_o = n6750_o[3];
  assign n6916_o = n6820_o[3];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6919_o = n6916_o;
      23'b01000000000000000000000: n6919_o = n6915_o;
      23'b00100000000000000000000: n6919_o = 1'b0;
      23'b00010000000000000000000: n6919_o = 1'b0;
      23'b00001000000000000000000: n6919_o = 1'b0;
      23'b00000100000000000000000: n6919_o = 1'b0;
      23'b00000010000000000000000: n6919_o = 1'b0;
      23'b00000001000000000000000: n6919_o = 1'b0;
      23'b00000000100000000000000: n6919_o = 1'b0;
      23'b00000000010000000000000: n6919_o = 1'b0;
      23'b00000000001000000000000: n6919_o = 1'b0;
      23'b00000000000100000000000: n6919_o = 1'b0;
      23'b00000000000010000000000: n6919_o = 1'b1;
      23'b00000000000001000000000: n6919_o = 1'b0;
      23'b00000000000000100000000: n6919_o = 1'b0;
      23'b00000000000000010000000: n6919_o = 1'b0;
      23'b00000000000000001000000: n6919_o = n6069_o;
      23'b00000000000000000100000: n6919_o = 1'b0;
      23'b00000000000000000010000: n6919_o = 1'b0;
      23'b00000000000000000001000: n6919_o = 1'b0;
      23'b00000000000000000000100: n6919_o = 1'b0;
      23'b00000000000000000000010: n6919_o = 1'b0;
      23'b00000000000000000000001: n6919_o = 1'b0;
      default: n6919_o = 1'bX;
    endcase
  assign n6920_o = n6127_o[0];
  assign n6921_o = n6184_o[0];
  assign n6922_o = n6237_o[0];
  assign n6924_o = n6501_o[0];
  assign n6925_o = n6542_o[0];
  assign n6926_o = n6682_o[0];
  assign n6927_o = n6754_o[0];
  assign n6928_o = n6824_o[0];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6931_o = n6928_o;
      23'b01000000000000000000000: n6931_o = n6927_o;
      23'b00100000000000000000000: n6931_o = n6926_o;
      23'b00010000000000000000000: n6931_o = 1'b0;
      23'b00001000000000000000000: n6931_o = 1'b0;
      23'b00000100000000000000000: n6931_o = n6925_o;
      23'b00000010000000000000000: n6931_o = n6924_o;
      23'b00000001000000000000000: n6931_o = n6451_o;
      23'b00000000100000000000000: n6931_o = n6366_o;
      23'b00000000010000000000000: n6931_o = 1'b0;
      23'b00000000001000000000000: n6931_o = 1'b0;
      23'b00000000000100000000000: n6931_o = 1'b0;
      23'b00000000000010000000000: n6931_o = 1'b1;
      23'b00000000000001000000000: n6931_o = n6922_o;
      23'b00000000000000100000000: n6931_o = n6921_o;
      23'b00000000000000010000000: n6931_o = n6920_o;
      23'b00000000000000001000000: n6931_o = 1'b0;
      23'b00000000000000000100000: n6931_o = 1'b0;
      23'b00000000000000000010000: n6931_o = 1'b0;
      23'b00000000000000000001000: n6931_o = 1'b0;
      23'b00000000000000000000100: n6931_o = 1'b0;
      23'b00000000000000000000010: n6931_o = 1'b0;
      23'b00000000000000000000001: n6931_o = 1'b0;
      default: n6931_o = 1'bX;
    endcase
  assign n6932_o = n6127_o[2:1];
  assign n6933_o = n6184_o[2:1];
  assign n6934_o = n6237_o[2:1];
  assign n6936_o = n6501_o[2:1];
  assign n6937_o = n6542_o[2:1];
  assign n6938_o = n6682_o[2:1];
  assign n6939_o = n6754_o[2:1];
  assign n6940_o = n6824_o[2:1];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6943_o = n6940_o;
      23'b01000000000000000000000: n6943_o = n6939_o;
      23'b00100000000000000000000: n6943_o = n6938_o;
      23'b00010000000000000000000: n6943_o = 2'b00;
      23'b00001000000000000000000: n6943_o = 2'b00;
      23'b00000100000000000000000: n6943_o = n6937_o;
      23'b00000010000000000000000: n6943_o = n6936_o;
      23'b00000001000000000000000: n6943_o = n6453_o;
      23'b00000000100000000000000: n6943_o = n6368_o;
      23'b00000000010000000000000: n6943_o = 2'b00;
      23'b00000000001000000000000: n6943_o = 2'b00;
      23'b00000000000100000000000: n6943_o = 2'b00;
      23'b00000000000010000000000: n6943_o = 2'b11;
      23'b00000000000001000000000: n6943_o = n6934_o;
      23'b00000000000000100000000: n6943_o = n6933_o;
      23'b00000000000000010000000: n6943_o = n6932_o;
      23'b00000000000000001000000: n6943_o = 2'b00;
      23'b00000000000000000100000: n6943_o = 2'b00;
      23'b00000000000000000010000: n6943_o = 2'b00;
      23'b00000000000000000001000: n6943_o = 2'b00;
      23'b00000000000000000000100: n6943_o = 2'b00;
      23'b00000000000000000000010: n6943_o = 2'b00;
      23'b00000000000000000000001: n6943_o = 2'b00;
      default: n6943_o = 2'bX;
    endcase
  assign n6944_o = n6127_o[3];
  assign n6945_o = n6184_o[3];
  assign n6946_o = n6237_o[3];
  assign n6948_o = n6754_o[3];
  assign n6949_o = n6824_o[3];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6952_o = n6949_o;
      23'b01000000000000000000000: n6952_o = n6948_o;
      23'b00100000000000000000000: n6952_o = n6684_o;
      23'b00010000000000000000000: n6952_o = 1'b0;
      23'b00001000000000000000000: n6952_o = 1'b0;
      23'b00000100000000000000000: n6952_o = 1'b0;
      23'b00000010000000000000000: n6952_o = 1'b0;
      23'b00000001000000000000000: n6952_o = n6455_o;
      23'b00000000100000000000000: n6952_o = n6370_o;
      23'b00000000010000000000000: n6952_o = 1'b0;
      23'b00000000001000000000000: n6952_o = 1'b0;
      23'b00000000000100000000000: n6952_o = 1'b0;
      23'b00000000000010000000000: n6952_o = 1'b0;
      23'b00000000000001000000000: n6952_o = n6946_o;
      23'b00000000000000100000000: n6952_o = n6945_o;
      23'b00000000000000010000000: n6952_o = n6944_o;
      23'b00000000000000001000000: n6952_o = 1'b0;
      23'b00000000000000000100000: n6952_o = 1'b0;
      23'b00000000000000000010000: n6952_o = 1'b0;
      23'b00000000000000000001000: n6952_o = 1'b0;
      23'b00000000000000000000100: n6952_o = 1'b0;
      23'b00000000000000000000010: n6952_o = 1'b0;
      23'b00000000000000000000001: n6952_o = 1'b0;
      default: n6952_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6955_o = n6826_o;
      23'b01000000000000000000000: n6955_o = n6756_o;
      23'b00100000000000000000000: n6955_o = n2203_o;
      23'b00010000000000000000000: n6955_o = n2203_o;
      23'b00001000000000000000000: n6955_o = n2203_o;
      23'b00000100000000000000000: n6955_o = n6544_o;
      23'b00000010000000000000000: n6955_o = n6503_o;
      23'b00000001000000000000000: n6955_o = n6458_o;
      23'b00000000100000000000000: n6955_o = n6373_o;
      23'b00000000010000000000000: n6955_o = n2203_o;
      23'b00000000001000000000000: n6955_o = n2203_o;
      23'b00000000000100000000000: n6955_o = n2203_o;
      23'b00000000000010000000000: n6955_o = 4'b0010;
      23'b00000000000001000000000: n6955_o = n6239_o;
      23'b00000000000000100000000: n6955_o = n6186_o;
      23'b00000000000000010000000: n6955_o = n2203_o;
      23'b00000000000000001000000: n6955_o = n2203_o;
      23'b00000000000000000100000: n6955_o = n2203_o;
      23'b00000000000000000010000: n6955_o = n2203_o;
      23'b00000000000000000001000: n6955_o = n2203_o;
      23'b00000000000000000000100: n6955_o = n2203_o;
      23'b00000000000000000000010: n6955_o = n2203_o;
      23'b00000000000000000000001: n6955_o = n2203_o;
      default: n6955_o = 4'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6959_o = n6829_o;
      23'b01000000000000000000000: n6959_o = n6759_o;
      23'b00100000000000000000000: n6959_o = 1'b0;
      23'b00010000000000000000000: n6959_o = 1'b0;
      23'b00001000000000000000000: n6959_o = 1'b0;
      23'b00000100000000000000000: n6959_o = n6547_o;
      23'b00000010000000000000000: n6959_o = n6506_o;
      23'b00000001000000000000000: n6959_o = n6462_o;
      23'b00000000100000000000000: n6959_o = n6377_o;
      23'b00000000010000000000000: n6959_o = 1'b0;
      23'b00000000001000000000000: n6959_o = 1'b0;
      23'b00000000000100000000000: n6959_o = 1'b0;
      23'b00000000000010000000000: n6959_o = 1'b1;
      23'b00000000000001000000000: n6959_o = n6242_o;
      23'b00000000000000100000000: n6959_o = 1'b0;
      23'b00000000000000010000000: n6959_o = 1'b0;
      23'b00000000000000001000000: n6959_o = 1'b0;
      23'b00000000000000000100000: n6959_o = 1'b0;
      23'b00000000000000000010000: n6959_o = 1'b0;
      23'b00000000000000000001000: n6959_o = 1'b0;
      23'b00000000000000000000100: n6959_o = 1'b0;
      23'b00000000000000000000010: n6959_o = 1'b0;
      23'b00000000000000000000001: n6959_o = 1'b0;
      default: n6959_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6962_o = 1'b0;
      23'b01000000000000000000000: n6962_o = 1'b0;
      23'b00100000000000000000000: n6962_o = 1'b0;
      23'b00010000000000000000000: n6962_o = 1'b0;
      23'b00001000000000000000000: n6962_o = 1'b0;
      23'b00000100000000000000000: n6962_o = 1'b0;
      23'b00000010000000000000000: n6962_o = 1'b0;
      23'b00000001000000000000000: n6962_o = 1'b0;
      23'b00000000100000000000000: n6962_o = 1'b0;
      23'b00000000010000000000000: n6962_o = 1'b0;
      23'b00000000001000000000000: n6962_o = 1'b0;
      23'b00000000000100000000000: n6962_o = 1'b0;
      23'b00000000000010000000000: n6962_o = 1'b0;
      23'b00000000000001000000000: n6962_o = n6245_o;
      23'b00000000000000100000000: n6962_o = 1'b0;
      23'b00000000000000010000000: n6962_o = 1'b0;
      23'b00000000000000001000000: n6962_o = 1'b0;
      23'b00000000000000000100000: n6962_o = 1'b0;
      23'b00000000000000000010000: n6962_o = 1'b0;
      23'b00000000000000000001000: n6962_o = 1'b0;
      23'b00000000000000000000100: n6962_o = 1'b0;
      23'b00000000000000000000010: n6962_o = 1'b0;
      23'b00000000000000000000001: n6962_o = 1'b0;
      default: n6962_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6965_o = n6833_o;
      23'b01000000000000000000000: n6965_o = n6763_o;
      23'b00100000000000000000000: n6965_o = n6687_o;
      23'b00010000000000000000000: n6965_o = n6635_o;
      23'b00001000000000000000000: n6965_o = n6578_o;
      23'b00000100000000000000000: n6965_o = n6551_o;
      23'b00000010000000000000000: n6965_o = n6510_o;
      23'b00000001000000000000000: n6965_o = 3'b111;
      23'b00000000100000000000000: n6965_o = 3'b111;
      23'b00000000010000000000000: n6965_o = 3'b111;
      23'b00000000001000000000000: n6965_o = 3'b111;
      23'b00000000000100000000000: n6965_o = 3'b111;
      23'b00000000000010000000000: n6965_o = 3'b111;
      23'b00000000000001000000000: n6965_o = n6248_o;
      23'b00000000000000100000000: n6965_o = n6190_o;
      23'b00000000000000010000000: n6965_o = n6131_o;
      23'b00000000000000001000000: n6965_o = n6073_o;
      23'b00000000000000000100000: n6965_o = 3'b111;
      23'b00000000000000000010000: n6965_o = 3'b111;
      23'b00000000000000000001000: n6965_o = 3'b111;
      23'b00000000000000000000100: n6965_o = 3'b111;
      23'b00000000000000000000010: n6965_o = 3'b111;
      23'b00000000000000000000001: n6965_o = 3'b111;
      default: n6965_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6968_o = n6836_o;
      23'b01000000000000000000000: n6968_o = n6766_o;
      23'b00100000000000000000000: n6968_o = n6690_o;
      23'b00010000000000000000000: n6968_o = n6638_o;
      23'b00001000000000000000000: n6968_o = 1'b0;
      23'b00000100000000000000000: n6968_o = 1'b0;
      23'b00000010000000000000000: n6968_o = 1'b0;
      23'b00000001000000000000000: n6968_o = 1'b0;
      23'b00000000100000000000000: n6968_o = 1'b0;
      23'b00000000010000000000000: n6968_o = 1'b0;
      23'b00000000001000000000000: n6968_o = 1'b0;
      23'b00000000000100000000000: n6968_o = 1'b0;
      23'b00000000000010000000000: n6968_o = 1'b0;
      23'b00000000000001000000000: n6968_o = 1'b0;
      23'b00000000000000100000000: n6968_o = 1'b0;
      23'b00000000000000010000000: n6968_o = 1'b0;
      23'b00000000000000001000000: n6968_o = 1'b0;
      23'b00000000000000000100000: n6968_o = 1'b0;
      23'b00000000000000000010000: n6968_o = 1'b0;
      23'b00000000000000000001000: n6968_o = 1'b0;
      23'b00000000000000000000100: n6968_o = 1'b0;
      23'b00000000000000000000010: n6968_o = 1'b0;
      23'b00000000000000000000001: n6968_o = 1'b0;
      default: n6968_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6971_o = 1'b0;
      23'b01000000000000000000000: n6971_o = 1'b0;
      23'b00100000000000000000000: n6971_o = 1'b0;
      23'b00010000000000000000000: n6971_o = 1'b0;
      23'b00001000000000000000000: n6971_o = n6581_o;
      23'b00000100000000000000000: n6971_o = 1'b0;
      23'b00000010000000000000000: n6971_o = 1'b0;
      23'b00000001000000000000000: n6971_o = 1'b0;
      23'b00000000100000000000000: n6971_o = 1'b0;
      23'b00000000010000000000000: n6971_o = 1'b0;
      23'b00000000001000000000000: n6971_o = 1'b0;
      23'b00000000000100000000000: n6971_o = 1'b0;
      23'b00000000000010000000000: n6971_o = 1'b0;
      23'b00000000000001000000000: n6971_o = 1'b0;
      23'b00000000000000100000000: n6971_o = 1'b0;
      23'b00000000000000010000000: n6971_o = 1'b0;
      23'b00000000000000001000000: n6971_o = 1'b0;
      23'b00000000000000000100000: n6971_o = 1'b0;
      23'b00000000000000000010000: n6971_o = 1'b0;
      23'b00000000000000000001000: n6971_o = 1'b0;
      23'b00000000000000000000100: n6971_o = 1'b0;
      23'b00000000000000000000010: n6971_o = 1'b0;
      23'b00000000000000000000001: n6971_o = 1'b0;
      default: n6971_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6974_o = 1'b0;
      23'b01000000000000000000000: n6974_o = 1'b0;
      23'b00100000000000000000000: n6974_o = 1'b0;
      23'b00010000000000000000000: n6974_o = 1'b0;
      23'b00001000000000000000000: n6974_o = n6584_o;
      23'b00000100000000000000000: n6974_o = 1'b0;
      23'b00000010000000000000000: n6974_o = 1'b0;
      23'b00000001000000000000000: n6974_o = 1'b0;
      23'b00000000100000000000000: n6974_o = 1'b0;
      23'b00000000010000000000000: n6974_o = 1'b0;
      23'b00000000001000000000000: n6974_o = 1'b0;
      23'b00000000000100000000000: n6974_o = 1'b0;
      23'b00000000000010000000000: n6974_o = 1'b0;
      23'b00000000000001000000000: n6974_o = 1'b0;
      23'b00000000000000100000000: n6974_o = 1'b0;
      23'b00000000000000010000000: n6974_o = n6134_o;
      23'b00000000000000001000000: n6974_o = n6076_o;
      23'b00000000000000000100000: n6974_o = 1'b0;
      23'b00000000000000000010000: n6974_o = 1'b0;
      23'b00000000000000000001000: n6974_o = 1'b0;
      23'b00000000000000000000100: n6974_o = 1'b0;
      23'b00000000000000000000010: n6974_o = 1'b0;
      23'b00000000000000000000001: n6974_o = 1'b0;
      default: n6974_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6977_o = 1'b0;
      23'b01000000000000000000000: n6977_o = 1'b0;
      23'b00100000000000000000000: n6977_o = 1'b0;
      23'b00010000000000000000000: n6977_o = 1'b0;
      23'b00001000000000000000000: n6977_o = n6587_o;
      23'b00000100000000000000000: n6977_o = 1'b0;
      23'b00000010000000000000000: n6977_o = 1'b0;
      23'b00000001000000000000000: n6977_o = 1'b0;
      23'b00000000100000000000000: n6977_o = 1'b0;
      23'b00000000010000000000000: n6977_o = 1'b0;
      23'b00000000001000000000000: n6977_o = 1'b0;
      23'b00000000000100000000000: n6977_o = 1'b0;
      23'b00000000000010000000000: n6977_o = 1'b0;
      23'b00000000000001000000000: n6977_o = 1'b0;
      23'b00000000000000100000000: n6977_o = 1'b0;
      23'b00000000000000010000000: n6977_o = n6137_o;
      23'b00000000000000001000000: n6977_o = n6079_o;
      23'b00000000000000000100000: n6977_o = 1'b0;
      23'b00000000000000000010000: n6977_o = 1'b0;
      23'b00000000000000000001000: n6977_o = 1'b0;
      23'b00000000000000000000100: n6977_o = 1'b0;
      23'b00000000000000000000010: n6977_o = 1'b0;
      23'b00000000000000000000001: n6977_o = 1'b0;
      default: n6977_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6984_o = 3'b000;
      23'b01000000000000000000000: n6984_o = 3'b000;
      23'b00100000000000000000000: n6984_o = 3'b000;
      23'b00010000000000000000000: n6984_o = 3'b000;
      23'b00001000000000000000000: n6984_o = 3'b000;
      23'b00000100000000000000000: n6984_o = 3'b000;
      23'b00000010000000000000000: n6984_o = 3'b000;
      23'b00000001000000000000000: n6984_o = 3'b000;
      23'b00000000100000000000000: n6984_o = 3'b000;
      23'b00000000010000000000000: n6984_o = 3'b000;
      23'b00000000001000000000000: n6984_o = 3'b000;
      23'b00000000000100000000000: n6984_o = 3'b000;
      23'b00000000000010000000000: n6984_o = 3'b000;
      23'b00000000000001000000000: n6984_o = 3'b000;
      23'b00000000000000100000000: n6984_o = 3'b000;
      23'b00000000000000010000000: n6984_o = 3'b000;
      23'b00000000000000001000000: n6984_o = 3'b000;
      23'b00000000000000000100000: n6984_o = 3'b111;
      23'b00000000000000000010000: n6984_o = 3'b110;
      23'b00000000000000000001000: n6984_o = 3'b101;
      23'b00000000000000000000100: n6984_o = 3'b100;
      23'b00000000000000000000010: n6984_o = 3'b000;
      23'b00000000000000000000001: n6984_o = 3'b000;
      default: n6984_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6987_o = 1'b0;
      23'b01000000000000000000000: n6987_o = 1'b0;
      23'b00100000000000000000000: n6987_o = 1'b0;
      23'b00010000000000000000000: n6987_o = 1'b0;
      23'b00001000000000000000000: n6987_o = n6590_o;
      23'b00000100000000000000000: n6987_o = 1'b0;
      23'b00000010000000000000000: n6987_o = 1'b0;
      23'b00000001000000000000000: n6987_o = 1'b0;
      23'b00000000100000000000000: n6987_o = 1'b0;
      23'b00000000010000000000000: n6987_o = 1'b0;
      23'b00000000001000000000000: n6987_o = 1'b0;
      23'b00000000000100000000000: n6987_o = 1'b0;
      23'b00000000000010000000000: n6987_o = 1'b0;
      23'b00000000000001000000000: n6987_o = 1'b0;
      23'b00000000000000100000000: n6987_o = 1'b0;
      23'b00000000000000010000000: n6987_o = 1'b0;
      23'b00000000000000001000000: n6987_o = 1'b0;
      23'b00000000000000000100000: n6987_o = 1'b0;
      23'b00000000000000000010000: n6987_o = 1'b0;
      23'b00000000000000000001000: n6987_o = 1'b0;
      23'b00000000000000000000100: n6987_o = 1'b0;
      23'b00000000000000000000010: n6987_o = 1'b0;
      23'b00000000000000000000001: n6987_o = 1'b0;
      default: n6987_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6990_o = 1'b0;
      23'b01000000000000000000000: n6990_o = 1'b0;
      23'b00100000000000000000000: n6990_o = 1'b0;
      23'b00010000000000000000000: n6990_o = 1'b0;
      23'b00001000000000000000000: n6990_o = 1'b0;
      23'b00000100000000000000000: n6990_o = 1'b0;
      23'b00000010000000000000000: n6990_o = 1'b0;
      23'b00000001000000000000000: n6990_o = 1'b0;
      23'b00000000100000000000000: n6990_o = 1'b0;
      23'b00000000010000000000000: n6990_o = 1'b0;
      23'b00000000001000000000000: n6990_o = 1'b0;
      23'b00000000000100000000000: n6990_o = 1'b0;
      23'b00000000000010000000000: n6990_o = 1'b0;
      23'b00000000000001000000000: n6990_o = 1'b0;
      23'b00000000000000100000000: n6990_o = n6193_o;
      23'b00000000000000010000000: n6990_o = 1'b0;
      23'b00000000000000001000000: n6990_o = 1'b0;
      23'b00000000000000000100000: n6990_o = 1'b0;
      23'b00000000000000000010000: n6990_o = 1'b0;
      23'b00000000000000000001000: n6990_o = 1'b0;
      23'b00000000000000000000100: n6990_o = 1'b0;
      23'b00000000000000000000010: n6990_o = 1'b0;
      23'b00000000000000000000001: n6990_o = 1'b0;
      default: n6990_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6993_o = 1'b0;
      23'b01000000000000000000000: n6993_o = 1'b0;
      23'b00100000000000000000000: n6993_o = 1'b0;
      23'b00010000000000000000000: n6993_o = 1'b0;
      23'b00001000000000000000000: n6993_o = 1'b0;
      23'b00000100000000000000000: n6993_o = 1'b0;
      23'b00000010000000000000000: n6993_o = 1'b0;
      23'b00000001000000000000000: n6993_o = 1'b0;
      23'b00000000100000000000000: n6993_o = 1'b0;
      23'b00000000010000000000000: n6993_o = 1'b0;
      23'b00000000001000000000000: n6993_o = 1'b0;
      23'b00000000000100000000000: n6993_o = 1'b0;
      23'b00000000000010000000000: n6993_o = 1'b0;
      23'b00000000000001000000000: n6993_o = n6251_o;
      23'b00000000000000100000000: n6993_o = 1'b0;
      23'b00000000000000010000000: n6993_o = 1'b0;
      23'b00000000000000001000000: n6993_o = 1'b0;
      23'b00000000000000000100000: n6993_o = 1'b0;
      23'b00000000000000000010000: n6993_o = 1'b0;
      23'b00000000000000000001000: n6993_o = 1'b0;
      23'b00000000000000000000100: n6993_o = 1'b0;
      23'b00000000000000000000010: n6993_o = 1'b0;
      23'b00000000000000000000001: n6993_o = 1'b0;
      default: n6993_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6996_o = n6839_o;
      23'b01000000000000000000000: n6996_o = n6769_o;
      23'b00100000000000000000000: n6996_o = 1'b0;
      23'b00010000000000000000000: n6996_o = 1'b0;
      23'b00001000000000000000000: n6996_o = 1'b0;
      23'b00000100000000000000000: n6996_o = 1'b0;
      23'b00000010000000000000000: n6996_o = 1'b0;
      23'b00000001000000000000000: n6996_o = 1'b0;
      23'b00000000100000000000000: n6996_o = 1'b0;
      23'b00000000010000000000000: n6996_o = 1'b0;
      23'b00000000001000000000000: n6996_o = 1'b0;
      23'b00000000000100000000000: n6996_o = 1'b0;
      23'b00000000000010000000000: n6996_o = 1'b0;
      23'b00000000000001000000000: n6996_o = 1'b0;
      23'b00000000000000100000000: n6996_o = 1'b0;
      23'b00000000000000010000000: n6996_o = 1'b0;
      23'b00000000000000001000000: n6996_o = 1'b0;
      23'b00000000000000000100000: n6996_o = 1'b0;
      23'b00000000000000000010000: n6996_o = 1'b0;
      23'b00000000000000000001000: n6996_o = 1'b0;
      23'b00000000000000000000100: n6996_o = 1'b0;
      23'b00000000000000000000010: n6996_o = 1'b0;
      23'b00000000000000000000001: n6996_o = 1'b0;
      default: n6996_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n6999_o = 1'b0;
      23'b01000000000000000000000: n6999_o = 1'b0;
      23'b00100000000000000000000: n6999_o = 1'b0;
      23'b00010000000000000000000: n6999_o = 1'b0;
      23'b00001000000000000000000: n6999_o = 1'b0;
      23'b00000100000000000000000: n6999_o = 1'b0;
      23'b00000010000000000000000: n6999_o = n6513_o;
      23'b00000001000000000000000: n6999_o = 1'b0;
      23'b00000000100000000000000: n6999_o = 1'b0;
      23'b00000000010000000000000: n6999_o = 1'b0;
      23'b00000000001000000000000: n6999_o = 1'b0;
      23'b00000000000100000000000: n6999_o = 1'b0;
      23'b00000000000010000000000: n6999_o = 1'b0;
      23'b00000000000001000000000: n6999_o = 1'b0;
      23'b00000000000000100000000: n6999_o = 1'b0;
      23'b00000000000000010000000: n6999_o = 1'b0;
      23'b00000000000000001000000: n6999_o = 1'b0;
      23'b00000000000000000100000: n6999_o = 1'b0;
      23'b00000000000000000010000: n6999_o = 1'b0;
      23'b00000000000000000001000: n6999_o = 1'b0;
      23'b00000000000000000000100: n6999_o = 1'b0;
      23'b00000000000000000000010: n6999_o = 1'b0;
      23'b00000000000000000000001: n6999_o = 1'b0;
      default: n6999_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n7002_o = 1'b0;
      23'b01000000000000000000000: n7002_o = 1'b0;
      23'b00100000000000000000000: n7002_o = 1'b0;
      23'b00010000000000000000000: n7002_o = 1'b0;
      23'b00001000000000000000000: n7002_o = 1'b0;
      23'b00000100000000000000000: n7002_o = n6554_o;
      23'b00000010000000000000000: n7002_o = 1'b0;
      23'b00000001000000000000000: n7002_o = 1'b0;
      23'b00000000100000000000000: n7002_o = 1'b0;
      23'b00000000010000000000000: n7002_o = 1'b0;
      23'b00000000001000000000000: n7002_o = 1'b0;
      23'b00000000000100000000000: n7002_o = 1'b0;
      23'b00000000000010000000000: n7002_o = 1'b0;
      23'b00000000000001000000000: n7002_o = 1'b0;
      23'b00000000000000100000000: n7002_o = 1'b0;
      23'b00000000000000010000000: n7002_o = 1'b0;
      23'b00000000000000001000000: n7002_o = 1'b0;
      23'b00000000000000000100000: n7002_o = 1'b0;
      23'b00000000000000000010000: n7002_o = 1'b0;
      23'b00000000000000000001000: n7002_o = 1'b0;
      23'b00000000000000000000100: n7002_o = 1'b0;
      23'b00000000000000000000010: n7002_o = 1'b0;
      23'b00000000000000000000001: n7002_o = 1'b0;
      default: n7002_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n7005_o = 1'b0;
      23'b01000000000000000000000: n7005_o = 1'b0;
      23'b00100000000000000000000: n7005_o = 1'b0;
      23'b00010000000000000000000: n7005_o = n6641_o;
      23'b00001000000000000000000: n7005_o = 1'b0;
      23'b00000100000000000000000: n7005_o = 1'b0;
      23'b00000010000000000000000: n7005_o = 1'b0;
      23'b00000001000000000000000: n7005_o = 1'b0;
      23'b00000000100000000000000: n7005_o = 1'b0;
      23'b00000000010000000000000: n7005_o = 1'b0;
      23'b00000000001000000000000: n7005_o = 1'b0;
      23'b00000000000100000000000: n7005_o = 1'b0;
      23'b00000000000010000000000: n7005_o = 1'b0;
      23'b00000000000001000000000: n7005_o = 1'b0;
      23'b00000000000000100000000: n7005_o = 1'b0;
      23'b00000000000000010000000: n7005_o = 1'b0;
      23'b00000000000000001000000: n7005_o = 1'b0;
      23'b00000000000000000100000: n7005_o = 1'b0;
      23'b00000000000000000010000: n7005_o = 1'b0;
      23'b00000000000000000001000: n7005_o = 1'b0;
      23'b00000000000000000000100: n7005_o = 1'b0;
      23'b00000000000000000000010: n7005_o = 1'b0;
      23'b00000000000000000000001: n7005_o = 1'b0;
      default: n7005_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n7008_o = n6842_o;
      23'b01000000000000000000000: n7008_o = n6772_o;
      23'b00100000000000000000000: n7008_o = n6693_o;
      23'b00010000000000000000000: n7008_o = n6644_o;
      23'b00001000000000000000000: n7008_o = 2'b00;
      23'b00000100000000000000000: n7008_o = 2'b00;
      23'b00000010000000000000000: n7008_o = 2'b00;
      23'b00000001000000000000000: n7008_o = n6465_o;
      23'b00000000100000000000000: n7008_o = n6380_o;
      23'b00000000010000000000000: n7008_o = 2'b00;
      23'b00000000001000000000000: n7008_o = 2'b00;
      23'b00000000000100000000000: n7008_o = 2'b00;
      23'b00000000000010000000000: n7008_o = 2'b00;
      23'b00000000000001000000000: n7008_o = 2'b00;
      23'b00000000000000100000000: n7008_o = 2'b00;
      23'b00000000000000010000000: n7008_o = 2'b00;
      23'b00000000000000001000000: n7008_o = 2'b00;
      23'b00000000000000000100000: n7008_o = 2'b00;
      23'b00000000000000000010000: n7008_o = 2'b00;
      23'b00000000000000000001000: n7008_o = 2'b00;
      23'b00000000000000000000100: n7008_o = 2'b00;
      23'b00000000000000000000010: n7008_o = 2'b00;
      23'b00000000000000000000001: n7008_o = 2'b00;
      default: n7008_o = 2'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n7014_o = 2'b11;
      23'b01000000000000000000000: n7014_o = 2'b11;
      23'b00100000000000000000000: n7014_o = 2'b11;
      23'b00010000000000000000000: n7014_o = 2'b11;
      23'b00001000000000000000000: n7014_o = 2'b11;
      23'b00000100000000000000000: n7014_o = 2'b11;
      23'b00000010000000000000000: n7014_o = 2'b11;
      23'b00000001000000000000000: n7014_o = 2'b11;
      23'b00000000100000000000000: n7014_o = 2'b11;
      23'b00000000010000000000000: n7014_o = 2'b10;
      23'b00000000001000000000000: n7014_o = 2'b01;
      23'b00000000000100000000000: n7014_o = 2'b00;
      23'b00000000000010000000000: n7014_o = 2'b11;
      23'b00000000000001000000000: n7014_o = 2'b11;
      23'b00000000000000100000000: n7014_o = 2'b11;
      23'b00000000000000010000000: n7014_o = 2'b11;
      23'b00000000000000001000000: n7014_o = 2'b11;
      23'b00000000000000000100000: n7014_o = 2'b11;
      23'b00000000000000000010000: n7014_o = 2'b11;
      23'b00000000000000000001000: n7014_o = 2'b11;
      23'b00000000000000000000100: n7014_o = 2'b11;
      23'b00000000000000000000010: n7014_o = 2'b11;
      23'b00000000000000000000001: n7014_o = 2'b11;
      default: n7014_o = 2'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n7017_o = n6845_o;
      23'b01000000000000000000000: n7017_o = n6775_o;
      23'b00100000000000000000000: n7017_o = 1'b0;
      23'b00010000000000000000000: n7017_o = 1'b0;
      23'b00001000000000000000000: n7017_o = 1'b0;
      23'b00000100000000000000000: n7017_o = n6557_o;
      23'b00000010000000000000000: n7017_o = n6516_o;
      23'b00000001000000000000000: n7017_o = n6469_o;
      23'b00000000100000000000000: n7017_o = n6384_o;
      23'b00000000010000000000000: n7017_o = 1'b0;
      23'b00000000001000000000000: n7017_o = 1'b0;
      23'b00000000000100000000000: n7017_o = 1'b0;
      23'b00000000000010000000000: n7017_o = 1'b0;
      23'b00000000000001000000000: n7017_o = n6255_o;
      23'b00000000000000100000000: n7017_o = n6196_o;
      23'b00000000000000010000000: n7017_o = 1'b0;
      23'b00000000000000001000000: n7017_o = 1'b0;
      23'b00000000000000000100000: n7017_o = 1'b0;
      23'b00000000000000000010000: n7017_o = 1'b0;
      23'b00000000000000000001000: n7017_o = 1'b0;
      23'b00000000000000000000100: n7017_o = 1'b0;
      23'b00000000000000000000010: n7017_o = 1'b0;
      23'b00000000000000000000001: n7017_o = 1'b0;
      default: n7017_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6860_o)
      23'b10000000000000000000000: n7020_o = n6848_o;
      23'b01000000000000000000000: n7020_o = n6778_o;
      23'b00100000000000000000000: n7020_o = n6696_o;
      23'b00010000000000000000000: n7020_o = 1'b0;
      23'b00001000000000000000000: n7020_o = 1'b0;
      23'b00000100000000000000000: n7020_o = n6560_o;
      23'b00000010000000000000000: n7020_o = n6519_o;
      23'b00000001000000000000000: n7020_o = 1'b0;
      23'b00000000100000000000000: n7020_o = 1'b0;
      23'b00000000010000000000000: n7020_o = 1'b0;
      23'b00000000001000000000000: n7020_o = 1'b0;
      23'b00000000000100000000000: n7020_o = 1'b0;
      23'b00000000000010000000000: n7020_o = 1'b0;
      23'b00000000000001000000000: n7020_o = 1'b0;
      23'b00000000000000100000000: n7020_o = n6199_o;
      23'b00000000000000010000000: n7020_o = n6141_o;
      23'b00000000000000001000000: n7020_o = 1'b0;
      23'b00000000000000000100000: n7020_o = 1'b0;
      23'b00000000000000000010000: n7020_o = 1'b0;
      23'b00000000000000000001000: n7020_o = 1'b0;
      23'b00000000000000000000100: n7020_o = 1'b0;
      23'b00000000000000000000010: n7020_o = 1'b0;
      23'b00000000000000000000001: n7020_o = 1'b0;
      default: n7020_o = 1'bX;
    endcase
  assign n7021_o = {n5482_o, n4394_o};
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7022_o = n5460_o;
      2'b01: n7022_o = n4156_o;
      default: n7022_o = n6876_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7024_o = n5462_o;
      2'b01: n7024_o = n4161_o;
      default: n7024_o = n6882_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7026_o = 2'b00;
      2'b01: n7026_o = n4167_o;
      default: n7026_o = 2'b00;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7029_o = 1'b0;
      2'b01: n7029_o = n4170_o;
      default: n7029_o = n6885_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7032_o = 1'b0;
      2'b01: n7032_o = n4173_o;
      default: n7032_o = n6888_o;
    endcase
  assign n7034_o = n6894_o[1:0];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7036_o = 2'b00;
      2'b01: n7036_o = n4185_o;
      default: n7036_o = n7034_o;
    endcase
  assign n7037_o = n4197_o[0];
  assign n7038_o = n6894_o[2];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7040_o = 1'b0;
      2'b01: n7040_o = n7037_o;
      default: n7040_o = n7038_o;
    endcase
  assign n7041_o = n4197_o[1];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7043_o = 1'b0;
      2'b01: n7043_o = n7041_o;
      default: n7043_o = n6900_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7047_o = n5465_o;
      2'b01: n7047_o = n4206_o;
      default: n7047_o = n6903_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7050_o = 1'b0;
      2'b01: n7050_o = n4209_o;
      default: n7050_o = n6907_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7052_o = n4395_o;
      2'b01: n7052_o = n4213_o;
      default: n7052_o = n6913_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7054_o = 1'b0;
      2'b01: n7054_o = n4217_o;
      default: n7054_o = n6919_o;
    endcase
  assign n7057_o = n5467_o[0];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7058_o = n7057_o;
      2'b01: n7058_o = n4242_o;
      default: n7058_o = n6931_o;
    endcase
  assign n7059_o = n5467_o[2:1];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7060_o = n7059_o;
      2'b01: n7060_o = n4267_o;
      default: n7060_o = n6943_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7062_o = 1'b0;
      2'b01: n7062_o = n4286_o;
      default: n7062_o = n6952_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7066_o = n5469_o;
      2'b01: n7066_o = n4292_o;
      default: n7066_o = n6955_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7067_o = n5472_o;
      2'b01: n7067_o = n4300_o;
      default: n7067_o = n6959_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7070_o = 1'b0;
      2'b01: n7070_o = n4305_o;
      default: n7070_o = n6962_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7073_o = 1'b0;
      2'b01: n7073_o = n4308_o;
      default: n7073_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7075_o = n5474_o;
      2'b01: n7075_o = n4311_o;
      default: n7075_o = n6965_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7078_o = 1'b0;
      2'b01: n7078_o = n4314_o;
      default: n7078_o = n6968_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7081_o = 1'b0;
      2'b01: n7081_o = n4317_o;
      default: n7081_o = n6971_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7084_o = 1'b0;
      2'b01: n7084_o = n4320_o;
      default: n7084_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7087_o = 1'b0;
      2'b01: n7087_o = n4324_o;
      default: n7087_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7090_o = 1'b0;
      2'b01: n7090_o = n4327_o;
      default: n7090_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7093_o = 1'b0;
      2'b01: n7093_o = n4330_o;
      default: n7093_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7096_o = 1'b0;
      2'b01: n7096_o = n4333_o;
      default: n7096_o = n6974_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7099_o = 1'b0;
      2'b01: n7099_o = n4336_o;
      default: n7099_o = n6977_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7102_o = 1'b0;
      2'b01: n7102_o = n4340_o;
      default: n7102_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7105_o = 3'b000;
      2'b01: n7105_o = 3'b000;
      default: n7105_o = n6984_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7108_o = 1'b0;
      2'b01: n7108_o = n4344_o;
      default: n7108_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7111_o = 1'b0;
      2'b01: n7111_o = n4348_o;
      default: n7111_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7114_o = 1'b0;
      2'b01: n7114_o = n4352_o;
      default: n7114_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7117_o = 1'b0;
      2'b01: n7117_o = n4356_o;
      default: n7117_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7120_o = 1'b0;
      2'b01: n7120_o = n4359_o;
      default: n7120_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7123_o = 1'b0;
      2'b01: n7123_o = n4363_o;
      default: n7123_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7126_o = 1'b0;
      2'b01: n7126_o = n4367_o;
      default: n7126_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7129_o = 1'b0;
      2'b01: n7129_o = n4371_o;
      default: n7129_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7132_o = 1'b0;
      2'b01: n7132_o = 1'b0;
      default: n7132_o = n6987_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7135_o = 1'b0;
      2'b01: n7135_o = 1'b0;
      default: n7135_o = n6990_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7138_o = 1'b0;
      2'b01: n7138_o = 1'b0;
      default: n7138_o = n6993_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7141_o = 1'b0;
      2'b01: n7141_o = 1'b0;
      default: n7141_o = n6996_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7144_o = 1'b0;
      2'b01: n7144_o = 1'b0;
      default: n7144_o = n6999_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7147_o = 1'b0;
      2'b01: n7147_o = 1'b0;
      default: n7147_o = n7002_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7150_o = 1'b0;
      2'b01: n7150_o = 1'b0;
      default: n7150_o = n7005_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7153_o = 2'b00;
      2'b01: n7153_o = n4374_o;
      default: n7153_o = n7008_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7156_o = 1'b0;
      2'b01: n7156_o = n4378_o;
      default: n7156_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7159_o = 1'b0;
      2'b01: n7159_o = n4382_o;
      default: n7159_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7162_o = 2'b11;
      2'b01: n7162_o = 2'b11;
      default: n7162_o = n7014_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7165_o = 1'b0;
      2'b01: n7165_o = n4386_o;
      default: n7165_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7168_o = 1'b0;
      2'b01: n7168_o = n4389_o;
      default: n7168_o = n7017_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7170_o = n5477_o;
      2'b01: n7170_o = n4392_o;
      default: n7170_o = n7020_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n7021_o)
      2'b10: n7173_o = n5480_o;
      2'b01: n7173_o = 1'b0;
      default: n7173_o = 1'b0;
    endcase
  /* T80_MCode.vhd:2003:35  */
  assign n7176_o = mcycle == 3'b110;
  /* T80_MCode.vhd:2011:40  */
  assign n7178_o = ir == 8'b00110110;
  /* T80_MCode.vhd:2011:60  */
  assign n7180_o = ir == 8'b11001011;
  /* T80_MCode.vhd:2011:53  */
  assign n7181_o = n7178_o | n7180_o;
  /* T80_MCode.vhd:2003:25  */
  assign n7183_o = n7186_o ? 3'b111 : n7075_o;
  /* T80_MCode.vhd:2003:25  */
  assign n7185_o = n7176_o ? 1'b1 : n7029_o;
  /* T80_MCode.vhd:2003:25  */
  assign n7186_o = n7176_o & n7181_o;
  /* T80_MCode.vhd:2015:35  */
  assign n7188_o = mcycle == 3'b111;
  /* T80_MCode.vhd:2019:41  */
  assign n7190_o = iset != 2'b01;
  /* T80_MCode.vhd:2015:25  */
  assign n7192_o = n7209_o ? 3'b010 : n7183_o;
  /* T80_MCode.vhd:2024:40  */
  assign n7195_o = ir == 8'b00110110;
  /* T80_MCode.vhd:2024:61  */
  assign n7197_o = iset == 2'b01;
  /* T80_MCode.vhd:2024:53  */
  assign n7198_o = n7195_o | n7197_o;
  /* T80_MCode.vhd:2015:25  */
  assign n7200_o = n7205_o ? 1'b1 : n7185_o;
  /* T80_MCode.vhd:2024:33  */
  assign n7202_o = n7198_o ? n7168_o : 1'b1;
  /* T80_MCode.vhd:2015:25  */
  assign n7204_o = n7188_o ? 3'b101 : n7024_o;
  /* T80_MCode.vhd:2015:25  */
  assign n7205_o = n7188_o & n7198_o;
  assign n7206_o = {1'b0, n2194_o};
  assign n7207_o = {n7062_o, n7060_o, n7058_o};
  /* T80_MCode.vhd:2015:25  */
  assign n7208_o = n7188_o ? n7206_o : n7207_o;
  /* T80_MCode.vhd:2015:25  */
  assign n7209_o = n7188_o & n7190_o;
  /* T80_MCode.vhd:2015:25  */
  assign n7210_o = n7188_o ? n7202_o : n7168_o;
  assign n7212_o = {n7043_o, n7040_o, n7036_o};
  assign n7213_o = {n7054_o, n7052_o};
endmodule

module t80_0_1_0_1_2_3_4_5_6_7
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
  wire [6:0] n424_o;
  wire [6:0] n426_o;
  wire n427_o;
  wire n428_o;
  wire n429_o;
  wire n430_o;
  wire n431_o;
  wire n432_o;
  wire n433_o;
  wire n434_o;
  wire n435_o;
  wire n436_o;
  wire [15:0] n438_o;
  wire [15:0] n439_o;
  wire n441_o;
  wire n442_o;
  wire n444_o;
  wire n445_o;
  wire n446_o;
  wire n447_o;
  wire [7:0] n449_o;
  wire [7:0] n451_o;
  wire n453_o;
  wire n455_o;
  wire n456_o;
  wire [1:0] n459_o;
  wire n461_o;
  wire [1:0] n463_o;
  wire n465_o;
  wire [1:0] n467_o;
  wire [1:0] n468_o;
  wire n469_o;
  wire [1:0] n471_o;
  wire [1:0] n474_o;
  wire n476_o;
  wire [15:0] n477_o;
  wire [15:0] n478_o;
  wire [6:0] n479_o;
  wire [6:0] n480_o;
  wire n481_o;
  wire [7:0] n482_o;
  wire [1:0] n483_o;
  wire [1:0] n484_o;
  wire n485_o;
  wire n487_o;
  wire n489_o;
  wire [1:0] n491_o;
  wire n492_o;
  wire n494_o;
  wire n495_o;
  wire n496_o;
  wire n497_o;
  wire n498_o;
  wire [7:0] n499_o;
  wire [7:0] n500_o;
  wire n501_o;
  wire n502_o;
  wire n503_o;
  wire n505_o;
  wire n506_o;
  wire n508_o;
  wire n509_o;
  wire [7:0] n510_o;
  wire [7:0] n511_o;
  wire n513_o;
  wire [15:0] n514_o;
  wire [15:0] n515_o;
  wire n517_o;
  wire [15:0] n518_o;
  wire [15:0] n521_o;
  wire n523_o;
  wire n525_o;
  wire n527_o;
  wire [15:0] n530_o;
  wire [15:0] n531_o;
  wire n533_o;
  wire [7:0] n534_o;
  wire [7:0] n537_o;
  wire [15:0] n538_o;
  wire [15:0] n539_o;
  wire n541_o;
  wire n543_o;
  wire [7:0] n544_o;
  wire [7:0] n547_o;
  wire [15:0] n548_o;
  wire [15:0] n549_o;
  wire n551_o;
  wire [15:0] n553_o;
  wire [7:0] n554_o;
  wire n556_o;
  wire [7:0] n557_o;
  wire [7:0] n560_o;
  wire [15:0] n561_o;
  wire [15:0] n562_o;
  wire [15:0] n563_o;
  wire [15:0] n564_o;
  wire [15:0] n565_o;
  wire n567_o;
  wire [5:0] n568_o;
  wire [7:0] n569_o;
  wire [7:0] n570_o;
  wire [7:0] n571_o;
  wire [7:0] n572_o;
  wire [7:0] n573_o;
  wire [7:0] n574_o;
  reg [7:0] n575_o;
  wire [7:0] n576_o;
  wire [7:0] n577_o;
  wire [7:0] n578_o;
  wire [7:0] n579_o;
  wire [7:0] n580_o;
  wire [7:0] n581_o;
  reg [7:0] n582_o;
  reg [15:0] n583_o;
  wire [15:0] n584_o;
  wire [15:0] n585_o;
  wire [15:0] n586_o;
  wire [15:0] n587_o;
  wire [15:0] n588_o;
  wire [15:0] n589_o;
  wire [15:0] n591_o;
  wire [15:0] n593_o;
  wire [15:0] n594_o;
  wire [15:0] n595_o;
  wire [15:0] n596_o;
  wire [15:0] n597_o;
  wire [15:0] n598_o;
  wire [15:0] n599_o;
  wire [15:0] n600_o;
  wire [15:0] n601_o;
  wire [15:0] n602_o;
  wire [15:0] n603_o;
  wire [15:0] n604_o;
  wire [15:0] n605_o;
  wire n607_o;
  wire [15:0] n608_o;
  wire [7:0] n609_o;
  wire n610_o;
  wire n611_o;
  wire n613_o;
  wire n614_o;
  wire [7:0] n616_o;
  wire [2:0] n617_o;
  wire n618_o;
  wire n619_o;
  wire n622_o;
  wire n623_o;
  wire n624_o;
  wire n625_o;
  wire n626_o;
  wire [1:0] n628_o;
  wire [2:0] n629_o;
  wire n630_o;
  wire [1:0] n631_o;
  wire [1:0] n632_o;
  wire n635_o;
  wire n637_o;
  wire [1:0] n639_o;
  wire [2:0] n640_o;
  wire [1:0] n641_o;
  wire [15:0] n643_o;
  wire n644_o;
  wire [1:0] n645_o;
  wire [1:0] n646_o;
  wire [15:0] n649_o;
  wire [15:0] n650_o;
  wire n651_o;
  wire [3:0] n653_o;
  wire n655_o;
  wire n657_o;
  wire n658_o;
  wire n659_o;
  wire n660_o;
  wire n662_o;
  wire n663_o;
  wire n664_o;
  wire n665_o;
  wire n666_o;
  wire n667_o;
  wire [8:0] n669_o;
  wire [7:0] n670_o;
  wire [8:0] n672_o;
  wire [8:0] n673_o;
  wire n674_o;
  wire n675_o;
  wire n676_o;
  wire [8:0] n678_o;
  wire [8:0] n680_o;
  wire [8:0] n681_o;
  wire n682_o;
  wire n683_o;
  wire n684_o;
  wire n685_o;
  wire n686_o;
  wire n687_o;
  wire n688_o;
  wire n689_o;
  wire n690_o;
  wire n691_o;
  wire n692_o;
  wire n693_o;
  wire n694_o;
  wire n695_o;
  wire n696_o;
  wire n697_o;
  wire [2:0] n698_o;
  wire n699_o;
  wire [2:0] n700_o;
  wire [2:0] n701_o;
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
  wire n723_o;
  wire n724_o;
  wire n725_o;
  wire n726_o;
  wire n727_o;
  wire n728_o;
  wire n729_o;
  wire n732_o;
  wire n733_o;
  wire n735_o;
  wire n737_o;
  wire n738_o;
  wire [7:0] n739_o;
  wire [15:0] n740_o;
  wire [15:0] n741_o;
  wire [15:0] n742_o;
  wire [15:0] n743_o;
  wire [15:0] n745_o;
  wire [15:0] n746_o;
  wire [15:0] n747_o;
  wire [15:0] n748_o;
  wire [15:0] n750_o;
  wire [15:0] n751_o;
  wire [2:0] n752_o;
  localparam [15:0] n753_o = 16'b0000000000000000;
  wire [9:0] n754_o;
  wire [2:0] n755_o;
  wire [15:0] n756_o;
  wire [15:0] n757_o;
  wire [15:0] n758_o;
  wire [15:0] n759_o;
  wire n760_o;
  wire n762_o;
  wire n764_o;
  wire n765_o;
  wire [15:0] n766_o;
  wire [15:0] n767_o;
  wire [15:0] n768_o;
  wire n770_o;
  wire n772_o;
  wire n773_o;
  wire n774_o;
  wire n775_o;
  wire n776_o;
  wire [15:0] n779_o;
  wire [15:0] n780_o;
  wire n781_o;
  wire n783_o;
  wire n784_o;
  wire n786_o;
  wire n788_o;
  wire n789_o;
  wire n790_o;
  wire [2:0] n791_o;
  wire n793_o;
  wire n794_o;
  wire [15:0] n796_o;
  wire [15:0] n798_o;
  wire [15:0] n799_o;
  wire [15:0] n800_o;
  wire n801_o;
  wire [15:0] n802_o;
  wire [7:0] n803_o;
  wire [1:0] n804_o;
  wire [7:0] n805_o;
  wire [7:0] n807_o;
  wire [7:0] n808_o;
  wire n809_o;
  wire n810_o;
  wire [15:0] n811_o;
  wire [7:0] n812_o;
  wire [7:0] n814_o;
  wire [7:0] n815_o;
  wire n817_o;
  wire [15:0] n818_o;
  wire [15:0] n819_o;
  wire n820_o;
  wire [15:0] n821_o;
  wire [7:0] n822_o;
  wire [1:0] n823_o;
  wire n824_o;
  wire n825_o;
  wire n826_o;
  wire [3:0] n828_o;
  wire n831_o;
  wire n835_o;
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
  wire [7:0] n911_o;
  wire [7:0] n912_o;
  wire [7:0] n913_o;
  wire [7:0] n914_o;
  wire [7:0] n915_o;
  wire [7:0] n916_o;
  wire [7:0] n917_o;
  wire [7:0] n918_o;
  wire [7:0] n919_o;
  wire n920_o;
  wire [1:0] n921_o;
  wire n922_o;
  wire n924_o;
  wire n927_o;
  wire n928_o;
  wire n930_o;
  wire n933_o;
  wire n934_o;
  wire n936_o;
  wire n939_o;
  wire n940_o;
  wire n942_o;
  wire n945_o;
  wire n947_o;
  wire [2:0] n948_o;
  reg [7:0] n949_o;
  wire n950_o;
  wire n951_o;
  wire n952_o;
  wire n953_o;
  wire n954_o;
  reg n955_o;
  wire n956_o;
  wire n957_o;
  wire n958_o;
  wire n959_o;
  wire n960_o;
  reg n961_o;
  wire n962_o;
  wire n963_o;
  wire n964_o;
  wire n965_o;
  wire n966_o;
  reg n967_o;
  wire n968_o;
  wire n969_o;
  wire n970_o;
  wire n971_o;
  wire n972_o;
  reg n973_o;
  wire n974_o;
  wire n975_o;
  wire n976_o;
  wire n977_o;
  wire n978_o;
  reg n979_o;
  wire n980_o;
  wire n981_o;
  wire n982_o;
  wire n983_o;
  wire n984_o;
  reg n985_o;
  wire n986_o;
  wire n987_o;
  wire n988_o;
  wire n989_o;
  wire n990_o;
  reg n991_o;
  reg [7:0] n992_o;
  wire n993_o;
  wire [7:0] n994_o;
  reg [7:0] n995_o;
  wire [7:0] n996_o;
  wire [6:0] n997_o;
  wire [6:0] n998_o;
  wire [6:0] n999_o;
  wire [6:0] n1000_o;
  wire [6:0] n1001_o;
  wire [6:0] n1002_o;
  wire [6:0] n1003_o;
  wire [7:0] n1004_o;
  wire n1005_o;
  wire [7:0] n1006_o;
  wire [7:0] n1007_o;
  wire n1008_o;
  wire [6:0] n1009_o;
  wire [6:0] n1010_o;
  wire [6:0] n1011_o;
  wire [6:0] n1012_o;
  wire [6:0] n1013_o;
  wire [6:0] n1014_o;
  wire n1015_o;
  wire n1016_o;
  wire n1017_o;
  wire n1018_o;
  wire n1019_o;
  wire n1020_o;
  wire n1021_o;
  wire [7:0] n1022_o;
  wire [7:0] n1023_o;
  wire [15:0] n1024_o;
  wire [15:0] n1025_o;
  wire n1026_o;
  wire n1027_o;
  wire n1029_o;
  wire n1030_o;
  wire [6:0] n1031_o;
  wire n1032_o;
  wire n1033_o;
  wire n1034_o;
  wire [7:0] n1035_o;
  wire [7:0] n1036_o;
  wire n1038_o;
  wire n1041_o;
  wire n1042_o;
  wire n1044_o;
  wire n1047_o;
  wire n1048_o;
  wire n1049_o;
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
  wire [6:0] n1065_o;
  wire n1070_o;
  wire n1071_o;
  wire n1072_o;
  wire n1074_o;
  wire n1075_o;
  wire n1076_o;
  wire n1077_o;
  wire n1078_o;
  wire [7:0] n1079_o;
  wire [3:0] n1080_o;
  wire [3:0] n1081_o;
  wire [7:0] n1082_o;
  wire [7:0] n1083_o;
  wire [3:0] n1084_o;
  wire [3:0] n1085_o;
  wire [7:0] n1086_o;
  wire [7:0] n1087_o;
  wire [7:0] n1088_o;
  wire n1089_o;
  wire [4:0] n1092_o;
  wire [4:0] n1093_o;
  wire [4:0] n1094_o;
  wire [4:0] n1096_o;
  wire n1099_o;
  wire n1100_o;
  wire n1101_o;
  wire n1102_o;
  wire [2:0] n1105_o;
  wire n1106_o;
  wire n1107_o;
  wire n1108_o;
  wire n1109_o;
  wire n1110_o;
  wire n1111_o;
  wire [1:0] n1123_o;
  wire [1:0] n1124_o;
  wire [1:0] n1125_o;
  wire [1:0] n1126_o;
  wire [1:0] n1127_o;
  wire n1128_o;
  wire n1129_o;
  wire n1130_o;
  wire n1131_o;
  wire n1132_o;
  wire n1134_o;
  wire n1135_o;
  wire n1136_o;
  wire [7:0] n1138_o;
  wire [7:0] n1139_o;
  wire n1140_o;
  wire n1141_o;
  wire n1142_o;
  wire n1143_o;
  wire n1144_o;
  wire n1145_o;
  wire n1146_o;
  wire n1147_o;
  wire n1148_o;
  wire n1149_o;
  wire n1150_o;
  wire n1151_o;
  wire n1152_o;
  wire n1153_o;
  wire n1154_o;
  wire n1155_o;
  wire n1156_o;
  wire n1157_o;
  wire n1165_o;
  wire n1166_o;
  wire n1167_o;
  wire n1168_o;
  wire n1169_o;
  wire n1170_o;
  wire n1171_o;
  wire n1173_o;
  wire n1174_o;
  wire n1176_o;
  wire n1177_o;
  wire n1178_o;
  wire n1179_o;
  wire n1180_o;
  wire n1182_o;
  wire n1183_o;
  wire n1184_o;
  wire n1186_o;
  wire n1188_o;
  wire n1190_o;
  wire n1192_o;
  wire n1194_o;
  wire [4:0] n1195_o;
  reg [7:0] n1196_o;
  reg [7:0] n1197_o;
  wire [7:0] n1198_o;
  reg [7:0] n1199_o;
  wire [7:0] n1200_o;
  wire [7:0] n1201_o;
  wire [7:0] n1202_o;
  wire [7:0] n1203_o;
  wire [7:0] n1204_o;
  wire [7:0] n1205_o;
  wire [7:0] n1206_o;
  wire [7:0] n1207_o;
  wire [7:0] n1208_o;
  reg [7:0] n1209_o;
  wire [7:0] n1210_o;
  wire [7:0] n1211_o;
  wire [7:0] n1212_o;
  wire [7:0] n1213_o;
  wire [7:0] n1214_o;
  wire [7:0] n1215_o;
  wire [7:0] n1216_o;
  wire [7:0] n1217_o;
  wire [7:0] n1218_o;
  reg [7:0] n1219_o;
  wire [7:0] n1220_o;
  wire [7:0] n1221_o;
  wire [7:0] n1222_o;
  wire [7:0] n1223_o;
  wire [7:0] n1224_o;
  wire [15:0] n1225_o;
  wire [15:0] n1226_o;
  wire [15:0] n1227_o;
  wire [7:0] n1228_o;
  wire [7:0] n1229_o;
  wire [7:0] n1230_o;
  wire [7:0] n1231_o;
  wire [7:0] n1232_o;
  wire n1233_o;
  wire [7:0] n1234_o;
  wire [15:0] n1235_o;
  wire [15:0] n1236_o;
  wire n1237_o;
  wire [15:0] n1238_o;
  wire [7:0] n1239_o;
  wire [1:0] n1240_o;
  wire n1241_o;
  wire n1242_o;
  wire n1243_o;
  wire n1244_o;
  wire [4:0] n1245_o;
  wire n1246_o;
  wire n1247_o;
  wire [3:0] n1248_o;
  wire n1249_o;
  wire n1250_o;
  wire [2:0] n1251_o;
  wire n1252_o;
  wire [15:0] n1255_o;
  wire [7:0] n1256_o;
  wire [7:0] n1257_o;
  wire [7:0] n1258_o;
  wire [7:0] n1259_o;
  wire [7:0] n1260_o;
  wire [7:0] n1261_o;
  wire [7:0] n1262_o;
  wire [15:0] n1263_o;
  wire [15:0] n1264_o;
  wire n1265_o;
  wire [15:0] n1266_o;
  wire [7:0] n1267_o;
  wire [1:0] n1268_o;
  wire [1:0] n1269_o;
  wire [1:0] n1270_o;
  wire n1271_o;
  wire n1272_o;
  wire [4:0] n1273_o;
  wire n1274_o;
  wire n1275_o;
  wire [3:0] n1276_o;
  wire n1277_o;
  wire n1278_o;
  wire [2:0] n1279_o;
  wire n1280_o;
  wire [1:0] n1375_o;
  wire [2:0] n1376_o;
  wire n1377_o;
  wire n1379_o;
  wire n1380_o;
  wire [1:0] n1381_o;
  wire n1383_o;
  wire n1384_o;
  wire n1385_o;
  wire [2:0] n1387_o;
  wire [2:0] n1388_o;
  wire [1:0] n1389_o;
  wire [2:0] n1390_o;
  wire n1391_o;
  wire n1393_o;
  wire n1394_o;
  wire [1:0] n1395_o;
  wire n1397_o;
  wire n1398_o;
  wire n1399_o;
  wire [2:0] n1401_o;
  wire [2:0] n1402_o;
  wire [1:0] n1403_o;
  wire [2:0] n1404_o;
  wire n1405_o;
  wire [2:0] n1407_o;
  wire [2:0] n1408_o;
  wire n1409_o;
  wire n1411_o;
  wire n1412_o;
  wire n1414_o;
  wire n1415_o;
  wire n1416_o;
  wire [2:0] n1418_o;
  wire [2:0] n1419_o;
  wire n1420_o;
  wire n1422_o;
  wire n1423_o;
  wire n1424_o;
  wire n1426_o;
  wire n1428_o;
  wire n1430_o;
  wire n1431_o;
  wire n1432_o;
  wire [2:0] n1433_o;
  wire n1435_o;
  wire n1436_o;
  wire n1438_o;
  wire n1441_o;
  wire n1442_o;
  wire [1:0] n1454_o;
  wire [2:0] n1455_o;
  wire n1457_o;
  wire n1459_o;
  wire n1461_o;
  wire n1462_o;
  wire n1463_o;
  wire n1464_o;
  wire n1465_o;
  wire n1467_o;
  wire n1468_o;
  wire [2:0] n1469_o;
  wire n1470_o;
  wire [2:0] n1472_o;
  wire n1474_o;
  wire n1476_o;
  wire n1478_o;
  wire n1479_o;
  wire n1480_o;
  wire n1481_o;
  wire n1482_o;
  wire [1:0] n1483_o;
  wire n1485_o;
  wire n1486_o;
  wire [2:0] n1487_o;
  wire [2:0] n1489_o;
  wire n1491_o;
  wire n1492_o;
  wire [2:0] n1493_o;
  wire [2:0] n1495_o;
  wire n1497_o;
  wire n1498_o;
  wire [2:0] n1499_o;
  wire [2:0] n1501_o;
  wire n1503_o;
  wire n1504_o;
  wire [2:0] n1505_o;
  wire [15:0] n1507_o;
  wire n1508_o;
  wire [15:0] n1509_o;
  wire [15:0] n1511_o;
  wire n1515_o;
  wire n1516_o;
  wire n1517_o;
  wire n1518_o;
  wire n1519_o;
  wire n1521_o;
  wire n1522_o;
  wire n1523_o;
  wire n1524_o;
  wire n1525_o;
  wire n1526_o;
  wire n1528_o;
  wire n1530_o;
  wire n1531_o;
  wire n1533_o;
  wire n1534_o;
  wire n1536_o;
  wire n1537_o;
  wire n1539_o;
  wire n1540_o;
  wire n1542_o;
  wire n1543_o;
  reg n1545_o;
  reg n1547_o;
  wire n1549_o;
  wire n1552_o;
  wire n1555_o;
  wire n1557_o;
  wire n1558_o;
  wire n1559_o;
  wire n1561_o;
  wire n1563_o;
  wire n1564_o;
  wire n1566_o;
  wire n1567_o;
  wire n1569_o;
  wire n1570_o;
  wire n1572_o;
  wire n1574_o;
  wire n1575_o;
  wire n1576_o;
  wire n1577_o;
  wire [1:0] n1578_o;
  wire n1580_o;
  wire n1582_o;
  wire n1583_o;
  wire n1585_o;
  wire n1586_o;
  reg n1588_o;
  reg n1590_o;
  wire n1591_o;
  wire n1592_o;
  wire n1597_o;
  wire n1598_o;
  wire [7:0] n1599_o;
  wire [7:0] n1600_o;
  wire [7:0] n1601_o;
  wire [7:0] n1602_o;
  wire n1604_o;
  wire n1605_o;
  wire [7:0] n1606_o;
  wire [7:0] n1607_o;
  wire [7:0] n1608_o;
  wire [7:0] n1609_o;
  wire n1610_o;
  wire n1612_o;
  wire n1614_o;
  wire n1615_o;
  wire n1617_o;
  wire n1619_o;
  wire n1620_o;
  wire n1621_o;
  wire n1622_o;
  wire [7:0] n1623_o;
  wire [7:0] n1624_o;
  wire [7:0] n1625_o;
  wire [7:0] n1626_o;
  wire [7:0] u_regs_n1628;
  wire [7:0] u_regs_n1629;
  wire [7:0] u_regs_n1630;
  wire [7:0] u_regs_n1631;
  wire [7:0] u_regs_n1632;
  wire [7:0] u_regs_n1633;
  wire [127:0] u_regs_n1634;
  wire [127:0] n1635_o;
  wire [7:0] u_regs_doah;
  wire [7:0] u_regs_doal;
  wire [7:0] u_regs_dobh;
  wire [7:0] u_regs_dobl;
  wire [7:0] u_regs_doch;
  wire [7:0] u_regs_docl;
  wire [127:0] u_regs_dor;
  wire n1654_o;
  wire n1655_o;
  wire [7:0] n1656_o;
  wire [7:0] n1657_o;
  wire [7:0] n1658_o;
  wire n1660_o;
  wire n1662_o;
  wire n1663_o;
  wire n1665_o;
  wire n1666_o;
  wire n1668_o;
  wire n1669_o;
  wire n1671_o;
  wire n1672_o;
  wire n1674_o;
  wire n1675_o;
  wire n1677_o;
  wire [7:0] n1678_o;
  wire n1680_o;
  wire [7:0] n1681_o;
  wire n1683_o;
  wire n1685_o;
  wire n1687_o;
  wire [7:0] n1688_o;
  wire n1690_o;
  wire [7:0] n1691_o;
  wire n1693_o;
  wire n1695_o;
  wire n1696_o;
  wire [7:0] n1699_o;
  wire n1701_o;
  wire [9:0] n1702_o;
  reg [7:0] n1705_o;
  wire n1707_o;
  wire n1708_o;
  wire [7:0] n1709_o;
  wire [7:0] n1710_o;
  wire [7:0] n1711_o;
  wire n1713_o;
  wire n1715_o;
  wire n1716_o;
  wire n1718_o;
  wire n1719_o;
  wire n1721_o;
  wire n1722_o;
  wire n1724_o;
  wire n1725_o;
  wire n1727_o;
  wire n1728_o;
  wire n1730_o;
  wire [7:0] n1731_o;
  wire n1733_o;
  wire [7:0] n1734_o;
  wire n1736_o;
  wire n1738_o;
  wire [5:0] n1739_o;
  reg [7:0] n1742_o;
  wire [7:0] n1743_o;
  wire [7:0] n1744_o;
  wire n1752_o;
  wire n1754_o;
  wire n1755_o;
  wire n1757_o;
  wire n1759_o;
  wire n1760_o;
  wire n1762_o;
  wire n1763_o;
  wire n1764_o;
  wire n1767_o;
  wire n1773_o;
  wire n1774_o;
  wire n1775_o;
  reg n1776_oldnmi_n;
  wire n1779_o;
  wire n1781_o;
  wire n1782_o;
  wire n1783_o;
  wire n1784_o;
  wire n1786_o;
  wire n1787_o;
  wire n1788_o;
  wire n1790_o;
  wire n1792_o;
  wire n1793_o;
  wire n1794_o;
  wire n1795_o;
  wire n1796_o;
  wire n1797_o;
  wire n1798_o;
  wire n1799_o;
  wire n1800_o;
  wire n1801_o;
  wire n1802_o;
  wire n1803_o;
  wire n1804_o;
  wire n1805_o;
  wire n1806_o;
  wire n1807_o;
  wire n1808_o;
  wire n1809_o;
  wire n1810_o;
  wire n1811_o;
  wire n1812_o;
  wire n1813_o;
  wire n1815_o;
  wire n1817_o;
  wire n1819_o;
  wire n1820_o;
  wire n1821_o;
  wire n1822_o;
  wire n1824_o;
  wire n1826_o;
  wire n1828_o;
  wire n1829_o;
  wire n1830_o;
  wire n1831_o;
  wire n1833_o;
  wire n1835_o;
  wire n1837_o;
  wire n1838_o;
  wire n1839_o;
  wire n1841_o;
  wire n1842_o;
  wire n1843_o;
  wire n1845_o;
  wire n1846_o;
  wire n1847_o;
  wire n1849_o;
  wire n1851_o;
  wire n1853_o;
  wire [2:0] n1855_o;
  wire n1857_o;
  wire n1861_o;
  wire [2:0] n1863_o;
  wire n1864_o;
  wire n1865_o;
  wire n1867_o;
  wire n1868_o;
  wire n1869_o;
  wire n1870_o;
  wire n1872_o;
  wire n1873_o;
  wire n1874_o;
  wire n1875_o;
  wire n1877_o;
  wire n1878_o;
  wire n1879_o;
  wire n1880_o;
  wire n1882_o;
  wire n1884_o;
  wire n1887_o;
  wire n1889_o;
  wire n1890_o;
  wire n1892_o;
  wire n1894_o;
  wire n1898_o;
  wire [2:0] n1901_o;
  wire n1903_o;
  wire [2:0] n1905_o;
  wire n1906_o;
  wire n1907_o;
  wire n1908_o;
  wire n1909_o;
  wire n1910_o;
  wire n1911_o;
  wire [2:0] n1912_o;
  wire n1913_o;
  wire n1914_o;
  wire n1915_o;
  wire n1916_o;
  wire n1917_o;
  wire n1918_o;
  wire [2:0] n1920_o;
  wire n1921_o;
  wire n1922_o;
  wire n1923_o;
  wire [2:0] n1924_o;
  wire n1925_o;
  wire n1926_o;
  wire n1927_o;
  wire [2:0] n1929_o;
  wire [2:0] n1930_o;
  wire n1931_o;
  wire n1932_o;
  wire n1935_o;
  wire n1936_o;
  wire [2:0] n1937_o;
  wire n1938_o;
  wire n1939_o;
  wire n1940_o;
  wire n1941_o;
  wire n1943_o;
  wire n1944_o;
  wire n1945_o;
  wire n1946_o;
  wire n1947_o;
  wire [2:0] n1949_o;
  wire [2:0] n1950_o;
  wire n1951_o;
  wire [2:0] n1952_o;
  wire [2:0] n1953_o;
  wire n1954_o;
  wire n1955_o;
  wire n1956_o;
  wire n1958_o;
  wire n1959_o;
  wire [2:0] n1960_o;
  wire n1961_o;
  wire n1962_o;
  wire n1963_o;
  wire [2:0] n1964_o;
  wire [2:0] n1965_o;
  wire n1966_o;
  wire n1967_o;
  wire n1968_o;
  wire n1970_o;
  wire n1972_o;
  wire [2:0] n1973_o;
  wire n1974_o;
  wire n1975_o;
  wire n1976_o;
  wire [2:0] n1977_o;
  wire [2:0] n1978_o;
  wire n1979_o;
  wire n1980_o;
  wire n1981_o;
  wire n1982_o;
  wire n1983_o;
  wire [2:0] n1984_o;
  wire n1985_o;
  wire n1986_o;
  wire n1988_o;
  wire n1990_o;
  wire n1991_o;
  wire n1992_o;
  wire n1993_o;
  wire n1994_o;
  wire n1995_o;
  wire n1996_o;
  wire n1997_o;
  wire n1998_o;
  wire n1999_o;
  wire n2000_o;
  wire n2001_o;
  wire n2002_o;
  wire n2003_o;
  wire n2004_o;
  wire n2005_o;
  wire n2006_o;
  wire [2:0] n2007_o;
  wire [2:0] n2008_o;
  wire n2009_o;
  wire n2010_o;
  wire n2011_o;
  wire n2012_o;
  wire n2013_o;
  wire n2014_o;
  wire [2:0] n2015_o;
  wire n2016_o;
  wire n2017_o;
  wire n2018_o;
  wire n2019_o;
  wire n2020_o;
  wire n2021_o;
  wire n2070_o;
  wire n2071_o;
  reg n2072_q;
  wire n2075_o;
  wire n2076_o;
  wire n2077_o;
  reg [7:0] n2079_q;
  reg [7:0] n2080_q;
  reg [7:0] n2081_q;
  reg [7:0] n2082_q;
  reg [7:0] n2083_q;
  reg [7:0] n2084_q;
  reg [15:0] n2085_q;
  reg [15:0] n2086_q;
  wire [15:0] n2087_o;
  wire [15:0] n2088_o;
  wire [15:0] n2089_o;
  wire [2:0] n2090_o;
  reg [2:0] n2091_q;
  wire [2:0] n2092_o;
  reg [2:0] n2093_q;
  wire [2:0] n2094_o;
  reg [2:0] n2095_q;
  reg n2096_q;
  reg [15:0] n2097_q;
  reg [7:0] n2098_q;
  reg [1:0] n2099_q;
  wire [15:0] n2100_o;
  reg [15:0] n2101_q;
  reg [2:0] n2102_q;
  reg [2:0] n2103_q;
  reg n2104_q;
  reg n2105_q;
  reg n2106_q;
  reg n2107_q;
  reg n2108_q;
  reg n2109_q;
  reg [1:0] n2110_q;
  reg [1:0] n2111_q;
  reg [2:0] n2112_q;
  reg n2113_q;
  reg n2114_q;
  reg n2115_q;
  reg n2116_q;
  reg n2117_q;
  wire n2118_o;
  reg n2119_q;
  wire [7:0] n2120_o;
  reg [7:0] n2121_q;
  wire [7:0] n2122_o;
  reg [7:0] n2123_q;
  reg [4:0] n2124_q;
  reg n2125_q;
  reg n2126_q;
  reg [3:0] n2127_q;
  reg n2128_q;
  reg n2129_q;
  reg [2:0] n2130_q;
  reg n2131_q;
  reg n2132_q;
  reg n2133_q;
  reg n2134_q;
  wire n2135_o;
  reg n2136_q;
  reg [15:0] n2137_q;
  reg [7:0] n2138_q;
  assign m1_n = n2134_q;
  assign iorq = iorq_i;
  assign noread = mcode_n247;
  assign write = mcode_n248;
  assign rfsh_n = n2136_q;
  assign halt_n = n1773_o;
  assign busak_n = n1774_o;
  assign a = n2137_q;
  assign dout = n2138_q;
  assign mc = mcycle;
  assign ts = tstate;
  assign intcycle_n = n1775_o;
  assign inte = inte_ff1;
  assign stop = i_djnz;
  assign regs = n183_o;
  /* T80.vhd:263:16  */
  assign acc = n2079_q; // (signal)
  /* T80.vhd:263:21  */
  assign f = n2080_q; // (signal)
  /* T80.vhd:264:16  */
  assign ap = n2081_q; // (signal)
  /* T80.vhd:264:20  */
  assign fp = n2082_q; // (signal)
  /* T80.vhd:265:16  */
  assign i = n2083_q; // (signal)
  /* T80.vhd:266:16  */
  assign r = n2084_q; // (signal)
  /* T80.vhd:267:16  */
  assign sp = n2085_q; // (signal)
  /* T80.vhd:267:20  */
  assign pc = n2086_q; // (signal)
  /* T80.vhd:269:16  */
  assign regdih = n1625_o; // (signal)
  /* T80.vhd:270:16  */
  assign regdil = n1626_o; // (signal)
  /* T80.vhd:271:16  */
  assign regbusa = n2087_o; // (signal)
  /* T80.vhd:272:16  */
  assign regbusb = n2088_o; // (signal)
  /* T80.vhd:273:16  */
  assign regbusc = n2089_o; // (signal)
  /* T80.vhd:274:16  */
  assign regaddra_r = n2091_q; // (signal)
  /* T80.vhd:275:16  */
  assign regaddra = n1469_o; // (signal)
  /* T80.vhd:276:16  */
  assign regaddrb_r = n2093_q; // (signal)
  /* T80.vhd:277:16  */
  assign regaddrb = n1505_o; // (signal)
  /* T80.vhd:278:16  */
  assign regaddrc = n2095_q; // (signal)
  /* T80.vhd:279:16  */
  assign regweh = n1591_o; // (signal)
  /* T80.vhd:280:16  */
  assign regwel = n1592_o; // (signal)
  /* T80.vhd:281:16  */
  assign alternate = n2096_q; // (signal)
  /* T80.vhd:284:16  */
  assign wz = n2097_q; // (signal)
  /* T80.vhd:285:16  */
  assign ir = n2098_q; // (signal)
  /* T80.vhd:286:16  */
  assign iset = n2099_q; // (signal)
  /* T80.vhd:287:16  */
  assign regbusa_r = n2101_q; // (signal)
  /* T80.vhd:289:16  */
  assign id16 = n1509_o; // (signal)
  /* T80.vhd:290:16  */
  assign save_mux = n381_o; // (signal)
  /* T80.vhd:292:16  */
  assign tstate = n2102_q; // (signal)
  /* T80.vhd:293:16  */
  assign mcycle = n2103_q; // (signal)
  /* T80.vhd:294:16  */
  assign inte_ff1 = n2104_q; // (signal)
  /* T80.vhd:295:16  */
  assign inte_ff2 = n2105_q; // (signal)
  /* T80.vhd:296:16  */
  assign halt_ff = n2106_q; // (signal)
  /* T80.vhd:297:16  */
  assign busreq_s = n2107_q; // (signal)
  /* T80.vhd:298:16  */
  assign busack = n2108_q; // (signal)
  /* T80.vhd:299:16  */
  assign clken = n354_o; // (signal)
  /* T80.vhd:300:16  */
  assign nmi_s = n2109_q; // (signal)
  /* T80.vhd:301:16  */
  assign istatus = n2110_q; // (signal)
  /* T80.vhd:864:50  */
  assign di_reg = di; // (signal)
  /* T80.vhd:304:16  */
  assign t_res = n357_o; // (signal)
  /* T80.vhd:305:16  */
  assign xy_state = n2111_q; // (signal)
  /* T80.vhd:306:16  */
  assign pre_xy_f_m = n2112_q; // (signal)
  /* T80.vhd:307:16  */
  assign nextis_xy_fetch = n379_o; // (signal)
  /* T80.vhd:308:16  */
  assign xy_ind = n2113_q; // (signal)
  /* T80.vhd:309:16  */
  assign no_btr = n2114_q; // (signal)
  /* T80.vhd:310:16  */
  assign btr_r = n2115_q; // (signal)
  /* T80.vhd:311:16  */
  assign auto_wait = n2077_o; // (signal)
  /* T80.vhd:312:16  */
  assign auto_wait_t1 = n2116_q; // (signal)
  /* T80.vhd:313:16  */
  assign auto_wait_t2 = n2117_q; // (signal)
  /* T80.vhd:314:16  */
  assign incdecz = n2119_q; // (signal)
  /* T80.vhd:317:16  */
  assign busb = n2121_q; // (signal)
  /* T80.vhd:318:16  */
  assign busa = n2123_q; // (signal)
  /* T80.vhd:319:16  */
  assign alu_q = u_alu_n347; // (signal)
  /* T80.vhd:320:16  */
  assign f_out = u_alu_n348; // (signal)
  /* T80.vhd:323:16  */
  assign read_to_reg_r = n2124_q; // (signal)
  /* T80.vhd:324:16  */
  assign arith16_r = n2125_q; // (signal)
  /* T80.vhd:325:16  */
  assign z16_r = n2126_q; // (signal)
  /* T80.vhd:326:16  */
  assign alu_op_r = n2127_q; // (signal)
  /* T80.vhd:327:16  */
  assign save_alu_r = n2128_q; // (signal)
  /* T80.vhd:328:16  */
  assign preservec_r = n2129_q; // (signal)
  /* T80.vhd:329:16  */
  assign mcycles = n2130_q; // (signal)
  /* T80.vhd:332:16  */
  assign mcycles_d = mcode_n202; // (signal)
  /* T80.vhd:333:16  */
  assign tstates = mcode_n203; // (signal)
  /* T80.vhd:334:16  */
  assign intcycle = n2131_q; // (signal)
  /* T80.vhd:335:16  */
  assign nmicycle = n2132_q; // (signal)
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
  assign i_rxdd = n2133_q; // (signal)
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
  assign dor = u_regs_n1634; // (signal)
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
  t80_mcode_0_0_1_2_3_4_5_6_7 mcode (
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
  t80_alu_0_0_1_2_3_4_5_6_7 u_alu (
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
  assign n402_o = n1241_o ? imode : istatus;
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
  /* T80.vhd:569:75  */
  assign n424_o = r[6:0];
  /* T80.vhd:569:88  */
  assign n426_o = n424_o + 7'b0000001;
  /* T80.vhd:572:57  */
  assign n427_o = ~jump;
  /* T80.vhd:572:72  */
  assign n428_o = ~call;
  /* T80.vhd:572:63  */
  assign n429_o = n428_o & n427_o;
  /* T80.vhd:572:91  */
  assign n430_o = ~nmicycle;
  /* T80.vhd:572:78  */
  assign n431_o = n430_o & n429_o;
  /* T80.vhd:572:110  */
  assign n432_o = ~intcycle;
  /* T80.vhd:572:97  */
  assign n433_o = n432_o & n431_o;
  /* T80.vhd:572:139  */
  assign n434_o = halt_ff | halt;
  /* T80.vhd:572:120  */
  assign n435_o = ~n434_o;
  /* T80.vhd:572:116  */
  assign n436_o = n435_o & n433_o;
  /* T80.vhd:573:66  */
  assign n438_o = pc + 16'b0000000000000001;
  /* T80.vhd:565:41  */
  assign n439_o = n481_o ? n438_o : pc;
  /* T80.vhd:576:79  */
  assign n441_o = istatus == 2'b01;
  /* T80.vhd:576:67  */
  assign n442_o = n441_o & intcycle;
  /* T80.vhd:578:100  */
  assign n444_o = istatus == 2'b10;
  /* T80.vhd:578:88  */
  assign n445_o = n444_o & intcycle;
  /* T80.vhd:578:69  */
  assign n446_o = halt_ff | n445_o;
  /* T80.vhd:578:108  */
  assign n447_o = n446_o | nmicycle;
  /* T80.vhd:578:49  */
  assign n449_o = n447_o ? 8'b00000000 : dinst;
  /* T80.vhd:576:49  */
  assign n451_o = n442_o ? 8'b11111111 : n449_o;
  /* T80.vhd:585:59  */
  assign n453_o = prefix != 2'b00;
  /* T80.vhd:586:67  */
  assign n455_o = prefix == 2'b11;
  /* T80.vhd:587:70  */
  assign n456_o = ir[5];
  /* T80.vhd:587:65  */
  assign n459_o = n456_o ? 2'b10 : 2'b01;
  /* T80.vhd:593:75  */
  assign n461_o = prefix == 2'b10;
  /* T80.vhd:593:65  */
  assign n463_o = n461_o ? 2'b00 : xy_state;
  /* T80.vhd:593:65  */
  assign n465_o = n461_o ? 1'b0 : xy_ind;
  /* T80.vhd:586:57  */
  assign n467_o = n455_o ? 2'b00 : prefix;
  /* T80.vhd:586:57  */
  assign n468_o = n455_o ? n459_o : n463_o;
  /* T80.vhd:586:57  */
  assign n469_o = n455_o ? xy_ind : n465_o;
  /* T80.vhd:585:49  */
  assign n471_o = n453_o ? n467_o : 2'b00;
  /* T80.vhd:585:49  */
  assign n474_o = n453_o ? n468_o : 2'b00;
  /* T80.vhd:585:49  */
  assign n476_o = n453_o ? n469_o : 1'b0;
  assign n477_o = {i, r};
  /* T80.vhd:565:41  */
  assign n478_o = n423_o ? n477_o : n2137_q;
  assign n479_o = r[6:0];
  /* T80.vhd:562:33  */
  assign n480_o = n817_o ? n426_o : n479_o;
  /* T80.vhd:565:41  */
  assign n481_o = n423_o & n436_o;
  /* T80.vhd:565:41  */
  assign n482_o = n423_o ? n451_o : ir;
  /* T80.vhd:565:41  */
  assign n483_o = n423_o ? n471_o : iset;
  /* T80.vhd:543:25  */
  assign n484_o = n1242_o ? n474_o : xy_state;
  /* T80.vhd:565:41  */
  assign n485_o = n423_o ? n476_o : xy_ind;
  /* T80.vhd:608:51  */
  assign n487_o = mcycle == 3'b110;
  /* T80.vhd:610:59  */
  assign n489_o = prefix == 2'b01;
  /* T80.vhd:608:41  */
  assign n491_o = n492_o ? 2'b01 : iset;
  /* T80.vhd:608:41  */
  assign n492_o = n487_o & n489_o;
  /* T80.vhd:608:41  */
  assign n494_o = n487_o ? 1'b1 : xy_ind;
  /* T80.vhd:616:64  */
  assign n495_o = i_bt | i_bc;
  /* T80.vhd:616:72  */
  assign n496_o = n495_o | i_btr;
  /* T80.vhd:616:86  */
  assign n497_o = ~no_btr;
  /* T80.vhd:616:82  */
  assign n498_o = n496_o & n497_o;
  /* T80.vhd:619:76  */
  assign n499_o = wz[7:0];
  /* T80.vhd:621:86  */
  assign n500_o = wz[7:0];
  /* T80.vhd:625:66  */
  assign n501_o = call | rstp;
  /* T80.vhd:628:62  */
  assign n502_o = mcycle == mcycles;
  /* T80.vhd:628:72  */
  assign n503_o = nmicycle & n502_o;
  /* T80.vhd:631:62  */
  assign n505_o = mcycle == 3'b011;
  /* T80.vhd:631:70  */
  assign n506_o = intcycle & n505_o;
  /* T80.vhd:631:101  */
  assign n508_o = istatus == 2'b10;
  /* T80.vhd:631:89  */
  assign n509_o = n508_o & n506_o;
  /* T80.vhd:633:76  */
  assign n510_o = wz[7:0];
  /* T80.vhd:635:86  */
  assign n511_o = wz[7:0];
  /* T80.vhd:639:77  */
  assign n513_o = xy_state == 2'b00;
  /* T80.vhd:642:73  */
  assign n514_o = nextis_xy_fetch ? pc : wz;
  /* T80.vhd:639:65  */
  assign n515_o = n513_o ? regbusc : n514_o;
  /* T80.vhd:638:57  */
  assign n517_o = set_addr_to == 3'b010;
  /* T80.vhd:659:76  */
  assign n518_o = {acc, di_reg};
  /* T80.vhd:659:86  */
  assign n521_o = n518_o + 16'b0000000000000001;
  /* T80.vhd:648:57  */
  assign n523_o = set_addr_to == 3'b100;
  /* T80.vhd:660:57  */
  assign n525_o = set_addr_to == 3'b101;
  /* T80.vhd:669:82  */
  assign n527_o = setwz == 2'b01;
  /* T80.vhd:670:95  */
  assign n530_o = regbusc + 16'b0000000000000001;
  /* T80.vhd:669:73  */
  assign n531_o = n527_o ? n530_o : wz;
  /* T80.vhd:672:82  */
  assign n533_o = setwz == 2'b10;
  /* T80.vhd:673:106  */
  assign n534_o = regbusc[7:0];
  /* T80.vhd:673:119  */
  assign n537_o = n534_o + 8'b00000001;
  assign n538_o = {acc, n537_o};
  /* T80.vhd:672:73  */
  assign n539_o = n533_o ? n538_o : n531_o;
  /* T80.vhd:662:57  */
  assign n541_o = set_addr_to == 3'b000;
  /* T80.vhd:679:74  */
  assign n543_o = setwz == 2'b10;
  /* T80.vhd:680:98  */
  assign n544_o = regbusc[7:0];
  /* T80.vhd:680:111  */
  assign n547_o = n544_o + 8'b00000001;
  assign n548_o = {acc, n547_o};
  /* T80.vhd:679:65  */
  assign n549_o = n543_o ? n548_o : wz;
  /* T80.vhd:677:57  */
  assign n551_o = set_addr_to == 3'b001;
  /* T80.vhd:685:108  */
  assign n553_o = wz + 16'b0000000000000001;
  /* T80.vhd:688:92  */
  assign n554_o = wz[7:0];
  /* T80.vhd:689:82  */
  assign n556_o = setwz == 2'b10;
  /* T80.vhd:690:101  */
  assign n557_o = wz[7:0];
  /* T80.vhd:690:114  */
  assign n560_o = n557_o + 8'b00000001;
  assign n561_o = {acc, n560_o};
  /* T80.vhd:689:73  */
  assign n562_o = n556_o ? n561_o : wz;
  assign n563_o = {di_reg, n554_o};
  /* T80.vhd:684:65  */
  assign n564_o = inc_wz ? n553_o : n563_o;
  /* T80.vhd:684:65  */
  assign n565_o = inc_wz ? wz : n562_o;
  /* T80.vhd:683:57  */
  assign n567_o = set_addr_to == 3'b110;
  assign n568_o = {n567_o, n551_o, n541_o, n525_o, n523_o, n517_o};
  assign n569_o = n515_o[7:0];
  assign n570_o = sp[7:0];
  assign n571_o = regbusc[7:0];
  assign n572_o = regbusc[7:0];
  assign n573_o = n564_o[7:0];
  assign n574_o = pc[7:0];
  /* T80.vhd:637:57  */
  always @*
    case (n568_o)
      6'b100000: n575_o = n573_o;
      6'b010000: n575_o = n572_o;
      6'b001000: n575_o = n571_o;
      6'b000100: n575_o = n570_o;
      6'b000010: n575_o = di_reg;
      6'b000001: n575_o = n569_o;
      default: n575_o = n574_o;
    endcase
  assign n576_o = n515_o[15:8];
  assign n577_o = sp[15:8];
  assign n578_o = regbusc[15:8];
  assign n579_o = regbusc[15:8];
  assign n580_o = n564_o[15:8];
  assign n581_o = pc[15:8];
  /* T80.vhd:637:57  */
  always @*
    case (n568_o)
      6'b100000: n582_o = n580_o;
      6'b010000: n582_o = n579_o;
      6'b001000: n582_o = n578_o;
      6'b000100: n582_o = n577_o;
      6'b000010: n582_o = acc;
      6'b000001: n582_o = n576_o;
      default: n582_o = n581_o;
    endcase
  /* T80.vhd:637:57  */
  always @*
    case (n568_o)
      6'b100000: n583_o = n565_o;
      6'b010000: n583_o = n549_o;
      6'b001000: n583_o = n539_o;
      6'b000100: n583_o = wz;
      6'b000010: n583_o = n521_o;
      6'b000001: n583_o = wz;
      default: n583_o = wz;
    endcase
  assign n584_o = {n582_o, n575_o};
  assign n585_o = {i, n510_o};
  /* T80.vhd:631:49  */
  assign n586_o = n509_o ? n585_o : n584_o;
  assign n587_o = {i, n511_o};
  /* T80.vhd:631:49  */
  assign n588_o = n509_o ? n587_o : pc;
  /* T80.vhd:631:49  */
  assign n589_o = n509_o ? wz : n583_o;
  /* T80.vhd:628:49  */
  assign n591_o = n503_o ? 16'b0000000001100110 : n586_o;
  /* T80.vhd:628:49  */
  assign n593_o = n503_o ? 16'b0000000001100110 : n588_o;
  /* T80.vhd:628:49  */
  assign n594_o = n503_o ? wz : n589_o;
  /* T80.vhd:625:49  */
  assign n595_o = n501_o ? wz : n591_o;
  /* T80.vhd:625:49  */
  assign n596_o = n501_o ? wz : n593_o;
  /* T80.vhd:625:49  */
  assign n597_o = n501_o ? wz : n594_o;
  /* T80.vhd:622:49  */
  assign n598_o = jumpxy ? regbusc : n595_o;
  /* T80.vhd:622:49  */
  assign n599_o = jumpxy ? regbusc : n596_o;
  /* T80.vhd:622:49  */
  assign n600_o = jumpxy ? wz : n597_o;
  assign n601_o = {di_reg, n499_o};
  /* T80.vhd:617:49  */
  assign n602_o = jump ? n601_o : n598_o;
  assign n603_o = {di_reg, n500_o};
  /* T80.vhd:617:49  */
  assign n604_o = jump ? n603_o : n599_o;
  /* T80.vhd:617:49  */
  assign n605_o = jump ? wz : n600_o;
  /* T80.vhd:699:58  */
  assign n607_o = setwz == 2'b11;
  /* T80.vhd:699:49  */
  assign n608_o = n607_o ? id16 : n605_o;
  /* T80.vhd:708:64  */
  assign n609_o = ~acc;
  /* T80.vhd:709:77  */
  assign n610_o = acc[5];
  /* T80.vhd:709:70  */
  assign n611_o = ~n610_o;
  /* T80.vhd:711:77  */
  assign n613_o = acc[3];
  /* T80.vhd:711:70  */
  assign n614_o = ~n613_o;
  /* T80.vhd:615:41  */
  assign n616_o = n644_o ? n609_o : acc;
  assign n617_o = {n611_o, 1'b1, n614_o};
  assign n618_o = f[1];
  /* T80.vhd:706:49  */
  assign n619_o = i_cpl ? 1'b1 : n618_o;
  /* T80.vhd:716:75  */
  assign n622_o = f[0];
  /* T80.vhd:716:70  */
  assign n623_o = ~n622_o;
  /* T80.vhd:717:73  */
  assign n624_o = acc[5];
  /* T80.vhd:718:71  */
  assign n625_o = f[0];
  /* T80.vhd:719:73  */
  assign n626_o = acc[3];
  assign n628_o = {1'b0, n623_o};
  assign n629_o = {n624_o, n625_o, n626_o};
  assign n630_o = f[0];
  assign n631_o = {n619_o, n630_o};
  /* T80.vhd:714:49  */
  assign n632_o = i_ccf ? n628_o : n631_o;
  /* T80.vhd:725:73  */
  assign n635_o = acc[5];
  /* T80.vhd:727:73  */
  assign n637_o = acc[3];
  assign n639_o = {1'b0, 1'b1};
  assign n640_o = {n635_o, 1'b0, n637_o};
  /* T80.vhd:722:49  */
  assign n641_o = i_scf ? n639_o : n632_o;
  /* T80.vhd:615:41  */
  assign n643_o = t_res ? n602_o : n2137_q;
  /* T80.vhd:615:41  */
  assign n644_o = t_res & i_cpl;
  assign n645_o = f[1:0];
  /* T80.vhd:615:41  */
  assign n646_o = t_res ? n641_o : n645_o;
  /* T80.vhd:615:41  */
  assign n649_o = t_res ? n604_o : pc;
  /* T80.vhd:615:41  */
  assign n650_o = t_res ? n608_o : wz;
  /* T80.vhd:615:41  */
  assign n651_o = t_res ? n498_o : btr_r;
  /* T80.vhd:615:41  */
  assign n653_o = t_res ? alu_op : 4'b0000;
  /* T80.vhd:615:41  */
  assign n655_o = t_res ? save_alu : 1'b0;
  /* T80.vhd:732:52  */
  assign n657_o = tstate == 3'b010;
  /* T80.vhd:732:56  */
  assign n658_o = i_btr & n657_o;
  /* T80.vhd:732:78  */
  assign n659_o = ir[0];
  /* T80.vhd:732:72  */
  assign n660_o = n659_o & n658_o;
  /* T80.vhd:732:100  */
  assign n662_o = tstate == 3'b001;
  /* T80.vhd:732:104  */
  assign n663_o = i_btr & n662_o;
  /* T80.vhd:732:126  */
  assign n664_o = ir[0];
  /* T80.vhd:732:130  */
  assign n665_o = ~n664_o;
  /* T80.vhd:732:120  */
  assign n666_o = n665_o & n663_o;
  /* T80.vhd:732:89  */
  assign n667_o = n660_o | n666_o;
  /* T80.vhd:733:61  */
  assign n669_o = {1'b0, di_reg};
  /* T80.vhd:733:101  */
  assign n670_o = id16[7:0];
  /* T80.vhd:733:78  */
  assign n672_o = {1'b0, n670_o};
  /* T80.vhd:733:71  */
  assign n673_o = n669_o + n672_o;
  /* T80.vhd:734:68  */
  assign n674_o = di_reg[7];
  /* T80.vhd:735:65  */
  assign n675_o = n673_o[8];
  /* T80.vhd:736:65  */
  assign n676_o = n673_o[8];
  /* T80.vhd:737:61  */
  assign n678_o = n673_o & 9'b000000111;
  /* T80.vhd:737:88  */
  assign n680_o = {1'b0, busa};
  /* T80.vhd:737:80  */
  assign n681_o = n678_o ^ n680_o;
  /* T80.vhd:738:70  */
  assign n682_o = n681_o[0];
  /* T80.vhd:738:81  */
  assign n683_o = n681_o[1];
  /* T80.vhd:738:74  */
  assign n684_o = n682_o ^ n683_o;
  /* T80.vhd:738:92  */
  assign n685_o = n681_o[2];
  /* T80.vhd:738:85  */
  assign n686_o = n684_o ^ n685_o;
  /* T80.vhd:738:103  */
  assign n687_o = n681_o[3];
  /* T80.vhd:738:96  */
  assign n688_o = n686_o ^ n687_o;
  /* T80.vhd:738:114  */
  assign n689_o = n681_o[4];
  /* T80.vhd:738:107  */
  assign n690_o = n688_o ^ n689_o;
  /* T80.vhd:738:125  */
  assign n691_o = n681_o[5];
  /* T80.vhd:738:118  */
  assign n692_o = n690_o ^ n691_o;
  /* T80.vhd:738:136  */
  assign n693_o = n681_o[6];
  /* T80.vhd:738:129  */
  assign n694_o = n692_o ^ n693_o;
  /* T80.vhd:738:147  */
  assign n695_o = n681_o[7];
  /* T80.vhd:738:140  */
  assign n696_o = n694_o ^ n695_o;
  /* T80.vhd:738:62  */
  assign n697_o = ~n696_o;
  assign n698_o = {n697_o, n674_o, n675_o};
  assign n699_o = f[2];
  assign n700_o = {n699_o, n646_o};
  /* T80.vhd:732:41  */
  assign n701_o = n667_o ? n698_o : n700_o;
  assign n702_o = n640_o[1];
  assign n703_o = n629_o[1];
  assign n704_o = n617_o[1];
  assign n705_o = f[4];
  /* T80.vhd:706:49  */
  assign n706_o = i_cpl ? n704_o : n705_o;
  /* T80.vhd:714:49  */
  assign n707_o = i_ccf ? n703_o : n706_o;
  /* T80.vhd:722:49  */
  assign n708_o = i_scf ? n702_o : n707_o;
  assign n709_o = f[4];
  /* T80.vhd:615:41  */
  assign n710_o = t_res ? n708_o : n709_o;
  /* T80.vhd:732:41  */
  assign n711_o = n667_o ? n676_o : n710_o;
  assign n712_o = n640_o[2];
  assign n713_o = n629_o[2];
  assign n714_o = n617_o[2];
  assign n715_o = f[5];
  /* T80.vhd:706:49  */
  assign n716_o = i_cpl ? n714_o : n715_o;
  /* T80.vhd:714:49  */
  assign n717_o = i_ccf ? n713_o : n716_o;
  /* T80.vhd:722:49  */
  assign n718_o = i_scf ? n712_o : n717_o;
  assign n719_o = f[5];
  /* T80.vhd:615:41  */
  assign n720_o = t_res ? n718_o : n719_o;
  assign n721_o = n640_o[0];
  assign n722_o = n629_o[0];
  assign n723_o = n617_o[0];
  assign n724_o = f[3];
  /* T80.vhd:706:49  */
  assign n725_o = i_cpl ? n723_o : n724_o;
  /* T80.vhd:714:49  */
  assign n726_o = i_ccf ? n722_o : n725_o;
  /* T80.vhd:722:49  */
  assign n727_o = i_scf ? n721_o : n726_o;
  assign n728_o = f[3];
  /* T80.vhd:615:41  */
  assign n729_o = t_res ? n727_o : n728_o;
  /* T80.vhd:741:51  */
  assign n732_o = tstate == 3'b010;
  /* T80.vhd:741:55  */
  assign n733_o = wait_n & n732_o;
  /* T80.vhd:742:57  */
  assign n735_o = iset == 2'b01;
  /* T80.vhd:742:75  */
  assign n737_o = mcycle == 3'b111;
  /* T80.vhd:742:64  */
  assign n738_o = n737_o & n735_o;
  /* T80.vhd:741:41  */
  assign n739_o = n760_o ? dinst : ir;
  /* T80.vhd:746:83  */
  assign n740_o = {{8{di_reg[7]}}, di_reg}; // sext
  /* T80.vhd:746:83  */
  assign n741_o = pc + n740_o;
  /* T80.vhd:747:91  */
  assign n742_o = {{8{di_reg[7]}}, di_reg}; // sext
  /* T80.vhd:747:91  */
  assign n743_o = pc + n742_o;
  /* T80.vhd:749:66  */
  assign n745_o = pc + 16'b0000000000000001;
  /* T80.vhd:748:49  */
  assign n746_o = inc_pc ? n745_o : n649_o;
  /* T80.vhd:745:49  */
  assign n747_o = jumpe ? n741_o : n746_o;
  /* T80.vhd:745:49  */
  assign n748_o = jumpe ? n743_o : n650_o;
  /* T80.vhd:752:66  */
  assign n750_o = pc - 16'b0000000000000010;
  /* T80.vhd:751:49  */
  assign n751_o = btr_r ? n750_o : n747_o;
  /* T80.vhd:756:77  */
  assign n752_o = ir[5:3];
  assign n754_o = n753_o[15:6];
  assign n755_o = n753_o[2:0];
  assign n756_o = {n754_o, n752_o, n755_o};
  /* T80.vhd:754:49  */
  assign n757_o = rstp ? n756_o : n748_o;
  /* T80.vhd:741:41  */
  assign n758_o = n733_o ? n751_o : n649_o;
  /* T80.vhd:741:41  */
  assign n759_o = n733_o ? n757_o : n650_o;
  /* T80.vhd:741:41  */
  assign n760_o = n733_o & n738_o;
  /* T80.vhd:759:51  */
  assign n762_o = tstate == 3'b011;
  /* T80.vhd:759:66  */
  assign n764_o = mcycle == 3'b110;
  /* T80.vhd:759:55  */
  assign n765_o = n764_o & n762_o;
  /* T80.vhd:760:88  */
  assign n766_o = {{8{di_reg[7]}}, di_reg}; // sext
  /* T80.vhd:760:88  */
  assign n767_o = regbusc + n766_o;
  /* T80.vhd:759:41  */
  assign n768_o = n765_o ? n767_o : n759_o;
  /* T80.vhd:763:51  */
  assign n770_o = mcycle == 3'b011;
  /* T80.vhd:763:70  */
  assign n772_o = tstate == 3'b100;
  /* T80.vhd:763:59  */
  assign n773_o = n772_o & n770_o;
  /* T80.vhd:763:85  */
  assign n774_o = ~no_btr;
  /* T80.vhd:763:74  */
  assign n775_o = n774_o & n773_o;
  /* T80.vhd:764:63  */
  assign n776_o = i_bt | i_bc;
  /* T80.vhd:765:83  */
  assign n779_o = pc - 16'b0000000000000001;
  /* T80.vhd:763:41  */
  assign n780_o = n781_o ? n779_o : n768_o;
  /* T80.vhd:763:41  */
  assign n781_o = n775_o & n776_o;
  /* T80.vhd:769:52  */
  assign n783_o = tstate == 3'b010;
  /* T80.vhd:769:56  */
  assign n784_o = wait_n & n783_o;
  /* T80.vhd:769:85  */
  assign n786_o = tstate == 3'b100;
  /* T80.vhd:769:100  */
  assign n788_o = mcycle == 3'b001;
  /* T80.vhd:769:89  */
  assign n789_o = n788_o & n786_o;
  /* T80.vhd:769:74  */
  assign n790_o = n784_o | n789_o;
  /* T80.vhd:770:61  */
  assign n791_o = incdec_16[2:0];
  /* T80.vhd:770:74  */
  assign n793_o = n791_o == 3'b111;
  /* T80.vhd:771:69  */
  assign n794_o = incdec_16[3];
  /* T80.vhd:772:74  */
  assign n796_o = sp - 16'b0000000000000001;
  /* T80.vhd:774:74  */
  assign n798_o = sp + 16'b0000000000000001;
  /* T80.vhd:771:57  */
  assign n799_o = n794_o ? n796_o : n798_o;
  /* T80.vhd:769:41  */
  assign n800_o = n801_o ? n799_o : sp;
  /* T80.vhd:769:41  */
  assign n801_o = n790_o & n793_o;
  /* T80.vhd:779:41  */
  assign n802_o = ldsphl ? regbusc : n800_o;
  /* T80.vhd:782:41  */
  assign n803_o = exchangeaf ? ap : n616_o;
  assign n804_o = f[7:6];
  assign n805_o = {n804_o, n720_o, n711_o, n729_o, n701_o};
  /* T80.vhd:782:41  */
  assign n807_o = exchangeaf ? acc : ap;
  /* T80.vhd:782:41  */
  assign n808_o = exchangeaf ? f : fp;
  /* T80.vhd:789:62  */
  assign n809_o = ~alternate;
  /* T80.vhd:788:41  */
  assign n810_o = exchangers ? n809_o : alternate;
  /* T80.vhd:562:33  */
  assign n811_o = n420_o ? n478_o : n643_o;
  /* T80.vhd:562:33  */
  assign n812_o = n420_o ? acc : n803_o;
  /* T80.vhd:562:33  */
  assign n814_o = n420_o ? ap : n807_o;
  /* T80.vhd:562:33  */
  assign n815_o = n420_o ? fp : n808_o;
  /* T80.vhd:562:33  */
  assign n817_o = n420_o & n423_o;
  /* T80.vhd:562:33  */
  assign n818_o = n420_o ? sp : n802_o;
  /* T80.vhd:562:33  */
  assign n819_o = n420_o ? n439_o : n758_o;
  /* T80.vhd:562:33  */
  assign n820_o = n420_o ? alternate : n810_o;
  /* T80.vhd:562:33  */
  assign n821_o = n420_o ? wz : n780_o;
  /* T80.vhd:562:33  */
  assign n822_o = n420_o ? n482_o : n739_o;
  /* T80.vhd:562:33  */
  assign n823_o = n420_o ? n483_o : n491_o;
  /* T80.vhd:562:33  */
  assign n824_o = n420_o & n423_o;
  /* T80.vhd:562:33  */
  assign n825_o = n420_o ? n485_o : n494_o;
  /* T80.vhd:562:33  */
  assign n826_o = n420_o ? btr_r : n651_o;
  /* T80.vhd:562:33  */
  assign n828_o = n420_o ? 4'b0000 : n653_o;
  /* T80.vhd:562:33  */
  assign n831_o = n420_o ? 1'b0 : n655_o;
  /* T80.vhd:793:43  */
  assign n835_o = tstate == 3'b011;
  assign n836_o = wz[7:0];
  assign n837_o = n779_o[7:0];
  assign n838_o = n767_o[7:0];
  assign n839_o = n756_o[7:0];
  assign n840_o = n743_o[7:0];
  assign n841_o = id16[7:0];
  assign n842_o = wz[7:0];
  assign n843_o = wz[7:0];
  assign n844_o = wz[7:0];
  assign n845_o = wz[7:0];
  assign n846_o = wz[7:0];
  assign n847_o = n583_o[7:0];
  /* T80.vhd:631:49  */
  assign n848_o = n509_o ? n846_o : n847_o;
  /* T80.vhd:628:49  */
  assign n849_o = n503_o ? n845_o : n848_o;
  /* T80.vhd:625:49  */
  assign n850_o = n501_o ? n844_o : n849_o;
  /* T80.vhd:622:49  */
  assign n851_o = jumpxy ? n843_o : n850_o;
  /* T80.vhd:617:49  */
  assign n852_o = jump ? n842_o : n851_o;
  /* T80.vhd:699:49  */
  assign n853_o = n607_o ? n841_o : n852_o;
  assign n854_o = wz[7:0];
  /* T80.vhd:615:41  */
  assign n855_o = t_res ? n853_o : n854_o;
  /* T80.vhd:745:49  */
  assign n856_o = jumpe ? n840_o : n855_o;
  /* T80.vhd:754:49  */
  assign n857_o = rstp ? n839_o : n856_o;
  assign n858_o = id16[7:0];
  assign n859_o = wz[7:0];
  assign n860_o = wz[7:0];
  assign n861_o = wz[7:0];
  assign n862_o = wz[7:0];
  assign n863_o = wz[7:0];
  assign n864_o = n583_o[7:0];
  /* T80.vhd:631:49  */
  assign n865_o = n509_o ? n863_o : n864_o;
  /* T80.vhd:628:49  */
  assign n866_o = n503_o ? n862_o : n865_o;
  /* T80.vhd:625:49  */
  assign n867_o = n501_o ? n861_o : n866_o;
  /* T80.vhd:622:49  */
  assign n868_o = jumpxy ? n860_o : n867_o;
  /* T80.vhd:617:49  */
  assign n869_o = jump ? n859_o : n868_o;
  /* T80.vhd:699:49  */
  assign n870_o = n607_o ? n858_o : n869_o;
  assign n871_o = wz[7:0];
  /* T80.vhd:615:41  */
  assign n872_o = t_res ? n870_o : n871_o;
  /* T80.vhd:741:41  */
  assign n873_o = n733_o ? n857_o : n872_o;
  /* T80.vhd:759:41  */
  assign n874_o = n765_o ? n838_o : n873_o;
  /* T80.vhd:763:41  */
  assign n875_o = n781_o ? n837_o : n874_o;
  /* T80.vhd:562:33  */
  assign n876_o = n420_o ? n836_o : n875_o;
  /* T80.vhd:794:41  */
  assign n877_o = ldz ? di_reg : n876_o;
  assign n878_o = wz[15:8];
  assign n879_o = n779_o[15:8];
  assign n880_o = n767_o[15:8];
  assign n881_o = n756_o[15:8];
  assign n882_o = n743_o[15:8];
  assign n883_o = id16[15:8];
  assign n884_o = wz[15:8];
  assign n885_o = wz[15:8];
  assign n886_o = wz[15:8];
  assign n887_o = wz[15:8];
  assign n888_o = wz[15:8];
  assign n889_o = n583_o[15:8];
  /* T80.vhd:631:49  */
  assign n890_o = n509_o ? n888_o : n889_o;
  /* T80.vhd:628:49  */
  assign n891_o = n503_o ? n887_o : n890_o;
  /* T80.vhd:625:49  */
  assign n892_o = n501_o ? n886_o : n891_o;
  /* T80.vhd:622:49  */
  assign n893_o = jumpxy ? n885_o : n892_o;
  /* T80.vhd:617:49  */
  assign n894_o = jump ? n884_o : n893_o;
  /* T80.vhd:699:49  */
  assign n895_o = n607_o ? n883_o : n894_o;
  assign n896_o = wz[15:8];
  /* T80.vhd:615:41  */
  assign n897_o = t_res ? n895_o : n896_o;
  /* T80.vhd:745:49  */
  assign n898_o = jumpe ? n882_o : n897_o;
  /* T80.vhd:754:49  */
  assign n899_o = rstp ? n881_o : n898_o;
  assign n900_o = id16[15:8];
  assign n901_o = wz[15:8];
  assign n902_o = wz[15:8];
  assign n903_o = wz[15:8];
  assign n904_o = wz[15:8];
  assign n905_o = wz[15:8];
  assign n906_o = n583_o[15:8];
  /* T80.vhd:631:49  */
  assign n907_o = n509_o ? n905_o : n906_o;
  /* T80.vhd:628:49  */
  assign n908_o = n503_o ? n904_o : n907_o;
  /* T80.vhd:625:49  */
  assign n909_o = n501_o ? n903_o : n908_o;
  /* T80.vhd:622:49  */
  assign n910_o = jumpxy ? n902_o : n909_o;
  /* T80.vhd:617:49  */
  assign n911_o = jump ? n901_o : n910_o;
  /* T80.vhd:699:49  */
  assign n912_o = n607_o ? n900_o : n911_o;
  assign n913_o = wz[15:8];
  /* T80.vhd:615:41  */
  assign n914_o = t_res ? n912_o : n913_o;
  /* T80.vhd:741:41  */
  assign n915_o = n733_o ? n899_o : n914_o;
  /* T80.vhd:759:41  */
  assign n916_o = n765_o ? n880_o : n915_o;
  /* T80.vhd:763:41  */
  assign n917_o = n781_o ? n879_o : n916_o;
  /* T80.vhd:562:33  */
  assign n918_o = n420_o ? n878_o : n917_o;
  /* T80.vhd:797:41  */
  assign n919_o = ldw ? di_reg : n918_o;
  /* T80.vhd:801:54  */
  assign n920_o = special_ld[2];
  /* T80.vhd:802:64  */
  assign n921_o = special_ld[1:0];
  /* T80.vhd:806:71  */
  assign n922_o = i[7];
  /* T80.vhd:808:62  */
  assign n924_o = i == 8'b00000000;
  /* T80.vhd:808:57  */
  assign n927_o = n924_o ? 1'b1 : 1'b0;
  /* T80.vhd:814:71  */
  assign n928_o = i[5];
  /* T80.vhd:816:71  */
  assign n930_o = i[3];
  /* T80.vhd:803:49  */
  assign n933_o = n921_o == 2'b00;
  /* T80.vhd:823:71  */
  assign n934_o = r[7];
  /* T80.vhd:825:62  */
  assign n936_o = r == 8'b00000000;
  /* T80.vhd:825:57  */
  assign n939_o = n936_o ? 1'b1 : 1'b0;
  /* T80.vhd:831:71  */
  assign n940_o = r[5];
  /* T80.vhd:833:71  */
  assign n942_o = r[3];
  /* T80.vhd:820:49  */
  assign n945_o = n921_o == 2'b01;
  /* T80.vhd:836:49  */
  assign n947_o = n921_o == 2'b10;
  assign n948_o = {n947_o, n945_o, n933_o};
  /* T80.vhd:802:49  */
  always @*
    case (n948_o)
      3'b100: n949_o = n812_o;
      3'b010: n949_o = r;
      3'b001: n949_o = i;
      default: n949_o = n812_o;
    endcase
  assign n950_o = f[1];
  assign n951_o = fp[1];
  assign n952_o = n805_o[1];
  /* T80.vhd:782:41  */
  assign n953_o = exchangeaf ? n951_o : n952_o;
  /* T80.vhd:562:33  */
  assign n954_o = n420_o ? n950_o : n953_o;
  /* T80.vhd:802:49  */
  always @*
    case (n948_o)
      3'b100: n955_o = n954_o;
      3'b010: n955_o = 1'b0;
      3'b001: n955_o = 1'b0;
      default: n955_o = n954_o;
    endcase
  assign n956_o = f[2];
  assign n957_o = fp[2];
  assign n958_o = n805_o[2];
  /* T80.vhd:782:41  */
  assign n959_o = exchangeaf ? n957_o : n958_o;
  /* T80.vhd:562:33  */
  assign n960_o = n420_o ? n956_o : n959_o;
  /* T80.vhd:802:49  */
  always @*
    case (n948_o)
      3'b100: n961_o = n960_o;
      3'b010: n961_o = inte_ff2;
      3'b001: n961_o = inte_ff2;
      default: n961_o = n960_o;
    endcase
  assign n962_o = f[3];
  assign n963_o = fp[3];
  assign n964_o = n805_o[3];
  /* T80.vhd:782:41  */
  assign n965_o = exchangeaf ? n963_o : n964_o;
  /* T80.vhd:562:33  */
  assign n966_o = n420_o ? n962_o : n965_o;
  /* T80.vhd:802:49  */
  always @*
    case (n948_o)
      3'b100: n967_o = n966_o;
      3'b010: n967_o = n942_o;
      3'b001: n967_o = n930_o;
      default: n967_o = n966_o;
    endcase
  assign n968_o = f[4];
  assign n969_o = fp[4];
  assign n970_o = n805_o[4];
  /* T80.vhd:782:41  */
  assign n971_o = exchangeaf ? n969_o : n970_o;
  /* T80.vhd:562:33  */
  assign n972_o = n420_o ? n968_o : n971_o;
  /* T80.vhd:802:49  */
  always @*
    case (n948_o)
      3'b100: n973_o = n972_o;
      3'b010: n973_o = 1'b0;
      3'b001: n973_o = 1'b0;
      default: n973_o = n972_o;
    endcase
  assign n974_o = f[5];
  assign n975_o = fp[5];
  assign n976_o = n805_o[5];
  /* T80.vhd:782:41  */
  assign n977_o = exchangeaf ? n975_o : n976_o;
  /* T80.vhd:562:33  */
  assign n978_o = n420_o ? n974_o : n977_o;
  /* T80.vhd:802:49  */
  always @*
    case (n948_o)
      3'b100: n979_o = n978_o;
      3'b010: n979_o = n940_o;
      3'b001: n979_o = n928_o;
      default: n979_o = n978_o;
    endcase
  assign n980_o = f[6];
  assign n981_o = fp[6];
  assign n982_o = n805_o[6];
  /* T80.vhd:782:41  */
  assign n983_o = exchangeaf ? n981_o : n982_o;
  /* T80.vhd:562:33  */
  assign n984_o = n420_o ? n980_o : n983_o;
  /* T80.vhd:802:49  */
  always @*
    case (n948_o)
      3'b100: n985_o = n984_o;
      3'b010: n985_o = n939_o;
      3'b001: n985_o = n927_o;
      default: n985_o = n984_o;
    endcase
  assign n986_o = f[7];
  assign n987_o = fp[7];
  assign n988_o = n805_o[7];
  /* T80.vhd:782:41  */
  assign n989_o = exchangeaf ? n987_o : n988_o;
  /* T80.vhd:562:33  */
  assign n990_o = n420_o ? n986_o : n989_o;
  /* T80.vhd:802:49  */
  always @*
    case (n948_o)
      3'b100: n991_o = n990_o;
      3'b010: n991_o = n934_o;
      3'b001: n991_o = n922_o;
      default: n991_o = n990_o;
    endcase
  /* T80.vhd:802:49  */
  always @*
    case (n948_o)
      3'b100: n992_o = acc;
      3'b010: n992_o = i;
      3'b001: n992_o = i;
      default: n992_o = i;
    endcase
  assign n993_o = r[7];
  assign n994_o = {n993_o, n480_o};
  /* T80.vhd:802:49  */
  always @*
    case (n948_o)
      3'b100: n995_o = n994_o;
      3'b010: n995_o = n994_o;
      3'b001: n995_o = n994_o;
      default: n995_o = acc;
    endcase
  /* T80.vhd:793:33  */
  assign n996_o = n1008_o ? n949_o : n812_o;
  assign n997_o = {n991_o, n985_o, n979_o, n973_o, n967_o, n961_o, n955_o};
  assign n998_o = f[7:1];
  assign n999_o = fp[7:1];
  assign n1000_o = n805_o[7:1];
  /* T80.vhd:782:41  */
  assign n1001_o = exchangeaf ? n999_o : n1000_o;
  /* T80.vhd:562:33  */
  assign n1002_o = n420_o ? n998_o : n1001_o;
  /* T80.vhd:801:41  */
  assign n1003_o = n920_o ? n997_o : n1002_o;
  /* T80.vhd:543:25  */
  assign n1004_o = n1233_o ? n992_o : i;
  assign n1005_o = r[7];
  assign n1006_o = {n1005_o, n480_o};
  /* T80.vhd:801:41  */
  assign n1007_o = n920_o ? n995_o : n1006_o;
  /* T80.vhd:793:33  */
  assign n1008_o = n835_o & n920_o;
  assign n1009_o = f[7:1];
  assign n1010_o = fp[7:1];
  assign n1011_o = n805_o[7:1];
  /* T80.vhd:782:41  */
  assign n1012_o = exchangeaf ? n1010_o : n1011_o;
  /* T80.vhd:562:33  */
  assign n1013_o = n420_o ? n1009_o : n1012_o;
  /* T80.vhd:793:33  */
  assign n1014_o = n835_o ? n1003_o : n1013_o;
  assign n1015_o = f[0];
  assign n1016_o = fp[0];
  assign n1017_o = n805_o[0];
  /* T80.vhd:782:41  */
  assign n1018_o = exchangeaf ? n1016_o : n1017_o;
  /* T80.vhd:562:33  */
  assign n1019_o = n420_o ? n1015_o : n1018_o;
  /* T80.vhd:793:33  */
  assign n1020_o = n835_o & n920_o;
  assign n1021_o = r[7];
  assign n1022_o = {n1021_o, n480_o};
  /* T80.vhd:793:33  */
  assign n1023_o = n835_o ? n1007_o : n1022_o;
  assign n1024_o = {n919_o, n877_o};
  /* T80.vhd:793:33  */
  assign n1025_o = n835_o ? n1024_o : n821_o;
  /* T80.vhd:844:44  */
  assign n1026_o = ~i_djnz;
  /* T80.vhd:844:50  */
  assign n1027_o = save_alu_r & n1026_o;
  /* T80.vhd:844:84  */
  assign n1029_o = alu_op_r == 4'b1001;
  /* T80.vhd:844:72  */
  assign n1030_o = n1027_o | n1029_o;
  /* T80.vhd:853:71  */
  assign n1031_o = f_out[7:1];
  /* T80.vhd:854:64  */
  assign n1032_o = ~preservec_r;
  /* T80.vhd:855:75  */
  assign n1033_o = f_out[0];
  /* T80.vhd:854:49  */
  assign n1034_o = n1032_o ? n1033_o : n1019_o;
  assign n1035_o = {n1031_o, n1034_o};
  assign n1036_o = {n1014_o, n1019_o};
  /* T80.vhd:859:48  */
  assign n1038_o = i_inrc & t_res;
  /* T80.vhd:862:60  */
  assign n1041_o = di_reg[3];
  /* T80.vhd:863:60  */
  assign n1042_o = di_reg[5];
  /* T80.vhd:864:63  */
  assign n1044_o = di_reg == 8'b00000000;
  /* T80.vhd:864:41  */
  assign n1047_o = n1044_o ? 1'b1 : 1'b0;
  /* T80.vhd:869:60  */
  assign n1048_o = di_reg[7];
  /* T80.vhd:870:65  */
  assign n1049_o = di_reg[0];
  /* T80.vhd:870:79  */
  assign n1050_o = di_reg[1];
  /* T80.vhd:870:69  */
  assign n1051_o = n1049_o ^ n1050_o;
  /* T80.vhd:870:93  */
  assign n1052_o = di_reg[2];
  /* T80.vhd:870:83  */
  assign n1053_o = n1051_o ^ n1052_o;
  /* T80.vhd:870:107  */
  assign n1054_o = di_reg[3];
  /* T80.vhd:870:97  */
  assign n1055_o = n1053_o ^ n1054_o;
  /* T80.vhd:871:55  */
  assign n1056_o = di_reg[4];
  /* T80.vhd:870:111  */
  assign n1057_o = n1055_o ^ n1056_o;
  /* T80.vhd:871:69  */
  assign n1058_o = di_reg[5];
  /* T80.vhd:871:59  */
  assign n1059_o = n1057_o ^ n1058_o;
  /* T80.vhd:871:83  */
  assign n1060_o = di_reg[6];
  /* T80.vhd:871:73  */
  assign n1061_o = n1059_o ^ n1060_o;
  /* T80.vhd:871:97  */
  assign n1062_o = di_reg[7];
  /* T80.vhd:871:87  */
  assign n1063_o = n1061_o ^ n1062_o;
  /* T80.vhd:870:54  */
  assign n1064_o = ~n1063_o;
  assign n1065_o = {n1048_o, n1047_o, n1042_o, 1'b0, n1041_o, n1064_o, 1'b0};
  assign n1070_o = n1035_o[0];
  assign n1071_o = n1036_o[0];
  /* T80.vhd:844:33  */
  assign n1072_o = n1030_o ? n1070_o : n1071_o;
  /* T80.vhd:874:43  */
  assign n1074_o = tstate == 3'b001;
  /* T80.vhd:874:64  */
  assign n1075_o = ~auto_wait_t1;
  /* T80.vhd:874:47  */
  assign n1076_o = n1075_o & n1074_o;
  /* T80.vhd:876:57  */
  assign n1077_o = i_rld | i_rrd;
  /* T80.vhd:877:50  */
  assign n1078_o = ~i_rxdd;
  /* T80.vhd:877:41  */
  assign n1079_o = n1078_o ? busb : n2138_q;
  /* T80.vhd:881:73  */
  assign n1080_o = busa[3:0];
  /* T80.vhd:882:73  */
  assign n1081_o = busb[3:0];
  assign n1082_o = {n1081_o, n1080_o};
  /* T80.vhd:880:41  */
  assign n1083_o = i_rld ? n1082_o : n1079_o;
  /* T80.vhd:885:73  */
  assign n1084_o = busb[7:4];
  /* T80.vhd:886:73  */
  assign n1085_o = busa[3:0];
  assign n1086_o = {n1085_o, n1084_o};
  /* T80.vhd:884:41  */
  assign n1087_o = i_rrd ? n1086_o : n1083_o;
  /* T80.vhd:874:33  */
  assign n1088_o = n1076_o ? n1087_o : n2138_q;
  /* T80.vhd:543:25  */
  assign n1089_o = n1252_o ? n1077_o : i_rxdd;
  assign n1092_o = {1'b1, 4'b0111};
  assign n1093_o = {read_to_reg, set_busa_to};
  /* T80.vhd:893:41  */
  assign n1094_o = read_to_acc ? n1092_o : n1093_o;
  /* T80.vhd:890:33  */
  assign n1096_o = t_res ? n1094_o : 5'b00000;
  /* T80.vhd:899:43  */
  assign n1099_o = tstate == 3'b001;
  /* T80.vhd:899:47  */
  assign n1100_o = i_bt & n1099_o;
  /* T80.vhd:900:59  */
  assign n1101_o = alu_q[3];
  /* T80.vhd:901:59  */
  assign n1102_o = alu_q[1];
  assign n1105_o = {n1102_o, 1'b0, n1101_o};
  assign n1106_o = n1065_o[0];
  assign n1107_o = n1035_o[1];
  assign n1108_o = n1036_o[1];
  /* T80.vhd:844:33  */
  assign n1109_o = n1030_o ? n1107_o : n1108_o;
  /* T80.vhd:859:33  */
  assign n1110_o = n1038_o ? n1106_o : n1109_o;
  /* T80.vhd:899:33  */
  assign n1111_o = n1100_o ? 1'b0 : n1110_o;
  assign n1123_o = n1065_o[6:5];
  assign n1124_o = n1035_o[7:6];
  assign n1125_o = n1036_o[7:6];
  /* T80.vhd:844:33  */
  assign n1126_o = n1030_o ? n1124_o : n1125_o;
  /* T80.vhd:859:33  */
  assign n1127_o = n1038_o ? n1123_o : n1126_o;
  assign n1128_o = n1065_o[1];
  assign n1129_o = n1035_o[2];
  assign n1130_o = n1036_o[2];
  /* T80.vhd:844:33  */
  assign n1131_o = n1030_o ? n1129_o : n1130_o;
  /* T80.vhd:859:33  */
  assign n1132_o = n1038_o ? n1128_o : n1131_o;
  /* T80.vhd:905:43  */
  assign n1134_o = tstate == 3'b001;
  /* T80.vhd:905:47  */
  assign n1135_o = i_bc & n1134_o;
  /* T80.vhd:906:72  */
  assign n1136_o = f_out[4];
  /* T80.vhd:906:65  */
  assign n1138_o = {7'b0000000, n1136_o};
  /* T80.vhd:906:52  */
  assign n1139_o = alu_q - n1138_o;
  /* T80.vhd:907:55  */
  assign n1140_o = n1139_o[3];
  /* T80.vhd:908:55  */
  assign n1141_o = n1139_o[1];
  assign n1142_o = n1105_o[0];
  assign n1143_o = n1065_o[2];
  assign n1144_o = n1035_o[3];
  assign n1145_o = n1036_o[3];
  /* T80.vhd:844:33  */
  assign n1146_o = n1030_o ? n1144_o : n1145_o;
  /* T80.vhd:859:33  */
  assign n1147_o = n1038_o ? n1143_o : n1146_o;
  /* T80.vhd:899:33  */
  assign n1148_o = n1100_o ? n1142_o : n1147_o;
  /* T80.vhd:905:33  */
  assign n1149_o = n1135_o ? n1140_o : n1148_o;
  assign n1150_o = n1105_o[2];
  assign n1151_o = n1065_o[4];
  assign n1152_o = n1035_o[5];
  assign n1153_o = n1036_o[5];
  /* T80.vhd:844:33  */
  assign n1154_o = n1030_o ? n1152_o : n1153_o;
  /* T80.vhd:859:33  */
  assign n1155_o = n1038_o ? n1151_o : n1154_o;
  /* T80.vhd:899:33  */
  assign n1156_o = n1100_o ? n1150_o : n1155_o;
  /* T80.vhd:905:33  */
  assign n1157_o = n1135_o ? n1141_o : n1156_o;
  assign n1165_o = n1105_o[1];
  assign n1166_o = n1065_o[3];
  assign n1167_o = n1035_o[4];
  assign n1168_o = n1036_o[4];
  /* T80.vhd:844:33  */
  assign n1169_o = n1030_o ? n1167_o : n1168_o;
  /* T80.vhd:859:33  */
  assign n1170_o = n1038_o ? n1166_o : n1169_o;
  /* T80.vhd:899:33  */
  assign n1171_o = n1100_o ? n1165_o : n1170_o;
  /* T80.vhd:910:47  */
  assign n1173_o = i_bc | i_bt;
  /* T80.vhd:910:33  */
  assign n1174_o = n1173_o ? incdecz : n1132_o;
  /* T80.vhd:914:44  */
  assign n1176_o = tstate == 3'b001;
  /* T80.vhd:914:63  */
  assign n1177_o = ~save_alu_r;
  /* T80.vhd:914:48  */
  assign n1178_o = n1177_o & n1176_o;
  /* T80.vhd:914:86  */
  assign n1179_o = ~auto_wait_t1;
  /* T80.vhd:914:69  */
  assign n1180_o = n1179_o & n1178_o;
  /* T80.vhd:915:72  */
  assign n1182_o = alu_op_r != 4'b0111;
  /* T80.vhd:915:59  */
  assign n1183_o = n1182_o & save_alu_r;
  /* T80.vhd:914:93  */
  assign n1184_o = n1180_o | n1183_o;
  /* T80.vhd:917:41  */
  assign n1186_o = read_to_reg_r == 5'b10111;
  /* T80.vhd:919:41  */
  assign n1188_o = read_to_reg_r == 5'b10110;
  /* T80.vhd:921:41  */
  assign n1190_o = read_to_reg_r == 5'b11000;
  /* T80.vhd:923:41  */
  assign n1192_o = read_to_reg_r == 5'b11001;
  /* T80.vhd:925:41  */
  assign n1194_o = read_to_reg_r == 5'b11011;
  assign n1195_o = {n1194_o, n1192_o, n1190_o, n1188_o, n1186_o};
  /* T80.vhd:916:41  */
  always @*
    case (n1195_o)
      5'b10000: n1196_o = n1088_o;
      5'b01000: n1196_o = n1088_o;
      5'b00100: n1196_o = n1088_o;
      5'b00010: n1196_o = save_mux;
      5'b00001: n1196_o = n1088_o;
      default: n1196_o = n1088_o;
    endcase
  /* T80.vhd:916:41  */
  always @*
    case (n1195_o)
      5'b10000: n1197_o = n996_o;
      5'b01000: n1197_o = n996_o;
      5'b00100: n1197_o = n996_o;
      5'b00010: n1197_o = n996_o;
      5'b00001: n1197_o = save_mux;
      default: n1197_o = n996_o;
    endcase
  assign n1198_o = {n1127_o, n1157_o, n1171_o, n1149_o, n1174_o, n1111_o, n1072_o};
  /* T80.vhd:916:41  */
  always @*
    case (n1195_o)
      5'b10000: n1199_o = save_mux;
      5'b01000: n1199_o = n1198_o;
      5'b00100: n1199_o = n1198_o;
      5'b00010: n1199_o = n1198_o;
      5'b00001: n1199_o = n1198_o;
      default: n1199_o = n1198_o;
    endcase
  assign n1200_o = sp[7:0];
  assign n1201_o = regbusc[7:0];
  assign n1202_o = n796_o[7:0];
  assign n1203_o = n798_o[7:0];
  /* T80.vhd:771:57  */
  assign n1204_o = n794_o ? n1202_o : n1203_o;
  assign n1205_o = sp[7:0];
  /* T80.vhd:769:41  */
  assign n1206_o = n801_o ? n1204_o : n1205_o;
  /* T80.vhd:779:41  */
  assign n1207_o = ldsphl ? n1201_o : n1206_o;
  /* T80.vhd:562:33  */
  assign n1208_o = n420_o ? n1200_o : n1207_o;
  /* T80.vhd:916:41  */
  always @*
    case (n1195_o)
      5'b10000: n1209_o = n1208_o;
      5'b01000: n1209_o = n1208_o;
      5'b00100: n1209_o = save_mux;
      5'b00010: n1209_o = n1208_o;
      5'b00001: n1209_o = n1208_o;
      default: n1209_o = n1208_o;
    endcase
  assign n1210_o = sp[15:8];
  assign n1211_o = regbusc[15:8];
  assign n1212_o = n796_o[15:8];
  assign n1213_o = n798_o[15:8];
  /* T80.vhd:771:57  */
  assign n1214_o = n794_o ? n1212_o : n1213_o;
  assign n1215_o = sp[15:8];
  /* T80.vhd:769:41  */
  assign n1216_o = n801_o ? n1214_o : n1215_o;
  /* T80.vhd:779:41  */
  assign n1217_o = ldsphl ? n1211_o : n1216_o;
  /* T80.vhd:562:33  */
  assign n1218_o = n420_o ? n1210_o : n1217_o;
  /* T80.vhd:916:41  */
  always @*
    case (n1195_o)
      5'b10000: n1219_o = n1218_o;
      5'b01000: n1219_o = save_mux;
      5'b00100: n1219_o = n1218_o;
      5'b00010: n1219_o = n1218_o;
      5'b00001: n1219_o = n1218_o;
      default: n1219_o = n1218_o;
    endcase
  /* T80.vhd:929:41  */
  assign n1220_o = xybit_undoc ? alu_q : n1196_o;
  /* T80.vhd:914:33  */
  assign n1221_o = n1184_o ? n1220_o : n1088_o;
  /* T80.vhd:914:33  */
  assign n1222_o = n1184_o ? n1197_o : n996_o;
  assign n1223_o = {n1127_o, n1157_o, n1171_o, n1149_o, n1174_o, n1111_o, n1072_o};
  /* T80.vhd:914:33  */
  assign n1224_o = n1184_o ? n1199_o : n1223_o;
  assign n1225_o = {n1219_o, n1209_o};
  /* T80.vhd:914:33  */
  assign n1226_o = n1184_o ? n1225_o : n818_o;
  /* T80.vhd:543:25  */
  assign n1227_o = clken ? n811_o : n2137_q;
  /* T80.vhd:543:25  */
  assign n1228_o = clken ? n1221_o : n2138_q;
  /* T80.vhd:543:25  */
  assign n1229_o = clken ? n1222_o : acc;
  /* T80.vhd:543:25  */
  assign n1230_o = clken ? n1224_o : f;
  /* T80.vhd:543:25  */
  assign n1231_o = clken ? n814_o : ap;
  /* T80.vhd:543:25  */
  assign n1232_o = clken ? n815_o : fp;
  /* T80.vhd:543:25  */
  assign n1233_o = clken & n1020_o;
  /* T80.vhd:543:25  */
  assign n1234_o = clken ? n1023_o : r;
  /* T80.vhd:543:25  */
  assign n1235_o = clken ? n1226_o : sp;
  /* T80.vhd:543:25  */
  assign n1236_o = clken ? n819_o : pc;
  /* T80.vhd:543:25  */
  assign n1237_o = clken ? n820_o : alternate;
  /* T80.vhd:543:25  */
  assign n1238_o = clken ? n1025_o : wz;
  /* T80.vhd:543:25  */
  assign n1239_o = clken ? n822_o : ir;
  /* T80.vhd:543:25  */
  assign n1240_o = clken ? n823_o : iset;
  /* T80.vhd:543:25  */
  assign n1241_o = clken & n401_o;
  /* T80.vhd:543:25  */
  assign n1242_o = clken & n824_o;
  /* T80.vhd:543:25  */
  assign n1243_o = clken ? n825_o : xy_ind;
  /* T80.vhd:543:25  */
  assign n1244_o = clken ? n826_o : btr_r;
  /* T80.vhd:543:25  */
  assign n1245_o = clken ? n1096_o : read_to_reg_r;
  /* T80.vhd:543:25  */
  assign n1246_o = clken ? arith16 : arith16_r;
  /* T80.vhd:543:25  */
  assign n1247_o = clken ? n415_o : z16_r;
  /* T80.vhd:543:25  */
  assign n1248_o = clken ? n828_o : alu_op_r;
  /* T80.vhd:543:25  */
  assign n1249_o = clken ? n831_o : save_alu_r;
  /* T80.vhd:543:25  */
  assign n1250_o = clken ? preservec : preservec_r;
  /* T80.vhd:543:25  */
  assign n1251_o = clken ? mcycles_d : mcycles;
  /* T80.vhd:543:25  */
  assign n1252_o = clken & n1076_o;
  /* T80.vhd:531:25  */
  assign n1255_o = dirset ? n398_o : n1227_o;
  /* T80.vhd:531:25  */
  assign n1256_o = dirset ? n2138_q : n1228_o;
  /* T80.vhd:531:25  */
  assign n1257_o = dirset ? n390_o : n1229_o;
  /* T80.vhd:531:25  */
  assign n1258_o = dirset ? n391_o : n1230_o;
  /* T80.vhd:531:25  */
  assign n1259_o = dirset ? n392_o : n1231_o;
  /* T80.vhd:531:25  */
  assign n1260_o = dirset ? n393_o : n1232_o;
  /* T80.vhd:531:25  */
  assign n1261_o = dirset ? n394_o : n1004_o;
  /* T80.vhd:531:25  */
  assign n1262_o = dirset ? n395_o : n1234_o;
  /* T80.vhd:531:25  */
  assign n1263_o = dirset ? n396_o : n1235_o;
  /* T80.vhd:531:25  */
  assign n1264_o = dirset ? n397_o : n1236_o;
  /* T80.vhd:531:25  */
  assign n1265_o = dirset ? alternate : n1237_o;
  /* T80.vhd:531:25  */
  assign n1266_o = dirset ? wz : n1238_o;
  /* T80.vhd:531:25  */
  assign n1267_o = dirset ? ir : n1239_o;
  /* T80.vhd:531:25  */
  assign n1268_o = dirset ? iset : n1240_o;
  /* T80.vhd:531:25  */
  assign n1269_o = dirset ? n399_o : n402_o;
  /* T80.vhd:531:25  */
  assign n1270_o = dirset ? xy_state : n484_o;
  /* T80.vhd:531:25  */
  assign n1271_o = dirset ? xy_ind : n1243_o;
  /* T80.vhd:531:25  */
  assign n1272_o = dirset ? btr_r : n1244_o;
  /* T80.vhd:531:25  */
  assign n1273_o = dirset ? read_to_reg_r : n1245_o;
  /* T80.vhd:531:25  */
  assign n1274_o = dirset ? arith16_r : n1246_o;
  /* T80.vhd:531:25  */
  assign n1275_o = dirset ? z16_r : n1247_o;
  /* T80.vhd:531:25  */
  assign n1276_o = dirset ? alu_op_r : n1248_o;
  /* T80.vhd:531:25  */
  assign n1277_o = dirset ? save_alu_r : n1249_o;
  /* T80.vhd:531:25  */
  assign n1278_o = dirset ? preservec_r : n1250_o;
  /* T80.vhd:531:25  */
  assign n1279_o = dirset ? mcycles : n1251_o;
  /* T80.vhd:531:25  */
  assign n1280_o = dirset ? i_rxdd : n1089_o;
  /* T80.vhd:947:70  */
  assign n1375_o = set_busa_to[2:1];
  /* T80.vhd:947:57  */
  assign n1376_o = {alternate, n1375_o};
  /* T80.vhd:948:43  */
  assign n1377_o = ~xy_ind;
  /* T80.vhd:948:62  */
  assign n1379_o = xy_state != 2'b00;
  /* T80.vhd:948:49  */
  assign n1380_o = n1379_o & n1377_o;
  /* T80.vhd:948:85  */
  assign n1381_o = set_busa_to[2:1];
  /* T80.vhd:948:98  */
  assign n1383_o = n1381_o == 2'b10;
  /* T80.vhd:948:70  */
  assign n1384_o = n1383_o & n1380_o;
  /* T80.vhd:949:63  */
  assign n1385_o = xy_state[1];
  /* T80.vhd:949:67  */
  assign n1387_o = {n1385_o, 2'b11};
  /* T80.vhd:948:33  */
  assign n1388_o = n1384_o ? n1387_o : n1376_o;
  /* T80.vhd:953:70  */
  assign n1389_o = set_busb_to[2:1];
  /* T80.vhd:953:57  */
  assign n1390_o = {alternate, n1389_o};
  /* T80.vhd:954:43  */
  assign n1391_o = ~xy_ind;
  /* T80.vhd:954:62  */
  assign n1393_o = xy_state != 2'b00;
  /* T80.vhd:954:49  */
  assign n1394_o = n1393_o & n1391_o;
  /* T80.vhd:954:85  */
  assign n1395_o = set_busb_to[2:1];
  /* T80.vhd:954:98  */
  assign n1397_o = n1395_o == 2'b10;
  /* T80.vhd:954:70  */
  assign n1398_o = n1397_o & n1394_o;
  /* T80.vhd:955:63  */
  assign n1399_o = xy_state[1];
  /* T80.vhd:955:67  */
  assign n1401_o = {n1399_o, 2'b11};
  /* T80.vhd:954:33  */
  assign n1402_o = n1398_o ? n1401_o : n1390_o;
  /* T80.vhd:959:68  */
  assign n1403_o = set_addr_to[1:0];
  /* T80.vhd:959:55  */
  assign n1404_o = {alternate, n1403_o};
  /* T80.vhd:961:50  */
  assign n1405_o = jumpxy | ldsphl;
  /* T80.vhd:962:63  */
  assign n1407_o = {alternate, 2'b10};
  /* T80.vhd:961:33  */
  assign n1408_o = n1405_o ? n1407_o : n1404_o;
  /* T80.vhd:964:51  */
  assign n1409_o = jumpxy | ldsphl;
  /* T80.vhd:964:81  */
  assign n1411_o = xy_state != 2'b00;
  /* T80.vhd:964:68  */
  assign n1412_o = n1411_o & n1409_o;
  /* T80.vhd:964:101  */
  assign n1414_o = mcycle == 3'b110;
  /* T80.vhd:964:90  */
  assign n1415_o = n1412_o | n1414_o;
  /* T80.vhd:965:61  */
  assign n1416_o = xy_state[1];
  /* T80.vhd:965:65  */
  assign n1418_o = {n1416_o, 2'b11};
  /* T80.vhd:964:33  */
  assign n1419_o = n1415_o ? n1418_o : n1408_o;
  /* T80.vhd:968:49  */
  assign n1420_o = save_alu_r & i_djnz;
  /* T80.vhd:968:70  */
  assign n1422_o = 1'b1 & n1420_o;
  /* T80.vhd:969:57  */
  assign n1423_o = f_out[6];
  /* T80.vhd:968:33  */
  assign n1424_o = n1422_o ? n1423_o : incdecz;
  /* T80.vhd:971:44  */
  assign n1426_o = tstate == 3'b010;
  /* T80.vhd:971:59  */
  assign n1428_o = tstate == 3'b011;
  /* T80.vhd:971:74  */
  assign n1430_o = mcycle == 3'b001;
  /* T80.vhd:971:63  */
  assign n1431_o = n1430_o & n1428_o;
  /* T80.vhd:971:48  */
  assign n1432_o = n1426_o | n1431_o;
  /* T80.vhd:971:97  */
  assign n1433_o = incdec_16[2:0];
  /* T80.vhd:971:110  */
  assign n1435_o = n1433_o == 3'b100;
  /* T80.vhd:971:84  */
  assign n1436_o = n1435_o & n1432_o;
  /* T80.vhd:972:49  */
  assign n1438_o = id16 == 16'b0000000000000000;
  /* T80.vhd:972:41  */
  assign n1441_o = n1438_o ? 1'b0 : 1'b1;
  /* T80.vhd:971:33  */
  assign n1442_o = n1436_o ? n1441_o : n1424_o;
  /* T80.vhd:986:46  */
  assign n1454_o = incdec_16[1:0];
  /* T80.vhd:986:35  */
  assign n1455_o = {alternate, n1454_o};
  /* T80.vhd:986:72  */
  assign n1457_o = tstate == 3'b010;
  /* T80.vhd:987:41  */
  assign n1459_o = tstate == 3'b011;
  /* T80.vhd:987:56  */
  assign n1461_o = mcycle == 3'b001;
  /* T80.vhd:987:45  */
  assign n1462_o = n1461_o & n1459_o;
  /* T80.vhd:987:77  */
  assign n1463_o = incdec_16[2];
  /* T80.vhd:987:64  */
  assign n1464_o = n1463_o & n1462_o;
  /* T80.vhd:986:76  */
  assign n1465_o = n1457_o | n1464_o;
  /* T80.vhd:987:102  */
  assign n1467_o = xy_state == 2'b00;
  /* T80.vhd:987:89  */
  assign n1468_o = n1467_o & n1465_o;
  /* T80.vhd:986:59  */
  assign n1469_o = n1468_o ? n1455_o : n1487_o;
  /* T80.vhd:988:33  */
  assign n1470_o = xy_state[1];
  /* T80.vhd:988:37  */
  assign n1472_o = {n1470_o, 2'b11};
  /* T80.vhd:988:57  */
  assign n1474_o = tstate == 3'b010;
  /* T80.vhd:989:41  */
  assign n1476_o = tstate == 3'b011;
  /* T80.vhd:989:56  */
  assign n1478_o = mcycle == 3'b001;
  /* T80.vhd:989:45  */
  assign n1479_o = n1478_o & n1476_o;
  /* T80.vhd:989:77  */
  assign n1480_o = incdec_16[2];
  /* T80.vhd:989:64  */
  assign n1481_o = n1480_o & n1479_o;
  /* T80.vhd:988:61  */
  assign n1482_o = n1474_o | n1481_o;
  /* T80.vhd:989:102  */
  assign n1483_o = incdec_16[1:0];
  /* T80.vhd:989:115  */
  assign n1485_o = n1483_o == 2'b10;
  /* T80.vhd:989:89  */
  assign n1486_o = n1485_o & n1482_o;
  /* T80.vhd:987:109  */
  assign n1487_o = n1486_o ? n1472_o : n1493_o;
  /* T80.vhd:991:35  */
  assign n1489_o = {alternate, 2'b10};
  /* T80.vhd:991:75  */
  assign n1491_o = tstate == 3'b011;
  /* T80.vhd:991:64  */
  assign n1492_o = n1491_o & exchangedh;
  /* T80.vhd:989:122  */
  assign n1493_o = n1492_o ? n1489_o : n1499_o;
  /* T80.vhd:992:35  */
  assign n1495_o = {alternate, 2'b01};
  /* T80.vhd:992:75  */
  assign n1497_o = tstate == 3'b100;
  /* T80.vhd:992:64  */
  assign n1498_o = n1497_o & exchangedh;
  /* T80.vhd:991:79  */
  assign n1499_o = n1498_o ? n1495_o : regaddra_r;
  /* T80.vhd:998:35  */
  assign n1501_o = {alternate, 2'b01};
  /* T80.vhd:998:75  */
  assign n1503_o = tstate == 3'b011;
  /* T80.vhd:998:64  */
  assign n1504_o = n1503_o & exchangedh;
  /* T80.vhd:998:42  */
  assign n1505_o = n1504_o ? n1501_o : regaddrb_r;
  /* T80.vhd:1002:33  */
  assign n1507_o = regbusa - 16'b0000000000000001;
  /* T80.vhd:1002:51  */
  assign n1508_o = incdec_16[3];
  /* T80.vhd:1002:37  */
  assign n1509_o = n1508_o ? n1507_o : n1511_o;
  /* T80.vhd:1003:41  */
  assign n1511_o = regbusa + 16'b0000000000000001;
  /* T80.vhd:1010:28  */
  assign n1515_o = tstate == 3'b001;
  /* T80.vhd:1010:47  */
  assign n1516_o = ~save_alu_r;
  /* T80.vhd:1010:32  */
  assign n1517_o = n1516_o & n1515_o;
  /* T80.vhd:1010:70  */
  assign n1518_o = ~auto_wait_t1;
  /* T80.vhd:1010:53  */
  assign n1519_o = n1518_o & n1517_o;
  /* T80.vhd:1011:56  */
  assign n1521_o = alu_op_r != 4'b0111;
  /* T80.vhd:1011:43  */
  assign n1522_o = n1521_o & save_alu_r;
  /* T80.vhd:1010:77  */
  assign n1523_o = n1519_o | n1522_o;
  /* T80.vhd:1014:60  */
  assign n1524_o = read_to_reg_r[0];
  /* T80.vhd:1014:43  */
  assign n1525_o = ~n1524_o;
  /* T80.vhd:1015:56  */
  assign n1526_o = read_to_reg_r[0];
  /* T80.vhd:1013:25  */
  assign n1528_o = read_to_reg_r == 5'b10000;
  /* T80.vhd:1013:38  */
  assign n1530_o = read_to_reg_r == 5'b10001;
  /* T80.vhd:1013:38  */
  assign n1531_o = n1528_o | n1530_o;
  /* T80.vhd:1013:48  */
  assign n1533_o = read_to_reg_r == 5'b10010;
  /* T80.vhd:1013:48  */
  assign n1534_o = n1531_o | n1533_o;
  /* T80.vhd:1013:58  */
  assign n1536_o = read_to_reg_r == 5'b10011;
  /* T80.vhd:1013:58  */
  assign n1537_o = n1534_o | n1536_o;
  /* T80.vhd:1013:68  */
  assign n1539_o = read_to_reg_r == 5'b10100;
  /* T80.vhd:1013:68  */
  assign n1540_o = n1537_o | n1539_o;
  /* T80.vhd:1013:78  */
  assign n1542_o = read_to_reg_r == 5'b10101;
  /* T80.vhd:1013:78  */
  assign n1543_o = n1540_o | n1542_o;
  /* T80.vhd:1012:25  */
  always @*
    case (n1543_o)
      1'b1: n1545_o = n1525_o;
      default: n1545_o = 1'b0;
    endcase
  /* T80.vhd:1012:25  */
  always @*
    case (n1543_o)
      1'b1: n1547_o = n1526_o;
      default: n1547_o = 1'b0;
    endcase
  /* T80.vhd:1010:17  */
  assign n1549_o = n1523_o ? n1545_o : 1'b0;
  /* T80.vhd:1010:17  */
  assign n1552_o = n1523_o ? n1547_o : 1'b0;
  /* T80.vhd:1020:49  */
  assign n1555_o = tstate == 3'b011;
  /* T80.vhd:1020:63  */
  assign n1557_o = tstate == 3'b100;
  /* T80.vhd:1020:53  */
  assign n1558_o = n1555_o | n1557_o;
  /* T80.vhd:1020:37  */
  assign n1559_o = n1558_o & exchangedh;
  /* T80.vhd:1020:17  */
  assign n1561_o = n1559_o ? 1'b1 : n1549_o;
  /* T80.vhd:1020:17  */
  assign n1563_o = n1559_o ? 1'b1 : n1552_o;
  /* T80.vhd:1025:29  */
  assign n1564_o = incdec_16[2];
  /* T80.vhd:1025:52  */
  assign n1566_o = tstate == 3'b010;
  /* T80.vhd:1025:56  */
  assign n1567_o = wait_n & n1566_o;
  /* T80.vhd:1025:84  */
  assign n1569_o = mcycle != 3'b001;
  /* T80.vhd:1025:73  */
  assign n1570_o = n1569_o & n1567_o;
  /* T80.vhd:1025:105  */
  assign n1572_o = tstate == 3'b011;
  /* T80.vhd:1025:120  */
  assign n1574_o = mcycle == 3'b001;
  /* T80.vhd:1025:109  */
  assign n1575_o = n1574_o & n1572_o;
  /* T80.vhd:1025:94  */
  assign n1576_o = n1570_o | n1575_o;
  /* T80.vhd:1025:39  */
  assign n1577_o = n1576_o & n1564_o;
  /* T80.vhd:1026:39  */
  assign n1578_o = incdec_16[1:0];
  /* T80.vhd:1027:25  */
  assign n1580_o = n1578_o == 2'b00;
  /* T80.vhd:1027:35  */
  assign n1582_o = n1578_o == 2'b01;
  /* T80.vhd:1027:35  */
  assign n1583_o = n1580_o | n1582_o;
  /* T80.vhd:1027:42  */
  assign n1585_o = n1578_o == 2'b10;
  /* T80.vhd:1027:42  */
  assign n1586_o = n1583_o | n1585_o;
  /* T80.vhd:1026:25  */
  always @*
    case (n1586_o)
      1'b1: n1588_o = 1'b1;
      default: n1588_o = n1561_o;
    endcase
  /* T80.vhd:1026:25  */
  always @*
    case (n1586_o)
      1'b1: n1590_o = 1'b1;
      default: n1590_o = n1563_o;
    endcase
  /* T80.vhd:1025:17  */
  assign n1591_o = n1577_o ? n1588_o : n1561_o;
  /* T80.vhd:1025:17  */
  assign n1592_o = n1577_o ? n1590_o : n1563_o;
  /* T80.vhd:1041:48  */
  assign n1597_o = tstate == 3'b011;
  /* T80.vhd:1041:37  */
  assign n1598_o = n1597_o & exchangedh;
  /* T80.vhd:1042:42  */
  assign n1599_o = regbusb[15:8];
  /* T80.vhd:1043:42  */
  assign n1600_o = regbusb[7:0];
  /* T80.vhd:1041:17  */
  assign n1601_o = n1598_o ? n1599_o : save_mux;
  /* T80.vhd:1041:17  */
  assign n1602_o = n1598_o ? n1600_o : save_mux;
  /* T80.vhd:1045:48  */
  assign n1604_o = tstate == 3'b100;
  /* T80.vhd:1045:37  */
  assign n1605_o = n1604_o & exchangedh;
  /* T80.vhd:1046:44  */
  assign n1606_o = regbusa_r[15:8];
  /* T80.vhd:1047:44  */
  assign n1607_o = regbusa_r[7:0];
  /* T80.vhd:1045:17  */
  assign n1608_o = n1605_o ? n1606_o : n1601_o;
  /* T80.vhd:1045:17  */
  assign n1609_o = n1605_o ? n1607_o : n1602_o;
  /* T80.vhd:1050:29  */
  assign n1610_o = incdec_16[2];
  /* T80.vhd:1050:52  */
  assign n1612_o = tstate == 3'b010;
  /* T80.vhd:1050:67  */
  assign n1614_o = mcycle != 3'b001;
  /* T80.vhd:1050:56  */
  assign n1615_o = n1614_o & n1612_o;
  /* T80.vhd:1050:88  */
  assign n1617_o = tstate == 3'b011;
  /* T80.vhd:1050:103  */
  assign n1619_o = mcycle == 3'b001;
  /* T80.vhd:1050:92  */
  assign n1620_o = n1619_o & n1617_o;
  /* T80.vhd:1050:77  */
  assign n1621_o = n1615_o | n1620_o;
  /* T80.vhd:1050:39  */
  assign n1622_o = n1621_o & n1610_o;
  /* T80.vhd:1051:56  */
  assign n1623_o = id16[15:8];
  /* T80.vhd:1052:56  */
  assign n1624_o = id16[7:0];
  /* T80.vhd:1050:17  */
  assign n1625_o = n1622_o ? n1623_o : n1608_o;
  /* T80.vhd:1050:17  */
  assign n1626_o = n1622_o ? n1624_o : n1609_o;
  /* T80.vhd:1067:33  */
  assign u_regs_n1628 = u_regs_doah; // (signal)
  /* T80.vhd:1068:33  */
  assign u_regs_n1629 = u_regs_doal; // (signal)
  /* T80.vhd:1069:33  */
  assign u_regs_n1630 = u_regs_dobh; // (signal)
  /* T80.vhd:1070:33  */
  assign u_regs_n1631 = u_regs_dobl; // (signal)
  /* T80.vhd:1071:33  */
  assign u_regs_n1632 = u_regs_doch; // (signal)
  /* T80.vhd:1072:33  */
  assign u_regs_n1633 = u_regs_docl; // (signal)
  /* T80.vhd:1073:33  */
  assign u_regs_n1634 = u_regs_dor; // (signal)
  /* T80.vhd:1075:36  */
  assign n1635_o = dir[207:80];
  /* T80.vhd:1056:9  */
  t80_reg u_regs (
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
    .dir(n1635_o),
    .doah(u_regs_doah),
    .doal(u_regs_doal),
    .dobh(u_regs_dobh),
    .dobl(u_regs_dobl),
    .doch(u_regs_doch),
    .docl(u_regs_docl),
    .dor(u_regs_dor));
  /* T80.vhd:1087:33  */
  assign n1654_o = set_busb_to == 4'b0111;
  /* T80.vhd:1090:55  */
  assign n1655_o = set_busb_to[0];
  /* T80.vhd:1091:64  */
  assign n1656_o = regbusb[7:0];
  /* T80.vhd:1093:64  */
  assign n1657_o = regbusb[15:8];
  /* T80.vhd:1090:41  */
  assign n1658_o = n1655_o ? n1656_o : n1657_o;
  /* T80.vhd:1089:33  */
  assign n1660_o = set_busb_to == 4'b0000;
  /* T80.vhd:1089:45  */
  assign n1662_o = set_busb_to == 4'b0001;
  /* T80.vhd:1089:45  */
  assign n1663_o = n1660_o | n1662_o;
  /* T80.vhd:1089:54  */
  assign n1665_o = set_busb_to == 4'b0010;
  /* T80.vhd:1089:54  */
  assign n1666_o = n1663_o | n1665_o;
  /* T80.vhd:1089:63  */
  assign n1668_o = set_busb_to == 4'b0011;
  /* T80.vhd:1089:63  */
  assign n1669_o = n1666_o | n1668_o;
  /* T80.vhd:1089:72  */
  assign n1671_o = set_busb_to == 4'b0100;
  /* T80.vhd:1089:72  */
  assign n1672_o = n1669_o | n1671_o;
  /* T80.vhd:1089:81  */
  assign n1674_o = set_busb_to == 4'b0101;
  /* T80.vhd:1089:81  */
  assign n1675_o = n1672_o | n1674_o;
  /* T80.vhd:1095:33  */
  assign n1677_o = set_busb_to == 4'b0110;
  /* T80.vhd:1098:68  */
  assign n1678_o = sp[7:0];
  /* T80.vhd:1097:33  */
  assign n1680_o = set_busb_to == 4'b1000;
  /* T80.vhd:1100:68  */
  assign n1681_o = sp[15:8];
  /* T80.vhd:1099:33  */
  assign n1683_o = set_busb_to == 4'b1001;
  /* T80.vhd:1101:33  */
  assign n1685_o = set_busb_to == 4'b1010;
  /* T80.vhd:1103:33  */
  assign n1687_o = set_busb_to == 4'b1011;
  /* T80.vhd:1106:68  */
  assign n1688_o = pc[7:0];
  /* T80.vhd:1105:33  */
  assign n1690_o = set_busb_to == 4'b1100;
  /* T80.vhd:1108:68  */
  assign n1691_o = pc[15:8];
  /* T80.vhd:1107:33  */
  assign n1693_o = set_busb_to == 4'b1101;
  /* T80.vhd:1110:47  */
  assign n1695_o = ir == 8'b01110001;
  /* T80.vhd:1110:55  */
  assign n1696_o = out0 & n1695_o;
  /* T80.vhd:1110:41  */
  assign n1699_o = n1696_o ? 8'b11111111 : 8'b00000000;
  /* T80.vhd:1109:33  */
  assign n1701_o = set_busb_to == 4'b1110;
  assign n1702_o = {n1701_o, n1693_o, n1690_o, n1687_o, n1685_o, n1683_o, n1680_o, n1677_o, n1675_o, n1654_o};
  /* T80.vhd:1086:33  */
  always @*
    case (n1702_o)
      10'b1000000000: n1705_o = n1699_o;
      10'b0100000000: n1705_o = n1691_o;
      10'b0010000000: n1705_o = n1688_o;
      10'b0001000000: n1705_o = f;
      10'b0000100000: n1705_o = 8'b00000001;
      10'b0000010000: n1705_o = n1681_o;
      10'b0000001000: n1705_o = n1678_o;
      10'b0000000100: n1705_o = di_reg;
      10'b0000000010: n1705_o = n1658_o;
      10'b0000000001: n1705_o = acc;
      default: n1705_o = 8'bX;
    endcase
  /* T80.vhd:1120:33  */
  assign n1707_o = set_busa_to == 4'b0111;
  /* T80.vhd:1123:55  */
  assign n1708_o = set_busa_to[0];
  /* T80.vhd:1124:64  */
  assign n1709_o = regbusa[7:0];
  /* T80.vhd:1126:64  */
  assign n1710_o = regbusa[15:8];
  /* T80.vhd:1123:41  */
  assign n1711_o = n1708_o ? n1709_o : n1710_o;
  /* T80.vhd:1122:33  */
  assign n1713_o = set_busa_to == 4'b0000;
  /* T80.vhd:1122:45  */
  assign n1715_o = set_busa_to == 4'b0001;
  /* T80.vhd:1122:45  */
  assign n1716_o = n1713_o | n1715_o;
  /* T80.vhd:1122:54  */
  assign n1718_o = set_busa_to == 4'b0010;
  /* T80.vhd:1122:54  */
  assign n1719_o = n1716_o | n1718_o;
  /* T80.vhd:1122:63  */
  assign n1721_o = set_busa_to == 4'b0011;
  /* T80.vhd:1122:63  */
  assign n1722_o = n1719_o | n1721_o;
  /* T80.vhd:1122:72  */
  assign n1724_o = set_busa_to == 4'b0100;
  /* T80.vhd:1122:72  */
  assign n1725_o = n1722_o | n1724_o;
  /* T80.vhd:1122:81  */
  assign n1727_o = set_busa_to == 4'b0101;
  /* T80.vhd:1122:81  */
  assign n1728_o = n1725_o | n1727_o;
  /* T80.vhd:1128:33  */
  assign n1730_o = set_busa_to == 4'b0110;
  /* T80.vhd:1131:68  */
  assign n1731_o = sp[7:0];
  /* T80.vhd:1130:33  */
  assign n1733_o = set_busa_to == 4'b1000;
  /* T80.vhd:1133:68  */
  assign n1734_o = sp[15:8];
  /* T80.vhd:1132:33  */
  assign n1736_o = set_busa_to == 4'b1001;
  /* T80.vhd:1134:33  */
  assign n1738_o = set_busa_to == 4'b1010;
  assign n1739_o = {n1738_o, n1736_o, n1733_o, n1730_o, n1728_o, n1707_o};
  /* T80.vhd:1119:33  */
  always @*
    case (n1739_o)
      6'b100000: n1742_o = 8'b00000000;
      6'b010000: n1742_o = n1734_o;
      6'b001000: n1742_o = n1731_o;
      6'b000100: n1742_o = di_reg;
      6'b000010: n1742_o = n1711_o;
      6'b000001: n1742_o = acc;
      default: n1742_o = 8'bX;
    endcase
  /* T80.vhd:1139:33  */
  assign n1743_o = xybit_undoc ? di_reg : n1705_o;
  /* T80.vhd:1139:33  */
  assign n1744_o = xybit_undoc ? di_reg : n1742_o;
  /* T80.vhd:1154:28  */
  assign n1752_o = ~reset_n;
  /* T80.vhd:1157:35  */
  assign n1754_o = ~dirset;
  /* T80.vhd:1157:41  */
  assign n1755_o = cen & n1754_o;
  /* T80.vhd:1158:43  */
  assign n1757_o = mcycle == 3'b001;
  /* T80.vhd:1158:64  */
  assign n1759_o = tstate == 3'b010;
  /* T80.vhd:1158:69  */
  assign n1760_o = wait_n & n1759_o;
  /* T80.vhd:1158:97  */
  assign n1762_o = tstate == 3'b011;
  /* T80.vhd:1158:87  */
  assign n1763_o = n1760_o | n1762_o;
  /* T80.vhd:1158:51  */
  assign n1764_o = n1763_o & n1757_o;
  /* T80.vhd:1158:33  */
  assign n1767_o = n1764_o ? 1'b0 : 1'b1;
  /* T80.vhd:1170:19  */
  assign n1773_o = ~halt_ff;
  /* T80.vhd:1171:20  */
  assign n1774_o = ~busack;
  /* T80.vhd:1172:23  */
  assign n1775_o = ~intcycle;
  /* T80.vhd:1183:26  */
  always @*
    n1776_oldnmi_n = n2072_q; // (isignal)
  initial
    n1776_oldnmi_n = 1'bX;
  /* T80.vhd:1185:28  */
  assign n1779_o = ~reset_n;
  /* T80.vhd:1204:48  */
  assign n1781_o = dir[211];
  /* T80.vhd:1205:48  */
  assign n1782_o = dir[210];
  /* T80.vhd:1207:42  */
  assign n1783_o = ~nmi_n;
  /* T80.vhd:1207:48  */
  assign n1784_o = n1776_oldnmi_n & n1783_o;
  /* T80.vhd:1207:33  */
  assign n1786_o = n1784_o ? 1'b1 : nmi_s;
  /* T80.vhd:1213:53  */
  assign n1787_o = ~busrq_n;
  /* T80.vhd:1219:75  */
  assign n1788_o = auto_wait | iorq_i;
  /* T80.vhd:1215:41  */
  assign n1790_o = t_res ? 1'b0 : n1788_o;
  /* T80.vhd:1215:41  */
  assign n1792_o = t_res ? 1'b0 : auto_wait_t1;
  /* T80.vhd:1221:68  */
  assign n1793_o = ir[4];
  /* T80.vhd:1221:62  */
  assign n1794_o = ~n1793_o;
  /* T80.vhd:1221:80  */
  assign n1795_o = f[2];
  /* T80.vhd:1221:75  */
  assign n1796_o = ~n1795_o;
  /* T80.vhd:1221:72  */
  assign n1797_o = n1794_o | n1796_o;
  /* T80.vhd:1221:57  */
  assign n1798_o = i_bt & n1797_o;
  /* T80.vhd:1222:74  */
  assign n1799_o = ir[4];
  /* T80.vhd:1222:68  */
  assign n1800_o = ~n1799_o;
  /* T80.vhd:1222:82  */
  assign n1801_o = f[6];
  /* T80.vhd:1222:78  */
  assign n1802_o = n1800_o | n1801_o;
  /* T80.vhd:1222:99  */
  assign n1803_o = f[2];
  /* T80.vhd:1222:94  */
  assign n1804_o = ~n1803_o;
  /* T80.vhd:1222:91  */
  assign n1805_o = n1802_o | n1804_o;
  /* T80.vhd:1222:63  */
  assign n1806_o = i_bc & n1805_o;
  /* T80.vhd:1221:91  */
  assign n1807_o = n1798_o | n1806_o;
  /* T80.vhd:1223:75  */
  assign n1808_o = ir[4];
  /* T80.vhd:1223:69  */
  assign n1809_o = ~n1808_o;
  /* T80.vhd:1223:83  */
  assign n1810_o = f[6];
  /* T80.vhd:1223:79  */
  assign n1811_o = n1809_o | n1810_o;
  /* T80.vhd:1223:64  */
  assign n1812_o = i_btr & n1811_o;
  /* T80.vhd:1222:110  */
  assign n1813_o = n1807_o | n1812_o;
  /* T80.vhd:1224:51  */
  assign n1815_o = tstate == 3'b010;
  /* T80.vhd:1225:49  */
  assign n1817_o = setei ? 1'b1 : inte_ff1;
  /* T80.vhd:1224:41  */
  assign n1819_o = n1822_o ? 1'b1 : inte_ff2;
  /* T80.vhd:1229:49  */
  assign n1820_o = i_retn ? inte_ff2 : n1817_o;
  /* T80.vhd:1224:41  */
  assign n1821_o = n1815_o ? n1820_o : inte_ff1;
  /* T80.vhd:1224:41  */
  assign n1822_o = n1815_o & setei;
  /* T80.vhd:1233:51  */
  assign n1824_o = tstate == 3'b011;
  /* T80.vhd:1233:41  */
  assign n1826_o = n1829_o ? 1'b0 : n1821_o;
  /* T80.vhd:1233:41  */
  assign n1828_o = n1830_o ? 1'b0 : n1819_o;
  /* T80.vhd:1233:41  */
  assign n1829_o = n1824_o & setdi;
  /* T80.vhd:1233:41  */
  assign n1830_o = n1824_o & setdi;
  /* T80.vhd:1239:59  */
  assign n1831_o = intcycle | nmicycle;
  /* T80.vhd:1239:41  */
  assign n1833_o = n1831_o ? 1'b0 : halt_ff;
  /* T80.vhd:1242:51  */
  assign n1835_o = mcycle == 3'b001;
  /* T80.vhd:1242:70  */
  assign n1837_o = tstate == 3'b010;
  /* T80.vhd:1242:59  */
  assign n1838_o = n1837_o & n1835_o;
  /* T80.vhd:1242:74  */
  assign n1839_o = wait_n & n1838_o;
  /* T80.vhd:1242:41  */
  assign n1841_o = n1839_o ? 1'b1 : n2134_q;
  /* T80.vhd:1245:65  */
  assign n1842_o = busack & busreq_s;
  /* T80.vhd:1245:44  */
  assign n1843_o = ~n1842_o;
  /* T80.vhd:1247:59  */
  assign n1845_o = tstate == 3'b010;
  /* T80.vhd:1247:74  */
  assign n1846_o = ~wait_n;
  /* T80.vhd:1247:63  */
  assign n1847_o = n1846_o & n1845_o;
  /* T80.vhd:1248:49  */
  assign n1849_o = n1956_o ? 1'b1 : n1833_o;
  /* T80.vhd:1259:79  */
  assign n1851_o = ir == 8'b00110110;
  /* T80.vhd:1259:92  */
  assign n1853_o = 1'b1 & n1851_o;
  /* T80.vhd:1259:73  */
  assign n1855_o = n1853_o ? 3'b010 : mcycle;
  /* T80.vhd:1262:79  */
  assign n1857_o = mcycle == 3'b111;
  /* T80.vhd:1262:88  */
  assign n1861_o = n1857_o | 1'b0;
  /* T80.vhd:1263:121  */
  assign n1863_o = pre_xy_f_m + 3'b001;
  /* T80.vhd:1264:79  */
  assign n1864_o = mcycle == mcycles;
  /* T80.vhd:1264:90  */
  assign n1865_o = n1864_o | no_btr;
  /* T80.vhd:1264:117  */
  assign n1867_o = mcycle == 3'b010;
  /* T80.vhd:1264:125  */
  assign n1868_o = i_djnz & n1867_o;
  /* T80.vhd:1264:142  */
  assign n1869_o = incdecz & n1868_o;
  /* T80.vhd:1264:106  */
  assign n1870_o = n1865_o | n1869_o;
  /* T80.vhd:1269:99  */
  assign n1872_o = prefix == 2'b00;
  /* T80.vhd:1269:88  */
  assign n1873_o = n1872_o & nmi_s;
  /* T80.vhd:1273:103  */
  assign n1874_o = ~int_n;
  /* T80.vhd:1273:94  */
  assign n1875_o = n1874_o & inte_ff1;
  /* T80.vhd:1273:119  */
  assign n1877_o = prefix == 2'b00;
  /* T80.vhd:1273:108  */
  assign n1878_o = n1877_o & n1875_o;
  /* T80.vhd:1273:136  */
  assign n1879_o = ~setei;
  /* T80.vhd:1273:126  */
  assign n1880_o = n1879_o & n1878_o;
  /* T80.vhd:1273:73  */
  assign n1882_o = n1880_o ? 1'b0 : n1826_o;
  /* T80.vhd:1273:73  */
  assign n1884_o = n1880_o ? 1'b0 : n1828_o;
  /* T80.vhd:1273:73  */
  assign n1887_o = n1880_o ? 1'b1 : 1'b0;
  /* T80.vhd:1269:73  */
  assign n1889_o = n1873_o ? 1'b0 : n1882_o;
  /* T80.vhd:1269:73  */
  assign n1890_o = n1873_o ? n1828_o : n1884_o;
  /* T80.vhd:1264:65  */
  assign n1892_o = n1908_o ? 1'b0 : n1786_o;
  /* T80.vhd:1269:73  */
  assign n1894_o = n1873_o ? 1'b0 : n1887_o;
  /* T80.vhd:1269:73  */
  assign n1898_o = n1873_o ? 1'b1 : 1'b0;
  /* T80.vhd:1279:117  */
  assign n1901_o = mcycle + 3'b001;
  /* T80.vhd:1264:65  */
  assign n1903_o = n1870_o ? 1'b0 : n1841_o;
  /* T80.vhd:1264:65  */
  assign n1905_o = n1870_o ? 3'b001 : n1901_o;
  /* T80.vhd:1264:65  */
  assign n1906_o = n1870_o ? n1889_o : n1826_o;
  /* T80.vhd:1264:65  */
  assign n1907_o = n1870_o ? n1890_o : n1828_o;
  /* T80.vhd:1264:65  */
  assign n1908_o = n1870_o & n1873_o;
  /* T80.vhd:1264:65  */
  assign n1909_o = n1870_o ? n1894_o : intcycle;
  /* T80.vhd:1264:65  */
  assign n1910_o = n1870_o ? n1898_o : nmicycle;
  /* T80.vhd:1262:65  */
  assign n1911_o = n1861_o ? n1841_o : n1903_o;
  /* T80.vhd:1262:65  */
  assign n1912_o = n1861_o ? n1863_o : n1905_o;
  /* T80.vhd:1262:65  */
  assign n1913_o = n1861_o ? n1826_o : n1906_o;
  /* T80.vhd:1262:65  */
  assign n1914_o = n1861_o ? n1828_o : n1907_o;
  /* T80.vhd:1262:65  */
  assign n1915_o = n1861_o ? n1786_o : n1892_o;
  /* T80.vhd:1262:65  */
  assign n1916_o = n1861_o ? intcycle : n1909_o;
  /* T80.vhd:1262:65  */
  assign n1917_o = n1861_o ? nmicycle : n1910_o;
  /* T80.vhd:1256:65  */
  assign n1918_o = nextis_xy_fetch ? n1841_o : n1911_o;
  /* T80.vhd:1256:65  */
  assign n1920_o = nextis_xy_fetch ? 3'b110 : n1912_o;
  /* T80.vhd:1256:65  */
  assign n1921_o = nextis_xy_fetch ? n1826_o : n1913_o;
  /* T80.vhd:1256:65  */
  assign n1922_o = nextis_xy_fetch ? n1828_o : n1914_o;
  /* T80.vhd:1256:65  */
  assign n1923_o = nextis_xy_fetch ? n1786_o : n1915_o;
  /* T80.vhd:1256:65  */
  assign n1924_o = nextis_xy_fetch ? n1855_o : pre_xy_f_m;
  /* T80.vhd:1256:65  */
  assign n1925_o = nextis_xy_fetch ? intcycle : n1916_o;
  /* T80.vhd:1256:65  */
  assign n1926_o = nextis_xy_fetch ? nmicycle : n1917_o;
  /* T80.vhd:1252:57  */
  assign n1927_o = busreq_s ? n1841_o : n1918_o;
  /* T80.vhd:1252:57  */
  assign n1929_o = busreq_s ? tstate : 3'b001;
  /* T80.vhd:1252:57  */
  assign n1930_o = busreq_s ? mcycle : n1920_o;
  /* T80.vhd:1252:57  */
  assign n1931_o = busreq_s ? n1826_o : n1921_o;
  /* T80.vhd:1252:57  */
  assign n1932_o = busreq_s ? n1828_o : n1922_o;
  /* T80.vhd:1252:57  */
  assign n1935_o = busreq_s ? 1'b1 : 1'b0;
  /* T80.vhd:1252:57  */
  assign n1936_o = busreq_s ? n1786_o : n1923_o;
  /* T80.vhd:1252:57  */
  assign n1937_o = busreq_s ? pre_xy_f_m : n1924_o;
  /* T80.vhd:1252:57  */
  assign n1938_o = busreq_s ? intcycle : n1925_o;
  /* T80.vhd:1252:57  */
  assign n1939_o = busreq_s ? nmicycle : n1926_o;
  /* T80.vhd:1283:94  */
  assign n1940_o = ~auto_wait_t2;
  /* T80.vhd:1283:77  */
  assign n1941_o = n1940_o & auto_wait;
  /* T80.vhd:1284:77  */
  assign n1943_o = iorq_i & 1'b1;
  /* T80.vhd:1284:111  */
  assign n1944_o = ~auto_wait_t1;
  /* T80.vhd:1284:94  */
  assign n1945_o = n1944_o & n1943_o;
  /* T80.vhd:1283:101  */
  assign n1946_o = n1941_o | n1945_o;
  /* T80.vhd:1283:101  */
  assign n1947_o = ~n1946_o;
  /* T80.vhd:1285:82  */
  assign n1949_o = tstate + 3'b001;
  /* T80.vhd:1283:57  */
  assign n1950_o = n1947_o ? n1949_o : tstate;
  /* T80.vhd:1248:49  */
  assign n1951_o = t_res ? n1927_o : n1841_o;
  /* T80.vhd:1248:49  */
  assign n1952_o = t_res ? n1929_o : n1950_o;
  /* T80.vhd:1248:49  */
  assign n1953_o = t_res ? n1930_o : mcycle;
  /* T80.vhd:1248:49  */
  assign n1954_o = t_res ? n1931_o : n1826_o;
  /* T80.vhd:1248:49  */
  assign n1955_o = t_res ? n1932_o : n1828_o;
  /* T80.vhd:1248:49  */
  assign n1956_o = t_res & halt;
  /* T80.vhd:1248:49  */
  assign n1958_o = t_res ? n1935_o : 1'b0;
  /* T80.vhd:1248:49  */
  assign n1959_o = t_res ? n1936_o : n1786_o;
  /* T80.vhd:1248:49  */
  assign n1960_o = t_res ? n1937_o : pre_xy_f_m;
  /* T80.vhd:1248:49  */
  assign n1961_o = t_res ? n1938_o : intcycle;
  /* T80.vhd:1248:49  */
  assign n1962_o = t_res ? n1939_o : nmicycle;
  /* T80.vhd:1247:49  */
  assign n1963_o = n1847_o ? n1841_o : n1951_o;
  /* T80.vhd:1247:49  */
  assign n1964_o = n1847_o ? tstate : n1952_o;
  /* T80.vhd:1247:49  */
  assign n1965_o = n1847_o ? mcycle : n1953_o;
  /* T80.vhd:1247:49  */
  assign n1966_o = n1847_o ? n1826_o : n1954_o;
  /* T80.vhd:1247:49  */
  assign n1967_o = n1847_o ? n1828_o : n1955_o;
  /* T80.vhd:1247:49  */
  assign n1968_o = n1847_o ? n1833_o : n1849_o;
  /* T80.vhd:1247:49  */
  assign n1970_o = n1847_o ? 1'b0 : n1958_o;
  /* T80.vhd:1247:49  */
  assign n1972_o = n1847_o ? n1786_o : n1959_o;
  /* T80.vhd:1247:49  */
  assign n1973_o = n1847_o ? pre_xy_f_m : n1960_o;
  /* T80.vhd:1247:49  */
  assign n1974_o = n1847_o ? intcycle : n1961_o;
  /* T80.vhd:1247:49  */
  assign n1975_o = n1847_o ? nmicycle : n1962_o;
  /* T80.vhd:1245:41  */
  assign n1976_o = n1843_o ? n1963_o : n1841_o;
  /* T80.vhd:1212:33  */
  assign n1977_o = n1992_o ? n1964_o : tstate;
  /* T80.vhd:1212:33  */
  assign n1978_o = n1993_o ? n1965_o : mcycle;
  /* T80.vhd:1245:41  */
  assign n1979_o = n1843_o ? n1966_o : n1826_o;
  /* T80.vhd:1245:41  */
  assign n1980_o = n1843_o ? n1967_o : n1828_o;
  /* T80.vhd:1245:41  */
  assign n1981_o = n1843_o ? n1968_o : n1833_o;
  /* T80.vhd:1212:33  */
  assign n1982_o = n1998_o ? n1970_o : busack;
  /* T80.vhd:1212:33  */
  assign n1983_o = n1999_o ? n1972_o : n1786_o;
  /* T80.vhd:1212:33  */
  assign n1984_o = n2000_o ? n1973_o : pre_xy_f_m;
  /* T80.vhd:1212:33  */
  assign n1985_o = n2004_o ? n1974_o : intcycle;
  /* T80.vhd:1212:33  */
  assign n1986_o = n2005_o ? n1975_o : nmicycle;
  /* T80.vhd:1289:51  */
  assign n1988_o = tstate == 3'b000;
  /* T80.vhd:1289:41  */
  assign n1990_o = n1988_o ? 1'b0 : n1976_o;
  /* T80.vhd:1212:33  */
  assign n1991_o = cen ? n1990_o : n2134_q;
  /* T80.vhd:1212:33  */
  assign n1992_o = cen & n1843_o;
  /* T80.vhd:1212:33  */
  assign n1993_o = cen & n1843_o;
  /* T80.vhd:1212:33  */
  assign n1994_o = cen ? n1979_o : inte_ff1;
  /* T80.vhd:1212:33  */
  assign n1995_o = cen ? n1980_o : inte_ff2;
  /* T80.vhd:1212:33  */
  assign n1996_o = cen ? n1981_o : halt_ff;
  /* T80.vhd:1212:33  */
  assign n1997_o = cen ? n1787_o : busreq_s;
  /* T80.vhd:1212:33  */
  assign n1998_o = cen & n1843_o;
  /* T80.vhd:1212:33  */
  assign n1999_o = cen & n1843_o;
  /* T80.vhd:1212:33  */
  assign n2000_o = cen & n1843_o;
  /* T80.vhd:1212:33  */
  assign n2001_o = cen ? n1813_o : no_btr;
  /* T80.vhd:1212:33  */
  assign n2002_o = cen ? n1790_o : auto_wait_t1;
  /* T80.vhd:1212:33  */
  assign n2003_o = cen ? n1792_o : auto_wait_t2;
  /* T80.vhd:1212:33  */
  assign n2004_o = cen & n1843_o;
  /* T80.vhd:1212:33  */
  assign n2005_o = cen & n1843_o;
  /* T80.vhd:1203:25  */
  assign n2006_o = dirset ? n2134_q : n1991_o;
  /* T80.vhd:1203:25  */
  assign n2007_o = dirset ? tstate : n1977_o;
  /* T80.vhd:1203:25  */
  assign n2008_o = dirset ? mcycle : n1978_o;
  /* T80.vhd:1203:25  */
  assign n2009_o = dirset ? n1782_o : n1994_o;
  /* T80.vhd:1203:25  */
  assign n2010_o = dirset ? n1781_o : n1995_o;
  /* T80.vhd:1203:25  */
  assign n2011_o = dirset ? halt_ff : n1996_o;
  /* T80.vhd:1203:25  */
  assign n2012_o = dirset ? busreq_s : n1997_o;
  /* T80.vhd:1203:25  */
  assign n2013_o = dirset ? busack : n1982_o;
  /* T80.vhd:1203:25  */
  assign n2014_o = dirset ? nmi_s : n1983_o;
  /* T80.vhd:1203:25  */
  assign n2015_o = dirset ? pre_xy_f_m : n1984_o;
  /* T80.vhd:1203:25  */
  assign n2016_o = dirset ? no_btr : n2001_o;
  /* T80.vhd:1203:25  */
  assign n2017_o = dirset ? auto_wait_t1 : n2002_o;
  /* T80.vhd:1203:25  */
  assign n2018_o = dirset ? auto_wait_t2 : n2003_o;
  /* T80.vhd:1203:25  */
  assign n2019_o = dirset ? intcycle : n1985_o;
  /* T80.vhd:1203:25  */
  assign n2020_o = dirset ? nmicycle : n1986_o;
  /* T80.vhd:1203:25  */
  assign n2021_o = dirset ? n1776_oldnmi_n : nmi_n;
  /* T80.vhd:1182:9  */
  assign n2070_o = ~n1779_o;
  /* T80.vhd:1201:17  */
  assign n2071_o = n2070_o ? n2021_o : n1776_oldnmi_n;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n)
    n2072_q <= n2071_o;
  /* T80.vhd:1297:57  */
  assign n2075_o = mcycle == 3'b001;
  /* T80.vhd:1297:46  */
  assign n2076_o = n2075_o & intcycle;
  /* T80.vhd:1297:26  */
  assign n2077_o = n2076_o ? 1'b1 : 1'b0;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2079_q <= 8'b11111111;
    else
      n2079_q <= n1257_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2080_q <= 8'b11111111;
    else
      n2080_q <= n1258_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2081_q <= 8'b11111111;
    else
      n2081_q <= n1259_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2082_q <= 8'b11111111;
    else
      n2082_q <= n1260_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2083_q <= 8'b00000000;
    else
      n2083_q <= n1261_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2084_q <= 8'b00000000;
    else
      n2084_q <= n1262_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2085_q <= 16'b1111111111111111;
    else
      n2085_q <= n1263_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2086_q <= 16'b0000000000000000;
    else
      n2086_q <= n1264_o;
  /* T80.vhd:499:17  */
  assign n2087_o = {u_regs_n1628, u_regs_n1629};
  /* T80.vhd:499:17  */
  assign n2088_o = {u_regs_n1630, u_regs_n1631};
  /* T80.vhd:499:17  */
  assign n2089_o = {u_regs_n1632, u_regs_n1633};
  /* T80.vhd:944:17  */
  assign n2090_o = clken ? n1388_o : regaddra_r;
  /* T80.vhd:944:17  */
  always @(posedge clk_n)
    n2091_q <= n2090_o;
  /* T80.vhd:944:17  */
  assign n2092_o = clken ? n1402_o : regaddrb_r;
  /* T80.vhd:944:17  */
  always @(posedge clk_n)
    n2093_q <= n2092_o;
  /* T80.vhd:944:17  */
  assign n2094_o = clken ? n1419_o : regaddrc;
  /* T80.vhd:944:17  */
  always @(posedge clk_n)
    n2095_q <= n2094_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2096_q <= 1'b0;
    else
      n2096_q <= n1265_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2097_q <= 16'b0000000000000000;
    else
      n2097_q <= n1266_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2098_q <= 8'b00000000;
    else
      n2098_q <= n1267_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2099_q <= 2'b00;
    else
      n2099_q <= n1268_o;
  /* T80.vhd:944:17  */
  assign n2100_o = clken ? regbusa : regbusa_r;
  /* T80.vhd:944:17  */
  always @(posedge clk_n)
    n2101_q <= n2100_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2102_q <= 3'b000;
    else
      n2102_q <= n2007_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2103_q <= 3'b001;
    else
      n2103_q <= n2008_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2104_q <= 1'b0;
    else
      n2104_q <= n2009_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2105_q <= 1'b0;
    else
      n2105_q <= n2010_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2106_q <= 1'b0;
    else
      n2106_q <= n2011_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2107_q <= 1'b0;
    else
      n2107_q <= n2012_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2108_q <= 1'b0;
    else
      n2108_q <= n2013_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2109_q <= 1'b0;
    else
      n2109_q <= n2014_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2110_q <= 2'b00;
    else
      n2110_q <= n1269_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2111_q <= 2'b00;
    else
      n2111_q <= n1270_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2112_q <= 3'b000;
    else
      n2112_q <= n2015_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2113_q <= 1'b0;
    else
      n2113_q <= n1271_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2114_q <= 1'b0;
    else
      n2114_q <= n2016_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2115_q <= 1'b0;
    else
      n2115_q <= n1272_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2116_q <= 1'b0;
    else
      n2116_q <= n2017_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2117_q <= 1'b0;
    else
      n2117_q <= n2018_o;
  /* T80.vhd:944:17  */
  assign n2118_o = clken ? n1442_o : incdecz;
  /* T80.vhd:944:17  */
  always @(posedge clk_n)
    n2119_q <= n2118_o;
  /* T80.vhd:1084:17  */
  assign n2120_o = clken ? n1743_o : busb;
  /* T80.vhd:1084:17  */
  always @(posedge clk_n)
    n2121_q <= n2120_o;
  /* T80.vhd:1084:17  */
  assign n2122_o = clken ? n1744_o : busa;
  /* T80.vhd:1084:17  */
  always @(posedge clk_n)
    n2123_q <= n2122_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2124_q <= 5'b00000;
    else
      n2124_q <= n1273_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2125_q <= 1'b0;
    else
      n2125_q <= n1274_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2126_q <= 1'b0;
    else
      n2126_q <= n1275_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2127_q <= 4'b0000;
    else
      n2127_q <= n1276_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2128_q <= 1'b0;
    else
      n2128_q <= n1277_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2129_q <= 1'b0;
    else
      n2129_q <= n1278_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2130_q <= 3'b000;
    else
      n2130_q <= n1279_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2131_q <= 1'b0;
    else
      n2131_q <= n2019_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2132_q <= 1'b0;
    else
      n2132_q <= n2020_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2133_q <= 1'b0;
    else
      n2133_q <= n1280_o;
  /* T80.vhd:1201:17  */
  always @(posedge clk_n or posedge n1779_o)
    if (n1779_o)
      n2134_q <= 1'b1;
    else
      n2134_q <= n2006_o;
  /* T80.vhd:1156:17  */
  assign n2135_o = n1755_o ? n1767_o : n2136_q;
  /* T80.vhd:1156:17  */
  always @(posedge clk_n or posedge n1752_o)
    if (n1752_o)
      n2136_q <= 1'b1;
    else
      n2136_q <= n2135_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2137_q <= 16'b0000000000000000;
    else
      n2137_q <= n1255_o;
  /* T80.vhd:529:17  */
  always @(posedge clk_n or posedge n388_o)
    if (n388_o)
      n2138_q <= 8'b00000000;
    else
      n2138_q <= n1256_o;
endmodule

module T80s
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
  t80_0_1_0_1_2_3_4_5_6_7 u0 (
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

