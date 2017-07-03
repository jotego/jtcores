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

	initial #(5*1000*1000) $finish;
	//initial #(120*1000*1000) $finish;

reg rst, clk, clk_rom;

initial begin
	clk_rom=1'b0;
	forever clk_rom = #6.173 ~clk_rom;
end


reg rst_base;

initial begin
	rst_base = 1'b0;
	#500 rst_base = 1'b1;
	#2500 rst_base=1'b0;
end

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

integer rst_cnt;

always @(negedge clk or posedge rst_base)
	if( rst_base ) begin
		rst <= 1'b1; 
		rst_cnt <= 2;
	end else begin
		if(rst_cnt) rst_cnt<=rst_cnt-1;
		else rst<=rst_base;
	end


jtgng_game UUT (
	.rst		( rst		),
	.clk		( clk		),
	.clk_rom	( clk_rom	)
);


endmodule // jt_gng_a_test