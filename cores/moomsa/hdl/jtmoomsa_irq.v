/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_irq(
    input      enable_n,
    input      ipl0_n,
    input      int1_n,
    input      irq_n,
    output reg [2:0] ipl_n
);

always @* begin
    ipl_n = 3'b111;
    if (!enable_n) begin
        if (!ipl0_n) ipl_n = ~3'd3;
        if (!int1_n) ipl_n = ~3'd4;
        if (!irq_n)  ipl_n = ~3'd5;
    end
end

endmodule
