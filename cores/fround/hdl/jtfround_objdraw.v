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
    Date: 30-8-2023 */

// Draws 16x16 sprites in a double-line buffer
// Assumes that the inputs are still during drawing,
// otherwise set LATCH=1
// LATCH=1 will introduce an extra 1-clock per drawing
// operation, so use LATCH=0 when throughput is critical

// Shadow operation follows TMNT style: an independent bit sets
// shadow for the pixel independently of the pixel color. The
// shadow bit is always written, even if the pixel is blank.
// The shadow bit must be the MSB

module jtfround_objdraw #( parameter
    CW    = 19,    // code width
    PW    =  8,    // pixel width (lower four bits come from ROM)
    HJUMP =  0,    // set to 0 if hdump is a continuous count
                   // set to 1 if hdump jumps from  FF to 180  (like KIWI)
                   // set to 2 if hdump jumps from 1FF to  80  (like JTTORA)
                   // See note below about hdump fix for HJUMP==0
    LATCH =  0,    // If set, latches code, xpos, ysub, hflip, vflip and pal when draw is set and busy is low
    FLIP_OFFSET=0, // Added to ~hdump when flip==1 and HJUMP==0
    KEEP_OLD   =0, // new writes do not overwrite old ones (reverse priority)
    // object line buffer
    SWAPH      =0,
    ALPHA      =0
)(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
    input               flip,
    input        [ 8:0] hdump,

    input               draw,
    output              busy,
    input    [CW-1:0]   code,
    input      [ 8:0]   xpos,
    input      [ 1:0]   hsize,

    input               hflip,
    input      [PW-5:0] pal,

    output     [CW+2:2] rom_addr,
    output              rom_cs,
    input               rom_ok,
    input      [31:0]   rom_data,

    output     [PW-1:0] pxl
);

reg     [8:0] aeff, hdf, hdfix;

reg  [CW-1:0] dr_code;
reg    [ 8:0] dr_xpos;
reg           dr_hflip, dr_draw;
reg  [PW-5:0] dr_pal;
wire [PW-1:0] buf_din;

reg     [1:0] dr_hsize;

wire    [8:0] buf_addr;
wire          buf_we;

generate
    if( LATCH ) begin
        always @(posedge clk) begin
            dr_draw <= draw;
            if( !busy ) begin
                dr_code  <= code;
                dr_xpos  <= xpos;
                dr_hflip <= hflip;
                dr_pal   <= pal;
                dr_hsize <= hsize;
            end
        end
    end else begin
        always @* begin
            dr_draw  = draw;
            dr_code  = code;
            dr_xpos  = xpos;
            dr_hflip = hflip;
            dr_pal   = pal;
            dr_hsize = hsize;
        end
    end
endgenerate

always @* begin
    case( HJUMP )
        1: begin
            aeff = { buf_addr[8], buf_addr[8] | buf_addr[7], buf_addr[6:0] }; // 100~17F is translated to 180~1FF
            hdf  = hdump ^ { 1'b0, flip&~hdump[8], {7{flip}} };
        end
        2: begin
            aeff = { buf_addr[8],~buf_addr[8] | buf_addr[7], buf_addr[6:0] }; //  00~ 7F is translated to  80~ FF
            hdf  = hdump ^ { 1'b0, flip&hdump[8], {7{flip}} }; // untested line
        end
        default: begin
            aeff = buf_addr;
            hdf  = flip ? ~hdfix+FLIP_OFFSET : hdfix;
        end
    endcase
end

// For HJUMP==0, it is common that the readout counter wraps around a bit before
// horizontal blank. That may read pixel data written to the start of the blank
// region instead of continuing the regular count. An example of this is
// scontra's final game boss. As it appears from the top (left unrotated) side
// of the screen, part of it is visible at the bottom (right).
// Instead of configuring this per game using macros, I have opted for detecting
// the situation generally and fixing it. The readout count will keep increasing
// until HS is hit.
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hdfix <= 0;
    end else if(pxl_cen) begin
        hdfix <= ( hdump > hdfix || hs ) ? hdump+9'd1 : hdfix+9'd1;
    end
end

jtfround_draw #(
    .CW      ( CW       ),
    .PW      ( PW       ),
    .SWAPH   ( SWAPH    ),
    .KEEP_OLD( KEEP_OLD )
)u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .draw       ( dr_draw   ),
    .busy       ( busy      ),
    .code       ( dr_code   ),
    .xpos       ( dr_xpos   ),
    .hsize      ( dr_hsize  ),
    .hflip      ( dr_hflip  ),
    .pal        ( dr_pal    ),
    .rom_addr   ( rom_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    .buf_addr   ( buf_addr  ),
    .buf_we     ( buf_we    ),
    .buf_din    ( buf_din   )
);

jtframe_obj_buffer #(
    .DW         ( PW          ),
    .ALPHA      ( ALPHA       ),
    .KEEP_OLD   ( KEEP_OLD    )
) u_linebuf(
    .clk        ( clk       ),
    .flip       ( 1'b0      ),      // flip is solved before this instance
    .LHBL       ( ~hs       ),
    // New line writting
    .we         ( buf_we    ),
    .wr_data    ( buf_din   ),
    .wr_addr    ( aeff      ),
    // Previous line reading
    .rd         ( pxl_cen   ),
    .rd_addr    ( hdf       ),
    .rd_data    ( pxl       )
);

endmodule