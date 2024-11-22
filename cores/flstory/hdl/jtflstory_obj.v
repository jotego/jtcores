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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-11-2024 */

module jtflstory_obj(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             lhbl,
    input             flip,

    input       [8:0] vrender,
    input       [8:0] hdump,
    // RAM shared with CPU
    output     [ 7:0] ram_addr,
    input      [ 7:0] ram_dout,
    // ROM
    output     [15:2] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,
    output     [ 7:0] pxl
);

reg  [9:0] code;
reg  [4:0] obj_cnt;
reg  [3:0] ysub,pal;
wire [7:0] ydiff;
reg  [7:0] vlatch;
reg  [1:0] obj_sub;
reg        lhbl_l, draw, scan_done, inzone;
wire       dr_busy;

assign ram_addr = lhbl ? {3'b110,hdump[7:3]} : {1'b0,obj_cnt,obj_sub};
assign ydiff    = vlatch+ram_dout;

always @(posedge clk) begin
    lhbl_l   <= lhbl;
    draw     <= 0;
    blank    <= vrender >= 9'h1f2 || vrender <= 9'h10e || !vrender[8];
    cen      <= ~cen;
    if(!scan_done && cen) begin
        if(!dr_busy) obj_sub <= obj_sub+2'd1;
        case(obj_sub)
            0: begin
                ysub   <= ydiff[3:0];
                inzone <= ydiff[7:4]==0;
            end
            1: {vflip,hflip,code[9:8],pal} <= ram_dout;
            2: code[7:0] <= ram_dout;
            3: begin
                xpos <= ram_dout;
                draw <= inzone;
                {scan_done,obj_cnt}<={1'b0,obj_cnt}+6'd1;
            end
        endcase
    end
    if( (!lhbl && lhbl_l) || blank ) begin
        vlatch    <= vrender;
        obj_cnt   <= 0;
        obj_sub   <= 0;
        scan_done <= 0;
        cen       <= 0;
    end
end

// original does not use a double line buffer. It buffers the data during
// HB instead. I'm using a double-line buffer to ease the implementation
jtframe_objdraw #(
    .CW(9),
    .PW(8),
    //SWAPH =  0,
    .HJUMP(0),
    .LATCH(1),
    .PACKED(1)
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),

    .draw       ( draw      ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( xpos      ),
    .ysub       ( ydiff     ),
    // optional zoom, keep at zero for no zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ), // set at 1 for the first tile

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),

    .rom_addr   ( rom_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    .pxl        ( pxl       )
);

endmodule