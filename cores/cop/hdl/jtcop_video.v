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
    Date: 25-9-2021 */

module jtcop_video(
    input              rst,
    input              clk,
    input              clk_cpu,
    output             pxl2_cen,  // pixel clock enable (2x)
    output             pxl_cen,   // pixel clock enable
    input       [ 1:0] game_id,

    input              ioctl_ram,
    input      [10:0]  ioctl_addr,
    output     [ 7:0]  pal_dmp,
    output     [ 7:0]  obj_dmp,
    // CPU interface
    input      [12:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  cpu_dsn,
    input              cpu_rnw,

    // MCU interface
    input      [ 9:0]  mcu_addr,
    input      [ 7:0]  mcu_dout,
    output     [ 7:0]  mcu_din,
    input              mcu_rnw,
    input              mcu_mode,
    input      [ 1:0]  mcu_dsn,

    input              fmode_cs, // BA0
    input              bmode_cs, // BA1
    input              cmode_cs, // BA2

    output     [15:0]  ba0_dout,
    output     [15:0]  ba1_dout,
    output     [15:0]  ba2_dout,

    // Palette
    input      [ 1:0]  pal_cs,
    input      [ 7:0]  prisel,
    output     [15:0]  pal_dout,

    // Objects
    input              objram_cs,
    input              obj_copy,
    input              mixpsel,
    output     [15:0]  obj_dout,

    // priority PROM
    input      [9:0]   prog_addr,
    input      [3:0]   prom_din,
    input              prio_we,

    // Scroll 0 - Foreground
    output             b0ram_cs,
    output      [13:1] b0ram_addr,
    input       [15:0] b0ram_data,
    input              b0ram_ok,

    output             b0rom_cs,
    output      [18:2] b0rom_addr,
    input       [31:0] b0rom_data,
    input              b0rom_ok,

    // Scroll 1 - Background
    output             b1ram_cs,
    output      [13:1] b1ram_addr,
    input       [15:0] b1ram_data,
    input              b1ram_ok,

    output             b1rom_cs,
    output      [18:2] b1rom_addr,
    input       [31:0] b1rom_data,
    input              b1rom_ok,

    // Scroll 2 - Characters
    output             b2ram_cs,
    output      [13:1] b2ram_addr,
    input       [15:0] b2ram_data,
    input              b2ram_ok,

    output             b2rom_cs,
    output      [18:2] b2rom_addr,
    input       [31:0] b2rom_data,
    input              b2rom_ok,

    // Objects
    output             orom_cs,
    output     [18:2]  orom_addr,
    input      [31:0]  orom_data,
    input              orom_ok,

    // Video signal
    output             HS,
    output             VS,
    output             LHBL_dly,
    output             LVBL_dly,
    output             flip,

    output     [ 7:0]  red,
    output     [ 7:0]  green,
    output     [ 7:0]  blue,

    // Debug
    input      [ 3:0]  gfx_en,
    input      [ 7:0]  debug_bus,
    // Status
    input      [ 7:0]  st_addr,
    output reg [ 7:0]  st_dout

);

localparam [ 1:0] HIPPODROME  = 2'd1;

wire          LVBL, LHBL;
wire   [8:0]  vdump, vrender, hdump;
wire   [7:0]  ba0_pxl, ba1_pxl, ba2_pxl, obj_pxl;
wire          vload, hinit;
reg           gmode_cs, gsft_cs, gmap_cs;
wire   [7:0]  st_dout0, st_dout1, st_dout2;

// Do not change the order, it would
// affect how data is dumped to the SD card
always @(posedge clk) begin
    case( st_addr[5:4] )
        0: st_dout <= st_dout0;
        1: st_dout <= st_dout1;
        2: st_dout <= st_dout2;
        3: st_dout <= prisel;
    endcase
end

jtcop_bac06 #(.MASTER(1)) u_ba0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),

    .mode_cs    ( fmode_cs      ),
    .flip       ( flip          ),

    // CPU interface
    .cpu_dout   ( cpu_dout      ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_din    ( ba0_dout      ),

    // Timer signals
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .vload      ( vload         ),
    .hinit      ( hinit         ),

    // VRAM
    .ram_cs     ( b0ram_cs      ),
    .ram_addr   ( b0ram_addr    ),
    .ram_data   ( b0ram_data    ),
    .ram_ok     ( b0ram_ok      ),

    // ROMs
    .rom_cs     ( b0rom_cs      ),
    .rom_addr   ( b0rom_addr    ),
    .rom_data   ( b0rom_data    ),
    .rom_ok     ( b0rom_ok      ),

    .pxl        ( ba0_pxl       ),
    .st_addr    ( st_addr       ),
    .st_dout    ( st_dout0      )
);

`ifndef NOBA1
jtcop_bac06 #(.SIMFILE("ba1.bin")) u_ba1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),

    .mode_cs    ( bmode_cs      ),
    .flip       ( flip          ),

    // CPU interface
    .cpu_dout   ( cpu_dout      ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_din    ( ba1_dout      ),

    // Timer signals
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .vload      ( vload         ),
    .hinit      ( hinit         ),

    // VRAM
    .ram_cs     ( b1ram_cs      ),
    .ram_addr   ( b1ram_addr    ),
    .ram_data   ( b1ram_data    ),
    .ram_ok     ( b1ram_ok      ),

    // ROMs
    .rom_cs     ( b1rom_cs      ),
    .rom_addr   ( b1rom_addr    ),
    .rom_data   ( b1rom_data    ),
    .rom_ok     ( b1rom_ok      ),

    .pxl        ( ba1_pxl       ),
    .st_addr    ( st_addr       ),
    .st_dout    ( st_dout1      )
);
`else
    assign b1ram_cs = 0;
    assign b1rom_cs = 0;
    assign ba1_pxl  = 0;
`endif

`ifndef NOBA2

wire [12:1] ba2_addr;
wire [15:0] ba2_din;
wire [ 1:0] ba2_dsn;
wire        ba2_rnw, ba2_mode;

`ifdef NOHUC
    assign ba2_addr = cpu_addr;
    assign ba2_din  = cpu_dout;
    assign ba2_dsn  = cpu_dsn;
    assign ba2_rnw  = cpu_rnw;
    assign ba2_mode = cmode_cs;
    assign mcu_din  = 0;
`else
    assign ba2_addr = game_id==HIPPODROME ? {2'd0,mcu_addr} : cpu_addr;
    assign ba2_din  = game_id==HIPPODROME ? {2{mcu_dout}} : cpu_dout;
    assign ba2_dsn  = game_id==HIPPODROME ? mcu_dsn  : cpu_dsn;
    assign ba2_rnw  = game_id==HIPPODROME ? mcu_rnw  : cpu_rnw;
    assign ba2_mode = game_id==HIPPODROME ? mcu_mode  : cmode_cs;
    assign mcu_din  = mcu_addr[0] ? ba2_dout[15:8] : ba2_dout[7:0];
`endif

jtcop_bac06 #(.SIMFILE("ba2.bin")) u_ba2(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),

    .mode_cs    ( ba2_mode      ),
    .flip       ( flip          ),

    // CPU interface
    .cpu_dout   ( ba2_din       ),
    .cpu_addr   ( ba2_addr      ),
    .cpu_rnw    ( ba2_rnw       ),
    .cpu_dsn    ( ba2_dsn       ),
    .cpu_din    ( ba2_dout      ),

    // Timer signals
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .vload      ( vload         ),
    .hinit      ( hinit         ),

    // VRAM
    .ram_cs     ( b2ram_cs      ),
    .ram_addr   ( b2ram_addr    ),
    .ram_data   (  b2ram_data   ),
    .ram_ok     ( b2ram_ok      ),

    // ROMs
    .rom_cs     ( b2rom_cs      ),
    .rom_addr   ( b2rom_addr    ),
    .rom_data   ( b2rom_data    ),
    .rom_ok     ( b2rom_ok      ),

    .pxl        ( ba2_pxl       ),
    .st_addr    ( st_addr       ),
    .st_dout    ( st_dout2      )
);
`else
    assign b2ram_cs = 0;
    assign b2rom_cs = 0;
    assign ba2_pxl  = 0;
`endif

jtcop_obj u_obj(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl_cen    ( pxl_cen       ),

    .ioctl_ram  ( ioctl_ram     ),
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( obj_dmp       ),

    .HS         ( HS            ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .flip       ( flip          ),
    .vload      ( vload         ),
    .hinit      ( hinit         ),
    .hdump      ( hdump         ),
    .vrender    ( vrender       ),

    // CPU interface
    .cpu_addr   ( cpu_addr[10:1]),
    .cpu_dout   ( cpu_dout      ),
    .obj_dout   ( obj_dout      ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_rnw    ( cpu_rnw       ),
    .objram_cs  ( objram_cs     ),

    // DMA trigger
    .obj_copy   ( obj_copy      ),
    .mixpsel    ( mixpsel       ),

    // ROM interface
    .rom_cs     ( orom_cs       ),
    .rom_addr   ( orom_addr     ),
    .rom_data   ( orom_data     ),
    .rom_ok     ( orom_ok       ),

    .pxl        ( obj_pxl       )
);

// NB: this module is different for jtmidres
jtcop_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl_cen    ( pxl_cen       ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),

    // SD card dump
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( pal_dmp       ),
    .ioctl_ram  ( ioctl_ram     ),

    // CPU interface
    .pal_cs     ( pal_cs        ),
    .cpu_addr   ( cpu_addr[10:1]),
    .cpu_dout   ( cpu_dout      ),
    .dsn        ( cpu_dsn       ),
    .cpu_din    ( pal_dout      ),

    .prisel     ( prisel[2:0]   ),

    // priority PROM
    .prog_addr  ( prog_addr     ),
    .prom_din   ( prom_din      ),
    .prom_we    ( prio_we       ),

    .ba0_pxl    ( ba0_pxl       ),
    .ba1_pxl    ( ba1_pxl       ),
    .ba2_pxl    ( ba2_pxl       ),
    .obj_pxl    ( obj_pxl       ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .LVBL_dly   ( LVBL_dly      ),
    .LHBL_dly   ( LHBL_dly      ),

    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     )
);

endmodule