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
    Date: 6-7-2025 */

module jtrungun_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [23:0] psrm_dout;
wire [12:1] cpu_addr;
wire [15:0] omem_dout;
wire [ 7:0] vtimer_mmr, st_main, st_snd, pair_dout;
wire [ 3:0] psac_bank;
wire        lrsw, psac_cs, ccu_cs, disp, gvflip, ghflip, pri, cpu_rnw, pair_we,
            sdon, objrg_cs, objrm_cs, objcha_n, dma_bsy;
reg         rst_main, rst_snd, rst_video;


assign debug_view={7'd0,dma_bsy};
assign dip_flip = ghflip ^ gvflip;
assign psrm_dout = {psac2_dout,psac01_dout};

always @(posedge clk48) begin
    rst_main  <= rst48;
    rst_snd   <= rst48;
end

always @(posedge clk) begin
    rst_video <= rst;
end

/* verilator tracing_on */
jtrungun_main u_main(
    .rst            ( rst48         ),
    .clk            ( clk48         ),
    .clk96          ( clk96         ),
    .pxl_cen        ( pxl_cen       ),
    .lvbl           ( LVBL          ),

    .lrsw           ( lrsw          ),
    .disp           ( disp          ),
    .pri            ( pri           ),
    .ghflip         ( ghflip        ),
    .gvflip         ( gvflip        ),

    .cpu_rnw        ( cpu_rnw       ),
    .cpu_dout       ( cpu_dout      ),

    .vmem_addr      ( vmem_addr     ),
    .pmem_addr      ( pmem_addr     ),
    .psac_bank      ( psac_bank     ),
    .vtimer_mmr     ( vtimer_mmr    ),

    .cpu_addr       ( cpu_addr      ),
    .rom_addr       ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_dsn        ( ram_dsn       ),
    .ram_we         ( ram_we        ),
    .ram_dout       ( ram_data      ),
    .ram_cs         ( ram_cs        ),
    .ram_ok         ( ram_ok        ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .joystick4      ( joystick4     ),
    .service        ( {4{service}}  ),
    // objects
    .objrg_cs       ( objrg_cs      ),
    .objrm_cs       ( objrm_cs      ),
    .odma           ( dma_bsy       ),
    .objcha_n       ( objcha_n      ),

    .cpal_addr      ( cpal_addr     ),

    .vmem_we        ( vmem_we       ),
    .pmem01_we      ( pmem01_we     ),
    .pmem2_we       ( pmem2_we      ),
    .lmem_we        ( lmem_we       ),
    .cpal_we        ( cpal_we       ),

    .vmem_dout      ( vmem_dout     ),
    .pmem01_dout    ( pmem01_dout   ),
    .pmem2_dout     ( pmem2_dout    ),
    .lmem_dout      ( lmem_dout     ),
    .omem_dout      ( omem_dout     ),
    .cpal_dout      ( cpal_dout     ),

    .psreg_cs       ( psac_cs       ),
    .ccu_cs         ( ccu_cs        ), // video timer
    // EEPROM
    .nv_addr        ( nvram_addr    ),
    .nv_dout        ( nvram_dout    ),
    .nv_din         ( nvram_din     ),
    .nv_we          ( nvram_we      ),
    // Sound
    .pair_dout      ( pair_dout     ),
    .pair_we        ( pair_we       ),
    .sdon           ( sdon          ),
    // DIP switches
    .dipsw          ( dipsw[7:4]    ),
    .dip_pause      ( dip_pause     ),
    .dip_test       ( dip_test      ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);
/* verilator tracing_off */
jtrungun_sound u_sound(
    .rst            ( rst_snd       ),
    .clk            ( clk48         ),
    .cen_8          ( cen_8         ),
    .cen_pcm        ( cen_pcm       ),

    // communication with main CPU
    .main_dout      ( cpu_dout[15:8]),  // bus access for Punk Shot
    .pair_dout      ( pair_dout     ),
    .main_addr      ( cpu_addr[4:1] ),
    .pair_we        ( pair_we       ),

    .snd_irq        ( sdon          ),
    // ROM
    .rom_addr       ( snd_addr      ),
    .rom_cs         ( snd_cs        ),
    .rom_data       ( snd_data      ),
    .rom_ok         ( snd_ok        ),
    // ADPCM ROM
    .pcma_addr      ( pcma_addr     ),
    .pcmb_addr      ( pcmb_addr     ),
    .pcma_data      ( pcma_data     ),
    .pcmb_data      ( pcmb_data     ),
    .pcma_cs        ( pcma_cs       ),
    .pcmb_cs        ( pcmb_cs       ),
    // Sound output
    .k539a_l        ( k539a_l       ),
    .k539a_r        ( k539a_r       ),
    .k539b_l        ( k539b_l       ),
    .k539b_r        ( k539b_r       ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_snd        )
);
/* verilator tracing_on */
jtrungun_video u_video(
    .rst            ( rst_video     ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .ghflip         ( ghflip        ),
    .gvflip         ( gvflip        ),
    .lrsw           ( lrsw          ),
    .pri            ( pri           ),

    .disp           ( disp          ),
    // Base Video
    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .hdump          ( game_hdump    ),
    .vdump          ( game_vrender  ),
    // CPU interface
    .ccu_cs         ( ccu_cs        ),   // timer
    .psac_cs        ( psac_cs       ),
    .addr           ( cpu_addr      ),
    .rnw            ( cpu_rnw       ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_dsn        ( ram_dsn       ),
    .vtimer_mmr     ( vtimer_mmr    ),
    // fixed layer
    .vram_addr      ( vram_addr     ),
    .vram_dout      ( vram_dout     ),
    // objects
    .objrg_cs       ( objrg_cs      ),
    .objrm_cs       ( objrm_cs      ),
    .dma_bsy        ( dma_bsy       ),
    .objcha_n       ( objcha_n      ),
    .objrm_dout     ( omem_dout     ),
    // palette
    .pal_addr       ( pal_addr      ),
    .pal_dout       ( pal_dout      ),

    .fix_addr       ( fix_addr      ),
    .fix_data       ( fix_data      ),
    .fix_cs         ( fix_cs        ),
    .fix_ok         ( fix_ok        ),

    // PSAC
    .line_addr      ( line_addr     ),
    .line_dout      ( line_dout     ),

    .psrm_addr      ( psac_addr     ),
    .psrm_dout      ( psrm_dout     ),

    .scr_addr       ( scr_addr      ),
    .scr_data       ( scr_data      ),
    .scr_cs         ( scr_cs        ),
    .scr_ok         ( scr_ok        ),

    .obj_addr       ( obj_addr      ),
    .obj_data       ( obj_data      ),
    .obj_cs         ( obj_cs        ),
    .obj_ok         ( obj_ok        ),

    // Frame buffer
    .ln_addr        ( ln_addr       ),
    .ln_data        ( ln_data       ),
    .ln_done        ( ln_done       ),
    .ln_vs          ( ln_vs         ),
    .ln_lvbl        ( ln_lvbl       ),
    .ln_hs          ( ln_hs         ),
    .ln_pxl         ( ln_pxl        ),
    .ln_v           ( ln_v          ),
    .ln_we          ( ln_we         ),
    // final pixel
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Debug
    .gfx_en         ( gfx_en        ),
    .debug_bus      ( debug_bus     ),
    // IOCTL dump
    .ioctl_ram      ( ioctl_ram     ),
    .ioctl_addr     (ioctl_addr[14:0]),
    .ioctl_din      ( ioctl_din     )
);

endmodule
