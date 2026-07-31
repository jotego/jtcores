`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

reg clk, rst;
reg        ioctl_savegame, ioctl_wr;
reg [25:0] ioctl_addr;
reg [ 7:0] ioctl_dout;
reg        sav_change;
reg [15:0] sav_din;

wire [15:0] sav_addr, sav_dout;
wire [ 1:0] sav_wr;
wire        sav_ack, flush_ack, save_size_valid;
wire [16:0] save_size;

reg [31:2] sys_addr;
reg         sys_rd, sys_wr;
reg [31:0]  sys_dout;
wire [31:0] sys_din;
wire         rst_req_n;

jtframe_pocket_cartsave uut(
    .clk             ( clk             ),
    .rst             ( rst             ),
    .ioctl_savegame  ( ioctl_savegame  ),
    .ioctl_addr      ( ioctl_addr      ),
    .ioctl_dout      ( ioctl_dout      ),
    .ioctl_wr        ( ioctl_wr        ),
    .sav_change      ( sav_change      ),
    .sav_din         ( sav_din         ),
    .flush_ack       ( flush_ack       ),
    .sav_addr        ( sav_addr        ),
    .sav_dout        ( sav_dout        ),
    .sav_wr          ( sav_wr          ),
    .sav_ack         ( sav_ack         ),
    .save_size       ( save_size       ),
    .save_size_valid ( save_size_valid )
);

jtframe_pocket_cmd #(.IDX_NVRAM(2),.IDX_SAVEGAME(3)) cmd(
    .clk             ( clk             ),
    .rst_req_n       ( rst_req_n       ),
    .save_size_valid ( save_size_valid ),
    .save_size       ( save_size       ),
    .save_flush_ack  ( flush_ack       ),
    .sys_addr        ( sys_addr        ),
    .sys_rd          ( sys_rd          ),
    .sys_din         ( sys_din         ),
    .ioctl_din32     ( 32'd0           ),
    .sys_wr          ( sys_wr          ),
    .sys_dout        ( sys_dout        ),
    .dipsw           ( 32'd0           ),
    .status          ( 64'd0           ),
    .down_index      (                 ),
    .ds_done         (                 ),
    .inmenu          (                 )
);

always #5 clk = ~clk;

task read_reg;
    input [31:0] address;
    begin
        sys_addr = address[31:2];
        sys_rd   = 1;
        @(posedge clk);
        #1 sys_rd = 0;
    end
endtask

task write_reg;
    input [31:0] address;
    input [31:0] data;
    begin
        sys_addr = address[31:2];
        sys_dout = data;
        sys_wr   = 1;
        @(posedge clk);
        #1 sys_wr = 0;
    end
endtask

task check;
    input condition;
    input [255:0] message;
    begin
        if(!condition) begin
            $display("FAIL: %0s", message);
            $finish;
        end
    end
endtask

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    clk = 0;
    rst = 1;
    ioctl_savegame = 0;
    ioctl_wr = 0;
    ioctl_addr = 0;
    ioctl_dout = 0;
    sav_change = 0;
    sav_din = 0;
    sys_addr = 0;
    sys_rd = 0;
    sys_wr = 0;
    sys_dout = 0;

    repeat(2) @(posedge clk);
    rst = 0;

    // APF keeps each data-slot table entry independently writable. Seed the
    // existing NVRAM entry to make sure the game-save update cannot replace it.
    write_reg(32'hf8002014,32'd12356);

    // Pocket writes a slot byte at each address. The adapter keeps the
    // existing save protocol's byte order and byte enables intact.
    ioctl_savegame = 1;
    ioctl_wr = 1;
    ioctl_addr = 26'h00101;
    ioctl_dout = 8'ha5;
    #1;
    check(sav_addr==16'h0101, "slot byte address was truncated incorrectly");
    check(sav_dout==16'ha5a5 && sav_wr==2'b10, "odd slot byte lane is wrong");
    check(sav_ack, "slot write was not acknowledged");
    ioctl_savegame = 0;
    ioctl_wr = 0;

    // Compact image: header plus changed blocks 2 through 5 = 5 * 256 B.
    sav_change = 1;
    @(posedge clk);
    #1 check(sav_addr==0, "header maximum address was not requested");
    sav_din = 16'h0005;
    @(posedge clk);
    #1 check(sav_addr==2, "header minimum address was not requested");
    sav_din = 16'h0002;
    @(posedge clk);
    #1 check(save_size_valid && save_size==17'd1280, "compact save size is wrong");
    @(posedge clk); // command FSM latches the size and posts the flush command

    read_reg(32'hf8001000);
    #1 check(sys_din=={"cm",16'h0188}, "flush target command was not posted");
    read_reg(32'hf800201c);
    #1 check(sys_din==32'd1280, "runtime save size was not published in table");
    read_reg(32'hf8002014);
    #1 check(sys_din==32'd12356, "game-save table update changed NVRAM slot 2");

    // Pocket completes the flush. The adapter forwards the acknowledgement to
    // the flash core only after the successful target-command response.
    write_reg(32'hf8001000,{"ok",16'd0});
    #1 check(flush_ack && sav_ack, "successful flush did not acknowledge save core");
    @(posedge clk);
    sav_change = 0;
    @(posedge clk);

    // More than 254 changed blocks cannot be represented by the inherited
    // 16-bit save address. Clamp the advertised slot size to its safe maximum.
    sav_change = 1;
    @(posedge clk); sav_din = 16'h012c;
    @(posedge clk); sav_din = 16'h0000;
    @(posedge clk);
    #1 check(save_size==17'h0ff00, "oversize changed range was not clamped");

    // A failed APF flush must leave the save pending. Only a later successful
    // completion may acknowledge the flash core and clear sav_change.
    @(posedge clk);
    write_reg(32'hf8001000,{"ok",16'd1});
    #1 check(!flush_ack && !sav_ack, "failed flush acknowledged the save core");
    read_reg(32'hf8001000);
    #1 check(sys_din=={"cm",16'h0188}, "failed flush was not retried");
    write_reg(32'hf8001000,{"ok",16'd0});
    #1 check(flush_ack && sav_ack, "retry did not acknowledge the save core");

    pass();
end

endmodule
