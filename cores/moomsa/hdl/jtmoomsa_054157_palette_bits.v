module jtmoomsa_054157_palette_bits(
    input      [7:2] attr,
    input      [1:0] fbits,
    output reg [3:0] pal
);

always @* begin
    case (fbits)
        2'd0: pal = attr[5:2];
        2'd1: pal = {attr[7:6],attr[3:2]};
        default: pal = attr[7:4];
    endcase
end

endmodule
