/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// jtmnymny_tms5200_tables.vh — TMS5200 parameter look-up ROMs
// The data manual (DSAP005265, table 3) gives only the level counts:
// energy 15+stop, pitch 64, K1/K2 32, K3-K7 16, K8-K10 8 — all decoding
// to 10-bit actual parameters. The values are chip mask data: FILL FROM
// A DIE DUMP (tms5110r-style tables for the TMC0285/TMS5200 variant).
// Placeholders: energy = exponential-ish ramp, pitch = linear 0..127,
// K = 0 (lattice passes excitation through). With placeholder K the chip
// "speaks" buzz/noise at the right cadence: enough to prove the CPU
// handshake end-to-end, not enough for real speech.

function signed [9:0] energytbl(input [3:0] idx);
    case( idx )
        4'd0 :   energytbl = 10'sd0;
        4'd1 :   energytbl = 10'sd1;
        4'd2 :   energytbl = 10'sd2;
        4'd3 :   energytbl = 10'sd3;
        4'd4 :   energytbl = 10'sd4;
        4'd5 :   energytbl = 10'sd6;
        4'd6 :   energytbl = 10'sd8;
        4'd7 :   energytbl = 10'sd11;
        4'd8 :   energytbl = 10'sd16;
        4'd9 :   energytbl = 10'sd23;
        4'd10:   energytbl = 10'sd33;
        4'd11:   energytbl = 10'sd47;
        4'd12:   energytbl = 10'sd63;
        4'd13:   energytbl = 10'sd85;
        4'd14:   energytbl = 10'sd114;
        default: energytbl = 10'sd0;    // 15 = stop code, no energy
    endcase
endfunction

function signed [9:0] pitchtbl(input [5:0] idx);
    // placeholder: linear map, index 0 = unvoiced
    pitchtbl = idx==0 ? 10'sd0 : {3'd0, idx, 1'b0} + 10'sd14;
endfunction

function signed [9:0] ktbl(input [3:0] k, input [4:0] idx);
    // placeholder: zero reflection coefficients
    ktbl = 10'sd0;
endfunction

function signed [13:0] chirp(input [6:0] pos);
    // placeholder chirp: single impulse at pitch period start
    chirp = pos==0 ? 14'sd512 : 14'sd0;
endfunction
