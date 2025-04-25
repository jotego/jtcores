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
    Date: 9-4-2025 */

module jtthundr_obj(
    input             rst,
    input             clk, pxl_cen, hs, lvbl,
                      flip, dmaon,
    input      [ 8:0] hdump, vdump,

    // MMR
    input             mmr_cs,
    input       [1:0] cpu_addr,
    input             cpu_rnw,
    input       [7:0] cpu_dout,
    // Look-up table
    output     [12:1] ram_addr,
    input      [15:0] ram_dout,
    output     [15:0] ram_din,
    output     [ 1:0] ram_we,

    output            rom_cs,
    output     [19:2] rom_addr,
    input      [31:0] rom_data,   // upper byte not used
    input             rom_ok,

    output     [ 2:0] pxl_prio,
    output     [10:0] pxl,

    // IOCTL dump
    input      [1:0] ioctl_addr,
    output     [7:0] ioctl_din,
    // Debug
    input      [7:0] debug_bus,
    output     [7:0] st_dout
);

wire [31:0] sorted;
wire [17:2] raw_addr;
wire [12:1] dma_addr, scan_addr;
wire        dma_busy, hflip, vflip, draw, dr_busy, dr_draw;
wire [10:0] code;
wire [ 8:0] xoffset, hpos;
wire [ 7:0] yoffset;
wire [ 6:0] pal;
wire [ 4:0] ysub;
wire [ 2:0] prio;
wire [ 1:0] vsize, hsize, trunc, hmsb;
reg         blankn;

assign rom_addr = { raw_addr[17:7],
    ysub[4],       // V16
    hmsb[1],       // H16
    ysub[3],       // V8 (unaffected by vflip)
    raw_addr[4:2], // V4~V1
    hsize[0] ? hmsb[0] : raw_addr[6] /* H8 */};
assign ram_addr = dma_busy ? dma_addr : scan_addr;
assign sorted   = {
    rom_data[27], rom_data[31], rom_data[19], rom_data[23], rom_data[11], rom_data[15], rom_data[3], rom_data[7],
    rom_data[26], rom_data[30], rom_data[18], rom_data[22], rom_data[10], rom_data[14], rom_data[2], rom_data[6],
    rom_data[25], rom_data[29], rom_data[17], rom_data[21], rom_data[ 9], rom_data[13], rom_data[1], rom_data[5],
    rom_data[24], rom_data[28], rom_data[16], rom_data[20], rom_data[ 8], rom_data[12], rom_data[0], rom_data[4]
};

always @(posedge clk) blankn <= !(vdump>9'hf8 && vdump<9'h11d);

jtthundr_obj_mmr #(.SIMFILE("ommr.bin")) u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cs         ( mmr_cs    ),
    .addr       ( cpu_addr  ),
    .rnw        ( cpu_rnw   ),
    .din        ( cpu_dout  ),
    .dout       (           ),

    .xoffset    ( xoffset   ),
    .yoffset    ( yoffset   ),

    // IOCTL dump
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),
    // Debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

jtthundr_objdma u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .lvbl       ( lvbl      ),
    .copy       ( dmaon     ),
    .busy       ( dma_busy  ),

    .ram_we     ( ram_we    ),
    .ram_addr   ( dma_addr  ),
    .ram_dout   ( ram_dout  ),
    .ram_din    ( ram_din   )
);

jtthundr_objscan u_scan(
    .clk        ( clk       ),
    .hs         ( hs        ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),
    .vrender    ( vdump     ),
    .xoffset    ( xoffset   ),
    .yoffset    ( yoffset   ),

    .code       ( code      ),
    .hsize      ( hsize     ),
    .vsize      ( vsize     ),
    .ysub       ( ysub      ),
    .pal        ( pal       ),
    .hpos       ( hpos      ),
    .prio       ( prio      ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .trunc      ( trunc     ),
    .hmsb       ( hmsb      ),

    // Look-up table
    .ram_addr   ( scan_addr ),
    .ram_dout   ( ram_dout  ),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   ),

    .debug_bus  ( debug_bus )
);

wire [13:0] buf_loop;

jtframe_objdraw_gate #(.CW(11),.PW(11+3),.LATCH(1),.HFIX(0),.ALPHA(15)) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),

    .draw       ( dr_draw   ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( hpos      ),
    .ysub       ( ysub[3:0] ),
    .trunc      ( trunc     ),
    // optional zoom, keep at zero for no zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ),

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( {prio,pal}),

    .buf_pred   ( buf_loop  ),
    .buf_din    ( buf_loop  ),

    .rom_addr   ( raw_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( sorted    ),

    .pxl        ( {pxl_prio,pxl} )
);

endmodule