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
    Date: 4-7-2026 */

module jtgae1_sound(
    input              clk,
    input              rst,
    input              enable,

    input              cen_snd,
    input              cen_opl,

    input              snd_irq,
    input      [ 7:0]  snd_latch,

    output     [15:0]  rom_addr,
    output reg         rom_cs,
    input      [ 7:0]  rom_data,
    input              rom_ok,

    output     [ 7:0]  oki_din,
    input      [ 7:0]  oki_dout,
    output             oki_wrn,

    output signed [15:0] opl
);

`ifndef NOSOUND
wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout, opl_dout;
wire        cpu_rnw, firq_n, sound_rst, sound_rstn;
wire        oki_wr, opl_csn;
reg  [ 7:0] cpu_din;
reg         ram_cs, oki_reg_cs, opl_cs, latch_cs;
reg         oki_wr_l;

assign sound_rst  = rst | ~enable;
assign sound_rstn = ~sound_rst;
assign rom_addr   = A;
assign oki_wr     = oki_reg_cs & ~cpu_rnw;
assign oki_wrn    = ~(oki_wr & ~oki_wr_l);
assign oki_din    = cpu_dout;
assign opl_csn    = ~opl_cs;

always @* begin
    ram_cs     = 1'b0;
    oki_reg_cs = 1'b0;
    opl_cs     = 1'b0;
    latch_cs   = 1'b0;
    rom_cs     = 1'b0;

    if (enable) begin
        ram_cs     = A < 16'h0800;
        oki_reg_cs = A[15:8] == 8'h08;
        opl_cs     = A[15:8] == 8'h0a;
        latch_cs   = A[15:8] == 8'h0b;
        rom_cs     = A >= 16'h0c00;
    end
end

always @* begin
    cpu_din = rom_cs     ? rom_data  :
              ram_cs     ? ram_dout  :
              opl_cs     ? opl_dout  :
              oki_reg_cs ? oki_dout  :
              latch_cs   ? snd_latch : 8'hff;
end

always @(posedge clk) begin
    oki_wr_l <= oki_wr;
end

jtframe_ff u_firq (
    .clk     ( clk      ),
    .rst     ( sound_rst ),
    .cen     ( 1'b1     ),
    .din     ( 1'b1     ),
    .q       (          ),
    .qn      ( firq_n   ),
    .set     ( 1'b0     ),
    .clr     ( latch_cs ),
    .sigedge ( snd_irq  )
);

jtframe_sys6809 #(
    .RAM_AW ( 11 ),
    .CENDIV ( 0  )
) u_cpu (
    .rstn       ( sound_rstn ),
    .clk        ( clk        ),
    .cen        ( cen_snd    ),
    .cpu_cen    (            ),
    .VMA        (            ),

    .nIRQ       ( 1'b1       ),
    .nFIRQ      ( firq_n     ),
    .nNMI       ( 1'b1       ),
    .irq_ack    (            ),

    .bus_busy   ( 1'b0       ),

    .A          ( A          ),
    .RnW        ( cpu_rnw    ),
    .ram_cs     ( ram_cs     ),
    .rom_cs     ( rom_cs     ),
    .rom_ok     ( rom_ok     ),
    .ram_dout   ( ram_dout   ),
    .cpu_dout   ( cpu_dout   ),
    .cpu_din    ( cpu_din    )
);

jtopl2 u_opl (
    .rst    ( sound_rst  ),
    .clk    ( clk        ),
    .cen    ( cen_opl    ),
    .din    ( cpu_dout   ),
    .addr   ( A[0]       ),
    .cs_n   ( opl_csn    ),
    .wr_n   ( cpu_rnw    ),
    .dout   ( opl_dout   ),
    .irq_n  (            ),
    .snd    ( opl        ),
    .sample (            )
);

`else
assign rom_addr = 16'd0;
assign oki_din  = 8'd0;
assign oki_wrn  = 1'b1;
assign opl      = 16'sd0;

initial begin
    rom_cs = 1'b0;
end
`endif

endmodule
