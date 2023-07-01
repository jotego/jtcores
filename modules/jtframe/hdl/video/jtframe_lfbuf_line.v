/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 30-10-2022 */

// Frame buffer built on top of two line buffers
// the frame buffer is assumed to be done on a 16-bit memory
// It uses 4x lines of internal BRAM.
// The idea is to use a regular object double line buffer to collect the line from the object processing unit
// at the same time, the previous line is dumped to the SDRAM
// in the mean time, one line is read from the SDRAM into another line buffer and
// the previous line is dumped from the same line buffer to the screen

// This module is not fully tested yet
module jtframe_lfbuf_line #(parameter
    DW      =  16,
    VW      =   8,
    HW      =   9
)(
    input               rst,
    input               clk,
    input               pxl_cen,
    // video status
    input      [VW-1:0] vrender,
    input      [HW-1:0] hdump,
    input               vs,     // vertical sync, the buffer is swapped here
    input               lvbl,   // vertical blank, active low

    // core interface
    output reg          ln_hs,
    output reg [VW-1:0] ln_v,
    input      [HW-1:0] ln_addr,
    input      [DW-1:0] ln_data,
    input               ln_we,
    output reg [DW-1:0] ln_pxl,

    // data written to external memory
    output reg          frame,
    input      [HW-1:0] fb_addr,
    input      [HW-1:0] rd_addr,
    output     [  15:0] fb_din,
    input               fb_clr,
    input               fb_done,

    // data read from external memory to screen buffer
    // during h blank
    input      [  15:0] fb_dout,
    input               line,
    input               scr_we
);

reg           vsl, lvbl_l, done;
reg  [VW-1:0] vstart=0, vend=0;
wire [  15:0] scr_pxl;
reg  [   1:0] vrdy;

always @(posedge clk) if(pxl_cen) ln_pxl <= scr_pxl[DW-1:0];

`ifdef SIMULATION
initial begin
    if( DW>16 ) begin
        $display("jtframe_framebuf: cannot handle pixels of more than 16 bits");
        $finish;
    end
end
`endif

// Capture the vstart/vend values
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vrdy   <= 0;
        lvbl_l <= 0;
    end else begin
        lvbl_l <= lvbl;
        vsl    <= vs;
        if( !lvbl &&  lvbl_l ) begin
            vrdy[0] <= 1;
            vend    <= vrender;
        end
        if(  lvbl && !lvbl_l ) begin
            vrdy[1] <= 1;
            vstart  <= vrender;
        end
    end
end

// count lines so objects get drawn in the line buffer
// and dumped from there to the SDRAM
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        frame <= 0;
        ln_hs <= 0;
        ln_v  <= 0;
        done  <= 0;
    end else if(&vrdy) begin
        ln_hs <= 0;
        if( vs && !vsl ) begin // object parsing starts during VB
            frame <= ~frame;
            ln_v  <= vstart;
            ln_hs <= 1;
            done  <= 0;
        end
        if( fb_done && !done ) begin
            ln_v <= ln_v + 1'd1;
            if( ln_v == vend )
                done <= 1;
            else
                ln_hs <= 1;
        end
    end
end

localparam [15:0] LFBUF_CLR = `ifndef JTFRAME_LFBUF_CLR 0 `else `JTFRAME_LFBUF_CLR `endif ;

// collect input data
jtframe_dual_ram #(.DW(16),.AW(HW+1)) u_linein(
    // Write to SDRAM and delete
    .clk0   ( clk           ),
    .data0  ( LFBUF_CLR     ),
    .addr0  ( { line^fb_clr, fb_addr } ),
    .we0    ( fb_clr        ),
    .q0     ( fb_din        ),
    // Get new pixels from core
    .clk1   ( clk           ),
    .data1  ( { {16-DW{1'b0}}, ln_data } ),
    .addr1  ( { line, ln_addr } ),
    .we1    ( ln_we         ), // the core should not send transparent pixels
    .q1     (               )
);

jtframe_rpwp_ram #(.DW(16),.AW(HW)) u_lineout(
    .clk    ( clk           ),
    // Read from SDRAM, write to line buffer
    .din    ( fb_dout       ),
    .wr_addr( rd_addr       ),
    .we     ( scr_we        ),
    // Read from line buffer to screen
    .rd_addr( hdump         ),
    .dout   ( scr_pxl       )
);

endmodule