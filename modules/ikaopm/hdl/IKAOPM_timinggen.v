/* verilator lint_off WIDTHEXPAND */
module IKAOPM_timinggen #(parameter FULLY_SYNCHRONOUS = 1, parameter FAST_RESET = 0) (
    //chip clock
    input   wire            i_EMUCLK, //emulator master clock

    //chip reset
    input   wire            i_IC_n,
    output  wire            o_MRST_n, //core internal reset

    //clock endables
    input   wire            i_phiM_PCEN_n, //phiM positive edge clock enable(negative logic)
    `ifdef IKAOPM_USER_DEFINED_CLOCK_ENABLES
    input   wire            i_phi1_PCEN_n, //phi1 positive edge clock enable
    input   wire            i_phi1_NCEN_n, //phi1 negative edge clock enable
    `endif

    //phiM/2
    output  wire            o_phi1, //phi1 output
    output  wire            o_phi1_PCEN_n, //positive edge clock enable for emulation
    output  wire            o_phi1_NCEN_n, //negative edge clock enable for emulation

    //SH1 and 2
    output  reg             o_SH1,
    output  reg             o_SH2,

    //timings
    output  reg             o_CYCLE_01,
    output  reg             o_CYCLE_31,

    output  reg             o_CYCLE_12_28,
    output  reg             o_CYCLE_05_21,
    output  reg             o_CYCLE_BYTE,

    output  reg             o_CYCLE_05,
    output  reg             o_CYCLE_10,

    output  reg             o_CYCLE_03,
    output  reg             o_CYCLE_00_16,
    output  reg             o_CYCLE_01_TO_16,

    output  reg             o_CYCLE_04_12_20_28,

    output  reg             o_CYCLE_12,
    output  reg             o_CYCLE_15_31,

    output  reg             o_CYCLE_29,
    output  reg             o_CYCLE_06_22
);

///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1ncen_n = o_phi1_NCEN_n;
wire            mrst_n = o_MRST_n;




///////////////////////////////////////////////////////////
//////  Reset generator
////

reg             ic_n_negedge = 1'b1; //IC_n negedge detector
reg             synced_mrst_n = 1'b0; //synchronized master reset
wire            phi1_init;

generate
if(FAST_RESET == 0) begin : FAST_RESET_0_clock_and_global_rst
    assign  o_MRST_n = synced_mrst_n;
    assign  phi1_init = ic_n_negedge;
end
else begin : FAST_RESET_1_clock_and_global_rst
    assign  o_MRST_n = synced_mrst_n & i_IC_n;
    assign  phi1_init = ic_n_negedge | ~i_IC_n;
end
endgenerate

generate
if(FULLY_SYNCHRONOUS == 0) begin : FULLY_SYNCHRONOUS_0_reset_syncchain
    //2 stage SR for synchronization
    reg     [1:0]   ic_n_internal = 2'b00;
    always @(posedge i_EMUCLK) if(!i_phiM_PCEN_n) begin 
        ic_n_internal[0] <= i_IC_n; 
        ic_n_internal[1] <= ic_n_internal[0]; //shift
    end

    //ICn falling edge detector for phi1 phase initialization
    always @(posedge i_EMUCLK) if(!i_phiM_PCEN_n) begin
        ic_n_negedge <= ~ic_n_internal[0] & ic_n_internal[1];
    end

    //internal master reset
    always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
        synced_mrst_n <= ic_n_internal[0];
    end
end
else begin : FULLY_SYNCHRONOUS_1_reset_syncchain
    //add two stage SR

    //4 stage SR for synchronization
    reg     [3:0]   ic_n_internal = 4'b0000;
    always @(posedge i_EMUCLK) if(!i_phiM_PCEN_n) begin 
        ic_n_internal[0] <= i_IC_n; 
        ic_n_internal[3:1] <= ic_n_internal[2:0]; //shift
    end

    //ICn falling edge detector for phi1 phase initialization
    always @(posedge i_EMUCLK) if(!i_phiM_PCEN_n) begin
        ic_n_negedge <= ~ic_n_internal[2] & ic_n_internal[3];
    end

    //internal master reset
    always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
        synced_mrst_n <= ic_n_internal[2];
    end
end
endgenerate



///////////////////////////////////////////////////////////
//////  phi1 and clock enables generator
////

/*
    CLOCKING INFORMATION(ORIGINAL CHIP)
    
    phiM        _______|¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    ICn         ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

    ICn neg     ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    ICn pos     ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    IC          _________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|__________________________________________________
    IC neg det  _________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________________________________________________________

    phi1        ¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________


    (FPGA)    
    EMUCLK      ¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|
    phiM cen    ¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯
    phiM        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|

    phi1p       ¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________
    phi1n       _______|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯
*/


`ifdef IKAOPM_USER_DEFINED_CLOCK_ENABLES

reg             phi1;
always @(posedge i_EMUCLK) begin
    case({i_phi1_PCEN_n, i_phi1_NCEN_n})
        2'b00: phi1 <= phi1;
        2'b01: phi1 <= 1'b1;
        2'b10: phi1 <= 1'b0;
        2'b11: phi1 <= phi1;
    endcase
end

//phi1 output(for reference)
assign  o_phi1 = phi1;

generate
if(FAST_RESET == 0) begin : FAST_RESET_0_cenout
    //phi1 cen(internal)
    assign  o_phi1_PCEN_n = i_phi1_PCEN_n;
    assign  o_phi1_NCEN_n = i_phi1_NCEN_n;
end
else begin : FAST_RESET_1_cenout
    //phi1 cen(internal)
    assign  o_phi1_PCEN_n = i_phi1_PCEN_n & i_IC_n;
    assign  o_phi1_NCEN_n = i_phi1_NCEN_n & i_IC_n;
end
endgenerate

`else

//actual phi1 output is phi1p(positive), and the inverted phi1 is phi1n(negative)
reg             phi1p, phi1n;
generate
if(FAST_RESET == 0) begin : FAST_RESET_0_phi1gen
    always @(posedge i_EMUCLK) if(!i_phiM_PCEN_n) begin
        if(phi1_init)   begin phi1p <= 1'b1;   phi1n <= 1'b1;  end //reset
        else            begin phi1p <= ~phi1p; phi1n <= phi1p; end //toggle
    end
end
else begin : FAST_RESET_1_phi1gen
    always @(posedge i_EMUCLK) if(!(i_phiM_PCEN_n & i_IC_n)) begin
        if(phi1_init)   begin phi1p <= 1'b1;   phi1n <= 1'b1;  end //reset
        else            begin phi1p <= ~phi1p; phi1n <= phi1p; end //toggle
    end
end
endgenerate

//phi1 output(for reference)
assign  o_phi1 = phi1p;

generate
if(FAST_RESET == 0) begin : FAST_RESET_0_cenout
    //phi1 cen(internal)
    assign  o_phi1_PCEN_n = phi1p | i_phiM_PCEN_n; //ORed signal
    assign  o_phi1_NCEN_n = phi1n | i_phiM_PCEN_n;
end
else begin : FAST_RESET_1_cenout
    //phi1 cen(internal)
    assign  o_phi1_PCEN_n = (phi1p | i_phiM_PCEN_n) & i_IC_n; //ORed signal
    assign  o_phi1_NCEN_n = (phi1n | i_phiM_PCEN_n) & i_IC_n;
end
endgenerate

`endif


///////////////////////////////////////////////////////////
//////  Timing Generator
////

//
//  counter
//

reg     [4:0]   timinggen_cntr = 5'h0;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    if(!mrst_n) begin
        timinggen_cntr <= 5'h0;
    end
    else begin
        if(timinggen_cntr == 5'h1F) timinggen_cntr <= 5'h0;
        else                        timinggen_cntr <= timinggen_cntr + 5'h1;
    end
end



//
//  decoder
//

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    //REG
    o_CYCLE_01          <= timinggen_cntr == 5'd0;
    o_CYCLE_31          <= timinggen_cntr == 5'd30;

    //LFO
    o_CYCLE_12_28 <= (timinggen_cntr == 5'd11) | (timinggen_cntr == 5'd27);
    o_CYCLE_05_21 <= (timinggen_cntr == 5'd4) | (timinggen_cntr == 5'd20);
    o_CYCLE_BYTE  <= (timinggen_cntr[3:1] == 3'b111) |
                     (timinggen_cntr[3:1] == 3'b010) |
                     (timinggen_cntr[3:2] == 2'b00);

    //PG
    o_CYCLE_05          <= timinggen_cntr == 5'd4;
    o_CYCLE_10          <= timinggen_cntr == 5'd9;

    //EG
    o_CYCLE_03          <= timinggen_cntr == 5'd2;
    o_CYCLE_00_16       <= (timinggen_cntr == 5'd31) | (timinggen_cntr == 5'd15);
    o_CYCLE_01_TO_16    <= ~timinggen_cntr[4];

    //OP
    o_CYCLE_04_12_20_28 <= (timinggen_cntr == 5'd3) | (timinggen_cntr == 5'd11) | (timinggen_cntr == 5'd19) | (timinggen_cntr == 5'd27);

    //ACC
    o_CYCLE_29          <= timinggen_cntr == 5'd28;
    o_CYCLE_06_22       <= (timinggen_cntr == 5'd05) | (timinggen_cntr == 5'd21);

    //NOISE
    o_CYCLE_12          <= timinggen_cntr == 5'd11;
    o_CYCLE_15_31       <= (timinggen_cntr == 5'd14) | (timinggen_cntr == 5'd30);
end



///////////////////////////////////////////////////////////
//////  SH1 / SH2
////

//sh1/sh2
wire            sh1 = timinggen_cntr[4:3] == 2'b01; //01XXX
wire            sh2 = timinggen_cntr[4:3] == 2'b11; //11XXX

reg     [4:0]   sh1_sr, sh2_sr;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    //sh1/2 shift register
    sh1_sr[0] <= sh1;
    sh2_sr[0] <= sh2;

    sh1_sr[4:1] <= sh1_sr[3:0];
    sh2_sr[4:1] <= sh2_sr[3:0];

    //sh1/2 output
    o_SH1 <= sh1_sr[4] & mrst_n;
    o_SH2 <= sh2_sr[4] & mrst_n;
end

endmodule
