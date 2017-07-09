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
	initial #(67*1000*1000) $finish;
	//initial #(120*1000*1000) $finish;

reg rst, clk_pxl, clk_rgb, clk_rom;

initial begin
	clk_rom=1'b0;
	forever clk_rom = #6 ~clk_rom;
end

initial begin
	clk_pxl =1'b0;
	forever clk_pxl  = #81 ~clk_pxl ;
end

initial begin
	clk_rgb =1'b0;
	forever clk_rgb  = #20.25 ~clk_rgb ;
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

jtgng_game UUT (
	.rst		( rst		),
	.clk		( clk_pxl	),
	.clk_rom	( clk_rom	),
	.clk_rgb    ( clk_rgb   ),
	.red		( red		),
	.green		( green		),
	.blue		( blue		),
	.LHBL		( LHBL 		),
	.LVBL		( LVBL 		)
);

`ifdef CHR_DUMP
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
			if(frame_cnt==6) $finish;
		end
		else
		if( enter_hbl != LHBL && !LHBL)
			$write("),\n(");
		else
			if( LHBL ) $write("%d,%d,%d,",red*8'd16,green*8'd16,blue*8'd16);
	end
end
`endif

endmodule // jt_gng_a_test