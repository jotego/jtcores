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
    Date: 30-7-2023 */

// See JTSIMSON's README.md

module jt053246(    // sprite logic
    input             rst,
    input             clk,
    input             pxl2_cen,
    input             pxl_cen,

    input             simson,   // enables temporary hack for The Simpsons
    // CPU interface
    input             cs,
    input             cpu_we,
    input      [ 3:0] cpu_addr, // bit 3 only in k44 mode
    input      [15:0] cpu_dout,
    input      [ 1:0] cpu_dsn,  // only used for MMR in 16-bit mode

    // ROM check by CPU
    output     [21:1] rmrd_addr,

    // External RAM
    output     [13:1] dma_addr, // up to 16 kB
    input      [15:0] dma_data,
    output            dma_bsy,

    // ROM addressing 22 bits in total
    output reg [15:0] code,
    // There are 22 bits communicating both chips on the PCB
    output reg [ 9:0] attr,     // OC pins
    output            hflip,
    output reg        vflip,
    output reg [ 9:0] hpos,
    output     [ 3:0] ysub,
    output reg [11:0] hzoom,
    output reg        hz_keep,

    // base video
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines
    input             vs,
    input             hs,

    // shadow
    input      [ 8:0] pxl,
    output reg [ 1:0] shd,

    // indr module / 051937
    output reg        dr_start,
    input             dr_busy,

    // Debug
    input      [ 7:0] debug_bus,
    input      [ 7:0] st_addr,
    output     [ 7:0] st_dout
);
parameter XMEN = 0;

localparam [2:0] REG_XOFF  = 0, // X offset
                 REG_YOFF  = 1, // Y offset
                 REG_CFG   = 2; // interrupt control, ROM read

wire [15:0] scan_even, scan_odd, dma_din;
wire [11:2] scan_addr;
wire [11:1] dma_wr_addr;
wire [ 9:0] xoffset, yoffset;
wire [ 7:0] cfg;
wire        dma_wel, dma_weh, cpu_bsy,
            ghf, gvf, mode8, dma_en, flicker;

assign ghf       = cfg[0]; // global flip
assign gvf       = cfg[1];
assign mode8     = cfg[2]; // guess, use it for 8-bit access on 46/47 pair
assign cpu_bsy   = cfg[3];
assign dma_en    = cfg[4];

jt053246_scan #(.XMEN(XMEN)) u_scan(
    .rst       ( rst        ),
    .clk       ( clk        ),
    .simson    ( simson     ),
    .code      ( code       ),
    .attr      ( attr       ),
    .hflip     ( hflip      ),
    .vflip     ( vflip      ),
    .hpos      ( hpos       ),
    .ysub      ( ysub       ),
    .hzoom     ( hzoom      ),
    .hz_keep   ( hz_keep    ),
    .hdump     ( hdump      ),
    .vdump     ( vdump      ),
    .hs        ( hs         ),
    .scan_even ( scan_even  ),
    .scan_odd  ( scan_odd   ),
    .xoffset   ( xoffset    ),
    .yoffset   ( yoffset    ),
    .ghf       ( ghf        ),
    .gvf       ( gvf        ),
    .scan_addr ( scan_addr  ),
    .shd       ( shd        ),
    .dr_start  ( dr_start   ),
    .dr_busy   ( dr_busy    ),
    .debug_bus ( debug_bus  )
);


jt053246_dma u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),

    .mode8      ( mode8     ),
    .dma_en     ( dma_en    ),
    .dma_trig   ( 1'b0      ),
    .k44_en     ( 1'b0      ),   // enable k053244/5 mode (default k053246/7)
    .simson     ( simson    ),

    .hs         ( hs        ),
    .vs         ( vs        ),

    // External RAM
    .dma_addr   ( dma_addr  ), // up to 16 kB
    .dma_data   ( dma_data  ),
    .dma_bsy    ( dma_bsy   ),

    .dma_weh    ( dma_weh   ),
    .dma_wel    ( dma_wel   ),
    .dma_wr_addr(dma_wr_addr),
    .dma_din    ( dma_din   ),

    .flicker    ( flicker   )  // debug
);

jt053246_mmr u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .k44_en     ( 1'b0      ),
    .cs         ( cs        ),
    .cpu_we     ( cpu_we    ),
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_dsn    ( cpu_dsn   ),
    .cfg        ( cfg       ),
    .xoffset    ( xoffset   ),
    .yoffset    ( yoffset   ),
    .rmrd_addr  ( rmrd_addr ),
    .st_addr    ( st_addr   ),
    .st_dout    ( st_dout   )
);

jtframe_dual_ram16 #(.AW(10)) u_even( // 10:0 -> 2kB
    // Port 0: DMA
    .clk0   ( clk            ),
    .data0  ( dma_din        ),
    .addr0  (dma_wr_addr[11:2]),
    .we0    ( {2{dma_wel}}   ),
    .q0     (                ),
    // Port 1: scan
    .clk1   ( clk            ),
    .data1  ( 16'd0          ),
    .addr1  ( scan_addr      ),
    .we1    ( 2'b0           ),
    .q1     ( scan_even      )
);

jtframe_dual_ram16 #(.AW(10)) u_odd( // 10:0 -> 2kB
    // Port 0: DMA
    .clk0   ( clk            ),
    .data0  ( dma_din        ),
    .addr0  (dma_wr_addr[11:2]),
    .we0    ( {2{dma_weh}}   ),
    .q0     (                ),
    // Port 1: scan
    .clk1   ( clk            ),
    .data1  ( 16'd0          ),
    .addr1  ( scan_addr      ),
    .we1    ( 2'b0           ),
    .q1     ( scan_odd       )
);

endmodule
