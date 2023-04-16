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
// 8x8 tiles
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
    input      [ 7:0] din,      // data can be written to any RAM chip attached
    input      [15:0] addr,
    output            dout,     // only half data bus available upon settings
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines

    output            irq_n,
    output            firq_n,
    output            nmi_n,
    output            flip,     // not a pin in the original, but the flip
                                // info was allowed to flow by means of the
                                // BEN pin. This approach is clearer

    // tile map addressing
    output     [12:1] vaddr,
    input      [15:0] din,

    // tile ROM addressing
    output     [12:0] rom_addr, // original pins: { CAB2,CAB1,VC[10:0] }
                                // [2:0] tile row (8 lines)
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
                  REG_FLIP  = 5, // 1E80                    only 1 bit used
                  REG_BANK1 = 6; // 1F00

// REG_CFG bits 1:0 act as a memory mapper, allowing up to 3 RAM chips
// to be connected to the K052109, but the third chip
//    ATTR CODE CPU-only
//    RWE0 RWE1 RWE2
//    VCS0 VCS1
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
           ba_lsb,      // bank lower 2 bits
           v8, vflip_en,
           rscra, rscrb;// row scroll
wire [1:0] fine_row;    // high sets scroll per row, otherwise per 8 rows
wire       same_col_n;  // layer B uses the same attribute data as layer A
reg        v4_l;
reg        reg_we, cscra_en, cscrb_en;

assign bank0       = mmr[REG_BANK0];
assign bank1       = mmr[REG_BANK1];
assign cfg         = mmr[REG_CFG];
assign int_en      = mmr[REG_INT];
assign flip        = mmr[REG_FLIP][0];
assign vflip_en    = mmr[REG_FLIP][2];
assign same_col_n  = cfg[5];
assign rom_addr   = { cab, tile_lsb };
assign {attr,code} = din;
assign { cscrb_en, rscrb, cscra_en, rscra } = mmr[REG_SCR];
assign fine_row    = {mmr[REG_SCR][5], mmr[REG_SCR][2]};

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
        v8     <= 0;
        irq_n  <= 0;
        firq_n <= 0;
        nirq_n <= 0;
    end else if( pxl_cen ) begin
        v4_l <= vdump[2];
        if( vdump[2] && !v4_l ) v8 <= v8+2'd1;
        if( vdump[7:0]=='hf8 ) irq_n <= int_en[2]; // once per frame
        if( vdump     =='h10 ) irq_n <= 1;
        firq_n <= vdump[0] && int_en[1]; // once every 2 lines
        nmi_n  <= v8[1]    && int_en[0]; // once every 32 lines
    end
end

always @* begin
    scrlyr_sel = hdump[3];
    hdumpf = hdump^{9{flip}};
    case( hdump[2:1] )
        0: vaddr_nx = { 3'b110, rd_rowscr ?
            {1'b1, hdump[7:3], hdump[2:0] & {3{fine_row[scrlyr_sel]}}, scrlyr_sel } :
            {4'd0, hdumpf[8:3] + {6{flip}} } };
        1: vaddr_nx = { 2'b01, }; // tilemap A
        2: vaddr_nx = { 2'b10, }; // tilemap B
        3: vaddr_nx = { 2'b00, vpos[7:3], hdump[8:3] };
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        rd_rowscr <= 0;
    end else begin
        rd_rowscr <= hpos<9'h60;
        col <= rmrd ? mmr[REG_RMRD] : lyr_col;
        tile_lsb <= rmrd ? cpu_addr[12:2] : { lyr_code, lyr_v ^ {3{vflip_en&lyr_col[1]}} };
        // at some specific state
        lyra_attr <= attr;
        lyrb_attr <= attr;
    end
end

endmodule