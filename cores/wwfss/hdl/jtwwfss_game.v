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
    Date: 27-8-2024 */

module jtwwfss_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [ 8:0] scrx, scry;
wire [ 7:0] char_dout, scr_dout, snd_latch;
wire        snd_on, v8;
reg  [ 7:0] debug_mux;
reg  [ 7:0] ioctl_mux;

assign char_dout  = main_addr[1] ? char16_dout[7:0] : char16_dout[15:8];
assign scr_dout   = main_addr[1] ?  scr16_dout[7:0] :  scr16_dout[15:8];
assign ram_addr   = main_addr[13:1];
assign debug_view = debug_mux;
assign dip_flip   = 0;
`ifndef JTFRAME_RELEASE
assign ioctl_din  = ioctl_mux;
`endif

always @(posedge clk) begin
    case (debug_bus[7:6])
        0: debug_mux <= scrx[8:1];
        1: debug_mux <= scry[8:1];
        default: debug_mux <= 0;
    endcase
end

always @* begin
    case(ioctl_addr[1:0])
        0: ioctl_mux = scrx[7:0];
        1: ioctl_mux = {7'd0,scrx[8]};
        2: ioctl_mux = scry[7:0];
        3: ioctl_mux = {7'd0,scry[8]};
    endcase
end

/* verilator tracing_off */
jtwwfss_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ), // 48 MHz
    .LVBL       ( LVBL      ),
    .v8         ( v8        ),

    .main_addr  ( main_addr ),
    .main_dsn   ( ram_dsn   ),
    .main_dout  ( main_dout ),
    .ram_we     ( ram_we    ),

    .cram_we    ( cram_we   ),
    .scr_we     ( scr_we    ),
    .oram_we    ( oram_we   ),
    .pal_we     ( pal_we    ),

    .fix_dout   ( char_dout ),
    .scr_dout   ( scr_dout  ),
    .oram_dout  ( oram2main_data ),
    .pal_dout   ( pal2main_data  ),

    .scrx       ( scrx      ),
    .scry       ( scry      ),

    .ram_cs     ( ram_cs    ),
    .ram_ok     ( ram_ok    ),
    .ram_dout   ( ram_data  ),

    .rom_cs     ( main_cs   ),
    .rom_ok     ( main_ok   ),
    .rom_data   ( main_data ),

    // Sound interface
    .snd_on     ( snd_on        ),
    .snd_latch  ( snd_latch     ),

    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
    .service    ( service       ),
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   )
);
/* verilator tracing_on */
jtwwfss_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .flip       ( 1'b0          ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .v8         ( v8            ),

    // Char
    .cram_addr  ( cram_addr     ),
    .cram_data  ( cram_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_cs    ( char_cs       ),
    .char_ok    ( char_ok       ),

    // Scroll
    .scrx       ( scrx          ),
    .scry       ( scry          ),
    .vram_addr  ( vram_addr     ),
    .vram_data  ( vram_dout     ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_cs     ( scr_cs        ),
    .scr_ok     ( scr_ok        ),

    // Object
    .oram_addr  ( oram_addr     ),
    .oram_data  ( oram_dout     ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_cs     ( obj_cs        ),
    .obj_ok     ( obj_ok        ),

    .pal_addr   ( pal_addr      ),
    .pal_dout   ( pal_dout      ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .gfx_en     ( gfx_en        )
);
/* verilator tracing_off */
jtwwfss_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    .cen_oki    ( cen_oki   ),

    // Interface with main CPU
    .snd_on     ( snd_on    ),
    .snd_latch  ( snd_latch ),

    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    // ADPCM ROM
    .pcm_addr   ( pcm_addr  ),
    .pcm_cs     ( pcm_cs    ),
    .pcm_data   ( pcm_data  ),
    .pcm_ok     ( pcm_ok    ),

    // Sound output
    .fm_l       ( fm_l      ),
    .fm_r       ( fm_r      ),
    .pcm        ( pcm       )
);

endmodule
