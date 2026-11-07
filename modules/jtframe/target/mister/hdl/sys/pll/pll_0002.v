`timescale 1ns/10ps
module  pll_0002(

	// interface 'refclk'
	input wire refclk,

	// interface 'reset'
	input wire rst,

	// interface 'outclk0'
	output wire outclk_0,

	// interface 'outclk1'
	output wire outclk_1,

	// interface 'outclk2'
	output wire outclk_2,

	// interface 'outclk3'
	output wire outclk_3,

	// interface 'outclk4'
	output wire outclk_4,

	// interface 'outclk5'
	output wire outclk_5,

	// interface 'locked'
	output wire locked
`ifdef JTFRAME_PLL_TUNE

	// interface 'reconfig_to_pll'
	,input wire [63:0] reconfig_to_pll

	// interface 'reconfig_from_pll'
	,output wire [63:0] reconfig_from_pll
`endif
);

	altera_pll #(
		.fractional_vco_multiplier(
`ifdef JTFRAME_PLL_TUNE
            "true"
`else
            "false"
`endif
        ),
		.reference_clock_frequency("50.0 MHz"),
		.operation_mode("direct"),
		.number_of_clocks(6),
		.output_clock_frequency0("48.000000 MHz"),
		.phase_shift0("0 ps"),
		.duty_cycle0(50),
		.output_clock_frequency1("48.000000 MHz"),
		.phase_shift1(
`ifdef JTFRAME_PLL_TUNE
            "0 ps"
`else
            "5555 ps"
`endif
        ),
		.duty_cycle1(50),
		.output_clock_frequency2("24.000000 MHz"),
		.phase_shift2("0 ps"),
		.duty_cycle2(50),
		.output_clock_frequency3("6.000000 MHz"),
		.phase_shift3("0 ps"),
		.duty_cycle3(50),
		.output_clock_frequency4("96.000000 MHz"),
		.phase_shift4("0 ps"),
		.duty_cycle4(50),
		.output_clock_frequency5("96.000000 MHz"),
		.phase_shift5(
`ifdef JTFRAME_PLL_TUNE
            "0 ps"
`else
            "-5034 ps"
`endif
        ),
		.duty_cycle5(50),
		.output_clock_frequency6("0 MHz"),
		.phase_shift6("0 ps"),
		.duty_cycle6(50),
		.output_clock_frequency7("0 MHz"),
		.phase_shift7("0 ps"),
		.duty_cycle7(50),
		.output_clock_frequency8("0 MHz"),
		.phase_shift8("0 ps"),
		.duty_cycle8(50),
		.output_clock_frequency9("0 MHz"),
		.phase_shift9("0 ps"),
		.duty_cycle9(50),
		.output_clock_frequency10("0 MHz"),
		.phase_shift10("0 ps"),
		.duty_cycle10(50),
		.output_clock_frequency11("0 MHz"),
		.phase_shift11("0 ps"),
		.duty_cycle11(50),
		.output_clock_frequency12("0 MHz"),
		.phase_shift12("0 ps"),
		.duty_cycle12(50),
		.output_clock_frequency13("0 MHz"),
		.phase_shift13("0 ps"),
		.duty_cycle13(50),
		.output_clock_frequency14("0 MHz"),
		.phase_shift14("0 ps"),
		.duty_cycle14(50),
		.output_clock_frequency15("0 MHz"),
		.phase_shift15("0 ps"),
		.duty_cycle15(50),
		.output_clock_frequency16("0 MHz"),
		.phase_shift16("0 ps"),
		.duty_cycle16(50),
		.output_clock_frequency17("0 MHz"),
		.phase_shift17("0 ps"),
		.duty_cycle17(50),
		.pll_type(
`ifdef JTFRAME_PLL_TUNE
            "Cyclone V"
`else
            "General"
`endif
        ),
		.pll_subtype(
`ifdef JTFRAME_PLL_TUNE
            "Reconfigurable"
`else
            "General"
`endif
        )
`ifdef JTFRAME_PLL_TUNE
        // 50 MHz * (19 + 0.2) = 960 MHz VCO. The six C counters keep
        // the existing 48/48/24/6/96/96 MHz clock relationships.
        ,.m_cnt_hi_div(10),
		.m_cnt_lo_div(9),
		.n_cnt_hi_div(256),
		.n_cnt_lo_div(256),
		.m_cnt_bypass_en("false"),
		.n_cnt_bypass_en("true"),
		.m_cnt_odd_div_duty_en("true"),
		.n_cnt_odd_div_duty_en("false"),
		.c_cnt_hi_div0(10), .c_cnt_lo_div0(10),
		.c_cnt_hi_div1(10), .c_cnt_lo_div1(10),
		.c_cnt_hi_div2(20), .c_cnt_lo_div2(20),
		.c_cnt_hi_div3(80), .c_cnt_lo_div3(80),
		.c_cnt_hi_div4(5),  .c_cnt_lo_div4(5),
		.c_cnt_hi_div5(5),  .c_cnt_lo_div5(5),
		.c_cnt_bypass_en0("false"), .c_cnt_bypass_en1("false"),
		.c_cnt_bypass_en2("false"), .c_cnt_bypass_en3("false"),
		.c_cnt_bypass_en4("false"), .c_cnt_bypass_en5("false"),
		.c_cnt_odd_div_duty_en0("false"), .c_cnt_odd_div_duty_en1("false"),
		.c_cnt_odd_div_duty_en2("false"), .c_cnt_odd_div_duty_en3("false"),
		.c_cnt_odd_div_duty_en4("false"), .c_cnt_odd_div_duty_en5("false"),
		.pll_vco_div(1),
		.pll_cp_current(20),
		.pll_bwctrl(4000),
		.pll_output_clk_frequency("960.000000 MHz"),
		.pll_fractional_division("858993459"),
		.mimic_fbclk_type("none"),
		.pll_fbclk_mux_1("glb"),
		.pll_fbclk_mux_2("m_cnt"),
		.pll_m_cnt_in_src("ph_mux_clk"),
		.pll_slf_rst("true")
`endif
	) altera_pll_i (
		.rst	(rst),
		.outclk	({outclk_5, outclk_4, outclk_3, outclk_2, outclk_1, outclk_0}),
		.locked	(locked),
		.fboutclk	( ),
		.fbclk	(1'b0),
		.refclk	(refclk)
`ifdef JTFRAME_PLL_TUNE
		,.reconfig_to_pll(reconfig_to_pll),
		.reconfig_from_pll(reconfig_from_pll)
`endif
	);
endmodule
