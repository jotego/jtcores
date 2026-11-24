/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-11-2026 */

// MiSTer regression capture. One clock: clk is clk_sys = clk_rom = DDRAM_CLK.
// The only clock crossing is the f2sdram bridge behind DDRAM_*, so ordinary
// STA covers this module.
//
// - Main arms each capture with CAP_ARM (0x91, 2 bytes): the target frame.
//   ARM also releases a frozen slot; a target of 0 only releases it.
// - Frame numbers come from the CAB replay: the picture drawn during
//   interval i is frame i+1, complete at the game's LVBL falling edge. After
//   the last interval the count goes on, so a missed last frame shows too.
//   A new CAB session (state ARMED) clears it.
// - While armed, every native frame (the arcade_video output, before the OSD
//   and the HDMI scaler) is packed as RGB888, rows padded to 256 bytes, and
//   written to a 2 MB slot in the core DDR region, pixels starting 256 bytes
//   into the slot. A frame starts at the first DE after a gap longer than 1.5
//   lines in the video stream itself. When the target frame has been written
//   whole, writing stops and the slot stays frozen, while the game keeps
//   running, until the next ARM. Any problem with the target frame leaves
//   ready low and Main sees the frame number pass the target.
// - CAP_STATUS (0x90): 0xCA50, 3, {ready, frame}, {video_ok, target}.
//   frame is the last complete frame of the session; it reaches the target
//   only once the slot is ready, or once the target frame is known missed.
// - CAP_RESULT (0x92): JTC3 descriptor 0x544A, 0x3343, frame, width, height,
//   slot base in 2 MB units, GFW1 pixel hash low and high words.
module jtframe_mister_capture #(
    // the slot must be 2 MB, aligned to its size
    parameter [31:0] BASE    = 32'h3FE0_0000,
    parameter        FIFO_AW = 9
)(
    input              rst,
    input              clk,
    // HPS transactions from jtframe_mister_uio
    input              uio_finish,
    input       [15:0] uio_command,
    input       [ 6:0] uio_words,
    input       [14:0] uio_payload,
    input              uio_bad_word,
    output     [127:0] uio_caps,
    output     [127:0] uio_result,
    // CAB replay
    input              lvbl,
    input              cab_frame_start,
    input       [14:0] cab_frame_index,
    input       [ 2:0] cab_state,
    // native video
    input              pxl_cen,
    input       [ 7:0] red,
    input       [ 7:0] green,
    input       [ 7:0] blue,
    input              de,
    input              video_ok,    // native, untransformed video and free DDR
    // DDR video client
    output             ddr_sel,
    output             ddr_lock,    // a burst is open: keep the DDR port
    input              ddr_busy,
    output      [ 7:0] ddr_burstcnt,
    output      [28:0] ddr_addr,
    output             ddr_we,
    output      [ 7:0] ddr_be,
    output      [63:0] ddr_din
);

localparam [15:0] CAP_ARM=16'h0091;
localparam [ 2:0] CAB_ARMED=1;
localparam        WW     = 18;               // words in a slot
localparam [WW-1:0] MAX_WORDS = (1<<WW) - 32; // minus the 256-byte offset
localparam [10:0] SLOT_HI = BASE[31:21];

// ---------------------------------------------------------------- state
reg  [14:0] target, frame;
reg         armed, hit, ready;

// tags
reg         lvbl_l, started, tag_pend;
reg  [14:0] iv_index, tag_q;

// video front end
reg         de_l, wr_frame, geom_bad, pad;
reg  [12:0] since_rise, line_len;   // in pixels, from one DE rise to the next
reg  [11:0] xcnt, width;
reg  [12:0] rows;
// RGB888 packing: 8 pixels fill 3 words. Slot k holds pixel k of the group;
// only the parts not pushed yet are kept.
reg  [23:0] p0, p1, p3, p4, p6;
reg  [ 7:0] p2h;
reg  [15:0] p5h;
reg  [ 2:0] slot;
reg  [ 4:0] row_words;
reg  [WW-1:0] frame_words;
reg  [31:0] hash;

// captured frame
reg  [11:0] cap_w;
reg  [12:0] cap_h;

// FIFO and DDR writer
reg  [FIFO_AW-1:0] wr_ptr, wr_ptr_d, rd_ptr;
reg         push, push_first, first_pend, flush;
reg  [63:0] push_data;
wire [64:0] fifo_q;
reg         burst;
reg  [ 4:0] beat;
reg  [WW-6:0] bidx;         // 256-byte block in the slot; pixels start at 1
wire [FIFO_AW-1:0] fill   = wr_ptr   - rd_ptr;
wire [FIFO_AW-1:0] fill_d = wr_ptr_d - rd_ptr;
wire        fifo_full = fill >= {FIFO_AW{1'b1}}-{{FIFO_AW-2{1'b0}},2'd2};
wire        pop       = burst && !ddr_busy;
wire        quiet     = !burst && fill==0 && !pad && !push && !flush;

function [31:0] gfw1(input [31:0] h, input [31:0] w);
    gfw1 = {h[30:0],1'b0} ^ (h[31] ? 32'h0040_0007 : 32'd0) ^ w;
endfunction

// ------------------------------------------------------------- HPS words
assign uio_caps   = {64'd0, video_ok, target, ready, frame, 16'd3, 16'hCA50};
assign uio_result = {hash, 5'd0, SLOT_HI, 3'd0, cap_h, 4'd0, cap_w,
                     1'b0, target, 16'h3343, 16'h544A};

// ------------------------------------------------------------- DDR port
assign ddr_sel      = burst || fill!=0 || wr_frame;
assign ddr_lock     = burst;
assign ddr_we       = burst;
assign ddr_burstcnt = 8'd32;
assign ddr_be       = 8'hff;
assign ddr_addr     = {SLOT_HI, bidx, 5'd0};
assign ddr_din      = fifo_q[63:0];

jtframe_dual_ram #(.DW(65),.AW(FIFO_AW)) u_fifo(
    .clk0   ( clk                   ),
    .data0  ( {push_first,push_data}),
    .addr0  ( wr_ptr                ),
    .we0    ( push                  ),
    .q0     (                       ),
    .clk1   ( clk                   ),
    .data1  ( 65'd0                 ),
    .addr1  ( pop ? rd_ptr+1'd1 : rd_ptr ),
    .we1    ( 1'b0                  ),
    .q1     ( fifo_q                )
);

// ------------------------------------------------------------- video
wire        vb_start = lvbl_l && !lvbl;     // the game's vertical blank starts
wire        de_rise  = pxl_cen &&  de && !de_l;
wire        de_fall  = pxl_cen && !de &&  de_l;
// first pixel of a frame: the line before it ended over 1.5 lines ago
wire        fs       = de_rise && line_len!=0 &&
                       since_rise > line_len + {1'b0,line_len[12:1]};
wire        pixel    = pxl_cen && de;
wire        prev_ok  = wr_frame && !geom_bad && !pad && rows!=0 && !rows[12] && width!=0;
wire        fs_match = armed && tag_pend && tag_q==target && prev_ok;
wire        fs_write = armed && !fs_match && !flush && video_ok;
// word under assembly; while padding, pixels not received yet are zero
wire [23:0] pixg     = pad ? 24'd0 : {blue,green,red};
wire [63:0] word     = slot<=2 ? {pixg[15:0], p1, p0} :
                       slot<=5 ? {pixg[ 7:0], p4, p3, p2h} :
                                 {pixg, p6, p5h};
// one word enters the FIFO per cycle: a completed pixel word, the partial
// word at the end of a row, or zero padding up to the 256-byte pitch
wire        pix_wr   = pixel && !fs && wr_frame && !pad;
wire        pix_push = pix_wr && (slot==2 || slot==5 || slot==7);
wire        pad_push = pad && !de && (slot!=0 || row_words!=0);
wire        push_now = pix_push || pad_push;
wire [63:0] push_d   = pad && slot==0 ? 64'd0 : word;
wire        arm_cmd  = uio_finish && uio_command==CAP_ARM && uio_words==7'd3 && !uio_bad_word;

// the frame being written is dropped and its words in the FIFO are flushed
task drop;
begin
    wr_frame <= 0;
    pad      <= 0;
    flush    <= 1;
end
endtask

always @(posedge clk) begin
    if(rst) begin
        target <= 0; frame <= 0; cap_w <= 0; cap_h <= 0;
        armed <= 0; hit <= 0; ready <= 0;
        lvbl_l <= 0; started <= 0; tag_pend <= 0;
        de_l <= 0; wr_frame <= 0; geom_bad <= 0; pad <= 0;
        since_rise <= 0; line_len <= 0;
        rows <= 0; slot <= 0; row_words <= 0; frame_words <= 0; hash <= 0;
        wr_ptr <= 0; wr_ptr_d <= 0; rd_ptr <= 0;
        push <= 0; push_first <= 0; first_pend <= 0; flush <= 0;
        burst <= 0; beat <= 0; bidx <= 0;
    end else begin
        push       <= 0;
        push_first <= 0;
        wr_ptr_d   <= wr_ptr;
        lvbl_l     <= lvbl;
        if(push) begin
            wr_ptr <= wr_ptr + 1'd1;
            hash   <= gfw1(gfw1(hash, push_data[31:0]), push_data[63:32]);
        end

        // ---- CAB intervals: the picture of interval i is frame i+1
        if(cab_frame_start) begin
            started  <= 1;
            iv_index <= cab_frame_index;
        end
        if(vb_start && started) begin
            tag_pend <= 1;
            tag_q    <= iv_index + 15'd1;
            iv_index <= iv_index + 15'd1;
        end

        // ---- video front end
        if(pxl_cen) begin
            de_l <= de;
            if(!(&since_rise)) since_rise <= since_rise + 1'd1;
        end
        if(de_rise) begin
            // a wrong value after reset or a frame gap is replaced by the
            // next line period, so frame detection settles within two lines
            since_rise <= 13'd1;
            line_len   <= since_rise;
            xcnt       <= 0;
            rows       <= fs ? 13'd1 : rows + 1'd1;
        end
        if(pixel) xcnt <= (de_rise ? 12'd0 : xcnt) + 1'd1;
        if(de_fall) begin
            if(rows==1) width <= xcnt;
            else if(xcnt != width) geom_bad <= 1;
            if(wr_frame) pad <= 1;
        end

        // pixel packing
        if(fs) begin
            geom_bad <= 0;
            if(fs_write) begin
                row_words <= 0; frame_words <= 0;
                hash <= 0;
                first_pend <= 1; // its first word resets the DDR address
            end
        end
        if(pixel && (fs ? fs_write : wr_frame)) begin
            if(pad && !fs) begin
                drop;           // row padding did not finish in time
            end else begin
                slot <= fs ? 3'd1 : slot+1'd1;
                case(fs ? 3'd0 : slot)
                    0: begin p0 <= {blue,green,red}; p1 <= 0; end
                    1: p1 <= {blue,green,red};
                    2: begin p2h <= blue; p3 <= 0; p4 <= 0; end
                    3: p3 <= {blue,green,red};
                    4: p4 <= {blue,green,red};
                    5: begin p5h <= {blue,green}; p6 <= 0; end
                    6: p6 <= {blue,green,red};
                    default:;
                endcase
            end
        end
        if(pad && !de) begin
            slot <= 0;
            if(!pad_push) pad <= 0;
        end
        if(push_now) begin
            push        <= 1;
            push_data   <= push_d;
            push_first  <= first_pend;
            first_pend  <= 0;
            row_words   <= row_words + 1'd1;
            frame_words <= frame_words + 1'd1;
            // a FIFO overrun, or a frame larger than the slot
            if(fifo_full || frame_words >= MAX_WORDS-1'd1) drop;
        end
        if(wr_frame && !video_ok) drop;

        // ---- DDR writer
        if(!burst && flush && !push && wr_ptr_d==wr_ptr) begin
            rd_ptr <= wr_ptr;
            flush  <= 0;
        end else if(!burst && fill_d>=32) begin
            burst <= 1;
            beat  <= 0;
            bidx  <= fifo_q[64] ? {{(WW-6){1'b0}},1'b1} : bidx + 1'd1;
        end
        if(pop) begin
            rd_ptr <= rd_ptr + 1'd1;
            beat   <= beat + 1'd1;
            if(&beat) burst <= 0;
        end

        // ---- frame start: the tagged frame has been written whole, or not
        if(fs) begin
            tag_pend <= 0;
            if(fs_match) begin
                armed <= 0;
                hit   <= 1;
                cap_w <= width;
                cap_h <= rows;
            end else if(tag_pend && !hit) begin
                frame <= tag_q;
            end
            wr_frame <= fs_write;
        end
        // the last words of the target frame are in DDR
        if(hit && quiet) begin
            hit   <= 0;
            ready <= 1;
            frame <= target;
        end

        // ---- ARM releases the slot and sets the next target
        if(arm_cmd) begin
            target <= uio_payload;
            armed  <= uio_payload!=0;
            hit    <= 0;
            ready  <= 0;
        end
        if(cab_state==CAB_ARMED) begin
            started  <= 0;
            tag_pend <= 0;
            frame    <= 0;
        end
    end
end

endmodule
