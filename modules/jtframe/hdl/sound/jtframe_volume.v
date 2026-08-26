/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 10-5-2021 */

module jtframe_volume(
    input            rst,
    input            clk,
    input            vs,
    input            peak,
    input            up,
    input            down,
    input      [7:0] game_vol,
    output reg [7:0] vol
);

localparam [7:0] UNSET=8'h0;

reg lock, vs_l, peaked;
reg [ 7:0] knob;
reg [15:0] vol16;

always @(posedge clk) begin
    vol16 <= game_vol==UNSET ? {knob,8'd0} : knob*game_vol;
    vol   <= vol16[15] ? 8'hff : vol16[14-:8];
end

always @(posedge clk) begin
    if( rst ) begin
        knob   <= 8'h80; // matching value in game_test.v
        vs_l   <= 0;
        lock   <= 0;
        peaked <= 0;
    end else begin      
        vs_l <= vs;  
        if(  peak ) peaked <= 1;
        if( !lock ) begin
            if( ~&knob && up && !peaked ) begin
                knob <= knob+8'd1;
            end
            if(  |knob && down ) begin
                knob <= knob-8'd1;
                peaked <= 0;
            end
            lock <= 1;
        end
        if( vs && !vs_l ) lock <= 0;
    end
end

endmodule