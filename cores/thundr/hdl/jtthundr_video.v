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
    Date: 15-3-2025 */

module jtthundr_video(
    input             rst,
    input             clk,
    input             pxl_cen, pxl2_cen, bank, dmaon, flip,
                      scrhflip, metrocrs,

    output            lvbl, lhbl, hs, vs,
    input             mmr0_cs, mmr1_cs, cpu_rnw,
    input      [ 7:0] cpu_dout,
    input      [12:0] cpu_addr,
    input      [ 7:0] backcolor,

    // Objects
    input             ommr_cs,
    output     [15:0] oram_din,
    output     [ 1:0] oram_we,

    // Tile ROM decoder PROM
    output     [12:1] vram0_addr, vram1_addr, oram_addr,
    input      [15:0] vram0_dout, vram1_dout, oram_dout,
    output     [ 4:0] dec0_addr, dec1_addr,
    input      [ 7:0] dec0_data, dec1_data,

    // ROMs
    output            scr0a_cs,   scr0b_cs,   scr1a_cs,   scr1b_cs,
    output     [16:2] scr0a_addr, scr0b_addr,
    output     [15:2] scr1a_addr, scr1b_addr,
    input      [31:0] scr0a_data, scr0b_data, scr1a_data, scr1b_data,
    input             scr0a_ok,   scr0b_ok,   scr1a_ok,   scr1b_ok,
    output            obj_cs,
    output     [19:2] obj_addr,
    input      [31:0] obj_data,
    input             obj_ok,
    // Metro Cross Text ROM
    output            txt_cs,
    output     [12:1] txt_addr,
    input      [15:0] txt_data,
    input             txt_ok,

    // Palette PROMs, used for SCR/OBJ in System 86 games
    //                used as RGB PROM in Baraduke/Metro Cross
    output     [10:0] scrpal_addr, objpal_addr,
    input      [ 7:0] scrpal_data, objpal_data,

    output     [ 8:0] rgb_addr,
    input      [ 7:0] rg_data,
    input      [ 3:0] b_data,
    output reg [ 3:0] red, green, blue,

    input      [ 4:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

wire [12:1] cus42_1_addr;
wire [10:0] scr0_pxl, scr1_pxl, pre1_pxl, obj_pxl,
            mxrgb_addr, objpala, scrpala;
wire [ 9:0] mxtxt_addr;
wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [ 7:0] mmr0, mmr1, st0, st1,  obj_mmr, obj_st;
wire [ 3:0] th_red, th_green, th_blue,
            mx_red, mx_green, mx_blue;
wire [ 2:0] obj_prio, scr0_prio, scr1_prio, pre1_prio;

reg         rst_scr1, rst_mx, dec_en;

assign scr0a_addr[16]= bank, scr0b_addr[16]=bank;
assign vram1_addr  = metrocrs ? {2'd0,mxtxt_addr} : cus42_1_addr;
assign objpal_addr = metrocrs ? mxrgb_addr : objpala;
assign scrpal_addr = metrocrs ? mxrgb_addr : scrpala;

always @(posedge clk) begin
    rst_scr1 <=  metrocrs | rst;
    rst_mx   <= ~metrocrs | rst;
    dec_en   <= ~metrocrs;
    {red,green,blue} <= metrocrs ? {mx_red,mx_green,mx_blue}:
                                   {th_red,th_green,th_blue};
end

always @(posedge clk) begin
    case(debug_bus[5:4])
        0: st_dout <= st0;
        1: st_dout <= st1;
        2: st_dout <= obj_st;
        default: st_dout <= {6'd0,bank,flip};
    endcase
end

jtframe_sh #(.W(14),.L(2)) u_sh(
    .clk    ( clk                   ),
    .clk_en ( pxl_cen               ),
    .din    ( {pre1_prio,pre1_pxl}  ),
    .drop   ( {scr1_prio,scr1_pxl}  )
);

jtshouse_vtimer u_vtimer(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .hdump      ( hdump         ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),
    .hs         ( hs            ),
    .vs         ( vs            )
);

jtthundr_ioctl_mux u_iomux(
    .bank       ( bank          ),
    .flip       ( flip          ),
    .backcolor  ( backcolor     ),
    .mmr0       ( mmr0          ),
    .mmr1       ( mmr1          ),
    .mmr2       ( obj_mmr       ),
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     )
);

jtcus42 #(.ID(0)) u_scroll0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .flip       ( flip          ),
    .scrhflip   ( scrhflip      ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .dec_en     ( dec_en        ),

    .cs         ( mmr0_cs       ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr[2:0] ),
    .cpu_dout   ( cpu_dout      ),

    .vram_addr  ( vram0_addr    ),
    .vram_dout  ( vram0_dout    ),
    .dec_addr   ( dec0_addr     ),
    .dec_data   ( dec0_data     ),

    .roma_cs    ( scr0a_cs      ),
    .roma_addr  (scr0a_addr[15:2]),
    .roma_data  ( scr0a_data    ),
    .roma_ok    ( scr0a_ok      ),

    .romb_cs    ( scr0b_cs      ),
    .romb_addr  (scr0b_addr[15:2]),
    .romb_data  ( scr0b_data    ),
    .romb_ok    ( scr0b_ok      ),

    .ioctl_addr (ioctl_addr[2:0]),
    .ioctl_din  ( mmr0          ),

    .prio       ( scr0_prio     ),
    .pxl        ( scr0_pxl      ),
    // debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st0           )
);

jtcus42 #(.ID(1),.HBASE(9'd4)) u_scroll1(
    .rst        ( rst_scr1      ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .flip       ( flip          ),
    .scrhflip   ( scrhflip      ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .dec_en     ( 1'b1          ),

    .cs         ( mmr1_cs       ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr[2:0] ),
    .cpu_dout   ( cpu_dout      ),

    .vram_addr  ( cus42_1_addr  ),
    .vram_dout  ( vram1_dout    ),
    .dec_addr   ( dec1_addr     ),
    .dec_data   ( dec1_data     ),

    .roma_cs    ( scr1a_cs      ),
    .roma_addr  ( scr1a_addr    ),
    .roma_data  ( scr1a_data    ),
    .roma_ok    ( scr1a_ok      ),

    .romb_cs    ( scr1b_cs      ),
    .romb_addr  ( scr1b_addr    ),
    .romb_data  ( scr1b_data    ),
    .romb_ok    ( scr1b_ok      ),

    .ioctl_addr (ioctl_addr[2:0]),
    .ioctl_din  ( mmr1          ),

    .prio       ( pre1_prio     ),
    .pxl        ( pre1_pxl      ),
    // debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st1           )
);

jtthundr_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .alt_offset ( scrhflip  ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),

    .dmaon      ( dmaon     ),
    // MMR
    .mmr_cs     ( ommr_cs   ),
    .cpu_addr   (cpu_addr[1:0]),
    .cpu_rnw    ( cpu_rnw   ),
    .cpu_dout   ( cpu_dout  ),

    // Look-up table
    .ram_addr   ( oram_addr ),
    .ram_dout   ( oram_dout ),
    .ram_din    ( oram_din  ),
    .ram_we     ( oram_we   ),

    .rom_cs     ( obj_cs    ),
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),   // upper byte not used
    .rom_ok     ( obj_ok    ),

    .pxl        ( obj_pxl   ),
    .pxl_prio   ( obj_prio  ),

    .ioctl_addr (ioctl_addr[1:0]),
    .ioctl_din  ( obj_mmr   ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( obj_st    )
);

jtthundr_colmix u_colmix(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .scrpal_addr( scrpala   ),
    .scrpal_data(scrpal_data),
    .objpal_addr( objpala   ),
    .objpal_data(objpal_data),

    .scr0_pxl   ( scr0_pxl  ),
    .scr1_pxl   ( scr1_pxl  ),
    .obj_pxl    ( obj_pxl   ),
    .obj_prio   ( obj_prio  ),
    .scr0_prio  ( scr0_prio ),
    .scr1_prio  ( scr1_prio ),
    .backcolor  ( backcolor ),

    .rgb_addr   ( rgb_addr  ),
    .rg_data    ( rg_data   ),
    .b_data     ( b_data    ),

    .red        ( th_red    ),
    .green      ( th_green  ),
    .blue       ( th_blue   ),
    .gfx_en     ( gfx_en    )
);

// Metro-Cross
wire [8:0] txt_pxl;

jtmetrox_text u_metrox_text(
    .rst        ( rst_mx        ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),
    .flip       ( flip          ),

    .vram_addr  ( mxtxt_addr    ),
    .vram_dout  ( vram1_dout    ),

    .rom_cs     ( txt_cs        ),
    .rom_addr   ( txt_addr      ),
    .rom_data   ( txt_data      ),
    .rom_ok     ( txt_ok        ),

    .pxl        ( txt_pxl       )
);

jtmetrox_colmix u_metrox_colmix(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),

    .scr0_pxl   ( scr0_pxl      ),
    .txt_pxl    ( txt_pxl       ),
    .obj_pxl    ( obj_pxl       ),

    .rgb_addr   ( mxrgb_addr    ),
    .bg_data    ( scrpal_data   ),
    .r_data     ( objpal_data   ),

    .red        ( mx_red        ),
    .green      ( mx_green      ),
    .blue       ( mx_blue       ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     )
);

endmodule    
