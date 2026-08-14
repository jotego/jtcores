`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

localparam SDRAMW = 22;

reg               rst, clk;
reg  [15:0]       ram_addr, rom_addr;
reg  [15:0]       ram_din;
reg  [ 1:0]       ram_wrmask;
reg               ram_cs, ram_wen, rom_cs, rom_clr;
reg               sdram_ack, data_dst, data_rdy;
reg  [15:0]       data_read;
reg  [15:0]       xs_addr;
reg               xs_cs, xs_ack, xs_dst, xs_rdy;
reg  [15:0]       xs_data;
wire [15:0]       ram_dout, rom_dout, data_write;
wire [15:0]       xs_dout;
wire [SDRAMW-1:0] sdram_addr;
wire [SDRAMW-1:0] xs_sdram_addr;
wire [ 1:0]       sdram_wrmask;
wire              ram_ok, rom_ok, hold_rst;
wire              sdram_rd, sdram_wr;
wire              xs_ok, xs_rd;

integer cycles;

always #5 clk = ~clk;

jtframe_ram1_2slots #(
    .SDRAMW     ( SDRAMW ),
    .SLOT0_ERASE( 0      ),
    .SLOT0_AW   ( 16     ),
    .SLOT0_DW   ( 16     ),
    .SLOT1_AW   ( 16     ),
    .SLOT1_DW   ( 16     )
) uut (
    .rst           ( rst           ),
    .clk           ( clk           ),
    .slot0_addr    ( ram_addr      ),
    .slot0_dout    ( ram_dout      ),
    .slot0_offset  ( 22'd0         ),
    .slot0_cs      ( ram_cs        ),
    .slot0_ok      ( ram_ok        ),
    .slot0_wen     ( ram_wen       ),
    .slot0_din     ( ram_din       ),
    .slot0_wrmask  ( ram_wrmask    ),
    .hold_rst      ( hold_rst      ),
    .slot1_addr    ( rom_addr      ),
    .slot1_dout    ( rom_dout      ),
    .slot1_cs      ( rom_cs        ),
    .slot1_ok      ( rom_ok        ),
    .slot1_clr     ( rom_clr       ),
    .sdram_ack     ( sdram_ack     ),
    .sdram_rd      ( sdram_rd      ),
    .sdram_wr      ( sdram_wr      ),
    .sdram_addr    ( sdram_addr    ),
    .data_rdy      ( data_rdy      ),
    .data_dst      ( data_dst      ),
    .data_read     ( data_read     ),
    .data_write    ( data_write    ),
    .sdram_wrmask  ( sdram_wrmask )
);

jtframe_rom_1slot #(
    .SDRAMW     ( SDRAMW ),
    .SLOT0_AW   ( 16     ),
    .SLOT0_DW   ( 16     ),
    .CACHE0_SIZE( 4      )
) uut_xscache (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .slot0_addr ( xs_addr       ),
    .slot0_dout ( xs_dout       ),
    .slot0_cs   ( xs_cs         ),
    .slot0_ok   ( xs_ok         ),
    .sdram_ack  ( xs_ack        ),
    .sdram_rd   ( xs_rd         ),
    .sdram_addr ( xs_sdram_addr ),
    .data_dst   ( xs_dst        ),
    .data_rdy   ( xs_rdy        ),
    .data_read  ( xs_data       )
);

task wait_command(input expected_rd, input integer expected_cycles);
    begin : wait_loop
        for( cycles=1; cycles<10; cycles=cycles+1 ) begin
            @(posedge clk);
            #1;
            if( sdram_rd || sdram_wr ) begin
                assert_msg(sdram_rd == expected_rd, "unexpected SDRAM command type");
                assert_msg(cycles == expected_cycles, "unexpected slot request latency");
                disable wait_loop;
            end
        end
        $display("Timed out waiting for SDRAM command");
        fail();
    end
endtask

task acknowledge_command;
    begin
        @(negedge clk);
        sdram_ack = 1'b1;
        @(negedge clk);
        sdram_ack = 1'b0;
    end
endtask

task return_rom_line;
    begin
        @(negedge clk);
        data_read = 16'h3412;
        data_dst  = 1'b1;
        @(negedge clk);
        data_read = 16'h7856;
        data_dst  = 1'b0;
        data_rdy  = 1'b1;
        @(negedge clk);
        data_rdy  = 1'b0;
    end
endtask

initial begin
    clk           = 1'b0;
    rst           = 1'b1;
    ram_addr      = 16'd0;
    rom_addr      = 16'd0;
    ram_din       = 16'd0;
    ram_wrmask    = 2'b00;
    ram_cs        = 1'b0;
    ram_wen       = 1'b0;
    rom_cs        = 1'b0;
    rom_clr       = 1'b0;
    sdram_ack     = 1'b0;
    data_dst      = 1'b0;
    data_rdy      = 1'b0;
    data_read     = 16'd0;
    xs_addr       = 16'd0;
    xs_cs         = 1'b0;
    xs_ack        = 1'b0;
    xs_dst        = 1'b0;
    xs_rdy        = 1'b0;
    xs_data       = 16'd0;

    repeat (4) @(posedge clk);
    rst = 1'b0;
    repeat (2) @(posedge clk);
    assert_msg(!hold_rst, "RAM erase must be disabled");

    // The arbiter accepts a newly detected writable request without a bubble.
    @(negedge clk);
    ram_addr = 16'h0020;
    ram_cs   = 1'b1;
    wait_command(1'b1, 1);
    assert_msg(sdram_addr == 22'h20, "RAM command address mismatch");
    acknowledge_command();
    @(negedge clk);
    data_read = 16'hca5a;
    data_dst  = 1'b1;
    data_rdy  = 1'b1;
    @(negedge clk);
    data_dst  = 1'b0;
    data_rdy  = 1'b0;
    wait(ram_ok);
    assert_msg(ram_dout == 16'hca5a, "RAM response mismatch");
    @(negedge clk);
    ram_cs = 1'b0;
    repeat (2) @(posedge clk);

    @(negedge clk);
    ram_addr   = 16'h0022;
    ram_din    = 16'h5aa5;
    ram_wrmask = 2'b10;
    ram_wen    = 1'b1;
    ram_cs     = 1'b1;
    wait_command(1'b0, 1);
    assert_msg(sdram_addr == 22'h22, "RAM write address mismatch");
    assert_msg(data_write == 16'h5aa5, "RAM write data mismatch");
    assert_msg(sdram_wrmask == 2'b10, "RAM write mask mismatch");
    acknowledge_command();
    @(negedge clk);
    data_rdy = 1'b1;
    @(negedge clk);
    data_rdy = 1'b0;
    wait(ram_ok);
    @(negedge clk);
    ram_cs  = 1'b0;
    ram_wen = 1'b0;
    repeat (2) @(posedge clk);

    // Fill the ROM block, then access the other word in the same block.
    @(negedge clk);
    rom_addr = 16'h0040;
    rom_cs   = 1'b1;
    wait_command(1'b1, 1);
    acknowledge_command();
    return_rom_line();
    wait(rom_ok);
    @(negedge clk);
    rom_cs = 1'b0;
    repeat (2) @(posedge clk);

    @(negedge clk);
    rom_addr = 16'h0041;
    rom_cs   = 1'b1;
    begin : wait_block_hit
        for( cycles=1; cycles<10; cycles=cycles+1 ) begin
            @(posedge clk);
            #1;
            if( rom_ok ) begin
                assert_msg(cycles == 1, "unexpected ROM cache-hit latency");
                assert_msg(!sdram_rd, "ROM cache hit issued an SDRAM request");
                assert_msg(rom_dout == 16'h7856, "ROM cache-hit data mismatch");
                disable wait_block_hit;
            end
        end
        $display("Timed out waiting for ROM cache hit");
        fail();
    end

    @(negedge clk);
    rom_cs  = 1'b0;
    xs_addr = 16'h0080;
    xs_cs   = 1'b1;
    @(posedge clk);
    #1;
    assert_msg(xs_rd, "configurable-cache miss request latency is not one clock");
    assert_msg(xs_sdram_addr == 22'h80, "configurable-cache address mismatch");
    @(negedge clk);
    xs_ack = 1'b1;
    @(negedge clk);
    xs_ack = 1'b0;
    xs_data = 16'h9b3c;
    xs_dst  = 1'b1;
    @(negedge clk);
    xs_dst = 1'b0;
    xs_rdy = 1'b1;
    @(negedge clk);
    xs_rdy = 1'b0;
    wait(xs_ok);
    assert_msg(xs_dout == 16'h9b3c, "configurable-cache fill data mismatch");
    @(negedge clk);
    xs_cs = 1'b0;
    repeat (2) @(posedge clk);

    @(negedge clk);
    xs_cs = 1'b1;
    begin : wait_xs_hit
        for( cycles=1; cycles<10; cycles=cycles+1 ) begin
            @(posedge clk);
            #1;
            if( xs_ok ) begin
                assert_msg(cycles == 1, "unexpected configurable-cache hit latency");
                assert_msg(!xs_rd, "configurable-cache hit issued an SDRAM request");
                assert_msg(xs_dout == 16'h9b3c, "configurable-cache hit data mismatch");
                pass();
            end
        end
        $display("Timed out waiting for configurable-cache hit");
        fail();
    end
end

endmodule
