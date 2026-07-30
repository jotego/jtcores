/* verilator lint_off WIDTHEXPAND */
module IKAOPM_noise (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_12,
    input   wire            i_CYCLE_15_31,

    //register data
    input   wire    [4:0]   i_NFRQ,

    //noise attenuation level input for muting(atten max detection)
    input   wire            i_NOISE_ATTENLEVEL,

    //output data
    output  wire    [13:0]  o_ACC_NOISE,
    output  wire            o_LFO_NOISE
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;



///////////////////////////////////////////////////////////
//////  Noise frequency tick generator
////

wire    [4:0]   noise_freqgen_value;
reg             noise_update, noise_update_z;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    noise_update <= (noise_freqgen_value == ~i_NFRQ);
    noise_update_z <= noise_update;
end

primitive_counter #(.WIDTH(5)) u_noise_freqgen (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(i_CYCLE_15_31), .i_LD(1'b0), .i_RST(~mrst_n | (noise_update & i_CYCLE_15_31)),
    .i_D(5'd0), .o_Q(noise_freqgen_value), .o_CO()
);



///////////////////////////////////////////////////////////
//////  LFSR
////

reg     [15:0]  noise_lfsr;
reg             xor_flag;
wire            xor_fdbk = (xor_flag ^ noise_lfsr[2]) | (noise_lfsr == 16'h0000 && xor_flag == 1'b0);
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    noise_lfsr[15] <= !mrst_n ? 1'b0 : 
                                noise_update_z ? xor_fdbk : noise_lfsr[0];
    noise_lfsr[14:0] <= noise_lfsr[15:1];

    xor_flag  <= !mrst_n ? noise_lfsr[0] :
                           noise_update_z ? noise_lfsr[0] : xor_flag;
end

wire            noise_serial = noise_lfsr[1];
assign  o_LFO_NOISE = noise_serial;



///////////////////////////////////////////////////////////
//////  Noise muting detection
////

reg             is_attenlevel_max; //zero detected = attenlevel is not max
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    is_attenlevel_max <= i_CYCLE_12 ? 1'b1 : (i_NOISE_ATTENLEVEL & is_attenlevel_max);
end



///////////////////////////////////////////////////////////
//////  Noise SIPO
////

reg             noise_sign_z, noise_sign_zz;
reg     [8:0]   noise_sipo_sr;

//flags
reg             noise_mute;
reg             noise_sign;
reg             noise_redundant_bit;
reg     [8:0]   noise_parallel;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        noise_sign_z <= noise_sign;
        noise_sign_zz <= noise_sign_z;

        noise_sipo_sr[0] <= noise_sign_zz ^ ~i_NOISE_ATTENLEVEL;
        noise_sipo_sr[8:1] <= noise_sipo_sr[7:0];
    end

    if(!phi1pcen_n) begin
        if(i_CYCLE_12) begin
            noise_mute <= is_attenlevel_max; //latch mute flag
            noise_sign <= noise_serial; //latch new sign bit
            noise_redundant_bit <= noise_sign_z; //latch redundant bits: previous sign bit
            noise_parallel <= noise_sipo_sr; //latch parallel output, discard MSB(really)
        end
    end    
end



///////////////////////////////////////////////////////////
//////  Make output
////

assign  o_ACC_NOISE = noise_mute ? 14'd0 : {{2{noise_redundant_bit}},
                                             noise_parallel,
                                            {3{noise_redundant_bit}}};


endmodule
