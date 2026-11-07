/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Date: 12-10-2026 */
//============================================================================
//  jtframe_crt_480i.sv  --  medium-res (25 kHz) source -> 15 kHz interlaced for low-res CRTs
//  (15 kHz only: there is no native output path)
//
//  Sits between a core's native video and the MiSTer VGA (analog) output. It
//  re-times a progressive source of up to W_MAX x 2*VIS_LINES (e.g. 512x384
//  at about 25 kHz) into interlaced video at a 15 kHz line rate: 525 lines a
//  frame (480i) for a 60 Hz source, 625 (576i) for 50 Hz, an odd count in
//  between for anything else. It has no path
//  from its inputs to its outputs: the output is interlaced, or black with both
//  syncs idle until it has locked. The native picture can still go to HDMI,
//  through the framework's scaler, beside it.
//  Every field carries alternate source lines, so at Height 1:1 with
//  deflicker Off every source line reaches the screen unchanged.
//
//  How it works
//  - One output field per source frame. The field starts a measured delay
//    after the source VSync, so the output is phase-locked to the source:
//    no drift, no tearing, under one frame of latency.
//  - Half-line cadence: HL half-line ticks per source frame (Bresenham over
//    the measured frame period, 1 clk jitter). Lines start on even ticks;
//    HL is odd, so field 1 starts on an odd tick and its VSync lands mid-line.
//  - HL comes from the measured frame period: the odd count nearest a line
//    rate of 15075 + 11 x (frame rate) Hz, so 525 at 59.94 Hz (NTSC) and 625
//    at 50 Hz (PAL); 571 for 54.82 Hz, 547 for 57.5 Hz (all about 15.65-15.76
//    kHz). It is never below HL_MIN (525 by default): from about 59.8 Hz up a
//    field keeps 262.5 lines and the line rate rises with the frame rate, to
//    16.5 kHz at most. A core whose picture is shorter than 240 lines a field
//    can set HL_MIN lower (e.g. 513 for 224 lines at 61.4 Hz: 15.74 kHz). HL is
//    held while locked. The lines a slower frame adds go half above, half
//    below the visible window (VIS_FIRST moves down by (HL - 525) / 4; up, for
//    HL below 525).
//  - Field 0 shows source lines 0,2,4..., field 1 lines 1,3,5..., from a
//    RING-line buffer that holds every source line, both parities, because
//    deflicker and stretch read the neighbouring lines too.
//  - A 15 kHz line carries one source line while the source makes one per
//    25 kHz line, so the output consumes lines faster than they arrive. The
//    field start is delayed so the last line read is still behind the source;
//    that delay is computed per frame from what was measured. RING must exceed
//    the backlog at the first active line: about 84 lines for 512x384 at 60 Hz.
//    RING > hsrc + 4 - (out_lines - 1) x (output line / source line), with
//    hsrc the active source lines, out_lines the output lines per field at
//    the smallest Height used (hsrc/2 at 1:1, 240 at most) and an output line
//    of 63.5 us (60.6 us at 16.5 kHz).
//  - Pixels are replayed at clk/CLK_DIV (CLK_DIV+0.5 with CLK_FRAC): about
//    10.67 MHz puts 512 pixels in 48 us of the 63.5 us line.
//
//  Self-measuring: frame period, line period, active width and height, and
//  the VSync-to-first-active-line time. It locks after 3 stable frames, only
//  from 49 Hz up to the rate where HL_MIN half-lines give a 16.5 kHz line
//  (62.86 Hz at 525), or lower if H_START + W_MAX would not fit that line, and drops
//  the lock within a frame if the source VSync stops or its timing changes. A
//  picture narrower than W_MAX or shorter than the field is centred; pixels
//  past W_MAX are dropped. At 1:1 an odd last source line is not shown.
//  All inputs must be synchronous to clk (4095 clocks a source line at most);
//  there is no clock crossing inside.
//  The output pixel clock (clk / CLK_DIV) must fit the line: the build stops if
//  it is too fast or too slow. There is no reset: every register starts at its
//  initial value and resynchronises itself.
//
//  Storage: PW bits per pixel. With LUT_EXT=1 they are a palette index and the
//  core returns the colour on lut_rgb, LUT_LAT clocks after lut_addr. Indices
//  keep colours exact and the ring small, but a colour is looked up when its
//  line goes out, up to RING source lines after it was drawn: a palette change
//  part-way through a frame (a raster effect, or a write just after the last
//  active line) also recolours the lines drawn shortly before it. With
//  LUT_EXT=0 they are packed {r,g,b} at PW/3 bits each, expanded to 8 bits
//  here, and there is no such delay.
//
//  Deflicker (Off, Low, Mid, High): each output pixel blends the
//  source lines above and below, so a one-line detail shows in both fields.
//  Height 1:1 uses the kernels directly; stretched heights use the weight ROM
//  below (deflicker, then interpolate).
//
//  Credit: the approach (measure the source, buffer lines in a ring, lock
//  once stable) was inspired by rmonic79's crt_vsize.sv (MiSTer-CRT-Adjust).
//  This is an independent implementation; licence as at the top of the file.
//============================================================================

module jtframe_crt_480i #(parameter
    CLK_HZ    = 0,     // Input clock frequency in Hz; required
    CLK_DIV   = 3,     // Output pixel period, at least three clocks
    CLK_FRAC  = 0,     // Alternate CLK_DIV and CLK_DIV+1 clock periods
    W_MAX     = 512,   // Maximum stored width; power of two
    RING      = 96,    // Stored source lines, including both parities
    PW        = 8,     // Palette index or packed RGB width
    LUT_EXT   = 1,     // External palette lookup; zero selects packed RGB
    LUT_LAT   = 1,     // External palette latency, one or two clocks
    HS_PIX    = 50,    // HSync duration in output pixels
    H_START   = 111,   // HSync start to active pixels at maximum width
    VIS_FIRST = 21,    // First visible line in each field
    VIS_LINES = 240,   // Maximum active lines in each field
    VS_HL     = 6,     // VSync start, half-lines after field start
    VS_LEN    = 6,     // VSync duration in half-lines
    HL_MIN    = 525    // Minimum odd half-line count per field
)(
    input                   clk,
    input                   ce_in,       // Source pixel enable
    input      [PW-1:0]     pix_in,      // Palette index or packed RGB
    input                   vs_in, de_in,
    input signed [6:0]      hoffset, voffset, // Positive offsets move right/down
    input      [ 1:0]       deflicker,   // Off, Low (1-6-1), Mid (1-3-1), High (1-2-1)
    input      [ 2:0]       vheight,     // 0=1:1; 1..6=200,208,216,224,232,240 field lines

    output reg [PW-1:0]     lut_addr,    // Registered palette lookup address
    input      [23:0]       lut_rgb,

    output reg              ce_out=0,
    output reg [ 7:0]       r_out, g_out, b_out,
    output reg              hs_out, vs_out, de_out,
    output reg              hb_out, vb_out,
    output reg              field,       // Odd field selects odd source lines
    output                  locked       // Source timing is stable
);

localparam AW = $clog2(W_MAX), SW = $clog2(RING), CB = PW/3;
localparam integer OUT_X2 = (CLK_DIV << 1) + CLK_FRAC;
localparam integer TL_HZ  = CLK_HZ / 16500 + 1;
localparam integer TL_PX  = ((H_START + W_MAX) * OUT_X2 + 1) / 2;
localparam integer TL_MIN = TL_HZ > TL_PX ? TL_HZ : TL_PX;
localparam [21:0] TF_MIN  = 22'((TL_MIN * HL_MIN + 1) / 2),
                  TF_MAX = 22'(CLK_HZ / 49);
localparam [47:0] HL_K    = CLK_HZ == 0 ? 48'd0 :
    ((48'd15075 << 32) + 48'(CLK_HZ) / 48'd2) / 48'(CLK_HZ);
localparam [13:0] LMIN    = 14'((HL_MIN - 1) / 2);
localparam [10:0] HLM     = HL_MIN[10:0];
localparam [ 9:0] VLIMIT  = VIS_LINES[9:0];
localparam integer V_MIN = (VS_HL + VS_LEN + 1) / 2;
localparam signed [11:0] V_MIN_SIGNED = V_MIN[11:0];

// Read phases and colour-pipeline latency, in input clocks and output pixels.
localparam integer LL = LUT_EXT ? LUT_LAT : 1, PM = 4 + LL, TD = 1 + LL;
localparam integer LAT = PM / CLK_DIV + 1, TAGW = TD << 1;
localparam [7:0] PH_C = 8'((1+LL) % CLK_DIV), PH_A = 8'((2+LL) % CLK_DIV),
                 PH_B = 8'((3+LL) % CLK_DIV), PH_M = 8'(PM % CLK_DIV);
localparam integer VADD_MIN = HL_MIN >= 525 ? (HL_MIN - 525) / 4 : -((525 - HL_MIN + 3) / 4);
localparam integer LINE_LO = (CLK_HZ / OUT_X2 << 1) / 15580;
localparam integer LINE_HI = (CLK_HZ / OUT_X2 << 1) / 15770;

wire [25:0] nx_pos, nx_pos_round, pos_0, pos_0r;
wire [23:0] rgb;
wire [11:0] dv_t;
wire [10:0] hlf;
wire [ 9:0] lf, nx_src_line;
wire [ 7:0] plast;
wire [ 1:0] f_adv, tag_in, tag_cap, tag_mix;
wire [AW:0] wx_cur;
wire [AW-1:0] rx;
wire [SW-1:0] slot_above;
wire vs_rise, de_rise, dv_ge, vfull, fstart, tick, h_on, v_on;
wire cap_c, cap_a, cap_b, do_m;

// Source measurements and geometry. Counters use the input clock.
reg [45:0] m_hl=0;
reg [33:0] m_step;
reg [25:0] pos=0;                           // Source position, 10.16 fixed point
reg [23:0] step=0, f_step=0;
reg [23:0] rgb_int, hk, cc=0, ca=0, cb=0, blend=0;
reg [22:0] dv_q=0, dly=0, dcnt=0, acc=0;
reg [21:0] fcnt=0, tf=0, tz_run=0, tz=0, tlo=0, tz_h=0;
reg [21:0] m_src, m_out;
reg [13:0] hl_f=0;
reg [11:0] lcnt=0, tls=0, tls_h=0;
reg signed [11:0] v_want=0;
reg [10:0] hl_n=HLM, dv_r=0, dv_d=11'd525, hl=0, px=0, hst=0;
reg signed [10:0] v_add=0;
reg [ 9:0] hs_run=0, hsrc=0, half_act=0, out_lines=0, vstart=0;
reg [ 9:0] v_cen=0, v_hi=0, f_lines=0, f_vstart=0, s_cur=0;
reg [ 9:0] hsel;
reg [ 7:0] cdiv=0, frac=0, r_o=0, g_o=0, b_o=0;
reg [ 4:0] dv_n=0;
reg [ 2:0] h_on_pipe=0, hs_pipe=0, vs_pipe=0, hw_pipe=0, vw_pipe=0;
reg [ 1:0] stable=0;
reg [AW:0] xw=0, ws_run=0, wsrc=0, wx=0;
reg [SW-1:0] wslot=0, rs_c=0, rs_a=0, rs_b=0;
reg [SW-1:0] rslot;
reg [TAGW+1:0] tsr=0;                      // Two-bit read tags at each pipeline stage
reg vs_l=0, de_l=0, seen_de=0, f_vfull=0, wpar=0, wfirst=0;
reg armed=0, fpar=0, alt=0, rline_on=0;
reg hs_o=0, vs_o=0, de_o=0, f_o=0, hb_o=1, vb_o=1;

// Both memories have synchronous reads for embedded RAM inference.
(* ramstyle = "no_rw_check" *) reg [PW-1:0] ring[0:RING*W_MAX-1];
reg [26:0] wrom[0:1023];                   // Four filters, 256 fractional positions each
reg [26:0] wq;

function [SW-1:0] inc_slot(input [SW-1:0] slot);
    inc_slot = slot == SW'(RING-1) ? {SW{1'b0}} : slot + 1'b1;
endfunction

function [7:0] expand_color(input [CB-1:0] value);
    expand_color = 8'({value, value, value, value} >> ((CB << 2) - 8));
endfunction

function [7:0] mix_lines(input [7:0] above, centre, below, input [1:0] level);
    reg [13:0] a, c, b, total;
    reg [10:0] mid_sum;
    reg [20:0] mid_product;
    begin
        a = {6'd0, above};
        c = {6'd0, centre};
        b = {6'd0, below};
        // floor(sum/5), exact over 0..1275, using a constant reciprocal.
        mid_sum = {3'd0, above} + 11'd3*{3'd0, centre} + {3'd0, below};
        mid_product = mid_sum * 21'd1639;
        case( level )
            2'd0: total = c;
            2'd1: total = (a + b + 14'd6*c) >> 3;             // Low: 1-6-1 / 8
            2'd2: total = {6'd0, mid_product[20:13]};         // Mid: 1-3-1 / 5
            2'd3: total = (a + b + {c[12:0], 1'b0}) >> 2;     // High: 1-2-1 / 4
        endcase
        mix_lines = total[7:0];
    end
endfunction

function [7:0] weighted_sum(input [7:0] above, centre, below);
    reg [17:0] total;
    begin
        total        = above*wq[26:18] + centre*wq[17:9] + below*wq[8:0] + 18'd128;
        weighted_sum = total[15:8];
    end
endfunction

assign locked       = stable == 2'd3;
assign vs_rise      = vs_in & ~vs_l;
assign de_rise      = de_in & ~de_l;
assign dv_t         = {dv_r, dv_q[22]};
assign dv_ge        = dv_t >= {1'b0, dv_d};
assign vfull        = vheight != 0;
assign wx_cur       = (de_rise | wfirst) ? {AW+1{1'b0}} : wx;
assign plast        = 8'(CLK_DIV-1) + {7'd0, CLK_FRAC[0] & alt};
assign fstart       = armed && dcnt >= dly;
assign tick         = acc + {12'd0, hl_n} >= {1'b0, tf};
assign hlf          = hl - {10'd0, fpar};
assign lf           = hlf[10:1];
assign v_on         = !(fpar && hl == 0) && lf >= f_vstart && lf < f_vstart + f_lines;
assign h_on         = px >= hst && px < hst + wsrc;
assign nx_pos       = pos + {f_step, 1'b0};
assign nx_pos_round = nx_pos + 26'h8000;
assign nx_src_line  = nx_pos_round[25:16];
assign f_adv        = nx_src_line[1:0] - s_cur[1:0];
assign pos_0        = fpar ? {2'd0, f_step} : 26'd0;
assign pos_0r       = pos_0 + 26'h8000;
assign rx           = AW'(px - hst);
assign rgb          = LUT_EXT ? lut_rgb : rgb_int;
assign tag_in       = cdiv == 0 ? 2'd1 : cdiv == 1 ? 2'd2 : cdiv == 2 ? 2'd3 : 2'd0;
assign tag_cap      = tsr[TAGW-1 -: 2];
assign tag_mix      = tsr[TAGW+1 -: 2];
assign cap_c        = CLK_FRAC ? tag_cap == 2'd1 : cdiv == PH_C;
assign cap_a        = CLK_FRAC ? tag_cap == 2'd2 : cdiv == PH_A;
assign cap_b        = CLK_FRAC ? tag_cap == 2'd3 : cdiv == PH_B;
assign do_m         = CLK_FRAC ? tag_mix == 2'd3 : cdiv == PH_M;
assign slot_above   = rs_c == 0 ? RING[SW-1:0]-1'b1 : rs_c-1'b1;

// Evaluate at time zero even when the height input is tied to a constant.
always_comb begin
    case( vheight )
        3'd1:    begin hsel = 10'd200; hk = 24'd41943; end
        3'd2:    begin hsel = 10'd208; hk = 24'd40329; end
        3'd3:    begin hsel = 10'd216; hk = 24'd38836; end
        3'd4:    begin hsel = 10'd224; hk = 24'd37449; end
        3'd5:    begin hsel = 10'd232; hk = 24'd36157; end
        default: begin hsel = 10'd240; hk = 24'd34952; end
    endcase
    if( hsel > VLIMIT ) begin
        hsel = VLIMIT;
        hk   = 24'((1 << 24) / (VIS_LINES << 1));
    end
end

always @(posedge clk) begin
    vs_l <= vs_in;
    de_l <= de_in;
    fcnt <= vs_rise ? 22'd1 : fcnt + 1'd1;
    lcnt <= de_rise ? 12'd1 : lcnt + 1'd1;
    if( de_rise ) begin
        if( seen_de ) tls <= lcnt;
        tz_run  <= fcnt;
        seen_de <= 1;
        hs_run  <= hs_run + 1'd1;
    end
    if( ce_in ) begin
        if( de_in ) begin
            if( !xw[AW] ) xw <= xw + 1'd1;      // saturates at W_MAX
        end else begin
            if( xw != 0 && xw > ws_run ) ws_run <= xw;
            xw <= 0;
        end
    end
    if( vs_rise ) begin
        tf      <= fcnt;
        tz      <= tz_run;
        hsrc    <= hs_run;
        wsrc    <= ws_run;
        hs_run  <= 0;
        ws_run  <= 0;
        seen_de <= 0;
        // two consecutive frames within 4 clk, with a picture in them, inside the window
        if( hs_run != 0 && fcnt >= TF_MIN && fcnt <= TF_MAX &&
            ((fcnt > tf ? fcnt - tf : tf - fcnt) < 22'd4) )
            stable <= stable == 2'd3 ? 2'd3 : stable + 1'd1;
        else
            stable <= 0;
    end else if( fcnt > TF_MAX )
        stable <= 0;                    // the source VSync stopped
end

always @(posedge clk) begin
    m_hl <= tf * HL_K[23:0];
    hl_f <= m_hl[45:32] + 14'd11;
    if( !locked ) hl_n <= hl_f < LMIN ? HLM : hl_f > 14'd1023 ? 11'd2047 : { hl_f[9:0], 1'b1 };
end

// Shift/subtract divider: one output line period result every 24 clocks.
always @(posedge clk) begin
    if( dv_n == 0 ) begin
        dv_q <= { tf, 1'b0 };
        dv_r <= 0;
        dv_d <= hl_n;
        dv_n <= 5'd23;
    end else begin
        dv_r <= dv_ge ? dv_t[10:0] - dv_d : dv_t[10:0];
        dv_q <= { dv_q[21:0], dv_ge };
        dv_n <= dv_n - 1'd1;
        if( dv_n == 1 ) tlo <= { dv_q[20:0], dv_ge };
    end
end

always @(posedge clk) begin
    // pipelined over the frame; results are stable long before they are used
    v_add     <= 11'($signed({1'b0, hl_n} - 12'd525) >>> 2);
    half_act  <= {1'b0, hsrc[9:1]};
    out_lines <= vfull ? hsel : half_act > VLIMIT ? VLIMIT : half_act;
    v_cen     <= (VIS_LINES[9:0] - out_lines) >> 1;       // centred in the visible lines
    v_want    <= $signed({2'b00, VIS_FIRST[9:0] + v_cen}) + $signed({v_add[10], v_add}) + $signed({{5{voffset[6]}}, voffset});
    v_hi      <= hl_n[10:1] - out_lines;
    vstart    <= v_want < V_MIN_SIGNED ? V_MIN[9:0] : v_want > $signed({2'b00, v_hi}) ? v_hi : v_want[9:0];
    // step = hsrc / (2*lines) in 8.16: hsrc * floor(2^24/(2*lines)) >> 8
    m_step <= hsrc * hk;
    step   <= m_step[31:8];
    // measured from the last line, not first line + hsrc x tls, with the line period held while
    // locked: a source whose line period alternates by 1 clk (Popeye: 1523/1524) would otherwise
    // move the field start from frame to frame (by hsrc clk with the old formula; the field
    // period then alternated and a CRT dropped the picture for single frames)
    // tz is held too unless it really moves (the source's picture moved: more than 8 clk)
    if( !locked ) tls_h <= tls;
    if( !locked || (tz > tz_h ? tz - tz_h : tz_h - tz) > 22'd8 ) tz_h <= tz;
    m_src <= tz_h + {10'd0, tls_h} + {9'd0, tls_h, 1'b0};                 // source finishes, plus two lines
    m_out <= ({12'd0, vstart} + {12'd0, out_lines} - 22'd1) * tlo;            // field start -> last active line
    // field start = source finish - that; if it lands before VSync, start in the previous frame
    dly <= (m_src >= m_out) ? {1'b0, m_src - m_out} : {1'b0, m_src} + {1'b0, tf} - {1'b0, m_out};
end

// Store every source line; wfirst preserves x=0 until the next pixel enable.
always @(posedge clk) begin
    if( vs_rise ) begin
        wpar  <= ~wpar;
        wslot <= 0;
    end else begin
        if( de_l & ~de_in )                // line ended
            wslot <= wslot == SW'(RING-1) ? {SW{1'b0}} : wslot + 1'd1;
        if( de_rise ) wfirst <= 1;
        if( ce_in && de_in ) begin
            if( !wx_cur[AW] ) ring[{wslot, wx_cur[AW-1:0]}] <= pix_in;
            wx     <= wx_cur + !wx_cur[AW];
            wfirst <= 0;
        end
    end
end

always @(posedge clk) begin
    dcnt <= vs_rise ? 23'd0 : dcnt + 1'd1;
    if( vs_rise ) armed <= 1;
    ce_out <= 0;
    if( fstart ) begin
        armed    <= 0;
        f_vfull  <= vfull;
        f_lines  <= out_lines;
        f_vstart <= vstart;
        f_step   <= step;
        fpar     <= wpar;                 // this frame's lines are the ones stored
        hl       <= 0;
        acc      <= 0;
        if( !wpar ) begin              // field 0 starts on a line boundary
            cdiv   <= 0;
            px     <= 0;
            ce_out <= 1;
            alt    <= 0;
        end else begin                 // field 1 starts mid-line: the line carries on
            cdiv <= cdiv == plast ? 8'd0 : cdiv + 1'd1;
            if( cdiv == plast ) begin
                ce_out <= 1;
                if( px != 11'h7ff ) px <= px + 1'd1;   // saturates: one HSync per line
                alt <= ~alt;
            end
        end
    end else begin
        if( tick ) begin
            acc <= acc + {12'd0, hl_n} - {1'b0, tf};
            hl  <= hl + 1'd1;
        end else
            acc <= acc + {12'd0, hl_n};
        // a line starts on every tick that lands on an even half-line of the frame
        if( tick && ((hl + 1'd1 + fpar) & 1) == 0 ) begin
            cdiv   <= 0;
            px     <= 0;
            ce_out <= 1;
            alt    <= 0;
        end else begin
            cdiv <= cdiv == plast ? 8'd0 : cdiv + 1'd1;
            if( cdiv == plast ) begin
                ce_out <= 1;
                if( px != 11'h7ff ) px <= px + 1'd1;   // saturates: one HSync per line
                alt <= ~alt;
            end
        end
    end
end

always @(posedge clk) hst <= H_START[10:0] + ((W_MAX[10:0] - wsrc) >> 1) + {{4{hoffset[6]}}, hoffset};

// Advance by two source lines at 1:1, or by the scaled source position.
always @(posedge clk) if( ce_out && px == 0 ) begin
    if( !v_on ) begin
        pos      <= pos_0;
        s_cur    <= f_vfull ? pos_0r[25:16] : {9'd0, fpar};              // nearest line (0..2)
        rs_c     <= f_vfull ? pos_0r[16 +: SW] : {{SW-1{1'b0}}, fpar};
        frac     <= f_vfull ? pos_0r[15:8] : 8'h80;
        rline_on <= 0;
    end else begin
        if( rline_on ) begin
            if( f_vfull ) begin
                pos   <= nx_pos;
                s_cur <= nx_src_line;
                frac  <= nx_pos_round[15:8];
                case( f_adv )
                    2'd1:    rs_c <= inc_slot(rs_c);
                    2'd2:    rs_c <= inc_slot(inc_slot(rs_c));
                    2'd3:    rs_c <= inc_slot(inc_slot(inc_slot(rs_c)));
                    default: ;                        // same line (stretched over 2x)
                endcase
            end else begin
                s_cur <= s_cur + 10'd2;
                rs_c  <= inc_slot(inc_slot(rs_c));
            end
        end
        rline_on <= 1;
    end
end

always @* begin
    rs_a = s_cur == 0            ? rs_c : slot_above;
    rs_b = s_cur + 1'd1 >= hsrc  ? rs_c : inc_slot(rs_c);
end

always @* case( cdiv )
    8'd1:    rslot = rs_a;
    8'd2:    rslot = rs_b;
    default: rslot = rs_c;
endcase

always @(posedge clk) lut_addr <= ring[{ rslot, rx }];

always @(posedge clk) begin
    rgb_int <= {expand_color(lut_addr[3*CB-1 -: CB]),
                expand_color(lut_addr[2*CB-1 -: CB]),
                expand_color(lut_addr[  CB-1 -: CB])};
end

// Stretch filtering blends the nearest line and its neighbours. The weights
// combine deflicker and interpolation, drop the fourth (most distant) tap,
// and renormalize to 256. A common denominator of 40 represents the exact
// side weights 0, 1/8, 1/5 and 1/4 before the final ROM quantization.
initial begin : build_wrom
    integer lv, fi, d, k, f, rawa, rawc, rawb, t, sum, wa, wb, wc;
    for( lv = 0; lv < 4; lv = lv + 1 ) begin
        k = lv == 0 ? 0 : lv == 1 ? 5 : lv == 2 ? 8 : 10;   // Kernel side weight, /40
        for( fi = 0; fi < 256; fi = fi + 1 ) begin
            d = fi - 128;                          // offset from the nearest line, /256
            f = d < 0 ? -d : d;
            rawc = (256 - f) * (40 - (k << 1)) + f * k;
            rawa = k * (256 - f);                         // Far side
            rawb = (256 - f) * k + f * (40 - (k << 1));    // Near side
            if( d < 0 ) begin
                t    = rawa;
                rawa = rawb;
                rawb = t;
            end
            sum                  = rawa + rawc + rawb;
            wa                   = ((rawa << 8) + sum/2) / sum;
            wb                   = ((rawb << 8) + sum/2) / sum;
            wc                   = 256 - wa - wb;
            wrom[(lv << 8) + fi] = { wa[8:0], wc[8:0], wb[8:0] };
        end
    end
end

always @(posedge clk) wq <= wrom[{ deflicker, frac }];

// synthesis translate_off
initial begin
    if( CLK_DIV < 3 )                  $fatal(1, "jtframe_crt_480i: CLK_DIV must be 3 or more");
    if( LUT_EXT && (LUT_LAT < 1 || LUT_LAT > 2) ) $fatal(1, "jtframe_crt_480i: LUT_LAT must be 1 or 2");
    if( CLK_FRAC && PM / CLK_DIV != PM / (CLK_DIV+1) )
        $fatal(1, "jtframe_crt_480i: CLK_FRAC needs PM/CLK_DIV == PM/(CLK_DIV+1) (e.g. CLK_DIV 4)");
    if( W_MAX != 1 << AW )             $fatal(1, "jtframe_crt_480i: W_MAX must be a power of 2");
    if( !LUT_EXT && PW < 6 )           $fatal(1, "jtframe_crt_480i: packed colour needs PW >= 6");
    if( HL_MIN % 2 == 0 || HL_MIN < 401 || HL_MIN > 625 ) $fatal(1, "jtframe_crt_480i: HL_MIN must be odd, 401..625");
    if( VIS_FIRST + VADD_MIN + VIS_LINES > (HL_MIN-1)/2 ) $fatal(1, "jtframe_crt_480i: VIS_FIRST + VIS_LINES exceed the shortest field (HL_MIN)");
    if( CLK_HZ != 0 && (HL_K >= (1 << 24) || HL_K < (1 << 17)) ) $fatal(1, "jtframe_crt_480i: CLK_HZ out of range (4..200 MHz)");
    if( VIS_FIRST + VADD_MIN < V_MIN ) $fatal(1, "jtframe_crt_480i: VIS_FIRST overlaps VSync (at HL_MIN)");
end
// synthesis translate_on

always @(posedge clk) tsr <= { tsr[TAGW-1:0], tag_in };

always @(posedge clk) begin
    if( cap_c ) cc <= rgb;
    if( cap_a ) ca <= rgb;
    if( cap_b ) cb <= rgb;
    // The blend is one clock after the last capture and uses registers only, so the lookup
    // and the blend arithmetic are never in the same clock. (At CLK_DIV 3 the next pixel's
    // centre is captured on this same clock; the blend still sees the old cc.)
    if( do_m ) begin
        blend <= f_vfull ?
                 { weighted_sum(ca[23:16], cc[23:16], cb[23:16]),
                   weighted_sum(ca[15: 8], cc[15: 8], cb[15: 8]),
                   weighted_sum(ca[ 7: 0], cc[ 7: 0], cb[ 7: 0]) } :
                 { mix_lines(ca[23:16], cc[23:16], cb[23:16], deflicker),
                   mix_lines(ca[15: 8], cc[15: 8], cb[15: 8], deflicker),
                   mix_lines(ca[ 7: 0], cc[ 7: 0], cb[ 7: 0], deflicker) };
    end
end

always @(posedge clk) if( ce_out ) begin
    h_on_pipe <= { h_on_pipe[1:0], h_on & v_on };
    hw_pipe   <= { hw_pipe[1:0],   h_on };          // horizontal window, every line
    vw_pipe   <= { vw_pipe[1:0],   v_on };          // active lines
    hs_pipe   <= { hs_pipe[1:0],   px < HS_PIX };
    vs_pipe   <= { vs_pipe[1:0],   hl >= VS_HL && hl < VS_HL + VS_LEN };
end

always @(posedge clk) if( ce_out ) begin
    { r_o, g_o, b_o } <= h_on_pipe[LAT-1] ? blend : 24'd0;
    de_o              <= h_on_pipe[LAT-1];
    hb_o              <= ~hw_pipe[LAT-1];
    vb_o              <= ~vw_pipe[LAT-1];
    hs_o              <= hs_pipe[LAT-1];
    vs_o              <= vs_pipe[LAT-1];
    f_o               <= fpar;
end

// Keep RGB black and syncs idle until source timing has locked.
always @* begin
    r_out  = locked ? r_o  : 8'd0;
    g_out  = locked ? g_o  : 8'd0;
    b_out  = locked ? b_o  : 8'd0;
    hs_out = locked & hs_o;                 // syncs are active high, idle low
    vs_out = locked & vs_o;
    de_out = locked & de_o;
    hb_out = locked ? hb_o : 1'b1;
    vb_out = locked ? vb_o : 1'b1;
    field  = locked & f_o;
end

// Invalid configurations fail during both simulation and synthesis.
generate
    if( CLK_HZ == 0 ) begin : g_needs_clk_hz
        jtframe_crt_480i_set_the_CLK_HZ_parameter u_err();
    end
    if( CLK_DIV < 3 ) begin : g_clk_div
        jtframe_crt_480i_CLK_DIV_must_be_3_or_more u_err();
    end
    if( CLK_FRAC && PM / CLK_DIV != PM / (CLK_DIV+1) ) begin : g_clk_frac
        jtframe_crt_480i_CLK_FRAC_needs_the_same_latency_for_both_pixel_lengths u_err();
    end
    if( CLK_HZ != 0 && LINE_LO > 2047 ) begin : g_too_fast
        jtframe_crt_480i_output_pixel_clock_too_fast u_err();       // aim for about 10-11 MHz
    end
    // also catches a tool that worked HL_K out in 32 bits (it would be 0: always 525, silently)
    if( CLK_HZ != 0 && (HL_K >= (1 << 24) || HL_K < (1 << 17)) ) begin : g_clk_hz_range
        jtframe_crt_480i_CLK_HZ_out_of_range_4_to_200_MHz u_err();
    end
    if( CLK_HZ != 0 && LINE_HI < H_START + W_MAX ) begin : g_too_slow
        jtframe_crt_480i_output_line_too_short_for_H_START_plus_W_MAX u_err();
    end
    if( HL_MIN % 2 == 0 || HL_MIN < 401 || HL_MIN > 625 ) begin : g_hl_min
        jtframe_crt_480i_HL_MIN_must_be_odd_401_to_625 u_err();
    end
    if( VIS_FIRST + VADD_MIN + VIS_LINES > (HL_MIN-1)/2 ) begin : g_hl_min_fit
        jtframe_crt_480i_VIS_FIRST_plus_VIS_LINES_exceed_the_shortest_field u_err();
    end
    if( VIS_FIRST + VADD_MIN < V_MIN ) begin : g_vis_first
        jtframe_crt_480i_VIS_FIRST_overlaps_VSync u_err();
    end
endgenerate

endmodule
