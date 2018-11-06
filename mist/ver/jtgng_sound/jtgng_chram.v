// RAM for simulation only

module jtgng_chram (
    input           clock,
    input   [10:0]  address,
    input   [ 7:0]  data,
    input           wren,
    output  [ 7:0]  q
);

reg [10:0] adr;
reg [7:0] memory[0:2047];

always @(posedge clock)
    adr <= address;

always @(*) begin
    if( wren ) begin
        memory[adr] = data;
        q = 8'd0;
    end
    else begin
        q = memory[adr];
    end
end


endmodule // jtgng_chram