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
    output            hflip_en, // info was allowed to flow by means of the
                                // BEN pin. This approach is clearer

    // tile ROM addressing
    // original pins: { CAB2,CAB1,VC[10:0] }
    // [2:0] tile row (8 lines)
    output reg [12:0] fix_addr,
    output reg [12:0] lyra_addr,
    output reg [12:0] lyrb_addr,
    output reg [ 7:0] fix_col,
    output reg [ 7:0] lyra_col,
    output reg [ 7:0] lyrb_col,

    // subtile addressing
    output     [ 2:0] lyra_hsub,   // original pins: { ZA4H, ZA2H, ZA1H }
    output     [ 2:0] lyrb_hsub    // original pins: { ZB4H, ZB2H, ZB1H }
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


// tile map addressing
wire [15:0] scan_dout,
reg  [ 7:0] mmr[0:6], col_cfg,
            vposa, vposb;
reg  [ 8:0] hposa, hposb;
wire [ 7:0] bank0, bank1,
            code, attr, int_en;
reg  [10:0] map_a, map_b;
reg  [12:0] vaddr, vaddr_nx;
reg  [ 1:0] col_aux;
reg  [ 1:0] cab,         // tile address MSB
            ba_lsb,      // bank lower 2 bits
            v8, vflip_en,
            rscra, rscrb;// row scroll
wire [ 1:0] fine_row;    // high sets scroll per row, otherwise per 8 rows
wire        same_col_n;  // layer B uses the same attribute data as layer A
reg         v4_l;
reg         reg_we, cscra_en, cscrb_en;

assign bank0       = mmr[REG_BANK0];
assign bank1       = mmr[REG_BANK1];
assign cfg         = mmr[REG_CFG];
assign int_en      = mmr[REG_INT];
assign flip        = mmr[REG_FLIP][0];
assign hflip_en    = mmr[REG_FLIP][1];
assign vflip_en    = mmr[REG_FLIP][2];
assign same_col_n  = cfg[5];
assign rom_addr   = { cab, tile_lsb };
assign {attr,code} = din;
assign { cscrb_en, rscrb, cscra_en, rscra } = mmr[REG_SCR];
assign fine_row    = {mmr[REG_SCR][3], mmr[REG_SCR][0]};
// read vpos when col scr is disabled
assign rd_vpos     = |{hdumpf[8:7], ~hdumpf[6:5], hdumpf[4], hdump[3]};

always @* begin
    heff_a = { {6{flip}},  1'b0, {2{flip}} } + hposa;
    // H part of the scan
    { map_a[5:0],hsuba_nx } =
        { hdumpf[8:3] + heff_a[8:3], hdump[2:0] + (heff_a[2:0]^{3{flip}})};
    { map_b[5:0],hsubb_nx } =
        { hdumpf[8:3] + heff_b[8:3], hdump[2:0] + (heff_b[2:0]^{3{flip}})};
    // V part of the scan
    { map_a[10:6], vsub_a } = vdump + vposa;
    { map_b[10:6], vsub_b } = vdump + vposb;
    scrlyr_sel = hdump[3];
    hdumpf = hdump^{9{flip}};
    rd_scr = rd_rowscr

    case( hdump[2:1] )
        0: vaddr_nx = { 3'b110, rd_rowscr ?
            {1'b1, hdump[7:3], hdump[2:0] & {3{fine_row[scrlyr_sel]}}, scrlyr_sel } :
            {4'd0, hdumpf[8:3] + {6{flip}} } };
        1: vaddr_nx = { 2'b01, map_a }; // tilemap A
        2: vaddr_nx = { 2'b10, map_b }; // tilemap B
        3: vaddr_nx = { 2'b00, vpos[7:3], hdump[8:3] }; // fix
    endcase
end

always @* begin
    col_cfg = scan_dout[15:8];
    case(col_cfg[3:2])
        2'd0: { cab, col_aux } = bank0[3:0];
        2'd1: { cab, col_aux } = bank0[7:4];
        2'd2: { cab, col_aux } = bank1[3:0];
        2'd3: { cab, col_aux } = bank1[7:4];
    endcase
    if( !cfg[5] ) col_cfg[3:2] = col_aux;
    // ROM address
    case( hdump[2:1] )
        1: vmux = vsub_a;
        2: vmux = vsub_b;
        default:  vmux = vdump[2:0]; // this is latched in the original
    endcase
    vflip = col_cfg[1] & vflip_en;
    vc = { scan_dout[7:0], vmux^{3{vflip}} };
    if( rmrd    ) begin
        col_cfg = mmr[REG_RMRD];
        vc      = addr[12:2];
    end
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

always @(posedge clk) begin
    if( rst ) begin
        rd_rowscr <= 0;
        vaddr     <= 0;
        fix_col   <= 0;
        lyra_col  <= 0;
        lyrb_col  <= 0;
        fix_addr  <= 0;
        lyra_addr <= 0;
        lyrb_addr <= 0;
    end else begin
        vaddr <= vaddr_nx;
        if(pxl_cen) case( hdump[2:1] )
            // 0: if(rd_vpos||)
            1: begin fix_col  <= col_cfg; fix_addr  <= { cab, vc }; end
            2: begin lyra_col <= col_cfg; lyra_addr <= { cab, vc }; end
            2: begin lyrb_col <= col_cfg; lyrb_addr <= { cab, vc }; end
        endcase
        rd_rowscr <= hpos<9'h60;
    end
end

jtframe_dual_ram #(.AW(13)) u_ram(
    // Port 0: CPU
    .clk0   ( clk            ),
    .data0  ( din            ),
    .addr0  ( cpu_addr[12:0] ),
    .we0    ( we[1]          ),
    .q0     ( cpu_code       ),
    // Port 1
    .clk1   ( clk            ),
    .data1  ( 8'd0           ),
    .addr1  ( vaddr          ),
    .we1    ( 1'b0           ),
    .q1     ( scan_dout[15:8])
);

jtframe_dual_ram #(.AW(13)) u_ram(
    // Port 0: CPU
    .clk0   ( clk            ),
    .data0  ( din            ),
    .addr0  ( cpu_addr[12:0] ),
    .we0    ( we[2]          ),
    .q0     ( cpu_code       ),
    // Port 1
    .clk1   ( clk            ),
    .data1  ( 8'd0           ),
    .addr1  ( vaddr          ),
    .we1    ( 1'b0           ),
    .q1     ( scan_dout[ 7:0])
);

endmodule
