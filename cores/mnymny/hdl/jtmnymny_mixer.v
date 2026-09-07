/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// 1B11142 analog network model: 68 parallel 1st-order sections served by
// one 4-multiplier engine at 3 clk/section, plus the tromba generator.
// Coefficients and golden vectors come from ver/audio (analyze.py --emit).
// Bit-true vs the python reference in ver/audio/emit.py.
// State RAM is not cleared on reset: bogus start-up content decays in
// <100 ms as every |a|<1 (verilator zero-inits, matching the reference).

module jtmnymny_mixer(
    input                    rst,
    input                    clk,
    input                    cen,      // 192 kHz
    input             [ 7:0] ay4g_a, ay4g_b, ay4g_c, ay4h_a, ay4h_b,
    input      signed [13:0] speech,
    input             [ 7:0] dac,
    input             [ 4:0] ioa,      // 2:0 tromba vol, 3 cassa, 4 rullante
    input                    level, levelt, sw1,
    output reg signed [15:0] music, voice, pcm
);

`include "jtmnymny_params.vh"

reg  [79:0] rom[0:79];
reg  [47:0] ysta[0:79];
initial $readmemh("jtmnymny_coeffs.hex", rom);

// ------------------------------------------------------------- tromba
reg         [ 1:0] tst;      // 0 idle, 1 pulse (Q=1), 2 recovery
reg         [ 5:0] tph;
reg                tone1;
reg  signed [15:0] tv;
reg         [ 1:0] tnx;
reg         [ 5:0] pnx;
wire               tone = ay4h_b > TONE_TH;
wire signed [16:0] ttgt = levelt ? TGT_SOFT : TGT_LOUD;
wire signed [17:0] tdif = {ttgt[16], ttgt} - {{2{tv[15]}}, tv};
wire signed [35:0] tinc = tdif * $signed({1'b0, KRAMP});
wire signed [15:0] tvnx = tnx==2'd1 ? 16'd0 : tv + tinc[31:16];
wire        [ 2:0] tvol = {ioa[0], ioa[1], ioa[2]};
wire        [15:0] tlad = LADDER[tvol*16 +: 16];
wire signed [32:0] tmul = tvnx * $signed({1'b0, tlad});

always @* begin
    tnx = tst; pnx = tph;
    case( tst )
        2'd0: if( tone && !tone1 ) begin tnx = 2'd1; pnx = PULSE_TK; end
        2'd1: begin pnx = tph-6'd1; if( tph==6'd1 ) begin tnx = 2'd2; pnx = RECOV_TK; end end
        default: begin pnx = tph-6'd1; if( tph==6'd1 ) tnx = 2'd0; end
    endcase
end

// ------------------------------------------------------------- engine
localparam [6:0] LAST = SECTIONS-1;
localparam [1:0] FETCH=0, MULT=1, WRITE=2, EPILOG=3;

reg  [ 1:0] ph;
reg  [ 6:0] sc;
reg         run, level_l;
reg  [79:0] cw;
reg  signed [47:0] y;
reg  signed [47:0] pa1;
reg         [47:0] pa2;
reg  signed [39:0] pb0, pb1;
reg  signed [55:0] accm, accv, accp;
reg  signed [15:0] x[0:8], x1[0:8];

wire [ 3:0] insel = cw[3:0];
wire [ 1:0] osel  = cw[5:4];
wire [23:0] ca    = cw[29:6];
wire signed [23:0] cb0 = cw[53:30];
wire signed [23:0] cb1 = cw[77:54];
wire signed [23:0] yhi = y[47:24];
wire        [23:0] ylo = y[23:0];

wire signed [49:0] ysum = {{2{pa1[47]}}, pa1} + {26'd0, pa2[47:24]}
                        + {{10{pb0[39]}}, pb0} + {{10{pb1[39]}}, pb1};
wire signed [47:0] ynew =
    ysum >  50'sh7FFF_FFFF_FFFF ?  48'sh7FFF_FFFF_FFFF :
    ysum < -50'sh8000_0000_0000 ? -48'sh8000_0000_0000 : ysum[47:0];

function signed [15:0] sat16(input signed [55:0] v);
    sat16 = v > 56'sd32767 ? 16'sd32767 :
            v < -56'sd32768 ? -16'sd32768 : v[15:0];
endfunction

wire signed [55:0] msh  = accm >>> BSH;
wire signed [16:0] msat = msh > 56'sd65535 ?  17'sd65535 :
                          msh < -56'sd65536 ? -17'sd65536 : msh[16:0];
wire signed [33:0] mduck = msat * $signed({1'b0, DUCK_G});
wire signed [18:0] mdk   = mduck[33:15];

integer i;

always @(posedge clk) begin
    if( rst ) begin
        tst <= 0; tph <= 0; tv <= 0; tone1 <= 0;
        run <= 0; music <= 0; voice <= 0; pcm <= 0;
        for( i=0; i<9; i=i+1 ) begin x[i] <= 0; x1[i] <= 0; end
    end else begin
        if( cen ) begin
            tst <= tnx; tph <= pnx; tone1 <= tone; tv <= tvnx;
            x[0] <= ioa[4] ? {1'b0, ay4g_a, 7'd0} : 16'd0;
            x[1] <= ioa[3] ? {1'b0, ay4g_a, 7'd0} : 16'd0;
            x[2] <= {1'b0, ay4g_b, 7'd0};
            x[3] <= {1'b0, ay4h_a, 7'd0};
            x[4] <= sw1 ? 16'd0 : {1'b0, ay4g_c, 7'd0};
            x[5] <= sw1 ? {1'b0, ay4g_c, 7'd0} : 16'd0;
            x[6] <= tmul[30:15];
            x[7] <= {speech, 2'd0};
            x[8] <= {1'b0, dac, 7'd0};
            level_l <= level;
            sc  <= 0; ph <= FETCH; run <= 1;
            accm <= 0; accv <= 0; accp <= 0;
        end else if( run ) case( ph )
            FETCH: begin
                cw <= rom[sc];
                y  <= ysta[sc];
                ph <= MULT;
            end
            MULT: begin
                pa1 <= $signed({1'b0, ca}) * yhi;
                pa2 <= ca * ylo;
                pb0 <= cb0 * x [insel];
                pb1 <= cb1 * x1[insel];
                ph  <= WRITE;
            end
            WRITE: begin
                ysta[sc] <= ynew;
                case( osel )
                    2'd0: accm <= accm + {{8{ynew[47]}}, ynew};
                    2'd1: accv <= accv + {{8{ynew[47]}}, ynew};
                    default: accp <= accp + {{8{ynew[47]}}, ynew};
                endcase
                sc <= sc + 7'd1;
                ph <= sc==LAST ? EPILOG : FETCH;
            end
            default: begin // EPILOG
                music <= level_l ?
                    ( mdk >  19'sd32767 ?  16'sd32767 :
                      mdk < -19'sd32768 ? -16'sd32768 : mdk[15:0] ) :
                    sat16({{39{msat[16]}}, msat});
                voice <= sat16(accv >>> BSH);
                pcm   <= sat16(accp >>> BSH);
                for( i=0; i<9; i=i+1 ) x1[i] <= x[i];
                run <= 0;
            end
        endcase
    end
end

endmodule
