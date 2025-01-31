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
    Date: 26-1-2025 */

module jtframe_debug_keys(
    input            rst,
    input            clk,

    input            ctrl, shift,
    input     [12:7] func_key,
    // active low
    input            coin_n,
    input            start_n,
    input      [9:0] joy_n,
    // active high
    input            plus,
    input            minus,

    output     [3:0] gfx_en,
    output     [5:0] snd_en,

    output reg       debug_toggle,
    output reg [1:0] debug_plus,
    output reg [1:0] debug_minus
);
`ifdef JTFRAME_RELEASE
    assign gfx_en=4'hf;
    assign snd_en=6'h3f;
    initial begin
        debug_toggle = 0;
        debug_plus   = 0;
        debug_minus  = 0;
    end
`else
localparam [3:0] UP=3, DOWN=2;

wire key_toggle =  ctrl     &  shift;
wire alt_toggle = !start_n && joy_n[1:0]!=3;

wire alt_plus   = ~start_n & ~joy_n[UP];
wire alt_minus  = ~start_n & ~joy_n[DOWN];

wire alt_plus16 =  ~coin_n & ~joy_n[UP];
wire alt_minus16=  ~coin_n & ~joy_n[DOWN];

always @(posedge clk) begin
    if(rst) begin
        debug_toggle <= 0;
        debug_plus   <= 0;
        debug_minus  <= 0;
    end else begin
        debug_toggle  <= key_toggle | alt_toggle;

        // 1 count steps
        debug_plus [0] <= plus      | alt_plus;
        debug_minus[0] <= minus     | alt_minus;

        // 16-count steps
        debug_plus [1] <= (plus &shift) | alt_plus16;
        debug_minus[1] <= (minus&shift) | alt_minus16;
    end
end

jtframe_toggle #(.W(4),.VALUE_AT_RST(1'b1)) u_gfxen(
    .rst    ( rst           ),
    .clk    ( clk           ),

    .toggle ( func_key[10:7]),
    .q      ( gfx_en        )
);

wire [5:0] snden_toggle = {6{shift}} & func_key[12:7];

jtframe_toggle #(.W(6),.VALUE_AT_RST(1'b1)) u_snden(
    .rst    ( rst           ),
    .clk    ( clk           ),

    .toggle ( snden_toggle  ),
    .q      ( snd_en        )
);
`endif
endmodule 
