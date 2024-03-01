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
    Version: 2.0
    Date: 28-2-2024 */

module jtcop_sdram(
    input            clk,

    // Main CPU
    input     [18:1] main_addr,
    output reg[15:1] ram_addr,
    // Video RAM
    input            fsft_cs,
    input            fmap_cs,
    input            bsft_cs,
    input            bmap_cs,
    input            csft_cs,
    input            cmap_cs,

    // ROM banks
    input     [ 2:1] sndflag,
    input            snd_bank,

    // PROM
    output           mcu_we,    // for i8751 only
    output           prio_we,

    // Sound CPU
    input     [15:0] snd_prea,
    output    [15:0] snd_addr,

    // ADPCM ROM
    input     [17:0] adpcm_prea,
    output    [17:0] adpcm_addr,

    // MCU
    output reg [1:0] game_id=0, // 1 for hippodrm, 0 for the rest

    // BA2 - MCU
    input     [13:1] ba2mcu_addr,

    // ROM LOAD
    input     [25:0] ioctl_addr,
    input     [21:0] prog_addr,
    input     [ 1:0] prog_ba,
    output reg[21:0] post_addr,
    input     [ 7:0] prog_data,
    output    [ 7:0] post_data,
    input            prom_we,
    input            prog_we
);

parameter BANKS=0;

/* verilator lint_off WIDTH */
localparam [24:0] BA1_START   = `JTFRAME_BA1_START,
                  MCU_START   = `MCU_START,
                  MCU_END     = MCU_START + 25'h1000,
                  BA2_START   = `JTFRAME_BA2_START,
                  GFX2_START  = `GFX2_START,
                  GFX3_START  = `GFX3_START,
                  BA3_START   = `JTFRAME_BA3_START,
                  PROM_START  = `PROM_START,
            `ifndef DEC1
                  PRIO_START  = PROM_START+25'h200,
                  PRIO_END    = PRIO_START+25'h400;
            `else
                  PRIO_START  = PROM_START,
                  PRIO_END    = PRIO_START+25'h100;
            `endif

localparam [21:0] GFX2_OFFSET = `GFX2_OFFSET,
                  GFX3_OFFSET = `GFX3_OFFSET,
                  MCU_OFFSET  = `MCU_OFFSET,
                  GFX1_LEN    = 22'h1_0000,
                  GFX2_LEN    = 22'h4_0000,
                  GFX3_LEN    = 22'h2_0000;

localparam [ 1:0] HIPPODROME  = 2'd1;
`ifndef DEC1
    localparam    DEC1=0;
`else
    localparam    DEC1=1;
`endif

wire        is_gfx1, is_gfx2, is_gfx3, reorder;
wire [21:0] gfx2_offset, gfx3_offset;
reg  [ 7:0] rom_test=0;

`ifndef DEC1
    assign reorder   = game_id==HIPPODROME && post_addr>=MCU_OFFSET && prog_ba==3 && !prom_we;
    assign post_data = reorder ? {2{prog_data[0], prog_data[6:1], prog_data[7]}} : prog_data;
`else
    assign reorder   = 0;
    assign post_data = prog_data;
`endif
assign mcu_we  = prom_we && prog_addr >= MCU_START  && prog_addr < MCU_END;
assign prio_we = prom_we && prog_addr >= PRIO_START && prog_addr < PRIO_END; // priority PROM comes 2nd in the MRA file
assign is_gfx1 = prog_ba==2 && prog_addr < GFX1_LEN;
assign is_gfx2 = prog_ba==2 && prog_addr >= GFX1_LEN && gfx2_offset < GFX2_LEN;
assign is_gfx3 = prog_ba==2 && !is_gfx1 && !is_gfx2;

// MSB bit moved to LSB position, so we get all four colour planes
// in a single 32-bit read
assign gfx2_offset = prog_addr - GFX1_LEN;
assign gfx3_offset = prog_addr - GFX1_LEN - GFX2_LEN;

always @* begin
    post_addr = prog_addr;
    if( is_gfx1 ) begin
        post_addr = { prog_addr[21:16], prog_addr[14:0], (~DEC1[0])^prog_addr[15] };
    end
    if( is_gfx2 ) begin
    `ifndef SLYSPY
        post_addr = { GFX2_OFFSET[21:18], gfx2_offset[16:0], gfx2_offset[17] };
    `else
        post_addr = { GFX2_OFFSET[21:18], gfx2_offset[17:16], gfx2_offset[14:0], gfx2_offset[15] };
    `endif
    end
    if( is_gfx3 ) begin
        post_addr = { GFX3_OFFSET[21:17], gfx3_offset[15:0],(~DEC1[0])^gfx3_offset[16] };
    end
    if( prio_we )
        post_addr[9:8] = post_addr[9:8]-2'd2;
end

reg prog_wel;

always @(posedge clk) begin
    prog_wel <= prog_we;
    if( prog_we && !prog_wel ) begin
        if( ioctl_addr < 8 )
            rom_test <= rom_test + prog_data;
        `ifndef DEC1
        if( ioctl_addr==8 )
            game_id <= (rom_test==8'hc || rom_test==8'hf4) ? HIPPODROME : 2'd0; // Detects Fighting Fantasy
        `else
            game_id <= 0;
        `endif
    end
end

// Sound
// adpcm_addr[16] is used as an /OE signal on the board
// I'm ignoring that connection here as it isn't relevant
`ifndef DEC1
    assign adpcm_addr = { 2'b0, adpcm_prea[15] | sndflag[2], adpcm_prea[14:0] };
`else
    assign adpcm_addr = adpcm_prea;
`endif
`ifdef MCU
assign snd_addr = BANKS ? { sndflag[1] | snd_prea[15],
                           (snd_bank | snd_prea[15]) & snd_prea[14],
                           snd_prea[13:0] } :
                        { 1'b0, snd_prea[14:0] };
`else
    `ifdef DEC1
        assign snd_addr = snd_prea;
    `else
        assign snd_addr = { 1'b0, snd_prea[14:0] };
    `endif
`endif

// RAM size
// 16kB   M68000 exclusive use
// 16kB   B0
//  4kB   B1
//  4kB   B2
// 40kB   Total -> AW=15, DW=16

// merged address
always @* begin
    ram_addr = {2'b0, main_addr[13:1]};
    // first BAC06 (16kB)
    if( fsft_cs )
        ram_addr[15:13] = 3'b010;
    else if( fmap_cs )
        ram_addr[15:13] = 3'b011;
    // second BAC06 (4kB)
    else if( bsft_cs )
        ram_addr[15:11] = 5'b1000_0;
    else if( bmap_cs )
        ram_addr[15:11] = 5'b1010_0;
    // third BAC06 (4kB)
    else if( csft_cs )
        ram_addr[15:11] = 5'b1100_0;
    else if( cmap_cs )
        ram_addr[15:11] = 5'b1110_0;
end

endmodule