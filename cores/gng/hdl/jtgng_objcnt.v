/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2019 */

module jtgng_objcnt #(parameter
    [5:0] OBJMAX_LINE = 6'd24
) (
    input               rst,
    input               clk,
    input               draw_cen /*direct_enable*/,
    input               rom_ok,

    input               HINIT,
    output              HINIT_draw,
    output              rom_wait,
    output reg          draw_over,
    output reg [4:0]    objcnt,
    output reg [3:0]    pxlcnt
);

// HINIT is generated in the pxl_cen domain (6MHz)
// If cen is 8MHz, The HINIT pulse will last for two 8MHz cen pulses
// and that can create problems.
// The signal is resampled here to obtain a shortened version.

jtframe_cencross_strobe u_hinit(
    .rst    ( rst         ),
    .clk    ( clk         ),
    .cen    ( draw_cen    ),
    .stin   ( HINIT       ),
    .stout  ( HINIT_draw  )
);

reg  over;
reg  wait_latch;
wire wait_cond = !rom_ok /*&& pxlcnt[1:0]==2'b11*/; // the 2'b11 condition creates artifacts in Side Arms at least

assign rom_wait = wait_cond | wait_latch;

always @(posedge clk) if(draw_cen) begin
    if( HINIT_draw ) begin
        { over, objcnt, pxlcnt } <= { 6'd32-OBJMAX_LINE,4'd0};
        draw_over  <= 1'b0;
        wait_latch <= 1'b0;
    end else begin
        // stops at the data collection point if rom data is not available
        // give extra time to the draw module to finish
        if( over && pxlcnt[2:0] == 3'd6 ) draw_over <= 1'b1;
        if( draw_over ) { objcnt, pxlcnt } <= { 5'd0, 4'd0 };
        if( !draw_over && !rom_wait )
            { over, objcnt, pxlcnt } <=  { over, objcnt, pxlcnt } + 1'd1;
        wait_latch <= wait_cond;
    end
end

endmodule