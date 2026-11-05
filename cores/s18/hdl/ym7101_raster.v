/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-11-2026 */

module ym7101_raster(
    input             clk,
    input             rst,
    input             pxl_cen,
    input             pxl2_cen,
    input             hs,
    input             vs,
    input             lhbl,
    input             lvbl,
    output     [ 9:0]  x,
    output     [ 8:0]  y,
    output reg [ 8:0]  frame_y,
    output reg         line_start,
    output reg         frame_start,
    output reg         h_active_start,
    output reg         h_active_end,
    output reg         v_active_start,
    output reg         v_active_end,
    output reg         geometry_valid,
    output reg         locked,
    output reg         timing_change,
    output reg         phase_error,
    output reg [ 9:0]  line_pixels,
    output reg [ 9:0]  active_pixels,
    output reg [ 8:0]  frame_lines,
    output reg [ 8:0]  active_lines,
    output reg [ 9:0]  hs_to_active,
    output reg [ 8:0]  vs_to_active_line,
    output reg [ 9:0]  vs_to_active_pixel,
    output reg [12:0]  hs_to_active_clks,
    output reg [12:0]  vs_to_active_clks
);

reg hs_l, vs_l, lhbl_l, lvbl_l;
reg [ 9:0] x_count;
reg [ 8:0] y_count;
reg [15:0] pixel_stamp, clk_stamp;
reg [15:0] last_line_stamp, last_active_stamp, last_hs_stamp, last_hs_clk;
reg [ 8:0] lines_since_vs, active_line_start;
reg [ 2:0] good_lines;
reg [ 1:0] good_frames;
reg [ 3:0] pxl_age, pxl2_age;
reg [ 3:0] lhbl_phase, hs_phase;
reg [ 9:0] line_age;
reg [12:0] hs_age;
reg pxl_missing, pxl2_missing;
reg have_lhbl, have_active, have_hs, have_vs;
reg have_pxl, have_pxl2, have_lhbl_phase, have_hs_phase;
reg have_frame, have_active_width;
reg have_h_offset, have_v_offset;
reg line_zero_pending;
reg [ 8:0] v_offset_line_l;
reg [ 9:0] v_offset_pixel_l;
reg active_open;
reg line_width_ok, active_width_ok;

wire hs_rise   =  hs && !hs_l;
wire vs_rise   =  vs && !vs_l;
wire lhbl_rise =  lhbl && !lhbl_l;
wire lhbl_fall = !lhbl &&  lhbl_l;
wire lvbl_rise =  lvbl && !lvbl_l;
wire lvbl_fall = !lvbl &&  lvbl_l;
wire [15:0] measured_line_period = pixel_stamp - last_line_stamp;
wire [15:0] measured_hs_period   = pixel_stamp - last_hs_stamp;
wire [15:0] measured_active_width= pixel_stamp - last_active_stamp;
wire [15:0] measured_h_offset_clks = clk_stamp - last_hs_clk;
wire pxl_period_bad = pxl_cen && have_pxl && pxl_age != 4'd7;
wire pxl2_period_bad = pxl2_cen && have_pxl2 && pxl2_age != 4'd3;
wire pxl_timeout_bad = have_pxl && pxl_age >= 4'd8;
wire pxl2_timeout_bad = have_pxl2 && pxl2_age >= 4'd4;
wire hs_phase_bad = hs_rise && have_hs_phase && hs_phase != pxl_age;
wire lhbl_phase_bad = lhbl_rise && have_lhbl_phase && lhbl_phase != pxl_age;
wire hs_period_bad = hs_rise && have_hs && line_pixels != 0 && measured_hs_period != {6'd0,line_pixels};
wire lhbl_period_bad = lhbl_rise && have_lhbl && line_pixels != 0 && measured_line_period != {6'd0,line_pixels};
wire active_width_bad = lhbl_fall && have_active && active_pixels != 0 && measured_active_width != {6'd0,active_pixels};
wire h_offset_bad = lhbl_rise && have_h_offset && measured_hs_period != {6'd0,hs_to_active};
wire v_offset_bad = lvbl_rise && have_v_offset &&
                    (frame_y + (hs_rise ? 9'd1 : 9'd0) != v_offset_line_l ||
                     (hs_rise ? 10'd0 : measured_hs_period[9:0]) != v_offset_pixel_l ||
                     (hs_rise ? 13'd0 : measured_h_offset_clks[12:0]) != vs_to_active_clks);
wire active_overlap_bad = lvbl_rise && active_open;
wire active_end_bad = lvbl_fall && !active_open;
wire line_timeout_bad = have_lhbl && line_pixels != 0 && line_age > line_pixels + 1'b1;
wire hs_timeout_bad = have_hs && line_pixels != 0 && hs_age > {line_pixels,3'b000} + 13'd8;
wire frame_timeout_bad = hs_rise && have_vs && frame_lines != 0 && lines_since_vs > frame_lines + 1'b1;
wire frame_period_bad = vs_rise && have_vs && frame_lines != 0 && lines_since_vs != frame_lines;
wire active_height_bad = lvbl_fall && active_lines != 0 && frame_y + (hs_rise ? 9'd1 : 9'd0) - active_line_start != active_lines;
wire active_timeout_bad = hs_rise && active_open && active_lines != 0 && frame_y - active_line_start > active_lines + 1'b1;
wire raster_fault = pxl_period_bad | pxl2_period_bad | pxl_timeout_bad | pxl2_timeout_bad |
                    hs_phase_bad | lhbl_phase_bad | hs_period_bad | lhbl_period_bad |
                    active_width_bad | h_offset_bad | v_offset_bad | active_overlap_bad |
                    active_end_bad | line_timeout_bad | hs_timeout_bad | frame_timeout_bad |
                    frame_period_bad | active_height_bad | active_timeout_bad;

assign x = lhbl_rise ? 10'd0 : x_count;
assign y = lvbl_rise ? 9'd0 :
           lhbl_rise && lvbl ? (line_zero_pending ? 9'd0 : y_count + 1'd1) : y_count;

always @(posedge clk) begin
    if( rst ) begin
        x_count           <= 0;
        y_count           <= 0;
        frame_y           <= 0;
        line_start        <= 0;
        frame_start       <= 0;
        h_active_start    <= 0;
        h_active_end      <= 0;
        v_active_start    <= 0;
        v_active_end      <= 0;
        geometry_valid    <= 0;
        locked            <= 0;
        timing_change     <= 0;
        phase_error       <= 0;
        line_pixels       <= 0;
        active_pixels     <= 0;
        frame_lines       <= 0;
        active_lines      <= 0;
        hs_to_active      <= 0;
        vs_to_active_line <= 0;
        vs_to_active_pixel<= 0;
        hs_to_active_clks <= 0;
        vs_to_active_clks <= 0;
        pixel_stamp       <= 0;
        clk_stamp        <= 0;
        last_line_stamp   <= 0;
        last_active_stamp <= 0;
        last_hs_stamp     <= 0;
        last_hs_clk       <= 0;
        lines_since_vs    <= 0;
        active_line_start <= 0;
        good_lines        <= 0;
        good_frames       <= 0;
        pxl_age           <= 0;
        pxl2_age          <= 0;
        lhbl_phase        <= 0;
        hs_phase          <= 0;
        line_age          <= 0;
        hs_age            <= 0;
        pxl_missing       <= 0;
        pxl2_missing      <= 0;
        have_lhbl         <= 0;
        have_active       <= 0;
        have_hs           <= 0;
        have_vs           <= 0;
        have_pxl          <= 0;
        have_pxl2         <= 0;
        have_lhbl_phase   <= 0;
        have_hs_phase     <= 0;
        have_frame        <= 0;
        have_active_width <= 0;
        line_width_ok     <= 0;
        active_width_ok   <= 0;
        active_open       <= 0;
        have_h_offset     <= 0;
        have_v_offset     <= 0;
        line_zero_pending <= 0;
        v_offset_line_l   <= 0;
        v_offset_pixel_l  <= 0;
        hs_l              <= hs;
        vs_l              <= vs;
        lhbl_l            <= lhbl;
        lvbl_l            <= lvbl;
    end else begin
        hs_l          <= hs;
        vs_l          <= vs;
        lhbl_l        <= lhbl;
        lvbl_l        <= lvbl;
        line_start    <= 1'b0;
        frame_start   <= 1'b0;
        h_active_start <= 1'b0;
        h_active_end   <= 1'b0;
        v_active_start <= 1'b0;
        v_active_end   <= 1'b0;
        timing_change <= 1'b0;
        phase_error   <= 1'b0;
        clk_stamp <= clk_stamp + 1'd1;
        if( pxl_cen ) pixel_stamp <= pixel_stamp + 1'd1;
        if( pxl_cen ) begin
            if( have_pxl && pxl_age != 4'd7 ) begin
                phase_error    <= 1'b1;
                timing_change  <= geometry_valid;
                geometry_valid <= 1'b0;
                locked         <= 1'b0;
                good_lines     <= 0;
                good_frames    <= 0;
            end
            pxl_age  <= 0;
            have_pxl <= 1'b1;
            pxl_missing <= 0;
        end else if( pxl_age != 4'hf ) begin
            pxl_age <= pxl_age + 1'd1;
        end
        if( have_pxl && pxl_age >= 4'd8 && !pxl_missing ) begin
            phase_error <= 1'b1;
            pxl_missing <= 1'b1;
        end
        if( pxl2_cen ) begin
            if( have_pxl2 && pxl2_age != 4'd3 ) begin
                phase_error    <= 1'b1;
                timing_change  <= geometry_valid;
                geometry_valid <= 1'b0;
                locked         <= 1'b0;
                good_lines     <= 0;
                good_frames    <= 0;
            end
            pxl2_age  <= 0;
            have_pxl2 <= 1'b1;
            pxl2_missing <= 0;
        end else if( pxl2_age != 4'hf ) begin
            pxl2_age <= pxl2_age + 1'd1;
        end
        if( have_pxl2 && pxl2_age >= 4'd4 && !pxl2_missing ) begin
            phase_error <= 1'b1;
            pxl2_missing <= 1'b1;
        end
        if( hs_rise ) hs_age <= 0;
        else if( hs_age != 13'h1fff ) hs_age <= hs_age + 1'd1;

        if( lhbl_rise ) x_count <= pxl_cen ? 10'd1 : 10'd0;
        else if( pxl_cen && lhbl ) x_count <= x_count + 1'd1;
        if( lvbl_rise ) begin
            y_count <= 0;
            line_zero_pending <= !lhbl;
        end else if( lhbl_rise && lvbl ) begin
            if( line_zero_pending ) begin
                y_count <= 0;
                line_zero_pending <= 0;
            end else y_count <= y_count + 1'd1;
        end

        if( hs_rise ) begin
            line_start <= 1'b1;
            frame_y <= frame_y + 1'd1;
            lines_since_vs <= lines_since_vs + 1'd1;
            if( have_hs ) begin
                if( measured_hs_period != {6'd0,line_pixels} && line_pixels != 0 ) begin
                    good_lines  <= 0;
                    good_frames <= 0;
                    if( geometry_valid ) begin
                        timing_change  <= 1'b1;
                        geometry_valid <= 1'b0;
                        locked         <= 1'b0;
                        good_lines     <= 0;
                        good_frames    <= 0;
                    end
                end
            end
            if( have_vs && frame_lines != 0 && lines_since_vs > frame_lines + 1'b1 ) begin
                if( geometry_valid ) timing_change <= 1'b1;
                geometry_valid <= 1'b0;
                locked         <= 1'b0;
                good_frames    <= 0;
            end
            last_hs_stamp <= pixel_stamp;
            last_hs_clk   <= clk_stamp;
            have_hs       <= 1'b1;
            if( !have_hs_phase ) begin
                hs_phase      <= pxl_age;
                have_hs_phase <= 1'b1;
            end else if( hs_phase != pxl_age ) begin
                phase_error    <= 1'b1;
                hs_phase       <= pxl_age;
                timing_change  <= geometry_valid;
                geometry_valid <= 1'b0;
                locked         <= 1'b0;
                good_frames    <= 0;
            end
        end

        if( vs_rise ) begin
            frame_start    <= 1'b1;
            frame_y        <= 0;
            lines_since_vs <= hs_rise ? 9'd1 : 9'd0;
            if( have_vs ) begin
                frame_lines <= lines_since_vs;
                if( lines_since_vs != frame_lines && frame_lines != 0 ) begin
                    if( geometry_valid ) begin
                        timing_change  <= 1'b1;
                        geometry_valid <= 1'b0;
                        locked         <= 1'b0;
                        good_frames    <= 0;
                    end
                end else if( good_frames != 2'b11 ) begin
                    good_frames <= good_frames + 1'd1;
                end
            end
            have_vs <= 1'b1;
        end

        if( lhbl_rise ) begin
            h_active_start <= 1'b1;
            line_age <= 0;
            if( have_lhbl ) begin
                line_pixels <= measured_line_period[9:0];
                if( measured_line_period == {6'd0,line_pixels} && line_pixels != 0 && active_width_ok ) begin
                    if( good_lines != 3'd7 ) good_lines <= good_lines + 1'd1;
                    line_width_ok <= 1'b1;
                end else begin
                    good_lines    <= 0;
                    line_width_ok <= 1'b0;
                    if( geometry_valid ) begin
                        timing_change  <= 1'b1;
                        geometry_valid <= 1'b0;
                        locked         <= 1'b0;
                        good_frames    <= 0;
                    end
                end
            end
            last_line_stamp <= pixel_stamp;
            have_lhbl       <= 1'b1;
            hs_to_active <= measured_hs_period[9:0];
            hs_to_active_clks <= measured_h_offset_clks[12:0];
            if( have_h_offset && measured_hs_period != {6'd0,hs_to_active} ) begin
                good_lines <= 0;
                if( geometry_valid ) timing_change <= 1'b1;
                geometry_valid <= 1'b0;
                locked         <= 1'b0;
                good_frames    <= 0;
            end
            have_h_offset <= 1'b1;
            if( !have_lhbl_phase ) begin
                lhbl_phase      <= pxl_age;
                have_lhbl_phase <= 1'b1;
            end else if( lhbl_phase != pxl_age ) begin
                phase_error    <= 1'b1;
                lhbl_phase     <= pxl_age;
                timing_change  <= geometry_valid;
                geometry_valid <= 1'b0;
                locked         <= 1'b0;
                good_lines     <= 0;
                good_frames    <= 0;
            end
        end else if( pxl_cen && line_age != 10'h3ff ) begin
            line_age <= line_age + 1'd1;
        end

        if( lhbl_rise ) begin
            last_active_stamp <= pixel_stamp;
            have_active       <= 1'b1;
        end
        if( lhbl_fall && have_active ) begin
            h_active_end <= 1'b1;
            active_pixels <= measured_active_width[9:0];
            if( measured_active_width == {6'd0,active_pixels} && active_pixels != 0 ) begin
                active_width_ok <= 1'b1;
            end else begin
                active_width_ok <= 1'b0;
                good_lines      <= 0;
                if( geometry_valid ) begin
                    timing_change  <= 1'b1;
                    geometry_valid <= 1'b0;
                    locked         <= 1'b0;
                    good_frames    <= 0;
                end
            end
            have_active_width <= 1'b1;
        end

        if( lvbl_rise ) begin
            v_active_start    <= 1'b1;
            active_line_start <= frame_y + (hs_rise ? 9'd1 : 9'd0);
            vs_to_active_line <= frame_y + (hs_rise ? 9'd1 : 9'd0);
            vs_to_active_pixel<= hs_rise ? 10'd0 : measured_hs_period[9:0];
            vs_to_active_clks <= hs_rise ? 13'd0 : measured_h_offset_clks[12:0];
            if( have_v_offset && (frame_y + (hs_rise ? 9'd1 : 9'd0) != v_offset_line_l ||
                (hs_rise ? 10'd0 : measured_hs_period[9:0]) != v_offset_pixel_l ||
                (hs_rise ? 13'd0 : measured_h_offset_clks[12:0]) != vs_to_active_clks) ) begin
                good_frames    <= 0;
                if( geometry_valid ) timing_change <= 1'b1;
                geometry_valid <= 1'b0;
                locked         <= 1'b0;
            end
            v_offset_line_l  <= frame_y + (hs_rise ? 9'd1 : 9'd0);
            v_offset_pixel_l <= hs_rise ? 10'd0 : measured_hs_period[9:0];
            have_v_offset   <= 1'b1;
            if( active_open ) begin
                if( geometry_valid ) timing_change <= 1'b1;
                geometry_valid <= 1'b0;
                locked         <= 1'b0;
                good_frames    <= 0;
            end
            active_open <= 1'b1;
        end
        if( lvbl_fall ) begin
            v_active_end <= 1'b1;
            active_lines <= frame_y + (hs_rise ? 9'd1 : 9'd0) - active_line_start;
            if( have_frame && frame_y + (hs_rise ? 9'd1 : 9'd0) - active_line_start == active_lines && active_lines != 0 ) begin
                if( good_frames != 0 && good_lines >= 3'd3 && line_width_ok && active_width_ok && have_h_offset && have_v_offset ) begin
                    geometry_valid <= 1'b1;
                    locked         <= 1'b1;
                end
            end else if( active_lines != 0 ) begin
                if( geometry_valid ) timing_change <= 1'b1;
                geometry_valid <= 1'b0;
                locked         <= 1'b0;
                good_frames    <= 0;
            end
            have_frame <= 1'b1;
            active_open <= 1'b0;
        end

        if( have_lhbl && line_pixels != 0 && line_age > line_pixels + 1'b1 ) begin
            if( locked ) begin
                timing_change  <= 1'b1;
                geometry_valid <= 1'b0;
                locked         <= 1'b0;
                good_lines     <= 0;
                good_frames    <= 0;
            end
        end
        if( raster_fault ) begin
            if( geometry_valid || locked ) timing_change <= 1'b1;
            geometry_valid <= 1'b0;
            locked         <= 1'b0;
            good_lines     <= 0;
            good_frames    <= 0;
        end
    end
end

endmodule
