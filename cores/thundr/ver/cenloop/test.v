module test;

`include "test_tasks.vh"

reg  busy=0;
wire rst, clk, cen_main, cen_sub, cen_mcu, mcu_seln, lhbl, lvbl;
wire [15:0] fave, fworst;
reg [1:0] sel_sh;

always @(posedge clk) begin
    sel_sh <= {sel_sh[0],mcu_seln};
    assert_msg( {sel_sh,mcu_seln}!=3'b010,"isolated mcu_seln pulse" );
end

always @* begin
    assert_msg( ~(mcu_seln & cen_mcu),"bus selection wrong" );
    assert_msg( ~(cen_main & cen_mcu),"main and mcu cannot be on at the same time" );
end

initial begin
    @(negedge lvbl);
    repeat(100) begin
        @(negedge lhbl);
        busy = 1;
        repeat($random()%40) @(posedge clk);
        busy = 0;
    end
    @(negedge lvbl);
    assert_msg(fave==16'h1536,"wrong average frequency");
    pass();
end


jtthundr_cenloop uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .busy       ( {1'b0,busy}   ),
    .cen_main   ( cen_main      ),
    .cen_sub    ( cen_sub       ),
    .cen_mcu    ( cen_mcu       ),
    .mcu_seln   ( mcu_seln      ),
    .fave       ( fave          ),
    .fworst     ( fworst        )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .lvbl       ( lvbl          ),
    .lhbl       ( lhbl          )
);

endmodule // test