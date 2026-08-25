/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-3-2026 */

module jtcps3_scan #(
    parameter CMDW=96
)(
    input               rst,
    input               clk,
    input               ln_hs,
    input               ln_vs,
    input               ln_lvbl,
    input       [ 8:0]  ln_v,
    input               xfer_busy,
    input               obj_busy,
    input               scr_busy,
    input       [ 9:0]  objlim,
    input       [ 9:0]  vb_end, vcnt_end,
    input       [ 8:0]  v_step,

    output reg  [ 8:0]  scan_v,
    output reg  [12:2]  scn_vaddr,
    input       [31:0]  scn_vdata,

    output reg          obj_draw,
    output reg          scr_draw,
    output reg  [CMDW-1:0] cmd,
    output reg          line_done,
    output reg          busy,
    input       [ 3:0]  gfx_en
);

localparam ST_IDLE      = 4'd0,
           ST_FETCH0    = 4'd1,
           ST_FETCH1    = 4'd2,
           ST_FETCH2    = 4'd3,
           ST_FETCH3    = 4'd4,
           ST_WAIT_DRAW = 4'd5,
           ST_LINE_DONE = 4'd6,
           ST_FETCH1_WAIT = 4'd7,
           ST_FETCH2_WAIT = 4'd8,
           ST_FETCH2_DECIDE = 4'd9;

localparam INVALID_Y  = 2'd0,
           IS_TILEMAP = 2'd0;

reg        ln_vs_l;
reg [ 3:0] st;
reg [12:2] entry_addr;
reg [12:2] nx_entry_addr;
reg [31:0] cmd_w0, cmd_w1, cmd_w2;
reg [ 7:0] entry_height;
reg [ 8:0] last_line_l;
reg        tilemap_sel, entry_tilemap, entry_invalid, entry_visible, entry_draw_en;

wire       draw_busy, is_lutover;
wire [9:0] entry_num;
wire       scr_en, obj_en;
wire [8:0] visible_lines, zoom_lines, last_line;
wire [17:0] zoom_line_prod, zoom_line_ceil;

assign draw_busy    = obj_busy | scr_busy;
assign entry_num    = { 1'b0, entry_addr[12:4] };
assign is_lutover   = entry_num >= objlim;
assign scr_en       = gfx_en[1];
assign obj_en       = gfx_en[3];
assign visible_lines= vcnt_end[8:0] - vb_end[8:0];
assign zoom_line_prod = { 9'd0, visible_lines } * v_step;
assign zoom_line_ceil = zoom_line_prod + 18'h0ff;
assign zoom_lines   = zoom_line_ceil[16:8];
assign last_line    = v_step > 9'h100 ? zoom_lines - 9'd1 : visible_lines - 9'd1;

function visible_line;
    input [8:0] line;
    input [9:0] base_raw;
    input [7:0] height;
    reg signed [11:0] line_i, base_i, end_i;
begin
    line_i = { 3'd0, line };
    base_i = base_raw[9] ? { 2'b11, base_raw } : { 2'b00, base_raw };
    end_i  = base_i + { 4'd0, height } - 12'd1;
    visible_line = height != 0 && line_i >= base_i && line_i <= end_i;
end
endfunction

function check_sprite_visible;
    input [8:0] line;
    input [9:0] ypos;
    input [7:0] height;
    reg   [10:0] ypos_sum;
    reg   [ 9:0] base_raw;
begin
    ypos_sum       = { 1'b0, ypos } + { 3'd0, height[7:1] };
    base_raw       = ~ypos_sum[9:0] - 10'd17;
    check_sprite_visible = visible_line(line, base_raw, height);
end
endfunction

function check_tilemap_visible;
    input [8:0] line;
    input [9:0] ypos;
    input [7:0] height;
    reg   [9:0] base_raw;
begin
    base_raw        = ~ypos - 10'd18;
    check_tilemap_visible = visible_line(line, base_raw, height);
end
endfunction

task start_line;
begin
    entry_addr <= 11'd0;
    scn_vaddr  <= 11'd2;
    busy       <= 1'b1;
    st         <= ST_FETCH0;
end
endtask

task advance_entry;
begin
    nx_entry_addr = entry_addr + 11'd4;
    if( nx_entry_addr == 11'd0 ) begin
        st <= ST_LINE_DONE;
    end else begin
        entry_addr <= nx_entry_addr;
        scn_vaddr  <= nx_entry_addr + 11'd2;
        st         <= ST_FETCH0;
    end
end
endtask

`ifdef SIMULATION
`ifdef CPS3_STATS
integer sim_frame_num;
integer sim_line_cycles, sim_line_scr_cycles, sim_line_obj_cycles,
        sim_line_draw_cycles, sim_line_overlap_cycles;
integer sim_frame_lines, sim_frame_cycles, sim_frame_scr_cycles,
        sim_frame_obj_cycles, sim_frame_draw_cycles, sim_frame_overlap_cycles;
real    sim_avg_line_cycles, sim_avg_scr_cycles, sim_avg_obj_cycles,
        sim_avg_draw_cycles, sim_avg_nondraw_cycles, sim_avg_overlap_cycles;
real    sim_draw_pct, sim_idle_pct, sim_scr_draw_pct, sim_obj_draw_pct;
reg     sim_busy_l;
reg [8:0] sim_scan_v_l;

task sim_reset_line;
begin
    sim_line_cycles        = 0;
    sim_line_scr_cycles    = 0;
    sim_line_obj_cycles    = 0;
    sim_line_draw_cycles   = 0;
    sim_line_overlap_cycles= 0;
end
endtask

task sim_reset_frame;
begin
    sim_frame_lines         = 0;
    sim_frame_cycles        = 0;
    sim_frame_scr_cycles    = 0;
    sim_frame_obj_cycles    = 0;
    sim_frame_draw_cycles   = 0;
    sim_frame_overlap_cycles= 0;
end
endtask

task sim_commit_line;
begin
    if( sim_line_cycles != 0 ) begin
        sim_frame_lines          = sim_frame_lines + 1;
        sim_frame_cycles         = sim_frame_cycles + sim_line_cycles;
        sim_frame_scr_cycles     = sim_frame_scr_cycles + sim_line_scr_cycles;
        sim_frame_obj_cycles     = sim_frame_obj_cycles + sim_line_obj_cycles;
        sim_frame_draw_cycles    = sim_frame_draw_cycles + sim_line_draw_cycles;
        sim_frame_overlap_cycles = sim_frame_overlap_cycles + sim_line_overlap_cycles;
    end
end
endtask

task sim_report_frame;
begin
    if( sim_frame_lines != 0 && sim_frame_cycles != 0 ) begin
        sim_avg_line_cycles    = sim_frame_cycles;
        sim_avg_scr_cycles     = sim_frame_scr_cycles;
        sim_avg_obj_cycles     = sim_frame_obj_cycles;
        sim_avg_draw_cycles    = sim_frame_draw_cycles;
        sim_avg_overlap_cycles = sim_frame_overlap_cycles;

        sim_avg_line_cycles    = sim_avg_line_cycles    / sim_frame_lines;
        sim_avg_scr_cycles     = sim_avg_scr_cycles     / sim_frame_lines;
        sim_avg_obj_cycles     = sim_avg_obj_cycles     / sim_frame_lines;
        sim_avg_draw_cycles    = sim_avg_draw_cycles    / sim_frame_lines;
        sim_avg_overlap_cycles = sim_avg_overlap_cycles / sim_frame_lines;
        sim_avg_nondraw_cycles = sim_avg_line_cycles - sim_avg_draw_cycles;
        sim_draw_pct           = (sim_frame_draw_cycles * 100.0) / sim_frame_cycles;
        sim_idle_pct           = 100.0 - sim_draw_pct;

        if( sim_frame_draw_cycles != 0 ) begin
            sim_scr_draw_pct = (sim_frame_scr_cycles * 100.0) / sim_frame_draw_cycles;
            sim_obj_draw_pct = (sim_frame_obj_cycles * 100.0) / sim_frame_draw_cycles;
        end else begin
            sim_scr_draw_pct = 0.0;
            sim_obj_draw_pct = 0.0;
        end

        $display(
            "jtcps3_scan frame %0d stats: lines=%0d avg_line=%0.2f avg_draw=%0.2f avg_wait=%0.2f avg_scr=%0.2f avg_obj=%0.2f draw=%0.2f%% idle=%0.2f%% scr/draw=%0.2f%% obj/draw=%0.2f%% overlap=%0.2f",
            sim_frame_num, sim_frame_lines,
            sim_avg_line_cycles, sim_avg_draw_cycles, sim_avg_nondraw_cycles,
            sim_avg_scr_cycles, sim_avg_obj_cycles,
            sim_draw_pct, sim_idle_pct, sim_scr_draw_pct, sim_obj_draw_pct,
            sim_avg_overlap_cycles );
    end
end
endtask

always @(posedge clk) begin
    if( rst ) begin
        sim_frame_num         = 0;
        sim_avg_line_cycles   = 0.0;
        sim_avg_scr_cycles    = 0.0;
        sim_avg_obj_cycles    = 0.0;
        sim_avg_draw_cycles   = 0.0;
        sim_avg_nondraw_cycles= 0.0;
        sim_avg_overlap_cycles= 0.0;
        sim_draw_pct          = 0.0;
        sim_idle_pct          = 0.0;
        sim_scr_draw_pct      = 0.0;
        sim_obj_draw_pct      = 0.0;
        sim_busy_l            = 1'b0;
        sim_scan_v_l          = 9'd0;
        sim_reset_frame();
        sim_reset_line();
    end else begin
        if( busy && !sim_busy_l ) begin
            sim_reset_frame();
            sim_reset_line();
        end else if( busy && scan_v != sim_scan_v_l ) begin
            sim_commit_line();
            sim_reset_line();
        end else if( !busy && sim_busy_l ) begin
            sim_commit_line();
            sim_report_frame();
            sim_frame_num = sim_frame_num + 1;
            sim_reset_frame();
            sim_reset_line();
        end

        if( busy ) begin
            sim_line_cycles = sim_line_cycles + 1;
            if( scr_busy ) sim_line_scr_cycles = sim_line_scr_cycles + 1;
            if( obj_busy ) sim_line_obj_cycles = sim_line_obj_cycles + 1;
            if( draw_busy ) sim_line_draw_cycles = sim_line_draw_cycles + 1;
            if( scr_busy && obj_busy ) sim_line_overlap_cycles = sim_line_overlap_cycles + 1;
        end

        sim_busy_l   = busy;
        sim_scan_v_l = scan_v;
end
end
`endif
`endif


always @(posedge clk) begin
    if( rst ) begin
        ln_vs_l      <= 1'b0;
        scan_v       <= 9'd0;
        scn_vaddr    <= 11'd0;
        obj_draw     <= 1'b0;
        scr_draw     <= 1'b0;
        cmd          <= {CMDW{1'b0}};
        line_done    <= 1'b0;
        busy         <= 1'b0;
        st           <= ST_IDLE;
        entry_addr   <= 11'd0;
        nx_entry_addr<= 11'd0;
        cmd_w0       <= 32'd0;
        cmd_w1       <= 32'd0;
        cmd_w2       <= 32'd0;
        entry_height <= 8'd0;
        last_line_l  <= 9'd0;
        tilemap_sel  <= 1'b0;
        entry_tilemap <= 1'b0;
        entry_invalid <= 1'b0;
        entry_visible <= 1'b0;
        entry_draw_en <= 1'b0;
    end else begin
        obj_draw  <= 1'b0;
        scr_draw  <= 1'b0;
        line_done <= 1'b0;

        case( st )
            ST_IDLE: begin
                busy    <= 1'b0;
                ln_vs_l <= ln_vs;
                scn_vaddr <= 0;
                if( ln_vs && !ln_vs_l ) begin
                    busy   <= 1'b1;
                    scan_v <= 9'd0;
                    last_line_l <= last_line;
                    start_line();
                end
            end

            ST_FETCH0: begin
                if( is_lutover ) begin
                    st <= ST_LINE_DONE;
                end else begin
                    st        <= ST_FETCH1_WAIT;
                    scn_vaddr <= entry_addr + 11'd1;
                end
            end

            ST_FETCH1_WAIT: begin
                st <= ST_FETCH1;
            end

            ST_FETCH1: begin
                cmd_w2        <= scn_vdata;
                entry_tilemap <= scn_vdata[1:0] == IS_TILEMAP;
                entry_invalid <= scn_vdata[3:2] == INVALID_Y;
                entry_height  <= { 1'b0, scn_vdata[30:24] } + 8'd1;
                scn_vaddr     <= entry_addr;
                st            <= ST_FETCH2_WAIT;
            end

            ST_FETCH2_WAIT: begin
                st <= ST_FETCH2;
            end

            ST_FETCH2: begin
                cmd_w1        <= scn_vdata;
                tilemap_sel   <= entry_tilemap;
                entry_draw_en <= entry_tilemap ? scr_en : obj_en;
                entry_visible <= entry_tilemap ? check_tilemap_visible(scan_v, scn_vdata[9:0], entry_height) :
                                                 check_sprite_visible (scan_v, scn_vdata[9:0], entry_height);
                st            <= ST_FETCH2_DECIDE;
            end

            ST_FETCH2_DECIDE: begin
                if( entry_invalid ) begin
                    advance_entry();
                end else if( !entry_draw_en ) begin
                    advance_entry();
                end else if( entry_visible ) begin
                    st <= ST_FETCH3;
                end else begin
                    advance_entry();
                end
            end

            ST_FETCH3: begin
                cmd_w0 <= scn_vdata;
                if( draw_busy ) begin
                    st <= ST_WAIT_DRAW;
                end else begin
                    cmd      <= { cmd_w2, cmd_w1, scn_vdata };
                    scr_draw <=  tilemap_sel & scr_en;
                    obj_draw <= ~tilemap_sel & obj_en;
                    advance_entry();
                end
            end

            ST_WAIT_DRAW: if( !draw_busy ) begin
                cmd      <= { cmd_w2, cmd_w1, cmd_w0 };
                scr_draw <=  tilemap_sel & scr_en;
                obj_draw <= ~tilemap_sel & obj_en;
                advance_entry();
            end

            ST_LINE_DONE: if( !draw_busy && !xfer_busy ) begin
                line_done <= 1'b1;
                if( scan_v == last_line_l ) begin
                    scn_vaddr <= 0;
                    st        <= ST_IDLE;
                end else begin
                    scan_v <= scan_v + 9'd1;
                    start_line();
                end
            end

            default: st <= ST_IDLE;
        endcase
    end
end

endmodule
