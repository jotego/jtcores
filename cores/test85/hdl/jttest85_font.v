/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jttest85_font(
    input             clk,
    input      [ 9:0] rom_addr,
    output     [ 7:0] rom_data
);

wire [ 6:0] ascii     = rom_addr[9:3];
wire [ 6:0] font_code = ascii < 7'h20 ? 7'd0 : ascii - 7'h20;
wire [ 9:0] font_addr = { font_code, rom_addr[2:0] };

jtframe_ram #(
    .AW      ( 10          ),
    .DW      (  8          ),
    .SYNFILE ( "font0.hex" )
) u_font(
    .clk     ( clk       ),
    .cen     ( 1'b1      ),
    .data    ( 8'd0      ),
    .addr    ( font_addr ),
    .we      ( 1'b0      ),
    .q       ( rom_data  )
);

endmodule
