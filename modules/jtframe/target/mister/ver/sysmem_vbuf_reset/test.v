`timescale 1ns/1ps

module test;

reg clk=0;
reg reset_out=0, vbuf_user_reset=0;
reg vbuf_reset_0=1, vbuf_reset_1=1;
reg waitrequest_master=0;
reg [7:0] burstcount_slave=0;
reg [27:0] address_slave=0;
reg [127:0] writedata_slave=0;
reg [15:0] byteenable_slave=16'hFFFF;
reg write_slave=0, read_slave=0;
reg [127:0] readdata_master=0;
reg readdatavalid_master=0;
wire waitrequest_slave;
wire [7:0] burstcount_master;
wire [27:0] address_master;
wire [127:0] writedata_master;
wire [15:0] byteenable_master;
wire write_master, read_master;
integer accepted=0;

always #5 clk=~clk;

// Keep the production vbuf_reset_0/vbuf_reset_1 sequence under test.
always @(posedge clk) begin
    vbuf_reset_0 <= reset_out | vbuf_user_reset;
    vbuf_reset_1 <= vbuf_reset_0;
end

f2sdram_safe_terminator #(128,8) uut(
    .clk                  ( clk                  ),
    .rst_req_sync         ( vbuf_reset_1         ),
    .waitrequest_slave    ( waitrequest_slave    ),
    .burstcount_slave     ( burstcount_slave     ),
    .address_slave        ( address_slave        ),
    .readdata_slave       (                       ),
    .readdatavalid_slave  (                       ),
    .read_slave           ( read_slave            ),
    .writedata_slave      ( writedata_slave       ),
    .byteenable_slave     ( byteenable_slave      ),
    .write_slave          ( write_slave           ),
    .waitrequest_master   ( waitrequest_master    ),
    .burstcount_master    ( burstcount_master     ),
    .address_master       ( address_master        ),
    .readdata_master      ( readdata_master       ),
    .readdatavalid_master ( readdatavalid_master  ),
    .read_master          ( read_master           ),
    .writedata_master     ( writedata_master      ),
    .byteenable_master    ( byteenable_master     ),
    .write_master         ( write_master          )
);

always @(posedge clk) begin
    if(write_master && !waitrequest_master) begin
        if(address_master !== 28'h1234567 || burstcount_master !== 8'd4)
            $fatal(1,"terminator changed partial write address/count");
        if(writedata_master !== 128'h0123456789ABCDEFFEDCBA9876543210)
            $fatal(1,"terminator changed write data during reset drain");
        accepted <= accepted + 1;
    end
end

task tick;
begin @(posedge clk); #1; end
endtask

initial begin
    repeat(4) tick();
    if(vbuf_reset_1 !== 1'b0) $fatal(1,"initial terminator reset did not release");

    // Begin a four-beat write and let exactly its first beat be accepted.
    burstcount_slave=8'd4;
    address_slave=28'h1234567;
    writedata_slave=128'h0123456789ABCDEFFEDCBA9876543210;
    write_slave=1;
    tick();
    if(accepted!=1) $fatal(1,"test did not accept exactly one initial burst beat: %0d",accepted);

    // Stall the next beat and notify only the VBUF user reset. Global reset
    // remains low, proving this cannot feed reset_core_req/reset_out.
    @(negedge clk); waitrequest_master=1; vbuf_user_reset=1;
    repeat(3) tick();
    if(reset_out!==1'b0 || vbuf_reset_1!==1'b1)
        $fatal(1,"VBUF user reset did not reach the existing synchronized terminator input");
    if(accepted!=1) $fatal(1,"stalled partial burst unexpectedly advanced");

    // The source retains its Avalon request/data while reset is asserted.
    // The terminator must finish beats 2..4 on the original transaction.
    @(negedge clk); waitrequest_master=0;
    repeat(5) tick();
    if(accepted!=4) $fatal(1,"terminator did not finish remaining beats: accepted=%0d",accepted);
    if(!vbuf_reset_1) $fatal(1,"capture reset deasserted before the burst drain");

    @(negedge clk); write_slave=0; burstcount_slave=0;
    repeat(3) tick();
    if(accepted!=4 || write_master)
        $fatal(1,"terminator emitted a tail request after draining the burst");

    @(negedge clk); vbuf_user_reset=0;
    repeat(4) tick();
    if(vbuf_reset_1!==1'b0 || reset_out!==1'b0)
        $fatal(1,"VBUF-only reset did not release independently of global reset");
    if(accepted!=4) $fatal(1,"request appeared after reset release");
    $display("PASS");
    $finish;
end

initial begin #100000 $fatal(1,"timeout"); end

endmodule
