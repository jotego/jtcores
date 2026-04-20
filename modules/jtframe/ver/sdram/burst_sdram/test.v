`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam PERIOD = 10;
localparam HF = 1;
localparam WORDS = 2048;
localparam PAGE_WORDS = 512;

reg         rst;
reg         clk;
reg         clk_sdram;
reg  [21:0] addr;
reg  [ 1:0] ba;
reg         rd;
reg         wr;
reg  [15:0] din;
wire [15:0] dout;
wire        ack;
wire        dst;
wire        dok;
wire        rdy;
wire        init;

reg         ioctl_rom;
reg  [25:0] ioctl_addr;
reg  [ 7:0] ioctl_dout;
reg         ioctl_wr;
wire [22:1] prog_addr;
wire [15:0] prog_data;
wire [ 1:0] prog_mask;
wire        prog_we;
wire        prog_rd;
wire [ 1:0] prog_ba;
wire        prom_we;
wire        header;
wire        prog_ack;

wire [15:0] sdram_dq;
wire [12:0] sdram_a;
wire [ 1:0] sdram_dqm;
wire [ 1:0] sdram_ba;
wire        sdram_nwe;
wire        sdram_ncas;
wire        sdram_nras;
wire        sdram_ncs;
wire        sdram_cke;

reg [15:0] exp_mem [0:WORDS-1];
reg [15:0] write_words [0:7];
reg [15:0] expected;

integer hcnt;
wire rfsh = hcnt == 0;

jtframe_burst_sdram #(
    .AW      ( 22 ),
    .HF      ( HF ),
    .MISTER  ( 0  ),
    .PROG_LEN( 64 )
) uut (
    .rst        ( rst        ),
    .clk        ( clk        ),
    .init       ( init       ),
    .addr       ( addr       ),
    .ba         ( ba         ),
    .rd         ( rd         ),
    .wr         ( wr         ),
    .din        ( din        ),
    .dout       ( dout       ),
    .ack        ( ack        ),
    .dst        ( dst        ),
    .dok        ( dok        ),
    .rdy        ( rdy        ),
    .prog_en    ( ioctl_rom  ),
    .prog_addr  ( prog_addr  ),
    .prog_rd    ( prog_rd    ),
    .prog_wr    ( prog_we    ),
    .prog_din   ( prog_data  ),
    .prog_dsn   ( prog_mask  ),
    .prog_ba    ( prog_ba    ),
    .prog_dst   (            ),
    .prog_dok   (            ),
    .prog_rdy   ( prog_ack   ),
    .prog_ack   (            ),
    .rfsh       ( rfsh       ),
    .sdram_dq   ( sdram_dq   ),
    .sdram_a    ( sdram_a    ),
    .sdram_dqml ( sdram_dqm[0] ),
    .sdram_dqmh ( sdram_dqm[1] ),
    .sdram_ba   ( sdram_ba   ),
    .sdram_nwe  ( sdram_nwe  ),
    .sdram_ncas ( sdram_ncas ),
    .sdram_nras ( sdram_nras ),
    .sdram_ncs  ( sdram_ncs  ),
    .sdram_cke  ( sdram_cke  )
);

jtframe_dwnld #(
    .SWAB       ( 1'b1      )
) u_dwnld(
    .clk        ( clk       ),
    .ioctl_rom  ( ioctl_rom ),
    .ioctl_addr ( ioctl_addr ),
    .ioctl_dout ( ioctl_dout ),
    .ioctl_wr   ( ioctl_wr   ),
    .prog_addr  ( prog_addr  ),
    .prog_data  ( prog_data  ),
    .prog_mask  ( prog_mask  ),
    .prog_we    ( prog_we    ),
    .prog_rd    ( prog_rd    ),
    .prog_ba    ( prog_ba    ),
    .gfx4_en    ( 1'b0       ),
    .gfx8_en    ( 1'b0       ),
    .gfx16_en   ( 1'b0       ),
    .gfx16b_en  ( 1'b0       ),
    .gfx16c_en  ( 1'b0       ),
    .prom_we    ( prom_we    ),
    .header     ( header     ),
    .sdram_ack  ( prog_ack   )
);

mt48lc16m16a2 sdram(
    .Clk        ( clk_sdram   ),
    .Cke        ( sdram_cke   ),
    .Dq         ( sdram_dq    ),
    .Addr       ( sdram_a     ),
    .Ba         ( sdram_ba    ),
    .Cs_n       ( sdram_ncs   ),
    .Ras_n      ( sdram_nras  ),
    .Cas_n      ( sdram_ncas  ),
    .We_n       ( sdram_nwe   ),
    .Dqm        ( sdram_dqm   ),
    .downloading( 1'b0        ),
    .VS         ( 1'b0        ),
    .frame_cnt  ( 0           )
);

`ifdef DEBUG
always @(posedge clk) begin
    if( ack || dok || rdy || prog_ack || uut.u_io.cmd != 4'b0111 ) begin
        $display("%t ack=%b dok=%b rdy=%b dst=%b dout=%h dq=%h cmd=%b a=%h ba=%0d prog=%b",
            $time, ack, dok, rdy, dst, dout, sdram_dq, uut.u_io.cmd, sdram_a, sdram_ba, ioctl_rom);
    end
end
`endif

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt+1;
    end
end

initial begin
    clk = 0;
    clk_sdram = 0;
    forever begin
        #(PERIOD/2) clk_sdram = ~clk_sdram;
        #5 clk = clk_sdram;
    end
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

task wait_prog_ready;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<500; timeout=timeout+1 ) begin
            @(posedge clk);
            if( prog_ack ) disable wait_loop;
        end
        $display("Timed out waiting for programming ready");
        fail();
    end
endtask

task wait_consumer_ack;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<500; timeout=timeout+1 ) begin
            @(posedge clk);
            if( ack ) disable wait_loop;
        end
        $display("Timed out waiting for burst ack");
        fail();
    end
endtask

task download_byte(input [25:0] byte_addr, input [7:0] value);
    integer word_idx;
    begin
        word_idx = byte_addr >> 1;
        if( byte_addr[0] ) exp_mem[word_idx][15:8] = value;
        else exp_mem[word_idx][7:0] = value;

        @(negedge clk);
        ioctl_rom  = 1'b1;
        ioctl_addr = byte_addr;
        ioctl_dout = value;
        ioctl_wr   = 1'b1;
        @(negedge clk);
        ioctl_wr   = 1'b0;
        wait_prog_ready();
    end
endtask

task burst_read_words(input [21:0] base_addr, input integer count);
    integer seen;
    integer idx;
    integer timeout;
    begin
        seen = 0;
        @(negedge clk);
        addr = base_addr;
        ba   = 2'd0;
        rd   = 1'b1;
        wait_consumer_ack();
        while( seen < count ) begin
            @(posedge clk);
            if( dok ) begin
                expected = exp_mem[base_addr + seen];
                if( dout !== expected ) begin
                    $display("Read mismatch at %0d: got %04x expected %04x", base_addr + seen, dout, expected);
                    fail();
                end
                if( seen == 0 ) assert_msg(dst, "dst must mark the first returned word");
                else assert_msg(!dst, "dst must only pulse for the first returned word");
                seen = seen + 1;
                if( seen == count ) begin
                    @(negedge clk);
                    rd = 1'b0;
                end
            end
        end
        begin : wait_done
            for( timeout=0; timeout<8; timeout=timeout+1 ) begin
                @(posedge clk);
                if( rdy ) disable wait_done;
            end
            $display("Timed out waiting for burst read completion");
            fail();
        end
        for( idx=0; idx<4; idx=idx+1 ) @(posedge clk);
    end
endtask

task burst_write_words(input [21:0] base_addr, input integer count);
    integer idx;
    begin
        @(negedge clk);
        addr = base_addr;
        ba   = 2'd0;
        wr   = 1'b1;
        din  = write_words[0];
        wait_consumer_ack();
        for( idx=0; idx<count; idx=idx+1 ) begin
            @(negedge clk);
            din = write_words[idx];
            @(posedge clk);
            exp_mem[base_addr + idx] = write_words[idx];
        end
        @(negedge clk);
        wr = 1'b0;
        din = 16'h0000;
        begin : wait_loop
            for( idx=0; idx<20; idx=idx+1 ) begin
                @(posedge clk);
                if( rdy ) disable wait_loop;
            end
            $display("Timed out waiting for burst write completion");
            fail();
        end
        for( idx=0; idx<4; idx=idx+1 ) @(posedge clk);
    end
endtask

task burst_read_page(input [21:0] base_addr, input integer count);
    integer seen;
    integer idx;
    integer timeout;
    reg done;
    begin
        seen = 0;
        done = 1'b0;
        @(negedge clk);
        addr = base_addr;
        ba   = 2'd0;
        rd   = 1'b1;
        wait_consumer_ack();
        begin : read_loop
            forever begin
                @(posedge clk);
                if( dok ) begin
                    expected = exp_mem[base_addr + seen];
                    if( dout !== expected ) begin
                        $display("Full-page read mismatch at %0d: got %04x expected %04x", base_addr + seen, dout, expected);
                        fail();
                    end
                    if( seen == 0 ) assert_msg(dst, "dst must mark the first full-page read word");
                    else assert_msg(!dst, "dst must only pulse for the first full-page read word");
                    seen = seen + 1;
                    if( rdy ) done = 1'b1;
                    if( seen == count ) begin
                        disable read_loop;
                    end
                end
            end
        end
        if( !done ) begin
            begin : wait_done
                for( timeout=0; timeout<8; timeout=timeout+1 ) begin
                    @(posedge clk);
                    if( rdy ) disable wait_done;
                end
                $display("Timed out waiting for full-page read completion");
                fail();
            end
        end
        @(negedge clk);
        rd = 1'b0;
        for( idx=0; idx<4; idx=idx+1 ) @(posedge clk);
    end
endtask

task burst_write_page(input [21:0] base_addr, input integer count, input [15:0] seed);
    integer idx;
    integer timeout;
    reg done;
    begin
        done = 1'b0;
        @(negedge clk);
        addr = base_addr;
        ba   = 2'd0;
        wr   = 1'b1;
        din  = seed;
        wait_consumer_ack();
        for( idx=0; idx<count; idx=idx+1 ) begin
            @(negedge clk);
            din = seed;
            @(posedge clk);
            exp_mem[base_addr + idx] = seed;
            if( rdy ) done = 1'b1;
        end
        if( !done ) begin
            begin : wait_done
                for( timeout=0; timeout<8; timeout=timeout+1 ) begin
                    @(posedge clk);
                    if( rdy ) disable wait_done;
                end
                $display("Timed out waiting for full-page write completion");
                fail();
            end
        end
        @(negedge clk);
        wr = 1'b0;
        din = 16'h0000;
        for( idx=0; idx<4; idx=idx+1 ) @(posedge clk);
    end
endtask

integer i;

initial begin
    for( i=0; i<WORDS; i=i+1 ) exp_mem[i] = 16'h0000;

    rst = 1'b1;
    addr = 22'd0;
    ba = 2'd0;
    rd = 1'b0;
    wr = 1'b0;
    din = 16'h0000;
    ioctl_rom = 1'b0;
    ioctl_addr = 26'd0;
    ioctl_dout = 8'd0;
    ioctl_wr = 1'b0;

    repeat (20) @(posedge clk);
    rst = 1'b0;

    begin : wait_init_done
        for( i=0; i<20_000; i=i+1 ) begin
            @(posedge clk);
            if( !init ) disable wait_init_done;
        end
        $display("Timed out waiting for SDRAM init");
        fail();
    end

    for( i=0; i<PAGE_WORDS*2; i=i+1 ) download_byte(i[25:0], i[7:0]);
    @(negedge clk);
    ioctl_rom = 1'b0;

    repeat (20) @(posedge clk);

    burst_read_page(22'd0, PAGE_WORDS);

    burst_read_words(22'd0, 8);

    write_words[0] = 16'hb100;
    write_words[1] = 16'hb211;
    write_words[2] = 16'hb322;
    write_words[3] = 16'hb433;
    write_words[4] = 16'hb544;
    burst_write_words(22'd8, 5);

    burst_read_words(22'd8, 5);

    burst_write_page(22'd0, PAGE_WORDS, 16'h4000);

    burst_read_page(22'd0, PAGE_WORDS);

    pass();
end

endmodule
