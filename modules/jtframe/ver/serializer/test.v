module test;

`include "test_tasks.vh"

localparam DW=8;

reg clk, rst;

reg  [   7:0] cen_cnt=1;
wire [DW-1:0] data_in;
wire [DW-1:0] data_out;
reg        load;
wire       sd, valid, sclk, cen, done;
integer    value=0;


initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    #2000000
    $display("FAIL");
    $finish;
end


initial begin
    clk=0;
    forever #10 clk=~clk;
end

always @(posedge clk) cen_cnt <= {cen_cnt[0],cen_cnt[7:1]};

assign cen     = cen_cnt[0];
assign data_in = value[0+:DW];

initial begin
    rst    = 1;
    load   = 0;
    repeat (20) @(posedge clk);
    rst  = 0;
    repeat (20) @(posedge clk);
    repeat (100) begin
        value  = $random;
        // wait ( cen==1 && !sclk );
        wait ( done );
        repeat ($random%10) @(posedge clk);
        @(posedge clk);
        load    = 1;
        wait( done==0 ) @(posedge clk);
        load    = 0;
        repeat ($random%10) @(posedge clk);
        wait ( valid );
        assert_msg(data_in == data_out,"Serialized output does not match expected input");
    end
    repeat (10) @(posedge clk);
    pass();
end

jtframe_serializer#(.DW(DW)) uut (
    .clk       ( clk      ),
    .rst       ( rst      ),
    .cen       ( cen      ),
    .din       ( data_in  ),
    .load      ( load     ),
    .done      ( done     ),
    .sdout     ( sd       ),
    .sclk      ( sclk     )
);

ps2_intf_v uut_s (
    .CLK      ( clk      ),
    .nRESET   ( ~rst     ),
    .PS2_CLK  ( sclk     ),
    .PS2_DATA ( sd       ),
    .DATA     ( data_out ),
    .VALID    ( valid    ),
    .ERROR    (          )
);
endmodule