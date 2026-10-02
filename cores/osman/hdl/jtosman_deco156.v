/*  This file is part of JTCORES. GPLv3. See jtosman_game.v header.
    Author: Andrea Bogazzi.

    DE156 ARM ROM descramble (combinational, at fetch). Faithful RTL port of MAME
    dataeast/deco156_m.cpp decrypt() — the SAME static transform for every DE156
    game (nslasher/hvysmsh/simpl156...). For ARM word address `a`:
        dec = DataXform( raw[ AddrScramble(a) ], a )
      AddrScramble: within a 64K-word page (a[17:16] preserved), low 16 bits =
                    0x92c6 ^ (XOR masks selected by a[15:0]) — invertible bit-scramble,
                    so the raw ROM stays in load order in SDRAM, read at scramble(a).
      DataXform   : 16 two-bit XORs selected by a[2:17], then one of 4 BITSWAP32
                    patterns (+ XOR constant) chosen by a[1:0].
    Osman ROM = 512 KB = 128K 32-bit words (a[16:0]); a[17] is 0 (its terms vanish).
    Usage: drive `a` (ARM word addr), read SDRAM at `dec_addr`, feed `raw`, take `dec`.
*/
module jtosman_deco156(
    input      [17:0] a,         // ARM word address (a[16:0] used; a[17]=0 for 512 KB)
    output     [17:0] dec_addr,  // raw (SDRAM) word address to fetch
    input      [31:0] raw,       // raw ROM word read at dec_addr
    output     [31:0] dec        // decrypted word for address a
);
    // ---- address scramble (low 16 bits; page bits a[17:16] preserved) ----
    wire [15:0] lo = 16'h92c6
        ^ (a[ 0] ? 16'hce4a : 16'h0) ^ (a[ 1] ? 16'h4db2 : 16'h0)
        ^ (a[ 2] ? 16'hef60 : 16'h0) ^ (a[ 3] ? 16'h5737 : 16'h0)
        ^ (a[ 4] ? 16'h13dc : 16'h0) ^ (a[ 5] ? 16'h4bd9 : 16'h0)
        ^ (a[ 6] ? 16'ha209 : 16'h0) ^ (a[ 7] ? 16'hd996 : 16'h0)
        ^ (a[ 8] ? 16'ha700 : 16'h0) ^ (a[ 9] ? 16'heca0 : 16'h0)
        ^ (a[10] ? 16'h7529 : 16'h0) ^ (a[11] ? 16'h3100 : 16'h0)
        ^ (a[12] ? 16'h33b4 : 16'h0) ^ (a[13] ? 16'h6161 : 16'h0)
        ^ (a[14] ? 16'h1eef : 16'h0) ^ (a[15] ? 16'hf5a5 : 16'h0);
    assign dec_addr = { a[17:16], lo };

    // ---- data XORs (each toggles exactly two bits), selected by a[2:17] ----
    wire [31:0] d1 = raw
        ^ (a[ 2] ? 32'h04400000 : 32'h0) ^ (a[ 3] ? 32'h40000004 : 32'h0)
        ^ (a[ 4] ? 32'h00048000 : 32'h0) ^ (a[ 5] ? 32'h00000280 : 32'h0)
        ^ (a[ 6] ? 32'h00200040 : 32'h0) ^ (a[ 7] ? 32'h09000000 : 32'h0)
        ^ (a[ 8] ? 32'h00001100 : 32'h0) ^ (a[ 9] ? 32'h20002000 : 32'h0)
        ^ (a[10] ? 32'h00000022 : 32'h0) ^ (a[11] ? 32'h000a0000 : 32'h0)
        ^ (a[12] ? 32'h10004000 : 32'h0) ^ (a[13] ? 32'h00010400 : 32'h0)
        ^ (a[14] ? 32'h80000010 : 32'h0) ^ (a[15] ? 32'h00000009 : 32'h0)
        ^ (a[16] ? 32'h02100000 : 32'h0) ^ (a[17] ? 32'h00800800 : 32'h0);

    // ---- BITSWAP32: result MSB-first = v[arg0..arg31] (MAME BITSWAP32 order) ----
    function [31:0] bsw0; input [31:0] v; begin bsw0 = {
        v[ 1],v[ 4],v[ 7],v[28],v[22],v[18],v[20],v[ 9], v[16],v[10],v[30],v[ 2],v[31],v[24],v[19],v[29],
        v[ 6],v[21],v[23],v[11],v[12],v[13],v[ 5],v[ 0], v[ 8],v[26],v[27],v[15],v[14],v[17],v[25],v[ 3] };
    end endfunction
    function [31:0] bsw1; input [31:0] v; begin bsw1 = {
        v[14],v[23],v[28],v[29],v[ 6],v[24],v[10],v[ 1], v[ 5],v[16],v[ 7],v[ 2],v[30],v[ 8],v[18],v[ 3],
        v[31],v[22],v[25],v[20],v[17],v[ 0],v[19],v[27], v[ 9],v[12],v[21],v[15],v[26],v[13],v[ 4],v[11] };
    end endfunction
    function [31:0] bsw2; input [31:0] v; begin bsw2 = {
        v[19],v[30],v[21],v[ 4],v[ 2],v[18],v[15],v[ 1], v[12],v[25],v[ 8],v[ 0],v[24],v[20],v[17],v[23],
        v[22],v[26],v[28],v[16],v[ 9],v[27],v[ 6],v[11], v[31],v[10],v[ 3],v[13],v[14],v[ 7],v[29],v[ 5] };
    end endfunction
    function [31:0] bsw3; input [31:0] v; begin bsw3 = {
        v[30],v[ 6],v[15],v[ 0],v[31],v[18],v[26],v[22], v[14],v[23],v[19],v[17],v[10],v[ 8],v[11],v[20],
        v[ 1],v[28],v[ 2],v[ 4],v[ 9],v[24],v[25],v[27], v[ 7],v[21],v[13],v[29],v[ 5],v[ 3],v[16],v[12] };
    end endfunction

    reg [31:0] dec_r;
    always @(*) case (a[1:0])
        2'd0: dec_r = bsw0(d1 ^ 32'hec63197a);
        2'd1: dec_r = bsw1(d1 ^ 32'h58a5a55f);
        2'd2: dec_r = bsw2(d1 ^ 32'he3a65f16);
        2'd3: dec_r = bsw3(d1 ^ 32'h28d93783);
    endcase
    assign dec = dec_r;
endmodule
