/*  This file is part of JT_FRAME.
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
    Date: 6-12-2022 */

`ifdef JTFRAME_PXLCLK
module jtframe_pxlcen(
    input   clk,
    output  pxl_cen,
    output  pxl2_cen
);

    localparam PXLCLK = `JTFRAME_PXLCLK,
               CLK    = `ifdef JTFRAME_SDRAM96 96 `else 48 `endif,
               M      = (PXLCLK==12 ? 2 : PXLCLK==8 ? 3 : 4) << (CLK==96 ? 1:0);

    initial begin
        if( PXLCLK!=8 && PXLCLK!=6 ) begin
            $display("JTFRAME_PXLCLK is set to %d. But that value isn't supported yet.",PXLCLK);
            $finish;
        end else begin
            $display("jtframe_pxlcen: using %0d as clock divider", M[3:0]);
        end
    end

    jtframe_frac_cen #(.WC(4),.W(2)) u_cen(
        .clk    ( clk       ),    // 48 or 96 MHz
        .n      ( 4'd1      ),
        .m      (M[3:0]),
        .cen    ( { pxl_cen, pxl2_cen } ),
        .cenb   (           )
    );

endmodule
`endif
