/* verilator lint_off WIDTHEXPAND */
module IKAOPM_reg #(parameter USE_BRAM_FOR_D32REG = 0, parameter FULLY_SYNCHRONOUS = 1) (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_01,
    input   wire            i_CYCLE_31,
    
    //control/address
    input   wire            i_CS_n,
    input   wire            i_RD_n,
    input   wire            i_WR_n,
    input   wire            i_A0,

    //bus data io
    input   wire    [7:0]   i_D,
    output  wire    [7:0]   o_D,   
    output  wire            o_D_OE,  //output driver enable

    //timer input
    input   wire            i_TIMERA_OVFL,
    input   wire            i_TIMERA_FLAG,
    input   wire            i_TIMERB_FLAG,

    //register output
    output  reg     [7:0]   o_TEST,     //0x01      TEST register

    output  reg             o_CT1,
    output  reg             o_CT2,

    output  reg             o_NE,       //0x0F[7]   Noise Enable
    output  reg     [4:0]   o_NFRQ,     //0x0F[4:0] Noise Frequency

    output  reg     [7:0]   o_CLKA1,        //0x10      Timer A D[9:2]
    output  reg     [1:0]   o_CLKA2,        //0x11      Timer A D[1:0]
    output  reg     [7:0]   o_CLKB,         //0x12      Timer B
    output  wire            o_TIMERA_FRST,  //0x14      Timer Control
    output  wire            o_TIMERB_FRST,  //          |
    output  reg             o_TIMERA_RUN,   //          |
    output  reg             o_TIMERB_RUN,   //          |
    output  reg             o_TIMERA_IRQ_EN,//          |
    output  reg             o_TIMERB_IRQ_EN,//          |

    output  reg     [7:0]   o_LFRQ,     //0x18      LFO frequency
    output  reg     [6:0]   o_PMD,      //0x19[6:0] D[7] == 1
    output  reg     [6:0]   o_AMD,      //0x19[6:0] D[7] == 0
    output  reg     [1:0]   o_W,        //0x1B[1:0] Waveform type
    output  wire            o_LFRQ_UPDATE,

    //PG
    output  wire    [6:0]   o_KC, 
    output  wire    [5:0]   o_KF, 
    output  wire    [2:0]   o_PMS,
    output  wire    [1:0]   o_DT2,
    output  wire    [2:0]   o_DT1,
    output  wire    [3:0]   o_MUL,

    //EG
    output  wire            o_KON,
    output  wire    [1:0]   o_KS,
    output  wire    [4:0]   o_AR,
    output  wire    [4:0]   o_D1R,
    output  wire    [4:0]   o_D2R,
    output  wire    [3:0]   o_RR,
    output  wire    [3:0]   o_D1L,
    output  wire    [6:0]   o_TL,
    output  wire    [1:0]   o_AMS,

    //OP
    output  wire    [2:0]   o_ALG,
    output  wire    [2:0]   o_FL,

    //ACC
    output  wire    [1:0]   o_RL,

    //input data for LSI test via CT pin
    input   wire            i_REG_LFO_CLK,

    //input data for LSI test via bus registers
    input   wire            i_REG_PHASE_CH6_C2,
    input   wire            i_REG_ATTENLEVEL_CH8_C2,
    input   wire    [13:0]  i_REG_OPDATA
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
reg             cycle_02;
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    cycle_02 <= i_CYCLE_01;
end



///////////////////////////////////////////////////////////
//////  Bus/control data inlatch and synchronizer
////

//3.58MHz phiM and 1.79MHz phi1 would be too slow to catch up
//bus transaction speed. So the chip "latch" the input first.
//3-stage DFF chain will synchronize the data then.

//latch outputs
wire    [7:0]   dbus_inlatch_temp;
wire            dreg_rq_inlatch, areg_rq_inlatch;

//Synchronizer DFF
reg             dreg_rq_synced0, dreg_rq_synced1, dreg_rq_synced2;
reg             areg_rq_synced0, areg_rq_synced1, areg_rq_synced2;
wire            data_ld = dreg_rq_synced2;
wire            addr_ld = areg_rq_synced2;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        if(!mrst_n) begin
            dreg_rq_synced0 <= 1'b0;
            dreg_rq_synced2 <= 1'b0;

            areg_rq_synced0 <= 1'b0;
            areg_rq_synced2 <= 1'b0;
        end
        else begin
            //data load
            dreg_rq_synced0 <= dreg_rq_inlatch;
            dreg_rq_synced2 <= dreg_rq_synced1;

            //address load
            areg_rq_synced0 <= areg_rq_inlatch;
            areg_rq_synced2 <= areg_rq_synced1;
        end
    end

    if(!phi1pcen_n) begin
        if(!mrst_n) begin
            dreg_rq_synced1 <= 1'b0;

            areg_rq_synced1 <= 1'b0;
        end
        else begin
            //data load
            dreg_rq_synced1 <= dreg_rq_synced0;

            //address load
            areg_rq_synced1 <= areg_rq_synced0;
        end
    end
end

//Stable data bus value; without this, a data value will overwrite a address value on a fast write cycle(6502@8MHz).
//The actual YM2151 is slow, so when the CPU writes a new value, it takes a significant amount of time for the old value
//to change(<20 ns). But an FPGA is fast. So the value has already changed before the address register samples the value.
reg     [7:0]   dbus_inlatch; 
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        if(!i_MRST_n) begin
            dbus_inlatch <= 8'h00;
        end
        else begin
            if(areg_rq_synced1 | dreg_rq_synced1) dbus_inlatch <= dbus_inlatch_temp;
        end
    end
end



generate
if(FULLY_SYNCHRONOUS == 0) begin : FULLY_SYNCHRONOUS_0_busctrl
    wire            dbus_inlatch_temp_en = ~|{i_CS_n, i_WR_n};
    wire            dreg_req_inlatch_set = ~(|{i_CS_n, i_WR_n, ~i_A0, ~mrst_n} | dreg_rq_synced1);
    wire            dreg_req_inlatch_rst = dreg_rq_synced1 | ~mrst_n;
    wire            areg_req_inlatch_set = ~(|{i_CS_n, i_WR_n,  i_A0, ~mrst_n} | areg_rq_synced1);
    wire            areg_req_inlatch_rst = areg_rq_synced1 | ~mrst_n;

    //D latch
    primitive_dlatch #(.WIDTH(8)) u_dbus_inlatch_temp (
        .i_EN(dbus_inlatch_temp_en), .i_D(i_D), .o_Q(dbus_inlatch_temp)
    );

    //SR latch
    primitive_srlatch u_dreg_req_inlatch (
        .i_S(dreg_req_inlatch_set), .i_R(dreg_req_inlatch_rst), .o_Q(dreg_rq_inlatch)
    );
    primitive_srlatch u_areg_req_inlatch (
        .i_S(areg_req_inlatch_set), .i_R(areg_req_inlatch_rst), .o_Q(areg_rq_inlatch)
    );
end
else begin : FULLY_SYNCHRONOUS_1_busctrl
    reg     [7:0]   din_syncchain[0:1];
    reg     [1:0]   cs_n_syncchain, rd_n_syncchain, wr_n_syncchain, a0_syncchain;
    always @(posedge i_EMUCLK) begin
        din_syncchain[0] <= i_D;
        din_syncchain[1] <= din_syncchain[0];

        cs_n_syncchain[0] <= i_CS_n;
        cs_n_syncchain[1] <= cs_n_syncchain[0];

        wr_n_syncchain[0] <= i_WR_n;
        wr_n_syncchain[1] <= wr_n_syncchain[0];

        a0_syncchain[0] <= i_A0;
        a0_syncchain[1] <= a0_syncchain[0];
    end

    //make alias signals
    wire            cs_n = cs_n_syncchain[1];
    wire            wr_n = wr_n_syncchain[1];
    wire            a0 = a0_syncchain[1];
    wire    [7:0]   din = din_syncchain[1];

    wire            dbus_inlatch_temp_en = ~|{cs_n, wr_n};
    wire            dreg_req_inlatch_set = ~(|{cs_n, wr_n, ~a0, ~mrst_n} | dreg_rq_synced1);
    wire            dreg_req_inlatch_rst = dreg_rq_synced1 | ~mrst_n;
    wire            areg_req_inlatch_set = ~(|{cs_n, wr_n, a0, ~mrst_n} | areg_rq_synced1);
    wire            areg_req_inlatch_rst = areg_rq_synced1 | ~mrst_n;

    //D latch
    primitive_syncdlatch #(.WIDTH(8)) u_dbus_inlatch_temp (
        .i_EMUCLK(i_EMUCLK), .i_RST_n(i_MRST_n),
        .i_EN(dbus_inlatch_temp_en), .i_D(din), .o_Q(dbus_inlatch_temp)
    );

    //SR latch
    primitive_syncsrlatch u_dreg_req_inlatch (
        .i_EMUCLK(i_EMUCLK), .i_RST_n(i_MRST_n),
        .i_S(dreg_req_inlatch_set), .i_R(dreg_req_inlatch_rst), .o_Q(dreg_rq_inlatch)
    );
    primitive_syncsrlatch u_areg_req_inlatch (
        .i_EMUCLK(i_EMUCLK), .i_RST_n(i_MRST_n),
        .i_S(areg_req_inlatch_set), .i_R(areg_req_inlatch_rst), .o_Q(areg_rq_inlatch)
    );
end
endgenerate


///////////////////////////////////////////////////////////
//////  Loreg decoder
////

wire            reg10_en, reg11_en, reg12_en, reg14_en; //timer related
wire            reg01_en; //test register
wire            reg0f_en; //noise generator
wire            reg19_en; //vibrato
wire            reg18_en; //LFO
wire            reg1b_en; //GPO
wire            reg08_en; //KON register

assign  o_LFRQ_UPDATE = reg18_en; //LFO frequency update flag;

reg_submdl_loreg_decoder #(.TARGET_ADDR(8'h10)) u_reg10 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(dbus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg10_en)
);

reg_submdl_loreg_decoder #(.TARGET_ADDR(8'h11)) u_reg11 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(dbus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg11_en)
);

reg_submdl_loreg_decoder #(.TARGET_ADDR(8'h12)) u_reg12 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(dbus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg12_en)
);

reg_submdl_loreg_decoder #(.TARGET_ADDR(8'h14)) u_reg14 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(dbus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg14_en)
);

reg_submdl_loreg_decoder #(.TARGET_ADDR(8'h01)) u_reg01 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(dbus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg01_en)
);

reg_submdl_loreg_decoder #(.TARGET_ADDR(8'h0f)) u_reg0f (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(dbus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg0f_en)
);

reg_submdl_loreg_decoder #(.TARGET_ADDR(8'h19)) u_reg19 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(dbus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg19_en)
);

reg_submdl_loreg_decoder #(.TARGET_ADDR(8'h18)) u_reg18 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(dbus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg18_en)
);

reg_submdl_loreg_decoder #(.TARGET_ADDR(8'h1B)) u_reg1b (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(dbus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg1b_en)
);

reg_submdl_loreg_decoder #(.TARGET_ADDR(8'h08)) u_reg08 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(dbus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg08_en)
);



///////////////////////////////////////////////////////////
//////  Hireg temp register, flags, decoder
////

//
//  TEMPORARY ADDRESS REGISTER FOR HIREG
//

//hireg temporary address register load enable
wire            hireg_addrreg_en = (addr_ld & (dbus_inlatch[7:5] != 3'b000)); //not 000X_XXXX

//hireg "address" temporary register with async reset
reg     [7:0]   hireg_addr;
always @(posedge i_EMUCLK or negedge mrst_n) begin
    if(!mrst_n) begin
        hireg_addr <= 8'hFF;
    end
    else begin
        if(!phi1pcen_n) begin
            if(hireg_addrreg_en) hireg_addr <= dbus_inlatch;
        end
    end
end

//hireg address valid flag, reset when the address input is loreg
reg             hireg_addr_valid;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        hireg_addr_valid <= hireg_addrreg_en | (hireg_addr_valid & ~addr_ld);
    end
end


//
//  TEMPORARY DATA REGISTER FOR HIREG
//

//hireg temporary data register load enable
wire            hireg_datareg_en = data_ld & hireg_addr_valid;

//hireg "data" temporary register with async reset
reg     [7:0]   hireg_data;
always @(posedge i_EMUCLK or negedge mrst_n) begin
    if(!mrst_n) begin
        hireg_data <= 8'hFF;
    end
    else begin
        if(!phi1ncen_n) begin
            if(hireg_datareg_en) hireg_data <= dbus_inlatch;
        end
    end
end

//hireg data valid flag, reset when the data input is loreg
reg             hireg_data_valid;
always @(posedge i_EMUCLK) begin
    if(!phi1pcen_n) begin
        hireg_data_valid <= hireg_datareg_en | (hireg_data_valid & ~addr_ld);
    end
end


//
//  HIREG ADDRESS COUNTER
//

wire    [4:0]   hireg_addrcntr;
primitive_counter #(.WIDTH(5)) u_hireg_addrcntr (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(1'b1), .i_LD(1'b0), .i_RST(i_CYCLE_31 | ~mrst_n),
    .i_D(5'd0), .o_Q(hireg_addrcntr), .o_CO()
);



//
//  DECODER
//

reg             reg38_3f_en; //PMS[6:4]/AMS[1:0]
reg             reg30_37_en; //KF[7:2]
reg             reg28_2f_en; //KC[6:0]
reg             reg20_27_en; //RL[7:6]/FL[5:3]/CONNECT(algorithm)[2:0]

reg             rege0_ff_en; //D1L[7:4]/RR[3:0]
reg             regc0_df_en; //DT2[7:6]/D2R[4:0]
reg             rega0_bf_en; //AMS-EN[7]/D1R[4:0]
reg             reg80_9f_en; //KS[7:6]/AR[4:0]
reg             reg60_7f_en; //TL[6:0]
reg             reg40_5f_en; //DT1[6:4]/MUL[3:0]

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        reg38_3f_en <= (hireg_addr[7:3] == 5'b00111) & (hireg_addr[2:0] == hireg_addrcntr[2:0]) & hireg_data_valid;
        reg30_37_en <= (hireg_addr[7:3] == 5'b00110) & (hireg_addr[2:0] == hireg_addrcntr[2:0]) & hireg_data_valid;
        reg28_2f_en <= (hireg_addr[7:3] == 5'b00101) & (hireg_addr[2:0] == hireg_addrcntr[2:0]) & hireg_data_valid;
        reg20_27_en <= (hireg_addr[7:3] == 5'b00100) & (hireg_addr[2:0] == hireg_addrcntr[2:0]) & hireg_data_valid;

        rege0_ff_en <= (hireg_addr[7:5] == 3'b111)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
        regc0_df_en <= (hireg_addr[7:5] == 3'b110)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
        rega0_bf_en <= (hireg_addr[7:5] == 3'b101)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
        reg80_9f_en <= (hireg_addr[7:5] == 3'b100)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
        reg60_7f_en <= (hireg_addr[7:5] == 3'b011)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
        reg40_5f_en <= (hireg_addr[7:5] == 3'b010)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
    end
end



///////////////////////////////////////////////////////////
//////  Low registers
////

//
//  GENERAL STATIC REGISTERS
//

//CT reg output
reg     [1:0]   ct_reg; //define CT reg

always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    o_CT1 <= o_TEST[3] ? i_REG_LFO_CLK : ct_reg[0];  //LSI test purpose
    o_CT2 <= ct_reg[1];
end

//reg for KON
reg             csm_reg;
reg     [6:0]   kon_temp_reg;

//timer flag reset
assign  o_TIMERA_FRST = (reg14_en & dbus_inlatch[4]) | ~mrst_n;
assign  o_TIMERB_FRST = (reg14_en & dbus_inlatch[5]) | ~mrst_n;

always @(posedge i_EMUCLK) begin
    if(!phi1pcen_n) begin //positive edge!!
        if(!mrst_n) begin
            o_TEST          <= 8'h0;

            ct_reg          <= 2'b00;

            o_NE            <= 1'b0;
            o_NFRQ          <= 5'h00;

            o_CLKA1         <= 8'h0;
            o_CLKA2         <= 2'h0;
            o_CLKB          <= 8'h0;
            o_TIMERA_RUN    <= 1'b0;
            o_TIMERB_RUN    <= 1'b0;
            o_TIMERA_IRQ_EN <= 1'b0;
            o_TIMERB_IRQ_EN <= 1'b0;

            o_LFRQ          <= 8'h00;
            o_PMD           <= 7'h00;
            o_AMD           <= 7'h00;
            o_W             <= 2'd0;

            csm_reg         <= 1'b0;
            kon_temp_reg    <= 7'b0000_000;
        end
        else begin
            o_TEST          <= reg01_en ? dbus_inlatch      : o_TEST;

            ct_reg          <= reg1b_en ? dbus_inlatch[7:6] : ct_reg;
            
            o_NE            <= reg0f_en ? dbus_inlatch[7]   : o_NE;
            o_NFRQ          <= reg0f_en ? dbus_inlatch[4:0] : o_NFRQ;

            o_CLKA1         <= reg10_en ? dbus_inlatch      : o_CLKA1;
            o_CLKA2         <= reg11_en ? dbus_inlatch[1:0] : o_CLKA2;
            o_CLKB          <= reg12_en ? dbus_inlatch      : o_CLKB;
            o_TIMERA_RUN    <= reg14_en ? dbus_inlatch[0]   : o_TIMERA_RUN;
            o_TIMERB_RUN    <= reg14_en ? dbus_inlatch[1]   : o_TIMERB_RUN;
            o_TIMERA_IRQ_EN <= reg14_en ? dbus_inlatch[2]   : o_TIMERA_IRQ_EN;
            o_TIMERB_IRQ_EN <= reg14_en ? dbus_inlatch[3]   : o_TIMERB_IRQ_EN;

            o_LFRQ          <= reg18_en ? dbus_inlatch      : o_LFRQ;
            o_PMD           <= reg19_en ? (dbus_inlatch[7] == 1'b1) ? dbus_inlatch[6:0] : o_PMD :
                                          o_PMD;
            o_AMD           <= reg19_en ? (dbus_inlatch[7] == 1'b0) ? dbus_inlatch[6:0] : o_AMD :
                                          o_AMD;
            o_W             <= reg1b_en ? dbus_inlatch[1:0] : o_W;

            csm_reg         <= reg14_en ? dbus_inlatch[7]   : csm_reg;
            kon_temp_reg    <= reg08_en ? dbus_inlatch[6:0] : kon_temp_reg;
        end
    end
end


//
//  DYNAMIC REGISTERS FOR KON
//

reg             ch_equal, force_kon;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        ch_equal <= hireg_addrcntr == {2'b00, kon_temp_reg[2:0]}; //channel number
    
        if(!mrst_n) force_kon <= 1'b0;
        else begin if(cycle_02) force_kon <= i_TIMERA_OVFL & csm_reg; end
    end
end

/*
    define 8-bit, 4-line, total 32-stage shift register(8*4)
    Data flows from LSB to MSB. The LSB of each line has a multiplexer
    to choose data to be written in the LSB register.
    When ch_equal is activated, new data from temporary kon reg is loaded.
    If not, it gets data from the MSB of the previous "line"
*/
reg             kon_m1, kon_m2, kon_c1, kon_c2;
reg     [7:0]   kon_sr_0_7, kon_sr_8_15, kon_sr_16_23, kon_sr_24_31;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        kon_m1 <= kon_temp_reg[3]; kon_m2 <= kon_temp_reg[5];
        kon_c1 <= kon_temp_reg[4]; kon_c2 <= kon_temp_reg[6];

        //line 1
        kon_sr_0_7[0] <= ch_equal ? kon_m1 : (kon_sr_24_31[7] & mrst_n);
        kon_sr_0_7[7:1] <= kon_sr_0_7[6:0];

        //line 2
        kon_sr_8_15[0] <= ch_equal ? kon_c2 : kon_sr_0_7[7];
        kon_sr_8_15[7:1] <= kon_sr_8_15[6:0];

        //line 3
        kon_sr_16_23[0] <= ch_equal ? kon_c1 : kon_sr_8_15[7];
        kon_sr_16_23[7:1] <= kon_sr_16_23[6:0];

        //line 4
        kon_sr_24_31[0] <= ch_equal ? kon_m2 : kon_sr_16_23[7];
        kon_sr_24_31[7:1] <= kon_sr_24_31[6:0];
    end
end

assign  o_KON = kon_sr_24_31[5] | force_kon;



///////////////////////////////////////////////////////////
//////  High registers
////

//
//  SR8 REGISTERS
//

/*
    8-stage sr for the data below:

    Address 38_3f : PMS[6:4]    AMS[1:0]
    Address 30_37 : KF[7:2]
    Address 28_2f : KC[6:0]
    Address 20_27 : RL[7:6]     FL[5:3]     CONNECT(algorithm)[2:0]
*/

//define in/out port
wire    [2:0]   pms_out;    //phase modulation sensitivity
wire    [1:0]   ams_out;    //amplitude modulation sensitivity
wire    [5:0]   kf_out;     //key fraction
wire    [6:0]   kc_out;     //key code
wire    [2:0]   fl_out;     //feedback level
wire    [2:0]   alg_out;    //algorithm type
wire    [1:0]   rl_out;     //right/left channel enable

wire    [2:0]   pms_in  = !mrst_n ? 3'd0  : reg38_3f_en ? hireg_data[6:4] : pms_out;
wire    [1:0]   ams_in  = !mrst_n ? 2'd0  : reg38_3f_en ? hireg_data[1:0] : ams_out;
wire    [5:0]   kf_in   = !mrst_n ? 6'd0  : reg30_37_en ? hireg_data[7:2] : kf_out;
wire    [6:0]   kc_in   = !mrst_n ? 7'd0  : reg28_2f_en ? hireg_data[6:0] : kc_out;
wire    [2:0]   fl_in   = !mrst_n ? 3'd0  : reg20_27_en ? hireg_data[5:3] : fl_out;
wire    [2:0]   alg_in  = !mrst_n ? 3'd0  : reg20_27_en ? hireg_data[2:0] : alg_out;
wire    [1:0]   rl_in   = !mrst_n ? 2'b00 : reg20_27_en ? hireg_data[7:6] : rl_out;

primitive_sr #(.WIDTH(3), .LENGTH(8), .TAP(0)) u_pms_reg 
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(pms_in), .o_Q_TAP(o_PMS), .o_Q_LAST(pms_out));

primitive_sr #(.WIDTH(2), .LENGTH(8), .TAP(8)) u_ams_reg 
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(ams_in), .o_Q_TAP(), .o_Q_LAST(ams_out));

primitive_sr #(.WIDTH(6), .LENGTH(8), .TAP(1)) u_kf_reg 
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(kf_in), .o_Q_TAP(o_KF), .o_Q_LAST(kf_out));

primitive_sr #(.WIDTH(7), .LENGTH(8), .TAP(1)) u_kc_reg 
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(kc_in), .o_Q_TAP(o_KC), .o_Q_LAST(kc_out));

primitive_sr #(.WIDTH(3), .LENGTH(8), .TAP(7)) u_fl_reg 
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(fl_in), .o_Q_TAP(o_FL), .o_Q_LAST(fl_out));

primitive_sr #(.WIDTH(3), .LENGTH(8), .TAP(4)) u_alg_reg 
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(alg_in), .o_Q_TAP(o_ALG), .o_Q_LAST(alg_out));

primitive_sr #(.WIDTH(2), .LENGTH(8), .TAP(5)) u_rl_reg 
(.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(rl_in), .o_Q_TAP(o_RL), .o_Q_LAST(rl_out));




//
//  SR32 REGISTERS
//

/*
    32-stage sr for the data below:

    Address e0_ff : D1L[7:4]    RR[3:0]
    Address c0_df : DT2[7:6]    D2R[4:0]
    Address a0_bf : AMS-EN[7]   D1R[4:0]
    Address 80_9f : KS[7:6]     AR[4:0]
    Address 60_7f : TL[6:0]
    Address 40_5f : DT1[6:4]    MUL[3:0]
*/

//define in/out port
wire    [1:0]   dt2_out;    //detune2
wire    [2:0]   dt1_out;    //detune1
wire    [3:0]   mul_out;    //phase multuply
wire    [4:0]   ar_out;     //attack rate
wire    [4:0]   d2r_out;    //second decay rate
wire    [4:0]   d1r_out;    //first decay rate
wire    [3:0]   rr_out;     //release rate
wire    [3:0]   d1l_out;    //first decay level
wire            amen_out;   //amplitude modulation enable
wire    [1:0]   ks_out;     //key scale
wire    [6:0]   tl_out;     //total level

generate
if(USE_BRAM_FOR_D32REG == 0) begin: d32reg_mode_sr
    wire    [1:0]   dt2_in  = !mrst_n ? 2'd0 : regc0_df_en ? hireg_data[7:6] : dt2_out;
    wire    [2:0]   dt1_in  = !mrst_n ? 3'd0 : reg40_5f_en ? hireg_data[6:4] : dt1_out;
    wire    [3:0]   mul_in  = !mrst_n ? 4'd0 : reg40_5f_en ? hireg_data[3:0] : mul_out;
    wire    [4:0]   ar_in   = !mrst_n ? 5'd0 : reg80_9f_en ? hireg_data[4:0] : ar_out;
    wire    [4:0]   d1r_in  = !mrst_n ? 5'd0 : rega0_bf_en ? hireg_data[4:0] : d1r_out;
    wire    [4:0]   d2r_in  = !mrst_n ? 5'd0 : regc0_df_en ? hireg_data[4:0] : d2r_out;
    wire    [3:0]   rr_in   = !mrst_n ? 4'd0 : rege0_ff_en ? hireg_data[3:0] : rr_out;
    wire    [3:0]   d1l_in  = !mrst_n ? 4'd0 : rege0_ff_en ? hireg_data[7:4] : d1l_out;
    wire            amen_in = !mrst_n ? 1'b0 : rega0_bf_en ? hireg_data[7]   : amen_out;
    wire    [1:0]   ks_in   = !mrst_n ? 2'd0 : reg80_9f_en ? hireg_data[7:6] : ks_out; 
    wire    [6:0]   tl_in   = !mrst_n ? 7'd0 : reg60_7f_en ? hireg_data[6:0] : tl_out; 

    primitive_sr #(.WIDTH(2), .LENGTH(32), .TAP(27)) u_dt2_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(dt2_in), .o_Q_TAP(o_DT2), .o_Q_LAST(dt2_out));

    primitive_sr #(.WIDTH(3), .LENGTH(32), .TAP(32)) u_dt1_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(dt1_in), .o_Q_TAP(o_DT1), .o_Q_LAST(dt1_out));

    primitive_sr #(.WIDTH(4), .LENGTH(32), .TAP(32)) u_mul_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(mul_in), .o_Q_TAP(o_MUL), .o_Q_LAST(mul_out));

    primitive_sr #(.WIDTH(5), .LENGTH(32), .TAP(32)) u_ar_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(ar_in), .o_Q_TAP(o_AR), .o_Q_LAST(ar_out));

    primitive_sr #(.WIDTH(5), .LENGTH(32), .TAP(32)) u_d1r_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(d1r_in), .o_Q_TAP(o_D1R), .o_Q_LAST(d1r_out));

    primitive_sr #(.WIDTH(5), .LENGTH(32), .TAP(32)) u_d2r_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(d2r_in), .o_Q_TAP(o_D2R), .o_Q_LAST(d2r_out));

    primitive_sr #(.WIDTH(4), .LENGTH(32), .TAP(32)) u_rr_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(rr_in), .o_Q_TAP(o_RR), .o_Q_LAST(rr_out));

    primitive_sr #(.WIDTH(4), .LENGTH(32), .TAP(32)) u_d1l_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(d1l_in), .o_Q_TAP(o_D1L), .o_Q_LAST(d1l_out));

    primitive_sr #(.WIDTH(1), .LENGTH(32), .TAP(32)) u_amen_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(amen_in), .o_Q_TAP(), .o_Q_LAST(amen_out));

    primitive_sr #(.WIDTH(2), .LENGTH(32), .TAP(32)) u_ks_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(ks_in), .o_Q_TAP(o_KS), .o_Q_LAST(ks_out));

    primitive_sr #(.WIDTH(7), .LENGTH(32), .TAP(32)) u_tl_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(tl_in), .o_Q_TAP(o_TL), .o_Q_LAST(tl_out));

    assign  o_AMS = ams_out & {2{amen_out}};
end
else begin: d32reg_mode_bram
    wire    [1:0]   dt2_in  = !mrst_n ? 2'd0 : regc0_df_en ? hireg_data[7:6] : dt2_out;
    wire    [2:0]   dt1_in  = !mrst_n ? 3'd0 : hireg_data[6:4];
    wire    [3:0]   mul_in  = !mrst_n ? 4'd0 : hireg_data[3:0];
    wire    [4:0]   ar_in   = !mrst_n ? 5'd0 : hireg_data[4:0];
    wire    [4:0]   d1r_in  = !mrst_n ? 5'd0 : hireg_data[4:0];
    wire    [4:0]   d2r_in  = !mrst_n ? 5'd0 : hireg_data[4:0];
    wire    [3:0]   rr_in   = !mrst_n ? 4'd0 : hireg_data[3:0];
    wire    [3:0]   d1l_in  = !mrst_n ? 4'd0 : hireg_data[7:4];
    wire            amen_in = !mrst_n ? 1'b0 : hireg_data[7]  ;
    wire    [1:0]   ks_in   = !mrst_n ? 2'd0 : hireg_data[7:6];
    wire    [6:0]   tl_in   = !mrst_n ? 7'd0 : hireg_data[6:0];

    wire            d32reg_cntr_rst = i_CYCLE_31 | ~mrst_n;

    primitive_sr #(.WIDTH(2), .LENGTH(32), .TAP(27)) u_dt2_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_D(dt2_in), .o_Q_TAP(o_DT2), .o_Q_LAST(dt2_out));

    primitive_sr_bram #(.WIDTH(3), .LENGTH(32), .TAP(32)) u_dt1_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(d32reg_cntr_rst), .i_WR(reg40_5f_en), .i_D(dt1_in), .o_Q_TAP(o_DT1));

    primitive_sr_bram #(.WIDTH(4), .LENGTH(32), .TAP(32)) u_mul_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(d32reg_cntr_rst), .i_WR(reg40_5f_en), .i_D(mul_in), .o_Q_TAP(o_MUL));

    primitive_sr_bram #(.WIDTH(5), .LENGTH(32), .TAP(32)) u_ar_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(d32reg_cntr_rst), .i_WR(reg80_9f_en), .i_D(ar_in), .o_Q_TAP(o_AR));

    primitive_sr_bram #(.WIDTH(5), .LENGTH(32), .TAP(32)) u_d1r_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(d32reg_cntr_rst), .i_WR(rega0_bf_en), .i_D(d1r_in), .o_Q_TAP(o_D1R));

    primitive_sr_bram #(.WIDTH(5), .LENGTH(32), .TAP(32)) u_d2r_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(d32reg_cntr_rst), .i_WR(regc0_df_en), .i_D(d2r_in), .o_Q_TAP(o_D2R));

    primitive_sr_bram #(.WIDTH(4), .LENGTH(32), .TAP(32)) u_rr_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(d32reg_cntr_rst), .i_WR(rege0_ff_en), .i_D(rr_in), .o_Q_TAP(o_RR));

    primitive_sr_bram #(.WIDTH(4), .LENGTH(32), .TAP(32)) u_d1l_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(d32reg_cntr_rst), .i_WR(rege0_ff_en), .i_D(d1l_in), .o_Q_TAP(o_D1L));

    primitive_sr_bram #(.WIDTH(1), .LENGTH(32), .TAP(32)) u_amen_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(d32reg_cntr_rst), .i_WR(rega0_bf_en), .i_D(amen_in), .o_Q_TAP(amen_out));

    primitive_sr_bram #(.WIDTH(2), .LENGTH(32), .TAP(32)) u_ks_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(d32reg_cntr_rst), .i_WR(reg80_9f_en), .i_D(ks_in), .o_Q_TAP(o_KS));

    primitive_sr_bram #(.WIDTH(7), .LENGTH(32), .TAP(32)) u_tl_reg 
    (.i_EMUCLK(i_EMUCLK), .i_CEN_n(phi1ncen_n), .i_CNTRRST(d32reg_cntr_rst), .i_WR(reg60_7f_en), .i_D(tl_in), .o_Q_TAP(o_TL));

    assign  o_AMS = ams_out & {2{amen_out}};
end
endgenerate



///////////////////////////////////////////////////////////
//////  Write busy flag timer
////

//write busy timer
reg             busycntr_cnt;
wire            busycntr_ovfl;
primitive_counter #(.WIDTH(5)) u_busycntr (
    .i_EMUCLK(i_EMUCLK), .i_PCEN_n(phi1pcen_n), .i_NCEN_n(phi1ncen_n),
    .i_CNT(busycntr_cnt), .i_LD(1'b0), .i_RST(~mrst_n),
    .i_D(5'd0), .o_Q(), .o_CO(busycntr_ovfl)
);

//write busy flag
reg             write_busy;
always @(posedge i_EMUCLK) begin
    if(!phi1pcen_n) write_busy <= (write_busy & ~(~mrst_n | busycntr_ovfl)) | data_ld;
    if(!phi1ncen_n) busycntr_cnt <= write_busy;
end





///////////////////////////////////////////////////////////
//////  Read-only register multiplexer
////

wire        [7:0]   internal_data = o_TEST[7] ? {i_REG_PHASE_CH6_C2, i_REG_ATTENLEVEL_CH8_C2, i_REG_OPDATA[13:8]} : i_REG_OPDATA[7:0];
assign  o_D = o_TEST[6] ? internal_data : {write_busy, 5'b00000, i_TIMERB_FLAG, i_TIMERA_FLAG};

assign  o_D_OE = ~|{~mrst_n, ~i_A0, i_RD_n, i_CS_n};

endmodule

module reg_submdl_loreg_decoder #(parameter TARGET_ADDR = 8'h00 ) (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //internal clock
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //address to be decoded
    input   wire    [7:0]   i_ADDR,

    input   wire            i_ADDR_LD,
    input   wire            i_DATA_LD,

    output  wire            o_REG_LD
);

reg             loreg_addr_valid;
always @(posedge i_EMUCLK) begin
    if(!i_phi1_NCEN_n) begin
        loreg_addr_valid <= ((TARGET_ADDR == i_ADDR) & i_ADDR_LD) | (loreg_addr_valid & ~i_ADDR_LD);
    end
end

assign  o_REG_LD = loreg_addr_valid & i_DATA_LD;

endmodule
