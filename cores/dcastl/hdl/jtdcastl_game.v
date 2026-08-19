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

    Author: aCORES
    Version: 1.0
    Date: 18-8-2026 */

module jtdcastl_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam PCB_FIDELITY     = 1'b1; // watchdog + sprite-CPU/CF37201 real timing
localparam PCB_AUDIO_FILTER = 1'b1; // AC-coupled 8302 output stage model
localparam PCB_FRAMEBUFFER  = 1'b0; // CF37201 alternate renderer: OFF (see V4)
localparam PCB_CURSOR_IRQ   = 1'b0; // CRTC CURSOR-sourced IRQ research mode: OFF

wire pause = ~dip_pause;

reg  [7:0] game_id;
reg        game_id_ok;

always @(posedge clk) begin
    if( rst ) begin
        game_id    <= 8'h00;
        game_id_ok <= 0;
    end else if( header && prog_we && prog_addr[2:0]==3'd0 ) begin
        game_id    <= prog_data;
        game_id_ok <= 1;
    end
end

wire       profile_valid, low_pen_priority, soccer_sprites,
           has_adpcm, has_joys2, native_vertical;
wire [1:0] profile;

jtdcastl_profile u_profile(
    .game_id            ( game_id           ),
    .valid              ( profile_valid     ),
    .profile            ( profile           ),
    .low_pen_priority   ( low_pen_priority  ),
    .soccer_sprites     ( soccer_sprites    ),
    .has_adpcm          ( has_adpcm         ),
    .has_joys2          ( has_joys2         ),
    .native_vertical    ( native_vertical   )
);

wire        watchdog_kick;
reg  [23:0] watchdog_count;
reg         watchdog_reset;
wire        base_reset        = rst | ~profile_valid | ~game_id_ok;
wire        machine_reset_raw = base_reset | watchdog_reset;
wire        machine_reset;

jtframe_rst_sync u_rst_sync(
    .rst        ( machine_reset_raw ),
    .clk        ( clk               ),
    .rst_sync   ( machine_reset     )
);

always @(posedge clk) begin
    watchdog_reset <= 0;
    if( base_reset || pause || !PCB_FIDELITY || watchdog_kick )
        watchdog_count <= 0;
    else if( cen_cpu ) begin
        if( watchdog_count >= 24'd11999999 ) begin
            watchdog_count <= 0;
            watchdog_reset <= 1;
        end else watchdog_count <= watchdog_count + 1'd1;
    end
end

wire [7:0] standard_joys = { joystick2[2], joystick2[1], joystick2[3], joystick2[0],
                             joystick1[2], joystick1[1], joystick1[3], joystick1[0] };
wire [7:0] game_buttons  = { cab_1p[1], 1'b1, joystick2[5], joystick2[4],
                             cab_1p[0], 1'b1, joystick1[5], joystick1[4] };
// SYSTEM[5]=COIN1, SYSTEM[4]=COIN2 (MAME's input table). Bits 2/1 mapping is
// open item I2.
wire [7:0] game_system   = { 2'b11, coin[0], coin[1], 1'b1, service, dip_test, 1'b1 };

// Active-high copies for the Soccer OR-combination below, which the source
// core performed on active-high signals before one final inversion.
wire p1_right =~joystick1[0], p1_left=~joystick1[1],
     p1_down  =~joystick1[2], p1_up  =~joystick1[3];
wire p2_right =~joystick2[0], p2_left=~joystick2[1],
     p2_down  =~joystick2[2], p2_up  =~joystick2[3];

wire p1_r_right=~joystick3[0], p1_r_left=~joystick3[1],
     p1_r_down =~joystick3[2], p1_r_up  =~joystick3[3];
wire p2_r_right=~joystick4[0], p2_r_left=~joystick4[1],
     p2_r_down =~joystick4[2], p2_r_up  =~joystick4[3];

wire p1_la_right, p1_la_left, p1_la_down, p1_la_up;
wire p2_la_right, p2_la_left, p2_la_down, p2_la_up;
wire p1_ra_right, p1_ra_left, p1_ra_down, p1_ra_up;
wire p2_ra_right, p2_ra_left, p2_ra_down, p2_ra_up;

jtdcastl_analog u_ana_1l(
    .clk    ( clk       ), .reset ( rst       ), .joyana( joyana_l1 ),
    .right  ( p1_la_right ), .left( p1_la_left ),
    .down   ( p1_la_down  ), .up  ( p1_la_up   )
);

jtdcastl_analog u_ana_2l(
    .clk    ( clk       ), .reset ( rst       ), .joyana( joyana_l2 ),
    .right  ( p2_la_right ), .left( p2_la_left ),
    .down   ( p2_la_down  ), .up  ( p2_la_up   )
);

jtdcastl_analog u_ana_1r(
    .clk    ( clk       ), .reset ( rst       ), .joyana( joyana_r1 ),
    .right  ( p1_ra_right ), .left( p1_ra_left ),
    .down   ( p1_ra_down  ), .up  ( p1_ra_up   )
);

jtdcastl_analog u_ana_2r(
    .clk    ( clk       ), .reset ( rst       ), .joyana( joyana_r2 ),
    .right  ( p2_ra_right ), .left( p2_ra_left ),
    .down   ( p2_ra_down  ), .up  ( p2_ra_up   )
);

wire soccer_mode = has_joys2;   // set only by the two Soccer profile IDs

// Left-hand joystick: digital d-pad OR'd with the left analog stick, exactly
// as the source core's soccer_left_joys.
wire [7:0] soccer_left_joys = ~{
    p2_down|p2_la_down, p2_left|p2_la_left, p2_up|p2_la_up, p2_right|p2_la_right,
    p1_down|p1_la_down, p1_left|p1_la_left, p1_up|p1_la_up, p1_right|p1_la_right };

wire [7:0] soccer_right_joys = ~{
    p2_r_down|p2_ra_down, p2_r_left|p2_ra_left, p2_r_up|p2_ra_up, p2_r_right|p2_ra_right,
    p1_r_down|p1_ra_down, p1_r_left|p1_ra_left, p1_r_up|p1_ra_up, p1_r_right|p1_ra_right };

wire [7:0] joys_to_core  = soccer_mode ? soccer_right_joys : standard_joys;
wire [7:0] joys2_to_core = soccer_mode ? soccer_left_joys  : 8'hff;
wire [7:0] dsw1 = dipsw[ 7:0];
wire [7:0] dsw2 = dipsw[15:8];

reg  [7:0] comm_latch;
reg        main_wait;
wire [7:0] main_comm_dout, sub_comm_dout;
wire       main_comm_start, main_comm_write, sub_comm_access, sub_comm_write;

always @(posedge clk) begin
    if( machine_reset ) begin
        comm_latch <= 0;
        main_wait  <= 0;
    end else begin
        if( main_comm_write ) comm_latch <= main_comm_dout;
        if( sub_comm_write  ) comm_latch <= sub_comm_dout;
        if( main_comm_start ) main_wait  <= 1;
        if( sub_comm_access ) main_wait  <= 0;
    end
end

wire [ 8:0] spr_addr;
wire [ 7:0] spr_din;
wire        spr_we;

assign oram_addr = spr_addr;
assign oram_din  = spr_din;
assign oram_we   = spr_we;
wire [ 4:0] crtc_reg;
wire [ 7:0] crtc_data;
wire        crtc_we;
wire        sub_nmi_req, flipscreen;
wire        main_irq_n, sub_irq_req, sprite_nmi_req;
wire [ 8:0] sprite_copy_addr;
wire [ 7:0] sprite_copy_data;
wire        sprite_copy_we;
wire [10:0] cf_addr;
wire [ 7:0] cf_data;
wire        cf_we, cf_irq_req, cf_irq_ack;
wire [ 7:0] cf_dram_addr;
wire [15:0] cf_dram_address;
wire        cf_dram_strobe, cf_dram_column;
wire [ 7:0] cf_dram_y, cf_dram_x;
wire [ 4:0] cf_palette;
wire        cf_flip_x, cf_flip_y, cf_plus_one, cf_serial_invert;
wire        cf_busy, cf_overrun;
wire [ 7:0] cf_reg2;
wire [ 8:0] h_count, v_count;
wire        crtc_cursor, renderer_busy, renderer_overrun;
wire [ 7:0] adpcm_status, adpcm_data_cpu;
wire        adpcm_wr;
wire signed [11:0] adpcm_sound;
wire signed [15:0] psg_audio;
wire [15:0] main_pc, sub_pc, sprite_pc;
wire [ 3:0] psg_ready;
wire        main_m1_n, main_iorq_n, sub_m1_n, sub_iorq_n;
wire [ 3:0] mix_tile_pen;
wire [ 4:0] mix_tile_color;
wire [ 9:0] mix_sprite_pixel;
wire [ 7:0] pal_addr;
wire        adpcm_busy, adpcm_strobe;
wire [17:0] adpcm_nibble;

// Sub-CPU interrupt: set by the CRTC's MA6 edge, cleared on the sub CPU's own
// M1+IORQ acknowledge, as on the board.
reg  sub_irq_n;
wire sub_iack = ~sub_m1_n & ~sub_iorq_n;

always @(posedge clk) begin
    if( machine_reset ) sub_irq_n <= 1;
    else begin
        if( sub_iack    ) sub_irq_n <= 1;
        if( sub_irq_req ) sub_irq_n <= 0;
    end
end

/* verilator tracing_on */
jtdcastl_main u_main(
    .rst            ( machine_reset     ),
    .clk            ( clk               ),
    .ce_cpu         ( cen_cpu           ),
    .pause          ( pause             ),
    .profile        ( profile           ),
    .irq_n          ( main_irq_n        ),
    // ROM -- SDRAM bank 0, bus `main`
    .rom_q          ( main_data         ),
    .rom_addr       ( main_addr         ),
    .rom_cs         ( main_cs           ),
    .rom_ok         ( main_ok           ),
    // sub CPU mailbox
    .comm_latch     ( comm_latch        ),
    .comm_dout      ( main_comm_dout    ),
    .comm_start     ( main_comm_start   ),
    .comm_write     ( main_comm_write   ),
    .comm_wait_n    ( ~main_wait        ),
    // sprite staging latch, read back by the sprite/protection CPU
    .sprite_addr    ( spr_addr          ),
    .sprite_din     ( spr_din           ),
    .sprite_we      ( spr_we            ),
    // tile / colour RAM
    .video_addr     ( vram_addr         ),
    .video_din      ( vram_din          ),
    .video_dout     ( vram_dout         ),
    .video_we       ( vram_we           ),
    .color_addr     ( cram_addr         ),
    .color_din      ( cram_din          ),
    .color_dout     ( cram_dout         ),
    .color_we       ( cram_we           ),
    // ADPCM control port (Soccer profile only)
    .adpcm_status   ( adpcm_status      ),
    .adpcm_wr       ( adpcm_wr          ),
    .adpcm_data     ( adpcm_data_cpu    ),
    // HD6845S register bus
    .crtc_reg       ( crtc_reg          ),
    .crtc_data      ( crtc_data         ),
    .crtc_we        ( crtc_we           ),
    .sub_nmi_req    ( sub_nmi_req       ),
    .watchdog_kick  ( watchdog_kick     ),
    // debug
    .cpu_addr_debug ( main_pc           ),
    .m1_n_debug     ( main_m1_n         ),
    .iorq_n_debug   ( main_iorq_n       )
);

jtdcastl_sub u_sub(
    .clk            ( clk               ),
    .reset          ( machine_reset     ),
    .ce_cpu         ( cen_cpu           ),
    .ce_psg         ( cen_cpu           ),
    .pause          ( pause             ),
    .profile        ( profile           ),
    .irq_n          ( sub_irq_n         ),
    .nmi_req        ( sub_nmi_req       ),
    // ROM -- SDRAM bank 0, bus `sub`
    .rom_q          ( sub_data          ),
    .rom_addr       ( sub_addr          ),
    .rom_cs         ( sub_cs            ),
    .rom_ok         ( sub_ok            ),
    // main CPU mailbox
    .comm_latch     ( comm_latch        ),
    .comm_dout      ( sub_comm_dout     ),
    .comm_access    ( sub_comm_access   ),
    .comm_write     ( sub_comm_write    ),
    // TMS1025 input multiplexer
    .dsw1           ( dsw1              ),
    .dsw2           ( dsw2              ),
    .joys           ( joys_to_core      ),
    .joys2          ( joys2_to_core     ),
    .buttons        ( game_buttons      ),
    .system         ( game_system       ),
    .flipscreen     ( flipscreen        ),
    // audio
    .audio          ( psg_audio         ),
    // debug
    .cpu_addr_debug ( sub_pc            ),
    .m1_n_debug     ( sub_m1_n          ),
    .iorq_n_debug   ( sub_iorq_n        ),
    .psg_ready_debug( psg_ready         )
);

jtdcastl_spritecpu u_spritecpu(
    .clk            ( clk               ),
    .reset          ( machine_reset     ),
    .ce_cpu         ( cen_cpu           ),
    .pause          ( pause             ),
    .pcb_fidelity   ( PCB_FIDELITY      ),
    .nmi_req        ( sprite_nmi_req    ),
    .cf_irq_req     ( cf_irq_req        ),
    // staging latch written by the main CPU
    .main_addr      ( spr_addr          ),
    .main_data      ( spr_din           ),
    .main_we        ( spr_we            ),
    // ROM -- BRAM
    .rom_q          ( spritecpu_data    ),
    .rom_addr       ( spritecpu_addr    ),
    .rom_ok         ( 1'b1              ),
    // first-phase copy (observed only)
    .copy_addr      ( sprite_copy_addr  ),
    .copy_data      ( sprite_copy_data  ),
    .copy_we        ( sprite_copy_we    ),
    // second phase: the CF37201 doorway
    .cf_addr        ( cf_addr           ),
    .cf_data        ( cf_data           ),
    .cf_we          ( cf_we             ),
    .cf_irq_ack     ( cf_irq_ack        ),
    .cpu_addr_debug ( sprite_pc         )
);

/* verilator tracing_off */
jtdcastl_cf37201 u_cf37201(
    .clk            ( clk               ),
    .reset          ( machine_reset     ),
    .ce_mclk        ( cen_mclk          ),
    .bus_we         ( cf_we             ),
    .bus_addr       ( cf_addr[1:0]      ),
    .bus_data       ( cf_data           ),
    .frame_parity   ( v_count[0]        ),
    .irq_ack        ( cf_irq_ack        ),
    .irq_req        ( cf_irq_req        ),
    .dram_addr      ( cf_dram_addr      ),
    .dram_address   ( cf_dram_address   ),
    .dram_strobe    ( cf_dram_strobe    ),
    .dram_column    ( cf_dram_column    ),
    .dram_y         ( cf_dram_y         ),
    .dram_x         ( cf_dram_x         ),
    .palette        ( cf_palette        ),
    .flip_x         ( cf_flip_x         ),
    .flip_y         ( cf_flip_y         ),
    .plus_one       ( cf_plus_one       ),
    .serial_invert  ( cf_serial_invert  ),
    .busy           ( cf_busy           ),
    .overrun        ( cf_overrun        ),
    .reg2_debug     ( cf_reg2           )
);

/* verilator tracing_on */
jtdcastl_video u_video(
    .clk                ( clk               ),
    .reset              ( machine_reset     ),
    .ce_pix             ( pxl_cen           ),
    .cursor_irq_mode    ( PCB_CURSOR_IRQ    ),
    .pcb_framebuffer    ( PCB_FRAMEBUFFER   ),
    .flipscreen         ( flipscreen        ),
    .low_pen_priority   ( low_pen_priority  ),
    .soccer_sprites     ( soccer_sprites    ),
    // CPU-side RAM ports
    .vram_scan_addr     ( vram_scan_addr    ),
    .vram_scan_dout     ( vram_scan_dout    ),
    .cram_scan_addr     ( cram_scan_addr    ),
    .cram_scan_dout     ( cram_scan_dout    ),
    .oram_scan_addr     ( oram_scan_addr    ),
    .oram_scan_dout     ( oram_scan_dout    ),
    // C000-C1FF is the physical 512-byte sprite doorway. C432 is the
    // protection/CF control latch and must never corrupt sprite RAM.
    .pcb_sprite_addr    ( cf_addr[8:0]      ),
    .pcb_sprite_din     ( cf_data           ),
    .pcb_sprite_we      ( cf_we && (cf_addr < 11'h200) ),
    // CF37201 pin-level DRAM interface
    .cf_dram_address    ( cf_dram_address   ),
    .cf_dram_strobe     ( cf_dram_strobe    ),
    .cf_dram_column     ( cf_dram_column    ),
    .cf_dram_y          ( cf_dram_y         ),
    .cf_dram_x          ( cf_dram_x         ),
    .cf_palette         ( cf_palette        ),
    .cf_flip_x          ( cf_flip_x         ),
    .cf_flip_y          ( cf_flip_y         ),
    .cf_plus_one        ( cf_plus_one       ),
    .cf_serial_invert   ( cf_serial_invert  ),
    // graphics ROMs
    .char_addr          ( gfx1_addr         ),
    .char_q             ( gfx1_data         ),
    .sprite_gfx_addr    ( gfx2_addr         ),
    .sprite_gfx_q       ( gfx2_data         ),
    .sprite_gfx_cs      ( gfx2_cs           ),
    .sprite_gfx_ok      ( gfx2_ok           ),
    .prom_addr          (                   ),
    .prom_q             ( cprom_data        ),
    // CRTC register bus
    .crtc_reg           ( crtc_reg          ),
    .crtc_data          ( crtc_data         ),
    .crtc_we            ( crtc_we           ),
    // dead RGB path -- see flagged item V1
    .r                  (                   ),
    .g                  (                   ),
    .b                  (                   ),
    .HS                 ( HS                ),
    .VS                 ( VS                ),
    .LHBL               ( LHBL              ),
    .LVBL               ( LVBL              ),
    // colour-mix taps into jtdcastl_colmix
    .mix_tile_pen       ( mix_tile_pen      ),
    .mix_tile_color     ( mix_tile_color    ),
    .mix_sprite_pixel   ( mix_sprite_pixel  ),
    // interrupts
    .main_irq_n         ( main_irq_n        ),
    .sub_irq_req        ( sub_irq_req       ),
    .sprite_nmi_req     ( sprite_nmi_req    ),
    // debug
    .h_count_debug      ( h_count           ),
    .v_count_debug      ( v_count           ),
    .cursor_debug       ( crtc_cursor       ),
    .renderer_busy_debug( renderer_busy     ),
    .renderer_overrun_debug( renderer_overrun )
);

jtdcastl_colmix u_colmix(
    .rst                ( machine_reset     ),
    .clk                ( clk               ),
    .pxl_cen            ( pxl_cen           ),
    .lvbl               ( LVBL              ),
    .lhbl               ( LHBL              ),
    .low_pen_priority   ( low_pen_priority  ),
    .tile_pen           ( mix_tile_pen      ),
    .tile_color         ( mix_tile_color    ),
    .sprite_pixel       ( mix_sprite_pixel  ),
    .pal_addr           ( pal_addr          ),
    .pal_dout           ( cprom_data        ),
    .red                ( red               ),
    .green              ( green             ),
    .blue               ( blue              ),
    .debug_bus          ( debug_bus         ),
    .gfx_en             ( gfx_en            )
);

// mem.yaml declares cprom with 9 address bits; the decode only produces 8,
// exactly as the source core's `.prom_addr({1'b0,prom_addr})`. See item S5.
assign cprom_addr = { 1'b0, pal_addr };

/* verilator tracing_off */
jtdcastl_adpcm u_adpcm(
    .clk                ( clk               ),
    .reset              ( machine_reset     ),
    .pause              ( pause             ),
    .enabled            ( has_adpcm         ),
    .cen_384k           ( cen_384k          ),
    .control_wr         ( adpcm_wr          ),
    .control_data       ( adpcm_data_cpu    ),
    .status             ( adpcm_status      ),
    .rom_addr           ( adpcm_addr        ),
    .rom_q              ( adpcm_data        ),
    .rom_cs             ( adpcm_cs          ),
    .rom_ok             ( adpcm_ok          ),
    .sound              ( adpcm_sound       ),
    .busy_debug         ( adpcm_busy        ),
    .nibble_pos_debug   ( adpcm_nibble      ),
    .nibble_strobe_debug( adpcm_strobe      )
);

wire signed [17:0] psg_mix      = {{2{psg_audio[15]}}, psg_audio};
wire signed [11:0] adpcm_dac    = { adpcm_sound[11:2], 2'b00 };
wire signed [17:0] adpcm_scaled = $signed(adpcm_dac) * 18'sd13;
wire signed [17:0] adpcm_mix    = adpcm_scaled >>> 2;
wire signed [18:0] full_mix     = {psg_mix[17],psg_mix} + {adpcm_mix[17],adpcm_mix};
reg  signed [15:0] mixed_audio;
wire signed [15:0] filtered_audio;

always @(*) begin
    if     ( full_mix >  19'sd32767 ) mixed_audio =  16'sh7fff;
    else if( full_mix < -19'sd32768 ) mixed_audio = -16'sd32768;
    else                              mixed_audio =  full_mix[15:0];
end

jtdcastl_audio_filter u_audio_filter(
    .clk        ( clk               ),
    .reset      ( machine_reset     ),
    .enable     ( PCB_AUDIO_FILTER  ),
    .cen_48k    ( cen_48k           ),
    .sample_in  ( mixed_audio       ),
    .sample_out ( filtered_audio    )
);

// Pixel clock enables. The board runs the pixel rate at MCLK/2, so both come
// from the same mem.yaml generator entry.
assign pxl2_cen = cen_mclk;
assign pxl_cen  = cen_pxl;

assign snd = (machine_reset || pause) ? 16'sd0 : filtered_audio;

// `sample` strobe. The board has no equivalent; ~48 kHz from a /1000 divider
// off clk. See item C3.
reg [9:0] sample_cnt;
reg       sample_r;

always @(posedge clk) begin
    if( rst ) begin
        sample_cnt <= 0;
        sample_r   <= 0;
    end else begin
        sample_r <= 0;
        if( sample_cnt==10'd999 ) begin
            sample_cnt <= 0;
            sample_r   <= 1;
        end else sample_cnt <= sample_cnt + 1'd1;
    end
end

assign sample = sample_r;

assign dip_flip = flipscreen;   // flagged item V3

reg [7:0] st_mux;

always @(posedge clk) begin
    case( debug_bus[7:6] )
        2'd0: st_mux <= game_id;
        2'd1: st_mux <= { 3'd0, game_id_ok, profile_valid, native_vertical, profile };
        2'd2: st_mux <= { renderer_overrun, renderer_busy, cf_overrun, cf_busy,
                          adpcm_busy, main_wait, watchdog_reset, crtc_cursor };
        2'd3: st_mux <= cf_reg2;
    endcase
end

assign debug_view = st_mux;

// Signals kept for traceability/debug but not consumed by any jtframe port.
wire _unused = &{ 1'b0, oram_dout, main_pc, sub_pc, sprite_pc, psg_ready, main_m1_n,
                  main_iorq_n, sprite_copy_addr, sprite_copy_data,
                  sprite_copy_we, cf_dram_addr, cf_flip_x, cf_flip_y,
                  cf_plus_one, cf_serial_invert, cf_palette, h_count,
                  adpcm_nibble, adpcm_strobe, gfx2_ok, adpcm_ok,
                  joyana_l3, joyana_l4, joyana_r3,
                  joyana_r4, dial_x, dial_y, snd_en, snd_vol, status,
                  dipsw[31:16], dip_fxlevel, tilt, prog_ba, prom_we,
                  ioctl_addr, ioctl_ram, ioctl_cart, rst24, clk24, rst96,
                  clk96, pxl2_cen, cab_1p[3:2], coin[3:2] };

endmodule
