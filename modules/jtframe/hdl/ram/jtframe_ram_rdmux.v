/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-3-2025 */

// read-only dual port for a single-port RAM
// output latency of two/three clocks: 1 from mux, 1 from RAM, 1 from data register
module jtframe_ram_rdmux #(parameter
    AW=10,
    DW=8
)(
    input               clk,

    // to RAM
    output     [AW-1:0] addr,
    input      [DW-1:0] data,

    // read ports
    input      [AW-1:0] addr_a,addr_b,
    input               cs_a,cs_b,
    output reg [DW-1:0] douta,doutb,
    output reg          ok_a,ok_b
);

reg a_sel=0;

assign addr = a_sel ? addr_a : addr_b;

always @(posedge clk) begin
    a_sel <= ~a_sel;
    ok_a <= 0;
    ok_b <= 0;
    // a_sel inverted because of 1-tick latency from RAM
    if(~a_sel && cs_a) begin
        douta <= data;
        ok_a <= 1;
    end
    if( a_sel && cs_b) begin
        doutb <= data;
        ok_b <= 1;
    end
end

endmodule
