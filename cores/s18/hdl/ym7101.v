/*
 * Copyright (C) 2023 nukeykt
 *
 * This file is part of Nuked-MD.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 *  YM7101 emulator
 *  Thanks:
 *      Fritzchens Fritz:
 *          YM7101 decap and die shot.
 *      andkorzh:
 *          YM7101 deroute.
 *      org (ogamespec):
 *          early YM7101 decap and die shot.
 *      HardWareMan:
 *          help & support.
 *
 */
/* verilator lint_off PINMISSING */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off SELRANGE */
/* xxverilator lint_off UNOPTFLAT */
/* xxxverilator tracing_on */
module ym7101
	(
	input MCLK,
	input [7:0] SD,
	output SE1,
	output SE0,
	output SC,
	output RAS1,
	output CAS1,
	output WE1,
	output WE0,
	output OE1,
	input [7:0] RD_i,
	output [7:0] RD_o,
	output RD_d,
	output [7:0] DAC_R,
	output [7:0] DAC_G,
	output [7:0] DAC_B,
	input [7:0] AD_i,
	output [7:0] AD_o,
	output AD_d,
	output YS,
	input SPA_B_i,
	output SPA_B_pull,
	output VSYNC,
	input CSYNC_i,
	output CSYNC_pull,
	input HSYNC_i,
	output HSYNC_pull,
	input HL,
	input SEL0,
	input PAL,
	input RESET, // active low
	//input SEL1,
	input CLK1_i,
	output CLK1_o,
	//output CLK1_d,
	output SBCR,
	output CLK0,
	input MCLK_e,
	input EDCLK_i,
	output EDCLK_o,
	output EDCLK_d,
	output reg_m5,
	input [15:0] CD_i,
	output [15:0] CD_o,
	output CD_d,
	input [22:0] CA_i,
	output [22:0] CA_o,
	output CA_d,
	output reg [15:0] SOUND,
	output INT_pull,
	output BR_pull,
	input BGACK_i,
	output BGACK_pull,
	input BG,
	input MREQ,
	input INTAK,
	output IPL1_pull,
	output IPL2_pull,
	input IORQ,
	input RD,
	input WR,
	input M1,
	input AS,
	input UDS,
	input LDS,
	input RW,
	input DTACK_i,
	output DTACK_pull,
	output UWR,
	output LWR,
	output OE0,
	output CAS0,
	output RAS0,
	output [7:0] RA,
	input ext_test_2,
	output vdp_hclk1,
	output vdp_intfield,
	output vdp_de_h,
	output vdp_de_v,
	output vdp_m5, // md mode
	output vdp_rs1, // h32/h40
	output vdp_m2, // v28/v30
	output vdp_lcb,
	output vdp_psg_clk1,
	output vdp_vsync2,
	output vdp_hsync2,
	input  vdp_cramdot_dis,
	output vdp_dma_oe_early,
	output vdp_dma
	);

	wire cpu_sel;
	wire cpu_as;
	wire cpu_uds;
	wire cpu_lds;
	wire cpu_m1;
	wire cpu_rd;
	wire cpu_wr;
	wire cpu_mreq;
	wire cpu_iorq;
	wire cpu_rw;
	wire cpu_bg;
	wire cpu_intak;
	wire cpu_bgack;
	wire cpu_pal;
	wire cpu_pen;
	
	wire cpu_clk0;
	wire cpu_clk1;
	
	wire i_csync = ~CSYNC_i;
	wire i_hsync = ~HSYNC_i;
	
	wire i_spa = ~SPA_B_i;
	
	wire reset_ext = ~RESET;
	
	wire clk1, clk2;
	wire hclk1, hclk2;
	
	wire reset_comb;
	wire mclk_and1;
	//reg prescaler_dff1 = 1'h0;
	//reg prescaler_dff2 = 1'h0;
	//reg prescaler_dff3 = 1'h0;
	//reg prescaler_dff4 = 1'h0;
	//reg prescaler_dff5 = 1'h0;
	//reg prescaler_dff6 = 1'h0;
	//reg prescaler_dff7 = 1'h0;
	//reg prescaler_dff8 = 1'h0;
	//reg prescaler_dff9 = 1'h0;
	//reg prescaler_dff10 = 1'h0;
	//reg prescaler_dff11 = 1'h0;
	
	wire prescaler_dff1_l2;
	wire prescaler_dff2_l2;
	wire prescaler_dff3_l2;
	wire prescaler_dff4_l2;
	wire prescaler_dff5_l2;
	wire prescaler_dff6_l2;
	wire prescaler_dff7_l2;
	wire prescaler_dff8_l2;
	wire prescaler_dff9_l2;
	wire prescaler_dff10_l2;
	wire prescaler_dff11_l2;
	
	wire prescaler_dff12_l2;
	wire prescaler_dff13_l2;
	wire prescaler_dff14_l2;
	wire prescaler_dff15_l2;
	wire prescaler_dff16_l2;
	wire prescaler_dff17_l2;
	wire mclk_clk1;
	wire mclk_clk2;
	wire mclk_clk3;
	wire mclk_clk4;
	wire mclk_clk5;
	wire mclk_sbcr;
	wire mclk_cpu_clk0;
	wire mclk_cpu_clk1;
	wire mclk_dclk;
	
	wire io_m1_dff1_l2;
	wire io_m1_dff2_l2;
	wire io_m1_dff3_l2;
	wire io_m1_dff4_l2;
	wire io_m1_s1;
	wire io_m1_s2;
	wire io_m1_s3;
	wire io_m1_s4;
	wire io_m1_s5;
	reg [22:0] io_address;
	wire io_address_22o;
	wire io_oe0;
	wire w1153;
	wire io_cas0;
	wire io_ras0;
	wire io_lwr;
	wire io_uwr;
	wire io_wr;
	wire io_ipl1;
	wire io_ipl2;
	reg [15:0] io_data;
	wire w1;
	wire dff1_l2;
	wire dff2_l2;
	wire t1;
	wire w2;
	wire w3;
	wire w4;
	wire dff3_l2;
	wire dff4_l2;
	wire t2;
	wire t3;
	wire t4;
	wire w5;
	wire l1;
	wire l2;
	wire l3;
	wire w6;
	wire l4;
	wire w7;
	wire l5;
	wire w8;
	wire l6;
	wire l7;
	wire l8;
	wire w9;
	wire w10;
	wire w11;
	wire w12;
	wire w13;
	wire w14;
	wire w15;
	wire w16;
	// wire w17; // nc
	wire w18;
	wire w19;
	wire w20;
	wire w21;
	wire w22;
	wire w23;
	wire w24;
	wire w25;
	wire dff5_l2;
	wire dff6_l2;
	wire w26;
	wire dff7_l2;
	wire w27;
	wire w28;
	wire dff8_l2;
	wire dff9_l2;
	wire w29;
	wire w30;
	reg  w31;
	wire dff10_l2;
	wire dff11_l2;
	wire w32;
	wire w33;
	wire w34;
	wire w35;
	wire w36;
	wire w37;
	wire dff12_l2;
	reg  w38;
	wire dff13_l2;
	wire dff14_l2;
	wire dff15_l2;
	wire w39;
	wire w40;
	wire w41;
	wire dff16_l2;
	wire dff17_l2;
	wire dff18_l2;
	wire dff19_l2;
	wire dff20_l2;
	wire dff21_l2;
	wire dff22_l2;
	wire w42;
	wire dff23_l2;
	wire dff24_l2;
	wire dff25_l2;
	wire dff26_l2;
	wire dff27_l2;
	wire dff28_l2;
	wire dff29_l2;
	wire w43;
	wire w44;
	wire w45;
	wire w46;
	wire w47;
	wire t5;
	wire w48;
	wire l9;
	wire l10;
	wire l11;
	wire w49;
	wire w50;
	wire t6;
	wire l12;
	wire w51;
	wire l13;
	wire w52;
	wire l14;
	wire w53;
	wire w54;
	wire dff30_l2;
	wire dff31_l2;
	wire w55;
	wire dff32_l2;
	wire w56;
	wire w57;
	wire w58;
	wire t7;
	wire t8;
	wire w59;
	wire w60;
	wire w61;
	wire w62;
	wire w63;
	wire w64;
	wire w65;
	wire w66;
	wire t9;
	wire t10;
	wire t11;
	wire w67;
	wire w68;
	wire w69;
	wire l15;
	wire cs;
	wire w71;
	wire w72;
	wire w73;
	wire w74;
	wire w75;
	wire w76;
	wire w77;
	wire w78;
	wire w79;
	wire w80;
	wire w81;
	wire w82;
	wire w83;
	wire w84;
	wire w85;
	wire w86;
	wire w87;
	wire w88;
	wire w89;
	wire w90;
	wire w91;
	wire w92;
	wire w93;
	wire w94;
	wire w95;
	wire w96;
	wire w97;
	wire w98;
	wire w99;
	wire w100;
	wire w101;
	wire w102;
	wire [7:0] w103;
	wire w104;
	wire [7:0] l16;
	wire w105;
	wire w106;
	wire w107;
	wire w108;
	wire w109;
	wire w110;
	wire w111;
	wire w112;
	wire w113;
	wire w114;
	wire w115;
	wire w116;
	wire dtack_pull_n;
	wire w118;
	wire l17;
	wire w119;
	wire w120;
	wire w121;
	wire t12;
	wire w122;
	wire w123;
	wire w124;
	wire w125;
	wire w126;
	wire w127;
	wire w128;
	wire w129;
	wire w130;
	wire w131;
	wire w132;
	wire w133;
	wire w134;
	wire w135;
	wire t13;
	wire w136;
	wire w137;
	wire t14;
	wire w138;
	wire w139;
	wire w140;
	wire w141;
	wire w142;
	wire l18;
	wire l19;
	wire w143;
	wire t15, t15_n;
	wire t16, t16_n;
	wire t17;
	wire w144;
	wire w145;
	wire t18, t18_n;
	wire t19;
	wire t20;
	wire w147;
	wire w148;
	wire w149;
	wire t21;
	wire w150;
	wire cdd_n;
	wire w152;
	wire w153;
	wire w154;
	wire w155;
	wire w156;
	wire w157;
	wire w158;
	wire w159;
	wire w160;
	wire w161;
	wire t22;
	wire w162;
	wire w163;
	wire w164;
	wire w165;
	wire w166;
	wire w167;
	wire w168;
	wire w169;
	wire w170;
	wire t23;
	wire t24;
	wire w171;
	wire w172;
	wire w173;
	wire w174;
	wire w175;
	wire t25;
	wire w176;
	wire w177;
	wire w178;
	wire w179;
	wire w180;
	wire l20;
	wire w181;
	wire w182;
	wire w183;
	wire w184;
	wire l21;
	wire l22;
	wire l23;
	wire l24;
	wire l25;
	wire l26;
	wire w185;
	wire t26, t26_n;
	wire w186;
	wire l27;
	wire w187;
	wire w188;
	wire w189;
	wire w190;
	wire w191;
	wire w192;
	wire w193;
	wire w194;
	wire w195;
	wire l28;
	wire w196;
	wire t27;
	wire w197;
	wire w198;
	wire w199;
	wire w200;
	wire w201;
	wire w202;
	wire l29;
	wire l30;
	wire w203;
	wire w204;
	wire l31;
	wire l32;
	wire l33;
	wire l34;
	wire w205;
	wire w206;
	wire w207;
	wire w208;
	wire w209;
	wire w210;
	wire w211;
	wire w212;
	wire w213;
	wire w214;
	wire w215;
	wire w216;
	wire w217;
	wire w218;
	wire w219;
	wire w220;
	wire w221;
	wire w222;
	wire w223;
	wire w224;
	wire w225;
	wire w226;
	wire w227;
	wire w228;
	wire w229;
	wire w230;
	wire w231;
	wire w232;
	wire w233;
	wire w234;
	wire w235;
	wire [16:0] l35;
	wire [16:0] l36;
	wire [16:0] l37;
	wire [16:0] l38;
	wire [16:0] l39;
	wire w244;
	wire w245;
	wire w246;
	wire w247;
	wire w248;
	wire l40;
	wire w249;
	wire l41;
	wire w250;
	wire w251;
	wire l42;
	wire w252;
	wire l43;
	wire l44;
	wire l45;
	wire w253;
	wire w254;
	wire w255;
	wire l46;
	wire w256;
	wire w257;
	wire w258;
	wire w259;
	wire w260;
	wire w261;
	// wire w262; // nc
	wire w263;
	wire w264;
	wire w265;
	wire l47;
	wire w266;
	wire w267;
	wire l48;
	wire w268;
	wire w269;
	wire l49;
	wire w270;
	wire w271;
	wire t28;
	wire l50;
	wire w272;
	wire w273;
	wire w274;
	wire w275;
	wire w276;
	wire w277;
	wire w278;
	wire w279;
	wire w280;
	wire w281;
	wire w282;
	wire w283;
	wire w284;
	wire w285;
	wire w286;
	wire w287;
	wire w288;
	wire w289;
	wire w290;
	wire [1:0] l51;
	wire w291;
	wire w292;
	wire w293;
	wire w294;
	wire w295;
	wire w296;
	wire w297;
	wire l52;
	wire l53;
	wire l54;
	wire w298;
	wire w299;
	wire w300;
	wire l55;
	wire l56;
	wire l57;
	wire l58;
	wire l59;
	wire l60;
	wire l61;
	wire l62;
	wire l63;
	wire l64;
	wire l65;
	wire l66;
	wire l67;
	wire l68;
	wire l69;
	wire l70;
	wire l71;
	wire l72;
	wire l73;
	wire l74;
	wire l75;
	wire l76;
	wire l77;
	wire l78;
	wire w301;
	wire w302;
	wire w303;
	wire w304;
	wire w305;
	wire w306;
	wire w307;
	wire w308;
	wire w309;
	wire w310;
	wire w311;
	wire w312;
	wire w313;
	wire w314;
	wire w315;
	wire w316;
	wire w317;
	wire w318;
	wire w319;
	wire w320;
	wire w321;
	wire w322;
	wire w323;
	wire w324;
	wire w325;
	wire w326;
	wire w327;
	wire w328;
	wire w329;
	wire w330;
	wire w331;
	wire w332;
	wire w333;
	wire w334;
	wire l79;
	wire l80;
	wire w335;
	wire l81;
	wire w336;
	wire w337;
	wire w338;
	wire l82;
	wire l83;
	wire l84;
	wire w339;
	wire w340;
	wire l85;
	wire l86;
	wire l87;
	wire w341;
	wire w342;
	wire l88;
	wire l89;
	wire w343;
	wire w344;
	wire w345;
	wire w346;
	wire [7:0] l90;
	wire [7:0] l91;
	wire [7:0] w347;
	wire [7:0] w348;
	wire [7:0] l92;
	wire [7:0] w349;
	wire [7:0] l93;
	wire [7:0] w350;
	wire [7:0] l94;
	wire [7:0] l95;
	wire [7:0] l96;
	wire [7:0] l97;
	wire [7:0] w351;
	wire [7:0] unk_data;
	wire [7:0] l98;
	wire [7:0] l99;
	wire [7:0] w352;
	wire [7:0] l100;
	wire [7:0] l101;
	wire [7:0] w353;
	wire [7:0] l102;
	wire [7:0] l103;
	wire [7:0] w354;
	wire [7:0] l104;
	
	wire [8:0] l105;
	wire [9:0] w355;
	wire [8:0] l106;
	wire l107;
	wire l108;
	wire l109;
	wire l110;
	wire w356;
	wire w357;
	wire w358;
	wire w359;
	wire w360;
	wire l111;
	wire l112;
	wire w361;
	wire w362;
	wire w363;
	wire [8:0] w364;
	wire w365;
	wire w366;
	wire w367;
	wire w368;
	wire w369;
	wire w370;
	wire l113;
	wire l114;
	wire l115;
	wire l116;
	wire w371;
	wire w372;
	wire l117;
	wire l118;
	wire l119;
	wire w373;
	wire w374;
	wire l120;
	wire w375;
	wire w376;
	wire w377;
	wire l121;
	wire l122;
	wire l123;
	wire w378;
	wire w379;
	wire w380;
	wire w381;
	wire w382;
	wire w383;
	wire w384;
	wire w385;
	wire w386;
	wire l124;
	wire l125;
	wire l126;
	wire w387;
	wire l127;
	wire w388;
	wire l128;
	wire w389;
	wire l129;
	wire w390;
	wire w391;
	wire l130;
	wire w392;
	wire t29;
	wire l131;
	wire w393;
	wire l132;
	wire w394;
	wire w395;
	wire l133;
	wire l134;
	wire w396;
	wire l135;
	wire l136;
	wire w397;
	wire w398;
	wire w399;
	wire w400;
	wire t30;
	wire w401;
	wire l137;
	wire l138;
	wire w402;
	wire l139;
	wire w403;
	wire l140;
	wire l141;
	wire l142;
	wire w404;
	wire w405;
	wire w406;
	wire t31;
	wire w407;
	wire w408;
	wire w409;
	wire l143;
	wire l144;
	wire w410;
	wire l145;
	wire l146;
	wire l147;
	wire l148;
	wire w411;
	wire l149;
	wire l150;
	wire w412;
	wire w413;
	wire l151;
	wire t32;
	wire w414;
	wire l152;
	wire l153;
	wire w415;
	wire w416;
	wire w417;
	wire w418;
	wire w419;
	wire l154;
	wire l155;
	wire l156;
	wire w420;
	wire w421;
	wire l157;
	wire w422;
	wire l158;
	wire t33;
	wire w423;
	wire w424;
	wire w425;
	wire l159;
	wire l160;
	wire w426;
	wire l161;
	wire w427;
	wire [8:0] w428;
	wire w429;
	wire w430;
	wire w431;
	wire w432;
	wire w433;
	wire w434;
	wire w435;
	wire w436;
	wire w437;
	wire w438;
	wire l162;
	wire w439;
	wire l163;
	wire w440;
	wire t34;
	wire w441;
	wire l164;
	wire w442;
	wire t35;
	wire w443;
	wire l165;
	wire w444;
	wire w445;
	wire t36;
	wire w446;
	wire l167;
	wire w447;
	wire w448;
	wire w449;
	wire l168;
	wire w450;
	wire w451;
	wire l169;
	wire w452;
	wire w453;
	wire t37;
	wire w454;
	wire w455;
	wire w456;
	wire l170;
	wire w457;
	wire w458;
	wire w459;
	wire t38;
	wire l171;
	wire l172;
	wire t39;
	wire w460;
	wire w461;
	wire l173;
	wire l174;
	wire w462;
	wire w463;
	wire w464;
	wire l175;
	wire l176;
	wire w465;
	wire w466;
	wire [47:0] pla_vcnt;
	wire [62:0] pla_hcnt1;
	wire [45:0] pla_hcnt2;
	wire w467;
	wire w468;
	wire w469;
	wire w470;
	wire w471;
	wire w472;
	wire w473;
	wire w474;
	wire w475;
	wire w476;
	wire w477;
	wire w478;
	wire w479;
	wire w480;
	wire w481;
	wire w482;
	wire w483;
	wire w484;
	wire w485;
	wire w486;
	wire w487;
	wire w488;
	wire w489;
	wire w490;
	wire w491;
	wire w492;
	wire w493;
	wire w494;
	wire w495;
	wire w496;
	wire w497;
	wire w498;
	wire w499;
	wire w500;
	wire w501;
	wire w502;
	wire w503;
	wire w504;
	wire w505;
	wire w506;
	wire w507;
	wire w508;
	wire w509;
	wire w510;
	wire w511;
	wire w512;
	wire l663;

	wire w513;
	wire l178;
	wire w514;
	wire [7:0] l179;
	wire [10:0] w515; // 11 bits
	wire [10:0] l180; // 11 bits
	wire [10:0] l181;
	wire [2:0] l182;
	wire l183;
	wire w516;
	wire w517;
	wire [10:0] l184;
	wire [10:0] l185;
	wire l186;
	wire [10:0] w518;
	wire w519;
	wire w520;
	wire [10:0] w521;
	wire [10:0] w522;
	wire [1:0] reg_hsz;
	wire [1:0] reg_vsz;
	wire w523;
	wire w524;
	wire w525;
	wire [6:0] w526;
	wire [6:0] w527;
	wire [6:0] w528;
	wire w529;
	wire w530;
	wire w531;
	wire [3:0] reg_sa;
	wire [1:0] reg_nt; // m4
	wire [3:0] reg_sb;
	wire [3:0] w532;
	wire [1:0] w533;
	wire reg_8e_b0;
	wire reg_8e_b4;
	wire w534;
	wire [7:0] w535; // 8 bits
	wire [5:0] w536; // 6 bits
	wire [5:0] reg_wd;
	wire [6:0] reg_hs;
	wire [7:0] w537;
	wire w538;
	wire w539;
	wire w540;
	wire w541;
	wire [4:0] reg_whp;
	wire reg_rigt;
	wire [4:0] reg_wvp;
	wire reg_down;
	wire w542;
	wire w543;
	wire w544;
	wire l187;
	wire [4:0] l188;
	wire l189;
	wire [4:0] l190;
	wire w545;
	wire w546;
	wire w547;
	wire [7:0] reg_88; // m4 scroll
	wire [7:0] l191;
	wire [7:0] l192;
	wire w548;
	wire w549;
	wire w550;
	wire w551;
	wire w552;
	wire w553;
	wire [7:0] l193;
	wire [9:0] w554;
	wire [1:0] l194;
	wire [1:0] l195;
	wire [6:0] w555;
	wire l196;
	wire l197;
	wire l198;
	wire l199;
	wire w556;
	wire l200;
	wire w557;
	wire l201;
	wire w558;
	wire w559;
	wire l202;
	wire w560;
	wire l203;
	wire l204;
	wire l205;
	wire w561;
	wire w562;
	wire w563;
	wire w564;
	wire [3:0] w565;
	wire w566;
	wire [1:0] w567;
	wire w568;
	wire l206;
	wire l207;
	wire l208;
	wire l209;
	wire l210;
	wire l211;
	wire w569;
	wire [5:0] l212; // 6 bits
	wire l213;
	wire w570;
	wire l214;
	wire w571;
	wire l215;
	wire w572;
	wire l216;
	wire w573;
	wire w574;
	wire w575;
	wire [3:0] w576;
	wire [3:0] w577;
	wire [8:0] w578;
	wire [2:0] w579;
	wire [11:0] w580;
	wire w581;
	wire l217;
	wire w582;
	wire l218;
	wire w583;
	wire [7:0] l219;
	wire [7:0] l220;
	wire [7:0] l221;
	wire [7:0] l222;
	wire w584;
	wire w585;
	wire [1:0] w586;
	wire w587;
	wire [7:0] l223;
	wire [7:0] l224;
	wire [7:0] l225;
	wire [7:0] l226;
	wire l227;
	wire l228;
	wire l229;
	wire l230;
	wire l231;
	wire w588;
	wire w589;
	wire w590;
	wire w591;
	wire [7:0] l232;
	wire [7:0] l233;
	wire [7:0] l234;
	wire [7:0] l235;
	wire w592;
	wire [3:0] l236;
	wire w593;
	wire [7:0] l237;
	wire [7:0] l238;
	wire [7:0] l239;
	wire [7:0] l240;
	wire [3:0] l241;
	wire l242;
	wire [7:0] l243;
	wire [7:0] l244;
	wire [7:0] l245;
	wire [7:0] l246;
	wire l247;
	wire l248;
	wire l249;
	wire l250;
	wire w594;
	wire w595;
	wire w596;
	wire w597;
	wire l251;
	wire l252;
	wire l253;
	wire l254;
	wire [7:0] l255;
	wire [7:0] l256;
	wire [7:0] l257;
	wire [7:0] l258;
	wire [7:0] l259;
	wire [7:0] l260;
	wire [7:0] l261;
	wire [7:0] l262;
	wire [7:0] l263;
	wire [7:0] l264;
	wire [7:0] l265;
	wire w598;
	wire w599;
	wire w600;
	wire w601;
	wire w602;
	wire w603;
	wire w604;
	wire w605;
	wire [2:0] w606;
	wire [3:0] w607;
	wire w608;
	wire w609;
	wire w610;
	wire l266;
	wire w611;
	wire w612;
	wire l267;
	wire l268;
	wire w613;
	wire [3:0] l269;
	wire [3:0] l270;
	wire [1:0] l271;
	wire [1:0] l272;
	wire l273;
	wire l274;
	wire w614;
	wire [7:0] l275;
	wire [7:0] l276;
	wire [7:0] l277;
	wire [7:0] l278;
	wire [7:0] l279;
	wire [7:0] l280;
	wire [7:0] l281;
	wire [7:0] l282;
	wire w615;
	wire w616;
	wire w617;
	wire w618;
	wire l283;
	wire l284;
	wire l285;
	wire l286;
	wire w619;
	wire w620;
	wire w621;
	wire w622;
	wire [7:0] l287;
	wire [7:0] l288;
	wire [7:0] l289;
	wire [7:0] l290;
	wire [7:0] l291;
	wire [7:0] l292;
	wire w623;
	wire [5:0] l293;
	wire w624;
	wire [4:0] w625;
	wire [5:0] w626;
	wire [7:0] l294;
	wire [7:0] l295;
	wire [7:0] l296;
	wire [7:0] l297;
	wire l298;
	wire l299;
	wire l300;
	wire l301;
	wire l302;
	wire w627;
	wire w628;
	wire w629;
	wire w630;
	wire w631;
	wire [7:0] l303;
	wire [7:0] l304;
	wire [7:0] l305;
	wire [7:0] l306;
	wire [7:0] l307;
	wire [7:0] l308;
	wire [7:0] l309;
	wire [7:0] l310;
	wire [3:0] l311;
	wire [2:0] w632;
	wire w633;
	wire w634;
	wire w635;
	wire w636;
	wire w637;
	wire w638;
	wire l312;
	wire l313;
	wire w639;
	wire w640;
	wire [2:0] w641;
	wire w642;
	wire l314;
	wire l315;
	wire l316;
	wire w643;
	wire w644;
	wire l317;
	wire w645;
	wire w646;
	wire [3:0] w647;
	wire [3:0] l318;
	wire [3:0] l319;
	wire w648;
	wire l320;
	wire l321;
	wire [1:0] l322;
	wire [1:0] l323;
	wire w649;

	wire [10:0] w650;
	wire [10:0] l324;
	wire l325;
	wire l326;
	wire [10:0] l327;
	wire [10:0] l328;
	wire w651;
	wire l329;
	wire l330;
	wire l331;
	wire [10:0] l332;
	wire l333;
	wire w652;
	wire [9:0] w653;
	wire w654;
	wire w655;
	wire w656;
	wire w657;
	wire w658;
	wire w659;
	wire l334;
	wire w660;
	wire l335;
	wire w661;
	wire [9:0] w662;
	wire l336;
	wire l337;
	wire l338;
	wire l339;
	wire w663;
	wire w664;
	wire w665;
	wire [9:0] w666;
	wire [9:0] l340;
	wire [9:0] l341;
	wire w667;
	wire w668;
	wire w669;
	wire w670;
	wire w671;
	wire w672;
	wire [7:0] l342;
	wire [9:0] l343;
	wire [9:0] l344;
	wire w673;
	wire w674;
	wire w675;
	wire w676;
	wire w677;
	wire w678;
	wire w679;
	wire [9:0] l345;
	wire [9:0] l346;
	wire [9:0] w680;
	wire l347;
	wire l348;
	wire l349;
	wire l350;
	wire w681;
	wire w682;
	wire [6:0] l351;
	wire w683;
	wire l352;
	wire w684;
	wire l353;
	wire l354;
	wire w685;
	wire l355;
	wire l356;
	wire w686;
	wire l357;
	wire l358;
	wire l359;
	wire w687;
	wire w688;
	wire w689;
	wire w690;
	wire w691;
	wire l360_1;
	wire [5:0] l360_83;
	wire l361;
	wire l362;
	wire w692;
	wire w693;
	wire w694;
	wire l363;
	wire l364;
	wire [6:0] w695;
	wire [6:0] w696;
	wire [4:0] l365;
	wire [6:0] sat_link;
	wire [3:0] sat_size;
	wire [9:0] sat_ypos;
	wire [3:0] l366;
	wire [4:0] w697;
	wire l367;
	wire w698;
	wire l368;
	wire l369;
	wire l370;
	wire w699;
	wire w700;
	wire [4:0] l371;
	wire l372;
	wire w701;
	wire l373;
	wire w702;
	wire w703;
	wire w704;
	wire w705;
	wire w706;
	wire w707;
	wire w708;
	wire w709;
	wire w710;
	wire w711;
	wire w712;
	wire w713;
	wire l374;
	wire l375;
	wire l376;
	wire w714;
	wire w715;
	wire w716;
	wire l377;
	wire w717;
	wire l378;
	wire w718;
	wire [3:0] l379;
	wire [5:0] l380;
	wire w719;
	wire w720;
	wire w721;
	wire l381;
	wire t40;
	wire t41;
	wire w722;
	wire w723;
	wire w724;
	wire [1:0] w725;
	wire [1:0] w726;
	wire l382;
	wire l383;
	wire w727;
	wire l384;
	wire l385;
	wire [3:0] w728;
	wire [2:0] w729;
	wire [1:0] w730;
	wire [5:0] yoff;
	wire [7:0] l386;
	wire [7:0] l387;
	wire [7:0] w731;
	wire w732;
	wire [9:0] l388;
	wire [9:0] l389;
	wire [9:0] l390;
	wire [9:0] l391;
	wire w733;
	wire w734;
	wire w735;
	wire w736;
	wire w737;
	wire w738;
	wire [3:0] w739;
	wire reg_86_b2;
	wire reg_86_b5;
	wire [7:0] reg_at;
	wire w740;
	wire w741;
	wire w742;
	wire w743;
	wire l392;
	wire w744;
	wire w745;
	wire w746;
	wire l393;
	wire l394;
	wire w747;
	wire w748;
	wire l395;
	wire w749;
	wire l396;
	wire l397;
	wire w750;
	wire [6:0] l398;
	wire [6:0] l399;
	wire [6:0] l400;
	wire w751;
	wire l401;
	wire l402;
	wire [6:0] w752;
	wire w753;
	wire [19:0] l403;
	wire [19:0] l404;
	wire [19:0] l405;
	wire [19:0] l406;
	wire [19:0] l407;
	wire [19:0] l408;
	wire [19:0] l409;
	wire [19:0] l410;
	wire l411;
	wire l412;
	wire w754;
	wire w755;
	wire w756;
	wire [6:0] w757;
	wire w758;
	wire w759;
	wire w760;
	wire [1:0] w761;
	wire w763;
	wire [1:0] w764;
	wire [1:0] w766;
	wire [5:0] w768;
	wire w769;
	wire [10:0] w770;
	wire l413;
	wire [1:0] l414;
	wire l415;
	wire [1:0] l416;
	wire [1:0] l417;
	wire [5:0] l418;
	wire [10:0] sprdata_pattern_o;
	wire [8:0] sprdata_hpos_o;
	wire sprdata_hflip_o;
	wire [1:0] sprdata_pal_o;
	wire sprdata_priority_o;
	wire [1:0] sprdata_xs_o;
	wire [1:0] sprdata_ys_o;
	wire [5:0] sprdata_yoffset_o;
	wire l419;
	wire [1:0] l420;
	wire w771;
	wire w772;
	wire l421;
	wire l422;
	wire t42;
	wire l423;
	wire w773;
	wire [10:0] w774;
	wire [10:0] l424;
	wire [8:0] w775;
	wire [8:0] l425;
	wire l426;
	wire w776;
	wire w777;
	wire l427; // nc
	wire [3:0] w778;
	wire [3:0] w779;
	wire [10:0] w780;
	wire l428;
	wire w781;
	wire w782;
	wire l429;
	wire l430;
	wire w783;
	wire l431;
	wire w784;
	wire l432;
	wire l433;
	wire [1:0] w785;
	wire [3:0] w786;
	wire [3:0] w787;
	wire [3:0] l434;
	wire [7:0] l435;
	wire [7:0] l436;
	wire [7:0] l437;
	wire [7:0] w788;
	wire l438;
	wire l439, l439_1;
	wire [1:0] l440, l440_1;
	wire l441, l441_1;
	wire [1:0] l442, l442_1;
	wire [8:0] l443, l443_1;
	wire l444;
	wire w789;
	wire w790;
	wire l445;
	wire w791;
	wire w792;
	wire w793;
	wire w794;
	wire w795;
	wire w796;
	wire w797;
	wire w798;
	wire [8:0] w799;
	wire [5:0] w800;
	wire [5:0] l446;
	wire [5:0] l447;
	wire [5:0] w801;
	wire [5:0] w802;
	wire w803;
	wire l448;
	wire l449;
	wire l450;
	wire l451;
	wire [1:0] l452;
	wire [1:0] l453;
	wire l454;
	wire l455;
	wire l456;
	wire w804;
	wire w805;
	wire w806;
	wire [1:0] l457;
	wire w807;
	wire w808;
	wire [8:0] w809;
	wire l458;
	wire w810;
	wire w811;
	wire [1:0] w812;
	wire l459;
	wire l460;
	wire w813;
	wire l461;
	wire w814;
	wire l462;
	wire w815;
	wire l463;
	wire w816;
	wire l464;
	wire w817;
	wire w818;
	wire l465;
	wire w819;
	wire l466;
	wire w820;
	wire l467;
	wire l468;
	wire l469;
	wire w821;
	wire l470;
	wire l471;
	wire [2:0] l472;
	wire [2:0] l473;
	wire w822;
	wire w823;
	wire w824;
	wire [5:0] l474;
	wire [5:0] l475;
	wire [5:0] w825;
	wire w827;
	wire w828;
	wire [7:0] l478;
	wire [7:0] l479;
	wire [7:0] l480;
	wire [7:0] l481;
	wire w829;
	wire l482;
	wire l483;
	wire w830;
	wire w831;
	wire w832;
	wire l484;
	wire w833;
	wire l485;
	wire w834;
	wire [7:0] l486;
	wire [7:0] l487;
	wire [7:0] l488;
	wire l489;
	wire l490;
	wire w835;
	wire [7:0] l491;
	wire [7:0] l492;
	wire [7:0] l493;
	wire [7:0] l494;
	wire l495;
	wire l496;
	wire l497;
	wire l498;
	wire l499;
	wire l500;
	wire w836;
	wire l501;
	wire w837;
	wire w838;
	wire w839;
	wire w840;
	wire w841;
	wire w842;
	wire [7:0] w843;
	wire [7:0] w844;
	wire [7:0] l502;
	wire [7:0] w845;
	wire [1:0] l503;
	wire w846;
	wire [2:0] l504;
	wire l505;
	wire l506;
	wire w847;
	wire w848;
	wire l507;
	wire l508;
	wire l509;
	wire l510;
	wire w849;
	wire l511;
	wire l512;
	wire l513;
	wire w850;
	wire l514;
	wire w851;
	wire w852;
	wire w853;
	wire w854;
	wire w855;
	wire w856;
	wire w857;
	wire w858;
	wire w859;
	wire w860;
	wire w861;
	wire w862;
	wire w863;
	wire w864;
	wire w865;
	wire w866;
	wire w867;
	wire w868;
	wire w869;
	wire w870;
	wire w871;
	wire w872;
	wire w873;
	wire w874;
	wire w875;
	wire w876;
	wire w877;
	wire w878;
	wire w879;
	wire w880;
	wire w881;
	wire w882;
	wire w883;
	wire w884;
	wire [3:0] l515;
	wire [3:0] l516;
	wire [3:0] l517;
	wire [3:0] l518;
	wire [3:0] l519;
	wire [3:0] l520;
	wire [3:0] l521;
	wire [3:0] l522;
	wire w885;
	wire [3:0] l523;
	wire [3:0] l524;
	wire [3:0] l525;
	wire [3:0] l526;
	wire [3:0] l527;
	wire [3:0] l528;
	wire [3:0] l529;
	wire [3:0] l530;
	wire l531;
	wire l532;
	wire l533;
	wire l534;
	wire l535;
	wire l536;
	wire l537;
	wire w886;
	wire w887;
	wire w888;
	wire w889;
	wire w890;
	wire w891;
	wire w892;
	wire w893;
	wire w894;
	wire w895;
	wire w896;
	wire w897;
	wire w898;
	wire w899;
	wire w900;
	wire w901;
	wire w902;
	wire w903;
	wire w904;
	wire w905;
	wire w906;
	wire w907;
	wire w908;
	wire w909;
	wire l538;
	wire l539;
	wire l540;
	wire l541;
	wire l542;
	wire l543;
	wire l544;
	wire l545;
	wire w910;
	wire w911;
	wire w912;
	wire w913;
	wire w914;
	wire w915;
	wire w916;
	wire w917;
	wire w918;
	wire w919;
	wire w920;
	wire w921;
	wire w922;
	wire w923;
	wire w924;
	wire w925;
	wire w926;
	wire w927;
	wire w928;
	wire w929;
	wire w930;
	wire w931;
	wire w932;
	wire w933;
	wire w934;
	wire w935;
	wire w936;
	wire w937;
	wire w938;
	wire w939;
	wire w940;
	wire w941;
	wire w942;
	wire w943;
	wire w944;
	wire w945;
	wire w946;
	wire w947;
	wire w948;
	wire w949;
	wire w950;
	wire w951;
	wire w952;
	wire w953;
	wire w954;
	wire w955;
	wire w956;
	wire w957;
	wire w958;
	wire w959;
	wire w960;
	wire w961;
	wire w962;
	wire w963;
	wire w964;
	wire w965;
	wire w966;
	wire w967;
	wire w968;
	wire w969;
	wire [1:0] l553;
	wire l554;
	wire [3:0] l555;
	wire [1:0]spr_pal;
	wire spr_priority;
	wire [3:0] spr_index;
	wire [1:0] w970;
	wire w971;
	wire [3:0] w972;
	wire [1:0] l556;
	wire l557;
	wire [3:0] l558;
	wire [1:0] l559;
	wire l560;
	wire [3:0] l561;
	wire w973;
	wire [1:0] w974;
	wire w975;
	wire w976;
	wire w977;
	wire w978;
	wire l562;
	wire l563;
	wire w979;
	wire [1:0] w980;
	wire w982;
	wire [1:0] w983;
	wire l600;
	wire w1020;
	wire w1154;
	
	wire [1:0] linebuffer_out_pal[0:7];
	wire linebuffer_out_priority[0:7];
	wire [3:0] linebuffer_out_index[0:7];

	wire l564;
	wire l565;
	wire l566;
	wire l567;
	wire w985;
	wire w986;
	wire w987;
	wire w988;
	wire w989;
	wire w990;
	wire l568;
	wire w991;
	wire w992;
	wire l569;
	wire l570;
	wire l571;
	wire w993;
	wire l572;
	wire l573;
	wire l574;
	wire l575;
	wire l576;
	wire l577;
	wire l578;
	wire l579;
	wire w994;
	wire l580;
	wire l581;
	wire w995;
	wire w996;
	wire w997;
	wire l582;
	wire w998;
	wire l583;
	wire l584;
	wire w999;
	wire l585;
	wire w1000;
	wire l586;
	wire l587;
	wire l588;
	wire l589;
	wire l590;
	wire w1001;
	wire w1002;
	wire w1003;
	wire w1004;
	wire l591;
	wire w1005;
	wire w1006;
	wire w1007;
	wire w1008;
	wire w1009;
	wire w1010;
	wire w1011;
	wire [7:0] w1012;
	wire w1013;
	wire [7:0] l592;
	wire [7:0] w1014;
	wire [7:0] l593;
	wire [7:0] w1015;
	wire [7:0] l594;
	wire [7:0] w1016;
	wire [7:0] l595;
	wire [7:0] l596;
	wire [7:0] w1017;
	wire [7:0] l597;
	wire [7:0] l598;
	wire [7:0] l599;
	wire [7:0] w1018;
	wire [7:0] w1019;
	
	wire w1021;
	wire l601;
	wire l602;
	wire w1022;
	wire w1023;
	wire w1024;
	wire w1025;
	wire w1026;
	wire w1027;
	wire w1028;
	wire w1029;
	wire w1030;
	wire w1031;
	wire w1032;
	wire w1033;
	wire w1034;
	wire w1035;
	wire w1036;
	wire w1037;
	wire w1038;
	wire w1039;
	wire w1040;
	wire w1041;
	wire w1042;
	wire w1043;
	wire w1044;
	wire w1045;
	wire w1046;
	wire w1047;
	wire w1048;
	wire w1049;
	wire w1050;
	wire w1051;
	wire w1052;
	wire w1053;
	wire w1054;
	wire w1055;
	wire w1056;
	wire w1057;
	wire w1058;
	wire w1059;
	wire w1060;
	wire w1061;
	wire w1062;
	wire l603;
	wire l604;
	wire l605;
	wire l606;
	wire w1063;
	wire w1064;
	wire w1065;
	wire w1066;
	wire l607;
	wire w1067;
	wire w1068;
	wire l608;
	wire w1069;
	wire l609;
	wire l610;
	wire w1070;
	wire l611;
	wire l612;
	wire w1071;
	wire l613;
	wire w1072;
	wire w1073;
	wire [3:0] reg_col_index;
	wire [1:0] reg_col_pal;
	wire reg_col_b6;
	wire reg_col_b7;
	wire l614;
	wire l615;
	wire w1074;
	wire l616;
	wire w1075;
	wire [5:0] w1076;
	wire [5:0] l617;
	wire l618;
	wire w1077;
	wire l619;
	wire [2:0] l620;
	wire [2:0] w1078;
	wire [2:0] w1079;
	wire [8:0] l621;
	wire [8:0] l622;
	wire l623_1, l623_2, l623_3;
	wire w1080;
	wire w1081;
	wire l624;
	wire l625;
	wire w1082;
	wire w1083;
	wire w1084;
	wire w1085;
	wire w1086;
	wire w1087;
	wire w1088;
	wire w1089;
	wire w1090;
	wire w1091;
	wire w1092;
	wire w1093;
	wire w1094;
	wire w1095;
	wire w1096;
	wire w1097;
	wire w1098;
	wire w1099;
	wire w1100;
	wire [2:0] l626; // r
	wire [2:0] l627; // g
	wire [2:0] l628; // b
	wire l629;
	wire l630;
	wire w1101;
	wire w1102;
	wire [16:0] w1103[0:2];
	
	wire psg_clk1;
	wire psg_clk2;
	wire l631;
	wire l632;
	wire w1104;
	wire w1105;
	wire l633;
	wire l634;
	wire psg_hclk1;
	wire psg_hclk2;
	wire t43;
	wire w1106;
	wire l635;
	wire l636;
	wire l637;
	wire t44;
	wire l638;
	wire w1107;
	wire w1108;
	wire w1109;
	wire w1110;
	wire l639;
	wire w1111;
	wire w1112;
	wire w1113;
	wire w1114;
	wire w1115;
	wire [9:0] w1116;
	wire [9:0] w1117;
	wire w1118;
	wire [15:0] l640;
	wire w1119;
	wire w1120;
	wire [9:0] l641;
	wire [9:0] l642;
	wire [9:0] l643;
	wire [9:0] l644;
	wire w1121;
	wire w1122;
	wire w1123;
	wire w1124;
	wire w1125;
	wire l645;
	wire l646;
	wire l647;
	wire l648;
	wire l649;
	wire [9:0] w1126;
	wire w1127;
	wire w1128;
	wire w1129;
	wire w1130;
	wire w1131;
	wire [3:0] l650;
	wire w1132;
	wire l651;
	wire w1133;
	wire [3:0] l652;
	wire [7:0] l653;
	wire [7:0] w1134;
	wire [2:0] l654;
	wire w1135;
	wire w1136;
	wire w1137;
	wire w1138;
	wire w1139;
	wire w1140;
	wire w1141;
	wire w1142;
	wire [3:0] w1143;
	wire [3:0] l655;
	wire [3:0] l656;
	wire [3:0] l657;
	wire [3:0] l658;
	wire w1144;
	wire [9:0] l659;
	wire [9:0] l660;
	wire [9:0] l661;
	wire [2:0] l662;
	wire w1145;
	wire w1146;
	wire w1147;
	wire w1148;
	wire [3:0] w1149;
	wire [3:0] w1150;
	wire [3:0] w1151;
	wire [3:0] w1152;

	wire [14:0] reg_test0;
	wire [11:0] reg_test_18;
	wire [7:0] reg_hit;
	wire [10:0] reg_test1;
	wire reg_80_b7;
	wire reg_80_b6;
	wire reg_lcb;
	wire reg_ie1;
	wire reg_80_b3;
	wire reg_80_b2;
	wire reg_m3;
	wire reg_80_b0;
	wire reg_lsm0;
	wire reg_lsm1;
	wire reg_ste;
	wire reg_8c_b4;
	wire reg_8c_b5;
	wire reg_8c_b6;
	wire reg_rs0;
	wire reg_rs1; // h40
	wire reg_81_b0;
	wire reg_81_b1;
	// wire reg_m5;
	wire reg_m2;
	wire reg_m1;
	wire reg_ie0;
	wire reg_disp;
	wire reg_81_b7;
	wire reg_lscr;
	wire reg_hscr;
	wire reg_vscr;
	wire reg_ie2;
	wire reg_8b_b4;
	wire reg_8b_b5;
	wire reg_8b_b6;
	wire reg_8b_b7;
	wire reg_lsm0_latch;
	wire reg_lsm1_latch;
	wire [4:0] reg_code;
	wire [16:0] reg_addr;
	wire [7:0] reg_inc;
	wire [16:0] reg_data_l2;
	wire [5:0] reg_sa_high;
	wire [1:0] reg_dmd;
	wire [15:0] reg_lg;
	wire [15:0] reg_sa_low;
	
	assign reset_comb = ~(RESET & w100);
	
	reg [16:0] vram_address;
	reg [15:0] vram_data;
	wire [7:0] vram_serial;
	
	//reg [16:0] vram_address_mem;
	//reg [15:0] vram_data_mem;
	
	wire [3:0] color_index;
	wire color_priority;
	wire [1:0] color_pal;
	
	reg [10:0] vsram[0:39];
	reg [10:0] vsram_out;
	reg [10:0] vsram_out_0;
	reg [10:0] vsram_out_1;
	
	reg [20:0] sat[0:79];
	reg [20:0] sat_out;
	reg [20:0] sat_out_0;
	reg [20:0] sat_out_1;
	reg [20:0] sat_out_2;
	reg [20:0] sat_out_3;
	
	reg [33:0] sprdata[0:19];
	reg [33:0] sprdata_out;
	reg [33:0] sprdata_out_0;
	reg [33:0] sprdata_out_1;
	
	reg [55:0] linebuffer[0:39];
	reg [55:0] linebuffer_out;
	reg [55:0] linebuffer_out_0;
	reg [55:0] linebuffer_out_1;
	
	reg [8:0] color_ram[0:63];
	reg [8:0] color_ram_out;
	
	// extra
	wire [5:0] w1076_dp;
	wire [5:0] l617_dp;
	reg [8:0] color_ram_out_dp;
	
	
	// prescaler
	
	assign mclk_and1 = prescaler_dff2_l2 & ~prescaler_dff1_l2;
	
	assign mclk_clk1 = prescaler_dff4_l2;
	
	assign mclk_clk2 = prescaler_dff7_l2;
	
	assign mclk_clk3 = ~prescaler_dff11_l2;
	
	assign mclk_clk4 = prescaler_dff13_l2 | prescaler_dff14_l2;
	
	assign mclk_clk5 = prescaler_dff16_l2 | prescaler_dff17_l2;
	
	assign mclk_sbcr = PAL ? mclk_clk4 : mclk_clk5;
	
	assign mclk_cpu_clk0 = reg_test1[0] ? CLK1_i : mclk_clk5;
	
	assign mclk_dclk = (reg_rs0 | reg_test1[0]) ? EDCLK_i : (reg_rs1 ? mclk_clk1 : mclk_clk2);
	//assign mclk_dclk = reg_rs1 ? mclk_clk1 : mclk_clk2;
	
	/*
	
	assign mclk_cpu_clk1 = ~mclk_clk3;
	
	always @(posedge MCLK)
	begin
		prescaler_dff1 <= reset_comb;
		prescaler_dff2 <= prescaler_dff1;
		
		if (mclk_and1)
		begin
			prescaler_dff3 <= 1'h0;
			prescaler_dff4 <= 1'h0;
			prescaler_dff5 <= 1'h0;
			prescaler_dff6 <= 1'h0;
			prescaler_dff7 <= 1'h0;
			prescaler_dff8 <= 1'h0;
			prescaler_dff9 <= 1'h0;
			prescaler_dff10 <= 1'h0;
			prescaler_dff11 <= 1'h0;
		end
		else
		begin
			prescaler_dff3 <= prescaler_dff4;
			prescaler_dff4 <= ~prescaler_dff3;
			
			prescaler_dff5 <= prescaler_dff7;
			prescaler_dff6 <= prescaler_dff5;
			prescaler_dff7 <= ~(prescaler_dff5 & prescaler_dff6);
			
			pres<caler_dff8 <= prescaler_dff11;
			prescaler_dff9 <= prescaler_dff8;
			prescaler_dff10 <= ~(prescaler_dff8 & prescaler_dff9);
			prescaler_dff11 <= prescaler_dff10;
		end
	end*/
	
	reg mclk_clk3_l;
	
	assign mclk_cpu_clk1 = ~(mclk_clk3 | mclk_clk3_l);
	
	always @(posedge MCLK)
	begin
		mclk_clk3_l <= mclk_clk3;
	end
	
	ym7101_dff prescaler_dff1(.MCLK(MCLK), .clk(MCLK_e), .inp(reset_comb), .rst(1'h0), .outp(prescaler_dff1_l2));
	ym7101_dff prescaler_dff2(.MCLK(MCLK), .clk(MCLK_e), .inp(prescaler_dff1_l2), .rst(1'h0), .outp(prescaler_dff2_l2));
	ym7101_dff prescaler_dff3(.MCLK(MCLK), .clk(MCLK_e), .inp(prescaler_dff4_l2), .rst(mclk_and1), .outp(prescaler_dff3_l2));
	ym7101_dff prescaler_dff4(.MCLK(MCLK), .clk(MCLK_e), .inp(~prescaler_dff3_l2), .rst(mclk_and1), .outp(prescaler_dff4_l2));
	ym7101_dff prescaler_dff5(.MCLK(MCLK), .clk(MCLK_e), .inp(prescaler_dff7_l2), .rst(mclk_and1), .outp(prescaler_dff5_l2));
	ym7101_dff prescaler_dff6(.MCLK(MCLK), .clk(MCLK_e), .inp(prescaler_dff5_l2), .rst(mclk_and1), .outp(prescaler_dff6_l2));
	ym7101_dff prescaler_dff7(.MCLK(MCLK), .clk(MCLK_e), .inp(~(prescaler_dff5_l2 & prescaler_dff6_l2)), .rst(mclk_and1), .outp(prescaler_dff7_l2));
	ym7101_dff prescaler_dff8(.MCLK(MCLK), .clk(MCLK_e), .inp(prescaler_dff11_l2), .rst(mclk_and1), .outp(prescaler_dff8_l2));
	ym7101_dff prescaler_dff9(.MCLK(MCLK), .clk(MCLK_e), .inp(prescaler_dff8_l2), .rst(mclk_and1), .outp(prescaler_dff9_l2));
	ym7101_dff prescaler_dff10(.MCLK(MCLK), .clk(MCLK_e), .inp(~(prescaler_dff8_l2 & prescaler_dff9_l2)), .rst(mclk_and1), .outp(prescaler_dff10_l2));
	ym7101_dff prescaler_dff11(.MCLK(MCLK), .clk(MCLK_e), .inp(prescaler_dff10_l2), .rst(mclk_and1), .outp(prescaler_dff11_l2));
	
	ym7101_dff prescaler_dff12(.MCLK(MCLK), .clk(mclk_clk1), .inp(~(prescaler_dff12_l2 | prescaler_dff13_l2)), .rst(mclk_and1), .outp(prescaler_dff12_l2));
	ym7101_dff prescaler_dff13(.MCLK(MCLK), .clk(mclk_clk1), .inp(prescaler_dff12_l2), .rst(mclk_and1), .outp(prescaler_dff13_l2));
	ym7101_dff prescaler_dff14(.MCLK(MCLK), .clk(~mclk_clk1), .inp(prescaler_dff13_l2), .rst(mclk_and1), .outp(prescaler_dff14_l2));
	ym7101_dff prescaler_dff15(.MCLK(MCLK), .clk(mclk_clk2), .inp(~(prescaler_dff15_l2 | prescaler_dff16_l2)), .rst(mclk_and1), .outp(prescaler_dff15_l2));
	ym7101_dff prescaler_dff16(.MCLK(MCLK), .clk(mclk_clk2), .inp(prescaler_dff15_l2), .rst(mclk_and1), .outp(prescaler_dff16_l2));
	ym7101_dff prescaler_dff17(.MCLK(MCLK), .clk(~mclk_clk2), .inp(prescaler_dff16_l2), .rst(mclk_and1), .outp(prescaler_dff17_l2));
	
	assign SBCR = mclk_sbcr;
	assign CLK0 = mclk_cpu_clk0;
	assign CLK1_o = mclk_cpu_clk1;
	
	assign EDCLK_o = mclk_dclk;
	
	assign EDCLK_d = reg_test1[1];
	
	assign cpu_clk0 = mclk_cpu_clk0;
	assign cpu_clk1 = CLK1_i;
	
	// clk1, clk2
	
	
	reg dclk_l;
	reg dclk_l2;
	reg dclk_l3;
	reg dclk_l4;
	
	always @(posedge MCLK)
	begin
		dclk_l <= dclk_l2;
		dclk_l2 <= dclk_l3;
		dclk_l3 <= dclk_l4;
		dclk_l4 <= mclk_dclk;
	end
	
	assign clk1 = ~mclk_dclk & dclk_l;
	assign clk2 = mclk_dclk & ~dclk_l;
	
	/*reg dclk_l;
	reg tclk1_l;
	reg tclk2_l;
	
	wire tclk1 = ~mclk_dclk & dclk_l;
	wire tclk2 = mclk_dclk & ~dclk_l;
	
	always @(posedge MCLK)
	begin
		dclk_l <= mclk_dclk;
		tclk1_l <= tclk1;
		tclk2_l <= tclk2;
	end
	
	assign clk1 = tclk1 | tclk1_l;
	assign clk2 = tclk2 | tclk2_l;*/
	
	
	// hclk1, hclk2 (half clock)
	
	wire reset_l1_o;
	wire reset_l2_o;
	wire reset_pulse = reset_l1_o & ~reset_l2_o;
	ym_sr_bit reset_l1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(~reset_comb), .sr_out(reset_l1_o)); // static latch
	ym_sr_bit reset_l2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(reset_l1_o), .sr_out(reset_l2_o));
	
	wire dclk_prescaler_l1_o;
	wire dclk_prescaler_l2_o;
	wire dclk_prescaler_l3_o;
	wire dclk_prescaler_dff1_l2;
	wire dclk_prescaler_dff2_l2;
	assign hclk1 = ~dclk_prescaler_dff1_l2;
	assign hclk2 = ~dclk_prescaler_dff2_l2;
	ym_sr_bit dclk_prescaler_l1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(~(dclk_prescaler_l1_o | reset_pulse)), .sr_out(dclk_prescaler_l1_o));
	ym_dlatch_1 dclk_prescaler_l2(.MCLK(MCLK), .c1(clk1), .inp(dclk_prescaler_l1_o), .val(dclk_prescaler_l2_o));
	ym_dlatch_1 dclk_prescaler_l3(.MCLK(MCLK), .c1(clk1), .inp(~dclk_prescaler_l1_o), .val(dclk_prescaler_l3_o));
	ym7101_dff dclk_prescaler_dff1(.MCLK(MCLK), .clk(~clk1), .inp(1'h1), .rst(dclk_prescaler_l2_o & clk2), .outp(dclk_prescaler_dff1_l2));
	ym7101_dff dclk_prescaler_dff2(.MCLK(MCLK), .clk(~clk1), .inp(1'h1), .rst(dclk_prescaler_l3_o & clk2), .outp(dclk_prescaler_dff2_l2));
	
	// IO, DMA/FIFO block
	
	assign cpu_sel = SEL0;
	assign cpu_as = ~AS & cpu_sel;
	assign cpu_uds = ~UDS & cpu_sel;
	assign cpu_lds = ~LDS & cpu_sel;
	assign cpu_m1 = ~M1 & ~cpu_sel;
	assign cpu_rd = ~RD & ~cpu_sel;
	assign cpu_wr = ~WR & ~cpu_sel;
	assign cpu_mreq = ~MREQ & ~cpu_sel;
	assign cpu_iorq = ~IORQ & ~cpu_sel;
	assign cpu_rw = ~RW;
	assign cpu_bg = ~BG;
	assign cpu_intak = ~INTAK;
	assign cpu_bgack = BGACK_i;
	assign cpu_pal = PAL;
	assign cpu_pen = HL;
	
	ym7101_dff io_m1_dff1(.MCLK(MCLK), .clk(cpu_clk0), .inp(cpu_m1), .rst(1'h0), .outp(io_m1_dff1_l2));
	ym7101_dff io_m1_dff2(.MCLK(MCLK), .clk(cpu_clk0), .inp(io_m1_dff1_l2), .rst(1'h0), .outp(io_m1_dff2_l2));
	ym7101_dff io_m1_dff3(.MCLK(MCLK), .clk(~cpu_clk0), .inp(io_m1_dff2_l2), .rst(1'h0), .outp(io_m1_dff3_l2));
	
	assign io_m1_s1 = io_m1_dff3_l2 & io_m1_dff2_l2;
	assign io_m1_s2 = ~io_m1_s1 & io_m1_s4;
	ym7101_dff io_m1_dff4(.MCLK(MCLK), .clk(~cpu_clk0), .inp(io_m1_s2), .rst(1'h0), .outp(io_m1_dff4_l2));
	
	assign io_m1_s3 = io_m1_dff4_l2 & io_m1_s2;
	
	assign io_m1_s4 = cpu_mreq & (io_m1_s1 | ( &io_address[15:14]));
	
	assign io_m1_s5 = io_m1_s4 & io_m1_s1;
	
	assign io_oe0 = io_m1_s5 | w25 | w27 | w118 | l8;
	
	assign w1153  = w1 & ~w2;
	
	assign io_cas0 = reg_8b_b6 ?
		(io_m1_dff2_l2 | w15 | w28 | w30 | w102) :
		(l8 | w25 | w1153);
	
	assign io_ras0 = reg_8b_b6 ?
		(io_m1_s4 | w21 | w14 | w27) :
		(io_m1_s2 | w22 | w16);
	
	assign io_wr = cpu_rw & dff1_l2;
	
	assign io_lwr = cpu_wr | (cpu_lds & io_wr);
	assign io_uwr = cpu_uds & io_wr;
	
	assign w1 = ~cpu_rw & (cpu_uds | cpu_lds);
	ym7101_dff dff1(.MCLK(MCLK), .clk(~cpu_clk1), .inp(w23), .rst(1'h0), .outp(dff1_l2));
	
	ym7101_dff dff2(.MCLK(MCLK), .clk(cpu_clk1), .inp(cpu_bg), .rst(1'h0), .outp(dff2_l2));
	
	ym7101_rs_trig rs1(.MCLK(MCLK), .set(cpu_bg | reset_comb), .rst(~reg_data_l2[7] & w227 & reg_m5), .q(t1));
	
	assign w2 = w35 & (&io_address[22:20]);
	
	assign io_address_22o = ~(l4 & w247 & (l6 | ~l7));
	
	ym7101_dff dff4(.MCLK(MCLK), .clk(hclk2), .inp(w3), .rst(w4), .outp(dff4_l2));
	ym7101_dff dff3(.MCLK(MCLK), .clk(hclk2), .inp(dff4_l2), .rst(w4), .outp(dff3_l2));
	
	assign w3 = t2 | t3;
	
	assign w4 = reset_comb | l48;
	
	ym7101_rs_trig rs2(.MCLK(MCLK), .set(w63), .rst(w4), .q(t2));
	ym7101_rs_trig rs3(.MCLK(MCLK), .set(w5), .rst(w4), .q(t3));
	ym7101_rs_trig rs4(.MCLK(MCLK), .set(w62), .rst(w4 | w5), .q(t4));
	
	assign w5 = dff22_l2 & cpu_bgack & DTACK_i & dff2_l2 & cpu_sel & w37;
	
	assign io_ipl1 = ~(w11 & cpu_sel);
	assign io_ipl2 = ~(w12 & cpu_sel);
	
	ym_sr_bit sr1(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l108), .sr_out(l1));
	ym_sr_bit sr2(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l1), .sr_out(l2));
	ym_sr_bit sr3(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l2), .sr_out(l3));
	ym_sr_bit sr4(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(~(l108 | l1 | l2 | l3)), .sr_out(l4));
	ym_sr_bit sr5(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w267), .sr_out(l5));
	ym_dlatch_1 dl6(.MCLK(MCLK), .c1(hclk1), .inp(~(w7 & w8 & l116)), .nval(l6));
	ym_dlatch_1 dl7(.MCLK(MCLK), .c1(clk1), .inp(l6), .nval(l7));
	ym_dlatch_2 dl8(.MCLK(MCLK), .c2(clk2), .inp(l7), .nval(l8));
	
	assign w6 = ~(l1 | l3);
	assign w7 = ~(w6 & w252);
	
	assign w8 = l5 & w267;
	
	assign w9 = w58 | w57 | w60;
	assign w10 = ~dff13_l2;
	
	assign w11 = w58 | w60;
	assign w12 = w57 | w60;
	
	assign w13 = l4 & w246;
	
	assign w14 = ~l7 | (l6 & w13);
	
	assign w15 = (~l4 & l6) | (l8 & w13);
	
	assign w16 = (~l7 & w13) | (l8 & w13);
	
	// assign w17 = l2 & l8;
	
	assign w18 = w267 & l4 & l8;
	
	assign w19 = w29 & w34;
	
	assign w20 = w34 & dff7_l2;
	
	assign w21 = w34 & w26;
	
	assign w22 = w10 ? w21 : w20;
	
	assign w23 = ~((w10 & w30) | (dff5_l2 & w34));
	
	assign w24 = w34 & (dff6_l2 | (dff11_l2 & w10));
	
	assign w25 = cpu_rd & l17;
	
	ym7101_dff dff5(.MCLK(MCLK), .clk(~cpu_clk1), .inp(dff6_l2), .rst(w10), .outp(dff5_l2));
	ym7101_dff dff6(.MCLK(MCLK), .clk(cpu_clk1), .inp(dff7_l2), .rst(w10), .outp(dff6_l2));
	
	assign w26 = ~(~dff6_l2 & dff8_l2);
	
	ym7101_dff dff7(.MCLK(MCLK), .clk(~cpu_clk1), .inp(dff8_l2), .rst(w10), .outp(dff7_l2));
	
	assign w27 = dff17_l2 & ~dff19_l2;
	
	assign w28 = dff16_l2 & ~dff19_l2;
	
	ym7101_dff dff8(.MCLK(MCLK), .clk(~cpu_clk1), .inp(dff9_l2), .rst(w10), .outp(dff8_l2));
	
	ym7101_dff dff9(.MCLK(MCLK), .clk(cpu_clk1), .inp(w30), .rst(w10), .outp(dff9_l2));
	
	assign w29 = ~(w10 | dff9_l2);
	
	assign w30 = w34 & dff10_l2;
	
	always @(posedge MCLK) w31 <= reset_comb | dff21_l2 | dff13_l2;
	
	ym7101_dff dff10(.MCLK(MCLK), .clk(~cpu_clk1), .inp(dff11_l2), .rst(w33), .outp(dff10_l2));
	ym7101_dff dff11(.MCLK(MCLK), .clk(cpu_clk1), .inp(w36), .rst(w33), .outp(dff11_l2));
	
	assign w32 = dff11_l2 & w1;
	
	assign w33 = ~w36;
	
	assign w34 = w2 & w36;
	
	assign w35 = ~cpu_intak;
	
	assign w36 = cpu_as & w40;
	
	assign w37 = ~cpu_as;
	
	ym7101_dff dff12(.MCLK(MCLK), .clk(w37), .inp(1'h1), .rst(w10), .outp(dff12_l2));
	
	always @(posedge MCLK) w38 <= dff12_l2 | reset_comb;
	
	ym7101_dff dff13(.MCLK(MCLK), .clk(w34), .inp(w44), .rst(w38), .outp(dff13_l2));
	
	ym7101_dff dff14(.MCLK(MCLK), .clk(cpu_clk1), .inp(w43), .rst(1'h0), .outp(dff14_l2));
	
	ym7101_dff dff15(.MCLK(MCLK), .clk(dff14_l2), .inp(w44), .rst(w31), .outp(dff15_l2));
	
	assign w39 = ~dff15_l2;
	
	assign w40 = w39 | dff21_l2;
	
	assign w41 = ~(~dff21_l2 & cpu_sel & w26);
	
	ym7101_dff dff16(.MCLK(MCLK), .clk(cpu_clk1), .inp(1'h1), .rst(w39), .outp(dff16_l2));
	ym7101_dff dff17(.MCLK(MCLK), .clk(cpu_clk1), .inp(dff16_l2), .rst(w39), .outp(dff17_l2));
	ym7101_dff dff18(.MCLK(MCLK), .clk(cpu_clk1), .inp(dff17_l2), .rst(w39), .outp(dff18_l2));
	ym7101_dff dff19(.MCLK(MCLK), .clk(~cpu_clk1), .inp(dff18_l2), .rst(w39), .outp(dff19_l2));
	ym7101_dff dff20(.MCLK(MCLK), .clk(cpu_clk1), .inp(dff19_l2), .rst(w39), .outp(dff20_l2));
	
	ym7101_dff dff21(.MCLK(MCLK), .clk(cpu_clk1), .inp(dff20_l2), .rst(1'h0), .outp(dff21_l2));
	
	ym7101_dff dff22(.MCLK(MCLK), .clk(cpu_clk1), .inp(t4), .rst(1'h0), .outp(dff22_l2));
	
	assign w42 = ~(dff22_l2 & cpu_sel);
	
	wire [6:0] i_sum = {6'h0, w64} + { dff29_l2, dff28_l2, dff27_l2, dff26_l2, dff25_l2, dff24_l2, dff23_l2 };
	
	ym7101_dff dff23(.MCLK(MCLK), .clk(cpu_clk1), .inp(i_sum[0]), .rst(w41), .outp(dff23_l2));
	ym7101_dff dff24(.MCLK(MCLK), .clk(cpu_clk1), .inp(i_sum[1]), .rst(w41), .outp(dff24_l2));
	ym7101_dff dff25(.MCLK(MCLK), .clk(cpu_clk1), .inp(i_sum[2]), .rst(w41), .outp(dff25_l2));
	ym7101_dff dff26(.MCLK(MCLK), .clk(cpu_clk1), .inp(i_sum[3]), .rst(w41), .outp(dff26_l2));
	ym7101_dff dff27(.MCLK(MCLK), .clk(cpu_clk1), .inp(i_sum[4]), .rst(w41), .outp(dff27_l2));
	ym7101_dff dff28(.MCLK(MCLK), .clk(cpu_clk1), .inp(i_sum[5]), .rst(w41), .outp(dff28_l2));
	ym7101_dff dff29(.MCLK(MCLK), .clk(cpu_clk1), .inp(i_sum[6]), .rst(w41), .outp(dff29_l2));
	
	assign w43 = dff25_l2 & dff24_l2 & dff26_l2 & w44;
	
	assign w44 = dff28_l2 & dff27_l2 & dff29_l2;
	
	assign w45 = cpu_as & cpu_intak;
	
	assign w46 = w45 | w47;
	
	assign w47 = cpu_m1 & cpu_iorq;
	
	ym7101_rs_trig rs5(.MCLK(MCLK), .set(w46), .rst(l9), .q(t5));
	
	assign w48 = t5 & reg_m5;
	
	ym_sr_bit sr9(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w48), .sr_out(l9));
	ym_dlatch_1 dl10(.MCLK(MCLK), .c1(clk1), .inp(l9), .nval(l10));
	ym_dlatch_2 dl11(.MCLK(MCLK), .c2(clk2), .inp(l10), .nval(l11));
	
	assign w49 = reset_comb | (l11 & l10);
	
	assign w50 = reset_comb | w114;
	
	ym7101_rs_trig rs6(.MCLK(MCLK), .set(w50), .rst(l13), .q(t6));
	
	ym_sr_bit sr12(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(t6), .sr_out(l12));
	
	assign w51 = ~(l12 | reset_comb);
	
	ym_sr_bit sr13(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l12), .sr_out(l13));
	
	assign w52 = ~(l13 & w51);
	
	ym_dlatch_1 dl14(.MCLK(MCLK), .c1(hclk1), .inp(w52), .nval(l14));
	
	assign w53 = l14 & ~reg_m5;
	
	assign w54 = w53 | dff30_l2;
	
	ym7101_dff dff30(.MCLK(MCLK), .clk(~w48), .inp(w58), .rst(w49), .outp(dff30_l2));
	
	ym7101_dff dff31(.MCLK(MCLK), .clk(~w48), .inp(w57), .rst(w49), .outp(dff31_l2));
	
	assign w55 = w53 | dff31_l2;
	
	ym7101_dff dff32(.MCLK(MCLK), .clk(~w48), .inp(w60), .rst(w49), .outp(dff32_l2));
	
	assign w56 = w53 | dff32_l2;
	
	assign w57 = t7 & ~w60 & reg_ie1;
	
	assign w58 = ~w57 & ~w60 & t8 & reg_ie2;
	
	ym7101_rs_trig rs7(.MCLK(MCLK), .set(l15), .rst(w55), .q(t7));
	
	ym7101_rs_trig rs8(.MCLK(MCLK), .set(w59), .rst(w54), .q(t8));
	
	assign w59 = reg_m5 & l81;
	
	assign w60 = t9 & reg_ie0;
	
	assign w61 = reg_m1 & reg_m5;
	
	assign w62 = w61 & ~reg_dmd[1] & w182;
	
	assign w63 = w61 & w182 & reg_dmd[1];
	
	assign w64 = ~t3;
	
	assign w65 = ~(~reg_m5 | io_address[1] | cpu_sel);
	
	assign w66 = ~t9 & w1154;
	
	ym7101_rs_trig rs9(.MCLK(MCLK), .set(w120), .rst(w56), .q(t9));
	
	ym7101_rs_trig rs10(.MCLK(MCLK), .set(w66), .rst(l14), .q(t10));
	
	ym7101_rs_trig rs11(.MCLK(MCLK), .set(l600), .rst(l14), .q(t11));
	
	assign w67 = l115 | reg_test0[3];
	
	assign w68 = ~(t38 | l162 | reg_test0[3]);
	
	wire cnt1_of;
	
	ym_cnt_bit_load #(.DATA_WIDTH(8)) cnt1(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(w67), .reset(1'h0), .load(w69), .load_val(reg_hit), .c_out(cnt1_of));
		
	assign w69 = w68 | l15;
	
	ym_sr_bit sr15(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(cnt1_of & ~w68), .sr_out(l15));
	
	assign cs = cpu_sel & (io_address & 23'h738070) == 23'h600000;
	
	assign w71 = ~cpu_sel & reg_test0[2] & w142;

	assign w72 = w65 ? w252 : cpu_pal;
	
	assign w73 = w65 ? l46 : dff3_l2;
	
	assign w74 = reg_test_18[11:8] == 4'hf;
	assign w75 = reg_test_18[11:8] == 4'h8;
	assign w76 = reg_test_18[11:8] == 4'h7;
	assign w77 = reg_test_18[11:8] == 4'h6;
	assign w78 = reg_test_18[11:8] == 4'h5;
	assign w79 = reg_test_18[11:8] == 4'h4;
	assign w80 = reg_test_18[11:8] == 4'h3;
	assign w81 = reg_test_18[11:8] == 4'h2;
	assign w82 = reg_test_18[11:8] == 4'h1;
	assign w83 = reg_test_18[11:8] == 4'h0;
	
	assign w84 = w83 & w129;
	assign w85 = w82 & w129;
	assign w86 = w81 & w129;
	assign w87 = w81 & w135;
	assign w88 = w80 & w129;
	assign w89 = w80 & w135;
	assign w90 = w79 & w129;
	assign w91 = w79 & w135;
	assign w92 = w78 & w129;
	assign w93 = w78 & w135;
	assign w94 = w77 & w129;
	assign w95 = w77 & w135;
	assign w96 = w76 & w129;
	assign w97 = w76 & w135;
	assign w98 = w75 & w129;
	assign w99 = w75 & w135;
	assign w100 = ~(w74 & w129);
	
	assign w101 = w16 | dff11_l2 | io_m1_s3;
	
	assign w102 = io_m1_s3 & w104;
	
	assign w103 = reg_8b_b7 ? l16 : (w101 ? 
		{ io_address[15], io_address[13], io_address[12], io_address[11],
			io_address[10], io_address[9], io_address[8], io_address[14] } :
			io_address[7:0]);
	
	assign w104 = reg_8b_b7 ? 1'h1 : (w101 ? 1'h1 : 1'h0);
	
	ym_dlatch_1 #(.DATA_WIDTH(8)) dl16(.MCLK(MCLK), .c1(hclk1), .inp({ w1070, w105, color_pal, color_index}), .val(l16));
	
	assign w105 = reg_test0[0] ? color_priority : w1069;
	
	assign w106 = reg_lsm0_latch & reg_lsm1_latch;
	
	assign w107 = ~reg_m2 & reg_m5;
	assign w108 = reg_m2 & reg_m5;
	assign w109 = reg_m5 & reg_81_b7;
	
	assign w110 = io_address[7:6] == 2'h1 & cpu_iorq & cpu_wr; // z80 psg
	assign w111 = w110 | (w133 & cpu_lds);
	
	assign w112 = io_address[7:6] == 2'h2 & cpu_iorq & cpu_rd;
	assign w113 = w112 | w132;
	assign w114 = w113 & w130;
	
	assign w115 = reg_8b_b6 & w30;
	assign w116 = w115 | w24;
	
	assign dtack_pull_n = ~(w24 | w125 | w128 | w129 | w133); // dtack
	
	assign w118 = (w1 & 1'h0) | (w32 & w116) | w19;
	
	ym_slatch sl17(.MCLK(MCLK), .en(cpu_clk0), .inp(cpu_rd), .val(l17));
	
	assign w119 = cpu_sel ? l110 : l115;
	
	assign w120 = w119 & w457;
	
	assign w121 = reset_comb | w360;
	
	ym7101_rs_trig rs12(.MCLK(MCLK), .set(w120), .rst(w121), .q(t12));
	
	assign w122 = ~(cpu_sel ? t12 : w9); // z80 int
	
	assign w123 = reg_lsm0_latch ? w355[8] : w355[0];
	
	assign w124 = cs & cpu_as & w158;
	
	assign w125 = cpu_sel & (w126 | w127 | w137 | w164 | w165);
	
	assign w126 = w152 & w162;
	
	assign w127 = w148 & w169;
	
	assign w128 = w124 & cpu_rw & io_address[3:2] == 2'h3 & ~w130; // test address
	
	assign w129 = w124 & cpu_rw & io_address[3:2] == 2'h3 & w130;
	
	assign w130 = cpu_sel ? io_address[1] : io_address[0];
	
	assign w131 = w124 & cpu_rw & io_address[3:2] == 2'h0 & w147;
	
	assign w132 = w124 & ~cpu_rw & io_address[3:2] == 2'h0 & w147;
	
	assign w133 = w124 & cpu_rw & io_address[3:2] == 2'h2;
	
	assign w134 = w124 & ~cpu_rw & io_address[3:2] == 2'h1;
	
	assign w135 = w124 & ~cpu_rw & io_address[3:2] == 2'h3;
	
	ym7101_rs_trig rs13(.MCLK(MCLK), .set(w163), .rst(w159), .q(t13));
	
	assign w136 = l48 | reset_comb;
	
	assign w137 = t1 & t14 & w168;
	
	ym7101_rs_trig rs14(.MCLK(MCLK), .set(w138), .rst(w143), .q(t14));
	
	assign w138 = reset_comb | l82;
	
	assign w139 = w131 | w140;
	
	assign w140 = cpu_iorq & cpu_wr & io_address[7:6] == 2'h2;
	
	assign w141 = cpu_iorq & cpu_rd & io_address[7:6] == 2'h1;
	
	assign w142 = w141 | w134; // HV cnt read
	
	ym_slatch sl18(.MCLK(MCLK), .en(~w139), .inp(w130), .val(l18));
	
	ym_slatch sl19(.MCLK(MCLK), .en(~w113), .inp(w130), .val(l19));
	
	assign w143 = ~l19 & w113;
	
	ym7101_rs_trig rs15(.MCLK(MCLK), .set(w173), .rst(w172), .q(t15), .nq(t15_n));
	
	ym7101_rs_trig rs16(.MCLK(MCLK), .set(w166), .rst(w174), .q(t16), .nq(t16_n));
	
	ym7101_rs_trig rs17(.MCLK(MCLK), .set(w175), .rst(w155), .q(t17));
	
	assign w144 = (t17 & w154) | reset_comb;
	
	assign w145 = w154 & t25 & w192 & reg_m5;
	
	ym7101_rs_trig rs18(.MCLK(MCLK), .set(w145), .rst(w144), .q(t18), .nq(t18_n));

	ym7101_rs_trig rs19(.MCLK(MCLK), .set(cpu_uds), .rst(w183), .q(t19));
	
	ym7101_rs_trig rs20(.MCLK(MCLK), .set(cpu_lds), .rst(w183), .q(t20));
	
	assign w147 = cpu_uds | cpu_lds;
	
	assign w148 = ~(w150 | w252);
	
	assign w149 = t21 & w154;
	
	ym7101_rs_trig rs21(.MCLK(MCLK), .set(w169), .rst(w183), .q(t21));
	
	assign w150 = t21 & w153;
	
	assign cdd_n = w152 | w47;
	
	assign w152 = w113 | w135 | w142;
	
	assign w153 = l22 & ~l24;
	
	assign w154 = ~l24 & ~l23;
	
	assign w155 = l22 & l23;
	
	assign w156 = l27 | w136;
	
	assign w157 = w180 & l28;
	
	assign w158 = t13 | l23;
	
	assign w159 = l24 | reset_comb;
	
	assign w160 = w113 & ~w130;
	
	assign w161 = w154 | reset_comb;
	
	ym7101_rs_trig rs22(.MCLK(MCLK), .set(w161), .rst(l82), .q(t22));
	
	assign w162 = ~(t22 & w160);
	
	assign w163 = w113 | w139;
	
	assign w164 = (cpu_sel & w165) | w167;
	
	assign w165 = w139 & t18_n & t15_n & l18;
	
	assign w166 = w165 & ~cpu_sel;
	
	assign w167 = l18 & w140 & t15;
	
	assign w168 = w139 & t15_n & l18 & t18 & reg_m5;
	
	assign w169 = ~l18 & w139;
	
	assign w170 = w164 | w169 | w160 | w168 | w114;
	
	ym7101_rs_trig rs23(.MCLK(MCLK), .set(w168), .rst(w176), .q(t23));
	
	ym7101_rs_trig rs24(.MCLK(MCLK), .set(w143), .rst(w176), .q(t24));
	
	assign w171 = w160 | w169 | w168 | w114;
	
	assign w172 = (t16_n & w154) | reset_comb;
	
	assign w173 = w154 & t16;
	
	assign w174 = reset_comb | w170;
	
	assign w175 = reset_comb | w171;
	
	ym7101_rs_trig rs25(.MCLK(MCLK), .set(w164), .rst(w176), .q(t25));
	
	assign w176 = reset_comb | w155;
	
	assign w177 = ~(w201 | w202);
	
	assign w178 = w202 & ~reg_test0[4];
	
	assign w179 = w202 & reg_test0[4];
	
	assign w180 = w245 | w346;
	
	ym_dlatch_1 dl20(.MCLK(MCLK), .c1(clk1), .inp(w18), .val(l20));
	
	assign w181 = l20 | w164 | w168 | w191 | w261;
	
	assign w182 = w168 & io_data[7];
	
	assign w183 = (l21 & ~l22) | reset_comb;
	
	assign w184 = ~(l23 | l25);
	
	ym_dlatch_1 dl21(.MCLK(MCLK), .c1(clk1), .inp(~l22), .nval(l21));
	ym_dlatch_2 dl22(.MCLK(MCLK), .c2(clk2), .inp(l23), .nval(l22));
	ym_dlatch_1 dl23(.MCLK(MCLK), .c1(clk1), .inp(l24), .nval(l23));
	
	ym_slatch dl24(.MCLK(MCLK), .en(clk2), .inp(l25), .val(l24));
	ym_slatch dl25(.MCLK(MCLK), .en(clk1), .inp(t13), .val(l25));
	
	ym_dlatch_1 dl26(.MCLK(MCLK), .c1(hclk1), .inp(w191), .nval(l26));
	
	assign w185 = l26 & l24;
	
	ym7101_rs_trig rs26(.MCLK(MCLK), .set(w157), .rst(w156), .q(t26), .nq(t26_n));
	
	assign w186 = t26 & l46 & l109;
	
	ym_sr_bit sr27(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w186), .sr_out(l27));
	
	assign w187 = l27 & w245;
	
	assign w188 = ~w245 & l27;
	
	assign w189 = l28 | w188;
	
	assign w190 = l28 & ~w245;
	
	assign w191 = w190 | w187 | l50;
	
	assign w192 = reg_code[1:0] != 2'h2;
	
	assign w193 = ~(~w192 & w184 & t25);
	
	assign w194 = ~(t24 | t23 | (t25 & ~reg_m5));
	
	assign w195 = l28 & w245;
	
	ym_sr_bit sr28(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w196), .sr_out(l28));
	
	assign w196 = t26_n & t27 & l46 & l109;
	
	ym7101_rs_trig rs27(.MCLK(MCLK), .set(w198), .rst(w197), .q(t27));
	
	assign w197 = l28 | w136;
	
	assign w198 = w199 | w200 | w203;
	
	assign w199 = w245 & reg_code[4];
	
	assign w200 = ~((reg_code[4] | reg_code[1] | reg_code[0]) | w194 | ~w154);
	
	assign w201 = w189 & reg_code[3:2] == 2'h1;
	
	assign w202 = w189 & reg_code[3:2] == 2'h2;
	
	ym_sr_bit sr29(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w177), .sr_out(l29));
	
	ym_sr_bit sr30(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l29), .sr_out(l30));
	
	assign w203 = w154 & t24 & ~reg_m5;
	
	assign w204 = reset_comb | ~reg_m5;
	
	ym_dlatch_2 dl31(.MCLK(MCLK), .c2(hclk2), .inp(l34), .nval(l31));
	
	ym_dlatch_2 dl32(.MCLK(MCLK), .c2(clk2), .inp(w193), .nval(l32));
	
	ym_sr_bit sr33(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l32), .sr_out(l33));
	
	ym_dlatch_2 dl34(.MCLK(MCLK), .c2(clk1), .inp(l32 | l33), .nval(l34));
	
	assign w205 = l31 & hclk1;
	
	assign w206 = w205 & reg_data_l2[12:11] == 2'h0;
	assign w207 = w205 & reg_data_l2[12:11] == 2'h1;
	assign w208 = w205 & reg_data_l2[12:11] == 2'h2 & reg_m5;
	assign w209 = w205 & reg_data_l2[12:11] == 2'h1 & reg_m5;
	
	assign w210 = (w209 & reg_data_l2[10:8] == 3'h7) | reset_comb; // 8f
	assign w211 = (w208 & reg_data_l2[10:8] == 3'h3) | reset_comb; // 93
	assign w212 = (w208 & reg_data_l2[10:8] == 3'h4) | reset_comb; // 94
	assign w213 = (w209 & reg_data_l2[10:8] == 3'h3) | reset_comb; // 8b
	assign w214 = (w208 & reg_data_l2[10:8] == 3'h6) | reset_comb; // 96
	assign w215 = (w209 & reg_data_l2[10:8] == 3'h4) | reset_comb; // 8c
	assign w216 = (w206 & reg_data_l2[10:8] == 3'h0) | reset_comb; // 80
	assign w217 = (w206 & reg_data_l2[10:8] == 3'h1) | reset_comb; // 81
	assign w218 = (w206 & reg_data_l2[10:8] == 3'h2) | reset_comb; // 82
	assign w219 = (w206 & reg_data_l2[10:8] == 3'h3) | reset_comb; // 83
	assign w220 = (w206 & reg_data_l2[10:8] == 3'h4) | reset_comb; // 84
	assign w221 = (w206 & reg_data_l2[10:8] == 3'h7) | reset_comb; // 87
	assign w222 = (w208 & reg_data_l2[10:8] == 3'h2) | reset_comb; // 92
	assign w223 = (w208 & reg_data_l2[10:8] == 3'h1) | reset_comb; // 91
	assign w224 = (w208 & reg_data_l2[10:8] == 3'h0) | reset_comb; // 90
	assign w225 = (w206 & reg_data_l2[10:8] == 3'h6) | reset_comb; // 86
	assign w226 = (w206 & reg_data_l2[10:8] == 3'h5) | reset_comb; // 85
	assign w227 = (w208 & reg_data_l2[10:8] == 3'h7) | reset_comb; // 97
	assign w228 = (w208 & reg_data_l2[10:8] == 3'h5) | reset_comb; // 95
	assign w229 = (w207 & reg_data_l2[10:8] == 3'h2) | reset_comb; // 8a
	assign w230 = (w207 & reg_data_l2[10:8] == 3'h1) | reset_comb; // 89
	assign w231 = (w207 & reg_data_l2[10:8] == 3'h0) | reset_comb; // 88
	assign w232 = (w209 & reg_data_l2[10:8] == 3'h6) | reset_comb; // 8e
	assign w233 = (w209 & reg_data_l2[10:8] == 3'h5) | reset_comb; // 8d
	
	assign w234 = w250 & reg_test0[1];
	
	assign w235 = w250 & ~reg_test0[1];
	
	ym_slatch #(.DATA_WIDTH(17)) sl35(.MCLK(MCLK), .en(w299), .inp(vram_address), .val(l35));
	ym_slatch #(.DATA_WIDTH(17)) sl36(.MCLK(MCLK), .en(w294), .inp(reg_data_l2), .val(l36));
	ym_slatch #(.DATA_WIDTH(17)) sl37(.MCLK(MCLK), .en(w293), .inp(reg_data_l2), .val(l37));
	ym_slatch #(.DATA_WIDTH(17)) sl38(.MCLK(MCLK), .en(w292), .inp(reg_data_l2), .val(l38));
	ym_slatch #(.DATA_WIDTH(17)) sl39(.MCLK(MCLK), .en(w291), .inp(reg_data_l2), .val(l39));
	
	assign w244 = reg_lg == 16'hfffe & w250;
	
	assign w245 = dff3_l2 & reg_dmd == 2'h3;
	assign w246 = dff3_l2 & reg_dmd == 2'h1;
	assign w247 = dff3_l2 & reg_dmd == 2'h0;
	assign w248 = dff3_l2 & reg_dmd == 2'h2;
	
	ym_sr_bit sr40(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w18), .sr_out(l40));
	
	assign w249 = l40 & w18;
	
	ym_dlatch_2 dl41(.MCLK(MCLK), .c2(hclk2), .inp(w18), .val(l41));
	
	assign w250 = w187 | l50 | l41;
	
	wire reg_lg_of;
	
	assign w251 = reg_lg_of | w234;
	
	ym_sr_bit sr42(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w264), .sr_out(l42));
	
	assign w252 = (~reset_comb & w295 & l43) | (~reset_comb & w295 & l42);
	
	ym_sr_bit sr43(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w252), .sr_out(l43));
	
	ym_sr_bit sr44(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l49), .sr_out(l44));
	
	ym_sr_bit sr45(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l44), .sr_out(l45));
	
	assign w253 = l44 & ~l45 & ~l52;
	
	assign w254 = reset_comb | (l46 & w295) | (w295 & w253);
	
	wire reg_sa_of;
	
	assign w255 = reg_sa_of | w234;
	
	ym_sr_bit sr46(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w254), .sr_out(l46));
	
	assign w256 = l49 & ~l52;
	
	assign w257 = w256 & l53 & ~l54;
	assign w258 = w256 & ~l53 & ~l54;
	assign w259 = w256 & l53 & l54;
	assign w260 = w256 & ~l53 & l54;
	
	assign w261 = w149 | 1'h0;
	
	// assign w262 = w248 & w300;
	
	assign w263 = w248 & l46;
	
	assign w264 = w249 | w150;
	
	assign w265 = w245 & l46;
	
	ym_slatch sl47(.MCLK(MCLK), .en(w266), .inp(vram_address[0]), .val(l47));
	
	assign w266 = hclk1 & l116;
	
	assign w267 = w247 | w246;
	
	ym_sr_bit sr48(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w244), .sr_out(l48));
	
	assign w268 = ~w265 & l116;
	
	assign w269 = l109 & ~l46;
	
	ym_sr_bit sr49(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w269), .sr_out(l49));
	
	assign w270 = reset_comb | l48;
	
	assign w271 = dff3_l2 & l49;
	
	ym7101_rs_trig rs28(.MCLK(MCLK), .set(w271), .rst(w270), .q(t28));
	
	ym_sr_bit sr50(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w272), .sr_out(l50));
	
	assign w272 = t28 & w263 & l109;
	
	assign w273 = w274 & w325;
	
	assign w274 = ~w109 & cpu_sel;
	
	assign w275 = w188 | w300;
	
	assign w276 = dff3_l2 | t19;
	
	assign w277 = cpu_sel ? w276 : w280;
	
	assign w278 = dff3_l2 | t20;
	
	assign w279 = cpu_sel ? w278 : ~w280;
	
	assign w280 = reg_data_l2[0] & reg_m5;
	
	assign w281 = w187 & (w109 | vram_address[0]);
	
	assign w282 = w187 & (w109 | ~vram_address[0]);
	
	assign w283 = w281 | (w289 & w317);
	
	assign w284 = w282 | (w289 & w319);
	
	assign w285 = w319 | ~w109;
	
	assign w286 = w187 | (w289 & w285);
	
	assign w287 = w109 & w317;
	
	assign w288 = w187 | (w287 & w289);
	
	assign w289 = w301 & ~w316 & ~w318 & ~w320;
	
	assign w290 = w149 | (w249 & clk1);
	
	ym_cnt_bit #(.DATA_WIDTH(2)) cnt2(.MCLK(MCLK), .c1(clk1), .c2(clk2),
		.c_in(w264), .reset(reset_comb), .val(l51));
	
	assign w291 = w290 & l51 == 2'h2;
	assign w292 = w290 & l51 == 2'h3;
	assign w293 = w290 & l51 == 2'h0;
	assign w294 = w290 & l51 == 2'h1;
	
	assign w295 = l54 == l51[1] & l53 == l51[0]; //l51 == { l54, l53 };
	
	assign w296 = l49 & w305;
	assign w297 = l49 & ~w305;
	
	wire [2:0] l52_sum = reset_comb ? 3'h0 : ({l54, l53, l52} + { 1'h0, w297, w296 });
	
	ym_sr_bit sr52(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l52_sum[0]), .sr_out(l52));
	ym_sr_bit sr53(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l52_sum[1]), .sr_out(l53));
	ym_sr_bit sr54(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l52_sum[2]), .sr_out(l54));
	
	assign w298 = ~(l52 | w188);
	
	assign w299 = hclk1 & (w191 | (l49 & w298));
	
	assign w300 = w273 & l49 & l52;
	
	ym_slatch sl55(.MCLK(MCLK), .en(w292), .inp(w277), .val(l55));
	ym_slatch sl56(.MCLK(MCLK), .en(w291), .inp(w277), .val(l56));
	ym_slatch sl57(.MCLK(MCLK), .en(w294), .inp(w277), .val(l57));
	ym_slatch sl58(.MCLK(MCLK), .en(w293), .inp(w277), .val(l58));
	ym_slatch sl59(.MCLK(MCLK), .en(w292), .inp(w279), .val(l59));
	ym_slatch sl60(.MCLK(MCLK), .en(w291), .inp(w279), .val(l60));
	ym_slatch sl61(.MCLK(MCLK), .en(w294), .inp(w279), .val(l61));
	ym_slatch sl62(.MCLK(MCLK), .en(w293), .inp(w279), .val(l62));
	ym_slatch sl63(.MCLK(MCLK), .en(w292), .inp(reg_code[0]), .val(l63));
	ym_slatch sl64(.MCLK(MCLK), .en(w291), .inp(reg_code[0]), .val(l64));
	ym_slatch sl65(.MCLK(MCLK), .en(w294), .inp(reg_code[0]), .val(l65));
	ym_slatch sl66(.MCLK(MCLK), .en(w293), .inp(reg_code[0]), .val(l66));
	ym_slatch sl67(.MCLK(MCLK), .en(w292), .inp(reg_code[1]), .val(l67));
	ym_slatch sl68(.MCLK(MCLK), .en(w291), .inp(reg_code[1]), .val(l68));
	ym_slatch sl69(.MCLK(MCLK), .en(w294), .inp(reg_code[1]), .val(l69));
	ym_slatch sl70(.MCLK(MCLK), .en(w293), .inp(reg_code[1]), .val(l70));
	ym_slatch sl71(.MCLK(MCLK), .en(w292), .inp(reg_code[2]), .val(l71));
	ym_slatch sl72(.MCLK(MCLK), .en(w291), .inp(reg_code[2]), .val(l72));
	ym_slatch sl73(.MCLK(MCLK), .en(w294), .inp(reg_code[2]), .val(l73));
	ym_slatch sl74(.MCLK(MCLK), .en(w293), .inp(reg_code[2]), .val(l74));
	ym_slatch sl75(.MCLK(MCLK), .en(w292), .inp(reg_code[3]), .val(l75));
	ym_slatch sl76(.MCLK(MCLK), .en(w291), .inp(reg_code[3]), .val(l76));
	ym_slatch sl77(.MCLK(MCLK), .en(w294), .inp(reg_code[3]), .val(l77));
	ym_slatch sl78(.MCLK(MCLK), .en(w293), .inp(reg_code[3]), .val(l78));
	
	assign w301 = w321 & (l50 | l49);
	
	assign w302 = w301 & w316 & ~w320 & w317 & ~w318;
	
	assign w303 = w301 & w316 & ~w320 & w319 & ~w318;
	
	assign w304 = w249 | w169;
	
	assign w305 = ~(~w273 | w332);
	
	assign w306 = l53 & l54;
	assign w307 = ~l53 & l54;
	assign w308 = l53 & ~l54;
	assign w309 = ~l53 & ~l54;
	
	assign w310 = (w306 & l67) | (w307 & l68) | (w308 & l69) | (w309 & l70);
	
	assign w311 = (w306 & l55) | (w307 & l56) | (w308 & l57) | (w309 & l58);
	
	assign w312 = (w306 & l71) | (w307 & l72) | (w308 & l73) | (w309 & l74);
	
	assign w313 = (w306 & l59) | (w307 & l60) | (w308 & l61) | (w309 & l62);
	
	assign w314 = (w306 & l75) | (w307 & l76) | (w308 & l77) | (w309 & l78);
	
	assign w315 = (w306 & l63) | (w307 & l64) | (w308 & l65) | (w309 & l66);
	
	assign w316 = l50 ? reg_code[1] : w310;
	
	assign w317 = l50 ? w277 : w311;
	
	assign w318 = l50 ? reg_code[2] : w312;
	
	assign w319 = l50 ? w279 : w313;
	
	assign w320 = l50 ? reg_code[3] : w314;
	
	assign w321 = l50 ? reg_code[0] : w322;
	
	assign w322 = w315 | ~reg_m5;
	
	assign w323 = w301 & w317 & ~w316 & w318 & ~w320;
	
	assign w324 = w301 & w319 & ~w316 & w318 & ~w320;
	
	assign w325 = ~w318 & ~w316;
	
	assign w326 = w268 & ~l53 & ~l54;
	assign w327 = w268 & ~l53 & l54;
	assign w328 = w268 & l53 & ~l54;
	assign w329 = w268 & l53 & l54;
	
	assign w330 = ~(w273 & w332);
	
	assign w331 = w330 ? l52 : w311;
	
	assign w332 = w311 ^ w313;
	
	assign w333 = cpu_sel | io_address[0];
	
	assign w334 = ~(~reg_m5 | reg_m3);
	
	ym_sr_bit sr79(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(cpu_pen), .sr_out(l79));
	ym_sr_bit sr80(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l79), .sr_out(l80));
	
	assign w335 = ~l79 & l80;
	
	ym_sr_bit sr81(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w335), .sr_out(l81));
	
	assign w336 = ~reg_m5 | w337;
	
	assign w337 = w334 | (hclk1 & l81);
	
	assign w338 = ~(reg_code[3] | reg_code[2]);
	
	ym_sr_bit sr82(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l88), .sr_out(l82));
	ym_sr_bit sr83(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l47), .sr_out(l83));
	ym_sr_bit sr84(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l83), .sr_out(l84));
	
	assign w339 = ~(l84 & w346);
	
	assign w340 = ~(~l84 & w346);
	
	ym_sr_bit sr85(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l84), .sr_out(l85));
	ym_sr_bit sr86(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w189), .sr_out(l86));
	ym_sr_bit sr87(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l86), .sr_out(l87));
	
	assign w341 = l87 & w340;
	
	assign w342 = l87 & w339;
	
	ym_sr_bit sr88(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w341), .sr_out(l88));
	ym_sr_bit sr89(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w342), .sr_out(l89));
	
	assign w343 = hclk1 & l88;
	
	assign w344 = hclk1 & l89;
	
	assign w345 = w109 & ~cpu_sel & l85;
	
	assign w346 = ~w109 & cpu_sel & w338;
	
	ym_slatch #(.DATA_WIDTH(8)) sl90(.MCLK(MCLK), .en(w336), .inp({ w355[7:1], w123}), .val(l90)); // v counter
	
	ym_slatch #(.DATA_WIDTH(8)) sl91(.MCLK(MCLK), .en(w337), .inp(l106[8:1]), .val(l91)); // h counter
	
	assign w347 = w333 ? l91 : l90;
	
	assign w348 = w345 ? vram_data[15:8] : vram_data[7:0];
	
	ym_slatch #(.DATA_WIDTH(8)) sl92(.MCLK(MCLK), .en(w344), .inp(w348), .val(l92));
	
	assign w349 = w346 ? vram_data[7:0] : vram_data[15:8];
	
	ym_slatch #(.DATA_WIDTH(8)) sl93(.MCLK(MCLK), .en(w343), .inp(w349), .val(l93));
	
	assign w350 = cpu_sel ? io_data[15:8] : io_data[7:0];
	
	ym_slatch #(.DATA_WIDTH(8)) sl94(.MCLK(MCLK), .en(w304), .inp(w350), .val(l94));
	ym_slatch #(.DATA_WIDTH(8)) sl95(.MCLK(MCLK), .en(w304), .inp(io_data[7:0]), .val(l95));
	
	ym_slatch #(.DATA_WIDTH(8)) sl96(.MCLK(MCLK), .en(w294), .inp(l94), .val(l96));
	ym_slatch #(.DATA_WIDTH(8)) sl97(.MCLK(MCLK), .en(w294), .inp(l95), .val(l97));
	
	assign w351 = w331 ? l96 : l97;
	
	assign unk_data =
		(w328 ? l97 : 8'h0) |
		(w327 ? l99 : 8'h0) |
		(w329 ? l101 : 8'h0) |
		(w326 ? l103 : 8'h0);
	
	ym_slatch #(.DATA_WIDTH(8)) sl98(.MCLK(MCLK), .en(w291), .inp(l94), .val(l98));
	ym_slatch #(.DATA_WIDTH(8)) sl99(.MCLK(MCLK), .en(w291), .inp(l95), .val(l99));
	
	assign w352 = w331 ? l98 : l99;
	
	ym_slatch #(.DATA_WIDTH(8)) sl100(.MCLK(MCLK), .en(w292), .inp(l94), .val(l100));
	ym_slatch #(.DATA_WIDTH(8)) sl101(.MCLK(MCLK), .en(w292), .inp(l95), .val(l101));
	
	assign w353 = w331 ? l100 : l101;
	
	ym_slatch #(.DATA_WIDTH(8)) sl102(.MCLK(MCLK), .en(w293), .inp(l94), .val(l102));
	ym_slatch #(.DATA_WIDTH(8)) sl103(.MCLK(MCLK), .en(w293), .inp(l95), .val(l103));
	
	assign w354 = w331 ? l102 : l103;
	
	ym_sr_bit_array #(.DATA_WIDTH(8)) sr104(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(unk_data), .data_out(l104));
	
	ym_slatch_r #(.DATA_WIDTH(8)) sl_hit(.MCLK(MCLK), .en(w229), .rst(reset_comb), .inp(~reg_data_l2[7:0]), .val(reg_hit));
	
	ym_slatch sl_lsm0_latch(.MCLK(MCLK), .en(w457), .inp(reg_lsm0), .val(reg_lsm0_latch));
	ym_slatch sl_lsm1_latch(.MCLK(MCLK), .en(w457), .inp(reg_lsm1), .val(reg_lsm1_latch));
	
	ym_slatch_r #(.DATA_WIDTH(12)) sl_test_18(.MCLK(MCLK), .en(w128), .rst(reset_ext), .inp(io_data[11:0]), .val(reg_test_18));
	
	ym_slatch_r #(.DATA_WIDTH(15)) sl_test0(.MCLK(MCLK), .en(w84), .rst(reset_ext), .inp(io_data[14:0]), .val(reg_test0));
	
	ym_slatch_r #(.DATA_WIDTH(11)) sl_test1(.MCLK(MCLK), .en(w85), .rst(reset_ext), .inp(io_data[10:0]), .val(reg_test1));
	
	ym_slatch #(.DATA_WIDTH(2)) sl_code_01(.MCLK(MCLK), .en(w164), .inp(w350[7:6]), .val(reg_code[1:0]));
	ym_slatch_r #(.DATA_WIDTH(3)) sl_code_234(.MCLK(MCLK), .en(w168), .rst(w204), .inp(io_data[6:4]), .val(reg_code[4:2]));
	
	ym_slatch #(.DATA_WIDTH(8)) sl_addr_1(.MCLK(MCLK), .en(w165), .inp(io_data[7:0]), .val(reg_addr[7:0]));
	ym_slatch #(.DATA_WIDTH(6)) sl_addr_2(.MCLK(MCLK), .en(w164), .inp(w350[5:0]), .val(reg_addr[13:8]));
	ym_slatch_r #(.DATA_WIDTH(3)) sl_addr_3(.MCLK(MCLK), .en(w168), .rst(w204), .inp(io_data[2:0]), .val(reg_addr[16:14]));
	
	wire [16:0] reg_data_sum = reg_data_l2 + { 9'h0, reg_inc } + { 16'h0, ~reg_m5 };
	wire [16:0] reg_data_mux = w185 ? reg_addr : reg_data_sum;
	
	ym7101_dff #(.DATA_WIDTH(14)) reg_data_1(.MCLK(MCLK), .clk(~w181), .inp(reg_data_mux[13:0]),
		.rst(reset_comb), .outp(reg_data_l2[13:0]));
	
	ym7101_dff #(.DATA_WIDTH(3)) reg_data_2(.MCLK(MCLK), .clk(~w181), .inp(reg_data_mux[16:14]),
		.rst(w204), .outp(reg_data_l2[16:14]));
	
	ym_slatch sl_80_b0(.MCLK(MCLK), .en(w216), .inp(reg_data_l2[0]), .val(reg_80_b0));
	ym_slatch sl_m3(.MCLK(MCLK), .en(w216), .inp(reg_data_l2[1]), .val(reg_m3));
	ym_slatch sl_80_b2(.MCLK(MCLK), .en(w216), .inp(reg_data_l2[2]), .val(reg_80_b2));
	ym_slatch sl_80_b3(.MCLK(MCLK), .en(w216), .inp(reg_data_l2[3]), .val(reg_80_b3));
	ym_slatch sl_ie1(.MCLK(MCLK), .en(w216), .inp(reg_data_l2[4]), .val(reg_ie1));
	ym_slatch sl_lcb(.MCLK(MCLK), .en(w216), .inp(reg_data_l2[5]), .val(reg_lcb));
	ym_slatch sl_80_b6(.MCLK(MCLK), .en(w216), .inp(reg_data_l2[6]), .val(reg_80_b6));
	ym_slatch sl_80_b7(.MCLK(MCLK), .en(w216), .inp(reg_data_l2[7]), .val(reg_80_b7));
	
	
	ym_slatch sl_rs1(.MCLK(MCLK), .en(w215), .inp(reg_data_l2[0]), .val(reg_rs1));
	ym_slatch sl_lsm0(.MCLK(MCLK), .en(w215), .inp(reg_data_l2[1]), .val(reg_lsm0));
	ym_slatch sl_lsm1(.MCLK(MCLK), .en(w215), .inp(reg_data_l2[2]), .val(reg_lsm1));
	ym_slatch sl_ste(.MCLK(MCLK), .en(w215), .inp(reg_data_l2[3]), .val(reg_ste));
	ym_slatch sl_8c_b4(.MCLK(MCLK), .en(w215), .inp(reg_data_l2[4]), .val(reg_8c_b4));
	ym_slatch sl_8c_b5(.MCLK(MCLK), .en(w215), .inp(reg_data_l2[5]), .val(reg_8c_b5));
	ym_slatch sl_8c_b6(.MCLK(MCLK), .en(w215), .inp(reg_data_l2[6]), .val(reg_8c_b6));
	ym_slatch sl_rs0(.MCLK(MCLK), .en(w215), .inp(reg_data_l2[7]), .val(reg_rs0));
	
	ym_slatch sl_81_b0(.MCLK(MCLK), .en(w217), .inp(reg_data_l2[0]), .val(reg_81_b0));
	ym_slatch sl_81_b1(.MCLK(MCLK), .en(w217), .inp(reg_data_l2[1]), .val(reg_81_b1));
	ym_slatch sl_m5(.MCLK(MCLK), .en(w217), .inp(reg_data_l2[2]), .val(reg_m5));
	ym_slatch sl_m2(.MCLK(MCLK), .en(w217), .inp(reg_data_l2[3]), .val(reg_m2));
	ym_slatch sl_m1(.MCLK(MCLK), .en(w217), .inp(reg_data_l2[4]), .val(reg_m1));
	ym_slatch sl_ie0(.MCLK(MCLK), .en(w217), .inp(reg_data_l2[5]), .val(reg_ie0));
	ym_slatch sl_disp(.MCLK(MCLK), .en(w217), .inp(reg_data_l2[6]), .val(reg_disp));
	ym_slatch sl_81_b7(.MCLK(MCLK), .en(w217), .inp(reg_data_l2[7]), .val(reg_81_b7));
	
	
	ym_slatch sl_lscr(.MCLK(MCLK), .en(w213), .inp(reg_data_l2[0]), .val(reg_lscr));
	ym_slatch sl_hscr(.MCLK(MCLK), .en(w213), .inp(reg_data_l2[1]), .val(reg_hscr));
	ym_slatch sl_vscr(.MCLK(MCLK), .en(w213), .inp(reg_data_l2[2]), .val(reg_vscr));
	ym_slatch sl_ie2(.MCLK(MCLK), .en(w213), .inp(reg_data_l2[3]), .val(reg_ie2));
	ym_slatch sl_8b_b4(.MCLK(MCLK), .en(w213), .inp(reg_data_l2[4]), .val(reg_8b_b4));
	ym_slatch sl_8b_b5(.MCLK(MCLK), .en(w213), .inp(reg_data_l2[5]), .val(reg_8b_b5));
	ym_slatch sl_8b_b6(.MCLK(MCLK), .en(w213), .inp(reg_data_l2[6]), .val(reg_8b_b6));
	ym_slatch sl_8b_b7(.MCLK(MCLK), .en(w213), .inp(reg_data_l2[7]), .val(reg_8b_b7));
	
	ym_slatch #(.DATA_WIDTH(8)) sl_inc(.MCLK(MCLK), .en(w210), .inp(reg_data_l2[7:0]), .val(reg_inc));
	
	ym_slatch #(.DATA_WIDTH(6)) sl_sa_high(.MCLK(MCLK), .en(w227), .inp(reg_data_l2[5:0]), .val(reg_sa_high));
	
	ym_slatch #(.DATA_WIDTH(2)) sl_dmd(.MCLK(MCLK), .en(w227), .inp(reg_data_l2[7:6]), .val(reg_dmd));
	
	ym_cnt_bit_load #(.DATA_WIDTH(8)) cnt_lg_1(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(w235), .reset(1'h0), .load(w211), .load_val(~reg_data_l2[7:0]), .c_out(reg_lg_of), .val(reg_lg[7:0]));
		
	ym_cnt_bit_load #(.DATA_WIDTH(8)) cnt_lg_2(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(w251), .reset(1'h0), .load(w212), .load_val(~reg_data_l2[7:0]), .val(reg_lg[15:8]));
	
	ym_cnt_bit_load #(.DATA_WIDTH(8)) cnt_sa_low_1(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(w235), .reset(1'h0), .load(w228), .load_val(reg_data_l2[7:0]), .c_out(reg_sa_of), .val(reg_sa_low[7:0]));
		
	ym_cnt_bit_load #(.DATA_WIDTH(8)) cnt_sa_low_2(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(w255), .reset(1'h0), .load(w214), .load_val(reg_data_l2[7:0]), .val(reg_sa_low[15:8]));
	
	assign IPL1_pull = ~io_ipl1;
	assign IPL2_pull = ~io_ipl2;
	assign UWR = ~io_uwr;
	assign LWR = ~io_lwr;
	assign OE0 = ~io_oe0;
	assign CAS0 = ~io_cas0;
	assign RAS0 = ~io_ras0;
	assign BR_pull = ~w42;
	assign BGACK_pull = ~w64;
	assign DTACK_pull = ~dtack_pull_n;
	assign RA = w103[7:0];
	assign INT_pull = ~w122;
	
	// FSM block
	
	ym_cnt_bit_load #(.DATA_WIDTH(9)) cnt105(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(w436), .reset(1'h0), .load(w437), .load_val(w428), .val(l105));
	
	assign w355 = w106 ? { l105, w446 } : { 1'h0, l105 };
	
	ym_cnt_bit_load #(.DATA_WIDTH(9)) cnt106(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(w363), .reset(1'h0), .load(w361), .load_val(w364), .val(l106));
	
	ym_sr_bit #(.SR_LENGTH(8)) sr107(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l663), .sr_out(l107));
	
	ym_sr_bit sr108(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w476), .sr_out(l108));
	
	ym_sr_bit sr109(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w359), .sr_out(l109));
	
	ym_sr_bit sr110(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w504), .sr_out(l110));
	
	assign w356 = w357 | (l118 & w380);
	
	assign w357 = reg_test1[6:4] == 3'h1;
	
	assign w358 = ~(w476 | w477 | w478 | w479);
	
	assign w359 = w358 & w386 & w395;
	
	assign w360 = ~l117;
	
	ym_sr_bit sr111(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w503), .sr_out(l111));
	
	ym_sr_bit sr112(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w490), .sr_out(l112));
	
	assign w361 = l112 | w88 | reset_comb | w370;
	
	assign w362 = ~(w361 | reg_test1[3]);
	
	assign w363 = w362 | (reg_test1[3] & ~cpu_intak);
	
	assign w364 = w88 ? io_data[8:0] : { 4'he, ~w365, w368, w367, w366, w365 };
	
	assign w365 = ~reg_80_b0 & reg_rs1 & reg_m5;

	assign w366 = ~reg_80_b0 & ~reg_rs1;
	
	assign w367 = reg_80_b0 & ~reg_rs1;
	
	assign w368 = w365 | w369;
	
	assign w369 = ~reg_rs1 & reg_80_b0 & reg_m5;
	// h40: 457
	// h32: 466
	// m4: 466
	
	assign w370 = ~l113 & l121 & reg_80_b0;
	
	ym_sr_bit sr113(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l121), .sr_out(l113));
	
	ym_sr_bit sr114(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w491), .sr_out(l114));
	
	wire l115_t;
	assign l115 = ~l115_t;
	ym_sr_bit sr115(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w502), .sr_out(l115_t));
	
	wire l116_t;
	assign l116 = ~l116_t;
	ym_sr_bit sr116(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w384), .sr_out(l116_t));
	
	assign w371 = reg_test1[6:4] == 3'h2;
	
	assign w372 = w371 | (l119 & w380);
	
	ym_sr_bit sr117(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w505), .sr_out(l117));
	
	ym_sr_bit sr118(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w477), .sr_out(l118));
	
	ym_sr_bit sr119(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w478), .sr_out(l119));
	
	assign w373 = ~(reg_m5 ? l107 : l663);
	
	assign w374 = reg_8c_b6 ? hclk2 : w373;
	
	ym_sr_bit sr120(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(i_csync), .sr_out(l120));
	
	assign w375 = l120 | w411;
	
	assign w376 = w377 & (l121 | w375);
	
	assign w377 = ~(l114 | reset_comb);
	
	ym_sr_bit sr121(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w376), .sr_out(l121));
	
	ym_sr_bit sr122(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w492), .sr_out(l122));
	
	ym_sr_bit sr123(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w501), .sr_out(l123));
	
	assign w378 = reg_vscr ? l124 : ~l117;
	
	assign w379 = w378 & w380;
	
	assign w380 = reg_test1[6:4] == 3'h0;
	
	assign w381 = reg_test1[6:4] == 3'h5;
	
	assign w382 = reg_test1[6:4] == 3'h3;
	
	assign w383 = reg_test1[6:4] == 3'h4;
	
	assign w384 = ~(w483 & ~l132);
	
	assign w385 = w382 | (w380 & l125);
	
	assign w386 = ~(w480 | w483 | w481);
	
	ym_sr_bit sr124(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w506), .sr_out(l124));
	
	ym_sr_bit sr125(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w479), .sr_out(l125));
	
	ym_sr_bit sr126(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w480), .sr_out(l126));
	
	assign w387 = reg_m5 ? l127 : w420;
	
	ym_sr_bit #(.SR_LENGTH(8)) sr127(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w420), .sr_out(l127));
	
	assign w388 = t29 & ~w439;
	
	ym_sr_bit sr128(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w397), .sr_out(l128));
	
	assign w389 = reg_disp & t29 & t38;
	
	ym_sr_bit sr129(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(t30), .sr_out(l129));
	
	assign w390 = w441 | w450;
	
	assign w391 = t31 & w443;
	
	ym_sr_bit sr130(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w493), .sr_out(l130));
	
	assign w392 = reset_comb | l137;
	
	ym7101_rs_trig rs29(.MCLK(MCLK), .set(l130), .rst(w392), .q(t29));
	
	ym_sr_bit sr131(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w500), .sr_out(l131));
	
	assign w393 = l133 & w380;
	
	ym_sr_bit sr132(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w403), .sr_out(l132));
	
	assign w394 = w383 | (w380 & l126);
	
	assign w395 = ~(w486 | w489 | w482 | w488);
	
	ym_sr_bit sr133(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w507), .sr_out(l133));
	
	ym_sr_bit sr134(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w481), .sr_out(l134));
	
	assign w396 = reg_m5 ? l135 : w421;
	
	ym_sr_bit #(.SR_LENGTH(7)) sr135(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w421), .sr_out(l135));
	
	ym_sr_bit sr136(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w404), .sr_out(l136));
	
	assign w397 = ~(~reg_80_b0 & w387);
	
	assign w398 = ~(w441 | w443 | w450);
	
	assign w399 = ~w398 & t32;
	
	assign w400 = w390 & t32;
	
	ym7101_rs_trig rs30(.MCLK(MCLK), .set(w401), .rst(l152), .q(t30));
	
	assign w401 = reset_comb | l143;
	
	ym_sr_bit sr137(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w494), .sr_out(l137));
	
	ym_sr_bit sr138(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w499), .sr_out(l138));
	
	assign w402 = w380 & l140;
	
	ym_sr_bit sr139(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w410), .sr_out(l139));
	
	assign w403 = l139 | w410;
	
	ym_sr_bit sr140(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w508), .sr_out(l140));
	
	ym_sr_bit sr141(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w482), .sr_out(l141));
	
	ym_sr_bit sr142(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w489), .sr_out(l142));
	
	assign w404 = ~(w396 & ~reg_8c_b5);
	
	assign w405 = w398 & t33;
	
	assign w406 = w398 & t33;
	
	ym7101_rs_trig rs31(.MCLK(MCLK), .set(w407), .rst(w408), .q(t31));
	
	assign w407 = l137 | l153;
	
	assign w408 = reset_comb | w409;
	
	assign w409 = l131 | l144;
	
	ym_sr_bit sr143(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w495), .sr_out(l143));
	
	ym_sr_bit sr144(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w498), .sr_out(l144));
	
	assign w410 = w361 & w416;
	
	ym_sr_bit sr145(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w510), .sr_out(l145));
	
	ym_sr_bit sr146(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w509), .sr_out(l146));
	
	ym_sr_bit sr147(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w487), .sr_out(l147));
	
	ym_sr_bit sr148(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w488), .sr_out(l148));
	
	assign w411 = reg_8c_b5 & l149;
	
	ym_sr_bit sr149(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(i_hsync), .sr_out(l149));
	
	ym_sr_bit sr150(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w412), .sr_out(l150));
	
	assign w412 = w405 | w399;
	
	assign w413 = w406 | w400 | w391;
	
	ym_sr_bit sr151(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w413), .sr_out(l151));
	
	ym7101_rs_trig rs32(.MCLK(MCLK), .set(w414), .rst(l138), .q(t32));
	
	assign w414 = w409 | reset_comb;
	
	ym_sr_bit sr152(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w496), .sr_out(l152));
	
	ym_sr_bit sr153(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w497), .sr_out(l153));
	
	assign w415 = w380 & l154;
	
	assign w416 = ~reg_8c_b4 & reg_80_b0;
	
	assign w417 = l146 | l145;
	
	assign w418 = l145 | l155;
	
	assign w419 = w381 | (w380 & l148);
	
	ym_sr_bit sr154(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w511), .sr_out(l154));
	
	ym_sr_bit sr155(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w485), .sr_out(l155));
	
	ym_sr_bit sr156(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w484), .sr_out(l156));
	
	assign w420 = l151 ^ l663;
	
	assign w421 = w427 ? l160 : l157;
	
	ym_sr_bit sr157(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l150), .sr_out(l157));
	
	assign w422 = reg_m5 ? l158 : l129;
	
	ym_sr_bit #(.SR_LENGTH(8)) sr158(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l129), .sr_out(l158));
	
	ym7101_rs_trig rs33(.MCLK(MCLK), .set(w423), .rst(l123), .q(t33));
	
	assign w423 = reset_comb | l131;
	
	assign w424 = l159 & w380;
	
	assign w425 = w416 & ~reg_81_b0;
	
	ym_sr_bit sr159(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w512), .sr_out(l159));
	
	ym_cnt_bit cnt160(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(w426), .reset(reset_comb), .val(l160));
	
	assign w426 = w420 & ~l161;
	
	ym_sr_bit sr161(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w420), .sr_out(l161));
	
	assign w427 = reg_m5 & reg_80_b3;
	
	assign w428 = w86 ? io_data[8:0] :
		{ 2'h3, ~w431, w429, ~w107, w433, ~cpu_pal, w434, w435 };
	
	assign w429 = w430 | w431;
	
	assign w430 = ~cpu_pal & w107;
	
	assign w431 = cpu_pal & ~reg_m5;
	
	assign w432 = cpu_pal & w107;
	
	assign w433 = w432 | w431;
	
	assign w434 = cpu_pal & ~w446;
	
	assign w435 = (~cpu_pal) ^ w446;
	
	assign w436 = (~reg_test1[2] & l115 & ~w437) | (reg_test1[2] & ~cpu_bg);
	
	assign w437 = w438 | reset_comb | w86 | w460;
	
	assign w438 = l115 & l174;
	
	ym_sr_bit sr162(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(~w475), .sr_out(l162));
	
	assign w439 = ~(reg_disp & (l162 | t38));
	
	ym_sr_bit sr163(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w474), .sr_out(l163));
	
	assign w440 = reset_comb | w442;
	
	ym7101_rs_trig rs34(.MCLK(MCLK), .set(w444), .rst(w440), .q(t34));
	
	assign w441 = t34 & reg_m5;
	
	ym_sr_bit sr164(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w473), .sr_out(l164));
	
	assign w442 = l163 & w449;
	
	ym7101_rs_trig rs35(.MCLK(MCLK), .set(w445), .rst(w444), .q(t35));
	
	assign w443 = t35 & reg_m5;
	
	ym_sr_bit sr165(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w472), .sr_out(l165));
	
	assign w444 = l164 & w449;
	
	assign w445 = reset_comb | w447;
	
	ym7101_rs_trig rs36(.MCLK(MCLK), .set(w452), .rst(w448), .q(t36));
	
	ym_cnt_bit_rs cnt166(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .c_in(w455), .reset(w451), .set(l168), .val(w446));
	
	ym_sr_bit sr167(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w471), .sr_out(l167));
	
	assign w447 = l165 & w449;
	
	assign w448 = reset_comb | w447;
	
	assign w449 = l111 | ~w446;
	
	ym_sr_bit sr168(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w456), .sr_out(l168));
	
	assign w450 = reg_m5 & t36;
	
	assign w451 = reset_comb | ~reg_lsm0 | (w454 & ~t39);
	
	ym_sr_bit sr169(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w470), .sr_out(l169));
	
	assign w452 = l169 & w449;
	
	assign w453 = w452 | reset_comb;
	
	ym7101_rs_trig rs37(.MCLK(MCLK), .set(w453), .rst(l167), .q(t37));
	
	assign w454 = reg_80_b0 & w459;
	
	assign w455 = ~reg_80_b0 & w459;
	
	assign w456 = w454 & t39;
	
	ym_sr_bit sr170(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w469), .sr_out(l170));
	
	assign w457 = ~l170;
	
	assign w458 = reset_comb | w457;
	
	assign w459 = ~l170 & l110;
	
	ym7101_rs_trig rs38(.MCLK(MCLK), .set(l172), .rst(w458), .q(t38));
	
	ym_sr_bit sr171(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l114), .sr_out(l171));
	
	ym_sr_bit sr172(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(~w468), .sr_out(l172));
	
	ym7101_rs_trig rs39(.MCLK(MCLK), .set(w465), .rst(w461), .q(t39));
	
	assign w460 = reg_80_b0 & ~l176 & l175;
	
	assign w461 = reset_comb | (w460 & l171);
	
	ym_sr_bit sr173(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l122), .sr_out(l173));
	
	ym_sr_bit sr174(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w467), .sr_out(l174));
	
	assign w462 = ~(l167 | reset_comb);
	
	assign w463 = l120 & (l122 | l114);
	
	assign w464 = w462 & (l175 | w463);
	
	ym_sr_bit sr175(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w464), .sr_out(l175));
	
	ym_sr_bit sr176(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l175), .sr_out(l176));
	
	assign w465 = w460 & l173;
	
	assign w466 = ~w439;
	
	assign pla_vcnt[0] = l105 == 9'd511;
	assign pla_vcnt[1] = w446 & cpu_pal & w108 & l105 == 9'd471;
	assign pla_vcnt[2] = w446 & cpu_pal & w107 & l105 == 9'd463;
	assign pla_vcnt[3] = w446 & ~cpu_pal & w107 & l105 == 9'd490;
	assign pla_vcnt[4] = ~w446 & cpu_pal & w108 & l105 == 9'd472;
	assign pla_vcnt[5] = ~w446 & cpu_pal & w107 & l105 == 9'd464;
	assign pla_vcnt[6] = ~w446 & cpu_pal & ~reg_m5 & l105 == 9'd448;
	assign pla_vcnt[7] = ~w446 & ~cpu_pal & w107 & l105 == 9'd491;
	assign pla_vcnt[8] = ~w446 & ~cpu_pal & ~reg_m5 & l105 == 9'd475;
	assign pla_vcnt[9] = w446 & cpu_pal & w108 & l105 == 9'd468;
	assign pla_vcnt[10] = w446 & cpu_pal & w107 & l105 == 9'd460;
	assign pla_vcnt[11] = w446 & ~cpu_pal & w107 & l105 == 9'd487;
	assign pla_vcnt[12] = ~w446 & cpu_pal & w108 & l105 == 9'd469;
	assign pla_vcnt[13] = ~w446 & cpu_pal & w107 & l105 == 9'd461;
	assign pla_vcnt[14] = ~w446 & cpu_pal & ~reg_m5 & l105 == 9'd445;
	assign pla_vcnt[15] = ~w446 & ~cpu_pal & w107 & l105 == 9'd488;
	assign pla_vcnt[16] = ~w446 & ~cpu_pal & ~reg_m5 & l105 == 9'd472;
	assign pla_vcnt[17] = w446 & cpu_pal & w108 & l105 == 9'd465;
	assign pla_vcnt[18] = w446 & cpu_pal & w107 & l105 == 9'd457;
	assign pla_vcnt[19] = w446 & ~cpu_pal & w107 & l105 == 9'd484;
	assign pla_vcnt[20] = ~w446 & cpu_pal & w108 & l105 == 9'd466;
	assign pla_vcnt[21] = ~w446 & cpu_pal & w107 & l105 == 9'd458;
	assign pla_vcnt[22] = ~w446 & cpu_pal & ~reg_m5 & l105 == 9'd442;
	assign pla_vcnt[23] = ~w446 & ~cpu_pal & w107 & l105 == 9'd485;
	assign pla_vcnt[24] = ~w446 & ~cpu_pal & ~reg_m5 & l105 == 9'd469;
	assign pla_vcnt[25] = cpu_pal & w108 & l105 == 9'd482;
	assign pla_vcnt[26] = cpu_pal & w107 & l105 == 9'd474;
	assign pla_vcnt[27] = cpu_pal & ~reg_m5 & l105 == 9'd458;
	assign pla_vcnt[28] = ~cpu_pal & w107 & l105 == 9'd501;
	assign pla_vcnt[29] = ~cpu_pal & ~reg_m5 & l105 == 9'd485;
	assign pla_vcnt[30] = reg_lsm0 & cpu_pal & w108 & l105 == 9'd263;
	assign pla_vcnt[31] = reg_lsm0 & cpu_pal & w107 & l105 == 9'd255;
	assign pla_vcnt[32] = ~reg_lsm0 & cpu_pal & w108 & l105 == 9'd264;
	assign pla_vcnt[33] = ~reg_lsm0 & cpu_pal & w107 & l105 == 9'd256;
	assign pla_vcnt[34] = ~reg_lsm0 & cpu_pal & ~reg_m5 & l105 == 9'd240;
	assign pla_vcnt[35] = ~cpu_pal & w107 & l105 == 9'd232;
	assign pla_vcnt[36] = ~cpu_pal & ~reg_m5 & l105 == 9'd216;
	assign pla_vcnt[37] = w108 & l105 == 9'd240;
	assign pla_vcnt[38] = w107 & l105 == 9'd224;
	assign pla_vcnt[39] = ~reg_m5 & l105 == 9'd192;
	assign pla_vcnt[40] = l105 == 9'd0;
	assign pla_vcnt[41] = reg_lsm0 & cpu_pal & w108 & l105 == 9'd265;
	assign pla_vcnt[42] = reg_lsm0 & cpu_pal & w107 & l105 == 9'd257;
	assign pla_vcnt[43] = ~reg_lsm0 & cpu_pal & w108 & l105 == 9'd266;
	assign pla_vcnt[44] = ~reg_lsm0 & cpu_pal & w107 & l105 == 9'd258;
	assign pla_vcnt[45] = ~reg_lsm0 & cpu_pal & ~reg_m5 & l105 == 9'd242;
	assign pla_vcnt[46] = ~cpu_pal & w107 & l105 == 9'd234;
	assign pla_vcnt[47] = ~cpu_pal & ~reg_m5 & l105 == 9'd218;
	
	assign pla_hcnt1[0] = w466 & ~reg_m5 & l106 == 9'd488;
	assign pla_hcnt1[1] = w466 & ~reg_m5 & l106 == 9'd484;
	assign pla_hcnt1[2] = w466 & ~reg_m5 & (l106 & 9'd507) == 9'd472;
	assign pla_hcnt1[3] = w466 & ~reg_m5 & (l106 & 9'd503) == 9'd272;
	assign pla_hcnt1[4] = w466 & ~reg_m5 & (l106 & 9'd495) == 9'd268;
	assign pla_hcnt1[5] = w466 & reg_m5 & reg_rs1 & (l106 & 9'd463) == 9'd266;
	assign pla_hcnt1[6] = w466 & reg_m5 & (l106 & 9'd271) == 9'd10;
	assign pla_hcnt1[7] = w466 & reg_m5 & reg_rs1 & l106 == 9'd484;
	assign pla_hcnt1[8] = w466 & reg_m5 & reg_rs1 & l106 == 9'd460;
	assign pla_hcnt1[9] = w466 & reg_m5 & reg_rs1 & l106 == 9'd458;
	assign pla_hcnt1[10] = w466 & ~w425 & reg_m5 & reg_rs1 & (l106 & 9'd505) == 9'd344;
	assign pla_hcnt1[11] = w466 & ~w416 & reg_m5 & reg_rs1 & l106 == 9'd364;
	assign pla_hcnt1[12] = w466 & ~w416 & reg_m5 & reg_rs1 & (l106 & 9'd509) == 9'd360;
	assign pla_hcnt1[13] = w466 & ~w416 & reg_m5 & reg_rs1 & (l106 & 9'd505) == 9'd352;
	assign pla_hcnt1[14] = w466 & reg_m5 & reg_rs1 & (l106 & 9'd505) == 9'd336;
	assign pla_hcnt1[15] = w466 & reg_m5 & reg_rs1 & (l106 & 9'd505) == 9'd328;
	assign pla_hcnt1[16] = w466 & reg_m5 & reg_rs1 & (l106 & 9'd509) == 9'd324;
	assign pla_hcnt1[17] = w466 & ~w416 & reg_m5 & ~reg_rs1 & l106 == 9'd290;
	assign pla_hcnt1[18] = w466 & ~w416 & reg_m5 & ~reg_rs1 & (l106 & 9'd509) == 9'd292;
	assign pla_hcnt1[19] = w466 & ~w425 & reg_m5 & ~reg_rs1 & (l106 & 9'd505) == 9'd280;
	assign pla_hcnt1[20] = w466 & reg_m5 & ~reg_rs1 & (l106 & 9'd505) == 9'd264;
	assign pla_hcnt1[21] = w466 & reg_m5 & ~reg_rs1 & (l106 & 9'd509) == 9'd260;
	assign pla_hcnt1[22] = w466 & reg_m5 & ~reg_rs1 & (l106 & 9'd505) == 9'd272;
	assign pla_hcnt1[23] = w466 & reg_m5 & l106 == 9'd486;
	assign pla_hcnt1[24] = w466 & reg_m5 & (l106 & 9'd503) == 9'd498;
	assign pla_hcnt1[25] = w466 & reg_m5 & (l106 & 9'd505) == 9'd488;
	assign pla_hcnt1[26] = w466 & reg_m5 & (l106 & 9'd509) == 9'd480;
	assign pla_hcnt1[27] = w466 & reg_m5 & (l106 & 9'd497) == 9'd464;
	assign pla_hcnt1[28] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd488;
	assign pla_hcnt1[29] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd476;
	assign pla_hcnt1[30] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd284;
	assign pla_hcnt1[31] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd272;
	assign pla_hcnt1[32] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd484;
	assign pla_hcnt1[33] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd472;
	assign pla_hcnt1[34] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd280;
	assign pla_hcnt1[35] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd268;
	assign pla_hcnt1[36] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd480;
	assign pla_hcnt1[37] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd468;
	assign pla_hcnt1[38] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd276;
	assign pla_hcnt1[39] = w466 & ~reg_m5 & (l106 & 9'd509) == 9'd264;
	assign pla_hcnt1[40] = w466 & ~reg_m5 & (l106 & 9'd279) == 9'd18;
	assign pla_hcnt1[41] = w466 & ~reg_m5 & (l106 & 9'd287) == 9'd10;
	assign pla_hcnt1[42] = w466 & ~reg_m5 & (l106 & 9'd497) == 9'd496;
	assign pla_hcnt1[43] = ~w466 & (l106 & 9'd259) == 9'd0;
	assign pla_hcnt1[44] = (l106 & 9'd1) == 9'd1;
	assign pla_hcnt1[45] = w466 & reg_m5 & l106 == 9'd510;
	assign pla_hcnt1[46] = w466 & reg_m5 & l106 == 9'd502;
	assign pla_hcnt1[47] = w466 & reg_m5 & l106 == 9'd508;
	assign pla_hcnt1[48] = w466 & reg_m5 & l106 == 9'd500;
	assign pla_hcnt1[49] = w466 & reg_m5 & l106 == 9'd504;
	assign pla_hcnt1[50] = w466 & reg_m5 & l106 == 9'd496;
	assign pla_hcnt1[51] = w466 & reg_m5 & reg_rs1 & (l106 & 9'd455) == 9'd262;
	assign pla_hcnt1[52] = w466 & (l106 & 9'd263) == 9'd6;
	assign pla_hcnt1[53] = w466 & reg_m5 & reg_rs1 & (l106 & 9'd455) == 9'd260;
	assign pla_hcnt1[54] = w466 & (l106 & 9'd263) == 9'd4;
	assign pla_hcnt1[55] = w466 & reg_m5 & reg_rs1 & (l106 & 9'd463) == 9'd264;
	assign pla_hcnt1[56] = w466 & (l106 & 9'd271) == 9'd8;
	assign pla_hcnt1[57] = w466 & ~reg_m5 & (l106 & 9'd271) == 9'd8;
	assign pla_hcnt1[58] = w466 & reg_m5 & reg_rs1 & (l106 & 9'd463) == 9'd256;
	assign pla_hcnt1[59] = w466 & (l106 & 9'd271) == 9'd0;
	assign pla_hcnt1[60] = ~w466 & (l106 & 9'd63) == 9'd50;
	assign pla_hcnt1[61] = w466 & reg_m5 & reg_rs1 & l106 == 9'd306;
	assign pla_hcnt1[62] = w466 & reg_m5 & (l106 & 9'd319) == 9'd50;
	
	assign pla_hcnt2[0] = (l106 & 9'd15) == 9'd3;
	assign pla_hcnt2[1] = l106 == 9'd507;
	assign pla_hcnt2[2] = reg_m5 & reg_rs1 & (l106 & 9'd463) == 9'd269;
	assign pla_hcnt2[3] = reg_m5 & (l106 & 9'd271) == 9'd13;
	assign pla_hcnt2[4] = ~reg_m5 & l106 == 9'd483;
	assign pla_hcnt2[5] = ~reg_m5 & l106 == 9'd471;
	assign pla_hcnt2[6] = ~reg_m5 & l106 == 9'd279;
	assign pla_hcnt2[7] = ~reg_m5 & l106 == 9'd267;
	assign pla_hcnt2[8] = (l106 & 9'd15) == 9'd15;
	assign pla_hcnt2[9] = ~reg_m5 & (l106 & 9'd15) == 9'd15;
	assign pla_hcnt2[10] = (l106 & 9'd15) == 9'd7;
	assign pla_hcnt2[11] = (l106 & 9'd7) == 9'd0;
	assign pla_hcnt2[12] = reg_rs1 & l106 == 9'd322;
	assign pla_hcnt2[13] = ~reg_rs1 & l106 == 9'd258;
	assign pla_hcnt2[14] = l106 == 9'd0;
	assign pla_hcnt2[15] = reg_rs1 & l106 == 9'd120;
	assign pla_hcnt2[16] = ~reg_rs1 & l106 == 9'd95;
	assign pla_hcnt2[17] = reg_m5 & reg_rs1 & l106 == 9'd328;
	assign pla_hcnt2[18] = reg_m5 & ~reg_rs1 & l106 == 9'd264;
	assign pla_hcnt2[19] = ~reg_m5 & l106 == 9'd488;
	assign pla_hcnt2[20] = reg_rs1 & l106 == 9'd482;
	assign pla_hcnt2[21] = ~reg_rs1 & l106 == 9'd488;
	assign pla_hcnt2[22] = reg_rs1 & l106 == 9'd358;
	assign pla_hcnt2[23] = ~reg_rs1 & l106 == 9'd292;
	assign pla_hcnt2[24] = reg_rs1 & l106 == 9'd164;
	assign pla_hcnt2[25] = reg_rs1 & l106 == 9'd466;
	assign pla_hcnt2[26] = ~reg_rs1 & l106 == 9'd134;
	assign pla_hcnt2[27] = ~reg_rs1 & l106 == 9'd475;
	assign pla_hcnt2[28] = reg_rs1 & l106 == 9'd148;
	assign pla_hcnt2[29] = ~reg_rs1 & l106 == 9'd121;
	assign pla_hcnt2[30] = reg_rs1 & l106 == 9'd120;
	assign pla_hcnt2[31] = ~reg_rs1 & l106 == 9'd95;
	assign pla_hcnt2[32] = reg_rs1 & l106 == 9'd1;
	assign pla_hcnt2[33] = ~reg_rs1 & l106 == 9'd0;
	assign pla_hcnt2[34] = reg_rs1 & l106 == 9'd348;
	assign pla_hcnt2[35] = ~reg_rs1 & l106 == 9'd284;
	assign pla_hcnt2[36] = reg_rs1 & l106 == 9'd330;
	assign pla_hcnt2[37] = ~reg_rs1 & l106 == 9'd266;
	assign pla_hcnt2[38] = l106 == 9'd18;
	assign pla_hcnt2[39] = ~reg_lcb & l106 == 9'd10;
	assign pla_hcnt2[40] = reg_rs1 & l106 == 9'd43;
	assign pla_hcnt2[41] = ~reg_rs1 & l106 == 9'd36;
	assign pla_hcnt2[42] = reg_rs1 & l106 == 9'd253;
	assign pla_hcnt2[43] = ~reg_rs1 & l106 == 9'd206;
	assign pla_hcnt2[44] = reg_rs1 & l106 == 9'd363;
	assign pla_hcnt2[45] = ~reg_rs1 & l106 == 9'd294;

	assign w467 = pla_vcnt[41] | pla_vcnt[42] | pla_vcnt[43]
		| pla_vcnt[44] | pla_vcnt[45] | pla_vcnt[46] | pla_vcnt[47];
	assign w468 = ~pla_vcnt[40];
	assign w469 = ~(pla_vcnt[37] | pla_vcnt[38] | pla_vcnt[39]);
	assign w470 = pla_vcnt[30] | pla_vcnt[31] | pla_vcnt[32]
		| pla_vcnt[33] | pla_vcnt[34] | pla_vcnt[35] | pla_vcnt[36];
	assign w471 = pla_vcnt[25] | pla_vcnt[26] | pla_vcnt[27]
		| pla_vcnt[28] | pla_vcnt[29];
	assign w472 = pla_vcnt[17] | pla_vcnt[18] | pla_vcnt[19] | pla_vcnt[20]
		| pla_vcnt[21] | pla_vcnt[22] | pla_vcnt[23] | pla_vcnt[24];
	assign w473 = pla_vcnt[9] | pla_vcnt[10] | pla_vcnt[11] | pla_vcnt[12]
		| pla_vcnt[13] | pla_vcnt[14] | pla_vcnt[15] | pla_vcnt[16];
	assign w474 = pla_vcnt[1] | pla_vcnt[2] | pla_vcnt[3] | pla_vcnt[4]
		| pla_vcnt[5] | pla_vcnt[6] | pla_vcnt[7] | pla_vcnt[8];
	assign w475 = ~pla_vcnt[0];

	assign w476 = pla_hcnt1[60] | pla_hcnt1[61] | pla_hcnt1[62];
	assign w477 = pla_hcnt1[50] | pla_hcnt1[57] | pla_hcnt1[58] | pla_hcnt1[59];
	assign w478 = pla_hcnt1[49] | pla_hcnt1[55] | pla_hcnt1[56];
	assign w479 = pla_hcnt1[47] | pla_hcnt1[48] | pla_hcnt1[53] | pla_hcnt1[54];
	assign w480 = pla_hcnt1[45] | pla_hcnt1[46] | pla_hcnt1[51] | pla_hcnt1[52];
	assign w481 = pla_hcnt1[5] | pla_hcnt1[6] | pla_hcnt1[36] |
		pla_hcnt1[37] | pla_hcnt1[38] | pla_hcnt1[39];
	assign w482 = pla_hcnt1[7] | pla_hcnt1[8] | pla_hcnt1[9] | pla_hcnt1[10]
		| pla_hcnt1[11] | pla_hcnt1[12] | pla_hcnt1[13] | pla_hcnt1[14]
		| pla_hcnt1[15] | pla_hcnt1[16] | pla_hcnt1[17] | pla_hcnt1[18]
		| pla_hcnt1[19] | pla_hcnt1[20] | pla_hcnt1[21] | pla_hcnt1[22]
		| pla_hcnt1[24] | pla_hcnt1[25] | pla_hcnt1[26] | pla_hcnt1[27]
		| pla_hcnt1[32] | pla_hcnt1[33] | pla_hcnt1[34] | pla_hcnt1[35];
	assign w483 = pla_hcnt1[44];
	assign w484 = pla_hcnt1[0] | pla_hcnt1[1] | pla_hcnt1[2] | pla_hcnt1[3] | pla_hcnt1[4];
	assign w485 = pla_hcnt1[36] | pla_hcnt1[37] | pla_hcnt1[38] | pla_hcnt1[39]
		| pla_hcnt1[43];
	assign w486 = w403 | pla_hcnt1[40] | pla_hcnt1[41] | pla_hcnt1[42];
	assign w487 = pla_hcnt1[7] | pla_hcnt1[8] | pla_hcnt1[9] | pla_hcnt1[10]
		| pla_hcnt1[11] | pla_hcnt1[12] | pla_hcnt1[13] | pla_hcnt1[14]
		| pla_hcnt1[17] | pla_hcnt1[18] | pla_hcnt1[19] | pla_hcnt1[22] | pla_hcnt1[23]
		| pla_hcnt1[24] | pla_hcnt1[25] | pla_hcnt1[26] | pla_hcnt1[27]
		| pla_hcnt1[40] | pla_hcnt1[41] | pla_hcnt1[42]
		| pla_hcnt1[46] | pla_hcnt1[47] | pla_hcnt1[48]
		| pla_hcnt1[49] | pla_hcnt1[50];
	assign w488 = pla_hcnt1[23];
	assign w489 = pla_hcnt1[31] | pla_hcnt1[28] | pla_hcnt1[29] | pla_hcnt1[30];

	assign w490 = pla_hcnt2[44] | pla_hcnt2[45];
	assign w491 = pla_hcnt2[42] | pla_hcnt2[43];
	assign w492 = pla_hcnt2[40] | pla_hcnt2[41];
	assign w493 = pla_hcnt2[38] | pla_hcnt2[39];
	assign w494 = pla_hcnt2[36] | pla_hcnt2[37];
	assign w495 = pla_hcnt2[34] | pla_hcnt2[35];
	assign w496 = pla_hcnt2[32] | pla_hcnt2[33];
	assign w497 = pla_hcnt2[30] | pla_hcnt2[31];
	assign w498 = pla_hcnt2[28] | pla_hcnt2[29];
	assign w499 = pla_hcnt2[24] | pla_hcnt2[25] | pla_hcnt2[26] | pla_hcnt2[27];
	assign w500 = pla_hcnt2[22] | pla_hcnt2[23];
	assign w501 = pla_hcnt2[20] | pla_hcnt2[21];
	assign w502 = ~(pla_hcnt2[17] | pla_hcnt2[18] | pla_hcnt2[19]);
	assign w503 = pla_hcnt2[15] | pla_hcnt2[16];
	assign w504 = pla_hcnt2[14];
	assign w505 = ~(pla_hcnt2[12] | pla_hcnt2[13]);
	assign w506 = pla_hcnt2[11];
	assign w507 = pla_hcnt2[9] | pla_hcnt2[10];
	assign w508 = pla_hcnt2[8];
	assign w509 = pla_hcnt2[4] | pla_hcnt2[5] | pla_hcnt2[6] | pla_hcnt2[7];
	assign w510 = pla_hcnt2[2] | pla_hcnt2[3];
	assign w511 = pla_hcnt2[1];
	assign w512 = pla_hcnt2[0];
	
	ym_sr_bit sr663(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(t35), .sr_out(l663));
	
	assign VSYNC = w374;
	assign CSYNC_pull = ~l128;
	assign HSYNC_pull = ~l136;

	// Plane block
	
	assign w513 = (hclk1 & w379) | reg_test1[7];
	
	ym_sr_bit sr178(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l106[3]), .sr_out(l178));
	
	assign w514 = hclk1 & l115 & (reg_m5 | l162);
	
	ym_slatch #(.DATA_WIDTH(8)) sl179(.MCLK(MCLK), .en(w230), .inp(reg_data_l2[7:0]), .val(l179));
	
	assign w515 = reg_m5 ? vsram_out : { 3'h0, l179 };
	
	ym_slatch #(.DATA_WIDTH(11)) sl180(.MCLK(MCLK), .en(w516), .inp(vsram_out), .val(l180));
	
	ym_sr_bit_array #(.DATA_WIDTH(11)) sr181(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in({ l182, l104 }), .data_out(l181));
	
	ym_sr_bit_array #(.DATA_WIDTH(3)) sr182(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(vram_data[10:8]), .data_out(l182));
	
	ym_sr_bit sr183(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l209), .sr_out(l183));
	
	assign w516 = l209 & hclk1;
	
	assign w517 = w514 | reg_test1[7];
	
	ym_slatch #(.DATA_WIDTH(11)) sl184(.MCLK(MCLK), .en(w517), .inp(w515), .val(l184));
	
	ym_slatch #(.DATA_WIDTH(11)) sl185(.MCLK(MCLK), .en(w513), .inp(vsram_out), .val(l185));
	
	ym_sr_bit sr186(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w519), .sr_out(l186));
	
	assign w518 = { l184[10:8], l186 ? l184[7:0] : 8'h0 };
	
	assign w519 = ~(l106[7:6] == 2'h3 & reg_80_b7);
	
	assign w520 = reg_m5 & (l178 | reg_vscr);
	
	assign w521 = w520 ? l185 : w518;
	
	assign w522 = w521 + { 2'h0, w355[8:0] };
	
	ym_slatch #(.DATA_WIDTH(2)) sl_hsz(.MCLK(MCLK), .en(w224), .inp(reg_data_l2[1:0]), .val(reg_hsz));
	
	ym_slatch #(.DATA_WIDTH(2)) sl_vsz(.MCLK(MCLK), .en(w224), .inp(reg_data_l2[5:4]), .val(reg_vsz));
	
	assign w523 = reg_hsz == 2'h0;
	
	assign w524 = reg_hsz == 2'h1;
	
	assign w525 = reg_hsz == 2'h3;
	
	assign w526 = w106 ? w522[10:4] : w522[9:3];
	
	assign w527 =
		( w523 ? w528 : 7'h0 ) |
		( w524 ? { w528[5:0], w555[5] }: 7'h0 ) |
		( w525 ? { w528[4:0], w555[6:5] } : 7'h0 );
	
	wire [2:0] w528_sum = w526[4:2] + { 2'h0, w529 };
	
	assign w528 = { reg_vsz[1] & w526[6], reg_vsz[0] & w526[5], w528_sum, w526[1:0] };
	
	assign w529 = ~reg_m5 & w530;
	
	assign w530 = w526[4:2] == 3'h7 | w526[5];
	
	assign w531 = reg_m5 & w558;
	
	ym_slatch #(.DATA_WIDTH(4)) sl_sa(.MCLK(MCLK), .en(w218), .inp(reg_data_l2[6:3]), .val(reg_sa));
	
	ym_slatch #(.DATA_WIDTH(2)) sl_nt(.MCLK(MCLK), .en(w218), .inp(reg_data_l2[2:1]), .val(reg_nt));
	
	ym_slatch #(.DATA_WIDTH(4)) sl_sb(.MCLK(MCLK), .en(w220), .inp(reg_data_l2[3:0]), .val(reg_sb));
	
	assign w532 = l200 ? reg_sb : reg_sa;
	
	assign w533 = reg_m5 ? w527[6:5] : reg_nt;
	
	ym_slatch sl_8e_b0(.MCLK(MCLK), .en(w232), .inp(reg_data_l2[0]), .val(reg_8e_b0));
	
	ym_slatch sl_8e_b4(.MCLK(MCLK), .en(w232), .inp(reg_data_l2[4]), .val(reg_8e_b4));
	
	assign w534 = l106[8:7] != 2'h3;
	
	assign w535 = { reg_hscr ? w537[7:3] : 5'h0, reg_lscr ? w537[2:0] : 3'h0 };
	
	assign w536 = reg_rs1 ?
		{ w537[7:3], l106[8] } :
		{ reg_wd[0], w537[7:3] };
	
	ym_slatch #(.DATA_WIDTH(6)) sl_wd(.MCLK(MCLK), .en(w219), .inp(reg_data_l2[6:1]), .val(reg_wd));
	
	ym_slatch #(.DATA_WIDTH(7)) sl_hs(.MCLK(MCLK), .en(w233), .inp(reg_data_l2[6:0]), .val(reg_hs));
	
	assign w537 = w106 ? w355[8:1] : w355[7:0];
	
	assign w538 = w546 ^ ~l187;
	
	assign w539 = w538 & w534;
	
	assign w540 = w545 ^ l189;
	
	assign w541 = (w540 | w539) & ~l106[3] & reg_m5;
	
	ym_slatch #(.DATA_WIDTH(5)) sl_whp(.MCLK(MCLK), .en(w223), .inp(reg_data_l2[4:0]), .val(reg_whp));
	
	ym_slatch sl_rigt(.MCLK(MCLK), .en(w223), .inp(reg_data_l2[7]), .val(reg_rigt));
	
	ym_slatch #(.DATA_WIDTH(5)) sl_wvp(.MCLK(MCLK), .en(w222), .inp(reg_data_l2[4:0]), .val(reg_wvp));
	
	ym_slatch sl_down(.MCLK(MCLK), .en(w222), .inp(reg_data_l2[7]), .val(reg_down));
	
	assign w542 = reg_test1[7] | l115;
	
	assign w543 = l115 & (reg_m5 | l162);
	
	assign w544 = w543 | reg_test1[7];
	
	ym_slatch sl187(.MCLK(MCLK), .en(w542), .inp(reg_rigt), .val(l187));
	
	ym_slatch #(.DATA_WIDTH(5)) sl188(.MCLK(MCLK), .en(w542), .inp(reg_whp), .val(l188));
	
	ym_slatch sl189(.MCLK(MCLK), .en(w544), .inp(reg_down), .val(l189));
	
	ym_slatch #(.DATA_WIDTH(5)) sl190(.MCLK(MCLK), .en(w544), .inp(reg_wvp), .val(l190));
	
	assign w545 = w537[7:3] < l190;
	
	assign w546 = l188 <= l106[8:4];
	
	assign w547 = reg_test1[7] | l115;
	
	ym_slatch #(.DATA_WIDTH(8)) sl_88(.MCLK(MCLK), .en(w231), .inp(reg_data_l2[7:0]), .val(reg_88));
	
	ym_slatch #(.DATA_WIDTH(8)) sl191(.MCLK(MCLK), .en(w570), .inp(vram_serial), .val(l191));
	
	ym_slatch #(.DATA_WIDTH(8)) sl192(.MCLK(MCLK), .en(w572), .inp(vram_serial), .val(l192));
	
	assign w548 = w394 | w385;
	
	assign w549 = w372 | (reg_test1[8] & cpu_pen);
	
	assign w550 = w394 & ~reg_m5;
	
	assign w551 = w550 | w385;
	
	assign w552 = ~(~reg_80_b6 | w355[5] | w355[6] | w355[4] | w355[7]);
	
	assign w553 = w552 | reg_m5;
	
	ym_slatch #(.DATA_WIDTH(8)) sl193(.MCLK(MCLK), .en(w547), .inp(reg_88), .val(l193));
	
	assign w554 = ~(
		(~w553 ? { 2'h0, l193 } : 10'h0) |
		(w574 ? { l194, l191 } : 10'h0) |
		(w575 ? { l195, l192 } : 10'h0)
		);
	
	ym_slatch #(.DATA_WIDTH(2)) sl194(.MCLK(MCLK), .en(w571), .inp(vram_serial[1:0]), .val(l194));
	
	ym_slatch #(.DATA_WIDTH(2)) sl195(.MCLK(MCLK), .en(w573), .inp(vram_serial[1:0]), .val(l195));
	
	assign w555 = { w554[9:4], w564 } + { w567, w565, w563 } + 7'h1;
	
	ym_sr_bit sr196(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w548), .sr_out(l196));
	
	ym_sr_bit sr197(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l106[3]), .sr_out(l197));
	
	ym_sr_bit sr198(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(~w550), .sr_out(l198));
	
	ym_sr_bit sr199(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w551), .sr_out(l199));
	
	assign w556 = reg_m5 & ~reg_test1[8] & w549;
	
	ym_sr_bit sr200(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w556), .sr_out(l200));
	
	assign w557 = ~w541 & w356;
	
	ym_sr_bit sr201(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w557), .sr_out(l201));
	
	assign w558 = l200 | l201;
	
	assign w559 = w356 & w541;
	
	ym_sr_bit sr202(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w559), .sr_out(l202));
	
	assign w560 = w356 | w549;
	
	ym_sr_bit sr203(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w560), .sr_out(l203));
	
	ym_sr_bit sr204(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l203), .sr_out(l204));
	
	ym_sr_bit sr205(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l204), .sr_out(l205));
	
	assign w561 = reg_rs1 ? w568 : l106[8];
	
	assign w562 = ~(w561 | reg_m5);
	
	assign w563 = w562 & l106[3];
	
	assign w564 = w554[3] | reg_m5;
	
	assign w565 = w561 ? 4'hf : l106[7:4];
	
	assign w566 = reg_m5 & l199;
	
	assign w567 = w561 ? reg_hsz : { w568, l106[8] };
	
	assign w568 = l106[8] & (l106[7] | l106[6]);
	
	ym_sr_bit sr206(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w201), .sr_out(l206));
	
	ym_sr_bit sr207(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w323), .sr_out(l207));
	
	ym_sr_bit sr208(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w324), .sr_out(l208));
	
	ym_sr_bit sr209(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l206), .sr_out(l209));
	
	ym_sr_bit sr210(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l207), .sr_out(l210));
	
	ym_sr_bit sr211(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l208), .sr_out(l211));
	
	assign w569 = l206 | l207 | l208;
	
	ym_sr_bit_array #(.DATA_WIDTH(6)) sr212(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(w626), .data_out(l212));
	
	ym_dlatch_1 dl213(.MCLK(MCLK), .c1(clk1), .inp(~(hclk1 & l316)), .nval(l213));
	
	assign w570 = l213 & clk2;
	
	ym_sr_bit sr214(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l213), .sr_out(l214));
	
	assign w571 = l214 & clk2;
	
	ym_sr_bit sr215(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l214), .sr_out(l215));
	
	assign w572 = l215 & clk2;
	
	ym_sr_bit sr216(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l215), .sr_out(l216));
	
	assign w573 = l216 & clk2;
	
	assign w574 = ~w541 & reg_m5 & ~l106[3];
	
	assign w575 = ~w541 & reg_m5 & l106[3];
	
	assign w576 = l217 ? w355[3:0] : w522[3:0];
	
	assign w577 = w583 ? ~w576 : w576;
	
	assign w578 = w106 ? { l219, w577[3] } : { l220[0], l219 };
	
	assign w579 = w106 ? l220[2:0] : { w581, l220[2:1] };
	
	assign w580 = w106 ? { l222[2:0], l221, w577[3] } : { w581, l222[2:0], l221 };
	
	assign w581 = l197 ? reg_8e_b4 : reg_8e_b0;
	
	ym_sr_bit sr217(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w541), .sr_out(l217));
	
	assign w582 = w394 & reg_m5;
	
	ym_sr_bit sr218(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w582), .sr_out(l218));
	
	assign w583 = l218 ? l222[4] : w585;
	
	ym_slatch #(.DATA_WIDTH(8)) sl219(.MCLK(MCLK), .en(w615), .inp(vram_serial), .val(l219));
	
	ym_slatch #(.DATA_WIDTH(8)) sl220(.MCLK(MCLK), .en(w616), .inp(vram_serial), .val(l220));
	
	ym_slatch #(.DATA_WIDTH(8)) sl221(.MCLK(MCLK), .en(w617), .inp(vram_serial), .val(l221));
	
	ym_slatch #(.DATA_WIDTH(8)) sl222(.MCLK(MCLK), .en(w618), .inp(vram_serial), .val(l222));
	
	assign w584 = reg_m5 ? l220[3] : l220[1];
	assign w585 = reg_m5 ? l220[4] : l220[2];
	assign w586 = reg_m5 ? l220[6:5] : { 1'h0, l220[3] };
	assign w587 = reg_m5 ? l220[7] : l220[4];
	
	ym_slatch #(.DATA_WIDTH(8)) sl223(.MCLK(MCLK), .en(w591), .inp(vram_serial), .val(l223));
	
	ym_slatch #(.DATA_WIDTH(8)) sl224(.MCLK(MCLK), .en(w590), .inp(vram_serial), .val(l224));
	
	ym_slatch #(.DATA_WIDTH(8)) sl225(.MCLK(MCLK), .en(w589), .inp(vram_serial), .val(l225));
	
	ym_slatch #(.DATA_WIDTH(8)) sl226(.MCLK(MCLK), .en(w588), .inp(vram_serial), .val(l226));
	
	ym_dlatch_1 dl227(.MCLK(MCLK), .c1(clk1), .inp(w613), .nval(l227));
	
	ym_sr_bit sr228(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l227), .sr_out(l228));
	
	ym_sr_bit sr229(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l228), .sr_out(l229));
	
	ym_sr_bit sr230(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l229), .sr_out(l230));
	
	ym_sr_bit sr231(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l230), .sr_out(l231));
	
	assign w588 = l227 & clk2;
	
	assign w589 = l228 & clk2;
	
	assign w590 = l229 & clk2;
	
	assign w591 = l230 & clk2;
	
	ym_slatch #(.DATA_WIDTH(8)) sl232(.MCLK(MCLK), .en(w592), .inp(l223), .val(l232));
	
	ym_slatch #(.DATA_WIDTH(8)) sl233(.MCLK(MCLK), .en(w592), .inp(l224), .val(l233));
	
	ym_slatch #(.DATA_WIDTH(8)) sl234(.MCLK(MCLK), .en(w592), .inp(l225), .val(l234));
	
	ym_slatch #(.DATA_WIDTH(8)) sl235(.MCLK(MCLK), .en(w592), .inp(l226), .val(l235));
	
	assign w592 = w598 & clk2;
	
	ym_slatch #(.DATA_WIDTH(4)) sl236(.MCLK(MCLK), .en(l242), .inp(w554[3:0]), .val(l236));
	
	assign w593 = w614 & l236 == 4'hf;
	
	ym_slatch #(.DATA_WIDTH(8)) sl237(.MCLK(MCLK), .en(w611), .inp(l232), .val(l237));
	
	ym_slatch #(.DATA_WIDTH(8)) sl238(.MCLK(MCLK), .en(w611), .inp(l233), .val(l238));
	
	ym_slatch #(.DATA_WIDTH(8)) sl239(.MCLK(MCLK), .en(w611), .inp(l234), .val(l239));
	
	ym_slatch #(.DATA_WIDTH(8)) sl240(.MCLK(MCLK), .en(w611), .inp(l235), .val(l240));
	
	ym_cnt_bit_load #(.DATA_WIDTH(4)) cnt241(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(1'h1), .reset(1'h0), .load(w614), .load_val(l236), .val(l241));
	
	ym_sr_bit sr242(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w614), .sr_out(l242));
	
	ym_slatch #(.DATA_WIDTH(8)) sl243(.MCLK(MCLK), .en(w597), .inp(vram_serial), .val(l243));
	
	ym_slatch #(.DATA_WIDTH(8)) sl244(.MCLK(MCLK), .en(w596), .inp(vram_serial), .val(l244));
	
	ym_slatch #(.DATA_WIDTH(8)) sl245(.MCLK(MCLK), .en(w595), .inp(vram_serial), .val(l245));
	
	ym_slatch #(.DATA_WIDTH(8)) sl246(.MCLK(MCLK), .en(w594), .inp(vram_serial), .val(l246));
	
	ym_dlatch_1 dl247(.MCLK(MCLK), .c1(clk1), .inp(w600), .nval(l247));
	
	ym_sr_bit sr248(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l247), .sr_out(l248));
	
	ym_sr_bit sr249(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l248), .sr_out(l249));
	
	ym_sr_bit sr250(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l249), .sr_out(l250));
	
	assign w594 = l247 & clk2;
	
	assign w595 = l248 & clk2;
	
	assign w596 = l249 & clk2;
	
	assign w597 = l250 & clk2;
	
	ym_dlatch_1 dl251(.MCLK(MCLK), .c1(clk1), .inp(w633), .nval(l251));
	
	ym_sr_bit sr252(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l251), .sr_out(l252));
	
	ym_sr_bit sr253(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l252), .sr_out(l253));
	
	ym_sr_bit sr254(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l253), .sr_out(l254));
	
	ym_slatch #(.DATA_WIDTH(8)) sl255(.MCLK(MCLK), .en(w592), .inp(l243), .val(l255));
	
	ym_slatch #(.DATA_WIDTH(8)) sl256(.MCLK(MCLK), .en(w592), .inp(l244), .val(l256));
	
	ym_slatch #(.DATA_WIDTH(8)) sl257(.MCLK(MCLK), .en(w592), .inp(l245), .val(l257));
	
	ym_slatch #(.DATA_WIDTH(8)) sl258(.MCLK(MCLK), .en(w592), .inp(l246), .val(l258));
	
	ym_slatch #(.DATA_WIDTH(8)) sl259(.MCLK(MCLK), .en(w591),
		.inp({ w587, l222[7], w586[1], l222[6], w586[0], l222[5], w584, l222[3] }), .val(l259));
	
	ym_slatch #(.DATA_WIDTH(8)) sl260(.MCLK(MCLK), .en(w592), .inp(l259), .val(l260));
	
	ym_slatch #(.DATA_WIDTH(8)) sl261(.MCLK(MCLK), .en(w611), .inp(l255), .val(l261));
	
	ym_slatch #(.DATA_WIDTH(8)) sl262(.MCLK(MCLK), .en(w611), .inp(l256), .val(l262));
	
	ym_slatch #(.DATA_WIDTH(8)) sl263(.MCLK(MCLK), .en(w611), .inp(l257), .val(l263));
	
	ym_slatch #(.DATA_WIDTH(8)) sl264(.MCLK(MCLK), .en(w611), .inp(l258), .val(l264));
	
	ym_slatch #(.DATA_WIDTH(8)) sl265(.MCLK(MCLK), .en(w611), .inp(l260), .val(l265));
	
	assign w598 = reg_m5 ? l302 : l231;
	
	assign w599 = reg_m5 & l241[3];
	
	assign w600 = ~(hclk1 & w612);
	
	assign w601 = reg_m5 ^ l241[1];
	
	assign w602 = w599 ? l265[0] : l265[1];
	
	assign w603 = w599 ? l265[2] : l265[3];
	
	assign w604 = w599 ? l265[4] : l265[5];
	
	assign w605 = w599 ? l265[6] : l265[7];
	
	wire[2:0] w606_t = { l241[2], w601, l241[0] };
	
	assign w606 = w602 ? ~w606_t : w606_t;
	
	wire [7:0] w606_sel;
	
	assign w606_sel[0] = w606 == 3'h0;
	assign w606_sel[1] = w606 == 3'h1;
	assign w606_sel[2] = w606 == 3'h2;
	assign w606_sel[3] = w606 == 3'h3;
	assign w606_sel[4] = w606 == 3'h4;
	assign w606_sel[5] = w606 == 3'h5;
	assign w606_sel[6] = w606 == 3'h6;
	assign w606_sel[7] = w606 == 3'h7;
	
	wire [3:0] w607_m4 =
		(w606_sel[0] ? { l239[7], l240[7], l263[7], l264[7] } : 4'h0 ) |
		(w606_sel[1] ? { l239[6], l240[6], l263[6], l264[6] } : 4'h0 ) |
		(w606_sel[2] ? { l239[5], l240[5], l263[5], l264[5] } : 4'h0 ) |
		(w606_sel[3] ? { l239[4], l240[4], l263[4], l264[4] } : 4'h0 ) |
		(w606_sel[4] ? { l239[3], l240[3], l263[3], l264[3] } : 4'h0 ) |
		(w606_sel[5] ? { l239[2], l240[2], l263[2], l264[2] } : 4'h0 ) |
		(w606_sel[6] ? { l239[1], l240[1], l263[1], l264[1] } : 4'h0 ) |
		(w606_sel[7] ? { l239[0], l240[0], l263[0], l264[0] } : 4'h0 );
	
	wire [3:0] w607_m5_1 =
		(w606_sel[7] ? l261[3:0] : 4'h0) |
		(w606_sel[6] ? l261[7:4] : 4'h0) |
		(w606_sel[5] ? l262[3:0] : 4'h0) |
		(w606_sel[4] ? l262[7:4] : 4'h0) |
		(w606_sel[3] ? l263[3:0] : 4'h0) |
		(w606_sel[2] ? l263[7:4] : 4'h0) |
		(w606_sel[1] ? l264[3:0] : 4'h0) |
		(w606_sel[0] ? l264[7:4] : 4'h0);
	
	wire [3:0] w607_m5_2 =
		(w606_sel[7] ? l237[3:0] : 4'h0) |
		(w606_sel[6] ? l237[7:4] : 4'h0) |
		(w606_sel[5] ? l238[3:0] : 4'h0) |
		(w606_sel[4] ? l238[7:4] : 4'h0) |
		(w606_sel[3] ? l239[3:0] : 4'h0) |
		(w606_sel[2] ? l239[7:4] : 4'h0) |
		(w606_sel[1] ? l240[3:0] : 4'h0) |
		(w606_sel[0] ? l240[7:4] : 4'h0);
	
	assign w607 =
		(~reg_m5 ? w607_m4 : 4'h0) |
		((reg_m5 & ~l241[3]) ? w607_m5_1 : 4'h0) |
		((reg_m5 & l241[3]) ? w607_m5_2 : 4'h0);
	
	assign w608 = l241[3] | ~reg_m5;
	
	assign w609 = w608 & l241[2:0] == 3'h7;
	
	assign w610 = ~(w609 | w593);
	
	ym_dlatch_1 dl266(.MCLK(MCLK), .c1(hclk1), .inp(w610), .nval(l266));
	
	assign w611 = hclk2 & l266;
	
	assign w612 = w393 | (reg_test1[9] & cpu_pen);
	
	ym_sr_bit sr267(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w612), .sr_out(l267));
	
	ym_sr_bit sr268(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l267), .sr_out(l268));
	
	assign w613 = ~(l268 & hclk1);
	
	ym_sr_bit_array #(.DATA_WIDTH(4)) sr269(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(w607), .data_out(l269));
	
	ym_sr_bit_array #(.DATA_WIDTH(4)) sr270(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l269), .data_out(l270));
	
	ym_sr_bit_array #(.DATA_WIDTH(2)) sr271(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in({ w604, w603 }), .data_out(l271));
	
	ym_sr_bit_array #(.DATA_WIDTH(2)) sr272(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l271), .data_out(l272));
	
	ym_sr_bit sr273(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w605), .sr_out(l273));
	
	ym_sr_bit sr274(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l273), .sr_out(l274));
	
	assign w614 = w424 | w90;
	
	ym_slatch #(.DATA_WIDTH(8)) sl275(.MCLK(MCLK), .en(w622), .inp(vram_serial), .val(l275));
	
	ym_slatch #(.DATA_WIDTH(8)) sl276(.MCLK(MCLK), .en(w621), .inp(vram_serial), .val(l276));
	
	ym_slatch #(.DATA_WIDTH(8)) sl277(.MCLK(MCLK), .en(w620), .inp(vram_serial), .val(l277));
	
	ym_slatch #(.DATA_WIDTH(8)) sl278(.MCLK(MCLK), .en(w619), .inp(vram_serial), .val(l278));
	
	ym_slatch #(.DATA_WIDTH(8)) sl279(.MCLK(MCLK), .en(w631), .inp(l275), .val(l279));
	
	ym_slatch #(.DATA_WIDTH(8)) sl280(.MCLK(MCLK), .en(w631), .inp(l276), .val(l280));
	
	ym_slatch #(.DATA_WIDTH(8)) sl281(.MCLK(MCLK), .en(w631), .inp(l277), .val(l281));
	
	ym_slatch #(.DATA_WIDTH(8)) sl282(.MCLK(MCLK), .en(w631), .inp(l278), .val(l282));
	
	assign w615 = l251 & clk2;
	assign w616 = l252 & clk2;
	assign w617 = l253 & clk2;
	assign w618 = l254 & clk2;
	
	ym_dlatch_1 dl283(.MCLK(MCLK), .c1(clk1), .inp(w640), .nval(l283));
	
	ym_sr_bit sr284(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l283), .sr_out(l284));
	
	ym_sr_bit sr285(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l284), .sr_out(l285));
	
	ym_sr_bit sr286(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l285), .sr_out(l286));
	
	assign w619 = l283 & clk2;
	assign w620 = l284 & clk2;
	assign w621 = l285 & clk2;
	assign w622 = l286 & clk2;
	
	ym_slatch #(.DATA_WIDTH(8)) sl287(.MCLK(MCLK), .en(w645), .inp(l279), .val(l287));
	
	ym_slatch #(.DATA_WIDTH(8)) sl288(.MCLK(MCLK), .en(w645), .inp(l280), .val(l288));
	
	ym_slatch #(.DATA_WIDTH(8)) sl289(.MCLK(MCLK), .en(w645), .inp(l281), .val(l289));
	
	ym_slatch #(.DATA_WIDTH(8)) sl290(.MCLK(MCLK), .en(w645), .inp(l282), .val(l290));
	
	ym_slatch #(.DATA_WIDTH(8)) sl291(.MCLK(MCLK), .en(w631),
		.inp({ w587, l222[7], w586[1], l222[6], w586[0], l222[5], w584, l222[3] }), .val(l291));
	
	ym_slatch #(.DATA_WIDTH(8)) sl292(.MCLK(MCLK), .en(w645), .inp(l291), .val(l292));
	
	assign w623 = ~(reg_m5 & reg_vscr);
	
	ym_sr_bit_array #(.DATA_WIDTH(6)) sr293(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(vram_address[6:1]), .data_out(l293));
	
	assign w624 = w623 ^ l106[3];
	
	assign w625 = reg_vscr ? l106[8:4] : 5'h0;
	
	assign w626 = w569 ? l293 : { w625, w624 };
	
	ym_slatch #(.DATA_WIDTH(8)) sl294(.MCLK(MCLK), .en(w630), .inp(vram_serial), .val(l294));
	
	ym_slatch #(.DATA_WIDTH(8)) sl295(.MCLK(MCLK), .en(w629), .inp(vram_serial), .val(l295));
	
	ym_slatch #(.DATA_WIDTH(8)) sl296(.MCLK(MCLK), .en(w628), .inp(vram_serial), .val(l296));
	
	ym_slatch #(.DATA_WIDTH(8)) sl297(.MCLK(MCLK), .en(w627), .inp(vram_serial), .val(l297));
	
	ym_dlatch_1 dl298(.MCLK(MCLK), .c1(clk1), .inp(w639), .nval(l298));
	
	ym_sr_bit sr299(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l298), .sr_out(l299));
	
	ym_sr_bit sr300(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l299), .sr_out(l300));
	
	ym_sr_bit sr301(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l300), .sr_out(l301));
	
	ym_sr_bit sr302(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l301), .sr_out(l302));
	
	assign w627 = l298 & clk2;
	
	assign w628 = l299 & clk2;
	
	assign w629 = l300 & clk2;
	
	assign w630 = l301 & clk2;
	
	assign w631 = l302 & clk2;
	
	ym_slatch #(.DATA_WIDTH(8)) sl303(.MCLK(MCLK), .en(w631), .inp(l294), .val(l303));
	
	ym_slatch #(.DATA_WIDTH(8)) sl304(.MCLK(MCLK), .en(w631), .inp(l295), .val(l304));
	
	ym_slatch #(.DATA_WIDTH(8)) sl305(.MCLK(MCLK), .en(w631), .inp(l296), .val(l305));
	
	ym_slatch #(.DATA_WIDTH(8)) sl306(.MCLK(MCLK), .en(w631), .inp(l297), .val(l306));
	
	ym_slatch #(.DATA_WIDTH(8)) sl307(.MCLK(MCLK), .en(w645), .inp(l303), .val(l307));
	
	ym_slatch #(.DATA_WIDTH(8)) sl308(.MCLK(MCLK), .en(w645), .inp(l304), .val(l308));
	
	ym_slatch #(.DATA_WIDTH(8)) sl309(.MCLK(MCLK), .en(w645), .inp(l305), .val(l309));
	
	ym_slatch #(.DATA_WIDTH(8)) sl310(.MCLK(MCLK), .en(w645), .inp(l306), .val(l310));
	
	ym_cnt_bit_load #(.DATA_WIDTH(4)) cnt311(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(1'h1), .reset(1'h0), .load(w649), .load_val({~w554[3], w554[2:0]}), .val(l311));
	
	wire [2:0] w632_t = l311[2:0];
	
	assign w632 = w634 ? ~w632_t : w632_t;
	
	assign w633 = ~(hclk1 & l205);
	
	assign w634 = l311[3] ? l292[0] : l292[1];
	assign w635 = l311[3] ? l292[2] : l292[3];
	assign w636 = l311[3] ? l292[4] : l292[5];
	assign w637 = l311[3] ? l292[6] : l292[7];
	
	assign w638 = w402 | (reg_test1[10] & cpu_pen);
	
	ym_sr_bit sr312(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w638), .sr_out(l312));
	
	ym_sr_bit sr313(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l312), .sr_out(l313));
	
	assign w639 = ~(hclk1 & l313);
	
	assign w640 = ~(hclk1 & w638);
	
	assign w641 = { w632[2], ~w632[1], w632[0] };
	
	assign w642 = w419 | (reg_test1[7] & cpu_pen);
	
	ym_sr_bit sr314(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w642), .sr_out(l314));
	
	ym_sr_bit sr315(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l314), .sr_out(l315));
	
	ym_sr_bit sr316(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l315), .sr_out(l316));
	
	assign w643 = l314 & ~reg_test1[7];
	
	assign w644 = ~(l311 == 4'hf);
	
	ym_dlatch_1 dl317(.MCLK(MCLK), .c1(hclk1), .inp(w644), .nval(l317));
	
	assign w645 = l317 & hclk2;
	
	assign w646 = l269 != 4'h0;
	
	wire [7:0] w641_sel;
	
	assign w641_sel[0] = w641 == 3'h0;
	assign w641_sel[1] = w641 == 3'h1;
	assign w641_sel[2] = w641 == 3'h2;
	assign w641_sel[3] = w641 == 3'h3;
	assign w641_sel[4] = w641 == 3'h4;
	assign w641_sel[5] = w641 == 3'h5;
	assign w641_sel[6] = w641 == 3'h6;
	assign w641_sel[7] = w641 == 3'h7;
	
	wire [3:0] w647_1 =
		(w641_sel[7] ? l307[3:0] : 4'h0) |
		(w641_sel[6] ? l307[7:4] : 4'h0) |
		(w641_sel[5] ? l308[3:0] : 4'h0) |
		(w641_sel[4] ? l308[7:4] : 4'h0) |
		(w641_sel[3] ? l309[3:0] : 4'h0) |
		(w641_sel[2] ? l309[7:4] : 4'h0) |
		(w641_sel[1] ? l310[3:0] : 4'h0) |
		(w641_sel[0] ? l310[7:4] : 4'h0);
	
	wire [3:0] w647_2 =
		(w641_sel[7] ? l287[3:0] : 4'h0) |
		(w641_sel[6] ? l287[7:4] : 4'h0) |
		(w641_sel[5] ? l288[3:0] : 4'h0) |
		(w641_sel[4] ? l288[7:4] : 4'h0) |
		(w641_sel[3] ? l289[3:0] : 4'h0) |
		(w641_sel[2] ? l289[7:4] : 4'h0) |
		(w641_sel[1] ? l290[3:0] : 4'h0) |
		(w641_sel[0] ? l290[7:4] : 4'h0);
	
	assign w647 =
		(l311[3] ? w647_1 : 4'h0) |
		(~l311[3] ? w647_2 : 4'h0);
	
	ym_sr_bit_array #(.DATA_WIDTH(4)) sr318(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(w647), .data_out(l318));
	
	ym_sr_bit_array #(.DATA_WIDTH(4)) sr319(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l318), .data_out(l319));
	
	assign w648 = l318 != 4'h0;
	
	ym_sr_bit sr320(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w637), .sr_out(l320));
	
	ym_sr_bit sr321(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l320), .sr_out(l321));
	
	ym_sr_bit_array #(.DATA_WIDTH(2)) sr322(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in({w636, w635}), .data_out(l322));
	
	ym_sr_bit_array #(.DATA_WIDTH(2)) sr323(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l322), .data_out(l323));
	
	assign w649 = w92 | w415;
	
	// vsram
	
	wire [5:0] vsram_index = l212;
	
	always @(posedge MCLK)
	begin
		if (vsram_index < 6'd40)
		begin
			if (hclk1) // write cycle
			begin
				if (l211)
					vsram[vsram_index][7:0] <= l181[7:0];
				if (l210)
					vsram[vsram_index][10:8] <= l181[10:8];
			end
			vsram_out <= vsram[vsram_index];
			if (vsram_index[0])
				vsram_out_1 <= vsram[vsram_index];
			else
				vsram_out_0 <= vsram[vsram_index];
		end
		else
		begin
			if (vsram_index[0])
				vsram_out <= vsram_out & vsram_out_1;
			else
				vsram_out <= vsram_out & vsram_out_0;
		end
	end
	
	
	// Sprite block
	
	assign w650 = l325 ? { sat_size, sat_link } : sat_ypos;
	
	ym_slatch #(.DATA_WIDTH(11)) sl324(.MCLK(MCLK), .en(w651), .inp(w650), .val(l324));
	
	ym_sr_bit sr325(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(vram_address[1]), .sr_out(l325));
	
	ym_sr_bit sr326(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w179), .sr_out(l326));
	
	ym_sr_bit_array #(.DATA_WIDTH(11)) sr327(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in( { sat_size, sat_link } ), .data_out(l327));
	
	ym_dlatch_1 #(.DATA_WIDTH(11)) dl328(.MCLK(MCLK), .c1(hclk1), .inp(l327), .nval(l328));
	
	assign w651 = hclk1 & l326;
	
	ym_sr_bit sr329(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l326), .sr_out(l329));
	
	ym_sr_bit sr330(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l329), .sr_out(l330));
	
	ym_sr_bit sr331(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l134), .sr_out(l331));
	
	ym_slatch #(.DATA_WIDTH(11)) sl332(.MCLK(MCLK), .en(w652), .inp(l328), .val(l332));
	
	ym_dlatch_1 dl333(.MCLK(MCLK), .c1(hclk1), .inp(w679), .nval(l333));
	
	assign w652 = hclk2 & clk2 & l333;
	
	assign w653 = w355 + { 1'h0, w106, w654, 5'h0, w106, w654 };
	
	assign w654 = ~w106 & reg_m5;
	
	assign w655 = reg_m5 & l332[6:0] == 7'h7f;
	
	assign w656 = reg_m5 & ~l332[8];
	
	assign w657 = reg_m5 ? ~l332[7] : reg_81_b1;
	
	assign w658 = w676 & (w655 | w667);
	
	assign w659 = ~(hclk1 & ~w679);
	
	ym_dlatch_1 dl334(.MCLK(MCLK), .c1(clk1), .inp(w659), .nval(l334));
	
	assign w660 = l334 & clk2;
	
	ym_sr_bit sr335(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l334), .sr_out(l335));
	
	assign w661 = l335 & clk2;
	
	assign w662 = 10'h1 + w653 + l340;
	
	ym_sr_bit sr336(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(~l332[10]), .sr_out(l336));
	
	ym_sr_bit sr337(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(~l332[9]), .sr_out(l337));
	
	ym_sr_bit sr338(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w656), .sr_out(l338));
	
	ym_sr_bit sr339(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w657), .sr_out(l339));
	
	assign w663 = ~(l338 | l339);
	
	assign w664 = l338 & ~l339;
	
	assign w665 = w668 & w669 & w670 & w671
		& w672 & l341[7] & l341[6] & ~w675 & l383;
	
	assign w666 = w677 ? { 2'h0, l342[7:0] } : l344;
	
	ym_dlatch_1 #(.DATA_WIDTH(10)) dl340(.MCLK(MCLK), .c1(hclk1), .inp(w666), .nval(l340));
	
	ym_dlatch_2 #(.DATA_WIDTH(6)) dl341_1(.MCLK(MCLK), .c2(hclk2), .inp(w662[5:0]), .val(l341[5:0]));
	ym_dlatch_2 #(.DATA_WIDTH(4)) dl341_2(.MCLK(MCLK), .c2(hclk2), .inp(w662[9:6]), .nval(l341[9:6]));
	
	assign w667 = w666 == 10'd208 & ~reg_m5;
	
	assign w668 = ~(w663 & w673);
	
	assign w669 = ~(~l338 & w674);
	
	assign w670 = ~(w664 & w673 & w674);
	
	assign w671 = l341[9] | ~w106;
	
	assign w672 = l341[8] | ~reg_m5;
	
	ym_slatch #(.DATA_WIDTH(8)) sl342(.MCLK(MCLK), .en(w661), .inp(vram_serial), .val(l342));
	
	ym_slatch #(.DATA_WIDTH(10)) sl343(.MCLK(MCLK), .en(w660), .inp(w680), .val(l343));
	
	ym_dlatch_2 #(.DATA_WIDTH(10)) dl344(.MCLK(MCLK), .c2(hclk2), .inp(l343), .nval(l344));
	
	assign w673 = w106 ? l341[4] : l341[3];
	
	assign w674 = w106 ? l341[5] : l341[4];
	
	assign w675 = w106 ? 1'h0 : l341[5];
	
	assign w676 = reg_m5 ? w681 : w682;
	
	assign w677 = ~reg_m5 & l350;
	
	assign w678 = l347 | l348 | l359;
	
	assign w679 = ~(reg_m5 ? w678 : l348);
	
	ym_sr_bit_array #(.DATA_WIDTH(10)) sr345(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(sat_ypos), .data_out(l345));
	
	ym_dlatch_1 #(.DATA_WIDTH(10)) dl346(.MCLK(MCLK), .c1(hclk1), .inp(l345), .nval(l346));
	
	assign w680 = reg_m5 ? l346 : { 2'h3, ~vram_serial };
	
	ym_sr_bit sr347(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l357), .sr_out(l347));
	
	ym_sr_bit sr348(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l347), .sr_out(l348));
	
	ym_sr_bit sr349(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l348), .sr_out(l349));
	
	ym_sr_bit sr350(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l349), .sr_out(l350));
	
	assign w681 = l348 | l349;
	
	assign w682 = l349 | l350;
	
	ym_cnt_bit_load #(.DATA_WIDTH(7)) cnt351(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(w684), .reset(l354), .load(w683), .load_val(sat_link), .val(l351));
	
	assign w683 = reg_m5 & (l352 | l353);
	
	ym_sr_bit sr352(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l353), .sr_out(l352));
	
	assign w684 = ~reg_m5 & l353;
	
	ym_sr_bit sr353(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l147), .sr_out(l353));
	
	ym_sr_bit sr354(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w685), .sr_out(l354));
	
	assign w685 = reset_comb | l115 | (~l355 & l356);
	
	ym_sr_bit sr355(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l356), .sr_out(l355));
	
	ym_sr_bit sr356(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w162), .sr_out(l356));
	
	assign w686 = l147 & (t38 | l162);
	
	ym_sr_bit sr357(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w686), .sr_out(l357));
	
	ym_sr_bit sr358(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l331), .sr_out(l358));
	
	ym_sr_bit sr359(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l358), .sr_out(l359));
	
	assign w687 = l364 & l360_1;
	assign w688 = l363 & l360_1;
	assign w689 = l363 & ~l360_1;
	assign w690 = l364 & ~l360_1;
	
	assign w691 = reg_rs1 & vram_address[9];
	
	ym_sr_bit sr360_1(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(vram_address[1]), .sr_out(l360_1));
	
	ym_sr_bit_array #(.DATA_WIDTH(6)) sr360_83(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(vram_address[8:3]), .data_out(l360_83));
	
	ym_sr_bit sr361(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w179), .sr_out(l361));
	
	ym_sr_bit sr362(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w691), .sr_out(l362));
	
	assign w692 = l358 | l363 | l364 | l361;
	
	assign w693 = w741 & w283;
	assign w694 = w741 & w284;
	
	ym_sr_bit sr363(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w693), .sr_out(l363));
	
	ym_sr_bit sr364(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w694), .sr_out(l364));
	
	assign w695 = w692 ? { l362, l360_83 } : l351;
	
	assign w696 = reg_m5 ? l351 : { 1'h1, l365, l116 };
	
	ym_sr_bit_array #(.DATA_WIDTH(5), .SR_LENGTH(2)) sr365(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l351[4:0]), .data_out(l365));
	
	ym_sr_bit_array #(.DATA_WIDTH(4)) sr366(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(vram_data[11:8]), .data_out(l366));
	
	assign w697 = reg_test0[12] ? reg_test_18[4:0] : l371;
	
	ym_sr_bit sr367(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w784), .sr_out(l367));
	
	assign w698 = l367 & l371[4] & l371[2];
	
	ym_sr_bit sr368(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w698), .sr_out(l368));
	
	ym_sr_bit sr369(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w699), .sr_out(l369));
	
	ym_sr_bit sr370(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w700), .sr_out(l370));
	
	assign w699 = reg_m5 & l370 & ~w700;
	
	assign w700 = ~(l368 | l429);
	
	ym_cnt_bit_rev #(.DATA_WIDTH(5)) cnt371(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .c_in(w703), .dec(w704), .reset(l373), .val(l371));
	
	ym_sr_bit sr372(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w360), .sr_out(l372));
	
	assign w701 = w360 | l110;
	
	ym_sr_bit sr373(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w701), .sr_out(l373));
	
	assign w702 = ~reg_m5 | l375 | w784;
	
	assign w703 = w702 & ~1'h0;
	
	assign w704 = w702 & 1'h0;
	
	assign w705 = reg_test_18[6:5] != 2'h2;
	assign w706 = reg_test_18[6:5] != 2'h1;
	assign w707 = reg_test_18[6:5] != 2'h0;
	
	assign w708 = w96 & reg_test_18[6] & ~reg_test_18[5];
	
	assign w709 = w708 | w713;
	
	assign w710 = w96 & ~reg_test_18[6] & reg_test_18[5];
	
	assign w711 = w96 & ~reg_test_18[6] & ~reg_test_18[5];
	
	assign w712 = w711 | w713;
	
	assign w713 = l374 & ~reg_test0[12];
	
	ym_sr_bit sr374(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l377), .sr_out(l374));
	
	ym_sr_bit sr375(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l374), .sr_out(l375));
	
	ym_sr_bit #(.SR_LENGTH(10)) sr376(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w743), .sr_out(l376));
	
	assign w714 = ~(l376 & ~reg_m5);
	
	assign w715 = w710 | w713 | ~l426;
	
	assign w716 = ~w743 & l396;
	
	ym_sr_bit sr377(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w716), .sr_out(l377));
	
	assign w717 = w719 | l382;
	
	ym_sr_bit sr378(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l382), .sr_out(l378));
	
	assign w718 = hclk1 & l378 & clk1;
	
	ym_slatch #(.DATA_WIDTH(4)) sl379(.MCLK(MCLK), .en(w718), .inp({l336, l337, l338, l339}), .val(l379));
	
	ym_slatch #(.DATA_WIDTH(6)) sl380(.MCLK(MCLK), .en(w718), .inp(l341[5:0]), .val(l380));
	
	assign w719 = w665 & w743;
	
	assign w720 = w665 & ~w743;
	
	assign w721 = l384 | l385;
	
	ym_sr_bit sr381(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l115), .sr_out(l381));
	
	ym7101_rs_trig rs40(.MCLK(MCLK), .set(w721), .rst(l381), .q(t40));
	
	ym7101_rs_trig rs41(.MCLK(MCLK), .set(l385), .rst(l381), .q(t41));
	
	assign w722 = l387[4] & (l379[1] | l379[0]);
	
	assign w723 = l387[4] & l379[1] & ~l379[0];
	
	assign w724 = l387[4] & l379[1];
	
	assign w725 = w106 ? l380[5:4] : l380[4:3];
	
	assign w726 = w725 + {1'h0, w723};
	
	ym_sr_bit sr382(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w418), .sr_out(l382));
	
	ym_sr_bit sr383(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w727), .sr_out(l383));
	
	assign w727 = ~(t40 | ~w676);
	
	ym_sr_bit sr384(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w658), .sr_out(l384));
	
	ym_sr_bit sr385(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w720), .sr_out(l385));
	
	assign w728 = l387[4] ? ~l380[3:0] : l380[3:0];
	
	assign w729 = w106 ? { w730, w728[3] } : { l380[5], w730 };
	
	assign w730 = w726 ^ { w724, w722 };
	
	assign yoff = { w729, w728[2:0] };
	
	ym_slatch #(.DATA_WIDTH(8)) sl386(.MCLK(MCLK), .en(w745), .inp(vram_serial), .val(l386));
	
	ym_slatch #(.DATA_WIDTH(8)) sl387(.MCLK(MCLK), .en(w746), .inp(vram_serial), .val(l387));
	
	assign w731 = l401 ? l387 : l386;
	
	assign w732 = w738 | w94 | w95;
	
	ym_sr_bit_en #(.SR_LENGTH(10)) sr388(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w739[0]), .data_out(l388));
	
	ym_sr_bit_en #(.SR_LENGTH(10)) sr389(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w739[1]), .data_out(l389));
	
	ym_sr_bit_en #(.SR_LENGTH(10)) sr390(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w739[2]), .data_out(l390));
	
	ym_sr_bit_en #(.SR_LENGTH(10)) sr391(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w739[3]), .data_out(l391));
	
	assign w733 = l401 ? l388[9] : l388[8];
	
	assign w734 = l401 ? l389[9] : l389[8];
	
	assign w735 = l401 ? l390[9] : l390[8];
	
	assign w736 = l401 ? l391[9] : l391[8];
	
	assign w737 = reg_81_b1 ? w736 : w731[0];
	
	assign w738 = ~reg_test0[14] & w717;
	
	assign w739 = w94 ? io_data[3:0] : l341[3:0];
	
	ym_slatch sl_86_b2(.MCLK(MCLK), .en(w225), .inp(reg_data_l2[2]), .val(reg_86_b2));
	
	ym_slatch sl_86_b5(.MCLK(MCLK), .en(w225), .inp(reg_data_l2[5]), .val(reg_86_b5));
	
	ym_slatch #(.DATA_WIDTH(8)) sl_at(.MCLK(MCLK), .en(w226), .inp(reg_data_l2[7:0]), .val(reg_at));
	
	wire [7:0] spr_at_1 = reg_at | { 7'h0, reg_rs1 };
	wire [7:0] spr_at_2 = vram_address[16:9] | { 7'h0, reg_rs1 };
	
	assign w740 = spr_at_1 == spr_at_2;
	
	assign w741 = w740 & ~vram_address[2] & reg_m5;
	
	assign w742 = ~reg_m5 & w751;
	
	assign w743 = (reg_m5 & reg_rs1 & l410[19])
		| (reg_m5 & ~reg_rs1 & l410[15])
		| (~reg_m5 & l410[7]);
	
	ym_sr_bit sr392(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l394), .sr_out(l392));
	
	assign w744 = l394 & clk2;
	
	assign w745 = l392 & clk2;
	
	assign w746 = l393 & clk2;
	
	ym_sr_bit sr393(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l395), .sr_out(l393));
	
	ym_dlatch_1 dl394(.MCLK(MCLK), .c1(clk1), .inp(w747), .nval(l394));
	
	assign w747 = ~(l396 & hclk1);
	
	assign w748 = ~(w417 & hclk1);
	
	ym_dlatch_1 dl395(.MCLK(MCLK), .c1(clk1), .inp(w748), .nval(l395));
	
	assign w749 = l395 & clk2;
	
	ym_sr_bit sr396(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w750), .sr_out(l396));
	
	ym_sr_bit sr397(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w417), .sr_out(l397));
	
	assign w750 = reg_m5 ? w417 : l397;
	
	ym_sr_bit_array #(.DATA_WIDTH(7)) sr398(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(w696), .data_out(l398));
	
	ym_sr_bit_array #(.DATA_WIDTH(7)) sr399(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l398), .data_out(l399));
	
	ym_sr_bit_array #(.DATA_WIDTH(7)) sr400(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l399), .data_out(l400));
	
	assign w751 = l402 | l401;
	
	ym_sr_bit sr401(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l141), .sr_out(l401));
	
	ym_sr_bit sr402(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l142), .sr_out(l402));
	
	assign w752 = w94 ? io_data[10:4] : l400;
	
	assign w753 = w94 ? io_data[11] : l382;
	
	ym_sr_bit_en #(.SR_LENGTH(20)) sr403(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w752[0]), .data_out(l403));
	
	ym_sr_bit_en #(.SR_LENGTH(20)) sr404(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w752[1]), .data_out(l404));
	
	ym_sr_bit_en #(.SR_LENGTH(20)) sr405(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w752[2]), .data_out(l405));
	
	ym_sr_bit_en #(.SR_LENGTH(20)) sr406(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w752[3]), .data_out(l406));
	
	ym_sr_bit_en #(.SR_LENGTH(20)) sr407(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w752[4]), .data_out(l407));
	
	ym_sr_bit_en #(.SR_LENGTH(20)) sr408(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w752[5]), .data_out(l408));
	
	ym_sr_bit_en #(.SR_LENGTH(20)) sr409(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w752[6]), .data_out(l409));
	
	ym_sr_bit_en #(.SR_LENGTH(20)) sr410(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .en1(w732), .en2(~w732), .data_in(w753), .data_out(l410));
	
	ym_sr_bit sr411(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l147), .sr_out(l411));
	
	ym_sr_bit sr412(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l134), .sr_out(l412));
	
	assign w754 = ~reg_m5 & (l411 | l412);
	
	assign w755 = ~reg_m5 & l412;
	
	assign w756 = reg_m5 & l412;
	
	assign w757 = reg_rs1 ?
		{ l409[19], l408[19], l407[19], l406[19], l405[19], l404[19], l403[19] } :
		{ reg_at[0], l408[15], l407[15], l406[15], l405[15], l404[15], l403[15] };
	
	assign w758 = (w759 ? io_data[0] : 1'h0) | (w760 ? l387[3] : 1'h0);
	
	assign w759 = l426 & reg_test0[12];
	
	assign w760 = l426 & ~reg_test0[12];
	
	assign w761 = (w759 ? io_data[2:1] : 2'h0) | (w760 ? l387[6:5] : 2'h0);
	
	assign w763 = (w759 ? io_data[3] : 1'h0) | (w760 ? l387[7] : 1'h0);
	
	assign w764 = (w759 ? io_data[5:4] : 2'h0) | (w760 ? l379[3:2] : 2'h0);
	
	assign w766 = (w759 ? io_data[7:6] : 2'h0) | (w760 ? l379[1:0] : 2'h0);
	
	assign w768 = (w759 ? io_data[13:8] : 6'h0) | (w760 ? yoff : 6'h0);
	
	assign w769 = hclk1 & (w97 | w772);
	
	assign w770 = (~w705 ? {l418[2:0], l417, l416, l415, l414, l413 } : 11'h0) |
		(~w706 ? {2'd0,l425} : 11'h0) |
		(~w707 ? l424 : 11'h0);
	
	ym_slatch sl413(.MCLK(MCLK), .en(w769), .inp(sprdata_hflip_o), .val(l413));
	ym_slatch #(.DATA_WIDTH(2)) sl414(.MCLK(MCLK), .en(w769), .inp(sprdata_pal_o), .val(l414));
	ym_slatch sl415(.MCLK(MCLK), .en(w769), .inp(sprdata_priority_o), .val(l415));
	ym_slatch #(.DATA_WIDTH(2)) sl416(.MCLK(MCLK), .en(w769), .inp(sprdata_xs_o), .val(l416));
	ym_slatch #(.DATA_WIDTH(2)) sl417(.MCLK(MCLK), .en(w769), .inp(sprdata_ys_o), .val(l417));
	ym_slatch #(.DATA_WIDTH(6)) sl418(.MCLK(MCLK), .en(w769), .inp(sprdata_yoffset_o), .val(l418));
	
	ym_sr_bit sr419(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l511), .sr_out(l419));
	
	ym_cnt_bit_load #(.DATA_WIDTH(2)) cnt420(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(l141), .reset(l372), .load(w772), .load_val(~sprdata_xs_o), .val(l420));
	
	assign w771 = l420 == 2'h0;
	
	assign w772 = w771 & l141;
	
	ym_cnt_bit cnt421(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(l419), .reset(w360), .val(l421));
	
	ym_sr_bit sr422(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l421), .sr_out(l422));
	
	ym7101_rs_trig rs42(.MCLK(MCLK), .set(l372), .rst(l369), .q(t42));
	
	ym_sr_bit sr423(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(t42), .sr_out(l423));
	
	assign w773 = l423 & l511 & w714;
	
	assign w774 =
		(w759 ? io_data[10:0] : 11'h0) |
		(w760 ? { l387[2:0], l435 } : 11'h0);
	
	ym_slatch #(.DATA_WIDTH(11)) sl424(.MCLK(MCLK), .en(w769), .inp(sprdata_pattern_o), .val(l424));
	
	assign w775 =
		(w759 ? io_data[8:0] : 9'h0) |
		(w760 ? { l386[0], l436 } : 9'h0);
	
	ym_slatch #(.DATA_WIDTH(9)) sl425(.MCLK(MCLK), .en(w769), .inp(sprdata_hpos_o), .val(l425));
	
	ym_sr_bit sr426(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w776), .sr_out(l426));
	
	assign w776 = ~(~reg_m5 | w772);
	
	assign w777 = l372 | w784;
	
	ym_sr_bit sr427(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w777), .sr_out(l427));
	
	assign w778 = { 2'h0,w106 ? l418[5:4] : l418[4:3] };
	
	assign w779 = w778 + w786;
	
	assign w780 = l424 + { 7'h0, w779 };
	
	ym_sr_bit sr428(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w781), .sr_out(l428));
	
	assign w781 = l141 & reg_m5;
	
	assign w782 = l425 != 9'h0;
	
	ym_dlatch_2 dl429(.MCLK(MCLK), .c2(hclk2), .inp(w782), .nval(l429));
	
	ym_sr_bit sr430(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l431), .sr_out(l430));
	
	assign w783 = l372 | w772;
	
	ym_sr_bit sr431(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l141), .sr_out(l431));
	
	assign w784 = l431 & w771;
	
	ym_dlatch_1 dl432(.MCLK(MCLK), .c1(hclk1), .inp(w783), .nval(l432));
	
	ym_dlatch_1 dl433(.MCLK(MCLK), .c1(hclk1), .inp(l430), .val(l433));
	
	assign w785 = l433 ? l417 : 2'h0;
	
	assign w786 = l432 ? w787 : 4'h0;
	
	assign w787 = {3'h0, l433} + l434 + { 2'h0, w785 };
	
	ym_sr_bit_array #(.DATA_WIDTH(4)) sr434(.MCLK(MCLK), .c1(hclk2), .c2(hclk1), .data_in(w786), .data_out(l434));
	
	ym_slatch #(.DATA_WIDTH(8)) sl435(.MCLK(MCLK), .en(w749), .inp(vram_serial), .val(l435));
	
	ym_slatch #(.DATA_WIDTH(8)) sl436(.MCLK(MCLK), .en(w744), .inp(vram_serial), .val(l436));
	
	ym_slatch #(.DATA_WIDTH(8)) sl437(.MCLK(MCLK), .en(l438), .inp(w788), .val(l437));
	
	assign w788 = l422 ? l436 : l435;
	
	ym_sr_bit sr438(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w773), .sr_out(l438));
	
	ym_dlatch_2 dl439_1(.MCLK(MCLK), .c2(hclk2), .inp(l413), .val(l439_1));
	ym_sr_bit #(.SR_LENGTH(5)) sr439(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l439_1), .sr_out(l439));
	
	ym_dlatch_2 #(.DATA_WIDTH(2)) dl440_1(.MCLK(MCLK), .c2(hclk2), .inp(l414), .val(l440_1));
	ym_sr_bit_array #(.SR_LENGTH(5), .DATA_WIDTH(2)) sr440(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l440_1), .data_out(l440));
	
	ym_dlatch_2 dl441_1(.MCLK(MCLK), .c2(hclk2), .inp(l415), .val(l441_1));
	ym_sr_bit #(.SR_LENGTH(5)) sr441(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l441_1), .sr_out(l441));
	
	ym_dlatch_2 #(.DATA_WIDTH(2)) dl442_1(.MCLK(MCLK), .c2(hclk2), .inp(l416), .val(l442_1));
	ym_sr_bit_array #(.SR_LENGTH(5), .DATA_WIDTH(2)) sr442(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l442_1), .data_out(l442));
	
	ym_dlatch_2 #(.DATA_WIDTH(9)) dl443_1(.MCLK(MCLK), .c2(hclk2), .inp(l425), .val(l443_1));
	ym_sr_bit_array #(.SR_LENGTH(5), .DATA_WIDTH(9)) sr443(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l443_1), .data_out(l443));
	
	ym_sr_bit sr444(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w805), .sr_out(l444));
	
	assign w789 = ~(l444 | l445);
	
	assign w790 = w789 & l449;
	
	ym_sr_bit sr445(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l454), .sr_out(l445));
	
	assign w791 = w792 | w796;
	
	assign w792 = l442[0] & w795;
	
	assign w793 = l442[1] & w795;
	
	assign w794 = w793 | w796;
	
	assign w795 = l439 & reg_m5;
	
	assign w796 = ~reg_m5 & reg_80_b3;
	
	assign w797 = reg_m5 | w796;
	
	assign w798 = w789 & ~l449;
	
	assign w799 = reg_m5 ? l443 : { 1'h0, l437 };
	
	assign w800 = w799[8:3] + {5'h0, w795} + { w797, w797, w796, w796, w794, w791 };
	
	ym_sr_bit_array #(.DATA_WIDTH(6)) sr446(.MCLK(MCLK), .c1(clk1), .c2(clk2), .data_in(w800), .data_out(l446));
	
	ym_sr_bit_array #(.DATA_WIDTH(6)) sr447(.MCLK(MCLK), .c1(clk1), .c2(clk2), .data_in(w802), .data_out(l447));
	
	assign w801 = l444 ? l446 : l447;
	
	assign w802 = w801 + {5'h0, w798} + {6{w790}};
	
	assign w803 = clk2 & l499;
	
	ym_slatch sl448(.MCLK(MCLK), .en(w805), .inp(w795), .val(l448));
	
	ym_sr_bit sr449(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l448), .sr_out(l449));
	
	ym_slatch sl450(.MCLK(MCLK), .en(w805), .inp(l441), .val(l450));
	
	ym_slatch sl451(.MCLK(MCLK), .en(w803), .inp(l450), .val(l451));
	
	ym_slatch #(.DATA_WIDTH(2)) sl452(.MCLK(MCLK), .en(w805), .inp(l440), .val(l452));
	
	ym_slatch #(.DATA_WIDTH(2)) sl453(.MCLK(MCLK), .en(w803), .inp(l452), .val(l453));
	
	ym_dlatch_2 dl454(.MCLK(MCLK), .c2(clk2), .inp(l499), .nval(l454));
	
	ym_sr_bit sr455(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l438), .sr_out(l455));
	
	ym_sr_bit sr456(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l455), .sr_out(l456));
	
	assign w804 = l456 & w808;
	
	assign w805 = l456 & w808 & hclk1;
	
	assign w806 = ~(reg_m5 & l442[0]);
	
	ym_cnt_bit_load #(.DATA_WIDTH(2)) cnt457(.MCLK(MCLK), .c1(hclk1), .c2(hclk2),
		.c_in(l456), .reset(w360), .load(w804), .load_val( { w807, w806 } ), .val(l457));
	
	assign w807 = ~(reg_m5 & l442[1]);
	
	assign w808 = l457 == 2'h0;
	
	assign w809 = l106 + 9'h1 + { 4'hf, ~reg_m5, reg_m5, 2'h2, reg_m5 };
	
	ym_sr_bit sr458(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w810), .sr_out(l458));
	
	assign w810 = ~((w802[5] & reg_rs1 & (w802[4] | w802[3]))
		| (w802[5] & ~reg_rs1));
	
	assign w811 = l451 & w821;
	
	assign w812 = w821 ? l453 : 2'h0;
	
	ym_sr_bit sr459(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(~l454), .sr_out(l459));
	
	ym_sr_bit sr460(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l459), .sr_out(l460));
	
	assign w813 = l460 ^ l449;
	
	ym_dlatch_1 dl461(.MCLK(MCLK), .c1(clk1), .inp(w813), .val(l461));
	
	assign w814 = l458 & (~l454 | l460);
	
	ym_dlatch_1 dl462(.MCLK(MCLK), .c1(clk1), .inp(w814), .nval(l462));
	
	assign w815 = ~(l462 | reg_test0[13]);
	
	ym_sr_bit sr463(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w814), .sr_out(l463));
	
	assign w816 = w814 | l463;
	
	ym_sr_bit sr464(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w951), .sr_out(l464));
	
	assign w817 = l464 | w816 | w951 | reg_test0[13];
	
	assign w818 = ~(l465 & ~reg_test0[13]);
	
	ym_dlatch_1 dl465(.MCLK(MCLK), .c1(clk1), .inp(w819), .nval(l465));
	
	assign w819 = ~(hclk2 & l466);
	
	ym_dlatch_1 dl466(.MCLK(MCLK), .c1(hclk1), .inp(w820), .nval(l466));
	
	assign w820 = w821 | l467 | l468 | l469;
	
	ym_sr_bit sr467(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w809[2]), .sr_out(l467));
	
	ym_sr_bit sr468(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w809[1]), .sr_out(l468));
	
	ym_sr_bit sr469(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w809[0]), .sr_out(l469));
	
	assign w821 = ~(reg_m5 ? l470 : w388);
	
	ym_sr_bit sr470(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l471), .sr_out(l470));
	
	ym_sr_bit sr471(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w388), .sr_out(l471));
	
	ym_sr_bit_array #(.DATA_WIDTH(3)) sr472(.MCLK(MCLK), .c1(clk1), .c2(clk2), .data_in(l473), .data_out(l472));
	
	ym_slatch #(.DATA_WIDTH(3)) sl473(.MCLK(MCLK), .en(w805), .inp(w799[2:0]), .val(l473));
	
	assign w822 = w821 & ~reg_test0[13];
	
	assign w823 = ~w821 & ~reg_test0[13];
	
	assign w824 = reg_test0[13];
	
	ym_sr_bit_array #(.DATA_WIDTH(6)) sr474(.MCLK(MCLK), .c1(clk1), .c2(clk2), .data_in(w802), .data_out(l474));
	
	ym_sr_bit_array #(.DATA_WIDTH(6)) sr475(.MCLK(MCLK), .c1(clk1), .c2(clk2), .data_in(w809[8:3]), .data_out(l475));
	
	assign w825 =
		(w822 ? l474 : 6'h0) |
		(w823 ? l475 : 6'h0) |
		(w824 ? reg_test_18[5:0] : 6'h0);
	
	ym_slatch #(.DATA_WIDTH(8)) sl478(.MCLK(MCLK), .en(w834), .inp(vram_serial), .val(l478));
	
	ym_slatch #(.DATA_WIDTH(8)) sl479(.MCLK(MCLK), .en(w833), .inp(vram_serial), .val(l479));
	
	ym_slatch #(.DATA_WIDTH(8)) sl480(.MCLK(MCLK), .en(w829), .inp(vram_serial), .val(l480));
	
	ym_slatch #(.DATA_WIDTH(8)) sl481(.MCLK(MCLK), .en(w830), .inp(vram_serial), .val(l481));
	
	assign w829 = l482 & clk2;
	
	ym_sr_bit sr482(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l483), .sr_out(l482));
	
	ym_dlatch_1 dl483(.MCLK(MCLK), .c1(clk1), .inp(w831), .nval(l483));
	
	assign w830 = l483 & clk2;
	
	assign w831 = ~(l509 & hclk1);
	
	assign w832 = ~(l511 & hclk1);
	
	ym_dlatch_1 dl484(.MCLK(MCLK), .c1(clk1), .inp(w832), .nval(l484));
	
	assign w833 = l484 & clk2;
	
	ym_sr_bit sr485(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l484), .sr_out(l485));
	
	assign w834 = l485 & clk2;
	
	ym_slatch #(.DATA_WIDTH(8)) sl486(.MCLK(MCLK), .en(w834), .inp(l479), .val(l486));
	
	ym_slatch #(.DATA_WIDTH(8)) sl487(.MCLK(MCLK), .en(w834), .inp(l480), .val(l487));
	
	ym_slatch #(.DATA_WIDTH(8)) sl488(.MCLK(MCLK), .en(w834), .inp(l481), .val(l488));
	
	ym_sr_bit sr489(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l485), .sr_out(l489));
	
	ym_sr_bit sr490(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(l489), .sr_out(l490));
	
	assign w835 = l490 & clk2;
	
	ym_slatch #(.DATA_WIDTH(8)) sl491(.MCLK(MCLK), .en(w835), .inp(l478), .val(l491));
	
	ym_slatch #(.DATA_WIDTH(8)) sl492(.MCLK(MCLK), .en(w835), .inp(l486), .val(l492));
	
	ym_slatch #(.DATA_WIDTH(8)) sl493(.MCLK(MCLK), .en(w835), .inp(l487), .val(l493));
	
	ym_slatch #(.DATA_WIDTH(8)) sl494(.MCLK(MCLK), .en(w835), .inp(l488), .val(l494));
	
	ym_sr_bit sr495(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w836), .sr_out(l495));
	
	ym_sr_bit sr496(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l495), .sr_out(l496));

	ym_sr_bit sr497(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l496), .sr_out(l497));
	
	ym_sr_bit sr498(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l497), .sr_out(l498));
	
	ym_dlatch_1 dl499(.MCLK(MCLK), .c1(clk1), .inp(l498), .nval(l499));
	
	ym_dlatch_1 dl500(.MCLK(MCLK), .c1(hclk1), .inp(l438), .val(l500));
	
	assign w836 = ~(l500 & hclk2);
	
	ym_sr_bit sr501(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w795), .sr_out(l501));
	
	assign w837 = l501 ? l495 : l498;
	
	assign w838 = l501 ? l496 : l497;
	
	assign w839 = l501 ? l497 : l496;
	
	assign w840 = l501 ? l498 : l495;
	
	assign w841 = ~(~reg_m5 | l514);
	
	assign w842 = ~(reg_m5 | l514);
	
	wire [7:0] w843_1 =
		(~w837 ? l492 : 8'h0) |
		(~w838 ? l491 : 8'h0) |
		(~w839 ? l494 : 8'h0) |
		(~w840 ? l493 : 8'h0);
	
	wire [7:0] w843_2 =
		(~l495 ? { l491[7], l492[7], l493[7], l494[7], l491[6], l492[6], l493[6], l494[6] } : 8'h0) |
		(~l496 ? { l491[5], l492[5], l493[5], l494[5], l491[4], l492[4], l493[4], l494[4] } : 8'h0) |
		(~l497 ? { l491[3], l492[3], l493[3], l494[3], l491[2], l492[2], l493[2], l494[2] } : 8'h0) |
		(~l498 ? { l491[1], l492[1], l493[1], l494[1], l491[0], l492[0], l493[0], l494[0] } : 8'h0);
	
	assign w843 =
		(w841 ? w843_1 : 8'h0) |
		(w842 ? w843_2 : 8'h0);
	
	assign w844 = w847 ? { w843[3:0], w843[7:4] } : w843;
	
	ym_dlatch_1 #(.DATA_WIDTH(8)) dl502(.MCLK(MCLK), .c1(clk1), .inp(w844), .val(l502));
	
	assign w845 = reg_test0[13] ?
		{ io_data[14], io_data[13], io_data[12], io_data[11], io_data[6], io_data[5], io_data[4], io_data[3] } :
		l502;
	
	ym_cnt_bit_load #(.DATA_WIDTH(2)) cnt503(.MCLK(MCLK), .c1(clk1), .c2(clk2),
		.c_in(~w846), .reset(1'h0), .load(w846), .load_val(w799[2:1]), .val(l503));
	
	assign w846 = ~w836;
	
	ym_dlatch_1 #(.DATA_WIDTH(3)) dl504(.MCLK(MCLK), .c1(clk1), .inp({ l503, l506 }), .val(l504));
	
	ym_slatch sl505(.MCLK(MCLK), .en(w846), .inp(w799[0]), .val(l505));
	
	ym_sr_bit sr506(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l505), .sr_out(l506));
	
	assign w847 = l506 ^ l501;
	
	assign w848 = l156 | (reg_m5 & l141);
	
	ym_sr_bit sr507(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w848), .sr_out(l507));
	
	ym_sr_bit sr508(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l507), .sr_out(l508));
	
	ym_sr_bit sr509(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l508), .sr_out(l509));
	
	ym_sr_bit sr510(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l509), .sr_out(l510));
	
	assign w849 = reg_m5 ? l509 : l510;
	
	ym_sr_bit sr511(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w849), .sr_out(l511));
	
	ym_dlatch_1 dl512(.MCLK(MCLK), .c1(hclk1), .inp(w388), .nval(l512));
	
	ym_sr_bit sr513(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l512), .sr_out(l513));
	
	assign w850 = l513 & ~l512;
	
	ym_sr_bit sr514(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w850), .sr_out(l514));
	
	assign w852 = ~(~reg_test_18[7] & ~reg_test_18[6] & w98);
	assign w853 = ~(~reg_test_18[7] & reg_test_18[6] & w98);
	assign w854 = ~(reg_test_18[7] & ~reg_test_18[6] & w98);
	assign w855 = ~(reg_test_18[7] & reg_test_18[6] & w98);
	
	assign w856 = ~(w852 & w818);
	assign w857 = ~(w853 & w818);
	assign w858 = ~(w854 & w818);
	assign w859 = ~(w855 & w818);
	
	assign w877 = ~(~reg_test0[13] & l563);
	
	assign w860 = l504 == 3'h0;
	assign w861 = l504 == 3'h1;
	assign w862 = l504 == 3'h2;
	assign w863 = l504 == 3'h3;
	assign w828 = l504 == 3'h4;
	assign w864 = l504 == 3'h5;
	assign w865 = l504 == 3'h6;
	assign w866 = l504 == 3'h7;
	
	assign w873 = w861 | w877;
	assign w876 = w863 | w877;
	assign w880 = w864 | w877;
	assign w883 = w866 | w877;
	
	assign w872 = clk2 & (w860 | w883);
	assign w874 = clk2 & (w873 | w860);
	assign w875 = clk2 & (w862 | w873);
	assign w878 = clk2 & (w876 | w862);
	assign w879 = clk2 & (w828 | w876);
	assign w881 = clk2 & (w880 | w828);
	assign w882 = clk2 & (w865 | w880);
	assign w884 = clk2 & (w883 | w865);
	
	ym_slatch_t #(.DATA_WIDTH(4)) sl515(.MCLK(MCLK), .en(w872), .inp(w845[7:4]), .val(l515));
	
	ym_slatch_t #(.DATA_WIDTH(4)) sl516(.MCLK(MCLK), .en(w874), .inp(w845[3:0]), .val(l516));
	
	ym_slatch_t #(.DATA_WIDTH(4)) sl517(.MCLK(MCLK), .en(w875), .inp(w845[7:4]), .val(l517));
	
	ym_slatch_t #(.DATA_WIDTH(4)) sl518(.MCLK(MCLK), .en(w878), .inp(w845[3:0]), .val(l518));
	
	ym_slatch_t #(.DATA_WIDTH(4)) sl519(.MCLK(MCLK), .en(w879), .inp(w845[7:4]), .val(l519));
	
	ym_slatch_t #(.DATA_WIDTH(4)) sl520(.MCLK(MCLK), .en(w881), .inp(w845[3:0]), .val(l520));
	
	ym_slatch_t #(.DATA_WIDTH(4)) sl521(.MCLK(MCLK), .en(w882), .inp(w845[7:4]), .val(l521));
	
	ym_slatch_t #(.DATA_WIDTH(4)) sl522(.MCLK(MCLK), .en(w884), .inp(w845[3:0]), .val(l522));
	
	assign w885 = clk2 & (l562 | l499);
	
	ym_slatch #(.DATA_WIDTH(4)) sl523(.MCLK(MCLK), .en(w885), .inp(l515), .val(l523));
	
	ym_slatch #(.DATA_WIDTH(4)) sl524(.MCLK(MCLK), .en(w885), .inp(l516), .val(l524));
	
	ym_slatch #(.DATA_WIDTH(4)) sl525(.MCLK(MCLK), .en(w885), .inp(l517), .val(l525));
	
	ym_slatch #(.DATA_WIDTH(4)) sl526(.MCLK(MCLK), .en(w885), .inp(l518), .val(l526));
	
	ym_slatch #(.DATA_WIDTH(4)) sl527(.MCLK(MCLK), .en(w885), .inp(l519), .val(l527));
	
	ym_slatch #(.DATA_WIDTH(4)) sl528(.MCLK(MCLK), .en(w885), .inp(l520), .val(l528));
	
	ym_slatch #(.DATA_WIDTH(4)) sl529(.MCLK(MCLK), .en(w885), .inp(l521), .val(l529));
	
	ym_slatch #(.DATA_WIDTH(4)) sl530(.MCLK(MCLK), .en(w885), .inp(l522), .val(l530));
	
	assign w851 = l472 >= 3'h1;
	assign w867 = l472 >= 3'h2;
	assign w868 = l472 >= 3'h3;
	assign w869 = l472 >= 3'h4;
	assign w827 = l472 >= 3'h5;
	assign w870 = l472 >= 3'h6;
	assign w871 = l472 >= 3'h7;
	
	ym_dlatch_1 dl531(.MCLK(MCLK), .c1(clk1), .inp(w851), .nval(l531));
	
	ym_dlatch_1 dl532(.MCLK(MCLK), .c1(clk1), .inp(w867), .nval(l532));
	
	ym_dlatch_1 dl533(.MCLK(MCLK), .c1(clk1), .inp(w868), .nval(l533));
	
	ym_dlatch_1 dl534(.MCLK(MCLK), .c1(clk1), .inp(w869), .nval(l534));
	
	ym_dlatch_1 dl535(.MCLK(MCLK), .c1(clk1), .inp(w827), .nval(l535));
	
	ym_dlatch_1 dl536(.MCLK(MCLK), .c1(clk1), .inp(w870), .nval(l536));
	
	ym_dlatch_1 dl537(.MCLK(MCLK), .c1(clk1), .inp(w871), .nval(l537));
	
	assign w886 = l531 ^ l461;
	assign w887 = l532 ^ l461;
	assign w888 = l533 ^ l461;
	assign w889 = l534 ^ l461;
	assign w890 = l535 ^ l461;
	assign w891 = l536 ^ l461;
	assign w892 = l537 ^ l461;
	assign w893 = ~l461;
	
	assign w894 = w886 & w815;
	assign w895 = w887 & w815;
	assign w896 = w888 & w815;
	assign w897 = w889 & w815;
	assign w898 = w890 & w815;
	assign w899 = w891 & w815;
	assign w900 = w892 & w815;
	assign w901 = w893 & w815;
	
	assign w902 = ~(w856 | (w894 & w942));
	assign w903 = ~(w856 | (w895 & w943));
	assign w904 = ~(w857 | (w896 & w944));
	assign w905 = ~(w857 | (w897 & w945));
	assign w906 = ~(w858 | (w898 & w946));
	assign w907 = ~(w858 | (w899 & w947));
	assign w908 = ~(w859 | (w900 & w948));
	assign w909 = ~(w859 | (w901 & w949));
	
	ym_dlatch_2 dl538(.MCLK(MCLK), .c2(clk2), .inp(w902), .nval(l538));
	
	ym_dlatch_2 dl539(.MCLK(MCLK), .c2(clk2), .inp(w903), .nval(l539));
	
	ym_dlatch_2 dl540(.MCLK(MCLK), .c2(clk2), .inp(w904), .nval(l540));
	
	ym_dlatch_2 dl541(.MCLK(MCLK), .c2(clk2), .inp(w905), .nval(l541));
	
	ym_dlatch_2 dl542(.MCLK(MCLK), .c2(clk2), .inp(w906), .nval(l542));
	
	ym_dlatch_2 dl543(.MCLK(MCLK), .c2(clk2), .inp(w907), .nval(l543));
	
	ym_dlatch_2 dl544(.MCLK(MCLK), .c2(clk2), .inp(w908), .nval(l544));
	
	ym_dlatch_2 dl545(.MCLK(MCLK), .c2(clk2), .inp(w909), .nval(l545));
	
	assign w910 = l538 & clk1;
	
	assign w911 = l539 & clk1;
	
	assign w912 = l540 & clk1;
	
	assign w913 = l541 & clk1;
	
	assign w914 = l542 & clk1;
	
	assign w915 = l543 & clk1;
	
	assign w916 = l544 & clk1;
	
	assign w917 = l545 & clk1;
	
	assign w918 = linebuffer_out_index[0] != 4'h0;
	assign w919 = linebuffer_out_index[1] != 4'h0;
	assign w920 = linebuffer_out_index[2] != 4'h0;
	assign w921 = linebuffer_out_index[3] != 4'h0;
	assign w922 = linebuffer_out_index[4] != 4'h0;
	assign w923 = linebuffer_out_index[5] != 4'h0;
	assign w924 = linebuffer_out_index[6] != 4'h0;
	assign w925 = linebuffer_out_index[7] != 4'h0;
	
	assign w926 = w918 & w894 & w934;
	assign w927 = w919 & w895 & w935;
	assign w928 = w920 & w896 & w936;
	assign w929 = w921 & w897 & w937;
	assign w930 = w922 & w898 & w938;
	assign w931 = w923 & w899 & w939;
	assign w932 = w924 & w900 & w940;
	assign w933 = w925 & w901 & w941;
	
	assign w934 = l523 != 4'h0;
	assign w935 = l524 != 4'h0;
	assign w936 = l525 != 4'h0;
	assign w937 = l526 != 4'h0;
	assign w938 = l527 != 4'h0;
	assign w939 = l528 != 4'h0;
	assign w940 = l529 != 4'h0;
	assign w941 = l530 != 4'h0;
	
	assign w942 = w950 ? w934 : ~w918;
	assign w943 = w950 ? w935 : ~w919;
	assign w944 = w950 ? w936 : ~w920;
	assign w945 = w950 ? w937 : ~w921;
	assign w946 = w950 ? w938 : ~w922;
	assign w947 = w950 ? w939 : ~w923;
	assign w948 = w950 ? w940 : ~w924;
	assign w949 = w950 ? w941 : ~w925;
	
	assign w950 = 1'h0;
	
	assign w951 = ~w820;
	
	assign w952 = reg_test_18[7:6] == 2'h0;
	assign w953 = reg_test_18[7:6] == 2'h1;
	assign w954 = reg_test_18[7:6] == 2'h2;
	assign w955 = reg_test_18[7:6] == 2'h3;
	
	assign w956 =
		(w952 & linebuffer_out_pal[0][0]) |
		(w953 & linebuffer_out_pal[2][0]) |
		(w954 & linebuffer_out_pal[4][0]) |
		(w955 & linebuffer_out_pal[6][0]);
	
	assign w957 =
		(w952 & linebuffer_out_pal[0][1]) |
		(w953 & linebuffer_out_pal[2][1]) |
		(w954 & linebuffer_out_pal[4][1]) |
		(w955 & linebuffer_out_pal[6][1]);
	
	assign w958 =
		(w952 & linebuffer_out_priority[0]) |
		(w953 & linebuffer_out_priority[2]) |
		(w954 & linebuffer_out_priority[4]) |
		(w955 & linebuffer_out_priority[6]);
	
	assign w959 =
		(w952 & linebuffer_out_index[0][0]) |
		(w953 & linebuffer_out_index[2][0]) |
		(w954 & linebuffer_out_index[4][0]) |
		(w955 & linebuffer_out_index[6][0]);
	
	assign w960 =
		(w952 & linebuffer_out_index[0][1]) |
		(w953 & linebuffer_out_index[2][1]) |
		(w954 & linebuffer_out_index[4][1]) |
		(w955 & linebuffer_out_index[6][1]);
	
	assign w961 =
		(w952 & linebuffer_out_index[0][2]) |
		(w953 & linebuffer_out_index[2][2]) |
		(w954 & linebuffer_out_index[4][2]) |
		(w955 & linebuffer_out_index[6][2]);
	
	assign w962 =
		(w952 & linebuffer_out_index[0][3]) |
		(w953 & linebuffer_out_index[2][3]) |
		(w954 & linebuffer_out_index[4][3]) |
		(w955 & linebuffer_out_index[6][3]);
	
	assign w963 =
		(w952 & linebuffer_out_pal[1][0]) |
		(w953 & linebuffer_out_pal[3][0]) |
		(w954 & linebuffer_out_pal[5][0]) |
		(w955 & linebuffer_out_pal[7][0]);
	
	assign w964 =
		(w952 & linebuffer_out_pal[1][1]) |
		(w953 & linebuffer_out_pal[3][1]) |
		(w954 & linebuffer_out_pal[5][1]) |
		(w955 & linebuffer_out_pal[7][1]);
	
	assign w965 =
		(w952 & linebuffer_out_priority[1]) |
		(w953 & linebuffer_out_priority[3]) |
		(w954 & linebuffer_out_priority[5]) |
		(w955 & linebuffer_out_priority[7]);
	
	assign w966 =
		(w952 & linebuffer_out_index[1][0]) |
		(w953 & linebuffer_out_index[3][0]) |
		(w954 & linebuffer_out_index[5][0]) |
		(w955 & linebuffer_out_index[7][0]);
	
	assign w967 =
		(w952 & linebuffer_out_index[1][1]) |
		(w953 & linebuffer_out_index[3][1]) |
		(w954 & linebuffer_out_index[5][1]) |
		(w955 & linebuffer_out_index[7][1]);
	
	assign w968 =
		(w952 & linebuffer_out_index[1][2]) |
		(w953 & linebuffer_out_index[3][2]) |
		(w954 & linebuffer_out_index[5][2]) |
		(w955 & linebuffer_out_index[7][2]);
	
	assign w969 =
		(w952 & linebuffer_out_index[1][3]) |
		(w953 & linebuffer_out_index[3][3]) |
		(w954 & linebuffer_out_index[5][3]) |
		(w955 & linebuffer_out_index[7][3]);
	
	wire [7:0] load_val_pal0;
	wire [7:0] load_val_pal1;
	wire [7:0] load_val_priority;
	wire [7:0] load_val_index0;
	wire [7:0] load_val_index1;
	wire [7:0] load_val_index2;
	wire [7:0] load_val_index3;
	
	genvar gi;
	generate
		for (gi = 0; gi < 8; gi = gi + 1)
		begin : gl1
			assign load_val_pal0[gi] = linebuffer_out_pal[gi][0];
			assign load_val_pal1[gi] = linebuffer_out_pal[gi][1];
			assign load_val_priority[gi] = linebuffer_out_priority[gi];
			assign load_val_index0[gi] = linebuffer_out_index[gi][0];
			assign load_val_index1[gi] = linebuffer_out_index[gi][1];
			assign load_val_index2[gi] = linebuffer_out_index[gi][2];
			assign load_val_index3[gi] = linebuffer_out_index[gi][3];
		end
	endgenerate
	
	ym_dbg_read #(.DATA_WIDTH(8)) sr546(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .prev(1'h0), .load(w951),
		.load_val(load_val_pal0), .next(spr_pal[0]));
	
	ym_dbg_read #(.DATA_WIDTH(8)) sr547(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .prev(1'h0), .load(w951),
		.load_val(load_val_pal1), .next(spr_pal[1]));
	
	ym_dbg_read #(.DATA_WIDTH(8)) sr548(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .prev(1'h0), .load(w951),
		.load_val(load_val_priority), .next(spr_priority));
	
	ym_dbg_read #(.DATA_WIDTH(8)) sr549(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .prev(1'h0), .load(w951),
		.load_val(load_val_index0), .next(spr_index[0]));
	
	ym_dbg_read #(.DATA_WIDTH(8)) sr550(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .prev(1'h0), .load(w951),
		.load_val(load_val_index1), .next(spr_index[1]));
	
	ym_dbg_read #(.DATA_WIDTH(8)) sr551(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .prev(1'h0), .load(w951),
		.load_val(load_val_index2), .next(spr_index[2]));
	
	ym_dbg_read #(.DATA_WIDTH(8)) sr552(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .prev(1'h0), .load(w951),
		.load_val(load_val_index3), .next(spr_index[3]));
	
	ym_sr_bit_array #(.DATA_WIDTH(2)) sr553(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(spr_pal), .data_out(l553));
	
	ym_sr_bit sr554(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(spr_priority), .sr_out(l554));
	
	ym_sr_bit_array #(.DATA_WIDTH(4)) sr555(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(spr_index), .data_out(l555));
	
	assign w970 = reg_m5 ? l553 : spr_pal;
	
	assign w971 = reg_m5 ? l554 : spr_priority;
	
	assign w972 = reg_m5 ? l555 : spr_index;
	
	ym_sr_bit_array #(.DATA_WIDTH(2)) sr556(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(w970), .data_out(l556));
	
	ym_sr_bit sr557(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w971), .sr_out(l557));
	
	ym_sr_bit_array #(.DATA_WIDTH(4)) sr558(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(w972), .data_out(l558));
	
	assign w973 = l557 & reg_m5;
	
	assign w974 = reg_m5 ? l556 : 2'h1;
	
	assign w975 = l556 == 2'h3;
	
	assign w976 = l558 != 4'h0;
	
	assign w977 = l558 == 4'he;

	assign w978 = l558 == 4'hf;
	
	ym_sr_bit_array #(.DATA_WIDTH(2)) sr559(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(w974), .data_out(l559));
	
	ym_sr_bit sr560(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w973), .sr_out(l560));
	
	ym_sr_bit_array #(.DATA_WIDTH(4)) sr561(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(l558), .data_out(l561));
	
	ym_sr_bit sr562(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(w877), .sr_out(l562));
	
	ym_dlatch_1 dl563(.MCLK(MCLK), .c1(clk1), .inp(l514), .nval(l563));
	
	assign w979 = reg_test0[13] ? io_data[10] : w811;
	
	assign w980 = reg_test0[13] ? io_data[9:8] : w812;
	
	assign w982 = reg_test0[13] ? io_data[2] : w811;
	
	assign w983 = reg_test0[13] ? io_data[1:0] : w812;
	
	ym_sr_bit sr600(.MCLK(MCLK), .c1(clk2), .c2(clk1), .bit_in(w1020), .sr_out(l600));
	
	assign w1020 = w926 | w927 | w928 | w929 | w930 | w931 | w932 | w933;
	
	assign w1154 = t41 & l115;
	
	// sat cache
	
	wire [6:0] sat_index = w695;
	
	wire [20:0] sat_data_in;
	
	assign sat_data_in[6:0] = l104[6:0];
	assign sat_data_in[10:7] = l366;
	assign sat_data_in[20:11] = { l366[1:0], l104 };
	
	assign sat_link = sat_out[6:0];
	assign sat_size = sat_out[10:7];
	assign sat_ypos = sat_out[20:11];
	
	always @(posedge MCLK)
	begin
		if (sat_index < 7'd80)
		begin
			if (hclk1) // write cycle
			begin
				if (w687)
					sat[sat_index][6:0] <= sat_data_in[6:0];
				if (w688)
					sat[sat_index][10:7] <= sat_data_in[10:7];
				if (w689)
					sat[sat_index][20:19] <= sat_data_in[20:19];
				if (w690)
					sat[sat_index][18:11] <= sat_data_in[18:11];
			end
			sat_out <= sat[sat_index];
			case (sat_index[1:0])
				2'h0: sat_out_0 <= sat[sat_index];
				2'h1: sat_out_1 <= sat[sat_index];
				2'h2: sat_out_2 <= sat[sat_index];
				2'h3: sat_out_3 <= sat[sat_index];
			endcase
		end
		else
		begin
			case (sat_index[1:0])
				2'h0: sat_out <= sat_out & sat_out_0;
				2'h1: sat_out <= sat_out & sat_out_1;
				2'h2: sat_out <= sat_out & sat_out_2;
				2'h3: sat_out <= sat_out & sat_out_3;
			endcase
		end
	end
	
	// sprdata
	
	wire [4:0] sprdata_index = w697;
	
	wire [33:0] sprdata_in;
	
	assign sprdata_in[10:0] = w774;
	assign sprdata_in[19:11] = w775;
	assign sprdata_in[33:20] = { w768, w766, w764, w763, w761, w758 };
	
	assign sprdata_pattern_o = sprdata_out[10:0];
	assign sprdata_hpos_o = sprdata_out[19:11];
	assign sprdata_hflip_o = sprdata_out[20];
	assign sprdata_pal_o = sprdata_out[22:21];
	assign sprdata_priority_o = sprdata_out[23];
	assign sprdata_xs_o = sprdata_out[25:24];
	assign sprdata_ys_o = sprdata_out[27:26];
	assign sprdata_yoffset_o = sprdata_out[33:28];
	
	always @(posedge MCLK)
	begin
		if (sprdata_index < 5'd20)
		begin
			if (hclk1) // write cycle
			begin
				if (w712)
					sprdata[sprdata_index][10:0] <= sprdata_in[10:0];
				if (w715)
					sprdata[sprdata_index][19:11] <= sprdata_in[19:11];
				if (w709)
					sprdata[sprdata_index][33:20] <= sprdata_in[33:20];
			end
			sprdata_out <= sprdata[sprdata_index];
			if (sprdata_index[0])
				sprdata_out_1 <= sprdata[sprdata_index];
			else
				sprdata_out_0 <= sprdata[sprdata_index];
		end
		else
		begin
			if (sprdata_index[0])
				sprdata_out <= sprdata_out & sprdata_out_1;
			else
				sprdata_out <= sprdata_out & sprdata_out_0;
		end
	end
	
	// linebuffer
	
	wire [5:0] linebuffer_index = w825;
	
	wire [55:0] linebuffer_data_in;
	
	assign linebuffer_data_in[0] = w982;
	assign linebuffer_data_in[2:1] = w983;
	assign linebuffer_data_in[6:3] = l523;
	
	assign linebuffer_data_in[7] = w979;
	assign linebuffer_data_in[9:8] = w980;
	assign linebuffer_data_in[13:10] = l524;
	
	assign linebuffer_data_in[14] = w982;
	assign linebuffer_data_in[16:15] = w983;
	assign linebuffer_data_in[20:17] = l525;
	
	assign linebuffer_data_in[21] = w979;
	assign linebuffer_data_in[23:22] = w980;
	assign linebuffer_data_in[27:24] = l526;
	
	assign linebuffer_data_in[28] = w982;
	assign linebuffer_data_in[30:29] = w983;
	assign linebuffer_data_in[34:31] = l527;
	
	assign linebuffer_data_in[35] = w979;
	assign linebuffer_data_in[37:36] = w980;
	assign linebuffer_data_in[41:38] = l528;
	
	assign linebuffer_data_in[42] = w982;
	assign linebuffer_data_in[44:43] = w983;
	assign linebuffer_data_in[48:45] = l529;
	
	assign linebuffer_data_in[49] = w979;
	assign linebuffer_data_in[51:50] = w980;
	assign linebuffer_data_in[55:52] = l530;
	
	wire [55:0] linebuffer_out2 = w817 ? linebuffer_out : ~56'h0;
	
	generate
		for (gi = 0; gi < 8; gi = gi + 1)
		begin : gl2
			assign linebuffer_out_priority[gi] = linebuffer_out2[gi*7];
			assign linebuffer_out_pal[gi] = linebuffer_out2[gi*7+2:gi*7+1];
			assign linebuffer_out_index[gi] = linebuffer_out2[gi*7+6:gi*7+3];
		end
	endgenerate
	
	always @(posedge MCLK)
	begin
		if (linebuffer_index < 6'd40)
		begin
			if (w817) // write cycle
			begin
				if (w910)
					linebuffer[linebuffer_index][6:0] <= linebuffer_data_in[6:0];
				if (w911)
					linebuffer[linebuffer_index][13:7] <= linebuffer_data_in[13:7];
				if (w912)
					linebuffer[linebuffer_index][20:14] <= linebuffer_data_in[20:14];
				if (w913)
					linebuffer[linebuffer_index][27:21] <= linebuffer_data_in[27:21];
				if (w914)
					linebuffer[linebuffer_index][34:28] <= linebuffer_data_in[34:28];
				if (w915)
					linebuffer[linebuffer_index][41:35] <= linebuffer_data_in[41:35];
				if (w916)
					linebuffer[linebuffer_index][48:42] <= linebuffer_data_in[48:42];
				if (w917)
					linebuffer[linebuffer_index][55:49] <= linebuffer_data_in[55:49];
			end
			linebuffer_out <= linebuffer[linebuffer_index];
			if (linebuffer_index[0])
				linebuffer_out_1 <= linebuffer[linebuffer_index];
			else
				linebuffer_out_0 <= linebuffer[linebuffer_index];
		end
		else
		begin
			if (linebuffer_index[0])
				linebuffer_out <= linebuffer_out & linebuffer_out_1;
			else
				linebuffer_out <= linebuffer_out & linebuffer_out_0;
		end
	end
	
	// VRAM interface block
	
	ym_dlatch_1 dl564(.MCLK(MCLK), .c1(hclk1), .inp(l116), .nval(l564));
	
	ym_sr_bit sr565(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(l564), .sr_out(l565));
	
	ym_dlatch_1 dl566(.MCLK(MCLK), .c1(clk1), .inp(l565), .nval(l566));
	
	ym_dlatch_2 dl567(.MCLK(MCLK), .c2(clk2), .inp(l566), .nval(l567));
	
	wire l576_delay = l576; // FIXME
	
	assign w985 = (l565 & w993 & l579)
		| (l575 & l576)
		| (l575 & l576_delay);
	
	assign w986 = l568 & l577 & l579;
	assign w987 = l577 & l584 & l579;
	
	assign w988 = (l566 & l587) | l579;
	assign w989 = (l566 & ~l587) | l578;
	
	assign w990 = (w992 & l579) | l576 | reg_test0[5];
	
	ym_sr_bit sr568(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w991), .sr_out(l568));
	
	assign w991 = w286 | l571;
	
	assign w992 = l569 | ~l570;
	
	ym_dlatch_2 dl569(.MCLK(MCLK), .c2(hclk2), .inp(l570), .nval(l569));
	
	ym_dlatch_1 dl570(.MCLK(MCLK), .c1(hclk1), .inp(w1000), .nval(l570));
	
	ym_sr_bit sr571(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w286), .sr_out(l571));
	
	assign w993 = ~w992 & (l572 | ~l573);
	
	ym_dlatch_2 dl572(.MCLK(MCLK), .c2(hclk2), .inp(l573), .nval(l572));
	
	ym_dlatch_1 dl573(.MCLK(MCLK), .c1(hclk1), .inp(l590), .nval(l573));
	
	ym_sr_bit sr574(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l109), .sr_out(l574));
	
	ym_dlatch_1 dl575(.MCLK(MCLK), .c1(hclk1), .inp(w1001), .nval(l575));
	
	ym_sr_bit sr576(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(~l564), .sr_out(l576));
	
	ym_dlatch_1 dl577(.MCLK(MCLK), .c1(clk1), .inp(l576), .nval(l577));
	
	ym_dlatch_2 dl578(.MCLK(MCLK), .c2(clk2), .inp(l577), .nval(l578));
	
	ym_dlatch_1 dl579(.MCLK(MCLK), .c1(clk1), .inp(~l578), .nval(l579));
	
	assign w994 = ~((l116 & ~w265 & ~w263) | (w265 & l581));
	
	ym_dlatch_1 dl580(.MCLK(MCLK), .c1(hclk1), .inp(w994), .nval(l580));
	
	ym_sr_bit sr581(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l582), .sr_out(l581));
	
	assign w995 = l565;
	assign w996 = l576 & l567; // addr high
	assign w997 = l578 & l576; // addr low
	
	ym_sr_bit sr582(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w195), .sr_out(l582));
	
	assign w998 = l577 & l579;
	
	ym_sr_bit sr583(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1004), .sr_out(l583));
	
	ym_sr_bit sr584(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w999), .sr_out(l584));
	
	assign w999 = w288 | l585;
	
	ym_sr_bit sr585(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w288), .sr_out(l585));
	
	assign w1000 = l585 | l571;
	
	ym_sr_bit sr586(.MCLK(MCLK), .c1(clk1), .c2(clk2), .bit_in(w1007), .sr_out(l586));
	
	ym_sr_bit sr587(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1008), .sr_out(l587));
	
	ym_sr_bit sr588(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l108), .sr_out(l588));
	
	ym_sr_bit sr589(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l588), .sr_out(l589));
	
	ym_sr_bit sr590(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l574), .sr_out(l590));
	
	assign w1001 = l574 | l590 | w1008;
	
	assign w1002 = l116 & hclk1;
	
	assign w1003 = hclk2 & l580;
	
	assign w1004 = l116 & l30;
	
	ym_sr_bit sr591(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w265), .sr_out(l591));
	
	assign w1005 = hclk1 & l116;
	
	assign w1006 = clk1 & (~w109 | hclk2);
	
	assign w1007 = w109 & hclk1;
	
	assign w1008 = l588 | l589;
	
	assign w1009 = reg_test0[5] ? vram_address[16] : l614;
	
	assign w1010 = reg_m5 & vram_address[1];
	
	assign w1011 = w1010 | (~reg_m5 & vram_address[9]);
	
	assign w1013 = reg_8b_b4 ? reg_8b_b5 : vram_address[16];
	
	assign w1012 = w109 ? // 128k
		{ w1013, vram_address[15:10], w1010 } :
		{ vram_address[15:10], w1011, vram_address[0] };
	
	assign w1014 = reg_m5 ? vram_address[9:2] : vram_address[8:1];
	
	ym_slatch #(.DATA_WIDTH(8)) sl592(.MCLK(MCLK), .en(w1002), .inp(w1012), .val(l592));
	
	ym_slatch #(.DATA_WIDTH(8)) sl593(.MCLK(MCLK), .en(w1002), .inp(w1014), .val(l593));
	
	assign w1015 =
		(w997 ? l592 : 8'h0) |
		(w996 ? l593 : 8'h0) |
		(w995 ? l594 : 8'h0);
	
	ym_slatch #(.DATA_WIDTH(8)) sl594(.MCLK(MCLK), .en(w1003), .inp(w1016), .val(l594));
	
	assign w1016 = l591 ? l599 : l595;
	
	ym_slatch #(.DATA_WIDTH(8)) sl595(.MCLK(MCLK), .en(w1005), .inp(vram_data[7:0]), .val(l595));
	
	ym_slatch #(.DATA_WIDTH(8)) sl596(.MCLK(MCLK), .en(w1005), .inp(vram_data[15:8]), .val(l596));
	
	assign w1017 = l591 ? l598 : l596;
	
	ym_slatch #(.DATA_WIDTH(8)) sl597(.MCLK(MCLK), .en(w1003), .inp(w1017), .val(l597));
	
	ym_slatch #(.DATA_WIDTH(8)) sl598(.MCLK(MCLK), .en(w998), .inp(RD_i), .val(l598));
	
	ym_slatch #(.DATA_WIDTH(8)) sl599(.MCLK(MCLK), .en(w998), .inp(AD_i), .val(l599));
	
	assign w1018 = reg_test0[5] ? vram_address[7:0] : w1015;
	
	assign w1019 = reg_test0[5] ? vram_address[15:9] : l597;
	
	assign SE0 = l586;
	assign SE1 = ~l586;
	assign SC = ~w1006;
	assign RAS1 = ~w989;
	assign CAS1 = ~w988;
	assign WE1 = ~w987;
	assign WE0 = ~w986;
	assign OE1 = ~w985;
	
	assign RD_d = ~w990;
	assign AD_d = ~w990;
	
	assign RD_o = w1019;
	assign AD_o = w1018;
	
	assign YS = w1009;
	
	assign SPA_B_pull = ~l613;
	
	// Video MUX block
	
	assign w1021 = w302 | w178 | w303;
	
	ym_sr_bit sr601(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w302), .sr_out(l601));
	
	ym_sr_bit sr602(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w303), .sr_out(l602));
	
	assign w1022 = l273 ? w973 : ~l320;
	
	assign w1023 = ~l273 & w973 & l320;
	
	assign w1024 = l273 & ~w973 & ~l320;
	
	assign w1025 = ~l273 & ~w973 & l320;
	
	assign w1026 = l273 & ~w973 & l320;
	
	assign w1027 = w1029 & ~l273 & ~w973 & ~l320;
	
	assign w1028 = w1029 & ~l273 & w973 & ~l320;
	
	assign w1029 = reg_ste & reg_m5;
	
	assign w1030 = w1029 & w975 & w1065;
	
	assign w1031 = w1030 | ~w976;
	
	assign w1032 = ~w646 & (reg_m5 | w976);
	
	assign w1033 = ~reg_m5 | ~w648;
	
	assign w1034 = reg_test0[8:7] == 2'h1;
	assign w1035 = reg_test0[8:7] == 2'h2;
	assign w1036 = reg_test0[8:7] == 2'h3;
	assign w1037 = reg_test0[8:7] == 2'h0;
	
	assign w1038 = w1032 & w1024;
	
	assign w1039 = w1025 & w1033;
	
	assign w1040 = w1032 & w1033 & w1026;
	
	assign w1041 = w1038 | w1039 | w1040 | w1022 | w1023;
	
	assign w1042 = w1041 & w976 & w1062;
	
	assign w1043 = w1042 & ~w1030;
	
	assign w1044 = w1043 | w1034;
	
	assign w1045 = w1042 & w1030;
	
	assign w1046 = w1031 & w1022;
	
	assign w1047 = w1031 & w1033 & w1023;
	
	assign w1048 = w1031 & w1033 & w1025;
	
	assign w1049 = w1048 | w1047 | w1046 | w1026 | w1024;
	
	assign w1050 = w1049 & ~w1032 & w1062;
	
	assign w1051 = w1050 | w1035;
	
	assign w1052 = w1031 & w1023;
	
	assign w1053 = w1032 & w1026;
	
	assign w1054 = w1032 & w1031 & w1022;
	
	assign w1055 = w1032 & w1031 & w1024;
	
	assign w1056 = w1055 | w1053 | w1052 | w1054 | w1025;
	
	assign w1057 = w1056 & ~w1033 & w1062;
	
	assign w1058 = w1057 | w1036;
	
	assign w1059 = w1032 & w1031 & w1033;
	
	assign w1060 = w1059 | ~w1062;
	
	assign w1061 = w1060 & w1037;
	
	assign w1062 = ~reg_test0[6] & l618;
	
	ym_sr_bit sr603(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1044), .sr_out(l603));
	
	ym_sr_bit sr604(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1051), .sr_out(l604));
	
	ym_sr_bit sr605(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1058), .sr_out(l605));
	
	ym_sr_bit sr606(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1061), .sr_out(l606));
	
	assign w1063 = ~w1044 & ~w977;
	
	assign w1064 = ~w1027 & ~w1028;
	
	assign w1065 = w977 | w978;
	
	assign w1066 = w1064 & w977 & w1045;
	
	ym_sr_bit sr607(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1066), .sr_out(l607));
	
	assign w1067 = (w1045 & w978) | (~w977 & w1027) | (~w1064 & w1063);
	
	assign w1068 = w1067 & l618;
	
	ym_sr_bit sr608(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1068), .sr_out(l608));
	
	assign w1069 = reg_test0[6] ? reg_col_b6 : l608;
	
	ym_sr_bit sr609(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1069), .sr_out(l609));
	
	ym_sr_bit sr610(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l609), .sr_out(l610));
	
	assign w1070 = reg_test0[6] ? reg_col_b7 : l607;
	
	ym_sr_bit sr611(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1070), .sr_out(l611));
	
	ym_sr_bit sr612(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l611), .sr_out(l612));
	
	assign w1071 = ~(l603 & reg_8c_b4);
	
	ym_sr_bit sr613(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1071), .sr_out(l613));
	
	assign w1072 = reg_m5 & w1021;
	
	assign w1073 = ~reg_m5 & w1021;
	
	ym_slatch #(.DATA_WIDTH(4)) sl_col_index(.MCLK(MCLK), .en(w221), .inp(reg_data_l2[3:0]), .val(reg_col_index));
	
	ym_slatch #(.DATA_WIDTH(2)) sl_col_pal(.MCLK(MCLK), .en(w221), .inp(reg_data_l2[5:4]), .val(reg_col_pal));
	
	ym_slatch sl_col_b6(.MCLK(MCLK), .en(w221), .inp(reg_data_l2[6]), .val(reg_col_b6));
	
	ym_slatch sl_col_b7(.MCLK(MCLK), .en(w221), .inp(reg_data_l2[7]), .val(reg_col_b7));
	
	ym_sr_bit sr614(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1074), .sr_out(l614));
	
	ym_sr_bit sr615(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(i_spa), .sr_out(l615));
	
	assign w1074 = ~(w1082 | (l615 & ~reg_8c_b4));
	
	ym_sr_bit #(.SR_LENGTH(8)) sr616(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w389), .sr_out(l616));
	
	assign w1075 = reg_m5 ? l616 : w389;
	
	assign w1076 =
		(~w1021 ? { color_pal, color_index } : 6'h0) |
		(w1072 ? vram_address[6:1] : 6'h0) |
		(w1073 ? { 1'h0, vram_address[4:0] } : 6'h0);
	
	ym_sr_bit_array #(.DATA_WIDTH(6)) sr617(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(w1076), .data_out(l617));
	
	ym_sr_bit #(.SR_LENGTH(3)) sr618(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1075), .sr_out(l618));
	
	assign w1077 = color_index == 4'h0;
	
	ym_sr_bit sr619(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1077), .sr_out(l619));
	
	ym_sr_bit_array #(.DATA_WIDTH(3)) sr620(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(vram_data[11:9]), .data_out(l620));
	
	assign w1078 = reg_m5 ? l104[3:1] : l104[2:0];
	
	assign w1079 = reg_m5 ? l104[7:5] : l104[5:3];
	
	ym_slatch #(.DATA_WIDTH(9)) sl621(.MCLK(MCLK), .en(w1080), .inp(color_ram_out), .val(l621));
	
	ym_sr_bit_array #(.DATA_WIDTH(9)) sr622(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(vdp_cramdot_dis ? color_ram_out_dp : color_ram_out), .data_out(l622));
	
	ym_sr_bit sr623_1(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w178), .sr_out(l623_1));
	
	ym_sr_bit sr623_2(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l623_1), .sr_out(l623_2));
	
	ym_sr_bit sr623_3(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l623_2), .sr_out(l623_3));
	
	assign w1080 = l623_1 & hclk1;
	
	assign w1081 = ~(w422 | t37);
	
	ym_sr_bit sr624(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(w1081), .sr_out(l624));
	
	ym_sr_bit sr625(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l619), .sr_out(l625));
	
	assign w1082 = l625 & l624;
	
	assign w1083 = reg_m5 ? l622[1] : l622[0];
	assign w1084 = reg_m5 ? l622[2] : l622[1];
	assign w1085 = reg_m5 ? l622[4] : l622[2];
	assign w1086 = reg_m5 ? l622[5] : l622[3];
	assign w1087 = reg_m5 ? l622[7] : l622[4];
	assign w1088 = reg_m5 ? l622[8] : l622[5];
	
	assign w1089 = w1083 & l624 & reg_80_b2;
	assign w1090 = w1084 & l624 & reg_80_b2;
	assign w1091 = w1085 & l624 & reg_80_b2;
	assign w1092 = w1086 & l624 & reg_80_b2;
	assign w1093 = w1087 & l624 & reg_80_b2;
	assign w1094 = w1088 & l624 & reg_80_b2;
	
	assign w1098 = l622[6] & l624 & reg_m5;
	assign w1099 = l622[3] & l624 & reg_m5;
	assign w1100 = l622[0] & l624 & reg_m5;
	
	ym_sr_bit_array #(.DATA_WIDTH(3)) sr626(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in({ w1090, w1089, w1100 }), .data_out(l626));
	
	ym_sr_bit_array #(.DATA_WIDTH(3)) sr627(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in({ w1092, w1091, w1099 }), .data_out(l627));
	
	ym_sr_bit_array #(.DATA_WIDTH(3)) sr628(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in({ w1094, w1093, w1098 }), .data_out(l628));
	
	ym_sr_bit sr629(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l610), .sr_out(l629));
	
	ym_sr_bit sr630(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(l612), .sr_out(l630));
	
	assign w1101 = ~(l629 | l630 | ~reg_m5);
	
	assign w1102 = ~l630 & l629;
	
	wire [7:0] r_col;
	wire [7:0] g_col;
	wire [7:0] b_col;
	
	assign r_col[0] = l626 == 3'h0;
	assign r_col[1] = l626 == 3'h1;
	assign r_col[2] = l626 == 3'h2;
	assign r_col[3] = l626 == 3'h3;
	assign r_col[4] = l626 == 3'h4;
	assign r_col[5] = l626 == 3'h5;
	assign r_col[6] = l626 == 3'h6;
	assign r_col[7] = l626 == 3'h7;
	
	assign g_col[0] = l627 == 3'h0;
	assign g_col[1] = l627 == 3'h1;
	assign g_col[2] = l627 == 3'h2;
	assign g_col[3] = l627 == 3'h3;
	assign g_col[4] = l627 == 3'h4;
	assign g_col[5] = l627 == 3'h5;
	assign g_col[6] = l627 == 3'h6;
	assign g_col[7] = l627 == 3'h7;
	
	assign b_col[0] = l628 == 3'h0;
	assign b_col[1] = l628 == 3'h1;
	assign b_col[2] = l628 == 3'h2;
	assign b_col[3] = l628 == 3'h3;
	assign b_col[4] = l628 == 3'h4;
	assign b_col[5] = l628 == 3'h5;
	assign b_col[6] = l628 == 3'h6;
	assign b_col[7] = l628 == 3'h7;
	
	assign w1103[0][0] = (w1101 & r_col[0]) | (~reg_m5 & r_col[0]) | (~reg_m5 & r_col[1]) | (w1102 & r_col[0]);
	assign w1103[0][1] = (w1102 & r_col[1]);
	assign w1103[0][2] = (w1101 & r_col[1]) | (w1102 & r_col[2]);
	assign w1103[0][3] = (w1102 & r_col[3]);
	assign w1103[0][4] = (w1101 & r_col[2]) | (w1102 & r_col[4]);
	assign w1103[0][5] = (~reg_m5 & r_col[2]) | (~reg_m5 & r_col[3]);
	assign w1103[0][6] = (w1102 & r_col[5]);
	assign w1103[0][7] = (w1101 & r_col[3]) | (w1102 & r_col[6]);
	assign w1103[0][8] = (w1102 & r_col[7]) | (l630 & r_col[0]);
	assign w1103[0][9] = (w1101 & r_col[4]) | (l630 & r_col[1]);
	assign w1103[0][10] = (l630 & r_col[2]);
	assign w1103[0][11] = (~reg_m5 & r_col[4]) | (~reg_m5 & r_col[5]);
	assign w1103[0][12] = (w1101 & r_col[5]) | (l630 & r_col[3]);
	assign w1103[0][13] = (l630 & r_col[4]);
	assign w1103[0][14] = (w1101 & r_col[6]) | (l630 & r_col[5]);
	assign w1103[0][15] = (l630 & r_col[6]);
	assign w1103[0][16] = (w1101 & r_col[7]) | (~reg_m5 & r_col[6]) | (~reg_m5 & r_col[7]) | (l630 & r_col[7]);
	
	assign w1103[1][0] = (w1101 & g_col[0]) | (~reg_m5 & g_col[0]) | (~reg_m5 & g_col[1]) | (w1102 & g_col[0]);
	assign w1103[1][1] = (w1102 & g_col[1]);
	assign w1103[1][2] = (w1101 & g_col[1]) | (w1102 & g_col[2]);
	assign w1103[1][3] = (w1102 & g_col[3]);
	assign w1103[1][4] = (w1101 & g_col[2]) | (w1102 & g_col[4]);
	assign w1103[1][5] = (~reg_m5 & g_col[2]) | (~reg_m5 & g_col[3]);
	assign w1103[1][6] = (w1102 & g_col[5]);
	assign w1103[1][7] = (w1101 & g_col[3]) | (w1102 & g_col[6]);
	assign w1103[1][8] = (w1102 & g_col[7]) | (l630 & g_col[0]);
	assign w1103[1][9] = (w1101 & g_col[4]) | (l630 & g_col[1]);
	assign w1103[1][10] = (l630 & g_col[2]);
	assign w1103[1][11] = (~reg_m5 & g_col[4]) | (~reg_m5 & g_col[5]);
	assign w1103[1][12] = (w1101 & g_col[5]) | (l630 & g_col[3]);
	assign w1103[1][13] = (l630 & g_col[4]);
	assign w1103[1][14] = (w1101 & g_col[6]) | (l630 & g_col[5]);
	assign w1103[1][15] = (l630 & g_col[6]);
	assign w1103[1][16] = (w1101 & g_col[7]) | (~reg_m5 & g_col[6]) | (~reg_m5 & g_col[7]) | (l630 & g_col[7]);
	
	assign w1103[2][0] = (w1101 & b_col[0]) | (~reg_m5 & b_col[0]) | (~reg_m5 & b_col[1]) | (w1102 & b_col[0]);
	assign w1103[2][1] = (w1102 & b_col[1]);
	assign w1103[2][2] = (w1101 & b_col[1]) | (w1102 & b_col[2]);
	assign w1103[2][3] = (w1102 & b_col[3]);
	assign w1103[2][4] = (w1101 & b_col[2]) | (w1102 & b_col[4]);
	assign w1103[2][5] = (~reg_m5 & b_col[2]) | (~reg_m5 & b_col[3]);
	assign w1103[2][6] = (w1102 & b_col[5]);
	assign w1103[2][7] = (w1101 & b_col[3]) | (w1102 & b_col[6]);
	assign w1103[2][8] = (w1102 & b_col[7]) | (l630 & b_col[0]);
	assign w1103[2][9] = (w1101 & b_col[4]) | (l630 & b_col[1]);
	assign w1103[2][10] = (l630 & b_col[2]);
	assign w1103[2][11] = (~reg_m5 & b_col[4]) | (~reg_m5 & b_col[5]);
	assign w1103[2][12] = (w1101 & b_col[5]) | (l630 & b_col[3]);
	assign w1103[2][13] = (l630 & b_col[4]);
	assign w1103[2][14] = (w1101 & b_col[6]) | (l630 & b_col[5]);
	assign w1103[2][15] = (l630 & b_col[6]);
	assign w1103[2][16] = (w1101 & b_col[7]) | (~reg_m5 & b_col[6]) | (~reg_m5 & b_col[7]) | (l630 & b_col[7]);
	
/*
	// linear DAC
	assign DAC_R =
		(w1103[0][0] ? 8'd0 : 8'd0) |
		(w1103[0][1] ? 8'd18 : 8'd0) |
		(w1103[0][2] ? 8'd36 : 8'd0) |
		(w1103[0][3] ? 8'd54 : 8'd0) |
		(w1103[0][4] ? 8'd72 : 8'd0) |
		(w1103[0][5] ? 8'd85 : 8'd0) |
		(w1103[0][6] ? 8'd91 : 8'd0) |
		(w1103[0][7] ? 8'd109 : 8'd0) |
		(w1103[0][8] ? 8'd127 : 8'd0) |
		(w1103[0][9] ? 8'd145 : 8'd0) |
		(w1103[0][10] ? 8'd163 : 8'd0) |
		(w1103[0][11] ? 8'd170 : 8'd0) |
		(w1103[0][12] ? 8'd182 : 8'd0) |
		(w1103[0][13] ? 8'd200 : 8'd0) |
		(w1103[0][14] ? 8'd218 : 8'd0) |
		(w1103[0][15] ? 8'd236 : 8'd0) |
		(w1103[0][16] ? 8'd255 : 8'd0);
	
	assign DAC_G =
		(w1103[1][0] ? 8'd0 : 8'd0) |
		(w1103[1][1] ? 8'd18 : 8'd0) |
		(w1103[1][2] ? 8'd36 : 8'd0) |
		(w1103[1][3] ? 8'd54 : 8'd0) |
		(w1103[1][4] ? 8'd72 : 8'd0) |
		(w1103[1][5] ? 8'd85 : 8'd0) |
		(w1103[1][6] ? 8'd91 : 8'd0) |
		(w1103[1][7] ? 8'd109 : 8'd0) |
		(w1103[1][8] ? 8'd127 : 8'd0) |
		(w1103[1][9] ? 8'd145 : 8'd0) |
		(w1103[1][10] ? 8'd163 : 8'd0) |
		(w1103[1][11] ? 8'd170 : 8'd0) |
		(w1103[1][12] ? 8'd182 : 8'd0) |
		(w1103[1][13] ? 8'd200 : 8'd0) |
		(w1103[1][14] ? 8'd218 : 8'd0) |
		(w1103[1][15] ? 8'd236 : 8'd0) |
		(w1103[1][16] ? 8'd255 : 8'd0);
	
	assign DAC_B =
		(w1103[2][0] ? 8'd0 : 8'd0) |
		(w1103[2][1] ? 8'd18 : 8'd0) |
		(w1103[2][2] ? 8'd36 : 8'd0) |
		(w1103[2][3] ? 8'd54 : 8'd0) |
		(w1103[2][4] ? 8'd72 : 8'd0) |
		(w1103[2][6] ? 8'd91 : 8'd0) |
		(w1103[2][5] ? 8'd102 : 8'd0) |
		(w1103[2][7] ? 8'd109 : 8'd0) |
		(w1103[2][8] ? 8'd127 : 8'd0) |
		(w1103[2][9] ? 8'd145 : 8'd0) |
		(w1103[2][10] ? 8'd163 : 8'd0) |
		(w1103[2][11] ? 8'd170 : 8'd0) |
		(w1103[2][12] ? 8'd182 : 8'd0) |
		(w1103[2][13] ? 8'd200 : 8'd0) |
		(w1103[2][14] ? 8'd218 : 8'd0) |
		(w1103[2][15] ? 8'd236 : 8'd0) |
		(w1103[2][16] ? 8'd255 : 8'd0);
*/
	// non-linear DAC (caused by voltage divider on MD board)
	assign DAC_R =
		(w1103[0][0] ? 8'd0 : 8'd0) |
		(w1103[0][1] ? 8'd27 : 8'd0) |
		(w1103[0][2] ? 8'd49 : 8'd0) |
		(w1103[0][3] ? 8'd67 : 8'd0) |
		(w1103[0][4] ? 8'd84 : 8'd0) |
		(w1103[0][5] ? 8'd95 : 8'd0) |
		(w1103[0][6] ? 8'd100 : 8'd0) |
		(w1103[0][7] ? 8'd114 : 8'd0) |
		(w1103[0][8] ? 8'd128 : 8'd0) |
		(w1103[0][9] ? 8'd142 : 8'd0) |
		(w1103[0][10] ? 8'd156 : 8'd0) |
		(w1103[0][11] ? 8'd161 : 8'd0) |
		(w1103[0][12] ? 8'd172 : 8'd0) |
		(w1103[0][13] ? 8'd188 : 8'd0) |
		(w1103[0][14] ? 8'd206 : 8'd0) |
		(w1103[0][15] ? 8'd228 : 8'd0) |
		(w1103[0][16] ? 8'd255 : 8'd0);
	
	assign DAC_G =
		(w1103[1][0] ? 8'd0 : 8'd0) |
		(w1103[1][1] ? 8'd27 : 8'd0) |
		(w1103[1][2] ? 8'd49 : 8'd0) |
		(w1103[1][3] ? 8'd67 : 8'd0) |
		(w1103[1][4] ? 8'd84 : 8'd0) |
		(w1103[1][5] ? 8'd95 : 8'd0) |
		(w1103[1][6] ? 8'd100 : 8'd0) |
		(w1103[1][7] ? 8'd114 : 8'd0) |
		(w1103[1][8] ? 8'd128 : 8'd0) |
		(w1103[1][9] ? 8'd142 : 8'd0) |
		(w1103[1][10] ? 8'd156 : 8'd0) |
		(w1103[1][11] ? 8'd161 : 8'd0) |
		(w1103[1][12] ? 8'd172 : 8'd0) |
		(w1103[1][13] ? 8'd188 : 8'd0) |
		(w1103[1][14] ? 8'd206 : 8'd0) |
		(w1103[1][15] ? 8'd228 : 8'd0) |
		(w1103[1][16] ? 8'd255 : 8'd0);
	
	assign DAC_B =
		(w1103[2][0] ? 8'd0 : 8'd0) |
		(w1103[2][1] ? 8'd27 : 8'd0) |
		(w1103[2][2] ? 8'd49 : 8'd0) |
		(w1103[2][3] ? 8'd67 : 8'd0) |
		(w1103[2][4] ? 8'd84 : 8'd0) |
		(w1103[2][6] ? 8'd100 : 8'd0) |
		(w1103[2][5] ? 8'd109 : 8'd0) |
		(w1103[2][7] ? 8'd114 : 8'd0) |
		(w1103[2][8] ? 8'd128 : 8'd0) |
		(w1103[2][9] ? 8'd142 : 8'd0) |
		(w1103[2][10] ? 8'd156 : 8'd0) |
		(w1103[2][11] ? 8'd161 : 8'd0) |
		(w1103[2][12] ? 8'd172 : 8'd0) |
		(w1103[2][13] ? 8'd188 : 8'd0) |
		(w1103[2][14] ? 8'd206 : 8'd0) |
		(w1103[2][15] ? 8'd228 : 8'd0) |
		(w1103[2][16] ? 8'd255 : 8'd0);
	
	// color ram
	
	wire [5:0] color_ram_index = l617;
	
	wire [8:0] color_ram_data_in = { l620, w1079, w1078 };
	
	always @(posedge MCLK)
	begin
		if (hclk1) // write cycle
		begin
			if (l602)
				color_ram[color_ram_index][5:0] <= color_ram_data_in[5:0];
			if (l601)
				color_ram[color_ram_index][8:6] <= color_ram_data_in[8:6];
		end
		color_ram_out <= color_ram[color_ram_index];
	end
	
	// PSG block
	
	assign psg_clk1 = cpu_clk0;
	assign psg_clk2 = ~cpu_clk0;
	
	ym_sr_bit sr631(.MCLK(MCLK), .c1(psg_clk1), .c2(psg_clk2), .bit_in(reset_comb), .sr_out(l631));
	ym_sr_bit sr632(.MCLK(MCLK), .c1(psg_clk1), .c2(psg_clk2), .bit_in(l631), .sr_out(l632));
	
	assign w1104 = l631 & ~l632;
	
	assign w1105 = ~w1104 & ~l633;
	
	ym_cnt_bit cnt649(.MCLK(MCLK), .c1(psg_clk1), .c2(psg_clk2), .c_in(l633), .reset(w1104), .val(l649));
	
	ym_sr_bit sr633(.MCLK(MCLK), .c1(psg_clk1), .c2(psg_clk2), .bit_in(w1105), .sr_out(l633));
	
	ym_dlatch_1 dl634(.MCLK(MCLK), .c1(psg_clk1), .inp(l649), .nval(l634));
	
	assign psg_hclk1 = l634 & l633;
	
	assign psg_hclk2 = ~l634 & l633;
	
	ym7101_rs_trig rs43(.MCLK(MCLK), .set(l635), .rst(w111), .q(t43));
	
	assign w1106 = ~t43 & ~w111;
	
	ym_sr_bit sr635(.MCLK(MCLK), .c1(psg_clk1), .c2(psg_clk2), .bit_in(w1106), .sr_out(l635));
	
	ym_sr_bit sr636(.MCLK(MCLK), .c1(psg_clk1), .c2(psg_clk2), .bit_in(l635), .sr_out(l636));
	
	ym_sr_bit sr637(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(reset_comb), .sr_out(l637));
	
	ym7101_rs_trig rs44(.MCLK(MCLK), .set(w1142), .rst(l638), .q(t44));
	
	ym_sr_bit sr638(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(t44), .sr_out(l638));
	
	assign w1107 = ~l638 & ~l637;
	
	assign w1108 = w1107 & ~w1110;
	
	assign w1109 = w1107 & w1110;
	
	assign w1110 = ~l639 & w1111;
	
	ym_sr_bit sr639(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(w1111), .sr_out(l639));
	
	assign w1111 = l662[1:0] == 2'h3 ? l647 : l648;
	
	assign w1112 = reg_test0[9] & reg_test0[11:10] != 2'h0;
	assign w1113 = reg_test0[9] & reg_test0[11:10] != 2'h1;
	assign w1114 = reg_test0[9] & reg_test0[11:10] != 2'h2;
	assign w1115 = reg_test0[9] & reg_test0[11:10] != 2'h3;
	
	assign w1116 = w1121 ? l644 : 10'h0;
	
	assign w1117 = w1116 + 10'h1;
	
	assign w1118 = l640[15] ^ l640[12];
	
	ym_sr_bit_en #(.SR_LENGTH(16)) sr640(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .en1(w1109), .en2(w1108),
		.data_in(~w1119 | ~w1120), .data_out(l640));
	
	assign w1119 = l640[14:0] != 15'h0;
	
	assign w1120 = ~(w1118 & l662[2]);
	
	ym_sr_bit_array #(.DATA_WIDTH(10)) sr641(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .data_in(w1117), .data_out(l641));
	
	ym_sr_bit_array #(.DATA_WIDTH(10)) sr642(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .data_in(l641), .data_out(l642));
	
	ym_sr_bit_array #(.DATA_WIDTH(10)) sr643(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .data_in(l642), .data_out(l643));
	
	ym_sr_bit_array #(.DATA_WIDTH(10)) sr644(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .data_in(l643), .data_out(l644));
	
	assign w1121 = ~l651 & ~w1127;
	
	assign w1122 = l650[0] & l652[3];
	assign w1123 = l650[0] & l652[2];
	assign w1124 = l650[0] & l652[1];
	assign w1125 = l650[0] & l652[0];
	
	ym_cnt_bit cnt645(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .c_in(w1122), .reset(l651), .val(l645));
	
	ym_cnt_bit cnt646(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .c_in(w1123), .reset(l651), .val(l646));
	
	ym_cnt_bit cnt647(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .c_in(w1124), .reset(l651), .val(l647));
	
	ym_cnt_bit cnt648(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .c_in(w1125), .reset(l651), .val(l648));
	
	assign w1126 =
		(w1131 ? l659 : 10'h0) |
		(w1130 ? l660 : 10'h0) |
		(w1129 ? l661 : 10'h0) |
		(w1128 ? { 3'h0, l662[1:0] == 2'h2, l662[1:0] == 2'h1, l662[1:0] == 2'h0, 4'h0 } : 10'h0);
	
	assign w1127 = w1126 <= l644;
	
	assign w1128 = l650[3] & ~l651;
	assign w1129 = l650[2] & ~l651;
	assign w1130 = l650[1] & ~l651;
	assign w1131 = l650[0] & ~l651;
	
	ym_sr_bit sr650_0(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(w1132), .sr_out(l650[0]));
	
	ym_sr_bit sr650_1(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(l650[0]), .sr_out(l650[1]));
	
	ym_sr_bit sr650_2(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(l650[1]), .sr_out(l650[2]));
	
	ym_sr_bit sr650_3(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(l650[2]), .sr_out(l650[3]));

	assign w1132 = l650[2:0] == 3'h0 & ~l637;
	
	ym_sr_bit sr651(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(l637), .sr_out(l651));
	
	assign w1133 = ~l651;
	
	ym_sr_bit sr652_0(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(w1127), .sr_out(l652[0]));
	
	ym_sr_bit sr652_1(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(l652[0]), .sr_out(l652[1]));
	
	ym_sr_bit sr652_2(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(l652[1]), .sr_out(l652[2]));
	
	ym_sr_bit sr652_3(.MCLK(MCLK), .c1(psg_hclk1), .c2(psg_hclk2), .bit_in(l652[2]), .sr_out(l652[3]));
	
	ym_slatch #(.DATA_WIDTH(8)) sl653(.MCLK(MCLK), .en(w111), .inp(io_data[7:0]), .val(l653));
	
	assign w1134 = w1133 ? l653 : 8'h0;
	
	ym_slatch #(.DATA_WIDTH(3)) sl654(.MCLK(MCLK), .en(l635 & w1134[7]), .inp(w1134[6:4]), .val(l654));
	
	assign w1135 = l637 | (l636 & l654 == 3'h1);
	assign w1136 = l637 | (l636 & l654 == 3'h3);
	assign w1137 = l637 | (l636 & l654 == 3'h4);
	assign w1138 = l637 | (l636 & l654 == 3'h2);
	assign w1139 = l637 | (l636 & l654 == 3'h5);
	assign w1140 = l637 | (l636 & l654 == 3'h0);
	assign w1141 = l637 | (l636 & l654 == 3'h7);
	assign w1142 = l637 | (l636 & l654 == 3'h6);
	
	assign w1143 = w1133 ? w1134[3:0] : 4'hf;
	
	ym_slatch #(.DATA_WIDTH(4)) sl655(.MCLK(MCLK), .en(w1135), .inp(w1143), .val(l655));
	
	ym_slatch #(.DATA_WIDTH(4)) sl656(.MCLK(MCLK), .en(w1136), .inp(w1143), .val(l656));
	
	ym_slatch #(.DATA_WIDTH(4)) sl657(.MCLK(MCLK), .en(w1139), .inp(w1143), .val(l657));
	
	ym_slatch #(.DATA_WIDTH(4)) sl658(.MCLK(MCLK), .en(w1141), .inp(w1143), .val(l658));
	
	assign w1144 = w1134[7] | l637;
	
	ym_slatch #(.DATA_WIDTH(6)) sl661_1(.MCLK(MCLK), .en(w1137 & ~w1134[7]), .inp(w1134[5:0]), .val(l661[9:4]));
	ym_slatch #(.DATA_WIDTH(4)) sl661_2(.MCLK(MCLK), .en(w1137 & w1144), .inp(w1134[3:0]), .val(l661[3:0]));
	
	ym_slatch #(.DATA_WIDTH(6)) sl660_1(.MCLK(MCLK), .en(w1138 & ~w1134[7]), .inp(w1134[5:0]), .val(l660[9:4]));
	ym_slatch #(.DATA_WIDTH(4)) sl660_2(.MCLK(MCLK), .en(w1138 & w1144), .inp(w1134[3:0]), .val(l660[3:0]));
	
	ym_slatch #(.DATA_WIDTH(6)) sl659_1(.MCLK(MCLK), .en(w1140 & ~w1134[7]), .inp(w1134[5:0]), .val(l659[9:4]));
	ym_slatch #(.DATA_WIDTH(4)) sl659_2(.MCLK(MCLK), .en(w1140 & w1144), .inp(w1134[3:0]), .val(l659[3:0]));
	
	ym_slatch #(.DATA_WIDTH(3)) sl662(.MCLK(MCLK), .en(w1142), .inp(w1134[2:0]), .val(l662));
	
	assign w1145 = ~reg_test0[9] & ~l645;
	assign w1146 = ~reg_test0[9] & ~l646;
	assign w1147 = ~reg_test0[9] & ~l647;
	assign w1148 = ~reg_test0[9] & ~l640[14];
	
	assign w1149 = w1145 ? 4'hf : l655;
	assign w1150 = w1146 ? 4'hf : l656;
	assign w1151 = w1147 ? 4'hf : l657;
	assign w1152 = w1148 ? 4'hf : l658;
	
	function [15:0] psg_vol;
		input [3:0] value;
		begin
			case (value)
				4'h0   : psg_vol = 16'd1200;
				4'h1   : psg_vol = 16'd0926;
				4'h2   : psg_vol = 16'd0746;
				4'h3   : psg_vol = 16'd0582;
				4'h4   : psg_vol = 16'd0458;
				4'h5   : psg_vol = 16'd0348;
				4'h6   : psg_vol = 16'd0274;
				4'h7   : psg_vol = 16'd0208;
				4'h8   : psg_vol = 16'd0158;
				4'h9   : psg_vol = 16'd0115;
				4'ha   : psg_vol = 16'd0086;
				4'hb   : psg_vol = 16'd0061;
				4'hc   : psg_vol = 16'd0040;
				4'hd   : psg_vol = 16'd0022;
				4'he   : psg_vol = 16'd0010;
				4'hf   : psg_vol = 16'd0000;
				default: psg_vol = 16'd0000;
			endcase
		end
	endfunction

	wire [15:0] psg_val[0:3]; // PSG Volume

	assign psg_val[0] = w1112 ? -16'd1270 : psg_vol(w1149);
	assign psg_val[1] = w1113 ? -16'd1270 : psg_vol(w1150);
	assign psg_val[2] = w1114 ? -16'd1270 : psg_vol(w1151);
	assign psg_val[3] = w1115 ? -16'd1270 : psg_vol(w1152);
	
	//assign SOUND = psg_val[0] + psg_val[1] + psg_val[2] + psg_val[3];
	
	always @(posedge MCLK)
	begin
		SOUND <= psg_val[0] + psg_val[1] + psg_val[2] + psg_val[3];
	end
	
	// vram bus
	
	ym_dlatch_1 #(.DATA_WIDTH(8)) dl_vs(.MCLK(MCLK), .c1(clk1), .inp(SD), .val(vram_serial));
	
	wire [15:0] vram_data_val =
		(w328 ? { l96, w351 } : 16'hffff) &
		(w327 ? { l98, w352 } : 16'hffff) &
		(w329 ? { l100, w353 } : 16'hffff) &
		(w326 ? { l102, w354 } : 16'hffff) &
		(l183 ? { 5'h1f, l180 } : 16'hffff) &
		(l330 ? { 5'h1f, l324 } : 16'hffff) &
		(l583 ? { l598, l599 } : 16'hffff) &
		(l623_3 ? { 4'hf, l621[8:6], 1'h1, l621[5:3], 1'h1, l621[2:0], 1'h1 } : 16'hffff);
		
	wire [15:0] vram_data_pull =
		(w328 ? 16'hffff : 16'h0) |
		(w327 ? 16'hffff : 16'h0) |
		(w329 ? 16'hffff : 16'h0) |
		(w326 ? 16'hffff : 16'h0) |
		(l183 ? 16'h07ff : 16'h0) |
		(l330 ? 16'h07ff : 16'h0) |
		(l583 ? 16'hffff : 16'h0) |
		(l623_3 ? 16'heee : 16'h0);
	
	wire [16:0] vram_address_val =
		(w195 ? { reg_sa_high[0], reg_sa_low } : 17'h1ffff) &
		(w191 ? reg_data_l2[16:0] : 17'h1ffff) &
		(w275 ? { l35[16:1], ~l35[0] } : 17'h1ffff) &
		(w257 ? l36 : 17'h1ffff) &
		(w258 ? l37 : 17'h1ffff) &
		(w259 ? l38 : 17'h1ffff) &
		(w260 ? l39 : 17'h1ffff) &
		(w531 ? { w532[3:1], 14'h3fff } : 17'h1ffff) &
		(w558 ? { 3'h7, w532[0], w533, w527[4:0], w555[4:0], 1'h0 } : 17'h1ffff) &
		(w643 ? { reg_hs, w535, 2'h0 } : 17'h1ffff) & // hscroll
		(l202 ? { reg_wd[5:1], w536, l106[7:4], 2'h0 } : 17'h1ffff) & // window
		(l196 ? { 12'hfff, w577[2:0], ~l198, 1'h0 } : 17'h1ffff) &
		(l199 ? { 3'h7, w578, 5'h1f } : 17'h1ffff) &
		(w566 ? { w579, 14'h3fff } : 17'h1ffff) &
		(l218 ? { w580, 5'h1f } : 17'h1ffff) &
		(w684 ? { 9'h1ff, 2'h0, l351[4:0], 1'h0 } : 17'h1ffff) &
		(w742 ? { 3'h7, reg_86_b2, w731[7:1], w737, w735, w734, w733, ~l106[1], 1'h0 } : 17'h1ffff) &
		(w754 ? { 3'h7, reg_at[6:1], 8'hff} : 17'h1ffff) &
		(w756 ? { reg_at[7:1], w757[6:0], 3'h4 } : 17'h1ffff) &
		(w755 ? { 9'h1ff, l409[7], l408[7], l407[7], l406[7], l405[7], l404[7], l403[7], 1'h0 } : 17'h1ffff) &
		(l428 ? (w106 ?
			{ w780, l418[3], l418[2:0], 2'h0 } : { reg_86_b5, w780, l418[2:0], 2'h0 }) : 17'h1ffff);
	
	wire [16:0] vram_address_pull =
		(w195 ? 17'h1ffff : 17'h0) |
		(w191 ? 17'h1ffff : 17'h0) |
		(w275 ? 17'h1ffff : 17'h0) |
		(w257 ? 17'h1ffff : 17'h0) |
		(w258 ? 17'h1ffff : 17'h0) |
		(w259 ? 17'h1ffff : 17'h0) |
		(w260 ? 17'h1ffff : 17'h0) |
		(w531 ? 17'h1c000 : 17'h0) |
		(w558 ? 17'h03fff : 17'h0) |
		(w643 ? 17'h1ffff : 17'h0) |
		(l202 ? 17'h1ffff : 17'h0) | 
		(l196 ? 17'h0001f : 17'h0) |
		(l199 ? 17'h03fe0 : 17'h0) |
		(w566 ? 17'h1c000 : 17'h0) |
		(l218 ? 17'h1ffe0 : 17'h0) |
		(w684 ? 17'h000ff : 17'h0) |
		(w742 ? 17'h03fff : 17'h0) |
		(w754 ? 17'h03f00 : 17'h0) |
		(w756 ? 17'h1ffff : 17'h0) |
		(w755 ? 17'h000ff : 17'h0) |
		(l428 ? 17'h1ffff : 17'h0);
	
	/*assign vram_data =
		(w328 ? { l96, w351 } : 16'h0) |
		(w327 ? { l98, w352 } : 16'h0) |
		(w329 ? { l100, w353 } : 16'h0) |
		(w326 ? { l102, w354 } : 16'h0) |
		(l183 ? { 5'h0, l180 } : 16'h0) |
		(l330 ? { 5'h0, l324 } : 16'h0) |
		(l583 ? { l598, l599 } : 16'h0) |
		(l623_3 ? { 4'h0, l621[8:6], 1'h0, l621[5:3], 1'h0, l621[2:0], 1'h0 } : 16'h0);*/
		
	/*assign vram_address =
		(w195 ? { reg_sa_high[0], reg_sa_low } : 17'h0) |
		(w191 ? reg_data_l2[16:0] : 17'h0) |
		(w275 ? { l35[16:1], ~l35[0] } : 17'h0) |
		(w257 ? l36 : 17'h0) |
		(w258 ? l37 : 17'h0) |
		(w259 ? l38 : 17'h0) |
		(w260 ? l39 : 17'h0) |
		(w531 ? { w532[3:1], 14'h0 } : 17'h0) |
		(w558 ? { 3'h0, w532[0], w533, w527[4:0], w555[4:0], 1'h0 } : 17'h0) |
		(w643 ? { reg_hs, w535, 2'h0 } : 17'h0) | // hscroll
		(l202 ? { reg_wd[5:1], w536, l106[7:4], 2'h0 } : 17'h0) | // window
		(l196 ? { 12'h0, w577[2:0], ~l198, 1'h0 } : 17'h0) |
		(l199 ? { 3'h0, w578, 5'h0 } : 17'h0) |
		(w566 ? { w579, 14'h0 } : 17'h0) |
		(l218 ? { w580, 5'h0 } : 17'h0) |
		(w684 ? { 9'h0, 2'h0, l351[4:0], 1'h0 } : 17'h0) |
		(w742 ? { 3'h0, reg_86_b2, w731[7:1], w737, w735, w734, w733, ~l106[1], 1'h0 } : 17'h0) |
		(w754 ? { 3'h0, reg_at[6:1], 8'h0} : 17'h0) |
		(w756 ? { reg_at[7:1], w757[6:0], 3'h4 } : 17'h0) |
		(w755 ? { 9'h0, l409[7], l408[7], l407[7], l406[7], l405[7], l404[7], l403[7], 1'h0 } : 17'h0) |
		(l428 ? (w106 ?
			{ w780, l418[3], l418[2:0], 2'h0 } : { reg_86_b5, w780, l418[2:0], 2'h0 }) : 17'h0);*/
	
	always @(posedge MCLK)
	begin
		vram_data <= (vram_data_pull & vram_data_val) | (~vram_data_pull & vram_data);	
		vram_address <= (vram_address_pull & vram_address_val) | (~vram_address_pull & vram_address);
	end
	
	// io bus
	
	wire vdp_data_dir = ~cdd_n | ext_test_2;
	wire vdp_address_dir = ~w267 | ext_test_2;
	
	wire [22:0] io_address_val =
		(vdp_address_dir ? (CA_i & 23'h73ffff) : 23'h73ffff) &
		(w267 ? ({ reg_sa_high, reg_sa_low } & 23'h33ffff) : 23'h73ffff);
	
	wire [22:0] io_address_pull =
		(vdp_address_dir ? 23'h73ffff : 23'h0) |
		(w267 ? 23'h33ffff : 23'h0);
	
	//reg [22:0] io_address_mem = 23'h0;
	
	wire [22:0] io_address_t = (io_address_pull & io_address_val) | (~io_address_pull & io_address);
	
	assign CA_o[22] = io_address_22o;
	assign CA_o[21:0] = io_address[21:0];
	
	assign CA_d = vdp_address_dir;
	
	wire [15:0] io_data_val =
		(vdp_data_dir ? CD_i : 16'hffff) &
		(w97 ? { 2'h3, l418[5:3], w770 } : 16'hffff) &
		(w71 ? { 5'h1f, ~w355[9], ~w355[8], ~l106[0], 8'hff} : 16'hffff) &
		(w114 ? { 6'h3f, l46, w252, t9, t10, t11, w446, w439, w422, w73, w72 } : 16'hffff) &
		(w134 ? { l90[7:0], 8'hff } : 16'hffff) &
		(w142 ? { 8'hff, w347[7:0] } : 16'hffff) &
		(w160 ? { l93[7:0], l92[7:0] } : 16'hffff) &
		(w47 ? { 8'hff, 5'h0, w12, w11, 1'h0 } : 16'hffff) &
		(w87 ? { 8'hff, ~l110, ~w360, ~w379, ~w393, ~w402, ~w417, ~w415, ~w424 } : 16'hffff) &
		(w89 ? { 2'h3, ~l156, ~w418, ~w419, ~l147, ~l142, ~l141, ~l134, ~l116, ~w394, ~w385, ~w372, ~w356, ~l108, ~l109 } : 16'hffff) &
		(w95 ? { 4'hf, l410[19], l409[19], l408[19], l407[19], l406[19], l405[19], l404[19], l403[19], l391[9], l390[9], l389[9], l388[9] } : 16'hffff) &
		(w99 ? { 1'h1, ~w969, ~w968, ~w967, ~w966, ~w965, ~w964, ~w963, 1'h1, ~w962, ~w961, ~w960, ~w959, ~w958, ~w957, ~w956 } : 16'hffff) &
		(w91 ? { 5'h1f, ~w1094, ~w1093, ~w1098, ~w1092, ~w1091, ~w1099, ~w1090, ~w1089, ~w1100, ~l610, ~l612 } : 16'hffff) &
		(w93 ? { ~w1149, ~w1150, ~w1151, ~w1152 } : 16'hffff);
	
	wire [15:0] io_data_pull =
		(vdp_data_dir ? 16'hffff : 16'h0) |
		(w97 ? 16'h3fff : 16'h0) |
		(w71 ? 16'h0700 : 16'h0) |
		(w114 ? 16'h03ff : 16'h0) |
		(w134 ? 16'hff00 : 16'h0) |
		(w142 ? 16'h00ff : 16'h0) |
		(w160 ? 16'hffff : 16'h0) |
		(w47 ? 16'h00ff : 16'h0) |
		(w87 ? 16'h00ff : 16'h0) |
		(w89 ? 16'h3fff : 16'h0) |
		(w95 ? 16'h0fff : 16'h0) |
		(w99 ? 16'h7f7f : 16'h0) |
		(w91 ? 16'h07ff : 16'h0) |
		(w93 ? 16'hffff : 16'h0);
	
	//reg [15:0] io_data_mem = 16'h0;
	
	/*assign io_data =
		(vdp_data_dir ? CD_i : 16'h0) |
		(w97 ? { 2'h0, l418[5:3], w770 } : 16'h0) |
		(w71 ? { 5'h0, ~w355[9], ~w355[8], ~l106[0], 8'h0} : 16'h0) |
		(w114 ? { 6'h0, l46, w252, t9, t10, t11, w446, w439, w422, w73, w72 } : 16'h0) |
		(w134 ? { l90[7:0], 8'h0 } : 16'h0) |
		(w142 ? { 8'h0, w347[7:0] } : 16'h0) |
		(w160 ? { l93[7:0], l92[7:0] } : 16'h0) |
		(w47 ? { 8'h0, 5'h0, w12, w11, 1'h0 } : 16'h0) |
		(w87 ? { 8'h0, ~l110, ~w360, ~w379, ~w393, ~w402, ~w417, ~w415, ~w424 } : 16'h0) |
		(w89 ? { 2'h0, ~l156, ~w418, ~w419, ~l147, ~l142, ~l141, ~l134, ~l116, ~w394, ~w385, ~w372, ~w356, ~l108, ~l109 } : 16'h0) |
		(w95 ? { 4'h0, l410[19], l409[19], l408[19], l407[19], l406[19], l405[19], l404[19], l403[19], l391[9], l390[9], l389[9], l388[9] } : 16'h0) |
		(w99 ? { 1'h0, ~w969, ~w968, ~w967, ~w966, ~w965, ~w964, ~w963, 1'h0, ~w962, ~w961, ~w960, ~w959, ~w958, ~w957, ~w956 } : 16'h0) |
		(w91 ? { 5'h0, ~w1094, ~w1093, ~w1098, ~w1092, ~w1091, ~w1099, ~w1090, ~w1089, ~w1100, ~l610, ~l612 } : 16'h0) |
		(w93 ? { ~w1149, ~w1150, ~w1151, ~w1152 } : 16'h0);*/
	
	assign CD_o = io_data;
	
	assign CD_d = vdp_data_dir;
	
	always @(posedge MCLK)
	begin
		io_data <= (io_data_pull & io_data_val) | (~io_data_pull & io_data);
		io_address[22:20] <= io_address_t[22:20];
		io_address[19:18] <= reg_sa_high[3:2];
		io_address[17:0] <= io_address_t[17:0];
	end
	
	// color bus
	
	wire [6:0] color_bus;
	
	assign color_index = color_bus[3:0];
	assign color_pal = color_bus[5:4];
	assign color_priority = color_bus[6];
	
	wire [6:0] color_bus_val =
		(l606 ? { 1'h0, reg_m5 ? reg_col_pal : 2'h1, reg_col_index } : 7'h7f) &
		(l603 ? { l560, l559, l561 } : 7'h7f) &
		(l605 ? { l321, l323, l319 } : 7'h7f) &
		(l604 ? { l274, l272, l270 } : 7'h7f);
	
	reg [6:0] color_bus_mem;
	
	assign color_bus = (l606 | l603 | l605 | l604) ? color_bus_val : color_bus_mem;
	
	always @(posedge MCLK)
	begin
		color_bus_mem <= color_bus;
	end
	
	// extra
	
	assign vdp_hclk1 = hclk1;
	
	assign vdp_intfield = w446;
	
	wire [1:0] vdp_de_1 = { t38, t29 };
	wire [1:0] vdp_de_delay_m5;
	
	ym_sr_bit_array #(.SR_LENGTH(8), .DATA_WIDTH(2)) vdp_de_delay_m5_sr(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(vdp_de_1), .data_out(vdp_de_delay_m5));
	
	wire [1:0] vdp_de_2 = reg_m5 ? vdp_de_delay_m5 : vdp_de_1;
	wire [1:0] vdp_de_3;
	
	ym_sr_bit_array #(.SR_LENGTH(7), .DATA_WIDTH(2)) vdp_de_delay_sr(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(vdp_de_2), .data_out(vdp_de_3));
	
	assign vdp_de_h = vdp_de_3[0];
	assign vdp_de_v = vdp_de_3[1];
	
	assign vdp_m5 = reg_m5;
	assign vdp_rs1 = reg_rs1;
	assign vdp_m2 = w108;
	assign vdp_lcb = reg_lcb;
	
	assign vdp_psg_clk1 = psg_hclk1;
	
	wire vdp_hsync2_delay1;
	ym_sr_bit #(.SR_LENGTH(2)) vdp_hsync2_delay1_sr(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(t33), .sr_out(vdp_hsync2_delay1));
	wire vdp_hsync2_delay2;
	ym_sr_bit #(.SR_LENGTH(7)) vdp_hsync2_delay2_sr(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(vdp_hsync2_delay1), .sr_out(vdp_hsync2_delay2));
	wire vdp_hsync2_1 = reg_m5 ? vdp_hsync2_delay2 : vdp_hsync2_delay1;
	wire vdp_hsync2_delay3;
	ym_sr_bit vdp_hsync2_delay3_sr(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .bit_in(vdp_hsync2_1), .sr_out(vdp_hsync2_delay3));
	
	assign vdp_hsync2 = vdp_hsync2_delay3;
	assign vdp_vsync2 = w373;
	
	assign w1076_dp = { color_pal, color_index };
	ym_sr_bit_array #(.DATA_WIDTH(6)) sr617_dp(.MCLK(MCLK), .c1(hclk1), .c2(hclk2), .data_in(w1076_dp), .data_out(l617_dp));
	
	always @(posedge MCLK) color_ram_out_dp <= color_ram[l617_dp];
	
	assign vdp_dma_oe_early = reg_8b_b6 ?
		(io_m1_dff2_l2 | w15 | w28 | w30 | w102) :
		(l6 | l8 | w25 | w1153);
	
	assign vdp_dma = l6 | l8;

endmodule

module ym7101_rs_trig
	(
	input MCLK,
	input set,
	input rst,
	output reg q = 1'h0,
	output reg nq = 1'h1
	);
	
	//reg mem = 1'h0;
	
	//assign q = set ? 1'h1 : (rst ? 1'h0 : mem);
	//assign nq = rst ? 1'h1 : (set ? 1'h0 : ~mem); 
	
	always @(posedge MCLK)
	begin
		q <= set ? 1'h1 : (rst ? 1'h0 : q);
		nq <= rst ? 1'h1 : (set ? 1'h0 : ~q);
	end
	
endmodule

/*module ym7101_rs_trig
	(
	input MCLK,
	input set,
	input rst,
	output q,
	output nq
	);
	
	reg mem = 1'h0;
	
	assign q = set | ~nq;
	assign nq = rst | ~q; 
	
endmodule*/


module ym7101_dff #(parameter DATA_WIDTH = 1)
	(
	input MCLK,
	input clk,
	input [DATA_WIDTH-1:0] inp,
	input rst,
	output [DATA_WIDTH-1:0] outp
	);
	
	reg [DATA_WIDTH-1:0] l1 = {DATA_WIDTH{1'h0}}, l2 = {DATA_WIDTH{1'h0}};
	
	wire [DATA_WIDTH-1:0] l2_assign = rst ? {DATA_WIDTH{1'h0}} : (clk ? l1 : l2);
	
	assign outp = l2_assign;
	//assign outp = l2;
	
	always @(posedge MCLK)
	begin
		if (rst)
		begin
			l1 <= {DATA_WIDTH{1'h0}};
		end
		else
		begin
			if (~clk)
				l1 <= inp;
		end
		l2 <= l2_assign;
	end
	
endmodule

/*module ym7101_dff #(parameter DATA_WIDTH = 1)
	(
	input MCLK,
	input clk,
	input [DATA_WIDTH-1:0] inp,
	input rst,
	output [DATA_WIDTH-1:0] outp
	);
	
	reg [DATA_WIDTH-1:0] l1 = {DATA_WIDTH{1'h0}}, l2 = {DATA_WIDTH{1'h0}};
	
	//assign outp = l2_assign;
	assign outp = l2;
	
	always @(*)
	begin
		if (rst)
		begin
			l1 <= {DATA_WIDTH{1'h0}};
			l2 <= {DATA_WIDTH{1'h0}};
		end
		else
		begin
			if (~clk)
				l1 <= inp;
			else
				l2 <= l1;
		end
	end
	
endmodule*/

/*module ym7101_dff #(parameter DATA_WIDTH = 1)
	(
	input MCLK,
	input clk,
	input [DATA_WIDTH-1:0] inp,
	input rst,
	output [DATA_WIDTH-1:0] outp
	);
	
	reg [DATA_WIDTH-1:0] l2 = {DATA_WIDTH{1'h0}};

	assign outp = l2;
	
	always @(posedge clk or posedge rst)
	begin
		if (rst)
			l2 <= {DATA_WIDTH{1'h0}};
		else
			l2 <= inp;
	end
	
endmodule*/