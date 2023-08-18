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
    input             pxl2_cen, // used for E/Q generation

    input             lvbl,
    // CPU interface
    input             gfx_cs,
    input             cpu_we,
    input      [ 7:0] cpu_dout,      // data can be written to any RAM chip attached
    input      [15:0] cpu_addr,
    output reg [ 7:0] cpu_din,     // only half data bus available upon settings
    output reg        rst8,     // reset signal at 8th frame

    // Fine grain scroll
    output reg [ 2:0] hsub_a, hsub_b,

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
    output reg [12:0] lyrf_addr,
    output reg [12:0] lyra_addr,
    output reg [12:0] lyrb_addr,
    output reg [ 7:0] lyrf_col,
    output reg [ 7:0] lyra_col,
    output reg [ 7:0] lyrb_col,

    output reg         e, q,        // 3MHz signals, Q is 1/4 wave ahead

    // Debug
    input      [14:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,
    output     [ 7:0] mmr_dump,

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
reg  [ 8:0] hposa, hposb, heff_a, heff_b, vdumpf;
reg  [ 8:0] hdumpf;
wire [ 7:0] bank0, bank1, cfg, int_en,
            cpu_attr, cpu_code;
reg  [10:0] map_a, map_b, vc;
reg  [12:0] vaddr, vaddr_nx;
reg  [ 1:0] col_aux;
reg  [ 1:0] cab,         // tile address MSB
            ba_lsb,      // bank lower 2 bits
            rscra, rscrb;// row scroll
reg  [ 2:1] we;
reg  [ 2:0] vsub_a, vsub_b, vmux, cs, rst_cnt;
wire [ 1:0] fine_row;    // high sets scroll per row, otherwise per 8 rows
wire        rd_vpos, rd_hpos, scrlyr_sel;
reg         v4_l, rd_rowscr, vflip;
wire        cscra_en, cscrb_en, reg_we,
            rscra_en, rscrb_en, vflip_en;
wire [ 2:0] reg_addr;

assign reg_addr    = cpu_addr[9:7];
assign bank0       = mmr[REG_BANK0];
assign bank1       = mmr[REG_BANK1];
assign cfg         = mmr[REG_CFG];
assign int_en      = mmr[REG_INT];
assign flip        = mmr[REG_FLIP][0];
assign hflip_en    = mmr[REG_FLIP][1];
assign vflip_en    = mmr[REG_FLIP][2];
assign { cscrb_en, rscrb_en, fine_row[1], cscra_en, rscra_en, fine_row[0] }
                   = mmr[REG_SCR][5:0];
// read vpos when col scr is disabled
assign rd_vpos     = hdump[8:3]==6'hC; // 9'h60 >> 3, should this be:
    // |{hdumpf[8:7], ~hdumpf[6:5], hdumpf[4], hdump[3]}; //instead?
assign rd_hpos     = vdump[7:0]==0;
assign scrlyr_sel  = hdump[1];
assign reg_we      = &{cpu_we,we[1],cpu_addr[12:10],gfx_cs};
assign mmr_dump    = mmr[ioctl_addr[2:0]];
assign ioctl_din   = ioctl_addr[13] ? scan_dout[15:8] : scan_dout[7:0];

reg  [5:0] range;
wire [3:0] range0 = range[5:2],
           range1 = range[3:0],
           range2 = range[4:1];

always @(posedge clk) begin // 3MHz signals
    if( pxl_cen  ) q <= ~q;
    if( pxl2_cen ) e <= q;
end

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

reg ca, cb;

always @* begin
    hdumpf = rd_rowscr || !flip ? hdump : ~hdump+9'd1;
    // 20~19F range moved to 30~1AF, active video from 60~19F
    if( hdumpf < 9'h030 ) hdumpf = hdumpf+9'h180;
    if( hdumpf > 9'h1af ) hdumpf = hdumpf-9'h180;
    heff_a = hposa - 9'd6;
    heff_b = hposb - 9'd6;

    // H part of the scan
    { ca, hsub_a } = { 1'b0, hdumpf[2:0] } + {1'd0,heff_a[2:0]};
    { cb, hsub_b } = { 1'b0, hdumpf[2:0] } + {1'd0,heff_b[2:0]};
    map_a[5:0] = hdumpf[8:3] + heff_a[8:3] + {5'd0,ca};
    map_b[5:0] = hdumpf[8:3] + heff_b[8:3] + {5'd0,cb};
    // V part of the scan
    { map_a[10:6], vsub_a } = vdumpf[7:0] + vposa;
    { map_b[10:6], vsub_b } = vdumpf[7:0] + vposb;

    // scan address
    if( rd_rowscr ) begin
        vaddr_nx = { 4'b110_1, vdumpf[7:3],
            vdump[2:0] & {3{fine_row[scrlyr_sel]}}, hdump[0] };
    end else begin case( hdump[1:0] )
            0: vaddr_nx = { 7'b110_0000, hdump[8:3] }; // col. scroll
            1: vaddr_nx = { 2'b01, map_a }; // tilemap A
            2: vaddr_nx = { 2'b10, map_b }; // tilemap B
            3: vaddr_nx = { 2'b00, vdumpf[7:3], hdumpf[8:3] }; // fix
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
    if( rmrd ) col_cfg = mmr[REG_RMRD];
    vflip = col_cfg[1] & vflip_en; // must be after rmrd check, as it changes col_cfg
    vc = rmrd ? cpu_addr[12:2] : { scan_dout[7:0], vmux^{3{vflip}} };
end

`ifdef SIMULATION
reg [7:0] mmr_init[0:6];
integer f,fcnt=0;

initial begin
    f=$fopen("scr_mmr.bin","rb");
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $fclose(f);
        $display("Read %1d bytes for 052109 MMR", fcnt);
    end
end
`endif

// Register map
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mmr[0]  <= 0; mmr[1] <= 0; mmr[2] <= 0; mmr[3] <= 0;
        mmr[4]  <= 0; mmr[5] <= 0; mmr[6] <= 0;
`ifdef SIMULATION
        if( fcnt!=0 ) begin
            mmr[0] <= mmr_init[0];
            mmr[1] <= mmr_init[1];
            mmr[2] <= mmr_init[2];
            mmr[3] <= mmr_init[3];
            mmr[4] <= mmr_init[4];
            mmr[5] <= mmr_init[5];
            mmr[6] <= mmr_init[6];
        end
`endif
        st_dout <= 0;
    end else begin
        if( reg_we ) begin
            mmr[reg_addr] <= cpu_dout;
// `ifdef SIMULATION
//             $display("TILE mmr[%d] <= %02X (cpu_addr=%x)", cpu_addr[9:7], cpu_dout, cpu_addr);
// `endif
        end
        if( debug_bus[3] ) begin
            case( debug_bus[2:0] )
                0: st_dout <= hposa[7:0];
                1: st_dout <= hposa[8:1];
                2: st_dout <= vposa[7:0];
                4: st_dout <= hposb[7:0];
                5: st_dout <= hposb[8:1];
                6: st_dout <= vposb[7:0];
                7: st_dout <= { flip, 1'd0, rscra_en, rscrb_en, 2'd0, cscra_en, cscrb_en };
            endcase
        end else begin
            st_dout <= mmr[debug_bus[2:0]];
        end
    end
end

// Interrupt handling - the bit mask is different in the K051960 (objects)
jtframe_edge #(.QSET(0)) u_irq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~lvbl     ),
    .clr    (~int_en[2] ),
    .q      ( irq_n     )
);

jtframe_edge #(.QSET(0)) u_firq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( vdump[0]  ),
    .clr    (~int_en[1] ),
    .q      ( firq_n    )
);

jtframe_edge #(.QSET(0)) u_nmi(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( vdump[4:0]==4 ), // every 32 lines
    .clr    (~int_en[0] ),
    .q      ( nmi_n     )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        v4_l    <= 0;
        rst_cnt <= `ifdef SIMULATION 7 `else 0 `endif;
        rst8    <= 1;
    end else if( pxl_cen ) begin
        v4_l <= vdump[2];
        if( vdump=='hf8 && rst8 && v4_l ) { rst8, rst_cnt } <= { rst8, rst_cnt } + 1'd1;
    end
end

// integer framecnt=0;
// integer vdumpl=0;

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
        // hposa     <= 0;
        // hposb     <= 0;
        vposa     <= 0;
        vposb     <= 0;
        vdumpf    <= 0;
    end else begin
// `ifdef SIMULATION
//         vdumpl <= vdump;
//         if( vdump==8'hfc && vdumpl!=8'hfc  ) framecnt <= framecnt+1;
// `endif
        vaddr     <= vaddr_nx;
        // rd_rowscr: 9'h27 prevents wrong data on right border on (flip mode)
        rd_rowscr <= hdump<9'h4f && hdump>9'h27;
        vdumpf    <= rd_rowscr ? vdump : vdump^{9{flip}};
        if( pxl_cen ) begin
            if( !rd_rowscr ) case( hdump[1:0] )
                0: begin
                    if( rd_vpos || cscra_en )
                        vposa <= scan_dout[15:8];
                    if( rd_vpos || cscrb_en )
                        vposb <= scan_dout[ 7:0];
                end
                1: begin lyra_col <= col_cfg; lyra_addr <= { cab, vc }; end
                2: begin lyrb_col  <= col_cfg; lyrb_addr <= { cab, vc };end
                3: begin lyrf_col <= col_cfg; lyrf_addr <= { cab, vc[10:3], vc[2:0]^{3{flip}} }; end
            endcase else case( hdump[1:0] ) // row scroll position reading
                0: if( rd_hpos || rscra_en ) hposa[7:0] <= scan_dout[15:8];
                1: if( rd_hpos || rscra_en ) hposa[8]   <= scan_dout[8];
                2: if( rd_hpos || rscrb_en ) hposb[7:0] <= scan_dout[7:0];
                3: if( rd_hpos || rscrb_en ) hposb[8]   <= scan_dout[0];
            endcase
        end
        if( rmrd ) lyra_addr <= { cab, cpu_addr[12:2] };
    end
end

jtframe_dual_nvram #(.AW(13),.SIMFILE("scr0.bin")) u_attr(
    // Port 0: CPU
    .clk0   ( clk            ),
    .data0  ( cpu_dout       ),
    .addr0  ( cpu_addr[12:0] ),
    .we0    ( we[1]          ),
    .q0     ( cpu_attr       ),
    // Port 1
    .clk1   ( clk            ),
    .addr1a ( vaddr          ),
    .addr1b (ioctl_addr[12:0]),
    .sel_b  ( ioctl_ram      ),
    .data1  ( 8'd0           ),
    .we_b   ( 1'b0           ),
    .q1     ( scan_dout[15:8])  // color
);

jtframe_dual_nvram #(.AW(13),.SIMFILE("scr1.bin")) u_code(
    // Port 0: CPU
    .clk0   ( clk            ),
    .data0  ( cpu_dout       ),
    .addr0  ( cpu_addr[12:0] ),
    .we0    ( we[2]          ),
    .q0     ( cpu_code       ),
    // Port 1
    .clk1   ( clk            ),
    .addr1a ( vaddr          ),
    .addr1b (ioctl_addr[12:0]),
    .sel_b  ( ioctl_ram      ),
    .data1  ( 8'd0           ),
    .we_b   ( 1'b0           ),
    .q1     ( scan_dout[ 7:0])  // code
);

endmodule
