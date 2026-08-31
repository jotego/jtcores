/* SPDX-License-Identifier: GPL-3.0-or-later */

// K053251 boundary; donor wiring is validated against GX151 evidence.
module jtmoomsa_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             cpu_cs,
    input       [3:0] cpu_addr,
    input       [5:0] cpu_din,
    input             sel,
    input       [5:0] pri0, pri1, pri2,
    input       [8:0] ci0, ci1, ci2,
    input       [7:0] ci3, ci4,
    input       [1:0] shd_in,
    output      [10:0] palette_index,
    output      [2:0]  winner,
    output            bright,
    output            color_valid_n,
    output      [1:0] shadow,
    output      [7:0] ioctl_din
);

jtcolmix_053251 u_k053251(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .pxl_cen    ( pxl_cen         ),
    .cs         ( cpu_cs          ),
    .addr       ( cpu_addr        ),
    .din        ( cpu_din         ),
    .sel        ( sel             ),
    .pri0       ( pri0            ),
    .pri1       ( pri1            ),
    .pri2       ( pri2            ),
    .ci0        ( ci0             ),
    .ci1        ( ci1             ),
    .ci2        ( ci2             ),
    .ci3        ( ci3             ),
    .ci4        ( ci4             ),
    .shd_in     ( shd_in          ),
    .shd_out    ( shadow          ),
    .ioctl_addr ( 4'd0            ),
    .ioctl_din  ( ioctl_din      ),
    .cout       ( palette_index   ),
    .winner     ( winner          ),
    .brit       ( bright          ),
    .col_n      ( color_valid_n   )
);

endmodule
