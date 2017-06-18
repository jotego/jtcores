`timescale 1ns/1ps

module jtgng_game(
	input			rst,
	input			clk	// 6MHz
);

	wire [8:0] V;
	wire [8:0] H;
	wire Hinit;
	wire LHBL;
	wire LVBL;

	wire [12:0] cpu_AB;
	wire char_cs;
	wire flip;
	wire [7:0] cpu_dout, char_dout;
	wire rd;
	wire char_mrdy;
	wire [13:0] char_addr;
	wire [7:0] char_data = 8'h00;
	wire [1:0] char_col;

jtgng_timer timers (.clk(clk), .rst(rst), .V(V), .H(H), .Hinit(Hinit), .LHBL(LHBL), .LVBL(LVBL));

	wire RnW;

jtgng_char chargen (
	.clk      ( clk      	),
	.AB       ( cpu_AB[10:0]),
	.V128     ( V[7:0]   	),
	.H128     ( H[7:0]   	),
	.char_cs  ( char_cs  	),
	.flip     ( flip     	),
	.din      ( cpu_dout 	),
	.dout     ( char_dout	),
	.rd       ( RnW      	),
	.MRDY_b   ( char_mrdy	),
	.char_addr( char_addr	),
	.char_data( char_data	),
	.char_col ( char_col 	)
);

	wire bus_ack, bus_req;
	wire [17:0] rom_addr;
	wire [7:0] rom_dout;
jtgng_main main (
	.clk      	( clk      	),
	.rst      	( rst      	),
	.ch_mrdy  	( char_mrdy	),
	.char_dout	( char_dout	),
	.LVBL     	( LVBL     	),
	.cpu_dout 	( cpu_dout 	),
	.char_cs  	( char_cs  	),
	.flip		( flip		),
	.bus_ack 	( bus_ack  	),
	.cpu_AB	 	( cpu_AB	),
	.RnW	 	( RnW		),
	.rom_addr	( rom_addr 	),
	.rom_dout	( rom_dout 	)
);


endmodule // jtgng