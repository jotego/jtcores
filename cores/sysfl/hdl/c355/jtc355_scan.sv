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
    Date: 21-9-2026
*/

// C355 sprite list scanner. Walks the list/attribute/format/tile tables and
// the zoom dividers, emitting one descriptor per visible tile column into
// the drawer FIFO. An eol descriptor closes each line.

module jtc355_scan #( parameter [8:0] H0=9'd0 )(
    input             rst,
    input             clk,

    input             flip,
    input      [ 1:0] sprbank,

    input             ln_hs,
    input      [ 7:0] ln_v,

    // sprite table RAM (read only)
    output reg [16:1] objtab_addr,
    input      [15:0] objtab_data,

    // column descriptors
    output reg [92:0] desc_data,
    output reg        desc_we,
    input             desc_full,
    input             line_full,  // drawer: every visible pixel written
    input      [63:0] cov_grp,    // drawer: 8-pixel groups fully written
    output            fwd_pass,   // build line, drawn back to front

    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

// word offsets in the 128kB sprite RAM; placement tables read from the
// vblank snapshot at +c800, tile indices from the live table
localparam [15:0] ATTR0=16'hC800, LIST0=16'hD000, CLIPT=16'hD200,
                  FMTT =16'hE000, TILET=16'h4000;

localparam [4:0] IDLE=0, LIST=1, VATR=2, RAT0=3, DYZS=4, DYZW=5,
                 VSPN=6, ROWC=8, VSBD=9,
                 RAT1=11, DXZS=12, DXZW=13, COLD=14,
                 TILR=15, CNXT=18, ENXT=19, PEOL=20;

reg         [ 4:0] st;
reg         [ 3:0] t;
reg         [ 8:0] entry;
reg         [ 7:0] which;
reg                stop;
reg         [10:0] link;
reg         [15:0] offset, tidx, rowbase;
reg  signed [12:0] hpos, vpos, xcur, ycur,
                   clx0, clx1, cly0, cly1;
reg         [ 9:0] hsize, vsize, shr, swr, tsh, tsw, liry;
reg                hflip, vflip;
reg         [11:0] pal;         // {window sel, prio, color}
reg         [ 4:0] rows, cols, rcnt, ccnt;
reg         [ 8:0] dxf, dyf;
reg         [ 3:0] vsub;
reg         [ 8:0] vlat;
reg         [ 6:0] hitcnt;
// per-frame visibility cache, rebuilt while scanning the first line
(* ramstyle = "MLAB, no_rw_check" *) reg viscache[0:255];
// margined window per entry, not the exact span: the CPU rewrites the tables
// mid frame, so the cache only excludes lines the sprite cannot reach
(* ramstyle = "MLAB, no_rw_check" *) reg signed [12:0] span0[0:255], span1[0:255];
// dy quotient per entry: a zoom ratio, stable within a frame, so the
// per-line walk skips the serial division and uses the live vpos
(* ramstyle = "MLAB, no_rw_check" *) reg [11:0] dyq_c[0:255];
reg         [ 7:0] list_len;
reg                bld, cache_ok;
reg                vs_pend, dx_run; // divider results collected while RAT1 reads run
// shared serial divider
reg                div_start, div_bsy;
reg         [17:0] div_shf, div_q;
reg         [10:0] div_rem;
reg         [ 9:0] div_den;
reg         [17:0] div_num;
reg         [ 4:0] div_cnt, div_n;

wire signed [12:0] vlat_s = {4'd0, vlat};
wire        [15:0] abase  = ATTR0;
wire        [15:0] lbase  = LIST0;
wire signed [12:0] tsw_s  = {3'd0, tsw};
wire signed [12:0] vsz_s  = {3'd0, vsize};
// coarse-reject margin: 2x size covers the dx/dy pivot for pivots within the sprite
wire signed [12:0] vszm   = $signed({2'd0, objtab_data[9:0], 1'b0}) + 13'sd64;
wire signed [12:0] q13    = $signed({1'b0, div_q[11:0]});
wire        [ 9:0] rmul   = rcnt * cols;
wire        [13:0] tadr   = rowbase[13:0] + {9'd0, ccnt};
wire        [14:0] c2t    = objtab_data[13] ? {sprbank, objtab_data[12:0]}
                                            : objtab_data[14:0];
wire signed [12:0] wx0    = debug_bus[0] ? 13'sd0   : clx0 < 13'sd0   ? 13'sd0   : clx0;
wire signed [12:0] wx1    = debug_bus[0] ? 13'sd287 : clx1 > 13'sd287 ? 13'sd287 : clx1;
wire               colvis = xcur <= wx1 && xcur + tsw_s > wx0;
wire        [10:0] rem_a  = {div_rem[9:0], div_shf[17]};
wire               qbit_a = rem_a >= {1'b0, div_den};
wire        [10:0] rem_a1 = qbit_a ? rem_a - {1'b0, div_den} : rem_a;
wire        [10:0] rem_b  = {rem_a1[9:0], div_shf[16]};
wire               qbit_b = rem_b >= {1'b0, div_den};
wire        [ 4:0] rleft  = rows - rcnt;
wire        [ 4:0] cleft  = cols - ccnt;
// division by 1-16 as a reciprocal multiply, exact for 10-bit numerators
function automatic [18:0] recip(input [4:0] d);
    case( d )
        5'd1: recip=19'd262144; 5'd2: recip=19'd131072; 5'd3: recip=19'd87382;
        5'd4: recip=19'd65536;  5'd5: recip=19'd52429;  5'd6: recip=19'd43691;
        5'd7: recip=19'd37450;  5'd8: recip=19'd32768;  5'd9: recip=19'd29128;
        5'd10: recip=19'd26215; 5'd11: recip=19'd23832; 5'd12: recip=19'd21846;
        5'd13: recip=19'd20165; 5'd14: recip=19'd18725; 5'd15: recip=19'd17477;
        default: recip=19'd16384;
    endcase
endfunction
wire [28:0] tshm   = shr * recip(rleft);
wire        [ 9:0] tsh_w  = tshm[27:18];
wire signed [12:0] tsh_c  = {3'd0, tsh_w};
wire signed [12:0] ycn_c  = vflip ? ycur - tsh_c : ycur;
wire signed [12:0] idd_s  = vflip ? vpos - 13'sd1 - vlat_s : vlat_s - vpos;
wire        [ 7:0] idd    = idd_s[7:0];
wire [28:0] colq0m = swr * recip(cleft);
wire        [ 9:0] colq   = colq0m[27:18];
wire               dy_id  = vsize == {1'b0, rows, 4'd0};
wire               dx_id  = hsize == {1'b0, cols, 4'd0};
wire signed [12:0] dyq    = dy_id ? {5'd0, dyf[7:0]} :
                            bld   ? q13 : {1'b0, dyq_c[entry[7:0]]};
wire signed [12:0] dxq    = dx_id ? {5'd0, dxf[7:0]} : q13;
wire               div_working = div_start | div_bsy;
wire               visany = objtab_data[9:0] != 0 &&
                            vpos + vszm > 13'sd0 && vpos - vszm < 13'sd224;
wire signed [12:0] sp0    = span0[entry[7:0]];
wire signed [12:0] sp1    = span1[entry[7:0]];
wire               online = viscache[entry[7:0]] && vlat_s >= sp0 && vlat_s < sp1;
wire signed [12:0] vtop   = vflip ? vpos - vsz_s : vpos;
wire signed [12:0] vbot   = vflip ? vpos : vpos + vsz_s;
wire        [ 9:0] sq_q   = tsw==0 ? 10'd0 : 10'd16 / tsw;
wire        [ 4:0] sq_c   = sq_q[4:0];
wire        [ 9:0] sr_c   = tsw==0 ? 10'd0 : 10'd16 % tsw;
// next-column recurrence for the pipelined loop
wire        [ 4:0] ccnt_n = ccnt + 5'd1;
wire        [13:0] tadr_n = rowbase[13:0] + {9'd0, ccnt_n};
wire        [ 9:0] swr_n  = swr - tsw;
wire [28:0] colqm  = swr_n * recip(cols - ccnt_n);
wire        [ 9:0] colq_n = colqm[27:18];
wire signed [12:0] xc_n   = hflip ? xcur - $signed({3'd0,colq_n})
                                  : xcur + $signed({3'd0,tsw});
wire               col_last = ccnt == cols-5'd1;
// column span already covered: skip it before the tile table read
wire signed [12:0] sc_x1a = xcur + $signed({3'd0,tsw}) - 13'sd1;
wire signed [12:0] sc_x0  = xcur > wx0 ? xcur : wx0;
wire signed [12:0] sc_x1  = sc_x1a < wx1 ? sc_x1a : wx1;
wire        [ 8:0] sc_a0  = (flip ? 9'd287 - sc_x0[8:0] : sc_x0[8:0]) + H0;
wire        [ 8:0] sc_a1  = (flip ? 9'd287 - sc_x1[8:0] : sc_x1[8:0]) + H0;
wire        [ 5:0] sc_gl  = flip ? sc_a1[8:3] : sc_a0[8:3];
wire        [ 5:0] sc_gh  = flip ? sc_a0[8:3] : sc_a1[8:3];
wire        [63:0] sc_rng = (64'h2 << sc_gh) - (64'h1 << sc_gl);
wire               sc_cov = !bld && &(cov_grp | ~sc_rng);
wire               unused = &{debug_bus[6:1], div_rem, div_q[17:12], sq_q[9:5]};
assign fwd_pass = bld;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st        <= IDLE;
        t         <= 0;
        entry     <= 0;
        div_start <= 0;
        hitcnt    <= 0;
        st_dout   <= 0;
        vlat      <= 0;
        stop      <= 0;
        vs_pend   <= 0;
        dx_run    <= 0;
        bld       <= 0;
        cache_ok  <= 0;
        desc_we   <= 0;
    end else begin
        div_start <= 0;
        desc_we   <= 0;
        case( st )
            IDLE:;
            LIST: begin
                if( line_full && !bld ) begin
                    st <= PEOL; t <= 0;
                end else if( t==0 && cache_ok && !online ) begin
                    // cached as not crossing this line, skip in one cycle
                    if( entry[7:0]==8'd0 ) begin
                        st <= PEOL;
                    end else begin
                        entry <= entry - 9'd1;
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
                        if( bld ) begin
                            viscache[entry[7:0]] <= visany;
                            span0[entry[7:0]] <= vpos - vszm;
                            span1[entry[7:0]] <= vpos + vszm;
                        end
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
            DYZS: if( dy_id || !bld ) begin // dy pivot, scaled by the vertical zoom
                vpos <= (vflip ^ dyf[8]) ? vpos + dyq : vpos - dyq;
                st   <= VSPN;
            end else begin // build pass derives the frame's quotient
                div_num   <= dyf[7:0]*vsize + {10'd0, rows, 3'd0};
                div_den   <= {1'b0, rows, 4'd0};
                div_n     <= 5'd18;
                div_start <= 1;
                st        <= DYZW;
            end
            DYZW: if( !div_working ) begin
                vpos <= (vflip ^ dyf[8]) ? vpos + dyq : vpos - dyq;
                dyq_c[entry[7:0]] <= div_q[11:0];
                st   <= VSPN;
            end
            VSPN: begin // exact vertical span
                shr  <= vsize;
                rcnt <= 0;
                ycur <= vpos;
                if( vlat_s >= vtop && vlat_s < vbot ) begin
                    if( dy_id ) begin // identity zoom, row known at once
                        rcnt <= {1'b0, idd[7:4]};
                        tsh  <= 10'd16;
                        vsub <= idd[3:0];
                        st   <= RAT1; t <= 0;
                    end else begin
                        st <= ROWC;
                    end
                end else begin
                    st <= ENXT;
                end
            end
            ROWC: begin // one row per clock, screen height = remaining/(rows left)
                if( vlat_s >= ycn_c && vlat_s < ycn_c + tsh_c ) begin
                    liry <= vlat_s[9:0] - ycn_c[9:0];
                    tsh  <= tsh_w;
                    st   <= VSBD;
                end else if( rcnt == rows-5'd1 ) begin
                    st <= ENXT;
                end else begin
                    ycur <= vflip ? ycn_c : ycur + tsh_c;
                    shr  <= shr - tsh_w;
                    rcnt <= rcnt + 5'd1;
                end
            end
            VSBD: begin // source row within the 16x16 tile
                if( tsh == 10'd16 ) begin
                    vsub <= vflip ? 4'd15 - liry[3:0] : liry[3:0];
                end else begin // collected during RAT1
                    div_num   <= {liry, 8'd0};
                    div_den   <= tsh;
                    div_n     <= 5'd14;
                    div_start <= 1;
                    vs_pend   <= 1;
                end
                st <= RAT1; t <= 0;
            end
            RAT1: begin // remaining attributes, only for sprites on this line
                t <= t + 4'd1;
                if( vs_pend && !div_working ) begin
                    vsub    <= vflip ? 4'd15 - div_q[3:0] : div_q[3:0];
                    vs_pend <= 0;
                end
                if( t >= 4'd8 && !dx_run && !dx_id && !vs_pend && !div_working ) begin
                    div_num   <= dxf[7:0]*hsize + {10'd0, cols, 3'd0};
                    div_den   <= {1'b0, cols, 4'd0};
                    div_n     <= 5'd18;
                    div_start <= 1;
                    dx_run    <= 1;
                end
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
                        if( objtab_data[9:0]==0 ) begin st <= ENXT; t <= 0;
                        end
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
                    if( !dx_run ) begin
                        div_num   <= dxf[7:0]*hsize + {10'd0, cols, 3'd0};
                        div_den   <= {1'b0, cols, 4'd0};
                        div_n     <= 5'd18;
                        div_start <= 1;
                    end
                    st <= DXZW;
                end
            end
            DXZW: if( !div_working ) begin
                xcur <= (hflip ^ dxf[8]) ? hpos + dxq : hpos - dxq;
                dx_run <= 0;
                st   <= COLD;
            end
            COLD: begin // tile column screen width = remaining/(cols left)
                tsw <= colq;
                if( hflip ) xcur <= xcur - $signed({3'd0, colq});
                objtab_addr <= TILET | {2'd0, tadr};
                st <= TILR; t <= 1;
            end
            TILR: begin // pipelined column loop: skip in one cycle, push in two
                if( t < 4'd2 ) t <= t + 4'd1;
                case( t )
                    1: if( tsw==0 || !colvis || sc_cov ) begin // no tile data needed
                        if( col_last ) begin
                            st <= ENXT; t <= 0;
                        end else begin
                            tsw  <= colq_n;
                            xcur <= xc_n;
                            swr  <= swr_n;
                            ccnt <= ccnt_n;
                            objtab_addr <= TILET | {2'd0, tadr_n};
                            t <= 1;
                        end
                    end
                    2: if( objtab_data[15] || !desc_full ) begin
                        if( !objtab_data[15] ) begin
                            desc_data <= { 1'b0, sq_c, sr_c, wx1, wx0, hflip,
                                           pal[7:0], xcur, tsw, vsub,
                                           c2t + offset[14:0] };
                            desc_we   <= 1;
                        end
                        if( col_last ) begin
                            st <= ENXT; t <= 0;
                        end else begin
                            tsw  <= colq_n;
                            xcur <= xc_n;
                            swr  <= swr_n;
                            ccnt <= ccnt_n;
                            objtab_addr <= TILET | {2'd0, tadr_n};
                            t <= 1;
                        end
                    end
                    default:;
                endcase
            end
            ENXT: begin
                vs_pend <= 0;
                dx_run  <= 0;
                t     <= 0;
                if( bld ) begin // forward build pass, line 0
                    entry <= entry + 9'd1;
                    if( stop || entry[7:0]==8'hff ) begin
                        st       <= PEOL;
                        bld      <= 0;
                        cache_ok <= 1;
                    end else begin
                        st <= LIST;
                    end
                end else begin  // reverse pass, front to back
                    entry <= entry - 9'd1;
                    st    <= entry[7:0]==8'd0 ? PEOL : LIST;
                end
            end
            PEOL: if( !desc_full ) begin // close the line for the drawer
                desc_data <= {1'b1, 92'd0};
                desc_we   <= 1;
                st        <= IDLE;
            end
            default: st <= IDLE;
        endcase
        if( ln_hs ) begin // line start
            vs_pend <= 0;
            dx_run  <= 0;
            vlat    <= flip ? 9'd223 - {1'b0, ln_v} : {1'b0, ln_v};
            t       <= 0;
            desc_we <= 0;
            st_dout <= {st != IDLE, hitcnt};
            hitcnt  <= 0;
            if( ln_v == 0 ) begin // frame start, rebuild the visibility cache
                bld      <= 1;
                cache_ok <= 0;
                list_len <= 8'hff;
                entry    <= 0;    // build pass walks forward
            end else begin
                // an unfinished build restarts forward; else front to back
                entry    <= bld ? 9'd0 : {1'b0, list_len};
            end
            st <= ln_v < 8'd224 ? LIST : IDLE;
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
