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
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-8-2022 */

module jtframe_pocket_video #(parameter
    COLORW = 4
) (
    input             clk,
    input             pxl2_cen,
    // scaler modes
    input             sht_en,       // enable blank shortening
    input             sht_wide,     // wide shortening (16pxl per side)
    input      [ 1:0] rotate,
    // Base video
    input [3*COLORW-1:0] base_rgb,
    input             base_lhbl,
    input             base_lvbl,
    input             base_hs,
    input             base_vs,
    // Final video
    output     [11:0] scal_vid,
    output            scal_clk,
    output            scal_de,
    output            scal_skip,
    output            scal_vs,
    output            scal_hs

);

reg  [ 3:0] pxl_cnt, pxl_90;
reg         hsl, vsl;
wire [COLORW-1:0] br,bg,bb;
reg  [23:0] pck_rgb;
reg         pck_rgb_clk, pck_rgb_clkq, pck_de, pck_vs, pck_hs;
wire        pck_skip, de;

`ifdef SIMULATION
    // counts the active video size
    integer hcnt=0, vcnt=0, htotal=0, vtotal=0;

    always @(posedge pck_rgb_clk) begin
        if( pck_hs ) begin
            hcnt <= 0;
            if( base_lvbl ) vcnt <= vcnt+1;
            if( hcnt!=0 ) htotal <= hcnt;
        end
        if( pck_vs ) begin
            vcnt <= 0;
            vtotal <= vcnt;
            $display("Pocket video size %0dx%0d",htotal, vtotal==0 ? vcnt : vtotal );
        end
        if( pck_de ) hcnt <= hcnt+1;
    end
`endif

assign pck_skip   = 0;
assign {br,bg,bb} = base_rgb;
assign de         = base_lhbl & base_lvbl;

initial begin
    pck_rgb_clk = 0;
    pck_rgb     = 0;
end

/* verilator lint_off WIDTHTRUNC  */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off SELRANGE    */
function [7:0] extend8;
    input [COLORW-1:0] a;
    case( COLORW )
        3: extend8 = { a, a, a[2:1] };
        4: extend8 = { a, a         };
        5: extend8 = { a, a[4:2]    };
        6: extend8 = { a, a[5:4]    };
        7: extend8 = { a, a[6]      };
        8: extend8 = a;
    endcase
endfunction
/* verilator lint_on WIDTHTRUNC  */
/* verilator lint_on WIDTHEXPAND */
/* verilator lint_on SELRANGE    */

reg [2:0] scaler_mode;

always @(posedge clk) begin
    case( {sht_en, sht_wide, rotate} )
        4'b00_00: scaler_mode = 0;
        4'b00_01: scaler_mode = 1;
        4'b00_10: scaler_mode = 2;
        // 16 pxl clip
        4'b10_00: scaler_mode = 3;
        4'b10_01: scaler_mode = 4;
        4'b10_10: scaler_mode = 5;
        // 32 pxl clip
        4'b11_00: scaler_mode = 6;
        4'b11_01: scaler_mode = 7;
        4'b11_10: scaler_mode = 5;  // uses 16-pxl clip as no more modes are available
    endcase
end

always @(posedge clk) begin
    pxl_cnt <= pxl2_cen ? 4'd0 : pxl_cnt+4'd1;
    if( pxl_cnt == {pxl_90[3:1],1'd0}-4'd1 )
        pck_rgb_clkq <= pck_rgb_clk;
    if(pxl2_cen) begin
        pck_rgb_clk <= ~pck_rgb_clk;
        pxl_90      <= pxl_cnt;
        if( pck_rgb_clk ) begin
            hsl     <= base_hs;
            vsl     <= base_vs;
            pck_hs  <= base_hs & ~hsl;
            pck_vs  <= base_vs & ~vsl;
            pck_de  <= de;
            // configuration info is sent during ~DE
            pck_rgb <= de ? { extend8(br), extend8(bg), extend8(bb) } :
                            {8'b0, scaler_mode, 13'b0};
        end
    end
end

// Pads
wire [ 7:0] nc;
wire [10:0] nc1;

mf_ddio_bidir_12 u_ddio1(
    .oe       ( 1'b1        ),
    .datain_h ( pck_rgb[23:12] ),
    .datain_l ( pck_rgb[11: 0] ),
    .outclock ( pck_rgb_clk ),
    .padio    ( scal_vid    )
);

mf_ddio_bidir_12 u_ddio2(
    .oe       ( 1'b1        ),
    .datain_h ( {8'd0, pck_vs, pck_hs, pck_de, pck_skip} ),
    .datain_l ( {8'd0, pck_vs, pck_hs, pck_de, pck_skip} ),
    .outclock ( pck_rgb_clk ),
    .padio    ( { nc, scal_vs, scal_hs, scal_de, scal_skip  } )
);


mf_ddio_bidir_12 u_ddclk(
    .oe       (  1'b1        ),
    .datain_h ( 12'b1        ),
    .datain_l ( 12'b0        ),
    .outclock ( pck_rgb_clkq ),
    .padio    ( { nc1, scal_clk } )
);

endmodule