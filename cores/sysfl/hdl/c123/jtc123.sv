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
// tiles and masks are fetched as 8-byte woven units on a single bus

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
    // Tile + mask readout (SDRAM), 8-byte woven units:
    // [4 texels][row mask byte][3 pad], keyed {code,row,col[2]}
    output            scr_cs,
    output     [22:3] scr_addr,
    input             scr_ok,
    input      [63:0] scr_data,
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
wire        blankn, buf_we, rom_ok, hs_edge, mfetch;
reg  [22:3] pix_unit;              // pixel fetch unit {code, row, col[2]}
reg  [ 1:0] pix_lane;              // texel byte lane, col[1:0]

// MAME dx = 44 + {4,2,1,0} per layer, calibrate hoff0 in sim
wire [15:0] hoff0 = dflip ? 16'h71 : -16'h0f;
wire [15:0] hoff1 = dflip ? hoff0 + 16'h2 : hoff0 - 16'h2;
wire [15:0] hoff2 = dflip ? hoff0 + 16'h3 : hoff0 - 16'h3;
wire [15:0] hoff3 = dflip ? hoff0 + 16'h4 : hoff0 - 16'h4;

integer     i, j;
`ifdef SIMULATION
    reg     miss;
`endif

// the mask prefetch steals the scr port; data_ok is address-qualified in the
// slot, so the pixel side just waits while the mask unit is on the bus
assign mfetch     = plyr!=7 && mst>=3; // tmap_data valid from mst 3
assign scr_cs     = ~done | mfetch;
assign scr_addr   = mfetch ? {tmap_data, mask_asub, 1'b0} : pix_unit;
assign hsub       = hcnt[2:0];
assign buf_we     = alt_cen & ~done;
// a layer entering its next tile needs that tile's mask ready
`ifdef SIMULATION
// optional per-layer render mask for layer-by-layer debugging
reg [7:0] simlyr [0:0];
initial begin simlyr[0]=8'hff; $readmemh("lyrmask.hex", simlyr); end
wire [5:0] cfg_enb_eff = cfg_enb | ~simlyr[0][5:0];
`else
wire [5:0] cfg_enb_eff = cfg_enb;
`endif
assign xing      = { hcnt[2:0]==7, hcnt[2:0]==7, hcnt3==7, hcnt2==7, hcnt1==7, hcnt0==7 };
assign block      = xing & ~nrdy & ~cfg_enb_eff;
assign rom_ok     = scr_ok & ~mfetch & ~|block;
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

// priority-sorted layer order, registered off the pixel path. sn keys are
// {cfg_prio, index}, unique, so the 12-CE network needs no stability:
// ord[0] ends up as the highest {prio, index} and ties go to the higher layer
reg  [5:0] sn[0:5], snt;
reg  [2:0] ord[0:5];
integer k2;
`define JTC123_CE(a,b) if( sn[a] < sn[b] ) begin snt=sn[a]; sn[a]=sn[b]; sn[b]=snt; end
always @(posedge clk) begin
    for( k2=0; k2<6; k2=k2+1 ) sn[k2] = {cfg_prio[5-k2], 3'd5-k2[2:0]};
    `JTC123_CE(0,1) `JTC123_CE(2,3) `JTC123_CE(4,5)
    `JTC123_CE(0,2) `JTC123_CE(3,5) `JTC123_CE(1,4)
    `JTC123_CE(0,1) `JTC123_CE(2,3) `JTC123_CE(4,5)
    `JTC123_CE(1,2) `JTC123_CE(3,4)
    `JTC123_CE(2,3)
    for( k2=0; k2<6; k2=k2+1 ) ord[k2] <= sn[k2][2:0];
end
`undef JTC123_CE

// per-pixel winner: opacity bits reordered by priority, flat encoder
wire [5:0] op6;
genvar gp;
generate for( gp=0; gp<6; gp=gp+1 ) begin : g_op6
    assign op6[gp] = mask[gp][7] & ~cfg_enb_eff[gp];
end endgenerate
wire [5:0] opb = { op6[ord[5]], op6[ord[4]], op6[ord[3]],
                   op6[ord[2]], op6[ord[1]], op6[ord[0]] };
wire [2:0] enc  = opb[0] ? 3'd0 : opb[1] ? 3'd1 : opb[2] ? 3'd2 :
                  opb[3] ? 3'd3 : opb[4] ? 3'd4 : 3'd5;
wire [2:0] wsel = ord[enc];

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
    opaque = |opb;
    win    = opaque ? wsel : 3'd0;
    cprio  = cfg_prio[win];
end

always @* begin // next layer to prefetch - keep in its own always block
    mlyr = 7;
    for( j=5; j>=0; j=j-1 ) if( !nrdy[j] && !cfg_enb_eff[j] ) mlyr = j[2:0];
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
            4: if( scr_ok ) begin
                nmask[plyr] <= scr_data[39:32];
                ninfo[plyr] <= {cfg_pal[plyr], tmap_data, mask_asub, poff};
                nrdy[plyr]  <= 1;
                plyr        <= 7;
                mst         <= 0;
            end
            default: mst <= 0;
        endcase
        if( alt_cen ) begin
            // next pixel information
            { attr, pix_unit, pix_lane } <= { opaque, cprio, info[win][3+:22], info[win][2:0]+hsub };
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
            { bblankn, bprio, bpxl } <= { attr, scr_data[{pix_lane,3'd0}+:8] };
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

// per-frame deadline audit, same shape as ROZA/SOBJ
integer sc_lines=0, sc_cut=0, sc_wait=0, sc_mf=0;
reg sc_vsl=0;
always @(posedge clk) begin
    sc_vsl <= vs;
    if( !done && !rom_ok ) sc_wait <= sc_wait+1;
    if( mfetch            ) sc_mf   <= sc_mf+1;
    if( hs_edge ) begin
        sc_lines <= sc_lines+1;
        if( !done ) sc_cut <= sc_cut+1;
    end
    if( vs && !sc_vsl ) begin
        $display("SCRA lines=%0d cut=%0d wait=%0d mask=%0d", sc_lines, sc_cut, sc_wait, sc_mf);
        sc_lines<=0; sc_cut<=0; sc_wait<=0; sc_mf<=0;
    end
end
`endif


endmodule
