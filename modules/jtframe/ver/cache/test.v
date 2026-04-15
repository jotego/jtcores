`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

localparam BLKSIZE = 16;
localparam BLOCKS  = 2;
localparam AW      = 8;
localparam EW      = 8;

wire rst, clk;

reg  [AW-1:0] mem8 [0:(1<<AW)-1];
wire [AW-1:1] ext_addr8, ext_addr16, ext_addr32, ext_addr32be;
reg  [15:0] ext_din8, ext_din16, ext_din32, ext_din32be;
wire ext_rd8, ext_rd16, ext_rd32, ext_rd32be;
reg  ext_ack8, ext_ack16, ext_ack32, ext_ack32be;
reg  ext_dst8, ext_dst16, ext_dst32, ext_dst32be;
reg  ext_rdy8, ext_rdy16, ext_rdy32, ext_rdy32be;
reg  [AW-1:0] addr8;
reg  [AW-1:1] addr16;
reg  [AW-1:2] addr32, addr32be;
reg  rd8, rd16, rd32, rd32be;
wire [7:0]  dout8;
wire [15:0] dout16;
wire [31:0] dout32, dout32be;
wire ok8, ok16, ok32, ok32be;

integer i;

initial begin
    for(i=0; i<(1<<AW); i=i+1) mem8[i] = i[7:0] ^ 8'h5a;

    ext_ack8 = 0;
    ext_ack16 = 0;
    ext_ack32 = 0;
    ext_ack32be = 0;
    ext_dst8 = 0;
    ext_dst16 = 0;
    ext_dst32 = 0;
    ext_dst32be = 0;
    ext_rdy8 = 0;
    ext_rdy16 = 0;
    ext_rdy32 = 0;
    ext_rdy32be = 0;
    ext_din8 = 0;
    ext_din16 = 0;
    ext_din32 = 0;
    ext_din32be = 0;
    addr8 = 0;
    addr16 = 0;
    addr32 = 0;
    addr32be = 0;
    rd8 = 0;
    rd16 = 0;
    rd32 = 0;
    rd32be = 0;

    fork
        drive_ext8();
        drive_ext16();
        drive_ext32();
        drive_ext32be();
    join_none

    @(negedge rst);
    repeat(4) @(posedge clk);

    run_dw8();
    run_dw16();
    run_dw32();
    run_dw32be();

    pass();
end

task run_dw8;
    begin
        request8(8'h05, 8'h5f, 1);
        request8(8'h04, 8'h5e, 0);
        request8(8'h13, 8'h49, 1);
        request8(8'h12, 8'h48, 0);
    end
endtask

task run_dw16;
    begin
        request16(7'h0a, { mem8[8'h15], mem8[8'h14] }, 1);
        request16(7'h0b, { mem8[8'h17], mem8[8'h16] }, 0);
        request16(7'h1a, { mem8[8'h35], mem8[8'h34] }, 1);
        request16(7'h19, { mem8[8'h33], mem8[8'h32] }, 0);
    end
endtask

task run_dw32;
    begin
        request32(6'h09, { mem8[8'h27], mem8[8'h26], mem8[8'h25], mem8[8'h24] }, 1);
        request32(6'h08, { mem8[8'h23], mem8[8'h22], mem8[8'h21], mem8[8'h20] }, 0);
        request32(6'h0d, { mem8[8'h37], mem8[8'h36], mem8[8'h35], mem8[8'h34] }, 1);
        request32(6'h0c, { mem8[8'h33], mem8[8'h32], mem8[8'h31], mem8[8'h30] }, 0);
    end
endtask

task run_dw32be;
    begin
        request32be(6'h09, { mem8[8'h25], mem8[8'h24], mem8[8'h27], mem8[8'h26] }, 1);
        request32be(6'h08, { mem8[8'h21], mem8[8'h20], mem8[8'h23], mem8[8'h22] }, 0);
        request32be(6'h0d, { mem8[8'h35], mem8[8'h34], mem8[8'h37], mem8[8'h36] }, 1);
        request32be(6'h0c, { mem8[8'h31], mem8[8'h30], mem8[8'h33], mem8[8'h32] }, 0);
    end
endtask

task request8;
    input [AW-1:0] req_addr;
    input [7:0] expected;
    input expect_miss;
    integer cycles;
    string msg;
    begin
        if(ok8) @(posedge clk);
        addr8 <= req_addr;
        rd8   <= 1;
        @(posedge clk);
        cycles = 1;
        while(!ok8) begin
            cycles = cycles + 1;
            @(posedge clk);
            assert_msg(cycles < 64, "DW8 request timed out");
        end
        rd8 <= 0;
        @(posedge clk);
        msg = $sformatf("DW8 returned %02X instead of %02X after %0d cycles", dout8, expected, cycles);
        assert_msg(dout8 == expected, msg);
        if(expect_miss)
            assert_msg(cycles > 2, "DW8 request should miss and refill");
        else
            assert_msg(cycles <= 3, "DW8 cached hit should complete within three cycles");
    end
endtask

task request16;
    input [AW-1:1] req_addr;
    input [15:0] expected;
    input expect_miss;
    integer cycles;
    string msg;
    begin
        if(ok16) @(posedge clk);
        addr16 <= req_addr;
        rd16   <= 1;
        @(posedge clk);
        cycles = 1;
        while(!ok16) begin
            cycles = cycles + 1;
            @(posedge clk);
            assert_msg(cycles < 64, "DW16 request timed out");
        end
        rd16 <= 0;
        @(posedge clk);
        msg = $sformatf("DW16 returned %04X instead of %04X after %0d cycles", dout16, expected, cycles);
        assert_msg(dout16 == expected, msg);
        if(expect_miss)
            assert_msg(cycles > 2, "DW16 request should miss and refill");
        else
            assert_msg(cycles <= 3, "DW16 cached hit should complete within three cycles");
    end
endtask

task request32;
    input [AW-1:2] req_addr;
    input [31:0] expected;
    input expect_miss;
    integer cycles;
    string msg;
    begin
        if(ok32) @(posedge clk);
        addr32 <= req_addr;
        rd32   <= 1;
        @(posedge clk);
        cycles = 1;
        while(!ok32) begin
            cycles = cycles + 1;
            @(posedge clk);
            assert_msg(cycles < 64, "DW32 request timed out");
        end
        rd32 <= 0;
        @(posedge clk);
        msg = $sformatf("DW32 returned %08X instead of %08X after %0d cycles", dout32, expected, cycles);
        assert_msg(dout32 == expected, msg);
        if(expect_miss)
            assert_msg(cycles > 2, "DW32 request should miss and refill");
        else
            assert_msg(cycles <= 3, "DW32 cached hit should complete within three cycles");
    end
endtask

task request32be;
    input [AW-1:2] req_addr;
    input [31:0] expected;
    input expect_miss;
    integer cycles;
    string msg;
    begin
        if(ok32be) @(posedge clk);
        addr32be <= req_addr;
        rd32be   <= 1;
        @(posedge clk);
        cycles = 1;
        while(!ok32be) begin
            cycles = cycles + 1;
            @(posedge clk);
            assert_msg(cycles < 64, "DW32 big-endian request timed out");
        end
        rd32be <= 0;
        @(posedge clk);
        msg = $sformatf("DW32 big-endian returned %08X instead of %08X after %0d cycles", dout32be, expected, cycles);
        assert_msg(dout32be == expected, msg);
        if(expect_miss)
            assert_msg(cycles > 2, "DW32 big-endian request should miss and refill");
        else
            assert_msg(cycles <= 3, "DW32 big-endian cached hit should complete within three cycles");
    end
endtask

task drive_ext8;
    integer base;
    integer n;
    begin
        forever begin
            @(posedge clk);
            ext_ack8 <= 0;
            ext_dst8 <= 0;
            ext_rdy8 <= 0;
            if(ext_rd8) begin
                ext_ack8 <= 1;
                base = { ext_addr8, 1'b0 };
                @(posedge clk);
                #1 assert_msg(ext_rd8, "DW8 ext_rd dropped before refill data started");
                ext_ack8 <= 0;
                for(n=0; n<(BLKSIZE>>1); n=n+1) begin
                    assert_msg(ext_rd8, "DW8 ext_rd must stay high through the refill burst");
                    ext_din8 <= { mem8[base + (n<<1) + 1], mem8[base + (n<<1)] };
                    ext_dst8 <= n==0;
                    ext_rdy8 <= n==(BLKSIZE>>1)-1;
                    @(posedge clk);
                    #1 if(n==(BLKSIZE>>1)-1)
                        assert_msg(!ext_rd8, "DW8 ext_rd must clear after the refill burst ends");
                    else
                        assert_msg(ext_rd8, "DW8 ext_rd dropped before the refill burst completed");
                    ext_dst8 <= 0;
                    ext_rdy8 <= 0;
                end
            end
        end
    end
endtask

task drive_ext16;
    integer base;
    integer n;
    begin
        forever begin
            @(posedge clk);
            ext_ack16 <= 0;
            ext_dst16 <= 0;
            ext_rdy16 <= 0;
            if(ext_rd16) begin
                ext_ack16 <= 1;
                base = { ext_addr16, 1'b0 };
                @(posedge clk);
                #1 assert_msg(ext_rd16, "DW16 ext_rd dropped before refill data started");
                ext_ack16 <= 0;
                for(n=0; n<(BLKSIZE>>1); n=n+1) begin
                    assert_msg(ext_rd16, "DW16 ext_rd must stay high through the refill burst");
                    ext_din16 <= { mem8[base + (n<<1) + 1], mem8[base + (n<<1)] };
                    ext_dst16 <= n==0;
                    ext_rdy16 <= n==(BLKSIZE>>1)-1;
                    @(posedge clk);
                    #1 if(n==(BLKSIZE>>1)-1)
                        assert_msg(!ext_rd16, "DW16 ext_rd must clear after the refill burst ends");
                    else
                        assert_msg(ext_rd16, "DW16 ext_rd dropped before the refill burst completed");
                    ext_dst16 <= 0;
                    ext_rdy16 <= 0;
                end
            end
        end
    end
endtask

task drive_ext32;
    integer base;
    integer n;
    begin
        forever begin
            @(posedge clk);
            ext_ack32 <= 0;
            ext_dst32 <= 0;
            ext_rdy32 <= 0;
            if(ext_rd32) begin
                ext_ack32 <= 1;
                base = { ext_addr32, 1'b0 };
                @(posedge clk);
                #1 assert_msg(ext_rd32, "DW32 ext_rd dropped before refill data started");
                ext_ack32 <= 0;
                for(n=0; n<(BLKSIZE>>1); n=n+1) begin
                    assert_msg(ext_rd32, "DW32 ext_rd must stay high through the refill burst");
                    ext_din32 <= { mem8[base + (n<<1) + 1], mem8[base + (n<<1)] };
                    ext_dst32 <= n==0;
                    ext_rdy32 <= n==(BLKSIZE>>1)-1;
                    @(posedge clk);
                    #1 if(n==(BLKSIZE>>1)-1)
                        assert_msg(!ext_rd32, "DW32 ext_rd must clear after the refill burst ends");
                    else
                        assert_msg(ext_rd32, "DW32 ext_rd dropped before the refill burst completed");
                    ext_dst32 <= 0;
                    ext_rdy32 <= 0;
                end
            end
        end
    end
endtask

task drive_ext32be;
    integer base;
    integer n;
    begin
        forever begin
            @(posedge clk);
            ext_ack32be <= 0;
            ext_dst32be <= 0;
            ext_rdy32be <= 0;
            if(ext_rd32be) begin
                ext_ack32be <= 1;
                base = { ext_addr32be, 1'b0 };
                @(posedge clk);
                #1 assert_msg(ext_rd32be, "DW32 big-endian ext_rd dropped before refill data started");
                ext_ack32be <= 0;
                for(n=0; n<(BLKSIZE>>1); n=n+1) begin
                    assert_msg(ext_rd32be, "DW32 big-endian ext_rd must stay high through the refill burst");
                    ext_din32be <= { mem8[base + (n<<1) + 1], mem8[base + (n<<1)] };
                    ext_dst32be <= n==0;
                    ext_rdy32be <= n==(BLKSIZE>>1)-1;
                    @(posedge clk);
                    #1 if(n==(BLKSIZE>>1)-1)
                        assert_msg(!ext_rd32be, "DW32 big-endian ext_rd must clear after the refill burst ends");
                    else
                        assert_msg(ext_rd32be, "DW32 big-endian ext_rd dropped before the refill burst completed");
                    ext_dst32be <= 0;
                    ext_rdy32be <= 0;
                end
            end
        end
    end
endtask

jtframe_test_clocks #(.MAXFRAMES(10), .TIMEOUT(5_000_000)) clocks(
    .rst        ( rst   ),
    .clk        ( clk   )
);

jtframe_cache #(
    .BLOCKS     ( BLOCKS ),
    .BLKSIZE    ( BLKSIZE),
    .AW         ( AW     ),
    .DW         ( 8      ),
    .EW         ( EW     )
) u_cache8(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .addr       ( addr8     ),
    .dout       ( dout8     ),
    .rd         ( rd8       ),
    .ok         ( ok8       ),
    .ext_addr   ( ext_addr8    ),
    .ext_din    ( ext_din8  ),
    .ext_rd     ( ext_rd8   ),
    .ext_ack    ( ext_ack8  ),
    .ext_dst    ( ext_dst8  ),
    .ext_rdy    ( ext_rdy8  )
);

jtframe_cache #(
    .BLOCKS     ( BLOCKS ),
    .BLKSIZE    ( BLKSIZE),
    .AW         ( AW     ),
    .DW         ( 16     ),
    .EW         ( EW     )
) u_cache16(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .addr       ( addr16    ),
    .dout       ( dout16    ),
    .rd         ( rd16      ),
    .ok         ( ok16      ),
    .ext_addr   ( ext_addr16   ),
    .ext_din    ( ext_din16 ),
    .ext_rd     ( ext_rd16  ),
    .ext_ack    ( ext_ack16 ),
    .ext_dst    ( ext_dst16 ),
    .ext_rdy    ( ext_rdy16 )
);

jtframe_cache #(
    .BLOCKS     ( BLOCKS ),
    .BLKSIZE    ( BLKSIZE),
    .AW         ( AW     ),
    .DW         ( 32     ),
    .EW         ( EW     )
) u_cache32(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .addr       ( addr32    ),
    .dout       ( dout32    ),
    .rd         ( rd32      ),
    .ok         ( ok32      ),
    .ext_addr   ( ext_addr32   ),
    .ext_din    ( ext_din32 ),
    .ext_rd     ( ext_rd32  ),
    .ext_ack    ( ext_ack32 ),
    .ext_dst    ( ext_dst32 ),
    .ext_rdy    ( ext_rdy32 )
);

jtframe_cache #(
    .BLOCKS     ( BLOCKS ),
    .BLKSIZE    ( BLKSIZE),
    .AW         ( AW     ),
    .DW         ( 32     ),
    .ENDIAN     ( 1      ),
    .EW         ( EW     )
) u_cache32be(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .addr       ( addr32be    ),
    .dout       ( dout32be    ),
    .rd         ( rd32be      ),
    .ok         ( ok32be      ),
    .ext_addr   ( ext_addr32be ),
    .ext_din    ( ext_din32be ),
    .ext_rd     ( ext_rd32be  ),
    .ext_ack    ( ext_ack32be ),
    .ext_dst    ( ext_dst32be ),
    .ext_rdy    ( ext_rdy32be )
);

endmodule
