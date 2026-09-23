/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 18-9-2026
*/

// single-cycle integer operations and condition-code generation
// keyed on { opcode[31:24], opcode[10:7] }, semantics per MAME i960.cpp

module jt960_alu(
    input      [31:0] ir,
    input      [31:0] t1, t2, t3, // src1, src2, src/dst current value
    input      [31:0] ac,
    output reg [31:0] res,
    output reg        res_we,
    output reg [31:0] ac_nx,
    output reg        bad
);

wire [ 7:0] mj   = ir[31:24];
wire [ 3:0] sb   = ir[10: 7];
wire [ 4:0] sh1  = t1[ 4: 0];
wire        shof = |t1[31:5];              // shift count >= 32
wire        cin  = ac[1];
// add/sub with carry
wire [32:0] addcs = {1'b0,t2} + {1'b0,t1} + {32'd0,cin};
wire        addcv = (addcs[31]^t1[31]) & (addcs[31]^t2[31]);
wire [32:0] subcs = {1'b0,t2} + {1'b0,~t1} + {32'd0,cin};
wire        subcv = (t2[31]^t1[31]) & (t2[31]^subcs[31]);
// one 64-bit left funnel serves every shift: the result is fun[63:32] and
// right shifts feed the amount complement, leaving the shifted-out bits
// in fun[31:0] (the shrdi rounding sticky comes for free)
wire is59  = mj==8'h59;
wire f_sr  = is59 && (sb==4'h8 || sb==4'ha || sb==4'hb);
wire f_sra = is59 && (sb==4'ha || sb==4'hb);
wire f_shl = is59 && (sb==4'hc || sb==4'he);
wire f_rot = is59 && sb==4'hd;
wire f_ext = mj==8'h65 && sb==4'h1;
wire f_bit = mj==8'h58;
wire [31:0] fhi  = f_bit ? 32'd1 : f_sra ? {32{t2[31]}} : (f_shl||f_rot) ? t2 : 32'd0;
wire [31:0] flo  = (f_sr||f_rot) ? t2 : f_ext ? t3 : 32'd0;
// shift as a one-hot multiply; the bit-reversed one-hot is the 32-sh1
// amount complement for right shifts, so the subtractor disappears
wire [32:0] oh_l = 33'd1 << sh1;
wire [32:0] oh_r;
genvar gk;
generate for( gk=0; gk<=32; gk=gk+1 ) begin : g_ohr
    assign oh_r[gk] = oh_l[32-gk];
end endgenerate
wire [32:0] oh   = (f_sr||f_ext) ? oh_r : oh_l;
(* multstyle = "dsp" *) wire [64:0] ph = fhi * oh;
(* multstyle = "dsp" *) wire [64:0] pl = flo * oh;
wire [63:0] fun  = { ph[31:0] | pl[63:32], pl[31:0] };
wire [31:0] fsh  = fun[63:32];
wire        fstk = |fun[31:0];
// extract length mask, thermometer decode
wire [31:0] exmsk;
genvar gi;
generate for( gi=0; gi<32; gi=gi+1 ) begin : g_exmsk
    assign exmsk[gi] = |t2[31:5] || gi[4:0] < t2[4:0];
end endgenerate

function [2:0] cmpu(input [31:0] a, input [31:0] b);
    cmpu = a<b ? 3'b100 : a==b ? 3'b010 : 3'b001;
endfunction

function [4:0] msb32(input [31:0] a); // highest set bit, binary search
    reg [15:0] h16; reg [7:0] h8; reg [3:0] h4; reg [1:0] h2;
    begin
        msb32[4] = |a[31:16];
        h16      = msb32[4] ? a[31:16] : a[15:0];
        msb32[3] = |h16[15:8];
        h8       = msb32[3] ? h16[15:8] : h16[7:0];
        msb32[2] = |h8[7:4];
        h4       = msb32[2] ? h8[7:4] : h8[3:0];
        msb32[1] = |h4[3:2];
        h2       = msb32[1] ? h4[3:2] : h4[1:0];
        msb32[0] = h2[1];
    end
endfunction

function [2:0] cmps(input [31:0] a, input [31:0] b);
    cmps = $signed(a)<$signed(b) ? 3'b100 : a==b ? 3'b010 : 3'b001;
endfunction

reg [2:0] cc;

always @* begin
    res    = 32'd0;
    res_we = 0;
    ac_nx  = ac;
    bad    = 0;
    cc     = 3'd0;
    case( mj )
    8'h30, 8'h37: begin // bbc, bbs: cc only, branch decided by the sequencer
        if( mj==8'h37 ? t2[sh1] : ~t2[sh1] ) cc = 3'b010;
        ac_nx = {ac[31:3], cc};
    end
    8'h31,8'h32,8'h33,8'h34,8'h35,8'h36:
        ac_nx = {ac[31:3], cmpu(t1,t2)};    // cmpobcc
    8'h39,8'h3a,8'h3b,8'h3c,8'h3d,8'h3e:
        ac_nx = {ac[31:3], cmps(t1,t2)};    // cmpibcc
    8'h58: begin
        res_we = 1;
        case( sb )
        4'h0: res = t2 ^  fsh;                      // notbit
        4'h1: res = t2 &  t1;                       // and
        4'h2: res = t2 & ~t1;                       // andnot
        4'h3: res = t2 |  fsh;                      // setbit
        4'h4: res = ~t2 &  t1;                      // notand
        4'h6: res = t2 ^  t1;                       // xor
        4'h7: res = t2 |  t1;                       // or
        4'h8: res = ~t2 & ~t1;                      // nor
        4'h9: res = ~(t2 ^ t1);                     // xnor
        4'ha: res = ~t1;                            // not
        4'hb: res = t2 | ~t1;                       // ornot
        4'hc: res = t2 & ~fsh;                      // clrbit
        4'hd: res = ~t2 | t1;                       // notor
        4'he: res = ~t2 | ~t1;                      // nand
        4'hf: res = ac[1] ? t2|fsh : t2&~fsh;       // alterbit
        default: begin bad=1; res_we=0; end
        endcase
    end
    8'h59: begin
        res_we = 1;
        case( sb )
        4'h0,4'h1: res = t2 + t1;                   // addo, addi
        4'h2,4'h3: res = t2 - t1;                   // subo, subi
        4'h8: res = shof ? 32'd0 : fsh;             // shro
        4'ha: res = shof ? 32'd0 :                  // shrdi, rounds towards zero
                    ( t2[31] && fstk ) ? fsh+32'd1 : fsh;
        4'hb: res = shof ? {32{t2[31]}} : fsh;      // shri
        4'hc,4'he: res = shof ? 32'd0 : fsh;        // shlo, shli
        4'hd: res = fsh;                            // rotate
        default: begin bad=1; res_we=0; end
        endcase
    end
    8'h5a: begin
        case( sb )
        4'h0: ac_nx = {ac[31:3], cmpu(t1,t2)};      // cmpo
        4'h1: ac_nx = {ac[31:3], cmps(t1,t2)};      // cmpi
        4'h2: if(!ac[2]) ac_nx = {ac[31:3],         // concmpo
                  t1<=t2 ? 3'b010 : 3'b001};
        4'h3: if(!ac[2]) ac_nx = {ac[31:3],         // concmpi
                  $signed(t1)<=$signed(t2) ? 3'b010 : 3'b001};
        4'h4: begin ac_nx={ac[31:3],cmpu(t1,t2)}; res=t2+32'd1; res_we=1; end // cmpinco
        4'h5: begin ac_nx={ac[31:3],cmps(t1,t2)}; res=t2+32'd1; res_we=1; end // cmpinci
        4'h6: begin ac_nx={ac[31:3],cmpu(t1,t2)}; res=t2-32'd1; res_we=1; end // cmpdeco
        4'h7: begin ac_nx={ac[31:3],cmps(t1,t2)}; res=t2-32'd1; res_we=1; end // cmpdeci
        4'hc: ac_nx = {ac[31:3], 1'b0,              // scanbyte
                  t1[31:24]==t2[31:24] || t1[23:16]==t2[23:16] ||
                  t1[15: 8]==t2[15: 8] || t1[ 7: 0]==t2[ 7: 0], 1'b0};
        4'he: ac_nx = {ac[31:3], 1'b0, t2[sh1], 1'b0}; // chkbit
        default: bad=1;
        endcase
    end
    8'h5b: begin
        res_we = 1;
        case( sb )
        4'h0: begin // addc, cc bit 2 is kept
            res   = addcs[31:0];
            ac_nx = {ac[31:2], addcs[32], addcv};
        end
        4'h2: begin // subc
            res   = subcs[31:0];
            ac_nx = {ac[31:3], 1'b0, subcs[32], subcv};
        end
        default: begin bad=1; res_we=0; end
        endcase
    end
    8'h64: begin
        case( sb )
        4'h0: begin // spanbit
            res = 32'hffff_ffff;
            if( ~&t1 ) begin res = {27'd0, msb32(~t1)}; cc = 3'b010; end
            ac_nx  = {ac[31:3], cc};
            res_we = 1;
        end
        4'h1: begin // scanbit
            res = 32'hffff_ffff;
            if( |t1 ) begin res = {27'd0, msb32(t1)}; cc = 3'b010; end
            ac_nx  = {ac[31:3], cc};
            res_we = 1;
        end
        4'h4: begin // dmovt - AC upper 16 bits cleared, as in MAME
            res    = t1;
            res_we = 1;
            ac_nx  = {16'd0, ac[15:3], 1'b0,
                      (t1[7:0]<8'h30 || t1[7:0]>8'h39), 1'b0};
        end
        4'h5: begin // modac
            res    = ac;
            res_we = 1;
            ac_nx  = (ac & ~t1) | (t2 & t1);
        end
        default: bad=1;
        endcase
    end
    8'h65: begin
        res_we = 1;
        case( sb )
        4'h0: res = (t2 & t1) | (t3 & ~t1);             // modify
        4'h1: res = (shof ? 32'd0 : fsh) & exmsk;       // extract
        default: begin bad=1; res_we=0; end
        endcase
    end
    default: bad=1;
    endcase
end

endmodule
