// Unit test: INT1 conditioning in jttc0030cmd.
//
// The IKA core samples INT1 through a noise filter that only recognises the
// request after it stays high across 3 consecutive sample windows (~108-144
// MCU-clock ticks). The wrapper holds an incoming int1 request (pulse or
// level) high for INT1_HOLD=192 *cen* ticks so it is always recognised, once
// per assert, independent of the request width and the cen rate. This test
// drives int1 and checks the internal `int1_held` hold (hierarchical probe).
//
// Because the hold counts cen ticks (not clk cycles), the measured hold is
// the same number of cen ticks whatever the cen divider is — the clock-rate
// tolerance we care about. This test uses a /6 cen (e.g. 48MHz->8MHz).
`timescale 1ns/1ps
module test;
    reg        clk = 0, rst = 1;
    reg  [2:0] cdiv = 0;
    wire       cen  = (cdiv == 3'd5);        // divide-by-6 MCU clock enable
    always #10 clk = ~clk;
    always @(posedge clk) cdiv <= cen ? 3'd0 : cdiv + 3'd1;

    reg int1 = 0;

    // idle host + MCU ports
    jttc0030cmd uut(
        .rst(rst), .clk(clk), .cen(cen),
        .cs(1'b0), .addr(11'd0), .din(8'd0), .dout(), .rnw(1'b1), .dtack_n(),
        .int1(int1), .nmi_n(1'b1),
        .pa_in(8'd0), .pb_in(8'd0), .pc_in(8'd0),
        .pa_out(), .pb_out(), .pc_out(),
        .an(8'd0),
        .mrom_addr(), .mrom_data(8'd0), .eprom_addr(), .eprom_data(8'd0),
        .dbg_pc(), .dbg_fetch()
    );

    integer cen_cnt;

    // Count cen ticks that elapse while int1_held stays high, then require the
    // hold to be long enough (>=144, the 3-sample filter worst case) and
    // bounded (not stuck). Fails on timeout.
    task measure_hold;
        begin
            cen_cnt = 0;
            if (!uut.int1_held) begin
                $display("FAIL: int1_held not asserted after request");
                $finish;
            end
            while (uut.int1_held) begin
                @(posedge clk);
                if (cen) cen_cnt = cen_cnt + 1;
                if (cen_cnt > 400) begin
                    $display("FAIL: int1_held stuck high (>400 cen)");
                    $finish;
                end
            end
        end
    endtask

    initial begin
        repeat (20) @(posedge clk);
        rst = 0;
        repeat (10) @(posedge clk);

        // ---- 1: a single-clk pulse must still be recognised (held long) ----
        @(posedge clk) int1 = 1;
        @(posedge clk) int1 = 0;
        measure_hold;
        if (cen_cnt < 144 || cen_cnt > 200) begin
            $display("FAIL: pulse held %0d cen (expected ~192, >=144)", cen_cnt);
            $finish;
        end
        $display("pulse: int1 held %0d cen ticks", cen_cnt);

        // small gap
        repeat (40) @(posedge clk);

        // ---- 2: a wide level must give exactly one hold, released after ----
        @(posedge clk) int1 = 1;
        repeat (30) @(posedge clk);      // hold the level high a while
        int1 = 0;
        measure_hold;                    // hold continues ~192 cen past release
        if (cen_cnt < 144 || cen_cnt > 200) begin
            $display("FAIL: level held %0d cen after release (expected ~192)", cen_cnt);
            $finish;
        end
        $display("level: int1 held %0d cen ticks after release", cen_cnt);

        // ---- 3: after the hold expires int1_held must be low (re-armable) ----
        repeat (20) @(posedge clk);
        if (uut.int1_held) begin
            $display("FAIL: int1_held did not clear");
            $finish;
        end

        // ---- 4: a long (full-vblank-like) level must release MID-level -------
        // Regression for the Op Wolf boot hang: a raw vblank level held high for
        // the whole vblank must give one hold measured from the rising edge and
        // then release even though the level is still high (not re-trigger).
        @(posedge clk) int1 = 1;              // rising edge arms the hold
        cen_cnt = 0;
        while (cen_cnt <= 260) begin           // keep the level HIGH well past 192 cen
            @(posedge clk);
            if (cen) cen_cnt = cen_cnt + 1;
        end
        if (uut.int1_held) begin
            $display("FAIL: int1_held still high after 260 cen with level stuck high");
            $finish;
        end
        $display("long level: int1_held released mid-level after ~192 cen (good)");
        int1 = 0;
        repeat (20) @(posedge clk);

        $display("PASS");
        $finish;
    end
endmodule
