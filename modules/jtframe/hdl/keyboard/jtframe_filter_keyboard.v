/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-1-2025 */

// prevents wrong inputs from keyboard
// pressing both left+right will make none to be pressed
// pressing both up  +down  will make none to be pressed
// transparent to other cases

module jtframe_filter_keyboard(
    input            clk,
    // decodes keys
    input      [9:0] raw1,
    input      [9:0] raw2,
    input      [9:0] raw3,
    input      [9:0] raw4,

    // decodes keys
    output     [9:0] joy1,
    output     [9:0] joy2,
    output     [9:0] joy3,
    output     [9:0] joy4
);

localparam JOYCOUNT=4,AXIS=2,AXISW=2,DIRW=JOYCOUNT*AXIS*AXISW;

reg  [DIRW-1:0] filtered;
wire [DIRW-1:0] raw;

assign raw  = {raw4[3:0],raw3[3:0],raw2[3:0],raw1[3:0]};
assign joy1 = {raw1[9:4],filtered[ 0+:4]};
assign joy2 = {raw2[9:4],filtered[ 4+:4]};
assign joy3 = {raw3[9:4],filtered[ 8+:4]};
assign joy4 = {raw4[9:4],filtered[12+:4]};

function [1:0] filter(input [1:0]exclusive);
begin
    case(exclusive)
        2'b11:   filter=2'b00;
        default: filter=exclusive;
    endcase
end
endfunction    

integer i;

always @(posedge clk) begin
    for(i=0;i<DIRW;i=i+AXISW)
        filtered[i+:2] <= filter(raw[i+:2]);
end

endmodule    