module ff_clr #(
    parameter WIDTH = 6
)(
    input clr_n,
    input clk,
    input [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

initial begin
    q <= {WIDTH{1'b0}};
end

always @(posedge clk or negedge clr_n) begin
    if (!clr_n) begin
        q <= {WIDTH{1'b0}};  // Asynchronously clear the output when clr_n is low
    end else begin
        q <= d;  // On clock's positive edge, capture data
    end
end

endmodule
