/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-4-2024 */

// average sound power
module jtframe_vumeter(
    input                   clk,
    input                   cen,    // use 192 kHz
    // input signals
    input  signed [15:0] l, r,
    output reg    [ 7:0]   vu,     // "volume unit", signals channel activity
    output reg            peak     // overflow signal
);

localparam W=28;

reg  signed [31:0] ml, mr;
reg  [15:0] l2r2; // accumulator result is always possitive
reg  [12:0] cnt;
reg  [ 5:0] peak_cnt;
reg  [ 1:0] cen_div=0;
reg         cen48;
reg  [W-1:0] acc;
wire [W-1:0] nx_acc;
wire        over, v;

assign over = &cnt;
assign {v, nx_acc} = ({1'b0,acc}>>over)+{ {W-16{1'b0}},l2r2};

always @(posedge clk) begin
    cen_div <= cen_div+2'd1;
    cen48   <= &cen_div;
end

always @(posedge clk) if(cen48) begin
    ml   <= l*l;
    mr   <= r*r;
    l2r2 <= ml[31-:16]+mr[31-:16];
    acc  <= v ? '1 : nx_acc;
    cnt  <= cnt+1;
    if(over) casez(acc[W-1-:8])
        8'b0000_0001: vu <= 8'h01;
        8'b0000_001?: vu <= 8'h03;
        8'b0000_01??: vu <= 8'h07;
        8'b0000_1???: vu <= 8'h0f;
        8'b0001_????: vu <= 8'h1f;
        8'b001?_????: vu <= 8'h3f;
        8'b01??_????: vu <= 8'h7f;
        8'b1???_????: vu <= 8'hff;
        default:      vu <= 0;
    endcase
    // peak
    if( &peak_cnt ) begin
        peak <= 0;
    end else begin
        peak_cnt <= peak_cnt+1'd1;
    end
    if( v ) begin
        peak     <= 1;
        peak_cnt <= 0;
    end
end

endmodule