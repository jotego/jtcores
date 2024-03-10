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
    Date: 12-10-2019 */


module jttora_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [ 8:0] V, H;

wire [13:1] cpu_AB;
wire        char_cs, col_uw, col_lw;
wire        flip;
wire [15:0] char_dout, cpu_dout;
wire        rd, cpu_cen, video_cen8;
wire        char_busy;

// MCU interface
wire [ 7:0] snd_din, snd_dout;
wire        snd_mcu_wr;
wire        mcu_brn;
wire [ 7:0] mcu_din, mcu_dout;
wire [16:1] mcu_addr;
wire        mcu_wr, mcu_DMAn, mcu_DMAONn;

wire [ 7:0] dipsw_a, dipsw_b;
reg  [ 7:0] debug_mux;

wire [15:0] scrposh, scrposv;
wire        UDSWn, LDSWn,RnW;
// sound
wire [ 7:0] snd_latch, st_snd;

// OBJ
wire OKOUT, blcnten, obj_br, bus_ack;
wire [13:1] obj_AB;     // 1 more bit than older games
wire [15:0] oram_dout;

wire        prom_mcu, prom_prio;
reg         jap,        // high if Japanese ROM was loaded
            f1dream;    // selects F1-Dream version of the PB

// A and B are inverted in this game (or in MAME definition)
assign {dipsw_a, dipsw_b} = dipsw[15:0];
assign dip_flip = flip;

assign debug_view = debug_mux;

// ROM Download
assign prom_prio = prom_we && ioctl_addr[12:8]==0;
assign prom_mcu  = prom_we && ioctl_addr[12:8]!=0;

always @(posedge clk) begin
    if( header && ioctl_addr[2:0]==0 && prog_we )
        { jap, f1dream } <= prog_data[1:0];
end

always @* begin
    case( debug_bus[2:0] )
        0: debug_mux = scrposh[ 7:0];
        1: debug_mux = scrposh[15:8];
        2: debug_mux = scrposv[ 7:0];
        3: debug_mux = scrposv[15:8];
        4: debug_mux = { 3'd0,scr_addr[19],3'd0, jap };
        default: debug_mux = 0;
    endcase
end

/////////////////////////////////////
// 48 MHz based clock enable signals
jtframe_cen48 u_cen48(
    .clk    ( clk           ),
    .cen16  (               ),
    .cen16b (               ),
    .cen12  ( pxl2_cen      ),
    .cen12b (               ),
    .cen8   ( video_cen8    ),
    .cen6   ( pxl_cen       ),
    .cen6b  (               ),
    .cen4   (               ),
    .cen4_12(               ),
    .cen3   (               ),
    .cen3q  (               ),
    .cen3qb (               ),
    .cen3b  (               ),
    .cen1p5 (               ),
    .cen1p5b(               )
);

/////////////////////////////////////
// 24 MHz based clock enable signals
wire        cen3, mcu_cen, clk_mcu;
wire        cenfm, cenp384;
wire        cen10b;
reg         rst_mcu;

jtframe_cen24 u_cen(
    .clk    ( clk24     ),
    .cen12  (           ),
    .cen12b (           ),
    .cen8   (           ),
    .cen4   (           ),
    .cen6   (           ),
    .cen6b  (           ),
    .cen3   ( cen3      ),
    .cen3q  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5 ( mcu_cen   ),
    .cen1p5b(           )
);

assign clk_mcu = clk24;
always @(posedge clk) rst_mcu = rst24 | ~f1dream;

jtframe_cen3p57 #(.CLK24(1)) u_cen3p57(
    .clk      ( clk24     ),
    .cen_3p57 ( cenfm     ),
    .cen_1p78 (           )     // unused
);

jtframe_cenp384 #(.CLK24(1)) u_cenp384(
    .clk      ( clk24     ),
    .cen_p384 ( cenp384   )
);

jtbiocom_main #(.GAME(1)) u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_cenb   (               ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // sound
    .snd_latch  ( snd_latch     ),
    .snd_nmi_n  (               ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .UDSWn      ( UDSWn         ),
    .LDSWn      ( LDSWn         ),
    // SCROLL
    .scr1_cs    (               ),
    .scr1_busy  ( 1'b0          ),
    .scr1_dout  (               ),
    .scr1_hpos  ( scrposh       ),
    .scr1_vpos  ( scrposv       ),
    .scr_bank   ( scr_addr[19]  ),
    // SCROLL 2 - Unused
    .scr2_cs    (               ),
    .scr2_busy  ( 1'b0          ),
    .scr2_dout  (               ),
    .scr2_hpos  (               ),
    .scr2_vpos  (               ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .oram_dout  ( oram_dout     ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .obj_br     ( obj_br        ),
    .bus_ack    ( bus_ack       ),
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    // MCU interface
    .mcu_cen    (  mcu_cen      ),
    .mcu_brn    (  mcu_brn  | ~f1dream ),
    .mcu_din    (  mcu_din      ),
    .mcu_dout   (  mcu_dout     ),
    .mcu_addr   (  mcu_addr     ),
    .mcu_wr     (  mcu_wr       ),
    .mcu_DMAn   (  mcu_DMAn | ~f1dream ),
    .mcu_DMAONn (  mcu_DMAONn   ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p( cab_1p ),
    .service    ( service       ),
    .coin       ( coin          ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);

jtbiocom_mcu #(.ROMBIN("../../../../rom/f1dream/8751.mcu")) u_mcu(
    .rst        ( rst_mcu         ),
    .clk        ( clk_mcu         ),
    .rst_cpu    ( rst             ),
    .clk_rom    ( clk             ),
    .clk_cpu    ( clk             ),
    .cen6a      ( mcu_cen         ), // 6 MHz
    // Main CPU interface
    .DMAONn     ( mcu_DMAONn      ),
    .mcu_din    ( mcu_din         ),
    .mcu_dout   ( mcu_dout        ),
    .mcu_wr     ( mcu_wr          ), // always write to low bytes
    .mcu_addr   ( mcu_addr        ),
    .mcu_brn    ( mcu_brn         ), // RQBSQn
    .DMAn       ( mcu_DMAn        ),

    // Sound CPU interface
    .snd_din    ( snd_din         ),
    .snd_dout   ( snd_dout        ),
    .snd_mcu_wr ( snd_mcu_wr      ),
    .snd_mcu_rd ( 1'b0            ),
    // ROM programming
    .prog_addr  ( prog_addr[11:0] ),
    .prom_din   ( prog_data       ),
    .prom_we    ( prom_mcu        )
);

jttora_sound u_sound (
    .rst            ( rst24          ),
    .clk            ( clk24          ),
    .cen3           ( cen3           ),
    .cenfm          ( cenfm          ),
    .cenp384        ( cenp384        ),
    .jap            ( jap            ),
    .f1dream        ( f1dream        ),
    // Interface with main CPU
    .snd_latch      ( snd_latch      ),
    // Interface with MCU
    .snd_din        ( snd_din        ),
    .snd_dout       ( snd_dout       ),
    .snd_mcu_wr     ( snd_mcu_wr     ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // ROM 2
    .rom2_addr      ( snd2_addr      ),
    .rom2_data      ( snd2_data      ),
    .rom2_cs        ( snd2_cs        ),
    .rom2_ok        ( snd2_ok        ),
    // sound output
    .fm0            ( fm0            ),
    .fm1            ( fm1            ),
    .psg0           ( psg0           ),
    .psg1           ( psg1           ),
    .pcm            ( pcm            ),
    .debug_view     ( st_snd         )
);

jttora_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( pxl2_cen      ),
    .cen8       ( video_cen8    ),
    .cen6       ( pxl_cen       ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB        ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .UDSWn      ( UDSWn         ),
    .LDSWn      ( LDSWn         ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL
    .map_data   ( map_data      ),
    .map_addr   ( map_addr      ),
    .map_cs     ( map_cs        ),
    .map_ok     ( map_ok        ),
    .scr_addr   ( scr_addr[18:1]),
    .scr_data   ( scr_data      ),
    .scrposh    ( scrposh       ),
    .scrposv    ( scrposv       ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .obj_AB     ( obj_AB        ),
    .oram_dout  ( oram_dout[11:0] ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_cs     ( obj_cs        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( obj_br        ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    .obj_ok     ( obj_ok        ),
    // PROMs
    .prog_addr   ( prog_addr[7:0]),
    .prom_prio_we( prom_prio     ),
    .prom_din    ( prog_data[3:0]),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .debug_bus  ( debug_bus     )
);

endmodule
