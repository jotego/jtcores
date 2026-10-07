/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtroller_colmix(
    input             rst, clk, pxl_cen,
    input             lhbl, lvbl,
    input      [ 7:0] psac_pxl,
    input             psac_opaque,
    input      [ 8:0] obj_pxl,
    input             shadow,
    output     [ 4:0] red, green, blue,
    output     [10:0] pal_addr,
    input      [ 7:0] pal_data,
    input      [ 3:0] gfx_en
);

wire [ 9:0] pal_idx;
wire        psac_valid, obj_valid, obj_front, shad;
reg         pal_half, shadow_l;
reg  [15:0] pal_word;
reg  [14:0] rgb;

assign psac_valid = psac_opaque && gfx_en[1];
assign obj_valid  = obj_pxl[3:0]!=0 && gfx_en[3];
// Sprite color bit 4 selects the foreground side of the zoom layer.
assign obj_front  = obj_pxl[8];
assign pal_idx    = obj_valid && (obj_front || !psac_valid) ?
                    {2'b01,obj_pxl[7:0]} :
                    psac_valid ? {4'd0,psac_pxl[5:0]} : 10'h100;
assign pal_addr   = {pal_idx,pal_half};
assign shad       = shadow && obj_valid && !obj_front;
assign {blue,green,red} = (lhbl && lvbl) ? rgb : 15'd0;

always @(posedge clk) begin
    if (rst) begin
        pal_half <= 0;
        shadow_l <= 0;
        rgb      <= 0;
    end else begin
        pal_word <= {pal_word[7:0],pal_data};
        if (pxl_cen) begin
            rgb      <= shadow_l ? {1'b0,pal_word[14:11],
                                    1'b0,pal_word[ 9: 6],
                                    1'b0,pal_word[ 4: 1]} : pal_word[14:0];
            shadow_l <= shad;
            pal_half <= 0;
        end else begin
            pal_half <= ~pal_half;
        end
    end
end

endmodule
