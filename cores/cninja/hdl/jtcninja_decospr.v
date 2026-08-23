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

// ---------- parse: scan the 256 sprites, find those on this line ----------
reg  [ 8:0] xpos;
reg  [15:0] id;                 // full 16-bit sprite code
reg  [ 4:0] pal;
reg  [ 1:0] pri;            // x[15:14] : sprite/playfield priority
reg         epri;           // y[15]    : extra priority bit (cbuster front/back)
reg  [ 1:0] vsize;          // 0..3 -> 1/2/4/8 tiles tall
reg         hflip, vflip;
reg         wide, flash_r;  // y[11]=2nd 16px column (wing); y[12]=flash/blink
reg  [ 8:0] veff;           // row within the sprite (0..16*tiles-1)
reg         frame, parse_busy, draw, HSl, LVl, draw_busy, rom_good;
reg  [ 5:0] line_cnt;

wire [ 8:0] ypos   = 9'd256 - oram_dout[8:0];     // bottom (exclusive)
reg  [ 8:0] vrf, top;
reg         inzone;

// vertical zone test (word0 in oram_dout while tbl_addr[1:0]==0)
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

reg cen2;     // half-rate: give the sprite RAM 1 cycle to return oram_dout
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        oram_addr<=0; parse_busy<=0; draw<=0; frame<=0; vsize<=0;
        hflip<=0; vflip<=0; id<=0; pal<=0; pri<=0; epri<=0; xpos<=0; veff<=0; cen2<=0;
    end else begin
        HSl <= HS; LVl <= LVBL; draw <= 0; cen2 <= ~cen2;
        if( !LVBL && LVl ) frame <= ~frame;
        // Sprite-vs-sprite priority is HIGH-slot-on-top: scan LOW->HIGH (0..255)
        // so the highest slot is drawn last and ends on top.
        if( HSl && !HS ) begin oram_addr <= 10'd0; parse_busy <= 1; cen2 <= 0; end
        if( parse_busy && !draw_busy && cen2 ) begin
            case( oram_addr[1:0] )
                0: begin     // word0 (y) : size/flip + zone test
                    { vflip, hflip } <= oram_dout[14:13];
                    epri    <= oram_dout[15];           // extra-pri (cbuster front/back)
                    vsize   <= oram_dout[10:9];
                    wide    <= oram_dout[11];
                    flash_r <= oram_dout[12];
                    veff  <= vrf - top;
                    if( !inzone ) begin
                        if( oram_addr[9:2]==8'd255 ) parse_busy <= 0;     // last slot done
                        else oram_addr <= {oram_addr[9:2]+8'd1, 2'd0};    // next sprite
                    end else
                        oram_addr <= oram_addr + 10'd1;
                end
                1: begin id <= oram_dout[15:0]; oram_addr <= oram_addr + 10'd1; end
                2: begin     // word2 (x) : xpos/colour/priority
                    xpos     <= 9'd240 - oram_dout[8:0];
                    pal      <= oram_dout[13:9];
                    pri      <= oram_dout[15:14];
                    draw     <= ~flash_r | frame;              // flash: blink on alt frames
                    if( oram_addr[9:2]==8'd255 ) parse_busy <= 0;      // last slot done
                    else oram_addr <= {oram_addr[9:2]+8'd1, 2'd0};     // next sprite
                end
                default:;
            endcase
            if( line_cnt >= 6'd58 ) parse_busy <= 0;           // per-line budget
        end
    end
end

// ---------- draw: fetch the sprite tile ROM, shift pixels to the buffer ----------
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

reg  [31:0] draw_data;
reg  [ 3:0] draw_cnt;
reg         half;
reg         col;         // 0=base column @xpos, 1=wing column @xpos-16
reg  [ 3:0] mult2;       // multi+1 = 1<<vsize : wing tile = base_row_tile - mult2
reg  [ 8:0] buf_waddr;
reg         buf_we;
reg         fresh;       // rom_ok deasserted since this fetch was issued
// plane decode: {p3,p2,p1,p0} (MSB-first / hflip LSB-first); pswap exchanges the
// two plane-pairs for darkseal's seallayout.
wire [ 3:0] dp = hflip ? { draw_data[24], draw_data[16], draw_data[8], draw_data[0] } :
                         { draw_data[31], draw_data[23], draw_data[15], draw_data[7] };
// darkseal's seallayout needs the plane half-swap (pswap). cninja AND cbuster
// both use MAME's `tilelayout` (same planeoffset), so they take dp straight -
// verified: cbuster sprite render matches MAME screen.png at 98% with dp, vs
// 21-29% for any swap.
wire [ 3:0] draw_pxl  = pswap ? { dp[1:0], dp[3:2] } : dp;
wire [11:0] buf_wdata = { epri, pri, pal, draw_pxl };
wire [ 8:0] buf_waflip= !flip ? buf_waddr : 9'h100 - buf_waddr;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        draw_busy<=0; draw_cnt<=0; buf_waddr<=0; rom_good<=0; buf_we<=0;
        rom_cs<=0; half<=0; col<=0; mult2<=0; line_cnt<=0; draw_data<=0;
        rom_addr<=0; fresh<=0;
    end else begin
        rom_good <= rom_ok;
        if( rom_cs && !rom_ok ) fresh <= 1;   // saw rom_ok low -> new read in flight
        if( !parse_busy ) line_cnt <= 0;
        if( draw ) begin
            draw_busy <= 1; half <= 1; col <= 0;                 // base column first
            mult2     <= 4'd1 << vsize;
            // initial ROM half = ~hflip: non-flip draws cols0-7 (half=1) first,
            // hflip draws cols8-15 (half=0) first, each mirrored via draw_pxl.
            rom_addr  <= { id_eff, ~hflip, veff[3:0]^{4{vflip}} };// {tile,half,row}
            draw_cnt  <= 0; rom_cs <= 1; rom_good <= 0; fresh <= 0;
            buf_waddr <= xpos;
        end
        if( !buf_we && rom_cs && fresh && rom_good && rom_ok && draw_cnt==0 ) begin
            draw_data <= rom_data; buf_we <= 1; draw_cnt <= 7;
            // PREFETCH the 2nd half as soon as the 1st is captured (overlap SDRAM
            // latency with the 8px shift). 2nd half captured -> no further fetch.
            if( half ) begin rom_addr[6] <= ~rom_addr[6]; rom_good <= 0; fresh <= 0; end
            else       rom_cs <= 0;
        end
        if( buf_we ) begin
            draw_data <= hflip ? draw_data>>1 : draw_data<<1;
            draw_cnt  <= draw_cnt - 1'd1;
            buf_waddr <= buf_waddr + 9'd1;
            if( draw_cnt==0 ) begin
                buf_we <= 0;
                if( half ) begin                                 // 1st half shifted; 2nd
                    half <= 0; draw_cnt <= 0;                    // half already fetching
                end else if( wide && !col ) begin                // -> wing column @xpos-16
                    col <= 1; half <= 1; line_cnt <= line_cnt + 1'd1;
                    rom_addr <= { id_eff-{12'd0,mult2}, ~hflip, veff[3:0]^{4{vflip}} };
                    buf_waddr<= xpos - 9'd16;
                    rom_cs <= 1; rom_good <= 0; fresh <= 0; draw_cnt <= 0;
                end else begin                                   // sprite done
                    draw_busy <= 0; rom_cs <= 0; line_cnt <= line_cnt + 1'd1;
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
