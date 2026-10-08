/* verilator lint_off WIDTHEXPAND */
module IKAOPM_op (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_03,
    input   wire            i_CYCLE_12,
    input   wire            i_CYCLE_04_12_20_28,

    input   wire    [2:0]   i_ALG,
    input   wire    [2:0]   i_FL,
    input   wire            i_TEST_D4, //test register

    input   wire    [9:0]   i_OP_PHASEDATA,
    input   wire    [9:0]   i_OP_ATTENLEVEL,
    output  wire            o_ACC_SNDADD,
    output  wire    [13:0]  o_ACC_OPDATA
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;



///////////////////////////////////////////////////////////
//////  Algorithm state counter
////

wire    [1:0]   algst_cntr;
primitive_counter #(.WIDTH(2)) u_op_algst_cntr (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(i_CYCLE_04_12_20_28), .i_LD(1'b0), .i_RST(i_CYCLE_12 | ~mrst_n),
    .i_D(2'd0), .o_Q(algst_cntr), .o_CO()
);



///////////////////////////////////////////////////////////
//////  Cycle 41: Phase modulation
////

//
//  combinational part
//

reg     [9:0]   cyc56r_phasemod_value; //get value from the end of the pipeline
wire    [10:0]  cyc41c_modded_phase_adder = !mrst_n ? 10'd0 : i_OP_PHASEDATA + cyc56r_phasemod_value;




//
//  register part
//

reg     [7:0]   cyc41r_logsinrom_phase;
reg             cyc41r_level_fp_sign;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc41r_logsinrom_phase <= cyc41c_modded_phase_adder[8] ?  cyc41c_modded_phase_adder[7:0] : 
                                                             ~cyc41c_modded_phase_adder[7:0];

    cyc41r_level_fp_sign <= cyc41c_modded_phase_adder[9]; //discard carry
end



///////////////////////////////////////////////////////////
//////  Cycle 42: Get data from Sin ROM
////

//
//  register part
//

wire    [45:0]  cyc42r_logsinrom_out;
op_submdl_logsinrom u_cyc42r_logsinrom (
    .i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_ADDR(cyc41r_logsinrom_phase[5:1]), .o_DATA(cyc42r_logsinrom_out)
);

reg             cyc42r_logsinrom_phase_odd;
reg     [1:0]   cyc42r_logsinrom_bitsel;
reg             cyc42r_level_fp_sign;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc42r_logsinrom_phase_odd <= cyc41r_logsinrom_phase[0];
    cyc42r_logsinrom_bitsel <= cyc41r_logsinrom_phase[7:6];
    cyc42r_level_fp_sign <= cyc41r_level_fp_sign;
end



///////////////////////////////////////////////////////////
//////  Cycle 43: Choose bits from Sin ROM and add them
////

//
//  combinational part
//

wire    [45:0]  ls = cyc42r_logsinrom_out; //alias signal
wire            odd = cyc42r_logsinrom_phase_odd; //alias signal

reg     [10:0]  cyc43c_logsinrom_addend0, cyc43c_logsinrom_addend1;
always @(*) begin
    case(cyc42r_logsinrom_bitsel)
        /*                                   D10      D9      D8      D7      D6      D5      D4      D3      D2      D1      D0  */
        2'd0: cyc43c_logsinrom_addend0 = {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0, ls[29], ls[25], ls[18], ls[14],  ls[3]};
        2'd1: cyc43c_logsinrom_addend0 = {  1'b0,   1'b0,   1'b0,   1'b0, ls[37], ls[34], ls[28], ls[24], ls[17], ls[13],  ls[2]};
        2'd2: cyc43c_logsinrom_addend0 = {  1'b0,   1'b0, ls[43], ls[41], ls[36], ls[33], ls[27], ls[23], ls[16], ls[12],  ls[1]};
        2'd3: cyc43c_logsinrom_addend0 = {ls[45], ls[44], ls[42], ls[40], ls[35], ls[32], ls[26], ls[22], ls[15], ls[11],  ls[0]};
    endcase

    case(cyc42r_logsinrom_bitsel)
        /*                                   D10      D9      D8      D7      D6      D5      D4      D3      D2      D1      D0  */
        2'd0: cyc43c_logsinrom_addend1 = {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,  ls[7]} & {2'b00, {9{odd}}};
        2'd1: cyc43c_logsinrom_addend1 = {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0, ls[10],  ls[6]} & {2'b00, {9{odd}}};
        2'd2: cyc43c_logsinrom_addend1 = {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0, ls[20],  ls[9],  ls[5]} & {2'b00, {9{odd}}};
        2'd3: cyc43c_logsinrom_addend1 = {  1'b0,   1'b0, ls[39], ls[39], ls[38], ls[31], ls[30], ls[21], ls[19],  ls[8],  ls[4]} & {2'b00, {9{odd}}};
    endcase 
end


//
//  register part
//

reg     [11:0]  cyc43r_logsin_raw;
reg             cyc43r_level_fp_sign;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc43r_logsin_raw <= cyc43c_logsinrom_addend0 + cyc43c_logsinrom_addend1;
    cyc43r_level_fp_sign <= cyc42r_level_fp_sign;
end



///////////////////////////////////////////////////////////
//////  Cycle 44: Apply attenuation level
////

//
//  register part
//

reg     [12:0]  cyc44r_logsin_attenuated;
reg             cyc44r_level_fp_sign;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc44r_logsin_attenuated <= cyc43r_logsin_raw + {i_OP_ATTENLEVEL, 2'b00};
    cyc44r_level_fp_sign <= cyc43r_level_fp_sign;
end



///////////////////////////////////////////////////////////
//////  Cycle 45: Saturation
////

//
//  register part
//

reg     [11:0]  cyc45r_logsin_saturated;
reg             cyc45r_level_fp_sign;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc45r_logsin_saturated <= cyc44r_logsin_attenuated[12] ? 12'd4095 : cyc44r_logsin_attenuated[11:0]; //discard carry
    cyc45r_level_fp_sign <= cyc44r_level_fp_sign;
end



///////////////////////////////////////////////////////////
//////  Cycle 46: Get data from exp ROM
////

//
//  register part
//

wire    [44:0]  cyc46r_exprom_out;
op_submdl_exprom u_cyc46r_exprom (
    .i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_ADDR(cyc45r_logsin_saturated[5:1]), .o_DATA(cyc46r_exprom_out)
);

reg             cyc46r_logsin_even;
reg     [1:0]   cyc46r_exprom_bitsel;
reg     [3:0]   cyc46r_level_fp_exp;
reg             cyc46r_level_fp_sign;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc46r_logsin_even <= ~cyc45r_logsin_saturated[0]; //inverted!! EVEN flag!!
    cyc46r_exprom_bitsel <= cyc45r_logsin_saturated[7:6];
    cyc46r_level_fp_exp <= ~cyc45r_logsin_saturated[11:8]; //invert
    cyc46r_level_fp_sign <= cyc45r_level_fp_sign;
end



///////////////////////////////////////////////////////////
//////  Cycle 47: Choose bits from exp ROM and add them
////

//
//  combinational part
//

wire    [44:0]  e = cyc46r_exprom_out; //alias signal
wire            even = cyc46r_logsin_even; //alias signal

reg     [9:0]  cyc47c_exprom_addend0, cyc47c_exprom_addend1;
always @(*) begin
    case(cyc46r_exprom_bitsel)
        /*                                 D9      D8      D7      D6      D5      D4      D3      D2      D1     D0  */
        2'd0: cyc47c_exprom_addend0 = {  1'b1,  e[43],  e[40],  e[36],  e[32],  e[28],  e[24],  e[18],  e[14],   e[3]};
        2'd1: cyc47c_exprom_addend0 = { e[44],  e[42],  e[39],  e[35],  e[31],  e[27],  e[23],  e[17],  e[13],   e[2]};
        2'd2: cyc47c_exprom_addend0 = {  1'b0,  e[41],  e[38],  e[34],  e[30],  e[26],  e[22],  e[16],  e[12],   e[1]};
        2'd3: cyc47c_exprom_addend0 = {  1'b0,   1'b0,  e[37],  e[33],  e[29],  e[25],  e[21],  e[15],  e[11],   e[0]};
    endcase

    case(cyc46r_exprom_bitsel)
        /*                                 D9      D8      D7      D6      D5      D4      D3      D2      D1      D0  */
        2'd0: cyc47c_exprom_addend1 = {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b1,  e[10],   e[7]} & {7'b0000000, {3{even}}};
        2'd1: cyc47c_exprom_addend1 = {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b1,   1'b0,   e[6]} & {7'b0000000, {3{even}}};
        2'd2: cyc47c_exprom_addend1 = {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,  e[19],   e[9],   e[5]} & {7'b0000000, {3{even}}};
        2'd3: cyc47c_exprom_addend1 = {  1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,   1'b0,  e[20],   e[8],   e[4]} & {7'b0000000, {3{even}}};
    endcase 
end


//
//  register part
//

reg     [9:0]   cyc47r_level_fp_mant;
reg     [3:0]   cyc47r_level_fp_exp;
reg             cyc47r_level_fp_sign;
reg             cyc47r_level_negate;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc47r_level_fp_mant <= cyc47c_exprom_addend0 + cyc47c_exprom_addend1; //discard carry
    cyc47r_level_fp_exp <= cyc46r_level_fp_exp;
    cyc47r_level_fp_sign <= cyc46r_level_fp_sign;
    cyc47r_level_negate <= i_TEST_D4;
end



///////////////////////////////////////////////////////////
//////  Cycle 48: Floating point to integer
////

//
//  combinational part
//

reg     [12:0]  cyc48c_shifter0, cyc48c_shifter1;
always @(*) begin
    case(cyc47r_level_fp_exp[1:0])
        2'b00: cyc48c_shifter0 = {3'b000, 1'b1, cyc47r_level_fp_mant[9:1]};
        2'b01: cyc48c_shifter0 = {2'b00, 1'b1, cyc47r_level_fp_mant      };
        2'b10: cyc48c_shifter0 = {1'b0, 1'b1, cyc47r_level_fp_mant, 1'b0 };
        2'b11: cyc48c_shifter0 = {     1'b1, cyc47r_level_fp_mant, 2'b00 };
    endcase

    case(cyc47r_level_fp_exp[3:2])
        2'b00: cyc48c_shifter1 = {12'b0, cyc48c_shifter0[12]  };
        2'b01: cyc48c_shifter1 = { 8'b0, cyc48c_shifter0[12:8]};
        2'b10: cyc48c_shifter1 = { 4'b0, cyc48c_shifter0[12:4]};
        2'b11: cyc48c_shifter1 = cyc48c_shifter0;
    endcase
end

//
//  register part
//

reg             cyc48r_level_negate;
reg             cyc48r_level_sign;
reg     [12:0]  cyc48r_level_magnitude;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc48r_level_negate <= cyc47r_level_negate;
    cyc48r_level_sign <= cyc47r_level_fp_sign;
    cyc48r_level_magnitude <= cyc48c_shifter1;
end



///////////////////////////////////////////////////////////
//////  Cycle 49: sign-magnitude to signed integer
////

//
//  register part
//

reg     [13:0]  cyc49r_level_signed;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc49r_level_signed <= cyc48r_level_sign ? (~{cyc48r_level_negate, cyc48r_level_magnitude} + 14'd1) : 
                                                 {cyc48r_level_negate, cyc48r_level_magnitude};
end



///////////////////////////////////////////////////////////
//////  Cycle 50: delay
////

//
//  register part
//

reg     [13:0]  cyc50r_level_signed;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc50r_level_signed <= cyc49r_level_signed;
end



///////////////////////////////////////////////////////////
//////  Cycle 51: delay
////

//
//  register part
//

reg     [13:0]  cyc51r_level_signed;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc51r_level_signed <= cyc50r_level_signed;
end



///////////////////////////////////////////////////////////
//////  Cycle 52: delay / latch algorithm type and state
////

//
//  register part
//

reg     [1:0]   cyc52r_algst;
reg     [2:0]   cyc52r_algtype;
reg     [13:0]  cyc52r_level_signed;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc52r_algst <= algst_cntr; //algorithm state counter
    cyc52r_algtype <= i_ALG; //algorithm type

    cyc52r_level_signed <= cyc51r_level_signed;
end



///////////////////////////////////////////////////////////
//////  Cycle 53: delay / Z reg / algorithm decoder
////

//
//  combinational part
//

assign  o_ACC_OPDATA = cyc52r_level_signed; //OP data output
reg             cyc53c_accumulation_en;
assign  o_ACC_SNDADD = cyc53c_accumulation_en;
always @(*) begin
    case(cyc52r_algst)
        2'd0: cyc53c_accumulation_en = cyc52r_algtype == 3'd7; //Add M1?
        2'd1: cyc53c_accumulation_en = cyc52r_algtype == 3'd7 || cyc52r_algtype == 3'd6 || cyc52r_algtype == 3'd5; //Add M2?
        2'd2: cyc53c_accumulation_en = cyc52r_algtype == 3'd7 || cyc52r_algtype == 3'd6 || cyc52r_algtype == 3'd5 || cyc52r_algtype == 3'd4; //Add C1?
        2'd3: cyc53c_accumulation_en = 1'b1; //Add C2?
    endcase
end


//
//  register part
//

//signed sound level
reg     [1:0]   cyc53r_algst;
reg     [2:0]   cyc53r_algtype;
reg     [13:0]  cyc53r_OP_current;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc53r_algst <= cyc52r_algst;
    cyc53r_algtype <= cyc52r_algtype;

    cyc53r_OP_current <= cyc52r_level_signed;
end


//Z registers that hold previous values
reg             cyc53r_M1_z_ld, cyc53r_M1_zz_ld; //store THIS M1 value, store PREVIOUS M1 value again
reg             cyc53r_C1_z_ld; //store THIS C1 value
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc53r_M1_z_ld <= cyc52r_algst == 2'd0;
    cyc53r_M1_zz_ld <= cyc52r_algst == 2'd0;
    cyc53r_C1_z_ld <= cyc52r_algst == 2'd2;
end

wire    [13:0]  cyc53r_M1_z_reg_out, cyc53r_M1_zz_reg_out, cyc53r_C1_z_reg_out;
wire    [13:0]  cyc46c_M1_z_reg_in  = !mrst_n ? 14'd0 : 
                                                cyc53r_M1_z_ld ? cyc53r_OP_current: cyc53r_M1_z_reg_out;
wire    [13:0]  cyc46c_M1_zz_reg_in = !mrst_n ? 14'd0 : 
                                                cyc53r_M1_zz_ld ? cyc53r_M1_z_reg_out : cyc53r_M1_zz_reg_out;
wire    [13:0]  cyc46c_C1_z_reg_in  = !mrst_n ? 14'd0 : 
                                                cyc53r_C1_z_ld ? cyc53r_OP_current : cyc53r_C1_z_reg_out;

//stores THIS M1
primitive_sr #(.WIDTH(14), .LENGTH(8), .TAP(8)) u_cyc46r_cyc53r_M1_z
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(cyc46c_M1_z_reg_in), .o_Q_TAP(), .o_Q_LAST(cyc53r_M1_z_reg_out));

//stores PREVIOUS M1 again, this will be used for M1 self feedback calculation
primitive_sr #(.WIDTH(14), .LENGTH(8), .TAP(8)) u_cyc46r_cyc53r_M1_zz
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(cyc46c_M1_zz_reg_in), .o_Q_TAP(), .o_Q_LAST(cyc53r_M1_zz_reg_out));

//stores THIS C1
primitive_sr #(.WIDTH(14), .LENGTH(8), .TAP(8)) u_cyc46r_cyc53r_C1_z
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(cyc46c_C1_z_reg_in), .o_Q_TAP(), .o_Q_LAST(cyc53r_C1_z_reg_out));

//misc control bits
reg             cyc53r_self_fdbk_en;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc53r_self_fdbk_en <= cyc52r_algst == 2'd2;
end




///////////////////////////////////////////////////////////
//////  Cycle 54: select addend 0 and 1
////

//
//  register part
//

//make alias signals
wire    [13:0]  M1    = cyc53r_OP_current;
wire    [13:0]  M2    = cyc53r_OP_current;
wire    [13:0]  M1_z  = cyc53r_M1_z_reg_out;
wire    [13:0]  M1_zz = cyc53r_M1_zz_reg_out;
wire    [13:0]  C1_z  = cyc53r_C1_z_reg_out;

//selector
reg     [13:0]  cyc54r_op_addend0, cyc54r_op_addend1;
reg             cyc54r_self_fdbk_en;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    case({cyc53r_algtype, cyc53r_algst})
        //Algorithm 0
        5'b000_10: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= M1_zz; end //state 2
        5'b000_11: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= C1_z ; end //state 3
        5'b000_00: begin cyc54r_op_addend0 <= M1   ; cyc54r_op_addend1 <= 14'd0; end //state 0
        5'b000_01: begin cyc54r_op_addend0 <= M2   ; cyc54r_op_addend1 <= 14'd0; end //state 1
        
        //Algorithm 1
        5'b001_10: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= M1_zz; end //state 2
        5'b001_11: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= C1_z ; end //state 3
        5'b001_00: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= 14'd0; end //state 0
        5'b001_01: begin cyc54r_op_addend0 <= M2   ; cyc54r_op_addend1 <= 14'd0; end //state 1
        
        //Algorithm 2
        5'b010_10: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= M1_zz; end //state 2
        5'b010_11: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= C1_z ; end //state 3
        5'b010_00: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= 14'd0; end //state 0
        5'b010_01: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= M2   ; end //state 1
        
        //Algorithm 3
        5'b011_10: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= M1_zz; end //state 2
        5'b011_11: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= 14'd0; end //state 3
        5'b011_00: begin cyc54r_op_addend0 <= M1   ; cyc54r_op_addend1 <= 14'd0; end //state 0
        5'b011_01: begin cyc54r_op_addend0 <= M2   ; cyc54r_op_addend1 <= C1_z ; end //state 1
        
        //Algorithm 4
        5'b100_10: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= M1_zz; end //state 2
        5'b100_11: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= 14'd0; end //state 3
        5'b100_00: begin cyc54r_op_addend0 <= M1   ; cyc54r_op_addend1 <= 14'd0; end //state 0
        5'b100_01: begin cyc54r_op_addend0 <= M2   ; cyc54r_op_addend1 <= 14'd0; end //state 1
        
        //Algorithm 5
        5'b101_10: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= M1_zz; end //state 2
        5'b101_11: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= 14'd0; end //state 3
        5'b101_00: begin cyc54r_op_addend0 <= M1   ; cyc54r_op_addend1 <= 14'd0; end //state 0
        5'b101_01: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= 14'd0; end //state 1
        
        //Algorithm 6
        5'b110_10: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= M1_zz; end //state 2
        5'b110_11: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= 14'd0; end //state 3
        5'b110_00: begin cyc54r_op_addend0 <= M1   ; cyc54r_op_addend1 <= 14'd0; end //state 0
        5'b110_01: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= 14'd0; end //state 1
        
        //Algorithm 7
        5'b111_10: begin cyc54r_op_addend0 <= M1_z ; cyc54r_op_addend1 <= M1_zz; end //state 2
        5'b111_11: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= 14'd0; end //state 3
        5'b111_00: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= 14'd0; end //state 0
        5'b111_01: begin cyc54r_op_addend0 <= 14'd0; cyc54r_op_addend1 <= 14'd0; end //state 1
    endcase

    cyc54r_self_fdbk_en <= cyc53r_self_fdbk_en;
end



///////////////////////////////////////////////////////////
//////  Cycle 55: sum two operator outputs
////

//
//  register part
//

reg             cyc55r_self_fdbk_en;
reg     [2:0]   cyc55r_fl;
reg     [14:0]  cyc55r_op_sum;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cyc55r_self_fdbk_en <= cyc54r_self_fdbk_en;
    cyc55r_fl <= cyc54r_self_fdbk_en ? i_FL : 3'd0;
    cyc55r_op_sum <= {cyc54r_op_addend0[13], cyc54r_op_addend0} + {cyc54r_op_addend1[13], cyc54r_op_addend1}; //add with sign extension, carry discarded
end



///////////////////////////////////////////////////////////
//////  Cycle 56: phase modulation value
////

//
//  register part
//

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(cyc55r_self_fdbk_en) begin
        case(cyc55r_fl)
            3'd0: cyc56r_phasemod_value <= 10'd0;
            3'd1: cyc56r_phasemod_value <= {{4{cyc55r_op_sum[14]}}, cyc55r_op_sum[14:9]};
            3'd2: cyc56r_phasemod_value <= {{3{cyc55r_op_sum[14]}}, cyc55r_op_sum[14:8]};
            3'd3: cyc56r_phasemod_value <= {{2{cyc55r_op_sum[14]}}, cyc55r_op_sum[14:7]};
            3'd4: cyc56r_phasemod_value <= {{1{cyc55r_op_sum[14]}}, cyc55r_op_sum[14:6]};
            3'd5: cyc56r_phasemod_value <= cyc55r_op_sum[14:5];
            3'd6: cyc56r_phasemod_value <= cyc55r_op_sum[13:4];
            3'd7: cyc56r_phasemod_value <= cyc55r_op_sum[12:3];
        endcase
    end
    else cyc56r_phasemod_value <= cyc55r_op_sum[10:1];
end

endmodule


module op_submdl_logsinrom (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //clock enable
    input   wire            i_CEN_n, //positive edge clock enable for emulation

    input   wire    [4:0]   i_ADDR,
    output  reg     [45:0]  o_DATA
);

always @(posedge i_EMUCLK) if(!i_CEN_n) begin
    case(i_ADDR)
        5'd0 : o_DATA <= 46'b000110000010010001000100_0010101010101001010010;
        5'd1 : o_DATA <= 46'b000110000011010000010000_0010010001001101000001;
        5'd2 : o_DATA <= 46'b000110000011010000010011_0010001011001101100000;
        5'd3 : o_DATA <= 46'b000111000001000000000011_0010110001001101110010;
        5'd4 : o_DATA <= 46'b000111000001000000110000_0010111010001101101001;
        5'd5 : o_DATA <= 46'b000111000001010000100110_0010000000101101111010;
        5'd6 : o_DATA <= 46'b000111000001010000110110_0010010011001101011010;
        5'd7 : o_DATA <= 46'b000111000001110000010101_0010111000101111111100;

        5'd8 : o_DATA <= 46'b000111000011100000000111_0010101110001101110111;
        5'd9 : o_DATA <= 46'b000111000011100001010011_1000011101011010100110;
        5'd10: o_DATA <= 46'b000111000011110001100001_1000111100001001111010;
        5'd11: o_DATA <= 46'b000111000011110001110011_1001101011001001110111;
        5'd12: o_DATA <= 46'b010010000101000001000101_1001001000111010110111;
        5'd13: o_DATA <= 46'b010010000101010001000100_1001110001111100101010;
        5'd14: o_DATA <= 46'b010010000101010001010110_1101111110100101000110;
        5'd15: o_DATA <= 46'b010010001110000000100001_1001010110101101111001;

        5'd16: o_DATA <= 46'b010010001110010000100010_1011100101001011101111;
        5'd17: o_DATA <= 46'b010010001110110000011101_1010000001011010110001;
        5'd18: o_DATA <= 46'b010011001100100000011110_1010000010111010111111;
        5'd19: o_DATA <= 46'b010011001100110000101101_1110101110110110000001;
        5'd20: o_DATA <= 46'b010011001110100001101011_1011001010001101110001;
        5'd21: o_DATA <= 46'b010011001110110101101011_0101111001010100001111;
        5'd22: o_DATA <= 46'b011100001000000101011100_0101010101010110010111;
        5'd23: o_DATA <= 46'b011100001000010101011111_0111110101010010111011;

        5'd24: o_DATA <= 46'b011100001011010110100010_1100001000010000011001;
        5'd25: o_DATA <= 46'b011101001001100110010001_1110100100010010010010;
        5'd26: o_DATA <= 46'b011101001011101010010110_0101000000110100100011;
        5'd27: o_DATA <= 46'b101000001001101010110101_1101100001110010011010;
        5'd28: o_DATA <= 46'b101000001011111111110010_0111010100010000111001;
        5'd29: o_DATA <= 46'b101001011111010011001000_1100111001010110100000;
        5'd30: o_DATA <= 46'b101101011101001111101101_1110000100110010100001;
        5'd31: o_DATA <= 46'b111001101111000111101110_0111100001110110100111;
    endcase
end

endmodule


module op_submdl_exprom (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //clock enable
    input   wire            i_CEN_n, //positive edge clock enable for emulation

    input   wire    [4:0]   i_ADDR,
    output  reg     [44:0]  o_DATA
);

always @(posedge i_EMUCLK) if(!i_CEN_n) begin
    case(i_ADDR)
        5'd0 : o_DATA <= 45'b110111111000111111010001_011000000100110011101;
        5'd1 : o_DATA <= 45'b110111111000110100111110_000001100001110110011;
        5'd2 : o_DATA <= 45'b110111111000000111101101_011101110100111011010;
        5'd3 : o_DATA <= 45'b110111111000000111000011_011100000010101010110;
        5'd4 : o_DATA <= 45'b110111111000000100001100_010100000010101011011;
        5'd5 : o_DATA <= 45'b110111010010101010111011_011000111100111011101;
        5'd6 : o_DATA <= 45'b110110010110111011110100_111001011000011000000;
        5'd7 : o_DATA <= 45'b110110010110111001001011_010001001100111011110;

        5'd8 : o_DATA <= 45'b110110010110011010001101_011000101000111011010;
        5'd9 : o_DATA <= 45'b110110010110000011100110_011110010100111010100;
        5'd10: o_DATA <= 45'b110110000111000101111001_010110110100110010101;
        5'd11: o_DATA <= 45'b110100001111100110011110_011111110000110011011;
        5'd12: o_DATA <= 45'b110100001111100110000001_001111001101110111101;
        5'd13: o_DATA <= 45'b110100001001111101101111_010110101010101010001;
        5'd14: o_DATA <= 45'b110100001001111101100000_010110001100110010011;
        5'd15: o_DATA <= 45'b110100001001011010110101_011001110000111010101;

        5'd16: o_DATA <= 45'b110100001001011000011010_001001010101110110111;
        5'd17: o_DATA <= 45'b110100001001001001010100_000000111001110110001;
        5'd18: o_DATA <= 45'b110100000001100011101011_000000011101110110011;
        5'd19: o_DATA <= 45'b110100000001100000101100_001011100001111110101;
        5'd20: o_DATA <= 45'b110100000000100100010011_011011000100110010101;
        5'd21: o_DATA <= 45'b011101000100010111011101_000010101001110110101;
        5'd22: o_DATA <= 45'b011001100110011111110010_000010001101111110011;
        5'd23: o_DATA <= 45'b011001100110011100100111_001001100001110110001;

        5'd24: o_DATA <= 45'b001011101110111110101001_001000000001110101010;
        5'd25: o_DATA <= 45'b001011101110101111000110_000000101101110111000;
        5'd26: o_DATA <= 45'b001011101110101001011001_010001001000110011010;
        5'd27: o_DATA <= 45'b001011101110100000110110_010011000100110010000;
        5'd28: o_DATA <= 45'b001011101110000010110000_001010101001110110001;
        5'd29: o_DATA <= 45'b001011101010010001001111_001010001101110111011;
        5'd30: o_DATA <= 45'b001011101010010001000010_011001000100100000000;
        5'd31: o_DATA <= 45'b001011100010110010001100_000000101001110110000;
    endcase
end

endmodule
