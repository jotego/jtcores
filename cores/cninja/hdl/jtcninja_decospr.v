/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    jtcninja_decospr - Data East DECO sprite generator (decospr / MXC-06 family,
    4bpp). MAME ref: decospr.cpp (mirrored in cores/cninja/doc).

    Sprite RAM entry (4 words, MXC-06 layout):
      word0 (y) : [8:0]ypos [10:9]vsize(1/2/4/8) [11]wide [12]flash
                  [13]hflip [14]vflip [15]extra-pri
      word1     : tile code (masked &~(vsize-1) for multi-tile)
      word2 (x) : [8:0]xpos [13:9]colour(5b) [15:14]priority
    Placement: bottom = 256-ypos, top = bottom-16*vtiles ; x = 240-xpos.
    Scanned LOW->HIGH so the highest slot ends on top (last-opaque-wins buffer).

    The only per-game gfx difference between the cninja and darkseal sprites is
    the gfx_layout planeoffset order (cninja tilelayout {FRAC+8,FRAC,8,0} vs
    darkseal seallayout {8,0,FRAC+8,FRAC}) - the two 4bpp plane-pairs are swapped.
    `pswap` exchanges them (same parameter as jtcninja_deco16). Everything else
    (word format, colour bits, x/y placement) is common.

    Pen out = {pri[1:0], colour[4:0], pixel[3:0]} ; pixel0 = transparent.

    Timing. A line is 376 px x 8 clk = 3008 clocks at 48 MHz (see the vtimer in
    jtcninja_video). The scan issues one sprite-RAM word per clock - a flat 3
    clocks per slot - so the whole 256-entry table is walked in 768, and it runs
    CONCURRENTLY with the gfx fetch: candidates queue in a small FIFO. The whole
    table is always covered, matching MAME's decospr, which has no per-line cap.
*/
module jtcninja_decospr(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             flip,            // screen flip
    input             pswap,           // gfx plane half-swap  (darkseal seallayout only)

    input             HS,
    input             LHBL,
    input             LVBL,
    input      [ 8:0] vrender,
    input      [ 8:0] hdump,

    // sprite RAM read port (256 slots x 4 words = 10-bit word address)
    output reg [ 9:0] oram_addr,
    input      [15:0] oram_dout,

    // sprite ROM
    output reg        rom_cs,
    output reg [22:2] rom_addr,     // 16-bit code -> up to 5MB (edrandy)
    input      [31:0] rom_data,
    input             rom_ok,

    output     [11:0] pxl          // {epri, pri[1:0], colour[4:0], pixel[3:0]}; pixel0 = transparent
);

// Candidate record handed from the scan to the drawer
localparam RECW = 41;   // xpos9 + tile16 + row4 + hflip1 + pal5 + pri2 + epri1 + wide1 + vsize2
localparam FW   = 3;    // FIFO depth = 8 candidates

// ---------- parse: scan the 256 sprites, find those on this line ----------
// Two-stage pipeline: the word issued at edge T is read back at edge T+2
// (jtframe_dual_ram registers the read), so the word index and slot number ride
// a matching 2-stage delay. Words 0,1,2 of a slot go out back to back whether
// the slot lands on this line or not - a flat 3 clocks per slot.
reg  [ 9:0] scan_addr;              // {slot[7:0], word[1:0]}
reg  [ 1:0] wsel1, wsel2;
reg         iss1, iss2;             // issue valid, delayed alongside
reg         issuing, HSl, LVl, frame;

reg  [ 1:0] vsize;                  // 0..3 -> 1/2/4/8 tiles tall
reg         hflip, vflip, wide_r, flash_r, epri_r, hit;
reg  [ 8:0] veff;                   // row within the sprite (0..16*tiles-1)
reg  [15:0] id;                     // full 16-bit sprite code

wire        hs_neg    = HSl & ~HS;
wire        last_word = scan_addr==10'd1022;      // slot 255, word 2

wire [ 8:0] ypos = 9'd256 - oram_dout[8:0];     // bottom (exclusive)
reg  [ 8:0] vrf, top;
reg         inzone;

// vertical zone test (word0 in oram_dout while wsel2==0)
always @* begin
    vrf  = flip ? 9'd255-vrender : vrender;
    case( oram_dout[10:9] )
        0: top = ypos - 9'h10;
        1: top = ypos - 9'h20;
        2: top = ypos - 9'h40;
        3: top = ypos - 9'h80;
    endcase
    inzone = !( (vrf < top && !top[8]) || vrf >= ypos || ypos < 8 || (top[8] && ypos[8]) );
end

// effective 16x16 tile id for this scanline's row within a multi-tile sprite
reg  [15:0] id_eff;
always @* begin
    id_eff = id;
    case( vsize )
        1: id_eff = { id[15:1],     vflip^veff[4]    };
        2: id_eff = { id[15:2], {2{vflip}}^veff[5:4] };
        3: id_eff = { id[15:3], {3{vflip}}^veff[6:4] };
        default:;
    endcase
end

// word2 fields, combinational (only sampled while wsel2==2)
wire [ 8:0] xpos_w = 9'd240 - oram_dout[8:0];
wire [ 4:0] pal_w  = oram_dout[13:9];
wire [ 1:0] pri_w  = oram_dout[15:14];

// ---------- candidate FIFO: decouples the scan from the gfx fetch ----------
reg  [RECW-1:0] fifo[0:(1<<FW)-1];
reg  [FW:0]     wptr, rptr;         // MSB is the wrap flag
reg             draw_busy;
wire            fifo_empty = wptr==rptr;
wire            fifo_full  = wptr[FW-1:0]==rptr[FW-1:0] && wptr[FW]!=rptr[FW];
wire [RECW-1:0] fifo_out   = fifo[rptr[FW-1:0]];
wire [RECW-1:0] rec_in     = { xpos_w, id_eff, veff[3:0]^{4{vflip}}, hflip,
                               pal_w, pri_w, epri_r, wide_r, vsize };
wire            push       = iss2 & ~hs_neg & wsel2==2'd2 & hit & (~flash_r | frame);
wire            pop        = ~fifo_empty & ~draw_busy;
// A full FIFO stalls the issue: the address holds and a bubble goes into the
// delay pipe, so the words already in flight still land in step.
wire            stall      = fifo_full;
// record fields, unpacked
wire [ 8:0] f_xpos  = fifo_out[40:32];
wire [15:0] f_tile  = fifo_out[31:16];
wire [ 3:0] f_row   = fifo_out[15:12];
wire        f_hflip = fifo_out[11];
wire [ 1:0] f_vsize = fifo_out[ 1: 0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        oram_addr<=0; scan_addr<=0; issuing<=0; frame<=0; vsize<=0;
        hflip<=0; vflip<=0; id<=0; epri_r<=0; veff<=0; hit<=0;
        wide_r<=0; flash_r<=0; wsel1<=0; wsel2<=0;
        iss1<=0; iss2<=0; wptr<=0;
    end else begin
        HSl <= HS; LVl <= LVBL;
        if( !LVBL && LVl ) frame <= ~frame;
        // Sprite-vs-sprite priority is HIGH-slot-on-top: scan LOW->HIGH (0..255)
        // so the highest slot is drawn last and ends on top.
        if( hs_neg ) begin
            scan_addr <= 10'd0; issuing <= 1;
            wptr <= 0; iss1 <= 0; iss2 <= 0;
        end else begin
            if( issuing && !stall ) begin
                oram_addr <= scan_addr;
                scan_addr <= scan_addr[1:0]==2'd2 ? { scan_addr[9:2]+8'd1, 2'd0 }
                                                  : scan_addr + 10'd1;
                if( last_word ) issuing <= 0;
            end
            wsel1 <= scan_addr[1:0]; iss1 <= issuing & ~stall;
            wsel2 <= wsel1;          iss2 <= iss1;
            // consume: the word issued two edges ago is on oram_dout now
            if( iss2 ) case( wsel2 )
                0: begin
                    { vflip, hflip } <= oram_dout[14:13];
                    epri_r  <= oram_dout[15];       // extra-pri (cbuster front/back)
                    vsize   <= oram_dout[10:9];
                    wide_r  <= oram_dout[11];
                    flash_r <= oram_dout[12];       // flash: blink on alternate frames
                    veff    <= vrf - top;
                    hit     <= inzone;
                end
                1: id <= oram_dout;
                default:;
            endcase
            if( push ) begin
                fifo[wptr[FW-1:0]] <= rec_in;
                wptr <= wptr + 1'd1;
            end
        end
    end
end

// ---------- draw: fetch the sprite tile ROM, shift pixels to the buffer ----------
reg  [15:0] d_tile;
reg  [ 8:0] d_xpos;
reg  [ 4:0] d_pal;
reg  [ 3:0] d_row, mult2;   // mult2 = 1<<vsize : wing tile = base_row_tile - mult2
reg  [ 1:0] d_pri;
reg         d_hflip, d_epri, d_wide;

reg  [31:0] draw_data;
reg  [ 3:0] draw_cnt;
reg         half;
reg         col;         // 0=base column @xpos, 1=wing column @xpos-16
reg  [ 8:0] buf_waddr;
reg         buf_we, rom_good;
reg         fresh;       // rom_ok deasserted since this fetch was issued
// plane decode: {p3,p2,p1,p0} (MSB-first / hflip LSB-first); pswap exchanges the
// two plane-pairs for darkseal's seallayout.
wire [ 3:0] dp = d_hflip ? { draw_data[24], draw_data[16], draw_data[8], draw_data[0] } :
                           { draw_data[31], draw_data[23], draw_data[15], draw_data[7] };
// darkseal's seallayout needs the plane half-swap (pswap). cninja AND cbuster
// both use MAME's `tilelayout` (same planeoffset), so they take dp straight -
// verified: cbuster sprite render matches MAME screen.png at 98% with dp, vs
// 21-29% for any swap.
wire [ 3:0] draw_pxl  = pswap ? { dp[1:0], dp[3:2] } : dp;
wire [11:0] buf_wdata = { d_epri, d_pri, d_pal, draw_pxl };
wire [ 8:0] buf_waflip= !flip ? buf_waddr : 9'h100 - buf_waddr;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        draw_busy<=0; draw_cnt<=0; buf_waddr<=0; rom_good<=0; buf_we<=0;
        rom_cs<=0; half<=0; col<=0; mult2<=0; draw_data<=0;
        rom_addr<=0; fresh<=0; rptr<=0;
        d_tile<=0; d_xpos<=0; d_pal<=0; d_row<=0; d_pri<=0;
        d_hflip<=0; d_epri<=0; d_wide<=0;
    end else begin
        rom_good <= rom_ok;
        if( rom_cs && !rom_ok ) fresh <= 1;   // saw rom_ok low -> new read in flight
        if( hs_neg ) rptr <= 0;
        if( pop ) begin
            d_xpos <= f_xpos; d_tile <= f_tile; d_row  <= f_row; d_hflip <= f_hflip;
            d_pal  <= fifo_out[10:6]; d_pri <= fifo_out[5:4];
            d_epri <= fifo_out[3];    d_wide<= fifo_out[2];
            rptr      <= rptr + 1'd1;
            draw_busy <= 1; half <= 1; col <= 0;                 // base column first
            mult2     <= 4'd1 << f_vsize;
            // initial ROM half = ~hflip: non-flip draws cols0-7 (half=1) first,
            // hflip draws cols8-15 (half=0) first, each mirrored via draw_pxl.
            rom_addr  <= { f_tile, ~f_hflip, f_row };            // {tile,half,row}
            draw_cnt  <= 0; rom_cs <= 1; rom_good <= 0; fresh <= 0;
            buf_waddr <= f_xpos;
        end
        if( !buf_we && rom_cs && fresh && rom_good && rom_ok && draw_cnt==0 ) begin
            draw_data <= rom_data; buf_we <= 1; draw_cnt <= 7;
            // PREFETCH the 2nd half as soon as the 1st is captured (overlap SDRAM
            // latency with the 8px shift). 2nd half captured -> no further fetch.
            if( half ) begin rom_addr[6] <= ~rom_addr[6]; rom_good <= 0; fresh <= 0; end
            else       rom_cs <= 0;
        end
        if( buf_we ) begin
            draw_data <= d_hflip ? draw_data>>1 : draw_data<<1;
            draw_cnt  <= draw_cnt - 1'd1;
            buf_waddr <= buf_waddr + 9'd1;
            if( draw_cnt==0 ) begin
                buf_we <= 0;
                if( half ) begin                                 // 1st half shifted; 2nd
                    half <= 0; draw_cnt <= 0;                    // half already fetching
                end else if( d_wide && !col ) begin              // -> wing column @xpos-16
                    col <= 1; half <= 1;
                    rom_addr <= { d_tile-{12'd0,mult2}, ~d_hflip, d_row };
                    buf_waddr<= d_xpos - 9'd16;
                    rom_cs <= 1; rom_good <= 0; fresh <= 0; draw_cnt <= 0;
                end else begin                                   // sprite done
                    draw_busy <= 0; rom_cs <= 0;
                end
            end
        end
    end
end

jtframe_obj_buffer #(.DW(12), .ALPHA(12'd0)) u_buffer(
    .clk     ( clk        ),
    .LHBL    ( LHBL       ),
    .flip    ( 1'b0       ),
    .wr_data ( buf_wdata  ),
    .wr_addr ( buf_waflip ),
    .we      ( buf_we     ),
    .rd_addr ( hdump      ),
    .rd      ( pxl_cen    ),
    .rd_data ( pxl        )
);

endmodule
