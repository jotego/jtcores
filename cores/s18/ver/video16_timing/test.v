`timescale 1ns/1ps

module test;

reg clk = 0;
reg rst = 1;
reg pxl_cen = 0, pxl2_cen = 0;
reg [2:0] phase = 0;
reg req_57Hz = 1;
reg char_cs = 0;
reg [12:1] addr = 0;
reg [15:0] din = 0;
reg [1:0] dsn = 2'b11;
integer capture_mode = 0;
integer seen_count = 0;
integer mismatch_count = 0;
integer active_scr_bad_count = 0;
integer active_sprite_busy_count = 0;
integer hscan_budget_checks = 0;
integer sprite_budget_checks = 0;
integer scroll_latch_checks = 0;
integer fast_hscan_checks = 0, original_hscan_checks = 0;
integer static_hscan_checks = 0;
integer fast_scroll_checks = 0, original_scroll_checks = 0;
integer fast_sprite_checks = 0, original_sprite_checks = 0;
integer line_count = 0;
integer timing_commits = 0;
reg [2:0] startup_trace_static = 0, startup_trace_fast = 0;
reg static_capture_armed = 0;
reg mode_seen = 0;
reg [3:0] fast_selected_layers = 0, original_selected_layers = 0;
reg [3:0] fast_raw_layers = 0, original_raw_layers = 0;
integer i;

always #10.416667 clk = ~clk;
always @(posedge clk) begin
    phase <= phase + 1'b1;
    pxl_cen <= phase == 3'd7;
    pxl2_cen <= phase[1:0] == 2'b11;
end

reg [7:0] fixed_timer_req_phase = 0;
always @(posedge clk) fixed_timer_req_phase <= fixed_timer_req_phase + 1'b1;
wire [31:0] timer_s16_checks, timer_s18_checks, timer_hb_checks;
wire [31:0] timer_s16_req0, timer_s16_req1;
wire [31:0] timer_s18_req0, timer_s18_req1;
wire [31:0] timer_hb_req0, timer_hb_req1;

fixed_timer_equivalence #(.HS_END(9'h09e)) timer_s16(
    .clk(clk), .pxl_cen(pxl_cen), .req_57Hz(fixed_timer_req_phase[4]),
    .checked_samples(timer_s16_checks), .req0_samples(timer_s16_req0), .req1_samples(timer_s16_req1)
);
fixed_timer_equivalence #(.HS_END(9'h0a0)) timer_s18(
    .clk(clk), .pxl_cen(pxl_cen), .req_57Hz(fixed_timer_req_phase[5]),
    .checked_samples(timer_s18_checks), .req0_samples(timer_s18_req0), .req1_samples(timer_s18_req1)
);
fixed_timer_equivalence #(.HB_END(9'h0c3),.HS_END(9'h09e)) timer_hb_variant(
    .clk(clk), .pxl_cen(pxl_cen), .req_57Hz(fixed_timer_req_phase[6]),
    .checked_samples(timer_hb_checks), .req0_samples(timer_hb_req0), .req1_samples(timer_hb_req1)
);

wire [8:0] ref_h, ref_v, ref_vrender;
wire ref_hs, ref_vs, ref_lhbl, ref_lvbl;
wire [69:0] ref_tuple;
wire ref_scr_bad;
wire [3:0] ref_scroll_en;
wire ref_done1, ref_done2;
wire [8:0] ref_hscan1, ref_hscan2;
wire ref_draw_busy;
wire ref_scan_idle;
wire [3:0] ref_selected;
wire ref_hstart, ref_scr_start;
wire ref_scr1_lastwrite, ref_scr2_lastwrite;
wire [60:0] ref_scroll1_trace, ref_scroll2_trace;
wire [3:0] ref_obj_state;

wire [8:0] dut_h, dut_v, dut_vrender;
wire dut_hs, dut_vs, dut_lhbl, dut_lvbl;
wire [69:0] dut_tuple;
wire dut_scr_bad;
wire [3:0] dut_scroll_en;
wire dut_done1, dut_done2;
wire [8:0] dut_hscan1, dut_hscan2;
wire dut_draw_busy;
wire dut_scan_idle;
wire dut_original_active;
wire dut_scr1_lastwrite, dut_scr2_lastwrite;
wire [3:0] dut_selected;
wire dut_hstart, dut_scr_start;
wire [60:0] dut_scroll1_trace, dut_scroll2_trace;
wire [3:0] dut_obj_state;

video16_case #(.DUAL_RATE(0)) uut_ref(
    .clk(clk), .rst(rst), .pxl_cen(pxl_cen), .pxl2_cen(pxl2_cen),
    .req_57Hz(1'b0), .char_cs(char_cs), .addr(addr), .din(din), .dsn(dsn),
    .H(ref_h), .V(ref_v), .vrender(ref_vrender), .HS(ref_hs), .VS(ref_vs),
    .LHBL(ref_lhbl), .LVBL(ref_lvbl), .tuple(ref_tuple), .scr_bad(ref_scr_bad),
    .scroll_en(ref_scroll_en), .done1(ref_done1), .done2(ref_done2),
    .hscan1(ref_hscan1), .hscan2(ref_hscan2), .draw_busy(ref_draw_busy),
    .scan_idle(ref_scan_idle), .original_active(), .selected(ref_selected),
    .hstart(ref_hstart), .scr_start(ref_scr_start),
    .scr1_lastwrite(ref_scr1_lastwrite), .scr2_lastwrite(ref_scr2_lastwrite),
    .scroll1_trace(ref_scroll1_trace), .scroll2_trace(ref_scroll2_trace), .obj_state(ref_obj_state)
);

video16_case #(.DUAL_RATE(1)) uut(
    .clk(clk), .rst(rst), .pxl_cen(pxl_cen), .pxl2_cen(pxl2_cen),
    .req_57Hz(req_57Hz), .char_cs(char_cs), .addr(addr), .din(din), .dsn(dsn),
    .H(dut_h), .V(dut_v), .vrender(dut_vrender), .HS(dut_hs), .VS(dut_vs),
    .LHBL(dut_lhbl), .LVBL(dut_lvbl), .tuple(dut_tuple), .scr_bad(dut_scr_bad),
    .scroll_en(dut_scroll_en), .done1(dut_done1), .done2(dut_done2),
    .hscan1(dut_hscan1), .hscan2(dut_hscan2), .draw_busy(dut_draw_busy),
    .scan_idle(dut_scan_idle), .original_active(dut_original_active), .selected(dut_selected),
    .scr1_lastwrite(dut_scr1_lastwrite), .scr2_lastwrite(dut_scr2_lastwrite),
    .hstart(dut_hstart), .scr_start(dut_scr_start),
    .scroll1_trace(dut_scroll1_trace), .scroll2_trace(dut_scroll2_trace), .obj_state(dut_obj_state)
);

reg [69:0] fast_pixels [0:959];
reg [69:0] static_original_pixels [0:959];
reg [959:0] seen = 0;
reg [959:0] static_seen = 0;
integer static_seen_count = 0;
reg [3:0] selected_layers = 0;
reg [3:0] checked_endpoints = 0;
reg saw_scr1_data = 0, saw_scr2_data = 0, saw_char_data = 0, saw_obj_data = 0;

task fail(input [8*96-1:0] why);
begin
    $display("FAIL video16_timing: %0s at t=%0t mode=%0d H/V=%0d/%0d", why, $time, capture_mode, dut_h, dut_v);
    $display("DIAG BUDGET H128 static=%0d fast=%0d original=%0d H144 fast=%0d original=%0d sprite fast=%0d original=%0d commits=%0d",
        static_hscan_checks,fast_hscan_checks,original_hscan_checks,fast_scroll_checks,
        original_scroll_checks,fast_sprite_checks,original_sprite_checks,timing_commits);
    $display("DIAG fast RESP char=%0d/%0dX map1=%0d/%0dX map2=%0d/%0dX scr1=%0d/%0dX scr2=%0d/%0dX obj=%0d/%0dX",
        uut.char_rsp_count,uut.char_rsp_x,uut.map1_rsp_count,uut.map1_rsp_x,
        uut.map2_rsp_count,uut.map2_rsp_x,uut.scr1_rsp_count,uut.scr1_rsp_x,
        uut.scr2_rsp_count,uut.scr2_rsp_x,uut.obj_rsp_count,uut.obj_rsp_x);
    $display("DIAG fast LINEBUF s1 bank=%b writes=%0d xdata=%0d first=%h/%h last=%h/%h s2 bank=%b writes=%0d xdata=%0d first=%h/%h last=%h/%h",
        uut.uut.u_tilemap.u_scr1.u_linebuf.line,uut.scr1_wr_count,uut.scr1_wr_x,
        uut.scr1_first_addr,uut.scr1_first_data,uut.scr1_last_addr,uut.scr1_last_data,
        uut.uut.u_tilemap.u_scr2.u_linebuf.line,uut.scr2_wr_count,uut.scr2_wr_x,
        uut.scr2_first_addr,uut.scr2_first_data,uut.scr2_last_addr,uut.scr2_last_data);
    $display("DIAG static RESP char=%0d/%0dX map1=%0d/%0dX map2=%0d/%0dX scr1=%0d/%0dX scr2=%0d/%0dX obj=%0d/%0dX",
        uut_ref.char_rsp_count,uut_ref.char_rsp_x,uut_ref.map1_rsp_count,uut_ref.map1_rsp_x,
        uut_ref.map2_rsp_count,uut_ref.map2_rsp_x,uut_ref.scr1_rsp_count,uut_ref.scr1_rsp_x,
        uut_ref.scr2_rsp_count,uut_ref.scr2_rsp_x,uut_ref.obj_rsp_count,uut_ref.obj_rsp_x);
    $display("DIAG static LINEBUF s1 bank=%b writes=%0d xdata=%0d first=%h/%h last=%h/%h s2 bank=%b writes=%0d xdata=%0d first=%h/%h last=%h/%h",
        uut_ref.uut.u_tilemap.u_scr1.u_linebuf.line,uut_ref.scr1_wr_count,uut_ref.scr1_wr_x,
        uut_ref.scr1_first_addr,uut_ref.scr1_first_data,uut_ref.scr1_last_addr,uut_ref.scr1_last_data,
        uut_ref.uut.u_tilemap.u_scr2.u_linebuf.line,uut_ref.scr2_wr_count,uut_ref.scr2_wr_x,
        uut_ref.scr2_first_addr,uut_ref.scr2_first_data,uut_ref.scr2_last_addr,uut_ref.scr2_last_data);
    $fatal(1);
end
endtask

task cpu_write(input [11:0] a, input [15:0] d);
begin
    @(negedge clk);
    addr = a;
    din = d;
    dsn = 2'b00;
    char_cs = 1;
    @(negedge clk);
    char_cs = 0;
    dsn = 2'b11;
end
endtask

task arm_capture(input integer mode);
begin
    capture_mode = mode;
    seen = 0;
    seen_count = 0;
    while (seen_count < 960) @(posedge clk);
    // The V2/H128 deadline follows the last active tuple at H511. Keep the
    // budget observers armed through that PRE-consumer source edge.
    while (!(pxl_cen && dut_h==9'h080 && dut_v==9'd2 && dut_lvbl)) @(posedge clk);
    #1;
    capture_mode = 0;
end
endtask

always @(posedge clk) begin : sample_and_check
    integer index;
    if (!rst && dut_original_active != mode_seen) begin
        mode_seen <= dut_original_active;
        timing_commits <= timing_commits + 1;
        if (dut_v !== 9'h0e0 || dut_h !== (dut_original_active ? 9'h070 : 9'h080))
            fail("production mode changed outside the V224 line-wrap boundary");
    end
    if (!rst && pxl_cen) begin
        if (dut_h==9'h1ff) begin
            line_count <= line_count + 1;
            if (line_count > 950) fail("physical-line watchdog expired");
        end
        if (ref_lvbl && ref_v==0 && ref_h==9'h080 && !startup_trace_static[0]) begin
            startup_trace_static[0] <= 1;
            $display("STARTUP static V0 H128 start=%b hstart=%b scr_bad=%b obj_state=%h draw=%b s1=%h s2=%h",ref_scr_start,ref_hstart,ref_scr_bad,ref_obj_state,ref_draw_busy,ref_scroll1_trace,ref_scroll2_trace);
        end
        if (ref_lvbl && ref_v==0 && ref_h==9'h090 && !startup_trace_static[1]) begin
            startup_trace_static[1] <= 1;
            $display("STARTUP static V0 H144 start=%b hstart=%b scr_bad=%b obj_state=%h draw=%b s1=%h s2=%h",ref_scr_start,ref_hstart,ref_scr_bad,ref_obj_state,ref_draw_busy,ref_scroll1_trace,ref_scroll2_trace);
        end
        if (ref_lvbl && ref_v==0 && ref_h==9'h0c0 && !startup_trace_static[2]) begin
            startup_trace_static[2] <= 1;
            $display("STARTUP static V0 H192 tuple=%h start=%b hstart=%b scr_bad=%b obj_state=%h draw=%b s1=%h s2=%h",ref_tuple,ref_scr_start,ref_hstart,ref_scr_bad,ref_obj_state,ref_draw_busy,ref_scroll1_trace,ref_scroll2_trace);
        end
        if (ref_lvbl && ref_lhbl && static_capture_armed && ref_v<9'd3 && ref_h>=9'h0c0) begin
            index = ref_v*320 + ref_h-9'h0c0;
            if (index<960 && !static_seen[index]) begin
                static_seen[index] <= 1;
                static_seen_count <= static_seen_count + 1;
                static_original_pixels[index] <= ref_tuple;
            end
        end
        if (dut_lvbl && dut_v==0 && dut_h==9'h080 && !startup_trace_fast[0]) begin
            startup_trace_fast[0] <= 1;
            $display("STARTUP fast V0 H128 start=%b hstart=%b scr_bad=%b obj_state=%h draw=%b s1=%h s2=%h",dut_scr_start,dut_hstart,dut_scr_bad,dut_obj_state,dut_draw_busy,dut_scroll1_trace,dut_scroll2_trace);
        end
        if (dut_lvbl && dut_v==0 && dut_h==9'h090 && !startup_trace_fast[1]) begin
            startup_trace_fast[1] <= 1;
            $display("STARTUP fast V0 H144 start=%b hstart=%b scr_bad=%b obj_state=%h draw=%b s1=%h s2=%h",dut_scr_start,dut_hstart,dut_scr_bad,dut_obj_state,dut_draw_busy,dut_scroll1_trace,dut_scroll2_trace);
        end
        if (dut_lvbl && dut_v==0 && dut_h==9'h0c0 && !startup_trace_fast[2]) begin
            startup_trace_fast[2] <= 1;
            $display("STARTUP fast V0 H192 tuple=%h start=%b hstart=%b scr_bad=%b obj_state=%h draw=%b s1=%h s2=%h",dut_tuple,dut_scr_start,dut_hstart,dut_scr_bad,dut_obj_state,dut_draw_busy,dut_scroll1_trace,dut_scroll2_trace);
        end
        if (capture_mode!=0 && dut_scr_bad && dut_lvbl && dut_v<9'd3)
            active_scr_bad_count <= active_scr_bad_count + 1;
        if (capture_mode!=0 && dut_lhbl && dut_lvbl && dut_v<9'd3 && dut_draw_busy)
            active_sprite_busy_count <= active_sprite_busy_count + 1;
        if (capture_mode!=0 && dut_h==9'h080 && dut_lvbl && dut_v>0 && dut_v<9'd3) begin
            hscan_budget_checks <= hscan_budget_checks + 1;
            if (dut_original_active) original_hscan_checks <= original_hscan_checks + 1;
            else fast_hscan_checks <= fast_hscan_checks + 1;
            if (dut_done1 !== 1'b1 || dut_done2 !== 1'b1)
                fail("scroll engines did not complete by H128");
            if (!dut_scr1_lastwrite || !dut_scr2_lastwrite)
                fail("scroll linebuffers did not commit HSCAN 511 by H128");
        end
        if (static_capture_armed && ref_h==9'h080 && ref_lvbl && ref_v>0 && ref_v<9'd3) begin
            static_hscan_checks <= static_hscan_checks + 1;
            if (ref_done1 !== 1'b1 || ref_done2 !== 1'b1)
                fail("static scroll engines did not complete by H128");
            if (!ref_scr1_lastwrite || !ref_scr2_lastwrite)
                fail("static scroll linebuffers did not commit HSCAN 511 by H128");
        end
        if (capture_mode!=0 && dut_h==9'h090 && dut_lvbl && dut_v>0 && dut_v<9'd3) begin
            scroll_latch_checks <= scroll_latch_checks + 1;
            if (dut_original_active) original_scroll_checks <= original_scroll_checks + 1;
            else fast_scroll_checks <= fast_scroll_checks + 1;
            if (uut.uut.u_tilemap.u_char.rowscr1==0 || uut.uut.u_tilemap.u_char.colscr1==0 ||
                uut.uut.u_tilemap.u_char.rowscr1==uut.uut.u_tilemap.scr1_hpos[9:0])
                fail("row/column scroll samples were not latched before H144");
        end
        if (capture_mode != 0 && dut_lvbl && dut_lhbl && dut_v<9'd3 && dut_h>=9'h0c0) begin
            index = dut_v*320 + dut_h-9'h0c0;
            if (index < 960) begin
                if (seen[index]) fail("duplicate active source coordinate");
                if ((^dut_tuple) === 1'bx) begin
                    $display("X tuple V/H=%0d/%0d char=%h scr1=%h scr2=%h obj=%h pal=%h rgb=%h",
                        dut_v,dut_h,dut_tuple[69:63],dut_tuple[62:52],dut_tuple[51:41],
                        dut_tuple[40:29],dut_tuple[28:18],dut_tuple[17:0]);
                    fail("X/Z in sampled layer, palette, or DAC tuple");
                end
                seen[index] <= 1;
                seen_count <= seen_count + 1;
                if (dut_h==9'h0c0) checked_endpoints[0] <= 1;
                if (dut_h==9'h1ff) checked_endpoints[1] <= 1;
                if (dut_h==9'h0c0 && dut_v==0) checked_endpoints[2] <= 1;
                if (dut_h==9'h1ff && dut_v==2) checked_endpoints[3] <= 1;
                if (dut_tuple[65:63] != 3'b0) begin
                    saw_char_data <= 1;
                    if (capture_mode==2 || capture_mode==4) fast_raw_layers[0] <= 1;
                    if (capture_mode==3) original_raw_layers[0] <= 1;
                end
                if (dut_tuple[54:52] != 3'b0) begin
                    saw_scr1_data <= 1;
                    if (capture_mode==2 || capture_mode==4) fast_raw_layers[1] <= 1;
                    if (capture_mode==3) original_raw_layers[1] <= 1;
                end
                if (dut_tuple[43:41] != 3'b0) begin
                    saw_scr2_data <= 1;
                    if (capture_mode==2 || capture_mode==4) fast_raw_layers[2] <= 1;
                    if (capture_mode==3) original_raw_layers[2] <= 1;
                end
                if (dut_tuple[32:29] != 4'b0) begin
                    saw_obj_data <= 1;
                    if (capture_mode==2 || capture_mode==4) fast_raw_layers[3] <= 1;
                    if (capture_mode==3) original_raw_layers[3] <= 1;
                end
                if (capture_mode==2) fast_pixels[index] <= dut_tuple;
                if (capture_mode==3 && dut_tuple !== static_original_pixels[index]) begin
                    mismatch_count <= mismatch_count + 1;
                    $display("live original mismatch v=%0d h=%0d got=%h expected=%h",dut_v,dut_h,dut_tuple,static_original_pixels[index]);
                    fail("live original output differs from static original coordinates");
                end
                if (capture_mode==4 && dut_tuple !== fast_pixels[index]) begin
                    mismatch_count <= mismatch_count + 1;
                    $display("live fast mismatch v=%0d h=%0d got=%h expected=%h",dut_v,dut_h,dut_tuple,fast_pixels[index]);
                    fail("live fast output differs from power-up fast coordinates");
                end
                if (capture_mode==2 || capture_mode==4) begin
                    fast_selected_layers <= fast_selected_layers | dut_selected;
                end
                if (capture_mode==3) begin
                    original_selected_layers <= original_selected_layers | dut_selected;
                end
                if (capture_mode==2 || capture_mode==3 || capture_mode==4)
                    selected_layers <= selected_layers | dut_selected;
            end
        end
    end
    // The object scanner consumes the hstart pulse at this same clk edge.
    // Check its previous line's completion immediately before that transition.
    if (capture_mode!=0 && !rst && uut.uut.u_tilemap.hstart && !uut.uut.u_obj.u_scan.hstart_l &&
        dut_lvbl && dut_v>0 && dut_v<9'd3) begin
        sprite_budget_checks <= sprite_budget_checks + 1;
        if (dut_original_active) original_sprite_checks <= original_sprite_checks + 1;
        else fast_sprite_checks <= fast_sprite_checks + 1;
        if (dut_draw_busy || !dut_scan_idle)
            fail("object list/draw did not finish before next H129");
    end
end

initial begin
    repeat (8) @(posedge clk);
    rst = 0;

    // S16B standard page tables and distinct scroll settings. Bit 15 enables
    // row scroll in H position and column scroll in V position for plane 1.
    cpu_write(12'h740, 16'h0000); // SCR1 standard pages
    cpu_write(12'h741, 16'h0000); // SCR2 standard pages
    cpu_write(12'h74c, 16'h8001); // SCR1 row-scroll enable + H offset
    cpu_write(12'h748, 16'h8002); // SCR1 column-scroll enable + V offset
    cpu_write(12'h74d, 16'h0003); // SCR2 fixed H offset
    cpu_write(12'h749, 16'h0004); // SCR2 fixed V offset

    req_57Hz = 0;
    repeat (2) @(posedge clk);
    if (uut.uut.u_tilemap.u_mmr.scr1_hpos_std !== 16'h8001 ||
        uut.uut.u_tilemap.u_mmr.scr1_vpos_std !== 16'h8002 ||
        uut.uut.u_tilemap.u_mmr.scr2_hpos_std !== 16'h0003 ||
        uut.uut.u_tilemap.u_mmr.scr2_vpos_std !== 16'h0004)
        fail("S16B CPU writes did not decode to the expected standard MMR registers");

    // `altscr*` is read from the initialized row table before the effective
    // h/v-position mux is defined. Observe each real raster at H144, after its
    // H134/135 and H142/143 row-table reads have completed.
    while (ref_h!=9'h090) @(posedge clk);
    while (dut_h!=9'h090) @(posedge clk);
    repeat (2) @(posedge clk);
    if (uut.uut.u_tilemap.scr1_hpos !== 16'h8001 || uut.uut.u_tilemap.scr1_vpos !== 16'h8002 ||
        uut.uut.u_tilemap.scr2_hpos !== 16'h0003 || uut.uut.u_tilemap.scr2_vpos !== 16'h0004)
        fail("S16B effective H/V positions did not follow initialized row-table selects");
    if (dut_scroll_en !== 4'b0011) fail("S16B MMR did not enable SCR1 row and column scroll");

    // Capture from the first active rows after legal MMR and row-table setup.
    // Both fixture responders publish address-tagged data after four clocks
    // and hold valid/data until the requested address changes.
    static_capture_armed = 1;
    arm_capture(2);
    while (static_seen_count < 960) @(posedge clk);
    if (static_seen_count != 960) fail("static reference missed active source coordinates");
    for (i=0; i<960; i=i+1) begin
        if (fast_pixels[i] !== static_original_pixels[i]) begin
            mismatch_count = mismatch_count + 1;
            $display("static-fast mismatch v=%0d h=%0d fast=%h original=%h",i/320,i%320+192,fast_pixels[i],static_original_pixels[i]);
            fail("static original and fast active tuples differ");
        end
    end

    // One live fast-to-original request is committed at the production timer's
    // safe blanking boundary. Check line-buffer reacquisition against the static
    // original source-coordinate cache.
    req_57Hz = 1;
    wait (dut_original_active);
    arm_capture(3);
    req_57Hz = 0;
    wait (!dut_original_active);
    arm_capture(4);

    $display("FINALDIAG budget H128 static/fast/original=%0d/%0d/%0d H144 fast/original=%0d/%0d sprite fast/original=%0d/%0d",
        static_hscan_checks,fast_hscan_checks,original_hscan_checks,
        fast_scroll_checks,original_scroll_checks,fast_sprite_checks,original_sprite_checks);
    $display("FINALDIAG capture seen dynamic/static=%0d/%0d endpoints=%b mismatch=%0d commits=%0d scr_bad=%0d active_draw=%0d",
        seen_count,static_seen_count,checked_endpoints,mismatch_count,timing_commits,
        active_scr_bad_count,active_sprite_busy_count);
    $display("FINALDIAG raw layers fast/original=%b/%b priority fast/original=%b/%b selected=%b data char/scr1/scr2/obj=%b%b%b%b",
        fast_raw_layers,original_raw_layers,fast_selected_layers,original_selected_layers,
        selected_layers,saw_char_data,saw_scr1_data,saw_scr2_data,saw_obj_data);

    if (active_scr_bad_count != 0) fail("scr_bad asserted on tested active rows");
    if (fast_hscan_checks < 4 || original_hscan_checks < 2 || static_hscan_checks < 2)
        fail("insufficient per-profile H128 scroll-budget observations");
    if (fast_scroll_checks < 4 || original_scroll_checks < 2)
        fail("insufficient per-profile H144 row/column observations");
    if (fast_sprite_checks < 4 || original_sprite_checks < 2)
        fail("insufficient per-profile sprite-list budget observations");
    if (timing_commits != 2) fail("expected exactly one live switch in each direction");
    if (checked_endpoints !== 4'b1111) fail("first/last active coordinate was not captured");
    if (!(saw_char_data && saw_scr1_data && saw_scr2_data && saw_obj_data) ||
        fast_raw_layers !== 4'b1111 || original_raw_layers !== 4'b1111)
        fail("one or more raw graphics layer tuples stayed transparent");
    if (fast_selected_layers !== 4'b1111 || original_selected_layers !== 4'b1111 || selected_layers !== 4'b1111)
        fail("priority did not select all four graphics layers in both profiles");
    if (mismatch_count != 0) fail("unexpected active-coordinate mismatch");
    if (timer_s16_checks < 1000 || timer_s18_checks < 1000 || timer_hb_checks < 1000)
        fail("fixed timer equivalence did not collect enough cycle samples");
    if (timer_s16_req0==0 || timer_s16_req1==0 || timer_s18_req0==0 || timer_s18_req1==0 ||
        timer_hb_req0==0 || timer_hb_req1==0)
        fail("fixed timer request did not exercise both values on enabled samples");

    $display("video16_timing: fast/original tuples matched 320x3; live fast-to-original-to-fast passed; commits=%0d lines=%0d fast/orig H128=%0d/%0d H144=%0d/%0d sprite=%0d/%0d active-draw samples=%0d",timing_commits,line_count,fast_hscan_checks,original_hscan_checks,fast_scroll_checks,original_scroll_checks,fast_sprite_checks,original_sprite_checks,active_sprite_busy_count);
    $display("PASS");
    $finish;
end

endmodule

module fixed_timer_equivalence #(
    parameter [8:0] HB_END = 9'h0bf,
    parameter [8:0] HS_END = 9'h09e
)(
    input clk,
    input pxl_cen,
    input req_57Hz,
    output reg [31:0] checked_samples = 0,
    output reg [31:0] req0_samples = 0,
    output reg [31:0] req1_samples = 0
);

wire [8:0] fixed_vdump, fixed_vrender, fixed_vrender1, fixed_H;
wire fixed_Hinit, fixed_Vinit, fixed_LHBL, fixed_LVBL, fixed_HS, fixed_VS;
wire fixed_is_57Hz;
wire [8:0] ref_vdump, ref_vrender, ref_vrender1, ref_H;
wire ref_Hinit, ref_Vinit, ref_LHBL, ref_LVBL, ref_HS, ref_VS;
wire [41:0] fixed_timing = {fixed_vdump,fixed_vrender,fixed_vrender1,fixed_H,
                            fixed_Hinit,fixed_Vinit,fixed_LHBL,fixed_LVBL,fixed_HS,fixed_VS};
wire [41:0] ref_timing = {ref_vdump,ref_vrender,ref_vrender1,ref_H,
                          ref_Hinit,ref_Vinit,ref_LHBL,ref_LVBL,ref_HS,ref_VS};

jts16_vtimer #(.HB_END(HB_END),.HS_END(HS_END)) u_fixed(
    .clk(clk), .pxl_cen(pxl_cen), .req_57Hz(req_57Hz), .is_57Hz(fixed_is_57Hz),
    .vdump(fixed_vdump), .vrender(fixed_vrender), .vrender1(fixed_vrender1), .H(fixed_H),
    .Hinit(fixed_Hinit), .Vinit(fixed_Vinit), .LHBL(fixed_LHBL), .LVBL(fixed_LVBL),
    .HS(fixed_HS), .VS(fixed_VS)
);

jtframe_vtimer #(
    .HB_START(9'h1ff), .HB_END(HB_END), .HCNT_START(9'h070), .HCNT_END(9'h1ff),
    .VB_START(9'h0df), .VB_END(9'h105), .VCNT_END(9'h105),
    .VS_START(9'h0ef), .VS_END(9'h0f3), .HS_START(9'h080), .HS_END(HS_END)
) u_reference(
    .clk(clk), .pxl_cen(pxl_cen), .vdump(ref_vdump), .vrender(ref_vrender),
    .vrender1(ref_vrender1), .H(ref_H), .Hinit(ref_Hinit), .Vinit(ref_Vinit),
    .LHBL(ref_LHBL), .LVBL(ref_LVBL), .HS(ref_HS), .VS(ref_VS)
);

always @(negedge clk) begin
    if ((^fixed_timing)===1'bx || (^ref_timing)===1'bx)
        $fatal(1,"fixed_timer_equivalence X/Z HB_END=%h HS_END=%h",HB_END,HS_END);
    if (fixed_timing !== ref_timing) begin
        $display("timer mismatch HB_END=%h HS_END=%h req=%b fixed=%h ref=%h",
            HB_END,HS_END,req_57Hz,fixed_timing,ref_timing);
        $fatal(1,"fixed timer differs from jtframe_vtimer");
    end
    if (fixed_is_57Hz !== 1'b1)
        $fatal(1,"fixed timer did not hold is_57Hz high with req=%b",req_57Hz);
    checked_samples <= checked_samples + 1'b1;
end

always @(posedge clk) if (pxl_cen) begin
    if (req_57Hz) req1_samples <= req1_samples + 1'b1;
    else          req0_samples <= req0_samples + 1'b1;
end

endmodule

module video16_case #(
    parameter DUAL_RATE=0
)(
    input clk, rst, pxl_cen, pxl2_cen,
    input req_57Hz,
    input char_cs,
    input [12:1] addr,
    input [15:0] din,
    input [1:0] dsn,
    output [8:0] H, V, vrender,
    output HS, VS, LHBL, LVBL,
    output [69:0] tuple,
    output scr_bad,
    output [3:0] scroll_en,
    output done1, done2,
    output [8:0] hscan1, hscan2,
    output draw_busy, scan_idle, original_active,
    output [3:0] selected,
    output scr1_lastwrite, scr2_lastwrite,
    output hstart, scr_start,
    output [60:0] scroll1_trace, scroll2_trace,
    output [3:0] obj_state
);

wire [13:2] char_addr;
wire [31:0] char_data;
wire [15:1] map1_addr, map2_addr;
wire [15:0] map1_data, map2_data;
wire [17:2] scr1_addr, scr2_addr;
wire [31:0] scr1_data, scr2_data;
wire [20:1] obj_addr;
wire [15:0] obj_data;
wire obj_cs;
wire [11:1] pal_addr;
wire [15:0] pal_dout;
wire [15:0] char_dout, obj_dout;
wire vint;
wire [5:0] red, green, blue;
wire [8:0] hdump, vdump, vrender_i;
wire [1:0] obj_prio;
wire fix, sa, sb, obj, tprio, s1_pri, s2_pri;
wire [7:0] st_dout;
wire [3:0] gfx_en = 4'hf;
wire [7:0] debug_bus = 0;
wire [7:0] st_addr = 0;
reg [31:0] char_data_r = 0, scr1_data_r = 0, scr2_data_r = 0;
reg [15:0] map1_data_r = 0, map2_data_r = 0, obj_data_r = 0, pal_dout_r = 0;
wire char_ok, map1_ok, map2_ok, scr1_ok, scr2_ok, obj_ok;
reg [13:2] char_tag=0;
reg [15:1] map1_tag=0, map2_tag=0;
reg [17:2] scr1_tag=0, scr2_tag=0;
reg [20:1] obj_tag=0;
reg [2:0] char_age=0, map1_age=0, map2_age=0, scr1_age=0, scr2_age=0, obj_age=0;
reg char_valid=0, map1_valid=0, map2_valid=0, scr1_valid=0, scr2_valid=0, obj_valid=0;
integer char_rsp_count=0, char_rsp_x=0, map1_rsp_count=0, map1_rsp_x=0;
integer map2_rsp_count=0, map2_rsp_x=0, scr1_rsp_count=0, scr1_rsp_x=0;
integer scr2_rsp_count=0, scr2_rsp_x=0, obj_rsp_count=0, obj_rsp_x=0;
integer scr1_wr_count=0, scr1_wr_x=0, scr2_wr_count=0, scr2_wr_x=0;
reg scr1_wr_seen=0, scr2_wr_seen=0;
reg scr1_start_d=0, scr2_start_d=0;
reg scr1_lastwrite_r=0, scr2_lastwrite_r=0;
reg [8:0] scr1_first_addr=0, scr1_last_addr=0, scr2_first_addr=0, scr2_last_addr=0;
reg [10:0] scr1_first_data=0, scr1_last_data=0, scr2_first_data=0, scr2_last_data=0;
reg [8:0] scr1_hscan_dly, scr2_hscan_dly;

assign char_ok = char_valid && char_tag==char_addr;
assign map1_ok = map1_valid && map1_tag==map1_addr;
assign map2_ok = map2_valid && map2_tag==map2_addr;
assign scr1_ok = scr1_valid && scr1_tag==scr1_addr;
assign scr2_ok = scr2_valid && scr2_tag==scr2_addr;
assign obj_ok  = obj_valid  && obj_cs && obj_tag==obj_addr;
assign scr1_lastwrite = scr1_lastwrite_r;
assign scr2_lastwrite = scr2_lastwrite_r;

function [31:0] char_word(input [11:0] a);
begin
    char_word = {8'h91 ^ a[7:0], 8'h6d ^ a[11:4], 8'hb3 ^ a[7:0], 8'h4f ^ a[11:4]};
end
endfunction

function [15:0] map_word(input [14:0] a, input plane);
begin
    map_word = 16'h8000 | ((a[12:0] * 13'd17) ^ (plane ? 13'h052b : 13'h016d));
end
endfunction

function [31:0] scroll_word(input [15:0] a, input plane);
begin
    scroll_word = { (plane ? 8'hd1 : 8'h93) ^ a[7:0],
                    (plane ? 8'h76 : 8'hb5) ^ a[15:8],
                    (plane ? 8'had : 8'h5b) ^ a[7:0],
                    (plane ? 8'h3a : 8'he7) ^ a[15:8] };
end
endfunction

function [15:0] object_word(input [19:0] a);
begin
    object_word = a[3:0]==3 ? 16'hffff : 16'h1234;
end
endfunction

function [15:0] palette_word(input [10:0] a);
begin
    palette_word = 16'h1234 ^ {5'd0, a[10:8], a[7:0]};
end
endfunction

assign H=hdump;
assign V=vdump;
assign vrender=vrender_i;
assign done1=uut.u_tilemap.u_scr1.done;
assign done2=uut.u_tilemap.u_scr2.done;
assign hscan1=uut.u_tilemap.u_scr1.hscan;
assign hscan2=uut.u_tilemap.u_scr2.hscan;
assign draw_busy=uut.u_obj.u_draw.busy;
assign scan_idle=uut.u_obj.u_scan.st==0;
assign selected={obj,sb,sa,fix};
assign hstart=uut.u_tilemap.hstart;
assign scr_start=uut.u_tilemap.scr_start;
assign obj_state=uut.u_obj.u_scan.st;
assign scroll1_trace={uut.u_tilemap.u_scr1.u_linebuf.line,uut.u_tilemap.u_scr1.done,
    uut.u_tilemap.u_scr1.hscan,uut.u_tilemap.u_scr1.busy,uut.u_tilemap.u_scr1.start,
    uut.u_tilemap.u_scr1.u_linebuf.we,uut.u_tilemap.u_scr1.u_linebuf.wr_addr,
    uut.u_tilemap.u_scr1.u_linebuf.wr_data,uut.u_tilemap.u_scr1.u_linebuf.rd_addr,
    uut.u_tilemap.u_scr1.u_linebuf.rd_data};
assign scroll2_trace={uut.u_tilemap.u_scr2.u_linebuf.line,uut.u_tilemap.u_scr2.done,
    uut.u_tilemap.u_scr2.hscan,uut.u_tilemap.u_scr2.busy,uut.u_tilemap.u_scr2.start,
    uut.u_tilemap.u_scr2.u_linebuf.we,uut.u_tilemap.u_scr2.u_linebuf.wr_addr,
    uut.u_tilemap.u_scr2.u_linebuf.wr_data,uut.u_tilemap.u_scr2.u_linebuf.rd_addr,
    uut.u_tilemap.u_scr2.u_linebuf.rd_data};
assign scroll_en={uut.u_tilemap.rowscr2_en,uut.u_tilemap.colscr2_en,
                  uut.u_tilemap.rowscr1_en,uut.u_tilemap.colscr1_en};
assign tuple={uut.u_tilemap.char_pxl,uut.u_tilemap.scr1_pxl,uut.u_tilemap.scr2_pxl,
              uut.obj_pxl,pal_addr,red,green,blue};

always @(posedge clk) begin
    pal_dout_r <= palette_word(pal_addr);

    // Model a cache hit: four clocks of address-qualified latency, then a
    // level-valid response with its registered data held until the address
    // changes. This is the contract used by the production S18 ROM/cache path.
    if (rst) begin
        scr1_start_d<=0; scr2_start_d<=0;
        scr1_lastwrite_r<=0; scr2_lastwrite_r<=0;
        char_tag<=char_addr; char_age<=0; char_valid<=0;
        map1_tag<=map1_addr; map1_age<=0; map1_valid<=0;
        map2_tag<=map2_addr; map2_age<=0; map2_valid<=0;
        scr1_tag<=scr1_addr; scr1_age<=0; scr1_valid<=0;
        scr2_tag<=scr2_addr; scr2_age<=0; scr2_valid<=0;
        obj_tag<=obj_addr; obj_age<=0; obj_valid<=0;
    end else begin
        scr1_start_d<=scr_start; scr2_start_d<=scr_start;
        if (scr_start && !scr1_start_d) scr1_lastwrite_r<=0;
        else if (uut.u_tilemap.u_scr1.u_linebuf.we && pxl2_cen &&
                 uut.u_tilemap.u_scr1.u_linebuf.wr_addr==9'h1ff)
            scr1_lastwrite_r<=1;
        if (scr_start && !scr2_start_d) scr2_lastwrite_r<=0;
        else if (uut.u_tilemap.u_scr2.u_linebuf.we && pxl2_cen &&
                 uut.u_tilemap.u_scr2.u_linebuf.wr_addr==9'h1ff)
            scr2_lastwrite_r<=1;
        if (char_addr!=char_tag) begin char_tag<=char_addr; char_age<=0; char_valid<=0; end
        else if (!char_valid) begin
            if (char_age==3) begin char_data_r<=char_word(char_addr); char_valid<=1; end
            else char_age<=char_age+1'b1;
        end
        if (map1_addr!=map1_tag) begin map1_tag<=map1_addr; map1_age<=0; map1_valid<=0; end
        else if (!map1_valid) begin
            if (map1_age==3) begin map1_data_r<=map_word(map1_addr,1'b0); map1_valid<=1; end
            else map1_age<=map1_age+1'b1;
        end
        if (map2_addr!=map2_tag) begin map2_tag<=map2_addr; map2_age<=0; map2_valid<=0; end
        else if (!map2_valid) begin
            if (map2_age==3) begin map2_data_r<=map_word(map2_addr,1'b1); map2_valid<=1; end
            else map2_age<=map2_age+1'b1;
        end
        if (scr1_addr!=scr1_tag) begin scr1_tag<=scr1_addr; scr1_age<=0; scr1_valid<=0; end
        else if (!scr1_valid) begin
            if (scr1_age==3) begin scr1_data_r<=scroll_word(scr1_addr,1'b0); scr1_valid<=1; end
            else scr1_age<=scr1_age+1'b1;
        end
        if (scr2_addr!=scr2_tag) begin scr2_tag<=scr2_addr; scr2_age<=0; scr2_valid<=0; end
        else if (!scr2_valid) begin
            if (scr2_age==3) begin scr2_data_r<=scroll_word(scr2_addr,1'b1); scr2_valid<=1; end
            else scr2_age<=scr2_age+1'b1;
        end
        if (!obj_cs) begin obj_valid<=0; obj_age<=0; end
        else if (obj_addr!=obj_tag) begin obj_tag<=obj_addr; obj_age<=0; obj_valid<=0; end
        else if (!obj_valid) begin
            if (obj_age==3) begin obj_data_r<=object_word(obj_addr); obj_valid<=1; end
            else obj_age<=obj_age+1'b1;
        end
    end

    if (char_ok) begin char_rsp_count<=char_rsp_count+1; if ((^char_data_r)===1'bx) char_rsp_x<=char_rsp_x+1; end
    if (map1_ok) begin map1_rsp_count<=map1_rsp_count+1; if ((^map1_data_r)===1'bx) map1_rsp_x<=map1_rsp_x+1; end
    if (map2_ok) begin map2_rsp_count<=map2_rsp_count+1; if ((^map2_data_r)===1'bx) map2_rsp_x<=map2_rsp_x+1; end
    if (scr1_ok) begin scr1_rsp_count<=scr1_rsp_count+1; if ((^scr1_data_r)===1'bx) scr1_rsp_x<=scr1_rsp_x+1; end
    if (scr2_ok) begin scr2_rsp_count<=scr2_rsp_count+1; if ((^scr2_data_r)===1'bx) scr2_rsp_x<=scr2_rsp_x+1; end
    if (obj_ok)  begin obj_rsp_count<=obj_rsp_count+1; if ((^obj_data_r)===1'bx) obj_rsp_x<=obj_rsp_x+1; end

    if (uut.u_tilemap.u_scr1.u_linebuf.we && pxl2_cen) begin
        scr1_wr_count<=scr1_wr_count+1;
        if ((^uut.u_tilemap.u_scr1.u_linebuf.wr_data)===1'bx) scr1_wr_x<=scr1_wr_x+1;
        if (!scr1_wr_seen) begin scr1_first_addr<=uut.u_tilemap.u_scr1.u_linebuf.wr_addr; scr1_first_data<=uut.u_tilemap.u_scr1.u_linebuf.wr_data; scr1_wr_seen<=1; end
        scr1_last_addr<=uut.u_tilemap.u_scr1.u_linebuf.wr_addr; scr1_last_data<=uut.u_tilemap.u_scr1.u_linebuf.wr_data;
    end
    if (uut.u_tilemap.u_scr2.u_linebuf.we && pxl2_cen) begin
        scr2_wr_count<=scr2_wr_count+1;
        if ((^uut.u_tilemap.u_scr2.u_linebuf.wr_data)===1'bx) scr2_wr_x<=scr2_wr_x+1;
        if (!scr2_wr_seen) begin scr2_first_addr<=uut.u_tilemap.u_scr2.u_linebuf.wr_addr; scr2_first_data<=uut.u_tilemap.u_scr2.u_linebuf.wr_data; scr2_wr_seen<=1; end
        scr2_last_addr<=uut.u_tilemap.u_scr2.u_linebuf.wr_addr; scr2_last_data<=uut.u_tilemap.u_scr2.u_linebuf.wr_data;
    end
end

jts18_video16 #(.DUAL_RATE(DUAL_RATE)) uut(
    .rst(rst), .clk(clk), .pxl2_cen(pxl2_cen), .pxl_cen(pxl_cen),
    .video_en(1'b1), .req_57Hz(req_57Hz), .gray_n(1'b1),
    .dip_pause(1'b0), .char_cs(char_cs), .objram_cs(1'b0), .addr(addr), .din(din), .dsn(dsn),
    .char_dout(char_dout), .obj_dout(obj_dout), .vint(vint), .is_57Hz(original_active), .flip(1'b0),
    .char_ok(char_ok), .char_addr(char_addr), .char_data(char_data_r),
    .map1_ok(map1_ok), .map1_addr(map1_addr), .map1_data(map1_data_r),
    .scr1_ok(scr1_ok), .scr1_addr(scr1_addr), .scr1_data(scr1_data_r),
    .map2_ok(map2_ok), .map2_addr(map2_addr), .map2_data(map2_data_r),
    .scr2_ok(scr2_ok), .scr2_addr(scr2_addr), .scr2_data(scr2_data_r),
    .obj_ok(obj_ok), .obj_cs(obj_cs), .obj_addr(obj_addr), .obj_data(obj_data_r),
    .HS(HS), .VS(VS), .LHBL(LHBL), .LVBL(LVBL), .hdump(hdump), .vdump(vdump), .vrender(vrender_i),
    .red(red), .green(green), .blue(blue), .obj_prio(obj_prio), .fix(fix), .sa(sa), .sb(sb),
    .obj(obj), .tprio(tprio), .s1_pri(s1_pri), .s2_pri(s2_pri),
    .pal_addr(pal_addr), .pal_dout(pal_dout_r), .gfx_en(gfx_en), .debug_bus(debug_bus),
    .st_addr(st_addr), .st_dout(st_dout), .scr_bad(scr_bad)
);

endmodule
