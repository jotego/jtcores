module test;

`include "test_tasks.vh"

wire       rst, clk, lhbl, lvbl, pxl_cen;
wire [8:0] h,v;
reg  [2:0] color;
wire [3:0] r, g, b;
wire [7:0] din;
reg        hex_en, bin_en;
reg  [3:0] videoin;

assign din={4'd0,v[7:4]};

always @(posedge clk) begin
    if(pxl_cen) videoin = $random;
end

always @(posedge clk) begin
    if(!hex_en && !bin_en) begin
        assert_msg(r==videoin && g==videoin && b==videoin, "output should match input video when disabled" );
    end
end

initial begin
    color=7;
    hex_en=0;
    bin_en=0;
    @(negedge rst);
    repeat (200) begin
       @(negedge lhbl);
       color=$random;
    end
    hex_en=1;
    bin_en=1;
    @(negedge lvbl);

    $display("PASS");
    $finish;
end

jtframe_binhex_overlay uut(
    .clk        ( clk       ),
    .v          ( v         ),
    .h          ( h         ),
    .din        ( din       ),
    .hex_en     ( hex_en    ),
    .bin_en     ( bin_en    ),
    .color      ( color     ),
    .rin        ( videoin   ),
    .gin        ( videoin   ),
    .bin        ( videoin   ),
    .rout       ( r         ),
    .gout       ( g         ),
    .bout       ( b         )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),
    .pxl_cen    ( pxl_cen       ),
    .h          ( h             ),
    .v          ( v             )
);

endmodule