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
    input             ioctl_ram,  // dump machinery owns the table port

    input             flip,
    input      [ 1:0] sprbank,

    // line frame buffer
    input             ln_hs,
    input      [ 7:0] ln_v,
    output reg [ 8:0] ln_addr,
    output reg [15:0] ln_data,
    output reg        ln_we,
    output reg        ln_done,

    // sprite table RAM; the DMA snapshots the placement tables at vblank
    output     [16:1] objtab_addr,
    output     [15:0] objtab_din,
    output     [ 1:0] objtab_we,
    input      [15:0] objtab_data,

    // OBJ ROM, 16x16x8bpp tiles
    output reg        objrom_cs,
    output reg [22:2] objrom_addr,
    input             objrom_ok,
    input      [31:0] objrom_data,

    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [104:0] desc_data;
wire        desc_we, fwd_pass;
// vblank DMA: attr/list/clip (0000-13ff) and format (2000-3fff) tables are
// copied to +c800, so the scan reads a frame-coherent snapshot while the CPU
// keeps writing the live tables
localparam [15:0] OFS1 = 16'hc800, OFS2 = 16'hc000; // dst = src + segment offset
reg  [13:0] dma_src;
reg         dma_bsy, dma_phase, snapped, dma_pend;
reg  [ 7:0] lnv_l;
wire [16:1] scan_addr;
wire        scan_hs;
assign objtab_addr = dma_bsy ? (dma_phase ? {2'd0,dma_src} + (dma_src<14'h800 ? OFS1 : OFS2)
                                          : {2'd0,dma_src})
                             : scan_addr;
assign objtab_din  = objtab_data;
assign objtab_we   = {2{dma_bsy && dma_phase}};
assign scan_hs     = ln_hs && !dma_bsy;

`ifdef SYSFL_DMADBG
integer dmacnt=0;
always @(posedge clk) begin
    if( dma_bsy && dma_phase && dma_src<14'h6 )
        $display("DMA%0d w src=%x din=%x", dmacnt, dma_src, objtab_din);
    if( dma_bsy && dma_phase && dma_src==14'h3fff ) dmacnt <= dmacnt+1;
end
`endif
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dma_bsy   <= 0;
        dma_phase <= 0;
        dma_src   <= 0;
        snapped   <= 0;
        dma_pend  <= 0;
    end else begin
        if( ln_hs ) lnv_l <= ln_v;
        if( ln_hs && ((ln_v==8'hff && lnv_l!=8'hff) || !snapped) ) dma_pend <= 1;
        if( dma_bsy ) begin
            if( ioctl_ram ) begin // dump hijacked the port, restart the copy
                dma_bsy  <= 0;
                dma_pend <= 1;
            end else begin
                dma_phase <= ~dma_phase;
                if( dma_phase ) begin
                    dma_src <= dma_src==14'h07ff ? 14'h1000 :
                               dma_src==14'h12ff ? 14'h2000 : dma_src + 14'd1;
                    if( dma_src==14'h3fff ) begin
                        dma_bsy <= 0;
                        snapped <= 1;
                    end
                end
            end
        end else if( dma_pend && !ioctl_ram ) begin
            dma_pend  <= 0;
            dma_bsy   <= 1;
            dma_phase <= 0;
            dma_src   <= 0;
        end
    end
end
// first-write-wins support: pixels already written and 8-pixel groups full
// F1: written-pixel mask as 64 group-words in an MLAB (async read, RMW),
// not 512 discrete FFs. gfull stays FFs (needed combinationally by q_cov).
(* ramstyle = "MLAB, no_rw_check" *) reg [7:0] wmaskg[0:63];
reg  [ 63:0] gfull;
reg  [  6:0] clr_cnt;   // 0..64 line-start clear sweep
reg          clr_bsy;
wire         line_full;

// column descriptor FIFO, scan runs ahead of the drawer
(* ramstyle = "MLAB, no_rw_check" *) reg [104:0] fifo[0:7];
reg  [ 3:0] fwp, frp;
wire        fifo_empty = fwp == frp;
wire        desc_full  = fwp[2:0]==frp[2:0] && fwp[3]!=frp[3];
wire [104:0] fifo_rd    = fifo[frp[2:0]];

// staged descriptor: row fetched (or eol) while the previous column draws
reg  [104:0] nxt;
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
wire        nxt_eol   = nxt[104];
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
wire        [ 8:0] wa     = xw + H0;
wire        [ 7:0] wm_word = wmaskg[wa[8:3]];
wire        [ 7:0] wm_new  = wm_word | (8'h1 << wa[2:0]);
wire        [10:0] acc_r  = acc + {1'b0, cur_sr};
wire               acc_c  = acc_r >= {1'b0, cur_tsw};
// clipped span groups of the queued column, precomputed by the scanner
wire        [ 5:0] q_gl  = fifo_rd[97:92];
wire        [ 5:0] q_gh  = fifo_rd[103:98];
wire        [63:0] q_rng;
wire               q_cov = !fwd_pass && !fifo_rd[104] && &(gfull | ~q_rng);
genvar qi;
generate for( qi=0; qi<64; qi=qi+1 ) begin : qrng_gen
    assign q_rng[qi] = qi >= q_gl && qi <= q_gh;
end endgenerate
// promote the staged column into the drawer as soon as its row is in
wire               pro    = !cur_vld && nxt_vld && nxt_rdy && !ln_done && !clr_bsy;
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
        gfull     <= 0;
        clr_bsy   <= 0;
        clr_cnt   <= 0;
    end else begin
        // line-start clear sweep of the mask MLAB (gfull cleared in one cycle)
        if( clr_bsy ) begin
            wmaskg[clr_cnt[5:0]] <= 8'd0;
            clr_cnt <= clr_cnt + 7'd1;
            if( clr_cnt[6] || clr_cnt==7'd63 ) clr_bsy <= 0;
        end
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
                nxt_rdy <= fifo_rd[104]; // eol carries no row
                if( !fifo_rd[104] ) begin
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
                if( xok && pen != 8'hff && (fwd_pass || !wm_word[wa[2:0]]) ) begin
                    ln_we   <= 1;
                    ln_addr <= wa;
                    ln_data <= {cur_pal, pen};
                    wmaskg[wa[8:3]] <= wm_new;
                    if( &wm_new ) gfull[wa[8:3]] <= 1'b1;
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
            clr_bsy   <= 1;
            clr_cnt   <= 0;
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

assign line_full = !fwd_pass && &gfull[43:8]; // window 0x40-0x15f is group aligned

jtc355_scan #(.H0(H0)) u_scan(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .flip       ( flip        ),
    .sprbank    ( sprbank     ),
    .ln_hs      ( scan_hs     ),
    .ln_v       ( ln_v        ),
    .objtab_addr( scan_addr   ),
    .objtab_data( objtab_data ),
    .desc_data  ( desc_data   ),
    .desc_we    ( desc_we     ),
    .desc_full  ( desc_full   ),
    .line_full  ( line_full   ),
    .cov_grp    ( gfull       ),
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
