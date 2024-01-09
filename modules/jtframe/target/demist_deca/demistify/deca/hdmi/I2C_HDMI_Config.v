// Original Terasic Module from HDMI TX example
//
// Added comments and some registers from https://github.com/chriz2600/DreamcastHDMI/blob/develop/Core/source/adv7513/ADV7513.v
//

module I2C_HDMI_Config (
    //	Host Side
    iCLK,
    iRST_N,
    //	I2C Side
    I2C_SCLK,
    I2C_SDAT,
    HDMI_TX_INT
  );
  //	Host Side
  input				iCLK;
  input				iRST_N;
  //	I2C Side
  output			I2C_SCLK;
  inout				I2C_SDAT;
  input				HDMI_TX_INT;

  //	Internal Registers/Wires
  reg	[15:0]	mI2C_CLK_DIV;
  reg	[23:0]	mI2C_DATA;
  reg				mI2C_CTRL_CLK;
  reg				mI2C_GO;
  wire				mI2C_END;
  wire				mI2C_ACK;
  reg	[15:0]	LUT_DATA;
  reg	[5:0]		LUT_INDEX;
  reg	[3:0]		mSetup_ST;

  //	Clock Setting
  parameter	CLK_Freq	=	50000000;	//	50	MHz
  parameter	I2C_Freq	=	20000;		//	20	KHz
  //	LUT Data Number
  parameter	LUT_SIZE	=	36;

  /////////////////////	I2C Control Clock	////////////////////////
  always@(posedge iCLK or negedge iRST_N)
  begin
    if(!iRST_N)
    begin
      mI2C_CTRL_CLK	<=	0;
      mI2C_CLK_DIV	<=	0;
    end
    else
    begin
      if( mI2C_CLK_DIV	< (CLK_Freq/I2C_Freq) )
        mI2C_CLK_DIV	<=	mI2C_CLK_DIV+ 16'd1;
      else
      begin
        mI2C_CLK_DIV	<=	0;
        mI2C_CTRL_CLK	<=	~mI2C_CTRL_CLK;
      end
    end
  end
  ////////////////////////////////////////////////////////////////////
  I2C_Controller u0	(.CLOCK(mI2C_CTRL_CLK), //  Controller Work Clock
                    .I2C_SCLK(I2C_SCLK),    //  I2C CLOCK
                    .I2C_SDAT(I2C_SDAT),    //  I2C DATA
                    .I2C_DATA(mI2C_DATA),   //  DATA:[SLAVE_ADDR,SUB_ADDR,DATA]
                    .GO(mI2C_GO),           //  GO transfor
                    .END(mI2C_END),         //  END transfor
                    .ACK(mI2C_ACK),         //  ACK
                    .RESET(iRST_N));
  //////////////////////	Config Control	////////////////////////////
  always@(posedge mI2C_CTRL_CLK or negedge iRST_N)
  begin
    if(!iRST_N)
    begin
      LUT_INDEX	<=	0;
      mSetup_ST	<=	0;
      mI2C_GO		<=	0;
    end
    else
    begin
      if(LUT_INDEX<LUT_SIZE)
      begin
        case(mSetup_ST)
          0:
          begin
            mI2C_DATA	<=	{8'h72,LUT_DATA};
            mI2C_GO		<=	1;
            mSetup_ST	<=	1;
          end
          1:
          begin
            if(mI2C_END)
            begin
              if(!mI2C_ACK)
                mSetup_ST	<=	2;
              else
                mSetup_ST	<=	0;
              mI2C_GO		<=	0;
            end
          end
          2:
          begin
            LUT_INDEX	<=	LUT_INDEX+6'd1;
            mSetup_ST	<=	0;
          end
        endcase
      end
      else
      begin
        if(!HDMI_TX_INT)
        begin
          LUT_INDEX <= 0;
        end
        else
          LUT_INDEX <= LUT_INDEX;
      end
    end
  end
  /////////////////////	Config Data LUT	  //////////////////////////
  always
  begin
    case(LUT_INDEX)
        //	Video Config Data
         0:	LUT_DATA      <= 16'h9803;  // Must be set to 0x03 for proper operation
                                 // 20 bit N used with CTS to regenerate the audio clock in the receiver.
         1:	LUT_DATA      <= 16'h0100;  // Set 'N' value at 6144 --idem 
         2:	LUT_DATA      <= 16'h0218;  // Set 'N' value at 6144 --idem
         3:	LUT_DATA      <= 16'h0300;  // Set 'N' value at 6144 --idem
         4:	LUT_DATA      <= 16'h1470;  // Audio. Set Ch count in the channel status to 8.
         5:	LUT_DATA      <= 16'h1520;  // Video Input 24 bit 444 (RGB or YCrCb) with sep. syncs; // Audio 48kHz fs  --idem   
         					  // [7:4]: I2S Sampling Frequency = 0b0000, 44.1kHz  //  0b0010, 48.0kHz  
                                                // [3:0]: Video Input ID = 0b0000, 24 bit RGB 4:4:4 (separate syncs)                                     
         6:	LUT_DATA      <= 16'h1630;  // Video Output format 444, 24-bit input (8 bits x 3)
                                                // [7]:   output format = 0b0, 4:4:4, (4:2:2, if OUTPUT_4_2_2 is set)
                                                // [6]:   reserved = 0b0
                                                // [5:4]: color depth = 0b11, 8bit
                                                // [3:2]: input style = 0b0, not valid
                                                // [1]:   ddr input edge = 0b0, falling edge
                                                // [0]:   output colorspace for blackimage = 0b0, RGB (YCbCr, if OUTPUT_4_2_2 is set)
                                                
      // X: LUT_DATA         <= 16'h1700;   //02: 16:9, 00: 4:3 (default)
                                                // [7]:   fixed = 0b0
                                                // [6]:   vsync polarity = 0b0, sync polarity pass through (sync adjust is off in 0x41)
                                                // [5]:   hsync polarity = 0b0, sync polarity pass through
                                                // [4:3]: reserved = 0b00
                                                // [2]:   4:2:2 to 4:4:4 interpolation style = 0b0, use zero order interpolation
                                                // [1]:   input video aspect ratio = 0b0, 4:3; 0b10 for 16:9
                                                // [0]:   DE generator = 0b0, disabled      
         7:	LUT_DATA      <= 16'h1846;  // Disable CSC --idem
         					  // [7]:   CSC enable = 0b0, disabled
                                                // [6:5]: default = 0b10
                                                // [4:0]: default = 0b00110
         8:	LUT_DATA      <= 16'h4080;  // General control packet enable --idem
         9:	LUT_DATA      <= 16'h4110;  // Power down control --idem
						   // [6]:   power down = 0b0, all circuits powered up
                                                 // [5]:   fixed = 0b0
                                                 // [4]:   reserved = 0b1
                                                 // [3:2]: fixed = 0b00
                                                 // [1]:   sync adjustment enable = 0b0, disabled
                                                 // [0]:   fixed = 0b0
        10:	LUT_DATA      <= 16'h49A8;  // Set dither mode - 12-to-10 bit --Must be set to Default Value  --idem
        11:	LUT_DATA      <= 16'h5510;  // Set RGB in AVI infoframe --5510 original   (551C  h,v resolution)
        12:	LUT_DATA      <= 16'h5608;  // Set active format aspect (same as aspect ratio ) --idem
        13:	LUT_DATA      <= 16'h96F6;  // Set interrup --96F6 original   (9620 HPD interrupt clear)

        14:	LUT_DATA      <= 16'h7307;  // Audio. Info frame Ch count to 8 channels
        15:	LUT_DATA      <= 16'h761f;  // Audio. Set speaker allocation for 8 channels
        
        16:	LUT_DATA      <= 16'h9803;  // Must be set to 0x03 for proper operation --idem
        17:	LUT_DATA      <= 16'h9902;  // Must be set to Default Value
        18:	LUT_DATA      <= 16'h9ae0;  // Must be set to 0b1110000   

        19:	LUT_DATA      <= 16'h9c30;  // PLL filter R1 value /  Must be set to Default Value    --idem             
        20:	LUT_DATA      <= 16'h9d61;  // Set clock divide (not divided) --9d61 original --idem   
        21:	LUT_DATA      <= 16'ha2a4;  // Must be set to 0xA4 for proper operation --idem      
        22:	LUT_DATA      <= 16'ha3a4;  // Must be set to 0xA4 for proper operation --idem
        23:	LUT_DATA      <= 16'ha504;  // Must be set to Default Value  
        24:	LUT_DATA      <= 16'hab40;  // Must be set to Default Value
        25:	LUT_DATA      <= 16'haf16;  // Select HDMI mode --idem  
        					  // [7]:   HDCP enable = 0b0, disabled
                                                // [6:5]: fixed = 0b00
                                                // [4]:   frame encryption = 0b0, current frame not encrypted
                                                // [3:2]: fixed = 0b01
                                                // [1]:   HDMI/DVI mode select = 0b1, HDMI mode
                                                // [0]:   fixed = 0b0
        26:	LUT_DATA      <= 16'hba60;  // No clock delay --idem
         					  // [7:5]: clock delay, 0b011 no delay
                                                // [4]:   hdcp eprom, 0b1 internal   0b0 external
                                                // [3]:   fixed, 0b0
                                                // [2]:   display aksv, 0b0 don't show
                                                // [1]:   Ri two point check, 0b0 hdcp Ri standard
        27:	LUT_DATA      <= 16'hd1ff;  // Must be set to Default Value

        28:	LUT_DATA      <= 16'hde10;  // Must be set to Default for proper operation   
        					  // [7:5]: clock delay, 0b011 no delay
                                                // [4]:   hdcp eprom, 0b1 internal
                                                // [3]:   fixed, 0b0
                                                // [2]:   display aksv, 0b0 don't show
                                                // [1]:   Ri two point check, 0b0 hdcp Ri standard
        29:	LUT_DATA      <= 16'he460;  // Must be set to Default Value --idem
        30:	LUT_DATA      <= 16'hfa7c;  // Nbr of times to look for good phase --fa7d original  --idem   --> should be 7c
        
        31:	LUT_DATA      <= 16'he0d0;  // Must be set to Default for proper operation   
        32:	LUT_DATA      <= 16'hf900;  // Must be set to Default for proper operation   
        
        33:	LUT_DATA      <= 16'h0a01;       //  [7]: CTS selet = 0b0, automatic
                                                // [6:4]: audio select = 0b000, I2S
                                                // [3:2]: audio mode = 0b00, default (HBR not used)
                                                // [1:0]: MCLK Ratio = 0b00, 128xfs   (0b01, 256xfs default value)
        34:	LUT_DATA      <= 16'h0c04;       // [7]:   audio sampling frequency select = 0b0, use sampling frequency from I2S stream
                                                // [6]:   channel status override = 0b0, use channel status bits from I2S stream
                                                // [5]:   I2S3 enable = 0b0, disabled
                                                // [4]:   I2S2 enable = 0b0, disabled
                                                // [3]:   I2S1 enable = 0b0, disabled
                                                // [2]:   I2S0 enable = 0b1, enabled
                                                // [1:0]: I2S format = 0b01, right justified mode   (0b00 = Standard I2S mode)
        35:	LUT_DATA      <= 16'h0d10;       // [4:0]: I2S bit width = 0b10000, 16bit   (default is 24 0b11000)
      
        default:LUT_DATA     <= 16'h9803;       // Must be set to 0x03 for proper operation
    endcase
  end
endmodule
