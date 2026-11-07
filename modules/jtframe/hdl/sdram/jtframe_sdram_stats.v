/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-10-2022 */

// see debug.md for a table describing the st_dout vs st_addr

module jtframe_sdram_stats(
    input               rst,
    input               clk,
    input         [3:0] rdy,
    input               LVBL,
    input         [7:0] st_addr,
    output reg    [7:0] st_dout
);

reg        LVBLl;
reg [19:0] acc_blank, acc_active,
           req_blank, req_active, req_frame;
reg [ 3:0] rdy_l;
reg        count_up;

always @* begin
    if( st_addr[5] )
        count_up   = |(rdy & ~rdy_l);
    else
        count_up   = rdy[ st_addr[1:0]] & ~rdy_l[st_addr[1:0]];
end

always @(posedge clk) begin
    LVBLl <= LVBL;
    rdy_l  <= rdy;
    if( count_up &&  LVBL ) acc_active <= acc_active+1'd1;
    if( count_up && !LVBL ) acc_blank  <= acc_blank+1'd1;
    req_frame <= req_blank + req_active;
    if( !LVBL && LVBLl ) begin
        req_blank  <= (req_blank >>1) + (acc_blank >>1);
        req_active <= (req_active>>1) + (acc_active>>1);
        acc_blank  <= 0;
        acc_active <= 0;
    end
end

always @(posedge clk) begin
    case( { st_addr[4], st_addr[3:2] } )
        3'b0_00: st_dout <= req_frame [19:12];
        3'b0_01: st_dout <= req_active[19:12];
        3'b0_10: st_dout <= req_blank [19:12];
        3'b1_00: st_dout <= req_frame [15:8];
        3'b1_01: st_dout <= req_active[15:8];
        3'b1_10: st_dout <= req_blank [15:8];
        default: st_dout <= 0;
    endcase
end

endmodule