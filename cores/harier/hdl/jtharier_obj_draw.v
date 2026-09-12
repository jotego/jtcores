/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-8-2026 */

/*  Sprite row renderer for the Space Harrier custom (315-5011/5012).

    ATTRIBUTION -- the draw algorithm is derived from MAME
    `sega_sharrier_sprite_device::draw` in sega16sp.cpp (Aaron Giles,
    BSD-3-Clause). BSD-3 requires the notice to be retained in redistributions,
    so this is a licence condition, not a note.

    Horizontal zoom is shrink-only, sega16sp.cpp:398:
        xacc = (xacc & 0xff) + hzoom;  if(xacc < 0x100){ draw; screen x++ }
    The source pixel always advances; the screen pixel only when xacc did not
    carry. Flip reads words and nibbles in reverse (sega16sp.cpp:420).

    The row ends when the last pixel DRAWN in a word is 0xF. pix 0 and 0xF are
    both transparent; 0xF also stops the row.

    obj_pxl = { prio[1:0], pal[5:0], pix[3:0] }; Space Harrier prio = { bit14, 1'b1 }.
    pal==6'h3f is shadow (segahang.cpp:282). obj_data[31:28] is the first
    non-flipped pixel -- the endianness jtframe's 32-bit obj read gives.

    Hang-On: 4-pixel 16-bit words; each 32-bit read holds two, byte-swapped:
    even {[7:0],[15:8]}, odd {[23:16],[31:24]}.
*/

module jtharier_obj_draw(
    input              rst,
    input              clk,
    input              hstart,
    input              hangon,

    input              start,
    output reg         busy,
    input      [ 8:0]  xpos,
    input      [15:0]  offset,    // [15] = hflip, [14:0] = word offset within bank
    input      [ 2:0]  bank,
    input      [ 1:0]  prio,
    input      [ 5:0]  pal,
    input              shadow,
    input      [ 6:0]  hzoom,     // MAME value: (field & 0x3f) << 1

    // Sprite ROM (1 MB, 32-bit reads; Hang-On takes 16-bit words from them)
    input              obj_ok,
    output reg         obj_cs,
    output     [19:2]  obj_addr,
    input      [31:0]  obj_data,

    output     [11:0]  bf_data,
    output             bf_we,
    output reg [ 8:0]  bf_addr
);

localparam [1:0] IDLE=2'd0, FETCH=2'd1, DRAW=2'd2;

reg  [ 1:0] st;
reg  [ 2:0] k;             // nibble index within the current word
reg  [31:0] pxl_data;
reg  [14:0] cur;           // 15-bit word address within the bank (wraps at 0x7fff)
reg  [ 7:0] xacc;
reg         hflip, last_word, fetch_dly;

wire [ 3:0] cur_pxl;
wire [ 8:0] xsum;
wire        emit, line_end, word_end;
wire [15:0] w16 = cur[0] ? { obj_data[23:16], obj_data[31:24] } :
                           { obj_data[ 7: 0], obj_data[15: 8] };

assign cur_pxl  = hflip ? pxl_data[3:0] : pxl_data[31-:4];
assign obj_addr = hangon ? { 1'b0, bank, cur[14:1] } : { bank, cur };
assign word_end = hangon ? k[1:0]==2'd3 : &k;
assign xsum     = { 1'b0, xacc } + { 2'b0, hzoom };
assign emit     = ~xsum[8];
// Must stop at the buffer end: bf_addr wraps otherwise and corrupts the line.
assign line_end = st==DRAW && emit && bf_addr==9'h1ff;

assign bf_we   = st==DRAW && emit && cur_pxl!=4'h0 && cur_pxl!=4'hf;
// per-pixel shadow: shadow-enabled AND pix==0xA (segahang.cpp:282, (pix&0x80f)==0x00a)
assign bf_data = { prio, (shadow && cur_pxl==4'ha) ? 6'h3f : pal, cur_pxl };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st        <= IDLE;
        busy      <= 0;
        obj_cs    <= 0;
        cur       <= 0;
        bf_addr   <= 0;
        pxl_data  <= 0;
        xacc      <= 0;
        k         <= 0;
        hflip     <= 0;
        last_word <= 0;
        fetch_dly <= 0;
    end else begin
        if( hstart ) begin
            st     <= IDLE;
            busy   <= 0;
            obj_cs <= 0;
        end else case( st )
            IDLE: if( start ) begin
                cur       <= offset[14:0];
                hflip     <= offset[15];
                bf_addr   <= xpos;
                xacc      <= 0;
                busy      <= 1;
                obj_cs    <= 1;
                fetch_dly <= 1;     // ignore obj_ok for one cycle after a request
                st        <= FETCH;
            end
            FETCH: begin
                fetch_dly <= 0;
                if( !fetch_dly && obj_ok ) begin
                    pxl_data  <= !hangon ? obj_data :
                                 hflip   ? { 16'd0, w16 } : { w16, 16'd0 };
                    last_word <= hangon ? &(hflip ? w16[15:12]      : w16[3:0]) :
                                          &(hflip ? obj_data[31-:4] : obj_data[3:0]);
                    obj_cs    <= 0;
                    k         <= 0;
                    st        <= DRAW;
                end
            end
            DRAW: begin
                xacc     <= xsum[7:0];
                pxl_data <= hflip ? pxl_data>>4 : pxl_data<<4;
                k        <= k + 3'd1;
                if( emit ) bf_addr <= bf_addr + 9'd1;
                if( line_end ) begin
                    busy   <= 0;
                    obj_cs <= 0;
                    st     <= IDLE;
                end else if( word_end ) begin
                    if( last_word ) begin
                        busy <= 0;
                        st   <= IDLE;
                    end else begin
                        cur       <= hflip ? cur - 15'd1 : cur + 15'd1;
                        obj_cs    <= 1;
                        fetch_dly <= 1;
                        st        <= FETCH;
                    end
                end
            end
            default: st <= IDLE;
        endcase
    end
end

endmodule
