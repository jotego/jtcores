`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

reg         clk = 0;
reg         rst_n = 0;
reg         ce_r = 0;
reg         ce_f = 0;
reg  [31:0] cbus_a = 32'd0;
reg  [31:0] cbus_di = 32'd0;
wire [31:0] cbus_do;
reg  [ 3:0] cbus_ba = 4'hf;
reg         cbus_we = 1'b0;
reg         cbus_req = 1'b0;
reg         cbus_prereq = 1'b0;
reg         cbus_burst = 1'b0;
reg         cbus_lock = 1'b0;
wire        cbus_busy;
wire        cbus_act;
reg  [31:0] dbus_a = 32'd0;
reg  [31:0] dbus_di = 32'd0;
wire [31:0] dbus_do;
reg  [ 3:0] dbus_ba = 4'hf;
reg         dbus_we = 1'b0;
reg         dbus_req = 1'b0;
reg         dbus_burst = 1'b0;
reg         dbus_lock = 1'b0;
wire        dbus_busy;
reg  [ 3:0] vbus_a = 4'd0;
wire [ 7:0] vbus_do;
reg         vbus_req = 1'b0;
wire        vbus_busy;
wire [26:0] A;
reg  [31:0] DI = 32'h12345678;
wire [31:0] DO;
wire        BS_N;
wire        CS0_N;
wire        CS1_N;
wire        CS2_N;
wire        CS3_N;
wire        RD_WR_N;
wire        CE_N;
wire        OE_N;
wire [ 3:0] WE_N;
wire        RD_N;
wire        BGR_N;
wire        IVECF_N;
wire        RFS;
wire        IRQ;
wire        CACK;
wire        BUS_RLS;
wire        BUS_DBUS_RD;

always #5 clk = ~clk;

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0, test);
    $dumpon;
end

initial begin
    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    dbus_a   = 32'h00000100;
    dbus_ba  = 4'hf;
    dbus_we  = 1'b0;
    dbus_req = 1'b1;

    tick_r();
    assert_or_fail(CACK && !BS_N && !RD_N,
        "BSC should acknowledge the DBUS read with active read strobes");
    assert_or_fail(BUS_DBUS_RD,
        "BUS_DBUS_RD should assert while the DBUS read is presented");

    wait_for_return_setup();
    assert_or_fail(BS_N && !RD_N,
        "BSC should release BS_N before the return-data CE_F");
    assert_or_fail(BUS_DBUS_RD,
        "BUS_DBUS_RD must remain high after BS_N releases");

    wait_for_dbus_ready();
    assert_or_fail(BUS_DBUS_RD,
        "BUS_DBUS_RD must remain high when DBUS_BUSY drops");

    tick_f();
    assert_or_fail(BUS_DBUS_RD,
        "BUS_DBUS_RD must remain high through the read-data latch edge");

    dbus_req = 1'b0;
    wait_for_marker_clear();
    assert_or_fail(!BUS_DBUS_RD,
        "BUS_DBUS_RD should clear after the DBUS read completes");

    pass();
end

task tick_r;
    begin
        @(negedge clk);
        ce_r = 1'b1;
        ce_f = 1'b0;
        @(posedge clk);
        #1;
        ce_r = 1'b0;
    end
endtask

task tick_f;
    begin
        @(negedge clk);
        ce_r = 1'b0;
        ce_f = 1'b1;
        @(posedge clk);
        #1;
        ce_f = 1'b0;
    end
endtask

task wait_for_return_setup;
    integer guard;
    begin
        guard = 0;
        while (!BS_N && guard < 16) begin
            tick_r();
            guard = guard + 1;
        end
        assert_or_fail(BS_N, "timed out waiting for DBUS read return setup");
    end
endtask

task wait_for_dbus_ready;
    integer guard;
    begin
        guard = 0;
        while (dbus_busy && guard < 32) begin
            tick_r();
            guard = guard + 1;
        end
        assert_or_fail(!dbus_busy, "timed out waiting for DBUS_BUSY to drop");
    end
endtask

task wait_for_marker_clear;
    integer guard;
    begin
        guard = 0;
        while (BUS_DBUS_RD && guard < 16) begin
            tick_r();
            tick_f();
            guard = guard + 1;
        end
    end
endtask

task assert_or_fail(input bit cond, input string msg);
    begin
        if (!cond) begin
            $display("FAIL %s", msg);
            $display("A=%08x BS_N=%0b RD_N=%0b CACK=%0b DBUS_BUSY=%0b BUS_DBUS_RD=%0b",
                {5'd0, A}, BS_N, RD_N, CACK, dbus_busy, BUS_DBUS_RD);
            $fatal;
        end
    end
endtask

SH7604_BSC uut(
    .CLK          ( clk          ),
    .RST_N        ( rst_n        ),
    .CE_R         ( ce_r         ),
    .CE_F         ( ce_f         ),
    .EN           ( 1'b1         ),
    .RES_N        ( rst_n        ),
    .CLK4_CE      ( 1'b0         ),
    .CLK16_CE     ( 1'b0         ),
    .CLK64_CE     ( 1'b0         ),
    .CLK256_CE    ( 1'b0         ),
    .CLK1024_CE   ( 1'b0         ),
    .CLK2048_CE   ( 1'b0         ),
    .CLK4096_CE   ( 1'b0         ),
    .A            ( A            ),
    .DI           ( DI           ),
    .DO           ( DO           ),
    .BS_N         ( BS_N         ),
    .CS0_N        ( CS0_N        ),
    .CS1_N        ( CS1_N        ),
    .CS2_N        ( CS2_N        ),
    .CS3_N        ( CS3_N        ),
    .RD_WR_N      ( RD_WR_N      ),
    .CE_N         ( CE_N         ),
    .OE_N         ( OE_N         ),
    .WE_N         ( WE_N         ),
    .RD_N         ( RD_N         ),
    .WAIT_N       ( 1'b1         ),
    .BRLS_N       ( 1'b1         ),
    .BGR_N        ( BGR_N        ),
    .IVECF_N      ( IVECF_N      ),
    .RFS          ( RFS          ),
    .MD           ( 6'b010100    ),
    .CBUS_A       ( cbus_a       ),
    .CBUS_DI      ( cbus_di      ),
    .CBUS_DO      ( cbus_do      ),
    .CBUS_BA      ( cbus_ba      ),
    .CBUS_WE      ( cbus_we      ),
    .CBUS_REQ     ( cbus_req     ),
    .CBUS_PREREQ  ( cbus_prereq  ),
    .CBUS_BURST   ( cbus_burst   ),
    .CBUS_LOCK    ( cbus_lock    ),
    .CBUS_BUSY    ( cbus_busy    ),
    .CBUS_ACT     ( cbus_act     ),
    .DBUS_A       ( dbus_a       ),
    .DBUS_DI      ( dbus_di      ),
    .DBUS_DO      ( dbus_do      ),
    .DBUS_BA      ( dbus_ba      ),
    .DBUS_WE      ( dbus_we      ),
    .DBUS_REQ     ( dbus_req     ),
    .DBUS_BURST   ( dbus_burst   ),
    .DBUS_LOCK    ( dbus_lock    ),
    .DBUS_BUSY    ( dbus_busy    ),
    .VBUS_A       ( vbus_a       ),
    .VBUS_DO      ( vbus_do      ),
    .VBUS_REQ     ( vbus_req     ),
    .VBUS_BUSY    ( vbus_busy    ),
    .IRQ          ( IRQ          ),
    .CACK         ( CACK         ),
    .BUS_RLS      ( BUS_RLS      ),
    .BUS_DBUS_RD  ( BUS_DBUS_RD  ),
    .FAST         ( 1'b0         )
);

endmodule
