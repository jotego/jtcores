`timescale 1ns/1ps

/*

	Game test

*/

module game_test;
	`ifdef DUMP
	initial begin
		// #(200*100*1000*1000);
		$display("DUMP ON");
		$dumpfile("test.lxt");
		//$dumpvars(0,UUT);
		$dumpvars(0,game_test);
		//$dumpvars(0,UUT.chargen);
		$dumpon;
	end
	`endif

	//initial #(200*1000) $finish;
	// initial #(60*1000*1000) $finish;
	initial #(120*1000*1000) $finish;
/*
	integer fincnt;
	initial begin
		for( fincnt=0; fincnt<50; fincnt=fincnt+1 )
			#(100*1000*1000);
		$finish;
	end
*/
reg rst, clk_pxl, clk_rgb, clk_rom;

initial begin
	clk_rom=1'b0;
	forever clk_rom = #6.173 ~clk_rom; //6.000
end

initial begin
	clk_pxl =1'b0;
	forever clk_pxl  = #83.340 ~clk_pxl ; //81
end

initial begin
	clk_rgb =1'b0;
	forever clk_rgb  = #20.835 ~clk_rgb ; //20.25
end

reg rst_base;

initial begin
	rst_base = 1'b0;
	#500 rst_base = 1'b1;
	#2500 rst_base=1'b0;
end
/*
integer clk_cnt;

always @(posedge clk_rom or posedge rst_base) begin
	if(rst_base) begin
		clk_cnt <= 0;
		clk <= 1'b1;
	end else begin
		clk_cnt <= clk_cnt!=13 ? clk_cnt+1 : 0;
		if( clk_cnt==0 ) clk <= ~clk;
	end
end
*/
integer rst_cnt;

always @(negedge clk_pxl or posedge rst_base)
	if( rst_base ) begin
		rst <= 1'b1; 
		rst_cnt <= 2;
	end else begin
		if(rst_cnt) rst_cnt<=rst_cnt-1;
		else rst<=rst_base;
	end

wire [3:0] red, green, blue;
wire LHBL, LVBL;

wire [15:0] SDRAM_DQ;
wire [12:0] SDRAM_A;
wire [ 1:0] SDRAM_BA;

wire	SPI_DO;
reg		SPI_DI;
reg		SPI_SCK;
reg		SPI_SS2;
reg		SPI_SS3;
reg		SPI_SS4;
reg		CONF_DATA0;

jtgng_game UUT (
	.rst		( rst		),
	.clk		( clk_pxl	),
	.clk_rom	( clk_rom	),
	.clk_rgb    ( clk_rgb   ),
	.red		( red		),
	.green		( green		),
	.blue		( blue		),
	.LHBL		( LHBL 		),
	.LVBL		( LVBL 		),

	.SDRAM_DQ	( SDRAM_DQ 	),
	.SDRAM_A	( SDRAM_A 	),
	.SDRAM_DQML	( SDRAM_DQML),
	.SDRAM_DQMH	( SDRAM_DQMH),
	.SDRAM_nWE	( SDRAM_nWE ),
	.SDRAM_nCAS	( SDRAM_nCAS),
	.SDRAM_nRAS	( SDRAM_nRAS),
	.SDRAM_nCS	( SDRAM_nCS ),
	.SDRAM_BA	( SDRAM_BA 	),
	.SDRAM_CLK	( SDRAM_CLK ),
	.SDRAM_CKE	( SDRAM_CKE ),

	.SPI_DO		( SPI_DO	),
	.SPI_DI		( SPI_DI	),
	.SPI_SCK	( SPI_SCK	),
	.SPI_SS2	( SPI_SS2	),
	.SPI_SS3	( SPI_SS3	),
	.SPI_SS4	( SPI_SS4	),
	.CONF_DATA0	( CONF_DATA0),
);

mt48lc16m16a2 mist_sdram (
	.Dq			( SDRAM_DQ		),
	.Addr   	( SDRAM_A  		),
	.Ba			( SDRAM_BA 		),
	.Clk		( SDRAM_CLK		),
	.Cke		( SDRAM_CKE		),
	.Cs_n   	( SDRAM_nCS  	),
	.Ras_n  	( SDRAM_nRAS 	),
	.Cas_n  	( SDRAM_nCAS 	),
	.We_n   	( SDRAM_nWE  	),
	.Dqm		( {SDRAM_DQMH,SDRAM_DQML} 	)
);

`ifdef VGACONV
reg clk_vga;
wire [3:0] VGA_R, VGA_G, VGA_B;
wire VGA_HS, VGA_VS;

initial begin
	clk_vga =1'b0;
	forever clk_vga  = #20.063 ~clk_vga ; //20
end

jtgng_vga vga_conv (
	.clk_gng  	( clk_pxl		), //  6 MHz
	.clk_vga  	( clk_vga		), // 25 MHz
	.rst      	( rst			),
	.red      	( red			),
	.green    	( green			),
	.blue     	( blue			),
	.LHBL     	( LHBL			),
	.LVBL     	( LVBL			),
	.vga_red  	( VGA_R			),
	.vga_green	( VGA_G			),
	.vga_blue 	( VGA_B			),
	.vga_hsync	( VGA_HS		),
	.vga_vsync	( VGA_VS		)
);
`ifdef CHR_DUMP
integer frame_cnt;
reg enter_hbl, enter_vbl;
always @(posedge clk_vga) begin
	if( rst ) begin
		enter_hbl <= 1'b0;
		enter_vbl <= 1'b0;
		frame_cnt <= 0;
	end else begin
		enter_hbl <= VGA_HS;
		enter_vbl <= VGA_VS;
		if( enter_vbl != VGA_VS && !VGA_VS) begin
			$write(")]\n# New frame\nframe_%d=[(\n", frame_cnt);
			frame_cnt <= frame_cnt + 1;
		end
		else
		if( enter_hbl != VGA_HS && !VGA_HS)
			$write("),\n(");
		else
			if( VGA_HS ) $write("%d,%d,%d,",red*8'd16,green*8'd16,blue*8'd16);
	end
end
`endif

`elsif CHR_DUMP
integer frame_cnt;
reg enter_hbl, enter_vbl;
always @(posedge clk_pxl) begin
	if( rst ) begin
		enter_hbl <= 1'b0;
		enter_vbl <= 1'b0;
		frame_cnt <= 0;
	end else begin
		enter_hbl <= LHBL;
		enter_vbl <= LVBL;
		if( enter_vbl != LVBL && !LVBL) begin
			$write(")]\n# New frame\nframe_%d=[(\n", frame_cnt);
			frame_cnt <= frame_cnt + 1;
		end
		else
		if( enter_hbl != LHBL && !LHBL)
			$write("),\n(");
		else
			if( LHBL ) $write("%d,%d,%d,",red*8'd16,green*8'd16,blue*8'd16);
	end
end

`endif

`ifdef LOADROM
integer file;

localparam UIO_FILE_TX      = 8'h53;
localparam UIO_FILE_TX_DAT  = 8'h54;
localparam UIO_FILE_INDEX   = 8'h55;
localparam TX_LEN			= 32'd794633

reg [7:0] rom_buffer[0:TX_LEN-1];

initial begin
	file=$fopen("JTGNG.rom","rb");
	$fread( rom_buffer, file );
	$fclose(file);
end

integer tx_cnt, spi_st;

localparam SPI_INIT=0, SPI_TX=1;

always @(posedge clk_rgb or posedge rst) begin
	if( rst ) begin 
		tx_cnt <= 0;
		spi_st <= 0;
	end
	else
	case( spi_st )
		0: 
	endcase
end

`else 
initial begin
	SPI_DI = 1'b0;
	SPI_SCK = 1'b0;
	SPI_SS2 = 1'b0;
	SPI_SS3 = 1'b0;
	SPI_SS4 = 1'b0;
	CONF_DATA0 = 1'b0;
end
`endif

endmodule // jt_gng_a_test