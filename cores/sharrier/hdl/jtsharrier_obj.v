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

/*  JTSHARRIER — sprite engine top

    jtsharrier_obj_scan  -> walks sprite RAM, per-line address stepping (zoom table)
    jtsharrier_obj_draw  -> fetches 32-bit sprite ROM, unpacks 8 px/word, hzoom
    jtframe_obj_buffer   -> double line buffer, scanned out as obj_pxl

    Interfaces VERIFIED from source:
      * output pxl[11:0] feeds jts16_tilemap.obj_pxl, whose contract (jts16_prio.v)
        is { prio[1:0], pal[5:0], pix[3:0] }; pix==0 transparent, pal==3f shadow.
      * jtframe_obj_buffer (jtframe/hdl/ram): DW/AW/ALPHAW/ALPHA parameters,
        ports clk/LHBL/flip/wr_data/wr_addr/we/rd_addr/rd/rd_data. It toggles the
        line automatically on the LHBL falling edge and erases after read, so
        ALPHA=0 gives us "pix==0 is transparent" for free.

    Sprite RAM is the existing 4KB u_objram in jtsharrier_game.v, not a
    double-buffered copy. MAME writes the running address back into the live
    table (data[7]), so the scanner shares that RAM through its port B.
*/

module jtsharrier_obj(
    input              rst,
    input              clk,
    input              pxl_cen,

    // sprite RAM port B (shared with the CPU port A in jtsharrier_game)
    output     [11:1]  tbl_addr,
    input      [15:0]  tbl_dout,
    output     [15:0]  tbl_din,
    output             tbl_we,

    // zoom table ROM (8KB BRAM, epr-6844)
    output     [12:0]  zoom_addr,
    input      [ 7:0]  zoom_data,

    // sprite ROM (1MB = 8 banks x 0x20000, 32-bit reads)
    input              obj_ok,
    output             obj_cs,
    output     [19:2]  obj_addr,
    input      [31:0]  obj_data,

    // video timing
    input              flip,
    input              hstart,
    input              LHBL,
    input      [ 8:0]  vrender,
    input      [ 8:0]  hdump,   // used to reload hobj on the last blanking pixel

    // ---- live diagnostics (jtframe debug_bus / debug_view) -----------------
    //
    //   debug_bus[7]=0  NORMAL RENDER. Modifier bits:
    input      [ 7:0]  debug_bus,
    output     [ 7:0]  debug_view,

    output     [11:0]  pxl
);

wire       dbg_probe = debug_bus[7];
wire       dbg_tbl   = dbg_probe & ~debug_bus[6];
wire       dbg_zoom  = dbg_probe &  debug_bus[6];
wire [7:0] spr_end;
wire       ovr;

// scan -> draw
wire        dr_start, dr_busy;
wire [ 8:0] dr_xpos;
wire [15:0] dr_offset;   // [15] = hflip
wire [ 2:0] dr_bank;
wire [ 1:0] dr_prio;
wire [ 5:0] dr_pal;
wire        dr_shadow;
wire [ 6:0] dr_hzoom;
wire        ln_done;

// draw -> buffer
wire [11:0] bf_data;
wire [ 8:0] bf_addr;
wire        bf_we;

wire [11:1] scan_tbl_addr;
wire [12:0] scan_zoom_addr;

assign tbl_addr  = dbg_tbl  ? { 6'd0, debug_bus[5:1] } : scan_tbl_addr;
assign zoom_addr = dbg_zoom ? { 7'd0, debug_bus[5:0] } : scan_zoom_addr;
assign debug_view = dbg_tbl  ? ( debug_bus[0] ? tbl_dout[15:8] : tbl_dout[7:0] ) :
                    dbg_zoom ? zoom_data :
                               { ovr, spr_end[6:0] };

jtsharrier_obj_scan u_scan(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .vrender    ( vrender   ),
    .hstart     ( hstart    ),

    .tbl_addr   ( scan_tbl_addr ),
    .tbl_dout   ( tbl_dout  ),
    .tbl_din    ( tbl_din   ),
    .tbl_we     ( tbl_we    ),

    .zoom_addr  ( scan_zoom_addr ),
    .zoom_data  ( zoom_data ),

    .dbg_nozoom ( debug_bus[6] & ~dbg_probe ),
    .dbg_norow  ( debug_bus[4] & ~dbg_probe ),
    .dbg_nohzoom( debug_bus[5] & ~dbg_probe ),
    .dbg_freeze ( dbg_probe ),
    .spr_end    ( spr_end   ),
    .ovr        ( ovr       ),

    .dr_start   ( dr_start  ),
    .dr_busy    ( dr_busy   ),
    .dr_xpos    ( dr_xpos   ),
    .dr_offset  ( dr_offset ),
    .dr_bank    ( dr_bank   ),
    .dr_prio    ( dr_prio   ),
    .dr_pal     ( dr_pal    ),
    .dr_shadow  ( dr_shadow ),
    .dr_hzoom   ( dr_hzoom  ),
    .ln_done    ( ln_done   )
);

jtsharrier_obj_draw u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .hstart     ( hstart    ),

    .start      ( dr_start  ),
    .busy       ( dr_busy   ),
    .xpos       ( dr_xpos   ),
    .offset     ( dr_offset ),
    .bank       ( dr_bank   ),
    .prio       ( dr_prio   ),
    .pal        ( dr_pal    ),
    .shadow     ( dr_shadow ),
    .hzoom      ( dr_hzoom  ),

    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    .bf_data    ( bf_data   ),
    .bf_we      ( bf_we     ),
    .bf_addr    ( bf_addr   )
);

// Line-buffer scan-out counter.
//
localparam [8:0] HB_END     = 9'h0bf;
localparam [8:0] HOBJ_START = 9'h0bd;   // device x of screen column 0
localparam [8:0] HOBJ_FLIP  = 9'h1fc;   // 189+319 = 508: device x of column 0 when flipped

// hobj free-runs through blanking and reloads on the rising edge of LHBL.
// jtframe_obj_buffer erases each entry as it is read, so parking the read
// address on HOBJ_START -- screen column 0 -- would wipe that column hundreds
// of times per line and cost every sprite its leftmost pixel. Gating rd with
// LHBL avoids that but stops the buffer's output register updating during
// blanking, leaving the left edge holding the previous line's last pixel, so
// rd stays ungated and hobj free-runs instead.
reg [8:0] hobj;
always @(posedge clk) if( pxl_cen ) begin
    if( hdump==HB_END )                      // last pixel before active video
        hobj <= flip ? HOBJ_FLIP : HOBJ_START;
    else
        hobj <= flip ? hobj - 1'd1 : hobj + 1'd1;
end

// Double line buffer. ALPHA=0 over the low 4 bits = pix 0 is transparent.
jtframe_obj_buffer #(
    .DW     ( 12    ),
    .AW     (  9    ),
    .ALPHAW (  4    ),
    .ALPHA  ( 32'd0 )
) u_buffer(
    .clk     ( clk      ),
    .LHBL    ( LHBL     ),
    .flip    ( 1'b0     ),   // handled by the hobj direction above

    .wr_data ( bf_data  ),
    .wr_addr ( bf_addr  ),
    .we      ( bf_we    ),

    .rd_addr ( hobj     ),
    // rd stays ungated -- see the hobj comment above.
    .rd      ( pxl_cen  ),
    .rd_data ( pxl      )
);

endmodule
