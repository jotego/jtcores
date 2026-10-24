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

    Author: Andrea Bogazzi.
    Date: 5-2026 */

// ============================================================================
// jttaitob_obj — TC0180VCU sprite engine
// ============================================================================
// Phase 3d-a.1: real 16x16 gfx (unscaled, single-tile — big-sprite zoom are
// 3d-b/c).  Per scanline the scanner walks the 408-slot sprite list; for each
// slot covering the next line it reads code/color/x, fetches the tile's gfx
// row from the obj bus (gsort'd, like BG/FG), decodes 16 pens (flipX/flipY)
// and writes them into a jtframe_obj_buffer (ping-pong line buffer).  Pen 0 is
// transparent (the buffer's ALPHA=0 skips it).
//
// Sprite slot (8 words, oram word offs = slot*8; scanned reverse hi->lo):
//   +0 code[14:0]
//   +1 color[5:0]  flipx[14]  flipy[15]
//   +2 x  [9:0] signed (>=0x200 -> -0x400)
//   +3 y  [9:0] signed
//   +4 zoom  (3d-c)    +5 big (3d-b)
//
// oram + obj reads have 1-clk latency → address issued one state before use.
// Line buffer filled during line N active for line N+1 (vrender), read on
// line N+1 after jtframe_obj_buffer swaps at LHBL.
// ============================================================================

module jttaitob_obj(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               LHBL,
    input               LVBL,
    input        [ 8:0] hdump,
    input        [ 8:0] vrender,        // line being prepared (= vdump+1)

    // sprite RAM read (oram) — arbitrated against the scroll FSM in video.v
    output reg   [12:0] sc_addr,
    output reg          sc_cs,
    input        [15:0] sc_data,

    // gfx ROM read (obj bus) — arbitrated against the FG fill in video.v
    output reg   [18:0] gfx_addr,
    output reg          gfx_cs,
    input        [15:0] gfx_data,
    input               gfx_ok,

    // pixel output to the priority mux
    output       [11:0] obj_pixel,
    output              obj_visible
);

localparam [12:0] OBJ_TOP = 13'h0CB8;   // (0x1980-16)/2 — highest slot word offs

localparam [3:0] IDLE=0, WAITY=1, GETY=2, WAITK=3, GETK=4, WAITC=5, GETC=6,
                 WAITX=7, GETX=8, G0=9, G1=10, G2=11, G3=12, DRAW=13, NEXT=14;

// gfx_sort swap (matches video.v / mem.yaml gfx_sort=hvvvx): the gfx region
// is byte-reordered, so every gfx address is remapped {A[18:4],A[2:0],A[3]}.
function [18:0] gsort; input [18:0] a; gsort = {a[18:4], a[2:0], a[3]}; endfunction

// One 4bpp pen of a 16x16 tile row (same plane/byte order as the tile planes).
function [3:0] obj_pen;
    input [ 3:0] p;
    input [15:0] w01l, w23l, w01r, w23r;
    reg   [ 3:0] b;
    reg   [15:0] w01, w23;
    begin
        b   = {1'b0, ~p[2:0]};
        w01 = p[3] ? w01r : w01l;
        w23 = p[3] ? w23r : w23l;
        obj_pen = { w01[b], w01[b+4'd8], w23[b], w23[b+4'd8] };
    end
endfunction

reg  [12:0] offs;
reg  [ 3:0] st;
reg  [13:0] spr_code;
reg  [11:0] spr_pal;                    // color*16 (palette base)
reg  [ 9:0] spr_x;
reg         flipx, flipy;
reg  [ 3:0] row_e;                      // tile row 0..15 (flipY applied)
reg  [15:0] w01l, w23l, w01r, w23r;
reg  [ 3:0] wcnt;
reg         lhbl_d;
reg         we;
reg  [ 8:0] waddr;
reg  [11:0] wdata;

wire        line_start = ~lhbl_d & LHBL;

// Coverage of the prepared line: vrender in [y, y+16).  y is 10-bit signed.
wire signed [11:0] vren_s = $signed({3'b0, vrender});
wire signed [11:0] y_now  = $signed({{2{sc_data[9]}}, sc_data[9:0]});
wire               covered = (vren_s >= y_now) && (vren_s < (y_now + 12'sd16));
wire        [ 3:0] row_now = (vren_s - y_now);        // 0..15 within the tile

// gfx row addresses for the captured code + row (left/right 8px halves)
wire [18:0] fw01l = gsort({spr_code[13:0], row_e[3], 1'b0, row_e[2:0]});
wire [18:0] fw01r = gsort({spr_code[13:0], row_e[3], 1'b1, row_e[2:0]});
wire [18:0] fw23l = fw01l + 19'h40000;
wire [18:0] fw23r = fw01r + 19'h40000;

// pixel index within the tile for the current write column (flipX)
wire [ 3:0] pidx = flipx ? (4'd15 - wcnt) : wcnt;
wire [ 3:0] pen  = obj_pen(pidx, w01l, w23l, w01r, w23r);

always @(posedge clk) begin
    if (rst) begin
        st <= IDLE; offs <= 13'd0; sc_cs <= 1'b0; sc_addr <= 13'd0;
        gfx_cs <= 1'b0; gfx_addr <= 19'd0; we <= 1'b0; wcnt <= 4'd0;
        spr_code <= 14'd0; spr_pal <= 12'd0; spr_x <= 10'd0;
        flipx <= 1'b0; flipy <= 1'b0; row_e <= 4'd0;
        w01l <= 16'd0; w23l <= 16'd0; w01r <= 16'd0; w23r <= 16'd0; lhbl_d <= 1'b0;
    end else begin
        lhbl_d <= LHBL;
        we     <= 1'b0;
        case (st)
        IDLE: begin
            sc_cs <= 1'b0; gfx_cs <= 1'b0;
            if (line_start && LVBL) begin
                offs    <= OBJ_TOP;
                sc_addr <= OBJ_TOP + 13'd3;          // issue y
                sc_cs   <= 1'b1;
                st      <= WAITY;
            end
        end
        WAITY: st <= GETY;
        GETY:  begin                                 // y valid
            if (covered) begin
                row_e   <= row_now;                  // flipY applied after color read
                sc_addr <= offs + 13'd0;             // issue code
                st <= WAITK;
            end else st <= NEXT;
        end
        WAITK: st <= GETK;
        GETK:  begin                                 // code valid
            spr_code <= sc_data[13:0];
            sc_addr  <= offs + 13'd1;                // issue color
            st <= WAITC;
        end
        WAITC: st <= GETC;
        GETC:  begin                                 // color valid
            spr_pal <= {2'b01, sc_data[5:0], 4'b0};  // fb_color_base 0x400 + color*16
            flipx   <= sc_data[14];
            flipy   <= sc_data[15];
            if (sc_data[15]) row_e <= ~row_e;        // flipY
            sc_addr <= offs + 13'd2;                 // issue x
            st <= WAITX;
        end
        WAITX: st <= GETX;
        GETX:  begin                                 // x valid
            spr_x   <= sc_data[9:0];
            gfx_cs  <= 1'b1;
            gfx_addr<= fw01l;                        // issue gfx w01l
            st <= G0;
        end
        G0: if (gfx_ok) begin w01l <= gfx_data; gfx_addr <= fw23l; st <= G1; end
        G1: if (gfx_ok) begin w23l <= gfx_data; gfx_addr <= fw01r; st <= G2; end
        G2: if (gfx_ok) begin w01r <= gfx_data; gfx_addr <= fw23r; st <= G3; end
        G3: if (gfx_ok) begin                        // gfx_data = w23r now
            w23r <= gfx_data;                        // latch right-half planes 2/3
            gfx_cs <= 1'b0; wcnt <= 4'd0; st <= DRAW;
        end
        DRAW: begin                                  // write 16 pens (pen 0 transparent)
            we    <= 1'b1;
            waddr <= spr_x[8:0] + {5'b0, wcnt};
            wdata <= spr_pal | {8'h0, pen};
            wcnt  <= wcnt + 4'd1;
            if (wcnt == 4'd15) st <= NEXT;
        end
        NEXT: begin
            if (offs == 13'd0) begin
                sc_cs <= 1'b0; st <= IDLE;
            end else begin
                offs    <= offs - 13'd8;
                sc_addr <= (offs - 13'd8) + 13'd3;   // issue next y
                st <= WAITY;
            end
        end
        default: st <= IDLE;
        endcase
    end
end

jtframe_obj_buffer #(.DW(12), .AW(9), .ALPHAW(4), .ALPHA(0), .BLANK(0)) u_line(
    .clk     ( clk        ),
    .LHBL    ( LHBL       ),
    .flip    ( 1'b0       ),
    .wr_data ( wdata      ),
    .wr_addr ( waddr      ),
    .we      ( we         ),
    .rd_addr ( rd_addr    ),
    .rd      ( pxl_cen    ),
    .rd_data ( obj_pixel  )
);

// jtframe_obj_buffer registers rd_data on pxl_cen (1px latency, same as the
// BG/FG/TX rings) — read one column ahead so sprites line up with the planes.
wire [8:0] rd_addr = hdump + 9'd1;

assign obj_visible = |obj_pixel;

endmodule
