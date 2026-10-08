/* SPDX-FileCopyrightText: 2026 Marc Emmerson / Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Sprite scan. The object RAM is copied into objbuf during vertical blanking,
 * one word every fourth pixel. Each line, the copy is scanned from entry 0
 * up to 511 reading only the y word, and the sprites on the line are handed
 * to jtframe_objdraw, so entry 511 is drawn last and ends on top.
 *
 * Entry words: 0 code; 1 attr = colour[5:0], flipx bit 8, flipy bit 9,
 * prio[11:10]; 2 x<<7; 3 y<<7. y == 0x100 hides a sprite, prio 0 skips it.
 */
module jtwardnr_obj(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             hs,
    input             LVBL,
    input      [ 8:0] hdump,
    input      [ 8:0] vrender,

    output     [11:1] ram_addr,
    input      [15:0] ram_dout,

    output     [11:1] cpy_addr,
    output     [ 1:0] cpy_we,

    output     [11:1] scan_addr,
    input      [15:0] scan_dout,

    output     [15:0] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,

    output     [11:0] pxl
);

localparam SCAN=0, DRAIN=1, FETCH0=2, FETCH1=3, FETCH2=4, FETCH3=5,
           FETCH4=6, DRAW=7, NEXT=8;

reg  [10:0] rd_cnt, wr_cnt, scan_cnt;
reg  [ 1:0] cdiv;
reg         copying, LVBL_l, hs_l, busy, draw, v1, v2, we;
reg  [ 3:0] st;
reg  [ 9:0] entry;
reg  [ 8:0] hit_e, e1, e2, ly;
reg  [15:0] w_code, w_attr, w_x, w_y;
wire        dr_busy;
wire [17:2] dr_rom;
wire [31:0] rom_rev;
wire [ 8:0] sy, sx, ydiff, q_sy, q_diff, xpos;
wire [ 1:0] prio;
wire        flipx, flipy, yhit;

assign ram_addr  = rd_cnt;
assign cpy_addr  = wr_cnt;
assign cpy_we    = {2{we}};
assign scan_addr = scan_cnt;
assign sy        = w_y[15:7];
assign sx        = w_x[15:7];
assign flipx     = w_attr[8];
assign flipy     = w_attr[9];
assign prio      = w_attr[11:10];
assign ydiff     = ly - (sy - 9'd16);
assign q_sy      = scan_dout[15:7];
assign q_diff    = ly - (q_sy - 9'd16);
assign yhit      = q_sy != 9'h100 && q_diff < 9'd16;
assign xpos      = sx - 9'd32 - (flipx ? 9'd14 : 9'd0);
// jtframe_objdraw addresses {code, H, VVVV}; the ROM is {code, VVVV, H}
assign rom_addr  = { dr_rom[17:7], dr_rom[5:2], dr_rom[6] };

// the ROM word has the leftmost pixel in each byte's MSB and plane 0 in the
// top byte, jtframe_draw the other way round in both
genvar k;
generate for( k=0; k<32; k=k+1 ) begin : rev
    assign rom_rev[k] = rom_data[31-k];
end endgenerate

always @(posedge clk) begin
    LVBL_l <= LVBL;
    we     <= 0;
    if( rst ) begin
        copying <= 0;
        rd_cnt  <= 0;
        cdiv    <= 0;
    end else if( LVBL_l && !LVBL ) begin
        copying <= 1;
        rd_cnt  <= 0;
        cdiv    <= 0;
    end else if( copying && pxl_cen ) begin
        cdiv <= cdiv + 2'd1;
        if( cdiv == 2'd3 ) begin
            we     <= 1;
            wr_cnt <= rd_cnt;
            rd_cnt <= rd_cnt + 11'd1;
            if( &rd_cnt ) copying <= 0;
        end
    end
end

always @(posedge clk) begin
    hs_l <= hs;
    draw <= 0;
    if( rst ) begin
        st       <= SCAN;
        entry    <= 0;
        busy     <= 0;
        scan_cnt <= 0;
        ly       <= 0;
        w_code   <= 0;
        w_attr   <= 0;
        w_x      <= 0;
        w_y      <= 0;
        hit_e    <= 0;
        e1       <= 0;
        e2       <= 0;
        v1       <= 0;
        v2       <= 0;
    end else if( hs && !hs_l ) begin
        ly    <= vrender;
        entry <= 0;
        v1    <= 0;
        v2    <= 0;
        busy  <= vrender < 9'd240;
        st    <= SCAN;
    end else if( busy ) begin
        v2 <= v1;
        e2 <= e1;
        case( st )
            SCAN: begin
                scan_cnt <= { entry[8:0], 2'd3 };
                v1       <= 1;
                e1       <= entry[8:0];
                entry    <= entry + 10'd1;
                if( entry == 10'd511 ) st <= DRAIN;
                if( v2 && yhit ) begin
                    w_y   <= scan_dout;
                    hit_e <= e2;
                    v1    <= 0;
                    v2    <= 0;
                    st    <= FETCH0;
                end
            end
            DRAIN: begin
                v1 <= 0;
                if( v2 && yhit ) begin
                    w_y   <= scan_dout;
                    hit_e <= e2;
                    v2    <= 0;
                    st    <= FETCH0;
                end else if( !v1 ) begin
                    busy <= 0;
                end
            end
            FETCH0: begin
                scan_cnt <= { hit_e, 2'd1 };
                st       <= FETCH1;
            end
            FETCH1: begin
                scan_cnt <= { hit_e, 2'd0 };
                st       <= FETCH2;
            end
            FETCH2: begin
                scan_cnt <= { hit_e, 2'd2 };
                w_attr   <= scan_dout;
                st       <= FETCH3;
            end
            FETCH3: begin
                w_code <= scan_dout;
                st     <= prio == 2'd0 ? NEXT : FETCH4;
            end
            FETCH4: begin
                w_x <= scan_dout;
                st  <= DRAW;
            end
            DRAW: if( !dr_busy ) begin
                draw <= 1;
                st   <= NEXT;
            end
            NEXT: begin
                if( hit_e == 9'd511 ) busy <= 0;
                entry <= { 1'b0, hit_e } + 10'd1;
                st    <= SCAN;
            end
            default: st <= SCAN;
        endcase
    end
end

jtframe_objdraw #(
    .CW         ( 11                    ),
    .PW         ( 12                    ),
    .HFIX       ( 0                     ),
    .LATCH      ( 1                     )
) u_draw(
    .rst        ( rst                   ),
    .clk        ( clk                   ),
    .pxl_cen    ( pxl_cen               ),
    .hs         ( hs                    ),
    .flip       ( 1'b0                  ),
    .hdump      ( hdump                 ),
    .draw       ( draw                  ),
    .busy       ( dr_busy               ),
    .code       ( w_code[10:0]          ),
    .xpos       ( xpos                  ),
    .ysub       ( ydiff[3:0]            ),
    .hzoom      ( 6'd0                  ),
    .hz_keep    ( 1'b0                  ),
    .hflip      ( flipx                 ),
    .vflip      ( flipy                 ),
    .pal        ( { prio, w_attr[5:0] } ),
    .rom_addr   ( dr_rom                ),
    .rom_cs     ( rom_cs                ),
    .rom_ok     ( rom_ok                ),
    .rom_data   ( rom_rev               ),
    .pxl        ( pxl                   )
);

endmodule
