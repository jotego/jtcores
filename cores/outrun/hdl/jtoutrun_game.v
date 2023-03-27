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
    Date: 10-7-2022 */

module jtoutrun_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam [24:0] KEY_PROM = `JTFRAME_PROM_START,
                  FD_PROM  = `FD1089_START;

`ifndef JTFRAME_CLK48
wire clk48, rst48;
assign clk48 = clk;
assign rst48 = rst;
`endif


// Main CPU RAM access
wire    ram_cs, vram_cs;

// clock enable signals
wire    cpu_cen, cpu_cenb,
        cen_fm,  cen_fm2, cen_snd,
        cen_pcm;

// video signals
wire [ 8:0] vrender, hdump;
wire        hstart, vint;
wire        scr_bad;
wire [ 1:0] obj_cfg;
wire        obj_swap;

// CPU interface
wire        creset;
wire [15:0] main_dout, char_dout, pal_dout, obj_dout;
wire [ 1:0] main_dsn, main_dswn;
wire        main_rnw, sub_br,
            char_cs, scr1_cs, pal_cs, objram_cs;
wire [19:1] full_addr;

// Sub CPU
wire        sio_cs, main_br, sub_rnw,
            sub_ok, road_cs;  // not SDRAM signals
wire [18:1] sub_addr;
wire [ 1:0] sub_dsn;
wire [15:0] sub_dout, road_dout, sub_din; // not SDRAM signals
// Sound CPU
wire [ 7:0] sndmap_din, sndmap_dout;
wire        sndmap_rd, sndmap_wr, sndmap_pbf, snd_rstb, mute;

// PCM
wire        snd_clip;

// Protection
wire        key_we, fd1089_we;
reg         dec_en, dec_type,
            fd1089_en, fd1094_en;
wire [ 7:0] key_data;
wire [12:0] key_addr;

wire        flip, video_en, sound_en, line_intn;

// Cabinet inputs
wire [ 7:0] dipsw_a, dipsw_b;
reg  [ 1:0] game_id;
wire [ 2:0] ctrl_type = status[22:20];

// Status report
wire [7:0] st_video, st_main, st_sub, st_snd;
reg  [7:0] st_mux;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
assign main_dswn            = {2{main_rnw}} | main_dsn;
assign game_led             = snd_clip;
assign debug_view           = st_dout;
assign st_dout              = st_mux;

// SDRAM memory
assign main_addr = full_addr[18:1];
assign gfx_cs    = LVBL || vrender==0 || vrender[8];
assign xram_addr = { ram_cs, main_addr[15]&~ram_cs, main_addr[14:1] }; // RAM is mapped up
assign xram_cs   = ram_cs | vram_cs;
assign xram_din  = main_dout;
assign xram_dsn  = main_dsn;
assign xram_we   = ~main_rnw;
assign subram_addr = sub_addr[14:1];
assign subram_dsn  = sub_dsn;
assign subram_we   = ~sub_rnw;
assign subram_din  = sub_dout;
assign subrom_addr = sub_addr;

assign key_we    = prom_we && prog_addr[21:13]==KEY_PROM[21:13];
assign fd1089_we = prom_we && prog_addr[21: 8]==FD_PROM [21: 8];

`ifdef JTFRAME_LF_BUFFER
    assign game_hdump = hdump;
    assign game_vrender = vrender[7:0];
`endif

initial begin
    fd1089_en = 0;
    fd1094_en = 0;
    dec_type  = 0;
end

always @(posedge clk48) begin
    case( st_addr[7:6] )
        0: st_mux <= st_snd; //st_main;
        1: st_mux <= st_sub;
        2: st_mux <= st_video;
        3: case( st_addr[3:0] )
            0: st_mux <= sndmap_dout;
            1: st_mux <= { 2'd0, obj_cfg, 3'b0, obj_swap };
            2: st_mux <= {obj_cfg, mute, 2'b0, snd_rstb, game_id};
            3: st_mux <= { 3'd0, flip, 3'd0, video_en };
        endcase
    endcase
end

always @(posedge clk) begin
    if( header && prog_we ) begin
        if( prog_addr[3:0]==0 ) begin
            fd1089_en <= prog_data[1];
            dec_type  <= prog_data[0];
            fd1094_en <= prog_data[2];
        end
        if( prog_addr[3:0]==1 ) game_id <= prog_data[1:0];
    end
    dec_en <= fd1089_en | fd1094_en;
end

`ifndef NODEC
jtframe_prom #(.AW(13),.SIMFILE("317-5021.key")) u_key(
    .clk    ( clk             ),
    .cen    ( 1'b1            ),
    // Program
    .wr_addr( prog_addr[12:0] ),
    .we     ( key_we          ),
    .data   ( prog_data       ),
    // Read
    .rd_addr( key_addr        ),
    .q      ( key_data        )
);
`else
    assign key_data = 0;
`endif

jts16_cen #(
`ifdef JTFRAME_SDRAM96
    .CLK96(1)
`else
    .CLK96(0)
`endif
) u_cen(
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .clk24      ( clk24     ),
    .mcu_cen    ( cen_pcm   ), // 8 MHz
    .fm2_cen    ( cen_fm2   ), // 4 MHz
    .fm_cen     ( cen_fm    ),
    .snd_cen    ( cen_snd   ),
    .pcm_cen    (           ),
    .pcm_cenb   (           )
);

`ifndef NOMAIN
jtoutrun_main u_main(
    .rst         ( rst48      ),
    .clk         ( clk48      ),
    .cpu_cen     ( cpu_cen    ),
    .cpu_cenb    ( cpu_cenb   ),
    .pxl_cen     ( pxl_cen    ),
    .LHBL        ( LHBL       ),
    .snd_rstb    ( snd_rstb   ),
    .mute        ( mute       ),
    // Video
    .vint        ( vint       ),
    .line_intn   ( line_intn  ),
    .video_en    ( video_en   ),
    .obj_cfg     ( obj_cfg    ),
    // Video circuitry
    .vram_cs     ( vram_cs    ),
    .char_cs     ( char_cs    ),
    .pal_cs      ( pal_cs     ),
    .objram_cs   ( objram_cs  ),
    .char_dout   ( char_dout  ),
    .pal_dout    ( pal_dout   ),
    .obj_dout    ( obj_dout   ),
    .obj_swap    ( obj_swap   ),
    .flip        ( flip       ),
    // RAM access
    .ram_cs      ( ram_cs     ),
    .ram_data    ( xram_data  ),
    .ram_ok      ( xram_ok    ),
    // CPU bus
    .cpu_dout    ( main_dout  ),
    .dsn         ( main_dsn   ),
    .RnW         ( main_rnw   ),
    .sub_cs      ( sub_br     ),
    .sub_ok      ( sub_ok     ),
    .sub_din     ( sub_din    ),
    .creset      ( creset     ),
    // cabinet I/O
    .ctrl_type   ( ctrl_type  ),
    .joystick1   ( joystick1  ),
    .joystick2   ( joystick2  ),
    .joyana1     ( joyana_l1  ),
    .joyana1b    ( joyana_r1  ),
    .start_button(start_button),
    .coin_input  ( coin_input ),
    .service     ( service    ),
    // ROM access
    .addr        ( full_addr  ),
    .rom_cs      ( main_cs    ),
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
    // Sound communication
    .sndmap_rd   ( sndmap_rd  ),
    .sndmap_wr   ( sndmap_wr  ),
    .sndmap_din  ( sndmap_din ),
    .sndmap_dout ( sndmap_dout),
    .sndmap_pbf  ( sndmap_pbf ),
    .prog_addr   ( prog_addr[12:0] ),
    .prog_data   ( prog_data[ 7:0] ),
    // DIP switches
    .dip_test    ( dip_test   ),
    .dipsw_a     ( dipsw_a    ),
    .dipsw_b     ( dipsw_b    ),
    // Status report
    //.debug_bus   ( debug_bus  ),
    .debug_bus   ( 8'd0  ),
    .st_addr     ( st_addr    ),
    .st_dout     ( st_main    )
);
`else
    assign flip        = 0;
    assign sndmap_dout = 0;
    assign main_cs     = 0;
    assign full_addr   = 0;
    assign obj_swap    = 0;
    assign main_dsn    = 3;
    assign char_cs     = 0;
    assign pal_cs      = 0;
    assign objram_cs   = 0;
    assign ram_cs      = 0;
    assign sub_br      = 0;
    assign vram_cs     = 0;
    assign main_rnw    = 1;
    assign main_dout   = 0;
    assign video_en    = 1;
    assign key_addr    = 0;
    assign st_main     = 0;
    assign obj_cfg     = 0;
    assign snd_rstb    = 0;
    assign mute        = 0;
    assign creset      = 0;
`endif

`ifndef NOSUB
jtoutrun_sub u_sub(
    .rst        ( rst48     ),
    .clk        ( clk48     ),
    .creset     ( creset    ),

    .irqn       ( ~vint     ),    // common with main CPU

    // From main CPU
    .main_A     ( full_addr ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .sub_br     ( sub_br    ), // bus request
    .sub_din    ( sub_din   ),
    .main_dout  ( main_dout ),
    .sub_ok     ( sub_ok    ),
    .road_dout  ( road_dout ),

    // sub CPU bus
    .cpu_dout   ( sub_dout  ),
    .sub_addr   ( sub_addr  ),

    .rom_cs     ( subrom_cs   ),
    .rom_ok     ( subrom_ok   ),
    .rom_data   ( subrom_data ),

    .ram_cs     ( subram_cs   ),
    .ram_ok     ( subram_ok   ),
    .ram_data   ( subram_data ),

    .road_cs    ( road_cs   ),
    .sio_cs     ( sio_cs    ),
    .dsn        ( sub_dsn   ),
    .RnW        ( sub_rnw   ),
    .st_addr    ( st_addr   ),
    .st_dout    ( st_sub    )

);
`else
    assign sub_addr = 0;
    assign sub_dout = 0;
    assign subrom_cs  = 0;
    assign subram_cs  = 0;
    assign road_cs  = 0;
    assign sio_cs   = 0;
    assign sub_dsn  = 3;
    assign sub_rnw  = 1;
    assign sub_din  = 0;
    assign sub_ok   = 1;
    assign st_sub   = 0;
`endif

`ifndef NOSOUND
jtoutrun_snd u_sound(
    .rst        ( rst24     ),
    .clk        ( clk24     ),
    .snd_rstb   ( snd_rstb  ),

    .cen_fm     ( cen_fm    ),   // 4MHz
    .cen_fm2    ( cen_fm2   ),   // 2MHz
    .cen_pcm    ( cen_pcm   ),   // 2MHz
    .game_id    ( game_id   ),

    // options
    .fxlevel    (dip_fxlevel),
    .enable_fm  ( enable_fm ),
    .enable_psg ( enable_psg),
    .mute       ( mute      ),

    // Mapper device 315-5195
    .mapper_rd  ( sndmap_rd ),
    .mapper_wr  ( sndmap_wr ),
    .mapper_din ( sndmap_din),
    .mapper_dout(sndmap_dout),
    .mapper_pbf ( sndmap_pbf),

    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    .pcm_addr   ( pcm_addr  ),
    .pcm_cs     ( pcm_cs    ),
    .pcm_data   ( pcm_data  ),
    .pcm_ok     ( pcm_ok    ),

    // Sound output
    .snd_left   ( snd_left  ),
    .snd_right  ( snd_right ),
    .sample     ( sample    ),
    .peak       ( snd_clip  ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_snd    )
);
`else
    assign snd_cs    = 0;
    assign pcm_cs    = 0;
    assign pcm_addr  = 0;
    assign snd_addr  = 0;
    assign snd_clip  = 0;
    assign sample    = 0;
    assign snd_left  = 0;
    assign snd_right = 0;
    assign sndmap_rd = 0;
    assign sndmap_wr = 0;
    assign st_snd    = 0;
`endif

jtoutrun_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .gfx_en     ( gfx_en    ),

    .video_en   ( video_en  ),
    // CPU interface
    .cpu_addr   ( full_addr[13:1]),
    .sub_addr   ( sub_addr[11:1] ),
    .road_cs    ( road_cs   ),
    .sub_io_cs  ( sio_cs    ),
    .char_cs    ( char_cs   ),
    .pal_cs     ( pal_cs    ),
    .objram_cs  ( objram_cs ),
    .vint       ( vint      ),
    .line_intn  ( line_intn ),
    .dip_pause  ( dip_pause ),

    .cpu_dout   ( main_dout ),
    .main_dswn  ( main_dswn ),
    .sub_dsn    ( sub_dsn   ),
    .sub_rnw    ( sub_rnw   ),
    .sub_dout   ( sub_dout  ),
    .char_dout  ( char_dout ),
    .pal_dout   ( pal_dout  ),
    .obj_dout   ( obj_dout  ),
    .road_dout  ( road_dout ),

    .flip       ( flip      ),
    .ext_flip   ( dip_flip  ),
    .obj_swap   ( obj_swap  ),

    // SDRAM interface
    .char_ok    ( char_ok   ),
    .char_addr  ( char_addr ), // 9 addr + 3 vertical + 2 horizontal = 14 bits
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
`ifdef JTFRAME_LF_BUFFER
    .ln_addr   ( ln_addr        ),
    .ln_data   ( ln_data        ),
    .ln_done   ( ln_done        ),
    .ln_hs     ( ln_hs          ),
    .ln_pxl    ( ln_pxl         ),
    .ln_v      ( ln_v           ),
    .ln_we     ( ln_we          ),
`endif

    // Road ROMs
    .rd0_ok     ( 1'b1       ), // implemented in BRAM
    .rd0_cs     (            ),
    .rd0_addr   ( rd0_addr   ),
    .rd0_data   ( rd0_data   ),

    .rd1_ok     ( 1'b1       ),
    .rd1_cs     (            ),
    .rd1_addr   ( rd1_addr   ),
    .rd1_data   ( rd1_data   ),

    // Video signal
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .vdump      (           ),
    .vrender    ( vrender   ),
    .hstart     ( hstart    ),
    .hdump      ( hdump     ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_addr    ( st_addr   ),
    .st_dout    ( st_video  ),
    .scr_bad    ( scr_bad   ),

    // SD card dumps
    .ioctl_addr ( prog_addr ),
    .ioctl_din  ( ioctl_din ),
    .ioctl_ram  ( ioctl_ram ),
    // Get some random data during start-up for the palette
    .prog_addr  ( prog_addr ),
    .prog_data  ( prog_data ),
    .prog_we    ( prog_we   )
);

endmodule
