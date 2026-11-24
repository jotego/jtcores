// Private source-clock HV/IRQ coverage profile. Expected coordinates come
// solely from the independent jtframe_vtimer/master signals.
integer irq_clk48_count = 0;
integer irq_clk96_edge_count = 0;
integer irq_source_line_age = 0;
integer irq_source_line_y = -1;
integer irq_source_line_q = -1;
reg irq_source_line_active = 0;
reg irq_source_line_valid = 0;
reg irq_prev_lhbl = 0, irq_prev_lvbl = 0, irq_prev_vs = 0;
reg irq_active_line_seen = 0;
integer irq_source_frame_id = 0;
integer irq_active_y0_origin_frame = -1;
integer irq_active_y0_origin_residue = -1;
integer irq_blank_line_index = 0;
reg irq_blank_sequence = 0;
wire irq_lhbl_rise = raster_lhbl && !irq_prev_lhbl;
wire irq_vs_rise = raster_vs && !irq_prev_vs;
reg [15:0] irq_hv_model_d1 = 0, irq_hv_model_d2 = 0;
reg irq_hv_trace_en = 0;
integer irq_s0_clk48 = -1, irq_s6_clk48 = -1;
integer irq_s0_clk96 = -1, irq_s6_clk96 = -1;
integer irq_s0_edge_residue = -1, irq_s6_edge_residue = -1;
integer irq_s0_canonical_residue = -1, irq_s6_canonical_residue = -1;
integer irq_s0_line_age = -1, irq_s6_line_age = -1;
integer irq_s0_source_y = -1, irq_s6_source_y = -1;
integer irq_s0_frame = -1;
integer irq_s6_frame = -1;
reg irq_s0_on_current_edge = 0;
reg [15:0] irq_s6_expected = 0;
integer irq_calibration_count = 0;
integer irq_h_event_count = 0, irq_v_event_count = 0;
reg irq_h_pending_expected = 0, irq_v_pending_expected = 0;
reg irq_hie_expected = 0, irq_vie_expected = 0;
reg irq_event_model_en = 0;
reg irq_pin_check_en = 0, irq_blank_check_en = 0;
reg irq_ack_watch_en = 0, irq_ack_check_h = 0, irq_ack_check_v = 0;
reg irq_ack_allow_h_survivor = 0;
reg irq_ack_watch_done = 0;
reg irq_priority_v_ack_watch = 0, irq_priority_h_clear_watch = 0;
reg irq_h222_retained = 0, irq_both_pending_masked = 0;
reg irq_both_pending_v_priority = 0, irq_v_mask_reveals_h = 0;
reg irq_v_restore_priority = 0, irq_v_ack_h_survivor = 0;
reg irq_survivor_status_preserved = 0, irq_h_survivor_ack_cleared = 0;
integer irq_v_ack_h_survivor_count = 0, irq_h_survivor_ack_clear_count = 0;
integer irq_ack_release_mclk = -1;
integer irq_ack_ym_as_release_mclk = -1;
integer irq_ack_release_h_event_count = 0, irq_ack_release_v_event_count = 0;
reg irq_ack_as_pre_edge = 1'b1;
reg irq_ack_intak_pre_edge = 1'b1;
integer irq_ym_mclk_count = 0;
reg irq_h_irq_first_seen = 0, irq_h_irq_periodic_seen = 0;
reg irq_h_blank_clear_seen = 0, irq_h_postblank_seen = 0;
reg irq_v_pending_seen = 0, irq_v_mask_seen = 0, irq_v_restore_seen = 0;
reg irq_v_ack_clear_seen = 0;
reg irq_hv_before_seen = 0, irq_hv_after_seen = 0;
reg irq_jump_left_seen = 0, irq_jump_right_seen = 0;
reg irq_encoded_wrap_seen = 0, irq_v511_tail_seen = 0, irq_v0_after_tail_seen = 0;
integer irq_v_event_frame = -1;
integer irq_priority_case_frame = -1;
integer irq_expected_v_events = 0;
integer irq_blank_check_samples = 0;
reg irq_legacy_compare_en = 0;
reg irq_legacy_h_seen = 0, irq_legacy_v_seen = 0;
integer irq_legacy_pin_samples = 0;

function integer irq_label_at_index;
    input integer idx;
    begin
        if (idx <= 338) irq_label_at_index = 26 + idx;
        else if (idx <= 393) irq_label_at_index = 457 + idx - 339;
        else irq_label_at_index = idx - 394;
    end
endfunction

always @(posedge irq_watch_mclk) begin : irq_mclk_ack_oracle
    // The current YM receives asn_r in both modes; do not anchor to the
    // separate pristine comparator register in legacy mode.
    irq_ack_as_pre_edge = asn_r;
    irq_ack_intak_pre_edge = service_intak;
    irq_ym_mclk_count <= irq_ym_mclk_count + 1;
    #1;
    if (irq_ack_watch_en && irq_ack_release_mclk>=0) begin
        if (irq_ym_mclk_count==irq_ack_release_mclk+1) begin
            if (irq_ack_as_pre_edge!==1'b0 || irq_ack_intak_pre_edge!==1'b0 ||
                asn_r!==1'b1 ||
                as_n!==1'b1 ||
                irq_ym_mclk_count!==irq_ack_release_mclk+1 ||
                irq_h_event_count!==irq_ack_release_h_event_count ||
                irq_v_event_count!==irq_ack_release_v_event_count ||
                (irq_ack_check_h && ym_ipl2!==1'b1) ||
                (irq_ack_check_v && (ym_ipl1!==1'b1 || ym_ipl2!==1'b1))) begin
                $display("IRQ_HV_FAIL registered YM-AS release edge rawR=%0d A=%0d preAS=%b preINTAK=%b postAS=%b rawAS=%b postINTAK=%b mode=%b",
                    irq_ack_release_mclk,irq_ym_mclk_count,irq_ack_as_pre_edge,
                    irq_ack_intak_pre_edge,
                    asn_r,as_n,service_intak,PASSIVE_MODE);
                $fatal(1);
            end
            irq_ack_ym_as_release_mclk=irq_ym_mclk_count;
            $display("IRQ_HV_ACK rawR=%0d M1/A=%0d AS=%b/%b INTAK=%b pull=%b%b",
                irq_ack_release_mclk,irq_ack_ym_as_release_mclk,
                as_n,asn_r,service_intak,ym_ipl1,ym_ipl2);
        end
        if (irq_ack_ym_as_release_mclk>=0 &&
            irq_ym_mclk_count==irq_ack_ym_as_release_mclk+1) begin
            if (irq_ym_mclk_count!==irq_ack_release_mclk+2 ||
                irq_ack_as_pre_edge!==1'b1 || asn_r!==1'b1 || as_n!==1'b1 ||
                irq_h_event_count!==irq_ack_release_h_event_count ||
                irq_v_event_count!==irq_ack_release_v_event_count) begin
                $display("IRQ_HV_FAIL AS/source guard before pending observation rawR/A/now=%0d/%0d/%0d pre/post/rawAS=%b/%b/%b eventsH/V=%0d/%0d releaseH/V=%0d/%0d",
                    irq_ack_release_mclk,irq_ack_ym_as_release_mclk,irq_ym_mclk_count,
                    irq_ack_as_pre_edge,asn_r,as_n,
                    irq_h_event_count,irq_v_event_count,
                    irq_ack_release_h_event_count,irq_ack_release_v_event_count);
                $fatal(1);
            end
            if ((irq_ack_check_h && ym_ipl2!==1'b1) ||
                (irq_ack_check_v && (ym_ipl1!==1'b1 || ym_ipl2!==1'b1))) begin
                $display("IRQ_HV_FAIL pending request cleared before registered-AS+1 rawR+2 pins=%b%b mode=%b",
                    ym_ipl1,ym_ipl2,PASSIVE_MODE);
                $fatal(1);
            end
            $display("IRQ_HV_ACK rawR=%0d M2/A+1=%0d AS=%b/%b INTAK=%b pull=%b%b",
                irq_ack_release_mclk,irq_ym_mclk_count,
                as_n,asn_r,service_intak,ym_ipl1,ym_ipl2);
        end
        if (irq_ack_ym_as_release_mclk>=0 &&
            irq_ym_mclk_count==irq_ack_ym_as_release_mclk+2) begin
            $display("IRQ_HV_ACK rawR=%0d M3/A+2=%0d AS-pre/post/raw=%b/%b/%b INTAK=%b pull=%b%b",
                irq_ack_release_mclk,irq_ym_mclk_count,
                irq_ack_as_pre_edge,asn_r,as_n,service_intak,ym_ipl1,ym_ipl2);
            if (irq_ym_mclk_count!==irq_ack_release_mclk+3 ||
                irq_ack_as_pre_edge!==1'b1 || asn_r!==1'b1 || as_n!==1'b1 ||
                irq_h_event_count!==irq_ack_release_h_event_count ||
                irq_v_event_count!==irq_ack_release_v_event_count) begin
                $display("IRQ_HV_FAIL AS/source release window changed rawR/A/now=%0d/%0d/%0d pre/post/rawAS=%b/%b/%b INTAK=%b eventsH/V=%0d/%0d releaseH/V=%0d/%0d",
                    irq_ack_release_mclk,irq_ack_ym_as_release_mclk,irq_ym_mclk_count,
                    irq_ack_as_pre_edge,asn_r,as_n,
                    service_intak,irq_h_event_count,irq_v_event_count,
                    irq_ack_release_h_event_count,irq_ack_release_v_event_count);
                $fatal(1);
            end
            if ((irq_ack_check_h && ym_ipl2!==1'b0) ||
                (irq_ack_check_v && (ym_ipl1!==1'b0 ||
                 (irq_ack_allow_h_survivor ? ym_ipl2!==1'b1 : ym_ipl2!==1'b0)))) begin
                $display("IRQ_HV_FAIL acknowledge did not clear by registered-AS+2 rawR+3 MCLKs pins=%b%b mode=%b",
                    ym_ipl1,ym_ipl2,PASSIVE_MODE);
                $fatal(1);
            end
            if (irq_priority_v_ack_watch &&
                (!PASSIVE_MODE || irq_ack_check_h || !irq_ack_check_v ||
                 !irq_ack_allow_h_survivor || !irq_h_pending_expected ||
                 !irq_v_pending_expected || !irq_hie_expected ||
                 !irq_vie_expected || irq_source_frame_id!=irq_priority_case_frame ||
                 irq_v_event_frame!=irq_priority_case_frame ||
                 ym_ipl1!==1'b0 || ym_ipl2!==1'b1)) begin
                $display("IRQ_HV_FAIL designated V-ACK input was not both-pending V priority pending(H/V)=%b%b H/VIE=%b%b pull=%b%b allow=%b",
                    irq_h_pending_expected,irq_v_pending_expected,
                    irq_hie_expected,irq_vie_expected,ym_ipl1,ym_ipl2,
                    irq_ack_allow_h_survivor);
                $fatal(1);
            end
            if (irq_priority_h_clear_watch &&
                (!PASSIVE_MODE || !irq_ack_check_h || irq_ack_check_v ||
                 !irq_h_pending_expected || irq_v_pending_expected ||
                 !irq_hie_expected || !irq_vie_expected || irq_ack_allow_h_survivor ||
                 irq_source_frame_id!=irq_priority_case_frame ||
                 irq_v_event_frame!=irq_priority_case_frame)) begin
                $display("IRQ_HV_FAIL designated survivor H-ACK input not H-only pending(H/V)=%b%b H/VIE=%b%b allow=%b frame/event=%0d/%0d expected=%0d",
                    irq_h_pending_expected,irq_v_pending_expected,
                    irq_hie_expected,irq_vie_expected,irq_ack_allow_h_survivor,
                    irq_source_frame_id,irq_v_event_frame,irq_priority_case_frame);
                $fatal(1);
            end
            if (PASSIVE_MODE) begin
                if (irq_ack_check_h) irq_h_pending_expected=0;
                if (irq_ack_check_v) irq_v_pending_expected=0;
            end
            if (irq_priority_v_ack_watch) begin
                if (!irq_h_pending_expected || irq_v_pending_expected ||
                    ym_ipl1!==1'b0 || ym_ipl2!==1'b1) begin
                    $display("IRQ_HV_FAIL designated V-ACK survivor postcondition pending(H/V)=%b%b H/VIE=%b%b allow=%b",
                        irq_h_pending_expected,irq_v_pending_expected,
                        irq_hie_expected,irq_vie_expected,irq_ack_allow_h_survivor);
                    $fatal(1);
                end
                irq_v_ack_h_survivor=1;
                irq_v_ack_h_survivor_count=irq_v_ack_h_survivor_count+1;
            end
            if (irq_priority_h_clear_watch) begin
                if (irq_h_pending_expected || irq_v_pending_expected ||
                    ym_ipl1!==1'b0 || ym_ipl2!==1'b0) begin
                    $display("IRQ_HV_FAIL H survivor did not clear at exact A+2 pending(H/V)=%b%b pull=%b%b",
                        irq_h_pending_expected,irq_v_pending_expected,ym_ipl1,ym_ipl2);
                    $fatal(1);
                end
                irq_h_survivor_ack_cleared=1;
                irq_h_survivor_ack_clear_count=irq_h_survivor_ack_clear_count+1;
            end
            irq_ack_watch_done=1;
            irq_ack_watch_en=0;
        end
        if (irq_ack_ym_as_release_mclk>=0 &&
            irq_ym_mclk_count>irq_ack_ym_as_release_mclk+2) begin
            $display("IRQ_HV_FAIL missed registered-AS+2 ACK monitor rawR/A=%0d/%0d now=%0d mode=%b",
                irq_ack_release_mclk,irq_ack_ym_as_release_mclk,irq_ym_mclk_count,PASSIVE_MODE);
            $fatal(1);
        end
    end
end

function irq_is_fast;
    input integer h;
    integer last_fast;
    begin
`ifdef PASSIVE_384_260
        last_fast=509;
`elsif PASSIVE_384_261
        last_fast=509;
`else
        last_fast=477;
`endif
        irq_is_fast = ((h>=346 && h<=364) || (h>=457 && h<=last_fast));
    end
endfunction

function integer irq_publish_age;
    input integer target_h;
    integer idx, h, next_h, t, old_dwell, current_dwell;
    begin
        h=26; t=0; old_dwell=2;
        irq_publish_age=-1;
        if (target_h==26) irq_publish_age=0;
        for (idx=0;idx<419;idx=idx+1) begin
            next_h=irq_label_at_index(idx+1);
            current_dwell=irq_is_fast(h) ? 1 : 2;
            t=t+2*old_dwell+2*current_dwell;
            if (next_h==target_h) irq_publish_age=t;
            h=next_h;
            old_dwell=current_dwell;
        end
    end
endfunction

function integer irq_v_event_age;
    begin
        irq_v_event_age=irq_publish_age(1)+1;
    end
endfunction

function integer irq_tick_edges_per_pixel;
    begin
        irq_tick_edges_per_pixel=PASSIVE_MODE ? 8 : 16;
    end
endfunction

function integer irq_source_delta_for_cpu_residue;
    input integer residue;
    begin
        case (residue)
            6,16: irq_source_delta_for_cpu_residue=15;
            25,35,45: irq_source_delta_for_cpu_residue=14;
            default: irq_source_delta_for_cpu_residue=-1;
        endcase
    end
endfunction

function integer irq_canonical_cpu_residue;
    input integer raw_residue;
    integer normalized;
    begin
        normalized=raw_residue-CPU_START_DELAY96;
        if (normalized<0) normalized=normalized+48;
        irq_canonical_cpu_residue=normalized;
    end
endfunction

function integer irq_s6_residue_for_s0;
    input integer residue;
    begin
        case (residue)
            6:  irq_s6_residue_for_s0=35;
            16: irq_s6_residue_for_s0=45;
            25: irq_s6_residue_for_s0=6;
            35: irq_s6_residue_for_s0=16;
            45: irq_s6_residue_for_s0=25;
            default: irq_s6_residue_for_s0=-1;
        endcase
    end
endfunction

function integer irq_cpu_edge_span_for_s0;
    input integer residue;
    begin
        irq_cpu_edge_span_for_s0=(residue==45) ? 28 : 29;
    end
endfunction

function integer irq_expected_active_y0_origin_residue;
    input integer frame_id;
    begin
        if (TEST_LINE_PIXELS==384) irq_expected_active_y0_origin_residue=35;
        else begin
            case (frame_id%3)
                0: irq_expected_active_y0_origin_residue=19;
                1: irq_expected_active_y0_origin_residue=35;
                default: irq_expected_active_y0_origin_residue=3;
            endcase
        end
    end
endfunction

function integer irq_h_at_age;
    input integer age;
    integer idx, h, next_h, t, old_dwell, current_dwell;
    begin
        h=(age==0) ? 25 : 26; t=0; old_dwell=2;
        for (idx=0;idx<419;idx=idx+1) begin
            next_h=irq_label_at_index(idx+1);
            current_dwell=irq_is_fast(h) ? 1 : 2;
            t=t+2*old_dwell+2*current_dwell;
            if (age>t) begin
                h=next_h;
                old_dwell=current_dwell;
            end
        end
        irq_h_at_age=h;
    end
endfunction

function [7:0] irq_encode_v;
    input integer q;
    begin
        if (q<=234) irq_encode_v=q[7:0];
        else irq_encode_v=8'((q+512-integer'(TEST_FRAME_LINES)) & 255);
    end
endfunction

// The geometry_switch profile has its own runtime source/coordinate oracle.
// This static-profile model is intentionally disabled there so its fixed
// TEST_LINE_PIXELS/TEST_FRAME_LINES assumptions cannot mask that oracle.
`ifndef GEOMETRY_SWITCH_SCENARIO
always @(posedge clk48) begin : irq_hv_source_model
    integer next_y, next_q, model_h, model_q, v330, model_age;
    irq_clk48_count <= irq_clk48_count + 1;
    irq_prev_lhbl <= raster_lhbl;
    irq_prev_lvbl <= raster_lvbl;
    irq_prev_vs <= raster_vs;
    if (irq_vs_rise) irq_source_frame_id <= irq_source_frame_id + 1;
    if (irq_prev_lvbl && !raster_lvbl) begin
        irq_blank_sequence <= 1;
        irq_blank_line_index <= 0;
    end
    if (!raster_lvbl) irq_active_line_seen <= 0;
    if (irq_lhbl_rise) begin
        irq_source_line_age <= 0;
        irq_source_line_valid <= 1;
        if (raster_lvbl) begin
            if (!irq_active_line_seen) begin
                if (irq_blank_sequence &&
                    irq_blank_line_index!=integer'(TEST_FRAME_LINES)-224) begin
                    $display("IRQ_HV_FAIL physical blank line count=%0d expected=%0d rawV=%0d N=%0d",
                        irq_blank_line_index,integer'(TEST_FRAME_LINES)-224,raster_vdump,TEST_FRAME_LINES);
                    $fatal(1);
                end
                if (irq_source_line_q==integer'(TEST_FRAME_LINES)-1)
                    irq_v0_after_tail_seen <= 1;
                irq_active_y0_origin_frame <= irq_source_frame_id;
                irq_active_y0_origin_residue <= irq_clk96_edge_count%48;
                next_y=0;
                irq_active_line_seen <= 1;
            end else next_y=irq_source_line_y+1;
            next_q=next_y;
            irq_source_line_y <= next_y;
            irq_source_line_q <= next_q;
            irq_source_line_active <= 1;
            irq_blank_sequence <= 0;
        end else begin
            irq_source_line_y <= -1;
            irq_source_line_active <= 0;
            if (irq_blank_sequence) begin
                next_q=224+irq_blank_line_index;
                if (next_q==235) begin
                    if (irq_encode_v(next_q)!==(integer'(TEST_FRAME_LINES)==262 ? 8'd229 : 8'd231)) begin
                        $display("IRQ_HV_FAIL encoded vertical wrap q=235 produced %0d for N=%0d",
                            irq_encode_v(next_q),TEST_FRAME_LINES); $fatal(1);
                    end
                    irq_encoded_wrap_seen <= 1;
                end
                if (next_q==integer'(TEST_FRAME_LINES)-1) begin
                    if (irq_encode_v(next_q)!==8'hff) begin
                        $display("IRQ_HV_FAIL final preactive row did not encode V511: q=%0d encoded=%0d",
                            next_q,irq_encode_v(next_q)); $fatal(1);
                    end
                    irq_v511_tail_seen <= 1;
                end
                if (next_q>=integer'(TEST_FRAME_LINES)) begin
                    $display("IRQ_HV_FAIL physical blank row exceeded frame q=%0d N=%0d",next_q,TEST_FRAME_LINES);
                    $fatal(1);
                end
                irq_source_line_q <= next_q;
                irq_blank_line_index <= irq_blank_line_index+1;
            end else irq_source_line_q <= -1;
        end
    end else irq_source_line_age <= irq_source_line_age + 1;

    if (irq_lhbl_rise && irq_source_line_valid) begin
        // E(j) observes LHBL one MCLK after the timer NBA. H26 publishes on
        // this edge, so the pre-edge native counter value is still H25.
        if (raster_lvbl) begin
            if (!irq_active_line_seen) model_q=0;
            else model_q=irq_source_line_q+1;
        end else model_q=224+irq_blank_line_index;
        irq_hv_model_d1 <= {irq_encode_v(model_q),8'h0c}; // V(new line), H25[8:1]
    end else if (irq_source_line_valid) begin
        model_age=irq_source_line_age+1;
        model_h=irq_h_at_age(model_age);
        v330=irq_publish_age(330);
        model_q=irq_source_line_q + ((model_age>v330) ? 1 : 0);
        if (model_q>=integer'(TEST_FRAME_LINES)) model_q=0;
        irq_hv_model_d1 <= {irq_encode_v(model_q),model_h[8:1]};
    end else begin
        irq_hv_model_d1 <= 16'h0000;
    end
    irq_hv_model_d2 <= irq_hv_model_d1;
end
`endif

// Independent positive-edge index for the 96 MHz master. The counter is
// sampled after NBA at legal CPU edges, alongside irq_clk48_count.
always @(posedge clk) irq_clk96_edge_count <= irq_clk96_edge_count + 1;

always @(posedge clk48) begin : irq_event_and_ack_oracle
    integer age_now;
    #1;
    age_now=irq_source_line_age;
    if (irq_event_model_en && irq_source_line_active) begin
        if (age_now==2433 && irq_source_line_y>=6 && irq_source_line_y<=222 &&
            ((irq_source_line_y-6)%8)==0) begin
            irq_h_event_count=irq_h_event_count+1;
            irq_h_pending_expected=1;
        end
        if (age_now==irq_v_event_age() && irq_source_line_y==223) begin
            if (irq_v_event_frame==irq_source_frame_id) begin
                $display("IRQ_HV_FAIL duplicate V event source frame=%0d",irq_source_frame_id); $fatal(1);
            end
            irq_v_event_frame=irq_source_frame_id;
            irq_v_event_count=irq_v_event_count+1;
            irq_v_pending_expected=1;
        end
    end
    if (irq_pin_check_en) begin
        if (ym_ipl1 !== (irq_v_pending_expected && irq_vie_expected) ||
            ym_ipl2 !== ((irq_v_pending_expected && irq_vie_expected) ||
                         (irq_h_pending_expected && irq_hie_expected))) begin
            $display("IRQ_HV_FAIL pin oracle pending(H/V)=%b%b enable(H/V)=%b%b pins=%b%b frame/y/age=%0d/%0d/%0d",
                irq_h_pending_expected,irq_v_pending_expected,irq_hie_expected,irq_vie_expected,
                ym_ipl1,ym_ipl2,irq_source_frame_id,irq_source_line_y,irq_source_line_age);
            $fatal(1);
        end
    end
    if (irq_blank_check_en && !irq_h_pending_expected && !irq_v_pending_expected &&
        (ym_ipl1!==1'b0 || ym_ipl2!==1'b0)) begin
        $display("IRQ_HV_FAIL unexpected request during H blank reload pins=%b%b source frame/y/age=%0d/%0d/%0d rawLVBL=%b",
            ym_ipl1,ym_ipl2,irq_source_frame_id,irq_source_line_y,irq_source_line_age,raster_lvbl);
        $fatal(1);
    end
    if (irq_blank_check_en && irq_hie_expected && irq_blank_sequence &&
        irq_source_line_q>=224 && !irq_h_pending_expected && !irq_v_pending_expected)
        irq_blank_check_samples=irq_blank_check_samples+1;
end

always @(posedge clk) begin : irq_legacy_pin_equivalence
    #1;
    if (irq_legacy_compare_en) begin
        irq_legacy_pin_samples=irq_legacy_pin_samples+1;
        if (ym_ipl1!==ym_ipl1_legacy || ym_ipl2!==ym_ipl2_legacy) begin
            $display("IRQ_HV_LEGACY_FAIL pin mismatch current=%b%b pristine=%b%b rawH/V=%03x/%03x native=%0d/%0d vs %0d/%0d",
                ym_ipl1,ym_ipl2,ym_ipl1_legacy,ym_ipl2_legacy,raster_hdump,raster_vdump,
                uut_ym.l106,uut_ym.l105,uut_ym_legacy.l106,uut_ym_legacy.l105); $fatal(1);
        end
        if (ym_ipl2 && !ym_ipl1) irq_legacy_h_seen=1;
        if (ym_ipl1 && ym_ipl2) irq_legacy_v_seen=1;
    end
end

task irq_check_pins;
    input string label;
    reg exp1, exp2;
begin
    exp1=irq_v_pending_expected && irq_vie_expected;
    exp2=exp1 || (irq_h_pending_expected && irq_hie_expected);
    if (ym_ipl1!==exp1 || ym_ipl2!==exp2) begin
        $display("IRQ_HV_FAIL %0s expected pins=%b%b pending=%b%b enable=%b%b actual=%b%b source frame/y/age=%0d/%0d/%0d",
            label,exp1,exp2,irq_h_pending_expected,irq_v_pending_expected,irq_hie_expected,irq_vie_expected,
            ym_ipl1,ym_ipl2,irq_source_frame_id,irq_source_line_y,irq_source_line_age);
        $fatal(1);
    end
end
endtask

task irq_reg_write;
    input [7:0] index;
    input [7:0] value;
begin
    if (service_intak!==1'b1) begin
        $display("IRQ_HV_FAIL configuration write %02x=%02x requires INTAK=1",index,value); $fatal(1);
    end
    irq_pin_check_en=0;
    cpu_write(23'h600002,{8'h80|index,value});
    repeat (32) tick();
    case(index)
        8'h00: irq_hie_expected=value[4];
        8'h01: irq_vie_expected=value[5];
        default: begin end
    endcase
    if (PASSIVE_MODE) begin
        irq_check_pins("after fixed MMR settle");
        irq_pin_check_en=1;
    end else irq_pin_check_en=0;
end
endtask

task irq_wait_next_vs;
    integer timeout, bound, start_frame;
begin
    timeout=0;
    start_frame=irq_source_frame_id;
    bound=(integer'(TEST_FRAME_LINES)+2)*integer'(TEST_LINE_PIXELS)*irq_tick_edges_per_pixel();
    while (irq_source_frame_id==start_frame && timeout<bound) begin tick(); timeout=timeout+1; end
    if (irq_source_frame_id==start_frame) begin
        $display("IRQ_HV_FAIL independent frame observer did not advance within frame+2 lines start=%0d current=%0d",
            start_frame,irq_source_frame_id); $fatal(1);
    end
    #2;
end
endtask

task irq_wait_next_vs_phase;
    input integer wanted_phase;
    input integer max_advances;
    integer advances, entry_frame;
begin
    entry_frame=irq_source_frame_id;
    advances=0;
    while ((advances==0 || irq_source_frame_id%3!=wanted_phase) && advances<max_advances) begin
        irq_wait_next_vs();
        advances=advances+1;
    end
    if (advances==0 || irq_source_frame_id%3!=wanted_phase) begin
        $display("IRQ_HV_FAIL no future external VS with phase=%0d in %0d advances entry/current=%0d/%0d",
            wanted_phase,max_advances,entry_frame,irq_source_frame_id); $fatal(1);
    end
    $display("IRQ_HV_SOURCE_PHASE selected frame=%0d phase=%0d advances=%0d K96=%0d",
        irq_source_frame_id,wanted_phase,advances,CPU_START_DELAY96);
end
endtask

task irq_check_active_y0_origin;
    input integer frame_id;
    integer expected_residue;
begin
    expected_residue=irq_expected_active_y0_origin_residue(frame_id);
    if (irq_active_y0_origin_frame!=frame_id || irq_active_y0_origin_residue!=expected_residue) begin
        $display("IRQ_HV_FAIL external active-y0 origin frame=%0d residue=%0d expected frame/residue=%0d/%0d",
            irq_active_y0_origin_frame,irq_active_y0_origin_residue,frame_id,expected_residue); $fatal(1);
    end
    $display("IRQ_HV_SOURCE_ORIGIN frame=%0d activeY0 residue96=%0d K96=%0d",
        frame_id,irq_active_y0_origin_residue,CPU_START_DELAY96);
end
endtask

task irq_wait_event;
    input integer line_y;
    input integer age;
    input integer frame_id;
    integer timeout, bound;
begin
    timeout=0;
    bound=(integer'(TEST_FRAME_LINES)+2)*integer'(TEST_LINE_PIXELS)*irq_tick_edges_per_pixel();
    if (irq_source_frame_id>frame_id ||
        (irq_source_frame_id==frame_id && irq_source_line_active &&
         (irq_source_line_y>line_y || (irq_source_line_y==line_y && irq_source_line_age>age)))) begin
        $display("IRQ_HV_FAIL requested event already passed target frame/y/age=%0d/%0d/%0d current=%0d/%0d/%0d",
            frame_id,line_y,age,irq_source_frame_id,irq_source_line_y,irq_source_line_age); $fatal(1);
    end
    while (!(irq_source_line_active && irq_source_line_y==line_y &&
             irq_source_line_age==age && irq_source_frame_id==frame_id) && timeout<bound) begin
        tick(); timeout=timeout+1;
        if (irq_source_frame_id>frame_id ||
            (irq_source_frame_id==frame_id && irq_source_line_active &&
             (irq_source_line_y>line_y || (irq_source_line_y==line_y && irq_source_line_age>age)))) begin
            $display("IRQ_HV_FAIL target event passed during wait frame/y/age=%0d/%0d/%0d current=%0d/%0d/%0d",
                frame_id,line_y,age,irq_source_frame_id,irq_source_line_y,irq_source_line_age); $fatal(1);
        end
    end
    if (!(irq_source_line_active && irq_source_line_y==line_y &&
          irq_source_line_age==age && irq_source_frame_id==frame_id)) begin
        $display("IRQ_HV_FAIL external event missing frame/y/age=%0d/%0d/%0d current=%0d/%0d/%0d",
            frame_id,line_y,age,irq_source_frame_id,irq_source_line_y,irq_source_line_age); $fatal(1);
    end
    #2;
end
endtask

task irq_status_no_ack;
    output reg [15:0] status;
begin
    if (service_intak!==1'b1) begin
        $display("IRQ_HV_FAIL pending-preservation status read requires INTAK=1"); $fatal(1);
    end
    cpu_read(23'h600002,status);
end
endtask

task irq_ack_status;
    input reg ack_h;
    input reg ack_v;
    output reg [15:0] status;
    integer timeout;
begin
    if (service_intak!==1'b1 || (!ack_h && !ack_v)) begin
        $display("IRQ_HV_FAIL malformed ordinary AS acknowledge setup INTAK=%b H/V=%b%b",service_intak,ack_h,ack_v);
        $fatal(1);
    end
    irq_ack_release_mclk=-1;
    irq_ack_ym_as_release_mclk=-1;
    irq_ack_watch_done=0;
    irq_ack_check_h=ack_h;
    irq_ack_check_v=ack_v;
    irq_ack_watch_en=1;
    irq_pin_check_en=0;
    service_intak=0;
    cpu_read(23'h600002,status);
    service_intak=1;
    timeout=0;
    while (!irq_ack_watch_done && timeout<16) begin tick(); timeout=timeout+1; end
    if (!irq_ack_watch_done) begin
        $display("IRQ_HV_FAIL registered-AS+2 acknowledgement monitor did not complete rawR/A=%0d/%0d now=%0d mode=%b",
            irq_ack_release_mclk,irq_ack_ym_as_release_mclk,irq_ym_mclk_count,PASSIVE_MODE); $fatal(1);
    end
    irq_ack_check_h=0;
    irq_ack_check_v=0;
    irq_ack_allow_h_survivor=0;
    if (PASSIVE_MODE) irq_check_pins("after ordinary AS acknowledge");
    irq_pin_check_en=PASSIVE_MODE && irq_event_model_en;
end
endtask

task irq_masked_h_line;
    input integer line_y;
    input integer frame_id;
begin
    irq_wait_event(line_y,2433,frame_id);
    if (!irq_h_pending_expected || irq_hie_expected || ym_ipl1!==1'b0 || ym_ipl2!==1'b0) begin
        $display("IRQ_HV_FAIL masked H event y=%0d pending/model=%b enable=%b pins=%b%b",
            line_y,irq_h_pending_expected,irq_hie_expected,ym_ipl1,ym_ipl2); $fatal(1);
    end
end
endtask

task irq_ack_existing_h;
    input integer line_y;
    reg [15:0] status;
begin
    if (!irq_h_pending_expected || !irq_hie_expected || ym_ipl1!==1'b0 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL existing H request line=%0d expected IPL2 only pending=%b enable=%b pins=%b%b",
            line_y,irq_h_pending_expected,irq_hie_expected,ym_ipl1,ym_ipl2); $fatal(1);
    end
    irq_ack_status(1'b1,1'b0,status);
end
endtask

task irq_enabled_h_ack;
    input integer line_y;
    input integer frame_id;
begin
    irq_wait_event(line_y,2433,frame_id);
    irq_ack_existing_h(line_y);
end
endtask

task irq_wait_external_line_age;
    input integer target_y;
    input integer target_age;
    input integer min_frame;
    integer timeout, bound, frames_ahead;
begin
    timeout=0;
    // Estimate the number of complete physical frames before the declared
    // target; include one target frame and the configured line margin.
    frames_ahead=min_frame-irq_source_frame_id;
    if (frames_ahead<0) frames_ahead=0;
    if (frames_ahead==0 && irq_source_line_active &&
        (irq_source_line_y>target_y || (irq_source_line_y==target_y && irq_source_line_age>target_age)))
        frames_ahead=1;
    bound=(frames_ahead+1)*(integer'(TEST_FRAME_LINES)+3)*integer'(TEST_LINE_PIXELS)*irq_tick_edges_per_pixel();
    while (!(irq_source_line_active && irq_source_line_y==target_y &&
             irq_source_line_age==target_age && irq_source_frame_id>=min_frame) && timeout<bound) begin
        tick();
        timeout=timeout+1;
    end
    if (!(irq_source_line_active && irq_source_line_y==target_y &&
          irq_source_line_age==target_age && irq_source_frame_id>=min_frame)) begin
        $display("IRQ_HV_CAL_FAIL target source y/age/frame=%0d/%0d/%0d entry frame/y/age=%0d/%0d/%0d rawH/V=%03x/%03x blank=%b%b",
            target_y,target_age,min_frame,irq_source_frame_id,irq_source_line_y,irq_source_line_age,
            raster_hdump,raster_vdump,raster_lhbl,raster_lvbl);
        $fatal(1);
    end
end
endtask

task irq_calibrated_read;
    input string label;
    input integer source_y;
    input integer target_s6_age;
    input integer launch_frame;
    reg [15:0] got;
begin
    // One predeclared launch rule: call the legal CPU task at target_age-16.
    // This is diagnostic only. It does not search offsets or accept data.
    irq_wait_external_line_age(source_y,target_s6_age-16,launch_frame);
    irq_hv_trace_en=1;
    cpu_read(23'h600004,got);
    irq_hv_trace_en=0;
    $display("IRQ_HV_CAL label=%0s target_y/age=%0d/%0d K96=%0d S0frame=%0d S0clk/age/y=%0d/%0d/%0d residue_raw/canon=%0d/%0d S6clk/age/y=%0d/%0d/%0d residue_raw/canon=%0d/%0d elapsed48=%0d S6expected=%04x current=%04x pristine=%04x ACKcurrent/legacy=%0d/%0d rawH/V=%03x/%03x nativeCurrent=%0d/%0d nativePristine=%0d/%0d",
        label,source_y,target_s6_age,CPU_START_DELAY96,irq_s0_frame,irq_s0_clk48,irq_s0_line_age,irq_s0_source_y,
        irq_s0_edge_residue,irq_s0_canonical_residue,
        irq_s6_clk48,irq_s6_line_age,irq_s6_source_y,irq_s6_edge_residue,irq_s6_canonical_residue,irq_s6_clk48-irq_s0_clk48,
        irq_s6_expected,got,cpu_capture_legacy_data,ack_current_latency,ack_legacy_latency,
        raster_hdump,raster_vdump,uut_ym.l106,uut_ym.l105,uut_ym_legacy.l106,uut_ym_legacy.l105);
    irq_calibration_count=irq_calibration_count+1;
end
endtask

task irq_read_s0_window;
    input string label;
    input integer source_y;
    input integer source_frame;
    input integer s6_min_age;
    input integer s6_max_age;
    input [15:0] expected_word;
    output reg passed;
    reg [15:0] got;
    integer timeout, bound, s0_min_age, s0_max_age;
    integer candidate_delta, candidate_residue, candidate_canonical_residue, found_edge;
begin
    passed=0;
    timeout=0;
    // Derive the S0 envelope from the unchanged S6 window and the only
    // legal three-cycle CPU phase deltas (post-NBA source-clock counts).
    s0_min_age=s6_min_age-15;
    s0_max_age=s6_max_age-14;
    bound=(integer'(TEST_FRAME_LINES)+2)*integer'(TEST_LINE_PIXELS)*irq_tick_edges_per_pixel();
    if (irq_source_frame_id>source_frame ||
        (irq_source_frame_id==source_frame && irq_source_line_active &&
         (irq_source_line_y>source_y || (irq_source_line_y==source_y && irq_source_line_age>s0_max_age)))) begin
        $display("IRQ_HV_FAIL fixed S0 target already passed label=%0s target=%0d/%0d/%0d current=%0d/%0d/%0d",
            label,source_frame,source_y,s0_min_age,irq_source_frame_id,irq_source_line_y,irq_source_line_age);
        $fatal(1);
    end
    while (!(irq_source_line_active && irq_source_line_y==source_y &&
             irq_source_frame_id==source_frame && irq_source_line_age>=s0_min_age) && timeout<bound) begin
        tick(); timeout=timeout+1;
        if (irq_source_frame_id>source_frame ||
            (irq_source_frame_id==source_frame && irq_source_line_active &&
             (irq_source_line_y>source_y ||
              (irq_source_line_y==source_y && irq_source_line_age>s0_max_age)))) begin
            $display("IRQ_HV_FAIL fixed S0 target passed during wait label=%0s target=%0d/%0d/%0d current=%0d/%0d/%0d",
                label,source_frame,source_y,s0_min_age,irq_source_frame_id,irq_source_line_y,irq_source_line_age);
            $fatal(1);
        end
    end
    if (timeout>=bound || irq_source_line_age>s0_max_age) begin
        $display("IRQ_HV_FAIL no predeclared S0 window label=%0s y/frame=%0d/%0d ages=%0d..%0d now frame/y/age=%0d/%0d/%0d",
            label,source_y,source_frame,s0_min_age,s0_max_age,irq_source_frame_id,irq_source_line_y,irq_source_line_age);
        $fatal(1);
    end
    // Select only an actual CPU edge whose independently known PLL residue
    // maps its post-NBA S0 age into the fixed S6 interval. Never inspect DUT
    // counters or returned data to choose a launch edge.
    found_edge=0;
    while (!found_edge && irq_source_line_active && irq_source_line_y==source_y &&
           irq_source_frame_id==source_frame && irq_source_line_age<=s0_max_age) begin
        @(posedge cpu_clk); #1;
        candidate_residue=irq_clk96_edge_count%48;
        candidate_canonical_residue=irq_canonical_cpu_residue(candidate_residue);
        candidate_delta=irq_source_delta_for_cpu_residue(candidate_canonical_residue);
        if (candidate_delta<0) begin
            $display("IRQ_HV_FAIL unrecognized CPU/master phase residue raw/canonical=%0d/%0d K96=%0d label=%0s",
                candidate_residue,candidate_canonical_residue,CPU_START_DELAY96,label);
            $fatal(1);
        end
        if (irq_source_line_active && irq_source_line_y==source_y && irq_source_frame_id==source_frame &&
            irq_source_line_age>=s0_min_age && irq_source_line_age<=s0_max_age &&
            irq_source_line_age+candidate_delta>=s6_min_age &&
            irq_source_line_age+candidate_delta<=s6_max_age) found_edge=1;
    end
    if (!found_edge) begin
        $display("IRQ_HV_FAIL no phase-eligible CPU S0 label=%0s frame/y=%0d/%0d derived S0=%0d..%0d from S6=%0d..%0d current=%0d/%0d/%0d",
            label,source_frame,source_y,s0_min_age,s0_max_age,s6_min_age,s6_max_age,
            irq_source_frame_id,irq_source_line_y,irq_source_line_age);
        $fatal(1);
    end
    irq_s0_on_current_edge=1;
    irq_hv_trace_en=1;
    cpu_read(23'h600004,got);
    irq_hv_trace_en=0;
    if (irq_s6_source_y!=source_y || irq_s6_frame!=irq_s0_frame ||
        irq_s6_line_age<s6_min_age || irq_s6_line_age>s6_max_age ||
        irq_s0_canonical_residue!=candidate_canonical_residue ||
        irq_s0_edge_residue!=(irq_s0_canonical_residue+CPU_START_DELAY96)%48 ||
        irq_s6_canonical_residue!=irq_s6_residue_for_s0(irq_s0_canonical_residue) ||
        irq_s6_edge_residue!=(irq_s6_canonical_residue+CPU_START_DELAY96)%48 ||
        irq_s6_clk96-irq_s0_clk96!=irq_cpu_edge_span_for_s0(irq_s0_canonical_residue) ||
        irq_s6_clk48-irq_s0_clk48!=candidate_delta ||
        irq_s6_line_age-irq_s0_line_age!=candidate_delta ||
        irq_s0_line_age+candidate_delta<s6_min_age || irq_s0_line_age+candidate_delta>s6_max_age ||
        irq_s6_expected!==expected_word || got!==expected_word) begin
        $display("IRQ_HV_FAIL fixed S6 label=%0s K96=%0d S0frame/age=%0d/%0d residue raw/canon=%0d/%0d S6frame/y/age=%0d/%0d/%0d residue raw/canon=%0d/%0d delta48=%0d delta96=%0d expectedD=%0d history/CPU/pristine=%04x/%04x/%04x required=%04x window=%0d..%0d native=%0d/%0d raw=%03x/%03x",
            label,CPU_START_DELAY96,irq_s0_frame,irq_s0_line_age,irq_s0_edge_residue,irq_s0_canonical_residue,
            irq_s6_frame,irq_s6_source_y,irq_s6_line_age,irq_s6_edge_residue,irq_s6_canonical_residue,
            irq_s6_clk48-irq_s0_clk48,
            irq_s6_clk96-irq_s0_clk96,candidate_delta,irq_s6_expected,got,cpu_capture_legacy_data,expected_word,
            s6_min_age,s6_max_age,uut_ym.l106,uut_ym.l105,raster_hdump,raster_vdump);
        $fatal(1);
    end
    passed=1;
    $display("IRQ_HV_S6_PASS label=%0s sourceY=%0d frame=%0d K96=%0d S0age=%0d S6age=%0d residue S0 raw/canon=%0d/%0d S6 raw/canon=%0d/%0d D48=%0d D96=%0d word=%04x history=%04x rawH/V=%03x/%03x",
        label,source_y,irq_s6_frame,CPU_START_DELAY96,irq_s0_line_age,irq_s6_line_age,
        irq_s0_edge_residue,irq_s0_canonical_residue,irq_s6_edge_residue,irq_s6_canonical_residue,
        irq_s6_clk48-irq_s0_clk48,irq_s6_clk96-irq_s0_clk96,got,irq_s6_expected,raster_hdump,raster_vdump);
end
endtask

task irq_legacy_hv_sample;
    input string label;
    input integer source_y;
    input integer source_frame;
    input integer source_age_min;
    reg [15:0] got;
    integer timeout, bound, frames_ahead;
begin
    timeout=0;
    // The declared frame can be ahead of the current external frame. Budget
    // exactly that many frames plus one target frame and the line margin.
    frames_ahead=source_frame-irq_source_frame_id;
    if (frames_ahead<0) frames_ahead=0;
    bound=(frames_ahead+1)*(integer'(TEST_FRAME_LINES)+2)*integer'(TEST_LINE_PIXELS)*irq_tick_edges_per_pixel();
    if (irq_source_frame_id>source_frame ||
        (irq_source_frame_id==source_frame && irq_source_line_active &&
         (irq_source_line_y>source_y || (irq_source_line_y==source_y && irq_source_line_age>source_age_min)))) begin
        $display("IRQ_HV_LEGACY_FAIL source sample already passed %0s target=%0d/%0d/%0d current=%0d/%0d/%0d",
            label,source_frame,source_y,source_age_min,irq_source_frame_id,irq_source_line_y,irq_source_line_age);
        $fatal(1);
    end
    while (!(irq_source_line_active && irq_source_line_y==source_y &&
             irq_source_frame_id==source_frame && irq_source_line_age>=source_age_min) && timeout<bound) begin
        tick(); timeout=timeout+1;
        if (irq_source_frame_id>source_frame ||
            (irq_source_frame_id==source_frame && irq_source_line_active &&
             (irq_source_line_y>source_y ||
              (irq_source_line_y==source_y && irq_source_line_age>source_age_min)))) begin
            $display("IRQ_HV_LEGACY_FAIL source target passed during wait %0s target=%0d/%0d/%0d current=%0d/%0d/%0d",
                label,source_frame,source_y,source_age_min,irq_source_frame_id,irq_source_line_y,irq_source_line_age);
            $fatal(1);
        end
    end
    if (timeout>=bound || !irq_source_line_active || irq_source_line_y!=source_y ||
        irq_source_frame_id!=source_frame || irq_source_line_age<source_age_min) begin
        $display("IRQ_HV_LEGACY_FAIL no source launch for %0s frame/y/age=%0d/%0d/%0d target=%0d/%0d/%0d",
            label,irq_source_frame_id,irq_source_line_y,irq_source_line_age,source_frame,source_y,source_age_min);
        $fatal(1);
    end
    @(posedge cpu_clk); #1;
    irq_s0_on_current_edge=1;
    irq_hv_trace_en=1;
    cpu_read(23'h600004,got);
    irq_hv_trace_en=0;
    if ((^got)===1'bx || irq_s0_frame!=source_frame || irq_s0_source_y!=source_y ||
        irq_s0_line_age<source_age_min || irq_s0_line_age>source_age_min+8 ||
        irq_s6_frame!=source_frame || irq_s6_source_y!=source_y) begin
        $display("IRQ_HV_LEGACY_FAIL source HV sample %0s S0=%0d/%0d/%0d S6=%0d/%0d/%0d data=%04x",
            label,irq_s0_frame,irq_s0_source_y,irq_s0_line_age,
            irq_s6_frame,irq_s6_source_y,irq_s6_line_age,got);
        $fatal(1);
    end
    $display("IRQ_HV_LEGACY_HV label=%0s frame/y S0age/S6age=%0d/%0d %0d/%0d K96=%0d S0raw/canon=%0d/%0d S6raw/canon=%0d/%0d word current/pristine=%04x/%04x",
        label,source_frame,source_y,irq_s0_line_age,irq_s6_line_age,CPU_START_DELAY96,
        irq_s0_edge_residue,irq_s0_canonical_residue,irq_s6_edge_residue,irq_s6_canonical_residue,
        got,cpu_capture_legacy_data);
end
endtask

task irq_check_pending_status;
    input string label;
    input reg expected_v;
    reg [15:0] status;
begin
    irq_status_no_ack(status);
    if (status[7]!==expected_v) begin
        $display("IRQ_HV_FAIL %0s status bit7=%b expected=%b full=%04x pending=%b%b",
            label,status[7],expected_v,status,irq_h_pending_expected,irq_v_pending_expected); $fatal(1);
    end
end
endtask

task irq_wait_vblank_coverage;
    integer timeout, bound, required_samples;
begin
    timeout=0;
    required_samples=2*integer'(TEST_LINE_PIXELS)*8;
    bound=(integer'(TEST_FRAME_LINES)+2)*integer'(TEST_LINE_PIXELS)*8;
    while (irq_blank_check_samples<required_samples && timeout<bound) begin
        tick(); timeout=timeout+1;
    end
    if (irq_blank_check_samples<required_samples || !irq_hie_expected ||
        irq_h_pending_expected || irq_v_pending_expected) begin
        $display("IRQ_HV_FAIL vertical blank clear coverage samples=%0d required=%0d currentBlank=%b active=%b HIE=%b pending(H/V)=%b%b source q/index=%0d/%0d",
            irq_blank_check_samples,required_samples,irq_blank_sequence,irq_source_line_active,
            irq_hie_expected,irq_h_pending_expected,irq_v_pending_expected,
            irq_source_line_q,irq_blank_line_index); $fatal(1);
    end
    irq_h_blank_clear_seen=1;
    $display("IRQ_HV_VBLANK_PASS clk48 samples=%0d required=%0d q=%0d blankLines=%0d HIE=1 no pending",
        irq_blank_check_samples,required_samples,irq_source_line_q,irq_blank_line_index);
end
endtask

task irq_write_reg_intak1;
    input [7:0] index;
    input [7:0] value;
begin
    irq_reg_write(index,value);
end
endtask

task run_irq_hv_strict_passive;
    integer frame1, frame2, y;
    reg [15:0] status;
    reg ok_before, ok_after, ok_jump_left, ok_jump_right;
begin
    $display("IRQ_HV_STRICT: source-only edge model, phase-derived S0-to-S6, fixed stable bus windows; geometry=%0dx%0d K96=%0d",
        TEST_LINE_PIXELS,TEST_FRAME_LINES,CPU_START_DELAY96);
    if (!PASSIVE_MODE || TEST_LINE_PIXELS==384 && TEST_FRAME_LINES!=260) begin
        $display("IRQ_HV_FAIL strict passive profile geometry unsupported"); $fatal(1);
    end

    // Clear any startup pending state while both sources are enabled, then
    // put INTAK high before the mask/configuration phase.
    service_intak=1;
    cpu_write(23'h600002,16'h8014); repeat(32) tick();
    irq_hie_expected=1;
    cpu_write(23'h600002,16'h8164); repeat(32) tick();
    irq_vie_expected=1;
    service_intak=0;
    cpu_read(23'h600002,status);
    cpu_read(23'h600002,status);
    repeat(8) tick();
    irq_h_pending_expected=0;
    irq_v_pending_expected=0;
    if (ym_ipl1!==1'b0 || ym_ipl2!==1'b0) begin
        $display("IRQ_HV_FAIL startup IRQ cleanup did not leave pins low %b%b",ym_ipl1,ym_ipl2); $fatal(1);
    end
    // Enter the counted test at a measured vertical blank. Clear any request
    // generated during the intervening enabled frame before changing R10.
    service_intak=1;
    if (TEST_LINE_PIXELS==400) irq_wait_next_vs_phase(0,3);
    else irq_wait_next_vs();
    service_intak=0;
    cpu_read(23'h600002,status);
    cpu_read(23'h600002,status);
    repeat(8) tick();
    if (ym_ipl1!==1'b0 || ym_ipl2!==1'b0) begin
        $display("IRQ_HV_FAIL VS-blank cleanup did not clear prior requests pins=%b%b",ym_ipl1,ym_ipl2); $fatal(1);
    end
    service_intak=1;
    cpu_write(23'h600002,16'h8a07); repeat(32) tick();
    irq_reg_write(8'h00,8'h04);
    irq_reg_write(8'h01,8'h54);
    irq_check_pins("masked before counted interval");
    irq_h_pending_expected=0;
    irq_v_pending_expected=0;
    irq_h_event_count=0;
    irq_v_event_count=0;
    irq_v_event_frame=-1;
    irq_blank_check_samples=0;
    irq_h222_retained=0;
    irq_both_pending_masked=0;
    irq_both_pending_v_priority=0;
    irq_v_mask_reveals_h=0;
    irq_v_restore_priority=0;
    irq_v_ack_h_survivor=0;
    irq_survivor_status_preserved=0;
    irq_h_survivor_ack_cleared=0;
    irq_priority_v_ack_watch=0;
    irq_priority_h_clear_watch=0;
    irq_v_ack_h_survivor_count=0;
    irq_h_survivor_ack_clear_count=0;

    frame1=irq_source_frame_id;
    if (TEST_LINE_PIXELS==400 && frame1%3!=0) begin
        $display("IRQ_HV_FAIL counted400 epoch did not start at declared frame phase0 frame=%0d",frame1); $fatal(1);
    end
    irq_event_model_en=1;
    irq_blank_check_en=1;
    irq_pin_check_en=1;

    // V511's preactive H opportunity is included in the reviewed counter
    // sequence, making the first active H request y6.
    irq_masked_h_line(6,frame1);
    irq_check_active_y0_origin(frame1);
    irq_h_irq_first_seen=1;
    irq_reg_write(8'h00,8'h14); // HIE on while INTAK remains high
    if (ym_ipl1!==1'b0 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL enabling HIE did not reveal the y6 pending request pins=%b%b",ym_ipl1,ym_ipl2); $fatal(1);
    end
    irq_status_no_ack(status);
    if (ym_ipl2!==1'b1) begin $display("IRQ_HV_FAIL INTAK=1 status read cleared masked H pending"); $fatal(1); end
    if (status[7]!==1'b0) begin
        $display("IRQ_HV_FAIL H pending incorrectly appears in status bit7: %04x",status); $fatal(1);
    end
    irq_ack_existing_h(6);

    for (y=14;y<=222;y=y+8) begin
        irq_enabled_h_ack(y,frame1);
        if (y==14) irq_h_irq_periodic_seen=1;
    end
    irq_read_s0_window("row223-before",223,frame1,2426,2433,16'hdfa4,ok_before);
    irq_hv_before_seen=ok_before;
    irq_wait_event(223,irq_v_event_age(),frame1);
    if (!irq_v_pending_expected || ym_ipl1!==1'b0 || ym_ipl2!==1'b0) begin
        $display("IRQ_HV_FAIL masked V event did not retain pending with pins low"); $fatal(1);
    end
    irq_check_pending_status("first frame V pending",1'b1);

    // Clear frame one's V request so the next frame has a fresh event. This
    // cleanup is separate from the full mask/re-enable sequence in frame 2.
    irq_blank_check_en=0;
    irq_reg_write(8'h01,8'h64);
    irq_check_pins("frame-one VIE cleanup enable");
    irq_ack_status(1'b0,1'b1,status);
    irq_check_pending_status("frame-one V clear",1'b0);
    irq_reg_write(8'h01,8'h54);
    irq_blank_check_en=1;

    irq_wait_next_vs();
    frame2=irq_source_frame_id;
    if (frame2!=frame1+1 || (TEST_LINE_PIXELS==400 && frame2%3!=1)) begin
        $display("IRQ_HV_FAIL counted second epoch source phase frame1/frame2=%0d/%0d geometry=%0dx%0d",
            frame1,frame2,TEST_LINE_PIXELS,TEST_FRAME_LINES); $fatal(1);
    end
    irq_enabled_h_ack(6,frame2);
    irq_check_active_y0_origin(frame2);
    irq_h_postblank_seen=1;
    for (y=14;y<=214;y=y+8) irq_enabled_h_ack(y,frame2);
    irq_read_s0_window("jump-left-H364",220,frame2,2636,2639,16'hddb6,ok_jump_left);
    irq_jump_left_seen=ok_jump_left;
    irq_read_s0_window("jump-right-H457",221,frame2,2640,2643,16'hdee4,ok_jump_right);
    irq_jump_right_seen=ok_jump_right;
    irq_wait_event(222,2433,frame2);
    if (!irq_h_pending_expected || irq_v_pending_expected ||
        !irq_hie_expected || irq_vie_expected || service_intak!==1'b1 ||
        ym_ipl1!==1'b0 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL second-frame y222 H was not retained before row223 HV pending(H/V)=%b%b H/VIE=%b%b INTAK=%b pull=%b%b",
            irq_h_pending_expected,irq_v_pending_expected,irq_hie_expected,
            irq_vie_expected,service_intak,ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_read_s0_window("row223-after",223,frame2,2434,2441,16'he0a5,ok_after);
    if (!irq_h_pending_expected || irq_v_pending_expected ||
        !irq_hie_expected || irq_vie_expected || ym_ipl1!==1'b0 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL fixed row223-after HV read did not retain y222 H pending(H/V)=%b%b H/VIE=%b%b pull=%b%b",
            irq_h_pending_expected,irq_v_pending_expected,irq_hie_expected,
            irq_vie_expected,ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_h222_retained=1;
    irq_hv_after_seen=ok_after;
    irq_wait_event(223,irq_v_event_age(),frame2);
    if (!irq_h_pending_expected || !irq_v_pending_expected ||
        !irq_hie_expected || irq_vie_expected || ym_ipl1!==1'b0 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL second-frame masked V did not retain both-pending H pull(H/V)=%b%b H/VIE=%b%b pins=%b%b",
            irq_h_pending_expected,irq_v_pending_expected,irq_hie_expected,
            irq_vie_expected,ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_check_pending_status("second frame masked V pending",1'b1);
    if (!irq_h_pending_expected || !irq_v_pending_expected ||
        ym_ipl1!==1'b0 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL masked simultaneous pending pull mismatch pending(H/V)=%b%b pull=%b%b",
            irq_h_pending_expected,irq_v_pending_expected,ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_both_pending_masked=1;
    irq_reg_write(8'h01,8'h64);
    irq_check_pins("VIE restored");
    if (!irq_h_pending_expected || !irq_v_pending_expected ||
        !irq_hie_expected || !irq_vie_expected || ym_ipl1!==1'b1 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL simultaneous pending did not select V priority pending(H/V)=%b%b H/VIE=%b%b pull=%b%b",
            irq_h_pending_expected,irq_v_pending_expected,irq_hie_expected,
            irq_vie_expected,ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_both_pending_v_priority=1;
    irq_v_pending_seen=1;
    irq_reg_write(8'h01,8'h54);
    irq_check_pins("VIE masked with pending retained");
    if (!irq_h_pending_expected || !irq_v_pending_expected ||
        !irq_hie_expected || irq_vie_expected || ym_ipl1!==1'b0 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL masking V did not reveal retained H pending(H/V)=%b%b H/VIE=%b%b pull=%b%b",
            irq_h_pending_expected,irq_v_pending_expected,irq_hie_expected,
            irq_vie_expected,ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_v_mask_reveals_h=1;
    irq_v_mask_seen=1;
    irq_check_pending_status("V status after mask",1'b1);
    irq_reg_write(8'h01,8'h64);
    irq_check_pins("VIE re-enabled with pending retained");
    if (!irq_h_pending_expected || !irq_v_pending_expected ||
        !irq_hie_expected || !irq_vie_expected || ym_ipl1!==1'b1 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL restoring VIE did not restore V priority pending(H/V)=%b%b H/VIE=%b%b pull=%b%b",
            irq_h_pending_expected,irq_v_pending_expected,irq_hie_expected,
            irq_vie_expected,ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_v_restore_priority=1;
    irq_v_restore_seen=1;
    irq_check_pending_status("V status after re-enable",1'b1);
    if (!irq_h_pending_expected || !irq_v_pending_expected ||
        ym_ipl1!==1'b1 || ym_ipl2!==1'b1 ||
        irq_source_frame_id!=frame2 || irq_v_event_frame!=frame2) begin
        $display("IRQ_HV_FAIL re-enabled both-pending pull/frame mismatch pending(H/V)=%b%b pull=%b%b source/Vevent=%0d/%0d expected=%0d",
            irq_h_pending_expected,irq_v_pending_expected,ym_ipl1,ym_ipl2,
            irq_source_frame_id,irq_v_event_frame,frame2);
        $fatal(1);
    end
    irq_priority_case_frame=frame2;
    irq_priority_v_ack_watch=1;
    irq_ack_allow_h_survivor=1;
    irq_ack_status(1'b0,1'b1,status);
    irq_priority_v_ack_watch=0;
    if (!irq_v_ack_h_survivor || irq_v_ack_h_survivor_count!=1 ||
        !irq_h_pending_expected || irq_v_pending_expected ||
        ym_ipl1!==1'b0 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL exact V-ACK observer did not record retained H count=%0d flag=%b pending(H/V)=%b%b pull=%b%b",
            irq_v_ack_h_survivor_count,irq_v_ack_h_survivor,
            irq_h_pending_expected,irq_v_pending_expected,ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_v_ack_clear_seen=1;
    irq_check_pending_status("V status after ACK",1'b0);
    if (!irq_h_pending_expected || irq_v_pending_expected ||
        ym_ipl1!==1'b0 || ym_ipl2!==1'b1) begin
        $display("IRQ_HV_FAIL status read did not preserve H survivor pending(H/V)=%b%b pull=%b%b",
            irq_h_pending_expected,irq_v_pending_expected,ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_survivor_status_preserved=1;
    irq_priority_h_clear_watch=1;
    irq_ack_existing_h(222);
    irq_priority_h_clear_watch=0;
    if (!irq_h_survivor_ack_cleared || irq_h_survivor_ack_clear_count!=1 ||
        irq_h_pending_expected || irq_v_pending_expected ||
        ym_ipl1!==1'b0 || ym_ipl2!==1'b0) begin
        $display("IRQ_HV_FAIL exact H-survivor clear observer count=%0d flag=%b pending(H/V)=%b%b pull=%b%b",
            irq_h_survivor_ack_clear_count,irq_h_survivor_ack_cleared,
            irq_h_pending_expected,irq_v_pending_expected,ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_reg_write(8'h01,8'h54);
    irq_wait_vblank_coverage();
    irq_blank_check_en=0;
    irq_event_model_en=0;
    irq_pin_check_en=0;

    if (!irq_h_irq_first_seen || !irq_h_irq_periodic_seen || !irq_h_blank_clear_seen || !irq_h_postblank_seen ||
        !irq_v_pending_seen || !irq_v_mask_seen || !irq_v_restore_seen || !irq_v_ack_clear_seen ||
        !irq_hv_before_seen || !irq_hv_after_seen || !irq_jump_left_seen || !irq_jump_right_seen ||
        !irq_h222_retained || !irq_both_pending_masked || !irq_both_pending_v_priority ||
        !irq_v_mask_reveals_h || !irq_v_restore_priority || !irq_v_ack_h_survivor ||
        !irq_survivor_status_preserved || !irq_h_survivor_ack_cleared ||
        irq_v_ack_h_survivor_count!=1 || irq_h_survivor_ack_clear_count!=1 ||
        !irq_encoded_wrap_seen || !irq_v511_tail_seen || !irq_v0_after_tail_seen ||
        irq_h_event_count!=56 || irq_v_event_count!=2 ||
        irq_blank_check_samples<2*8*integer'(TEST_LINE_PIXELS)) begin
        $display("IRQ_HV_FAIL incomplete coverage H/V events=%0d/%0d blankSamples=%0d original=%b%b%b%b%b%b%b%b%b%b%b%b%b%b%b priority=%b%b%b%b%b%b%b%b counts=%0d/%0d",
            irq_h_event_count,irq_v_event_count,irq_blank_check_samples,irq_h_irq_first_seen,
            irq_h_irq_periodic_seen,irq_h_blank_clear_seen,irq_h_postblank_seen,irq_v_pending_seen,irq_v_mask_seen,
            irq_v_restore_seen,irq_v_ack_clear_seen,irq_hv_before_seen,irq_hv_after_seen,
            irq_jump_left_seen,irq_jump_right_seen,irq_encoded_wrap_seen,irq_v511_tail_seen,
            irq_v0_after_tail_seen,irq_h222_retained,irq_both_pending_masked,
            irq_both_pending_v_priority,irq_v_mask_reveals_h,irq_v_restore_priority,
            irq_v_ack_h_survivor,irq_survivor_status_preserved,irq_h_survivor_ack_cleared,
            irq_v_ack_h_survivor_count,irq_h_survivor_ack_clear_count); $fatal(1);
    end
    $display("IRQ_HV_PRIORITY_PASS H222-retained=%b both-masked=%b V-priority=%b mask-reveals-H=%b restore=%b VACK-H-survivor=%b status-preserved=%b HACK-cleared=%b observer-counts=%0d/%0d",
        irq_h222_retained,irq_both_pending_masked,irq_both_pending_v_priority,
        irq_v_mask_reveals_h,irq_v_restore_priority,irq_v_ack_h_survivor,
        irq_survivor_status_preserved,irq_h_survivor_ack_cleared,
        irq_v_ack_h_survivor_count,irq_h_survivor_ack_clear_count);
    $display("IRQ_HV_STRICT_PASS Hevents=%0d Vevents=%0d blankSamples=%0d HV=dfa4/e0a5 jump=ddb6/dee4 geometry=%0dx%0d",
        irq_h_event_count,irq_v_event_count,irq_blank_check_samples,TEST_LINE_PIXELS,TEST_FRAME_LINES);
end
endtask

task irq_wait_legacy_pins;
    input reg want1;
    input reg want2;
    input string label;
    integer timeout, bound;
begin
    timeout=0;
    // In legacy mode the YM advances through 420 encoded H events per native
    // line, each at 16 clk96 MCLKs. The independent external timer's 400px
    // line is not a valid timeout unit for autonomous native V events.
    bound=(262+2)*420*16;
    while ((ym_ipl1!==want1 || ym_ipl2!==want2) && timeout<bound) begin
        tick();
        timeout=timeout+1;
    end
    if (ym_ipl1!==want1 || ym_ipl2!==want2) begin
        $display("IRQ_HV_LEGACY_FAIL missing pin tuple %0s want=%b%b got=%b%b frame/y/age=%0d/%0d/%0d",
            label,want1,want2,ym_ipl1,ym_ipl2,irq_source_frame_id,
            irq_source_line_y,irq_source_line_age);
        $fatal(1);
    end
    #2;
end
endtask

task run_irq_hv_strict_legacy;
    reg [15:0] status;
    integer frame_before, frame_after;
begin
    $display("IRQ_HV_LEGACY: current/pristine pin and CPU status/HV equivalence; geometry=400x262");
    if (PASSIVE_MODE || TEST_LINE_PIXELS!=400 || TEST_FRAME_LINES!=262) begin
        $display("IRQ_HV_LEGACY_FAIL legacy equivalence requires 400x262 legacy mode");
        $fatal(1);
    end
    // Establish a fresh native V epoch. The raw external VS edge is not phase
    // aligned to the legacy YM's autonomous 420-event raster.
    service_intak=1;
    irq_reg_write(8'h00,8'h04); // HIE off; VIE on
    irq_reg_write(8'h01,8'h64);
    irq_pin_check_en=0;
    irq_legacy_compare_en=1;
    service_intak=0;
    cpu_read(23'h600002,status); // discard any initial V latch
    service_intak=1;
    irq_wait_legacy_pins(1'b0,1'b0,"initial V cleanup");
    irq_status_no_ack(status);
    if (status[7]!==1'b0) begin
        $display("IRQ_HV_LEGACY_FAIL initial V cleanup did not clear status7: %04x",status);
        $fatal(1);
    end
    $display("IRQ_HV_LEGACY_PREP initial-clear t=%0t clk96=%0d MCLK=%0d status=%04x INTAK=%b pull=%b%b",
        $time,irq_clk96_edge_count,irq_ym_mclk_count,status,service_intak,ym_ipl1,ym_ipl2);
    irq_wait_legacy_pins(1'b1,1'b1,"fresh native V request with HIE off");
    irq_status_no_ack(status);
    if (status[7]!==1'b1) begin
        $display("IRQ_HV_LEGACY_FAIL fresh native V request missing status7: %04x",status);
        $fatal(1);
    end
    $display("IRQ_HV_LEGACY_PREP fresh-V t=%0t clk96=%0d MCLK=%0d status=%04x INTAK=%b pull=%b%b nativeH/V=%0d/%0d",
        $time,irq_clk96_edge_count,irq_ym_mclk_count,status,service_intak,
        ym_ipl1,ym_ipl2,uut_ym.l106,uut_ym.l105);
    irq_ack_status(1'b0,1'b1,status);
    irq_wait_legacy_pins(1'b0,1'b0,"fresh native V acknowledged");
    irq_status_no_ack(status);
    if (status[7]!==1'b0) begin
        $display("IRQ_HV_LEGACY_FAIL fresh native V acknowledge did not clear status7: %04x",status);
        $fatal(1);
    end
    $display("IRQ_HV_LEGACY_PREP fresh-V-cleared t=%0t clk96=%0d MCLK=%0d status=%04x INTAK=%b pull=%b%b",
        $time,irq_clk96_edge_count,irq_ym_mclk_count,status,service_intak,ym_ipl1,ym_ipl2);

    // Enable H briefly and acknowledge a latch accumulated while HIE was off;
    // this preparation does not count as the main H-only probe.
    irq_reg_write(8'h00,8'h14);
    service_intak=0;
    cpu_read(23'h600002,status);
    service_intak=1;
    irq_wait_legacy_pins(1'b0,1'b0,"pre-probe H cleanup");
    irq_status_no_ack(status);
    if (status[7]!==1'b0) begin
        $display("IRQ_HV_LEGACY_FAIL pre-probe cleanup unexpectedly has V pending: %04x",status);
        $fatal(1);
    end
    $display("IRQ_HV_LEGACY_PREP H-clean t=%0t clk96=%0d MCLK=%0d status=%04x INTAK=%b pull=%b%b nativeH/V=%0d/%0d",
        $time,irq_clk96_edge_count,irq_ym_mclk_count,status,service_intak,
        ym_ipl1,ym_ipl2,uut_ym.l106,uut_ym.l105);

    // Main probe starts only after the cleanup above. Keep VIE masked through
    // the first H request and its acknowledge; then retain the next H request
    // before restoring VIE for the V-priority/survivor portion.
    irq_reg_write(8'h01,8'h54);
    irq_reg_write(8'h0a,8'h07);
    irq_reg_write(8'h00,8'h14);
    irq_status_no_ack(status);
    if (status[7]!==1'b0) begin
        $display("IRQ_HV_LEGACY_FAIL V status not clear at main H probe start: %04x",status);
        $fatal(1);
    end
    irq_legacy_h_seen=0;
    irq_legacy_v_seen=0;
    irq_legacy_pin_samples=0;
    irq_wait_legacy_pins(1'b0,1'b1,"H only");
    irq_status_no_ack(status);
    if (status[7]!==1'b0) begin
        $display("IRQ_HV_LEGACY_FAIL H-only status unexpectedly sets V pending bit: %04x",status);
        $fatal(1);
    end
    $display("IRQ_HV_LEGACY_PREP H-only t=%0t clk96=%0d MCLK=%0d status=%04x INTAK=%b pull=%b%b nativeH/V=%0d/%0d",
        $time,irq_clk96_edge_count,irq_ym_mclk_count,status,service_intak,
        ym_ipl1,ym_ipl2,uut_ym.l106,uut_ym.l105);
    irq_ack_status(1'b1,1'b0,status);
    irq_wait_legacy_pins(1'b0,1'b1,"next H retained before VIE enable");
    irq_status_no_ack(status);
    if (status[7]!==1'b0) begin
        $display("IRQ_HV_LEGACY_FAIL retained second H request has unexpected V status: %04x",status);
        $fatal(1);
    end
    $display("IRQ_HV_LEGACY_PREP second-H-retained t=%0t clk96=%0d MCLK=%0d status=%04x INTAK=%b pull=%b%b nativeH/V=%0d/%0d",
        $time,irq_clk96_edge_count,irq_ym_mclk_count,status,service_intak,
        ym_ipl1,ym_ipl2,uut_ym.l106,uut_ym.l105);
    irq_reg_write(8'h01,8'h64);
    if (ym_ipl2!==1'b1) begin
        $display("IRQ_HV_LEGACY_FAIL enabling VIE lost retained H request pull=%b%b",ym_ipl1,ym_ipl2);
        $fatal(1);
    end
    irq_wait_legacy_pins(1'b1,1'b1,"V priority over retained H");
    irq_status_no_ack(status);
    if (status[7]!==1'b1) begin
        $display("IRQ_HV_LEGACY_FAIL V request did not set status bit7: %04x",status);
        $fatal(1);
    end
    irq_ack_allow_h_survivor=1;
    irq_ack_status(1'b0,1'b1,status);
    irq_wait_legacy_pins(1'b0,1'b1,"H revealed after V acknowledge");
    irq_ack_status(1'b1,1'b0,status);
    irq_status_no_ack(status);
    if (status[7]!==1'b0 || !irq_legacy_h_seen || !irq_legacy_v_seen || irq_legacy_pin_samples==0) begin
        $display("IRQ_HV_LEGACY_FAIL final status/coverage status=%04x H/V=%b%b samples=%0d",
            status,irq_legacy_h_seen,irq_legacy_v_seen,irq_legacy_pin_samples);
        $fatal(1);
    end
    irq_legacy_compare_en=0;
    $display("IRQ_HV_LEGACY_IRQ_PASS current/pristine matched for %0d clk96 samples; H-only, V-priority, and status set/clear observed",
        irq_legacy_pin_samples);

    // Capture the common four legal HV reads after the pending-state check.
    // Keep requests masked, but compare every S6 word against pristine.
    irq_reg_write(8'h01,8'h54);
    irq_reg_write(8'h00,8'h04);
    irq_pin_check_en=0;
    frame_before=irq_source_frame_id+1;
    irq_legacy_hv_sample("row223-before",223,frame_before,2390);
    frame_after=frame_before+1;
    irq_legacy_hv_sample("jump-left",220,frame_after,2621);
    irq_legacy_hv_sample("jump-right",221,frame_after,2625);
    irq_legacy_hv_sample("row223-after",223,frame_after,2480);
    $display("IRQ_HV_LEGACY_PASS current/pristine CPU HV words matched at all four fixed source windows");
end
endtask

task run_irq_hv_profile;
    integer start_frame;
begin
    if ($test$plusargs("irq_calibrate")) begin
        $display("IRQ_HV_CALIBRATION_ONLY: four fixed external launches; values are diagnostic, not accepted coverage");
        start_frame=irq_source_frame_id+1;
        irq_calibrated_read("row223-before",223,2433,start_frame);
        irq_calibrated_read("row223-after",223,2434,irq_source_frame_id+1);
        irq_calibrated_read("jump-left",220,2637,irq_source_frame_id);
        irq_calibrated_read("jump-right",221,2640,irq_source_frame_id);
        if (irq_calibration_count!=4) begin
            $display("IRQ_HV_CAL_FAIL incomplete fixed-launch coverage count=%0d",irq_calibration_count);
            $fatal(1);
        end
        $display("IRQ_HV_CALIBRATION_COMPLETE count=%0d; no strict acceptance asserted",irq_calibration_count);
        $finish;
    end else if (PASSIVE_MODE) run_irq_hv_strict_passive();
    else run_irq_hv_strict_legacy();
end
endtask
