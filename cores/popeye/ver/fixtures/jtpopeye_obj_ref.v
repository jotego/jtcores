`include "fixtures.vh"
/*  This file is part of JTPOPEYE.
    JTPOPEYE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTPOPEYE program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTPOPEYE.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-3-2019 */

`timescale 1ns/1ps

module jtpopeye_obj_2020(
    input               rst_n,
    input               clk,
    input               pxl_cen,
    input               pxl2_cen,

    input               ROHVS,
    input               ROHVCK,
    input               RV_n,
    input               INITEO,
    input               HB,
    input               VB,

    input      [ 7:0]   H,
    input      [17:0]   DJ,
    // SDRAM interface
    output reg [12:0]   obj_addr,
    input      [15:0]   obj_data0,
    input      [15:0]   obj_data1,
    // pixel data
    output reg [ 2:0]   OBJC,
    output reg [ 1:0]   OBJV
);

// DJ[0] - object's Y LSB (interlaced)
// DJ[3:1] - object's Y (mod 8)
// { DJ[17], DJ[10:4] } - object ID
// DJ[16:14] - object's palette. If == 3'b000 then result colour is always black
// DJ[11] - hflip
// DJ[13:12] - count start

reg hflip;
reg [15:0] objd0, objd1;

reg [2:0] objc;
reg [4:0] cnt;  // device 5E, video sheet 2/3

wire RV = ~RV_n;
wire [3:0] pload = { DJ[16:14]!=3'b000, 1'b1, DJ[13:12] ^ {2{RV_n}} };

always @(posedge clk) if( pxl_cen ) begin // 5E
    if( HB )
        cnt <= 5'd0;
    else begin
        if( H[1:0]==2'b11 ) begin
            cnt <= { &pload, pload };
            obj_addr <= { DJ[16], DJ[17], DJ[10:1], DJ[0]^~INITEO   };
            objc   <= DJ[16:14];
            hflip  <= DJ[11] ^ RV;
        end
        else
            cnt <= { cnt[3:0]==4'b1110, cnt[3:0]+4'd1 };
    end
end

reg HFLIP;
reg last_carry;
wire carry = cnt[4];

// devices 4K, 4L, 4J, 5K, 4F, 4H, 4E and 5F, video sheet 2/3
always @(posedge clk) if(pxl2_cen) begin : shift_register
    if( carry ) begin
        { objd1, objd0 } <= { obj_data1, obj_data0 };
    end else begin
        objd1 <= HFLIP ? { objd1[14:0], 1'b0 } : { 1'b0, objd1[15:1] }; // pink
        objd0 <= HFLIP ? { objd0[14:0], 1'b0 } : { 1'b0, objd0[15:1] }; // green
    end
end

always @(posedge clk) if(pxl2_cen) begin : u_4C
    last_carry <= cnt[4];
    if( carry  ) begin
        OBJC  <= objc;
        HFLIP <= hflip;  // shouldn't it be inverted?
    end
end

always @(posedge clk) begin : u_5J
    if( VB || HB ) begin
        OBJV <= 2'b00;      // Low outputs during blank as per LS157 behaviour
    end else begin
        OBJV <= HFLIP ? { objd1[15], objd0[15] } : { objd1[0], objd0[0] };
    end
end

endmodule // jtpopeye_obj
