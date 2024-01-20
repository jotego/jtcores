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
    Date: 6-4-2020 */

module jtrumble_sdram #(
    parameter MAINW = 18,
    parameter RAMW  = 13,
    parameter CHARW = 13,
    parameter SCRW  = 17,
    parameter OBJW  = 17
)(
    input              rst,
    input              clk,

    input              LVBL,
    output         reg loud,        // the srumbler has low volume, the others are louder

    // Main CPU
    input              main_cs,
    input  [MAINW-1:0] main_addr,
    output      [ 7:0] main_data,
    output             main_ok,
    input       [ 7:0] main_dout,

    // Sound CPU
    input              snd_cs,
    output             snd_ok,
    input      [14:0]  snd_addr,
    output     [ 7:0]  snd_data,

    // Char
    output             char_ok,
    input  [CHARW-1:0] char_addr,
    output      [15:0] char_data,

    // Scroll 1
    output             scr1_ok,
    input   [SCRW-1:0] scr1_addr,
    output      [15:0] scr1_data,

    // Obj
    output             obj_ok,
    input              obj_cs,
    input   [OBJW-1:0] obj_addr,
    output      [15:0] obj_data,

    // Bank 0: allows R/W
    output   [21:0] ba0_addr,
    output   [21:0] ba1_addr,
    output   [21:0] ba2_addr,
    output   [21:0] ba3_addr,
    output   [ 3:0] ba_rd,
    output          ba_wr,
    output   [15:0] ba0_din,
    output   [ 1:0] ba0_din_m,  // write mask
    input    [ 3:0] ba_ack,
    input    [ 3:0] ba_dst,
    input    [ 3:0] ba_rdy,

    input    [15:0] data_read,

    // ROM LOAD
    input           ioctl_rom,
    output reg      dwnld_busy,

    // PROMs
    output [1:0]    prom_banks,
    output          prom_prior_we,

    input   [25:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [15:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output  [ 1:0]  prog_ba,
    output          prog_we,
    output          prog_rd,
    input           prog_ack,
    input           prog_rdy,
    input           prog_dst
);

localparam [21:0] ZERO_OFFSET=0,
                  SCR_OFFSET =(22'h4c000-22'h48000)>>1;

/* verilator lint_off WIDTH */
localparam [24:0] BA1_START  = `BA1_START,
                  BA2_START  = `BA2_START,
                  BA3_START  = `BA3_START,
                  PROM_START = `PROM_START;
/* verilator lint_on WIDTH */

wire       prom_we, header;
wire       gfx_cs = LVBL;

wire convert;

wire [21:0] conv_addr, dwn_addr;
wire [15:0] dwn_data;
wire [ 7:0] conv_data;
wire [ 1:0] conv_mask, dwn_mask, dwn_ba;
wire        conv_we,   dwn_we,
            conv_rd,   dwn_rd;

//always @(*) begin
//    prog_addr = raw_prog;
//    if( prog_ba==2'd2 && raw_prog >= 22'h4000 && !prom_we ) begin
//        prog_addr[4:0] = { raw_prog[3:0], raw_prog[4] }; // swaps bit 4 for scroll tiles
//    end
//end

assign prom_prior_we = prom_we && prog_addr[9:8]==2'b10;
assign prom_banks[0] = prom_we && prog_addr[9:8]==2'b00;
assign prom_banks[1] = prom_we && prog_addr[9:8]==2'b01;

assign prog_addr = convert ? conv_addr : (
        { dwn_addr[21:6], (dwn_ba==3 && !prom_we) ? { dwn_addr[4:1], dwn_addr[5], dwn_addr[0] }: dwn_addr[5:0] });
assign prog_data = convert ? {2{conv_data}} : dwn_data;
assign prog_mask = convert ? conv_mask : dwn_mask;
assign prog_we   = convert ? conv_we   : dwn_we;
assign prog_rd   = convert ? conv_rd   : dwn_rd;
assign prog_ba   = convert ? 2'd3      : dwn_ba;
assign ba_wr     = 0;
assign ba0_din   = 0;
assign ba0_din_m = 3;

reg last_dwn;

always @(posedge clk) begin
    if( header && ioctl_addr[3:0]==0 && ioctl_wr ) loud <= ioctl_dout[0];
    last_dwn   <= ioctl_rom;
    dwnld_busy <= ioctl_rom | last_dwn | convert;
end

jtframe_dwnld #(
    .BA1_START ( BA1_START ), // sound
    .BA2_START ( BA2_START ), // tiles
    .BA3_START ( BA3_START ), // obj
    .PROM_START( PROM_START), // PCM MCU
    .SWAB      ( 1         )
) u_dwnld(
    .clk          ( clk            ),
    .ioctl_rom    ( ioctl_rom      ),
    .ioctl_addr   ( ioctl_addr     ),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ),
    .prog_addr    ( dwn_addr       ),
    .prog_data    ( dwn_data       ),
    .prog_mask    ( dwn_mask       ), // active low
    .prog_we      ( dwn_we         ),
    .prog_rd      ( dwn_rd         ),
    .prog_ba      ( dwn_ba         ),
    .prom_we      ( prom_we        ),
    .header       ( header         ),
    .sdram_ack    ( prog_ack       ),
    .gfx8_en      ( 1'b0           ),
    .gfx16_en     ( 1'b0           )
);

`ifdef SIMULATION
`ifndef LOADROM
    `define SKIPOBJ32
`endif
`endif

`ifndef SKIPOBJ32
jtgng_obj32 #(
    .OBJ_START( 22'd0     ),
    .OBJ_END  ( 22'h40000 )
) u_obj32(
    .clk         ( clk          ),
    .ioctl_rom   ( ioctl_rom    ),
    .sdram_dout  ( data_read    ),
    .convert     ( convert      ),
    .prog_addr   ( conv_addr    ),
    .prog_data   ( conv_data    ),
    .prog_mask   ( conv_mask    ), // active low
    .prog_we     ( conv_we      ),
    .prog_rd     ( conv_rd      ),
    .sdram_ack   ( prog_ack     ),
    .data_ok     ( prog_rdy     )   // using prog_dst would corrupt the graphics
);
`else
assign conv_addr = 0;
assign conv_data = 0;
assign conv_we   = 0;
assign conv_rd   = 0;
assign conv_mask = 0;
assign convert   = 0;
`endif

/* xxx tracing_off */
// main CPU ROM
jtframe_rom_1slot #(
    // Game ROM
    .SLOT0_DW( 8),
    .SLOT0_AW(MAINW)
) u_bank0(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .slot0_addr ( main_addr ),
    .slot0_dout ( main_data ),
    .slot0_cs   ( main_cs   ),
    .slot0_ok   ( main_ok   ),

    // SDRAM controller interface
    .sdram_ack   ( ba_ack[0] ),
    .sdram_rd    ( ba_rd[0]  ),
    .sdram_addr  ( ba0_addr  ),
    .data_dst    ( ba_dst[0] ),
    .data_rdy    ( ba_rdy[0] ),
    .data_read   ( data_read )
);

// Audio CPU
jtframe_rom_1slot #(
    .SLOT0_DW( 8),
    .SLOT0_AW(15)
) u_bank1(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .slot0_addr ( snd_addr  ),
    .slot0_dout ( snd_data  ),
    .slot0_cs   ( snd_cs    ),
    .slot0_ok   ( snd_ok    ),

    // SDRAM controller interface
    .sdram_ack  ( ba_ack[1] ),
    .sdram_rd   ( ba_rd[1]  ),
    .sdram_addr ( ba1_addr  ),
    .data_dst   ( ba_dst[1] ),
    .data_rdy   ( ba_rdy[1] ),
    .data_read  ( data_read )
);

// Char and scroll
jtframe_rom_2slots #(
    .SLOT0_DW(   16),
    .SLOT0_AW(CHARW),

    .SLOT1_DW(  16),
    .SLOT1_AW(SCRW),

    .SLOT1_OFFSET( SCR_OFFSET )
) u_bank2(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .slot0_addr ( char_addr ),
    .slot0_dout ( char_data ),
    .slot0_cs   ( gfx_cs    ),
    .slot0_ok   ( char_ok   ),

    .slot1_addr ( scr1_addr ),
    .slot1_dout ( scr1_data ),
    .slot1_cs   ( gfx_cs    ),
    .slot1_ok   ( scr1_ok   ),

    // SDRAM controller interface
    .sdram_ack  ( ba_ack[2] ),
    .sdram_rd   ( ba_rd[2]  ),
    .sdram_addr ( ba2_addr  ),
    .data_dst   ( ba_dst[2] ),
    .data_rdy   ( ba_rdy[2] ),
    .data_read  ( data_read )
);

// Objects
jtframe_rom_1slot #(
    .SLOT0_DW(  16),
    .SLOT0_AW(OBJW)
) u_bank3(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .slot0_addr ( obj_addr  ),
    .slot0_dout ( obj_data  ),
    .slot0_cs   ( obj_cs    ),
    .slot0_ok   ( obj_ok    ),

    // SDRAM controller interface
    .sdram_ack  ( ba_ack[3] ),
    .sdram_rd   ( ba_rd[3]  ),
    .sdram_addr ( ba3_addr  ),
    .data_dst   ( ba_dst[3] ),
    .data_rdy   ( ba_rdy[3] ),
    .data_read  ( data_read )
);
/* verilator tracing_on */
endmodule