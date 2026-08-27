/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-2-2019 */

// Alternative memory for on-screen message generation
// SW = width of the memory address/scan vectors
// msg_width output is a fixed value equal to HVAL

module jtframe_charmsg #(parameter SW=10, HVAL=8'd2, VERTICAL=1)(
    input            clk,
    input            pxl_cen,  /* synthesis direct_enable = 1 */

    input      [3:0] avatar_idx,
    input   [SW-1:0] scan,
    output reg [7:0] msg_low,
    output     [7:0] msg_high
);

wire [7:0] mem_msg, mem_msg_av;

jtframe_ram #(.AW(SW),.SYNFILE("msg.hex"),.SIMFILE("msg.bin")) u_char_msg(
    .clk    ( clk         ),
    .cen    ( pxl_cen     ),
    .data   ( 8'd0        ),
    .addr   ( scan        ),
    .we     ( 1'b0        ),
    .q      ( mem_msg     )
);

`ifdef JTFRAME_AVATARS
wire [4:0] av_sel0 = VERTICAL ? scan[9:5] : scan[4:0];
wire [4:0] av_sel1  = VERTICAL ? scan[4:0] : scan[9:5];
localparam [4:0] AVPOS = VERTICAL ? 5'd8 : 5'd22;

wire [8:0] av_scan = { avatar_idx, av_sel0 };

jtframe_ram #(.AW(9),.SYNFILE("msg_av.hex")) u_ram_msg_av(
    .clk    ( clk         ),
    .cen    ( pxl_cen        ),
    .data   ( 8'd0        ),
    .addr   ( av_scan     ),
    .we     ( 1'b0        ),
    .q      ( mem_msg_av  )
);

reg av_col;

always @(*) begin
    av_col  = av_sel1 == AVPOS;
    msg_low = av_col ? mem_msg_av : mem_msg;
end
`else 
always @(*) msg_low = mem_msg;
`endif

assign msg_high = HVAL;

endmodule