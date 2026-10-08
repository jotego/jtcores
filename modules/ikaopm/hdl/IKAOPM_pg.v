/* verilator lint_off WIDTHEXPAND */
module IKAOPM_pg #(parameter USE_BRAM_FOR_PHASEREG = 0) (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_05, //ch6 c2 phase piso sr parallel load
    input   wire            i_CYCLE_10,

    //register data
    input   wire    [6:0]   i_KC, //Key Code
    input   wire    [5:0]   i_KF, //Key Fraction
    input   wire    [2:0]   i_PMS, //Pulse Modulation Sensitivity
    input   wire    [1:0]   i_DT2, //Detune 2
    input   wire    [2:0]   i_DT1, //Detune 1
    input   wire    [3:0]   i_MUL,
    input   wire            i_TEST_D3, //test register

    //Vibrato
    input   wire    [7:0]   i_LFP,

    //send signals to other modules
    input   wire            i_PG_PHASE_RST, //phase reset request signal from PG
    output  wire    [4:0]   o_EG_PDELTA_SHIFT_AMOUNT, //send shift amount to EG
    output  wire    [9:0]   o_OP_PHASEDATA, //send phase data to OP
    output  wire            o_REG_PHASE_CH6_C2 //send Ch6, Carrier2 phase data to REG serially
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;



///////////////////////////////////////////////////////////
//////  Cycle 0: PMS decoding, ex-LFP conversion
////

//  DESCRIPTION
//The original chip decodes PMS value in this step(we don't need to do it)
//and does extended LFP conversion with few adders.


//
//  combinational part
//

//ex-lfp conversion
wire    [2:0]   cyc0c_ex_lfp_weight0 = (i_PMS == 3'd7) ? i_LFP[6:4]        : {1'b0, i_LFP[6:5]};
wire    [2:0]   cyc0c_ex_lfp_weight1 = (i_PMS == 3'd7) ? {2'b00, i_LFP[6]} : 3'b000;
wire            cyc0c_ex_lfp_weight2 = (i_PMS == 3'd7) ? ((i_LFP[6] & i_LFP[5]) | (i_LFP[5] & i_LFP[4])) : 
                                       (i_PMS == 3'd6) ? (i_LFP[6] & i_LFP[5]) : 1'b0;
wire    [3:0]   cyc0c_ex_lfp_weightsum = cyc0c_ex_lfp_weight0 + cyc0c_ex_lfp_weight1 + cyc0c_ex_lfp_weight2;


//
//  register part
//

reg     [2:0]   cyc0r_pms_level;
reg     [7:0]   cyc0r_ex_lfp;
reg             cyc0r_ex_lfp_sign;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc0r_pms_level <= i_PMS;

    if(i_PMS == 3'd7) cyc0r_ex_lfp <= {cyc0c_ex_lfp_weightsum,      i_LFP[3:0]};
    else              cyc0r_ex_lfp <= {cyc0c_ex_lfp_weightsum[2:0], i_LFP[4:0]};

    //lfp_sign becomes 1 when PMS > 0 and LFP sign is negative to convert lfp_ex to 2's complement
    cyc0r_ex_lfp_sign <= (i_PMS > 3'd0) & i_LFP[7];
end



///////////////////////////////////////////////////////////
//////  Cycle 1: Pitch value calculation
////

//  DESCRIPTION
//The original chip decodes PMS value in this step(we don't need to do it)
//and does extended LFP conversion with few adders.


//
//  combinational part
//

reg     [12:0]  cyc1c_lfp_deviance;
always @(*) begin
    case(cyc0r_pms_level)
        3'd0: cyc1c_lfp_deviance = 13'b0;
        3'd1: cyc1c_lfp_deviance = {11'b0, cyc0r_ex_lfp[6:5]      };
        3'd2: cyc1c_lfp_deviance = {10'b0, cyc0r_ex_lfp[6:4]      };
        3'd3: cyc1c_lfp_deviance = {9'b0,  cyc0r_ex_lfp[6:3]      };
        3'd4: cyc1c_lfp_deviance = {8'b0,  cyc0r_ex_lfp[6:2]      };
        3'd5: cyc1c_lfp_deviance = {7'b0,  cyc0r_ex_lfp[6:1]      };
        3'd6: cyc1c_lfp_deviance = {4'b0,  cyc0r_ex_lfp[7:0], 1'b0};
        3'd7: cyc1c_lfp_deviance = {3'b0,  cyc0r_ex_lfp[7:0], 2'b0};
    endcase
end

wire    [6:0]   cyc1c_frac_adder      = i_KF      + (cyc1c_lfp_deviance[5:0]  ^ {6{cyc0r_ex_lfp_sign}}) + cyc0r_ex_lfp_sign; 
wire    [7:0]   cyc1c_int_adder       = i_KC      + (cyc1c_lfp_deviance[12:6] ^ {7{cyc0r_ex_lfp_sign}}) + cyc1c_frac_adder[6];
wire    [2:0]   cyc1c_notegroup_adder = i_KC[1:0] + (cyc1c_lfp_deviance[7:6]  ^ {2{cyc0r_ex_lfp_sign}}) + cyc1c_frac_adder[6];
//wire    [12:0]  cyc1c_modded_raw_pitchval = (cyc0r_ex_lfp_sign == 1'b0) ? {i_KC, i_KF} + cyc1c_lfp_deviance : {i_KC, i_KF} + ~cyc1c_lfp_deviance + 13'd1;


//
//  register part
//

reg     [12:0]  cyc1r_modded_pitchval; //add or subtract LFP value from KC, KF
reg             cyc1r_modded_pitchval_ovfl;
reg             cyc1r_notegroup_nopitchmod; //this flag set when no "LFP" addend is given to a "note group" range(note group: 012/456/89A/CDE)
reg             cyc1r_notegroup_ovfl; //note group overflow, e.g. 6(3'b1_10) + 2(3'b0_10)
reg             cyc1r_lfp_sign;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc1r_modded_pitchval      <= {cyc1c_int_adder[6:0], cyc1c_frac_adder[5:0]};

    cyc1r_modded_pitchval_ovfl <= cyc1c_int_adder[7];
    cyc1r_notegroup_nopitchmod <= (cyc1c_lfp_deviance[7:6] ^ {2{cyc0r_ex_lfp_sign}}) == 2'b00;
    cyc1r_notegroup_ovfl <= cyc1c_notegroup_adder[2];

    //bypass
    cyc1r_lfp_sign <= cyc0r_ex_lfp_sign; 
end



///////////////////////////////////////////////////////////
//////  Cycle 2: Notegroup rearrange
////

//  DESCRIPTION
//The pitch value modulated by the LFP value can cause notegroup violation.
//Modify the integer part of this pitch value if it is out of the note group range.
//Notegroup (note group: 012/456/89A/CDE)

//
//  combinational part
//

//wire            cyc2c_int_adder_add1 = ((cyc1r_modded_pitchval[7:6] == 2'd3) | cyc1r_notegroup_ovfl) & ~cyc1r_lfp_sign;
//wire            cyc2c_int_adder_sub1 = ~(cyc1r_notegroup_nopitchmod | cyc1r_notegroup_ovfl | ~cyc1r_lfp_sign);
//wire    [7:0]   cyc2c_int_adder = cyc1r_modded_pitchval[12:6] + {7{cyc2c_int_adder_sub1}} + cyc2c_int_adder_add1;

reg     [7:0]   cyc2c_int_adder;
always @(*) begin
    case({(cyc1r_modded_pitchval[7:6] == 2'd3), cyc1r_notegroup_nopitchmod, cyc1r_notegroup_ovfl, cyc1r_lfp_sign})
        //valid notegroup value
        4'b0_0_0_0: cyc2c_int_adder = cyc1r_modded_pitchval[12:6]        ; //
        4'b0_0_0_1: cyc2c_int_adder = cyc1r_modded_pitchval[12:6] + 7'h7F; //
        4'b0_0_1_0: cyc2c_int_adder = cyc1r_modded_pitchval[12:6] + 7'h01; //
        4'b0_0_1_1: cyc2c_int_adder = cyc1r_modded_pitchval[12:6]        ; //

        4'b0_1_0_0: cyc2c_int_adder = cyc1r_modded_pitchval[12:6]        ; //
        4'b0_1_0_1: cyc2c_int_adder = cyc1r_modded_pitchval[12:6]        ; //
        4'b0_1_1_0: cyc2c_int_adder = cyc1r_modded_pitchval[12:6] + 7'h01; //
        4'b0_1_1_1: cyc2c_int_adder = cyc1r_modded_pitchval[12:6]        ; //

        //invalid notegroup value
        4'b1_0_0_0: cyc2c_int_adder = cyc1r_modded_pitchval[12:6] + 7'h01; //
        4'b1_0_0_1: cyc2c_int_adder = cyc1r_modded_pitchval[12:6] + 7'h7F; //
        4'b1_0_1_0: cyc2c_int_adder = cyc1r_modded_pitchval[12:6] + 7'h01; //
        4'b1_0_1_1: cyc2c_int_adder = cyc1r_modded_pitchval[12:6]        ; //

        4'b1_1_0_0: cyc2c_int_adder = cyc1r_modded_pitchval[12:6] + 7'h01; //
        4'b1_1_0_1: cyc2c_int_adder = cyc1r_modded_pitchval[12:6]        ; //
        4'b1_1_1_0: cyc2c_int_adder = cyc1r_modded_pitchval[12:6] + 7'h01; //
        4'b1_1_1_1: cyc2c_int_adder = cyc1r_modded_pitchval[12:6]        ; //
    endcase
end


//
//  register part
//

reg     [12:0]  cyc2r_rearranged_pitchval;
reg             cyc2r_rearranged_pitchval_ovfl;
reg             cyc2r_modded_pitchval_ovfl;
reg             cyc2r_int_sub1;
reg             cyc2r_lfp_sign;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc2r_rearranged_pitchval <= {cyc2c_int_adder[6:0], cyc1r_modded_pitchval[5:0]};
    cyc2r_rearranged_pitchval_ovfl <= cyc2c_int_adder[7];

    cyc2r_int_sub1 <= ~(cyc1r_notegroup_nopitchmod | cyc1r_notegroup_ovfl | ~cyc1r_lfp_sign);

    cyc2r_modded_pitchval_ovfl <= cyc1r_modded_pitchval_ovfl;
    cyc2r_lfp_sign <= cyc1r_lfp_sign;
end

`ifdef IKAOPM_DEBUG
wire    [13:0]  debug_cyc1c_lfp_deviance = (cyc0r_ex_lfp_sign == 1'b1) ? (~cyc1c_lfp_deviance + 7'h1) : cyc1c_lfp_deviance;
wire            debug_cyc1r_notrgroup_violation = cyc1r_modded_pitchval[7:6] == 2'd3;
wire            debug_cyc2r_notrgroup_violation = cyc2r_rearranged_pitchval[7:6] == 2'd3;
`endif


///////////////////////////////////////////////////////////
//////  Cycle 3: Overflow control
////

//  DESCRIPTION
//Controls the rearranged pitch values to be saturated.

//
//  register part
//

reg     [12:0]  cyc3r_saturated_pitchval;
reg     [1:0]   cyc3r_dt2; //just delays, the original chip decodes DT2 input here, we don't have to do.

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    casez({cyc2r_lfp_sign, cyc2r_modded_pitchval_ovfl, cyc2r_int_sub1, cyc2r_rearranged_pitchval_ovfl})
        //lfp = positive
        4'b0000: cyc3r_saturated_pitchval <= cyc2r_rearranged_pitchval;
        4'b00?1: cyc3r_saturated_pitchval <= 13'b111_1110_111111; //max
        4'b01?0: cyc3r_saturated_pitchval <= 13'b111_1110_111111;
        4'b01?1: cyc3r_saturated_pitchval <= 13'b111_1110_111111;
        4'b0010: cyc3r_saturated_pitchval <= 13'b000_0000_000000; //will never happen

        //lfp = negative
        4'b1000: cyc3r_saturated_pitchval <= 13'b000_0000_000000; //min
        4'b1001: cyc3r_saturated_pitchval <= 13'b000_0000_000000;
        4'b1010: cyc3r_saturated_pitchval <= 13'b000_0000_000000;
        4'b1011: cyc3r_saturated_pitchval <= 13'b000_0000_000000;
        4'b1100: cyc3r_saturated_pitchval <= cyc2r_rearranged_pitchval;
        4'b1101: cyc3r_saturated_pitchval <= cyc2r_rearranged_pitchval;
        4'b1110: cyc3r_saturated_pitchval <= 13'b000_0000_000000;
        4'b1111: cyc3r_saturated_pitchval <= cyc2r_rearranged_pitchval;
    endcase

    cyc3r_dt2 <= i_DT2;
end



///////////////////////////////////////////////////////////
//////  Cycle 4: apply DT2 to fractional part
////

//  DESCRIPTION
//Apply DT2 to fractional part of the pitch value
//fixed point, fractional part is 6 bits. 0.015625 step value

//
//  register part
//

reg     [6:0]   cyc4r_frac_detuned_pitchval; //carry + 6bit value
reg     [6:0]   cyc4r_int_pitchval;
reg     [1:0]   cyc4r_dt2;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    case(cyc3r_dt2)
        2'd0: cyc4r_frac_detuned_pitchval <= cyc3r_saturated_pitchval[5:0] + 6'd0  + 1'd0;
        2'd1: cyc4r_frac_detuned_pitchval <= cyc3r_saturated_pitchval[5:0] + 6'd0  + 1'd0;
        2'd2: cyc4r_frac_detuned_pitchval <= cyc3r_saturated_pitchval[5:0] + 6'd52 + 1'd0; //fractional part +0.8125
        2'd3: cyc4r_frac_detuned_pitchval <= cyc3r_saturated_pitchval[5:0] + 6'd32 + 1'd0; //fractional part +0.5
    endcase

    cyc4r_int_pitchval <= cyc3r_saturated_pitchval[12:6];

    cyc4r_dt2 <= cyc3r_dt2;
end



///////////////////////////////////////////////////////////
//////  Cycle 5: apply DT2 to integer part
////

//  DESCRIPTION
//Apply DT2 to integer part of the pitch value

//
//  register part
//

reg     [5:0]   cyc5r_frac_detuned_pitchval; //no carry here
reg     [7:0]   cyc5r_int_detuned_pitchval; //carry + 7bit value

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    casez({cyc4r_dt2, cyc4r_frac_detuned_pitchval[6], cyc4r_int_pitchval[1:0]})
        //dt2 = 0
        5'b00_0_00: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd0;
        5'b00_0_01: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd0;
        5'b00_0_10: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd0;
        5'b00_0_11: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd0;
        5'b00_1_00: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd0 + 7'd1;
        5'b00_1_01: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd0 + 7'd1;
        5'b00_1_10: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd0 + 7'd2;
        5'b00_1_11: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd0 + 7'd2;
        //                                        |---base value---| +  dt2 + carry(avoids notegroup violation)

        //dt2 = 1
        5'b01_0_00: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd8;
        5'b01_0_01: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd8;
        5'b01_0_10: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd8;
        5'b01_0_11: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd8;
        5'b01_1_00: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd8 + 7'd1;
        5'b01_1_01: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd8 + 7'd1;
        5'b01_1_10: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd8 + 7'd2;
        5'b01_1_11: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd8 + 7'd2;

        //dt2 = 2
        5'b10_0_00: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd9;
        5'b10_0_01: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd9;
        5'b10_0_10: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd9 + 7'd1;
        5'b10_0_11: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd9 + 7'd1;
        5'b10_1_00: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd9 + 7'd1;
        5'b10_1_01: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd9 + 7'd2;
        5'b10_1_10: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd9 + 7'd2;
        5'b10_1_11: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd9 + 7'd2;

        //dt2 = 3
        5'b11_0_00: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd12;
        5'b11_0_01: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd12;
        5'b11_0_10: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd12;
        5'b11_0_11: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd12;
        5'b11_1_00: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd12 + 7'd1;
        5'b11_1_01: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd12 + 7'd1;
        5'b11_1_10: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd12 + 7'd2;
        5'b11_1_11: cyc5r_int_detuned_pitchval <= cyc4r_int_pitchval + 7'd12 + 7'd2;
    endcase

    cyc5r_frac_detuned_pitchval <= cyc4r_frac_detuned_pitchval[5:0]; //discard carry
end



///////////////////////////////////////////////////////////
//////  Cycle 6: Overflow control, Keycode to F-num 1
////


//  DESCRIPTION
//Controls the final pitch values to be saturated.

//
//  combinational part
//

wire   [12:0]  cyc6c_final_pitchval = (cyc5r_int_detuned_pitchval[7] == 1'b1) ? 13'b111_1110_111111 : {cyc5r_int_detuned_pitchval[6:0], cyc5r_frac_detuned_pitchval};

//  DESCRIPTION
//This ROM has absolute phase increment value(pdelta) and 
//fine tuning value for small phase changes. Now we get the values
//from the conversion table.

//
//  register part
//

reg     [4:0]   cyc6r_pdelta_shift_amount;
wire    [11:0]  cyc6r_pdelta_base;
wire    [3:0]   cyc6r_pdelta_increment_multiplicand;
reg     [3:0]   cyc6r_pdelta_increment_multiplier;
wire            cyc6r_pdelta_calcmode;

pg_submdl_fnumrom u_cyc6r_fnumrom (
    .i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_ADDR(cyc6c_final_pitchval[9:4]),
    .o_DATA({cyc6r_pdelta_base, cyc6r_pdelta_increment_multiplicand[0], cyc6r_pdelta_increment_multiplicand[3:1], cyc6r_pdelta_calcmode})
    //The original chip's output bit order is scrambled!
);

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc6r_pdelta_shift_amount <= cyc6c_final_pitchval[12:8];
    cyc6r_pdelta_increment_multiplier <= cyc6c_final_pitchval[3:0];
end



///////////////////////////////////////////////////////////
//////  Cycle 7: Keycode to F-num 2
////

//  DESCRIPTION
//Now we have to generate the value to adjust the pdelta base value.
//YM2151 decompresses the ROM output we got in the previous step.
//
//in calcmode == 0, we can write the weird expression like this:
//if(multiply[3:2] == 2'b11) and (increment[0] == 1'b0), then +4
//if(multiply[3] == 1'b1), then +1
//if(multiply[1] == 1'b1), then +8
//if(multuply[0] == 1'b1), then +2

//
//  register part
//

reg     [4:0]   cyc7r_pdelta_shift_amount;
reg     [11:0]  cyc7r_pdelta_base;
reg     [6:0]   cyc7r_multiplied_increment;
assign  o_EG_PDELTA_SHIFT_AMOUNT = cyc7r_pdelta_shift_amount;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc7r_pdelta_shift_amount <= cyc6r_pdelta_shift_amount;
    cyc7r_pdelta_base <= cyc6r_pdelta_base;

    if(cyc6r_pdelta_calcmode) begin
        cyc7r_multiplied_increment <= ({{1'b1, cyc6r_pdelta_increment_multiplicand} >> 0} & {5{cyc6r_pdelta_increment_multiplier[3]}}) +
                                        ({{1'b1, cyc6r_pdelta_increment_multiplicand} >> 1} & {5{cyc6r_pdelta_increment_multiplier[2]}}) +
                                        ({{1'b1, cyc6r_pdelta_increment_multiplicand} >> 2} & {5{cyc6r_pdelta_increment_multiplier[1]}}) +
                                        ({{1'b1, cyc6r_pdelta_increment_multiplicand} >> 3} & {5{cyc6r_pdelta_increment_multiplier[0]}});
    end
    else begin
        cyc7r_multiplied_increment <= ({{1'b1, cyc6r_pdelta_increment_multiplicand[3:1], 1'b1} >> 0} & {5{cyc6r_pdelta_increment_multiplier[3]}}) +
                                        ({{1'b1, cyc6r_pdelta_increment_multiplicand[3:1], 1'b1} >> 1} & {5{cyc6r_pdelta_increment_multiplier[2]}}) +
                                        ({{1'b1, cyc6r_pdelta_increment_multiplicand[3:1], 1'b1} >> 3} & {5{cyc6r_pdelta_increment_multiplier[0]}}) +

                                        (5'd4 & {5{&{cyc6r_pdelta_increment_multiplier[3:2], ~cyc6r_pdelta_increment_multiplicand[0]}}}) + 
                                        (5'd1 & {5{cyc6r_pdelta_increment_multiplier[3]}}) + 
                                        (5'd8 & {5{cyc6r_pdelta_increment_multiplier[1]}}) + 
                                        (5'd2 & {5{cyc6r_pdelta_increment_multiplier[0]}});
    end
end



///////////////////////////////////////////////////////////
//////  Cycle 8: Keycode to F-num 3, DT1/MUL latch
////

//  DESCRIPTION
//This is the third step of F-num conversion.
//Discard the LSB of "cyc7r_multiplied_increment" first.
//Add them to the base next.

//
//  register part
//

reg     [4:0]   cyc8r_pdelta_shift_amount;
reg     [11:0]  cyc8r_pdelta_base;
reg     [2:0]   cyc8r_dt1;
reg     [3:0]   cyc8r_mul;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc8r_pdelta_shift_amount <= cyc7r_pdelta_shift_amount;
    cyc8r_pdelta_base <= cyc7r_pdelta_base + {6'b0, cyc7r_multiplied_increment[6:1]};
    cyc8r_dt1 <= i_DT1;
    cyc8r_mul <= i_MUL;
end



///////////////////////////////////////////////////////////
//////  Cycle 9: Keycode to F-num 4, DT1 decode
////

//  DESCRIPTION
//This is the last step of F-num conversion. Shift the pdelta
//value using the shift amount[4:3].
//Calculate the intensity of detuning amount. Decode the base
//detuning value from DT1 parameter.

//
//  combinational part
//

//intensity shifts the base value
reg     [4:0]   cyc9c_dt1_intensity; //possible intensity value: from 1 to 19
always @(*) begin
    case(cyc8r_dt1[1:0])
        2'd0: cyc9c_dt1_intensity = {1'b0, cyc8r_pdelta_shift_amount[4:2]} + 4'd0  + 1'd1; //always +1, confirmed 2023-07-06
        2'd1: cyc9c_dt1_intensity = {1'b0, cyc8r_pdelta_shift_amount[4:2]} + 4'd8  + 1'd1;
        2'd2: cyc9c_dt1_intensity = {1'b0, cyc8r_pdelta_shift_amount[4:2]} + 4'd10 + 1'd1;
        2'd3: cyc9c_dt1_intensity = {1'b0, cyc8r_pdelta_shift_amount[4:2]} + 4'd11 + 1'd1;
    endcase
end

//generate the base value(PLA), confirmed 2023-07-06
wire    [1:0]   cyc9c_dt1_base_sel = (cyc8r_pdelta_shift_amount >= 5'd28) ? 2'd0 : cyc8r_pdelta_shift_amount[1:0]; //confirmed 2023-07-06
reg     [4:0]   cyc9c_dt1_base;
always @(*) begin
    case({cyc9c_dt1_intensity[0], cyc9c_dt1_base_sel})
        //dt1 intensity is even
        3'b0_00: cyc9c_dt1_base = 5'b10000; //1, 0
        3'b0_01: cyc9c_dt1_base = 5'b10001; //1, 1
        3'b0_10: cyc9c_dt1_base = 5'b10011; //1, 3
        3'b0_11: cyc9c_dt1_base = 5'b10100; //1, 4

        //dt1 intensity is odd
        3'b1_00: cyc9c_dt1_base = 5'b10110; //1, 6
        3'b1_01: cyc9c_dt1_base = 5'b11000; //1, 8
        3'b1_10: cyc9c_dt1_base = 5'b11011; //1, 11
        3'b1_11: cyc9c_dt1_base = 5'b11101; //1, 13
    endcase
end

//
//  register part
//

wire    [19:0]  cyc40r_phase_sr_out; //get previous phase from the cycle 40, SR last step(21)
reg     [19:0]  cyc9r_previous_phase;
reg     [16:0]  cyc9r_shifted_pdelta;
reg     [16:0]  cyc9r_pdelta_detuning_value;
reg     [3:0]   cyc9r_mul;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    case(cyc8r_pdelta_shift_amount[4:2])
        3'd0: cyc9r_shifted_pdelta <= {7'b0000000, cyc8r_pdelta_base[11:2]}; //>>4
        3'd1: cyc9r_shifted_pdelta <= {6'b000000, cyc8r_pdelta_base[11:1] }; //>>3
        3'd2: cyc9r_shifted_pdelta <= {5'b00000, cyc8r_pdelta_base        }; //>>2
        3'd3: cyc9r_shifted_pdelta <= {4'b0000, cyc8r_pdelta_base, 1'b0   }; //>>1
        3'd4: cyc9r_shifted_pdelta <= {3'b000, cyc8r_pdelta_base, 2'b00   }; //zero
        3'd5: cyc9r_shifted_pdelta <= {2'b00, cyc8r_pdelta_base, 3'b000   }; //<<1
        3'd6: cyc9r_shifted_pdelta <= {1'b0, cyc8r_pdelta_base, 4'b0000   }; //<<2
        3'd7: cyc9r_shifted_pdelta <= {     cyc8r_pdelta_base, 5'b00000   }; //<<3
    endcase

    case(cyc9c_dt1_intensity[4:1])
        //                                                      DT1 is ? |-------- positive --------|   |------------- negative -----------|  intensity
        4'b0101: cyc9r_pdelta_detuning_value <= (cyc8r_dt1[2] == 1'b0) ? {16'd0, cyc9c_dt1_base[4]}   : ~{16'd0, cyc9c_dt1_base[4]}   + 1'd1; //10, 11
        4'b0110: cyc9r_pdelta_detuning_value <= (cyc8r_dt1[2] == 1'b0) ? {15'd0, cyc9c_dt1_base[4:3]} : ~{15'd0, cyc9c_dt1_base[4:3]} + 1'd1; //12, 13
        4'b0111: cyc9r_pdelta_detuning_value <= (cyc8r_dt1[2] == 1'b0) ? {14'd0, cyc9c_dt1_base[4:2]} : ~{14'd0, cyc9c_dt1_base[4:2]} + 1'd1; //14, 15
        4'b1000: cyc9r_pdelta_detuning_value <= (cyc8r_dt1[2] == 1'b0) ? {13'd0, cyc9c_dt1_base[4:1]} : ~{13'd0, cyc9c_dt1_base[4:1]} + 1'd1; //16, 17
        4'b1001: cyc9r_pdelta_detuning_value <= (cyc8r_dt1[2] == 1'b0) ? {12'd0, cyc9c_dt1_base}      : ~{12'd0, cyc9c_dt1_base}      + 1'd1; //18, 19

        default: cyc9r_pdelta_detuning_value <= 17'd0;                                                                                    //1 to 9
    endcase

    cyc9r_mul <= cyc8r_mul;
    cyc9r_previous_phase <= mrst_n ? cyc40r_phase_sr_out : 20'd0; //force reset added
end



///////////////////////////////////////////////////////////
//////  Cycle 10: apply DT1
////

//  DESCRIPTION
//Sum shifted pdelta and detuning value.
//YM2151 adds low bits in this step, but we don't have to do it. 
//Add everything within one cycle.

//
//  register part
//

reg     [19:0]  cyc10r_previous_phase;
reg     [16:0]  cyc10r_detuned_pdelta; //ignore carry
reg     [3:0]   cyc10r_mul;
reg             cyc10r_phase_rst;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc10r_detuned_pdelta <= cyc9r_shifted_pdelta + cyc9r_pdelta_detuning_value;
    cyc10r_mul <= cyc9r_mul;
    cyc10r_previous_phase <= cyc9r_previous_phase;
    cyc10r_phase_rst <= i_PG_PHASE_RST;
end



///////////////////////////////////////////////////////////
//////  Cycle 11: delay
////

//  DESCRIPTION
//YM2151 adds high bits in this step.
//Just latch multiplier. The original chip decodes mul value
//here to feed some control signal for booth multiplier.

//
//  register part
//

reg     [19:0]  cyc11r_previous_phase;
reg     [16:0]  cyc11r_detuned_pdelta;
reg     [3:0]   cyc11r_mul;
reg             cyc11r_phase_rst;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc11r_detuned_pdelta <= cyc10r_detuned_pdelta;
    cyc11r_mul <= cyc10r_mul;
    cyc11r_previous_phase <= cyc10r_previous_phase;
    cyc11r_phase_rst <= cyc10r_phase_rst;
end



///////////////////////////////////////////////////////////
//////  Cycle 12: apply mul
////

//
//  register part
//

reg     [19:0]  cyc12r_previous_phase;
reg     [19:0]  cyc12r_multiplied_pdelta; //131071*15 = 1_1101_1111_1111_1111_0001, max 21 bits, but discard MSB anyway
reg             cyc12r_phase_rst;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(cyc11r_mul == 4'b0) cyc12r_multiplied_pdelta <= {4'b0000, cyc11r_detuned_pdelta[16:1]}; // divide by 2
    else begin
        cyc12r_multiplied_pdelta <= cyc11r_detuned_pdelta * cyc11r_mul;
    end

    cyc12r_previous_phase <= cyc11r_previous_phase;
    cyc12r_phase_rst <= cyc11r_phase_rst;
end



///////////////////////////////////////////////////////////
//////  Cycle 13: delay
////

//
//  register part
//

reg     [19:0]  cyc13r_previous_phase;
reg     [19:0]  cyc13r_multiplied_pdelta; //ignore carry
reg             cyc13r_phase_rst;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc13r_multiplied_pdelta <= cyc12r_multiplied_pdelta[19:0];
    cyc13r_previous_phase <= cyc12r_previous_phase;
    cyc13r_phase_rst <= cyc12r_phase_rst;
end



///////////////////////////////////////////////////////////
//////  Cycle 14: reset phase
////

//
//  register part
//

reg     [19:0]  cyc14r_previous_phase;
reg     [19:0]  cyc14r_final_pdelta; 
reg             cyc14r_phase_rst;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc14r_final_pdelta <= (cyc13r_phase_rst) ? 20'd0 : cyc13r_multiplied_pdelta;
    cyc14r_previous_phase <= cyc13r_previous_phase;
    cyc14r_phase_rst <= cyc13r_phase_rst;
end



///////////////////////////////////////////////////////////
//////  Cycle 15: delay
////

//
//  register part
//

reg     [19:0]  cyc15r_previous_phase;
reg     [19:0]  cyc15r_final_pdelta; 
reg             cyc15r_phase_rst;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc15r_final_pdelta <= cyc14r_final_pdelta;
    cyc15r_previous_phase <= cyc14r_previous_phase;
    cyc15r_phase_rst <= cyc14r_phase_rst;
end



///////////////////////////////////////////////////////////
//////  Cycle 16: delay, reset previous phase
////

//
//  register part
//

reg     [19:0]  cyc16r_final_pdelta; 
reg     [19:0]  cyc16r_previous_phase;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc16r_final_pdelta <= cyc15r_final_pdelta;
    cyc16r_previous_phase <= (cyc15r_phase_rst | i_TEST_D3) ? 20'd0 : cyc15r_previous_phase;
end



///////////////////////////////////////////////////////////
//////  Cycle 17: sum previous phase and pdelta
////

//  DESCRIPTION
//YM2151 adds low bits in this step. We will sum entire bits.

//
//  register part
//

reg     [19:0]  cyc17r_current_phase; //ignore carry
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc17r_current_phase <= cyc16r_previous_phase + cyc16r_final_pdelta;
end



///////////////////////////////////////////////////////////
//////  Cycle 18: delay 
////

//  DESCRIPTION
//YM2151 adds high bits in this step.

//
//  register part
//

reg     [19:0]  cyc18r_current_phase;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc18r_current_phase <= mrst_n ? cyc17r_current_phase : 20'd0; //force reset added
end



///////////////////////////////////////////////////////////
//////  Cycle 19-40: delay shift register 
////

//  DESCRIPTION
//10-bit processing chain above and 22-bit length shift register 
//will store all 32 phases.

//
//  register part
//

generate
if(USE_BRAM_FOR_PHASEREG == 0) begin: phasesr_mode_sr
    primitive_sr #(.WIDTH(20), .LENGTH(22), .TAP(22)) u_cyc19r_cyc40r_phase_sr
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(cyc18r_current_phase), .o_Q_TAP(), .o_Q_LAST(cyc40r_phase_sr_out));
end
else begin: phasesr_mode_bram
    primitive_sr_bram #(.WIDTH(20), .LENGTH(32), .TAP(22)) u_cyc19r_cyc40r_phase_sr
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(i_CYCLE_10 | ~mrst_n), .i_WR(1'b1), .i_D(cyc18r_current_phase), .o_Q_TAP(cyc40r_phase_sr_out));
end
endgenerate

//last stage
assign  o_OP_PHASEDATA = cyc40r_phase_sr_out[19:10];



///////////////////////////////////////////////////////////
//////  Phase serialization(send to test reg)
////

reg     [8:0]   phase_ch6_c2;
assign  o_REG_PHASE_CH6_C2 = phase_ch6_c2[0];
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(i_CYCLE_05) phase_ch6_c2 <= cyc15r_previous_phase[8:0];
    else begin 
        phase_ch6_c2[7:0] <= phase_ch6_c2[8:1];
        phase_ch6_c2[8] <= 1'b0;
    end
end



///////////////////////////////////////////////////////////
//////  STATIC STORAGE FOR DEBUG
////

`ifdef IKAOPM_DEBUG

reg     [4:0]   sim_pg_static_storage_addr_cntr = 5'd0;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(i_CYCLE_10) sim_pg_static_storage_addr_cntr <= 5'd0;
    else sim_pg_static_storage_addr_cntr <= sim_pg_static_storage_addr_cntr == 5'd31 ? 5'd0 : sim_pg_static_storage_addr_cntr + 5'd1;
end

reg     [19:0]  sim_pg_static_storage[0:31];
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    sim_pg_static_storage[sim_pg_static_storage_addr_cntr] <= mrst_n ? cyc18r_current_phase : 20'd0;
end

`endif


endmodule


module pg_submdl_fnumrom (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //clock enable
    input   wire            i_CEN_n, //positive edge clock enable for emulation

    input   wire    [5:0]   i_ADDR,
    output  reg     [16:0]  o_DATA
);

always @(posedge i_EMUCLK) if(!i_CEN_n) begin
    case(i_ADDR)
        6'h00: o_DATA <= 17'b010100_010011_1001_1;
        6'h01: o_DATA <= 17'b010100_100110_1001_1;
        6'h02: o_DATA <= 17'b010100_111001_1001_1;
        6'h03: o_DATA <= 17'b010101_001100_0010_1;
        6'h04: o_DATA <= 17'b010101_100000_0010_1;
        6'h05: o_DATA <= 17'b010101_110100_0010_1;
        6'h06: o_DATA <= 17'b010110_001000_1010_1;
        6'h07: o_DATA <= 17'b010110_011101_0010_1;
        6'h08: o_DATA <= 17'b010110_110010_1010_1;
        6'h09: o_DATA <= 17'b010111_000111_1010_1;
        6'h0A: o_DATA <= 17'b010111_011101_0011_1;
        6'h0B: o_DATA <= 17'b010111_110011_0011_1;
        6'h0C: o_DATA <= 17'b000000_000000_0000_0;
        6'h0D: o_DATA <= 17'b000000_000000_0000_0;
        6'h0E: o_DATA <= 17'b000000_000000_0000_0;
        6'h0F: o_DATA <= 17'b000000_000000_0000_0;

        6'h10: o_DATA <= 17'b011000_001001_0011_1;
        6'h11: o_DATA <= 17'b011000_011111_0011_1;
        6'h12: o_DATA <= 17'b011000_110110_1011_1;
        6'h13: o_DATA <= 17'b011001_001101_1011_1;
        6'h14: o_DATA <= 17'b011001_100101_1011_1;
        6'h15: o_DATA <= 17'b011001_111100_0100_1;
        6'h16: o_DATA <= 17'b011010_010101_0100_1;
        6'h17: o_DATA <= 17'b011010_101101_0100_1;
        6'h18: o_DATA <= 17'b011011_000110_1100_1;
        6'h19: o_DATA <= 17'b011011_011111_1100_1;
        6'h1A: o_DATA <= 17'b011011_111001_0101_1;
        6'h1B: o_DATA <= 17'b011100_010011_0101_1;
        6'h1C: o_DATA <= 17'b000000_000000_0000_0;
        6'h1D: o_DATA <= 17'b000000_000000_0000_0;
        6'h1E: o_DATA <= 17'b000000_000000_0000_0;
        6'h1F: o_DATA <= 17'b000000_000000_0000_0;

        6'h20: o_DATA <= 17'b011100_101101_0101_1;
        6'h21: o_DATA <= 17'b011101_001000_1101_1;
        6'h22: o_DATA <= 17'b011101_100011_1101_1;
        6'h23: o_DATA <= 17'b011101_111110_0110_1;
        6'h24: o_DATA <= 17'b011110_011010_0110_1;
        6'h25: o_DATA <= 17'b011110_110111_0110_1;
        6'h26: o_DATA <= 17'b011111_010011_1110_1;
        6'h27: o_DATA <= 17'b011111_110000_0111_1;
        6'h28: o_DATA <= 17'b100000_001110_0111_1;
        6'h29: o_DATA <= 17'b100000_101100_0111_1;
        6'h2A: o_DATA <= 17'b100001_001010_1111_1;
        6'h2B: o_DATA <= 17'b100001_101001_1111_1;
        6'h2C: o_DATA <= 17'b000000_000000_0000_0;
        6'h2D: o_DATA <= 17'b000000_000000_0000_0;
        6'h2E: o_DATA <= 17'b000000_000000_0000_0;
        6'h2F: o_DATA <= 17'b000000_000000_0000_0;

        6'h30: o_DATA <= 17'b100010_001001_1111_1;
        6'h31: o_DATA <= 17'b100010_101000_1111_0;
        6'h32: o_DATA <= 17'b100011_001001_1111_0;
        6'h33: o_DATA <= 17'b100011_101001_1111_0;
        6'h34: o_DATA <= 17'b100100_001011_1111_0;
        6'h35: o_DATA <= 17'b100100_101100_1111_0;
        6'h36: o_DATA <= 17'b100101_001110_0111_0;
        6'h37: o_DATA <= 17'b100101_110001_0111_0;
        6'h38: o_DATA <= 17'b100110_010100_0111_0;
        6'h39: o_DATA <= 17'b100110_111000_0111_0;
        6'h3A: o_DATA <= 17'b100111_011100_0111_0;
        6'h3B: o_DATA <= 17'b101000_000001_0111_0;
        6'h3C: o_DATA <= 17'b000000_000000_0000_0;
        6'h3D: o_DATA <= 17'b000000_000000_0000_0;
        6'h3E: o_DATA <= 17'b000000_000000_0000_0;
        6'h3F: o_DATA <= 17'b000000_000000_0000_0;
    endcase
end

endmodule
