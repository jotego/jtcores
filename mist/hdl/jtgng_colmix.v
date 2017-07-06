`timescale 1ns/1ps

module jtgng_colmix(
	input			rst,
	input			clk_rgb,	// 6*6=36 MHz
	input [1:0]		char,
	input [3:0]		cc,		// character color code
	input [7:0]		AB,
	input			blue_cs,
	input			redgreen_cs,
	input [7:0]		DB,
	input			LVBL,
	input			LHBL,

	output 	[3:0]	red,
	output 	[3:0]	green,
	output 	[3:0]	blue
);

reg addr_top;
reg aux, we;
reg [7:0] addr_bot;
wire [8:0] addr = { addr_top, addr_bot };
wire [7:0] pixel_mux = 8'd0;
wire [7:0] dout;

wire [5:0] pixel_mux = { 2'b11, cc, char };

always @(posedge clk_rgb)
	if( rst ) begin
		{ addr_top, aux } <= 2'b00;
	end else begin
		{addr_top,aux}={addr_top,aux}+2'b1;
		addr_bot <= LVBL ? AB : pixel_mux;
		casex( {addr_top,aux} )
			2'b00: we <= redgreen_cs;
			2'b10: we <= blue_cs;
			default: we <= 1'b0;
		endcase
		// assign current pixel colour
		if( !LVBL && !LHBL )
			case( {addr_top,aux} )
				2'b01: begin
					red   <= dout[7:4];
					green <= dout[3:0];
					end
				2'b11: begin
					blue  <= dout[7:4];
					end
			endcase // {addr_top,aux}
		else
			{red, green, blue } <= 12'd0; 
	end



// RAM
jtgng_m9k #(.addrw(9)) RAM(
	.clk ( clk_rgb  ),
	.addr( addr     ),
	.din ( DB       ),
	.dout( dout     ),
	.we  ( we       )
);


endmodule // jtgng_colmix