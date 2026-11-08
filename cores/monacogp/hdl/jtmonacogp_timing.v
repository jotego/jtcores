// SPDX-License-Identifier: GPL-3.0-or-later
// 96578-P sheet E, manual 420-0358 PDF page 32.
// Settled-state equivalent of IC108/107/116 and IC102/100/109.
// RC pulse shaping and TTL propagation delays are not reproduced in hardware.
module jtmonacogp_timing(
    input clk, rst, pxl_cen,
    output reg [8:0] h,
    output reg [8:0] v,
    output reg hblank,
    output vblank, hs, vs,
    output [8:0] x, y,
    output [8:0] hpos, vpos
);
    // IC115 pins 3,4,5 = /H5, H6, horizontal blanking latch.
    assign hs = hblank & ~h[5] & h[6];
    // IC115 pins 13,1,2 = /V3, V2, V8.
    assign vs = v[8] & ~v[3] & v[2];
    // IC101: V8 or all-zero V7..V4 blanks the vertical interval.
    assign vblank = v[8] | (v[7:4] == 4'd0);
    assign x = h - 9'h098;
    assign y = v - 9'd16;
    assign hpos = hblank ? (9'd200 + {1'b0,h[7:0]}) : x;
    assign vpos = v[8] ? {1'b0,v[7:0]} :
                  (v[7:4] == 0 ? 9'd248 + {1'b0,v[7:0]} : y);

    always @(posedge clk) begin
        if (rst) begin
            // Deterministic entry into the stable repeating cycle.
            // The original oscillators/counters have no equivalent global reset.
            h <= 9'h098;
            hblank <= 0;
            v <= 9'd16;
        end else if (pxl_cen) begin
            if (h[7:0] == 8'hff) begin
                // Both JK halves see the falling carry of IC107.
                h[8] <= ~hblank;
                hblank <= h[8] & ~hblank; // includes asynchronous clear by H8
                // IC115 /LOAD decode and parallel data pins.
                h[7:0] <= h[8] ? (hblank ? 8'h98 : 8'ha0) : 8'h00;
            end else h[7:0] <= h[7:0] + 8'd1;

            // Vertical 161 clocks see the rising edge of /HS, at H=$1df->$1e0.
            if (hblank && h[7:0] == 8'hdf) begin
                if (v[7:0] == 8'hff) begin
                    // IC102 D=V8; IC100 A..D=/V8; IC109 toggles on carry fall.
                    v <= {~v[8], {4{~v[8]}}, v[8], 3'b000};
                end else v[7:0] <= v[7:0] + 8'd1;
            end
        end
    end
endmodule
