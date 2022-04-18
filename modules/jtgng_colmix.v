
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
    Date: 27-10-2017 */

// This module introduces 1-pixel delay
// clock operates at 4*cen6 because colour data requires
// two memory reads per pixel
// It could be done at 2*cen6, but this solutions is neat
// and 24MHz is not a tough requirement for modern FPGAs


module jtgng_colmix(
    input            rst,
    input            clk,
    input            cen6 /* synthesis direct_enable = 1 */,

    // pixel input from generator modules
    input [5:0]      char_pxl,        // character color code
    input [6:0]      scr_pxl,
    input [5:0]      obj_pxl,
    input            LVBL,
    input            LHBL,
    output  reg      LHBL_dly,
    output  reg      LVBL_dly,
    // Palette PROMs and object priority
    input [7:0]      prog_addr,
    input            prom_red_we,
    input            prom_green_we,
    input            prom_blue_we,
    input [3:0]      prom_din,
    // Avatars
    input [3:0]      avatar_idx,
    input            pause,
    // CPU inteface
    input [7:0]      AB,
    input            blue_cs,
    input            redgreen_cs,
    input [7:0]      DB,

    output reg [3:0] red,
    output reg [3:0] green,
    output reg [3:0] blue,
    // Debug
    input      [3:0] gfx_en
);

parameter SCRWIN        = 1,
          BLUELOW       = 0, // used high or low nibble for blue palette
          PALETTE_PROM  = 0,
          GNGPAL        = 0, // during non blanking, the CPU does not control the pal. address
          PALETTE_RED   = "../../../rom/commando/vtb1.1d",
          PALETTE_GREEN = "../../../rom/commando/vtb2.2d",
          PALETTE_BLUE  = "../../../rom/commando/vtb3.3d";
parameter [1:0] OBJ_PAL = 2'b01; // 01 for GnG, 10 for Commando
    // These two bits mark the region of the palette RAM/PROM where
    // palettes for objects are stored

reg [7:0] pixel_mux;

wire enable_char = gfx_en[0];
wire enable_scr  = gfx_en[1];
wire obj_blank   = &obj_pxl[3:0];
wire enable_obj  = gfx_en[3];

// SCRWIN means that the MSB of scr_pxl signals that the background
// tile should go on top of the sprites, changing the priority order.
// When SCRWIN=0 then the MSB of scr_pxl has no special meaning.
wire scrwin = SCRWIN ? scr_pxl[6] : 1'b0;
wire [7:0] scr_mux = SCRWIN ? {2'b00, scr_pxl[5:0] } : {1'b0, scr_pxl};
reg  [2:0] obj_sel; // signals whether an object pixel is selected

always @(posedge clk) if(cen6) begin
    obj_sel[2] <= obj_sel[1];
    obj_sel[1] <= obj_sel[0];
    obj_sel[0] <= 1'b0;
    if( char_pxl[1:0]==2'b11 || !enable_char ) begin
        // Object or scroll
        if( obj_blank || !enable_obj || (scrwin&&scr_pxl[2:0]!=3'd0 &&scr_pxl[2:0]!=3'd6) )
            pixel_mux <= enable_scr ? scr_mux : 8'hff; // scroll wins
        else begin
            obj_sel[0] <= 1'b1;
            pixel_mux <= {OBJ_PAL, obj_pxl }; // object wins
        end
    end
    else begin // characters
        pixel_mux <= { 2'b11, char_pxl };
    end
end

wire [1:0] pre_BL;

jtframe_sh #(.width(2),.stages(5)) u_hb_dly(
    .clk    ( clk      ),
    .clk_en ( cen6     ),
    .din    ( {LHBL, LVBL}     ),
    .drop   ( pre_BL   )
);

always @(posedge clk) if(cen6) {LHBL_dly, LVBL_dly} <= pre_BL;

wire [3:0] pal_red, pal_green, pal_blue;

////////////////////// Palette can be in RAM or in PROMs:
generate

if( PALETTE_PROM==1) begin
    // palette is in PROM

    jtframe_prom #(.aw(8),.dw(4),.simfile(PALETTE_RED)) u_red(
        .clk    ( clk          ),
        .cen    ( 1'b1         ),
        .data   ( prom_din     ),
        .rd_addr( pixel_mux    ),
        .wr_addr( prog_addr    ),
        .we     ( prom_red_we  ),
        .q      ( pal_red      )
    );

    jtframe_prom #(.aw(8),.dw(4),.simfile(PALETTE_GREEN)) u_green(
        .clk    ( clk          ),
        .cen    ( 1'b1         ),
        .data   ( prom_din     ),
        .rd_addr( pixel_mux    ),
        .wr_addr( prog_addr    ),
        .we     ( prom_green_we),
        .q      ( pal_green    )
    );

    jtframe_prom #(.aw(8),.dw(4),.simfile(PALETTE_BLUE)) u_blue(
        .clk    ( clk          ),
        .cen    ( 1'b1         ),
        .data   ( prom_din     ),
        .rd_addr( pixel_mux    ),
        .wr_addr( prog_addr    ),
        .we     ( prom_blue_we ),
        .q      ( pal_blue     )
    );

end else begin
    // Palette is in RAM
    reg  we_rg, we_b;
    reg  [7:0] eff_AB;
    wire [7:0] pre_rg;
    wire [3:0] pre_b;

    assign { pal_red, pal_green } = (GNGPAL==1 && we_rg ) ? DB : pre_rg;
    assign pal_blue               = (GNGPAL==1 && we_b  ) ? DB : pre_b;

    always @* begin
        if( GNGPAL==1 ) begin // GnG circuit:
            we_rg  = redgreen_cs;
            we_b   = blue_cs;
            eff_AB = LVBL ? (LHBL ? pixel_mux : 8'd0) : AB;
        end else begin // block the colour RAM if not in blanking
            we_rg  = !LVBL & redgreen_cs;
            we_b   = !LVBL & blue_cs;
            eff_AB = AB;
        end
    end

    jtgng_dual_ram #(.aw(8),.simfile("rg_ram.hex")) u_redgreen(
        .clk        ( clk         ),
        .clk_en     ( 1'b1        ), // clock enable only applies to write operation
        .data       ( DB          ),
        .rd_addr    ( pixel_mux   ),
        .wr_addr    ( eff_AB      ),
        .we         ( we_rg       ),
        .q          ( pre_rg      )
    );

    jtgng_dual_ram #(.aw(8),.dw(4),.simfile("b_ram.hex")) u_blue(
        .clk        ( clk         ),
        .clk_en     ( 1'b1        ), // clock enable only applies to write operation
        .data       ( BLUELOW ? DB[3:0] : DB[7:4] ),
        .rd_addr    ( pixel_mux   ),
        .wr_addr    ( eff_AB      ),
        .we         ( we_b        ),
        .q          ( pre_b       )
    );
end
endgenerate

`ifdef AVATARS
`ifdef MISTER
`define AVATAR_PAL
`endif
`endif

`ifdef AVATAR_PAL
wire [11:0] avatar_pal;
// Objects have their own palette during pause
wire [ 7:0] avatar_addr = { avatar_idx, obj_pxl[0], obj_pxl[1], obj_pxl[2], obj_pxl[3] };

jtframe_ram #(.dw(12),.aw(8), .synfile("avatar_pal.hex"),.cen_rd(1))u_avatars(
    .clk    ( clk           ),
    .cen    ( pause         ),  // tiny power saving when not in pause
    .data   ( 12'd0         ),
    .addr   ( avatar_addr   ),
    .we     ( 1'b0          ),
    .q      ( avatar_pal    )
);
// Select the avatar palette output if we are on avatar mode
wire [11:0] avatar_mux = (pause&&obj_sel[1]) ? avatar_pal : { pal_red, pal_green, pal_blue };
`else 
wire [11:0] avatar_mux = {pal_red, pal_green, pal_blue};
`endif


always @(posedge clk) if (cen6)
    {red, green, blue } <= pre_BL==2'b11 ? avatar_mux : 12'd0;

endmodule // jtgng_colmix