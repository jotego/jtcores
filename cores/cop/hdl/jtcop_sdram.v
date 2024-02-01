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
    Date: 25-9-2021 */

module jtcop_sdram(
    input            rst,
    input            clk,
    input     [ 7:0] st_video,
    input     [ 7:0] pal_dmp,
    input     [ 7:0] obj_dmp,

    // Main CPU
    input            main_cs,
    input     [18:1] main_addr,
    output    [15:0] main_data,
    output           main_ok,

    input            ram_cs,
    output           ram_ok,
    output    [15:0] ram_data,

    input     [ 1:0] dsn,
    input     [15:0] main_dout,
    input            main_rnw,

    // Video RAM
    input            fsft_cs,
    input            fmap_cs,
    input            bsft_cs,
    input            bmap_cs,
    input            csft_cs,
    input            cmap_cs,

    // ROM banks
    input     [ 2:1] sndflag,
    input     [ 2:1] b1flg,
    input     [ 2:1] mixflg,
    input     [ 2:0] crback,
    input            b0flg,
    input            sndbank,

    // PROM
    output           mcu_we,    // for i8751 only
    output           prio_we,

    // Sound CPU
    input            snd_cs,
    output           snd_ok,
    input     [15:0] snd_addr,
    output    [ 7:0] snd_data,

    // ADPCM ROM
    input     [17:0] adpcm_addr,
    input            adpcm_cs,
    output    [ 7:0] adpcm_data,
    output           adpcm_ok,

    // Scroll B0 - RAM
    input            b0ram_cs,
    input     [13:1] b0ram_addr,
    output    [15:0] b0ram_data,
    output           b0ram_ok,
    //        B0 - ROM
    output           b0rom_ok,
    input    [17:0]  b0rom_addr,
    input            b0rom_cs,
    output   [31:0]  b0rom_data,

    // Scroll B1 - RAM
    input            b1ram_cs,
    input     [13:1] b1ram_addr,
    output    [15:0] b1ram_data,
    output           b1ram_ok,
    //        B1 - ROM
    output           b1rom_ok,
    input    [17:0]  b1rom_addr,
    input            b1rom_cs,
    output   [31:0]  b1rom_data,

    // Scroll B2 - RAM
    input            b2ram_cs,
    input     [13:1] b2ram_addr,
    output    [15:0] b2ram_data,
    output           b2ram_ok,
    //        B2 - ROM
    output           b2rom_ok,
    input    [17:0]  b2rom_addr,
    input            b2rom_cs,
    output   [31:0]  b2rom_data,

    // Obj
    output           obj_ok,
    input            obj_cs,
    input    [17:0]  obj_addr,
    output   [31:0]  obj_data,

    // MCU
    output           mcu_ok,
    input            mcu_cs,
    input    [15:0]  mcu_addr,
    output   [ 7:0]  mcu_data,
    output reg [1:0] game_id=0, // 1 for hippodrm, 0 for the rest

    // BA2 - MCU
    input            ba2mcu_cs,
    input            ba2mcu_rnw,
    output           ba2mcu_ok,
    input     [ 7:0] mcu_dout,
    input     [13:1] ba2mcu_addr,
    output    [ 7:0] ba2mcu_data,
    input     [ 1:0] ba2mcu_dsn,

    // Bank 0: allows R/W
    output    [21:0] ba0_addr,
    output    [21:0] ba1_addr,
    output    [21:0] ba2_addr,
    output    [21:0] ba3_addr,
    output    [ 3:0] ba_rd,
    output    [ 3:0] ba_wr,
    output    [15:0] ba0_din,
    output    [ 1:0] ba0_din_m,  // write mask
    input     [ 3:0] ba_ack,
    input     [ 3:0] ba_dst,
    input     [ 3:0] ba_dok,
    input     [ 3:0] ba_rdy,

    input     [15:0] data_read,

    // ROM LOAD
    input            ioctl_rom,
    output           dwnld_busy,

    input    [24:0]  ioctl_addr,
    input    [ 7:0]  ioctl_dout,
    output   [ 7:0]  ioctl_din,
    input            ioctl_wr,
    input            ioctl_ram,
    output reg [21:0] prog_addr,
    output    [15:0] prog_data,
    output    [ 1:0] prog_mask,
    output    [ 1:0] prog_ba,
    output           prog_we,
    output           prog_rd,
    input            prog_ack,
    input            prog_rdy
);

parameter BANKS=0;

/* verilator lint_off WIDTH */
localparam [24:0] BA1_START   = `BA1_START,
                  MCU_START   = `MCU_START,
                  MCU_END     = MCU_START + 25'h1000,
                  BA2_START   = `BA2_START,
                  GFX2_START  = `GFX2_START,
                  GFX3_START  = `GFX3_START,
                  BA3_START   = `BA3_START,
                  PROM_START  = `JTFRAME_PROM_START,
            `ifndef DEC1
                  PRIO_START  = PROM_START+25'h200,
                  PRIO_END    = PRIO_START+25'h400;
            `else
                  PRIO_START  = PROM_START,
                  PRIO_END    = PRIO_START+25'h100;
            `endif

localparam [21:0] B0_OFFSET   = 22'h2000,
                  B1_OFFSET   = 22'h4000,
                  B2_OFFSET   = 22'h6000,
                  SND_OFFSET  = (`SND_START-BA1_START[21:0])>>1,
                  PCM_OFFSET  = (`PCM_START-BA1_START[21:0])>>1,
                  ZERO_OFFSET = 0,
                  GFX2_OFFSET = 22'h10_0000,
                  GFX3_OFFSET = 22'h20_0000,
                  MCU_OFFSET  = 22'h4_0000,
                  GFX1_LEN    = 22'h1_0000,
                  GFX2_LEN    = 22'h4_0000,
                  GFX3_LEN    = 22'h2_0000;

localparam [ 1:0] HIPPODROME  = 2'd1;
`ifndef DEC1
    localparam    DEC1=0;
`else
    localparam    DEC1=1;
`endif

wire        prom_we, is_gfx1, is_gfx2, is_gfx3;
wire [21:0] pre_prog, gfx2_offset, gfx3_offset;
reg  [ 7:0] rom_test=0;
wire [ 7:0] ram_dmp;
wire [15:0] prog_raw, ba2mcu_raw;

assign ba2mcu_data = mcu_addr[0] ? ba2mcu_raw[15:8] : ba2mcu_raw[7:0];
assign mcu_we  = prom_we && pre_prog >= MCU_START  && pre_prog < MCU_END;
`ifndef DEC1
    assign prog_data =
        (game_id==HIPPODROME && prog_addr>=MCU_OFFSET && prog_ba==3 && !prom_we) ?
        {   prog_raw[8], prog_raw[14:9], prog_raw[15],
            prog_raw[0], prog_raw[ 6:1], prog_raw[ 7] } : prog_raw;
`else
    assign prog_data = prog_raw;
`endif
// priority PROM is meant to be the second one in the MRA file
assign prio_we = prom_we && pre_prog >= PRIO_START && pre_prog < PRIO_END;
assign is_gfx1 = prog_ba==2'd2 && pre_prog < GFX1_LEN;
assign is_gfx2 = prog_ba==2'd2 && pre_prog >= GFX1_LEN && gfx2_offset < GFX2_LEN;
assign is_gfx3 = prog_ba==2'd2 && !is_gfx1 && !is_gfx2;

// MSB bit moved to LSB position, so we get all four colour planes
// in a single 32-bit read
assign gfx2_offset = pre_prog - GFX1_LEN;
assign gfx3_offset = pre_prog - GFX1_LEN - GFX2_LEN;

assign ba_wr[3:1]  = 0;
assign ioctl_din = ioctl_addr[15:8]<8'he8 ? ram_dmp :
                   ioctl_addr[15:8]<8'hf0 ? pal_dmp :
                   ioctl_addr[15:8]<8'hf8 ? obj_dmp : st_video;

always @* begin
    prog_addr = pre_prog;
    if( is_gfx1 ) begin
        prog_addr = { pre_prog[21:16], pre_prog[14:0], (~DEC1[0])^pre_prog[15] };
    end
    if( is_gfx2 ) begin
    `ifndef SLYSPY
        prog_addr = { GFX2_OFFSET[21:18], gfx2_offset[16:0], gfx2_offset[17] };
    `else
        prog_addr = { GFX2_OFFSET[21:18], gfx2_offset[17:16], gfx2_offset[14:0], gfx2_offset[15] };
    `endif
    end
    if( is_gfx3 ) begin
        prog_addr = { GFX3_OFFSET[21:17], gfx3_offset[15:0],(~DEC1[0])^gfx3_offset[16] };
    end
    if( prio_we )
        prog_addr[9:8] = prog_addr[9:8]-2'd2;
end

always @(posedge clk) begin
    if( !ioctl_rom ) rom_test <= 0;
    if( ioctl_wr ) begin
        if( ioctl_addr < 8 )
            rom_test <= rom_test + ioctl_dout;
        `ifndef DEC1
        if( ioctl_addr==8 )
            game_id <= (rom_test==8'hc || rom_test==8'hf4) ? HIPPODROME : 2'd0; // Detects Fighting Fantasy
        `else
            game_id <= 0;
        `endif
    end
end

`ifdef JTFRAME_DWNLD_PROM_ONLY
    assign dwnld_busy = ioctl_rom | prom_we; // keep the game in reset while
        // the short PROM download occurs
`else
    assign dwnld_busy = ioctl_rom;
`endif

jtframe_dwnld #(
    .BA1_START ( 0         ), // sound
    .BA2_START ( BA2_START ), // tiles
    .BA3_START ( BA3_START ), // obj
`ifdef NOHUC
    .PROM_START( MCU_START ), // i8751
`else
    .PROM_START( PROM_START),
`endif
    .SWAB      ( 1         )
) u_dwnld(
    .clk          ( clk            ),
    .ioctl_rom    ( ioctl_rom      ),
    .ioctl_addr   ( ioctl_addr     ),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ),
    .prog_addr    ( pre_prog       ),
    .prog_data    ( prog_raw       ),
    .prog_mask    ( prog_mask      ), // active low
    .prog_we      ( prog_we        ),
    .prog_rd      ( prog_rd        ),
    .prog_ba      ( prog_ba        ),
    .prom_we      ( prom_we        ),
    .header       (                ),
    .sdram_ack    ( prog_ack       ),
    .gfx8_en      ( 1'b0           ),
    .gfx16_en     ( 1'b0           )
);

// Sound
// adpcm_addr[16] is used as an /OE signal on the board
// I'm ignoring that connection here as it isn't relevant
wire [17:0] adpcm_eff;
wire [15:0] snd_eff;

`ifndef DEC1
    assign adpcm_eff = { 2'b0, adpcm_addr[15] | sndflag[2], adpcm_addr[14:0] };
`else
    assign adpcm_eff = adpcm_addr;
`endif
`ifdef MCU
assign snd_eff = BANKS ? { sndflag[1] | snd_addr[15],
                           (sndbank | snd_addr[15]) & snd_addr[14],
                           snd_addr[13:0] } :
                        { 1'b0, snd_addr[14:0] };
`else
    `ifdef DEC1
        assign snd_eff = snd_addr;
    `else
        assign snd_eff = { 1'b0, snd_addr[14:0] };
    `endif
`endif

// RAM size
// 16kB   M68000 exclusive use
// 16kB   B0
//  4kB   B1
//  4kB   B2
// 40kB   Total -> AW=15, DW=16

// merged address
reg  [15:1] ram_maddr /* synthesis keep */;

always @* begin
    ram_maddr = {2'b0, main_addr[13:1]};
    // first BAC06 (16kB)
    if( fsft_cs )
        ram_maddr[15:13] = 3'b010;
    else if( fmap_cs )
        ram_maddr[15:13] = 3'b011;
    // second BAC06 (4kB)
    else if( bsft_cs )
        ram_maddr[15:11] = 5'b1000_0;
    else if( bmap_cs )
        ram_maddr[15:11] = 5'b1010_0;
    // third BAC06 (4kB)
    else if( csft_cs )
        ram_maddr[15:11] = 5'b1100_0;
    else if( cmap_cs )
        ram_maddr[15:11] = 5'b1110_0;
end

jtframe_ram2_6slots #(
    .ERASE       (  0          ),
    // VRAM/RAM
    .SLOT0_DW    ( 16          ),
    .SLOT0_AW    ( 15          ),  // 64 kB (only 40 used)

    // MCU access to B2
    .SLOT1_DW    ( 16          ),
    .SLOT1_AW    ( 13          ),  // 2 kB

    // VRAM access by B0
    .SLOT2_DW    ( 16          ),
    .SLOT2_AW    ( 13          ),
    .SLOT2_OFFSET(  B0_OFFSET  ),

    // VRAM access by B1
    .SLOT3_DW    ( 16          ),
    .SLOT3_AW    ( 13          ),
    .SLOT3_OFFSET(  B1_OFFSET  ),

    // VRAM access by B2
    .SLOT4_DW    ( 16          ),
    .SLOT4_AW    ( 13          ),
    .SLOT4_OFFSET(  B2_OFFSET  ),

    // Dump to SD card
    .SLOT5_DW    (  8          ),
    .SLOT5_AW    ( 16          )
) u_bank0(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .slot0_offset(  22'd0   ),
    .slot1_offset(  B2_OFFSET),

    .slot0_addr ( ram_maddr ),
    .slot1_addr (ba2mcu_addr),
    .slot2_addr ( b0ram_addr),
    .slot3_addr ( b1ram_addr),
    .slot4_addr ( b2ram_addr),
    .slot5_addr ( ioctl_addr[15:0] ),

    //  output data
    .slot0_dout ( ram_data  ),
    .slot1_dout ( ba2mcu_raw ),
    .slot2_dout ( b0ram_data),
    .slot3_dout ( b1ram_data),
    .slot4_dout ( b2ram_data),
    .slot5_dout ( ram_dmp   ),

    .slot0_cs   ( ram_cs    ),
    .slot1_cs   ( ba2mcu_cs ),
    .slot2_cs   ( b0ram_cs & ~ioctl_ram  ),
    .slot3_cs   ( b1ram_cs & ~ioctl_ram  ),
    .slot4_cs   ( b2ram_cs & ~ioctl_ram  ),
    .slot5_cs   ( ioctl_ram ),

    .slot0_wen  ( ~main_rnw ),
    .slot0_din  ( main_dout ),
    .slot0_wrmask( dsn      ),
    .hold_rst   (           ),

    .slot1_wen  ( ~ba2mcu_rnw ),
    .slot1_din  ({2{mcu_dout}}),
    .slot1_wrmask( ba2mcu_dsn ),

    .slot2_clr  ( 1'b0      ),
    .slot3_clr  ( 1'b0      ),
    .slot4_clr  ( 1'b0      ),
    .slot5_clr  ( 1'b0      ),

    .slot0_ok   ( ram_ok    ),
    .slot1_ok   ( ba2mcu_ok ),
    .slot2_ok   ( b0ram_ok  ),
    .slot3_ok   ( b1ram_ok  ),
    .slot4_ok   ( b2ram_ok  ),
    .slot5_ok   (           ),

    // SDRAM controller interface
    .sdram_ack   ( ba_ack[0] ),
    .sdram_rd    ( ba_rd[0]  ),
    .sdram_wr    ( ba_wr[0]  ),
    .sdram_addr  ( ba0_addr  ),
    .data_dst    ( ba_dst[0] ),
    .data_rdy    ( ba_rdy[0] ),
    .data_write  ( ba0_din   ),
    .sdram_wrmask( ba0_din_m ),
    .data_read   ( data_read )
);

// Bank 1: Main CPU and Sound

jtframe_rom_3slots #(
    .SLOT0_DW    (   8         ),
    .SLOT0_AW    (  16         ),
    .SLOT0_OFFSET( SND_OFFSET  ),

    .SLOT1_DW    (   8         ),
    .SLOT1_AW    (  18         ),
    .SLOT1_OFFSET( PCM_OFFSET  ),

    // Game ROM
    .SLOT2_DW    ( 16          ),
    .SLOT2_AW    ( 18          ),  // 512kB temptative value
    .SLOT2_OFFSET( ZERO_OFFSET )
) u_bank1(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .slot0_addr ( snd_eff   ),
    .slot0_dout ( snd_data  ),
    .slot0_cs   ( snd_cs    ),
    .slot0_ok   ( snd_ok    ),

    .slot1_addr (adpcm_eff  ),
    .slot1_dout (adpcm_data ),
    .slot1_cs   (adpcm_cs   ),
    .slot1_ok   (adpcm_ok   ),

    .slot2_addr ( main_addr ),
    .slot2_dout ( main_data ),
    .slot2_cs   ( main_cs   ),
    .slot2_ok   ( main_ok   ),
    // SDRAM controller interface
    .sdram_addr ( ba1_addr  ),
    .sdram_rd   ( ba_rd[1]  ),
    .sdram_ack  ( ba_ack[1] ),
    .data_dst   ( ba_dst[1] ),
    .data_rdy   ( ba_rdy[1] ),
    .data_read  ( data_read )
);

// Bank 2: BAC06 chips

jtframe_rom_3slots #(
    .SLOT0_DW(  32),
    .SLOT0_AW(  18),

    .SLOT1_DW(  32),
    .SLOT1_AW(  18),

    .SLOT2_DW(  32),
    .SLOT2_AW(  18),

    .SLOT1_OFFSET( GFX2_OFFSET ),
    .SLOT2_OFFSET( GFX3_OFFSET )
) u_bank2(
    .rst        ( rst        ),
    .clk        ( clk        ),

    .slot0_addr ( b0rom_addr ),
    .slot0_dout ( b0rom_data ),
    .slot0_cs   ( b0rom_cs & ~ioctl_ram ),
    .slot0_ok   ( b0rom_ok   ),

    .slot1_addr ( b1rom_addr ),
    .slot1_dout ( b1rom_data ),
    .slot1_cs   ( b1rom_cs & ~ioctl_ram ),
    .slot1_ok   ( b1rom_ok   ),

    .slot2_addr ( b2rom_addr ),
    .slot2_dout ( b2rom_data ),
    .slot2_cs   ( b2rom_cs & ~ioctl_ram ),
    .slot2_ok   ( b2rom_ok   ),

    // SDRAM controller interface
    .sdram_addr ( ba2_addr   ),
    .sdram_rd   ( ba_rd[2]   ),
    .sdram_ack  ( ba_ack[2]  ),
    .data_dst   ( ba_dst[2]  ),
    .data_rdy   ( ba_rdy[2]  ),
    .data_read  ( data_read  )
);

// Bank 3: objects & HuC

jtframe_rom_2slots #(
    .SLOT0_DW    (  32        ),
    .SLOT0_AW    (  18        ),
    .SLOT1_DW    (   8        ),
    .SLOT1_AW    (  16        ),
    .SLOT1_OFFSET( MCU_OFFSET )
) u_bank3(
    .rst        ( rst        ),
    .clk        ( clk        ),

    .slot0_addr ( obj_addr   ),
    .slot0_dout ( obj_data   ),
    .slot0_cs   ( obj_cs     ),
    .slot0_ok   ( obj_ok     ),

    .slot1_addr ( mcu_addr   ),
    .slot1_dout ( mcu_data   ),
    .slot1_cs   ( mcu_cs     ),
    .slot1_ok   ( mcu_ok     ),

    // SDRAM controller interface
    .sdram_addr ( ba3_addr   ),
    .sdram_rd   ( ba_rd[3]   ),
    .sdram_ack  ( ba_ack[3]  ),
    .data_dst   ( ba_dst[3]  ),
    .data_rdy   ( ba_rdy[3]  ),
    .data_read  ( data_read  )
);

endmodule