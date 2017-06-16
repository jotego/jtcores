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
		$dumpvars(0,UUT);
		$dumpon;
	end
	`endif

	initial #(60*1000*1000) $finish;
	//initial #(120*1000*1000) $finish;

reg rst, clk;

initial begin
	clk=1'b0;
	forever clk = #167 ~clk;
end

initial begin
	rst = 1'b0;
	#500 rst = 1'b1;
	#2500 rst=1'b0;
end


jtgng_main UUT (
	.rst		( rst		),
	.clk		( clk		)
);


endmodule // jt_gng_a_test