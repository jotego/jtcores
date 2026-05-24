/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jttest85_game(
    `include "jtframe_game_ports.inc"
);

assign snd         = 16'd0;
assign sample      = 1'b0;
assign dip_flip    = 1'b0;
assign debug_view  = cache_status;

wire [7:0] cache_status;

jttest85_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen6          ),

    .cache_data ( cpu_data      ),
    .cache_ok   ( cpu_ok        ),
    .cache_flushing   ( cpu_flushing   ),
    .cache_flush_done ( cpu_flush_done ),
    .cache_addr ( cpu_addr      ),
    .cache_din  ( cpu_din       ),
    .cache_rd   ( cpu_rd        ),
    .cache_we   ( cpu_we        ),
    .cache_flush( cpu_flush     ),
    .cache_dsn  ( cpu_dsn       ),
    .cache_status( cache_status ),

    .text_addr  ( text_addr     ),
    .text_din   ( text_din      ),
    .text_dout  ( text_dout     ),
    .text_we    ( text_we       )
);

jttest85_video u_video(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .pxl_cen    ( pxl_cen         ),

    .text_vaddr ( text_vaddr ),
    .text_vdata ( text_vdata ),

    .LHBL       ( LHBL            ),
    .LVBL       ( LVBL            ),
    .HS         ( HS              ),
    .VS         ( VS              ),
    .red        ( red             ),
    .green      ( green           ),
    .blue       ( blue            )
);

/* verilator lint_on UNUSED */

endmodule
