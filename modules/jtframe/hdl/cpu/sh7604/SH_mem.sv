// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module SH_regram (
	clock,
	data,
	rdaddress,
	wraddress,
	wren,
	q);

	input	  clock;
	input	[31:0]  data;
	input	[4:0]  rdaddress;
	input	[4:0]  wraddress;
	input	  wren;
	output	[31:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0	  wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [31:0] sub_wire0;
	wire [31:0] q = sub_wire0[31:0];

//	altsyncram	altsyncram_component (
//				.address_a (wraddress),
//				.address_b (rdaddress),
//				.clock0 (clock),
//				.clock1 (~clock),
//				.data_a (data),
//				.wren_a (wren),
//				.q_b (sub_wire0),
//				.aclr0 (1'b0),
//				.aclr1 (1'b0),
//				.addressstall_a (1'b0),
//				.addressstall_b (1'b0),
//				.byteena_a (1'b1),
//				.byteena_b (1'b1),
//				.clocken0 (1'b1),
//				.clocken1 (1'b1),
//				.clocken2 (1'b1),
//				.clocken3 (1'b1),
//				.data_b ({32{1'b1}}),
//				.eccstatus (),
//				.q_a (),
//				.rden_a (1'b1),
//				.rden_b (1'b1),
//				.wren_b (1'b0));
//	defparam
//		altsyncram_component.address_aclr_b = "NONE",
//		altsyncram_component.address_reg_b = "CLOCK1",
//		altsyncram_component.clock_enable_input_a = "BYPASS",
//		altsyncram_component.clock_enable_input_b = "BYPASS",
//		altsyncram_component.clock_enable_output_b = "BYPASS",
//		altsyncram_component.intended_device_family = "Cyclone V",
//		altsyncram_component.lpm_type = "altsyncram",
//		altsyncram_component.numwords_a = 32,
//		altsyncram_component.numwords_b = 32,
//		altsyncram_component.operation_mode = "DUAL_PORT",
//		altsyncram_component.outdata_aclr_b = "NONE",
//		altsyncram_component.outdata_reg_b = "UNREGISTERED",
//		altsyncram_component.power_up_uninitialized = "FALSE",
//		altsyncram_component.widthad_a = 5,
//		altsyncram_component.widthad_b = 5,
//		altsyncram_component.width_a = 32,
//		altsyncram_component.width_b = 32,
//		altsyncram_component.width_byteena_a = 1;
		
	altdpram	altdpram_component (
				.data (data),
				.inclock (clock),
				.outclock (clock),
				.rdaddress (rdaddress),
				.wraddress (wraddress),
				.wren (wren),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.outclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 32,
		altdpram_component.widthad = 5,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";

endmodule
