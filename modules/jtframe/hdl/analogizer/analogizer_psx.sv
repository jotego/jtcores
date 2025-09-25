
// convert dualshock to Analogizer Analogue Pocket format
// @RndMnkIII. 11/2024
//Analogue pocket format 
//key1
// Pocket logic button order:
// [0]     dpad_up
// [1]     dpad_down
// [2]     dpad_left
// [3]     dpad_right
// [4]     face_a
// [5]     face_b
// [6]     face_x
// [7]     face_y
// [8]     trig_l1
// [9]     trig_r1
// [10]    trig_l2
// [11]    trig_r2
// [12]    trig_l3
// [13]    trig_r3
// [14]    face_select
// [15]    face_start      
// [28:16] <unused>
// [31:28] type:
// Type Field (4 bits)	Description
// 0x0	Nothing connected
// 0x1	Pocket built-in buttons (only possible on Player 1)
// 0x2	Docked game controller, no analog support
// 0x3	Docked game controller, analog support
// 0x4	Docked keyboard
// 0x5	Docked mouse
// 0x7-0xF	Reserved
//JOY
// [31:0]  joy
// [ 7: 0] lstick_x
// [15: 8] lstick_y
// [23:16] rstick_x
// [31:24] rstick_y  

module analogizer_psx #(parameter MASTER_CLK_FREQ=50_000_000) (
    input i_clk,
	input i_rst,
	input i_ena,
	input i_stb,
	//Pocket control interface
    output reg [15:0] key1,
    output reg [31:0] joy1,
	output reg [15:0] key2,
    output reg [31:0] joy2,
	//PSX INTERFACE

	input [1:0] i_VIB_SW1,  //  Vibration SW  VIB_SW[0] Small Moter OFF 0:ON  1:
                           //VIB_SW[1] Bic Moter   OFF 0:ON  1(Dualshook Only)
	input [7:0] i_VIB_DAT1,  //  Vibration(Bic Moter)Data   8'H00-8'HFF (Dualshook Only)
    input [1:0] i_VIB_SW2,
	input [7:0] i_VIB_DAT2,  
	output PSX_CLK,
    input  PSX_DAT,
    output PSX_CMD,
    output PSX_ATT1,
	output PSX_ATT2,
	input  PSX_ACK,
	//output PSX_IRQ
	output wire [3:0] DBG_TX
);
	logic [7:0] rx0, rx1, rx2, rx3, rx4, rx5, rx6;
	logic [7:0] RXD_ID;
    reg att1r, att2r;
	//reg [3:0] id1, id2;
	reg no_gamepad;
	//reg send_bytes1_stb, send_bytes2_stb;

	always @(posedge i_clk) begin
		no_gamepad <= (&RXD_ID) & (&rx0); //both are FF no device detected
		att1r <= PSX_ATT1;
		att2r <= PSX_ATT2;
		//send_bytes1_stb <= 0;
		//send_bytes2_stb <= 0;

		if (~att1r & PSX_ATT1) begin //capture when ATT1 becomes idle
			//send_bytes1_stb <= 1;

			if(no_gamepad) begin //no gamepad detected, default data
				key1 <= 16'h00;
				joy1 <= 32'h80808080; //neutral position
			end
			else
			begin
				//       START    SELECT  R3      L3      R2      L2      R1      L1      Y       X       B       A       LEFT    RIGHT   DOWN    UP 
				key1 <= {~rx1[3], ~rx1[0],~rx1[2],~rx1[1],~rx2[1],~rx2[0],~rx2[3],~rx2[2],~rx2[7],~rx2[4],~rx2[6],~rx2[5],~rx1[5],~rx1[7],~rx1[6],~rx1[4]};    
				//       rstick_y rstick_x lstick_y lstick_x
				joy1 <= {rx4,rx3,rx6,rx5};
			end
		end
		else if(~att2r & PSX_ATT2) begin //capture when ATT2 becomes idle
			//send_bytes2_stb <= 1;

			if(no_gamepad) begin //no gamepad detected, default data
				key2 <= 16'h00;
				joy2 <= 32'h80808080; //neutral position
			end
			else
			begin
				//       START    SELECT  R3      L3      R2      L2      R1      L1      Y       X       B       A       LEFT    RIGHT   DOWN    UP 
				key2 <= {~rx1[3], ~rx1[0],~rx1[2],~rx1[1],~rx2[1],~rx2[0],~rx2[3],~rx2[2],~rx2[7],~rx2[4],~rx2[6],~rx2[5],~rx1[5],~rx1[7],~rx1[6],~rx1[4]};    
				//       rstick_y rstick_x lstick_y lstick_x
				joy2 <= {rx4,rx3,rx6,rx5};
			end
		end
	end
    //assign DBG_TX = {PSX_ATT1,PSX_CLK,PSX_CMD,PSX_DAT}; //r_Tx_DV;
	//assign DBG_TX = {dbgtx,dbgtx,dbgtx,1'b0};
	assign DBG_TX = {4'b0000};
	// Dualshock controller

	dualshock_controller #(.FREQ(MASTER_CLK_FREQ)) ds1 (
		.clk(i_clk), .i_RSTn(~i_rst), .i_ena(i_ena), .i_stb(i_stb),
		.i_MULTITAP_ena(1'b0), .i_VIB_SW1(i_VIB_SW1), .i_VIB_DAT1(i_VIB_DAT1), .i_VIB_SW2(i_VIB_SW2), .i_VIB_DAT2(i_VIB_DAT2), 
		.o_psCLK(PSX_CLK), .o_ATT1(PSX_ATT1), .o_ATT2(PSX_ATT2),  .o_psTXD(PSX_CMD),
		.i_psRXD(PSX_DAT), .i_psACK(PSX_ACK),
		.o_RXD_ID(RXD_ID), .o_RXD_0(rx0),
		.o_RXD_1(rx1), .o_RXD_2(rx2), .o_RXD_3(rx3),
		.o_RXD_4(rx4), .o_RXD_5(rx5), .o_RXD_6(rx6)
	);

	//debug as UART TX at 500000bps
//	   wire [7:0]            lut[15:0]; 
//
//   assign lut[0]=8'h30;    	// ascii 0 
//   assign lut[1]=8'h31;     //  ascii 1
//   assign lut[2]=8'h32;    	// ascii 2 
//   assign lut[3]=8'h33;    	// ascii 3 
//   assign lut[4]=8'h34;    	// ascii 4 
//   assign lut[5]=8'h35;    	// ascii 5 
//   assign lut[6]=8'h36;    	// ascii 6 
//   assign lut[7]=8'h37;    	// ascii 7 
//   assign lut[8]=8'h38;    	// ascii 8 
//   assign lut[9]=8'h39;    	// ascii 9 
//   assign lut[10]=8'h41;    //  ascii A
//   assign lut[11]=8'h42;     //  ascii B
//   assign lut[12]=8'h43;    //  ascii C
//   assign lut[13]=8'h44;    //  ascii D
//   assign lut[14]=8'h45;    //  ascii E
//   assign lut[15]=8'h46;    //  ascii F
//
//	reg r_Tx_DV;
//	wire w_Tx_Done;
//	reg [7:0] r_Tx_Byte;
//	reg r_Rx_Serial;
//
//	//cycle bytes to send
//	reg [5:0] byte_cnt;
//
//	always @(posedge i_clk) begin
//		r_Tx_DV  <= 1'b0;
//		if(~i_rst) begin 
//			byte_cnt <= 6'd0;
//			r_Tx_DV  <= 1'b0;
//		end
//		else begin
//			if(send_bytes1_stb || send_bytes2_stb) begin
//				byte_cnt <= 6'd1;
//				r_Tx_DV  <= 1'b1;
//			end
//			else begin
//				if ((byte_cnt < 6'd27) && w_Tx_Done) begin
//					byte_cnt <= byte_cnt + 6'd1;
//					r_Tx_DV  <= 1'b1;
//				end
//			end
//		end
//	end
//
//	always@(*) begin
//		case(byte_cnt)
//			6'd01:   r_Tx_Byte = "R";
//			6'd02:   r_Tx_Byte = "x";
//			6'd03:   r_Tx_Byte = ":";
//			6'd04:   r_Tx_Byte = lut[RXD_ID[7:4]];
//			6'd05:   r_Tx_Byte = lut[RXD_ID[3:0]];
//			6'd07:   r_Tx_Byte = lut[rx0[7:4]];
//			6'd08:   r_Tx_Byte = lut[rx0[3:0]];
//			6'd10:   r_Tx_Byte = lut[rx1[7:4]];
//			6'd11:   r_Tx_Byte = lut[rx1[3:0]];
//			6'd13:   r_Tx_Byte = lut[rx2[7:4]];
//			6'd14:   r_Tx_Byte = lut[rx2[3:0]];
//			6'd16:   r_Tx_Byte = lut[rx3[7:4]];
//			6'd17:   r_Tx_Byte = lut[rx3[3:0]];
//			6'd19:   r_Tx_Byte = lut[rx4[7:4]];
//			6'd20:   r_Tx_Byte = lut[rx4[3:0]];
//			6'd22:   r_Tx_Byte = lut[rx5[7:4]];
//			6'd23:   r_Tx_Byte = lut[rx5[3:0]];
//			6'd25:   r_Tx_Byte = lut[rx6[7:4]];
//			6'd26:   r_Tx_Byte = lut[rx6[3:0]];
//			6'd27:   r_Tx_Byte = 8'h0D; //carriage return
//			default: r_Tx_Byte = " ";
//		endcase
//	end

	//i_clk 48_000_000
//	wire dbgtx;
//	uart_tx #(.CLKS_PER_BIT(96)) UART_TX_INST
//    (.i_Clock(i_clk),
//     .i_Tx_DV(r_Tx_DV), //enable to send byte
//     .i_Tx_Byte(r_Tx_Byte),
//     .o_Tx_Active(),
//     .o_Tx_Serial(dbgtx),
//     .o_Tx_Done(w_Tx_Done)
//     );
endmodule