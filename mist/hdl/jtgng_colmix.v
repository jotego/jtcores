`timescale 1ns/1ps

module jtgng_colmix(
	input			rst,
	input			clk_rgb,	// 6MHz*4=24 MHz
	//input			clk_pxl,	// 6MHz
	// Synchronization
	//input [2:0]		H,
	// characters
	input [1:0]		chr_col,
	input [3:0]		chr_pal,		// character color code
	// scroll
	input [2:0]		scr_col,
	input [2:0]		scr_pal,
	// objects
	input [5:0]		obj_pxl,
	// Debug
	input			enable_char,
	input			enable_obj,
	// CPU inteface
	input [7:0]		AB,
	input			blue_cs,
	input			redgreen_cs,
	input [7:0]		DB,
	input			LVBL,
	input			LHBL,	

	output 	reg [3:0]	red,
	output 	reg [3:0]	green,
	output 	reg [3:0]	blue
);

reg addr_top;
reg aux, we;
wire [7:0] dout;

//wire [7:0] pixel_mux = { 2'b11, chr_pal, chr_col };

//reg char_win, scr_win, obj_win;
`ifdef OBJTEST
wire [7:0] pixel_mux = {2'b01,obj_pxl};
`else
reg [7:0] pixel_mux;
always @(*) begin	
	if( chr_col==2'b11 || !enable_char ) begin
		// Object or scroll
		if( &obj_pxl[3:0] || !enable_obj)
			pixel_mux = {2'b00, scr_pal, scr_col }; // scroll wins
		else
			pixel_mux = {2'b01, obj_pxl }; // object wins
		//{ char_win, scr_win, obj_win } = 3'b010;
	end
	else begin // characters
		pixel_mux = { 2'b11, chr_pal, chr_col };
		//{ char_win, scr_win } = 2'b10;
	end
end
`endif

reg [3:0] aux_red, aux_green, aux_blue;

always @(negedge clk_rgb)
	if( rst ) begin
		{ addr_top, aux } <= 2'b00;
	end else begin
		{addr_top,aux}<={addr_top,aux}+2'b1;
		casex( {addr_top,aux} )
			2'b00: we <= redgreen_cs && !LVBL;
			2'b10: we <= blue_cs && !LVBL;
			default: we <= 1'b0;
		endcase
		// assign current pixel colour
		if( LVBL && LHBL )
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

wire [8:0] rdaddress = {addr_top, pixel_mux};
wire [8:0] wraddress = {addr_top, AB };

// RAM
jtgng_rgbram RAM(
	.clock		( clk_rgb	),
	.data		( DB		),
	.rdaddress	( rdaddress	),
	.wraddress	( wraddress	),
	.wren		( we		),
	.q			( dout		)
);

endmodule // jtgng_colmix