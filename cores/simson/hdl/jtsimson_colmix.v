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
    Date: 23-7-2023 */

// Color mixer compatible with K053251
// See Furrtek's files for RE information

module jtsimson_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,
    // CPU interface
    input             cpu_we,
    input      [11:0] cpu_addr,
    input       [7:0] cpu_dout,
    output      [7:0] cpu_din,

    // Final pixels
    input      [ 6:0] lyrf_pxl, lyra_pxl, lyrb_pxl,
    input      [ 9:0] lyro_pxl,
    input      [ 4:0] prio,
    input      [ 1:0] obj_shd,
    input             shadow,

    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,
    // Debug
    input      [11:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,

    input      [ 7:0] debug_bus
);

wire [10:0] pxl;
wire [11:0] pal_addr;
wire [ 1:0] shd_eff;

assign pal_addr = { pxl, pal_half };

always @(posedge clk) begin
    if( rst ) begin
        pal_half <= 0;
        bgr      <= 0;
        shl      <= 0;
    end else begin
`ifndef GRAY
        pxl_aux <= { pxl_aux[7:0], pal_dout };
`else
        pxl_aux <= {1'b0,{3{pxl[4:0]}}};
`endif
        if( pxl_cen ) begin
            shl <= shad;
            bgr <= dim(pxl_aux[14:0], shl);
            pal_half <= 0;
        end else
            pal_half <= ~pal_half;
    end
end

jtcolmix_053251 u_prio(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    // CPU interface
    .cs         ( cs        ),
    .addr       (cpu_addr[3:0]),
    .din        (cpu_dout[5:0]),
    // explicit priorities
    .sel        ( 1'b0      ),
    .pri0       ( 6'h3f     ),
    .pri1       ({prio,1'b0}),
    .pri2       ( 6'h3f     ),
    // color inputs
    .ci0        ( 9'd0      ),
    .ci1        ( lyro_pxl  ),
    .ci2        ({2'd0,lyrf_pxl}),
    .ci3        ({1'b0,lyra_pxl}),
    .ci4        ({1'b0,lyrb_pxl}),
    // shadow
    .shd_in     ( obj_shd   ),
    .shd_out    ( shd_eff   ),

    .cout       ( pxl       ),
    .brit       (           ),
    .col_n      (           )
);

jtframe_dual_nvram #(.AW(12),.SIMFILE("pal.bin")) u_ram(
    // Port 0: CPU
    .clk0   ( clk           ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr      ),
    .we0    ( cpu_we        ),
    .q0     ( cpu_din       ),
    // Port 1
    .clk1   ( clk           ),
    .data1  ( 8'd0          ),
    .addr1a ( pal_addr      ),
    .addr1b ( ioctl_addr    ),
    .sel_b  ( ioctl_ram     ),
    .we_b   ( 1'b0          ),
    .q1     ( pal_dout      )
);

endmodule