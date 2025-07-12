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
    Date: 6-12-2022 */

`ifdef JTFRAME_PXLCLK
module jtframe_pxlcen(
    input   clk,
    output  pxl_cen,
    output  pxl2_cen
);

    localparam PXLCLK = `JTFRAME_PXLCLK;

    reg [3:0] m;
    wire is_clk112, is_clk96, is_clk48, pll7000, sdram96;

    assign pll7000 = `ifdef JTFRAME_PLL7000 1 `else 0 `endif ;
    assign sdram96 = `ifdef JTFRAME_SDRAM96 1 `else 0 `endif ;
    assign is_clk112 = sdram96 &  pll7000;
    assign is_clk96  = sdram96 & ~pll7000;
    assign is_clk48  =~sdram96;

    initial begin
        m = 1;
        if(is_clk112) case(PXLCLK)
            8: m=7;
            6: begin $display("Cannot produce 6MHz with an integer divider at 112MHz"); $finish; end
            default:;
        endcase
        if(is_clk96) case(PXLCLK)
            8: m=6;
            6: m=8;
            default:;
        endcase
        if(is_clk48) case(PXLCLK)
            8: m=3;
            6: m=4;
            default:;
        endcase
    end

    initial begin
        if( PXLCLK!=8 && PXLCLK!=6 ) begin
            $display("JTFRAME_PXLCLK is set to %d. But that value isn't supported yet.",PXLCLK);
            $finish;
        end else begin
            $display("jtframe_pxlcen: using %0d as clock divider", m);
        end
    end

    jtframe_frac_cen #(.WC(4),.W(2)) u_cen(
        .clk    ( clk       ),    // 48 or 96 MHz
        .n      ( 4'd1      ),
        .m      ( m         ),
        .cen    ( { pxl_cen, pxl2_cen } ),
        .cenb   (           )
    );

endmodule
`endif
