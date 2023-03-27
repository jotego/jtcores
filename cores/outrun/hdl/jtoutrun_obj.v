/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 8-10-2021 */

module jtoutrun_obj(
    input              rst,
    input              clk,
    input              pxl_cen,   // pixel clock enable

    input              obj_swap,
    // CPU interface
    input              cpu_obj_cs,
    input      [10:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dswn,
    output     [15:0]  cpu_din,

    // SDRAM interface
    input              obj_ok,
    output             obj_cs,
    output     [19:2]  obj_addr,
    input      [31:0]  obj_data,

    // Line buffer
    output     [ 8:0]  buf_addr,
    output     [13:0]  buf_data,
    output             buf_we,
    output             ln_done,

    // Video signal
    input              flip,
    input              hstart,
    input              LHBL,
    input      [ 8:0]  vrender,
    input      [ 8:0]  hdump,
    output     [13:0]  pxl,

    // Debug
    input      [ 7:0]  st_addr,
    output     [ 7:0]  st_dout,
    input      [ 7:0]  debug_bus,
    input      [11:0]  ioctl_addr,
    output     [ 7:0]  ioctl_din
);

parameter [8:0] PXL_DLY=8;

// Object scan
wire [10:1] tbl_addr;
wire [15:0] tbl_din, tbl_dout;
wire        tbl_we;

// Draw commands
wire        dr_start;
wire        dr_busy;
wire [ 8:0] dr_xpos;
wire [15:0] dr_offset;  // MSB is also used as the flip bit
wire [ 2:0] dr_bank;
wire [ 1:0] dr_prio;
wire [ 6:0] dr_pal;
wire [ 9:0] dr_hzoom;
wire        dr_hflip, dr_backwd, dr_shadow;

jtoutrun_obj_ram u_ram(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .swap      ( obj_swap       ),
    // CPU interface
    .obj_cs    ( cpu_obj_cs     ),
    .cpu_addr  ( cpu_addr       ),
    .cpu_dout  ( cpu_dout       ),
    .dswn      ( dswn           ),
    .cpu_din   ( cpu_din        ),
    // Scan
    .tbl_addr  ( tbl_addr       ),
    .tbl_dout  ( tbl_dout       ),
    .tbl_we    ( tbl_we         ),
    .tbl_din   ( tbl_din        ),
    // SD dump
    .ioctl_addr( ioctl_addr     ),
    .ioctl_din ( ioctl_din      )
);

jtoutrun_obj_scan #(.PXL_DLY(0)) u_scan(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .ln_done   ( ln_done        ),

    // Obj table
    .tbl_addr  ( tbl_addr       ),
    .tbl_dout  ( tbl_dout       ),
    .tbl_we    ( tbl_we         ),
    .tbl_din   ( tbl_din        ),

    // Draw commands
    .dr_start  ( dr_start       ),
    .dr_busy   ( dr_busy        ),
    .dr_xpos   ( dr_xpos        ),
    .dr_offset ( dr_offset      ),
    .dr_bank   ( dr_bank        ),
    .dr_prio   ( dr_prio        ),
    .dr_shadow ( dr_shadow      ),
    .dr_pal    ( dr_pal         ),
    .dr_hflip  ( dr_hflip       ),
    .dr_backwd ( dr_backwd      ),
    .dr_hzoom  ( dr_hzoom       ),

    // Video signal
    .flip      ( flip           ),
    .hstart    ( hstart         ),
    .vrender   ( vrender        ),
    .st_addr   ( st_addr        ),
    .st_dout   ( st_dout        ),
    .debug_bus ( debug_bus      )
);

jtoutrun_obj_draw u_draw(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .hstart    ( hstart         ),

    // From scan
    .start     ( dr_start       ),
    .busy      ( dr_busy        ),
    .xpos      ( dr_xpos        ),
    .offset    ( dr_offset      ),
    .bank      ( dr_bank        ),
    .prio      ( dr_prio        ),
    .shadow    ( dr_shadow      ),
    .pal       ( dr_pal         ),
    .hflip     ( dr_hflip       ),
    .backwd    ( dr_backwd      ),
    .hzoom     ( dr_hzoom       ),

    // SDRAM interface
    .obj_ok    ( obj_ok         ),
    .obj_cs    ( obj_cs         ),
    .obj_addr  ( obj_addr       ),
    .obj_data  ( obj_data       ),

    // Buffer
    .bf_data   ( buf_data       ),
    .bf_we     ( buf_we         ),
    .bf_addr   ( buf_addr       ),
    .debug_bus ( debug_bus      )
);

reg [8:0] hobj;
localparam [8:0] HOBJ_START = 9'haa-PXL_DLY; //a6
localparam [8:0] FLIP_START = 9'hc0-HOBJ_START;

always @(posedge clk) begin
    if( !LHBL ) hobj <= (flip ? (9'h1ff+FLIP_START) : HOBJ_START); // + {debug_bus[7], debug_bus};
    else if(pxl_cen) hobj<= flip ? hobj-1'd1 : hobj+1'd1;
end

jtframe_obj_buffer #(
    .DW     (   14   ),
    .AW     (    9    ),
    .ALPHA  (    0    )
) u_line(
    .clk        ( clk       ),
    .LHBL       ( LHBL      ),
    .flip       ( 1'b0      ),
    // New data writes
    .wr_data    ( buf_data  ),
    .wr_addr    ( buf_addr  ),
    .we         ( buf_we    ),
    // Old data reads (and erases)
    .rd_addr    ( hobj      ),
    .rd         ( pxl_cen   ),
    .rd_data    ( pxl       )
);

endmodule