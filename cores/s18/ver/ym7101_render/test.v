`timescale 1ns/1ps

module test;

reg clk = 0, clk48 = 0;
reg reset_n = 0;
always #5.208 clk = ~clk;
always @(posedge clk) clk48 <= ~clk48;

`ifdef PASSIVE_TEST
reg use48 = 1;
reg compare_en = 0;
localparam PASSIVE_MODE = 1;
`else
reg use48 = 0;
reg compare_en = 1;
localparam PASSIVE_MODE = 0;
`endif
`ifdef PASSIVE_TEST
`ifdef PASSIVE_384_260
`ifdef IRQ_HV_SCENARIO
localparam integer CPU_START_DELAY96 = 2;
`else
localparam integer CPU_START_DELAY96 = 0;
`endif
`else
localparam integer CPU_START_DELAY96 = 0;
`endif
`else
localparam integer CPU_START_DELAY96 = 0;
`endif
wire irq_watch_mclk = use48 ? clk48 : clk;
`ifdef PRODUCTION_TIMER_SCENARIO
localparam [8:0] TEST_HCNT_START = 9'h080;
localparam [8:0] TEST_VB_END = 9'h103, TEST_VS_START = 9'h0ed;
localparam [8:0] TEST_VS_END = 9'h0f1, TEST_VCNT_END = 9'h103;
localparam [9:0] TEST_LINE_PIXELS = 10'd384;
localparam [8:0] TEST_FRAME_LINES = 9'd260;
localparam [6:0] TEST_FAST_QUOTA = 7'd72;
`elsif PASSIVE_384_260
localparam [8:0] TEST_HCNT_START = 9'h080;
localparam [8:0] TEST_VB_END = 9'h103, TEST_VS_START = 9'h0ed;
localparam [8:0] TEST_VS_END = 9'h0f1, TEST_VCNT_END = 9'h103;
localparam [9:0] TEST_LINE_PIXELS = 10'd384;
localparam [8:0] TEST_FRAME_LINES = 9'd260;
localparam [6:0] TEST_FAST_QUOTA = 7'd72;
`elsif PASSIVE_384_261
localparam [8:0] TEST_HCNT_START = 9'h080;
localparam [8:0] TEST_VB_END = 9'h104, TEST_VS_START = 9'h0ee;
localparam [8:0] TEST_VS_END = 9'h0f2, TEST_VCNT_END = 9'h104;
localparam [9:0] TEST_LINE_PIXELS = 10'd384;
localparam [8:0] TEST_FRAME_LINES = 9'd261;
localparam [6:0] TEST_FAST_QUOTA = 7'd72;
`else
localparam [8:0] TEST_HCNT_START = 9'h070;
localparam [8:0] TEST_VB_END = 9'h105, TEST_VS_START = 9'h0ef;
localparam [8:0] TEST_VS_END = 9'h0f3, TEST_VCNT_END = 9'h105;
localparam [9:0] TEST_LINE_PIXELS = 10'd400;
localparam [8:0] TEST_FRAME_LINES = 9'd262;
localparam [6:0] TEST_FAST_QUOTA = 7'd40;
`endif
`ifdef PASSIVE_384_260
localparam TEST_GEOMETRY_384_260 = 1;
`else
localparam TEST_GEOMETRY_384_260 = 0;
`endif
`ifdef PASSIVE_384_261
localparam TEST_GEOMETRY_384_261 = 1;
`else
localparam TEST_GEOMETRY_384_261 = 0;
`endif
initial begin
    if ((TEST_GEOMETRY_384_260 && TEST_GEOMETRY_384_261) ||
        ((TEST_GEOMETRY_384_260 || TEST_GEOMETRY_384_261) && !PASSIVE_MODE)) begin
        $display("FAIL: 384 raster geometry defines require exactly one PASSIVE_TEST selection");
        $fatal(1);
    end
`ifdef PASSIVE_TEST
`ifdef PASSIVE_384_260
`ifdef IRQ_HV_SCENARIO
    if (CPU_START_DELAY96!=2) begin $display("FAIL: strict 384x260 IRQ phase K must be 2"); $fatal(1); end
`else
    if (CPU_START_DELAY96!=0) begin $display("FAIL: non-IRQ 384x260 phase K must be 0"); $fatal(1); end
`endif
`else
    if (CPU_START_DELAY96!=0) begin $display("FAIL: passive400 phase K must be 0"); $fatal(1); end
`endif
`else
    if (CPU_START_DELAY96!=0) begin $display("FAIL: non-passive phase K must be 0"); $fatal(1); end
`endif
end
`ifdef PASSIVE_TEST
`define RENDER_FIXTURE
`elsif LEGACY_TEST
`define RENDER_FIXTURE
`endif
integer service_cpu_edge_index = 0;
integer service_cpu_write_accept_count = 0;
reg service_intak = 1'b0;
integer service_copy_expected_first_s0 = 0;
integer service_cpu_read_accept_count = 0;
reg copy_start_late = 0;
reg copy_late_command_fast_seen = 0;
reg copy_late_source_wrap_seen = 0;
reg copy_late_normal_commit_seen = 0;
reg [8:0] copy_late_source_h_prev = 0;
`include "service_profile.vh"
`include "irq_hv_profile.vh"
reg [2:0] phase_tb = 0;
reg [2:0] raster_phase_tb = 0;
reg pxl_cen = 0, pxl2_cen = 0;
integer raster_pixel_count = 0;
wire raster_hs, raster_vs, raster_lhbl, raster_lvbl;
wire [8:0] raster_vdump, raster_hdump;
wire raster_hinit, raster_vinit;
wire [8:0] raster_vrender, raster_vrender1;
`ifdef GEOMETRY_SWITCH_SCENARIO
`ifdef PRODUCTION_TIMER_SCENARIO
reg [1:0] geometry_switch_request = 1;
`else
reg [1:0] geometry_switch_request = 0;
`endif
reg geometry_switch_request_valid = 0;
wire [1:0] geometry_switch_mode;
wire geometry_switch_source_commit;
wire [9:0] geometry_switch_line_pixels;
wire [8:0] geometry_switch_frame_lines;
reg geometry_capture_enable = 0, geometry_capture_done = 0;
reg geometry_capture_started = 0, geometry_capture_reference = 0;
integer geometry_capture_frame = -1;
integer geometry_capture_counts [0:5];
integer geometry_capture_rgb [0:5], geometry_capture_transparent [0:5];
reg [24:0] geometry_capture_pixels [0:1919];
reg [24:0] geometry_reference_row100 [0:319];
integer geometry_source_changes = 0;
integer geometry_vs_master_count = 0, geometry_vs_previous_master = -1;
integer geometry_vs_previous_mode = -1;
reg geometry_vs_previous = 0;
integer geometry_source_cycles = 0;
integer geometry_line_previous_cycle = -1, geometry_line_expected_pixels = 0;
integer geometry_lvbl_previous_cycle = -1, geometry_lvbl_previous_mode = -1;
integer geometry_active_line_count = 0, geometry_active_pixel_count = 0;
reg geometry_lhbl_previous = 0, geometry_lvbl_previous = 0;
reg geometry_lhbl_seen_low = 0, geometry_lhbl_armed = 0;
reg geometry_commit_previous = 0;
reg geometry_prime_check_enable = 0, geometry_prime_active = 0, geometry_prime_done = 0;
reg [8:0] geometry_prime_last_h = 0;
integer geometry_prime_events = 0;
integer geometry_dut_timing_changes = 0;
reg geometry_dut_change_previous = 0;
`endif
reg render_trace_en = 0;
reg render_line_capture_en = 0;
reg render_line_current_ready = 0, render_line_legacy_ready = 0;
reg render_line_current_started = 0, render_line_legacy_started = 0;
reg render_line_current_done = 0, render_line_legacy_done = 0;
integer render_line_current_last_h = -1, render_line_legacy_last_h = -1;
integer render_line_current_events = 0, render_line_legacy_events = 0;
integer render_line_current_total = 0, render_line_legacy_total = 0;
integer render_line_current_de = 0, render_line_legacy_de = 0;
integer render_line_current_rgb = 0, render_line_legacy_rgb = 0;
integer render_line_current_ys = 0, render_line_legacy_ys = 0;
integer render_line_current_x = 0, render_line_legacy_x = 0;
integer render_line_current_first_de = -1, render_line_legacy_first_de = -1;
integer render_line_current_last_de = -1, render_line_legacy_last_de = -1;
reg [24:0] render_current_pixels [0:319];
reg [24:0] render_legacy_pixels [0:319];
reg [24:0] render_current_row0 [0:319];
reg [24:0] render_legacy_row0 [0:319];
reg render_current_row0_armed = 0, render_legacy_row0_armed = 0;
integer render_current_row0_last = -1, render_legacy_row0_last = -1;
integer render_current_row0_count = 0, render_legacy_row0_count = 0;
reg [24:0] render_external_row0 [0:319];
reg [24:0] render_external_row1 [0:319];
integer render_external_row0_count = 0, render_external_row1_count = 0;
integer render_external_row0_last = -1, render_external_row1_last = -1;
`ifdef PASSIVE_TEST
reg render_external_started = 0, render_external_complete = 0;
reg transition_coord_check_en = 0;
reg transition_origin_seen = 0;
integer render_external_frame_id = 0;
integer render_locked_line_count = 0, render_locked_last_y = -1;
reg [9:0] source_x_count = 0;
reg [8:0] source_y_count = 0;
reg source_lhbl_prev = 0, source_lvbl_prev = 0, source_vs_prev = 0;
reg source_active_line_seen = 0;
integer source_frame_id = 0;
integer service_hv_line_id = 0, service_hv_latch_line_id = 0;
reg [7:0] service_hv_ext_h_d1 = 0, service_hv_ext_h_d2 = 0;
reg [7:0] service_hv_ext_v_d1 = 0, service_hv_ext_v_d2 = 0;
wire source_lhbl_rise = raster_lhbl && !source_lhbl_prev;
wire source_lvbl_rise = raster_lvbl && !source_lvbl_prev;
wire source_vs_rise = raster_vs && !source_vs_prev;
wire [9:0] source_x_sample = source_lhbl_rise ? 10'd0 : source_x_count;
wire [8:0] source_y_sample = source_lvbl_rise ? 9'd0 :
    source_lhbl_rise && raster_lvbl ? (source_active_line_seen ? source_y_count+9'd1 : 9'd0) : source_y_count;
wire [31:0] source_x_integer = {22'd0,source_x_sample};
wire [31:0] source_y_integer = {23'd0,source_y_sample};
reg render_prime_count_active = 0, render_prime_count_done = 0;
reg [8:0] render_prime_last_h = 0;
integer render_prime_events = 0;
`endif
`ifdef PASSIVE_TEST
reg dbg_geometry_prev = 0, dbg_prime_prev = 0, dbg_seed_prev = 0;
reg dbg_v0_prev = 0, dbg_ready_prev = 0;
always @(posedge clk48) begin
    #1;
    if (!reset_n) begin
        dbg_geometry_prev = 0;
        dbg_prime_prev = 0;
        dbg_seed_prev = 0;
        dbg_v0_prev = 0;
        dbg_ready_prev = 0;
    end else begin
        if (uut_ym.passive_geometry_supported && !dbg_geometry_prev)
            $display("PASSIVE_ACQ geometry locked T/W/N/A=%0d/%0d/%0d/%0d VS-origin K=%0d,V=%0dclk H=%0dclk",
                uut_ym.passive_line_pixels,uut_ym.passive_active_pixels,uut_ym.passive_frame_lines,
                uut_ym.passive_active_lines,uut_ym.passive_vs_to_active_line,
                uut_ym.passive_vs_to_active_clks,uut_ym.passive_hs_to_active_clks);
        if (uut_ym.passive_prime_pending && !dbg_prime_prev)
            $display("PASSIVE_ACQ prime scheduled frame_y=%0d first-origin=%0d countdown=%0d quarter=%0d tick=%0d",
                uut_ym.passive_frame_y,uut_ym.passive_active_origin_line,
                uut_ym.passive_active_countdown,uut_ym.passive_quarter,uut_ym.passive_tick);
        if (uut_ym.passive_seed_active && !dbg_seed_prev)
            $display("PASSIVE_ACQ H26/V511 seed starts Q=%0d tick=%0d H/V=%0d/%0d",
                uut_ym.passive_quarter,uut_ym.passive_tick,uut_ym.l106,uut_ym.l105);
        if (uut_ym.passive_v0_committed && !dbg_v0_prev)
            $display("PASSIVE_ACQ V0 committed at frame_y=%0d H/V=%0d/%0d t38=%b",
                uut_ym.passive_frame_y,uut_ym.l106,uut_ym.l105,uut_ym.t38);
        if (uut_ym.passive_render_ready && !dbg_ready_prev)
            $display("PASSIVE_ACQ renderer ready first-origin frame_y=%0d H/V=%0d/%0d t38=%b",
                uut_ym.passive_frame_y,uut_ym.l106,uut_ym.l105,uut_ym.t38);
        dbg_geometry_prev = uut_ym.passive_geometry_supported;
        dbg_prime_prev = uut_ym.passive_prime_pending;
        dbg_seed_prev = uut_ym.passive_seed_active;
        dbg_v0_prev = uut_ym.passive_v0_committed;
        dbg_ready_prev = uut_ym.passive_render_ready;
    end
end

// Independent source-coordinate model of the free-running H/V read path:
// external coordinate -> H/V slave latch -> registered io_data/CD_o.
// This samples only the jtframe_vtimer-derived coordinate oracle and preserves
// the two MCLK stages documented by sl91/sl90 and the io_data register.
always @(posedge clk48) begin
    service_hv_ext_h_d1 <= (9'd26 + source_x_sample) >> 1;
    service_hv_ext_v_d1 <= source_y_sample[7:0] +
        ((raster_lhbl && raster_lvbl && source_x_sample>=10'd304) ? 8'd1 : 8'd0);
    service_hv_ext_h_d2 <= service_hv_ext_h_d1;
    service_hv_ext_v_d2 <= service_hv_ext_v_d1;
end
`endif
reg trace_prev_ras = 1, trace_prev_cas = 1, trace_prev_oe = 1, trace_prev_sc = 1;
reg h40_trace_en = 0;
reg h40_latch_seen = 0;
reg [29:0] h40_trace_last = 30'h3fffffff;
integer render_trace_count = 0;
integer stage_trace_count = 0;
always @(posedge clk48) begin
    if (!reset_n) phase_tb <= 0;
    else phase_tb <= phase_tb + 1'b1;
end

// The S16 timing master runs continuously, independent of VDP reset.
always @(posedge clk48) begin
    raster_phase_tb <= raster_phase_tb + 1'b1;
    pxl_cen <= raster_phase_tb == 3'd7;
    pxl2_cen <= raster_phase_tb[1:0] == 2'b11;
    if (pxl_cen) raster_pixel_count <= raster_pixel_count + 1;
end

reg phase_mon_valid = 0;
reg [1:0] phase_mon_prev = 0;
integer phase_mon_run = 0;
integer phase_mon_dwell = 0;
reg phase_mon_anchor = 0;
reg phase_mon_seed_prev = 0;
integer phase_mon_q0_extensions = 0;
always @(posedge clk48) begin
    if (!reset_n) begin
        phase_mon_valid <= 0;
        phase_mon_prev <= 0;
        phase_mon_run <= 0;
        phase_mon_dwell <= 0;
        phase_mon_anchor <= 0;
        phase_mon_seed_prev <= 0;
        phase_mon_q0_extensions <= 0;
    end else if (PASSIVE_MODE) begin
        if (uut_ym.passive_dwell!=3'd1 && uut_ym.passive_dwell!=3'd2) begin
            $display("FAIL: illegal phase dwell %0d",uut_ym.passive_dwell); $fatal(1);
        end
        case (uut_ym.passive_quarter)
            2'd0: if ({uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2} !== 4'b1001) begin
                $display("FAIL: quarter Q0 outputs %b%b%b%b",uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2); $fatal(1);
            end
            2'd1: if ({uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2} !== 4'b0110) begin
                $display("FAIL: quarter Q1 outputs %b%b%b%b",uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2); $fatal(1);
            end
            2'd2: if ({uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2} !== 4'b1010) begin
                $display("FAIL: quarter Q2 outputs %b%b%b%b",uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2); $fatal(1);
            end
            2'd3: if ({uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2} !== 4'b0101) begin
                $display("FAIL: quarter Q3 outputs %b%b%b%b",uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2); $fatal(1);
            end
            default: begin
                $display("FAIL: unknown quarter state %b",uut_ym.passive_quarter); $fatal(1);
            end
        endcase
        if (!phase_mon_valid) begin
            phase_mon_valid <= 1;
            phase_mon_prev <= uut_ym.passive_quarter;
            phase_mon_run <= 1;
            phase_mon_dwell <= {29'd0,uut_ym.passive_dwell};
            phase_mon_anchor <= uut_ym.passive_quarter==2'd0 && uut_ym.passive_prime_pending;
        end else if (uut_ym.passive_quarter==phase_mon_prev) begin
            if (uut_ym.passive_quarter==2'd0) begin
                if ((phase_mon_anchor || uut_ym.passive_prime_pending) && !uut_ym.passive_render_ready) begin
                    if (phase_mon_run>=phase_mon_dwell+7) begin
                        $display("FAIL: anchored Q0 stayed high beyond base dwell+7: dwell=%0d run=%0d",phase_mon_dwell,phase_mon_run); $fatal(1);
                    end
                end else if (phase_mon_run>=phase_mon_dwell) begin
                    $display("FAIL: Q0 did not advance on its bounded normal/fast dwell=%0d",phase_mon_dwell); $fatal(1);
                end
            end else if (phase_mon_run>=phase_mon_dwell) begin
                $display("FAIL: Q%0d held beyond dwell=%0d",uut_ym.passive_quarter,phase_mon_dwell); $fatal(1);
            end
            phase_mon_run <= phase_mon_run+1;
            if (uut_ym.passive_quarter==2'd0 && uut_ym.passive_prime_pending)
                phase_mon_anchor <= 1;
            if ({29'd0,uut_ym.passive_dwell} != phase_mon_dwell) begin
                $display("FAIL: dwell changed inside quarter Q%0d %0d->%0d",phase_mon_prev,phase_mon_dwell,uut_ym.passive_dwell); $fatal(1);
            end
        end else begin
            if (uut_ym.passive_quarter != phase_mon_prev+2'd1) begin
                $display("FAIL: quarter order %0d->%0d",phase_mon_prev,uut_ym.passive_quarter); $fatal(1);
            end
            if (phase_mon_prev==2'd0) begin
                if (phase_mon_anchor) begin
                    if (phase_mon_run < phase_mon_dwell || phase_mon_run > phase_mon_dwell+7) begin
                        $display("FAIL: anchored Q0 dwell=%0d run=%0d (max seven added clocks)",phase_mon_dwell,phase_mon_run); $fatal(1);
                    end
                    phase_mon_q0_extensions = phase_mon_q0_extensions+phase_mon_run-phase_mon_dwell;
                end else if (phase_mon_run != phase_mon_dwell) begin
                    $display("FAIL: normal Q0 dwell=%0d run=%0d",phase_mon_dwell,phase_mon_run); $fatal(1);
                end
                if (uut_ym.passive_dwell!=3'd1 && uut_ym.passive_dwell!=3'd2) begin
                    $display("FAIL: unsupported next quarter dwell %0d",uut_ym.passive_dwell); $fatal(1);
                end
            end else begin
                if (phase_mon_run != phase_mon_dwell || {29'd0,uut_ym.passive_dwell}!=phase_mon_dwell) begin
                    $display("FAIL: quarter Q%0d dwell was %0d run=%0d next=%0d",phase_mon_prev,
                        phase_mon_dwell,phase_mon_run,uut_ym.passive_dwell); $fatal(1);
                end
            end
            phase_mon_prev <= uut_ym.passive_quarter;
            phase_mon_run <= 1;
                phase_mon_dwell <= {29'd0,uut_ym.passive_dwell};
            phase_mon_anchor <= uut_ym.passive_quarter==2'd0 && uut_ym.passive_prime_pending;
        end
        if (uut_ym.passive_seed_active &&
            !(uut_ym.passive_quarter==2'd1 || uut_ym.passive_quarter==2'd2 ||
              (uut_ym.passive_quarter==2'd3 && uut_ym.passive_tick==0))) begin
            $display("FAIL: H26/V511 seed outside Q1/Q2/Q3 commit phase Q=%0d tick=%0d",
                uut_ym.passive_quarter,uut_ym.passive_tick); $fatal(1);
        end
        if (uut_ym.passive_seed_active && !phase_mon_seed_prev &&
            (uut_ym.passive_quarter!=2'd1 || uut_ym.passive_tick!=0 || uut_ym.passive_dwell!=3'd2)) begin
            $display("FAIL: seed must enter Q1/tick0 at normal dwell2, got Q=%0d tick=%0d dwell=%0d",
                uut_ym.passive_quarter,uut_ym.passive_tick,uut_ym.passive_dwell); $fatal(1);
        end
        phase_mon_seed_prev <= uut_ym.passive_seed_active;
        if (uut_ym.passive_render_ready && !uut_ym.passive_v0_committed) begin
            $display("FAIL: renderer ready before V0 preline commit"); $fatal(1);
        end
    end
end

`ifdef PASSIVE_TEST
// Independent coordinate oracle from the raw vtimer blank/pixel signals.
always @(posedge clk48) begin
    if (source_lhbl_rise && raster_lvbl) service_hv_line_id <= service_hv_line_id+1;
    source_lhbl_prev <= raster_lhbl;
    source_lvbl_prev <= raster_lvbl;
    source_vs_prev <= raster_vs;
    if (source_vs_rise) source_frame_id <= source_frame_id+1;
    if (!raster_lhbl) source_x_count <= 0;
    else if (source_lhbl_rise) source_x_count <= pxl_cen ? 10'd1 : 10'd0;
    else if (pxl_cen) source_x_count <= source_x_count+1'd1;
    if (!raster_lvbl) begin
        source_y_count <= 0;
        source_active_line_seen <= 0;
    end else if (source_lhbl_rise) begin
        if (!source_active_line_seen) begin
            source_y_count <= 0;
            source_active_line_seen <= 1;
        end else source_y_count <= source_y_count+1'd1;
    end
end
`endif

`ifdef GEOMETRY_SWITCH_SCENARIO
always @(posedge clk48) begin
    geometry_source_cycles = geometry_source_cycles+1;
    if (pxl_cen && raster_hdump==9'h1ff) begin
        if (geometry_line_previous_cycle>=0 &&
            geometry_source_cycles-geometry_line_previous_cycle != geometry_line_expected_pixels*8) begin
            $display("GEOMETRY_FAIL source line interval=%0d master clocks expected=%0d pixels*8 mode=%0d H=%0d V=%0d",
                geometry_source_cycles-geometry_line_previous_cycle,geometry_line_expected_pixels,
                geometry_switch_mode,raster_hdump,raster_vdump);
            $fatal(1);
        end
        geometry_line_previous_cycle=geometry_source_cycles;
        geometry_line_expected_pixels=geometry_switch_line_pixels;
        if (geometry_switch_request_valid &&
            geometry_switch_request!=geometry_switch_mode && raster_vdump==9'h0e0 && !raster_lvbl)
            geometry_line_expected_pixels=geometry_switch_request==0 ? 400 : 384;
    end
    if (raster_vs && !geometry_vs_previous) begin
        if (geometry_vs_previous_master>=0) begin
            integer old_lines, old_vs, old_pixels, new_lines, new_vs, new_pixels;
            integer expected_pixels, measured_pixels;
            old_lines=geometry_vs_previous_mode==0 ? 262 :
                geometry_vs_previous_mode==1 ? 260 : 261;
            old_vs=geometry_vs_previous_mode==0 ? 239 :
                geometry_vs_previous_mode==1 ? 237 : 238;
            old_pixels=geometry_vs_previous_mode==0 ? 400 : 384;
            new_lines=geometry_switch_mode==0 ? 262 :
                geometry_switch_mode==1 ? 260 : 261;
            new_vs=geometry_switch_mode==0 ? 239 :
                geometry_switch_mode==1 ? 237 : 238;
            new_pixels=geometry_switch_mode==0 ? 400 : 384;
            expected_pixels=geometry_vs_previous_mode==geometry_switch_mode ?
                new_lines*new_pixels :
                (old_lines-old_vs+224)*old_pixels+(new_vs-224)*new_pixels;
            measured_pixels=(geometry_source_cycles-geometry_vs_previous_master)/8;
            if (geometry_source_cycles-geometry_vs_previous_master != expected_pixels*8) begin
                $display("GEOMETRY_FAIL VS interval=%0d master clocks expected=%0d pixels old/new=%0d/%0d VS=%0d/%0d",
                    geometry_source_cycles-geometry_vs_previous_master,expected_pixels,
                    geometry_vs_previous_mode,geometry_switch_mode,old_vs,new_vs);
                $fatal(1);
            end
            $display("GEOMETRY_VS mode=%0d->%0d interval=%0d pixels expected=%0d",
                geometry_vs_previous_mode,geometry_switch_mode,measured_pixels,expected_pixels);
        end
        geometry_vs_previous_master=geometry_source_cycles;
        geometry_vs_previous_mode=geometry_switch_mode;
    end
    geometry_vs_previous <= raster_vs;
end

always @(posedge clk48) begin
    geometry_commit_previous <= geometry_switch_source_commit;
    geometry_dut_change_previous<=uut_ym.passive_raster_change;
    if (geometry_switch_source_commit && !geometry_commit_previous) begin
        geometry_source_changes=geometry_source_changes+1;
        #1;
        if (raster_lvbl!==1'b0 || raster_lhbl!==1'b0 || raster_hdump!==
            (geometry_switch_mode==0 ? 9'h070 : 9'h080)) begin
            $display("GEOMETRY_FAIL commit not at blank line boundary LVBL/LHBL/H=%b%b/%03x mode=%0d",
                raster_lvbl,raster_lhbl,raster_hdump,geometry_switch_mode);
            $fatal(1);
        end
        $display("GEOMETRY_COMMIT mode=%0d H/V=%0d/%0d LVBL/LHBL=%b%b t=%0t",
            geometry_switch_mode,raster_hdump,raster_vdump,raster_lvbl,raster_lhbl,$time);
    end
    if (uut_ym.passive_raster_change && !geometry_dut_change_previous)
        geometry_dut_timing_changes=geometry_dut_timing_changes+1;
end

always @(posedge clk48) begin
    if (raster_lvbl && !geometry_lvbl_previous) begin
        geometry_active_line_count=0;
        if (geometry_lvbl_previous_cycle>=0) begin
            integer old_pixels, new_pixels, new_lines, expected_pixels, measured_pixels;
            old_pixels=geometry_lvbl_previous_mode==0 ? 400 : 384;
            new_pixels=geometry_switch_mode==0 ? 400 : 384;
            new_lines=geometry_switch_mode==0 ? 262 :
                geometry_switch_mode==1 ? 260 : 261;
            expected_pixels=geometry_lvbl_previous_mode==geometry_switch_mode ?
                (new_lines-224)*new_pixels : old_pixels+(new_lines-225)*new_pixels;
            measured_pixels=(geometry_source_cycles-geometry_lvbl_previous_cycle)/8;
            if (geometry_source_cycles-geometry_lvbl_previous_cycle != expected_pixels*8) begin
                $display("GEOMETRY_FAIL blank interval=%0d master clocks expected=%0d pixels old/new mode=%0d/%0d",
                    geometry_source_cycles-geometry_lvbl_previous_cycle,expected_pixels,
                    geometry_lvbl_previous_mode,geometry_switch_mode);
                $fatal(1);
            end
            $display("GEOMETRY_LVBL mode=%0d->%0d blank=%0d pixels expected=%0d active_lines=224",
                geometry_lvbl_previous_mode,geometry_switch_mode,measured_pixels,expected_pixels);
        end
    end
    if (raster_lhbl && !geometry_lhbl_previous && raster_lvbl)
        geometry_active_line_count=geometry_active_line_count+1;
    if (!raster_lvbl && geometry_lvbl_previous) begin
        if (geometry_active_line_count!=224) begin
            $display("GEOMETRY_FAIL active frame had %0d LHBL lines, expected224",geometry_active_line_count);
            $fatal(1);
        end
        geometry_lvbl_previous_cycle=geometry_source_cycles;
        geometry_lvbl_previous_mode=geometry_switch_mode;
    end
    if (!raster_lhbl) geometry_lhbl_seen_low=1;
    if (raster_lhbl && !geometry_lhbl_previous && geometry_lhbl_seen_low) begin
        geometry_active_pixel_count=0;
        geometry_lhbl_armed=1;
    end
    if (pxl_cen && raster_lhbl && geometry_lhbl_armed)
        geometry_active_pixel_count=geometry_active_pixel_count+1;
    if (!raster_lhbl && geometry_lhbl_previous) begin
        if (geometry_lhbl_armed && geometry_active_pixel_count!=320) begin
            $display("GEOMETRY_FAIL active raster line had %0d pixel enables, expected320",geometry_active_pixel_count);
            $fatal(1);
        end
        geometry_active_pixel_count=0;
    end
    geometry_lhbl_previous=raster_lhbl;
    geometry_lvbl_previous=raster_lvbl;
end

always @(posedge clk48) begin
    if (geometry_prime_check_enable) begin
        if (!uut_ym.passive_render_ready &&
            (ym_ys!==1'b0 || {ym_r,ym_g,ym_b}!==24'h000000)) begin
            $display("GEOMETRY_FAIL renderer output was not muted during re-prime YS/RGB=%b/%06x",
                ym_ys,{ym_r,ym_g,ym_b});
            $fatal(1);
        end
        if (!geometry_prime_active && !geometry_prime_done &&
            uut_ym.passive_seed_committed && !uut_ym.passive_render_ready &&
            uut_ym.l106==9'd26 && uut_ym.l105==9'd511) begin
            geometry_prime_active=1;
            geometry_prime_last_h=9'd26;
            geometry_prime_events=1;
        end else if (geometry_prime_active && uut_ym.l106!=geometry_prime_last_h) begin
            if (uut_ym.l106==9'd26 &&
                uut_ym.passive_frame_y==uut_ym.passive_active_origin_line) begin
                if (geometry_prime_events!=420) begin
                    $display("GEOMETRY_FAIL prime traversal=%0d native H events, expected420",geometry_prime_events);
                    $fatal(1);
                end
                geometry_prime_done=1;
                geometry_prime_active=0;
                $display("GEOMETRY_PRIME mode=%0d native_H_events=420 quota=%0d",
                    geometry_switch_mode,uut_ym.passive_fast_quota);
            end else begin
                geometry_prime_events=geometry_prime_events+1;
                geometry_prime_last_h=uut_ym.l106;
            end
        end
        if (uut_ym.passive_render_ready && !geometry_prime_done) begin
            $display("GEOMETRY_FAIL ready rose before post-switch 420-event prime");
            $fatal(1);
        end
    end
end

always @(posedge clk48) begin
    integer slot, capture_index;
    if (geometry_capture_enable && geometry_capture_started && !geometry_capture_done &&
        (!uut_ym.passive_render_ready || !uut_ym.passive_geometry_supported ||
         !uut_ym.passive_raster_locked ||
         uut_ym.passive_line_pixels!=geometry_switch_line_pixels ||
         uut_ym.passive_frame_lines!=geometry_switch_frame_lines ||
         uut_ym.passive_active_pixels!=10'd320 || uut_ym.passive_active_lines!=9'd224)) begin
        $display("GEOMETRY_FAIL lock/readiness/geometry dropped during enabled sentinel capture mode=%0d ready/lock/valid=%b%b%b T/N=%0d/%0d",
            geometry_switch_mode,uut_ym.passive_render_ready,uut_ym.passive_raster_locked,
            uut_ym.passive_geometry_supported,uut_ym.passive_line_pixels,uut_ym.passive_frame_lines);
        $fatal(1);
    end
    if (geometry_capture_enable && pxl_cen && raster_lhbl && raster_lvbl &&
        uut_ym.passive_render_ready) begin
        if (!uut_ym.passive_geometry_supported || !uut_ym.passive_raster_locked ||
            uut_ym.passive_line_pixels!=geometry_switch_line_pixels ||
            uut_ym.passive_frame_lines!=geometry_switch_frame_lines ||
            uut_ym.passive_active_pixels!=10'd320 || uut_ym.passive_active_lines!=9'd224 ||
            uut_ym.passive_raster_x!=source_x_sample || uut_ym.passive_raster_y!=source_y_sample) begin
            $display("GEOMETRY_FAIL independent tracker/source mismatch lock=%b geometry=%b T/N=%0d/%0d expected=%0d/%0d xy=%0d/%0d source=%0d/%0d",
                uut_ym.passive_raster_locked,uut_ym.passive_geometry_supported,
                uut_ym.passive_line_pixels,uut_ym.passive_frame_lines,
                geometry_switch_line_pixels,geometry_switch_frame_lines,
                uut_ym.passive_raster_x,uut_ym.passive_raster_y,source_x_sample,source_y_sample);
            $fatal(1);
        end
        if (source_y_sample==0 && source_x_sample==0) begin
            if (!geometry_capture_started) begin
                geometry_capture_started=1;
                geometry_capture_frame=0;
            end else if (geometry_capture_counts[geometry_capture_frame*3+2]==320) begin
                if (geometry_capture_frame==0) geometry_capture_frame=1;
            end
        end
        slot=source_y_sample==0 ? 0 : source_y_sample==1 ? 1 :
            source_y_sample==100 ? 2 : -1;
        if (geometry_capture_frame>=0 && geometry_capture_frame<2 && slot>=0) begin
            capture_index=geometry_capture_frame*3+slot;
            if (geometry_capture_counts[capture_index]!=source_x_sample) begin
                $display("GEOMETRY_FAIL sentinel row=%0d frame=%0d expected x=%0d got=%0d",
                    source_y_sample,geometry_capture_frame,geometry_capture_counts[capture_index],source_x_sample);
                $fatal(1);
            end
            geometry_capture_pixels[capture_index*320+source_x_sample]=
                {ym_ys,ym_r,ym_g,ym_b};
            geometry_capture_counts[capture_index]=geometry_capture_counts[capture_index]+1;
            if ({ym_r,ym_g,ym_b}!=24'h000000) geometry_capture_rgb[capture_index]=geometry_capture_rgb[capture_index]+1;
            if (ym_ys===1'b0) geometry_capture_transparent[capture_index]=geometry_capture_transparent[capture_index]+1;
            if (slot==2 && geometry_capture_reference && geometry_capture_frame==0)
                geometry_reference_row100[source_x_sample]={ym_ys,ym_r,ym_g,ym_b};
            if (slot==2 && geometry_capture_reference && geometry_capture_frame==0 &&
                {ym_ys,ym_r,ym_g,ym_b}!==25'd0) begin
                $display("GEOMETRY_FAIL row100 baseline should be transparent black x=%0d tuple=%07x",
                    source_x_sample,{ym_ys,ym_r,ym_g,ym_b});
                $fatal(1);
            end
            if (slot==2 && geometry_capture_reference && geometry_capture_frame==1 &&
                geometry_reference_row100[source_x_sample]!=={ym_ys,ym_r,ym_g,ym_b}) begin
                $display("GEOMETRY_FAIL original row100 changed between frames x=%0d",source_x_sample);
                $fatal(1);
            end
            if (!geometry_capture_reference && slot==0 &&
                render_current_row0[source_x_sample]!=={ym_ys,ym_r,ym_g,ym_b}) begin
                $display("GEOMETRY_FAIL row0 differs from original profile x=%0d",source_x_sample);
                $fatal(1);
            end
            if (!geometry_capture_reference && slot==1 &&
                render_current_pixels[source_x_sample]!=={ym_ys,ym_r,ym_g,ym_b}) begin
                $display("GEOMETRY_FAIL row1 differs from original profile x=%0d",source_x_sample);
                $fatal(1);
            end
            if (!geometry_capture_reference && slot==2 &&
                geometry_reference_row100[source_x_sample]!=={ym_ys,ym_r,ym_g,ym_b}) begin
                $display("GEOMETRY_FAIL row100 differs from original profile x=%0d mode=%0d",
                    source_x_sample,geometry_switch_mode);
                $fatal(1);
            end
            if (geometry_capture_counts[capture_index]==320 &&
                (source_x_sample!=319 || geometry_capture_pixels[capture_index*320]===25'h1ffffff ||
                 geometry_capture_pixels[capture_index*320+319]===25'h1ffffff)) begin
                $display("GEOMETRY_FAIL sentinel row endpoints were not fully captured y=%0d frame=%0d",
                    source_y_sample,geometry_capture_frame);
                $fatal(1);
            end
            if (slot==2 && geometry_capture_frame==1 && source_x_sample==319)
                geometry_capture_done=1;
        end
    end
end
`endif

`ifdef PASSIVE_TEST
always @(posedge clk48) begin
    if (transition_coord_check_en &&
        (!uut_ym.passive_render_ready || !uut_ym.passive_geometry_supported || !uut_ym.passive_raster_locked)) begin
        $display("FAIL: post-transition readiness or geometry lock dropped during a full source frame");
        $fatal(1);
    end
    if (transition_coord_check_en && pxl_cen && raster_lhbl && raster_lvbl &&
        uut_ym.passive_render_ready) begin
        if (!uut_ym.passive_raster_locked ||
            uut_ym.passive_raster_x!=source_x_sample || uut_ym.passive_raster_y!=source_y_sample) begin
            $display("FAIL: post-reset frame drift source x/y=%0d/%0d tracker=%0d/%0d locked=%b",
                source_x_sample,source_y_sample,uut_ym.passive_raster_x,uut_ym.passive_raster_y,
                uut_ym.passive_raster_locked);
            $fatal(1);
        end
        if (source_x_sample==0 && source_y_sample<uut_ym.passive_active_lines) begin
            if (uut_ym.l106!=9'd26 || uut_ym.l105!=source_y_sample) begin
                $display("FAIL: active origin encoded H/V=%0d/%0d source y=%0d expected26/%0d",
                    uut_ym.l106,uut_ym.l105,source_y_sample,source_y_sample);
                $fatal(1);
            end
            if (source_y_sample==0) transition_origin_seen = 1;
        end
    end
end
`endif

`ifdef PASSIVE_TEST
always @(posedge clk48) begin
    #1;
    if (!reset_n) begin
        render_prime_count_active = 0;
        render_prime_count_done = 0;
        render_prime_events = 0;
        render_prime_last_h = 0;
    end else if (!render_prime_count_active && !render_prime_count_done &&
                 uut_ym.passive_seed_committed && !uut_ym.passive_render_ready &&
                 uut_ym.l106==9'd26 && uut_ym.l105==9'd511) begin
        render_prime_count_active = 1;
        render_prime_last_h = 9'd26;
        render_prime_events = 1;
    end else if (render_prime_count_active && uut_ym.l106!=render_prime_last_h) begin
        if (uut_ym.l106==9'd26 && uut_ym.passive_frame_y==uut_ym.passive_active_origin_line) begin
            if (render_prime_events!=420) begin
                $display("FAIL: prime traversal contained %0d H events, expected420",render_prime_events);
                $fatal(1);
            end
            render_prime_count_done = 1;
            render_prime_count_active = 0;
            $display("PASSIVE_PRIME complete 420 native H events; V0=%0d fast quota=%0d",
                uut_ym.l105,uut_ym.passive_fast_quota);
        end else begin
            render_prime_events = render_prime_events+1;
            render_prime_last_h = uut_ym.l106;
        end
    end
    if (uut_ym.passive_render_ready && !render_prime_count_done) begin
        $display("FAIL: renderer became ready before a complete420-event H26-to-H26 prime");
        $fatal(1);
    end
end
`endif

`ifdef PASSIVE_TEST
always @(posedge clk48) begin
    if (render_external_started && !render_external_complete &&
        (!uut_ym.passive_render_ready || !uut_ym.passive_geometry_supported || !uut_ym.passive_raster_locked)) begin
        $display("FAIL: passive readiness/lock dropped during a captured physical row y=%0d x=%0d",
            uut_ym.passive_raster_y,uut_ym.passive_raster_x);
        $fatal(1);
    end
    if (render_external_started && !render_external_complete && source_y_sample>3) begin
        $display("FAIL: source advanced beyond row3 before four locked rows were checked"); $fatal(1);
    end
    if (render_external_started && !render_external_complete && source_y_sample>1 && render_external_row1_count!=320) begin
        $display("FAIL: captured rows ended at physical row1 with only %0d master samples",render_external_row1_count); $fatal(1);
    end
    if (render_line_capture_en && pxl_cen && raster_lhbl && raster_lvbl &&
        uut_ym.passive_render_ready && source_x_sample < 10'd320 && !render_external_complete) begin
        if (render_external_started && source_frame_id!=render_external_frame_id) begin
            $display("FAIL: master row capture crossed an external frame boundary"); $fatal(1);
        end
        if (uut_ym.passive_raster_x!=source_x_sample || uut_ym.passive_raster_y!=source_y_sample) begin
            $display("FAIL: passive tracker coordinate differs from raw S16 source x/y=%0d/%0d tracker=%0d/%0d",
                source_x_sample,source_y_sample,uut_ym.passive_raster_x,uut_ym.passive_raster_y); $fatal(1);
        end
        if (source_y_sample>3) begin
            $display("FAIL: physical source line advanced beyond the four-line lock check"); $fatal(1);
        end
        if (source_x_sample==0 && source_y_sample<4 && source_y_integer!=render_locked_last_y) begin
            if (uut_ym.l106!=9'd26 || uut_ym.l105!=source_y_sample) begin
                $display("FAIL: locked line origin y=%0d source, H/V=%0d/%0d",source_y_sample,uut_ym.l106,uut_ym.l105); $fatal(1);
            end
            render_locked_last_y = source_y_integer;
            render_locked_line_count = render_locked_line_count+1;
            $display("PASSIVE_LOCKED_LINE y=%0d H/V=%0d/%0d",source_y_sample,uut_ym.l106,uut_ym.l105);
        end
        if (source_y_sample==3 && source_x_sample==319) begin
            if (render_locked_line_count!=4) begin
                $display("FAIL: only %0d complete line origins checked",render_locked_line_count); $fatal(1);
            end
            render_external_complete = 1;
        end
        if (source_y_sample==0 && render_external_row0_count<320 &&
            source_x_integer!=render_external_row0_last) begin
            if (render_external_row0_count==0 && source_x_sample!=0) begin
                $display("FAIL: first visible row0 master sample started at x=%0d instead of x0",source_x_sample);
                $fatal(1);
            end
            if (source_x_integer!=render_external_row0_count) begin
                $display("FAIL: row0 master x discontinuity count=%0d x=%0d",render_external_row0_count,source_x_sample); $fatal(1);
            end
            if (!render_external_started) begin
                render_external_started = 1;
                render_external_frame_id = source_frame_id;
            end
            render_external_row0_last = source_x_integer;
            render_external_row0[source_x_sample[8:0]] = {ym_ys,ym_r,ym_g,ym_b};
            render_external_row0_count = render_external_row0_count+1;
            if (source_x_sample==0 || source_x_sample==319)
                $display("PASSIVE_SAMPLE y=0 x=%0d H/V=%0d/%0d tuple=%07x",
                    source_x_sample,uut_ym.l106,uut_ym.l105,{ym_ys,ym_r,ym_g,ym_b});
        end
        if (source_y_sample==1 && render_external_row1_count<320 &&
            source_x_integer!=render_external_row1_last) begin
            if (render_external_row1_count==0 && source_x_sample!=0) begin
                $display("FAIL: first visible row1 master sample started at x=%0d instead of x0",source_x_sample);
                $fatal(1);
            end
            if (render_external_row0_count!=320 || source_x_integer!=render_external_row1_count) begin
                $display("FAIL: row1 did not follow a complete row0 or x was discontinuous row0=%0d row1=%0d x=%0d",
                    render_external_row0_count,render_external_row1_count,source_x_sample); $fatal(1);
            end
            render_external_row1_last = source_x_integer;
            render_external_row1[source_x_sample[8:0]] = {ym_ys,ym_r,ym_g,ym_b};
            render_external_row1_count = render_external_row1_count+1;
            if (source_x_sample==0 || source_x_sample==319)
                $display("PASSIVE_SAMPLE y=1 x=%0d H/V=%0d/%0d tuple=%07x",
                    source_x_sample,uut_ym.l106,uut_ym.l105,{ym_ys,ym_r,ym_g,ym_b});
        end
        if (source_y_sample>1) begin
            render_external_row0_last = -1;
            render_external_row1_last = -1;
        end
    end
end

`endif

always @(posedge clk) begin
    #1;
`ifdef PASSIVE_TEST
    if (render_line_capture_en && uut_ym.passive_render_ready && uut_ym.l105==0 && uut_ym.l106==9'd26)
        render_current_row0_armed = 1;
    if (render_line_capture_en && uut_ym_legacy.l105==0 && uut_ym_legacy.l106==9'd26)
        render_legacy_row0_armed = 1;
    if (render_line_capture_en && render_current_row0_armed && render_current_row0_count<320 &&
        uut_ym.l106>=9'd26 && uut_ym.l106<=9'd345 && {23'd0,uut_ym.l106}!=render_current_row0_last) begin
        render_current_row0_last = {23'd0,uut_ym.l106};
        render_current_row0[uut_ym.l106-9'd26] = {ym_ys,ym_r,ym_g,ym_b};
        render_current_row0_count = render_current_row0_count+1;
    end
    if (render_line_capture_en && render_legacy_row0_armed && render_legacy_row0_count<320 &&
        uut_ym_legacy.l106>=9'd26 && uut_ym_legacy.l106<=9'd345 &&
        {23'd0,uut_ym_legacy.l106}!=render_legacy_row0_last) begin
        render_legacy_row0_last = {23'd0,uut_ym_legacy.l106};
        render_legacy_row0[uut_ym_legacy.l106-9'd26] = {ym_ys_legacy,ym_r_legacy,ym_g_legacy,ym_b_legacy};
        render_legacy_row0_count = render_legacy_row0_count+1;
    end
`endif
    if (render_line_capture_en && render_line_current_ready) begin
        if (!render_line_current_started && uut_ym.l105 == 1 && uut_ym.l106 == 9'd0) begin
            render_line_current_started = 1;
            render_line_current_last_h = -1;
        end
        if (render_line_current_started && !render_line_current_done &&
            {23'd0,uut_ym.l106} != render_line_current_last_h) begin
            if (render_line_current_last_h >= 500 && uut_ym.l106 == 0) begin
                $display("LINE_CUR H=0 V=%0d DE=%b%b RGB=%06x YS=%b WRAP",uut_ym.l105,
                    ym_de_h,ym_de_v,{ym_r,ym_g,ym_b},ym_ys);
                render_line_current_done = 1;
            end else begin
                render_line_current_last_h = {23'd0,uut_ym.l106};
                render_line_current_total = render_line_current_total + 1;
                if (ym_de_h && ym_de_v) begin
                    render_line_current_de = render_line_current_de + 1;
                    if (render_line_current_first_de < 0) render_line_current_first_de = {23'd0,uut_ym.l106};
                    render_line_current_last_de = {23'd0,uut_ym.l106};
                end
                if (uut_ym.l106 >= 9'd26 && uut_ym.l106 <= 9'd345) begin
                    render_line_current_events = render_line_current_events + 1;
                    render_current_pixels[uut_ym.l106-9'd26] = {ym_ys,ym_r,ym_g,ym_b};
                    if ((^{ym_r,ym_g,ym_b}) !== 1'bx && {ym_r,ym_g,ym_b} != 24'h000000)
                        render_line_current_rgb = render_line_current_rgb + 1;
                    if (ym_ys === 1'b1) render_line_current_ys = render_line_current_ys + 1;
                    if ((^{ym_r,ym_g,ym_b,ym_ys}) === 1'bx) render_line_current_x = render_line_current_x + 1;
                end
                $display("LINE_CUR H=%0d V=%0d DE=%b%b RGB=%06x YS=%b",uut_ym.l106,uut_ym.l105,
                    ym_de_h,ym_de_v,{ym_r,ym_g,ym_b},ym_ys);
            end
        end
    end
    if (render_line_capture_en && render_line_legacy_ready) begin
        if (!render_line_legacy_started && uut_ym_legacy.l105 == 1 && uut_ym_legacy.l106 == 9'd0) begin
            render_line_legacy_started = 1;
            render_line_legacy_last_h = -1;
        end
        if (render_line_legacy_started && !render_line_legacy_done &&
            {23'd0,uut_ym_legacy.l106} != render_line_legacy_last_h) begin
            if (render_line_legacy_last_h >= 500 && uut_ym_legacy.l106 == 0) begin
                $display("LINE_REF H=0 V=%0d DE=%b%b RGB=%06x YS=%b WRAP",uut_ym_legacy.l105,
                    ym_de_h_legacy,ym_de_v_legacy,{ym_r_legacy,ym_g_legacy,ym_b_legacy},ym_ys_legacy);
                render_line_legacy_done = 1;
            end else begin
                render_line_legacy_last_h = {23'd0,uut_ym_legacy.l106};
                render_line_legacy_total = render_line_legacy_total + 1;
                if (ym_de_h_legacy && ym_de_v_legacy) begin
                    render_line_legacy_de = render_line_legacy_de + 1;
                    if (render_line_legacy_first_de < 0) render_line_legacy_first_de = {23'd0,uut_ym_legacy.l106};
                    render_line_legacy_last_de = {23'd0,uut_ym_legacy.l106};
                end
                if (uut_ym_legacy.l106 >= 9'd26 && uut_ym_legacy.l106 <= 9'd345) begin
                    render_line_legacy_events = render_line_legacy_events + 1;
                    render_legacy_pixels[uut_ym_legacy.l106-9'd26] =
                        {ym_ys_legacy,ym_r_legacy,ym_g_legacy,ym_b_legacy};
                    if ((^{ym_r_legacy,ym_g_legacy,ym_b_legacy}) !== 1'bx &&
                        {ym_r_legacy,ym_g_legacy,ym_b_legacy} != 24'h000000)
                        render_line_legacy_rgb = render_line_legacy_rgb + 1;
                    if (ym_ys_legacy === 1'b1) render_line_legacy_ys = render_line_legacy_ys + 1;
                    if ((^{ym_r_legacy,ym_g_legacy,ym_b_legacy,ym_ys_legacy}) === 1'bx)
                        render_line_legacy_x = render_line_legacy_x + 1;
                end
                $display("LINE_REF H=%0d V=%0d DE=%b%b RGB=%06x YS=%b",uut_ym_legacy.l106,uut_ym_legacy.l105,
                    ym_de_h_legacy,ym_de_v_legacy,{ym_r_legacy,ym_g_legacy,ym_b_legacy},ym_ys_legacy);
            end
        end
    end
end
wire ym_clk = use48 ? clk48 : clk;
reg mclk_e = 0, mclk_e_legacy = 0, edclk = 0, cpu_clk = 0, cen20 = 0;
always @(posedge cpu_clk) service_cpu_edge_index <= service_cpu_edge_index + 1;
integer cen20_acc = 0;
integer cpu_start_delay_count = CPU_START_DELAY96;
always @(posedge ym_clk) mclk_e <= ~mclk_e;
always @(posedge clk) mclk_e_legacy <= ~mclk_e_legacy;
always @(posedge clk) begin
    // The strict 384x260 IRQ fixture waits two idle clk96 edges before
    // entering this original fractional CPU divider sequence.
    if (cpu_start_delay_count > 0) begin
        if (as_n !== 1'b1 || uds !== 1'b1 || lds !== 1'b1 ||
            service_cpu_read_accept_count != 0 || service_cpu_write_accept_count != 0 ||
            cen20_acc != 0 || cen20 !== 1'b0 || cpu_clk !== 1'b0) begin
            $display("FAIL: CPU startup phase delay encountered non-idle divider/bus or accepted transaction K=%0d remaining=%0d AS/UDS/LDS=%b%b%b divider=%0d/%b/%b reads/writes=%0d/%0d",
                CPU_START_DELAY96,cpu_start_delay_count,as_n,uds,lds,
                cen20_acc,cen20,cpu_clk,service_cpu_read_accept_count,service_cpu_write_accept_count);
            $fatal(1);
        end
        cen20_acc <= 0;
        cen20 <= 0;
        cpu_clk <= 0;
        cpu_start_delay_count <= cpu_start_delay_count - 1;
    end else begin
        if (cen20_acc >= 76) begin
            cen20_acc <= cen20_acc + 20 - 96;
            cen20 <= 1;
        end else begin
            cen20_acc <= cen20_acc + 20;
            cen20 <= 0;
        end
        if (cen20) cpu_clk <= ~cpu_clk;
    end
end
reg [1:0] edclk_div = 0;
always @(posedge clk) begin
    edclk_div <= edclk_div + 1'b1;
    if (edclk_div == 2'd3) edclk <= ~edclk;
end

`ifdef GEOMETRY_SWITCH_SCENARIO
`ifdef PRODUCTION_TIMER_SCENARIO
wire production_active_original;
wire production_req_57Hz;
assign geometry_switch_mode = production_active_original ? 2'd0 : 2'd1;
assign geometry_switch_line_pixels = production_active_original ? 10'd400 : 10'd384;
assign geometry_switch_frame_lines = production_active_original ? 9'd262 : 9'd260;
assign geometry_switch_source_commit =
    production_req_57Hz != production_active_original &&
    pxl_cen && raster_hdump==9'h1ff && raster_vdump==9'h0e0 && !raster_lvbl;
assign production_req_57Hz = geometry_switch_request==0;

jts16_vtimer #(.DUAL_RATE(1),.HS_END(9'h0a0)) u_production_raster(
    .clk                 ( clk48                         ),
    .pxl_cen             ( pxl_cen                       ),
    .req_57Hz            ( production_req_57Hz           ),
    .is_57Hz             ( production_active_original    ),
    .vdump               ( raster_vdump                  ),
    .vrender             ( raster_vrender                ),
    .vrender1            ( raster_vrender1               ),
    .H                   ( raster_hdump                  ),
    .Hinit               ( raster_hinit                  ),
    .Vinit               ( raster_vinit                  ),
    .LHBL                ( raster_lhbl                   ),
    .LVBL                ( raster_lvbl                   ),
    .HS                  ( raster_hs                     ),
    .VS                  ( raster_vs                     )
);
`else
geometry_switch_vtimer u_raster_source(
    .clk           ( clk48                         ),
    .pxl_cen       ( pxl_cen                       ),
    .request_mode  ( geometry_switch_request       ),
    .request_valid ( geometry_switch_request_valid),
    .active_mode   ( geometry_switch_mode          ),
    .timing_change ( geometry_switch_source_commit),
    .vdump         ( raster_vdump                  ),
    .vrender       ( raster_vrender                ),
    .vrender1      ( raster_vrender1               ),
    .H             ( raster_hdump                  ),
    .Hinit         ( raster_hinit                  ),
    .Vinit         ( raster_vinit                  ),
    .LHBL          ( raster_lhbl                   ),
    .LVBL          ( raster_lvbl                   ),
    .HS            ( raster_hs                     ),
    .VS            ( raster_vs                     ),
    .line_pixels   ( geometry_switch_line_pixels   ),
    .frame_lines   ( geometry_switch_frame_lines   )
);
`endif
`else
jtframe_vtimer #(
    .HB_START  ( 9'h1ff ),
    .HB_END    ( 9'h0bf ),
    .HCNT_START( TEST_HCNT_START ),
    .HCNT_END  ( 9'h1ff ),
    .VB_START  ( 9'h0df ),
    .VB_END    ( TEST_VB_END ),
    .VCNT_END  ( TEST_VCNT_END ),
    .VS_START  ( TEST_VS_START ),
    .VS_END    ( TEST_VS_END ),
    .HS_START  ( 9'h080 ),
    .HS_END    ( 9'h0a0 ),
    .H_VB      ( 9'h1ff ),
    .H_VS      ( 9'h080 ),
    .H_VNEXT   ( 9'h080 ),
    .HINIT     ( 9'h080 )
) u_raster_source(
    .clk      ( clk48          ),
    .pxl_cen  ( pxl_cen        ),
    .vdump    ( raster_vdump   ),
    .H        ( raster_hdump   ),
    .Hinit    ( raster_hinit   ),
    .Vinit    ( raster_vinit   ),
    .LHBL     ( raster_lhbl    ),
    .LVBL     ( raster_lvbl    ),
    .HS       ( raster_hs      ),
    .VS       ( raster_vs      ),
    .vrender  ( raster_vrender ),
    .vrender1 ( raster_vrender1 )
);
`endif

// The late-copy acceptance requires an independently observed source-line
// wrap before a physical write commit is counted at normal dwell.
always @(posedge clk48) begin
    if (!reset_n) begin
        copy_late_source_h_prev <= raster_hdump;
    end else begin
        if (copy_start_late && copy_late_command_fast_seen &&
            copy_late_source_h_prev==9'h1ff && raster_hdump==TEST_HCNT_START) begin
            copy_late_source_wrap_seen <= 1'b1;
            $display("SERVICE_COPY_LATE_SOURCE_WRAP H/V=%0d/%0d time=%0t",
                raster_hdump,raster_vdump,$time);
        end
        copy_late_source_h_prev <= raster_hdump;
    end
end

always @(posedge ym_clk) begin
    if (service_dma_monitor && copy_start_late && copy_late_command_fast_seen &&
        copy_late_source_wrap_seen && !copy_late_normal_commit_seen && ym_vram.wr &&
        uut_ym.passive_dwell==3'd2 && uut_ym.l106<=9'd345) begin
        copy_late_normal_commit_seen = 1'b1;
        $display("SERVICE_COPY_LATE_NORMAL_COMMIT DRAM=%04x data=%02x native_H/V=%0d/%0d Q/tick/dwell=%0d/%0d/%0d source_H/V=%0d/%0d",
            ym_vram.addr,ym_vram.RD_i,uut_ym.l106,uut_ym.l105,uut_ym.passive_quarter,
            uut_ym.passive_tick,uut_ym.passive_dwell,raster_hdump,raster_vdump);
    end
end

reg [22:0] ca = 0;
reg [15:0] cd = 0;
reg as_n = 1, uds = 1, lds = 1, rw = 1;
reg feature_bus_active = 0;
reg [22:0] feature_ca = 0, feature_ca_legacy = 0;
reg [15:0] feature_cd = 0, feature_cd_legacy = 0;
reg feature_as_n = 1, feature_uds = 1, feature_lds = 1, feature_rw = 1;
reg feature_as_n_legacy = 1, feature_uds_legacy = 1, feature_lds_legacy = 1, feature_rw_legacy = 1;
reg [22:0] ca_r = 0, ca_r_legacy = 0;
reg [15:0] cd_r = 0, cd_r_legacy = 0;
reg asn_r = 1, uds_r = 1, lds_r = 1, rnw_r = 1;
reg asn_r_legacy = 1, uds_r_legacy = 1, lds_r_legacy = 1, rnw_r_legacy = 1;

wire [7:0] ym_ad_bus, ym_ad_bus_legacy, ym_sd_bus, ym_sd_bus_legacy;
wire [7:0] ym_vram_ad_o, ym_vram_ad_o_legacy, ym_vram_sd_o, ym_vram_sd_o_legacy;
wire ym_vram_ad_d, ym_vram_ad_d_legacy, ym_vram_sd_d, ym_vram_sd_d_legacy;
wire ym_se0, ym_se0_legacy, ym_bgack, ym_bgack_legacy;
wire ym_spa_b, ym_spa_b_legacy, ym_int, ym_int_legacy, ym_br, ym_br_legacy;
wire ym_ipl1, ym_ipl2, ym_ipl1_legacy, ym_ipl2_legacy;
wire [7:0] ym_rd_o, ym_rd_o_legacy, ym_ad_o, ym_ad_o_legacy;
wire [15:0] ym_cd_o, ym_cd_o_legacy;
wire ym_rd_d, ym_rd_d_legacy, ym_ad_d, ym_ad_d_legacy;
wire ym_cd_d, ym_cd_d_legacy, ym_dtack, ym_dtack_legacy;
wire ym_ras, ym_ras_legacy, ym_cas, ym_cas_legacy, ym_we0, ym_we0_legacy;
wire ym_we, ym_we_legacy, ym_oe, ym_oe_legacy, ym_sc, ym_sc_legacy;
wire [7:0] ym_r, ym_r_legacy, ym_g, ym_g_legacy, ym_b, ym_b_legacy;
wire ym_ys, ym_ys_legacy, ym_reg_m5, ym_reg_m5_legacy;
wire ym_de_h, ym_de_h_legacy, ym_de_v, ym_de_v_legacy;
wire ym_hs, ym_hs_legacy, ym_vs, ym_vs_legacy;
wire [15:0] ym_sound, ym_sound_legacy;
wire ym_edclk_o, ym_edclk_o_legacy, ym_edclk_d, ym_edclk_d_legacy;
reg [7:0] ym_ad_mem = 0, ym_ad_mem_legacy = 0, ym_sd_mem = 0, ym_sd_mem_legacy = 0;
reg [1:0] ym_dtack_r = 0, ym_dtack_r_legacy = 0;
reg ym_edclk_l = 0, ym_edclk_l_legacy = 0;
integer timeout;
reg ack_capture_en = 0, ack_current_seen = 0, ack_legacy_seen = 0;
reg [15:0] ack_current_data = 0, ack_legacy_data = 0;
reg ack_current_dir = 1, ack_legacy_dir = 1;
reg cpu_capture_en = 0, cpu_capture_current_seen = 0, cpu_capture_legacy_seen = 0;
reg [15:0] cpu_capture_current_data = 0, cpu_capture_legacy_data = 0;
reg cpu_capture_current_dir = 1, cpu_capture_legacy_dir = 1;
integer ack_cycle = 0, ack_start_cycle = 0;
integer ack_current_latency = 0, ack_legacy_latency = 0;
integer ram_write_events = 0;
reg hl_test = 1;
reg service_hv_capture_en = 0, service_hv_capture_seen = 0;
reg [9:0] service_hv_capture_x = 0;
reg [8:0] service_hv_capture_y = 0;
reg [15:0] service_hv_capture_expected = 0;
reg [8:0] service_hv_capture_source_h = 0, service_hv_capture_source_v = 0;
reg service_hv_latch_capture_en = 0, service_hv_latch_capture_seen = 0;
reg service_hv_latch_prev = 0;
reg [9:0] service_hv_latch_x = 0;
reg [8:0] service_hv_latch_y = 0;
reg service_fifo_probe = 0;
reg service_fifo_full_seen = 0, service_fifo_status_full_seen = 0;
integer service_fifo_full_ticks = 0, service_fifo_withheld_samples = 0;
integer service_fifo_accepted_writes = 0;
integer service_fifo_max_wait = 0;
reg service_dma_monitor = 0;
integer service_dma_busy_samples = 0, service_dma_ramwr_samples = 0;
integer service_dma_fill_samples = 0, service_dma_copy_samples = 0;
integer service_copy_write_events = 0;
integer service_copy_issue_events = 0;
integer service_copy_commit_samples = 0;
integer service_mclk_cycle = 0, service_copy_wait_start_cycle = 0;
reg service_copy_prev_wr = 0, service_copy_prev_issue = 0;
time service_copy_terminal_time = 0;
reg service_copy_oracle_failed = 0;
reg service_reg_wait_enable = 0;
reg service_reg_trace_en = 0;
reg [7:0] service_reg_trace_prev_strobe = 0, service_reg_trace_strobe = 0;
reg [16:0] service_reg_trace_prev_data = 0;
reg [1:0] service_reg_trace_prev_code = 0;
reg service_copy_trace_en = 0, service_copy_trace_command = 0;
integer service_copy_trace_events = 0;
reg service_copy_trace_overflow = 0;
reg [201:0] service_copy_trace_key = 0, service_copy_trace_prev_key = 0;
reg [7:0] service_copy_source_snapshot [0:15];
reg rate_check_en = 0, rate_started = 0;
reg rate_last_hclk1 = 0, rate_wait_hclk1 = 0;
integer rate_run = 0;
integer rate_dwell = 2;
integer rate_fast_transitions = 0, rate_normal_transitions = 0;
integer fast_event_count = 0;
reg passive_geometry_seen = 0;
always @(posedge clk48) begin
    if (uut_ym.passive_geometry_supported) passive_geometry_seen <= 1'b1;
end

always @(posedge ym_clk) begin
    #1;
    if (!service_reg_trace_en) begin
        service_reg_trace_prev_strobe <= 0;
        service_reg_trace_prev_data <= 0;
        service_reg_trace_prev_code <= 0;
    end
    else begin
        service_reg_trace_strobe = {uut_ym.w228,uut_ym.w227,uut_ym.w217,uut_ym.w213,
            uut_ym.w212,uut_ym.w211,uut_ym.w210,uut_ym.w205};
        if (service_reg_trace_strobe!=0 &&
            (service_reg_trace_strobe!=service_reg_trace_prev_strobe ||
             uut_ym.reg_data_l2!=service_reg_trace_prev_data ||
             uut_ym.reg_code[1:0]!=service_reg_trace_prev_code)) begin
            $display("SERVICE_REG_DECODE t=%0t code=%02x data=%05x w184/w193=%b%b stage=%b%b%b%b w205=%b strobes210/211/212/213/217/227/228=%b%b%b%b%b%b%b fields m5/disp/m1=%b%b%b inc=%02x len=%04x dmd=%0d sa=%04x",
                $time,uut_ym.reg_code,uut_ym.reg_data_l2,uut_ym.w184,uut_ym.w193,
                uut_ym.l32,uut_ym.l33,uut_ym.l34,uut_ym.l31,uut_ym.w205,
                uut_ym.w210,uut_ym.w211,uut_ym.w212,uut_ym.w213,uut_ym.w217,uut_ym.w227,uut_ym.w228,
                uut_ym.reg_m5,uut_ym.reg_disp,uut_ym.reg_m1,uut_ym.reg_inc,uut_ym.reg_lg,uut_ym.reg_dmd,uut_ym.reg_sa_low);
        end
        service_reg_trace_prev_strobe <= service_reg_trace_strobe;
        service_reg_trace_prev_data <= uut_ym.reg_data_l2;
        service_reg_trace_prev_code <= uut_ym.reg_code[1:0];
    end
end

always @(posedge ym_clk) begin
    service_mclk_cycle <= service_mclk_cycle + 1;
    service_copy_trace_key = {ca,cd,as_n,uds,lds,
        uut_ym.cpu_clk0,uut_ym.cpu_clk1,uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2,
        uut_ym.w181,uut_ym.w185,uut_ym.w187,uut_ym.w191,uut_ym.w195,uut_ym.w299,
        uut_ym.reg_data_l2,uut_ym.reg_data_sum,uut_ym.reg_data_1.l1,uut_ym.reg_data_1.l2,
        uut_ym.reg_data_2.l1,uut_ym.reg_data_2.l2,uut_ym.l35,uut_ym.vram_address,
        uut_ym.l592,uut_ym.l593,ym_ras,ym_cas,ym_we0,ym_vram.wr,
        ym_read_data,ym_vram.o_RAS,ym_vram.o_cas,ym_vram.addr};
    if (service_copy_trace_en && (service_copy_trace_command || uut_ym.dff3_l2) &&
        service_copy_trace_key !== service_copy_trace_prev_key) begin
        if (service_copy_trace_events<32768) begin
        $display("SERVICE_COPY_CHAIN_PRE cycle=%0d t=%0t H/V=%0d/%0d CPU=%06x/%04x AS/UDS/LDS=%b%b%b cpuclk=%b%b clk=%b%b hclk=%b%b ctrl181/185/187/191/195/299=%b%b%b%b%b%b regaddr=%05x regdata=%05x sum=%05x data1=%04x/%04x data2=%01x/%01x l35=%05x vaddr=%05x l592/593=%02x/%02x AD=%02x pins=%b%b%b delayedRAS/CAS=%b%b addr=%04x",
            service_mclk_cycle,$time,uut_ym.l106,uut_ym.l105,ca,cd,as_n,uds,lds,
            uut_ym.cpu_clk0,uut_ym.cpu_clk1,uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2,
            uut_ym.w181,uut_ym.w185,uut_ym.w187,uut_ym.w191,uut_ym.w195,uut_ym.w299,
            uut_ym.reg_addr,uut_ym.reg_data_l2,uut_ym.reg_data_sum,uut_ym.reg_data_1.l1,uut_ym.reg_data_1.l2,
            uut_ym.reg_data_2.l1,uut_ym.reg_data_2.l2,uut_ym.l35,uut_ym.vram_address,uut_ym.l592,uut_ym.l593,
            ym_read_data,ym_ras,ym_cas,ym_we0,ym_vram.o_RAS,ym_vram.o_cas,ym_vram.addr);
        #1;
        $display("SERVICE_COPY_CHAIN_POST cycle=%0d t=%0t H/V=%0d/%0d CPU=%06x/%04x AS/UDS/LDS=%b%b%b cpuclk=%b%b clk=%b%b hclk=%b%b ctrl181/185/187/191/195/299=%b%b%b%b%b%b regaddr=%05x regdata=%05x sum=%05x data1=%04x/%04x data2=%01x/%01x l35=%05x vaddr=%05x l592/593=%02x/%02x AD=%02x pins=%b%b%b delayedRAS/CAS=%b%b addr=%04x",
            service_mclk_cycle,$time,uut_ym.l106,uut_ym.l105,ca,cd,as_n,uds,lds,
            uut_ym.cpu_clk0,uut_ym.cpu_clk1,uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2,
            uut_ym.w181,uut_ym.w185,uut_ym.w187,uut_ym.w191,uut_ym.w195,uut_ym.w299,
            uut_ym.reg_addr,uut_ym.reg_data_l2,uut_ym.reg_data_sum,uut_ym.reg_data_1.l1,uut_ym.reg_data_1.l2,
            uut_ym.reg_data_2.l1,uut_ym.reg_data_2.l2,uut_ym.l35,uut_ym.vram_address,uut_ym.l592,uut_ym.l593,
            ym_read_data,ym_ras,ym_cas,ym_we0,ym_vram.o_RAS,ym_vram.o_cas,ym_vram.addr);
        service_copy_trace_events=service_copy_trace_events+1;
        end else begin
            service_copy_trace_overflow=1;
        end
    end
    service_copy_trace_prev_key <= service_copy_trace_en ? service_copy_trace_key : 0;
end

always @(posedge ym_clk) begin
    if (service_dma_monitor) begin
        if (uut_ym.dff3_l2) service_dma_busy_samples <= service_dma_busy_samples + 1;
        if (uut_ym.dff3_l2 && ym_vram.wr) service_dma_ramwr_samples <= service_dma_ramwr_samples + 1;
        if (uut_ym.w248 && uut_ym.dff3_l2) service_dma_fill_samples <= service_dma_fill_samples + 1;
        if (uut_ym.w245 && uut_ym.dff3_l2) service_dma_copy_samples <= service_dma_copy_samples + 1;
        if (uut_ym.w245 && uut_ym.dff3_l2 && ym_vram.wr && !service_copy_prev_wr) begin
            if (service_copy_write_events < 24)
                $display("SERVICE_COPY_PIN n=%0d cycle=%0d vaddr=%05x regaddr=%05x code=%02x data=%04x source=%04x mode=%b dram=%03x write_data=%02x ser=%02x/%02x",
                    service_copy_write_events,service_mclk_cycle,uut_ym.vram_address,uut_ym.reg_addr,uut_ym.reg_code,uut_ym.vram_data,
                    uut_ym.reg_sa_low,uut_ym.reg_dmd,ym_vram.addr,ym_vram.RD_i,ym_vram.addr_ser_page,ym_vram.addr_ser,ym_vram.vram_ser);
            service_copy_write_events <= service_copy_write_events + 1;
        end
        if (ym_vram.wr && service_copy_commit_samples < 256) begin
            $display("SERVICE_COPY_COMMIT_SAMPLE n=%0d elapsed_ns=%0d source_now=%04x destination_reg=%05x dma=%b/%b pending=%b%b%b%b DRAM=%04x old=%02x new=%02x H/V=%0d/%0d pins RAS/CAS/WE=%b%b%b",
                service_copy_commit_samples,$time-service_copy_terminal_time,uut_ym.reg_sa_low,uut_ym.reg_addr,uut_ym.dff3_l2,uut_ym.w245,
                uut_ym.l41,uut_ym.w250,uut_ym.w187,uut_ym.l50,ym_vram.addr,
                ym_vram.mem[ym_vram.addr],ym_vram.RD_i,uut_ym.l106,uut_ym.l105,ym_ras,ym_cas,ym_we0);
            service_copy_commit_samples <= service_copy_commit_samples + 1;
        end
        if (uut_ym.w195 && !service_copy_prev_issue) begin
            if (service_copy_issue_events < 24)
                $display("SERVICE_COPY_SOURCE_ISSUE n=%0d cycle=%0d source=%04x destination=%05x len=%04x vram_addr=%05x serial=%02x sd=%02x ser_addr=%02x:%02x ser_data=%02x",
                    service_copy_issue_events,service_mclk_cycle,uut_ym.reg_sa_low,uut_ym.reg_addr,uut_ym.reg_lg,uut_ym.vram_address,
                    uut_ym.vram_serial,ym_vram_sd_o,ym_vram.addr_ser_page,ym_vram.addr_ser,ym_vram.vram_ser);
            service_copy_issue_events <= service_copy_issue_events + 1;
        end
        service_copy_prev_wr <= ym_vram.wr;
        service_copy_prev_issue <= uut_ym.w195;
    end else begin
        service_copy_prev_wr <= 0;
        service_copy_prev_issue <= 0;
    end
end
wire ym_dtackn = ~ym_dtack_r[0];
wire ym_dtackn_legacy = ~ym_dtack_r_legacy[0];
wire [7:0] ym_read_data =
    (~ym_ad_d ? ym_ad_o : 8'h00) |
    (~ym_vram_ad_d ? ym_vram_ad_o : 8'h00) |
    ((ym_ad_d & ym_vram_ad_d) ? ym_ad_mem : 8'h00);
wire [7:0] ym_read_data_legacy =
    (~ym_ad_d_legacy ? ym_ad_o_legacy : 8'h00) |
    (~ym_vram_ad_d_legacy ? ym_vram_ad_o_legacy : 8'h00) |
    ((ym_ad_d_legacy & ym_vram_ad_d_legacy) ? ym_ad_mem_legacy : 8'h00);
wire [7:0] ym_sd = ym_vram_sd_d ? ym_sd_mem : ym_vram_sd_o;
wire [7:0] ym_sd_legacy = ym_vram_sd_d_legacy ? ym_sd_mem_legacy : ym_vram_sd_o_legacy;

always @(posedge ym_clk) if (ym_vram.wr) ram_write_events <= ram_write_events + 1;

always @(posedge clk48) begin
    if (service_fifo_probe && uut_ym.w252) begin
        service_fifo_full_seen <= 1'b1;
        service_fifo_full_ticks <= service_fifo_full_ticks + 1;
    end
end

always @(posedge clk48) begin
    #1;
    if (render_trace_en && stage_trace_count < 32 &&
        uut_ym.passive_quarter==2'd0 && uut_ym.passive_tick==0 &&
        uut_ym.l106>=9'd170 && uut_ym.l106<=9'd190) begin
        $display("PLANE_CUR H=%0d Q=%0d/%0d D=%0d tile=%h stages=%h/%h/%h/%h/%h/%h gates=%h/%h/%h/%b data_stage=%h colors=%h serial=%h vaddr=%h data=%h",
            uut_ym.l106,uut_ym.passive_quarter,uut_ym.passive_tick,uut_ym.passive_dwell,
            {uut_ym.l219,uut_ym.l220,uut_ym.l221,uut_ym.l222},
            {uut_ym.l275,uut_ym.l276,uut_ym.l277,uut_ym.l278},
            {uut_ym.l279,uut_ym.l280,uut_ym.l281,uut_ym.l282},
            {uut_ym.l287,uut_ym.l288,uut_ym.l289,uut_ym.l290},
            {uut_ym.l294,uut_ym.l295,uut_ym.l296,uut_ym.l297},
            {uut_ym.l303,uut_ym.l304,uut_ym.l305,uut_ym.l306},
            {uut_ym.l307,uut_ym.l308,uut_ym.l309,uut_ym.l310},
            {uut_ym.w619,uut_ym.w620,uut_ym.w621,uut_ym.w622},
            {uut_ym.w627,uut_ym.w628,uut_ym.w629,uut_ym.w630,uut_ym.w631},
            {uut_ym.w588,uut_ym.w589,uut_ym.w590,uut_ym.w591,uut_ym.w592,uut_ym.w593,uut_ym.w594,uut_ym.w595,uut_ym.w596,uut_ym.w597},
            uut_ym.w645,{uut_ym.w647,uut_ym.l318,uut_ym.l319,uut_ym.l323},
            {uut_ym.l603,uut_ym.l604,uut_ym.l605,uut_ym.l606},uut_ym.vram_serial,uut_ym.vram_address,uut_ym.vram_data);
        $display("PLANE_REF H=%0d tile=%h stages=%h/%h/%h/%h/%h/%h gates=%h/%h/%h/%b data_stage=%h colors=%h serial=%h vaddr=%h data=%h",
            uut_ym_legacy.l106,{uut_ym_legacy.l219,uut_ym_legacy.l220,uut_ym_legacy.l221,uut_ym_legacy.l222},
            {uut_ym_legacy.l275,uut_ym_legacy.l276,uut_ym_legacy.l277,uut_ym_legacy.l278},
            {uut_ym_legacy.l279,uut_ym_legacy.l280,uut_ym_legacy.l281,uut_ym_legacy.l282},
            {uut_ym_legacy.l287,uut_ym_legacy.l288,uut_ym_legacy.l289,uut_ym_legacy.l290},
            {uut_ym_legacy.l294,uut_ym_legacy.l295,uut_ym_legacy.l296,uut_ym_legacy.l297},
            {uut_ym_legacy.l303,uut_ym_legacy.l304,uut_ym_legacy.l305,uut_ym_legacy.l306},
            {uut_ym_legacy.l307,uut_ym_legacy.l308,uut_ym_legacy.l309,uut_ym_legacy.l310},
            {uut_ym_legacy.w619,uut_ym_legacy.w620,uut_ym_legacy.w621,uut_ym_legacy.w622},
            {uut_ym_legacy.w627,uut_ym_legacy.w628,uut_ym_legacy.w629,uut_ym_legacy.w630,uut_ym_legacy.w631},
            {uut_ym_legacy.w588,uut_ym_legacy.w589,uut_ym_legacy.w590,uut_ym_legacy.w591,uut_ym_legacy.w592,uut_ym_legacy.w593,uut_ym_legacy.w594,uut_ym_legacy.w595,uut_ym_legacy.w596,uut_ym_legacy.w597},
            uut_ym_legacy.w645,{uut_ym_legacy.w647,uut_ym_legacy.l318,uut_ym_legacy.l319,uut_ym_legacy.l323},
            {uut_ym_legacy.l603,uut_ym_legacy.l604,uut_ym_legacy.l605,uut_ym_legacy.l606},uut_ym_legacy.vram_serial,
            uut_ym_legacy.vram_address,uut_ym_legacy.vram_data);
        stage_trace_count = stage_trace_count+1;
    end
end

always @(posedge ym_clk) begin
    #1;
    if (render_trace_en && render_trace_count < 64 &&
        ({ym_ras,ym_cas,ym_oe,ym_sc} !== {trace_prev_ras,trace_prev_cas,trace_prev_oe,trace_prev_sc})) begin
        $display("SERIAL_TRACE n=%0d H=%0d V=%0d pins=%b%b%b%b dt=%b old=%b%b%b addr=%h seraddr=%h/%h ser=%h SD=%h vaddr=%h data=%h",
            render_trace_count,uut_ym.l106,uut_ym.l105,ym_ras,ym_cas,ym_oe,ym_sc,
            ym_vram.dt,ym_vram.o_OE,ym_vram.o_RAS,ym_vram.o_cas,
            ym_vram.addr,ym_vram.addr_ser_page,ym_vram.addr_ser,ym_vram.vram_ser,ym_sd,
            uut_ym.vram_address,uut_ym.vram_data);
        render_trace_count = render_trace_count+1;
    end
    trace_prev_ras = ym_ras;
    trace_prev_cas = ym_cas;
    trace_prev_oe = ym_oe;
    trace_prev_sc = ym_sc;
end

always @(posedge clk48) begin
    #1;
    if (PASSIVE_MODE && reset_n && rate_check_en) begin
        if (uut_ym.passive_quarter==2'd1 && uut_ym.passive_tick==0 && uut_ym.passive_dwell==1)
            fast_event_count = fast_event_count + 1;
        if (!rate_started) begin
            if (uut_ym.hclk1 !== rate_last_hclk1) begin
                rate_started = 1;
                rate_last_hclk1 = uut_ym.hclk1;
                rate_run = 1;
                rate_dwell = {29'd0,uut_ym.passive_dwell};
            end
        end else if (uut_ym.hclk1 !== rate_last_hclk1) begin
            if (rate_run != 2*rate_dwell) begin
                $display("FAIL: hclk half width=%0d expected=%0d quarter=%0d dwell=%0d H=%0d",
                    rate_run, 2*rate_dwell, uut_ym.passive_quarter, uut_ym.passive_dwell, uut_ym.l106);
                $fatal(1);
            end
            rate_last_hclk1 = uut_ym.hclk1;
            rate_run = 1;
            if (uut_ym.passive_dwell==1 && rate_dwell==2) rate_fast_transitions = rate_fast_transitions+1;
            if (uut_ym.passive_dwell==2 && rate_dwell==1) rate_normal_transitions = rate_normal_transitions+1;
            rate_dwell = {29'd0,uut_ym.passive_dwell};
        end else rate_run = rate_run+1;
    end
end

always @(posedge clk) begin
    ack_cycle = ack_cycle + 1;
    #1;
    if (ack_capture_en) begin
        if (!ack_current_seen && !ym_dtackn) begin
            ack_current_seen = 1;
            ack_current_data = ym_cd_o;
            ack_current_dir = ym_cd_d;
            ack_current_latency = ack_cycle-ack_start_cycle;
        end
        if (!ack_legacy_seen && !ym_dtackn_legacy) begin
            ack_legacy_seen = 1;
            ack_legacy_data = ym_cd_o_legacy;
            ack_legacy_dir = ym_cd_d_legacy;
            ack_legacy_latency = ack_cycle-ack_start_cycle;
        end
    end
end

always @(posedge cpu_clk) begin
    #1;
    if (cpu_capture_en && irq_hv_trace_en) begin
        irq_s6_clk48=irq_clk48_count;
        irq_s6_clk96=irq_clk96_edge_count;
        irq_s6_edge_residue=irq_clk96_edge_count%48;
        irq_s6_canonical_residue=irq_canonical_cpu_residue(irq_s6_edge_residue);
        irq_s6_line_age=irq_source_line_age;
        irq_s6_source_y=irq_source_line_y;
        irq_s6_frame=irq_source_frame_id;
        irq_s6_expected=irq_hv_model_d2;
    end
    if (cpu_capture_en) begin
        if (!cpu_capture_current_seen && !ym_dtackn) begin
            cpu_capture_current_seen = 1;
            cpu_capture_current_data = ym_cd_o;
            cpu_capture_current_dir = ym_cd_d;
        end
        if (!cpu_capture_legacy_seen && !ym_dtackn_legacy) begin
            cpu_capture_legacy_seen = 1;
            cpu_capture_legacy_data = ym_cd_o_legacy;
            cpu_capture_legacy_dir = ym_cd_d_legacy;
        end
    end
`ifdef PASSIVE_TEST
    if (service_hv_capture_en && cpu_capture_en && !ym_dtackn && !service_hv_capture_seen) begin
        service_hv_capture_seen = 1;
        service_hv_capture_x = source_x_sample;
        service_hv_capture_y = source_y_sample;
        service_hv_capture_source_h = raster_hdump;
        service_hv_capture_source_v = raster_vdump;
        service_hv_capture_expected = {service_hv_ext_v_d2,service_hv_ext_h_d2};
        $display("SERVICE_HV_S6 t=%0t CA=%06x CD=%04x ioaddr=%06x capture=%04x decode134/142/160=%b%b%b w333=%b l90/91=%02x/%02x w347=%02x H/V=%0d/%0d sourceXY=%0d/%0d",
            $time,ca,ym_cd_o,uut_ym.io_address, cpu_capture_current_data,
            uut_ym.w134,uut_ym.w142,uut_ym.w160,uut_ym.w333,uut_ym.l90,uut_ym.l91,uut_ym.w347,
            uut_ym.l106,uut_ym.l105,source_x_sample,source_y_sample);
    end
`endif
end

`ifdef PASSIVE_TEST
always @(posedge clk48) begin
    if (service_hv_capture_en && raster_lhbl && raster_lvbl &&
        source_x_sample>=10'd308 && source_x_sample<=10'd314) begin
        $display("HV_PIPE_EDGE t=%0t x=%0d y=%0d pxl=%b q/t=%0d/%0d H/V=%0d/%0d l91/l90=%02x/%02x io=%04x",
            $time,source_x_sample,source_y_sample,pxl_cen,uut_ym.passive_quarter,
            uut_ym.passive_tick,uut_ym.l106,uut_ym.l105,uut_ym.l91,uut_ym.l90,uut_ym.io_data);
    end
end
`endif

`ifdef PASSIVE_TEST
always @(posedge ym_clk) begin
    if (service_hv_latch_capture_en && uut_ym.w337 && !service_hv_latch_prev &&
        !service_hv_latch_capture_seen) begin
        service_hv_latch_capture_seen = 1;
        service_hv_latch_x = source_x_sample;
        service_hv_latch_y = source_y_sample;
        service_hv_latch_line_id = service_hv_line_id;
    end
    service_hv_latch_prev <= uut_ym.w337;
end
`endif

always @(posedge ym_clk) begin
    ca_r <= feature_bus_active ? feature_ca : ca;
    cd_r <= feature_bus_active ? feature_cd : cd;
    asn_r <= feature_bus_active ? feature_as_n : as_n;
    uds_r <= feature_bus_active ? feature_uds : uds;
    lds_r <= feature_bus_active ? feature_lds : lds;
    rnw_r <= feature_bus_active ? feature_rw : rw;
    ym_ad_mem <= ym_read_data;
    ym_sd_mem <= ym_sd;
    ym_dtack_r <= {ym_dtack_r[0], ym_dtack};
    ym_edclk_l <= ym_edclk_d ? ym_edclk_o : edclk;
end

always @(posedge clk) begin
    ca_r_legacy <= feature_bus_active ? feature_ca_legacy : ca;
    cd_r_legacy <= feature_bus_active ? feature_cd_legacy : cd;
    asn_r_legacy <= feature_bus_active ? feature_as_n_legacy : as_n;
    uds_r_legacy <= feature_bus_active ? feature_uds_legacy : uds;
    lds_r_legacy <= feature_bus_active ? feature_lds_legacy : lds;
    rnw_r_legacy <= feature_bus_active ? feature_rw_legacy : rw;
    ym_ad_mem_legacy <= ym_read_data_legacy;
    ym_sd_mem_legacy <= ym_sd_legacy;
    ym_dtack_r_legacy <= {ym_dtack_r_legacy[0], ym_dtack_legacy};
    ym_edclk_l_legacy <= ym_edclk_d_legacy ? ym_edclk_o_legacy : edclk;
end

ym7101 #(.PASSIVE(PASSIVE_MODE)) uut_ym(
    .MCLK           ( ym_clk              ),
    .pxl_cen        ( pxl_cen             ),
    .pxl2_cen       ( pxl2_cen            ),
    .HS             ( raster_hs           ),
    .VS             ( raster_vs           ),
    .LHBL           ( raster_lhbl         ),
    .LVBL           ( raster_lvbl         ),
    .SD             ( ym_sd               ),
    .SE1            (                     ),
    .SE0            ( ym_se0              ),
    .SC             ( ym_sc               ),
    .RAS1           ( ym_ras              ),
    .CAS1           ( ym_cas              ),
    .WE1            ( ym_we               ),
    .WE0            ( ym_we0              ),
    .OE1            ( ym_oe               ),
    .RD_i           ( ym_rd_o             ),
    .RD_o           ( ym_rd_o             ),
    .RD_d           ( ym_rd_d             ),
    .DAC_R          ( ym_r                ),
    .DAC_G          ( ym_g                ),
    .DAC_B          ( ym_b                ),
    .AD_i           ( ym_read_data        ),
    .AD_o           ( ym_ad_o             ),
    .AD_d           ( ym_ad_d             ),
    .YS             ( ym_ys               ),
    .SPA_B_i        ( 1'b1                ),
    .SPA_B_pull     ( ym_spa_b            ),
    .VSYNC          (                     ),
    .CSYNC_i        ( 1'b1                ),
    .CSYNC_pull     (                     ),
    .HSYNC_i        ( 1'b1                ),
    .HSYNC_pull     (                     ),
    .HL             ( hl_test             ),
    .SEL0           ( 1'b1                ),
    .PAL            ( 1'b0                ),
    .RESET          ( reset_n             ),
    .CLK1_i         ( cpu_clk             ),
    .CLK1_o         (                     ),
    .SBCR           (                     ),
    .CLK0           (                     ),
    .MCLK_e         ( mclk_e              ),
    .EDCLK_i        ( ym_edclk_l          ),
    .EDCLK_o        ( ym_edclk_o          ),
    .EDCLK_d        ( ym_edclk_d          ),
    .reg_m5         ( ym_reg_m5           ),
    .CD_i           ( ym_cd_d ? cd_r : ym_cd_o ),
    .CD_o           ( ym_cd_o             ),
    .CD_d           ( ym_cd_d             ),
    .CA_i           ( ca_r                ),
    .CA_o           (                     ),
    .CA_d           (                     ),
    .SOUND          ( ym_sound            ),
    .INT_pull       ( ym_int              ),
    .BR_pull        ( ym_br               ),
    .BGACK_i        ( ~ym_bgack           ),
    .BGACK_pull     ( ym_bgack            ),
    .BG             ( 1'b1                ),
    .MREQ           ( 1'b1                ),
    .INTAK          ( service_intak       ),
    .IPL1_pull      ( ym_ipl1             ),
    .IPL2_pull      ( ym_ipl2             ),
    .IORQ           ( 1'b1                ),
    .RD             ( 1'b1                ),
    .WR             ( 1'b1                ),
    .M1             ( 1'b1                ),
    .AS             ( asn_r               ),
    .UDS            ( uds_r               ),
    .LDS            ( lds_r               ),
    .RW             ( rnw_r               ),
    .DTACK_i        ( ym_dtack_r[1]       ),
    .DTACK_pull     ( ym_dtack            ),
    .UWR            (                     ),
    .LWR            (                     ),
    .OE0            (                     ),
    .CAS0           (                     ),
    .RAS0           (                     ),
    .RA             (                     ),
    .ext_test_2     ( 1'b0                ),
    .vdp_hclk1      (                     ),
    .vdp_intfield   (                     ),
    .vdp_de_h       ( ym_de_h             ),
    .vdp_de_v       ( ym_de_v             ),
    .vdp_m5         (                     ),
    .vdp_rs1        (                     ),
    .vdp_m2         (                     ),
    .vdp_lcb        (                     ),
    .vdp_psg_clk1   (                     ),
    .vdp_vsync2     ( ym_vs               ),
    .vdp_hsync2     ( ym_hs               ),
    .vdp_cramdot_dis( 1'b0                ),
    .vdp_dma_oe_early(                    ),
    .vdp_dma        (                     )
);

ym7101_legacy uut_ym_legacy(
    .MCLK           ( clk                 ),
    .SD             ( ym_sd_legacy        ),
    .SE1            (                     ),
    .SE0            ( ym_se0_legacy       ),
    .SC             ( ym_sc_legacy        ),
    .RAS1           ( ym_ras_legacy       ),
    .CAS1           ( ym_cas_legacy       ),
    .WE1            ( ym_we_legacy        ),
    .WE0            ( ym_we0_legacy       ),
    .OE1            ( ym_oe_legacy         ),
    .RD_i           ( ym_rd_o_legacy      ),
    .RD_o           ( ym_rd_o_legacy      ),
    .RD_d           ( ym_rd_d_legacy      ),
    .DAC_R          ( ym_r_legacy         ),
    .DAC_G          ( ym_g_legacy         ),
    .DAC_B          ( ym_b_legacy         ),
    .AD_i           ( ym_read_data_legacy ),
    .AD_o           ( ym_ad_o_legacy      ),
    .AD_d           ( ym_ad_d_legacy      ),
    .YS             ( ym_ys_legacy        ),
    .SPA_B_i        ( 1'b1                ),
    .SPA_B_pull     ( ym_spa_b_legacy     ),
    .VSYNC          (                     ),
    .CSYNC_i         ( 1'b1                ),
    .CSYNC_pull     (                     ),
    .HSYNC_i        ( 1'b1                ),
    .HSYNC_pull     (                     ),
    .HL             ( hl_test             ),
    .SEL0           ( 1'b1                ),
    .PAL            ( 1'b0                ),
    .RESET          ( reset_n             ),
    .CLK1_i         ( cpu_clk             ),
    .CLK1_o         (                     ),
    .SBCR           (                     ),
    .CLK0           (                     ),
    .MCLK_e         ( mclk_e_legacy       ),
    .EDCLK_i        ( ym_edclk_l_legacy   ),
    .EDCLK_o        ( ym_edclk_o_legacy   ),
    .EDCLK_d        ( ym_edclk_d_legacy   ),
    .reg_m5         ( ym_reg_m5_legacy    ),
    .CD_i           ( ym_cd_d_legacy ? cd_r_legacy : ym_cd_o_legacy ),
    .CD_o           ( ym_cd_o_legacy      ),
    .CD_d           ( ym_cd_d_legacy      ),
    .CA_i           ( ca_r_legacy         ),
    .CA_o           (                     ),
    .CA_d           (                     ),
    .SOUND          ( ym_sound_legacy     ),
    .INT_pull       ( ym_int_legacy       ),
    .BR_pull        ( ym_br_legacy        ),
    .BGACK_i        ( ~ym_bgack_legacy    ),
    .BGACK_pull     ( ym_bgack_legacy     ),
    .BG             ( 1'b1                ),
    .MREQ           ( 1'b1                ),
    .INTAK          ( service_intak       ),
    .IPL1_pull      ( ym_ipl1_legacy      ),
    .IPL2_pull      ( ym_ipl2_legacy      ),
    .IORQ           ( 1'b1                ),
    .RD             ( 1'b1                ),
    .WR             ( 1'b1                ),
    .M1             ( 1'b1                ),
    .AS             ( asn_r_legacy        ),
    .UDS            ( uds_r_legacy        ),
    .LDS            ( lds_r_legacy        ),
    .RW             ( rnw_r_legacy        ),
    .DTACK_i        ( ym_dtack_r_legacy[1]),
    .DTACK_pull     ( ym_dtack_legacy     ),
    .UWR            (                     ),
    .LWR            (                     ),
    .OE0            (                     ),
    .CAS0           (                     ),
    .RAS0           (                     ),
    .RA             (                     ),
    .ext_test_2     ( 1'b0                ),
    .vdp_hclk1      (                     ),
    .vdp_intfield   (                     ),
    .vdp_de_h       ( ym_de_h_legacy      ),
    .vdp_de_v       ( ym_de_v_legacy      ),
    .vdp_m5         (                     ),
    .vdp_rs1        (                     ),
    .vdp_m2         (                     ),
    .vdp_lcb        (                     ),
    .vdp_psg_clk1   (                     ),
    .vdp_vsync2     ( ym_vs_legacy        ),
    .vdp_hsync2     ( ym_hs_legacy        ),
    .vdp_cramdot_dis( 1'b0                ),
    .vdp_dma_oe_early(                    ),
    .vdp_dma        (                     )
);

always @(posedge ym_clk) begin
    #1;
    if (h40_trace_en &&
        {uut_ym.reg_code[1:0],uut_ym.t25,uut_ym.w184,uut_ym.w193,
         uut_ym.l32,uut_ym.l33,uut_ym.l34,uut_ym.l31,uut_ym.w205,uut_ym.w215,
         uut_ym.reg_data_l2,uut_ym.reg_rs1,uut_ym.reg_rs0} !== h40_trace_last) begin
        h40_trace_last = {uut_ym.reg_code[1:0],uut_ym.t25,uut_ym.w184,uut_ym.w193,
                          uut_ym.l32,uut_ym.l33,uut_ym.l34,uut_ym.l31,uut_ym.w205,uut_ym.w215,
                          uut_ym.reg_data_l2,uut_ym.reg_rs1,uut_ym.reg_rs0};
        $display("H40_CHAIN t=%0t H=%0d code=%b t25=%b w184=%b w193=%b l32/33/34/31=%b%b%b%b w205=%b w215=%b data=%05x rs1/rs0=%b%b addr=%05x",
            $time,uut_ym.l106,uut_ym.reg_code[1:0],uut_ym.t25,uut_ym.w184,uut_ym.w193,
            uut_ym.l32,uut_ym.l33,uut_ym.l34,uut_ym.l31,uut_ym.w205,uut_ym.w215,
            uut_ym.reg_data_l2,uut_ym.reg_rs1,uut_ym.reg_rs0,uut_ym.reg_addr);
    end
    if (h40_trace_en && uut_ym.w215 && uut_ym.reg_code[1:0] == 2'b10 &&
        uut_ym.reg_data_l2[15:0] == 16'h0c81) h40_latch_seen = 1;
end

vram #(.SERIAL_LOOKAHEAD(PASSIVE_MODE)) ym_vram(
    .MCLK  ( ym_clk            ),
    .RAS   ( ym_ras            ),
    .CAS   ( ym_cas            ),
    .WE    ( ym_we0            ),
    .OE    ( ym_oe             ),
    .SC    ( ym_sc             ),
    .SE    ( ym_se0            ),
    .AD    ( ym_read_data      ),
    .RD_i  ( ym_read_data      ),
    .RD_o  ( ym_vram_ad_o      ),
    .RD_d  ( ym_vram_ad_d      ),
    .SD_o  ( ym_vram_sd_o      ),
    .SD_d  ( ym_vram_sd_d      )
);

vram_legacy ym_vram_legacy(
    .MCLK  ( clk                       ),
    .RAS   ( ym_ras_legacy             ),
    .CAS   ( ym_cas_legacy             ),
    .WE    ( ym_we0_legacy             ),
    .OE    ( ym_oe_legacy              ),
    .SC    ( ym_sc_legacy              ),
    .SE    ( ym_se0_legacy             ),
    .AD    ( ym_read_data_legacy       ),
    .RD_i  ( ym_read_data_legacy       ),
    .RD_o  ( ym_vram_ad_o_legacy       ),
    .RD_d  ( ym_vram_ad_d_legacy       ),
    .SD_o  ( ym_vram_sd_o_legacy       ),
    .SD_d  ( ym_vram_sd_d_legacy       )
);

integer mem_init;
initial begin
    for (mem_init = 0; mem_init < 65536; mem_init = mem_init + 1) begin
        ym_vram.mem[mem_init] = 8'h00;
        ym_vram_legacy.mem[mem_init] = 8'h00;
    end
end

wire [93:0] ym_outputs = {
    ym_rd_o, ym_rd_d, ym_ad_o, ym_ad_d, ym_cd_o, ym_cd_d, ym_dtack,
    ym_ras, ym_cas, ym_we, ym_oe, ym_sc, ym_r, ym_g, ym_b, ym_ys,
    ym_we0, ym_se0, ym_spa_b, ym_int, ym_br, ym_ipl1, ym_ipl2,
    ym_reg_m5, ym_de_h, ym_de_v, ym_hs, ym_vs, ym_sound
};
wire [93:0] ym_outputs_legacy = {
    ym_rd_o_legacy, ym_rd_d_legacy, ym_ad_o_legacy, ym_ad_d_legacy,
    ym_cd_o_legacy, ym_cd_d_legacy, ym_dtack_legacy, ym_ras_legacy,
    ym_cas_legacy, ym_we_legacy, ym_oe_legacy, ym_sc_legacy,
    ym_r_legacy, ym_g_legacy, ym_b_legacy, ym_ys_legacy,
    ym_we0_legacy, ym_se0_legacy, ym_spa_b_legacy, ym_int_legacy, ym_br_legacy,
    ym_ipl1_legacy, ym_ipl2_legacy,
    ym_reg_m5_legacy, ym_de_h_legacy, ym_de_v_legacy,
    ym_hs_legacy, ym_vs_legacy, ym_sound_legacy
};

reg ras = 1, cas = 1, we = 1, oe = 1, sc = 1, se = 0;
reg [7:0] ad = 0, rd_i = 0;
wire [7:0] rd_o, rd_o_legacy, sd_o, sd_o_legacy;
wire rd_d, rd_d_legacy, sd_d, sd_d_legacy;

vram uut(
    .MCLK  ( clk   ),
    .RAS   ( ras   ),
    .CAS   ( cas   ),
    .WE    ( we    ),
    .OE    ( oe    ),
    .SC    ( sc    ),
    .SE    ( se    ),
    .AD    ( ad    ),
    .RD_i  ( rd_i  ),
    .RD_o  ( rd_o  ),
    .RD_d  ( rd_d  ),
    .SD_o  ( sd_o  ),
    .SD_d  ( sd_d  )
);

vram_legacy uut_legacy(
    .MCLK  ( clk          ),
    .RAS   ( ras          ),
    .CAS   ( cas          ),
    .WE    ( we           ),
    .OE    ( oe           ),
    .SC    ( sc           ),
    .SE    ( se           ),
    .AD    ( ad           ),
    .RD_i  ( rd_i         ),
    .RD_o  ( rd_o_legacy  ),
    .RD_d  ( rd_d_legacy  ),
    .SD_o  ( sd_o_legacy  ),
    .SD_d  ( sd_d_legacy  )
);

function [15:0] physical_addr;
    input [15:0] cpu_addr;
    begin
        physical_addr = {cpu_addr[9:2],cpu_addr[15:10],cpu_addr[1:0]};
    end
endfunction

task tick;
begin
    if (use48) @(posedge clk48);
    else @(posedge clk);
    #1;
    if (compare_en && {rd_o, rd_d, sd_o, sd_d} !== {rd_o_legacy, rd_d_legacy, sd_o_legacy, sd_d_legacy}) begin
        $display("FAIL: current and baseline VRAM outputs differ");
        $fatal(1);
    end
    if (compare_en && ym_outputs !== ym_outputs_legacy) begin
        $display("FAIL: current and baseline YM7101 outputs differ");
        $fatal(1);
    end
    if (PASSIVE_MODE && reset_n && !rate_check_en && !passive_geometry_seen &&
        (uut_ym.clk1 !== ~phase_tb[1] || uut_ym.clk2 !== phase_tb[1] ||
         uut_ym.hclk1 !== (phase_tb[2] ^ phase_tb[1]) ||
         uut_ym.hclk2 !== ~(phase_tb[2] ^ phase_tb[1]))) begin
        $display("FAIL: passive normal8 phase table mismatch phase=%0d clk=%b%b hclk=%b%b",
            phase_tb, uut_ym.clk1, uut_ym.clk2, uut_ym.hclk1, uut_ym.hclk2);
        $fatal(1);
    end
end
endtask

task cpu_write;
    input [22:0] address;
    input [15:0] data;
    integer timeout;
begin
    // Model all four 10 MHz FX68K states. Each Phi1/Phi2 phase is 50 ns:
    // S0 address, S1 AS/RW, S2 write data, S3 DS, S4 ACK, S6 release,
    // then the 50 ns post-release hold before the next S0.
    @(posedge cpu_clk);
    if (address==23'h600002 && (data==16'h0140 || data==16'h00c1)) begin
        if (data==16'h0140 && service_copy_expected_first_s0!=0 &&
            service_cpu_edge_index+1!=service_copy_expected_first_s0) begin
            $display("FAIL: copy first S0 edge mismatch expected=%0d actual=%0d",
                service_copy_expected_first_s0,service_cpu_edge_index+1);
            $fatal(1);
        end
        $display("SERVICE_COPY_COMMAND_S0 data=%04x cpu_edge=%0d t=%0t source_raster_HV=%0d/%0d source_phase=%0d cpu_phase=%b cen20=%b refclk=%b candidateclk=%b H/V=%0d/%0d Q/tick/dwell=%0d/%0d/%0d",
            data,service_cpu_edge_index+1,$time,raster_hdump,raster_vdump,
            raster_phase_tb,cpu_clk,cen20,mclk_e_legacy,mclk_e,
            uut_ym.l106,uut_ym.l105,uut_ym.passive_quarter,uut_ym.passive_tick,uut_ym.passive_dwell);
        if (copy_start_late && data==16'h00c1) begin
            if (!PASSIVE_MODE ||
                {1'b0,uut_ym.l106}<10'd457 ||
                {1'b0,uut_ym.l106}>uut_ym.passive_fast_last ||
                uut_ym.passive_dwell!==3'd1) begin
                $display("FAIL: late critical 00c1 S0 missed fast region source_H/V=%0d/%0d native_H/V=%0d/%0d Q/tick/dwell=%0d/%0d/%0d fast_last=%0d",
                    raster_hdump,raster_vdump,uut_ym.l106,uut_ym.l105,
                    uut_ym.passive_quarter,uut_ym.passive_tick,uut_ym.passive_dwell,uut_ym.passive_fast_last);
                $fatal(1);
            end
            copy_late_command_fast_seen=1'b1;
            $display("SERVICE_COPY_LATE_FAST_S0 source_H/V=%0d/%0d native_H/V=%0d/%0d Q/tick/dwell=%0d/%0d/%0d fast_window=457..%0d",
                raster_hdump,raster_vdump,uut_ym.l106,uut_ym.l105,
                uut_ym.passive_quarter,uut_ym.passive_tick,uut_ym.passive_dwell,uut_ym.passive_fast_last);
        end
        if (data==16'h0140) service_copy_expected_first_s0=0;
    end
    ca = address;
    rw = 0;
    uds = 1;
    lds = 1;
    as_n = 1;
    @(negedge cpu_clk);
    as_n = 0;
    @(posedge cpu_clk);
    cd = data;
    @(negedge cpu_clk);
    ack_current_seen = 0;
    ack_legacy_seen = 0;
    ack_start_cycle = ack_cycle;
    ack_capture_en = 1;
    uds = 0;
    lds = 0;
    timeout = 0;
    while ((ym_dtackn || (compare_en && ym_dtackn_legacy)) && timeout < 1024) begin
        @(posedge cpu_clk);
        #2;
        timeout = timeout + 1;
        if (service_fifo_probe && uut_ym.w252 && ym_dtackn) begin
            service_fifo_withheld_samples = service_fifo_withheld_samples + 1;
            if (ca !== address || cd !== data || as_n !== 1'b0 || uds !== 1'b0 || lds !== 1'b0) begin
                $display("FAIL: full FIFO write bus changed before ACK address=%06x data=%04x",ca,cd);
                $fatal(1);
            end
        end
    end
    if (service_reg_trace_en && address==23'h600002)
        $display("SERVICE_REG_BUS_S4 t=%0t addr=%06x data=%04x wait=%0d H/V=%0d/%0d dtack=%b/%b",
            $time,address,data,timeout,uut_ym.l106,uut_ym.l105,ym_dtackn,ym_dtackn_legacy);
    ack_capture_en = 0;
    if (service_fifo_probe && address==23'h600000) begin
        service_fifo_accepted_writes = service_fifo_accepted_writes + 1;
        if (timeout > service_fifo_max_wait) service_fifo_max_wait = timeout;
    end
    if (!ack_current_seen || (compare_en && !ack_legacy_seen)) begin
        $display("FAIL: write to %06x missing first ACK current=%b/%0d legacy=%b/%0d", address,
            ack_current_seen, ack_current_latency, ack_legacy_seen, ack_legacy_latency);
        $fatal(1);
    end
    service_cpu_write_accept_count = service_cpu_write_accept_count + 1;
    // S4 is the ACK edge above. Enter S6 at Phi1, release at Phi2, then
    // keep address/data/RW stable through the following Phi1 hold.
    @(negedge cpu_clk);
    @(posedge cpu_clk);
    as_n = 1;
    uds = 1;
    lds = 1;
    if (service_reg_trace_en && address==23'h600002)
        $display("SERVICE_REG_BUS_S6_RELEASE t=%0t addr=%06x data=%04x H/V=%0d/%0d dtack=%b/%b",
            $time,address,data,uut_ym.l106,uut_ym.l105,ym_dtackn,ym_dtackn_legacy);
    @(negedge cpu_clk);
    timeout = 0;
    while ((!ym_dtackn || (compare_en && !ym_dtackn_legacy)) && timeout < 32) begin
        tick();
        timeout = timeout + 1;
    end
    if (ym_dtackn !== 1'b1 || (compare_en && ym_dtackn_legacy !== 1'b1)) begin
        $display("FAIL: DTACK did not recover after write to %06x", address);
        $fatal(1);
    end
end
endtask

task cpu_read;
    input [22:0] address;
    output [15:0] data;
    integer timeout;
    reg s0_sampled_by_caller;
begin
    // Match the write task's full 10 MHz S0/S1/S2/S3/S4/S6 sequence.
    s0_sampled_by_caller=irq_s0_on_current_edge;
    if (irq_s0_on_current_edge) irq_s0_on_current_edge=0;
    else @(posedge cpu_clk);
    if (irq_hv_trace_en) begin
        if (!s0_sampled_by_caller) #1;
        irq_s0_clk48=irq_clk48_count;
        irq_s0_clk96=irq_clk96_edge_count;
        irq_s0_edge_residue=irq_clk96_edge_count%48;
        irq_s0_canonical_residue=irq_canonical_cpu_residue(irq_s0_edge_residue);
        irq_s0_line_age=irq_source_line_age;
        irq_s0_source_y=irq_source_line_y;
        irq_s0_frame=irq_source_frame_id;
    end
    ca = address;
    cd = 16'hffff;
    rw = 1;
    uds = 1;
    lds = 1;
    as_n = 1;
    @(negedge cpu_clk);
    as_n = 0;
    @(posedge cpu_clk);
    ack_current_seen = 0;
    ack_legacy_seen = 0;
    cpu_capture_current_seen = 0;
    cpu_capture_legacy_seen = 0;
    cpu_capture_en = 0;
    ack_start_cycle = ack_cycle;
    ack_capture_en = 1;
    @(negedge cpu_clk);
    uds = 0;
    lds = 0;
    timeout = 0;
    while ((ym_dtackn || (compare_en && ym_dtackn_legacy)) && timeout < 1024) begin
        @(posedge cpu_clk);
        #2;
        timeout = timeout + 1;
    end
    ack_capture_en = 0;
    if (!ack_current_seen || (compare_en && !ack_legacy_seen)) begin
        $display("FAIL: read from %06x missing first ACK current=%b/%0d legacy=%b/%0d", address,
            ack_current_seen, ack_current_latency, ack_legacy_seen, ack_legacy_latency);
        $fatal(1);
    end
    if (ym_dtackn !== 1'b0 || (compare_en && ym_dtackn_legacy !== 1'b0)) begin
        $display("FAIL: S4 ACK not accepted for read addr=%06x current DTACK=%b legacy=%b",
            address,ym_dtackn,ym_dtackn_legacy);
        $fatal(1);
    end
    service_cpu_read_accept_count = service_cpu_read_accept_count + 1;
    // Enter S6 at Phi1, sample each model at the legal S6 Phi2 capture edge,
    // then release AS/DS on that same edge. The test never waits on data value.
    @(negedge cpu_clk);
    cpu_capture_en = 1;
    @(posedge cpu_clk);
    #2;
    cpu_capture_en = 0;
    as_n = 1;
    uds = 1;
    lds = 1;
    if (irq_ack_watch_en) begin
        irq_ack_release_mclk=irq_ym_mclk_count;
        irq_ack_ym_as_release_mclk=-1;
        irq_ack_release_h_event_count=irq_h_event_count;
        irq_ack_release_v_event_count=irq_v_event_count;
    end
    if (!cpu_capture_current_seen || (compare_en && !cpu_capture_legacy_seen)) begin
        $display("FAIL: CPU capture edge missed ACK addr=%06x current=%b legacy=%b",
            address,cpu_capture_current_seen,cpu_capture_legacy_seen);
        $fatal(1);
    end
    data = cpu_capture_current_data;
    if (cpu_capture_current_dir !== 1'b0 || (^cpu_capture_current_data) === 1'bx ||
        (compare_en && (cpu_capture_legacy_dir !== 1'b0 || (^cpu_capture_legacy_data) === 1'bx)) ||
        (compare_en && cpu_capture_current_data !== cpu_capture_legacy_data)) begin
        $display("FAIL: CPU-edge read addr=%06x current=%04x/%b firstACK%0d baseline=%04x/%b firstACK%0d",
            address,cpu_capture_current_data,cpu_capture_current_dir,ack_current_latency,
            cpu_capture_legacy_data,cpu_capture_legacy_dir,ack_legacy_latency);
        $fatal(1);
    end
    @(negedge cpu_clk);
    timeout = 0;
    while ((!ym_dtackn || (compare_en && !ym_dtackn_legacy)) && timeout < 32) begin
        tick();
        timeout = timeout + 1;
    end
    if (ym_dtackn !== 1'b1 || (compare_en && ym_dtackn_legacy !== 1'b1)) begin
        $display("FAIL: DTACK did not recover after read from %06x", address);
        $fatal(1);
    end
end
endtask

`ifdef GEOMETRY_SWITCH_SCENARIO
task geometry_capture_sentinels;
    input save_reference;
    integer i, timeout, period_limit;
    begin
        for (i=0; i<6; i=i+1) begin
            geometry_capture_counts[i]=0;
            geometry_capture_rgb[i]=0;
            geometry_capture_transparent[i]=0;
        end
        geometry_capture_frame=-1;
        geometry_capture_started=0;
        geometry_capture_done=0;
        geometry_capture_reference=save_reference;
        geometry_capture_enable=1;
        period_limit=3*geometry_switch_frame_lines*geometry_switch_line_pixels*8+
            geometry_switch_line_pixels*8;
        timeout=0;
        while (!geometry_capture_done && timeout<period_limit) begin
            @(posedge clk48);
            timeout=timeout+1;
        end
        geometry_capture_enable=0;
        if (!geometry_capture_done) begin
            $display("GEOMETRY_FAIL sentinel rows did not complete within %0d clk48 edges mode=%0d",timeout,geometry_switch_mode);
            $fatal(1);
        end
        for (i=0; i<6; i=i+1) begin
            if (geometry_capture_counts[i]!=320 ||
                (i%3<2 && geometry_capture_rgb[i]==0) ||
                (i%3==2 && geometry_capture_transparent[i]!=320)) begin
                $display("GEOMETRY_FAIL incomplete/empty sentinel pass=%0d row_slot=%0d pixels=%0d rgb=%0d transparent=%0d",
                    i/3,i%3,geometry_capture_counts[i],geometry_capture_rgb[i],geometry_capture_transparent[i]);
                $fatal(1);
            end
        end
        $display("GEOMETRY_ROWS mode=%0d frames=2 rows=0,1,100 each=320 RGB/YS tuples checked",
            geometry_switch_mode);
    end
endtask

task geometry_switch_to;
    input [1:0] new_mode;
    integer timeout, expected_pixels, timing_change_start;
    reg [15:0] geometry_status;
    reg [7:0] saved_r1, saved_r12;
    begin
        saved_r1={uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,
            uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_m3,uut_ym.reg_81_b0};
        saved_r12={uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,
            uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1};
        timing_change_start=geometry_dut_timing_changes;
        if (new_mode==0) expected_pixels=400;
        else expected_pixels=384;
        geometry_switch_request=new_mode;
        geometry_switch_request_valid=1;
        timeout=0;
        while (geometry_switch_mode!=new_mode && timeout<3*400*262*8) begin
            @(posedge clk48);
            timeout=timeout+1;
        end
        geometry_switch_request_valid=0;
        if (geometry_switch_mode!=new_mode) begin
            $display("GEOMETRY_FAIL mode request %0d did not commit within three original frames",new_mode);
            $fatal(1);
        end
        if (geometry_switch_source_commit!==1'b1) begin
            // timing_change is one pixel wide in the 48 MHz domain; the
            // source-change counter provides the durable event receipt.
            if (geometry_source_changes==0) begin
                $display("GEOMETRY_FAIL source commit pulse was not observed");
                $fatal(1);
            end
        end
        timeout=0;
        while (uut_ym.passive_render_ready && timeout<2*400*8) begin
            @(posedge clk48);
            timeout=timeout+1;
        end
        if (uut_ym.passive_render_ready || ym_ys!==1'b0 ||
            {ym_r,ym_g,ym_b}!==24'h000000) begin
            $display("GEOMETRY_FAIL renderer did not mute after mode=%0d change ready/YS/RGB=%b/%b/%06x",
                new_mode,uut_ym.passive_render_ready,ym_ys,{ym_r,ym_g,ym_b});
            $fatal(1);
        end
        if (geometry_dut_timing_changes<=timing_change_start) begin
            $display("GEOMETRY_FAIL passive raster did not report timing_change after mode=%0d",new_mode);
            $fatal(1);
        end
        geometry_prime_check_enable=1;
        geometry_prime_active=0;
        geometry_prime_done=0;
        geometry_prime_events=0;
        timeout=0;
        while ((!uut_ym.passive_geometry_supported || !uut_ym.passive_raster_locked ||
                uut_ym.passive_line_pixels!=expected_pixels ||
                uut_ym.passive_frame_lines!=geometry_switch_frame_lines ||
                uut_ym.passive_active_lines!=224) &&
               timeout<5*400*262*8+400*8) begin
            @(posedge clk48);
            timeout=timeout+1;
        end
        if (!uut_ym.passive_geometry_supported || !uut_ym.passive_raster_locked ||
            uut_ym.passive_line_pixels!=expected_pixels || uut_ym.passive_active_pixels!=320 ||
            uut_ym.passive_frame_lines!=geometry_switch_frame_lines || uut_ym.passive_active_lines!=224) begin
            $display("GEOMETRY_FAIL relock mode=%0d observed T/W/N/A=%0d/%0d/%0d/%0d expected line=%0d frame=%0d after=%0d",
                new_mode,uut_ym.passive_line_pixels,uut_ym.passive_active_pixels,
                uut_ym.passive_frame_lines,uut_ym.passive_active_lines,
                expected_pixels,geometry_switch_frame_lines,timeout);
            $fatal(1);
        end
        timeout=0;
        while (!uut_ym.passive_render_ready && timeout<2*400*262*8+2*400*8) begin
            @(posedge clk48);
            timeout=timeout+1;
        end
        if (!uut_ym.passive_render_ready || uut_ym.passive_fast_quota!==
            (new_mode==0 ? 7'd40 : 7'd72)) begin
            $display("GEOMETRY_FAIL renderer prime/quota mode=%0d ready=%b quota=%0d after=%0d",
                new_mode,uut_ym.passive_render_ready,uut_ym.passive_fast_quota,timeout);
            $fatal(1);
        end
        if (!geometry_prime_done || saved_r1!==8'h44 || saved_r12!==8'h81 ||
            reset_n!==1'b1 ||
            saved_r1!=={uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,
                uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_m3,uut_ym.reg_81_b0} ||
            saved_r12!=={uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,
                uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1}) begin
            $display("GEOMETRY_FAIL reset/MMR state changed or prime missing mode=%0d R1/R12=%02x/%02x expected=%02x/%02x prime=%b reset=%b",
                new_mode,
                {uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_m3,uut_ym.reg_81_b0},
                {uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1},
                saved_r1,saved_r12,geometry_prime_done,reset_n);
            $fatal(1);
        end
        geometry_prime_check_enable=0;
        cpu_read(23'h600002,geometry_status);
        if ((^geometry_status)===1'bx) begin
            $display("GEOMETRY_FAIL status read returned unknown data %04x",geometry_status);
            $fatal(1);
        end
        $display("GEOMETRY_STATUS mode=%0d data=%04x acknowledged reads=%0d",
            new_mode,geometry_status,service_cpu_read_accept_count);
        geometry_capture_sentinels(0);
        $display("GEOMETRY_READY mode=%0d T/N=%0d/%0d quota=%0d source_commit=%0d timing_changes=%0d",
            new_mode,uut_ym.passive_line_pixels,uut_ym.passive_frame_lines,
            uut_ym.passive_fast_quota,geometry_source_changes,geometry_dut_timing_changes);
    end
endtask

task run_geometry_switch_profile;
    begin
`ifdef PRODUCTION_TIMER_SCENARIO
        if (!uut_ym.passive_render_ready || geometry_switch_mode!=1 ||
            geometry_switch_line_pixels!=384 || geometry_switch_frame_lines!=260) begin
            $display("GEOMETRY_FAIL production timer did not start ready in default 384x260 mode");
            $fatal(1);
        end
        geometry_capture_sentinels(1);
        geometry_switch_to(0);
        geometry_switch_to(1);
        if (geometry_source_changes!=2) begin
            $display("GEOMETRY_FAIL production timer committed %0d changes, expected two",geometry_source_changes);
            $fatal(1);
        end
        $display("PRODUCTION_TIMER_SWITCH PASS 384x260 -> 400x262 -> 384x260; no VDP reset/MMR reprogram");
`else
        if (!uut_ym.passive_render_ready || geometry_switch_mode!=0 ||
            uut_ym.passive_line_pixels!=400 || uut_ym.passive_frame_lines!=262) begin
            $display("GEOMETRY_FAIL scenario did not start in ready 400x262 profile");
            $fatal(1);
        end
        geometry_capture_sentinels(1);
        geometry_switch_to(1);
        geometry_switch_to(0);
        geometry_switch_to(2);
        geometry_switch_to(0);
        if (geometry_source_changes!=4) begin
            $display("GEOMETRY_FAIL source committed %0d changes, expected four",geometry_source_changes);
            $fatal(1);
        end
        $display("GEOMETRY_SWITCH PASS 400x262 -> 384x260 -> 400x262 -> 384x261 -> 400x262; no reset/MMR reprogram; source line/VS/LVBL and pixel oracles passed");
`endif
    end
endtask
`endif

// Feature-scene writes use independent legal bus cycles so each YM model
// must acknowledge its own MMR and SAT programming.
integer feature_cpu_current_accepts = 0, feature_cpu_legacy_accepts = 0;
task feature_cpu_write_model;
    input model_legacy;
    input [22:0] address;
    input [15:0] data;
    integer timeout;
    begin
        feature_bus_active=1;
        feature_ca=0; feature_cd=0; feature_as_n=1; feature_uds=1; feature_lds=1; feature_rw=1;
        feature_ca_legacy=0; feature_cd_legacy=0; feature_as_n_legacy=1; feature_uds_legacy=1; feature_lds_legacy=1; feature_rw_legacy=1;
        if(!ym_dtackn || !ym_dtackn_legacy) begin
            $display("FEATURE_FAIL previous per-model CPU transaction has not released both DTACKs"); $fatal(1);
        end
        if(model_legacy) begin feature_ca_legacy=address; feature_rw_legacy=0; end
        else begin feature_ca=address; feature_rw=0; end

        @(posedge cpu_clk); // S0 address
        @(negedge cpu_clk);
        if(model_legacy) feature_as_n_legacy=0; else feature_as_n=0; // S1 AS/RW
        @(posedge cpu_clk); // S2 data setup
        if(model_legacy) feature_cd_legacy=data; else feature_cd=data;
        @(negedge cpu_clk);
        if(model_legacy) begin feature_uds_legacy=0; feature_lds_legacy=0; end
        else begin feature_uds=0; feature_lds=0; end // S3 DS

        timeout=0;
        while((model_legacy ? ym_dtackn_legacy : ym_dtackn) && timeout<1024) begin
            @(posedge cpu_clk); #2; timeout=timeout+1;
            if(model_legacy ? !ym_dtackn : !ym_dtackn_legacy) begin
                $display("FEATURE_FAIL inactive YM asserted DTACK during isolated write target=%0d addr=%06x",model_legacy,address); $fatal(1);
            end
        end
        if(model_legacy ? ym_dtackn_legacy : ym_dtackn) begin
            $display("FEATURE_FAIL isolated write missed ACK target=%0d addr=%06x",model_legacy,address); $fatal(1);
        end
        if(model_legacy) feature_cpu_legacy_accepts=feature_cpu_legacy_accepts+1;
        else feature_cpu_current_accepts=feature_cpu_current_accepts+1;

        @(negedge cpu_clk);
        @(posedge cpu_clk); // S6 release only the target model's pins
        if(model_legacy) begin feature_as_n_legacy=1; feature_uds_legacy=1; feature_lds_legacy=1; end
        else begin feature_as_n=1; feature_uds=1; feature_lds=1; end
        timeout=0;
        while(!(model_legacy ? ym_dtackn_legacy : ym_dtackn) && timeout<32) begin
            @(posedge cpu_clk); #2; timeout=timeout+1;
        end
        if(!(model_legacy ? ym_dtackn_legacy : ym_dtackn)) begin
            $display("FEATURE_FAIL isolated DTACK did not release target=%0d addr=%06x",model_legacy,address); $fatal(1);
        end
        if(model_legacy ? !ym_dtackn : !ym_dtackn_legacy) begin
            $display("FEATURE_FAIL inactive YM ACK leaked across isolated release target=%0d addr=%06x",model_legacy,address); $fatal(1);
        end
        @(negedge cpu_clk); // retain address/data for required post-S6 hold
    end
endtask

task feature_cpu_write_both;
    input [22:0] address;
    input [15:0] data;
    begin
        feature_cpu_write_model(1'b0,address,data);
        feature_cpu_write_model(1'b1,address,data);
    end
endtask

`ifdef PASSIVE_TEST
`include "features_profile.vh"
`endif

`ifndef LEGACY_FORMATS_TEST
initial begin
    reg [15:0] status, vram_readback1, vram_readback2;
    if ($test$plusargs("copy_start=late")) copy_start_late = 1'b1;
    @(negedge clk);
    repeat (8) tick();
    reset_n = 1;
`ifdef PASSIVE_TEST
    begin : phase_rate_check
        integer pixel_count, pixel2_count, n;
        pixel_count = 0;
        pixel2_count = 0;
        for (n = 0; n < 80; n = n + 1) begin
            tick();
            if (pxl_cen) pixel_count = pixel_count + 1;
            if (pxl2_cen) pixel2_count = pixel2_count + 1;
        end
        if (pixel_count !== 10 || pixel2_count !== 20) begin
            $display("FAIL: 48 MHz enable rates pxl=%0d pxl2=%0d over80ticks", pixel_count, pixel2_count);
            $fatal(1);
        end
    end
`else
    repeat (64) tick();
`endif

`ifdef SERVICE_COPY_FIRST
    if (copy_start_late && !PASSIVE_MODE) begin
        $display("FAIL: late copy start is passive-only");
        $fatal(1);
    end
    if (service_cpu_read_accept_count!=0) begin
        $display("FAIL: copy-first entered with %0d accepted CPU reads",service_cpu_read_accept_count);
        $fatal(1);
    end
    run_service_copy_first();
    $display("SERVICE_COPY_FIRST PASS: reset-origin write-only setup and strict copy oracle");
    $finish;
end
`else
    // Exercise a VDP register write at the M68k control port. The address
    // and data are stable before active-low AS, as on the physical bus.
    cpu_write(23'h600002, 16'h8104);
    timeout = 0;
    while ((ym_reg_m5 !== 1'b1 || ym_reg_m5_legacy !== 1'b1) && timeout < 512) begin
        tick();
        timeout = timeout + 1;
    end
    if (ym_reg_m5 !== 1'b1 || ym_reg_m5_legacy !== 1'b1) begin
        $display("FAIL: m5=%b/%b reg=%05x/%05x addr=%05x/%05x dtack=%b/%b",
            ym_reg_m5, ym_reg_m5_legacy, uut_ym.reg_data_l2,
            uut_ym_legacy.reg_data_l2, uut_ym.reg_addr,
            uut_ym_legacy.reg_addr, ym_dtackn, ym_dtackn_legacy);
        $fatal(1);
    end
    cpu_read(23'h600002, status);
    if ((^status) === 1'bx) begin
        $display("FAIL: CPU status read returned unknown bits %04x", status);
        $fatal(1);
    end

    // Program a VRAM write to address zero through the real CPU port and
    // YM7101/VRAM bus, then check the external byte memory contents.
    cpu_write(23'h600002, 16'h8104); // Keep Mode 5 display disabled
    cpu_write(23'h600002, 16'h8f02); // Set autoincrement to two bytes
    cpu_write(23'h600002, 16'h4000); // VRAM write, address high
    cpu_write(23'h600002, 16'h0000); // VRAM write, address low
    // Five distinct FIFO writes exceed the four-word buffer depth.
    cpu_write(23'h600000, 16'h1234);
    cpu_write(23'h600000, 16'h5678);
    cpu_write(23'h600000, 16'h9abc);
    cpu_write(23'h600000, 16'hdef0);
    cpu_write(23'h600000, 16'h55aa);
    timeout = 0;
    while ({ym_vram.mem[0], ym_vram.mem[1], ym_vram.mem[2], ym_vram.mem[3],
            ym_vram.mem[256], ym_vram.mem[257], ym_vram.mem[258], ym_vram.mem[259],
            ym_vram.mem[512], ym_vram.mem[513]} !==
           {8'h34,8'h12,8'h78,8'h56,8'hbc,8'h9a,8'hf0,8'hde,8'haa,8'h55} && timeout < 100000) begin
        tick();
        timeout = timeout + 1;
    end
    if ({ym_vram.mem[0], ym_vram.mem[1], ym_vram.mem[2], ym_vram.mem[3],
         ym_vram.mem[256], ym_vram.mem[257], ym_vram.mem[258], ym_vram.mem[259],
         ym_vram.mem[512], ym_vram.mem[513]} !==
        {8'h34,8'h12,8'h78,8'h56,8'hbc,8'h9a,8'hf0,8'hde,8'haa,8'h55} ||
        (compare_en && {ym_vram_legacy.mem[0], ym_vram_legacy.mem[1], ym_vram_legacy.mem[2], ym_vram_legacy.mem[3],
         ym_vram_legacy.mem[256], ym_vram_legacy.mem[257], ym_vram_legacy.mem[258], ym_vram_legacy.mem[259],
         ym_vram_legacy.mem[512], ym_vram_legacy.mem[513]} !==
        {8'h34,8'h12,8'h78,8'h56,8'hbc,8'h9a,8'hf0,8'hde,8'haa,8'h55})) begin
        $display("FAIL: five VRAM FIFO words did not drain in order after %0d clocks; writes=%0d code=%b fifo=%b mem=%02x,%02x,%02x,%02x,%02x,%02x,%02x,%02x,%02x,%02x base=%02x,%02x,%02x,%02x,%02x,%02x,%02x,%02x,%02x,%02x",
            timeout, ram_write_events, uut_ym.reg_code, {uut_ym.l54,uut_ym.l53,uut_ym.l52},
            ym_vram.mem[0],ym_vram.mem[1],ym_vram.mem[2],ym_vram.mem[3],ym_vram.mem[256],ym_vram.mem[257],ym_vram.mem[258],ym_vram.mem[259],ym_vram.mem[512],ym_vram.mem[513],
            ym_vram_legacy.mem[0],ym_vram_legacy.mem[1],ym_vram_legacy.mem[2],ym_vram_legacy.mem[3],ym_vram_legacy.mem[256],ym_vram_legacy.mem[257],ym_vram_legacy.mem[258],ym_vram_legacy.mem[259],ym_vram_legacy.mem[512],ym_vram_legacy.mem[513]);
        $display("debug m5=%b reg15=%h inc=%h fifo=%b/%b l109=%b l46=%b l49=%b l50=%b pins=%b%b%b%b addr=%h data=%h ramwr=%b",
            ym_reg_m5, uut_ym.reg_data_l2[15], uut_ym.reg_inc, uut_ym.l54, uut_ym.l53, uut_ym.l109, uut_ym.l46, uut_ym.l49, uut_ym.l50,
            ym_ras, ym_cas, ym_oe, ym_we0, uut_ym.vram_address, uut_ym.vram_data, ym_vram.wr);
        $fatal(1);
    end

    cpu_write(23'h600002, 16'h0000); // VRAM read, address high
    cpu_write(23'h600002, 16'h0000); // VRAM read, address low
    cpu_read(23'h600000, vram_readback1);
    cpu_read(23'h600000, vram_readback2);
    if (vram_readback1 !== 16'h1234 || vram_readback2 !== 16'h5678) begin
        $display("FAIL: CPU VRAM reads got %04x,%04x expected 1234,5678", vram_readback1, vram_readback2);
        $fatal(1);
    end

    cpu_write(23'h600002, 16'h4000); // VSRAM write, address high
    cpu_write(23'h600002, 16'h0010); // VSRAM write, address low
    cpu_write(23'h600000, 16'h02ab);
    timeout = 0;
    while (uut_ym.vsram[0] !== 11'h2ab && timeout < 2048) begin
        tick();
        timeout = timeout + 1;
    end
    if (uut_ym.vsram[0] !== 11'h2ab) begin
        $display("FAIL: VSRAM[0]=%03x expected 2ab after %0d clocks", uut_ym.vsram[0], timeout);
        $fatal(1);
    end

    cpu_write(23'h600002, 16'hc000); // CRAM write, address high
    cpu_write(23'h600002, 16'h0000); // CRAM write, address low
    cpu_write(23'h600000, 16'h0016);
    timeout = 0;
    while (uut_ym.color_ram[0] !== 9'h003 && timeout < 2048) begin
        tick();
        timeout = timeout + 1;
    end
    if (uut_ym.color_ram[0] !== 9'h003) begin
        $display("FAIL: CRAM[0]=%03x expected 003 after %0d clocks", uut_ym.color_ram[0], timeout);
        $fatal(1);
    end

    // Keep the original post-CRAM H40 write order in both models and observe
    // the entire deferred decode through the reg1 latch.
    h40_trace_last = 30'h3fffffff;
    h40_latch_seen = 0;
    h40_trace_en = 1;
    cpu_write(23'h600002, 16'h8c81);
    timeout = 0;
    while ((uut_ym.reg_rs1 !== 1'b1 || uut_ym_legacy.reg_rs1 !== 1'b1) && timeout < 512) begin
        tick();
        timeout = timeout + 1;
    end
    repeat (8) tick();
    h40_trace_en = 0;
    if (!h40_latch_seen || uut_ym.reg_rs1 !== 1'b1 || uut_ym.reg_rs0 !== 1'b1 ||
        uut_ym_legacy.reg_rs1 !== 1'b1 || uut_ym_legacy.reg_rs0 !== 1'b1) begin
        $display("FAIL: H40 write did not traverse w215 with 0c81; seen=%b current=%b%b legacy=%b%b data=%05x addr=%05x code=%b",
            h40_latch_seen,uut_ym.reg_rs1,uut_ym.reg_rs0,uut_ym_legacy.reg_rs1,uut_ym_legacy.reg_rs0,
            uut_ym.reg_data_l2,uut_ym.reg_addr,uut_ym.reg_code);
        $fatal(1);
    end
`ifdef PASSIVE_TEST
    cpu_write(23'h600002, 16'h8f02);
    cpu_write(23'h600002, 16'h4020); // Prepare a VRAM write during the accelerated blank interval
    cpu_write(23'h600002, 16'h0000);
    timeout = 0;
    while (!uut_ym.passive_geometry_supported &&
           timeout < (5*TEST_FRAME_LINES*TEST_LINE_PIXELS*8+TEST_LINE_PIXELS*8)) begin
        tick();
        timeout = timeout + 1;
    end
    if (!uut_ym.passive_geometry_supported) begin
        $display("FAIL: S16 raster did not lock: T=%0d W=%0d N=%0d A=%0d phase=%b",
            uut_ym.passive_line_pixels,uut_ym.passive_active_pixels,uut_ym.passive_frame_lines,
            uut_ym.passive_active_lines,uut_ym.passive_raster_phase_error);
        $fatal(1);
    end
    if (uut_ym.passive_line_pixels !== TEST_LINE_PIXELS ||
        uut_ym.passive_active_pixels !== 10'd320 ||
        uut_ym.passive_frame_lines !== TEST_FRAME_LINES ||
        uut_ym.passive_active_lines !== 9'd224) begin
        $display("FAIL: acquired raster geometry T/W/N/A=%0d/%0d/%0d/%0d expected %0d/320/%0d/224",
            uut_ym.passive_line_pixels,uut_ym.passive_active_pixels,
            uut_ym.passive_frame_lines,uut_ym.passive_active_lines,
            TEST_LINE_PIXELS,TEST_FRAME_LINES);
        $fatal(1);
    end
    timeout = 0;
    while (uut_ym.l106 !== 9'd345 && timeout < 10000) begin
        tick();
        timeout = timeout + 1;
    end
    if (uut_ym.l106 !== 9'd345) begin
        $display("FAIL: did not reach H345 for fast-blank trial, H=%0d", uut_ym.l106);
        $fatal(1);
    end
    if (uut_ym.passive_fast_quota !== TEST_FAST_QUOTA) begin
        $display("FAIL: measured %0d-pixel line selected fast quota %0d, expected %0d",
            TEST_LINE_PIXELS,uut_ym.passive_fast_quota,TEST_FAST_QUOTA);
        $fatal(1);
    end
    rate_last_hclk1 = uut_ym.hclk1;
    rate_started = 0;
    rate_run = 0;
    rate_dwell = {29'd0,uut_ym.passive_dwell};
    rate_check_en = 1;
    timeout = 0;
    while ((uut_ym.l106 !== 9'd350 || uut_ym.passive_quarter !== 2'd1 ||
            uut_ym.passive_tick !== 0 || uut_ym.passive_dwell !== 3'd1) && timeout < 10000) begin
        tick();
        timeout = timeout + 1;
    end
    if (uut_ym.l106 !== 9'd350 || uut_ym.passive_quarter !== 2'd1 || uut_ym.passive_dwell !== 3'd1) begin
        $display("FAIL: did not reach fast H350 data-write point H=%0d q=%0d dwell=%0d", uut_ym.l106,
            uut_ym.passive_quarter, uut_ym.passive_dwell);
        $fatal(1);
    end
    cpu_write(23'h600000, 16'ha55a);
    timeout = 0;
    while ({ym_vram.mem[2048],ym_vram.mem[2049]} !== {8'h5a,8'ha5} &&
           uut_ym.l106 <= 9'd364 && timeout < 512) begin
        tick();
        timeout = timeout + 1;
    end
    if ({ym_vram.mem[2048],ym_vram.mem[2049]} !== {8'h5a,8'ha5} || uut_ym.l106 > 9'd364) begin
        $display("FAIL: fast-window VRAM write not complete before H365; bytes=%02x,%02x H=%0d",
            ym_vram.mem[2048],ym_vram.mem[2049],uut_ym.l106);
        $fatal(1);
    end
    timeout = 0;
    while (({1'b0,uut_ym.l106} !== uut_ym.passive_fast_last || uut_ym.passive_quarter !== 2'd1 || uut_ym.passive_tick !== 0) && timeout < 10000) begin
        tick();
        timeout = timeout + 1;
    end
    if ({1'b0,uut_ym.l106} !== uut_ym.passive_fast_last || uut_ym.passive_quarter !== 2'd1 || uut_ym.passive_tick !== 0) begin
        $display("FAIL: did not reach final fast event H=%0d quota=%0d", uut_ym.l106,uut_ym.passive_fast_quota);
        $fatal(1);
    end
    timeout = 0;
    while (({1'b0,uut_ym.l106} !== (uut_ym.passive_fast_last+10'd1) || uut_ym.passive_dwell !== 3'd2) && timeout < 100) begin
        tick();
        timeout = timeout + 1;
    end
    repeat (8) tick();
    if (rate_fast_transitions !== 1 || rate_normal_transitions !== 1 || fast_event_count !== {25'd0,TEST_FAST_QUOTA}) begin
        $display("FAIL: safe rate transitions fast=%0d normal=%0d fastEvents=%0d",
            rate_fast_transitions, rate_normal_transitions, fast_event_count);
        $fatal(1);
    end
    rate_check_en = 0;

`endif

    cpu_write(23'h600002, 16'h4020); // VRAM write command, byte address20
    cpu_write(23'h600002, 16'h0000);
    cpu_write(23'h600000, 16'h0000);
    cpu_write(23'h600001, 16'h1111); // odd byte address aliases data port
    cpu_write(23'h600002, 16'h0020); // VRAM read command, byte address20
    cpu_write(23'h600002, 16'h0000);
    cpu_read(23'h600001, vram_readback1);
    cpu_read(23'h600000, vram_readback2);
    if (vram_readback1 !== 16'h0000 || vram_readback2 !== 16'h1111 ||
        {ym_vram.mem[2050],ym_vram.mem[2051]} !== {8'h11,8'h11}) begin
        $display("FAIL: odd-alias CPU reads got %04x,%04x expected 0000,1111; bytes=%02x,%02x",
            vram_readback1, vram_readback2, ym_vram.mem[2050], ym_vram.mem[2051]);
        $fatal(1);
    end

`ifdef RENDER_FIXTURE
    begin : render_fixture
`ifdef FEATURES_SCENARIO
        run_features_profile();
`else
        integer fixture_i;
        reg [15:0] fixture_cpu_addr, fixture_phys_addr;
    // Give the renderer isolated, known internal RAM contents after the
    // independent CPU-port tests have already exercised these paths.
    for (fixture_i=0; fixture_i<65536; fixture_i=fixture_i+1) begin
        ym_vram.mem[fixture_i] = 0;
        ym_vram_legacy.mem[fixture_i] = 0;
    end
    for (fixture_i=0; fixture_i<40; fixture_i=fixture_i+1) uut_ym.vsram[fixture_i] = 0;
    for (fixture_i=0; fixture_i<40; fixture_i=fixture_i+1) uut_ym_legacy.vsram[fixture_i] = 0;
    for (fixture_i=0; fixture_i<64; fixture_i=fixture_i+1) uut_ym.color_ram[fixture_i] = 0;
    for (fixture_i=0; fixture_i<64; fixture_i=fixture_i+1) uut_ym_legacy.color_ram[fixture_i] = 0;
    for (fixture_i=0; fixture_i<32; fixture_i=fixture_i+1) begin
        fixture_cpu_addr = 16'h0040 + fixture_i[15:0];
        fixture_phys_addr = physical_addr(fixture_cpu_addr);
        case( {fixture_i[4:2],fixture_i[1:0]} )
            5'b00000: begin ym_vram.mem[fixture_phys_addr] = 8'h12; ym_vram_legacy.mem[fixture_phys_addr] = 8'h12; end
            5'b00001: begin ym_vram.mem[fixture_phys_addr] = 8'h34; ym_vram_legacy.mem[fixture_phys_addr] = 8'h34; end
            5'b00010: begin ym_vram.mem[fixture_phys_addr] = 8'h56; ym_vram_legacy.mem[fixture_phys_addr] = 8'h56; end
            5'b00011: begin ym_vram.mem[fixture_phys_addr] = 8'h78; ym_vram_legacy.mem[fixture_phys_addr] = 8'h78; end
            5'b00100: begin ym_vram.mem[fixture_phys_addr] = 8'h87; ym_vram_legacy.mem[fixture_phys_addr] = 8'h87; end
            5'b00101: begin ym_vram.mem[fixture_phys_addr] = 8'h65; ym_vram_legacy.mem[fixture_phys_addr] = 8'h65; end
            5'b00110: begin ym_vram.mem[fixture_phys_addr] = 8'h43; ym_vram_legacy.mem[fixture_phys_addr] = 8'h43; end
            default: begin ym_vram.mem[fixture_phys_addr] = 8'h21; ym_vram_legacy.mem[fixture_phys_addr] = 8'h21; end
        endcase
    end
    for (fixture_i=0; fixture_i<40; fixture_i=fixture_i+1) begin
        fixture_cpu_addr = 16'he000 + (fixture_i[15:0]<<1);
        fixture_phys_addr = physical_addr(fixture_cpu_addr);
        ym_vram.mem[fixture_phys_addr] = 8'h02;
        ym_vram_legacy.mem[fixture_phys_addr] = 8'h02;
        fixture_cpu_addr = fixture_cpu_addr+16'd1;
        fixture_phys_addr = physical_addr(fixture_cpu_addr);
        ym_vram.mem[fixture_phys_addr] = 8'h40;
        ym_vram_legacy.mem[fixture_phys_addr] = 8'h40;
    end
    if ({ym_vram.mem[224],ym_vram.mem[225],ym_vram.mem[4096],ym_vram.mem[4097]} !==
        {8'h02,8'h40,8'h12,8'h34} ||
        {ym_vram_legacy.mem[224],ym_vram_legacy.mem[225],ym_vram_legacy.mem[4096],ym_vram_legacy.mem[4097]} !==
        {8'h02,8'h40,8'h12,8'h34}) begin
        $display("FAIL: render-fixture DRAM bytes do not match known pattern/table contents");
        $fatal(1);
    end
    cpu_write(23'h600002, 16'hc042); // CRAM address42, command code3
    cpu_write(23'h600002, 16'h0000);
    cpu_write(23'h600000, 16'h000e);
    cpu_write(23'h600002, 16'h8238); // Plane A name table base E000
    cpu_write(23'h600002, 16'h833c); // Window base in a zeroed page
    cpu_write(23'h600002, 16'h8406); // Plane B base in a zeroed page
    cpu_write(23'h600002, 16'h857e); // Sprite table base in zeroed page
    cpu_write(23'h600002, 16'h8700); // Backdrop color zero
    cpu_write(23'h600002, 16'h8b00); // No external scroll mode
    cpu_write(23'h600002, 16'h8d3f); // Horizontal-scroll table base in zeroed page
    cpu_write(23'h600002, 16'h9000); // 32x32 plane sizes
    cpu_write(23'h600002, 16'h9100); // Window horizontal position
    cpu_write(23'h600002, 16'h9200); // Window vertical position
    cpu_write(23'h600002, 16'h8144); // Mode5 + display enable
    timeout = 0;
    while ((uut_ym.reg_disp !== 1'b1 || uut_ym_legacy.reg_disp !== 1'b1 ||
            uut_ym.reg_rs1 !== 1'b1 || uut_ym_legacy.reg_rs1 !== 1'b1 ||
            uut_ym.reg_m5 !== 1'b1 || uut_ym_legacy.reg_m5 !== 1'b1) && timeout < 4096) begin
        tick();
        timeout = timeout + 1;
    end
    if (uut_ym.reg_disp !== 1'b1 || uut_ym_legacy.reg_disp !== 1'b1 ||
        uut_ym.reg_rs1 !== 1'b1 || uut_ym_legacy.reg_rs1 !== 1'b1 ||
        uut_ym.reg_m5 !== 1'b1 || uut_ym_legacy.reg_m5 !== 1'b1) begin
        $display("FAIL: render MMR state current disp/rs1/m5=%b%b%b baseline=%b%b%b data=%05x addr=%05x code=%b",
            uut_ym.reg_disp,uut_ym.reg_rs1,uut_ym.reg_m5,uut_ym_legacy.reg_disp,uut_ym_legacy.reg_rs1,uut_ym_legacy.reg_m5,
            uut_ym.reg_data_l2,uut_ym.reg_addr,uut_ym.reg_code);
        $fatal(1);
    end
    if (uut_ym.reg_sa !== 4'h7 || uut_ym.reg_sb !== 4'h6 || uut_ym.reg_wd !== 6'h1e ||
        uut_ym.reg_hs !== 7'h3f || uut_ym.reg_rs0 !== 1'b1) begin
        $display("FAIL: render MMR config sa=%h sb=%h wd=%h hs=%h rs0=%b expected 7/6/1e/3f/1 data=%05x addr=%05x code=%b",
            uut_ym.reg_sa,uut_ym.reg_sb,uut_ym.reg_wd,uut_ym.reg_hs,uut_ym.reg_rs0,
            uut_ym.reg_data_l2,uut_ym.reg_addr,uut_ym.reg_code);
        $fatal(1);
    end
    timeout = 0;
    while (uut_ym.color_ram[6'h21] !== 9'h007 && timeout < 4096) begin
        tick();
        timeout = timeout + 1;
    end
    if (uut_ym.color_ram[6'h21] !== 9'h007 || uut_ym_legacy.color_ram[6'h21] !== 9'h007) begin
        $display("FAIL: rendered tile palette entry CRAM[21]=%03x", uut_ym.color_ram[6'h21]);
        $fatal(1);
    end
    uut_ym.color_ram[6'h22] = 9'h038;
    uut_ym.color_ram[6'h23] = 9'h1c0;
    uut_ym.color_ram[6'h24] = 9'h1c7;
    uut_ym.color_ram[6'h25] = 9'h0e0;
    uut_ym.color_ram[6'h26] = 9'h00e;
    uut_ym.color_ram[6'h27] = 9'h070;
    uut_ym.color_ram[6'h28] = 9'h1c8;
    uut_ym_legacy.color_ram[6'h22] = 9'h038;
    uut_ym_legacy.color_ram[6'h23] = 9'h1c0;
    uut_ym_legacy.color_ram[6'h24] = 9'h1c7;
    uut_ym_legacy.color_ram[6'h25] = 9'h0e0;
    uut_ym_legacy.color_ram[6'h26] = 9'h00e;
    uut_ym_legacy.color_ram[6'h27] = 9'h070;
    uut_ym_legacy.color_ram[6'h28] = 9'h1c8;
`ifdef PASSIVE_TEST
    render_current_row0_last = -1;
    render_legacy_row0_last = -1;
    render_current_row0_armed = 0;
    render_legacy_row0_armed = 0;
    render_current_row0_count = 0;
    render_legacy_row0_count = 0;
    render_external_row0_count = 0;
    render_external_row1_count = 0;
    render_locked_line_count = 0;
    render_locked_last_y = -1;
    render_external_row0_last = -1;
    render_external_row1_last = -1;
    render_line_capture_en = 1;
`endif
    begin : render_sample_check
        integer pixel_i, distinct_count;
        reg current_armed, legacy_armed, current_origin, legacy_origin;
        reg [24:0] previous_pixel;
        current_armed = 0;
        legacy_armed = 0;
        current_origin = 0;
        legacy_origin = 0;
        render_trace_count = 0;
        stage_trace_count = 0;
        trace_prev_ras = ym_ras;
        trace_prev_cas = ym_cas;
        trace_prev_oe = ym_oe;
        trace_prev_sc = ym_sc;
`ifdef PASSIVE_TEST
        timeout = 0;
        // Geometry was already acquired; readiness waits at most two full frames plus two lines for the next prime opportunity.
        while (!uut_ym.passive_render_ready && timeout < (2*TEST_FRAME_LINES*TEST_LINE_PIXELS*8+2*TEST_LINE_PIXELS*8)) begin
            tick();
            timeout = timeout + 1;
        end
        if (!uut_ym.passive_render_ready) begin
            $display("FAIL: passive raster never reached prefetched render state after %0d clocks T/W/N/A=%0d/%0d/%0d/%0d H/V=%0d/%0d frame_y=%0d",timeout,
                uut_ym.passive_line_pixels,uut_ym.passive_active_pixels,uut_ym.passive_frame_lines,
                uut_ym.passive_active_lines,uut_ym.l106,uut_ym.l105,uut_ym.passive_frame_y);
            $fatal(1);
        end
        current_origin = 1;
        timeout = 0;
        while (!legacy_origin && timeout < 1500000) begin
            tick();
            if (uut_ym_legacy.l105 != 0 || uut_ym_legacy.l106 != 0) legacy_armed = 1;
            if (legacy_armed && uut_ym_legacy.l105 == 0 && uut_ym_legacy.l106 == 0) legacy_origin = 1;
            timeout = timeout + 1;
        end
        if (!legacy_origin) begin
            $display("FAIL: legacy reference did not reach its frame origin after %0d clocks H=%0d V=%0d",
                timeout,uut_ym_legacy.l106,uut_ym_legacy.l105);
            $fatal(1);
        end
`else
        timeout = 0;
        while ((!current_origin || !legacy_origin) && timeout < 1500000) begin
            tick();
            timeout = timeout + 1;
            if (uut_ym.l105 != 0 || uut_ym.l106 != 0) current_armed = 1;
            if (uut_ym_legacy.l105 != 0 || uut_ym_legacy.l106 != 0) legacy_armed = 1;
            if (current_armed && uut_ym.l105 == 0 && uut_ym.l106 == 0) current_origin = 1;
            if (legacy_armed && uut_ym_legacy.l105 == 0 && uut_ym_legacy.l106 == 0) legacy_origin = 1;
        end
        if (!current_origin || !legacy_origin) begin
            $display("FAIL: no full-frame origin after %0d clocks current=%b H=%0d V=%0d legacy=%b H=%0d V=%0d",
                timeout,current_origin,uut_ym.l106,uut_ym.l105,legacy_origin,uut_ym_legacy.l106,uut_ym_legacy.l105);
            $fatal(1);
        end
`endif
        $display("render origins current H/V=%0d/%0d legacy H/V=%0d/%0d; capture next active line at V1 H26..345",
            uut_ym.l106,uut_ym.l105,uut_ym_legacy.l106,uut_ym_legacy.l105);
        $display("render registers current R1=%02x R12=%02x legacy R1=%02x R12=%02x",
            {uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_m3,uut_ym.reg_81_b0},
            {uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1},
            {uut_ym_legacy.reg_81_b7,uut_ym_legacy.reg_disp,uut_ym_legacy.reg_ie0,uut_ym_legacy.reg_m1,uut_ym_legacy.reg_m2,uut_ym_legacy.reg_m5,uut_ym_legacy.reg_m3,uut_ym_legacy.reg_81_b0},
            {uut_ym_legacy.reg_rs0,uut_ym_legacy.reg_8c_b6,uut_ym_legacy.reg_8c_b5,uut_ym_legacy.reg_8c_b4,uut_ym_legacy.reg_ste,uut_ym_legacy.reg_lsm1,uut_ym_legacy.reg_lsm0,uut_ym_legacy.reg_rs1});
        render_line_current_ready = 0;
        render_line_legacy_ready = 0;
        render_line_current_started = 0;
        render_line_legacy_started = 0;
        render_line_current_done = 0;
        render_line_legacy_done = 0;
        render_line_current_last_h = -1;
        render_line_legacy_last_h = -1;
        render_line_current_events = 0;
        render_line_legacy_events = 0;
        render_line_current_total = 0;
        render_line_legacy_total = 0;
        render_line_current_de = 0;
        render_line_legacy_de = 0;
        render_line_current_rgb = 0;
        render_line_legacy_rgb = 0;
        render_line_current_ys = 0;
        render_line_legacy_ys = 0;
        render_line_current_x = 0;
        render_line_legacy_x = 0;
        render_line_current_first_de = -1;
        render_line_legacy_first_de = -1;
        render_line_current_last_de = -1;
        render_line_legacy_last_de = -1;
        render_trace_en = 1;
        render_line_capture_en = 1;
        timeout = 0;
        while ((!render_line_current_done || !render_line_legacy_done
`ifdef PASSIVE_TEST
            || render_external_row0_count!=320 || render_external_row1_count!=320 || !render_external_complete
`endif
            ) && timeout < 1500000) begin
            tick();
            timeout = timeout + 1;
            if (current_origin && !render_line_current_ready && uut_ym.l105 == 1 && uut_ym.l106 == 0)
                render_line_current_ready = 1;
            if (legacy_origin && !render_line_legacy_ready && uut_ym_legacy.l105 == 1 && uut_ym_legacy.l106 == 0)
                render_line_legacy_ready = 1;
        end
        render_line_capture_en = 0;
        render_trace_en = 0;
        $display("render line current total=%0d H26-345=%0d DE=%0d %0d..%0d RGB=%0d YS=%0d X=%0d done=%b; legacy total=%0d H26-345=%0d DE=%0d %0d..%0d RGB=%0d YS=%0d X=%0d done=%b",
            render_line_current_total,render_line_current_events,render_line_current_de,
            render_line_current_first_de,render_line_current_last_de,render_line_current_rgb,
            render_line_current_ys,render_line_current_x,render_line_current_done,
            render_line_legacy_total,render_line_legacy_events,render_line_legacy_de,
            render_line_legacy_first_de,render_line_legacy_last_de,render_line_legacy_rgb,
            render_line_legacy_ys,render_line_legacy_x,render_line_legacy_done);
`ifdef PASSIVE_TEST
        if (render_external_row0_count!=320 || render_external_row1_count!=320 ||
            !render_external_complete || render_locked_line_count!=4 || !render_prime_count_done) begin
            $display("FAIL: external render acceptance incomplete rows=%0d/%0d complete=%b locked-lines=%0d prime=%b",
                render_external_row0_count,render_external_row1_count,render_external_complete,
                render_locked_line_count,render_prime_count_done);
            $fatal(1);
        end
        for (pixel_i=0; pixel_i<320; pixel_i=pixel_i+1) begin
            if (render_external_row0[pixel_i] !== render_current_row0[pixel_i] ||
                render_external_row1[pixel_i] !== render_current_pixels[pixel_i]) begin
                $display("FAIL: S16 master sample phase differs from candidate H-event output x=%0d row0=%07x/%07x row1=%07x/%07x",
                    pixel_i,render_external_row0[pixel_i],render_current_row0[pixel_i],
                    render_external_row1[pixel_i],render_current_pixels[pixel_i]);
                $fatal(1);
            end
        end
        $display("S16 master pixel samples: row0 x0/x319=%07x/%07x row1 x0/x319=%07x/%07x",
            render_external_row0[0],render_external_row0[319],
            render_external_row1[0],render_external_row1[319]);
        if (render_current_row0_count!=320 || render_legacy_row0_count!=320) begin
            $display("FAIL: first visible row0 was not captured completely candidate=%0d reference=%0d",
                render_current_row0_count,render_legacy_row0_count);
            $fatal(1);
        end
        for (pixel_i=0; pixel_i<320; pixel_i=pixel_i+1) begin
            if (render_current_row0[pixel_i] !== render_legacy_row0[pixel_i]) begin
                $display("FAIL: first visible row0 differs at X=%0d candidate=%07x legacy=%07x",
                    pixel_i,render_current_row0[pixel_i],render_legacy_row0[pixel_i]);
                $fatal(1);
            end
        end
        if (render_current_row0[0][23:0]===0 || render_current_row0[319][23:0]===0 ||
            render_current_row0[0][23:0]===render_current_row0[319][23:0] ||
            render_current_row0[0]===render_current_pixels[0]) begin
            $display("FAIL: first visible row0 edge/pattern oracle invalid x0=%07x x319=%07x row1x0=%07x",
                render_current_row0[0],render_current_row0[319],render_current_pixels[0]);
            $fatal(1);
        end
        $display("First visible row0: 320 tuple matches; external edges x0=%07x x319=%07x; row1 x0=%07x",
            render_current_row0[0],render_current_row0[319],render_current_pixels[0]);
`endif
        distinct_count = 0;
        previous_pixel = 25'h1ffffff;
        for (pixel_i=0; pixel_i<320; pixel_i=pixel_i+1) begin
            if (render_current_pixels[pixel_i] !== render_legacy_pixels[pixel_i]) begin
                $display("FAIL: rendered pixel tuple differs at X=%0d current=%07x legacy=%07x",
                    pixel_i,render_current_pixels[pixel_i],render_legacy_pixels[pixel_i]);
                $fatal(1);
            end
            if (render_current_pixels[pixel_i] != previous_pixel)
                distinct_count = distinct_count+1;
            previous_pixel = render_current_pixels[pixel_i];
        end
        if (distinct_count < 4 || render_current_pixels[0][23:0]==0 ||
            render_current_pixels[319][23:0]==0 || render_current_pixels[0][23:0]==render_current_pixels[319][23:0]) begin
            $display("FAIL: patterned edge pixels did not render distinctly: first=%07x last=%07x transitions=%0d",
                render_current_pixels[0],render_current_pixels[319],distinct_count);
            $fatal(1);
        end
        $display("Pattern oracle: %0d packed pixel/YS runs; edges first=%07x last=%07x",
            distinct_count,render_current_pixels[0],render_current_pixels[319]);
        if (!render_line_current_done || !render_line_legacy_done ||
            render_line_current_total != 420 || render_line_legacy_total != 420 ||
            render_line_current_events != 320 || render_line_legacy_events != 320 ||
            render_line_current_x != 0 || render_line_legacy_x != 0 ||
            render_line_current_de != render_line_legacy_de ||
            render_line_current_first_de != render_line_legacy_first_de ||
            render_line_current_last_de != render_line_legacy_last_de ||
            render_line_current_rgb != render_line_legacy_rgb ||
            render_line_current_rgb == 0 || render_line_legacy_rgb == 0 ||
            {uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_m3,uut_ym.reg_81_b0} !== 8'h44 ||
            {uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1} !== 8'h81) begin
            $display("FAIL: H40 full-line/DE/pixel comparison failed; pattern=%h,%h names=%h,%h,%h,%h CRAM=%h",
                ym_vram.mem[4096],ym_vram.mem[4097],ym_vram.mem[224],ym_vram.mem[225],ym_vram.mem[228],ym_vram.mem[229],uut_ym.color_ram[6'h21]);
            $fatal(1);
        end
        $display("Mode5 H40 V1 tile scan current RGB/DE=%0d/%0d legacy RGB/DE=%0d/%0d",
            render_line_current_rgb,render_line_current_de,render_line_legacy_rgb,render_line_legacy_de);
    end
`endif
    end
`ifdef GEOMETRY_SWITCH_SCENARIO
    run_geometry_switch_profile();
    $finish;
`endif
`endif
`ifdef IRQ_HV_SCENARIO
    run_irq_hv_profile();
    $display("IRQ_HV scenario completed");
    $finish;
`endif

`ifdef SERVICE_SCENARIO
    run_service_memory_reads();
`ifdef PASSIVE_TEST
    run_service_hv_latch();
`endif
    run_service_fifo_dma();
`ifdef SERVICE_COPY_READ_BEFORE
    run_service_copy_read_before();
`endif
`endif

`ifdef PASSIVE_TEST
`ifndef FEATURES_SCENARIO
    // Clear Mode 5 while display-enable remains asserted. This separately
    // exercises renderer invalidation by Mode 5 itself, not only R1=04 blanking.
    cpu_write(23'h600002,16'h8140);
    timeout = 0;
    while ((uut_ym.reg_m5!==1'b0 || uut_ym.passive_render_ready!==1'b0) && timeout<512) begin
        tick();
        timeout = timeout+1;
    end
    if (uut_ym.reg_m5!==1'b0 || uut_ym.reg_disp!==1'b1 ||
        uut_ym.passive_render_ready!==1'b0 || ym_ys!==1'b0 ||
        {ym_r,ym_g,ym_b}!==24'h000000) begin
        $display("FAIL: active-display Mode 5 clear did not invalidate/mute: M5=%b disp=%b ready=%b YS=%b RGB=%06x",
            uut_ym.reg_m5,uut_ym.reg_disp,uut_ym.passive_render_ready,ym_ys,{ym_r,ym_g,ym_b});
        $fatal(1);
    end
    cpu_read(23'h600002,status);
    cpu_write(23'h600002,16'h8144);
    timeout = 0;
    while (!uut_ym.passive_render_ready && timeout<(2*TEST_FRAME_LINES*TEST_LINE_PIXELS*8+2*TEST_LINE_PIXELS*8)) begin
        tick();
        timeout = timeout+1;
    end
    if (!uut_ym.passive_render_ready || uut_ym.reg_m5!==1'b1 || uut_ym.reg_disp!==1'b1) begin
        $display("FAIL: active-display Mode 5 re-enable did not re-prime");
        $fatal(1);
    end
    cpu_read(23'h600002,status);
`endif
`endif

`ifdef PASSIVE_TRANSITIONS
    begin : reset_and_mode_transition_check
        integer phase_i, phase_mask, pixels_before, transition_frame, transition_timeout, asserted_phase;
        phase_mask = 0;
        pixels_before = raster_pixel_count;
        transition_coord_check_en = 0;
        for (phase_i=0; phase_i<8; phase_i=phase_i+1) begin
            timeout = 0;
            while ((raster_phase_tb !== phase_i[2:0] ||
                    ((phase_i%3)==0 && !(raster_lhbl && raster_lvbl)) ||
                    ((phase_i%3)==1 && raster_lvbl) ||
                    ((phase_i%3)==2 && (!raster_lvbl || raster_lhbl))) &&
                   timeout<(TEST_FRAME_LINES*TEST_LINE_PIXELS*8+TEST_LINE_PIXELS*8)) begin
                @(negedge clk48);
                timeout = timeout+1;
            end
            if (raster_phase_tb !== phase_i[2:0] ||
                ((phase_i%3)==0 && !(raster_lhbl && raster_lvbl)) ||
                ((phase_i%3)==1 && raster_lvbl) ||
                ((phase_i%3)==2 && (!raster_lvbl || raster_lhbl))) begin
                $display("FAIL: reset phase/region %0d was not observed in a complete source frame",phase_i);
                $fatal(1);
            end
            asserted_phase = raster_phase_tb;
            reset_n = 0;
            @(posedge clk48);
            #1;
            phase_mask = phase_mask | (1<<asserted_phase);
            if (uut_ym.passive_render_ready !== 1'b0 || ym_ys !== 1'b0 ||
                {ym_r,ym_g,ym_b} !== 24'h000000) begin
                $display("FAIL: reset at master phase %0d did not mute VDP ready/YS/RGB: ready=%b YS=%b RGB=%06x",
                    asserted_phase,uut_ym.passive_render_ready,ym_ys,{ym_r,ym_g,ym_b});
                $fatal(1);
            end
            @(negedge clk48);
            reset_n = 1;
            // A complete MCLK samples RESET deasserted before the next pulse.
            @(posedge clk48);
            #1;
            if (reset_n!==1'b1) begin
                $display("FAIL: reset release was not sampled between phase cases");
                $fatal(1);
            end

            // Reacquire and re-prime after every assertion, including the
            // first READY reset and each later phase/blanking location.
            cpu_write(23'h600002,16'h8104);
            timeout = 0;
            while ((uut_ym.reg_m5!==1'b1 || uut_ym.reg_disp!==1'b0) && timeout<512) begin
                tick();
                timeout = timeout+1;
            end
            if (uut_ym.reg_m5!==1'b1 || uut_ym.reg_disp!==1'b0) begin
                $display("FAIL: reset case %0d did not restore Mode5 blank state",phase_i);
                $fatal(1);
            end
            cpu_write(23'h600002,16'h8c81);
            timeout = 0;
            while ((uut_ym.reg_rs1!==1'b1 || uut_ym.reg_rs0!==1'b1) && timeout<512) begin
                tick();
                timeout = timeout+1;
            end
            if (uut_ym.reg_rs1!==1'b1 || uut_ym.reg_rs0!==1'b1) begin
                $display("FAIL: reset case %0d failed to program H40",phase_i);
                $fatal(1);
            end
            cpu_read(23'h600002,status);
            timeout = 0;
            while (!uut_ym.passive_geometry_supported && timeout<(5*TEST_FRAME_LINES*TEST_LINE_PIXELS*8+TEST_LINE_PIXELS*8)) begin
                tick();
                timeout = timeout+1;
            end
            if (!uut_ym.passive_geometry_supported) begin
                $display("FAIL: reset case %0d did not reacquire external geometry",phase_i);
                $fatal(1);
            end
            cpu_read(23'h600002,status);
            cpu_write(23'h600002,16'h8144);
            timeout = 0;
            while (!uut_ym.passive_render_ready && timeout<(2*TEST_FRAME_LINES*TEST_LINE_PIXELS*8+2*TEST_LINE_PIXELS*8)) begin
                tick();
                timeout = timeout+1;
            end
            if (!uut_ym.passive_render_ready) begin
                $display("FAIL: reset case %0d did not re-prime Mode5",phase_i);
                $fatal(1);
            end
            cpu_read(23'h600002,status);
            transition_origin_seen = 0;
            transition_coord_check_en = 1;
            timeout = 0;
            while (!transition_origin_seen && timeout<(TEST_FRAME_LINES*TEST_LINE_PIXELS*8+TEST_LINE_PIXELS*8)) begin
                tick();
                timeout = timeout+1;
            end
            transition_coord_check_en = 0;
            if (!transition_origin_seen) begin
                $display("FAIL: reset case %0d missed independent physical H26/V0 active origin",phase_i);
                $fatal(1);
            end
            $display("PASSIVE_RESET case=%0d phase=%0d active-origin H/V=26/0 CPU status and re-prime passed",
                phase_i,asserted_phase);
        end
        if (phase_mask != 8'hff || raster_pixel_count<=pixels_before) begin
            $display("FAIL: reset phase coverage/master continuity mask=%02x pixels before/after=%0d/%0d",
                phase_mask,pixels_before,raster_pixel_count);
            $fatal(1);
        end
        $display("PASSIVE_RESET phases=%02x; master advanced %0d pixels across separately released/reset cases",
            phase_mask,raster_pixel_count-pixels_before);

        cpu_write(23'h600002,16'h8104);
        timeout = 0;
        while ((uut_ym.reg_disp!==1'b0 || uut_ym.passive_render_ready!==1'b0) && timeout<512) begin
            tick();
            timeout = timeout+1;
        end
        if (uut_ym.reg_disp!==1'b0 || uut_ym.reg_m5!==1'b1 ||
            uut_ym.passive_render_ready!==1'b0 || ym_ys!==1'b0 ||
            {ym_r,ym_g,ym_b}!==24'h000000) begin
            $display("FAIL: display-off did not mute VDP: disp=%b M5=%b ready=%b YS=%b RGB=%06x",
                uut_ym.reg_disp,uut_ym.reg_m5,uut_ym.passive_render_ready,ym_ys,{ym_r,ym_g,ym_b});
            $fatal(1);
        end
        cpu_read(23'h600002,status);

        cpu_write(23'h600002,16'h8100);
        timeout = 0;
        while (uut_ym.reg_m5!==1'b0 && timeout<512) begin
            tick();
            timeout = timeout+1;
        end
        if (uut_ym.reg_m5!==1'b0 || uut_ym.passive_render_ready!==1'b0 ||
            ym_ys!==1'b0 || {ym_r,ym_g,ym_b}!==24'h000000) begin
            $display("FAIL: Mode 4 transition did not leave renderer muted M5=%b ready=%b YS=%b RGB=%06x",
                uut_ym.reg_m5,uut_ym.passive_render_ready,ym_ys,{ym_r,ym_g,ym_b});
            $fatal(1);
        end
        cpu_read(23'h600002,status);

        cpu_write(23'h600002,16'h8144);
        timeout = 0;
        while (!uut_ym.passive_render_ready && timeout<(2*TEST_FRAME_LINES*TEST_LINE_PIXELS*8+2*TEST_LINE_PIXELS*8)) begin
            tick();
            timeout = timeout+1;
        end
        if (!uut_ym.passive_render_ready || uut_ym.reg_m5!==1'b1 || uut_ym.reg_disp!==1'b1) begin
            $display("FAIL: Mode 5 display did not re-enable after blank/Mode4 transitions M5/disp/ready=%b/%b/%b",
                uut_ym.reg_m5,uut_ym.reg_disp,uut_ym.passive_render_ready);
            $fatal(1);
        end
        cpu_read(23'h600002,status);
        transition_origin_seen = 0;
        transition_coord_check_en = 1;
        transition_timeout = 0;
        while (!transition_origin_seen && transition_timeout<(TEST_FRAME_LINES*TEST_LINE_PIXELS*8+TEST_LINE_PIXELS*8)) begin
            tick();
            transition_timeout = transition_timeout+1;
        end
        if (!transition_origin_seen) begin
            $display("FAIL: post-transition frame did not reach independent physical H26/V0 origin");
            $fatal(1);
        end
        transition_frame = source_frame_id;
        transition_timeout = 0;
        while (source_frame_id<transition_frame+2 && transition_timeout<(3*TEST_FRAME_LINES*TEST_LINE_PIXELS*8+TEST_LINE_PIXELS*8)) begin
            tick();
            transition_timeout = transition_timeout+1;
        end
        transition_coord_check_en = 0;
        if (source_frame_id<transition_frame+2 || !uut_ym.passive_geometry_supported ||
            !uut_ym.passive_raster_locked || !uut_ym.passive_render_ready) begin
            $display("FAIL: post-transition frame did not preserve lock/ready sourceFrame=%0d startFrame=%0d",
                source_frame_id,transition_frame);
            $fatal(1);
        end
        $display("PASSIVE_TRANSITIONS reset8phase, CPU status, display blank, Mode4, and Mode5 re-enable passed");
    end
`endif

    ad = 8'h12;
    ras = 0;
    tick();

    ad = 8'h34;
    cas = 0;
    tick();

    rd_i = 8'ha5;
    we = 0;
    tick();
    we = 1;

    oe = 0;
    tick();
    if (rd_o !== 8'ha5 || rd_d !== 1'b0) begin
        $display("FAIL: VRAM read got data=%02x valid_n=%b", rd_o, rd_d);
        $fatal(1);
    end

    cas = 1;
    oe = 1;
    tick();
`ifdef SERVICE_SCENARIO
`ifdef SERVICE_COPY_READ_BEFORE
    if (!service_copy_oracle_failed) begin
        $display("FAIL: historical read-before-copy diagnostic unexpectedly matched strict payload oracle");
        $fatal(1);
    end
    $display("SERVICE_COPY_READ_BEFORE EXPECTED_FAILURE: strict historical source/destination oracle mismatch reproduced");
    $fatal(1);
`else
    if (service_copy_oracle_failed) begin
        $display("FAIL: service scenario completed all bounded checks but internal VRAM copy differs from the independent byte-copy oracle");
        $fatal(1);
    end
`endif
`endif
    $display("PASS");
    $finish;
end
`endif
`endif

`ifdef LEGACY_FORMATS_TEST
`include "legacy_formats.vh"
`endif

endmodule
