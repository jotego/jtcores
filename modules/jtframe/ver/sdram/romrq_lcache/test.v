`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

reg rst, clk;
reg [7:0]  addr8;
reg [15:0] addr16, addr32;
reg cs8, cs16, cs32;
reg we8, we16, we32;
reg dst8, dst16, dst32;
reg rdy8, rdy16, rdy32;
reg [15:0] din8, din16, din32;
wire req8, req16, req32;
wire ok8, ok16, ok32;
wire [7:0] dout8;
wire [15:0] dout16;
wire [31:0] dout32;
wire [21:0] sdram_addr8, sdram_addr16, sdram_addr32;

always #5 clk = ~clk;

jtframe_romrq_lcache #(.SDRAMW(22),.AW(8),.DW(8),.BURSTLEN(16)) uut_byte(
    .rst(rst), .clk(clk), .clr(1'b0), .offset(22'd0), .din(din8), .din_ok(rdy8),
    .dst(dst8), .we(we8), .req(req8), .sdram_addr(sdram_addr8), .addr(addr8),
    .addr_ok(cs8), .data_ok(ok8), .dout(dout8)
);

jtframe_romrq_lcache #(.SDRAMW(22),.AW(16),.DW(16),.CACHE_SIZE(2048),.BURSTLEN(32)) uut_word(
    .rst(rst), .clk(clk), .clr(1'b0), .offset(22'd0), .din(din16), .din_ok(rdy16),
    .dst(dst16), .we(we16), .req(req16), .sdram_addr(sdram_addr16), .addr(addr16),
    .addr_ok(cs16), .data_ok(ok16), .dout(dout16)
);

jtframe_romrq_lcache #(.SDRAMW(22),.AW(16),.DW(32),.BURSTLEN(64)) uut_long(
    .rst(rst), .clk(clk), .clr(1'b0), .offset(22'd0), .din(din32), .din_ok(rdy32),
    .dst(dst32), .we(we32), .req(req32), .sdram_addr(sdram_addr32), .addr(addr32),
    .addr_ok(cs32), .data_ok(ok32), .dout(dout32)
);

task finish_byte;
    begin
        @(negedge clk); we8=1; dst8=1; din8=16'h3412;
        @(negedge clk); dst8=0; rdy8=1;
        @(negedge clk); we8=0; rdy8=0;
    end
endtask

task finish_word(input [15:0] first, input [15:0] second);
    begin
        @(negedge clk); we16=1; dst16=1; din16=first;
        @(negedge clk); dst16=0; din16=second; rdy16=1;
        @(negedge clk); we16=0; rdy16=0;
    end
endtask

task start_long;
    begin
        @(negedge clk); we32=1; dst32=1; din32=16'h1122;
        @(negedge clk); dst32=0; din32=16'h3344;
        @(negedge clk); din32=16'h5566;
    end
endtask

task finish_long;
    begin
        @(negedge clk); din32=16'h7788; rdy32=1;
        @(negedge clk); we32=0; rdy32=0;
    end
endtask

initial begin
    clk=0; rst=1;
    addr8=0; addr16=0; addr32=0;
    cs8=0; cs16=0; cs32=0;
    we8=0; we16=0; we32=0;
    dst8=0; dst16=0; dst32=0;
    rdy8=0; rdy16=0; rdy32=0;
    din8=0; din16=0; din32=0;
    repeat(3) @(posedge clk);
    rst=0;

    // 8-bit, one-beat fill; the second byte must be a one-clock hit.
    @(negedge clk); addr8=8'h20; cs8=1;
    #1 assert_msg(req8, "byte cold request missing");
    assert_msg(sdram_addr8==22'h10, "byte request was not word aligned");
    finish_byte();
    @(posedge clk); #1 assert_msg(ok8, "byte hit was not one clock after fill");
    assert_msg(dout8==8'h12, "byte low data order is wrong");
    @(negedge clk); addr8=8'h21;
    @(posedge clk); #1 assert_msg(ok8 && !req8, "byte cache hit missing");
    assert_msg(dout8==8'h34, "byte high data order is wrong");
    @(negedge clk); cs8=0;

    // 16-bit, two-beat fill, then direct-mapped conflict/refetch.
    @(negedge clk); addr16=16'h0040; cs16=1;
    #1 assert_msg(req16 && sdram_addr16==22'h40, "word cold request is wrong");
    finish_word(16'h3412,16'h7856);
    @(posedge clk); #1 assert_msg(ok16 && dout16==16'h3412, "word first beat is wrong");
    @(negedge clk); addr16=16'h0041;
    @(posedge clk); #1 assert_msg(ok16 && !req16 && dout16==16'h7856, "word second beat hit is wrong");
    @(negedge clk); addr16=16'h0440;
    #1 assert_msg(req16, "direct-mapped conflict did not miss");
    finish_word(16'habcd,16'hef01);
    @(posedge clk); #1 assert_msg(ok16 && dout16==16'habcd, "conflict line data is wrong");
    @(negedge clk); addr16=16'h0040;
    #1 assert_msg(req16, "evicted line did not refetch");
    @(negedge clk); cs16=0;

    // 32-bit, four-beat fill; no response may occur before the final beat.
    @(negedge clk); addr32=16'h0080; cs32=1;
    #1 assert_msg(req32 && sdram_addr32==22'h80, "long cold request is wrong");
    start_long();
    #1 assert_msg(!ok32, "long cache hit before final beat");
    finish_long();
    @(posedge clk); #1 assert_msg(ok32 && dout32==32'h3344_1122, "long first data order is wrong");
    @(negedge clk); addr32=16'h0082;
    @(posedge clk); #1 assert_msg(ok32 && !req32 && dout32==32'h7788_5566, "long second data order is wrong");
    @(negedge clk); cs32=0;

    // The controller can select a request after the client has moved on to a
    // new address.  The fill must retain the line captured with req, not the
    // address visible when we first asserts.
    @(negedge clk); addr8=8'h30; cs8=1;
    #1 assert_msg(req8, "delayed byte request missing");
    @(negedge clk); addr8=8'h34;
    #1 assert_msg(sdram_addr8==22'h18,
        "delayed request address changed before the fill started");
    finish_byte();
    @(posedge clk); #1 assert_msg(req8 && !ok8,
        "delayed fill was tagged with the changed address");
    @(negedge clk); addr8=8'h30;
    @(posedge clk);
    @(posedge clk); #1 assert_msg(ok8 && dout8==8'h12,
        "delayed fill did not retain its request address");
    @(negedge clk); cs8=0;

    pass();
end

endmodule
