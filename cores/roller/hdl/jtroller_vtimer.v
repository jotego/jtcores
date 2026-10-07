/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

// Pixel position counters driven by the K053252 load strobes. The visible
// period uses the same 020-19f coordinates as Konami's sprite logic. The
// vertical count starts one line earlier to align the rendered pixels.
module jtroller_vtimer(
    input            rst, clk, pxl_cen, hld, vld,
    output reg [8:0] hdump, vdump, vrender
);

reg hld_l, vld_l;

always @(posedge clk) if (pxl_cen) begin
    hld_l <= hld;
    vld_l <= vld;
end

always @(posedge clk) begin
    if (rst) begin
        hdump   <= 9'h020;
        vdump   <= 9'h0f7;
        vrender <= 9'h0f8;
    end else if (pxl_cen) begin
        hdump <= hdump+9'd1;
        if (hld && !hld_l) begin
            hdump   <= 9'h020;
            vdump   <= vrender;
            vrender <= vrender+9'd1;
        end
        if (vld && !vld_l) begin
            vdump   <= 9'h0f7;
            vrender <= 9'h0f8;
        end
    end
end

endmodule
