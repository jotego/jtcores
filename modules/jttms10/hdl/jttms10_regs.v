/* SPDX-License-Identifier: GPL-3.0-or-later */
// Two synchronous read ports, one write port. Mirroring keeps both read
// muxes in block RAM. Architectural registers have no reset value; avoiding
// a reset on the array is essential for RAM inference. A15 and B15 alias SP.
module jttms10_regs(
`ifdef JTTMS10_REGRESSION
    output            obs_rf_we,
    output     [ 5:0] obs_rf_addr,
    output     [31:0] obs_rf_data,
`endif
    input             clk,
    input      [4:0]  rs, rd, wa,
    input             rs_ext, rd_ext, wa_ext,
    input             we,
    input      [31:0] wd,
    output reg [31:0] qs, qd
);
    reg [31:0] ram0 [0:63];
    reg [31:0] ram1 [0:63];
    wire [5:0] sa = rs_ext ? {1'b1,rs} :
                    rs[3:0]==4'hf ? 6'd15 : {1'b0,rs};
    wire [5:0] da = rd_ext ? {1'b1,rd} :
                    rd[3:0]==4'hf ? 6'd15 : {1'b0,rd};
    wire [5:0] wr = wa_ext ? {1'b1,wa} :
                    wa[3:0]==4'hf ? 6'd15 : {1'b0,wa};
`ifdef JTTMS10_REGRESSION
    assign obs_rf_we   = we;
    assign obs_rf_addr = wr;
    assign obs_rf_data = wd;
`endif

    always @(posedge clk) begin
        qs <= ram0[sa];
        qd <= ram1[da];
        if(we) begin
            ram0[wr] <= wd;
            ram1[wr] <= wd;
        end
    end
endmodule
