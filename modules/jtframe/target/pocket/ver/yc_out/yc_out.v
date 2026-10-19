module yc_out (
	clk,
	PHASE_INC,
	PAL_EN,
	CVBS,
	COLORBURST_RANGE,
	hsync,
	vsync,
	csync,
	din,
	dout,
	hsync_o,
	vsync_o,
	csync_o
);
	input clk;
	input [39:0] PHASE_INC;
	input PAL_EN;
	input CVBS;
	input [16:0] COLORBURST_RANGE;
	input hsync;
	input vsync;
	input csync;
	input [23:0] din;
	output wire [23:0] dout;
	output reg hsync_o;
	output reg vsync_o;
	output reg csync_o;
	wire [7:0] red = din[23:16];
	wire [7:0] green = din[15:8];
	wire [7:0] blue = din[7:0];
	reg [9:0] red_1;
	reg [9:0] blue_1;
	wire [9:0] green_1;
	reg [9:0] red_2;
	reg [9:0] blue_2;
	wire [9:0] green_2;
	reg signed [20:0] yr = 0;
	reg signed [20:0] yb = 0;
	reg signed [20:0] yg = 0;
	localparam MAX_PHASES = 7'd8;
	// reg [86:0] phase0, phase1, phase2, phase3, phase4, phase5, phase6, phase7;// [0:MAX_PHASES - 1];
	reg signed [20:0] phase0_y, phase0_c, phase0_u, phase0_v;
	reg               phase0_hsync, phase0_vsync, phase0_csync;
	reg signed [20:0] phase1_y, phase1_c, phase1_u, phase1_v;
	reg               phase1_hsync, phase1_vsync, phase1_csync;
	reg signed [20:0] phase2_y, phase2_c, phase2_u, phase2_v;
	reg               phase2_hsync, phase2_vsync, phase2_csync;
	reg signed [20:0] phase3_y, phase3_c, phase3_u, phase3_v;
	reg               phase3_hsync, phase3_vsync, phase3_csync;
	reg signed [20:0] phase4_y, phase4_c, phase4_u, phase4_v;
	reg               phase4_hsync, phase4_vsync, phase4_csync;
	reg signed [20:0] phase5_y, phase5_c, phase5_u, phase5_v;
	reg               phase5_hsync, phase5_vsync, phase5_csync;
	reg signed [20:0] phase6_y, phase6_c, phase6_u, phase6_v;
	reg               phase6_hsync, phase6_vsync, phase6_csync;
	reg signed [20:0] phase7_y, phase7_c, phase7_u, phase7_v;
	reg               phase7_hsync, phase7_vsync, phase7_csync;
	reg [7:0] Y;
	reg [7:0] C;
	reg [7:0] c;
	reg [7:0] U;
	reg [7:0] V;
	reg [10:0] cburst_phase;
	reg [7:0] vref = 'd128;
	reg [7:0] chroma_LUT_COS;
	reg [7:0] chroma_LUT_SIN;
	reg [7:0] chroma_LUT_BURST;
	reg [7:0] chroma_LUT = 8'd0;
	wire signed [2815:0] chroma_SIN_LUT = 2816'h180601203007c1282b0620dc1e84409413c2a85b0c219c368720f01f44188811a2484b89c142298558af1682e05e0c118a324660d01a835c6d0dd1c038c730e91d63b4780f21e83d47b8f81f43ec7e0fd1fa3f87f0fe1fe3f87f0fe1fa3f47e0fb1f43e07b8f51e83c8780ed1d63a4730e31c03746d0d71a8340660c918a3045e0b81682bc558a61422704b89211a2204187d0f01c8368670c216c2a84f0941101e8370620ac1281f03004806006001fe7f9fedfcff83ed7d4f9df23e17bbf6bec3d57a4f3de63c978df0fe0bbe777ee5db7b4763ebdd67aa750e97d1fa1f3ee75cdb99f2fe57ca392f22e3fc738cf16e29c4b87f0de17c2b84707e0bc1381f02e05c0780f01e03c0780f01e05c0b81f04e0bc1f8470ae17c3787f12e29c5b8cf1ce3fc8b92f28e57cbf99f36e75cfba1f47e97d43aa759ebdd8fb476dee5ddfbe782f0fe37c9798f3de93d57b0f6beefe17c8f9df53ed7e0fcffb7f9ff9;
	reg [39:0] phase_accum=0;
	reg PAL_FLIP = 1'd0;
	reg PAL_line_count = 1'd0;
	function automatic signed [20:0] sv2v_cast_21_signed;
		input reg signed [20:0] inp;
		sv2v_cast_21_signed = inp;
	endfunction
	always @(posedge clk) begin
		//{phase1, phase2, phase3, phase4, phase5, phase6, phase7} <= {phase0, phase1, phase2, phase3, phase4, phase5, phase6};
	/*		begin : sv2v_autoblock_1
			reg [3:0] x;
			for (x = 0; x < (MAX_PHASES - 1'd1); x = x + 1'd1)
				phase[x + 1] <= phase[x];
		end*/
		{phase1_y, phase1_c, phase1_u, phase1_v, phase1_hsync, phase1_vsync, phase1_csync} <= {phase0_y, phase0_c, phase0_u, phase0_v, phase0_hsync, phase0_vsync, phase0_csync};
		{phase2_y, phase2_c, phase2_u, phase2_v, phase2_hsync, phase2_vsync, phase2_csync} <= {phase1_y, phase1_c, phase1_u, phase1_v, phase1_hsync, phase1_vsync, phase1_csync};
		{phase3_y, phase3_c, phase3_u, phase3_v, phase3_hsync, phase3_vsync, phase3_csync} <= {phase2_y, phase2_c, phase2_u, phase2_v, phase2_hsync, phase2_vsync, phase2_csync};
		{phase4_y, phase4_c, phase4_u, phase4_v, phase4_hsync, phase4_vsync, phase4_csync} <= {phase3_y, phase3_c, phase3_u, phase3_v, phase3_hsync, phase3_vsync, phase3_csync};
		{phase5_y, phase5_c, phase5_u, phase5_v, phase5_hsync, phase5_vsync, phase5_csync} <= {phase4_y, phase4_c, phase4_u, phase4_v, phase4_hsync, phase4_vsync, phase4_csync};
		{phase6_y, phase6_c, phase6_u, phase6_v, phase6_hsync, phase6_vsync, phase6_csync} <= {phase5_y, phase5_c, phase5_u, phase5_v, phase5_hsync, phase5_vsync, phase5_csync};
		{phase7_y, phase7_c, phase7_u, phase7_v, phase7_hsync, phase7_vsync, phase7_csync} <= {phase6_y, phase6_c, phase6_u, phase6_v, phase6_hsync, phase6_vsync, phase6_csync};

		red_1 <= red;
		blue_1 <= blue;
		red_2 <= red_1;
		blue_2 <= blue_1;
		yr <= (({red, 8'd0} + {red, 5'd0}) + {red, 4'd0}) + {red, 1'd0};
		yg <= ((({green, 9'd0} + {green, 6'd0}) + {green, 4'd0}) + {green, 3'd0}) + green;
		yb <= ((({blue, 6'd0} + {blue, 5'd0}) + {blue, 4'd0}) + {blue, 2'd0}) + blue;
		phase0_y <= (yr + yg) + yb;
		phase_accum <= phase_accum + PHASE_INC;
		chroma_LUT <= phase_accum[39:32];
		if (PAL_EN) begin
			if (PAL_FLIP)
				chroma_LUT_BURST <= chroma_LUT + 8'd160;
			else
				chroma_LUT_BURST <= chroma_LUT + 8'd96;
		end
		else
			chroma_LUT_BURST <= chroma_LUT + 8'd128;
		chroma_LUT_SIN <= chroma_LUT;
		chroma_LUT_COS <= chroma_LUT + 8'd64;
		phase0_u <= $signed({2'b00, blue_2}) - $signed({2'b00, phase0_y[17:10]});
		phase0_v <= $signed({2'b00, red_2}) - $signed({2'b00, phase0_y[17:10]});
		phase1_u <= sv2v_cast_21_signed((((($signed({$signed(phase0_u), 8'd0}) + $signed({$signed(phase0_u), 7'd0})) + $signed({$signed(phase0_u), 6'd0})) + $signed({$signed(phase0_u), 5'd0})) + $signed({$signed(phase0_u), 4'd0})) + $signed({$signed(phase0_u), 3'd0}));
		phase1_v <= sv2v_cast_21_signed((($signed({$signed(phase0_v), 9'd0}) + $signed({$signed(phase0_v), 8'd0})) + $signed({$signed(phase0_v), 7'd0})) + $signed({$signed(phase0_v), 1'd0}));
		phase0_c <= vref;
		phase1_c <= phase0_c;
		phase2_c <= phase1_c;
		phase3_c <= phase2_c;
		if (hsync) begin
			cburst_phase <= 10'd0;
			phase2_u <= 21'b000000000000000000000;
			phase2_v <= 21'b000000000000000000000;
			phase4_c <= phase3_c;
			if (PAL_line_count) begin
				PAL_FLIP <= ~PAL_FLIP;
				PAL_line_count <= ~PAL_line_count;
			end
		end
		else begin
			if ((cburst_phase >= COLORBURST_RANGE[16:10]) && (cburst_phase <= COLORBURST_RANGE[9:0])) begin
				phase2_u <= $signed({chroma_SIN_LUT[(255 - chroma_LUT_BURST) * 11+:11], 5'd0});
				phase2_v <= 21'b000000000000000000000;
				if (PAL_EN)
					phase3_u <= ($signed(phase2_u[20:8]) + $signed(phase2_u[20:10])) + $signed(phase2_u[20:14]);
				else
					phase3_u <= (($signed(phase2_u[20:8]) + $signed(phase2_u[20:11])) + $signed(phase2_u[20:12])) + $signed(phase2_u[20:13]);
				phase3_v <= $signed(phase2_v);
			end
			else begin
				phase2_u <= $signed($signed(phase1_u) >>> 10) * $signed(chroma_SIN_LUT[(255 - chroma_LUT_SIN) * 11+:11]);
				phase2_v <= $signed($signed(phase1_v) >>> 10) * $signed(chroma_SIN_LUT[(255 - chroma_LUT_COS) * 11+:11]);
				phase3_u <= $signed(phase2_u[20:9]) + $signed(phase2_u[20:10]) + $signed(phase2_u[20:14]);
				phase3_v <= $signed(phase2_v[20:9]) + $signed(phase2_v[20:10]) + $signed(phase2_u[20:14]);
			end
			if (cburst_phase <= COLORBURST_RANGE[9:0])
				cburst_phase <= cburst_phase + 9'd1;
			if (PAL_EN) begin
				if (PAL_FLIP)
					phase4_c <= (vref + phase3_u) - phase3_v;
				else
					phase4_c <= (vref + $signed(phase3_u)) + $signed(phase3_v);
				PAL_line_count <= 1'd1;
			end
			else
				phase4_c <= (vref + $signed(phase3_u)) + $signed(phase3_v);
		end
		phase1_hsync <= hsync;
		phase1_vsync <= vsync;
		phase1_csync <= csync;
		phase2_hsync <= phase1_hsync;
		phase2_vsync <= phase1_vsync;
		phase2_csync <= phase1_csync;
		phase3_hsync <= phase2_hsync;
		phase3_vsync <= phase2_vsync;
		phase3_csync <= phase2_csync;
		phase4_hsync <= phase3_hsync;
		phase4_vsync <= phase3_vsync;
		phase4_csync <= phase3_csync;
		hsync_o <= phase4_hsync;
		vsync_o <= phase4_vsync;
		csync_o <= phase4_csync;
		phase1_y <= phase0_y;
		phase2_y <= phase1_y;
		phase3_y <= phase2_y;
		phase4_y <= phase3_y;
		phase5_y <= phase4_y;
		C <= (CVBS ? 8'd0 : phase4_c[7:0]);
		Y <= (CVBS ? {1'b0, phase5_y[17:11]} + {1'b0, phase4_c[7:1]} : phase5_y[17:10]);
	end
	assign dout = {C, Y, 8'd0};
endmodule
