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
    Date: 2-4-2022 */

module jtrastan_sdram(
    input           rst,
    input           clk,

    // Main CPU
    input    [18:1] main_addr,
    output   [15:0] main_data,
    output   [15:0] ram_data,
    input    [ 1:0] main_dsn,
    input    [15:0] main_dout,
    input           main_cs,
    input           main_rnw,
    input           ram_cs,
    input           vram_cs,
    output          main_ok,
    output          ram_ok,

    // Sound
    input         [15:0] snd_addr,
    input                snd_cs,
    output               snd_ok,
    output        [ 7:0] snd_data,

    input         [15:0] pcm_addr,
    input                pcm_cs,
    output               pcm_ok,
    output        [ 7:0] pcm_data,

    // From the scroll layer
    input    [18:0] scr0rom_addr,
    output   [31:0] scr0rom_data,
    input           scr0rom_cs,
    output          scr0rom_ok,

    input    [18:0] scr1rom_addr,
    output   [31:0] scr1rom_data,
    input           scr1rom_cs,
    output          scr1rom_ok,

    // VRAM
    input    [14:0] scr0ram_addr,
    output   [31:0] scr0ram_data,
    input           scr0ram_cs,
    output          scr0ram_ok,

    input    [14:0] scr1ram_addr,
    output   [31:0] scr1ram_data,
    input           scr1ram_cs,
    output          scr1ram_ok,

    input    [18:0] orom_addr,
    output   [31:0] orom_data,
    output          orom_ok,
    input           orom_cs,

    // SDRAM interface
    input           ioctl_rom,
    output          dwnld_busy,

    // Bank 0: allows R/W
    output   [21:0] ba0_addr,
    output   [21:0] ba1_addr,
    output   [21:0] ba2_addr,
    output   [21:0] ba3_addr,
    output   [15:0] ba0_din,
    output   [ 1:0] ba0_din_m,  // write mask
    output   [ 3:0] ba_rd,
    output          ba_wr,
    input    [ 3:0] ba_ack,
    input    [ 3:0] ba_dst,
    input    [ 3:0] ba_dok,
    input    [ 3:0] ba_rdy,

    input   [15:0]  data_read,
    // ROM LOAD
    input   [25:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    input           ioctl_ram,
    output  [21:0]  prog_addr,
    output  [15:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output  [ 1:0]  prog_ba,
    output          prog_we,
    output          prog_rd,
    input           prog_ack,
    input           prog_dst,
    input           prog_dok,
    input           prog_rdy
);

localparam [24:0] SCR_START = `SCR_START,
                  OBJ_START = `OBJ_START,
                  PCM_START = `PCM_START,
                  SND_START = `SND_START;

assign dwnld_busy = ioctl_rom;

jtframe_dwnld #(
    .SWAB           ( 1             ),
    .BA1_START      ( SND_START     ),
    .BA2_START      ( SCR_START     ),
    .BA3_START      ( OBJ_START     )
) u_dwnld(
    .clk            ( clk           ),
    .ioctl_rom      ( ioctl_rom     ),
    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_dout     ( ioctl_dout    ),
    .ioctl_wr       ( ioctl_wr      ),
    .prog_addr      ( prog_addr     ),
    .prog_data      ( prog_data     ),
    .prog_mask      ( prog_mask     ), // active low
    .prog_we        ( prog_we       ),
    .prog_ba        ( prog_ba       ),
    .prog_rd        ( prog_rd       ),
    .prom_we        (               ),
    .header         (               ),
    .sdram_ack      ( prog_ack      ),
    .gfx8_en        ( 1'b0          ),
    .gfx16_en       ( 1'b0          )
);

localparam [21:0] ZERO_OFFSET = 0,
                  RAM_OFFSET  = 22'h10_0000,
                  VRAM_OFFSET = 22'h11_0000;

wire [16:0] ram_addr;
wire        ram_we;

assign ram_addr = ram_cs ? {4'd0, main_addr[13:1] } : { 2'b10, main_addr[15:1] };
assign ram_we   = ( ram_cs | vram_cs ) & ~main_rnw;

// Bank 0: ROM, RAM, VRAM
jtframe_ram1_4slots #(
    .ERASE   (  0 ),
    // RAM
    .SLOT0_DW( 16 ),
    .SLOT0_AW( 17 ),

    // ROM
    .SLOT1_DW( 16 ),
    .SLOT1_AW( 18 ),

    // VRAM
    .SLOT2_DW( 32 ),
    .SLOT2_AW( 15 ),

    .SLOT3_DW( 32 ),
    .SLOT3_AW( 15 ),

    // OFFSET
    .SLOT1_OFFSET( ZERO_OFFSET ),
    .SLOT2_OFFSET( VRAM_OFFSET ),
    .SLOT3_OFFSET( VRAM_OFFSET )
) u_bank0(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .slot0_addr ( ram_addr  ),
    .slot1_addr ( main_addr ),
    .slot2_addr ( scr0ram_addr ),
    .slot3_addr ( scr1ram_addr ),

    //  output data
    .slot0_dout ( ram_data  ),
    .slot1_dout ( main_data ),
    .slot2_dout ( scr0ram_data ),
    .slot3_dout ( scr1ram_data ),

    .slot0_offset( RAM_OFFSET),

    .slot0_cs   ( ram_cs | vram_cs ),
    .slot1_cs   ( main_cs   ),
    .slot2_cs   ( scr0ram_cs),
    .slot3_cs   ( scr1ram_cs),

    .slot0_ok   ( ram_ok    ),
    .slot1_ok   ( main_ok   ),
    .slot2_ok   ( scr0ram_ok),
    .slot3_ok   ( scr1ram_ok),

    // Slot 0 accepts 16-bit writes
    .slot0_wen  ( ram_we    ),
    .slot0_din  ( main_dout ),
    .slot0_wrmask( main_dsn ),
    .hold_rst   (           ),

    // Slot 1-3 cache can be cleared
    .slot1_clr  ( 1'b0      ),
    .slot2_clr  ( 1'b0      ),
    .slot3_clr  ( 1'b0      ),

    // SDRAM controller interface
    .sdram_ack  ( ba_ack[0] ),
    .sdram_rd   ( ba_rd[0]  ),
    .sdram_wr   ( ba_wr     ),
    .sdram_addr ( ba0_addr  ),
    .data_rdy   ( ba_rdy[0] ),
    .data_dst   ( ba_dst[0] ),
    .data_read  ( data_read ),
    .data_write ( ba0_din   ),  // only 16-bit writes
    .sdram_wrmask( ba0_din_m) // each bit is active low
);

// Bank 1: sound
jtframe_rom_2slots #(
    .SLOT0_AW    ( 16            ),
    .SLOT0_DW    (  8            ),
    .SLOT1_AW    ( 16            ),
    .SLOT1_DW    (  8            ),
    .SLOT1_OFFSET( (PCM_START[21:0]-SND_START[21:0])>>1 )
) u_bank1(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .slot0_addr ( snd_addr      ),
    .slot0_dout ( snd_data      ),
    .slot0_cs   ( snd_cs        ),
    .slot0_ok   ( snd_ok        ),

    .slot1_addr ( pcm_addr      ),
    .slot1_dout ( pcm_data      ),
    .slot1_cs   ( pcm_cs        ),
    .slot1_ok   ( pcm_ok        ),

    // SDRAM controller interface
    .sdram_ack  ( ba_ack[1]     ),
    .sdram_rd   ( ba_rd[1]      ),
    .sdram_addr ( ba1_addr      ),
    .data_dst   ( ba_dst[1]     ),
    .data_rdy   ( ba_rdy[1]     ),
    .data_read  ( data_read     )
);

// Bank 2: scroll
jtframe_rom_2slots #(
    .SLOT0_AW   ( 19            ),
    .SLOT0_DW   ( 32            ),
    .SLOT1_AW   ( 19            ),
    .SLOT1_DW   ( 32            )
) u_bank2(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .slot0_addr ( scr0rom_addr  ),
    .slot0_dout ( scr0rom_data  ),
    .slot0_cs   ( scr0rom_cs    ),
    .slot0_ok   ( scr0rom_ok    ),

    .slot1_addr ( scr1rom_addr  ),
    .slot1_dout ( scr1rom_data  ),
    .slot1_cs   ( scr1rom_cs    ),
    .slot1_ok   ( scr1rom_ok    ),

    // SDRAM controller interface
    .sdram_ack  ( ba_ack[2]     ),
    .sdram_rd   ( ba_rd[2]      ),
    .sdram_addr ( ba2_addr      ),
    .data_dst   ( ba_dst[2]     ),
    .data_rdy   ( ba_rdy[2]     ),
    .data_read  ( data_read     )
);

// Bank 3: Objects
jtframe_rom_1slot #(
    .SLOT0_AW   ( 19            ),
    .SLOT0_DW   ( 32            )
) u_bank3(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .slot0_addr ( orom_addr     ),
    .slot0_dout ( orom_data     ),
    .slot0_cs   ( orom_cs       ),
    .slot0_ok   ( orom_ok       ),

    // SDRAM controller interface
    .sdram_ack  ( ba_ack[3]     ),
    .sdram_rd   ( ba_rd[3]      ),
    .sdram_addr ( ba3_addr      ),
    .data_dst   ( ba_dst[3]     ),
    .data_rdy   ( ba_rdy[3]     ),
    .data_read  ( data_read     )
);

endmodule