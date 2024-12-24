/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 5-12-2020 */

module jtcps1_sdram #( parameter
           CPS     = 1,
           REGSIZE = 24,
           Z80_AW  = CPS==1 ? 16 : 19,
           PCM_AW  = CPS==1 ? 18 : 23
) (
    input           rst,
    input           clk,        // SDRAM clock (48/96)
    input           clk_gfx,    // 96 MHz
    input           clk_cpu,    // 48 MHz
    input           LVBL,

    input           ioctl_rom,
    output          dwnld_busy,
    output          cfg_we,

    // ROM LOAD
    input   [25:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    output  [ 7:0]  ioctl_din,
    input           ioctl_wr,
    input           ioctl_ram,
    output  [22:0]  prog_addr,
    output  [15:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output  [ 1:0]  prog_ba,
    output          prog_we,
    output          prog_rd,
    input           prog_rdy,
    output          prog_qsnd,

    // EEPROM
    input           sclk,
    input           sdi,
    output          sdo,
    input           scs,

    // Kabuki decoder (CPS 1.5)
    output          kabuki_we,

    // CPS2 Keys
    output          cps2_key_we,
    output   [ 1:0] cps2_joymode,

    // Main CPU
    input           main_rom_cs,
    output          main_rom_ok,
    input    [20:0] main_rom_addr,
    output   [15:0] main_rom_data,

    // VRAM
    input           vram_clr,
    input           vram_dma_cs,
    input           main_ram_cs,
    input           main_vram_cs,
    input           main_oram_cs,
    `ifdef CPS2
    input           obank,
    input    [15:0] oram_base,
    input    [12:0] gfx_oram_addr,
    output   [15:0] gfx_oram_data,
    output          gfx_oram_ok,
    input           gfx_oram_clr,
    input           gfx_oram_cs,
    `endif
    input           vram_rfsh_en,

    input    [ 1:0] dsn,
    input    [15:0] main_dout,
    input           main_rnw,

    output          main_ram_ok,
    output          vram_dma_ok,

    input    [17:1] main_ram_addr,
    input    [17:1] vram_dma_addr,

    output   [15:0] main_ram_data,
    output   [15:0] vram_dma_data,

    // Sound CPU and PCM
    input           snd_cs,
    input           pcm_cs,

    output          snd_ok,
    output          pcm_ok,

    input [Z80_AW-1:0] snd_addr,
    input [PCM_AW-1:0] pcm_addr,

    output     [7:0] snd_data,
    output     [7:0] pcm_data,

    // Graphics
    input           rom0_cs,
    input           rom1_cs,

    output reg      rom0_ok, // obj
    output          rom1_ok,

    input    [19:0] rom0_addr,
    input    [ 1:0] rom0_bank,
    input    [19:0] rom1_addr,

    input           rom0_half,
    input           rom1_half,

    output reg [31:0] rom0_data,  // obj
    output     [31:0] rom1_data,

    input             star_bank,
    input     [12:0]  star0_addr,
    output    [31:0]  star0_data,
    output            star0_ok,
    input             star0_cs,

    input     [12:0]  star1_addr,
    output    [31:0]  star1_data,
    output            star1_ok,
    input             star1_cs,

    // Bank 0: allows R/W
    output   [22:0] ba0_addr,
    output   [22:0] ba1_addr,
    output   [22:0] ba2_addr,
    output   [22:0] ba3_addr,
    output   [ 3:0] ba_rd,
    output   [ 3:0] ba_wr,
    output   [15:0] ba0_din,
    output   [ 1:0] ba0_dsn,  // write mask
    input    [ 3:0] ba_ack,
    input    [ 3:0] ba_dst,
    input    [ 3:0] ba_dok,
    input    [ 3:0] ba_rdy,

    input    [15:0] data_read,
    output          dump_flag
);

localparam [22:0] ZERO_OFFSET  = 23'h0,
                  PCM_OFFSET   = ZERO_OFFSET,
                  VRAM_OFFSET  = 23'h20_0000,
                  ORAM_OFFSET  = 23'h28_0000,
                  WRAM_OFFSET  = 23'h30_0000,
                  SND_OFFSET   = 23'h38_0000,
                  ROM_OFFSET   = ZERO_OFFSET;

// Disabling the SDRAM cache latch increases
// object trhoughput
`ifdef MISTER
localparam OBJ_LATCH=0;
`else
// MiST/SiDi struggle with timing with the low latency setting
// So it is disabled. Nonetheless,
// they enjoy a different benefit as the SDRAM has dedicated
// lines for DQMH/L
localparam OBJ_LATCH=1;
`endif

`ifdef CPS2
    localparam [22:0] SCR_OFFSET = 23'h00_0000; // change this when moving to 8MB+ GFX
    localparam        CPS2       = 1;
`else
    localparam [22:0] SCR_OFFSET = ZERO_OFFSET;
    localparam        CPS2       = 0;

    wire [12:0] gfx_oram_addr = 13'd0;
    wire [15:0] gfx_oram_data;
    wire        gfx_oram_ok;
    wire        gfx_oram_clr = 0;
    wire        gfx_oram_cs  = 0;
`endif

`ifdef CPS15
localparam EEPROM_AW=7, EEPROM_DW=8;
`else
localparam EEPROM_AW=6, EEPROM_DW=16;
`endif

(*keep*) wire [22:0] cps2_gfx0;
wire [21:0] gfx1_addr, gfx0_addr;
wire [22:0] main_offset;
wire        ram_vram_cs;
wire        ba2_rdy_gfx, ba2_ack_gfx;
reg  [17:1] main_addr_x; // main addr modified for object bank access
reg         ocache_clr, obank_last;
wire        dump_we;


assign gfx0_addr   = {rom0_addr, rom0_half, 1'b0 }; // OBJ
assign gfx1_addr   = {rom1_addr, rom1_half, 1'b0 };
assign ram_vram_cs = main_ram_cs | main_vram_cs | main_oram_cs;
assign main_offset = main_oram_cs ? ORAM_OFFSET :
                    (main_ram_cs  ? WRAM_OFFSET : VRAM_OFFSET );
assign prog_rd     = 0;
assign dump_we     = ioctl_wr & ioctl_ram;
assign ba_wr[3:1]  = 0;

always @(*) begin
    main_addr_x = main_ram_addr;
    `ifdef CPS2
    if( main_oram_cs ) begin
        main_addr_x[17:14]  = 4'd0;
        main_addr_x[13] = main_ram_addr[15] ^ obank;
    end
    `endif
end

jtcps1_prom_we #(
    .CPS        ( CPS           ),
    .REGSIZE    ( REGSIZE       ),
    .CPU_OFFSET ( ROM_OFFSET    ),
    .PCM_OFFSET ( PCM_OFFSET    ),
    .SND_OFFSET ( SND_OFFSET    )
) u_prom_we(
    .clk            ( clk           ),
    .ioctl_rom      ( ioctl_rom     ),
    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_dout     ( ioctl_dout    ),
    .ioctl_wr       ( ioctl_wr      ),
    .ioctl_ram      ( ioctl_ram     ),
    .prog_addr      ( prog_addr     ),
    .prog_data      ( prog_data     ),
    .prog_mask      ( prog_mask     ),
    .prog_ba        ( prog_ba       ),
    .prog_we        ( prog_we       ),
    .prog_rdy       ( prog_rdy      ),
    .cfg_we         ( cfg_we        ),
    .dwnld_busy     ( dwnld_busy    ),
    // QSound & Kabuki keys
    .prom_we        ( prog_qsnd     ),
    .kabuki_we      ( kabuki_we     ),
    // CPS2
    .cps2_key_we    ( cps2_key_we   ),
    .joymode        ( cps2_joymode  )
);

jtframe_ram1_5slots #(
    .SDRAMW      ( 23            ),
    .ERASE       (  0            ),
    .SLOT0_AW    ( 17            ), // Main CPU RAM
    .SLOT0_DW    ( 16            ),
    .SLOT0_FASTWR(  0            ),

    .SLOT1_AW    ( 17            ), // VRAM - read only access
    .SLOT1_DW    ( 16            ),
    .SLOT1_LATCH (  OBJ_LATCH    ),
    .SLOT1_DOUBLE(  1            ),
    .SLOT1_OFFSET( VRAM_OFFSET   ),

    .SLOT2_AW    ( 13            ), // Object RAM - read only access
    .SLOT2_DW    ( 16            ),
    .SLOT2_LATCH (  OBJ_LATCH    ),
    .SLOT2_DOUBLE(  1            ),
    .SLOT2_OFFSET( ORAM_OFFSET   ),

    .SLOT3_AW    ( 21            ), // Main CPU ROM
    .SLOT3_DW    ( 16            ),
    .SLOT3_LATCH (  1            ),
    .SLOT3_DOUBLE(  1            ),
    .SLOT3_OFFSET(  ROM_OFFSET   ),

    .SLOT4_AW    ( Z80_AW        ), // Sound CPU
    .SLOT4_DW    (  8            ),
    .SLOT4_OFFSET(  SND_OFFSET   )
) u_bank0 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_offset( main_offset   ),
    .slot0_cs    ( ram_vram_cs   ),
    .slot0_wen   ( !main_rnw     ),
    .slot1_cs    ( vram_dma_cs   ),
    .slot1_clr   ( vram_clr      ),
    .slot2_cs    ( gfx_oram_cs   ),
    .slot2_clr   ( gfx_oram_clr  ),
    .slot3_cs    ( main_rom_cs   ),
    .slot3_clr   ( 1'b0          ),
    .slot4_cs    ( snd_cs        ),
    .slot4_clr   ( 1'b0          ),

    .slot0_ok    ( main_ram_ok   ),
    .slot1_ok    ( vram_dma_ok   ),
    .slot2_ok    ( gfx_oram_ok   ),
    .slot3_ok    ( main_rom_ok   ),
    .slot4_ok    ( snd_ok        ),

    .slot0_din   ( main_dout     ),
    .slot0_wrmask( dsn           ),
    .hold_rst    (               ),

    .slot0_addr  ( main_addr_x   ),
    .slot1_addr  ( vram_dma_addr ),
    .slot2_addr  ( gfx_oram_addr ),
    .slot3_addr  ( main_rom_addr ),
    .slot4_addr  ( snd_addr      ),

    .slot0_dout  ( main_ram_data ),
    .slot1_dout  ( vram_dma_data ),
    .slot2_dout  ( gfx_oram_data ),
    .slot3_dout  ( main_rom_data ),
    .slot4_dout  ( snd_data      ),

    // SDRAM interface
    .sdram_addr  ( ba0_addr      ),
    .sdram_rd    ( ba_rd[0]      ),
    .sdram_wr    ( ba_wr[0]      ),
    .sdram_ack   ( ba_ack[0]     ),
    .data_dst    ( ba_dst[0]     ),
    .data_rdy    ( ba_rdy[0]     ),
    .data_write  ( ba0_din       ),
    .sdram_wrmask( ba0_dsn       ),
    .data_read   ( data_read     )
);

jtframe_rom_1slot #(
    .SDRAMW      ( 23            ),
    .SLOT0_AW    ( PCM_AW        ), // PCM
    .SLOT0_DW    (  8            )
) u_bank1 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( pcm_cs        ),
    .slot0_ok    ( pcm_ok        ),
    .slot0_addr  ( pcm_addr      ),
    .slot0_dout  ( pcm_data      ),

    .sdram_addr  ( ba1_addr      ),
    .sdram_rd    ( ba_rd[1]      ),
    .sdram_ack   ( ba_ack[1]     ),
    .data_dst    ( ba_dst[1]     ),
    .data_rdy    ( ba_rdy[1]     ),
    .data_read   ( data_read     )
);

wire [ 1:0] objgfx_cs, objgfx_ok;
wire [31:0] objgfx_dout0, objgfx_dout1;

`ifdef CPS2
    assign objgfx_cs = {2{rom0_cs}} & { rom0_bank[0], ~rom0_bank[0] };
    assign cps2_gfx0 = { rom0_bank[1], gfx0_addr };

    always @(*) begin
        rom0_ok   = rom0_bank[0] ? objgfx_ok[1] : objgfx_ok[0];
        rom0_data = rom0_bank[0] ? objgfx_dout1 : objgfx_dout0;
    end

    jtframe_rom_1slot #(
        .SDRAMW      ( 23            ),
        // Slot 0: Obj
        .SLOT0_AW    ( 23            ),
        .SLOT0_DW    ( 32            ),
        .SLOT0_DOUBLE( 1             ),
        .SLOT0_LATCH ( OBJ_LATCH     )
    ) u_bank2 (
        .rst         ( rst           ),
        .clk         ( clk_gfx       ), // do not use clk

        .slot0_cs    ( objgfx_cs[0]  ),
        .slot0_ok    ( objgfx_ok[0]  ),
        .slot0_addr  ( cps2_gfx0     ),
        .slot0_dout  ( objgfx_dout0  ),

        .sdram_addr  ( ba2_addr      ),
        .sdram_rd    ( ba_rd[2]      ),
        .sdram_ack   ( ba_ack[2]     ),
        .data_dst    ( ba_dst[2]     ),
        .data_rdy    ( ba_rdy[2]     ),
        .data_read   ( data_read     )
    );
`else
    assign objgfx_cs = 2'b10;
    always @(*) begin
        rom0_ok   = objgfx_ok[1];
        rom0_data = objgfx_dout1;
    end
    assign cps2_gfx0 = { 1'b0, gfx0_addr };
    assign ba_rd[2] = 0;
    assign ba2_addr = 0;
`endif

// 7+15=22
wire [21:0] gfx_star0 = { 1'b0, star_bank, 5'd0, star0_addr, 2'b00 },
            gfx_star1 = { 1'b0, star_bank, 5'd0, star1_addr, 2'b10 };

jtframe_rom_4slots #(
    .SDRAMW      ( 23            ),
    // Slot 0: Obj
    .SLOT0_AW    ( 23            ),
    .SLOT0_DW    ( 32            ),
    .SLOT0_OFFSET( ZERO_OFFSET   ),
    .SLOT0_LATCH ( OBJ_LATCH     ),
    .SLOT0_DOUBLE( 1             ),

    // Slot 1: Scroll
    .SLOT1_AW    ( 22            ),
    .SLOT1_DW    ( 32            ),
    .SLOT1_OFFSET( SCR_OFFSET    ),
    .SLOT1_DOUBLE( 1             ),

    // Slot 2: Stars
    .SLOT2_AW    ( 22            ),
    .SLOT2_DW    ( 32            ),
    .SLOT2_OFFSET( SCR_OFFSET    ),

    // Slot 3: Stars
    .SLOT3_AW    ( 22            ),
    .SLOT3_DW    ( 32            ),
    .SLOT3_OFFSET( SCR_OFFSET    )
) u_bank3 (
    .rst         ( rst           ),
    .clk         ( clk_gfx       ), // do not use clk

    .slot0_cs    ( objgfx_cs[1]  ),
    .slot1_cs    ( rom1_cs       ),

    .slot0_ok    ( objgfx_ok[1]  ),
    .slot1_ok    ( rom1_ok       ),

    .slot0_addr  ( cps2_gfx0     ),
    .slot1_addr  ( gfx1_addr     ),

    .slot0_dout  ( objgfx_dout1  ),
    .slot1_dout  ( rom1_data     ),

    // stars
    .slot2_cs    ( star0_cs      ),
    .slot3_cs    ( star1_cs      ),
    .slot2_ok    ( star0_ok      ),
    .slot3_ok    ( star1_ok      ),
    .slot2_addr  ( gfx_star0     ),
    .slot3_addr  ( gfx_star1     ),
    .slot2_dout  ( star0_data    ),
    .slot3_dout  ( star1_data    ),

    .sdram_addr  ( ba3_addr      ),
    .sdram_rd    ( ba_rd[3]      ),
    .sdram_ack   ( ba_ack[3]     ),
    .data_dst    ( ba_dst[3]     ),
    .data_rdy    ( ba_rdy[3]     ),
    .data_read   ( data_read     )
);

// EEPROM used by Pang 3 and by CPS1.5/2
jt9346_16b8b #(.DW(EEPROM_DW),.AW(EEPROM_AW)) u_eeprom(
    .rst        ( rst       ),  // system reset
    .clk        ( clk       ),  // system clock
    // chip interface
    .sclk       ( sclk      ),  // serial clock
    .sdi        ( sdi       ),  // serial data in
    .sdo        ( sdo       ),  // serial data out and ready/not busy signal
    .scs        ( scs       ),  // chip select, active high. Goes low in between instructions
    // Dump access
    .dump_clk   ( clk       ),  // same as prom_we module
    .dump_addr  ( ioctl_addr[(EEPROM_DW==16?EEPROM_AW+1:EEPROM_AW):0] ),
    .dump_we    ( dump_we   ),
    .dump_din   ( ioctl_dout),
    .dump_dout  ( ioctl_din ),
    .dump_flag  ( dump_flag ),
    .dump_clr   ( ioctl_ram )
);

endmodule