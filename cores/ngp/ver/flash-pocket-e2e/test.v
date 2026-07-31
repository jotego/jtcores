`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

localparam [12:0] MIN_BLOCK = 13'd2;
localparam [12:0] MAX_BLOCK = 13'd3;
localparam integer IMAGE_BYTES = 3*256; // header plus two changed blocks

reg clk, rst, cart;
reg        ioctl_savegame, ioctl_wr;
reg [25:0] ioctl_addr;
reg [ 7:0] ioctl_dout;
reg        sav_change, flush_ack;

wire [15:0] sav_addr, sav_dout, sav_din;
wire [ 1:0] sav_wr;
wire        sav_ack, sav_wait, sav_done, save_size_valid;
wire [16:0] save_size;

wire [20:1] gs_addr;
wire [15:0] gs_din, gs_data;
wire [ 1:0] gs_dsn;
wire        gs_cs, gs_we;
wire [ 1:0] gs_we0;
reg  [15:0] check_din;
reg  [13:1] check_addr;
reg  [ 1:0] check_we;
wire [15:0] check_dout;

wire [20:1] cart_addr;
wire [15:0] cart_din, cpu_din;
wire [ 1:0] cart_dsn;
wire        cart_we, cart_cs, cpu_ok, rdy;

assign gs_we0 = gs_cs ? ~gs_dsn : 2'b00;

always #5 clk = ~clk;

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

jtngp_flash u_flash(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .dev_type   ( 4'd8      ),
    .cpu_addr   ( 20'd0     ),
    .cpu_cs     ( 1'b0      ),
    .cpu_we     ( 2'b00     ),
    .cpu_dout   ( 16'd0     ),
    .cpu_din    ( cpu_din   ),
    .rdy        ( rdy       ),
    .cpu_ok     ( cpu_ok    ),
    .cart_addr  ( cart_addr ),
    .cart_we    ( cart_we   ),
    .cart_cs    ( cart_cs   ),
    .cart_ok    ( 1'b1      ),
    .cart_data  ( 16'd0     ),
    .cart_dsn   ( cart_dsn  ),
    .cart_din   ( cart_din  ),
    .cart       ( cart      ),
    .sav_addr   ( sav_addr  ),
    .sav_dout   ( sav_dout  ),
    .sav_wr     ( sav_wr    ),
    .sav_ack    ( sav_ack   ),
    .sav_din    ( sav_din   ),
    .sav_done   ( sav_done  ),
    .sav_wait   ( sav_wait  ),
    .sav_change (           ),
    .gs_data    ( gs_data   ),
    .gs_din     ( gs_din    ),
    .gs_addr    ( gs_addr   ),
    .gs_dsn     ( gs_dsn    ),
    .gs_ok      ( 1'b1      ),
    .gs_we      ( gs_we     ),
    .gs_cs      ( gs_cs     )
);

jtframe_dual_ram16 #(.AW(13)) u_save_ram(
    .clk0  ( clk              ),
    .data0 ( gs_din           ),
    .addr0 ( gs_addr[13:1]    ),
    .we0   ( gs_we0           ),
    .q0    ( gs_data          ),
    .clk1  ( clk              ),
    .data1 ( check_din        ),
    .addr1 ( check_addr       ),
    .we1   ( check_we         ),
    .q1    ( check_dout       )
);

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

task send_byte;
    input [15:0] address;
    input [ 7:0] data;
    begin
        ioctl_addr = address;
        ioctl_dout = data;
        ioctl_wr   = 1;
        @(posedge clk);
        #1 ioctl_wr = 0;
        while(sav_wait) @(posedge clk);
    end
endtask

task get_byte;
    input [15:0] address;
    output [7:0] data;
    begin
        ioctl_addr = address;
        ioctl_wr   = 0;
        repeat(3) @(posedge clk);
        data = address[0] ? sav_din[15:8] : sav_din[7:0];
        while(sav_wait) @(posedge clk);
    end
endtask

task read_flash_byte;
    input [12:0] block;
    input [ 7:0] offset;
    output [7:0] data;
    begin
        check_addr = {block,offset[7:1]};
        check_we   = 0;
        repeat(2) @(posedge clk);
        data = offset[0] ? check_dout[15:8] : check_dout[7:0];
    end
endtask

integer addr, block;
reg [7:0] seed, expected, actual;

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    clk = 0;
    rst = 1;
    cart = 0;
    ioctl_savegame = 0;
    ioctl_wr = 0;
    ioctl_addr = 0;
    ioctl_dout = 0;
    sav_change = 0;
    flush_ack = 0;
    check_din = 0;
    check_addr = 0;
    check_we = 0;
    seed = 8'h5a;

    repeat(2) @(posedge clk);
    rst = 0;
    cart = 1;
    @(posedge clk);
    cart = 0;

    // APF's missing-file fill is erased bytes. The flash metadata must not
    // turn that into a zero-filled save range.
    ioctl_savegame = 1;
    send_byte(16'h0000,8'hff);
    send_byte(16'h0001,8'hff);
    send_byte(16'h0002,8'hff);
    send_byte(16'h0003,8'hff);
    check(u_flash.auto_addr_max==13'h1fff && u_flash.auto_addr_min==13'h1fff,
        "erased missing-save header was not preserved");
    ioctl_savegame = 0;
    cart = 1;
    @(posedge clk);
    cart = 0;

    // Load the compact image: first its range header, then blocks 2 and 3.
    ioctl_savegame = 1;
    for(addr=0; addr<IMAGE_BYTES; addr=addr+1) begin
        if(addr==0) expected = MAX_BLOCK[7:0];
        else if(addr==1) expected = {3'd0,MAX_BLOCK[12:8]};
        else if(addr==2) expected = MIN_BLOCK[7:0];
        else if(addr==3) expected = {3'd0,MIN_BLOCK[12:8]};
        else if(addr<256) expected = 0;
        else expected = seed ^ addr[7:0] ^ (MIN_BLOCK + addr[15:8] - 1'd1);
        send_byte(addr[15:0],expected);
    end
    check(u_flash.auto_addr_min==MIN_BLOCK && u_flash.auto_addr_max==MAX_BLOCK,
        "loaded compact range metadata is wrong");
    ioctl_savegame = 0;
    @(posedge clk);

    for(block=MIN_BLOCK; block<=MAX_BLOCK; block=block+1) begin
        for(addr=0; addr<256; addr=addr+1) begin
            read_flash_byte(block[12:0],addr[7:0],actual);
            expected = seed ^ addr[7:0] ^ block[7:0];
            check(actual==expected,"Pocket load did not reach flash-save RAM");
        end
    end

    // A Pocket flush reads the same compact bytes back through sav_din.
    ioctl_savegame = 1;
    for(addr=0; addr<IMAGE_BYTES; addr=addr+1) begin
        get_byte(addr[15:0],actual);
        if(addr==0) expected = MAX_BLOCK[7:0];
        else if(addr==1) expected = {3'd0,MAX_BLOCK[12:8]};
        else if(addr==2) expected = MIN_BLOCK[7:0];
        else if(addr==3) expected = {3'd0,MIN_BLOCK[12:8]};
        else if(addr<256) expected = 0;
        else expected = seed ^ addr[7:0] ^ (MIN_BLOCK + addr[15:8] - 1'd1);
        check(actual==expected,"Pocket flush byte order or flash-save data is wrong");
    end
    ioctl_savegame = 0;

    pass();
end

endmodule
