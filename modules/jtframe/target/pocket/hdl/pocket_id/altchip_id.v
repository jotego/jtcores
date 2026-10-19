// (C) 2001-2013 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


////////////////////////////////////////////////////////////////////
//
//   ALTCHIP_ID
//
//  Copyright (C) 1991-2013 Altera Corporation
//  Your use of Altera Corporation's design tools, logic functions 
//  and other software and tools, and its AMPP partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Altera Program License 
//  Subscription Agreement, Altera MegaCore Function License 
//  Agreement, or other applicable license agreement, including, 
//  without limitation, that your use is for the sole purpose of 
//  programming logic devices manufactured by Altera and sold by 
//  Altera or its authorized distributors.  Please refer to the 
//  applicable agreement for further details.
//
////////////////////////////////////////////////////////////////////

// synthesis VERILOG_INPUT_VERSION VERILOG_2001

module  altchip_id
	( 
	clkin,
	chip_id,
	data_valid,
	reset);
	
	input	clkin;
	output	[63:0]	chip_id;
	output	data_valid;
	input	reset;
	
	parameter	DEVICE_FAMILY	= "Stratix V";	
	parameter	ID_VALUE	= 64'hffffffffffffffff;
	
	// clock cycle for shiftnld
	localparam	LOAD_WIDTH	= 'h01;	
	localparam	DATA_WIDTH	= 'h60;	// gray of binary 0100 0000, for 64 clock cycles
	
	wire  	clkin_wire;
	wire	current_state_wire;
	wire	regout_wire;
	wire	[6:0]   wire_gen_cntr_q;
	wire	[63:0]	wire_shift_reg_q;
	wire 	reset_wire;
	reg		current_state_reg;
	reg		data_valid_reg;
	reg		end_op_reg;
	reg		end_stage_pos_reg;
	reg		[63:0]	output_reg;
	reg		busy_reg;
	
	initial begin
		current_state_reg = 1'b0;
		data_valid_reg = 1'b0;
		end_op_reg = 1'b0;
		end_stage_pos_reg = 1'b0;
		output_reg = 64'h0000000000000000;
		busy_reg = 1'b0;
	end
	
	// clkin and reset input
	assign clkin_wire = clkin;
	assign reset_wire = reset; 
	
	// busy_reg to indicate read id operation is in progress
	always @ (posedge clkin_wire or posedge reset_wire)
		if (reset_wire == 1'b1) busy_reg <= 1'b0;
		else if (data_valid_reg) busy_reg <= 1'b0;
		else busy_reg <= 1'b1;
		
	// general counter to count the number of clock cycles in each stage
	a_graycounter   gen_cntr
	( 
		.aclr(reset_wire),
		.clk_en(busy_reg),
		.clock(~ clkin_wire),
		.q(wire_gen_cntr_q),
		.qbin(),
		.sclr(end_stage_pos_reg | end_op_reg),
		.cnt_en(1'b1),
		.updown(1'b1)
	);
	defparam
		gen_cntr.width = 7,
		gen_cntr.lpm_type = "a_graycounter";
	
	// state machine to control the shiftnld of chipidblock
	// state 0 - loading the unique chip id from fuse to shift register, 1 clock cycle
	// state 1 - shifting shift register to read out the value of unique chip id, 64 clock cycles
	always @ (posedge clkin_wire or posedge reset_wire)
		if (reset_wire == 1'b1)  current_state_reg <= 1'b0;
		else if (busy_reg == 1'b0) current_state_reg <= 1'b0;
		else if (data_valid_reg == 1'b1) current_state_reg <= 1'b0;
		else if (end_stage_pos_reg == 1'b1) current_state_reg <= (~ current_state_wire);
		else current_state_reg <= current_state_reg;
	assign current_state_wire = current_state_reg;
	
	// end stage signal
	always @ (posedge clkin_wire or posedge reset_wire)
		if (reset_wire == 1'b1) end_stage_pos_reg <= 1'b0;
		else if (data_valid_reg == 1'b1) end_stage_pos_reg <= 1'b0;
		else end_stage_pos_reg <= (((~ current_state_wire) & (wire_gen_cntr_q == LOAD_WIDTH)) | 
										(current_state_wire & (wire_gen_cntr_q == DATA_WIDTH)));
	
	always @ (negedge clkin_wire or posedge reset_wire)
		if (reset_wire == 1'b1) end_op_reg <= 1'b0;
		else end_op_reg <= (current_state_wire & end_stage_pos_reg);
		
	// -------------------------------------------------------------------
	// Instantiate wysiwyg for chipidblock according to device family
	// -------------------------------------------------------------------	
	generate
		if (DEVICE_FAMILY == "Stratix V") begin
			stratixv_chipidblock   chipidblock_dut		//Stratix V
			( 
				.clk(clkin_wire),
				.regout(regout_wire),
				.shiftnld(current_state_wire));
			end
		else if (DEVICE_FAMILY == "Arria V GZ") begin
			arriavgz_chipidblock   chipidblock_dut		//Arria V GZ
			( 
				.clk(clkin_wire),
				.regout(regout_wire),
				.shiftnld(current_state_wire));
			end
		else if (DEVICE_FAMILY == "Arria V") begin
			arriav_chipidblock   chipidblock_dut		//Arria V
			( 
				.clk(clkin_wire),
				.regout(regout_wire),
				.shiftnld(current_state_wire));
			end
		else begin
			cyclonev_chipidblock   chipidblock_dut		//Cyclone V
			( 
				.clk(clkin_wire),
				.regout(regout_wire),
				.shiftnld(current_state_wire));
			end
	endgenerate
	
	// -------------------------------------------------------------------
	// Output signals
	// -------------------------------------------------------------------
	// data_valid output - operation is completed
	always @ (posedge clkin_wire or posedge reset_wire)
		if (reset_wire == 1'b1) data_valid_reg <= 1'b0;
		else if (end_op_reg == 1'b1) data_valid_reg <= 1'b1;
		else data_valid_reg <= data_valid_reg;
	assign data_valid = data_valid_reg;
	
	// shift register to convert serial output to parallel
	lpm_shiftreg	shift_reg (
		.aclr (reset_wire),
		.clock (clkin_wire),
		.shiftin (regout_wire),
		.q (wire_shift_reg_q),
		.enable(((~ end_op_reg) & (~ data_valid_reg)) | (~ busy_reg)),
		.aset (1'b0),
		.data (64'b0),
		.load (1'b0),
		.sclr (~ busy_reg),
		.shiftout (),
		.sset (1'b0)
	);
	defparam
		shift_reg.lpm_direction = "RIGHT",
		shift_reg.lpm_type = "LPM_SHIFTREG",
		shift_reg.lpm_width = 64;
	
	always @ (negedge clkin_wire or posedge reset_wire)
		if (reset_wire == 1'b1) output_reg <= 64'h0000000000000000;
		else if (data_valid_reg == 1'b0) begin
			if  (end_stage_pos_reg == 1'b1)   output_reg <= {wire_shift_reg_q[63:0]};
			else output_reg <= output_reg;
		end
		else output_reg <= output_reg;
	
	//output
	assign chip_id = output_reg;
		
endmodule //altchip_id
//VALID FILE
