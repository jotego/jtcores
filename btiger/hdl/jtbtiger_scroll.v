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
    Date: 19-11-2017 */

module jtbtiger_scroll #(parameter 
    HOFFSET  = 9'd0
) (
    input              clk,     // 24 MHz
    input              pxl_cen  /* synthesis direct_enable = 1 */,    //  6 MHz
    input              cpu_cen,
    input       [11:0] AB,
    input        [7:0] V, // V128-V1
    input        [8:0] H, // H256-H1
    input        [8:0] hpos,
    input        [8:0] vpos,
    input              scr_cs,
    input              layout,
    input        [1:0] bank,
    input              flip,
    input        [7:0] din,
    output       [7:0] dout,
    input              wr_n,
    output             busy,

    // ROM
    output      [16:0] scr_addr,
    input       [15:0] rom_data,
    input              rom_ok,
    output       [7:0] scr_pxl
);

localparam POSW = 9;   // Scroll offset width, normally 9 bits

wire [8:0] Hfix = H + HOFFSET[8:0]; // Corrects pixel output offset
reg  [POSW-1:0] HS, VS;
wire [ 7:0] VF = {8{flip}}^V;
wire [ 7:0] HF = {8{flip}}^Hfix[7:0];

wire H7 = (~Hfix[8] & (~flip ^ HF[6])) ^HF[7];

reg [2:0] HSaux;

always @(posedge clk) begin
    VS = vpos + { {POSW-8{1'b0}}, VF};
    { HS[POSW-1:3], HSaux } = hpos + { {POSW-8{~Hfix[8]}}, H7, HF[6:0]};
    HS[2:0] = HSaux ^ {3{flip}};
end

wire [7:0] dout_low, dout_high;

localparam DATAREAD = 3'd1;

wire [7:0] Vtilemap = VS[POSW-1:POSW-8]; // : VS[7:0];
wire [7:0] Htilemap = HS[POSW-1:POSW-8];

wire [12:0] tile_addr = { bank, AB[11:1] };

jtgng_tilemap #(
    .SELBIT     ( 1         ),
    .INVERT_SCAN( 1         ),
    .DATAREAD   ( DATAREAD  ),
    .SCANW      ( 13        ),
    .SIMID      ( "CHAR"    )
) u_tilemap(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .Asel       ( AB[0]     ),
    .AB         ( tile_addr ),
    .V          ( Vtilemap  ),
    .H          ( Htilemap  ),
    .flip       ( 1'b0      ),  // Flip is already done on HS and VS
    .din        ( din       ),
    .dout       ( dout      ),
    .layout     ( layout    ),
    // Bus arbitrion
    .cs         ( scr_cs    ),
    .wr_n       ( wr_n      ),
    .busy       ( busy      ),
    // Pause screen -unused for scroll-
    .pause      ( 1'b0      ),
    .scan       (           ),
    .msg_low    ( 8'd0      ),
    .msg_high   ( 8'd0      ),
    // Current tile
    .dout_low   ( dout_low  ),
    .dout_high  ( dout_high ),
    // unused:
    .dseln      (           )
);

 jtbtiger_tile4 u_tile4(
    .clk        (  clk        ),
    .cen6       (  pxl_cen    ),
    .HS         (  HS[4:0]    ),
    .SV         (  VS[4:0]    ),
    .attr       (  dout_high  ),
    .id         (  dout_low   ),
    .SCxON      (  1'b0       ),
    .flip       (  flip       ),
    .layout     ( layout      ),
    // Gfx ROM
    .scr_addr   (  scr_addr   ),
    .rom_data   (  rom_data   ),
    .scr_pxl    (  scr_pxl    )
);       

endmodule // jtgng_scroll