/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-7-2022 */

// dummy motor, follows MAME's implementation

module jtoutrun_motor(
    input              rst,
    input              clk,
    input              vint,
    input      [ 7:0]  ctrl,
    output reg [ 2:0]  limpos,
    output reg [15:0]  pos
);

localparam [15:0] LEFTLIM  = 16'h2000, 
                  RIGHTLIM = 16'he000;

reg        vintl;
reg [15:0] nx_pos;

always @* begin
    nx_pos = ctrl[3] ? 
        pos + { 8'd0,  ctrl[2:0], 5'd0 } : // right
        pos - { 8'd0, ~ctrl[2:0], 5'd0 };
    if( nx_pos < LEFTLIM  ) nx_pos = LEFTLIM;
    if( nx_pos > RIGHTLIM ) nx_pos = RIGHTLIM;
end

always @(posedge clk, posedge rst ) begin
    if( rst ) begin
        pos    <= 16'h8000;
        vintl  <= 0;
        limpos <= 0;
    end else begin
        vintl <= vint;
        limpos <= ~{
            pos[15:8]==LEFTLIM[15:8],
            pos[15:8]==8'h80,
            pos[15:8]>=RIGHTLIM[15:8]-8'h1
        };
        if( vint && !vintl )
            pos <= nx_pos;
    end
end

endmodule