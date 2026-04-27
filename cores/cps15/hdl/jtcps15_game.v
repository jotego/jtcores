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
    Date: 26-9-2020 */

module jtcps15_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        clk_gfx, rst_gfx, hold_rst;
wire        main_ram_cs, main_vram_cs;
wire        HB, VB;
wire        prog_qsnd;
wire [17:1] ram_addr;
wire [15:0] mmr_dout;
wire        ppu1_cs, ppu2_cs, ppu_rstn;
wire [19:0] rom1_addr, rom0_addr;
wire [31:0] rom0_data, rom1_data;
wire        rom0_cs, rom1_cs, rom0_ok, rom1_ok;
wire [15:0] cpu_dout;
wire        cpu_speed;

wire        main_rnw, busreq, busack;
wire [ 7:0] dipsw_a, dipsw_b, dipsw_c;
wire [22:0] qsnd_rom_addr;

wire        vram_clr, vram_rfsh_en;
wire [ 8:0] hdump;
wire [ 8:0] vdump, vrender;

wire        rom0_half, rom1_half;
wire        cfg_we;
wire        charger, video_flip, dump_flag;

// QSound - Decode keys
wire        kabuki_we, kabuki_en;

// M68k - Sound subsystem communication
wire [ 7:0] main2qs_din;
wire [23:1] main2qs_addr;
wire        main2qs_cs, main_busakn, main_waitn;

// EEPROM
wire        sclk, sdi, sdo, scs;

assign { dipsw_c, dipsw_b, dipsw_a } = ~24'd0;
`ifndef JTFRAME_MEMGEN
assign snd_peak = 0;
`endif

wire        cen16, cen12, cen8, cen10b;
wire        cpu_cen, cpu_cenb;
wire        turbo;
reg         rst_game;

`ifndef JTFRAME_MEMGEN
wire [15:0] main_dout;
wire [ 1:0] dsn;
wire        snd_cs, qsnd_cs, main_ram_cs, main_vram_cs, main_rom_cs,
            rom0_cs, rom1_cs,
            vram_dma_cs;
wire [18:0] snd_addr;
wire [ 7:0] snd_data, qsnd_data;
wire [21:1] main_rom_addr;
wire [15:0] main_ram_data, main_rom_data;
wire        main_rom_ok, main_ram_ok;
wire [17:1] vram_dma_addr;
wire [15:0] vram_dma_data;
wire        vram_dma_ok, snd_ok, qsnd_ok;
`endif

`include "turbo.vh"

assign debug_view = 0;

`ifndef JTFRAME_MEMGEN
assign snd_vu     = 0;
assign ba1_din=0, ba2_din=0, ba3_din=0,
       ba1_dsn=3, ba2_dsn=3, ba3_dsn=3;
`endif

// CPU clock enable signals come from 48MHz domain
/* verilator lint_off PINMISSING */
jtframe_cen48 u_cen48(
    .clk        ( clk48         ),
    .cen16      ( cen16         ),
    .cen12      ( cen12         ),
    .cen8       ( cen8          ),
    .cen6       (               ),
    .cen4       (               ),
    .cen4_12    (               ),
    .cen3       (               ),
    .cen3q      (               ),
    .cen1p5     (               ),
    // 180 shifted signals
    .cen12b     (               ),
    .cen6b      (               ),
    .cen3b      (               ),
    .cen3qb     (               ),
    .cen1p5b    (               )
);

assign clk_gfx = clk;
assign rst_gfx = rst;

always @(posedge clk) rst_game <= hold_rst | rst48;

localparam REGSIZE=24,
           START_HEADER=16,
           KABUKI_HEADER=26'd48,
           KABUKI_END=KABUKI_HEADER+26'd11;

`ifdef JTFRAME_MEMGEN
localparam [22:0] SND_OFFSET =23'h38_0000,
                  VRAM_OFFSET=23'h20_0000,
                  WRAM_OFFSET=23'h30_0000;
localparam EEPROM_AW=7, EEPROM_DW=8;
wire dump_we = ioctl_wr & ioctl_ram;
reg  [1:0]  kabuki_sr;
reg  [15:0] snd_start_cfg;
wire [21:0] snd_start_addr = { snd_start_cfg[12:0], 9'd0 };

assign hold_rst   = 1'b0;
assign kabuki_we  = kabuki_sr[0];
assign prog_qsnd  = prom_we;
assign ram_vram_cs = main_ram_cs | main_vram_cs;
assign main_ram_we = !main_rnw;
assign main_offset = main_ram_cs ? WRAM_OFFSET : VRAM_OFFSET;
assign main_addr_x = { 3'd0, ram_addr };
assign qsnd_addr   = qsnd_rom_addr[21:0];
assign gfx0_addr   = { rom0_addr, rom0_half };
assign gfx1_addr   = { rom1_addr, rom1_half };
assign gfx0_cs     = rom0_cs;
assign gfx1_cs     = rom1_cs;
assign rom0_data   = gfx0_data;
assign rom1_data   = gfx1_data;
assign rom0_ok     = gfx0_ok;
assign rom1_ok     = gfx1_ok;
assign cfg_we      = header && ioctl_wr &&
                     ioctl_addr > 7 &&
                     ioctl_addr < (REGSIZE+START_HEADER);

always @(*) begin
    post_addr = prog_addr;
    if( !header && prog_ba==2'd0 && ioctl_addr[25:10] >= snd_start_cfg ) begin
        post_addr = prog_addr - snd_start_addr + SND_OFFSET[21:0];
    end
end

always @(posedge clk) begin
    kabuki_sr <= kabuki_sr >> 1;
    if( header && ioctl_wr ) begin
        if( ioctl_addr == 26'd0 ) begin
            snd_start_cfg[ 7:0] <= prog_data;
            kabuki_sr           <= 2'b0;
        end
        if( ioctl_addr == 26'd1 ) begin
            snd_start_cfg[15:8] <= prog_data;
        end
        if( ioctl_addr >= KABUKI_HEADER &&
            ioctl_addr <  KABUKI_END ) begin
            kabuki_sr <= 2'b11;
        end
    end
end

jt9346_16b8b #(.DW(EEPROM_DW),.AW(EEPROM_AW)) u_eeprom(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sclk       ( sclk      ),
    .sdi        ( sdi       ),
    .sdo        ( sdo       ),
    .scs        ( scs       ),
    .dump_clk   ( clk       ),
    .dump_addr  ( ioctl_addr[7:0] ),
    .dump_we    ( dump_we   ),
    .dump_din   ( ioctl_dout),
    .dump_dout  ( ioctl_din ),
    .dump_flag  ( dump_flag ),
    .dump_clr   ( ioctl_ram )
);
`endif

// Turbo speed disables DMA
wire busreq_cpu = busreq & ~turbo;
wire busack_cpu;
assign busack = busack_cpu | turbo;

`ifndef NOMAIN
jtcps1_main u_main(
    .rst        ( rst_game          ),
    .clk        ( clk48             ),
    .cen10      ( cpu_cen           ),
    .cen10b     ( cpu_cenb          ),
    .cpu_cen    (                   ),
    .turbo      ( 1'b1              ),  // 12MHz CPU
    // Timing
    .V          ( vdump             ),
    .LVBL       ( LVBL              ),
    .LHBL       ( LHBL              ),
    // PPU
    .ppu1_cs    ( ppu1_cs           ),
    .ppu2_cs    ( ppu2_cs           ),
    .ppu_rstn   ( ppu_rstn          ),
    .mmr_dout   ( mmr_dout          ),
    // Sound
    .main2qs_din ( main2qs_din      ),
    .main2qs_addr( main2qs_addr     ),
    .main2qs_cs  ( main2qs_cs       ),
    .main2qs_busakn( main_busakn    ),
    .main2qs_waitn( main_waitn      ),
    .UDSWn      ( dsn[1]            ),
    .LDSWn      ( dsn[0]            ),
    // cabinet I/O
    // Cabinet input
    .charger     ( charger          ),
    .cab_1p      ( cab_1p           ),
    .coin        ( coin             ),
    .joystick1   ( joystick1        ),
    .joystick2   ( joystick2        ),
    .joystick3   ( joystick3        ),
    .joystick4   ( joystick4        ),
    .dial_x      ( 2'd0             ),
    .dial_y      ( 2'd0             ),
    .service     ( service          ),
    .tilt        ( 1'b1             ),
    // BUS sharing
    .busreq      ( busreq_cpu       ),
    .busack      ( busack_cpu       ),
    .RnW         ( main_rnw         ),
    // RAM/VRAM access
    .addr        ( ram_addr         ),
    .cpu_dout    ( main_dout        ),
    .ram_cs      ( main_ram_cs      ),
    .vram_cs     ( main_vram_cs     ),
    .ram_data    ( main_ram_data    ),
    .ram_ok      ( main_ram_ok      ),
    // ROM access
    .rom_cs      ( main_rom_cs      ),
    .rom_addr    ( main_rom_addr    ),
    .rom_data    ( main_rom_data    ),
    .rom_ok      ( main_rom_ok      ),
    // DIP switches
    .dip_pause   ( dip_pause        ),
    .dip_test    ( dip_test         ),
    .dipsw_a     ( dipsw_a          ),
    .dipsw_b     ( dipsw_b          ),
    .dipsw_c     ( dipsw_c          ),
    // EEPROM
    .eeprom_sclk ( sclk             ),
    .eeprom_sdi  ( sdi              ),
    .eeprom_sdo  ( sdo              ),
    .eeprom_scs  ( scs              ),
    // Unused -stuff from CPS1
    .snd_latch0  (                  ),
    .snd_latch1  (                  ),
    .joymode     ( 2'd0             )
);
`else
assign ram_addr = 17'd0;
assign main_ram_cs = 1'b0;
assign main_vram_cs = 1'b0;
assign main_rom_cs = 1'b0;
assign dsn = 2'b11;
assign main_rnw   = 1'b1;
assign sclk       = 0;
assign sdo        = 0;
assign scs        = 0;
assign busack_cpu = 1;
`endif

reg rst_video;
`ifndef JTFRAME_MEMGEN
reg rst_sdram;
`endif

always @(negedge clk_gfx) begin
    rst_video <= rst_gfx;
end

`ifndef JTFRAME_MEMGEN
always @(negedge clk) begin
    rst_sdram <= rst;
end
`endif

assign dip_flip = ~video_flip;

jtcps1_video #(REGSIZE) u_video(
    .rst            ( rst_video     ),
    .clk            ( clk_gfx       ),
    .clk_cpu        ( clk48         ),
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),

    .hdump          ( hdump         ),
    .vdump          ( vdump         ),
    .vrender        ( vrender       ),
    .gfx_en         ( gfx_en        ),
    .cpu_speed      ( cpu_speed     ),
    .charger        ( charger       ),
    .kabuki_en      ( kabuki_en     ),
    .raster         (               ),

    // CPU interface
    .ppu_rstn       ( ppu_rstn      ),
    .ppu1_cs        ( ppu1_cs       ),
    .ppu2_cs        ( ppu2_cs       ),
    .addr           ( ram_addr[12:1]),
    .dsn            ( dsn           ),      // data select, active low
    .cpu_dout       ( main_dout     ),
    .mmr_dout       ( mmr_dout      ),
    // BUS sharing
    .busreq         ( busreq        ),
    .busack         ( busack        ),

    // Video signal
    .HS             ( HS            ),
    .VS             ( VS            ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    .flip           ( video_flip    ),

    // CPS-B Registers
    .cfg_we         ( cfg_we        ),
    .cfg_data       ( prog_data[7:0]),

    // Extra inputs read through the C-Board
    .cab_1p   ( cab_1p  ),
    .coin     ( coin    ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .joystick4      ( joystick4     ),

    // Video RAM interface
    .vram_dma_addr  ( vram_dma_addr ),
    .vram_dma_data  ( vram_dma_data ),
    .vram_dma_ok    ( vram_dma_ok   ),
    .vram_dma_cs    ( vram_dma_cs   ),
    .vram_dma_clr   ( vram_clr      ),
    .vram_rfsh_en   ( vram_rfsh_en  ),

    // GFX ROM interface
    .rom1_addr      ( rom1_addr     ),
    .rom1_half      ( rom1_half     ),
    .rom1_data      ( rom1_data     ),
    .rom1_cs        ( rom1_cs       ),
    .rom1_ok        ( rom1_ok       ),
    .rom0_addr      ( rom0_addr     ),
    .rom0_bank      (               ),
    .rom0_half      ( rom0_half     ),
    .rom0_data      ( rom0_data     ),
    .rom0_cs        ( rom0_cs       ),
    .rom0_ok        ( rom0_ok       ),

    .debug_bus      ( debug_bus     ),
    // unused
    .star_bank      (               ),
    .star0_addr     (               ),
    .star0_data     ( 32'd0         ),
    .star0_cs       (               ),
    .star0_ok       ( 1'd0          ),
    .star1_addr     (               ),
    .star1_data     ( 32'd0         ),
    .star1_cs       (               ),
    .star1_ok       ( 1'd0          ),
    .watch_vram_cs  ( 1'd0          ),
    .watch          (               )
);

`ifndef NOZ80
// Sound CPU cannot be disabled as there is
// interaction between both CPUs at power up
jtcps15_sound u_sound(
    .rst        ( rst               ),
    .clk48      ( clk48             ),
    .clk96      ( clk               ),
    .cen8       ( cen8              ),
    .vol_up     ( 1'b0              ),
    .vol_down   ( 1'b0              ),
    // Decode keys
    .kabuki_we  ( kabuki_we         ),
    .kabuki_en  ( kabuki_en         ),

    // Interface with main CPU
    .main_addr  ( main2qs_addr      ),
    .main_dout  ( main_dout[7:0]    ),
    .main_din   ( main2qs_din       ),
    .main_ldswn ( dsn[0]            ),
    .main_buse_n( ~main2qs_cs       ),
    .main_busakn( main_busakn       ),
    .main_waitn ( main_waitn        ),

    // ROM
    .rom_addr   ( snd_addr          ),
    .rom_cs     ( snd_cs            ),
    .rom_data   ( snd_data          ),
    .rom_ok     ( snd_ok            ),

    // QSound sample ROM
    .qsnd_addr  ( qsnd_rom_addr     ), // max 8 MB.
    .qsnd_cs    ( qsnd_cs           ),
    .qsnd_data  ( qsnd_data         ),
    .qsnd_ok    ( qsnd_ok           ),

    // ROM programming interface
    .prog_addr  ( prog_addr[12:0]   ),
    .prog_data  ( prog_data[7:0]    ),
    .prog_we    ( prog_qsnd         ),

    // Sound output
    .left       ( snd_left          ),
    .right      ( snd_right         ),
    .sample     ( sample            ),
    .volume     (                   )
);
`else
assign snd_cs = 0;
assign snd_addr = 0;
assign qsnd_cs = 0;
assign qsnd_rom_addr = 0;
`ifndef JTFRAME_MEMGEN
assign prog_qsnd = 0;
`endif
`endif

wire nc0, nc1, nc2, nc3, nc4;

`ifndef JTFRAME_MEMGEN
jtcps1_sdram #(.CPS(15), .REGSIZE(REGSIZE)) u_sdram (
    .rst         ( rst_sdram     ),
    .clk         ( clk           ),
    .clk_gfx     ( clk_gfx       ),
    .clk_cpu     ( clk48         ),
    .LVBL        ( LVBL          ),
    .hold_rst    ( hold_rst      ),

    .ioctl_rom   ( ioctl_rom     ),
    .dwnld_busy  ( dwnld_busy    ),
    .cfg_we      ( cfg_we        ),

    // ROM LOAD
    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_dout  ( ioctl_dout    ),
    .ioctl_din   ( ioctl_din     ),
    .ioctl_wr    ( ioctl_wr      ),
    .ioctl_ram   ( ioctl_ram     ),
    .prog_addr   ({nc4,prog_addr}),
    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_ba     ( prog_ba       ),
    .prog_we     ( prog_we       ),
    .prog_rd     ( prog_rd       ),
    .prog_rdy    ( prog_rdy      ),
    .prog_qsnd   ( prog_qsnd     ),
    // Kabuki decoder (CPS 1.5)
    .kabuki_we   ( kabuki_we     ),

    // EEPROM
    .sclk           ( sclk          ),
    .sdi            ( sdi           ),
    .sdo            ( sdo           ),
    .scs            ( scs           ),

    // Main CPU
    .main_rom_cs    ( main_rom_cs   ),
    .main_rom_ok    ( main_rom_ok   ),
    .main_rom_addr  ( main_rom_addr ),
    .main_rom_data  ( main_rom_data ),

    // VRAM
    .vram_clr       ( vram_clr      ),
    .vram_dma_cs    ( vram_dma_cs   ),
    .main_ram_cs    ( main_ram_cs   ),
    .main_vram_cs   ( main_vram_cs  ),
    .vram_rfsh_en   ( vram_rfsh_en  ),

    // Object RAM (CPS2)
    .main_oram_cs   ( 1'b0          ),

    .dsn            ( dsn           ),
    .main_dout      ( main_dout     ),
    .main_rnw       ( main_rnw      ),

    .main_ram_ok    ( main_ram_ok   ),
    .vram_dma_ok    ( vram_dma_ok   ),

    .main_ram_addr  ( ram_addr      ),
    .vram_dma_addr  ( vram_dma_addr ),

    .main_ram_data  ( main_ram_data ),
    .vram_dma_data  ( vram_dma_data ),

    // Sound CPU and PCM
    .snd_cs      ( snd_cs        ),
    .pcm_cs      ( qsnd_cs       ),

    .snd_ok      ( snd_ok        ),
    .pcm_ok      ( qsnd_ok       ),

    .snd_addr    ( snd_addr      ),
    .pcm_addr    ( qsnd_rom_addr ),

    .snd_data    ( snd_data      ),
    .pcm_data    ( qsnd_data     ),

    // Graphics
    .rom0_cs     ( rom0_cs       ),
    .rom1_cs     ( rom1_cs       ),

    .rom0_ok     ( rom0_ok       ),
    .rom1_ok     ( rom1_ok       ),

    .rom0_addr   ( rom0_addr     ),
    .rom1_addr   ( rom1_addr     ),

    .rom0_half   ( rom0_half     ),
    .rom1_half   ( rom1_half     ),

    .rom0_data   ( rom0_data     ),
    .rom1_data   ( rom1_data     ),

    .star0_addr  ( 13'd0         ),
    .star0_data  (               ),
    .star0_ok    (               ),
    .star0_cs    ( 1'b0          ),

    .star1_addr  ( 13'd0         ),
    .star1_data  (               ),
    .star1_ok    (               ),
    .star1_cs    ( 1'b0          ),

    // Bank 0: allows R/W
    .ba0_addr    ( {nc0,ba0_addr}),
    .ba1_addr    ( {nc1,ba1_addr}),
    .ba2_addr    ( {nc2,ba2_addr}),
    .ba3_addr    ( {nc3,ba3_addr}),
    .ba_rd       ( ba_rd         ),
    .ba_wr       ( ba_wr         ),
    .ba_ack      ( ba_ack        ),
    .ba_dst      ( ba_dst        ),
    .ba_dok      ( ba_dok        ),
    .ba_rdy      ( ba_rdy        ),
    .ba0_din     ( ba0_din       ),
    .ba0_dsn     ( ba0_dsn       ),

    .data_read   ( data_read     ),
    // Unused - CPS2
    .rom0_bank    ( 2'd0         ),
    .star_bank    ( 1'd0         ),
    .cps2_key_we  (              ),
    .cps2_joymode (              ),
    .dump_flag    (              )
);
`endif

endmodule
