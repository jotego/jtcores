module ram_k051937_color(
    input      [ 7:0] a,
    input             clk,
    input      [11:0] din,
    input             we,
    output reg [11:0] dout
);

    reg [11:0] mem[0:127];

    always @(posedge clk) begin
        if(we) mem[a] <= din;
        dout <= mem[a];
    end

endmodule

module ram_k051937_shadow(
    input      [ 7:0] a,
    input             clk,
    input             din,
    input             we,
    output reg        dout
);

    reg [7:0] mem;

    always @(posedge clk) begin
        if(we) mem[a] <= din;
        dout <= mem[a];
    end

endmodule