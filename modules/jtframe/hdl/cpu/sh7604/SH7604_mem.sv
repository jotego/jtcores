// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module CACHE_RAM (
	data,
	rdaddress,
	rdclock,
	wraddress,
	wrclock,
	wren,
	q);

	input	[7:0]  data;
	input	[9:0]  rdaddress;
	input	  rdclock;
	input	[9:0]  wraddress;
	input	  wrclock;
	input	  wren;
	output	[7:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1	  wrclock;
	tri0	  wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [7:0] sub_wire0;
	wire [7:0] q = sub_wire0[7:0];

	altsyncram	altsyncram_component (
				.address_a (wraddress),
				.address_b (rdaddress),
				.clock0 (wrclock),
				.clock1 (rdclock),
				.data_a (data),
				.wren_a (wren),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({8{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK1",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 1024,
		altsyncram_component.numwords_b = 1024,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.widthad_a = 10,
		altsyncram_component.widthad_b = 10,
		altsyncram_component.width_a = 8,
		altsyncram_component.width_b = 8,
		altsyncram_component.width_byteena_a = 1;

endmodule


module CACHE_TAG (
	clock,
	data,
	rdaddress,
	wraddress,
	wren,
	q);

	input	  clock;
	input	[19:0]  data;
	input	[5:0]  rdaddress;
	input	[5:0]  wraddress;
	input	  wren;
	output	[19:0]  q;

	(* ramstyle = "MLAB, no_rw_check" *) reg [19:0] mem[0:63];

	assign q = mem[rdaddress];

	always @(posedge clock) begin
		if (wren) mem[wraddress] <= data;
	end

endmodule


module CACHE_LRU (
	clock,
	data,
	rdaddress,
	wraddress,
	wren,
	q);

	input	  clock;
	input	[5:0]  data;
	input	[5:0]  rdaddress;
	input	[5:0]  wraddress;
	input	  wren;
	output	[5:0]  q;

	(* ramstyle = "MLAB, no_rw_check" *) reg [5:0] mem[0:63];

	assign q = mem[rdaddress];

	always @(posedge clock) begin
		if (wren) mem[wraddress] <= data;
	end


endmodule
