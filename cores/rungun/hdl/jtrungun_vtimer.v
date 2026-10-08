/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-7-2025 */

module jtrungun_vtimer(
    input            rst, clk, pxl_cen, vld, hld,
                     hflip, vflip,
    output     [8:0] hdump, hdumpf,
    output     [7:0] vdump, vdumpf, vrender
);

wire [8:0] hinit;
wire [7:0] vinit;

reg  [8:0] hcnt;
reg  [7:0] vcnt, vnext;
reg        hld_l, vld_l;

assign hinit = { {3{hflip}}, 1'b0, hflip, 4'd0 };
assign vinit = { {4{vflip}}, 4'd0 };

assign hdump  = hcnt,
       hdumpf = {9{hflip}}^hdump,
       vdump  = vcnt,
       vdumpf = {8{vflip}}^vdump,
       vrender = vnext;

// external counters
always @(posedge clk) if(pxl_cen) begin
    hld_l <= hld;
    vld_l <= vld;
end

always @(posedge clk) begin
    if(rst) begin
        hcnt <= 0;
        vcnt <= 0;
        vnext <= 1;
    end else if(pxl_cen) begin
        hcnt <= hcnt+9'd1;
        if( hld & ~hld_l ) begin
            hcnt <= hinit;
            vcnt <= vnext;
            vnext <= vnext+8'd1;
        end
        if( vld & ~vld_l ) begin
            vcnt <= vinit;
            vnext <= vinit+8'd1;
        end
    end
end

endmodule
