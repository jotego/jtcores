`timescale 1ns/1ps

module test;

reg clk = 0;
reg pxl_cen = 1;
reg rst = 0;
always #5 clk = ~clk;

wire lhbl, lvbl, hs, vs;
wire toki_cabal_lhbl, toki_cabal_lvbl, toki_cabal_hs, toki_cabal_vs;

`ifdef CORE_BLKOUT
jtblkout_video dut(.clk(clk), .rst(rst), .pxl_cen(pxl_cen),
    .LHBL(lhbl), .LVBL(lvbl), .HS(hs), .VS(vs));
localparam CORE_CODE = 0;
localparam EXPECTED_HSYNC = 27, EXPECTED_VSYNC = 3;
localparam EXPECTED_HFRONT = 82, EXPECTED_HBACK = 83;
localparam EXPECTED_VFRONT_TICKS = 6656, EXPECTED_VBACK_TICKS = 6656;
localparam EXPECTED_HTOTAL = 512, EXPECTED_VTOTAL = 269, EXPECTED_HACTIVE = 320, EXPECTED_VACTIVE = 240;
`elsif CORE_PKTGAL
jtpktgal_video dut(.clk(clk), .rst(rst), .pxl_cen(pxl_cen),
    .LHBL(lhbl), .LVBL(lvbl), .HS(hs), .VS(vs));
localparam CORE_CODE = 1;
localparam EXPECTED_HSYNC = 32, EXPECTED_VSYNC = 3;
localparam EXPECTED_HFRONT = 48, EXPECTED_HBACK = 48;
localparam EXPECTED_VFRONT_TICKS = 3128, EXPECTED_VBACK_TICKS = 9544;
localparam EXPECTED_HTOTAL = 384, EXPECTED_VTOTAL = 260, EXPECTED_HACTIVE = 256, EXPECTED_VACTIVE = 224;
`elsif CORE_SF
jtsf_video dut(.clk(clk), .rst(rst), .pxl_cen(pxl_cen),
    .LHBL(lhbl), .LVBL(lvbl), .HS(hs), .VS(vs));
localparam CORE_CODE = 2;
localparam EXPECTED_HSYNC = 40, EXPECTED_VSYNC = 3;
localparam EXPECTED_HFRONT = 32, EXPECTED_HBACK = 56;
localparam EXPECTED_VFRONT_TICKS = 2568, EXPECTED_VBACK_TICKS = 12280;
localparam EXPECTED_HTOTAL = 512, EXPECTED_VTOTAL = 256, EXPECTED_HACTIVE = 384, EXPECTED_VACTIVE = 224;
`elsif CORE_SARMS
jtsarms_video dut(.clk(clk), .rst(rst), .pxl_cen(pxl_cen),
    .LHBL(lhbl), .LVBL(lvbl), .HS(hs), .VS(vs));
localparam CORE_CODE = 3;
localparam EXPECTED_HSYNC = 40, EXPECTED_VSYNC = 3;
localparam EXPECTED_HFRONT = 32, EXPECTED_HBACK = 56;
localparam EXPECTED_VFRONT_TICKS = 2576, EXPECTED_VBACK_TICKS = 12272;
localparam EXPECTED_HTOTAL = 512, EXPECTED_VTOTAL = 256, EXPECTED_HACTIVE = 384, EXPECTED_VACTIVE = 224;
`elsif CORE_GAE1
`ifndef TEST_VTOTAL
`define TEST_VTOTAL 272
`endif
jtgae1_video #(.VTOTAL(`TEST_VTOTAL)) dut(.clk(clk), .rst(rst), .pxl_cen(pxl_cen),
    .lhbl(lhbl), .lvbl(lvbl), .hsync(hs), .vsync(vs), .gfx_en(4'b0), .gfx_4m(1'b0),
    .squash(1'b0), .bigkarnk(1'b0), .spr_force_high(6'b0));
localparam CORE_CODE = 4;
localparam EXPECTED_HSYNC = 28, EXPECTED_VSYNC = 8;
localparam EXPECTED_HFRONT = 11, EXPECTED_HBACK = 25;
localparam EXPECTED_VFRONT_TICKS = ((`TEST_VTOTAL-247)/2)*384 - ((`TEST_VTOTAL%2) ? 192 : 0);
localparam EXPECTED_VBACK_TICKS = EXPECTED_VFRONT_TICKS;
localparam EXPECTED_HTOTAL = 384, EXPECTED_VTOTAL = `TEST_VTOTAL, EXPECTED_HACTIVE = 320, EXPECTED_VACTIVE = 240;
`elsif CORE_TOKI
jttoki_video dut(.clk(clk), .rst(rst), .pxl_cen(pxl_cen), .pxl2_cen(pxl_cen),
    .cabal(1'b0), .lhbl(lhbl), .lvbl(lvbl), .hsync(hs), .vsync(vs));
jttoki_video dut_cabal(.clk(clk), .rst(rst), .pxl_cen(pxl_cen), .pxl2_cen(pxl_cen),
    .cabal(1'b1), .lhbl(toki_cabal_lhbl), .lvbl(toki_cabal_lvbl),
    .hsync(toki_cabal_hs), .vsync(toki_cabal_vs));
localparam CORE_CODE = 5;
localparam EXPECTED_HSYNC = 32, EXPECTED_VSYNC = 3;
localparam EXPECTED_HFRONT = 41, EXPECTED_HBACK = 55;
localparam EXPECTED_VFRONT_TICKS = 3788, EXPECTED_VBACK_TICKS = 9652;
localparam EXPECTED_HTOTAL = 384, EXPECTED_VTOTAL = 262, EXPECTED_HACTIVE = 256, EXPECTED_VACTIVE = 224;
`else
initial begin $display("FAIL: select a core with -DCORE_*"); $fatal(1); end
`endif

`ifdef MEASURE_ONLY
localparam REQUIRED_FRAMES = 2;
`else
localparam REQUIRED_FRAMES = 4;
`endif

integer tick = 0;
integer line_no = 0;
integer frame_no = 0;
integer line_start = -1;
integer blank_start = -1;
integer hsync_start = -1;
integer hsync_end = -1;
integer hblank_end = -1;
integer vblank_start_line = -1;
integer vsync_start_line = -1;
integer vsync_end_line = -1;
integer previous_frame_line = -1;
integer last_htotal = -1;
integer last_vtotal = -1;
integer last_hblank_width = -1;
integer last_active_width = -1;
integer previous_vblank_start_tick = -1;
integer vsync_start_tick = -1;
integer vsync_end_tick = -1;
integer last_frame_ticks = -1;
integer vfront_ticks, vback_ticks, vwidth_ticks, frame_ticks;
integer last_hsync_width = -1;
integer last_vsync_width = -1;
integer hfront, hwidth, hback, htotal;
integer vfront, vwidth, vback, vtotal;
integer line_rows = 0;
integer last_hfront = -1;
integer last_hback = -1;
integer last_vfront = -1;
integer last_vback = -1;
integer last_vblank_ticks = -1;
integer last_hactive = -1;
integer last_vactive = -1;
reg last_lhbl = 1'b1;
reg last_lvbl = 1'b0;
reg last_hs = 1'b0;
reg last_vs = 1'b0;

task fail;
    input [8*96-1:0] reason;
    begin
        $display("FAIL core=%0d tick=%0d: %0s", CORE_CODE, tick, reason);
        $fatal(1);
    end
endtask

task check_renderer_sync;
    begin
`ifndef MEASURE_ONLY
`ifdef CORE_BLKOUT
        if (dut.render_hs !== dut.u_vtimer.HS || dut.u_fb.HS !== dut.render_hs)
            fail("Block Out renderer HS is not the unshifted timer HS");
        if (dut.u_ovlb.LHBL !== ~dut.render_hs)
            fail("Block Out overlay line buffer lost its raw HS phase");
`elsif CORE_PKTGAL
        if (dut.render_hs !== dut.u_vtimer.HS || dut.u_bac06.HS !== dut.render_hs)
            fail("Pocket Gal renderer HS is not the unshifted timer HS");
`elsif CORE_GAE1
        if (dut.render_hs !== dut.u_vtimer.HS || dut.u_scroll.hsync !== dut.render_hs ||
            dut.u_obj.hs !== dut.render_hs)
            fail("Gaelco renderers lost the unshifted timer HS phase");
`elsif CORE_TOKI
        if (dut.render_hs !== dut.u_vtimer.HS || dut.u_scr1.hs !== dut.render_hs ||
            dut.u_scr2.hs !== dut.render_hs || dut.u_obj.hs !== dut.render_hs)
            fail("Toki renderers lost the unshifted timer HS phase");
`endif
`endif
    end
endtask

initial begin
    if ($test$plusargs("wave")) begin
        $dumpfile("sync_phase.vcd");
        $dumpvars(0, lhbl, lvbl, hs, vs);
    end
    #20_000_000 fail("simulation watchdog expired");
end

always @(negedge clk) if (pxl_cen) begin
    tick = tick + 1;
    check_renderer_sync();
`ifdef CORE_TOKI
    if ({toki_cabal_lhbl,toki_cabal_lvbl,toki_cabal_hs,toki_cabal_vs} !== {lhbl,lvbl,hs,vs})
        fail("Toki Cabal mode changed exported raster timing");
`endif

    if (last_lhbl && !lhbl) begin
        if (line_start >= 0) begin
            htotal = tick - line_start;
            if (last_htotal >= 0 && htotal != last_htotal)
                fail("horizontal total changed");
            if (htotal != EXPECTED_HTOTAL) fail("horizontal total differs from source geometry");
            last_htotal = htotal;
        end
        if (hblank_end >= 0) begin
            integer active_width;
            active_width = tick - hblank_end;
            if (last_active_width >= 0 && active_width != last_active_width)
                fail("horizontal active width changed");
            if (active_width != EXPECTED_HACTIVE) fail("horizontal active resolution changed");
            last_active_width = active_width;
            last_hactive = active_width;
        end
        line_start = tick;
        blank_start = tick;
        hsync_start = -1;
        hsync_end = -1;
        line_no = line_no + 1;
        if (!lvbl && vblank_start_line >= 0) begin
            if (vsync_start_line >= 0 && vsync_end_line >= 0)
                vfront = vsync_start_line - vblank_start_line;
        end
    end

    if (!last_hs && hs) begin
        if (lhbl !== 1'b0) fail("HS starts outside horizontal blank");
        hsync_start = tick;
        if (blank_start >= 0) hfront = tick - blank_start;
    end
    if (hs && lhbl) fail("HS pulse escaped horizontal blanking");
    if (vs && lvbl) fail("VS pulse escaped vertical blanking");
    if (last_hs && !hs) begin
        hsync_end = tick;
        if (hsync_start >= 0) begin
            hwidth = hsync_end - hsync_start;
            if (last_hsync_width >= 0 && hwidth != last_hsync_width)
                fail("horizontal sync width changed");
            if (hwidth != EXPECTED_HSYNC) fail("horizontal sync width differs from source timing");
            last_hsync_width = hwidth;
        end
    end
    if (!last_lhbl && lhbl) begin
        hblank_end = tick;
        if (hsync_end >= 0 && blank_start >= 0) begin
            integer blank_width;
            blank_width = tick - blank_start;
            if (last_hblank_width >= 0 && blank_width != last_hblank_width)
                fail("horizontal blank width changed");
            if (last_active_width >= 0 && blank_width + last_active_width != EXPECTED_HTOTAL)
                fail("horizontal active and blank intervals do not span one line");
            last_hblank_width = blank_width;
            hback = hblank_end - hsync_end;
`ifndef MEASURE_ONLY
            if (hfront != EXPECTED_HFRONT || hback != EXPECTED_HBACK)
                fail("horizontal sync phase differs from selected output timing");
`endif
            last_hfront = hfront;
            last_hback = hback;
            line_rows = line_rows + 1;
        end
    end

    if (last_lvbl && !lvbl) begin
        vblank_start_line = line_no;
        if (previous_vblank_start_tick >= 0) begin
            frame_ticks = tick - previous_vblank_start_tick;
            if (last_frame_ticks >= 0 && frame_ticks != last_frame_ticks)
                fail("vertical frame period changed");
            last_frame_ticks = frame_ticks;
        end
        previous_vblank_start_tick = tick;
        vsync_start_line = -1;
        vsync_end_line = -1;
        if (previous_frame_line >= 0) begin
            vtotal = line_no - previous_frame_line;
            if (last_vtotal >= 0 && vtotal != last_vtotal)
                fail("vertical frame total changed");
            if (vtotal != EXPECTED_VTOTAL) fail("vertical total differs from source geometry");
            last_vtotal = vtotal;
        end
        previous_frame_line = line_no;
    end
    if (!last_vs && vs) begin
        if (lvbl !== 1'b0) fail("VS starts outside vertical blank");
        vsync_start_line = line_no;
        vsync_start_tick = tick;
        if (vblank_start_line >= 0) vfront = line_no - vblank_start_line;
    end
    if (last_vs && !vs) begin
        vsync_end_line = line_no;
        vsync_end_tick = tick;
        if (vsync_start_line >= 0) begin
            vwidth = vsync_end_line - vsync_start_line;
            if (last_vsync_width >= 0 && vwidth != last_vsync_width)
                fail("vertical sync width changed");
            vwidth_ticks = vsync_end_tick - vsync_start_tick;
            if (vwidth_ticks != EXPECTED_VSYNC*last_htotal)
                fail("vertical sync width differs from source timing");
            last_vsync_width = vwidth;
        end
    end
    if (!last_lvbl && lvbl) begin
        if (vblank_start_line >= 0 && vsync_end_line >= 0) begin
            last_vblank_ticks = tick - previous_vblank_start_tick;
            last_vactive = last_vtotal-(last_vblank_ticks/last_htotal);
            if (last_vtotal >= 0 && last_htotal > 0 && last_vactive != EXPECTED_VACTIVE)
                fail("vertical active resolution changed");
            vback = line_no - vsync_end_line;
            vfront_ticks = vsync_start_tick - previous_vblank_start_tick;
            vback_ticks  = tick - vsync_end_tick;
`ifndef MEASURE_ONLY
            if (vfront_ticks != EXPECTED_VFRONT_TICKS || vback_ticks != EXPECTED_VBACK_TICKS)
                fail("vertical sync phase differs from selected output timing");
`endif
            last_vfront = vfront;
            last_vback = vback;
            frame_no = frame_no + 1;
            if (frame_no >= REQUIRED_FRAMES) begin
                $display("PASS core=%0d H=%0d/%0d/%0d Hactive=%0d Hblank=%0d Vticks=%0d/%0d/%0d Vactive=%0d Vblank_ticks=%0d Htotal=%0d Vtotal=%0d frame_ticks=%0d",
                    CORE_CODE, last_hfront, last_hsync_width, last_hback,
                    last_htotal-last_hblank_width, last_hblank_width,
                    vfront_ticks, vwidth_ticks, vback_ticks,
                    last_vtotal-(last_vblank_ticks/last_htotal), last_vblank_ticks,
                    last_htotal, last_vtotal, last_frame_ticks);
                $finish;
            end
        end
    end

    last_lhbl = lhbl;
    last_lvbl = lvbl;
    last_hs = hs;
    last_vs = vs;
end

endmodule
