/* verilator lint_off WIDTHEXPAND */
module IKAOPM_lfo (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_12_28,
    input   wire            i_CYCLE_05_21,
    input   wire            i_CYCLE_BYTE,

    //register data
    input   wire    [7:0]   i_LFRQ, //LFO frequency
    input   wire    [6:0]   i_AMD,  //amplitude modulation depth
    input   wire    [6:0]   i_PMD,  //phase modulation depth
    input   wire    [1:0]   i_W,    //waveform select
    input   wire            i_TEST_D1, //test register
    input   wire            i_TEST_D2,
    input   wire            i_TEST_D3,

    //control signal
    input   wire            i_LFRQ_UPDATE,

    //noise
    input   wire            i_LFO_NOISE,

    output  wire    [7:0]   o_LFP,
    output  wire    [7:0]   o_LFA,

    output  wire            o_REG_LFO_CLK
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
reg             cycle_06_22, cycle_13_29, cycle_14_30, cycle_15_31;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cycle_06_22 <= i_CYCLE_05_21;

    cycle_13_29 <= i_CYCLE_12_28;
    cycle_14_30 <= cycle_13_29;
    cycle_15_31 <= cycle_14_30;
end

`ifdef IKAOPM_DEBUG
reg             debug_cycle_07_23;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    debug_cycle_07_23 <= cycle_06_22;
end
`endif



///////////////////////////////////////////////////////////
//////  Prescaler
////

//counter
wire    [3:0]   prescaler_value;
wire            prescaler_cout;
primitive_counter #(.WIDTH(4)) u_lfo_prescaler (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(i_CYCLE_12_28), .i_LD(1'b0), .i_RST(~mrst_n),
    .i_D(4'd0), .o_Q(prescaler_value), .o_CO(prescaler_cout)
);

//cycle 2 / cout_z
reg             prescaler_cycle_2, prescaler_cout_z;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) prescaler_cycle_2 <= prescaler_value == 4'd2;

    if(!phi1ncen_n) prescaler_cout_z <= prescaler_cout;
end



///////////////////////////////////////////////////////////
//////  LFO LUT and output latch
////

/*
    pre-initialized LFO LUT. The bit order of the original chip is:
      (LEFT) D1 - D7 / D14 - D8 (RIGHT)
    D0 is controlled by row F enable signal, so the table below contains the precalculated values

    lfo dout latch:
    the original one uses different edges due to carry delay of the counter cells
    so the counter for MSBs is delayed by a half phi1.
*/

reg     [14:0]  lfolut_dout;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    case(i_LFRQ[7:4])
        4'hF: lfolut_dout <= 15'h7FFF;
        4'hE: lfolut_dout <= 15'h7FFE;
        4'hD: lfolut_dout <= 15'h7FFC;
        4'hC: lfolut_dout <= 15'h7FF8;
        4'hB: lfolut_dout <= 15'h7FF0;
        4'hA: lfolut_dout <= 15'h7FE0;
        4'h9: lfolut_dout <= 15'h7FC0;
        4'h8: lfolut_dout <= 15'h7F80;
        4'h7: lfolut_dout <= 15'h7F00;
        4'h6: lfolut_dout <= 15'h7E00;
        4'h5: lfolut_dout <= 15'h7C00;
        4'h4: lfolut_dout <= 15'h7800;
        4'h3: lfolut_dout <= 15'h7000;
        4'h2: lfolut_dout <= 15'h6000;
        4'h1: lfolut_dout <= 15'h4000;
        4'h0: lfolut_dout <= 15'h1000;
    endcase
end



///////////////////////////////////////////////////////////
//////  LFRQ counter low bits
////

//locntr cnt up signal
reg             locntr_cnt;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    locntr_cnt <= prescaler_cout_z | i_TEST_D3; //de morgan
end

//locntr preload signal
wire            locntr_cout;
reg             locntr_cout_z, freq_update;
reg             locntr_ld;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    locntr_cout_z <= locntr_cout;
    freq_update <= i_LFRQ_UPDATE;

    locntr_ld <= (locntr_cout_z | freq_update);
end

//define locntr
primitive_counter #(.WIDTH(15)) u_lfo_locntr (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(locntr_cnt), .i_LD(locntr_ld), .i_RST(~mrst_n),
    .i_D(lfolut_dout), .o_Q(), .o_CO(locntr_cout)
);



///////////////////////////////////////////////////////////
//////  LFRQ counter high bits
////

//hicntr cout delay
reg             locntr_cout_step1, locntr_cout_step2;
always @(posedge i_EMUCLK) begin
    if(!phi1pcen_n) if(cycle_15_31) locntr_cout_step1 <= locntr_cout_z;

    if(!phi1pcen_n) if(i_CYCLE_05_21) locntr_cout_step2 <= locntr_cout_step1; //use positive edge
end

//hicntr cnt up and output decoder enable
reg             hicntr_cnt;
wire            hicntr_decode_en = (cycle_13_29 & locntr_cout_step2); //de morgan
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    hicntr_cnt <= hicntr_decode_en;
end

//counter
wire    [3:0]  hicntr_value;
primitive_counter #(.WIDTH(4)) u_lfo_hicntr (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(hicntr_cnt), .i_LD(1'b0), .i_RST(~mrst_n),
    .i_D(4'd0), .o_Q(hicntr_value), .o_CO()
);

//hicntr complete flag
reg             hicntr_complete; //use positive edge
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(hicntr_decode_en) begin //decode locntr value only when decode_en == 1
        casez(hicntr_value)
            4'b???0: hicntr_complete <= i_LFRQ[3];
            4'b??01: hicntr_complete <= i_LFRQ[2];
            4'b?011: hicntr_complete <= i_LFRQ[1];
            4'b0111: hicntr_complete <= i_LFRQ[0];
            
            default: hicntr_complete <= 1'b0;
        endcase
    end
    else hicntr_complete <= 1'b0; //disable
end



///////////////////////////////////////////////////////////
//////  LFO clock generation
////

reg             lfo_clk;
assign  o_REG_LFO_CLK = lfo_clk;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    lfo_clk <= |{locntr_cout, hicntr_complete, i_TEST_D2};
end



///////////////////////////////////////////////////////////
//////  latched LFO clock
////

//The original one used dynamic D-latch to latch lfo_clk
//I reused the signal above to eliminate a latch.
reg             lfo_clk_latched = 1'b0; //dynamic d latch
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(cycle_14_30) lfo_clk_latched <= |{locntr_cout, hicntr_complete, i_TEST_D2};
end



///////////////////////////////////////////////////////////
//////  waveform decoder
////

reg     [1:0]   wfsel;
wire            wfsel_noise = (wfsel == 2'd3);
wire            wfsel_tri   = (wfsel == 2'd2);
//wire            wfsel_sq    = (wfsel == 2'd1);
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    wfsel <= i_W;
end



///////////////////////////////////////////////////////////
//////  LFO phase accumulator
////

//test bit 1 latch
reg             tst_bit1_latched;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    tst_bit1_latched <= i_TEST_D1;
end

//phase accumulator
reg     [15:0]  phase_acc; //phase accumulator shift register
wire            phase_acc_lsb = phase_acc[0];

//full adder
wire    [1:0]   phase_acc_fa;
reg             phase_acc_fa_prev_carry = 1'b0;
always @(posedge i_EMUCLK or negedge mrst_n) begin //async reset
    if(!mrst_n) phase_acc_fa_prev_carry <= 1'b0;
    else begin
        if(!phi1ncen_n) phase_acc_fa_prev_carry <= phase_acc_fa[1]; //store previous carry(serial full adder)
    end
end

//tri = enable / square, saw, noise = disable
wire            phase_acc_fa_a   =  &{cycle_15_31, lfo_clk, ~wfsel_noise} &
                                    wfsel_tri;

//tri, square, saw = enable / noise = temporarily disable 
wire            phase_acc_fa_b   =  mrst_n &
                                   ~tst_bit1_latched &
                                    phase_acc_lsb &
                                   ~(lfo_clk_latched & wfsel_noise);

//tri, square, saw = enable / noise = disable
wire            phase_acc_fa_cin = ~(|{cycle_15_31, ~phase_acc_fa_prev_carry, wfsel_noise} &
                                     ~&{cycle_15_31, lfo_clk, ~wfsel_noise});

assign  phase_acc_fa = phase_acc_fa_a + phase_acc_fa_b + phase_acc_fa_cin;


//noise input
reg             noise_input_z, noise_stream;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    noise_input_z <= i_LFO_NOISE;
    noise_stream <= lfo_clk_latched & noise_input_z; //de morgan
end

//phase accumulator input
wire            phase_acc_input = phase_acc_fa[0] | (wfsel_noise & noise_stream);

//shift accumulator
always @(posedge i_EMUCLK or negedge mrst_n) begin //async reset
    if(!mrst_n) phase_acc <= 16'h0;
    else begin
        if(!phi1ncen_n) begin
            phase_acc[15] <= phase_acc_input;
            phase_acc[14:0] <= phase_acc[15:1];
        end
    end
end

//for debug
`ifdef IKAOPM_DEBUG
reg     [15:0]      debug_phase_acc;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(cycle_15_31) debug_phase_acc <= phase_acc;
end
`endif


///////////////////////////////////////////////////////////
//////  Bit select counter for base value multiply
////

//define counter
wire    [3:0]   multiplier_bitselcntr_value;
primitive_counter #(.WIDTH(4)) u_lfo_multiplier_bitselcntr (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(cycle_14_30), .i_LD(1'b0), .i_RST(prescaler_cycle_2 & i_CYCLE_12_28),
    .i_D(4'd0), .o_Q(multiplier_bitselcntr_value), .o_CO()
);

//this counter output value selects AMD/PMD bit
reg     [2:0]   multiplier_bitsel;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    multiplier_bitsel <= multiplier_bitselcntr_value[2:0]; //store value at negative edge
end

//timings/control
wire            a_np_sel = ~multiplier_bitselcntr_value[3]; //AMD/PMD mux select
wire            multiplier_bitselcntr_cycle_0_8 = multiplier_bitselcntr_value == 4'd0 | multiplier_bitselcntr_value == 4'd8;
wire            multiplier_bitsel_0 = multiplier_bitsel == 3'd0;
wire            multiplier_bitsel_7 = multiplier_bitsel == 3'd7;



///////////////////////////////////////////////////////////
//////  Sigh bit latch
////

//triangle/sawtooth sign bit latch
/*
    phi1    |_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯
            |----(14_30)----|----(15_31)----|----(0_16)----|

    d valid <--------------> <-------------> <------------->
    0_8     ________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    latchen ________________|¯¯¯¯¯¯¯|_______________________

    dff                             ^ <-- sample here     
*/

reg             wf_tri_sign, wf_saw_sign;
always @(posedge i_EMUCLK) if(!phi1pcen_n) begin
    if(cycle_15_31 & multiplier_bitselcntr_cycle_0_8) begin
        wf_tri_sign <= phase_acc[8];
        wf_saw_sign <= phase_acc[7];
    end
end



///////////////////////////////////////////////////////////
//////  Oscillator base value generator
////

//amd/pmd select latch
reg             a_np_sel_latched;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    a_np_sel_latched <= a_np_sel;
end

//base value stream, behavioral implementation
//              waveform type                           (             AM            ) : (             PM             )
wire            noise_value_stream = a_np_sel_latched ? phase_acc_fa_b ^ 1'b1         : (phase_acc_fa_b ^ wf_saw_sign);
wire            tri_value_stream   = a_np_sel_latched ? phase_acc_fa_b ^ ~wf_tri_sign : (phase_acc_fa_b ^ wf_saw_sign);
wire            sq_value_stream    = a_np_sel_latched ?         ~wf_saw_sign          :          cycle_06_22          ;
wire            saw_value_stream   = a_np_sel_latched ? phase_acc_fa_b ^ 1'b1         : (phase_acc_fa_b ^ wf_saw_sign);

//input selector
reg             base_value_input;
always @(*) begin
    if(i_CYCLE_BYTE) begin
        case(wfsel)
            2'd3: base_value_input = noise_value_stream;
            2'd2: base_value_input = tri_value_stream; //gawr gura
            2'd1: base_value_input = sq_value_stream;
            2'd0: base_value_input = saw_value_stream;
        endcase
    end
    else base_value_input = 1'b0;
end

//base value shift register
reg     [6:0]   base_value_sr;
always @(posedge i_EMUCLK or negedge mrst_n) begin
    if(!mrst_n) base_value_sr <= 7'h00;
    else begin
        if(!phi1ncen_n) begin
            base_value_sr[6] <= base_value_input;
            base_value_sr[5:0] <= base_value_sr[6:1];
        end
    end
end

//debug
`ifdef IKAOPM_DEBUG
reg     [6:0]   debug_base_value_am, debug_base_value_pm;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(debug_cycle_07_23) begin
        if(a_np_sel_latched) debug_base_value_am <= base_value_sr;
        else debug_base_value_pm <= base_value_sr;
    end
end
`endif



///////////////////////////////////////////////////////////
//////  Volume multiplier
////

/*
                         TAP
                                MSB 6   5   4   3   2   1   0 LSB

    Base value shift register       0   1   1   0   1   0   1

    Volume register(AMD/PMD)        1   0   0   1   1   0   0

    1. pick volume_reg[6] and do AND with the base value[6:0], add serially, from the LSB
    -> 0110101

    2. pick volume reg[5] and do AND with the base value {1'b0, value[6:1]}, add serially, from the LSB
    -> 0000000

    3. pick volume reg[4] and do AND with the base value {2'b00, value[6:2]}, add serially, from the LSB
    -> 0000000

    ...repeat for all bits of AMD/PMD

    now the process above can be expressed like below
        0110101
        0000000
        0000000
        0000110
        0000011
        0000000
        0000000 +
    =   0111110       ====> this is the final value calculated

    Volume format X.XXXXXX fixed point.
    AMD/PMD bit 6 is decimal part, and bit 5 to 0 is fractional part. Step width 0.015625.
*/

//AMD/PMD mux
reg     [6:0]   ap_muxed;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    ap_muxed <= a_np_sel ? i_AMD : i_PMD;
end

//bit selector
reg             multiplier_fa_b;
always @(*) begin
    case(multiplier_bitsel)
        3'b000: multiplier_fa_b = base_value_sr[0] & ap_muxed[6];
        3'b001: multiplier_fa_b = base_value_sr[1] & ap_muxed[5];
        3'b010: multiplier_fa_b = base_value_sr[2] & ap_muxed[4];
        3'b011: multiplier_fa_b = base_value_sr[3] & ap_muxed[3];
        3'b100: multiplier_fa_b = base_value_sr[4] & ap_muxed[2];
        3'b101: multiplier_fa_b = base_value_sr[5] & ap_muxed[1];
        3'b110: multiplier_fa_b = base_value_sr[6] & ap_muxed[0];
        3'b111: multiplier_fa_b = 1'b0;
    endcase 
end

//multiplier
wire    [1:0]   multiplier_fa;
reg     [15:0]  multiplier_sr = 16'h0;

always @(posedge i_EMUCLK or negedge mrst_n) begin
    if(!mrst_n) multiplier_sr <= 16'h0; //reset
    else begin
        if(!phi1ncen_n) begin
            multiplier_sr[15] <= multiplier_fa[0];
            multiplier_sr[14:0] <= multiplier_sr[15:1];
        end
    end
end

reg             multiplier_prev_carry = 1'b0;
always @(posedge i_EMUCLK or negedge mrst_n) begin
    if(!mrst_n) multiplier_prev_carry <= 1'b0; //reset
    else begin
        if(!phi1ncen_n) multiplier_prev_carry <= multiplier_fa[1];
    end
end

wire            multiplier_fa_a = ~(~multiplier_sr[0] | multiplier_bitsel_0);
wire            multiplier_fa_cin = multiplier_prev_carry & ~cycle_15_31;

assign  multiplier_fa = multiplier_fa_a + multiplier_fa_b + multiplier_fa_cin;



///////////////////////////////////////////////////////////
//////  LFA/LFP latch
////

//LFA LFP register load
wire            lfa_reg_ld = &{cycle_15_31, multiplier_bitsel_7, a_np_sel};
wire            lfp_reg_ld = &{cycle_15_31, multiplier_bitsel_7, ~a_np_sel};

//LFA LFP register
reg     [7:0]   lfa_reg, lfp_reg;
assign  o_LFA = lfa_reg;
assign  o_LFP = lfp_reg;

//LFP sign/value control
wire            pmd_zero = i_PMD == 7'h00;
wire            lfp_sign_ctrl = wfsel_tri ? wf_tri_sign : wf_saw_sign; //AOI

//note that LFA is 8-bit unsigned, LFP is 8-bit sign(1 = negative) and magnitude output
always @(posedge i_EMUCLK) begin
    //negative edge
    if(!phi1ncen_n) begin
        if(!mrst_n) lfa_reg <= 8'd0; 
        else begin
            if(lfa_reg_ld) lfa_reg <= multiplier_sr[15:8];
        end
    end

    //positive edge
    if(!phi1pcen_n) begin
        if(!mrst_n) lfp_reg <= 8'd0;
        else begin
            if(lfp_reg_ld) lfp_reg <= (pmd_zero == 1'b1) ? 8'h00 : {~(multiplier_sr[15] ^ ~lfp_sign_ctrl), multiplier_sr[14:8]};
        end
    end
end

//lfp debug(2's complement)
`ifdef IKAOPM_DEBUG
reg     [7:0]   debug_lfp_reg_pitchmod, debug_lfa_reg_attenlevel;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) 
        if(lfa_reg_ld) begin 
            debug_lfa_reg_attenlevel <= multiplier_sr[15:8]; 
        end
    if(!phi1pcen_n) begin
        if(lfp_reg_ld) 
            debug_lfp_reg_pitchmod <= (pmd_zero == 1'b1) ? 8'h80 : 
                                      (~(multiplier_sr[15] ^ ~lfp_sign_ctrl) == 1'b1) ? (~multiplier_sr[14:8] + 7'h1) : multiplier_sr[14:8];
    end
end
`endif


endmodule
