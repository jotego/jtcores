/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 01-11-2026 */

module jtttnose_colmix(
    input             video_en,
    input      [2:0]  gfx_en,
    input      [6:0]  roz_pxl, obj_pxl,
    input      [10:0] tx_pxl,
    output reg [10:0] pal_addr
);

always @* begin
    pal_addr = 0;
    if(video_en) begin
        if(gfx_en[0]) pal_addr = {4'h4,roz_pxl};
        if(gfx_en[1] && obj_pxl[3:0]!=4'hf) pal_addr = {4'h5,obj_pxl};
        if(gfx_en[2] && tx_pxl[3:0]!=4'hf) pal_addr = tx_pxl;
    end
end

endmodule
