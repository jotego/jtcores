/* verilator lint_off WIDTHEXPAND */
module IKAOPM #(parameter FULLY_SYNCHRONOUS = 1, parameter FAST_RESET = 0,
                parameter USE_BRAM = 0) (
    //chip clock
    input   wire            i_EMUCLK, //emulator master clock

    //clock endables
    input   wire            i_phiM_PCEN_n, //phiM positive edge clock enable(negative logic)
    `ifdef IKAOPM_USER_DEFINED_CLOCK_ENABLES
    input   wire            i_phi1_PCEN_n, //phi1 positive edge clock enable(negative logic)
    input   wire            i_phi1_NCEN_n, //phi1 negative edge clock enable(negative logic)
    `endif

    //chip reset
    input   wire            i_IC_n,    

    //phi1
    output  wire            o_phi1,

    //bus control and address
    input   wire            i_CS_n,
    input   wire            i_RD_n,
    input   wire            i_WR_n,
    input   wire            i_A0,

    //bus data
    input   wire    [7:0]   i_D,
    output  wire    [7:0]   o_D,

    //output driver enable
    output  wire            o_D_OE,

    //ct
    output  wire            o_CT2, //BIT7 of register 0x1B, pin 8
    output  wire            o_CT1, //BIT6 of register 0x1B, pin 9

    //interrupt
    output  wire            o_IRQ_n,

    //sh
    output  wire            o_SH1,
    output  wire            o_SH2,

    //output
    output  wire            o_SO,

    output  wire            o_EMU_R_SAMPLE, o_EMU_L_SAMPLE,
    output  wire signed     [15:0]  o_EMU_R_EX, o_EMU_L_EX,
    output  wire signed     [15:0]  o_EMU_R, o_EMU_L

    `ifdef IKAOPM_BUSY_FLAG_ENABLE
    , output  wire            o_EMU_BUSY_FLAG
    `endif 
);



///////////////////////////////////////////////////////////
//////  Clock enable information
////

/*
    EMUCLK      ¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|
    phiM        _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    phi1        ¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________

    You should provide 3 enables when `IKAOPM_USER_DEFINED_CLOCK_ENABLES is defined
    phiM_PCEN   ¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯
    phi1_NCEN   ¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯
    phi1_PCEN   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
*/



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n, phi1ncen_n;
wire            mrst_n;



///////////////////////////////////////////////////////////
//////  Interconnects
////

//timings
wire            cycle_31, cycle_01;                     //to REG
wire            cycle_12_28, cycle_05_21, cycle_byte;   //to LFO
wire            cycle_05, cycle_10;                     //to PG
wire            cycle_03, cycle_00_16, cycle_01_to_16;  //to EG
wire            cycle_04_12_20_28;                      //to OP(algorithm state counter)
wire            cycle_29, cycle_06_22;                  //to ACC
wire            cycle_12, cycle_15_31;                  //to NOISE

//NOISE
wire    [4:0]   nfrq;
wire            lfo_noise;
wire            noise_attenlevel;

//LFO
wire    [7:0]   lfrq;
wire    [6:0]   pmd, amd;
wire    [1:0]   w;
wire            lfrq_update;
wire    [7:0]   lfa, lfp;

//PG
wire    [6:0]   kc;
wire    [5:0]   kf;
wire    [2:0]   pms;
wire    [1:0]   dt2;
wire    [2:0]   dt1;
wire    [3:0]   mul;
wire    [4:0]   pdelta_shamt;
wire            phase_rst;

//EG
wire            kon;
wire    [1:0]   ks;
wire    [4:0]   ar;
wire    [4:0]   d1r;
wire    [4:0]   d2r;
wire    [3:0]   rr;
wire    [3:0]   d1l;
wire    [6:0]   tl;
wire    [1:0]   ams;

//OP
wire    [9:0]   op_attenlevel, op_phasedata;
wire    [2:0]   alg, fl;

//ACC
wire            ne;
wire    [1:0]   rl;
wire            acc_snd_add;
wire    [13:0]  acc_noise;
wire    [13:0]  acc_opdata;

//TIMER
wire    [7:0]   clka1, clkb;
wire    [1:0]   clka2;
wire    [5:0]   timerctrl;
wire            timera_flag, timerb_flag, timera_ovfl;

//TEST
wire    [7:0]   test;
wire            reg_phase_ch6_c2, reg_attenlevel_ch8_c2, reg_lfo_clk;

//write busy flag(especially for an external asynchronous fifo)
`ifdef IKAOPM_BUSY_FLAG_ENABLE
assign  o_EMU_BUSY_FLAG = o_D[7];
`endif



///////////////////////////////////////////////////////////
//////  Modules
////

IKAOPM_timinggen #(
    .FULLY_SYNCHRONOUS          (FULLY_SYNCHRONOUS          ),
    .FAST_RESET                 (FAST_RESET                 )
) TIMINGGEN (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_IC_n                     (i_IC_n                     ),
    .o_MRST_n                   (mrst_n                     ),

    .i_phiM_PCEN_n              (i_phiM_PCEN_n              ),
    `ifdef IKAOPM_USER_DEFINED_CLOCK_ENABLES
    .i_phi1_PCEN_n              (i_phi1_PCEN_n              ),
    .i_phi1_NCEN_n              (i_phi1_NCEN_n              ),
    `endif

    .o_phi1                     (o_phi1                     ),
    .o_phi1_PCEN_n              (phi1pcen_n                 ),
    .o_phi1_NCEN_n              (phi1ncen_n                 ),

    .o_SH1                      (o_SH1                      ),
    .o_SH2                      (o_SH2                      ),

    .o_CYCLE_01                 (cycle_01                   ),
    .o_CYCLE_31                 (cycle_31                   ),

    .o_CYCLE_12_28              (cycle_12_28                ),
    .o_CYCLE_05_21              (cycle_05_21                ),
    .o_CYCLE_BYTE               (cycle_byte                 ),

    .o_CYCLE_05                 (cycle_05                   ),
    .o_CYCLE_10                 (cycle_10                   ),

    .o_CYCLE_03                 (cycle_03                   ),
    .o_CYCLE_00_16              (cycle_00_16                ),
    .o_CYCLE_01_TO_16           (cycle_01_to_16             ),

    .o_CYCLE_04_12_20_28        (cycle_04_12_20_28          ),

    .o_CYCLE_12                 (cycle_12                   ),
    .o_CYCLE_15_31              (cycle_15_31                ),

    .o_CYCLE_29                 (cycle_29                   ),
    .o_CYCLE_06_22              (cycle_06_22                )
);



IKAOPM_reg #(
    .USE_BRAM_FOR_D32REG        (USE_BRAM                   ),
    .FULLY_SYNCHRONOUS          (FULLY_SYNCHRONOUS          )
) REG (
    .i_EMUCLK                   (i_EMUCLK                   ),
    .i_MRST_n                   (mrst_n                     ),

    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_01                 (cycle_01                   ),
    .i_CYCLE_31                 (cycle_31                   ),

    .i_CS_n                     (i_CS_n                     ),
    .i_RD_n                     (i_RD_n                     ),
    .i_WR_n                     (i_WR_n                     ),
    .i_A0                       (i_A0                       ),

    .i_D                        (i_D                        ),
    .o_D                        (o_D                        ),
    .o_D_OE                     (o_D_OE                     ),

    .i_TIMERA_OVFL              (timera_ovfl                ),
    .i_TIMERA_FLAG              (timera_flag                ),
    .i_TIMERB_FLAG              (timerb_flag                ),

    .o_TEST                     (test                       ),

    .o_CT1                      (o_CT1                      ),
    .o_CT2                      (o_CT2                      ),

    .o_NE                       (ne                         ),
    .o_NFRQ                     (nfrq                       ),

    .o_CLKA1                    (clka1                      ),
    .o_CLKA2                    (clka2                      ),
    .o_CLKB                     (clkb                       ),       
    .o_TIMERA_RUN               (timerctrl[0]               ),
    .o_TIMERB_RUN               (timerctrl[1]               ),
    .o_TIMERA_IRQ_EN            (timerctrl[2]               ),
    .o_TIMERB_IRQ_EN            (timerctrl[3]               ),
    .o_TIMERA_FRST              (timerctrl[4]               ),
    .o_TIMERB_FRST              (timerctrl[5]               ),

    .o_LFRQ                     (lfrq                       ),
    .o_PMD                      (pmd                        ),
    .o_AMD                      (amd                        ),
    .o_W                        (w                          ),
    .o_LFRQ_UPDATE              (lfrq_update                ),

    .o_KC                       (kc                         ),
    .o_KF                       (kf                         ),
    .o_PMS                      (pms                        ),
    .o_DT2                      (dt2                        ),
    .o_DT1                      (dt1                        ),
    .o_MUL                      (mul                        ),

    .o_KON                      (kon                        ),
    .o_KS                       (ks                         ),
    .o_AR                       (ar                         ),
    .o_D1R                      (d1r                        ),
    .o_D2R                      (d2r                        ),
    .o_RR                       (rr                         ),
    .o_D1L                      (d1l                        ),
    .o_TL                       (tl                         ),
    .o_AMS                      (ams                        ),

    .o_ALG                      (alg                        ),
    .o_FL                       (fl                         ),

    .o_RL                       (rl                         ),

    .i_REG_LFO_CLK              (reg_lfo_clk                ),

    .i_REG_PHASE_CH6_C2         (reg_phase_ch6_c2           ),
    .i_REG_ATTENLEVEL_CH8_C2    (reg_attenlevel_ch8_c2      ),
    .i_REG_OPDATA               (acc_opdata                 )
);



IKAOPM_noise NOISE (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_12                 (cycle_12                   ),
    .i_CYCLE_15_31              (cycle_15_31                ),

    .i_NFRQ                     (nfrq                       ),

    .i_NOISE_ATTENLEVEL         (noise_attenlevel           ),

    .o_ACC_NOISE                (acc_noise                  ),
    .o_LFO_NOISE                (lfo_noise                  )
);



IKAOPM_lfo LFO (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),
    
    .i_CYCLE_12_28              (cycle_12_28                ),
    .i_CYCLE_05_21              (cycle_05_21                ),
    .i_CYCLE_BYTE               (cycle_byte                 ),
    
    .i_LFRQ                     (lfrq                       ),
    .i_PMD                      (pmd                        ),
    .i_AMD                      (amd                        ),
    .i_W                        (w                          ),
    .i_TEST_D1                  (test[1]                    ),
    .i_TEST_D2                  (test[2]                    ),
    .i_TEST_D3                  (test[3]                    ),

    .i_LFRQ_UPDATE              (lfrq_update                ),

    .i_LFO_NOISE                (lfo_noise                  ),

    .o_LFA                      (lfa                        ),
    .o_LFP                      (lfp                        ),
    .o_REG_LFO_CLK              (reg_lfo_clk                )
);



IKAOPM_pg #(
    .USE_BRAM_FOR_PHASEREG      (USE_BRAM                   )
) PG (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_05                 (cycle_05                   ),
    .i_CYCLE_10                 (cycle_10                   ),

    .i_KC                       (kc                         ),
    .i_KF                       (kf                         ),
    .i_PMS                      (pms                        ),
    .i_DT2                      (dt2                        ),
    .i_DT1                      (dt1                        ),
    .i_MUL                      (mul                        ),
    .i_TEST_D3                  (test[3]                    ),

    .i_LFP                      (lfp                        ),

    .i_PG_PHASE_RST             (phase_rst                  ),
    .o_EG_PDELTA_SHIFT_AMOUNT   (pdelta_shamt               ),
    .o_OP_PHASEDATA             (op_phasedata               ),
    .o_REG_PHASE_CH6_C2         (reg_phase_ch6_c2           )
);



IKAOPM_eg EG (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_03                 (cycle_03                   ),
    .i_CYCLE_31                 (cycle_31                   ),
    .i_CYCLE_00_16              (cycle_00_16                ),
    .i_CYCLE_01_TO_16           (cycle_01_to_16             ),

    .i_KON                      (kon                        ),
    .i_KS                       (ks                         ),
    .i_AR                       (ar                         ),
    .i_D1R                      (d1r                        ),
    .i_D2R                      (d2r                        ),
    .i_RR                       (rr                         ),
    .i_D1L                      (d1l                        ),
    .i_TL                       (tl                         ),
    .i_AMS                      (ams                        ),
    .i_LFA                      (lfa                        ),
    .i_TEST_D0                  (test[0]                    ),
    .i_TEST_D5                  (test[5]                    ),

    .i_EG_PDELTA_SHIFT_AMOUNT   (pdelta_shamt               ),

    .o_PG_PHASE_RST             (phase_rst                  ),
    .o_OP_ATTENLEVEL            (op_attenlevel              ),
    .o_NOISE_ATTENLEVEL         (noise_attenlevel           ),
    .o_REG_ATTENLEVEL_CH8_C2    (reg_attenlevel_ch8_c2      )
);



IKAOPM_op OP (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_03                 (cycle_03                   ),
    .i_CYCLE_12                 (cycle_12                   ),
    .i_CYCLE_04_12_20_28        (cycle_04_12_20_28          ),

    .i_ALG                      (alg                        ),
    .i_FL                       (fl                         ),
    .i_TEST_D4                  (test[4]                    ),

    .i_OP_PHASEDATA             (op_phasedata               ),
    .i_OP_ATTENLEVEL            (op_attenlevel              ),
    .o_ACC_SNDADD               (acc_snd_add                ),
    .o_ACC_OPDATA               (acc_opdata                 )
);



IKAOPM_acc ACC (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_12                 (cycle_12                   ),
    .i_CYCLE_29                 (cycle_29                   ),
    .i_CYCLE_00_16              (cycle_00_16                ),
    .i_CYCLE_06_22              (cycle_06_22                ),
    .i_CYCLE_01_TO_16           (cycle_01_to_16             ),

    .i_NE                       (ne                         ),
    .i_RL                       (rl                         ),

    .i_ACC_SNDADD               (acc_snd_add                ),
    .i_ACC_OPDATA               (acc_opdata                 ),
    .i_ACC_NOISE                (acc_noise                  ),

    .o_SO                       (o_SO                       ),

    .o_EMU_R_SAMPLE             (o_EMU_R_SAMPLE             ),
    .o_EMU_R_EX                 (o_EMU_R_EX                 ),
    .o_EMU_R                    (o_EMU_R                    ),

    .o_EMU_L_SAMPLE             (o_EMU_L_SAMPLE             ),
    .o_EMU_L_EX                 (o_EMU_L_EX                 ),
    .o_EMU_L                    (o_EMU_L                    )
);



IKAOPM_timer TIMER (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_31                 (cycle_31                   ),

    .i_CLKA1                    (clka1                      ),
    .i_CLKA2                    (clka2                      ),
    .i_CLKB                     (clkb                       ),
    .i_TIMERA_RUN               (timerctrl[0]               ),
    .i_TIMERB_RUN               (timerctrl[1]               ),
    .i_TIMERA_IRQ_EN            (timerctrl[2]               ),
    .i_TIMERB_IRQ_EN            (timerctrl[3]               ),
    .i_TIMERA_FRST              (timerctrl[4]               ),
    .i_TIMERB_FRST              (timerctrl[5]               ),
    .i_TEST_D2                  (test[2]                    ),

    .o_TIMERA_OVFL              (timera_ovfl                ),
    .o_TIMERA_FLAG              (timera_flag                ),
    .o_TIMERB_FLAG              (timerb_flag                ),
    .o_IRQ_n                    (o_IRQ_n                    )
);

endmodule 
