/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-7-2026 */

// Taito TC0060DCA stereo programmable volume control.
// The gain curve matches the measured model in doc/tc0060dca.cpp.
module jt060dca #(parameter SW=16)(
    input                       rst,
    input                       clk,
    input                       vol1_we,
    input                       vol2_we,
    input              [ 7:0]   din,
    input signed       [SW-1:0] sin1,
    input signed       [SW-1:0] sin2,
    output reg signed  [SW-1:0] sout1,
    output reg signed  [SW-1:0] sout2
);

wire        [15:0] gain1, gain2;
wire signed [16:0] gain1_signed, gain2_signed;
wire signed [SW+16:0] scaled1, scaled2;
reg         [ 7:0] volume1, volume1_in, volume2, volume2_in;
reg                vol1_we_l, vol2_we_l;

assign gain1_signed = $signed({1'b0,gain1});
assign gain2_signed = $signed({1'b0,gain2});
assign scaled1      = sin1 * gain1_signed;
assign scaled2      = sin2 * gain2_signed;

always @(posedge clk) begin
    if( rst ) begin
        volume1    <= 8'hff;
        volume1_in <= 8'hff;
        volume2    <= 8'hff;
        volume2_in <= 8'hff;
        vol1_we_l  <= 0;
        vol2_we_l  <= 0;
        sout1      <= 0;
        sout2      <= 0;
    end else begin
        vol1_we_l <= vol1_we;
        vol2_we_l <= vol2_we;
        if( vol1_we && !vol1_we_l ) {volume1,volume1_in} <= {volume1_in,din};
        if( vol2_we && !vol2_we_l ) {volume2,volume2_in} <= {volume2_in,din};
        sout1 <= scaled1[SW+15:16];
        sout2 <= scaled2[SW+15:16];
    end
end

jtframe_dual_ram16 #(
    .AW            ( 8                  ),
    .SYNFILE_LO    ( "jt060dca_lo.hex"  ),
    .SYNFILE_HI    ( "jt060dca_hi.hex"  )
) u_gain(
    // Port 0: volume 1 gain
    .clk0  ( clk     ),
    .data0 ( 16'd0   ),
    .addr0 ( volume1 ),
    .we0   ( 2'b00   ),
    .q0    ( gain1   ),
    // Port 1: volume 2 gain
    .clk1  ( clk     ),
    .data1 ( 16'd0   ),
    .addr1 ( volume2 ),
    .we1   ( 2'b00   ),
    .q1    ( gain2   )
);

endmodule
