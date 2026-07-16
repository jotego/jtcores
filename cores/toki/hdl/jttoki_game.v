//Toki MiSTer
//Copyright (C) 2023 Solal Jacob

//This program is free software: you can redistribute it and/or modify
//it under the terms of the GNU General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.

//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.

//You should have received a copy of the GNU General Public License
//along with this program.  If not, see <http://www.gnu.org/licenses/>.

module jttoki_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [10:1] sprite_addr;
wire [15:0] sprite_table_data;
wire [10:1] main_obj_addr;
wire        obj_copy_active, obj_copy_write;
reg         obj_copy_busy, obj_copy_phase, LVBL_l;
reg         obj_copy_half, obj_render_half, objbuf_valid;
reg  [ 1:0] game_id = 2'd0;
reg  [10:1] obj_copy_addr;

assign obj_cpu_addr       = main_obj_addr;
assign objbuf_copy_addr   = {obj_copy_half, obj_copy_addr};
assign objbuf_copy_din    = objsrc_data;
assign objbuf_copy_we     = {2{obj_copy_write}};

`ifdef SIMSCENE
assign obj_copy_active  = 1'b0;
assign obj_copy_write   = 1'b0;
assign objsrc_addr      = sprite_addr;
assign sprite_table_data = objsrc_data;
`else
assign obj_copy_active  = obj_copy_busy;
assign obj_copy_write   = obj_copy_busy & obj_copy_phase;
assign objsrc_addr      = obj_copy_active ? obj_copy_addr : 10'd0;
assign sprite_table_data = obj_data;
`endif

always @(posedge clk) begin
    if (rst) begin
        LVBL_l         <= 1'b0;
        obj_copy_busy  <= 1'b0;
        obj_copy_phase <= 1'b0;
        obj_copy_half  <= 1'b1;
        obj_render_half <= 1'b0;
        objbuf_valid   <= 1'b0;
        obj_copy_addr  <= 10'd0;
    end else begin
        LVBL_l <= LVBL;
        if (LVBL && !LVBL_l && !obj_copy_busy) begin
            if (objbuf_valid) begin
                obj_render_half <= obj_copy_half;
                obj_copy_half   <= ~obj_copy_half;
            end
            objbuf_valid   <= 1'b1;
            obj_copy_busy  <= 1'b1;
            obj_copy_phase <= 1'b0;
            obj_copy_addr  <= 10'd0;
        end else if (obj_copy_busy) begin
            obj_copy_phase <= ~obj_copy_phase;
            if (obj_copy_phase) begin
                if (obj_copy_addr == 10'h3ff)
                    obj_copy_busy <= 1'b0;
                else
                    obj_copy_addr <= obj_copy_addr + 10'd1;
            end
        end
    end
end

assign objrd_addr  = {obj_render_half, sprite_addr};

`ifdef JTFRAME_IOCTL_RD
assign ioctl_din = 8'd0;
`endif

wire  [6:1] scroll_addr;
wire [15:0] scroll_out;

wire [8:0]  scr1_scroll_x;
wire [8:0]  scr1_scroll_y;
wire [8:0]  scr2_scroll_x;
wire [8:0]  scr2_scroll_y;
wire        bg_order;

wire m68k_sound_wr_2;
wire m68k_sound_wr_4;
wire m68k_sound_wr_6;

wire [15:0] m68k_sound_latch_0;
wire [15:0] m68k_sound_latch_1;
wire [15:0] z80_sound_latch_0;
wire [15:0] z80_sound_latch_1;
wire [15:0] z80_sound_latch_2;

assign debug_view = 0;
assign dip_flip   = 0;

always @(posedge clk) begin
    if (header && prog_we && prog_addr[1:0] == 2'd0)
        game_id <= prog_data[1:0];
end

jttoki_main  u_main(
    .rst                ( rst                ),
    .clk                ( clk                ),
    .lvbl               ( LVBL               ),
    .cabal              ( game_id == 2'd1    ),

    // Input
    .start_button       ( cab_1p[1:0]        ),
    .joystick1          ( joystick1          ),
    .joystick2          ( joystick2          ),

    // DIP switches
    .dipsw              ( dipsw              ),
    .dip_pause          ( dip_pause          ),
    .service            ( service            ),

    // 68K rom
    .cpu_rom_addr       ( cpu_rom_addr       ),
    .cpu_rom_cs         ( cpu_rom_cs         ),
    .cpu_rom_ok         ( cpu_rom_ok         ),
    .cpu_rom_data       ( cpu_rom_data       ),

    // Generated palette RAM
    .cpu_dout           ( cpu_dout           ),
    .ram_addr           ( ram_addr           ),
    .ram_we             ( ram_we             ),
    .ram_dout           ( ram_dout           ),
    .pal_cpu_addr       ( pal_cpu_addr       ),
    .pal_we             ( pal_we             ),
    .pal_dout           ( pal_dout           ),
    .vram_cpu_addr      ( vram_cpu_addr      ),
    .vram_we            ( vram_we            ),
    .vram_dout          ( vram_dout          ),
    .scr1_cpu_addr      ( scr1_cpu_addr      ),
    .scr1_we            ( scr1_we            ),
    .scr1_dout          ( scr1_dout          ),
    .scr2_cpu_addr      ( scr2_cpu_addr      ),
    .scr2_we            ( scr2_we            ),
    .scr2_dout          ( scr2_dout          ),
    .obj_cpu_addr       ( main_obj_addr      ),
    .obj_we             ( obj_we             ),
    .obj_dout           ( obj_dout           ),

    //Scroll latch
    .scr1_scroll_x      ( scr1_scroll_x      ),
    .scr1_scroll_y      ( scr1_scroll_y      ),
    .scr2_scroll_x      ( scr2_scroll_x      ),
    .scr2_scroll_y      ( scr2_scroll_y      ),
    .bg_order           ( bg_order           ),

    //Sound latch
    .sound_wr_2         ( m68k_sound_wr_2    ),
    .sound_wr_4         ( m68k_sound_wr_4    ),
    .sound_wr_6         ( m68k_sound_wr_6    ),

    .m68k_sound_latch_0 ( m68k_sound_latch_0 ),
    .m68k_sound_latch_1 ( m68k_sound_latch_1 ),

    //Sound input from z80
    .z80_sound_latch_0  ( z80_sound_latch_0  ),
    .z80_sound_latch_1  ( z80_sound_latch_1  ),
    .z80_sound_latch_2  ( z80_sound_latch_2  )
);

`ifdef SIMSCENE
/* verilator tracing_on */
`endif
jttoki_video u_video(
    .rst           ( rst         ),
    .clk           ( clk         ),
    .pxl_cen       ( pxl_cen     ),
    .pxl2_cen      ( pxl2_cen    ),
    .cabal         ( game_id == 2'd1 ),

    // Video signal
    .hsync         ( HS          ),
    .vsync         ( VS          ),
    .lvbl          ( LVBL        ),
    .lhbl          ( LHBL        ),
    .gfx_en        ( gfx_en      ),

    .red           ( red         ),
    .green         ( green       ),
    .blue          ( blue        ),

    //Shared video RAM
    .pal_addr      ( palrd_addr  ),
    .pal_data      ( pal_data    ),

    .vram_addr     ( vram_addr   ),
    .vram_out      ( vram_out    ),

    .scr1_addr     ( scr1_addr   ),
    .scr1_out      ( scr1_out    ),

    .scr2_addr     ( scr2_addr   ),
    .scr2_out      ( scr2_out    ),

    .sprite_addr   ( sprite_addr ),
    .sprite_out    ( sprite_table_data ),

    //GFX ROM
    .gfx1_data     ( gfx1_data   ),
    .gfx1_ok       ( gfx1_ok     ),
    .gfx1_addr     ( gfx1_addr   ),
    .gfx1_cs       ( gfx1_cs     ),

    .gfx1_hi_data  ( gfx1_hi_data ),
    .gfx1_hi_ok    ( gfx1_hi_ok   ),
    .gfx1_hi_addr  ( gfx1_hi_addr ),
    .gfx1_hi_cs    ( gfx1_hi_cs   ),

    .gfx2_data     ( gfx2_data   ),
    .gfx2_ok       ( gfx2_ok     ),
    .gfx2_addr     ( gfx2_addr   ),
    .gfx2_cs       ( gfx2_cs     ),

    .gfx3_data     ( gfx3_data   ),
    .gfx3_ok       ( gfx3_ok     ),
    .gfx3_addr     ( gfx3_addr   ),
    .gfx3_cs       ( gfx3_cs     ),

    .gfx4_data     ( gfx4_data   ),
    .gfx4_ok       ( gfx4_ok     ),
    .gfx4_addr     ( gfx4_addr   ),
    .gfx4_cs       ( gfx4_cs     ),

    // scroll latch
    .scr1_scroll_x ( scr1_scroll_x ),
    .scr1_scroll_y ( scr1_scroll_y ),
    .scr2_scroll_x ( scr2_scroll_x ),
    .scr2_scroll_y ( scr2_scroll_y ),
    .bg_order      ( bg_order      )
);

`ifndef NOSOUND
jttoki_sound u_sound(
    .rst                ( rst                ),
    .clk                ( clk                ),

    .cabal              ( game_id == 2'd1    ),
    .cen_fm             ( cen_fm             ),
    .cen_fm2            ( cen_fm2            ),
    .msm_cen            ( msm_cen            ),
    .oki_cen            ( oki_cen            ),

    .coin               ( coin[1:0]          ),

    .fm                 ( fm                 ),
    .pcm0               ( pcm0               ),
    .pcm1               ( pcm1               ),

    .rom_addr           ( snd_addr           ),
    .rom_data           ( snd_data           ),
    .rom_ok             ( snd_ok             ),
    .rom_cs             ( snd_cs             ),

    .bank_rom_addr      ( bank_rom_addr      ),
    .bank_rom_data      ( bank_rom_data      ),
    .bank_rom_ok        ( bank_rom_ok        ),
    .bank_rom_cs        ( bank_rom_cs        ),

    .pcm_addr           ( pcm_addr           ),
    .pcm_data           ( pcm_data           ),
    .pcm_ok             ( pcm_ok             ),
    .pcm_cs             ( pcm_cs             ),

    .adpcm1_addr        ( adpcm1_addr        ),
    .adpcm1_data        ( adpcm1_data        ),
    .adpcm1_ok          ( adpcm1_ok          ),
    .adpcm1_cs          ( adpcm1_cs          ),

    .adpcm2_addr        ( adpcm2_addr        ),
    .adpcm2_data        ( adpcm2_data        ),
    .adpcm2_ok          ( adpcm2_ok          ),
    .adpcm2_cs          ( adpcm2_cs          ),

    .m68k_sound_wr_2    ( m68k_sound_wr_2    ),
    .m68k_sound_wr_4    ( m68k_sound_wr_4    ),
    .m68k_sound_wr_6    ( m68k_sound_wr_6    ),

    .m68k_sound_latch_0 ( m68k_sound_latch_0 ),
    .m68k_sound_latch_1 ( m68k_sound_latch_1 ),
    .z80_sound_latch_0  ( z80_sound_latch_0  ),
    .z80_sound_latch_1  ( z80_sound_latch_1  ),
    .z80_sound_latch_2  ( z80_sound_latch_2  )
);
`else
assign fm                 = 16'd0;
assign pcm0               = 14'd0;
assign pcm1               = 14'd0;
assign snd_addr           = 13'd0;
assign snd_cs             = 1'b0;
assign bank_rom_addr      = 16'd0;
assign bank_rom_cs        = 1'b0;
assign pcm_addr           = 17'd0;
assign pcm_cs             = 1'b0;
assign adpcm1_addr        = 16'd0;
assign adpcm1_cs          = 1'b0;
assign adpcm2_addr        = 16'd0;
assign adpcm2_cs          = 1'b0;
assign z80_sound_latch_0  = 16'd0;
assign z80_sound_latch_1  = 16'd0;
assign z80_sound_latch_2  = 16'd0;
`endif

endmodule
