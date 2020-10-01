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

// This module is meant to be equivalent to schematic sheet 12/12
// but the output doesn't agree to pictures from PCB
// Possible reasons:
// 1. Starfield ROM dump is wrong. Unless you pay close attention, you
//    wouldn't notice.
//    The size of the ROM dump does not agree with the size of the ROM
//    in the schematics. The dump is not a 16kB ROM duplicated into 32kB,
//    but data really is 32kB long.
// 2. The schematic sheet is very hard to read. I might have got one or
//    or more signals or gates wrong
// 3. Data from the ROM is latched at the 1F to 00 transition of horizontal-
//    sum bits. I think at that point the data latched actually correspond
//    to the previous ROM address values as the data delay is smaller up to
//    the latch clock input compared to the data inputs
// 4. The top bit of the horizontal ripple counter is taken from the negative
//    output, which I find confusing. But it wouldn't make sense if either
//    the counter, or the HSUM were not continuous sequences

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
    output      [14:0]  rom_addr,
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

assign rom_addr = { 3'b111, vsum, hsum[8:5] };

always @(posedge clk) begin
    last_h <= hscan;
    last_v <= vscan;
end

always @(posedge clk) begin
    if( !STARON || rst ) begin
        hcnt <= 9'd0;
        vcnt <= 8'd0;
        hsum <= 9'd0;
        vsum <= 8'd0;
    end else begin
        if( posedge_h ) hcnt<= flip ? hcnt-1'd1 : hcnt+1'd1;
        if( posedge_v ) vcnt<= flip ? vcnt-1'd1 : vcnt+1'd1;
        hsum <= hcnt + H;
        vsum <= vcnt + V;
    end
end

always @(posedge clk) if(pxl_cen) begin
    if( hsum[4:0]==5'h1f ) data <= rom_data;
    star_pxl <= STARON && &(hsum[4:1]^data[4:1]) && ~(hsum[0]^data[0])
                && (vsum[2]^H[5]) && (!hsum[2] || !vsum[1]) ?
        data[7:5] : 3'd0;
end

endmodule