`timescale 1ns/1ps

module test;

reg clk=0;
always #5 clk=~clk;

reg rst=1;
reg pxl_cen=0, pxl2_cen=0;
reg hs=0, vs=0, lhbl=0, lvbl=0;
wire [9:0] x, line_pixels, active_pixels;
wire [8:0] y, frame_y, frame_lines, active_lines;
wire [9:0] hs_to_active, vs_to_active_pixel;
wire [8:0] vs_to_active_line;
wire [12:0] hs_to_active_clks, vs_to_active_clks;
wire line_start, frame_start;
wire h_active_start, h_active_end, v_active_start, v_active_end;
wire geometry_valid, locked, timing_change, phase_error;

integer pixel_no=0, line_no=0, total_pixels=400, total_lines=262;
integer hs_position=0, h_active_offset=80, vs_position=0;
integer v_active_line=30, v_active_pixel=0;
integer sub, p, l, edge_sub=7, v_edge_sub=7;
integer changes=0, phase_errors=0, line_events=0, frame_events=0;
integer expected_x=0, expected_y=0, active_samples=0;
integer stable_phase_errors=0;
integer max_lock_pixels=0, lock_events=0;
reg expected_y_pending=0;
reg x_origin_seen=0, y_origin_seen=0;
reg omit_hs=0, omit_vs=0;
reg inject_end_fault=0, injection_armed=0, injection_done=0;

ym7101_raster uut(
    .clk           ( clk            ),
    .rst           ( rst            ),
    .pxl_cen       ( pxl_cen        ),
    .pxl2_cen      ( pxl2_cen       ),
    .hs            ( hs             ),
    .vs            ( vs             ),
    .lhbl          ( lhbl           ),
    .lvbl          ( lvbl           ),
    .x             ( x              ),
    .y             ( y              ),
    .frame_y       ( frame_y        ),
    .line_start    ( line_start     ),
    .frame_start   ( frame_start    ),
    .h_active_start( h_active_start ),
    .h_active_end  ( h_active_end   ),
    .v_active_start( v_active_start ),
    .v_active_end  ( v_active_end   ),
    .geometry_valid( geometry_valid ),
    .locked        ( locked         ),
    .timing_change ( timing_change  ),
    .phase_error   ( phase_error    ),
    .line_pixels   ( line_pixels    ),
    .active_pixels ( active_pixels  ),
    .frame_lines   ( frame_lines    ),
    .active_lines      ( active_lines       ),
    .hs_to_active      ( hs_to_active       ),
    .vs_to_active_line ( vs_to_active_line  ),
    .vs_to_active_pixel( vs_to_active_pixel ),
    .hs_to_active_clks ( hs_to_active_clks  ),
    .vs_to_active_clks ( vs_to_active_clks  )
);

always @(posedge clk) begin
    if( timing_change ) changes <= changes + 1;
    if( phase_error ) phase_errors <= phase_errors + 1;
    if( line_start ) line_events <= line_events + 1;
    if( frame_start ) frame_events <= frame_events + 1;
    if( rst ) begin
        expected_x=0;
        expected_y=0;
        expected_y_pending=0;
        x_origin_seen=0;
        y_origin_seen=0;
    end else if( uut.raster_fault ) begin
        x_origin_seen=0;
        y_origin_seen=0;
    end else begin
      if( uut.lhbl_rise ) begin
          expected_x=0;
          x_origin_seen=1;
      end
      if( uut.lvbl_rise ) begin
          expected_y=0;
          expected_y_pending=!lhbl;
          y_origin_seen=1;
      end
      if( uut.lhbl_rise && lvbl && !uut.lvbl_rise ) begin
          if( expected_y_pending ) begin
              expected_y=0;
              expected_y_pending=0;
          end else expected_y=expected_y+1;
      end
    end
    if( !uut.raster_fault && pxl_cen && lhbl && x_origin_seen ) begin
        if( x!==expected_x[9:0] ) begin
            $display("FAIL: x coordinate expected %0d, got %0d", expected_x, x);
            $fatal(1);
        end
        expected_x=expected_x+1;
        active_samples=active_samples+1;
        if( lvbl && y_origin_seen && y!==expected_y[8:0] ) begin
            $display("FAIL: y coordinate expected %0d, got %0d at frame line %0d", expected_y, y, frame_y);
            $fatal(1);
        end
    end
end

always @(negedge clk) if( inject_end_fault && locked && uut.lvbl_fall ) begin
    force uut.pxl_age = 4'd8;
    inject_end_fault = 0;
    injection_armed = 1;
end

always @(posedge clk) if( injection_armed ) begin
    #2 release uut.pxl_age;
    injection_armed = 0;
    injection_done = 1;
end

task step_pixel;
integer frame_span, frame_phase, active_phase, active_origin;
begin
    for( sub=0; sub<8; sub=sub+1 ) begin
        @(negedge clk);
        pxl_cen  = sub==7;
        pxl2_cen = sub==3 || sub==7;
        @(posedge clk);
        #1;
        if( sub==edge_sub ) begin
            p = pixel_no;
            l = line_no;
            frame_span = total_pixels*total_lines;
            frame_phase = (l*total_pixels+p-vs_position+frame_span)%frame_span;
            active_origin = (hs_position+h_active_offset)%total_pixels;
            active_phase = (p-active_origin+total_pixels)%total_pixels;
            hs   = !omit_hs && (p-hs_position+total_pixels)%total_pixels<4;
            vs   = !omit_vs && frame_phase<2*total_pixels;
            lhbl = active_phase<320;
        end
        if( sub==v_edge_sub ) begin
            p = v_edge_sub==0 ? pixel_no-1 : pixel_no;
            l = line_no;
            if( p<0 ) begin
                p = total_pixels-1;
                l = line_no-1;
                if( l<0 ) l = total_lines-1;
            end
            frame_span = total_pixels*total_lines;
            frame_phase = (l*total_pixels+p-vs_position+frame_span)%frame_span;
            active_phase = (frame_phase-v_active_line*total_pixels-v_active_pixel+frame_span)%frame_span;
            lvbl = active_phase<224*total_pixels;
        end
        if( sub==edge_sub ) begin
            pixel_no = pixel_no+1;
            if( pixel_no==total_pixels ) begin
                pixel_no=0;
                line_no=line_no+1;
                if( line_no==total_lines ) line_no=0;
            end
        end
    end
end
endtask

task step_pixels;
input integer count;
integer i;
begin
    for( i=0; i<count; i=i+1 ) step_pixel;
end
endtask

task wait_for_lock;
input integer max_pixels;
integer i;
begin
    i=0;
    while( !locked && i<max_pixels ) begin
        step_pixel;
        i=i+1;
    end
    if( !locked ) begin
        $display("FAIL: raster did not lock after %0d pixels: line=%0d active=%0d frame=%0d height=%0d", max_pixels,
            line_pixels, active_pixels, frame_lines, active_lines);
        $display("STATE: good_lines=%0d good_frames=%0d widths=%0d/%0d have=%0d/%0d phase=%0d/%0d", uut.good_lines, uut.good_frames,
            uut.line_width_ok, uut.active_width_ok, uut.have_frame, uut.have_active_width, uut.lhbl_phase, uut.hs_phase);
        $fatal(1);
    end
    if( i>max_lock_pixels ) max_lock_pixels=i;
    lock_events=lock_events+1;
end
endtask

task wait_for_unlock;
input integer max_pixels;
integer i;
begin
    i=0;
    while( locked && i<max_pixels ) begin
        step_pixel;
        i=i+1;
    end
    if( locked ) begin
        $display("FAIL: geometry change did not clear lock");
        $fatal(1);
    end
end
endtask

initial begin
    repeat(4) @(negedge clk);
    rst=0;
    // Acquire after reset is released part way through a live 400x262 raster.
    step_pixels(220*400);
    rst=1;
    step_pixels(1);
    rst=0;
    wait_for_lock(3*262*400);
    if( line_pixels!==400 || active_pixels!==320 || frame_lines!==262 || active_lines!==224 ||
        hs_to_active!==80 || vs_to_active_line!==30 || vs_to_active_pixel!==0 ||
        hs_to_active_clks!==640 || vs_to_active_clks!==0 ) begin
        $display("FAIL: measured geometry %0d/%0d x %0d/%0d offsets %0d/%0d/%0d clocks %0d/%0d", line_pixels, frame_lines, active_pixels, active_lines, hs_to_active, vs_to_active_line, vs_to_active_pixel, hs_to_active_clks, vs_to_active_clks);
        $fatal(1);
    end
    if( active_samples < 2*320*224 ) begin
        $display("FAIL: coordinate oracle saw only %0d active pixel samples", active_samples);
        $fatal(1);
    end

    // Move syncs independently so LVBL rises before the next HS boundary.
    hs_position=20;
    h_active_offset=95;
    vs_position=7;
    v_active_line=35;
    v_active_pixel=11;
    wait_for_unlock(2*400);
    wait_for_lock(5*262*400);
    if( hs_to_active!==95 || vs_to_active_line!==35 || vs_to_active_pixel!==398 ||
        hs_to_active_clks!==760 || vs_to_active_clks!==3184 ) begin
        $display("FAIL: changed offsets were not measured: %0d/%0d/%0d clocks %0d/%0d", hs_to_active, vs_to_active_line, vs_to_active_pixel, hs_to_active_clks, vs_to_active_clks);
        $fatal(1);
    end

    // Shift stable raster edges by one clk48 tick; invalidate once, relearn, and relock.
    edge_sub=6;
    wait_for_unlock(2*400);
    wait_for_lock(5*262*400);
    if( phase_errors==0 ) begin
        $display("FAIL: stable one-clock edge phase shift was not reported");
        $fatal(1);
    end
    edge_sub=7;
    wait_for_unlock(2*400);
    wait_for_lock(5*262*400);
    stable_phase_errors=phase_errors;

    // Shift only LVBL by one MCLK tick while preserving whole-pixel offsets.
    v_edge_sub=0;
    wait_for_unlock(2*262*400);
    wait_for_lock(5*262*400);
    if( vs_to_active_pixel!==398 || vs_to_active_clks!==3185 ) begin
        $display("FAIL: fractional LVBL shift was not measured: %0d px / %0d clocks", vs_to_active_pixel, vs_to_active_clks);
        $fatal(1);
    end
    v_edge_sub=7;
    wait_for_unlock(2*262*400);
    wait_for_lock(5*262*400);
    if( vs_to_active_clks!==3184 ) begin
        $display("FAIL: restored LVBL phase measured %0d clocks", vs_to_active_clks);
        $fatal(1);
    end

    // A line-total change clears lock and must reacquire on the new raster.
    total_pixels=384;
    pixel_no=0;
    wait_for_unlock(2*400);
    wait_for_lock(3*262*400);
    if( line_pixels!==384 || active_pixels!==320 || frame_lines!==262 || active_lines!==224 ) begin
        $display("FAIL: changed geometry %0d/%0d x %0d/%0d", line_pixels, frame_lines, active_pixels, active_lines);
        $fatal(1);
    end
    if( changes==0 ) begin
        $display("FAIL: line-total change was not reported");
        $fatal(1);
    end

    // Reacquire with both a shortened frame and a distinct 261-line total.
    total_lines=260;
    line_no=0;
    wait_for_unlock(2*260*384);
    wait_for_lock(4*260*384);
    if( frame_lines!==260 || active_lines!==224 ) begin
        $display("FAIL: 260-line geometry %0d/%0d", frame_lines, active_lines);
        $fatal(1);
    end
    total_lines=261;
    line_no=0;
    wait_for_unlock(2*261*384);
    wait_for_lock(4*261*384);
    if( frame_lines!==261 || active_lines!==224 ) begin
        $display("FAIL: 261-line geometry %0d/%0d", frame_lines, active_lines);
        $fatal(1);
    end
    if( phase_errors!=stable_phase_errors ) begin
        $display("FAIL: stable raster changed phase-error count (%0d -> %0d)", stable_phase_errors, phase_errors);
        $fatal(1);
    end

    // A stopped pixel enable must invalidate a currently locked tracker.
    pxl_cen=0;
    pxl2_cen=0;
    repeat(16) @(negedge clk);
    if( locked || geometry_valid || phase_errors<=stable_phase_errors ) begin
        $display("FAIL: stopped pixel enables did not invalidate a locked geometry");
        $fatal(1);
    end
    wait_for_lock(5*261*384);
    stable_phase_errors=phase_errors;

    // Force an enable-age fault on the same edge as an otherwise valid LVBL fall.
    inject_end_fault=1;
    step_pixels(total_lines*384);
    if( !injection_done || locked || geometry_valid ) begin
        $display("FAIL: same-edge LVBL-end fault was allowed to grant lock");
        $fatal(1);
    end
    wait_for_lock(5*261*384);

    // Missing VS must invalidate lock even when VS never returns.
    omit_vs=1;
    step_pixels((261+4)*384);
    if( locked || geometry_valid ) begin
        $display("FAIL: missing VS edge did not invalidate geometry");
        $fatal(1);
    end
    omit_vs=0;
    wait_for_lock(4*261*384);

    // Missing HS must invalidate lock before the edge returns.
    omit_hs=1;
    step_pixels(2*384);
    if( locked || geometry_valid ) begin
        $display("FAIL: missing HS edge did not invalidate geometry");
        $fatal(1);
    end
    omit_hs=0;

    if( line_events==0 || frame_events==0 ) begin
        $display("FAIL: external line/frame event pulses absent");
        $fatal(1);
    end
    $display("PASS: geometry %0d x %0d active %0d x %0d; changed=%0d, line/frame pulses=%0d/%0d, coordinate samples=%0d, max lock wait=%0d pixels over %0d acquisitions",
        line_pixels, frame_lines, active_pixels, active_lines, changes, line_events, frame_events, active_samples, max_lock_pixels, lock_events);
    $finish;
end

endmodule
