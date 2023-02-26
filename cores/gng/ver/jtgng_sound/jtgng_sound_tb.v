`timescale 1ns/1ps

module jtgng_sound_tb;

reg rst, clk_pxl, clk_snd, clk_ym, V32;

initial begin
	clk_pxl =1'b0;
	forever clk_pxl  = #83.340 ~clk_pxl ; // 6
end

initial begin
	clk_snd =1'b0;
	forever clk_snd  = #166.68 ~clk_snd ; // 3
end

initial begin
	clk_ym =1'b0;
	forever clk_ym  = #666.72 ~clk_ym ; // .75
end

initial begin
	V32 =1'b0;
	forever V32  = #4096000 ~V32 ;
end

initial begin
	rst = 1'b0;
	#500 rst = 1'b1;
	#2500 rst=1'b0;
end

reg [7:0] snd_latch;
wire signed [8:0] ym_mux_right, ym_mux_left;
wire ym_mux_sample;

wire rom_cs;
wire [14:0] rom_addr;
reg [7:0] rom_dout;

reg [7:0] rom[0:2**15-1];

integer fincnt;

always @(fincnt) begin
	case( fincnt )
		   0: snd_latch = 8'h0;
		  10: snd_latch = 8'h2B;
//		 500: snd_latch = 8'h1;
//		1000: snd_latch = 8'h2;
//		1500: snd_latch = 8'h3;
//		2500: snd_latch = 8'h4;
	endcase
end

initial $readmemh("../../../rom/audio_x1.hex",rom);

always @(*)
	rom_dout = rom[rom_addr];

jtgng_sound uut(
	.clk6	( clk_pxl	),	// 6   MHz
	.clk	( clk_snd	),	// 3   MHz
	.rst	( rst		),
	.soft_rst( 1'b0		),
	// Interface with main CPU
	.sres_b	( 1'b1		),	// Z80 reset
	.snd_latch( snd_latch ),
	.V32	( V32		),
	// ROM access
	.rom_addr	( rom_addr	),
	.rom_cs		( rom_cs	),
	.rom_dout	( rom_dout	),
	.snd_wait	( 1'b1	),
	// Sound output
	.ym_mux_right	( ym_mux_right	),
	.ym_mux_left	( ym_mux_left	),
	.ym_mux_sample	( ym_mux_sample	)
);

initial begin
	for( fincnt=0; fincnt<`SIM_MS; fincnt=fincnt+1 ) begin
		#(1000*1000); // ms
		if( fincnt%5==0 ) $display("%d ms",fincnt+1);
	end
	$finish;
end

initial begin
	$display("DUMP enabled");
	$DUMPFILE("test.lxt");
	$dumpvars(1,jtgng_sound_tb.uut);
	$dumpvars(1,jtgng_sound_tb.uut.fm0.u_mmr);
	$dumpvars(1,jtgng_sound_tb.uut.fm1.u_mmr);
	$dumpvars(2,jtgng_sound_tb.uut.Z80);
	$dumpvars;
	$dumpon;
end

endmodule // jtgng_sound_tb