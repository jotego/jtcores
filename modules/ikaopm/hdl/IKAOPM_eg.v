/* verilator lint_off WIDTHEXPAND */
module IKAOPM_eg (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_03,
    input   wire            i_CYCLE_31,
    input   wire            i_CYCLE_00_16,
    input   wire            i_CYCLE_01_TO_16,

    //register data
    input   wire            i_KON, //key on
    input   wire    [1:0]   i_KS,  //key scale
    input   wire    [4:0]   i_AR,  //attack rate
    input   wire    [4:0]   i_D1R, //first decay rate
    input   wire    [4:0]   i_D2R, //second decay rate
    input   wire    [3:0]   i_RR,  //release rate
    input   wire    [3:0]   i_D1L, //first decay level
    input   wire    [6:0]   i_TL,  //total level
    input   wire    [1:0]   i_AMS, //amplitude modulation sensitivity
    input   wire    [7:0]   i_LFA, //amplitude modulation from LFO
    input   wire            i_TEST_D0, //test register
    input   wire            i_TEST_D5,

    //input data
    input   wire    [4:0]   i_EG_PDELTA_SHIFT_AMOUNT,

    //output data
    output  wire            o_PG_PHASE_RST,
    output  wire    [9:0]   o_OP_ATTENLEVEL, //envelope level
    output  wire            o_NOISE_ATTENLEVEL, //envelope level(for noise module)
    output  wire            o_REG_ATTENLEVEL_CH8_C2 //noise envelope level
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;



///////////////////////////////////////////////////////////
//////  Cycle number
////

//additional cycle bits
reg             cycle_01_17;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cycle_01_17 <= i_CYCLE_00_16;
end



///////////////////////////////////////////////////////////
//////  Third sample flag
////

reg             samplecntr_rst;
wire    [1:0]   samplecntr_q;
reg             third_sample;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    samplecntr_rst <= samplecntr_q[1];

    third_sample <= samplecntr_q[1] | i_TEST_D0;
end

primitive_counter #(.WIDTH(2)) u_samplecntr (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(i_CYCLE_31), .i_LD(1'b0), .i_RST((samplecntr_rst & i_CYCLE_31) | ~mrst_n),
    .i_D(2'd0), .o_Q(samplecntr_q), .o_CO()
);



///////////////////////////////////////////////////////////
//////  Attenuation rate generator
////

/*
    YM2151 uses serial counter and shift register to get the rate below

    timecntr = X_0000_00000_00000 = 0
    timecntr = X_1000_00000_00000 = 14
    timecntr = X_X100_00000_00000 = 13
    timecntr = X_XX10_00000_00000 = 12
    ...
    timecntr = X_XXXX_XXXXX_XXX10 = 2
    timecntr = X_XXXX_XXXXX_XXXX1 = 1

    I used parallel 4-bit counter instead of the shift register to save
    FPGA resources.
*/

reg             mrst_z;
reg     [1:0]   timecntr_adder;
reg     [14:0]  timecntr_sr; //this sr can hold 15-bit integer

reg             onebit_det, mrst_dlyd;
reg     [3:0]   conseczerobitcntr;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    //adder
    timecntr_adder <= mrst_n ? (((third_sample & i_CYCLE_01_TO_16) & (cycle_01_17 | timecntr_adder[1])) + timecntr_sr[0]) :
                                2'd0;

    //sr
    timecntr_sr[14] <= timecntr_adder[0];
    timecntr_sr[13:0] <= timecntr_sr[14:1];

    //consecutive zero bits counter
    mrst_z <= ~mrst_n; //delay master reset, to synchronize the reset timing with timecntr_adder register

    if(mrst_z | cycle_01_17) begin
        onebit_det <= 1'b0;
        conseczerobitcntr <= 4'd1; //start from 1
    end
    else begin
        if(!onebit_det) begin
            if(timecntr_adder[0]) begin
                onebit_det <= 1'b1;
                conseczerobitcntr <= conseczerobitcntr;
            end
            else begin
                onebit_det <= 1'b0;
                conseczerobitcntr <= (conseczerobitcntr == 4'd14) ? 4'd0 : conseczerobitcntr + 4'd1; //max 14
            end
        end
    end
end

`ifdef IKAOPM_DEBUG
reg     [15:0]  debug_timecntr;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(cycle_01_17) debug_timecntr <= {timecntr_adder[0], timecntr_sr}; //timecounter parallel output
end
`endif


reg     [1:0]   envcntr;
reg     [3:0]   attenrate;

always @(posedge i_EMUCLK) if(!phi1pcen_n) begin //positive edge!!!!
    if(third_sample & ~i_CYCLE_01_TO_16 & cycle_01_17) begin
        envcntr <= timecntr_sr[2:1];

        attenrate <= conseczerobitcntr;
    end
end



///////////////////////////////////////////////////////////
//////  Previous KON shift register
////

/*
    Note that the cycle numbers below are "elapsed" cycle, 
    NOT the master cycle counter value

                                             previous KON data
                                     |----------(32 stages)---------|
    i_KON(cyc5) -> (cyc6 - cyc9) -+> (cyc10 - cyc37) -> (cyc6 - cyc9) -> -o|¯¯¯¯\
                                  |                                        | AND )---
                                  +------------------------------------> --|____/
                                                                    positive edge detector
*/

//These shift registers holds KON values from previous 32 cycles
reg     [3:0]   cyc6r_cyc9r_kon_current_dlyline; //outer process delay compensation(4 cycles)
reg     [27:0]  cyc10r_cyc37r_kon_previous; //previous KON values
reg     [3:0]   cyc6r_cyc9r_kon_previous; //delayed concurrently with the current kon delay line

wire            cyc9r_kon_current = cyc6r_cyc9r_kon_current_dlyline[3]; //current kon value
wire            cyc9r_kon_detected = ~cyc6r_cyc9r_kon_previous[3] & cyc9r_kon_current; //prev=0, curr=1, new kon detected
assign  o_PG_PHASE_RST = cyc9r_kon_detected;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc6r_cyc9r_kon_current_dlyline[0] <= i_KON;
    cyc6r_cyc9r_kon_current_dlyline[3:1] <= cyc6r_cyc9r_kon_current_dlyline[2:0];

    cyc10r_cyc37r_kon_previous[0] <= cyc6r_cyc9r_kon_current_dlyline[3];
    cyc10r_cyc37r_kon_previous[27:1] <= cyc10r_cyc37r_kon_previous[26:0];

    cyc6r_cyc9r_kon_previous[0] <= cyc10r_cyc37r_kon_previous[27];
    cyc6r_cyc9r_kon_previous[3:1] <= cyc6r_cyc9r_kon_previous[2:0];
end



///////////////////////////////////////////////////////////
//////  Cycle 6 to 37: Envelope state machine
////

/*
    Note that the cycle numbers below are "elapsed" cycle, 
    NOT the master cycle counter value

    Envelope state machine holds the states of 32 operators

                  (state update)
                        |
                        V
    (cyc6 - cyc9) -> (cyc10 - cyc37) (loop to cyc 6, total 32 stages) 
*/

localparam ATTACK = 2'd0;
localparam FIRST_DECAY = 2'd1;
localparam SECOND_DECAY = 2'd2;
localparam RELEASE = 2'd3;

//
//  combinational part
//

//flags and prev state for FSM, get the values from the last step of the attenuation level SR
wire            cyc10c_first_decay_end;
wire            cyc10c_prevatten_min;
wire            cyc10c_prevatten_max;


//
//  register part
//

//total 32 stages to store states of all operators
reg     [1:0]   cyc6r_cyc9r_envstate_previous[0:3]; //4 stages
reg     [1:0]   cyc10r_envstate_current; //1 stage
wire    [1:0]   cyc37r_envstate_previous; //27 stages

wire    [1:0]   cyc9r_envstate_previous = cyc6r_cyc9r_envstate_previous[3];


//sr4
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    //if kon detected, make previous envstate ATTACK
    cyc6r_cyc9r_envstate_previous[0] <= (~cyc10r_cyc37r_kon_previous[27] & i_KON) ? ATTACK : cyc37r_envstate_previous;
    cyc6r_cyc9r_envstate_previous[1] <= cyc6r_cyc9r_envstate_previous[0];
    cyc6r_cyc9r_envstate_previous[2] <= cyc6r_cyc9r_envstate_previous[1];
    cyc6r_cyc9r_envstate_previous[3] <= cyc6r_cyc9r_envstate_previous[2];
end

//sr27 first stage
primitive_sr #(.WIDTH(2), .LENGTH(27), .TAP(27)) u_cyc11r_cyc37r_envstate_sr
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(cyc10r_envstate_current), .o_Q_TAP(), .o_Q_LAST(cyc37r_envstate_previous));



//state machine
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(!mrst_n) begin
        cyc10r_envstate_current <= RELEASE;
    end
    else begin
        if(cyc9r_kon_detected) begin
            cyc10r_envstate_current <= ATTACK; //start attack
        end
        else begin
            if(cyc9r_kon_current) begin
                case(cyc9r_envstate_previous)
                    //current state 0: attack
                    2'd0: begin
                        if(cyc10c_prevatten_min) begin
                            cyc10r_envstate_current <= FIRST_DECAY; //start first decay
                        end
                        else begin
                            cyc10r_envstate_current <= ATTACK; //hold state
                        end
                    end

                    //current state 1: first decay
                    2'd1: begin
                        if(cyc10c_prevatten_max) begin
                            cyc10r_envstate_current <= RELEASE; //start release
                        end
                        else begin
                            if(cyc10c_first_decay_end) begin
                                cyc10r_envstate_current <= SECOND_DECAY; //start second decay
                            end
                            else begin
                                cyc10r_envstate_current <= FIRST_DECAY; //hold state
                            end
                        end
                    end 

                    //current state 2: second decay
                    2'd2: begin
                        if(cyc10c_prevatten_max) begin
                            cyc10r_envstate_current <= RELEASE; //start release
                        end
                        else begin
                            cyc10r_envstate_current <= SECOND_DECAY; //hold state
                        end
                    end

                    //current state 3: release
                    2'd3: begin
                        cyc10r_envstate_current <= RELEASE; //hold state
                    end
                endcase                    
            end
            else begin
                cyc10r_envstate_current <= RELEASE; //key off -> start release
            end
        end
    end
end



///////////////////////////////////////////////////////////
//////  Attenuation level preprocessing
//////  Cycle 8: EG param/KS latch 
////


//
//  combinational part
//

reg     [4:0]   cyc8c_egparam;
always @(*) begin
    if(!mrst_n) begin
        cyc8c_egparam = 5'd31;
    end
    else begin
        case(cyc6r_cyc9r_envstate_previous[1])
            ATTACK:         cyc8c_egparam = i_AR;
            FIRST_DECAY:    cyc8c_egparam = i_D1R;
            SECOND_DECAY:   cyc8c_egparam = i_D2R;
            RELEASE:        cyc8c_egparam = {i_RR, 1'b1};
        endcase
    end
end


//
//  register part
//

reg     [4:0]   cyc8r_egparam;
reg             cyc8r_egparam_zero;
reg     [3:0]   cyc8r_d1l;
reg     [4:0]   cyc8r_keyscale;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc8r_egparam <= cyc8c_egparam;
    cyc8r_egparam_zero <= cyc8c_egparam == 5'd0;
    cyc8r_d1l <= i_D1L;

    case(i_KS)
        2'd0: cyc8r_keyscale <= (cyc8c_egparam == 5'd0) ? 5'd0 : {3'b000, i_EG_PDELTA_SHIFT_AMOUNT[4:3]};
        2'd1: cyc8r_keyscale <= {2'b00, i_EG_PDELTA_SHIFT_AMOUNT[4:2]};
        2'd2: cyc8r_keyscale <= {1'b0, i_EG_PDELTA_SHIFT_AMOUNT[4:1]};
        2'd3: cyc8r_keyscale <= i_EG_PDELTA_SHIFT_AMOUNT;
    endcase
end



///////////////////////////////////////////////////////////
//////  Attenuation level preprocessing
//////  Cycle 9: apply KS 
////


//
//  combinational part
//

wire    [6:0]   cyc9c_egparam_scaled_adder = {cyc8r_egparam, 1'b0} + {1'b0, cyc8r_keyscale};
wire    [9:0]   cyc40r_attenlevel_previous; //feedback from the last stage of the SR


//
//  register part
//

reg             cyc9r_egparam_zero;
reg     [5:0]   cyc9r_egparam_scaled;
reg             cyc9r_egparam_scaled_fullrate;
reg     [3:0]   cyc9r_d1l;

reg             cyc9r_third_sample;
reg     [1:0]   cyc9r_envcntr;
reg     [3:0]   cyc9r_attenrate;

reg     [9:0]   cyc9r_attenlevel_previous;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc9r_egparam_zero <= cyc8r_egparam_zero;
    cyc9r_egparam_scaled <= cyc9c_egparam_scaled_adder[6] ? 6'd63 : cyc9c_egparam_scaled_adder[5:0]; //saturation
    cyc9r_egparam_scaled_fullrate <= cyc9c_egparam_scaled_adder[5:1] == 5'b11111; //eg parameter max
    cyc9r_d1l <= cyc8r_d1l;

    cyc9r_third_sample <= third_sample;
    cyc9r_envcntr <= envcntr;
    cyc9r_attenrate <= attenrate;

    cyc9r_attenlevel_previous <= cyc40r_attenlevel_previous;
end



///////////////////////////////////////////////////////////
//////  Attenuation level preprocessing
//////  Cycle 10: make attenuation level delta weight
////


/*

    HOW ATTENUATION RATE GENERATOR WORKS:

    See "Attenuation rate generator" section. Attenrate value is determined
    from the counter value like below:

    timecntr = X_0000_00000_00000 = 0
    timecntr = X_1000_00000_00000 = 14
    timecntr = X_X100_00000_00000 = 13
    timecntr = X_XX10_00000_00000 = 12
    ...
    timecntr = X_XXXX_XXXXX_XXX10 = 2
    timecntr = X_XXXX_XXXXX_XXXX1 = 1

    An attenuation rate of 1 will occur most often, 14 or 0 will occur 
    least often. Attenuation rate * 4 (2-bit left shift) is added to 
    the "egparam_scaled" to get the final value.

    Therefore, the quadrupled values that should be added to 
    "egparam_scaled" are:

    least often <----                      ----> most often
    0, 56, 52, 48, 44, 40, 36, 32, 28, 24, 20, 16, 12, 8, 4


    If the "egparam_scaled" is NOT 11XXXX, there are three conditions 
    that can change the envelope value:

    1. egparam_scaled      != from 6'd48 to 6'd63
       egparam_scaled      != 6'd0
       egparam_rateapplied == from 6'd48 to 6'd51

    2. egparam_scaled      != from 6'd48 to 6'd63
       egparam_rateapplied == 6'd54 or 6'd55

    3. egparam_scaled      != from 6'd48 to 6'd63
       egparam_rateapplied == 6'd57 or 6'd59

    These three conditions can be compressed like this:
        egparam_scaled      != from 6'd48 to 6'd63
        egparam_scaled      != 6'd0
        egparam_rateapplied == 48, 49, 50, 51, 54, 55, 57, 59


    Therefore, if "egparam scaled" is 1, this value can change the envelope
    level when the rate is "48"
    if "egparam_scaled" is 2, this value can change the envelope level when
    the rate is "48" or "52"
    if 3, the value-changable rate is "48" or "52" or "59"
    if 4, the value-changable rate is "44"

    The rate "44" appears more often than the sum of the frequency of
    occurrence of "48", "52", "59". So, egparam_scaled = 4 can change the
    envelope level often, than 1, 2, 3. If the envelope level changes frequently,
    the difference between the envelope level of the current sample and the next 
    sample becomes larger.


    INTENSITY AND ENVELOPE DELTA WEIGHT:






*/


//
//  combinational part
//

reg             cyc10c_envdeltaweight_intensity; //0 = weak, 1 = strong
always @(*) begin
    case({cyc9r_egparam_scaled[1:0], cyc9r_envcntr})
        4'b00_00: cyc10c_envdeltaweight_intensity = 1'b0;
        4'b00_01: cyc10c_envdeltaweight_intensity = 1'b0;
        4'b00_10: cyc10c_envdeltaweight_intensity = 1'b0;
        4'b00_11: cyc10c_envdeltaweight_intensity = 1'b0;

        4'b01_00: cyc10c_envdeltaweight_intensity = 1'b1;
        4'b01_01: cyc10c_envdeltaweight_intensity = 1'b0;
        4'b01_10: cyc10c_envdeltaweight_intensity = 1'b0;
        4'b01_11: cyc10c_envdeltaweight_intensity = 1'b0;

        4'b10_00: cyc10c_envdeltaweight_intensity = 1'b1;
        4'b10_01: cyc10c_envdeltaweight_intensity = 1'b0;
        4'b10_10: cyc10c_envdeltaweight_intensity = 1'b1;
        4'b10_11: cyc10c_envdeltaweight_intensity = 1'b0;

        4'b11_00: cyc10c_envdeltaweight_intensity = 1'b1;
        4'b11_01: cyc10c_envdeltaweight_intensity = 1'b1;
        4'b11_10: cyc10c_envdeltaweight_intensity = 1'b1;
        4'b11_11: cyc10c_envdeltaweight_intensity = 1'b0;
    endcase
end

wire    [5:0]   cyc10c_egparam_rateapplied = cyc9r_egparam_scaled + {cyc9r_attenrate, 2'b00}; //discard carry

//first decay end, compare cyc9r_attenlevel_previous[9:4] with {(cyc9r_d1l == 4'd15), cyc9r_d1l, 1'b0} <- idk why
assign  cyc10c_first_decay_end =  cyc9r_attenlevel_previous[9:4] == {(cyc9r_d1l == 4'd15), cyc9r_d1l, 1'b0}; //==? {(cyc9r_d1l == 4'd15), cyc9r_d1l, 1'b0, 4'bXXXX};

//attenuation level is min(loud)
assign  cyc10c_prevatten_min = cyc9r_attenlevel_previous == 10'd0;

//attenuation level is around max(quiet), get cyc9r_attenlevel_previous[9:4] only. [3:0] don't care
assign  cyc10c_prevatten_max = cyc9r_attenlevel_previous >= 10'd1008; //==? 10'b11_1111_xxxx;


//
//  register part
//

//envelope delta weight
reg     [3:0]   cyc10r_envdeltaweight; //lv4, lv3, lv2, lv1
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    //only works every third sample
    if(cyc9r_third_sample) begin
        //if egparam_scaled == 1111XX
        if     (cyc9r_egparam_scaled[5:2] == 4'b1111) cyc10r_envdeltaweight <= cyc10c_envdeltaweight_intensity ? 4'b1000 : 4'b1000;
        
        //if egparam_scaled == 1110XX
        else if(cyc9r_egparam_scaled[5:2] == 4'b1110) cyc10r_envdeltaweight <= cyc10c_envdeltaweight_intensity ? 4'b1000 : 4'b0100;
        
        //if egparam_scaled == 1101XX
        else if(cyc9r_egparam_scaled[5:2] == 4'b1101) cyc10r_envdeltaweight <= cyc10c_envdeltaweight_intensity ? 4'b0100 : 4'b0010;
        
        //if egparam_scaled == 1100XX
        else if(cyc9r_egparam_scaled[5:2] == 4'b1100) cyc10r_envdeltaweight <= cyc10c_envdeltaweight_intensity ? 4'b0010 : 4'b0001;
        
        //else, not 11XXXX
        else begin
            if(cyc9r_egparam_zero) begin
                cyc10r_envdeltaweight <= 4'b0000;
            end
            else begin
                if(cyc9r_egparam_scaled != 6'd0 & 
                    |{cyc10c_egparam_rateapplied == 6'd59, cyc10c_egparam_rateapplied == 6'd57,
                        cyc10c_egparam_rateapplied == 6'd55, cyc10c_egparam_rateapplied == 6'd54,
                        cyc10c_egparam_rateapplied == 6'd51, cyc10c_egparam_rateapplied == 6'd50,
                        cyc10c_egparam_rateapplied == 6'd49, cyc10c_egparam_rateapplied == 6'd48}) begin
                    
                    cyc10r_envdeltaweight <= 4'b0001;
                end
                else begin
                    cyc10r_envdeltaweight <= 4'b0000;
                end
            end
        end
    end
    else begin
        cyc10r_envdeltaweight <= 4'b0000;
    end
end

//misc flags for envelope generator feedback
reg             cyc10r_atten_inc; //attenuation level decrement mode(for decay and release)
reg             cyc10r_atten_dec; //attenuation level increment mode(for attack)
reg             cyc10r_fix_prevatten_max; //force previous attenuation level max(quiet)
reg             cyc10r_enable_prevatten; //previous attenuation level enable(disable = 0)
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(!mrst_n) begin
        cyc10r_atten_inc <= 1'b0;
        cyc10r_atten_dec <= 1'b0;
    end
    else begin
        cyc10r_atten_inc     <= ( cyc9r_envstate_previous == FIRST_DECAY &
                                ~cyc9r_kon_detected &
                                ~cyc10c_first_decay_end &
                                ~cyc10c_prevatten_max ) |
                                ((cyc9r_envstate_previous == SECOND_DECAY | cyc9r_envstate_previous == RELEASE) &
                                ~cyc9r_kon_detected &
                                ~cyc10c_prevatten_max );

        cyc10r_atten_dec      <= ( cyc9r_envstate_previous == ATTACK &
                                cyc9r_kon_current &
                                ~cyc10c_prevatten_min &
                                ~cyc9r_egparam_scaled_fullrate );
    end

    cyc10r_fix_prevatten_max <= ( cyc9r_envstate_previous != ATTACK ) & ~cyc9r_kon_detected & cyc10c_prevatten_max;

    cyc10r_enable_prevatten  <= (~cyc9r_kon_detected &
                                    cyc9r_egparam_scaled_fullrate) |
                                    ~cyc9r_egparam_scaled_fullrate;
end

reg     [9:0]   cyc10r_attenlevel_previous;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc10r_attenlevel_previous <= cyc9r_attenlevel_previous;
end



///////////////////////////////////////////////////////////
//////  Cycle 11 to 40: Attenuation level SR storage
////

/*
    Note that the cycle numbers below are "elapsed" cycle, 
    NOT the master cycle counter value

    start from cycle 11, this shift register stores all envelopes of 32 operators

                                                  <---------(30 stages)----------->
    cyc6  -> cyc7  -> cyc8  -> cyc9  -> cyc10 -+> cyc11 -> cyc12 -> (cyc13 - cyc40) --> attenuation value output from cycle 40
                                               |                               |
                                 +---------------------------------------------+
                                 V             |
                               cyc9  -> cyc10 -+
                               <--(2 stages)-->

*/ 

//
//  cycle 11: latch weighted delta
//

reg     [9:0]   cyc11r_attenlevel_previous_gated; //loud: 10'd0, quiet: 10'd1023
reg     [9:0]   cyc11r_attenlevel_weighted_delta;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(cyc10r_fix_prevatten_max | ~mrst_n) cyc11r_attenlevel_previous_gated <= 10'd1023;
    else begin
        if(cyc10r_enable_prevatten) cyc11r_attenlevel_previous_gated <= cyc10r_attenlevel_previous;
        else                        cyc11r_attenlevel_previous_gated <= 10'd0;
    end

    case({cyc10r_atten_dec, cyc10r_atten_inc})
        //off, no change
        2'b00: cyc11r_attenlevel_weighted_delta <= 10'd0;

        //attenuation level increment: quieter
        2'b01: cyc11r_attenlevel_weighted_delta <= {6'b000000, cyc10r_envdeltaweight};

        //attenuation level decrement: louder
        2'b10: begin
            case(cyc10r_envdeltaweight)
                4'b0001: cyc11r_attenlevel_weighted_delta <= {4'b1111, ~cyc10r_attenlevel_previous[9:5], ~cyc10r_attenlevel_previous[3]};
                4'b0010: cyc11r_attenlevel_weighted_delta <= {3'b111, ~cyc10r_attenlevel_previous[9:5], ~cyc10r_attenlevel_previous[3], ~cyc10r_attenlevel_previous[1]};
                4'b0100: cyc11r_attenlevel_weighted_delta <= {2'b11, ~cyc10r_attenlevel_previous[9:5], ~cyc10r_attenlevel_previous[3], {2{~cyc10r_attenlevel_previous[2]}}};
                4'b1000: cyc11r_attenlevel_weighted_delta <= {1'b1, ~cyc10r_attenlevel_previous[9:5], {4{~cyc10r_attenlevel_previous[4]}}};
                default: cyc11r_attenlevel_weighted_delta <= 10'd0;
            endcase
        end

        //invalid, will not happen
        2'b11: cyc11r_attenlevel_weighted_delta <= 10'd1023;
    endcase
end



//
//  cycle 12: add delta
//

reg     [9:0]   cyc12r_attenlevel_current;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc12r_attenlevel_current <= cyc11r_attenlevel_previous_gated + cyc11r_attenlevel_weighted_delta; //discard carry
end



//
//  cycle from 13 to 40: shift register storage
//

//total 32 stages to store all levels, SR 28 stages and the remaining 4 stages from cyc9r to cyc12r

primitive_sr #(.WIDTH(10), .LENGTH(28), .TAP(28)) u_cyc13r_cyc40r_attenlevel_sr
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(cyc12r_attenlevel_current), .o_Q_TAP(), .o_Q_LAST(cyc40r_attenlevel_previous));





///////////////////////////////////////////////////////////
//////  Attenuation level postprocessing
//////  Cycle 40: shift LFA
////

//
//  register part
//

reg     [9:0]   cyc40r_lfa_shifted;
reg             cyc40r_force_no_atten;
reg     [6:0]   cyc40r_tl;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    case(i_AMS)
        2'd0: cyc40r_lfa_shifted <= {10'd0};
        2'd1: cyc40r_lfa_shifted <= {2'b00, i_LFA};
        2'd2: cyc40r_lfa_shifted <= {1'b0, i_LFA, 1'b0};
        2'd3: cyc40r_lfa_shifted <= {i_LFA, 2'b00};
    endcase

    cyc40r_force_no_atten <= i_TEST_D5;
    cyc40r_tl <= i_TL;
end



///////////////////////////////////////////////////////////
//////  Attenuation level postprocessing
//////  Cycle 41: apply LFA/underflow handling
////

//
//  combinational part
//

wire    [10:0]  cyc41c_attenlevel_mod_adder = cyc40r_attenlevel_previous + cyc40r_lfa_shifted;


//
//  register part
//

reg     [9:0]   cyc41r_attenlevel_mod;
reg             cyc41r_force_no_atten;
reg     [6:0]   cyc41r_tl;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc41r_attenlevel_mod <= cyc41c_attenlevel_mod_adder[10] ? 10'd1023 : cyc41c_attenlevel_mod_adder[9:0]; //attenlevel saturation

    cyc41r_force_no_atten <= cyc40r_force_no_atten;
    cyc41r_tl <= cyc40r_tl;
end



///////////////////////////////////////////////////////////
//////  Attenuation level postprocessing
//////  Cycle 42: apply TL/underflow handling
////

//
//  combinational part
//

wire    [10:0]  cyc42c_attenlevel_tl_adder = cyc41r_attenlevel_mod + {cyc41r_tl, 3'b000}; //multiply by 8


//
//  register part
//

reg     [9:0]   cyc42r_attenlevel_tl;
reg             cyc42r_force_no_atten;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc42r_attenlevel_tl <= cyc42c_attenlevel_tl_adder[10] ? 10'd1023 : cyc42c_attenlevel_tl_adder[9:0]; //attenlevel saturation

    cyc42r_force_no_atten <= cyc41r_force_no_atten;
end



///////////////////////////////////////////////////////////
//////  Attenuation level postprocessing
//////  Cycle 43: apply test bit
////

reg     [9:0]   cyc43r_attenlevel_final;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc43r_attenlevel_final <= cyc42r_force_no_atten ? 10'd0 : cyc42r_attenlevel_tl; //force attenlevel min(loud)
end

//final value
assign  o_OP_ATTENLEVEL = cyc43r_attenlevel_final;



///////////////////////////////////////////////////////////
//////  Attenuation level serialization
////

reg     [9:0]   noise_attenlevel;
assign  o_NOISE_ATTENLEVEL = noise_attenlevel[9];
assign  o_REG_ATTENLEVEL_CH8_C2 = noise_attenlevel[9];

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(i_CYCLE_03) noise_attenlevel <= cyc43r_attenlevel_final;
    else begin 
        noise_attenlevel[9:1] <= noise_attenlevel[8:0];
        noise_attenlevel[0] <= 1'b1;
    end
end



///////////////////////////////////////////////////////////
//////  STATIC STORAGE FOR DEBUG
////

`ifdef IKAOPM_DEBUG

reg     [4:0]   sim_attenlevel_static_storage_addr_cntr = 5'd0;
reg     [4:0]   sim_envstate_static_storage_addr_cntr = 5'd0;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(i_CYCLE_03) sim_attenlevel_static_storage_addr_cntr <= 5'd0;
    else sim_attenlevel_static_storage_addr_cntr <= sim_attenlevel_static_storage_addr_cntr == 5'd31 ? 5'd0 : sim_attenlevel_static_storage_addr_cntr + 5'd1;

    if(i_CYCLE_03) sim_envstate_static_storage_addr_cntr <= 5'd1;
    else sim_envstate_static_storage_addr_cntr <= sim_envstate_static_storage_addr_cntr == 5'd31 ? 5'd0 : sim_envstate_static_storage_addr_cntr + 5'd1;
end

reg     [9:0]  sim_attenlevel_static_storage[0:31];
reg     [1:0]  sim_envstate_static_storage[0:31];
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    sim_attenlevel_static_storage[sim_attenlevel_static_storage_addr_cntr] <= mrst_n ? ~cyc43r_attenlevel_final : 10'd0;
    sim_envstate_static_storage[sim_envstate_static_storage_addr_cntr] <= mrst_n ? cyc10r_envstate_current : 2'd3;
end

`endif

endmodule
