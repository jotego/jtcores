`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam [31:0] SAR0       = 32'hffffff80;
localparam [31:0] DAR0       = 32'hffffff84;
localparam [31:0] TCR0       = 32'hffffff88;
localparam [31:0] CHCR0      = 32'hffffff8c;
localparam [31:0] DMAOR      = 32'hffffffb0;
localparam [31:0] CHCR_LWORD = 32'h00005a41;

localparam [31:0] SRC_ADDR   = 32'h02010000;
localparam [31:0] DST_ADDR   = 32'h02011450;
localparam [31:0] FLASH_ID   = 32'h04040404;
localparam [31:0] LIVE_DBUS  = 32'h9323fb63;

reg         clk = 0;
reg         rst_n = 0;
reg         ce_r = 0;
reg         ce_f = 0;
reg         res_n = 1;
reg         nmi_n = 1;
reg         dreq0 = 0;
reg         dreq1 = 0;
reg         rxi_irq = 0;
reg         txi_irq = 0;

reg  [31:0] ibus_a = 0;
reg  [31:0] ibus_di = 0;
wire [31:0] ibus_do;
reg  [ 3:0] ibus_ba = 4'hf;
reg         ibus_we = 0;
reg         ibus_req = 0;
wire        ibus_act;

wire [31:0] dbus_a;
reg  [31:0] dbus_di = 32'h00000000;
wire [31:0] dbus_do;
wire [ 3:0] dbus_ba;
wire        dbus_we;
wire        dbus_req;
wire        dbus_lock;
wire        dbus_burst;
reg         dbus_wait = 0;
reg         bsc_ack = 1;

wire        dack0;
wire        dack1;
wire        dmac0_irq;
wire [ 7:0] dmac0_vec;
wire        dmac1_irq;
wire [ 7:0] dmac1_vec;

integer     write_count = 0;
reg  [31:0] last_write_addr = 0;
reg  [31:0] last_write_data = 0;

always #5 clk = ~clk;

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0, test);
    $dumpon;
end

initial begin
    repeat (4) @(posedge clk);
    rst_n = 1;

    ibus_write32(DMAOR, 32'h00000000);
    ibus_write32(CHCR0, 32'h00000000);
    start_dma(SRC_ADDR, DST_ADDR, 24'd1);

    wait_for_read_phase();
    assert_or_fail(dbus_a == (SRC_ADDR & 32'h07ffffff),
        "DMAC should read from SAR0 first");

    dbus_di = FLASH_ID;
    tick_f();
    assert_or_fail(dbus_req && dbus_we,
        "DMAC should enter write phase after source read");
    assert_or_fail(dbus_a == (DST_ADDR & 32'h07ffffff),
        "DMAC should write to DAR0 after source read");

    dbus_wait = 1;
    dbus_di = LIVE_DBUS;
    #1;
    assert_or_fail(dbus_do == FLASH_ID,
        "DMAC write data must be captured source read data, not live DBUS_DI");

    dbus_wait = 0;
    tick_f();
    assert_or_fail(write_count == 1,
        "DMAC should accept exactly one destination write");
    assert_or_fail(last_write_addr == (DST_ADDR & 32'h07ffffff),
        "accepted write should target DAR0");
    assert_or_fail(last_write_data == FLASH_ID,
        "accepted write should store captured source read data");

    pass();
end

task assert_or_fail(input bit cond, input string msg);
    begin
        if (!cond) begin
            $display("FAIL %s", msg);
            $display("dbus_req=%0b dbus_we=%0b dbus_wait=%0b dbus_a=%08x dbus_di=%08x dbus_do=%08x",
                dbus_req, dbus_we, dbus_wait, dbus_a, dbus_di, dbus_do);
            $display("write_count=%0d last_write_addr=%08x last_write_data=%08x",
                write_count, last_write_addr, last_write_data);
            $finish;
        end
    end
endtask

task tick_r;
    begin
        @(negedge clk);
        ce_r = 1;
        ce_f = 0;
        @(posedge clk);
        #1;
        ce_r = 0;
    end
endtask

task tick_f;
    begin
        @(negedge clk);
        ce_r = 0;
        ce_f = 1;
        @(posedge clk);
        #1;
        ce_f = 0;
    end
endtask

task tick_pair;
    begin
        tick_r();
        tick_f();
    end
endtask

task ibus_write32(input [31:0] addr, input [31:0] data);
    begin
        @(negedge clk);
        ibus_a = addr;
        ibus_di = data;
        ibus_ba = 4'hf;
        ibus_we = 1;
        ibus_req = 1;
        ce_r = 1;
        ce_f = 0;
        @(posedge clk);
        #1;
        ce_r = 0;
        @(negedge clk);
        ibus_req = 0;
        ibus_we = 0;
        ibus_a = 0;
        ibus_di = 0;
    end
endtask

task start_dma(input [31:0] src, input [31:0] dst, input [23:0] count);
    begin
        ibus_write32(SAR0, src);
        ibus_write32(DAR0, dst);
        ibus_write32(TCR0, {8'h00, count});
        ibus_write32(DMAOR, 32'h00000001);
        ibus_write32(CHCR0, CHCR_LWORD);
    end
endtask

task wait_for_read_phase;
    integer guard;
    begin
        guard = 0;
        while (!(dbus_req && !dbus_we) && guard < 64) begin
            tick_pair();
            guard = guard + 1;
        end
        assert_or_fail(dbus_req && !dbus_we,
            "timed out waiting for DMAC read phase");
    end
endtask

always @(posedge clk) begin
    if (rst_n && ce_f && dbus_req && dbus_we && !dbus_wait) begin
        write_count <= write_count + 1;
        last_write_addr <= dbus_a;
        last_write_data <= dbus_do;
    end
end

SH7604_DMAC uut(
    .CLK        ( clk        ),
    .RST_N      ( rst_n      ),
    .CE_R       ( ce_r       ),
    .CE_F       ( ce_f       ),
    .EN         ( 1'b1       ),
    .RES_N      ( res_n      ),
    .NMI_N      ( nmi_n      ),
    .DREQ0      ( dreq0      ),
    .DACK0      ( dack0      ),
    .DREQ1      ( dreq1      ),
    .DACK1      ( dack1      ),
    .RXI_IRQ    ( rxi_irq    ),
    .TXI_IRQ    ( txi_irq    ),
    .IBUS_A     ( ibus_a     ),
    .IBUS_DI    ( ibus_di    ),
    .IBUS_DO    ( ibus_do    ),
    .IBUS_BA    ( ibus_ba    ),
    .IBUS_WE    ( ibus_we    ),
    .IBUS_REQ   ( ibus_req   ),
    .IBUS_ACT   ( ibus_act   ),
    .DBUS_A     ( dbus_a     ),
    .DBUS_DI    ( dbus_di    ),
    .DBUS_DO    ( dbus_do    ),
    .DBUS_BA    ( dbus_ba    ),
    .DBUS_WE    ( dbus_we    ),
    .DBUS_REQ   ( dbus_req   ),
    .DBUS_LOCK  ( dbus_lock  ),
    .DBUS_BURST ( dbus_burst ),
    .DBUS_WAIT  ( dbus_wait  ),
    .BSC_ACK    ( bsc_ack    ),
    .DMAC0_IRQ  ( dmac0_irq  ),
    .DMAC0_VEC  ( dmac0_vec  ),
    .DMAC1_IRQ  ( dmac1_irq  ),
    .DMAC1_VEC  ( dmac1_vec  )
);

endmodule
