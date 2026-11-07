/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-1-2024 */

module jtframe_sim_inputs(
    input             rst,
    input             vs,

    output      [6:0] joy1,
    output            start, service,
    output            coin,test, game_rst
);
`ifndef SIMINPUTS
assign {game_rst,test,joy1,service,start,coin} = 0;
`else
assign {game_rst,test,joy1,service,start,coin} = sim_inputs[frame_cnt][12:0];

reg [15:0] sim_inputs[0:16383];

integer frame_cnt;

initial begin : read_sim_inputs
    integer c;
    for( c=0; c<16384; c=c+1 ) sim_inputs[c] = 0;
    $display("INFO: input simulation enabled");
    $readmemh( "sim_inputs.hex", sim_inputs );
end

always @(negedge vs) begin
    if( rst ) begin
        frame_cnt <= 0;
    end else begin
        frame_cnt <= frame_cnt+1;
    end
end
`endif
endmodule