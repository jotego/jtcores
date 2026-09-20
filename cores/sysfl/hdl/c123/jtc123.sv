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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 18-9-2026
*/

// Namco 123+145 tilemap pair, System FL configuration
// 4 scrolling 64x64 + 2 fixed 36x28 layers, 8x8 tiles, 8bpp
// 16-bit tile codes, per-tile mask ROM byte row gives pixel opacity

module jtc123(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             hs,
    input             vs,
    input       [8:0] hdump,
    input       [8:0] vdump,
    input             flip,

    // CPU access to control registers
    input             cs,
    input       [5:1] addr,
    input             rnw,
    input       [1:0] dsn,
    input      [15:0] din,
    output     [15:0] dout,

    // Tile map readout (BRAM)
    output reg [15:1] tmap_addr,
    input      [15:0] tmap_data,
    // Mask readout (SDRAM)
    output            smask_cs,
    output     [18:0] smask_addr,
    input             smask_ok,
    input      [ 7:0] smask_data,
    // Tile readout (SDRAM)
    output            scr_cs,
    output reg [21:0] scr_addr,
    input             scr_ok,
    input      [ 7:0] scr_data,
    // Pixel output
    output     [11:0] scr_pxl,
    output     [ 2:0] scr_prio,
    output            scr_blankn,
    // IOCTL dump
    input      [ 5:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    // Debug
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

parameter SIMFILE="rest.bin", SEEK=0;


localparam [ 8:0] HMARGIN=9'h8,
                  HSTART=9'h40-HMARGIN,
                  HEND=9'd288+HSTART+(HMARGIN<<1), // hdump non blank from 'h40 to 'h160
                  VB_END=9'h120,
                  FLIP_DX=9'h5e;
localparam [15:0] VOFF=16'd248;                    // MAME dy=24, calibrate in sim
localparam [ 9:0] LIN0=10'd1, LIN0F=10'd973;

// Layer configuration
wire [3:0][ 8:0] hscr, vscr;
wire [5:0][ 2:0] cfg_pal, cfg_prio;
wire [5:0]       cfg_enb;
wire             cfg_flip, dflip;

reg  [15:0] hoff, hpos, vpos;
reg  [ 2:0] mlyr, mask_asub, mst;
reg  [ 6:0] attr;                  // opaque, priority, palette
wire [ 2:0] hsub;
reg  [ 7:0] mask[0:5], nmask[0:5];
reg  [24:0] info[0:5], ninfo[0:5]; // palette, code, tile row, column base
reg  [ 5:0] nrdy;                  // next tile of each layer prefetched
reg  [ 2:0] plyr;                  // layer being prefetched
reg  [ 2:0] poff;                  // column base of the prefetched tile
reg  [ 2:0] pcnt;                  // sub-tile counter of the prefetched layer
wire [ 5:0] xing, block;
wire [ 9:0] lin_next = lin_row + {4'd0,hcnt[3+:6]} - 10'd8;
reg  [ 8:0] hcnt, buf_a;
reg  [10:0] bpxl;
reg  [ 9:0] lin_row;               // linear row base for the fixed layers
reg  [ 2:0] bprio, cprio, win, hcnt0, hcnt1, hcnt2, hcnt3;
reg         done, alt_cen, opaque, bblankn;
wire [10:0] pxl;
wire [ 2:0] prio;
wire        blankn, buf_we, rom_ok, hs_edge;

// MAME dx = 44 + {4,2,1,0} per layer, calibrate hoff0 in sim
wire [15:0] hoff0 = dflip ? 16'h71 : -16'h0f;
wire [15:0] hoff1 = dflip ? hoff0 + 16'h2 : hoff0 - 16'h2;
wire [15:0] hoff2 = dflip ? hoff0 + 16'h3 : hoff0 - 16'h3;
wire [15:0] hoff3 = dflip ? hoff0 + 16'h4 : hoff0 - 16'h4;

integer     i, j;
`ifdef SIMULATION
    reg     miss;
`endif

assign scr_cs     = ~done;
assign smask_cs   = plyr!=7 && mst>=3; // tmap_data valid from mst 3
assign hsub       = hcnt[2:0];
assign buf_we     = alt_cen & ~done;
// a layer entering its next tile needs that tile's mask ready
assign xing      = { hcnt[2:0]==7, hcnt[2:0]==7, hcnt3==7, hcnt2==7, hcnt1==7, hcnt0==7 };
assign block      = xing & ~nrdy & ~cfg_enb;
assign rom_ok     = scr_ok & ~|block;
assign smask_addr = { tmap_data, mask_asub };
assign dflip      = flip ^ cfg_flip;
assign scr_pxl    = { 1'b0, pxl };
assign scr_prio   = prio;
assign scr_blankn = blankn;

jtsysfl_scr_mmr #(.SIMFILE(SIMFILE),.SEEK(SEEK)) u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( cs        ),
    .addr       ( addr      ),
    .rnw        ( rnw       ),
    .din        ( din       ),
    .dout       ( dout      ),
    .dsn        ( dsn       ),
    .hscr       ( hscr      ),
    .vscr       ( vscr      ),
    .flip       ( cfg_flip  ),
    .enb        ( cfg_enb   ),
    .prio       ( cfg_prio  ),
    .pal        ( cfg_pal   ),
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

jtframe_edge_pulse u_hsedge(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( 1'b1      ),
    .sigin      ( hs        ),
    .pulse      ( hs_edge   )
);

// Horizontal counter that waits for SDRAM
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hcnt    <= 0;
        done    <= 0;
        lin_row <= 0;
        alt_cen <= 1;
    end else begin
        alt_cen <= ~alt_cen & rom_ok;
        if( hcnt < HEND && alt_cen ) begin
            hcnt  <= hcnt +9'd1;
            hcnt0 <= hcnt0+3'd1;
            hcnt1 <= hcnt1+3'd1;
            hcnt2 <= hcnt2+3'd1;
            hcnt3 <= hcnt3+3'd1;
        end
        `ifdef SIMULATION miss <= 0; `endif

        if( hs_edge ) begin
            `ifdef SIMULATION miss <= !done; `endif
            hcnt  <= HSTART;
            hcnt0 <= (-hscr[0][2:0] ^ {3{~dflip}})+hoff0[2:0];
            hcnt1 <= (-hscr[1][2:0] ^ {3{~dflip}})+hoff1[2:0];
            hcnt2 <= (-hscr[2][2:0] ^ {3{~dflip}})+hoff2[2:0];
            hcnt3 <= (-hscr[3][2:0] ^ {3{~dflip}})+hoff3[2:0];

            if( vdump[2:0]==0 )
                if( dflip )
                    lin_row <= vdump[8:3]==VB_END[8:3] ? LIN0F : lin_row-10'd36;
                else
                    lin_row <= vdump[8:3]==VB_END[8:3] ? LIN0  : lin_row+10'd36;
        end
        done <= hcnt==HEND;
    end
end

always @* begin
    case( plyr[1:0] )
        0: begin hoff = hoff0; pcnt = hcnt0; end
        1: begin hoff = hoff1; pcnt = hcnt1; end
        2: begin hoff = hoff2; pcnt = hcnt2; end
        3: begin hoff = hoff3; pcnt = hcnt3; end
    endcase

    if( plyr>3 )
        { vpos, hpos } = { 7'd0, vdump, 7'd0, hcnt };
    else
        { vpos, hpos } = { {7'd0, vdump}+{7'd0,vscr[plyr[1:0]]} + VOFF,
                           {7'd0,  hcnt}-({7'd0,hscr[plyr[1:0]]} ^ {16{~dflip}}) + hoff + 16'd8 - {13'd0,pcnt}};

    if( dflip ) vpos = ~vpos;

    // Determines the active layer
    win    = 5;
    cprio  = 0;
    opaque = 0;
    for( j=5; j>=0; j=j-1 )
        if( !opaque || (cfg_prio[j]>cprio && mask[j][7] && !cfg_enb[j]))
            { opaque, win, cprio } = { mask[j][7] & ~cfg_enb[j], j[2:0], cfg_prio[j] };
end

always @* begin // next layer to prefetch - keep in its own always block
    mlyr = 7;
    for( j=5; j>=0; j=j-1 ) if( !nrdy[j] && !cfg_enb[j] ) mlyr = j[2:0];
end

// Pixel drawing. Masks and tile codes of the next tile of each layer are
// prefetched while the current one is drawn, and swapped in at the crossing
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mask_asub <= 0;
        bpxl      <= 0;
        bprio     <= 0;
        bblankn   <= 0;
        attr      <= 0;
        nrdy      <= 0;
        plyr      <= 7;
        mst       <= 0;
    end else begin
        case( mst )
            0: if( mlyr!=7 ) begin
                plyr <= mlyr;
                mst  <= 1;
            end
            1: begin // Tile map RAM address, one tile ahead
                case( plyr )
                    0,1,2,3: tmap_addr <= { 1'b0, plyr[1:0], vpos[3+:6], hpos[3+:6] };
                    // fixed tile maps are packed in memory and do not fit into a H-V binary split
                    4: tmap_addr <= 15'h4008 + {5'd0, lin_next};
                    5: tmap_addr <= 15'h4408 + {5'd0, lin_next};
                    default:;
                endcase
                mask_asub <= vpos[2:0];
                // counters and hcnt move together, so this stays valid
                poff <= plyr>3 ? 3'd0 : pcnt - hcnt[2:0];
                mst <= 2;
            end
            2,3: mst <= mst + 3'd1;
            4: if( smask_ok ) begin
                nmask[plyr] <= smask_data;
                ninfo[plyr] <= {cfg_pal[plyr], tmap_data, mask_asub, poff};
                nrdy[plyr]  <= 1;
                plyr        <= 7;
                mst         <= 0;
            end
            default: mst <= 0;
        endcase
        if( alt_cen ) begin
            // next pixel information
            { attr, scr_addr } <= { opaque, cprio, info[win][3+:22], info[win][2:0]+hsub };
            for( i=0; i<6; i=i+1 ) begin
                if( xing[i] && nrdy[i] ) begin
                    mask[i] <= nmask[i];
                    info[i] <= ninfo[i];
                    nrdy[i] <= 0;
                end else begin
                    mask[i] <= mask[i] << 1;
                end
            end
            buf_a <= hcnt;
            // current pixel
            { bblankn, bprio, bpxl } <= { attr, scr_data };
        end
        if( hs_edge ) begin
            nrdy <= 0;
            plyr <= 7;
            mst  <= 0;
        end
    end
end

jtframe_linebuf #(.DW(15)) u_buffer(
    .clk        ( clk       ),
    .LHBL       ( ~hs       ),
    .wr_addr    ( buf_a     ),
    .wr_data    ({bpxl,bprio,bblankn}),
    .we         ( buf_we    ),
    .rd_addr    ( dflip ? ~hdump - FLIP_DX : hdump ),
    .rd_data    ({pxl,prio,blankn}),
    .rd_gated   (           )
);

`ifdef SIMULATION
/* verilator tracing_off */
int reported=0;

always @(posedge miss) begin
    if( reported==1 ) $display("C123 line missed");
    reported <= reported+1;
end
`endif


endmodule
