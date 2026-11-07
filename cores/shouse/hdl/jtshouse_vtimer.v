/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-3-2025 */

// See https://github.com/jotego/jtcores/issues/348
module jtshouse_vtimer(
    input             clk,
    input             pxl_cen,
    output     [ 8:0] vdump, vrender, vrender1, hdump,
    output            lhbl, lvbl, hs, vs
);

`include "vtimer.vh"

jtframe_vtimer #(
    .HCNT_START ( 9'h000    ),
    .HCNT_END   ( 9'h17F    ),
    .HB_START   ( HB_START  ), // 288 visible, 384 total (96 pxl=HB)
    .HB_END     ( HB_END    ), // Fixed layer is mapped for a counter that leaves blanking at $40
    .HS_START   ( HS_START  ), // HS starts 32 pixels after HB
    .HS_END     ( HS_END    ), // 32 pixel wide

    .V_START    ( V_START   ), // 224 visible, 40 blank, 264 total
    .VB_START   ( VB_START  ),
    .VB_END     ( VB_END    ),
    .VS_START   ( VS_START  ), // 8 lines wide, 8 lines after VB start
    .VS_END     ( VS_END    ), // 60.6 Hz according to MAME
    .VCNT_END   ( VCNT_END  )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ), // 16kHz
    .VS         ( vs        )
);

endmodule