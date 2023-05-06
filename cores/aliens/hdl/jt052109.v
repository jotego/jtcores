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

// The scroll data can be read only at the beginning of a frame, 8-pxl row,
// row or 8-pixel column.

module jt052109(
    input             rst,
    input             clk,
    input             pxl_cen,

    // CPU interface
    input             gfx_cs,
    input             cpu_we,
    input      [ 7:0] cpu_dout,      // data can be written to any RAM chip attached
    input      [15:0] cpu_addr,
    output reg [ 7:0] cpu_din,     // only half data bus available upon settings
    output reg        rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines

    output reg        irq_n,
    output reg        firq_n,
    output reg        nmi_n,
    output            flip,     // not a pin in the original, but the flip
    output            hflip_en, // info was allowed to flow by means of the
                                // BEN pin. This approach is clearer

    // tile ROM addressing
    // original pins: { CAB2,CAB1,VC[10:0] }
    // [2:0] tile row (8 lines)
    output reg [12:0] lyrf_addr,
    output reg [12:0] lyra_addr,
    output reg [12:0] lyrb_addr,
    output reg [ 7:0] lyrf_col,
    output reg [ 7:0] lyra_col,
    output reg [ 7:0] lyrb_col,

    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
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
wire [15:0] scan_dout;
reg  [ 7:0] mmr[0:6], col_cfg,
            vposa, vposb;
reg  [ 8:0] hposa, hposb, heff_a, heff_b, flipk;
wire [ 8:0] hdumpf;
wire [ 7:0] bank0, bank1, cfg,
            code, attr, int_en,
            cpu_attr, cpu_code;
reg  [10:0] map_a, map_b, vc;
reg  [12:0] vaddr, vaddr_nx;
reg  [ 1:0] col_aux;
reg  [ 1:0] cab,         // tile address MSB
            ba_lsb,      // bank lower 2 bits
            v8,
            rscra, rscrb;// row scroll
reg  [ 2:1] we;
reg  [ 2:0] vsub_a, vsub_b, vmux, cs, nc, rst_cnt;
wire [ 1:0] fine_row;    // high sets scroll per row, otherwise per 8 rows
wire        same_col_n,  // layer B uses the same attribute data as layer A
            rd_vpos, rd_hpos, scrlyr_sel;
reg         v4_l, rd_rowscr, vflip;
wire        cscra_en, cscrb_en, reg_we,
            rscra_en, rscrb_en, vflip_en;

assign bank0       = mmr[REG_BANK0];
assign bank1       = mmr[REG_BANK1];
assign cfg         = mmr[REG_CFG];
assign int_en      = mmr[REG_INT];
assign flip        = mmr[REG_FLIP][0];
assign hflip_en    = mmr[REG_FLIP][1];
assign vflip_en    = mmr[REG_FLIP][2];
assign same_col_n  = cfg[5];
assign {attr,code} = scan_dout;
assign { cscrb_en, rscrb_en, fine_row[1], cscra_en, rscra_en, fine_row[0] }
                   = mmr[REG_SCR][5:0];
// read vpos when col scr is disabled
assign rd_vpos     = hdump[8:3]==6'hC; // 9'h60 >> 3, should this be:
    // |{hdumpf[8:7], ~hdumpf[6:5], hdumpf[4], hdump[3]}; instead?
assign rd_hpos     = vdump==0;
assign scrlyr_sel  = hdump[1];
assign reg_we      = &{cpu_we,we[1],cpu_addr[12:10],gfx_cs};
assign hdumpf      = hdump^{9{flip}};

reg  [5:0] range;
wire [3:0] range0 = range[5:2],
           range1 = range[3:0],
           range2 = range[4:1];
// CPU Memory Mapper
always @* begin
    casez( cpu_addr[15:13] )
        0: range = 6'b111110;    // 0000~1FFF
        1: range = 6'b111101;    // 2000~3FFF
        2: range = 6'b111011;    // 4000~5FFF
        3: range = 6'b110111;    // 6000~7FFF
        4: range = 6'b101111;    // 8000~9FFF
        5: range = 6'b011111;    // A000~BFFF
        default: range = 6'b111111;
    endcase
    cs[0] = ~range0[~cfg[1:0]];
    cs[1] = ~range1[~cfg[1:0]];
    cs[2] = ~range2[~cfg[1:0]];
    // WARNING: these are external connections and could change on
    // some games. If so, cs[2:0] should go out and re-tied at an upper level
    cpu_din = cs[1] ? cpu_attr : cpu_code;
    we[1]   = cs[1] & cpu_we & gfx_cs;
    we[2]   = cs[2] & cpu_we & gfx_cs;
end

always @* begin
    flipk  = { {6{flip}},  1'b0, {2{flip}} };
    heff_a = flipk + hposa;
    heff_b = flipk + hposb;
    // H part of the scan
    { map_a[5:0], nc } =
        { hdumpf[8:3] + heff_a[8:3], hdump[2:0] + (heff_a[2:0]^{3{flip}})};
    { map_b[5:0], nc } =
        { hdumpf[8:3] + heff_b[8:3], hdump[2:0] + (heff_b[2:0]^{3{flip}})};
    // V part of the scan
    { map_a[10:6], vsub_a } = vdump[7:0] + vposa;
    { map_b[10:6], vsub_b } = vdump[7:0] + vposb;

    if( rd_rowscr ) begin
        vaddr_nx = { 4'b110_1, vdump[7:3],
            vdump[2:0] & {3{fine_row[scrlyr_sel]}}, hdump[0] };
    end else begin case( hdump[1:0] )
            0: vaddr_nx = { 7'b110_0000, hdumpf[8:3] + {6{flip}} }; // col. scroll
            1: vaddr_nx = { 2'b01, map_a }; // tilemap A
            2: vaddr_nx = { 2'b10, map_b }; // tilemap B
            3: vaddr_nx = { 2'b00, vdump[7:3], hdump[8:3] }; // fix
        endcase
    end
end

always @* begin
    col_cfg = scan_dout[15:8];
    case(col_cfg[3:2])
        0: { cab, col_aux } = bank0[3:0];
        1: { cab, col_aux } = bank0[7:4];
        2: { cab, col_aux } = bank1[3:0];
        3: { cab, col_aux } = bank1[7:4];
    endcase
    if( !cfg[5] ) col_cfg[3:2] = col_aux;
    // ROM address
    case( hdump[1:0] )
        1: vmux = vsub_a;
        2: vmux = vsub_b;
        default:  vmux = vdump[2:0]; // this is latched in the original
    endcase
    vflip = col_cfg[1] & vflip_en;
    vc = { scan_dout[7:0], vmux^{3{vflip}} };
    if( rmrd    ) begin
        col_cfg = mmr[REG_RMRD];
        vc      = cpu_addr[12:2];
    end
end

// Register map
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mmr[0]  <= 0; mmr[1] <= 0; mmr[2] <= 0; mmr[3] <= 0;
        mmr[4]  <= 0; mmr[5] <= 0; mmr[6] <= 0;
        st_dout <= 0;
    end else begin
        if( reg_we ) begin
            mmr[cpu_addr[9:7]] <= cpu_dout;
`ifdef SIMULATION
            $display("TILE mmr[%d] <= %02X (cpu_addr=%x)", cpu_addr[9:7], cpu_dout, cpu_addr);
`endif
        end
        st_dout <= mmr[debug_bus[2:0]];
    end
end

// Interrupt handling
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        v4_l    <= 0;
        v8      <= 0;
        irq_n   <= 0;
        firq_n  <= 0;
        nmi_n   <= 0;
        rst_cnt <= 0;
        rst8    <= 0;
    end else if( pxl_cen ) begin
        v4_l <= vdump[2];
        if( vdump[2] && !v4_l ) v8 <= v8+2'd1;
        if( vdump[7:0]=='hf8 && !rst8 ) { rst8, rst_cnt } <= { rst8, rst_cnt } + 1'd1;
        if( vdump     =='h10 ) irq_n <= 1;
        irq_n  <= vdump[7:0]=='hf8 || !int_en[2]; // once per frame
        firq_n <= vdump[0] || !int_en[1]; // once every 2 lines
        nmi_n  <= v8[1]    || !int_en[0]; // once every 32 lines
    end
end

always @(posedge clk) begin
    if( rst ) begin
        rd_rowscr <= 0;
        vaddr     <= 0;
        lyrf_col  <= 0;
        lyra_col  <= 0;
        lyrb_col  <= 0;
        lyrf_addr  <= 0;
        lyra_addr <= 0;
        lyrb_addr <= 0;
        hposa     <= 0;
        hposb     <= 0;
        vposa     <= 0;
        vposb     <= 0;
    end else begin
        vaddr     <= vaddr_nx;
        rd_rowscr <= hdump<9'h4f;
        if( pxl_cen ) begin
            if( !rd_rowscr ) case( hdump[1:0] )
                0: begin
                    if( rd_vpos || cscra_en )
                        vposa <= scan_dout[15:8];
                    if( rd_vpos || cscrb_en )
                        vposb <= scan_dout[ 7:0];
                end
                1: begin lyra_col <= col_cfg; lyra_addr <= { cab, vc }; end
                2: begin lyrb_col <= col_cfg; lyrb_addr <= { cab, vc }; end
                3: begin lyrf_col <= col_cfg; lyrf_addr  <= { cab, vc }; end
            endcase
        end else begin case( hdump[1:0] )
                0: if( rd_hpos || rscra_en ) hposa[7:0] <= scan_dout[15:8];
                1: if( rd_hpos || rscra_en ) hposa[8]   <= scan_dout[8];
                2: if( rd_hpos || rscrb_en ) hposb[7:0] <= scan_dout[7:0];
                3: if( rd_hpos || rscrb_en ) hposb[8]   <= scan_dout[0];
            endcase
        end
    end
end

jtframe_dual_ram #(.AW(13),.SIMFILE("scr0.bin")) u_attr(
    // Port 0: CPU
    .clk0   ( clk            ),
    .data0  ( cpu_dout       ),
    .addr0  ( cpu_addr[12:0] ),
    .we0    ( we[1]          ),
    .q0     ( cpu_attr       ),
    // Port 1
    .clk1   ( clk            ),
    .data1  ( 8'd0           ),
    .addr1  ( vaddr          ),
    .we1    ( 1'b0           ),
    .q1     ( scan_dout[15:8])
);

jtframe_dual_ram #(.AW(13),.SIMFILE("scr1.bin")) u_code(
    // Port 0: CPU
    .clk0   ( clk            ),
    .data0  ( cpu_dout       ),
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
