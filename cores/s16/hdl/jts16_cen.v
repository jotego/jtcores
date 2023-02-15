/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 10-3-2021 */

module jts16_cen(
    input              clk,       // main CPU & video (50.3496 MHz)
    output             pxl2_cen,  // pixel clock enable (2x)
    output             pxl_cen,   // pixel clock enable

    input              clk24,     // sound subsystem (25.1748 MHz)
    output             mcu_cen,   // 8 MHz
    output             snd_cen,   // 5 MHz
    output             fm_cen,    // 4 MHz
    output             fm2_cen,   // 2 MHz
    output             pcm_cen,
    output             pcm_cenb
);

parameter CLK96=0;

wire nc, ncb, nc2, ncb2, nc3, nc4;

jtframe_frac_cen #(2) u_pxlcen(
    .clk    ( clk       ),
    .n      ( 10'd1     ),
    .m      ( CLK96 ? 10'd8 : 10'd4  ),
    .cen    ( {pxl_cen, pxl2_cen }   ),
    .cenb   (           )
);


// Sound subsystem uses clk24 = 25.1748 MHz

jtframe_frac_cen u_mcucen(   // 8MHz
    .clk    ( clk24     ),
    .n      ( 10'd143   ),
    .m      ( 10'd450   ),
    .cen    ( { nc4, mcu_cen } ),
    .cenb   (           )
);

jtframe_frac_cen u_fmcen(   // 4MHz
    .clk    ( clk24     ),
    .n      ( 10'd143   ),
    .m      ( 10'd900   ),
    .cen    ( { fm2_cen, fm_cen } ),
    .cenb   (           )
);

jtframe_frac_cen #(.WC(14)) u_sndcen( // 5 MHz
    .clk    ( clk24     ),
    .n      ( 14'd1373  ),
    .m      ( 14'd6913  ),
    .cen    ( { nc3, snd_cen } ),
    .cenb   (           )
);

`ifndef S16B
    jtframe_frac_cen #(.WC(14)) u_pcmcen(  // 6 MHz
        .clk    ( clk24     ),
        .n      ( 14'd1619  ),
        .m      ( 14'd6793  ),
        .cen    ( { nc2, pcm_cen  } ),
        .cenb   ( { ncb2, pcm_cenb} )
    );
`else
    // 640 kHz
    jtframe_frac_cen  #(.WC(16)) u_pcmcen(
        .clk    ( clk24     ),
        .n      ( 16'd873   ),
        .m      ( 16'd34340 ),
        .cen    ( { nc2, pcm_cen  } ),
        .cenb   ( { ncb2, pcm_cenb} )
    );
`endif

endmodule