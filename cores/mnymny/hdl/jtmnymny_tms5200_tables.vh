/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// jtmnymny_tms5200_tables.vh — TMS5200/TMC0285 (CD2501E) parameter ROMs
// Values read from the TMS5200NL die decapped and imaged by digshadow
// (March 2013, siliconpr0n.org); energy and pitch also match US patent
// 4,335,277 (the patent's K tables are scrambled, the decap is authoritative).
// Chirp checksum 0x3da per the decap notes.

// energy, 15 levels + stop (index 15)
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
        default: energytbl = 10'sd0;    // 15 = stop code
    endcase
endfunction

// pitch, 64 entries (6-bit field); 0 = unvoiced
function signed [9:0] pitchtbl(input [5:0] idx);
    case( idx )
        6'd0 : pitchtbl = 10'sd0;   6'd1 : pitchtbl = 10'sd14;
        6'd2 : pitchtbl = 10'sd15;  6'd3 : pitchtbl = 10'sd16;
        6'd4 : pitchtbl = 10'sd17;  6'd5 : pitchtbl = 10'sd18;
        6'd6 : pitchtbl = 10'sd19;  6'd7 : pitchtbl = 10'sd20;
        6'd8 : pitchtbl = 10'sd21;  6'd9 : pitchtbl = 10'sd22;
        6'd10: pitchtbl = 10'sd23;  6'd11: pitchtbl = 10'sd24;
        6'd12: pitchtbl = 10'sd25;  6'd13: pitchtbl = 10'sd26;
        6'd14: pitchtbl = 10'sd27;  6'd15: pitchtbl = 10'sd28;
        6'd16: pitchtbl = 10'sd29;  6'd17: pitchtbl = 10'sd30;
        6'd18: pitchtbl = 10'sd31;  6'd19: pitchtbl = 10'sd32;
        6'd20: pitchtbl = 10'sd34;  6'd21: pitchtbl = 10'sd36;
        6'd22: pitchtbl = 10'sd38;  6'd23: pitchtbl = 10'sd40;
        6'd24: pitchtbl = 10'sd41;  6'd25: pitchtbl = 10'sd43;
        6'd26: pitchtbl = 10'sd45;  6'd27: pitchtbl = 10'sd48;
        6'd28: pitchtbl = 10'sd49;  6'd29: pitchtbl = 10'sd51;
        6'd30: pitchtbl = 10'sd54;  6'd31: pitchtbl = 10'sd55;
        6'd32: pitchtbl = 10'sd57;  6'd33: pitchtbl = 10'sd60;
        6'd34: pitchtbl = 10'sd62;  6'd35: pitchtbl = 10'sd64;
        6'd36: pitchtbl = 10'sd68;  6'd37: pitchtbl = 10'sd72;
        6'd38: pitchtbl = 10'sd74;  6'd39: pitchtbl = 10'sd76;
        6'd40: pitchtbl = 10'sd81;  6'd41: pitchtbl = 10'sd85;
        6'd42: pitchtbl = 10'sd87;  6'd43: pitchtbl = 10'sd90;
        6'd44: pitchtbl = 10'sd96;  6'd45: pitchtbl = 10'sd99;
        6'd46: pitchtbl = 10'sd103; 6'd47: pitchtbl = 10'sd107;
        6'd48: pitchtbl = 10'sd112; 6'd49: pitchtbl = 10'sd117;
        6'd50: pitchtbl = 10'sd122; 6'd51: pitchtbl = 10'sd127;
        6'd52: pitchtbl = 10'sd133; 6'd53: pitchtbl = 10'sd139;
        6'd54: pitchtbl = 10'sd145; 6'd55: pitchtbl = 10'sd151;
        6'd56: pitchtbl = 10'sd157; 6'd57: pitchtbl = 10'sd164;
        6'd58: pitchtbl = 10'sd171; 6'd59: pitchtbl = 10'sd178;
        6'd60: pitchtbl = 10'sd186; 6'd61: pitchtbl = 10'sd194;
        6'd62: pitchtbl = 10'sd202; 6'd63: pitchtbl = 10'sd211;
    endcase
endfunction

// K1-K10 reflection coefficients; K1,K2: 32 entries, K3-K7: 16, K8-K10: 8
function signed [9:0] ktbl(input [3:0] k, input [4:0] idx);
    case( k )
    4'd0: case( idx )   // K1
        5'd0 : ktbl = -10'sd501; 5'd1 : ktbl = -10'sd498;
        5'd2 : ktbl = -10'sd495; 5'd3 : ktbl = -10'sd490;
        5'd4 : ktbl = -10'sd485; 5'd5 : ktbl = -10'sd478;
        5'd6 : ktbl = -10'sd469; 5'd7 : ktbl = -10'sd459;
        5'd8 : ktbl = -10'sd446; 5'd9 : ktbl = -10'sd431;
        5'd10: ktbl = -10'sd412; 5'd11: ktbl = -10'sd389;
        5'd12: ktbl = -10'sd362; 5'd13: ktbl = -10'sd331;
        5'd14: ktbl = -10'sd295; 5'd15: ktbl = -10'sd253;
        5'd16: ktbl = -10'sd207; 5'd17: ktbl = -10'sd156;
        5'd18: ktbl = -10'sd102; 5'd19: ktbl = -10'sd45;
        5'd20: ktbl =  10'sd13;  5'd21: ktbl =  10'sd70;
        5'd22: ktbl =  10'sd126; 5'd23: ktbl =  10'sd179;
        5'd24: ktbl =  10'sd228; 5'd25: ktbl =  10'sd272;
        5'd26: ktbl =  10'sd311; 5'd27: ktbl =  10'sd345;
        5'd28: ktbl =  10'sd374; 5'd29: ktbl =  10'sd399;
        5'd30: ktbl =  10'sd420; 5'd31: ktbl =  10'sd437;
    endcase
    4'd1: case( idx )   // K2
        5'd0 : ktbl = -10'sd376; 5'd1 : ktbl = -10'sd357;
        5'd2 : ktbl = -10'sd335; 5'd3 : ktbl = -10'sd312;
        5'd4 : ktbl = -10'sd286; 5'd5 : ktbl = -10'sd258;
        5'd6 : ktbl = -10'sd227; 5'd7 : ktbl = -10'sd195;
        5'd8 : ktbl = -10'sd161; 5'd9 : ktbl = -10'sd124;
        5'd10: ktbl = -10'sd87;  5'd11: ktbl = -10'sd49;
        5'd12: ktbl = -10'sd10;  5'd13: ktbl =  10'sd29;
        5'd14: ktbl =  10'sd68;  5'd15: ktbl =  10'sd106;
        5'd16: ktbl =  10'sd143; 5'd17: ktbl =  10'sd178;
        5'd18: ktbl =  10'sd212; 5'd19: ktbl =  10'sd243;
        5'd20: ktbl =  10'sd272; 5'd21: ktbl =  10'sd299;
        5'd22: ktbl =  10'sd324; 5'd23: ktbl =  10'sd346;
        5'd24: ktbl =  10'sd366; 5'd25: ktbl =  10'sd384;
        5'd26: ktbl =  10'sd400; 5'd27: ktbl =  10'sd414;
        5'd28: ktbl =  10'sd427; 5'd29: ktbl =  10'sd438;
        5'd30: ktbl =  10'sd448; 5'd31: ktbl =  10'sd506;
    endcase
    4'd2: case( idx[3:0] )  // K3
        4'd0 : ktbl = -10'sd407; 4'd1 : ktbl = -10'sd381;
        4'd2 : ktbl = -10'sd349; 4'd3 : ktbl = -10'sd311;
        4'd4 : ktbl = -10'sd268; 4'd5 : ktbl = -10'sd218;
        4'd6 : ktbl = -10'sd162; 4'd7 : ktbl = -10'sd102;
        4'd8 : ktbl = -10'sd39;  4'd9 : ktbl =  10'sd25;
        4'd10: ktbl =  10'sd89;  4'd11: ktbl =  10'sd149;
        4'd12: ktbl =  10'sd206; 4'd13: ktbl =  10'sd257;
        4'd14: ktbl =  10'sd302; 4'd15: ktbl =  10'sd341;
    endcase
    4'd3: case( idx[3:0] )  // K4
        4'd0 : ktbl = -10'sd290; 4'd1 : ktbl = -10'sd252;
        4'd2 : ktbl = -10'sd209; 4'd3 : ktbl = -10'sd163;
        4'd4 : ktbl = -10'sd114; 4'd5 : ktbl = -10'sd62;
        4'd6 : ktbl = -10'sd9;   4'd7 : ktbl =  10'sd44;
        4'd8 : ktbl =  10'sd97;  4'd9 : ktbl =  10'sd147;
        4'd10: ktbl =  10'sd194; 4'd11: ktbl =  10'sd238;
        4'd12: ktbl =  10'sd278; 4'd13: ktbl =  10'sd313;
        4'd14: ktbl =  10'sd344; 4'd15: ktbl =  10'sd371;
    endcase
    4'd4: case( idx[3:0] )  // K5
        4'd0 : ktbl = -10'sd318; 4'd1 : ktbl = -10'sd283;
        4'd2 : ktbl = -10'sd245; 4'd3 : ktbl = -10'sd202;
        4'd4 : ktbl = -10'sd156; 4'd5 : ktbl = -10'sd107;
        4'd6 : ktbl = -10'sd56;  4'd7 : ktbl = -10'sd3;
        4'd8 : ktbl =  10'sd49;  4'd9 : ktbl =  10'sd101;
        4'd10: ktbl =  10'sd150; 4'd11: ktbl =  10'sd196;
        4'd12: ktbl =  10'sd239; 4'd13: ktbl =  10'sd278;
        4'd14: ktbl =  10'sd313; 4'd15: ktbl =  10'sd344;
    endcase
    4'd5: case( idx[3:0] )  // K6
        4'd0 : ktbl = -10'sd193; 4'd1 : ktbl = -10'sd152;
        4'd2 : ktbl = -10'sd109; 4'd3 : ktbl = -10'sd65;
        4'd4 : ktbl = -10'sd20;  4'd5 : ktbl =  10'sd26;
        4'd6 : ktbl =  10'sd71;  4'd7 : ktbl =  10'sd115;
        4'd8 : ktbl =  10'sd158; 4'd9 : ktbl =  10'sd198;
        4'd10: ktbl =  10'sd235; 4'd11: ktbl =  10'sd270;
        4'd12: ktbl =  10'sd301; 4'd13: ktbl =  10'sd330;
        4'd14: ktbl =  10'sd355; 4'd15: ktbl =  10'sd377;
    endcase
    4'd6: case( idx[3:0] )  // K7
        4'd0 : ktbl = -10'sd254; 4'd1 : ktbl = -10'sd218;
        4'd2 : ktbl = -10'sd180; 4'd3 : ktbl = -10'sd140;
        4'd4 : ktbl = -10'sd97;  4'd5 : ktbl = -10'sd53;
        4'd6 : ktbl = -10'sd8;   4'd7 : ktbl =  10'sd36;
        4'd8 : ktbl =  10'sd81;  4'd9 : ktbl =  10'sd124;
        4'd10: ktbl =  10'sd165; 4'd11: ktbl =  10'sd204;
        4'd12: ktbl =  10'sd240; 4'd13: ktbl =  10'sd274;
        4'd14: ktbl =  10'sd304; 4'd15: ktbl =  10'sd332;
    endcase
    4'd7: case( idx[2:0] )  // K8
        3'd0 : ktbl = -10'sd205; 3'd1 : ktbl = -10'sd112;
        3'd2 : ktbl = -10'sd10;  3'd3 : ktbl =  10'sd92;
        3'd4 : ktbl =  10'sd187; 3'd5 : ktbl =  10'sd269;
        3'd6 : ktbl =  10'sd336; 3'd7 : ktbl =  10'sd387;
    endcase
    4'd8: case( idx[2:0] )  // K9
        3'd0 : ktbl = -10'sd249; 3'd1 : ktbl = -10'sd183;
        3'd2 : ktbl = -10'sd110; 3'd3 : ktbl = -10'sd32;
        3'd4 : ktbl =  10'sd48;  3'd5 : ktbl =  10'sd126;
        3'd6 : ktbl =  10'sd198; 3'd7 : ktbl =  10'sd261;
    endcase
    default: case( idx[2:0] ) // K10
        3'd0 : ktbl = -10'sd190; 3'd1 : ktbl = -10'sd133;
        3'd2 : ktbl = -10'sd73;  3'd3 : ktbl = -10'sd10;
        3'd4 : ktbl =  10'sd53;  3'd5 : ktbl =  10'sd115;
        3'd6 : ktbl =  10'sd173; 3'd7 : ktbl =  10'sd227;
    endcase
    endcase
endfunction

// chirp (voiced excitation), 52 entries, signed 8-bit; sum = 0x3da
function signed [7:0] chirp(input [6:0] pos);
    case( pos )
        7'd0 : chirp =  8'sh00; 7'd1 : chirp =  8'sh03;
        7'd2 : chirp =  8'sh0f; 7'd3 : chirp =  8'sh28;
        7'd4 : chirp =  8'sh4c; 7'd5 : chirp =  8'sh6c;
        7'd6 : chirp =  8'sh71; 7'd7 : chirp =  8'sh50;
        7'd8 : chirp =  8'sh25; 7'd9 : chirp =  8'sh26;
        7'd10: chirp =  8'sh4c; 7'd11: chirp =  8'sh44;
        7'd12: chirp =  8'sh1a; 7'd13: chirp =  8'sh32;
        7'd14: chirp =  8'sh3b; 7'd15: chirp =  8'sh13;
        7'd16: chirp =  8'sh37; 7'd17: chirp =  8'sh1a;
        7'd18: chirp =  8'sh25; 7'd19: chirp =  8'sh1f;
        7'd20: chirp =  8'sh1d;
        default: chirp = 8'sh00;    // 21..51 and beyond
    endcase
endfunction

// interpolation shifts per interpolation period IC0..IC7
function [2:0] interp_shift(input [2:0] icp);
    case( icp )
        3'd0: interp_shift = 3'd0;  // IC0: jump to target (shift 0 = full)
        3'd1: interp_shift = 3'd3;
        3'd2: interp_shift = 3'd3;
        3'd3: interp_shift = 3'd3;
        3'd4: interp_shift = 3'd2;
        3'd5: interp_shift = 3'd2;
        3'd6: interp_shift = 3'd1;
        default: interp_shift = 3'd1;
    endcase
endfunction
