// Author: Andrea Bogazzi
module jtseicro_watchdog(
    input      rst, clk, enable, vblank, service,
    output     reset
);

reg [3:0] count;
reg vblank_l;

assign reset = &count;

always @(posedge clk) begin
    vblank_l <= vblank;
    if(rst || service) count <= 0;
    else if(enable && vblank && !vblank_l) count <= count+4'd1;
end

endmodule
