/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-1-2025 */

// Provides H and V counters starting at zero while input
// LHBL and LVBL last
module jtframe_video_counter(
    input        rst,
    input        clk,
    input        pxl_cen,

    input        lhbl,
    input        lvbl,
    input        flip,

    output [8:0] v, h
);

reg  [8:0] vcnt, hcnt;
reg        lhbl_l;

assign v = vcnt ^ { 1'b0, {8{flip}}};
assign h = hcnt ^ { 1'b0, {8{flip}}};

always @(posedge clk) begin
    if( rst ) begin
        lhbl_l      <= 0;
        vcnt        <= 0;
        hcnt        <= 0;
    end else if(pxl_cen) begin
        lhbl_l <= lhbl & lvbl;
        if (!lvbl) begin
            vcnt <= 0;
        end else if( !lhbl && lhbl_l ) begin
            vcnt <= vcnt + 9'd1;
        end
        if (!lhbl) begin
            hcnt <= 0;
        end else begin 
            hcnt <= hcnt + 9'd1;
        end
    end
end

endmodule
