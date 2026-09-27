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
    output reg [104:0] desc_data,
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
// attr/list/clip live in the snapshot BRAM (addresses under 1000); the
// static format and tile tables are read live at their real oram addresses
localparam [15:0] ATTR0=16'h0000, LIST0=16'h0800, CLIPT=16'h0A00,
                  FMTT =16'h2000, TILET=16'h4000;

localparam [4:0] IDLE=0, RLOD=1, RTST=2,
                 VSPN=6, ROWC=8, VSBD=9,
                 COLD=14,
                 TILR=15, ENXT=19, PEOL=20,
                 // vblank decode pass
                 DLST=21, DATR=22, DDYZ=24, DDXZ=25, DWRT=27;

reg         [ 4:0] st;
reg         [ 3:0] t;
reg         [ 8:0] entry;
reg         [ 7:0] which;
reg                stop;
reg         [10:0] link;
reg         [15:0] offset, tidx, rowbase;
reg  signed [12:0] hpos, vpos, xcur, ycur, clx0, clx1;
reg         [ 9:0] hsize, vsize, shr, swr, tsh, tsw, liry;
reg                hflip, vflip;
reg         [11:0] pal;         // {window sel, prio, color}
reg         [ 4:0] rows, cols, rcnt, ccnt;
reg         [ 8:0] dxf, dyf;
reg         [ 3:0] vsub;
reg         [ 8:0] vlat;
reg         [ 6:0] hitcnt;
// decoded sprite records, rebuilt from the tables once per vblank: only
// frame-visible sprites, list order (drawn back to front by walking the
// records in reverse). Everything the per-line walk needs except the tile
// indices, which stay live.
// [149:137] ylo | [136:124] yhi | [123:111] vpos' | [110] vflip
// [109:100] vsize | [99:95] rows | [94] dy_id | [93:81] xstart | [80] hflip
// [79:70] hsize | [69:65] cols | [64:57] pal | [56:44] clx0 | [43:31] clx1
// [30:15] tidx | [14:0] offset
localparam RECW = 150;
(* ramstyle = "M10K, no_rw_check" *) reg [RECW-1:0] rec[0:255];
reg  [RECW-1:0] rq;
reg         [ 7:0] cra, reccnt, dslot;
reg                rec_ok, dy_id_r;
// decode-pass temporaries
reg         [ 5:0] bcnt;        // blank lines seen; decode starts after the DMA
reg                dec_pend, dec_done;
reg  signed [12:0] cly0d;
wire signed [12:0] ylo_w, yhi_w, yhi_c;
reg                vs_pend; // vsub divider result pending
// shared serial divider
reg                div_start, div_bsy;
reg         [17:0] div_shf, div_q;
reg         [10:0] div_rem;
reg         [ 9:0] div_den;
reg         [17:0] div_num;
reg         [ 4:0] div_cnt, div_n;

(* multstyle = "dsp" *) wire [17:0] dyv_m = dyf[7:0]*vsize;
(* multstyle = "dsp" *) wire [17:0] dxh_m = dxf[7:0]*hsize;
wire signed [12:0] vlat_s = {4'd0, vlat};
wire        [15:0] abase  = ATTR0;
wire        [15:0] lbase  = LIST0;
wire signed [12:0] tsw_s  = {3'd0, tsw};
wire signed [12:0] vsz_s  = {3'd0, vsize};
// coarse-reject margin: 2x size covers the dx/dy pivot for pivots within the sprite
wire signed [12:0] q13    = $signed({1'b0, div_q[11:0]});
wire        [ 9:0] rmul   = rcnt * cols;
wire        [ 9:0] fmul   = {1'b0, idd[7:4]} * cols; // fast-path row*cols
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
(* multstyle = "dsp" *) wire [28:0] tshm   = shr * recip(rleft);
wire        [ 9:0] tsh_w  = tshm[27:18];
wire signed [12:0] tsh_c  = {3'd0, tsh_w};
wire signed [12:0] ycn_c  = vflip ? ycur - tsh_c : ycur;
wire signed [12:0] idd_s  = vflip ? vpos - 13'sd1 - vlat_s : vlat_s - vpos;
wire        [ 7:0] idd    = idd_s[7:0];
(* multstyle = "dsp" *) wire [28:0] colq0m = swr * recip(cleft);
wire        [ 9:0] colq   = colq0m[27:18];
wire               dy_id  = vsize == {1'b0, rows, 4'd0};
wire               dx_id  = hsize == {1'b0, cols, 4'd0};
wire signed [12:0] dyq    = dy_id ? {5'd0, dyf[7:0]} : q13;
wire signed [12:0] dxq    = dx_id ? {5'd0, dxf[7:0]} : q13;
wire               div_working = div_start | div_bsy;
wire signed [12:0] vtop   = vflip ? vpos - vsz_s : vpos;
wire signed [12:0] vbot   = vflip ? vpos : vpos + vsz_s;
// record unpack (valid the cycle after cra settles)
wire signed [12:0] r_ylo  = rq[149:137];
wire signed [12:0] r_yhi  = rq[136:124];
wire               online = vlat_s >= r_ylo && vlat_s <= r_yhi;
// decode window: sprite span intersected with the clip-window y range
assign ylo_w = vtop > cly0d ? vtop : cly0d;
assign yhi_c = vbot - 13'sd1;
assign yhi_w = yhi_c < $signed(objtab_data[12:0]) ? yhi_c : $signed(objtab_data[12:0]);
// 16/tsw and 16%tsw as a lookup: a real divider is 15 logic levels deep
reg         [ 4:0] sq_c;
reg         [ 9:0] sr_c;
always @* begin
    if( tsw[9:5]!=0 || tsw[4:0]>5'd16 ) begin
        {sq_c, sr_c} = {5'd0, 10'd16};      // tsw > 16
    end else case( tsw[4:0] )
        5'd0:    {sq_c, sr_c} = {5'd0,  10'd0};
        5'd1:    {sq_c, sr_c} = {5'd16, 10'd0};
        5'd2:    {sq_c, sr_c} = {5'd8,  10'd0};
        5'd3:    {sq_c, sr_c} = {5'd5,  10'd1};
        5'd4:    {sq_c, sr_c} = {5'd4,  10'd0};
        5'd5:    {sq_c, sr_c} = {5'd3,  10'd1};
        5'd6:    {sq_c, sr_c} = {5'd2,  10'd4};
        5'd7:    {sq_c, sr_c} = {5'd2,  10'd2};
        5'd8:    {sq_c, sr_c} = {5'd2,  10'd0};
        5'd9:    {sq_c, sr_c} = {5'd1,  10'd7};
        5'd10:   {sq_c, sr_c} = {5'd1,  10'd6};
        5'd11:   {sq_c, sr_c} = {5'd1,  10'd5};
        5'd12:   {sq_c, sr_c} = {5'd1,  10'd4};
        5'd13:   {sq_c, sr_c} = {5'd1,  10'd3};
        5'd14:   {sq_c, sr_c} = {5'd1,  10'd2};
        5'd15:   {sq_c, sr_c} = {5'd1,  10'd1};
        default: {sq_c, sr_c} = {5'd1,  10'd0};  // 16
    endcase
end
// next-column recurrence for the pipelined loop
wire        [ 4:0] ccnt_n = ccnt + 5'd1;
wire        [13:0] tadr_n = rowbase[13:0] + {9'd0, ccnt_n};
wire        [ 9:0] swr_n  = swr - tsw;
(* multstyle = "dsp" *) wire [28:0] colqm  = swr_n * recip(cols - ccnt_n);
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
wire        [63:0] sc_rng;
genvar si;
generate for( si=0; si<64; si=si+1 ) begin : srng_gen
    assign sc_rng[si] = si >= sc_gl && si <= sc_gh;
end endgenerate
wire               sc_cov = &(cov_grp | ~sc_rng);
wire               unused = &{debug_bus[6:1], div_rem, div_q[17:12], offset[15]};
assign fwd_pass = 1'b0;

// cly1 sits held on objtab_data in DWRT: no reads are issued after DATR t=13
wire vis_w  = ylo_w <= yhi_w && yhi_w >= 13'sd0 && ylo_w < 13'sd224;
wire rec_we = st==DWRT && t==4'd0 && vis_w;

`ifdef SYSFL_SCANDBG
always @(posedge clk) begin
    if( st==DWRT && t==4'd0 )
        $display("REC %s slot=%0d e=%0d ylo=%0d yhi=%0d vpos=%0d vsz=%0d rows=%0d hpos=%0d hsz=%0d cols=%0d tidx=%x pal=%x clx=%0d..%0d %s%s",
            vis_w?"W":"-", dslot, entry, ylo_w, yhi_w, vpos, vsize, rows, hpos, hsize, cols, tidx, pal, clx0, clx1,
            vflip?"vf":"", hflip?"hf":"");
    if( st==DWRT && (stop || entry[7:0]==8'hff) )
        $display("DECODE END reccnt=%0d", rec_we ? dslot+8'd1 : dslot);
end
`endif

always @(posedge clk) begin
    rq <= rec[cra];
    if( rec_we )
        rec[dslot] <= { ylo_w, yhi_w, vpos, vflip, vsize, rows,
                        dy_id, hpos, hflip, hsize, cols,
                        pal[7:0], clx0, clx1, tidx[15:0], offset[14:0] };
end

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
        desc_we   <= 0;
        rec_ok    <= 0;
        reccnt    <= 0;
        dslot     <= 0;
        bcnt      <= 0;
        dec_pend  <= 0;
        dec_done  <= 0;
    end else begin
        div_start <= 0;
        desc_we   <= 0;
        case( st )
            IDLE: if( dec_pend ) begin // vblank decode pass
                dec_pend <= 0;
                dslot    <= 0;
                entry    <= 0;
                stop     <= 0;
                st       <= DLST; t <= 0;
            end
            // ---------- display: walk the decoded records ----------
            RLOD: begin // cra was set one cycle earlier; rq valid in RTST
                if( line_full ) begin
                    st <= PEOL; t <= 0;
                end else begin
                    st <= RTST;
                end
            end
            RTST: begin
                if( !online ) begin
                    if( entry[7:0]==8'd0 ) st <= PEOL;
                    else begin
                        entry <= entry - 9'd1;
                        cra   <= entry[7:0] - 8'd1;
                        st    <= RLOD;
                    end
                end else begin
                    // unpack the record and resolve the row
                    vpos    <= rq[123:111];
                    vflip   <= rq[110];
                    vsize   <= rq[109:100];
                    rows    <= rq[99:95];
                    dy_id_r <= rq[94];
                    xcur    <= rq[93:81];
                    hflip   <= rq[80];
                    hsize   <= rq[79:70];
                    cols    <= rq[69:65];
                    pal     <= {4'd0, rq[64:57]};
                    clx0    <= rq[56:44];
                    clx1    <= rq[43:31];
                    tidx    <= rq[30:15];
                    offset  <= {1'b0, rq[14:0]};
                    st      <= VSPN;
                end
            end
            VSPN: begin // row search setup; the y window already passed
                shr  <= vsize;
                rcnt <= 0;
                ycur <= vpos;
                if( dy_id_r ) begin // identity zoom, row known at once
                    rcnt <= {1'b0, idd[7:4]};
                    tsh  <= 10'd16;
                    vsub <= idd[3:0];
                    st   <= COLD; t <= 0;
                    swr     <= hsize;
                    ccnt    <= 0;
                    rowbase <= tidx + {6'd0, fmul};
                    hitcnt  <= hitcnt + 7'd1;
                end else begin
                    st <= ROWC;
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
                end else begin // collected while the column loop starts
                    div_num   <= {liry, 8'd0};
                    div_den   <= tsh;
                    div_n     <= 5'd14;
                    div_start <= 1;
                    vs_pend   <= 1;
                end
                swr     <= hsize;
                ccnt    <= 0;
                rowbase <= tidx + {6'd0, rmul};
                hitcnt  <= hitcnt + 7'd1;
                st <= COLD; t <= 0;
            end
            COLD: begin // tile column screen width = remaining/(cols left)
                if( vs_pend && !div_working ) begin
                    vsub    <= vflip ? 4'd15 - div_q[3:0] : div_q[3:0];
                    vs_pend <= 0;
                end
                if( !vs_pend || !div_working ) begin
                    tsw <= colq;
                    if( hflip ) xcur <= xcur - $signed({3'd0, colq});
                    objtab_addr <= TILET | {2'd0, tadr};
                    st <= TILR; t <= 1;
                end
            end
            TILR: begin // pipelined column loop: skip in one cycle, push in two
                if( vs_pend && !div_working ) begin
                    vsub    <= vflip ? 4'd15 - div_q[3:0] : div_q[3:0];
                    vs_pend <= 0;
                end
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
                            desc_data <= { 1'b0, sc_gh, sc_gl, sq_c, sr_c,
                                           wx1, wx0, hflip,
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
                t       <= 0;
                entry   <= entry - 9'd1;
                cra     <= entry[7:0] - 8'd1;
                st      <= entry[7:0]==8'd0 ? PEOL : RLOD;
            end
            PEOL: if( !desc_full ) begin // close the line for the drawer
                desc_data <= {1'b1, 104'd0};
                desc_we   <= 1;
                st        <= IDLE;
            end
            // ---------- vblank decode: tables -> records ----------
            DLST: begin // list entry -> attribute set
                t <= t + 4'd1;
                case( t )
                    0: objtab_addr <= lbase | {8'd0, entry[7:0]};
                    2: begin
                        which <= objtab_data[7:0];
                        stop  <= objtab_data[8];
                        objtab_addr <= abase | {5'd0, objtab_data[7:0], 3'd3};
                        st <= DATR; t <= 0;
                    end
                    default:;
                endcase
            end
            DATR: begin // placement words, exactly the display read program
                t <= t + 4'd1;
                case( t )
                    0: objtab_addr <= abase | {5'd0, which, 3'd5};
                    1: begin objtab_addr <= abase | {5'd0, which, 3'd0};
                             vpos <= {{2{objtab_data[10]}}, objtab_data[10:0]}; end
                    2: begin objtab_addr <= abase | {5'd0, which, 3'd6};
                             {vflip, vsize} <= {objtab_data[15], objtab_data[9:0]}; end
                    3: begin objtab_addr <= abase | {5'd0, which, 3'd1};
                             link <= objtab_data[10:0]; end
                    4: begin objtab_addr <= FMTT | {3'd0, link, 2'd1};
                             pal <= objtab_data[11:0]; end
                    5: begin objtab_addr <= FMTT | {3'd0, link, 2'd3};
                             offset <= objtab_data; end
                    6: begin objtab_addr <= abase | {5'd0, which, 3'd2};
                             rows <= objtab_data[3:0]==0 ? 5'd16 : {1'b0, objtab_data[3:0]};
                             cols <= objtab_data[7:4]==0 ? 5'd16 : {1'b0, objtab_data[7:4]}; end
                    7: begin objtab_addr <= abase | {5'd0, which, 3'd4};
                             dyf <= objtab_data[8:0]; end
                    8: begin objtab_addr <= FMTT | {3'd0, link, 2'd0};
                             hpos <= {{2{objtab_data[10]}}, objtab_data[10:0]}; end
                    9: begin objtab_addr <= FMTT | {3'd0, link, 2'd2};
                             {hflip, hsize} <= {objtab_data[15], objtab_data[9:0]}; end
                    10: begin objtab_addr <= CLIPT | {10'd0, pal[11:8], 2'd0};
                              tidx <= objtab_data; end
                    11: begin objtab_addr <= CLIPT | {10'd0, pal[11:8], 2'd1};
                              dxf <= objtab_data[8:0]; end
                    12: begin objtab_addr <= CLIPT | {10'd0, pal[11:8], 2'd2};
                              clx0 <= $signed(objtab_data[12:0]); end
                    13: begin objtab_addr <= CLIPT | {10'd0, pal[11:8], 2'd3};
                              clx1 <= $signed(objtab_data[12:0]); end
                    14: begin
                        cly0d <= $signed(objtab_data[12:0]);
                        // skip clearly dead sprites before the divides
                        if( vsize==0 || hsize==0 ) begin
                            st <= DWRT; t <= 1; // t=1: skip the write
                        end else begin
                            st <= DDYZ; t <= 0;
                        end
                    end
                    default:;
                endcase
            end
            DDYZ: begin // dy pivot quotient (cly1 arrives while it runs)
                if( t==0 ) begin
                    t <= 4'd1;
                    if( !dy_id ) begin
                        div_num   <= dyv_m + {10'd0, rows, 3'd0};
                        div_den   <= {1'b0, rows, 4'd0};
                        div_n     <= 5'd18;
                        div_start <= 1;
                    end
                end else if( !div_working && !div_start ) begin
                    vpos <= (vflip ^ dyf[8]) ? vpos + dyq : vpos - dyq;
                    st   <= DDXZ; t <= 0;
                end
            end
            DDXZ: begin // dx pivot quotient
                if( t==0 ) begin
                    t <= 4'd1;
                    if( !dx_id ) begin
                        div_num   <= dxh_m + {10'd0, cols, 3'd0};
                        div_den   <= {1'b0, cols, 4'd0};
                        div_n     <= 5'd18;
                        div_start <= 1;
                    end
                end else if( !div_working && !div_start ) begin
                    hpos <= (hflip ^ dxf[8]) ? hpos + dxq : hpos - dxq;
                    st   <= DWRT; t <= 0;
                end
            end
            DWRT: begin // rec_we writes the record in the sync block above
                if( rec_we ) dslot <= dslot + 8'd1;
                if( stop || entry[7:0]==8'hff ) begin
                    reccnt   <= rec_we ? dslot + 8'd1 : dslot;
                    rec_ok   <= 1;
                    dec_done <= 1;
                    st       <= IDLE;
                end else begin
                    entry <= entry + 9'd1;
                    st    <= DLST; t <= 0;
                end
            end
            default: st <= IDLE;
        endcase
        if( ln_hs ) begin // line start
            vlat    <= flip ? 9'd223 - {1'b0, ln_v} : {1'b0, ln_v};
            st_dout <= {st != IDLE, hitcnt};
            hitcnt  <= 0;
            if( ln_v == 8'hff ) begin
                // blank: the decode pass owns st/t, do not disturb it here.
                // It starts once the snapshot DMA has settled
                bcnt <= bcnt + 6'd1;
                if( bcnt == 6'd7 && !dec_done ) dec_pend <= 1;
            end else begin
                vs_pend  <= 0;
                t        <= 0;
                desc_we  <= 0;
                bcnt     <= 0;
                dec_done <= 0;
                entry    <= {1'b0, reccnt - 8'd1};
                cra      <= reccnt - 8'd1;
                if( ln_v < 8'd224 )
                    st <= (rec_ok && reccnt != 0) ? RLOD : PEOL;
                else
                    st <= IDLE;
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
