//-------------------------------------------------------------------
//                                                          
// PLAYSTATION CONTROLLER(DUALSHOCK TYPE) INTERFACE TOP          
//                                                          
// Version : 2.00                                           
//                                                          
// Copyright(c) 2003 - 2004 Katsumi Degawa , All rights reserved  
//                                                          
// Important !                                              
//                                                          
// This program is freeware for non-commercial use.         
// An author does no guarantee about this program.          
// You can use this under your own risk.                    
// 
// 2003.10.30          It is optimized . by K Degawa 
// 2023.12 nand2mario: rewrite without ripple clocks to improve stability
//                     remove fine-grained vibration control as we don't use it         
// 2024.11 RndMnkIII: added capability to read two controllers using two ATT signals                                          
//                    check when there is a game controller connected
//
//-------------------------------------------------------------------
`timescale 100ps/10ps		

// Protocol: https://store.curiousinventor.com/guides/PS2/
// - Full duplex (command and data at the same time)
// - On negedge of clock, the line start to change. 
//   On posedge, values are read. 
// - Command   0x01 0x42(cmd) 0x00   0x00        0x00
//   Data      0xFF 0x41      0x5A   0xFF(btns)  0xFF(btns)
//                    ^- mode + # of words

//--------- SIMULATION ---------------------------------------------- 
//`define	SIMULATION_1	
//
// Poll controller status every 2^Timer clock cycles
// 125Khz / 2^11 = 61Hz
//
// SONY PLAYSTATION® CONTROLLER INFORMATION
// https://gamesx.com/controldata/psxcont/psxcont.htm
//
// "The DS4 stock polling rate is 250Hz 3-4 ms compared to the SN30 which is 67-75Hz 13-18 ms"
// https://www.reddit.com/r/8bitdo/comments/u8z3ag/has_anyone_managed_to_get_their_controllers/
`ifdef SIMULATION_1
`define Timer_siz 18  
`else
`define Timer_siz 11
`endif

module dualshock_controller #(
   parameter    FREQ             // frequency of `clk`
) (
   input        clk,             // Any main clock faster than 1Mhz 
   input        i_RSTn,          //  MAIN RESET
   input        i_ena,           // Enable operation of the module
   input        i_stb,
   //PSX interface
   input        i_MULTITAP_ena,
   input  [1:0] i_VIB_SW1,  //  Vibration SW  VIB_SW[0] Small Moter OFF 0:ON  1:
                           //                VIB_SW[1] Bic Moter   OFF 0:ON  1(Dualshook Only)
   input  [7:0] i_VIB_DAT1,  //  Vibration(Bic Moter)Data   8'H00-8'HFF (Dualshook Only)
   input  [1:0] i_VIB_SW2,
   input  [7:0] i_VIB_DAT2,  
   output       o_psCLK,         //  psCLK CLK OUT
   output       o_ATT1,         //  ATT1 OUT 
   output       o_ATT2,         //  ATT1 OUT        
   output       o_psTXD,         //  psTXD OUT
   input        i_psRXD,         //  psRXD IN
   input        i_psACK,         //ACK

   //vibration control
   output reg [7:0] o_RXD_ID,        //  RX DEVICE ID (UPPER NIBBLE) AND PAYLOAD SIZE (LOWER NIBBLE)
   output reg [7:0] o_RXD_0,
   output reg [7:0] o_RXD_1,         //  RX DATA 1 (8bit)
   output reg [7:0] o_RXD_2,         //  RX DATA 2 (8bit)
   output reg [7:0] o_RXD_3,         //  RX DATA 3 (8bit)
   output reg [7:0] o_RXD_4,         //  RX DATA 4 (8bit)
   output reg [7:0] o_RXD_5,         //  RX DATA 5 (8bit)
   output reg [7:0] o_RXD_6          //  RX DATA 6 (8bit) 
);

reg i_CLK ;          // SPI clock at 125Khz 
                    // some cheap controllers cannot handle the nominal 250Khz
reg R_CE, F_CE ;     // rising and falling edge pulses of i_CLK

// Generate i_CLK, F_CE, R_CE
always @(posedge clk) begin
    //clk_cnt <= clk_cnt + 1;
    //if(i_ena)clk_cnt <= clk_cnt + 1;
    R_CE <= 0;
    F_CE <= 0;
    //if (clk_cnt == CLK_DELAY-1) begin
    if (i_stb && i_ena) begin
        i_CLK <= ~i_CLK;
        R_CE <= ~i_CLK;
        F_CE <= i_CLK;
        //clk_cnt <= 0;
    end
end

reg ack_r/* synthesis noprune */;
always @(posedge clk) begin
    if (i_stb && i_ena) begin
        ack_r <= i_psACK;
    end
end

reg device_id_type ; //1'b1 digital one, 1'b0 analog one
always @(posedge clk) begin
    if(! i_RSTn) device_id_type <= 1'b0; 
    else if (W_byte_cnt == 2) begin
        case(o_RXD_ID)
             8'h23:   device_id_type <= 1'b1;
             8'h41:   device_id_type <= 1'b0;
             8'h53:   device_id_type <= 1'b1;
             8'h73:   device_id_type <= 1'b1;
             8'hE3:   device_id_type <= 1'b1;
             8'hF3:   device_id_type <= 1'b1;
             8'h80:   device_id_type <= 1'b1;  //multitap
             default: device_id_type <= 1'b0;
        endcase
    end
end

wire   W_type = 1'b1 ;        // DIGITAL PAD 0, ANALOG PAD 1
wire   [3:0] W_byte_cnt ;
wire   W_RXWT ;
wire   W_TXWT ;
wire   W_TXEN ;
wire   W_TXSET ;
reg    [7:0]W_TXD_DAT /* synthesis noprune */;
wire   [7:0]W_RXD_DAT ;

ps_pls_gan pls(
   .clk(clk), .R_CE(R_CE), .i_CLK(i_CLK), .i_RSTn(i_RSTn), .i_TYPE(device_id_type), 
   .o_RXWT(W_RXWT), .o_TXWT(W_TXWT), 
   .o_TXEN(W_TXEN), .o_psCLK(o_psCLK), 
   .o_ATT1(o_ATT1), .o_ATT2(o_ATT2), .o_byte_cnt(W_byte_cnt)
); 

ps_txd txd(
   .clk(clk), .F_CE(F_CE), .i_RSTn(i_RSTn),
   .i_WT(W_TXWT), .i_EN(W_TXEN), .i_TXD_DAT(W_TXD_DAT), .o_psTXD(o_psTXD)
);

ps_rxd rxd(
   .clk(clk), .R_CE(R_CE), .i_RSTn(i_RSTn),	
   .i_WT(W_RXWT), .i_psRXD(i_psRXD), .o_RXD_DAT(W_RXD_DAT)
);

// TX command generation
always @* begin
    case(W_byte_cnt)
     0:   W_TXD_DAT = 8'h01;
     1:   W_TXD_DAT = 8'h42;
     2:   W_TXD_DAT = (i_MULTITAP_ena) ? 8'h01 : 8'h00;
    //  3:   W_TXD_DAT = 8'h00;       // or vibration command
    //  4:   W_TXD_DAT = 8'h00;       // or vibration command
     3:  W_TXD_DAT = (~o_ATT1)? i_VIB_SW1[0] : ((~o_ATT2)? i_VIB_SW2[0]  :8'h00 );       // or vibration command
     4:  W_TXD_DAT = (~o_ATT1 && i_VIB_SW1[1])? i_VIB_DAT1 : ((~o_ATT2 && i_VIB_SW2[1])? i_VIB_DAT1  :8'h00 );        // or vibration command
    default: W_TXD_DAT = 8'h00;
    endcase
end

// RX data decoding
//ID DESCRIPTION                                          PAYLOAD_SIZE (half dwords)
// 1 Mouse                                                2
// 9 Lightspan Keyboard SCPH-2000                         6
// 4 Digital Controller SCPH-1010                         1
// 5 Analog Joystick SCPH-1110 (Analog Mode)              3
// 5 Dual Analog SCPH-1180 (Green LED mode)               3
// 7 Dual Analog & Dual Shock 1/2 (Analog Mode)           3-8
// 8 MultiTap                                             disabled: based on device ID connected, enabled: 16 (4x8)

reg W_RXWT_r ;

always @(posedge clk) begin
    W_RXWT_r <= W_RXWT;
    if (~W_RXWT && W_RXWT_r) begin  // record received value one cycle after RXWT
        case (W_byte_cnt)
         1: o_RXD_ID <= W_RXD_DAT; 
         2: o_RXD_0  <= W_RXD_DAT;
         3: o_RXD_1  <= W_RXD_DAT;
         4: o_RXD_2  <= W_RXD_DAT;
         5: o_RXD_3  <= W_RXD_DAT;
         6: o_RXD_4  <= W_RXD_DAT;
         7: o_RXD_5  <= W_RXD_DAT;
         8: o_RXD_6  <= W_RXD_DAT;
         default:;
        endcase
    end
end

endmodule


// timing signal generation module
module ps_pls_gan(
    input clk,
    input R_CE,
    input i_CLK,
    input i_RSTn,
    input i_TYPE,

    output o_RXWT,              // pulse to input RX byte
    output o_TXWT,              // pulse to output TX byte
    output o_TXSET,
    output o_TXEN,
    output o_psCLK,             // SPI clock to send to controller
    output o_ATT1,             // 0: active 
    output o_ATT2,             // 0: active 
    output [3:0] o_byte_cnt // index for byte received
);

parameter Timer_size = `Timer_siz;

reg [3:0] o_byte_cnt_r ;
reg [`Timer_siz-1:0] Timer ;
reg RXWT, TXWT, TXSET ;
reg psCLK_gate ;                 // 0: send i_CLK on wire
reg psATT1 ;         
reg psATT2 ;        

// increment timer on i_CLK rising edge
always @(posedge clk) begin
    if (~i_RSTn) 
        Timer <= 0;
    else if (R_CE) 
        Timer <= Timer+1;
end

always @(posedge clk) begin
    if (~i_RSTn) begin
        psCLK_gate <= 1;
        RXWT     <= 0;
        TXWT     <= 0;
        TXSET    <= 0;
    end else begin
        TXWT  <= 0;
        RXWT  <= 0;
        TXSET <= 0;
        if (R_CE) begin
            case (Timer[4:0])
             6: TXSET <= 1;
             9:  TXWT <= 1;         // pulse to set byte to send
             12: psCLK_gate <= 0;   // send 8 cycles of clock: 
             20: begin
                    psCLK_gate <= 1;   // 13,14,15,16,17,18,19,20
                    RXWT <= 1;         // pulse to get received byte
                end
            default:;
            endcase
        end
    end
end

always @(posedge clk) begin
    if (~i_RSTn) begin
        psATT1 <= 1;
        psATT2 <= 1;
    end
    else if (R_CE) begin	
        if (Timer[9:0] == 0) begin
            psATT1 <= Timer[10]; //switch each 2^10 R_CE cycles
            psATT2 <= ~Timer[10];
        end
        else if ((i_TYPE == 0)&&(Timer[9:0] == 158)) begin// end of byte 4
            psATT1 <=  1;
            psATT2 <=  1;
        end
        else if ((i_TYPE == 1)&&(Timer[9:0]  == 286)) begin // end of byte 9
            psATT1 <=  1;
            psATT2 <=  1;
        end
        
    end
end

always @(posedge clk) begin             // update o_byte_cnt_r
    if (!i_RSTn)
        o_byte_cnt_r <= 0;
    else if (R_CE) begin
        if (Timer[9:0] == 0)
            o_byte_cnt_r <= 0;
        else begin 
            if (Timer[4:0] == 31) begin         // received a byte
                if (i_TYPE == 0 && o_byte_cnt_r == 5)
                    o_byte_cnt_r <= o_byte_cnt_r;
                else if (i_TYPE == 1 && o_byte_cnt_r == 9)
                    o_byte_cnt_r <= o_byte_cnt_r;
                else
                    o_byte_cnt_r <= o_byte_cnt_r + 4'd1;
            end    
        end
    end
end

assign o_psCLK = psCLK_gate | i_CLK | ~(psATT1 ^ psATT2);
assign o_ATT1 = psATT1;
assign o_ATT2 = psATT2;
assign o_RXWT  = (~psATT1 | ~psATT2) & RXWT;
assign o_TXSET = (~psATT1 | ~psATT2) & TXSET;
assign o_TXWT  = (~psATT1 | ~psATT2) & TXWT;
assign o_TXEN  = (~psATT1 | ~psATT2) & ~psCLK_gate;
assign o_byte_cnt = o_byte_cnt_r;

endmodule

// receiver
module ps_rxd(
   input            clk,
   input            R_CE,       // one bit is transmitted on rising edge
   input            i_RSTn,	
   input            i_WT,       // pulse to output byte to o_RXD_DAT
   input            i_psRXD,
   output reg [7:0] o_RXD_DAT
);

reg     [7:0]   sp;

always @(posedge clk)
    if (~i_RSTn) begin
        sp <= 1;
        o_RXD_DAT <= 1;
    end else begin
        if (R_CE)         // posedge i_CLK
            sp <= { i_psRXD, sp[7:1]};
        if (i_WT)     
            o_RXD_DAT <= sp;
    end

endmodule

// transmitter
module ps_txd (
   input       clk,
   input       F_CE,       // transmit on falling edge of i_CLK
   input       i_RSTn,
   input       i_WT,       // pulse to load data to transmit
   input       i_EN,       // 1 to do transmission
   input [7:0] i_TXD_DAT,  // byte to transmit, lowest bit first
   output  reg o_psTXD     // output pin
);

reg   [7:0] ps;            // data buffer

always @(posedge clk) begin
   if (~i_RSTn) begin 
      o_psTXD <= 1;
      ps      <= 0;
   end else begin
      if (i_WT)
         ps  <= i_TXD_DAT;
      if (F_CE) begin       // bit is sent on falling edge of i_CLK
         if (i_EN) begin
            o_psTXD <= ps[0];
            ps      <= {1'b1, ps[7:1]};
         end else begin
            o_psTXD <= 1'd1;
            ps  <= ps;
         end
      end 
   end 	
end

endmodule