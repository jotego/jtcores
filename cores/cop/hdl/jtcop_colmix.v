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
    Date: 24-9-2021 */

module jtcop_colmix(
    input              rst,
    input              clk,
    input              clk_cpu,
    input              pxl_cen,

    input              LHBL,
    input              LVBL,

    // Memory dump
    input      [10:0]  ioctl_addr,
    input              ioctl_ram,
    output     [ 7:0]  ioctl_din,
    // CPU interface
    input      [ 1:0]  pal_cs,
    input      [10:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dsn,
    output     [15:0]  cpu_din,

    input      [2:0]   prisel,

    // priority PROM
    input      [9:0]   prog_addr,
    input      [3:0]   prom_din,
    input              prom_we,

    input      [7:0]   ba0_pxl,
    input      [7:0]   ba1_pxl,
    input      [7:0]   ba2_pxl,
    input      [7:0]   obj_pxl, // called "MCOL" in the schematics

    output     [7:0]   red,
    output     [7:0]   green,
    output     [7:0]   blue,
    output             LVBL_dly,
    output             LHBL_dly,

    input      [ 3:0]  gfx_en,
    input      [ 7:0]  debug_bus
);

reg  [ 9:0] seladdr;
wire [ 1:0] selbus;
wire [15:0] pal_gr, cpu_gr;
wire [ 7:0] pal_b,  cpu_b;
wire [ 1:0] we_gr;
wire        ba0_blank, obj_blank, ba1_blank, ba2_blank;
wire        we_b;
reg  [ 9:0] pal_addr;

assign ba0_blank = ~|ba0_pxl[3:0] | ~gfx_en[0];
// for ba1_blank: only 2:0 used as 3 is another input to the PROM
assign ba1_blank = ~|ba1_pxl[2:0] | ~gfx_en[1];
assign ba2_blank = ~|ba2_pxl[3:0] | ~gfx_en[2];
assign obj_blank = ~|obj_pxl[3:0] | ~gfx_en[3];

assign we_gr   = ~dsn & {2{pal_cs[0]}};
assign we_b    = ~dsn[0] & pal_cs[1];
assign cpu_din = pal_cs[0] ? cpu_gr : {8'hff, cpu_b};

assign ioctl_din = ioctl_addr[7:0];  // RAM dump not supported (see jtmidres_colmix for support)

always @(posedge clk) begin
    seladdr <= { prisel,     // 9:7
               ba0_blank,    // 6
               obj_pxl[7],   // 5
               obj_blank,    // 4
               ba1_pxl[7],   // 3
               ba1_pxl[3],   // 2
               ba1_blank,    // 1
               ba2_blank     // 0
            };
    if( pxl_cen ) begin
        pal_addr[9:8] <= selbus;
        case( selbus )
            0: pal_addr[7:0] <= ba0_pxl;
            1: pal_addr[7:0] <= obj_pxl;
            2: pal_addr[7:0] <= ba1_pxl;
            3: pal_addr[7:0] <= ba2_pxl;
        endcase
    end
end

jtframe_blank #(.DLY(2),.DW(24)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( LHBL      ),
    .preLVBL    ( LVBL      ),
    .LHBL       ( LHBL_dly  ),
    .LVBL       ( LVBL_dly  ),
    .preLBL     (           ),
    .rgb_in     ( { pal_gr, pal_b    } ),
    .rgb_out    ( { green, red, blue } )
);

// Red - Green palette RAM
jtframe_dual_ram16 #(
    .AW        ( 10          ),
    .SIMFILE_LO("pal0_lo.bin"),
    .SIMFILE_HI("pal0_hi.bin")
) u_ram_gr(
    // CPU writes
    .clk0   ( clk_cpu   ),
    .addr0  ( cpu_addr  ),
    .data0  ( cpu_dout  ),
    .we0    ( we_gr     ),
    .q0     ( cpu_gr    ),

    // Video reads
    .clk1   ( clk       ),
    .addr1  ( pal_addr  ),
    .data1  (           ),
    .we1    ( 2'b0      )
    `ifndef GRAY
    ,.q1     ( pal_gr    )
    `endif
);

`ifdef GRAY
    assign pal_gr = {4{pal_addr[3:0]}};
    assign pal_b  = {2{pal_addr[3:0]}};
`endif

// Blue palette RAM
jtframe_dual_ram #(
    .AW     ( 10       ),
    .SIMFILE("pal1_lo.bin")
) u_ram_b(
    // CPU writes
    .clk0   ( clk_cpu   ),
    .addr0  ( cpu_addr  ),
    .data0  (cpu_dout[7:0]),
    .we0    ( we_b      ),
    .q0     ( cpu_b     ),

    // Video reads
    .clk1   ( clk       ),
    .addr1  ( pal_addr  ),
    .data1  (           ),
    .we1    ( 1'b0      )
    `ifndef GRAY
    ,.q1     ( pal_b     )
    `endif
);

jtframe_prom #(
    .AW     ( 10            ),
    .DW     ( 2             ),
    .SIMFILE("../../../../rom/robocop/mb7122e_a-2.17e")
) u_selbus(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prom_din[1:0] ),
    .rd_addr( seladdr       ),
    .wr_addr( prog_addr     ),
    .we     ( prom_we       ),
    .q      ( selbus        )
);

endmodule
