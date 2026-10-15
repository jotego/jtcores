// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Chris Watson. GPL v2 or later.
//============================================================================
//  crt_480i.sv  --  medium-res (25 kHz) source -> 15 kHz interlaced for low-res CRTs
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
//  All inputs must be synchronous to clk, which is also the core's CLK_VIDEO
//  (4095 clocks a source line at most); there is no clock crossing inside.
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
//  Deflicker (deflicker input, 5..7 act as Full): each output pixel blends the
//  source lines above and below, so a one-line detail shows in both fields.
//  Height 1:1 uses the kernels directly; stretched heights use the weight ROM
//  below (deflicker, then interpolate).
//
//  Credit: the approach (measure the source, buffer lines in a ring, lock
//  once stable) was inspired by rmonic79's crt_vsize.sv (MiSTer-CRT-Adjust).
//  This is an independent implementation; licence as at the top of the file.
//============================================================================

module crt_480i #(
    parameter CLK_HZ    = 0,     // clk frequency, Hz (required): only 49..62.86 Hz sources lock
    parameter CLK_DIV   = 3,     // output pixel = clk / CLK_DIV; >= 3 for deflicker
    parameter CLK_FRAC  = 0,     // 1: pixels alternate CLK_DIV and CLK_DIV+1 clocks (e.g. 48 MHz / 4.5)
    parameter W_MAX     = 512,   // max active width stored per line (power of 2)
    parameter RING      = 96,    // stored source lines (both parities)
    parameter PW        = 8,     // stored bits per pixel: a palette index, or packed colour
    parameter LUT_EXT   = 1,     // 1: pix_in is a palette index, coloured via lut_addr -> lut_rgb
                                 // 0: pix_in is packed {r,g,b}, PW/3 bits each
    parameter LUT_LAT   = 1,     // lut_addr -> lut_rgb latency, 1 or 2 clocks (LUT_EXT=1 only)
    parameter HS_PIX    = 50,    // output HSync width, output pixels (~4.7 us)
    parameter H_START   = 111,   // HSync start to first active pixel of a W_MAX-wide picture
    parameter VIS_FIRST = 21,    // first visible line of a field
    parameter VIS_LINES = 240,   // visible lines of a field (active is centred in them)
    parameter VS_HL     = 6,     // VSync start, half-lines after field start
    parameter VS_LEN    = 6,     // VSync length, half-lines (3 lines)
    parameter HL_MIN    = 525    // fewest half-lines a frame (odd); below 525 only for pictures
                                 // shorter than 240 lines a field (VIS_FIRST + VIS_LINES must fit)
)(
    input             clk,
    input             ce_in,     // source pixel enable
    input   [PW-1:0]  pix_in,    // what is stored (index or packed colour), with de_in
    input             vs_in, de_in,
    input signed [6:0] hoffset,  // output pixels, + = right (keep H_START + hoffset > HS_PIX)
    input signed [6:0] voffset,  // lines, + = down (clamped: clear of VSync, inside the field)
    input      [2:0]  deflicker, // 0 off, 1 mild 1-6-1, 2 medium 3-10-3, 3 medium+ 13-38-13, 4+ full 1-2-1
    input      [2:0]  vheight,   // 0: 1:1, every line exact; 1..6: stretch to 200,208,..,240
                                 //    lines per field (VIS_LINES caps it), filtered by deflicker

    output  [PW-1:0]  lut_addr,  // colour lookup, LUT_LAT clk latency (LUT_EXT=1)
    input      [23:0] lut_rgb,

    output            ce_out,
    output reg [7:0]  r_out, g_out, b_out,
    output reg        hs_out, vs_out, de_out,
    output reg        hb_out, vb_out,   // de = ~hb & ~vb (do NOT feed this through arcade_video)
    output reg        field,     // 1 while the lower field (odd source lines) is out
    output            locked     // the source is measured and the interlaced stream is out
);

localparam AW   = $clog2(W_MAX);
localparam SW   = $clog2(RING);

// ---------------------------------------------------------------------------
// Source measurement (all counts in clk)
// ---------------------------------------------------------------------------
reg        vs_l = 0, de_l = 0;
wire       vs_rise = vs_in & ~vs_l;
wire       de_rise = de_in & ~de_l;
reg [21:0] fcnt = 0;               // clk since source VSync
reg [21:0] tf = 0;                 // frame period
reg [21:0] tz_run = 0, tz = 0;     // VSync -> last active line (its DE rise)
reg [11:0] lcnt = 0, tls = 0;      // source line period (DE rise to DE rise)
reg [ 9:0] hs_run = 0, hsrc = 0;   // active lines per frame
reg [AW:0] xw = 0, ws_run = 0, wsrc = 0;
reg        seen_de = 0;
reg [ 1:0] stable = 0;
assign     locked = stable == 2'd3;
// Frame-rate window. Slowest: 49 Hz (HL 637, 15.6 kHz). Fastest: HL is HL_MIN from about 59.8 Hz
// up (525) so the output line is 2 tf / HL_MIN; it must last at least a 16.5 kHz line and hold
// H_START + W_MAX.
localparam integer OUT_X2 = 2 * CLK_DIV + CLK_FRAC;               // clocks per 2 output pixels
localparam integer TL_HZ  = CLK_HZ / 16500 + 1;
localparam integer TL_PX  = ((H_START + W_MAX) * OUT_X2 + 1) / 2;
localparam integer TL_MIN = TL_HZ > TL_PX ? TL_HZ : TL_PX;      // shortest output line, clk
localparam [21:0] TF_MIN = (TL_MIN * HL_MIN + 1) / 2, TF_MAX = CLK_HZ / 49;

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

// ---------------------------------------------------------------------------
// Per-frame geometry: output line period, active window and field delay
// ---------------------------------------------------------------------------
// Half-lines a frame: L = floor(15075 x tf / CLK_HZ + 11) lines a field, HL = 2L + 1, at least HL_MIN.
// (Line rate (L + 0.5) x fps: 525 at 59.94 Hz, 625 at 50 Hz.) Followed while unlocked, held while
// locked, so a frame period on a rounding boundary cannot switch it back and forth.
localparam [47:0] HL_K = CLK_HZ == 0 ? 48'd0 : ((48'd15075 << 32) + CLK_HZ / 2) / CLK_HZ;
reg [45:0] m_hl = 0;
localparam [10:0] HLM  = HL_MIN;
localparam [13:0] LMIN = (HL_MIN - 1) / 2;
reg [13:0] hl_f = 0;               // lines a field, before the HL_MIN floor
reg [10:0] hl_n = HLM;             // half-lines a frame (odd)
always @(posedge clk) begin
    m_hl <= tf * HL_K[23:0];
    hl_f <= m_hl[45:32] + 14'd11;
    if( !locked ) hl_n <= hl_f < LMIN ? HLM : hl_f > 14'd1023 ? 11'd2047 : { hl_f[9:0], 1'b1 };
end

// tlo = tf / (HL/2) = 2 tf / HL, output line period (floor, error < 1 clk): a shift-subtract
// divider, 24 clocks a result, running all the time (tf and HL change at most once a frame)
reg [21:0] tlo = 0;
reg [ 4:0] dv_n = 0;
reg [22:0] dv_q = 0;               // numerator in, quotient out
reg [10:0] dv_r = 0, dv_d = 11'd525;
wire [11:0] dv_t  = { dv_r, dv_q[22] };
wire        dv_ge = dv_t >= { 1'b0, dv_d };
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
reg [ 9:0] half_act = 0;           // source lines per field (1:1)
reg [ 9:0] out_lines = 0;          // active output lines per field
wire       vfull = vheight != 0;
reg [ 9:0] hsel;                   // stretched height, lines per field
reg [23:0] hk;                     // floor(2^24 / (2*hsel))
always_comb begin                  // (always_comb: evaluated at time 0 too, for a constant vheight)
    case( vheight )
        3'd1:    begin hsel = 10'd200; hk = 24'd41943; end
        3'd2:    begin hsel = 10'd208; hk = 24'd40329; end
        3'd3:    begin hsel = 10'd216; hk = 24'd38836; end
        3'd4:    begin hsel = 10'd224; hk = 24'd37449; end
        3'd5:    begin hsel = 10'd232; hk = 24'd36157; end
        default: begin hsel = 10'd240; hk = 24'd34952; end
    endcase
    if( hsel > VIS_LINES ) begin hsel = VIS_LINES[9:0]; hk = (1 << 24) / (2*VIS_LINES); end
end
reg [23:0] step = 0;               // stretch: source lines per output frame line, 8.16
reg [33:0] m_step;
reg [ 9:0] vstart = 0;             // first active line of a field
reg [ 9:0] v_cen = 0, v_hi = 0;
reg signed [11:0] v_want = 0;
// the active lines stay clear of VSync and inside the (HL-1)/2 whole lines of a field
localparam integer V_MIN = (VS_HL + VS_LEN + 1) / 2;
reg [22:0] dly = 0;                // source VSync -> field start
reg signed [10:0] v_add = 0;       // lines a slower frame adds above the visible window (< 0: removes)
// What a field displays: a snapshot, taken at its start, of the same geometry its start time was
// computed from. A menu change (Height, V-Position) therefore applies whole, from a field start.
reg        f_vfull = 0;
reg [ 9:0] f_lines = 0, f_vstart = 0;
reg [23:0] f_step = 0;
reg [21:0] m_src, m_out;
reg [11:0] tls_h = 0;              // tls, held while locked
reg [21:0] tz_h = 0;               // tz, held while it moves by 8 clk or less

always @(posedge clk) begin
    // pipelined over the frame; results are stable long before they are used
    v_add    <= $signed({1'b0, hl_n} - 12'd525) >>> 2;
    half_act <= hsrc[9:1];
    out_lines<= vfull ? hsel : half_act > VIS_LINES ? VIS_LINES[9:0] : half_act;
    v_cen    <= (VIS_LINES[9:0] - out_lines) >> 1;       // centred in the visible lines
    v_want   <= $signed({2'b00, VIS_FIRST[9:0] + v_cen}) + $signed({v_add[10], v_add}) + $signed({{5{voffset[6]}}, voffset});
    v_hi     <= hl_n[10:1] - out_lines;
    vstart   <= v_want < V_MIN ? V_MIN[9:0] : v_want > $signed({2'b00, v_hi}) ? v_hi : v_want[9:0];
    // step = hsrc / (2*lines) in 8.16: hsrc * floor(2^24/(2*lines)) >> 8
    m_step   <= hsrc * hk;
    step     <= m_step[31:8];
    // measured from the last line, not first line + hsrc x tls, with the line period held while
    // locked: a source whose line period alternates by 1 clk (Popeye: 1523/1524) would otherwise
    // move the field start from frame to frame (by hsrc clk with the old formula; the field
    // period then alternated and a CRT dropped the picture for single frames)
    // tz is held too unless it really moves (the source's picture moved: more than 8 clk)
    if( !locked ) tls_h <= tls;
    if( !locked || (tz > tz_h ? tz - tz_h : tz_h - tz) > 22'd8 ) tz_h <= tz;
    m_src    <= tz_h + tls_h + (tls_h << 1);                 // source finishes, plus two lines
    m_out    <= (vstart + out_lines - 1'd1) * tlo;            // field start -> last active line
    // field start = source finish - that; if it lands before VSync, start in the previous frame
    dly      <= (m_src >= m_out) ? {1'b0, m_src - m_out} : {1'b0, m_src} + {1'b0, tf} - {1'b0, m_out};
end

// ---------------------------------------------------------------------------
// Write side: every active source line, slot = line mod RING
// ---------------------------------------------------------------------------
reg          wpar = 0;             // field parity this source frame will be shown in
reg [SW-1:0] wslot = 0;
reg [AW:0]   wx = 0;               // bit AW: past W_MAX, the rest of the line is not stored
reg          wfirst = 0;
// A line starts at x=0 even when DE rises on a clock without the pixel enable: wfirst
// carries the line start to the next enabled clock. (Without it, a line cut short by a
// reset left wx part-way and every later line was written rotated.)
wire [AW:0]  wx_cur = (de_rise | wfirst) ? {AW+1{1'b0}} : wx;

(* ramstyle = "no_rw_check" *) reg [PW-1:0] ring[0:RING*W_MAX-1];

always @(posedge clk) begin
    if( vs_rise ) begin
        wpar  <= ~wpar;
        wslot <= 0;
    end else begin
        if( de_l & ~de_in )                // line ended
            wslot <= wslot == RING-1 ? {SW{1'b0}} : wslot + 1'd1;
        if( de_rise ) wfirst <= 1;
        if( ce_in && de_in ) begin
            if( !wx_cur[AW] ) ring[{wslot, wx_cur[AW-1:0]}] <= pix_in;
            wx     <= wx_cur + !wx_cur[AW];
            wfirst <= 0;
        end
    end
end

// ---------------------------------------------------------------------------
// Output timing
// ---------------------------------------------------------------------------
reg [22:0] dcnt = 0;               // clk since source VSync, for the field start
reg        armed = 0;
reg [22:0] acc = 0;                // half-line Bresenham
reg [10:0] hl = 0;                 // half-line within the field
reg        fpar = 0;               // field parity
reg [ 7:0] cdiv = 0;
reg        alt  = 0;               // CLK_FRAC: this pixel is the long one
wire [7:0] plast = CLK_DIV - 1 + (CLK_FRAC & alt);   // last clock of this pixel
reg [10:0] px = 0;                 // output pixel within the line
reg        ce_o = 0;
wire       run = locked;

wire       fstart = armed && dcnt >= dly;   // >=: a dly that moved earlier still starts
wire       tick   = acc + {12'd0, hl_n} >= {1'b0, tf};

always @(posedge clk) begin
    dcnt <= vs_rise ? 23'd0 : dcnt + 1'd1;
    if( vs_rise ) armed <= 1;
    ce_o <= 0;
    if( fstart ) begin
        armed <= 0;
        f_vfull  <= vfull;
        f_lines  <= out_lines;
        f_vstart <= vstart;
        f_step   <= step;
        fpar  <= wpar;                 // this frame's lines are the ones stored
        hl    <= 0;
        acc   <= 0;
        if( !wpar ) begin              // field 0 starts on a line boundary
            cdiv <= 0;
            px   <= 0;
            ce_o <= 1;
            alt  <= 0;
        end else begin                 // field 1 starts mid-line: the line carries on
            cdiv <= cdiv == plast ? 8'd0 : cdiv + 1'd1;
            if( cdiv == plast ) begin
                ce_o <= 1;
                if( px != 11'h7ff ) px <= px + 1'd1;   // saturates: one HSync per line
                alt  <= ~alt;
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
            cdiv <= 0;
            px   <= 0;
            ce_o <= 1;
            alt  <= 0;
        end else begin
            cdiv <= cdiv == plast ? 8'd0 : cdiv + 1'd1;
            if( cdiv == plast ) begin
                ce_o <= 1;
                if( px != 11'h7ff ) px <= px + 1'd1;   // saturates: one HSync per line
                alt  <= ~alt;
            end
        end
    end
end

// line within the field, counted from the field's first full line
wire [10:0] hlf  = hl - {10'd0, fpar};
wire [ 9:0] lf   = hlf[10:1];
wire        v_on = !(fpar && hl == 0) && lf >= f_vstart && lf < f_vstart + f_lines;
reg  [10:0] hst = 0;               // first active pixel: a narrower source is centred
always @(posedge clk) hst <= H_START[10:0] + ((W_MAX[10:0] - wsrc) >> 1) + {{4{hoffset[6]}}, hoffset};
wire        h_on = px >= hst && px < hst + wsrc;

// ---------------------------------------------------------------------------
// Read side: per output pixel, three reads (centre, above, below) on its first
// three clocks, each through the colour lookup, then a blend.
// ---------------------------------------------------------------------------
function [SW-1:0] inc(input [SW-1:0] v); inc = v == RING-1 ? {SW{1'b0}} : v + 1'd1; endfunction
function [SW-1:0] dec(input [SW-1:0] v); dec = v == 0 ? RING[SW-1:0]-1'd1 : v - 1'd1; endfunction

reg  [SW-1:0] rs_c = 0, rs_a = 0, rs_b = 0;   // slots of the centre line and its neighbours
reg  [ 9:0]   s_cur = 0;                      // centre source line
reg           rline_on = 0;
reg  [25:0]   pos = 0;                        // stretch: source position of this output line, 10.16
wire [25:0]   pos_nx = pos + {f_step, 1'b0};    // next line of this field: 2 frame lines on
wire [25:0]   pos_nr = pos_nx + 26'h8000;     // rounded: centre on the NEAREST source line
wire [ 9:0]   f_nx   = pos_nr[25:16];
wire [ 1:0]   f_adv  = f_nx - s_cur;          // source lines per output line: 0..3 (up to 2*VIS_LINES)
wire [25:0]   pos_0  = fpar ? {2'd0, f_step} : 26'd0;   // a field's first line: frame line 0 or 1
wire [25:0]   pos_0r = pos_0 + 26'h8000;
reg  [ 7:0]   frac = 0;                       // offset from that line + 128 (0..255 = -0.5..+0.5)

// new output line: 1:1 advances the centre line by 2 (a field skips the other parity);
// stretch advances the position by 2 frame lines and follows its integer part
always @(posedge clk) if( ce_o && px == 0 ) begin
    if( !v_on ) begin
        pos   <= pos_0;
        s_cur <= f_vfull ? pos_0r[25:16] : {9'd0, fpar};              // nearest line (0..2)
        rs_c  <= f_vfull ? pos_0r[16 +: SW] : {{SW-1{1'b0}}, fpar};
        frac  <= f_vfull ? pos_0r[15:8] : 8'h80;
        rline_on <= 0;
    end else begin
        if( rline_on ) begin
            if( f_vfull ) begin
                pos   <= pos_nx;
                s_cur <= f_nx;
                frac  <= pos_nr[15:8];
                case( f_adv )
                    2'd1:    rs_c <= inc(rs_c);
                    2'd2:    rs_c <= inc(inc(rs_c));
                    2'd3:    rs_c <= inc(inc(inc(rs_c)));
                    default: ;                        // same line (stretched over 2x)
                endcase
            end else begin
                s_cur <= s_cur + 2'd2;
                rs_c  <= inc(inc(rs_c));
            end
        end
        rline_on <= 1;
    end
end
always @* begin
    rs_a = s_cur == 0            ? rs_c : dec(rs_c);
    rs_b = s_cur + 1'd1 >= hsrc  ? rs_c : inc(rs_c);
end

wire [AW-1:0] rx = px - hst;
reg  [SW-1:0] rslot;
always @* case( cdiv )
    8'd1:    rslot = rs_a;
    8'd2:    rslot = rs_b;
    default: rslot = rs_c;
endcase

reg  [PW-1:0] ram_q;
always @(posedge clk) ram_q <= ring[{ rslot, rx }];

// internal "lookup" for packed colour
localparam CB = PW/3;
function [7:0] expand(input [CB-1:0] v);
    expand = { v, v, v, v } >> (4*CB - 8);
endfunction
reg  [23:0] rgb_int;
always @(posedge clk) rgb_int <= { expand(ram_q[3*CB-1 -: CB]), expand(ram_q[2*CB-1 -: CB]), expand(ram_q[CB-1 -: CB]) };
assign lut_addr = ram_q;
wire [23:0] rgb = LUT_EXT ? lut_rgb : rgb_int;

reg [23:0] cc = 0, ca = 0, cb = 0, blend = 0;
function [7:0] mix(input [7:0] a, c, b, input [2:0] m);
    reg [13:0] t;
    begin
        case( m )
            3'd1:    t = ( a + b + 6*c ) >> 3;           // mild    (1-6-1)/8
            3'd2:    t = ( 3*a + 3*b + 10*c ) >> 4;      // medium  (3-10-3)/16
            3'd3:    t = ( 13*a + 13*b + 38*c ) >> 6;    // medium+ (13-38-13)/64
            3'd0:    t = c;
            default: t = ( a + b + 2*c ) >> 2;           // full    (1-2-1)/4
        endcase
        mix = t[7:0];
    end
endfunction
// ---------------------------------------------------------------------------
// Stretch filter: deflicker first, then interpolate. Each output line sits at a fractional
// source position; the result is the linear blend of the two nearest source lines AFTER
// each has been through the 1:1 deflicker kernel (k, 1-2k, k with k = 0, 1/8, 3/16, 1/4 for
// Off, Mild, Medium, Full), so every output line gets the same filtering as 1:1. That needs
// four source lines; the module reads three (nearest and its neighbours), so the far line
// (weight k*f, at most 1/8) is dropped and the three are renormalised: less than half the
// error of the tent scheme against the exact four-line result, and exact on lines that
// land on a source line. Off is plain two-line interpolation.
// Medium+ keeps the earlier scheme's Full: a tent of half-width 1.5 source lines centred
// on the output position (weights 20/60/20 on a source line, 0/50/50 halfway) - slightly
// sharper than Full, uneven line to line. At 1:1 its kernel is 13-38-13.
// Weights sum to 256, stored per level and per offset (256 steps of 1/256 line).
// ---------------------------------------------------------------------------
reg [26:0] wrom[0:2047];              // { w_above[8:0], w_centre[8:0], w_below[8:0] }
initial begin : build_wrom
    integer lv, fi, d, k, f, rawa, rawc, rawb, t, sum, wa, wb, wc;
    for( lv = 0; lv < 8; lv = lv + 1 ) begin
        k = lv == 0 ? 0 : lv == 1 ? 32 : lv == 2 ? 48 : 64;   // kernel side weight, /256
        for( fi = 0; fi < 256; fi = fi + 1 ) begin
            d    = fi - 128;                          // offset from the nearest line, /256
            f    = d < 0 ? -d : d;
            if( lv == 3 ) begin                       // Medium+: tent, half-width 1.5 lines
                rawc = 384 - f;
                rawa = 384 - (256 + d); if( rawa < 0 ) rawa = 0;
                rawb = 384 - (256 - d); if( rawb < 0 ) rawb = 0;
            end else begin
                rawc = (256 - f) * (256 - 2*k) + f * k;
                rawa = k * (256 - f);                     // far side (the dropped line is beyond it)
                rawb = (256 - f) * k + f * (256 - 2*k);   // near side, towards the output position
                if( d < 0 ) begin t = rawa; rawa = rawb; rawb = t; end
            end
            sum  = rawa + rawc + rawb;
            wa   = (rawa * 256 + sum/2) / sum;
            wb   = (rawb * 256 + sum/2) / sum;
            wc   = 256 - wa - wb;
            wrom[lv*256 + fi] = { wa[8:0], wc[8:0], wb[8:0] };
        end
    end
end
reg  [26:0] wq;
always @(posedge clk) wq <= wrom[{ deflicker, frac }];
// weighted sum of three 8-bit values, weights summing to 256
function [7:0] wsum(input [7:0] a, c, b);
    reg [17:0] t;
    begin
        t    = a * wq[26:18] + c * wq[17:9] + b * wq[8:0] + 18'd128;
        wsum = t[15:8];
    end
endfunction

// Schedule. The reads are issued on the pixel's clocks 0 (centre), 1 (above) and 2 (below);
// each colour is on rgb 1+LUT_LAT clocks later and the blend follows one clock after the last
// (LUT_LAT=1: captures on clocks 2, 3, 4, blend on 5). Integer CLK_DIV: fixed phases, mod
// CLK_DIV. CLK_FRAC: pixels are CLK_DIV or CLK_DIV+1 clocks, so each read carries a tag down a
// short pipeline and the capture happens when the tag arrives.
// The output register takes the blend on the first pixel enable after it is written (LAT pixel
// enables after the read). With CLK_FRAC this must be the same for both pixel lengths:
// PM/CLK_DIV == PM/(CLK_DIV+1), true for CLK_DIV 4 with LUT_LAT 1 or 2.
localparam integer LL  = LUT_EXT ? LUT_LAT : 1;   // packed colour: the expand register
localparam integer PM  = 4 + LL;              // clock of the blend, from the centre read
localparam [7:0]   PH_C = (1+LL) % CLK_DIV, PH_A = (2+LL) % CLK_DIV,
                   PH_B = (3+LL) % CLK_DIV, PH_M = PM % CLK_DIV;
localparam integer LAT = PM / CLK_DIV + 1;
localparam integer TD  = 1 + LL;              // read -> colour on rgb, clocks
// how far the visible window moves at the shortest field: floor((HL_MIN - 525) / 4)
localparam integer VADD_MIN = HL_MIN >= 525 ? (HL_MIN - 525) / 4 : -((525 - HL_MIN + 3) / 4);

// synthesis translate_off
initial begin
    if( CLK_DIV < 3 )                  $fatal(1, "crt_480i: CLK_DIV must be 3 or more");
    if( LUT_EXT && (LUT_LAT < 1 || LUT_LAT > 2) ) $fatal(1, "crt_480i: LUT_LAT must be 1 or 2");
    if( CLK_FRAC && PM / CLK_DIV != PM / (CLK_DIV+1) )
        $fatal(1, "crt_480i: CLK_FRAC needs PM/CLK_DIV == PM/(CLK_DIV+1) (e.g. CLK_DIV 4)");
    if( W_MAX != 1 << AW )             $fatal(1, "crt_480i: W_MAX must be a power of 2");
    if( !LUT_EXT && PW < 6 )           $fatal(1, "crt_480i: packed colour needs PW >= 6");
    if( HL_MIN % 2 == 0 || HL_MIN < 401 || HL_MIN > 625 ) $fatal(1, "crt_480i: HL_MIN must be odd, 401..625");
    if( VIS_FIRST + VADD_MIN + VIS_LINES > (HL_MIN-1)/2 ) $fatal(1, "crt_480i: VIS_FIRST + VIS_LINES exceed the shortest field (HL_MIN)");
    if( CLK_HZ != 0 && (HL_K >= (1 << 24) || HL_K < (1 << 17)) ) $fatal(1, "crt_480i: CLK_HZ out of range (4..200 MHz)");
    if( VIS_FIRST + VADD_MIN < V_MIN ) $fatal(1, "crt_480i: VIS_FIRST overlaps VSync (at HL_MIN)");
end
// synthesis translate_on
// The same rules as build errors (Quartus ignores the block above): each instantiates a module
// that does not exist, named after the problem.
// Output line rates: 15.58 kHz at the slowest (49 Hz); below 59.94 Hz never over 15.77 kHz (the
// line rate is 15075 + 10.5..11.5 x fps), above it the window keeps the line long enough.
localparam integer LINE_LO = CLK_HZ / OUT_X2 * 2 / 15580;             // output pixels, longest line
localparam integer LINE_HI = CLK_HZ / OUT_X2 * 2 / 15770;             // output pixels, 59.94 Hz and below
generate
    if( CLK_HZ == 0 ) begin : g_needs_clk_hz
        crt_480i_set_the_CLK_HZ_parameter u_err();
    end
    if( CLK_DIV < 3 ) begin : g_clk_div
        crt_480i_CLK_DIV_must_be_3_or_more u_err();
    end
    if( CLK_FRAC && PM / CLK_DIV != PM / (CLK_DIV+1) ) begin : g_clk_frac
        crt_480i_CLK_FRAC_needs_the_same_latency_for_both_pixel_lengths u_err();
    end
    if( CLK_HZ != 0 && LINE_LO > 2047 ) begin : g_too_fast
        crt_480i_output_pixel_clock_too_fast u_err();       // aim for about 10-11 MHz
    end
    // also catches a tool that worked HL_K out in 32 bits (it would be 0: always 525, silently)
    if( CLK_HZ != 0 && (HL_K >= (1 << 24) || HL_K < (1 << 17)) ) begin : g_clk_hz_range
        crt_480i_CLK_HZ_out_of_range_4_to_200_MHz u_err();
    end
    if( CLK_HZ != 0 && LINE_HI < H_START + W_MAX ) begin : g_too_slow
        crt_480i_output_line_too_short_for_H_START_plus_W_MAX u_err();
    end
    if( HL_MIN % 2 == 0 || HL_MIN < 401 || HL_MIN > 625 ) begin : g_hl_min
        crt_480i_HL_MIN_must_be_odd_401_to_625 u_err();
    end
    if( VIS_FIRST + VADD_MIN + VIS_LINES > (HL_MIN-1)/2 ) begin : g_hl_min_fit
        crt_480i_VIS_FIRST_plus_VIS_LINES_exceed_the_shortest_field u_err();
    end
    if( VIS_FIRST + VADD_MIN < V_MIN ) begin : g_vis_first
        crt_480i_VIS_FIRST_overlaps_VSync u_err();
    end
endgenerate

reg  [2*TD+1:0] tsr = 0;                      // tag pipeline, 2 bits a stage: 1 c, 2 a, 3 b
wire [1:0]      tag_in = cdiv == 0 ? 2'd1 : cdiv == 1 ? 2'd2 : cdiv == 2 ? 2'd3 : 2'd0;
always @(posedge clk) tsr <= { tsr[2*TD-1:0], tag_in };
wire [1:0] tag_cap = tsr[2*TD-1 -: 2];        // tag of the colour now on rgb
wire [1:0] tag_mix = tsr[2*TD+1 -: 2];        // one clock later
wire cap_c = CLK_FRAC ? tag_cap == 2'd1 : cdiv == PH_C;
wire cap_a = CLK_FRAC ? tag_cap == 2'd2 : cdiv == PH_A;
wire cap_b = CLK_FRAC ? tag_cap == 2'd3 : cdiv == PH_B;
wire do_m  = CLK_FRAC ? tag_mix == 2'd3 : cdiv == PH_M;
always @(posedge clk) begin
    if( cap_c ) cc <= rgb;
    if( cap_a ) ca <= rgb;
    if( cap_b ) cb <= rgb;
    // The blend is one clock after the last capture and uses registers only, so the lookup
    // and the blend arithmetic are never in the same clock. (At CLK_DIV 3 the next pixel's
    // centre is captured on this same clock; the blend still sees the old cc.)
    if( do_m ) begin
        blend <= f_vfull ?
                 { wsum(ca[23:16], cc[23:16], cb[23:16]),
                   wsum(ca[15: 8], cc[15: 8], cb[15: 8]),
                   wsum(ca[ 7: 0], cc[ 7: 0], cb[ 7: 0]) } :
                 { mix(ca[23:16], cc[23:16], cb[23:16], deflicker),
                   mix(ca[15: 8], cc[15: 8], cb[15: 8], deflicker),
                   mix(ca[ 7: 0], cc[ 7: 0], cb[ 7: 0], deflicker) };
    end
end

// sync, DE and blanks are delayed LAT pixel enables to line up with the colour
reg [2:0] h_on_d = 0, hs_d = 0, vs_d = 0, hw_d = 0, vw_d = 0;
always @(posedge clk) if( ce_o ) begin
    h_on_d <= { h_on_d[1:0], h_on & v_on };
    hw_d   <= { hw_d[1:0],   h_on };          // horizontal window, every line
    vw_d   <= { vw_d[1:0],   v_on };          // active lines
    hs_d   <= { hs_d[1:0],   px < HS_PIX };
    vs_d   <= { vs_d[1:0],   hl >= VS_HL && hl < VS_HL + VS_LEN };
end

reg [7:0] r_o = 0, g_o = 0, b_o = 0;
reg       hs_o = 0, vs_o = 0, de_o = 0, f_o = 0, hb_o = 1, vb_o = 1;
always @(posedge clk) if( ce_o ) begin
    { r_o, g_o, b_o } <= h_on_d[LAT-1] ? blend : 24'd0;
    de_o <= h_on_d[LAT-1];
    hb_o <= ~hw_d[LAT-1];
    vb_o <= ~vw_d[LAT-1];
    hs_o <= hs_d[LAT-1];
    vs_o <= vs_d[LAT-1];
    f_o  <= fpar;
end

// Until locked (core load, reset, or a change in the source timing) the output is black with
// both syncs idle, so the monitor never sees anything but the interlaced stream. The pixel enable
// always runs.
assign ce_out = ce_o;
always @* begin
    r_out  = run ? r_o  : 8'd0;
    g_out  = run ? g_o  : 8'd0;
    b_out  = run ? b_o  : 8'd0;
    hs_out = run & hs_o;                 // syncs are active high, idle low
    vs_out = run & vs_o;
    de_out = run & de_o;
    hb_out = run ? hb_o : 1'b1;
    vb_out = run ? vb_o : 1'b1;
    field  = run & f_o;
end

endmodule
