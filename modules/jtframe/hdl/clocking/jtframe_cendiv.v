/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-4-2021 */

// Divides a clock enable signal frequency by an integer

module jtframe_cendiv #( parameter
    MDIV    = 2
)(
    input      rst,
    input      clk,
    input      cen_in,
    output reg cen_div, // Divided but not alligned with the original
    output     cen_da   // Divided and alligned
);

localparam CW = $clog2(MDIV);

reg [CW-1:0] cnt=0;
reg z=0, rst_l=0;
wire restart = rst_l & ~rst;

assign cen_da = cen_in & z;

always @(posedge clk) begin
    if( cen_in ) cnt <= cnt==(MDIV[CW-1:0]-1) ? {CW{1'b0}} : cnt+1'd1;
    z <= cnt==0;
    cen_div <= cen_da;
    rst_l   <= rst;
    if( restart ) begin
        cnt     <= 0;
        z       <= 1;
        cen_div <= 0;
    end
end

endmodule