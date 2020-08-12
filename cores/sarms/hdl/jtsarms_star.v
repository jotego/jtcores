/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-8-2020 */

module jtsarms_star(
    input               rst,
    input               clk,
    input               pxl_cen,
    input       [ 7:0]  V,
    input       [ 8:0]  H,
    // From CPU
    input               STARON,
    input               flip,
    input               hscan,
    input               vscan,
    // To SDRAM
    output      [13:0]  rom_addr,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // Output star
    output reg  [ 2:0]  star_pxl
);

reg  [8:0] hcnt, hsum;
reg  [7:0] vcnt, vsum;
reg  [7:0] data;
reg        last_h, last_v;
wire       posedge_h = !last_h && hscan;
wire       posedge_v = !last_v && vscan;

assign rom_addr = { 2'b11, vsum, hsum[8:5] };

always @(posedge clk) begin
    last_h <= hscan;
    last_v <= vscan;
    if( !STARON ) begin
        hcnt <= 9'd0;
        vcnt <= 8'd0;
    end else begin
        if( posedge_h ) hcnt<= flip ? hcnt-1'd1 : hcnt+1'd1;
        if( posedge_v ) vcnt<= flip ? vcnt-1'd1 : vcnt+1'd1;
        hsum <= hcnt + H;
        vsum <= vcnt + V;
    end
end

always @(posedge clk) begin
    if( rom_ok && hsum[4:0]==5'd0 ) data <= rom_data;
    if( pxl_cen ) begin
        star_pxl <= STARON && &(hsum[4:1]^data[4:1]) && ~(hsum[0]^data[0])
                    && (vsum[2]^H[5]) && (!hsum[2] || !vsum[1]) ?
            data[7:5] : 3'd0;
    end
end

endmodule