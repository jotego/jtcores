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
    Date: 27-8-2023 */

module jttwin16_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

/* verilator tracing_on */
wire [ 7:0] snd_latch;
wire [ 8:0] scra_x, scra_y, scrb_x, scrb_y;
wire        snd_irq, pal_cs, dma_on, dma_bsy, vramcvf, mint,
            cpu_rnw, snd_wrn, hflip, vflip, tim, tim1, tim2, sint;
wire [ 7:0] st_main, st_video, st_snd;
wire [15:0] m_dout, s_dout, shs_dout, shm_dout, obj_dx, obj_dy;
wire [19:1] m_addr;
wire [17:1] s_addr;
wire [ 1:0] vam_we, vbm_we, om_we, stile_we16,
            vas_we, vbs_we, os_we,
            shs_we, shm_we;
reg  [ 7:0] debug_mux, ioctl_mux;
wire        oram_wex;
wire [ 2:0] prio;

assign main_addr  = m_addr[17:1];
assign mram_addr  = m_addr[13:1];
assign debug_view = debug_mux;
assign oram_we    = {2{oram_wex}};
assign ioctl_din = ioctl_mux;
assign sram_din   = s_dout;
assign mram_din   = m_dout;
assign stile_addr = s_addr;

`ifdef SCRTILE_SDRAM
wire [15:0] stile_dout = stile_data;
assign stile_dsn = sram_dsn;
assign stile_we  = sram_we;
`else
wire [31:0] lyra_data, lyrb_data;
wire [17:2] lyra_addr, lyrb_addr;
wire   stile_cs, lyra_cs, lyrb_cs;
reg    stile_ok;
assign stile_we  = stile_we16;
always @(posedge clk) stile_ok <= stile_cs;
// makes consequitive requests to
// convert 16 bit data to 32 bits
jttwin16_tile u_tile(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .vramcvf    ( vramcvf       ),
    .lyra_addr  ( lyra_addr     ),
    .lyrb_addr  ( lyrb_addr     ),
    .stram_addr ( stram_addr    ),
    .stram_dout ( stram_dout    ),
    .lyra_data  ( lyra_data     ),
    .lyrb_data  ( lyrb_data     )
);
`endif

always @(posedge clk) begin
    case( ioctl_addr[3:0] )
         0: ioctl_mux <= scra_x[7:0];
         1: ioctl_mux <= scrb_x[7:0];
         2: ioctl_mux <= scra_y[7:0];
         3: ioctl_mux <= scrb_y[7:0];
         4: ioctl_mux <= { vflip, hflip, prio[1:0], scrb_y[8],scra_y[8], scrb_x[8], scra_x[8] };
         7: ioctl_mux <= obj_dx[ 7:0];
         8: ioctl_mux <= obj_dx[15:8];
         9: ioctl_mux <= obj_dy[ 7:0];
        10: ioctl_mux <= obj_dy[15:8];
        11: ioctl_mux <= {7'd0, dma_on};
        default: ioctl_mux <= 0;
    endcase
end

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= st_main;
        1: debug_mux <= st_video;
        2: debug_mux <= st_snd;
        3: debug_mux <= {3'd0, vramcvf, 1'd0, vflip, hflip, dip_flip };
    endcase
end

// always @(posedge clk) begin
//     if( prog_addr==0 && prog_we && header )
//         game_id <= prog_data[2:0];
// end
/* verilator tracing_off */
jttwin16_share u_share(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen            ( cen_1m5       ),
    .tim1           ( tim1          ),  // main CPU has access to video
    .tim2           ( tim2          ),  // sub CPU does
    // main CPU
    .m_addr         ( m_addr[13:1]  ),
    .m_dout         ( m_dout        ),
    .om_we          ( om_we         ),
    .vam_we         ( vam_we        ),
    .vbm_we         ( vbm_we        ),
    .shm_we         ( shm_we        ),
    .shm_dout       ( shm_dout      ),
    // sub CPU
    .s_addr         ( s_addr[13:1]  ),
    .s_dout         ( s_dout        ),
    .os_we          ( os_we         ),
    .vas_we         ( vas_we        ),
    .vbs_we         ( vbs_we        ),
    .shs_we         ( shs_we        ),
    .shs_dout       ( shs_dout      ),
    // video RAM muxes
    .vram_addr      ( vram_addr     ),
    .osha_addr      ( osha_addr     ),
    .va_we          ( va_we         ),
    .vb_we          ( vb_we         ),
    .oram_we        ( osha_we       ),
    .v_din          ( v_din         )
);

jttwin16_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .LVBL           ( LVBL          ),

    .cpu_dout       ( m_dout        ),
    .mint           ( mint          ),
    .sint           ( sint          ),

    .main_addr      ( m_addr        ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_dsn        ( mram_dsn      ),
    .ram_dout       ( mram_data     ),
    .ram_cs         ( mram_cs       ),
    .ram_ok         ( mram_ok       ),
    .ram_we         ( mram_we       ),
    // shared RAM
    .sh_we          ( shm_we        ),
    .sh_dout        ( shm_dout      ),
    // NVRAM
    .nvram_addr     ( nvram_addr    ),
    .nvram_dout     ( nvram_dout    ),
    .nvram_we       ( nvram_we      ),
    // cabinet I/O
    .cab_1p         ( cab_1p[2:0]   ),
    .coin           ( coin[2:0]     ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .service        ( service       ),

    .ma_dout        ( ma_dout       ),
    .mb_dout        ( mb_dout       ),
    .mf_dout        ( mf_dout       ),
    .mo_dout        ( mo_dout       ),
    .mp_dout        ( mp_dout       ),
    .va_we          ( vam_we        ),
    .vb_we          ( vbm_we        ),
    .fx_we          ( fx_we         ),
    .oram_we        ( om_we         ),
    .tim            ( tim1          ),

    // To video
    .prio           ( prio          ),
    .vramcvf        ( vramcvf       ),
    .dma_on         ( dma_on        ),
    .dma_bsy        ( dma_bsy       ),
    .pal_we         ( pal_we        ),
    .hflip          ( hflip         ),
    .vflip          ( vflip         ),
    // scroll for each layer
    .scra_x         ( scra_x        ),
    .scra_y         ( scra_y        ),
    .scrb_x         ( scrb_x        ),
    .scrb_y         ( scrb_y        ),
    .obj_dx         ( obj_dx        ),
    .obj_dy         ( obj_dy        ),
    // To sound
    .snd_latch      ( snd_latch     ),
    .sndon          ( snd_irq       ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw          ( dipsw[19:0]   ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);
/* verilator tracing_on */
jttwin16_sub u_sub(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .LVBL           ( LVBL          ),
    .tim            ( tim2          ),
    .mint           ( mint          ),
    .sint           ( sint          ),
    .dma_bsy        ( dma_bsy       ),

    .ram_addr       ( sram_addr     ),
    .ram_dout       ( sram_data     ),
    .ram_ok         ( sram_ok       ),
    .ram_cs         ( sram_cs       ),
    .bus_dsn        ( sram_dsn      ),
    .bus_we         ( sram_we       ),

    .cpu_addr       ( s_addr        ),
    .cpu_dout       ( s_dout        ),
    // shared RAM
    .sh_we          ( shs_we        ),
    .sh_dout        ( shs_dout      ),
    // video RAM outputs,
    .ma_dout        ( ma_dout       ),   // scroll A
    .mb_dout        ( mb_dout       ),   // scroll B
    .mo_dout        ( mo_dout       ),   // objects
    .va_we          ( vas_we        ),
    .vb_we          ( vbs_we        ),
    .oram_we        ( os_we         ),

    // tile RAMs
    .stile_cs       ( stile_cs      ),
    .stile_we       ( stile_we16    ),
    .stile_dout     ( stile_dout    ),
    .stile_ok       ( stile_ok      ),
    // video ROM checks
    .obj_addr       ( chko_addr     ),
    .obj_cs         ( chko_cs       ),
    .obj_data       ( chko_data     ),
    .obj_ok         ( chko_ok       ),

    .rom_addr       ( sub_addr      ),
    .rom_cs         ( sub_cs        ),
    .rom_ok         ( sub_ok        ),
    .rom_data       ( sub_data      ),
    .dip_pause      ( dip_pause     )
);

/* verilator tracing_off */
jttwin16_video u_video (
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),

    .hflip          ( hflip         ),
    .vflip          ( vflip         ),
    .vramcvf        ( vramcvf       ),

    .cpu_prio       ( prio          ),
    .scra_x         ( scra_x        ),
    .scra_y         ( scra_y        ),
    .scrb_x         ( scrb_x        ),
    .scrb_y         ( scrb_y        ),
    .obj_dx         ( obj_dx        ),
    .obj_dy         ( obj_dy        ),

    .dma_on         ( dma_on        ),
    .dma_bsy        ( dma_bsy       ),

    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),
    // VRAM
    .fram_addr      ( fram_addr     ),
    .fram_dout      ( fram_dout     ),
    .scra_addr      ( scra_addr     ),
    .scra_dout      ( scra_dout     ),
    .scrb_addr      ( scrb_addr     ),
    .scrb_dout      ( scrb_dout     ),
    .oram_addr      ( oram_addr     ),
    .oram_dout      ( oram_dout     ),
    .oram_din       ( oram_din      ),
    .oram_we        ( oram_wex      ),
    .pal_addr       ( pal_addr      ),
    .pal_dout       ( pal_dout      ),
    // tile RAM
    .lyra_cs        ( lyra_cs       ),
    .lyra_addr      ( lyra_addr     ),
    .lyra_data      ( lyra_data     ),
    .lyrb_cs        ( lyrb_cs       ),
    .lyrb_addr      ( lyrb_addr     ),
    .lyrb_data      ( lyrb_data     ),
    // SDRAM
    .lyrf_addr      ( lyrf_addr     ),
    .lyro_addr      ( lyro_addr     ),
    .lyro_data      ( lyro_data     ),
    .lyrf_data      ( lyrf_data     ),
    .lyrf_cs        ( lyrf_cs       ),
    .lyro_cs        ( lyro_cs       ),
    .lyro_ok        ( lyro_ok       ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

/* verilator tracing_off */
jttmnt_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_fm     ( cen_fm        ),
    .cen_fm2    ( cen_fm2       ),
    .cen_640    ( cen_640       ),
    .cen_20     ( 1'b0          ),  // for title music in TMNT, unused here
    .game_id    ( 3'd0          ),
    // communication with main CPU
    .main_dout  ( 8'd0          ),
    .main_din   (               ),
    .main_addr  ( 1'b0          ),
    .main_rnw   ( 1'b1          ),
    .snd_irq    ( snd_irq       ),
    .snd_latch  ( snd_latch     ),
    // ROM
    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),
    // ADPCM ROM
    .pcma_addr  ( pcma_addr     ),
    .pcma_dout  ( pcma_data     ),
    .pcma_cs    ( pcma_cs       ),
    .pcma_ok    ( pcma_ok       ),

    .pcmb_addr  ( pcmb_addr     ),
    .pcmb_dout  ( pcmb_data     ),
    .pcmb_cs    ( pcmb_cs       ),
    .pcmb_ok    ( pcmb_ok       ),

    .pcmc_addr  (               ),
    .pcmc_dout  ( 8'd0          ),
    .pcmc_cs    (               ),
    .pcmc_ok    ( 1'b1          ),

    .pcmd_addr  (               ),
    .pcmd_dout  ( 8'd0          ),
    .pcmd_cs    (               ),
    .pcmd_ok    ( 1'b1          ),

    .upd_addr   ( upd_addr      ),
    .upd_cs     ( upd_cs        ),
    .upd_data   ( upd_data      ),
    .upd_ok     ( upd_ok        ),
    // Title music
    .title_addr (               ),
    .title_data ( 16'd0         ),
    .title_cs   (               ),
    .title_ok   ( 1'b1          ),
    // Sound output
    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          ),
    .pcm        ( pcm           ),
    .upd        ( upd           ),
    .k60_l      (               ),
    .k60_r      (               ),
    .title      (               ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_snd        )
);

endmodule
