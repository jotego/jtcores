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
    Date: 15-4-2023 */

// Based on Furrtek's RE work on die shots
// and MAME documentation

// Games that may be using this chip
// _88games, ajax, aliens, blockhl, blswhstl, bottom9, crimfght, cuebrick,
// ddboy, devstors, esckids, fuusenpn, gbusters, glfgreat, gradius3, lgtnfght,
// mainevt, mariorou, mia, parodius, prmrsocr, punkshot, scontra, shuriboy,
// simpsons, spy, ssriders, sunsetbl, surpratk, thndrx2, thunderx, tmnt, tmnt2,
// tsukande, tsupenta, tsururin, vendetta, xmen, xmen6p, xmenabl


module jt052109(
    input             rst,
    input             clk,
    input             pxl_cen,

    // CPU interface
    input             we,
    input      [ 7:0] din,
    input      [15:0] addr,
    output            dout,

    // control
    input             rmrd,     // Tile ROM read mode
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines

    output            irq_n,
    output            firq_n,
    output            nmi_n,

    // VRAM connection
    output     [12:1] vaddr,
    input      [15:0] din,

    // tile map addressing
    output     [12:0] tile_addr, // original pins: { CAB2,CAB1,VC[10:0] }
    output reg [ 7:0] col,

    // subtile addressing
    output     [ 2:0] hsub_a,   // original pins: { ZA4H, ZA2H, ZA1H }
    output     [ 2:0] hsub_b,   // original pins: { ZB4H, ZB2H, ZB1H }

    // config to drawing chip 051962
    output            flip_up,  // original pin: BEN
);

// MMR go from 1C00 to 1F00
localparam [15:0] REGBASE = 16'h1C00;
// bits 9-7 of address select the register
localparam [ 2:0] REG_CFG   = 0, // 1C00 set at start up,   only 6 bits used
                  REG_SCR   = 1, // 1C80 row/col scroll
                  REG_INT   = 2, // 1D00 interrupt control, only 3 bits used
                  REG_BANK0 = 3, // 1D80
                  REG_RMRD  = 4, // 1E00 bank selector during test
                  REG_FLIP  = 5, // 1E80
                  REG_BANK1 = 6; // 1F00

// REG_CFG bits 1:0 act as a memory mapper, allowing up to 3 RAM chips
// to be connected to the K052109, but the third chip
//    ATTR CODE CPU-only
//    RWE0 RWE1
//    VCS0 VCS1 RWE2
// 00 A~B  6~7  8~9  Reset state
// 01 8~9  4~5  6~7
// 10 6~7  2~3  4~5
// 11 4~5  0~1  2~3
//
// Code RAM is always mapped to the lower 8kB
// Attr RAM mapped to the higher 8kB
// CPU  RAM mapped in the middle of the two

reg  [7:0] mmr[0:6];
reg  [7:0] lyra_attr, lyrb_attr;
wire [7:0] bank0, bank1,
           code, attr, int_en;
reg  [1:0] col_mux_a;
reg  [1:0] cab,         // tile address MSB
           ba_lsb;      // bank lower 2 bits
wire       same_col_n;  // layer B uses the same attribute data as layer A
reg        v4_l;
reg        reg_we;

assign bank0       = mmr[REG_BANK0];
assign bank1       = mmr[REG_BANK1];
assign cfg         = mmr[REG_CFG];
assign int_en      = mmr[REG_INT];
assign same_col_n  = cfg[5];
assign tile_addr   = { cab, tile_lsb };
assign {attr,code} = din;

always @(*) begin
    act_col = (same_col_n & some_sel) ? lyra_attr : lyrb_attr;
    case(act_col[3:2])
        2'd0: {cab, ba_lsb } = bank0[3:0];
        2'd1: {cab, ba_lsb } = bank0[7:4];
        2'd2: {cab, ba_lsb } = bank1[3:0];
        2'd3: {cab, ba_lsb } = bank1[7:4];
    endcase
    lyr_col = act_col;
    if( cfg[5] ) lyr_col[3:2] = ba_lsb;
end

// Register map
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mmr[0] <= 0; mmr[1] <= 0; mmr[2] <= 0; mmr[3] <= 0;
        mmr[4] <= 0; mmr[5] <= 0; mmr[6] <= 0; mmr[7] <= 0;
    end else begin
        if( &{reg_we,A[12:10]} ) mmr[A[9:7]] <= din;
    end
end

// Interrupt handling
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        v4_l   <= 0;
        irq_n  <= 0;
        firq_n <= 0;
        nirq_n <= 0;
    end else if( pxl_cen ) begin
        v4_l <= vdump[2];
        if( vdump[2] && !v4_l ) v8 <= ~v8;
        if( vdump[7:0]=='hf8 ) irq_n <= int_en[2]; // once per frame
        if( vdump     ==0    ) irq_n <= 1;
        firq_n <= vdump[0] && int_en[1]; // once every 2 lines
        nmi_n  <= v8       && int_en[0]; // once every 16 lines
    end
end

always @(posedge clk) begin
    col <= rmrd ? mmr[REG_RMRD] : lyr_col;
    // at some specific state
    lyra_attr <= attr;
    lyrb_attr <= attr;
end

endmodule