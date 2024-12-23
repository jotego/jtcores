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

/* verilator tracing_off */
wire [ 7:0] snd_latch;
wire [ 9:0] obj_dx, obj_dy;
wire [ 8:0] scra_x, scra_y, scrb_x, scrb_y;
wire        snd_irq, pal_cs, cpu_we, crtkill, dma_on, dma_bsy,
            cpu_rnw, snd_wrn, hflip, vflip, tim;
wire [ 7:0] st_main, st_video, st_snd;
wire [15:0] scr_bank;
wire [19:1] cpu_addr;
wire [ 1:0] prio;
reg  [ 7:0] debug_mux, ioctl_mux;
wire        oram_wex;
// reg  [ 2:0] game_id;

assign main_addr  = cpu_addr[18:1];
assign debug_view = debug_mux;
assign ram_addr   = main_addr[13:1];
assign ram_we     = cpu_we;
assign vram_addr[12:1] = main_addr[12:1];
assign oram_we = {2{oram_wex}};
assign ioctl_din = ioctl_mux;

always @(posedge clk) begin
    case( ioctl_addr[3:0] )
         0: ioctl_mux <= scra_x[7:0];
         1: ioctl_mux <= scrb_x[7:0];
         2: ioctl_mux <= scra_y[7:0];
         3: ioctl_mux <= scrb_y[7:0];
         4: ioctl_mux <= { vflip, hflip, prio, scrb_y[8],scra_y[8], scrb_x[8], scra_x[8] };
         5: ioctl_mux <= scr_bank[ 7:0];
         6: ioctl_mux <= scr_bank[15:8];
         7: ioctl_mux <= obj_dx[ 7:0];
         8: ioctl_mux <= { 6'd0, obj_dx[9:8] };
         9: ioctl_mux <= obj_dy[ 7:0];
        10: ioctl_mux <= { 6'd0, obj_dy[9:8] };
        default: ioctl_mux <= 0;
    endcase
end

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= st_main;
        1: debug_mux <= st_video;
        2: debug_mux <= st_snd;
        3: debug_mux <= { 7'd0, dip_flip };
    endcase
end

// always @(posedge clk) begin
//     if( prog_addr==0 && prog_we && header )
//         game_id <= prog_data[2:0];
// end

/* verilator tracing_on */
jttwin16_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .LVBL           ( LVBL          ),

    .cpu_we         ( cpu_we        ),
    .cpu_dout       ( ram_din       ),

    .main_addr      ( cpu_addr      ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_dsn        ( ram_dsn       ),
    .ram_dout       ( ram_data      ),
    .ram_cs         ( ram_cs        ),
    .ram_ok         ( ram_ok        ),
    // Video ROM check
    .scr_data       ( lyra_data     ),
    .scr_ok         ( lyra_ok       ),
    .obj_data       ( lyro_data     ),
    .obj_ok         ( lyro_ok       ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),

    .ma_dout        ( ma_dout       ),
    .mb_dout        ( mb_dout       ),
    .mf_dout        ( mf_dout       ),
    .mo_dout        ( mo_dout       ),
    .mp_dout        ( mp_dout       ),
    .va_we          ( va_we         ),
    .vb_we          ( vb_we         ),
    .fx_we          ( fx_we         ),
    .obj_we         ( obj_we        ),
    .tim            ( tim           ),

    // To video
    .prio           ( prio          ),
    .crtkill        ( crtkill       ),
    .dma_on         ( dma_on        ),
    .dma_bsy        ( dma_bsy       ),
    .pal_we         ( pal_we        ),
    .hflip          ( hflip         ),
    .vflip          ( vflip         ),
    .scr_bank       ( scr_bank      ),
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
    .dip_test       ( dip_test      ),
    .dipsw          ( dipsw[19:0]   ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);

/* verilator tracing_on */
jttwin16_video u_video (
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),

    .hflip          ( hflip         ),
    .vflip          ( vflip         ),
    .crtkill        ( crtkill       ),
    .tim            ( tim           ),

    .cpu_prio       ( prio          ),
    .scr_bank       ( scr_bank      ),
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
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      ( prog_addr[7:0]),
    .prog_data      ( prog_data[2:0]),
    // GFX - CPU interface
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( ram_din[7:0]  ),
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
    // SDRAM
    .lyra_addr      ( lyra_addr     ),
    .lyrb_addr      ( lyrb_addr     ),
    .lyrf_addr      ( lyrf_addr     ),
    .lyro_addr      ( lyro_addr     ),
    .lyra_data      ( lyra_data     ),
    .lyrb_data      ( lyrb_data     ),
    .lyro_data      ( lyro_data     ),
    .lyrf_data      ( lyrf_data     ),
    .lyrf_cs        ( lyrf_cs       ),
    .lyra_cs        ( lyra_cs       ),
    .lyrb_cs        ( lyrb_cs       ),
    .lyro_cs        ( lyro_cs       ),
    .lyro_ok        ( lyro_ok       ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .ioctl_addr     (ioctl_addr[14:0]),
    // .ioctl_din      ( ioctl_din     ),
    .ioctl_ram      ( ioctl_ram     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

/* verilator tracing_off */
jttmnt_sound #( // -1.5dB compared to MIA, same balance
    .MONO_FM    ( 8'h18 ),
    .MONO_PCM   ( 8'h06 ),
    .MONO_UPD   ( 8'h0C ),
    .MONO_TTL   ( 8'h00 )
) u_sound(
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
    .snd_left   ( snd           ),
    .snd_right  (               ),
    .sample     ( sample        ),
    .peak       ( game_led      ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_snd        )
);

endmodule
