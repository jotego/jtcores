/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Author: Rafael Eduardo Paiva Feener. Copyright: Jose Tejada Gomez
 * Version: 1.0
 * Date: 17-6-2026 */

// K053251 priority mixer and K054338 colour combiner
// Plane 0 bypasses the K053251 and uses palette bank 0x700

module jtmoo_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

    // Base Video
    input             lhbl,
    input             lvbl,

    // CPU interface
    input             pcu_cs,   // K053251
    input             reg_cs,   // K054338 registers
    input             pal_cs,   // palette RAM
    input             cpu_we,
    input      [15:0] cpu_dout,
    input      [ 1:0] cpu_dsn,
    input      [12:1] cpu_addr,
    output     [15:0] cpu_din,

    // Palette RAM, generated from cfg/mem.yaml
    output     [ 3:0] pal_we,
    output     [12:2] pal_addr,
    output     [31:0] pal_din,
    input      [31:0] pal_dout,
    output     [12:2] palrd_addr,
    input      [31:0] pal_data,

    // Final pixels
    input      [11:0] lyrf_pxl, // plane 0, bypasses the K053251
    input      [11:0] lyra_pxl, // plane 1 -> CI2
    input      [11:0] lyrb_pxl, // plane 2 -> CI3
    input      [11:0] lyrc_pxl, // plane 3 -> CI4
    input      [ 8:0] lyro_pxl,
    input      [ 4:0] lyro_pri,

    input      [ 1:0] shadow,

    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    // Debug
    input      [12:0] ioctl_addr,
    input             ioctl_ram,
    output reg [ 7:0] ioctl_din,
    output     [ 7:0] mmr_dump,

    input      [ 7:0] debug_bus
);

wire [23:0] k338_bg;
wire [15:0] k338_dout;
wire [10:0] col, vid_pal_addr, cpu_pal_addr;
wire [ 8:0] ci0, ci1, ci2;
wire [ 7:0] ci3, ci4, alpha_level, bri1_lvl,
            pal_r, pal_g, pal_b, cpu_r, cpu_g, cpu_b,
            k338g_dump, k251g_dump;
wire [ 5:0] pri0;
wire [ 4:0] k338g_addr;
wire [ 3:0] k251g_addr;
wire [ 1:0] shd_out, shd_a;
wire        pcu_we, reg_we, col_n, k338_video_en, clipsl, alpha_add, pblend0,
            brit, wr_r, wr_g, wr_b, pal_word, p0_opaque, blank_a, bri_a,
            blend_a, k338_dump_sel;
wire signed [9:0] shad_r, shad_g, shad_b;
reg  [23:0] bgr;
reg  [11:0] lyrf_l;
reg  [ 7:0] lyrf_p;
reg  [ 7:0] r8, g8, b8, fr8, fg8, fb8;
reg         fixop_a, ph, ph_l;

// palette is xRGB_888, big endian: even word = R, odd word = {G,B}
assign pal_word     = cpu_addr[1];
assign cpu_pal_addr = cpu_addr[12:2];
assign wr_r         = pal_cs & cpu_we & ~pal_word & ~cpu_dsn[0];
assign wr_g         = pal_cs & cpu_we &  pal_word & ~cpu_dsn[1];
assign wr_b         = pal_cs & cpu_we &  pal_word & ~cpu_dsn[0];
assign pcu_we       = pcu_cs & ~cpu_dsn[0] & cpu_we;
assign reg_we       = reg_cs & cpu_we & (cpu_dsn!=2'b11);
assign cpu_din      = reg_cs   ? k338_dout :
                      pal_word ? { cpu_g, cpu_b } : { 8'd0, cpu_r };
assign {blue,green,red} = (lvbl & lhbl) ? bgr : 24'd0;

// K053251 inputs. CI1 is grounded on this board
assign pri0      = { lyro_pri, 1'b1 };
assign ci0       = lyro_pxl;
assign ci1       = 9'd0;
assign ci2       = lyra_pxl[8:0];
assign ci3       = { lyrb_pxl[7:5], 1'b0, lyrb_pxl[3:0] }; // DSB4 not wired to M9
assign ci4       = lyrc_pxl[7:0];

// MIX0 = COL8 & ~COL9 & ~COL10, MIX1 tied low
assign pblend0    = col[8] & ~col[9] & ~col[10];
// opaque plane 0 wins unless MIX0 selects blending with the K053251 winner
assign p0_opaque  = |lyrf_l[3:0];
// col and col_n leave the K053251 together and the palette read costs less
// than a pixel, so these take no pxl_cen of their own. fixop_a matches them.
assign blank_a    = fixop_a ? 1'b0 : col_n;
assign shd_a      = fixop_a ? 2'b0 : shd_out;
assign bri_a      = fixop_a ? 1'b0 : brit;
assign blend_a    = fixop_a & pblend0;
// plane 0 reads the palette on the odd clock cycles, bank 0x700-0x7FF.
// lyrf_p spends the second pxl_cen the K053251 costs the back colour, so the
// plane-0 colour lands on the same pixel as fixop_a, col and the back colour.
assign vid_pal_addr = ioctl_ram ? ioctl_addr[12:2] :
                    ph        ? {3'b111,lyrf_p}        : col;

// palette RAM port 0 is the CPU, port 1 the video/ioctl read
assign pal_addr   = cpu_pal_addr;
assign pal_we     = { 1'b0, wr_b, wr_g, wr_r };
assign pal_din     = { 8'd0, cpu_dout[7:0], cpu_dout[15:8], cpu_dout[7:0] };
assign palrd_addr = vid_pal_addr;
assign cpu_r      = pal_dout[ 7:0];
assign cpu_g      = pal_dout[15:8];
assign cpu_b      = pal_dout[23:16];
assign pal_r      = pal_data[ 7:0];
assign pal_g      = pal_data[15:8];
assign pal_b      = pal_data[23:16];

// Version 1 dump allocates separate aligned blocks to the two chips.
assign k338_dump_sel = ioctl_ram ? ioctl_addr[5]   : debug_bus[7];
assign k338g_addr    = ioctl_ram ? ioctl_addr[4:0] : debug_bus[4:0];
assign k251g_addr    = ioctl_ram ? ioctl_addr[3:0] : debug_bus[3:0];
assign mmr_dump      = k338_dump_sel ? k338g_dump :
                      k251g_addr < 4'd13 ? k251g_dump : 8'd0;

// CLIPSL disables the clamp, the sum wraps instead
function [7:0] add_clip(input [7:0] cin, input signed [9:0] delta, input noclip);
    reg signed [10:0] sum;
begin
    // $signed keeps the addition signed so a negative delta is sign-extended
    sum = $signed({3'd0,cin}) + delta;
    add_clip = noclip          ? sum[7:0] :
               sum < 0         ? 8'd0  :
               sum > 11'sd255  ? 8'hff : sum[7:0];
end
endfunction

// mode 0: (front*level + back*(256-level))>>8
// mode 1: front + (back*(32-mixlv))>>5, mixlv is the top 5 bits of level
function [7:0] mix_blend(input [7:0] front, input [7:0] back, input [7:0] level, input additive);
    reg [ 8:0] inv9, asum;
    reg [ 5:0] inv5;
    reg [17:0] sum;
    reg [13:0] aprod;
begin
    inv9  = 9'd256 - {1'b0,level};
    inv5  = 6'd32 - {1'b0,level[7:3]};
    sum   = front*level + back*inv9; // <= 65280, no clamp needed
    aprod = back * inv5;
    asum  = {1'b0,front} + aprod[13:5];
    mix_blend = !additive ? sum[15:8] : asum[8] ? 8'hff : asum[7:0];
end
endfunction

// BRI1 is tied, so only brightness code 1 is selected
function [23:0] apply_bright(input [23:0] rgb, input en, input [7:0] lvl);
    reg [15:0] pb, pg, pr;
begin
    pb = 16'd0;
    pg = 16'd0;
    pr = 16'd0;
    if( en ) begin
        pb = rgb[23:16] * lvl;
        pg = rgb[15: 8] * lvl;
        pr = rgb[ 7: 0] * lvl;
        apply_bright = { pb[15:8], pg[15:8], pr[15:8] };
    end else apply_bright = rgb;
end
endfunction

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bgr     <= 0;
        fixop_a <= 0;
        lyrf_l  <= 0;
        lyrf_p  <= 0;
        {r8,g8,b8}    <= 0;
        {fr8,fg8,fb8} <= 0;
        ph      <= 0;
        ph_l    <= 0;
    end else begin
        ph   <= ~ph & ~pxl_cen;
        ph_l <= ph;
        if( ph_l )
            { fr8, fg8, fb8 } <= { pal_r, pal_g, pal_b };
        else
            { r8,  g8,  b8  } <= { pal_r, pal_g, pal_b };
        if( pxl_cen ) begin
            lyrf_l  <= lyrf_pxl;
            lyrf_p  <= lyrf_l[7:0];
            fixop_a <= p0_opaque;
            bgr     <= apply_bright( !k338_video_en   ? 24'd0 :
                       blank_a          ? {k338_bg[7:0],k338_bg[15:8],k338_bg[23:16]} :
                       fixop_a & ~blend_a ? { fb8, fg8, fr8 } :
                       fixop_a &  blend_a ? { mix_blend(fb8,b8,alpha_level,alpha_add),
                                               mix_blend(fg8,g8,alpha_level,alpha_add),
                                               mix_blend(fr8,r8,alpha_level,alpha_add) } :
                       ~|shd_a          ? { b8, g8, r8 } :
                                        { add_clip(b8,shad_b,clipsl),
                                          add_clip(g8,shad_g,clipsl),
                                          add_clip(r8,shad_r,clipsl) },
                       bri_a, bri1_lvl );
        end
    end
end

// palette dump: four bytes per entry, x/R/G/B
always @(posedge clk) begin
    case( ioctl_addr[1:0] )
        2'd0: ioctl_din <= 8'd0;
        2'd1: ioctl_din <= pal_r;
        2'd2: ioctl_din <= pal_g;
        default: ioctl_din <= pal_b;
    endcase
end

jt054338 u_k338(
    .rst         ( rst             ),
    .clk         ( clk             ),

    .cs          ( reg_cs          ),
    .we          ( reg_we          ),
    .addr        ( cpu_addr[4:1]   ),
    .din         ( cpu_dout        ),
    .dsn         ( cpu_dsn         ),
    .dout        ( k338_dout       ),

    .pblend      ( { 1'b0, pblend0 } ),
    .shadow      ( shd_a           ),

    .bg_rgb      ( k338_bg         ),
    .alpha_level ( alpha_level     ),
    .alpha_add   ( alpha_add       ),
    .video_en    ( k338_video_en   ),
    // pin input-delay selects, not needed
    .mixpri      (                 ),
    .shdpri      (                 ),
    .brtpri      (                 ),
    .clipsl      ( clipsl          ),
    .dump_addr   ( k338g_addr      ),
    .dump_mmr    ( k338g_dump      ),
    .bri1_lvl    ( bri1_lvl        ),

    .shadow_r    ( shad_r          ),
    .shadow_g    ( shad_g          ),
    .shadow_b    ( shad_b          )
);

jtcolmix_053251 u_k251(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    // CPU interface
    .cs         ( pcu_we    ),
    .addr       (cpu_addr[4:1]),
    .din        (cpu_dout[5:0]),
    // explicit priorities
    .sel        ( 1'b0      ),
    .pri0       ( pri0      ),
    .pri1       ( 6'h0      ),
    .pri2       ( 6'h0      ),
    // color inputs
    .ci0        ( ci0       ),
    .ci1        ( ci1       ),
    .ci2        ( ci2       ),
    .ci3        ( ci3       ),
    .ci4        ( ci4       ),
    // shadow
    .shd_in     ( shadow    ),
    .shd_out    ( shd_out   ),
    .ioctl_addr ( k251g_addr ),
    .ioctl_din  ( k251g_dump ),

    .cout       ( col       ),
    .brit       ( brit      ),
    .col_n      ( col_n     )
);

`ifdef SIMULATION
wire unused_colmix = &{ 1'b0, lyrb_pxl[4], lyrf_l[11:8],
                        lyra_pxl[11:9], lyrb_pxl[11:8], lyrc_pxl[11:8] };
`endif

endmodule
