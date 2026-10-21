module test;
    import SH7604_PKG::*;

    reg         clk=0;
    reg         rst_n=0;
    reg         ce_r=0, ce_f=0;
    reg         c_bus_wr=0, c_bus_req=0, c_bus_id=0, c_bus_tas=0;
    reg  [31:0] c_bus_a=0, c_bus_di=0, i_bus_di=0;
    reg  [ 3:0] c_bus_ba=4'hf;
    reg         i_bus_wait=1;
    reg         i_bus_write_drain=0;

    wire [31:0] c_bus_do, i_bus_a, i_bus_do;
    wire [ 3:0] i_bus_ba;
    wire        c_bus_busy, i_bus_we, i_bus_req, i_bus_prereq,
                i_bus_burst, i_bus_lock;

    always #5 clk=~clk;

    SH7604_CACHE dut(
        .CLK             ( clk          ),
        .RST_N           ( rst_n        ),
        .CE_R            ( ce_r         ),
        .CE_F            ( ce_f         ),
        .EN              ( 1'b1         ),
        .RES_N           ( 1'b1         ),
        .CBUS_A          ( c_bus_a      ),
        .CBUS_DI         ( c_bus_di     ),
        .CBUS_DO         ( c_bus_do     ),
        .CBUS_WR         ( c_bus_wr     ),
        .CBUS_BA         ( c_bus_ba     ),
        .CBUS_REQ        ( c_bus_req    ),
        .CBUS_ID         ( c_bus_id     ),
        .CBUS_TAS        ( c_bus_tas    ),
        .CBUS_BUSY       ( c_bus_busy   ),
        .IBUS_A          ( i_bus_a      ),
        .IBUS_DI         ( i_bus_di     ),
        .IBUS_DO         ( i_bus_do     ),
        .IBUS_BA         ( i_bus_ba     ),
        .IBUS_WE          ( i_bus_we     ),
        .IBUS_REQ        ( i_bus_req    ),
        .IBUS_PREREQ     ( i_bus_prereq ),
        .IBUS_BURST      ( i_bus_burst  ),
        .IBUS_LOCK       ( i_bus_lock   ),
        .IBUS_WAIT       ( i_bus_wait   ),
        .IBUS_WRITE_DRAIN( i_bus_write_drain ),
        .CPS3_DECRYPT    ( 1'b0         ),
        .CPS3_ALT_DECRYPT( 1'b0         ),
        .CPS3_KEY1       ( 32'd0        ),
        .CPS3_KEY2       ( 32'd0        )
    );

    task automatic phase(input reg r, input reg f);
        begin
            ce_r=r;
            ce_f=f;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        phase(0,0);
        rst_n=1;

        // Seed one cache line so a hit can be observed during the posted write.
        dut.CCR.CE=1;
        dut.WAY0[0]=26'h000001;
        dut.LRU[0]=6'h2d;
        dut.DATA00[0]=8'h11;
        dut.DATA01[0]=8'h22;
        dut.DATA02[0]=8'h33;
        dut.DATA03[0]=8'h44;

        // Start a cache-through store. The BSC accepts it locally, then keeps
        // the external write active while the CPU can continue.
        c_bus_a=32'h20000000;
        c_bus_di=32'h00000017;
        c_bus_wr=1;
        c_bus_req=1;
        phase(0,1);
        if (!i_bus_req || !dut.IBUS_WRITE)
            $fatal(1,"cache-through store did not become outstanding");
        c_bus_req=0;
        i_bus_wait=0;
        i_bus_write_drain=1;
        phase(0,1);
        if (dut.IBUS_WRITE || c_bus_busy || !i_bus_write_drain)
            $fatal(1,"BSC write drain did not remain visible after local acceptance");

        // The CCR command is accepted, but its effect waits for external drain.
        c_bus_req=0;
        c_bus_wr=0;
        c_bus_a=32'hfffffe92;
        c_bus_di=32'h00000011;
        c_bus_wr=1;
        c_bus_req=1;
        phase(1,0);
        if (dut.CCR.CP || !dut.CCR_WRITE_PEND || c_bus_busy)
            $fatal(1,"CCR purge was not deferred and acknowledged");

        // Later external writes and reads that need memory wait behind the
        // deferred CCR effect, so the command stays ordered after store one.
        c_bus_req=0;
        c_bus_wr=1;
        c_bus_a=32'h20000004;
        c_bus_di=32'h00000022;
        c_bus_req=1;
        phase(0,1);
        if (!c_bus_busy || i_bus_req || dut.IBUS_WRITE || dut.IBUS_WRITE_PEND)
            $fatal(1,"second store passed the deferred CCR fence");

        c_bus_req=0;
        c_bus_wr=0;
        c_bus_a=32'h00001000;
        c_bus_req=1;
        phase(0,1);
        if (!c_bus_busy || i_bus_req || i_bus_prereq || dut.IBUS_READ || dut.IBUS_READARRAY)
            $fatal(1,"cache miss passed the deferred CCR fence");

        // A cache hit returns the old line while the posted write remains active.
        c_bus_req=0;
        c_bus_wr=0;
        phase(1,0);
        c_bus_a=32'h00000000;
        c_bus_req=1;
        phase(0,1);
        if (c_bus_busy || c_bus_do !== 32'h44332211)
            $fatal(1,"old cache line was unavailable during posted write");

        // The instruction-side access sees the same stale cached line while
        // the CCR command is still queued behind the external write.
        c_bus_req=0;
        c_bus_id=1;
        c_bus_req=1;
        phase(0,1);
        if (c_bus_busy || c_bus_do !== 32'h44332211 || i_bus_req || dut.IBUS_READARRAY)
            $fatal(1,"instruction fetch did not hit the stale line during drain");
        c_bus_req=0;
        c_bus_id=0;

        // The deferred CCR command commits once the BSC reports write drain.
        i_bus_write_drain=0;
        phase(0,1);
        phase(1,0);
        if (!dut.CCR.CP || dut.CCR_WRITE_PEND)
            $fatal(1,"deferred CCR command did not commit after write drain");

        c_bus_a=32'hfffffe92;
        c_bus_wr=0;
        c_bus_req=1;
        #1;
        if (c_bus_do[4])
            $fatal(1,"CCR CP bit was visible on read");
        c_bus_req=0;

        // A fresh CCR write cannot overwrite CP before its purge completes.
        c_bus_di=32'h00000001;
        c_bus_wr=1;
        c_bus_req=1;
        phase(1,0);
        if (!c_bus_busy || !dut.CCR.CP || dut.CCR_WRITE_PEND)
            $fatal(1,"second CCR write passed the pending CP purge");
        c_bus_req=0;
        c_bus_wr=0;

        // A cache hit store cannot take priority over the pending purge edge.
        c_bus_a=32'h00000000;
        c_bus_di=32'h00000099;
        c_bus_wr=1;
        c_bus_req=1;
        phase(0,1);
        if (!c_bus_busy || dut.CACHE_WRITE)
            $fatal(1,"cache store passed the CP purge edge");
        c_bus_req=0;
        c_bus_wr=0;
        c_bus_a=32'h00000000;
        c_bus_id=1;
        c_bus_req=1;
        #1;
        if (c_bus_busy || c_bus_do !== 32'h44332211 || !dut.CCR.CP)
            $fatal(1,"instruction hit was not accepted on the CP invalidation edge");
        phase(1,0);
        if (dut.CCR.CP || dut.WAY0[0][0] || dut.LRU[0] != 0)
            $fatal(1,"CCR purge did not invalidate the cached line");
        c_bus_req=0;
        c_bus_id=0;

        // After purge, the instruction-side access must miss and request a refill.
        c_bus_id=1;
        c_bus_req=1;
        phase(0,1);
        if (!c_bus_busy || !i_bus_req || !dut.IBUS_READARRAY)
            $fatal(1,"instruction fetch still hit after purge");

        $display("PASS: posted-store/CCR ordering, data/instruction hits, and purge");
        $finish;
    end
endmodule
