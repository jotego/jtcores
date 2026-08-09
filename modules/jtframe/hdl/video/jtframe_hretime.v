//============================================================================
//  CRT-Adjust module by Umberto Parisi
//
//  Horizontal pixel-stretch module for the ANALOG VGA output path of a
//  MiSTer FPGA arcade core.
//
//  ─── What it does ──────────────────────────────────────────────────────────
//  Each source pixel is emitted to the DAC for a longer, integer-uniform
//  number of pixel-clock periods. Every pixel of every line is stretched by
//  the same exact factor.
//
//  The horizontal sync rate seen by the CRT is slightly reduced (front+back
//  porches absorb the extra time), keeping the line within the tolerance of
//  vintage 15 kHz CRT and PVM monitors.
//
//  The HDMI path is left untouched: this module is inserted
//  only on the analog VGA branch, after the core's video composition and
//  before the analog DAC pins (typical insertion point in MiSTer is
//  inside sys_top.v, before the OSD overlay).
//
//  ─── License ───────────────────────────────────────────────────────────────
//  Author: Umberto Parisi (rmonic79), 2026.
//  Distributed under GNU GPL v3 or later.
//  Adapted for JTFRAME usage by Andrea Bogazzi (andreabogazzi79@gmail.com)
//============================================================================

/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 9-8-2026 */


module jtframe_hretime #(parameter
    DW    = 24,     // colour bus width
    DIV   = 8,      // clk cycles per input pixel
    STEP  = 64,     // scale denominator, must be a power of two
    DEPTH = 64,     // FIFO depth, must be a power of two
    HW    = 10      // active pixel counter width
)(
    input               clk,
    input               ce_in,      // input pixel clock enable
    input               enable,
    input signed [ 3:0] scale,      // -8..+7 in 1/STEP units. 0 = 1:1

    input      [DW-1:0] din,
    input               hs_in,
    input               vs_in,
    input               de_in,
    // re-timed video
    output              ce_out,
    output     [DW-1:0] dout,
    output              hs_out,
    output              vs_out,
    output              de_out
);

localparam SL  = $clog2(STEP),                  // division by STEP is a shift
           AW  = $clog2(DEPTH),
           MW  = $clog2(DIV*(STEP+8))+1,        // rate accumulator width
           PW  = SL+HW,                         // nactive * |scale|
           DLD = 1<<$clog2((DEPTH*DIV)/2+1),    // sync delay line depth
           DLW = $clog2(DLD);

(* ramstyle = "MLAB, no_rw_check" *) reg [DW-1:0] mem[0:DEPTH-1];
reg  [ 1:0] sync_mem[0:DLD-1];

reg  [DW-1:0] fifo_dout=0, din_l=0;
reg  [ AW-1:0] wptr=0, rptr=0;
reg  [ HW-1:0] wcnt=0, rcnt=0, nactive=0;
reg  [ MW-1:0] acc=0;
reg  [DLW-1:0] sync_wp=0;
reg  hs_l=0, ce_slow=0, started=0, fifo_de=0, de_l=0, hs_dly=0, vs_dly=0;

wire [    3:0] absc  = scale[3] ? -scale : scale;
wire [  MW-1:0] m    = DIV[MW-1:0]*(STEP[MW-1:0]+{{MW-4{scale[3]}},scale}),
                nxt  = acc + STEP[MW-1:0];
wire [  PW-1:0] prod = nactive*absc;
wire [  HW-1:0] grow = prod[PW-1:SL];           // size change, in pixels
wire [  HW+4:0] dly_f= grow*DIV;                // .. as master clocks
wire [  HW+3:0] dly_h= dly_f[HW+4:1];           // half of it centres the image
// one clock is the minimum, as the delay line output is registered
wire [ DLW-1:0] dly  = dly_h>=DLD ? {DLW{1'b1}} :
                       dly_h==0   ? {{DLW-1{1'b0}},1'b1} : dly_h[DLW-1:0];

wire bypass = ~enable | scale==0,
     hs_pos = hs_in & ~hs_l,                    // one per line, sets the phase
     push   = ce_in & de_in & ~bypass,
     pop    = ce_slow & started & rcnt<wcnt;

assign ce_out = bypass ? ce_in : ce_slow,
       hs_out = bypass ? hs_in : hs_dly,
       vs_out = bypass ? vs_in : vs_dly,
       de_out = bypass ? de_l  : fifo_de,
       dout   = bypass ? din_l : fifo_dout;

// Rate generator. The phase restarts at hs so every line is identical
always @(posedge clk) begin
    hs_l    <= hs_in;
    ce_slow <= 0;
    if( hs_pos ) begin
        acc <= 0;
    end else if( nxt>=m ) begin
        acc     <= nxt-m;
        ce_slow <= 1;
    end else begin
        acc <= nxt;
    end
end

// Write side. hs empties the FIFO, so it cannot drift from line to line
always @(posedge clk) begin
    if( hs_pos ) begin
        wptr <= 0;
        wcnt <= 0;
        if( wcnt!=0 ) nactive <= wcnt;
    end else if( push ) begin
        mem[wptr] <= din;
        wptr <= wptr+1'd1;
        wcnt <= wcnt+1'd1;
    end
end

// Read side. `started` releases the shrink pre-buffer: once the writer is
// `grow` samples ahead the reader can run to the end of the line without
// underrunning, so the tail is not lost when the writer stops
always @(posedge clk) begin
    if( hs_pos ) begin
        rptr      <= 0;
        rcnt      <= 0;
        started   <= 0;
        fifo_de   <= 0;
        fifo_dout <= 0;
    end else begin
        if( !started && wcnt>(scale[3] ? grow : {HW{1'b0}}) ) started <= 1;
        if( ce_slow ) begin
            fifo_de <= pop;
            if( pop ) begin
                fifo_dout <= mem[rptr];
                rptr      <= rptr+1'd1;
                rcnt      <= rcnt+1'd1;
            end else begin
                fifo_dout <= 0;
            end
        end
    end
end

// The active window grows to the right by `grow` pixels, so hs/vs are pushed
// back by half of that to keep the picture centred
always @(posedge clk) begin
    sync_mem[sync_wp] <= { hs_in, vs_in };
    sync_wp           <= sync_wp+1'd1;
    { hs_dly, vs_dly} <= sync_mem[sync_wp-dly];
end

// Bypass path, kept aligned with the input pixel rate
always @(posedge clk) if( ce_in ) begin
    din_l <= din;
    de_l  <= de_in;
end

endmodule
