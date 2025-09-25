module psx_control(clk_50mhz,
	I_psRXD,
	O_psCLK,
	O_psSEL,
	O_psTXD,
	O_l1,
	O_l2,
	O_r1,
	O_r2,
	O_l3,
	O_r3,
	O_d_pad_up,
	O_d_pad_down,
	O_d_pad_left,
	O_d_pad_right,
	O_square,
	O_triangle,
	O_circle,
	O_x,
	O_select,
	O_start,
	O_analog1_left_right,
	O_analog2_left_right,
	O_analog1_up_down,
	O_analog2_up_down,
	switches
	);
	
input	clk_50mhz; //  50Mhz
input  I_psRXD;
output O_psCLK;
output O_psSEL;
output O_psTXD;
output	O_l1;
output	O_l2;
output	O_r1;
output	O_r2;
output O_l3;
output O_r3;
output	O_d_pad_up;
output	O_d_pad_down;
output	O_d_pad_left;
output	O_d_pad_right;
output	O_square;
output	O_triangle;
output	O_circle;
output	O_x;
output	O_select;
output	O_start;
output	[7:0]O_analog1_left_right;
output	[7:0]O_analog2_left_right;
output	[7:0]O_analog1_up_down;
output	[7:0]O_analog2_up_down;	
input [1:0]switches;


wire [7:0]data_to_psx1;
wire [7:0]data_to_psx2;
wire [7:0]data_to_psx3;
wire [7:0]data_to_psx4;
wire [7:0]data_to_psx5;
wire [7:0]data_to_psx6;


// BUTTONS PSX
assign O_d_pad_up=~data_to_psx1[4];
assign O_d_pad_down=~data_to_psx1[6];
assign O_d_pad_left=~data_to_psx1[5];
assign O_d_pad_right=~data_to_psx1[7];

assign O_select=~data_to_psx1[0];
assign O_start=~data_to_psx1[3];
assign O_l3=~data_to_psx1[1];
assign O_r3=~data_to_psx1[2];
assign O_l1=~data_to_psx2[2];
assign O_r1=~data_to_psx2[3];
assign O_l2=~data_to_psx2[0];
assign O_r2=~data_to_psx2[1];
assign O_triangle=~data_to_psx2[4];
assign O_square=~data_to_psx2[7];
assign O_circle=~data_to_psx2[5];
assign O_x=~data_to_psx2[6];

assign O_analog1_left_right=data_to_psx3[7:0];
assign O_analog2_left_right=data_to_psx5[7:0];
assign O_analog1_up_down=data_to_psx4[7:0];
assign O_analog2_up_down=data_to_psx6[7:0];


wire CLK_FSM_PSX;

/*DIVISOR DE FRECUENCIA PARA GENERAR CLK DE LA FSM DEL DECODIFICADOR DE PSX*/
pll	pll_inst (
	.inclk0 ( clk_50mhz ),
	.c0 ( CLK_FSM_PSX ),
	.c1 ( )
	);


psPAD_top psPAD_top_inst
(
	.I_CLK250K(CLK_FSM_PSX) ,	// input  I_CLK250K_sig
	.I_RSTn(1'b1) ,	// input  I_RSTn_sig
	.O_psCLK(O_psCLK) ,	// output  O_psCLK_sig
	.O_psSEL(O_psSEL) ,	// output  O_psSEL_sig
	.O_psTXD(O_psTXD) ,	// output  O_psTXD_sig
	.I_psRXD(I_psRXD) ,	// input  I_psRXD_sig
	.O_RXD_1(data_to_psx1) ,	// output [7:0] O_RXD_1_sig
	.O_RXD_2(data_to_psx2) ,	// output [7:0] O_RXD_2_sig
	.O_RXD_3(data_to_psx3) ,	// output [7:0] O_RXD_3_sig
	.O_RXD_4(data_to_psx4) ,	// output [7:0] O_RXD_4_sig
	.O_RXD_5(data_to_psx5) ,	// output [7:0] O_RXD_5_sig
	.O_RXD_6(data_to_psx6) ,	// output [7:0] O_RXD_6_sig
	.I_CONF_SW(1'b1) ,	// input  I_CONF_SW_sig
	.I_MODE_SW(1'b1) ,	// input  I_MODE_SW_sig
	.I_MODE_EN(1'b1) ,	// input  I_MODE_EN_sig
	.I_VIB_SW(switches) ,	// input [1:0] I_VIB_SW_sig
	.I_VIB_DAT(8'hff) 	// input [7:0] I_VIB_DAT_sig
);



endmodule
