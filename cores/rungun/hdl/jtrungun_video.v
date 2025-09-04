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
    Date: 4-7-2025 */

module jtrungun_video(
    input              rst, clk,
    input              pxl_cen, pxl2_cen,
                       ghflip, gvflip, pri,
    input              lrsw,
    output             disp,
    // Base Video
    output             lhbl,
    output             lvbl,
    output             hs,
    output             vs,
    output      [ 8:0] hdump,
    output      [ 7:0] vdump,
    // CPU interface
    input              ccu_cs,   // timer
    input              psac_cs,
    input       [12:1] addr,
    input              rnw,
    input       [15:0] cpu_dout,
    input       [ 1:0] cpu_dsn,
    output      [ 7:0] vtimer_mmr,

    // line-based frame buffer
    output     [ 8:0]  ln_addr,
    output     [15:0]  ln_data,
    output             ln_done,
    input              ln_hs, ln_vs, ln_lvbl,
    input      [15:0]  ln_pxl,
    input      [ 7:0]  ln_v,
    output             ln_we,

    // fixed layer
    output      [12:1] vram_addr,
    input       [15:0] vram_dout,
    // Objects
    input              objrg_cs, objcha_n, objrm_cs,
    output             dma_bsy,
    output      [15:0] objrm_dout,
    // PSAC Lines
    output      [10:1] line_addr,
    input       [15:0] line_dout,
    // Tile map
    output      [14:0] psrm_addr,
    input       [23:0] psrm_dout,
    // PSAC (scroll)
    output      [20:0] scr_addr,
    input       [ 7:0] scr_data,
    output             scr_cs,
    input              scr_ok,
    // palette
    output      [11:1] pal_addr,
    input       [15:0] pal_dout,
    // ROMs
    output      [22:2] obj_addr,
    input       [31:0] obj_data,
    output             obj_cs,
    input              obj_ok,

    output      [16:2] fix_addr,
    input       [31:0] fix_data,
    output             fix_cs,
    input              fix_ok,
    // final pixel
    output      [ 7:0] red,
    output      [ 7:0] green,
    output      [ 7:0] blue,
    // Debug
    input       [ 3:0] gfx_en,
    input       [ 7:0] debug_bus,
    // IOCTL dump
    input     [14:0] ioctl_addr,
    output     [7:0] ioctl_din,
    input            ioctl_ram
);

wire [31:0] fix_sort;
wire [11:0] fix_code;
wire [ 8:0] virt_hdumpf, obj_pxl, virt_hdump;
wire [ 7:0] virt_vdumpf, psc_pxl, virt_vdump;
wire [ 7:0] fix_raw, fix_pxl, dump_obj, obj_mmr, ccu_mmr, psac_mmr;
wire [ 5:0] hbs_len, hsy_len, hsa_len;
wire [ 4:0] obj_prio;
wire [ 3:0] fix_pal, ommra;
wire [ 1:0] oram_we, shadow;
wire        cpu_we, hld, vld, obj_done;
reg  [14:0] ioctl_adj;
wire        iosel_obj, iosel_ccu, iosel_psc, virt_hs, virt_lhbl, virt_cen;

assign cpu_we    = ~rnw;
assign oram_we   = ~cpu_dsn & {2{~rnw}};
assign ommra     = {addr[3:1],cpu_dsn[1]};

assign vram_addr[12] = lrsw;
assign psrm_addr[14] = lrsw;
assign fix_pal  = vram_dout[15:12];
assign fix_code = vram_dout[11: 0];

localparam [19:0] IOCTL_RD_SIZE=`JTFRAME_IOCTL_RD;
localparam [14:0] IOADDR0 = IOCTL_RD_SIZE[14:0]-15'd8192-15'd16*4;

always @(posedge clk) begin
    ioctl_adj <= ioctl_addr - IOADDR0;
end

assign iosel_obj=~ioctl_adj[13];
assign iosel_ccu= ioctl_adj[13] && ioctl_adj[5:4]==1,
       iosel_psc= ioctl_adj[13] && ioctl_adj[5:4]>=2;

assign ioctl_din= iosel_obj ? dump_obj :
                  iosel_ccu ? ccu_mmr  :
                  iosel_psc ? psac_mmr : obj_mmr; // obj is dumped before ccu and psac

jtrungun_vtimer u_vtimer(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vld        ( vld           ),
    .hld        ( hld           ),

    .hflip      ( ghflip        ),
    .vflip      ( gvflip        ),
    .hdump      ( hdump         ),
    .hdumpf     (               ),
    .vdump      ( vdump         ),
    .vdumpf     (               )
);

// video timer
jtk053252 u_k053252(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),


    .cs         ( ccu_cs        ),
    .addr       ( addr[4:1]     ),
    .rnw        ( rnw           ),
    .din        ( cpu_dout[7:0] ),
    .dout       ( vtimer_mmr    ),

    .hs         ( hs            ),
    .vs         ( vs            ),
    .lhbl       ( lhbl          ),
    .lhbs       (               ),
    .lvbl       ( lvbl          ),
    .hld        ( hld           ),
    .vld        ( vld           ),
    // unused
    .vldi       ( 1'b1          ),
    .hldi       ( 1'b1          ),
    .sel        ( 3'd0          ),
    .int1       (               ),
    .int2       (               ),
    // IOCTL dump
    .ioctl_addr ( ioctl_adj[3:0]),
    .ioctl_din  ( ccu_mmr       )
);

jtframe_video_counter u_counter(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .lhbl       ( lhbl          ),
    .lvbl       ( 1'b0          ),
    .hs         ( hs            ),
    .vs         ( 1'b0          ),
    .flip       ( 1'b0          ),

    .v          (               ),
    .h          (               ),
    .hbs_len    ( hbs_len       ),
    .hsy_len    ( hsy_len       ),
    .hsa_len    ( hsa_len       ),
    .vbs_len    (               ),
    .vsy_len    (               ),
    .vsa_len    (               ),
    .rdy        (               )
);

jtrungun_lfbuf_ctrl u_lfbuf_ctrl(
    .clk        ( clk           ),
    .obj_done   ( obj_done      ),

    .ln_addr    ( ln_addr       ),
    .ln_done    ( ln_done       ),
    .ln_hs      ( ln_hs         ),
    .ln_v       ( ln_v          ),
    .ln_vs      ( ln_vs         ),
    .ln_lvbl    ( ln_lvbl       ),
    .ln_we      ( ln_we         ),

    .vflip      ( gvflip        ),
    .hflip      ( ghflip        ),

    .scr_cs     ( scr_cs        ),
    .obj_cs     ( obj_cs        ),
    .fix_cs     ( fix_cs        ),

    .scr_ok     ( scr_ok        ),
    .obj_ok     ( obj_ok        ),
    .fix_ok     ( fix_ok        ),
    // virtual screen
    .hbs_len    ( hbs_len       ),
    .hsy_len    ( hsy_len       ),
    .hsa_len    ( hsa_len       ),

    .cen        ( virt_cen      ),
    .hs         ( virt_hs       ),
    .lhbl       ( virt_lhbl     ),
    .hdump      ( virt_hdump    ),
    .vdump      ( virt_vdump    ),
    .hdumpf     ( virt_hdumpf   ),
    .vdumpf     ( virt_vdumpf   )
);

assign disp = 0;
// jtframe_toggle #(.W(1)) u_disp(rst,clk,vs,disp);
jtframe_8x8x4_packed_msb u_packed(fix_data,fix_sort);

jtframe_tilemap #(
    .VA(11),
    .MAP_HW(9),
    .VDUMPW(8),
    .FLIP_HDUMP(0),
    .FLIP_VDUMP(0)
)u_fix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( virt_cen      ),

    .vdump      ( virt_vdumpf   ),
    .hdump      ( virt_hdumpf   ),
    .blankn     ( ln_lvbl       ),
    .flip       ( 1'b0          ),    // Screen flip

    .vram_addr  (vram_addr[11:1]),

    .code       ( fix_code      ),
    .pal        ( fix_pal       ),
    .hflip      ( 1'b0          ),
    .vflip      ( 1'b0          ),

    .rom_addr   ( fix_addr      ),
    .rom_data   ( fix_sort      ),    // expects data packed as plane3,plane2,plane1,plane0, each of 8 bits
    .rom_cs     ( fix_cs        ),
    .rom_ok     ( 1'b1          ),

    .pxl        ( fix_raw       )
);

jtframe_sh #(.W(8),.L(2)) u_fixsh(
    .clk    ( clk       ),
    .clk_en ( virt_cen  ),
    .din    ( fix_raw   ),
    .drop   ( fix_pxl   )
);

jtrungun_psac u_psac(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( virt_cen  ),

    .hs         (~virt_lhbl ),
    .vs         ( ln_vs     ),
    .dtackn     ( 1'b0      ),

    .cs         ( psac_cs   ), // cs always writes
    .din        ( cpu_dout  ),
    .addr       ( addr[4:1] ),
    .dsn        ( cpu_dsn   ),
    .dma_n      (           ),

    .vram_addr  ( psrm_addr[13:0] ),
    .vram_dout  ( psrm_dout ),

    .line_addr  ( line_addr ),
    .line_dout  ( line_dout ),

    // Tiles
    .rom_addr   ( scr_addr  ),
    .rom_data   ( scr_data  ),
    .rom_cs     ( scr_cs    ),
    .rom_ok     ( 1'b1      ),
    .pxl        ( psc_pxl   ),
    // IOCTL dump
    .ioctl_addr (ioctl_addr[4:0]),
    .ioctl_din  ( psac_mmr  )
);

localparam [9:0] OVOFFSET = 10'h111;

jtsimson_obj #(.PACKED(0),.SHADOW(1),.K55673(1),.HOFFSET(10'd30)) u_obj(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( virt_cen  ),
    .pxl2_cen   ( pxl2_cen  ),  // for DMA only
    .simson     ( 1'b0      ),
    .ln_done    ( obj_done  ),

    .voffset    ( OVOFFSET  ),
    // Base Video (inputs)
    .hs         ( virt_hs   ),
    .lvbl       (      vs   ),
    .hdump      ( virt_hdump),
    .vdump      ({1'b1,virt_vdump} ),
    // CPU interface
    .ram_cs     ( objrm_cs  ),
    .ram_addr   ( addr      ),
    .ram_din    ( cpu_dout  ),
    .ram_we     ( oram_we   ),
    .cpu_din    ( objrm_dout),

    .reg_cs     ( objrg_cs  ),
    .mmr_addr   ( ommra     ),
    .mmr_din    ( cpu_dout  ),
    .mmr_we     ( cpu_we    ), // active on ~dsn[1] but ignores cpu_dout[15:8]
    .mmr_dsn    ( cpu_dsn   ),

    .dma_bsy    ( dma_bsy   ),
    // ROM
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),
    .rom_ok     ( obj_ok    ),
    .rom_cs     ( obj_cs    ),
    .objcha_n   ( objcha_n  ),
    // pixel output
    .pxl        ( obj_pxl   ),
    .shd        ( shadow    ),
    .prio       ( obj_prio  ),
    // Debug
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_addr ( ioctl_adj[13:0] ),
    .dump_ram   ( dump_obj  ),
    .dump_reg   ( obj_mmr   ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

jtrungun_colmix u_colmix(
    .lrsw       ( lrsw          ),
    .pri        ( pri           ),
    // Final pixels
    .fix_pxl    ( fix_pxl       ),
    .obj_pxl    ( obj_pxl       ),
    .psc_pxl    ( psc_pxl       ),
    .shadow     ( shadow        ),

    .pxl        ( ln_data       ),
    .debug_bus  ( debug_bus     )
);

jtrungun_dim u_dim(
    .rst        ( rst           ),
    .clk        ( clk           ),
    // Base Video
    .pxl_cen    ( pxl_cen       ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),

    .pal_addr   ( pal_addr      ),
    .pal_dout   ( pal_dout      ),
    .pxl        ( ln_pxl        ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
