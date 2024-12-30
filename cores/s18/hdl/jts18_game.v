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
    Date: 25-4-2024 */

module jts18_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam [24:0] MCU_START = `MCU_START;
localparam VRAMW = 18;

// clock enable signals
wire    cpu_cen, cpu_cenb;

// video signals
wire [ 8:0] vrender;
wire [ 7:0] tile_bank;
wire [ 2:0] vdp_prio;
wire        flip, vdp_en, vid16_en, sound_en, gray_n, vint;
wire [ 2:0] crosshairs;
wire [ 8:0] lg1_x, lg2_x;
wire [ 8:0] lg1_y, lg2_y;

// SDRAM interface
wire        vram_cs, ram_cs;

// CPU interface
wire [23:1] cpu_addr;
wire [15:0] char_dout, obj_dout, vdp_dout;
wire [ 1:0] dsn, dswn;
wire        UDSn, LDSn, main_rnw, vdp_dtackn;
wire        char_cs, scr1_cs, pal_cs, objram_cs, bank_cs, asn;

// Protection
wire        key_we, mcu_we;
reg         fd1094_en, mcu_en;
wire [ 7:0] key_data;
wire [12:0] key_addr;
// Cabinet type
reg         cab3; // support for three players

wire [ 7:0] sndmap_din, sndmap_dout;
wire        snd_irqn, snd_ack, sndmap_rd, sndmap_wr, sndmap_pbf;

// Status report
wire [7:0] st_video, st_main;
reg  [7:0] st_mux, game_id;

assign dsn        = { UDSn, LDSn };
assign dswn       = {2{main_rnw}} | dsn;
assign debug_view = st_mux;//{ 5'd0, vdp_prio }; // st_mux;
assign xram_dsn   = dswn;
assign xram_we    = ~main_rnw;
assign xram_din   = main_dout;
assign mcu_we     = prom_we && prog_addr[15:12]>=MCU_START[15:12];
assign key_we     = prom_we && prog_addr[15:12]< MCU_START[15:12];
assign xram_cs    = vram_cs;
assign gfx_cs     = LVBL || vrender==0 || vrender[8];
assign pal_we     = ~dswn & {2{pal_cs}};
assign ioctl_din  = 0;
assign xram_addr  = main_addr[15:1];
// work RAM (non volatile)
assign nvram_addr = 0;
assign nvram_we   = 0;
assign nvram_din  = 0;
assign wram_we    = {2{ram_cs&~main_rnw}} & ~dsn;

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: case( debug_bus[1:0] )
                0: st_mux <= tile_bank;
                1: st_mux <= game_id;
                2: st_mux <= { vid16_en, vdp_en, 4'd0, mcu_en, fd1094_en };
                3: st_mux <= sndmap_dout;
            endcase
        1: st_mux <= st_video;
        2: st_mux <= st_main;
        default: st_mux <= 0;
    endcase

    st_mux <= st_video;
end

always @(posedge clk) begin
    if( header && ioctl_wr ) begin
        if( ioctl_addr[4:0]==5'h11 ) fd1094_en <= ioctl_dout[0];
        if( ioctl_addr[4:0]==5'h13 ) mcu_en    <= ioctl_dout[0];
        if( ioctl_addr[4:0]==5'h14 ) cab3      <= ioctl_dout[0]; // support for three players
        if( ioctl_addr[4:0]==5'h18 ) game_id   <= ioctl_dout;
    end
end

/* verilator tracing_on */
jts18_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_rom    ( clk       ),  // same clock - at least for now
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .game_id    ( game_id   ),
    .cab3       ( cab3      ),
    // Video
    .vint       ( vint      ),
    .flip       ( flip      ),
    .gray_n     ( gray_n    ),
    .vdp_en     ( vdp_en    ),
    .vdp_prio   ( vdp_prio  ),
    .vid16_en   ( vid16_en  ),
    .tile_bank  ( tile_bank ),

    // Video memory
    .bank_cs    ( bank_cs   ),
    .vram_cs    ( vram_cs   ),
    .char_cs    ( char_cs   ),
    .pal_cs     ( pal_cs    ),
    .objram_cs  ( objram_cs ),
    .char_dout  ( char_dout ),
    .pal_dout   ( pal2main_data  ),
    .obj_dout   ( obj_dout  ),
    .vdp_dout   ( vdp_dout  ),
    .vdp_dtackn ( vdp_dtackn),

    // RAM access
    .ram_cs     ( ram_cs    ),
    .ram_data   ( wram_dout ),
    .vram_ok    ( xram_ok   ),
    .vram_data  ( xram_data ),
    // CPU bus
    .cpu_dout   ( main_dout ),
    .UDSn       ( UDSn      ),
    .LDSn       ( LDSn      ),
    .RnW        ( main_rnw  ),
    .ASn        ( asn       ),
    .cpu_addr   ( cpu_addr  ),
    // cabinet I/O
    .joystick1   ( joystick1  ),
    .joystick2   ( joystick2  ),
    .joystick3   ( joystick3  ),
    .lg1_x       ( lg1_x      ),
    .lg1_y       ( lg1_y      ),
    .lg2_x       ( lg2_x      ),
    .lg2_y       ( lg2_y      ),
    .dial_x      ( dial_x     ),
    .dial_y      ( dial_y     ),
    .cab_1p      ( cab_1p[2:0]),
    .coin        (   coin[2:0]),
    .service     ( service    ),
    // ROM access
    .rom_cs      ( main_cs    ),
    .rom_addr    ( main_addr  ),
    .rom_data    ( main_data  ),
    .rom_ok      ( main_ok    ),
    // PROM (FD1094 and MCU)
    .prog_addr   ( prog_addr[12:0] ),
    .prog_data   ( prog_data[ 7:0] ),
    // Decoder configuration
    .fd1094_en   ( fd1094_en  ),
    .key_we      ( key_we     ),
    // MCU
    .rst24       ( rst        ),
    .clk24       ( clk24      ),  // To ease MCU compilation
    .mcu_cen     ( mcu_cen    ),
    .mcu_en      ( mcu_en     ),
    .mcu_prog_we ( mcu_we     ),
    // Sound communication
    .pxl_cen     ( pxl_cen    ),
    .sndmap_rd   ( sndmap_rd  ),
    .sndmap_wr   ( sndmap_wr  ),
    .sndmap_din  ( sndmap_din ),
    .sndmap_dout (sndmap_dout ),
    .sndmap_pbf  ( sndmap_pbf ),
    // DIP switches
    .dip_test    ( dip_test   ),
    .dipsw       ( dipsw[15:0]),
    // Status report
    .debug_bus   ( debug_bus  ),
    .st_addr     ( debug_bus  ),
    .st_dout     ( st_main    )
);

/* verilator tracing_off */
jts18_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_fm     ( cen_fm    ),  //  8 MHz
    .cen_pcm    ( cen_pcm   ),  // 10 MHz

    .mapper_rd  ( sndmap_rd ),
    .mapper_wr  ( sndmap_wr ),
    .mapper_din ( sndmap_din),
    .mapper_dout(sndmap_dout),
    .mapper_pbf ( sndmap_pbf),
    // .game_id    ( game_id   ),
    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    // ADPCM RAM -- read only
    .pcm0_addr  ( pcm_addr  ),
    .pcm0_dout  ( pcm_dout  ),
    // ADPCM RAM -- R/W by sound CPU
    .pcm1_addr  ( pcm1_addr ),
    .pcm1_dout  ( pcm1_dout ),
    .pcm1_din   ( pcm1_din  ),
    .pcm1_we    ( pcm1_we   ),
    // Sound output
    .fm0_l      ( fm0_l     ),
    .fm0_r      ( fm0_r     ),
    .fm1_l      ( fm1_l     ),
    .fm1_r      ( fm1_r     ),
    .pcm        ( pcm       )
);

/* verilator tracing_on */
jts18_video u_video(
    .rst        ( rst       ),
    .clk96      ( clk96     ),
    .clk48      ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_48cen ( pxl2_48cen),
    .pxl_48cen  ( pxl_48cen ),

    .flip       ( flip      ),
    .ext_flip   ( dip_flip  ),
    .vid16_en   ( vid16_en  ),
    .vdp_en     ( vdp_en    ),
    .gfx_en     ( gfx_en    ),
    .vdp_prio   ( vdp_prio  ),
    .gray_n     ( gray_n    ),
    .tile_bank  ( tile_bank ),

    .game_id    ( game_id   ),
    // CPU interface
    .addr       ( cpu_addr  ),
    .char_cs    ( char_cs   ),
    .objram_cs  ( objram_cs ),
    .bank_cs    ( bank_cs   ),
    .vint       ( vint      ),
    .dip_pause  ( dip_pause ),

    .din        ( main_dout ),
    .dsn        ( dsn       ),
    .asn        ( asn       ),
    .rnw        ( main_rnw  ),
    .char_dout  ( char_dout ),
    .obj_dout   ( obj_dout  ),
    .vdp_dout   ( vdp_dout  ),
    .vdp_dtackn ( vdp_dtackn),

    // palette RAM
    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),

    // SDRAM interface
    .char_ok    ( char_ok   ),
    .char_addr  ( char_addr ),
    .char_data  ( char_data ),

    .map1_ok    ( map1_ok   ),
    .map1_addr  ( map1_addr ),
    .map1_data  ( map1_data ),

    .scr1_ok    ( scr1_ok   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),

    .map2_ok    ( map2_ok   ),
    .map2_addr  ( map2_addr ),
    .map2_data  ( map2_data ),

    .scr2_ok    ( scr2_ok   ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data ),

    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    .lightguns  ( crosshairs),

    .joystick1   ( {joystick1[6],joystick1[5]}  ),
    // Video signal
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .vrender    ( vrender   ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_addr    ( debug_bus ),
    .st_dout    ( st_video  )
);

jts18_crosshair crosshair_left (
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .dx         ( mouse_1p[ 7: 0] ),
    .dy         ( mouse_1p[15: 8] ),
    .strobe     ( mouse_strobe[0] ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .x          ( lg1_x     ),
    .y          ( lg1_y     ),
    .crosshair  ( crosshairs[0] )
);

jts18_crosshair crosshair_center (
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .dx         ( mouse_2p[ 7: 0] ),
    .dy         ( mouse_2p[15: 8] ),
    .strobe     ( mouse_strobe[1] ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .x          ( lg2_x     ),
    .y          ( lg2_y     ),
    .crosshair  ( crosshairs[1] )
);

// 2 guns are supported right now
assign crosshairs[2] = 0;

endmodule
