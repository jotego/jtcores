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

    ===========================================================================
    Volfied bitmap framebuffer — SDRAM backed.

    The 512 KB player-drawn bitmap (2 pages x 256 rows x 512 cols x 16-bit)
    lives in its OWN SDRAM bank (bank 3), NOT in BRAM (it would eat ~512 of the
    553 M10K blocks and never fit). Two SDRAM ports on that bank:
      - fbram : CPU read / write (RW). The per-bit video_mask write becomes a
                read-modify-write here; mask=0xffff is a single straight write.
      - fbrd  : video line fetch (read). A double-buffered line buffer in BRAM
                holds the current display line while the next one is fetched, so
                the heavy per-pixel scanout never touches SDRAM directly and the
                fetch has a whole line-time (~64us) of slack.

    Pixel decode = volfied.cpp refresh_pixel_layer (16-bit word -> 12-bit pen).
    Page select = video_ctrl[0]. CPU paces on fb_ok (wired into the 68k DTACK).
    ===========================================================================
*/

module jtvolfied_fb #(parameter FETCH_W = 512 )(
    input               rst,
    input               clk,
    input               pxl_cen,

    input        [ 8:0] hdump,
    input        [ 8:0] vrender,
    input               flip,
    input               HS,

    // CPU bitmap access (0x400000-0x47ffff). fb_ok feeds the 68k DTACK.
    input        [18:1] main_addr,
    input        [15:0] main_dout,
    output reg   [15:0] main_din,
    input        [ 1:0] main_dsn,
    input               main_rnw,
    input               fb_cs,
    output              fb_ok,

    // control registers
    input               vmask_cs,       // 600000 video mask write
    input               vctrl_cs,       // d00000 video control r/w
    output       [15:0] vctrl_dout,

    // SDRAM bank 3, port A: CPU read/write (RW). din = fb_wdata (the RMW result)
    output reg   [18:1] fbram_addr,
    output reg   [ 1:0] fbram_dsn,
    output reg          fbram_we,
    output reg          fbram_cs,
    output reg   [15:0] fb_wdata,
    input        [15:0] fbram_data,
    input               fbram_ok,

    // SDRAM bank 3, port B: video line fetch (read)
    output       [18:1] fbrd_addr,
    output reg          fbrd_cs,
    input        [15:0] fbrd_data,
    input               fbrd_ok,

    // 12-bit palette index to the colour mixer
    output reg   [11:0] fb_pxl
);

reg  [15:0] video_mask, video_ctrl;

// video_ctrl_r returns 0x60 on hardware (status bits the game polls).
assign vctrl_dout = 16'h0060;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        video_mask <= 16'hffff;
        video_ctrl <= 0;
    end else begin
        if( vmask_cs && !main_rnw ) video_mask <= main_dout;
        if( vctrl_cs && !main_rnw ) video_ctrl <= main_dout;
    end
end

// ---------------------------------------------------------------------------
// CPU read/write to the bitmap, paced on fb_ok (-> 68k DTACK).
//   mask==0xffff : single SDRAM write (fast path, used by the boot clear)
//   else         : read-modify-write  (read old, merge per-bit, write back)
// ---------------------------------------------------------------------------
localparam [2:0] C_IDLE=0, C_RD=1, C_RMWR=2, C_WGAP=3, C_WR=4, C_DONE=5;
reg  [ 2:0] cst;
reg  [15:0] rmw_old;
reg         fbdone;
wire        full_wr = video_mask==16'hffff;   // dsn byte-enables handle byte writes
assign      fb_ok   = fbdone;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cst<=C_IDLE; fbram_cs<=0; fbram_we<=0; fbdone<=0; main_din<=0;
        fbram_addr<=0; fbram_dsn<=0; fb_wdata<=0; rmw_old<=0;
    end else case( cst )
    C_IDLE: begin
        fbram_we<=0; fbram_cs<=0;
        if( fb_cs && !fbdone ) begin
            if( main_rnw ) begin
                // read: address (ASn) is enough, byte mask irrelevant
                fbram_addr<=main_addr; fbram_dsn<=main_dsn; fbram_cs<=1;
                fbram_we<=0; cst<=C_RD;
            end else if( main_dsn != 2'b11 ) begin
                // WRITE: fb_cs asserts at ASn time, but {UDSn,LDSn} (=main_dsn)
                // and the write data are only valid once the 68k asserts the
                // data strobes. Wait for that here (the cycle is held by
                // bus_busy until fb_ok) so we don't latch dsn=11 and mask off
                // the whole write (which left the SDRAM bitmap all zeros).
                fbram_addr<=main_addr; fbram_dsn<=main_dsn; fbram_cs<=1;
                if( full_wr ) begin
                    fbram_we<=1; fb_wdata<=main_dout; cst<=C_WR;
                end else begin
                    fbram_we<=0; cst<=C_RMWR;   // read first (RMW)
                end
            end
            // write with strobes not yet asserted: hold in C_IDLE one more cycle
        end else if( !fb_cs ) fbdone<=0;
    end
    C_RD:   if( fbram_ok ) begin main_din<=fbram_data; fbram_cs<=0; fbdone<=1; cst<=C_DONE; end
    C_RMWR: if( fbram_ok ) begin rmw_old<=fbram_data;  fbram_cs<=0;            cst<=C_WGAP; end
    C_WGAP: begin // one cycle gap, then issue the merged write
        fb_wdata <= (rmw_old & ~video_mask) | (main_dout & video_mask);
        fbram_we <= 1; fbram_cs <= 1; cst<=C_WR;
    end
    C_WR:   if( fbram_ok ) begin fbram_cs<=0; fbram_we<=0; fbdone<=1; cst<=C_DONE; end
    C_DONE: if( !fb_cs ) begin fbdone<=0; cst<=C_IDLE; end
    default: cst<=C_IDLE;
    endcase
end

// ---------------------------------------------------------------------------
// Video line fetch: double-buffered. At each HS, swap which buffer is
// displayed and start fetching the upcoming line (vrender) into the other.
// ---------------------------------------------------------------------------
reg         disp_buf, HSl, fbusy;
reg  [ 8:0] fcol;
reg  [ 7:0] fline;
reg         fpage;
reg  [15:0] lb_din;
reg  [ 9:0] lb_waddr;
reg  [ 1:0] lb_we;
wire [15:0] lb_q;

assign fbrd_addr = { fpage, fline, fcol };   // 1+8+9 = 18-bit word address

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        disp_buf<=0; HSl<=0; fbusy<=0; fbrd_cs<=0; fcol<=0; lb_we<=0;
        fline<=0; fpage<=0;
    end else begin
        HSl  <= HS;
        lb_we<= 0;
        if( HS && !HSl ) begin            // new line: swap + start fetch
            disp_buf <= ~disp_buf;
            fline    <= vrender[7:0] + 8'd7;   // +7 row = BG 7px left in portrait
            fpage    <= video_ctrl[0];
            fcol     <= 0;
            fbrd_cs  <= 1;
            fbusy    <= 1;
        end else if( fbusy ) begin
            if( fbrd_ok ) begin
                lb_din   <= fbrd_data;
                lb_waddr <= { ~disp_buf, fcol };  // fetch target = the non-displayed buffer
                lb_we    <= 2'b11;
                if( fcol == 9'h1ff ) begin   // fetched full 512-col line
                    fbrd_cs <= 0;
                    fbusy   <= 0;
                end else fcol <= fcol + 9'd1;
            end
        end
    end
end

// Two-line buffer (1024 x 16). Port 0: fetch write. Port 1: scanout read.
jtframe_dual_ram16 #(.AW(10)) u_lbuf(
    .clk0   ( clk       ),
    .data0  ( lb_din    ),
    .addr0  ( lb_waddr  ),
    .we0    ( lb_we     ),
    .q0     (           ),
    .clk1   ( clk       ),
    .data1  ( 16'd0     ),
    // x+1 is MAME's videoram[y*512 + x+1]; net -2 (=+1-3) shifts BG 3px up in
    // the rotated (portrait) view to align with sprites. Row offset (+7, see
    // fline above) shifts BG 7px left. Both empirical, ROT270 = SWAP_XY|FLIP_Y:
    //   display_x = vrender (fline)   -> +7 fline  = 7px left
    //   display_y = 319 - hdump       -> -3 column = 3px up
    .addr1  ( { disp_buf, hdump - 9'd2 } ),
    .we1    ( 2'd0      ),
    .q1     ( lb_q      )
);

// Pixel -> palette index decode (volfied.cpp refresh_pixel_layer):
//   color = (px<<2)&0x700;  color[10:8]=px[8:6]
//   if(px&0x8000){ color|=0x800|((px>>9)&0xf); if(px&0x2000) color&=~0xf; }
//   else          color|= px&0xf;
reg [11:0] color;
always @* begin
    color       = 12'd0;
    color[10:8] = lb_q[8:6];
    if( lb_q[15] ) begin
        color[11]  = 1'b1;
        color[3:0] = lb_q[13] ? 4'd0 : lb_q[12:9];
    end else begin
        color[3:0] = lb_q[3:0];
    end
end

always @(posedge clk) if(pxl_cen) fb_pxl <= color;

endmodule
