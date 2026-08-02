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

    Author: niknak
    Version: 1.0
    Date: 2-8-2026 */

/*  JTSHARRIER — sprite row renderer

    ATTRIBUTION
    -----------
    The sprite draw algorithm implemented here is DERIVED FROM MAME source:
    `sega_sharrier_sprite_device::draw` in sega16sp.cpp.

        MAME sega16sp.cpp
        license: BSD-3-Clause
        copyright-holders: Aaron Giles

    BSD-3-Clause is compatible with this core's GPL-3 and requires the copyright
    notice to be retained in redistributions.

    Renders ONE scanline of ONE sprite into the line buffer.

    ===========================================================================
    DIFFERENCES FROM OUT RUN'S DRAWER
    ===========================================================================
    This is not a port of jtoutrun_obj_draw. Out Run's horizontal
    zoom ENLARGES: MAME repeats one source pixel while (xacc < 0x200), then
    subtracts 0x200 and advances the source. Space Harrier's is the exact DUAL —
    it only ever SHRINKS (the sprite ROM holds many pre-scaled copies of each
    object; the zoom hardware just interpolates between them):

        sega16sp.cpp, sega_sharrier_sprite_device::draw, per source pixel:
            pix  = (pixels >> N) & 0xf;
            xacc = (xacc & 0xff) + hzoom;
            if (xacc < 0x100) { if (pix!=0 && pix!=15) dest[x] = colpri|pix; x++; }

    So the source pixel always advances; the screen pixel only advances when
    the accumulator did not carry out of 8 bits. Out Run's structure gives the
    wrong zoom shape here, and half strength, because hzoom is rescaled into a
    0x200 domain without doubling.

    Other differences from Out Run's drawer, all verified against sega16sp.cpp:
      * TERMINATOR. Out Run stops on the SECOND-TO-LAST pixel of the group (its
        MAME comment says so, hence jtoutrun's obj_data[7:4]). Space Harrier
        stops on the LAST pixel DRAWN:
            non-flip: draws [31:28]..[3:0]  -> terminator = obj_data[ 3: 0]
            flip:     draws [3:0]..[31:28]  -> terminator = obj_data[31:28]
      * BANK. Sharrier's region is ROM_REGION32_LE(0x100000) = 1 MB = 8 banks of
        0x20000 (spritedata = base + 0x8000*bank, 32-bit words), so all 3 bank
        bits are real: obj_addr = {bank[2:0], cur[14:0]}. m_bank[] is 1:1 and
        segahang.cpp never calls set_bank, so there is no remap.
        cfg/mem.yaml sets obj addr_width to 20 = 1 MB to match.
      * SHADOW is per pixel, not per sprite. MAME's mix (segahang.cpp,
        sharrier branch): shadow when (pix & 0x80f)==0x00a, so the sprite's
        shadow-enable bit is set AND the 4-bit pixel is exactly 0xA.
        We encode that in the jts16_prio contract by emitting pal==6'h3f, which
        jts16_prio detects with &obj[9:4].

    ===========================================================================
    OUTPUT CONTRACT (jts16_prio.v, verified)
    ===========================================================================
        obj_pxl[11:0] = { prio[1:0], pal[5:0], pix[3:0] }
        pix == 0      -> transparent (jtframe_obj_buffer ALPHA=0 drops the write)
        pal == 6'h3f  -> shadow
        jts16_prio then forms pal_addr = { 2'b1, obj[9:0] } = 0x400 | {pal,pix},
        which is exactly MAME's `dest[x] = 0x400 | (pix & 0x3ff)`.

    ENDIANNESS: jtframe delivers obj_data[31:0] identical to MAME's little-endian
    uint32 read of the sprites region (proven by jtoutrun_obj_draw taking its
    first non-flipped pixel from pxl_data[31-:4] against the same MRA rule,
    width=32 with no reverse, on Out Run's identically-formed ROM_REGION32_LE).
    So obj_data[31:28] is the first pixel of a non-flipped row.
*/

module jtsharrier_obj_draw(
    input              rst,
    input              clk,
    input              hstart,

    // From scan
    input              start,
    output reg         busy,
    input      [ 8:0]  xpos,
    input      [15:0]  offset,    // [15] = hflip, [14:0] = word offset in bank
    input      [ 2:0]  bank,
    input      [ 1:0]  prio,
    input      [ 5:0]  pal,
    input              shadow,    // shadow ENABLED for this sprite
    input      [ 6:0]  hzoom,     // MAME value: (field & 0x3f) << 1

    // SDRAM interface (1 MB sprite ROM, 32-bit reads)
    input              obj_ok,
    output reg         obj_cs,
    output     [19:2]  obj_addr,
    input      [31:0]  obj_data,

    // Line buffer
    output     [11:0]  bf_data,
    output             bf_we,
    output reg [ 8:0]  bf_addr
);

localparam [1:0] IDLE=2'd0, FETCH=2'd1, DRAW=2'd2;

reg  [ 1:0] st;
reg  [ 2:0] k;             // nibble within the 32-bit word
reg  [31:0] pxl_data;
reg  [14:0] cur;           // 15-bit word address inside the bank (wraps: &0x7fff)
reg  [ 7:0] xacc;
reg         hflip, last_word, fetch_dly;

wire [ 3:0] cur_pxl;
wire [ 8:0] xsum;
wire        emit, line_end;

assign cur_pxl  = hflip ? pxl_data[3:0] : pxl_data[31-:4];
assign obj_addr = { bank, cur };
assign xsum     = { 1'b0, xacc } + { 2'b0, hzoom };   // MAME: (xacc&0xff)+hzoom
assign emit     = ~xsum[8];                           // MAME: xacc < 0x100
// MAME's device-space cliprect is 189..508. The line buffer is 512 deep and
// jtsharrier_obj only reads 189..508 back, so stopping at the buffer end is
// equivalent. Stopping there also keeps bf_addr from wrapping onto the line.
assign line_end = st==DRAW && emit && bf_addr==9'h1ff;

// pix 0 = transparent, pix F = row terminator: neither is ever written
assign bf_we    = st==DRAW && emit && cur_pxl!=4'h0 && cur_pxl!=4'hf;
// per-pixel shadow: (pix & 0x80f) == 0x00a
assign bf_data  = { prio, (shadow && cur_pxl==4'ha) ? 6'h3f : pal, cur_pxl };

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
                fetch_dly <= 1;     // jtframe_romrq: ignore obj_ok for 1 cycle
                st        <= FETCH;
            end
            FETCH: begin
                fetch_dly <= 0;
                if( !fetch_dly && obj_ok ) begin
                    pxl_data  <= obj_data;
                    // terminator = the LAST pixel DRAWN in this word
                    last_word <= &(hflip ? obj_data[31-:4] : obj_data[3:0]);
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
                if( line_end ) begin                 // hit the end of the line
                    busy   <= 0;
                    obj_cs <= 0;
                    st     <= IDLE;
                end else if( &k ) begin              // 8th nibble of this word
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
