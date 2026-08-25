/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2019 */

module jttora_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [ 8:0] V, H;

wire [13:1] cpu_AB;
wire        char_cs, col_uw, col_lw;
wire        flip;
wire [15:0] char_dout, cpu_dout;
wire        rd, cpu_cen;
wire        char_busy;
// F1 Dream's 8751 runs at 6 MHz while the main 68000 runs at 10 MHz.
reg         mcu_cen_cpu;
reg [2:0]   mcu_cen_phase;

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
    .service    ( service       ),
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);

reg         rst_mcu;
always @(posedge clk) begin
    rst_mcu     <= rst | ~f1dream;
    mcu_cen_cpu <= 1'b0;
    // Restart the fractional divider with the MCU itself.  F1 Dream is
    // selected from the downloaded header, so the global reset may already
    // be inactive when its 8751 is released.
    if( rst || !f1dream ) begin
        mcu_cen_phase <= 3'd0;
    end else if( cpu_cen ) begin
        // Repeat CPU-enable phases 0, 1 and 3 of each five-phase interval:
        // 3/5 of 10 MHz gives the measured 6 MHz 8751 oscillator rate.
        mcu_cen_cpu   <= mcu_cen_phase == 3'd0 ||
                         mcu_cen_phase == 3'd1 ||
                         mcu_cen_phase == 3'd3;
        mcu_cen_phase <= mcu_cen_phase == 3'd4 ? 3'd0 :
                         mcu_cen_phase + 3'd1;
    end
end

jtbiocom_mcu #(.ROMBIN("../../../../rom/f1dream/8751.mcu")) u_mcu(
    .rst        ( rst_mcu         ),
    .clk        ( clk             ),
    .rst_cpu    ( rst             ),
    .clk_rom    ( clk             ),
    .clk_cpu    ( clk             ),
    .cen6a      ( mcu_cen_cpu     ), // 6 MHz, derived from the 10 MHz CPU
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
    .rst            ( rst            ),
    .clk            ( clk            ),
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
