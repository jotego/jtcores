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
    // tile ROM (RCHAR)
    output            roz_cs,
    output reg [20:2] roz_addr,     // 32-bit words, texel xpos[1:0] = byte lane
    input             roz_ok,
    input      [31:0] roz_data,
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
                 CALCA=5, CALCB=6, CALCC=7, RUN=8;

reg  [15:0] rec[0:7];
reg  [ 3:0] fsm;
reg  [ 2:0] st, rcnt;
reg  [ 8:0] lline;
reg         lyr1, scl, hs_l;
reg  [ 1:0] fv, to, mo, tbl, mbl;
reg  [ 8:0] fx0, fx1;
reg  [ 1:0] flane0, flane1;
reg  [ 2:0] fmb0, fmb1;
reg         fmok0, fmok1, fbit0, fbit1, ftok0, ftok1;
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
            sx24, sy24, lxt, lyt, cx, cy;
// single-entry caches: one mask byte, one 4-texel word
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
wire        t0ok   = ftok0 || (roz_ok && tbl==0);
wire        ret    = fv[0] && fmok0 && t0ok;
wire [ 7:0] t_byt0 = ftok0 ? ftex0 : roz_data[{flane0,3'd0} +: 8];
wire        m_done = mo[1] && mbl==0 && rmask_ok;
wire        t_dup  = !h_thit && to[1] && roz_addr ==h_til[20:2];
wire        m_dup  = !h_mhit2 && mo[1] && rmask_addr==h_msk;
wire        pophit = h_vld && !ret && (!h_draw || (h_mhit2 && h_thit));
wire        popst  = h_vld && h_draw && !(h_mhit2 && h_thit) && !ret && !fv[1]
                     && !t_dup && (h_thit || !to[1])
                     && (h_mhit2 || (opq_cur && !m_dup && !mo[1]));
wire        pop    = pophit || popst;
// line buffer write
reg  [15:0] bdata;
reg  [ 8:0] baddr;
reg         bwe, bwl;

reg  [11:0] xpos, ypos;
reg         in_win;
integer     i;

wire [15:0] q0, q1;
wire [127:0] ctl0, ctl1;
wire [11:0] xw, yw, pyr, pym, ysl;
wire [23:0] cyfw;
wire [16:1] map_a;
wire [15:0] rec_a;
wire [ 8:0] hd, rda, nline;
wire        scl_mode, hs_edge, in_x, in_y, b0, b1, sel0;

assign rmask_cs = mo[1];
assign roz_cs   = to[1];

assign scl_mode = ctl0[15:0]==16'h8000;
assign hs_edge  = hs & ~hs_l;
assign nline    = vdump + 9'd1 - V0;

assign xw   = cx[23:12];
assign yw   = cy[23:12];
assign cyfw = cy - p_ay;                 // Y wrap in firmware space
assign pyr  = cyfw[23:12];
assign pym  = pyr>=12'hc00 ? pyr-12'hc00 : pyr;
assign ysl  = pym + p_ay[23:12];
assign in_x = p_x1<=13'h1000 ? (xw>=p_left && {1'b0,xw}<p_x1)
                             : (xw>=p_left || {1'b0,xw}<p_x1-13'h1000);
assign in_y = p_y1<=13'h1000 ? (yw>=p_top  && {1'b0,yw}<p_y1)
                             : (yw>=p_top  || {1'b0,yw}<p_y1-13'h1000);

assign map_a = { xpos[11], ypos[11:4], xpos[10:4] };
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
integer rz_lines=0, rz_cut=0, rz_wait=0, rz_cyc=0, rz_maxc=0;
integer rz_fill=0, rz_req=0, rz_hit=0;
reg rz_vsl=0, rz_csl=0, rz_okl=0;
wire rz_okl_w = !rz_okl;
always @(posedge clk) begin
    rz_vsl <= vs;
    if( fsm != IDLE ) begin
        rz_cyc <= rz_cyc + 1;
        if( roz_cs && !roz_ok ) rz_wait <= rz_wait + 1;
        rz_csl <= roz_cs;
        rz_okl <= roz_cs && roz_ok;
        if( roz_cs && !rz_csl ) rz_req <= rz_req + 1;         // new requests
        if( roz_cs && roz_ok && !rz_okl ) rz_hit <= rz_hit+1; // served
        if( roz_cs && !roz_ok && rz_okl_w ) rz_fill <= rz_fill + 1;
    end
    if( hs_edge ) begin
        if( fsm != IDLE ) begin
            rz_cut <= rz_cut + 1;
            $display("RZCUT line=%0d xi=%0d fsm=%0d cyc=%0d fills=%0d freq=%0d", lline, xi, fsm, rz_cyc, rz_fill, rz_req);
        end
        rz_fill <= 0; rz_req <= 0;
        if( rz_cyc > rz_maxc ) rz_maxc <= rz_cyc;
        rz_cyc <= 0;
        if( nline < VLINES ) rz_lines <= rz_lines + 1;
    end
    if( vs && !rz_vsl ) begin
        $display("ROZA lines=%0d cut=%0d wait=%0d maxc=%0d", rz_lines, rz_cut, rz_wait, rz_maxc);
        rz_lines<=0; rz_cut<=0; rz_wait<=0; rz_maxc<=0;
    end
end
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
        s1_v  <= 0;
        s2_v  <= 0;
        f_cnt <= 0;
        f_rd  <= 0;
        f_wr  <= 0;
        h_vld <= 0;
        rozmap_addr <= 0;
        rmask_addr  <= 0;
        roz_addr    <= 0;
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
        if( hs_edge ) begin
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
            mo    <= 0;
            fsm   <= nline < VLINES ? LDREG : IDLE;
        end else case( fsm )
            LDREG: begin
                xi  <= 0;
                st  <= 0;
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
            CALCC: begin // scanline records already hold this line's start
                cx  <= sx24 + p_ax + (scl ? 24'd0 : lxt);
                cy  <= sy24 + p_ay + (scl ? 24'd0 : lyt);
                fsm <= RUN;
            end
            RUN: begin
                // front end: one map read per clock, positions walk on issue
                s1_v <= issue;
                s2_v <= s1_v;
                s2_x <= s1_x; s2_d <= s1_d; s2_xp <= s1_xp; s2_yp <= s1_yp;
                if( issue ) begin
                    rozmap_addr <= map_a;
                    s1_x  <= xi;
                    s1_d  <= p_en && in_win;
                    s1_xp <= xpos;
                    s1_yp <= ypos;
                    xi    <= xi + 9'd1;
                    if( p_en ) begin
                        cx <= cx + p_incxx;
                        cy <= cy + p_incxy;
                    end
                end
                if( s2_v ) begin // BRAM data belongs to the s2 token now
                    fifo[f_wr] <= { s2_d, s2_x, s2_xp, s2_yp, 1'b0, rozmap_data[13:0] };
                    f_wr <= f_wr + 2'd1;
                end
                f_cnt <= f_cnt + {2'd0,s2_v} - {2'd0,pop};
                // back end: caches hit -> one pixel per clock, else fetch
                if( tbl!=0 ) tbl <= tbl-2'd1;
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
                    bwe   <= 1;
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
                        roz_addr <= h_til[20:2];
                        tbl <= 2'd2;
                        to  <= {1'b1, fv[0]};
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
                    bwe   <= 1;
                    if( !ftok0 ) begin
                        c_tword <= roz_data;
                        c_taddr <= roz_addr;
                        c_tok   <= 1;
                        to      <= 0;
                    end
                    fv[0] <= fv[1];
                    fv[1] <= 0;
                    fx0<=fx1; flane0<=flane1; fmb0<=fmb1;
                    ftok0<=ftok1; ftex0<=ftex1; fmok0<=fmok1; fbit0<=fbit1;
                    if( to==2'b11 ) to <= 2'b10;
                    if( mo==2'b11 ) mo <= 2'b10;
                end
                if( xi==LINE_W && f_cnt==0 && inflight==0 && fv==0 ) begin
                    lyr1 <= 1;
                    fsm  <= lyr1 ? IDLE : LDREG;
                end
            end
            default: fsm <= IDLE;
        endcase
    end
end

assign hd  = hdump - H0;
assign rda = flip ? LINE_W-9'd1-hd : hd;

jtframe_linebuf #(.DW(16)) u_buf0(
    .clk        ( clk       ),
    .LHBL       ( ~hs       ),
    .wr_addr    ( baddr     ),
    .wr_data    ( bdata     ),
    .we         ( bwe & ~bwl),
    .rd_addr    ( rda       ),
    .rd_data    ( q0        ),
    .rd_gated   (           )
);

jtframe_linebuf #(.DW(16)) u_buf1(
    .clk        ( clk       ),
    .LHBL       ( ~hs       ),
    .wr_addr    ( baddr     ),
    .wr_data    ( bdata     ),
    .we         ( bwe &  bwl),
    .rd_addr    ( rda       ),
    .rd_data    ( q1        ),
    .rd_gated   (           )
);

// layer mixing: same priority resolves to layer 0
assign b0   = q0[15];
assign b1   = q1[15];
assign sel0 = b0 && (!b1 || q0[14:11] >= q1[14:11]);

always @(posedge clk) if( pxl_cen ) begin
    roz_blankn <= b0 | b1;
    if( sel0 ) begin
        roz_prio <= q0[14:11];
        roz_pxl  <= {1'b0, q0[10:0]};
    end else begin
        roz_prio <= q1[14:11];
        roz_pxl  <= {1'b0, q1[10:0]};
    end
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
