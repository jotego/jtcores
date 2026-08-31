/* SPDX-License-Identifier: GPL-3.0-or-later */

// Board control word at 0x0DE000.  The direct byte-lane/readback contract is
// retained here; IRQ_SET is produced by the separate Q4 latch boundary.
module jtmoomsa_control2(
    input             clk,
    input             rst,
    input             cpu_cs,
    input             cpu_wr,
    input       [1:0] cpu_dsn,
    input      [15:0] cpu_din,
    output     [15:0] cpu_dout,
    output            irq5_en,
    output            irq4_en,
    output            objcha_n
);

reg [15:0] value;

assign cpu_dout = value;
assign irq5_en   = value[5];
assign irq4_en   = value[11];
assign objcha_n  = ~value[8];

always @(posedge clk) begin
    if (rst)
        value <= 16'h0000;
    else if (cpu_cs && cpu_wr) begin
        if (!cpu_dsn[1]) value[15:8] <= cpu_din[15:8];
        if (!cpu_dsn[0]) value[7:0]  <= cpu_din[7:0];
    end
end

endmodule
