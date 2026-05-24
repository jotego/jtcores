/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jttest85_game(
    `include "jtframe_game_ports.inc"
);

/* verilator lint_off UNUSED */

assign snd         = 16'd0;
assign sample      = 1'b0;
assign dip_flip    = 1'b0;
assign debug_view  = { cpu_flushing, cpu_flush_done, cpu_ok, text_we, 4'd0 };

assign cpu_addr    = 24'd0;
assign cpu_rd      = 1'b0;
assign cpu_we      = 1'b0;
assign cpu_din     = 8'd0;
assign cpu_dsn     = 1'b0;
assign cpu_flush   = 1'b0;

jttest85_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen6          ),

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
