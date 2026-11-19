/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-11-2026 */

// MiSTer regression capture. One clock: clk is clk_sys = clk_rom = DDRAM_CLK.
// The only clock crossing is the f2sdram bridge behind DDRAM_*, so ordinary
// STA covers this module.
//
// - HPS commands arrive already framed by jtframe_mister_uio:
//   CAP_CAPS 0x90, CAP_ARM 0x91, CAP_RESULT_READ 0x92, CAP_RELEASE 0x93,
//   CAP_ABORT 0x94.
// - Native checkpoint tags come straight from the CAB replay counters:
//   checkpoint N labels the frame of interval N-1, completed at the game's
//   LVBL falling edge.
// - While a capture is armed, every native frame (the arcade_video output,
//   before the OSD and the HDMI scaler) is packed as RGB888, rows padded to
//   256 bytes, and written to a 2 MB slot in the core DDR region, pixels
//   starting 256 bytes into the slot. A frame starts at the first DE after a
//   gap longer than 1.5 lines in the video stream itself. When the frame
//   labelled with the requested
//   checkpoint has been written, writing stops and the slot stays frozen,
//   while the game keeps running, until the HPS releases it.
// - The result is the 64-byte JTC2 v3 descriptor (GFW1 pixel hash, mode bit
//   13 = core DDR slot), read one byte at a time.
module jtframe_mister_capture #(
    // the slot must be 2 MB, aligned to its size
    parameter [31:0] BASE    = 32'h3FE0_0000,
    parameter        FIFO_AW = 9
)(
    input              rst,
    input              clk,
    // HPS transactions from jtframe_mister_uio
    input       [15:0] host_word,
    input              uio_start,
    input              uio_finish,
    input              uio_active,
    input       [15:0] uio_command,
    input       [ 6:0] uio_words,
    input       [63:0] uio_payload,
    input              uio_bad_word,
    input       [ 6:0] uio_bad_index,
    output     [127:0] uio_caps,
    output             uio_result_valid,
    input       [ 5:0] result_index,
    output      [ 7:0] result_byte,
    // CAB replay
    input              lvbl,
    input              cab_frame_start,
    input       [14:0] cab_frame_index,
    input       [14:0] cab_completed,
    input       [ 2:0] cab_state,
    input       [ 7:0] cab_error,
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

localparam [15:0] CAP_CAPS=16'h0090, CAP_ARM=16'h0091, CAP_RESULT_READ=16'h0092,
                  CAP_RELEASE=16'h0093, CAP_ABORT=16'h0094;
localparam [2:0] S_IDLE=0, S_ARMED=1, S_RUN=2, S_READY=3, S_FAULT=4;
localparam [7:0] F_BAD_LENGTH=8'h01, F_BAD_WORD=8'h02, F_BAD_STATE=8'h03,
                 F_LATE=8'h04, F_LIFE=8'h05, F_MODE=8'h06, F_TAG=8'h07,
                 F_OVERRUN=8'h08, F_RELEASE=8'h0C, F_GEOM=8'h0E;
localparam [2:0] CAB_IDLE=0, CAB_ARMED=1, CAB_RUNNING=2, CAB_DONE=3, CAB_ERROR=4;
localparam [31:0] STRIDE = 32'h0020_0000;
// mode: RGB888, slot 0, progressive, native input, core DDR slot (bit 13)
localparam [31:0] MODE   = 32'h0000_2C01;
localparam        WW     = 18;               // words in a slot
localparam [WW-1:0] MAX_WORDS = (1<<WW) - 32; // minus the 256-byte offset
localparam [10:0] SLOT_HI = BASE[31:21];

// ---------------------------------------------------------------- state
reg  [ 2:0] st;
reg  [14:0] cp;             // owned checkpoint
reg  [ 7:0] fault;          // first fault, sticky until the next ARM
reg         owner, abort_pend, cancel, flush;
reg         result_valid, last_release_ok;
reg  [15:0] cmd_fresh, res_fresh;

// CAB lifecycle
reg  [ 2:0] l_state;
reg  [ 7:0] l_err;
reg         session_ready;

// tags
reg         lvbl_l, iv_active, tag_pend;
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
reg         push, push_first, first_pend;
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

// descriptor CRC
reg  [31:0] crc;
reg  [ 5:0] crc_i;
reg         crc_busy;

function [31:0] gfw1(input [31:0] h, input [31:0] w);
    gfw1 = {h[30:0],1'b0} ^ (h[31] ? 32'h0040_0007 : 32'd0) ^ w;
endfunction

function [31:0] crc8(input [31:0] c, input [7:0] d);
    integer k;
    reg [31:0] x;
    begin
        x = c ^ {24'd0,d};
        for(k=0;k<8;k=k+1) x = (x>>1) ^ (x[0] ? 32'hEDB8_8320 : 32'd0);
        crc8 = x;
    end
endfunction

// ------------------------------------------------------------ descriptor
wire [14:0] interval  = cp - 15'd1;
wire [13:0] row_bytes = {2'd0,cap_w} + {1'b0,cap_w,1'b0};
wire [ 7:0] pitch_hi  = {2'd0,row_bytes[13:8]} + {7'd0,|row_bytes[7:0]};
// frame_words and hash stay frozen from the match until the next ARM
wire [31:0] payload   = {{(29-WW){1'b0}},frame_words,3'd0};
wire [31:0] blocks    = 32'd1 + {{(37-WW){1'b0}},frame_words[WW-1:5]};
wire [511:0] desc = {
    32'h3259_4452,              // 60..63 "RDY2"
    ~crc,                       // 56..59 CRC32 of bytes 0..55
    64'd0,                      // 48..55
    hash,                       // 44..47 GFW1 pixel hash
    32'h3157_4647,              // 40..43 "GFW1"
    blocks,                     // 36..39 256-byte blocks in the slot
    MODE,                       // 32..35
    payload,                    // 28..31
    16'd0, pitch_hi, 8'd0,      // 24..27 row pitch
    3'd0, cap_h,                // 22..23
    4'd0, cap_w,                // 20..21
    STRIDE,                     // 16..19
    BASE,                       // 12..15
    1'b0, interval,             // 10..11
    1'b0, cp,                   //  8..9
    16'h0040, 16'h0002,         //  4..7 version 2, 64 bytes
    32'h3243_544A               //  0..3 "JTC2"
};
// one byte mux serves both the CRC engine and the HPS result read
wire [ 5:0] desc_i   = crc_busy ? crc_i : result_index;
wire [ 7:0] desc_b   = desc[{desc_i,3'd0} +: 8];
assign result_byte      = desc_b;
assign uio_result_valid = result_valid;

// ------------------------------------------------------------- status
wire drain_ready = (session_ready || (l_state==CAB_IDLE && l_err==0)) &&
                   st==S_IDLE && !owner && quiet && !cancel;
wire draining    = st==S_IDLE && !drain_ready;
wire owned_cmd   = uio_command>=CAP_CAPS && uio_command<=CAP_ABORT;
wire write_cmd   = owned_cmd && uio_command!=CAP_CAPS && uio_command!=CAP_RESULT_READ;
wire busy        = abort_pend || (uio_active && write_cmd);
wire [15:0] flags = { fault, 1'b0, 1'b1, draining, last_release_ok, fault!=0,
                      st==S_READY && result_valid && fault==0, owner, busy };
assign uio_caps = {16'd0, res_fresh, 16'd0, cmd_fresh, flags, 16'd64, 16'd2, 16'hCA50};

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

// ------------------------------------------------------------- tags
wire        vb_start = lvbl_l && !lvbl;     // the game's vertical blank starts
wire        tag_new  = vb_start && iv_active && cab_error==0 &&
                       (cab_state==CAB_RUNNING ||
                        (cab_state==CAB_DONE && iv_index < cab_completed));
wire [14:0] tag_cp   = iv_index + 15'd1;

// ------------------------------------------------------------- video
wire        de_rise = pxl_cen &&  de && !de_l;
wire        de_fall = pxl_cen && !de &&  de_l;
// first pixel of a frame: the line before it ended over 1.5 lines ago
wire        fs      = de_rise && line_len!=0 &&
                      since_rise > line_len + {1'b0,line_len[12:1]};
wire        pixel   = pxl_cen && de;
wire        prev_ok = wr_frame && !geom_bad && !pad && rows!=0 && !rows[12] && width!=0;
// word under assembly; while padding, pixels not received yet are zero
wire [23:0] pixg    = pad ? 24'd0 : {blue,green,red};
wire [63:0] word    = slot<=2 ? {pixg[15:0], p1, p0} :
                      slot<=5 ? {pixg[ 7:0], p4, p3, p2h} :
                                {pixg, p6, p5h};
// one word enters the FIFO per cycle: a completed pixel word, the partial
// word at the end of a row, or zero padding up to the 256-byte pitch
wire        pix_wr   = pixel && !fs && wr_frame && !pad;
wire        pix_push = pix_wr && (slot==2 || slot==5 || slot==7);
wire        pad_push = pad && !de && (slot!=0 || row_words!=0);
wire        push_now = pix_push || pad_push;
wire [63:0] push_d   = pad && slot==0 ? 64'd0 : word;

// frame-start decision while armed
reg         fs_match, fs_fault;
reg  [ 7:0] fs_code;

always @* begin
    fs_match = 0;
    fs_fault = 0;
    fs_code  = 0;
    if(tag_pend) begin
        if(tag_q < cp) begin
            if(l_state==CAB_DONE && tag_q >= cab_completed) begin
                fs_fault = 1; fs_code = F_LATE;   // the replay ends first
            end
        end else if(tag_q == cp) begin
            if(prev_ok) fs_match = 1;
            else begin
                fs_fault = 1;
                fs_code  = wr_frame && geom_bad ? F_GEOM : F_LATE;
            end
        end else begin
            fs_fault = 1; fs_code = F_LATE;
        end
    end else if(l_state==CAB_DONE && (cab_completed < cp || !iv_active)) begin
        fs_fault = 1; fs_code = F_LATE;           // no tag will reach cp
    end
end
wire fs_write = st==S_ARMED && !fs_match && !fs_fault;

// ------------------------------------------------------------- commands
wire [ 6:0] rx_bytes  = uio_words - 7'd1;
wire [ 6:0] exp_words = uio_command==CAP_CAPS || uio_command==CAP_ARM ? 7'd8 :
                        uio_command==CAP_RESULT_READ ? 7'd64 : 7'd4;
wire [ 7:0] tx_error  = uio_bad_word && uio_bad_index<=exp_words ? F_BAD_WORD :
                        rx_bytes>exp_words ? F_BAD_LENGTH : 8'd0;
wire [14:0] pay_cp    = uio_payload[14:0];
wire [10:0] pay_hold  = uio_payload[42:32];
wire        pay_clean = uio_payload[31:15]==0;
wire        cmd_done  = uio_finish && uio_active && owned_cmd;
wire        rd_cmd    = uio_command==CAP_CAPS || uio_command==CAP_RESULT_READ;
wire        cmd_ok    = cmd_done && !rd_cmd && tx_error==0 && rx_bytes==exp_words && !abort_pend;
wire        life_evt  = cab_state!=l_state || cab_error!=l_err;
wire        life_block= cab_state==CAB_IDLE || cab_state==CAB_ERROR || cab_error!=0 ||
                        (cab_state==CAB_ARMED && l_state!=CAB_IDLE);
wire        arm_ok    = drain_ready && session_ready && l_err==0 && !(life_evt && life_block) &&
                        (l_state==CAB_ARMED || l_state==CAB_RUNNING ||
                         (l_state==CAB_DONE && cab_completed>=pay_cp)) &&
                        video_ok && pay_cp!=0 &&
                        pay_hold>=11'd100 && pay_hold<=11'd2000;

task set_fault(input [7:0] code);
begin
    if(fault==0) fault <= code;
    st       <= S_FAULT;
    wr_frame <= 0;
    pad      <= 0;
    flush    <= 1;
    crc_busy <= 0;
end
endtask

always @(posedge clk) begin
    if(rst) begin
        st <= S_IDLE; cp <= 0; fault <= 0;
        owner <= 0; abort_pend <= 0; cancel <= 0; flush <= 0;
        result_valid <= 0; last_release_ok <= 0;
        cmd_fresh <= 0; res_fresh <= 0;
        l_state <= CAB_IDLE; l_err <= 0; session_ready <= 0;
        lvbl_l <= 0; iv_active <= 0; tag_pend <= 0;
        de_l <= 0; wr_frame <= 0; geom_bad <= 0; pad <= 0;
        since_rise <= 0; line_len <= 0;
        rows <= 0; slot <= 0; row_words <= 0; frame_words <= 0; hash <= 0;
        wr_ptr <= 0; wr_ptr_d <= 0; rd_ptr <= 0;
        push <= 0; push_first <= 0; first_pend <= 0;
        burst <= 0; beat <= 0; bidx <= 0;
        crc_busy <= 0;
    end else begin
        push       <= 0;
        push_first <= 0;
        wr_ptr_d   <= wr_ptr;
        lvbl_l     <= lvbl;
        if(push) begin
            wr_ptr <= wr_ptr + 1'd1;
            hash   <= gfw1(gfw1(hash, push_data[31:0]), push_data[63:32]);
        end

        // ---- CAB intervals
        if(cab_frame_start) begin
            iv_active <= cab_state==CAB_RUNNING && cab_error==0 && lvbl;
            iv_index  <= cab_frame_index;
        end
        if(vb_start) begin
            iv_active  <= 0;
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
        end
        if(de_rise) begin
            xcnt <= 0;
            rows <= fs ? 13'd1 : rows + 1'd1;
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
                set_fault(F_OVERRUN); // row padding did not finish in time
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
            if(fifo_full) set_fault(F_OVERRUN);
            else if(frame_words >= MAX_WORDS-1'd1) begin
                // never write past the slot
                geom_bad <= 1;
                wr_frame <= 0;
                pad      <= 0;
                flush    <= 1;
            end
        end

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

        // ---- frame start
        if(fs) begin
            if(st==S_ARMED) begin
                tag_pend <= 0;
                if(fs_match) begin
                    st        <= S_RUN;
                    cap_w     <= width;
                    cap_h     <= rows;
                end else if(fs_fault) begin
                    set_fault(fs_code);
                end
            end
            wr_frame   <= fs_write;
        end

        // ---- tags, consumed at the next frame start
        if(tag_new && st==S_ARMED) begin
            if(tag_pend) set_fault(F_TAG); // no frame start between two tags
            tag_pend <= 1;
            tag_q    <= tag_cp;
        end

        // ---- matched frame reaches DDR: hash the descriptor, publish
        if(st==S_RUN && quiet && !crc_busy) begin
            crc_busy <= 1;
            crc_i    <= 0;
            crc      <= 32'hFFFF_FFFF;
        end
        if(crc_busy) begin
            crc   <= crc8(crc, desc_b);
            crc_i <= crc_i + 1'd1;
            if(crc_i==6'd55) begin
                crc_busy     <= 0;
                st           <= S_READY;
                result_valid <= 1;
                res_fresh    <= res_fresh + 1'd1;
            end
        end

        if(st!=S_IDLE && st!=S_FAULT && !video_ok) set_fault(F_MODE);

        // ---- CAB lifecycle
        if(life_evt) begin
            l_state <= cab_state;
            l_err   <= cab_error;
            if(cab_state==CAB_IDLE || cab_state==CAB_ERROR || cab_error!=0 || cab_state>CAB_ERROR)
                session_ready <= 0;
            else if(cab_state==CAB_ARMED)
                session_ready <= l_state==CAB_IDLE && l_err==0;
            if(st!=S_IDLE && life_block) begin
                set_fault(F_LIFE);
                cancel <= 1;
            end
        end

        // ---- HPS commands
        if(uio_start && host_word==CAP_RESULT_READ && !result_valid && fault==0)
            fault <= F_BAD_STATE;
        if(cmd_done) begin
            if(rd_cmd) begin
                if(uio_words != exp_words+7'd1 && fault==0) fault <= F_BAD_LENGTH;
                if(uio_command==CAP_RESULT_READ && !result_valid && fault==0) fault <= F_BAD_STATE;
            end else if(tx_error!=0 || rx_bytes!=exp_words) begin
                if(fault==0) fault <= tx_error!=0 ? tx_error : F_BAD_LENGTH;
            end else if(abort_pend) begin
                if(fault==0) fault <= F_BAD_STATE;  // command while busy
            end
        end
        if(cmd_ok) case(uio_command)
            CAP_ARM: begin
                cmd_fresh <= cmd_fresh + 1'd1;
                if(st!=S_IDLE || draining || owner || uio_payload[15] ||
                   uio_payload[31:16]!=0 || uio_payload[63:43]!=0) begin
                    if(fault==0) fault <= F_BAD_STATE;
                end else begin
                    last_release_ok <= 0;
                    result_valid    <= 0;
                    if(arm_ok) begin
                        st       <= S_ARMED;
                        cp       <= pay_cp;
                        owner    <= 1;
                        fault    <= 0;
                        cancel   <= 0;
                        tag_pend <= 0;
                    end else begin
                        fault <= !video_ok ? F_MODE :
                                 (l_state==CAB_DONE && session_ready && l_err==0 &&
                                  cab_completed<pay_cp) ? F_LATE : F_BAD_STATE;
                    end
                end
            end
            CAP_RELEASE: begin
                cmd_fresh <= cmd_fresh + 1'd1;
                if(last_release_ok && pay_cp==cp && pay_clean) begin
                    // repeated release of the last capture
                end else if(!owner || pay_cp!=cp || !pay_clean || pay_cp==0) begin
                    if(fault==0) fault <= F_RELEASE;
                end else if(st==S_READY && fault==0) begin
                    st              <= S_IDLE;
                    owner           <= 0;
                    result_valid    <= 0;
                    last_release_ok <= 1;
                end else begin
                    // only a READY slot can be released; abort it instead
                    set_fault(F_RELEASE);
                    last_release_ok <= 0;
                end
            end
            CAP_ABORT: begin
                if(!owner || pay_cp!=cp || !pay_clean || pay_cp==0) begin
                    if(fault==0) fault <= F_BAD_STATE;
                    cmd_fresh <= cmd_fresh + 1'd1;
                end else begin
                    abort_pend <= 1;    // acknowledged once the writer is quiet
                    if(st!=S_IDLE) set_fault(8'd0);
                end
            end
            default:;
        endcase

        // ---- cleanup: a lifecycle cancel frees the writer, an abort also
        // ends the ownership
        if(cancel && quiet && (st==S_FAULT || st==S_IDLE)) begin
            st     <= S_IDLE;
            cancel <= 0;
        end
        if(abort_pend && quiet && (st==S_IDLE || st==S_FAULT)) begin
            st              <= S_IDLE;
            cancel          <= 0;
            abort_pend      <= 0;
            owner           <= 0;
            result_valid    <= 0;
            last_release_ok <= 0;
            cmd_fresh       <= cmd_fresh + 1'd1;
        end
    end
end

endmodule
