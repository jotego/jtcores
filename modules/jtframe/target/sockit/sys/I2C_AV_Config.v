//Legal Notice: (C)2006 Altera Corporation. All rights reserved. Your
//use of Altera Corporation's design tools, logic functions and other
//software and tools, and its AMPP partner logic functions, and any
//output files any of the foregoing (including device programming or
//simulation files), and any associated documentation or information are
//expressly subject to the terms and conditions of the Altera Program
//License Subscription Agreement or other applicable license agreement,
//including, without limitation, that your use is for the sole purpose
//of programming logic devices manufactured by Altera and sold by Altera
//or its authorized distributors.  Please refer to the applicable
//agreement for further details.

module I2C_AV_Config (  //Host Side
    iCLK,
    iRST_N,
      //  I2C Side
    oI2C_SCLK,
    oI2C_SDAT
  );

//  Host Side
input  iCLK;
input  iRST_N;
//  I2C Side
output  oI2C_SCLK;
inout  oI2C_SDAT;
//  Internal Registers/Wires
reg  [15:0]  mI2C_CLK_DIV;
reg  [23:0]  mI2C_DATA;
reg  mI2C_CTRL_CLK;
reg  mI2C_GO;
wire  mI2C_END;
wire  mI2C_ACK;
reg  [15:0]  LUT_DATA;
reg  [3:0]  LUT_INDEX;
reg  [1:0]  mSetup_ST;

//  Clock Setting
parameter  CLK_Freq  =  24000000;  //  24  MHz
parameter  I2C_Freq  =  20000;    //  20  KHz
//  LUT Data Number
parameter  LUT_SIZE  =  11;
//  Audio Data Index
parameter  Dummy_DATA  =  0;
parameter  SET_LIN_L  =  1;
parameter  SET_LIN_R  =  2;
parameter  SET_HEAD_L  =  3;
parameter  SET_HEAD_R  =  4;
parameter  A_PATH_CTRL  =  5;
parameter  D_PATH_CTRL  =  6;
parameter  POWER_ON  =  7;
parameter  SET_FORMAT  =  8;
parameter  SAMPLE_CTRL  =  9;
parameter  SET_ACTIVE  =  10;



/////////////////////  I2C Control Clock  ////////////////////////
always@(posedge iCLK or negedge iRST_N) begin
  if(!iRST_N) begin
    mI2C_CTRL_CLK  <=  1'd0;
    mI2C_CLK_DIV  <=  16'd0;
  end else begin
    if (mI2C_CLK_DIV < (CLK_Freq/I2C_Freq))
      mI2C_CLK_DIV  <=  mI2C_CLK_DIV + 16'd1;
    else begin
      mI2C_CLK_DIV  <=  16'd0;
      mI2C_CTRL_CLK  <=  ~mI2C_CTRL_CLK;
    end
  end
end

////////////////////////////////////////////////////////////////////
I2C_Controller   u0 (
  .CLOCK(mI2C_CTRL_CLK),  //  Controller Work Clock
  .I2C_SCLK(oI2C_SCLK),    //  I2C CLOCK
  .I2C_SDAT(oI2C_SDAT),    //  I2C DATA
  .I2C_DATA(mI2C_DATA),    //  DATA:[SLAVE_ADDR,SUB_ADDR,DATA]
  .GO(mI2C_GO),            //  GO transfor
  .END(mI2C_END),        //  END transfor
  .ACK(mI2C_ACK),        //  ACK
  .RESET(iRST_N)
);
////////////////////////////////////////////////////////////////////


//////////////////////  Config Control  ////////////////////////////
always@(posedge mI2C_CTRL_CLK or negedge iRST_N) begin
  if(!iRST_N)  begin
    LUT_INDEX  <=  4'd0;
    mSetup_ST  <=  2'd0;
    mI2C_GO    <=  1'd0;
  end else begin
    if(LUT_INDEX < LUT_SIZE) begin
      case(mSetup_ST)
        0:  begin
          mI2C_DATA  <= {8'h34,LUT_DATA};
          mI2C_GO    <= 1'd1;
          mSetup_ST  <= 2'd1;
        end
        1:  begin
          if(mI2C_END) begin
            if(!mI2C_ACK)
              mSetup_ST  <= 2'd2;
            else
              mSetup_ST  <= 2'd0;
            mI2C_GO    <= 1'd0;
          end
        end
        2:  begin
          LUT_INDEX  <= LUT_INDEX + 4'd1;
          mSetup_ST  <= 2'd0;
        end
      endcase
    end
  end
end
////////////////////////////////////////////////////////////////////


/////////////////////  Config Data LUT    //////////////////////////
always @ (*)
begin
  case(LUT_INDEX)
  //  Audio Config Data
  Dummy_DATA  :  LUT_DATA <= 16'h0000;
  SET_LIN_L   :  LUT_DATA <= 16'h009A;//16'h001A;  //R0 LINVOL = 1Ah (+4.5bB)
  SET_LIN_R   :  LUT_DATA <= 16'h029A;//16'h021A;  //R1 RINVOL = 1Ah (+4.5bB)
  SET_HEAD_L  :  LUT_DATA <= 16'h0479;  //R2 LHPVOL = 7Bh (+2dB)
  SET_HEAD_R  :  LUT_DATA <= 16'h0679;  //R3 RHPVOL = 7Bh (+2dB)
  A_PATH_CTRL :  LUT_DATA <= 16'h08D2;//16'h08F8;  //R4 DACSEL = 1
  D_PATH_CTRL :  LUT_DATA <= 16'h0A06;  //R5 DEEMP = 11 (48 KHz)
  //POWER_ON    :  LUT_DATA <= 16'h0C00;  //R6 all powered ON
  POWER_ON    :  LUT_DATA <= 16'h0C20;    //R6 internal oscilator MCLK powered down
  //SET_FORMAT  :  LUT_DATA <= 16'h0E01;  //R7 FORMAT=01,16 bit   format left justified
  SET_FORMAT  :  LUT_DATA <= 16'h0E02;    //R7 FORMAT=10,16 bit   format I2S
  //SAMPLE_CTRL :  LUT_DATA <= 16'h1009;  //R8 48KHz,USB-mode
  SAMPLE_CTRL :  LUT_DATA <= 16'h1008;    //R8 48KHz,Normal mode, clkdiv2=0 
  SET_ACTIVE  :  LUT_DATA <= 16'h1201;  //R9 ACTIVE
  default     :  LUT_DATA <= 16'h0000;
  endcase
end
////////////////////////////////////////////////////////////////////


endmodule

