/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2017 */

module jtframe_linebuf #(parameter
    DW=8,
    AW=9
)(
    input            clk,
    input            LHBL,  // the line buffer is swapped when this signal goes low
                            // you can use ~HS instead of LHBL too
    // New data writes
    input   [AW-1:0] wr_addr,
    input   [DW-1:0] wr_data,
    input            we,
    // Old data reads
    input   [AW-1:0] rd_addr,
    output  [DW-1:0] rd_data,
    output  [DW-1:0] rd_gated
);

reg     line, last_LHBL;

wire [DW-1:0]       dump_data;

`ifdef SIMULATION
initial begin
    line = 0;
end
`endif

always @(posedge clk) begin
    last_LHBL <= LHBL;
    if( !LHBL && last_LHBL )
        line <= ~line;
end

assign rd_gated = LHBL ? rd_data : {DW{1'b0}};

jtframe_rpwp_ram #(.AW(AW+1),.DW(DW)) u_line(
    .clk    ( clk           ),

    .din    ( wr_data       ),
    .wr_addr( {line,wr_addr}),
    .we     ( we            ),

    .rd_addr({~line,rd_addr}),
    .dout   ( rd_data       )
);

endmodule