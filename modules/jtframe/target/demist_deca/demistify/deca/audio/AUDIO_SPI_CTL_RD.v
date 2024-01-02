module AUDIO_SPI_CTL_RD(
 input  iRESET_n,
 input	iCLK_50,
 output	oCS_n,
 output	oSCLK,
 output	oDIN,
 input	iDOUT
);

 reg  [7:0]   ST;
 reg  [7:0]   COUNTER;
 reg  [15:0]  W_REG_DATA;
 reg  [15:0]  W_REG_DATA_T;
 reg  [15:0]  W_REG_DATA_R;
 reg  [15:0]  READ_DATA;
 reg  [7:0]   WORD_CNT;
 reg          W_R;
 reg [1:0]    OK2;

//== ASSIGN TO OUTPUT ===
assign  RESET_n = iRESET_n  ; 
assign  oCS_n = CS;
assign  oDIN  = DIN;
assign  oSCLK = SCLK;
assign  CLK_50= iCLK_50;
assign  DOUT  = iDOUT; 

//======== REG =========== 
wire  RESET_n  ; 
reg 	CS;
reg		DIN;
reg  	SCLK;
wire 	DOUT; 
wire 	CLK_50;
					

//==SET REGISTER NUM====
parameter    W_WORD_NUM  = 128;

//== 1M CLOCK GEN ==
reg        CLK_1M ;
reg [15:0] CLK_DELAY ;
always @ (posedge  CLK_50)  begin
if  ( CLK_DELAY  > 62  )   // 25= 1M clock  / 62 =400k
  begin
    CLK_DELAY <= 0;
	 CLK_1M    <= ~CLK_1M;
	end
	else CLK_DELAY <= CLK_DELAY + 16'd1;
end

//==== SPI ST === // 
always@( negedge RESET_n or posedge CLK_1M )begin
if (!RESET_n) begin   
       ST       <=0;
		 CS       <=1; 
		 SCLK     <=1;
		 OK2      <=0;
		 ROM_CK   <=0;
		 WORD_CNT <=0; 
end
else 
 case (ST)
	0:begin 
       ST       <=1;
		 CS       <=1; 
		 SCLK     <=1;
		 WORD_CNT <=0;
  end   
 //--- WRITE REGISTER ---  
	1:begin 
       ST       <=30;
		 CS       <=1;  
		 SCLK     <=0;
		 COUNTER  <=0;
		 ROM_CK   <=1;
  end 
	2:begin 
       ST       <=3;
		 CS       <=0; //<----CS 0
		 SCLK     <=1; 
		 {DIN, W_REG_DATA[15:1] } <= W_REG_DATA[15:0] ;
		 
  end  
	3:begin 
       ST       <=4;
		 SCLK     <=1;
  end 
	4:begin 
       ST       <=5;
		 SCLK     <=0;
		 READ_DATA[15:0]  <= {READ_DATA[14:0], DOUT } ; 
		 COUNTER  <=COUNTER+ 8'd1 ;
  end 
	5:begin 
       if (COUNTER !=16)  ST <=2;
		 else begin 
		       if (W_R==0) begin 
				   	READ_DATA <=0; 
					   W_R<=1; 
					   W_REG_DATA <= { W_REG_DATA_R[15:8] ,8'hff } ; 
					   CS <=1; 
					   ST <= 2 ; 	
					   SCLK     <=0;  
					   COUNTER  <=0; 
					end  //read
				 else  begin 
				   WORD_CNT <= WORD_CNT+8'd1 ;
				   ST <=6; 
				   CS <=1; //<----CS 1
				 end
				end
  end   
	6:begin 
	   if       (( WORD_CNT == 34 ) &&  (READ_DATA[7:0]==8'h01))    
	   		OK2 <= OK2 | 2'b01  ;
	   else if  (( WORD_CNT == 35 ) &&  (READ_DATA[7:0]==8'h00))    
	   		OK2 <= OK2 | 2'b10 ;
				
      if ( WORD_CNT != W_WORD_NUM )  
	  		ST<=1 ; 
		else   
			ST<=7;
  end 
	7:begin 
        ST<=ST;
  end 
//-----END-ST-------------------  
//-----WRITE REGISTER TABLE-----
	29:begin
	  W_REG_DATA   <= {W_REG_DATA_T[14:8],1'b0,W_REG_DATA_T[7:0] };
	  W_REG_DATA_R <= {W_REG_DATA_T[14:8],1'b1,W_REG_DATA_T[7:0] };
	  W_R <=0;
	  ST <= 2 ;    
   end  	
	30:begin    
     ROM_CK  <=0;  
	  if (( WORD_CNT >=0 ) &&  (WORD_CNT <=127 ) ) W_REG_DATA_T [15:0]<= REG_DATA [15:0]  ; 
	  ST <= 29 ;
  end          
 endcase      
end     


//--------ROM/RAM Table for Audio Codec  Register ----
wire [15:0]REG_DATA ; 
reg        ROM_CK ; 

SPI_RAM R(
	.address(WORD_CNT[6:0]),
	.clock(ROM_CK),
	.data(),
	.wren (1'b0),
	.q(REG_DATA)
	);

endmodule
