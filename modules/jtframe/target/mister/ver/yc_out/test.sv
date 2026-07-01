`timescale 1ns/1ps

module test;

logic        clk = 1'b0;
logic [23:0] dout;
logic        hsync_o, vsync_o, csync_o, de_o;

localparam logic signed [10:0] first_quarter[0:63] = '{
	11'h000, 11'h006, 11'h00C, 11'h012, 11'h018, 11'h01F, 11'h025, 11'h02B,
	11'h031, 11'h037, 11'h03D, 11'h044, 11'h04A, 11'h04F, 11'h055, 11'h05B,
	11'h061, 11'h067, 11'h06D, 11'h072, 11'h078, 11'h07D, 11'h083, 11'h088,
	11'h08D, 11'h092, 11'h097, 11'h09C, 11'h0A1, 11'h0A6, 11'h0AB, 11'h0AF,
	11'h0B4, 11'h0B8, 11'h0BC, 11'h0C1, 11'h0C5, 11'h0C9, 11'h0CC, 11'h0D0,
	11'h0D4, 11'h0D7, 11'h0DA, 11'h0DD, 11'h0E0, 11'h0E3, 11'h0E6, 11'h0E9,
	11'h0EB, 11'h0ED, 11'h0F0, 11'h0F2, 11'h0F4, 11'h0F5, 11'h0F7, 11'h0F8,
	11'h0FA, 11'h0FB, 11'h0FC, 11'h0FD, 11'h0FD, 11'h0FE, 11'h0FE, 11'h0FE
};

function automatic logic signed [10:0] expected_sin;
	input logic [7:0] idx;
	logic [5:0] lut_addr;
	logic peak;
	logic signed [10:0] lut_data;
begin
	lut_addr     = idx[6] ? (6'd0 - idx[5:0]) : idx[5:0];
	peak         = idx[6] && (idx[5:0] == 6'd0);
	lut_data     = peak ? 11'sh0ff : first_quarter[lut_addr];
	expected_sin = idx[7] ? -lut_data : lut_data;
end
endfunction

yc_out u_yc(
	.clk              ( clk        ),
	.PHASE_INC        ( 40'd0      ),
	.PAL_EN           ( 1'b0       ),
	.CVBS             ( 1'b0       ),
	.COLORBURST_RANGE ( 17'd0      ),
	.hsync            ( 1'b0       ),
	.vsync            ( 1'b0       ),
	.csync            ( 1'b0       ),
	.de               ( 1'b0       ),
	.din              ( 24'd0      ),
	.dout             ( dout       ),
	.hsync_o          ( hsync_o    ),
	.vsync_o          ( vsync_o    ),
	.csync_o          ( csync_o    ),
	.de_o             ( de_o       )
);

initial begin
	int sum;
	sum = 0;
	for (int i = 0; i < 256; i++) begin
		logic [7:0] idx;
		logic signed [10:0] got, exp;
		idx = i[7:0];
		got = u_yc.chroma_sin(idx);
		exp = expected_sin(idx);
		sum += got;
		if (got !== exp) begin
			$error("sine[%0d] mismatch: got %0d (0x%03h), expected %0d (0x%03h)",
				i, got, got, exp, exp);
			$fatal;
		end
		if (got !== -u_yc.chroma_sin(idx + 8'd128)) begin
			$error("sine[%0d] is not odd-symmetric with sine[%0d]", i, idx + 8'd128);
			$fatal;
		end
	end
	if (sum != 0) begin
		$error("sine table DC bias: sum=%0d", sum);
		$fatal;
	end
	$display("All yc_out sine samples match the balanced quarter-wave reconstruction");
	$finish;
end

endmodule
