/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-8-2020 */

module jtsarms_star(
    input               rst,
    input               clk,
    input               pxl_cen,
    input       [ 7:0]  V,
    input       [ 8:0]  H,
    input               fixed_n,
    // From CPU
    input               STARON,
    input               flip,
    input               hscan,
    input               vscan,
    // To SDRAM
    output      [14:0]  rom_addr,   // 27256
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // Output star
    output reg  [ 2:0]  star_pxl,
    input       [ 7:0]  debug_bus
);

reg  [8:0] hcnt, hsum;
reg  [7:0] vcnt, vsum;
reg  [7:0] data;
reg        last_h, last_v;
wire       posedge_h = !last_h && hscan;
wire       posedge_v = !last_v && vscan;

// in aged PCBs hsum[8] gets stuck to 1
assign rom_addr = { 3'b111, vsum, hsum[8] | fixed_n, hsum[7:5] };

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
        hsum <= hcnt + H - 9'd8;
        vsum <= vcnt + V;
    end
end

always @(posedge clk) begin
    // hsum[1] input to the large NAND is not connected (by pulling the pin off)
    // in the bootleg examined. Star field pictures from other boards match the
    // image with the pin pulled off. For the fixed version of the star field
    // I am connecting the pin as the designer intention.
    if( &{hsum[4:2], hsum[1]|~fixed_n, hsum[0], rom_ok} ) data <= rom_data;
    if(pxl_cen) begin
        star_pxl <= STARON && &(hsum[4:1]^data[4:1]) && ~(hsum[0]^data[0])
                    && (vsum[2]^H[5]) && (!hsum[2] || !vsum[1]) ?
            data[7:5] : 3'd0;
    end
end

endmodule