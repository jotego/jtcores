/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-10-2026 */

module jtsvolle_colmix(
    input             rst, clk, pxl_cen, LHBL, LVBL, rpunch,
    input      [7:0]  scr0, scr1,
    input      [8:0]  obj,
    input      [3:0]  bitmap, bitmap_bank,
    input      [3:0]  gfx_en,
    output     [10:1] pal_addr,
    input      [15:0] pal_data,
    output reg [4:0]  red, green, blue
);

wire fg = gfx_en[1] && scr1[3:0]!=4'hf;
wire sprite = gfx_en[3] && obj[3:0]!=4'hf;
wire [9:0] obj_index = (rpunch ? 10'h300 : 10'h080)+{2'd0,obj[7:0]};

assign pal_addr = rpunch && gfx_en[2] && bitmap!=4'hf ? {2'b10,bitmap_bank,bitmap} :
                 sprite && (obj[8] || !fg) ? obj_index :
                 fg ? {2'b01,scr1} :
                 gfx_en[0] ? {2'b00,scr0} : 10'd0;

always @(posedge clk) begin
    if(rst) {red,green,blue} <= 0;
    else if(pxl_cen) {red,green,blue} <= LHBL && LVBL ? pal_data[14:0] : 15'd0;
end

endmodule
