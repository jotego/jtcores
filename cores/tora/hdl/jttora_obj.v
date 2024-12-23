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
    Date: 1-12-2022 */

module jttora_obj #(
    parameter
    VINV        =  1,
    DMA_DW      = 12,        // Data width of each DMA transfer
    DMA_AW      = 10,        // Data width of each DMA transfer
    ROM_AW      = 19
) (
    input               rst,
    input               clk,
    input               dma_cen,   // use same as original PCB
    input               pxl_cen,   // use same as original PCB
    // screen
    input               hs,
    input               LVBL,
    input   [ 8:0]      vdump,
    input   [ 8:0]      hdump,
    input               flip,
    // shared bus
    output [DMA_AW-1:0] AB,
    input  [DMA_DW-1:0] DB,
    input               OKOUT,
    output              bus_req,        // Request bus
    input               bus_ack,    // bus acknowledge
    output              blen,   // bus line counter enable
    // SDRAM interface
    output [ROM_AW-1:2] rom_addr,
    input  [      31:0] rom_data,
    input               rom_ok,
    output              rom_cs,
    // pixel output
    input         [7:0] debug_bus,
    output        [7:0] pxl
);

localparam OBJMAX='h280;

wire [DMA_AW-1:0] lut_addr;
wire [11:0] lut_data;

wire [11:0] dr_code;
wire [ 8:0] dr_xpos;
wire [ 3:0] dr_pal, dr_ysub;
wire        dr_busy, dr_hflip, dr_vflip, dr_start;

// DMA to 6809 RAM memory to copy the sprite data
jtgng_objdma #(
    .DW         ( DMA_DW     ),
    .AW         ( DMA_AW     ),
    .OBJMAX     ( OBJMAX     ))
 u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( dma_cen   ),
    // screen
    .LVBL       ( LVBL       ),
    // shared bus
    .AB         ( AB        ),
    .DB         ( DB        ),
    .OKOUT      ( OKOUT     ),
    .bus_req    ( bus_req   ),  // Request bus
    .bus_ack    ( bus_ack   ),  // bus acknowledge
    .blen       ( blen      ),  // bus line counter enable
    // output data
    .pre_scan   ( lut_addr  ),
    .dma_dout   ( lut_data  )
);

jttora_objdata #(.VINV(VINV)) u_objdata(
    .rst        ( rst       ),
    .clk        ( clk       ),
    // screen
    .vdump      ( vdump     ),
    .flip       ( flip      ),
    .hs         ( hs        ),
    // per-line sprite data
    .lut_addr   ( lut_addr  ),
    .lut_data   ( lut_data  ),
    // Draw data
    .dr_code    ( dr_code   ),
    .dr_hflip   ( dr_hflip  ),
    .dr_vflip   ( dr_vflip  ),
    .dr_pal     ( dr_pal    ),
    .dr_ysub    ( dr_ysub   ),
    .dr_xpos    ( dr_xpos   ),
    .dr_start   ( dr_start  ),
    .dr_busy    ( dr_busy   ),

    .debug_bus  ( debug_bus )
);

jtframe_objdraw#(.CW(ROM_AW-7),.ALPHA('hf),.LATCH(1),.SWAPH(1),.HJUMP(1)) u_draw (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump^9'h100     ),

    .code       (dr_code[0+:ROM_AW-7]),
    .xpos       ( dr_xpos   ),
    .ysub       ( dr_ysub   ),
    .hflip      ( dr_hflip  ),
    .vflip      ( dr_vflip  ),

    // No zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ),

    .pal        ( dr_pal    ),
    .draw       ( dr_start  ),
    .busy       ( dr_busy   ),

    .rom_addr   ( rom_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    .pxl        ( pxl       )
);

endmodule