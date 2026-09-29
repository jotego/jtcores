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
    output     [15:1] tmap_addr,
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
    // scr opaque-class table (game level)
    output reg [15:0] sopq_addr,
    input             sopq_bit,
    // per-tile-row HUD coverage of all six layers, for the roz drawer
    input      [ 4:0] cov_row,
    output    [215:0] cov_word,
    output     [17:0] cov_prio,
    output reg        cov_ok,
    // road coverage summary from the C169 prescan
    input             sum_vld,
    input             sum_full,
    input      [ 8:0] sum_x0, sum_x1,
    input      [ 3:0] sum_prio,
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
parameter [15:0] BLANK=16'h0020; // both games' pervasive fully-transparent tile


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
reg  [ 8:0] hcnt, buf_a, clr_a;
reg         clr_on;
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

integer     i, j, j2;
`ifdef SIMULATION
    reg     miss;
`endif

assign scr_cs     = ~done & attr[6]; // transparent pixels fetch nothing
wire pre_blank    = tmap_data==BLANK;
assign smask_cs   = plyr!=7 && mst>=3 && !pre_blank && !skip_cov; // tmap_data valid from mst 3
assign hsub       = hcnt[2:0];
assign buf_we     = (alt_cen & ~done) | clr_we;
// tail sweep: descends from HEND on the idle write phase and stops at the
// renderer, so a cut line never shows the previous line's tail
wire        clr_we  = clr_on & ~(alt_cen & ~done) & clr_a > hcnt;
wire [ 8:0] buf_wa  = clr_we ? clr_a : buf_a;
wire [14:0] buf_wd  = clr_we ? 15'd0 : {bpxl,bprio,bblankn};
// a layer entering its next tile needs that tile's mask ready
`ifdef SIMULATION
// optional per-layer render mask for layer-by-layer debugging
reg [7:0] simlyr [0:0];
initial begin simlyr[0]=8'hff; $readmemh("lyrmask.hex", simlyr); end
wire [5:0] cfg_enb_eff = cfg_enb | ~simlyr[0][5:0] | skip_l;
`else
wire [5:0] cfg_enb_eff = cfg_enb | skip_l;
`endif
// layers that provably lose to the covered road span this line
reg  [5:0] lose_l, skip_l;
reg  [8:0] spx0, spx1;
reg        span_v, skip_cov;
wire [8:0] hvis = hcnt - 9'h40; // buffer x -> screen x (roz space), no flip
wire       in_span = span_v && hvis>=spx0 && hvis<=spx1;
// next tile of the prefetched layer, in buffer coordinates
wire [2:0] eff_pcnt = plyr>3 ? hcnt[2:0] : pcnt;
wire [9:0] wxb0     = {1'b0,hcnt} + 10'd8 - {7'd0,eff_pcnt};
wire       cov_tile = span_v && wxb0          >= ({1'b0,spx0}+10'h40) &&
                                (wxb0+10'd7)  <= ({1'b0,spx1}+10'h40);
assign xing      = { hcnt[2:0]==7, hcnt[2:0]==7, hcnt3==7, hcnt2==7, hcnt1==7, hcnt0==7 };
assign block      = xing & ~nrdy & ~cfg_enb_eff;
assign rom_ok     = (scr_ok | ~attr[6]) & ~|block;
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
        clr_a   <= 0;
        clr_on  <= 0;
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

        if( clr_we ) clr_a <= clr_a - 9'd1;
        if( hs_edge ) begin
            // road coverage: whole losing layers drop on covered rows, the
            // covered span silences losing pixels elsewhere (Stage 0 then
            // skips their fetches). Strict compare: tilemap wins ties.
            for( j2=0; j2<6; j2=j2+1 ) begin
                lose_l[j2] <= sum_vld && {1'b0,cfg_prio[j2],1'b0} < {1'b0,sum_prio};
                skip_l[j2] <= sum_vld && sum_full &&
                              {1'b0,cfg_prio[j2],1'b0} < {1'b0,sum_prio};
            end
            span_v <= sum_vld && !dflip; // flip changes the x mapping: v1 skips it
            spx0   <= sum_x0;
            spx1   <= sum_x1;
            `ifdef SIMULATION miss <= !done && vdump>=9'h120 && vdump<=9'h1ff; `endif
            clr_a <= HEND;
            clr_on<= 1;
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
    assign op6[gp] = mask[gp][7] & ~cfg_enb_eff[gp] & ~(lose_l[gp] & in_span);
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
    if( sc_on ) mlyr = 7; // vblank coverage scan owns the tilemap port
end

// HUD coverage scan: after the CPU's vblank updates, walk all six layers'
// tilemaps through the opaque-class table into one 36-bit word per tile row
// and layer. Scroll layers AND the 2x2 straddled tiles, so fine scroll only
// costs coverage at block edges. Any cfg write after the scan drops cov_ok.
reg        sc_on, vs_l;
reg [ 2:0] sc_st;
reg [ 3:0] sc_dly;
reg [35:0] sc_word;
reg        sc_we, sc_qac;
reg [15:0] sc_it, sc_i1, sc_i2; // {lyr[2:0], row[4:0], col[5:0], quad[1:0]}
reg [15:1] sc_ta, tmap_a;
reg        sc_bl1, sc_bl2;
assign tmap_addr = sc_on ? sc_ta : tmap_a;
assign cov_prio  = { cfg_prio[5], cfg_prio[4], cfg_prio[3],
                     cfg_prio[2], cfg_prio[1], cfg_prio[0] };

wire [ 2:0] it_lyr  = sc_it[15:13];
wire [ 1:0] it_quad = sc_it[1:0];
wire [ 2:0] i1_lyr  = sc_i1[15:13];
wire [ 4:0] i1_row  = sc_i1[12:8];
wire [ 5:0] i1_col  = sc_i1[7:2];
wire [ 1:0] i1_quad = sc_i1[1:0];
wire        it_last = it_lyr==3'd5 && sc_it[12:2]=={5'd27,6'd35};
wire [ 1:0] it_qtop = it_lyr<3'd4 ? 2'd3 : 2'd0;

function [15:1] sc_addr( input [15:0] it );
    reg [ 2:0] l;
    reg [ 4:0] r;
    reg [ 5:0] c;
    reg [ 1:0] q;
    reg [15:0] hv, vv;
    reg [ 9:0] lin;
begin
    {l, r, c, q} = it;
    if( l<4 ) begin
        vv = 16'h121 + {8'd0,r,3'b0} + (q[1]?16'd7:16'd0)
             + {7'd0,vscr[l[1:0]]} + VOFF;
        hv = 16'h40 + {7'd0,c,3'b0} + (q[0]?16'd7:16'd0)
             - ({7'd0,hscr[l[1:0]]} ^ {16{~dflip}})
             + (l[1] ? (l[0]?hoff3:hoff2) : (l[0]?hoff1:hoff0));
        sc_addr = {1'b0, l[1:0], vv[3+:6], hv[3+:6]};
    end else begin
        lin = {r,5'd0} + {2'd0,r,2'd0} + {4'd0,c}; // r*36+c
        sc_addr = (l[0] ? 15'h4408 : 15'h4008) + {5'd0,lin};
    end
end
endfunction

// iterator advance: quad within col within row within layer
function [15:0] sc_next( input [15:0] it );
    reg [ 2:0] l;
    reg [ 4:0] r;
    reg [ 5:0] c;
    reg [ 1:0] q;
begin
    {l, r, c, q} = it;
    if( q != (l<4 ? 2'd3 : 2'd0) ) q = q + 2'd1;
    else begin
        q = 0;
        if( c != 6'd35 ) c = c + 6'd1;
        else begin
            c = 0;
            if( r != 5'd27 ) r = r + 5'd1;
            else begin r = 0; l = l + 3'd1; end
        end
    end
    sc_next = {l, r, c, q};
end
endfunction

always @(posedge clk) begin
    vs_l  <= vs;
    sc_we <= 0;
    if( rst ) begin
        sc_on  <= 0;
        cov_ok <= 0;
        sc_dly <= 15;
    end else begin
        if( vs && !vs_l ) begin
            cov_ok <= 0;
            sc_dly <= 0;
        end
        if( hs_edge && sc_dly != 4'd15 ) sc_dly <= sc_dly + 4'd1;
        if( sc_dly == 4'd8 && !sc_on && !dflip ) begin
            sc_on <= 1;
            sc_it <= 0;
            sc_st <= 0;
            sc_dly<= 15;
        end
        // a cfg write after the scan means stale scroll/prio: stand down
        if( cs && !rnw ) cov_ok <= 0;
        if( sc_on ) case( sc_st )
            0: if( mst==0 && plyr==7 ) begin // renderer drained, port is ours
                sc_ta <= sc_addr(sc_it);
                sc_i2 <= sc_it;
                sc_it <= sc_next(sc_it);
                sc_st <= 1;
            end
            1: sc_st <= 2;
            2: begin // tmap in: to the table, next tmap out
                sopq_addr <= tmap_data;
                sc_bl2    <= tmap_data==BLANK;
                sc_i1     <= sc_i2;
                sc_bl1    <= sc_bl2;
                sc_ta     <= sc_addr(sc_it);
                sc_i2     <= sc_it;
                sc_it     <= sc_next(sc_it);
                sc_st     <= 3;
            end
            3: sc_st <= 4;
            4: begin // sopq_bit for sc_i1's PREVIOUS issue... sample and loop
                sc_qac <= (i1_quad==0 ? 1'b1 : sc_qac) && sopq_bit && !sc_bl1
                          && !cfg_enb[i1_lyr];
                if( i1_quad == (i1_lyr<4 ? 2'd3 : 2'd0) )
                    sc_word[i1_col] <= (i1_quad==0 ? 1'b1 : sc_qac)
                          && sopq_bit && !sc_bl1 && !cfg_enb[i1_lyr];
                if( i1_col==6'd35 && i1_quad == (i1_lyr<4 ? 2'd3 : 2'd0) ) begin
                    sc_we <= 1;
                end
                if( sc_i1[15:13]==3'd5 && sc_i1[12:0]=={5'd27,6'd35,2'd0} ) begin
                    sc_on  <= 0;
                    cov_ok <= 1;
`ifdef SYSFL_SCRDBG
                    $display("COVS F=%0d done cols=%0d", sc_frm, cv_tot);
`endif
                end else sc_st <= 2;
            end
        endcase
    end
end

`ifdef SYSFL_SCRDBG
integer cv_tot=0;
always @(posedge clk) begin
    if( sc_on && sc_we ) cv_tot <= cv_tot + $countones(sc_word);
    if( vs && sc_dly==0 ) cv_tot <= 0;
end
`endif

// one RAM per layer, written at each row's last column
reg  [ 2:0] sc_wl;
reg  [ 4:0] sc_wr;
always @(posedge clk) if( sc_on && sc_st==4 ) begin
    sc_wl <= i1_lyr;
    sc_wr <= i1_row;
end
wire [5:0] cov_wsel;
assign cov_wsel = { sc_we && sc_wl==3'd5, sc_we && sc_wl==3'd4,
                    sc_we && sc_wl==3'd3, sc_we && sc_wl==3'd2,
                    sc_we && sc_wl==3'd1, sc_we && sc_wl==3'd0 };
generate
    genvar gl;
    for( gl=0; gl<6; gl=gl+1 ) begin : gen_cov
        jtframe_dual_ram #(.DW(36),.AW(5)) u_cov(
            .clk0(clk), .data0(sc_word), .addr0(sc_wr), .we0(cov_wsel[gl]), .q0(),
            .clk1(clk), .data1(36'd0), .addr1(cov_row), .we1(1'b0),
            .q1(cov_word[gl*36 +: 36])
        );
    end
endgenerate

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
        skip_cov  <= 0;
    end else begin
        case( mst )
            0: if( mlyr!=7 ) begin
                plyr <= mlyr;
                mst  <= 1;
            end
            1: begin // Tile map RAM address, one tile ahead
                skip_cov <= cov_tile && lose_l[plyr];
                case( plyr )
                    0,1,2,3: tmap_a <= { 1'b0, plyr[1:0], vpos[3+:6], hpos[3+:6] };
                    // fixed tile maps are packed in memory and do not fit into a H-V binary split
                    4: tmap_a <= 15'h4008 + {5'd0, lin_next};
                    5: tmap_a <= 15'h4408 + {5'd0, lin_next};
                    default:;
                endcase
                mask_asub <= vpos[2:0];
                // counters and hcnt move together, so this stays valid
                poff <= plyr>3 ? 3'd0 : pcnt - hcnt[2:0];
                mst <= 2;
            end
            2: mst <= 3;
            3: begin
                mst <= 4;
                if( pre_blank || skip_cov ) begin // blank or road-covered tile: mask 0, no fetches
                    nmask[plyr] <= 0;
                    ninfo[plyr] <= {cfg_pal[plyr], tmap_data, mask_asub, poff};
                    nrdy[plyr]  <= 1;
                    plyr        <= 7;
                    mst         <= 0;
                end
            end
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
    .wr_addr    ( buf_wa    ),
    .wr_data    ( buf_wd    ),
    .we         ( buf_we    ),
    .rd_addr    ( dflip ? ~hdump - FLIP_DX : hdump ),
    .rd_data    ({pxl,prio,blankn}),
    .rd_gated   (           )
);

`ifdef SYSFL_SCRDBG
// per-frame tilemap bus audit
integer sc_req=0, sc_wait=0, sc_skip=0, sc_cov=0, sp_vld=0, sp_full=0, sp_w=0, sc_frm=0;
reg sc_vsl=0;
always @(posedge clk) begin
    sc_vsl <= vs;
    if( hs_edge && sum_vld ) begin
        sp_vld <= sp_vld+1;
        if( sum_full ) sp_full <= sp_full+1;
        else sp_w <= sp_w + {23'd0,sum_x1} - {23'd0,sum_x0};
    end
    if( scr_cs && !scr_ok ) sc_wait <= sc_wait+1;
    if( alt_cen && !done ) begin
        if( attr[6] ) sc_req <= sc_req+1; else sc_skip <= sc_skip+1;
    end
    if( mst==3 && skip_cov && !pre_blank ) sc_cov <= sc_cov+1;
    if( vs && !sc_vsl ) begin
        $display("SCRA F=%0d req=%0d skip=%0d cov=%0d wait=%0d | span vld=%0d full=%0d partw=%0d", sc_frm, sc_req, sc_skip, sc_cov, sc_wait, sp_vld, sp_full, sp_w);
        sc_req<=0; sc_skip<=0; sc_cov<=0; sc_wait<=0; sp_vld<=0; sp_full<=0; sp_w<=0;
        sc_frm <= sc_frm+1;
    end
end
`endif

`ifdef SIMULATION
/* verilator tracing_off */
int reported=0, ms_frm=0;
reg ms_vsl=0;
always @(posedge clk) begin
    ms_vsl <= vs;
    if( vs && !ms_vsl ) ms_frm <= ms_frm+1;
end
always @(posedge miss) begin
    if( reported>0 ) $display("C123 line missed F=%0d line=%0d hcnt=%0d",
        ms_frm, vdump-9'h120, hcnt);
    reported <= reported+1;
end
`endif


endmodule
