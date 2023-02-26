/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 16-6-2021 */

module jts16_fd1094_dec(
    input             rst,
    input             clk,

    // Key access
    output reg [12:0] key_addr,
    input      [ 7:0] key_data,

    // Configuration
    input      [12:0] prog_addr,
    input             fd1094_we,
    input      [ 7:0] prog_data,

    // Operation
    input             dec_en,
    input             vrq,      // vector request
    input      [ 7:0] st,       // state
    output reg [ 7:0] gkey0,    // used as state during interrupts

    input             op_n,     // OP (0) or data (1)
    input      [23:1] addr,
    input      [15:0] enc,
    output     [15:0] dec,

    input             rom_ok,
    output reg        ok_dly
);

`define BITSWAP( v, b15, b14, b13, b12, b11, b10, b9, b8, b7, b6, b5, b4, b3, b2, b1, b0 ) { \
    v[b15], v[b14], v[b13], v[b12], v[b11], v[b10], v[b9], v[b8], \
    v[b7],  v[b6],  v[b5],  v[b4],  v[b3],  v[b2],  v[b1], v[b0] }

reg [7:0] gkey1, gkey2, gkey3;
reg [7:0] gkey1_st, gkey2_st, gkey3_st;

wire [ 7:0] xor_mask1, xor_mask2, xor_mask3;
reg         key_F, mask_en;
reg  [15:0] val, masked;

// only decode if dec_en is high and it is an OP code
assign dec = (dec_en & ~op_n) ? masked : enc;

assign xor_mask1 = { st[2], st[4], st[3], st[6],
                     st[5], st[0], st[4], st[1]};

assign xor_mask2 = { st[0], st[2], st[6], st[1],
                     st[4], st[6], st[3], st[7]};

assign xor_mask3 = { st[0], st[7], st[3], st[5],
                     st[5], st[2], st[7], st[1]};

wire global_xor0         = ~gkey1_st[5];
wire global_xor1         = ~gkey1_st[2];
wire global_swap2        = ~gkey1_st[0];

wire global_swap0a       = ~gkey2_st[5];
wire global_swap0b       = ~gkey2_st[2];

wire global_swap3        = ~gkey3_st[6];
wire global_swap1        = ~gkey3_st[4];
wire global_swap4        = ~gkey3_st[2];

wire key_0a = key_data[0] ^ gkey3_st[1];
wire key_0b = key_data[0] ^ gkey1_st[7];
wire key_0c = key_data[0] ^ gkey1_st[1];

wire key_1a = key_data[1] ^ gkey2_st[7];
wire key_1b = key_data[1] ^ gkey1_st[3];

wire key_2a = key_data[2] ^ gkey3_st[7];
wire key_2b = key_data[2] ^ gkey1_st[4];

wire key_3a = key_data[3] ^ gkey2_st[0];
wire key_3b = key_data[3] ^ gkey3_st[3];

wire key_4a = key_data[4] ^ gkey2_st[3];
wire key_4b = key_data[4] ^ gkey3_st[0];

wire key_5a = key_data[5] ^ gkey3_st[5];
wire key_5b = key_data[5] ^ gkey1_st[6];

wire key_6a = key_data[6] ^ gkey2_st[1];
wire key_6b = key_data[6] ^ gkey2_st[6];

wire key_7a = key_data[7] ^ gkey2_st[4];

always @(posedge clk) begin
    if( fd1094_we && prog_addr<4 ) begin
        case( prog_addr[1:0] )
            0: gkey0 <= prog_data;
            1: gkey1 <= prog_data;
            2: gkey2 <= prog_data;
            3: gkey3 <= prog_data;
        endcase
        // $display("global key %d = %X",prog_addr, prog_data);
    end
end

always @(*) begin
    key_addr = addr[13:1];
    if ((addr[16:1] & 16'h0ffc) == 0 && addr >= 4)
        key_addr[12] = 1;
    key_F = addr[13] ? key_data[7] : key_data[6];

    gkey1_st = gkey1 ^ xor_mask1;
    gkey2_st = gkey2 ^ xor_mask2;
    gkey3_st = gkey3 ^ xor_mask3;

    if( vrq ) begin
        if( addr <= 3 ) gkey3_st = 0;
        if( addr <= 2 ) gkey2_st = 0;
        if( addr <= 1 ) gkey1_st = 0;
        if( addr <= 1 ) key_F = 0;
    end
end

// `ifdef SIMULATION
// always @(key_data) begin
//     $display("key_data = %X",key_data);
// end
// `endif

// decoding, pretty much copy-paste from MAME's fd1094.cpp
// I trust the synthesizer to simplify the equations
always @(*) begin
    val=enc;
    if (val[15] ) begin
        val = `BITSWAP(val, 15, 9,10,13, 3,12, 0,14, 6, 5, 2,11, 8, 1, 4, 7);

        if (!global_xor1)   if (~val[11] /*& 16'h0800*/)  val = val ^ 16'h3002;                                      // 1,12,13
                            if (~val[ 5] /*& 16'h0020*/)  val = val ^ 16'h0044;                                      // 2,6
        if (!key_1b)        if (~val[10] /*& 16'h0400*/)  val = val ^ 16'h0890;                                      // 4,7,11
        if (!global_swap2)  if (!key_0c)        val = val ^ 16'h0308;                                      // 3,8,9
                                                val = val ^ 16'h6561;

        if (!key_2b)        val = `BITSWAP(val,15,10,13,12,11,14,9,8,7,6,0,4,3,2,1,5);             // 0-5, 10-14
    end
    //$display("Check point 0: %X (%d,%d,%d,%d)",val, global_xor1, key_1b, global_swap2, key_2b);
    if (val[14] ) begin
        val = `BITSWAP(val, 13,14, 7, 0, 8, 6, 4, 2, 1,15, 3,11,12,10, 5, 9);

        if (!global_xor0)   if (val[4] /*& 16'h0010*/)   val = val ^ 16'h0468;                                      // 3,5,6,10
        if (!key_3a)        if (val[8] /*& 16'h0100*/)   val = val ^ 16'h0081;                                      // 0,7
        if (!key_6a)        if (val[2] /*& 16'h0004*/)   val = val ^ 16'h0100;                                      // 8
        if (!key_5b)        if (!key_0b)        val = val ^ 16'h3012;                                      // 1,4,12,13
                                                val = val ^ 16'h3523;

        if (!global_swap0b) val = `BITSWAP(val, 2,14,13,12, 9,10,11, 8, 7, 6, 5, 4, 3,15, 1, 0);   // 2-15, 9-11
    end

    if (val[13] ) begin     // block invariant: val & 16'h2000 != 0
        val = `BITSWAP(val, 10, 2,13, 7, 8, 0, 3,14, 6,15, 1,11, 9, 4, 5,12);

        if (!key_4a)        if (val[11] /*& 16'h0800*/)   val = val ^ 16'h010c;                                      // 2,3,8
        if (!key_1a)        if (val[ 7] /*& 16'h0080*/)   val = val ^ 16'h1000;                                      // 12
        if (!key_7a)        if (val[10] /*& 16'h0400*/)   val = val ^ 16'h0a21;                                      // 0,5,9,11
        if (!key_4b)        if (!key_0a)        val = val ^ 16'h0080;                                      // 7
        if (!global_swap0a) if (!key_6b)        val = val ^ 16'hc000;                                      // 14,15
                                                val = val ^ 16'h99a5;

        if (!key_5b)        val = `BITSWAP(val,15,14,13,12,11, 1, 9, 8, 7,10, 5, 6, 3, 2, 4, 0);   // 1,4,6,10
    end

    if (val[15:13]!=0 ) begin
        val = `BITSWAP(val,15,13,14, 5, 6, 0, 9,10, 4,11, 1, 2,12, 3, 7, 8);

        val = val ^ 16'h17ff;

        if (!global_swap4)  val = `BITSWAP(val, 15,14,13, 6,11,10, 9, 5, 7,12, 8, 4, 3, 2, 1, 0);  // 5-8, 6-12
        if (!global_swap3)  val = `BITSWAP(val, 13,15,14,12,11,10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0);  // 15-14-13
        if (!global_swap2)  val = `BITSWAP(val, 15,14,13,12,11, 2, 9, 8,10, 6, 5, 4, 3, 0, 1, 7);  // 10-2-0-7
        if (!key_3b)        val = `BITSWAP(val, 15,14,13,12,11,10, 4, 8, 7, 6, 5, 9, 1, 2, 3, 0);  // 9-4, 3-1
        if (!key_2a)        val = `BITSWAP(val, 13,14,15,12,11,10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0);  // 13-15

        if (!global_swap1)  val = `BITSWAP(val, 15,14,13,12, 9, 8,11,10, 7, 6, 5, 4, 3, 2, 1, 0);  // 11...8
        if (!key_5a)        val = `BITSWAP(val, 15,14,13,12,11,10, 9, 8, 4, 5, 7, 6, 3, 2, 1, 0);  // 7...4
        if (!global_swap0a) val = `BITSWAP(val, 15,14,13,12,11,10, 9, 8, 7, 6, 5, 4, 0, 3, 2, 1);  // 3...0
    end

    val = `BITSWAP(val, 12,15,14,13,11,10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0);

    if ((val & 16'hb080) == 16'h8000) val = val ^ 16'h4000;
    if ((val & 16'hf000) == 16'hc000) val = val ^ 16'h0080;
    if ((val & 16'hb100) == 16'h0000) val = val ^ 16'h4000;
end

always @(posedge clk) begin
    if(rom_ok) masked <= mask_en ? 16'hffff : val;
    ok_dly <= rom_ok;
end

always @(val, key_F) begin
    case( { val[15:1], 1'b0} )
    16'h013a,16'h033a,16'h053a,16'h073a,16'h083a,16'h093a,16'h0b3a,16'h0d3a,16'h0f3a,

    16'h103a,       16'h10ba,16'h10fa,    16'h113a,16'h117a,16'h11ba,16'h11fa,
    16'h123a,       16'h12ba,16'h12fa,    16'h133a,16'h137a,16'h13ba,16'h13fa,
    16'h143a,       16'h14ba,16'h14fa,    16'h153a,16'h157a,16'h15ba,
    16'h163a,       16'h16ba,16'h16fa,    16'h173a,16'h177a,16'h17ba,
    16'h183a,       16'h18ba,16'h18fa,    16'h193a,16'h197a,16'h19ba,
    16'h1a3a,       16'h1aba,16'h1afa,    16'h1b3a,16'h1b7a,16'h1bba,
    16'h1c3a,       16'h1cba,16'h1cfa,    16'h1d3a,16'h1d7a,16'h1dba,
    16'h1e3a,       16'h1eba,16'h1efa,    16'h1f3a,16'h1f7a,16'h1fba,

    16'h203a,16'h207a,16'h20ba,16'h20fa,    16'h213a,16'h217a,16'h21ba,16'h21fa,
    16'h223a,16'h227a,16'h22ba,16'h22fa,    16'h233a,16'h237a,16'h23ba,16'h23fa,
    16'h243a,16'h247a,16'h24ba,16'h24fa,    16'h253a,16'h257a,16'h25ba,
    16'h263a,16'h267a,16'h26ba,16'h26fa,    16'h273a,16'h277a,16'h27ba,
    16'h283a,16'h287a,16'h28ba,16'h28fa,    16'h293a,16'h297a,16'h29ba,
    16'h2a3a,16'h2a7a,16'h2aba,16'h2afa,    16'h2b3a,16'h2b7a,16'h2bba,
    16'h2c3a,16'h2c7a,16'h2cba,16'h2cfa,    16'h2d3a,16'h2d7a,16'h2dba,
    16'h2e3a,16'h2e7a,16'h2eba,16'h2efa,    16'h2f3a,16'h2f7a,16'h2fba,

    16'h303a,16'h307a,16'h30ba,16'h30fa,    16'h313a,16'h317a,16'h31ba,16'h31fa,
    16'h323a,16'h327a,16'h32ba,16'h32fa,    16'h333a,16'h337a,16'h33ba,16'h33fa,
    16'h343a,16'h347a,16'h34ba,16'h34fa,    16'h353a,16'h357a,16'h35ba,
    16'h363a,16'h367a,16'h36ba,16'h36fa,    16'h373a,16'h377a,16'h37ba,
    16'h383a,16'h387a,16'h38ba,16'h38fa,    16'h393a,16'h397a,16'h39ba,
    16'h3a3a,16'h3a7a,16'h3aba,16'h3afa,    16'h3b3a,16'h3b7a,16'h3bba,
    16'h3c3a,16'h3c7a,16'h3cba,16'h3cfa,    16'h3d3a,16'h3d7a,16'h3dba,
    16'h3e3a,16'h3e7a,16'h3eba,16'h3efa,    16'h3f3a,16'h3f7a,16'h3fba,

    16'h41ba,16'h43ba,16'h44fa,16'h45ba,16'h46fa,16'h47ba,16'h49ba,16'h4bba,16'h4cba,16'h4cfa,16'h4dba,16'h4fba,

    16'h803a,16'h807a,16'h80ba,16'h80fa,    16'h81fa,
    16'h823a,16'h827a,16'h82ba,16'h82fa,    16'h83fa,
    16'h843a,16'h847a,16'h84ba,16'h84fa,    16'h85fa,
    16'h863a,16'h867a,16'h86ba,16'h86fa,    16'h87fa,
    16'h883a,16'h887a,16'h88ba,16'h88fa,    16'h89fa,
    16'h8a3a,16'h8a7a,16'h8aba,16'h8afa,    16'h8bfa,
    16'h8c3a,16'h8c7a,16'h8cba,16'h8cfa,    16'h8dfa,
    16'h8e3a,16'h8e7a,16'h8eba,16'h8efa,    16'h8ffa,

    16'h903a,16'h907a,16'h90ba,16'h90fa,    16'h91fa,
    16'h923a,16'h927a,16'h92ba,16'h92fa,    16'h93fa,
    16'h943a,16'h947a,16'h94ba,16'h94fa,    16'h95fa,
    16'h963a,16'h967a,16'h96ba,16'h96fa,    16'h97fa,
    16'h983a,16'h987a,16'h98ba,16'h98fa,    16'h99fa,
    16'h9a3a,16'h9a7a,16'h9aba,16'h9afa,    16'h9bfa,
    16'h9c3a,16'h9c7a,16'h9cba,16'h9cfa,    16'h9dfa,
    16'h9e3a,16'h9e7a,16'h9eba,16'h9efa,    16'h9ffa,

    16'hb03a,16'hb07a,16'hb0ba,16'hb0fa,    16'hb1fa,
    16'hb23a,16'hb27a,16'hb2ba,16'hb2fa,    16'hb3fa,
    16'hb43a,16'hb47a,16'hb4ba,16'hb4fa,    16'hb5fa,
    16'hb63a,16'hb67a,16'hb6ba,16'hb6fa,    16'hb7fa,
    16'hb83a,16'hb87a,16'hb8ba,16'hb8fa,    16'hb9fa,
    16'hba3a,16'hba7a,16'hbaba,16'hbafa,    16'hbbfa,
    16'hbc3a,16'hbc7a,16'hbcba,16'hbcfa,    16'hbdfa,
    16'hbe3a,16'hbe7a,16'hbeba,16'hbefa,    16'hbffa,

    16'hc03a,16'hc07a,16'hc0ba,16'hc0fa,    16'hc1fa,
    16'hc23a,16'hc27a,16'hc2ba,16'hc2fa,    16'hc3fa,
    16'hc43a,16'hc47a,16'hc4ba,16'hc4fa,    16'hc5fa,
    16'hc63a,16'hc67a,16'hc6ba,16'hc6fa,    16'hc7fa,
    16'hc83a,16'hc87a,16'hc8ba,16'hc8fa,    16'hc9fa,
    16'hca3a,16'hca7a,16'hcaba,16'hcafa,    16'hcbfa,
    16'hcc3a,16'hcc7a,16'hccba,16'hccfa,    16'hcdfa,
    16'hce3a,16'hce7a,16'hceba,16'hcefa,    16'hcffa,

    16'hd03a,16'hd07a,16'hd0ba,16'hd0fa,    16'hd1fa,
    16'hd23a,16'hd27a,16'hd2ba,16'hd2fa,    16'hd3fa,
    16'hd43a,16'hd47a,16'hd4ba,16'hd4fa,    16'hd5fa,
    16'hd63a,16'hd67a,16'hd6ba,16'hd6fa,    16'hd7fa,
    16'hd83a,16'hd87a,16'hd8ba,16'hd8fa,    16'hd9fa,
    16'hda3a,16'hda7a,16'hdaba,16'hdafa,    16'hdbfa,
    16'hdc3a,16'hdc7a,16'hdcba,16'hdcfa,    16'hddfa,
    16'hde3a,16'hde7a,16'hdeba,16'hdefa,    16'hdffa:
                 mask_en = 1;
        default: mask_en = 0;
    endcase
    if(key_F && (
           (val & 16'hff80) == 16'h4e80 ||
           (val & 16'hf0f8) == 16'h50c8 ||
            val[15:12] == 4'h6 ))
        mask_en = 1;
end

`undef BITSWAP

endmodule