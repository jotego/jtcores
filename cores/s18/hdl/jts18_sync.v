/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-11-2026 */

module jts18_sync(
    input             clk,
    input             pxl_cen,
    input             is_57Hz,
    input      [8:0]  hdump,
    input      [8:0]  vdump,
    output reg        HS,
    output reg        VS
);

wire [8:0] hs_start, hs_end, vs_start, vs_end;

// These edges replace the old MiSTer OSD centering (H+4 at 57 Hz, H+7 at
// 60 Hz, V-4). The raw timer sync remains internal to the S16 object scanner
// and VDP; this helper only drives the S18 output pins.
assign hs_start = is_57Hz ? 9'h088 : 9'h08e;
assign hs_end   = is_57Hz ? 9'h0a8 : 9'h0ae;
assign vs_start = is_57Hz ? 9'h0eb : 9'h0e9;
assign vs_end   = is_57Hz ? 9'h0ef : 9'h0ed;

`ifdef SIMULATION
initial begin
    HS = 0;
    VS = 0;
end
`endif

always @(posedge clk) if (pxl_cen) begin
    if (hdump==hs_start) HS <= 1;
    if (hdump==hs_end) begin
        HS <= 0;
        if (vdump==vs_start) VS <= 1;
        if (vdump==vs_end)   VS <= 0;
    end
end

endmodule
