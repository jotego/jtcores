/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-1-2020 */


module jtcps1_timing(
    input              clk,
    input              cen8,

    output reg [ 8:0]  hdump,
    output reg [ 8:0]  vdump,
    output reg [ 8:0]  vrender,
    output reg [ 8:0]  vrender1,
    output reg         line_start,
    output reg         line_inc,
    output reg         frame_start,
    // to video output
    output reg         HS,
    output reg         VS,
    output reg         VB,
    output             preVB,
    output reg         HB,
    input      [ 7:0]  debug_bus
);

reg [1:0] shVB;

`ifdef SIMULATION
initial begin
    hdump       = 9'd0;
    vrender1    = 9'hf2;
    vrender     = 9'hf1;
    vdump       = 9'hf0;  // start with the full V blank period
    HS          = 1'b0;
    VS          = 1'b0;
    HB          = 1'b1;
    VB          = 1'b1;
    shVB        = 2'b11;
    line_start  = 1'b1;
    line_inc    = 1'b0;
    frame_start = 1'b0;
end
`endif

assign preVB = shVB[0];

localparam [8:0] VS_START = 9'd251; // larger values pull it up
localparam [8:0] VS_END   = VS_START + 9'd4;
localparam [8:0] HS_START = 9'd487; // larger values pull it left
localparam [8:0] HS_LEN   = 9'd38;
localparam [8:0] HS_END   = HS_START<(9'd511-HS_LEN) ? (HS_START+HS_LEN) : ( HS_LEN-(9'd511-HS_START)-9'd1  );

always @(posedge clk) if(cen8) begin
    hdump     <= hdump+9'd1;
    shVB[0] <= vdump<(9'd14) || vdump>9'd237; // 224 visible lines
    HB      <= hdump>=(9'd384+9'd64) || hdump<9'd64;
    if( hdump== HS_START ) begin
        HS <= 1'b1; // original HS duration = 36 clock ticks
        if ( vdump==VS_START ) VS <= 1'b1;
        if ( vdump==VS_END   ) VS <= 1'b0;
    end
    if( hdump== HS_END ) HS <= 1'b0;
    line_start  <= hdump==HS_START && vdump<9'hF0 && vdump>9'h0c;
    line_inc    <= hdump==HS_START;
    if( hdump==HS_START-1'd1 ) begin
        { VB, shVB[1] } <= shVB;
    end
    if( hdump==HS_START ) begin
        vrender1<= vrender1==9'd261 ? 9'd0 : vrender1+9'd1;
        vrender <= vrender1;
        vdump   <= vrender;
        frame_start <= vrender1==9'd260; // see issue #610
    end else begin
        frame_start <= 0;
    end
    if(&hdump) begin
        hdump <= 9'd0;
    end
end

endmodule
