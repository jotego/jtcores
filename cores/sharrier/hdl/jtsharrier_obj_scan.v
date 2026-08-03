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

/*  JTSHARRIER — sprite table scanner

    ATTRIBUTION
    -----------
    The sprite draw algorithm implemented here is DERIVED FROM MAME source:
    `sega_sharrier_sprite_device::draw` in sega16sp.cpp.

        MAME sega16sp.cpp
        license: BSD-3-Clause
        copyright-holders: Aaron Giles

    BSD-3-Clause is compatible with this core's GPL-3 and requires the copyright
    notice to be retained in redistributions.

    Walks sprite RAM once per scanline, finds the sprites covering this line,
    keeps the per-sprite running ROM offset in the descriptor's scratch word,
    and issues draw commands.

    Everything below is taken from sega16sp.cpp,
    sega_sharrier_sprite_device::draw.

    Descriptor (8 words / 16 bytes per sprite):
      +0  bbbbbbbb tttttttt   bottom = [15:8], top = [7:0]   (DEVICE scanlines)
      +2  -bbb---- --------   bank = (data[1]>>12)&7         (3 bits; m_bank[] is
                              1:1 by default and segahang never calls set_bank)
      +2  -------x xxxxxxxx   xpos = data[1]&0x1ff  (xpos $BD = screen X 0)
      +4  s------- --------   shadow DISABLE (0 = shadow enabled)
      +4  -p------ --------   priority
      +4  --cccccc --------   colour palette
      +4  -------- -ppppppp   pitch = sext(data[2],7)        signed
      +6  f------- --------   flip (address bit 15)
      +6  -ooooooo oooooooo   offset within bank
      +8  --zzzzzz --------   hzoom (used as <<1)
      +8  -------- --zzzzzz   vzoom
      +E  dddddddd dddddddd   scratch: running address

      Terminator: bottom > 0xF0 ends the WHOLE list.  Skip if top >= bottom.

    COORDINATES — sega16sp.cpp: set_local_origin(189, -1), and
    devices/video/sprite.h applies the origin by offsetting the cliprect and
    re-basing the bitmap pointer. So inside draw() the coordinates are DEVICE
    coordinates and:
          screen_x = device_x - 189      (handled by HOBJ_START in _obj.v)
          screen_y = device_y + 1        (handled HERE: vdev = vrender-1)
    which is consistent with the MAME comment "Bottom/Top scanline of sprite - 1".

    Vertical zoom is STATEFUL down the sprite:
        for y = top .. bottom-1:
            addr += pitch
            if (zoom[zaddr++] & zmask) addr += pitch
        zaddr = (vzoom & 0x38) << 5        <-- vzoom[5:3] << 8, not << 6
        zmask = 1 << (vzoom & 7)
    Because device y is always >= 0, every line of a sprite that is on screen at
    all is scanned in order starting at y==top, so keeping the running address in
    the +E scratch reproduces MAME's local `addr` exactly.

*/

module jtsharrier_obj_scan(
    input              rst,
    input              clk,

    input      [ 8:0]  vrender,
    input              hstart,

    // sprite RAM port B, 4KB = 2K x 16
    output     [11:1]  tbl_addr,
    input      [15:0]  tbl_dout,
    output reg [15:0]  tbl_din,
    output reg         tbl_we,

    // zoom table ROM (epr-6844, 8KB)
    output     [12:0]  zoom_addr,
    input      [ 7:0]  zoom_data,

    // draw command
    output reg         dr_start,
    input              dr_busy,
    output reg [ 8:0]  dr_xpos,
    output reg [15:0]  dr_offset,   // [15] = hflip
    output reg [ 2:0]  dr_bank,
    output reg [ 1:0]  dr_prio,
    output reg [ 5:0]  dr_pal,
    output reg         dr_shadow,   // shadow ENABLED for this sprite
    output reg [ 6:0]  dr_hzoom,

    output reg         ln_done,

    // ---- live diagnostics (debug_bus; all zero = normal operation) ---------
    input              dbg_nozoom,   // force the zoom-table double-step off
    input              dbg_norow,    // ignore the scratch: every line redraws the
                                     // sprite's FIRST row (kills the vertical walk)
    input              dbg_nohzoom,  // force hzoom=0 (1:1 horizontal)
    input              dbg_freeze,   // hold the scanner at st 0 (probe mode)
    output reg [ 7:0]  spr_end,      // cur_obj when the last line's scan ended
    output reg         ovr           // a line ended while still scanning
);

localparam [2:0] LAST_IDX = 3'd4;   // words +0,+2,+4,+6,+8 then jump to +E (idx 7)

reg  [ 7:0] cur_obj;      // 4KB/16 = 256 sprites
reg  [ 3:0] st;
reg  [ 2:0] idx;
reg         stop, visible, hstart_l;

reg  [ 7:0] top, bottom;
reg  [ 2:0] bank;
reg  [ 8:0] xpos;
reg signed [15:0] pitch;
reg  [15:0] addr;
reg  [ 5:0] vzoom, hzoom6, pal;
reg         prio, shadow_dis, first;
reg  [15:0] scr;          // the +E scratch word, latched

assign tbl_addr = { cur_obj, idx };

// DEVICE y = screen y - 1 (set_local_origin(189,-1))
wire [ 8:0] vdev = vrender - 9'd1;

// zoom table walk: zaddr = (vzoom&0x38)<<5 + (y-top)
wire [12:0] zbase  = { 2'd0, vzoom[5:3], 8'd0 };
wire [ 7:0] yoff   = vdev[7:0] - top;
assign      zoom_addr = zbase + { 5'd0, yoff };
wire        zbit_raw = zoom_data[ vzoom[2:0] ];
wire        zbit     = zbit_raw & ~dbg_nozoom;

// this line's address: the scratch (or the +6 base on the sprite's first line)
// + pitch, +pitch again if the zoom bit is set
wire        first_eff = first | dbg_norow;
wire [15:0] base_addr = first_eff ? addr : scr;
wire [15:0] nx_addr   = base_addr + pitch + (zbit ? pitch : 16'd0);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cur_obj   <= 0;
        st        <= 0;
        idx       <= 0;
        stop      <= 0;
        tbl_we    <= 0;
        tbl_din   <= 0;
        ln_done   <= 0;
        dr_start  <= 0;
        dr_xpos   <= 0;
        dr_offset <= 0;
        dr_bank   <= 0;
        dr_prio   <= 0;
        dr_pal    <= 0;
        dr_shadow <= 0;
        dr_hzoom  <= 0;
        hstart_l  <= 0;
        spr_end   <= 0;
        ovr       <= 0;
        first     <= 0;
        visible   <= 0;
        addr      <= 0;
        scr       <= 0;
        top       <= 0;
        bottom    <= 0;
    end else begin
        // idx FREE-RUNS (jts16_obj_scan pattern). Branches below that force
        // idx<=0 win by being later in the same always block. tbl_addr is
        // combinational and the BRAM has one cycle of latency, so state N must
        // see idx==N for tbl_dout to be word N-1; guarding the increment
        // instead makes every sprite after a skip read one word early.
        idx      <= idx>=LAST_IDX ? 3'd7 : (idx + 3'd1);
        if( !stop ) st <= st + 1'd1;
        hstart_l <= hstart;
        stop     <= 0;
        ln_done  <= 0;
        dr_start <= 0;
        tbl_we   <= 0;

        case( st )
            0: begin
                cur_obj <= 0;
                stop    <= 0;
                if( !(hstart && !hstart_l) || vrender>223 || dbg_freeze ) begin
                    st  <= 0;
                    idx <= 0;
                end
            end
            // tbl_dout = +0 : bottom / top
            1: if( !stop ) begin
                bottom  <= tbl_dout[15:8];
                top     <= tbl_dout[ 7:0];
                visible <= (vdev[8] == 0) && (vdev[7:0] >= tbl_dout[7:0])
                                          && (tbl_dout[15:8] > vdev[7:0])
                                          && (tbl_dout[7:0] < tbl_dout[15:8]);
                first   <= tbl_dout[7:0] == vdev[7:0];
                if( tbl_dout[15:8] > 8'hf0 ) begin      // end of list
                    ln_done <= 1;
                    st      <= 0;
                    idx     <= 0;
                end
            end
            // tbl_dout = +2 : bank / xpos
            2: begin
                bank <= tbl_dout[14:12];
                xpos <= tbl_dout[ 8:0];
            end
            // tbl_dout = +4 : shadow / prio / colour / pitch
            3: begin
                shadow_dis  <= tbl_dout[15];
                prio        <= tbl_dout[14];
                pal         <= tbl_dout[13:8];
                pitch[6:0]  <= tbl_dout[6:0];
                pitch[15:7] <= {9{tbl_dout[6]}};        // sext 7-bit
            end
            // tbl_dout = +6 : flip + base offset (used on the sprite's 1st line)
            4: begin
                addr <= tbl_dout;
                // skip early — before touching the scratch word
                if( !visible ) begin
                    cur_obj <= cur_obj + 1'd1;
                    idx     <= 0;
                    st      <= 1;
                    stop    <= 1;
                    if( &cur_obj ) begin
                        ln_done <= 1;
                        st      <= 0;
                    end
                end
            end
            // tbl_dout = +8 : hzoom / vzoom.  idx jumps to 7, so tbl_addr is
            // now {cur_obj,7} and zoom_addr becomes valid from the NEXT cycle.
            5: begin
                hzoom6 <= tbl_dout[13:8];
                vzoom  <= tbl_dout[ 5:0];
            end
            // tbl_dout = +E : the scratch word.  zoom_addr is valid this cycle,
            // so zoom_data (a registered BRAM read, jtframe_ram LATCH_OUT=0 =>
            // 1 clock) is valid in st 7. Do not use zbit before then.
            6: begin
                scr <= tbl_dout;
            end
            // step the running address and write it back into the scratch word
            7: begin
                addr    <= nx_addr;
                tbl_din <= nx_addr;
                tbl_we  <= ~dbg_norow;   // do not corrupt the scratch while probing
            end
            // issue the draw
            8: begin
                if( !dr_busy ) begin
                    dr_xpos   <= xpos;
                    dr_offset <= addr;                 // [15] = hflip
                    dr_bank   <= bank;
                    dr_prio   <= { prio, 1'b1 };       // MAME: ((pix>>9)&2)|1
                    dr_pal    <= pal;
                    dr_shadow <= ~shadow_dis;          // per-pixel test in _draw
                    dr_hzoom  <= dbg_nohzoom ? 7'd0 : { hzoom6, 1'b0 }; // MAME: (field&0x3f)<<1
                    dr_start  <= 1;
                    cur_obj   <= cur_obj + 1'd1;
                    idx       <= 0;
                    st        <= 1;
                    stop      <= 1;
                    if( &cur_obj ) begin
                        ln_done <= 1;
                        st      <= 0;
                    end
                end else begin
                    st  <= st;     // wait for the drawer
                    idx <= 7;
                end
            end
            default: st <= 0;
        endcase

        // ---- diagnostics ---------------------------------------------------
        // spr_end = how far down the sprite list we got before the line ended.
        // ovr     = still scanning when the next line started, so the list did
        //           not finish and every sprite not reached had its per-line
        //           address walk skipped; those desync on later lines.
        if( ln_done ) spr_end <= cur_obj;
        if( hstart && !hstart_l && st!=0 ) begin
            spr_end <= cur_obj;
            ovr     <= 1;
        end
        if( vrender==0 ) ovr <= 0;     // clear once per frame

        // a new line started while still scanning: restart
        if( hstart && !hstart_l && st!=0 && !dbg_freeze ) begin
            cur_obj  <= 0;
            idx      <= 0;
            st       <= 1;
            stop     <= 1;
            dr_start <= 0;
            tbl_we   <= 0;
        end
    end
end

endmodule
