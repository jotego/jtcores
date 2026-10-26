/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

module jtroundu_bg(
    input             rst,
    input             clk,
    input             pxl_cen,
    input       [8:0] h,
    input       [8:0] v,
    input      [15:0] back_x,
    input      [15:0] scroll_x,
    input      [15:0] scroll_y,
    output reg [16:0] gfx_addr,
    input       [7:0] gfx_data,
    output reg  [8:0] pxl,
    output reg        solid
);

reg [2:0] phase;
reg [16:0] near_addr;
reg far_valid, near_valid, far_odd, near_odd;
reg [3:0] far_pen;
wire [3:0] near_pen = near_odd ? gfx_data[7:4] : gfx_data[3:0];
wire [8:0] far_x = h + back_x[8:0];
wire [8:0] near_x = h + scroll_x[8:0];
wire signed [10:0] far_y = $signed({2'd0,v}) + $signed({2'd0,scroll_y[8:0]}) - 11'sd384;
wire signed [10:0] near_y = far_y - 11'sd64;

always @(posedge clk) begin
    if (rst) begin
        phase <= 0;
        gfx_addr <= 0;
        near_addr <= 0;
        far_valid <= 0;
        near_valid <= 0;
        far_odd <= 0;
        near_odd <= 0;
        far_pen <= 0;
        pxl <= 0;
        solid <= 0;
    end else if (pxl_cen) begin
        phase <= 1;
        gfx_addr <= {2'b10,far_y[6:0],far_x[8:1]};
        near_addr <= {3'b110,near_y[5:0],near_x[8:1]};
        far_valid <= far_y >= 0 && far_y < 128;
        near_valid <= near_y >= 0 && near_y < 64;
        far_odd <= far_x[0];
        near_odd <= near_x[0];
    end else if (phase != 0) begin
        phase <= phase + 1'b1;
        case (phase)
            2: begin
                far_pen <= far_valid ? (far_odd ? gfx_data[7:4] : gfx_data[3:0]) : 4'd0;
                gfx_addr <= near_addr;
            end
            4: begin
                pxl <= near_valid && near_pen != 0 ? {5'h10,near_pen} : {5'h11,far_pen};
                solid <= (near_valid && near_pen != 0) || far_pen != 0;
                phase <= 0;
            end
            default: ;
        endcase
    end
end

endmodule
