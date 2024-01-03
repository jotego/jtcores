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

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 22-3-2022 */

module jtngp_video(
    input               rst,
    input               clk,
    input               clk24,
    input               cen6,
    input               pxl_cen,
    input               pxl2_cen,

    input        [31:0] status,

    // CPU
    input        [13:1] cpu_addr,
    input        [15:0] cpu_dout,
    output reg   [15:0] cpu_din,
    input        [ 1:0] we,
    input               gfx_cs,

    output              hirq,
    output              virq,

    output              HS,
    output              VS,
    output              LHBL,
    output              LVBL,
    output       [ 3:0] red,
    output       [ 3:0] green,
    output       [ 3:0] blue,
    input        [ 3:0] gfx_en,
    // Debug
    input        [ 7:0] debug_bus,
    output reg   [ 7:0] st_dout
);

wire [ 9:0] hcnt;
wire [ 7:0] vdump;
wire [ 7:0] vrender;
wire [ 8:0] hdump;
wire [ 1:0] dsn;

// Memory map
reg   ram_cs, obj_cs,  obj2_cs, pal_cs, palrgb_cs,
      scr1_cs,  scr2_cs, regs_cs, rst_cs;
reg   rstv;
// video access
wire [15:0] scr1_data, scr2_data, obj_data;
wire [12:1] scr1_addr, scr2_addr, obj_addr;
wire        obj_rd, obj_ok;

// video configuration
wire [ 7:0] hoffset, voffset,
            scr1_hpos, scr1_vpos,
            scr2_hpos, scr2_vpos,
            view_width, view_height,
            view_startx,view_starty;
wire        scr_order, hirq_en, virq_en, lcd_neg, oow;

wire [ 4:0] obj_pxl;
wire [ 2:0] scr1_pxl, scr2_pxl, oowc;

wire [15:0] regs_dout, fix_dout,
            obj_dout,  pal_dout,
            scr1_dout, scr2_dout;

function in_range( input [13:0] min, max );
    in_range = cpu_addr>=min[13:1] && cpu_addr<max[13:1];
endfunction

assign dsn = ~we;

always @(posedge clk) begin
    rstv <= rst || (rst_cs && we[0] && cpu_dout[7:0]==8'h52);
end

always @(posedge clk) begin
    case( debug_bus[3:0] )
        1: st_dout <= scr1_hpos;
        2: st_dout <= scr1_vpos;
        3: st_dout <= scr2_hpos;
        4: st_dout <= scr2_vpos;
        5: st_dout <= view_width;  // WSI.H
        6: st_dout <= view_height; // WSI.V
        7: st_dout <= view_startx; // WBA.H
        8: st_dout <= view_starty; // WBA.V
        9: st_dout <= hoffset;
       10: st_dout <= voffset;
        default: st_dout <= { 1'b0, oowc, scr_order, lcd_neg, hirq_en, virq_en };
    endcase
end

always @* begin
    regs_cs   = gfx_cs && in_range(14'h0000,14'h00C0);
    pal_cs    = gfx_cs && in_range(14'h0100,14'h011A); // monochrome palette
    palrgb_cs = gfx_cs && in_range(14'h0200,14'h0400); // color palette
    rst_cs    = gfx_cs && cpu_addr[13:1]==13'h7e0>>1;
    obj_cs    = gfx_cs && in_range(14'h0800,14'h0900); // OBJ, NGP mode
    obj2_cs   = gfx_cs && in_range(14'h0C00,14'h0C40); // OBJ, NPGC addition
    scr1_cs   = gfx_cs && in_range(14'h1000,14'h1800); // Scroll VRAM, 1st half
    scr2_cs   = gfx_cs && in_range(14'h1800,14'h2000); //              2nd half
    ram_cs    = gfx_cs && cpu_addr[13:1] >= 13'h1000;  // 2000-4000 character RAM
end

always @* begin // do not register here
    cpu_din =  pal_cs   ? pal_dout  :
               scr1_cs  ? scr1_dout :
               scr2_cs  ? scr2_dout :
               regs_cs  ? regs_dout :
               ram_cs   ? fix_dout : obj_dout;
end
/* verilator tracing_on */
jtngp_vtimer u_vtimer(
    .clk        ( clk       ),
    .cen6       ( cen6      ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .hint_en    ( hirq_en   ),
    .vint_en    ( virq_en   ),
    // outputs:
    .hcnt       ( hcnt      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        ),
    // Window
    .view_width ( view_width  ),
    .view_height( view_height ), // it influences when interrupts occur too
    .view_startx( view_startx ),
    .view_starty( view_starty ),
    .oow        ( oow       ),
    // interrupts
    .hirq       ( hirq      ),
    .virq       ( virq      )
);
/* verilator tracing_on */
jtngp_mmr u_mmr(
    .rst        ( rstv        ),
    .clk        ( clk         ),
    .hcnt       ( hcnt        ),
    .vdump      ( vdump       ),
    .LVBL       ( LVBL        ),
    // CPU access
    .cpu_addr   (cpu_addr[12:1]),
    .cpu_din    ( regs_dout   ),
    .cpu_dout   ( cpu_dout    ),
    .dsn        ( dsn         ),
    .regs_cs    ( regs_cs     ),
    // video access
    .hoffset    ( hoffset     ),
    .voffset    ( voffset     ),
    .scr1_hpos  ( scr1_hpos   ),
    .scr1_vpos  ( scr1_vpos   ),
    .scr2_hpos  ( scr2_hpos   ),
    .scr2_vpos  ( scr2_vpos   ),
    .scr_order  ( scr_order   ),
    // Window
    .view_width ( view_width  ),
    .view_height( view_height ), // it influences when interrupts occur too
    .view_startx( view_startx ),
    .view_starty( view_starty ),
    .oowc       ( oowc        ),
    .hirq_en    ( hirq_en     ),
    .virq_en    ( virq_en     ),
    .lcd_neg    ( lcd_neg     )
);
/* verilator tracing_off */
jtngp_chram u_chram(
    .rst        ( rstv      ),
    .clk        ( clk       ),
    // CPU access
    .cpu_addr   (cpu_addr[12:1]),
    .cpu_din    ( fix_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .dsn        ( dsn       ),
    .ram_cs     ( ram_cs    ),
    // video access
    .obj_rd     ( obj_rd    ),
    .obj_ok     ( obj_ok    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data )
);
/* verilator tracing_on */
jtngp_scr #(
    .SIMFILE_LO("scr1_lo.bin"),
    .SIMFILE_HI("scr1_hi.bin")
) u_scr1 (
    .rst        ( rstv      ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .hpos       ( scr1_hpos ),
    .vpos       ( scr1_vpos ),
    // CPU access
    .cpu_addr   ( cpu_addr[10:1] ),
    .cpu_din    ( scr1_dout ),
    .cpu_dout   ( cpu_dout  ),
    .dsn        ( dsn       ),
    .scr_cs     ( scr1_cs   ),
    // Character RAM
    .chram_addr ( scr1_addr ),
    .chram_data ( scr1_data ),
    // video output
    .en         ( gfx_en[0] ),
    .pxl        ( scr1_pxl  )
);

jtngp_scr #(
    .SIMFILE_LO("scr2_lo.bin"),
    .SIMFILE_HI("scr2_hi.bin")
) u_scr2 (
    .rst        ( rstv      ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .hpos       ( scr2_hpos ),
    .vpos       ( scr2_vpos ),
    // CPU access
    .cpu_addr   ( cpu_addr[10:1] ),
    .cpu_din    ( scr2_dout ),
    .cpu_dout   ( cpu_dout  ),
    .dsn        ( dsn       ),
    .scr_cs     ( scr2_cs   ),
    // Character RAM
    .chram_addr ( scr2_addr ),
    .chram_data ( scr2_data ),
    // video output
    .en         ( gfx_en[1] ),
    .pxl        ( scr2_pxl  )
);
/* verilator tracing_on */
jtngp_obj u_obj(
    .rst        ( rstv      ),
    .clk        ( clk       ),

    .HS         ( HS        ),
    .pxl_cen    ( pxl_cen   ),
    .hdump      ( hdump     ),
    .vrender    (vrender[7:0]),
    // configuration
    .hoffset    ( hoffset   ),
    .voffset    ( voffset   ),
    // CPU access
    .cpu_addr   ( cpu_addr[7:1] ),
    .cpu_din    ( obj_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .dsn        ( dsn       ),
    .obj_cs     ( obj_cs    ),
    .obj2_cs    ( obj2_cs   ),
    // Character RAM
    .chram_addr ( obj_addr  ),
    .chram_data ( obj_data  ),
    .chram_rd   ( obj_rd    ),
    .chram_ok   ( obj_ok    ),
    // video output
    .en         ( gfx_en[3] ),
    .pxl        ( obj_pxl   )
);
/* verilator tracing_on */
jtngp_colmix u_colmix(
    .rst        ( rstv      ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .lcd_neg    ( lcd_neg   ),
    .scr_order  ( scr_order ),

    // Window
    .oow        ( oow       ),
    .oowc       ( oowc      ),

    // CPU access
    .cpu_addr   ( cpu_addr[8:1] ),
    .cpu_din    ( pal_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .we         ( we        ),
    .pal_cs     ( pal_cs    ),
    .palrgb_cs  ( palrgb_cs ),

    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),

    .scr1_pxl   ( scr1_pxl  ),
    .scr2_pxl   ( scr2_pxl  ),
    .obj_pxl    ( obj_pxl   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .debug_bus  ( debug_bus )
);

endmodule