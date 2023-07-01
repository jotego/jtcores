/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-10-2022 */

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