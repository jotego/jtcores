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

// Namco C169 ROZ, System FL flavour. Two layers into a 256x256 map of
// 16x16x8bpp tiles (4096x4096px). Layer 0 reads per-scanline records at
// 0xE080 when control0==0x8000 (Speed Racer road). Each line is walked
// ahead of the beam into line buffers, texels fetched from SDRAM.

module jtc169(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             hs,
    input             vs,
    input             flip,
    input       [8:0] hdump,
    input       [8:0] vdump,
    // CPU control registers
    input             cs,
    input       [4:1] addr,
    input             rnw,
    input       [1:0] dsn,
    input      [15:0] din,
    output     [15:0] dout,
    // ROZ VRAM (BRAM, read only)
    output reg [16:1] rozmap_addr,
    input      [15:0] rozmap_data,
    // mask ROM (RSHAPE)
    output            rmask_cs,
    output reg [18:0] rmask_addr,
    input             rmask_ok,
    input      [ 7:0] rmask_data,
    output     [13:0] opq_addr,   // opaque-tile table lookup, skips mask fetches
    input             opq_bit,
    output reg [13:0] opq2_addr,  // prescan lookups on the table's idle port
    input             opq2_bit,
    output reg [15:0] cnt_cov,
    // opaque scr coverage from the c123 layers: covered columns skip
    output reg [ 4:0] cov_row,
    input     [215:0] cov_word,
    input      [17:0] cov_prio,
    input             cov_ok,
    input             cov_rdy,
    // road coverage summary for the tilemaps: line vdump+2, latched at hs
    output reg        sum_vld,    // covered span is valid (scl line, contiguous)
    output reg        sum_full,   // every visible pixel covered
    output reg [ 8:0] sum_x0, sum_x1,
    output reg [ 3:0] sum_prio,
    // tile ROM (RCHAR), two buses so two misses stay in flight
    output            roz_cs,
    output reg [20:2] roz_addr,     // 32-bit words, texel xpos[1:0] = byte lane
    input             roz_ok,
    input      [31:0] roz_data,
    output            rozb_cs,
    output reg [20:2] rozb_addr,
    input             rozb_ok,
    input      [31:0] rozb_data,
    // pixel output
    output reg [11:0] roz_pxl,
    output reg [ 3:0] roz_prio,
    output reg        roz_blankn,
    // IOCTL dump
    input      [ 4:0] ioctl_addr,
    output     [ 7:0] ioctl_din,

    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

parameter SIMFILE="rest.bin", SEEK=64;


parameter  [8:0] H0     = 9'h040,  // first visible hdump, adjust to vtimer
                 V0     = 9'd0;    // first visible vdump, adjust to vtimer
localparam [8:0] LINE_W = 9'd288,
                 VLINES = 9'd224;

localparam [3:0] IDLE=0, LDREG=1, RECA=2, RECW=3, RECL=4,
                 CALCA=5, CALCB=6, CALCC=7, RUN=8, WAITL=9,
                 CLRB=10, ADV=11;
localparam [8:0] AHEAD=9'd2; // render-ahead depth over the classic 1 line

reg  [15:0] rec[0:7];
reg  [ 3:0] fsm;
reg  [ 2:0] st, rcnt;
reg  [ 8:0] lline;
reg         lyr1, scl, hs_l;
reg  [ 1:0] fv, to, mo, tbl, mbl, tob, tbb;
reg  [ 8:0] fx0, fx1;
reg  [ 1:0] flane0, flane1;
reg  [ 2:0] fmb0, fmb1;
reg         fmok0, fmok1, fbit0, fbit1, ftok0, ftok1, fbus0, fbus1;
reg  [ 7:0] ftex0, ftex1;
// unpacked parameters, 12.12 fixed point
reg         p_en, p_wrap, p_wrapy;
reg  [ 2:0] p_color;
reg  [ 3:0] p_prio;
(* multstyle = "dsp" *) wire [23:0] lxt_m = p_incyx * {15'd0, lline};
(* multstyle = "dsp" *) wire [23:0] lyt_m = p_incyy * {15'd0, lline};
(* multstyle = "dsp" *) wire [23:0] pax_m = p_incxx*24'd36 + p_incyx*24'd3;
(* multstyle = "dsp" *) wire [23:0] pay_m = p_incxy*24'd36 + p_incyy*24'd3;
reg  [11:0] p_left, p_top, p_smask;
reg  [12:0] p_size, p_x1, p_y1;
reg  [23:0] p_incxx, p_incxy, p_incyx, p_incyy, p_ax, p_ay,
            sx24, sy24, lxt, lyt, cx, cy, cyf;
// single-entry caches: one mask byte, one 4-texel word (copy A)
reg  [18:0] c_maddr;
reg  [20:2] c_taddr;
reg  [ 7:0] c_mbyte;
reg  [31:0] c_tword;
reg         c_mok, c_tok;
// render pipeline: map read issue -> 2 BRAM stages -> 4-entry FIFO -> fetch/write
reg  [ 8:0] xi, s1_x, s2_x;
reg         s1_v, s2_v, s1_d, s2_d;
reg  [11:0] s1_xp, s1_yp, s2_xp, s2_yp;
(* ramstyle = "MLAB, no_rw_check" *) reg [48:0] fifo[0:3]; // {draw, x, xpos, ypos, code}
reg  [ 1:0] f_rd, f_wr;
reg  [ 2:0] f_cnt;
// skid register on the FIFO head: the back-end comparators work on FFs.
// One idle cycle when the queue refills from empty
reg  [48:0] hreg;
reg         h_vld;
wire [48:0] f_head = hreg;
wire        h_draw = f_head[48];
wire [ 8:0] h_x    = f_head[47:39];
wire [11:0] h_xp   = f_head[38:27], h_yp = f_head[26:15];
wire [13:0] h_code = f_head[13:0];
wire [18:0] h_msk  = { h_code, h_yp[3:0], h_xp[3] };
wire [20:0] h_til  = { h_code[12:0], h_yp[3:0], h_xp[3:0] };
reg  [13:0] opq_cl;
wire        opq_cur = opq_cl == h_code;
wire        h_opq   = opq_cur && opq_bit;
wire        h_mhit  = c_mok && c_maddr==h_msk;
wire        h_thit = c_tok && c_taddr==h_til[20:2];
wire [ 7:0] h_tex  = c_tword[ {h_til[1:0],3'd0} +: 8 ];
wire        h_mbit = c_mbyte[ ~h_xp[2:0] ];
wire        h_mhit2 = h_mhit || h_opq;
wire        h_mbit2 = h_mhit ? h_mbit : 1'b1;
assign      opq_addr = h_code;
wire [ 2:0] inflight = {2'd0,s1_v} + {2'd0,s2_v};
wire        issue  = fsm==RUN && xi!=LINE_W && (f_cnt + inflight) < 3'd4;
wire        t0ok   = ftok0 || (fbus0 ? (rozb_ok && tbb==0) : (roz_ok && tbl==0));
wire        ret    = fv[0] && fmok0 && t0ok;
wire [31:0] t_wrd0 = fbus0 ? rozb_data : roz_data;
wire [ 7:0] t_byt0 = ftok0 ? ftex0 : t_wrd0[{flane0,3'd0} +: 8];
wire        m_done = mo[1] && mbl==0 && rmask_ok;
wire        t_dup  = !h_thit && ((to[1]  && roz_addr ==h_til[20:2]) ||
                                 (tob[1] && rozb_addr==h_til[20:2]));
wire        m_dup  = !h_mhit2 && mo[1] && rmask_addr==h_msk;
wire        pophit = h_vld && !ret && (!h_draw || (h_mhit2 && h_thit));
wire        popst  = h_vld && h_draw && !(h_mhit2 && h_thit) && !ret && !fv[1]
                     && !t_dup && (h_thit || !to[1] || !tob[1])
                     && (h_mhit2 || (opq_cur && !m_dup && !mo[1]));
wire        pop    = pophit || popst;
// line buffer write
reg  [15:0] bdata;
reg  [ 8:0] baddr;
reg         bwe, bwl;

reg  [11:0] xpos, ypos;
reg         in_win;
reg  [215:0] cw;
reg  [  4:0] ccnt;
integer     i;
// layer-0 winner companion: the L1 pass skips pixels L0 already won
wire [ 4:0] l0_q;
wire [ 8:0] l0_ra = issue ? xi+9'd1 : xi; // read one ahead of the walk
reg         l0_live;   // this line's L0 pass really ran
wire        l0_skip = lyr1 && l0_live && l0_q[4] && l0_q[3:0] >= p_prio;
// a disabled pass leaves its plane alone when it is already blank
reg  [ 3:0] cln0;
reg  [ 8:0] clr_x, swp;
// tail blanker: sweeps the pass's plane down toward the walk on idle write
// cycles, so an aborted line shows a hole instead of stale texels
wire        swp_we = fsm==RUN && !lyr1 && !bwe && swp >= xi && swp != 9'h1ff;
// column of the pixel being issued; coverage words align to 8px screen columns
wire [5:0]  cov_col = xi[8:3];
reg         cov_hit;
always @* begin
    cov_hit = 0;
    for( i=0; i<6; i=i+1 )
        if( cw[i*36+{26'd0,cov_col}] &&
            {1'b0,cov_prio[i*3 +: 3],1'b0} >= p_prio ) cov_hit = 1;
end

// records-only coverage prescan: walks line vdump+2 of the road (scl mode)
// through the map and the opq table on idle cycles, no texel traffic.
// Replicates the render DDA bit for bit; anything unexpected drops valid.
reg  [ 2:0] q_st, q_rcnt;
reg  [ 8:0] q_x;
reg  [15:0] q_rec[0:7];
reg  [23:0] q_cx, q_cy, q_cyf, q_dxx, q_dxy, q_ay;
reg  [ 8:0] q_x0, q_x1;
reg         q_run, q_gap, q_vld, q_wrapy, q_pend, q_mapw;
reg  [ 9:0] q_tgt;
wire [11:0] q_xw  = q_cx[23:12];
wire [11:0] q_pyr = q_cyf[23:12];
wire [11:0] q_pym = q_pyr>=12'hc00 ? q_pyr-12'hc00 : q_pyr;
wire [11:0] q_ysl = q_pym + q_ay[23:12];
wire [11:0] q_yw  = q_cy[23:12];
wire [11:0] q_yp  = q_wrapy ? q_ysl : q_yw;
wire [16:1] q_map = { q_xw[11], q_yp[11:4], q_xw[10:4] };
// 36*inc + 3*inc porch terms as shift-adds, no DSP
function [23:0] q_pax( input [23:0] a, input [23:0] b );
    q_pax = (a<<5)+(a<<2)+(b<<1)+b;
endfunction
wire [ 9:0] q_lin = {1'b0,vdump}+10'd2-{1'b0,V0};
wire [15:0] q_rca = 16'h7040 + {3'd0,q_lin[8:3],7'd0} + {10'd0,q_lin[2:0],3'd0}
                  + {13'd0,q_rcnt};

wire [15:0] q0;
wire [127:0] ctl0, ctl1;
wire [11:0] xw, yw, pyr, pym, ysl;
wire [23:0] cyfw;
wire [16:1] map_a;
wire [15:0] rec_a;
wire [ 8:0] hd, rda, nline;
wire        scl_mode, hs_edge, in_x, in_y, b0;

assign rmask_cs = mo[1];
assign roz_cs   = to[1];
assign rozb_cs  = tob[1];

assign scl_mode = ctl0[15:0]==16'h8000;
assign hs_edge  = hs & ~hs_l;
assign nline    = vdump + 9'd1 - V0;

assign xw   = cx[23:12];
assign yw   = cy[23:12];
assign cyfw = cyf;                       // Y wrap in firmware space
assign pyr  = cyfw[23:12];
assign pym  = pyr>=12'hc00 ? pyr-12'hc00 : pyr;
assign ysl  = pym + p_ay[23:12];
assign in_x = p_x1<=13'h1000 ? (xw>=p_left && {1'b0,xw}<p_x1)
                             : (xw>=p_left || {1'b0,xw}<p_x1-13'h1000);
assign in_y = p_y1<=13'h1000 ? (yw>=p_top  && {1'b0,yw}<p_y1)
                             : (yw>=p_top  || {1'b0,yw}<p_y1-13'h1000);

assign map_a = { xpos[11], ypos[11:4], xpos[10:4] };
// the prescan borrows the map port on cycles the front end leaves idle
wire q_take = q_pend && !issue && fsm!=RECA && fsm!=RECW && fsm!=RECL;
assign rec_a = 16'h7040 + {3'd0,lline[8:3],7'd0} + {10'd0,lline[2:0],3'd0}
             + {13'd0,rcnt};

function [23:0] inc24( input [15:0] w, input full16 );
    reg [15:0] v;
begin
    v     = full16 ? w : w[15] ? (w|16'hf000) : (w&16'h0fff);
    inc24 = { {4{v[15]}}, v, 4'd0 };
end
endfunction

// texel coordinates
always @* begin
    in_win = 1;
    if( scl ) begin
        xpos = xw;
        ypos = p_wrapy ? ysl : yw;
    end else if( p_wrap ) begin
        xpos = (xw & p_smask) + p_left;
        ypos = (yw & p_smask) + p_top;
    end else begin
        xpos   = xw;
        ypos   = yw;
        in_win = in_x & in_y;
    end
end

`ifdef SYSFL_ROZDBG
// per-frame roz deadline audit: lines whose walk missed the next hs
integer rz_lines=0, rz_cut=0, rz_wait=0, rz_cyc=0, rz_maxc=0, rz_cov=0, rz_frm=0, rz_l1s=0;
integer rz_fill=0, rz_req=0, rz_hit=0;
reg rz_vsl=0, rz_csl=0, rz_okl=0;
wire rz_okl_w = !rz_okl;
wire rz_ladv = fsm==ADV && lyr1;
always @(posedge clk) begin
    rz_vsl <= vs;
    if( fsm != IDLE && fsm != WAITL ) begin
        rz_cyc <= rz_cyc + 1;
        rz_wait <= rz_wait + (roz_cs && !roz_ok ? 1:0) + (rozb_cs && !rozb_ok ? 1:0);
        rz_csl <= roz_cs;
        rz_okl <= roz_cs && roz_ok;
        if( roz_cs && !rz_csl ) rz_req <= rz_req + 1;         // new requests
        if( roz_cs && roz_ok && !rz_okl ) rz_hit <= rz_hit+1; // served
        if( roz_cs && !roz_ok && rz_okl_w ) rz_fill <= rz_fill + 1;
    end
    if( issue && cov_hit ) rz_cov <= rz_cov+1;
    if( issue && l0_skip && p_en && in_win && !cov_hit ) rz_l1s <= rz_l1s+1;
    if( rz_ladv ) begin // per rendered line, the drawer free-runs over hs
        if( rz_cyc > rz_maxc ) rz_maxc <= rz_cyc;
        rz_cyc <= 0; rz_fill <= 0; rz_req <= 0;
    end
    if( hs_edge ) begin
        if( nline < VLINES && lline < nline ) begin // display caught the drawer
            rz_cut <= rz_cut + 1;
            $display("RZCUT F=%0d line=%0d xi=%0d fsm=%0d cyc=%0d fills=%0d freq=%0d", rz_frm, lline, xi, fsm, rz_cyc, rz_fill, rz_req);
        end
        if( nline < VLINES ) rz_lines <= rz_lines + 1;
    end
    if( vs && !rz_vsl ) begin
        $display("ROZA F=%0d lines=%0d cut=%0d wait=%0d maxc=%0d cov=%0d l1s=%0d", rz_frm, rz_lines, rz_cut, rz_wait, rz_maxc, rz_cov, rz_l1s);
        rz_lines<=0; rz_cut<=0; rz_wait<=0; rz_maxc<=0; rz_cov<=0; rz_l1s<=0;
        rz_frm <= rz_frm+1;
    end
end
`ifdef SYSFL_PXTRACE
wire trc_w = rz_frm==3638 && lline>=9'd157 && lline<=9'd166;
always @(posedge clk) if( trc_w && fsm==RUN ) begin
    if( pophit && h_x>=9'd165 && h_x<=9'd210 )
        $display("TRC l=%0d ly=%0d x=%0d dr=%0d code=%h xp=%h yp=%h opq=%0d mhit=%0d mbit=%0d thit=%0d",
            lline, lyr1, h_x, h_draw, h_code, h_xp, h_yp, h_opq, h_mhit, h_mbit2, h_thit);
    if( ret && fx0>=9'd165 && fx0<=9'd210 )
        $display("TRR l=%0d ly=%0d x=%0d bit=%0d tex=%h", lline, lyr1, fx0, fbit0, t_byt0);
    if( issue && xi>=9'd165 && xi<=9'd210 && (!p_en || !in_win) )
        $display("TRW l=%0d ly=%0d x=%0d pen=%0d inwin=%0d xw=%h yw=%h", lline, lyr1, xi, p_en, in_win, xw, yw);
end
`endif
integer rz_mw=0, rz_tw=0, rz_ov=0;
always @(posedge clk) begin
    if( fsm != IDLE ) begin
        if( fv[0] && !fmok0 ) rz_mw <= rz_mw+1;
        if( fv[0] && fmok0 && !t0ok ) rz_tw <= rz_tw+1;
        if( fv[1] ) rz_ov <= rz_ov+1;
    end
    if( vs && !rz_vsl ) begin
        $display("ROZB mw=%0d tw=%0d ov=%0d", rz_mw, rz_tw, rz_ov);
        rz_mw<=0; rz_tw<=0; rz_ov<=0;
    end
end
`endif
// line render
always @(posedge clk) begin
    if( rst ) begin
        fsm   <= IDLE;
        st    <= 0;
        bwe   <= 0;
        c_mok <= 0;
        c_tok <= 0;
        hs_l  <= 0;
        fv    <= 0;
        to    <= 0;
        mo    <= 0;
        tob   <= 0;
        s1_v  <= 0;
        s2_v  <= 0;
        f_cnt <= 0;
        f_rd  <= 0;
        f_wr  <= 0;
        h_vld <= 0;
        rozmap_addr <= 0;
        opq2_addr   <= 0;
        roz_addr    <= 0;
        rozb_addr   <= 0;
        cln0        <= 0;
        lline       <= VLINES; // out of range: first visible hs resyncs
        sum_vld     <= 0;
        sum_full    <= 0;
        sum_x0      <= 0;
        sum_x1      <= 0;
        sum_prio    <= 0;
        q_st        <= 0;
        q_pend      <= 0;
        q_vld       <= 0;
        q_mapw      <= 0;
        q_rcnt      <= 0;
        rmask_addr  <= 0;
    end else begin
        hs_l <= hs;
        bwe  <= 0;
        opq_cl <= h_code;
        // an empty (or emptying) queue takes the push directly, so the skid
        // adds no cycle anywhere
        hreg  <= s2_v && f_cnt == {2'd0,pop} ?
                 { s2_d, s2_x, s2_xp, s2_yp, 1'b0, rozmap_data[13:0] } :
                 fifo[pop ? f_rd + 2'd1 : f_rd];
        h_vld <= f_cnt != {2'd0, pop} || s2_v;
        // ---------- records-only coverage prescan (line vdump+2) ----------
        q_mapw <= 1'b0;
        if( q_take ) begin
            case( q_st )
                1: begin rozmap_addr <= q_rca[15:0]; q_mapw <= 1; q_st <= 2; end
                5: begin rozmap_addr <= q_map;       q_mapw <= 1; q_st <= 6; end
                default:;
            endcase
        end
        if( q_st==2 || q_st==6 ) begin
            // the read is valid only if the port stayed ours for both cycles
            if( issue || fsm==RECA ) q_st <= q_st-3'd1; // stolen: retry
            else q_st <= q_st+3'd1;
        end else if( q_st==3 ) begin
            if( issue || fsm==RECA ) q_st <= 1; // last cycle stolen: retry
            else begin
                q_rec[q_rcnt] <= rozmap_data;
                q_rcnt <= q_rcnt+3'd1;
                q_st   <= q_rcnt==3'd7 ? 3'd4 : 3'd1;
            end
        end else if( q_st==4 ) begin // line setup from the records
            q_wrapy <= q_rec[0][15:3]==13'h0c00;
            q_dxx   <= inc24(q_rec[2],1'b1);
            q_dxy   <= inc24(q_rec[3],1'b1);
            q_cx    <= {q_rec[6],8'd0} + q_pax(inc24(q_rec[2],1'b1),inc24(q_rec[4],1'b1));
            q_cy    <= {q_rec[7],8'd0} + q_pax(inc24(q_rec[3],1'b1),inc24(q_rec[5],1'b1));
            q_cyf   <= {q_rec[7],8'd0};
            q_ay    <= q_pax(inc24(q_rec[3],1'b1),inc24(q_rec[5],1'b1));
            q_x     <= 0;
            q_run   <= 0;
            q_gap   <= 0;
            q_x0    <= 0;
            q_x1    <= 0;
            // road layer must be enabled and layer 1 off for a usable summary
            if( q_rec[1][15] || ctl0[31] || !ctl1[31] ) begin
                q_vld <= 0; q_pend <= 0; q_st <= 0;
            end else q_st <= 5;
        end else if( q_st==7 ) begin // map word in: tile -> opq port
            opq2_addr <= rozmap_data[13:0];
            q_st <= 3'd0; // reuse 0 as the opq-latency slot via q_x flag
            q_mapw <= 1;  // mark: opq read pending
        end
        if( q_mapw && q_st==0 && q_pend ) begin // opq2_bit valid now
            if( opq2_bit ) begin
                if( q_gap ) q_vld <= 0;       // second run: not contiguous
                if( !q_run ) begin q_run <= 1; q_x0 <= q_x; end
                q_x1 <= q_x;
            end else if( q_run ) q_gap <= 1;
            q_cx  <= q_cx + q_dxx;
            q_cy  <= q_cy + q_dxy;
            q_cyf <= q_cyf+ q_dxy;
            if( q_x==9'd287 ) begin q_pend <= 0; q_st <= 0; end
            else begin q_x <= q_x+9'd1; q_st <= 5; end
        end
        if( hs_edge ) begin
            // publish last line's walk, then restart for vdump+2
            // only a genuine road frame may publish: the mid-walk validity
            // check can lose the port race and leave stale state behind
            sum_vld  <= q_vld && !q_pend && q_run && q_tgt=={1'b0,nline}
                        && scl_mode && !ctl0[31] && ctl1[31];
            sum_full <= q_vld && !q_pend && q_run && !q_gap
                        && q_x0==9'd0 && q_x1==9'd287 && q_tgt=={1'b0,nline}
                        && scl_mode && !ctl0[31] && ctl1[31];
            sum_x0   <= q_x0;
            sum_x1   <= q_x1;
            sum_prio <= q_rec[1][7:4];
            q_pend <= scl_mode && q_lin<10'd224;
            q_tgt  <= q_lin;
            q_vld  <= 1;
            q_rcnt <= 0;
            q_st   <= 1;
        end
        // ---------- line render ----------
        // free-running drawer: lline advances on its own up to AHEAD lines
        // past the display; hs only resyncs at frame start or when behind
        if( hs_edge && nline < VLINES && (lline < nline || lline >= VLINES) ) begin
            lline <= nline;
            lyr1  <= 0;
            st    <= 0;
            s1_v  <= 0;
            s2_v  <= 0;
            f_cnt <= 0;
            f_rd  <= 0;
            f_wr  <= 0;
            fv    <= 0;
            to    <= 0;
            tob   <= 0;
            mo    <= 0;
            fsm   <= LDREG;
        end else case( fsm )
            WAITL: if( nline < VLINES && {1'b0,lline} <= {1'b0,nline}+{1'b0,AHEAD} )
                fsm <= LDREG;
            LDREG: begin
                xi  <= 0;
                st  <= 0;
                ccnt<= 0;
                cov_row <= lline[7:3];
                scl <= ~lyr1 & scl_mode;
                if( ~lyr1 & scl_mode ) begin
                    rcnt <= 0;
                    fsm  <= RECA;
                end else begin
                    for( i=0; i<8; i=i+1 ) rec[i] <= lyr1 ? ctl1[16*i +: 16] : ctl0[16*i +: 16];
                    fsm <= CALCA;
                end
            end
            RECA: begin
                rozmap_addr <= rec_a;
                fsm <= RECW;
            end
            RECW: fsm <= RECL;
            RECL: begin
                rec[rcnt] <= rozmap_data;
                rcnt <= rcnt + 3'd1;
                fsm  <= rcnt==7 ? CALCA : RECA;
            end
            CALCA: begin
                p_en    <= ~rec[1][15] & ~(scl & ctl0[31]);
                p_wrap  <= ~rec[1][11];
                p_size  <= 13'h0200 << rec[1][9:8];
                p_prio  <= rec[1][7:4];
                p_color <= rec[1][2:0];
                p_wrapy <= scl && rec[0][15:3]==13'h0c00; // Speed Racer 3072px Y ring
                p_left  <= scl ? 12'd0 : {rec[2][14:12],9'd0};
                p_top   <= scl ? 12'd0 : {rec[3][14:12],9'd0};
                p_incxx <= inc24(rec[2], scl);
                p_incxy <= inc24(rec[3], scl);
                p_incyx <= inc24(rec[4], scl);
                p_incyy <= inc24(rec[5], scl);
                sx24    <= {rec[6], 8'd0}; // signed 12.4 start
                sy24    <= {rec[7], 8'd0};
                case( rec[1][9:8] )
                    0: p_smask <= 12'h1ff;
                    1: p_smask <= 12'h3ff;
                    2: p_smask <= 12'h7ff;
                    3: p_smask <= 12'hfff;
                endcase
                fsm <= CALCB;
            end
            CALCB: begin // (36,3) analog porch and line terms
                p_ax <= pax_m;
                p_ay <= pay_m;
                lxt  <= lxt_m;
                lyt  <= lyt_m;
                p_x1 <= {1'b0,p_left} + p_size;
                p_y1 <= {1'b0,p_top}  + p_size;
                fsm  <= CALCC;
            end
            CALCC: if( cov_rdy || !p_en || &ccnt ) begin
                // wait for the packed coverage words, bounded
`ifdef SYSFL_NOCOV
                cw <= 216'd0;
`else
                cw <= cov_ok && cov_rdy ? cov_word : 216'd0;
`endif
                cx  <= sx24 + p_ax + (scl ? 24'd0 : lxt);
                cy  <= sy24 + p_ay + (scl ? 24'd0 : lyt);
                cyf <= sy24 + (scl ? 24'd0 : lyt);
                if( !lyr1 ) l0_live <= p_en;
                if( p_en ) begin
                    cln0[lline[1:0]] <= 0; // any real pass dirties the plane
                    swp <= LINE_W-9'd1;
                    fsm <= RUN;
                end else if( lyr1 || cln0[lline[1:0]] )
                    fsm <= ADV;       // L1 leaves L0's plane; blank plane is free
                else begin
                    clr_x <= 0;       // blank sweep, 1 px/clk, no fetches
                    fsm   <= CLRB;
                end
            end else ccnt <= ccnt + 5'd1;
            CLRB: begin // only the L0 pass blanks; L1 shares the plane
                bwe   <= 1;
                bwl   <= 0;
                bdata <= 16'd0;
                baddr <= clr_x;
                clr_x <= clr_x + 9'd1;
                if( clr_x == LINE_W-9'd1 ) begin
                    cln0[lline[1:0]] <= 1;
                    fsm <= ADV;
                end
            end
            ADV: begin
                if( !lyr1 ) begin
                    lyr1 <= 1;
                    fsm  <= LDREG;
                end else begin
                    lyr1  <= 0;
                    lline <= lline + 9'd1;
                    fsm   <= lline+9'd1 >= VLINES ? IDLE : WAITL;
                end
            end
            RUN: begin
                // front end: one map read per clock, positions walk on issue
                s1_v <= issue;
                s2_v <= s1_v;
                s2_x <= s1_x; s2_d <= s1_d; s2_xp <= s1_xp; s2_yp <= s1_yp;
                if( issue ) begin
                    rozmap_addr <= map_a;
                    s1_x  <= xi;
                    s1_d  <= p_en && in_win && !cov_hit && !l0_skip;
                    s1_xp <= xpos;
                    s1_yp <= ypos;
                    xi    <= xi + 9'd1;
                    if( p_en ) begin
                        cx  <= cx + p_incxx;
                        cy  <= cy + p_incxy;
                        cyf <= cyf + p_incxy;
                    end
                end
                if( s2_v ) begin // BRAM data belongs to the s2 token now
                    fifo[f_wr] <= { s2_d, s2_x, s2_xp, s2_yp, 1'b0, rozmap_data[13:0] };
                    f_wr <= f_wr + 2'd1;
                end
                f_cnt <= f_cnt + {2'd0,s2_v} - {2'd0,pop};
                // back end: caches hit -> one pixel per clock, else fetch
                if( tbl!=0 ) tbl <= tbl-2'd1;
                if( tbb!=0 ) tbb <= tbb-2'd1;
                if( mbl!=0 ) mbl <= mbl-2'd1;
                if( m_done && !ret ) begin
                    c_mbyte <= rmask_data;
                    c_maddr <= rmask_addr;
                    c_mok   <= 1;
                    if( mo[0] ) begin fbit1 <= rmask_data[~fmb1]; fmok1 <= 1; end
                    else        begin fbit0 <= rmask_data[~fmb0]; fmok0 <= 1; end
                    mo <= 0;
                end
                if( pophit ) begin
                    bdata <= h_draw ? { h_mbit2, p_prio, p_color, h_tex } : 16'd0;
                    baddr <= h_x;
                    bwl   <= lyr1;
                    bwe   <= !lyr1 || (h_draw && h_mbit2);
                    f_rd  <= f_rd + 2'd1;
                end else if( popst ) begin
                    f_rd <= f_rd + 2'd1;
                    if( fv[0] ) begin
                        fx1<=h_x; flane1<=h_til[1:0]; fmb1<=h_xp[2:0];
                        ftok1<=h_thit; ftex1<=h_tex; fmok1<=h_mhit2; fbit1<=h_mbit2;
                        fv[1]<=1;
                    end else begin
                        fx0<=h_x; flane0<=h_til[1:0]; fmb0<=h_xp[2:0];
                        ftok0<=h_thit; ftex0<=h_tex; fmok0<=h_mhit2; fbit0<=h_mbit2;
                        fv[0]<=1;
                    end
                    if( !h_thit ) begin
                        if( !to[1] ) begin
                            roz_addr <= h_til[20:2];
                            tbl <= 2'd2;
                            to  <= {1'b1, fv[0]};
                            if( fv[0] ) fbus1 <= 0; else fbus0 <= 0;
                        end else begin
                            rozb_addr <= h_til[20:2];
                            tbb <= 2'd2;
                            tob <= {1'b1, fv[0]};
                            if( fv[0] ) fbus1 <= 1; else fbus0 <= 1;
                        end
                    end
                    if( !h_mhit2 ) begin
                        rmask_addr <= h_msk;
                        mbl <= 2'd2;
                        mo  <= {1'b1, fv[0]};
                    end
                end else if( ret ) begin
                    bdata <= { fbit0, p_prio, p_color, t_byt0 };
                    baddr <= fx0;
                    bwl   <= lyr1;
                    bwe   <= !lyr1 || fbit0;
                    if( !ftok0 ) begin
                        c_tword <= t_wrd0;
                        c_taddr <= fbus0 ? rozb_addr : roz_addr;
                        c_tok   <= 1;
                        if( fbus0 ) tob <= 0; else to <= 0;
                    end
                    fv[0] <= fv[1];
                    fv[1] <= 0;
                    fx0<=fx1; flane0<=flane1; fmb0<=fmb1; fbus0<=fbus1;
                    ftok0<=ftok1; ftex0<=ftex1; fmok0<=fmok1; fbit0<=fbit1;
                    if( to ==2'b11 ) to  <= 2'b10;
                    if( tob==2'b11 ) tob <= 2'b10;
                    if( mo ==2'b11 ) mo  <= 2'b10;
                end
                if( swp_we ) swp <= swp==9'd0 ? 9'h1ff : swp-9'd1;
                if( xi==LINE_W && f_cnt==0 && inflight==0 && fv==0 )
                    fsm <= ADV;
            end
            default: fsm <= IDLE;
        endcase
    end
end

// per-frame skip tallies for the OSD debug view
reg dvs_l;
always @(posedge clk) begin
    dvs_l <= vs;
    if( vs && !dvs_l ) begin
        cnt_cov <= 0;
    end else if( issue && cov_hit ) cnt_cov <= cnt_cov + 16'd1;
end

assign hd  = hdump - H0;
assign rda = flip ? LINE_W-9'd1-hd : hd;
wire [8:0] rdline = nline - 9'd1; // displayed row, V0 folded via nline

// L0 winner per x of the line in progress; written by the L0 pass,
// read one pixel ahead by the L1 pass of the same line
jtframe_dual_ram #(.DW(5),.AW(9)) u_l0win(
    .clk0   ( clk       ),
    .data0  ( {bdata[15], bdata[14:11]} ),
    .addr0  ( baddr     ),
    .we0    ( bwe & ~bwl),
    .q0     (           ),
    .clk1   ( clk       ),
    .data1  ( 5'd0      ),
    .addr1  ( l0_ra     ),
    .we1    ( 1'b0      ),
    .q1     ( l0_q      )
);

// 4-line buffers: the drawer runs up to AHEAD+1 lines past the display,
// banking cheap (sky) lines' time for the heavy horizon band
wire [10:0] bwa_mux = swp_we ? {lline[1:0], swp} : {lline[1:0], baddr};
wire [15:0] bwd_mux = swp_we ? 16'd0 : bdata;
wire        bww     = bwe | swp_we;

// single merged plane: the L1 pass only writes pixels that win the mixer
// compare (the L0-winner skip removes the rest), so both layers share it
jtframe_dual_ram #(.AW(11),.DW(16)) u_buf0(
    .clk0       ( clk       ),
    .data0      ( bwd_mux   ),
    .addr0      ( bwa_mux   ),
    .we0        ( bww       ),
    .q0         (           ),
    .clk1       ( clk       ),
    .data1      ( 16'd0     ),
    .addr1      ( {rdline[1:0], rda}  ),
    .we1        ( 1'b0      ),
    .q1         ( q0        )
);

assign b0 = q0[15];

always @(posedge clk) if( pxl_cen ) begin
    roz_blankn <= b0;
    roz_prio   <= q0[14:11];
    roz_pxl    <= {1'b0, q0[10:0]};
end

// control registers
jtsysfl_roz_mmr #(.SIMFILE(SIMFILE),.SEEK(SEEK)) u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( cs        ),
    .addr       ( addr      ),
    .rnw        ( rnw       ),
    .din        ( din       ),
    .dout       ( dout      ),
    .dsn        ( dsn       ),
    .lyr0       ( ctl0      ),
    .lyr1       ( ctl1      ),
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

endmodule
