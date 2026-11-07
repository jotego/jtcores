//============================================================================
// 	YC - Luma / Chroma Generation
//  Copyright (C) 2022 Mike Simone
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================
/*
Colorspace
Y	0.299R' + 0.587G' + 0.114B'
U	0.492(B' - Y) = 504 (X 1024)
V	0.877(R' - Y) = 898 (X 1024)
*/
//////////////////////////////////////////////////////////

module yc_out
(
	input         clk,
	input  [39:0] PHASE_INC,
	input         PAL_EN,
	input         CVBS,
	input  [16:0] COLORBURST_RANGE,

	input	        hsync,
	input	        vsync,
	input	        csync,
	input	        de,

	input	 [23:0] din,
	output [23:0] dout,

	output reg	  hsync_o,
	output reg	  vsync_o,
	output reg	  csync_o,
	output reg	  de_o
);
`ifdef NCVERILOG
initial begin
    hsync_o=0;
    vsync_o=0;
    csync_o=0;
    de_o=0;
end
`else
wire [7:0] red = din[23:16];
wire [7:0] green = din[15:8];
wire [7:0] blue = din[7:0];

logic [7:0] red_1, blue_1, red_2, blue_2;

logic signed [20:0] yr = 0, yb = 0, yg = 0;
logic [7:0] luma_d0;
logic [7:0] luma_d1;
logic [7:0] luma_d2;
logic [7:0] luma_d3;
logic [7:0] luma_d4;

typedef struct {
	logic signed [20:0] y;
	logic signed [20:0] c;
	logic signed [20:0] u;
	logic signed [20:0] v;
	logic        burst;
	logic        chroma_en;
} phase_t;

phase_t phase[5];
reg unsigned [7:0] Y = 8'd0, C = 8'd128;
reg [6:0] hsync_dly = '0, vsync_dly = '0, csync_dly = '0;
reg de_dly0 = 1'b0, de_dly1 = 1'b0, de_dly2 = 1'b0, de_dly3 = 1'b0;
reg de_dly4 = 1'b0, de_dly5 = 1'b0, de_dly6 = 1'b0;


reg [10:0]  cburst_phase = 11'd0; // colorburst counter
reg unsigned [7:0] vref = 'd128; // Voltage reference point (Used for Chroma)
logic signed [10:0] chroma_COS = 11'sd0; // Chroma cos carrier
logic signed [10:0] chroma_SIN = 11'sd0; // Chroma sin carrier
logic signed [10:0] chroma_BURST = 11'sd0; // Chroma colorburst carrier
logic [7:0]  chroma_LUT = 8'd0;

/*
THe following LUT table was calculated by Sin(2*pi*t/2^8) where t: 0 - 255
*/

/*************************************
		8 bit Sine look up Table
**************************************/
localparam logic signed [10:0] chroma_SIN_LUT[0:255] = '{
	11'h000, 11'h006, 11'h00C, 11'h012, 11'h018, 11'h01F, 11'h025, 11'h02B, 11'h031, 11'h037, 11'h03D, 11'h044, 11'h04A, 11'h04F,
	11'h055, 11'h05B, 11'h061, 11'h067, 11'h06D, 11'h072, 11'h078, 11'h07D, 11'h083, 11'h088, 11'h08D, 11'h092, 11'h097, 11'h09C,
	11'h0A1, 11'h0A6, 11'h0AB, 11'h0AF, 11'h0B4, 11'h0B8, 11'h0BC, 11'h0C1, 11'h0C5, 11'h0C9, 11'h0CC, 11'h0D0, 11'h0D4, 11'h0D7,
	11'h0DA, 11'h0DD, 11'h0E0, 11'h0E3, 11'h0E6, 11'h0E9, 11'h0EB, 11'h0ED, 11'h0F0, 11'h0F2, 11'h0F4, 11'h0F5, 11'h0F7, 11'h0F8,
	11'h0FA, 11'h0FB, 11'h0FC, 11'h0FD, 11'h0FD, 11'h0FE, 11'h0FE, 11'h0FE, 11'h0FF, 11'h0FE, 11'h0FE, 11'h0FE, 11'h0FD, 11'h0FD,
	11'h0FC, 11'h0FB, 11'h0FA, 11'h0F8, 11'h0F7, 11'h0F5, 11'h0F4, 11'h0F2, 11'h0F0, 11'h0ED, 11'h0EB, 11'h0E9, 11'h0E6, 11'h0E3,
	11'h0E0, 11'h0DD, 11'h0DA, 11'h0D7, 11'h0D4, 11'h0D0, 11'h0CC, 11'h0C9, 11'h0C5, 11'h0C1, 11'h0BC, 11'h0B8, 11'h0B4, 11'h0AF,
	11'h0AB, 11'h0A6, 11'h0A1, 11'h09C, 11'h097, 11'h092, 11'h08D, 11'h088, 11'h083, 11'h07D, 11'h078, 11'h072, 11'h06D, 11'h067,
	11'h061, 11'h05B, 11'h055, 11'h04F, 11'h04A, 11'h044, 11'h03D, 11'h037, 11'h031, 11'h02B, 11'h025, 11'h01F, 11'h018, 11'h012,
	11'h00C, 11'h006, 11'h000, 11'h7F9, 11'h7F3, 11'h7ED, 11'h7E7, 11'h7E0, 11'h7DA, 11'h7D4, 11'h7CE, 11'h7C8, 11'h7C2, 11'h7BB,
	11'h7B5, 11'h7B0, 11'h7AA, 11'h7A4, 11'h79E, 11'h798, 11'h792, 11'h78D, 11'h787, 11'h782, 11'h77C, 11'h777, 11'h772, 11'h76D,
	11'h768, 11'h763, 11'h75E, 11'h759, 11'h754, 11'h750, 11'h74B, 11'h747, 11'h743, 11'h73E, 11'h73A, 11'h736, 11'h733, 11'h72F,
	11'h72B, 11'h728, 11'h725, 11'h722, 11'h71F, 11'h71C, 11'h719, 11'h716, 11'h714, 11'h712, 11'h70F, 11'h70D, 11'h70B, 11'h70A,
	11'h708, 11'h707, 11'h705, 11'h704, 11'h703, 11'h702, 11'h702, 11'h701, 11'h701, 11'h701, 11'h701, 11'h701, 11'h701, 11'h701,
	11'h702, 11'h702, 11'h703, 11'h704, 11'h705, 11'h707, 11'h708, 11'h70A, 11'h70B, 11'h70D, 11'h70F, 11'h712, 11'h714, 11'h716,
	11'h719, 11'h71C, 11'h71F, 11'h722, 11'h725, 11'h728, 11'h72B, 11'h72F, 11'h733, 11'h736, 11'h73A, 11'h73E, 11'h743, 11'h747,
	11'h74B, 11'h750, 11'h754, 11'h759, 11'h75E, 11'h763, 11'h768, 11'h76D, 11'h772, 11'h777, 11'h77C, 11'h782, 11'h787, 11'h78D,
	11'h792, 11'h798, 11'h79E, 11'h7A4, 11'h7AA, 11'h7B0, 11'h7B5, 11'h7BB, 11'h7C2, 11'h7C8, 11'h7CE, 11'h7D4, 11'h7DA, 11'h7E0,
	11'h7E7, 11'h7ED, 11'h7F3, 11'h7F9
};


function automatic signed [10:0] chroma_sin;
	input [7:0] idx;
begin
	chroma_sin = chroma_SIN_LUT[idx];
end
endfunction

logic [39:0] phase_accum = 40'd0;
logic PAL_FLIP = 1'd0;
logic PAL_line_count = 1'd0;

wire signed [20:0] vref_s = $signed({13'd0, vref});

/**************************************
	Output Level Formatting
***************************************/

// Completed chroma waveform for the separate C output and the CVBS mixer.
// Outside active video and burst, the pipeline holds this at the 128 neutral level.
wire [7:0] chroma = phase[4].c[7:0];

// This value is read before the delay line advances in the output register,
// so it matches the C/Y sample captured by Y and C below.
wire data_de = de_dly6;

// Keep the separate Y/C luma level identical for PAL and NTSC.
wire [7:0] luma_raw = luma_d4;

// Disabled 7.5 IRE setup scaling, retained here for reference.
// wire [15:0] luma_setup_scaled =
// 	{luma_raw, 8'd0} -
// 	{4'd0, luma_raw, 4'd0} -
// 	{7'd0, luma_raw, 1'd0} -
// 	{8'd0, luma_raw};
// wire [7:0] yc_luma_setup = luma_setup_scaled[15:8] + 8'd19;

wire [7:0] yc_luma = data_de ? luma_raw : 8'd0;

// CVBS intentionally keeps the original mixer behavior from the legacy module.
// The Y/C path below still applies the newer chroma gating changes.
wire [7:0] cvbs_out = {1'b0, luma_raw[7:1]} + {1'b0, chroma[7:1]};

/**************************************
	Generate Luma and Chroma Signals
***************************************/

always_ff @(posedge clk) begin
	// delay red / blue signals to align luma with U/V calculation (Fixes colorbleeding)
	red_1 <= red;
	blue_1 <= blue;
	red_2 <= red_1;
	blue_2 <= blue_1;

	// Calculate Luma signal
	yr <= {red, 8'd0} + {red, 5'd0}+ {red, 4'd0} + {red, 1'd0};
	yg <= {green, 9'd0} + {green, 6'd0} + {green, 4'd0} + {green, 3'd0} + green;
	yb <= {blue, 6'd0} + {blue, 5'd0} + {blue, 4'd0} + {blue, 2'd0} + blue;
	phase[0].y <= yr + yg + yb;

	// Generate the LUT values using the phase accumulator reference.
	phase_accum <= phase_accum + PHASE_INC;
	chroma_LUT <= phase_accum[39:32];

	// Adjust SINE carrier reference for PAL (Also adjust for PAL Switch)
	if (PAL_EN) begin
		if (PAL_FLIP)
			chroma_BURST <= chroma_sin(chroma_LUT + 8'd160);
		else
			chroma_BURST <= chroma_sin(chroma_LUT + 8'd96);
	end else  // Adjust SINE carrier reference for NTSC
		chroma_BURST <= chroma_sin(chroma_LUT + 8'd128);

	// Prepare LUT values for sin / cos (+90 degress)
	chroma_SIN <= chroma_sin(chroma_LUT);
	chroma_COS <= chroma_sin(chroma_LUT + 8'd64);

	// Calculate for U, V - Bit Shift Multiple by u = by * 1024 x 0.492 = 504, v = ry * 1024 x 0.877 = 898
	phase[0].u <= $signed({2'b0 ,(blue_2)}) - $signed({2'b0 ,phase[0].y[17:10]});
	phase[0].v <= $signed({2'b0 , (red_2)}) - $signed({2'b0 ,phase[0].y[17:10]});
	phase[1].u <= 21'($signed({phase[0].u, 8'd0}) + $signed({phase[0].u, 7'd0}) + $signed({phase[0].u, 6'd0}) + $signed({phase[0].u, 5'd0}) + $signed({phase[0].u, 4'd0}) + $signed({phase[0].u, 3'd0}));
	phase[1].v <= 21'($signed({phase[0].v, 9'd0}) + $signed({phase[0].v, 8'd0}) + $signed({phase[0].v, 7'd0}) + $signed({phase[0].v, 1'd0}));


	if (hsync) begin // Reset colorburst counter, as well as the calculated cos / sin values.
		cburst_phase <= 'd0;
		phase[2].u <= 21'b0;
		phase[2].v <= 21'b0;
		phase[2].burst <= 1'b0;
		phase[2].chroma_en <= 1'b0;
		phase[4].c <= vref_s;

		if (PAL_line_count) begin
			PAL_FLIP <= ~PAL_FLIP;
			PAL_line_count <= ~PAL_line_count;
		end
	end
	else begin // Generate Colorburst for 9 cycles
		if (cburst_phase >= COLORBURST_RANGE[16:10] && cburst_phase <= COLORBURST_RANGE[9:0]) begin // Start the color burst signal at 40 samples or 0.9 us
			// COLORBURST SIGNAL GENERATION (9 CYCLES ONLY or between count 40 - 240)
			phase[2].u <= $signed({chroma_BURST,5'd0});
			phase[2].v <= 21'b0;
			phase[2].burst <= 1'b1;
			phase[2].chroma_en <= 1'b0;
		end	else begin  // MODULATE U, V for chroma
			/*
			U,V are both multiplied by 1024 earlier to scale for the decimals in the YUV colorspace conversion.
			U and V are both divided by 2^10 which introduce chroma subsampling of 4:1:1 (25% or from 8 bit to 6 bit)
			*/
			phase[2].u <= $signed((phase[1].u)>>>10) * chroma_SIN;
			phase[2].v <= $signed((phase[1].v)>>>10) * chroma_COS;
			phase[2].burst <= 1'b0;
			phase[2].chroma_en <= de_dly3;
		end

		// Scale the previous stage-2 sample. Its burst flag selects the matching
		// coefficient set even on the first active-video cycle after the burst.
		if (phase[2].burst) begin
			if (PAL_EN)
				phase[3].u <= $signed(phase[2].u[20:8]) + $signed(phase[2].u[20:11]) + $signed(phase[2].u[20:12]) + $signed(phase[2].u[20:14]);
			else
				phase[3].u <= $signed(phase[2].u[20:8]) + $signed(phase[2].u[20:11]) + $signed(phase[2].u[20:12]) + $signed(phase[2].u[20:13]);
		end else begin
			phase[3].u <= $signed(phase[2].u[20:9]) + $signed(phase[2].u[20:10]) + $signed(phase[2].u[20:14]);
		end
		phase[3].v <= $signed(phase[2].v[20:9]) + $signed(phase[2].v[20:10]) + $signed(phase[2].v[20:14]);

		// Stop the colorburst timer as its only needed for the initial pulse
		if (cburst_phase <= COLORBURST_RANGE[9:0])
			cburst_phase <= cburst_phase + 9'd1;

		// Build the chroma byte only during burst or active video. Outside those
		// windows, hold chroma at the 128 reference level.
		if (phase[3].burst || phase[3].chroma_en) begin
			if (PAL_EN) begin
				if (PAL_FLIP)
					phase[4].c <= vref_s + phase[3].u - phase[3].v;
				else
					phase[4].c <= vref_s + phase[3].u + phase[3].v;
				PAL_line_count <= 1'd1;
			end else
				phase[4].c <= vref_s + phase[3].u + phase[3].v;
		end else
			phase[4].c <= vref_s;
	end

	phase[3].burst <= phase[2].burst;
	phase[3].chroma_en <= phase[2].chroma_en;

	// Seven-cycle control delay, sampled by the output registers below.
	hsync_dly <= {hsync_dly[5:0], hsync};
	vsync_dly <= {vsync_dly[5:0], vsync};
	csync_dly <= {csync_dly[5:0], csync};
	de_dly0 <= de;
	de_dly1 <= de_dly0;	de_dly2 <= de_dly1;	de_dly3 <= de_dly2;	de_dly4 <= de_dly3;	de_dly5 <= de_dly4;	de_dly6 <= de_dly5;
	hsync_o <= hsync_dly[6]; vsync_o <= vsync_dly[6]; csync_o <= csync_dly[6]; de_o <= de_dly6;

	luma_d0 <= phase[0].y[17:10];luma_d1 <= luma_d0; luma_d2 <= luma_d1;	luma_d3 <= luma_d2;	luma_d4 <= luma_d3;

	// Select separate Y/C or packed CVBS output.
	C <= CVBS ? 8'd0 : chroma;
	Y <= CVBS ? cvbs_out : yc_luma;
end

assign dout = {C, Y, 8'd0};
`endif
endmodule
