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

// Namco C355 zooming sprites. Renders one line per ln_hs pulse into the
// jtframe_lfbuf line frame buffer: scans the sprite list, walks the
// attribute/format/tile tables, splits hsize/vsize across tile rows/columns
// with zoom accumulators and writes 8bpp pens through ln_addr/ln_data/ln_we.
// ln_done reports the line finished. Line = ln_v, screen coordinates 0-223.
// Word written = {prio, color, pen}. Pen 0xff is transparent, 0xffe flags a
// shadow pixel for the mixer. Sprite table RAM is external (mem.yaml)

module jtc355 #( parameter [8:0] H0=9'd0 )(
    input             rst,
    input             clk,

    input             flip,
    input      [ 1:0] sprbank,

    // line frame buffer
    input             ln_hs,
    input      [ 7:0] ln_v,
    output reg [ 8:0] ln_addr,
    output reg [15:0] ln_data,
    output reg        ln_we,
    output reg        ln_done,

    // sprite table RAM (read only)
    output reg [16:1] objtab_addr,
    input      [15:0] objtab_data,

    // OBJ ROM, 16x16x8bpp tiles
    output reg        objrom_cs,
    output reg [22:2] objrom_addr,
    input             objrom_ok,
    input      [31:0] objrom_data,

    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

// word offsets in the 128kB sprite RAM
localparam [15:0] ATTR0=16'h0000, LIST0=16'h1000, CLIPT=16'h1200,
                  FMTT =16'h2000, TILET=16'h4000,
                  ATTR1=16'h8000, LIST1=16'hA000;

localparam [4:0] IDLE=0, LIST=1, VATR=2, RAT0=3, DYZS=4, DYZW=5,
                 VSPN=6, ROWD=7, ROWC=8, VSBD=9, VSBW=10,
                 RAT1=11, DXZS=12, DXZW=13, COLD=14,
                 TILR=15, DPIX=16, DSKP=17, CNXT=18, ENXT=19,
                 ROWW=20, COLW=21;

reg         [ 4:0] st;
reg         [ 3:0] t;
reg         [ 8:0] entry;
reg         [ 7:0] which;
reg                stop, page;
reg         [10:0] link;
reg         [15:0] offset, tidx, rowbase;
reg  signed [12:0] hpos, vpos, xcur, ycur, xdr,
                   clx0, clx1, cly0, cly1;
reg         [ 9:0] hsize, vsize, shr, swr, tsh, tsw, liry, pxleft;
reg                hflip, vflip;
reg         [11:0] pal;         // {window sel, prio, color}
reg         [ 4:0] rows, cols, rcnt, ccnt;
reg         [ 8:0] dxf, dyf;
reg         [ 3:0] vsub, srcx;
reg         [14:0] codef;
reg         [10:0] acc;
reg         [ 4:0] sq;          // 16 = sq*tsw + sr, source step per screen pixel
reg         [ 9:0] sr;
(* ramstyle = "MLAB, no_rw_check" *) reg [31:0] rowb[0:7]; // 16 source pens per column, {buf, word}, ping-pong
reg         [ 1:0] fw;          // word being fetched
reg                fetch_bsy, row_ok, rsel, fbuf;
// next column prefetched while the current one draws
reg         [ 2:0] pf_st;
reg         [14:0] pf_code;
reg                pf_skip;
reg         [ 8:0] vlat;
reg         [ 6:0] hitcnt;
// per-frame visibility cache, rebuilt while drawing the first line
(* ramstyle = "MLAB, no_rw_check" *) reg viscache[0:255];
(* ramstyle = "MLAB, no_rw_check" *) reg signed [12:0] span0[0:255], span1[0:255]; // adjusted vertical span per entry
reg         [ 7:0] list_len;
reg                bld, cache_ok;
// shared serial divider
reg                div_start, div_bsy;
reg         [17:0] div_shf, div_q;
reg         [10:0] div_rem;
reg         [ 9:0] div_den;
reg         [17:0] div_num;
reg         [ 4:0] div_cnt, div_n;

wire signed [12:0] vlat_s = {4'd0, vlat};
wire        [15:0] abase  = page ? ATTR1 : ATTR0;
wire        [15:0] lbase  = page ? LIST1 : LIST0;
wire signed [12:0] tsh_s  = {3'd0, tsh};
wire signed [12:0] tsw_s  = {3'd0, tsw};
wire signed [12:0] vsz_s  = {3'd0, vsize};
// coarse-reject margin: 2x size covers the dx/dy pivot for pivots within the sprite
wire signed [12:0] vszm   = $signed({2'd0, objtab_data[9:0], 1'b0}) + 13'sd64;
wire signed [12:0] q13    = $signed({1'b0, div_q[11:0]});
wire signed [12:0] ycn    = vflip ? ycur - tsh_s : ycur;
wire        [ 9:0] rmul   = rcnt * cols;
wire        [13:0] tadr   = rowbase[13:0] + {9'd0, ccnt};
wire        [14:0] c2t    = objtab_data[13] ? {sprbank, objtab_data[12:0]}
                                            : objtab_data[14:0];
wire signed [12:0] wx0    = debug_bus[0] ? 13'sd0   : clx0 < 13'sd0   ? 13'sd0   : clx0;
wire signed [12:0] wx1    = debug_bus[0] ? 13'sd287 : clx1 > 13'sd287 ? 13'sd287 : clx1;
wire               colvis = xcur <= wx1 && xcur + tsw_s > wx0;
wire        [ 3:0] srcx_e = hflip ? 4'd15 - srcx : srcx;
wire        [31:0] rowb_w = rowb[{rsel, srcx_e[3:2]}];
wire        [ 7:0] pen    = rowb_w[{srcx_e[1:0],3'd0}+:8];
wire        [ 4:0] ccnt_n = ccnt + 5'd1;
wire        [13:0] tadr_n = rowbase[13:0] + {9'd0, ccnt_n};
wire               xok    = xdr >= wx0 && xdr <= wx1;
wire        [ 8:0] xw     = flip ? 9'd287 - xdr[8:0] : xdr[8:0];
wire        [10:0] acc_r  = acc + {1'b0, sr};
wire               acc_c  = acc_r >= {1'b0, tsw};
wire        [10:0] rem_a  = {div_rem[9:0], div_shf[17]};
wire               qbit_a = rem_a >= {1'b0, div_den};
wire        [10:0] rem_a1 = qbit_a ? rem_a - {1'b0, div_den} : rem_a;
wire        [10:0] rem_b  = {rem_a1[9:0], div_shf[16]};
wire               qbit_b = rem_b >= {1'b0, div_den};
wire        [ 4:0] rleft  = rows - rcnt;
wire        [ 4:0] cleft  = cols - ccnt;
// 16-pixel tile quotient: nonzero only for tsw<=16, and 16%tsw derives from it
reg         [ 4:0] q16;
always @* begin
    q16 = 5'd0;
    if( tsw <= 10'd16 ) case( tsw[4:0] )
        5'd1: q16 = 5'd16;
        5'd2: q16 = 5'd8;
        5'd3: q16 = 5'd5;
        5'd4: q16 = 5'd4;
        5'd5: q16 = 5'd3;
        5'd6, 5'd7, 5'd8: q16 = 5'd2;
        default: q16 = 5'd1;
    endcase
end
wire               dy_id  = vsize == {1'b0, rows, 4'd0};
wire               dx_id  = hsize == {1'b0, cols, 4'd0};
wire signed [12:0] dyq    = dy_id ? {5'd0, dyf[7:0]} : q13;
wire signed [12:0] dxq    = dx_id ? {5'd0, dxf[7:0]} : q13;
wire               div_working = div_start | div_bsy;
wire               visany = objtab_data[9:0] != 0 &&
                            vpos + vszm > 13'sd0 && vpos - vszm < 13'sd224;
wire signed [12:0] sp0    = span0[entry[7:0]];
wire signed [12:0] sp1    = span1[entry[7:0]];
wire               online = viscache[entry[7:0]] && vlat_s >= sp0 && vlat_s < sp1;
wire signed [12:0] vtop   = vflip ? vpos - vsz_s : vpos;
wire signed [12:0] vbot   = vflip ? vpos : vpos + vsz_s;
wire               unused = &{debug_bus[6:1], div_rem, div_q[17:12]};

// list scan and drawer
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st        <= IDLE;
        t         <= 0;
        entry     <= 0;
        objrom_cs <= 0;
        ln_we     <= 0;
        ln_done   <= 0;
        div_start <= 0;
        page      <= 0;
        hitcnt    <= 0;
        st_dout   <= 0;
        vlat      <= 0;
        stop      <= 0;
        fetch_bsy <= 0;
        row_ok    <= 0;
        rsel      <= 0;
        fbuf      <= 0;
        pf_st     <= 0;
        bld       <= 0;
        cache_ok  <= 0;
    end else begin
        ln_we     <= 0;
        div_start <= 0;
        // whole tile row fetched up front, 4 words, then drawn without stalls
        if( fetch_bsy && objrom_ok ) begin
            rowb[{fbuf,fw}] <= objrom_data;
            fw <= fw + 2'd1;
            objrom_addr <= {fbuf==rsel ? codef : pf_code, vsub, fw + 2'd1};
            if( &fw ) begin
                objrom_cs <= 0;
                fetch_bsy <= 0;
                if( fbuf==rsel ) row_ok <= 1; else pf_st <= 3'd4;
            end
        end
        // prefetch the next column of this sprite while the current one draws
        case( pf_st )
            0: if( st==DPIX && row_ok && !fetch_bsy && ccnt!=cols-5'd1 ) begin
                objtab_addr <= TILET | {2'd0, tadr_n};
                pf_st <= 3'd1;
            end
            1: pf_st <= 3'd2;
            2: begin
                pf_skip <= objtab_data[15];
                pf_code <= c2t + offset[14:0];
                pf_st   <= 3'd4;
                if( !objtab_data[15] && !fetch_bsy ) begin
                    objrom_addr <= {c2t + offset[14:0], vsub, 2'd0};
                    objrom_cs   <= 1;
                    fw          <= 0;
                    fbuf        <= ~rsel;
                    fetch_bsy   <= 1;
                    pf_st       <= 3'd3;
                end
            end
            default:;
        endcase
        case( st )
            IDLE:;
            LIST: begin
                if( t==0 && cache_ok && !online ) begin
                    // cached as not crossing this line, skip in one cycle
                    if( entry[7:0]==list_len || entry[7:0]==8'hff ) begin
                        st      <= IDLE;
                        ln_done <= 1;
                    end else begin
                        entry <= entry + 9'd1;
                    end
                end else begin
                    t <= t + 4'd1;
                    case( t )
                        0: objtab_addr <= lbase | {8'd0, entry[7:0]};
                        2: begin
                            {stop, which} <= objtab_data[8:0];
                            if( objtab_data[8] ) list_len <= entry[7:0];
                            objtab_addr <= abase | {5'd0, objtab_data[7:0], 3'd3};
                            st <= VATR; t <= 0;
                        end
                        default:;
                    endcase
                end
            end
            VATR: begin // vpos/vsize for early reject
                t <= t + 4'd1;
                case( t )
                    0: objtab_addr <= abase | {5'd0, which, 3'd5};
                    1: vpos <= {{2{objtab_data[10]}}, objtab_data[10:0]};
                    2: begin
                        {vflip, vsize} <= {objtab_data[15], objtab_data[9:0]};
                        if( bld ) viscache[entry[7:0]] <= visany;
                        st <= ( bld ? visany :
                              ( objtab_data[9:0] != 0 &&
                                vlat_s >= vpos - vszm &&
                                vlat_s <  vpos + vszm ) ) ? RAT0 : ENXT;
                        t  <= 0;
                    end
                    default:;
                endcase
            end
            RAT0: begin // link + format size/dy, enough for the exact reject
                t <= t + 4'd1;
                case( t )
                    0: objtab_addr <= abase | {5'd0, which, 3'd0};
                    2: begin
                        link <= objtab_data[10:0];
                        objtab_addr <= FMTT | {3'd0, objtab_data[10:0], 2'd1};
                    end
                    3: objtab_addr <= FMTT | {3'd0, link, 2'd3};
                    4: begin
                        rows <= objtab_data[3:0]==0 ? 5'd16 : {1'b0, objtab_data[3:0]};
                        cols <= objtab_data[7:4]==0 ? 5'd16 : {1'b0, objtab_data[7:4]};
                    end
                    5: begin
                        dyf <= objtab_data[8:0];
                        st  <= DYZS; t <= 0;
                    end
                    default:;
                endcase
            end
            DYZS: if( dy_id ) begin // dy pivot, scaled by the vertical zoom
                vpos <= (vflip ^ dyf[8]) ? vpos + dyq : vpos - dyq;
                st   <= VSPN;
            end else begin
                div_num   <= dyf[7:0]*vsize + {10'd0, rows, 3'd0};
                div_den   <= {1'b0, rows, 4'd0};
                div_n     <= 5'd18;
                div_start <= 1;
                st        <= DYZW;
            end
            DYZW: if( !div_working ) begin
                vpos <= (vflip ^ dyf[8]) ? vpos + dyq : vpos - dyq;
                st   <= VSPN;
            end
            VSPN: begin // exact vertical span
                shr  <= vsize;
                rcnt <= 0;
                ycur <= vpos;
                if( bld ) begin
                    span0[entry[7:0]] <= vtop;
                    span1[entry[7:0]] <= vbot;
                end
                st   <= ( vlat_s >= vtop && vlat_s < vbot ) ? ROWD : ENXT;
            end
            ROWD: begin // tile row screen height = remaining/(rows left)
                div_num   <= {shr, 8'd0};
                div_den   <= {5'd0, rleft};
                div_n     <= 5'd10;
                div_start <= 1;
                st        <= ROWW;
            end
            ROWW: if( !div_working ) begin
                tsh <= div_q[9:0];
                st  <= ROWC;
            end
            ROWC: begin
                if( vlat_s >= ycn && vlat_s < ycn + tsh_s ) begin
                    liry <= vlat_s[9:0] - ycn[9:0];
                    st   <= VSBD;
                end else if( rcnt == rows-5'd1 ) begin
                    st <= ENXT;
                end else begin
                    ycur <= vflip ? ycn : ycur + tsh_s;
                    shr  <= shr - tsh;
                    rcnt <= rcnt + 5'd1;
                    st   <= ROWD;
                end
            end
            VSBD: begin // source row within the 16x16 tile
                if( tsh == 10'd16 ) begin
                    vsub <= vflip ? 4'd15 - liry[3:0] : liry[3:0];
                    st   <= RAT1; t <= 0;
                end else begin
                    div_num   <= {liry, 8'd0};
                    div_den   <= tsh;
                    div_n     <= 5'd14;
                    div_start <= 1;
                    st        <= VSBW;
                end
            end
            VSBW: if( !div_working ) begin
                vsub <= vflip ? 4'd15 - div_q[3:0] : div_q[3:0];
                st   <= RAT1; t <= 0;
            end
            RAT1: begin // remaining attributes, only for sprites on this line
                t <= t + 4'd1;
                case( t )
                    0: objtab_addr <= abase | {5'd0, which, 3'd6};
                    1: objtab_addr <= abase | {5'd0, which, 3'd1};
                    2: begin objtab_addr <= abase | {5'd0, which, 3'd2}; pal    <= objtab_data[11:0]; end
                    3: begin objtab_addr <= abase | {5'd0, which, 3'd4}; offset <= objtab_data;       end
                    4: begin
                        objtab_addr <= FMTT | {3'd0, link, 2'd0};
                        hpos <= {{2{objtab_data[10]}}, objtab_data[10:0]};
                    end
                    5: begin
                        objtab_addr <= FMTT | {3'd0, link, 2'd2};
                        {hflip, hsize} <= {objtab_data[15], objtab_data[9:0]};
                        if( objtab_data[9:0]==0 ) begin st <= ENXT; t <= 0; end
                    end
                    6: begin objtab_addr <= CLIPT | {10'd0, pal[11:8], 2'd0}; tidx <= objtab_data;     end
                    7: begin objtab_addr <= CLIPT | {10'd0, pal[11:8], 2'd1}; dxf  <= objtab_data[8:0];end
                    8: begin objtab_addr <= CLIPT | {10'd0, pal[11:8], 2'd2}; clx0 <= $signed(objtab_data[12:0]); end
                    9: begin objtab_addr <= CLIPT | {10'd0, pal[11:8], 2'd3}; clx1 <= $signed(objtab_data[12:0]); end
                    10: cly0 <= $signed(objtab_data[12:0]);
                    11: begin
                        cly1 <= $signed(objtab_data[12:0]);
                        st <= ( debug_bus[0] || (vlat_s >= cly0 &&
                                vlat_s <= $signed(objtab_data[12:0])) ) ? DXZS : ENXT;
                        t  <= 0;
                    end
                    default:;
                endcase
            end
            DXZS: begin // dx pivot, scaled by the horizontal zoom
                swr     <= hsize;
                ccnt    <= 0;
                rowbase <= tidx + {6'd0, rmul};
                hitcnt  <= hitcnt + 7'd1;
                if( dx_id ) begin
                    xcur <= (hflip ^ dxf[8]) ? hpos + dxq : hpos - dxq;
                    st   <= COLD;
                end else begin
                    div_num   <= dxf[7:0]*hsize + {10'd0, cols, 3'd0};
                    div_den   <= {1'b0, cols, 4'd0};
                    div_n     <= 5'd18;
                    div_start <= 1;
                    st        <= DXZW;
                end
            end
            DXZW: if( !div_working ) begin
                xcur <= (hflip ^ dxf[8]) ? hpos + dxq : hpos - dxq;
                st   <= COLD;
            end
            COLD: begin // tile column screen width = remaining/(cols left)
                div_num   <= {swr, 8'd0};
                div_den   <= {5'd0, cleft};
                div_n     <= 5'd10;
                div_start <= 1;
                st        <= COLW;
            end
            COLW: if( !div_working ) begin
                tsw <= div_q[9:0];
                if( hflip ) xcur <= xcur - $signed({3'd0, div_q[9:0]});
                objtab_addr <= TILET | {2'd0, tadr};
                st <= TILR; t <= 1;
            end
            TILR: begin // tile table indirection + bank remap
                if( t < 4'd2 ) t <= t + 4'd1;
                if( tsw!=0 ) begin
                    sq <= q16;
                    sr <= 10'd16 - q16*tsw[4:0];
                end
                case( t )
                    2: if( !fetch_bsy || pf_st==3'd4 ) begin
                        t <= 0;
                        if( objtab_data[15] ) begin
                            st <= CNXT;
                        end else begin
                            codef  <= c2t + offset[14:0];
                            xdr    <= xcur;
                            pxleft <= tsw;
                            srcx   <= 0;
                            acc    <= 0;
                            row_ok <= 0;
                            st     <= (tsw==0 || !colvis) ? CNXT : DPIX;
                            if( tsw!=0 && colvis ) begin
                                if( pf_st==3'd4 && !pf_skip && pf_code==(c2t + offset[14:0]) ) begin
                                    rsel   <= ~rsel;    // prefetched, draw at once
                                    row_ok <= 1;
                                end else begin
                                    objrom_addr <= {c2t + offset[14:0], vsub, 2'd0};
                                    objrom_cs   <= 1;
                                    fw          <= 0;
                                    fbuf        <= rsel;
                                    fetch_bsy   <= 1;
                                end
                            end
                            pf_st <= 0;
                        end
                    end
                    default:;
                endcase
            end
            DPIX: begin // one screen pixel per clock, x-zoom accumulator
                if( xdr > wx1 ) begin
                    st <= CNXT; // rest of the tile falls right of the window
                end else if( !row_ok ) begin
                    // waiting for the tile row
                end else begin
                    if( xok ) begin
                        if( pen != 8'hff ) begin
                            ln_we   <= 1;
                            ln_addr <= xw + H0 + 9'd1;
                            ln_data <= {pal[7:0], pen};
                        end
                    end
                    xdr    <= xdr + 13'sd1;
                    pxleft <= pxleft - 10'd1;
                    if( pxleft == 10'd1 ) begin
                        st <= CNXT;
                    end else begin
                        srcx <= srcx + sq[3:0] + {3'd0, acc_c};
                        acc  <= acc_c ? acc_r - {1'b0, tsw} : acc_r;
                    end
                end
            end
            CNXT: begin
                if( !hflip ) xcur <= xcur + tsw_s;
                swr  <= swr - tsw;
                ccnt <= ccnt + 5'd1;
                st   <= ccnt == cols-5'd1 ? ENXT : COLD;
            end
            ENXT: begin
                pf_st <= 0;
                entry <= entry + 9'd1;
                t     <= 0;
                if( stop || entry[7:0]==8'hff ) begin
                    st      <= IDLE;
                    ln_done <= 1;
                    if( bld ) begin
                        bld      <= 0;
                        cache_ok <= 1;
                    end
                end else begin
                    st <= LIST;
                end
            end
            default: st <= IDLE;
        endcase
        if( ln_hs ) begin // line start
            pf_st     <= 0;
            vlat      <= flip ? 9'd223 - {1'b0, ln_v} : {1'b0, ln_v};
            entry     <= 0;
            t         <= 0;
            objrom_cs <= 0;
            fetch_bsy <= 0;
            ln_we     <= 0;
            page      <= debug_bus[7];
            st_dout   <= {st != IDLE, hitcnt};
            hitcnt    <= 0;
            if( ln_v == 0 ) begin // frame start, rebuild the visibility cache
                bld      <= 1;
                cache_ok <= 0;
                list_len <= 8'hff;
            end
            if( ln_v < 8'd224 ) begin
                st      <= LIST;
                ln_done <= 0;
            end else begin // blank line, nothing to draw
                st      <= IDLE;
                ln_done <= 1;
            end
        end
    end
end

// serial divider, two bits per cycle over the left-aligned numerator
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        div_bsy <= 0;
        div_cnt <= 0;
    end else begin
        if( div_start ) begin
            div_rem <= 0;
            div_shf <= div_num;
            div_q   <= 0;
            div_cnt <= {1'b0, div_n[4:1]}; // div_n is always even
            div_bsy <= 1;
        end else if( div_bsy ) begin
            div_shf <= div_shf << 2;
            div_rem <= qbit_b ? rem_b - {1'b0, div_den} : rem_b;
            div_q   <= {div_q[15:0], qbit_a, qbit_b};
            div_cnt <= div_cnt - 5'd1;
            if( div_cnt == 5'd1 ) div_bsy <= 0;
        end
    end
end

endmodule
