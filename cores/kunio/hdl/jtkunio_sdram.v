/*  This file is part of JTKUNIO.
    JTKUNIO program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKUNIO program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKUNIO.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 30-7-2022 */

module jtkunio_sdram(
    input           rst,
    input           clk,
    input           vs,
    input           hs,

    // Main CPU
    input            main_cs,
    input     [15:0] main_addr,
    output    [ 7:0] main_data,
    output           main_ok,

    // Sound CPU
    input            snd_cs,
    input     [14:0] snd_addr,
    output    [ 7:0] snd_data,
    output           snd_ok,

    // PCM ROM
    input     [16:0] pcm_addr,
    input            pcm_cs,
    output    [ 7:0] pcm_data,
    output           pcm_ok,

    // Char layer
    output           char_ok,
    input    [13:0]  char_addr,
    output   [31:0]  char_data,

    // Scroll layer
    output           scr_ok,
    input    [16:0]  scr_addr,
    output   [31:0]  scr_data,


    // Obj
    output           obj_ok,
    input            obj_cs,
    input    [17:0]  obj_addr,
    output   [31:0]  obj_data,

    // Banks
    output    [21:0] ba0_addr,
    output    [21:0] ba1_addr,
    output    [21:0] ba2_addr,
    output    [21:0] ba3_addr,
    output    [ 3:0] ba_rd,
    input     [ 3:0] ba_ack,
    input     [ 3:0] ba_dst,
    input     [ 3:0] ba_dok,
    input     [ 3:0] ba_rdy,

    input     [15:0] data_read,

    // ROM LOAD
    input            downloading,
    output           dwnld_busy,

    input    [24:0]  ioctl_addr,
    input    [ 7:0]  ioctl_dout,
    input            ioctl_wr,
    output    [21:0] prog_addr,
    output    [15:0] prog_data,
    output    [ 1:0] prog_mask,
    output    [ 1:0] prog_ba,
    output           prog_we,
    output           prog_rd,
    input            prog_ack,
    input            prog_rdy,
    output           prom_we
);

/* verilator lint_off WIDTH */
localparam [24:0] BA1_START   = `BA1_START,
                  BA2_START   = `BA2_START,
                  BA3_START   = `BA3_START,
                  SCR_START   = `SCR_START,
                  PROM_START  = `PROM_START;

localparam [21:0] SCR_OFFSET  = (SCR_START-BA2_START)>>1,
                  PCM_OFFSET  = `PCM_OFFSET;
/* verilator lint_on WIDTH */

/* xxverilator tracing_off */

wire        is_char, is_scr, is_obj;
reg  [24:0] post_addr;
wire        gfx_cs;

assign gfx_cs     = ~vs & ~hs & ~downloading;
assign dwnld_busy = downloading;
assign is_char    = prog_ba==2 && ioctl_addr[19:0]<SCR_START[19:0];
assign is_scr     = prog_ba==2 && !is_char;
assign is_obj     = prog_ba==3 && !prom_we;

always @* begin
    post_addr = ioctl_addr;
    // moves the H address bit to the LSBs
    if( is_char )
        post_addr[4:0] = { ioctl_addr[2:0], ioctl_addr[4:3] };
    if( is_scr | is_obj )
        post_addr[5:0] = { ioctl_addr[3:0], ioctl_addr[5:4] };
end

jtframe_dwnld #(
    .BA1_START ( BA1_START ), // PCM sound
    .BA2_START ( BA2_START ), // char
    .BA3_START ( BA3_START ), // obj
    .PROM_START( PROM_START),
    .SWAB      ( 1         )
) u_dwnld(
    .clk          ( clk            ),
    .downloading  ( downloading    ),
    .ioctl_addr   ( post_addr      ),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ),
    .prog_addr    ( prog_addr      ),
    .prog_data    ( prog_data      ),
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

jtframe_rom_1slot #(
    .SLOT0_DW( 8),
    .SLOT0_AW(16)
) u_bank0(
    .rst         ( rst        ),
    .clk         ( clk        ),

    .slot0_addr  ( main_addr  ),
    .slot0_dout  ( main_data  ),
    .slot0_cs    ( main_cs    ),
    .slot0_ok    ( main_ok    ),

    // SDRAM controller interface
    .sdram_ack   ( ba_ack[0]  ),
    .sdram_rd    ( ba_rd[0]   ),
    .sdram_addr  ( ba0_addr   ),
    .data_dst    ( ba_dst[0]  ),
    .data_rdy    ( ba_rdy[0]  ),
    .data_read   ( data_read  )
);

// Bank 1: sound
jtframe_rom_2slots #(
    .SLOT0_DW    (   8        ),
    .SLOT0_AW    (  15        ),

    .SLOT1_DW    (   8        ),
    .SLOT1_AW    (  17        ),
    .SLOT1_OFFSET( PCM_OFFSET )
) u_bank1(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .slot0_addr ( snd_addr  ),
    .slot0_dout ( snd_data  ),
    .slot0_cs   ( snd_cs    ),
    .slot0_ok   ( snd_ok    ),

    .slot1_addr ( pcm_addr  ),
    .slot1_dout ( pcm_data  ),
    .slot1_cs   ( pcm_cs    ),
    .slot1_ok   ( pcm_ok    ),

    // SDRAM controller interface
    .sdram_addr ( ba1_addr  ),
    .sdram_rd   ( ba_rd[1]  ),
    .sdram_ack  ( ba_ack[1] ),
    .data_dst   ( ba_dst[1] ),
    .data_rdy   ( ba_rdy[1] ),
    .data_read  ( data_read )
);

// Bank 2: Char & scroll layers
jtframe_rom_2slots #(
    .SLOT0_DW    (         32 ), // Char
    .SLOT0_AW    (         14 ),

    .SLOT1_DW    (         32 ), // Scroll
    .SLOT1_AW    (         17 ),
    .SLOT1_OFFSET( SCR_OFFSET )
) u_bank2(
    .rst        ( rst        ),
    .clk        ( clk        ),

    .slot0_addr ( char_addr  ),
    .slot0_dout ( char_data  ),
    .slot0_cs   ( gfx_cs     ),
    .slot0_ok   ( char_ok    ),

    .slot1_addr ( scr_addr   ),
    .slot1_dout ( scr_data   ),
    .slot1_cs   ( gfx_cs     ),
    .slot1_ok   ( scr_ok     ),

    // SDRAM controller interface
    .sdram_addr ( ba2_addr   ),
    .sdram_rd   ( ba_rd[2]   ),
    .sdram_ack  ( ba_ack[2]  ),
    .data_dst   ( ba_dst[2]  ),
    .data_rdy   ( ba_rdy[2]  ),
    .data_read  ( data_read  )
);

// Bank 3: objects
jtframe_rom_1slot #(
    .SLOT0_DW   (  32        ),
    .SLOT0_AW   (  18        )
) u_bank3(
    .rst        ( rst        ),
    .clk        ( clk        ),

    .slot0_addr ( obj_addr   ),
    .slot0_dout ( obj_data   ),
    .slot0_cs   ( gfx_cs     ),
    .slot0_ok   ( obj_ok     ),

    // SDRAM controller interface
    .sdram_addr ( ba3_addr   ),
    .sdram_rd   ( ba_rd[3]   ),
    .sdram_ack  ( ba_ack[3]  ),
    .data_dst   ( ba_dst[3]  ),
    .data_rdy   ( ba_rdy[3]  ),
    .data_read  ( data_read  )
);

/* verilator tracing_on */
endmodule