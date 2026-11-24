`timescale 1ns/1ps

module test;

reg clk = 0;
reg [2:0] div = 0;
reg req_57Hz = 0;
reg compare_enable = 0;
always #5 clk = ~clk;
always @(posedge clk) div <= div + 1'b1;
wire pxl_cen = div==3'd7;

wire [8:0] H, vdump, vrender, vrender1;
wire Hinit, Vinit, LHBL, LVBL, raw_hs, raw_vs;
wire is_57Hz;
wire native_hs, native_vs, osd_hs, osd_vs, zero_hs, zero_vs;
wire [3:0] old_hoffset = is_57Hz ? 4'd4 : 4'd7;
integer mismatch_count = 0;
integer checked_samples = 0;
integer tick_count = 0;
integer native_hs_rises = 0, native_vs_rises = 0;
integer osd_hs_rises = 0, osd_vs_rises = 0;
integer zero_hs_rises = 0, zero_vs_rises = 0;
reg native_hs_last = 0, native_vs_last = 0;
reg osd_hs_last = 0, osd_vs_last = 0;
reg zero_hs_last = 0, zero_vs_last = 0;

jts16_vtimer #(.DUAL_RATE(1),.HS_END(9'h0a0)) u_timer(
    .clk                    ( clk                    ),
    .pxl_cen                ( pxl_cen                ),
    .req_57Hz               ( req_57Hz               ),
    .is_57Hz                ( is_57Hz                ),
    .vdump                  ( vdump                  ),
    .vrender                ( vrender                ),
    .vrender1               ( vrender1               ),
    .H                      ( H                      ),
    .Hinit                  ( Hinit                  ),
    .Vinit                  ( Vinit                  ),
    .LHBL                   ( LHBL                   ),
    .LVBL                   ( LVBL                   ),
    .HS                     ( raw_hs                 ),
    .VS                     ( raw_vs                 )
);

jts18_sync u_native(
    .clk                    ( clk                    ),
    .pxl_cen                ( pxl_cen                ),
    .is_57Hz                ( is_57Hz                ),
    .hdump                  ( H                      ),
    .vdump                  ( vdump                  ),
    .HS                     ( native_hs              ),
    .VS                     ( native_vs              )
);

// Compare through the real JTFRAME resynchronizer: legacy raw sync plus the
// saved OSD offsets versus native centered sync with all offsets set to zero.
jtframe_resync #(.WIDE(1)) u_resync_osd(
    .clk      ( clk         ),
    .pxl_cen  ( pxl_cen     ),
    .hs_in    ( raw_hs      ),
    .vs_in    ( raw_vs      ),
    .LVBL     ( LVBL        ),
    .LHBL     ( LHBL        ),
    .hoffset  ( old_hoffset ),
    .voffset  ( 4'hc        ),
    .hs_out   ( osd_hs      ),
    .vs_out   ( osd_vs      )
);

jtframe_resync #(.WIDE(1)) u_resync_zero(
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .hs_in    ( native_hs ),
    .vs_in    ( native_vs ),
    .LVBL     ( LVBL      ),
    .LHBL     ( LHBL      ),
    .hoffset  ( 4'd0      ),
    .voffset  ( 4'd0      ),
    .hs_out   ( zero_hs   ),
    .vs_out   ( zero_vs   )
);

always @(posedge clk) if (pxl_cen) begin
    tick_count <= tick_count + 1;
    if (tick_count > 1500000) begin
        $display("FAIL sync_center: watchdog expired");
        $fatal(1);
    end
    #1;
    if (compare_enable && ((^{osd_hs,osd_vs,zero_hs,zero_vs})===1'bx)) begin
        $display("FAIL sync_center: resync output contains X/Z");
        $fatal(1);
    end
    if (native_hs && !native_hs_last) native_hs_rises <= native_hs_rises + 1;
    if (native_vs && !native_vs_last) native_vs_rises <= native_vs_rises + 1;
    if (osd_hs && !osd_hs_last) osd_hs_rises <= osd_hs_rises + 1;
    if (osd_vs && !osd_vs_last) osd_vs_rises <= osd_vs_rises + 1;
    if (zero_hs && !zero_hs_last) zero_hs_rises <= zero_hs_rises + 1;
    if (zero_vs && !zero_vs_last) zero_vs_rises <= zero_vs_rises + 1;
    native_hs_last <= native_hs;
    native_vs_last <= native_vs;
    osd_hs_last <= osd_hs;
    osd_vs_last <= osd_vs;
    zero_hs_last <= zero_hs;
    zero_vs_last <= zero_vs;
    if (compare_enable) begin
        checked_samples <= checked_samples + 1;
        if (osd_hs !== zero_hs || osd_vs !== zero_vs) begin
            mismatch_count <= mismatch_count + 1;
            if (mismatch_count < 8)
                $display("SYNC_FAIL OSD/zero HS=%b/%b VS=%b/%b H/V=%03x/%03x mode=%b",
                    osd_hs,zero_hs,osd_vs,zero_vs,H,vdump,is_57Hz);
        end
    end
end

task settle_and_compare(input mode);
    integer frames, before_mismatch, before_samples;
    reg previous_lvbl;
    begin
        compare_enable = 0;
        frames = 0;
        previous_lvbl = LVBL;
        while (frames < 3) begin
            @(posedge clk);
            #2;
            if (LVBL && !previous_lvbl) frames = frames + 1;
            previous_lvbl = LVBL;
        end
        if (is_57Hz !== mode) begin
            $display("FAIL sync_center: mode did not settle to %b",mode);
            $fatal(1);
        end
        before_mismatch = mismatch_count;
        before_samples = checked_samples;
        native_hs_rises = 0;
        native_vs_rises = 0;
        osd_hs_rises = 0;
        osd_vs_rises = 0;
        zero_hs_rises = 0;
        zero_vs_rises = 0;
        compare_enable = 1;
        frames = 0;
        previous_lvbl = LVBL;
        while (frames < 1) begin
            @(posedge clk);
            #2;
            if (LVBL && !previous_lvbl) frames = frames + 1;
            previous_lvbl = LVBL;
        end
        compare_enable = 0;
        if (mismatch_count != before_mismatch ||
            checked_samples-before_samples != (mode ? 104800 : 99840) ||
            native_hs_rises != (mode ? 262 : 260) || native_vs_rises != 1 ||
            osd_hs_rises != native_hs_rises || zero_hs_rises != native_hs_rises ||
            osd_vs_rises != 1 || zero_vs_rises != 1) begin
            $display("FAIL sync_center: OSD/zero mismatch count %0d samples %0d",
                mismatch_count-before_mismatch,checked_samples-before_samples);
            $display("FAIL sync_center: native/OSD/zero HS rises=%0d/%0d/%0d VS rises=%0d/%0d/%0d",
                native_hs_rises,osd_hs_rises,zero_hs_rises,
                native_vs_rises,osd_vs_rises,zero_vs_rises);
            $fatal(1);
        end
        $display("SYNC_CENTER mode=%s compared %0d pixel enables after field-slot settling",
            mode ? "57Hz" : "60Hz",checked_samples-before_samples);
    end
endtask

initial begin
    #1;
    // jtframe_resync does not initialize its learned field selector. Seed only
    // the test instances identically; production RTL and startup behavior stay intact.
    u_resync_osd.field = 0;
    u_resync_zero.field = 0;
    u_resync_osd.last_LHBL = LHBL;
    u_resync_zero.last_LHBL = LHBL;
    u_resync_osd.last_LVBL = LVBL;
    u_resync_zero.last_LVBL = LVBL;
    u_resync_osd.last_hsin = raw_hs;
    u_resync_zero.last_hsin = native_hs;
    u_resync_osd.last_vsin = raw_vs;
    u_resync_zero.last_vsin = native_vs;

    settle_and_compare(1'b0);
    req_57Hz = 1;
    wait (is_57Hz);
    settle_and_compare(1'b1);
    req_57Hz = 0;
    wait (!is_57Hz);
    settle_and_compare(1'b0);
    $display("PASS");
    $finish;
end

endmodule
