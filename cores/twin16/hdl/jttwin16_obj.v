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
    Date: 28-8-2023 */

module jttwin16_obj(
    input             rst,
    input             clk,
    input             pxl_cen,

    // Base Video
    input             lhbl,
    input             lvbl,
    input             hs,
    input             vs,

    input      [ 8:0] vdump,
    input      [ 8:0] hdump,
    input      [15:0] obj_dx, obj_dy,
    input             vflip,

    // Object RAM
    output     [13:1] oram_addr,
    input      [15:0] oram_dout,
    output     [15:0] oram_din,
    output            oram_we,

    input             dma_on,
    output            dma_bsy,

    // ROM addressing
    output reg [21:2] rom_addr, // code + 1 bit. VH mostly embedded in core
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,

    input      [ 7:0] debug_bus,
    output     [ 7:0] pxl
);

localparam CW=19;

wire [CW-1:0] code; // lower 4 bits for H/V
wire [ 3:0] attr;
wire [ 1:0] hsize;
wire        hflip;
wire [15:0] hpos;
wire [21:2] lin_addr;
wire        dr_start, dr_busy;

always @* begin
    rom_addr = lin_addr;
    casez( lin_addr[20:19] )
        2'b0?: rom_addr[21:20]=0;
        2'b10: rom_addr[21:19]={2'b01,lin_addr[21]};
        2'b11: rom_addr[21:18]={4'b1001}+{3'd0,lin_addr[18]};
    endcase
end

jt00778x #(.CW(CW),.PW(16)) u_scan(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    // input             cs,
    // input             cpu_we,
    // input      [ 7:0] cpu_dout,
    // input      [10:0] cpu_addr,
    // output     [ 7:0] cpu_din,
    .obj_dx         ( obj_dx        ),
    .obj_dy         ( obj_dy        ),
    .gvflip         ( vflip         ),

    // ROM addressing
    .code           ( code          ),
    .attr           ( attr          ),
    .hflip          ( hflip         ),
    .hpos           ( hpos          ),
    .hsize          ( hsize         ),

    // DMA memory
    .oram_addr      ( oram_addr     ),
    .oram_dout      ( oram_dout     ),
    .oram_din       ( oram_din      ),
    .oram_we        ( oram_we       ),
    // control
    .dma_on         ( dma_on | debug_bus[7]        ),
    .dma_bsy        ( dma_bsy       ),
    .vdump          ( vdump         ),

    .vs             ( vs            ),
    .lvbl           ( lvbl          ),
    .hs             ( hs            ),
    // output            flip,

    // draw module
    .dr_start       ( dr_start      ),
    .dr_busy        ( dr_busy       ),

    .debug_bus      ( debug_bus     )
    // output reg [ 7:0] st_dout
);

jtfround_objdraw #(
    .CW(CW),.LATCH(1),.SWAPH(1),.FLIP_OFFSET(9'h12)
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),
    .flip       ( 1'b0      ),
    .hdump      ( hdump     ),

    .draw       ( dr_start  ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( hpos[8:0] ),

    .hflip      ( ~hflip    ),
    .hsize      ( hsize     ),
    .pal        ( attr      ),

    .rom_addr   ( lin_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    .pxl        ( pxl       )
);

endmodule