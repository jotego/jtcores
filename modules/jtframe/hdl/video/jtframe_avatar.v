/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-2-2019 */


module jtframe_avatar #(parameter AW=13)(
    input             rst,
    input             clk,
    input             pause,
    input    [AW-1:0] obj_addr,
    input      [15:0] obj_data,
    input             ok_in,
    output reg        ok_out,
    output reg [15:0] obj_mux
);

`ifdef JTFRAME_AVATARS
    // Alternative Objects during pause for MiSTer
    wire [15:0] avatar_data;
    jtframe_ram #(.DW(16), .AW(AW), .SYNFILE("avatar.hex"),.CEN_RD(1)) u_avatars(
        .clk    ( clk            ),
        .cen    ( pause          ),  // tiny power saving when not in pause
        .data   ( 16'd0          ),
        .addr   ( obj_addr       ),
        .we     ( 1'b0           ),
        .q      ( avatar_data    )
    );
    always @(posedge clk) begin
        obj_mux <= pause ? avatar_data : obj_data;
        ok_out  <= ok_in;
    end
`else
    // Let the real data go through
    always @(*) begin
        obj_mux = obj_data;
        ok_out  = ok_in;
    end
`endif

endmodule