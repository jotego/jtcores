/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jttest85_main(
    input             rst,
    input             clk,
    input             cen,

    output     [ 9:0] text_addr,
    output     [ 7:0] text_din,
    input      [ 7:0] text_dout,
    output            text_we
);

wire        cpu_wr, cpu_rd, text_cs, rom_cs;
wire [15:0] cpu_addr;
wire [ 7:0] cpu_din, cpu_dout, rom_dout;

assign text_cs   = cpu_addr[15:10]==6'b001000;
assign rom_cs    = cpu_addr[15:14]==2'b11;
assign text_addr = cpu_addr[9:0];
assign text_din  = cpu_dout;
assign text_we   = cpu_wr & text_cs;
assign cpu_din   = text_cs ? text_dout :
                   rom_cs  ? rom_dout  : 8'hff;

jt65c02 u_cpu(
    .rst        ( rst      ),
    .clk        ( clk      ),
    .cen        ( cen      ),
    .irq        ( 1'b0     ),
    .nmi        ( 1'b0     ),
    .wr         ( cpu_wr   ),
    .rd         ( cpu_rd   ),
    .addr       ( cpu_addr ),
    .din        ( cpu_din  ),
    .dout       ( cpu_dout )
);

jtframe_ram #(
    .AW      ( 14         ),
    .DW      (  8         ),
    .SYNFILE ( "boot.hex" )
) u_boot_rom(
    .clk     ( clk             ),
    .cen     ( 1'b1            ),
    .data    ( 8'd0            ),
    .addr    ( cpu_addr[13:0]  ),
    .we      ( 1'b0            ),
    .q       ( rom_dout        )
);

wire unused = cpu_rd;

endmodule
