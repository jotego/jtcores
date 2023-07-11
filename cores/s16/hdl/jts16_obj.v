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
    Date: 12-3-2021 */

module jts16_obj(
    input              rst,
    input              clk,
    input              pxl_cen,   // pixel clock enable

    input              alt_bank,
    // CPU interface
    input              cpu_obj_cs,
    input      [10:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dswn,
    output     [15:0]  cpu_din,

    // SDRAM interface
    input              obj_ok,
    output             obj_cs,
    output     [20:1]  obj_addr, // 3(+1) bank + 15 offset = 18
    input      [15:0]  obj_data,

    // Video signal
    input              flip,
    input              hstart,
    input              hsn,
    input      [ 8:0]  vrender,
    input      [ 8:0]  hdump,
    output     [11:0]  pxl,
    input      [ 7:0]  debug_bus
);

/* verilator lint_off WIDTH */
parameter [8:0] PXL_DLY=8;
parameter       MODEL=0;  // 0 = S16A, 1 = S16B
/* verilator lint_on WIDTH */

// Object scan
wire [10:1] tbl_addr;
wire [15:0] tbl_din, tbl_dout;
wire        tbl_we;

// Draw commands
wire        dr_start;
wire        dr_busy;
wire [ 8:0] dr_xpos;
wire [15:0] dr_offset;  // MSB is also used as the flip bit
wire [ 3:0] dr_bank;
wire [ 1:0] dr_prio;
wire [ 5:0] dr_pal;
wire [ 4:0] dr_hzoom;
wire        dr_hflipb;

// Line buffer
wire [11:0] buf_data;
wire [ 8:0] buf_addr;
wire        buf_we;

jts16_obj_ram u_ram(
    .rst       ( rst            ),
    .clk       ( clk            ),
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
    .tbl_din   ( tbl_din        )
);

jts16_obj_scan #(.PXL_DLY(0),.MODEL(MODEL)) u_scan(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .alt_bank  ( alt_bank       ),

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
    .dr_pal    ( dr_pal         ),
    .dr_hflipb ( dr_hflipb      ),
    .dr_hzoom  ( dr_hzoom       ),

    // Video signal
    .flip      ( flip           ),
    .hstart    ( hstart         ),
    .vrender   ( vrender        )
);

jts16_obj_draw #(.MODEL(MODEL)) u_draw(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .hstart    ( hstart         ),

    // From scan
    .start     ( dr_start       ),
    .busy      ( dr_busy        ),
    .xpos      ( dr_xpos        ),
    .offset    ( dr_offset      ),
    //.bank      ( bank_aux       ),
    .bank      ( dr_bank        ),
    .prio      ( dr_prio        ),
    .pal       ( dr_pal         ),
    .hflipb    ( dr_hflipb      ),
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
localparam [8:0] FLIP_START = 9'hb0-HOBJ_START; //9'hc0-before

always @(posedge clk) begin
    if( !hsn ) hobj <= (flip ? (9'h1ff+FLIP_START) : HOBJ_START);// + {debug_bus[7], debug_bus};
    else if(pxl_cen) hobj<= flip ? hobj-1'd1 : hobj+1'd1;
end

jtframe_obj_buffer #(
    .DW     (   12    ),
    .AW     (    9    ),
    .ALPHA  (    0    )
) u_line(
    .clk        ( clk       ),
    .LHBL       ( hsn       ),
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