// GHDL 4.1.0 output for T80_ALU.vhd from T80s synthesis with -gMode=2.
// Copyright (c) 2018 Sorgelig
//  Test passed: ZEXDOC, ZEXALL, Z80Full(*), Z80memptr
//  (*) Currently only SCF and CCF instructions aren't passed X/Y flags check as
//      correct implementation is still unclear.
//
// ****
// T80(b) core. In an effort to merge and maintain bug fixes ....
//
// Ver 301 parity flag is just parity for 8080, also overflow for Z80, by Sean Riddle
// Ver 300 started tidyup
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
module t80_8080_alu
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
