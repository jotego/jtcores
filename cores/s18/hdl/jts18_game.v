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

localparam [24:0] MCU_PROM = `MCU_START,
                  KEY_PROM = `JTFRAME_PROM_START;
localparam VRAMW = 19;

// clock enable signals
wire    cpu_cen, cpu_cenb;

// video signals
wire [ 8:0] vrender;
wire [ 7:0] tile_bank;
wire        flip, vdp_en, vid16_en, sound_en, gray_n, vint;

// SDRAM interface
wire        vram_cs, ram_cs;

// CPU interface
wire [12:1] cpu_addr;
wire [15:0] char_dout, obj_dout, vdp_dout;
wire [ 1:0] dsn, dswn;
wire        UDSn, LDSn, main_rnw, vdp_dtackn;
wire        char_cs, scr1_cs, pal_cs, objram_cs, asn;

// Protection
wire        key_we;
reg         fd1094_en;
wire        mcu_en, mcu_we;
wire [ 7:0] key_data;
wire [12:0] key_addr;

wire [ 7:0] sndmap_din, sndmap_dout;
wire        snd_irqn, snd_ack, sndmap_rd, sndmap_wr, sndmap_pbf;

// Cabinet inputs
wire [ 7:0] game_id;

// Status report
wire [7:0] st_video, st_main;
reg  [7:0] st_mux;

assign dsn        = { UDSn, LDSn };
assign dswn       = {2{main_rnw}} | dsn;
assign debug_view = st_mux;
assign xram_dsn   = dswn;
assign xram_we    = ~main_rnw;
assign xram_din   = main_dout;
assign mcu_we     = prom_we && prog_addr[21:13]==MCU_PROM[21:13];
assign key_we     = prom_we && prog_addr[21:13]==KEY_PROM[21:13];
assign xram_cs    = ram_cs | vram_cs;
assign gfx_cs     = LVBL || vrender==0 || vrender[8];
assign pal_we     = ~dswn & {2{pal_cs}};

always @(posedge clk) begin
    case( st_addr[7:4] )
        0: st_mux <= st_video;
        1: st_mux <= st_main;
        2: case( st_addr[3:0] )
                0: st_mux <= sndmap_dout;
                1: st_mux <= {2'd0, tile_bank};
                2: st_mux <= game_id;
                3: st_mux <= { 6'd0, mcu_en, fd1094_en };
            endcase
        default: st_mux <= 0;
    endcase
end

always @(posedge clk) begin
    if( header && prog_we ) begin
        if( prog_addr[4:0]==5'h11 ) fd1094_en <= prog_data[0];
        if( prog_addr[4:0]==5'h13 ) mcu_en    <= prog_data[0];
        if( prog_addr[4:0]==5'h18 ) game_id   <= prog_data;
    end
end

always @(*) begin
    xram_addr = 0;
    xram_addr[VRAMW-1:1] = { ram_cs, main_addr[VRAMW-2:1] }; // RAM is mapped up
    // Mask RAM address
    if( ram_cs  ) xram_addr[VRAMW-2:14]=0; // only 16kB for RAM
    if( vram_cs ) xram_addr[VRAMW-2:16]=0;
end

/* xxxverilator tracing_off */
jts18_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_rom    ( clk       ),  // same clock - at least for now
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .game_id    ( game_id   ),
    // Video
    .vint       ( vint      ),
    .flip       ( flip      ),
    .gray_n     ( gray_n    ),
    .vdp_en     ( vdp_en    ),
    .vid16_en   ( vid16_en  ),
    .tile_bank  ( tile_bank ),

    // Video memory
    .vram_cs    ( vram_cs   ),
    .char_cs    ( char_cs   ),
    .pal_cs     ( pal_cs    ),
    .objram_cs  ( objram_cs ),
    .char_dout  ( char_dout ),
    .pal_dout   ( pal_dout  ),
    .obj_dout   ( obj_dout  ),
    .vdp_dout   ( vdp_dout  ),
    .vdp_dtackn ( vdp_dtackn),

    // RAM access
    .ram_cs     ( ram_cs    ),
    .ram_data   ( xram_data ),
    .ram_ok     ( xram_ok   ),
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
    .st_addr     ( st_addr    ),
    .st_dout     ( st_main    )
);

/* xxxverilator tracing_off */
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

/* xxxverilator tracing_off */
jts18_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .flip       ( flip      ),
    .ext_flip   ( dip_flip  ),
    .vid16_en   ( vid16_en  ),
    .vdp_en     ( vdp_en    ),
    .gfx_en     ( gfx_en    ),
    .gray_n     ( gray_n    ),
    .tile_bank  ( tile_bank ),

    // .game_id    ( game_id   ),
    // CPU interface
    .addr       ( cpu_addr  ),
    .char_cs    ( char_cs   ),
    .objram_cs  ( objram_cs ),
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
    .st_addr    ( st_addr   ),
    .st_dout    ( st_video  )
);

endmodule
