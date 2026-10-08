/* verilator lint_off WIDTHEXPAND */
module IKAOPM_acc (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_12,
    input   wire            i_CYCLE_29,
    input   wire            i_CYCLE_00_16,
    input   wire            i_CYCLE_06_22,
    input   wire            i_CYCLE_01_TO_16,

    //data
    input   wire            i_NE,
    input   wire    [1:0]   i_RL,

    input   wire            i_ACC_SNDADD,
    input   wire    [13:0]  i_ACC_OPDATA,
    input   wire    [13:0]  i_ACC_NOISE,

    output  reg             o_SO,
    
    output  reg             o_EMU_R_SAMPLE, o_EMU_L_SAMPLE,
    output  reg signed      [15:0]  o_EMU_R_EX, o_EMU_L_EX,
    output  reg signed      [15:0]  o_EMU_R, o_EMU_L
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;



///////////////////////////////////////////////////////////
//////  Cycle number
////

//additional cycle bits
reg             cycle_13, cycle_01_17, cycle_02_to_17;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cycle_13 <= i_CYCLE_12;
    cycle_01_17 <= i_CYCLE_00_16;
    cycle_02_to_17 <= i_CYCLE_01_TO_16;
end



///////////////////////////////////////////////////////////
//////  Sound input MUX / RL acc enable
////

//noise data will be launched at master cycle 12
reg     [13:0]  sound_inlatch;
reg             r_add, l_add;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    sound_inlatch <= (i_NE & i_CYCLE_12) ? i_ACC_NOISE : i_ACC_OPDATA;

    r_add <= i_ACC_SNDADD & i_RL[1];
    l_add <= i_ACC_SNDADD & i_RL[0];
end



///////////////////////////////////////////////////////////
//////  R/L channel accmulators
////

reg     [17:0]  r_accumulator, l_accumulator;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(!mrst_n) begin
        r_accumulator <= 18'd0; //original chip doesn't have this reset
        l_accumulator <= 18'd0;
    end
    else begin
        if(cycle_13)   r_accumulator <= r_add ? {{4{sound_inlatch[13]}}, sound_inlatch}                 : 17'd0;         //reset
        else           r_accumulator <= r_add ? {{4{sound_inlatch[13]}}, sound_inlatch} + r_accumulator : r_accumulator; //accumulation

        if(i_CYCLE_29) l_accumulator <= l_add ? {{4{sound_inlatch[13]}}, sound_inlatch}                 : 17'd0;         //reset
        else           l_accumulator <= l_add ? {{4{sound_inlatch[13]}}, sound_inlatch} + l_accumulator : l_accumulator; //accumulation
    end
end



///////////////////////////////////////////////////////////
//////  R/L PISO register
////

/*
    Sign bit is inverted in this stage.
    11111...(positive max)
    10000...(positive min)
    01111...(negative min)
    00000...(negative max)
*/

reg     [15:0]  mcyc14_r_piso, mcyc30_l_piso;
reg     [2:0]   mcyc14_r_saturation_ctrl, mcyc30_l_saturation_ctrl;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(cycle_13) begin
        mcyc14_r_piso <= {~r_accumulator[17], r_accumulator[14:0]}; //FLIP THE SIGN BIT!!
        mcyc14_r_saturation_ctrl <= r_accumulator[17:15];
    end
    else begin
        mcyc14_r_piso[14:0] <= mcyc14_r_piso[15:1]; //shift
    end

    if(i_CYCLE_29) begin
        mcyc30_l_piso <= {~l_accumulator[17], l_accumulator[14:0]}; //FLIP THE SIGN BIT!!
        mcyc30_l_saturation_ctrl <= l_accumulator[17:15];
    end
    else begin
        mcyc30_l_piso[14:0] <= mcyc30_l_piso[15:1]; //shift
    end
end



///////////////////////////////////////////////////////////
//////  Parallel output control
////

localparam  SAMPLE_STROBE_LENGTH = 1; //adjust this value to stretch the strobe width
reg     [SAMPLE_STROBE_LENGTH+1:0]   r_sample_det, l_sample_det;
always @(posedge i_EMUCLK) begin
    if(!i_MRST_n) begin
        r_sample_det[0] <= 1'b0;
        l_sample_det[0] <= 1'b0;
    end
    else begin
        r_sample_det[0] <= cycle_13;
        l_sample_det[0] <= i_CYCLE_29;
    end

    r_sample_det[SAMPLE_STROBE_LENGTH+1:1] <= r_sample_det[SAMPLE_STROBE_LENGTH:0];
    l_sample_det[SAMPLE_STROBE_LENGTH+1:1] <= l_sample_det[SAMPLE_STROBE_LENGTH:0];

    //negative edge detector + pulse stretcher
    o_EMU_R_SAMPLE <= {|{r_sample_det[SAMPLE_STROBE_LENGTH+1:2]}, r_sample_det[1]} == 2'b10;
    o_EMU_L_SAMPLE <= {|{l_sample_det[SAMPLE_STROBE_LENGTH+1:2]}, l_sample_det[1]} == 2'b10;
end


reg signed  [15:0]  r_parallel, l_parallel, r_parallel_extended, l_parallel_extended; //parallel output intermediate storage
reg         [2:0]   r_parallel_saturation_ctrl, l_parallel_saturation_ctrl; //parallel output saturation control
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(!i_MRST_n) begin
        r_parallel_saturation_ctrl <= 3'b000;
        r_parallel_extended <= 16'sd0;
        r_parallel <= 16'sd0;

        l_parallel_saturation_ctrl <= 3'b000;
        l_parallel_extended <= 16'sd0;
        l_parallel <= 16'sd0;
    end
    else begin
        if(cycle_13) begin
            r_parallel_saturation_ctrl <= r_accumulator[17:15];
            r_parallel_extended <= {r_accumulator[17], r_accumulator[14:0]}; //extended output, sign bit + least important 15 bits

            casez(r_accumulator[14:9] ^ {6{r_accumulator[17]}})
                6'b000000: r_parallel <= {r_accumulator[17], r_accumulator[14:6], r_accumulator[5:0]}; //small number
                6'b000001: r_parallel <= {r_accumulator[17], r_accumulator[14:6], r_accumulator[17] ? r_accumulator[5:0] | 6'b000001 : r_accumulator[5:0] & 6'b111110};
                6'b00001?: r_parallel <= {r_accumulator[17], r_accumulator[14:6], r_accumulator[17] ? r_accumulator[5:0] | 6'b000011 : r_accumulator[5:0] & 6'b111100};
                6'b0001??: r_parallel <= {r_accumulator[17], r_accumulator[14:6], r_accumulator[17] ? r_accumulator[5:0] | 6'b000111 : r_accumulator[5:0] & 6'b111000};
                6'b001???: r_parallel <= {r_accumulator[17], r_accumulator[14:6], r_accumulator[17] ? r_accumulator[5:0] | 6'b001111 : r_accumulator[5:0] & 6'b110000};
                6'b01????: r_parallel <= {r_accumulator[17], r_accumulator[14:6], r_accumulator[17] ? r_accumulator[5:0] | 6'b011111 : r_accumulator[5:0] & 6'b100000};
                6'b1?????: r_parallel <= {r_accumulator[17], r_accumulator[14:6], r_accumulator[17] ? r_accumulator[5:0] | 6'b111111 : r_accumulator[5:0] & 6'b000000}; //large number
                
                default:   r_parallel <= {r_accumulator[17], r_accumulator[14:6], r_accumulator[5:0]};
            endcase
        end
        if(i_CYCLE_29) begin
            l_parallel_saturation_ctrl <= l_accumulator[17:15];
            l_parallel_extended <= {l_accumulator[17], l_accumulator[14:0]}; //extended output, sign bit + least important 15 bits

            casez(l_accumulator[14:9] ^ {6{l_accumulator[17]}})
                6'b000000: l_parallel <= {l_accumulator[17], l_accumulator[14:6], l_accumulator[5:0]}; //small number
                6'b000001: l_parallel <= {l_accumulator[17], l_accumulator[14:6], l_accumulator[17] ? l_accumulator[5:0] | 6'b000001 : l_accumulator[5:0] & 6'b111110};
                6'b00001?: l_parallel <= {l_accumulator[17], l_accumulator[14:6], l_accumulator[17] ? l_accumulator[5:0] | 6'b000011 : l_accumulator[5:0] & 6'b111100};
                6'b0001??: l_parallel <= {l_accumulator[17], l_accumulator[14:6], l_accumulator[17] ? l_accumulator[5:0] | 6'b000111 : l_accumulator[5:0] & 6'b111000};
                6'b001???: l_parallel <= {l_accumulator[17], l_accumulator[14:6], l_accumulator[17] ? l_accumulator[5:0] | 6'b001111 : l_accumulator[5:0] & 6'b110000};
                6'b01????: l_parallel <= {l_accumulator[17], l_accumulator[14:6], l_accumulator[17] ? l_accumulator[5:0] | 6'b011111 : l_accumulator[5:0] & 6'b100000};
                6'b1?????: l_parallel <= {l_accumulator[17], l_accumulator[14:6], l_accumulator[17] ? l_accumulator[5:0] | 6'b111111 : l_accumulator[5:0] & 6'b000000}; //large number
                
                default:   l_parallel <= {l_accumulator[17], l_accumulator[14:6], l_accumulator[5:0]};
            endcase
        end
    end
end

always @(posedge i_EMUCLK) begin
    if(!i_MRST_n) begin
        o_EMU_R <= 16'sd0;
        o_EMU_R_EX <= 16'sd0;
        o_EMU_L <= 16'sd0;
        o_EMU_L_EX <= 16'sd0;
    end
    else begin
        case(r_parallel_saturation_ctrl)
            3'b000: begin o_EMU_R <= r_parallel; o_EMU_R_EX <= r_parallel_extended; end
            3'b001: begin o_EMU_R <= 16'h7FFF;   o_EMU_R_EX <= 16'h7FFF; end //saturated to positive maximum
            3'b010: begin o_EMU_R <= 16'h7FFF;   o_EMU_R_EX <= 16'h7FFF; end
            3'b011: begin o_EMU_R <= 16'h7FFF;   o_EMU_R_EX <= 16'h7FFF; end
            3'b100: begin o_EMU_R <= 16'h8000;   o_EMU_R_EX <= 16'h8000; end //saturated to negative maximum
            3'b101: begin o_EMU_R <= 16'h8000;   o_EMU_R_EX <= 16'h8000; end
            3'b110: begin o_EMU_R <= 16'h8000;   o_EMU_R_EX <= 16'h8000; end
            3'b111: begin o_EMU_R <= r_parallel; o_EMU_R_EX <= r_parallel_extended; end
        endcase

        case(l_parallel_saturation_ctrl)
            3'b000: begin o_EMU_L <= l_parallel; o_EMU_L_EX <= l_parallel_extended; end
            3'b001: begin o_EMU_L <= 16'h7FFF;   o_EMU_L_EX <= 16'h7FFF; end //saturated to positive maximum
            3'b010: begin o_EMU_L <= 16'h7FFF;   o_EMU_L_EX <= 16'h7FFF; end
            3'b011: begin o_EMU_L <= 16'h7FFF;   o_EMU_L_EX <= 16'h7FFF; end
            3'b100: begin o_EMU_L <= 16'h8000;   o_EMU_L_EX <= 16'h8000; end //saturated to negative maximum
            3'b101: begin o_EMU_L <= 16'h8000;   o_EMU_L_EX <= 16'h8000; end
            3'b110: begin o_EMU_L <= 16'h8000;   o_EMU_L_EX <= 16'h8000; end
            3'b111: begin o_EMU_L <= l_parallel; o_EMU_L_EX <= l_parallel_extended; end
        endcase
    end
end



///////////////////////////////////////////////////////////
//////  R/L Saturation control
////

reg             mcyc15_r_stream, mcyc31_l_stream;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    case(mcyc14_r_saturation_ctrl)
        3'b000: mcyc15_r_stream <= mcyc14_r_piso[0];
        3'b001: mcyc15_r_stream <= 1'b1; //saturated to positive maximum
        3'b010: mcyc15_r_stream <= 1'b1;
        3'b011: mcyc15_r_stream <= 1'b1;
        3'b100: mcyc15_r_stream <= 1'b0; //saturated to negative maximum
        3'b101: mcyc15_r_stream <= 1'b0;
        3'b110: mcyc15_r_stream <= 1'b0;
        3'b111: mcyc15_r_stream <= mcyc14_r_piso[0];
    endcase

    case(mcyc30_l_saturation_ctrl)
        3'b000: mcyc31_l_stream <= mcyc30_l_piso[0];
        3'b001: mcyc31_l_stream <= 1'b1; //saturated to positive maximum
        3'b010: mcyc31_l_stream <= 1'b1;
        3'b011: mcyc31_l_stream <= 1'b1;
        3'b100: mcyc31_l_stream <= 1'b0; //saturated to negative maximum
        3'b101: mcyc31_l_stream <= 1'b0;
        3'b110: mcyc31_l_stream <= 1'b0;
        3'b111: mcyc31_l_stream <= mcyc30_l_piso[0];
    endcase
end



///////////////////////////////////////////////////////////
//////  Delays
////

reg             mcyc16_r_stream_z, mcyc17_r_stream_zz, mcyc18_r_stream_zzz;
reg             mcyc00_l_stream_z, mcyc01_l_stream_zz, mcyc02_l_stream_zzz;

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    mcyc16_r_stream_z <= mcyc15_r_stream;
    mcyc00_l_stream_z <= mcyc31_l_stream;
    mcyc17_r_stream_zz <= mcyc16_r_stream_z;
    mcyc01_l_stream_zz <= mcyc00_l_stream_z;
    mcyc18_r_stream_zzz <= mcyc17_r_stream_zz;
    mcyc02_l_stream_zzz <= mcyc01_l_stream_zz;
end



///////////////////////////////////////////////////////////
//////  SIPO/SO register
////

wire            sound_data_lookaround_register_input_stream = cycle_02_to_17 ? mcyc02_l_stream_zzz : mcyc18_r_stream_zzz;
reg     [20:0]  sound_data_lookaround_register;
reg     [6:0]   sound_data_bit_15_9;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    //The LSB of serial sound data is placed on the MSB of lookaround register if(master cycle == 17 || 1). It flows in from the LSB.
    sound_data_lookaround_register[20] <= sound_data_lookaround_register_input_stream; //sound data LSB is latched at (master cycle == 18)
    sound_data_lookaround_register[19:0] <= sound_data_lookaround_register[20:1];

    if(cycle_01_17) sound_data_bit_15_9 <= {sound_data_lookaround_register_input_stream, sound_data_lookaround_register[20:15]};
end



///////////////////////////////////////////////////////////
//////  Output MUX
////

//original chip used shift register to select bits
reg     [3:0]   outmux_sel_cntr;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(i_CYCLE_06_22) outmux_sel_cntr <= 4'd1;
    else outmux_sel_cntr <= (outmux_sel_cntr == 4'd15) ? 4'd0 : outmux_sel_cntr + 4'd1;
end

//sound data magnitude
/*
    Invert the upper bits when the number is negative.
    11111...(positive max)
    10000...(positive min)
    00000...(negative min)
    01111...(negative max)
*/
wire    [5:0]   sound_data_magnitude = sound_data_bit_15_9[6] ? sound_data_bit_15_9[5:0] : ~sound_data_bit_15_9[5:0];
reg             sound_data_sign;
reg     [2:0]   sound_data_shift_amount;
reg     [4:0]   sound_data_output_tap;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(i_CYCLE_06_22) begin
        sound_data_sign <= sound_data_bit_15_9[6];

        casez(sound_data_magnitude)
            6'b000000: begin sound_data_output_tap <= 5'd0; sound_data_shift_amount <= 3'd1; end //small number
            6'b000001: begin sound_data_output_tap <= 5'd1; sound_data_shift_amount <= 3'd2; end
            6'b00001?: begin sound_data_output_tap <= 5'd2; sound_data_shift_amount <= 3'd3; end
            6'b0001??: begin sound_data_output_tap <= 5'd3; sound_data_shift_amount <= 3'd4; end
            6'b001???: begin sound_data_output_tap <= 5'd4; sound_data_shift_amount <= 3'd5; end
            6'b01????: begin sound_data_output_tap <= 5'd5; sound_data_shift_amount <= 3'd6; end
            6'b1?????: begin sound_data_output_tap <= 5'd6; sound_data_shift_amount <= 3'd7; end //large number
            
            default:   begin sound_data_output_tap <= 5'd0; sound_data_shift_amount <= 3'd1; end
        endcase
    end
end

reg             floating_sound_data;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(outmux_sel_cntr >= 4'd1 && outmux_sel_cntr < 4'd10)  floating_sound_data <= sound_data_lookaround_register[sound_data_output_tap];
    else if(outmux_sel_cntr == 4'd10)                       floating_sound_data <= sound_data_sign;
    else if(outmux_sel_cntr == 4'd11)                       floating_sound_data <= sound_data_shift_amount[0];
    else if(outmux_sel_cntr == 4'd12)                       floating_sound_data <= sound_data_shift_amount[1];
    else if(outmux_sel_cntr == 4'd13)                       floating_sound_data <= sound_data_shift_amount[2];
    else                                                    floating_sound_data <= sound_data_lookaround_register[sound_data_output_tap];

    o_SO <= floating_sound_data;
end

endmodule
