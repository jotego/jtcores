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
// jtframe_lfbuf line frame buffer. jtc355_scan walks the sprite tables and
// queues one descriptor per visible tile column; the drawer here fetches
// each column's tile row ahead of the draw and writes 8bpp pens through
// ln_addr/ln_data/ln_we. ln_done reports the line finished. Line = ln_v,
// screen coordinates 0-223. Word written = {prio, color, pen}. Pen 0xff is
// transparent, 0xffe flags a shadow pixel for the mixer. Sprite table RAM
// is external (mem.yaml)

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
    output     [16:1] objtab_addr,
    input      [15:0] objtab_data,

    // OBJ ROM, 16x16x8bpp tiles
    output reg        objrom_cs,
    output reg [22:2] objrom_addr,
    input             objrom_ok,
    input      [31:0] objrom_data,

    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [92:0] desc_data;
wire        desc_we, fwd_pass;
// first-write-wins support: pixels already written and 8-pixel groups full
reg  [511:0] wmask;
reg  [ 63:0] gfull;
wire         line_full;

// column descriptor FIFO, scan runs ahead of the drawer
(* ramstyle = "MLAB, no_rw_check" *) reg [92:0] fifo[0:7];
reg  [ 3:0] fwp, frp;
wire        fifo_empty = fwp == frp;
wire        desc_full  = fwp[2:0]==frp[2:0] && fwp[3]!=frp[3];
wire [92:0] fifo_rd    = fifo[frp[2:0]];

// staged descriptor: row fetched (or eol) while the previous column draws
reg  [92:0] nxt;
reg         nxt_vld, nxt_rdy;
// descriptor being drawn
reg  [ 9:0] cur_tsw, cur_sr;
reg  [ 4:0] cur_sq;
reg  [ 7:0] cur_pal;
reg         cur_hflip;
reg  signed [12:0] cur_wx0, cur_wx1;
reg         cur_vld;

wire [14:0] nxt_code  = nxt[14:0];
wire [ 3:0] nxt_vsub  = nxt[18:15];
wire        nxt_eol   = nxt[92];
(* ramstyle = "MLAB, no_rw_check" *) reg [31:0] rowb[0:7]; // 16 source pens per column, {buf, word}, ping-pong
reg         [ 1:0] fw;          // word being fetched
reg                fetch_bsy, cbuf, nbuf;
reg  signed [12:0] xdr;
reg         [ 9:0] pxleft;
reg         [10:0] acc;
reg         [ 3:0] srcx;

wire        [ 3:0] srcx_e = cur_hflip ? 4'd15 - srcx : srcx;
wire        [31:0] rowb_w = rowb[{cbuf, srcx_e[3:2]}];
wire        [ 7:0] pen    = rowb_w[{srcx_e[1:0],3'd0}+:8];
wire               xok    = xdr >= cur_wx0 && xdr <= cur_wx1;
wire        [ 8:0] xw     = flip ? 9'd287 - xdr[8:0] : xdr[8:0];
wire        [ 8:0] wa     = xw + H0 + 9'd1;
wire        [10:0] acc_r  = acc + {1'b0, cur_sr};
wire               acc_c  = acc_r >= {1'b0, cur_tsw};
// clipped span endpoints of the queued column, in line buffer addresses
wire signed [12:0] q_x0  = $signed(fifo_rd[41:29]) < $signed(fifo_rd[63:51]) ?
                           $signed(fifo_rd[63:51]) : $signed(fifo_rd[41:29]);
wire signed [12:0] q_x1a = $signed(fifo_rd[41:29]) + $signed({3'd0,fifo_rd[28:19]}) - 13'sd1;
wire signed [12:0] q_x1  = q_x1a > $signed(fifo_rd[76:64]) ? $signed(fifo_rd[76:64]) : q_x1a;
wire        [ 8:0] q_a0  = (flip ? 9'd287 - q_x0[8:0] : q_x0[8:0]) + H0 + 9'd1;
wire        [ 8:0] q_a1  = (flip ? 9'd287 - q_x1[8:0] : q_x1[8:0]) + H0 + 9'd1;
wire        [ 5:0] q_gl  = (flip ? q_a1[8:3] : q_a0[8:3]);
wire        [ 5:0] q_gh  = (flip ? q_a0[8:3] : q_a1[8:3]);
wire        [63:0] q_rng = (64'h2 << q_gh) - (64'h1 << q_gl);
wire               q_cov = !fwd_pass && !fifo_rd[92] && &(gfull | ~q_rng);
// promote the staged column into the drawer as soon as its row is in
wire               pro    = !cur_vld && nxt_vld && nxt_rdy && !ln_done;
wire               pop    = (!nxt_vld || pro || q_cov) && !fifo_empty && !fetch_bsy;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        fwp       <= 0;
        frp       <= 0;
        nxt_vld   <= 0;
        nxt_rdy   <= 0;
        cur_vld   <= 0;
        fetch_bsy <= 0;
        objrom_cs <= 0;
        cbuf      <= 0;
        nbuf      <= 0;
        ln_we     <= 0;
        ln_done   <= 0;
        wmask     <= 0;
        gfull     <= 0;
    end else begin
        ln_we <= 0;
        if( desc_we ) begin
            fifo[fwp[2:0]] <= desc_data;
            fwp <= fwp + 4'd1;
        end
        // whole tile row fetched up front, 4 words, then drawn without stalls
        if( fetch_bsy && objrom_ok ) begin
            rowb[{nbuf,fw}] <= objrom_data;
            fw <= fw + 2'd1;
            objrom_addr <= {nxt_code, nxt_vsub, fw + 2'd1};
            if( &fw ) begin
                objrom_cs <= 0;
                fetch_bsy <= 0;
                nxt_rdy   <= 1;
            end
        end
        if( pro ) begin
            nxt_vld <= 0;
            if( nxt_eol ) begin
                ln_done <= 1;
            end else begin
                cur_vld   <= 1;
                cbuf      <= nbuf;
                nbuf      <= ~nbuf;
                cur_tsw   <= nxt[28:19];
                xdr       <= $signed(nxt[41:29]);
                cur_pal   <= nxt[49:42];
                cur_hflip <= nxt[50];
                cur_wx0   <= $signed(nxt[63:51]);
                cur_wx1   <= $signed(nxt[76:64]);
                cur_sr    <= nxt[86:77];
                cur_sq    <= nxt[91:87];
                pxleft    <= nxt[28:19];
                srcx      <= 0;
                acc       <= 0;
            end
        end
        if( pop ) begin
            if( q_cov ) begin // column fully hidden, drop it unfetched
                frp <= frp + 4'd1;
            end else begin
                nxt     <= fifo_rd;
                frp     <= frp + 4'd1;
                nxt_vld <= 1;
                nxt_rdy <= fifo_rd[92]; // eol carries no row
                if( !fifo_rd[92] ) begin
                    objrom_addr <= {fifo_rd[14:0], fifo_rd[18:15], 2'd0};
                    objrom_cs   <= 1;
                    fw          <= 0;
                    fetch_bsy   <= 1;
                end
            end
        end
        if( cur_vld ) begin // one screen pixel per clock, x-zoom accumulator
            if( xdr > cur_wx1 ) begin
                cur_vld <= 0; // rest of the tile falls right of the window
            end else begin
                if( xok && pen != 8'hff && (fwd_pass || !wmask[wa]) ) begin
                    ln_we   <= 1;
                    ln_addr <= wa;
                    ln_data <= {cur_pal, pen};
                    wmask[wa] <= 1'b1;
                    if( &(wmask[{wa[8:3],3'd0} +: 8] | (8'h1 << wa[2:0])) )
                        gfull[wa[8:3]] <= 1'b1;
                end
                xdr    <= xdr + 13'sd1;
                pxleft <= pxleft - 10'd1;
                if( pxleft == 10'd1 ) begin
                    cur_vld <= 0;
                end else begin
                    srcx <= srcx + cur_sq[3:0] + {3'd0, acc_c};
                    acc  <= acc_c ? acc_r - {1'b0, cur_tsw} : acc_r;
                end
            end
        end
        if( ln_hs ) begin // line start
            wmask     <= 0;
            gfull     <= 0;
            fwp       <= 0;
            frp       <= 0;
            nxt_vld   <= 0;
            nxt_rdy   <= 0;
            cur_vld   <= 0;
            fetch_bsy <= 0;
            objrom_cs <= 0;
            ln_we     <= 0;
            ln_done   <= ln_v >= 8'd224; // blank line, nothing to draw
        end
    end
end

assign line_full = !fwd_pass && &gfull[43:9] &&
                   &wmask[9'h47:9'h41] && wmask[9'h160] && wmask[9'h161];

jtc355_scan u_scan(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .flip       ( flip        ),
    .sprbank    ( sprbank     ),
    .ln_hs      ( ln_hs       ),
    .ln_v       ( ln_v        ),
    .objtab_addr( objtab_addr ),
    .objtab_data( objtab_data ),
    .desc_data  ( desc_data   ),
    .desc_we    ( desc_we     ),
    .desc_full  ( desc_full   ),
    .line_full  ( line_full   ),
    .fwd_pass   ( fwd_pass    ),
    .debug_bus  ( debug_bus   ),
    .st_dout    ( st_dout     )
);

`ifdef SYSFL_OBJDBG
// overdraw probe: writes hitting an already-written pixel this line
reg [511:0] ovr_mask;
integer ovr_wr=0, ovr_hit=0;
always @(posedge clk) begin
    if( ln_we ) begin
        ovr_wr <= ovr_wr+1;
        if( ovr_mask[ln_addr] ) ovr_hit <= ovr_hit+1;
        ovr_mask[ln_addr] <= 1'b1;
    end
    if( ln_hs ) begin
        ovr_mask <= 0;
        if( ln_v == 8'd0 ) begin
            $display("OVR wr=%0d hit=%0d", ovr_wr, ovr_hit);
            ovr_wr <= 0; ovr_hit <= 0;
        end
    end
end
`endif
`ifdef SYSFL_OBJDBG
// drawer-visible stalls only: the staged fetch is supposed to miss
integer fstall=0, sstall=0, lcyc=0, over=0, cut=0, maxl=0, lines=0, donel=0;
reg     lact=0;
always @(posedge clk) begin
    if( lact && !ln_done ) begin
        lcyc <= lcyc + 1;
        if( !cur_vld &&  nxt_vld && !nxt_rdy ) fstall <= fstall+1;
        if( !cur_vld && !nxt_vld && fifo_empty ) sstall <= sstall+1;
    end
    if( ln_done && lact ) begin
        lact  <= 0;
        donel <= lcyc;
        if( lcyc > maxl ) maxl <= lcyc;
    end
    if( ln_hs ) begin
        if( ln_v < 8'd224 ) begin
            lines <= lines + 1;
            if( lact ) cut <= cut + 1;          // previous line never finished
            else if( donel > 3053 ) over <= over + 1;
            lact <= 1;
            lcyc <= 0;
            donel<= 0;
        end
        if( ln_v == 8'd0 ) begin
            $display("SOBJ lines=%0d fstall=%0d sstall=%0d over=%0d cut=%0d maxl=%0d",
                lines, fstall, sstall, over, cut, maxl);
            fstall<=0; sstall<=0; over<=0; cut<=0; maxl<=0; lines<=0;
        end
    end
end
`endif

endmodule
