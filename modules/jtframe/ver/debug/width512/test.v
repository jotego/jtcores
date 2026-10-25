`timescale 1ns/1ps
module test;
reg clk=0;
wire hex_en, bin_en;
reg [8:0] h=0;
reg [8:0] v=0;
wire [7:0] msg;
wire [2:0] color;
always #5 clk=~clk;
jtframe_debug_ctrl uut(
    .clk(clk), .pxl_cen(1'b1),
    .debug_bus(8'd0), .view_bin(8'ha5), .view_hex(8'h5a),
    .v(v), .h(h), .view_mode(2'd0), .split_binhex(1'b1),
    .hex_en(hex_en), .bin_en(bin_en), .color(color), .msg(msg)
);
initial begin
    $dumpfile("test.lxt"); $dumpvars(0,test);
    repeat(8) @(negedge clk);
    v=9'd432;
    // The binary overlay occupies the 64-pixel cell just left of centre.
    h = `JTFRAME_WIDTH == 512 ? 9'd224 : 9'd96;
    repeat(8) @(negedge clk);
    if(bin_en!==1'b1 || msg!==8'ha5) $fatal(1,"FAIL centred binary overlay");
    h=9'd496;
    repeat(8) @(negedge clk);
    if(bin_en!==1'b0) $fatal(1,"FAIL binary overlay wrapped to right edge");
    $display("PASS"); $finish;
end
initial begin #1000; $fatal(1,"FAIL timeout"); end
endmodule
