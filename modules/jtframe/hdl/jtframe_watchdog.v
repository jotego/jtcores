/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 6-3-2025 */

module jtframe_watchdog #(
    parameter
        W=3,
        INVERT=0    // wdog=!INVERT when a watchdog event occurs
)(
    input  rst, clk, lvbl, clr,
    output reg wdog
);

reg [W-1:0] cnt=0;
reg lvbl_l=0;
wire frame = ~lvbl &lvbl_l;

localparam [0:0] RESET=~INVERT[0], ACTIVE=INVERT[0];

always @(posedge clk) begin
    lvbl_l  <= lvbl;
end

always @(posedge clk) begin
    wdog <= &cnt ? RESET : ACTIVE;
    if( rst ) begin
        cnt  <= 0;
        wdog <= RESET;
    end else if( clr) begin
        cnt  <= 0;
    end else if(frame) begin
        cnt  <= cnt+1'd1;
    end
end

endmodule