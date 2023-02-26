/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-3-2021 */

module jts16_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

`ifndef S16B
    localparam SNDW=15;
    wire [7:0] sndmap_dout=0;

    assign snd_addr[18:16]=0;
`else
    localparam SNDW=19;

    wire [7:0] sndmap_din, sndmap_dout;
    wire       sndmap_rd, sndmap_wr, sndmap_pbf;
`endif

// clock enable signals
wire    cpu_cen, cpu_cenb,
        cen_fm,  cen_fm2, cen_snd,
        cen_pcm, cen_pcmb;

// video signals
wire [ 8:0] vrender;
wire        hstart, vint;
wire        colscr_en, rowscr_en;
wire [ 5:0] tile_bank;
wire        scr_bad;

// SDRAM interface
wire        vram_cs, ram_cs;
wire [13:2] pre_char_addr;
wire [17:2] pre_scr1_addr, pre_scr2_addr;
wire [20:1] pre_obj_addr;

// CPU interface
wire [12:1] cpu_addr;
wire [15:0] main_dout, char_dout, pal_dout, obj_dout;
wire [ 1:0] dsn;
wire        UDSWn, LDSWn, main_rnw;
wire        char_cs, scr1_cs, pal_cs, objram_cs;

// Sound CPU
wire [SNDW-1:0] pre_snd_addr;
wire        mc8123_we; // only for S16B2 core
wire        snd_clip;

// PCM
wire        n7751_prom;

// Protection
wire        key_we, fd1089_we;
wire        dec_en, dec_type,
            fd1089_en, fd1094_en, mc8123_en;
wire        mcu_en, mcu_we, mcu_cen;
wire [ 7:0] key_data;
wire [12:0] key_addr, key_mcaddr;

wire [ 7:0] snd_latch;
wire        snd_irqn, snd_ack;

wire        flip, video_en, sound_en;

// Cabinet inputs
wire [ 7:0] dipsw_a, dipsw_b;
wire [ 7:0] game_id;

// Status report
wire [7:0] st_video, st_main;
reg  [7:0] st_mux;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
assign dsn                  = { UDSWn, LDSWn };
assign game_led             = 1;
assign debug_view           = st_dout;
assign st_dout              = st_mux;
assign xram_dsn             = dsn;
assign xram_we              = ~main_rnw;
assign xram_din             = main_dout;

always @(posedge clk) begin
    case( st_addr[7:4] )
        0: st_mux <= st_video;
        1: case( st_addr[3:0] )
                0: st_mux <= sndmap_dout;
                1: st_mux <= {2'd0, tile_bank};
                2: st_mux <= game_id;
                3: st_mux <= { 3'd0, dec_type, mc8123_en, fd1089_en, fd1094_en, dec_en };
            endcase
        2,3: st_mux <= st_main;
    endcase
end

jts16_cen u_cen(
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .clk24      ( clk24     ),
    .mcu_cen    ( mcu_cen   ),
    .fm2_cen    ( cen_fm2   ),
    .fm_cen     ( cen_fm    ),
    .snd_cen    ( cen_snd   ),
    .pcm_cen    ( cen_pcm   ),
    .pcm_cenb   ( cen_pcmb  )
);

`ifndef NOMAIN
`JTS16_MAIN u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_rom    ( clk       ),  // same clock - at least for now
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .game_id    ( game_id   ),
    .LHBL       ( LHBL      ),
    // Video
    .vint       ( vint      ),
    .video_en   ( video_en  ),
    // Video circuitry
    .vram_cs    ( vram_cs   ),
    .char_cs    ( char_cs   ),
    .pal_cs     ( pal_cs    ),
    .objram_cs  ( objram_cs ),
    .char_dout  ( char_dout ),
    .pal_dout   ( pal_dout  ),
    .obj_dout   ( obj_dout  ),

    .flip       ( flip      ),
    .colscr_en  ( colscr_en ),
    .rowscr_en  ( rowscr_en ),
    // RAM access
    .ram_cs     ( ram_cs    ),
    .ram_data   ( xram_data ),
    .ram_ok     ( xram_ok   ),
    // CPU bus
    .cpu_dout   ( main_dout ),
    .UDSWn      ( UDSWn     ),
    .LDSWn      ( LDSWn     ),
    .RnW        ( main_rnw  ),
    .cpu_addr   ( cpu_addr  ),
    // cabinet I/O
    .joystick1   ( joystick1  ),
    .joystick2   ( joystick2  ),
    .joystick3   ( joystick3  ),
    .joystick4   ( joystick4  ),
    .joyana1     ( joyana_l1  ),
    .joyana1b    ( joyana_r1  ),
    .joyana2     ( joyana_l2  ),
    .joyana2b    ( joyana_r2  ),
    .joyana3     ( joyana_l3  ),
    .joyana4     ( joyana_l4  ),
    .start_button(start_button),
    .coin_input  (coin_input[1:0]),
    .service     ( service    ),
    // ROM access
    .rom_cs      ( main_cs    ),
    .rom_addr    ( main_addr  ),
    .rom_data    ( main_data  ),
    .rom_ok      ( main_ok    ),
    // Decoder configuration
    .dec_en      ( dec_en     ),
    .fd1089_en   ( fd1089_en  ),
    .fd1094_en   ( fd1094_en  ),
    .key_we      ( key_we     ),
    .fd1089_we   ( fd1089_we  ),
    .dec_type    ( dec_type   ),
    .key_addr    ( key_addr   ),
    .key_data    ( key_data   ),
    // MCU
    .rst24       ( rst24      ),
    .clk24       ( clk24      ),  // To ease MCU compilation
    .mcu_cen     ( mcu_cen    ),
    .mcu_en      ( mcu_en     ),
    .mcu_prog_we ( mcu_we     ),
`ifndef S16B
    // Sound communication
    .snd_latch   ( snd_latch  ),
    .snd_irqn    ( snd_irqn   ),
    .snd_ack     ( snd_ack    ),
    .sound_en    ( sound_en   ),
`else
    .pxl_cen     ( pxl_cen    ),
    .sndmap_rd   ( sndmap_rd  ),
    .sndmap_wr   ( sndmap_wr  ),
    .sndmap_din  ( sndmap_din ),
    .sndmap_dout (sndmap_dout ),
    .sndmap_pbf  ( sndmap_pbf ),
    .tile_bank   ( tile_bank  ),
`endif
    .prog_addr   ( prog_addr[12:0] ),
    .prog_data   ( prog_data[ 7:0] ),
    // DIP switches
    .dip_test    ( dip_test   ),
    .dipsw_a     ( dipsw_a    ),
    .dipsw_b     ( dipsw_b    ),
    // Status report
    .debug_bus   ( debug_bus  ),
    .st_addr     ( st_addr    ),
    .st_dout     ( st_main    ),
    // NVRAM dump
    .ioctl_din   ( `ifdef JTFRAME_IOCTL_RD ioctl_din `endif ),
    .ioctl_addr  ( prog_addr[16:0] )
);
`else
    assign flip      = 0;
    assign main_addr = 0;
    assign main_cs   = 0;
    assign ram_cs    = 0;
    assign pal_cs    = 0;
    assign vram_cs   = 0;
    assign UDSWn     = 1;
    assign LDSWn     = 1;
    assign main_rnw  = 1;
    assign main_dout = 0;
    assign video_en  = 1;
    assign sound_en  = 0; // active low (?)
    `ifdef S16B
        reg aux_obf = 0;
        reg [7:0] aux_dout=0;
        assign sndmap_dout = aux_dout;
        assign sndmap_pbf  = aux_obf;
        integer framecnt=0, last_fcnt=0;

        always @(negedge LVBL) begin
            framecnt <= framecnt+1;
        end
        always @(negedge LHBL) begin
            last_fcnt <= framecnt;
            aux_obf <= last_fcnt != framecnt && (framecnt==10
                || framecnt==12
                // || framecnt==32
                // || framecnt==72
                // || framecnt==112
            );
            if( framecnt == 11 ) aux_dout <= 8'h4b; //8'h48 Ok; 4c
            //if( framecnt == 31 ) aux_dout <= 8'h42;
            //if( framecnt == 71 ) aux_dout <= 8'h41;
            //if( framecnt ==111 ) aux_dout <= 8'h40;
        end
    `endif
    `ifdef SIMULATION
        reg [7:0] sim_def[0:1];

        initial begin
            $readmemh("tilebank.hex",sim_def);
            $display("Tile bank set to %X",sim_def[0]);
        end
        assign tile_bank = sim_def[0][5:0];
    `endif
`endif

`ifndef NOSOUND
`JTS16_SND u_sound(
    .rst        ( rst24     ),
    .clk        ( clk24     ),

    .cen_fm     ( cen_fm    ),   // 4MHz or 5MHz
    .cen_fm2    ( cen_fm2   ),   // 2MHz
    .cen_pcm    ( cen_pcm   ),   // 6MHz or 640kHz

    .fxlevel    (dip_fxlevel),
    .enable_fm  ( enable_fm ),
    .enable_psg ( enable_psg),

`ifdef S16B
    // System 16B
    .cen_snd    ( cen_snd   ),  // 5MHz
    // .cen_snd    ( mcu_cen   ),  // 8MHz - keeps the tempo in Cotton but it isn't the right value
    .mapper_rd  ( sndmap_rd ),
    .mapper_wr  ( sndmap_wr ),
    .mapper_din ( sndmap_din),
    .mapper_dout(sndmap_dout),
    .mapper_pbf ( sndmap_pbf),
    .game_id    ( game_id   ),
    // MC8123 encoding
    .dec_en     ( mc8123_en ),
    .key_addr   ( key_mcaddr),
    .key_data   ( key_data  ),
`else
    // System 16A
    .cen_pcmb   ( cen_pcmb  ),   // 6MHz
    .sound_en   ( sound_en  ),

    .latch      ( snd_latch ),
    .irqn       ( snd_irqn  ),
    .ack        ( snd_ack   ),
    // MCU PROM
    .prom_we    ( n7751_prom     ),
    .prog_addr  ( prog_addr[9:0] ),
    .prog_data  ( prog_data[7:0] ),

    // ADPCM ROM
    .pcm_addr   ( pcm_addr  ),
    .pcm_cs     ( pcm_cs    ),
    .pcm_data   ( pcm_data  ),
    .pcm_ok     ( pcm_ok    ),
`endif
    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    // Sound output
    .snd        ( snd       ),
    .sample     ( sample    ),
    .peak       ( snd_clip  )
);
`else
    assign snd_cs=0;
    assign sample=0;
    assign snd_addr=0;
    assign snd_ack=1;
    `ifdef SIMULATION
    assign pcm_cs=0;
    assign pcm_addr=0;
    `endif
`endif

`ifdef S16B
assign pcm_cs   = 0;
assign pcm_addr = 0;
`else
assign tile_bank = 0; // unused on S16A
`endif

jts16_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .gfx_en     ( gfx_en    ),

    .video_en   ( video_en  ),
    .game_id    ( game_id   ),
    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .char_cs    ( char_cs   ),
    .pal_cs     ( pal_cs    ),
    .objram_cs  ( objram_cs ),
    .vint       ( vint      ),
    .dip_pause  ( dip_pause ),

    .cpu_dout   ( main_dout ),
    .dsn        ( dsn       ),
    .char_dout  ( char_dout ),
    .pal_dout   ( pal_dout  ),
    .obj_dout   ( obj_dout  ),

    .flip       ( flip      ),
    .ext_flip   ( dip_flip  ),
    .colscr_en  ( colscr_en ),
    .rowscr_en  ( rowscr_en ),

    // SDRAM interface
    .char_ok    ( char_ok   ),
    .char_addr  ( pre_char_addr ), // 9 addr + 3 vertical + 2 horizontal = 14 bits
    .char_data  ( char_data ),

    .map1_ok    ( map1_ok   ),
    .map1_addr  ( map1_addr ),
    .map1_data  ( map1_data ),

    .scr1_ok    ( scr1_ok   ),
    .scr1_addr  ( pre_scr1_addr ),
    .scr1_data  ( scr1_data ),

    .map2_ok    ( map2_ok   ),
    .map2_addr  ( map2_addr ),
    .map2_data  ( map2_data ),

    .scr2_ok    ( scr2_ok   ),
    .scr2_addr  ( pre_scr2_addr ),
    .scr2_data  ( scr2_data ),

    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( pre_obj_addr  ),
    .obj_data   ( obj_data  ),

    // Video signal
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .vdump      (           ),
    .vrender    ( vrender   ),
    .hstart     ( hstart    ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_addr    ( st_addr   ),
    .st_dout    ( st_video  ),
    .scr_bad    ( scr_bad   )
);

jts16_mem u_mem(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .vrender    ( vrender   ),
    .LVBL       ( LVBL      ),
    .game_id    ( game_id   ),
    .tile_bank  ( tile_bank ),
    .gfx_cs     ( gfx_cs    ),
    .n7751_prom ( n7751_prom),

    .dec_en     ( dec_en    ),
    .fd1089_en  ( fd1089_en ),
    .fd1094_en  ( fd1094_en ),
    .mc8123_en  ( mc8123_en ),
    .dec_type   ( dec_type  ),
    .key_we     ( key_we    ),
    .fd1089_we  ( fd1089_we ),
    .key_addr   ( key_addr  ),
    .key_mcaddr ( key_mcaddr),
    .key_data   ( key_data  ),

    // i8751 MCU
    .mcu_we     ( mcu_we    ),
    .mcu_en     ( mcu_en    ),

    // Main CPU
    .main_cs    ( main_cs   ),
    .vram_cs    ( vram_cs   ),
    .ram_cs     ( ram_cs    ),
    .main_addr  ( main_addr ),
    .xram_cs    ( xram_cs   ),
    .xram_addr  ( xram_addr ),

    // Sound CPU
    .mc8123_we  ( mc8123_we ),

    // video addresses before gating and banking
    .char_addr  ( pre_char_addr ), // 9 addr + 3 vertical + 2 horizontal = 14 bits
    .scr1_addr  ( pre_scr1_addr ),
    .scr2_addr  ( pre_scr2_addr ),
    .obj_addr   ( pre_obj_addr  ),

    // and after:
    .char_adj   ( char_addr  ),
    .scr1_adj   ( scr1_addr  ),
    .scr2_adj   ( scr2_addr  ),
    .obj_addr_g ( obj_addr   ),

    .prog_addr  ( prog_addr  ),
    .prog_data  ( prog_data  ),
    .prog_we    ( prog_we    ),
    .prom_we    ( prom_we    ),
    .header     ( header     )
);

endmodule
