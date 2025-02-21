module k007779	(
				input clk2,
				input p1h,
				input clr_n,
				input v1,
				input hsync_n,
				input vcen,
				input syld
				);

wire [3:0] v;
wire [7:0] h;

C43_4bit_cnt b1	(
				.d(4'b1100),
				.l_n(syld),
				.ck(clk2),
				.en(vcen),
				.ci(vcen),
				.cl_n(clr_n),
				.q   (v),
				.co()
				);

C43_4bit_cnt a1	(
				.d(4'b0000),
				.l_n(1'b1),
				.ck(clk2),
				.en(p1h),
				.ci(p1h),
				.cl_n(clr_n),
				.q   (h[3:0]),
				.co()
				);

C43_4bit_cnt g1	(
				.d(4'b1111),
				.l_n(1'b1),
				.ck(!h[3]),
				.en(1'b1),
				.ci(1'b1),
				.cl_n(clr_n),
				.q   (h[7:4]),
				.co()
				);

endmodule