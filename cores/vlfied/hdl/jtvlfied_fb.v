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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 7-8-2026 */

/*  Player-drawn bitmap framebuffer, 512 KB in its own SDRAM bank: 2 pages x
    256 rows x 512 columns x 16 bits. Page select is video_ctrl[0]; the word
    address is y*512+x. Writes are masked per bit by video_mask, so a write
    becomes a read-modify-write unless the mask is all ones. video_ctrl reads
    back 0x60. Pixel decode follows volfied.cpp refresh_pixel_layer.

    BRAM is not an option here: 512 KB would take ~512 of the 553 M10K blocks.    */

module jtvlfied_fb #(parameter FETCH_W = 512 )(
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

// An all-ones mask needs no read back, which is what the boot clear uses
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
                fbram_addr<=main_addr; fbram_dsn<=main_dsn; fbram_cs<=1;
                fbram_we<=0; cst<=C_RD;
            end else if( main_dsn != 2'b11 ) begin
                // fb_cs asserts at ASn time, but main_dsn and the write data
                // only become valid when the 68k asserts the data strobes
                fbram_addr<=main_addr; fbram_dsn<=main_dsn; fbram_cs<=1;
                if( full_wr ) begin
                    fbram_we<=1; fb_wdata<=main_dout; cst<=C_WR;
                end else begin
                    fbram_we<=0; cst<=C_RMWR;
                end
            end
        end else if( !fb_cs ) fbdone<=0;
    end
    C_RD:   if( fbram_ok ) begin main_din<=fbram_data; fbram_cs<=0; fbdone<=1; cst<=C_DONE; end
    C_RMWR: if( fbram_ok ) begin rmw_old<=fbram_data;  fbram_cs<=0;            cst<=C_WGAP; end
    C_WGAP: begin
        fb_wdata <= (rmw_old & ~video_mask) | (main_dout & video_mask);
        fbram_we <= 1; fbram_cs <= 1; cst<=C_WR;
    end
    C_WR:   if( fbram_ok ) begin fbram_cs<=0; fbram_we<=0; fbdone<=1; cst<=C_DONE; end
    C_DONE: if( !fb_cs ) begin fbdone<=0; cst<=C_IDLE; end
    default: cst<=C_IDLE;
    endcase
end

// A whole line time of slack to fetch the next line, so the per-pixel scanout
// never reaches SDRAM
reg         disp_buf, HSl, fbusy;
reg  [ 8:0] fcol;
reg  [ 7:0] fline;
reg         fpage;
reg  [15:0] lb_din;
reg  [ 9:0] lb_waddr;
reg  [ 1:0] lb_we;
wire [15:0] lb_q;

assign fbrd_addr = { fpage, fline, fcol };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        disp_buf<=0; HSl<=0; fbusy<=0; fbrd_cs<=0; fcol<=0; lb_we<=0;
        fline<=0; fpage<=0;
    end else begin
        HSl  <= HS;
        lb_we<= 0;
        if( HS && !HSl ) begin
            disp_buf <= ~disp_buf;
            fline    <= vrender[7:0] + 8'd7;
            fpage    <= video_ctrl[0];
            fcol     <= 0;
            fbrd_cs  <= 1;
            fbusy    <= 1;
        end else if( fbusy ) begin
            if( fbrd_ok ) begin
                lb_din   <= fbrd_data;
                lb_waddr <= { ~disp_buf, fcol };
                lb_we    <= 2'b11;
                if( fcol == 9'h1ff ) begin
                    fbrd_cs <= 0;
                    fbusy   <= 0;
                end else fcol <= fcol + 9'd1;
            end
        end
    end
end

jtframe_dual_ram16 #(.AW(10)) u_lbuf(
    .clk0   ( clk       ),
    .data0  ( lb_din    ),
    .addr0  ( lb_waddr  ),
    .we0    ( lb_we     ),
    .q0     (           ),
    .clk1   ( clk       ),
    .data1  ( 16'd0     ),
    // ROT270 makes display_x = vrender and display_y = 319-hdump, so the fline
    // and hdump offsets move the bitmap left and up respectively. MAME reads
    // videoram[y*512 + x+1]; the rest of both offsets is empirical alignment
    // against the sprites.
    .addr1  ( { disp_buf, hdump - 9'd2 } ),
    .we1    ( 2'd0      ),
    .q1     ( lb_q      )
);

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
