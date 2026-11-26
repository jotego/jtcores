/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-11-2026 */

module jtshdfrc_game(
    `include "jtframe_game_ports.inc"
);

localparam [1:0] SPR_IDLE=0, SPR_CPU=1, SPR_DMA=2;

reg  [ 1:0] spr_owner;
wire        spr_copy_busy, spr_copy_ok;
wire        spr_cpu_cs, spr_cpu_we, spr_cpu_ok, spr_cpu_hold;
wire [12:1] spr_rd_addr;
wire [13:1] bg_addr;
wire [15:0] bg_data;
reg         bg_bank;
wire [14:1] pal_rd_addr;
wire [15:0] pal_rd_data, pal_dout;
wire [ 1:0] pal_we;
wire [13:0] pal_cpu_map = palette_map(main_addr[14:1]);
wire [13:0] pal_vid_map = palette_map(pal_rd_addr);
reg         pal_char_rd_sel;
wire [ 8:0] scrx0, scry0, scrx1, scry1, vpos;
wire        flip, video_en, line_start, snd_on;
wire [ 7:0] brt, snd_latch;

assign dip_flip   = flip;
assign debug_view = 8'd0;
`ifndef JTFRAME_RELEASE
assign ioctl_din  = 8'd0;
`endif

assign bg0_rd_addr = bg_addr[11:1];
assign bg1_rd_addr = bg_addr[10:1];
assign bg_data     = bg_bank ? bg1_rd_data : bg0_rd_data;

always @(posedge clk) bg_bank <= bg_addr[13];

function [13:0] palette_map(input [13:0] index);
    case( index[13:12] )
        2'd0: palette_map = { index[11:10]==0 && index[5:4]==0, 1'b1, 4'd0, index[9:6], index[3:0] };
        2'd1: palette_map = { !index[10] && !index[5], 1'b0, 2'b11, index[11], index[9:6], index[4:0] };
        2'd2: palette_map = { !index[10], 2'b00, index[11], index[9:0] };
        2'd3: palette_map = { index[11:10]==0, 1'b0, 2'b10, index[9:0] };
    endcase
endfunction

assign pal_main_addr    = pal_cpu_map[11:0];
assign pal_char_addr    = pal_cpu_map[ 7:0];
assign pal_main_we      = pal_cpu_map[12] ? 2'b00 : pal_we;
assign pal_char_we      = pal_cpu_map[12] ? pal_we : 2'b00;
assign pal_dout         = pal_cpu_map[12] ? pal_char_dout : pal_main_dout;
assign pal_main_rd_addr = pal_vid_map[11:0];
assign pal_char_rd_addr = pal_vid_map[ 7:0];
assign pal_rd_data      = pal_char_rd_sel ? pal_char_rd_data : pal_main_rd_data;

always @(posedge clk) pal_char_rd_sel <= pal_vid_map[12];

assign spr_cpu_hold = spr_cpu_cs && spr_cpu_we && spr_owner!=SPR_CPU &&
                      spr_copy_busy && main_addr[12:1]>=spr_rd_addr;
assign spr_addr     = spr_owner==SPR_DMA ? spr_rd_addr : main_addr[12:1];
assign spr_cs       = spr_owner==SPR_DMA || (spr_owner==SPR_CPU && spr_cpu_cs);
assign spr_we       = spr_owner==SPR_CPU && spr_cpu_we;
assign spr_dsn      = wram_dsn;
assign spr_cpu_ok   = spr_owner==SPR_CPU && spr_ok;
assign spr_copy_ok  = spr_owner==SPR_DMA && spr_ok;

always @(posedge clk, posedge rst) begin
    if( rst ) spr_owner <= SPR_IDLE;
    else case( spr_owner )
        SPR_IDLE: if( spr_cpu_cs && !spr_cpu_hold ) spr_owner <= SPR_CPU;
                  else if( spr_copy_busy )         spr_owner <= SPR_DMA;
        SPR_CPU:  if( !spr_cpu_cs ) spr_owner <= SPR_IDLE;
        SPR_DMA:  if( spr_ok     ) spr_owner <= SPR_IDLE;
        default:  spr_owner <= SPR_IDLE;
    endcase
end

/* verilator tracing_off */
`ifdef SIMSCENE
assign main_addr = 0, main_cs = 0;
assign ram_din = 0;
assign wram_addr = 0;
assign wram_cs = 0, wram_we = 0, wram_dsn = 2'b11;
assign bg0_we = 0, bg1_we = 0, fg_we = 0, pal_we = 0;
assign spr_cpu_cs = 0, spr_cpu_we = 0;
assign snd_on = 0, snd_latch = 0;

jtshdfrc_scene_mmr #(
    .SIMFILE ( "mmr.bin" )
) u_scene(
    .rst        ( rst      ),
    .clk        ( clk      ),
    .cs         ( 1'b0     ),
    .addr       ( 4'd0     ),
    .rnw        ( 1'b1     ),
    .din        ( 8'd0     ),
    .scrx0      ( scrx0    ),
    .scry0      ( scry0    ),
    .scrx1      ( scrx1    ),
    .scry1      ( scry1    ),
    .flip       ( flip     ),
    .video_en   ( video_en ),
    .brt        ( brt      ),
    .ioctl_addr ( 4'd0     ),
    .ioctl_din  (          ),
    .debug_bus  ( 8'd0     ),
    .st_dout    (          )
);
`else
jtshdfrc_main u_main(
    .rst           ( rst            ),
    .clk           ( clk            ),
    .line_start    ( line_start     ),
    .vpos          ( vpos           ),

    .rom_addr      ( main_addr      ),
    .rom_cs        ( main_cs        ),
    .rom_ok        ( main_ok        ),
    .rom_data      ( main_data      ),

    .ram_din       ( ram_din        ),
    .wram_addr     ( wram_addr      ),
    .wram_cs       ( wram_cs        ),
    .wram_we       ( wram_we        ),
    .wram_dsn      ( wram_dsn       ),
    .wram_ok       ( wram_ok        ),
    .wram_data     ( wram_data      ),
    .bg0_we        ( bg0_we         ),
    .bg1_we        ( bg1_we         ),
    .fg_we         ( fg_we          ),
    .spr_cpu_cs    ( spr_cpu_cs     ),
    .spr_cpu_we    ( spr_cpu_we     ),
    .spr_cpu_ok    ( spr_cpu_ok     ),
    .spr_cpu_hold  ( spr_cpu_hold   ),
    .pal_local     ( pal_cpu_map[13]),
    .pal_we        ( pal_we         ),
    .bg0_q         ( bg0_dout       ),
    .bg1_q         ( bg1_dout       ),
    .fg_q          ( fg_dout        ),
    .spr_q         ( spr_data       ),
    .pal_q         ( pal_dout       ),

    .scrx0         ( scrx0          ),
    .scry0         ( scry0          ),
    .scrx1         ( scrx1          ),
    .scry1         ( scry1          ),
    .flip          ( flip           ),
    .video_en      ( video_en       ),
    .brt           ( brt            ),

    .snd_on        ( snd_on         ),
    .snd_latch     ( snd_latch      ),

    .joystick1     ( joystick1[9:0] ),
    .joystick2     ( joystick2[9:0] ),
    .cab_1p        ( cab_1p[1:0]    ),
    .coin          ( coin[1:0]      ),
    .service       ( service        ),
    .dip_pause     ( dip_pause      ),
    .dipsw         ( dipsw[15:0]    )
);
`endif
/* verilator tracing_on */
jtshdfrc_video u_video(
    .rst           ( rst           ),
    .clk           ( clk           ),
    .pxl_cen       ( pxl_cen       ),

    .line_start    ( line_start    ),
    .vpos          ( vpos          ),

    .bg_addr       ( bg_addr       ),
    .fg_rd_addr    ( fg_rd_addr    ),
    .spr_rd_addr   ( spr_rd_addr   ),
    .pal_rd_addr   ( pal_rd_addr   ),
    .bg_data       ( bg_data       ),
    .fg_rd_data    ( fg_rd_data    ),
    .spr_rd_data   ( spr_data      ),
    .pal_rd_data   ( pal_rd_data   ),
    .spr_copy_busy ( spr_copy_busy ),
    .spr_copy_ok   ( spr_copy_ok   ),

    .scrx0         ( scrx0         ),
    .scry0         ( scry0         ),
    .scrx1         ( scrx1         ),
    .scry1         ( scry1         ),
    .video_en      ( video_en      ),
    .brt           ( brt           ),

    .scr_addr      ( scr_addr      ),
    .scr_cs        ( scr_cs        ),
    .scr_ok        ( scr_ok        ),
    .scr_data      ( scr_data      ),
    .scr2_addr     ( scr2_addr     ),
    .scr2_cs       ( scr2_cs       ),
    .scr2_ok       ( scr2_ok       ),
    .scr2_data     ( scr2_data     ),
    .obj_addr      ( obj_addr      ),
    .obj_cs        ( obj_cs        ),
    .obj_ok        ( obj_ok        ),
    .obj_data      ( obj_data      ),
    .obj4_addr     ( obj4_addr     ),
    .obj4_cs       ( obj4_cs       ),
    .obj4_ok       ( obj4_ok       ),
    .obj4_data     ( obj4_data     ),
    .fgrom_addr    ( fgrom_addr    ),
    .fgrom_cs      ( fgrom_cs      ),
    .fgrom_ok      ( fgrom_ok      ),
    .fgrom_data    ( fgrom_data    ),

    .LHBL          ( LHBL          ),
    .LVBL          ( LVBL          ),
    .HS            ( HS            ),
    .VS            ( VS            ),
    .red           ( red           ),
    .green         ( green         ),
    .blue          ( blue          ),
    .gfx_en        ( gfx_en        )
);
/* verilator tracing_off */
jtshdfrc_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    .cen_oki    ( cen_oki   ),

    .snd_on     ( snd_on    ),
    .snd_latch  ( snd_latch ),

    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    .pcm_addr   ( pcm_addr  ),
    .pcm_cs     ( pcm_cs    ),
    .pcm_data   ( pcm_data  ),
    .pcm_ok     ( pcm_ok    ),

    .fm_l       ( fm_l      ),
    .fm_r       ( fm_r      ),
    .pcm        ( pcm       )
);

endmodule
