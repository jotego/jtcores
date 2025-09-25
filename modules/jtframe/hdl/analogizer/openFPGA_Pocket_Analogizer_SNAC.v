//This module encapsulates all Analogizer adapter SNAC controllers
// Original work by @RndMnkIII. 
// Date: 01/2024 
// Release: 1.0

// *** Analogizer R.1 adapter ***
//SNAC mappings:
//USB 3 Type A connector   ______________________________________________________________________________________                             
//PIN_NUMBER:             /           1      2       3       4       5       6       7       8       9           \
//PIN_NAME:              |             VBUS   D-      D+      GND     RX-     RX+     GND_D   TX-     TX+         |
//FUNCTION:              |             +5V    OUT1    OUT2    GND     IO3     IN4     IO5     IO6     IN7         |
//                       |  A                   ^       ^              ^       |       ^       ^       |          |
//                       |  N                   |       |              |       |    +--|-------|-------+          |
//                       |  A       +-----------|-------|--------------|-------+    |  |       +----------------+ |                              
//                       |  L       |         +-|-------|--------------|------------+  +--------+               | |            
//                       |  O       |         | |       |              |      +------------+    |               | |
//                       |  G       |         | |       |              |   +->| B        B |----|------+        | |
//                       |  I       |         | |       |              +---|->| CONF. SW.  |<---+      |        | |
//                       |  Z       |         | |   +---|-------<----------|<-| A        A |<----+     |        | |
//                       |  E       |         | |   |   |                  |  +------------+     |     |        | |
//                       |  R       |         | |   |   |             +-->-+------>--------->----+     |        | |         
//                       |         I|        I| |   |   +-------+     |                                |        | |
//                       |  R      N|        N| +---------+     |    B|A     B OUT                     |        | |
//                       |  1      4|   I    7|  IO3| OUT1| OUT2|  IO3|IO5  +-----------------------------------+ |
//                       |          |   O   IN|    A|     |O    |O   O|O    |A IN                      |          |  
//                       |         I|   5+----|-----|-----|U----|U---U|U ---|--------------------------+          |  
//                       |      ___N|___B|IN__|___IN|_____|T____|T___T|T____|_____                                |  
//POCKET                 |     /    V    V    V     V     ^     ^     ^     V     \                               |    
//CARTRIDGE PIN #:        \___|     2    3    4     5 ... 28    29    30    31     |_____________________________/
//                             \____|____|____|_____|_____|_____|_____|_____|_____/
//Pocket Pin Name:                  |    |    |     |     |     |     |     |
//cart_tran_bank0[7] ---------------+    |    |     |     |     |     |     | cart_tran_bank0_dir=1'b0; //input
//cart_tran_bank0[6] --------------------+    |     |     |     |     |     |
//cart_tran_bank0[5] -------------------------+     |     |     |     |     |
//cart_tran_bank0[4] -------------------------------+     |     |     |     |
//cart_tran_bank1[6] -------------------------------------+     |     |     | cart_tran_bank1_dir=1'b1 //output
//cart_tran_bank1[7] -------------------------------------------+     |     |
//cart_tran_pin30    -------------------------------------------------+     | cart_tran_pin30_dir=1'b1, cart_pin30_pwroff_reset=1'b1 (GPIO USE)
//cart_tran_pin31    -------------------------------------------------------+ cart_tran_pin31_dir=1'b0 / 1'b1 
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------++------------------
//                                                      C O N F I G U R A T I O N   A                                                                                || CONFIGURATION  B
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------++------------------
//     DEV TYPE          0                   1                    2                   3                   4                     5                 6                  || 16         
//     PIN_NAME         SNAC DISABLED        DB15		          NES                 SNES                PCENGINE(2BTN)        PCENGINE(6BTN)    PCENGINE(MULTITAP) || PSX
//USB3       SNAC                                                                                                                                                    || [NOT IMPLEMENTED]
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------||------------------
//VBUS 		 	                             +5V                  +5V                 +5V                 +5V                   +5V               +5V                || +5V                 
//D-		 OUT1      	                     CLK(O)               CLK_1(O)            CLK_1(O)            CLR(O)(*)             CLR(O)(*)         CLR(O)(*)          || AT1(O)     
//D+		 OUT2      	                     LAT(O)               LAT(O)              LAT(O)              SEL(O)(*)             SEL(O)(*)         SEL(O)(*)          || AT2(O)     
//GND 		 	                             GND                  GND                 GND                 GND                   GND               GND                || GND     
//RX-		  IO3                            DAT(I)               D0_1(I)             D0_1(I)             D2 (I)(*)             D2 (I)(*)         D2 (I)(*)          || CLK(O)          +
//RX+		  IN4                                                 D4_2(I)             IO_2(I)             D0 (I)(*)             D0 (I)(*)         D0 (I)(*)          || DAT(I)      
//GND_DRAIN	  IO5                                                 CLK_2(O)            CLK_2(O)                                                                       || ACK(I)          +
//TX-		  IO6                            DAT(I)(1)            D3_2(I)             D3_2(I)             D1 (I)(*)             D1 (I)(*)         D1 (I)(*)          || CMD(O)          +    
//TX+		  IN7                            D0_2(I)              D0_2(I)             D3 (I)(*)           D3 (I)(*)             D3 (I)(*)         D3 (I)(*)          || IRQ10(I)      
//
//(1) Alternate output of DAT (for male-to-male extension cables which cross Tx,Rx lines)

//(*) Needs a specific cable harness for use MiSTer SNAC adapter with the Pocket:
//  SNAC      PCENGINE     POCKET
// ADAPTER    FUNCTION     SNAC
//   D-    -> D0       ->  RX+    IN4
//   D+    -> D1       ->  TX-    IO6 (IN)
//   RX-   -> D2       ->  RX-    IO3 (IN)
//   RX+   -> CLR      ->  D-     OUT1
//   GND_D -> D3       ->  TX+    IN7 
//   TX-   -> SEL      ->  D+     OUT2

// `timescale 1ns / 1ps
module openFPGA_Pocket_Analogizer_SNAC #(parameter MASTER_CLK_FREQ=50_000_000)
(
    input             i_clk, //Core Master Freq.
    input             i_rst, //Core general reset
    input             conf_AB, //0 conf. A(default), 1 conf. B (see graph above)
    input      [ 4:0] game_cont_type, //0-15 Conf. A, 16-31 Conf. B
    //input wire [2:0] game_cont_sample_rate, //0 compatibility mode (slowest), 1 normal mode, 2 fast mode, 3 superfast mode
    output reg [15:0] p1_btn_state,
    output reg [15:0] p2_btn_state,
    output reg [15:0] p3_btn_state,
    output reg [15:0] p4_btn_state,
    // output reg        busy,
    //SNAC Pocket cartridge port interface (see graph above)   
    output reg [ 7:4] cart_bk0_out,        // Unused ??
    input      [ 7:4] cart_bk0_in,
    output reg        cart_bk0_dir,
    output reg [ 7:6] cart_bk1_out_p76,
    output reg        cart_pin30_out,
    input             cart_pin30_in,       // Unused ??
    output reg        cart_pin30_dir,
    output reg        cart_pin31_out,
    input             cart_pin31_in,
    output reg        cart_pin31_dir,
    //debug
    output            o_stb

); 

reg snac_out1;       // cart_tran_bank1[6]                                           D-
reg snac_out2;       // cart_tran_bank1[7]                                           D+
reg snac_io3_A;      // Conf.A: cart_tran_bank0[4] (in),  Conf.B: pin30(out)         RX-
reg snac_io3_B=0;    // Conf.A: cart_tran_bank0[4] (in),  Conf.B: pin30(out)         RX-
reg snac_in4;        // cart_tran_bank0[7]                                           RX+
wire snac_io5_A;     // Conf.A: pin30(out),               Conf.B: cart_tran_bank1[6] GND_D
// reg snac_io5_B;   // Conf.A: pin30(out),               Conf.B: cart_tran_bank1[6] GND_D
reg snac_io6_A;      // Conf.A: pin31(in),                Conf.B: pin31(out)         TX-
// reg snac_io6_B=0; // Conf.A: pin31(in),                Conf.B: pin31(out)         TX-
reg snac_in7;        // cart_tran_bank0[5]                                           TX+

//calculate step sizes for fract clock enables
localparam pce_normal_polling_freq      =  40_000;  //  40_000 /  5  =  8K samples/sec PCE
localparam pce_fast_polling_freq        =  80_000;  //  80_000 /  5  = 16K samples/sec PCE
localparam snes_compat_polling_freq     =  50_000;  //
localparam serlatch_normal_polling_freq =  200_000; //  200_000 / 25 =  8K samples/sec DB15    200_000 / 18 = 11.11K samples/sec NES/SNES
localparam serlatch_fast_polling_freq   =  400_000; //  400_000 / 25 = 16K samples/sec DB15    400_000 / 18 = 22.22K samples/sec NES/SNES

//the FSM is clocked 2x the polling freq.
localparam [32:0] MAX_INT = 33'h0ffffffff;
localparam [32:0] pce_normal_pstep      = ((MAX_INT / (MASTER_CLK_FREQ / 1000)) * pce_normal_polling_freq      * 2) / 1000;
localparam [32:0] pce_fast_pstep        = ((MAX_INT / (MASTER_CLK_FREQ / 1000)) * pce_fast_polling_freq        * 2) / 1000;
localparam [32:0] serlatch_normal_pstep = ((MAX_INT / (MASTER_CLK_FREQ / 1000)) * serlatch_normal_polling_freq * 2) / 1000;
localparam [32:0] serlatch_fast_pstep   = ((MAX_INT / (MASTER_CLK_FREQ / 1000)) * serlatch_fast_polling_freq   * 2) / 1000;
localparam [32:0] snes_compat_pstep     = ((MAX_INT / (MASTER_CLK_FREQ / 1000)) * snes_compat_polling_freq     * 2) / 1000;

//Supported game controller types
localparam GC_DISABLED     = 5'h0;
localparam GC_DB15         = 5'h1;
localparam GC_NES          = 5'h2;
localparam GC_SNES         = 5'h3;
localparam GC_PCE_2BTN     = 5'h4;
localparam GC_PCE_6BTN     = 5'h5;
localparam GC_PCE_MULTITAP = 5'h6;
localparam GC_DB15_FAST    = 5'h9;
localparam GC_SNES_SWAP    = 5'hB;
//parameter GC_PSX= 5'h16;

//Configuration:
localparam CONF_A = 1'b0;
localparam CONF_B = 1'b1;

reg [4:0] game_cont_type_r;
reg [32:0] strobe_step_size;
reg reset_on_change;

always @(posedge i_clk) begin
    //register SNAC settings
    game_cont_type_r <= game_cont_type;

    //detect change of SNAC settings and reset clock divider and set new settings
    reset_on_change <= 1'b0;
    if(i_rst || (game_cont_type_r != game_cont_type)) begin
        reset_on_change <= 1'b1;
    end
end

always @(posedge i_clk) begin

    case (game_cont_type)
        GC_DB15: begin
            strobe_step_size <= serlatch_normal_pstep;
        end
        GC_DB15_FAST: begin
            strobe_step_size <= serlatch_fast_pstep;
        end
        GC_NES, GC_SNES, GC_SNES_SWAP: begin
            strobe_step_size <= snes_compat_pstep;
        end
        GC_PCE_2BTN, GC_PCE_6BTN: begin
            strobe_step_size <= pce_normal_pstep;
        end
        GC_PCE_MULTITAP: begin
            strobe_step_size <= pce_fast_pstep;
        end

        default: //disabled
            strobe_step_size <= 33'h0;
    endcase
end

always @(posedge i_clk) begin
    case (conf_AB)
        CONF_A: begin
            cart_bk0_dir                   <= 1'b0;                                           //INPUT
            {snac_in4,snac_in7,snac_io3_A} <= {cart_bk0_in[7],cart_bk0_in[5],cart_bk0_in[4]}; //OUTPUT
            cart_bk1_out_p76               <= {snac_out2,snac_out1};                          //OUTPUT
            cart_pin30_dir                 <= 1'b1;                                           //OUTPUT
            cart_pin30_out                 <= snac_io5_A;
            cart_pin31_dir                 <= 1'b0;                                           //INPUT
            cart_pin31_out                 <= 1'b0;
            snac_io6_A                     <= cart_pin31_in;
        end
        CONF_B: begin
            cart_bk0_dir                   <= 1'b0;                                           //INPUT
            {snac_in4,/*snac_io5_B,*/snac_in7} <= {cart_bk0_in[7],/*cart_bk0_in[6],*/cart_bk0_in[5]}; //OUTPUT
            cart_bk1_out_p76               <= {snac_out2,snac_out1};                          //OUTPUT
            cart_pin30_dir                 <= 1'b1;                                           //OUTPUT
            cart_pin30_out                 <= snac_io3_B;
            cart_pin31_dir                 <= 1'b1;                                           //OUTPUT
            // cart_pin31_out                 <= snac_io6_B;
        end
    endcase
end

wire stb_clk /* synthesis keep */;
clock_divider_fract ckdiv(
.i_clk (i_clk),
.i_rst(reset_on_change), //reset on polling freq change
.i_step(strobe_step_size[31:0]),
.o_stb (stb_clk)
);

 wire dbg_clk_w;
 // reg dbg_clk /* synthesis noprune */;
clock_divider_fract dbgckdiv(
.i_clk (i_clk),
.i_rst(reset_on_change), //reset on polling freq change
.i_step({strobe_step_size[29:0],2'b00}),
.o_stb (dbg_clk_w)
);

 // always @(posedge i_clk) dbg_clk <= dbg_clk_w;

assign o_stb = stb_clk;

//DB15/NES/SNES game controller
wire [15:0] sl_p1 /* synthesis keep */;
wire [15:0] sl_p2 /* synthesis keep */;
wire SERLAT_snac_out1 /* synthesis keep */;
wire SERLAT_snac_out2 /* synthesis keep */;
//wire SERLAT_snac_io5_A /* synthesis keep */;
wire serlat_dat1 = (game_cont_type == 5'h1 || game_cont_type == 5'h9) ? snac_io3_A & snac_io6_A : snac_io3_A ;
serlatch_game_controller #(.MASTER_CLK_FREQ(MASTER_CLK_FREQ)) slgc
(
    .i_clk(i_clk),
    .i_rst(reset_on_change),
    .game_controller_type(game_cont_type[3:0]), //0x1 DB15, 0x2 NES, 0x3 SNES, 0x9 DB15 FAST, 0XB SNES SWAP A,B<->X,Y
    .i_stb(stb_clk),
    .p1_btn_state(sl_p1),
    .p2_btn_state(sl_p2),
    .busy(),
    //SNAC Game controller interface
    .o_clk(SERLAT_snac_out1), //shared for 2 controllers
    .o_clk2(snac_io5_A),
    .o_lat(SERLAT_snac_out2), //shared for 2 controllers
    .i_dat1(serlat_dat1),     //data from controller 1
    .i_dat2(snac_in7)         //data from controller 2
);

//PCENGINE game controller
wire [15:0] pce_p1 /* synthesis keep */;
wire PCE_snac_out1 /* synthesis keep */;
wire PCE_snac_out2 /* synthesis keep */;

pcengine_game_controller #(.MASTER_CLK_FREQ(MASTER_CLK_FREQ), .PULSE_CLR_LINE(1'b1)) pcegc1
(
    .i_clk(i_clk),
    .i_rst(reset_on_change),
    .game_controller_type(game_cont_type[3:0]), //0X4 2btn, 0X5 6btn
    .i_stb(stb_clk),
    .player_btn_state(pce_p1),
    .busy(),
    //SNAC Game controller interface
    .o_clr(PCE_snac_out1), //shared for 2 controllers
    .o_sel(PCE_snac_out2), //shared for 2 controllers
    .i_dat({snac_in7,snac_io3_A,snac_io6_A,snac_in4}) //data from controller
);

wire [15:0] pce_multitap_p1, pce_multitap_p2, pce_multitap_p3, pce_multitap_p4;
wire PCE_MULTITAP_snac_out1, PCE_MULTITAP_snac_out2;

pcengine_game_controller_multitap #(.MASTER_CLK_FREQ(MASTER_CLK_FREQ)) pcegmutitap
(
    .i_clk(i_clk),
    .i_rst(reset_on_change),
    .game_controller_type(game_cont_type[3:0]), //0x6 multitap
    .i_stb(stb_clk),
    .player1_btn_state(pce_multitap_p1),
    .player2_btn_state(pce_multitap_p2),
    .player3_btn_state(pce_multitap_p3),
    .player4_btn_state(pce_multitap_p4),
    .player5_btn_state(),
    .busy(),
    //SNAC Game controller interface
    .o_clr(PCE_MULTITAP_snac_out1), //shared for 2 controllers
    .o_sel(PCE_MULTITAP_snac_out2), //shared for 2 controllers
    .i_dat({snac_in7,snac_io3_A,snac_io6_A,snac_in4}) //data from controller
);

always @(*) begin
    cart_bk0_out = 4'hZ;

    case(game_cont_type)
    GC_DISABLED: begin
        snac_out1 = 1'b0;
        snac_out2 = 1'b0;
        p1_btn_state = 16'h0;
        p2_btn_state = 16'h0;
        p3_btn_state = 16'h0;
        p4_btn_state = 16'h0;
    end
    GC_DB15, GC_DB15_FAST, GC_NES, GC_SNES, GC_SNES_SWAP: begin
        snac_out1 = SERLAT_snac_out1;
        snac_out2 = SERLAT_snac_out2;
        p1_btn_state = sl_p1;
        p2_btn_state = sl_p2;
        p3_btn_state = 16'h0;
        p4_btn_state = 16'h0;

    end
    GC_PCE_2BTN, GC_PCE_6BTN: begin
        snac_out1 = PCE_snac_out1;
        snac_out2 = PCE_snac_out2;
        p1_btn_state = pce_p1;
        p2_btn_state = 16'h0;
        p3_btn_state = 16'h0;
        p4_btn_state = 16'h0;
    end
    GC_PCE_MULTITAP: begin
        snac_out1 = PCE_MULTITAP_snac_out1;
        snac_out2 = PCE_MULTITAP_snac_out2;
        p1_btn_state = pce_multitap_p1;
        p2_btn_state = pce_multitap_p2;
        p3_btn_state = pce_multitap_p3;
        p4_btn_state = pce_multitap_p4;
    end
    default: begin
        snac_out1 = 1'b0;
        snac_out2 = 1'b0;
        p1_btn_state = 16'h0;
        p2_btn_state = 16'h0;
        p3_btn_state = 16'h0;
        p4_btn_state = 16'h0;
    end
    endcase
end
endmodule