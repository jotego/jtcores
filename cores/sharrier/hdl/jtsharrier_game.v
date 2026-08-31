/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-8-2026 */

module jtsharrier_game(
    `include "jtframe_game_ports.inc"
);

wire vint, mcu_we;

localparam [24:0] MCU_PROM = `MCU_START;

wire [23:1] main_addr_cpu;
wire [15:0] main_dout;
wire [ 1:0] main_dsn;
wire        main_rnw, ram_cs, vram_cs_main, char_cs_main, objram_cs_main,
            pal_cs_main, io_cs, subram_cs_main, roadram_cs_main;
wire [15:0] char_dout;
wire [15:1] sub_addr_cpu;
wire [15:0] sub_cpu_dout;
wire [ 1:0] sub_dsn;
wire        sub_rnw, sub_ram_cs, sub_road_cs, sub_rom_cs, sub_rstn, sub_intn;
wire        flip, sound_en, video_en, colscr_en, rowscr_en;
wire        snd_rstn;   // PPI0 port B bit 5, Z80 /RESET (active low)
wire [ 7:0] snd_latch;
wire        snd_ack;
wire        snd_nmin;
wire [ 8:0] vrender, hdump;
wire [13:0] road_romaddr;  // road data-ROM address from the road engine
wire [ 7:0] dipsw_a, dipsw_b, st_main, st_sub, st_video, st_road;
wire        scr_bad;
reg  [ 7:0] st_mux;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
assign vint       = ~LVBL;
assign mcu_we     = prom_we && prog_addr[21:12]==MCU_PROM[21:12];

assign dip_flip   = flip;
assign debug_view = st_dout;
assign st_dout    = st_mux;

// Debug status, st_addr[7:6]: 0/1 main, 2 sub, 3 -> [5:4] tilemap / road /
// scr_bad. Road slots are control/hpos/color0/color1 on st_addr[1:0].
always @(posedge clk) begin
    case( st_addr[7:6] )
        2'd0, 2'd1: st_mux <= st_main;
        2'd2:       st_mux <= st_sub;
        default: case( st_addr[5:4] )
            2'd0: st_mux <= st_video;
            2'd1: st_mux <= st_road;
            2'd2: st_mux <= { 7'd0, scr_bad };
            default: st_mux <= 0;
        endcase
    endcase
end

assign mute       = ~sound_en;

assign main_addr  = main_addr_cpu[17:1];
assign xram_cs    = vram_cs_main;
assign xram_addr  = main_addr_cpu[15:1];
assign xram_we    = ~main_rnw;
assign xram_din   = main_dout;
assign xram_dsn   = main_dsn;

assign objram_addr= main_addr_cpu[11:1];
assign objram_din = main_dout;
assign objram_we  = objram_cs_main & ~main_rnw ? ~main_dsn : 2'b00;

assign pal_addr   = main_addr_cpu[11:1];
assign pal_din    = main_dout;
assign pal_we     = pal_cs_main & ~main_rnw ? ~main_dsn : 2'b00;

assign wram_addr  = main_addr_cpu[13:1];
assign wram_din   = main_dout;
assign wram_we    = ram_cs & ~main_rnw ? ~main_dsn : 2'b00;

assign subram_addr = main_addr_cpu[13:1];
assign subram_din  = main_dout;
assign subram_we   = subram_cs_main & ~main_rnw ? ~main_dsn : 2'b00;
// Road RAM CPU port. The board puts road RAM on the sub bus (sheet 3/6) and
// decodes no ROAD select for the main, so the sub owns this port and the engine
// reads the other. The main's writes are merged in on free cycles anyway: the
// firmware does write 256 words per title/attract transition. The arbiter cannot
// back up -- a 68000 write is ~19 clk against a sub access holding road_cs for
// at most one.
reg  [10:0] mainwr_addr;
reg  [15:0] mainwr_din;
reg  [ 1:0] mainwr_we;
reg         mainwr_pend, main_road_wr_l;

// Qualify on the STROBES, not the chip select: latching on the select's edge
// catches main_dsn inactive and the byte enables latch as 00.
wire [ 1:0] main_road_we = roadram_cs_main & ~main_rnw ? ~main_dsn : 2'b00;
wire        main_road_wr = |main_road_we;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mainwr_addr    <= 0;
        mainwr_din     <= 0;
        mainwr_we      <= 0;
        mainwr_pend    <= 0;
        main_road_wr_l <= 0;
    end else begin
        main_road_wr_l <= main_road_wr;
        if( main_road_wr & ~main_road_wr_l ) begin
            mainwr_addr <= main_addr_cpu[11:1];
            mainwr_din  <= main_dout;
            mainwr_we   <= main_road_we;
            mainwr_pend <= 1;
        end else if( mainwr_pend & ~sub_road_cs ) begin
            mainwr_pend <= 0;      // served on this cycle by the mux below
        end
    end
end

assign roadram_addr= sub_road_cs ? sub_addr_cpu[11:1] : mainwr_addr;
assign roadram_din = sub_road_cs ? sub_cpu_dout       : mainwr_din;
assign roadram_we  = sub_road_cs ? (~sub_rnw ? ~sub_dsn : 2'b00) :
                     mainwr_pend ? mainwr_we : 2'b00;

assign sub_addr    = sub_addr_cpu[13:1];
assign sub_dout    = sub_cpu_dout;
assign subsh_we    = sub_ram_cs  & ~sub_rnw ? ~sub_dsn : 2'b00;

assign subrom_addr = sub_addr_cpu;

assign ioctl_din  = 0;
assign subrom_cs  = sub_rom_cs;
// gfx_cs gates the tile-graphics reads to the visible field
assign gfx_cs     = LVBL || vrender==0 || vrender[8];
assign road_addr  = road_romaddr;

// The tilemap owns the video timing; no separate vtimer here.
jtsharrier_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .video_en   ( video_en      ),
    .colscr_en  ( colscr_en     ),
    .rowscr_en  ( rowscr_en     ),
    .vfix_en    ( vfix_en       ),

    .dip_pause  ( dip_pause     ),
    .char_cs    ( char_cs_main  ),
    .cpu_addr   ( main_addr_cpu[12:1] ),
    .cpu_dout   ( main_dout     ),
    .dsn        ( main_dsn      ),
    .char_dout  ( char_dout     ),

    .flip       ( flip          ),

    .pal_vaddr  ( pal_vaddr     ),
    .pal_vdata  ( pal_vdata     ),

    .rdram_addr ( road_rdaddr   ),
    .rdram_data ( roadram_engine_dout ),
    .rdrom_addr ( road_romaddr  ),
    .rdrom_data ( road_data     ),

    .char_ok    ( char_ok       ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .map1_ok    ( map1_ok       ),
    .map1_addr  ( map1_addr     ),
    .map1_data  ( map1_data     ),
    .scr1_ok    ( scr1_ok       ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .map2_ok    ( map2_ok       ),
    .map2_addr  ( map2_addr     ),
    .map2_data  ( map2_data     ),
    .scr2_ok    ( scr2_ok       ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),

    .objdma_addr( objdma_addr   ),
    .objdma_dout( objdma_dout   ),
    .zoom_addr  ( zoom_addr     ),
    .zoom_data  ( zoom_data     ),
    .obj_ok     ( obj_ok        ),
    .obj_cs     ( obj_cs        ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),

    .HS         ( HS            ),
    .VS         ( VS            ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),

    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    .st_addr    ( st_addr       ),
    .st_dout    ( st_video      ),
    .st_road    ( st_road       ),
    .scr_bad    ( scr_bad       )
);

// Flight-stick conditioning to ADC0/ADC1 (sheet 2/6, IC126/IC125). Each byte must
// be pre-shaped to the window the ROM decodes (68000 dasm 0x5AD0); the raw swing
// pins the stick to a corner. X window 0x20..0xE0, reversed. Y is asymmetric
// about the 0x80 rest -- 0xC0 down, 0x60 up -- hence separate gains. Both axes
// latch once per frame: the MCU scans each twice into different slots.
localparam signed [9:0] AN_LIMIT = 10'sd96;   // 0x80 +/- 0x60 = the 0x20..0xE0 window
localparam signed [9:0] AN_STEP  = 10'sd4;    // matches MAME PORT_KEYDELTA(4)

// The digital d-pad becomes a sprung analog offset summed into the stick, so a
// pad and an analog stick both work. Hold to ramp toward full deflection at
// AN_STEP per frame, springing back on release as the cabinet's stick does --
// the game treats stick position as an ABSOLUTE screen position. Ticked on
// vblank, so the ramp is 60 Hz regardless of clock.
wire sprung   = dipsw[29];
// 'V' glyph fix (dipsw[30]): the MRA lists "On,Off" so the all-ones default
// ships faithful to the PCB.
wire vfix_en  = ~dipsw[30];
wire dp_up    = ~joystick1[3];
wire dp_down  = ~joystick1[2];
wire dp_left  = ~joystick1[1];
wire dp_right = ~joystick1[0];
reg  signed [9:0] dig_x, dig_y;

wire signed [ 9:0] ana_x = { {2{joyana_l1[ 7]}}, joyana_l1[ 7:0] };
wire signed [ 9:0] ana_y = { {2{joyana_l1[15]}}, joyana_l1[15:8] };
wire signed [ 9:0] sum_x = ana_x + dig_x;    // analog stick + digital d-pad offset
wire signed [ 9:0] sum_y = ana_y + dig_y;
wire signed [ 9:0] clp_x = sum_x >  AN_LIMIT ?  AN_LIMIT : (sum_x < -AN_LIMIT ? -AN_LIMIT : sum_x);
wire signed [ 9:0] clp_y = sum_y >  AN_LIMIT ?  AN_LIMIT : (sum_y < -AN_LIMIT ? -AN_LIMIT : sum_y);
// Y invert: the cabinet is an aircraft stick, so Arcade = inverted is faithful.
wire               invert_y = dipsw[28];
wire signed [ 9:0] clp_yf   = invert_y ? -clp_y : clp_y;

// The 171/86 gains are COUPLED to AN_LIMIT(96): 96*171>>8 = 64 (0x80->0xC0) and
// 96*86>>8 = 32 (0x80->0x60). Change AN_LIMIT and both must be recomputed as
// endpoint*256/AN_LIMIT, or full travel stops reaching the window endpoints.
wire        [ 9:0] mag_y    = clp_yf[9] ? -clp_yf : clp_yf;            // 0..96
wire        [17:0] scl_y    = mag_y * (clp_yf[9] ? 18'd171 : 18'd86); // down x171 / up x86
wire        [ 7:0] off_y    = scl_y[15:8];                            // 0..64 / 0..32
wire        [ 7:0] an_x_raw = 8'h80 - clp_x[7:0];                     // PORT_REVERSE
wire        [ 7:0] an_y_raw = clp_yf[9] ? 8'h80 + off_y : 8'h80 - off_y;

reg  [7:0] an_x, an_y;
reg        anl_vbl;
always @(posedge clk) begin
    anl_vbl <= vint;
    if( rst ) begin
        an_x  <= 8'h80;
        an_y  <= 8'h80;                    // neutral is 0x80 on both axes
        dig_x <= 0;
        dig_y <= 0;
    end else if( vint & ~anl_vbl ) begin   // once per frame at vblank (60 Hz tick)
        // X: right = positive. Springs back in Arcade; holds in Console.
        if( dp_right ^ dp_left )
            dig_x <= dp_right ? (dig_x + AN_STEP >  AN_LIMIT ?  AN_LIMIT : dig_x + AN_STEP)
                              : (dig_x - AN_STEP < -AN_LIMIT ? -AN_LIMIT : dig_x - AN_STEP);
        else if( sprung ) begin
            if( dig_x >  AN_STEP ) dig_x <= dig_x - AN_STEP;   // spring back to centre
            else if( dig_x < -AN_STEP ) dig_x <= dig_x + AN_STEP;
            else                        dig_x <= 0;
        end
        // Y: down = positive offset
        if( dp_down ^ dp_up )
            dig_y <= dp_down ? (dig_y + AN_STEP >  AN_LIMIT ?  AN_LIMIT : dig_y + AN_STEP)
                             : (dig_y - AN_STEP < -AN_LIMIT ? -AN_LIMIT : dig_y - AN_STEP);
        else if( sprung ) begin
            if( dig_y >  AN_STEP ) dig_y <= dig_y - AN_STEP;
            else if( dig_y < -AN_STEP ) dig_y <= dig_y + AN_STEP;
            else                        dig_y <= 0;
        end
        // sample-and-hold the shaped axes
        an_x  <= an_x_raw;
        an_y  <= an_y_raw;
    end
end

jtsharrier_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .hdump      ( hdump         ),   // VWAIT slot phase, ISSUES.md 42
    .cpu_cen    (               ),
    .cpu_cenb   (               ),

    .vint       ( vint          ),

    .vram_cs    ( vram_cs_main  ),
    .char_cs    ( char_cs_main  ),
    .objram_cs  ( objram_cs_main),
    .pal_cs     ( pal_cs_main   ),
    .io_cs      ( io_cs         ),
    .vram_data  ( xram_data     ),
    .vram_ok    ( xram_ok       ),
    .char_dout  ( char_dout     ),
    .objram_dout( objram_dout   ),
    .pal_dout   ( pal_dout      ),

    .ram_cs     ( ram_cs        ),
    .ram_dout   ( wram_dout     ),

    .addr       ( main_addr_cpu ),
    .cpu_dout   ( main_dout     ),
    .RnW        ( main_rnw      ),
    .dsn        ( main_dsn      ),

    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),

    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .dip_test   ( dip_test      ),
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
    .service    ( service       ),
    .joystick1  ( joystick1[8:0]),
    .an_x       ( an_x          ),
    .an_y       ( an_y          ),

    .flip       ( flip          ),
    .sound_en   ( sound_en      ),
    .snd_latch  ( snd_latch     ),
    .snd_nmin   ( snd_nmin      ),
    .snd_rstn   ( snd_rstn      ),
    .snd_ack    ( snd_ack       ),
    .video_en   ( video_en      ),
    .colscr_en  ( colscr_en     ),
    .rowscr_en  ( rowscr_en     ),

    .subram_cs  ( subram_cs_main ),
    .roadram_cs ( roadram_cs_main),
    .subram_dout( subram_dout   ),

    .sub_rstn   ( sub_rstn      ),
    .sub_intn   ( sub_intn      ),

    .mcu_cen    ( mcu_cen       ),
    .mcu_we     ( mcu_we        ),
    .prog_addr  ( prog_addr[12:0] ),
    .prog_data  ( prog_data     ),

    .st_addr    ( st_addr       ),
    .st_dout    ( st_main       )
);

jtsharrier_sub u_sub(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .rstn       ( sub_rstn      ),
    .intn       ( sub_intn      ),

    .ram_cs     ( sub_ram_cs    ),
    .ram_dout   ( subsh_dout    ),
    .road_cs    ( sub_road_cs   ),
    .road_dout  ( roadram_dout  ),

    .addr       ( sub_addr_cpu  ),
    .cpu_dout   ( sub_cpu_dout  ),
    .RnW        ( sub_rnw       ),
    .dsn        ( sub_dsn       ),

    .rom_cs     ( sub_rom_cs    ),
    .rom_data   ( subrom_data   ),
    .rom_ok     ( subrom_ok     ),

    .st_addr    ( st_addr       ),
    .st_dout    ( st_sub        )
);

// Sound board 834-5799. cen_pcm is 16 MHz, not 8 -- see the module header.
jtsharrier_sound u_snd(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .rstn       ( snd_rstn      ),

    .cen_snd    ( cen_snd       ),
    .cen_fm     ( cen_fm        ),
    .cen_pcm    ( cen_pcm       ),

    .latch      ( snd_latch     ),
    .nmi_n      ( snd_nmin      ),
    .latch_rd   ( snd_ack       ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),

    .fm_snd     ( fm            ),
    .psg_snd    ( psg           ),
    .pcm_l      ( pcm_l         ),
    .pcm_r      ( pcm_r         )
);

endmodule
