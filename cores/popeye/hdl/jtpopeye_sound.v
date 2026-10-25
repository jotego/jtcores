/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_sound(
    input            rst,
    input            clk,
    input            psg_cen,
    input            reset_n,

    input            bdir,
    input            bc1,
    input      [7:0] din,
    output     [7:0] dout,

    input      [3:0] sw1,
    input      [7:0] sw2,
    input      [1:0] cpyr,
    output reg       rv,

    output     [9:0] psga,
    output     [9:0] psgb,
    output     [9:0] psgc
);

wire [7:0] ioa_out, iob_out, ioa_pu, iob, a, b, c, ay_a, ay_b, ay_c, mave_a, mave_b, mave_c;
wire [2:0] sel;
wire       ioa_oe, iob_oe, rst_n, y;
reg  [7:0] ioa;

assign rst_n  = ~rst & reset_n;
assign iob    = iob_oe ? iob_out : 8'hff;
assign ioa_pu = ioa_oe ? ioa_out : 8'hff;
assign sel    = iob[3:1];
assign y      = sw2[sel];
assign psga   = { 2'd0, a };
assign psgb   = { 2'd0, b };
assign psgc   = { 2'd0, c };

always @(posedge clk) begin
    if( !rst_n ) begin
        ioa <= 8'hff;
        rv  <= 1;
    end else begin
        ioa <= {y,cpyr,1'b1,sw1} & ioa_pu;
        rv  <= iob[0];
    end
end

`ifndef NOSOUND
assign a = mave_a;
assign b = mave_b;
assign c = mave_c;
`else
assign a = 0;
assign b = 0;
assign c = 0;
`endif

jt49_bus u_psg(
    .rst_n      ( rst_n     ),
    .clk        ( clk       ),
    .clk_en     ( psg_cen   ),
    .bdir       ( bdir      ),
    .bc1        ( bc1       ),
    .din        ( din       ),
    .sel        ( 1'b1      ),
    .dout       ( dout      ),
    .sound      (           ),
    .A          ( ay_a      ),
    .B          ( ay_b      ),
    .C          ( ay_c      ),
    .sample     (           ),
    .IOA_in     ( ioa       ),
    .IOA_out    ( ioa_out   ),
    .IOA_oe     ( ioa_oe    ),
    .IOB_in     ( iob       ),
    .IOB_out    ( iob_out   ),
    .IOB_oe     ( iob_oe    )
);

// The AY bus stays alive in NOSOUND: its I/O ports select DIPs and flip.
`ifndef NOSOUND
jt49_mave #(.depth(4)) u_mave_a(
    .clk        ( clk       ),
    .cen        ( psg_cen   ),
    .rst        ( rst       ),
    .din        ( ay_a      ),
    .dout       ( mave_a    )
);

jt49_mave #(.depth(4)) u_mave_b(
    .clk        ( clk       ),
    .cen        ( psg_cen   ),
    .rst        ( rst       ),
    .din        ( ay_b      ),
    .dout       ( mave_b    )
);

jt49_mave #(.depth(4)) u_mave_c(
    .clk        ( clk       ),
    .cen        ( psg_cen   ),
    .rst        ( rst       ),
    .din        ( ay_c      ),
    .dout       ( mave_c    )
);

`endif

endmodule
