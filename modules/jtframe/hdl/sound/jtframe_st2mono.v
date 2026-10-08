/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-3-2024 */

// converts stereo to mono by a clipping adder
// or leaves the signal as stereo if the output can take stereo
module jtframe_st2mono #(parameter
    W          = 12,
    STEREO_IN  = 1,
    STEREO_OUT = 1,
    // Do not assign
    EFF_OUT    = STEREO_IN==1&&STEREO_OUT==1 ? 1 : 0,
    WI   = (STEREO_IN==1?2*W:W),
    WO   =    EFF_OUT==1?2*W:W
)(
    input      [WI-1:0] sin,
    output reg [WO-1:0] sout
);

initial begin
    if(STEREO_IN==0 && EFF_OUT==1) begin
        $display("mono to stereo conversion is not supported");
        `ifdef SIMULATION
        $stop;
        `endif
    end
end

wire [W:0] raw = {sin[W-1],sin[0+:W]}+{sin[WI-1],sin[WI-1-:W]};
reg [W-1:0] mono;
localparam [1:0] ST2MONO  =2'b10,
                 STEREO   =2'b11;

always @* begin
    mono = raw[W]!=raw[W-1] ? { raw[W], {W-1{~raw[W]}}} : raw[W-1:0];
    case( {STEREO_IN[0], EFF_OUT[0]} )
        STEREO:  sout        = sin[WO-1:0];
        ST2MONO: sout[W-1:0] = mono;
        default: sout[W-1:0] = sin[W-1:0];
    endcase
end

endmodule
