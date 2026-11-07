/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-3-2026 */

module jtcps3_vtimer(
    input               clk,
    input               std_cen, std2_cen,
    input       [ 9:0]  h_sync_width,
    input       [ 9:0]  h_blank_end,
    input       [ 9:0]  h_screen_end,
    input       [ 9:0]  h_total_end,
    input       [ 9:0]  v_sync_end,
    input       [ 9:0]  v_blank_end,
    input       [ 9:0]  v_screen_end,
    input       [ 9:0]  v_total_end,
    input       [ 2:0]  pxl_div,

    output              pxl2_cen, pxl_cen,
    output  reg         lhbl,
    output  reg         lvbl,
    output  reg         hs,
    output  reg         vs,
    output  reg         line_start,
    output  reg         frame_start,
    output  reg [ 9:0]  hdump,
    output  reg [ 9:0]  vdump
);

reg  [9:0] hpos, vpos;
reg [11:0] h_period, v_period,
           h_blank_start, h_blank_end_ext,
           h_sync_start, h_sync_end;
reg [ 9:0] h_sync_width_fix;
reg [10:0] hdump_start, h_visible_wrap;
reg        line_vactive, next_vactive, next_vsync;

localparam [10:0] HDUMP_LEAD    = 11'd8;
localparam [10:0] H_VISIBLE_MAX = 11'd384;
localparam [ 2:0] PXL_REG_STD   = 3'd3;
localparam [ 2:0] PXL_REG_WIDE  = 3'd5;

wire [11:0] nx_h_period      = { 2'd0, h_total_end  } + 12'd1;
wire [11:0] nx_v_period      = { 2'd0, v_total_end  } + 12'd2;
wire [ 9:0] v_total_last     = v_total_end + 10'd1;
wire [11:0] h_visible_raw = h_screen_end >= h_blank_end ?
    ({ 2'd0, h_screen_end } - { 2'd0, h_blank_end }) :
    ({ 2'd0, h_screen_end } + nx_h_period - { 2'd0, h_blank_end });
wire [11:0] h_visible_clamped = h_visible_raw > { 1'b0, H_VISIBLE_MAX } ?
    { 1'b0, H_VISIBLE_MAX } : h_visible_raw;
wire [11:0] nx_h_blank_start_unwrapped = { 2'd0, h_blank_end } + h_visible_clamped;
wire [11:0] nx_h_blank_start = nx_h_blank_start_unwrapped >= nx_h_period ?
    nx_h_blank_start_unwrapped - nx_h_period : nx_h_blank_start_unwrapped;
wire [11:0] nx_h_blank_end_ext = nx_h_blank_start >= { 2'd0, h_blank_end } ?
    ({ 2'd0, h_blank_end } + nx_h_period) :
    { 2'd0, h_blank_end };
wire [10:0] nx_hdump_start = { 1'b0, h_blank_end } - HDUMP_LEAD;

wire [11:0] h_blank_width = h_blank_end_ext - h_blank_start;
wire [11:0] h_ext         = { 2'd0, hpos } < h_blank_start ? { 2'd0, hpos } + h_period : { 2'd0, hpos };

wire [19:0] hsync_x5       = { 10'd0, h_sync_width } + ({ 10'd0, h_sync_width } << 2);
wire [19:0] hsync_x2       = { 10'd0, h_sync_width } << 1;
wire [29:0] hsync_std_fix   = hsync_x5 * 10'd171; // /6 using a 10-bit reciprocal
wire [29:0] hsync_wide_fix  = hsync_x2 * 10'd341; // /3 using a 10-bit reciprocal
wire [29:0] hsync_std_round = hsync_std_fix  + 30'd512;
wire [29:0] hsync_wide_round= hsync_wide_fix + 30'd512;
wire [ 9:0] hsync_std_width = hsync_std_round[19:10];
wire [ 9:0] hsync_wide_width= hsync_wide_round[19:10];
wire [ 9:0] nx_hsync_width_fix = pxl_div == PXL_REG_STD  ? hsync_std_width  :
                                 pxl_div == PXL_REG_WIDE ? hsync_wide_width : h_sync_width;

wire [ 9:0] nx_hpos = hpos == h_total_end ? 10'd0 : (hpos + 10'd1);
wire        hb_start_evt = h_ext == h_blank_start;
wire        hb_end_evt   = h_ext == h_blank_end_ext;
wire        hs_start_evt = h_ext == h_sync_start;
wire        hs_end_evt   = h_ext == h_sync_end;
wire [ 9:0] adv_vpos = vpos == v_total_last ? 10'd0 : (vpos + 10'd1);

wire [10:0] hrender = { 1'b0, hpos } >= hdump_start ?
    ({ 1'b0, hpos } - hdump_start) :
    ({ 1'b0, hpos } + h_visible_wrap);
wire        hdump_valid = hrender < 11'd392;
wire [11:0] adv_v_ext   = adv_vpos < v_blank_end ? { 2'd0, adv_vpos } + v_period : { 2'd0, adv_vpos };
wire        adv_vactive = adv_v_ext >= { 2'd0, v_blank_end } && adv_v_ext < { 2'd0, v_screen_end };
wire        adv_vsync   = adv_vpos < v_sync_end;

// TODO: support a different clock enable for the wide screen case
assign pxl_cen = std_cen;
assign pxl2_cen = std2_cen;

initial begin
    lhbl            = 1;
    lvbl            = 0;
    hs              = 0;
    vs              = 1;
    line_start      = 0;
    frame_start     = 0;
    hpos            = 0;
    vpos            = 0;
    hdump           = 0;
    vdump           = 0;
    h_period        = 0;
    v_period        = 0;
    h_blank_start   = 0;
    h_blank_end_ext = 0;
    h_sync_width_fix= 0;
    h_sync_start    = 0;
    h_sync_end      = 0;
    hdump_start     = 0;
    h_visible_wrap  = 0;
    line_vactive    = 0;
    next_vactive    = 0;
    next_vsync      = 1;
end

always @(posedge clk) begin
    line_start  <= 0;
    frame_start <= 0;
    h_period        <= nx_h_period;
    v_period        <= nx_v_period;
    h_blank_start   <= nx_h_blank_start;
    h_blank_end_ext <= nx_h_blank_end_ext;
    h_sync_width_fix<= nx_hsync_width_fix;
    h_sync_start    <= h_blank_start + ((h_blank_width - { 2'd0, h_sync_width_fix }) >> 1);
    h_sync_end      <= h_sync_start + { 2'd0, h_sync_width_fix };
    hdump_start     <= nx_hdump_start;
    h_visible_wrap  <= ({ 1'b0, h_total_end } - nx_hdump_start) + 11'd1;
    next_vactive    <= adv_vactive;
    next_vsync      <= adv_vsync;

    if( pxl_cen ) begin
        hpos        <= nx_hpos;
        hdump       <= hdump_valid ? { 1'b0, hrender[8:0] } : 10'd0;
        if( hb_start_evt ) begin
            lhbl        <= 0;
            vpos        <= adv_vpos;
            vdump       <= adv_vpos;
            line_start  <= 1;
            frame_start <= vpos == v_total_last;
            vs          <= next_vsync;
            line_vactive<= next_vactive;
            if( !next_vactive ) lvbl <= 0;
        end else if( hb_end_evt ) begin
            lhbl <= 1;
            lvbl <= line_vactive;
        end

        if( hs_start_evt ) hs <= 1;
        if( hs_end_evt   ) hs <= 0;
    end
end

endmodule
