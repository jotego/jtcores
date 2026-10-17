/* SPDX-License-Identifier: GPL-3.0-or-later */
// Two synchronous read ports, one write port. Mirroring keeps both read
// muxes in block RAM. Architectural registers have no reset value; avoiding
// a reset on the array is essential for RAM inference. A15 and B15 alias SP.
module jttms10_regs(
    input             clk,
    input      [4:0]  rs, rd, wa,
    input             we,
    input      [31:0] wd,
    output reg [31:0] qs, qd
);
    reg [31:0] ram0 [0:31];
    reg [31:0] ram1 [0:31];
    wire [4:0] sa = rs[3:0]==4'hf ? 5'd15 : rs;
    wire [4:0] da = rd[3:0]==4'hf ? 5'd15 : rd;
    wire [4:0] wr = wa[3:0]==4'hf ? 5'd15 : wa;
    always @(posedge clk) begin
        qs <= ram0[sa];
        qd <= ram1[da];
        if(we) begin
            ram0[wr] <= wd;
            ram1[wr] <= wd;
        end
    end
endmodule
