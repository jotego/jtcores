/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

module jtgng_obj #(parameter
    OBJMAX      = 9'h180,
    OBJMAX_LINE = 5'd24,
    PXL_DLY     = 7,
    ROM_AW      = 16,
    LAYOUT      = 0,   // 0: GnG, Commando
                       // 1: 1943
                       // 2: GunSmoke
    PALW        = 2,
    PALETTE     = 0, // 1 if the palette PROM is used
    PALETTE1_SIMFILE = "", // only for simulation
    PALETTE0_SIMFILE = "", // only for simulation
    AVATAR_MAX  = 8  // only used if macro AVATARS is defined
) (
    input              rst,
    input              clk,
    input              cen6,    //  6 MHz
    // screen
    input              HINIT,
    input              LHBL,
    input              LVBL,
    input              LVBL_obj,
    input   [ 7:0]     V,
    input   [ 8:0]     H,
    input              flip,
    // Pause screen
    input              pause,
    output  [ 3:0]     avatar_idx,
    // shared bus
    output  [ 8:0]     AB,
    input   [ 7:0]     DB,
    input              OKOUT,
    output             bus_req,        // Request bus
    input              bus_ack,    // bus acknowledge
    output             blen,   // bus line counter enable
    // Palette PROM
    input              OBJON,
    input   [ 7:0]     prog_addr,
    input              prom_hi_we,
    input              prom_lo_we,
    input   [ 3:0]     prog_din,
    // SDRAM interface
    output  [ROM_AW-1:0] obj_addr,
    input   [15:0]     objrom_data,
    input              rom_ok,
    // pixel output
    output  [(PALETTE?7:5):0] obj_pxl
);

wire [8:0] pre_scan;
wire [7:0] ram_dout;

wire line, fill, line_obj_we;
wire [4:0] post_scan;
wire [7:0] VF;
wire [7:0] objbuf_data;

reg [4:0] objcnt;
reg [3:0] pxlcnt;

always @(posedge clk) if(cen6) begin
    if( HINIT )
        { objcnt, pxlcnt } <= {5'd8,4'd0};
    else
        if( objcnt != 5'd0 )  { objcnt, pxlcnt } <=  { objcnt, pxlcnt } + 1'd1;
end

// DMA to 6809 RAM memory to copy the sprite data
jtgng_objdma #(
    .OBJMAX     ( OBJMAX     ),
    .AVATAR_MAX ( AVATAR_MAX ))
 u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen6       ( cen6      ),    //  6 MHz
    // screen
    .LVBL       ( LVBL       ),
    .pause      ( pause      ),
    .avatar_idx ( avatar_idx ),
    // shared bus
    .AB         ( AB        ),
    .DB         ( DB        ),
    .OKOUT      ( OKOUT     ),
    .bus_req    ( bus_req   ),  // Request bus
    .bus_ack    ( bus_ack   ),  // bus acknowledge
    .blen       ( blen      ),  // bus line counter enable
    // output data
    .pre_scan   ( pre_scan  ),
    .ram_dout   ( ram_dout  )
);

// Parse sprite data per line
jtgng_objbuf #(
    .OBJMAX     ( OBJMAX     ),
    .OBJMAX_LINE( OBJMAX_LINE))
u_buf(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    // screen
    .HINIT          ( HINIT         ),
    .LVBL           ( LVBL_obj      ),
    .V              ( V             ),
    .VF             ( VF            ),
    .flip           ( flip          ),
    // sprite data scan
    .pre_scan       ( pre_scan      ),
    .ram_dout       ( ram_dout      ),
    // sprite data buffer
    .objbuf_data    ( objbuf_data   ),
    .objcnt         ( objcnt        ),
    .pxlcnt         ( pxlcnt        ),
    .line           ( line          )
);

wire [8:0] posx;
localparam PXLW = PALETTE ? 8 : 6;

wire [PALW-1:0] pospal;
wire [(PALETTE?7:3):0] new_pxl;

// draw the sprite
jtgng_objdraw #(
    .ROM_AW           ( ROM_AW            ),          
    .LAYOUT           ( LAYOUT            ),          
    .PALW             ( PALW              ),            
    .PALETTE          ( PALETTE           ),         
    .PALETTE1_SIMFILE ( PALETTE1_SIMFILE  ),
    .PALETTE0_SIMFILE ( PALETTE0_SIMFILE  ))
u_draw(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    .OBJON          ( OBJON         ),
    // screen
    .VF             ( VF            ),
    .pxlcnt         ( pxlcnt        ),
    .flip           ( flip          ),
    .pause          ( pause         ),
    // per-line sprite data
    .objcnt         ( objcnt        ),
    .objbuf_data    ( objbuf_data   ),
    // SDRAM interface
    .obj_addr       ( obj_addr      ),
    .objrom_data    ( objrom_data   ),
    // PROMs
    .prog_addr      ( prog_addr     ),
    .prom_hi_we     ( prom_hi_we    ),
    .prom_lo_we     ( prom_lo_we    ),
    .prog_din       ( prog_din      ),
    // pixel data
    .posx           ( posx          ),
    .pospal         ( pospal        ),
    .new_pxl        ( new_pxl       )
);

// line buffers for pixel data
// obj_dly is not object pixel delay with respect to background
// instead, it is the internal delay from previous stages
wire [PXLW-1:0] obj_pxl0;
wire [PXLW-1:0] pxl_data;
generate
    if( PALETTE==1 )
        assign pxl_data = new_pxl;
    else
        assign pxl_data = {pospal, new_pxl};
endgenerate

jtgng_objpxl #(.dw(PXLW),.obj_dly(5'h11),.palw(PALW)) u_pxlbuf(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    .DISPTM_b       ( 1'b0          ),
    // screen
    .LHBL           ( LHBL          ),
    .flip           ( flip          ),
    .objcnt         ( objcnt        ),
    .pxlcnt         ( pxlcnt        ),
    .posx           ( posx          ),
    .line           ( line          ),
    // pixel data
    .new_pxl        ( pxl_data      ),
    .obj_pxl        ( obj_pxl0      )
);

//always @(posedge clk) if(cen6) obj_pxl<=obj_pxl0;

// Delay pixel output in order to be aligned with the other layers
jtgng_sh #(.width(PXLW), .stages(PXL_DLY)) u_sh(
    .clk            ( clk           ),
    .clk_en         ( cen6          ),
    .din            ( obj_pxl0      ),
    .drop           ( obj_pxl       )
);

endmodule