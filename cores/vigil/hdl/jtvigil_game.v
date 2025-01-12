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
    Date: 30-4-2022 */

module jtvigil_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam [24:0] SCR2_START  = `SCR2_START;

// video signals
wire        v1;

// CPU interface
reg  [ 7:0] dump_mux, debug_mux;
wire        main_rnw, latch_wr, pal_cs, oram_cs, scr1_ramcs;

// Scroll configuration
wire [ 8:0] scr1pos;
wire [10:0] scr2pos;
wire [ 2:0] scr2col;
wire        flip, scr2enb;
wire        is_tiles, is_obj;

// Cabinet inputs
assign dip_flip   = ~flip;
assign debug_view = debug_mux;

assign is_tiles  = prog_ba==2 && ioctl_addr[24:0]<SCR2_START;
assign is_obj    = prog_ba==3;
assign pal1_we   = ~main_rnw & pal_cs;
assign scr1_we   = ~main_rnw & scr1_ramcs;
assign ioctl_din = dump_mux;

always @* begin
    post_addr = prog_addr;
    // moves the H address bit to the LSBs
    if( is_tiles )
        post_addr[3:0] = { prog_addr[2:0], prog_addr[3] };
    if( is_obj )
        post_addr[5:0] = { prog_addr[3:0], prog_addr[5:4] };
end

always @(posedge clk) begin
    case(ioctl_addr[1:0])
        0: dump_mux <= scr1pos[7:0]; // for some reason this one gets dump as FF. Correct it manually in the file
        1: dump_mux <= scr2pos[7:0];
        2: dump_mux <= { 4'd0, scr2pos[10:8], scr1pos[8] };
        3: dump_mux <= { 3'd0, flip, scr2enb, scr2col };
    endcase
    case(debug_bus[1:0])
        0: debug_mux <= scr1pos[7:0];
        1: debug_mux <= scr2pos[7:0];
        2: debug_mux <= { 4'd0, scr2pos[10:8], scr1pos[8] };
        3: debug_mux <= { 3'd0, flip, scr2enb, scr2col };
    endcase
end

/* verilator tracing_off */
jtvigil_main u_main(
    .rst         ( rst        ),
    .clk         ( clk        ),
    .cpu_cen     ( cpu_cen    ),
    // Video
    .LVBL        ( LVBL       ),
    // Sound communication
    .latch_wr    ( latch_wr   ),
    // Palette
    .pal_cs      ( pal_cs     ),
    .pal_dout    ( pal1_dout  ),
    .scr_dout    ( scr1_dout  ),
    // Video circuitry
    .scr_cs      ( scr1_ramcs ),
    .scr1pos     ( scr1pos    ),
    .scr2pos     ( scr2pos    ),
    .scr2col     ( scr2col    ),
    .scr2enb     ( scr2enb    ),
    .obj_cs      ( oram_cs    ),

    // CPU bus
    .main_addr   ( main_addr  ),
    .cpu_dout    ( main_dout  ),
    .main_rnw    ( main_rnw   ),
    // cabinet I/O
    .joystick1   ( joystick1  ),
    .joystick2   ( joystick2  ),
    .cab_1p      ( cab_1p[1:0]),
    .coin        ( coin[1:0]  ),
    .service     ( service    ),
    // ROM access
    .rom_cs      ( main_cs    ),
    .rom_data    ( main_data  ),
    .rom_ok      ( main_ok    ),
    // DIP switches
    .flip        ( flip       ),
    .dip_pause   ( dip_pause  ),
    .dipsw_a     ( dipsw[ 7:0]),
    .dipsw_b     ( dipsw[15:8])
);
/* verilator tracing_off */
jtvigil_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_cpu    ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .v1         ( v1        ),

    // CPU interface
    .main_addr  ( main_addr[7:0] ),
    .main_dout  ( main_dout ),
    .main_rnw   ( main_rnw  ),
    // Scroll
    .scr1pos    ( scr1pos   ),
    .scr1_cs    ( scr1_cs   ),
    .scr1_ok    ( scr1_ok   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),
    .vram_addr  ( vram_addr ),
    .vram_dout  ( vram_dout ),

    .scr2pos    ( scr2pos   ),
    .scr2col    ( scr2col   ),
    .scr2_cs    ( scr2_cs   ),
    .scr2_ok    ( scr2_ok   ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data ),
    .scr2enb    ( scr2enb   ),

    // Object
    .oram_cs    ( oram_cs   ),

    // Palette
    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),
    .flip       ( flip      ),

    // SDRAM interface

    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    // Video signal
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LVBL       ( LVBL      ),
    .LHBL       ( LHBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

jtvigil_snd u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .fm_cen     ( fm_cen    ),
    .v1         ( v1        ),

    // From main CPU
    .main_dout  ( main_dout ),
    .latch_wr   ( latch_wr  ),

    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    // PCM ROM
    .pcm_addr   ( pcm_addr  ),
    .pcm_cs     ( pcm_cs    ),
    .pcm_data   ( pcm_data  ),
    .pcm_ok     ( pcm_ok    ),

    .fm_l       ( fm_l      ),
    .fm_r       ( fm_r      ),
    .pcm        ( pcm       ),
    .debug_bus  ( debug_bus )
);

endmodule
