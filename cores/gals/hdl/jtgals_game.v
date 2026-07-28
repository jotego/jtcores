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
    Date: 12-7-2026 */

module jtgals_game(
    `include "jtframe_game_ports.inc"
);

wire [23:1] cpu_addr;
wire [15:0] cpu_din;
wire [ 8:0] vdump;
wire [ 7:0] oki_dout;
wire        oki_cs, oki_wr, oki_bank_we, irq3_n, irq5_n;
wire        cpu_rnw;
wire [ 3:0] oki_bank;
reg         prot_wdog = 1'b0;

assign ram_we = ram_cs & ~cpu_rnw;
assign dip_flip   = 1'b1;
assign debug_view = { 7'd0, fb_keep };
`ifdef JTFRAME_IOCTL_RD
assign ioctl_din  = 8'd0;
`endif

always @(posedge clk) begin
    if (header && prog_we && prog_addr[1:0] == 2'd0)
        prot_wdog <= prog_data[0];
end

jtgals_main u_main(
    .rst            ( rst             ),
    .clk            ( clk             ),
    .lvbl           ( LVBL            ),
    .vdump          ( vdump           ),
    .dip_pause      ( dip_pause       ),
    .prot_wdog      ( prot_wdog       ),

    .joystick1      ( joystick1[5:0]  ),
    .joystick2      ( joystick2[5:0]  ),
    .start_button   ( cab_1p[1:0]     ),
    .coin           ( coin[1:0]       ),
    .service        ( service         ),
    .tilt           ( tilt            ),
    .dipsw          ( dipsw           ),

    .cpu_addr       ( cpu_addr        ),
    .cpu_dout       ( cpu_dout        ),
    .cpu_din        ( cpu_din         ),
    .cpu_rnw        ( cpu_rnw         ),

    .ram_addr       ( ram_addr        ),
    .ram_dsn        ( ram_dsn         ),
    .ram_cs         ( ram_cs          ),
    .ram_data       ( ram_data        ),
    .ram_ok         ( ram_ok          ),

    .fg_addr        ( fg_addr         ),
    .fg_we          ( fg_we           ),
    .fg_dout        ( fg_dout         ),
    .bg_addr        ( bg_addr         ),
    .bg_we          ( bg_we           ),
    .bg_dout        ( bg_dout         ),
    .pal_addr       ( pal_addr        ),
    .pal_we         ( pal_we          ),
    .pal_dout       ( pal_dout        ),
    .objram_addr    ( objram_addr     ),
    .objram_din     ( objram_din      ),
    .objram_we      ( objram_we       ),
    .objram_dout    ( objram_dout     ),
    .objaux_addr    ( objaux_addr     ),
    .objaux_we      ( objaux_we       ),
    .objaux_dout    ( objaux_dout     ),

    .oki_dout       ( oki_dout        ),
    .oki_cs         ( oki_cs          ),
    .oki_wr         ( oki_wr          ),
    .oki_bank_we    ( oki_bank_we     ),
    .oki_bank       ( oki_bank        ),
    .irq3_n         ( irq3_n          ),
    .irq5_n         ( irq5_n          ),
    .fb_keep        ( fb_keep         ),

    .rom_addr       ( main_addr       ),
    .rom_cs         ( main_cs         ),
    .rom_data       ( main_data       ),
    .rom_ok         ( main_ok         )
);

jtgals_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_pcm       ),
    .cpu_dout   ( cpu_dout[7:0] ),
    .cs         ( oki_cs        ),
    .wr         ( oki_wr        ),
    .bank       ( oki_bank      ),
    .dout       ( oki_dout      ),
    .rom_cs     ( pcm_cs        ),
    .rom_addr   ( pcm_addr      ),
    .rom_data   ( pcm_data      ),
    .rom_ok     ( pcm_ok        ),
    .pcm        ( pcm           )
);

`ifdef SIMSCENE
/* verilator tracing_on */
`endif
jtgals_video u_video(
    .rst                ( rst              ),
    .clk                ( clk              ),
    .pxl_cen            ( pxl_cen          ),
    .gfx_en             ( gfx_en           ),
    .game_vrender       ( game_vrender     ),
    .game_hdump         ( game_hdump       ),
    .ln_addr            ( ln_addr          ),
    .ln_data            ( ln_data          ),
    .ln_done            ( ln_done          ),
    .ln_hs              ( ln_hs            ),
    .ln_dout            ( ln_dout          ),
    .ln_pxl             ( ln_pxl           ),
    .ln_v               ( ln_v             ),
    .ln_vs              ( ln_vs            ),
    .ln_lvbl            ( ln_lvbl          ),
    .ln_we              ( ln_we            ),

    .fg_video_addr      ( fg_video_addr    ),
    .fg_video_dout      ( fg_video_dout    ),
    .bg_video_addr      ( bg_video_addr    ),
    .bg_video_dout      ( bg_video_dout    ),
    .pal_video_addr     ( pal_video_addr   ),
    .pal_video_dout     ( pal_video_dout   ),
    .objram_video_addr  ( objram_video_addr),
    .objram_video_dout  ( objram_video_dout),

    .obj_cs             ( obj_cs           ),
    .obj_addr           ( obj_addr         ),
    .obj_data           ( obj_data         ),
    .obj_ok             ( obj_ok           ),

    .LHBL               ( LHBL             ),
    .LVBL               ( LVBL             ),
    .HS                 ( HS               ),
    .VS                 ( VS               ),
    .vdump              ( vdump            ),
    .red                ( red              ),
    .green              ( green            ),
    .blue               ( blue             )
);

endmodule
