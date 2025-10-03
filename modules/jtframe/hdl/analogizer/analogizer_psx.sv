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

module analogizer_psx #(parameter MASTER_CLK_FREQ=50_000_000)
(
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
	input [1:0] i_VIB_SW1,	//  Vibration SW  VIB_SW[0] Small Moter OFF 0:ON  1:
							//VIB_SW[1] Bic Moter   OFF 0:ON  1(Dualshook Only)
	input [7:0] i_VIB_DAT1,	//  Vibration(Bic Moter)Data   8'H00-8'HFF (Dualshook Only)
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
	reg no_gamepad;

	always @(posedge i_clk) begin
		no_gamepad <= (&RXD_ID) & (&rx0); //both are FF no device detected
		att1r <= PSX_ATT1;
		att2r <= PSX_ATT2;

		if (~att1r & PSX_ATT1) begin //capture when ATT1 becomes idle

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
	assign DBG_TX = {4'b0000};
	// Dualshock controller
	dualshock_controller #(.FREQ(MASTER_CLK_FREQ)) ds1
	(
		.clk(i_clk),
		.i_RSTn(~i_rst),
		.i_ena(i_ena),
		.i_stb(i_stb),
		.i_MULTITAP_ena(1'b0),
		.i_VIB_SW1(i_VIB_SW1),
		.i_VIB_DAT1(i_VIB_DAT1),
		.i_VIB_SW2(i_VIB_SW2),
		.i_VIB_DAT2(i_VIB_DAT2),
		.o_psCLK(PSX_CLK),
		.o_ATT1(PSX_ATT1),
		.o_ATT2(PSX_ATT2),
		.o_psTXD(PSX_CMD),
		.i_psRXD(PSX_DAT),
		.i_psACK(PSX_ACK),
		.o_RXD_ID(RXD_ID),
		.o_RXD_0(rx0),
		.o_RXD_1(rx1),
		.o_RXD_2(rx2),
		.o_RXD_3(rx3),
		.o_RXD_4(rx4),
		.o_RXD_5(rx5),
		.o_RXD_6(rx6)
	);

endmodule