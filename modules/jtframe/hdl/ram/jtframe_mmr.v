/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-5-2021 */

module jtframe_mmr #(parameter
    SIZE  =10,
    SIMHEX="",
    DW    = 8,
    AW    = $clog2(SIZE),
    DUMPW = AW+$clog2(DW/8)
) (
    input                rst,
    input                clk,
    input                cen,

    input       [AW-1:0] addr,
    input                we,
    input       [DW-1:0] din,
    output      [DW-1:0] dout,
    output [SIZE*DW-1:0] mmr
    // serial output
    `ifdef JTFRAME_DUMP
    ,input    [DUMPW-1:0] dump_a
    ,output         [7:0] dump
    `endif
);

localparam DAW=$clog2(DW);
localparam FAW=AW+DAW;

`ifdef SIMULATION
initial begin
    if( $log2(DW) != $clog2(DW) ) begin
        $display("jtframe_mmr: DW must be a power of 2 (%m)");
        $finish;
    end
    if( DW<8 ) begin
        $display("jtframe_mmr: DW must be a at least 8 (%m)");
        $finish;
    end
end
`endif

`ifdef JTFRAME_DUMP
assign dump=mmr[ {dump_a,3'd0} +: 8];
`endif

wire [FAW-1:0] fa = { addr, {DAW{1'b0}}};

assign dout = mmr[ fa +: DW ];

always @(posedge clk) begin
    if( rst ) begin
        mmr <= 0;
    end else if(cen) begin
        mmr[ fa +: DW ] <= din;
    end
end

endmodule