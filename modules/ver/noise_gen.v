// This module is meant to be used in simulation

module noise_gen(
    input        rst,
    input        clk,
    input        cen,
    output [7:0] noise
);

reg [16:0] bb;
assign noise = bb[7:0];

always @(posedge clk) begin : base_counter
    if( rst ) begin
        bb <= 17'hCAFE;
    end
    else if( cen ) begin
            bb[16:1]    <= bb[15:0];
            bb[0]       <= ~(bb[16]^bb[13]);
        end
end

endmodule // noise_gen