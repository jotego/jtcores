/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-3-2020 */

// 8x8 tiles

module jtframe_credits #(
    parameter        PAGES  = 1,
                     COLW   = 4,       // bits per pixel colour component
    parameter [11:0] PAL0   = { 4'hf, 4'h0, 4'h0 },  // Red
    parameter [11:0] PAL1   = { 4'h0, 4'hf, 4'h0 },  // Green
    parameter [11:0] PAL2   = { 4'h3, 4'h3, 4'hf },  // Blue
    parameter [11:0] PAL3   = { 4'hf, 4'hf, 4'hf },  // White
    parameter        BLKPOL = 1'b1, // Blanking polarity
    parameter        SPEED  = 2     // scroll speed
) (
    input               rst,
    input               clk,

    // input image
    input               pxl_cen,
    input               HB,
    input               VB,
    input               HS,
    input               VS,
    input [COLW*3-1:0]  rgb_in,

    // Optional VRAM control
    input         [7:0] vram_din,
    input         [9:0] vram_addr,
    input               vram_we,
    output        [7:0] vram_dout,

    // control
    input               enable, // shows the screen and resets the scroll counter
    input               toggle, // disables the screen. Only has an effect if enable is high
    input [2:0]         vram_ctrl,
    input               fast_scroll,
    input [1:0]         rotate,

    // output image
    output reg              HB_out,
    output reg              VB_out,
    output reg              HS_out,
    output reg              VS_out,
    output reg [COLW*3-1:0] rgb_out
);

localparam VPOSW = PAGES <= 1 ? 8 :
                   (PAGES <= 2 ? 9 :
                   (PAGES <= 4 ? 10 :
                   (PAGES <= 8 ? 11 : 12)));
localparam HPOSW = 10;
localparam [12:0] MAXVISIBLE = {PAGES[4:0],8'd0};
localparam [12:0] MAXVISIBLE_13 = MAXVISIBLE;

function [71:0] page_filename;
    input integer page;
    reg [7:0] digit;
    begin
        digit = 8'd48 + (page < 10 ? page[7:0] : page[7:0] - 8'd10);
        // Leave the short name implicitly extended; a leading NUL breaks Quartus string typing for SYNFILE.
        /* verilator lint_off WIDTHEXPAND */
        page_filename = page < 10 ? {"msg",digit,".bin"} : {"msg1",digit,".bin"};
        /* verilator lint_on WIDTHEXPAND */
    end
endfunction

reg  [HPOSW-1:0]  hn;
wire [HPOSW-1:0]  hscan;
reg  [VPOSW:0]    scrpos;
reg  [8:0]        vrender;
wire [8:0]        scan_data;
wire [7:0]        font_data;
reg  [9:0]        scan_addr;
reg  [3:0]        scan_page, scan_page_addr;
wire [2:0]        font_row;
wire              visible;
reg               visible_l, visible_l2, visible_l3;
reg               last_toggle, last_enable_pxl;
reg               show, hide;
reg               pxl_valid;
reg               pxl_row7;
wire              vram_mode = vram_ctrl[0];
wire              vram_nc;

reg  [HPOSW-1:0] active_width;
reg  [8:0] active_height;
reg  [8:0] active_lines;
reg  [HPOSW-1:0] h_offset;
reg  [8:0] h_source, v_source;
reg  [8:0] h_phase, v_phase;
reg  [2:0] x_addr, x_ram, x_font;
reg  [2:0] row_addr, row_ram;
reg         row7_addr, row7_ram, row7_font;
reg  [1:0] pal_font;
reg        last_hb, last_vb;
reg  [3:0] scr_base;
wire       tate      = rotate[0];
wire       tate_flip = rotate==2'b11;
wire       hb = BLKPOL ? HB : ~HB;
wire       vb = BLKPOL ? VB : ~VB;
wire       hb_edge = hb && !last_hb;
wire       vb_edge = vb && !last_vb;
wire       vb_fall = !vb && last_vb;
wire [12:0] scroll_coord;
wire [12:0] text_y;
wire [12:0] scrpos_13 = {{(12-VPOSW){1'b0}},scrpos};
wire [7:0] text_x;
wire [7:0] h_source_direct = hn[7:0]-h_offset[7:0];
wire [7:0] v_source_flip = 8'hff-v_source[7:0];
wire [9:0] h_scale_step = 10'd256-active_width;
wire [9:0] h_scale_sum = {1'b0,h_phase}+h_scale_step;
wire [10:0] h_scale_wrap = {1'b0,h_scale_sum}-{1'b0,active_width};
wire [3:0] text_page;
wire       text_valid;
wire [8:0] page_data [0:15];
wire [8:0] page_cpu_q [0:15];
wire [8:0] vram_q = page_cpu_q[0];
reg [COLW*3-1:0] rgb_d0, rgb_d1, rgb_d2, rgb_d3;
reg [3:0] sync_d0, sync_d1, sync_d2, sync_d3;
wire hb_delayed = BLKPOL ? sync_d3[3] : ~sync_d3[3];
wire vb_delayed = BLKPOL ? sync_d3[2] : ~sync_d3[2];
wire [9:0] font_addr = {scan_data[6:0],font_row};

assign hscan = tate ? hn : hn - h_offset;
assign font_row = row_ram;
assign scroll_coord = scrpos_13 + (tate ? {3'd0,hscan} : {4'd0,vrender});
assign text_y = tate_flip ? MAXVISIBLE_13-13'd1-scroll_coord : scroll_coord;
assign text_x = tate ? (rotate[1] ? v_source[7:0] : v_source_flip) :
                (active_width<256 ? h_source[7:0] : h_source_direct);
assign text_page = text_y[11:8];
assign text_valid = scroll_coord < MAXVISIBLE_13;

generate
    genvar page;
    for(page=0;page<16;page=page+1) begin: gen_page
        if(page<PAGES) begin: gen_ram
            localparam [71:0] INIT_FILE = page_filename(page);
            wire [8:0] cpu_wdata = page==0 ? {1'b1,vram_din} : 9'd0;
            wire [9:0] cpu_waddr = page==0 ? vram_addr : 10'd0;
            wire       cpu_we    = page==0 ? vram_we : 1'b0;

            jtframe_dual_ram_cen #(
                .DW        ( 9              ),
                .AW        ( 10             ),
                .SYNFILE   ( INIT_FILE      ),
                .ASCII_BIN ( 1              )
            ) u_msg(
                .cen0   ( 1'b1         ),
                .cen1   ( pxl_cen      ),
                .clk0   ( clk          ),
                .data0  ( cpu_wdata    ),
                .addr0  ( cpu_waddr    ),
                .we0    ( cpu_we       ),
                .q0     ( page_cpu_q[page] ),
                .clk1   ( clk          ),
                .data1  ( 9'd0         ),
                .addr1  ( scan_addr    ),
                .we1    ( 1'b0         ),
                .q1     ( page_data[page] )
            );
        end else begin: gen_empty
            assign page_cpu_q[page] = 9'd0;
            assign page_data[page]  = 9'd0;
        end
    end
endgenerate

assign scan_data = page_data[scan_page];
assign visible = pxl_valid;

always @(posedge clk) begin
    if(rst) begin
        scan_page  <= 0;
        x_ram      <= 0;
        x_font     <= 0;
        row_ram    <= 0;
        row7_ram   <= 0;
        row7_font  <= 0;
        pal_font   <= 0;
        visible_l2 <= 0;
        visible_l3 <= 0;
    end else if(pxl_cen) begin
        scan_page  <= scan_page_addr;
        x_ram      <= x_addr;
        x_font     <= x_ram;
        row_ram    <= row_addr;
        row7_ram   <= row7_addr;
        row7_font  <= row7_ram;
        pal_font   <= scan_data[8:7];
        visible_l2 <= visible_l;
        visible_l3 <= visible_l2;
    end
end

jtframe_ram #(.DW(8),.AW(10),.SYNFILE("font0.hex"),.CEN_RD(1)) u_font(
    .clk    ( clk       ),
    .cen    ( pxl_cen   ),
    .data   ( 8'd0      ),
    .addr   ( font_addr ),
    .we     ( 1'b0      ),
    .q      ( font_data )
);

reg  [2:0]      pxl;

localparam MULTIPAGE = PAGES > 1;
assign vram_dout = vram_q[7:0];
assign vram_nc   = vram_q[8];

always @(posedge clk) begin
    if(rst) begin
        hn            <= 0;
        scrpos        <= 0;
        vrender       <= 0;
        active_width  <= 384;
        active_height <= 224;
        active_lines  <= 0;
        h_offset      <= 64;
        h_source      <= 0;
        v_source      <= 0;
        h_phase       <= 0;
        v_phase       <= 0;
        last_enable_pxl <= 0;
        scr_base      <= 0;
        last_hb       <= 1'b0;
        last_vb       <= 1'b0;
        scan_addr     <= 0;
        scan_page_addr<= 0;
        visible_l     <= 0;
        x_addr        <= 0;
        row_addr      <= 0;
        row7_addr     <= 0;
        pxl_valid     <= 0;
        pxl_row7      <= 0;
    end else if(pxl_cen) begin
        last_hb <= hb;
        last_vb <= vb;
        last_enable_pxl <= enable;
            hn <= hb ? 0 : hn+1'b1;
            if(hb_edge) begin
                active_width <= hn;
                if(!vb) begin
                    active_lines <= active_lines+1'b1;
                    if(tate && active_height<256) begin
                        if(v_phase+(256-active_height)>=active_height) begin
                            v_phase  <= v_phase+(256-active_height)-active_height;
                            v_source <= v_source+9'd2;
                        end else begin
                            v_phase  <= v_phase+(256-active_height);
                            v_source <= v_source+1'b1;
                        end
                    end else if(tate) v_source <= v_source+1'b1;
                end
                if(!vb) vrender <= vrender+1'b1;
            end
            if(vb_edge) begin
                active_height <= active_lines + (hb_edge ? 9'd1 : 9'd0);
                if(MULTIPAGE) begin
                    if(scr_base==SPEED || fast_scroll) begin
                        scrpos <= scrpos_13>=MAXVISIBLE_13 ? 0 : scrpos+1'b1;
                        scr_base <= 0;
                    end else scr_base <= scr_base+1'b1;
                end
            end
            if(vb_fall) begin
                active_lines <= 0;
                vrender      <= 0;
                v_source     <= 0;
                v_phase      <= 0;
            end
            if(enable && !last_enable_pxl) begin
                scrpos   <= 0;
                scr_base <= 0;
            end
            if(vram_mode) scrpos <= 0;

            if(hb) begin
                h_source <= 0;
                h_phase  <= 0;
            end else if(active_width<256 && !tate) begin
                if({1'b0,h_scale_sum}>={1'b0,active_width}) begin
                    h_phase  <= h_scale_wrap[8:0];
                    h_source <= h_source+9'd2;
                end else begin
                    h_phase  <= h_scale_sum[8:0];
                    h_source <= h_source+1'b1;
                end
            end else if(!tate) begin
                h_source <= 0;
                h_phase  <= 0;
            end else begin
                h_source <= 0;
            end
            if(hb_edge && active_width>=256 && !tate)
                h_offset <= (active_width-256)>>1;

            scan_addr  <= { text_y[7:3], text_x[7:3] };
            scan_page_addr <= text_page;
            x_addr         <= text_x[2:0];
            row_addr       <= text_y[2:0];
            row7_addr      <= text_y[7];
            visible_l  <= text_valid && (tate || active_width<256 ||
                          (hn>=h_offset && hn<h_offset+256));

            if(tate) begin
                pxl       <= { pal_font, font_data[~x_font] };
                pxl_valid <= visible_l3;
                pxl_row7  <= row7_font;
            end else begin
                pxl       <= { pal_font, font_data[~x_font] };
                pxl_valid <= visible_l3;
                pxl_row7  <= row7_font;
            end
    end
end

/////////////////////////////////////////////////////////////////////////////
// Colour Mixer
// Merge the new image with the old
localparam R1 = COLW*3-1;
localparam R0 = COLW*2;
localparam G1 = COLW*2-1;
localparam G0 = COLW;
localparam B1 = COLW-1;
localparam B0 = 0;

wire [COLW*3-1:0] dim = { 1'b0, rgb_d3[R1:R0+1], 1'b0, rgb_d3[G1:G0+1], 1'b0, rgb_d3[B1:B0+1] };

// COLW must be >= 4
reg [7:0] b;

function [COLW*3-1:0] extend;
    input [11:0] rgb4;
    begin
        b = {2{rgb4[3:0]}};
        extend[COLW*3-1-:8] = {2{rgb4[11:8]}};
        extend[COLW*2-1-:8] = {2{rgb4[ 7:4]}};
        extend[COLW*1-1: 0] = b[7-:COLW];
    end
endfunction

always @(posedge clk) begin
    if( rst ) begin
        show        <= 0;
        hide        <= 0;
        last_toggle <= 0;
    end else begin
        last_toggle <= toggle;
        if( enable ) begin
            if( vram_mode ) begin
                show <= 1;
                hide <= 0;
            end else begin
                show <= ~hide;
                if( toggle && !last_toggle ) begin
                    hide <= ~hide;
                end
            end
        end else show <= 0;
    end
end

always @(posedge clk) if(pxl_cen) begin
    if( !show )
        rgb_out <= rgb_d3;
    else begin
        if( !pxl[0] || !visible ) begin
            if( vram_ctrl[0] ) begin
                rgb_out <= (pxl_row7 ? vram_ctrl[2] : vram_ctrl[1]) ? dim : rgb_d3;
            end else begin
                rgb_out <= dim;
            end
        end else begin
            case( pxl[2:1] )
                2'd0: rgb_out <= extend(PAL0);
                2'd1: rgb_out <= extend(PAL1);
                2'd2: rgb_out <= extend(PAL2);
                2'd3: rgb_out <= extend(PAL3);
            endcase
        end
        if( vb_delayed || hb_delayed ) rgb_out <= 0;
    end
end

always @(posedge clk) begin
    if(rst) begin
        rgb_d0  <= 0;
        rgb_d1  <= 0;
        rgb_d2  <= 0;
        rgb_d3  <= 0;
        sync_d0 <= 0;
        sync_d1 <= 0;
        sync_d2 <= 0;
        sync_d3 <= 0;
        HB_out <= 0;
        VB_out <= 0;
        HS_out <= 0;
        VS_out <= 0;
    end else if(pxl_cen) begin
        { HB_out, VB_out, HS_out, VS_out } <= sync_d3;
        rgb_d0  <= rgb_in;
        rgb_d1  <= rgb_d0;
        rgb_d2  <= rgb_d1;
        rgb_d3  <= rgb_d2;
        sync_d0 <= {HB,VB,HS,VS};
        sync_d1 <= sync_d0;
        sync_d2 <= sync_d1;
        sync_d3 <= sync_d2;
    end
end

endmodule
