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
/* Colorspace
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
logic [7:0]  chroma_LUT_COS = 8'd0; // Chroma cos LUT reference
logic [7:0]  chroma_LUT_SIN = 8'd0; // Chroma sin LUT reference
logic [7:0]  chroma_LUT_BURST = 8'd0; // Chroma colorburst LUT reference
logic [7:0]  chroma_LUT = 8'd0;

/*
	The following LUT table was calculated by (sin((2 * pi * t) / 255) * 255) + 0.5f where t: 0 - 255
	8 bit sine look up table, first quarter only
*/
localparam logic [7:0] chroma_SIN_LUT[64] = '{
	0,   6,   13,  19,  25,  31,  38,  44,  50,  56,  62,  68,  74,  80,  86,  92,
	98,  104, 109, 115, 121, 126, 132, 137, 142, 147, 152, 157, 162, 167, 172, 176,
	181, 185, 190, 194, 198, 202, 205, 209, 213, 216, 219, 222, 225, 228, 231, 234,
	236, 238, 241, 243, 244, 246, 248, 249, 250, 251, 252, 253, 254, 254, 255, 255
};

function automatic signed [10:0] chroma_sin;
	input [7:0] idx;
	logic signed [10:0] lut_data;
begin
	lut_data   = {3'b000, chroma_SIN_LUT[idx[6] ? ~idx[5:0] : idx[5:0]]};
	chroma_sin = idx[7] ? -lut_data : lut_data;
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

// Y/C luma keeps full range. North American NTSC applies 7.5 IRE setup
// during active video only, so blanking is not lifted with the black level.
wire [7:0] luma_raw = luma_d4;

wire [15:0] luma_setup_scaled =
	{luma_raw, 8'd0} -
	{4'd0, luma_raw, 4'd0} -
	{7'd0, luma_raw, 1'd0} -
	{8'd0, luma_raw};

wire [7:0] yc_luma_setup = luma_setup_scaled[15:8] + 8'd19;

wire [7:0] yc_luma =
	data_de ? (PAL_EN ? luma_raw : yc_luma_setup) : 8'd0;

// CVBS intentionally keeps the original mixer behavior from the legacy module.
// The Y/C path below still applies the newer setup and chroma gating changes.
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
			chroma_LUT_BURST <= chroma_LUT + 8'd160;
		else
			chroma_LUT_BURST <= chroma_LUT + 8'd96;
	end else  // Adjust SINE carrier reference for NTSC
		chroma_LUT_BURST <= chroma_LUT + 8'd128;

	// Prepare LUT values for sin / cos (+90 degress)
	chroma_LUT_SIN <= chroma_LUT;
	chroma_LUT_COS <= chroma_LUT + 8'd64;

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
			phase[2].u <= $signed({chroma_sin(chroma_LUT_BURST),5'd0});
			phase[2].v <= 21'b0;
			phase[2].burst <= 1'b1;
			phase[2].chroma_en <= 1'b0;

			// Division to scale down the results to fit 8 bit.
			if (PAL_EN)
				phase[3].u <= $signed(phase[2].u[20:8]) + $signed(phase[2].u[20:11]) + $signed(phase[2].u[20:12]) + $signed(phase[2].u[20:14]);
			else
				phase[3].u <= $signed(phase[2].u[20:8]) + $signed(phase[2].u[20:11]) + $signed(phase[2].u[20:12]) + $signed(phase[2].u[20:13]);

			phase[3].v <= phase[2].v;
		end	else begin  // MODULATE U, V for chroma
			/*
			U,V are both multiplied by 1024 earlier to scale for the decimals in the YUV colorspace conversion.
			U and V are both divided by 2^10 which introduce chroma subsampling of 4:1:1 (25% or from 8 bit to 6 bit)
			*/
			phase[2].u <= $signed((phase[1].u)>>>10) * $signed(chroma_sin(chroma_LUT_SIN));
			phase[2].v <= $signed((phase[1].v)>>>10) * $signed(chroma_sin(chroma_LUT_COS));
			phase[2].burst <= 1'b0;
			phase[2].chroma_en <= de_dly3;

			// Divide U*sin(wt) and V*cos(wt) to fit results to 8 bit
			phase[3].u <= $signed(phase[2].u[20:9]) + $signed(phase[2].u[20:10]) + $signed(phase[2].u[20:14]);
			phase[3].v <= $signed(phase[2].v[20:9]) + $signed(phase[2].v[20:10]) + $signed(phase[2].v[20:14]);
		end

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

endmodule