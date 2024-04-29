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
    Date: 28-3-2024 */

module jts18_colmix(
    input          clk,
    input          pxl_cen,
    input          LVBL,
    input          LHBL,

    // S18 palette
    output  [11:1] pal_addr,
    input   [15:0] pal_dout,
    // Genesis VDP


    output  [ 5:0] red, green, blue
);

wire [ 4:0] rpal, gpal, bpal;
wire        hilo;

assign rpal  = { pal_dout[ 3:0], pal_dout[12] };
assign gpal  = { pal_dout[ 7:4], pal_dout[13] };
assign bpal  = { pal_dout[11:8], pal_dout[14] };
assign hilo  =   pal_dout[15];

// Model of 315-5242 DAC
jtshanon_coldac u_dac(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .rin        ( rpal      ),
    .gin        ( gpal      ),
    .bin        ( bpal      ),
    .sh         ( shadow    ),
    .en         ( video_en  ),
    .hilo       ( hilo      ),
    .rout       ( pr        ),
    .gout       ( pg        ),
    .bout       ( pb        )
);

endmodule