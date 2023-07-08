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
    Date: 23-10-2022 */

module jts16_mem(
    input            rst,
    input            clk,

    input            LVBL,
    input      [8:0] vrender,
    output reg [7:0] game_id,
    input      [5:0] tile_bank, // always 0 for S16A
    output           gfx_cs,

    // Encryption
    output           fd1089_we,
    output           key_we,
    input     [12:0] key_addr,
    input     [12:0] key_mcaddr,
    output    [ 7:0] key_data,

    // Main CPU
    input            main_cs,
    input            vram_cs,
    input            ram_cs,
    input     [18:1] main_addr,
    output           xram_cs,
    output reg [18:1] xram_addr,

    // Sound CPU
    output           mc8123_we,

    // PROM
    output           n7751_prom,
    output           mcu_we,
    output  reg      mcu_en,

    // ADPCM ROM
    output  reg      dec_en,
    output  reg      fd1089_en,
    output  reg      fd1094_en,
    output  reg      mc8123_en,
    output  reg      dec_type,

    input    [13:2]  char_addr, // 9 addr + 3 vertical + 2 horizontal = 14 bits
    input    [17:2]  scr1_addr, // 1 bank + 12 addr + 3 vertical = 15 bits
    input    [17:2]  scr2_addr, // 1 bank + 12 addr + 3 vertical = 15 bits
    input    [19:0]  obj_addr,
    // Scroll address after banking
    output   [19:2]  char_adj,
    output   [19:2]  scr1_adj,
    output   [19:2]  scr2_adj,
    output reg [19:0]  obj_addr_g,

    input    [21:0]  prog_addr,
    input    [ 7:0]  prog_data,
    input            prog_we,
    input            prom_we,
    input            header
);

/* verilator lint_off WIDTH */
localparam [24:0] MCU_PROM   = `MCU_START,
                  N7751_PROM = `N7751_START,
                  KEY_PROM   = `MAINKEY_START,
                  MC8123_PROM= `SNDKEY_START,
                  FD_PROM    = `FD1089_START;

localparam [ 7:0] GAME_FANTZN2X = `GAME_FANTZN2X;
/* verilator lint_on WIDTH */

localparam VRAMW = `VRAMW;
localparam [7:0] DUNKSHOT='h14;

wire [ 7:0] key_din;
wire [12:0] key_mux;

// S16A = 32 kB VRAM + 16kB RAM
// S16B = 64 kB VRAM + 16-256kB RAM
wire        fd_we;


assign xram_cs    = ram_cs | vram_cs;
assign gfx_cs     = LVBL || vrender==0 || vrender[8];
assign n7751_prom = prom_we && prog_addr[21:10]==N7751_PROM [21:10];
assign fd_we      = prom_we && prog_addr[21:13]==KEY_PROM   [21:13];
assign fd1089_we  = prom_we && prog_addr[21: 8]==FD_PROM    [21: 8];
assign mcu_we     = prom_we && prog_addr[21:12]==MCU_PROM   [21:12];
assign mc8123_we  = prom_we && prog_addr[21:13]==MC8123_PROM[21:13];
assign key_we     = mc8123_en ? mc8123_we : fd_we;
assign key_din    = prog_data^{8{mc8123_en}}; // the data is inverted for the MC8123
assign key_mux    = mc8123_en ? key_mcaddr : key_addr;

`ifdef S16B
reg dunkshot, game_fantzn2x;

always @(posedge clk) begin
    dunkshot      <= game_id == DUNKSHOT;
    game_fantzn2x <= game_id == GAME_FANTZN2X;
end
`endif

always @(*) begin
    xram_addr = 0;
    xram_addr[VRAMW-1:1] = { ram_cs, main_addr[VRAMW-2:1] }; // RAM is mapped up
`ifndef S16B
    if( ram_cs ) xram_addr[VRAMW-2:14]=0; // only 16kB for RAM
`else
    // Mask RAM for System16B too, but no for System16C
    if( ram_cs && !game_fantzn2x ) xram_addr[VRAMW-2:14]=0; // only 16kB for RAM
    if( vram_cs ) xram_addr[VRAMW-2:16]=0;
`endif
end

always @(posedge clk) begin
    if( header && prog_we ) begin
        if( prog_addr[4:0]==5'h10 ) begin
            fd1089_en <= |prog_data[1:0];
            dec_type  <= prog_data[1];
        end
        if( prog_addr[4:0]==5'h11 ) fd1094_en <= prog_data[0];
        if( prog_addr[4:0]==5'h12 ) mc8123_en <= prog_data[0];
        if( prog_addr[4:0]==5'h13 ) mcu_en    <= prog_data[0];
        if( prog_addr[4:0]==5'h18 ) game_id   <= prog_data;
    end
    dec_en <= fd1089_en | fd1094_en;
end

jtframe_prom #(.AW(13),.SIMFILE("317-5021.key")) u_key(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( key_din   ),
    .rd_addr( key_mux   ),
    .wr_addr( prog_addr[12:0] ),
    .we     ( key_we    ),
    .q      ( key_data  )
);

`ifdef S16B
    reg single_bank;
    always @(posedge clk) begin
        single_bank <= game_id[4];
                    //game_id==8'h10 || // shinobi2/5
                    //game_id==8'h1A || // shinobi3
                    //game_id==8'h11 || // afighterh/g/f
                    //game_id==8'h16 || // aliensyn7
                    //game_id==8'h19 || // defense
    end
    assign char_adj = { tile_bank[2:0], 3'd0, char_addr };
    assign scr1_adj = { single_bank ? {2'b0, scr1_addr[17] } :
                      scr1_addr[17] ? tile_bank[5:3] : tile_bank[2:0], scr1_addr[16:2] };
    assign scr2_adj = { single_bank ? {2'b0, scr2_addr[17] } :
                      scr2_addr[17] ? tile_bank[5:3] : tile_bank[2:0], scr2_addr[16:2] };
`else
    assign char_adj = { 6'd0, char_addr };
    assign scr1_adj = { 2'd0, scr1_addr };
    assign scr2_adj = { 2'd0, scr2_addr };
`endif

always @(*) begin
    obj_addr_g = obj_addr;
`ifdef S16B
    if( dunkshot ) obj_addr_g[15]=0;
`endif
end

endmodule